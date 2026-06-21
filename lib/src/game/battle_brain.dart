import 'dart:math';

import 'package:flame/components.dart';

import '../models/game_state.dart';
import 'battle_arena.dart';
import 'fighter_component.dart';
import 'projectile_component.dart';

class BrainDecision {
  const BrainDecision({
    required this.movement,
    required this.castSkill,
    required this.jump,
    required this.intent,
  });

  final Vector2 movement;
  final bool castSkill;
  final bool jump;
  final CombatIntent intent;
}

enum CombatIntent { advance, kite, commit, retreat, execute, dodge, bait, ambush }

// ─────────────────────────────────────────────────────────────────────────────
// Phase system — gives each archetype a readable rhythm.
// Transitions are driven by events (hit, timer, distance) not just timers.
// ─────────────────────────────────────────────────────────────────────────────
enum _Phase {
  approach,   // Closing in
  engage,     // Trading blows
  pressure,   // Aggressive burst window
  backOff,    // Brief breathing room after burst
  bait,       // Fake retreat to bait skill
  reposition, // Angle adjustment before next engage
  platformSeek, // Jumping to a platform
  flee,       // Emergency
}

class DuelBrain {
  DuelBrain(this._random);

  final Random _random;

  _Phase _phase = _Phase.approach;
  double _phaseTimer  = 0;
  double _feintDir    = 1;
  double _feintTimer  = 0;
  double _prevHp      = -1;
  double _hitCooldown = 0;    // prevents dodge spam on same projectile
  bool   _desperate   = false;
  int    _burstCount  = 0;    // attacks landed recently — escalates aggression
  double _burstDecay  = 0;
  double _jumpCooldown = 0;   // prevents repeated jump spam

  // ── public entry point ────────────────────────────────────────────────────

  BrainDecision decide({
    required FighterComponent self,
    required FighterComponent target,
    required ArchetypeDefinition definition,
    required Iterable<ProjectileComponent> projectiles,
    required BattleArena arena,
    required double confidence,
    required double dt,
  }) {
    // ── tick internal timers ─────────────────────────────────────────────
    _phaseTimer   -= dt;
    _feintTimer   -= dt;
    _hitCooldown  -= dt;
    _jumpCooldown -= dt;
    _burstDecay   -= dt;
    if (_burstDecay <= 0) _burstCount = 0;

    if (_feintTimer <= 0) {
      _feintTimer = 0.2 + _random.nextDouble() * 0.35;
      _feintDir   = _random.nextBool() ? 1.0 : -1.0;
    }

    final double hpRatio       = self.hp / self.stats.maxHp;
    final double targetHpRatio = target.hp / target.stats.maxHp;
    final bool   hitThisFrame  = _prevHp > 0 && self.hp < _prevHp - 0.5;
    if (_prevHp < 0) _prevHp = self.hp;

    if (hitThisFrame) {
      _prevHp = self.hp;
    }

    if (!_desperate && hpRatio < 0.25) _desperate = true;
    if (_desperate  && hpRatio > 0.35) _desperate = false;

    // Shared geometry
    final Vector2 toTarget  = target.position - self.position;
    final double  distance  = toTarget.length;
    final double  forward   = (distance > 0.001) ? toTarget.x.sign : 0.0;
    final double  attackRange = self.stats.attackRange;
    final double  preferred   = definition.preferredRange;

    return switch (definition.archetype) {
      FighterArchetype.kiting => _decideMage(
          self: self, target: target, definition: definition,
          projectiles: projectiles, arena: arena,
          confidence: confidence, dt: dt,
          distance: distance, forward: forward,
          attackRange: attackRange, preferred: preferred,
          hpRatio: hpRatio, targetHpRatio: targetHpRatio,
          hitThisFrame: hitThisFrame,
        ),
      FighterArchetype.melee => _decideSword(
          self: self, target: target, definition: definition,
          projectiles: projectiles, arena: arena,
          confidence: confidence, dt: dt,
          distance: distance, forward: forward,
          attackRange: attackRange, preferred: preferred,
          hpRatio: hpRatio, targetHpRatio: targetHpRatio,
          hitThisFrame: hitThisFrame,
        ),
      FighterArchetype.bruiser => _decideBruiser(
          self: self, target: target, definition: definition,
          projectiles: projectiles, arena: arena,
          confidence: confidence, dt: dt,
          distance: distance, forward: forward,
          attackRange: attackRange, preferred: preferred,
          hpRatio: hpRatio, targetHpRatio: targetHpRatio,
          hitThisFrame: hitThisFrame,
        ),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAGE  —  거리 유지 + 플랫폼 도주 + 정확한 투사체 타이밍
  // 전략: 투사체를 꾸준히 쏘되, 근접이 오면 플랫폼으로 올라가 거리 확보.
  //       체력이 낮으면 더 공격적으로 스킬 사용.
  // ═══════════════════════════════════════════════════════════════════════════
  BrainDecision _decideMage({
    required FighterComponent self,
    required FighterComponent target,
    required ArchetypeDefinition definition,
    required Iterable<ProjectileComponent> projectiles,
    required BattleArena arena,
    required double confidence,
    required double dt,
    required double distance,
    required double forward,
    required double attackRange,
    required double preferred,
    required double hpRatio,
    required double targetHpRatio,
    required bool hitThisFrame,
  }) {
    double moveX = 0;
    bool jump    = false;
    CombatIntent intent = CombatIntent.kite;

    // ── priority 1: jump over incoming projectile ─────────────────────────
    if (_shouldJumpOver(self, projectiles) && _jumpCooldown <= 0 && self.onGround) {
      jump = true;
      _jumpCooldown = 0.9;
      return BrainDecision(movement: Vector2.zero(), castSkill: false, jump: true, intent: CombatIntent.dodge);
    }

    // ── priority 2: mage on a platform — enjoy high ground ───────────────
    final ArenaPlatform? myPlatform = _platformUnder(self, arena);
    final bool onHighGround = myPlatform != null;

    // ── phase: danger zone — enemy in face ───────────────────────────────
    final bool dangerClose = distance < preferred * 0.55;

    if (dangerClose && _phase != _Phase.flee) {
      _phase = _Phase.flee;
      _phaseTimer = 0.5 + _random.nextDouble() * 0.3;
    }

    // ── phase: try to get on a platform when enemy is advancing ──────────
    if (!onHighGround && distance < preferred * 1.3 && _phase == _Phase.approach) {
      final ArenaPlatform? nearPlat = _nearestPlatform(self, arena, preferSide: forward > 0 ? -1 : 1);
      if (nearPlat != null && _jumpCooldown <= 0 && self.onGround) {
        final double platCenterX = nearPlat.centerX;
        final double dx = platCenterX - self.position.x;
        moveX = dx.sign;
        if (dx.abs() < 30) {
          jump = true;
          _jumpCooldown = 1.2;
        }
        return BrainDecision(movement: _norm(Vector2(moveX, 0)), castSkill: false, jump: jump, intent: CombatIntent.advance);
      }
    }

    // ── phase transitions ─────────────────────────────────────────────────
    if (_phaseTimer <= 0) {
      _phase = switch (_phase) {
        _Phase.flee       => _Phase.bait,
        _Phase.bait       => _Phase.approach,
        _Phase.approach   => _Phase.engage,
        _Phase.engage     => (_random.nextDouble() < 0.35) ? _Phase.bait : _Phase.approach,
        _Phase.backOff    => _Phase.approach,
        _Phase.reposition => _Phase.approach,
        _Phase.platformSeek => _Phase.engage,
        _Phase.pressure   => _Phase.backOff,
      };
      _phaseTimer = _phaseDurationMage(_phase);
    }

    // ── produce movement ──────────────────────────────────────────────────
    switch (_phase) {
      case _Phase.flee:
        // Run away from enemy AND try to get to a safe platform
        moveX = onHighGround ? _feintDir * 0.5 : -forward;
        intent = CombatIntent.retreat;

      case _Phase.bait:
        // Fake approach to bait skill, then dodge back
        moveX = _phaseTimer > 0.25 ? forward * 0.4 : -forward * 0.8;
        intent = CombatIntent.bait;

      case _Phase.approach:
      case _Phase.engage:
        if (distance > preferred + 25) {
          moveX = forward * 0.6;   // close in slowly
          intent = CombatIntent.advance;
        } else if (distance < preferred - 15) {
          moveX = -forward * 0.8;  // back off to sweet spot
          intent = CombatIntent.kite;
        } else {
          // In sweet spot — strafe sideways to be harder to hit
          moveX = _feintDir * 0.45;
          if (hitThisFrame) moveX = -forward * 0.7;
          intent = CombatIntent.kite;
        }

      case _Phase.backOff:
        moveX = -forward * 0.9;
        intent = CombatIntent.retreat;

      case _Phase.pressure:
        moveX = _feintDir * 0.5;
        intent = CombatIntent.commit;

      default:
        moveX = forward * 0.5;
    }

    // When desperate: stand and fight — more aggressive skill casts
    if (_desperate) {
      moveX = distance > attackRange ? forward * 0.5 : _feintDir * 0.3;
      intent = CombatIntent.execute;
    }

    // ── skill decision ────────────────────────────────────────────────────
    // Mage fires skill: when on high ground (bonus), at good range, or desperate
    final double skillRange = min(280.0, self.stats.skillSpeed * 0.85);
    final bool goodSkillRange = distance > attackRange * 0.7 && distance < skillRange;
    final double baseChance = 0.038 + confidence * 0.04;
    final bool castSkill = self.skillReady && goodSkillRange && (
      _random.nextDouble() < (onHighGround ? baseChance * 1.6 : baseChance)
      || targetHpRatio < 0.25
      || (_desperate && _random.nextDouble() < 0.08)
    );

    return BrainDecision(
      movement: _norm(Vector2(moveX.clamp(-1, 1), 0)),
      castSkill: castSkill,
      jump: jump,
      intent: intent,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SWORD  —  영리한 근접전. 견제 후 찌르기, 플랫폼 활용한 다이브.
  // 전략: 짧게 견제(feint) → 틈 노려 파고들기 → 연타 → 짧게 뒤로.
  //       마법사가 플랫폼에 있으면 점프로 올라가서 따라감.
  // ═══════════════════════════════════════════════════════════════════════════
  BrainDecision _decideSword({
    required FighterComponent self,
    required FighterComponent target,
    required ArchetypeDefinition definition,
    required Iterable<ProjectileComponent> projectiles,
    required BattleArena arena,
    required double confidence,
    required double dt,
    required double distance,
    required double forward,
    required double attackRange,
    required double preferred,
    required double hpRatio,
    required double targetHpRatio,
    required bool hitThisFrame,
  }) {
    double moveX = 0;
    bool jump    = false;

    // ── priority: chase target to platform ───────────────────────────────
    final ArenaPlatform? targetPlatform = _platformUnder(target, arena);
    final ArenaPlatform? myPlatform     = _platformUnder(self, arena);
    final bool targetOnPlatform = targetPlatform != null && myPlatform == null;

    if (targetOnPlatform && _jumpCooldown <= 0 && self.onGround && distance < 160) {
      // Move under target platform and jump
      final double dx = target.position.x - self.position.x;
      moveX = dx.sign;
      if (dx.abs() < 45) {
        jump = true;
        _jumpCooldown = 1.1;
      }
      return BrainDecision(
        movement: _norm(Vector2(moveX, 0)),
        castSkill: false,
        jump: jump,
        intent: CombatIntent.ambush,
      );
    }

    // ── priority: jump over projectile ───────────────────────────────────
    if (_shouldJumpOver(self, projectiles) && _jumpCooldown <= 0 && self.onGround) {
      jump = true;
      _jumpCooldown = 0.75;
      // Keep advancing while jumping
      moveX = forward;
      return BrainDecision(movement: _norm(Vector2(moveX, 0)), castSkill: false, jump: true, intent: CombatIntent.dodge);
    }

    // ── phase transitions ─────────────────────────────────────────────────
    switch (_phase) {
      case _Phase.approach:
      case _Phase.reposition:
        if (distance <= attackRange + 12) {
          _phase = _Phase.engage;
          _phaseTimer = _engageDurationSword();
        }

      case _Phase.engage:
        // After enough hits, go pressure
        if (_burstCount >= 2) {
          _phase = _Phase.pressure;
          _phaseTimer = 0.5 + _random.nextDouble() * 0.3;
          _burstCount = 0;
        } else if (_phaseTimer <= 0 || (hitThisFrame && _random.nextDouble() < 0.35)) {
          _startBackOff();
        }

      case _Phase.pressure:
        if (_phaseTimer <= 0) _startBackOff();

      case _Phase.backOff:
        if (_phaseTimer <= 0) {
          // Sometimes bait with fake retreat
          if (_random.nextDouble() < 0.3) {
            _phase = _Phase.bait;
            _phaseTimer = 0.4;
          } else {
            _phase = _Phase.reposition;
            _phaseTimer = 0.3 + _random.nextDouble() * 0.25;
          }
        }

      case _Phase.bait:
        if (_phaseTimer <= 0) {
          _phase = _Phase.engage;
          _phaseTimer = _engageDurationSword();
        }

      default: break;
    }

    // Desperate → full aggression
    if (_desperate || targetHpRatio < 0.2) {
      if (_phase != _Phase.engage && _phase != _Phase.pressure) {
        _phase = _Phase.pressure;
        _phaseTimer = 1.2;
      }
    }

    moveX = switch (_phase) {
      _Phase.approach    => forward,
      _Phase.reposition  => forward * 0.75 + _feintDir * 0.3,
      _Phase.engage      => (distance > attackRange + 5) ? forward * 0.95 : _feintDir * 0.25,
      _Phase.pressure    => (distance > attackRange) ? forward : _feintDir * 0.15,
      _Phase.backOff     => -forward * 0.9,
      _Phase.bait        => -forward * 0.5,
      _Phase.flee        => -forward,
      _Phase.platformSeek => forward,
    };

    // Smart aggression: when enemy is running low, full commit regardless of HP
    final bool killOpportunity = targetHpRatio < 0.3 && distance < preferred * 2.5;
    if (killOpportunity) {
      moveX = forward;
    }

    // Low confidence + low HP → brief retreat instead of suiciding
    if (hpRatio < 0.18 && confidence < 0.6 && !_desperate) {
      moveX = -forward * 0.8;
    }

    final double castChance = (0.03 + confidence * 0.04) * definition.skillUsageBias;
    final bool castSkill = self.skillReady &&
        distance <= attackRange * 1.3 &&
        _phase == _Phase.pressure &&
        (_random.nextDouble() < castChance || targetHpRatio < 0.22);

    return BrainDecision(
      movement: _norm(Vector2(moveX.clamp(-1, 1), 0)),
      castSkill: castSkill,
      jump: jump,
      intent: targetHpRatio < 0.25
          ? CombatIntent.execute
          : switch (_phase) {
              _Phase.approach    => CombatIntent.advance,
              _Phase.reposition  => CombatIntent.advance,
              _Phase.bait        => CombatIntent.bait,
              _Phase.engage      => CombatIntent.commit,
              _Phase.pressure    => CombatIntent.commit,
              _Phase.backOff     => CombatIntent.retreat,
              _Phase.flee        => CombatIntent.retreat,
              _Phase.platformSeek => CombatIntent.ambush,
            },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BRUISER  —  육중한 돌격. 맞으면서 전진, 붙으면 절대 안 놓음.
  // 전략: 투사체 점프 회피하며 전진 → 붙으면 집요하게 연타.
  //       체력이 반 이하여도 후퇴하지 않고 더 공격적으로 변함.
  // ═══════════════════════════════════════════════════════════════════════════
  BrainDecision _decideBruiser({
    required FighterComponent self,
    required FighterComponent target,
    required ArchetypeDefinition definition,
    required Iterable<ProjectileComponent> projectiles,
    required BattleArena arena,
    required double confidence,
    required double dt,
    required double distance,
    required double forward,
    required double attackRange,
    required double preferred,
    required double hpRatio,
    required double targetHpRatio,
    required bool hitThisFrame,
  }) {
    double moveX = 0;
    bool jump = false;

    // ── priority: jump over projectile while advancing ───────────────────
    if (_shouldJumpOver(self, projectiles) && _jumpCooldown <= 0 && self.onGround) {
      jump = true;
      _jumpCooldown = 0.65;
      moveX = forward;  // keep pressing forward while jumping
      return BrainDecision(movement: _norm(Vector2(forward, 0)), castSkill: false, jump: true, intent: CombatIntent.dodge);
    }

    // ── chase onto platform ───────────────────────────────────────────────
    final ArenaPlatform? targetPlatform = _platformUnder(target, arena);
    final ArenaPlatform? myPlatform     = _platformUnder(self, arena);

    if (targetPlatform != null && myPlatform == null && _jumpCooldown <= 0 && self.onGround) {
      final double dx = target.position.x - self.position.x;
      moveX = dx.sign;
      if (dx.abs() < 55) {
        jump = true;
        _jumpCooldown = 1.0;
      }
      return BrainDecision(
        movement: _norm(Vector2(moveX, 0)),
        castSkill: false,
        jump: jump,
        intent: CombatIntent.ambush,
      );
    }

    // ── phase transitions — bruiser almost never backs off ────────────────
    switch (_phase) {
      case _Phase.approach:
      case _Phase.reposition:
        if (distance <= attackRange + 10) {
          _phase = _Phase.engage;
          _phaseTimer = _engageDurationBruiser();
        }

      case _Phase.engage:
        if (_phaseTimer <= 0) {
          // Bruiser only backs off when hit hard AND low hp
          if (hitThisFrame && hpRatio < 0.4 && _random.nextDouble() < 0.25) {
            _startBackOff();
          } else {
            _phaseTimer = _engageDurationBruiser(); // keep punching
          }
        }

      case _Phase.backOff:
        if (_phaseTimer <= 0) {
          _phase = _Phase.approach;
          _phaseTimer = 0.2;
        }

      default: break;
    }

    // Bruiser gets MORE aggressive when hurt (berserker mode)
    final bool berserker = hpRatio < 0.45;

    moveX = switch (_phase) {
      _Phase.approach   => berserker ? forward * 1.0 : forward * 0.9,
      _Phase.reposition => forward * 0.85 + _feintDir * 0.2,
      _Phase.engage     => (distance > attackRange) ? forward : (berserker ? forward * 0.2 : _feintDir * 0.15),
      _Phase.backOff    => berserker ? -forward * 0.4 : -forward * 0.7,  // berserker barely retreats
      _Phase.flee       => -forward * 0.6,
      _Phase.platformSeek => forward,
      _Phase.bait       => -forward * 0.3,
      _Phase.pressure   => forward,
    };

    // Full berserker: never back off, always in face
    if (berserker && _phase == _Phase.backOff) {
      _phase = _Phase.engage;
      _phaseTimer = _engageDurationBruiser();
      moveX = (distance > attackRange) ? forward : _feintDir * 0.1;
    }

    // Skill: bruiser uses skill when deep in melee (max damage)
    final double castChance = (0.025 + confidence * 0.04) * definition.skillUsageBias;
    final bool castSkill = self.skillReady &&
        distance <= attackRange * 1.1 &&
        (_random.nextDouble() < castChance || targetHpRatio < 0.25 || berserker);

    return BrainDecision(
      movement: _norm(Vector2(moveX.clamp(-1, 1), 0)),
      castSkill: castSkill,
      jump: jump,
      intent: berserker
          ? CombatIntent.execute
          : switch (_phase) {
              _Phase.approach    => CombatIntent.advance,
              _Phase.reposition  => CombatIntent.advance,
              _Phase.engage      => CombatIntent.commit,
              _Phase.pressure    => CombatIntent.commit,
              _Phase.backOff     => CombatIntent.retreat,
              _Phase.flee        => CombatIntent.retreat,
              _Phase.bait        => CombatIntent.bait,
              _Phase.platformSeek => CombatIntent.ambush,
            },
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _startBackOff() {
    _phase = _Phase.backOff;
    _phaseTimer = 0.22 + _random.nextDouble() * 0.18;
  }

  double _engageDurationSword()   => 0.55 + _random.nextDouble() * 0.45;
  double _engageDurationBruiser() => 0.80 + _random.nextDouble() * 0.50;
  double _phaseDurationMage(_Phase p) => switch (p) {
    _Phase.flee        => 0.4 + _random.nextDouble() * 0.3,
    _Phase.bait        => 0.45 + _random.nextDouble() * 0.3,
    _Phase.engage      => 0.6 + _random.nextDouble() * 0.4,
    _Phase.backOff     => 0.25 + _random.nextDouble() * 0.2,
    _Phase.pressure    => 0.35 + _random.nextDouble() * 0.2,
    _Phase.approach    => 0.7 + _random.nextDouble() * 0.5,
    _Phase.reposition  => 0.3 + _random.nextDouble() * 0.2,
    _Phase.platformSeek => 0.6,
  };

  /// Jump over a projectile heading straight at us.
  bool _shouldJumpOver(
    FighterComponent self,
    Iterable<ProjectileComponent> projectiles,
  ) {
    if (_hitCooldown > 0) return false;
    for (final ProjectileComponent p in projectiles) {
      if (p.ownerTeam == self.team) continue;
      final Vector2 offset = self.position - p.position;
      if (offset.length > 130) continue;
      final Vector2 velDir = p.velocity.normalized();
      // Projectile is aimed at us (dot product > threshold)
      if (velDir.dot(offset.normalized()) > 0.60) {
        _hitCooldown = 0.5;
        return true;
      }
    }
    return false;
  }

  /// Returns the platform the character is currently standing on, or null.
  ArenaPlatform? _platformUnder(FighterComponent f, BattleArena arena) {
    for (final ArenaPlatform p in arena.platforms) {
      if (f.position.x >= p.left && f.position.x <= p.right) {
        if ((f.position.y - p.top).abs() < 8) return p;
      }
    }
    return null;
  }

  /// Nearest platform on a preferred side (-1 = left, 1 = right, 0 = any).
  ArenaPlatform? _nearestPlatform(FighterComponent self, BattleArena arena, {double preferSide = 0}) {
    ArenaPlatform? best;
    double bestDist = double.infinity;
    for (final ArenaPlatform p in arena.platforms) {
      final double d = (p.centerX - self.position.x).abs();
      final bool sidePref = preferSide == 0 || (p.centerX - self.position.x).sign == preferSide;
      if (sidePref && d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best ?? (arena.platforms.isNotEmpty ? arena.platforms.first : null);
  }

  Vector2 _norm(Vector2 v) =>
      v.length2 > 0.01 ? (v..normalize()) : Vector2.zero();
}

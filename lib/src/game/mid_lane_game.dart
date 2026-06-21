import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import 'attack_effect_component.dart';
import 'battle_arena.dart';
import 'battle_brain.dart';
import 'fighter_component.dart';
import 'minion_component.dart';
import 'projectile_component.dart';
import 'skill_telegraph_component.dart';
import 'tower_component.dart';

class MidLaneGame extends FlameGame {
  static const double _gravity = 920;
  static const double _terminalVelocity = 540;

  MidLaneGame({
    required this.config,
    required this.onBattleFinished,
  })  : hud = ValueNotifier<BattleHudData>(
          BattleHudData(
            round: config.round,
            playerDefinition: config.playerDefinition,
            enemyDefinition: config.enemyDefinition,
            playerHp: config.playerStats.maxHp,
            playerMaxHp: config.playerStats.maxHp,
            enemyHp: config.enemyStats.maxHp,
            enemyMaxHp: config.enemyStats.maxHp,
            playerSkillReady: true,
            enemySkillReady: true,
          ),
        ),
        _playerBrain = DuelBrain(Random(1)),
        _enemyBrain = DuelBrain(Random(2));

  final BattleConfig config;
  final void Function(bool playerWon) onBattleFinished;
  final ValueNotifier<BattleHudData> hud;
  final DuelBrain _playerBrain;
  final DuelBrain _enemyBrain;

  late final FighterComponent player;
  late final FighterComponent enemy;
  late final TowerComponent playerTower;
  late final TowerComponent enemyTower;

  final List<MinionComponent> _playerMinions = <MinionComponent>[];
  final List<MinionComponent> _enemyMinions = <MinionComponent>[];
  final List<_PendingSkill> _pendingSkills = <_PendingSkill>[];

  RectangleComponent? _arenaBase;
  SpriteComponent? _backdrop;
  bool _resolved = false;

  // ── Dead-Cells feel ───────────────────────────────────────────────────────
  double _hitStopTimer    = 0; // freeze everything while > 0
  double _shakeTimer      = 0;
  double _shakeDuration   = 0;
  double _shakeIntensity  = 0;

  BattleArena get _arena => BattleArena(size);

  @override
  Future<void> onLoad() async {
    // Must be set before any sprite/image load in this game or its children.
    images.prefix = 'assets/';
    await super.onLoad();
    _arenaBase = RectangleComponent(
      position: Vector2.zero(),
      size: size,
      paint: Paint()..color = const Color(0xFF0B1825),
    );

    add(_arenaBase!);
    final Sprite backdropSprite = await loadSprite('game/tiles/arena_scene.png');
    _backdrop = SpriteComponent(
      sprite: backdropSprite,
      position: Vector2.zero(),
      size: size.clone(),
      anchor: Anchor.topLeft,
    );
    add(_backdrop!);

    // Floating platforms
    for (final ArenaPlatform p in _arena.platforms) {
      add(RectangleComponent(
        position: Vector2(p.left, p.top),
        size: Vector2(p.width, 10),
        paint: Paint()..color = const Color(0xFF5C4A2A),
      ));
      // Top highlight
      add(RectangleComponent(
        position: Vector2(p.left, p.top),
        size: Vector2(p.width, 3),
        paint: Paint()..color = const Color(0xFF8B6F47),
      ));
    }

    playerTower = TowerComponent(
      team: FighterTeam.player,
      position: _arena.playerTowerSpawn(),
    );
    enemyTower = TowerComponent(
      team: FighterTeam.enemy,
      position: _arena.enemyTowerSpawn(),
    );
    add(playerTower);
    add(enemyTower);

    player = FighterComponent(
      label: config.playerName,
      archetype: config.playerDefinition.archetype,
      stats: config.playerStats,
      team: FighterTeam.player,
      position: _arena.playerSpawn(),
    );
    enemy = FighterComponent(
      label: config.enemyName,
      archetype: config.enemyDefinition.archetype,
      stats: config.enemyStats,
      team: FighterTeam.enemy,
      position: _arena.enemySpawn(),
    );
    player.lookAt(enemy.position);
    enemy.lookAt(player.position);

    add(player);
    add(enemy);
    _spawnMinions();
  }

  void _spawnMinions() {
    for (final Vector2 position in _arena.playerMeleeMinionSpawns()) {
      final MinionComponent minion = MinionComponent(
        team: FighterTeam.player,
        type: MinionType.melee,
        position: position,
        maxHp: 40,
        attackDamage: 4,
        attackRange: 26,
        attackCooldown: 1.0,
        moveSpeed: 58,
      );
      _playerMinions.add(minion);
      add(minion);
    }
    for (final Vector2 position in _arena.playerRangedMinionSpawns()) {
      final MinionComponent minion = MinionComponent(
        team: FighterTeam.player,
        type: MinionType.ranged,
        position: position,
        maxHp: 28,
        attackDamage: 3,
        attackRange: 138,
        attackCooldown: 1.3,
        moveSpeed: 50,
      );
      _playerMinions.add(minion);
      add(minion);
    }
    for (final Vector2 position in _arena.enemyMeleeMinionSpawns()) {
      final MinionComponent minion = MinionComponent(
        team: FighterTeam.enemy,
        type: MinionType.melee,
        position: position,
        maxHp: 40,
        attackDamage: 4,
        attackRange: 26,
        attackCooldown: 1.0,
        moveSpeed: 58,
      );
      _enemyMinions.add(minion);
      add(minion);
    }
    for (final Vector2 position in _arena.enemyRangedMinionSpawns()) {
      final MinionComponent minion = MinionComponent(
        team: FighterTeam.enemy,
        type: MinionType.ranged,
        position: position,
        maxHp: 28,
        attackDamage: 3,
        attackRange: 138,
        attackCooldown: 1.3,
        moveSpeed: 50,
      );
      _enemyMinions.add(minion);
      add(minion);
    }
  }

  void setInput(Vector2 input) {}

  void castPlayerSkill() {}

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _arenaBase?.size = size;
    _backdrop?.size = size;
  }

  void _triggerHitStop(double duration) {
    if (duration > _hitStopTimer) _hitStopTimer = duration;
  }

  void _triggerShake({double duration = 0.14, double intensity = 5}) {
    _shakeTimer     = duration;
    _shakeDuration  = duration;
    _shakeIntensity = intensity;
  }

  void _updateShake(double dt) {
    if (_shakeTimer <= 0) return;
    _shakeTimer -= dt;
    if (_shakeTimer <= 0) {
      camera.viewfinder.position = Vector2.zero();
      return;
    }
    final double strength = _shakeIntensity * (_shakeTimer / _shakeDuration);
    final Random rng = Random();
    camera.viewfinder.position = Vector2(
      (rng.nextDouble() - 0.5) * strength * 2,
      (rng.nextDouble() - 0.5) * strength * 2,
    );
  }

  @override
  void update(double dt) {
    // Hit stop: freeze the entire simulation (components stop updating too).
    if (_hitStopTimer > 0) {
      _hitStopTimer -= dt;
      _updateShake(dt);
      _publishHud();
      return; // skip super.update — all children freeze
    }
    _updateShake(dt);
    super.update(dt);
    if (_resolved || !isLoaded) {
      return;
    }

    player.tickCooldowns(dt);
    enemy.tickCooldowns(dt);
    playerTower.tickCooldowns(dt);
    enemyTower.tickCooldowns(dt);
    for (final MinionComponent minion in _allMinions()) {
      minion.tickCooldowns(dt);
    }

    _applyFighterPhysics(player, dt);
    _applyFighterPhysics(enemy, dt);
    _updatePendingSkills(dt);
    _updatePlayer(dt);
    _updateEnemy(dt);
    _resolveFighterSupport(player);
    _resolveFighterSupport(enemy);
    _separateFighters();
    _updateMinions(dt);
    _updateTowers();
    _updateFighterBasicAttack(
      attacker: player,
      definition: config.playerDefinition,
      target: enemy,
      color: const Color(0xFFB4F8C8),
    );
    _updateFighterBasicAttack(
      attacker: enemy,
      definition: config.enemyDefinition,
      target: player,
      color: const Color(0xFFFFD180),
    );
    _checkProjectileHits();
    _cleanupProjectiles();
    _cleanupDefeatedMinions();
    _publishHud();
    _checkBattleEnd();
  }

  static const double _jumpForce = 480.0;

  void _applyBrainDecision({
    required FighterComponent fighter,
    required FighterComponent target,
    required BrainDecision decision,
    required Color skillColor,
    required ArchetypeDefinition definition,
  }) {
    final double horizontal = decision.movement.x.clamp(-1.0, 1.0);
    if (horizontal.abs() > 0.01) {
      double h = horizontal;
      if (fighter.position.x <= _arena.fighterBounds.left + fighter.collisionRadius && h < 0) h = 0;
      if (fighter.position.x >= _arena.fighterBounds.right - fighter.collisionRadius && h > 0) h = 0;
      fighter.moveHorizontally(h * fighter.stats.moveSpeed * _dt, _arena.fighterBounds);
      fighter.lookAt(target.position);
    } else {
      fighter.stopMoving();
    }
    if (decision.jump) fighter.jump(_jumpForce);
    if (decision.castSkill) {
      _queueSkill(
        from: fighter,
        targetFighter: target,
        definition: definition,
        color: skillColor,
        intent: decision.intent,
      );
    }
  }

  double _dt = 0;

  void _updatePlayer(double dt) {
    _dt = dt;
    final BrainDecision autoDecision = _playerBrain.decide(
      self: player,
      target: enemy,
      definition: config.playerDefinition,
      projectiles: children.whereType<ProjectileComponent>(),
      arena: _arena,
      confidence: config.playerAiConfidence,
      dt: dt,
    );
    _applyBrainDecision(
      fighter: player,
      target: enemy,
      decision: autoDecision,
      skillColor: const Color(0xFFB4F8C8),
      definition: config.playerDefinition,
    );
  }

  void _updateEnemy(double dt) {
    _dt = dt;
    final BrainDecision decision = _enemyBrain.decide(
      self: enemy,
      target: player,
      definition: config.enemyDefinition,
      projectiles: children.whereType<ProjectileComponent>(),
      arena: _arena,
      confidence: config.enemyAiConfidence,
      dt: dt,
    );
    _applyBrainDecision(
      fighter: enemy,
      target: player,
      decision: decision,
      skillColor: const Color(0xFFFFD180),
      definition: config.enemyDefinition,
    );
  }

  void _updateTowers() {
    _updateTower(playerTower);
    _updateTower(enemyTower);
  }

  void _updateTower(TowerComponent tower) {
    if (!tower.isAlive || !tower.attackReady) {
      return;
    }
    final Object? target = _findNearestEnemyTarget(
      team: tower.team,
      origin: tower.position,
      maxDistance: tower.attackRange,
      includeTowers: false,
    );
    if (target == null) {
      return;
    }
    _spawnProjectile(
      fromTeam: tower.team,
      start: tower.position,
      target: _targetPosition(target),
      speed: 250,
      damage: tower.attackDamage,
      radius: 7,
      color: const Color(0xFFEF6C00),
      kind: ProjectileKind.cannon,
      maxTravelDistance: tower.attackRange + 28,
      hitsFighters: true,
      hitsMinions: true,
    );
    tower.resetAttackTimer();
  }

  void _updateMinions(double dt) {
    for (final MinionComponent minion in _allMinions()) {
      if (!minion.isAlive) {
        continue;
      }
      final Object? target = _findNearestEnemyTarget(
        team: minion.team,
        origin: minion.position,
        maxDistance: minion.type == MinionType.melee ? 42 : 150,
        includeTowers: true,
      );

      if (target != null) {
        final Vector2 targetPosition = _targetPosition(target);
        final double distance = minion.position.distanceTo(targetPosition);
        if (distance <= minion.attackRange + _targetRadius(target)) {
          minion.lookAt(targetPosition);
          minion.stopMoving();
          _minionAttack(minion, target);
          continue;
        }
      }

      final double xDirection = minion.team == FighterTeam.player ? 1 : -1;
      minion.moveHorizontally(xDirection * minion.moveSpeed * dt, _arena.bounds);
      final double supportY = _arena.supportYFor(
        previousY: minion.position.y,
        position: minion.position,
        radius: minion.collisionRadius,
      );
      minion.moveVerticallyTowards(supportY, dt);
    }
  }

  void _applyFighterPhysics(FighterComponent fighter, double dt) {
    fighter.applyGravity(dt, _gravity, _terminalVelocity);
  }

  void _resolveFighterSupport(FighterComponent fighter) {
    final double supportY = _arena.supportYFor(
      previousY: fighter.previousY,
      position: fighter.position,
      radius: fighter.collisionRadius,
    );
    if (fighter.position.y >= supportY && fighter.velocity.y >= 0) {
      fighter.landOn(supportY);
    }
  }

  /// Push the two fighters apart when they physically overlap.
  void _separateFighters() {
    final double minDist = player.collisionRadius + enemy.collisionRadius + 4;
    final Vector2 delta = player.position - enemy.position;
    final double dist = delta.length;
    if (dist < minDist && dist > 0.001) {
      final Vector2 push = delta / dist * ((minDist - dist) * 0.5);
      player.position.add(push);
      enemy.position.sub(push);
      // Clamp back into arena bounds.
      player.position.x = player.position.x.clamp(
          _arena.fighterBounds.left + player.collisionRadius,
          _arena.fighterBounds.right - player.collisionRadius);
      enemy.position.x = enemy.position.x.clamp(
          _arena.fighterBounds.left + enemy.collisionRadius,
          _arena.fighterBounds.right - enemy.collisionRadius);
      // Keep Y on the ground line (push vector may have Y component).
      player.position.y = player.position.y.clamp(0, _arena.groundY);
      enemy.position.y = enemy.position.y.clamp(0, _arena.groundY);
    }
  }

  void _minionAttack(MinionComponent minion, Object target) {
    if (!minion.attackReady) {
      return;
    }
    if (minion.type == MinionType.ranged) {
      _spawnProjectile(
        fromTeam: minion.team,
        start: minion.position,
        target: _targetPosition(target),
        speed: 220,
        damage: minion.attackDamage,
        radius: 4,
        color: minion.team == FighterTeam.player
            ? const Color(0xFFB3E5FC)
            : const Color(0xFFFFCC80),
        kind: ProjectileKind.minionBolt,
        maxTravelDistance: minion.attackRange + 24,
        hitsFighters: true,
        hitsMinions: true,
        hitsStructures: true,
      );
    } else {
      _applyDamage(target, minion.attackDamage);
      add(
        AttackEffectComponent(
          position: minion.position.clone(),
          direction: minion.facing,
          color: const Color(0xFFE8F0FE),
          isPunch: true,
        ),
      );
    }
    minion.resetAttackTimer();
  }

  void _updateFighterBasicAttack({
    required FighterComponent attacker,
    required ArchetypeDefinition definition,
    required FighterComponent target,
    required Color color,
  }) {
    if (!attacker.isAlive || !target.isAlive || attacker.attackTimer > 0) {
      return;
    }
    final Object? attackTarget = _findFighterAttackTarget(
      attacker: attacker,
      enemyFighter: target,
    );
    if (attackTarget == null) {
      return;
    }
    final Vector2 targetPosition = _targetPosition(attackTarget);

    attacker.lookAt(targetPosition);
    switch (definition.attackStyle) {
      case AttackStyle.bowShot:
        _spawnProjectile(
          fromTeam: attacker.team,
          start: attacker.position,
          target: targetPosition,
          speed: 285,
          damage: attacker.stats.attackDamage,
          radius: 4,
          color: color,
          kind: ProjectileKind.arrow,
          maxTravelDistance: attacker.stats.attackRange + 26,
          hitsFighters: true,
          hitsMinions: true,
        );
      case AttackStyle.swordSwing:
        _applyDamage(attackTarget, attacker.stats.attackDamage);
        add(AttackEffectComponent(
          position: attacker.position.clone(),
          direction: attacker.facing,
          color: color,
          isPunch: false,
        ));
        _triggerHitStop(0.07);
        _triggerShake(intensity: 4.5);
      case AttackStyle.fistSwing:
        _applyDamage(attackTarget, attacker.stats.attackDamage);
        add(AttackEffectComponent(
          position: attacker.position.clone(),
          direction: attacker.facing,
          color: color,
          isPunch: true,
        ));
        _triggerHitStop(0.08);
        _triggerShake(intensity: 5.5);
    }
    attacker.resetAttackTimer();
  }

  Object? _findFighterAttackTarget({
    required FighterComponent attacker,
    required FighterComponent enemyFighter,
  }) {
    final double range = attacker.stats.attackRange;
    final double enemyDistance = attacker.position.distanceTo(enemyFighter.position);
    final bool canExecute =
        enemyFighter.hp / enemyFighter.stats.maxHp < 0.28 && enemyDistance <= range + 18;
    if (canExecute) {
      return enemyFighter;
    }

    Object? bestTarget;
    double bestDistance = range;
    for (final MinionComponent minion in _enemyMinionsFor(attacker.team)) {
      if (!minion.isAlive) {
        continue;
      }
      final double distance = attacker.position.distanceTo(minion.position);
      if (distance <= bestDistance + minion.collisionRadius) {
        bestDistance = distance;
        bestTarget = minion;
      }
    }

    if (bestTarget != null) {
      return bestTarget;
    }
    if (enemyFighter.isAlive && enemyDistance <= range + enemyFighter.collisionRadius) {
      return enemyFighter;
    }
    return null;
  }

  bool _hasPendingSkill(FighterComponent fighter) {
    return _pendingSkills.any((_PendingSkill skill) => skill.caster == fighter);
  }

  void _queueSkill({
    required FighterComponent from,
    required FighterComponent targetFighter,
    required ArchetypeDefinition definition,
    required Color color,
    required CombatIntent intent,
  }) {
    if (!from.skillReady || _hasPendingSkill(from)) {
      return;
    }
    from.lookAt(targetFighter.position);
    from.resetSkillTimer();
    final double windup = switch (definition.attackStyle) {
      AttackStyle.bowShot => 0.62,
      AttackStyle.swordSwing => 0.46,
      AttackStyle.fistSwing => 0.54,
    };
    final double threatRadius = switch (definition.attackStyle) {
      AttackStyle.bowShot => from.stats.skillRadius,
      AttackStyle.swordSwing => from.stats.skillRadius * 2.7,
      AttackStyle.fistSwing => from.stats.skillRadius * 3.2,
    };
    final Vector2 targetPosition = targetFighter.position.clone();
    _pendingSkills.add(
      _PendingSkill(
        caster: from,
        targetFighter: targetFighter,
        targetPosition: targetPosition,
        definition: definition,
        color: color,
        remaining: windup,
        radius: threatRadius,
        intent: intent,
      ),
    );

    if (definition.attackStyle == AttackStyle.bowShot) {
      add(
        SkillTelegraphComponent.line(
          start: from.position,
          end: targetPosition,
          color: color,
          duration: windup,
        ),
      );
    } else {
      add(
        SkillTelegraphComponent.area(
          center: from.position + Vector2(from.facing.x * 28, 0),
          radius: threatRadius,
          color: color,
          duration: windup,
        ),
      );
    }
  }

  void _updatePendingSkills(double dt) {
    for (final _PendingSkill skill in _pendingSkills.toList()) {
      skill.remaining -= dt;
      if (skill.remaining > 0) {
        continue;
      }
      _pendingSkills.remove(skill);
      if (!skill.caster.isAlive) {
        continue;
      }
      _resolveSkill(skill);
    }
  }

  void _resolveSkill(_PendingSkill skill) {
    final FighterComponent from = skill.caster;
    final FighterComponent targetFighter = skill.targetFighter;
    final ArchetypeDefinition definition = skill.definition;
    final Color color = skill.color;
    from.lookAt(skill.targetPosition);

    switch (definition.attackStyle) {
      case AttackStyle.bowShot:
        // Archer: fire a fast skill-shot projectile.
        _spawnProjectile(
          fromTeam: from.team,
          start: from.position,
          target: skill.targetPosition,
          speed: from.stats.skillSpeed,
          damage: from.stats.skillDamage,
          radius: from.stats.skillRadius,
          color: color,
          kind: ProjectileKind.skillShot,
          maxTravelDistance: 340,
          hitsFighters: true,
          hitsMinions: true,
        );

      case AttackStyle.swordSwing:
        final double aoeRadius = skill.radius;
        final Vector2 impactCenter = from.position + Vector2(from.facing.x * 28, 0);
        if (targetFighter.isAlive &&
            impactCenter.distanceTo(targetFighter.position) <=
                aoeRadius + targetFighter.collisionRadius) {
          targetFighter.receiveDamage(from.stats.skillDamage);
          _triggerHitStop(0.12);
          _triggerShake(intensity: 7.0);
        }
        for (final MinionComponent minion in _enemyMinionsFor(from.team)) {
          if (minion.isAlive &&
              impactCenter.distanceTo(minion.position) <= aoeRadius + minion.collisionRadius) {
            minion.receiveDamage(from.stats.skillDamage * 0.6);
          }
        }
        add(AttackEffectComponent(
          position: from.position.clone(),
          direction: from.facing,
          color: color,
          isPunch: false,
        ));

      case AttackStyle.fistSwing:
        final double aoeRadiusFist = skill.radius;
        final Vector2 impactCenter = from.position + Vector2(from.facing.x * 24, 0);
        if (targetFighter.isAlive &&
            impactCenter.distanceTo(targetFighter.position) <=
                aoeRadiusFist + targetFighter.collisionRadius) {
          targetFighter.receiveDamage(from.stats.skillDamage);
          _triggerHitStop(0.14);
          _triggerShake(intensity: 9.0);
        }
        for (final MinionComponent minion in _enemyMinionsFor(from.team)) {
          if (minion.isAlive &&
              impactCenter.distanceTo(minion.position) <=
                  aoeRadiusFist + minion.collisionRadius) {
            minion.receiveDamage(from.stats.skillDamage * 0.7);
          }
        }
        add(AttackEffectComponent(
          position: from.position.clone(),
          direction: from.facing,
          color: color,
          isPunch: true,
        ));
    }
    from.resetAttackTimer();
  }

  void _spawnProjectile({
    required FighterTeam fromTeam,
    required Vector2 start,
    required Vector2 target,
    required double speed,
    required double damage,
    required double radius,
    required Color color,
    required ProjectileKind kind,
    required double maxTravelDistance,
    required bool hitsFighters,
    required bool hitsMinions,
    bool hitsStructures = false,
  }) {
    final Vector2 raw = target - start;
    final Vector2 direction = raw.length2 > 0.01 ? raw.normalized() : Vector2(0, -1);
    final ProjectileComponent projectile = ProjectileComponent(
      damage: damage,
      velocity: direction * speed,
      position: start + direction * 20,
      radius: radius,
      color: color,
      ownerTeam: fromTeam,
      kind: kind,
      maxTravelDistance: maxTravelDistance,
      hitsFighters: hitsFighters,
      hitsMinions: hitsMinions,
      hitsStructures: hitsStructures,
    );
    add(projectile);
  }

  void _checkProjectileHits() {
    final List<ProjectileComponent> projectiles =
        children.whereType<ProjectileComponent>().toList();
    for (final ProjectileComponent projectile in projectiles) {
      if (projectile.hitsMinions) {
        for (final MinionComponent minion in _enemyMinionsFor(projectile.ownerTeam)) {
          if (!minion.isAlive) {
            continue;
          }
          if (_projectileHits(projectile, minion.position, minion.collisionRadius)) {
            minion.receiveDamage(projectile.damage);
            projectile.removeFromParent();
            break;
          }
        }
      }
      if (projectile.isRemoving) {
        continue;
      }
      if (projectile.hitsFighters) {
        final FighterComponent target =
            projectile.ownerTeam == FighterTeam.player ? enemy : player;
        if (target.isAlive &&
            _projectileHits(projectile, target.position, target.collisionRadius)) {
          target.receiveDamage(projectile.damage);
          projectile.removeFromParent();
          _triggerHitStop(0.055);
          _triggerShake(intensity: 3.0);
          continue;
        }
      }
      if (projectile.hitsStructures) {
        final TowerComponent tower =
            projectile.ownerTeam == FighterTeam.player ? enemyTower : playerTower;
        if (tower.isAlive &&
            _projectileHits(projectile, tower.position, tower.collisionRadius)) {
          tower.receiveDamage(projectile.damage);
          projectile.removeFromParent();
        }
      }
    }
  }

  bool _projectileHits(
    ProjectileComponent projectile,
    Vector2 targetPosition,
    double targetRadius,
  ) {
    return projectile.position.distanceTo(targetPosition) <= targetRadius + projectile.radius;
  }

  void _cleanupProjectiles() {
    final Rect bounds = _arena.bounds.inflate(40);
    final List<ProjectileComponent> projectiles =
        children.whereType<ProjectileComponent>().toList();
    for (final ProjectileComponent projectile in projectiles) {
      final bool outOfBounds =
          !bounds.contains(Offset(projectile.position.x, projectile.position.y));
      if (outOfBounds || projectile.exceededTravelDistance) {
        projectile.removeFromParent();
      }
    }
  }

  void _cleanupDefeatedMinions() {
    _playerMinions.removeWhere((MinionComponent minion) {
      final bool defeated = !minion.isAlive;
      if (defeated) {
        minion.removeFromParent();
      }
      return defeated;
    });
    _enemyMinions.removeWhere((MinionComponent minion) {
      final bool defeated = !minion.isAlive;
      if (defeated) {
        minion.removeFromParent();
      }
      return defeated;
    });
  }

  Iterable<MinionComponent> _allMinions() sync* {
    yield* _playerMinions;
    yield* _enemyMinions;
  }

  List<MinionComponent> _enemyMinionsFor(FighterTeam team) {
    return team == FighterTeam.player ? _enemyMinions : _playerMinions;
  }

  Object? _findNearestEnemyTarget({
    required FighterTeam team,
    required Vector2 origin,
    required double maxDistance,
    required bool includeTowers,
  }) {
    Object? bestTarget;
    double bestDistance = maxDistance;

    for (final MinionComponent minion in _enemyMinionsFor(team)) {
      if (!minion.isAlive) {
        continue;
      }
      final double distance = origin.distanceTo(minion.position);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestTarget = minion;
      }
    }

    final FighterComponent fighter = team == FighterTeam.player ? enemy : player;
    if (fighter.isAlive) {
      final double distance = origin.distanceTo(fighter.position);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestTarget = fighter;
      }
    }

    if (includeTowers) {
      final TowerComponent tower = team == FighterTeam.player ? enemyTower : playerTower;
      if (tower.isAlive) {
        final double distance = origin.distanceTo(tower.position);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestTarget = tower;
        }
      }
    }

    return bestTarget;
  }

  Vector2 _targetPosition(Object target) {
    if (target is FighterComponent) {
      return target.position;
    }
    if (target is MinionComponent) {
      return target.position;
    }
    return (target as TowerComponent).position;
  }

  double _targetRadius(Object target) {
    if (target is FighterComponent) {
      return target.collisionRadius;
    }
    if (target is MinionComponent) {
      return target.collisionRadius;
    }
    return (target as TowerComponent).collisionRadius;
  }

  void _applyDamage(Object target, double damage) {
    if (target is FighterComponent) {
      target.receiveDamage(damage);
      return;
    }
    if (target is MinionComponent) {
      target.receiveDamage(damage);
      return;
    }
    (target as TowerComponent).receiveDamage(damage);
  }

  void _publishHud() {
    hud.value = BattleHudData(
      round: config.round,
      playerDefinition: config.playerDefinition,
      enemyDefinition: config.enemyDefinition,
      playerHp: player.hp,
      playerMaxHp: player.stats.maxHp,
      enemyHp: enemy.hp,
      enemyMaxHp: enemy.stats.maxHp,
      playerSkillReady: player.skillReady,
      enemySkillReady: enemy.skillReady,
    );
  }

  void _checkBattleEnd() {
    if (_resolved) {
      return;
    }
    if (!enemy.isAlive) {
      _resolved = true;
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        onBattleFinished(true);
      });
    } else if (!player.isAlive) {
      _resolved = true;
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        onBattleFinished(false);
      });
    }
  }
}

class _PendingSkill {
  _PendingSkill({
    required this.caster,
    required this.targetFighter,
    required this.targetPosition,
    required this.definition,
    required this.color,
    required this.remaining,
    required this.radius,
    required this.intent,
  });

  final FighterComponent caster;
  final FighterComponent targetFighter;
  final Vector2 targetPosition;
  final ArchetypeDefinition definition;
  final Color color;
  final double radius;
  final CombatIntent intent;
  double remaining;
}

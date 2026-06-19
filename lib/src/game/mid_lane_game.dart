import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import 'battle_arena.dart';
import 'battle_brain.dart';
import 'fighter_component.dart';
import 'projectile_component.dart';

class MidLaneGame extends FlameGame {
  MidLaneGame({
    required this.config,
    required this.onBattleFinished,
  })  : hud = ValueNotifier<BattleHudData>(
          BattleHudData(
            round: config.round,
            playerName: config.playerName,
            enemyName: config.enemyName,
            playerHp: config.playerStats.maxHp,
            playerMaxHp: config.playerStats.maxHp,
            enemyHp: config.enemyStats.maxHp,
            enemyMaxHp: config.enemyStats.maxHp,
            playerSkillReady: true,
            enemySkillReady: true,
            playerWeapon: config.playerDefinition.weaponLabel,
            enemyWeapon: config.enemyDefinition.weaponLabel,
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

  RectangleComponent? _arenaBase;
  RectangleComponent? _arenaBorder;
  bool _resolved = false;
  Vector2 _playerInput = Vector2.zero();

  BattleArena get _arena => BattleArena(size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _arenaBase = RectangleComponent(
      position: Vector2.zero(),
      size: size,
      paint: Paint()..color = const Color(0xFF0B1825),
    );
    _arenaBorder = RectangleComponent(
      position: Vector2(24, 24),
      size: Vector2(size.x - 48, size.y - 48),
      paint: Paint()
        ..color = const Color(0x00000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    add(_arenaBase!);
    add(
      RectangleComponent(
        position: Vector2(24, size.y * 0.5 - 28),
        size: Vector2(size.x - 48, 56),
        paint: Paint()..color = const Color(0xFF13273A),
      ),
    );
    add(_arenaBorder!);

    player = FighterComponent(
      label: config.playerName,
      stats: config.playerStats,
      bodyColor: Color(config.playerDefinition.colorValue),
      team: FighterTeam.player,
      position: _arena.playerSpawn(),
    );
    enemy = FighterComponent(
      label: config.enemyName,
      stats: config.enemyStats,
      bodyColor: Color(config.enemyColorValue),
      team: FighterTeam.enemy,
      position: _arena.enemySpawn(),
    );
    player.lookAt(enemy.position);
    enemy.lookAt(player.position);

    add(player);
    add(enemy);
  }

  void setInput(Vector2 input) {
    _playerInput = input.length2 > 0.01 ? input.normalized() : Vector2.zero();
  }

  void castPlayerSkill() {
    if (_resolved || !player.isAlive || !player.skillReady) {
      return;
    }
    _castSkill(from: player, target: enemy.position, color: const Color(0xFFB4F8C8));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _arenaBase?.size = size;
    final RectangleComponent? border = _arenaBorder;
    if (border != null) {
      border.position = Vector2(24, 24);
      border.size = Vector2(size.x - 48, size.y - 48);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_resolved || !isLoaded) {
      return;
    }

    player.tickCooldowns(dt);
    enemy.tickCooldowns(dt);

    _updatePlayer(dt);
    _updateEnemy(dt);
    _updateAutoAttacks();
    _checkProjectileHits();
    _cleanupProjectiles();
    _publishHud();
    _checkBattleEnd();
  }

  void _updatePlayer(double dt) {
    final BrainDecision autoDecision = _playerBrain.decide(
      self: player,
      target: enemy,
      definition: config.playerDefinition,
      projectiles: children.whereType<ProjectileComponent>(),
      confidence: config.playerAiConfidence,
      dt: dt,
    );
    Vector2 movement = autoDecision.movement + _playerInput * 1.25;
    if (movement.length2 > 0.01) {
      movement = movement.normalized();
      player.moveBy(movement * player.stats.moveSpeed * dt, _arena.bounds);
      player.lookAt(enemy.position);
    }
    if (autoDecision.castSkill) {
      _castSkill(from: player, target: enemy.position, color: const Color(0xFFB4F8C8));
    }
  }

  void _updateEnemy(double dt) {
    final BrainDecision decision = _enemyBrain.decide(
      self: enemy,
      target: player,
      definition: config.enemyDefinition,
      projectiles: children.whereType<ProjectileComponent>(),
      confidence: config.enemyAiConfidence,
      dt: dt,
    );
    if (decision.movement.length2 > 0.01) {
      enemy.moveBy(decision.movement * enemy.stats.moveSpeed * dt, _arena.bounds);
    }
    enemy.lookAt(player.position);
    if (decision.castSkill) {
      _castSkill(from: enemy, target: player.position, color: const Color(0xFFFFD180));
    }
  }

  void _updateAutoAttacks() {
    final double distance = player.position.distanceTo(enemy.position);
    if (player.attackTimer <= 0 && distance <= player.stats.attackRange && enemy.isAlive) {
      enemy.receiveDamage(player.stats.attackDamage);
      player.lookAt(enemy.position);
      player.resetAttackTimer();
    }
    if (enemy.attackTimer <= 0 && distance <= enemy.stats.attackRange && player.isAlive) {
      player.receiveDamage(enemy.stats.attackDamage);
      enemy.lookAt(player.position);
      enemy.resetAttackTimer();
    }
  }

  void _castSkill({
    required FighterComponent from,
    required Vector2 target,
    required Color color,
  }) {
    if (!from.skillReady) {
      return;
    }
    from.lookAt(target);
    from.resetSkillTimer();
    _spawnProjectile(
      from: from,
      target: target,
      speed: from.stats.skillSpeed,
      damage: from.stats.skillDamage,
      radius: from.stats.skillRadius,
      color: color,
    );
  }

  void _spawnProjectile({
    required FighterComponent from,
    required Vector2 target,
    required double speed,
    required double damage,
    required double radius,
    required Color color,
  }) {
    final Vector2 raw = target - from.position;
    final Vector2 direction = raw.length2 > 0.01 ? raw.normalized() : Vector2(0, -1);
    final ProjectileComponent projectile = ProjectileComponent(
      damage: damage,
      velocity: direction * speed,
      position: from.position + direction * (from.collisionRadius + 10),
      radius: radius,
      color: color,
      ownerTeam: from.team,
    );
    add(projectile);
  }

  void _checkProjectileHits() {
    final List<ProjectileComponent> projectiles =
        children.whereType<ProjectileComponent>().toList();
    for (final ProjectileComponent projectile in projectiles) {
      final FighterComponent target =
          projectile.ownerTeam == FighterTeam.player ? enemy : player;
      if (!target.isAlive) {
        continue;
      }
      if (projectile.position.distanceTo(target.position) <=
          target.collisionRadius + projectile.radius) {
        target.receiveDamage(projectile.damage);
        projectile.removeFromParent();
      }
    }
  }

  void _cleanupProjectiles() {
    final Rect bounds = _arena.bounds.inflate(30);
    final List<ProjectileComponent> projectiles =
        children.whereType<ProjectileComponent>().toList();
    for (final ProjectileComponent projectile in projectiles) {
      if (!bounds.contains(Offset(projectile.position.x, projectile.position.y))) {
        projectile.removeFromParent();
      }
    }
  }

  void _publishHud() {
    hud.value = BattleHudData(
      round: config.round,
      playerName: config.playerName,
      enemyName: config.enemyName,
      playerHp: player.hp,
      playerMaxHp: player.stats.maxHp,
      enemyHp: enemy.hp,
      enemyMaxHp: enemy.stats.maxHp,
      playerSkillReady: player.skillReady,
      enemySkillReady: enemy.skillReady,
      playerWeapon: config.playerDefinition.weaponLabel,
      enemyWeapon: config.enemyDefinition.weaponLabel,
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

import 'dart:math';

import 'package:flame/components.dart';

import '../models/game_state.dart';
import 'fighter_component.dart';
import 'projectile_component.dart';

class BrainDecision {
  const BrainDecision({
    required this.movement,
    required this.castSkill,
  });

  final Vector2 movement;
  final bool castSkill;
}

class DuelBrain {
  DuelBrain(this._random);

  final Random _random;
  double _strafeDirection = 1;
  double _strafeTimer = 0;

  BrainDecision decide({
    required FighterComponent self,
    required FighterComponent target,
    required ArchetypeDefinition definition,
    required Iterable<ProjectileComponent> projectiles,
    required double confidence,
    required double dt,
  }) {
    _strafeTimer -= dt;
    if (_strafeTimer <= 0) {
      _strafeTimer = 0.45 + _random.nextDouble() * 0.65;
      _strafeDirection = _random.nextBool() ? 1 : -1;
    }

    final Vector2 toTarget = target.position - self.position;
    final double distance = toTarget.length;
    final Vector2 forward = distance > 0.001 ? toTarget / distance : Vector2.zero();
    final Vector2 side = Vector2(-forward.y, forward.x);
    final Vector2 dodge = _computeDodge(self, projectiles);

    Vector2 move = dodge * 1.3;
    if (move.length2 < 0.01) {
      final double desiredRange = definition.preferredRange;
      if (distance > desiredRange + 18) {
        move += forward * definition.approachBias;
        move += side * _strafeDirection * definition.strafeBias * 0.45;
      } else if (distance < desiredRange - 14) {
        move -= forward * max(0.35, definition.retreatBias);
        move += side * _strafeDirection * definition.strafeBias * 0.3;
      } else {
        move += side * _strafeDirection * definition.strafeBias;
      }

      final bool lowHp = self.hp / self.stats.maxHp < 0.33;
      final bool targetThreat =
          target.skillReady && distance < target.stats.skillSpeed * 0.72;
      if (lowHp) {
        move -= forward * (0.35 + definition.retreatBias * 0.75);
      }
      if (targetThreat) {
        move -= forward * (0.18 + definition.retreatBias * 0.65);
      }
    }

    final bool inSkillBand = distance > self.stats.attackRange * 0.9 &&
        distance < min(290, self.stats.skillSpeed * 0.92);
    final double castChance = (0.02 + confidence * 0.03) * definition.skillUsageBias;
    final bool castSkill = self.skillReady &&
        inSkillBand &&
        dodge.length2 < 0.01 &&
        !_isProjectileLineBlocked(self, target, projectiles) &&
        _random.nextDouble() < castChance;

    return BrainDecision(
      movement: move.length2 > 0.01 ? move.normalized() : Vector2.zero(),
      castSkill: castSkill,
    );
  }

  Vector2 _computeDodge(
    FighterComponent self,
    Iterable<ProjectileComponent> projectiles,
  ) {
    for (final ProjectileComponent projectile in projectiles) {
      if (projectile.ownerTeam == self.team) {
        continue;
      }
      final Vector2 offset = self.position - projectile.position;
      final double distance = offset.length;
      if (distance > 95) {
        continue;
      }
      final Vector2 velocityDir = projectile.velocity.normalized();
      final double heading = velocityDir.dot(offset.normalized());
      if (heading > 0.7) {
        return Vector2(-velocityDir.y, velocityDir.x) *
            (_random.nextBool() ? 1 : -1);
      }
    }
    return Vector2.zero();
  }

  bool _isProjectileLineBlocked(
    FighterComponent self,
    FighterComponent target,
    Iterable<ProjectileComponent> projectiles,
  ) {
    final Vector2 line = target.position - self.position;
    if (line.length2 < 0.01) {
      return false;
    }
    final Vector2 normalizedLine = line.normalized();
    for (final ProjectileComponent projectile in projectiles) {
      if (projectile.ownerTeam == self.team) {
        continue;
      }
      final Vector2 offset = projectile.position - self.position;
      if (offset.length > line.length) {
        continue;
      }
      if (offset.dot(normalizedLine) > 0 && offset.cross(line).abs() < 14) {
        return true;
      }
    }
    return false;
  }
}

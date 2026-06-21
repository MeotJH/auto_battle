import 'dart:ui';
import 'package:flame/components.dart';

import 'fighter_component.dart';

class TowerComponent extends PositionComponent {
  TowerComponent({
    required this.team,
    required Vector2 position,
    this.maxHp = 260,
    this.attackRange = 172,
    this.attackDamage = 22,
    this.attackCooldown = 1.5,
  })  : hp = maxHp,
        super(
          position: position,
          size: Vector2(48, 48),
          anchor: Anchor.center,
        );

  final FighterTeam team;
  final double maxHp;
  final double attackRange;
  final double attackDamage;
  final double attackCooldown;

  final Paint _hpBackPaint = Paint()..color = const Color(0xFF1B1F2A);
  final Paint _hpPaint = Paint()..color = const Color(0xFF7AE582);

  double hp;
  double attackTimer = 0;

  bool get isAlive => hp > 0;
  double get collisionRadius => size.x * 0.5;
  bool get attackReady => attackTimer <= 0;

  void tickCooldowns(double dt) {
    attackTimer -= dt;
  }

  void receiveDamage(double damage) {
    hp = (hp - damage).clamp(0, maxHp);
  }

  void resetAttackTimer() {
    attackTimer = attackCooldown;
  }

  @override
  void render(Canvas canvas) {
    final double hpRatio = hp / maxHp;
    canvas.drawRect(Rect.fromLTWH(-22, -38, 44, 5), _hpBackPaint);
    canvas.drawRect(Rect.fromLTWH(-22, -38, 44 * hpRatio, 5), _hpPaint);
  }
}

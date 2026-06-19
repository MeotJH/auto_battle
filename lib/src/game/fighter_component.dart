import 'dart:ui';

import 'package:flame/components.dart';

import '../models/game_state.dart';

enum FighterTeam { player, enemy }

class FighterComponent extends PositionComponent {
  FighterComponent({
    required this.label,
    required this.stats,
    required this.bodyColor,
    required this.team,
    required Vector2 position,
  })  : hp = stats.maxHp,
        super(
          position: position,
          size: Vector2.all(34),
          anchor: Anchor.center,
        );

  final String label;
  final CombatStats stats;
  final Color bodyColor;
  final FighterTeam team;

  final Paint _bodyPaint = Paint();
  final Paint _hpBackPaint = Paint()..color = const Color(0xFF1B1F2A);
  final Paint _hpPaint = Paint()..color = const Color(0xFF7AE582);
  final Paint _ringPaint = Paint()
    ..color = const Color(0x66000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  double hp;
  double attackTimer = 0;
  double skillTimer = 0;
  Vector2 facing = Vector2(0, -1);

  bool get isAlive => hp > 0;
  bool get skillReady => skillTimer <= 0;
  double get collisionRadius => size.x * 0.5;

  @override
  Future<void> onLoad() async {
    _bodyPaint.color = bodyColor;
    return super.onLoad();
  }

  void tickCooldowns(double dt) {
    attackTimer -= dt;
    skillTimer -= dt;
  }

  void moveBy(Vector2 delta, Rect bounds) {
    final Vector2 next = position + delta;
    position.x = next.x.clamp(bounds.left + collisionRadius, bounds.right - collisionRadius);
    position.y = next.y.clamp(bounds.top + collisionRadius, bounds.bottom - collisionRadius);
    if (delta.length2 > 0.001) {
      facing = delta.normalized();
    }
  }

  @override
  void lookAt(Vector2 target) {
    final Vector2 direction = target - position;
    if (direction.length2 > 0.001) {
      facing = direction.normalized();
    }
  }

  void receiveDamage(double damage) {
    hp = (hp - damage).clamp(0, stats.maxHp);
  }

  void resetAttackTimer() {
    attackTimer = stats.attackCooldown;
  }

  void resetSkillTimer() {
    skillTimer = stats.skillCooldown;
  }

  @override
  void render(Canvas canvas) {
    final double hpRatio = hp / stats.maxHp;
    final Rect hpBack = Rect.fromLTWH(-24, -32, 48, 6);
    final Rect hpFront = Rect.fromLTWH(-24, -32, 48 * hpRatio, 6);

    canvas.drawCircle(const Offset(2, 4), 17, _ringPaint);
    canvas.drawCircle(Offset.zero, 17, _bodyPaint);
    canvas.drawRect(hpBack, _hpBackPaint);
    canvas.drawRect(hpFront, _hpPaint);

    final Offset facingTip = Offset(facing.x * 12, facing.y * 12);
    canvas.drawLine(
      Offset.zero,
      facingTip,
      Paint()
        ..color = const Color(0xFFF2F7FF)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }
}

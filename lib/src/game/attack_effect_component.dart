import 'dart:ui';

import 'package:flame/components.dart';

class AttackEffectComponent extends PositionComponent {
  AttackEffectComponent({
    required Vector2 position,
    required this.direction,
    required this.color,
    required this.isPunch,
    this.lifetime = 0.12,
  }) : super(
          position: position,
          size: Vector2.all(40),
          anchor: Anchor.center,
        );

  final Vector2 direction;
  final Color color;
  final bool isPunch;
  final double lifetime;

  late final Paint _paint = Paint()
    ..color = color.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = isPunch ? 5 : 4;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final double progress = (_elapsed / lifetime).clamp(0, 1);
    final double scale = 1 - progress * 0.35;
    final Offset tip = Offset(direction.x * 16 * scale, direction.y * 16 * scale);
    if (isPunch) {
      canvas.drawLine(Offset.zero, tip, _paint);
      canvas.drawCircle(tip, 4 * scale, Paint()..color = color.withValues(alpha: 0.7));
      return;
    }

    final Offset side = Offset(-direction.y * 10 * scale, direction.x * 10 * scale);
    final Path path = Path()
      ..moveTo(-side.dx, -side.dy)
      ..quadraticBezierTo(tip.dx, tip.dy, side.dx, side.dy);
    canvas.drawPath(path, _paint);
  }
}

import 'dart:ui';

import 'package:flame/components.dart';

class SkillTelegraphComponent extends PositionComponent {
  SkillTelegraphComponent.line({
    required Vector2 start,
    required Vector2 end,
    required this.color,
    required this.duration,
  })  : _start = start.clone(),
        _end = end.clone(),
        _radius = 0,
        _isLine = true,
        super(position: Vector2.zero(), anchor: Anchor.topLeft);

  SkillTelegraphComponent.area({
    required Vector2 center,
    required double radius,
    required this.color,
    required this.duration,
  })  : _start = center.clone(),
        _end = center.clone(),
        _radius = radius,
        _isLine = false,
        super(position: Vector2.zero(), anchor: Anchor.topLeft);

  final Vector2 _start;
  final Vector2 _end;
  final double _radius;
  final bool _isLine;
  final Color color;
  final double duration;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final double progress = (_elapsed / duration).clamp(0, 1);
    final Paint warningPaint = Paint()
      ..color = color.withValues(alpha: 0.28 + progress * 0.42)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _isLine ? 5 : 3;
    final Paint fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08 + progress * 0.12)
      ..style = PaintingStyle.fill;

    if (_isLine) {
      final Offset start = Offset(_start.x, _start.y);
      final Offset end = Offset(_end.x, _end.y);
      canvas.drawLine(start, end, warningPaint);
      canvas.drawCircle(end, 8 + progress * 8, warningPaint);
      return;
    }

    final Offset center = Offset(_start.x, _start.y);
    canvas.drawCircle(center, _radius, fillPaint);
    canvas.drawCircle(center, _radius * (0.65 + progress * 0.35), warningPaint);
  }
}

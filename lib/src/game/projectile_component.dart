import 'dart:ui';
import 'dart:math' as math;

import 'package:flame/components.dart';

import 'fighter_component.dart';

enum ProjectileKind { arrow, skillShot, cannon, minionBolt }

class ProjectileComponent extends PositionComponent {
  ProjectileComponent({
    required this.damage,
    required this.velocity,
    required super.position,
    required this.radius,
    required Color color,
    required this.ownerTeam,
    required this.kind,
    this.maxTravelDistance = 420,
    this.hitsFighters = true,
    this.hitsMinions = false,
    this.hitsStructures = false,
  })  : _paint = Paint()..color = color,
        super(
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  final double damage;
  final Vector2 velocity;
  final double radius;
  final FighterTeam ownerTeam;
  final ProjectileKind kind;
  final double maxTravelDistance;
  final bool hitsFighters;
  final bool hitsMinions;
  final bool hitsStructures;
  final Paint _paint;
  double _travelDistance = 0;

  bool get exceededTravelDistance => _travelDistance >= maxTravelDistance;

  @override
  void update(double dt) {
    super.update(dt);
    final Vector2 delta = velocity * dt;
    position += delta;
    _travelDistance += delta.length;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.rotate(math.atan2(velocity.y, velocity.x));
    switch (kind) {
      case ProjectileKind.arrow:
        final Rect shaft = Rect.fromLTWH(-radius * 1.4, -1.5, radius * 2.8, 3);
        canvas.drawRect(shaft, _paint);
        canvas.drawPath(
          Path()
            ..moveTo(radius * 1.8, 0)
            ..lineTo(radius * 0.4, -radius * 0.9)
            ..lineTo(radius * 0.4, radius * 0.9)
            ..close(),
          _paint,
        );
        break;
      case ProjectileKind.skillShot:
      case ProjectileKind.cannon:
      case ProjectileKind.minionBolt:
        canvas.drawCircle(Offset.zero, radius, _paint);
        break;
    }
    canvas.restore();
  }
}

import 'dart:ui';

import 'package:flame/components.dart';

import 'fighter_component.dart';

class ProjectileComponent extends CircleComponent {
  ProjectileComponent({
    required this.damage,
    required this.velocity,
    required super.position,
    required double radius,
    required Color color,
    required this.ownerTeam,
  }) : super(
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

  final double damage;
  final Vector2 velocity;
  final FighterTeam ownerTeam;

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
  }
}

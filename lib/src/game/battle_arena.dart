import 'dart:ui';

import 'package:flame/components.dart';

class BattleArena {
  BattleArena(this.size);

  final Vector2 size;

  Rect get bounds => Rect.fromLTWH(24, 24, size.x - 48, size.y - 48);

  Vector2 playerSpawn() => Vector2(bounds.center.dx, bounds.bottom - 68);

  Vector2 enemySpawn() => Vector2(bounds.center.dx, bounds.top + 68);

  bool contains(Vector2 point) {
    return bounds.contains(Offset(point.x, point.y));
  }
}

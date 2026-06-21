import 'dart:ui';

import 'package:flame/components.dart';

/// A single floating platform.
class ArenaPlatform {
  const ArenaPlatform({
    required this.left,
    required this.right,
    required this.top,  // Y coordinate of surface (smaller = higher on screen)
  });

  final double left;
  final double right;
  final double top;

  double get width => right - left;
  double get centerX => (left + right) / 2;

  bool containsX(double x) => x >= left && x <= right;
}

class BattleArena {
  BattleArena(this.size);

  final Vector2 size;

  Rect get bounds => Rect.fromLTWH(0, 0, size.x, size.y);
  double get groundY => bounds.top + bounds.height * 0.78;

  Rect get fighterBounds => Rect.fromLTWH(
        bounds.left + bounds.width * 0.06,
        bounds.top,
        bounds.width * 0.88,
        bounds.height,
      );

  /// Two floating platforms at different heights and X positions.
  List<ArenaPlatform> get platforms => <ArenaPlatform>[
        // Left-centre platform — lower height, good for melee approach
        ArenaPlatform(
          left:  size.x * 0.22,
          right: size.x * 0.42,
          top:   groundY - size.y * 0.18,
        ),
        // Right-centre platform — higher, good for mage escape
        ArenaPlatform(
          left:  size.x * 0.58,
          right: size.x * 0.78,
          top:   groundY - size.y * 0.22,
        ),
      ];

  Vector2 playerSpawn() => Vector2(bounds.left + bounds.width * 0.15, groundY);
  Vector2 enemySpawn()  => Vector2(bounds.right - bounds.width * 0.15, groundY);

  Vector2 playerTowerSpawn() => Vector2(bounds.left  + bounds.width * 0.065, groundY - 28);
  Vector2 enemyTowerSpawn()  => Vector2(bounds.right - bounds.width * 0.065, groundY - 28);

  static const double _minionXStep = 28.0;

  List<Vector2> playerMeleeMinionSpawns() => _minionLineSpawns(
        frontX: bounds.left + bounds.width * 0.22,
        count: 3,
        stepX: _minionXStep,
      );

  List<Vector2> playerRangedMinionSpawns() => _minionLineSpawns(
        frontX: bounds.left + bounds.width * 0.22 + _minionXStep * 3,
        count: 3,
        stepX: _minionXStep,
      );

  List<Vector2> enemyMeleeMinionSpawns() => _minionLineSpawns(
        frontX: bounds.right - bounds.width * 0.22,
        count: 3,
        stepX: -_minionXStep,
      );

  List<Vector2> enemyRangedMinionSpawns() => _minionLineSpawns(
        frontX: bounds.right - bounds.width * 0.22 - _minionXStep * 3,
        count: 3,
        stepX: -_minionXStep,
      );

  List<Vector2> _minionLineSpawns({
    required double frontX,
    required int count,
    required double stepX,
  }) {
    return List<Vector2>.generate(
      count,
      (int i) => Vector2(frontX + stepX * i, groundY),
    );
  }

  /// Returns the Y surface the character should land on given its current
  /// position and previous Y (to detect downward passage through a platform).
  double supportYFor({
    required double previousY,
    required Vector2 position,
    required double radius,
  }) {
    // Check platforms first — only land on top (falling through from above).
    for (final ArenaPlatform p in platforms) {
      if (position.x >= p.left - radius && position.x <= p.right + radius) {
        // Character was above the platform surface last frame and is now at/below it.
        if (previousY <= p.top && position.y >= p.top) {
          return p.top;
        }
      }
    }
    return groundY;
  }

  bool contains(Vector2 point) {
    return bounds.contains(Offset(point.x, point.y));
  }
}

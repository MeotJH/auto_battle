import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../models/game_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SpriteRig — Dead-Cells-style skeletal rig.
//
// Attack flow (3-phase):
//   0 % – 22 %  WIND-UP   slow anticipation, moves OPPOSITE to strike
//   22% – 45 %  STRIKE    extremely fast, overshoots into peak pose
//   45% – 100%  RECOVERY  ease back with a small bounce overshoot
//
// Extras:
//   • Hit flash    – white colour-filter for ~120 ms after receiveDamage
//   • Afterimage   – 2 faded ghost copies drawn behind during the strike phase
//   • Squash/Stretch – canvas scale changes on wind-up and peak
// ─────────────────────────────────────────────────────────────────────────────

class SpriteRig extends PositionComponent {
  SpriteRig({
    required this.upper,
    required this.lower,
    required this.upperSize,
    required this.lowerSize,
    required this.archetype,
    super.position,
    super.anchor,
  }) : super(
          size: Vector2(
            max(upperSize.x, lowerSize.x),
            upperSize.y + lowerSize.y,
          ),
        );

  final Sprite upper;
  final Sprite lower;
  final Vector2 upperSize;
  final Vector2 lowerSize;
  final FighterArchetype archetype;

  // ── state ─────────────────────────────────────────────────────────────────
  bool   _walking = false;
  double _time     = 0;

  // Attack: progress 0 → 1 over _atkDuration seconds.
  double _atkProgress = 0;
  bool   _atkActive   = false;
  static const double _atkDuration = 0.28; // shorter = snappier (Dead Cells ≈ 0.25-0.30 s)

  static const double _pWindEnd   = 0.22; // 0 → 22%  wind-up
  static const double _pStrikeEnd = 0.45; // 22% → 45% strike (FAST)
  //                                        45% → 100% recovery

  // Hit flash: _flashT counts down from 1 → 0 over _flashDuration.
  double _flashT = 0;
  static const double _flashDuration = 0.13;

  // ── public API ────────────────────────────────────────────────────────────

  void setWalking(bool v) => _walking = v;

  void triggerAttack() {
    _atkProgress = 0;
    _atkActive   = true;
  }

  /// Call when this fighter receives damage (shows white flash).
  void triggerHitFlash() => _flashT = 1.0;

  // ── update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (_atkActive) {
      _atkProgress += dt / _atkDuration;
      if (_atkProgress >= 1.0) {
        _atkProgress = 0;
        _atkActive   = false;
      }
    }

    if (_flashT > 0) {
      _flashT = (_flashT - dt / _flashDuration).clamp(0, 1);
    }
  }

  // ── render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final double rW = size.x;
    final double uH = upperSize.y;
    final double lH = lowerSize.y;

    // Walk / breathe base values.
    final double wPhase = _time * 8.0;
    final double bPhase = _time * 1.4;

    double baseDY    = _walking ? -sin(wPhase).abs() * 2.5 : sin(bPhase) * 1.4;
    double baseAngle = _walking ? sin(wPhase) * 0.04        : sin(bPhase * 0.7) * 0.015;

    // Compute attack pose.
    _AtkPose pose = const _AtkPose.zero();
    if (_atkActive) {
      pose = _poseFor(_atkProgress);
    }

    final double finalDY    = baseDY    + pose.dy;
    final double finalAngle = baseAngle + pose.angle;

    // ── afterimage (drawn BEHIND main sprite, only during strike phase) ─────
    if (_atkActive &&
        _atkProgress > _pWindEnd &&
        _atkProgress < _pStrikeEnd + 0.08) {
      _renderAfterimage(canvas, rW, uH, 0.06, 0.28);
      _renderAfterimage(canvas, rW, uH, 0.13, 0.14);
    }

    // ── wrap everything in hit-flash layer if needed ──────────────────────
    final bool flashing = _flashT > 0;
    if (flashing) {
      final int a = (_flashT * 210).round();
      canvas.saveLayer(
        null,
        Paint()
          ..colorFilter =
              ColorFilter.mode(Color.fromARGB(a, 255, 255, 255), BlendMode.srcATop),
      );
    }

    // ── upper body ──────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(rW / 2, uH + finalDY);
    canvas.rotate(finalAngle);
    canvas.scale(pose.sx, pose.sy);
    upper.render(canvas,
        position: Vector2(-upperSize.x / 2, -uH), size: upperSize);
    canvas.restore();

    // ── legs ────────────────────────────────────────────────────────────────
    final double legShear =
        (_walking ? sin(wPhase) * 16.0 : 0.0) + pose.legShift;

    canvas.save();
    canvas.translate(rW / 2, uH + (_walking ? baseDY * 0.5 : 0));
    _renderLegs(canvas, lH, legShear);
    canvas.restore();

    if (flashing) canvas.restore(); // close hit-flash layer
  }

  // ── afterimage helper ─────────────────────────────────────────────────────

  void _renderAfterimage(
    Canvas canvas,
    double rW,
    double uH,
    double progOffset,
    double alpha,
  ) {
    final double pastP = (_atkProgress - progOffset).clamp(0.0, 1.0);
    final _AtkPose past = _poseFor(pastP);

    final int a = (alpha * 255).round();
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromARGB(a, 180, 200, 255),
    );
    canvas.save();
    canvas.translate(rW / 2, uH + past.dy);
    canvas.rotate(past.angle);
    canvas.scale(past.sx, past.sy);
    upper.render(canvas,
        position: Vector2(-upperSize.x / 2, -uH), size: upperSize);
    canvas.restore();
    canvas.restore();
  }

  // ── leg split-shear ───────────────────────────────────────────────────────

  void _renderLegs(Canvas canvas, double lH, double shear) {
    final double sx  = shear / lH;
    final Vector2 pos = Vector2(-lowerSize.x / 2, 0);

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, lowerSize.x, lH + 4));
    canvas.transform(_shearMat(sx));
    lower.render(canvas, position: pos, size: lowerSize);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-lowerSize.x, 0, 0, lH + 4));
    canvas.transform(_shearMat(-sx));
    lower.render(canvas, position: pos, size: lowerSize);
    canvas.restore();
  }

  // ── per-archetype attack pose ─────────────────────────────────────────────

  _AtkPose _poseFor(double p) => switch (archetype) {
        FighterArchetype.kiting  => _bowPose(p),
        FighterArchetype.melee   => _swordPose(p),
        FighterArchetype.bruiser => _fistPose(p),
      };

  // BOW: pull string (lean back + rise) → snap-release (burst forward).
  _AtkPose _bowPose(double p) {
    if (p < _pWindEnd) {
      final double t = _s(p / _pWindEnd);
      return _AtkPose(angle: -0.28 * t, dy: -5.0 * t,
          sx: 1.0, sy: 1.0 - 0.06 * t, legShift: 0);
    }
    if (p < _pStrikeEnd) {
      final double t = (p - _pWindEnd) / (_pStrikeEnd - _pWindEnd);
      final double e = _eOut(t);
      return _AtkPose(
        angle: -0.28 + 0.38 * e,
        dy:    -5.0  + 8.0  * e,
        sx:    1.0   + 0.10 * _peak(t),
        sy:    1.0   - 0.06 + 0.10 * _peak(t),
        legShift: 10.0 * _peak(t),
      );
    }
    final double t = _s((p - _pStrikeEnd) / (1.0 - _pStrikeEnd));
    return _AtkPose(angle: 0.10 * (1-t), dy: 3.0 * (1-t),
        sx: 1.0, sy: 1.0, legShift: 0);
  }

  // SWORD: raise + rotate back → explosive slash → overshoot bounce recovery.
  _AtkPose _swordPose(double p) {
    if (p < _pWindEnd) {
      final double t = _s(p / _pWindEnd);
      return _AtkPose(
        angle: -0.40 * t, dy: -6.0 * t,
        sx: 1.0, sy: 1.0 - 0.06 * t, legShift: -5.0 * t,
      );
    }
    if (p < _pStrikeEnd) {
      final double t = (p - _pWindEnd) / (_pStrikeEnd - _pWindEnd);
      final double e = _eOut(t);
      return _AtkPose(
        angle:    -0.40 + 0.95 * e,
        dy:       -6.0  + 11.0 * e,
        sx:        1.0  + 0.12 * _peak(t),
        sy:        1.0  - 0.06 + 0.06 * e,
        legShift: -5.0  + 18.0 * e,
      );
    }
    final double t = (p - _pStrikeEnd) / (1.0 - _pStrikeEnd);
    // Bounce: overshoot slightly then settle.
    final double bounce = sin(t * pi * 1.6) * 0.10 * (1.0 - t);
    return _AtkPose(
      angle:    (0.55 + bounce) * (1 - _s(t)),
      dy:        5.0 * (1 - _s(t)),
      sx:        1.0, sy: 1.0,
      legShift: 13.0 * (1 - _s(t)),
    );
  }

  // FIST: crouch + coil → explosive spring punch → guard bounce.
  _AtkPose _fistPose(double p) {
    if (p < _pWindEnd) {
      final double t = _s(p / _pWindEnd);
      return _AtkPose(
        angle: -0.22 * t, dy: 7.0 * t,
        sx: 1.0 + 0.06 * t, sy: 1.0 - 0.10 * t,
        legShift: -6.0 * t,
      );
    }
    if (p < _pStrikeEnd) {
      final double t = (p - _pWindEnd) / (_pStrikeEnd - _pWindEnd);
      final double e = _eOut(t);
      return _AtkPose(
        angle:    -0.22 + 0.52 * e,
        dy:        7.0  - 13.0 * e,
        sx:        1.0  + 0.06 + 0.10 * _peak(t),
        sy:        1.0  - 0.10 + 0.16 * e,
        legShift: -6.0  + 22.0 * e,
      );
    }
    final double t = _s((p - _pStrikeEnd) / (1.0 - _pStrikeEnd));
    final double bounce = sin(t * pi) * 0.08;
    return _AtkPose(
      angle:    (0.30 + bounce) * (1 - t),
      dy:       -6.0 * (1 - t),
      sx:        1.0 + 0.16 * (1 - t),
      sy:        1.0 + 0.06 * (1 - t),
      legShift: 16.0 * (1 - t),
    );
  }

  // ── math helpers ──────────────────────────────────────────────────────────

  static Float64List _shearMat(double sx) => Float64List.fromList(<double>[
        1, 0, 0, 0,
        sx, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]);

  static double _s(double t)    { final c = t.clamp(0.0, 1.0); return c*c*(3-2*c); }
  static double _eOut(double t) { final c = t.clamp(0.0, 1.0); return 1-(1-c)*(1-c); }
  static double _peak(double t) => sin(t.clamp(0.0, 1.0) * pi);
}

// ── pose value object ─────────────────────────────────────────────────────────

class _AtkPose {
  const _AtkPose({
    required this.angle,
    required this.dy,
    required this.sx,
    required this.sy,
    required this.legShift,
  });

  const _AtkPose.zero()
      : angle = 0, dy = 0, sx = 1, sy = 1, legShift = 0;

  final double angle;
  final double dy;
  final double sx;
  final double sy;
  final double legShift;
}

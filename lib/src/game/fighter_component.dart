import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';

import '../models/game_state.dart';
import 'sprite_catalog.dart';

enum FighterTeam { player, enemy }

class FighterComponent extends PositionComponent {
  FighterComponent({
    required this.label,
    required this.archetype,
    required this.stats,
    required this.team,
    required Vector2 position,
  })  : hp = stats.maxHp,
        super(
          position: position,
          size: Vector2.all(64),
          anchor: Anchor.center,
        );

  final String label;
  final FighterArchetype archetype;
  final CombatStats stats;
  final FighterTeam team;

  final Paint _hpBackPaint = Paint()..color = const Color(0xFF1B1F2A);
  final Paint _hpPaint     = Paint()..color = const Color(0xFF7AE582);
  final Paint _ringPaint   = Paint()
    ..color = const Color(0x44000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  double hp;
  double attackTimer = 0;
  double skillTimer  = 0;
  Vector2 facing     = Vector2(1, 0);
  Vector2 velocity   = Vector2.zero();
  bool onGround = false;
  double _lastY = 0;
  bool _moving  = false;
  bool _dead    = false;

  SpriteAnimationGroupComponent<UnitAnimState>? _sprite;

  bool get isAlive => hp > 0;
  bool get skillReady => skillTimer <= 0;
  double get collisionRadius => size.x * 0.5;
  double get previousY => _lastY;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final FlameGame game = findGame()!;
    final catalog = SpriteCatalog(game);
    final anims = await catalog.loadHeroAnimations(
      archetype,
      facingLeft: team == FighterTeam.enemy,
    );

    // Hero = minion-melee(50×44) × 1.3 × 1.5 ≈ 98×86
    final Vector2 spriteSize = Vector2(98, 86);
    _sprite = SpriteAnimationGroupComponent<UnitAnimState>(
      animations: anims,
      current: UnitAnimState.idle,
      size: spriteSize,
      anchor: Anchor.bottomCenter,
      position: Vector2(0, size.y * 0.5 + 4),
    );
    add(_sprite!);

    // Non-looping animations return to idle when done
    _sprite!.animationTicker?.onComplete = _onAnimComplete;
  }

  void _onAnimComplete() {
    if (_dead) return;
    if (_sprite?.current == UnitAnimState.attack ||
        _sprite?.current == UnitAnimState.skill ||
        _sprite?.current == UnitAnimState.hurt) {
      _setAnim(_moving ? UnitAnimState.run : UnitAnimState.idle);
    }
  }

  void _setAnim(UnitAnimState state) {
    if (_sprite == null) return;
    if (_sprite!.current == state) return;
    _sprite!.current = state;
    _sprite!.animationTicker?.reset();
    _sprite!.animationTicker?.onComplete = _onAnimComplete;
  }

  // ── cooldowns ─────────────────────────────────────────────────────────────

  void tickCooldowns(double dt) {
    attackTimer -= dt;
    skillTimer  -= dt;
  }

  // ── movement ──────────────────────────────────────────────────────────────

  void moveHorizontally(double deltaX, Rect bounds) {
    position.x = (position.x + deltaX)
        .clamp(bounds.left + collisionRadius, bounds.right - collisionRadius);
    _moving = deltaX.abs() > 0.001;
    if (_moving) {
      facing = Vector2(deltaX.isNegative ? -1 : 1, 0);
    }
    if (!_dead &&
        _sprite?.current != UnitAnimState.attack &&
        _sprite?.current != UnitAnimState.skill &&
        _sprite?.current != UnitAnimState.hurt) {
      _setAnim(_moving ? UnitAnimState.run : UnitAnimState.idle);
    }
  }

  void stopMoving() {
    _moving = false;
    if (!_dead &&
        _sprite?.current != UnitAnimState.attack &&
        _sprite?.current != UnitAnimState.skill &&
        _sprite?.current != UnitAnimState.hurt) {
      _setAnim(UnitAnimState.idle);
    }
  }

  // ── physics ───────────────────────────────────────────────────────────────

  void applyGravity(double dt, double gravity, double terminalVelocity) {
    _lastY = position.y;
    velocity.y =
        (velocity.y + gravity * dt).clamp(-terminalVelocity, terminalVelocity);
    position.y += velocity.y * dt;
    onGround = false;
  }

  void landOn(double supportY) {
    position.y = supportY;
    velocity.y = 0;
    onGround = true;
  }

  void jump(double force) {
    if (!onGround) return;
    velocity.y = -force;
    onGround = false;
  }

  // ── combat ────────────────────────────────────────────────────────────────

  @override
  void lookAt(Vector2 target) {
    final Vector2 dir = target - position;
    if (dir.length2 > 0.001) {
      facing = Vector2(dir.x.isNegative ? -1 : 1, 0);
    }
  }

  void receiveDamage(double damage) {
    if (_dead) return;
    hp = (hp - damage).clamp(0, stats.maxHp);
    _sprite?.add(
      ColorEffect(
        const Color(0xFFFFFFFF),
        EffectController(duration: 0.08),
        opacityFrom: 1.0,
        opacityTo: 0.0,
      ),
    );
    if (hp <= 0) {
      _dead = true;
      _setAnim(UnitAnimState.death);
    } else {
      _setAnim(UnitAnimState.hurt);
    }
  }

  void resetAttackTimer() {
    attackTimer = stats.attackCooldown;
    _setAnim(UnitAnimState.attack);
  }

  void resetSkillTimer() {
    skillTimer = stats.skillCooldown;
    _setAnim(UnitAnimState.skill);
  }

  // ── render / update ───────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Ground shadow
    canvas.drawOval(const Rect.fromLTWH(-14, 10, 28, 7), _ringPaint);

    // HP bar
    final double hpRatio = hp / stats.maxHp;
    canvas.drawRect(const Rect.fromLTWH(-22, -38, 44, 5), _hpBackPaint);
    canvas.drawRect(Rect.fromLTWH(-22, -38, 44 * hpRatio, 5), _hpPaint);
  }

}


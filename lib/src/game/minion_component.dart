import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'fighter_component.dart';
import 'sprite_catalog.dart';

enum MinionType { melee, ranged }

// Attack animation: 3 frames × 0.09 s = 0.27 s.
const double _kAttackAnimDuration = 0.29;

class MinionComponent extends PositionComponent {
  MinionComponent({
    required this.team,
    required this.type,
    required Vector2 position,
    required this.maxHp,
    required this.attackDamage,
    required this.attackRange,
    required this.attackCooldown,
    required this.moveSpeed,
  })  : hp = maxHp,
        super(
          position: position,
          size: Vector2.all(22),
          anchor: Anchor.center,
        ) {
    // Enemy minions start on the right and move left → face left
    facing = team == FighterTeam.enemy ? Vector2(-1, 0) : Vector2(1, 0);
  }

  final FighterTeam team;
  final MinionType type;
  final double maxHp;
  final double attackDamage;
  final double attackRange;
  final double attackCooldown;
  final double moveSpeed;

  final Paint _hpBackPaint = Paint()..color = const Color(0xFF1B1F2A);
  final Paint _hpPaint = Paint()..color = const Color(0xFF9BE57A);

  double hp;
  double attackTimer = 0;
  late Vector2 facing;
  double _attackAnimTimer = 0;
  bool _moving = false;
  SpriteAnimationGroupComponent<UnitAnimState>? _sprite;

  bool get isAlive => hp > 0;
  bool get attackReady => attackTimer <= 0;
  double get collisionRadius => size.x * 0.5;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final FlameGame game = findGame()!;
    final Map<UnitAnimState, SpriteAnimation> anims =
        await SpriteCatalog(game).loadMinionAnimations(team: team, type: type);

    // Minion frames are slightly wider than tall — use separate w/h.
    final Vector2 spriteSize =
        type == MinionType.melee ? Vector2(50, 44) : Vector2(54, 48);

    _sprite = SpriteAnimationGroupComponent<UnitAnimState>(
      animations: anims,
      current: UnitAnimState.idle,
      size: spriteSize,
      anchor: Anchor.bottomCenter,
      position: Vector2(0, size.y * 0.5 + 2),
    );
    add(_sprite!);
  }

  void tickCooldowns(double dt) {
    attackTimer -= dt;
    if (_attackAnimTimer > 0) {
      _attackAnimTimer -= dt;
      if (_attackAnimTimer <= 0) {
        _syncAnimation();
      }
    }
  }

  void receiveDamage(double damage) {
    hp = (hp - damage).clamp(0, maxHp);
  }

  void resetAttackTimer() {
    attackTimer = attackCooldown;
    _attackAnimTimer = _kAttackAnimDuration;
    _sprite?.current = UnitAnimState.attack;
    _sprite?.animationTicker?.reset();
  }

  void moveHorizontally(double deltaX, Rect bounds) {
    position.x = (position.x + deltaX)
        .clamp(bounds.left + collisionRadius, bounds.right - collisionRadius);
    _moving = deltaX.abs() > 0.001;
    if (deltaX.abs() > 0.001) {
      facing = Vector2(deltaX.isNegative ? -1 : 1, 0);
    }
    _syncAnimation();
  }

  void moveVerticallyTowards(double targetY, double dt) {
    final double delta = targetY - position.y;
    position.y += delta.clamp(-moveSpeed * dt * 0.35, moveSpeed * dt * 0.35);
  }

  @override
  void lookAt(Vector2 target) {
    final Vector2 dir = target - position;
    if (dir.length2 > 0.001) {
      facing = Vector2(dir.x.isNegative ? -1 : 1, 0);
    }
  }

  void stopMoving() {
    _moving = false;
    _syncAnimation();
  }

  void _syncAnimation() {
    final SpriteAnimationGroupComponent<UnitAnimState>? sprite = _sprite;
    if (sprite == null || _attackAnimTimer > 0) return;
    sprite.current = _moving ? UnitAnimState.run : UnitAnimState.idle;
  }

  @override
  void render(Canvas canvas) {
    final double hpRatio = hp / maxHp;
    canvas.drawRect(const Rect.fromLTWH(-13, -16, 26, 4), _hpBackPaint);
    canvas.drawRect(Rect.fromLTWH(-13, -16, 26 * hpRatio, 4), _hpPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_sprite != null) {
      _sprite!.scale.x = facing.x.isNegative ? -1 : 1;
    }
  }
}

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../models/game_state.dart';
import 'fighter_component.dart';
import 'minion_component.dart';

enum UnitAnimState { idle, run, attack, skill, hurt, death }

class SpriteCatalog {
  SpriteCatalog(this.game);

  final FlameGame game;

  static const String _heroBase = 'raw/split/heroes';
  static const String _minionBase = 'raw/split/minions';

  // frame counts per character (from assets/raw/split/heroes/{prefix}/)
  static const Map<String, Map<String, int>> _heroFrames = <String, Map<String, int>>{
    'fist':  <String, int>{'idle': 5, 'run': 8, 'attack': 6, 'hurt': 4, 'death': 4},
    'mage':  <String, int>{'idle': 7, 'run': 7, 'attack': 6, 'hurt': 3, 'death': 5},
    'sword': <String, int>{'idle': 8, 'run': 8, 'attack': 6, 'hurt': 3, 'death': 5},
  };

  Future<Map<UnitAnimState, SpriteAnimation>> loadHeroAnimations(
    FighterArchetype archetype, {
    bool facingLeft = false,
  }) async {
    final String base = switch (archetype) {
      FighterArchetype.kiting  => 'mage',
      FighterArchetype.melee   => 'sword',
      FighterArchetype.bruiser => 'fist',
    };
    // facingLeft → use pre-flipped assets (prefix_r_*)
    final String prefix = facingLeft ? '${base}_r' : base;
    final Map<String, int> counts = _heroFrames[base]!;

    Future<List<Sprite>> frames(String state, int count) async {
      final List<Sprite> sprites = <Sprite>[];
      for (int i = 1; i <= count; i++) {
        sprites.add(await game.loadSprite('$_heroBase/$base/${prefix}_$state$i.png'));
      }
      return sprites;
    }

    final List<Sprite> idleFrames   = await frames('idle',   counts['idle']!);
    final List<Sprite> runFrames    = await frames('run',    counts['run']!);
    final List<Sprite> attackFrames = await frames('attack', counts['attack']!);
    final List<Sprite> hurtFrames   = await frames('hurt',   counts['hurt']!);
    final List<Sprite> deathFrames  = await frames('death',  counts['death']!);

    return <UnitAnimState, SpriteAnimation>{
      UnitAnimState.idle:   SpriteAnimation.spriteList(idleFrames,   stepTime: 0.14, loop: true),
      UnitAnimState.run:    SpriteAnimation.spriteList(runFrames,    stepTime: 0.09, loop: true),
      UnitAnimState.attack: SpriteAnimation.spriteList(attackFrames, stepTime: 0.07, loop: false),
      UnitAnimState.skill:  SpriteAnimation.spriteList(attackFrames, stepTime: 0.07, loop: false),
      UnitAnimState.hurt:   SpriteAnimation.spriteList(hurtFrames,   stepTime: 0.07, loop: false),
      UnitAnimState.death:  SpriteAnimation.spriteList(deathFrames,  stepTime: 0.12, loop: false),
    };
  }

  Future<Map<UnitAnimState, SpriteAnimation>> loadMinionAnimations({
    required FighterTeam team,
    required MinionType type,
  }) async {
    final String prefix = switch ((team, type)) {
      (FighterTeam.player, MinionType.melee) => 'blue_melee',
      (FighterTeam.enemy, MinionType.melee) => 'red_melee',
      (FighterTeam.player, MinionType.ranged) => 'blue_ranged',
      (FighterTeam.enemy, MinionType.ranged) => 'red_ranged',
    };

    // Detect available frame counts from known split files.
    const int idleCount = 3;
    const int runCount = 4;
    const int attackCount = 3;

    return _loadAnimations(
      base: _minionBase,
      prefix: prefix,
      idleCount: idleCount,
      runCount: runCount,
      attackCount: attackCount,
      idleStepTime: 0.18,
      runStepTime: 0.12,
      attackStepTime: 0.09,
    );
  }

  Future<Map<UnitAnimState, SpriteAnimation>> _loadAnimations({
    required String base,
    required String prefix,
    required int idleCount,
    required int runCount,
    required int attackCount,
    double idleStepTime = 0.16,
    double runStepTime = 0.11,
    double attackStepTime = 0.08,
  }) async {
    Future<List<Sprite>> frames(String state, int count) async {
      final List<Sprite> sprites = <Sprite>[];
      for (int i = 1; i <= count; i++) {
        final String path = '$base/${prefix}_${state}_$i.png';
        final Sprite sprite = await game.loadSprite(path);
        sprites.add(sprite);
      }
      return sprites;
    }

    final List<Sprite> idleFrames = await frames('idle', idleCount);
    final List<Sprite> runFrames = await frames('run', runCount);
    final List<Sprite> attackFrames = await frames('attack', attackCount);

    return <UnitAnimState, SpriteAnimation>{
      UnitAnimState.idle: SpriteAnimation.spriteList(
        idleFrames,
        stepTime: idleStepTime,
        loop: true,
      ),
      UnitAnimState.run: SpriteAnimation.spriteList(
        runFrames,
        stepTime: runStepTime,
        loop: true,
      ),
      UnitAnimState.attack: SpriteAnimation.spriteList(
        attackFrames,
        stepTime: attackStepTime,
        loop: false,
      ),
    };
  }
}

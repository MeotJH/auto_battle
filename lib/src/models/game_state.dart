import 'dart:math';

import 'package:flutter/foundation.dart';

import 'reward.dart';

enum FlowPhase { menu, battle, reward, gameOver }

enum FighterArchetype { kiting, melee, bruiser }

enum AttackStyle { bowShot, swordSwing, fistSwing }

class CombatStats {
  const CombatStats({
    required this.maxHp,
    required this.attackDamage,
    required this.attackRange,
    required this.attackCooldown,
    required this.moveSpeed,
    required this.skillDamage,
    required this.skillSpeed,
    required this.skillCooldown,
    required this.skillRadius,
  });

  final double maxHp;
  final double attackDamage;
  final double attackRange;
  final double attackCooldown;
  final double moveSpeed;
  final double skillDamage;
  final double skillSpeed;
  final double skillCooldown;
  final double skillRadius;

  CombatStats scale(double factor) {
    return CombatStats(
      maxHp: maxHp * factor,
      attackDamage: attackDamage * factor,
      attackRange: attackRange,
      attackCooldown: attackCooldown,
      moveSpeed: moveSpeed,
      skillDamage: skillDamage * factor,
      skillSpeed: skillSpeed,
      skillCooldown: skillCooldown,
      skillRadius: skillRadius,
    );
  }

  CombatStats add({
    double maxHp = 0,
    double attackDamage = 0,
    double attackRange = 0,
    double attackCooldown = 0,
    double moveSpeed = 0,
    double skillDamage = 0,
    double skillSpeed = 0,
    double skillCooldown = 0,
    double skillRadius = 0,
  }) {
    return CombatStats(
      maxHp: this.maxHp + maxHp,
      attackDamage: this.attackDamage + attackDamage,
      attackRange: this.attackRange + attackRange,
      attackCooldown: this.attackCooldown + attackCooldown,
      moveSpeed: this.moveSpeed + moveSpeed,
      skillDamage: this.skillDamage + skillDamage,
      skillSpeed: this.skillSpeed + skillSpeed,
      skillCooldown: this.skillCooldown + skillCooldown,
      skillRadius: this.skillRadius + skillRadius,
    );
  }
}

class ArchetypeDefinition {
  const ArchetypeDefinition({
    required this.archetype,
    required this.attackStyle,
    required this.displayName,
    required this.summary,
    required this.weaponLabel,
    required this.colorValue,
    required this.baseStats,
    required this.preferredRange,
    required this.approachBias,
    required this.strafeBias,
    required this.retreatBias,
    required this.skillUsageBias,
  });

  final FighterArchetype archetype;
  final AttackStyle attackStyle;
  final String displayName;
  final String summary;
  final String weaponLabel;
  final int colorValue;
  final CombatStats baseStats;
  final double preferredRange;
  final double approachBias;
  final double strafeBias;
  final double retreatBias;
  final double skillUsageBias;
}

const Map<FighterArchetype, ArchetypeDefinition> archetypeCatalog =
    <FighterArchetype, ArchetypeDefinition>{
  FighterArchetype.kiting: ArchetypeDefinition(
    archetype: FighterArchetype.kiting,
    attackStyle: AttackStyle.bowShot,
    displayName: '마법사',
    summary: '원거리 마법 공격으로 거리를 유지하며 싸우는 마법사.',
    weaponLabel: '마법',
    colorValue: 0xFF64B5F6,
    baseStats: CombatStats(
      maxHp: 85,
      attackDamage: 10,   // 쿨다운 길어진 만큼 단발 데미지 소폭 상승
      attackRange: 125,
      attackCooldown: 1.15, // 느린 사격 — 근접이 점프로 피할 시간 확보
      moveSpeed: 108,
      skillDamage: 22,
      skillSpeed: 310,
      skillCooldown: 4.0,
      skillRadius: 10,
    ),
    preferredRange: 150,
    approachBias: 0.38,
    strafeBias: 1.0,
    retreatBias: 1.0,
    skillUsageBias: 1.1,
  ),
  FighterArchetype.melee: ArchetypeDefinition(
    archetype: FighterArchetype.melee,
    attackStyle: AttackStyle.swordSwing,
    displayName: '검사',
    summary: '빠른 검격으로 적에게 밀착해 싸우는 전사.',
    weaponLabel: '검',
    colorValue: 0xFFE57373,
    baseStats: CombatStats(
      maxHp: 100,
      attackDamage: 17,   // 붙으면 강하게
      attackRange: 50,
      attackCooldown: 0.68,
      moveSpeed: 122,     // 마법사보다 빠르게 — 점프+추격 가능
      skillDamage: 28,
      skillSpeed: 260,
      skillCooldown: 4.5,
      skillRadius: 9,
    ),
    preferredRange: 52,
    approachBias: 1.0,
    strafeBias: 0.15,
    retreatBias: 0.45,
    skillUsageBias: 0.9,
  ),
  FighterArchetype.bruiser: ArchetypeDefinition(
    archetype: FighterArchetype.bruiser,
    attackStyle: AttackStyle.fistSwing,
    displayName: '격투가',
    summary: '강력한 주먹으로 적을 압도하는 근거리 파이터.',
    weaponLabel: '주먹',
    colorValue: 0xFFFFB74D,
    baseStats: CombatStats(
      maxHp: 135,         // 체력 강화 — 맞으면서 접근하는 스타일
      attackDamage: 25,   // 붙으면 압도
      attackRange: 38,
      attackCooldown: 0.88,
      moveSpeed: 115,     // 기존 96 → 115: 투사체 피하며 접근 가능
      skillDamage: 36,
      skillSpeed: 240,
      skillCooldown: 5.0,
      skillRadius: 12,
    ),
    preferredRange: 42,
    approachBias: 0.9,
    strafeBias: 0.2,
    retreatBias: 0.35,    // 격투가는 거의 후퇴 안 함
    skillUsageBias: 0.85,
  ),
};

class PlayerProgress {
  FighterArchetype selectedArchetype = FighterArchetype.kiting;
  double bonusMaxHp = 0;
  double bonusAttackDamage = 0;
  double bonusAttackRange = 0;
  double bonusAttackCooldown = 0;
  double bonusMoveSpeed = 0;
  double bonusSkillDamage = 0;
  double bonusSkillSpeed = 0;
  double bonusSkillCooldown = 0;
  double bonusSkillRadius = 0;

  ArchetypeDefinition get selectedDefinition => archetypeCatalog[selectedArchetype]!;

  void selectArchetype(FighterArchetype archetype) {
    selectedArchetype = archetype;
    resetBonuses();
  }

  void resetBonuses() {
    bonusMaxHp = 0;
    bonusAttackDamage = 0;
    bonusAttackRange = 0;
    bonusAttackCooldown = 0;
    bonusMoveSpeed = 0;
    bonusSkillDamage = 0;
    bonusSkillSpeed = 0;
    bonusSkillCooldown = 0;
    bonusSkillRadius = 0;
  }

  CombatStats toCombatStats() {
    final CombatStats base = selectedDefinition.baseStats;
    return base.add(
      maxHp: bonusMaxHp,
      attackDamage: bonusAttackDamage,
      attackRange: bonusAttackRange,
      attackCooldown: bonusAttackCooldown,
      moveSpeed: bonusMoveSpeed,
      skillDamage: bonusSkillDamage,
      skillSpeed: bonusSkillSpeed,
      skillCooldown: bonusSkillCooldown,
      skillRadius: bonusSkillRadius,
    );
  }
}

class BattleConfig {
  const BattleConfig({
    required this.round,
    required this.playerDefinition,
    required this.enemyDefinition,
    required this.playerStats,
    required this.enemyStats,
    required this.playerAiConfidence,
    required this.enemyAiConfidence,
  });

  final int round;
  final ArchetypeDefinition playerDefinition;
  final ArchetypeDefinition enemyDefinition;
  final CombatStats playerStats;
  final CombatStats enemyStats;
  final double playerAiConfidence;
  final double enemyAiConfidence;

  String get playerName => playerDefinition.displayName;
  String get enemyName => enemyDefinition.displayName;
  int get enemyColorValue => enemyDefinition.colorValue;
}

class BattleHudData {
  const BattleHudData({
    required this.round,
    required this.playerDefinition,
    required this.enemyDefinition,
    required this.playerHp,
    required this.playerMaxHp,
    required this.enemyHp,
    required this.enemyMaxHp,
    required this.playerSkillReady,
    required this.enemySkillReady,
  });

  final int round;
  final ArchetypeDefinition playerDefinition;
  final ArchetypeDefinition enemyDefinition;
  final double playerHp;
  final double playerMaxHp;
  final double enemyHp;
  final double enemyMaxHp;
  final bool playerSkillReady;
  final bool enemySkillReady;
}

class GameFlowController extends ChangeNotifier {
  final Random _random = Random();
  final PlayerProgress playerProgress = PlayerProgress();

  FlowPhase phase = FlowPhase.menu;
  int round = 1;
  int bestRound = 0;
  String statusMessage = 'Defeat one enemy per round.';
  BattleConfig? currentBattle;
  List<RewardChoice> rewardChoices = <RewardChoice>[];

  void selectPlayerArchetype(FighterArchetype archetype) {
    playerProgress.selectArchetype(archetype);
    notifyListeners();
  }

  void goToMenu() {
    round = 1;
    playerProgress.resetBonuses();
    rewardChoices = <RewardChoice>[];
    currentBattle = null;
    phase = FlowPhase.menu;
    notifyListeners();
  }

  void startRun() {
    round = 1;
    playerProgress.resetBonuses();
    statusMessage = 'Round 1: auto duel started. You can still steer movement.';
    rewardChoices = <RewardChoice>[];
    currentBattle = _buildBattle(round);
    phase = FlowPhase.battle;
    notifyListeners();
  }

  void beginNextRound() {
    currentBattle = _buildBattle(round);
    statusMessage = 'Round $round: keep the auto fight favorable with manual movement.';
    phase = FlowPhase.battle;
    notifyListeners();
  }

  void finishBattle({required bool playerWon}) {
    if (playerWon) {
      bestRound = max(bestRound, round);
      round += 1;
      rewardChoices = _generateRewards();
      statusMessage = 'Round cleared. Pick one reward.';
      phase = FlowPhase.reward;
      notifyListeners();
      return;
    }

    bestRound = max(bestRound, round - 1);
    statusMessage = 'Game over. You reached round $round.';
    phase = FlowPhase.gameOver;
    notifyListeners();
  }

  void chooseReward(RewardChoice choice) {
    choice.definition.apply(playerProgress);
    beginNextRound();
  }

  BattleConfig _buildBattle(int currentRound) {
    final ArchetypeDefinition playerDefinition = playerProgress.selectedDefinition;
    final FighterArchetype enemyArchetype =
        FighterArchetype.values[_random.nextInt(FighterArchetype.values.length)];
    final ArchetypeDefinition enemyDefinition = archetypeCatalog[enemyArchetype]!;
    final double growth = 1 + (currentRound - 1) * 0.18;
    final double enemyAiConfidence = min(1, 0.54 + currentRound * 0.07);
    final double playerAiConfidence = 0.82;

    return BattleConfig(
      round: currentRound,
      playerDefinition: playerDefinition,
      enemyDefinition: enemyDefinition,
      playerStats: playerProgress.toCombatStats(),
      enemyStats: enemyDefinition.baseStats
          .scale(growth)
          .add(
            attackRange: currentRound * 1.5,
            moveSpeed: currentRound * 3,
            attackCooldown: -currentRound * 0.02,
            skillCooldown: -currentRound * 0.05,
          ),
      playerAiConfidence: playerAiConfidence,
      enemyAiConfidence: enemyAiConfidence,
    );
  }

  List<RewardChoice> _generateRewards() {
    final List<RewardDefinition> pool = List<RewardDefinition>.from(rewardPool)
      ..shuffle(_random);
    return pool.take(3).map(RewardChoice.new).toList();
  }
}

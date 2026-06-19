import 'dart:math';

import 'package:flutter/foundation.dart';

import 'reward.dart';

enum FlowPhase { menu, battle, reward, gameOver }

enum FighterArchetype { kiting, melee, bruiser }

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
    displayName: 'Hex Ranger',
    summary: 'Long range kiting fighter with evasive spacing.',
    weaponLabel: 'Bow',
    colorValue: 0xFF64B5F6,
    baseStats: CombatStats(
      maxHp: 82,
      attackDamage: 11,
      attackRange: 118,
      attackCooldown: 1.0,
      moveSpeed: 104,
      skillDamage: 25,
      skillSpeed: 300,
      skillCooldown: 4.3,
      skillRadius: 10,
    ),
    preferredRange: 150,
    approachBias: 0.42,
    strafeBias: 1.0,
    retreatBias: 1.0,
    skillUsageBias: 1.0,
  ),
  FighterArchetype.melee: ArchetypeDefinition(
    archetype: FighterArchetype.melee,
    displayName: 'Blade Dash',
    summary: 'Fast sword duelist that sticks close and cuts often.',
    weaponLabel: 'Sword',
    colorValue: 0xFFE57373,
    baseStats: CombatStats(
      maxHp: 92,
      attackDamage: 16,
      attackRange: 40,
      attackCooldown: 0.72,
      moveSpeed: 118,
      skillDamage: 24,
      skillSpeed: 260,
      skillCooldown: 4.8,
      skillRadius: 9,
    ),
    preferredRange: 58,
    approachBias: 1.0,
    strafeBias: 0.28,
    retreatBias: 0.2,
    skillUsageBias: 0.75,
  ),
  FighterArchetype.bruiser: ArchetypeDefinition(
    archetype: FighterArchetype.bruiser,
    displayName: 'Iron Boxer',
    summary: 'Heavy fist fighter with balanced chase and sustain.',
    weaponLabel: 'Fist',
    colorValue: 0xFFFFB74D,
    baseStats: CombatStats(
      maxHp: 120,
      attackDamage: 18,
      attackRange: 48,
      attackCooldown: 0.92,
      moveSpeed: 96,
      skillDamage: 30,
      skillSpeed: 230,
      skillCooldown: 5.3,
      skillRadius: 12,
    ),
    preferredRange: 76,
    approachBias: 0.76,
    strafeBias: 0.45,
    retreatBias: 0.45,
    skillUsageBias: 0.62,
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
    required this.playerName,
    required this.enemyName,
    required this.playerHp,
    required this.playerMaxHp,
    required this.enemyHp,
    required this.enemyMaxHp,
    required this.playerSkillReady,
    required this.enemySkillReady,
    required this.playerWeapon,
    required this.enemyWeapon,
  });

  final int round;
  final String playerName;
  final String enemyName;
  final double playerHp;
  final double playerMaxHp;
  final double enemyHp;
  final double enemyMaxHp;
  final bool playerSkillReady;
  final bool enemySkillReady;
  final String playerWeapon;
  final String enemyWeapon;
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

  static const List<FighterArchetype> enemyRotation = <FighterArchetype>[
    FighterArchetype.kiting,
    FighterArchetype.melee,
    FighterArchetype.bruiser,
  ];

  void selectPlayerArchetype(FighterArchetype archetype) {
    playerProgress.selectArchetype(archetype);
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
    final ArchetypeDefinition enemyDefinition =
        archetypeCatalog[enemyRotation[(currentRound - 1) % enemyRotation.length]]!;
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

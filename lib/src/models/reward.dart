import 'dart:math';

import 'game_state.dart';

class RewardDefinition {
  const RewardDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.apply,
  });

  final String id;
  final String title;
  final String description;
  final void Function(PlayerProgress progress) apply;
}

class RewardChoice {
  const RewardChoice(this.definition);

  final RewardDefinition definition;
}

final List<RewardDefinition> rewardPool = <RewardDefinition>[
  RewardDefinition(
    id: 'steel_blade',
    title: 'Steel Blade',
    description: 'Basic attacks deal 4 more damage.',
    apply: (PlayerProgress progress) => progress.bonusAttackDamage += 4,
  ),
  RewardDefinition(
    id: 'quick_boots',
    title: 'Quick Boots',
    description: 'Move speed increases by 20.',
    apply: (PlayerProgress progress) => progress.bonusMoveSpeed += 20,
  ),
  RewardDefinition(
    id: 'vital_plate',
    title: 'Vital Plate',
    description: 'Max HP increases by 25.',
    apply: (PlayerProgress progress) => progress.bonusMaxHp += 25,
  ),
  RewardDefinition(
    id: 'focus_core',
    title: 'Focus Core',
    description: 'Skill damage increases by 8.',
    apply: (PlayerProgress progress) => progress.bonusSkillDamage += 8,
  ),
  RewardDefinition(
    id: 'rapid_trigger',
    title: 'Rapid Trigger',
    description: 'Attack cooldown is reduced by 0.12s.',
    apply: (PlayerProgress progress) {
      progress.bonusAttackCooldown =
          max(-0.44, progress.bonusAttackCooldown - 0.12);
    },
  ),
  RewardDefinition(
    id: 'mana_coil',
    title: 'Mana Coil',
    description: 'Skill cooldown is reduced by 0.45s.',
    apply: (PlayerProgress progress) {
      progress.bonusSkillCooldown = max(-1.8, progress.bonusSkillCooldown - 0.45);
    },
  ),
];

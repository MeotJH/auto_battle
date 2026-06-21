import 'dart:ui';

import '../models/game_state.dart';
import '../models/reward.dart';

enum AppLanguage { english, korean }

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isKorean => language == AppLanguage.korean;

  Locale get locale => Locale(isKorean ? 'ko' : 'en');

  String get appTitle => isKorean ? '미드 라인 로그라이크' : 'Mid Lane Roguelite';
  String get chooseYourStyle => isKorean ? '직업 선택' : 'Choose Your Style';
  String get introBody => isKorean
      ? '탑다운 1대1 자동 결투입니다. 양쪽 모두 자동으로 이동하고 공격합니다. 당신은 이동을 보정하고 원할 때 Q 스킬을 직접 발동할 수 있습니다.'
      : 'Top-down 1:1 auto duel. Both sides move and attack automatically. You steer movement and can trigger Q whenever you want.';
  String selectedFighter(ArchetypeDefinition definition) => isKorean
      ? '선택됨: ${archetypeName(definition)} · ${weaponLabel(definition)}'
      : 'Selected: ${archetypeName(definition)} · ${weaponLabel(definition)}';
  String get startRun => isKorean ? '시작' : 'Start Run';
  String get tryAgain => isKorean ? '다시 도전' : 'Try Again';
  String get goToCharacterSelect => isKorean ? '캐릭터 선택으로' : 'Character Select';
  String get roundClear => isKorean ? '라운드 클리어' : 'Round Clear';
  String get runOver => isKorean ? '실패' : 'Run Over';
  String bestClearedRound(int round) =>
      isKorean ? '최고 클리어 라운드: $round' : 'Best cleared round: $round';
  String get skill => isKorean ? '스킬' : 'Skill';
  String get up => isKorean ? '위' : 'UP';
  String get down => isKorean ? '아래' : 'DOWN';
  String get left => isKorean ? '왼쪽' : 'LEFT';
  String get right => isKorean ? '오른쪽' : 'RIGHT';
  String get jump => isKorean ? '점프' : 'JUMP';
  String get hp => 'HP';
  String get attack => isKorean ? '공격' : 'ATK';
  String get range => isKorean ? '사거리' : 'Range';
  String get move => isKorean ? '이동' : 'Move';
  String get best => isKorean ? '최고기록' : 'Best';
  String get playerSkillReady => isKorean ? 'Q 준비' : 'Q Ready';
  String get playerSkillCooldown => isKorean ? 'Q 재사용' : 'Q Cooldown';
  String get enemySkillReady => isKorean ? '스킬 준비' : 'Skill Up';
  String get enemySkillCooldown => isKorean ? '스킬 재사용' : 'Skill Down';
  String get battleHint => isKorean
      ? '전투는 완전 자동으로 진행됩니다. 캐릭터와 미니언이 플랫폼을 오가며 전투하고, 타워도 사거리 안의 적을 자동으로 공격합니다.'
      : 'Combat is fully automatic. Heroes and minions navigate platforms on their own, and towers auto-fire at enemies in range.';
  String statusFor(GameFlowController controller) {
    switch (controller.phase) {
      case FlowPhase.menu:
        return isKorean ? '적 하나를 쓰러뜨리면 라운드 승리입니다.' : 'Defeat one enemy per round.';
      case FlowPhase.battle:
        return isKorean
            ? '${controller.round}라운드: 이동 조작으로 자동 전투의 간격을 유리하게 만드세요.'
            : 'Round ${controller.round}: keep the auto fight favorable with manual movement.';
      case FlowPhase.reward:
        return isKorean ? '라운드 클리어. 보상 하나를 고르세요.' : 'Round cleared. Pick one reward.';
      case FlowPhase.gameOver:
        return isKorean
            ? '게임 오버. ${controller.round}라운드까지 도달했습니다.'
            : 'Game over. You reached round ${controller.round}.';
    }
  }

  String archetypeName(ArchetypeDefinition definition) {
    switch (definition.archetype) {
      case FighterArchetype.kiting:
        return isKorean ? '마법사' : 'Mage';
      case FighterArchetype.melee:
        return isKorean ? '검사' : 'Swordsman';
      case FighterArchetype.bruiser:
        return isKorean ? '격투가' : 'Brawler';
    }
  }

  String archetypeSummary(ArchetypeDefinition definition) {
    switch (definition.archetype) {
      case FighterArchetype.kiting:
        return isKorean
            ? '원거리 마법 공격으로 거리를 유지하며 싸우는 마법사입니다.'
            : 'A mage who fights from range using powerful magic spells.';
      case FighterArchetype.melee:
        return isKorean
            ? '빠른 검격으로 적에게 밀착해 싸우는 전사입니다.'
            : 'Fast sword duelist that sticks close and cuts often.';
      case FighterArchetype.bruiser:
        return isKorean
            ? '강력한 주먹으로 적을 압도하는 근거리 파이터입니다.'
            : 'Heavy brawler with powerful fists and high sustain.';
    }
  }

  String weaponLabel(ArchetypeDefinition definition) {
    switch (definition.archetype) {
      case FighterArchetype.kiting:
        return isKorean ? '마법' : 'Magic';
      case FighterArchetype.melee:
        return isKorean ? '검' : 'Sword';
      case FighterArchetype.bruiser:
        return isKorean ? '주먹' : 'Fist';
    }
  }

  String rewardTitle(RewardDefinition definition) {
    switch (definition.id) {
      case 'steel_blade':
        return isKorean ? '강철 검날' : 'Steel Blade';
      case 'quick_boots':
        return isKorean ? '신속 장화' : 'Quick Boots';
      case 'vital_plate':
        return isKorean ? '생명 판금' : 'Vital Plate';
      case 'focus_core':
        return isKorean ? '집중 코어' : 'Focus Core';
      case 'rapid_trigger':
        return isKorean ? '속사 장치' : 'Rapid Trigger';
      case 'mana_coil':
        return isKorean ? '마나 코일' : 'Mana Coil';
      default:
        return definition.title;
    }
  }

  String rewardDescription(RewardDefinition definition) {
    switch (definition.id) {
      case 'steel_blade':
        return isKorean ? '기본 공격 피해가 4 증가합니다.' : 'Basic attacks deal 4 more damage.';
      case 'quick_boots':
        return isKorean ? '이동 속도가 20 증가합니다.' : 'Move speed increases by 20.';
      case 'vital_plate':
        return isKorean ? '최대 HP가 25 증가합니다.' : 'Max HP increases by 25.';
      case 'focus_core':
        return isKorean ? '스킬 피해가 8 증가합니다.' : 'Skill damage increases by 8.';
      case 'rapid_trigger':
        return isKorean ? '공격 재사용 대기시간이 0.12초 감소합니다.' : 'Attack cooldown is reduced by 0.12s.';
      case 'mana_coil':
        return isKorean ? '스킬 재사용 대기시간이 0.45초 감소합니다.' : 'Skill cooldown is reduced by 0.45s.';
      default:
        return definition.description;
    }
  }
}

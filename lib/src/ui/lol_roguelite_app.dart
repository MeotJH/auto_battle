import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../game/mid_lane_game.dart';
import '../models/game_state.dart';
import '../models/reward.dart';
import 'app_strings.dart';

class LolRogueliteApp extends StatefulWidget {
  const LolRogueliteApp({super.key});

  @override
  State<LolRogueliteApp> createState() => _LolRogueliteAppState();
}

class _LolRogueliteAppState extends State<LolRogueliteApp> {
  AppLanguage _language = AppLanguage.korean;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings(_language);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: strings.appTitle,
      locale: strings.locale,
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ko'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07111D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7AE582),
          secondary: Color(0xFFFFD166),
          surface: Color(0xFF102033),
        ),
        useMaterial3: true,
      ),
      home: GameShell(
        strings: strings,
        language: _language,
        onLanguageChanged: (AppLanguage language) {
          setState(() {
            _language = language;
          });
        },
      ),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({
    super.key,
    required this.strings,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppStrings strings;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final GameFlowController controller = GameFlowController();

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (controller.phase) {
                FlowPhase.menu => _MenuView(
                    controller: controller,
                    strings: widget.strings,
                  ),
                FlowPhase.battle => _BattleView(
                    key: ValueKey<String>(
                      '${controller.currentBattle!.round}-${controller.currentBattle!.playerDefinition.archetype.name}',
                    ),
                    controller: controller,
                    config: controller.currentBattle!,
                    strings: widget.strings,
                  ),
                FlowPhase.reward => _RewardView(
                    controller: controller,
                    strings: widget.strings,
                  ),
                FlowPhase.gameOver => _GameOverView(
                    controller: controller,
                    strings: widget.strings,
                  ),
              },
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _LanguageToggle(
                language: widget.language,
                onChanged: widget.onLanguageChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuView extends StatelessWidget {
  const _MenuView({
    required this.controller,
    required this.strings,
  });

  final GameFlowController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final PlayerProgress progress = controller.playerProgress;
    final CombatStats stats = progress.toCombatStats();
    final ArchetypeDefinition selected = progress.selectedDefinition;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(0, MediaQuery.sizeOf(context).height - 40),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'MID LANE\nROGUELITE',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.introBody,
              style: TextStyle(color: Color(0xFFC7D2E1), height: 1.45),
            ),
            const SizedBox(height: 24),
            Text(
              strings.chooseYourStyle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            for (final FighterArchetype archetype in FighterArchetype.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ArchetypeCard(
                  definition: archetypeCatalog[archetype]!,
                  selected: progress.selectedArchetype == archetype,
                  onTap: () => controller.selectPlayerArchetype(archetype),
                  strings: strings,
                ),
              ),
            const SizedBox(height: 18),
            Text(
              strings.selectedFighter(selected),
              style: const TextStyle(
                color: Color(0xFF7AE582),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _StatLine(label: strings.hp, value: stats.maxHp.toStringAsFixed(0)),
            _StatLine(label: strings.attack, value: stats.attackDamage.toStringAsFixed(0)),
            _StatLine(label: strings.range, value: stats.attackRange.toStringAsFixed(0)),
            _StatLine(label: strings.move, value: stats.moveSpeed.toStringAsFixed(0)),
            _StatLine(label: strings.best, value: controller.bestRound.toString()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: controller.startRun,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(strings.startRun),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleView extends StatefulWidget {
  const _BattleView({
    super.key,
    required this.controller,
    required this.config,
    required this.strings,
  });

  final GameFlowController controller;
  final BattleConfig config;
  final AppStrings strings;

  @override
  State<_BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<_BattleView> {
  late final MidLaneGame game;

  @override
  void initState() {
    super.initState();
    game = MidLaneGame(
      config: widget.config,
      onBattleFinished: (bool playerWon) {
        if (mounted) {
          widget.controller.finishBattle(playerWon: playerWon);
        }
      },
    );
  }

  @override
  void dispose() {
    game.hud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GameWidget(game: game),
        ValueListenableBuilder<BattleHudData>(
          valueListenable: game.hud,
          builder: (BuildContext context, BattleHudData hud, _) {
            return _BattleHud(
              data: hud,
              strings: widget.strings,
            );
          },
        ),
      ],
    );
  }
}

class _BattleHud extends StatelessWidget {
  const _BattleHud({
    required this.data,
    required this.strings,
  });

  final BattleHudData data;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _HpPanel(
                    name: strings.archetypeName(data.playerDefinition),
                    subtitle: strings.weaponLabel(data.playerDefinition),
                    current: data.playerHp,
                    max: data.playerMaxHp,
                    accent: const Color(0xFF7AE582),
                    trailing: data.playerSkillReady
                        ? strings.playerSkillReady
                        : strings.playerSkillCooldown,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'R${data.round}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: _HpPanel(
                    name: strings.archetypeName(data.enemyDefinition),
                    subtitle: strings.weaponLabel(data.enemyDefinition),
                    current: data.enemyHp,
                    max: data.enemyMaxHp,
                    accent: const Color(0xFFFFD166),
                    trailing: data.enemySkillReady
                        ? strings.enemySkillReady
                        : strings.enemySkillCooldown,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xAA09121F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                strings.battleHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFFD8E1F0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardView extends StatelessWidget {
  const _RewardView({
    required this.controller,
    required this.strings,
  });

  final GameFlowController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            strings.roundClear,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.statusFor(controller),
            style: const TextStyle(color: Color(0xFFC8D3E2)),
          ),
          const SizedBox(height: 20),
          for (final RewardChoice choice in controller.rewardChoices)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RewardCard(
                choice: choice,
                onTap: () => controller.chooseReward(choice),
                strings: strings,
              ),
            ),
        ],
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  const _GameOverView({
    required this.controller,
    required this.strings,
  });

  final GameFlowController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ArchetypeDefinition selected = controller.playerProgress.selectedDefinition;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            strings.runOver,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '${strings.archetypeName(selected)} · ${strings.weaponLabel(selected)}',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.statusFor(controller),
            style: const TextStyle(color: Color(0xFFC8D3E2), height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            strings.bestClearedRound(controller.bestRound),
            style: const TextStyle(
              color: Color(0xFF7AE582),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.startRun,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(strings.tryAgain),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: controller.goToMenu,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(strings.goToCharacterSelect),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HpPanel extends StatelessWidget {
  const _HpPanel({
    required this.name,
    required this.subtitle,
    required this.current,
    required this.max,
    required this.accent,
    required this.trailing,
    this.alignEnd = false,
  });

  final String name;
  final String subtitle;
  final double current;
  final double max;
  final Color accent;
  final String trailing;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final double ratio = (current / max).clamp(0, 1);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF93A4BC)),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: const Color(0xFF223042),
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${current.ceil()}/${max.ceil()} · $trailing',
          style: const TextStyle(fontSize: 11, color: Color(0xFFC8D3E2)),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.choice,
    required this.onTap,
    required this.strings,
  });

  final RewardChoice choice;
  final VoidCallback onTap;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF112135),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF253751)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.rewardTitle(choice.definition),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              strings.rewardDescription(choice.definition),
              style: const TextStyle(color: Color(0xFFC8D3E2), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  const _ArchetypeCard({
    required this.definition,
    required this.selected,
    required this.onTap,
    required this.strings,
  });

  final ArchetypeDefinition definition;
  final bool selected;
  final VoidCallback onTap;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final Color border = selected
        ? const Color(0xFF7AE582)
        : const Color(0xFF253751);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF112135),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 56,
              decoration: BoxDecoration(
                color: Color(definition.colorValue),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${strings.archetypeName(definition)} · ${strings.weaponLabel(definition)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.archetypeSummary(definition),
                    style: const TextStyle(
                      color: Color(0xFFC8D3E2),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.language,
    required this.onChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC112135),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF253751)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageChip(
              label: 'EN',
              selected: language == AppLanguage.english,
              onTap: () => onChanged(AppLanguage.english),
            ),
            const SizedBox(width: 4),
            _LanguageChip(
              label: 'KO',
              selected: language == AppLanguage.korean,
              onTap: () => onChanged(AppLanguage.korean),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7AE582) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF08111B) : const Color(0xFFC8D3E2),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF93A4BC)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

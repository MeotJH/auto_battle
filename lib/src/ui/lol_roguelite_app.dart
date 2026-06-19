import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/mid_lane_game.dart';
import '../models/game_state.dart';
import '../models/reward.dart';

class LolRogueliteApp extends StatelessWidget {
  const LolRogueliteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mid Lane Roguelite',
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
      home: const GameShell(),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (controller.phase) {
            FlowPhase.menu => _MenuView(controller: controller),
            FlowPhase.battle => _BattleView(
                key: ValueKey<String>(
                  '${controller.currentBattle!.round}-${controller.currentBattle!.playerDefinition.archetype.name}',
                ),
                controller: controller,
                config: controller.currentBattle!,
              ),
            FlowPhase.reward => _RewardView(controller: controller),
            FlowPhase.gameOver => _GameOverView(controller: controller),
          },
        ),
      ),
    );
  }
}

class _MenuView extends StatelessWidget {
  const _MenuView({required this.controller});

  final GameFlowController controller;

  @override
  Widget build(BuildContext context) {
    final PlayerProgress progress = controller.playerProgress;
    final CombatStats stats = progress.toCombatStats();
    final ArchetypeDefinition selected = progress.selectedDefinition;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 40,
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
            const Text(
              'Top-down 1:1 auto duel. Both sides move and attack automatically. You steer movement and can trigger Q whenever you want.',
              style: TextStyle(color: Color(0xFFC7D2E1), height: 1.45),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose Your Style',
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
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'Selected: ${selected.displayName} · ${selected.weaponLabel}',
              style: const TextStyle(
                color: Color(0xFF7AE582),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _StatLine(label: 'HP', value: stats.maxHp.toStringAsFixed(0)),
            _StatLine(label: 'ATK', value: stats.attackDamage.toStringAsFixed(0)),
            _StatLine(label: 'Range', value: stats.attackRange.toStringAsFixed(0)),
            _StatLine(label: 'Move', value: stats.moveSpeed.toStringAsFixed(0)),
            _StatLine(label: 'Best', value: controller.bestRound.toString()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: controller.startRun,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Start Run'),
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
  });

  final GameFlowController controller;
  final BattleConfig config;

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
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GameWidget(game: game),
              ValueListenableBuilder<BattleHudData>(
                valueListenable: game.hud,
                builder: (BuildContext context, BattleHudData hud, _) {
                  return _BattleHud(data: hud);
                },
              ),
            ],
          ),
        ),
        _Controls(game: game),
      ],
    );
  }
}

class _BattleHud extends StatelessWidget {
  const _BattleHud({required this.data});

  final BattleHudData data;

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
                    name: data.playerName,
                    subtitle: data.playerWeapon,
                    current: data.playerHp,
                    max: data.playerMaxHp,
                    accent: const Color(0xFF7AE582),
                    trailing: data.playerSkillReady ? 'Q Ready' : 'Q Cooldown',
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
                    name: data.enemyName,
                    subtitle: data.enemyWeapon,
                    current: data.enemyHp,
                    max: data.enemyMaxHp,
                    accent: const Color(0xFFFFD166),
                    trailing: data.enemySkillReady ? 'Skill Up' : 'Skill Down',
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
              child: const Text(
                'Your fighter auto-moves, auto-attacks, and auto-casts. Use the pad to bias spacing or force an angle, and tap Q to cast manually too.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFFD8E1F0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardView extends StatelessWidget {
  const _RewardView({required this.controller});

  final GameFlowController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Round Clear',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.statusMessage,
            style: const TextStyle(color: Color(0xFFC8D3E2)),
          ),
          const SizedBox(height: 20),
          for (final RewardChoice choice in controller.rewardChoices)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RewardCard(
                choice: choice,
                onTap: () => controller.chooseReward(choice),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  const _GameOverView({required this.controller});

  final GameFlowController controller;

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
            'Run Over',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '${selected.displayName} · ${selected.weaponLabel}',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.statusMessage,
            style: const TextStyle(color: Color(0xFFC8D3E2), height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Best cleared round: ${controller.bestRound}',
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Try Again'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.game});

  final MidLaneGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF09121D),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _DirectionPad(game: game),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Skill',
                style: TextStyle(
                  color: Color(0xFF93A4BC),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 104,
                height: 104,
                child: FilledButton(
                  onPressed: game.castPlayerSkill,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: const Color(0xFF231900),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Q',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionPad extends StatefulWidget {
  const _DirectionPad({required this.game});

  final MidLaneGame game;

  @override
  State<_DirectionPad> createState() => _DirectionPadState();
}

class _DirectionPadState extends State<_DirectionPad> {
  final Set<_Direction> activeDirections = <_Direction>{};

  void _setDirection(_Direction direction, bool active) {
    if (active) {
      activeDirections.add(direction);
    } else {
      activeDirections.remove(direction);
    }
    widget.game.setInput(_composeVector());
    setState(() {});
  }

  Vector2 _composeVector() {
    double x = 0;
    double y = 0;
    if (activeDirections.contains(_Direction.left)) {
      x -= 1;
    }
    if (activeDirections.contains(_Direction.right)) {
      x += 1;
    }
    if (activeDirections.contains(_Direction.up)) {
      y -= 1;
    }
    if (activeDirections.contains(_Direction.down)) {
      y += 1;
    }
    return Vector2(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PadButton(
          label: 'UP',
          active: activeDirections.contains(_Direction.up),
          onChanged: (bool active) => _setDirection(_Direction.up, active),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PadButton(
              label: 'LEFT',
              active: activeDirections.contains(_Direction.left),
              onChanged: (bool active) => _setDirection(_Direction.left, active),
            ),
            const SizedBox(width: 10),
            _PadButton(
              label: 'DOWN',
              active: activeDirections.contains(_Direction.down),
              onChanged: (bool active) => _setDirection(_Direction.down, active),
            ),
            const SizedBox(width: 10),
            _PadButton(
              label: 'RIGHT',
              active: activeDirections.contains(_Direction.right),
              onChanged: (bool active) =>
                  _setDirection(_Direction.right, active),
            ),
          ],
        ),
      ],
    );
  }
}

enum _Direction { up, down, left, right }

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.label,
    required this.active,
    required this.onChanged,
  });

  final String label;
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color background =
        active ? const Color(0xFF2E4765) : const Color(0xFF172436);
    return Listener(
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A3A52)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
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
  });

  final RewardChoice choice;
  final VoidCallback onTap;

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
              choice.definition.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              choice.definition.description,
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
  });

  final ArchetypeDefinition definition;
  final bool selected;
  final VoidCallback onTap;

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
                    '${definition.displayName} · ${definition.weaponLabel}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    definition.summary,
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

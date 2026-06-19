# AGENTS

## Purpose

This repository builds a Flutter + Flame mobile combat prototype.
Code changes should preserve a clear separation between app flow, combat harness, and UI controls.

## Architecture Rules

- `lib/src/models`
  Contains immutable config objects and high-level run state.
- `lib/src/game`
  Contains the combat harness and all runtime combat objects.
- `lib/src/ui`
  Contains Flutter screens, HUD widgets, and touch controls only.

## Combat Harness

- `MidLaneGame` is the battle harness entry point.
- `BattleArena` owns spatial rules and spawn positions.
- `FighterComponent` owns combatant state and rendering.
- `EnemyBattleBrain` owns enemy decision making.
- `ProjectileComponent` owns projectile movement only.

Do not move AI heuristics into widgets.
Do not put touch input handling directly into combatant classes.
Prefer adding new behavior by introducing a new class instead of growing `MidLaneGame`.

## Gameplay Direction

- Camera style: top-down arena duel.
- Core loop: one enemy kill wins the round, player death ends the run.
- Player controls: manual movement plus active `Q` skill.
- Enemy behavior should prioritize spacing, strafing, retreat logic, and projectile dodging.

## Verification

- Run `flutter analyze`
- Run `flutter test`

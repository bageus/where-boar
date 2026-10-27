---
task_version: 1
task_id: P3-010
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-010 — петух-загонщик и индюк-разведчик (M016, M017, D024, D025).

## Goal

На карте водятся дикие петух и индюк; пойманные сетью, они живут в загоне лагеря. На охоте Z зовёт петуха — он залетает за ближайшую группу и гонит её криком прямо на охотника; X зовёт индюка — он отмечает всех кабанов на миникарте на 20 с.

## Why this matters

Животные-помощники входят в MVP (D025) и дают загон без второго игрока.

## In scope

- `features.companions` (новый): `companion_rules.gd` (точка посадки петуха, ближайшая группа), `wild_animal.gd` + `wild_rooster.tscn`/`wild_turkey.tscn`, `rooster_driver.tscn`.
- `features.boar`: `driven_from` — бег прямо от петуха.
- `features.hunter`: сеть ловит всё, что отвечает на `net_hit`.
- `features.hunt` / `features.settlement`: `helpers_caught` → `Progress.helpers` (загон), в сохранении.
- `presentation.hunt_map`: спавн диких птиц на свободных точках, призыв Z/X раз за охоту, метки на миникарте.
- `presentation.camp`: загон в HUD лагеря.
- Smoke-тест считает выполненные проверки: ошибка скрипта больше не прячет пропущенные проверки (с P3-007 часть проверок крика молча не выполнялась — исправлено).

## Out of scope

- Отдельная сцена загона в лагере (P3-012 вместе с ездовыми).

## Acceptance criteria

- [x] Given группа к северу от охотника, Then петух садится за ней, на 8 м дальше (тест companions).
- [x] Given пойманный сетью петух, Then он в загоне после охоты (тесты settlement, smoke).
- [x] Given индюк в загоне, When X, Then кабаны на миникарте (smoke-тест).

## Decisions made during this task

- [ASSUMPTION] Клавиши Z/X; каждый вид помогает раз за охоту и не расходуется; на карте по одной дикой птице; крик петуха слышен в 12 м; метки индюка 20 с (D013).

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-011.

## Session handoff

- Completed: P3-010.

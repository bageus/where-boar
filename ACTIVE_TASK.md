---
task_version: 1
task_id: P3-011
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-011 — помощники: носильщик и установщик ловушек (M013).

## Goal

В таверне нанимаются носильщик (+2 сети, +6 стрел на каждую охоту) и установщик ловушек (в начале охоты ставит 2 ловушки со склада перед зонами побега).

## Why this matters

Помощники входят в MVP (D021) и дают дорогую цель для бивней.

## In scope

- `features.settlement`: `item_porter` 60, `item_trap_setter` 80 в лавке «tavern».
- `features.hunter`: носильщик в `Loadout.equip`; `place_any_trap`; `Hunter.set_trap_for_hunter`.
- `presentation.hunt_map`: установщик ставит ловушки в 5 м перед первыми двумя зонами побега.
- `presentation.camp`: станция «Tavern».

## Out of scope

- Носильщик как видимый персонаж.

## Acceptance criteria

- [x] Given нанят носильщик, Then сетей 5, стрел 18 (тест hunter).
- [x] Given нанят установщик и 3 силка, When охота началась, Then 2 ловушки на карте, 1 силок остался (smoke-тест).

## Decisions made during this task

- [ASSUMPTION] Что делают помощники, спецификация не уточняет; эффекты и цены 60/80 выбраны AI (D013); найм навсегда.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-012.

## Session handoff

- Completed: P3-011.

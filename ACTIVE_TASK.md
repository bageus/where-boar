---
task_version: 1
task_id: P3-007
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-007 — ловушки: яма, силок, трос, клетка, забор; охотничья хижина (M015, D023, D024).

## Goal

Охотник покупает ловушки в хижине, ставит их на карте (G — выбор, T — поставить), и кабаны попадают в них по правилам D023/D024.

## Why this matters

Ловушки — основной инструмент загона и живой поимки.

## In scope

- `features.boar`: TRAPPED держит кабана при ранении; `break_free`; сеть и клетка ловят и пойманного в ловушку; агент: `fall_in_pit`, `snare` (большие вырываются: злой 12 с, броненосец 8 с), `trip` (оглушение 3 с), `cage_capture`, разворот о забор; сигнал `held_changed`.
- `features.hunter`: сцены `presentation/traps/*.tscn`, ловушки в `Loadout`, `place_trap`, HUD.
- `features.hunt`: `held`, `close_traps` — кабаны в ловушке засчитываются пойманными в конце охоты; охота кончается, когда свободных не осталось.
- `features.settlement`: ловушки в каталоге хижины (яма 40, силок 30, трос 30, клетка 60, забор 35).
- `project.godot`: `trap_next` (G), `trap_place` (T).

## Out of scope

- Установщик ловушек (P3-011).

## Acceptance criteria

- [x] Given кабан в ловушке, When удар не убивает, Then он остаётся в ловушке; сеть ловит его; силок можно сорвать (тест boar).
- [x] Given последний свободный кабан попал в ловушку, Then охота окончена, он засчитан пойманным (тест hunt).
- [x] Given яма под кабаном, Then TRAPPED, «в ловушках: 1», в итогах — пойман (smoke-тест).
- [x] Ловушки выбираются и кончаются (тест hunter).

## Decisions made during this task

- [ASSUMPTION] Клавиши G/T (в карте управления раздела 05 ловушек нет); каждая ловушка срабатывает один раз; трос исчезает после срабатывания; цены 30–60 по таблице лавок.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-008.

## Session handoff

- Completed: P3-007.

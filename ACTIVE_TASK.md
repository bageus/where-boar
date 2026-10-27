---
task_version: 1
task_id: P3-008
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-008 — стада и группы, испуг передаётся соседям (M009).

## Goal

На карте пасутся стадо, группы и одиночки; испуганный кабан поднимает соседей по стаду, отбившиеся кабаны возвращаются к своим.

## Why this matters

Цепная реакция стада — главный источник «историй» в погоне.

## In scope

- `features.boar`: `BoarSenses.hear_herd`, `cohesion_heading`; агент: общий массив `herd`; `presentation/boar_surroundings.gd` собирает позиции соседей и приманок (вынесено из `boar_body.gd`, чтобы файл остался до 300 строк).
- `presentation.hunt_map`: спавн группами `[10, 3, 3, 3, 1, 1]` по случайным точкам.

## Out of scope

- Карта Green Valley с 1–5 стадами по 10–30 (P3-013).

## Acceptance criteria

- [x] Given испуганный сосед в 8 м, Then спокойный кабан бежит; дальний нет (тест senses).
- [x] Given отбившийся кабан дальше 6 м от центра, Then он идёт обратно (тест senses).
- [x] На карте 21 кабан группами; испуг первого поднимает стадо (smoke-тест).

## Decisions made during this task

- [ASSUMPTION] Радиус тревоги 8 м, разброс стада 6 м, состав групп уменьшен под серую карту 80×80 (D013).
- Ревью размера: `boar_body.gd` дорос до 328 строк; чтение окружения вынесено в `boar_surroundings.gd` (299 строк).

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-009.

## Session handoff

- Completed: P3-008.

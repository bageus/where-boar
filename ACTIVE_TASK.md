---
task_version: 1
task_id: P3-002
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-002 — 5 видов кабанов данными (.tres), спавн по редкости, награды по типу (раздел 15, D022).

## Goal

На охоте встречаются лесной, быстрый, злой, броненосец и золотой бивень; каждый выглядит, бегает, бьёт и оплачивается по своему типу.

## Why this matters

Типы дают выбор цели и ценность редкой добычи.

## In scope

- `features.boar`: `public/boar_type.gd` (Resource), `public/boar_types.gd` (список, выбор по весу, таблица наград), `content/boar_*.tres`; агент берёт числа и цвет из типа.
- `features.hunt`: награды берутся из типов (таблица из кода удалена).
- `presentation.hunt_map`: 6 кабанов, тип по редкости; итоги показывают названия типов.

## Out of scope

- Стада (P3-008).

## Acceptance criteria

- [x] Given 5 типов, Then порядок и выбор по весу: бросок 0 — лесной, 0,999 — золотой (тест `run_boar_tests.gd`).
- [x] Given убит лесной и пойман золотой, Then 2 + 20 бивней (тест `run_hunt_tests.gd`).
- [x] Злой всегда атакует после паники; броненосец почти не отбрасывается; быстрый и золотой видят охотника издалека.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- Импорт без ошибок; все тесты 0 failures (smoke 6 прогонов подряд); `validate_project.py` passed.

## Decisions made during this task

- [ASSUMPTION] Веса спавна 50/20/20/8/2; скорости бегства 8/10/8/6,5/10,5 м/с; радиус восприятия 12/16/12/10/22 м; шанс атаки 0,35/0,2/1/0,5/0,3; броненосец получает 20% отбрасывания (D013).
- [ASSUMPTION] 6 кабанов на охоту до появления стад.

## Blockers

- None.

## Next exact action

Start P3-003 (save).

## Session handoff

- Completed: P3-002.

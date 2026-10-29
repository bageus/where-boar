---
task_version: 1
task_id: P3-026
status: DONE
phase: 3
owner: AI
updated: 2026-10-29
---

# Active Task

P3-026 — модели петуха и индюка (толстый и тонкий), анимации, больше птиц на охоте.

## Goal

Игрушечные петухи и индюки по референсам владельца, в своих расцветках, с анимациями в игре.

## Why this matters

Просьба владельца 2026-10-29 с тремя картинками-референсами.

## In scope

- Процедурные модели (`tools/build_birds.py`), две версии на вид: толстая и тонкая.
- Анимации: стойка, ходьба, бег, клюёт землю.
- Замена шаров на охоте, в клетках лагеря и у петуха-помощника; больше птиц на охоте; птицы в просмотрщике анимаций.

## Out of scope

- Новые правила для птиц (скорость, поимка) — без изменений.

## Acceptance criteria

- [x] Given 4 модели, Then у каждой скелет и анимации idle, walk, run, peck.
- [x] Given охота, Then 6 петухов и 6 индюков, случайная версия, ходьба/бег по скорости, клюют на остановках.
- [x] Given просмотрщик анимаций, Then можно выбрать любую птицу и анимацию.

## Decisions made during this task

- (ASSUMPTION) Расцветки: петух кремовый с охристыми крыльями и сине-зелёным хвостом; индюк коричневый с голубой головой и бронзово-бирюзово-кремовым веером.
- (ASSUMPTION) 3 петуха и 3 индюка у каждой свободной точки появления; 40% остановок — клюёт.

## Progress

- Реализовано, тесты зелёные.

## Validation evidence

- Все тесты 0 failures; `validate_project.py` passed; рендеры Blender и скриншоты Godot проверены.

## Blockers

- None.

## Next exact action

Owner review of the bird models and colours.

## Session handoff

- Completed: P3-026. Rebuild with `python tools/build_birds.py [--preview DIR]` (needs `pip install bpy`).

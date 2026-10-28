---
task_version: 1
task_id: P3-024
status: DONE
phase: 3
owner: AI
updated: 2026-10-28
---

# Active Task

P3-024 — риги, веса и анимации для моделей пещерных людей; страница просмотра анимаций.

## Goal

Две модели владельца (худой и толстый пещерный человек) с риггингом и анимациями, которые можно посмотреть в игре.

## Why this matters

Просьба владельца 2026-10-28 с двумя моделями .glb.

## In scope

- Скелет и веса кожи, облегчённые модели (как оружие).
- Анимации: ходьба, бег, подкрадывание, езда на кабане, удар оружием, сильный удар, выстрел из лука (+ стойка).
- Отдельный экран просмотра анимаций из стартового меню.

## Out of scope

- Использование персонажей в игре (игра от первого лица; NPC/кооп позже).

## Acceptance criteria

- [x] Given обе модели, Then у каждой скелет, веса и 8 анимаций, не более 5000 треугольников.
- [x] Given стартовый экран, When "Character animations", Then экран просмотра: выбор модели и анимации, вращение камеры, кабан под всадником.

## Decisions made during this task

- (ASSUMPTION) Рост: худой 1.8 м, толстый 1.65 м; 5000 треугольников, текстуры 1024 px.
- Пальцы: кости fingers, fingertips, thumb; руки всегда в кулаке вокруг оружия. Сильный удар = замах и удержание (заряд) с дрожью, затем удар (отзыв владельца).
- Анимации процедурные (ключевые позы в `tools/rig_cavemen.py`), без root motion; удары правой рукой, лук в левой.
- Веб-версия просмотрщика опубликована как Artifact (three.js) для просмотра без запуска игры.

## Progress

- Реализовано, тесты зелёные.

## Validation evidence

- `run_animation_viewer_smoke_test.gd` 0 failures; все domain и smoke тесты 0 failures; `validate_project.py` passed; editor import без ошибок.

## Blockers

- None.

## Next exact action

Owner review of the animations in the viewer.

## Session handoff

- Completed: P3-024. Source .glb files are not in the repo; to rebuild, pass them to `tools/rig_cavemen.py`.

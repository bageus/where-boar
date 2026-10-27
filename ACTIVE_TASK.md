---
task_version: 1
task_id: P3-016
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-016 — рельеф карты охоты (D039).

## Goal

Карта не плоская: холмы, уступы, обрывы, поляны; охотник поднимается выше и высматривает кабанов.

## Why this matters

Просьба владельца 2026-10-27: подняться повыше и рассмотреть, где кабаны.

## In scope

- `presentation.hunt_map`: сцены `plateau.tscn`, `ridge.tscn`, `ledges.tscn`, `clearing.tscn`; расстановка в Green Valley, холмы 1 и 3 крупнее, пропы убраны из-под рельефа, кусты на вершинах.
- `features.hunter`: `ground_at` — ловушки, приманка и ездовой кабан ложатся на склон; прыжок у стены — подъём на уступ, в воздухе им можно управлять.

## Out of scope

- Рельеф на миникарте, урон от падения, heightmap-ландшафт.

## Acceptance criteria

- [x] Given охотник на смотровом плато, When кабан под обрывом, Then луч взгляда кабана перекрыт (smoke-тест).
- [x] Given ловушка на пандусе, Then она лежит на склоне (smoke-тест).
- [x] Given охотник бежит в уступ 0,7 м и жмёт пробел, Then он на уступе; кабан в бегстве проходит через холм (проверено локально).

## Decisions made during this task

- [ASSUMPTION] Плато 14×14×6 м с пандусом 23°; обрыв над рекой 5 м, склон 23°; уступы 5×0,7 м; холмы ×1,4 и ×1,6; три поляны r 7–9 м.
- [ASSUMPTION] Прыжок с направлением у стены — обычный прыжок, не рывок; после обычного прыжка охотник рулит в воздухе.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Owner playtest of the relief.

## Session handoff

- Completed: P3-016.

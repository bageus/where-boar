---
task_version: 1
task_id: P3-022
status: DONE
phase: 3
owner: AI
updated: 2026-10-28
---

# Active Task

P3-022 — папоротники, новые деревья, упавшие деревья, единый стиль деревьев.

## Goal

Больше разных растений, и все деревья выглядят одним набором.

## Why this matters

Просьба владельца 2026-10-28 со своими моделями.

## In scope

- `tools/bake_nature_meshes.gd`: общая палитра коры, листвы и хвои для деревьев, брёвен, пней, пальм и папоротников; поверхности одного цвета сливаются.
- `terrain.gd`: 260 папоротников (видны в 35 м), 36 упавших деревьев и брёвен; Tree_1..3 среди деревьев.

## Out of scope

- Подсветка подбираемых предметов и падение сети (отдельная задача).

## Acceptance criteria

- [x] Given карта, Then есть папоротники, упавшие деревья и новые виды деревьев (превью).
- [x] Given все деревья, Then кора и листва одного цвета.

## Decisions made during this task

- Папоротники без коллизии, трава под ними не растёт.

## Progress

- Реализовано, проверено превью.

## Validation evidence

- Все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Owner playtest.

## Session handoff

- Completed: P3-022.

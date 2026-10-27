---
task_version: 1
task_id: P3-004
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-004 — лагерь от первого лица: меню → лагерь → «Начать охоту» → итоги → лагерь (A001, A003).

## Goal

Между охотами игрок ходит по лагерю от первого лица, видит бивни и пойманных кабанов и начинает охоту у станции.

## Why this matters

Лагерь — место, где бивни превращаются в улучшения; без него нет цикла MVP.

## In scope

- `presentation.camp` (новый): сцена лагеря, пропсы (.tscn: земля, забор, шатры, станция), станции по E, HUD прогресса.
- `bootstrap.app`: «Играть» → лагерь; станция «Start hunt» → охота; «Back to camp» после итогов.

## Out of scope

- Лавки (P3-005, P3-007, P3-009), загоны с ездовыми (P3-012).

## Acceptance criteria

- [x] Given игрок в лагере у станции «Start hunt», When E, Then загружается карта охоты (smoke-тест).
- [x] Given итоги, When «Back to camp», Then лагерь с бивнями (smoke-тест).

## Decisions made during this task

- [ASSUMPTION] Станция — универсальная сцена `station.tscn` с `station_id`; лавки будут станциями.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-005.

## Session handoff

- Completed: P3-004.

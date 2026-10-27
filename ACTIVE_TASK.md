---
task_version: 1
task_id: P3-003
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-003 — сохранение бивней и пойманных животных: JSON в user:// с save_version и резервной копией (раздел 18).

## Goal

Бивни и пойманные кабаны переживают перезапуск игры; сохранение не теряется и не портится.

## Why this matters

Без сохранения нет долгосрочного цикла «охота → бивни → улучшение».

## In scope

- `features.settlement` (новый): `public/progress.gd` — бивни, пойманные животные, `add_hunt`, `spend`, `to_dict/from_dict`.
- `infrastructure.save` (новый): `public/save_store.gd` — один слот `user://save.json`, `save_version: 1`, резервная копия `.bak`, запись через временный файл.
- `bootstrap.app`: загрузка при старте, сохранение после итогов; итоги показывают общий счёт бивней.

## Out of scope

- Сохранение покупок (появится вместе с лавками), настройки (P3-014), Steam Cloud.

## Acceptance criteria

- [x] Given итоги охоты, Then бивни и пойманные добавлены в прогресс и файл записан (тесты settlement, smoke).
- [x] Given испорченный файл, Then загружается резервная копия (тест `run_save_tests.gd`).
- [x] Given файл новее игры, Then загрузка отказана, файл не перезаписан (тест).
- [x] Given мусор в полях, Then значения по умолчанию, игра не падает (тест).

## Decisions made during this task

- [ASSUMPTION] Миграций пока нет: версия одна; более старая версия грузится как есть, поля по умолчанию.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-004.

## Session handoff

- Completed: P3-003.

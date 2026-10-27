---
task_version: 1
task_id: P3-014
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-014 — пауза, настройки (FOV, чувствительность мыши, движение камеры), подсказки первой охоты (раздел 16).

## Goal

Esc ставит игру на паузу в лагере и на охоте; в паузе меняются FOV, чувствительность и движение камеры (сохраняются отдельно от прогресса); первая охота и первый лагерь показывают подсказки.

## Why this matters

Без паузы и настроек FOV первое лицо плохо переносится; без подсказок новый игрок не пройдёт цикл.

## In scope

- `presentation.menus`: `pause_menu.tscn` (Continue, FOV 60–110, чувствительность, движение камеры, выход в меню).
- `bootstrap.app`: пауза через дерево сцен, настройки в `user://settings.json` (тот же версионный формат), применение к охотнику.
- `features.hunter`: `apply_settings`; подсказка управления перенесена влево наверх.
- `features.settlement`: счётчик охот `hunts` в сохранении.
- `presentation.hunt_map`: 6 подсказок по 8 с на первой охоте; `presentation.camp`: подсказка при первом входе.

## Out of scope

- Переназначение клавиш, масштаб текста (DEFERRED в разделе 16).

## Acceptance criteria

- [x] Given лагерь, When Esc, Then пауза; When FOV 95, Then камера 95 и файл настроек записан; When Continue, Then игра идёт (smoke-тест).
- [x] Given охот 0, Then подсказки; после охоты счётчик 1 (тест settlement).
- [x] HUD без наложений проверен снимком (xvfb).

## Decisions made during this task

- [ASSUMPTION] Выход в меню из паузы теряет текущую охоту (раздел 07: охота не сохраняется посреди).

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-015.

## Session handoff

- Completed: P3-014.

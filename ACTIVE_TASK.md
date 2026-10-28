---
task_version: 1
task_id: P3-019
status: DONE
phase: 3
owner: AI
updated: 2026-10-28
---

# Active Task

P3-019 — пак природы владельца на карте Green Valley.

## Goal

Обрывы — массивные серые скалы, камни и деревья разные, есть пни, брёвна, участки высокой травы, кусты похожи на кусты.

## Why this matters

Просьба владельца 2026-10-28 со своими моделями и скриншотом.

## In scope

- `tools/bake_nature_meshes.gd`: модели из `assets/nature/source` → `assets/nature/meshes/*.res` (начало координат внизу по центру, плоские цвета).
- `terrain.gd`: большие камни на крутых участках (один на 5×5 м), пни и брёвна с коллизией, 12 участков высокой травы с пшеницей.
- `props/varied_mesh.gd`: дерево/скала выбирает модель по имени узла; JungleTree — пальмы.
- Новый куст в `tools/build_models.py`; окружение без синего оттенка.

## Out of scope

- Коллизия у камней на обрывах (обрыв и так непроходим), ветер в траве.

## Acceptance criteria

- [x] Given обрыв, Then он покрыт крупными серыми скалами, а не мелкими камнями (превью).
- [x] Given карта, Then 30 пней и 24 бревна вне зон, спавнов и пропов (smoke-тест проходит).
- [x] Given деревья и камни, Then формы разные; в джунглях пальмы.

## Decisions made during this task

- [ASSUMPTION] Камни обрыва — только визуал; коллизия обрыва — карта высот.
- Пни и брёвна — формы коллизии на теле рельефа.

## Progress

- Реализовано, проверено превью и тестами.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Owner playtest: look and FPS.

## Session handoff

- Completed: P3-019.

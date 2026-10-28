---
task_version: 1
task_id: P3-018
status: IN_PROGRESS
phase: 3
owner: AI
updated: 2026-10-28
---

# Active Task

P3-018 — low-poly модели вместо серых заглушек (раздел 17).

## Goal

Кабаны, природа, руки с оружием и лагерь выглядят как мультяшный low poly, а не как капсулы и кубы.

## Why this matters

Просьба владельца 2026-10-28: сперва визуал (модели, окружение), потом экономика.

## In scope

- `tools/build_models.py` пишет `assets/models/*.glb` (кабан, дерево, куст, камень, камешек; дальше руки, оружие, лагерь).
- `features.boar/public/boar_model.tscn`: модель кабана, `paint(color)` красит шкуру по типу; используют кабан и ездовой кабан.
- Пропы карты (дерево, куст, скала, кучка камней) показывают модели; коллизии прежние.

## Out of scope

- Анимации скелетом, текстуры, трава, CC0-паки (сеть контейнера их не скачивает).

## Acceptance criteria

- [x] Given пять типов кабанов, Then у каждого своя окраска шкуры, клыки, пятачок, грива (превью-скриншот).
- [x] Given карта Green Valley, Then деревья, кусты, скалы — low-poly модели, коллизии и укрытия прежние (smoke-тест).
- [ ] Given руки и оружие, лагерь, Then они тоже из моделей.

## Decisions made during this task

- [ASSUMPTION] Модели генерируются скриптом (владелец ещё не выбрал источник; CC0-паки можно положить поверх с тем же именем).
- Один материал на цвет вместо вершинных цветов: импорт Godot не включает vertex colour для материалов glTF.

## Progress

- Кабаны, ездовой кабан и природа готовы.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Руки и оружие (копьё, сеть, дубина, праща, лук), затем лагерь.

## Session handoff

- Next: hands and weapons models.

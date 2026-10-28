---
task_version: 1
task_id: P3-017
status: DONE
phase: 3
owner: AI
updated: 2026-10-28
---

# Active Task

P3-017 — сплошной плавный рельеф вместо примитивов (D039).

## Goal

Возвышенности, обрывы и впадины Green Valley — одна плавная поверхность, а не фигуры на плоскости.

## Why this matters

Просьба владельца 2026-10-28.

## In scope

- `tools/bake_green_valley.py`: функция высот, запись `props/terrain_heights.tres`, установка пропов, реки, зон, спавнов, охотника и лагеря на поверхность.
- `presentation.hunt_map`: `props/terrain.tscn` + `terrain.gd` (коллизия HeightMapShape3D, меш из тех же данных, цвет по крутизне, `height_at`); удалены hill/plateau/ridge/ledges/clearing; стены глубже русла.
- Спавн кабанов, ловушки установщика и цель петуха — на высоте земли; smoke-тест ставит охотника и кабанов на землю.

## Out of scope

- Текстуры, рельеф на миникарте, урон от падения.

## Acceptance criteria

- [x] Given охотник на столовой горе, Then кабан под обрывом его не видит (smoke-тест).
- [x] Given ловушка на склоне, Then она лежит на земле (smoke-тест).
- [x] Given все кабаны бегут 15 с, Then ни один не провалился под землю и не ушёл за стену (проверено локально).

## Decisions made during this task

- [ASSUMPTION] Шаг сетки 1 м, 161×161; высоты и размеры холмов, впадин, горы и гребня — в `tools/bake_green_valley.py`.
- Меш рисуется из данных высот при загрузке сцены (@tool, виден в редакторе); сами данные — ресурс сцены (D017).

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Owner playtest of the smooth relief.

## Session handoff

- Completed: P3-017.

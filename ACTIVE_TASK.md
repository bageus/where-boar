---
task_version: 1
task_id: P3-013
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-013 — карта Green Valley: холмы, река, джунгли, кусты, узкий проход, 7 зон побега (раздел 11).

## Goal

Охота идёт на карте 160×160 м с местами для загона: река с двумя бродами, узкий проход между камнями, джунгли, холмы и кусты.

## Why this matters

Первая карта MVP; загон работает только при рельефе, который направляет кабанов.

## In scope

- `presentation.hunt_map`: новые пропсы-сцены `hill.tscn`, `river_segment.tscn`, `bush.tscn`; земля и стены 160 м; `hunt_map.tscn` пересобран; 12 точек спавна, 7 зон побега; группы `[15, 12, 4, 4, 3, 3, 3, 1, 1, 1]` (47 кабанов); миникарта на 160 м.

## Out of scope

- Финальные ассеты, навигационная сетка (кабаны по-прежнему рулят без NavigationServer3D).

## Acceptance criteria

- [x] Все объекты карты — экземпляры .tscn (D017).
- [x] 2 стада (15 и 12), 6 групп по 3–4, одиночки; 7 зон побега (5–10 по разделу 11) (smoke-тест: 47 кабанов).
- [x] Снимок сверху и от лица охотника проверен вручную (xvfb).

## Decisions made during this task

- [ASSUMPTION] Река непроходима, кроме двух бродов; кусты не мешают движению; раскладка выбрана AI.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-014.

## Session handoff

- Completed: P3-013.

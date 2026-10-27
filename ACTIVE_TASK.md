---
task_version: 1
task_id: P2-005
status: DONE
phase: 2
owner: AI
updated: 2026-10-27
---

# Active Task

P2-005 — цикл охоты: стартовый экран, цель в HUD, возврат в лагерь, экран итогов (M007). Вместе с ним: шкала здоровья над кабаном (зелёная → красная, раздел 16) и зоны побега на миникарте (D011).

## Goal

Игрок проходит полный цикл: «Начать охоту» → погоня → возврат в лагерь или конец кабанов → итоги с бивнями → новая охота.

## Why this matters

Это критерий выхода фазы 2: новый пользователь проходит цикл охоты без помощи разработчика.

## In scope

- `features.hunt`: `public/hunt.gd` — счёт исходов, `remaining()`, `is_over()`, таблица наград из раздела 15.
- `features.boar`: сигнал `outcome_reached`, шкала здоровья над кабаном.
- `features.hunter`: сигнал `interacted` (E).
- `presentation.hunt_map`: точка возврата (`props/return_point.tscn`), HUD цели, миникарта (`hud/minimap.tscn`), сигнал `hunt_ended`.
- `presentation.menus` (новый): стартовый экран и экран итогов.
- `bootstrap.app`: переходы старт → карта → итоги → старт.

## Out of scope

- Поселение и лавки (фаза 3), здоровье охотника, типы кабанов (все — `common_brown`).

## Acceptance criteria

- [x] Given убиты и пойманы кабаны разных типов, When охота заканчивается, Then итоги по типам и бивни по таблице (тест `run_hunt_tests.gd`).
- [x] Given ни один кабан не добыт, Then пустые итоги без экрана поражения (тест).
- [x] Given все кабаны разрешены, Then охота заканчивается (тест).
- [x] Given охотник в зоне лагеря нажал E, Then экран итогов (smoke-тест).
- [x] Шкала здоровья уменьшается после попадания (smoke-тест).
- [x] Зоны побега и лагерь на миникарте; кабаны на ней не показаны (их отмечает индюк, M017).

## Progress

- Реализовано и проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit` (4.7.2): без ошибок.
- Тесты boar, senses, hunt, hunter: 0 failures; smoke-тест карты: 0 failures в 3 прогонах.
- `python tools/validate_project.py`: passed.

## Decisions made during this task

- [ASSUMPTION] Конец охоты по нулю здоровья охотника отложен: у охотника пока нет здоровья.
- [ASSUMPTION] Шкала здоровья сжимается к центру (billboard-квады), цвет от красного к зелёному.
- [ASSUMPTION] «Охотиться снова» возвращает на стартовый экран; поселение появится в фазе 3.

## Blockers

- None.

## Next exact action

Plan phase 3 tasks in BACKLOG.md.

## Session handoff

- Completed: P2-005.
- Next action: plan phase 3.

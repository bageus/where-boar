---
task_version: 1
task_id: P3-012
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-012 — ездовые кабаны из пойманных (D021).

## Goal

В загоне за 50 бивней седлается пойманный кабан одного из трёх видов; на охоте он ждёт рядом, E — сесть/слезть. Верхом скорость вида, выносливость не тратится, со спины только удар копьём. Быстрый — скорость 10 м/с, злой — таранит кабанов, броненосец — всадника не сбивают.

## Why this matters

Ездовые кабаны, загоны и седло входят в MVP (D021) и дают смысл живой поимке.

## In scope

- `features.hunter`: `domain/ride.gd`, сёдла в `Loadout.saddled`, `presentation/rider.gd` (привести, сесть/слезть, таран), `presentation/mount.tscn`.
- `features.settlement`: сёдла в лавке «pens», `Progress.unlocked` — седло только при пойманном кабане этого вида.
- `presentation.camp`: станция «Pens»; окно лавки показывает «catch one first».

## Out of scope

- Видимая модель всадника, анимации, выбор из нескольких оседланных (берётся первый).

## Acceptance criteria

- [x] Given вид кабана, Then скорость и способность по виду; верхом работает только удар копьём (тест hunter).
- [x] Given нет пойманного быстрого, Then седло не продаётся; есть — продаётся за 50 (тест settlement).
- [x] Given оседланный быстрый, When охота началась и E рядом, Then охотник верхом, 10 м/с (smoke-тест).

## Decisions made during this task

- [ASSUMPTION] Сделан рекомендованный вариант «верхом под седлом»; вопрос о езде задан владельцу, ответ ещё не получен.
- [ASSUMPTION] Три вида для езды — быстрый, злой, броненосец; на охоту берётся первый оседланный; таран злого: импульс 12, урон 1, раз в секунду (D013).

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Phase 3 backlog done; wait for the owner's answer on riding (P3-012) and a playtest of the vertical slice.

## Session handoff

- Completed: P3-012.

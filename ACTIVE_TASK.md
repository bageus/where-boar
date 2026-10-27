---
task_version: 1
task_id: P3-001
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-001 — здоровье охотника, нападение и таран кабана (CHARGE), конец охоты при нуле здоровья (M002, M005, D018).

## Goal

Атака пугает кабана, затем он может развернуться и протаранить охотника; таран в CHARGE отнимает здоровье; при нуле охотник возвращается в лагерь с добычей.

## Why this matters

Опасность кабана — половина погони; без урона таран не имеет последствий.

## In scope

- `features.boar`: `Boar.charge()` / `end_charge()`; агент: после 2,5 с паники бросок шанса `aggression`, CHARGE на охотника до 4 с или до тарана.
- `features.hunter`: `domain/health.gd`, полоса здоровья в HUD, сигнал `downed`.
- `presentation.hunt_map`: `downed` заканчивает охоту.
- CI: тесты находятся по маске, у каждого запуска таймаут.

## Out of scope

- Числа по типам кабанов (P3-002), кувырок камеры (P3-015).

## Acceptance criteria

- [x] Given кабан в PANIC, When он решает атаковать, Then CHARGE; спокойный кабан не атакует; кабан в CHARGE не сбегает (тест `run_boar_tests.gd`).
- [x] Given урон охотнику, Then здоровье падает и останавливается на нуле (тест `run_hunter_tests.gd`).
- [x] Given CHARGE-кабан таранит охотника, Then отбрасывание, урон `damage × 20`, управление через 1 с.
- [x] Given здоровье 0, Then охота заканчивается экраном итогов без поражения.

## Progress

- Реализовано, тесты проходят локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Decisions made during this task

- [ASSUMPTION] Урон: 1 единица урона кабана = 20 здоровья охотника; шанс атаки 0,35; паника до броска 2,5 с; CHARGE до 4 с, 9 м/с (D013).
- [ASSUMPTION] Быстрый таран без CHARGE отбрасывает без урона.

## Blockers

- None.

## Next exact action

Start P3-002 (boar types).

## Session handoff

- Completed: P3-001.

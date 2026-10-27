---
task_version: 1
task_id: P3-009
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-009 — еда у костра и мешок с водой (M012).

## Goal

Блюдо с костра поднимает максимум выносливости на следующую охоту; мешок с водой (Q) быстро возвращает выносливость прямо на бегу и бесплатно наполняется в лагере.

## Why this matters

Это единственные бафы MVP (D012) и вторая статья трат бивней.

## In scope

- `features.hunter`: `Stamina.max_value`, `eat`, `drink`; `Loadout.eat_best_meal`, глотки воды; `Hunter.start_hunt`; клавиша Q.
- `features.settlement`: блюда (похлёбка +20 за 10, жаркое +35 за 18, пир +50 за 25) на станции «Campfire», мешок с водой 25 в хижине.
- `presentation.camp`: станция костра; `presentation.hunt_map`: охотник ест перед охотой.

## Out of scope

- Покачивание камеры и дыхание при усталости (P3-015).

## Acceptance criteria

- [x] Given пир и похлёбки на складе, When охота началась, Then съеден пир, максимум 150, выносливость полная; блюдо списывается (тест hunter).
- [x] Given мешок с водой, Then 3 глотка по 40 за охоту, потом пусто (тест hunter).

## Decisions made during this task

- [ASSUMPTION] Перед охотой автоматически съедается лучшее блюдо со склада; клавиша Q; 3 глотка по 40; цены в диапазоне 10–25 и 15–40 (D013).

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-010.

## Session handoff

- Completed: P3-009.

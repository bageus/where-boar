---
task_version: 1
task_id: P3-005
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-005 — оружейная и оружие: дубина, праща, лук (M013, D022).

## Goal

В лагере за бивни покупаются дубина, праща и лук; купленное оружие появляется в хотбаре на охоте и в лагере.

## Why this matters

Первое улучшение за бивни замыкает цикл «охота → бивни → улучшение».

## In scope

- `features.settlement`: `public/shop_catalog.gd` (товары, лавка, цена, уникальность), `Progress.buy/owns`, предметы в сохранении.
- `features.hunter`: `Loadout.Weapon` (5 видов), `equip(items)`, стрелы; дубина (ближний, урон 2, отталкивает), праща (камни без счёта, урон 1), лук (12 стрел, урон 2); снаряды `stone.tscn`, `arrow.tscn`; хотбар 1–5.
- `presentation.camp`: станция «Armory», окно лавки `hud/shop_panel.tscn`.
- `bootstrap.app`: сохранение после покупки; снаряжение передаётся на карту.
- `project.godot`: `weapon_3..weapon_5`.

## Out of scope

- Ловушки, приманки, еда (P3-006, P3-007, P3-009).

## Acceptance criteria

- [x] Given 60 бивней, When куплена праща, Then 35 бивней, повторная покупка и покупка дороже баланса отклонены (тест settlement).
- [x] Given купленный лук, Then он доступен, стрелы кончаются (тест hunter).
- [x] Given 100 бивней в лагере, When в оружейной куплена дубина, Then 70 бивней, дубина в хотбаре, покупка сохранена (smoke-тест).

## Decisions made during this task

- [ASSUMPTION] Сеть и копьё бесплатны и всегда с собой (раздел 13, «защита от тупиков»); цена сети 20 из таблицы лавок не используется, пока не решено, что именно продаётся.
- [ASSUMPTION] Цены: дубина 30, праща 25, лук 50; 12 стрел на охоту, стрелы не подбираются; камни пращи бесконечны; клавиши 1–5.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-006.

## Session handoff

- Completed: P3-005.

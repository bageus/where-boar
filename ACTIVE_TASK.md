---
task_version: 1
task_id: P3-006
status: DONE
phase: 3
owner: AI
updated: 2026-10-27
---

# Active Task

P3-006 — крик и приманки (M014, M011).

## Goal

Крик (R) отпугивает кабанов вбок под углом ±30°, приманка (F) тянет спокойных кабанов к себе; приманки покупаются в охотничьей хижине.

## Why this matters

Это инструменты загона: игрок управляет, куда бегут кабаны, а не только догоняет.

## In scope

- `features.boar`: `BoarSenses.bait_target`, `BoarBody.hear_shout`, руление к приманке в WANDER.
- `features.hunter`: сигналы `shouted`, `bait_placed`; `bait.tscn`; приманки и потраченные предметы в `Loadout`; HUD приманок.
- `features.hunt` / `features.settlement`: `Hunt.used_items`; потраченные приманки списываются со склада.
- `presentation.hunt_map`: крик слышен в 15 м; общий список приманок для кабанов.
- `presentation.camp`: станция «Hunting hut» (желуди 5, морковка 8, яблоко 8).
- `project.godot`: `shout` (R), `bait` (F).

## Out of scope

- Ловушки (P3-007), стада (P3-008).

## Acceptance criteria

- [x] Given приманки в радиусе, Then кабан идёт к ближайшей (тест senses).
- [x] Given яблоко и желуди, Then F кладёт сначала яблоко; потраченное учитывается (тест hunter) и списывается после охоты (тест settlement).
- [x] Given бегущий кабан в 15 м, When крик, Then его курс подменён на отклонённый (smoke-тест).

## Decisions made during this task

- [ASSUMPTION] Крик раз в 2 с, слышен в 15 м, держит курс 2 с; паникующий и атакующий кабан крик игнорирует.
- [ASSUMPTION] Приманки: желуди 12 м / 20 с, морковка 18 м / 25 с, яблоко 18 м / 35 с; F кладёт самую сильную из имеющихся.

## Progress

- Реализовано, проверено локально.

## Validation evidence

- `godot --headless --path . --editor --quit`: без ошибок; все тесты 0 failures; `validate_project.py` passed.

## Blockers

- None.

## Next exact action

Start P3-007.

## Session handoff

- Completed: P3-006.

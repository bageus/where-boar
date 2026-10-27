---
task_version: 1
task_id: P2-003
status: DONE
phase: 2
owner: AI
updated: 2026-10-27
---

# Active Task

P2-001..P2-003 — первый играбельный прототип охоты: охотник от первого лица, серая карта, кабаны, копьё и сеть. Выполнены одним заходом по поручению координатора; последняя задача — P2-003.

## Goal

Игрок ходит по серой карте от первого лица, кабаны пугаются и убегают к зонам побега, копьё ранит и убивает, сеть ловит; все решения принимают доменные правила P1-001/P1-002.

## Why this matters

Это первый видимый цикл погони (M001–M004) и проверка, что доменные правила работают в сцене.

## In scope

- `features.hunter` (новый): выносливость и снаряжение в домене; сцена охотника с камерой, HUD (выносливость, оружие), удар, бросок копья, бросок сети, подбор.
- `features.boar`: сцена агента кабана `public/boar_body.tscn`, руление по состояниям WANDER/FLEE/PANIC, `BoarSenses.flee_heading`.
- `presentation.hunt_map` (новый): серая карта, все объекты — сцены (.tscn, D017): земля, стены, деревья, камни, зоны побега, точки спавна.
- `bootstrap.app`: главная сцена запускает карту; Input Map в `project.godot`.

## Out of scope

- Отбрасывание при столкновении (P2-004), цикл охоты и итоги (P2-005), миникарта, шкала здоровья над кабаном (показан текст состояния), CHARGE.

## Acceptance criteria

- [x] Given полная выносливость, When зажат sprint, Then скорость растёт, выносливость убывает (тест `run_hunter_tests.gd`).
- [x] Given ходьба, Then выносливость растёт; при нуле спринт заблокирован до 20 (тест).
- [x] Given кабан WANDER, When охотник в радиусе восприятия, Then FLEE (smoke-тест сцены).
- [x] Given сеть брошена в кабана, Then CAPTURED (smoke-тест).
- [x] Given копьё брошено в кабана, Then урон и PANIC, копьё остаётся на месте попадания и подбирается по E (smoke-тест на попадание).
- [x] Все объекты карты — .tscn (D017).

## Progress

- Все три задачи реализованы и проверены; см. Validation evidence.

## Validation evidence

- `godot --headless --path . --editor --quit` (4.7.2): без ошибок.
- Тесты boar, senses, hunt, hunter: 0 failures; `run_hunt_map_smoke_test.gd`: 0 failures в 12 прогонах подряд.
- `python tools/validate_project.py`: passed.

## Decisions made during this task

- [ASSUMPTION] Числа: ходьба 4, спринт 7, красться 2 м/с; кабан бродит 1.5, бежит 8, паникует 10 м/с; радиус восприятия 12 м; здоровье кабана 3, удар 1, бросок 2; сетей 3; 4 кабана на карте.
- Space с направлением — наскок, без направления или без выносливости — прыжок (как в карте управления).
- Удар копьём — ЛКМ; бросок — ПКМ (прицел) + ЛКМ.

## Blockers

- None.

## Next exact action

Plan P2-004 (collision knockback, M005) in BACKLOG.md and ACTIVE_TASK.md.

## Session handoff

- Completed: P2-001, P2-002, P2-003.
- Files changed: `game/features/hunter/`, `game/features/boar/public/boar_body.*`, `game/features/boar/domain/boar_senses.gd`, `game/presentation/hunt_map/`, `game/bootstrap/app/`, `project.godot`, CI workflow, docs.
- Next action: plan P2-004 (collision knockback).

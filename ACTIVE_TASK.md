---
task_version: 1
task_id: P3-025
status: DONE
phase: 3
owner: AI
updated: 2026-10-28
---

# Active Task

P3-025 — риги, веса и анимации для моделей кабанов владельца; редкие кабаны; кабаны в просмотрщике анимаций.

## Goal

13 моделей кабанов владельца с риггингом и анимациями в игре: пять типов и восемь редких вариантов.

## Why this matters

Просьба владельца 2026-10-28 с 13 моделями .glb.

## In scope

- Облегчённые модели (сравнение рендеров до/после), скелет, веса.
- Анимации: стойка, ходьба, бег, еда с земли, атака, смерть.
- Модели для пяти типов и восемь редких типов; кабаны в просмотрщике анимаций и на веб-странице.

## Out of scope

- Особые умения редких кабанов (камуфляж, длинное тело и т. п.) сверх чисел в .tres.

## Acceptance criteria

- [x] Given 13 моделей, Then у каждой скелет, веса и 5 анимаций, не более 3000 треугольников (костяной 4000).
- [x] Given охота, Then каждый тип кабана показывает свою модель; ходьба/бег по скорости, атака при рывке, смерть при убийстве.
- [x] Given просмотрщик анимаций, Then можно выбрать любого кабана и анимацию.

## Decisions made during this task

- Владелец: копилка (golden_piggy_bank) — золотой кабан, тотем (tusker_totem) — боевой (Angry boar).
- (ASSUMPTION) Остальные: Forest = boar_buddy, Runner = neon_boar, Armored = blocky_boar; редкие: Bone, Bun (cinnamon_tuskboar), Bubble, Mohawk (spiky_boar_monster), Long (boaripede), Camouflage, Hairy (cozy_boar_cloak), Tiny tusker; веса появления 1.5–2, числа в .tres — ASSUMPTION.
- Анимации процедурные (`tools/rig_boars.py`), без root motion; скорость ходьбы/бега подгоняется под скорость кабана.
- Цвет типа больше не красит модель (у моделей свои текстуры); поле осталось в .tres (сейчас не используется).

## Progress

- Реализовано, тесты зелёные.

## Validation evidence

- Все domain и smoke тесты 0 failures; `validate_project.py` passed; скриншоты просмотрщика в Godot проверены.

## Blockers

- None.

## Next exact action

Owner review of the boar animations and rare-boar numbers.

## Session handoff

- Completed: P3-025. Source .glb files are not in the repo; to rebuild, pass them to `tools/rig_boars.py`.

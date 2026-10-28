---
backlog_version: 1
status: ACTIVE
current_milestone: P3_VERTICAL_SLICE
updated: 2026-10-27
---

# Backlog

The backlog contains approved work that is not currently active. Only one item may be copied into `ACTIVE_TASK.md` at a time.

## Rules

- Every task has a stable ID.
- A task describes one verifiable outcome.
- Dependencies must be completed first.
- New work enters here before becoming active.
- A task may not silently expand while active.
- Unapproved ideas go to Icebox, not the active task.

## Ready queue

| ID | Phase | Outcome | Dependencies | Status |
|---|---:|---|---|---|
| P1-001 | 1 | Boar and hunt domain model with headless tests in CI | DISC-001 | DONE |
| P1-002 | 1 | Boar perception, panic and escape-zone choice in domain with tests | P1-001 | DONE |

## Planned

| ID | Phase | Outcome | Dependencies | Status |
|---|---:|---|---|---|
| P2-001 | 2 | First-person hunter movement and stamina on a grey test map (M001) | P1-002 | DONE |
| P2-002 | 2 | Boar agent in scene with flee/panic steering (M002) | P2-001 | DONE |
| P2-003 | 2 | Spear and net (M003, M004) | P2-002 | DONE |
| P2-004 | 2 | Collision knockback (M005) | P2-002 | DONE |
| P2-005 | 2 | Hunt flow: start button, goal, return, results (M007) | P2-003 | DONE |
| P3-001 | 3 | Hunter health, boar attack and CHARGE ram, hunt ends at zero health (M002, M005) | P2-005 | DONE |
| P3-002 | 3 | Five boar types as .tres data, spawn by rarity, rewards by type | P3-001 | DONE |
| P3-003 | 3 | Save tusks and caught animals (versioned JSON in user://, backup) | P2-005 | DONE |
| P3-004 | 3 | First-person camp hub: menu, camp, start hunt, results back to camp | P3-003 | DONE |
| P3-005 | 3 | Weapon shop; club, sling, bow (M013, D022) | P3-004 | DONE |
| P3-006 | 3 | Shout and bait (M014, M011) | P3-004 | DONE |
| P3-007 | 3 | Traps: pit, snare, tripwire, cage, fence; hunting hut (M015) | P3-005 | DONE |
| P3-008 | 3 | Herds and groups, fear spreads to neighbours (M009) | P3-002 | DONE |
| P3-009 | 3 | Campfire food and water bag (M012) | P3-004 | DONE |
| P3-010 | 3 | Rooster driver and turkey scout (M016, M017) | P3-008 | DONE |
| P3-011 | 3 | Helpers: porter and trap setter (M013) | P3-007 | DONE |
| P3-012 | 3 | Mounts from caught boars (D021) | P3-004 | DONE |
| P3-013 | 3 | Green Valley map: hills, river, bushes, 5–10 escape zones | P3-008 | DONE |
| P3-014 | 3 | Pause, settings (FOV, camera shake), first-hunt hints | P3-004 | DONE |
| P3-015 | 3 | Sound and visual feedback: stomps, squeals, knockback camera roll | P3-001 | DONE |
| P3-016 | 3 | Hunt map relief: hills, ledges, cliffs, clearings; climb up to spot boars (D039) | P3-013 | DONE |
| P3-017 | 3 | Smooth height-map terrain instead of primitives (D039) | P3-016 | DONE |
| P3-018 | 3 | Low-poly models instead of placeholders: boars, nature, hands and weapons, camp (section 17) | P3-017 | DONE |
| P3-019 | 3 | Owner's nature pack: rocky cliffs, varied rocks and trees, palms in the jungle, stumps, logs, tall grass, leafy bushes | P3-018 | DONE |
| P3-021 | 3 | Playtest fixes: solid rocky cliffs, no grass through stumps, cover in tall grass, winding river with flow, sand and log bridge, more trees | P3-019 | DONE |
| P3-022 | 3 | Ferns, more tree kinds and fallen trees; one bark and leaf palette for all trees | P3-021 | DONE |
| P3-020 | 3 | Max throw range per ranged weapon: net < spear < sling < bow | P3-019 | DONE |
| P3-023 | 3 | Hunt HUD redesign: bait/trap ring menus, water under stamina, tusks under minimap, +N popups, stats in Esc; trap ghosts built with E or by the trap setter | P3-022 | DONE |
| P3-024 | 3 | Owner's caveman models rigged and animated (walk, run, sneak, ride, attack, strong attack, bow shot); animation viewer from the start screen | P3-018 | DONE |
| P3-025 | 3 | Owner's 13 boar models rigged and animated (idle, walk, run, attack, death) for the five types and eight rare variants; boars in the animation viewer | P3-024 | DONE |

## Icebox

Unapproved ideas and possible future features belong here.

| ID | Idea | Why deferred | Reconsider when |
|---|---|---|---|
| ICE-001 | Coop for 2–4 players with DOWNED | Not in MVP (D005) | After MVP |
| ICE-002 | Spike and log traps, boar types Charger..Giant, biomes, settlement buildings | Post-MVP scope (section 21) | After MVP |
| ICE-003 | Обучение через опыт без текста: сцены на карте (кабаны у приманки, кабан в ловушке), пробник на старте (2 приманки, 1 силок), в итогах бивни за живого и убитого; убрать советы первой охоты | Владелец одобрил идею, но отложил (2026-10-27) | Когда владелец скажет |

## Completed

| ID | Outcome | Evidence |
|---|---|---|
| SETUP-001 | Repository architecture and AI workflow created | Git history and CI |
| DISC-001 | Game discovery completed and approved | GAME_SPEC.md READY, decision D009 |
| P2-001..P2-003 | First-person hunt prototype: hunter, grey-box map, boars, spear, net | Hunter and smoke tests in CI |
| P2-004..P2-005 | Knockback, hunt flow with results, health bar, minimap | Hunt and smoke tests in CI |

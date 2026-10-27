---
backlog_version: 1
status: ACTIVE
current_milestone: P2_PROTOTYPE
updated: 2026-10-26
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
| P2-004 | 2 | Collision knockback (M005) | P2-002 | PLANNED |
| P2-005 | 2 | Hunt flow: start button, goal, return, results (M007) | P2-003 | PLANNED |

## Icebox

Unapproved ideas and possible future features belong here.

| ID | Idea | Why deferred | Reconsider when |
|---|---|---|---|
| ICE-001 | Coop for 2–4 players with DOWNED | Not in MVP (D005) | After MVP |
| ICE-002 | Traps, extra weapons, mounts, roosters, turkeys, buffs, biomes | Post-MVP scope | After MVP |

## Completed

| ID | Outcome | Evidence |
|---|---|---|
| SETUP-001 | Repository architecture and AI workflow created | Git history and CI |
| DISC-001 | Game discovery completed and approved | GAME_SPEC.md READY, decision D009 |
| P2-001..P2-003 | First-person hunt prototype: hunter, grey-box map, boars, spear, net | Hunter and smoke tests in CI |

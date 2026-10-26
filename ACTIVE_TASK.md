---
task_version: 1
task_id: P1-001
status: READY
phase: 1
owner: AI
updated: 2026-10-26
---

# Active Task

P1-001 — Boar and hunt domain model with headless tests.

## Goal

Boar states and hunt goal rules exist as engine-light GDScript classes and are proven by headless tests that run in CI.

## Why this matters

Phase 1 must prove the core rules (capture vs kill, escape, win/lose) before any scene work. Keeping rules out of scenes also prepares the host-authoritative coop planned after MVP.

## In scope

- `features.boar`: boar runtime state (WANDER, FLEE, PANIC, CHARGE, TRAPPED, CAPTURED, DEAD, ESCAPED), type data, health, transitions for hit, net capture, trap capture, death and escape (M002, M004, M006).
- `features.hunt`: hunt results counter per type and outcome, tusk reward per result (M007). No defeat state.
- Headless test runner script and a CI job that installs Godot 4.7.2 and runs the tests.

## Out of scope

- Scenes, nodes, input, camera, assets, UI.
- Perception radius, steering and escape-zone choice (P1-002).
- Coop, saving, settlement upgrades.

## Dependencies

- DISC-001 (done).

## Affected modules

- `features.boar` (new)
- `features.hunt` (new, depends on public API of `features.boar`)

## Expected files

- `game/features/boar/module.json`, `domain/`, `public/`, `tests/`
- `game/features/hunt/module.json`, `domain/`, `tests/`
- `.github/workflows/` — Godot headless test job

## Acceptance criteria

- [ ] Given a FLEE boar, When it is hit without dying, Then it becomes PANIC.
- [ ] Given a FLEE boar, When a net hits it, Then it becomes CAPTURED and the hunt goal counter increases.
- [ ] Given CAPTURED or DEAD boars, When escape is requested, Then nothing changes.
- [ ] Given boars of several types are killed and captured, When the hunt ends, Then results list counts per type and tusks follow the reward table (captured worth more than killed).
- [ ] Given a boar has health 0, When it dies, Then it counts as DEAD and fades out after a delay.
- [ ] Given a boar in a trap that is not broken by hunt end, When the hunt ends, Then it counts as captured.
- [ ] Given no boar was caught or killed, When the hunt ends, Then results show an empty hunt with no defeat state.
- [ ] Given a FLEE boar enters an escape point, When it is inside for about 3 seconds, Then it is ESCAPED; a calm boar passing the point is not.
- [ ] Tests pass in CI; `python tools/validate_project.py` passes.

## Plan

1. Create module manifests.
2. Implement boar state and transitions.
3. Implement hunt goal and outcome.
4. Write headless tests and the CI job.
5. Run validators and report.

## Progress

- Not started.

## Decisions made during this task

- None.

## Validation evidence

- Not run.

## Blockers

- None. Note: Godot is not installed in the AI environment, so tests are verified in CI.

## Next exact action

Create `game/features/boar/module.json`.

## Session handoff

- Completed: task planned after spec approval.
- Stopped at: before implementation.
- Files changed: GAME_SPEC.md, PROJECT_STATE.md, BACKLOG.md, ACTIVE_TASK.md.
- Checks: see commit.
- Unresolved blocker: none.
- Next action: create `game/features/boar/module.json`.

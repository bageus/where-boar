---
state_version: 1
status: IMPLEMENTATION
current_phase: 3
current_milestone: P3_VERTICAL_SLICE
active_task_id: P3-015
last_completed_task_id: P3-015
build_status: PASS
updated: 2026-10-27
---

# Project State

This is the compact current truth about project progress. Update it after every material work session.

## Current outcome

Первый играбельный прототип: охотник от первого лица на серой карте, кабаны убегают и паникуют по доменным правилам, копьё и сеть работают.

## Current phase

Phase 3 — Vertical slice (owner's instruction 2026-10-27; phase 2 cycle not yet playtested by a new player).

## Current milestone

P3_VERTICAL_SLICE — объём MVP в сером виде (GAME_SPEC раздел 25, P3-001..P3-015).

## Active task

P3-015 done; next P3-012.

## Last completed work

- DISC-001: GAME_SPEC.md approved (READY).
- P1-001, P1-002: boar and hunt domain, perception and escape rules.
- P2-001..P2-003: `features.hunter`, boar agent scene, `presentation.hunt_map`, main scene runs the map.
- P2-004: boar ram knockback + hunter stun; playtest fixes (hotbar HUD, central stamina bar, wall sliding).
- P2-005: start screen, goal HUD, return to camp, results with tusks; boar health bar; minimap with escape zones.
- P3-001: hunter health, boar CHARGE ram with damage, hunt ends at zero health.
- P3-002: five boar types as .tres (colour, speed, senses, aggression, armour, rewards), rarity-weighted spawn, 6 boars per hunt.
- P3-003: versioned JSON save of tusks and caught animals with backup (features.settlement, infrastructure.save).
- P3-004: first-person camp hub with stations; menu → camp → hunt → results → camp.
- P3-005: armory shop in camp; club, sling and bow bought with tusks and saved.
- P3-006: shout scares boars sideways; bait bought in the hunting hut pulls calm boars.
- P3-007: traps (pit, snare, tripwire, cage, fence) bought in the hunting hut and placed with G/T; trapped boars count as caught.
- P3-008: herds and groups; fear spreads to herd mates; strays rejoin the herd.
- P3-009: campfire meals raise max stamina for the next hunt; water bag sips restore stamina.
- P3-010: wild roosters and turkeys caught for the pen; rooster drives a group at the hunter, turkey marks boars on the minimap.
- P3-011: tavern helpers: porter carries extra nets and arrows, trap setter sets traps at escape zones.
- P3-013: Green Valley grey-box map 160×160: river with fords, jungle, hills, narrow pass, 7 escape zones, 47 boars.
- P3-014: pause menu with FOV, mouse sensitivity and camera-motion settings saved apart from progress; first-hunt tips.
- P3-015: synthesized squeal, stomps and thud; knockback camera roll; outcome messages in the HUD.

## Build and validation

| Check | Last result | Date | Notes |
|---|---|---|---|
| Game specification structure | PASS | 2026-10-27 | `python tools/validate_game_spec.py --ready` |
| Workflow state | PASS | 2026-10-27 | `python tools/validate_workflow_state.py --ready` |
| Architecture | PASS | 2026-10-27 | `python tools/validate_project.py` |
| Godot headless import | PASS | 2026-10-27 | Godot 4.7.2 (session hook installs it) |
| Tests | PASS | 2026-10-27 | boar, senses, hunt, hunter, hunt map smoke test |

## Known blockers

- None.

## Current risks

- Fast boars may be hard to read in first person.
- One-week prototype deadline for a solo developer.
- All speeds and damage are AI assumptions (D013); not yet playtested by a human.

## Next action

Start P3-012.

## Handoff notes

Run the game from `game/bootstrap/app/main.tscn`: start screen → hunt → results. Controls are listed on the HUD.

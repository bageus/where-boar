---
state_version: 1
status: IMPLEMENTATION
current_phase: 3
current_milestone: P3_VERTICAL_SLICE
active_task_id: P3-019
last_completed_task_id: P3-019
build_status: PASS
updated: 2026-10-28
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

None. P3-001..P3-019 done.

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
- P3-012: saddled mounts from caught boars: ride with E; runner is fast, angry boar rams, armored boar is steady.
- P3-016: map relief: 6 m lookout plateau with ramp, 5 m cliff over the river, 0.7 m ledges up to 3.5 m, bigger hills, clearings; jumping at a ledge climbs it; traps, bait and the mount sit on slopes; boars never notice a hunter 3 m or more above them.
- P3-017: the relief is one smooth height map (HeightMapShape3D + mesh drawn from it, rock colour on cliffs) baked by `tools/bake_green_valley.py`, which also puts props, spawns and zones on the ground.
- Perf fix 2026-10-28: Godot Physics was slow on the height map (physics ~31 ms/frame headless); switched to Jolt Physics (~9 ms, flat map was ~8 ms). FPS counter in the bottom-right corner.
- P3-018: cartoon low-poly models built by `tools/build_models.py` into `assets/models/*.glb`; boars (hide tinted per type), mount, trees, bushes, rocks, stones, first-person fist with spear, net, club, sling, bow, knife; thrown spear, arrow, stone; camp tents, palisade, stalls, campfire, signpost. Stylized grass (owner's MIT shader and mesh in `assets/grass/`) on grassy ground of the hunt map, 6 clumps per m², 20 m chunks hidden beyond 30 m.
- P3-019: owner's nature pack baked by `tools/bake_nature_meshes.gd`: massive grey rocks on every cliff, 32 rock shapes, oak/spruce/dead trees, palms for jungle trees (`props/varied_mesh.gd` picks by node name), 30 stumps and 24 logs with collision, 12 tall-grass patches with wheat, leafy bushes; neutral ambient light so grey no longer looks blue.

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

Owner playtest of the vertical slice (playtest batches 1 and 2 of 2026-10-27 in, D027).

## Handoff notes

Run the game from `game/bootstrap/app/main.tscn`: start screen → hunt → results. Controls are listed on the HUD. After changing the Green Valley relief run `python tools/bake_green_valley.py`.

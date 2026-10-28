---
state_version: 1
status: IMPLEMENTATION
current_phase: 3
current_milestone: P3_VERTICAL_SLICE
active_task_id: P3-023
last_completed_task_id: P3-023
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

None. P3-001..P3-023 done.

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
- P3-007: traps (pit, snare, tripwire, cage, fence) bought in the hunting hut and placed with T; trapped boars count as caught.
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
- P3-021: winding river (`river_z` in `tools/bake_green_valley.py`), one water plane with flow ripples, soft depth edge and no shadows, sandy banks, a log bridge; cliff rocks denser and solid (convex hulls); tall-grass patches are cover; no grass under stumps, logs and 70 extra trees.
- P3-022: owner's ferns (260, drawn within 35 m), Tree_1..3 among the trees, 36 fallen trees and logs; the bake gives every tree, log, stump, palm and fern one bark/leaf/needle palette and merges same-colour surfaces.
- P3-023: hunt HUD redesign: no controls legend; active bait on the left (F), active trap on the right (T), holding the key opens a ring menu to pick another; water under stamina; helpers line above the trap; tusks under the minimap and "+N" popups for tusks and picked-up items; boar counts in the Esc menu. A placed trap is a ghost that works only once built: hold E next to it (pit 6 s, cage 5 s, fence 4 s, snare 3 s, tripwire 2 s) or the hired trap setter walks over and builds it.
- P3-020: throw speed caps in `hunter.gd` (range net < spear < sling < bow): net 10 (charged 16), spear max 22, sling 24 (charged max 30), arrow 40.

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

## Latest

- 2026-10-28: pickups (stone piles, landed spears/arrows/stones/nets) get a pulsing outline within 8 m (`highlight.gd`); a net that hits a tree or rock now drops to the ground instead of freezing in the air.

- 2026-10-28 playtest fixes: tree collision now sits on the real trunk (many models keep it off the origin), corpses lie by turning only the model (no sinking), sling stones bounce off boars and lie as pickups.
- 2026-10-28 weapon model audit: all weapons are 44-168 triangles with no detached parts and outward normals; slingshot rebuilt as a Y-fork with two bands attached to the pouch, spear head made symmetric (no jitter), knife blade joined to its handle. Non-weapon heavy models: fence 2454 and bush 1280 triangles.
- 2026-10-28 owner weapon models (textured .glb: spear, arrow, club, sling, bow, knife) replace the generated ones in hand and as thrown spear and arrow; decimated afterwards to 220-800 triangles (arrow 220, spear 378, knife 448, sling 499 plus bands, bow 548, club 798) with no visible loss. Placed into the old frames (long axis +y, tip/head +y, bow string toward the player); spear straightened (it was tilted 34 degrees), sling bands snapped to fork and pouch (gaps up to 4 cm), bow grip at the origin. `tools/build_models.py` no longer builds them.

## Next action

Owner playtest of the vertical slice (playtest batches 1 and 2 of 2026-10-27 in, D027).

## Handoff notes

Run the game from `game/bootstrap/app/main.tscn`: start screen → hunt → results. Controls are listed on the HUD. After changing the Green Valley relief run `python tools/bake_green_valley.py`.

- 2026-10-28 P3-023: езда верхом — покачивание камеры, нельзя красться в седле, кабаны замечают всадника раньше (радиус x1.5, тревога x2) и убегают без атаки, крупные кабаны (здоровье >= 4) сбивают из седла (броня-ездовой держится).

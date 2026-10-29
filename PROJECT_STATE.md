---
state_version: 1
status: IMPLEMENTATION
current_phase: 3
current_milestone: P3_VERTICAL_SLICE
active_task_id: P3-032
last_completed_task_id: P3-032
build_status: PASS
updated: 2026-10-29
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

None. P3-001..P3-032 done.

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
- P3-024: owner's caveman models (skinny, heavy) cut to 5000 triangles, 1024 px textures, 25-bone skeleton with fingers (fists around the weapon) and automatic skin weights, animations idle, walk, run, sneak, ride, attack, strong_attack (wind-up held as a charge, then release), bow_shot (right fist solved onto the string and drawn to the chin; the viewer lays an arrow from it through the bow until release); built by `tools/rig_cavemen.py` (needs `pip install bpy`). "Character animations" on the start screen opens a viewer (pick model and animation, orbit camera, boar under the rider, always a weapon in hand: bow for the bow shot, club otherwise). Not yet used in gameplay (first-person game).
- P3-029: hireable helper (owner 2026-10-29) — the owner's tribesman (`tribal_character_04_12000.glb`) rigged by `tools/rig_cavemen.py helper` into `caveman_helper.glb` (1.5 m, 5000 triangles) with walk, run, sneak, crouch, hammer, sit and the owner's stone hammer in the right fist. He sits at the tavern's feast table (hammer hidden) and is still hired there as the trap setter; on the hunt he walks or runs after the hunter (boars sense only the hunter), and at each trap ghost squats and hammers the ground until it is built. The hunter's shadow body wears the owner's backpack on the hunt (`shadow_body.gd`, on the chest bone).
- P3-032: owner's tribal characters (2026-10-29) — `tools/rig_cavemen.py` rigs `tribal_hunter_12000` → `caveman_hunter.glb` (1.8 m), `tribal_character_02_12000` → `caveman_skinny.glb` (1.8 m) and `tribal_character_05_12000` → `caveman_heavy.glb` (1.65 m): 25 bones, 5000 triangles, idle/walk/run/sneak/ride/attack/strong_attack/bow_shot; the old caveman models are gone. The hunter is the shadow-only body (`shadow_body.gd`, backpack moved back to his fatter back); the hunter kind also writes `hunter_arm.glb`, his right forearm and fist posed as a fist, which replaces the primitive `hand.glb` in first person (no shadow; the body casts it). Viewer lists Hunter, Skinny, Heavy. Sources: 12k triangles, one material, three 1024 maps each.
- P3-031: ambience (owner 2026-10-29) — jungle bed always on (hunt and camp), river sound at the river point nearest the hunter (25 m), wind loop at the camp drop-off (one take, random in/out points); `sfx_loop.gd` blends overlapping takes with random entry, swell and fade. "Effects volume" slider in the pause menu (master bus, saved). `core.synth` removed (ram thud now silent).
- P3-030: owner's recorded sounds (2026-10-29) — all of `assets/sfx/<group>/` as OGG `<group>_<n>.ogg`, played by `core.sfx` (random take, no repeat, random pitch and volume). Impacts (arrow, stone, spear, net, club) are 3D at the landing point (20 m); boars cry when they start to run (own take, up to 0.5 s late), panic in layers incl. reversed takes, squeal when hit, grunt at the ram, hooves while running, splash in the river, grunt now and then when calm and in the camp pen; hunter steps on ground/grass/river, bush rustle in and out of cover, roar on R, bow/sling draw and spear wind-up, shots and throws, a grunt on melee blows; helper steps; rooster and turkey calls and idles; crossfaded fire loop at the campfire/brazier and the tavern hearth (10 m). Rivers are physics layer 7. Jungle and river ambience: P3-031.
- P3-028: camp polish (owner 2026-10-29) — camp square 40 → 34 m; huts and tents 30% larger, every entrance faces the campfire, cage rack to the right of the pen facing the centre (tavern now south-east, pens south-west). Ground shader (`props/ground.gdshader`): mottled dirt with reddish clay, wobbly grass border with soft edge (also under the forest), trodden patches at the fire, the doors and along the paths to them and to the gate. Lower rocks skirt the rock wall and the drop-off so no strip shows, some inside the camp. Pebbles round the perimeter, ferns and bushes beside the buildings (`props/dressing.gd`). Blue gradient sky with a visible sun (sky-only light). Hunter has a shadow-only caveman body (idle/walk/run/sneak/ride), so his shadow falls on buildings. Frame time held at the old level (skirt rocks and plants as shadowless MultiMesh, less hidden grass).
- P3-027: camp edges redesigned — perimeter fence gone; rock wall rising on the west and south-west, rocky drop-off on the east and south-east over an unreachable hazy valley (river, hills, woods, birds that take off, fly and land), toy clouds; palisade of mixed logs with an ajar gate behind the Start hunt sign, forest beyond. Owner's large, round and A-frame hide tents and the tribal well placed; water is filled free at the well (moved from the Hunting hut). Invisible StaticBody walls keep the hunter in.
- P3-025: owner's 13 boar models cut to 3000 triangles (bone boar 4000, flat shaded, 512 px textures), quadruped skeleton found from the mesh (feet, belly, back, snout, tail) with automatic weights, animations idle, walk, run (trot: only the legs work, body and head stay steady, owner 2026-10-28), eat (snout on the ground, played at a bait), attack (lunge with a tusk rip), death (rolls onto its side); built by `tools/rig_boars.py` into `assets/models/boar_<type>.glb`. Types: Forest boar = boar_buddy, Runner = neon_boar, Angry = tusker_totem, Armored = blocky_boar, Golden tusk = golden_piggy_bank; rare variants (weights 1.5–2 of ~114): Bone, Bun (cinnamon), Bubble, Mohawk (spiky), Long (boaripede), Camouflage, Hairy (cozy cloak), Tiny tusker. Boars play idle/walk/run by speed, attack when a charge locks on, death when killed; saddles sit on the model's back. Boars are in the in-game animation viewer and on a web page (Artifact "Boar Animations").
- P3-026: toy roosters and turkeys after the owner's three references, own colours (rooster: cream, ochre wings, teal/navy/green sickle tail; turkey: brown, blue head and neck, bronze/teal/cream fan), fat and thin builds each, smooth vinyl look, rigid-part rig (body, neck, head, tail, wings, thighs, shins) with idle, walk, run (wings flap), peck (beak to the ground); superseded 2026-10-29: the owner's thin models `tribal_<rooster|turkey>_3000.glb` replace them, animated by `bird_model.gd` (no skeleton: hop, roll, lean, beak dip). Wild birds pick a build at random, face their heading, peck when they stop; 3 roosters and 3 turkeys around each spare spawn point (6 + 6 per hunt, was 1 + 1); caged birds idle in camp; the summoned rooster flies with flapping wings; birds are in the animation viewer.
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
- 2026-10-28 camp scenery (`camp/props/scenery.gd`): green lawn beyond the fence, 70 oak/spruce trees, small rocks inside and outside, stylized grass along the inside of the fence and outside it (no collision; only seen from inside the fence).
- 2026-10-28 camp campfire replaced by the owner's tribal cooking set (fire ring, tripod pot with soup, flame meshes, steam, plus a terracotta brazier ~2.3 m east; 10k triangles, left as is). Scene roots shifted so the fire sits at the station origin.
- 2026-10-29 camp armory (WeaponShop station) uses the owner's tribal weapon stall (`assets/models/weapon_stall.glb`, 38k triangles, 267 small meshes, left as is); other stations keep `stall.glb`.
- 2026-10-29 camp hunting hut station uses the owner's tribal hunter stall (`assets/models/hunter_stall.glb`, 63k triangles, 114 meshes, left as is).
- 2026-10-29 camp tavern station uses the owner's tribal tavern (`assets/models/tavern.glb`, ~19k triangles, 54 meshes, left as is); front orientation not checked in-game.
- 2026-10-29 camp "Start hunt" station (exit toward the hunt, z=-16) uses the owner's tribal direction sign (`assets/models/direction_sign.glb`, 3k triangles, 10 meshes, ~2.7 m tall); replaces the placeholder `signpost.glb`; arrow direction not checked in-game.
- 2026-10-29 camp Pens station uses the owner's tribal boar pen (`boar_pen.glb`, 31k triangles) with the tribal cage rack (`cage_rack.glb`, 43k, left as is) right behind it. Caught roosters/turkeys (up to 3 each) show in the rack's cages; the pen shows the last five caught boars as their own rigged models (`Progress.pen`, oldest out first, saved in the "pen" field).

- 2026-10-29 hunt FPS: map props (bushes, trees, rocks) are drawn as one MultiMesh per model and 80 m quadrant (`hunt_map.gd` `_batch_props`); sun shadows end at 60 m; stone piles and boar health bars cast no shadow. Measured at the hunter's start view (1280x720): 2289 -> 720 draw calls and 1.51M -> 1.07M triangles per frame. Scripts take ~0.5 ms per frame, so boar AI was not the cause.

## Next action

Owner playtest of the vertical slice (playtest batches 1 and 2 of 2026-10-27 in, D027).

## Handoff notes

Run the game from `game/bootstrap/app/main.tscn`: start screen → hunt → results. Controls are listed on the HUD. After changing the Green Valley relief run `python tools/bake_green_valley.py`.

- 2026-10-28 P3-023: езда верхом — покачивание камеры, нельзя красться в седле, кабаны замечают всадника раньше (радиус x1.5, тревога x2) и убегают без атаки, крупные кабаны (здоровье >= 4) сбивают из седла (броня-ездовой держится).

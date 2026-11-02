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
| P3-026 | 3 | Toy rooster and turkey models (fat and thin, own colours) rigged with idle, walk, run, peck; in the hunt (6 of each), camp cages, rooster helper and the animation viewer | P3-025 | DONE |
| P3-027 | 3 | Camp edges and decor: rock wall up (W, SW), drop-off with vista (E, SE: river, hills, woods, haze, toy clouds, birds), log palisade with ajar gate (N), owner's tents and well; water at the well | P3-026 | DONE |
| P3-028 | 3 | Camp polish: rocks meet the ground and spill into camp, wobbly grass border, colourful ground trodden at the fire, doors and paths; compact camp (34 m), huts and tents +30%, every entrance faces the centre, cages right of the pen; hunter's shadow body; blue gradient sky with a sun; pebbles, ferns and bushes | P3-027 | DONE |
| P3-029 | 3 | Hireable helper: owner's tribesman rigged (walk, run, sneak, crouch, hammer, sit) with the stone hammer; sits at the tavern table, follows the hunter on the hunt unseen by boars, squats and hammers at trap ghosts; hunter wears the owner's backpack on the hunt | P3-028 | DONE |
| P3-030 | 3 | Owner's sounds: WAV → OGG with short names; impacts heard where they land, boar cries/panic/steps/voices, hunter steps by surface, bushes, roar, weapon draws, shots and blows, birds, crossfaded fire loop at the campfire and tavern hearth | P3-029 | DONE |
| P3-031 | 3 | Ambience: jungle always on (hunt and camp), river near the water, wind at the camp drop-off, overlapping takes blended; effects volume slider; synthesized sounds removed | P3-030 | DONE |
| P3-032 | 3 | Owner's new tribal characters rigged and animated: hunter as the player's shadow body with his own arm in first person; skinny and heavy replaced; old caveman models and the primitive hand removed | P3-031 | DONE |
| P3-033 | 3 | Bait fruit models in the hunt and atlas icons (no name, price only) in the hunting hut shop | P3-032 | DONE |
| P3-034 | 3 | Owner's rigged net: hangs from the fist, opens in flight, drapes over the caught boar's shape and rides its forward fall | P3-033 | DONE |
| P3-035 | 3 | Hunt map: mesa and river cliffs widened into steep rocky slopes (no flat walls); normal grass 50% lower, tall patches unchanged | P3-034 | DONE |
| P3-036 | 3 | Camp fixes: stalls/tavern back to size (tents only +30%), greenery and tavern sand blob out of models, solid buildings/pens/rim rocks, rock wall grounded and sinking to the drop-off, hunt-size bushes and ferns, cage birds turned 180° with both feet down, helper's hammer grip | P3-032 | DONE |
| P3-037 | 3 | Camp UI: station outline + pulsing E key above stamina, name-only building labels, bait shop icons 3x smaller, shop and pause menus scroll to fit any resolution | P3-036 | DONE |

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
| P3-038 | 3 | StoneTrail font as the default UI and 3D label font (project theme, Label3D nodes) | P3-036 | DONE |
| P3-039 | 3 | Hunt map surroundings: grey wall gone (invisible collision), woods, grass, rocks and far mountains past the walls; escape zones on the map edge with natural gates of tall grass and rotten stumps | P3-038 | DONE |
| P3-040 | 3 | Camp FPS: batch scenery meshes, camp shadow range 40 m, valley trees culled by cell | P3-039 | DONE |
| P3-041 | 3 | Owner's trap models with trigger animations and new trap rules (D040): snare rescue and E-take, leaf pit in the ground, two-peg tripwire with stun stars, half-inside cage, fence; build times and carry caps | P3-040 | DONE |
| P3-042 | 3 | Bait shop icons: removed stray fragments of neighbouring atlas icons from 6 PNGs (`assets/icon/bait/`) | P3-041 | DONE |
| P3-043 | 3 | Sneaking hunter inside tall grass or a bush is unseen by boars, even by boars standing in the same patch (hearing unchanged) | P3-042 | DONE |
| P3-044 | 3 | Bait is eaten up after 10 s at the bait, then gone; calm boars graze or stand most of the time, walk over to stand by a herd mate, and roam only sometimes | P3-043 | DONE |
| P3-045 | 3 | A thrown net that misses lies on the ground instead of hanging above it | P3-044 | DONE |
| P3-046 | 3 | Net throw distance capped at 15 m (`NET_MAX_SPEED` in hunter.gd) | P3-045 | DONE |
| P3-047 | 3 | Trap placement mode: T shows a ghost preview (green where free, red over trees, stumps, rocks), Q/R turn it, LMB puts it down; the helper builds from any side | P3-046 | DONE |
| P3-048 | 3 | A fleeing boar may hide in tall grass, stand there without a fear mark, then calm down and walk out; boars scattered by an attack walk back to their herd once they find it | P3-047 | DONE |
| P3-049 | 3 | Trees (and stumps, logs) on slopes sink to the lowest ground under their footprint so they never float | P3-048 | DONE |
| P3-050 | 3 | Spear/net slot leaves the hotbar when out, knife auto-equipped; bow/sling with no ammo play a cancel sound (`assets/sfx/no_ammo/`, placeholder) | P3-049 | DONE |
| P3-051 | 3 | Hunt FPS: half the grass clumps (wider), 2 sun shadow cascades in hunt and camp, boar health bar/label/dust drawn within 40 m only | P3-050 | DONE |
| P3-052 | 3 | Baked shadows: static trees, rocks, bushes and buildings cast no live shadow; their shadows are rendered once into a ground texture (`core.baked_shadow`) | P3-051 | DONE |
| P3-053 | 3 | Saddle scaled to boar size (length/height ratio) so it sits on the back of small and big boars | P3-052 | DONE |
| P3-054 | 3 | Riding: any ramming boar throws the rider off and the mount stays put; mount hoof sounds and idle `boar_voice` while riding | P3-053 | DONE |
| P3-055 | 3 | Trees whose lowest vertex is above the model origin (OakTree3, DeadOak3) sink by that gap too; wider ground probe ring | P3-054 | DONE |
| P3-056 | 3 | No ?/! alert mark over a dead or caught boar (label and health bar stay) | P3-055 | DONE |
| P3-057 | 3 | Clouds on the hunt map (shared core.clouds, same as camp vista) | P3-056 | DONE |
| P3-058 | 3 | Missed arrows/spears stick into the ground; corpse stays until its projectiles are taken | P3-057 | DONE |
| P3-059 | 3 | Rocks, cliffs and grass in a PEAK-like style: procedural faceted boulders, layered cliff chunks, horizon peaks, swaying bright grass (`tools/bake_peak_rocks.gd`) | P3-058 | DONE |
| P3-061 | 3 | Trees and bushes in a PEAK-like style to match P3-059: puffy faceted broadleaves, jagged pines, dead trees, palms, bushes, low leafy undergrowth instead of ferns (`tools/bake_peak_trees.gd`) | P3-059 | DONE |
| P3-062 | 3 | Dead boars make no sound: no idle voice, panic squeals or steps after death (`boar_sounds.gd` `silent`) | P3-061 | DONE |
| P3-063 | 3 | Denser short grass with noise height variation, soft range fade, grass-style hunt ground with a normal map for turf and sand (`peak_ground.gdshader`) | P3-059 | DONE |
| P3-064 | 3 | Cliffs as solid stepped walls facing downhill instead of a chaotic boulder pile (`tools/bake_peak_rocks.gd`, `terrain.gd` `_place_cliff_rocks`) | P3-059 | DONE |
| P3-065 | 3 | Camp buildings in a simplified PEAK-like style: procedural stalls, tavern, tents, pens, cages, campfire, well and signpost with the same footprints and anchor points; brighter faceted palisade (`tools/bake_peak_buildings.gd`) | P3-061 | DONE |
| P3-066 | 3 | Weapons in a simplified PEAK-like style: procedural spear, arrow, club, knife, sling, bow and sling stone (`tools/bake_peak_weapons.gd`), flat rope material on the net | P3-059 | DONE |
| P3-067 | 3 | Stumps and logs in a simplified PEAK-like style (`tools/bake_peak_stumps.gd`: `PeakStump1`, `PeakLog1-4`) | P3-061 | DONE |
| P3-068 | 3 | Traps and bait in a simplified PEAK-like style: procedural pit, snare, tripwire, cage, fence and nine fruits (`tools/bake_peak_traps.gd`), bait icons re-rendered | P3-059 | DONE |
| P3-069 | 3 | Camp shops show the game's real weapon and bait models; decorative traps around the hunting hut; black armory emblem with a cave-painting bow (`game/presentation/camp/props/shop_display.gd`) | P3-068 | DONE |
| P3-070 | 3 | Bone and wooden spears: kinds in Loadout, models, armory stock and rack | Done |
| P3-071 | 3 | Saddle, backpack and helper hammer in a simplified PEAK-like style (`tools/bake_peak_gear.gd`) | P3-066 | DONE |
| P3-072 | 3 | Cliffs not boxy: tilted, bevelled layer tops; camp rim and drop-off rocks fewer and larger (`tools/bake_peak_rocks.gd`, `scenery.gd`) | P3-064 | DONE |

# CLAUDE.md

Canonical rules live in `AGENTS.md`; this file is a quick map. Godot 4.x, GDScript.

## Read first, in order
`AI_START_HERE.md`, `AGENTS.md`, `GAME_SPEC.md`, `docs/WORKING_AGREEMENT.md`, `PROJECT_STATE.md`, `ACTIVE_TASK.md`.
Follow the mode they select. Do not implement gameplay while `GAME_SPEC.md` is `DRAFT`.

## Layout
- `game/` — GDScript source, by feature (`game/<feature>/`); `architecture.yml` per module.
- `architecture/policy.json`, `docs/ARCHITECTURE.md`, `docs/adr/` — layer and dependency rules.
- `tools/` — Python validators. `templates/` — task and doc templates.
- `BACKLOG.md` — task list; `ACTIVE_TASK.md` — the one task being worked on.

## Work rules
- One active task at a time; stay inside its scope and update `PROJECT_STATE.md` and the task status when done.
- On conflicting rules, stop and ask; never invent a rule.
- Gameplay rules must run without a scene (engine-light classes, headless tests).
- Limits: production `.gd` file max 600 lines (review above 300), test file max 900, function max 100.

## Checks
```
python tools/validate_game_spec.py --ready
python tools/validate_workflow_state.py --ready
python tools/validate_project.py
godot --headless --path . --editor --quit   # Godot 4.7.2, when available
```
`validate_project.py` runs the architecture, source-size and import-file checks.

extends RefCounted

## The hunters the player can be (owner's references, 2026-11-02), picked in the settings: the body
## that casts the shadow (tools/build_peak_cavemen.py). First person shows no arms (owner, 2026-11-23).
## Bearded, plump and lanky wear the owner's rigged hunters (assets/models/hunter/, 2026-11-23), animated by HunterRig.

const HunterRig = preload("res://game/features/hunter/public/hunter_rig.gd")
const DEFAULT := "bearded"
const KINDS: Array[String] = ["bearded", "plump", "lanky"]


## kind, or the default one when the settings hold an unknown name.
static func known(kind: String) -> String:
	return kind if kind in KINDS else DEFAULT


## The rigged hunters by kind; other kinds are cavemen with their own clips.
const HUNTERS := {
	"bearded": "res://assets/models/hunter/prehistoric_hunter.glb",
	"plump": "res://assets/models/hunter/plump_hunter.glb",
	"lanky": "res://assets/models/hunter/lanky_hunter.glb",
}


## The body of this kind, with an AnimationPlayer holding idle, walk, run, sneak and ride (and more).
static func body(kind: String) -> Node3D:
	kind = known(kind)
	if HUNTERS.has(kind):
		return HunterRig.instance(load(HUNTERS[kind]))
	return load("res://assets/models/peak_cavemen/%s.glb" % kind).instantiate()

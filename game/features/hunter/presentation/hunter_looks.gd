extends RefCounted

## The hunters the player can be (owner's references, 2026-11-02), picked in the settings: the body
## that casts the shadow and the forearm seen in first person (tools/build_peak_cavemen.py).

const DEFAULT := "bearded"
const KINDS: Array[String] = ["bearded", "plump", "lanky"]
## Where the backpack sits on each body, in the model's space (it faces +z, the back is -z).
const BACKPACK := {
	"bearded": Transform3D(Basis.IDENTITY * 0.6, Vector3(0.0, 0.9, -0.48)),
	"plump": Transform3D(Basis.IDENTITY * 0.6, Vector3(0.0, 0.85, -0.55)),
	"lanky": Transform3D(Basis.IDENTITY * 0.6, Vector3(0.0, 1.15, -0.4)),
}


## kind, or the default one when the settings hold an unknown name.
static func known(kind: String) -> String:
	return kind if kind in KINDS else DEFAULT


static func body(kind: String) -> PackedScene:
	return load("res://assets/models/peak_cavemen/%s.glb" % known(kind))


static func arm(kind: String) -> PackedScene:
	return load("res://assets/models/peak_cavemen/arm_%s.glb" % known(kind))

#!/usr/bin/env python3
"""Lowers the raised foot of the owner's static rooster and turkey models (owner, 2026-10-30) so both
feet stand on the ground. Edits assets/models/tribal_<bird>_3000.glb in place; running it twice does
nothing more (the lifted foot is already at height 0). Model space: height is -z (the node turns +90 deg about x)."""
import json
import struct
from pathlib import Path

import numpy as np

MODELS = Path(__file__).resolve().parent.parent / "assets" / "models"
# bird: (leg selector on the raised side y < 0, height where the leg starts blending into the body)
BIRDS = {
    "tribal_rooster_3000": (lambda p: p[:, 0] > 0.04, 0.22),
    "tribal_turkey_3000": (lambda p: np.abs(p[:, 0]) < 0.25, 0.26),
}


def main() -> None:
    for name, (in_leg, top) in BIRDS.items():
        path = MODELS / f"{name}.glb"
        data = bytearray(path.read_bytes())
        json_len, = struct.unpack_from("<I", data, 12)
        meta = json.loads(data[20:20 + json_len])
        start = 20 + json_len + 8
        count = meta["accessors"][0]["count"]
        pos = np.frombuffer(data, dtype="<f4", count=count * 3, offset=start).reshape(-1, 3).copy()
        height = -pos[:, 2]
        raised = (pos[:, 1] < 0) & in_leg(pos) & (height < top)
        lift = height[raised].min()
        weight = np.clip((top - height[raised]) / (top - lift), 0.0, 1.0)
        pos[raised, 2] += lift * weight  # z grows towards the ground
        data[start:start + pos.nbytes] = pos.astype("<f4").tobytes()
        meta["accessors"][0]["min"] = pos.min(axis=0).tolist()
        meta["accessors"][0]["max"] = pos.max(axis=0).tolist()
        new_json = json.dumps(meta, separators=(",", ":")).encode()
        new_json += b" " * (-len(new_json) % 4)
        out = data[:12] + struct.pack("<I", len(new_json)) + data[16:20] + new_json + data[20 + json_len:]
        out[8:12] = struct.pack("<I", len(out))
        path.write_bytes(out)
        print(f"{name}: lowered {raised.sum()} vertices by {lift:.3f}")


if __name__ == "__main__":
    main()

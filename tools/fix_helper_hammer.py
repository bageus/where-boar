#!/usr/bin/env python3
"""Turns the helper's hammer a quarter turn about its handle (owner, 2026-10-30): it was gripped with the
head pointing sideways, now the head lies in the plane of the swing. Edits assets/models/caveman_helper.glb
in place; run it once (a second run turns it back a quarter further)."""
import json
import math
import struct
import sys
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "assets" / "models" / "caveman_helper.glb"


def mul(a: list, b: list) -> list:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz]


def main() -> None:
    sign = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    data = PATH.read_bytes()
    json_len, = struct.unpack_from("<I", data, 12)
    meta = json.loads(data[20:20 + json_len])
    node = next(n for n in meta["nodes"] if n.get("name") == "hammer")
    half = sign * math.pi / 4
    node["rotation"] = mul(node["rotation"], [0.0, math.sin(half), 0.0, math.cos(half)])  # about the handle (local Y)
    new_json = json.dumps(meta, separators=(",", ":")).encode()
    new_json += b" " * (-len(new_json) % 4)
    out = bytearray(data[:12] + struct.pack("<I", len(new_json)) + data[16:20] + new_json + data[20 + json_len:])
    out[8:12] = struct.pack("<I", len(out))
    PATH.write_bytes(out)


if __name__ == "__main__":
    main()

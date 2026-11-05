"""The mamak apron drying on the laundry rack by the window: the figure's apron (art/shared/apron, the same pattern and
texture), folded over the rack's rail at the waist. The skirt hangs on the room's side, its stained front out; the bib
hangs behind with the neck strap looped below it; the ties come over the rail and hang down the front of the skirt,
past its hem. Run by tools/models.sh.

The origin is on the rail, 1 cm under its centre (the game places it at the rack's 1.69 m; the rail is 2.5 cm square
round 1.7 m), and the rail runs along X. The front, the skirt's side, faces -Y, which is the game's +Z.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils import noise as perlin

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "apron")]
import apron  # noqa: E402
import common  # noqa: E402

perlin.seed_set(1208)

RAIL_Z = 0.01  # the rail's centre above the origin
BEND = 0.0145  # the cloth's bend over the rail: the rail's half-thickness and a little
FOLD = 0.44  # the pattern's v that lies on top of the rail, a little below the waist


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def hung(u: float, s: float, out: float = 0.0) -> Vector:
    """The cloth s metres from the top of the rail (negative down the front, positive down the back), u across, out
    metres further from the rail than the cloth: over the rail, then hanging in loose folds that grow towards the hem."""
    quarter = math.pi * BEND / 2
    if abs(s) <= quarter:
        a = s / BEND
        r = BEND + out
        return Vector((u, r * math.sin(a), RAIL_Z + r * math.cos(a)))
    side = math.copysign(1.0, s)
    drop = abs(s) - quarter
    ripple = 0.01 * smooth(drop / 0.15) * math.sin(u * 30.0 + 2.0 * perlin.noise(Vector((u * 8.0, drop * 3.0, side))))
    away = BEND + out + ripple + 0.012 * smooth(drop / 0.45)
    return Vector((u * (1.0 + 0.03 * smooth(drop / 0.4)), side * away, RAIL_Z - drop))


def build() -> bpy.types.Object:
    bm = bmesh.new()
    quarter = math.pi * BEND / 2
    vs = [0.0] + [0.025 * k for k in range(1, 16)] + [FOLD + quarter * k / 5 for k in range(-5, 6)]
    vs += [FOLD + quarter + 0.03 * k for k in range(1, 12)] + [apron.LENGTH]
    vs = sorted({round(v, 5) for v in vs if 0.0 <= v <= apron.LENGTH})
    rows = apron.panel(bm, lambda u, v: hung(u, v - FOLD), vs, 14)
    # The neck strap hangs in a loop from the bib's top corners, behind it.
    left, right = rows[-1][-2].co, rows[-1][1].co
    loop = []
    for k in range(25):
        t = k / 24
        p = left.lerp(right, 0.5 - 0.5 * math.cos(math.pi * t))
        loop.append(Vector((p.x, p.y + 0.006, p.z - 0.24 * math.sin(math.pi * t))))
    apron.strap(bm, "neck", loop, [Vector((0, 1, 0))] * len(loop))
    # The ties start at the waist's corners, just behind the top of the rail, and hang down the front.
    for side, which in ((1, "left"), (-1, "right")):
        u0 = side * apron.half_width(apron.WAIST)
        path = []
        for k in range(23):
            along = apron.TIE_LEN * k / 22
            s = apron.WAIST - FOLD - along
            u = u0 - side * (0.03 * smooth(along / 0.1) + 0.012 * math.sin(along * 9.0 + side))
            path.append(hung(u, s, out=0.003 + 0.011 * smooth((abs(s) - math.pi * BEND / 2) / 0.04)))  # clear of the folds below
        apron.strap(bm, which, path, [Vector((0, p.y, min(p.z - RAIL_Z, 0.0) * 0.1 + max(p.z - RAIL_Z, 0.0))).normalized() for p in path])
    me = bpy.data.meshes.new("ApronHung")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("ApronHung", me)
    bpy.context.scene.collection.objects.link(obj)
    me.materials.append(apron.material())
    return obj


common.reset()
hung_apron = build()
print("APRON tris", sum(len(p.vertices) - 2 for p in hung_apron.data.polygons))
common.export("apron_hung", [hung_apron])

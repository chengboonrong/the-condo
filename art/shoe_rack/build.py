"""The entrance's shoe rack: the cheap three-tier slatted kind from a hardware shop, 1.0 m long, 0.38 m deep and
0.6 m tall, two flat side panels carrying a slatted shelf each at 0.03, 0.3 and 0.59 m. The varnish has worn off the
edges and where shoes have scraped, and the shelves are grimy; a pair of blue rubber selipar sit on the bottom shelf.
Run by tools/models.sh.

The rack's front faces -Y; its length runs along X. The pair of work shoes that stand on its top shelf are a model of
their own (work_shoes), placed by the game.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

LENGTH, DEPTH = 1.0, 0.38
PANEL = 0.018  # thickness of the side panels
SHELVES = [0.03, 0.3, 0.59]  # centre heights
SLAT = (0.056, 0.02)  # width, thickness
SLATS = 5
BATTEN = (0.03, 0.015)
FOOT = 0.02  # the panels stand on two feet this tall
# The panel's outline in (y, z), anticlockwise seen from +X: two feet, a notch between them, the corners rounded off.
PANEL_OUTLINE = [(-0.19, 0.0), (-0.15, 0.0), (-0.15, FOOT), (0.15, FOOT), (0.15, 0.0), (0.19, 0.0), (0.19, 0.59),
                 (0.18, 0.6), (-0.18, 0.6), (-0.19, 0.59)]
SELIPAR = 0.26  # length
WOOD, PINE = 0, 3  # material indices: three woods, then the batten pine, rubber and strap
SOLE, STRAP = 4, 5


# --- geometry -------------------------------------------------------------------------------------------

def box(bm: bmesh.types.BMesh, centre: tuple, size: tuple, material: int) -> None:
    geom = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector(centre), None, Vector(size)))
    for f in {f for v in geom["verts"] for f in v.link_faces}:
        f.material_index = material


def panel(bm: bmesh.types.BMesh, x: float, material: int) -> None:
    """A side panel: PANEL_OUTLINE extruded along X, centred on x."""
    x0, x1 = x - PANEL / 2, x + PANEL / 2
    back = [bm.verts.new((x0, y, z)) for y, z in PANEL_OUTLINE]
    front = [bm.verts.new((x1, y, z)) for y, z in PANEL_OUTLINE]
    faces = [bm.faces.new(front), bm.faces.new(back[::-1])]
    for k in range(len(back)):
        j = (k + 1) % len(back)
        faces.append(bm.faces.new([back[k], back[j], front[j], front[k]]))
    for f in faces:
        f.material_index = material


def shelf(bm: bmesh.types.BMesh, z: float, tier: int) -> None:
    """Slats along X between the panels, with a gap between them, on two battens running front to back."""
    span = LENGTH - 2 * PANEL
    gap = (DEPTH - SLATS * SLAT[0]) / (SLATS - 1)
    for i in range(SLATS):
        y = -DEPTH / 2 + SLAT[0] / 2 + i * (SLAT[0] + gap)
        box(bm, (0.0, y, z), (span, SLAT[0], SLAT[1]), WOOD + (tier + 2 * i) % 3)
    for x in (-0.22, 0.22):
        box(bm, (x, 0.0, z - SLAT[1] / 2 - BATTEN[1] / 2), (BATTEN[0], DEPTH - 0.04, BATTEN[1]), PINE)


def hidden(f: bmesh.types.BMFace) -> bool:
    """A face nobody sees: facing down, or the end of a slat against its side panel."""
    x = f.calc_center_median().x
    return f.normal.z < -0.99 or (abs(abs(x) - (LENGTH - 2 * PANEL) / 2) < 1e-4 and f.normal.x * math.copysign(1, x) > 0.99)


def selipar(bm: bmesh.types.BMesh, centre: tuple, yaw: float) -> None:
    """A rubber flip-flop lying on the shelf: its sole lofted from stations (heel at +Y, toe at -Y), a V of strap
    over it. The soles are open underneath."""
    widths = [(0.0, 0.034), (0.2, 0.034), (0.45, 0.03), (0.72, 0.046), (0.88, 0.044), (1.0, 0.03)]
    stations = 11
    turn = math.cos(yaw), math.sin(yaw)

    def vert(x: float, y: float, z: float) -> bmesh.types.BMVert:
        return bm.verts.new((centre[0] + x * turn[0] - y * turn[1], centre[1] + x * turn[1] + y * turn[0], centre[2] + z))

    def half(s: float) -> float:
        e = 3.0 if s < 0.5 else 2.2
        k = max(i for i in range(len(widths) - 1) if widths[i][0] <= s)
        (s0, w0), (s1, w1) = widths[k], widths[k + 1]
        return (w0 + (w1 - w0) * (s - s0) / (s1 - s0)) * (1 - abs(2 * s - 1) ** e) ** (1 / e)

    ss = [0.5 - 0.5 * math.cos(math.pi * (i + 0.5) / stations) for i in range(stations)]
    rings = []
    for scale, z in [(0.96, 0.0), (1.0, 0.003), (1.0, 0.010), (0.97, 0.013)]:
        ring = [vert(-half(s) * scale, (0.5 - s) * SELIPAR * scale, z) for s in ss]
        ring += [vert(half(s) * scale, (0.5 - s) * SELIPAR * scale, z) for s in reversed(ss)]
        rings.append(ring)
    n = len(rings[0])
    faces = []
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new([a[i], a[j], b[j], b[i]]))
    faces.append(bm.faces.new(rings[-1]))
    for f in faces:
        f.material_index = SOLE
        f.smooth = True
    for end in (-1, 1):  # the strap: from the post between the toes, up over the foot, to each side of the sole
        path = []
        for k in range(5):
            t = k / 4
            path.append((end * 0.032 * t, -0.08 + 0.06 * t, 0.011 + 0.026 * math.sin(math.pi * t) ** 0.8 * (1 - 0.35 * t)))
        sections = []
        for k, (x, y, z) in enumerate(path):
            ahead, behind = path[min(k + 1, 4)], path[max(k - 1, 0)]
            dx, dy = ahead[0] - behind[0], ahead[1] - behind[1]
            nx, ny = -dy / math.hypot(dx, dy), dx / math.hypot(dx, dy)  # across the strap, in plan
            sections.append([vert(x + sx * nx * 0.006, y + sx * ny * 0.006, z + sz * 0.0025) for sx, sz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]])
        faces = [bm.faces.new(sections[0]), bm.faces.new(sections[-1])]
        for a, b in zip(sections, sections[1:]):
            faces += [bm.faces.new([a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]]) for i in range(4)]
        bmesh.ops.recalc_face_normals(bm, faces=faces)  # a closed solid: wound outwards whichever way the path turns
        for f in faces:
            f.material_index = STRAP
            f.smooth = True


# --- materials ------------------------------------------------------------------------------------------

def wood(name: str, tint: tuple, raw: bool = False) -> bpy.types.Material:
    """Varnished pine: grain along X, the varnish gone from the edges and in patches, dirt where it is dark in the
    corners and on the shelf tops. raw: unvarnished (the battens), not shiny anywhere."""
    mat, nt, bsdf, coords = common.surface(name)

    def stretched(scale: tuple) -> bpy.types.NodeSocket:  # noise drawn out along X: the grain
        return common.noise(nt, common.node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": scale}).outputs["Vector"], 1.0, 3.0)

    rings = common.maths(nt, "ADD", common.maths(nt, "MULTIPLY", stretched((3.0, 120.0, 120.0)), 0.6), common.maths(nt, "MULTIPLY", stretched((2.0, 22.0, 22.0)), 0.4))
    grain = common.mapped(nt, rings, 0.3, 0.7, 0.0, 1.0)
    bevelled = common.node(nt, "ShaderNodeBevel", {"Radius": 0.003}, samples=16).outputs["Normal"]
    flat = common.node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    worn = 1.0  # the battens are bare wood
    if not raw:
        edge = common.mapped(nt, common.node(nt, "ShaderNodeVectorMath", {0: bevelled, 1: flat}, operation="DOT_PRODUCT").outputs["Value"], 1.0, 0.8, 0.0, 1.0)
        patches = common.mapped(nt, common.noise(nt, coords, 7.0, 3.0), 0.56, 0.7, 0.0, 1.0)
        worn = common.maths(nt, "MAXIMUM", edge, common.maths(nt, "MULTIPLY", patches, 0.85))
    varnished = common.lerp(nt, tuple(c * 0.75 for c in tint), tuple(c * 1.1 for c in tint), grain)
    bare = common.lerp(nt, tuple(c * 1.5 for c in tint), tuple(c * 1.9 for c in tint), grain)
    colour = common.lerp(nt, varnished, bare, worn)
    up = common.mapped(nt, common.node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs["Z"], 0.5, 0.95, 0.0, 1.0)
    grime = common.maths(nt, "MULTIPLY", up, common.mapped(nt, common.noise(nt, coords, 3.5, 3.0), 0.45, 0.75, 0.0, 0.5))
    colour = common.lerp(nt, colour, (0.02, 0.016, 0.012), grime)
    dark = common.node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.05}, samples=32, only_local=True).outputs["AO"]
    colour = common.lerp(nt, tuple(c * 0.4 for c in tint), colour, common.mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(common.maths(nt, "MAXIMUM", common.mapped(nt, worn, 0.0, 1.0, 0.3, 0.85), common.mapped(nt, grime, 0.0, 0.5, 0.0, 0.8)), bsdf.inputs["Roughness"])
    nt.links.new(bevelled, bsdf.inputs["Normal"])
    return mat


def rubber(name: str, colour: tuple) -> bpy.types.Material:
    """Blue rubber: faded and dirty from a kitchen floor, a little glossy."""
    mat, nt, bsdf, coords = common.surface(name)
    dirt = common.mapped(nt, common.noise(nt, coords, 22.0, 6.0), 0.4, 0.7, 0.0, 0.6)
    nt.links.new(common.lerp(nt, colour, tuple(c * 0.25 + 0.01 for c in colour), dirt), bsdf.inputs["Base Color"])
    nt.links.new(common.mapped(nt, common.noise(nt, coords, 14.0, 4.0), 0.4, 0.65, 0.4, 0.75), bsdf.inputs["Roughness"])
    nt.links.new(common.node(nt, "ShaderNodeBevel", {"Radius": 0.002}, samples=4).outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
bm = bmesh.new()
for x in (-(LENGTH - PANEL) / 2, (LENGTH - PANEL) / 2):
    panel(bm, x, WOOD + 2)
for tier, z in enumerate(SHELVES):
    shelf(bm, z, tier)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)  # the panels were wound by hand; the rest are closed boxes
bmesh.ops.delete(bm, geom=[f for f in bm.faces if hidden(f)], context="FACES")
shelf_top = SHELVES[0] + SLAT[1] / 2
selipar(bm, (0.26, -0.01, shelf_top), math.radians(5))
selipar(bm, (0.12, 0.012, shelf_top), math.radians(-9))
me = bpy.data.meshes.new("ShoeRack")
bm.to_mesh(me)
bm.free()
for m in (wood("pine_a", (0.145, 0.065, 0.032)), wood("pine_b", (0.16, 0.074, 0.037)), wood("pine_c", (0.125, 0.056, 0.028)),
          wood("batten", (0.2, 0.11, 0.055), raw=True), rubber("sole", (0.03, 0.08, 0.32)), rubber("strap", (0.05, 0.12, 0.38))):
    me.materials.append(m)
rack = bpy.data.objects.new("ShoeRack", me)
bpy.context.scene.collection.objects.link(rack)
me.set_sharp_from_angle(angle=math.radians(50))
common.bake(rack)
common.export("shoe_rack", [rack])

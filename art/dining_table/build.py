"""The dining table: the cheap rubberwood kind, 1.1 m by 0.75 m with its top at 0.76 m, seven glued boards with the
varnish worn pale along the chamfered edge, two mug rings, scuffed feet. On it, as part of the model: a pink plastic
tudung saji (the dome food cover, 0.54 m across, yellowed and dusty) at the -X end, and a tied plastic bag of teh
tarik with a pink raffia loop at the +X end. Run by tools/models.sh.

The table's long side runs along X; its front faces -Y like every model's. The chairs are a model of their own
(dining_chair), placed by the game.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

WIDTH, DEPTH = 1.1, 0.75
TOP = (0.73, 0.76)  # the board's underside and top
APRON = 0.65  # the rails' lower edge
LEG = (0.5, 0.32)  # the legs' centres
RINGS = [(0.12, -0.2, 0.042), (-0.28, 0.285, 0.03)]  # mug rings: x, y, radius
DOME = (-0.25, -0.05)  # the tudung saji's centre
BAG = (0.32, 0.15)  # the teh tarik's
LEVEL = TOP[1] + 0.074  # the tea in the bag, as high as the table's z
TOP_BOARD, LEG_WOOD, RAIL_X, RAIL_Y, SAJI, TEA, RAFFIA = range(7)  # material indices


# --- geometry -------------------------------------------------------------------------------------------

def revolve(bm: bmesh.types.BMesh, profile: list, centre: tuple, segments: int, material: int) -> None:
    """Spins the (radius, height) profile, bottom to top, about the vertical axis at centre = (x, y, z). A radius
    of 0 ends it in a point. Open at the bottom."""
    rings = []
    for r, z in profile:
        if r == 0:
            rings.append([bm.verts.new((centre[0], centre[1], centre[2] + z))])
        else:
            rings.append([bm.verts.new((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a), centre[2] + z))
                          for a in (math.tau * i / segments for i in range(segments))])
    faces = []
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            faces.append(bm.faces.new([a[i], a[j], b[0]] if len(b) == 1 else [a[i], a[j], b[j], b[i]]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for f in faces:
        f.material_index = material
        f.smooth = True


def saji(bm: bmesh.types.BMesh) -> None:
    """The food cover: a low dome with a bead round its rim and a mushroom handle on top."""
    profile = [(0.270, 0.0), (0.270, 0.012), (0.2655, 0.018)]
    for t in (0.0, 0.15, 0.3, 0.45, 0.58, 0.7, 0.8, 0.88, 0.94, 0.98):  # a superellipse: round shoulders, a flat top
        profile.append((0.262 * (1 - t ** 2.4) ** (1 / 2.4), 0.018 + 0.14 * t))
    profile += [(0.04, 0.162), (0.013, 0.162), (0.013, 0.184), (0.027, 0.19), (0.027, 0.197), (0.0, 0.197)]
    revolve(bm, profile, (DOME[0], DOME[1], TOP[1]), 48, SAJI)


# The bag, from its flat base up: (height, half-width along X, half-depth along Y). It bulges where the tea is, gathers
# in to a neck, and ends in the flat ears of the knot.
BAG_STATIONS = [(0.0, 0.04, 0.028), (0.006, 0.05, 0.035), (0.022, 0.056, 0.04), (0.045, 0.055, 0.038), (0.068, 0.046, 0.032),
                (0.088, 0.034, 0.024), (0.102, 0.019, 0.0145), (0.109, 0.0125, 0.0105), (0.116, 0.0135, 0.01), (0.124, 0.024, 0.0065),
                (0.133, 0.03, 0.004), (0.141, 0.022, 0.0025)]
SEGMENTS = 20


def neck(z: float) -> tuple:
    """The bag's half-width and half-depth at height z, between its stations."""
    for (z0, a0, b0), (z1, a1, b1) in zip(BAG_STATIONS, BAG_STATIONS[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            return a0 + (a1 - a0) * t, b0 + (b1 - b0) * t
    raise ValueError(z)


def bag(bm: bmesh.types.BMesh) -> None:
    """A plastic bag of teh tarik, sagging a little to one side, tied at the neck with a band of raffia and a loop
    of it to carry the bag by."""
    start = len(bm.verts)
    ox, oy, oz = BAG[0], BAG[1], TOP[1]
    rings = []
    for z, a, b in BAG_STATIONS:
        pleats = 0.18 * min(1.0, max(0.0, (z - 0.055) / 0.04))  # the gathered plastic puckers towards the neck
        ring = []
        for i in range(SEGMENTS):
            th = math.tau * i / SEGMENTS
            k = 1 + pleats * math.cos(5 * th + 9 * z)
            ring.append(bm.verts.new((ox + a * k * math.cos(th), oy + b * k * math.sin(th), oz + z)))
        rings.append(ring)
    apex = bm.verts.new((ox, oy, oz + BAG_STATIONS[-1][0] + 0.003))
    faces = []
    for a, b in zip(rings, rings[1:]):
        faces += [bm.faces.new([a[i], a[(i + 1) % SEGMENTS], b[(i + 1) % SEGMENTS], b[i]]) for i in range(SEGMENTS)]
    faces += [bm.faces.new([rings[-1][i], rings[-1][(i + 1) % SEGMENTS], apex]) for i in range(SEGMENTS)]
    for f in faces:
        f.material_index = TEA
        f.smooth = True
    # The raffia: a band round the neck, and the loop standing up out of the knot, leaning over.
    band = []
    for z, grow in [(0.099, 0.0015), (0.105, 0.0025), (0.111, 0.0015)]:
        a, b = neck(z)
        band.append([bm.verts.new((ox + (a + grow) * math.cos(th), oy + (b + grow) * math.sin(th), oz + z))
                     for th in (math.tau * i / SEGMENTS for i in range(SEGMENTS))])
    ribbon = []
    for lo, hi in zip(band, band[1:]):
        ribbon += [bm.faces.new([lo[i], lo[(i + 1) % SEGMENTS], hi[(i + 1) % SEGMENTS], hi[i]]) for i in range(SEGMENTS)]
    loop = []
    n, wide, tall = 28, 0.03, 0.05
    for k in range(n):  # a teardrop in the XZ plane, pointed at the knot
        th = -math.pi / 2 + math.tau * k / n
        s = math.sin(th)
        loop.append((wide * ((1 + s) / 2) ** 0.4 * math.cos(th), tall * (1 + s)))
    lean = Matrix.Rotation(math.radians(35), 3, "Y")
    sections = []
    for k, (x, z) in enumerate(loop):
        ahead, behind = loop[(k + 1) % n], loop[k - 1]
        dx, dz = ahead[0] - behind[0], ahead[1] - behind[1]
        nx, nz = -dz / math.hypot(dx, dz), dx / math.hypot(dx, dz)  # across the strip, in its plane
        section = []
        for sw, sy in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
            p = lean @ Vector((x + sw * nx * 0.006, sy * 0.0015, z + sw * nz * 0.006))
            section.append(bm.verts.new((ox + p.x, oy + p.y, oz + 0.11 + p.z)))
        sections.append(section)
    for k, section in enumerate(sections):
        nxt = sections[(k + 1) % n]
        ribbon += [bm.faces.new([section[i], section[(i + 1) % 4], nxt[(i + 1) % 4], nxt[i]]) for i in range(4)]
    bmesh.ops.recalc_face_normals(bm, faces=ribbon)
    for f in ribbon:
        f.material_index = RAFFIA
        f.smooth = True
    bm.verts.ensure_lookup_table()
    bmesh.ops.rotate(bm, verts=bm.verts[start:], cent=(ox, oy, oz), matrix=Matrix.Rotation(math.radians(7), 3, "Y"))


# --- materials ------------------------------------------------------------------------------------------

def saji_material(name: str) -> bpy.types.Material:
    """Pink plastic gone orange with the years, greasy where hands hold it, pale where the rim is scuffed, dusty on top;
    ribbed round its sides."""
    mat, nt, bsdf, coords = common.surface(name)
    flat = common.node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    up = common.mapped(nt, common.node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs["Z"], 0.3, 0.95, 0.0, 1.0)
    local = common.node(nt, "ShaderNodeVectorMath", {0: coords, 1: (DOME[0], DOME[1], TOP[1])}, operation="SUBTRACT").outputs["Vector"]
    parts = common.node(nt, "ShaderNodeSeparateXYZ", {"Vector": local}).outputs
    colour = common.lerp(nt, (0.46, 0.085, 0.13), (0.5, 0.17, 0.1), common.mapped(nt, common.noise(nt, local, 4.0, 3.0), 0.4, 0.7, 0.0, 0.6))
    grease = common.maths(nt, "MAXIMUM", common.mapped(nt, common.noise(nt, local, 9.0, 4.0), 0.58, 0.72, 0.0, 0.55), common.mapped(nt, parts["Z"], 0.16, 0.18, 0.0, 0.6))
    colour = common.lerp(nt, colour, (0.12, 0.04, 0.03), grease)
    scuff = common.maths(nt, "MULTIPLY", common.mapped(nt, parts["Z"], 0.03, 0.01, 0.0, 1.0), common.mapped(nt, common.noise(nt, local, 40.0, 3.0), 0.35, 0.6, 0.2, 1.0))
    colour = common.lerp(nt, colour, (0.7, 0.45, 0.45), common.maths(nt, "MULTIPLY", scuff, 0.8))
    dust = common.maths(nt, "MULTIPLY", up, common.mapped(nt, common.noise(nt, coords, 15.0, 4.0), 0.4, 0.7, 0.1, 0.5))
    colour = common.lerp(nt, colour, (0.3, 0.28, 0.25), dust)
    angle = common.maths(nt, "ARCTAN2", parts["Y"], parts["X"])
    ribs = common.maths(nt, "SINE", common.maths(nt, "MULTIPLY", angle, 24.0))
    bump = common.node(nt, "ShaderNodeBump", {"Strength": 0.2, "Distance": 0.01, "Height": common.maths(nt, "MULTIPLY", ribs, common.mapped(nt, parts["Z"], 0.17, 0.14, 0.0, 1.0))}).outputs["Normal"]
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(common.maths(nt, "ADD", common.maths(nt, "ADD", 0.3, common.maths(nt, "MULTIPLY", dust, 0.7)), common.maths(nt, "MULTIPLY", scuff, 0.3)), bsdf.inputs["Roughness"])
    nt.links.new(bump, bsdf.inputs["Normal"])
    return mat


def tea_material(name: str) -> bpy.types.Material:
    """Milky tea below its level, grubby clear plastic above; wrinkled all over."""
    mat, nt, bsdf, coords = common.surface(name)
    z = common.node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs["Z"]
    liquid = common.mapped(nt, z, LEVEL + 0.003, LEVEL - 0.003, 0.0, 1.0)
    tea = common.lerp(nt, (0.3, 0.115, 0.03), (0.4, 0.17, 0.05), common.noise(nt, coords, 18.0, 3.0))
    foam = common.mapped(nt, common.maths(nt, "ABSOLUTE", common.maths(nt, "SUBTRACT", z, LEVEL - 0.006)), 0.008, 0.0, 0.0, 0.6)
    film = common.lerp(nt, (0.5, 0.5, 0.47), (0.33, 0.34, 0.32), common.noise(nt, coords, 25.0, 3.0))
    colour = common.lerp(nt, common.lerp(nt, film, tea, liquid), (0.55, 0.36, 0.2), common.maths(nt, "MULTIPLY", foam, liquid))
    bump = common.node(nt, "ShaderNodeBump", {"Strength": 0.5, "Distance": 0.004, "Height": common.noise(nt, coords, 90.0, 4.0)}).outputs["Normal"]
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(common.mapped(nt, liquid, 0.0, 1.0, 0.12, 0.25), bsdf.inputs["Roughness"])
    nt.links.new(bump, bsdf.inputs["Normal"])
    return mat


def raffia_material(name: str) -> bpy.types.Material:
    """Pink raffia, sun-bleached and fibrous."""
    mat, nt, bsdf, coords = common.surface(name)
    fibres = common.noise(nt, coords, 400.0, 3.0)
    nt.links.new(common.lerp(nt, (0.79, 0.1, 0.21), (0.6, 0.2, 0.25), common.mapped(nt, fibres, 0.35, 0.65, 0.0, 1.0)), bsdf.inputs["Base Color"])
    nt.links.new(common.mapped(nt, fibres, 0.3, 0.7, 0.5, 0.8), bsdf.inputs["Roughness"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
bm = bmesh.new()
common.slab(bm, (0.0, 0.0), (WIDTH, DEPTH), TOP[0], TOP[1], 0.03, 0.005, TOP_BOARD)
for sx in (-1, 1):
    for sy in (-1, 1):
        x, y = sx * LEG[0], sy * LEG[1]
        common.box(bm, (x, y, (APRON + TOP[0]) / 2), (0.05, 0.05, TOP[0] - APRON), LEG_WOOD)
        common.post(bm, 0.0, APRON, (x, y, 0.034, 0.034), (x, y, 0.05, 0.05), LEG_WOOD)
for sy in (-1, 1):  # the rails sit back a few millimetres from the legs' faces
    common.box(bm, (0.0, sy * (LEG[1] + 0.011), (APRON + TOP[0]) / 2), (2 * LEG[0] - 0.03, 0.02, TOP[0] - APRON), RAIL_X)
for sx in (-1, 1):
    common.box(bm, (sx * (LEG[0] + 0.011), 0.0, (APRON + TOP[0]) / 2), (0.02, 2 * LEG[1] - 0.03, TOP[0] - APRON), RAIL_Y)
saji(bm)
bag(bm)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99], context="FACES")  # undersides and feet: nobody sees them
me = bpy.data.meshes.new("DiningTable")
bm.to_mesh(me)
bm.free()
boards = (-DEPTH / 2, DEPTH / 7)
stain = (0.14, 0.066, 0.032)
for m in (common.wood("top", stain, 0, boards, RINGS), common.wood("leg", (0.125, 0.056, 0.027), 2), common.wood("rail_x", (0.135, 0.06, 0.029), 0),
          common.wood("rail_y", (0.135, 0.06, 0.029), 1), saji_material("saji"), tea_material("tea"), raffia_material("raffia")):
    me.materials.append(m)
table = bpy.data.objects.new("DiningTable", me)
bpy.context.scene.collection.objects.link(table)
me.set_sharp_from_angle(angle=math.radians(50))
common.bake(table, pack=True)
common.export("dining_table", [table])

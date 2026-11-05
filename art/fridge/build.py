"""The kitchen's fridge: an old two-door top-freezer, 0.7 m wide and deep and 1.8 m tall, its off-white enamel gone
faintly yellow, with a small freezer door over a big one and a recessed handle scooped into each, down the edge away
from the hinges. A grey rubber seal runs round both doors, a dark grille under them. The enamel is yellowest at the top,
greasy and fingerprinted round the handles, scuffed and rusting at the bottom and dented here and there. Three things
are stuck on the freezer door round the management notice's place: a kedai runcit's magnet, a takeaway menu held up by
two round magnets, and a magnet calendar (made-up shop, no brand). Run by tools/models.sh.

The origin is the centre of the floor footprint; the front faces -Y like every model's. Left out, because nobody sees
them: the back and the underside (against the wall and the floor) and the hinge-side wall of the cabinet (2.5 cm from the
kitchen's north wall once the fridge is turned). It is drawn in the fridge's own axes (x across, y up, z out of the
front) and turned to Blender's at the end.

The doors' flat face is at FACE. The management notice (an Interactable box centred at x = 0.77, 2 cm thick) hangs
on it: once the fridge stands at x = 0.4 turned a quarter its face is at x = 0.758, 2 mm behind the notice's back.
Nothing stands out of the face where the notice is (tests/integration/test_models.gd checks it with rays).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

node, mapped, maths, lerp, noise, between = common.node, common.mapped, common.maths, common.lerp, common.noise, common.between

HALF = 0.35  # half the cabinet's width
BACK, SIDE_FRONT = -0.35, 0.30  # the cabinet's back, and where its sides end at the seals
SEAL, FACE = 0.322, 0.358  # the seals' front, and the doors' flat front
DOOR_BACK = 0.312  # the doors' edges end against the seals
TOP, PLINTH = 1.80, 0.076
LINE, GAP = 1.12, 0.010  # the freezer line, and the gap there between the doors
DOOR_HALF = 0.346
FRIDGE = (0.08, LINE - GAP / 2)  # each door's y range
FREEZER = (LINE + GAP / 2, 1.79)
R = 0.014  # the doors' edge radius
LIP, DEEP = 0.008, 0.026  # a handle recess: its sloped rim, and how deep it is scooped
POCKET_X = (-0.305, -0.255)  # the recesses' floors, across; and up, door by door
POCKETS = [(FRIDGE, (0.56, 1.00)), (FREEZER, (1.21, 1.50))]
SHOP = (0.235, 1.675, 0.082, 0.052)  # the cards on the freezer door: centre x, centre y, width, height
MENU = (0.22, 1.40, 0.115, 0.16)
CALENDAR = (-0.07, 1.665, 0.075, 0.105)
DISCS = [(MENU[0] - 0.04, MENU[1] + MENU[3] / 2 - 0.012), (MENU[0] + 0.04, MENU[1] + MENU[3] / 2 - 0.012)]  # the menu's two round magnets
ENAMEL, SEAL_MAT, GRILLE, HINGE, SHOP_MAT, MENU_MAT, CALENDAR_MAT, DISC = range(8)  # material indices


# --- geometry -------------------------------------------------------------------------------------------

def face(bm: bmesh.types.BMesh, verts: list, outward: tuple, material: int, smooth: bool = False) -> None:
    """A face through the (new or existing) verts, turned to look along outward."""
    f = bm.faces.new([v if isinstance(v, bmesh.types.BMVert) else bm.verts.new(v) for v in verts])
    f.normal_update()
    if f.normal.dot(Vector(outward)) < 0:
        f.normal_flip()
    f.material_index = material
    f.smooth = smooth


FILLET = [R * (1 - math.cos(math.radians(a))) for a in (0, 22.5, 45, 67.5, 90)]  # how far in from the edge each step of the rounding is


def lines(lo: float, hi: float, extra: list) -> list:
    """The grid lines across a door from lo to hi: the rounded edge's steps at each end, and the extra ones."""
    return sorted({round(v, 6) for v in [lo + u for u in FILLET] + [hi - u for u in FILLET] + extra})


def door(bm: bmesh.types.BMesh, span: tuple, pocket: tuple) -> None:
    """One door: its front a grid of heights, flat at FACE, rounded off at the edge all round, with the recessed handle
    scooped into it (a flat floor, a sloped rim); its edges run back to the seals."""
    y0, y1 = span
    xs = lines(-DOOR_HALF, DOOR_HALF, [POCKET_X[0] - LIP, POCKET_X[0], POCKET_X[1], POCKET_X[1] + LIP])
    ys = lines(y0, y1, [pocket[0] - LIP, pocket[0], pocket[1], pocket[1] + LIP])

    def z(x: float, y: float) -> float:
        edge = min(x + DOOR_HALF, DOOR_HALF - x, y - y0, y1 - y)
        drop = R - math.sqrt(max(R * R - (R - min(edge, R)) ** 2, 0.0))
        away = max(POCKET_X[0] - x, x - POCKET_X[1], pocket[0] - y, y - pocket[1], 0.0)
        return FACE - drop - DEEP * (1 - min(away / LIP, 1.0))

    grid = [[bm.verts.new((x, y, z(x, y))) for y in ys] for x in xs]
    nx, ny = len(xs), len(ys)
    for i in range(nx - 1):
        for j in range(ny - 1):
            face(bm, [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]], (0, 0, 1), ENAMEL, True)
    for i in range(nx - 1):  # bottom and top edges
        for j, out in ((0, -1), (ny - 1, 1)):
            a, b = grid[i][j], grid[i + 1][j]
            face(bm, [a, b, (b.co.x, b.co.y, DOOR_BACK), (a.co.x, a.co.y, DOOR_BACK)], (0, out, 0), ENAMEL, True)
    for j in range(ny - 1):  # left and right edges
        for i, out in ((0, -1), (nx - 1, 1)):
            a, b = grid[i][j], grid[i][j + 1]
            face(bm, [a, b, (b.co.x, b.co.y, DOOR_BACK), (a.co.x, a.co.y, DOOR_BACK)], (out, 0, 0), ENAMEL, True)


def seals(bm: bmesh.types.BMesh) -> None:
    """The rubber seals: a frame at the cabinet's front, behind both doors, showing as a rim round each and in the gap
    between them, with its outer edge running back to the cabinet."""
    xs = [-HALF, -DOOR_HALF + 0.003, DOOR_HALF - 0.003, HALF]
    ys = [PLINTH, FRIDGE[0] + 0.004, FRIDGE[1] - 0.004, FREEZER[0] + 0.004, FREEZER[1] - 0.004, TOP]
    grid = [[bm.verts.new((x, y, SEAL)) for y in ys] for x in xs]
    for i in range(3):
        for j in range(5):
            if (i, j) not in ((1, 1), (1, 3)):  # the doors cover these
                face(bm, [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]], (0, 0, 1), SEAL_MAT)
    for x, out in ((-HALF, -1), (HALF, 1)):
        face(bm, [(x, PLINTH, SEAL), (x, TOP, SEAL), (x, TOP, SIDE_FRONT), (x, PLINTH, SIDE_FRONT)], (out, 0, 0), SEAL_MAT)
    for y, out in ((PLINTH, -1), (TOP, 1)):
        face(bm, [(-HALF, y, SEAL), (HALF, y, SEAL), (HALF, y, SIDE_FRONT), (-HALF, y, SIDE_FRONT)], (0, out, 0), SEAL_MAT)


def cabinet(bm: bmesh.types.BMesh) -> None:
    """The cabinet's wall on the handle side and its top, and the grille under the doors, set back from the front and the sides."""
    face(bm, [(-HALF, PLINTH, BACK), (-HALF, TOP, BACK), (-HALF, TOP, SIDE_FRONT), (-HALF, PLINTH, SIDE_FRONT)], (-1, 0, 0), ENAMEL)
    face(bm, [(-HALF, TOP, BACK), (HALF, TOP, BACK), (HALF, TOP, SIDE_FRONT), (-HALF, TOP, SIDE_FRONT)], (0, 1, 0), ENAMEL)
    face(bm, [(-0.33, 0.0, 0.28), (0.33, 0.0, 0.28), (0.33, PLINTH, 0.28), (-0.33, PLINTH, 0.28)], (0, 0, 1), GRILLE)
    for x, out in ((-0.33, -1), (0.33, 1)):
        face(bm, [(x, 0.0, BACK + 0.02), (x, PLINTH, BACK + 0.02), (x, PLINTH, 0.28), (x, 0.0, 0.28)], (out, 0, 0), GRILLE)


def hinges(bm: bmesh.types.BMesh) -> None:
    """The plastic hinge cap on the top and the hinge between the doors, both on the side away from the handles."""
    common.chamfered_box(bm, (0.28, TOP + 0.006, 0.26), (0.07, 0.012, 0.07), 0.003, HINGE)
    common.chamfered_box(bm, (0.29, LINE, 0.332), (0.07, 0.034, 0.036), 0.003, HINGE)


def card(bm: bmesh.types.BMesh, spec: tuple, thickness: float, lift: float, radius: float, material: int, sag: float = 0.0) -> None:
    """A card on the freezer door, lifted lift off the face; sag: how far its lower edge stands off it (paper hung by its top)."""
    x, y, w, h = spec
    start = len(bm.verts)
    common.slab(bm, (x, y), (w, h), FACE + lift, FACE + lift + thickness, radius, min(0.0006, radius / 3), material)
    if sag:
        bm.verts.ensure_lookup_table()
        bmesh.ops.rotate(bm, verts=bm.verts[start:], cent=(x, y + h / 2, FACE), matrix=Matrix.Rotation(-math.atan(sag / h), 3, "X"))


def discs(bm: bmesh.types.BMesh) -> None:
    for x, y in DISCS:
        common.revolve(bm, [(0.0105, 0.0), (0.0105, 0.0036), (0.0095, 0.0043), (0.0, 0.0043)], (x, y, FACE + 0.0016), 14, DISC)


def build() -> bpy.types.Object:
    bm = bmesh.new()
    for span, pocket in POCKETS:
        door(bm, span, pocket)
    seals(bm)
    cabinet(bm)
    hinges(bm)
    card(bm, SHOP, 0.004, 0.0, 0.004, SHOP_MAT)
    card(bm, CALENDAR, 0.003, 0.0, 0.002, CALENDAR_MAT)
    card(bm, MENU, 0.0012, 0.0006, 0.0012, MENU_MAT, sag=0.003)
    discs(bm)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))  # z out of the front -> -Y
    me = bpy.data.meshes.new("Fridge")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Fridge", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- materials ------------------------------------------------------------------------------------------
# The coordinates a material reads are the object's, after the turn to Blender's axes: x across, y backwards (the front
# at -FACE), z up.

def letters(nt: bpy.types.NodeTree, u: bpy.types.NodeSocket, v: bpy.types.NodeSocket, span: tuple, cell: float, seed: float, fill: float = 0.75) -> bpy.types.NodeSocket:
    """A line of print too small to read: span = (u0, u1, v0, v1) in the card's own axes, one block per cell wide, some of
    them gaps, some with a slot cut across: what a menu or a shop's sign looks like from two metres."""
    u0, u1, v0, v1 = span
    along = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", u, u0), cell)
    index = maths(nt, "ADD", maths(nt, "FLOOR", along), seed)
    inside = maths(nt, "MULTIPLY", between(nt, u, u0, u1, 0.0002), between(nt, v, v0, v1, 0.0002))
    stroke = between(nt, maths(nt, "FRACT", along), 0.15, 0.85, 0.12)
    present = mapped(nt, node(nt, "ShaderNodeTexWhiteNoise", {"W": index}, noise_dimensions="1D").outputs["Value"], fill, fill + 0.001, 1.0, 0.0)
    slot = mapped(nt, node(nt, "ShaderNodeTexWhiteNoise", {"W": maths(nt, "ADD", index, 57.0)}, noise_dimensions="1D").outputs["Value"], 0.5, 0.501, 1.0, 0.0)
    across = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", v, v0), v1 - v0)
    cut = maths(nt, "MULTIPLY", slot, between(nt, across, 0.38, 0.62, 0.05))
    return maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", inside, stroke), maths(nt, "MULTIPLY", present, maths(nt, "SUBTRACT", 1.0, cut)))


def rect(nt: bpy.types.NodeTree, u: bpy.types.NodeSocket, v: bpy.types.NodeSocket, span: tuple) -> bpy.types.NodeSocket:
    """1 inside the rectangle span = (u0, u1, v0, v1), a hair of softness at its edge."""
    return maths(nt, "MULTIPLY", between(nt, u, span[0], span[1], 0.0003), between(nt, v, span[2], span[3], 0.0003))


def enamel(name: str) -> bpy.types.Material:
    """Off-white enamel gone faintly yellow: more so up the fridge and in low, soft patches. Greasy and fingerprinted round
    the two handle recesses, dust on top, grime streaking down the lower part with rust at the bottom, pale scuffs on the
    sharp edges, dark in the crevices; the sheet is faintly wavy, with a few dents."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    normal = node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs
    bevelled = node(nt, "ShaderNodeBevel", {"Radius": 0.002}, samples=8).outputs["Normal"]
    height = xyz["Z"]
    front = mapped(nt, xyz["Y"], -0.305, -0.312, 0.0, 1.0)  # the doors' faces and edges, not the cabinet's sides
    age = mapped(nt, maths(nt, "ADD", mapped(nt, height, 0.2, 1.8, 0.1, 0.6), maths(nt, "MULTIPLY", mapped(nt, noise(nt, coords, 2.5, 3.0), 0.35, 0.65, 0.0, 1.0), 0.4)), 0.0, 1.0, 0.0, 1.0)
    colour = lerp(nt, (0.54, 0.51, 0.42), (0.5, 0.41, 0.24), age)
    edge = mapped(nt, node(nt, "ShaderNodeVectorMath", {0: bevelled, 1: flat}, operation="DOT_PRODUCT").outputs["Value"], 1.0, 0.85, 0.0, 1.0)
    colour = lerp(nt, colour, (0.78, 0.74, 0.64), maths(nt, "MULTIPLY", edge, mapped(nt, noise(nt, coords, 90.0, 3.0), 0.35, 0.6, 0.2, 0.8)))

    # Hands: grease round each handle recess, thickest in it and at the lip, and fingerprints on the door beside it.
    near = None
    for span, (p0, p1) in POCKETS:
        dx = maths(nt, "MAXIMUM", maths(nt, "SUBTRACT", maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", xyz["X"], sum(POCKET_X) / 2)), (POCKET_X[1] - POCKET_X[0]) / 2 + LIP), 0.0)
        dz = maths(nt, "MAXIMUM", maths(nt, "SUBTRACT", maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", height, (p0 + p1) / 2)), (p1 - p0) / 2 + LIP), 0.0)
        d = node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": dx, "Y": dz}).outputs["Vector"]}, operation="LENGTH").outputs["Value"]
        near = d if near is None else maths(nt, "MINIMUM", near, d)
    halo = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", front, mapped(nt, near, 0.18, 0.0, 0.0, 1.0)), mapped(nt, noise(nt, coords, 7.0, 4.0), 0.3, 0.7, 0.4, 1.0))
    colour = lerp(nt, colour, (0.34, 0.28, 0.18), maths(nt, "MULTIPLY", halo, 0.7))
    cells = node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": (30.0, 30.0, 21.0)}).outputs["Vector"]  # fingertip-sized cells, taller than wide
    voronoi = node(nt, "ShaderNodeTexVoronoi", {"Vector": cells, "Scale": 1.0}, voronoi_dimensions="3D", feature="F1")
    chance = node(nt, "ShaderNodeTexWhiteNoise", {"Vector": voronoi.outputs["Position"]}, noise_dimensions="3D").outputs["Value"]
    touched = maths(nt, "MULTIPLY", front, mapped(nt, near, 0.14, 0.0, 0.0, 0.75))
    prints = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", mapped(nt, maths(nt, "SUBTRACT", chance, touched), 0.0, 0.15, 1.0, 0.0), mapped(nt, touched, 0.0, 0.05, 0.0, 1.0)),
                   mapped(nt, voronoi.outputs["Distance"], 0.5, 0.25, 0.0, 1.0))  # a cell is printed when its chance is under how touched the place is
    colour = lerp(nt, colour, (0.3, 0.25, 0.16), maths(nt, "MULTIPLY", prints, 0.4))

    # Above, brown runs of grease and steam down the sheet; below, kicked, splashed and rusting. Dust on top.
    runs = node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": (50.0, 50.0, 2.5)}).outputs["Vector"]
    drips = maths(nt, "MULTIPLY", mapped(nt, noise(nt, runs, 1.0, 3.0), 0.55, 0.75, 0.0, 1.0), mapped(nt, height, 0.9, 1.8, 0.0, 1.0))
    colour = lerp(nt, colour, (0.34, 0.25, 0.12), maths(nt, "MULTIPLY", drips, 0.5))
    colour = lerp(nt, colour, tuple(c * 0.8 for c in (0.5, 0.45, 0.33)), mapped(nt, noise(nt, coords, 1.6, 3.0), 0.5, 0.7, 0.0, 0.5))  # old dirt, darker in broad low patches
    low = maths(nt, "MULTIPLY", mapped(nt, height, 0.32, 0.0, 0.0, 1.0), mapped(nt, noise(nt, runs, 1.0, 3.0), 0.4, 0.7, 0.35, 1.0))
    colour = lerp(nt, colour, (0.3, 0.26, 0.19), maths(nt, "MULTIPLY", low, 0.6))
    rust = maths(nt, "MULTIPLY", mapped(nt, height, 0.14, 0.0, 0.0, 1.0), mapped(nt, noise(nt, coords, 22.0, 4.0), 0.45, 0.62, 0.0, 1.0))
    colour = lerp(nt, colour, (0.3, 0.13, 0.05), maths(nt, "MULTIPLY", rust, 0.7))
    dust = maths(nt, "MULTIPLY", mapped(nt, normal["Z"], 0.6, 0.95, 0.0, 1.0), mapped(nt, noise(nt, coords, 30.0, 3.0), 0.35, 0.65, 0.4, 0.9))
    colour = lerp(nt, colour, (0.33, 0.31, 0.27), dust)
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.03}, samples=16, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.2, 0.18, 0.14), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    rough = maths(nt, "ADD", 0.28, maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", halo, low), maths(nt, "MAXIMUM", dust, maths(nt, "MAXIMUM", rust, drips))), 0.35))

    # The sheet: waves too faint to see in the shape, and a few dents (a door kicked shut, the cabinet knocked by the gas man).
    height_map = maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", noise(nt, coords, 5.0, 2.0), 0.5), 0.25)
    for cx, cy, cz, radius in ((0.2, -FACE, 0.2, 0.035), (-0.05, -FACE, 0.45, 0.03), (-HALF, 0.0, 1.0, 0.05), (-HALF, -0.2, 0.55, 0.04)):
        away = node(nt, "ShaderNodeVectorMath", {0: coords, 1: (cx, cy, cz)}, operation="DISTANCE").outputs["Value"]
        height_map = maths(nt, "SUBTRACT", height_map, mapped(nt, away, radius, 0.0, 0.0, 1.0))
    bump = node(nt, "ShaderNodeBump", {"Strength": 0.7, "Distance": 0.003, "Height": height_map, "Normal": bevelled}).outputs["Normal"]
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    nt.links.new(bump, bsdf.inputs["Normal"])
    return mat


def seal_rubber(name: str) -> bpy.types.Material:
    """Grey rubber, dirtier in the gap and dusty on top."""
    mat, nt, bsdf, coords = common.surface(name)
    up = mapped(nt, node(nt, "ShaderNodeSeparateXYZ", {"Vector": node(nt, "ShaderNodeNewGeometry").outputs["Normal"]}).outputs["Z"], 0.5, 0.95, 0.0, 1.0)
    colour = lerp(nt, (0.2, 0.205, 0.2), (0.12, 0.115, 0.1), mapped(nt, noise(nt, coords, 30.0, 4.0), 0.35, 0.65, 0.0, 1.0))
    colour = lerp(nt, colour, (0.3, 0.28, 0.24), maths(nt, "MULTIPLY", up, 0.5))
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.012}, samples=16, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.05, 0.05, 0.05), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, noise(nt, coords, 60.0, 3.0), 0.3, 0.7, 0.55, 0.8), bsdf.inputs["Roughness"])
    return mat


def grille(name: str) -> bpy.types.Material:
    """The dark plastic under the doors: slots across it, grey with dust, scuffed pale where feet and brooms reach it."""
    mat, nt, bsdf, coords = common.surface(name)
    z = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs["Z"]
    slots = between(nt, maths(nt, "FRACT", maths(nt, "DIVIDE", z, 0.0115)), 0.3, 0.75, 0.06)
    colour = lerp(nt, (0.05, 0.048, 0.045), (0.13, 0.12, 0.105), mapped(nt, noise(nt, coords, 25.0, 4.0), 0.35, 0.65, 0.0, 1.0))
    scuffs = maths(nt, "MULTIPLY", mapped(nt, noise(nt, coords, 70.0, 3.0), 0.5, 0.7, 0.0, 1.0), mapped(nt, z, 0.06, 0.0, 0.0, 1.0))
    colour = lerp(nt, colour, (0.3, 0.28, 0.24), maths(nt, "MULTIPLY", scuffs, 0.6))
    colour = lerp(nt, colour, (0.012, 0.011, 0.01), maths(nt, "MULTIPLY", slots, 0.9))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(maths(nt, "ADD", 0.5, maths(nt, "MULTIPLY", scuffs, 0.3)), bsdf.inputs["Roughness"])
    return mat


def hinge_plastic(name: str) -> bpy.types.Material:
    """Beige-grey plastic, yellowed like the enamel, dusty on top."""
    mat, nt, bsdf, coords = common.surface(name)
    up = mapped(nt, node(nt, "ShaderNodeSeparateXYZ", {"Vector": node(nt, "ShaderNodeNewGeometry").outputs["Normal"]}).outputs["Z"], 0.4, 0.95, 0.0, 1.0)
    colour = lerp(nt, (0.36, 0.33, 0.26), (0.46, 0.41, 0.3), mapped(nt, noise(nt, coords, 25.0, 4.0), 0.35, 0.65, 0.0, 1.0))
    colour = lerp(nt, colour, (0.3, 0.28, 0.25), maths(nt, "MULTIPLY", up, 0.6))
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.015}, samples=16, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.14, 0.13, 0.1), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, noise(nt, coords, 50.0, 3.0), 0.3, 0.7, 0.4, 0.65), bsdf.inputs["Roughness"])
    return mat


def printed(name: str, centre: tuple, art) -> bpy.types.Material:
    """A printed card on the door. art(nt, coords, u, v) returns the print's colour and the colour of the card's edge, in the
    card's axes (u across, v up, from its centre). The print is faded and greasy."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    u = maths(nt, "SUBTRACT", xyz["X"], centre[0])
    v = maths(nt, "SUBTRACT", xyz["Z"], centre[1])
    colour, edge = art(nt, coords, u, v)
    facing = mapped(nt, node(nt, "ShaderNodeSeparateXYZ", {"Vector": node(nt, "ShaderNodeNewGeometry").outputs["Normal"]}).outputs["Y"], -0.7, -0.95, 0.0, 1.0)
    colour = lerp(nt, edge, colour, facing)
    colour = lerp(nt, colour, (0.42, 0.37, 0.25), maths(nt, "MULTIPLY", mapped(nt, noise(nt, coords, 60.0, 3.0), 0.4, 0.7, 0.0, 0.35), facing))  # faded, greasy
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, noise(nt, coords, 90.0, 3.0), 0.3, 0.7, 0.35, 0.6), bsdf.inputs["Roughness"])
    return mat


def shop_art(nt: bpy.types.NodeTree, coords: bpy.types.NodeSocket, u: bpy.types.NodeSocket, v: bpy.types.NodeSocket) -> tuple:
    """A kedai runcit's magnet: a yellow card with a red band of print on top, a striped awning over a little shopfront
    and three lines of print beside it."""
    colour = lerp(nt, (0.6, 0.4, 0.03), (0.74, 0.52, 0.05), mapped(nt, noise(nt, coords, 20.0, 3.0), 0.3, 0.7, 0.0, 1.0))
    colour = lerp(nt, colour, (0.38, 0.03, 0.025), rect(nt, u, v, (-0.041, 0.041, 0.012, 0.026)))
    colour = lerp(nt, colour, (0.8, 0.74, 0.56), letters(nt, u, v, (-0.035, 0.035, 0.0155, 0.0225), 0.0058, 3.0, 0.85))
    stripes = mapped(nt, maths(nt, "FRACT", maths(nt, "DIVIDE", u, 0.0064)), 0.49, 0.5, 0.0, 1.0)
    colour = lerp(nt, colour, lerp(nt, (0.4, 0.03, 0.025), (0.8, 0.74, 0.56), stripes), rect(nt, u, v, (-0.036, -0.004, 0.0, 0.008)))
    colour = lerp(nt, colour, (0.25, 0.08, 0.04), rect(nt, u, v, (-0.034, -0.006, -0.02, 0.0)))
    colour = lerp(nt, colour, (0.78, 0.7, 0.5), maths(nt, "ADD", rect(nt, u, v, (-0.022, -0.014, -0.02, -0.004)), rect(nt, u, v, (-0.012, -0.008, -0.014, -0.006))))
    ink = (0.12, 0.06, 0.02)
    for span, seed in (((0.002, 0.037, 0.0035, 0.0075), 11.0), ((0.002, 0.033, -0.0045, -0.0005), 23.0), ((0.002, 0.029, -0.0125, -0.0085), 37.0)):
        colour = lerp(nt, colour, ink, letters(nt, u, v, span, 0.0035, seed, 0.8))
    colour = lerp(nt, colour, ink, letters(nt, u, v, (-0.036, 0.036, -0.0235, -0.0195), 0.004, 41.0, 0.85))
    return colour, (0.09, 0.08, 0.07)


def menu_art(nt: bpy.types.NodeTree, coords: bpy.types.NodeSocket, u: bpy.types.NodeSocket, v: bpy.types.NodeSocket) -> tuple:
    """A takeaway menu: cream paper folded in two, a red title band, a photo of a dish and rows of dishes and prices."""
    paper = lerp(nt, (0.74, 0.7, 0.54), (0.64, 0.58, 0.4), mapped(nt, noise(nt, coords, 12.0, 3.0), 0.3, 0.7, 0.0, 1.0))
    colour = lerp(nt, paper, (0.45, 0.4, 0.28), mapped(nt, maths(nt, "ABSOLUTE", v), 0.0015, 0.0, 0.0, 0.7))  # the fold
    colour = lerp(nt, colour, (0.42, 0.04, 0.03), rect(nt, u, v, (-0.054, 0.054, 0.056, 0.077)))
    colour = lerp(nt, colour, (0.82, 0.78, 0.62), letters(nt, u, v, (-0.045, 0.045, 0.0605, 0.0725), 0.0055, 5.0, 0.8))
    photo = lerp(nt, (0.42, 0.2, 0.05), (0.7, 0.4, 0.1), mapped(nt, noise(nt, coords, 80.0, 3.0), 0.3, 0.7, 0.0, 1.0))
    plate = mapped(nt, node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": u, "Y": v}).outputs["Vector"], 1: (-0.008, 0.026, 0.0)}, operation="DISTANCE").outputs["Value"], 0.02, 0.016, 0.0, 1.0)
    photo = lerp(nt, photo, (0.78, 0.72, 0.55), plate)
    photo = lerp(nt, photo, (0.35, 0.14, 0.04), mapped(nt, node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": u, "Y": v}).outputs["Vector"], 1: (-0.008, 0.026, 0.0)}, operation="DISTANCE").outputs["Value"], 0.013, 0.01, 0.0, 1.0))
    colour = lerp(nt, colour, photo, rect(nt, u, v, (-0.05, 0.05, 0.002, 0.05)))
    ink = (0.14, 0.1, 0.06)
    for k in range(5):
        top = -0.01 - 0.0125 * k
        colour = lerp(nt, colour, ink, letters(nt, u, v, (-0.05, 0.012, top - 0.0065, top), 0.0042, 70.0 + 13 * k, 0.78))
        colour = lerp(nt, colour, ink, letters(nt, u, v, (0.03, 0.05, top - 0.0065, top), 0.0042, 90.0 + 7 * k, 0.9))
    return colour, (0.7, 0.66, 0.5)


def calendar_art(nt: bpy.types.NodeTree, coords: bpy.types.NodeSocket, u: bpy.types.NodeSocket, v: bpy.types.NodeSocket) -> tuple:
    """A magnet calendar: a landscape over a month of numbers, the Sundays in red."""
    colour = (0.66, 0.64, 0.55)
    sky = lerp(nt, (0.55, 0.45, 0.2), (0.06, 0.28, 0.3), mapped(nt, v, 0.012, 0.05, 0.0, 1.0))
    horizon = maths(nt, "ADD", 0.024, maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", noise(nt, coords, 40.0, 3.0), 0.5), 0.02))
    land = mapped(nt, maths(nt, "SUBTRACT", v, horizon), 0.001, -0.001, 0.0, 1.0)
    picture = lerp(nt, sky, (0.05, 0.14, 0.1), land)
    colour = lerp(nt, colour, picture, rect(nt, u, v, (-0.034, 0.034, 0.012, 0.05)))
    colour = lerp(nt, colour, (0.45, 0.04, 0.03), letters(nt, u, v, (-0.034, 0.034, -0.001, 0.0075), 0.0075, 3.0, 0.85))
    for k in range(6):
        top = -0.011 - 0.0072 * k
        ink = lerp(nt, (0.12, 0.1, 0.08), (0.5, 0.05, 0.04), mapped(nt, u, -0.024, -0.025, 0.0, 1.0))  # the first column: Sundays
        colour = lerp(nt, colour, ink, letters(nt, u, v, (-0.034, 0.034, top - 0.0048, top), 0.0097, 120.0 + 9 * k, 0.92))
    return colour, (0.55, 0.53, 0.45)


def round_magnet(name: str) -> bpy.types.Material:
    """The menu's two round magnets, a maroon one and a green one, dull and greasy."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    colour = lerp(nt, (0.22, 0.025, 0.025), (0.04, 0.2, 0.07), mapped(nt, xyz["X"], DISCS[0][0] + 0.02, DISCS[1][0] - 0.02, 0.0, 1.0))
    colour = lerp(nt, colour, (0.4, 0.34, 0.24), mapped(nt, noise(nt, coords, 150.0, 3.0), 0.5, 0.7, 0.0, 0.4))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, noise(nt, coords, 100.0, 3.0), 0.3, 0.7, 0.3, 0.55), bsdf.inputs["Roughness"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
fridge = build()
me = fridge.data
for m in (enamel("enamel"), seal_rubber("seal"), grille("grille"), hinge_plastic("hinge"), printed("shop", SHOP, shop_art),
          printed("menu", MENU, menu_art), printed("calendar", CALENDAR, calendar_art), round_magnet("magnets")):
    me.materials.append(m)
me.set_sharp_from_angle(angle=math.radians(50))
lo = Vector((min(v.co[i] for v in me.vertices) for i in range(3)))
hi = Vector((max(v.co[i] for v in me.vertices) for i in range(3)))
assert abs(lo.y + 0.364) < 0.002 and abs(hi.y - 0.35) < 0.002, (lo, hi)  # the front is -Y: the doors' face and the magnets on it, and the back
assert abs(lo.z) < 1e-6 and 1.8 <= hi.z < 1.82 and abs(lo.x + HALF) < 1e-6 and abs(hi.x - HALF) < 1e-6, (lo, hi)
common.bake(fridge, size=512, pack=True, grow={SHOP_MAT: 2.2, MENU_MAT: 2.2, CALENDAR_MAT: 2.2, DISC: 1.5})
common.export("fridge", [fridge])

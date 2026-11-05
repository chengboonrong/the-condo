"""The bathroom's pedestal basin: cheap white sanitaryware, 0.48 m wide with its rim at 0.93 m, yellowed and grubby,
a ring of limescale at the old waterline, a rust-brown stain round the drain and a chip out of the front rim. A
chrome pillar tap with a cross handle stands on the back deck, its spout curving forward over the bowl, scaled and
tarnished. Above it, as part of the model: a glass shelf on two chrome clamps at 1.17 m, a teal plastic cup on it
and one red toothbrush leaning in the cup. Run by tools/models.sh.

The origin is the floor centre of the pedestal. The front faces -Y like every model's; the wall is at +Y, 0.205 m
behind the origin, so placed with its front facing away from the wall the basin stands flush against it. The
stream that runs from the spout is a model of its own (tap_water), placed at SPOUT.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

node, mapped, maths, lerp, noise = common.node, common.mapped, common.maths, common.lerp, common.noise

HALF = 0.24  # half the basin's width
FRONT, BACK = -0.18, 0.205  # the basin's front, and its back against the wall
RIM = 0.93
FLOOR = 0.82  # the bowl's floor
DRAIN = (0.0, 0.04)
TAP_Y = 0.176  # the pillar, on the deck behind the bowl
SPOUT = (0.0, 0.06, 0.964)  # where the water leaves the spout: tap_water's origin, in this model's axes
SHELF = 1.17  # the glass's top
CUP = (0.17, 0.16)
OUT, BOWL, CHROME, GLASS, PLASTIC, HANDLE, BRISTLES = range(7)  # material indices

# The basin's shell from its underside up over the rim and down into the bowl: (height, inset at the sides, at the
# front, at the back). The back stays flush with the wall all the way up the outside.
SHELL = [(0.775, 0.075, 0.065, 0.0), (0.81, 0.04, 0.032, 0.0), (0.87, 0.012, 0.012, 0.0), (0.922, 0.0, 0.0, 0.0), (0.93, 0.004, 0.004, 0.0),
         (0.93, 0.03, 0.03, 0.05), (0.9255, 0.0335, 0.0335, 0.0535), (0.912, 0.0365, 0.0365, 0.0565), (0.87, 0.05, 0.05, 0.07),
         (0.83, 0.09, 0.08, 0.1), (FLOOR, 0.14, 0.13, 0.105)]
OUTSIDE = 4  # the rings below this index (and the band that ends on it) are the basin's outside


# --- geometry -------------------------------------------------------------------------------------------

def plan(x: tuple, y: tuple, front: float, back: float, k: int = 6) -> list:
    """A rounded rectangle seen from above, counter-clockwise from the front edge: x and y its extents, front and
    back the corner radii (cut down to fit), k segments to a corner."""
    hw, h = (x[1] - x[0]) / 2, y[1] - y[0]
    rf = min(front, 0.95 * hw, 0.7 * h)
    rb = min(back, 0.95 * hw, 0.95 * h - rf)
    corners = [(x[1] - rf, y[0] + rf, rf, -90), (x[1] - rb, y[1] - rb, rb, 0), (x[0] + rb, y[1] - rb, rb, 90), (x[0] + rf, y[0] + rf, rf, 180)]
    return [(cx + r * math.cos(math.radians(a0 + 90 * i / k)), cy + r * math.sin(math.radians(a0 + 90 * i / k)))
            for cx, cy, r, a0 in corners for i in range(k + 1)]


def loft(bm: bmesh.types.BMesh, rings: list, materials: list, caps: tuple = (None, None)) -> list:
    """Joins each ring of vertices to the next with quads (materials[i] for the band after ring i), and closes
    the first and last ring with a face when caps gives it a material. Returns the faces."""
    n = len(rings[0])
    faces = []
    for a, b, m in zip(rings, rings[1:], materials):
        for i in range(n):
            f = bm.faces.new([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]])
            f.material_index = m
            faces.append(f)
    for ring, m in zip((rings[0], rings[-1]), caps):
        if m is not None:
            f = bm.faces.new(ring)
            f.material_index = m
            faces.append(f)
    for f in faces:
        f.smooth = True
    return faces


def shell(bm: bmesh.types.BMesh) -> None:
    """The basin: a D in plan, flat at the back, its rim a rounded band wider at the back for the tap, the bowl
    sloping to a flat floor."""
    rings = [[bm.verts.new((x, y, z)) for x, y in plan((-HALF + ix, HALF - ix), (FRONT + f, BACK - b), 0.13, 0.03)] for z, ix, f, b in SHELL]
    materials = [OUT] * OUTSIDE + [BOWL] * (len(rings) - 1 - OUTSIDE)
    bmesh.ops.recalc_face_normals(bm, faces=loft(bm, rings, materials, (OUT, BOWL)))


def pedestal(bm: bmesh.types.BMesh) -> None:
    """The column under the basin: a flared foot, a slim waist, a collar that tucks up under the bowl."""
    profile = [(0.0, 0.09, 0.075), (0.012, 0.092, 0.077), (0.026, 0.078, 0.065), (0.07, 0.054, 0.045), (0.2, 0.045, 0.037),
               (0.45, 0.043, 0.035), (0.65, 0.05, 0.041), (0.78, 0.075, 0.06)]
    rings = [[bm.verts.new((rx * math.cos(a), ry * math.sin(a), z)) for a in (math.tau * i / 28 for i in range(28))] for z, rx, ry in profile]
    bmesh.ops.recalc_face_normals(bm, faces=loft(bm, rings, [OUT] * (len(rings) - 1), (OUT, OUT)))


def tube(bm: bmesh.types.BMesh, path: list, material: int, segments: int = 12) -> None:
    """A closed pipe along path, a list of (y, z, radius) in the plane x = 0."""
    rings = []
    for i, (y, z, r) in enumerate(path):
        (y0, z0, _), (y1, z1, _) = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        t = Vector((0.0, y1 - y0, z1 - z0)).normalized()
        n = Vector((0.0, -t.z, t.y))
        rings.append([bm.verts.new(Vector((0.0, y, z)) + r * (math.cos(a) * Vector((1.0, 0.0, 0.0)) + math.sin(a) * n))
                      for a in (math.tau * k / segments for k in range(segments))])
    bmesh.ops.recalc_face_normals(bm, faces=loft(bm, rings, [material] * (len(rings) - 1), (material, material)))


def tap(bm: bmesh.types.BMesh) -> None:
    """A pillar tap on the back deck: an escutcheon, a column with a cross handle on top, and a swan spout out of its
    side that bends down over the bowl."""
    common.revolve(bm, [(0.024, 0.0), (0.024, 0.007), (0.021, 0.011), (0.0185, 0.015), (0.0165, 0.019), (0.0165, 0.078), (0.012, 0.083), (0.012, 0.086),
                        (0.017, 0.088), (0.017, 0.101), (0.009, 0.108), (0.0, 0.108)], (0.0, TAP_Y, RIM), 16, CHROME)
    for angle in (0.0, math.pi / 2):  # the cross: two bars through the hub
        bar = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector((0.0, TAP_Y, RIM + 0.094)), Euler((0.0, 0.0, angle)), Vector((0.056, 0.011, 0.015))))
        for f in {f for v in bar["verts"] for f in v.link_faces}:
            f.material_index = CHROME
    y_bend, z_run, bend = 0.08, 0.995, 0.02
    path = [(TAP_Y, z_run, 0.008), (0.13, z_run, 0.008), (y_bend, z_run, 0.008)]
    path += [(y_bend + bend * math.cos(math.radians(a)), z_run - bend + bend * math.sin(math.radians(a)), 0.008) for a in range(105, 181, 15)]
    path += [(SPOUT[1], 0.972, 0.0095), (SPOUT[1], SPOUT[2], 0.0095)]  # the nozzle's sleeve
    tube(bm, path, CHROME)


def drain(bm: bmesh.types.BMesh) -> None:
    common.revolve(bm, [(0.024, 0.0), (0.024, 0.002), (0.021, 0.0035), (0.011, 0.0035)], (DRAIN[0], DRAIN[1], FLOOR), 20, CHROME)


def shelf(bm: bmesh.types.BMesh) -> None:
    """The glass, held at its ends by two chrome clamps, against the wall."""
    common.slab(bm, (0.0, BACK - 0.06), (0.44, 0.12), SHELF - 0.008, SHELF, 0.008, 0.002, GLASS)
    for sx in (-1, 1):
        common.box(bm, (sx * 0.226, BACK - 0.0575, SHELF - 0.004), (0.012, 0.115, 0.034), CHROME)


def cup(bm: bmesh.types.BMesh) -> None:
    """A plastic tumbler, open at the top, standing on the shelf."""
    common.revolve(bm, [(0.026, 0.0), (0.0365, 0.095), (0.0365, 0.0965), (0.0345, 0.0965), (0.0335, 0.095), (0.0245, 0.004), (0.0, 0.004)],
                   (CUP[0], CUP[1], SHELF), 20, PLASTIC)


def toothbrush(bm: bmesh.types.BMesh) -> None:
    """One red toothbrush stood in the cup, leaning out of it towards the front and a little to one side."""
    start = len(bm.verts)
    common.post(bm, 0.0, 0.12, (0.0, 0.0, 0.008, 0.006), (0.0, 0.0, 0.013, 0.007), HANDLE)
    common.post(bm, 0.12, 0.172, (0.0, 0.0, 0.013, 0.007), (0.0, 0.0, 0.012, 0.006), HANDLE)
    common.box(bm, (0.0, -0.008, 0.158), (0.01, 0.01, 0.026), BRISTLES)
    bm.verts.ensure_lookup_table()
    verts = bm.verts[start:]
    bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0), matrix=Matrix.Rotation(0.55, 3, "Z"))
    bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0), matrix=Matrix.Rotation(0.14, 3, "X") @ Matrix.Rotation(-0.05, 3, "Y"))
    bmesh.ops.translate(bm, verts=verts, vec=(CUP[0], CUP[1], SHELF + 0.006))


# --- materials ------------------------------------------------------------------------------------------

def porcelain(name: str, bowl: bool) -> bpy.types.Material:
    """White glaze gone yellow, grubby in the crevices. The bowl's has a ring of limescale at the waterline with a
    brown tide mark above it, a rust stain round the dark drain, and a chip out of the front rim; the outside is
    dirty at the foot and streaked under the rim."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    colour = lerp(nt, (0.72, 0.71, 0.66), (0.6, 0.56, 0.45), mapped(nt, noise(nt, coords, 5.0, 4.0), 0.4, 0.7, 0.0, 1.0))
    rough = 0.16
    ao = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.04}, samples=32, only_local=True).outputs["AO"]
    grime = maths(nt, "MULTIPLY", mapped(nt, ao, 0.85, 0.15, 0.0, 0.85), mapped(nt, noise(nt, coords, 30.0, 3.0), 0.3, 0.7, 0.4, 1.0))
    flat_xy = node(nt, "ShaderNodeCombineXYZ", {"X": xyz["X"], "Y": xyz["Y"]}).outputs["Vector"]

    def spot(x: float, y: float) -> bpy.types.NodeSocket:  # distance from (x, y) in plan
        return node(nt, "ShaderNodeVectorMath", {0: flat_xy, 1: (x, y, 0.0)}, operation="DISTANCE").outputs["Value"]

    if bowl:
        line = maths(nt, "ADD", 0.855, maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", noise(nt, coords, 25.0, 3.0), 0.5), 0.03))
        d = maths(nt, "SUBTRACT", xyz["Z"], line)
        scale = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", mapped(nt, d, 0.002, -0.002, 0.0, 1.0), mapped(nt, d, -0.014, -0.034, 1.0, 0.0)),
                      mapped(nt, noise(nt, coords, 70.0, 4.0), 0.3, 0.6, 0.45, 1.0))
        tide = maths(nt, "MULTIPLY", mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "ADD", d, 0.001)), 0.004, 0.0, 0.0, 1.0),
                     mapped(nt, noise(nt, coords, 50.0, 3.0), 0.35, 0.6, 0.3, 1.0))
        around = spot(*DRAIN)
        rust = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", mapped(nt, around, 0.075, 0.022, 0.0, 0.9), mapped(nt, noise(nt, coords, 20.0, 4.0), 0.3, 0.6, 0.3, 1.0)),
                     mapped(nt, xyz["Z"], 0.86, 0.83, 0.0, 1.0))
        chip = maths(nt, "MULTIPLY", mapped(nt, spot(-0.17, -0.15), 0.016, 0.008, 0.0, 1.0), mapped(nt, noise(nt, coords, 90.0, 3.0), 0.3, 0.55, 0.5, 1.0))
        colour = lerp(nt, colour, (0.75, 0.71, 0.6), maths(nt, "MULTIPLY", scale, 0.9))
        colour = lerp(nt, colour, (0.3, 0.22, 0.12), maths(nt, "MULTIPLY", tide, 0.8))
        colour = lerp(nt, colour, (0.26, 0.12, 0.05), rust)
        colour = lerp(nt, colour, (0.03, 0.025, 0.02), mapped(nt, around, 0.013, 0.01, 0.0, 1.0))  # the drain's dark centre
        colour = lerp(nt, colour, (0.33, 0.29, 0.24), chip)
        rough = maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", rough, maths(nt, "MULTIPLY", scale, 0.8)), maths(nt, "MAXIMUM", maths(nt, "MULTIPLY", rust, 0.55), maths(nt, "MULTIPLY", chip, 0.7)))
        height = scale  # the limescale stands proud of the glaze
    else:
        foot = maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], 0.07, 0.0, 0.0, 0.45), mapped(nt, noise(nt, coords, 18.0, 4.0), 0.35, 0.65, 0.4, 1.0))
        runs = node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": (60.0, 60.0, 4.0)}).outputs["Vector"]
        streaks = maths(nt, "MULTIPLY", mapped(nt, noise(nt, runs, 1.0, 2.0), 0.5, 0.7, 0.0, 0.5), mapped(nt, xyz["Z"], 0.78, 0.92, 0.0, 1.0))
        colour = lerp(nt, colour, (0.5, 0.42, 0.28), streaks)
        colour = lerp(nt, colour, (0.36, 0.31, 0.22), foot)
        rough = maths(nt, "MAXIMUM", rough, maths(nt, "MULTIPLY", foot, 0.8))
    colour = lerp(nt, colour, (0.16, 0.13, 0.09), grime)
    rough = maths(nt, "MAXIMUM", rough, maths(nt, "MULTIPLY", grime, 0.7))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    if bowl:
        nt.links.new(node(nt, "ShaderNodeBump", {"Strength": 0.6, "Distance": 0.003, "Height": height}).outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def chrome(name: str) -> bpy.types.Material:
    """Chrome gone dull: tarnished in soft blotches, flecked with water spots, and crusted with limescale low on the
    tap and round the drain, where the water sits; the crust is pale, rough and not metal at all."""
    mat, nt, bsdf, coords = common.surface(name)
    z = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs["Z"]
    spots = mapped(nt, noise(nt, coords, 140.0, 3.0), 0.58, 0.7, 0.0, 0.45)
    low = maths(nt, "MULTIPLY", mapped(nt, z, 0.985, 0.94, 0.0, 1.0), mapped(nt, noise(nt, coords, 90.0, 4.0), 0.4, 0.62, 0.2, 1.0))
    crust = maths(nt, "MAXIMUM", spots, maths(nt, "MULTIPLY", low, 0.85))
    tarnish = mapped(nt, noise(nt, coords, 12.0, 4.0), 0.45, 0.7, 0.0, 0.3)
    colour = lerp(nt, lerp(nt, (0.76, 0.78, 0.8), (0.4, 0.4, 0.38), tarnish), (0.8, 0.78, 0.7), crust)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, crust, 0.0, 1.0, 0.6, 0.2), bsdf.inputs["Metallic"])
    nt.links.new(maths(nt, "ADD", maths(nt, "ADD", 0.22, maths(nt, "MULTIPLY", tarnish, 0.4)), maths(nt, "MULTIPLY", crust, 0.4)), bsdf.inputs["Roughness"])
    return mat


def glass(name: str) -> bpy.types.Material:
    """Glass seen as an opaque pale green: dark green at the ends and edges, filmed with soap and dust on top, with a
    cleaner ring where the cup stands."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    up = mapped(nt, node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs["Z"], 0.6, 0.95, 0.0, 1.0)
    film = maths(nt, "MULTIPLY", up, mapped(nt, noise(nt, coords, 25.0, 4.0), 0.4, 0.7, 0.0, 0.8))
    cup = node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": xyz["X"], "Y": xyz["Y"]}).outputs["Vector"], 1: (CUP[0], CUP[1], 0.0)}, operation="DISTANCE").outputs["Value"]
    ring = maths(nt, "MULTIPLY", up, mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", cup, 0.03)), 0.008, 0.0, 0.0, 0.8))
    colour = lerp(nt, (0.05, 0.22, 0.17), (0.42, 0.55, 0.51), up)
    colour = lerp(nt, colour, (0.45, 0.4, 0.3), film)
    colour = lerp(nt, colour, (0.2, 0.15, 0.1), ring)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(maths(nt, "ADD", 0.12, maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", film, ring), 0.6)), bsdf.inputs["Roughness"])
    return mat


def plastic(name: str, tint: tuple, worn: tuple, rough: float, scum: bool = False) -> bpy.types.Material:
    """Moulded plastic: the tint dulled towards worn in patches, pale scuffs, dust on up-facing surfaces. scum: a
    film of soap and limescale low down and a ring of scale where the water stood, for the cup."""
    mat, nt, bsdf, coords = common.surface(name)
    z = maths(nt, "SUBTRACT", node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs["Z"], SHELF)
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    up = mapped(nt, node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs["Z"], 0.3, 0.95, 0.0, 1.0)
    colour = lerp(nt, tint, worn, mapped(nt, noise(nt, coords, 9.0, 4.0), 0.4, 0.65, 0.0, 1.0))
    scuffs = mapped(nt, noise(nt, coords, 120.0, 3.0), 0.55, 0.7, 0.0, 0.5)
    colour = lerp(nt, colour, tuple(min(c * 2.0 + 0.1, 1.0) for c in tint), scuffs)
    dust = maths(nt, "MULTIPLY", up, mapped(nt, noise(nt, coords, 40.0, 3.0), 0.4, 0.7, 0.1, 0.5))
    colour = lerp(nt, colour, (0.3, 0.28, 0.25), dust)
    rougher = maths(nt, "MAXIMUM", maths(nt, "MULTIPLY", dust, 0.6), maths(nt, "MULTIPLY", scuffs, 0.5))
    if scum:
        low = mapped(nt, z, 0.05, 0.0, 0.0, 1.0)
        band = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", z, 0.06)), 0.012, 0.0, 0.0, 1.0)
        film = maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", low, band), mapped(nt, noise(nt, coords, 60.0, 4.0), 0.3, 0.6, 0.4, 1.0))
        colour = lerp(nt, colour, (0.55, 0.5, 0.36), maths(nt, "MULTIPLY", film, 0.5))
        rougher = maths(nt, "MAXIMUM", rougher, maths(nt, "MULTIPLY", film, 0.6))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(maths(nt, "ADD", rough, maths(nt, "MULTIPLY", rougher, 0.5)), bsdf.inputs["Roughness"])
    return mat


def bristles(name: str) -> bpy.types.Material:
    """Nylon bristles, blue-white gone yellow and splayed."""
    mat, nt, bsdf, coords = common.surface(name)
    fibres = noise(nt, coords, 300.0, 3.0)
    colour = lerp(nt, lerp(nt, (0.5, 0.58, 0.78), (0.62, 0.57, 0.42), mapped(nt, noise(nt, coords, 40.0, 3.0), 0.4, 0.7, 0.0, 1.0)), (0.82, 0.8, 0.72), mapped(nt, fibres, 0.45, 0.65, 0.0, 0.6))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, fibres, 0.3, 0.7, 0.65, 0.9), bsdf.inputs["Roughness"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
bm = bmesh.new()
shell(bm)
pedestal(bm)
tap(bm)
drain(bm)
shelf(bm)
cup(bm)
toothbrush(bm)
me = bpy.data.meshes.new("Basin")
bm.to_mesh(me)
bm.free()
for m in (porcelain("outside", False), porcelain("bowl", True), chrome("chrome"), glass("glass"),
          plastic("cup", (0.17, 0.38, 0.46), (0.25, 0.36, 0.3), 0.3, scum=True), plastic("handle", (0.69, 0.07, 0.05), (0.42, 0.05, 0.04), 0.35),
          bristles("bristles")):
    me.materials.append(m)
basin = bpy.data.objects.new("Basin", me)
bpy.context.scene.collection.objects.link(basin)
me.set_sharp_from_angle(angle=math.radians(50))
common.bake(basin, pack=True)
common.export("basin", [basin])

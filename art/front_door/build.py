"""The front door of the flat: a solid timber door, 0.954 m wide, 2.07 m tall and 5 cm thick, two panels recessed 5 mm
between a stile on each side and three rails, dark varnish rubbed through to pale wood round the handle and the key plate
and chipped along the edges, scuffed and kicked at the bottom, dirtier outside than in. A lever handle stands out of each face, a deadbolt's
key plate outside and its thumb-turn inside, a peephole at 1.55 m. Run by tools/models.sh.

The origin is the hinge-side bottom edge, in the middle of the thickness; the panel runs along +X. The front faces -Y
like every model's, and is the outside: the corridor. The inside faces +Y.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

node, mapped, maths, lerp, noise = common.node, common.mapped, common.maths, common.lerp, common.noise

WIDTH, HEIGHT = 0.954, 2.07
FACE, FIELD = 0.025, 0.020  # half the thickness at the stiles and rails; at the recessed panels
STILE = 0.14
RAILS = [(0.0, 0.18), (0.95, 1.10), (1.93, HEIGHT)]  # bottom, middle, top: from, to
LEVER = (0.877, 0.985)  # the handle's rose, across and up the door
GRIP = (0.86, 1.07)  # the centre of the rubbed patch, between the lever and the key plate
BOLT = (0.877, 1.15)  # the deadbolt's key plate and thumb-turn
PEEPHOLE = (0.477, 1.55)
TIMBER, STEEL, BRASS, LENS = range(4)  # material indices
SEGMENTS = 16


# --- geometry -------------------------------------------------------------------------------------------

def added(bm: bmesh.types.BMesh, draw) -> list:
    """Runs draw(bm) and returns the vertices it made (not the last ones in bm.verts: bmesh reuses the slots of deleted
    ones)."""
    old = set(bm.verts)
    draw(bm)
    return [v for v in bm.verts if v not in old]


def mount(bm: bmesh.types.BMesh, part, x: float, z: float, front: bool, surface: float) -> None:
    """Draws part, which stands out of the plane z = 0 along +z, on the door's front (-Y) or back face at (x, z); surface
    is the half thickness there."""
    verts = added(bm, part)
    bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2 if front else -math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, verts=verts, vec=(x, -surface if front else surface, z))


def lever(bm: bmesh.types.BMesh) -> None:
    """A lever handle on a round rose, the lever pointing back towards the hinge."""
    common.revolve(bm, [(0.027, 0.0), (0.027, 0.006), (0.0245, 0.009), (0.0125, 0.0095), (0.0095, 0.012), (0.0095, 0.04), (0.0, 0.04)], (0, 0, 0), SEGMENTS, STEEL)
    common.chamfered_box(bm, (-0.045, 0.0, 0.0355), (0.125, 0.019, 0.019), 0.004, STEEL)


def thumb_turn(bm: bmesh.types.BMesh) -> None:
    """The deadbolt's thumb-turn: a rose with a flat tab on a stem, standing a little off upright."""
    common.revolve(bm, [(0.026, 0.0), (0.026, 0.006), (0.023, 0.009), (0.0105, 0.0095), (0.007, 0.012), (0.007, 0.022), (0.0, 0.022)], (0, 0, 0), SEGMENTS, STEEL)
    tab = added(bm, lambda b: common.chamfered_box(b, (0.0, 0.0, 0.0265), (0.012, 0.038, 0.009), 0.002, STEEL))
    bmesh.ops.rotate(bm, verts=tab, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(18), 3, "Z"))


def key_plate(bm: bmesh.types.BMesh) -> None:
    common.revolve(bm, [(0.0225, 0.0), (0.0225, 0.004), (0.02, 0.007), (0.0125, 0.0075), (0.011, 0.01), (0.0, 0.01)], (0, 0, 0), SEGMENTS, BRASS)


def peephole_outside(bm: bmesh.types.BMesh) -> None:
    common.revolve(bm, [(0.0135, 0.0), (0.0135, 0.003), (0.011, 0.0065), (0.0066, 0.0068)], (0, 0, 0), SEGMENTS, BRASS)
    common.revolve(bm, [(0.0066, 0.0045), (0.005, 0.0062), (0.0, 0.0068)], (0, 0, 0), SEGMENTS, LENS)


def peephole_inside(bm: bmesh.types.BMesh) -> None:
    common.revolve(bm, [(0.0145, 0.0), (0.0145, 0.004), (0.012, 0.0085), (0.0, 0.0095)], (0, 0, 0), SEGMENTS, BRASS)


def build() -> bpy.types.Object:
    bm = bmesh.new()
    common.box(bm, (WIDTH / 2, 0.0, HEIGHT / 2), (WIDTH, 2 * FIELD, HEIGHT), TIMBER)  # the panels' level
    frame = [(0.0, STILE, 0.0, HEIGHT), (WIDTH - STILE, WIDTH, 0.0, HEIGHT)] + [(STILE, WIDTH - STILE, a, b) for a, b in RAILS]
    for side in (-1, 1):  # the stiles and rails stand 5 mm proud of the panels on both faces
        for x0, x1, z0, z1 in frame:
            common.box(bm, ((x0 + x1) / 2, side * (FIELD + FACE) / 2, (z0 + z1) / 2), (x1 - x0, FACE - FIELD, z1 - z0), TIMBER)
    for front in (True, False):
        mount(bm, lever, *LEVER, front, FACE)
        mount(bm, key_plate if front else thumb_turn, *BOLT, front, FACE)
        mount(bm, peephole_outside if front else peephole_inside, *PEEPHOLE, front, FIELD)
    me = bpy.data.meshes.new("FrontDoor")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("FrontDoor", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- materials ------------------------------------------------------------------------------------------

def timber() -> bpy.types.Material:
    """Dark varnished timber: the grain up the stiles and panels, across the rails. The varnish is worn through to pale,
    greyish bare wood only where hands and feet touch: softly round the handle and the key plate, along the lock stile's
    edge, along the foot, and chipped at the edges; the bottom is kicked in long low scuffs, rubber-streaked, and grimy.
    The outside gets more of the kicks."""
    mat, nt, bsdf, coords = common.surface("timber")
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    x, y, z = xyz["X"], xyz["Y"], xyz["Z"]
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    bevelled = node(nt, "ShaderNodeBevel", {"Radius": 0.003}, samples=16).outputs["Normal"]

    def between(v: bpy.types.NodeSocket, lo: float, hi: float) -> bpy.types.NodeSocket:  # 1 inside lo..hi, soft edges
        return maths(nt, "MULTIPLY", mapped(nt, v, lo - 0.002, lo, 0.0, 1.0), mapped(nt, v, hi, hi + 0.002, 1.0, 0.0))

    def stretched(axis: int, along: float, across: float) -> bpy.types.NodeSocket:  # noise drawn out along the grain
        scale = tuple(along if i == axis else across for i in range(3))
        return noise(nt, node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": scale}).outputs["Vector"], 1.0, 3.0)

    def smudged(scale: tuple, offset: tuple = (0.0, 0.0, 0.0)) -> bpy.types.NodeSocket:  # soft noise, drawn out along the axes whose scale is low
        return noise(nt, node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": scale, "Location": offset}).outputs["Vector"], 1.0, 2.0)

    def grain(axis: int) -> bpy.types.NodeSocket:
        return mapped(nt, maths(nt, "ADD", maths(nt, "MULTIPLY", stretched(axis, 3.0, 120.0), 0.6), maths(nt, "MULTIPLY", stretched(axis, 2.0, 22.0), 0.4)), 0.3, 0.7, 0.0, 1.0)

    def around(cx: float, cz: float, rx: float, rz: float) -> bpy.types.NodeSocket:  # distance from (cx, cz) in units of the ellipse's radii
        pos = node(nt, "ShaderNodeCombineXYZ", {"X": maths(nt, "DIVIDE", maths(nt, "SUBTRACT", x, cx), rx), "Y": maths(nt, "DIVIDE", maths(nt, "SUBTRACT", z, cz), rz)}).outputs["Vector"]
        return node(nt, "ShaderNodeVectorMath", {0: pos}, operation="LENGTH").outputs["Value"]

    rails = maths(nt, "MULTIPLY", between(x, STILE, WIDTH - STILE), maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", between(z, *RAILS[0]), between(z, *RAILS[1])), between(z, *RAILS[2])))
    vertical = grain(2)
    lines = maths(nt, "ADD", vertical, maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", grain(0), vertical), rails))
    varnished = lerp(nt, (0.055, 0.022, 0.010), (0.105, 0.045, 0.021), lines)
    bare = lerp(nt, (0.34, 0.29, 0.22), (0.48, 0.42, 0.33), lines)
    outside = mapped(nt, y, 0.01, -0.01, 0.0, 1.0)

    edge = mapped(nt, node(nt, "ShaderNodeVectorMath", {0: bevelled, 1: flat}, operation="DOT_PRODUCT").outputs["Value"], 1.0, 0.8, 0.0, 1.0)
    # Where hands and feet touch: the lock stile's edge about the handle, and the foot of the door.
    stile = maths(nt, "MULTIPLY", mapped(nt, x, WIDTH - 0.06, WIDTH, 0.0, 1.0), mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", z, GRIP[1])), 0.4, 0.1, 0.0, 1.0))
    foot_rub = mapped(nt, z, 0.16, 0.03, 0.0, 1.0)
    touched = maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", maths(nt, "MULTIPLY", stile, 0.7), maths(nt, "MULTIPLY", foot_rub, 0.55)), mapped(nt, smudged((6.0, 6.0, 6.0)), 0.3, 0.65, 0.35, 1.0))
    # The rub-through round the lever and the key plate: soft, roughly elliptical, streaked up the grain; a faint dark ring at its edge.
    rub = around(GRIP[0], GRIP[1], 0.1, 0.2)
    rubbed = maths(nt, "MULTIPLY", mapped(nt, rub, 1.0, 0.15, 0.0, 0.85), mapped(nt, smudged((22.0, 22.0, 5.0)), 0.3, 0.7, 0.5, 1.0))
    grease = maths(nt, "MULTIPLY", mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", rub, 1.25)), 0.4, 0.0, 0.0, 0.3), mapped(nt, smudged((5.0, 5.0, 5.0)), 0.3, 0.7, 0.3, 1.0))
    # Kicks: long, low scuffs along the foot, with the odd finer scratch and a streak of rubber.
    low = mapped(nt, z, 0.3, 0.04, 0.0, 1.0)
    scuffs = maths(nt, "MULTIPLY", low, mapped(nt, smudged((5.0, 5.0, 26.0)), 0.55, 0.7, 0.0, 0.85))
    scratches = maths(nt, "MULTIPLY", low, mapped(nt, smudged((9.0, 9.0, 140.0), (3.0, 7.0, 0.0)), 0.55, 0.68, 0.0, 0.5))
    smear = maths(nt, "MULTIPLY", low, mapped(nt, smudged((6.0, 6.0, 30.0), (11.0, 3.0, 5.0)), 0.52, 0.68, 0.0, 1.0))
    kicked = maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", scuffs, scratches), mapped(nt, outside, 0.0, 1.0, 0.45, 1.0))
    worn = maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", edge, touched), maths(nt, "MAXIMUM", rubbed, kicked))
    colour = lerp(nt, varnished, bare, worn)
    colour = lerp(nt, colour, (0.025, 0.02, 0.014), maths(nt, "MULTIPLY", smear, mapped(nt, outside, 0.0, 1.0, 0.4, 0.8)))
    colour = lerp(nt, colour, (0.02, 0.012, 0.008), grease)
    foot = maths(nt, "MULTIPLY", mapped(nt, z, 0.14, 0.0, 0.0, 0.75), mapped(nt, noise(nt, coords, 25.0, 4.0), 0.3, 0.65, 0.3, 1.0))
    colour = lerp(nt, colour, (0.035, 0.03, 0.024), foot)
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.04}, samples=32, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.02, 0.01, 0.005), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    rough = maths(nt, "MAXIMUM", mapped(nt, worn, 0.0, 1.0, 0.38, 0.85), maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", foot, grease), 0.9))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    nt.links.new(bevelled, bsdf.inputs["Normal"])
    return mat


def steel() -> bpy.types.Material:
    """Satin stainless gone dull: tarnished in blotches, dirty in the crevices."""
    mat, nt, bsdf, coords = common.surface("steel")
    tarnish = mapped(nt, noise(nt, coords, 22.0, 4.0), 0.35, 0.65, 0.0, 1.0)
    colour = lerp(nt, (0.62, 0.6, 0.55), (0.36, 0.34, 0.3), tarnish)
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.01}, samples=16, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.1, 0.08, 0.06), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(maths(nt, "ADD", 0.34, maths(nt, "MULTIPLY", tarnish, 0.25)), bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.55
    return mat


def brass() -> bpy.types.Material:
    """Brass gone brown, with the key plate's keyhole: a round hole over a slot, black."""
    mat, nt, bsdf, coords = common.surface("brass")
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    tarnish = mapped(nt, noise(nt, coords, 30.0, 4.0), 0.35, 0.65, 0.0, 1.0)
    colour = lerp(nt, (0.5, 0.34, 0.11), (0.22, 0.14, 0.055), tarnish)
    dx, dz = maths(nt, "SUBTRACT", xyz["X"], BOLT[0]), maths(nt, "SUBTRACT", xyz["Z"], BOLT[1])
    hole = node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": dx, "Y": maths(nt, "SUBTRACT", dz, 0.002)}).outputs["Vector"]}, operation="LENGTH").outputs["Value"]
    slot = maths(nt, "MULTIPLY", mapped(nt, maths(nt, "ABSOLUTE", dx), 0.0016, 0.0009, 0.0, 1.0), mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "ADD", dz, 0.002)), 0.0045, 0.0035, 0.0, 1.0))
    keyhole = maths(nt, "MAXIMUM", mapped(nt, hole, 0.0034, 0.0026, 0.0, 1.0), slot)
    colour = lerp(nt, colour, (0.01, 0.008, 0.006), maths(nt, "MULTIPLY", keyhole, mapped(nt, maths(nt, "ABSOLUTE", dz), 0.02, 0.012, 0.0, 1.0)))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(maths(nt, "ADD", 0.3, maths(nt, "MULTIPLY", tarnish, 0.3)), bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.5
    return mat


def lens() -> bpy.types.Material:
    """The peephole's glass, dark."""
    mat, nt, bsdf, coords = common.surface("lens")
    bsdf.inputs["Base Color"].default_value = (0.012, 0.014, 0.017, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.1
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
door = build()
for m in (timber(), steel(), brass(), lens()):
    door.data.materials.append(m)
door.data.set_sharp_from_angle(angle=math.radians(50))
common.bake(door, size=512, pack=True)
common.export("front_door", [door])

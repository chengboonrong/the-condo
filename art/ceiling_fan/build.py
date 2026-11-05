"""The living room's ceiling fan: the plain three-blade kind, 1.4 m across, on a short downrod under a ceiling
canopy. A white motor housing yellowed round its underside, three cream painted steel blades on flat blade irons, and a
grey line of dust along each blade's leading edge. Run by tools/models.sh.

The origin is the ceiling mount, the top of the canopy. The Blades part (the housing, the blades and their irons)
turns about the downrod, so its origin is on the rod's axis, DROP below the mount; the game turns it, anticlockwise
seen from above, which makes +Y the blades' leading edge when one points along +X.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

node, mapped, maths, lerp, noise = common.node, common.mapped, common.maths, common.lerp, common.noise

DROP = 0.2  # the blades' pivot, below the mount
SEGMENTS = 24
HUB, TIP = 0.17, 0.70  # a blade runs from the housing's edge to 0.7 m out: 1.4 m across
HALF_WIDTH = 0.088
ROUND = 0.06  # the length of the blade's rounded tip
THICK = 0.006
CAMBER = 0.012  # how far the middle of a blade arches above its edges
PITCH = math.radians(11)  # the leading edge stands higher, so the blade pushes air down
PAINT, ENAMEL = range(2)  # material indices
WHITE = (0.80, 0.77, 0.68)
YELLOWED = (0.68, 0.56, 0.30)
CREAM = (0.58, 0.48, 0.30)
STAIN = (0.5, 0.38, 0.2)
DUST = (0.2, 0.195, 0.185)

# The canopy and downrod, from the rod's lower end up to the ceiling (radius, height); the housing, from its top down to
# its point, with a seam round its widest line.
CANOPY = [(0.0125, -0.14), (0.0125, -0.078), (0.02, -0.074), (0.034, -0.066), (0.06, -0.052), (0.08, -0.034), (0.089, -0.016),
          (0.091, -0.006), (0.091, 0.0)]
HOUSING = [(0.03, -0.138), (0.055, -0.141), (0.085, -0.153), (0.098, -0.17), (0.1035, -0.19), (0.1015, -0.197), (0.1015, -0.2025),
           (0.104, -0.209), (0.103, -0.222), (0.094, -0.24), (0.07, -0.25), (0.0, -0.2525)]


# --- geometry -------------------------------------------------------------------------------------------

def blade(bm: bmesh.types.BMesh, turn: float, uv) -> None:
    """One blade pointing out along the direction turn (radians about the downrod). Its UVs are (along the blade, 0 at
    the root to 1 at the tip; across it, 0 at the trailing edge to 1 at the leading edge), which the paint reads."""
    stations = [(HUB + (TIP - ROUND - HUB) * k / 3, HALF_WIDTH) for k in range(4)]
    stations += [(TIP - ROUND + ROUND * math.sin(math.radians(a)), HALF_WIDTH * math.cos(math.radians(a))) for a in (35, 60, 80)]
    top = (-0.95, -0.5, 0.0, 0.5, 0.95)
    section = [(s, 1) for s in top] + [(1.0, 0)] + [(s, -1) for s in reversed(top)] + [(-1.0, 0)]  # round the lens, edges at +-1
    pitch, spin = Matrix.Rotation(PITCH, 3, "X"), Matrix.Rotation(turn, 3, "Z")
    rings, uvs = [], {}
    for r, half in stations:
        ring = []
        for s, side in section:
            camber = CAMBER * (1 - s * s) * half / HALF_WIDTH  # flattens towards the tip
            v = bm.verts.new(spin @ (pitch @ Vector((0.0, s * half, camber + side * THICK / 2))) + spin @ Vector((r, 0.0, 0.0)) + Vector((0.0, 0.0, -DROP)))
            uvs[v] = ((r - HUB) / (TIP - HUB), (s + 1) / 2)
            ring.append(v)
        rings.append(ring)
    n = len(section)
    faces = [bm.faces.new([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]]) for a, b in zip(rings, rings[1:]) for i in range(n)]
    for f in faces:
        f.smooth = True
    faces += [bm.faces.new(rings[0]), bm.faces.new(rings[-1])]  # the ends, flat
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for f in faces:
        f.material_index = PAINT
        for loop in f.loops:
            loop[uv].uv = uvs[loop.vert]


def iron(bm: bmesh.types.BMesh, turn: float) -> None:
    """The flat steel bar that holds a blade to the housing: it runs from inside the housing out under the blade's root."""
    spin = Matrix.Rotation(turn, 4, "Z") @ Matrix.Rotation(PITCH, 4, "X")
    cube = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0.0, 0.0, -DROP)) @ spin @ Matrix.LocRotScale(Vector((0.21, 0.0, 0.0065)), None, Vector((0.24, 0.038, 0.003))))
    for f in {f for v in cube["verts"] for f in v.link_faces}:
        f.material_index = PAINT  # painted to match the blade it holds


def mesh_object(name: str, bm: bmesh.types.BMesh, materials: list) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in materials:
        me.materials.append(m)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def fixed(materials: list) -> bpy.types.Object:
    """The canopy and the rod."""
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    common.revolve(bm, CANOPY, (0.0, 0.0, 0.0), SEGMENTS, ENAMEL)
    return mesh_object("fixed", bm, materials)


def turning(materials: list) -> bpy.types.Object:
    """The housing, the three blades and their irons. The vertex group names them for splitting off after the bake."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    common.revolve(bm, HOUSING, (0.0, 0.0, 0.0), SEGMENTS, ENAMEL)
    for k in range(3):
        blade(bm, math.tau * k / 3, uv)
        iron(bm, math.tau * k / 3)
    obj = mesh_object("turning", bm, materials)
    obj.vertex_groups.new(name="Blades").add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    return obj


def split_off(fan: bpy.types.Object) -> bpy.types.Object:
    """Separates the Blades vertex group from the baked fan, its origin on the rod's axis, unrotated: the game turns it."""
    common.select([fan])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    fan.vertex_groups.active = fan.vertex_groups["Blades"]
    bpy.ops.object.vertex_group_select()
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    part = next(o for o in bpy.context.view_layer.objects if o.select_get() and o != fan)
    part.name = part.data.name = "Blades"
    pivot = Vector((0.0, 0.0, -DROP))
    part.data.transform(Matrix.Translation(-pivot))
    part.location = pivot
    part.vertex_groups.clear()
    return part


# --- materials ------------------------------------------------------------------------------------------

def paint() -> bpy.types.Material:
    """Cream paint on pressed steel: uneven in tone, stained yellow-brown in broad patches by years of cooking air, and
    a grey line of dust along the leading edge (UV v near 1), heavier towards the tip. The irons have no UVs (v = 0), so they
    get plain paint."""
    mat, nt, bsdf, coords = common.surface("paint")
    uv = node(nt, "ShaderNodeSeparateXYZ", {"Vector": node(nt, "ShaderNodeUVMap", uv_map="UVMap").outputs["UV"]}).outputs  # not the bake's own unwrap
    tone = mapped(nt, noise(nt, coords, 5.0, 2.0), 0.35, 0.65, 0.0, 1.0)
    stain = mapped(nt, noise(nt, coords, 3.0, 2.0), 0.5, 0.7, 0.0, 0.7)
    inner = maths(nt, "SUBTRACT", 0.86, mapped(nt, noise(nt, coords, 22.0, 2.0), 0.35, 0.65, -0.04, 0.04))  # the line's wavering inner edge
    line = mapped(nt, maths(nt, "SUBTRACT", uv["Y"], inner), 0.0, 0.04, 0.0, 1.0)
    patchy = mapped(nt, noise(nt, coords, 6.0, 2.0), 0.35, 0.65, 0.6, 1.0)
    dust = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", line, patchy), mapped(nt, uv["X"], 0.0, 1.0, 0.8, 1.0))
    colour = lerp(nt, lerp(nt, tuple(c * 0.9 for c in CREAM), tuple(c * 1.05 for c in CREAM), tone), STAIN, stain)
    colour = lerp(nt, colour, DUST, maths(nt, "MULTIPLY", dust, 0.95))
    rough = maths(nt, "MAXIMUM", mapped(nt, stain, 0.0, 0.7, 0.42, 0.55), mapped(nt, dust, 0.0, 1.0, 0.0, 0.9))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    return mat


def enamel() -> bpy.types.Material:
    """White enamel gone yellow, more so on the underside of the housing, darker in its seam and where the blade irons
    meet it."""
    mat, nt, bsdf, coords = common.surface("enamel")
    z = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs["Z"]
    below = mapped(nt, z, -0.18, -0.255, 0.0, 1.0)
    patchy = mapped(nt, noise(nt, coords, 12.0, 2.0), 0.35, 0.65, 0.0, 1.0)
    yellow = maths(nt, "MINIMUM", maths(nt, "ADD", maths(nt, "MULTIPLY", below, 0.6), maths(nt, "MULTIPLY", patchy, 0.4)), 1.0)
    crevice = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.03}, samples=16, only_local=True).outputs["AO"]
    colour = node(nt, "ShaderNodeVectorMath", {0: lerp(nt, WHITE, YELLOWED, yellow), "Scale": mapped(nt, crevice, 0.0, 0.8, 0.5, 1.0)}, operation="SCALE").outputs["Vector"]
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, yellow, 0.0, 1.0, 0.4, 0.6), bsdf.inputs["Roughness"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
materials = [paint(), enamel()]
fan = fixed(materials)
common.select([fan, turning(materials)])
bpy.ops.object.join()
fan.name = "CeilingFan"
fan.data.set_sharp_from_angle(angle=math.radians(35))
common.bake(fan, size=256, pack=True)
blades = split_off(fan)
fan.vertex_groups.clear()
common.export("ceiling_fan", [fan, blades])

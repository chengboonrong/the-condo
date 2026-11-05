"""The entrance's intercom: the cheap wall-mounted handset kind, a beige plastic base 9 cm by 22 cm and 2.2 cm deep with
the handset lying on it, its cord coiled down below the base and back up into it, and a round door-release button with
a key on it. The plastic has yellowed; the base is greasy round the handset where a hand holds it, and the handset
more so. Run by tools/models.sh.

The origin is the centre of the face on the wall; the front faces -Y like every model's, so placed with its front
facing away from the wall the base stands flush against it. It is drawn in the plate's own axes (x across, y up, z
out of the wall) and turned to Blender's at the end.
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

WIDTH, HEIGHT, DEPTH = 0.09, 0.22, 0.022  # the base
EAR, MOUTH = 0.084, -0.014  # the handset's cups: their centres' height on the base
BUTTON = (-0.02, -0.07)  # the release button's centre on the base
SHELL, HANDSET, KEY, CORD = range(4)  # material indices
# The cord's centre line: from the mouthpiece's underside, down past the base's lower edge, round a loop and back up into
# the underside of the base (x, y, z in the plate's axes).
CORD_PATH = [(0.012, -0.032, 0.040), (0.016, -0.075, 0.034), (0.012, -0.12, 0.028), (0.0, -0.138, 0.025), (-0.014, -0.125, 0.018), (-0.019, -0.109, 0.011)]
COIL, WIRE, PITCH, STEPS = 0.0058, 0.0021, 0.0135, 6  # the coil's radius, the wire's, one turn's length, segments in a turn


# --- geometry -------------------------------------------------------------------------------------------

def spline(points: list, per_segment: int = 24) -> list:
    """A smooth line through the points (Catmull-Rom), as a list of Vectors."""
    p = [Vector(q) for q in points]
    p = [p[0]] + p + [p[-1]]
    out = []
    for a, b, c, d in zip(p, p[1:], p[2:], p[3:]):
        for i in range(per_segment):
            t = i / per_segment
            out.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3))
    out.append(p[-2])
    return out


def resample(line: list, step: float) -> list:
    """Points along the line every step metres."""
    out = [line[0]]
    carry = 0.0
    for a, b in zip(line, line[1:]):
        length = (b - a).length
        while carry + length >= step:
            a = a + (b - a) * ((step - carry) / length)
            length = (b - a).length
            carry = 0.0
            out.append(a)
        carry += length
    return out


def frames(points: list) -> list:
    """(tangent, normal, binormal) at each point, the normal carried along the line without twisting."""
    out = []
    normal = Vector((1.0, 0.0, 0.0))
    for i in range(len(points)):
        t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        normal = (normal - t * normal.dot(t)).normalized()
        out.append((t, normal, t.cross(normal)))
    return out


def tube(bm: bmesh.types.BMesh, points: list, radius: float, sides: int, material: int) -> None:
    """A closed pipe along the points."""
    rings = [[bm.verts.new(p + radius * (math.cos(a) * n + math.sin(a) * b)) for a in (math.tau * k / sides for k in range(sides))]
             for p, (_, n, b) in zip(points, frames(points))]
    faces = [bm.faces.new([a[i], a[(i + 1) % sides], b[(i + 1) % sides], b[i]]) for a, b in zip(rings, rings[1:]) for i in range(sides)]
    faces += [bm.faces.new(rings[0][::-1]), bm.faces.new(rings[-1])]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for f in faces:
        f.material_index = material
        f.smooth = True


def cord(bm: bmesh.types.BMesh) -> None:
    """The coiled cord: a wire wound round the centre line in a helix."""
    line = resample(spline(CORD_PATH), PITCH / STEPS)
    turned = []
    for i, (p, (_, n, b)) in enumerate(zip(line, frames(line))):
        a = math.tau * i / STEPS
        turned.append(p + COIL * (math.cos(a) * n + math.sin(a) * b))
    tube(bm, turned, WIRE, 4, CORD)


def build() -> bpy.types.Object:
    bm = bmesh.new()
    common.slab(bm, (0.0, 0.0), (WIDTH, HEIGHT), 0.0, DEPTH, 0.012, 0.003, SHELL)
    # The handset: two cups and a grip between them, lying on the base between two posts.
    common.chamfered_box(bm, (0.0, EAR, DEPTH + 0.014), (0.05, 0.036, 0.028), 0.005, HANDSET)
    common.chamfered_box(bm, (0.0, MOUTH, DEPTH + 0.013), (0.05, 0.036, 0.026), 0.005, HANDSET)
    common.chamfered_box(bm, (0.0, 0.035, DEPTH + 0.008), (0.029, 0.072, 0.016), 0.004, HANDSET)
    for sx in (-1, 1):
        common.box(bm, (sx * 0.0215, 0.035, DEPTH + 0.009), (0.008, 0.02, 0.018), SHELL)
    common.revolve(bm, [(0.0095, 0.0), (0.0095, 0.0025), (0.0085, 0.0045), (0.0, 0.005)], (BUTTON[0], BUTTON[1], DEPTH), 12, KEY)
    cord(bm)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))  # z out of the wall -> -Y
    me = bpy.data.meshes.new("Intercom")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Intercom", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- materials ------------------------------------------------------------------------------------------

def plastic(name: str, tint: tuple, handset: bool) -> bpy.types.Material:
    """Yellowed beige plastic, greyer in patches, its edges scuffed pale and dusty on top. The base has a halo of finger
    grease round the handset; the handset is greasier, most of all along its grip, and its cups have a grille of holes
    in front."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    normal = node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs
    bevelled = node(nt, "ShaderNodeBevel", {"Radius": 0.002}, samples=8).outputs["Normal"]
    colour = lerp(nt, tuple(c * 0.86 for c in tint), tuple(c * 1.04 for c in tint), mapped(nt, noise(nt, coords, 14.0, 4.0), 0.35, 0.65, 0.0, 1.0))
    edge = mapped(nt, node(nt, "ShaderNodeVectorMath", {0: bevelled, 1: flat}, operation="DOT_PRODUCT").outputs["Value"], 1.0, 0.85, 0.0, 1.0)
    scuffs = maths(nt, "MULTIPLY", edge, mapped(nt, noise(nt, coords, 90.0, 3.0), 0.35, 0.6, 0.2, 0.8))
    colour = lerp(nt, colour, tuple(min(c * 1.3, 1.0) for c in tint), scuffs)
    plan = node(nt, "ShaderNodeCombineXYZ", {"X": xyz["X"], "Y": xyz["Z"]}).outputs["Vector"]  # across and up the base
    if handset:  # a palm and fingers: the grip most of all
        hold = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", xyz["Z"], 0.035)), 0.05, 0.012, 0.35, 1.0)
        halo = maths(nt, "MULTIPLY", hold, mapped(nt, noise(nt, coords, 45.0, 4.0), 0.3, 0.6, 0.3, 1.0))
    else:  # the base: grease in a band round where the handset is picked up and put back
        reach = maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", maths(nt, "SUBTRACT", xyz["Z"], 0.1), maths(nt, "SUBTRACT", -0.03, xyz["Z"])), 0.0)
        away = node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": xyz["X"], "Y": reach}).outputs["Vector"]}, operation="LENGTH").outputs["Value"]
        halo = maths(nt, "MULTIPLY", mapped(nt, away, 0.05, 0.022, 0.0, 0.9), mapped(nt, noise(nt, coords, 55.0, 4.0), 0.3, 0.6, 0.2, 1.0))
    colour = lerp(nt, colour, (0.38, 0.26, 0.12), maths(nt, "MULTIPLY", halo, 0.6))
    dust = maths(nt, "MULTIPLY", mapped(nt, normal["Z"], 0.3, 0.95, 0.0, 1.0), mapped(nt, noise(nt, coords, 40.0, 3.0), 0.4, 0.7, 0.1, 0.55))
    colour = lerp(nt, colour, (0.3, 0.28, 0.25), dust)
    holes = 0.0
    if handset:
        cell = node(nt, "ShaderNodeCombineXYZ", {"X": maths(nt, "FRACT", maths(nt, "DIVIDE", xyz["X"], 0.0045)), "Y": maths(nt, "FRACT", maths(nt, "DIVIDE", xyz["Z"], 0.0045))}).outputs["Vector"]
        dots = mapped(nt, node(nt, "ShaderNodeVectorMath", {0: cell, 1: (0.5, 0.5, 0.0)}, operation="DISTANCE").outputs["Value"], 0.3, 0.2, 0.0, 1.0)
        for z in (EAR, MOUTH):
            near = node(nt, "ShaderNodeVectorMath", {0: plan, 1: (0.0, z, 0.0)}, operation="DISTANCE").outputs["Value"]
            holes = maths(nt, "MAXIMUM", holes, maths(nt, "MULTIPLY", dots, mapped(nt, near, 0.0145, 0.016, 1.0, 0.0)))
        holes = maths(nt, "MULTIPLY", holes, mapped(nt, normal["Y"], -0.6, -0.9, 0.0, 1.0))  # on the faces that look out
        colour = lerp(nt, colour, (0.025, 0.02, 0.015), holes)
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.02}, samples=16, only_local=True).outputs["AO"]
    colour = lerp(nt, tuple(c * 0.45 for c in tint), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    rough = maths(nt, "ADD", 0.42, maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", halo, dust), maths(nt, "MULTIPLY", scuffs, 0.8)), 0.3))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    nt.links.new(bevelled, bsdf.inputs["Normal"])
    return mat


def key_button(name: str) -> bpy.types.Material:
    """The release button: darker, browner plastic with a key printed on it, the print half rubbed away by a thumb."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    dx = maths(nt, "SUBTRACT", xyz["X"], BUTTON[0])
    dz = maths(nt, "SUBTRACT", xyz["Z"], BUTTON[1])
    here = node(nt, "ShaderNodeCombineXYZ", {"X": dx, "Y": dz}).outputs["Vector"]

    def between(v: bpy.types.NodeSocket, lo: float, hi: float) -> bpy.types.NodeSocket:  # 1 inside lo..hi, soft edges
        return maths(nt, "MULTIPLY", mapped(nt, v, lo - 0.0004, lo, 0.0, 1.0), mapped(nt, v, hi, hi + 0.0004, 1.0, 0.0))

    bow = node(nt, "ShaderNodeVectorMath", {0: here, 1: (-0.0035, 0.0, 0.0)}, operation="DISTANCE").outputs["Value"]
    ring = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", bow, 0.0028)), 0.0011, 0.0006, 0.0, 1.0)
    shaft = maths(nt, "MULTIPLY", between(dx, -0.0007, 0.0062), between(dz, -0.0006, 0.0006))
    tooth = maths(nt, "MULTIPLY", between(dx, 0.0040, 0.0049), between(dz, -0.0025, 0.0))
    print_ = maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", ring, maths(nt, "MAXIMUM", shaft, tooth)), mapped(nt, noise(nt, coords, 220.0, 3.0), 0.35, 0.6, 0.35, 1.0))
    colour = lerp(nt, (0.34, 0.25, 0.12), (0.43, 0.33, 0.17), mapped(nt, noise(nt, coords, 60.0, 3.0), 0.35, 0.65, 0.0, 1.0))
    colour = lerp(nt, colour, (0.045, 0.03, 0.015), print_)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, noise(nt, coords, 80.0, 3.0), 0.3, 0.7, 0.35, 0.6), bsdf.inputs["Roughness"])
    return mat


def cord_material(name: str, tint: tuple) -> bpy.types.Material:
    """The cord's plastic: the base's yellow, dirtier, with dust settled between the coils."""
    mat, nt, bsdf, coords = common.surface(name)
    colour = lerp(nt, tuple(c * 0.7 for c in tint), tuple(c * 0.95 for c in tint), mapped(nt, noise(nt, coords, 50.0, 4.0), 0.35, 0.65, 0.0, 1.0))
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.006}, samples=16, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.22, 0.18, 0.1), colour, mapped(nt, dark, 0.0, 0.85, 0.0, 1.0))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, noise(nt, coords, 70.0, 3.0), 0.3, 0.7, 0.45, 0.7), bsdf.inputs["Roughness"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
intercom = build()
tint = (0.88, 0.76, 0.48)
for m in (plastic("shell", tint, False), plastic("handset", (0.84, 0.72, 0.45), True), key_button("key"), cord_material("cord", tint)):
    intercom.data.materials.append(m)
me = intercom.data
me.set_sharp_from_angle(angle=math.radians(50))
for poly in me.polygons:  # the cord is round: a four-sided wire would otherwise shade as a square one
    if poly.material_index == CORD:
        for loop in poly.loop_indices:
            me.edges[me.loops[loop].edge_index].use_edge_sharp = False
common.bake(intercom, size=256, pack=True)
common.export("intercom", [intercom])

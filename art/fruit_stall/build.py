"""The fruit stall: a closed roadside stall, the kind that sells durians by a trunk road at night. Run by
tools/models.sh.

A frame of rough sawn timber (four posts, the beams the roof rests on, two braces), a blue tarp for its roof, sagging
between the beams and hanging over the front, and another tied across the back; a plank table with a few durians left
on it and two old crates under it; three more durians hanging on raffia from the middle beam, and one bare bulb hanging
from it on its flex, which runs along the beam and down a post. Nothing is branded.

Materials, so code can tell them apart: "stall" (the timber, the durians, the raffia, the crates and the flex, coloured per vertex:
the attribute "Color"), "tarp" (coloured per vertex, seen from both sides) and "bulb" (the glass, emissive: code
dims it and turns it off). An empty, "bulb", sits at the bulb's centre for the light. The origin is on the ground at the
middle of the front edge; the open front faces -Y, which is the game's +Z.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils import noise as perlin

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ART)
import common  # noqa: E402

perlin.seed_set(3141)

BULB, STALL, TARP = 0, 1, 2  # material indices (Godot's glTF import never colours the first by vertex)
WIDTH, DEPTH = 2.3, 1.7  # between the posts' centres
FRONT_H, BACK_H = 2.22, 1.92  # the tops of the front and back beams
BEAM_Y = 0.7  # the middle beam, the bulb under it
BULB_AT = Vector((0.12, BEAM_Y, 1.8))  # the bulb's centre
TIMBER = (0.12, 0.092, 0.062)  # linear: weathered sawn timber
BLUE = (0.035, 0.1, 0.24)  # linear: a cheap blue tarp, faded


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def mix(a: tuple, b: tuple, t: float) -> tuple:
    t = min(max(t, 0.0), 1.0)
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def paint(bm: bmesh.types.BMesh, verts: list, colour, material: int = STALL, flat: bool = True) -> None:
    """The faces of the new verts: their material and colour(position) -> RGB per corner."""
    layer = bm.loops.layers.float_color["Color"]
    for f in {f for v in verts for f in v.link_faces}:
        f.material_index = material
        f.smooth = not flat
        for loop in f.loops:
            loop[layer] = (*colour(loop.vert.co), 1.0)


def weathered(base: tuple, grain: float = 30.0):
    """A colour function: base, streaked along the grain, darker low down where the rain splashes."""
    def colour(p: Vector) -> tuple:
        k = 0.82 + 0.3 * perlin.noise(Vector((p.x * 3.0, p.y * 3.0, p.z * grain))) + 0.1 * perlin.noise(p * 9.0)
        c = tuple(x * k for x in base)
        return mix(c, (0.05, 0.045, 0.035), 0.6 * smooth((0.25 - p.z) / 0.25))
    return colour


def beam(bm: bmesh.types.BMesh, a: Vector, b: Vector, w: float, h: float) -> list:
    """A timber of w by h section from a to b, a little out of true. Returns its verts."""
    axis = (b - a).normalized()
    side = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    up = side.cross(axis).normalized()
    rings = []
    for end in (a, b):
        rings.append([bm.verts.new(end + side * sx * w / 2 + up * sy * h / 2)
                      for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    lo, hi = rings
    faces = [bm.faces.new(lo[::-1]), bm.faces.new(hi)]
    faces += [bm.faces.new([lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]]) for i in range(4)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return lo + hi


def tube(bm: bmesh.types.BMesh, path: list, r: float, sides: int = 4) -> list:
    """A thin round thing along path (the flex). Returns its verts."""
    verts, rings = [], []
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        n = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = t.cross(n)
        ring = [bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r) for a in (math.tau * k / sides for k in range(sides))]
        rings.append(ring)
        verts += ring
    for a_, b_ in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new([a_[k], a_[(k + 1) % sides], b_[(k + 1) % sides], b_[k]])
    return verts


# --- the frame and the table ----------------------------------------------------------------------------

def frame(bm: bmesh.types.BMesh) -> None:
    hx, y0, y1 = WIDTH / 2, 0.0, DEPTH
    lean = {(-1, 0): (0.012, -0.008), (1, 0): (-0.006, 0.01), (-1, 1): (0.01, 0.0), (1, 1): (-0.012, 0.006)}
    for sx in (-1, 1):
        for back in (0, 1):
            x, y = sx * hx, (y1 if back else y0)
            top = BACK_H if back else FRONT_H
            dx, dy = lean[(sx, back)]
            v = beam(bm, Vector((x, y, 0.0)), Vector((x + dx, y + dy, top + 0.04)), 0.07, 0.07)
            paint(bm, v, weathered(TIMBER))
    for a, b in (((-hx - 0.12, y0, FRONT_H), (hx + 0.12, y0, FRONT_H)), ((-hx - 0.12, y1, BACK_H), (hx + 0.12, y1, BACK_H)),
                 ((-hx, y0 - 0.04, FRONT_H + 0.035), (-hx, y1 + 0.04, BACK_H + 0.035)),
                 ((hx, y0 - 0.04, FRONT_H + 0.035), (hx, y1 + 0.04, BACK_H + 0.035)),
                 ((-hx - 0.05, BEAM_Y, FRONT_H + 0.07 - (FRONT_H - BACK_H) * BEAM_Y / DEPTH),
                  (hx + 0.05, BEAM_Y, FRONT_H + 0.07 - (FRONT_H - BACK_H) * BEAM_Y / DEPTH))):
        paint(bm, beam(bm, Vector(a), Vector(b), 0.06, 0.08), weathered(TIMBER))
    for sx in (-1, 1):  # braces at the back corners
        paint(bm, beam(bm, Vector((sx * hx, y1, 1.2)), Vector((sx * (hx - 0.5), y1, BACK_H - 0.04)), 0.045, 0.03),
              weathered(TIMBER))


def table(bm: bmesh.types.BMesh) -> None:
    """Three planks on four legs, the top at 0.78 m, stained and uneven."""
    for i, (y, dz) in enumerate(((0.24, 0.0), (0.47, 0.006), (0.7, -0.004))):
        v = common.added(bm, lambda bm: common.box(bm, (0.0, y, 0.765 + dz), (2.0, 0.215, 0.026), STALL))
        paint(bm, v, lambda p: mix(weathered((0.1, 0.075, 0.05), 60.0)(p), (0.04, 0.03, 0.025),
                                   0.6 * smooth((perlin.noise(p * 4.0) - 0.1) / 0.3)))
    for x in (-0.94, 0.94):
        for y in (0.17, 0.77):
            paint(bm, beam(bm, Vector((x, y, 0.0)), Vector((x, y, 0.752)), 0.05, 0.05), weathered(TIMBER))
    paint(bm, beam(bm, Vector((-0.94, 0.77, 0.25)), Vector((0.94, 0.77, 0.25)), 0.03, 0.06), weathered(TIMBER))


def crates(bm: bmesh.types.BMesh) -> None:
    """Two old slatted crates under the table, one on the other, askew."""
    for centre, size, yaw in (((-0.45, 0.5, 0.13), (0.5, 0.36, 0.26), 0.06), ((-0.42, 0.5, 0.39), (0.5, 0.36, 0.26), -0.1)):
        v = common.added(bm, lambda bm: common.box(bm, (0, 0, 0), size, STALL))
        bmesh.ops.transform(bm, matrix=Matrix.Translation(centre) @ Matrix.Rotation(yaw, 4, "Z"), verts=v)
        paint(bm, v, lambda p: mix(weathered((0.15, 0.115, 0.07), 80.0)(p), (0.03, 0.025, 0.02),
                                   0.7 * smooth((abs(math.sin(p.z * 60.0)) - 0.75) / 0.2)))


# --- the durians ----------------------------------------------------------------------------------------

def durian(bm: bmesh.types.BMesh, centre: Vector, length: float, yaw: float, tilt: float, seed: float) -> Vector:
    """A durian (lying on its side, or hung by its stalk with tilt -pi/2): an ovoid, a little lopsided, covered in short
    sharp thorns (a lattice of points raised between hollows), olive green to brown, with its woody stalk. Returns the
    stalk's end."""
    rings, segments = 9, 20
    r = length * 0.38
    pose = Matrix.Translation(centre) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(tilt, 4, "Y")
    rows = []
    for k in range(1, rings):
        t = math.pi * k / rings  # from one end along its length (x)
        row = []
        for i in range(segments):
            a = math.tau * i / segments
            d = Vector((math.cos(t), math.sin(t) * math.cos(a), math.sin(t) * math.sin(a)))
            lump = 1.0 + 0.08 * perlin.noise(d * 2.0 + Vector((seed, 0, 0)))
            p = Vector((d.x * length / 2, d.y * r, d.z * r * 0.92)) * lump
            thorn = 1.28 if (k + i) % 2 == 0 else 0.95
            row.append(pose @ (p * thorn))
        rows.append(row)
    new = [[bm.verts.new(p) for p in row] for row in rows]
    ends = [bm.verts.new(pose @ Vector((-length / 2 * 1.04, 0, 0))), bm.verts.new(pose @ Vector((length / 2 * 1.04, 0, 0)))]
    for a_, b_ in zip(new, new[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new([a_[i], a_[j], b_[j], b_[i]])
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([new[0][j], new[0][i], ends[0]])
        bm.faces.new([new[-1][i], new[-1][j], ends[1]])
    verts = [v for row in new for v in row] + ends
    bmesh.ops.recalc_face_normals(bm, faces=list({f for v in verts for f in v.link_faces}))
    rest = Matrix.inverted(pose)

    def colour(p: Vector) -> tuple:
        q = rest @ p
        out = (Vector((q.x / (length / 2), q.y / r, q.z / r)).length - 1.0) / 0.22
        c = mix((0.12, 0.125, 0.035), (0.17, 0.14, 0.045), 0.5 + 0.8 * perlin.noise(q * 12.0 + Vector((seed, 0, 0))))
        c = mix(c, (0.075, 0.058, 0.028), smooth(out))  # the thorns' tips, brown
        return mix(c, (0.05, 0.045, 0.03), 0.5 * smooth((-q.z - r * 0.5) / (r * 0.4)))  # dirty where it lies
    paint(bm, verts, colour, flat=False)
    stalk = [pose @ Vector((length / 2 * 1.02 + s * 0.05, 0, s * 0.006)) for s in (0.0, 0.5, 1.0)]
    paint(bm, tube(bm, stalk, 0.009, 5), lambda p: (0.07, 0.06, 0.035))
    return stalk[-1]


# --- the tarp -------------------------------------------------------------------------------------------

def tarp(bm: bmesh.types.BMesh) -> None:
    """The roof: a tarp over the beams, sagging between them, hanging down over the front and the sides; and the one
    tied across the back."""
    hx = WIDTH / 2
    nx, ny = 16, 10
    x0, x1, y0, y1 = -hx - 0.32, hx + 0.32, -0.22, DEPTH + 0.18
    grid = []
    for j in range(ny + 1):
        v = j / ny
        y = y0 + (y1 - y0) * v
        row = []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            roof = FRONT_H + 0.1 - (FRONT_H - BACK_H) * (y / DEPTH)
            between = min(abs(y - 0.0), abs(y - BEAM_Y), abs(y - DEPTH))  # how far from a beam
            z = roof - 0.07 * smooth(between / 0.4) * smooth((hx - abs(x)) / 0.3)
            over = max(abs(x) - hx, 0.0)
            z -= over * 1.4 + 1.6 * max(y0 + 0.2 - y, 0.0) + 1.2 * max(y - DEPTH - 0.06, 0.0)  # hanging over the edges
            z += 0.012 * perlin.noise(Vector((x * 3.0, y * 3.0, 0.5)))
            row.append(Vector((x, y, z)))
        grid.append(row)
    verts = [[bm.verts.new(p) for p in row] for row in grid]
    for a_, b_ in zip(verts, verts[1:]):
        for i in range(nx):
            bm.faces.new([a_[i], a_[i + 1], b_[i + 1], b_[i]])
    roof = [v for row in verts for v in row]
    # the back: from the back beam nearly to the ground, tied at the posts, bellying in the middle
    back = []
    for j in range(7):
        v = j / 6
        z = BACK_H - (BACK_H - 0.35) * v
        row = []
        for i in range(11):
            u = i / 10
            x = -hx + WIDTH * u
            y = DEPTH + 0.05 + 0.07 * math.sin(math.pi * u) * math.sin(math.pi * min(v * 1.2, 1.0)) \
                + 0.015 * perlin.noise(Vector((x * 4.0, z * 4.0, 2.0)))
            row.append(bm.verts.new((x, y, z - 0.05 * math.sin(math.pi * u) * v)))
        back.append(row)
    for a_, b_ in zip(back, back[1:]):
        for i in range(10):
            bm.faces.new([a_[i], a_[i + 1], b_[i + 1], b_[i]])
    allv = roof + [v for row in back for v in row]
    bmesh.ops.recalc_face_normals(bm, faces=list({f for v in allv for f in v.link_faces}))

    def colour(p: Vector) -> tuple:
        c = mix(BLUE, (0.05, 0.1, 0.19), 0.5 + 0.8 * perlin.noise(Vector((p.x * 1.5, p.y * 1.5, p.z * 1.5))))  # sun-faded
        c = mix(c, (0.025, 0.03, 0.035), 0.6 * smooth((perlin.noise(Vector((p.x * 6.0, p.y * 1.0, p.z * 6.0))) - 0.15) / 0.3))  # grime
        return mix(c, (0.03, 0.03, 0.03), 0.5 * smooth((0.6 - p.z) / 0.3))  # mud at the bottom of the back
    paint(bm, allv, colour, TARP, flat=False)


# --- the bulb -------------------------------------------------------------------------------------------

def light(bm: bmesh.types.BMesh) -> None:
    """The bare bulb on its flex: the flex from the middle beam down to a black socket, the pear of glass under it;
    the flex runs along the beam and down the right post to the ground."""
    beam_z = FRONT_H + 0.07 - (FRONT_H - BACK_H) * BEAM_Y / DEPTH - 0.04
    top = Vector((BULB_AT.x, BEAM_Y, beam_z))
    socket = BULB_AT + Vector((0, 0, 0.045))
    flex = [top, top + Vector((0, 0, -0.08)), socket + Vector((0, 0, 0.03))]
    run = [top, Vector((0.6, BEAM_Y + 0.02, beam_z - 0.05)), Vector((1.1, BEAM_Y + 0.03, beam_z - 0.02)),
           Vector((WIDTH / 2 - 0.05, BEAM_Y + 0.05, beam_z - 0.12)), Vector((WIDTH / 2 - 0.06, 0.05, 1.6)),
           Vector((WIDTH / 2 - 0.05, -0.045, 1.0)), Vector((WIDTH / 2 - 0.05, -0.045, 0.1)), Vector((WIDTH / 2 + 0.25, -0.2, 0.01))]
    black = lambda p: (0.012, 0.012, 0.012)  # noqa: E731
    paint(bm, tube(bm, flex, 0.004), black)
    paint(bm, tube(bm, run, 0.004), black)
    v = common.added(bm, lambda bm: common.revolve(bm, [(0.017, -0.025), (0.017, 0.025), (0.008, 0.032), (0.0, 0.033)],
                                                  tuple(socket), 8, STALL))
    paint(bm, v, black)
    v = common.added(bm, lambda bm: common.revolve(bm, [(0.014, 0.022), (0.018, 0.005), (0.03, -0.015), (0.03, -0.035),
                                                       (0.018, -0.055), (0.0, -0.06)], tuple(BULB_AT + Vector((0, 0, 0.03))), 10, BULB))
    paint(bm, v, lambda p: (1.0, 1.0, 1.0), BULB, flat=False)


def material(name: str, roughness: float, double: bool = False) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_backface_culling = not double
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def bulb_material() -> bpy.types.Material:
    """"bulb": warm glass, lit."""
    mat = bpy.data.materials.new("bulb")
    mat.use_backface_culling = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (1.0, 0.8, 0.55, 1.0)
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.52, 0.2, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 3.0  # warm, not clipped to white
    bsdf.inputs["Roughness"].default_value = 0.2
    return mat


common.reset()
bm = bmesh.new()
bm.loops.layers.float_color.new("Color")
frame(bm)
table(bm)
crates(bm)
for i, (x, y, z, length, yaw, tilt) in enumerate(((-0.62, 0.38, 0.0, 0.27, 0.3, 0.0), (-0.3, 0.52, 0.0, 0.24, -0.5, 0.05),
                                                  (0.08, 0.4, 0.0, 0.29, 1.4, -0.04), (0.42, 0.56, 0.0, 0.25, 0.9, 0.0),
                                                  (0.25, 0.47, 0.17, 0.23, -0.2, 0.25))):
    durian(bm, Vector((x, y, 0.778 + length * 0.36 + z)), length, yaw, tilt, i * 7.0)
beam_under = FRONT_H + 0.07 - (FRONT_H - BACK_H) * BEAM_Y / DEPTH - 0.04
for i, (x, drop, length, yaw) in enumerate(((-0.75, 0.3, 0.26, 0.4), (-0.5, 0.42, 0.24, 2.1), (0.45, 0.34, 0.27, -1.0))):
    top = durian(bm, Vector((x, BEAM_Y, beam_under - drop - length / 2)), length, yaw, -math.pi / 2, 40.0 + i * 7.0)
    raffia = [top, Vector((x + 0.006, BEAM_Y - 0.004, (top.z + beam_under) / 2)), Vector((x, BEAM_Y, beam_under + 0.01))]
    paint(bm, tube(bm, raffia, 0.0035, 3), lambda p: (0.27, 0.21, 0.11))  # tied round the beam
tarp(bm)
light(bm)
stall = common.mesh_object("FruitStall", bm, [bulb_material(), material("stall", 0.82), material("tarp", 0.55, double=True)])
bulb = bpy.data.objects.new("bulb", None)
bulb.location = BULB_AT
bpy.context.scene.collection.objects.link(bulb)
print("FRUIT_STALL tris", sum(len(p.vertices) - 2 for p in stall.data.polygons), [m.name for m in stall.data.materials])
common.export("fruit_stall", [stall, bulb])

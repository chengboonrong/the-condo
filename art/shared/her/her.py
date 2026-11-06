"""Her: the woman who is the penanggal by night and the fourth passenger by day. Shared by art/penanggal and art/fourth,
so the two have the same face and the same hair.

Head space is metres, the origin at the centre of the skull, her face towards -Y, her left +X, up +Z (Blender). The
skin is one closed surface shaped in code (surface()): a woman's head, gaunt, the eyes wide in deep sockets and the
mouth a little open. It is built dense and then decimated, so the lids and the parted lips keep their edges. Its
colour is one painted texture (texture(), saved beside this file as Her_skin.png), projected from the front. The eyes
are balls in the sockets, coloured per vertex. The hair is a shell on the scalp and wet clumps (ribbons) that run down
from a centre parting under gravity until the head curves away beneath them, and then hang. hair(pose) drapes them for
the head posed in model space, so the same hair falls round her face in one model and over it in the other.

Materials: "skin", "eyes", "hair" (seen from both sides). Every part carries a colour attribute, "Color" (white where
it means nothing), so the parts can be joined with ones coloured per vertex.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils import noise as perlin

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [os.path.join(os.path.dirname(HERE), "apron")]
from apron import _fbm, _over, _smooth  # noqa: E402  the shared texture helpers

perlin.seed_set(611)

# The skull: a superellipsoid, half width, half depth to the front and to the back, half height up and down.
CRANIUM = (0.073, 0.094, 0.096, 0.102, 0.08)
# The face: its front (y) at the midline by height, without the nose; how fast it turns back at the sides (A x^2 + B x^4)
# by height; its half width by height (cheekbones, jaw, chin); the jaw's underside (z) by depth (y). From the proportions
# of a woman's head, measured; then narrowed a little and hollowed to make her gaunt.
PROFILE = [(0.045, -0.088), (0.02, -0.094), (0.0, -0.095), (-0.035, -0.096), (-0.05, -0.102), (-0.064, -0.106),
           (-0.075, -0.103), (-0.085, -0.101), (-0.095, -0.094), (-0.106, -0.095), (-0.117, -0.087), (-0.127, -0.072)]
TURN = [(0.045, 2.5, 2600.0), (0.02, 2.0, 2100.0), (-0.035, 2.6, 1200.0), (-0.075, 14.0, 0.0), (-0.1, 18.0, 0.0), (-0.127, 26.0, 0.0)]
WIDTH = [(0.045, 0.07), (0.0, 0.068), (-0.035, 0.066), (-0.06, 0.059), (-0.085, 0.05), (-0.105, 0.037), (-0.12, 0.023),
         (-0.132, 0.01)]
JAW = [(-0.1, -0.132), (-0.085, -0.127), (-0.05, -0.113), (-0.01, -0.101), (0.02, -0.088), (0.04, -0.07)]
EYE = Vector((0.033, -0.073, -0.005))  # her left eyeball's centre; the right one mirrors it
EYE_R = 0.012
MEDIAL, LATERAL = (0.0195, -0.0068), (0.0478, -0.0028)  # the corners of her left eye's opening (x, z)
LID_UP, LID_DOWN = 0.0069, 0.0051  # how far the open lids stand above and below the line between the corners
MOUTH_Z, MOUTH_W, MOUTH_OPEN = -0.0735, 0.0245, 0.0055  # the line between the lips, the corners' x, the gap at the middle
TEX_W, TEX_H = 192, 384  # the skin texture, projected from the front over x -0.1..0.1, z -0.27..0.13
TEX_X, TEX_Z = (-0.1, 0.1), (-0.27, 0.13)

SKIN = (0.5, 0.47, 0.425)  # sRGB: grey-pale, the colour drained out of a Malay woman's skin
HAIR = (0.011, 0.01, 0.0105)  # linear
WHITE = (1.0, 1.0, 1.0, 1.0)


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def bump(d: float, width: float) -> float:
    return math.exp(-(d / width) ** 2)


# --- the head's surface -----------------------------------------------------------------------------------

def almond(x: float, z: float) -> float:
    """How far (x, z) is outside her left eye's opening, in metres (negative inside). x is taken as |x|."""
    x = abs(x)
    t = (x - MEDIAL[0]) / (LATERAL[0] - MEDIAL[0])
    tc = min(max(t, 0.0), 1.0)
    line = MEDIAL[1] + (LATERAL[1] - MEDIAL[1]) * tc
    s = math.sin(math.pi * tc)
    upper = line + LID_UP * s ** 0.75 * (1.0 + 0.2 * (0.5 - tc))  # the upper lid peaks a little towards the nose
    lower = line - LID_DOWN * s ** 0.9
    d = max(lower - z, z - upper)
    if t < 0:
        d = max(d, MEDIAL[0] - x)
    elif t > 1:
        d = max(d, x - LATERAL[0])
    return d


def above_line(x: float, z: float) -> bool:
    t = min(max((abs(x) - MEDIAL[0]) / (LATERAL[0] - MEDIAL[0]), 0.0), 1.0)
    return z > MEDIAL[1] + (LATERAL[1] - MEDIAL[1]) * t


def ball_front(x: float, z: float) -> float | None:
    """The y of her left eyeball's front at (|x|, z), seen from the front, or None off it."""
    dx, dz = abs(x) - EYE.x, z - EYE.z
    q = EYE_R ** 2 - dx * dx - dz * dz
    return EYE.y - math.sqrt(q) if q > 0 else None


def mouth(x: float) -> tuple:
    """The parted lips at |x|: the middle of the gap (z) and its height."""
    t = min(abs(x) / MOUTH_W, 1.0)
    return MOUTH_Z - 0.0035 * t * t, MOUTH_OPEN * max(1.0 - t * t, 0.0) ** 0.7


def table(rows_: list, key: float, column: int = 1) -> float:
    """Linear interpolation in rows_ [(key, value, ...)] sorted by key, either order; clamped at the ends."""
    rs = rows_ if rows_[0][0] < rows_[-1][0] else rows_[::-1]
    if key <= rs[0][0]:
        return rs[0][column]
    for a, b in zip(rs, rs[1:]):
        if key <= b[0]:
            t = (key - a[0]) / (b[0] - a[0])
            return a[column] + (b[column] - a[column]) * t
    return rs[-1][column]


def smin(a: float, b: float, k: float) -> float:
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k / 4


def smax(a: float, b: float, k: float) -> float:
    return -smin(-a, -b, k)


def solid(p: Vector) -> float:
    """Below 0 inside the head (not its features), about in metres: the skull and the face block, smoothly joined."""
    a, bf, bb, cu, cd = CRANIUM
    n, m = 2.2, 2.25
    g = ((abs(p.x) / a) ** n + (abs(p.y) / (bf if p.y < 0 else bb)) ** n) ** (m / n) + (abs(p.z) / (cu if p.z > 0 else cd)) ** m
    skull = (g ** (1 / m) - 1.0) * 0.09
    x, z = abs(p.x), p.z
    front = table(PROFILE, z) + table(TURN, z) * x * x + table(TURN, z, 2) * x ** 4
    face = smax(front - p.y, x - table(WIDTH, z), 0.012)
    face = smax(face, table(JAW, p.y) - z, 0.01)  # the jaw's underside
    face = smax(face, p.y - 0.03, 0.02)  # back to the jaw's angle
    face = smax(face, z - 0.035, 0.02)  # up to the brow
    return smin(skull, face, 0.014)


def surface(direction: Vector) -> Vector:
    """The skin, from the centre of the skull in the direction given: a narrow skull, fuller at the back; a flat face
    narrowing to a small jaw and chin; a soft brow, deep orbits, high cheekbones over hollow cheeks and temples, a low
    broad nose and thin lips, a little open; the eyelids drawn wide over the eyeballs."""
    d = direction.normalized()
    lo, hi = 0.02, 0.2
    for _ in range(24):
        mid = (lo + hi) / 2
        if solid(d * mid) < 0:
            lo = mid
        else:
            hi = mid
    p = d * lo
    front = smooth(-d.y * 1.8)  # the face only
    x, z = abs(p.x), p.z
    out = 0.0
    out += 0.0025 * bump(z - 0.018, 0.009) * smooth((0.05 - x) / 0.02)  # brow
    out -= 0.0025 * bump(x, 0.008) * bump(z + 0.004, 0.007)  # the root of the nose, between the eyes
    out -= 0.008 * bump(x - EYE.x, 0.016) * bump(z - EYE.z, 0.013)  # orbits
    out -= 0.003 * bump(x - 0.034, 0.011) * bump(z - 0.01, 0.005)  # hollow under the brow
    out -= 0.0025 * bump(x - 0.03, 0.013) * bump(z + 0.023, 0.005)  # tear trough
    out += 0.005 * bump(x - 0.051, 0.012) * bump(z + 0.028, 0.01)  # cheekbones
    out -= 0.009 * bump(x - 0.046, 0.014) * bump(z + 0.062, 0.018)  # hollow cheeks
    # the nose: the bridge rising from its root to the tip, its underside turning back to the lip; broad wings
    ridge = (0.0005 + 0.0205 * smooth((-0.006 - z) / 0.03) ** 1.5) * smooth((z + 0.051) / 0.012)
    out += ridge * bump(x, 0.0065 + 0.006 * smooth((-0.01 - z) / 0.03))
    out += 0.006 * bump(x - 0.0135, 0.006) * bump(z + 0.045, 0.006)  # wings
    out -= 0.0018 * bump(x - 0.0195, 0.0018) * bump(z + 0.045, 0.006)  # the crease round each wing
    out -= 0.001 * bump(x, 0.0035) * bump(z + 0.058, 0.007)  # philtrum
    out += 0.0016 * bump(x, 0.02) * bump(z + 0.0695, 0.0026)  # upper lip
    out += 0.0024 * bump(x, 0.019) * bump(z + 0.079, 0.0033)  # lower lip
    out += 0.0025 * bump(x, 0.014) * bump(z + 0.106, 0.008)  # chin
    # the folds from the nose's wings to the corners of the mouth
    t = min(max((z + 0.047) / -0.028, 0.0), 1.0)
    out -= 0.002 * bump(abs(x - (0.021 + 0.007 * t)), 0.0025) * (1.0 if -0.077 < z < -0.045 else 0.0)
    p.y -= out * front
    if p.y < 0:  # hollow temples
        p.x -= math.copysign(0.004 * bump(z - 0.015, 0.02) * bump(p.y + 0.05, 0.02) * smooth((abs(p.x) - 0.055) / 0.01), p.x)
    if front > 0.5:
        p.y = _lidded(x, z, p.y)
        mz, gap = mouth(x)
        if gap > 0:
            p.y += 0.012 * smooth((gap / 2 - abs(z - mz)) / 0.0024)  # into the mouth
    return p


def _lidded(x: float, z: float, y: float) -> float:
    """y where the eyelids lie over the eyeball, and inside the opening, back behind the ball."""
    e = almond(x, z)
    if e > 0.009:
        return y
    yb = ball_front(x, z)
    if e < 0:
        return max(y, (yb if yb is not None else EYE.y) + 0.0035 * smooth(-e / 0.0005))
    zone = 0.0065 if above_line(x, z) else 0.0042
    thick = 0.0011 + 0.0008 * smooth(e / 0.001)
    lid = (yb if yb is not None else EYE.y + 0.002) - thick
    lidded = min(y, lid)
    if above_line(x, z):  # the upper lid's crease
        lidded += 0.0008 * bump(e - 0.0052, 0.0012)
    return lidded + (y - lidded) * smooth(e / zone)


def rows(offset=None, segments: int = 220, rings: int = 170) -> list:
    """Rings of points over the head (crown last), each moved by offset(direction, point) if given."""
    out = []
    for k in range(1, rings):
        t = math.pi * (1 - k / rings)
        row = []
        for i in range(segments):
            a = math.tau * i / segments
            d = Vector((math.sin(t) * math.sin(a), -math.sin(t) * math.cos(a), math.cos(t)))  # a = 0 is the face
            p = surface(d)
            row.append(offset(d, p) if offset else p)
        out.append(row)
    return out


def normal_at(d: Vector, f=surface, h: float = 0.004) -> Vector:
    """The outward normal of the surface f at the direction d."""
    d = d.normalized()
    a = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
    b = d.cross(a)
    n = (f(d + a * h) - f(d - a * h)).cross(f(d + b * h) - f(d - b * h)).normalized()
    return n if n.dot(f(d)) > 0 else -n


# --- building blocks ------------------------------------------------------------------------------------

def grid(bm: bmesh.types.BMesh, rows_: list, material: int, colour=None) -> None:
    """A closed surface from rings of points into bm: quads between rings, the first and last closed with a fan."""
    rings = [[bm.verts.new(p) for p in row] for row in rows_]
    n = len(rows_[0])
    faces = []
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new([a[i], a[j], b[j], b[i]]))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        c = bm.verts.new(sum((v.co for v in ring), Vector()) / n)
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new([ring[j], ring[i], c] if flip else [ring[i], ring[j], c]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    paint(bm, faces, material, colour)


def paint(bm: bmesh.types.BMesh, faces: list, material: int, colour=None) -> None:
    """Sets the faces' material, smooth shading and colour attribute: colour(position) -> RGBA, or white."""
    layer = bm.loops.layers.float_color.get("Color") or bm.loops.layers.float_color.new("Color")
    for f in faces:
        f.material_index = material
        f.smooth = True
        for loop in f.loops:
            loop[layer] = colour(loop.vert.co) if colour else WHITE


def new_bmesh() -> bmesh.types.BMesh:
    bm = bmesh.new()
    bm.loops.layers.float_color.new("Color")
    return bm


def to_object(name: str, bm: bmesh.types.BMesh, materials: list) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in materials:
        me.materials.append(m)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def decimate(obj: bpy.types.Object, tris: int) -> None:
    """Collapses obj down to about tris triangles, keeping it symmetric across X, and gives it the dense surface's
    normals, so its flat facets still shade as the smooth head."""
    have = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if have <= tris:
        return
    dense = obj.copy()
    dense.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(dense)
    mod = obj.modifiers.new("fewer", "DECIMATE")
    mod.ratio = tris / have
    mod.use_symmetry = True
    mod.symmetry_axis = "X"
    _apply(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    normals = obj.modifiers.new("normals", "DATA_TRANSFER")
    normals.object = dense
    normals.use_loop_data = True
    normals.data_types_loops = {"CUSTOM_NORMAL"}
    normals.loop_mapping = "POLYINTERP_NEAREST"
    _apply(obj)
    bpy.data.meshes.remove(dense.data)


def _apply(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")


def front_uv(obj: bpy.types.Object, head: Matrix = Matrix()) -> None:
    """Gives obj the skin texture's projection from the front, through head space (head maps it into obj's space)."""
    me = obj.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    inverse = head.inverted()
    for loop in me.loops:
        p = inverse @ me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((p.x - TEX_X[0]) / (TEX_X[1] - TEX_X[0]), (p.z - TEX_Z[0]) / (TEX_Z[1] - TEX_Z[0]))


# --- the head -------------------------------------------------------------------------------------------

def head(name: str, tris: int, pose: Matrix = Matrix()) -> bpy.types.Object:
    """Her skin, about tris triangles, posed into model space by pose. Material 0 is "skin"."""
    bm = new_bmesh()
    grid(bm, rows(), 0)
    obj = to_object(name, bm, [skin_material()])
    decimate(obj, tris)
    front_uv(obj)
    obj.data.transform(pose)
    return obj


def eyes(name: str, pose: Matrix = Matrix()) -> bpy.types.Object:
    """Her eyeballs, staring straight ahead: a greyed, bloodshot white, the iris near black, the pupil wide. Material 0
    is "eyes"."""
    bm = new_bmesh()
    for side in (1, -1):
        centre = Vector((side * EYE.x, EYE.y, EYE.z))
        rings_, segments = 9, 14
        pts = []
        for k in range(1, rings_):
            t = math.pi * k / rings_  # from the front pole
            r = EYE_R * (1.0 + 0.07 * smooth((0.55 - t) / 0.25))  # the cornea stands out over the iris
            pts.append([centre + r * Vector((math.sin(t) * math.cos(a), -math.cos(t), math.sin(t) * math.sin(a)))
                        for a in (math.tau * i / segments for i in range(segments))])
        rings = [[bm.verts.new(p) for p in row] for row in pts]
        tip, back = bm.verts.new(centre + Vector((0, -EYE_R * 1.07, 0))), bm.verts.new(centre + Vector((0, EYE_R, 0)))
        faces = []
        for i in range(segments):
            j = (i + 1) % segments
            faces.append(bm.faces.new([tip, rings[0][j], rings[0][i]]))
            faces.append(bm.faces.new([back, rings[-1][i], rings[-1][j]]))
        for a, b in zip(rings, rings[1:]):
            for i in range(segments):
                j = (i + 1) % segments
                faces.append(bm.faces.new([a[i], a[j], b[j], b[i]]))
        bmesh.ops.recalc_face_normals(bm, faces=faces)

        def colour(p: Vector, centre=centre) -> tuple:
            q = (p - centre).normalized()
            t = math.acos(max(min(-q.y, 1.0), -1.0))  # angle from the front
            pupil, iris = 0.27, 0.5
            if t < pupil:
                return (0.004, 0.003, 0.003, 1.0)
            if t < iris:
                ring = smooth((t - iris + 0.08) / 0.08)  # the dark ring at its edge
                c = (0.03 - 0.02 * ring, 0.017 - 0.012 * ring, 0.01 - 0.007 * ring)
                return (*c, 1.0)
            red = smooth((t - 0.9) / 0.7)  # bloodshot towards the corners
            return (0.3 - 0.06 * red, 0.27 - 0.17 * red, 0.21 - 0.13 * red, 1.0)
        paint(bm, faces, 0, colour)
    obj = to_object(name, bm, [eyes_material()])
    obj.data.transform(pose)
    return obj


# --- the hair -------------------------------------------------------------------------------------------

def hairline(a: float) -> float:
    """How low the hair comes at the angle a round the head (0 the face, pi the nape): a high, rounded forehead, down
    over the temples and in front of the ears, and low at the nape."""
    a = abs(math.remainder(a, math.tau))
    keys = [(0.0, 0.067), (0.45, 0.062), (0.85, 0.044), (1.15, 0.022), (1.42, -0.022), (1.8, -0.035), (2.4, -0.066),
            (math.pi, -0.078)]
    for (a0, z0), (a1, z1) in zip(keys, keys[1:]):
        if a <= a1:
            return z0 + (z1 - z0) * smooth((a - a0) / (a1 - a0))
    return keys[-1][1]


def scalp(d: Vector) -> Vector:
    """Where the wet hair lies: a few mm off the skin inside the hairline, a mm off it outside (strands on the face)."""
    p = surface(d)
    a = math.atan2(d.x, -d.y)
    inside = smooth((p.z - hairline(a)) / 0.006)
    return p + d.normalized() * (0.0012 + 0.0035 * inside)


def shell(tris: int, pose: Matrix = Matrix()) -> bpy.types.Object:
    """The hair flat on the scalp, wet: clinging, with grooves where it parts into clumps; tucked inside the head below
    the hairline."""
    def offset(d: Vector, p: Vector) -> Vector:
        a = math.atan2(d.x, -d.y)
        edge = p.z - hairline(a)
        if edge < 0:
            return p * 0.95
        grooves = 0.0012 * perlin.noise(Vector((a * 9.0, p.z * 3.0, 2.2)))
        part = 0.0015 * bump(p.x, 0.0025) * smooth((p.z - 0.06) / 0.02) * (1.0 if p.y < 0.04 else 0.0)  # the parting
        return p + d * (0.0042 * smooth(edge / 0.008) + grooves - part)
    bm = new_bmesh()
    grid(bm, rows(offset, 96, 64), 0)
    obj = to_object("hair_shell", bm, [hair_material()])
    decimate(obj, tris)
    obj.data.transform(pose)
    return obj


def roots(count: int, seed: int = 3) -> list:
    """Directions inside the hairline for count clumps, spread evenly (a Fibonacci lattice)."""
    out = []
    n = count * 4
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        a = i * math.pi * (3 - math.sqrt(5)) + seed
        d = Vector((math.sqrt(1 - z * z) * math.sin(a), -math.sqrt(1 - z * z) * math.cos(a), z))
        p = surface(d)
        if p.z > hairline(math.atan2(d.x, -d.y)) + 0.004:
            out.append(d)
    step = max(len(out) / count, 1.0)
    return [out[int(k * step)] for k in range(min(count, len(out)))]


def comb(p: Vector) -> Vector:
    """Which way the hair is combed at p (head space): away from a centre parting and a little back, on the top and
    the front of the head; nothing at the back."""
    if p.z < 0.0 or p.y > 0.05:
        return Vector()
    side = 1.0 if p.x >= 0 else -1.0
    return Vector((side, 0.15, 0.0)) * smooth((0.05 - p.y) / 0.06)


def strand(root: Vector, pose: Matrix, length: float, colliders: list, seed: float, plastered: Vector | None = None,
           combed: float = 1.4) -> list:
    """The path of one clump: (model-space point, outward normal) pairs from its root. It runs down the scalp (head
    space) the way gravity and the comb take it, until the head curves away beneath it, then hangs free (model space),
    kept out of the colliders [(a, b, radius)], capsules. plastered: a comb direction of its own, for strands stuck
    across the face. combed: how strongly the parting holds the hair against gravity."""
    rot = pose.to_3x3()
    g = (rot.inverted() @ Vector((0, 0, -1))).normalized()  # gravity in head space
    d = root.normalized()
    path, s = [], 0.0
    while s < length:
        p = scalp(d)
        n = normal_at(d, scalp)
        path.append((pose @ p, (rot @ n).normalized()))
        if n.dot(g) > 0.3 and s > 0.01:
            break
        tangent = g - n * g.dot(n)
        c = plastered if plastered is not None else comb(p)
        c = c - n * c.dot(n)
        w = combed if plastered is None else 1.6 * math.exp(-s / 0.09)
        step = tangent * (1.0 if tangent.length > 1e-4 else 0.0) + c * w
        if step.length < 1e-5:
            break
        d = (p + step.normalized() * 0.015).normalized()
        s += 0.015
    # free: straight down, with the slow kinks of wet hair, out of the colliders
    centre = pose @ Vector()
    q = path[-1][0].copy()
    seg = 0.034
    while s < length:
        k = s * 7.0
        q = q + Vector((0, 0, -seg)) + Vector((perlin.noise(Vector((k, seed, 0.3))), perlin.noise(Vector((k, seed, 5.1))), 0)) * 0.006
        for a, b, r in colliders:
            ab = b - a
            t = min(max((q - a).dot(ab) / ab.length_squared, 0.0), 1.0)
            c = a + ab * t
            off = q - c
            if off.length < r:
                q = c + (off.normalized() if off.length > 1e-6 else Vector((1, 0, 0))) * r
        outward = Vector((q.x - centre.x, q.y - centre.y, 0.0))
        path.append((q.copy(), outward.normalized() if outward.length > 1e-4 else path[-1][1]))
        s += seg
    return path


def ribbon(bm: bmesh.types.BMesh, path: list, width: float, material: int, flat: bool = False) -> None:
    """A clump of wet hair along path [(point, normal)]: a strip with a raised middle, narrowing to a point. flat: barely
    raised, a few hairs stuck to the skin."""
    n = len(path)
    if n < 2:
        return
    ringset = []
    for i, (p, nrm) in enumerate(path):
        t = (path[min(i + 1, n - 1)][0] - path[max(i - 1, 0)][0]).normalized()
        side = t.cross(nrm).normalized()
        u = i / (n - 1)
        w = width * (1.0 - u ** 1.6) ** 0.8 + 0.0008
        lift = nrm * ((0.0005 + 0.08 * w) if flat else (0.0012 + 0.25 * w))
        ringset.append([bm.verts.new(p - side * w / 2), bm.verts.new(p + lift), bm.verts.new(p + side * w / 2)])
    faces = []
    for a, b in zip(ringset, ringset[1:]):
        faces.append(bm.faces.new([a[0], a[1], b[1], b[0]]))
        faces.append(bm.faces.new([a[1], a[2], b[2], b[1]]))
    paint(bm, faces, material)


def hair(pose: Matrix, count: int, length: tuple, colliders: list, shell_tris: int, plastered: list = (),
         combed: float = 1.4, parting: bool = True) -> list:
    """Her hair for the head posed into model space by pose: the shell and count clumps, each length[0] to length[1]
    long from its root. plastered: (root direction, comb direction) of strands stuck across the face. combed: how
    strongly the parting holds the hair (low: it falls where gravity takes it, over her face when she bows her head).
    parting: keep the parting bare (no clumps grow from it)."""
    bm = new_bmesh()
    rng = np.random.default_rng(29)
    for i, d in enumerate(roots(count)):
        p = surface(d)
        if parting and abs(p.x) < 0.012 and p.y < 0.03 and p.z > 0.05:  # nothing grows out of the parting itself
            continue
        ribbon(bm, strand(d, pose, rng.uniform(*length), colliders, i * 1.7, combed=combed), rng.uniform(0.01, 0.019), 0)
    for i, (d, c) in enumerate(plastered):
        ribbon(bm, strand(d, pose, rng.uniform(*length), colliders, 50 + i, plastered=c), 0.0045, 0, flat=True)
    clumps = to_object("hair", bm, [hair_material()])
    return [shell(shell_tris, pose), clumps]


# --- materials ------------------------------------------------------------------------------------------

def _material(name: str) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_backface_culling = True  # glTF: one-sided
    return mat


def skin_material() -> bpy.types.Material:
    """"skin": the painted texture, clammy (a little glossy)."""
    if bpy.data.materials.get("skin"):
        return bpy.data.materials["skin"]
    mat = _material("skin")
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = texture()
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.5
    return mat


def plain_skin_material() -> bpy.types.Material:
    """"skin" without the texture: its average colour, for where her face is never seen."""
    mat = _material("skin")
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*(c ** 2.2 for c in SKIN), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.5
    return mat


def eyes_material() -> bpy.types.Material:
    """"eyes": the colour per vertex, wet."""
    mat = _material("eyes")
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.12
    return mat


def hair_material() -> bpy.types.Material:
    """"hair": black, wet, seen from both sides."""
    mat = bpy.data.materials.get("hair")
    if mat:
        return mat
    mat = _material("hair")
    mat.use_backface_culling = False
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*HAIR, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.3
    return mat


# --- the texture ----------------------------------------------------------------------------------------

def texture() -> bpy.types.Image:
    """Paints the skin, saves it as art/shared/her/Her_skin.png and returns it. Projected from the front: the colour
    at (x, z) in head space lies on whatever skin is there, front or back."""
    rng = np.random.default_rng(611)
    zz, xx = np.meshgrid(TEX_Z[0] + (np.arange(TEX_H) + 0.5) / TEX_H * (TEX_Z[1] - TEX_Z[0]),
                         TEX_X[0] + (np.arange(TEX_W) + 0.5) / TEX_W * (TEX_X[1] - TEX_X[0]), indexing="ij")  # rows bottom first
    ax = np.abs(xx)
    colour = np.broadcast_to(np.array(SKIN), xx.shape + (3,)).copy()
    blotch = _fbm(rng, xx, zz, 60.0, 4)
    colour *= (0.93 + 0.12 * blotch)[..., None]
    colour = _over(colour, (0.5, 0.5, 0.52), 0.25 * _smooth((_fbm(rng, xx, zz, 25.0) - 0.45) / 0.2))  # grey, bloodless
    # veins: faint blue-grey threads at the temples, round the eyes and on the throat
    vein = np.abs(_fbm(rng, xx * 1.3, zz, 70.0, 3) - 0.5)
    where = np.exp(-((ax - 0.06) / 0.02) ** 2 - ((zz - 0.03) / 0.03) ** 2) + np.exp(-((ax - 0.04) / 0.02) ** 2 - ((zz + 0.01) / 0.012) ** 2) \
        + 0.8 * _smooth((-0.12 - zz) / 0.03)
    colour = _over(colour, (0.36, 0.4, 0.48), 0.5 * where * _smooth((0.035 - vein) / 0.03))
    # sunken, bruised hollows: round the eyes, under the cheekbones
    e = np.vectorize(almond)(xx, zz)
    colour = _over(colour, (0.34, 0.27, 0.29), 0.75 * _smooth((0.016 - e) / 0.014) * (0.8 + 0.4 * blotch))
    colour = _over(colour, (0.42, 0.36, 0.36), 0.35 * np.exp(-((ax - 0.046) / 0.016) ** 2 - ((zz + 0.062) / 0.02) ** 2))
    # the lid margins, wet and reddened, and the eyes' corners
    colour = _over(colour, (0.5, 0.28, 0.28), 0.8 * np.exp(-(e / 0.0009) ** 2))
    colour = _over(colour, (0.45, 0.22, 0.22), 0.8 * np.exp(-((ax - MEDIAL[0] - 0.002) / 0.003) ** 2 - ((zz - MEDIAL[1]) / 0.003) ** 2))
    # thin dark brows, sparse
    t = np.clip((ax - 0.013) / 0.045, 0, 1)
    brow_z = 0.0105 + 0.0065 * np.sin(np.pi * (0.2 + 0.7 * t)) - 0.002 * t
    brow = np.exp(-((zz - brow_z) / (0.003 * (1.25 - 0.6 * t))) ** 2) * _smooth((ax - 0.012) / 0.004) * _smooth((0.06 - ax) / 0.008)
    hairs = _smooth((_fbm(rng, xx * 0.25, zz * 4.0, 300.0, 2) - 0.35) / 0.3)
    colour = _over(colour, (0.13, 0.11, 0.105), 0.7 * brow * (0.55 + 0.45 * hairs))
    # the nose: shade at its wings, the nostrils dark beneath it
    colour = _over(colour, (0.4, 0.33, 0.33), 0.5 * np.exp(-((ax - 0.0195) / 0.003) ** 2 - ((zz + 0.045) / 0.006) ** 2))
    colour = _over(colour, (0.07, 0.04, 0.04), 0.95 * np.exp(-((ax - 0.008) / 0.0035) ** 2 - ((zz + 0.049) / 0.0022) ** 2))
    # the lips: dry, grey-mauve, cracked; the gap between them black
    mz = MOUTH_Z - 0.0035 * np.clip(ax / MOUTH_W, 0, 1) ** 2
    lips = np.exp(-((zz + 0.0695) / 0.0032) ** 2) * _smooth((0.022 - ax) / 0.004) + np.exp(-((zz + 0.079) / 0.0042) ** 2) * _smooth((0.021 - ax) / 0.004)
    colour = _over(colour, (0.42, 0.3, 0.33), 0.8 * lips)
    cracks = _smooth((0.04 - np.abs(_fbm(rng, xx * 6.0, zz * 0.3, 400.0, 2) - 0.5)) / 0.03)
    colour = _over(colour, (0.25, 0.14, 0.15), 0.6 * lips * cracks)
    gap = MOUTH_OPEN * np.clip(1 - (ax / MOUTH_W) ** 2, 0, 1) ** 0.7
    colour = _over(colour, (0.03, 0.015, 0.015), _smooth((gap / 2 + 0.0012 - np.abs(zz - mz)) / 0.0012) * (ax < MOUTH_W + 0.001))
    # blood: at the corners of the mouth and the lower lip, run down the chin and the throat
    blood = np.exp(-((ax - 0.021) / 0.003) ** 2 - ((zz - mz) / 0.004) ** 2) + 0.7 * np.exp(-((zz + 0.081) / 0.003) ** 2) * _smooth((0.012 - ax) / 0.006)
    wobble = 0.006 * (_fbm(rng, xx * 0.1, zz, 18.0) - 0.5)
    for cx, top, length, w in ((0.021, -0.076, 0.085, 0.0026), (-0.019, -0.077, 0.045, 0.002), (-0.002, -0.084, 0.15, 0.0032)):
        along = np.clip((top - zz) / length, 0, 1)
        run = _smooth((top - zz) / 0.004) * _smooth((zz - top + length) / 0.015) * np.exp(-((xx - cx - wobble * along) / (w * (1 - 0.45 * along))) ** 2)
        blood = blood + run
    blood = blood + 0.35 * np.exp(-((xx - 0.004) / 0.016) ** 2 - ((zz + 0.105) / 0.014) ** 2) * _smooth((_fbm(rng, xx, zz, 70.0) - 0.4) / 0.2)  # smeared on the chin
    colour = _over(colour, (0.22, 0.025, 0.035), 0.9 * np.clip(blood, 0, 1) * (0.75 + 0.3 * blotch))
    # the throat: bruised purple and grey where it tore, smeared with blood
    colour = _over(colour, (0.3, 0.2, 0.25), 0.8 * _smooth((-0.128 - zz) / 0.03) * (0.6 + 0.6 * blotch))
    colour = _over(colour, (0.2, 0.03, 0.04), 0.8 * _smooth((-0.19 - zz) / 0.02) * _smooth((_fbm(rng, xx * 0.4, zz, 50.0) - 0.3) / 0.25))
    path = os.path.join(HERE, "Her_skin.png")
    img = bpy.data.images.get("Her_skin") or bpy.data.images.new("Her_skin", TEX_W, TEX_H)
    img.pixels.foreach_set(np.concatenate([np.clip(colour, 0, 1), np.ones(xx.shape + (1,))], axis=-1).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.source = "FILE"
    img.reload()
    return img

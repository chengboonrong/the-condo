"""Hafiz and Mei, the couple who drive the player down the mountain: what art/hafiz/build.py and art/mei/build.py share.

A person is one bmesh: lofts (the clothes, the limbs, the neck: rings of points joined by quads), a head shaped in code
(skull and face, eyes, ears) and hands. Every face is on a pre-bake material, a procedural colour, and every vertex is in
the body or in a part the game turns (Head, Chest, LegL, LegR). common.bake bakes the person into one colour image (it
bakes roughness and normal too; only the colour is kept, as they are seen dimly and small), then the faces get the
materials the game draws them with, all on that image (skin, cloth, hair, eye, plastic) but the phone's screen, which is
plain and lit by code. Then the parts are split off at their pivots. Blender Z up; the person faces -Y (the game's +Z);
their left is +X. Colours are linear RGB.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy
from mathutils import Matrix, Vector
from mathutils import noise as perlin

ART = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ART)
import common  # noqa: E402
from common import between, lerp, mapped, maths, node, noise  # noqa: E402

PARTS = ["Head", "Chest", "LegL", "LegR"]  # vertex groups, in this order
# What the game draws each kind of surface with: roughness. "screen" is the phone's, untextured and emissive.
FINAL = {"skin": 0.55, "cloth": 0.92, "hair": 0.8, "eye": 0.06, "plastic": 0.35}
# The hatchback's front footwells from a front seat's H-point (art/hatchback/build.py: carpet at 0.285, mats 0.012 thick,
# H-points at y -0.05, z 0.56, the firewall at y -0.86): the mat's top, and how far ahead the firewall is.
MAT_TOP, FIREWALL = -0.263, -0.81


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def bump(d: float, width: float) -> float:
    return math.exp(-(d / width) ** 2)


def catmull(keys: list, t: float) -> list:
    """The values in keys (rows of numbers, the first being the parameter, increasing) at t, Catmull-Rom between rows."""
    t = min(max(t, keys[0][0]), keys[-1][0])
    i = max(k for k in range(len(keys) - 1) if keys[k][0] <= t) if t < keys[-1][0] else len(keys) - 2
    p0, p1, p2, p3 = keys[max(i - 1, 0)], keys[i], keys[i + 1], keys[min(i + 2, len(keys) - 1)]
    u = (t - p1[0]) / (p2[0] - p1[0])
    out = []
    for a, b, c, d in zip(p0[1:], p1[1:], p2[1:], p3[1:]):
        m1, m2 = (c - a) / 2, (d - b) / 2
        out.append((2 * u ** 3 - 3 * u ** 2 + 1) * b + (u ** 3 - 2 * u ** 2 + u) * m1 + (-2 * u ** 3 + 3 * u ** 2) * c + (u ** 3 - u ** 2) * m2)
    return out


class Person:
    """One person's geometry, built part by part, and the pre-bake materials its faces are on."""

    def __init__(self, seed: int) -> None:
        perlin.seed_set(seed)
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.hp = self.bm.verts.layers.float_vector.new("hp")  # head and eye vertices: where they are on the unturned head
        self.flow = self.bm.verts.layers.float_vector.new("flow")  # hair: across a clump (-1 to 1), along it (0 to 1), which
        self.nrm = self.bm.verts.layers.float_vector.new("nrm")  # hair: the way out of the head, which it is shaded towards
        self.slots = []  # (pre-bake material, final kind, UV grow)

    def slot(self, material: bpy.types.Material, final: str, grow: float = 0.0) -> int:
        self.slots.append((material, final, grow))
        return len(self.slots) - 1

    def vert(self, co: Vector, part: str | None = None, hp: Vector | None = None, flow: Vector | None = None) -> bmesh.types.BMVert:
        v = self.bm.verts.new(co)
        if part:
            v[self.deform][PARTS.index(part)] = 1.0
        if hp is not None:
            v[self.hp] = hp
        if flow is not None:
            v[self.flow] = flow
        return v

    def loft(self, rings: list, mat: int, part: str | None = None, caps: tuple = (False, False), hp=None, flow=None) -> list:
        """Quads between rings of points (lists of the same length, each closed: its last point joins its first); caps:
        a fan over the first and/or last ring. hp, flow: functions (ring index, point index) -> a vector for that vertex.
        The faces point out of the shape. Returns the vertices, ring by ring."""
        vs = [[self.vert(q, part, hp(i, j) if hp else None, flow(i, j) if flow else None) for j, q in enumerate(r)]
              for i, r in enumerate(rings)]
        n = len(rings[0])
        faces = []
        for a, b in zip(vs, vs[1:]):
            for j in range(n):
                k = (j + 1) % n
                faces.append(self.bm.faces.new([a[j], a[k], b[k], b[j]]))
        for ring, on, i in ((vs[0], caps[0], 0), (vs[-1], caps[1], len(vs) - 1)):
            if on:
                c = self.vert(sum((v.co for v in ring), Vector()) / n, part, hp(i, 0) if hp else None, flow(i, 0) if flow else None)
                faces += [self.bm.faces.new([ring[j], ring[(j + 1) % n], c]) for j in range(n)]
        self.finish(faces, mat)
        return vs

    def sheet(self, rows: list, mat: int, part: str | None = None, hp=None, flow=None, inside: Vector | None = None) -> list:
        """Quads between open rows of points (the last point does not join the first); the faces turned away from
        inside if given. hp, flow as for loft. Returns the vertices, row by row."""
        vs = [[self.vert(q, part, hp(i, j) if hp else None, flow(i, j) if flow else None) for j, q in enumerate(r)]
              for i, r in enumerate(rows)]
        faces = [self.bm.faces.new([a[j], a[j + 1], b[j + 1], b[j]]) for a, b in zip(vs, vs[1:]) for j in range(len(a) - 1)]
        self.finish(faces, mat)
        if inside is not None and sum((f.calc_center_median() - inside).dot(f.normal) for f in faces) < 0:
            for f in faces:
                f.normal_flip()
        return vs

    def finish(self, faces: list, mat: int) -> None:
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        for f in faces:
            f.material_index = mat
            f.smooth = True

    def tube(self, path: list, radius, sides: int, mat: int, part: str | None = None, up: Vector = Vector((0, 0, 1)),
             caps: tuple = (False, True), shape=None) -> list:
        """A tube along path (points): radius(i) -> (across, along up) half widths of its ellipse at point i, or a
        number. shape(i, k, (x, y)) may move a ring point in its frame. Returns the rings' vertices."""
        rings = []
        for i, (p, (t, side, n)) in enumerate(zip(path, frames(path, up))):
            r = radius(i) if callable(radius) else radius
            rx, ry = (r, r) if isinstance(r, (int, float)) else r
            ring = []
            for k in range(sides):
                a = math.tau * k / sides
                x, y = rx * math.cos(a), ry * math.sin(a)
                if shape:
                    x, y = shape(i, k, (x, y))
                ring.append(p + side * x + n * y)
            rings.append(ring)
        return self.loft(rings, mat, part, caps)

    def mesh(self, name: str) -> bpy.types.Object:
        """The person as one object, its pre-bake materials in slot order and its parts as vertex groups."""
        obj = common.mesh_object(name, self.bm, [s[0] for s in self.slots])
        for part in PARTS:
            obj.vertex_groups.new(name=part)
        return obj


def frames(path: list, up: Vector) -> list:
    """(tangent, side, normal) at each point of path, carried along it without twisting; the first normal is as near up
    as it can be."""
    ts = [(path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized() for i in range(len(path))]
    n = (up - up.project(ts[0])).normalized()
    out = []
    for i, t in enumerate(ts):
        if i:
            n = ts[i - 1].rotation_difference(t) @ n
        n = (n - n.project(t)).normalized()
        out.append((t, t.cross(n), n))
    return out


def limb(a: Vector, b: Vector, c: Vector, steps: tuple = (4, 3, 4), round_off: float = 0.35) -> list:
    """Points from a to c through the joint b, the joint rounded: steps along a-b, round the joint, along b-c."""
    ab, bc = b - a, c - b
    j0, j1 = b - ab * round_off * min(1.0, 0.12 / ab.length), b + bc * round_off * min(1.0, 0.12 / bc.length)
    pts = [a.lerp(j0, i / steps[0]) for i in range(steps[0])]
    for i in range(steps[1]):
        t = i / steps[1]
        pts.append(j0 * (1 - t) ** 2 + b * 2 * t * (1 - t) + j1 * t * t)
    pts += [j1.lerp(c, i / steps[2]) for i in range(steps[2] + 1)]
    return pts


def elbow(root: Vector, end: Vector, l1: float, l2: float, pole: Vector) -> Vector:
    """The middle joint of a two-bone limb from root to end, bent towards pole (a direction)."""
    d = min((end - root).length, (l1 + l2) * 0.999)
    axis = (end - root).normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    side = (pole - pole.project(axis)).normalized()
    return root + axis * a + side * h


def section(hw: float, df: float, db: float, sq: float, n: int, start: float = 0.0, end: float = math.tau) -> list:
    """(x, depth) round a body's cross-section: half width hw, depth df to the front (-Y) and db to the back,
    squareness sq (2 an ellipse, more is boxier). From angle start to end (0 the front, increasing towards +X)."""
    out = []
    count = n if end - start >= math.tau - 1e-6 else n + 1
    for k in range(count):
        a = start + (end - start) * k / n
        s, c = math.sin(a), math.cos(a)
        x = math.copysign(abs(s) ** (2 / sq), s) * hw
        d = math.copysign(abs(c) ** (2 / sq), c) * (df if c > 0 else db)
        out.append((x, d))
    return out


class Frame:
    """A body's axis: points given as (x, y, h) about it (h up the axis) to the model's coordinates."""

    def __init__(self, origin: Vector, lean: float) -> None:
        self.origin = origin
        self.rot = Matrix.Rotation(-lean, 3, "X")  # lean > 0 tips the top back, +Y

    def __call__(self, x: float, y: float, h: float) -> Vector:
        return self.origin + self.rot @ Vector((x, y, h))


def torso_rings(frame: Frame, rows: list, step: float, n: int, start: float = 0.0, end: float = math.tau, grow=None) -> list:
    """Rings round a body from its rows (h, half width, front depth, back depth, centre y, squareness), every step up
    the axis; grow(h, x, depth) may push a point out (metres)."""
    h0, h1 = rows[0][0], rows[-1][0]
    count = max(2, round((h1 - h0) / step))
    rings = []
    for i in range(count + 1):
        h = h0 + (h1 - h0) * i / count
        hw, df, db, cy, sq = catmull(rows, h)
        ring = []
        for x, d in section(hw, df, db, sq, n, start, end):
            if grow:
                k = Vector((x, d)).normalized() if (x or d) else Vector((0, 1))
                g = grow(h, x, d)
                x, d = x + k.x * g, d + k.y * g
            ring.append(frame(x, cy - d, h))
        rings.append(ring)
    return rings


def open_loft(p: Person, outer: list, inner: list, mat: int, part: str | None = None) -> None:
    """A layer of cloth with an opening (a cardigan's front): rows of points round its outside, open at the ends, and
    the same rows round its inside; closed along the opening and at the top and bottom edges."""
    rings = [o + i[::-1] for o, i in zip(outer, inner)]
    vs = [[p.vert(q, part) for q in r] for r in rings]
    n, m = len(rings[0]), len(outer[0])
    faces = []
    for a, b in zip(vs, vs[1:]):
        for j in range(n):
            k = (j + 1) % n
            faces.append(p.bm.faces.new([a[j], a[k], b[k], b[j]]))
    for r in (vs[0], vs[-1]):  # the hem and the top edge: outside to inside
        for j in range(m - 1):
            faces.append(p.bm.faces.new([r[j], r[j + 1], r[n - 2 - j], r[n - 1 - j]]))
    p.finish(faces, mat)


def keyed(keys: list, t: float):
    """keys: [(t, value)], the value at t, linear between keys (values are numbers or pairs)."""
    t = min(max(t, keys[0][0]), keys[-1][0])
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            u = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
            if isinstance(a, tuple) or isinstance(b, tuple):
                a, b = (a if isinstance(a, tuple) else (a, a)), (b if isinstance(b, tuple) else (b, b))
                return tuple(x + (y - x) * u for x, y in zip(a, b))
            return a + (b - a) * u
    return keys[-1][1]


def along(path: list) -> list:
    """How far along path each point is, 0 to 1."""
    d = [0.0]
    for a, b in zip(path, path[1:]):
        d.append(d[-1] + (b - a).length)
    return [x / d[-1] for x in d]


def limb_tube(p: Person, root: Vector, joint: Vector, end: Vector, radii: list, mat: int, part: str | None, up: Vector,
              sides: int = 12, caps: tuple = (True, True), shape=None) -> None:
    """A sleeve or a trouser leg from root through its joint (elbow or knee) to end; radii: [(0 to 1 along it, radius
    or (across, along up))]; shape(t, k, (x, y)) may move ring points (folds)."""
    path = limb(root, joint, end)
    t = along(path)
    p.tube(path, lambda i: keyed(radii, t[i]), sides, mat, part, up=up, caps=caps, shape=shape and (lambda i, k, xy: shape(t[i], k, xy)))


def folds(amount: float, seed: float):
    """A shape for limb_tube: cloth bunched in soft creases round the tube, deeper towards the joint (t = 0.5)."""
    def shape(t: float, k: int, xy: tuple) -> tuple:
        n = perlin.noise(Vector((t * 7.0, k * 0.55, seed))) + 0.5 * perlin.noise(Vector((t * 15.0, k * 1.3, seed + 3.0)))
        g = 1.0 + amount * n * (0.5 + bump(t - 0.5, 0.18))
        return xy[0] * g, xy[1] * g
    return shape


def strap(p: Person, points: list, outs: list, width: float, thick: float, mat: int, part: str | None, caps: tuple = (True, True)) -> None:
    """A flat strap (a lanyard, a cap's strap) along points, its face square to outs (the way out of the body there)."""
    rings = []
    for i, (q, o) in enumerate(zip(points, outs)):
        t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        o = (o - o.project(t)).normalized()
        s = t.cross(o)
        rings.append([q + s * width / 2 + o * thick / 2, q - s * width / 2 + o * thick / 2, q - s * width / 2 - o * thick / 2,
                      q + s * width / 2 - o * thick / 2])
    p.loft(rings, mat, part, caps)


def clump(p: Person, path: list, outs: list, width: float, thick: float, mat: int, part: str | None, ident: float,
          tip: float = 0.2) -> None:
    """A clump of hair along path (root to end): a lens width by thick (half sizes) at the root, flat to outs (the way
    out of the head at each point), narrowing to tip of that at its end, which is closed. flow: (across -1 to 1, along
    0 to 1, ident) for hair_material."""
    t = along(path)
    rings, flows = [], []
    for i, q in enumerate(path):
        tg = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        n = (outs[i] - outs[i].project(tg)).normalized()
        side = tg.cross(n)
        k = 1 - (1 - tip) * smooth((t[i] - 0.3) / 0.7)
        rings.append([q + side * width * k, q + n * thick * k, q - side * width * k, q - n * thick * k])
        flows.append([Vector((a, t[i], ident)) for a in (1.0, 0.0, -1.0, 0.0)])
    for ring, o in zip(p.loft(rings, mat, part, (False, True), flow=lambda i, j: flows[i][j]), outs):
        for v in ring:
            v[p.nrm] = o


def spline(points: list, count: int) -> list:
    """count points along a Catmull-Rom curve through points."""
    keys = [(i, *q) for i, q in enumerate(points)]
    return [Vector(catmull(keys, (len(points) - 1) * k / (count - 1))) for k in range(count)]


def phone(p: Person, centre: Vector, length_axis: Vector, face: Vector, case: int, screen: int, part: str | None) -> None:
    """A phone 7.4 by 15.3 cm, 8.5 mm thick, its screen on the face side: a chamfered box and the glass a hair above it."""
    face = face.normalized()
    up = (length_axis - length_axis.project(face)).normalized()
    across = up.cross(face)
    to = Matrix((across, up, face)).transposed().to_4x4()
    to.translation = centre
    verts = common.added(p.bm, lambda bm: common.chamfered_box(bm, (0, 0, 0), (0.074, 0.153, 0.0085), 0.0025, case))
    glass = [p.bm.verts.new((x, y, 0.00428)) for x, y in ((-0.034, -0.071), (0.034, -0.071), (0.034, 0.071), (-0.034, 0.071))]
    face_ = p.bm.faces.new(glass)
    face_.material_index = screen
    for v in verts + glass:
        v.co = to @ v.co
        if part:
            v[p.deform][PARTS.index(part)] = 1.0
    face_.normal_update()
    if face_.normal.dot(face) < 0:
        face_.normal_flip()


# --- hands ------------------------------------------------------------------------------------------------

def hand(p: Person, mat: int, part: str | None, wrist: Vector, fwd: Vector, palm: Vector, side: int, size: float,
         curl, thumb: tuple = (0.5, 0.3, 0.2), spread: float = 0.1) -> None:
    """A hand from its wrist: fwd towards the knuckles, palm the way the palm faces, side +1 the left hand, -1 the
    right. size: the hand's length (wrist to the middle fingertip). curl: (knuckle, middle, end) bends towards the palm in
    radians, for every finger or a list of four (index to little). thumb: its bends; it lies along the palm's thumb side."""
    fwd = fwd.normalized()
    palm = (palm - palm.project(fwd)).normalized()
    across = side * palm.cross(fwd)  # towards the thumb
    bend_axis = fwd.cross(palm)
    k = size / 0.185
    rows = []
    for t, w, th in ((0.0, 0.031, 0.018), (0.35, 0.039, 0.016), (0.75, 0.042, 0.0135), (1.0, 0.041, 0.012)):
        c = wrist + fwd * (0.1 * k * t) - palm * 0.002 * t
        rows.append([c + across * (x * w * k) + palm * (y * th * k) for x, y in
                     ((1, 0), (0.8, 0.8), (0, 1), (-0.8, 0.8), (-1, 0), (-0.8, -0.85), (0, -1.05), (0.8, -0.85))])
    p.loft(rows, mat, part, (True, True))
    curls = curl if isinstance(curl, (list, tuple)) and len(curl) == 4 else [curl] * 4
    for f, (offset, length, r) in enumerate(((0.027, 0.92, 0.0095), (0.009, 1.0, 0.0097), (-0.01, 0.94, 0.0092), (-0.027, 0.76, 0.0082))):
        base = wrist + fwd * (0.094 * k) + across * (offset * k) - palm * 0.003 * k
        d = Matrix.Rotation(spread * offset / 0.027 * side, 3, palm) @ fwd
        pts, angle = [base], 0.0
        for seg, bend in zip((0.044, 0.026, 0.021), curls[f]):
            angle += bend
            step = Matrix.Rotation(angle, 3, bend_axis) @ d
            pts.append(pts[-1] + step * seg * length * k)
        p.tube(pts, lambda i, r=r: r * k * (1 - 0.1 * i), 5, mat, part, up=palm, caps=(False, True))
    base = wrist + fwd * (0.025 * k) + across * (0.024 * k) + palm * (0.006 * k)
    d = (fwd * 0.75 + across * 0.55 + palm * 0.35).normalized()
    axis = d.cross(palm).normalized() * side
    pts, angle = [base], 0.0
    for seg, bend in zip((0.042, 0.033, 0.027), thumb):
        angle += bend
        pts.append(pts[-1] + (Matrix.Rotation(angle, 3, axis) @ d) * seg * k)
    p.tube(pts, lambda i: 0.0125 * k * (1 - 0.1 * i), 5, mat, part, up=palm, caps=(False, True))


# --- shoes ------------------------------------------------------------------------------------------------

def shoe(p: Person, mat: int, part: str | None, heel: Vector, toe: Vector, up: Vector, side: int, width: float, height: float) -> None:
    """A low sneaker from the back of its heel to its toe, its sole on the plane through them square to up: rows
    across the foot, each round the upper and flat under the sole. The shader paints the sole by height."""
    along = (toe - heel)
    length = along.length
    f = along.normalized()
    u = (up - up.project(f)).normalized()
    x = f.cross(u)
    rows = []
    for i in range(11):
        t = i / 10
        w = width * (0.66 + 0.34 * math.sin(min(t * 1.25, 1.0) * math.pi * 0.62 + 0.25)) * (1 - 0.35 * smooth((t - 0.86) / 0.14))
        h = height * (1.0 - 0.62 * smooth((t - 0.3) / 0.55)) * (1 - 0.3 * smooth((t - 0.92) / 0.08))
        inner = 0.12 * side * width * bump(t - 0.6, 0.25)  # the arch side is straighter
        ring = []
        for k in range(10):
            a = math.tau * k / 10
            cx, cz = math.cos(a), math.sin(a)
            cz = cz if cz > 0 else cz * 0.15  # flat under the sole
            ring.append(heel + f * (length * t) + x * (cx * w + inner) + u * ((cz + 0.15) * h * 0.5 + 0.004))
        rows.append(ring)
    p.loft(rows, mat, part, (True, True))


# --- the head ---------------------------------------------------------------------------------------------

def skull(d: Vector, f: dict) -> Vector:
    """The head's surface from its centre in the direction d (x left, y back, z up): a skull fuller at the back, the
    face narrowing to the jaw, with a brow, eye sockets, cheekbones, a nose, lips and a chin; f is the face."""
    d = d.normalized()
    p = Vector((d.x * f["width"], d.y * (f["front"] if d.y < 0 else f["back"]), d.z * f["height"]))
    low = smooth((-p.z - 0.01) / 0.08)  # 0 above the cheekbones, 1 at the jaw
    front = smooth(-d.y * 1.6)  # the face only
    p.x *= 1.0 - f["jaw"] * low * (1.0 if d.y < 0.3 else 0.6)
    if d.y < 0:
        p.y -= f["chin_fwd"] * low * front
    p.y -= features(abs(p.x), p.z, f) * front
    return p


def features(x: float, z: float, f: dict) -> float:
    """How far the face stands out of the plain skull at (|x|, z), metres."""
    ex, ez = f["eye_x"], f["eye_z"]
    out = f["brow"] * bump(z - ez - 0.022, 0.011) * smooth((0.058 - x) / 0.02)
    out -= f["socket"] * math.exp(-((x - ex) / 0.0165) ** 2 - ((z - ez - 0.001) / 0.0105) ** 2)
    out += f["lid"] * math.exp(-((x - ex) / 0.013) ** 2 - ((z - ez - 0.0085) / 0.0042) ** 2)
    out += f["cheekbone"] * math.exp(-((x - 0.049) / 0.017) ** 2 - ((z - ez + 0.022) / 0.014) ** 2)
    out += f["cheek"] * math.exp(-((x - 0.038) / 0.02) ** 2 - ((z - ez + 0.05) / 0.02) ** 2)
    zr, zt = ez + 0.004, f["tip_z"]
    zb = zt - 0.011
    if z >= zt:
        ridge = f["root"] + (f["tip"] - f["root"]) * min(1.0, max(0.0, (zr - z) / (zr - zt))) ** 1.3 if z <= zr + 0.01 else 0.0
        ridge *= smooth((zr + 0.012 - z) / 0.012)
    elif z >= zb:
        ridge = f["tip"] * (1 - 0.72 * ((zt - z) / (zt - zb)) ** 2)
    else:
        ridge = f["tip"] * 0.28 * bump(zb - z, 0.004)
    w = f["bridge_w"] + (f["tip_w"] - f["bridge_w"]) * smooth((zr - z) / (zr - zt))
    out += ridge * bump(x, w)
    out += f["alar"] * math.exp(-((x - f["alar_x"]) / 0.0065) ** 2 - ((z - zt + 0.006) / 0.0075) ** 2)
    ul = zb - 0.011
    ll = ul - 0.0135
    mw = f["mouth_w"]
    out += f["muzzle"] * bump(x, 0.03) * between_f(z, ll - 0.012, zb, 0.012)
    out += f["lip_u"] * bump(z - ul, 0.0048) * smooth((mw - x) / 0.009)
    out += f["lip_l"] * bump(z - ll, 0.0052) * smooth((mw - 0.003 - x) / 0.009)
    out -= 0.0025 * bump(z - (ul - 0.0062), 0.0016) * smooth((mw - x) / 0.004)
    out += f["chin_b"] * bump(x, 0.021) * bump(z - (ll - 0.026), 0.011)
    return out


def between_f(v: float, lo: float, hi: float, soft: float) -> float:
    return smooth((v - lo + soft) / soft) * smooth((hi + soft - v) / soft)


def head_grid(f: dict, offset=None, segments: int = 44, rings: int = 34, polar: tuple = (0.0, 1.0)) -> list:
    """Rings of (direction, point on the head) from the bottom up, closer together over the face and round the eyes'
    height; each point pushed by offset(direction, point) if given. polar: the share of the way from the bottom to the
    crown the rings span."""
    rows = []
    for k in range(1, rings):
        v = polar[0] + (polar[1] - polar[0]) * k / rings
        v += 0.075 * math.sin(math.tau * v)  # closer at the middle
        t = math.pi * (1 - v)
        row = []
        for i in range(segments):
            s = 2 * i / segments - 1
            a = math.pi * s * (0.42 + 0.58 * s * s)  # closer over the face
            d = Vector((math.sin(t) * math.sin(a), -math.sin(t) * math.cos(a), math.cos(t)))
            q = skull(d, f)
            if offset:
                q = offset(d, q)
            row.append((d, q))
        rows.append(row)
    return rows


def grid_loft(p: Person, rows: list, centre: Vector, mat: int, part: str, caps: tuple = (True, True), flow=None) -> list:
    """The head grid rows as a closed surface at centre, each vertex's hp its place on the head."""
    return p.loft([[centre + q for _, q in r] for r in rows], mat, part, caps, hp=lambda i, j: rows[i][j][1], flow=flow)


def eye_centre(f: dict, side: int) -> Vector:
    """The centre of an eye (side +1 the left) from the head's centre: set f["eye_set"] behind the face's plain surface."""
    x = side * f["eye_x"]
    surface = skull(Vector((x / f["width"], -1.0, f["eye_z"] / f["height"])), dict(f, socket=0.0, lid=0.0))
    return Vector((x, surface.y + f["eye_set"] + f["eye_r"], f["eye_z"]))


def eyes(p: Person, f: dict, centre: Vector, mat: int, part: str, look: Vector = Vector((0, -1, 0)), rings: int = 6,
         segs: int = 12) -> None:
    """Two eyeballs in their sockets, a little more than their front half; each vertex's hp is its direction from the
    eye's centre with the iris at -Y, and its x the side (the shader finds the iris by -hp.y)."""
    r = f["eye_r"]
    for side in (1, -1):
        c = eye_centre(f, side)
        gaze = Matrix.Rotation(side * 0.06, 3, "Z") @ look.normalized()  # a little outward, as eyes rest
        to = gaze.to_track_quat("-Y", "Z").to_matrix()
        dirs = []
        for k in range(1, rings + 1):
            t = math.radians(110) * k / rings
            dirs.append([Vector((math.sin(t) * math.cos(a), -math.cos(t), math.sin(t) * math.sin(a))) for a in
                         (math.tau * j / segs for j in range(segs))])
        tip = p.vert(centre + c + to @ Vector((0, -r, 0)), part, Vector((0, -1, 0)))
        vs = p.loft([[centre + c + to @ (q * r) for q in ring] for ring in dirs], mat, part, hp=lambda i, j, dirs=dirs: dirs[i][j])
        faces = [p.bm.faces.new([vs[0][(j + 1) % segs], vs[0][j], tip]) for j in range(segs)]
        p.finish(faces, mat)


def lids(p: Person, f: dict, centre: Vector, mat: int, part: str, cols: int = 11) -> None:
    """The eyelids: an upper and a lower shell a hair off each eyeball, so the eye shows as an almond and not a ball.
    Each margin is thick (it starts inside the eyeball) and follows the face shader's lash line (f["lash_h"] above the
    eye's centre at its middle, falling to the corners); the skin closes over the shells beyond the socket. They are
    on the face's material, hp their place on the head."""
    r = f["eye_r"]
    for side in (1, -1):
        c = eye_centre(f, side)
        for sign in (1, -1):  # the upper lid, the lower
            rows = []
            for lift, rad in ((0.0, r * 0.94), (0.04, r + 0.0016), (0.35, r + 0.0011), (1.0, r + 0.0008)):
                row = []
                for j in range(cols):
                    phi = math.radians(84) * (2 * j / (cols - 1) - 1)
                    du = r * math.sin(phi) / 0.0135
                    th = math.asin(sign * f["lash_h"] * (1.0 if sign > 0 else 0.92) * (1 - du * du) / r)
                    th += (sign * 1.25 - th) * lift
                    row.append(c + Vector((math.sin(phi) * math.cos(th), -math.cos(phi) * math.cos(th), math.sin(th))) * rad)
                rows.append(row)
            p.sheet([[centre + q for q in row] for row in rows], mat, part, hp=lambda i, j, rows=rows: rows[i][j], inside=centre + c)


def ear(p: Person, f: dict, centre: Vector, side: int, mat: int, part: str, k_rings: int = 5, segs: int = 14) -> None:
    """An ear: a shell 6 cm tall, its rim rolled, a bowl inside it and a lobe, its back towards the skull, angled back
    and a little out. hp: its place on the head (the shader colours ears by |x|)."""
    def outline(a: float) -> float:  # a from the top round the back (the ear's +v) and down
        return 1.0 + 0.12 * bump(math.remainder(a - 2.9, math.tau), 0.5)
    fronts, backs = [], []
    for k in range(1, k_rings + 1):
        r = k / k_rings
        fr, bk = [], []
        for j in range(segs):
            a = math.tau * j / segs
            ro = r * outline(a)
            u, v = 0.0175 * ro * math.sin(a), 0.031 * ro * math.cos(a)  # u back, v up
            if v < 0:
                u *= 0.85
            rim = 0.0055 * bump(r - 0.92, 0.12) * (0.4 + 0.6 * smooth((math.cos(a) + 0.4) / 0.6))
            bowl = -0.0045 * bump(r, 0.42) * smooth((0.25 - u) / 0.01)
            anti = 0.0022 * bump(r - 0.58, 0.1) * smooth((v + 0.008) / 0.01)
            lobe = 0.002 * bump(v + 0.026, 0.006)
            fr.append(Vector((0.006 + rim + bowl + anti + lobe, u, v)))
            bk.append(Vector((0.0015 * (1 - r * r), u * 0.97, v * 0.97)))
        fronts.append(fr)
        backs.append(bk)
    place = Matrix.Translation(Vector((side * (f["width"] - 0.006), f["ear_y"], f["eye_z"] - 0.012))) @ \
        Matrix.Rotation(-side * 0.32, 4, "Z") @ Matrix.Rotation(-0.18, 4, "X") @ Matrix.Scale(side, 4, (1, 0, 0))
    rows = [[place @ q for q in ring] for ring in fronts] + [[place @ q for q in ring] for ring in reversed(backs)]
    p.loft([[centre + q for q in r] for r in rows], mat, part, (True, True), hp=lambda i, j: rows[i][j])


def rotate_verts(verts: list, pivot: Vector, rot: Matrix) -> None:
    for v in verts:
        v.co = pivot + rot @ (v.co - pivot)


# --- materials --------------------------------------------------------------------------------------------

def attr(nt: bpy.types.NodeTree, name: str) -> list:
    return node(nt, "ShaderNodeSeparateXYZ", {"Vector": node(nt, "ShaderNodeAttribute", attribute_name=name).outputs["Vector"]}).outputs


def scaled(nt: bpy.types.NodeTree, colour, k) -> bpy.types.NodeSocket:
    return node(nt, "ShaderNodeVectorMath", {0: colour, "Scale": k}, operation="SCALE").outputs["Vector"]


def shaded(nt: bpy.types.NodeTree, colour, distance: float, depth: float) -> bpy.types.NodeSocket:
    """colour darkened in creases and where parts meet (ambient occlusion over distance), by up to depth."""
    ao = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": distance}, samples=24, only_local=True).outputs["AO"]
    return scaled(nt, colour, mapped(nt, ao, 0.0, 1.0, 1.0 - depth, 1.0))


def face_skin(name: str, f: dict, tone: tuple, hair: tuple, extra=None) -> bpy.types.Material:
    """The head's skin, painted by where each point is on the unturned head (the hp attribute): blotchy, redder on the
    cheeks, the nose, the ears and the lips, darker round the eyes, the brows and the lash line drawn in, the nostrils
    and the mouth's line dark, and the hair's colour on the scalp above the hairline (f["hairline"](nt, hp, x, z) -> metres
    above it, as a shader socket). extra(nt, colour, hp) may paint more (stubble)."""
    mat, nt, bsdf, coords = common.surface(name)
    hp = attr(nt, "hp")
    vec = node(nt, "ShaderNodeAttribute", attribute_name="hp").outputs["Vector"]
    x = maths(nt, "ABSOLUTE", hp["X"])
    z = hp["Z"]
    ex, ez = f["eye_x"], f["eye_z"]

    def blob(cx, cz, wx, wz):
        dx = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", x, cx), wx)
        dz = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", z, cz), wz)
        return maths(nt, "EXPONENT", maths(nt, "MULTIPLY", maths(nt, "ADD", maths(nt, "MULTIPLY", dx, dx), maths(nt, "MULTIPLY", dz, dz)), -1.0))

    t = Vector(tone)
    mottle = mapped(nt, noise(nt, vec, 38.0, 4.0), 0.3, 0.7, 0.9, 1.08)
    colour = scaled(nt, lerp(nt, tuple(t), tuple(t * 1.06 * Vector((1.04, 0.97, 0.94))), noise(nt, vec, 9.0, 3.0)), mottle)
    red = tuple(t * Vector((1.12, 0.78, 0.74)))
    redness = maths(nt, "ADD", maths(nt, "MULTIPLY", blob(0.042, ez - 0.03, 0.022, 0.022), 0.55), maths(nt, "MULTIPLY", blob(0.0, f["tip_z"], 0.012, 0.012), 0.5))
    redness = maths(nt, "ADD", redness, maths(nt, "MULTIPLY", mapped(nt, x, f["width"] - 0.012, f["width"], 0.0, 1.0), 0.6))  # the ears
    redness = maths(nt, "MINIMUM", maths(nt, "MULTIPLY", redness, mapped(nt, noise(nt, vec, 25.0, 3.0), 0.3, 0.7, 0.6, 1.2)), 1.0)
    colour = lerp(nt, colour, red, redness)
    zb = f["tip_z"] - 0.011
    ul, ll = zb - 0.011, zb - 0.0245
    lips = maths(nt, "MULTIPLY", between(nt, z, ll - 0.004, ul + 0.0035, 0.002), mapped(nt, x, f["mouth_w"] - 0.002, f["mouth_w"] + 0.004, 1.0, 0.0))
    colour = lerp(nt, colour, f["lip_colour"], maths(nt, "MULTIPLY", lips, 0.85))
    seam = maths(nt, "MULTIPLY", between(nt, z, ul - 0.0072, ul - 0.0052, 0.0012), mapped(nt, x, f["mouth_w"] - 0.002, f["mouth_w"] + 0.003, 1.0, 0.0))
    colour = lerp(nt, colour, tuple(t * 0.25), maths(nt, "MULTIPLY", seam, 0.8))
    lidshadow = maths(nt, "MULTIPLY", blob(ex, ez, 0.019, 0.013), 0.45)
    colour = lerp(nt, colour, tuple(t * Vector((0.62, 0.5, 0.5))), lidshadow)
    # The lash line: a dark arc along the upper lid's edge, a fainter one under the eye.
    du = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", x, ex), 0.0135)
    arch = maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", 1.0, maths(nt, "MULTIPLY", du, du)), f["lash_h"])
    across = mapped(nt, maths(nt, "ABSOLUTE", du), 0.85, 1.05, 1.0, 0.0)
    lash =maths(nt, "MULTIPLY", across, mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", maths(nt, "SUBTRACT", z, ez), arch)), 0.0009, 0.0024, 1.0, 0.0))
    under = maths(nt, "MULTIPLY", across, mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "ADD", maths(nt, "SUBTRACT", z, ez), 0.0045)), 0.0006, 0.0018, 0.45, 0.0))
    colour = lerp(nt, colour, tuple(Vector(hair) * 0.8), maths(nt, "MAXIMUM", lash, under))
    # The brows: a band over each eye, higher at its middle, thinning towards the temple.
    bu = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", x, ex + 0.002), 0.024)
    brow_z = maths(nt, "ADD", ez + f["brow_z"], maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", 1.0, maths(nt, "MULTIPLY", bu, bu)), 0.004))
    thick = maths(nt, "ADD", f["brow_t"] * 0.55, maths(nt, "MULTIPLY", mapped(nt, bu, -1.0, 1.0, 1.0, 0.25), f["brow_t"] * 0.45))
    in_brow = maths(nt, "MULTIPLY", mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", z, brow_z)), maths(nt, "MULTIPLY", thick, 0.6), thick, 1.0, 0.0),
                    mapped(nt, maths(nt, "ABSOLUTE", bu), 0.85, 1.05, 1.0, 0.0))
    in_brow = maths(nt, "MULTIPLY", in_brow, mapped(nt, noise(nt, scaled(nt, vec, 1.0), 160.0, 2.0), 0.3, 0.7, f["brow_k"] * 0.7, f["brow_k"]))
    colour = lerp(nt, colour, hair, in_brow)
    nostril = blob(0.0075, zb + 0.0012, 0.0042, 0.0022)
    colour = lerp(nt, colour, tuple(t * 0.2), maths(nt, "MULTIPLY", nostril, 0.9))
    alar = maths(nt, "MULTIPLY", blob(f["alar_x"] + 0.006, f["tip_z"] - 0.004, 0.003, 0.008), 0.35)
    colour = lerp(nt, colour, tuple(t * 0.6), alar)
    if extra:
        colour = extra(nt, colour, hp, x, z)
    scalp = mapped(nt, f["hairline"](nt, hp, x, z), -0.002, 0.004, 0.0, 1.0)
    colour = lerp(nt, colour, hair, maths(nt, "MULTIPLY", scalp, 0.92))
    nt.links.new(shaded(nt, colour, 0.025, 0.55), bsdf.inputs["Base Color"])
    return mat


def body_skin(name: str, tone: tuple) -> bpy.types.Material:
    """Skin on the neck, the hands and the legs: a little blotchy, redder at the knuckles and the knees."""
    mat, nt, bsdf, coords = common.surface(name)
    t = Vector(tone)
    colour = lerp(nt, tuple(t * 0.95), tuple(t * Vector((1.08, 0.95, 0.9))), noise(nt, coords, 22.0, 4.0))
    colour = lerp(nt, colour, tuple(t * Vector((1.1, 0.8, 0.76))), mapped(nt, noise(nt, coords, 6.0, 2.0), 0.55, 0.75, 0.0, 0.5))
    nt.links.new(shaded(nt, colour, 0.03, 0.6), bsdf.inputs["Base Color"])
    return mat


def fabric(name: str, colour: tuple, grain: float = 400.0, worn: float = 0.1, ao: float = 0.6, ribs=None, paint=None) -> bpy.types.Material:
    """Cloth: colour with a fine weave noise, worn paler in patches, darker in folds and where parts meet. ribs: (axis,
    count per metre) for knit ribs. paint(nt, colour, coords) may add marks."""
    mat, nt, bsdf, coords = common.surface(name)
    c = Vector(colour)
    weave = noise(nt, coords, grain, 2.0)
    col = lerp(nt, tuple(c * 0.88), tuple(c * 1.1), weave)
    col = lerp(nt, col, tuple(c * (1.0 + 3 * worn)), mapped(nt, noise(nt, coords, 5.0, 3.0), 0.52, 0.72, 0.0, 1.0))
    if ribs:
        axis, count = ribs
        xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
        across = maths(nt, "ADD", xyz["X" if axis != 0 else "Y"], maths(nt, "MULTIPLY", xyz["Y" if axis == 2 else "Z"], 0.6))
        rib = maths(nt, "ABSOLUTE", maths(nt, "SINE", maths(nt, "MULTIPLY", across, count)))
        col = scaled(nt, col, mapped(nt, rib, 0.0, 1.0, 0.86, 1.04))
    if paint:
        col = paint(nt, col, coords)
    nt.links.new(shaded(nt, col, 0.05, ao), bsdf.inputs["Base Color"])
    return mat


def hair_material(name: str, colour: tuple, tips: tuple) -> bpy.types.Material:
    """Hair by clump (the flow attribute): each clump its own tone, streaks along it, darker at the roots and under
    the others (occlusion), lighter at the ends."""
    mat, nt, bsdf, coords = common.surface(name)
    fl = attr(nt, "flow")
    tone = mapped(nt, node(nt, "ShaderNodeTexWhiteNoise", {"W": maths(nt, "MULTIPLY", fl["Z"], 97.0)}, noise_dimensions="1D").outputs["Value"], 0.0, 1.0, 0.8, 1.2)
    streak_at = node(nt, "ShaderNodeCombineXYZ", {"X": maths(nt, "MULTIPLY", fl["X"], 9.0), "Y": maths(nt, "MULTIPLY", fl["Y"], 1.2), "Z": fl["Z"]}).outputs["Vector"]
    streak = mapped(nt, noise(nt, streak_at, 2.0, 3.0), 0.35, 0.65, 0.75, 1.25)
    col = lerp(nt, colour, tips, mapped(nt, fl["Y"], 0.55, 1.0, 0.0, 0.6))
    col = scaled(nt, scaled(nt, col, tone), streak)
    col = scaled(nt, col, mapped(nt, fl["Y"], 0.0, 0.12, 0.6, 1.0))
    nt.links.new(shaded(nt, col, 0.03, 0.75), bsdf.inputs["Base Color"])
    return mat


def eye_material(name: str, iris: tuple) -> bpy.types.Material:
    """The eyeballs (by the hp attribute: the direction from each eye's centre, the iris at -Y): a sclera that is not
    white but greyed and pinker at the corners, a dark iris with a darker ring, a black pupil."""
    mat, nt, bsdf, coords = common.surface(name)
    hp = attr(nt, "hp")
    front = maths(nt, "MULTIPLY", hp["Y"], -1.0)
    sclera = lerp(nt, (0.36, 0.31, 0.28), (0.42, 0.25, 0.22), mapped(nt, front, 0.9, 0.3, 0.0, 0.7))
    col = lerp(nt, sclera, tuple(Vector(iris) * 0.5), mapped(nt, front, 0.86, 0.875, 0.0, 1.0))
    col = lerp(nt, col, iris, mapped(nt, front, 0.88, 0.9, 0.0, 1.0))
    col = lerp(nt, col, (0.004, 0.003, 0.003), mapped(nt, front, 0.965, 0.975, 0.0, 1.0))
    nt.links.new(col, bsdf.inputs["Base Color"])
    return mat


def plain(name: str, colour: tuple, ao: float = 0.5) -> bpy.types.Material:
    mat, nt, bsdf, coords = common.surface(name)
    nt.links.new(shaded(nt, lerp(nt, tuple(Vector(colour) * 0.9), tuple(Vector(colour) * 1.08), noise(nt, coords, 60.0, 2.0)), 0.02, ao), bsdf.inputs["Base Color"])
    return mat


# --- bake, materials, parts, export -----------------------------------------------------------------------

def triangles(objs: list) -> int:
    return sum(len(f.vertices) - 2 for o in objs for f in o.data.polygons)


def finish(p: Person, name: str, model_id: str, pivots: dict, size: int = 256, parents: dict | None = None,
           screen: int | None = None) -> None:
    """Bakes the person into one colour image, gives each face the material the game draws it with, splits off the
    parts at their pivots ({part: point}), parents parts ({child: parent}) and writes assets/models/<model_id>.glb.
    screen: the slot of the phone's screen, which keeps a plain emissive material of its own."""
    obj = p.mesh(name)
    me = obj.data
    hair_normals(me)
    slots = [p.slots[f.material_index][1] if f.material_index != screen else "screen" for f in me.polygons]
    common.bake(obj, size=size, pack=True, grow={i: s[2] for i, s in enumerate(p.slots) if s[2]})
    image = bpy.data.images[f"{name}_color"]
    # In steps of 4 (of 255): the bake's sampling noise doubles what a lossless texture costs, and steps that small
    # are lost in the game's soft, grained picture.
    px = numpy.empty(len(image.pixels), dtype=numpy.float32)
    image.pixels.foreach_get(px)
    image.pixels.foreach_set(numpy.clip(numpy.round(px * 255.0 / 4.0) * 4.0 / 255.0, 0.0, 1.0))
    for m, _, _ in p.slots:  # out of the way of the drawn materials' names
        m.name = f"prebake_{m.name}"
    me.materials.clear()
    kinds = list(dict.fromkeys(slots))
    for kind in kinds:
        me.materials.append(drawn(kind, image))
    me.polygons.foreach_set("material_index", [kinds.index(k) for k in slots])
    for a in ("hp", "flow", "nrm"):
        me.attributes.remove(me.attributes[a])
    parts = {}
    for part, pivot in pivots.items():
        parts[part] = common.split_off(obj, part, pivot)
    obj.vertex_groups.clear()
    for child, parent in (parents or {}).items():
        c, q = parts[child], parts[parent]
        c.parent = q
        c.location = pivots[child] - pivots[parent]
    objs = [obj] + list(parts.values())
    print("PERSON", model_id, "tris", triangles(objs), {o.name: triangles([o]) for o in objs})
    os.makedirs(os.path.join(common.ART, model_id), exist_ok=True)  # where export keeps the .blend and the image
    common.export(model_id, objs)


def hair_normals(me: bpy.types.Mesh) -> None:
    """Shades each clump of hair mostly as the head's outline there (its nrm), a quarter as its own round section: a
    light in front of the face (the phone, with no shadows) otherwise catches the clumps' sides at the back of the head
    and draws them as bright lines. Other faces keep their own normals."""
    count = len(me.vertices)
    nrm, vn = numpy.empty(count * 3, dtype=numpy.float32), numpy.empty(count * 3, dtype=numpy.float32)
    me.attributes["nrm"].data.foreach_get("vector", nrm)
    me.vertex_normals.foreach_get("vector", vn)
    nrm, vn = nrm.reshape(-1, 3), vn.reshape(-1, 3)
    hair = numpy.linalg.norm(nrm, axis=1) > 0.5
    if not hair.any():
        return
    mixed = 0.75 * nrm + 0.25 * vn
    mixed /= numpy.maximum(numpy.linalg.norm(mixed, axis=1, keepdims=True), 1e-6)
    corner = numpy.empty(len(me.loops) * 3, dtype=numpy.float32)
    me.corner_normals.foreach_get("vector", corner)
    corner = corner.reshape(-1, 3)
    at = numpy.empty(len(me.loops), dtype=numpy.int32)
    me.loops.foreach_get("vertex_index", at)
    corner[hair[at]] = mixed[at[hair[at]]]
    me.normals_split_custom_set(corner.tolist())


def drawn(kind: str, image: bpy.types.Image) -> bpy.types.Material:
    """The material the game draws a kind of surface with: the baked image and the kind's roughness; the screen is
    near-black and glows a cold grey-blue (the game drives how much)."""
    mat = bpy.data.materials.new(kind)
    mat.use_backface_culling = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    if kind == "screen":
        bsdf.inputs["Base Color"].default_value = (0.01, 0.012, 0.015, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.2
        bsdf.inputs["Emission Color"].default_value = (0.5, 0.58, 0.68, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
        return mat
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = FINAL[kind]
    return mat

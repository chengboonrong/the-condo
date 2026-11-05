"""The figure: an ordinary person, about 1.7 m, medium build, standing still where nobody should be. A loose work T-shirt
and trousers, rubber slippers, plain short hair; the arms hang a little too low (the hands near mid-thigh) and the head
is tipped. It wears the player's mamak apron, tied at the back. Nothing says who it is, man or woman. Run by
tools/models.sh.

The body is Skin-modifier tubes on a vertex skeleton (trousers, shirt, arms, hands, neck, feet, slipper straps), then
Subdivision; the head and the hair are shaped in code, and the cloth gets its drape folds from noise. The game draws
the body near-black (Silhouette._material), so it needs no texture: its material "body" is a plain colour. The apron is
the shared one (art/shared/apron), wrapped round the body; its material is "apron". The origin is the floor between the
feet; the figure faces -Y, which is the game's +Z.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils import noise as perlin

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "apron")]
import apron  # noqa: E402
import common  # noqa: E402

perlin.seed_set(1207)

ROLL, NOD = 0.2, 0.06  # the head: tipped towards its left shoulder, and a little forward
NECK_TOP = Vector((0.0, 0.0, 1.535))  # what the head turns about
HEAD = Vector((0.0, -0.006, 1.594))  # the skull's centre, before the tip
SKULL = (0.079, 0.099, 0.106, 0.107)  # half width, half depth to the front and to the back, half height

# Skeletons for the Skin modifier: chains of (x, y, z, radius x, radius y) for the figure's left side (+X) or the middle;
# a chain that starts where an earlier one passes branches from it. Front is -Y.
TROUSERS = [
    [(0, 0.004, 1.0, 0.15, 0.104), (0, 0.008, 0.88, 0.155, 0.112)],
    [(0, 0.008, 0.88, 0.155, 0.112), (0.086, 0.01, 0.8, 0.093, 0.1), (0.09, 0.0, 0.64, 0.086, 0.089),
     (0.092, -0.008, 0.47, 0.073, 0.077), (0.094, 0.0, 0.3, 0.066, 0.071), (0.096, 0.008, 0.13, 0.064, 0.069),
     (0.097, 0.01, 0.052, 0.068, 0.074)],
]
SHIRT = [
    [(0, 0.006, 0.795, 0.168, 0.113), (0, 0.006, 0.812, 0.177, 0.122), (0, 0.004, 0.9, 0.174, 0.12),
     (0, 0.0, 1.04, 0.166, 0.116), (0, -0.004, 1.18, 0.17, 0.118), (0, 0.004, 1.3, 0.158, 0.106),
     (0, 0.008, 1.39, 0.09, 0.075)],
    [(0, 0.008, 1.39, 0.09, 0.075), (0.075, 0.01, 1.385, 0.045, 0.068), (0.14, 0.012, 1.362, 0.056, 0.064),
     (0.181, 0.012, 1.26, 0.057, 0.06), (0.19, 0.012, 1.2, 0.056, 0.058), (0.191, 0.012, 1.192, 0.05, 0.052)],
]
ARM = [
    [(0.178, 0.012, 1.28, 0.044, 0.046), (0.188, 0.016, 1.18, 0.042, 0.044), (0.196, 0.024, 1.075, 0.034, 0.037),
     (0.203, 0.016, 0.97, 0.036, 0.034), (0.209, 0.004, 0.86, 0.028, 0.031), (0.211, 0.0, 0.825, 0.022, 0.028),
     (0.212, -0.003, 0.79, 0.018, 0.04), (0.213, -0.004, 0.752, 0.016, 0.041)],
]
NECK = [[(0, 0.004, 1.38, 0.085, 0.068), (0, 0.006, 1.43, 0.07, 0.06), (0, 0.01, 1.48, 0.056, 0.057),
         (0, 0.018, 1.53, 0.051, 0.06)]]


def fingers() -> list:
    """The left hand's fingers and thumb, relaxed: each a chain from inside the palm, curled a little towards it (-X)."""
    chains = []
    for y, length in ((-0.026, 0.92), (-0.009, 1.0), (0.008, 0.95), (0.024, 0.8)):  # index to little finger
        x, z = 0.213, 0.76
        chain = [(x, y, z, 0.009, 0.009)]
        for seg, bend in ((0.044, 0.06), (0.027, 0.2), (0.021, 0.34)):
            seg *= length
            x -= seg * math.sin(bend)
            z -= seg * math.cos(bend)
            r = 0.009 - 0.0007 * len(chain)
            chain.append((x, y, z, r, r))
        chains.append(chain)
    chains.append([(0.209, -0.018, 0.81, 0.011, 0.011), (0.205, -0.036, 0.783, 0.0105, 0.0105),
                   (0.201, -0.044, 0.757, 0.009, 0.009), (0.198, -0.046, 0.737, 0.008, 0.008)])
    return chains


# --- building blocks ------------------------------------------------------------------------------------

def skin(name: str, chains: list, mirror: bool = True, levels: int = 2) -> bpy.types.Object:
    """A mesh made by the Skin modifier, then Subdivision, from chains of (x, y, z, rx, ry); with mirror, each chain is
    added again on the right (x negated). Returns the result as a plain mesh object."""
    verts, radii, edges, roots, index = [], [], [], [], {}
    for chain in chains + ([[(-p[0], *p[1:]) for p in c] for c in chains if any(p[0] for p in c)] if mirror else []):
        ids = []
        for p in chain:
            key = tuple(round(c, 5) for c in p[:3])
            if key not in index:
                index[key] = len(verts)
                verts.append(p[:3])
                radii.append(p[3:5])
                if not ids:
                    roots.append(index[key])
            ids.append(index[key])
        edges += list(zip(ids, ids[1:]))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, edges, [])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("skin", "SKIN")
    mod.use_smooth_shade = True
    mod.branch_smoothing = 0.6
    for i, sv in enumerate(me.skin_vertices[0].data):
        sv.radius = radii[i]
        sv.use_root = i in roots
    sub = obj.modifiers.new("smooth", "SUBSURF")
    sub.levels = sub.render_levels = levels
    return applied(obj)


def applied(obj: bpy.types.Object) -> bpy.types.Object:
    """obj with its modifiers applied."""
    common.select([obj])
    bpy.ops.object.convert(target="MESH")
    return obj


def grid_object(name: str, rows: list) -> bpy.types.Object:
    """A closed surface from rows of points, each row a ring (the last point joins the first): quads between rows,
    the first and last rows closed with a fan to their centre."""
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in row] for row in rows]
    n = len(rows[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([a[i], a[j], b[j], b[i]])
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        c = bm.verts.new(sum((v.co for v in ring), Vector()) / n)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([ring[j], ring[i], c] if flip else [ring[i], ring[j], c])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def bump(d: float, width: float) -> float:
    return math.exp(-(d / width) ** 2)


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


# --- the head ---------------------------------------------------------------------------------------------

def skull(direction: Vector) -> Vector:
    """The head's surface, from its centre, in the direction given (x left, y back, z up): a skull fuller at the back,
    the face narrowing to the jaw and the chin, with a brow, eye sockets, cheekbones, a nose and lips."""
    d = direction.normalized()
    half_y = SKULL[1] if d.y < 0 else SKULL[2]
    p = Vector((d.x * SKULL[0], d.y * half_y, d.z * SKULL[3]))
    low = smooth((-p.z - 0.01) / 0.08)  # 0 above the cheekbones, 1 at the jaw
    p.x *= 1.0 - 0.3 * low * (1.0 if d.y < 0.3 else 0.6)
    front = smooth(-d.y * 1.6)  # the face only
    if d.y < 0:
        p.y -= 0.012 * low * front  # the jaw and the chin come forward of the ellipsoid's bottom
    z = p.z
    x = abs(p.x)
    out = 0.0
    out += 0.005 * bump(z - 0.028, 0.012) * smooth((0.055 - x) / 0.02)  # brow
    out -= 0.007 * bump(x - 0.031, 0.014) * bump(z - 0.006, 0.011)  # eye sockets
    out += 0.004 * bump(x - 0.052, 0.014) * bump(z + 0.012, 0.014)  # cheekbones
    nose = smooth((z + 0.042) / 0.006) * (0.004 + 0.016 * smooth((0.02 - z) / 0.055))
    out += nose * bump(x, 0.011 + 0.006 * smooth((0.0 - z) / 0.04))
    out += 0.003 * bump(x, 0.02) * bump(z + 0.068, 0.006)  # lips
    out += 0.004 * bump(x, 0.022) * bump(z + 0.092, 0.01)  # chin
    p.y -= out * front
    return p


def head_rows(offset=None, segments: int = 40, rings: int = 30) -> list:
    """Rings of points over the skull (crown last), each pushed out by offset(direction, point) if given."""
    rows = []
    for k in range(1, rings):
        t = math.pi * (1 - k / rings)  # from the bottom up
        row = []
        for i in range(segments):
            a = math.tau * i / segments
            d = Vector((math.sin(t) * math.sin(a), -math.sin(t) * math.cos(a), math.cos(t)))  # a = 0 is the face
            p = skull(d)
            if offset:
                p = offset(d, p)
            row.append(HEAD + p)
        rows.append(row)
    return rows


def hairline(a: float) -> float:
    """How high the hair comes down at the angle a round the head (0 the face, pi the nape), relative to the skull's
    centre: a fringe over the forehead, above the ears, down to the nape; ragged where it ends."""
    a = abs(math.remainder(a, math.tau))
    keys = [(0.0, 0.042), (0.6, 0.036), (1.2, 0.02), (1.5, 0.022), (1.9, -0.02), (2.4, -0.06), (math.pi, -0.075)]
    for (a0, z0), (a1, z1) in zip(keys, keys[1:]):
        if a <= a1:
            t = smooth((a - a0) / (a1 - a0))
            base = z0 + (z1 - z0) * t
            break
    ragged = 0.007 * abs(math.sin(a * 23.0)) ** 3 + 0.004 * perlin.noise(Vector((a * 3.0, 0.5, 0.2)))
    return base - ragged * (1.0 if a < 0.9 or a > 2.0 else 0.4)


def hair_offset(d: Vector, p: Vector) -> Vector:
    """The hair over the skull: thickest on the crown, in clumps and strands that fall from it, thinning to nothing at
    the sides and the nape; the fringe keeps an edge. Below the hairline it tucks inside the head."""
    a = math.atan2(d.x, -d.y)
    edge = p.z - hairline(a)  # metres above the hairline
    if edge < 0:
        return p * 0.94
    thick = 0.008 + 0.009 * smooth((p.z - 0.01) / 0.08) + 0.004 * smooth(abs(a) - 2.0)
    fringe = smooth((0.9 - abs(a)) / 0.3)
    thick *= fringe * (0.55 + 0.45 * smooth(edge / 0.01)) + (1 - fringe) * (0.1 + 0.9 * smooth(edge / 0.025))
    clumps = perlin.noise(Vector((a * 4.0, p.z * 9.0, 3.1))) + 0.6 * perlin.noise(Vector((a * 14.0, p.z * 2.0, 7.7)))
    # Uncut, slept-on hair: a few tufts lift off the crown and the back, so the outline is never a clean dome.
    tufts = max(perlin.noise(Vector((a * 5.0, p.z * 14.0, 9.4))), 0.0) ** 1.5 * smooth((p.z + 0.02) / 0.06)
    clumps = 0.003 * clumps + 0.016 * tufts * (1 - fringe)
    q = p + d * (thick + clumps)
    if q.z < 0.0:  # below the skull's widest, the hair falls instead of following the skull in towards the neck
        wide = skull(Vector((d.x, d.y, 0.0)))
        hang = smooth(-q.z / 0.05) * smooth(d.y * 3.0 + 0.3) * smooth((edge - 0.01) / 0.03)
        flat = Vector((q.x, q.y, 0.0))
        full = Vector((wide.x, wide.y, 0.0)) * (1.0 + (thick + clumps) / max(wide.length, 1e-6))
        if full.length > flat.length:
            q.x, q.y = flat.lerp(full, hang * 0.85).to_tuple()[:2]
    return q


def ear(side: int) -> bpy.types.Object:
    """An ear on the side of the head, its back towards the skull, angled back."""
    rows = []
    for k in range(1, 8):
        t = math.pi * (1 - k / 8)
        row = []
        for i in range(12):
            a = math.tau * i / 12
            x, y, z = 0.006 * math.cos(a) * math.sin(t), 0.016 * math.sin(a) * math.sin(t), 0.029 * math.cos(t)
            if x > 0:
                x *= 0.4  # cupped: the outer face is flatter
            row.append(Vector((x, y, z)))
        rows.append(row)
    obj = grid_object("ear", rows)
    obj.matrix_world = Matrix.Translation(HEAD + Vector((side * 0.074, 0.008, -0.012))) @ Matrix.Rotation(side * 0.35, 4, "Z") \
        @ Matrix.Rotation(-0.12, 4, "X") @ Matrix.Scale(side, 4, (1, 0, 0))
    return obj


def head() -> list:
    head_obj = grid_object("head", head_rows())
    hair = grid_object("hair", head_rows(hair_offset, 64, 40))
    return [head_obj, hair, ear(1), ear(-1)]


# --- the feet -----------------------------------------------------------------------------------------------

def slipper() -> bpy.types.Object:
    """A rubber slipper's sole under the left foot: a flip-flop outline, 1.3 cm thick, its edges rounded."""
    bm = bmesh.new()
    outline = []
    for i in range(24):
        s = i / 24 * math.tau
        y = -0.13 * math.cos(s)  # -0.13 toe, +0.13 heel
        u = (y + 0.13) / 0.26
        half = 0.034 + 0.016 * bump(u - 0.25, 0.22) - 0.009 * bump(u - 0.58, 0.12)  # wide at the ball, narrow at the arch
        outline.append((half * math.sin(s), y))
    rings = []
    for z, inset in ((0.0, 0.003), (0.004, 0.0), (0.01, 0.0), (0.013, 0.003)):
        rings.append([bm.verts.new((x * (1 - inset / 0.05), y * (1 - inset / 0.15), z)) for x, y in outline])
    n = len(outline)
    faces = [bm.faces.new(rings[0][::-1]), bm.faces.new(rings[-1])]
    for a, b in zip(rings, rings[1:]):
        faces += [bm.faces.new([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]]) for i in range(n)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    me = bpy.data.meshes.new("slipper")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("slipper", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


FOOT = [
    [(0.097, 0.012, 0.11, 0.03, 0.034), (0.098, 0.016, 0.062, 0.031, 0.034), (0.1, -0.03, 0.04, 0.036, 0.024),
     (0.103, -0.085, 0.031, 0.042, 0.017), (0.106, -0.12, 0.026, 0.043, 0.013), (0.107, -0.142, 0.022, 0.038, 0.009)],
    [(0.098, 0.016, 0.062, 0.031, 0.034), (0.098, 0.04, 0.036, 0.026, 0.022)],
]
STRAP = [
    [(0.09, -0.112, 0.014, 0.003, 0.003), (0.093, -0.1, 0.034, 0.003, 0.004), (0.118, -0.07, 0.04, 0.004, 0.0025),
     (0.135, -0.045, 0.024, 0.004, 0.0025), (0.138, -0.035, 0.013, 0.004, 0.0025)],
    [(0.093, -0.1, 0.034, 0.003, 0.004), (0.072, -0.072, 0.038, 0.004, 0.0025), (0.062, -0.045, 0.022, 0.004, 0.0025),
     (0.061, -0.035, 0.013, 0.004, 0.0025)],
]


def feet() -> list:
    """Both feet in their slippers, toes turned a little out."""
    parts = []
    for side in (1, -1):
        foot = skin("foot", FOOT, mirror=False)
        strap = skin("strap", STRAP, mirror=False, levels=1)
        sole = slipper()
        sole.location = (0.1, -0.04, 0.0)
        common.select([sole])
        bpy.ops.object.transform_apply(location=True)
        for o in (foot, strap, sole):
            o.matrix_world = Matrix.Scale(side, 4, (1, 0, 0)) @ Matrix.Translation((0.098, 0.016, 0)) \
                @ Matrix.Rotation(0.14, 4, "Z") @ Matrix.Translation((-0.098, -0.016, 0))
            parts.append(o)
    return parts


# --- the cloth ----------------------------------------------------------------------------------------------

def drape(obj: bpy.types.Object, amount: float, bottom: float, top: float, bunch: float = 0.0) -> None:
    """Pushes obj's vertices along their normals into hanging folds: long vertical ridges, deeper towards the bottom
    (between the heights bottom and top), and with bunch, creases round the ankles."""
    me = obj.data
    for v in me.vertices:
        p = obj.matrix_world @ v.co
        a = math.atan2(p.x - (0.1 if p.x > 0 else -0.1) * (p.z < 0.85), p.y)
        ridge = perlin.noise(Vector((a * 2.6, p.z * 1.4, 1.7 + (p.x > 0)))) + 0.5 * perlin.noise(Vector((a * 6.0, p.z * 3.0, 9.1)))
        depth = amount * (0.4 + 0.6 * smooth((top - p.z) / (top - bottom)))
        crease = bunch * bump(p.z - 0.09, 0.05) * perlin.noise(Vector((a * 3.0, p.z * 30.0, 4.4)))
        v.co += v.normal * (depth * ridge + crease)


def body() -> bpy.types.Object:
    trousers = skin("trousers", TROUSERS)
    drape(trousers, 0.004, 0.05, 0.85, bunch=0.004)
    shirt = skin("shirt", SHIRT)
    drape(shirt, 0.005, 0.8, 1.35)
    parts = [trousers, shirt, skin("arms", ARM), skin("fingers", fingers()), skin("neck", NECK, mirror=False)]
    tipped = head()
    tip = Matrix.Translation(NECK_TOP) @ Matrix.Rotation(-NOD, 4, "X") @ Matrix.Rotation(ROLL, 4, "Y") @ Matrix.Translation(-NECK_TOP)
    for o in tipped:
        o.matrix_world = tip @ o.matrix_world
    parts += tipped + feet()
    common.select(parts)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in parts:  # mirrored parts (scale -1) came out inside out
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
    common.select(parts)
    bpy.ops.object.join()
    figure = bpy.context.view_layer.objects.active
    figure.name = "Figure"
    mat = bpy.data.materials.new("body")
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.03, 0.032, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    figure.data.materials.clear()
    figure.data.materials.append(mat)
    for f in figure.data.polygons:
        f.use_smooth = True
    return figure


# --- the apron ------------------------------------------------------------------------------------------------

GAP = 0.008  # the apron stands this far off the shirt
# What the apron lies on, by height: (z, half width, half depth, centre y). Below the hips it hangs straight down
# from them instead of following the legs in.
TORSO = [(0.88, 0.18, 0.124, 0.004), (0.95, 0.178, 0.122, 0.004), (1.04, 0.168, 0.118, 0.0),
         (1.18, 0.172, 0.12, -0.004), (1.3, 0.16, 0.108, 0.004), (1.36, 0.152, 0.1, 0.006)]
HEM_Z = 0.56  # the apron's hem; its waist is apron.WAIST above it, where the ties pull it in
BIB_DROP = 0.92  # the bib leans back over the chest: height gained per metre of cloth


def torso(z: float) -> tuple:
    z = min(max(z, TORSO[0][0]), TORSO[-1][0])
    for a, b in zip(TORSO, TORSO[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
    return TORSO[-1][1:]


def around(z: float, s: float, gap: float) -> Vector:
    """The point s metres round the front of the body at height z (positive towards the figure's left, +X), gap off it."""
    hx, hy, cy = torso(z)
    hx, hy = hx + gap, hy + gap
    phi, walked, step = 0.0, 0.0, 0.004
    while walked < abs(s) and phi < math.pi:
        walked += step * math.hypot(hx * math.cos(phi), hy * math.sin(phi))
        phi += step
    return Vector((math.copysign(hx * math.sin(phi), s), cy - hy * math.cos(phi), z))


def apron_z(v: float) -> float:
    return HEM_Z + v if v <= apron.WAIST else HEM_Z + apron.WAIST + (v - apron.WAIST) * BIB_DROP


def worn(u: float, v: float) -> Vector:
    """Where the apron's pattern point (u, v) is on the figure: wrapped round it, gathered a little at the waist and
    hanging in soft folds below it."""
    hang = smooth((apron.WAIST - v) / 0.35)
    fold = 0.007 * hang * math.sin(u * 52.0 + 2.0 * perlin.noise(Vector((u * 9.0, v * 3.0, 0.4))))
    gather = 0.0025 * bump(v - apron.WAIST, 0.03) * math.sin(u * 140.0)
    return around(apron_z(v), u, GAP + 0.004 * hang + fold + gather)


def wearing() -> bpy.types.Object:
    """The apron, worn: the panel round the front, the neck strap round the back of the neck, the ties round the
    waist to a bow at the back, its tails hanging."""
    bm = bmesh.new()
    vs = [0.0] + [0.02 * k for k in range(1, 23)] + [apron.WAIST + 0.03 * k for k in range(1, 12)] + [apron.LENGTH]
    rows = apron.panel(bm, worn, vs, 14)
    # The strap is sewn on just in from the bib's corners: from its left (+X) one, round the back of the neck.
    neck = [rows[-1][-2].co.copy(), Vector((0.097, -0.088, 1.39)), Vector((0.08, -0.048, 1.437)), Vector((0.074, 0.0, 1.46)),
            Vector((0.054, 0.05, 1.466)), Vector((0.0, 0.08, 1.462))]
    neck += [Vector((-p.x, p.y, p.z)) for p in reversed(neck[:-1])]
    neck[-1] = rows[-1][1].co.copy()
    apron.strap(bm, "neck", neck, [(p - Vector((0, 0.01, 1.3))).normalized() for p in neck])
    waist_z = apron_z(apron.WAIST) - 0.012
    for side, which in ((1, "left"), (-1, "right")):
        start = around(waist_z, side * apron.half_width(apron.WAIST), GAP)
        path = [around(waist_z, side * s, GAP) for s in (apron.half_width(apron.WAIST) + 0.02 * k for k in range(15))]
        path = [start] + [p for p in path if p.y > start.y + 0.005 and not (p.y > 0.11 and abs(p.x) < 0.012)]
        back = path[-1].y
        knot = Vector((side * 0.006, back + 0.006, waist_z))
        loop = [knot, Vector((side * 0.03, back + 0.016, waist_z + 0.016)), Vector((side * 0.06, back + 0.014, waist_z + 0.012)),
                Vector((side * 0.066, back + 0.012, waist_z - 0.008)), Vector((side * 0.035, back + 0.016, waist_z - 0.012)),
                Vector((side * 0.008, back + 0.018, waist_z - 0.004))]
        tail = [Vector((side * (0.012 + 0.004 * k + 0.003 * math.sin(k)), back + 0.016 - 0.0015 * k, waist_z - 0.03 - 0.03 * k))
                for k in range(6 if side > 0 else 5)]
        path += loop + tail
        normals = apron.ribbon_normals(path[:len(path) - len(loop) - len(tail)], Vector((0, 0.002, 0)))
        normals += [Vector((0, 1, 0))] * (len(loop) + len(tail))
        apron.strap(bm, which, path, normals)
    me = bpy.data.meshes.new("apron")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("apron", me)
    bpy.context.scene.collection.objects.link(obj)
    me.materials.append(apron.material())
    return obj


def triangles(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


BODY_TRIS = 10000  # of the model's 12000: the decimated body; the apron is the rest

common.reset()
figure = body()
fewer = figure.modifiers.new("fewer", "DECIMATE")
fewer.ratio = BODY_TRIS / triangles(figure)
applied(figure)
dress = wearing()
figure.data.uv_layers.new(name=dress.data.uv_layers[0].name)  # or the join drops the apron's
common.select([figure, dress])
bpy.ops.object.join()
print("FIGURE tris", triangles(figure), [uv.name for uv in figure.data.uv_layers])
common.export("figure", [figure])

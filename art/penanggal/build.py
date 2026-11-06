"""The penanggal: a woman's head flying loose of her body, her organs hanging from her neck. Run by tools/models.sh.

Her head and hair are the shared ones (art/shared/her), the same as the fourth passenger's: gaunt, grey-pale, the eyes
wide and dark, the mouth a little open, the long black hair wet and hanging in clumps. Her neck is torn off raggedly
under the jaw, bruised and bloodied down to the tear, its skin hanging in shreds. Below it hang what came out with her,
as the anatomy has them: the windpipe (ringed, the voice box at its top, splitting into the two bronchi) and the gullet
behind it; the carotid arteries and the jugular veins, and strings of sinew; two dark, spongy, lobed lungs; the heart
between them with its great vessels; the stomach at the end of the gullet; and three ropes of intestine, looped and
torn: the small one bunched in loops under the stomach and then hanging free (2.7 m along it, about 1.15 m of that
hanging), a second small one of 1.2 m and the large one of 1.5 m; everything ends about 2.05 m below the skull. And
strands of blood that drip. Everything is muted and wet: dark crimson, bruise purple and grey-pink, coloured per vertex.

Materials, so code can tell them apart: "skin" (the face and the neck: the painted texture, times the colour attribute,
white but for the neck's bruising and blood), "eyes", "hair" (black, seen from both sides) and "entrails" (the organs,
the torn neck and the blood, coloured per vertex: the attribute "Color"). The hair and the entrails hang along -Z (the
game's -Y) below the head, with vertices every few cm along their length, for a sway that grows with the distance below
the head. The origin is the centre of the skull; she faces -Y, which is the game's +Z.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils import noise as perlin

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "her")]
import common  # noqa: E402
import her  # noqa: E402
from her import bump, smooth  # noqa: E402

perlin.seed_set(4401)

# Colours, linear: the muted palette of the brief.
CRIMSON = (0.11, 0.012, 0.016)
BLOOD = (0.05, 0.003, 0.005)
BRUISE = (0.075, 0.028, 0.06)
GREY_PINK = (0.3, 0.17, 0.165)
FAT = (0.27, 0.21, 0.12)


def mix(a: tuple, b: tuple, t: float) -> tuple:
    t = min(max(t, 0.0), 1.0)
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def rgba(c: tuple) -> tuple:
    return (*c, 1.0)


def n3(p: Vector, scale: float, seed: float = 0.0) -> float:
    """Perlin noise at p, 0 centred, about -1..1."""
    return perlin.noise(p * scale + Vector((seed, seed * 0.7, seed * 1.3)))


# --- tubes ----------------------------------------------------------------------------------------------

def frames(path: list) -> list:
    """(tangent, normal, binormal) along path, the normal carried along without twisting."""
    out = []
    t0 = (path[1] - path[0]).normalized()
    n = t0.cross(Vector((0.0, 1.0, 0.0)) if abs(t0.y) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
    for i in range(len(path)):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        n = (n - t * n.dot(t)).normalized()
        out.append((t, n, t.cross(n)))
    return out


def tube(bm: bmesh.types.BMesh, path: list, radius, sides: int, colour, caps: tuple = (True, True), lumps: tuple = (0.0, 1.0)) -> list:
    """A tube along path. radius(u, a) -> (r across, r along the binormal) at u (0..1 along) and the angle a; colour(p, u,
    a) -> RGB. A cap is a point when the radius there is 0, a fan when it is not, and nothing when caps says so. lumps:
    (amount, per metre), pushing the surface in and out by that fraction of its radius, so nothing is a clean hose.
    Returns the faces, coloured, material "entrails"."""
    fr = frames(path)
    rings = []
    for i, (p, (t, n, b)) in enumerate(zip(path, fr)):
        u = i / (len(path) - 1)
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            rx, ry = radius(u, a)
            q = n * (rx * math.cos(a)) + b * (ry * math.sin(a))
            if lumps[0]:
                q *= 1.0 + lumps[0] * n3(p + q, lumps[1], 11.0)
            ring.append(bm.verts.new(p + q))
        rings.append(ring)
    faces = []
    for a_, b_ in zip(rings, rings[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            faces.append(bm.faces.new([a_[k], a_[j], b_[j], b_[k]]))
    for ring, end, cap, flip in ((rings[0], path[0], caps[0], True), (rings[-1], path[-1], caps[1], False)):
        if not cap:
            continue
        c = bm.verts.new(cap if isinstance(cap, Vector) else end)
        for k in range(sides):
            j = (k + 1) % sides
            faces.append(bm.faces.new([ring[j], ring[k], c] if flip else [ring[k], ring[j], c]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    layer = bm.loops.layers.float_color["Color"]
    index = {v: (i, k) for i, ring in enumerate(rings) for k, v in enumerate(ring)}
    for f in faces:
        f.material_index = ENTRAILS
        f.smooth = True
        for loop in f.loops:
            i, k = index.get(loop.vert, (0 if (loop.vert.co - path[0]).length < (loop.vert.co - path[-1]).length else len(path) - 1, 0))
            loop[layer] = rgba(colour(loop.vert.co, i / (len(path) - 1), math.tau * k / sides))
    return faces


def resample(points: list, step: float) -> list:
    """A smooth path through points (a Catmull-Rom spline) with a point every step metres or so."""
    pts = [points[0]] + points + [points[-1]]
    dense = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(12):
            t = k / 12
            dense.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    dense.append(points[-1])
    out, walked = [dense[0]], 0.0
    for a, b in zip(dense, dense[1:]):
        walked += (b - a).length
        if walked >= step:
            out.append(b)
            walked = 0.0
    if (out[-1] - dense[-1]).length > step * 0.3:
        out.append(dense[-1])
    else:
        out[-1] = dense[-1]
    return out


def length(path: list) -> float:
    return sum((b - a).length for a, b in zip(path, path[1:]))


# --- the organs -----------------------------------------------------------------------------------------

ENTRAILS = 3  # material index: skin, eyes, hair, entrails


def neck(bm: bmesh.types.BMesh) -> list:
    """The neck, torn off under the jaw. Its skin (material 0, the painted texture) is gaunt: two cords running down
    and in, and between them the throat fallen in, where the windpipe and the gullet were pulled out from under it.
    It lies in the jaw's shadow under the jaw; lower down it is bruised, run with blood from her mouth, and in
    patches just above the tear soaked and wet (entrails). The tear wanders up and down round the neck by over 3 cm,
    jagged, never cut; below it the skin hangs in shreds of every length, up to 8.5 cm, falling in and curling, raw
    on their insides, or where there is no shred its torn edge rolls out. Within the tear the torn flesh bulges out,
    lumpy: a ring of yellow fat under the skin, then dark muscle. Returns the long shreds' tips, where blood drips
    from."""
    sides, lower = 36, 6
    fractions = (0.0, 0.3, 0.5, 0.63, 0.74, 0.83, 0.9, 0.95, 1.0)  # the rings from the neck's top down to the tear
    upper = len(fractions)
    top, bottom = Vector((0.0, 0.016, -0.04)), Vector((0.0, -0.002, -0.165))
    shreds = ((0.25, 0.14, 0.07), (-0.38, 0.07, 0.035), (0.9, 0.09, 0.045), (-0.95, 0.12, 0.115), (1.55, 0.16, 0.085),
              (-1.7, 0.09, 0.05), (2.35, 0.2, 0.1), (-2.5, 0.13, 0.06), (3.05, 0.09, 0.03))  # (angle, width, length)

    def at(a: float, z: float, inward: float = 0.0) -> Vector:
        """The skin at the angle a round the neck (0 at her throat, + to her left) and the height z, pulled in by that
        fraction."""
        u = (top.z - z) / (top.z - bottom.z)
        uc = min(max(u, 0.0), 1.0)
        out = Vector((math.sin(a), -math.cos(a), 0.0))
        cords = sum(bump(math.remainder(a - side * (0.95 - 0.45 * uc), math.tau), 0.26) for side in (1.0, -1.0))
        fallen = bump(math.remainder(a, math.tau), 0.5) * (0.035 + 0.42 * smooth((u - 0.4) / 0.5))  # the throat
        k_ = (1.0 + 0.05 * n3(Vector((out.x, out.y, z * 6.0)), 2.2, 4.0) + 0.08 * cords * (1.0 - 0.3 * uc) - fallen) * (1.0 - inward)
        centre = top + (bottom - top) * u
        return centre + Vector((out.x * (0.045 + 0.002 * uc) * k_, out.y * (0.048 + 0.003 * uc) * k_, 0.0))

    angles = [math.tau * k / sides for k in range(sides)]
    rounds = [Vector((math.cos(a), math.sin(a), 0.0)) for a in angles]  # for noise round the neck, with no seam
    cuts, soaked, reach, drops, rolls = [], [], [], [], []
    for k, (a, r) in enumerate(zip(angles, rounds)):
        c = -0.149 + 0.008 * n3(r, 1.3, 2.0)
        c += 0.017 * bump(math.remainder(a + 0.8, math.tau), 0.32)  # bitten high on her right
        c -= 0.013 * bump(math.remainder(a - 0.3, math.tau), 0.22)  # torn low under her chin, to her left
        c -= 0.012 * bump(math.remainder(a - 2.2, math.tau), 0.5)  # and low at the back
        c += 0.004 * n3(r, 7.0, 9.0) + 0.003 * (1 if k % 2 else -1) * (0.3 + 0.7 * abs(n3(r, 3.0, 13.0)))  # jagged
        cuts.append(min(max(c, -0.183), -0.124))
        soaked.append(0.004 + 0.012 * max(0.0, n3(r, 3.0, 21.0) + 0.2))  # how far above the tear it is soaked, in patches
        reach.append(0.016 + 0.012 * (0.5 + 0.5 * n3(r, 2.6, 27.0)))  # and bruised above that
        shred = max(l * bump(math.remainder(a - fa, math.tau), w) for fa, w, l in shreds)
        drops.append(max(0.003 + 0.006 * abs(n3(r, 4.0, 5.0)), shred))
        rolls.append(1.0 - smooth(shred / 0.015))  # no shred: the skin's torn edge rolls out
    columns = []
    for a, r, c, drop, roll in zip(angles, rounds, cuts, drops, rolls):
        column = [at(a, top.z + (c - top.z) * f) for f in fractions]
        for j in range(1, lower + 1):
            h = drop * j / lower
            inward = 0.2 * smooth(h / 0.03) + 0.1 * smooth((h - 0.03) / 0.06) - 0.14 * roll * smooth(h / drop)
            curl = 0.25 * smooth((h - drop + 0.02) / 0.02) * smooth((drop - 0.04) / 0.03)  # the long ones' tips turn out
            twist = 0.3 * n3(r, 2.0, 31.0) * smooth(h / 0.1)
            column.append(at(a + twist, c - h, inward - curl))
        columns.append(column)
    verts = [[bm.verts.new(columns[k][i]) for k in range(sides)] for i in range(upper + lower)]
    column_of = {v: k for ring in verts for k, v in enumerate(ring)}

    def band(rings: list, out: bool) -> list:
        """Quads between rings (each running round the neck the same way); out: facing away from the neck's middle
        (or, for rings going inwards, down)."""
        faces = []
        for a_, b_ in zip(rings, rings[1:]):
            for k in range(sides):
                j = (k + 1) % sides
                quad = [a_[k], a_[j], b_[j], b_[k]]
                faces.append(bm.faces.new(quad[::-1] if out else quad))
        return faces

    def middle(p: Vector) -> Vector:
        return top + (bottom - top) * ((top.z - p.z) / (top.z - bottom.z))
    skin = band(verts[:upper], True)
    lip = band(verts[upper - 1:], True)
    # the torn skin's raw inside: the lip and the shreds again, a mm in from the skin, facing in
    raw_rings = [[bm.verts.new(v.co.lerp(middle(v.co), 0.025)) for v in ring] for ring in verts[upper - 1:]]
    raw = band(raw_rings, False)
    # inside the tear the flesh bulges out and down, lumpy: the fat under the skin's edge, then the muscle
    low = sum(cuts) / sides - 0.014
    inner = []
    for left, lumps in ((0.93, 0.0), (0.8, 0.002), (0.56, 0.005), (0.3, 0.006)):
        ring = []
        for k, v in enumerate(verts[upper - 1]):
            c = middle(v.co)
            p = c + (v.co - c) * left
            p.z = cuts[k] + (low - cuts[k]) * (1.0 - left) ** 0.8 + lumps * n3(rounds[k] * (2.0 - left), 2.0, 7.0)
            ring.append(bm.verts.new(p))
        inner.append(ring)
    flesh = band([verts[upper - 1]] + inner, True)
    centre = bm.verts.new(Vector((0.0, 0.004, low - 0.003)))
    flesh += [bm.faces.new([inner[-1][(k + 1) % sides], inner[-1][k], centre]) for k in range(sides)]
    her.paint(bm, skin, 0)
    layers = {v: i + 1 for i, ring in enumerate(inner) for v in ring}
    layers[centre] = 5
    span = {v: j / lower for j, ring in enumerate(raw_rings) for v in ring}
    hang = {v: j / lower for j, ring in enumerate(verts[upper - 1:]) for v in ring}
    colours = bm.loops.layers.float_color["Color"]

    def wet(f: bmesh.types.BMFace) -> bool:
        """A face of the skin within the soaked band above the tear."""
        k = column_of[f.loops[0].vert]
        return max(l.vert.co.z for l in f.loops) < cuts[k] + soaked[k]
    for f in skin:
        k = column_of[f.loops[0].vert]
        if wet(f):
            f.material_index = ENTRAILS
        for loop in f.loops:
            q = loop.vert.co
            above = q.z - cuts[k]
            if wet(f):  # soaked: bruise-dark, black with blood at the tear
                c = mix(mix(BRUISE, CRIMSON, 0.6 + 0.3 * n3(q, 90, 2.0)), BLOOD, 0.85 * smooth(1.0 - above / soaked[k]))
            else:  # the texture's skin, times: in the jaw's shadow, bruised, then bloodied down to the soaked band
                t = smooth(1.0 - (above - soaked[k]) / reach[k])
                c = mix((1.0, 1.0, 1.0), (0.75, 0.55, 0.62), smooth(t / 0.5))
                run = smooth(n3(Vector((q.x, q.y, q.z * 0.1)), 160, 41.0) / 0.3)  # blood run down from her mouth
                c = mix(c, (0.45, 0.14, 0.15), smooth((t - 0.5) / 0.5) * (0.35 + 0.65 * run))
                shade = 1.0 - 0.5 * math.exp(-max(her.solid(q), 0.0) / 0.006)
                c = tuple(x * shade for x in c)
            loop[colours] = rgba(c)

    def colour(v: bmesh.types.BMVert) -> tuple:
        q = v.co
        if v in span:  # raw flesh, fresh at the torn edge with fat in it, bloodier to the shreds' ends
            raw_ = mix((0.3, 0.085, 0.09), FAT, 0.45 * smooth((n3(q, 70, 1.0) - 0.1) / 0.3))
            return mix(raw_, BLOOD, 0.15 + 0.7 * span[v])
        if v in hang:  # the lip and the shreds outside: bruised skin, run with blood
            run = n3(Vector((q.x, q.y, q.z * 0.15)), 140, 6.0)
            return mix((0.3, 0.19, 0.22), mix(CRIMSON, BLOOD, 0.5), 0.3 + 0.4 * run + 0.25 * hang[v])
        layer = layers.get(v, 0)
        if layer <= 1:  # where the skin tore, then the fat under it
            return mix(mix(BRUISE, CRIMSON, 0.5), mix((0.24, 0.17, 0.12), FAT, 0.5 + 0.5 * n3(q, 90)), layer)
        return mix(CRIMSON, BLOOD, 0.4 + 0.5 * n3(q, 60, 3.0))
    for f in flesh + raw + lip:
        f.material_index = ENTRAILS
        f.smooth = True
        for loop in f.loops:
            loop[colours] = rgba(colour(loop.vert))
    return [columns[k][-1] for k in range(sides) if drops[k] > 0.06 and drops[k] >= max(drops[k - 1], drops[(k + 1) % sides])]


def sinews(bm: bmesh.types.BMesh) -> list:
    """What else came out of the neck with her, hanging from the torn flesh: the two carotid arteries down into the arch
    of the aorta, the jugular veins (the right one into the vena cava, the left torn free), strips of torn neck muscle,
    and strings of sinew pulled down to the tops of the lungs. Returns the free ends, where blood drips from."""
    ends = []
    artery, vein = (0.0042, 1.0, CRIMSON, (0.24, 0.13, 0.13)), (0.0055, 0.55, BLOOD, BRUISE)
    vessels = [  # (points, radius, flattened, colour at the top, colour along)
        ([(0.02, -0.014, -0.15), (0.024, -0.024, -0.2), (0.022, -0.03, -0.26), (0.02, -0.03, -0.316)], *artery),
        ([(-0.02, -0.014, -0.15), (-0.018, -0.026, -0.21), (-0.008, -0.034, -0.28), (0.004, -0.038, -0.33)], *artery),
        ([(-0.032, 0.0, -0.148), (-0.036, -0.012, -0.2), (-0.03, -0.022, -0.26), (-0.022, -0.024, -0.312)], *vein),
        ([(0.033, 0.0, -0.148), (0.038, -0.01, -0.19), (0.036, -0.016, -0.235), (0.042, -0.012, -0.262)], *vein),  # torn free
    ]
    for i, (points, r, flat, top, along) in enumerate(vessels):
        path = resample([Vector(p) for p in points], 0.014)
        free = i == 3
        tube(bm, path, lambda u, a, r=r, flat=flat, free=free: (r * (1.0 + 0.3 * free * smooth((u - 0.85) / 0.15)), r * flat), 5,
             lambda p, u, a, top=top, along=along: mix(mix(top, along, smooth(u / 0.3)), CRIMSON,
                                                       0.45 * smooth((n3(p, 40, 3.0) + 0.1) / 0.4)),
             caps=(False, not free), lumps=(0.06, 40.0))
        if free:
            ends.append(path[-1])
    strips = [  # torn strips of the muscles down the front of the neck: (from, to, width)
        ((0.012, -0.022, -0.152), (0.016, -0.034, -0.215), 0.0055),
        ((-0.01, -0.02, -0.15), (-0.014, -0.03, -0.19), 0.0045),
        ((0.03, -0.01, -0.158), (0.034, -0.016, -0.24), 0.004),
    ]
    for start, end, w in strips:
        a, b = Vector(start), Vector(end)
        path = resample([a, a.lerp(b, 0.5) + Vector((0.002, -0.003, 0.0)), b], 0.012)
        tube(bm, path, lambda u, a_, w=w: (w * (1.0 - 0.75 * u), 0.0016), 4,
             lambda p, u, a_: mix(CRIMSON, BLOOD, 0.3 + 0.5 * u + 0.2 * n3(p, 120, 4.0)), caps=(False, True))
        ends.append(path[-1])
    for side in (1, -1):  # sinew pulled taut down to the lung's top
        path = resample([Vector((side * 0.026, 0.008, -0.152)), Vector((side * 0.036, 0.006, -0.25)),
                         Vector((side * 0.05, 0.0, -0.37))], 0.02)
        tube(bm, path, lambda u, a: (0.0014,) * 2, 4,
             lambda p, u, a: mix((0.28, 0.18, 0.17), CRIMSON, 0.3 + 0.5 * smooth((n3(p, 50, 8.0) + 0.2) / 0.4)), caps=(False, False))
    return ends


def windpipe(bm: bmesh.types.BMesh) -> None:
    """The voice box, the windpipe below it, its cartilage rings faint and uneven under the blood, and its two bronchi
    turning down into the lungs."""
    path = resample([Vector((0.0, -0.008, -0.15)), Vector((0.0, -0.018, -0.18)), Vector((0.003, -0.024, -0.21)), Vector((-0.002, -0.021, -0.26)),
                     Vector((0.002, -0.014, -0.315))], 0.0055)
    total = length(path)

    def rings(s: float) -> float:
        """-1..1 round the cartilage rings at s along it: uneven in spacing."""
        return math.cos(math.tau * s / 0.0135 + 2.5 * n3(Vector((s * 25.0, 0.0, 1.0)), 1.0))

    def radius(u: float, a: float) -> tuple:
        s = u * total
        box = smooth((0.045 - s) / 0.015)  # the voice box, wider, its front a blunt ridge
        r = 0.0098 + 0.007 * box * (1.0 + 0.35 * max(math.cos(a), 0.0) ** 3)
        r += 0.0004 * (1.0 - box) * rings(s)
        return r, r * (0.92 + 0.08 * box)

    def colour(p: Vector, u: float, a: float) -> tuple:
        s = u * total
        pale = mix((0.24, 0.14, 0.13), GREY_PINK, 0.3 + 0.5 * n3(p, 80))
        c = mix(pale, (0.2, 0.08, 0.08), 0.12 * (0.5 - 0.5 * rings(s)))
        c = mix(c, CRIMSON, 0.9 * smooth((0.03 - s) / 0.02) + 0.75 * smooth((n3(p, 30, 5.0) + 0.25) / 0.5))  # smeared
        return mix(c, BLOOD, 0.7 * smooth((n3(p, 55, 2.0) - 0.1) / 0.3))  # clotted
    tube(bm, path, radius, 7, colour, caps=(True, False))
    for side in (1, -1):
        branch = resample([path[-1], Vector((side * 0.02, -0.012, -0.335)), Vector((side * 0.042, -0.006, -0.355)),
                           Vector((side * 0.05, -0.002, -0.38))], 0.008)
        tube(bm, branch, lambda u, a: (0.0085 - 0.002 * u,) * 2, 6,
             lambda p, u, a: mix((0.32, 0.22, 0.21), BRUISE, u), caps=(False, False))


def gullet(bm: bmesh.types.BMesh) -> None:
    """The gullet, behind the windpipe, down to the stomach: a flattened muscular tube."""
    path = resample([Vector((0.0, 0.01, -0.135)), Vector((0.002, 0.016, -0.25)), Vector((0.006, 0.02, -0.38)),
                     Vector((0.012, 0.02, -0.5)), Vector((0.018, 0.016, -0.585))], 0.022)
    tube(bm, path, lambda u, a: (0.0105, 0.0072), 6,
         lambda p, u, a: mix((0.19, 0.065, 0.065), CRIMSON, 0.3 + 0.4 * n3(p, 40)), caps=(True, False))


def lungs(bm: bmesh.types.BMesh) -> None:
    """Two lungs out of the chest, hanging from their bronchi: collapsed, heavy at the base, the flat side towards the
    heart, cut into lobes (three on her right, two on her left), spongy, dark: mottled purple-grey and crimson with black
    specks."""
    for side in (1, -1):
        path = resample([Vector((side * 0.05, 0.0, -0.36)), Vector((side * 0.07, 0.006, -0.44)),
                         Vector((side * 0.08, 0.01, -0.53)), Vector((side * 0.078, 0.006, -0.63))], 0.019)

        def radius(u: float, a: float, side=side) -> tuple:
            # narrow at the apex, broadest low down, the base flat and sharp-edged where it sat on the diaphragm
            profile = math.sin(0.5 * math.pi * min(u / 0.84, 1.0)) ** 1.3 * math.sqrt(max(0.0, 1.0 - (max(u - 0.84, 0.0) / 0.16) ** 2))
            r = 0.06 * profile + 0.004
            towards_middle = max(0.0, -side * math.cos(a))
            rx = r * (1.0 - 0.38 * towards_middle ** 2)
            fissure = 0.0
            for f_u, slope, depth in ((0.42, 0.12, 0.16), (0.62, -0.1, 0.12 if side < 0 else 0.0)):
                fissure += depth * bump(u - f_u - slope * math.sin(a), 0.03)
            sponge = 1.0 + 0.05 * n3(Vector((u * 9, a, side)), 1.0, 2.0)
            k = (1.0 - fissure) * sponge
            return rx * k, r * 0.85 * k

        def colour(p: Vector, u: float, a: float, side=side) -> tuple:
            m = n3(p, 45, side)
            c = mix((0.19, 0.09, 0.11), (0.16, 0.04, 0.05), 0.5 + 0.8 * m)
            c = mix(c, (0.06, 0.022, 0.04), 0.8 * smooth((n3(p, 110, 9 + side) - 0.15) / 0.2))  # darker, congested patches
            c = mix(c, (0.012, 0.01, 0.012), smooth((n3(p, 260, 4 + side) - 0.42) / 0.08))  # black specks
            c = mix(c, (0.02, 0.008, 0.016), 0.7 * smooth((0.05 - abs(n3(p, 70, 6 + side))) / 0.04))  # the lobules' web
            return mix(c, BLOOD, 0.5 * smooth((u - 0.85) / 0.15))
        tube(bm, path, radius, 11, colour, caps=(True, True), lumps=(0.09, 28.0))


def heart(bm: bmesh.types.BMesh) -> None:
    """The heart, hanging in front between the lungs, its point down and to her left: maroon, fat in its grooves, the
    stubs of the aorta (arching over to her left) and the pulmonary trunk torn off above it."""
    path = resample([Vector((0.006, -0.042, -0.355)), Vector((0.014, -0.05, -0.395)), Vector((0.026, -0.056, -0.44)),
                     Vector((0.036, -0.058, -0.476))], 0.012)

    def radius(u: float, a: float) -> tuple:
        r = 0.041 * math.sin(math.pi * (0.18 + 0.82 * u)) ** 0.7 * (1.0 - 0.25 * u) + 0.002
        r *= 1.0 - 0.05 * bump(u - 0.2, 0.05)  # the groove between the atria and the ventricles
        r *= 1.0 - 0.04 * bump(math.remainder(a - 0.8 + 0.6 * u, math.tau), 0.15) * smooth((u - 0.2) / 0.1)  # and down its front
        return r, r * 0.82

    def colour(p: Vector, u: float, a: float) -> tuple:
        c = mix((0.1, 0.018, 0.024), (0.07, 0.012, 0.03), 0.5 + 0.7 * n3(p, 50))
        fat = bump(u - 0.2, 0.06) + 0.8 * bump(math.remainder(a - 0.8 + 0.6 * u, math.tau), 0.18) * smooth((u - 0.2) / 0.1) * (1 - u)
        return mix(c, FAT, min(fat, 1.0) * (0.55 + 0.4 * n3(p, 120, 2.0)))
    tube(bm, path, radius, 12, colour, caps=(True, True))
    vessels = [
        ([Vector((0.004, -0.04, -0.37)), Vector((0.004, -0.038, -0.335)), Vector((0.02, -0.028, -0.318)),
          Vector((0.036, -0.012, -0.322)), Vector((0.04, 0.004, -0.34))], 0.0105),  # the aorta, over to her left
        ([Vector((0.016, -0.05, -0.37)), Vector((0.022, -0.054, -0.345)), Vector((0.03, -0.05, -0.33))], 0.0095),
        ([Vector((-0.016, -0.036, -0.37)), Vector((-0.02, -0.03, -0.335)), Vector((-0.022, -0.024, -0.315))], 0.009),  # vena cava
    ]
    for points, r in vessels:
        path = resample(points, 0.009)
        tube(bm, path, lambda u, a, r=r: (r * (1.0 + 0.1 * u),) * 2, 6,
             lambda p, u, a: mix((0.3, 0.19, 0.18), CRIMSON, 0.3 + 0.7 * smooth((u - 0.8) / 0.2)), caps=(False, True))


def stomach(bm: bmesh.types.BMesh) -> tuple:
    """The stomach at the end of the gullet, hanging: a J-shaped sac, collapsed and lumpy, swelling to her left and
    turning back up to the pylorus. Returns the pylorus and a point low on its greater curve."""
    points = [Vector((0.018, 0.016, -0.585)), Vector((0.05, 0.008, -0.62)), Vector((0.07, 0.0, -0.69)),
              Vector((0.062, -0.006, -0.77)), Vector((0.03, -0.01, -0.82)), Vector((-0.012, -0.012, -0.815)),
              Vector((-0.034, -0.012, -0.785))]
    path = resample(points, 0.02)

    def radius(u: float, a: float) -> tuple:
        r = 0.011 + 0.043 * math.sin(math.pi * min(u * 1.1, 1.0)) ** 0.8 * (1.0 - 0.45 * u)
        r *= 1.0 - 0.12 * abs(n3(Vector((u * 14.0, a * 0.6, 3.0)), 1.0))  # collapsed, creased
        return r, r * 0.7

    def colour(p: Vector, u: float, a: float) -> tuple:
        c = mix(GREY_PINK, (0.22, 0.12, 0.14), 0.5 + 0.7 * n3(p, 35))
        vessel = smooth((0.06 - abs(n3(p, 55, 8.0))) / 0.05)  # the vessels along its curves
        c = mix(c, BRUISE, 0.6 * vessel)
        return mix(c, CRIMSON, 0.35 * smooth((n3(p, 20, 6.0) - 0.2) / 0.3))
    tube(bm, path, radius, 11, colour, caps=(False, False), lumps=(0.16, 26.0))
    return path[-1], path[len(path) // 2]


def gut(bm: bmesh.types.BMesh, points: list, r: float, large: bool, sides: int, step: float, seed: float) -> Vector:
    """A rope of intestine through points: the small one irregular where it was squeezed, the large one in pouches;
    torn open at its end. Returns where it ends."""
    path = resample(points, step)
    total = length(path)
    print("GUT", "large" if large else "small", round(total, 2), "m")

    def radius(u: float, a: float) -> tuple:
        s = u * total
        k = 1.0 + 0.13 * n3(Vector((s * 9.0, seed, 0)), 1.0)
        if large:
            k *= 0.86 + 0.24 * abs(math.sin(math.pi * s / 0.036))  # haustra
            k *= 1.0 - 0.08 * max(0.0, math.cos(3 * a)) ** 4  # the three bands down it
        k *= 1.0 + 0.25 * smooth((u - 0.985) / 0.015)  # flared where it tore
        return r * k, r * k * 0.9

    def colour(p: Vector, u: float, a: float) -> tuple:
        base = (0.17, 0.1, 0.11) if large else GREY_PINK
        c = mix(base, (0.21, 0.1, 0.13), 0.5 + 0.8 * n3(p, 28, seed))
        c = mix(c, BRUISE, 0.55 * smooth((n3(p, 12, seed + 4) - 0.15) / 0.3))
        c = mix(c, (0.26, 0.2, 0.12), 0.5 * smooth((n3(p, 16, seed + 2) - 0.45) / 0.15))  # fat on the mesentery's edge
        c = mix(c, CRIMSON, 0.5 * smooth((n3(p, 7, seed + 9) - 0.25) / 0.3) + 0.6 * smooth((u - 0.94) / 0.06))
        return c
    tube(bm, path, radius, sides, colour, caps=(False, path[-1] + (path[-2] - path[-1]).normalized() * r * 1.5),
         lumps=(0.1, 30.0))
    return path[-1]


def coils(top: Vector, centre: Vector, loops: list) -> list:
    """Points for the small intestine bunched in loops under the stomach, each hanging from the root of its mesentery at
    centre: loops [(angle round, reach out, depth)]."""
    def at(angle: float, out: float, down: float) -> Vector:
        return centre + Vector((out * math.sin(angle), -out * math.cos(angle), -down))
    points = [top]
    for angle, out, depth in loops:
        points += [at(angle - 0.45, 0.025, 0.0), at(angle - 0.3, out * 0.75, depth * 0.6), at(angle, out, depth),
                   at(angle + 0.3, out * 0.75, depth * 0.6), at(angle + 0.45, 0.025, 0.0)]
    return points


def hanging(start: Vector, keys: list) -> list:
    """Points for a rope from start through keys [(x, y, z)] relative to the skull's centre."""
    return [start] + [Vector(k) for k in keys]


def blood(bm: bmesh.types.BMesh, start: Vector, drop: float, seed: float, r: float = 0.0022) -> None:
    """A strand of blood hanging drop metres from start, thinning, a drop forming at its end."""
    n = max(3, int(drop / 0.02))
    path = [start + Vector((0.002 * n3(Vector((k, seed, 0)), 0.7), 0.002 * n3(Vector((k, seed, 3)), 0.7), -drop * k / n)) for k in range(n + 1)]
    end = path[-1]
    path.append(end + Vector((0, 0, -0.004)))
    path.append(end + Vector((0, 0, -0.008)))

    def radius(u: float, a: float) -> tuple:
        last = len(path) - 1
        i = u * last
        if i > last - 2.5:
            rr = r * 1.8 * math.sin(math.pi * min((i - (last - 2.5)) / 2.5, 1.0) * 0.9 + 0.15)  # the drop
        else:
            rr = r * (1.0 - 0.45 * u)
        return rr, rr
    tube(bm, path, radius, 4, lambda p, u, a: mix(CRIMSON, BLOOD, 0.4 + 0.4 * u), caps=(False, True))


def organs(bm: bmesh.types.BMesh) -> None:
    tips = neck(bm)
    tips += sinews(bm)
    windpipe(bm)
    gullet(bm)
    lungs(bm)
    heart(bm)
    pylorus, curve = stomach(bm)
    root = Vector((0.0, -0.005, -0.85))
    bunch = coils(pylorus, root, [(-1.9, 0.075, 0.13), (-0.6, 0.085, 0.17), (0.7, 0.07, 0.12), (2.0, 0.08, 0.16), (3.1, 0.06, 0.11)])
    ends = [gut(bm, bunch + [Vector(k) for k in [(-0.03, -0.03, -0.96), (-0.04, -0.035, -1.12), (-0.02, -0.035, -1.3),
                                                  (-0.035, -0.03, -1.5), (-0.02, -0.03, -1.7), (-0.03, -0.025, -1.9),
                                                  (-0.02, -0.025, -2.0)]], 0.0125, False, 6, 0.03, 1.0)]
    ends.append(gut(bm, hanging(curve + Vector((0.01, 0.0, -0.01)), [(0.08, 0.025, -0.86), (0.085, 0.035, -1.0),
                                                                    (0.06, 0.04, -1.2), (0.02, 0.04, -1.32),
                                                                    (-0.02, 0.035, -1.24), (-0.03, 0.03, -1.08),
                                                                    (-0.06, 0.03, -1.12), (-0.075, 0.025, -1.35),
                                                                    (-0.07, 0.02, -1.55), (-0.08, 0.015, -1.7)]),
                    0.019, True, 7, 0.028, 5.0))
    ends.append(gut(bm, hanging(root + Vector((0.03, 0.03, -0.08)), [(0.05, 0.03, -1.0), (0.045, 0.02, -1.15),
                                                                    (0.085, 0.01, -1.27), (0.08, 0.0, -1.4),
                                                                    (0.035, -0.005, -1.37), (0.03, 0.0, -1.5),
                                                                    (0.055, -0.005, -1.7), (0.045, -0.01, -1.85),
                                                                    (0.05, -0.01, -2.05)]),
                    0.0115, False, 6, 0.032, 9.0))
    drips = [(Vector((0.078, 0.006, -0.64)), 0.16),
             (Vector((-0.078, 0.006, -0.64)), 0.09), (Vector((0.036, -0.058, -0.478)), 0.22), (Vector((0.03, -0.01, -0.83)), 0.12),
             (Vector((-0.06, -0.01, -1.0)), 0.15), (Vector((0.07, 0.0, -1.0)), 0.2)]
    drips += [(e, d) for e, d in zip(ends, (0.18, 0.1, 0.26))]
    drips += [(t, d) for t, d in zip(tips, (0.09, 0.05, 0.13, 0.07, 0.11, 0.06, 0.08, 0.04))]
    for i, (p, d) in enumerate(drips):
        blood(bm, p, d, i * 3.1)


def entrails_material() -> bpy.types.Material:
    """"entrails": the colour per vertex, wet."""
    mat = bpy.data.materials.new("entrails")
    mat.use_backface_culling = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.36
    return mat


def skin_material() -> bpy.types.Material:
    """Her "skin" (the painted texture), times the colour attribute: white on her face, the bruising and the blood down
    her neck."""
    mat = her.skin_material()
    nt = mat.node_tree
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    times = nt.nodes.new("ShaderNodeMix")
    times.data_type, times.blend_type = "RGBA", "MULTIPLY"
    times.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], times.inputs["A"])
    nt.links.new(attr.outputs["Color"], times.inputs["B"])
    nt.links.new(times.outputs["Result"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return mat


def triangles(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


common.reset()
skin, eyes_mat, hair_mat = skin_material(), her.eyes_material(), her.hair_material()
head = her.head("head", 2400)
eyes = her.eyes("eyes")
colliders = [(Vector((0.0, 0.004, -0.05)), Vector((0.0, -0.002, -0.2)), 0.056)]
colliders += [(Vector((s * 0.06, 0.004, -0.38)), Vector((s * 0.078, 0.008, -0.6)), 0.062) for s in (1, -1)]
plastered = [(Vector((0.62, -0.62, 0.42)), Vector((0.15, 0.0, -1.0))), (Vector((-0.3, -0.72, 0.62)), Vector((-0.12, 0.0, -1.0))),
             (Vector((-0.12, -0.7, 0.7)), Vector((0.05, 0.0, -1.0)))]
hair_parts = her.hair(Matrix(), 44, (0.6, 0.78), colliders, 600, plastered)
bm = her.new_bmesh()
organs(bm)
body = her.to_object("organs", bm, [skin, eyes_mat, hair_mat, entrails_material()])
her.front_uv(body)
parts = [head, eyes] + hair_parts + [body]
for o in parts:
    print("PART", o.name, triangles(o))
common.select(parts)
bpy.ops.object.join()
penanggal = bpy.context.view_layer.objects.active
penanggal.name = penanggal.data.name = "Penanggal"
print("PENANGGAL tris", triangles(penanggal), [m.name for m in penanggal.data.materials])
common.export("penanggal", [penanggal])

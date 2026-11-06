"""Mei: Chinese Malaysian, early twenties, beside Hafiz in the front. A cropped oatmeal cardigan, open, over a plain
navy fit-and-flare dress; a chin-length bob parted on her left; the theme park's lanyard round her neck, its card plain
(no logo); worn white sneakers; her phone in her right hand, its screen lighting her face from below.

Two models (art/shared/person builds them):
- mei_seated: the front passenger seat, the origin its H-point; looking down at the phone she holds at her chest, her
  left hand in her lap. Chest (her upper body, arms, the lanyard and the phone; its origin at her waist) is the parent
  of Head, so her head and shoulders turn towards the back seat together.
- mei_standing: the origin the floor between her feet; the phone in her right hand at her waist, its screen up. LegL
  and LegR (origins at the hips) swing for walking inside the skirt.
Both have Head, its origin the top of the neck. The phone's screen is its own material ("screen"). Run by
tools/models.sh mei.
"""
import math
import os
import random
import sys

from mathutils import Matrix, Vector

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "person")]
import common  # noqa: E402
import person as P  # noqa: E402
from common import lerp, maths  # noqa: E402

SKIN = (0.45, 0.27, 0.17)  # light, warm
HAIR = (0.016, 0.01, 0.0075)
TIPS = (0.03, 0.017, 0.011)  # browner where the sun has had it
CARDIGAN = (0.27, 0.18, 0.085)  # camel, washed
DRESS = (0.022, 0.028, 0.055)  # navy
LANYARD = (0.4, 0.085, 0.035)  # the park's red-orange, no print
CARD = (0.52, 0.51, 0.47)
SHOES = (0.5, 0.49, 0.46)
CASE = (0.36, 0.24, 0.23)  # a dusty pink phone case

FACE = dict(width=0.073, front=0.094, back=0.098, height=0.101, jaw=0.2, chin_fwd=0.008, eye_x=0.031, eye_z=0.004,
            brow=0.0035, socket=0.0055, lid=0.0, cheekbone=0.004, cheek=0.0045, tip_z=-0.028, root=0.003, tip=0.0145,
            bridge_w=0.0105, tip_w=0.014, alar=0.0045, alar_x=0.0145, mouth_w=0.022, muzzle=0.004, lip_u=0.0052,
            lip_l=0.0064, chin_b=0.0035, eye_r=0.0115, eye_set=0.0028, ear_y=0.008, lash_h=0.0036, brow_z=0.0165,
            brow_t=0.0046, brow_k=0.85, lip_colour=(0.4, 0.17, 0.13))
UPPER, FOREARM = 0.28, 0.24
# The dress about the body's axis from the hip joints: (h, half width, front depth, back depth, centre y, squareness).
DRESS_ROWS = [(-0.1, 0.155, 0.075, 0.105, 0.02, 2.3), (-0.04, 0.168, 0.088, 0.108, 0.015, 2.4), (0.04, 0.158, 0.085, 0.098, 0.01, 2.3),
              (0.14, 0.13, 0.072, 0.082, 0.005, 2.2), (0.24, 0.135, 0.085, 0.082, 0.0, 2.2), (0.31, 0.142, 0.1, 0.082, 0.0, 2.2),
              (0.38, 0.145, 0.088, 0.08, 0.0, 2.3), (0.45, 0.155, 0.07, 0.075, 0.004, 2.3), (0.49, 0.142, 0.062, 0.068, 0.008, 2.2),
              (0.515, 0.1, 0.055, 0.058, 0.012, 2.2), (0.535, 0.058, 0.048, 0.05, 0.015, 2.0)]
# The skirt standing, flared so the legs can swing inside it: from the hips to the hem just above the knees.
SKIRT_ROWS = [(-0.37, 0.235, 0.19, 0.2, 0.01, 2.0), (-0.3, 0.215, 0.165, 0.18, 0.01, 2.1), (-0.2, 0.19, 0.13, 0.148, 0.015, 2.2),
              (-0.1, 0.166, 0.095, 0.114, 0.02, 2.3), (-0.04, 0.172, 0.096, 0.11, 0.015, 2.4), (0.04, 0.158, 0.085, 0.098, 0.01, 2.3),
              (0.14, 0.13, 0.072, 0.082, 0.005, 2.2)]


def hairline(nt, hp, x, z):
    """The head's height above her hairline: high at the forehead, down to the ears at the sides, the nape at the back."""
    a = maths(nt, "ABSOLUTE", maths(nt, "ARCTAN2", hp["X"], maths(nt, "MULTIPLY", hp["Y"], -1.0)))
    hz = maths(nt, "ADD", -0.004, maths(nt, "MULTIPLY", maths(nt, "COSINE", a), 0.066))
    hz = maths(nt, "ADD", hz, maths(nt, "MULTIPLY", maths(nt, "COSINE", maths(nt, "MULTIPLY", a, 2.0)), 0.004))
    return maths(nt, "SUBTRACT", z, hz)


FACE["hairline"] = hairline


def blush(nt, colour, hp, x, z):
    """Her cheeks a little pink from a day in the sun, and darker under the eyes from the long day."""
    def blob(cx, cz, wx, wz):
        dx = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", x, cx), wx)
        dz = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", z, cz), wz)
        return maths(nt, "EXPONENT", maths(nt, "MULTIPLY", maths(nt, "ADD", maths(nt, "MULTIPLY", dx, dx), maths(nt, "MULTIPLY", dz, dz)), -1.0))
    colour = lerp(nt, colour, (SKIN[0] * 1.12, SKIN[1] * 0.74, SKIN[2] * 0.72), maths(nt, "MULTIPLY", blob(0.042, FACE["eye_z"] - 0.026, 0.017, 0.014), 0.4))
    return lerp(nt, colour, (SKIN[0] * 0.72, SKIN[1] * 0.62, SKIN[2] * 0.66), maths(nt, "MULTIPLY", blob(FACE["eye_x"], FACE["eye_z"] - 0.009, 0.012, 0.004), 0.3))


def direction(theta: float, a: float) -> Vector:
    """theta down from the crown, a round from the face (towards her left, +X)."""
    return Vector((math.sin(theta) * math.sin(a), -math.sin(theta) * math.cos(a), math.cos(theta)))


def at_height(z: float, a: float, off: float) -> Vector:
    """The point off metres out of the skull at height z (from the head's centre), round at a."""
    q = P.skull(direction(math.acos(max(-1.0, min(1.0, z / FACE["height"]))), a), FACE)
    return q + q.normalized() * off


def hanging(a: float, z: float, off: float) -> Vector:
    """A point of the bob's outline round at a, height z: off out of the skull, straight down below its widest."""
    q = at_height(max(z, 0.0), a, off)
    return Vector((q.x, q.y, z)) if z < 0 else q


def bob(p: P.Person, mat: int, centre: Vector, top: int, under: int, steps: int, wide: float) -> None:
    """Her bob as clumps: the top layer from the parting (on her left, front to crown) over the head and down to her
    jaw, most of it swept to her right, the ends turned under; an under layer at the sides and back fills the gaps."""
    rng = random.Random(31)
    front, crown = Vector((0.024, -0.072, 0.08)).normalized(), Vector((0.016, 0.03, 0.1)).normalized()
    side_z = 0.035
    for k in range(top):
        u = (k + 0.5) / top
        a = -1.12 - u * (math.tau - 2.24) + rng.uniform(-0.04, 0.04)  # where it hangs: her right cheek, the back, her left
        v, side = (u / 0.6, -1) if u <= 0.6 else ((1 - u) / 0.4, 1)
        root = (front.slerp(crown, v) + Vector((side * 0.035, 0, 0))).normalized()
        over = direction(math.acos(side_z / FACE["height"]), a)
        z_end = -0.085 - 0.016 * (1 + math.cos(a)) / 2 + rng.uniform(-0.006, 0.004)
        off, off0 = 0.022 + rng.uniform(-0.003, 0.003), 0.003 + 0.0012 * (k % 4)
        path, outs = [], []
        for i in range(steps):
            s = i / (steps - 1)
            if s <= 0.5:
                q = P.skull(root.slerp(over, s / 0.5), FACE)
                q += q.normalized() * (off0 + (off - off0) * P.smooth(s / 0.3))
                outs.append(q.normalized())
            else:
                w = (s - 0.5) / 0.5
                q = hanging(a, side_z + (z_end - side_z) * w, off - 0.009 * P.smooth((w - 0.7) / 0.3))
                outs.append(Vector((q.x, q.y, 0)).normalized())
            path.append(q)
        P.clump(p, [centre + q for q in path], outs, (0.013 + rng.uniform(-0.0015, 0.0015)) * wide, 0.0055, mat, "Head", rng.random(), 0.7)
    for k in range(under):
        u = (k + 0.5) / under
        a = -1.2 - u * (math.tau - 2.4)
        z_end = -0.075 - 0.012 * (1 + math.cos(a)) / 2
        path = [hanging(a, 0.045 - (0.045 - z_end) * i / 4, 0.002 + 0.012 * P.smooth(i / 2)) for i in range(5)]
        P.clump(p, [centre + q for q in path], [Vector((q.x, q.y, 0)).normalized() for q in path], 0.018 * wide, 0.004, mat,
                "Head", rng.random(), 0.7)


def head(p: P.Person, s: dict, centre: Vector, pivot: Vector, fine: bool, nod: float, look: Vector) -> None:
    """Her head at centre, nodded forward by nod (radians) about pivot. fine: seated, seen at arm's length."""
    old = set(p.bm.verts)
    rows = P.head_grid(FACE, None, *((36, 28) if fine else (24, 18)))
    P.grid_loft(p, rows, centre, s["face"], "Head")
    P.eyes(p, FACE, centre, s["eye"], "Head", look, *((6, 12) if fine else (4, 8)))
    P.lids(p, FACE, centre, s["face"], "Head", 11 if fine else 7)
    bob(p, s["hair"], centre, *((22, 10, 9, 1.0) if fine else (19, 8, 7, 1.15)))
    P.rotate_verts([v for v in p.bm.verts if v not in old], pivot, Matrix.Rotation(nod, 3, "X"))


def surface(rows: list, frame: P.Frame, h: float, x: float, out: float, back: bool = False) -> Vector:
    """The point of the body (rows) at height h and across x, its front (or back) pushed out metres off it."""
    hw, df, db, cy, sq = P.catmull(rows, h)
    d = (db if back else df) * (1 - min(abs(x) / hw, 0.99) ** sq) ** (1 / sq)
    return frame(x, cy + d + out if back else cy - d - out, h)


def cardigan(p: P.Person, s: dict, frame: P.Frame, part: str | None) -> None:
    """Cropped at the waist and open down the front, wider apart towards the neck; round the back of the neck it is
    the collar. The fronts hang a little off the body."""
    outer, inner = [], []
    for i in range(8):
        h = 0.16 + (0.535 - 0.16) * i / 7
        hw, df, db, cy, sq = P.catmull(DRESS_ROWS, h)
        start = 0.45 + 0.75 * P.smooth((h - 0.3) / 0.22)
        for rows, t in ((outer, 0.013), (inner, 0.005)):
            pts = P.section(hw + t, df + t, db + t, sq, 16, start, math.tau - start)
            row = []
            for j, (x, d) in enumerate(pts):
                edge = P.bump(min(j, 16 - j), 2.0) * 0.004 * (1 - P.smooth((h - 0.42) / 0.08))
                row.append(frame(x, cy - d - edge, h))
            rows.append(row)
    P.open_loft(p, outer, inner, s["cardigan"], part)


def lanyard(p: P.Person, s: dict, frame: P.Frame, part: str | None) -> None:
    """The strap round the back of her neck, over the cardigan's collar, down the front to a plain card at her chest."""
    out = 0.004
    pts = [surface(DRESS_ROWS, frame, 0.335, -0.012, out), surface(DRESS_ROWS, frame, 0.41, -0.03, out),
           surface(DRESS_ROWS, frame, 0.48, -0.052, out + 0.012), frame(-0.072, 0.012, 0.53),
           surface(DRESS_ROWS, frame, 0.535, 0.0, 0.02, back=True), frame(0.072, 0.012, 0.53),
           surface(DRESS_ROWS, frame, 0.48, 0.052, out + 0.012), surface(DRESS_ROWS, frame, 0.41, 0.03, out),
           surface(DRESS_ROWS, frame, 0.335, 0.012, out)]
    axis = frame.rot @ Vector((0, 0, 1))
    path = P.spline(pts, 17)
    mid = frame(0, 0.012, 0.42)
    P.strap(p, path, [(q - mid - (q - mid).project(axis)).normalized() for q in path], 0.014, 0.0018, s["lanyard"], part)
    centre = surface(DRESS_ROWS, frame, 0.29, 0.0, 0.006)
    face = (frame.rot @ Vector((0, -1, 0)))
    up = axis
    across = up.cross(face)
    to = Matrix((across, up, face)).transposed().to_4x4()
    to.translation = centre
    verts = common.added(p.bm, lambda bm: common.chamfered_box(bm, (0, 0, 0), (0.054, 0.086, 0.003), 0.001, s["card"]))
    for v in verts:
        v.co = to @ v.co
        if part:
            v[p.deform][P.PARTS.index(part)] = 1.0


def neck(p: P.Person, s: dict, frame: P.Frame, pivot: Vector, part: str | None) -> None:
    base = frame(0, 0.015, 0.47)
    p.tube(P.spline([base, base.lerp(pivot, 0.5) + Vector((0, 0.004, 0)), pivot + Vector((0, -0.004, 0.03))], 5),
           lambda i: (0.043 - 0.001 * i, 0.046 - 0.001 * i), 10, s["skin"], part, up=Vector((0, -1, 0)), caps=(True, True))


def arm(p: P.Person, s: dict, shoulder: Vector, wrist: Vector, pole: Vector, seed: float, part: str | None) -> None:
    joint = P.elbow(shoulder, wrist, UPPER, FOREARM, pole)
    P.limb_tube(p, shoulder + Vector((-shoulder.x * 0.14, 0, -0.04)), joint, wrist,
                [(0.0, 0.04), (0.15, 0.044), (0.5, 0.039), (0.85, 0.035), (0.95, 0.032), (1.0, 0.031)], s["cardigan"], part,
                up=pole, sides=10, shape=P.folds(0.06, seed))


def phone_in_hand(p: P.Person, s: dict, centre: Vector, eye: Vector, up: Vector, shoulder: Vector, pole: Vector,
                  part: str | None) -> None:
    """The phone at centre, its screen towards eye, its top along up; her right hand round it from its right edge, the
    fingers across its back and round its far edge, the thumb at its near edge."""
    face = (eye - centre).normalized()
    up = (up - up.project(face)).normalized()
    across = up.cross(face)
    left = across if across.x > 0 else -across
    P.phone(p, centre, up, face, s["phone"], s["glass"], part)
    fwd = (left * 0.9 + up * 0.35).normalized()
    wrist = centre - fwd * 0.07 - face * 0.022 - up * 0.02
    arm(p, s, shoulder, wrist, pole, 1.0, part)
    P.hand(p, s["skin"], part, wrist, fwd, face, -1, 0.17, (0.55, 0.9, 0.6), (0.5, 0.2, 0.1), 0.05)


def leg(p: P.Person, s: dict, root: Vector, knee: Vector, ankle: Vector, part: str | None, up: Vector) -> None:
    P.limb_tube(p, root, knee, ankle, [(0.0, 0.06), (0.35, 0.05), (0.5, 0.044), (0.65, 0.047), (0.8, 0.043), (1.0, 0.031)],
                s["skin"], part, up=up, sides=10)


def build(seated: bool) -> None:
    common.reset()
    p = P.Person(2207 if seated else 2208)
    s = {"face": p.slot(P.face_skin("face", FACE, SKIN, HAIR, blush), "skin", 2.6),
         "skin": p.slot(P.body_skin("skin", SKIN), "skin", 1.2),
         "eye": p.slot(P.eye_material("eye", (0.02, 0.011, 0.006)), "eye", 2.5),
         "hair": p.slot(P.hair_material("hair", HAIR, TIPS), "hair", 1.4),
         "cardigan": p.slot(P.fabric("cardigan", CARDIGAN, grain=30.0, worn=0.06), "cloth"),
         "dress": p.slot(P.fabric("dress", DRESS, grain=30.0, worn=0.12), "cloth"),
         "lanyard": p.slot(P.plain("lanyard", LANYARD), "cloth", 1.5),
         "card": p.slot(P.plain("card", CARD), "plastic", 1.5),
         "shoes": p.slot(P.fabric("shoes", SHOES, grain=25.0, worn=-0.05, ao=0.7), "cloth"),
         "phone": p.slot(P.plain("phone", CASE), "plastic"),
         "glass": p.slot(P.plain("glass", (0.01, 0.012, 0.015)), "plastic")}
    if seated:
        frame = P.Frame(Vector((0, 0, 0)), 0.26)
        pivot = frame(0, 0.012, 0.535) + Vector((0, -0.03, 0.058))
        upper = "Chest"
    else:
        frame = P.Frame(Vector((0, 0, 0.82)), 0.0)
        pivot = frame(0, 0.012, 0.535) + Vector((0, -0.012, 0.062))
        upper = None
    centre = pivot + Vector((0, -0.008, 0.055))
    hip_r, hip_l = frame.origin + Vector((-0.08, 0, 0)), frame.origin + Vector((0.08, 0, 0))
    sh_r, sh_l = frame(-0.165, 0.0, 0.47), frame(0.165, 0.0, 0.47)
    if seated:
        # The dress: the hips and skirt stay; the upper body (from inside the hips) is Chest and turns at the waist.
        p.loft(P.torso_rings(frame, DRESS_ROWS[:4], 0.04, 20), s["dress"], None, (True, True))
        p.loft(P.torso_rings(frame, DRESS_ROWS[2:], 0.04, 20, grow=lambda h, x, d: -0.03 * P.smooth((0.15 - h) / 0.08)),
               s["dress"], "Chest", (True, True))
    else:
        rings = P.torso_rings(frame, SKIRT_ROWS + DRESS_ROWS[4:], 0.045, 22)
        axis = frame(0, 0.01, SKIRT_ROWS[0][0])
        hem = [[axis + (q - axis) * k + Vector((0, 0, lift)) for q in rings[0]] for k, lift in ((0.93, 0.03), (0.97, 0.006))]
        p.loft(hem + rings, s["dress"], None, (False, True))
    cardigan(p, s, frame, upper)
    lanyard(p, s, frame, upper)
    neck(p, s, frame, pivot, upper)
    if seated:
        eye = centre + Vector((0, -0.09, 0.0))
        phone_in_hand(p, s, Vector((-0.035, -0.2, 0.38)), eye, Vector((0, -0.75, 0.65)), sh_r, Vector((-0.5, 0.4, -0.8)), upper)
        wrist = frame(0.06, -0.15, 0.07)
        arm(p, s, sh_l, wrist, Vector((0.5, 0.5, -0.6)), 2.0, upper)
        P.hand(p, s["skin"], upper, wrist, Vector((-0.75, -0.55, -0.2)), Vector((0, 0.1, -1)), 1, 0.17, (0.3, 0.4, 0.25), (0.3, 0.2, 0.1))
        # The skirt over her thighs to just above the knees; her legs from under it, her feet on the floor.
        knee_r, knee_l = Vector((-0.065, -0.4, 0.075)), Vector((0.07, -0.4, 0.075))
        rings = []
        for t in (0.0, 0.25, 0.5, 0.72, 0.84):
            c = (hip_r.lerp(knee_r, t) + hip_l.lerp(knee_l, t)) / 2 + Vector((0, 0.03 * (1 - t), 0.0))
            hw, top, bottom = 0.165 - 0.03 * t, 0.085 - 0.02 * t, 0.07 - 0.012 * t
            rings.append([c + Vector((x, 0, d)) for x, d in P.section(hw, top, bottom, 2.4, 20)])
        inner = [c + (q - c) * 0.93 + Vector((0, 0.03, 0)) for q in rings[-1] for c in [sum(rings[-1], Vector()) / 20]]
        p.loft(rings + [inner], s["dress"], None)
        for hip, knee, ankle, side in ((hip_r, knee_r, Vector((-0.08, -0.6, -0.3)), -1), (hip_l, knee_l, Vector((0.085, -0.58, -0.3)), 1)):
            leg(p, s, hip.lerp(knee, 0.5), knee, ankle, None, Vector((0, 0, 1)))
            heel = ankle + Vector((0, 0.04, -0.06))
            P.shoe(p, s["shoes"], None, heel, heel + Vector((side * 0.015, -0.23, 0.0)), Vector((0, 0, 1)), side, 0.042, 0.065)
        head(p, s, centre, pivot, True, 0.12, Vector((0, -1, -0.1)))
        P.finish(p, "Mei", "mei_seated", {"Head": pivot, "Chest": frame(0, 0, 0.16)}, parents={"Head": "Chest"}, screen=s["glass"])
        return
    eye = centre + Vector((0, -0.09, 0.0))
    phone_in_hand(p, s, Vector((-0.07, -0.24, 1.02)), eye, Vector((0, -1, 0.25)), sh_r, Vector((-0.5, 0.5, -0.8)), None)
    wrist = Vector((0.19, 0.02, 0.79))
    arm(p, s, sh_l, wrist, Vector((0.3, 1, 0)), 2.0, None)
    P.hand(p, s["skin"], None, wrist, Vector((0.02, -0.05, -1)), Vector((-1, 0, 0)), 1, 0.17, (0.25, 0.3, 0.2), (0.3, 0.2, 0.1))
    for side, hip, part in ((1, hip_l, "LegL"), (-1, hip_r, "LegR")):
        leg(p, s, hip, Vector((side * 0.08, -0.012, 0.45)), Vector((side * 0.085, 0.02, 0.08)), part, Vector((0, -1, 0)))
        P.shoe(p, s["shoes"], part, Vector((side * 0.09, 0.07, 0.0)), Vector((side * 0.1, -0.16, 0.0)), Vector((0, 0, 1)), side, 0.042, 0.065)
    head(p, s, centre, pivot, False, 0.05, Vector((0, -1, -0.15)))
    P.finish(p, "Mei", "mei_standing", {"Head": pivot, "LegL": hip_l, "LegR": hip_r}, size=128, screen=s["glass"])


build(True)
build(False)

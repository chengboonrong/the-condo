"""Hafiz: Malay, early twenties, who drives the player down. A plain heather-grey hoodie, its hood down and bunched at
the back of his neck, its drawstrings hanging; a dark cap worn backwards over short hair, a tuft of it showing through
the strap's opening; faded dark jeans and worn white sneakers. A thin moustache and a little stubble.

Two models (art/shared/person builds them):
- hafiz_seated: at the wheel, the origin the driver seat's H-point. His right hand holds the rim at about two o'clock
  (the wheel's centre is 0.42 m ahead of the H-point and 0.38 m up, 0.37 m across outside, its rim's centre line 0.168 m
  out, its face tilted 25 degrees back), his left hand rests on his thigh, his right foot on the accelerator.
- hafiz_standing: the origin the floor between his feet; he holds his phone up in his right hand as a torch. LegL and
  LegR (origins at the hips) swing for walking.
Both have Head, its origin the top of the neck. Run by tools/models.sh hafiz.
"""
import math
import os
import sys

from mathutils import Vector
from mathutils import noise as perlin

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "person")]
import common  # noqa: E402
import person as P  # noqa: E402
from common import lerp, mapped, maths  # noqa: E402

SKIN = (0.22, 0.1, 0.052)  # warm medium brown
HAIR = (0.012, 0.009, 0.007)
HOODIE = (0.11, 0.11, 0.115)  # heather grey, washed many times
JEANS = (0.034, 0.05, 0.092)
CAP = (0.014, 0.017, 0.028)  # navy gone dark
SHOES = (0.48, 0.46, 0.41)

FACE = dict(width=0.077, front=0.1, back=0.104, height=0.11, jaw=0.26, chin_fwd=0.012, eye_x=0.032, eye_z=0.004,
            brow=0.0055, socket=0.0085, lid=0.0012, cheekbone=0.0045, cheek=0.004, tip_z=-0.031, root=0.004, tip=0.017,
            bridge_w=0.0095, tip_w=0.0155, alar=0.0065, alar_x=0.016, mouth_w=0.0255, muzzle=0.004, lip_u=0.0052,
            lip_l=0.0062, chin_b=0.0042, eye_r=0.0118, eye_set=0.0032, ear_y=0.008, lash_h=0.0045, brow_z=0.0185,
            brow_t=0.005, brow_k=0.92, lip_colour=(0.2, 0.075, 0.055))
OPEN = 0.42  # half the strap opening at his forehead, radians round the head
UPPER, FOREARM, THIGH, SHIN = 0.31, 0.27, 0.43, 0.41
# The torso about its axis from the hip joints: (h, half width, front depth, back depth, centre y, squareness).
JEANS_ROWS = [(-0.1, 0.13, 0.07, 0.1, 0.02, 2.3), (-0.04, 0.165, 0.09, 0.11, 0.015, 2.4), (0.03, 0.17, 0.095, 0.105, 0.01, 2.4),
              (0.1, 0.16, 0.095, 0.095, 0.005, 2.3)]
HOODIE_ROWS = [(0.02, 0.183, 0.113, 0.118, 0.012, 2.4), (0.07, 0.18, 0.112, 0.115, 0.01, 2.4), (0.18, 0.172, 0.11, 0.108, 0.005, 2.3),
               (0.3, 0.178, 0.118, 0.106, 0.0, 2.3), (0.4, 0.188, 0.118, 0.104, 0.0, 2.4), (0.47, 0.196, 0.105, 0.1, 0.004, 2.6),
               (0.52, 0.18, 0.088, 0.085, 0.01, 2.8), (0.555, 0.125, 0.072, 0.072, 0.015, 2.2), (0.585, 0.072, 0.062, 0.064, 0.018, 2.0)]


def cap_edge(a: float) -> float:
    """The cap's lower edge round his head, metres above the eyes' height: its band, low at the back where the brim is,
    and the arch of the strap's opening over his forehead."""
    z = 0.024 + 0.0155 * (1 + math.cos(a))
    if abs(a) < OPEN:
        z += 0.02 * math.cos(a / OPEN * math.pi / 2) ** 2
    return z


def hairline_z(a: float) -> float:
    """How high his hair starts, round the head (a = 0 the face): the forehead, over the ears, sideburns, the nape."""
    a = abs(math.remainder(a, math.tau))
    return -0.003 + 0.059 * math.cos(a) + 0.002 * math.cos(2 * a) + 0.035 * P.bump(a - 1.68, 0.25) - 0.022 * P.bump(a - 1.3, 0.08)


def hairline(nt, hp, x, z):
    """The head's height above hairline_z, as shader nodes."""
    a = maths(nt, "ABSOLUTE", maths(nt, "ARCTAN2", hp["X"], maths(nt, "MULTIPLY", hp["Y"], -1.0)))

    def b(c, w):
        d = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", a, c), w)
        return maths(nt, "EXPONENT", maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", d, d), -1.0))
    hz = maths(nt, "ADD", -0.003, maths(nt, "MULTIPLY", maths(nt, "COSINE", a), 0.059))
    hz = maths(nt, "ADD", hz, maths(nt, "MULTIPLY", maths(nt, "COSINE", maths(nt, "MULTIPLY", a, 2.0)), 0.002))
    hz = maths(nt, "ADD", hz, maths(nt, "SUBTRACT", maths(nt, "MULTIPLY", b(1.68, 0.25), 0.035), maths(nt, "MULTIPLY", b(1.3, 0.08), 0.022)))
    return maths(nt, "SUBTRACT", z, hz)


FACE["hairline"] = hairline


def stubble(nt, colour, hp, x, z):
    """A thin moustache, a little hair on the chin, and his jaw darker where he shaves."""
    zb = FACE["tip_z"] - 0.011
    ul, ll = zb - 0.011, zb - 0.0245
    jaw = maths(nt, "MULTIPLY", mapped(nt, z, ul + 0.004, ul - 0.012, 0.0, 1.0), mapped(nt, x, 0.05, 0.068, 1.0, 0.0))
    colour = lerp(nt, colour, (SKIN[0] * 0.62, SKIN[1] * 0.6, SKIN[2] * 0.66), maths(nt, "MULTIPLY", jaw, 0.45))
    tache = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", mapped(nt, z, ul + 0.0025, ul + 0.004, 0.0, 1.0), mapped(nt, z, ul + 0.008, ul + 0.0105, 1.0, 0.0)),
                  mapped(nt, x, 0.019, 0.026, 1.0, 0.0))
    chin = maths(nt, "MULTIPLY", mapped(nt, z, ll - 0.009, ll - 0.012, 0.0, 1.0), mapped(nt, x, 0.012, 0.02, 1.0, 0.0))
    vec = common.node(nt, "ShaderNodeAttribute", attribute_name="hp").outputs["Vector"]
    hairs = mapped(nt, common.noise(nt, vec, 300.0, 1.0), 0.35, 0.65, 0.35, 1.0)
    amount = maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", maths(nt, "MULTIPLY", tache, 0.85), maths(nt, "MULTIPLY", chin, 0.55)), hairs)
    return lerp(nt, colour, tuple(c * 0.55 for c in HAIR), amount)


def cap_seams(nt, colour, coords):
    """Six panels from the button, their seams darker, the button on top."""
    hp = P.attr(nt, "hp")
    a = maths(nt, "ARCTAN2", hp["X"], maths(nt, "MULTIPLY", hp["Y"], -1.0))
    seam = maths(nt, "MULTIPLY", mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SINE", maths(nt, "MULTIPLY", a, 3.0))), 0.0, 0.07, 1.0, 0.0),
                 mapped(nt, hp["Z"], 0.03, 0.05, 0.0, 1.0))
    colour = lerp(nt, colour, tuple(c * 0.45 for c in CAP), maths(nt, "MULTIPLY", seam, 0.8))
    return lerp(nt, colour, tuple(c * 0.6 for c in CAP), mapped(nt, hp["Z"], 0.122, 0.126, 0.0, 1.0))


def direction(theta: float, a: float) -> Vector:
    """theta down from the crown, a round from the face."""
    return Vector((math.sin(theta) * math.sin(a), -math.sin(theta) * math.cos(a), math.cos(theta)))


def at_height(z: float, a: float, off: float) -> Vector:
    """The point off metres out of the skull at height z (from its centre) round at a."""
    q = P.skull(direction(math.acos(max(-1.0, min(1.0, z / FACE["height"]))), a), FACE)
    return q + q.normalized() * off


def hair_offset(d: Vector, q: Vector) -> Vector:
    """His hair: short at the back and sides, thinning to nothing at the hairline, a tuft through the cap's opening;
    under the cap and below the hairline it tucks into the head."""
    a = math.atan2(d.x, -d.y)
    above = q.z - hairline_z(a)
    if above < 0 or q.z > cap_edge(a) + 0.004:
        return q * 0.95
    thick = 0.0022 + 0.0042 * P.smooth(above / 0.025)
    if abs(a) < OPEN:
        thick += 0.005 * P.smooth((q.z - 0.055) / 0.012)
    # Combed down and back in clumps: ridges along the hair, a little irregular.
    ridge = abs(math.sin(a * 16 + 3 * perlin.noise(Vector((a * 2.0, q.z * 30.0, 7.0))))) - 0.5
    return q + d * (thick + 0.0016 * ridge + 0.0008 * perlin.noise(Vector((a * 7.0, q.z * 60.0, 2.0))))


def head(p: P.Person, s: dict, centre: Vector, fine: bool) -> None:
    """fine: the seated head, seen at arm's length; else the standing one, seen at metres."""
    rows = P.head_grid(FACE, None, *((36, 28) if fine else (24, 18)))
    P.grid_loft(p, rows, centre, s["face"], "Head")
    P.eyes(p, FACE, centre, s["eye"], "Head", Vector((0, -1, 0)), *((6, 12) if fine else (4, 8)))
    P.lids(p, FACE, centre, s["face"], "Head", 11 if fine else 7)
    for side in (1, -1):
        P.ear(p, FACE, centre, side, s["face"], "Head", *((4, 12) if fine else (3, 8)))
    shell = P.head_grid(FACE, hair_offset, *((26, 12) if fine else (18, 8)), (0.22, 0.86))
    p.loft([[centre + q for _, q in r] for r in shell], s["hair"], "Head")
    # The cap: its crown from the lower edge (an inner lip, then the outside) up to the button.
    ring = []
    segs = 24 if fine else 16
    for share, off in ((0.0, 0.0045), (0.0, 0.0095), (0.12, 0.0105), (0.3, 0.013), (0.5, 0.016), (0.7, 0.018), (0.86, 0.019)):
        row = []
        for i in range(segs):
            a = -math.pi + math.tau * i / segs
            theta = math.acos(cap_edge(a) / FACE["height"]) * (1 - share)
            q = P.skull(direction(theta, a), FACE)
            row.append(q + q.normalized() * off)
        ring.append(row)
    p.loft([[centre + q for q in r] for r in ring], s["cap"], "Head", (False, True), hp=lambda i, j: ring[i][j])
    # The strap across the opening, and the brim at the back, its sides curved down.
    pts = [at_height(0.057, a, 0.0085) for a in (OPEN * (2 * k / 8 - 1) * 1.1 for k in range(9))]
    P.strap(p, [centre + q for q in pts], [q.normalized() for q in pts], 0.012, 0.0022, s["cap"], "Head")
    brim = []
    cols = 13 if fine else 9
    for i in range(cols):
        u = -0.95 + 1.9 * i / (cols - 1)
        a = math.pi + 0.85 * u
        root = at_height(cap_edge(a) + 0.003, a, 0.008)
        tilt = 0.3
        out = Vector((math.sin(a) * math.cos(tilt), -math.cos(a) * math.cos(tilt), -math.sin(tilt)))
        nrm = Vector((math.sin(a) * math.sin(tilt), -math.cos(a) * math.sin(tilt), math.cos(tilt)))
        length = 0.072 * math.sqrt(max(0.0, 1 - u * u)) + 0.008
        line = [root + out * (length * w) - nrm * (0.016 * u * u * w) for w in (0.0, 0.3, 0.6, 0.85, 1.0)]
        brim.append([q + nrm * 0.0028 for q in line] + [q - nrm * 0.0028 for q in reversed(line)])
    p.loft([[centre + q for q in r] for r in brim], s["cap"], "Head", (True, True), hp=lambda i, j: brim[i][j])


def front(frame: P.Frame, h: float, x: float, out: float) -> Vector:
    """The hoodie's front at height h and across x, out metres off it."""
    hw, df, db, cy, sq = P.catmull(HOODIE_ROWS, h)
    d = df * (1 - min(abs(x) / hw, 0.99) ** sq) ** (1 / sq)
    return frame(x, cy - d - out, h)


def body(p: P.Person, s: dict, frame: P.Frame) -> None:
    """The jeans round his hips, the hoodie, its hood bunched behind his neck, its drawstrings."""
    p.loft(P.torso_rings(frame, JEANS_ROWS, 0.03, 20), s["jeans"], None, (True, True))

    def creases(h, x, d):
        a = math.atan2(x, d)
        return 0.0035 * perlin.noise(Vector((a * 3.0, h * 11.0, 1.0))) + 0.004 * P.bump(h - 0.08, 0.05) * perlin.noise(Vector((a * 6.0, 4.0, 2.0)))
    p.loft(P.torso_rings(frame, HOODIE_ROWS, 0.04, 24, grow=creases), s["hoodie"], None, (False, True))
    hw, df, db, cy, sq = P.catmull(HOODIE_ROWS, 0.548)
    path = []
    for k in range(17):
        phi = 1.35 + (math.tau - 2.7) * k / 16
        x, d = P.section(hw, df, db, sq, 1, phi, phi + 1e-3)[0]
        path.append(frame(x * 1.12, cy - d * 1.12, 0.548))
    axis = frame.rot @ Vector((0, 0, 1))
    hang = [P.bump((1.35 + (math.tau - 2.7) * k / 16) - math.pi, 0.75) for k in range(17)]
    ends = [P.smooth(min(k, 16 - k) / 3.0) * 0.6 + 0.4 for k in range(17)]
    p.tube(path, lambda i: ((0.02 + 0.014 * hang[i]) * ends[i], (0.022 + 0.045 * hang[i]) * ends[i]), 8, s["hoodie"], None, up=axis,
           caps=(True, True), shape=lambda i, k, xy: (xy[0] * (1 + 0.15 * perlin.noise(Vector((i * 0.6, k * 0.9, 5.0)))) + 0.012 * hang[i],
                                                       xy[1] - 0.035 * hang[i]))
    for side in (1, -1):
        cord = [front(frame, h, side * (0.03 + 0.012 * (0.57 - h)), 0.006) for h in (0.565, 0.53, 0.49, 0.45, 0.41, 0.375)]
        p.tube(P.spline(cord, 9), 0.0034, 4, s["cord"], None, up=axis, caps=(True, True))


def neck(p: P.Person, s: dict, frame: P.Frame, pivot: Vector) -> None:
    base = frame(0, 0.015, 0.5)
    p.tube(P.spline([base, base.lerp(pivot, 0.5) + Vector((0, 0.004, 0)), pivot + Vector((0, -0.004, 0.035))], 5),
           lambda i: (0.054 - 0.001 * i, 0.058 - 0.001 * i), 12, s["skin"], None, up=Vector((0, -1, 0)), caps=(True, True))


def arm(p: P.Person, s: dict, shoulder: Vector, wrist: Vector, pole: Vector, seed: float) -> None:
    joint = P.elbow(shoulder, wrist, UPPER, FOREARM, pole)
    P.limb_tube(p, shoulder + Vector((-shoulder.x * 0.14, 0, -0.045)), joint, wrist,
                [(0.0, 0.048), (0.15, 0.052), (0.5, 0.047), (0.85, 0.042), (0.95, 0.036), (1.0, 0.035)], s["hoodie"], None,
                up=pole, sides=10, shape=P.folds(0.07, seed))


def leg(p: P.Person, s: dict, hip: Vector, knee: Vector, ankle: Vector, part: str | None, up: Vector, seed: float) -> None:
    root = hip + (Vector((0, 0.025, 0.0)) if part is None else Vector((0, 0, 0.06)))
    P.limb_tube(p, root, knee, ankle, [(0.0, (0.088, 0.085)), (0.2, 0.08), (0.45, 0.058), (0.5, 0.055), (0.75, 0.052), (0.95, 0.049), (1.0, 0.048)],
                s["jeans"], part, up=up, sides=10, shape=P.folds(0.05, seed))


def build(seated: bool) -> None:
    common.reset()
    p = P.Person(1907 if seated else 1908)
    s = {"face": p.slot(P.face_skin("face", FACE, SKIN, HAIR, stubble), "skin", 2.6),
         "skin": p.slot(P.body_skin("skin", SKIN), "skin", 1.2),
         "eye": p.slot(P.eye_material("eye", (0.022, 0.01, 0.005)), "eye", 2.5),
         "hair": p.slot(P.fabric("hair", HAIR, grain=40.0, worn=0.0, ao=0.7), "hair", 1.6),
         "cap": p.slot(P.fabric("cap", CAP, grain=30.0, worn=0.15, paint=cap_seams), "cloth", 1.3),
         "hoodie": p.slot(P.fabric("hoodie", HOODIE, grain=25.0, worn=0.05), "cloth"),
         "cord": p.slot(P.plain("cord", (0.36, 0.36, 0.34)), "cloth"),
         "jeans": p.slot(P.fabric("jeans", JEANS, grain=30.0, worn=0.22), "cloth"),
         "shoes": p.slot(P.fabric("shoes", SHOES, grain=25.0, worn=-0.06, ao=0.7), "cloth"),
         "phone": p.slot(P.plain("phone", (0.02, 0.02, 0.022)), "plastic"),
         "glass": p.slot(P.plain("glass", (0.006, 0.007, 0.009)), "plastic")}
    if seated:
        frame = P.Frame(Vector((0, 0, 0)), 0.21)
        pivot = frame(0, 0.012, 0.56) + Vector((0, -0.04, 0.08))
    else:
        frame = P.Frame(Vector((0, 0, 0.89)), 0.0)
        pivot = frame(0, 0.012, 0.56) + Vector((0, -0.017, 0.09))
    centre = pivot + Vector((0, -0.008, 0.058))
    body(p, s, frame)
    neck(p, s, frame, pivot)
    head(p, s, centre, seated)
    sh_r, sh_l = frame(-0.185, 0.0, 0.525), frame(0.185, 0.0, 0.525)
    hip_r, hip_l = frame.origin + Vector((-0.085, 0, 0)), frame.origin + Vector((0.085, 0, 0))
    if seated:
        # The wheel (lane geometry): its centre, its face tilted 25 degrees back, the grip at two o'clock.
        wheel = Vector((0, -0.42, 0.38))
        w_up, w_right = Vector((0, -math.sin(math.radians(25)), math.cos(math.radians(25)))), Vector((-1, 0, 0))
        clock = math.radians(60)
        grip = wheel + (w_right * math.sin(clock) + w_up * math.cos(clock)) * 0.168  # the rim's centre line
        tangent = (w_right * math.cos(clock) - w_up * math.sin(clock)).normalized()
        fwd = (grip - sh_r).normalized()
        fwd = (fwd - fwd.project(tangent)).normalized()
        palm = fwd.cross(tangent).normalized()
        wrist = grip - fwd * 0.07 - palm * 0.027
        arm(p, s, sh_r, wrist, Vector((-0.6, 0.3, -0.75)), 1.0)
        P.hand(p, s["skin"], None, wrist, fwd, palm, -1, 0.185, (1.0, 1.25, 0.9), (0.6, 0.5, 0.3))
        knee_l = Vector((0.13, -0.42, 0.05))
        thigh = (knee_l - hip_l).normalized()
        wrist = hip_l.lerp(knee_l, 0.7) + Vector((0, 0, 0.09)) - thigh * 0.06
        arm(p, s, sh_l, wrist, Vector((0.6, 0.6, -0.2)), 2.0)
        P.hand(p, s["skin"], None, wrist, thigh, Vector((0, 0, -1)), 1, 0.185, (0.25, 0.35, 0.2), (0.3, 0.2, 0.1))
        knee_r, ankle_r, ankle_l = Vector((-0.12, -0.43, 0.045)), Vector((-0.13, -0.745, -0.215)), Vector((0.15, -0.66, -0.27))
        leg(p, s, hip_r, knee_r, ankle_r, None, Vector((0, 0, 1)), 3.0)
        leg(p, s, hip_l, knee_l, ankle_l, None, Vector((0, 0, 1)), 4.0)
        pedal = math.radians(25)
        heel = ankle_r + Vector((0, 0.045, -0.065))
        P.shoe(p, s["shoes"], None, heel, heel + Vector((0, -math.cos(pedal), math.sin(pedal))) * 0.275,
               Vector((0, math.sin(pedal), math.cos(pedal))), -1, 0.05, 0.075)
        heel = ankle_l + Vector((0, 0.045, -0.065))
        P.shoe(p, s["shoes"], None, heel, heel + Vector((0.02, -0.27, 0.025)), Vector((0, 0.09, 1)), 1, 0.05, 0.075)
        P.finish(p, "Hafiz", "hafiz_seated", {"Head": pivot})
        return
    wrist = Vector((-0.13, -0.26, 1.0))
    fwd = Vector((0.15, -0.95, 0.27)).normalized()
    palm = Vector((1, 0.15, 0))
    arm(p, s, sh_r, wrist, Vector((-0.5, 0.5, -0.7)), 1.0)
    P.hand(p, s["skin"], None, wrist, fwd, palm, -1, 0.185, (1.1, 1.1, 0.8), (0.5, 0.4, 0.2))
    P.phone(p, wrist + fwd * 0.055 + Vector((0.03, 0, 0.045)), Vector((0, -0.1, 1)), Vector((0, 1, 0.1)), s["phone"], s["glass"], None)
    wrist = Vector((0.215, 0.025, 0.86))
    arm(p, s, sh_l, wrist, Vector((0.3, 1, 0)), 2.0)
    P.hand(p, s["skin"], None, wrist, Vector((0.02, -0.05, -1)), Vector((-1, 0, 0)), 1, 0.185, (0.25, 0.3, 0.2), (0.3, 0.2, 0.1))
    for side, hip, part in ((1, hip_l, "LegL"), (-1, hip_r, "LegR")):
        leg(p, s, hip, Vector((side * 0.09, -0.012, 0.49)), Vector((side * 0.095, 0.02, 0.085)), part, Vector((0, -1, 0)), 3.0 + side)
        P.shoe(p, s["shoes"], part, Vector((side * 0.1, 0.075, 0.0)), Vector((side * 0.115, -0.205, 0.0)), Vector((0, 0, 1)), side, 0.05, 0.075)
    P.finish(p, "Hafiz", "hafiz_standing", {"Head": pivot, "LegL": hip_l, "LegR": hip_r}, size=128)


build(True)
build(False)

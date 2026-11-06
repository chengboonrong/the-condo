"""The couple's hatchback: an ordinary small 5-door car, about ten years old and kept clean, with nothing on it that names a make.
Right-hand drive, silver, grey cloth seats. Run by tools/models.sh.

The player rides in its rear-left seat for about eight minutes, so the inside is where the work is: the headliner, door cards,
dashboard with its gauges, the backs of the front seats, the mirror, the windows. The outside only has to be a believable small
car in fog and headlights.

Origin: the ground at the centre of the wheelbase; the front faces Blender -Y (the game's +Z); the car's left is +X. Metres.
Objects: "hatchback" (the body and the inside), door_rear_left and door_driver (the front right door; origins on their hinge lines,
at their front edges), wheel_fl, wheel_fr, wheel_rl, wheel_rr (origin at the hub), and empties seat_driver, seat_front, seat_rear_left, seat_rear_right (the H-points),
mirror_mount, headlight_l, headlight_r, taillight_l, taillight_r and dash_glow. Materials the game drives: "gauges" (glows),
"headlight_lens", "taillight_lens". Nothing is baked: plain materials, two tiny tiling textures, the gauges' dial image, and
ambient occlusion in the "ao" vertex colours.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "car")]
import car  # noqa: E402
import common  # noqa: E402
from car import Part, aim, at  # noqa: E402

# --- the car's numbers ----------------------------------------------------------------------------------
AXLE = 1.225  # the wheels are this far in front of and behind the origin
TRACK = 0.72  # the hubs' distance from the centre line
TYRE = 0.298  # tyre radius; the hub is this high
ARCH = 0.335  # the wheel arch's radius, about the hub
DOOR = (0.11, 0.89)  # the rear doors' front and rear edges (y)
FRONT_DOOR = (-0.72, 0.10)  # the front doors'
DOOR_BOTTOM = 0.46  # z of the rear door's lower edge on its outside
COWL, TAIL = -0.86, 1.72  # where the front shell ends (the windscreen's foot) and the rear shell begins
BELT = [(-0.86, 0.965), (-0.70, 0.99), (-0.40, 1.0), (0.9, 1.0), (1.2, 1.015), (1.72, 1.03)]  # y, z of the door tops
FLOOR = 0.285  # the carpet
MIRROR_Y = -0.2985  # the rear-view mirror's glass plane, where the mirror_mount empty is (the glass is recessed 2 mm behind it)

# H-points of the four seats (lane-common): the hip joint of a person sitting, 0.13 m in front of the seatback.
SEATS = {"seat_driver": (-0.37, -0.05, 0.56), "seat_front": (0.37, -0.05, 0.56),
         "seat_rear_left": (0.37, 0.78, 0.58), "seat_rear_right": (-0.37, 0.78, 0.58)}

# The windscreen and the greenhouse, for the car's left (+X; mirrored for the right): (x, y, z)
A_FOOT, A_TOP = (0.80, -0.84, 0.975), (0.625, -0.24, 1.435)
B_FOOT, B_TOP = (0.84, 0.105, 1.0), (0.64, 0.085, 1.45)
C_TOP = (0.60, 0.78, 1.445)  # the rear door window's rear edge at the roof
HATCH_TOP, HATCH_BOTTOM = (0.55, 1.30, 1.425), (0.66, 1.70, 1.045)
_slope = Vector((0, A_TOP[1] - A_FOOT[1], A_TOP[2] - A_FOOT[2])).normalized()
WIND_OUT = Vector((0, -_slope.z, _slope.y))  # the windscreen's outward normal: forward and up


def arch_height(y: float, zb: float) -> float:
    return car.arch_height(y, zb, AXLE, ARCH, TYRE)


def arch_stations(yc: float) -> list:
    return car.arch_stations(yc, ARCH)


interp, mirrored, nose_half = car.interp, car.mirrored, car.nose_half


# --- materials ------------------------------------------------------------------------------------------
common.reset()
weave, grain = car.weave_image(), car.grain_image()
M = {
    "paint": car.material("paint", (0.36, 0.38, 0.39), rough=0.38, metal=0.15),
    "liner": car.material("liner", (0.012, 0.012, 0.013), rough=0.95),
    "seal": car.material("seal", (0.008, 0.008, 0.009), rough=0.9),
    "glass": car.material("glass", (0.06, 0.075, 0.075), rough=0.12, alpha=0.2),
    "trim_dark": car.material("trim_dark", (0.03, 0.03, 0.032), rough=0.7, texture=grain),
    "trim_grey": car.material("trim_grey", (0.11, 0.11, 0.115), rough=0.75, texture=grain),
    "headliner": car.material("headliner", (0.22, 0.205, 0.18), rough=0.95, texture=weave),
    "carpet": car.material("carpet", (0.035, 0.035, 0.04), rough=1.0, texture=weave),
    "cloth": car.material("cloth", (0.10, 0.105, 0.12), rough=0.95, texture=weave),
    "cloth_light": car.material("cloth_light", (0.17, 0.17, 0.17), rough=0.95, texture=weave),
    "seat_back": car.material("seat_back", (0.025, 0.025, 0.028), rough=0.6, texture=grain),
    "rubber": car.material("rubber", (0.012, 0.012, 0.013), rough=0.92),
    "steel": car.material("steel", (0.2, 0.2, 0.21), rough=0.5, metal=0.5),
}


# --- the shells -----------------------------------------------------------------------------------------

def tub_half(y: float) -> list:
    zb = 0.22
    ha = arch_height(y, zb)
    zbelt = interp(BELT, y)[0]
    xin, xlip, xw = 0.56, 0.80, 0.85
    z4 = max(zb + 0.07, ha + 0.012)
    return [(0, zb), (xin, zb), (xin, ha), (xlip, ha), (xw, z4), (xw + 0.005, max(DOOR_BOTTOM, z4 + 0.02)), (0.857, 0.72), (0.845, zbelt),
            (0.80, zbelt + 0.012), (0.772, zbelt + 0.010), (0.77, zbelt - 0.06), (0.765, 0.74), (0.742, 0.44), (0.70, 0.30),
            (0.45, FLOOR), (0, 0.27)]


FRONT = [(-2.025, 0.46, 0.40, 0.66, 0.70, 0.40), (-2.010, 0.62, 0.36, 0.70, 0.745, 0.57), (-1.980, 0.73, 0.32, 0.74, 0.78, 0.68),
         (-1.930, 0.79, 0.29, 0.76, 0.80, 0.73), (-1.860, 0.825, 0.26, 0.78, 0.815, 0.75), (-1.760, 0.845, 0.24, 0.80, 0.83, 0.765),
         (-1.650, 0.85, 0.23, 0.82, 0.85, 0.77), (COWL, 0.85, 0.22, 0.96, 0.97, 0.835)]
REAR = [(TAIL, 0.85, 0.28, 1.03, 1.05, 0.845), (1.78, 0.84, 0.30, 1.01, 1.03, 0.80), (1.83, 0.82, 0.32, 0.99, 1.01, 0.77),
        (1.86, 0.78, 0.36, 0.95, 0.97, 0.72), (1.875, 0.70, 0.42, 0.88, 0.90, 0.64)]
NOSE_MATS = [M["liner"]] * 3 + [M["paint"]] * 5
TUB_MATS = [M["liner"]] * 3 + [M["paint"]] * 5 + [M["seal"], M["trim_grey"], M["trim_grey"], M["trim_dark"], M["trim_dark"], M["carpet"], M["carpet"]]


def cut_door(body: Part, door: Part, grid: list, ys: list, edges: tuple, sx: int) -> None:
    """Moves the tub's faces between the y values in edges (outside skin, rim and inside card on side sx) to `door`, leaving an
    opening with jamb faces, and gives the door its own edge faces."""
    s0, s1 = ys.index(edges[0]), ys.index(edges[1])
    cut = [grid[s][seg] for s in range(s0, s1) for seg in (range(5, 12) if sx > 0 else range(18, 25))]  # the mirrored half runs backwards
    for f in cut:
        door.poly([v.co.copy() for v in f.verts], body.mats[f.material_index], smooth=True)
    bmesh.ops.delete(body.bm, geom=cut, context="FACES_ONLY")
    ring0, ring1 = tub_half(edges[0]), tub_half(edges[1])
    edge = lambda half, y: [(sx * x, y, z) for x, z in half[5:13]]
    body.poly(edge(ring0, edges[0]), M["trim_dark"], facing=(0, 1, 0))  # the jamb faces of the opening
    body.poly(edge(ring1, edges[1]), M["trim_dark"], facing=(0, -1, 0))
    door.poly(edge(ring0, edges[0]), M["trim_dark"], facing=(0, -1, 0))
    door.poly(edge(ring1, edges[1]), M["trim_dark"], facing=(0, 1, 0))
    sill = [(sx * ring0[5][0], edges[0], ring0[5][1]), (sx * ring1[5][0], edges[1], ring1[5][1]),
            (sx * ring1[12][0], edges[1], ring1[12][1]), (sx * ring0[12][0], edges[0], ring0[12][1])]
    body.poly(sill, M["trim_dark"], facing=(0, 0, 1))
    door.poly(sill, M["trim_dark"], facing=(0, 0, -1))


def shells(body: Part, door_rl: Part, door_dr: Part) -> None:
    """The nose, the open-topped tub that is the cabin's floor and sides, and the tail. The rear left door and the driver's door
    are cut out of the tub and moved to their own parts."""
    ys = [y for y in sorted(set([r[0] for r in FRONT] + arch_stations(-AXLE))) if y <= COWL + 1e-6]
    body.loft([mirrored(nose_half(*interp(FRONT, y), arch_height(y, interp(FRONT, y)[1])), y) for y in ys],
              NOSE_MATS + NOSE_MATS[::-1], toward=(4, (1, 0, 0)))
    body.poly(mirrored(nose_half(*interp(FRONT, COWL), 0.22), COWL), M["liner"], facing=(0, 1, 0))  # the firewall
    body.poly(mirrored(nose_half(*FRONT[0][1:], 0.40), FRONT[0][0]), M["paint"], facing=(0, -1, 0))  # the bumper's face, closing the nose
    ys = sorted(set([COWL, -0.62, -0.38, -0.12] + list(FRONT_DOOR) + list(DOOR) + [0.30, 0.52, 0.76] + arch_stations(AXLE) + [1.60, TAIL]))
    grid = body.loft([mirrored(tub_half(y), y) for y in ys], TUB_MATS + TUB_MATS[::-1], toward=(6, (1, 0, 0)))
    # the tail (no arches here: the arch height is the underbody's)
    body.loft([mirrored(nose_half(*r[1:], r[2]), r[0]) for r in REAR], NOSE_MATS + NOSE_MATS[::-1], toward=(4, (1, 0, 0)))
    body.poly(mirrored(nose_half(*REAR[0][1:], REAR[0][2]), REAR[0][0]), M["trim_dark"], facing=(0, -1, 0))  # the cargo area's end wall
    body.poly(mirrored(nose_half(*REAR[-1][1:], REAR[-1][2]), REAR[-1][0]), M["paint"], facing=(0, 1, 0))
    cut_door(body, door_rl, grid, ys, DOOR, 1)
    cut_door(body, door_dr, grid, ys, FRONT_DOOR, -1)


# --- the greenhouse -------------------------------------------------------------------------------------

def mir(p, sx):
    return (p[0] * sx, p[1], p[2])


def sunk(p, by: float = 0.05):
    """p lowered, so a pillar's end stays inside the roof's thickness instead of standing above it."""
    return (p[0], p[1], p[2] - by)


def windscreen(t: float) -> tuple:
    """(y, z) on the windscreen's centre line, t from its foot (0) to its top edge (1)."""
    return (A_FOOT[1] + (A_TOP[1] - A_FOOT[1]) * t, A_FOOT[2] + (A_TOP[2] - A_FOOT[2]) * t)


ROOF = [(-0.24, 1.43, 1.46), (0.0, 1.45, 1.49), (0.3, 1.455, 1.50), (0.7, 1.45, 1.495), (1.0, 1.44, 1.48), (1.3, 1.415, 1.445)]


def greenhouse(body: Part, door_rl: Part, door_dr: Part) -> None:
    glass = M["glass"]
    # the roof: a slab, paint above and headliner below
    rings = []
    xs = [-0.64 + 1.28 * k / 6 for k in range(7)]
    for y, ze, zc in ROOF:
        top = [(x, y, ze + (zc - ze) * (1 - (x / 0.64) ** 2)) for x in xs]
        bot = [(x * 0.94, y, z - 0.05) for x, _, z in top][::-1]
        rings.append(top + bot)
    mats = [M["paint"]] * 6 + [M["paint"]] + [M["headliner"]] * 6 + [M["paint"]]
    body.loft(rings, mats, toward=(3, (0, 0, 1)))
    body.poly(rings[0], M["paint"], facing=(0, -1, 0))
    body.poly(rings[-1], M["paint"], facing=(0, 1, 0))
    for sx in (1, -1):
        # pillars: A and B as beams, the rail along the roof's edge
        body.beam([mir(A_FOOT, sx), mir(sunk(A_TOP), sx)], 0.075, 0.07, (sx, 0, 0), (M["paint"], M["trim_grey"], M["paint"]))
        body.beam([mir(B_FOOT, sx), mir(sunk(B_TOP), sx)], 0.09, 0.08, (sx, 0, 0), (M["seal"], M["trim_grey"], M["seal"]))
        body.beam([mir((x, y, z - 0.03), sx) for x, y, z in (A_TOP, B_TOP, C_TOP)], 0.05, 0.05, (sx, 0, 0.3), (M["paint"], M["headliner"], M["paint"]))
        # the front side window, between the A and B pillars (the driver's is in his door, which starts behind the pillar's foot)
        bf, br, tr, tf = (0.815, -0.80 if sx > 0 else -0.76, 1.012), (0.815, 0.09, 1.012), (0.64, 0.085, 1.455), (0.63, -0.26, 1.44)
        (body if sx > 0 else door_dr).sheet(*[mir(p, sx) for p in ((bf, br, tr, tf) if sx > 0 else (br, bf, tf, tr))], glass)
        if sx < 0:  # the rear right window, in the body (the left one is in the door)
            body.sheet(*[mir(p, sx) for p in ((0.815, 0.885, 1.012), (0.815, 0.145, 1.012), (0.635, 0.145, 1.45), (0.615, 0.775, 1.44))], glass)
        # the quarter panel, from the belt behind the rear door to the rail and the hatch glass
        belt = [(0.82, 0.89, 1.012), (0.815, 1.2, 1.02), (0.81, 1.45, 1.03), (0.81, 1.70, 1.04)]
        rail = [(0.60, 0.78, 1.445), (0.575, 1.30, 1.42), (0.62, 1.52, 1.24), (0.665, 1.70, 1.045)]
        quarter = [[tuple(b[k] + (r[k] - b[k]) * t for k in range(3)) for t in (0, 1 / 3, 2 / 3, 1)] for b, r in zip(belt, rail)]
        quarter = [[mir(p, sx) for p in row] for row in quarter]
        body.loft(quarter, M["paint"], closed=False, toward=(0, (sx, 0, 0.4)))
        inner = [[(p[0] - 0.04 * sx, p[1], p[2] - 0.02) for p in row] for row in quarter]
        body.loft(inner, M["trim_grey"], closed=False, toward=(0, (-sx, 0, -0.4)))
    # the windscreen and the hatch glass
    wf, wt = (A_FOOT[0] - 0.02, A_FOOT[1], A_FOOT[2]), A_TOP
    body.sheet((-wf[0], wf[1], wf[2]), wf, wt, (-wt[0], wt[1], wt[2]), glass, nu=4, nv=3, facing=WIND_OUT)
    body.sheet((HATCH_BOTTOM[0], HATCH_BOTTOM[1], HATCH_BOTTOM[2]), (-HATCH_BOTTOM[0], HATCH_BOTTOM[1], HATCH_BOTTOM[2]),
               (-HATCH_TOP[0], HATCH_TOP[1], HATCH_TOP[2]), HATCH_TOP, glass, nu=4, nv=3, facing=(0, 0.6, 0.8))
    # the rear left door's window, with the door
    door_rl.sheet((0.815, 0.145, 1.012), (0.815, 0.885, 1.012), (0.615, 0.775, 1.44), (0.635, 0.145, 1.45), glass)


# --- the inside -----------------------------------------------------------------------------------------
M.update({
    "plush": car.material("plush", (0.34, 0.15, 0.03), rough=1.0, texture=weave),
    "plush_dark": car.material("plush_dark", (0.035, 0.025, 0.02), rough=1.0, texture=weave),
    "card": car.material("card", (0.22, 0.30, 0.38), rough=0.9, texture=grain),
    "tissue": car.material("tissue", (0.62, 0.62, 0.6), rough=1.0, texture=weave),
    "webbing": car.material("webbing", (0.045, 0.045, 0.05), rough=0.9, texture=weave),
    "mirror_glass": car.material("mirror_glass", (0.02, 0.025, 0.03), rough=0.08, metal=0.3),
    "plate": car.material("plate", (0.018, 0.018, 0.017), rough=0.95),  # Malaysian private plates are black; this one has nothing on it
    "plate_rim": car.material("plate_rim", (0.07, 0.07, 0.068), rough=0.95),
})


def seat(body: Part, h, width: float = 0.47) -> None:
    """One seat about its H-point h (a front seat, or one side of the rear bench): cushion, bolsters, backrest leaning back 22
    degrees, headrest. The seat is built about the origin and placed with the matrices."""
    place = at(h)
    lean = at(h) @ Matrix.Rotation(math.radians(-22), 4, "X")
    c, cl, plastic = M["cloth"], M["cloth_light"], M["seat_back"]
    body.rbox((0, -0.20, -0.18), (width, 0.50, 0.15), 0.04, c, place)
    body.box((0, -0.20, -0.1025), (width * 0.62, 0.44, 0.012), cl, place)
    for sx in (1, -1):
        body.rbox((sx * (width / 2 - 0.035), -0.22, -0.12), (0.07, 0.44, 0.07), 0.025, c, place, seg=1)
    body.box((0, -0.15, -0.275), (width * 0.76, 0.40, 0.07), plastic, place)
    body.rbox((0, 0.195, 0.20), (width, 0.13, 0.58), 0.04, c, lean)
    body.box((0, 0.1345, 0.22), (width * 0.6, 0.012, 0.44), cl, lean)
    for sx in (1, -1):
        body.rbox((sx * (width / 2 - 0.03), 0.17, 0.20), (0.06, 0.12, 0.55), 0.02, c, lean, seg=1)
    body.rbox((0, 0.268, 0.19), (width - 0.02, 0.025, 0.55), 0.012, plastic, lean, seg=1)
    body.rbox((0, 0.282, 0.02), (width * 0.62, 0.02, 0.17), 0.01, c, lean, seg=1)  # the map pocket
    body.rbox((0, 0.19, 0.67), (0.25, 0.10, 0.17), 0.04, c, lean)
    for sx in (1, -1):  # the headrest's posts
        body.cyl(lean @ Vector((sx * 0.07, 0.19, 0.47)), lean @ Vector((sx * 0.07, 0.19, 0.60)), 0.007, 0.007, M["steel"], sides=6)


def rear_bench(body: Part) -> None:
    y, z = SEATS["seat_rear_left"][1], SEATS["seat_rear_left"][2]
    for sx in (1, -1):
        seat(body, (sx * 0.37, y, z), width=0.55)
    h = (0, y, z - 0.02)
    place = at(h)
    lean = at(h) @ Matrix.Rotation(math.radians(-22), 4, "X")
    body.rbox((0, -0.20, -0.18), (0.20, 0.50, 0.15), 0.04, M["cloth"], place)
    body.rbox((0, 0.195, 0.20), (0.20, 0.13, 0.56), 0.04, M["cloth"], lean)
    body.box((0, y - 0.20, z - 0.275), (1.30, 0.46, 0.06), M["trim_dark"])  # the base under the cushions


# --- the dashboard --------------------------------------------------------------------------------------
FONT = {"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111", "4": "101101111001001",
        "5": "111100111001111", "6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111"}


def gauge_image() -> bpy.types.Image:
    """The instrument cluster's dials, 256 x 128: a tachometer and a speedometer, amber on black, needles at a cruise, a small
    fuel and temperature arc between them and a row of dim warning lamps. Drawn at twice the size and averaged down."""
    w, h = 512, 256
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    canvas = np.zeros((h, w, 3), np.float32)
    amber, red = np.array([1.0, 0.62, 0.18], np.float32), np.array([1.0, 0.22, 0.07], np.float32)

    def paint(cover, colour, level=1.0) -> None:
        nonlocal canvas
        canvas = np.maximum(canvas, cover[..., None] * np.asarray(colour, np.float32) * level)

    def seg(p, q, width):
        p, q = np.array(p, np.float32), np.array(q, np.float32)
        d = q - p
        t = np.clip(((xx - p[0]) * d[0] + (yy - p[1]) * d[1]) / max(float(d @ d), 1e-6), 0, 1)
        dist = np.hypot(xx - (p[0] + t * d[0]), yy - (p[1] + t * d[1]))
        return np.clip(width / 2 + 0.7 - dist, 0, 1)

    def disc(c, r, fill=True):
        dist = np.hypot(xx - c[0], yy - c[1])
        return np.clip(r + 0.7 - dist, 0, 1) if fill else np.clip(1.4 - np.abs(dist - r), 0, 1)

    def digits(text, c, cell):
        out = np.zeros((h, w), np.float32)
        x0 = c[0] - (len(text) * 4 - 1) * cell / 2
        for k, ch in enumerate(text):
            for n, bit in enumerate(FONT[ch]):
                if bit == "1":
                    x, y = x0 + (k * 4 + n % 3) * cell, c[1] - 2.5 * cell + (n // 3) * cell
                    out = np.maximum(out, np.clip(np.minimum(np.minimum(xx - x, x + cell - xx), np.minimum(yy - y, y + cell - yy)) + 0.7, 0, 1))
        return out

    def dial(c, r, top, major, minor, step, cruise, redline=None):
        glow = np.hypot(xx - c[0], yy - c[1])
        paint(np.clip((r - glow) / r, 0, 1) ** 0.5 * (glow < r), amber, 0.06)  # the backlit face
        paint(disc(c, r, False), amber, 0.7)
        for k in range(minor + 1):
            a = math.radians(225 - 270 * k / minor)
            long = k % (minor // major) == 0
            p = (c[0] + math.cos(a) * r * (0.78 if long else 0.86), c[1] - math.sin(a) * r * (0.78 if long else 0.86))
            q = (c[0] + math.cos(a) * r * 0.95, c[1] - math.sin(a) * r * 0.95)
            red_zone = redline is not None and k / minor >= redline
            paint(seg(p, q, 3.0 if long else 1.6), red if red_zone else amber, 0.9)
        for k in range(major + 1):
            a = math.radians(225 - 270 * k / major)
            label = str(int(k * step))
            paint(digits(label, (c[0] + math.cos(a) * r * 0.58, c[1] - math.sin(a) * r * 0.58), 2.2 if len(label) < 3 else 1.9), amber, 0.9)
        a = math.radians(225 - 270 * cruise)
        paint(seg(c, (c[0] + math.cos(a) * r * 0.82, c[1] - math.sin(a) * r * 0.82), 4.0), red, 1.0)
        paint(disc(c, 7), (0.25, 0.25, 0.25))

    dial((120, 120), 104, 0, 8, 16, 1, 0.27, redline=0.85)  # tachometer, 0 to 8 (x 1000), at 2 200 rpm
    dial((392, 120), 104, 0, 9, 18, 20, 0.28)  # speedometer, 0 to 180, at 50 km/h
    for x0 in (236, 276):  # fuel (left) and temperature (right): a short ruler each, the first mark red
        for k in range(6):
            x = x0 + (k / 5 - 0.5) * 30
            paint(seg((x, 112 - k % 2 * 3), (x, 124), 2.0), red if k == 0 else amber, 0.7)
    for x, colour in ((150, red), (180, amber), (210, red), (302, (0.3, 1.0, 0.4)), (332, (0.3, 1.0, 0.4)), (362, (0.3, 0.5, 1.0))):
        paint(disc((x, 232), 6), colour, 0.12)  # warning lamps, off
    small = canvas.reshape(h // 2, 2, w // 2, 2, 3).mean(axis=(1, 3))
    return car._image("gauges", np.concatenate([np.flipud(small), np.ones((h // 2, w // 2, 1), np.float32)], axis=-1))


def dash_ring(x: float, k: float = 1.0) -> list:
    """The dashboard's cross-section at x, as (x, y, z) points; k below 1 draws it in at the ends."""
    pts = [(-0.87, 0.955), (-0.62, 0.935), (-0.47, 0.905), (-0.43, 0.86), (-0.50, 0.77), (-0.60, 0.60), (-0.68, 0.46), (-0.87, 0.40)]
    return [(x, y, 0.40 + (z - 0.40) * k) for y, z in pts]


def dashboard(body: Part) -> None:
    xs = [-0.77, -0.74, -0.5, -0.2, 0.1, 0.4, 0.7, 0.745, 0.77]
    rings = [dash_ring(x, 0.6 if abs(x) > 0.76 else 0.85 if abs(x) > 0.73 else 1.0) for x in xs]
    mats = [M["trim_dark"]] * 4 + [M["trim_grey"]] * 3 + [M["liner"]]
    body.loft(rings, mats, toward=(0, (0, 0, 1)))
    body.poly(rings[0], M["trim_dark"], facing=(-1, 0, 0))
    body.poly(rings[-1], M["trim_dark"], facing=(1, 0, 0))
    # the instrument cluster in front of the driver: a hooded pod standing on the dash, the dials on its rear face
    d = SEATS["seat_driver"][0]
    body.rbox((d, -0.675, 0.975), (0.42, 0.14, 0.09), 0.02, M["trim_dark"], seg=1)
    body.rbox((d, -0.60, 1.032), (0.42, 0.12, 0.025), 0.008, M["trim_dark"], seg=1)  # the hood over the dials
    g, u, v = Vector((d, -0.5955, 0.972)), Vector((1, 0, 0)), Vector((0, -0.45, 0.89)).normalized()
    gauges = car.material("gauges", (0.004, 0.004, 0.004), rough=0.5, emission=gauge_image(), ao=False)
    body.sheet(g + u * 0.15 - v * 0.055, g - u * 0.15 - v * 0.055, g - u * 0.15 + v * 0.055, g + u * 0.15 + v * 0.055, gauges, facing=(0, 0.89, 0.45))
    # the centre stack, the vents, the glovebox
    body.rbox((0, -0.52, 0.66), (0.26, 0.18, 0.36), 0.015, M["trim_grey"], seg=1)
    body.rbox((0, -0.428, 0.77), (0.20, 0.01, 0.07), 0.004, M["liner"], seg=1)  # the head unit
    for x in (-0.07, 0.0, 0.07):
        body.cyl((x, -0.43, 0.67), (x, -0.41, 0.67), 0.018, 0.018, M["trim_dark"], sides=8)
    for x in (-0.05, 0.05):
        body.rbox((x, -0.43, 0.58), (0.05, 0.012, 0.025), 0.004, M["trim_dark"], seg=1)
    for x, z in ((-0.68, 0.80), (-0.20, 0.79), (0.20, 0.79), (0.68, 0.80)):
        body.rbox((x, -0.44, z), (0.10, 0.02, 0.045), 0.006, M["liner"], seg=1)
        body.box((x, -0.428, z), (0.09, 0.004, 0.003), M["trim_grey"])
    body.rbox((0.45, -0.58, 0.63), (0.42, 0.02, 0.2), 0.008, M["trim_grey"], seg=1)  # the glovebox lid
    body.rbox((0.45, -0.565, 0.565), (0.08, 0.015, 0.02), 0.005, M["trim_dark"], seg=1)
    # the wheel and its column
    hub = Vector((d, -0.47, 0.94))
    normal = Vector((0, math.cos(math.radians(25)), math.sin(math.radians(25))))
    frame = aim(hub, hub + normal)
    body.draw(lambda bm: car.torus(bm, 0.168, 0.0175, 22, 8), M["trim_dark"], frame)
    body.cyl(hub - normal * 0.015, hub + normal * 0.03, 0.05, 0.047, M["trim_dark"], sides=14)
    for k in range(3):  # three spokes
        a = math.radians(270 + 120 * k)  # 6, 10 and 2 o'clock
        tip = frame @ Vector((math.cos(a) * 0.16, math.sin(a) * 0.16, 0.0))
        body.beam([hub, tip], 0.03, 0.016, normal, (M["trim_dark"], M["trim_dark"], M["trim_dark"]))
    body.cyl(hub - normal * 0.02, hub - normal * 0.30 + Vector((0, 0, 0.0)), 0.04, 0.042, M["trim_dark"], sides=10)
    # the plush toy on the dash, in the middle: a small tiger, sitting, facing the back seat
    plush(body, Vector((0.02, -0.72, 0.945)))
    body.box((0.02, -0.72, 0.9475), (0.34, 0.20, 0.007), M["trim_dark"])  # the cloth mat under it
    # wipers resting along the foot of the windscreen
    nrm = WIND_OUT
    wy, wz = windscreen(0.045)
    for x0, x1 in ((-0.70, -0.14), (0.05, 0.62)):
        p0, p1 = Vector((x0, wy, wz)) + nrm * 0.012, Vector((x1, wy, wz)) + nrm * 0.012
        body.beam([p0, p1], 0.022, 0.014, nrm, (M["rubber"], M["rubber"], M["rubber"]))


def plush(body: Part, at_: Vector) -> None:
    """A faded plush tiger about 14 cm tall, sitting, facing +Y (the back seat). Invented, no logo."""
    m = Matrix.Translation(at_) @ Matrix.Rotation(math.radians(8), 4, "Z")
    body.rbox((0, 0, 0.055), (0.09, 0.08, 0.10), 0.03, M["plush"], m, seg=1)  # body
    body.rbox((0, 0.01, 0.135), (0.085, 0.075, 0.07), 0.025, M["plush"], m, seg=1)  # head
    for sx in (1, -1):
        body.box((sx * 0.035, 0.01, 0.175), (0.022, 0.012, 0.024), M["plush"], m)  # ears
        body.box((sx * 0.052, 0.025, 0.07), (0.022, 0.04, 0.06), M["plush"], m)  # arms
        body.box((sx * 0.027, 0.045, 0.015), (0.03, 0.05, 0.03), M["plush"], m)  # feet
        body.box((sx * 0.017, 0.0485, 0.14), (0.012, 0.004, 0.012), M["plush_dark"], m)  # eyes
    body.box((0, 0.06, 0.12), (0.03, 0.02, 0.02), M["plush_dark"], m)  # nose
    body.box((0.0, -0.045, 0.02), (0.015, 0.05, 0.015), M["plush"], m)  # tail
    for z in (0.04, 0.07, 0.095):
        body.box((0, 0.001, z), (0.092, 0.081, 0.012), M["plush_dark"], m)  # stripes round the body
    for x in (-0.03, 0.03):
        body.box((x, 0.012, 0.172), (0.012, 0.077, 0.006), M["plush_dark"], m)  # stripes on the head


# --- doors, ceiling, belts, the cargo area ---------------------------------------------------------------

def door_card(part: Part, sx: int, y0: float, y1: float, front: bool) -> None:
    """What is on the inside of a door between y0 (front edge) and y1: armrest with its pull handle, release lever, window
    switch (front doors), speaker, map pocket."""
    ym = (y0 + y1) / 2
    part.rbox((sx * 0.735, ym + 0.02, 0.775), (0.07, 0.34, 0.05), 0.02, M["trim_grey"], seg=1)
    part.box((sx * 0.745, ym - 0.04, 0.805), (0.03, 0.12, 0.02), M["liner"])
    part.rbox((sx * 0.752, y0 + 0.09, 0.89), (0.026, 0.09, 0.022), 0.008, M["trim_dark"], seg=1)
    if front:
        part.rbox((sx * 0.744, y0 + 0.12, 0.805), (0.04, 0.10, 0.012), 0.004, M["trim_dark"], seg=1)
    part.cyl((sx * 0.765, ym, 0.56), (sx * 0.745, ym, 0.56), 0.07, 0.07, M["liner"], sides=12, caps=(False, True))
    part.rbox((sx * 0.745, ym, 0.505), (0.04, 0.36, 0.10), 0.012, M["trim_dark"], seg=1)


def outside_handle(part: Part, sx: int, y: float) -> None:
    part.rbox((sx * 0.866, y, 0.925), (0.026, 0.14, 0.022), 0.008, M["paint"], seg=1)
    part.box((sx * 0.859, y, 0.925), (0.012, 0.15, 0.03), M["liner"])


def on_glass(t: float, x: float, lift: float = 0.006) -> Matrix:
    """A placement on the windscreen's inside at fraction t up its slope and x across, its local Y along the glass's normal."""
    y, z = windscreen(t)
    return Matrix.Translation(Vector((x, y, z)) - WIND_OUT * lift) @ Matrix.Rotation(math.atan2(WIND_OUT.z, WIND_OUT.y), 4, "X")


def ceiling(body: Part) -> None:
    """Visors, the dome light, the grab handles, the header, the mirror and what hangs from it, the tags on the glass."""
    for sx in (1, -1):
        body.rbox((sx * 0.30, -0.12, 1.372), (0.36, 0.22, 0.022), 0.008, M["headliner"], seg=1)
    body.box((0, -0.222, 1.398), (1.18, 0.03, 0.035), M["trim_grey"])
    body.rbox((0, 0.08, 1.432), (0.14, 0.08, 0.022), 0.01, M["cloth_light"], seg=1)
    for sx, y in ((1, -0.02), (1, 0.58), (-1, 0.58)):
        body.rbox((sx * 0.585, y, 1.372), (0.025, 0.16, 0.022), 0.008, M["trim_grey"], seg=1)
        for dy in (-0.075, 0.075):
            body.box((sx * 0.59, y + dy, 1.392), (0.03, 0.025, 0.03), M["trim_grey"])
    # the mirror: its glass is the mirror_mount empty's plane
    body.cyl((0, -0.255, 1.425), (0, -0.315, 1.34), 0.008, 0.008, M["trim_dark"], sides=6)
    body.rbox((0, MIRROR_Y - 0.025, 1.30), (0.26, 0.04, 0.075), 0.015, M["trim_dark"], seg=1)
    body.sheet((0.12, MIRROR_Y - 0.002, 1.268), (-0.12, MIRROR_Y - 0.002, 1.268), (-0.12, MIRROR_Y - 0.002, 1.332), (0.12, MIRROR_Y - 0.002, 1.332), M["mirror_glass"], facing=(0, 1, 0))
    # a parking pass hanging from the mirror (plain card, no design), a toll-tag and a road tax disc on the glass
    body.cyl((0.10, -0.33, 1.27), (0.10, -0.33, 1.165), 0.002, 0.002, M["webbing"], sides=4)
    body.box((0.10, -0.33, 1.135), (0.075, 0.003, 0.055), M["card"])
    body.box((0.10, -0.3315, 1.12), (0.075, 0.002, 0.012), M["trim_dark"])
    body.rbox((0, 0, 0), (0.085, 0.008, 0.05), 0.003, M["card"], on_glass(0.72, 0.24), seg=1)
    body.box((0, 0, 0), (0.10, 0.004, 0.07), M["tissue"], on_glass(0.14, 0.60))
    body.box((0, 0.002, 0), (0.10, 0.003, 0.012), M["trim_dark"], on_glass(0.14, 0.60))


def belts(body: Part) -> None:
    """Seat belts, unfastened, hanging from their pillars: a webbing strip, its upper anchor, the retractor at the foot."""
    for sx, y, z_top, z_bot, x_top in ((1, 0.095, 1.12, 0.52, 0.745), (-1, 0.095, 1.12, 0.52, 0.745),
                                       (1, 0.945, 1.07, 0.60, 0.73), (-1, 0.945, 1.07, 0.60, 0.73)):
        body.sheet((sx * x_top, y - 0.022, z_bot), (sx * x_top, y + 0.022, z_bot), (sx * x_top, y + 0.022, z_top), (sx * x_top, y - 0.022, z_top),
                   M["webbing"], back=M["webbing"], gap=0.004, facing=(-sx, 0, 0))
        body.box((sx * (x_top + 0.003), y, z_top + 0.012), (0.014, 0.05, 0.035), M["trim_dark"])
        body.rbox((sx * (x_top + 0.005), y, z_bot - 0.03), (0.03, 0.07, 0.07), 0.01, M["trim_dark"], seg=1)
        body.box((sx * x_top, y, z_bot + 0.015), (0.012, 0.03, 0.05), M["trim_dark"])  # the tongue


def cargo(body: Part) -> None:
    """The parcel tray, with a tissue box and an umbrella on it; the wheelhouses' bumps; mats on the floor."""
    body.box((0, 1.43, 0.965), (1.26, 0.56, 0.02), M["trim_dark"])
    body.box((0, 1.14, 0.93), (1.26, 0.02, 0.07), M["trim_dark"])
    body.rbox((0.12, 1.45, 1.015), (0.24, 0.12, 0.075), 0.01, M["card"], seg=1)  # a box of tissues
    body.box((0.12, 1.45, 1.058), (0.07, 0.03, 0.012), M["tissue"])
    body.cyl((-0.45, 1.30, 0.99), (-0.45, 1.62, 1.0), 0.026, 0.02, M["rubber"], sides=8)  # a folded umbrella
    for sx in (1, -1):
        body.box((sx * 0.64, 1.225, 0.42), (0.24, 0.72, 0.28), M["trim_dark"])  # the wheelhouse in the cargo area
    for sx in (1, -1):
        body.box((sx * 0.37, -0.50, FLOOR + 0.006), (0.50, 0.62, 0.012), M["rubber"])  # front footwell mats
        body.box((sx * 0.37, 0.50, FLOOR + 0.006), (0.50, 0.50, 0.012), M["rubber"])  # rear
    body.box((0, 1.38, FLOOR + 0.004), (1.2, 0.66, 0.008), M["carpet"])


def console(body: Part) -> None:
    """The centre console between the front seats, its gear lever, the handbrake and two cup holders."""
    body.rbox((0, -0.36, 0.41), (0.20, 0.64, 0.24), 0.03, M["trim_grey"], seg=1)
    body.rbox((0, -0.36, 0.535), (0.18, 0.6, 0.012), 0.004, M["trim_dark"], seg=1)
    body.cyl((0, -0.34, 0.54), (0, -0.30, 0.65), 0.012, 0.012, M["trim_dark"], sides=6)
    body.rbox((0, -0.295, 0.675), (0.04, 0.05, 0.07), 0.015, M["trim_dark"], seg=1)
    body.cyl((-0.06, -0.06, 0.52), (-0.06, 0.0, 0.60), 0.01, 0.01, M["trim_dark"], sides=6)
    body.rbox((-0.06, 0.005, 0.61), (0.03, 0.06, 0.025), 0.008, M["trim_dark"], seg=1)
    body.rbox((0, -0.07, 0.40), (0.20, 0.1, 0.16), 0.02, M["trim_dark"], seg=1)  # the back of the console, facing the rear seat


def exterior(body: Part, door_rl: Part, door_dr: Part) -> None:
    """Lights, grille, handles, mirrors and shut lines: the little that makes it read as a car from outside."""
    headlight = car.material("headlight_lens", (0.26, 0.28, 0.29), rough=0.1, metal=0.3, ao=False)
    taillight = car.material("taillight_lens", (0.30, 0.015, 0.012), rough=0.15, ao=False)
    for sx in (1, -1):
        m = Matrix.Translation((sx * 0.67, -1.945, 0.735)) @ Matrix.Rotation(math.radians(sx * 30), 4, "Z")
        body.rbox((0, 0, 0), (0.36, 0.07, 0.10), 0.02, M["liner"], m, seg=1)
        body.rbox((0, -0.008, 0), (0.34, 0.05, 0.085), 0.02, headlight, m, seg=1)
        body.rbox((sx * 0.52, 1.872, 0.80), (0.24, 0.035, 0.17), 0.012, taillight, seg=1)
        body.rbox((sx * 0.95, -0.80, 1.035), (0.09, 0.14, 0.09), 0.02, M["paint"], None, seg=1)  # the door mirror
        body.box((sx * 0.905, -0.78, 1.0), (0.05, 0.04, 0.03), M["paint"])
        body.sheet((sx * 0.935, -0.715, 1.0), (sx * 0.935, -0.715, 1.07), (sx * 0.985, -0.715, 1.07), (sx * 0.985, -0.715, 1.0), M["mirror_glass"], facing=(0, 1, 0))
        outside_handle(body if sx > 0 else door_dr, sx, 0.0)
        for y in (-0.72, 0.105):  # shut lines: the doors' edges
            body.beam([(sx * 0.858, y, 0.50), (sx * 0.8585, y, 0.72), (sx * 0.848, y, interp(BELT, y)[0])], 0.006, 0.004, (sx, 0, 0), (M["seal"], M["seal"], M["seal"]))
        if sx < 0:
            outside_handle(body, sx, 0.80)
    body.rbox((0, -2.02, 0.47), (0.90, 0.04, 0.11), 0.02, M["liner"], seg=1)
    body.box((0, 1.879, 0.58), (0.50, 0.008, 0.135), M["plate_rim"])  # a blank number plate: black, nothing on it, a pale rim
    body.box((0, 1.8855, 0.58), (0.46, 0.007, 0.105), M["plate"])
    body.beam([(0.858, 0.89, 0.50), (0.8585, 0.89, 0.72), (0.848, 0.89, interp(BELT, 0.89)[0])], 0.006, 0.004, (1, 0, 0), (M["seal"], M["seal"], M["seal"]))
    body.beam([(-0.858, 0.89, 0.50), (-0.8585, 0.89, 0.72), (-0.848, 0.89, interp(BELT, 0.89)[0])], 0.006, 0.004, (-1, 0, 0), (M["seal"], M["seal"], M["seal"]))
    outside_handle(door_rl, 1, 0.80)
    door_card(door_rl, 1, DOOR[0], DOOR[1], False)
    door_card(door_dr, -1, FRONT_DOOR[0], FRONT_DOOR[1], True)


# --- build ----------------------------------------------------------------------------------------------

def empty(name: str, loc, rot=(0, 0, 0)) -> bpy.types.Object:
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.08
    e.location = loc
    e.rotation_euler = tuple(math.radians(a) for a in rot)
    bpy.context.scene.collection.objects.link(e)
    return e


body, door_rl, door_dr = Part("hatchback", []), Part("door_rear_left", []), Part("door_driver", [])
shells(body, door_rl, door_dr)
greenhouse(body, door_rl, door_dr)
for h in (SEATS["seat_driver"], SEATS["seat_front"]):
    seat(body, h)
rear_bench(body)
dashboard(body)
console(body)
ceiling(body)
belts(body)
cargo(body)
exterior(body, door_rl, door_dr)
for sx, y0, y1, front in ((1, FRONT_DOOR[0], FRONT_DOOR[1], True), (-1, DOOR[0], DOOR[1], False)):  # the doors that stay shut
    door_card(body, sx, y0, y1, front)
for d in (door_rl, door_dr):
    bmesh.ops.remove_doubles(d.bm, verts=d.bm.verts, dist=1e-5)
body_obj, rl_obj, dr_obj = body.object(sharp=50), door_rl.object(sharp=50), door_dr.object(sharp=50)
for obj, pivot in ((rl_obj, Vector((0.857, DOOR[0], 0.70))), (dr_obj, Vector((-0.857, FRONT_DOOR[0], 0.70)))):  # the hinge lines: the doors' front edges
    obj.data.transform(Matrix.Translation(-pivot))
    obj.location = pivot
wheels = [car.wheel(n, sx, (sx * TRACK, y, TYRE), TYRE, M["rubber"], M["steel"]) for n, sx, y in (("wheel_fl", 1, -AXLE), ("wheel_fr", -1, -AXLE), ("wheel_rl", 1, AXLE), ("wheel_rr", -1, AXLE))]
d = SEATS["seat_driver"]
empties = [empty(n, p) for n, p in SEATS.items()] + [
    empty("mirror_mount", (0, MIRROR_Y, 1.30), (0, 0, 180)),  # its local +Z faces the back seat
    empty("headlight_l", (0.65, -1.98, 0.735), (0, 0, 180)), empty("headlight_r", (-0.65, -1.98, 0.735), (0, 0, 180)),  # -Z is the beam, forward
    empty("taillight_l", (0.52, 1.89, 0.80)), empty("taillight_r", (-0.52, 1.89, 0.80)),  # -Z points back
    empty("dash_glow", (d[0], -0.58, 0.97)),
]
meshes = [body_obj, rl_obj, dr_obj] + wheels
textured = {m: 0.12 for m in M.values() if m.name in ("headliner", "carpet", "cloth", "cloth_light", "plush", "plush_dark", "tissue", "webbing")}
textured.update({m: 0.2 for m in M.values() if m.name in ("trim_dark", "trim_grey", "seat_back", "card")})
for o in meshes:
    car.uv_box(o, textured)
bpy.context.view_layer.update()  # the objects' world matrices, for the occlusion rays
car.bake_ao(meshes, skip=("glass",))
common.export("hatchback", meshes + empties)

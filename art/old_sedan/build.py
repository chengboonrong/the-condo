"""The slow sedan: a small, rounded, old saloon in faded yellow, no badge, nothing in it. One tail light burns dim and the other is
dead. Seen from behind, in the couple's headlights, in fog; its rear window is see-through and shows the front seats, a
right-hand-drive driver's seat and the dashboard, all empty. Run by tools/models.sh.

Origin: the ground at the centre of the wheelbase; the front faces Blender -Y (the game's +Z); the car's left is +X. About 4.0 m by
1.62 m by 1.38 m. Objects: "old_sedan", wheel_fl, wheel_fr, wheel_rl, wheel_rr (origin at the hub) and the empties headlight_l,
headlight_r (-Z is the beam, forward), taillight_l, taillight_r (-Z points back). Materials the game drives: "headlight_lens",
"taillight_dim" (the left lamp, to glow faintly) and "taillight_dead" (the right one, which stays dark). Plain materials and two
tiny tiling textures; ambient occlusion in the "ao" vertex colours.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "car")]
import car  # noqa: E402
import common  # noqa: E402
from car import Part, aim, at  # noqa: E402

AXLE, TRACK, TYRE, ARCH = 1.17, 0.68, 0.275, 0.31
COWL, CAB_END = -0.72, 1.30  # the nose shell ends at the windscreen's foot; the tub (the cabin) ends at the boot
BELT = [(-0.72, 0.90), (-0.5, 0.925), (1.0, 0.925), (1.3, 0.915)]
FLOOR = 0.285
SEATS = {"driver": (-0.35, 0.0, 0.52), "front": (0.35, 0.0, 0.52), "rear_left": (0.35, 0.86, 0.54), "rear_right": (-0.35, 0.86, 0.54)}
A_FOOT, A_TOP = (0.77, -0.70, 0.915), (0.585, -0.10, 1.335)
B_FOOT, B_TOP = (0.815, 0.12, 0.925), (0.60, 0.10, 1.36)
C_TOP, C_FOOT = (0.575, 0.92, 1.345), (0.79, 1.28, 0.915)
ROOF = [(-0.10, 1.31, 1.345), (0.2, 1.335, 1.375), (0.6, 1.335, 1.375), (0.93, 1.315, 1.345)]  # y, edge z, centre z

common.reset()
weave, grain = car.weave_image(), car.grain_image()
M = {
    "paint": car.material("paint", (0.46, 0.37, 0.10), rough=0.62),  # sides: faded yellow
    "paint_faded": car.material("paint_faded", (0.56, 0.49, 0.20), rough=0.8),  # bonnet, roof and boot lid, bleached by the sun
    "glass": car.material("glass", (0.07, 0.08, 0.07), rough=0.15, alpha=0.3),
    "liner": car.material("liner", (0.012, 0.012, 0.013), rough=0.95),
    "seal": car.material("seal", (0.008, 0.008, 0.009), rough=0.9),
    "rubber": car.material("rubber", (0.014, 0.014, 0.015), rough=0.9),
    "steel": car.material("steel", (0.16, 0.16, 0.16), rough=0.6, metal=0.4),
    "trim_dark": car.material("trim_dark", (0.03, 0.03, 0.03), rough=0.75, texture=grain),
    "cloth": car.material("cloth", (0.075, 0.06, 0.05), rough=0.95, texture=weave),
    "headliner": car.material("headliner", (0.17, 0.16, 0.13), rough=0.95, texture=weave),
    "carpet": car.material("carpet", (0.03, 0.028, 0.026), rough=1.0, texture=weave),
    "plate": car.material("plate", (0.26, 0.26, 0.24), rough=0.5),
    "headlight_lens": car.material("headlight_lens", (0.5, 0.48, 0.42), rough=0.15, ao=False),
    "taillight_dim": car.material("taillight_dim", (0.16, 0.012, 0.01), rough=0.2, ao=False),
    "taillight_dead": car.material("taillight_dead", (0.06, 0.03, 0.025), rough=0.35, ao=False),
}


def arch_height(y: float, zb: float) -> float:
    return car.arch_height(y, zb, AXLE, ARCH, TYRE)


def tub_half(y: float) -> list:
    zb = 0.23
    ha = arch_height(y, zb)
    zbelt = car.interp(BELT, y)[0]
    z4 = max(zb + 0.07, ha + 0.012)
    return [(0, zb), (0.56, zb), (0.56, ha), (0.76, ha), (0.81, z4), (0.813, max(0.44, z4 + 0.02)), (0.818, 0.68), (0.805, zbelt),
            (0.765, zbelt + 0.012), (0.738, zbelt + 0.01), (0.735, zbelt - 0.05), (0.73, 0.68), (0.71, 0.42), (0.67, 0.30), (0.40, FLOOR), (0, 0.27)]


FRONT = [(-2.0, 0.50, 0.36, 0.60, 0.65, 0.44), (-1.985, 0.62, 0.33, 0.66, 0.70, 0.56), (-1.95, 0.72, 0.30, 0.70, 0.745, 0.65),
         (-1.88, 0.77, 0.27, 0.73, 0.77, 0.69), (-1.75, 0.80, 0.25, 0.75, 0.79, 0.72), (-1.6, 0.81, 0.24, 0.77, 0.805, 0.735),
         (COWL, 0.81, 0.23, 0.87, 0.89, 0.74)]
BOOT = [(CAB_END, 0.81, 0.24, 0.915, 0.93, 0.74), (1.6, 0.80, 0.26, 0.91, 0.925, 0.735), (1.85, 0.78, 0.30, 0.89, 0.905, 0.71),
        (1.95, 0.72, 0.34, 0.85, 0.87, 0.66), (1.99, 0.62, 0.38, 0.80, 0.82, 0.56), (2.0, 0.50, 0.40, 0.72, 0.74, 0.46)]
NOSE_MATS = [M["liner"]] * 3 + [M["paint"]] * 4 + [M["paint_faded"]]
TUB_MATS = [M["liner"]] * 3 + [M["paint"]] * 5 + [M["seal"]] + [M["trim_dark"]] * 4 + [M["carpet"]] * 2


def shells(body: Part) -> None:
    ys = [y for y in sorted(set([r[0] for r in FRONT] + car.arch_stations(-AXLE, ARCH))) if y <= COWL + 1e-6]
    body.loft([car.mirrored(car.nose_half(*car.interp(FRONT, y), arch_height(y, car.interp(FRONT, y)[1])), y) for y in ys],
              NOSE_MATS + NOSE_MATS[::-1], toward=(4, (1, 0, 0)))
    body.poly(car.mirrored(car.nose_half(*car.interp(FRONT, COWL), 0.23), COWL), M["liner"], facing=(0, 1, 0))
    body.poly(car.mirrored(car.nose_half(*FRONT[0][1:], 0.36), FRONT[0][0]), M["paint"], facing=(0, -1, 0))
    ys = [y for y in sorted(set([COWL, -0.4, 0.0, 0.5] + car.arch_stations(AXLE, ARCH) + [CAB_END])) if y <= CAB_END + 1e-6]
    body.loft([car.mirrored(tub_half(y), y) for y in ys], TUB_MATS + TUB_MATS[::-1], toward=(6, (1, 0, 0)))
    ys = sorted(set([r[0] for r in BOOT] + [y for y in car.arch_stations(AXLE, ARCH) if y >= CAB_END]))
    body.loft([car.mirrored(car.nose_half(*car.interp(BOOT, y), arch_height(y, car.interp(BOOT, y)[1])), y) for y in ys],
              NOSE_MATS + NOSE_MATS[::-1], toward=(4, (1, 0, 0)))
    body.poly(car.mirrored(car.nose_half(*BOOT[0][1:], 0.24), CAB_END), M["trim_dark"], facing=(0, -1, 0))  # the boot's front wall, behind the rear shelf
    body.poly(car.mirrored(car.nose_half(*BOOT[-1][1:], 0.40), BOOT[-1][0]), M["paint"], facing=(0, 1, 0))


def mir(p, sx):
    return (p[0] * sx, p[1], p[2])


def greenhouse(body: Part) -> None:
    glass = M["glass"]
    xs = [-0.60 + 1.20 * k / 6 for k in range(7)]
    rings = []
    for y, ze, zc in ROOF:
        top = [(x, y, ze + (zc - ze) * (1 - (x / 0.60) ** 2)) for x in xs]
        rings.append(top + [(x * 0.94, yy, z - 0.05) for x, yy, z in top][::-1])
    body.loft(rings, [M["paint_faded"]] * 7 + [M["headliner"]] * 6 + [M["paint_faded"]], toward=(3, (0, 0, 1)))
    body.poly(rings[0], M["paint_faded"], facing=(0, -1, 0))
    body.poly(rings[-1], M["paint_faded"], facing=(0, 1, 0))
    for sx in (1, -1):
        body.beam([mir(A_FOOT, sx), mir(A_TOP, sx)], 0.07, 0.065, (sx, 0, 0), (M["paint"], M["trim_dark"], M["paint"]))
        body.beam([mir(B_FOOT, sx), mir(B_TOP, sx)], 0.085, 0.075, (sx, 0, 0), (M["seal"], M["trim_dark"], M["seal"]))
        body.beam([mir(A_TOP, sx), mir(B_TOP, sx), mir(C_TOP, sx)], 0.045, 0.045, (sx, 0, 0.3), (M["paint_faded"], M["headliner"], M["paint_faded"]))
        windows = (((0.80, -0.58, 0.925), (0.80, 0.08, 0.925), (0.61, 0.085, 1.355), (0.595, -0.12, 1.335)),
                   ((0.80, 0.165, 0.925), (0.80, 1.10, 0.925), (0.59, 0.90, 1.345), (0.61, 0.165, 1.36)))
        for w in windows:
            body.sheet(*[mir(p, sx) for p in w], glass)
        # the C-pillar panel between the rear side window and the rear window
        quarter = [(0.80, 1.10, 0.925), (0.78, 1.28, 0.915), (0.64, 1.28, 0.935), (0.585, 0.93, 1.335)]
        body.sheet(*[mir(p, sx) for p in quarter], M["paint"], nu=2, nv=2, back=M["trim_dark"], gap=0.04, facing=(sx, 0.3, 0.3))
    wf, wt = (A_FOOT[0] - 0.02, A_FOOT[1], A_FOOT[2]), A_TOP
    body.sheet((-wf[0], wf[1], wf[2]), wf, wt, (-wt[0], wt[1], wt[2]), glass, nu=3, nv=2, facing=(0, -0.6, 0.8))
    body.sheet((0.64, 1.28, 0.935), (-0.64, 1.28, 0.935), (-0.52, 0.93, 1.335), (0.52, 0.93, 1.335), glass, nu=3, nv=2, facing=(0, 0.7, 0.7))
    body.box((0, 1.14, 0.90), (1.28, 0.28, 0.02), M["trim_dark"])  # the rear shelf


def seat(body: Part, h, width: float = 0.46, back_only: bool = False) -> None:
    place = at(h)
    lean = at(h) @ Matrix.Rotation(math.radians(-20), 4, "X")
    c = M["cloth"]
    if not back_only:
        body.rbox((0, -0.19, -0.17), (width, 0.48, 0.14), 0.04, c, place, seg=1)
        body.box((0, -0.15, -0.275), (width * 0.7, 0.38, 0.07), M["trim_dark"], place)
    body.rbox((0, 0.19, 0.19), (width, 0.12, 0.54), 0.04, c, lean, seg=1)
    if not back_only:
        body.rbox((0, 0.19, 0.60), (0.22, 0.09, 0.16), 0.035, c, lean, seg=1)
        for sx in (1, -1):
            body.cyl(lean @ Vector((sx * 0.06, 0.19, 0.45)), lean @ Vector((sx * 0.06, 0.19, 0.56)), 0.007, 0.007, M["steel"], sides=6)


def interior(body: Part) -> None:
    for k in ("driver", "front"):
        seat(body, SEATS[k])
    for k in ("rear_left", "rear_right"):
        seat(body, SEATS[k], back_only=False, width=0.55)
    body.box((0, 0.66, FLOOR + 0.05), (1.3, 0.5, 0.1), M["trim_dark"])  # the rear bench's base
    # the dashboard: a slab across, the wheel and its column on the right
    pts = [(-0.70, 0.90), (-0.50, 0.885), (-0.38, 0.86), (-0.36, 0.78), (-0.42, 0.60), (-0.70, 0.45)]
    xs = [-0.74, -0.4, 0.0, 0.4, 0.74]
    rings = [[(x, y, z) for y, z in pts] for x in xs]
    body.loft(rings, M["trim_dark"], toward=(0, (0, 0, 1)))
    body.poly(rings[0], M["trim_dark"], facing=(-1, 0, 0))
    body.poly(rings[-1], M["trim_dark"], facing=(1, 0, 0))
    body.rbox((-0.35, -0.52, 0.925), (0.34, 0.14, 0.08), 0.02, M["trim_dark"], seg=1)  # the instrument hood, a silhouette
    hub = Vector((-0.35, -0.36, 0.86))
    n = Vector((0, math.cos(math.radians(22)), math.sin(math.radians(22))))
    frame = aim(hub, hub + n)
    body.draw(lambda bm: car.torus(bm, 0.19, 0.016, 18, 6), M["trim_dark"], frame)
    body.cyl(hub - n * 0.02, hub - n * 0.28, 0.038, 0.04, M["trim_dark"], sides=8)
    for k in range(2):
        a = math.radians(0 + 180 * k)
        body.beam([hub, frame @ Vector((math.cos(a) * 0.18, math.sin(a) * 0.18, 0))], 0.03, 0.015, n, (M["trim_dark"],) * 3)


def exterior(body: Part) -> None:
    for sx in (1, -1):
        # round headlamps, a lamp each side of a plain grille; a tail lamp each side (the left one dim, the right one dead)
        body.cyl((sx * 0.55, -1.975, 0.66), (sx * 0.55, -2.01, 0.66), 0.085, 0.08, M["headlight_lens"], sides=14, caps=(False, True))
        body.rbox((sx * 0.60, 1.985, 0.80), (0.26, 0.05, 0.12), 0.015, M["taillight_dim"] if sx > 0 else M["taillight_dead"], seg=1)
        body.rbox((sx * 0.89, -0.55, 0.955), (0.07, 0.12, 0.07), 0.02, M["paint"], seg=1)
        body.box((sx * 0.84, -0.55, 0.94), (0.08, 0.04, 0.03), M["paint"])  # its stalk
        for y in (-0.2, 0.75):
            body.rbox((sx * 0.826, y, 0.84), (0.02, 0.12, 0.02), 0.006, M["seal"], seg=1)
    body.rbox((0, -2.0, 0.42), (1.52, 0.1, 0.1), 0.03, M["rubber"], seg=1)  # the bumpers
    body.rbox((0, 2.0, 0.42), (1.52, 0.1, 0.1), 0.03, M["rubber"], seg=1)
    body.rbox((0, -2.01, 0.62), (0.5, 0.03, 0.16), 0.01, M["liner"], seg=1)  # the grille
    body.box((0, 2.012, 0.62), (0.50, 0.012, 0.12), M["plate"])  # a blank number plate


body = Part("old_sedan", [])
shells(body)
greenhouse(body)
interior(body)
exterior(body)
body_obj = body.object(sharp=50)
wheels = [car.wheel(n, sx, (sx * TRACK, y, TYRE), TYRE, M["rubber"], M["steel"], 14) for n, sx, y in (("wheel_fl", 1, -AXLE), ("wheel_fr", -1, -AXLE), ("wheel_rl", 1, AXLE), ("wheel_rr", -1, AXLE))]


def empty(name: str, loc, rot=(0, 0, 0)) -> bpy.types.Object:
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.08
    e.location = loc
    e.rotation_euler = tuple(math.radians(a) for a in rot)
    bpy.context.scene.collection.objects.link(e)
    return e


empties = [empty("headlight_l", (0.55, -2.0, 0.66), (0, 0, 180)), empty("headlight_r", (-0.55, -2.0, 0.66), (0, 0, 180)),
           empty("taillight_l", (0.60, 2.0, 0.80)), empty("taillight_r", (-0.60, 2.0, 0.80))]
meshes = [body_obj] + wheels
textured = {m: 0.12 for m in M.values() if m.name in ("headliner", "carpet", "cloth")}
textured[M["trim_dark"]] = 0.2
for o in meshes:
    car.uv_box(o, textured)
bpy.context.view_layer.update()  # the objects' world matrices, for the occlusion rays
car.bake_ao(meshes, skip=("glass",))
common.export("old_sedan", meshes + empties)

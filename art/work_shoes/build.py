"""A pair of kitchen work shoes: black slip-ons with thick rubber soles, left by the door of a mamak worker. The
leather is creased across the toe flex, scuffed grey at the toes and shiny with grease in patches; the heels are
worn down on their outer edges; the rubber has side ribbing. Run by tools/models.sh.

Each shoe is lofted from stations along its length: a five-ring sole (bevel, ribbed wall, a ledge the upper stands in from) with the upper
rising from its top ring as a half-superellipse arch, dipped into an oval opening from the back of the heel to the
throat. The soles are open underneath: nothing ever sees them. The pair stands on the origin, toes towards -Y.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

LENGTH = 0.285
APART = 0.2  # between the shoes' centres
STATIONS = 20  # along the length, closer together at the ends
ARCH = 12  # segments over the upper's cross-section: the collar's rim is at 3 and 9, what it dips into is 4 to 8
ROUND = (3.4, 3.0)  # superellipse exponents of the heel and toe ends: a blunt, chunky toe
SQUARE = 2.6  # ... and of the upper's cross-section
# Profiles along the length (0 at the heel, 1 at the toe): half-width of the sole, sole thickness, height of the
# upper above the sole.
WIDTH = [(0.0, 0.039), (0.15, 0.0385), (0.4, 0.035), (0.55, 0.0445), (0.7, 0.0525), (0.88, 0.0525), (1.0, 0.052)]
SOLE = [(0.0, 0.042), (0.5, 0.038), (1.0, 0.032)]
UPPER = [(0.0, 0.066), (0.08, 0.07), (0.25, 0.064), (0.45, 0.06), (0.6, 0.074), (0.75, 0.07), (0.9, 0.062), (0.97, 0.05), (1.0, 0.038)]
RINGS = [(0.93, 0.0), (1.0, 0.2), (1.0, 0.8), (0.99, 0.95), (0.93, 1.0)]  # sole: scale of the outline, share of the thickness; the last two are the ledge the upper stands in from
LEATHER, LINING, RUBBER = 0, 1, 2


# --- geometry -------------------------------------------------------------------------------------------

def curve(points: list, s: float) -> float:
    """Cubic Hermite through (s, value) points, the tangents taken from the neighbours."""
    n = len(points)
    k = 0
    while k < n - 2 and s > points[k + 1][0]:
        k += 1

    def slope(i: int) -> float:
        a, b = points[max(i - 1, 0)], points[min(i + 1, n - 1)]
        return (b[1] - a[1]) / (b[0] - a[0])

    (s0, y0), (s1, y1) = points[k], points[k + 1]
    h = s1 - s0
    t = (s - s0) / h
    return ((2 * t**3 - 3 * t**2 + 1) * y0 + (t**3 - 2 * t**2 + t) * h * slope(k)
            + (-2 * t**3 + 3 * t**2) * y1 + (t**3 - t**2) * h * slope(k + 1))


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def half_width(s: float) -> float:
    """The sole's half-width: its profile, rounded off at the heel and the toe."""
    e = ROUND[s > 0.5]
    return curve(WIDTH, s) * (1 - abs(2 * s - 1) ** e) ** (1 / e)


def opening(s: float) -> float:
    """1 where the collar is open, 0 at the back of the heel and from the throat on, where the upper is closed."""
    return smooth((s - 0.04) / 0.05) * (1 - smooth((s - 0.55) / 0.07))


def power(x: float, e: float) -> float:
    return math.copysign(abs(x) ** e, x)


def shoe(bm: bmesh.types.BMesh, side: int, yaw: float, slide: float) -> None:
    """One shoe, side +1 or -1 (its outer edge towards that side of the pair), turned by yaw about its own
    centre and slid along Y."""
    stations = [0.5 - 0.5 * math.cos(math.pi * (i + 0.5) / STATIONS) for i in range(STATIONS)]
    turn = math.cos(yaw), math.sin(yaw)

    def vert(x: float, y: float, z: float) -> bmesh.types.BMVert:
        """x, y, z in the shoe's frame (outer side +x, toe -y)."""
        x *= side
        return bm.verts.new((side * APART / 2 + x * turn[0] - y * turn[1], slide + x * turn[1] + y * turn[0], z))

    def face(verts: list, material: int) -> bmesh.types.BMFace:
        f = bm.faces.new(verts if side > 0 else verts[::-1])
        f.material_index = material
        f.smooth = True
        return f

    # The sole: an outline of a left chain and a right chain of station points, at four heights.
    rings = []
    for scale, share in RINGS:
        ring = []
        for sign in (-1, 1):
            for i in (range(STATIONS) if sign < 0 else reversed(range(STATIONS))):
                s = stations[i]
                y = (0.5 - s) * LENGTH * scale
                z = curve(SOLE, s) * share + 0.009 * (max(s - 0.78, 0.0) / 0.22) ** 2  # the toe springs up
                if share < 0.5 and sign > 0:  # worn down on the outer heel
                    z += 0.005 * (1 - smooth(s / 0.3)) * (1 - 2 * share)
                ring.append(vert(sign * half_width(s) * scale, y, z))
        rings.append(ring)
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            face([a[i], a[j], b[j], b[i]], RUBBER)
    top = rings[-1]  # left chain 0..STATIONS-1, then the right chain back from the toe

    # The upper: an arch from the sole's top ring at each station.
    arches = []
    for i, s in enumerate(stations):
        left, right = top[i], top[n - 1 - i]
        z0, y = left.co.z, (0.5 - s) * LENGTH * RINGS[-1][0]
        width, height = half_width(s) * RINGS[-1][0], curve(UPPER, s)
        pts = []
        for j in range(ARCH + 1):
            phi = math.pi * j / ARCH
            pts.append((-width * power(math.cos(phi), 2 / SQUARE), z0 + height * math.sin(phi) ** (2 / SQUARE)))
        (x3, z3), foot = pts[3], z0 + 0.004
        flat = 1 - smooth(s / 0.1)  # round the back of the heel the top is level with the rim, not a dome
        for j in range(4, 9):
            pts[j] = (pts[j][0], pts[j][1] + (z3 + 0.003 - pts[j][1]) * flat)
        o = opening(s)
        if o > 0:  # the collar: its rim stays, what is inside dips to the footbed
            inside = [(0.9 * x3, z3 - 0.005), (0.62 * x3, foot + 0.12 * (z3 - foot)), (0.0, foot)]
            inside += [(-x, z) for x, z in reversed(inside[:2])]
            for j, p in zip(range(4, 9), inside):
                pts[j] = (pts[j][0] + (p[0] - pts[j][0]) * o, pts[j][1] + (p[1] - pts[j][1]) * o)
        arches.append(([left] + [vert(x, y, z) for x, z in pts[1:-1]] + [right], o))
    for (a, oa), (b, ob) in zip(arches, arches[1:]):
        for j in range(ARCH):
            lining = 4 <= j <= 7 and (oa + ob) / 2 > 0.45
            face([a[j], b[j], b[j + 1], a[j + 1]], LINING if lining else LEATHER)
    face(arches[0][0], LEATHER)  # the back of the heel, facing +Y
    face(arches[-1][0][::-1], LEATHER)  # the toe cap, facing -Y


# --- materials ------------------------------------------------------------------------------------------

def leather() -> bpy.types.Material:
    """Black work-shoe leather, matte and dirty: floor dust splashed up from the sole, scuffed grey at the toes,
    creased across the toe flex, and a few small slick patches of grease."""
    mat, nt, bsdf, coords = common.surface("leather")
    xyz = common.node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords})
    toe = common.mapped(nt, xyz.outputs["Y"], 0.0, -0.13, 0.0, 1.0)  # 0 at the middle of the shoe, 1 at the toe
    scuff = common.maths(nt, "MULTIPLY", common.mapped(nt, common.noise(nt, coords, 18.0, 8.0), 0.5, 0.7, 0.0, 1.0), common.mapped(nt, toe, 0.0, 1.0, 0.25, 1.0))
    splash = common.maths(nt, "MULTIPLY", common.mapped(nt, xyz.outputs["Z"], 0.075, 0.04, 0.0, 1.0), common.mapped(nt, common.noise(nt, coords, 10.0, 5.0), 0.4, 0.65, 0.3, 1.0))
    dust = common.maths(nt, "MAXIMUM", common.maths(nt, "MULTIPLY", splash, 0.8), common.mapped(nt, common.noise(nt, coords, 5.0, 4.0), 0.55, 0.7, 0.0, 0.5))
    colour = common.lerp(nt, (0.008, 0.008, 0.008), (0.1, 0.09, 0.08), dust)  # black, dusty grey-brown
    nt.links.new(common.lerp(nt, colour, (0.12, 0.115, 0.11), scuff), bsdf.inputs["Base Color"])
    slick = common.mapped(nt, common.noise(nt, coords, 30.0, 3.0), 0.6, 0.68, 0.0, 1.0)  # small wet patches
    dull = common.maths(nt, "ADD", 0.7, common.maths(nt, "MULTIPLY", dust, 0.15))
    nt.links.new(common.maths(nt, "MAXIMUM", common.maths(nt, "SUBTRACT", dull, common.maths(nt, "MULTIPLY", slick, 0.6)), 0.1), bsdf.inputs["Roughness"])
    flex = common.mapped(nt, xyz.outputs["Y"], -0.045, -0.1, 0.0, 1.0)  # creases between the ball and the toe
    wave = common.node(nt, "ShaderNodeTexWave", {"Vector": coords, "Scale": 13.0, "Distortion": 6.0, "Detail": 1.0}, bands_direction="Y").outputs["Factor"]
    height = common.maths(nt, "MULTIPLY", wave, flex)
    nt.links.new(common.node(nt, "ShaderNodeBump", {"Strength": 0.6, "Distance": 0.002, "Height": height}).outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def lining() -> bpy.types.Material:
    mat = bpy.data.materials.new("lining")
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.016, 0.015, 0.014, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def rubber() -> bpy.types.Material:
    """Dull worn grey-brown rubber, ribbed round the side, the grooves black with grime: paler than the leather."""
    mat, nt, bsdf, coords = common.surface("rubber")
    ribs = common.node(nt, "ShaderNodeTexWave", {"Vector": coords, "Scale": 60.0, "Distortion": 1.5, "Detail": 1.0}, bands_direction="Z", wave_profile="SAW").outputs["Factor"]
    ridge = common.mapped(nt, ribs, 0.25, 0.55, 0.0, 1.0)  # 0 in a groove, 1 on a ridge
    paler = common.mapped(nt, common.noise(nt, coords, 25.0), 0.4, 0.7, 0.0, 1.0)  # worn unevenly
    top = common.lerp(nt, (0.25, 0.22, 0.185), (0.38, 0.34, 0.285), paler)
    nt.links.new(common.lerp(nt, (0.05, 0.046, 0.04), top, ridge), bsdf.inputs["Base Color"])
    nt.links.new(common.mapped(nt, common.noise(nt, coords, 9.0, 4.0), 0.4, 0.65, 0.7, 0.92), bsdf.inputs["Roughness"])
    nt.links.new(common.node(nt, "ShaderNodeBump", {"Strength": 1.0, "Distance": 0.0015, "Height": ribs}).outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
bm = bmesh.new()
shoe(bm, 1, math.radians(-1.5), 0.004)
shoe(bm, -1, math.radians(2.5), -0.005)
me = bpy.data.meshes.new("WorkShoes")
bm.to_mesh(me)
bm.free()
for m in (leather(), lining(), rubber()):
    me.materials.append(m)
pair = bpy.data.objects.new("WorkShoes", me)
bpy.context.scene.collection.objects.link(pair)
me.set_sharp_from_angle(angle=math.radians(55))
common.bake(pair, 256)  # about a millimetre a texel, as fine as the screen shows
common.export("work_shoes", [pair])

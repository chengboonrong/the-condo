"""The bedroom's bed: a cheap dark-wood queen frame, 1.8 m wide and 2.0 m long (the base's footprint), with a plank
headboard 1.86 m wide and 0.96 m tall at the head. On it, as part of the model: a mattress in a white fitted sheet,
yellowed where someone sleeps and sagged there, creased out from the hip; two pillows, the sleeper's still dented; a
bantal peluk (the long bolster) hugged against the wall side; and a blue quilted blanket kicked down to the foot, its
end and its open side hanging over the edge. Run by tools/models.sh.

The origin is the floor below the middle of the frame. The foot end is at -Y, like every model's front, and the head
at +Y; the sleeper's side, the open one, is -X. B-11-07's copy is the same model, turned round and greyed by the game.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils import noise as perlin

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

node, mapped, maths, lerp, noise = common.node, common.mapped, common.maths, common.lerp, common.noise

WIDTH, LENGTH = 1.8, 2.0  # the frame, outside
RAIL = (0.12, 0.34)  # the side rails: from, to
RAIL_T = 0.045
POST = 0.07
HEAD = 0.96  # the headboard's height
HX, HY, ROUND = 0.85, 0.95, 0.05  # the mattress: half width, half length, the roundover of its top edges
TOP = 0.555  # the mattress's top, where nobody lies
SLEEP = (-0.33, 0.12)  # where the sleeper lies: the sag and the creases centre here
DENT = [(-0.38, 0.69), (0.18, 0.67)]  # the two pillows' centres, on the sheet
CLEAR = 0.04  # the blanket's top lies this far above the sheet
FRAME_Y, FRAME_X, FRAME_Z, SHEET, PILLOW, BOLSTER, BLANKET = range(7)  # material indices

perlin.seed_set(1307)


# --- the shapes -----------------------------------------------------------------------------------------

def fbm(x: float, y: float, seed: float = 0.0, octaves: int = 3) -> float:
    """Soft noise in -1..1, finer octaves fainter."""
    total = norm = 0.0
    amp, freq = 1.0, 1.0
    for _ in range(octaves):
        total += amp * perlin.noise(Vector((x * freq + seed, y * freq - seed * 0.7, seed * 0.37)))
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


def band(v: float, lo: float, hi: float, soft: float) -> float:
    """About 1 between lo and hi, falling to 0 over soft either side."""
    return 0.5 * (math.tanh((v - lo) / soft) - math.tanh((v - hi) / soft))


def sheet_top(x: float, y: float) -> float:
    """Where the mattress's top is under the sheet: sagged where someone sleeps, creased out from the hip."""
    dx, dy = x - SLEEP[0], y - SLEEP[1]
    body = math.exp(-(dx / 0.30) ** 2) * band(y, -0.55, 0.75, 0.15)
    hip = math.exp(-((dx / 0.2) ** 2 + (dy / 0.22) ** 2))
    r = math.hypot(dx, dy) + 1e-6
    creases = perlin.noise(Vector((dx / r * 1.7, dy / r * 1.7, r * 1.3)))
    wrinkles = 1 - abs(fbm(x * 2.6, y * 2.6, 11.0, 2) * 1.6)  # ridged noise: long creases in the cloth
    return TOP - 0.036 * body - 0.012 * hip + 0.012 * creases * math.exp(-r / 0.9) + 0.005 * fbm(x * 2.2, y * 2.2, 5.0) + 0.007 * wrinkles * (0.4 + 0.6 * body)


def wrap(a: float, radius: float) -> tuple:
    """Cloth lying over a rounded edge: how far out, and how far down, it has gone when a metres of it are past where the
    edge starts to turn."""
    quarter = math.pi * radius / 2
    if a <= quarter:
        t = a / radius
        return radius * math.sin(t), radius * (1 - math.cos(t))
    return radius, radius + (a - quarter)


def cloth_uv(bm: bmesh.types.BMesh) -> bmesh.types.BMLayerItem:
    """The "cloth" map the soft materials read: metres across the blanket and the bolster, 0..1 across a pillow."""
    return bm.loops.layers.uv.get("cloth") or bm.loops.layers.uv.new("cloth")


def quads(bm: bmesh.types.BMesh, rows: list, material: int, uvs: dict | None = None, reverse: bool = False) -> None:
    """Smooth faces over a grid of vertices. Rows go towards +Y and columns towards +X, so the normals point up where the
    surface lies flat. uvs: vertex -> (u, v) for the "cloth" map. The vertices are the caller's: a seam is two of them."""
    layer = cloth_uv(bm)
    made = []
    for a, b in zip(rows, rows[1:]):
        for i in range(len(a) - 1):
            quad = [a[i], a[i + 1], b[i + 1], b[i]]
            made.append(bm.faces.new(quad[::-1] if reverse else quad))
            made[-1].material_index = material
            made[-1].smooth = True
            if uvs:
                for loop in made[-1].loops:
                    loop[layer].uv = uvs[loop.vert]
    assert facing(made[(len(rows) // 2 - 1) * (len(rows[0]) - 1) + len(rows[0]) // 2], Vector((0, 0, -1 if reverse else 1))), "a grid of faces points the wrong way"  # near its middle it lies flat


def facing(f: bmesh.types.BMFace, towards: Vector) -> bool:
    f.normal_update()
    return f.normal.dot(towards) > 0


def mattress(bm: bmesh.types.BMesh) -> None:
    """The mattress in its fitted sheet: the top (sagged and creased), the rounded edges, the sides down to the rails."""
    def profile(half: float) -> list:  # one side of the outline along an axis: (position, drop below the top); drop None: the side's foot
        side = [(-half, None), (-half, ROUND)] + [(-(half - ROUND) - ROUND * math.sin(a), ROUND * (1 - math.cos(a))) for a in (math.radians(55), math.radians(25))]
        return side + [(-(half - ROUND), 0.0)]

    def axis(half: float, n: int) -> list:
        side = profile(half)
        inner = [(-(half - ROUND) + 2 * (half - ROUND) * i / n, 0.0) for i in range(1, n)]
        return side + inner + [(-x, d) for x, d in reversed(side)]

    rows = []
    for y, dy in axis(HY, 20):
        row = []
        for x, dx in axis(HX, 18):
            if dx is None or dy is None:
                z = RAIL[1]
            else:
                z = sheet_top(max(-(HX - ROUND), min(HX - ROUND, x)), max(-(HY - ROUND), min(HY - ROUND, y))) - math.hypot(dx, dy)
            row.append(bm.verts.new((x, y, max(z, RAIL[1]))))
        rows.append(row)
    quads(bm, rows, SHEET)


def pillow(bm: bmesh.types.BMesh, centre: tuple, yaw: float, tilt: float, size: tuple, height: float, dent: float, seed: float) -> None:
    """A pillow in its case: puffy and pinched at the corners, the middle pressed in by dent (0..1), its base on the sheet
    at centre and its head end leaning up by tilt against the headboard."""
    nu, nv = 14, 12
    turn = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(tilt, 3, "X")
    for top in (True, False):
        rows, uvs = [], {}
        for j in range(nv + 1):
            row = []
            v = -1 + 2 * j / nv
            for i in range(nu + 1):
                u = -1 + 2 * i / nu
                g = ((1 - abs(u) ** 2.4) * (1 - abs(v) ** 2.4)) ** 0.6 * (1 + 0.2 * fbm(u * 2 + seed, v * 2, seed))
                z = height * g * (1 - dent * math.exp(-((u / 0.45) ** 2 + (v / 0.5) ** 2))) if top else -0.08 * height * g
                vert = bm.verts.new(Vector(centre) + turn @ Vector((u * size[0] / 2, v * size[1] / 2, z)))
                uvs[vert] = (u * 0.5 + 0.5, v * 0.5 + 0.5)
                row.append(vert)
            rows.append(row)
        quads(bm, rows, PILLOW, uvs, reverse=not top)


def bolster(bm: bmesh.types.BMesh, y0: float, y1: float, x: float) -> None:
    """The bantal peluk: a long bolster in a printed cover, gathered and tied at each end, bowed and a little flat on its
    underside where it lies on the sheet."""
    length, sides = y1 - y0, 16
    layer = cloth_uv(bm)
    rings = []
    for t in [0.0, 0.012, 0.03, 0.065, 0.12, 0.22, 0.36, 0.5, 0.64, 0.78, 0.88, 0.935, 0.97, 0.988, 1.0]:
        pinch = 0.07 + 0.93 * math.sin(math.pi / 2 * min(1.0, min(t, 1 - t) * length / 0.075)) ** 0.8  # gathered at the ends
        cx, cy = x + 0.035 * math.sin(math.pi * t) + 0.02 * (t - 0.5), y0 + length * t
        cz = sheet_top(cx, cy) + 0.08
        ring = []
        for k in range(sides + 1):  # the last repeats the first: the cover's seam
            th = math.tau * k / sides
            wob = 1 + 0.035 * math.sin(3 * th + 7 * t) + 0.03 * fbm(th * 1.3, t * 5.0, 4.0)
            flat = 0.9 if math.sin(th) < 0 else 1.0
            ring.append((bm.verts.new((cx + 0.1 * pinch * wob * math.cos(th), cy, cz + 0.088 * pinch * wob * flat * math.sin(th))), (0.62 * k / sides, length * t)))
        rings.append(ring)
    faces = []
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            faces.append(bm.faces.new([a[k][0], b[k][0], b[k + 1][0], a[k + 1][0]]))
            for loop, p in zip(faces[-1].loops, (a[k], b[k], b[k + 1], a[k + 1])):
                loop[layer].uv = p[1]
    for ring, reverse in ((rings[0], False), (rings[-1], True)):  # the ends, closed
        pts = [p[0] for p in ring[:-1]]
        faces.append(bm.faces.new(pts[::-1] if reverse else pts))
        for loop in faces[-1].loops:
            loop[layer].uv = (0.0, 0.0)
    for f in faces:
        f.material_index, f.smooth = BOLSTER, True
    assert facing(faces[sides * 7 + 4], Vector((0, 0, 1))), "the bolster's faces point inwards"  # k = 4 is the top, half way along


def blanket(bm: bmesh.types.BMesh) -> None:
    """The blue blanket, thick and quilted, kicked down: its head edge slanting and rucked, a heap where the feet were, its
    end hanging over the foot and a hem over the open side. A rim and a lower face where it hangs free."""
    ex, ey, radius = HX - ROUND, HY - ROUND, ROUND + CLEAR  # where the mattress's top starts to turn; the cloth's own turn
    thick, hang_w, hang_e, hang_f = 0.03, 0.12, 0.04, 0.26

    def head(x: float) -> float:  # the head edge, slanting down towards the wall: the feet kicked it off the open side first
        return -0.02 - 0.22 * x / 0.9 + 0.07 * fbm(x * 3.0, 1.0, 2.0)

    def fold(x: float, y: float) -> float:  # how high the cloth stands above its resting place
        d = head(x) - y
        rucks = (0.5 + 0.5 * math.sin(math.tau * d / 0.3 + 1.6 * fbm(x * 1.8, y * 1.4, 3.0))) ** 1.3
        z = 0.07 * rucks * math.exp(-d / 0.8)
        z += 0.11 * math.exp(-(((x + 0.3) / 0.36) ** 2 + ((y + 0.5) / 0.3) ** 2))  # the wad where the feet kicked it
        z += 0.06 * math.exp(-(((x - 0.45) / 0.25) ** 2 + ((y + 0.65) / 0.2) ** 2))
        z += 0.05 * (0.5 + 0.5 * math.sin(math.tau * (x * 0.55 + y * 0.83 - 0.1) / 0.42 + 2.0 * fbm(x, y, 6.0))) * math.exp(-(((x - 0.1) / 0.6) ** 2 + ((y + 0.2) / 0.5) ** 2))
        return z + 0.014 * (fbm(x * 3.5, y * 3.5, 9.0) + 1)

    # Across, west hem to east hem: (x where the flat top's edge is, which side, cloth hanging past it).
    across = [(-ex, -1, hang_w * (1 - k / 5)) for k in range(5)] + [(-ex + 2 * ex * k / 30, 0, 0.0) for k in range(31)] + [(ex, 1, hang_e * k / 2) for k in (1, 2)]
    down = [hang_f * (1 - k / 6) for k in range(6)]  # along, foot hem first: cloth hanging past the foot edge
    flat_rows = 14
    layer = cloth_uv(bm)
    top, uvs, hangs = [], {}, []
    for j in range(len(down) + flat_rows + 1):
        row, hang_row = [], []
        for x, side, a in across:
            if j < len(down):  # the hem hangs lower towards the open side, where the feet pushed it off
                af = down[j] * (0.72 - 0.35 * x / 0.8 + 0.12 * fbm(x * 2.0, 3.0, 5.0))
                out_y, drop_y = wrap(af, radius)
                yf = -ey
                y = yf - out_y - 0.012 * math.sin(math.tau * x / 0.26 + 0.6) * af / hang_f
                v = hang_f - af
            else:
                af, drop_y = 0.0, 0.0
                yf = -ey + (head(x) + ey) * (j - len(down)) / flat_rows
                y, v = yf, hang_f + yf + ey
            if side:
                a *= 0.35 + 0.65 * max(0.0, min(1.0, (0.15 - yf) / 1.0))
            out_x, drop_x = wrap(a, radius) if side else (0.0, 0.0)
            px = x + side * (out_x + 0.012 * math.sin(math.tau * yf / 0.3 + 1.0) * a / (hang_w if side < 0 else hang_e))
            z = sheet_top(max(-ex, min(ex, x)), max(-ey, min(ey, yf))) + fold(x, yf) + CLEAR - math.hypot(drop_x, drop_y)
            vert = bm.verts.new((px, y, z))
            uvs[vert] = ((hang_w - a) if side < 0 else (hang_w + 2 * ex + a) if side > 0 else (hang_w + x + ex), v)
            row.append(vert)
            hang_row.append(a > 0 or af > 0)
        top.append(row)
        hangs.append(hang_row)
    quads(bm, top, BLANKET, uvs)

    last_i, last_j = len(top) - 1, len(top[0]) - 1

    def outward(i: int, j: int) -> Vector:  # the top's normal there, from its neighbours
        a, b = top[max(i - 1, 0)][j].co, top[min(i + 1, last_i)][j].co
        c, d = top[i][max(j - 1, 0)].co, top[i][min(j + 1, last_j)].co
        return (d - c).cross(b - a).normalized()

    under = [[bm.verts.new(v.co - outward(i, j) * thick) for j, v in enumerate(row)] for i, row in enumerate(top)]
    for i, row in enumerate(under):
        for j, v in enumerate(row):
            uvs[v] = uvs[top[i][j]]
    faces, wrong = [], 0
    for i in range(last_i):
        for j in range(last_j):
            if hangs[i][j] or hangs[i + 1][j] or hangs[i][j + 1] or hangs[i + 1][j + 1]:  # the lower face, where it hangs free
                faces.append(bm.faces.new([under[i][j], under[i][j + 1], under[i + 1][j + 1], under[i + 1][j]][::-1]))
                wrong += facing(faces[-1], outward(i, j))  # the corner's sliver of a quad may fold over: only most must face inwards
    assert wrong < len(faces) / 50, "the blanket's lower faces point outwards"
    centre = sum((v.co for row in top for v in row), Vector()) / ((last_i + 1) * (last_j + 1))
    rim = [((0, j), (0, j + 1)) for j in range(last_j)] + [((last_i, j), (last_i, j + 1)) for j in range(last_j)]
    rim += [((i, 0), (i + 1, 0)) for i in range(last_i)] + [((i, last_j), (i + 1, last_j)) for i in range(last_i)]
    for (i0, j0), (i1, j1) in rim:
        f = bm.faces.new([top[i0][j0], top[i1][j1], under[i1][j1], under[i0][j0]])
        if not facing(f, f.calc_center_median() - centre):
            f.normal_flip()
        faces.append(f)
    for f in faces:
        f.material_index, f.smooth = BLANKET, True
        for loop in f.loops:
            loop[layer].uv = uvs[loop.vert]


def frame(bm: bmesh.types.BMesh) -> None:
    """The dark wooden frame and its plank headboard. The foot's legs are short blocks; the headboard's posts run up past
    the frame's width."""
    mid, y_head = (RAIL[0] + RAIL[1]) / 2, LENGTH / 2 - 0.0475  # the headboard's posts start here
    for sx in (-1, 1):
        common.box(bm, (sx * (WIDTH / 2 - RAIL_T / 2), (-LENGTH / 2 + POST + y_head) / 2, mid), (RAIL_T, y_head + LENGTH / 2 - POST, RAIL[1] - RAIL[0]), FRAME_Y)
        common.box(bm, (sx * (WIDTH / 2 - POST / 2), -LENGTH / 2 + POST / 2, RAIL[1] / 2), (POST, POST, RAIL[1]), FRAME_Z)
        common.box(bm, (sx * (WIDTH / 2 + 0.03 - POST / 2), LENGTH / 2 - 0.005, HEAD / 2), (POST, 0.085, HEAD), FRAME_Z)
    inner = WIDTH + 0.06 - 2 * POST
    common.box(bm, (0.0, -LENGTH / 2 + RAIL_T / 2, mid), (WIDTH - 2 * POST, RAIL_T, RAIL[1] - RAIL[0]), FRAME_X)
    common.box(bm, (0.0, LENGTH / 2 - RAIL_T / 2, mid), (inner, RAIL_T, RAIL[1] - RAIL[0]), FRAME_X)
    common.box(bm, (0.0, LENGTH / 2, (RAIL[1] + 0.86) / 2), (inner, 0.04, 0.86 - RAIL[1]), FRAME_X)  # the planks
    common.chamfered_box(bm, (0.0, LENGTH / 2 - 0.005, HEAD - 0.05), (inner, 0.085, 0.1), 0.006, FRAME_X)  # and the top rail


# --- materials ------------------------------------------------------------------------------------------

def cloth_coords(nt: bpy.types.NodeTree) -> tuple:
    """The "cloth" map's u and v."""
    uv = node(nt, "ShaderNodeSeparateXYZ", {"Vector": node(nt, "ShaderNodeUVMap", uv_map="cloth").outputs["UV"]}).outputs
    return uv["X"], uv["Y"]


def creases(nt: bpy.types.NodeTree, coords: bpy.types.NodeSocket, centre: tuple, reach: float) -> tuple:
    """Crease lines (0..1), wandering out from centre (x, y) and fading over reach metres, and the distance from it."""
    d = node(nt, "ShaderNodeVectorMath", {0: coords, 1: (centre[0], centre[1], 0.0)}, operation="SUBTRACT").outputs["Vector"]
    parts = node(nt, "ShaderNodeSeparateXYZ", {"Vector": d}).outputs
    flat = node(nt, "ShaderNodeCombineXYZ", {"X": parts["X"], "Y": parts["Y"]}).outputs["Vector"]
    r = maths(nt, "MAXIMUM", node(nt, "ShaderNodeVectorMath", {0: flat}, operation="LENGTH").outputs["Value"], 0.001)
    warp = maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", noise(nt, coords, 3.0, 2.0), 0.5), 1.6)  # so the lines wander, not spoke
    spokes = node(nt, "ShaderNodeCombineXYZ", {"X": maths(nt, "ADD", maths(nt, "MULTIPLY", maths(nt, "DIVIDE", parts["X"], r), 1.5), warp),
                  "Y": maths(nt, "ADD", maths(nt, "MULTIPLY", maths(nt, "DIVIDE", parts["Y"], r), 1.5), warp), "Z": maths(nt, "MULTIPLY", r, 1.4)}).outputs["Vector"]
    line = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", noise(nt, spokes, 1.0, 2.0), 0.5)), 0.05, 0.0, 0.0, 1.0)
    return maths(nt, "MULTIPLY", line, mapped(nt, r, 0.12, reach, 1.0, 0.2)), r


def finish(nt, bsdf, colour, rough, height=None, strength=0.3, distance=0.004, ao=0.05) -> None:
    """Darkens the creases (ambient occlusion, baked into the colour), then wires the surface up."""
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": ao}, samples=32, only_local=True).outputs["AO"]
    nt.links.new(lerp(nt, (0.0, 0.0, 0.0), colour, mapped(nt, dark, 0.0, 0.85, 0.45, 1.0)), bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    if height is not None:
        nt.links.new(node(nt, "ShaderNodeBump", {"Strength": strength, "Distance": distance, "Height": height}).outputs["Normal"], bsdf.inputs["Normal"])


def timber(name: str, axis: int) -> bpy.types.Material:
    """Dark stained wood, the grain along axis (0 X, 1 Y, 2 Z). Worn through the varnish only where use would wear it:
    pale along the edges, scuffed near the floor, rubbed along the headboard's top rail where hands rest; greasy where
    heads lean on the headboard; dusty on every upward face."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    bevelled = node(nt, "ShaderNodeBevel", {"Radius": 0.003}, samples=16).outputs["Normal"]
    normal = node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs
    grain = common.grain(nt, coords, axis)
    varnished = lerp(nt, (0.065, 0.027, 0.012), (0.12, 0.052, 0.024), grain)
    bare = lerp(nt, (0.22, 0.165, 0.115), (0.33, 0.255, 0.18), grain)  # greyish tan, as the front door's
    up = mapped(nt, normal["Z"], 0.5, 0.95, 0.0, 1.0)
    breakup = mapped(nt, noise(nt, coords, 12.0, 3.0), 0.3, 0.7, 0.35, 1.0)
    edge = maths(nt, "MULTIPLY", mapped(nt, node(nt, "ShaderNodeVectorMath", {0: bevelled, 1: flat}, operation="DOT_PRODUCT").outputs["Value"], 1.0, 0.8, 0.0, 1.0), breakup)
    scuff = maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], 0.1, 0.0, 0.0, 1.0), mapped(nt, noise(nt, coords, 35.0, 3.0), 0.35, 0.6, 0.3, 1.0))
    hands = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], 0.935, 0.955, 0.0, 1.0), up), mapped(nt, noise(nt, node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": (3.0, 30.0, 30.0)}).outputs["Vector"], 1.0, 3.0), 0.35, 0.65, 0.2, 1.0))
    worn = maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", maths(nt, "MULTIPLY", edge, 0.85), maths(nt, "MULTIPLY", scuff, 0.8)), maths(nt, "MULTIPLY", hands, 0.7))
    colour = lerp(nt, varnished, bare, worn)
    # Hair oil on the headboard's face where the pillows lean: darker, glossier.
    head = maths(nt, "MULTIPLY", mapped(nt, node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": maths(nt, "DIVIDE", maths(nt, "SUBTRACT", xyz["X"], DENT[0][0]), 0.3), "Y": maths(nt, "DIVIDE", maths(nt, "SUBTRACT", xyz["Z"], 0.6), 0.2)}).outputs["Vector"]}, operation="LENGTH").outputs["Value"], 1.0, 0.2, 0.0, 0.6),
                 mapped(nt, noise(nt, coords, 6.0, 3.0), 0.3, 0.7, 0.4, 1.0))
    colour = lerp(nt, colour, (0.02, 0.009, 0.004), head)
    grime = maths(nt, "MULTIPLY", up, mapped(nt, noise(nt, coords, 3.5, 3.0), 0.45, 0.75, 0.0, 0.5))
    colour = lerp(nt, colour, (0.04, 0.034, 0.028), grime)
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.05}, samples=32, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.02, 0.01, 0.005), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    rough = maths(nt, "MAXIMUM", mapped(nt, worn, 0.0, 1.0, 0.38, 0.85), maths(nt, "MULTIPLY", grime, 1.4))
    rough = maths(nt, "MINIMUM", maths(nt, "SUBTRACT", rough, maths(nt, "MULTIPLY", head, 0.2)), 1.0)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    nt.links.new(bevelled, bsdf.inputs["Normal"])
    return mat


def sheet_material() -> bpy.types.Material:
    """White cotton gone a little grey, yellowed where the sleeper lies, creased out from the hip, dirtier down the
    sides."""
    mat, nt, bsdf, coords = common.surface("sheet")
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    lines, _ = creases(nt, coords, SLEEP, 1.4)
    tone = mapped(nt, noise(nt, coords, 2.5, 3.0), 0.3, 0.7, 0.0, 1.0)
    colour = lerp(nt, (0.55, 0.55, 0.52), (0.64, 0.63, 0.6), tone)
    across = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", xyz["X"], SLEEP[0])), 0.45, 0.1, 0.0, 1.0)
    along = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", xyz["Y"], 0.15)), 0.8, 0.3, 0.0, 1.0)
    body = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", across, mapped(nt, noise(nt, coords, 4.0, 3.0), 0.35, 0.65, 0.3, 1.0)), along)
    colour = lerp(nt, colour, (0.48, 0.41, 0.27), maths(nt, "MULTIPLY", body, 0.4))
    colour = lerp(nt, colour, (0.4, 0.39, 0.37), maths(nt, "MULTIPLY", lines, 0.4))
    sides = maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], 0.5, 0.36, 0.0, 1.0), mapped(nt, noise(nt, coords, 8.0, 3.0), 0.3, 0.7, 0.2, 0.8))
    colour = lerp(nt, colour, (0.3, 0.28, 0.25), sides)
    height = maths(nt, "ADD", lines, maths(nt, "MULTIPLY", noise(nt, coords, 9.0, 3.0), 0.6))
    finish(nt, bsdf, colour, maths(nt, "ADD", 0.86, maths(nt, "MULTIPLY", tone, 0.1)), height, 0.3)
    return mat


def pillow_material() -> bpy.types.Material:
    """Pillowcases gone ivory, the sleeper's stained where the head lies, both creased round their dents and stitched
    round the edge."""
    mat, nt, bsdf, coords = common.surface("pillow")
    u, v = cloth_coords(nt)
    inset = maths(nt, "MINIMUM", maths(nt, "MINIMUM", u, maths(nt, "SUBTRACT", 1.0, u)), maths(nt, "MINIMUM", v, maths(nt, "SUBTRACT", 1.0, v)))
    stitch = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", inset, 0.05)), 0.012, 0.0, 0.0, 1.0)
    (head, r), (other, _) = creases(nt, coords, DENT[0], 0.5), creases(nt, coords, DENT[1], 0.5)
    lines = maths(nt, "MAXIMUM", head, other)
    tone = mapped(nt, noise(nt, coords, 5.0, 3.0), 0.3, 0.7, 0.0, 1.0)
    colour = lerp(nt, (0.55, 0.54, 0.5), (0.65, 0.64, 0.58), tone)
    stain = maths(nt, "MULTIPLY", mapped(nt, r, 0.17, 0.04, 0.0, 1.0), mapped(nt, noise(nt, coords, 9.0, 3.0), 0.3, 0.65, 0.3, 1.0))
    colour = lerp(nt, colour, (0.46, 0.37, 0.21), maths(nt, "MULTIPLY", stain, 0.55))
    colour = lerp(nt, colour, (0.4, 0.38, 0.34), maths(nt, "MULTIPLY", lines, 0.3))
    colour = lerp(nt, colour, (0.36, 0.34, 0.3), maths(nt, "MULTIPLY", stitch, 0.4))
    colour = lerp(nt, colour, (0.3, 0.28, 0.24), maths(nt, "MULTIPLY", mapped(nt, inset, 0.012, 0.0, 0.0, 1.0), 0.5))
    height = maths(nt, "ADD", maths(nt, "ADD", lines, stitch), maths(nt, "MULTIPLY", noise(nt, coords, 12.0, 3.0), 0.4))
    finish(nt, bsdf, colour, maths(nt, "ADD", 0.88, maths(nt, "MULTIPLY", tone, 0.08)), height, 0.3)
    return mat


def bolster_material() -> bpy.types.Material:
    """A cotton cover printed with faded rose flowers on cream in staggered rows, gathered and tied at both ends,
    grubby where it is hugged."""
    mat, nt, bsdf, coords = common.surface("bolster")
    u, v = cloth_coords(nt)
    cell = 0.1
    row = maths(nt, "FLOOR", maths(nt, "DIVIDE", v, cell))
    across = maths(nt, "SUBTRACT", maths(nt, "FRACT", maths(nt, "ADD", maths(nt, "DIVIDE", u, cell), maths(nt, "MULTIPLY", row, 0.5))), 0.5)
    along = maths(nt, "SUBTRACT", maths(nt, "FRACT", maths(nt, "DIVIDE", v, cell)), 0.5)
    spot = node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": across, "Y": along}).outputs["Vector"]}, operation="LENGTH").outputs["Value"]
    petals = maths(nt, "ADD", 0.3, maths(nt, "MULTIPLY", maths(nt, "COSINE", maths(nt, "MULTIPLY", maths(nt, "ARCTAN2", along, across), 5.0)), 0.06))
    flower = mapped(nt, maths(nt, "SUBTRACT", spot, petals), 0.03, -0.03, 0.0, 1.0)
    heart = mapped(nt, spot, 0.1, 0.06, 0.0, 1.0)
    fade = mapped(nt, noise(nt, coords, 5.0, 3.0), 0.3, 0.7, 0.55, 1.0)
    colour = lerp(nt, (0.6, 0.55, 0.43), (0.68, 0.62, 0.49), mapped(nt, noise(nt, coords, 4.0, 3.0), 0.3, 0.7, 0.0, 1.0))
    colour = lerp(nt, colour, (0.42, 0.2, 0.18), maths(nt, "MULTIPLY", flower, fade))
    colour = lerp(nt, colour, (0.62, 0.52, 0.33), maths(nt, "MULTIPLY", heart, 0.8))
    ends = maths(nt, "MAXIMUM", mapped(nt, v, 0.07, 0.04, 0.0, 1.0), mapped(nt, v, 0.79, 0.82, 0.0, 1.0))
    colour = lerp(nt, colour, (0.26, 0.2, 0.14), maths(nt, "MULTIPLY", ends, 0.6))
    colour = lerp(nt, colour, (0.2, 0.17, 0.13), mapped(nt, noise(nt, coords, 6.0, 3.0), 0.5, 0.75, 0.0, 0.35))
    finish(nt, bsdf, colour, maths(nt, "ADD", 0.86, maths(nt, "MULTIPLY", flower, 0.05)), maths(nt, "MULTIPLY", noise(nt, coords, 14.0, 3.0), 0.5), 0.3)
    return mat


def blanket_material() -> bpy.types.Material:
    """Thick blue polyester, softly quilted in diamonds, faded and pilled where it has been kicked about."""
    mat, nt, bsdf, coords = common.surface("blanket")
    u, v = cloth_coords(nt)
    a = maths(nt, "DIVIDE", maths(nt, "ADD", u, v), 0.13)
    b = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", u, v), 0.13)

    def from_line(t: bpy.types.NodeSocket) -> bpy.types.NodeSocket:  # distance to the nearest whole number, 0..0.5
        return maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", maths(nt, "FRACT", maths(nt, "ADD", t, 0.5)), 0.5))

    quilt = mapped(nt, maths(nt, "MINIMUM", from_line(a), from_line(b)), 0.0, 0.16, 0.0, 1.0)  # 0 on a seam, 1 in a cell's middle
    mottle = mapped(nt, noise(nt, coords, 6.0, 4.0), 0.3, 0.7, 0.0, 1.0)
    colour = lerp(nt, (0.025, 0.065, 0.22), (0.04, 0.09, 0.28), mottle)
    colour = lerp(nt, colour, (0.014, 0.034, 0.13), maths(nt, "MULTIPLY", maths(nt, "SUBTRACT", 1.0, quilt), 0.4))
    colour = lerp(nt, colour, (0.07, 0.1, 0.24), maths(nt, "MULTIPLY", mapped(nt, noise(nt, coords, 3.0, 3.0), 0.5, 0.8, 0.0, 1.0), 0.35))
    colour = lerp(nt, colour, (0.16, 0.19, 0.3), mapped(nt, noise(nt, coords, 140.0, 2.0), 0.7, 0.78, 0.0, 0.2))
    up = mapped(nt, node(nt, "ShaderNodeSeparateXYZ", {"Vector": node(nt, "ShaderNodeNewGeometry").outputs["Normal"]}).outputs["Z"], 0.4, 0.95, 0.0, 1.0)
    colour = lerp(nt, colour, (0.2, 0.2, 0.2), maths(nt, "MULTIPLY", up, mapped(nt, noise(nt, coords, 5.0, 4.0), 0.4, 0.75, 0.0, 0.3)))  # dust, and lint
    height = maths(nt, "ADD", quilt, maths(nt, "MULTIPLY", noise(nt, coords, 40.0, 3.0), 0.2))
    finish(nt, bsdf, colour, maths(nt, "ADD", 0.9, maths(nt, "MULTIPLY", mottle, 0.07)), height, 0.4, 0.006, 0.06)
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
bm = bmesh.new()
frame(bm)
mattress(bm)
pillow(bm, (*DENT[0], sheet_top(*DENT[0]) + 0.035), math.radians(4), math.radians(9), (0.62, 0.41), 0.13, 0.4, 1.0)
pillow(bm, (*DENT[1], sheet_top(*DENT[1]) + 0.035), math.radians(-12), math.radians(11), (0.6, 0.4), 0.14, 0.12, 4.0)
bolster(bm, 0.07, 0.93, 0.62)
blanket(bm)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99 and f.calc_center_median().z < 0.001], context="FACES")  # the feet
me = bpy.data.meshes.new("Bed")
bm.to_mesh(me)
bm.free()
for m in (timber("frame_y", 1), timber("frame_x", 0), timber("frame_z", 2), sheet_material(), pillow_material(), bolster_material(), blanket_material()):
    me.materials.append(m)
bed = bpy.data.objects.new("Bed", me)
bpy.context.scene.collection.objects.link(bed)
common.bake(bed, size=512, pack=True)
common.export("bed", [bed])

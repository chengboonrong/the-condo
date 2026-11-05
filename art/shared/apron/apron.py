"""The player's mamak apron, shared by art/figure (worn) and art/apron_hung (on the laundry rack): one pattern, one
texture, so the two are visibly the same apron.

The pattern is flat cloth in metres: the panel (u across, centred; v up from the hem to the top of the bib), the neck
strap and the two waist ties (each a strip: across, along). Every piece's UV is its pattern position, so any mesh made
from the pattern reads the same texture whatever shape it is given. texture() paints that texture (off-white canvas,
yellowed with washing; tea and oil stains low on the front, a grey band where it leans on the counter, hand-wipes at
the hips, a grubby pocket, a frayed hem and frayed tie ends, a sweat-darkened neck strap) and saves it beside this file.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 512
LENGTH = 0.8  # hem to the top of the bib
WAIST = 0.46  # v of the waist: the ties start here, the bib above it
STRAP_W = 0.025
NECK_LEN, TIE_LEN = 0.56, 0.55
K = 1.15  # UV per metre
PANEL_UV = (0.02, 0.02)  # where the panel's (u = -half width, v = 0) corner sits
STRAPS_UV = {"neck": (0.72, 0.02), "left": (0.8, 0.02), "right": (0.88, 0.02)}  # each strip's (across 0, along 0)
STRAP_LEN = {"neck": NECK_LEN, "left": TIE_LEN, "right": TIE_LEN}


def half_width(v: float) -> float:
    """Half the panel's width at v: an A-line skirt, the bib scooped in under the arms."""
    if v <= WAIST:
        return 0.24 - 0.01 * v / WAIST
    t = min((v - WAIST) / 0.2, 1.0)
    return 0.125 + 0.105 * (1 - t) ** 2


def hem(u: float) -> float:
    """The hem's ragged edge: how far above v = 0 the cloth ends at u (frayed, a thread or two gone in places)."""
    return 0.002 + 0.0025 * math.sin(u * 61.0) * math.sin(u * 23.0 + 1.0) ** 2


# --- the mesh ---------------------------------------------------------------------------------------------

def panel(bm: bmesh.types.BMesh, place, vs: list, columns: int) -> list:
    """The panel as quads: a row of columns + 1 points across it at each v in vs (bottom to top), placed in 3D by
    place(u, v). Returns the rows of vertices."""
    uv = bm.loops.layers.uv.verify()
    rows, coords = [], {}
    for v in vs:
        row = []
        for i in range(columns + 1):
            u = half_width(v) * (2 * i / columns - 1)
            vv = hem(u) if v == vs[0] else v
            vert = bm.verts.new(place(u, vv))
            coords[vert] = (PANEL_UV[0] + (u + half_width(0.0)) * K, PANEL_UV[1] + vv * K)
            row.append(vert)
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for i in range(columns):
            f = bm.faces.new([a[i], a[i + 1], b[i + 1], b[i]])
            f.smooth = True
            for loop in f.loops:
                loop[uv].uv = coords[loop.vert]
    return rows


def strap(bm: bmesh.types.BMesh, which: str, path: list, normals: list, start: float = 0.0) -> None:
    """A strip of the strap or tie named which, laid along path (points, with the cloth's outward normal at each); the
    first point is start metres along it. Its width lies across the path, square to the normal."""
    uv = bm.loops.layers.uv.verify()
    s0, t0 = STRAPS_UV[which]
    pairs, along = [], start
    for i, (p, n) in enumerate(zip(path, normals)):
        if i:
            along += (p - path[i - 1]).length
        tangent = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        side = n.cross(tangent).normalized() * STRAP_W / 2
        pairs.append(((bm.verts.new(p - side), bm.verts.new(p + side)), t0 + along * K))
    for (a, ta), (b, tb) in zip(pairs, pairs[1:]):
        f = bm.faces.new([a[0], a[1], b[1], b[0]])
        f.smooth = True
        for loop, coord in zip(f.loops, [(s0, ta), (s0 + STRAP_W * K, ta), (s0 + STRAP_W * K, tb), (s0, tb)]):
            loop[uv].uv = coord


def material() -> bpy.types.Material:
    """The apron's material, "apron": the texture as its colour, matte canvas, seen from both sides."""
    mat = bpy.data.materials.new("apron")
    mat.use_backface_culling = False
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = texture()
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


# --- the texture --------------------------------------------------------------------------------------------

def _noise(rng: np.random.Generator, u: np.ndarray, v: np.ndarray, scale: float) -> np.ndarray:
    """Smooth value noise in 0..1 over pattern metres (above -4), scale lattice cells per metre."""
    x, y = (u + 4.0) * scale, (v + 4.0) * scale
    grid = rng.random((int(y.max()) + 2, int(x.max()) + 2))
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    top = grid[y0, x0] * (1 - fx) + grid[y0, x0 + 1] * fx
    bottom = grid[y0 + 1, x0] * (1 - fx) + grid[y0 + 1, x0 + 1] * fx
    return top * (1 - fy) + bottom * fy


def _fbm(rng, u, v, scale: float, octaves: int = 3) -> np.ndarray:
    total, norm, amp = 0.0, 0.0, 1.0
    for _ in range(octaves):
        total = total + amp * _noise(rng, u, v, scale)
        norm += amp
        amp *= 0.5
        scale *= 2.0
    return total / norm


def _smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _over(colour: np.ndarray, stain, alpha: np.ndarray) -> np.ndarray:
    """colour with stain laid over it at alpha (0..1 per pixel)."""
    return colour + (np.asarray(stain)[None, None, :] - colour) * np.clip(alpha, 0.0, 1.0)[..., None]


# Stains on the panel. Tea where the teh tarik is pulled and splashes, low and a little to the pouring hand's side:
# (u, v, radius, strength, stretch down). Old soaks that never washed out: (u, v, radius, strength). Oil where it
# meets the stove and the counter: (u, v, radius, strength).
TEA = [(-0.08, 0.2, 0.034, 0.42, 1.6), (0.05, 0.25, 0.026, 0.3, 1.3), (-0.15, 0.09, 0.03, 0.35, 1.0),
       (0.11, 0.08, 0.02, 0.22, 1.8), (-0.02, 0.06, 0.018, 0.28, 1.2)]
SOAK = [(-0.07, 0.15, 0.09, 0.16), (0.09, 0.22, 0.07, 0.12), (-0.16, 0.3, 0.05, 0.1)]
DRIPS = [(-0.085, 0.18, 0.08), (0.052, 0.23, 0.05), (-0.02, 0.05, 0.04)]  # (u, v at the top, length) runs below a splash
OIL = [(0.03, 0.37, 0.035, 0.3), (0.15, 0.3, 0.025, 0.25), (-0.05, 0.41, 0.022, 0.22)]
POCKET = (-0.12, 0.12, 0.12, 0.3)  # u0, v0, u1, v1


def texture() -> bpy.types.Image:
    """Paints the apron's texture, saves it as art/shared/apron/Apron_color.png and returns it."""
    rng = np.random.default_rng(1207)
    t, s = np.meshgrid((np.arange(SIZE) + 0.5) / SIZE, (np.arange(SIZE) + 0.5) / SIZE, indexing="ij")  # Blender rows: bottom first
    u = (s - PANEL_UV[0]) / K - half_width(0.0)
    v = (t - PANEL_UV[1]) / K
    canvas = np.array([0.85, 0.83, 0.77])
    colour = np.broadcast_to(canvas, u.shape + (3,)).copy()
    colour *= (0.96 + 0.08 * _fbm(rng, u, v, 5.0))[..., None]  # washed unevenly
    colour = _over(colour, (0.8, 0.75, 0.62), 0.3 * _smooth(1 - v / 0.5) * _fbm(rng, u, v, 3.0))  # yellowed low down
    blot = _fbm(rng, u, v, 14.0)  # what gives every stain its ragged outline
    patch = _fbm(rng, u, v, 9.0)
    # leaning on the counter, and wiping the hands on the hips
    colour = _over(colour, (0.56, 0.52, 0.44), 0.3 * np.exp(-((v - 0.34) / 0.045) ** 2) * _smooth((0.22 - abs(u)) / 0.08) * (0.5 + patch))
    for side in (-1, 1):
        du, dv = u - side * 0.17, v - 0.3
        dv = dv + 0.6 * du * side  # drawn down and in, the way a hand wipes
        colour = _over(colour, (0.5, 0.46, 0.39), 0.42 * np.exp(-(du / 0.045) ** 2 - (dv / 0.08) ** 2) * (0.4 + patch))
    # the pocket: its seams, a grubby opening and the shade beneath it
    u0, v0, u1, v1 = POCKET
    inside = (u > u0) & (u < u1) & (v > v0) & (v < v1)
    colour = _over(colour, (0.6, 0.56, 0.48), 0.22 * inside * _smooth((v - (v1 - 0.03)) / 0.03))
    seam = np.minimum(np.minimum(abs(u - u0), abs(u - u1)), abs(v - v0))
    colour = _over(colour, (0.55, 0.52, 0.46), 0.5 * inside * np.exp(-(seam / 0.0025) ** 2))
    colour = _over(colour, (0.5, 0.47, 0.41), 0.55 * np.exp(-((v - v1) / 0.0035) ** 2) * ((u > u0) & (u < u1)))
    # tea: old soaks, then splashes, each a pale brown cloud dried darker at its broken edge, with runs below
    fine = _fbm(rng, u, v, 30.0)
    for cu, cv, r, alpha in SOAK:
        d = np.hypot(u - cu, v - cv) / r + 0.8 * (patch - 0.5)
        colour = _over(colour, (0.72, 0.6, 0.45), alpha * _smooth((1 - d) / 0.5))
    for cu, cv, r, alpha, stretch in TEA:
        d = np.hypot(u - cu, np.minimum(v - cv, (v - cv) / stretch)) / r + 0.9 * (blot - 0.5) + 0.4 * (fine - 0.5)
        colour = _over(colour, (0.74, 0.58, 0.4), alpha * _smooth((1 - d) / 0.35))
        colour = _over(colour, (0.62, 0.45, 0.28), 0.7 * alpha * np.exp(-((d - 0.95) / 0.1) ** 2) * _smooth((fine - 0.35) / 0.2))
    for cu, cv, length in DRIPS:
        down = _smooth((cv - v) / 0.01) * _smooth((v - cv + length) / length)
        colour = _over(colour, (0.68, 0.53, 0.36), 0.28 * down * np.exp(-((u - cu - 0.004 * np.sin(v * 90)) / 0.0035) ** 2))
    # oil: a greyed, yellowish soak with no edge to speak of
    for cu, cv, r, alpha in OIL:
        d = np.hypot(u - cu, (v - cv) * 1.3) / r + 0.7 * (blot - 0.5)
        colour = _over(colour, (0.6, 0.58, 0.45), alpha * _smooth((1 - d) / 0.5))
    # the edges: hems stitched in, the bottom one dragged grey and frayed, the top of the bib handled
    side = np.array([half_width(x) for x in np.clip(v[:, 0], 0.0, LENGTH)])[:, None] - abs(u)
    colour = _over(colour, (0.62, 0.59, 0.52), 0.35 * np.exp(-((side - 0.012) / 0.0022) ** 2))
    colour = _over(colour, (0.62, 0.59, 0.52), 0.35 * np.exp(-((v - 0.018) / 0.0022) ** 2))
    colour = _over(colour, (0.5, 0.48, 0.43), 0.5 * _smooth(1 - v / 0.045) * (0.5 + 0.5 * patch))
    colour = _over(colour, (0.42, 0.4, 0.36), 0.6 * _smooth(1 - v / 0.006) * _fbm(rng, u * 8.0, v, 40.0))
    colour = _over(colour, (0.6, 0.57, 0.5), 0.3 * _smooth(1 - (LENGTH - v) / 0.025))
    # the straps
    for which, (s0, t0) in STRAPS_UV.items():
        a = (s - s0) / K  # across, 0..STRAP_W
        along = (t - t0) / K
        cell = (a > -0.004) & (a < STRAP_W + 0.004) & (along > -0.01) & (along < STRAP_LEN[which] + 0.01)
        tone = np.broadcast_to(canvas, u.shape + (3,)) * (0.95 + 0.08 * _fbm(rng, a * 3.0, along, 6.0))[..., None]
        edge = np.minimum(abs(a - 0.003), abs(a - STRAP_W + 0.003))
        tone = _over(tone, (0.6, 0.57, 0.5), 0.35 * np.exp(-(edge / 0.0015) ** 2))
        if which == "neck":  # the middle lies on the back of the neck all shift
            mid = abs(along - NECK_LEN / 2)
            tone = _over(tone, (0.62, 0.55, 0.4), 0.6 * _smooth((0.13 - mid) / 0.06) * (0.6 + 0.6 * patch))
        else:  # handled every time they are tied; frayed at the ends
            end = STRAP_LEN[which] - along
            tone = _over(tone, (0.56, 0.53, 0.46), 0.45 * _smooth(1 - end / 0.12))
            tone = _over(tone, (0.45, 0.43, 0.38), 0.55 * _smooth(1 - end / 0.012))
        colour = np.where(cell[..., None], tone, colour)
    path = os.path.join(HERE, "Apron_color.png")
    img = bpy.data.images.get("Apron_color") or bpy.data.images.new("Apron_color", SIZE, SIZE)
    img.pixels.foreach_set(np.concatenate([np.clip(colour, 0, 1), np.ones(u.shape + (1,))], axis=-1).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.source = "FILE"  # read from the saved file from now on: export() leaves it where it is
    img.reload()
    return img


def ribbon_normals(path: list, centre: Vector) -> list:
    """Outward normals for a strap lying round a body: away from the vertical axis through centre."""
    return [Vector((p.x - centre.x, p.y - centre.y, 0.0)).normalized() for p in path]

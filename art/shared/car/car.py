"""Shared by art/hatchback and art/old_sedan, run inside Blender by tools/models.sh.

A car here is built from plain parts, not baked: a Part is one mesh with its materials, and the helpers add lofted
shells (ring after ring along the car), rounded boxes, tubes, thin sheets (glass, panels) and beams to it. Every material
is a plain Principled BSDF (colour, roughness, metal), optionally times a tiny tiling texture and the part's baked
ambient occlusion (the "ao" vertex colours, which Godot's importer multiplies into the albedo). Blender, Z up, the car's front
toward -Y, its left toward +X.
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

ART = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ART)
import common  # noqa: E402

node = common.node


# --- textures -------------------------------------------------------------------------------------------

def _image(name: str, pixels: np.ndarray) -> bpy.types.Image:
    """An image from an (h, w) grey or (h, w, 4) RGBA float array, not packed (common.export saves it beside the build)."""
    if pixels.ndim == 2:
        pixels = np.stack([pixels, pixels, pixels, np.ones_like(pixels)], axis=-1)
    h, w = pixels.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = pixels.astype(np.float32).ravel()
    img.alpha_mode = "STRAIGHT"
    return img


def weave_image() -> bpy.types.Image:
    """Cloth: a 64 px tile of plain weave, mid grey with the threads a few per cent lighter and darker."""
    rng = np.random.default_rng(7)
    n = 64
    y, x = np.mgrid[0:n, 0:n]
    thread = 0.5 + 0.5 * np.sin(x * math.tau / 4) * np.sin(y * math.tau / 4)  # a 4 px weave
    grey = 0.80 + 0.09 * thread + rng.normal(0, 0.03, (n, n))
    return _image("weave", np.clip(grey, 0, 1))


def grain_image() -> bpy.types.Image:
    """Moulded plastic: a 64 px tile of fine pitting, around 0.88 grey."""
    rng = np.random.default_rng(11)
    n = 64
    return _image("grain", np.clip(0.88 + rng.normal(0, 0.035, (n, n)), 0, 1))


# --- materials ------------------------------------------------------------------------------------------

def material(name: str, colour: tuple, rough: float = 0.8, metal: float = 0.0, alpha: float | None = None,
             texture: bpy.types.Image | None = None, emission: bpy.types.Image | None = None,
             ao: bool = True) -> bpy.types.Material:
    """A plain material. colour: linear RGB. alpha: below 1 makes it see-through glass-style (and double-sided).
    texture: a tiling grey multiplied into the colour. emission: an image that glows (the gauges). ao: multiply the
    part's "ao" vertex colours in."""
    mat = bpy.data.materials.new(name)
    mat.use_backface_culling = alpha is None
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    cur = colour
    if texture is not None or ao:
        def multiply(a, b):
            ins = {0: 1.0}
            for i, c in ((6, a), (7, b)):
                ins[i] = c if isinstance(c, bpy.types.NodeSocket) else (*c, 1.0)
            return node(nt, "ShaderNodeMix", ins, data_type="RGBA", blend_type="MULTIPLY").outputs[2]
        if texture is not None:
            cur = multiply(cur, node(nt, "ShaderNodeTexImage", image=texture).outputs["Color"])
        if ao:
            cur = multiply(cur, node(nt, "ShaderNodeVertexColor", layer_name="ao").outputs["Color"])
    if isinstance(cur, bpy.types.NodeSocket):
        nt.links.new(cur, bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*cur, 1.0)
    if alpha is not None:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
    if emission is not None:
        bsdf.inputs["Emission Strength"].default_value = 1.0
        nt.links.new(node(nt, "ShaderNodeTexImage", image=emission).outputs["Color"], bsdf.inputs["Emission Color"])
    return mat


# --- geometry -------------------------------------------------------------------------------------------

def at(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)) -> Matrix:
    """A placement: location, XYZ Euler rotation in degrees, scale."""
    return Matrix.LocRotScale(Vector(loc), Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix(), Vector(scale))


def aim(p0, p1, up=(0, 0, 1)) -> Matrix:
    """A rotation whose +Z runs from p0 to p1 (and whose +X lies as near the up vector's cross as it can), placed at p0."""
    z = (Vector(p1) - Vector(p0)).normalized()
    x = Vector(up).cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(p0)
    return m


class Part:
    """One mesh object in the making: a bmesh plus its materials. Add geometry with the methods, then .object()."""

    def __init__(self, name: str, mats: list):
        self.name = name
        self.bm = bmesh.new()
        self.mats = list(mats)
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def i(self, m) -> int:
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _tag(self, geom_faces, m, smooth=True) -> None:
        k = self.i(m)
        for f in geom_faces:
            f.material_index = k
            f.smooth = smooth

    def draw(self, fn, m, matrix: Matrix | None = None, smooth: bool = True) -> list:
        """Runs fn(bm), which adds geometry in local coordinates, and tags the new faces with m; matrix (if any) then
        moves the new vertices. Returns the new faces."""
        old_v, old_f = set(self.bm.verts), set(self.bm.faces)
        fn(self.bm)
        new_v = [v for v in self.bm.verts if v not in old_v]
        if matrix is not None:
            bmesh.ops.transform(self.bm, matrix=matrix, verts=new_v)
        faces = [f for f in self.bm.faces if f not in old_f]
        self._tag(faces, m, smooth)
        return faces

    # -- solids --
    def box(self, centre, size, m, matrix: Matrix | None = None) -> list:
        """An axis-aligned box about centre (then matrix applied, if given)."""
        def d(bm):
            bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector(centre), None, Vector(size)))
        return self.draw(d, m, matrix, smooth=False)

    def rbox(self, centre, size, radius, m, matrix: Matrix | None = None, seg: int = 2) -> list:
        """A box with every edge rounded (radius, seg steps), smooth shaded: a cushion, a pad, a bolster."""
        def d(bm):
            vs = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector(centre), None, Vector(size)))["verts"]
            radius_ = min(radius, min(size) * 0.49)
            bmesh.ops.bevel(bm, geom=list({e for v in vs for e in v.link_edges}), offset=radius_, offset_type="OFFSET",
                            segments=seg, profile=0.5, affect="EDGES")
        return self.draw(d, m, matrix)

    def cyl(self, p0, p1, r0, r1, m, sides=12, caps=(True, True), smooth=True, matrix: Matrix | None = None) -> list:
        """A cylinder or cone from p0 (radius r0) to p1 (radius r1); matrix (if any) then moves it."""
        length = (Vector(p1) - Vector(p0)).length

        def d(bm):
            res = bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=sides, radius1=r0, radius2=r1, depth=length)
            vs = res["verts"]
            bmesh.ops.translate(bm, verts=vs, vec=(0, 0, length / 2))
            faces = {f for v in vs for f in v.link_faces}
            for cap, z in ((caps[0], 0.0), (caps[1], length)):
                if cap:
                    ring = [v for v in vs if abs(v.co.z - z) < 1e-6]
                    faces.add(bm.faces.new(ring if z > 0 else ring[::-1]))
            bmesh.ops.recalc_face_normals(bm, faces=list(faces))
        return self.draw(d, m, aim(p0, p1) if matrix is None else matrix @ aim(p0, p1), smooth)

    def revolve(self, profile: list, centre, sides: int, m, matrix: Matrix | None = None) -> list:
        """common.revolve: spins the (radius, height) profile about the vertical axis at centre."""
        return self.draw(lambda bm: common.revolve(bm, profile, centre, sides, 0), m, matrix)

    # -- surfaces --
    def poly(self, pts, m, facing=None, smooth=False) -> bmesh.types.BMFace:
        """One face over the points; facing: a direction its normal should lie towards (else the points are reversed)."""
        pts = [Vector(p) for p in pts]
        if facing is not None:
            n = Vector()
            for a, b in zip(pts, pts[1:] + pts[:1]):  # Newell's normal, good for a concave outline
                n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
            if n.dot(Vector(facing)) < 0:
                pts = pts[::-1]
        f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        self._tag([f], m, smooth)
        return f

    def loft(self, rings: list, mats, closed: bool = True, toward=None, smooth: bool = True) -> list:
        """Quads between consecutive rings (lists of points, the same count each), returned as grid[strip][segment].
        mats: a material or one per ring segment. toward: (segment, direction): the faces on that segment must face that way
        (else all are flipped). Coincident points are welded, so a ring that pinches two of its points together costs nothing
        (the faces that collapse are gone: check is_valid)."""
        n = len(rings[0])
        segs = n if closed else n - 1
        mats = mats if isinstance(mats, (list, tuple)) else [mats] * segs
        verts = [[self.bm.verts.new(Vector(p)) for p in ring] for ring in rings]
        grid = [[self.bm.faces.new([a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]]) for j in range(segs)] for a, b in zip(verts, verts[1:])]
        flat = [f for row in grid for f in row]
        if toward is not None:
            seg, direction = toward
            grid[0][seg].normal_update()
            if grid[0][seg].normal.dot(Vector(direction)) < 0:
                bmesh.ops.reverse_faces(self.bm, faces=flat)
        for row in grid:
            for j, f in enumerate(row):
                f.material_index = self.i(mats[j])
                f.smooth = smooth
        bmesh.ops.remove_doubles(self.bm, verts=[v for ring in verts for v in ring], dist=1e-5)
        return grid

    def sheet(self, c00, c10, c11, c01, m, nu: int = 1, nv: int = 1, bulge=(0.0, 0.0), back=None, gap: float = 0.0, facing=None) -> list:
        """A bilinear patch over four corners (c00 -> c10 along u, c00 -> c01 along v; counter-clockwise seen from the front),
        nu by nv quads, bowed outward by bulge = (along u, along v) metres at the middle. back: a material for a second skin gap
        metres behind it, facing the other way (a panel with an inner trim)."""
        p = [Vector(c) for c in (c00, c10, c11, c01)]
        normal = (p[1] - p[0]).cross(p[3] - p[0]).normalized()
        if facing is not None and normal.dot(Vector(facing)) < 0:  # wound the wrong way round: swap the sides
            p = [p[0], p[3], p[2], p[1]]
            bulge = (bulge[1], bulge[0])
            nu, nv = nv, nu
            normal = -normal
        grid = []
        for iv in range(nv + 1):
            row = []
            for iu in range(nu + 1):
                u, v = iu / nu, iv / nv
                pt = p[0].lerp(p[1], u).lerp(p[3].lerp(p[2], u), v)
                pt += normal * (bulge[0] * 4 * u * (1 - u) + bulge[1] * 4 * v * (1 - v))
                row.append(pt)
            grid.append(row)
        faces = self._grid(grid, m, False)
        if back is not None:
            grid2 = [[pt - normal * gap for pt in row] for row in grid]
            faces += self._grid(grid2, back, True)
        return faces

    def _grid(self, grid, m, flip) -> list:
        vs = [[self.bm.verts.new(p) for p in row] for row in grid]
        nv, nu = len(vs) - 1, len(vs[0]) - 1
        faces = []
        for iv, (r0, r1) in enumerate(zip(vs, vs[1:])):
            for j in range(nu):
                quad = [(r0[j], j, iv), (r0[j + 1], j + 1, iv), (r1[j + 1], j + 1, iv + 1), (r1[j], j, iv + 1)]
                f = self.bm.faces.new([q[0] for q in (quad[::-1] if flip else quad)])
                for loop, q in zip(f.loops, quad[::-1] if flip else quad):
                    loop[self.uv].uv = (q[1] / nu, q[2] / nv)
                faces.append(f)
        self._tag(faces, m, True)
        return faces

    def beam(self, path, w: float, d: float, out, mats) -> list:
        """A straight or bent bar along the points of path, w wide and d deep (d along out). mats: (outer, inner, sides)."""
        path = [Vector(p) for p in path]
        out = Vector(out)
        rings = []
        for k, p in enumerate(path):
            t = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
            o = (out - t * out.dot(t)).normalized()
            s = t.cross(o)
            rings.append([p + s * w / 2 + o * d / 2, p - s * w / 2 + o * d / 2, p - s * w / 2 - o * d / 2, p + s * w / 2 - o * d / 2])
        vs = [[self.bm.verts.new(p) for p in ring] for ring in rings]
        faces = []
        for a, b in zip(vs, vs[1:]):
            for j in range(4):
                faces.append(self.bm.faces.new([a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]]))
        faces += [self.bm.faces.new(vs[0][::-1]), self.bm.faces.new(vs[-1])]
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        for f in faces:
            f.normal_update()
            facing = f.normal.dot(out)
            f.material_index = self.i(mats[0] if facing > 0.5 else mats[1] if facing < -0.5 else mats[2])
            f.smooth = False
        return faces

    # -- finishing --
    def object(self, sharp: float = 40.0, scene=None) -> bpy.types.Object:
        """The mesh object (the bmesh is freed); edges sharper than `sharp` degrees stay hard."""
        bm = self.bm
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(m)
        if sharp:
            me.set_sharp_from_angle(angle=math.radians(sharp))
        obj = bpy.data.objects.new(self.name, me)
        (bpy.context.scene if scene is None else scene).collection.objects.link(obj)
        return obj


def uv_box(obj: bpy.types.Object, textured: dict) -> None:
    """Box-projected UVs for the faces whose material is in textured (material -> metres per tile), by the face's dominant axis."""
    me = obj.data
    slots = {i: textured[s.material] for i, s in enumerate(obj.material_slots) if s.material in textured}
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        scale = slots.get(poly.material_index)
        if not scale:
            continue
        n = poly.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        a, b = [k for k in range(3) if k != ax]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (co[a] / scale, co[b] / scale)


def bake_ao(objects: list, rays: int = 24, reach: float = 0.4, floor: float = 0.3, skip: tuple = ()) -> None:
    """Ambient occlusion into each object's "ao" colour attribute (byte colours, per corner): the share of rays cast from a
    corner, in a cosine fan about its normal, that reach `reach` metres without hitting another surface, from `floor` (shut in)
    to 1 (open). Faces in a material named in `skip` (glass) neither block nor take it."""
    rng = random.Random(5)
    verts, tris, owners = [], [], []
    for o in objects:
        me = o.data
        me.calc_loop_triangles()
        base = len(verts)
        mw = o.matrix_world
        verts += [mw @ v.co for v in me.vertices]
        for t in me.loop_triangles:
            if me.materials[t.material_index].name in skip:
                continue
            tris.append(tuple(base + i for i in t.vertices))
    tree = BVHTree.FromPolygons(verts, tris)
    # a fixed fan of directions in the z-up hemisphere (cosine weighted), turned to each normal
    fan = []
    for k in range(rays):
        u, v = (k + 0.5) / rays, rng.random()
        r, a = math.sqrt(u), math.tau * v
        fan.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(1 - u))))
    for o in objects:
        me = o.data
        ca = me.color_attributes.get("ao") or me.color_attributes.new("ao", "BYTE_COLOR", "CORNER")
        mw = o.matrix_world
        nm = mw.to_3x3()
        for poly in me.polygons:
            if me.materials[poly.material_index].name in skip:
                for li in poly.loop_indices:
                    ca.data[li].color = (1, 1, 1, 1)
                continue
            for li in poly.loop_indices:
                n = (nm @ me.corner_normals[li].vector).normalized()
                p = mw @ me.vertices[me.loops[li].vertex_index].co + n * 0.004
                t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
                bt = n.cross(t)
                open_ = 0.0
                for d in fan:
                    w = t * d.x + bt * d.y + n * d.z
                    hit = tree.ray_cast(p, w, reach)
                    open_ += 1.0 if hit[0] is None else hit[3] / reach
                g = floor + (1.0 - floor) * open_ / rays
                ca.data[li].color = (g, g, g, 1)


def torus(bm: bmesh.types.BMesh, radius: float, tube: float, major: int = 20, minor: int = 8) -> None:
    """A ring about the Z axis, in the XY plane (a steering wheel's rim)."""
    rings = []
    for i in range(major):
        a = math.tau * i / major
        out = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(out * radius + tube * (math.cos(b) * out + math.sin(b) * Vector((0, 0, 1)))) for b in (math.tau * k / minor for k in range(minor))])
    faces = [bm.faces.new([a[k], a[(k + 1) % minor], b[(k + 1) % minor], b[k]]) for a, b in zip(rings, rings[1:] + rings[:1]) for k in range(minor)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)


# --- body outlines and wheels, shared by both cars ------------------------------------------------------

def interp(table: list, y: float) -> list:
    """Linear interpolation of a table of rows (y, v1, v2, ...) at y."""
    if y <= table[0][0]:
        return list(table[0][1:])
    for a, b in zip(table, table[1:]):
        if y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return [p + (q - p) * t for p, q in zip(a[1:], b[1:])]
    return list(table[-1][1:])


def arch_height(y: float, zb: float, axle: float, arch: float, hub: float) -> float:
    """The height of the wheel arch's ceiling at y for wheels at +-axle (the underbody's own height zb outside them)."""
    for yc in (-axle, axle):
        if abs(y - yc) < arch - 1e-6:
            return max(zb, hub + math.sqrt(arch ** 2 - (y - yc) ** 2))
    return zb


def arch_stations(yc: float, arch: float) -> list:
    """y values that trace the arch round the axle at yc."""
    return [yc + arch * math.sin(math.radians(a)) for a in (-90, -70, -50, -30, -10, 10, 30, 50, 70, 90)]


def mirrored(half: list, y: float) -> list:
    """A ring from a half outline of (x, z) that starts and ends on the centre line, as (x, y, z) points."""
    return [(x, y, z) for x, z in half + [(-x, z) for x, z in half[-2:0:-1]]]


def nose_half(xw, zb, zs, zt, xs, ha) -> list:
    """The right half of a nose or tail shell's outline: underbody and wheelhouse (the first four segments), the side up to the
    shoulder at (xs, zs), over to the top centre (0, zt). ha: the arch ceiling here (zb outside the arches)."""
    xin, xlip = 0.56, xw - 0.05
    z4 = max(zb + 0.07, ha + 0.012)
    return [(0, zb), (xin, zb), (xin, ha), (xlip, ha), (xw, z4), (xw, z4 * 0.45 + zs * 0.55), (xs, zs), (xs * 0.78, zs * 0.25 + zt * 0.75), (0, zt)]


def wheel(name: str, sx: int, loc, r: float, rubber, steel, sides: int = 16) -> bpy.types.Object:
    """A wheel of tyre radius r spinning about X, its origin at the hub (loc), the outer face on side sx."""
    k = r / 0.298
    w = Part(name, [])
    spin = Matrix.Rotation(math.radians(90 * sx), 4, "Y")  # the profile's axis (Z) turned to point outward
    w.revolve([(0.19 * k, -0.080 * k), (0.25 * k, -0.083 * k), (0.29 * k, -0.055 * k), (0.298 * k, 0.0), (0.29 * k, 0.055 * k), (0.25 * k, 0.083 * k), (0.19 * k, 0.080 * k)],
              (0, 0, 0), sides, rubber, spin)
    w.revolve([(0.19 * k, 0.0), (0.186 * k, 0.07 * k), (0.15 * k, 0.058 * k), (0.06 * k, 0.058 * k), (0.0, 0.072 * k)], (0, 0, 0), sides, steel, spin)
    for n in range(4):
        a = math.tau * n / 4 + 0.4
        p0 = (0.1 * k * math.cos(a), 0.1 * k * math.sin(a), 0.07 * k)
        w.cyl(p0, (p0[0], p0[1], 0.082 * k), 0.012 * k, 0.012 * k, steel, sides=6, caps=(False, True), matrix=spin)
    obj = w.object()
    obj.location = loc
    return obj

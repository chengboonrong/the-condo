"""Shared by every art/<id>/build.py, run inside Blender by tools/models.sh.

Conventions: metres; the origin at the centre of the floor footprint (wall items: the centre of the face
touching the wall; hanging items: the hanging point); the front faces Blender -Y, which is Godot +Z.
"""
import filecmp
import glob
import math
import os
import shutil
import tempfile

import bmesh
import bpy
from mathutils import Matrix, Vector

ART = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(ART)


def reset() -> None:
    """An empty scene in metres."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    units = bpy.context.scene.unit_settings
    units.system = "METRIC"
    units.scale_length = 1.0


def pbr(name: str, folder: str, tint: tuple[float, float, float] | None = None) -> bpy.types.Material:
    """A Principled material from the texture set in folder (relative to art/): *Color*, *Roughness* and
    *NormalGL* files, read through the object's UV map. tint multiplies the colour."""
    mat = bpy.data.materials.new(name)
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def image(pattern: str, data: bool) -> bpy.types.NodeSocket:
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(sorted(glob.glob(os.path.join(ART, folder, f"*{pattern}*")))[0], check_existing=True)
        if data:
            node.image.colorspace_settings.name = "Non-Color"
        return node.outputs["Color"]

    color = image("Color", False)
    if tint:
        mul = nt.nodes.new("ShaderNodeVectorMath")
        mul.operation = "MULTIPLY"
        nt.links.new(color, mul.inputs[0])
        mul.inputs[1].default_value = tint
        color = mul.outputs["Vector"]
    nt.links.new(color, bsdf.inputs["Base Color"])
    nt.links.new(image("Roughness", True), bsdf.inputs["Roughness"])
    normal = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(image("NormalGL", True), normal.inputs["Color"])
    nt.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def bake(obj: bpy.types.Object, size: int = 512, pack: bool = False, grow: dict | None = None) -> None:
    """Cycles-bakes every material on obj (base colour, roughness, metallic, normal) into one image set on a
    fresh UV unwrap, and replaces them with one material, <obj.name>_baked. Each material must be a
    Principled BSDF; whatever feeds its inputs (procedural wear, texture sets) ends up in the images. pack: pack
    the islands tightly, rotated where that helps (the unwrap's own packing leaves a lot of the image empty). grow:
    {material index: factor}: the islands of faces with those materials are drawn that many times larger than their
    size warrants, for small things with fine print (needs pack, which keeps the sizes relative)."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    mats = list(dict.fromkeys(s.material for s in obj.material_slots if s.material))  # once each, in slot order
    me = obj.data
    old = [uv.name for uv in me.uv_layers]
    me.uv_layers.active = me.uv_layers.new(name="baked")  # the bake target; textures still read the old map
    select([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.01)
    if grow:
        _grow_islands(me, grow)
    if pack:
        bpy.ops.uv.pack_islands(rotate=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    images = {}
    for kind in ["color", "roughness_metallic", "normal"]:
        images[kind] = bpy.data.images.new(f"{obj.name}_{kind}", size, size, is_data=kind != "color")
        _bake_pass(obj, mats, kind, images[kind])
    baked = bpy.data.materials.new(f"{obj.name}_baked")
    baked.use_backface_culling = True  # glTF: not double-sided
    nt = baked.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def image(kind: str) -> bpy.types.NodeSocket:
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = images[kind]
        return node.outputs["Color"]

    nt.links.new(image("color"), bsdf.inputs["Base Color"])
    split = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(image("roughness_metallic"), split.inputs["Color"])
    nt.links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
    normal = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(image("normal"), normal.inputs["Color"])
    nt.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    me.materials.clear()
    me.materials.append(baked)
    me.polygons.foreach_set("material_index", [0] * len(me.polygons))
    for name in old:
        me.uv_layers.remove(me.uv_layers[name])


def _grow_islands(me: bpy.types.Mesh, grow: dict) -> None:
    """Scales each UV island whose faces have a material in grow about its own centre (the mesh is in edit mode)."""
    bm = bmesh.from_edit_mesh(me)
    uv = bm.loops.layers.uv.active
    parent = list(range(len(bm.faces)))

    def root(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def uv_at(f: bmesh.types.BMFace, v: bmesh.types.BMVert) -> Vector:
        return next(l for l in f.loops if l.vert is v)[uv].uv

    bm.faces.ensure_lookup_table()
    for e in bm.edges:  # faces are one island when they share an edge and its UVs
        if len(e.link_faces) == 2:
            a, b = e.link_faces
            if all((uv_at(a, v) - uv_at(b, v)).length < 1e-5 for v in e.verts):
                parent[root(a.index)] = root(b.index)
    islands = {}
    for f in bm.faces:
        islands.setdefault(root(f.index), []).append(f)
    for faces in islands.values():
        factor = grow.get(faces[0].material_index)
        if factor:
            loops = [l for f in faces for l in f.loops]
            lo = Vector((min(l[uv].uv.x for l in loops), min(l[uv].uv.y for l in loops)))
            hi = Vector((max(l[uv].uv.x for l in loops), max(l[uv].uv.y for l in loops)))
            for l in loops:
                l[uv].uv = (lo + hi) / 2 + (l[uv].uv - (lo + hi) / 2) * factor
    bmesh.update_edit_mesh(me)


def _bake_pass(obj: bpy.types.Object, mats: list, kind: str, img: bpy.types.Image) -> None:
    """Bakes into img, from every material: its base colour; its roughness (green) and metallic (blue), packed
    as glTF wants them; or its normal, in tangent space. The first two go through an emission shader."""
    added = []  # [node tree, node], removed after the bake
    surfaces = []  # [node tree, shader, output socket], linked back after the bake
    for mat in mats:
        nt = mat.node_tree
        target = nt.nodes.new("ShaderNodeTexImage")
        target.image = img
        nt.nodes.active = target
        added.append((nt, target))
        if kind == "normal":
            continue
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)
        emit = nt.nodes.new("ShaderNodeEmission")
        added.append((nt, emit))
        if kind == "color":
            _feed(nt, bsdf.inputs["Base Color"], emit.inputs["Color"])
        else:
            pack = nt.nodes.new("ShaderNodeCombineColor")
            added.append((nt, pack))
            _feed(nt, bsdf.inputs["Roughness"], pack.inputs["Green"])
            _feed(nt, bsdf.inputs["Metallic"], pack.inputs["Blue"])
            nt.links.new(pack.outputs["Color"], emit.inputs["Color"])
        surfaces.append((nt, out.inputs["Surface"].links[0].from_socket, out.inputs["Surface"]))
        nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    bpy.ops.object.bake(type="NORMAL" if kind == "normal" else "EMIT", normal_space="TANGENT", margin=4, use_clear=True)
    for nt, shader, out in surfaces:
        nt.links.new(shader, out)
    for nt, node in added:
        nt.nodes.remove(node)


def _feed(nt: bpy.types.NodeTree, src: bpy.types.NodeSocket, dst: bpy.types.NodeSocket) -> None:
    """Gives dst what feeds the input src: its link, or its value."""
    if src.is_linked:
        nt.links.new(src.links[0].from_socket, dst)
    else:
        dst.default_value = src.default_value


def export(model_id: str, objects: list[bpy.types.Object]) -> None:
    """Writes assets/models/<id>.glb (these objects only, modifiers applied, +Y up, textures embedded) and
    saves art/<id>/<id>.blend: the scene and what it uses, its generated images as PNGs beside it (not
    packed). Both are left alone when the .glb comes out the same: Blender seeds a few ids in a .blend at
    random, so an unchanged model would still change it."""
    folder = os.path.join(ART, model_id)
    glb = os.path.join(ROOT, "assets", "models", f"{model_id}.glb")
    blend = os.path.join(folder, f"{model_id}.blend")
    bpy.data.orphans_purge(do_recursive=True)  # what the bake replaced, and anything built only to be baked
    for img in bpy.data.images:
        if img.source == "GENERATED" and img.users:
            img.filepath_raw = os.path.join(folder, f"{img.name}.png")
            img.file_format = "PNG"
            img.save()
    select(objects)
    with tempfile.TemporaryDirectory() as tmp:
        new = os.path.join(tmp, f"{model_id}.glb")
        bpy.ops.export_scene.gltf(filepath=new, export_format="GLB", use_selection=True, export_apply=True,
            export_yup=True, export_animations=False)
        if os.path.exists(blend) and os.path.exists(glb) and filecmp.cmp(new, glb, shallow=False):
            return
        # The .blend first: a run stopped between the two writes leaves an old .glb, so the next run writes both.
        bpy.data.libraries.write(blend, {bpy.context.scene}, path_remap="RELATIVE_ALL", compress=True)
        os.makedirs(os.path.dirname(glb), exist_ok=True)
        shutil.move(new, glb)


# --- geometry -------------------------------------------------------------------------------------------
# Furniture parts for a build.py's bmesh: each takes the mesh and the index of the material its faces use.

def box(bm: bmesh.types.BMesh, centre: tuple, size: tuple, material: int) -> None:
    geom = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector(centre), None, Vector(size)))
    for f in {f for v in geom["verts"] for f in v.link_faces}:
        f.material_index = material


def chamfered_box(bm: bmesh.types.BMesh, centre: tuple, size: tuple, chamfer: float, material: int) -> None:
    """A box with all twelve edges chamfered, chamfer metres in along each face."""
    old = set(bm.faces)  # the bevel replaces the cube's faces, and bmesh reuses freed slots: the new ones are not the last
    verts = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector(centre), None, Vector(size)))["verts"]
    bmesh.ops.bevel(bm, geom=list({e for v in verts for e in v.link_edges}), offset=chamfer, offset_type="OFFSET", segments=1, affect="EDGES")
    for f in bm.faces:
        if f not in old:
            f.material_index = material


def post(bm: bmesh.types.BMesh, z0: float, z1: float, bottom: tuple, top: tuple, material: int) -> None:
    """A four-sided post from z0 to z1, slanted or tapered: bottom and top are (centre x, centre y, width, depth)."""
    def ring(z: float, r: tuple) -> list:
        return [bm.verts.new((r[0] + sx * r[2] / 2, r[1] + sy * r[3] / 2, z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    lo, hi = ring(z0, bottom), ring(z1, top)
    faces = [bm.faces.new(lo[::-1]), bm.faces.new(hi)]
    faces += [bm.faces.new([lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]]) for i in range(4)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for f in faces:
        f.material_index = material


def slab(bm: bmesh.types.BMesh, centre: tuple, size: tuple, z0: float, z1: float, radius: float, chamfer: float, material: int) -> None:
    """A board from z0 to z1 with rounded corners (radius), its top and bottom edges chamfered."""
    def outline(inset: float) -> list:
        half = (size[0] / 2 - inset, size[1] / 2 - inset)
        r = radius - inset
        points = []
        for sx, sy, start in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
            for k in range(5):
                a = math.radians(start + 90 * k / 4)
                points.append((centre[0] + sx * (half[0] - r) + r * math.cos(a), centre[1] + sy * (half[1] - r) + r * math.sin(a)))
        return points
    levels = [(z0, chamfer), (z0 + chamfer, 0.0), (z1 - chamfer, 0.0), (z1, chamfer)]
    rings = [[bm.verts.new((x, y, z)) for x, y in outline(inset)] for z, inset in levels]
    n = len(rings[0])
    faces = [bm.faces.new(rings[0][::-1]), bm.faces.new(rings[-1])]
    for a, b in zip(rings, rings[1:]):
        faces += [bm.faces.new([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]]) for i in range(n)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for f in faces:
        f.material_index = material


def revolve(bm: bmesh.types.BMesh, profile: list, centre: tuple, segments: int, material: int) -> None:
    """Spins the (radius, height) profile, bottom to top, about the vertical axis at centre = (x, y, z). A radius
    of 0 ends it in a point. Open at the bottom."""
    rings = []
    for r, z in profile:
        if r == 0:
            rings.append([bm.verts.new((centre[0], centre[1], centre[2] + z))])
        else:
            rings.append([bm.verts.new((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a), centre[2] + z))
                          for a in (math.tau * i / segments for i in range(segments))])
    faces = []
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            faces.append(bm.faces.new([a[i], a[j], b[0]] if len(b) == 1 else [a[i], a[j], b[j], b[i]]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for f in faces:
        f.material_index = material
        f.smooth = True


# --- shader nodes ---------------------------------------------------------------------------------------
# Small helpers for the procedural materials a build.py bakes. Colours are linear RGB.

def node(nt: bpy.types.NodeTree, kind: str, inputs: dict | None = None, **props) -> bpy.types.Node:
    """A node with its properties set; inputs: socket name or index -> a value, or an output socket to link."""
    n = nt.nodes.new(kind)
    for k, v in props.items():
        setattr(n, k, v)
    for k, v in (inputs or {}).items():
        if isinstance(v, bpy.types.NodeSocket):
            nt.links.new(v, n.inputs[k])
        else:
            n.inputs[k].default_value = v
    return n


def mapped(nt: bpy.types.NodeTree, value: bpy.types.NodeSocket, lo: float, hi: float, a: float, b: float) -> bpy.types.NodeSocket:
    """value from lo..hi mapped to a..b, clamped (lo may be above hi)."""
    return node(nt, "ShaderNodeMapRange", {"Value": value, "From Min": lo, "From Max": hi, "To Min": a, "To Max": b}).outputs["Result"]


def maths(nt: bpy.types.NodeTree, op: str, a, b=0.0) -> bpy.types.NodeSocket:
    """Math node: a and b are values or sockets."""
    return node(nt, "ShaderNodeMath", {0: a, 1: b}, operation=op).outputs["Value"]


def lerp(nt: bpy.types.NodeTree, a, b, fac) -> bpy.types.NodeSocket:
    """A colour mixed from a to b by fac; a and b are RGB tuples or sockets, fac a value or a socket."""
    # The Mix node has a float, a vector and a colour version of each socket, all named alike: take the colour
    # ones (inputs 6 and 7, output 2) by index.
    inputs = {0: fac}
    for i, c in ((6, a), (7, b)):
        inputs[i] = c if isinstance(c, bpy.types.NodeSocket) else (*c, 1.0)
    return node(nt, "ShaderNodeMix", inputs, data_type="RGBA").outputs[2]


def noise(nt: bpy.types.NodeTree, coords: bpy.types.NodeSocket, scale: float, detail: float = 6.0) -> bpy.types.NodeSocket:
    return node(nt, "ShaderNodeTexNoise", {"Vector": coords, "Scale": scale, "Detail": detail}).outputs["Factor"]


def surface(name: str) -> tuple:
    """A new material: (material, its node tree, its Principled BSDF, object coordinates)."""
    mat = bpy.data.materials.new(name)
    nt = mat.node_tree
    return mat, nt, nt.nodes["Principled BSDF"], node(nt, "ShaderNodeTexCoord").outputs["Object"]


def wood(name: str, tint: tuple, axis: int = 0, boards: tuple | None = None, rings: list = ()) -> bpy.types.Material:
    """Stained, varnished rubberwood with its grain along axis (0 X, 1 Y, 2 Z). The varnish is worn off the edges
    and chamfers, near the floor and in patches; the dirt is on up-facing surfaces and in the corners. tint is the
    stain, linear RGB. boards: (start, width) in metres, glued boards side by side along Y, each a little lighter or
    darker, with a seam between them. rings: [(x, y, radius)] mug rings on up-facing surfaces."""
    mat, nt, bsdf, coords = surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs

    def stretched(along: float, across: float) -> bpy.types.NodeSocket:  # noise drawn out along the grain
        scale = tuple(along if i == axis else across for i in range(3))
        return noise(nt, node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": scale}).outputs["Vector"], 1.0, 3.0)

    grain = mapped(nt, maths(nt, "ADD", maths(nt, "MULTIPLY", stretched(3.0, 120.0), 0.6), maths(nt, "MULTIPLY", stretched(2.0, 22.0), 0.4)), 0.3, 0.7, 0.0, 1.0)
    bevelled = node(nt, "ShaderNodeBevel", {"Radius": 0.003}, samples=16).outputs["Normal"]
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    normal = node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs
    square = maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", maths(nt, "ABSOLUTE", normal["X"]), maths(nt, "ABSOLUTE", normal["Y"])), maths(nt, "ABSOLUTE", normal["Z"]))
    edge = maths(nt, "MAXIMUM", mapped(nt, node(nt, "ShaderNodeVectorMath", {0: bevelled, 1: flat}, operation="DOT_PRODUCT").outputs["Value"], 1.0, 0.8, 0.0, 1.0),
                 mapped(nt, square, 0.97, 0.85, 0.0, 1.0))  # the bevel's edge, and every face not square to an axis: chamfers, rounded corners
    patches = mapped(nt, noise(nt, coords, 7.0, 3.0), 0.56, 0.7, 0.0, 1.0)
    floor = maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], 0.07, 0.0, 0.0, 1.0), mapped(nt, noise(nt, coords, 40.0, 3.0), 0.35, 0.6, 0.4, 1.0))  # scuffed by shoes and brooms
    worn = maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", edge, floor), maths(nt, "MULTIPLY", patches, 0.85))
    varnished = lerp(nt, tuple(c * 0.75 for c in tint), tuple(c * 1.1 for c in tint), grain)
    bare = lerp(nt, tuple(c * 1.5 for c in tint), tuple(c * 1.9 for c in tint), grain)
    colour = lerp(nt, varnished, bare, worn)
    seam = 0.0
    if boards:
        u = maths(nt, "DIVIDE", maths(nt, "SUBTRACT", xyz["Y"], boards[0]), boards[1])
        tone = mapped(nt, node(nt, "ShaderNodeTexWhiteNoise", {"W": maths(nt, "FLOOR", u)}, noise_dimensions="1D").outputs["Value"], 0.0, 1.0, 0.85, 1.15)
        colour = node(nt, "ShaderNodeVectorMath", {0: colour, "Scale": tone}, operation="SCALE").outputs["Vector"]
        across = maths(nt, "FRACT", u)
        seam = mapped(nt, maths(nt, "MULTIPLY", maths(nt, "MINIMUM", across, maths(nt, "SUBTRACT", 1.0, across)), boards[1]), 0.0015, 0.0003, 0.0, 1.0)
        colour = lerp(nt, colour, tuple(c * 0.3 for c in tint), maths(nt, "MULTIPLY", seam, 0.7))
    up = mapped(nt, normal["Z"], 0.5, 0.95, 0.0, 1.0)
    marks = 0.0  # mug rings: a dark line, a pale cloud inside it
    for x, y, radius in rings:
        flat_xy = node(nt, "ShaderNodeCombineXYZ", {"X": xyz["X"], "Y": xyz["Y"]}).outputs["Vector"]
        d = node(nt, "ShaderNodeVectorMath", {0: flat_xy, 1: (x, y, 0.0)}, operation="DISTANCE").outputs["Value"]
        broken = mapped(nt, noise(nt, coords, 45.0, 3.0), 0.35, 0.6, 0.3, 1.0)
        line = maths(nt, "MULTIPLY", mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", d, radius)), 0.005, 0.0008, 0.0, 1.0), broken)
        cloud = maths(nt, "MULTIPLY", mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", d, radius - 0.007)), 0.009, 0.0, 0.0, 0.5), mapped(nt, noise(nt, coords, 12.0, 3.0), 0.3, 0.6, 0.3, 1.0))
        colour = lerp(nt, colour, tuple(c * 2.4 for c in tint), maths(nt, "MULTIPLY", cloud, up))
        colour = lerp(nt, colour, tuple(c * 0.4 for c in tint), maths(nt, "MULTIPLY", line, up))
        marks = maths(nt, "MAXIMUM", marks, maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", line, cloud), up))
    grime = maths(nt, "MULTIPLY", up, mapped(nt, noise(nt, coords, 3.5, 3.0), 0.45, 0.75, 0.0, 0.5))
    colour = lerp(nt, colour, (0.02, 0.016, 0.012), grime)
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.05}, samples=32, only_local=True).outputs["AO"]
    colour = lerp(nt, tuple(c * 0.4 for c in tint), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    rough = maths(nt, "MAXIMUM", mapped(nt, worn, 0.0, 1.0, 0.3, 0.85), mapped(nt, grime, 0.0, 0.5, 0.0, 0.8))
    rough = maths(nt, "MAXIMUM", rough, maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", marks, seam), 0.75))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    nt.links.new(bevelled, bsdf.inputs["Normal"])
    return mat


def select(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

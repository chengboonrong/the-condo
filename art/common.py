"""Shared by every art/<id>/build.py, run inside Blender by tools/models.sh.

Conventions: metres; the origin at the centre of the floor footprint (wall items: the centre of the face
touching the wall; hanging items: the hanging point); the front faces Blender -Y, which is Godot +Z.
"""
import filecmp
import glob
import os
import shutil
import tempfile

import bpy

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


def bake(obj: bpy.types.Object, size: int = 512) -> None:
    """Cycles-bakes every material on obj (base colour, roughness, metallic, normal) into one image set on a
    fresh UV unwrap, and replaces them with one material, <obj.name>_baked. Each material must be a
    Principled BSDF; whatever feeds its inputs (procedural wear, texture sets) ends up in the images."""
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


def select(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

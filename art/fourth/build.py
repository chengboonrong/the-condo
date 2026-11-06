"""The fourth passenger: the penanggal by day, sitting in the back of the car behind the driver. Run by tools/models.sh.

The same woman (art/shared/her: the same head, face and hair), sitting still with her hands limp in her lap and her
head bowed, chin almost on her chest, so her long wet hair hangs forward over her face. She wears a plain baju kurung,
soaked through: the long loose top to below the hips, its sleeves to the wrists, and the kain (the long skirt) down to
her bare feet, the cotton clinging, darker where it is wettest, a little mud at the hem.

The body is Skin-modifier tubes on a vertex skeleton, then Subdivision and drape folds from noise, like art/figure.
Materials, so code can tell them apart: "skin" (the face, the neck, the hands and the feet: her plain skin, no texture
and no blood, the hands and feet a darker, greyer grey than her face), "eyes", "hair" (seen from both sides) and
"cloth" (the baju kurung). Skin, eyes and cloth are coloured per vertex: the attribute "Color".
The origin is the H-point, the centre of her hip joint as she sits (the cushion 0.10 m below it, the seatback 0.13 m
behind it); her thighs run forward along -Y, which is the game's +Z.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils import noise as perlin

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [ART, os.path.join(ART, "shared", "her")]
import common  # noqa: E402
import her  # noqa: E402
from her import smooth  # noqa: E402

perlin.seed_set(5207)

BOW = math.radians(52)  # how far her head hangs forward
NECK = Vector((0.0, 0.035, 0.575))  # where her head turns on her neck (model space)
PIVOT = Vector((0.0, 0.012, -0.072))  # the same point in head space, below and a little behind the skull's centre
POSE = Matrix.Translation(NECK) @ Matrix.Rotation(BOW, 4, "X") @ Matrix.Translation(-PIVOT)
# Her vertex colours are written as display (sRGB) values, not glTF's linear ones: Godot's Compatibility renderer runs
# material code in sRGB and decodes ALBEDO after it, so a linear vertex colour is decoded twice and shows far too dark.
FACE = (*her.SKIN, 1.0)
LIMBS = (0.35, 0.34, 0.33, 1.0)  # the hands and the feet: darker and greyer, so they never draw the eye
CLOTH = (0.15, 0.17, 0.19)  # linear: a faded grey-blue cotton (dress() writes it as sRGB)

# Skeletons for the Skin modifier: chains of (x, y, z, radius, radius) for her left side (+X) or the middle.
BODY = [
    # the top, loose, from the seat up her back to the shoulders, leaning back on the seat a little and slumped
    [(0, 0.035, -0.035, 0.17, 0.125), (0, 0.045, 0.1, 0.148, 0.105), (0, 0.058, 0.24, 0.152, 0.1),
     (0, 0.064, 0.36, 0.158, 0.092), (0, 0.06, 0.43, 0.1, 0.07), (0, 0.05, 0.47, 0.058, 0.05)],
    # the lap: the top's hem over the kain, both legs together, the knees, the shins down to the hem above her feet
    [(0, 0.035, -0.035, 0.17, 0.125), (0, -0.14, -0.01, 0.168, 0.1), (0, -0.21, -0.004, 0.172, 0.103),
     (0, -0.235, 0.0, 0.156, 0.084), (0, -0.39, 0.012, 0.15, 0.078),
     (0, -0.445, -0.07, 0.14, 0.074), (0, -0.475, -0.24, 0.13, 0.07), (0, -0.48, -0.275, 0.135, 0.072)],
    # the sleeves, loose, the arms hanging and the forearms in her lap
    [(0, 0.064, 0.36, 0.158, 0.092), (0.15, 0.066, 0.355, 0.055, 0.055), (0.178, 0.058, 0.25, 0.052, 0.052),
     (0.19, 0.035, 0.13, 0.05, 0.05), (0.15, -0.07, 0.1, 0.048, 0.048), (0.12, -0.165, 0.1, 0.05, 0.05)],
]
SKIN_PARTS = [
    # the neck, up into the bowed head
    [(0, 0.05, 0.455, 0.05, 0.05), (0, 0.042, 0.53, 0.047, 0.047), (0, 0.035, 0.585, 0.045, 0.045)],
    # the hands, limp on her thighs, palms down (flattened after), the fingers hanging over and the thumbs inside
    [(0.118, -0.15, 0.1, 0.02, 0.02), (0.11, -0.2, 0.1, 0.024, 0.024), (0.1, -0.245, 0.097, 0.024, 0.024)],
    [(0.104, -0.19, 0.095, 0.0075, 0.0075), (0.088, -0.222, 0.088, 0.0068, 0.0068), (0.08, -0.248, 0.08, 0.006, 0.006)],
    # the bare feet, flat on the floor
    [(0.055, -0.48, -0.27, 0.032, 0.032), (0.06, -0.5, -0.31, 0.034, 0.034), (0.066, -0.58, -0.32, 0.033, 0.033),
     (0.07, -0.68, -0.325, 0.03, 0.03)],
]


def fingers() -> list:
    """Her left hand's four fingers, from the knuckles, curling down over her thigh; the middle one longest."""
    out = []
    for dx, reach in ((0.016, 0.82), (0.005, 0.97), (-0.006, 1.0), (-0.017, 0.9)):  # little finger outside
        x, y, z = 0.1 + dx, -0.245, 0.097
        chain = [(x, y, z, 0.007, 0.007)]
        for seg, down in ((0.04, 0.25), (0.026, 0.75), (0.02, 1.15)):
            seg *= reach
            x += dx * 0.15
            y -= seg * math.cos(down)
            z -= seg * math.sin(down)
            chain.append((x, y, z, 0.0066 - 0.0006 * len(chain), 0.0066 - 0.0006 * len(chain)))
        out.append(chain)
    return out


def skin(name: str, chains: list, levels: int = 2) -> bpy.types.Object:
    """A mesh made by the Skin modifier, then Subdivision, from chains of (x, y, z, rx, ry), mirrored across X (a chain
    that starts where an earlier one passes branches from it). Returns it as a plain mesh object."""
    verts, radii, edges, roots, index = [], [], [], [], {}
    for chain in chains + [[(-p[0], *p[1:]) for p in c] for c in chains if any(p[0] for p in c)]:
        ids = []
        for p in chain:
            key = tuple(round(c, 5) for c in p[:3])
            if key not in index:
                index[key] = len(verts)
                verts.append(p[:3])
                radii.append(p[3:5])
                if not ids:
                    roots.append(index[key])
            ids.append(index[key])
        edges += list(zip(ids, ids[1:]))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, edges, [])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("skin", "SKIN")
    mod.use_smooth_shade = True
    mod.branch_smoothing = 0.6
    for i, sv in enumerate(me.skin_vertices[0].data):
        sv.radius = radii[i]
        sv.use_root = i in roots
    sub = obj.modifiers.new("smooth", "SUBSURF")
    sub.levels = sub.render_levels = levels
    common.select([obj])
    bpy.ops.object.convert(target="MESH")
    return obj


def cloth_material() -> bpy.types.Material:
    """"cloth": the colour per vertex, wet cotton."""
    mat = bpy.data.materials.new("cloth")
    mat.use_backface_culling = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.68
    return mat


def dress(obj: bpy.types.Object) -> None:
    """The baju kurung's drape: soft folds hanging down it and creases at the elbows and the lap, the cotton clinging;
    coloured darker where it is wettest, with mud at the hem."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    for v in bm.verts:
        p = v.co
        folds = 0.011 * perlin.noise(Vector((p.x * 22.0, p.y * 22.0, p.z * 2.5)))  # long, hanging
        creases = 0.004 * perlin.noise(p * 45.0)
        v.co = p + v.normal * (folds + creases)
    layer = bm.loops.layers.float_color.new("Color")
    for f in bm.faces:
        f.material_index = 0
        f.smooth = True
        for loop in f.loops:
            p = loop.vert.co
            wet = smooth((perlin.noise(p * 6.0 + Vector((3.0, 1.0, 2.0))) + 0.1) / 0.5)
            k = 0.62 + 0.38 * (1.0 - wet) + 0.05 * perlin.noise(p * 30.0)
            c = [x * k for x in CLOTH]
            mud = smooth((-0.2 - p.z) / 0.07) * (0.5 + 0.5 * perlin.noise(p * 25.0))
            c = [x + (m - x) * mud * 0.7 for x, m in zip(c, (0.06, 0.045, 0.03))]
            loop[layer] = (*(x ** (1 / 2.2) for x in c), 1.0)  # as sRGB: see FACE
    bm.to_mesh(obj.data)
    bm.free()


def skin_below_head(obj: bpy.types.Object) -> None:
    """The neck, the hands and the feet: her plain skin, the neck her face's colour, the hands and feet greyer."""
    me = obj.data
    for p in me.polygons:
        p.material_index = 0
        p.use_smooth = True
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    for loop, d in zip(me.loops, attr.data):
        d.color = FACE if me.vertices[loop.vertex_index].co.z > 0.3 else LIMBS


def triangles(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


common.reset()
skin_mat, cloth_mat = her.plain_skin_material(), cloth_material()
head = her.head("head", 1600, POSE, FACE)
eyes = her.eyes("eyes", POSE)
# the hair hangs off her face onto her chest and lap
colliders = [(Vector((0.0, 0.05, 0.05)), Vector((0.0, 0.064, 0.38)), 0.12),
             (Vector((0.0, -0.05, -0.01)), Vector((0.0, -0.39, 0.012)), 0.1)]
hair_parts = her.hair(POSE, 42, (0.5, 0.62), colliders, 400, combed=0.25, parting=False)
body = skin("body", BODY, levels=1)
body.data.materials.append(cloth_mat)
dress(body)
bare = skin("bare", SKIN_PARTS + fingers(), levels=1)
for v in bare.data.vertices:  # flat hands
    if v.co.y < -0.14 and v.co.z > 0.03:
        v.co.z = 0.097 + (v.co.z - 0.097) * 0.45
bare.data.materials.append(skin_mat)
skin_below_head(bare)
for o in (body, bare):
    her.decimate(o, 1300 if o is body else 700)
# the hair first: Godot's importer never colours a model's first primitive from its vertices, and the hair is the
# one part not coloured per vertex (tests/integration/test_models.gd checks)
parts = hair_parts + [head, eyes, body, bare]
for o in parts:
    print("PART", o.name, triangles(o))
common.select(parts)
bpy.ops.object.join()
fourth = bpy.context.view_layer.objects.active
fourth.name = fourth.data.name = "Fourth"
print("FOURTH tris", triangles(fourth), [m.name for m in fourth.data.materials])
common.export("fourth", [fourth])

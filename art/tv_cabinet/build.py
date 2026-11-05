"""The TV corner: a low chipboard TV cabinet, 2.0 m by 0.45 m and 0.5 m tall, in wood-grain laminate over a dark plinth, with
two doors, the laminate swollen and peeling off the left door's bottom corner where the mop reaches it, rubbed pale along the
door edges by the hands that open it and dusty on top. On it: a flat TV (1.43 m by 0.83 m of glass, 1.45 m by 0.87 m with its
bezel, centred 0.95 m up) on a plate stand, a black satellite decoder on the left with its red standby light, and a white
Wi-Fi router on the right with two antennas and three green lights. No brand names anywhere. Run by tools/models.sh.

Three objects: the cabinet and everything on it as one baked mesh, the TV's glass as a flat quad with a plain glossy black
material (not baked), and the four lights as boxes sharing one emissive material (a 2 by 1 pixel picture of red and green, read
by their UVs). The origin is the centre of the cabinet's footprint on the floor; the front faces -Y like every model's.

The glass lies 3 mm behind the front of the `tv` Interactable's click box (apartment_builder.gd OBJECTS: 1.4 by 0.8 m, its front
0.30 m from the cabinet's centre), which is no longer drawn: the glass is what the player sees there. That puts the TV 7 cm
proud of the cabinet's front, as the old boxes did (4.5 cm).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

node, mapped, maths, lerp, noise = common.node, common.mapped, common.maths, common.lerp, common.noise

# Everything below is in metres; D is how far out in front of the cabinet's centre (Blender -Y), so a part at D is at y = -D.
WIDTH, DEPTH, TOP = 2.0, 0.45, 0.5  # the cabinet; its top panel is 2.5 cm thick
PLINTH = 0.045  # the dark recess under the carcass
DOOR_FRONT, DOOR_BACK = 0.225, 0.207  # doors are 18 mm thick, flush with the top panel's front
HANDLE = (0.06, 0.39)  # each handle's x from the middle, and its centre height
TV_D = (0.267, 0.298)  # the TV's frame: its back and its front
GLASS_D = 0.297  # the TV's glass, 1 mm behind the frame's front
GLASS = (1.43, 0.83, 0.95)  # its width, height and centre height
BEZEL = (1.45, 0.87)
DECODER = (-0.75, 0.0)  # x and D of the decoder's centre
ROUTER = (0.85, -0.05)
PEEL = (-1.0, DOOR_FRONT, 0.05)  # the corner the laminate peels from: x, D and height
LAMINATE, HANDLE_METAL, TV_PLASTIC, DECODER_PLASTIC, ROUTER_PLASTIC = range(5)  # material indices
LIGHTS = [  # (x, D, height of centre), size (x, D, z), colour: u on the 2 by 1 picture
    ((-0.84, 0.112, 0.53), (0.012, 0.004, 0.008), 0.25),  # the decoder's standby light, red
    ((0.80, 0.027, 0.525), (0.008, 0.004, 0.006), 0.75),  # the router's lights, green
    ((0.84, 0.027, 0.525), (0.008, 0.004, 0.006), 0.75),
    ((0.88, 0.027, 0.525), (0.008, 0.004, 0.006), 0.75),
]


# --- geometry -------------------------------------------------------------------------------------------

def added(bm: bmesh.types.BMesh, draw) -> list:
    """Runs draw(bm) and returns the vertices it made."""
    old = set(bm.verts)
    draw(bm)
    return [v for v in bm.verts if v not in old]


def antenna(bm: bmesh.types.BMesh, x: float, lean: float) -> None:
    """A router antenna: a hinge, a round rod, leaning sideways by lean degrees."""
    base = (x, 0.10, TOP + 0.04)  # on the router's top, towards its back
    profile = [(0.0075, 0.0), (0.0075, 0.016), (0.0055, 0.018), (0.0055, 0.232), (0.0042, 0.24), (0.0, 0.242)]
    verts = added(bm, lambda b: common.revolve(b, profile, base, 8, TV_PLASTIC))
    bmesh.ops.rotate(bm, verts=verts, cent=base, matrix=Matrix.Rotation(math.radians(lean), 3, "Y"))


def cabinet() -> bpy.types.Object:
    bm = bmesh.new()
    L = LAMINATE
    common.box(bm, (0.0, 0.0, PLINTH / 2), (WIDTH - 0.04, DEPTH - 0.04, PLINTH), L)  # the plinth, inset 2 cm
    body_d = DOOR_BACK + DEPTH / 2  # the carcass runs from the back (D = -0.225) to the doors
    common.box(bm, (0.0, -(DOOR_BACK - DEPTH / 2) / 2, (PLINTH + TOP - 0.025) / 2), (WIDTH, body_d, TOP - 0.025 - PLINTH), L)
    common.chamfered_box(bm, (0.0, 0.0, TOP - 0.0125), (WIDTH, DEPTH, 0.025), 0.003, L)  # the top panel
    for s in (-1, 1):  # two doors, a 4 mm seam between them
        common.chamfered_box(bm, (s * 0.5, -(DOOR_FRONT + DOOR_BACK) / 2, 0.262), (0.996, DOOR_FRONT - DOOR_BACK, 0.42), 0.002, L)
        x, d = s * HANDLE[0], DOOR_FRONT
        common.chamfered_box(bm, (x, -(d + 0.011), HANDLE[1]), (0.010, 0.010, 0.11), 0.002, HANDLE_METAL)
        for z in (HANDLE[1] - 0.045, HANDLE[1] + 0.045):
            common.box(bm, (x, -(d + 0.0045), z), (0.007, 0.009, 0.007), HANDLE_METAL)
    # The TV: a frame round the glass (which is its own object), the swell on its back, the neck down to a plate on the cabinet.
    side, mid = (BEZEL[0] - GLASS[0]) / 2, (TV_D[0] + TV_D[1]) / 2
    for s in (-1, 1):
        common.box(bm, (s * (GLASS[0] + side) / 2, -mid, GLASS[2]), (side, TV_D[1] - TV_D[0], BEZEL[1]), TV_PLASTIC)
        common.box(bm, (0.0, -mid, GLASS[2] + s * (GLASS[1] + (BEZEL[1] - GLASS[1]) / 2) / 2), (GLASS[0], TV_D[1] - TV_D[0], (BEZEL[1] - GLASS[1]) / 2), TV_PLASTIC)
    swell = added(bm, lambda b: common.chamfered_box(b, (0.0, -0.252, 0.93), (0.84, 0.03, 0.66), 0.004, TV_PLASTIC))
    bm.normal_update()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.y < -0.99 and all(v in swell for v in f.verts)], context="FACES")  # its front is behind the glass
    common.post(bm, TOP + 0.012, 0.62, (0.0, -0.19, 0.12, 0.03), (0.0, -0.252, 0.09, 0.03), TV_PLASTIC)
    common.chamfered_box(bm, (0.0, -0.13, TOP + 0.006), (0.42, 0.17, 0.012), 0.003, TV_PLASTIC)
    # The decoder, with its vent and its display window painted on; the router and its two antennas.
    common.chamfered_box(bm, (DECODER[0], -DECODER[1], TOP + 0.025), (0.30, 0.22, 0.05), 0.003, DECODER_PLASTIC)
    common.chamfered_box(bm, (ROUTER[0], -ROUTER[1], TOP + 0.02), (0.22, 0.15, 0.04), 0.003, ROUTER_PLASTIC)
    antenna(bm, ROUTER[0] - 0.09, 0.0)
    antenna(bm, ROUTER[0] + 0.09, 7.0)
    # Nobody sees undersides, or the backs against the wall.
    bm.normal_update()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99 or f.normal.y > 0.99], context="FACES")
    me = bpy.data.meshes.new("TvCabinet")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("TvCabinet", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def glass() -> bpy.types.Object:
    """The screen: one quad facing out, with the plain glossy black material."""
    bm = bmesh.new()
    w, h, z = GLASS[0] / 2, GLASS[1] / 2, GLASS[2]
    face = bm.faces.new([bm.verts.new(p) for p in ((-w, -GLASS_D, z - h), (w, -GLASS_D, z - h), (w, -GLASS_D, z + h), (-w, -GLASS_D, z + h))])
    bmesh.ops.recalc_face_normals(bm, faces=[face])
    if face.normal.y > 0:
        face.normal_flip()
    me = bpy.data.meshes.new("TvScreen")
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.new("screen")
    mat.use_backface_culling = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.004, 0.004, 0.005, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.1
    me.materials.append(mat)
    obj = bpy.data.objects.new("TvScreen", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def lights() -> bpy.types.Object:
    """The four lights, one emissive material: the red or the green of a 2 by 1 pixel picture, by each box's UVs."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for (x, d, z), size, u in LIGHTS:
        geom = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector((x, -d, z)), None, Vector((size[0], size[1], size[2]))))
        for f in {f for v in geom["verts"] for f in v.link_faces}:
            for loop in f.loops:
                loop[uv].uv = (u, 0.5)
    me = bpy.data.meshes.new("TvLights")
    bm.to_mesh(me)
    bm.free()
    colours = bpy.data.images.new("tv_lights", 2, 1)
    colours.pixels = [1.0, 0.03, 0.02, 1.0, 0.1, 1.0, 0.15, 1.0]
    mat = bpy.data.materials.new("light")
    mat.use_backface_culling = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.01, 0.01, 0.01, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 1.0
    pic = node(nt, "ShaderNodeTexImage", image=colours, interpolation="Closest")
    nt.links.new(pic.outputs["Color"], bsdf.inputs["Emission Color"])
    me.materials.append(mat)
    obj = bpy.data.objects.new("TvLights", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- materials ------------------------------------------------------------------------------------------

def geometry(nt: bpy.types.NodeTree) -> tuple:
    """The face's normal (x, y, z outputs) and the bevel node's rounded normal."""
    flat = node(nt, "ShaderNodeNewGeometry").outputs["Normal"]
    return node(nt, "ShaderNodeSeparateXYZ", {"Vector": flat}).outputs, flat


def edges(nt: bpy.types.NodeTree, flat: bpy.types.NodeSocket, bevelled: bpy.types.NodeSocket, normal) -> bpy.types.NodeSocket:
    """1 along the edges and chamfers, 0 on flat faces square to an axis."""
    square = maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", maths(nt, "ABSOLUTE", normal["X"]), maths(nt, "ABSOLUTE", normal["Y"])), maths(nt, "ABSOLUTE", normal["Z"]))
    return maths(nt, "MAXIMUM", mapped(nt, node(nt, "ShaderNodeVectorMath", {0: bevelled, 1: flat}, operation="DOT_PRODUCT").outputs["Value"], 1.0, 0.8, 0.0, 1.0),
                 mapped(nt, square, 0.97, 0.85, 0.0, 1.0))


def dust_on_top(nt: bpy.types.NodeTree, coords, xyz, normal, strength: float) -> bpy.types.NodeSocket:
    """A film of dust on up-facing surfaces, in broad drifts, a little thicker towards the wall."""
    up = mapped(nt, normal["Z"], 0.5, 0.95, 0.0, 1.0)
    drifts = mapped(nt, noise(nt, coords, 7.0, 3.0), 0.3, 0.7, 0.35, 1.0)
    wall = mapped(nt, maths(nt, "MULTIPLY", xyz["Y"], -1.0), -0.2, 0.2, 1.0, 0.6)  # -y is D, how far out front: thicker at the back
    return maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", up, drifts), maths(nt, "MULTIPLY", wall, strength))


def box_mask(nt: bpy.types.NodeTree, xyz, x: tuple, z: tuple, soft: float = 0.0015) -> bpy.types.NodeSocket:
    """1 inside the x and z ranges, soft edges."""
    return maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", mapped(nt, xyz["X"], x[0] - soft, x[0], 0.0, 1.0), mapped(nt, xyz["X"], x[1], x[1] + soft, 1.0, 0.0)),
                 maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], z[0] - soft, z[0], 0.0, 1.0), mapped(nt, xyz["Z"], z[1], z[1] + soft, 1.0, 0.0)))


def laminate(name: str) -> bpy.types.Material:
    """Dark printed wood grain over chipboard, grain along each panel's long side. Worn: the edges rubbed pale and the front
    greasy round the handles; dust on top; splashed and scuffed at the bottom; and at the left door's bottom corner swollen
    chipboard, the laminate lifting off it along a pale lip."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    normal, flat = geometry(nt)
    bevelled = node(nt, "ShaderNodeBevel", {"Radius": 0.002}, samples=16).outputs["Normal"]

    def stretched(axis: int, along: float, across: float) -> bpy.types.NodeSocket:  # noise drawn out along the grain
        scale = tuple(along if i == axis else across for i in range(3))
        return noise(nt, node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": scale}).outputs["Vector"], 1.0, 3.0)

    def streaks(axis: int) -> bpy.types.NodeSocket:
        return mapped(nt, maths(nt, "ADD", maths(nt, "MULTIPLY", stretched(axis, 3.0, 90.0), 0.6), maths(nt, "MULTIPLY", stretched(axis, 2.0, 24.0), 0.4)), 0.3, 0.7, 0.0, 1.0)

    sideways = maths(nt, "ABSOLUTE", normal["X"])  # the sides' grain runs along Y, the rest along X
    grain = maths(nt, "ADD", maths(nt, "MULTIPLY", streaks(0), maths(nt, "SUBTRACT", 1.0, sideways)), maths(nt, "MULTIPLY", streaks(1), sideways))
    colour = lerp(nt, (0.08, 0.045, 0.026), (0.17, 0.098, 0.058), grain)
    tone = mapped(nt, noise(nt, coords, 1.6, 3.0), 0.35, 0.65, 0.88, 1.08)  # the print is a little different from panel to panel
    colour = node(nt, "ShaderNodeVectorMath", {0: colour, "Scale": tone}, operation="SCALE").outputs["Vector"]
    # Where hands are: a smudge round each handle, the print rubbed pale in a ragged band down the doors' inner edges and along
    # their top edge (and the top panel's front above it), where fingers and thumbs take hold.
    front = mapped(nt, normal["Y"], -0.5, -0.9, 0.0, 1.0)
    across = maths(nt, "ABSOLUTE", xyz["X"])
    handle = node(nt, "ShaderNodeVectorMath", {0: node(nt, "ShaderNodeCombineXYZ", {"X": maths(nt, "SUBTRACT", across, HANDLE[0]), "Z": maths(nt, "SUBTRACT", xyz["Z"], HANDLE[1])}).outputs["Vector"]},
                  operation="LENGTH").outputs["Value"]
    broken = mapped(nt, noise(nt, coords, 14.0, 3.0), 0.3, 0.65, 0.3, 1.0)
    smudge = maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", mapped(nt, handle, 0.1, 0.02, 0.0, 1.0), front), broken)
    seam = maths(nt, "MULTIPLY", mapped(nt, across, 0.05, 0.006, 0.0, 1.0), mapped(nt, xyz["Z"], 0.1, 0.3, 0.0, 1.0))
    thumbs = maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], 0.425, 0.466, 0.0, 1.0), mapped(nt, across, 0.6, 0.15, 0.0, 1.0))
    rubbed = maths(nt, "ADD", maths(nt, "MULTIPLY", maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", seam, thumbs), front), broken), maths(nt, "MULTIPLY", edges(nt, flat, bevelled, normal), 0.2))
    colour = lerp(nt, colour, (0.27, 0.18, 0.105), maths(nt, "MULTIPLY", rubbed, 0.75))  # the chipboard shows through
    colour = lerp(nt, colour, (0.03, 0.02, 0.014), maths(nt, "MULTIPLY", smudge, 0.5))
    # The bottom: mop splashes in drifts and a few pale scuffs from feet.
    low = mapped(nt, xyz["Z"], 0.22, 0.05, 0.0, 1.0)
    splash = maths(nt, "MULTIPLY", low, mapped(nt, noise(nt, coords, 6.0, 3.0), 0.4, 0.7, 0.1, 0.8))
    colour = lerp(nt, colour, (0.05, 0.04, 0.034), maths(nt, "MULTIPLY", splash, 0.6))
    scuff = maths(nt, "MULTIPLY", mapped(nt, xyz["Z"], 0.13, 0.055, 0.0, 1.0), mapped(nt, noise(nt, coords, 11.0, 2.0), 0.58, 0.7, 0.0, 0.7))
    colour = lerp(nt, colour, (0.16, 0.11, 0.075), maths(nt, "MULTIPLY", scuff, front))
    # The peel: a ragged patch about the corner, a dark water stain round it.
    corner = node(nt, "ShaderNodeCombineXYZ", {"X": maths(nt, "DIVIDE", maths(nt, "SUBTRACT", xyz["X"], PEEL[0]), 0.24), "Y": maths(nt, "DIVIDE", maths(nt, "SUBTRACT", xyz["Y"], -PEEL[1]), 0.15),
                                                "Z": maths(nt, "DIVIDE", maths(nt, "SUBTRACT", xyz["Z"], PEEL[2]), 0.17)}).outputs["Vector"]
    reach = node(nt, "ShaderNodeVectorMath", {0: corner}, operation="LENGTH").outputs["Value"]
    field = maths(nt, "ADD", reach, mapped(nt, noise(nt, coords, 16.0, 3.0), 0.3, 0.7, -0.4, 0.4))
    swollen = mapped(nt, field, 0.98, 0.88, 0.0, 1.0)
    stain = maths(nt, "MULTIPLY", mapped(nt, field, 1.5, 0.95, 0.0, 1.0), mapped(nt, noise(nt, coords, 8.0, 3.0), 0.3, 0.7, 0.4, 1.0))
    colour = lerp(nt, colour, (0.035, 0.025, 0.02), maths(nt, "MULTIPLY", stain, 0.7))
    chips = lerp(nt, (0.45, 0.31, 0.18), (0.26, 0.17, 0.1), mapped(nt, noise(nt, coords, 45.0, 4.0), 0.4, 0.65, 0.0, 1.0))  # the chipboard, darker where it is wet
    colour = lerp(nt, colour, chips, swollen)
    cut = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", field, 0.98)), 0.05, 0.0, 0.0, 0.8)  # the laminate's cut edge, curled and pale
    colour = lerp(nt, colour, (0.5, 0.37, 0.24), cut)
    shadow = mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", field, 0.9)), 0.06, 0.0, 0.0, 0.7)  # and the dark crack under it
    colour = lerp(nt, colour, (0.015, 0.01, 0.008), shadow)
    # The dust, then the plinth and the dark gaps.
    dust = dust_on_top(nt, coords, xyz, normal, 0.6)
    colour = lerp(nt, colour, (0.2, 0.185, 0.165), dust)
    colour = lerp(nt, colour, (0.02, 0.016, 0.013), mapped(nt, xyz["Z"], 0.046, 0.044, 0.0, 1.0))
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.05}, samples=32, only_local=True).outputs["AO"]
    colour = lerp(nt, (0.03, 0.02, 0.014), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    rough = maths(nt, "ADD", 0.42, maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", maths(nt, "MAXIMUM", rubbed, dust), maths(nt, "MAXIMUM", swollen, splash)), 0.5))
    step = mapped(nt, field, 0.98, 0.9, 1.0, 0.0)  # the laminate stands proud of the chipboard
    bump = node(nt, "ShaderNodeBump", {"Strength": 0.8, "Distance": 0.003, "Height": step, "Normal": bevelled}).outputs["Normal"]
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    nt.links.new(bump, bsdf.inputs["Normal"])
    return mat


def handle_metal(name: str) -> bpy.types.Material:
    """Aluminium-look bars, dulled and greasy."""
    mat, nt, bsdf, coords = common.surface(name)
    colour = lerp(nt, (0.34, 0.34, 0.33), (0.17, 0.15, 0.12), mapped(nt, noise(nt, coords, 60.0, 3.0), 0.35, 0.65, 0.0, 0.8))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(mapped(nt, noise(nt, coords, 40.0, 3.0), 0.3, 0.7, 0.3, 0.6), bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.4
    return mat


def plastic(name: str, tint: tuple, rough: float, kind: str) -> bpy.types.Material:
    """Aged plastic for the TV (kind "tv"), the decoder and the router: edges scuffed pale, dust on top. The decoder has a vent
    of slots across its top and a smoked window in front; the router a vent at its back and a smoked strip behind its lights."""
    mat, nt, bsdf, coords = common.surface(name)
    xyz = node(nt, "ShaderNodeSeparateXYZ", {"Vector": coords}).outputs
    normal, flat = geometry(nt)
    bevelled = node(nt, "ShaderNodeBevel", {"Radius": 0.002}, samples=8).outputs["Normal"]
    colour = lerp(nt, tuple(c * 0.8 for c in tint), tuple(c * 1.1 for c in tint), mapped(nt, noise(nt, coords, 6.0, 3.0), 0.35, 0.65, 0.0, 1.0))
    scuffs = maths(nt, "MULTIPLY", edges(nt, flat, bevelled, normal), mapped(nt, noise(nt, coords, 40.0, 3.0), 0.3, 0.6, 0.3, 1.0))
    colour = lerp(nt, colour, tuple(min(c * 2.2 + 0.03, 1.0) for c in tint), maths(nt, "MULTIPLY", scuffs, 0.6))
    up = mapped(nt, normal["Z"], 0.8, 0.99, 0.0, 1.0)  # flat tops only
    front = mapped(nt, normal["Y"], -0.8, -0.95, 0.0, 1.0)
    cut = 0.0
    if kind == "decoder":
        slots = maths(nt, "MULTIPLY", box_mask(nt, xyz, (DECODER[0] - 0.12, DECODER[0] + 0.12), (-1.0, 1.0)), mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", maths(nt, "FRACT", maths(nt, "DIVIDE", xyz["Y"], 0.016)), 0.5)), 0.1, 0.18, 1.0, 0.0))
        cut = maths(nt, "MAXIMUM", maths(nt, "MULTIPLY", slots, maths(nt, "MULTIPLY", up, mapped(nt, maths(nt, "ABSOLUTE", xyz["Y"]), 0.09, 0.07, 0.0, 1.0))),
                    maths(nt, "MULTIPLY", box_mask(nt, xyz, (DECODER[0] - 0.05, DECODER[0] + 0.14), (TOP + 0.014, TOP + 0.038), 0.001), front))
    if kind == "router":
        slots = maths(nt, "MULTIPLY", box_mask(nt, xyz, (ROUTER[0] - 0.08, ROUTER[0] + 0.08), (-1.0, 1.0)), mapped(nt, maths(nt, "ABSOLUTE", maths(nt, "SUBTRACT", maths(nt, "FRACT", maths(nt, "DIVIDE", xyz["Y"], 0.014)), 0.5)), 0.1, 0.18, 1.0, 0.0))
        behind = mapped(nt, xyz["Y"], 0.01, 0.04, 0.0, 1.0)  # y is -D: the back half
        cut = maths(nt, "MAXIMUM", maths(nt, "MULTIPLY", slots, maths(nt, "MULTIPLY", up, behind)),
                    maths(nt, "MULTIPLY", box_mask(nt, xyz, (ROUTER[0] - 0.09, ROUTER[0] + 0.09), (TOP + 0.014, TOP + 0.036), 0.001), front))
    colour = lerp(nt, colour, tuple(c * 0.12 for c in tint), cut)
    dust = dust_on_top(nt, coords, xyz, normal, 0.7 if kind != "router" else 0.45)
    colour = lerp(nt, colour, (0.2, 0.185, 0.165), dust)
    dark = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.03}, samples=16, only_local=True).outputs["AO"]
    colour = lerp(nt, tuple(c * 0.4 for c in tint), colour, mapped(nt, dark, 0.0, 0.8, 0.0, 1.0))
    roughness = maths(nt, "ADD", rough, maths(nt, "MULTIPLY", maths(nt, "MAXIMUM", dust, scuffs), 0.4))
    nt.links.new(colour, bsdf.inputs["Base Color"])
    nt.links.new(roughness, bsdf.inputs["Roughness"])
    nt.links.new(bevelled, bsdf.inputs["Normal"])
    return mat


# --- build ----------------------------------------------------------------------------------------------

common.reset()
body = cabinet()
for m in (laminate("laminate"), handle_metal("handle"), plastic("tv", (0.016, 0.016, 0.018), 0.4, "tv"), plastic("decoder", (0.012, 0.012, 0.014), 0.3, "decoder"),
          plastic("router", (0.66, 0.62, 0.5), 0.42, "router")):
    body.data.materials.append(m)
me = body.data
me.set_sharp_from_angle(angle=math.radians(50))
common.bake(body, pack=True)
common.export("tv_cabinet", [body, glass(), lights()])

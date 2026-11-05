"""The living room's wall clock: the cheap round plastic kind, 30 cm across and 4 cm deep. A yellowed rim, an
off-white printed face under a scuffed clear cover (glossy, not transparent), black hour and minute hands that
the game turns, and a thin red second hand stopped at 12: the battery died long ago. Run by tools/models.sh.

The numerals are set in Inter, the font Blender ships, rendered into the face's print before the bake.
"""
import math
import os
import sys
import tempfile

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

SEGMENTS = 48
DIAL_R = 0.1275
DIAL_Y = -0.024  # the printed face, 2.4 cm out from the wall (the front is -Y)
# The case, turned about the dial's axis: (radius, depth) from the wall, round the front lip, into the dial.
CASE = [(0.146, 0.0), (0.149, -0.012), (0.150, -0.026), (0.148, -0.034), (0.144, -0.0385), (0.139, -0.040),
        (0.134, -0.039), (0.131, -0.036), (0.129, -0.031), (DIAL_R, DIAL_Y)]
LIP = 7  # bands from here on are the inner wall, in the lip's shadow
# Hands: outline (x, height above the centre) pointing up, depth of the front face, thickness.
HOUR = ([(-0.0034, -0.017), (0.0034, -0.017), (0.0034, 0.058), (0.0, 0.074), (-0.0034, 0.058)], -0.0266, 0.0006)
MINUTE = ([(-0.0024, -0.022), (0.0024, -0.022), (0.0024, 0.1), (0.0, 0.114), (-0.0024, 0.1)], -0.0280, 0.0006)
SECOND = [(-0.0007, -0.027), (0.0007, -0.027), (0.0005, 0.112), (0.0, 0.116), (-0.0005, 0.112)]
SECOND_Y = -0.0293
HUB = (0.0055, -0.0305)  # radius, front
PAPER = (0.84, 0.82, 0.76)
INK = (0.03, 0.03, 0.03)
YELLOWED = (0.78, 0.72, 0.54)


# --- geometry -------------------------------------------------------------------------------------------

def ring(r: float, y: float, i: int, segments: int = SEGMENTS) -> Vector:
    a = math.tau * i / segments
    return Vector((r * math.sin(a), y, r * math.cos(a)))


def facing_front(bm: bmesh.types.BMesh, verts: list) -> bmesh.types.BMFace:
    face = bm.faces.new(verts)
    face.normal_update()
    if face.normal.y > 0.0:
        face.normal_flip()
    return face


def body(materials: list) -> bpy.types.Object:
    """The case (rim, then the inner wall), the dial with its print mapped across it, the hub and the
    second hand. materials: rim, inner wall, dial, black, red."""
    bm = bmesh.new()
    rings = [[bm.verts.new(ring(r, y, i)) for i in range(SEGMENTS)] for r, y in CASE]
    for b in range(len(CASE) - 1):
        for i in range(SEGMENTS):
            j = (i + 1) % SEGMENTS
            f = bm.faces.new([rings[b][i], rings[b + 1][i], rings[b + 1][j], rings[b][j]])
            f.material_index = 0 if b < LIP else 1
            f.smooth = True
    uv = bm.loops.layers.uv.new("UVMap")
    face = facing_front(bm, [bm.verts.new(ring(DIAL_R, DIAL_Y, i)) for i in range(SEGMENTS)])
    face.material_index = 2
    for loop in face.loops:
        loop[uv].uv = (loop.vert.co.x / (2 * DIAL_R) + 0.5, loop.vert.co.z / (2 * DIAL_R) + 0.5)
    hub = [[bm.verts.new(ring(HUB[0], y, i, 12)) for i in range(12)] for y in (DIAL_Y, HUB[1])]
    for i in range(12):
        f = bm.faces.new([hub[0][i], hub[1][i], hub[1][(i + 1) % 12], hub[0][(i + 1) % 12]])
        f.material_index = 3
        f.smooth = True
    facing_front(bm, hub[1]).material_index = 3
    facing_front(bm, [bm.verts.new((x, SECOND_Y, z)) for x, z in SECOND]).material_index = 4
    weight = facing_front(bm, [bm.verts.new(ring(0.0045, SECOND_Y + 0.0002, i, 10) + Vector((0, 0, -0.022))) for i in range(10)])
    weight.material_index = 4
    return common.mesh_object("WallClock", bm, materials, bpy.context.scene)


def hand(name: str, spec: tuple, black: bpy.types.Material) -> bpy.types.Object:
    """A stamped hand: its outline at its depth, and edges back towards the dial (no back face). Its vertex
    group names it, so it can be split off again after the bake."""
    outline, front, thickness = spec
    bm = bmesh.new()
    face = facing_front(bm, [bm.verts.new((x, front, z)) for x, z in outline])
    rim = [loop.vert for loop in face.loops]
    back = {v: bm.verts.new(v.co + Vector((0, thickness, 0))) for v in rim}
    for a, b in zip(rim, rim[1:] + rim[:1]):
        bm.faces.new([b, a, back[a], back[b]])  # each edge walked against the face's own direction: outwards
    obj = common.mesh_object(name, bm, [black], bpy.context.scene)
    obj.vertex_groups.new(name=name).add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    return obj


# --- materials ------------------------------------------------------------------------------------------

def material(name: str, color: tuple, roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def mapped_noise(nt: bpy.types.NodeTree, scale: float, lo: float, hi: float, a: float, b: float) -> bpy.types.NodeSocket:
    """Noise in object space, its values from lo to hi mapped to a..b (clamped)."""
    coords = common.node(nt, "ShaderNodeTexCoord").outputs["Object"]
    tex = common.node(nt, "ShaderNodeTexNoise", {"Vector": coords, "Scale": scale, "Detail": 6.0}).outputs["Fac"]
    return common.node(nt, "ShaderNodeMapRange", {"Value": tex, "From Min": lo, "From Max": hi, "To Min": a, "To Max": b}).outputs["Result"]


def scaled(nt: bpy.types.NodeTree, color, factor: bpy.types.NodeSocket) -> bpy.types.NodeSocket:
    """A colour (a value or a socket) times a factor."""
    return common.node(nt, "ShaderNodeVectorMath", {0: color, "Scale": factor}, operation="SCALE").outputs["Vector"]


def plastic(name: str, color: tuple) -> bpy.types.Material:
    """Yellowed plastic, greyed here and there by years of kitchen air."""
    mat = material(name, color, 0.5)
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(scaled(nt, color, mapped_noise(nt, 18.0, 0.3, 0.7, 0.84, 1.0)), bsdf.inputs["Base Color"])
    nt.links.new(mapped_noise(nt, 40.0, 0.3, 0.7, 0.42, 0.62), bsdf.inputs["Roughness"])
    return mat


def dial(print_image: bpy.types.Image) -> bpy.types.Material:
    """The printed face as seen through the cover: darker towards the rim, aged unevenly, and glossy with
    the cover's scratches and smudges."""
    mat = material("dial", PAPER, 0.1)
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    printed = common.node(nt, "ShaderNodeTexImage", image=print_image).outputs["Color"]
    flat = common.node(nt, "ShaderNodeMapping", {"Vector": common.node(nt, "ShaderNodeTexCoord").outputs["Object"], "Scale": (1.0, 0.0, 1.0)})
    r = common.node(nt, "ShaderNodeVectorMath", {0: flat.outputs["Vector"]}, operation="LENGTH").outputs["Value"]
    rim_shadow = common.node(nt, "ShaderNodeMapRange", {"Value": r, "From Min": 0.108, "From Max": DIAL_R, "To Min": 1.0, "To Max": 0.6}).outputs["Result"]
    aged = common.node(nt, "ShaderNodeMath", {0: rim_shadow, 1: mapped_noise(nt, 6.0, 0.35, 0.65, 0.94, 1.0)}, operation="MULTIPLY").outputs["Value"]
    nt.links.new(scaled(nt, printed, aged), bsdf.inputs["Base Color"])
    scratches = mapped_noise(nt, 70.0, 0.5, 0.515, 0.38, 0.08)  # thin contour lines of a fine noise
    smudges = mapped_noise(nt, 7.0, 0.4, 0.7, 0.1, 0.2)
    rough = common.node(nt, "ShaderNodeMath", {0: scratches, 1: smudges}, operation="MAXIMUM").outputs["Value"]
    nt.links.new(rough, bsdf.inputs["Roughness"])
    return mat


def emission(name: str, color: tuple) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    nt = mat.node_tree
    shader = common.node(nt, "ShaderNodeEmission", {"Color": (*color, 1.0)}).outputs["Emission"]
    nt.links.new(shader, nt.nodes["Material Output"].inputs["Surface"])
    return mat


def render_print(size: int = 1024) -> bpy.types.Image:
    """The face's print, flat, in a scene of its own: the hour numerals, the minute track and QUARTZ in ink
    on the paper, filling the image edge to edge across the dial."""
    scene = bpy.data.scenes.new("print")
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.view_settings.view_transform = "Standard"
    ink = emission("ink", INK)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=DIAL_R * 2, matrix=Matrix.Rotation(math.pi / 2, 4, "X"))
    common.mesh_object("paper", bm, [emission("paper", PAPER)], scene)
    bm = bmesh.new()  # the minute track: a tick every minute, a heavier one every five
    for i in range(60):
        w, inner = (0.0026, 0.1145) if i % 5 == 0 else (0.0012, 0.1185)
        turn = Matrix.Rotation(math.tau * i / 60, 4, "Y")
        bm.faces.new([bm.verts.new(turn @ Vector((x, -0.001, z))) for x, z in [(-w / 2, inner), (w / 2, inner), (w / 2, 0.1225), (-w / 2, 0.1225)]])
    common.mesh_object("track", bm, [ink], scene)
    font = bpy.data.fonts.load(os.path.join(bpy.utils.system_resource("DATAFILES", path="fonts"), "Inter.woff2"))
    texts = [(str(h), 0.1 * math.sin(math.tau * h / 12), 0.1 * math.cos(math.tau * h / 12), 0.03) for h in range(1, 13)]
    for text, x, z, height in texts + [("QUARTZ", 0.0, -0.042, 0.0068)]:
        curve = bpy.data.curves.new(text, type="FONT")
        curve.body = text
        curve.font = font
        curve.size = height
        curve.offset = height * 0.012  # a heavier weight, as printed
        curve.space_character = 1.0 if height > 0.01 else 1.3
        curve.align_x = curve.align_y = "CENTER"
        curve.materials.append(ink)
        obj = bpy.data.objects.new(text, curve)
        obj.location = (x, -0.001, z)
        obj.rotation_euler = (math.pi / 2, 0, 0)
        scene.collection.objects.link(obj)
    cam = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = DIAL_R * 2
    cam.location = (0, -1, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    with tempfile.TemporaryDirectory() as tmp:
        scene.render.filepath = os.path.join(tmp, "print.png")
        bpy.ops.render.render(write_still=True, scene=scene.name)
        bpy.data.scenes.remove(scene)
        image = bpy.data.images.load(os.path.join(tmp, "print.png"))
        image.pack()  # read now: the directory goes away
    return image


# --- build ----------------------------------------------------------------------------------------------

common.reset()
black = material("black", (0.02, 0.02, 0.02), 0.35)
clock = body([plastic("rim", YELLOWED), plastic("inner", tuple(c * 0.68 for c in YELLOWED)), dial(render_print()), black,
              material("red", (0.55, 0.05, 0.035), 0.4)])
parts = [hand("HourHand", HOUR, black), hand("MinuteHand", MINUTE, black)]
common.select([clock] + parts)
bpy.ops.object.join()
clock.data.set_sharp_from_angle(angle=math.radians(35))
common.bake(clock)
hands = [common.split_off(clock, p, Vector((0, DIAL_Y, 0))) for p in ["HourHand", "MinuteHand"]]
clock.vertex_groups.clear()
common.export("wall_clock", [clock] + hands)

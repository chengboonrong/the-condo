"""The dining chair to go with dining_table: cheap rubberwood, a 0.42 m square seat at 0.45 m, four tapered legs,
rails and side stretchers, and a ladder back of three slats and an arched crest rail up to 0.9 m. The stain is the
table's; the seat is four glued boards, grubby and pale at the front edge, the back's top rail rubbed bare. Run by
tools/models.sh.

The origin is the floor below the seat's centre. The chair's front faces -Y, its back is at +Y: the back's stiles
are the rear legs carried up, leaning back a little.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

SEAT = 0.42  # square
SEAT_Z = (0.425, 0.45)
LEG = 0.18  # the legs' centres, either way from the middle
APRON = (0.375, 0.425)  # the rails under the seat ...
RAIL = LEG + 0.0045  # ... sit back a few millimetres from the legs' faces
TOP = 0.9
LEAN = 0.012  # how far the stiles' tops sit behind their feet
SEAT_BOARD, LEG_WOOD, RAIL_X, RAIL_Y = range(4)  # material indices


def back_y(z: float) -> float:
    """Where the back's stiles stand, front to back, at height z."""
    return LEG + LEAN * (z - SEAT_Z[0]) / (TOP - SEAT_Z[0])


def crest(bm: bmesh.types.BMesh) -> None:
    """The top rail: flat underneath, arched on top, between the stiles."""
    half, thick = 0.17, 0.02
    points = [(-half, 0.775), (half, 0.775)]
    for k in range(9):  # the arch, right to left
        x = half * (1 - k / 4)
        points.append((x, 0.855 + 0.035 * (1 - (x / half) ** 2)))
    y = back_y(0.83)
    front = [bm.verts.new((x, y - thick / 2, z)) for x, z in points]
    back = [bm.verts.new((x, y + thick / 2, z)) for x, z in points]
    n = len(points)
    faces = [bm.faces.new(front), bm.faces.new(back[::-1])]
    faces += [bm.faces.new([front[i], front[(i + 1) % n], back[(i + 1) % n], back[i]]) for i in range(n)]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for f in faces:
        f.material_index = RAIL_X


common.reset()
bm = bmesh.new()
common.slab(bm, (0.0, 0.0), (SEAT, SEAT), SEAT_Z[0], SEAT_Z[1], 0.025, 0.004, SEAT_BOARD)
for sx in (-1, 1):
    x = sx * LEG
    common.post(bm, 0.0, SEAT_Z[0], (x, -LEG, 0.026, 0.026), (x, -LEG, 0.035, 0.035), LEG_WOOD)  # front legs
    common.post(bm, 0.0, SEAT_Z[0], (x, LEG, 0.026, 0.026), (x, LEG, 0.035, 0.035), LEG_WOOD)  # rear legs ...
    common.post(bm, SEAT_Z[0], TOP, (x, back_y(SEAT_Z[0]), 0.032, 0.026), (x, back_y(TOP), 0.032, 0.022), LEG_WOOD)  # ... and the stiles above them
    common.box(bm, (sx * RAIL, 0.0, (APRON[0] + APRON[1]) / 2), (0.018, 2 * LEG - 0.015, APRON[1] - APRON[0]), RAIL_Y)  # side rails
    common.box(bm, (x, 0.0, 0.17), (0.022, 2 * LEG - 0.015, 0.022), RAIL_Y)  # side stretchers
for sy in (-1, 1):
    common.box(bm, (0.0, sy * RAIL, (APRON[0] + APRON[1]) / 2), (2 * LEG - 0.015, 0.018, APRON[1] - APRON[0]), RAIL_X)  # front and back rails
common.box(bm, (0.0, LEG, 0.17), (2 * LEG - 0.015, 0.022, 0.022), RAIL_X)  # the stretcher between the rear legs
for z in (0.53, 0.62, 0.71):
    common.box(bm, (0.0, back_y(z), z), (2 * LEG - 0.02, 0.014, 0.045), RAIL_X)  # the back's slats
crest(bm)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99], context="FACES")  # undersides and feet: nobody sees them
me = bpy.data.meshes.new("DiningChair")
bm.to_mesh(me)
bm.free()
stain = (0.14, 0.066, 0.032)
for m in (common.wood("seat", stain, 0, (-SEAT / 2, SEAT / 4)), common.wood("leg", (0.125, 0.056, 0.027), 2),
          common.wood("rail_x", (0.135, 0.06, 0.029), 0), common.wood("rail_y", (0.135, 0.06, 0.029), 1)):
    me.materials.append(m)
chair = bpy.data.objects.new("DiningChair", me)
bpy.context.scene.collection.objects.link(chair)
me.set_sharp_from_angle(angle=math.radians(50))
common.bake(chair, pack=True)
common.export("dining_chair", [chair])

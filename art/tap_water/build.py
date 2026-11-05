"""The water running from the basin's tap: a thin stream falling from the spout (the origin) to the bowl's floor,
narrowing as it falls and flaring into a splash where it lands. One plain material, not baked: Godot's
(0.6, 0.8, 1.0) at 0.6 alpha, roughness 0.1, blended. Run by tools/models.sh.

basin/build.py puts the spout at SPOUT, 0.144 m above its bowl floor: DROP is that, and a little into the floor.
"""
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

DROP = 0.147
# (radius, height): the splash at the foot, then the stream, a little wider at the top. The top ends inside the spout.
PROFILE = [(0.017, -DROP), (0.0115, -DROP + 0.005), (0.0075, -DROP + 0.016), (0.0055, -0.11), (0.0062, -0.05), (0.0072, 0.0), (0.0072, 0.003), (0.0, 0.003)]


def linear(c: float) -> float:
    """An sRGB channel as Blender's linear one: glTF holds linear and Godot shows it back as sRGB."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


common.reset()
bm = bmesh.new()
common.revolve(bm, PROFILE, (0.0, 0.0, 0.0), 10, 0)
me = bpy.data.meshes.new("TapWater")
bm.to_mesh(me)
bm.free()
mat = bpy.data.materials.new("water")
mat.surface_render_method = "BLENDED"
mat.use_backface_culling = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (linear(0.6), linear(0.8), linear(1.0), 1.0)
bsdf.inputs["Alpha"].default_value = 0.6
bsdf.inputs["Roughness"].default_value = 0.1
me.materials.append(mat)
water = bpy.data.objects.new("TapWater", me)
bpy.context.scene.collection.objects.link(water)
common.export("tap_water", [water])

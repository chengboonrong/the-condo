class_name CarRig
extends Node3D
## The couple's hatchback (assets/models/hatchback.glb) as the road uses it: where it stands on the road, its seats and
## mirror mount, its rear left door as something he can use, its lights, and the materials it draws with. The model's
## origin is the ground at the centre of the wheelbase, facing +Z, with its left at +X.

const DOOR_OPEN := 60.0  # degrees the rear left door swings out when he gets in
const HEADLIGHT := Color(1.0, 0.93, 0.8)
const TAIL := Color(0.9, 0.05, 0.03)
const DASH := Color(1.0, 0.6, 0.25)
const BEAM := 14.0  # metres of each headlight's cone in the fog
const CLEAR := 0.35  # metres he must be from its body before it turns solid: his capsule's radius and a little
const GLARE_AHEAD := 0.18  # metres the glare sits ahead of the lamp, so the housing and nose never hide its centre
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 color : source_color;
uniform float beam = 14.0;
varying float along;  // 0 at the lamp, 1 at the cone's far end

void vertex() {
	along = 0.5 + VERTEX.y / beam;
}

void fragment() {
	float fade = (1.0 - along) * (1.0 - along) * smoothstep(0.0, 0.1, along);
	ALBEDO = color.rgb;
	// gone close to the camera, so from beside the beam or behind the lamp its near side never fills the view
	float dist = length(VERTEX);
	ALPHA = color.a * fade * sqrt(abs(dot(NORMAL, VIEW))) * smoothstep(2.0, 7.0, dist) * exp(-0.03 * dist);
}
"""
## A headlamp's glare in the fog: a soft disc that faces the camera, seen only from in front of the lamp.
const GLARE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 color : source_color;
varying float facing;

void vertex() {
	facing = dot(normalize(-MODEL_MATRIX[2].xyz), normalize(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = min(length(UV - 0.5) * 2.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = color.a * pow(1.0 - r, 3.0) * smoothstep(0.0, 0.7, facing) * exp(-0.02 * length(VERTEX));
}
"""

var seat_driver: Node3D
var seat_front: Node3D
var seat_rear_left: Node3D  # his
var seat_rear_right: Node3D  # the fourth's
var mirror_mount: Node3D
var mirror: Mirror  # on mirror_mount, with the fourth passenger in the rear right seat
var door_rear_left: Interactable  # car_door from outside; car_door_inside once he sits
var headlights: Array[SpotLight3D] = []

var _model: Node3D
var _footprint: AABB  # the body and the shut door, in the car's own space
var _colliders: Array[CollisionShape3D] = []
var _still := false  # it stood still at the last set_solid
var _on_him := false  # it stopped where he stood, and he has not yet stepped clear of it


## Where a vehicle stands at s, `across` metres left of the centreline, nose along the road (or up it), pitched with
## the grade.
static func on_road(s: float, across: float, uphill := false) -> Transform3D:
	var fwd := RoadLayout.tangent(s) * (-1.0 if uphill else 1.0)
	var left := Vector3(fwd.z, 0.0, -fwd.x).normalized()
	return Transform3D(Basis(left, fwd.cross(left), fwd), RoadLayout.point(s, across))


func _ready() -> void:
	_model = ApartmentBuilder.model(&"hatchback")
	add_child(_model)
	seat_driver = _model.get_node("seat_driver")
	seat_front = _model.get_node("seat_front")
	seat_rear_left = _model.get_node("seat_rear_left")
	seat_rear_right = _model.get_node("seat_rear_right")
	mirror_mount = _model.get_node("mirror_mount")
	mirror = Mirror.new(seat_rear_right)
	mirror.name = "Mirror"
	mirror_mount.add_child(mirror)
	var body: MeshInstance3D = _model.get_node("hatchback")
	# A box he can't walk through, inside the door's skin so that a look at the door finds the door first.
	var box := body.get_aabb()
	_footprint = AABB(Vector3(-0.78, box.position.y, box.position.z), Vector3(1.56, box.size.y, box.size.z))
	var solid := StaticBody3D.new()
	_colliders.append(_collider(_footprint))
	solid.add_child(_colliders[-1])
	add_child(solid)
	var door: MeshInstance3D = _model.get_node("door_rear_left")
	door_rear_left = Interactable.new()
	door_rear_left.name = "RearLeftDoor"
	door_rear_left.object_id = &"car_door"
	door_rear_left.prompt = ""  # only usable while a mission prompts it
	door_rear_left.transform = door.transform
	_model.add_child(door_rear_left)
	door.reparent(door_rear_left, false)
	door.transform = Transform3D.IDENTITY
	_colliders.append(_collider(door.get_aabb()))
	door_rear_left.add_child(_colliders[-1])
	_footprint = _footprint.merge(door_rear_left.transform * door.get_aabb())
	_build_lights(body)


func place(s: float, across: float) -> void:
	global_transform = on_road(s, across)


## Solid while he sits in it (his own collision is off then) and while it stands still, but never while it moves, so
## it can't shove him. If it stops where he stands (`him`, his feet), it stays not solid until he has stepped clear,
## so it can't shut him in; walking up to a car that already stands there never makes it not solid.
func set_solid(still: bool, seated: bool, him: Vector3) -> void:
	var at := global_transform.affine_inverse() * him
	at.y = _footprint.get_center().y
	var over := _footprint.grow(CLEAR).has_point(at)
	if seated:
		_on_him = false
	elif still and not _still:  # it has just stopped
		_on_him = over
	elif not over:
		_on_him = false
	_still = still
	var on := seated or (still and not _on_him)
	for c in _colliders:
		c.disabled = not on


## He opens the rear left door from outside, gets in and pulls it shut from inside.
func swing_door() -> void:
	EventBus.sound_requested.emit(&"car_door_open", door_rear_left.global_position, 0.0)
	var tween := create_tween()
	tween.tween_property(door_rear_left, "rotation:y", -deg_to_rad(DOOR_OPEN), 0.35)
	tween.tween_interval(0.4)
	tween.tween_property(door_rear_left, "rotation:y", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: EventBus.sound_requested.emit(&"car_door_close", door_rear_left.global_position, 0.0))


## Every material it draws with, for the start card's warm-up.
func materials() -> Array[Material]:
	var out: Array[Material] = []
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat != null and not out.has(mat):
				out.append(mat)
	return out


## Two unshadowed headlights, each with an additive cone that shows in the fog; the lenses and the tail lamps lit;
## and the dash's glow, a short amber spot from the gauges aimed back and down onto the seat backs, so it never
## lights the headliner through the cluster's hood.
func _build_lights(body: MeshInstance3D) -> void:
	var cone_material := ShaderMaterial.new()
	cone_material.shader = Shader.new()
	cone_material.shader.code = BEAM_SHADER
	cone_material.set_shader_parameter(&"color", Color(HEADLIGHT, 0.2))
	cone_material.set_shader_parameter(&"beam", BEAM)
	var glare_material := ShaderMaterial.new()
	glare_material.shader = Shader.new()
	glare_material.shader.code = GLARE_SHADER
	glare_material.set_shader_parameter(&"color", Color(HEADLIGHT, 0.9))
	for side: String in ["l", "r"]:
		var spot := SpotLight3D.new()
		spot.light_color = HEADLIGHT
		spot.light_energy = 3.0
		spot.light_specular = 0.1  # the asphalt's sheen toward someone in front of the car stays off white
		spot.spot_range = 45.0
		spot.spot_angle = 20.0
		spot.spot_angle_attenuation = 1.5
		spot.spot_attenuation = 0.3  # a dipped beam lights the road far ahead, not a pool at the bumper
		spot.shadow_enabled = false  # only the phone light casts shadows
		spot.rotation.x = deg_to_rad(-2.0)  # dipped
		var lamp: Node3D = _model.get_node("headlight_" + side)
		lamp.add_child(spot)
		headlights.append(spot)
		var glare := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 1.6)
		glare.mesh = quad
		glare.material_override = glare_material
		glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glare.position.z = -GLARE_AHEAD
		lamp.add_child(glare)
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = tan(deg_to_rad(spot.spot_angle)) * BEAM * 0.6  # the far end: the beam's bright core
		mesh.bottom_radius = 0.08
		mesh.height = BEAM
		mesh.radial_segments = 16
		mesh.rings = 1
		mesh.cap_top = false
		mesh.cap_bottom = false
		cone.mesh = mesh
		cone.material_override = cone_material
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = -PI / 2.0  # the cylinder's +Y, its far end, along the light's -Z
		cone.position = Vector3(0.0, 0.0, -BEAM / 2.0)
		spot.add_child(cone)
	_glow(body, &"headlight_lens", HEADLIGHT, 8.0)
	_glow(body, &"taillight_lens", TAIL, 1.5)
	var dash := SpotLight3D.new()
	dash.light_color = DASH
	dash.light_energy = 0.6
	dash.spot_range = 1.5
	dash.spot_angle = 55.0
	dash.shadow_enabled = false
	dash.rotation.x = -0.45  # its -Z is the back of the car: tipped down onto the front seats' backs
	(_model.get_node("dash_glow") as Node3D).add_child(dash)
	# The fog's grey through the rear and side windows, just enough to give the front seats' backs their shape.
	var fill := SpotLight3D.new()
	fill.light_color = Color(0.55, 0.6, 0.7)
	fill.light_energy = 0.35
	fill.spot_range = 2.2
	fill.spot_angle = 35.0
	fill.shadow_enabled = false
	fill.position = Vector3(0.0, 1.0, -1.3)
	fill.rotation = Vector3(-0.15, PI, 0.0)  # ahead, a little down
	add_child(fill)


## The model's lens surfaces are plain gloss: a copy of each, lit.
func _glow(body: MeshInstance3D, surface: StringName, color: Color, energy: float) -> void:
	for i in body.mesh.get_surface_count():
		var mat := body.mesh.surface_get_material(i)
		if mat != null and mat.resource_name == surface:
			var lit := mat.duplicate() as StandardMaterial3D
			lit.emission_enabled = true
			lit.emission = color
			lit.emission_energy_multiplier = energy
			body.set_surface_override_material(i, lit)


static func _collider(box: AABB) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = box.get_center()
	return collider

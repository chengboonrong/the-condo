class_name Couple
extends Node3D
## Hafiz and Mei in the front seats of the couple's car (CarRig): Hafiz drives with one hand on the wheel, and Mei sits
## beside him with her phone, its screen lighting her face from below. They turn when they speak (EventBus.road_line):
## Mei turns her head and shoulders to him in the back seat, and Hafiz glances up at the mirror.

const TURN := 0.5  # seconds to turn, and to turn back
const GLANCE := 1.2  # seconds Hafiz takes his eyes off the road for the mirror
## Mei's turn to the back seat, over her left shoulder: her chest twists left and leans in towards the middle of the
## car, and her head turns on round, so from his seat her eyes show over her headrest, on him. rotation.y > 0 is to her
## left.
const MEI_CHEST := Vector3(0.0, deg_to_rad(35.0), deg_to_rad(20.0))
const MEI_HEAD := Vector3(0.0, deg_to_rad(80.0), 0.0)
## Her phone's screen as she sits facing the road, in her head's space (measured on the model): its centre, and the way
## it faces, up at her face.
const SCREEN := Vector3(-0.035, -0.188, 0.316)
const SCREEN_FACING := Vector3(0.1, 0.74, -0.66)
## Her hair's light: the model's, as a rough surface with no shine to speak of, and the light from beyond her that the
## edges of her hair scatter towards the eye, as real hair does against a lamp. Her phone and the dash are ahead of her,
## so from the back seat this is what shows her bob, in clumps; seen from in front, they add none of it.
const HAIR_SHADER := """
shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float roughness = 0.8;
uniform float halo = 2.0;
uniform vec3 tint = vec3(1.0, 0.6, 0.44);  // the light warms a little coming through her brown hair

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	ROUGHNESS = roughness;
}

void light() {
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	float beyond = max(dot(-LIGHT, VIEW), 0.0);  // 1 with the light straight beyond her hair from the eye
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	SPECULAR_LIGHT += halo * beyond * beyond * pow(edge, 4.0) * ATTENUATION * LIGHT_COLOR * tint;
}
"""

var hafiz: Node3D
var mei: Node3D

var _car: CarRig
var _his_head: Node3D
var _her_chest: Node3D
var _her_head: Node3D
var _mirror := Vector3.ZERO  # his head's rotation when it faces the mirror
var _his_left := 0.0  # seconds each stays turned
var _her_left := 0.0
var _his_turn := 0.0  # 0 facing the road, 1 turned
var _her_turn := 0.0


func _init(car: CarRig) -> void:
	name = "Couple"
	_car = car


func _ready() -> void:
	hafiz = _seat(&"hafiz_seated", _car.seat_driver)
	mei = _seat(&"mei_seated", _car.seat_front)
	_his_head = hafiz.get_node("Head")
	_her_chest = mei.get_node("Chest")
	_her_head = _her_chest.get_node("Head")
	var hair_shader := Shader.new()
	hair_shader.code = HAIR_SHADER
	for m: MeshInstance3D in mei.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var hair := m.get_active_material(i) as BaseMaterial3D
			if hair != null and hair.resource_name == "hair":
				var lit := ShaderMaterial.new()
				lit.shader = hair_shader
				lit.set_shader_parameter("albedo_texture", hair.albedo_texture)
				lit.set_shader_parameter("roughness", hair.roughness)
				m.set_surface_override_material(i, lit)
	var to := _his_head.global_transform.affine_inverse() * _car.mirror_mount.global_position
	_mirror = Vector3(-atan2(to.y, Vector2(to.x, to.z).length()), atan2(to.x, to.z), 0.0)
	# Her screen's glow lights her face from below and, past her, the roof over the front seats. It has no shadow, like
	# every light but his phone's, so it is a wide, dim glow that can pass her head unnoticed, not a beam. It turns with
	# her head, as if she brings the phone round with her: from his seat her seat hides the phone, and her face is what
	# shows.
	var screen := SpotLight3D.new()
	screen.light_color = Color(0.88, 0.9, 0.95)
	screen.light_energy = 0.3
	screen.spot_range = 0.7  # her face and the roof over the front seats, not the side glass behind her
	screen.spot_angle = 60.0
	screen.shadow_enabled = false
	screen.transform = Transform3D(Basis.looking_at(SCREEN_FACING), SCREEN)
	_her_head.add_child(screen)
	EventBus.road_line.connect(turn_to)


## Someone in the car says a line for `seconds`: Mei turns to him for hers, and stays turned through the gap before
## a next line, so two of hers in a row are one turn; Hafiz glances at the mirror for his.
func turn_to(speaker: StringName, seconds: float) -> void:
	match speaker:
		&"mei":
			_her_left = seconds + RoadDirector.LINE_GAP
		&"hafiz":
			_his_left = minf(seconds, GLANCE)


## Every material they draw with, for the start card's warm-up.
func materials() -> Array[Material]:
	var out: Array[Material] = []
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat != null and not out.has(mat):
				out.append(mat)
	return out


func _process(delta: float) -> void:
	_his_left -= delta
	_her_left -= delta
	_his_turn = move_toward(_his_turn, 1.0 if _his_left > 0.0 else 0.0, delta / TURN)
	_her_turn = move_toward(_her_turn, 1.0 if _her_left > 0.0 else 0.0, delta / TURN)
	_his_head.rotation = _mirror * smoothstep(0.0, 1.0, _his_turn)
	var k := smoothstep(0.0, 1.0, _her_turn)
	_her_chest.rotation = MEI_CHEST * k
	_her_head.rotation = MEI_HEAD * k


func _seat(id: StringName, seat: Node3D) -> Node3D:
	var person := ApartmentBuilder.model(id)
	add_child(person)
	person.global_transform = seat.global_transform
	return person

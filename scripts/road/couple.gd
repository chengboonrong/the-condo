class_name Couple
extends Node3D
## Hafiz and Mei in the front seats of the couple's car (CarRig): Hafiz drives with one hand on the wheel, and Mei sits
## beside him with her phone, its screen lighting her face from below. They turn when they speak (EventBus.road_line):
## Mei turns her head and shoulders to him in the back seat, and Hafiz glances up at the mirror. When the car dies,
## Hafiz gets out and walks off down the road with his phone as a torch (hafiz_leaves).

const TURN := 0.5  # seconds to turn, and to turn back
const GLANCE := 1.2  # seconds Hafiz takes his eyes off the road for the mirror
const DOOR_LAYER := 2  # visual layer 2's bit: his door is drawn on it alone, so her screen's glow can leave it out
const OUT := Vector3(-1.2, 0.0, 0.1)  # where Hafiz stands up outside his door, in the car's space
const STAND_UP := 0.45  # seconds from his door opening to him standing outside it
const SET_OFF := 1.6  # seconds from his door opening to his first step, once it is shut behind him
const WALK := 1.3  # m/s, down the road
const EDGE := -3.0  # metres across (+ left): he crosses to the road's right edge and walks down it, facing any traffic
const CROSS := 6.0  # metres down the road he takes to get there
const STRIDE := 0.7  # metres a step takes
const SWING := 0.4  # radians each leg swings, forward and back
const GONE := 60.0  # metres he walks before he is lost in the fog, torch and all
const TORCH := Vector3(-0.12, 1.08, 0.33)  # his phone in his right hand, in his own space (measured on the model)
## Mei's turn to the back seat, over her left shoulder: her chest twists left and leans in towards the middle of the
## car, and her head turns on round, so from his seat her eyes show over her headrest, on him. rotation.y > 0 is to her
## left, x > 0 forward and z > 0 to her right.
const MEI_CHEST := Vector3(0.0, deg_to_rad(35.0), deg_to_rad(20.0))
const MEI_HEAD := Vector3(0.0, deg_to_rad(80.0), 0.0)
## Where else she turns for a line (mei_faces), as [chest, head]: leaning in and over to her left to see down the
## road, which from his seat uncovers the road ahead past her (no further in: her screen's glow would catch the
## windscreen as a lamp out in the fog); or to her own door, for its handle.
const MEI_TO := {
	&"him": [MEI_CHEST, MEI_HEAD],
	&"ahead": [Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(-20.0)),
		Vector3(deg_to_rad(-5.0), deg_to_rad(-5.0), deg_to_rad(15.0))],
	&"door": [Vector3(deg_to_rad(10.0), deg_to_rad(20.0), deg_to_rad(-10.0)),
		Vector3(deg_to_rad(15.0), deg_to_rad(55.0), 0.0)],
}
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
uniform float halo = 0.45;  // a dim outline: more, and the edges clip to white
uniform vec3 tint : source_color = vec3(0.65, 0.4, 0.25);  // her dark brown, which the light takes on coming through

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
var hafiz_out: Node3D  # on his feet, his phone up as a torch: hidden until he gets out
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
var _her_to: Array = MEI_TO[&"him"]  # her pose, turned
var _her_next: Array = MEI_TO[&"him"]  # her pose for her next line
var _out_t := -1.0  # seconds since his door opened, as he gets out; -1 unless he is getting out or walking off
var _out_s := 0.0  # where along the road he sets off from
var _out_across := 0.0
var _legs: Array[Node3D] = []


func _init(car: CarRig) -> void:
	name = "Couple"
	_car = car


func _ready() -> void:
	hafiz = _seat(&"hafiz_seated", _car.seat_driver)
	mei = _seat(&"mei_seated", _car.seat_front)
	_his_head = hafiz.get_node("Head")
	hafiz_out = ApartmentBuilder.model(&"hafiz_standing")
	hafiz_out.top_level = true  # he walks off down the road, not with the car
	hafiz_out.visible = false
	add_child(hafiz_out)
	_legs.assign([hafiz_out.get_node("LegL"), hafiz_out.get_node("LegR")])
	var torch := SpotLight3D.new()
	torch.light_color = Color(0.95, 0.97, 1.0)
	torch.light_energy = 4.0
	torch.spot_range = 12.0
	torch.spot_angle = 30.0
	torch.spot_attenuation = 0.5  # a pool on the road ahead of him that shows from the car, not a glow at his feet
	torch.shadow_enabled = false  # only his own phone light casts shadows
	torch.transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.35, 1.0)), TORCH)  # ahead of him and down
	hafiz_out.add_child(torch)
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
	# Her screen's glow lights her face from below and, past her, the roof over the front seats: the headliner, the sun
	# visors and the dome lamp. It has no shadow, like every light but his phone's, so it is a wide, dim glow that can
	# pass her head unnoticed, not a beam. It turns with her head, as if she brings the phone round with her: from his
	# seat her seat hides the phone, and her face is what shows. It leaves out his door, on a visual layer of its own:
	# from his seat its glass would catch the glow as a bright spot, like a lamp out in the fog.
	var screen := SpotLight3D.new()
	screen.light_color = Color(0.88, 0.9, 0.95)
	screen.light_energy = 0.3
	screen.spot_range = 0.95
	screen.spot_angle = 60.0
	screen.shadow_enabled = false
	screen.transform = Transform3D(Basis.looking_at(SCREEN_FACING), SCREEN)
	(_car.door_rear_left.get_node("door_rear_left") as MeshInstance3D).layers = DOOR_LAYER
	screen.light_cull_mask &= ~DOOR_LAYER
	_her_head.add_child(screen)
	EventBus.road_line.connect(turn_to)


## Someone in the car says a line for `seconds`: Mei turns to him for hers (or where mei_faces said), and stays
## turned through the gap before a next line, so two of hers in a row are one turn; Hafiz glances at the mirror for his.
func turn_to(speaker: StringName, seconds: float) -> void:
	match speaker:
		&"mei":
			_her_to = _her_next
			_her_next = MEI_TO[&"him"]
			_her_left = seconds + RoadDirector.LINE_GAP
		&"hafiz":
			_his_left = minf(seconds, GLANCE)


## Mei's next line is said not to him but `to` (a MEI_TO pose); after it, she turns to him again.
func mei_faces(to: StringName) -> void:
	_her_next = MEI_TO[to]


## The car has died: Hafiz opens his door, gets out, shuts it behind him and walks off ahead down the road, his phone
## held up as a torch, until the fog has him.
func hafiz_leaves() -> void:
	_car.swing_door(_car.door_driver, deg_to_rad(CarRig.DOOR_OPEN), SET_OFF - 0.85)
	var at := _car.global_transform * OUT
	_out_s = RoadLayout.closest_s(at)
	var t := RoadLayout.tangent(_out_s)
	_out_across = (at - RoadLayout.point(_out_s)).dot(Vector3(t.z, 0.0, -t.x).normalized())
	_out_t = 0.0


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
	_her_chest.rotation = _her_to[0] * k
	_her_head.rotation = _her_to[1] * k
	if _out_t >= 0.0:
		_walk_off(delta)


## Hafiz out of his seat and on his feet beside his door, then walking off down the road's right edge. From the back
## seat he stays in sight past Mei's head until the fog has him.
func _walk_off(delta: float) -> void:
	_out_t += delta
	if _out_t < STAND_UP:
		return
	hafiz.visible = false
	var walked := maxf(_out_t - SET_OFF, 0.0) * WALK
	hafiz_out.visible = walked < GONE
	if walked >= GONE:
		_out_t = -1.0
		return
	var at := _path(walked)
	var ahead := (_path(walked + 0.5) - at).slide(Vector3.UP).normalized()
	hafiz_out.global_transform = Transform3D(Basis.looking_at(ahead, Vector3.UP, true), at)
	var swing := sin(walked / STRIDE * PI) * SWING * minf(walked / STRIDE, 1.0)  # his first step from a standstill
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing


## Where he is once he has walked `walked` metres.
func _path(walked: float) -> Vector3:
	return RoadLayout.point(_out_s + walked, lerpf(_out_across, EDGE, smoothstep(0.0, CROSS, walked)))


func _seat(id: StringName, seat: Node3D) -> Node3D:
	var person := ApartmentBuilder.model(id)
	add_child(person)
	person.global_transform = seat.global_transform
	return person

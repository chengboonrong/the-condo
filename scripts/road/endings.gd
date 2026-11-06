class_name Endings
extends Node3D
## The end of the road, as the core cues it (LightMission): the closed fruit stall at the light, with its bare bulb and
## Hafiz's phone on its table, the lorry, and each ending's moments.
##   alive   hafiz_at_stall: a lorry stands idling past the stall, and Hafiz walks up from beside it to the stall
##   saved   phone_rings: his phone rings on the table; lorry_stops: a lorry pulls up behind the two of them
##   caught  light_out: the bulb dies, and Hafiz walks out of the fog ahead; her_catches_hafiz: she flies up and over
##           the two of them and drops onto him, and Mei screams once he is down; her_comes: she comes for the camera,
##           and the black card cuts in the moment she reaches it, with no caption
## The stall stands wherever the core puts the light (RoadDirector.light_s), so a skip to the walk finds it there.

const BULB := Vector3(0.12, 1.8, -0.7)  # the bulb's centre in the stall's own space (the model's "bulb" empty)
## The bulb's glass and its light: a warm bare bulb under the road's grade (an emission of 1 reads neutral, 3 cool
## white: warm is below 1).
const BULB_COLOR := Color(1.0, 0.6, 0.28)
const BULB_GLOW := 0.8
const BULB_ENERGY := 3.0
const BULB_RANGE := 10.0
const DIE := 0.25  # seconds the bulb takes to die: once, never a flicker
const PHONE := Vector3(0.7, 0.783, -0.3)  # Hafiz's phone on the table, face up, in the stall's space
const LORRY_AHEAD := 9.0  # metres past the light the lorry stands, idling (alive): its tail 4.9 m past it
## alive: Hafiz walks up the asphalt's edge, clear of the lorry's side, from past its cab to the stall's far post.
const HAFIZ_FROM := 14.0  # metres past the light
const HAFIZ_STOP := 1.6
const HAFIZ_ACROSS := 3.6
const LORRY_BEHIND := 11.0  # metres behind him it pulls up (saved)
const HAFIZ_AHEAD := 14.0  # metres down the road from him Hafiz walks out of the fog (caught), into his phone light
## Where she flies to before she drops onto Hafiz: metres short of him towards the walkers (so he falls away from
## them), and up. Her line there from behind them passes over their heads by more than what hangs from her, and she
## stays out of his phone light (40 degrees round his view, 11 m long): 10 m up is past its reach or above its cone
## wherever Hafiz is ahead of him.
const OVER := Vector2(0.5, 10.0)
const SCREAM := "[Mei screams.]"  # always shown: nobody's voice is heard
const SCREEN_GLOW := 1.2  # his phone's screen, lit as it rings
const RING_DB := 0.0  # the phone, within 3 m; it falls off as 1/distance past that
const IDLE_DB := -4.0  # the lorry's diesel, within 6 m

var director: RoadDirector
var builder: RoadBuilder
var couple: Couple
var her: Penanggal
var lorry: Lorry
var audio: RoadAudio
var hud: Hud
var player: PlayerController
var stall: Node3D
var bulb: OmniLight3D
var phone: MeshInstance3D

var _glass: StandardMaterial3D
var _screen := StandardMaterial3D.new()
var _phone_body := StandardMaterial3D.new()
var _at_s := NAN  # where the stall stands
var _ringing := false
var _idling := false
var _catching := false  # her_catches_hafiz: she is on her way to him
var _caught := false  # the caught ending is playing


## Where the stall stands for a light at s: its open front on the asphalt's edge on the left verge, facing the road,
## standing level (the long straight's verge is flat to the drain on the hill side).
static func stall_at(s: float) -> Transform3D:
	var fwd := RoadLayout.tangent(s).slide(Vector3.UP).normalized()
	var left := Vector3(fwd.z, 0.0, -fwd.x)
	return Transform3D(Basis(fwd, Vector3.UP, -left), RoadLayout.point(s, RoadBuilder.EDGE))


## The bulb, for a light at s: what the far light's haze is drawn round.
static func bulb_at(s: float) -> Vector3:
	return stall_at(s) * BULB


func _ready() -> void:
	stall = ApartmentBuilder.model(&"fruit_stall")
	stall.visible = false
	add_child(stall)
	var body: MeshInstance3D = stall.get_node("FruitStall")
	for i in body.mesh.get_surface_count():
		var own := body.mesh.surface_get_material(i) as StandardMaterial3D
		if own != null and own.resource_name == "bulb":
			_glass = own.duplicate()
			_glass.emission = BULB_COLOR
			body.set_surface_override_material(i, _glass)
	bulb = OmniLight3D.new()
	bulb.light_color = BULB_COLOR
	bulb.omni_range = BULB_RANGE
	bulb.shadow_enabled = false  # only his phone light casts shadows
	bulb.position = BULB
	stall.add_child(bulb)
	var solid := StaticBody3D.new()  # closed: he can't walk in under its tarp
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(2.4, 2.2, 1.8)
	box.position = Vector3(0.0, 1.1, -0.85)
	solid.add_child(box)
	stall.add_child(solid)
	_phone_body.albedo_color = Color(0.02, 0.02, 0.022)
	_phone_body.roughness = 0.4
	_screen.albedo_color = Color(0.01, 0.012, 0.015)
	_screen.roughness = 0.1
	_screen.emission_enabled = true  # always: switching it on would compile a new shader mid-game
	_screen.emission = Color(0.75, 0.85, 1.0)
	_screen.emission_energy_multiplier = 0.0  # dark until it rings
	phone = MeshInstance3D.new()
	var case := BoxMesh.new()
	case.size = Vector3(0.075, 0.009, 0.155)
	phone.mesh = case
	phone.material_override = _phone_body
	phone.position = PHONE
	phone.rotation.y = 0.4
	var screen := MeshInstance3D.new()
	var glass := PlaneMesh.new()
	glass.size = Vector2(0.068, 0.145)
	screen.mesh = glass
	screen.material_override = _screen
	screen.position.y = 0.0046
	phone.add_child(screen)
	stall.add_child(phone)
	_light(false)
	EventBus.road_cue.connect(_on_cue)
	her.caught.connect(_on_caught)
	her.arrived.connect(_on_arrived)
	her.reached.connect(_on_reached)


## The light down the road, on or off: the stall's bulb, and the far light's haze round it.
func light(on: bool) -> void:
	_light(on)
	if on:
		builder.show_light(bulb_at(director.light_s))
	else:
		builder.hide_light()


## Every material it draws with, for the start card's warm-up: the stall's, the phone's and the lorry's.
func materials() -> Array[Material]:
	var out: Array[Material] = []
	for m: MeshInstance3D in stall.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat != null and not out.has(mat):
				out.append(mat)
	out.append_array(lorry.materials())
	return out


func _process(_delta: float) -> void:
	if director.light_s != _at_s:
		_at_s = director.light_s
		stall.visible = _at_s >= 0.0
		if stall.visible:
			stall.global_transform = stall_at(_at_s)
	var ear := player.camera.global_position
	audio.set_loop(&"phone_ring_mobile", _ringing, RING_DB + linear_to_db(1.0 / maxf(ear.distance_to(phone.global_position) / 3.0, 1.0)))
	audio.set_loop(&"lorry_idle", _idling, IDLE_DB + linear_to_db(1.0 / maxf(ear.distance_to(lorry.global_position) / 6.0, 1.0)),
		lerpf(1.0, 1.4, lorry.speed / 12.0))


func _on_cue(cue: StringName) -> void:
	match cue:
		&"light_on":
			light(true)
		&"hafiz_at_stall":
			couple.hafiz_comes(player, _at_s + HAFIZ_FROM, HAFIZ_ACROSS, _at_s + HAFIZ_STOP)
			phone.visible = false  # it is in his hand
			lorry.stand(_at_s + LORRY_AHEAD)
			_idling = true
		&"phone_rings":
			_ringing = true
			_screen.emission_energy_multiplier = SCREEN_GLOW
		&"lorry_stops":  # out of the fog behind them, its lamps on them: she is gone
			lorry.pull_up(RoadLayout.closest_s(player.global_position) - LORRY_BEHIND)
			_idling = true
			her.hide_her()
		&"card_on":  # they are on their way down: the phone and the diesel are left behind
			_ringing = false
			_idling = false
		&"light_out":
			_caught = true
			var dying := create_tween()
			dying.tween_method(func(k: float) -> void:
				bulb.light_energy = BULB_ENERGY * k
				_glass.emission_energy_multiplier = BULB_GLOW * k, 1.0, 0.0, DIE)
			dying.tween_callback(light.bind(false))
			var s := RoadLayout.closest_s(player.global_position)
			couple.hafiz_comes(player, s + HAFIZ_AHEAD, Couple.across(player.global_position, s) - 1.0)  # to his right
		&"her_catches_hafiz":
			couple.hafiz_stops()
			var hafiz := couple.hafiz_out.global_position
			var towards := (player.global_position - hafiz).slide(Vector3.UP).normalized()
			_catching = true
			her.fly_to(hafiz + towards * OVER.x + Vector3.UP * OVER.y)
		&"her_comes":
			her.come_for(player.camera)


func _on_arrived() -> void:
	if _catching:
		_catching = false
		her.catch(couple.hafiz_out)


func _on_caught(victim: Node3D) -> void:
	if victim == couple.hafiz_out:
		EventBus.line_requested.emit(SCREAM, 2.5)


func _on_reached() -> void:
	if _caught:
		hud.show_card("")


func _light(on: bool) -> void:
	bulb.light_energy = BULB_ENERGY if on else 0.0
	bulb.visible = on
	_glass.emission_energy_multiplier = BULB_GLOW if on else 0.0

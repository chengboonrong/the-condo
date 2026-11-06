class_name Endings
extends Node3D
## The end of the road, as the core cues it (LightMission): the closed fruit stall at the light, with its bare bulb and
## a phone on its table (Hafiz's, as saved finds; it stays there in alive, as hiding it would be seen), the lorry, and
## each ending's moments.
##   alive   hafiz_at_stall: Hafiz walks up out of the fog to the stall, his torch coming on; lorry_flagged: the lorry
##           he flagged down comes down the mountain behind the two of them, passes them slowly and pulls up idling just
##           past the stall, and she is gone
##   saved   phone_rings: his phone rings on the table; lorry_stops: a lorry pulls up behind the two of them
##   caught  light_out: the bulb dies, and Hafiz walks out of the fog ahead, his torch on them; her_catches_hafiz: she
##           flies up and over the two of them and drops onto him, his phone falls lit on the road beside him, and Mei
##           screams once he is down; her_comes: she comes for the camera, and the black card cuts in the moment she
##           reaches it, with no caption
## Once the walk is over (walk_over) Mei stands where she stopped. The stall stands wherever the core puts the light
## (RoadDirector.light_s), so a skip to the walk finds it there. Its lights come on and go out by their energy, but
## some are shown late: the bulb and the ring light with the stall, once the light is placed, and Hafiz's torch with
## him. None compiles a shader mid-game: the start card's warm-up (RoadMain._compile_shaders) has drawn everything
## under each kind of light already.

const BULB := Vector3(0.12, 1.8, -0.7)  # the bulb's centre in the stall's own space (the model's "bulb" empty)
## The bulb's glass and its light: a warm bare bulb under the road's grade (an emission of 1 reads neutral, 3 cool
## white: warm is below 1).
const BULB_COLOR := Color(1.0, 0.6, 0.28)
const BULB_GLOW := 0.8
const BULB_ENERGY := 3.0
const BULB_RANGE := 10.0
## The stall's solid box, in its own space: he can't walk in under its tarp, and Mei never stands in it.
const BOX := Vector3(2.4, 2.2, 1.8)
const BOX_AT := Vector3(0.0, 1.1, -0.85)
const DIE := 0.25  # seconds the bulb takes to die: once, never a flicker
const PHONE := Vector3(0.7, 0.783, -0.3)  # the phone on the table, face up, in the stall's space
## alive: metres past the light the lorry Hafiz flagged down pulls up, come down the mountain in their lane, its tail
## 4.9 m past the light, idling. It comes from LORRY_FROM metres up the road from there, past the camera's far plane
## behind them as they get there, so it is never seen to appear, and passes them at Lorry.PASS: it comes no faster
## within LORRY_CRAWL metres of its stop.
const LORRY_AHEAD := 9.0
const LORRY_FROM := 140.0
const LORRY_CRAWL := 20.0
## alive: Hafiz hurries up the asphalt's edge out of the fog below to the stall's far post, from 90 m on from where it
## is decided (where even the clearest fog leaves no more of him than a faint smudge against the bulb's haze), and is
## there in 24 s, before the lorry he flagged pulls up, even if they run to it.
const HAFIZ_FROM := 60.0
const HAFIZ_PACE := 2.4
const HAFIZ_STOP := 1.6
const HAFIZ_ACROSS := 3.6
const LORRY_BEHIND := 11.0  # metres behind him it pulls up (saved)
## caught: metres down the road from him Hafiz walks out of the fog, to stop Couple.MEET short of him before she comes
## for him (LightMission.CAUGHT_CATCH), into his phone light.
const HAFIZ_AHEAD := 11.0
## Where she flies to before she drops onto Hafiz: metres short of him towards the walkers (so he falls away from
## them), and up. Her line there from behind them passes over their heads by more than what hangs from her, and she
## stays out of his phone light (40 degrees round his view, 11 m long): 10 m up is past its reach or above its cone
## wherever Hafiz is ahead of him.
const OVER := Vector2(0.5, 10.0)
const SCREAM := "[Mei screams.]"  # always shown: nobody's voice is heard
const SCREEN_GLOW := 1.2  # his phone's screen, lit as it rings
const RING_LIGHT := 1.5  # and the light it throws on the table round it, seen from where the walk ends
const RING_RANGE := 0.9
## caught: his phone, fallen on the road at his right side as he goes down (metres to his right and back from where
## he stood), its torch still on, lighting him, the pool and her over him.
const DROPPED := Vector2(0.45, 1.1)
const DROPPED_UP := 0.5  # metres over the road the torch's glow is lit from: over his chest as he lies
const DROPPED_LIGHT := 2.5
const DROPPED_RANGE := 3.0
const PHONE_COLOR := Color(0.92, 0.95, 1.0)  # a phone's white LED
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
var screen := StandardMaterial3D.new()  # his phone's screen on the table
var ring_light: OmniLight3D  # what the ringing screen throws on the table
var dropped: MeshInstance3D  # caught: his phone, on the road beside him
var dropped_light: OmniLight3D

var _glass: StandardMaterial3D
var _phone_body := StandardMaterial3D.new()
var _hafiz_at := Transform3D.IDENTITY  # caught: where Hafiz stood as she dropped onto him
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
	(box.shape as BoxShape3D).size = BOX
	box.position = BOX_AT
	solid.add_child(box)
	stall.add_child(solid)
	_phone_body.albedo_color = Color(0.02, 0.02, 0.022)
	_phone_body.roughness = 0.4
	screen.albedo_color = Color(0.01, 0.012, 0.015)
	screen.roughness = 0.1
	screen.emission_enabled = true  # always: switching it on would compile a new shader mid-game
	screen.emission = Color(0.75, 0.85, 1.0)
	screen.emission_energy_multiplier = 0.0  # dark until it rings
	phone = _phone()
	phone.position = PHONE
	phone.rotation.y = 0.4
	var lit := MeshInstance3D.new()
	var glass := PlaneMesh.new()
	glass.size = Vector2(0.068, 0.145)
	lit.mesh = glass
	lit.material_override = screen
	lit.position.y = 0.0046
	phone.add_child(lit)
	ring_light = _lamp(screen.emission, RING_RANGE)
	ring_light.position.y = 0.03
	phone.add_child(ring_light)
	stall.add_child(phone)
	dropped = _phone()
	dropped.top_level = true
	dropped.visible = false
	add_child(dropped)
	dropped_light = _lamp(PHONE_COLOR, DROPPED_RANGE)  # not the phone's child: shown always, and dark until it falls
	dropped_light.top_level = true
	add_child(dropped_light)
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
			couple.hafiz_comes(player, _at_s + HAFIZ_FROM, HAFIZ_ACROSS, _at_s + HAFIZ_STOP, HAFIZ_PACE)
		&"lorry_flagged":  # out of the fog behind them, slowly past them, to where he flagged it: she is gone
			lorry.pull_up(_at_s + LORRY_AHEAD, LORRY_FROM, LORRY_CRAWL)
			_idling = true
			her.hide_her()
		&"phone_rings":
			_ringing = true
			screen.emission_energy_multiplier = SCREEN_GLOW
			ring_light.light_energy = RING_LIGHT
		&"lorry_stops":  # out of the fog behind them, its lamps on them: she is gone
			lorry.pull_up(RoadLayout.closest_s(player.global_position) - LORRY_BEHIND)
			_idling = true
			her.hide_her()
		&"walk_over":
			couple.mei_stops()
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
			couple.hafiz_comes(player, s + HAFIZ_AHEAD, RoadLayout.across(player.global_position, s) - 1.0)  # to his right
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
		_hafiz_at = couple.hafiz_out.global_transform
		her.catch(couple.hafiz_out)


## He is down: his torch goes out of his hand and lies lit on the road at his right side, and Mei screams.
func _on_caught(victim: Node3D) -> void:
	if victim != couple.hafiz_out:
		return
	var at := _hafiz_at * Vector3(-DROPPED.x, 0.0, -DROPPED.y)
	var s := RoadLayout.closest_s(at)
	var road := CarRig.on_road(s, RoadLayout.across(at, s))
	dropped.global_transform = Transform3D(road.basis.rotated(road.basis.y, 2.3), road.origin + road.basis.y * 0.005)
	dropped.visible = true
	dropped_light.global_position = road.origin + road.basis.y * DROPPED_UP
	dropped_light.light_energy = DROPPED_LIGHT
	couple.torch.light_energy = 0.0
	EventBus.line_requested.emit(SCREAM, 2.5)


func _on_reached() -> void:
	if _caught:
		hud.show_card("")


func _light(on: bool) -> void:
	bulb.light_energy = BULB_ENERGY if on else 0.0
	_glass.emission_energy_multiplier = BULB_GLOW if on else 0.0


## A phone, face up: its dark case.
func _phone() -> MeshInstance3D:
	var case := BoxMesh.new()
	case.size = Vector3(0.075, 0.009, 0.155)
	var m := MeshInstance3D.new()
	m.mesh = case
	m.material_override = _phone_body
	return m


## A small light with no shadow, dark until its energy is set.
func _lamp(color: Color, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = 0.0
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	return lamp

class_name Lorry
extends Node3D
## A lorry, built in code: a dark cargo box on a dark cab, red and white reflective strips, and two headlights.
## pass_by() drives it up the road past the bus stop in the other lane; at the road's end it comes down the walkers'
## lane and pulls up, behind them or past them at the fruit stall (pull_up), yielding to anyone in its way. The rest of
## the time it is not on the road.
## Like the car, it faces +Z with its origin on the ground.

const SECONDS := 3.0
const FROM := 30.0  # s: out of the fog below the stop...
const TO := -30.0  # ...and gone into it above
const DARK := Color(0.05, 0.05, 0.055)
const PULL_FROM := 30.0  # metres up the road it comes from, pulling up...
const PULLING := 5.0  # ...braking evenly to a stop over this many seconds (from 12 m/s)
const CRUISE := 2.0 * PULL_FROM / PULLING  # m/s it comes at from further off, before it brakes
const BRAKE := CRUISE / PULLING  # m/s², however it slows
const PASS := 3.0  # m/s at the most it passes people on the road at
## Metres off the centreline it comes down the walkers' lane on: wholly in it (its far side 0.28 m inside the
## centreline), and its near side 0.58 m from their line on it (3.3 m) as it passes them.
const LINE := 1.5
## pull_up: it yields to anyone ahead of its tail and less than CLEAR metres from its side (or in its way): it comes
## no faster than it can still stop SHORT_OF metres short of them, holds there, idling, while they stay, and drives on
## once the way is clear, pulling away no harder than it brakes.
const CLEAR := 0.5
const SHORT_OF := 1.5
const BRAKES := Vector3(0.0, 0.6, -1.0)  # its air brakes, under the cargo box

var speed := 0.0  # m/s, down the road, pulling up
var yields_to: Array[Node3D] = []  # pull_up: who it yields to (RoadMain: him, Mei and Hafiz), while they are seen
var _t := INF
var _stop_s := NAN  # pull_up: where it stops; NAN when passing
var _short := 0.0  # pull_up: metres short of its stop
var _crawl := 0.0  # pull_up: metres short of its stop it comes no faster than PASS within
var _body := AABB()  # every box it is built of, in its own space


func _ready() -> void:
	var dark := _material(DARK, 0.0)
	_box(Vector3(0.0, 1.95, -0.9), Vector3(2.4, 2.9, 6.4), dark)  # the cargo box
	_box(Vector3(0.0, 1.45, 3.25), Vector3(2.3, 2.1, 1.9), dark)  # the cab
	_box(Vector3(0.0, 0.45, 0.3), Vector3(2.1, 0.7, 7.6), dark)  # the chassis and wheels, as one dark mass
	var white := _material(Color(0.85, 0.85, 0.8), 0.5)  # tape that catches the light, so it shows in the dark
	var red := _material(Color(0.8, 0.06, 0.04), 0.5)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 1.21, 0.62, -0.9), Vector3(0.02, 0.08, 6.2), white)
		var lamp := SpotLight3D.new()
		lamp.light_color = Color(1.0, 0.9, 0.75)
		lamp.light_energy = 3.0
		lamp.spot_range = 35.0
		lamp.spot_angle = 26.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(side * 0.85, 0.85, 4.22)
		lamp.rotation.y = PI  # its -Z ahead, along the lorry's +Z
		add_child(lamp)
		_box(lamp.position + Vector3(0.0, 0.0, -0.02), Vector3(0.3, 0.16, 0.04), _material(Color(1.0, 0.9, 0.75), 3.0))
	_box(Vector3(0.0, 0.62, -4.11), Vector3(2.3, 0.1, 0.02), red)
	visible = false
	set_process(false)


func pass_by() -> void:
	_t = 0.0
	_stop_s = NAN
	visible = true
	set_process(true)


## It comes down the couple's lane out of the fog, `from` metres up the road from s, and pulls up at s: at CRUISE,
## braking evenly over the last PULL_FROM metres, and its air brakes hiss as it stops. Within `crawl` metres of s it
## comes no faster than PASS, braking down to it before then: it is passing people on the road.
func pull_up(s: float, from := PULL_FROM, crawl := 0.0) -> void:
	_t = 0.0
	_stop_s = s
	_short = from
	_crawl = crawl
	speed = CRUISE  # as it comes from further off
	visible = true
	set_process(true)
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	if not is_nan(_stop_s):
		_short = maxf(_short - speed * delta, 0.0)
		global_transform = CarRig.on_road(_stop_s - _short, LINE)
		speed = minf(_speed(_short), speed + BRAKE * delta)
		if _short == 0.0:
			set_process(false)
			EventBus.sound_requested.emit(&"lorry_brake", global_transform * BRAKES, 0.0)
		return
	if _t >= SECONDS:
		visible = false
		set_process(false)
		return
	global_transform = CarRig.on_road(lerpf(FROM, TO, _t / SECONDS), -RoadLayout.LANE, true)


## m/s it may come at, `short` metres short of its stop: as fast as it can still brake to a stop there, to PASS by
## the time it is `_crawl` short of it, and SHORT_OF anyone in its way.
func _speed(short: float) -> float:
	var v := minf(CRUISE, sqrt(2.0 * BRAKE * short))
	if short <= _crawl:
		v = minf(v, PASS)
	else:
		v = minf(v, sqrt(PASS * PASS + 2.0 * BRAKE * (short - _crawl)))
	for who in yields_to:
		var s := RoadLayout.closest_s(who.global_position)
		var ahead := s - (_stop_s - short)  # metres down the road from its origin
		if who.is_visible_in_tree() and ahead > _body.position.z \
				and absf(RoadLayout.across(who.global_position, s) - LINE) < _body.end.x + CLEAR:
			v = minf(v, sqrt(2.0 * BRAKE * maxf(ahead - _body.end.z - SHORT_OF, 0.0)))
	return v


func _box(at: Vector3, size: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position = at
	add_child(box)
	var part := AABB(at - size / 2.0, size)
	_body = part if _body.size == Vector3.ZERO else _body.merge(part)


func _material(color: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

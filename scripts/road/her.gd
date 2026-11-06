class_name Penanggal
extends Node3D
## Her: the penanggal of Malay folklore, a woman's head flown loose of her body with her insides hanging beneath it
## (assets/models/penanggal.glb: its origin is the centre of her skull, and she faces +Z). Hidden until the road calls
## for her, then in one place at a time: glimpsed at the roadside ahead of the car, on the car's roof, behind a
## walker, catching someone, or coming for the camera. She is lit only by the scene's own lights, she always hangs
## upright, and she is quiet: her sounds are wet, and none of them is a sting.

## come_for: she is as close to the camera as she comes.
signal reached

const SMELL := "[A sour smell, like vinegar.]"  # after her first glimpse: the folklore's vinegar, unexplained
const GLIMPSE := 1.2  # seconds she is seen at the roadside
const GLIMPSE_AHEAD := Vector2(25.0, 35.0)  # metres along the road she may show at
const GLIMPSE_OUT := Vector2(5.3, 5.6)  # across, on the valley side: past the rail and its posts, drifting out
## Her skull above the road there, rising 0.15 m: her face in the dipped beam's top, her insides hanging into the drop.
const GLIMPSE_UP := 1.8
const SEAT := 0.37  # his seat, left of the car's middle
## Degrees left and right of the car's way she stays within, from his seat: inside the windscreen's left pillar (its
## edge is at 12.4 at her height), short of Hafiz's head on the right.
const SEEN := Vector2(11.5, 24.0)
const FADE := 0.25  # seconds she takes to come out of the fog, and to go back into it
const ABOVE_ROAD := 2.45  # her skull above the road behind a walker: the ends of her insides just clear it
const BEHIND := Vector2(18.0, 4.0)  # metres behind a walker along the road, from no rule broken to her nearest
const FOLLOW := 6.0  # m/s at most, keeping behind a walker
const SPEED := 6.0  # m/s, coming for the camera
const LOW_IN := 2.0  # metres from the camera she comes down from ABOVE_ROAD to its height
const CLOSE := 0.6  # metres from the camera she stops at
const SWOOP := 8.0  # m/s at most, dropping onto someone
const SHOULDERS := 1.42  # a standing victim's shoulders, above his feet
const DROP := 0.35  # seconds she takes to drop onto them, at the least
const FALL := 0.6  # seconds he takes to fall
const OVER_HIM := 1.0  # her skull above the ground at the lowest, over him: her organs stay off it
const POOL := 0.95  # metres the pool spreads to
## On the car's roof, in the car's space: her skull over the roof's edge and outside his window, facing in, so what
## hangs from her passes the glass and the door (the car's body is 0.88 m wide each side at most).
const ROOF := Vector3(1.08, 1.62, -0.45)
const POOL_COLOR := Color(0.2, 0.02, 0.03)
## [sound, the shortest and longest seconds between] while she is in each place.
const NOISES := {
	&"behind": [[&"wet_flap", 3.0, 6.0], [&"drip", 1.5, 4.0]],
	&"catch": [[&"drip", 0.8, 2.0]],
	&"come_for": [[&"wet_flap", 0.5, 0.9]],
	&"roof": [[&"drip", 2.0, 5.0], [&"rattle", 6.0, 11.0]],
}
const NOISE := """
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
"""
## Her four surfaces (skin, eyes, hair, entrails), as the model coloured them. Below her jaw everything hangs free: it
## sways more the further it hangs (with the square of the distance), trails against `motion` (her velocity, in her own
## space) keeping its length, and lies on the ground wherever it would reach below `floor_y`. On the organs and the skin
## the roughness wanders in patches and the surface is lumpy (`bump`, metres), so their highlights break up: wet flesh,
## not rubber hoses or plastic. `fade` dissolves her in and out.
const SWAY_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform float roughness = 0.5;
uniform float roughness_noise = 0.0;
uniform float bump = 0.0;
uniform vec3 motion = vec3(0.0);
uniform float floor_y = -100.0;
uniform float fade = 1.0;
varying vec3 rest;
""" + NOISE + """
void vertex() {
	rest = VERTEX;
	float d = max(-0.12 - VERTEX.y, 0.0);  // below the jaw
	float k = d * d;
	VERTEX.x += k * 0.012 * (sin(TIME * 0.83 + d * 1.9 + rest.z * 5.0) + 0.4 * sin(TIME * 2.1 + d * 4.3));
	VERTEX.z += k * 0.012 * (sin(TIME * 0.61 + d * 1.5 + rest.x * 5.0 + 1.7) + 0.4 * sin(TIME * 1.7 + d * 3.7 + 0.9));
	vec2 trail = -motion.xz * 0.035 * k;
	float reach = length(trail);
	if (reach > 0.8 * d) {
		trail *= 0.8 * d / reach;
		reach = 0.8 * d;
	}
	VERTEX.xz += trail;
	VERTEX.y += d - sqrt(d * d - reach * reach);
	float under = floor_y - VERTEX.y;
	if (under > 0.0) {  // on the ground: it runs out from under her in a wavering line
		vec2 out_dir = normalize(rest.xz + vec2(0.0001, 0.0));
		VERTEX.xz += out_dir * under * 0.35 + vec2(-out_dir.y, out_dir.x) * sin(under * 9.0 + rest.x * 40.0) * 0.05;
		VERTEX.y = floor_y + 0.01;
		NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
	}
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb * COLOR.rgb;
	ROUGHNESS = roughness;
	if (roughness_noise > 0.0 || bump > 0.0) {  // the eyes and the hair have neither
		float grain = 0.6 * value_noise(rest * 45.0) + 0.4 * value_noise(rest * 130.0);
		ROUGHNESS += roughness_noise * smoothstep(0.3, 0.7, grain);
		// bump mapping from the screen-space slopes of the grain (no texture, no tangents), gone where it would only
		// shimmer
		float h = bump * grain * (1.0 - smoothstep(3.0, 8.0, length(VERTEX)));
		h *= 0.3 + 0.7 * smoothstep(0.09, 0.13, -rest.y);  // her face only faintly: it is below the jaw that sags
		vec3 dx = dFdx(VERTEX);
		vec3 dy = dFdy(VERTEX);
		vec3 r1 = cross(dy, NORMAL);
		vec3 r2 = cross(NORMAL, dx);
		float det = dot(dx, r1);
		NORMAL = normalize(abs(det) * NORMAL - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2));
	}
	// last, so the slopes above are taken with the whole quad drawn
	if (fade < 1.0 && fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) >= fade) {
		discard;
	}
}
"""
## A dark pool on the ground, `spread` metres from its centre at most, its front further on in some directions than
## others, as blood runs over asphalt. Wet: it shows the lights on it.
const POOL_SHADER := """
shader_type spatial;

uniform vec4 color : source_color;
uniform float spread = 0.0;
varying vec3 at;
""" + NOISE + """
void vertex() {
	at = VERTEX;
}

void fragment() {
	float r = length(at.xz);
	vec2 dir = at.xz / max(r, 0.0001);
	float reach = spread * (0.6 + 0.4 * value_noise(vec3(dir * 1.7, 4.0))) + 0.04 * spread * value_noise(at * 9.0);
	if (r > reach) {
		discard;
	}
	ALBEDO = color.rgb;
	ROUGHNESS = mix(0.06, 0.3, smoothstep(reach - 0.05, reach, r));
}
"""

var director: RoadDirector  # the ride: where the car is, and how near she has come
var builder: RoadBuilder  # the ground beside the road; without it, the road's plane runs on
var pool: MeshInstance3D  # catch: what spreads under him

var _skin: Array[ShaderMaterial] = []  # her four surfaces
var _pool_material := ShaderMaterial.new()
var _mode := &""  # where she is: &"glimpse", &"behind", &"catch", &"come_for", &"roof", or nowhere
var _t := 0.0  # seconds there
var _target: Node3D  # the walker, the victim, the camera or the car
var _drop := DROP  # catch: seconds she takes to drop onto him
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _fall := Vector3.ZERO  # the way the victim falls
var _victim_at := Transform3D.IDENTITY  # where he stood
var _arrived := false
var _base := Vector3.ZERO  # where she is, before she bobs
var _last := Vector3.ZERO  # last frame
var _swing := Vector3.ZERO  # what hangs from her lags her motion: a velocity, on a spring
var _swing_v := Vector3.ZERO
var _timers := {}  # sound -> seconds to the next
var _warm_frame := -1
var _smelt := false
var _rng := RandomNumberGenerator.new()  # presentation only


func _ready() -> void:
	var model := ApartmentBuilder.model(&"penanggal")
	add_child(model)
	var mesh: MeshInstance3D = model.get_node("Penanggal")
	var shader := Shader.new()
	shader.code = SWAY_SHADER
	for i in mesh.mesh.get_surface_count():
		var own := mesh.mesh.surface_get_material(i) as StandardMaterial3D
		var m := ShaderMaterial.new()
		m.shader = shader
		m.resource_name = own.resource_name
		m.set_shader_parameter(&"albedo", own.albedo_color)
		m.set_shader_parameter(&"albedo_texture", own.albedo_texture)  # her skin's; white for the rest
		m.set_shader_parameter(&"roughness", own.roughness)
		if own.resource_name == "entrails":
			m.set_shader_parameter(&"roughness", 0.35)
			m.set_shader_parameter(&"roughness_noise", 0.25)
			m.set_shader_parameter(&"bump", 0.003)
		elif own.resource_name == "skin":  # dead skin, damp: no broad plastic sheen down her neck or over her brow
			m.set_shader_parameter(&"roughness_noise", 0.3)
			m.set_shader_parameter(&"bump", 0.0015)
		mesh.set_surface_override_material(i, m)
		_skin.append(m)
	_pool_material.shader = Shader.new()
	_pool_material.shader.code = POOL_SHADER
	_pool_material.resource_name = "pool"
	_pool_material.set_shader_parameter(&"color", POOL_COLOR)
	pool = MeshInstance3D.new()
	pool.name = "Pool"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * POOL * 2.2
	pool.mesh = plane
	pool.material_override = _pool_material
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.top_level = true  # it stays where it spread when she moves on
	add_child(pool)
	hide_her()


## Ahead of the car, past the guard rail on the valley side, half in the fog: her face at the top of the dipped beam
## and her insides hanging into the drop. She drifts out over it, and the car closing on her carries her across the
## beam's edge; she is gone in GLIMPSE seconds. Her first glimpse leaves a smell behind.
## ponytail: never in the tunnel's 80 m (Mission 2 shows her from s 387 on), where she would stand in its wall.
func show_glimpse() -> void:
	var path := _glimpse_path(_glimpse_s())
	_from = path[0]
	_to = path[1]
	_begin(&"glimpse", _from)
	_set_fade(0.0)


## On the car's roof, over the edge on his side: her insides hang past his window (Task 9).
func on_roof(car: CarRig) -> void:
	_target = car
	_begin(&"roof", car.global_transform * ROOF)


## On the road behind the walker along the road, on his line, high enough that what hangs from her clears it: 18 m
## back with no rule broken, 4 m at her nearest (RoadDirector.her_near, read as he walks, so a rule he breaks on the
## way brings her gliding in).
func behind(walker: Node3D) -> void:
	var was := _mode == &"behind"
	_target = walker
	if not was:
		_begin(&"behind", _behind_point())


## She drops onto the victim's shoulders and he falls, away from where she came from, over FALL seconds. She stays
## over him while a dark pool spreads under his shoulders.
func catch(victim: Node3D) -> void:
	var away := (victim.global_position - global_position).slide(Vector3.UP)
	_fall = away.normalized() if visible and away.length() > 0.1 else victim.global_basis.z.slide(Vector3.UP).normalized()
	_victim_at = victim.global_transform
	_target = victim
	var shoulders := victim.global_position + Vector3.UP * SHOULDERS
	_from = global_position if visible else shoulders - _fall * 1.5 + Vector3.UP * 1.0
	_drop = maxf(DROP, _from.distance_to(shoulders) / SWOOP)
	_begin(&"catch", _from)
	pool.visible = false
	var s := RoadLayout.closest_s(victim.global_position + _fall * SHOULDERS)
	var road := CarRig.on_road(s, 0.0)
	var ground := victim.global_position + _fall * SHOULDERS
	ground += road.basis.y * (road.origin - ground).dot(road.basis.y)  # down onto the road's plane
	pool.global_transform = Transform3D(road.basis, ground + road.basis.y * 0.012)
	_pool_material.set_shader_parameter(&"spread", 0.0)


## She comes straight at the camera at SPEED from wherever she is (if hidden, out of the fog 15 m ahead of it), high
## enough that what hangs from her clears the road, and comes down to its height over the last LOW_IN metres. She
## stops CLOSE to it, face to face: `reached`.
func come_for(camera: Camera3D) -> void:
	_target = camera
	_arrived = false
	var ahead := camera.global_position - camera.global_basis.z.slide(Vector3.UP).normalized() * 15.0
	_begin(&"come_for", global_position if visible else ahead)
	_play(&"rattle")


## She is gone, and so is anything she left.
func hide_her() -> void:
	_mode = &""
	_target = null
	visible = false
	pool.visible = false


## Every material she draws with, for the start card's warm-up: her four surfaces and the pool.
func materials() -> Array[Material]:
	var out: Array[Material] = []
	out.append_array(_skin)
	out.append(_pool_material)
	return out


## Shows her and the pool at `at` for a frame, so their shaders compile behind the start card. Nothing is heard.
func warm_up(at: Vector3) -> void:
	global_position = at
	visible = true
	pool.visible = true
	pool.global_position = at
	_pool_material.set_shader_parameter(&"spread", POOL)
	_warm_frame = Engine.get_process_frames()


func _process(delta: float) -> void:
	if _mode == &"":
		if visible and _warm_frame >= 0 and Engine.get_process_frames() > _warm_frame:
			_warm_frame = -1
			hide_her()
		return
	_t += delta
	var bob := 0.04
	match _mode:
		&"glimpse":
			_base = _from.lerp(_to, smoothstep(0.0, GLIMPSE, _t))
			_face(RoadLayout.point(director.car_s, director.lane))
			_set_fade(clampf(minf(_t, GLIMPSE - _t) / FADE, 0.0, 1.0))
			if _t >= GLIMPSE:
				hide_her()
				if not _smelt:
					_smelt = true
					EventBus.line_requested.emit(SMELL, 4.0)  # always shown: a smell has no sound to caption
				return
		&"behind":
			_base = _base.move_toward(_behind_point(), FOLLOW * delta)
			_face(_target.global_position)
		&"catch":
			_feed(delta)
			bob = 0.02
		&"come_for":
			var cam := _target.global_position
			var flat := (cam - _base).slide(Vector3.UP)
			_base += flat.normalized() * clampf(flat.length() - CLOSE, 0.0, SPEED * delta)
			var left := (cam - _base).slide(Vector3.UP).length() - CLOSE
			var high := maxf(cam.y, _ground_under(_base) + ABOVE_ROAD)
			_base.y = move_toward(_base.y, lerpf(cam.y, high, clampf(left / LOW_IN, 0.0, 1.0)), SPEED * delta)
			if left <= 0.001 and absf(_base.y - cam.y) < 0.001 and not _arrived:
				_arrived = true
				_play(&"rattle")  # her breath, in his face
				reached.emit()
			_face(cam)
			bob = 0.0 if _arrived else 0.04
		&"roof":
			_base = _target.global_transform * ROOF
			_face(_target.global_transform * Vector3(0.0, ROOF.y, ROOF.z))
			bob = 0.015
	global_position = _base + Vector3.UP * sin(_t * 1.25) * bob
	_sway(delta)
	for noise: Array in NOISES.get(_mode, []):
		_timers[noise[0]] = _timers.get(noise[0], _rng.randf_range(noise[1], noise[2])) - delta
		if _timers[noise[0]] <= 0.0:
			_timers[noise[0]] = _rng.randf_range(noise[1], noise[2])
			_play(noise[0])


## catch: she drops onto his shoulders, he falls, and she stays over him while the pool spreads.
func _feed(delta: float) -> void:
	var fall := clampf((_t - _drop) / FALL, 0.0, 1.0)
	var tip := Basis(Vector3.UP.cross(_fall).normalized(), PI / 2.0 * fall * fall)
	_target.global_transform = Transform3D(tip * _victim_at.basis, _victim_at.origin)
	var on := _target.global_transform * Vector3(0.0, SHOULDERS, 0.0) + Vector3.UP * 0.3 - _fall * 0.12
	on.y = maxf(on.y, _ground_under(on) + OVER_HIM)
	var drop := clampf(_t / _drop, 0.0, 1.0)
	_base = _from.lerp(on, drop * drop)
	if _passed(_drop, delta) or _passed(_drop + FALL, delta):
		_play(&"wet_flap")
	if _passed(_drop + FALL + 1.2, delta):
		_play(&"rattle")
	if _t >= _drop + FALL:
		pool.visible = true
		_pool_material.set_shader_parameter(&"spread", POOL * (1.0 - exp(-(_t - _drop - FALL) / 1.6)))


func _behind_point() -> Vector3:
	var at := _target.global_position
	var s := RoadLayout.closest_s(at)
	var back := lerpf(BEHIND.x, BEHIND.y, director.her_near)
	return RoadLayout.point(s - back, _across(at, s)) + Vector3.UP * ABOVE_ROAD


## Where along the road the glimpse is: the nearest place GLIMPSE_AHEAD on that keeps her in his view for the whole
## glimpse, from where the car is to where it will be when she is gone (on a bend she swings across the windscreen);
## failing that, the place she strays least from it.
func _glimpse_s() -> float:
	var best := Vector2(INF, director.car_s + GLIMPSE_AHEAD.y)  # (how far out of view, s)
	for ahead in range(int(GLIMPSE_AHEAD.x), int(GLIMPSE_AHEAD.y) + 1):
		var s := director.car_s + ahead
		if _by_a_sign(s):
			continue
		var path := _glimpse_path(s)
		var stray := 0.0
		for k: float in [0.0, 0.5, 1.0]:
			var car := director.car_s + director.car_speed * GLIMPSE * k
			var to := (path[0].lerp(path[1], k) - RoadLayout.point(car, director.lane + SEAT)).slide(Vector3.UP)
			var bearing := rad_to_deg(RoadLayout.tangent(car).slide(Vector3.UP).signed_angle_to(to, Vector3.UP))
			stray = maxf(stray, maxf(bearing / SEEN.x, -bearing / SEEN.y))
		if stray <= 1.0:
			return s
		if stray < best.x:
			best = Vector2(stray, s)
	return best.y


## Whether a roadside sign stands within 3 m of s: its board would hide her face.
static func _by_a_sign(s: float) -> bool:
	for at: float in RoadBuilder.WINDING + RoadBuilder.SIGNS.map(func(sign: Array) -> float: return sign[0]):
		if absf(at - s) < 3.0:
			return true
	return false


## [from, to]: her glimpse at s, on the side where the ground falls away (the left without the builder).
func _glimpse_path(s: float) -> Array[Vector3]:
	var side := 1.0
	if builder != null and builder.ground_at(s, -GLIMPSE_OUT.y) < builder.ground_at(s, GLIMPSE_OUT.y):
		side = -1.0
	return [RoadLayout.point(s, side * GLIMPSE_OUT.x) + Vector3.UP * GLIMPSE_UP,
		RoadLayout.point(s, side * GLIMPSE_OUT.y) + Vector3.UP * (GLIMPSE_UP + 0.15)]


## Shows her at `at`, starting over in a new place. Moving on from where she is, what hangs from her keeps swinging.
func _begin(mode: StringName, at: Vector3) -> void:
	if not visible or at.distance_to(global_position) > 0.5:
		_last = at
		_swing = Vector3.ZERO
		_swing_v = Vector3.ZERO
	_mode = mode
	_t = 0.0
	_base = at
	global_position = at
	_timers.clear()
	_warm_frame = -1
	_set_fade(1.0)
	visible = true


## What hangs from her swings after her motion, as a heavy wet rope would (a period of about 2 s, settling in a few
## swings), and lies on the ground wherever it would reach below it.
func _sway(delta: float) -> void:
	var v := (global_position - _last) / delta if delta > 0.0 else Vector3.ZERO
	_last = global_position
	_swing_v += ((v - _swing) * 9.0 - _swing_v * 2.0) * delta
	_swing += _swing_v * delta
	var motion := global_basis.inverse() * _swing
	var floor_y := _ground_under(global_position) + 0.02 - global_position.y
	for m in _skin:
		m.set_shader_parameter(&"motion", motion)
		m.set_shader_parameter(&"floor_y", floor_y)


## The ground's height under `at`: the road's, and beside it the verge, the drain or the drop into the valley.
func _ground_under(at: Vector3) -> float:
	var s := RoadLayout.closest_s(at)
	var road := RoadLayout.point(s).y
	return road + builder.ground_at(s, _across(at, s)) if builder != null else road


func _set_fade(amount: float) -> void:
	for m in _skin:
		m.set_shader_parameter(&"fade", amount)


## Turns her face to `point`, staying upright.
func _face(point: Vector3) -> void:
	var level := Vector3(point.x, global_position.y, point.z)
	if level.distance_to(global_position) > 0.05:
		look_at(level, Vector3.UP, true)


## Whether `at` seconds passed this frame.
func _passed(at: float, delta: float) -> bool:
	return _t >= at and _t - delta < at


func _play(sound: StringName) -> void:
	EventBus.sound_requested.emit(sound, global_position, 0.0)


## Metres to the left of the road's centreline at s.
static func _across(at: Vector3, s: float) -> float:
	var t := RoadLayout.tangent(s)
	return (at - RoadLayout.point(s)).dot(Vector3(t.z, 0.0, -t.x).normalized())

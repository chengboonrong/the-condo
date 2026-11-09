class_name Penanggal
extends Node3D
## Her: the penanggal of Malay folklore, a woman's head flown loose of her body with her insides hanging beneath it
## (assets/models/penanggal.glb: its origin is the centre of her skull, and she faces +Z). Hidden until the road calls
## for her, then in one place at a time: glimpsed at the roadside ahead of the car, on the car's roof, behind a
## walker, right behind him when he looks back, flying somewhere, catching someone, or coming for the camera. In the flat
## she has no director and only comes for the camera. She always hangs upright. She is lit by the scene's own lights, and
## in his face by her own dim fill as well. Her sounds are wet, but for one: when he looks back and it counts, the
## stinger and her shriek.

## come_for: she is as close to the camera as she comes.
signal reached
## catch: he is down and the pool begins to spread, once per catch (a drop from afar takes as long as its distance).
signal caught(victim: Node3D)
## fly_to: she hangs where she was sent.
signal arrived

const SMELL := "[A sour smell, like vinegar.]"  # after her first glimpse: the folklore's vinegar, unexplained
const GLIMPSE := 1.2  # seconds she is seen at the roadside, at the most
## Metres along the road ahead of the car she keeps pace at, from no rule broken to her nearest (RoadDirector.her_near
## NEAREST and over): each overtake brings her closer.
const GLIMPSE_AHEAD := Vector2(28.0, 10.0)
const NEAREST := 0.4
## Metres across she may hang at, always on the left verge (his side, the side the dipped beam reaches furthest): past
## the guard rail and its posts, over the drop, where the valley is on the left...
const VALLEY_OUT := Vector2(5.3, 8.0)
## ...and where the hill is, off the asphalt to the foot of the cut slope, short of the bushes on it.
const HILL_OUT := Vector2(4.4, 6.0)
## Her skull above the road: her face in the dipped beam's top, her insides hanging into the drop or onto the verge.
const GLIMPSE_UP := 1.8
const SEAT := Vector3(0.37, 1.15, -0.78)  # his eyes in the car's space (+X its left, +Z its forward)
const PACE_AT := 10.0  # her bearing from his seat as she keeps pace, in degrees left: between Mei's head and the pillar
const GONE_AT := 21.0  # and as she goes: in the front door's window
## Bearings from his seat at her height, in degrees (+ left), where nothing in the car hides her: the windscreen
## between its left pillar and Mei's head, the front door's window past that pillar, and the windscreen between Mei's
## head and its right pillar, short of Hafiz. She may pass behind the pillar or a head, but not as she goes.
const CLEAR := [Vector2(8.0, 12.0), Vector2(16.5, 25.5), Vector2(-35.0, -7.5)]
const FADE := 0.1  # seconds she takes to come out of the fog, and to go back into it
## The share of the road's fog between her and his eye in a glimpse: she shows through it more than the road does, as
## nothing of this world would. Everywhere else she takes all of it (1.0, the road's fog exactly).
const GLIMPSE_FOG := 0.1
const ABOVE_ROAD := 2.45  # her skull above the road behind a walker: the ends of her insides just clear it
const BEHIND := Vector2(18.0, 4.0)  # metres behind a walker along the road, from no rule broken to her nearest
const BEHIND_STILL := 1.0  # and as near as she comes when he has stood still long enough (RoadDirector.closing 1)
const FOLLOW := 6.0  # m/s at most, keeping behind a walker
const SPEED := 6.0  # m/s, coming for the camera
const LOW_IN := 2.0  # metres from the camera she comes down from ABOVE_ROAD to its height
const CLOSE := 0.6  # metres from the camera she stops at
## come_for: he sees her come. She starts where she is only if he sees her there: in view, with nothing solid in the way,
## and MIN_START or more from him. Otherwise she starts where she is told to (the flat's Main finds a clear line, and
## keeps her SHORT of what ends it), or out of the fog AHEAD of the camera along its level view. His held view turns to
## her over TURN (the presentation's PlayerController.turn_to), and then she is in it SEEN at the least before she
## reaches him: from a short way off she hangs at the start first.
const AHEAD := 15.0
const MIN_START := 2.0
const SHORT := 0.3
const TURN := 0.25
const SEEN := 0.5
## lunge: metres from his eyes to her skull's centre when he looks back and it counts. From here her head, crown to
## chin, fills over a third of his view (72 degrees high; 0.38 on the lunge still): size wins over distance.
const LUNGE_AT := 0.45
const LUNGE_HOLD := 0.5  # seconds she stays in his face before she pulls back
const LUNGE_CAPTION := "[She is right behind you.]"
## Her first wet flap behind him, captioned once: the same noise after it is not. Her flaps in her other places have no
## caption, and the door's slap has its own (RoadMain.CAPTIONS).
const FLAP_CAPTION := "[Behind you, something wet flaps.]"
## The stinger's and her shriek's play levels in his head (RoadAudio.play_here, so exact): their file peaks (0.80 and
## 0.32) summed at the master's 0.8 come to -6.7 dBFS, under the road's loudest peak now (-6.1). See
## docs/architecture.md, "Audio levels".
const STING_DB := -8.0
const SHRIEK_DB := -2.0
## Her fill, in her own space: off to her left, above and a little in front, so her brow leaves her eyes in deep
## sockets, her right cheek falls into shadow and her left eye catches it. It lights her alone, on render layer 12
## (LAYER), and only for a lunge.
const FILL := Vector3(0.22, 0.18, 0.14)
const FILL_ENERGY := 0.5  # dim and steady at a lunge; it fades out over the pull-back
const LAYER := 1 << 11  # render layer 12: her alone (the mirror's is 11)
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
## The wet flap's play level behind a walker: from 4 m back at her nearest it stands 13 dB over his steps and the wind.
const BEHIND_DB := 4.0
## [sound, the shortest and longest seconds between, play level] while she is in each place.
const NOISES := {
	&"behind": [[&"wet_flap", 3.0, 6.0, BEHIND_DB], [&"drip", 1.5, 4.0, 0.0]],
	&"catch": [[&"drip", 0.8, 2.0, 0.0]],
	&"come_for": [[&"wet_flap", 0.5, 0.9, 0.0]],
	&"fly": [[&"wet_flap", 0.5, 0.9, 0.0]],
	&"roof": [[&"drip", 2.0, 5.0, 0.0], [&"rattle", 6.0, 11.0, 0.0]],
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
## not rubber hoses or plastic. Where her paint is black (the hole of her mouth) nothing shines, and her hair's
## `specular` is low. `fade` dissolves her in and out. She makes her own fog, `fog_share` of the road's:
## writing FOG replaces the renderer's (Compatibility, scene.glsl: CUSTOM_FOG_USED skips fog_process, and the fog is
## then mixed in as ever), so it repeats fog_process's exponential fog from the road's density and colour in linear.
## ponytail: exponential fog only; the road has no height fog, no sun scatter and no depth fog to repeat.
const SWAY_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform float roughness = 0.5;
uniform float roughness_noise = 0.0;
uniform float specular = 0.5;
uniform float bump = 0.0;
uniform vec3 motion = vec3(0.0);
uniform float floor_y = -100.0;
uniform float fade = 1.0;
uniform float fog_density = 0.0;
uniform vec3 fog_color = vec3(0.0);
uniform float fog_share = 1.0;
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
	vec3 paint = texture(albedo_texture, UV).rgb;
	// Her mouth's hole is painted black: nothing there is lit or shines, not even the glancing shine of its steep walls
	// (AO, on the lights too). Read from the full-size texture, as those walls would read a blurred mip with her lips in.
	vec3 sharp = textureLod(albedo_texture, UV, 0.0).rgb;
	float lit = smoothstep(0.0, 0.003, max(sharp.r, max(sharp.g, sharp.b)));
	ALBEDO = albedo.rgb * paint * COLOR.rgb * lit;
	ROUGHNESS = roughness;
	SPECULAR = specular * lit;
	AO = lit;
	AO_LIGHT_AFFECT = 1.0;
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
	FOG = vec4(fog_color, fog_share * (1.0 - exp(min(0.0, -length(VERTEX) * fog_density))));
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
var audio: RoadAudio  # lunge: where the stinger and her shriek are played, in his head
var pool: MeshInstance3D  # catch: what spreads under him
var fill: OmniLight3D  # lunge: her own light on her

var _skin: Array[ShaderMaterial] = []  # her four surfaces
var _pool_material := ShaderMaterial.new()
var _mode := &""  # where she is: &"glimpse", &"behind", &"lunge", &"catch", &"fly", &"come_for", &"roof", or nowhere
var _t := 0.0  # seconds there
var _target: Node3D  # the walker, the victim, the camera or the car
var _drop := DROP  # catch: seconds she takes to drop onto him
var _from := Vector3.ZERO  # catch: where she drops from
var _to := Vector3.ZERO  # fly: where she flies to
var _hold := 0.0  # come_for: seconds she hangs at the start before she comes
var _pull_from := 1.0  # behind, back from a lunge: metres she had to go back, which her fill fades out over
var _lunge_eyes: Camera3D  # lunge: his eyes, whose place she holds her offset from
var _lunge_off := Vector3.ZERO  # lunge: where she is from his eyes, in the world: it does not turn with him
var _ahead := 0.0  # glimpse: metres ahead of the car she keeps pace at
var _out := 0.0  # glimpse: metres across
var _pace := 0.0  # glimpse: seconds she keeps pace for, before she stops dead
var _stop_s := 0.0  # glimpse: where along the road she is
var _until := GLIMPSE  # glimpse: seconds she is seen for
var _fall := Vector3.ZERO  # the way the victim falls
var _victim_at := Transform3D.IDENTITY  # where he stood
var _arrived := false
var _base := Vector3.ZERO  # where she is, before she bobs
var _last := Vector3.ZERO  # last frame
var _swing := Vector3.ZERO  # what hangs from her lags her motion: a velocity, on a spring
var _swing_v := Vector3.ZERO
var _timers := {}  # sound -> seconds to the next
var _smelt := false
var _flapped := false  # her flap behind him has had its caption
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
		elif own.resource_name == "hair":  # wet, but a phone's light along it is a dull streak, not grey plastic
			m.set_shader_parameter(&"specular", 0.2)
		mesh.set_surface_override_material(i, m)
		_skin.append(m)
	mesh.layers |= LAYER
	fill = OmniLight3D.new()
	fill.light_color = Color(0.75, 0.8, 0.9)  # the fog's grey, as the mirror's fourth passenger's
	fill.omni_range = 2.5
	fill.light_cull_mask = LAYER
	fill.position = FILL
	add_child(fill)
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


## Ahead of the car on the left verge, half in the fog: past the guard rail over the drop, or at the foot of the cut
## slope among its bushes. She keeps pace with the car at glimpse_distance, her face lit by the near headlight between
## the windscreen's pillar and Mei's head; then she stops dead and hangs there as the car passes her, out of the
## windscreen, behind the pillar, into the front door's window, where she is gone: GLIMPSE seconds or less, ending where
## he can see her. Her first glimpse leaves a smell behind. Where her pace, from where she shows to where she stops and
## hangs, crosses a change of the hill's side, she keeps between the rail's line and the bushes, right for either.
## ponytail: never in the tunnel's 80 m (Mission 2 shows her from s 387 on), where she would stand in its wall.
func show_glimpse() -> void:
	var span := _verge(director.car_s + glimpse_distance(director.her_near))
	_plan(span)
	if _verge(director.car_s + _ahead) != span or _verge(director.car_s + _travel(_pace) + _ahead) != span:
		_plan(Vector2(VALLEY_OUT.x, HILL_OUT.y))  # her pace crosses a change of the hill's side: right for either
	_until = GLIMPSE
	while _until > 0.0 and not _clear(_bearing(_until, _ahead, _out, _pace)):
		_until -= 0.05
	if _until <= 0.0:  # ponytail: never clear (none on Mission 2's spots, sampled); a place search would fix one
		_until = GLIMPSE
	_stop_s = director.car_s + _ahead
	_begin(&"glimpse", RoadLayout.point(_stop_s, _out) + Vector3.UP * GLIMPSE_UP)
	_set_fade(0.0)


## The metres across she may hang at, at s: past the rail where the valley is on the left, short of the bushes where
## the hill is.
func _verge(s: float) -> Vector2:
	return HILL_OUT if builder != null and builder.ground_at(s, 7.0) >= 0.0 else VALLEY_OUT


## Her glimpse on `span`: how far ahead and across she keeps pace, and for how long.
func _plan(span: Vector2) -> void:
	_ahead = glimpse_distance(director.her_near)
	while _bearing(0.0, _ahead, span.x, 0.0) > CLEAR[0].y and _ahead < GLIMPSE_AHEAD.x:
		_ahead += 0.5  # past the rail, this near, the pillar would hide her: as near as he can see her from
	var sign := _sign_from(director.car_s + _ahead)
	if sign < director.car_s + _ahead + 3.0:
		_ahead = sign + 3.0 - director.car_s  # past its board
		sign = _sign_from(sign + 3.0)
	_out = span.x
	for k in int((span.y - span.x) * 10.0) + 1:
		var out := span.x + k * 0.1
		if absf(_bearing(0.0, _ahead, out, 0.0) - PACE_AT) < absf(_bearing(0.0, _ahead, _out, 0.0) - PACE_AT):
			_out = out
	_pace = GLIMPSE
	while _pace > 0.0 and _bearing(GLIMPSE, _ahead, _out, _pace) < GONE_AT:
		_pace -= 0.05
	while _pace > 0.0 and director.car_s + _travel(_pace) + _ahead > sign - 3.0:
		_pace -= 0.05  # she stops short of a sign's board


## On the car's roof, over the edge on his side: her insides hang past his window (Task 9).
func on_roof(car: CarRig) -> void:
	_target = car
	_begin(&"roof", car.global_transform * ROOF)


## On the road behind the walker along the road, on his line, high enough that what hangs from her clears it: 18 m
## back with no rule broken, 4 m at her nearest (RoadDirector.her_near, read as he walks, so a rule he breaks on the
## way brings her gliding in, and so does his standing still).
func behind(walker: Node3D) -> void:
	var was := _mode == &"behind"
	_target = walker
	if not was:
		_begin(&"behind", _behind_point())


## Her breath, where she hangs behind a walker: she is closing in (the walk's `she_closes`).
func breathe() -> void:
	_play(&"rattle", BEHIND_DB)


## He looked back, and it counted: she is right behind him. In the same frame she is LUNGE_AT from his eyes in the
## middle of his view, wherever he looks up or down (the look counts on his yaw alone), upright and facing him in her
## own fill, as the stinger and her shriek sound in his head and the caption shows. Through LUNGE_HOLD she goes where he
## goes, so a step into her does not carry his eyes into her head, but she does not turn with him. Then she pulls back to
## where she follows him (behind), at FOLLOW, from where she is. Only from behind him; a lunge during a lunge starts it
## over.
func lunge(camera: Camera3D) -> void:
	if _mode != &"behind" and _mode != &"lunge":
		return
	_lunge_eyes = camera
	_lunge_off = -camera.global_basis.z * LUNGE_AT
	_begin(&"lunge", camera.global_position + _lunge_off)
	_face(camera.global_position)
	audio.play_here(&"stinger", STING_DB)
	audio.play_here(&"shriek", SHRIEK_DB)
	EventBus.subtitle_requested.emit(LUNGE_CAPTION, 3.0)


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


## She flies straight to `at` at SWOOP, facing the way she goes, and hangs there: `arrived`. The caller picks a point
## whose line clears whoever is in the way, by more than what hangs from her.
func fly_to(at: Vector3) -> void:
	_to = at
	_arrived = false
	_begin(&"fly", global_position if visible else at)


## She comes straight at the camera at SPEED from where he sees her, or from `from`, or out of the fog ahead of it, high
## enough that what hangs from her clears the road, and comes down to its height over the last LOW_IN metres. In the
## flat (no director) she comes at its height all the way, along the clear line she starts on and under every door's
## top; what hangs from her lies on the floor, as it does once she is there. She stops CLOSE to it, face to face:
## `reached`, TURN + SEEN after this at the soonest.
func come_for(camera: Camera3D, from := Vector3.INF) -> void:
	_target = camera
	_arrived = false
	var eye := camera.global_position
	var start := global_position
	if not (visible and start.distance_to(eye) >= MIN_START and camera.is_position_in_frustum(start) and _in_sight(eye, start)):
		start = from if from.is_finite() else eye - camera.global_basis.z.slide(Vector3.UP).normalized() * AHEAD
	_begin(&"come_for", start)
	_hold = maxf(0.0, TURN + SEEN - ((eye - start).slide(Vector3.UP).length() - CLOSE) / SPEED)
	_play(&"rattle")


## Whether nothing solid is between `eye` and `at`.
func _in_sight(eye: Vector3, at: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at)).is_empty()


## She is gone, and so is anything she left.
func hide_her() -> void:
	_mode = &""
	_target = null
	visible = false
	fill.visible = false
	pool.visible = false


func _process(delta: float) -> void:
	if _mode == &"":
		return
	_t += delta
	var bob := 0.04
	match _mode:
		&"glimpse":
			if _t < _pace:
				_stop_s = director.car_s + _ahead  # keeping pace with the car
			_base = RoadLayout.point(_stop_s, _out) + Vector3.UP * GLIMPSE_UP
			_face(RoadLayout.point(director.car_s, director.lane))
			_set_fade(clampf(minf(_t, _until - _t) / minf(FADE, _until / 3.0), 0.0, 1.0))
			if _t >= _until:
				hide_her()
				if not _smelt:
					_smelt = true
					EventBus.line_requested.emit(SMELL, 4.0)  # always shown: a smell has no sound to caption
				return
		&"behind":
			_base = _base.move_toward(_behind_point(), FOLLOW * delta)
			_face(_target.global_position)
			if fill.visible:  # back from a lunge: her fill fades out as she goes, and is out once she is there
				fill.light_energy = minf(fill.light_energy, FILL_ENERGY * _base.distance_to(_behind_point()) / _pull_from)
				fill.visible = fill.light_energy > 0.0
		&"lunge":
			bob = 0.0
			if is_instance_valid(_lunge_eyes):
				_base = _lunge_eyes.global_position + _lunge_off
				_face(_lunge_eyes.global_position)
			if _t >= LUNGE_HOLD:
				_mode = &"behind"
				_t = 0.0
				_pull_from = maxf(_base.distance_to(_behind_point()), 0.01)
		&"catch":
			_feed(delta)
			bob = 0.02
		&"fly":
			_face(_to)
			_base = _base.move_toward(_to, SWOOP * delta)
			bob = 0.0
			if _base.is_equal_approx(_to) and not _arrived:
				_arrived = true
				arrived.emit()
		&"come_for":
			var cam := _target.global_position
			if _t >= _hold:
				var flat := (cam - _base).slide(Vector3.UP)
				_base += flat.normalized() * clampf(flat.length() - CLOSE, 0.0, SPEED * delta)
				var left := (cam - _base).slide(Vector3.UP).length() - CLOSE
				var high := cam.y if director == null else maxf(cam.y, _ground_under(_base) + ABOVE_ROAD)
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
			_play(noise[0], noise[3])
			if noise[0] == &"wet_flap" and _mode == &"behind" and not _flapped:
				_flapped = true
				EventBus.subtitle_requested.emit(FLAP_CAPTION, 2.5)


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
	if _passed(_drop + FALL, delta):
		caught.emit(_target)


func _behind_point() -> Vector3:
	var at := _target.global_position
	var s := RoadLayout.closest_s(at)
	var back := behind_distance(director.her_near, director.closing)
	return RoadLayout.point(s - back, RoadLayout.across(at, s)) + Vector3.UP * ABOVE_ROAD


## Metres behind a walker along the road: BEHIND by her_near, and on towards BEHIND_STILL as `closing` goes to 1.
static func behind_distance(her_near: float, closing: float) -> float:
	return lerpf(lerpf(BEHIND.x, BEHIND.y, her_near), BEHIND_STILL, closing)


## How far ahead of the car, along the road, her glimpse is.
static func glimpse_distance(her_near: float) -> float:
	return lerpf(GLIMPSE_AHEAD.x, GLIMPSE_AHEAD.y, clampf(her_near / NEAREST, 0.0, 1.0))


## His bearing to her from his seat, in degrees (+ left), `t` seconds into a glimpse `ahead` of the car and `out`
## across, keeping pace for `pace` seconds.
func _bearing(t: float, ahead: float, out: float, pace: float) -> float:
	var her := RoadLayout.point(director.car_s + _travel(minf(t, pace)) + ahead, out)
	var car := CarRig.on_road(director.car_s + _travel(t), director.lane)
	var at := car.affine_inverse() * (her + Vector3.UP * GLIMPSE_UP) - SEAT
	return rad_to_deg(atan2(at.x, at.z))


## Metres the car goes in `t` seconds of a glimpse. ponytail: it is taken to slow at RoadDirector.ACCEL, as Mission 2's
## does after the pass; at a steady speed she would go past the door's window early, and be cut short in view.
func _travel(t: float) -> float:
	var t_stop := minf(t, director.car_speed / RoadDirector.ACCEL)
	return director.car_speed * t_stop - 0.5 * RoadDirector.ACCEL * t_stop * t_stop


## Whether nothing in the car hides her at `bearing` from his seat (CLEAR).
static func _clear(bearing: float) -> bool:
	return CLEAR.any(func(band: Vector2) -> bool: return bearing >= band.x and bearing <= band.y)


## Where the first roadside sign is from 3 m short of s on, or INF: her face keeps 3 m clear of a board.
static func _sign_from(s: float) -> float:
	var first := INF
	for at: float in RoadBuilder.WINDING + RoadBuilder.SIGNS.map(func(sign: Array) -> float: return sign[0]):
		if at > s - 3.0:
			first = minf(first, at)
	return first


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
	_set_fade(1.0)
	fill.visible = mode == &"lunge"
	fill.light_energy = FILL_ENERGY if fill.visible else 0.0
	visible = true


## What hangs from her swings after her motion, as a heavy wet rope would (a period of about 2 s, settling in a few
## swings), and lies on the ground wherever it would reach below it. Her fog follows the road's as it thickens.
func _sway(delta: float) -> void:
	var v := (global_position - _last) / delta if delta > 0.0 else Vector3.ZERO
	_last = global_position
	_swing_v += ((v - _swing) * 9.0 - _swing_v * 2.0) * delta
	_swing += _swing_v * delta
	var motion := global_basis.inverse() * _swing
	var floor_y := _ground_under(global_position) + 0.02 - global_position.y
	var env := builder.environment if builder != null else null
	var density := env.fog_density if env != null and env.fog_enabled else 0.0
	var fog := env.fog_light_color.srgb_to_linear() * env.fog_light_energy if env != null else Color.BLACK
	for m in _skin:
		m.set_shader_parameter(&"motion", motion)
		m.set_shader_parameter(&"floor_y", floor_y)
		m.set_shader_parameter(&"fog_density", density)
		m.set_shader_parameter(&"fog_color", Vector3(fog.r, fog.g, fog.b))
		m.set_shader_parameter(&"fog_share", GLIMPSE_FOG if _mode == &"glimpse" else 1.0)


## The ground's height under `at`: the road's, and beside it the verge, the drain or the drop into the valley. In the flat
## (no director) it is the flat's floor.
func _ground_under(at: Vector3) -> float:
	if director == null:
		return 0.0
	var s := RoadLayout.closest_s(at)
	var road := RoadLayout.point(s).y
	return road + builder.ground_at(s, RoadLayout.across(at, s)) if builder != null else road


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


func _play(sound: StringName, volume_db := 0.0) -> void:
	EventBus.sound_requested.emit(sound, global_position, volume_db)

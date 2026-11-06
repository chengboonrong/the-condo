class_name RoadBuilder
extends Node3D
## The road down the mountain, built in code from RoadLayout: the asphalt and its lines, the verges, the open monsoon
## drain on the hill side and the guard rail on the valley side, the jungle in layers of tree cards, the signs, the
## sodium lamps near the resort, the tunnel, the resort's back wall with the staff exit, the bus stop, and colliders
## that keep him on the road and its verges. All of it is cut into chunks of CHUNK_ROWS rows (100 m), each with a
## visibility range, so only what is near is drawn. Textures are drawn in code; there are no image files.
##
## Which side is the hill: the left, the resort's side, as far as the tunnel, which goes through a spur. After it the
## right, until the first switchback. Each switchback has the hill on its inside, and the hill stays on that side until
## the next one. The ground beside the road changes over within BLEND metres of each of those points.

## The texts a sign may carry. Each was checked against photographs of Malaysian roads or JKR's sign manual: see
## docs/architecture.md, "The road: invented names". "SELEKOH MERBAHAYA" is spelt as the boards print it.
const SIGN_TEXTS := ["AWAS", "KURANGKAN LAJU", "SELEKOH MERBAHAYA DI HADAPAN", "KAWASAN TANAH RUNTUH", "PANDU BERHATI-HATI", "KAWASAN KEMALANGAN", "200 m", "40 km/j"]
## The AWAS boards, on the left verge facing the traffic coming down: [s, lines]. Red with white text.
const SIGNS := [
	[40.0, ["AWAS", "KAWASAN TANAH RUNTUH", "PANDU BERHATI-HATI"]],  # past the stop, under the cut slope
	[431.0, ["AWAS", "SELEKOH MERBAHAYA DI HADAPAN", "200 m", "KURANGKAN LAJU"]],  # 200 m before switchback 1
	[1480.0, ["AWAS", "KAWASAN TANAH RUNTUH", "PANDU BERHATI-HATI"]],
	[1765.0, ["AWAS", "KAWASAN KEMALANGAN", "KURANGKAN LAJU"]],  # where the long straight begins
	[2292.0, ["AWAS", "SELEKOH MERBAHAYA DI HADAPAN", "KURANGKAN LAJU", "40 km/j"]],  # 200 m before switchback 4
]
const WINDING := [560.0, 2420.0]  # the winding-road diamond, black on yellow, before each stack of switchbacks

const FOG_CLEAR := 0.035  # fog density with no rule broken (set_fog(0))
const FOG_THICK := 0.11  # with every rule broken (set_fog(1))
const FOG_COLOR := Color(0.2, 0.205, 0.21)  # night fog, faintly lit; the background is the same, so far is fog
const STEP := 2.0  # metres between the rows of the road's meshes and colliders
const CHUNK_ROWS := 50
const VIEW := 150.0  # visibility_range_end of everything in a chunk (the camera's far plane is 120 m)
const EDGE := 3.9  # the asphalt's edge, off the centreline; the edge lines are painted just inside it
const DASH := 3.0  # the centre line: a dash this long...
const DASH_PERIOD := 9.0  # ...in every this many metres
const BLEND := 12.0  # metres either side of a change of the hill's side
const WALL_HILL := 5.5  # how far he can walk off the centreline: up to the drain on the hill side,
const WALL_VALLEY := 4.75  # to the face of the guard rail on the valley side,
const WALL_TUNNEL := 3.9  # and to the walkway's kerb in the tunnel
const RESORT_END := -22.0  # the resort's back wall stands on the left from START_S to here
const GATE_S := -196.0  # the resort's service gate, shut, across the top of the road
const SODIUM := Color(1.0, 0.6, 0.26)
const STRIP := Vector2(2.6, 5.72)  # the tunnel's light strips: out and up, just under the vault (5.80 there)
const CITY_AWAY := 100.0  # metres from the camera to KL's glow: inside its 120 m far plane
const CITY_ALPHA := 0.3  # the glow's strength in the clearest fog; the thickest takes it away
const LIGHT_AWAY := 90.0  # metres from the camera, at the most, that the light far down the road is drawn at
const LIGHT_UP := 2.6  # its bulb, above the road
const LIGHT_ALPHA := 0.8  # its strength in the clearest fog; the thickest takes most of it away
const LIGHT_SIZE := 36.0  # metres across its haze, at the bulb: wide enough to spill past Mei from his seat
const LAMPS := [[-170.0, -1.0], [-110.0, -1.0], [5.0, 1.0], [70.0, -1.0], [130.0, 1.0]]  # [s, side]: +1 left

## The ground beside the road, as (metres out from the centreline, metres up), each point a [valley, hill] pair lerped
## by how much that side is the hill. The verge runs flat from EDGE to the first point.
const DRAIN := [  # concrete: the open monsoon drain on the hill side, an apron falling away on the valley side
	[Vector2(5.0, 0.0), Vector2(5.6, 0.0)],
	[Vector2(5.2, -0.15), Vector2(5.66, -0.5)],
	[Vector2(5.4, -0.35), Vector2(6.14, -0.5)],
	[Vector2(5.6, -0.6), Vector2(6.2, 0.0)],
]
const SLOPE := [  # earth, after the drain: the cut slope up into the jungle, or the fall into the valley
	[Vector2(7.0, -2.0), Vector2(6.8, 1.6)],
	[Vector2(10.0, -6.0), Vector2(9.5, 7.0)],
	[Vector2(18.0, -16.0), Vector2(15.0, 16.0)],
	[Vector2(34.0, -36.0), Vector2(22.0, 27.0)],
]
const RAIL := [  # the W-beam's face, bottom to top, its two ribs towards the road
	Vector2(4.8, 0.45), Vector2(4.74, 0.5), Vector2(4.74, 0.55), Vector2(4.8, 0.605),
	Vector2(4.74, 0.66), Vector2(4.74, 0.71), Vector2(4.8, 0.76),
]
const LINING := [  # the tunnel, one half: the kerb, the walkway, the wall, the vault up to the crown
	Vector2(EDGE, 0.0), Vector2(EDGE, 0.22), Vector2(4.9, 0.22), Vector2(5.15, 0.4),
	Vector2(5.15, 4.0), Vector2(4.2, 5.4), Vector2(2.0, 5.95), Vector2(0.0, 6.05),
]
## [hill side, card (0 broadleaf, 1 tree fern), metres between, out from the centreline, width, height, sunk]. A card
## never reaches the walkable verge: its crossed quads stand at 45 degrees to the road.
const TREES := [
	[true, 0, 3.0, Vector2(6.9, 8.0), Vector2(1.8, 2.8), Vector2(1.4, 2.4), 0.6],  # bushes on the foot of the cut
	[true, 1, 7.0, Vector2(8.0, 11.0), Vector2(3.5, 5.0), Vector2(3.5, 5.5), 0.0],  # tree ferns
	[true, 0, 5.0, Vector2(9.5, 13.0), Vector2(6.0, 9.0), Vector2(9.0, 14.0), 0.5],  # the canopy
	[true, 0, 6.0, Vector2(15.0, 21.0), Vector2(9.0, 13.0), Vector2(12.0, 18.0), 0.5],  # and the canopy above it
	[false, 0, 3.5, Vector2(5.4, 6.4), Vector2(1.6, 2.6), Vector2(1.2, 2.0), 0.4],  # bushes behind the rail
	[false, 1, 6.0, Vector2(6.6, 8.5), Vector2(3.5, 5.0), Vector2(3.5, 5.5), 0.0],  # tree ferns on the edge
	[false, 0, 4.5, Vector2(9.0, 16.0), Vector2(7.0, 10.0), Vector2(11.0, 17.0), 0.5],  # crowns at the road's height
	[false, 0, 6.0, Vector2(17.0, 26.0), Vector2(9.0, 13.0), Vector2(14.0, 20.0), 0.5],  # and lower down
]

const ASPHALT := Color(1.0, 1.0, 1.0)
const VERGE := Color(0.2, 0.21, 0.15)
const CONCRETE := Color(0.46, 0.46, 0.43)
const EARTH := Color(0.15, 0.17, 0.12)
const STEEL := Color(0.52, 0.54, 0.55)
const AWAS_RED := Color(0.6, 0.05, 0.05)
const POST_BANDS := [Color(0.06, 0.06, 0.06), Color(0.85, 0.85, 0.83)]  # black and white every 0.3 m
const FONT_PX := 64

var environment: Environment
var city_dir: Vector3  # where KL lies, level: the way the whole road goes down
var signs: Array[GeometryInstance3D] = []  # every part of every sign: the boards, their posts and their lines
var far_light: MeshInstance3D  # the light far down the road, once the car has died there (show_light)
var _materials: Array[Material] = []
var _mats := {}  # mesh kind -> its material
var _spans: Array = []  # [s_from, s_to, segment], one per RoadLayout.SEGMENTS
var _flips: Array = []  # [s, the hill's side after it]: +1 left, -1 right
var _rows: Array[Row] = []
var _chunks: Array[Chunk] = []
var _city: MeshInstance3D
var _far_at := Vector3.ZERO  # where the far light's bulb really is


## One row of the road's meshes, and the frame anything placed beside the road at s uses.
class Row:
	var s: float
	var p: Vector3  # the centreline
	var fwd: Vector3  # down the road, level
	var left: Vector3  # across, to the left
	var hill: float  # +1: the hill is on the left; -1: on the right; between them near a change-over
	var inside := 0.0  # on a bend, the side it turns to (+1 left)
	var room := INF  # on a bend, its radius: how far the inside can reach

	func at(side: float, out: float, up: float) -> Vector3:
		return p + left * (side * out) + Vector3.UP * up

	## 1 where `side` is the hill, 0 where it is the valley.
	func hilly(side: float) -> float:
		return clampf((side * hill + 1.0) * 0.5, 0.0, 1.0)

	## Facing back up the road, x to the right of someone coming down: the way a sign faces.
	func basis() -> Basis:
		return Basis.looking_at(fwd)


## A 100 m piece of the road: its meshes by kind, its trees by card, its colliders, all relative to node.
class Chunk:
	var node: Node3D
	var tools := {}  # kind -> SurfaceTool
	var trees := [[], []]  # per card: Transform3D
	var faces := PackedVector3Array()


## The yaw (PlayerController.set_look) that faces down the road at s.
static func yaw_along(s: float) -> float:
	var t := RoadLayout.tangent(s)
	return atan2(-t.x, -t.z)


## Each segment's [s_from, s_to, segment], its length measured as RoadLayout._build measures it.
static func spans() -> Array:
	var flat := sqrt(1.0 - RoadLayout.GRADE * RoadLayout.GRADE)
	var s := RoadLayout.START_S
	var out := []
	for seg: Array in RoadLayout.SEGMENTS:
		var length: float = seg[1] if seg[0] == "straight" else seg[1] * deg_to_rad(absf(seg[2])) / flat
		out.append([s, s + length, seg])
		s += length
	return out


func _ready() -> void:
	_spans = spans()
	_flips = _hill_flips()
	_build_environment()
	_build_materials()
	var end: float = _spans[-1][1]
	var s := RoadLayout.START_S
	while s <= end - 0.5:
		_rows.append(_row(s))
		s += STEP
	for c in ceili((_rows.size() - 1) / float(CHUNK_ROWS)):
		var chunk := Chunk.new()
		chunk.node = Node3D.new()
		chunk.node.name = "Chunk%d" % c
		chunk.node.position = _rows[mini(c * CHUNK_ROWS + CHUNK_ROWS / 2, _rows.size() - 1)].p
		add_child(chunk.node)
		_chunks.append(chunk)
	for i in _rows.size() - 1:
		_build_row(_chunks[i / CHUNK_ROWS], _rows[i], _rows[i + 1], i)
	_build_ends()
	_build_trees()
	_build_chevrons()
	_build_signs()
	for lamp: Array in LAMPS:
		_lamp(lamp[0], lamp[1])
	_build_tunnel()
	_build_resort()
	_build_stop()
	_build_city()
	_build_far_light()
	for c in _chunks:
		_commit(c)
	Settings.changed.connect(_apply_brightness)


## 0 is the clearest fog, with no rule broken; 1 the thickest.
func set_fog(amount: float) -> void:
	environment.fog_density = lerpf(FOG_CLEAR, FOG_THICK, clampf(amount, 0.0, 1.0))
	var city := _city.material_override as StandardMaterial3D
	var alpha := CITY_ALPHA * (1.0 - clampf(amount, 0.0, 1.0))
	if not is_equal_approx(city.albedo_color.a, alpha):  # no material update on a still frame
		city.albedo_color.a = alpha
	var far := far_light.material_override as StandardMaterial3D
	alpha = LIGHT_ALPHA * (1.0 - 0.6 * clampf(amount, 0.0, 1.0))
	if not is_equal_approx(far.albedo_color.a, alpha):
		far.albedo_color.a = alpha


## The light far down the road comes on: a bulb over the road at s.
func show_light(s: float) -> void:
	_far_at = RoadLayout.point(s) + Vector3.UP * LIGHT_UP
	far_light.visible = true


## KL's glow stays CITY_AWAY down the valley from wherever the camera is, so it reads as far below. The far light is
## drawn on the line to its bulb, no further than LIGHT_AWAY and at the size it would have there.
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_city.global_position = camera.global_position + city_dir * CITY_AWAY + Vector3.DOWN * 5.0
		if far_light.visible:
			var to := _far_at - camera.global_position
			var k := minf(1.0, LIGHT_AWAY / maxf(to.length(), 0.01))
			far_light.global_position = camera.global_position + to * k
			far_light.scale = Vector3.ONE * k


## Every material the road made, for the start card's warm-up. The signs' lines (Label3D) draw with the engine's own.
func materials() -> Array[Material]:
	return _materials


# --- the hill's side ----------------------------------------------------------------------------

## The left before the tunnel's middle, the right after it, then the inside of each switchback from where its bend
## begins (the switchbacks that turn the way the hill already is change nothing).
func _hill_flips() -> Array:
	var out := [[(RoadLayout.TUNNEL.x + RoadLayout.TUNNEL.y) * 0.5, 0.0]]
	for sp: Array in _spans:
		var seg: Array = sp[2]
		if seg[0] == "bend" and absf(seg[2]) >= 180.0:
			if out.size() == 1:
				out[0][1] = -signf(seg[2])  # before the first switchback its outside is the hill
			out.append([sp[0], signf(seg[2])])
	return out


func _hill(s: float) -> float:
	var side := 1.0
	for f: Array in _flips:
		if s <= f[0] - BLEND:
			break
		if s < f[0] + BLEND:
			return lerpf(side, f[1], smoothstep(f[0] - BLEND, f[0] + BLEND, s))
		side = f[1]
	return side


func _row(s: float) -> Row:
	var r := Row.new()
	r.s = s
	r.p = RoadLayout.point(s)
	var t := RoadLayout.tangent(s)
	r.fwd = Vector3(t.x, 0.0, t.z).normalized()
	r.left = Vector3(r.fwd.z, 0.0, -r.fwd.x)
	r.hill = _hill(s)
	for sp: Array in _spans:
		if s >= sp[0] and s < sp[1]:
			if sp[2][0] == "bend":
				r.inside = signf(sp[2][2])
				r.room = sp[2][1]
			break
	return r


## The ground beside the road on `side` at r: EDGE, then DRAIN (points 1 to 4), then SLOPE (4 to 8). On the inside
## of a bend nothing reaches past 2.5 m short of its centre.
func _ground(r: Row, side: float) -> PackedVector2Array:
	var t := r.hilly(side)
	var room := r.room - 2.5 if r.inside == side else INF
	var out := PackedVector2Array([Vector2(EDGE, 0.0)])
	for pair: Array in DRAIN + SLOPE:
		var q: Vector2 = (pair[0] as Vector2).lerp(pair[1], t)
		out.append(Vector2(minf(q.x, room), q.y))
	return out


## The ground's height `out` metres off the centreline, past the last point along the last slope.
static func _height(profile: PackedVector2Array, out: float) -> float:
	for j in range(1, profile.size()):
		if out <= profile[j].x or j == profile.size() - 1:
			var a := profile[j - 1]
			var b := profile[j]
			return a.y + (b.y - a.y) * (out - a.x) / maxf(b.x - a.x, 0.001)
	return 0.0


## The ground's height `across` metres off the centreline at s (+ left), from the road's own height: 0 on the asphalt,
## then the verge, the drain or the apron, and the cut slope up or the fall into the valley (the tunnel's lining aside).
func ground_at(s: float, across: float) -> float:
	return _height(_ground(_row(s), signf(across)), absf(across))


## How far from the centreline he can walk on `side` (+1 left) at s: to the drain or the rail's face, or the kerb in
## the tunnel.
func wall(s: float, side: float) -> float:
	return _wall(_row(s), side)


func _wall(r: Row, side: float) -> float:
	return WALL_TUNNEL if _in_tunnel(r.s) else lerpf(WALL_VALLEY, WALL_HILL, r.hilly(side))


static func _in_tunnel(s: float) -> bool:
	return s >= RoadLayout.TUNNEL.x and s <= RoadLayout.TUNNEL.y


# --- the road, row by row -----------------------------------------------------------------------

## Everything between rows a and b: the asphalt, the ground on both sides (or the tunnel's lining), the guard rail
## on the valley side, and the colliders: the floor out to the walls, and the walls.
func _build_row(c: Chunk, a: Row, b: Row, i: int) -> void:
	var v0 := (a.s - RoadLayout.START_S) / DASH_PERIOD
	var v1 := (b.s - RoadLayout.START_S) / DASH_PERIOD
	_poly(c, &"road", [a.at(1.0, -EDGE, 0.0), a.at(1.0, EDGE, 0.0), b.at(1.0, EDGE, 0.0), b.at(1.0, -EDGE, 0.0)], Vector3.UP, ASPHALT, [Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)])
	var tunnel := _in_tunnel(a.s) and _in_tunnel(b.s)
	var limits: Array[float] = []
	for side: float in [1.0, -1.0]:
		if tunnel:
			var lining := PackedVector2Array(LINING)
			_strip(c, &"ground", a, b, side, lining, lining, 0, lining.size() - 1, CONCRETE * 0.8)
		else:
			var ga := _ground(a, side)
			var gb := _ground(b, side)
			_strip(c, &"ground", a, b, side, ga, gb, 0, 1, VERGE)
			_strip(c, &"ground", a, b, side, ga, gb, 1, 4, CONCRETE)
			_strip(c, &"ground", a, b, side, ga, gb, 4, ga.size() - 1, EARTH)
			if a.hilly(side) < 0.05 and b.hilly(side) < 0.05 and not _in_tunnel(a.s) and not _in_tunnel(b.s):
				var rail := PackedVector2Array(RAIL)
				_strip(c, &"ground", a, b, side, rail, rail, 0, rail.size() - 1, STEEL)
				_strip(c, &"ground", a, b, side, rail, rail, 0, rail.size() - 1, STEEL * 0.7, true)  # its back
				if i % 2 == 0:  # a post every 4 m
					_box(c, &"ground", Transform3D(a.basis(), a.at(side, 4.92, 0.375)), Vector3(0.15, 0.75, 0.1), STEEL * 0.8)
		limits.append(_wall(a, side))  # each end its own, so the wall slants into a tunnel mouth with no gap
		limits.append(_wall(b, side))
	# limits: left at a, left at b, right at a, right at b
	var floor_a := [a.at(1.0, limits[0], 0.0), a.at(-1.0, limits[2], 0.0)]
	var floor_b := [b.at(1.0, limits[1], 0.0), b.at(-1.0, limits[3], 0.0)]
	_face(c, [floor_a[0], floor_b[0], floor_b[1], floor_a[1]])
	for k in 2:
		_face(c, [floor_a[k] + Vector3.DOWN, floor_b[k] + Vector3.DOWN, floor_b[k] + Vector3.UP * 3.0, floor_a[k] + Vector3.UP * 3.0])


## Walls across both ends of the walk: at the resort's service gate and at the road's last row.
func _build_ends() -> void:
	for r: Row in [_row(GATE_S + 2.0), _rows[-1]]:
		var c := _chunk_at(r.s)
		_face(c, [r.at(1.0, 8.0, -1.0), r.at(-1.0, 8.0, -1.0), r.at(-1.0, 8.0, 4.0), r.at(1.0, 8.0, 4.0)])


# --- the jungle, the signs and the lamps ---------------------------------------------------------

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1147
	var end := _rows[-1].s
	for side: float in [1.0, -1.0]:
		for layer: Array in TREES:
			var s: float = RoadLayout.START_S + rng.randf() * layer[2]
			while s < end:
				_tree(side, s, layer, rng)
				s += layer[2] * rng.randf_range(0.6, 1.4)


func _tree(side: float, s: float, layer: Array, rng: RandomNumberGenerator) -> void:
	var out := rng.randf_range(layer[3].x, layer[3].y)
	var width := rng.randf_range(layer[4].x, layer[4].y)
	var height := rng.randf_range(layer[5].x, layer[5].y)
	var yaw := rng.randf_range(-0.2, 0.2)
	if s > RoadLayout.TUNNEL.x - 3.0 and s < RoadLayout.TUNNEL.y + 3.0:
		return
	if side > 0.0 and out < 14.0 and (s < RESORT_END or absf(s - RoadLayout.BUS_STOP_S) < 5.0):
		return  # the resort's back wall, and the bus stop
	var r := _row(s)
	var hill := r.hilly(side) > 0.5
	if hill != layer[0] or (r.inside == side and out > r.room - 4.0):
		return
	width = minf(width, (out - (6.3 if hill else 4.9)) / 0.354)  # half its width, at 45 degrees, short of the verge
	var c := _chunk_at(s)
	var base := r.at(side, out, _height(_ground(r, side), out) - layer[6])
	var basis := Basis(Vector3.UP, atan2(-r.fwd.x, -r.fwd.z) + PI / 4.0 + yaw).scaled(Vector3(width, height, width))
	c.trees[layer[1]].append(Transform3D(basis, base - c.node.position))


## Chevron boards round the outside of every switchback, black on yellow, one every 7 m, facing the traffic coming
## down. The chevrons point the way the road turns.
func _build_chevrons() -> void:
	for sp: Array in _spans:
		var seg: Array = sp[2]
		if seg[0] != "bend" or absf(seg[2]) < 180.0:
			continue
		var turn := signf(seg[2])
		var s: float = sp[0] + BLEND
		while s < sp[1] - 3.0:
			var r := _row(s)
			var basis := r.basis()
			var c := _chunk_at(s)
			var mid := _board(c, r, -turn, Vector2(0.6, 0.75), 0.925, 0.0)
			var x := basis.x * 0.3
			var y := Vector3.UP * 0.375
			var u := [0.0, 0.25] if turn < 0.0 else [0.25, 0.0]  # the board's chevron points right: mirrored for a left turn
			_poly(c, &"sign_faces", [mid - x - y, mid + x - y, mid + x + y, mid - x + y], basis.z, Color.WHITE, [Vector2(u[0], 0.625), Vector2(u[1], 0.625), Vector2(u[1], 0.0), Vector2(u[0], 0.0)])
			s += 7.0


## The AWAS boards and the winding-road diamonds, on the left verge, beyond the drain or behind the rail.
func _build_signs() -> void:
	var font := ThemeDB.fallback_font
	for sign: Array in SIGNS:
		var r := _row(sign[0])
		var c := _chunk_at(sign[0])
		var basis := r.basis()
		var lines: Array = sign[1]
		var sizes := lines.map(func(text: String) -> float: return 0.0056 if text == "AWAS" else 0.0026)
		var width := 0.0
		var height := 0.3
		for k in lines.size():
			width = maxf(width, font.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x * sizes[k])
			height += font.get_height(FONT_PX) * sizes[k]
		width += 0.4
		var mid := _board(c, r, 1.0, Vector2(width, height), 1.4, 0.3)
		_box(c, &"signs", Transform3D(basis, mid), Vector3(width, height, 0.04), AWAS_RED)
		var top := height * 0.5 - 0.15  # from the board's middle
		for k in lines.size():
			var line_height: float = font.get_height(FONT_PX) * sizes[k]
			var label := Label3D.new()
			label.text = lines[k]
			label.font_size = FONT_PX
			label.pixel_size = sizes[k]
			label.outline_size = 0
			label.modulate = Color(0.95, 0.95, 0.92)
			label.shaded = true
			label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			label.visibility_range_end = VIEW
			label.transform = Transform3D(basis, mid + Vector3.UP * (top - line_height * 0.5) + basis.z * 0.025 - c.node.position)
			top -= line_height
			c.node.add_child(label)
			signs.append(label)
	for s: float in WINDING:
		var r := _row(s)
		var c := _chunk_at(s)
		var basis := r.basis()
		var mid := _board(c, r, 1.0, Vector2(0.9, 0.9), 1.75, 0.0)
		var x := basis.x * 0.45
		var y := Vector3.UP * 0.45
		_poly(c, &"sign_faces", [mid + y, mid + x, mid - y, mid - x], basis.z, Color.WHITE, [Vector2(0.5, 0.0), Vector2(0.75, 0.5), Vector2(0.5, 1.0), Vector2(0.25, 0.5)])


## Sets a board of `size` (width, height) beside the road on `side` at r, and its banded posts. On the valley side it
## stands behind the guard rail, `bottom` metres up. On the hill side it hangs over the verge, high enough to walk
## under and to clear the cut slope it reaches into. The posts (`inset` in from each edge, or one in the middle for
## 0) start on the ground. Returns the board's centre.
func _board(c: Chunk, r: Row, side: float, size: Vector2, bottom: float, inset: float) -> Vector3:
	var ground := _ground(r, side)
	var near := EDGE + 0.15
	if r.hilly(side) > 0.5:
		bottom = maxf(2.2, _height(ground, near + size.x) + 0.3)
	else:
		near = WALL_VALLEY + 0.3
	var basis := r.basis()
	var top := r.p.y + bottom + size.y - 0.1
	for x: float in ([near + size.x * 0.5] if inset == 0.0 else [near + inset, near + size.x - inset]):
		var foot := r.at(side, x, _height(ground, x))
		_post(c, Transform3D(basis, foot - basis.z * 0.05), top - foot.y)
	return r.at(side, near + size.x * 0.5, bottom + size.y * 0.5)


## A sodium street lamp on `side`: a pole beyond the walk wall, an arm over the road, the glowing head, its light,
## and the halo the fog would make round it.
func _lamp(s: float, side: float) -> void:
	var r := _row(s)
	var c := _chunk_at(s)
	var basis := r.basis()
	var out := 6.6 if r.hilly(side) > 0.5 else 5.4
	var reach := out - 2.3
	var foot := _height(_ground(r, side), out)
	_box(c, &"ground", Transform3D(basis, r.at(side, out, (foot + 8.0) * 0.5)), Vector3(0.16, 8.0 - foot, 0.16), STEEL * 0.7)
	_box(c, &"ground", Transform3D(basis, r.at(side, (out + reach) * 0.5, 7.92)), Vector3(2.4, 0.08, 0.08), STEEL * 0.7)
	_box(c, &"ground", Transform3D(basis, r.at(side, reach, 7.95)), Vector3(0.7, 0.16, 0.32), STEEL * 0.5)
	_box(c, &"sodium", Transform3D(basis, r.at(side, reach, 7.86)), Vector3(0.5, 0.03, 0.22), SODIUM)
	_light(c, r.at(side, reach, 7.5), 20.0, 4.0)
	_halo(c, r.at(side, reach, 7.8), 6.0)


func _light(c: Chunk, at: Vector3, reach: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at - c.node.position
	light.light_color = SODIUM
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false  # omni shadows cost a lot in WebGL2; only the phone light casts shadows
	c.node.add_child(light)


func _halo(c: Chunk, at: Vector3, size: float) -> void:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	halo.mesh = quad
	halo.material_override = _mats[&"halo"]
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.visibility_range_end = VIEW
	halo.position = at - c.node.position
	c.node.add_child(halo)


# --- the tunnel, the resort and the bus stop ------------------------------------------------------

## The two portals' faces, the hill the tunnel goes through, and its two lights (the lamps along its vault are built
## with the lining, row by row).
func _build_tunnel() -> void:
	for end: Array in [[RoadLayout.TUNNEL.x, 1.0], [RoadLayout.TUNNEL.y, -1.0]]:  # [s, 1: its face looks up the road]
		var r := _row(end[0])
		var c := _chunk_at(end[0] + end[1] * STEP)  # with the lining it frames
		var n: Vector3 = r.basis().z * end[1]
		for side: float in [1.0, -1.0]:
			for j in LINING.size() - 1:
				var p0: Vector2 = LINING[j]
				var p1: Vector2 = LINING[j + 1]
				var o0 := _portal_edge(p0)
				var o1 := _portal_edge(p1)
				_poly(c, &"ground", [r.at(side, p0.x, p0.y), r.at(side, p1.x, p1.y), r.at(side, o1.x, o1.y), r.at(side, o0.x, o0.y)], n, CONCRETE)
		_box(c, &"ground", Transform3D(r.basis(), r.at(1.0, 0.0, 9.7) - n * 0.3), Vector3(18.6, 0.4, 0.6), CONCRETE * 0.9)
	var mid := (RoadLayout.TUNNEL.x + RoadLayout.TUNNEL.y) * 0.5
	var length := RoadLayout.TUNNEL.y - RoadLayout.TUNNEL.x
	var xf := Transform3D(Basis.looking_at(RoadLayout.tangent(mid)), RoadLayout.point(mid))  # it slopes with the road
	var c := _chunk_at(mid)
	for block: Array in [[Vector3(-27.0, 2.5, 0.0), Vector3(36.0, 55.0, length)], [Vector3(27.0, 2.5, 0.0), Vector3(36.0, 55.0, length)], [Vector3(0.0, 19.75, 0.0), Vector3(18.0, 20.5, length)]]:
		_box(c, &"ground", Transform3D(xf.basis, xf * (block[0] as Vector3)), block[1], EARTH)
	var s := RoadLayout.TUNNEL.x + 3.0
	while s <= RoadLayout.TUNNEL.y - 3.0:  # a light strip every 6 m on both sides, none out past a mouth
		var r := _row(s)
		for side: float in [1.0, -1.0]:
			_box(_chunk_at(s), &"sodium", Transform3D(r.basis(), r.at(side, STRIP.x, STRIP.y)), Vector3(0.16, 0.05, 1.2), SODIUM)
		s += 6.0
	# The top portal's lamp hangs 2 m in front of its face, which a light inside could not reach; the other lights
	# the rest of the tube, from 35 m inside the bottom mouth.
	for at: Vector2 in [Vector2(RoadLayout.TUNNEL.x - 2.0, 26.0), Vector2(RoadLayout.TUNNEL.y - 35.0, 32.0)]:  # [s, range]
		_light(_chunk_at(at.x), RoadLayout.point(at.x) + Vector3.UP * 5.5, at.y, 2.5)
	var top := _row(RoadLayout.TUNNEL.x)
	_box(_chunk_at(RoadLayout.TUNNEL.x + STEP), &"sodium", Transform3D(top.basis(), top.at(1.0, 0.0, 7.0) - top.fwd * 0.1), Vector3(0.6, 0.12, 0.2), SODIUM)


## Where the portal's face meets a point of the lining: straight out to its side for the kerb and the wall's foot,
## its top corner for the wall's top, straight up to its top for the vault.
static func _portal_edge(p: Vector2) -> Vector2:
	if p.y < 1.0:
		return Vector2(9.0, p.y)
	return Vector2(9.0, 9.5) if p.x > 5.0 else Vector2(p.x, 9.5)


## The back of the resort along the left of the top of the road, in level steps down it, with a few lit windows; the
## staff exit in it, with its door, its lamp and its bin; the shut service gate; and the resort's glow in the fog.
func _build_resort() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1207
	var s := RoadLayout.START_S
	while s < RESORT_END - 1.0:
		var s1 := minf(s + 30.0, RESORT_END)
		var r := _row((s + s1) * 0.5)
		var c := _chunk_at(r.s)
		var low := RoadLayout.point(s1).y - 1.0 - r.p.y
		var high := RoadLayout.point(s).y + 15.0 - r.p.y
		_box(c, &"ground", Transform3D(r.basis(), r.at(1.0, 7.0, (low + high) * 0.5)), Vector3(1.0, high - low, s1 - s), Color(0.42, 0.41, 0.38))
		var along := s + 2.5
		while along < s1 - 2.0:
			var w := _row(along)
			for up: float in [5.0, 8.0, 11.0]:
				var lit := rng.randf() < 0.22
				var at := w.at(1.0, 6.48 if lit else 6.49, up + (RoadLayout.point(s).y - w.p.y))
				var x := w.fwd * 0.6
				var y := Vector3.UP * 0.5
				_poly(c, &"windows" if lit else &"ground", [at - x - y, at + x - y, at + x + y, at - x + y], -w.left, Color(1, 1, 1) if lit else Color(0.08, 0.09, 0.1))
			along += 4.0
		s = s1
	var exit_s := RoadLayout.closest_s(RoadLayout.EXIT)
	var r := _row(exit_s)
	var c := _chunk_at(exit_s)
	var basis := r.basis()
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 6.47, 1.1)), Vector3(0.06, 2.3, 2.0), Color(0.12, 0.12, 0.13))  # the frame
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 6.43, 1.06)), Vector3(0.04, 2.1, 1.8), Color(0.3, 0.36, 0.4))  # the door
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 6.0, 2.62)), Vector3(1.0, 0.12, 2.8), CONCRETE)  # its canopy
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 6.0, 0.01)), Vector3(0.95, 0.1, 12.0), CONCRETE)  # a slab over the drain
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 6.42, 2.38)), Vector3(0.1, 0.18, 0.34), STEEL * 0.5)
	_box(c, &"sodium", Transform3D(basis, r.at(1.0, 6.36, 2.36)), Vector3(0.02, 0.12, 0.26), SODIUM)
	_light(c, r.at(1.0, 6.1, 2.3), 11.0, 1.4)
	_halo(c, r.at(1.0, 6.3, 2.36), 1.6)
	var bin := _row(exit_s + 3.2)
	_box(c, &"ground", Transform3D(basis, bin.at(1.0, 6.05, 0.55)), Vector3(0.78, 1.1, 1.26), Color(0.07, 0.19, 0.1))
	_box(c, &"ground", Transform3D(basis, bin.at(1.0, 6.05, 1.13)), Vector3(0.84, 0.06, 1.32), Color(0.05, 0.14, 0.07))
	var gate := _row(GATE_S)
	var g := _chunk_at(GATE_S)
	_box(g, &"ground", Transform3D(gate.basis(), gate.at(1.0, 0.0, 1.5)), Vector3(24.0, 3.0, 0.3), Color(0.38, 0.37, 0.35))
	_box(g, &"ground", Transform3D(gate.basis(), gate.at(1.0, 0.0, 1.25)), Vector3(7.6, 2.3, 0.4), Color(0.1, 0.11, 0.12))
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(90.0, 55.0)
	glow.mesh = quad
	glow.material_override = _mats[&"resort_glow"]
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = RoadLayout.point(-90.0, 14.0) + Vector3.UP * 24.0
	add_child(glow)


## KL's glow in the clouds far below: a low, wide sodium haze kept down the valley (see _process). Nearer things
## hide it; a thicker fog fades it out (set_fog).
func _build_city() -> void:
	var drop := RoadLayout.point(_rows[-1].s) - RoadLayout.point(RoadLayout.START_S)
	city_dir = Vector3(drop.x, 0.0, drop.z).normalized()
	_city = MeshInstance3D.new()
	_city.name = "City"
	var quad := QuadMesh.new()
	quad.size = Vector2(260.0, 30.0)
	_city.mesh = quad
	_city.material_override = _mats[&"city"]
	_city.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_city)


## The light far down the road (Mission 4): a warm haze, as a bare bulb makes in the fog. It ignores the fog, which
## would hide it at that distance, and draws inside the camera's far plane (see _process).
func _build_far_light() -> void:
	far_light = MeshInstance3D.new()
	far_light.name = "FarLight"
	var quad := QuadMesh.new()
	quad.size = Vector2(LIGHT_SIZE, LIGHT_SIZE)
	far_light.mesh = quad
	far_light.material_override = _mats[&"far_light"]
	far_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_light.visible = false
	add_child(far_light)


## The bus stop on the left verge: a metal roof on two posts at the back, a concrete bench under it, and the timetable
## plate. A slab covers the drain there.
func _build_stop() -> void:
	var s := RoadLayout.BUS_STOP_S
	var r := _row(s)
	var c := _chunk_at(s)
	var basis := r.basis()
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 5.45, 2.55)), Vector3(2.3, 0.06, 4.4), STEEL)
	for along: float in [-1.9, 1.9]:
		_box(c, &"ground", Transform3D(basis, r.at(1.0, 6.45, 1.275) + r.fwd * along), Vector3(0.1, 2.55, 0.1), STEEL * 0.8)
		_box(c, &"ground", Transform3D(basis, r.at(1.0, 5.85, 0.21) + r.fwd * along * 0.7), Vector3(0.4, 0.42, 0.15), CONCRETE)
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 6.5, 1.15)), Vector3(0.04, 1.7, 4.0), STEEL * 0.6)
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 5.85, 0.46)), Vector3(0.45, 0.08, 3.2), CONCRETE)
	_box(c, &"ground", Transform3D(basis, r.at(1.0, 5.9, 0.01)), Vector3(0.7, 0.1, 8.0), CONCRETE)
	var at := r.at(1.0, 6.47, 1.5) + r.fwd * 1.2
	var x := r.fwd * 0.2
	var y := Vector3.UP * 0.275
	_poly(c, &"sign_faces", [at - x - y, at + x - y, at + x + y, at - x + y], -r.left, Color.WHITE, [Vector2(0.75, 0.75), Vector2(1.0, 0.75), Vector2(1.0, 0.0), Vector2(0.75, 0.0)])


# --- building blocks ----------------------------------------------------------------------------

func _chunk_at(s: float) -> Chunk:
	return _chunks[clampi(int((s - RoadLayout.START_S) / (STEP * CHUNK_ROWS)), 0, _chunks.size() - 1)]


func _tool(c: Chunk, kind: StringName) -> SurfaceTool:
	if not c.tools.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		c.tools[kind] = st
	return c.tools[kind]


## One convex polygon, in world space, facing n, into chunk c's mesh of `kind`: Decor._poly, moved into the chunk.
## normals: per point, for smooth shading.
func _poly(c: Chunk, kind: StringName, p: Array, n: Vector3, color: Color, uv: Array = [], normals: Array = []) -> void:
	var o := c.node.position
	Decor._poly(_tool(c, kind), p.map(func(q: Vector3) -> Vector3: return q - o), n, color, uv, normals)


## The cross-section points j0 to j1 of pa (at row a) and pb (at row b) on `side`, as a strip along the road, smooth
## across it. Its front faces the left of the way the points run (up, from the road outwards); `back` turns it round.
func _strip(c: Chunk, kind: StringName, a: Row, b: Row, side: float, pa: PackedVector2Array, pb: PackedVector2Array, j0: int, j1: int, color: Color, back := false) -> void:
	for j in range(j0, j1):
		var p := [a.at(side, pa[j].x, pa[j].y), a.at(side, pa[j + 1].x, pa[j + 1].y), b.at(side, pb[j + 1].x, pb[j + 1].y), b.at(side, pb[j].x, pb[j].y)]
		var n := [_across(a, side, pa, j, j0, j1, back), _across(a, side, pa, j + 1, j0, j1, back), _across(b, side, pb, j + 1, j0, j1, back), _across(b, side, pb, j, j0, j1, back)]
		_poly(c, kind, p, n[0] + n[1] + n[2] + n[3], color, [], n)


## The normal at point j of a cross-section: square to it, on the left of the way it runs.
func _across(r: Row, side: float, profile: PackedVector2Array, j: int, j0: int, j1: int, back: bool) -> Vector3:
	var d := profile[mini(j + 1, j1)] - profile[maxi(j - 1, j0)]
	var n := (r.left * (side * -d.y) + Vector3.UP * d.x).normalized()
	if n == Vector3.ZERO:
		n = Vector3.UP
	return -n if back else n


## A box: the basis gives its axes (x across, y up, z along the road), size its extents, centred on the origin.
func _box(c: Chunk, kind: StringName, xf: Transform3D, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		var n: Vector3 = axes[i]
		var du: Vector3 = axes[(i + 1) % 3] * h
		var dv: Vector3 = axes[(i + 2) % 3] * h
		for sgn: float in [-1.0, 1.0]:
			var mid := n * h * sgn
			var pts := [mid - du - dv, mid + du - dv, mid + du + dv, mid - du + dv].map(func(q: Vector3) -> Vector3: return xf * q)
			_poly(c, kind, pts, (xf.basis * (n * sgn)).normalized(), color)


## A sign post from xf's origin up `height`, banded black and white every 0.3 m.
func _post(c: Chunk, xf: Transform3D, height: float) -> void:
	var z := 0.0
	var k := 0
	while z < height - 0.01:
		var band := minf(0.3, height - z)
		_box(c, &"signs", Transform3D(xf.basis, xf.origin + Vector3.UP * (z + band * 0.5)), Vector3(0.07, band, 0.07), POST_BANDS[k % 2])
		z += band
		k += 1
	var x := xf.basis.x * 0.05
	var y := Vector3.UP * height
	var z_ := xf.basis.z * 0.05
	var corners := [xf.origin + x + z_, xf.origin + x - z_, xf.origin - x - z_, xf.origin - x + z_]
	for j in 4:  # he walks into a post, not through it
		var a: Vector3 = corners[j]
		var b: Vector3 = corners[(j + 1) % 4]
		_face(c, [a, b, b + y, a + y])


## Two triangles of the walking colliders.
func _face(c: Chunk, p: Array) -> void:
	for k: int in [0, 1, 2, 0, 2, 3]:
		c.faces.append(p[k] - c.node.position)


func _commit(c: Chunk) -> void:
	for kind: StringName in c.tools:
		var mesh := MeshInstance3D.new()
		mesh.name = String(kind).to_pascal_case()
		mesh.mesh = (c.tools[kind] as SurfaceTool).commit()
		mesh.material_override = _mats[kind]
		mesh.visibility_range_end = VIEW
		if kind == &"sodium" or kind == &"windows":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.node.add_child(mesh)
		if kind == &"signs" or kind == &"sign_faces":
			signs.append(mesh)
	for k in 2:
		if c.trees[k].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mats[&"cards"][k]
		mm.instance_count = c.trees[k].size()
		for i in c.trees[k].size():
			mm.set_instance_transform(i, c.trees[k][i])
		var trees := MultiMeshInstance3D.new()
		trees.name = "Trees" if k == 0 else "Ferns"
		trees.multimesh = mm
		trees.material_override = _mats[&"trees"]
		trees.visibility_range_end = VIEW
		c.node.add_child(trees)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(c.faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.add_child(collider)
	c.node.add_child(body)


# --- the look -----------------------------------------------------------------------------------

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = FOG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.13, 0.145, 0.17)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = FOG_COLOR
	environment.fog_density = FOG_CLEAR
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	_apply_brightness()
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _apply_brightness() -> void:
	environment.tonemap_exposure = float(Settings.get_value("brightness"))


func _add_material(kind: StringName, m: Material) -> void:
	_mats[kind] = m
	_materials.append(m)


func _build_materials() -> void:
	var road := StandardMaterial3D.new()
	road.albedo_texture = _asphalt_texture()
	road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	road.roughness = 0.62  # damp
	_add_material(&"road", road)
	var ground := StandardMaterial3D.new()  # everything vertex-coloured: verges, concrete, earth, steel, walls, boards
	ground.vertex_color_use_as_albedo = true
	ground.vertex_color_is_srgb = true  # the colours here are picked like albedo colours
	ground.albedo_texture = _grain_texture()
	ground.uv1_triplanar = true
	ground.uv1_world_triplanar = true
	ground.uv1_scale = Vector3.ONE * 0.5
	ground.roughness = 0.9
	_add_material(&"ground", ground)
	_mats[&"signs"] = ground
	_add_material(&"sodium", _glow(SODIUM, 4.0))
	_add_material(&"windows", _glow(Color(0.9, 0.62, 0.34), 0.45))
	var faces := StandardMaterial3D.new()
	faces.albedo_texture = _sign_texture()
	faces.roughness = 0.5
	faces.emission_enabled = true  # a stand-in for retroreflective sheeting, so the chevrons show in the headlights
	faces.emission_texture = faces.albedo_texture
	faces.emission_energy_multiplier = 0.35
	_add_material(&"sign_faces", faces)
	var trees := StandardMaterial3D.new()
	trees.albedo_texture = _tree_texture()
	trees.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	trees.alpha_scissor_threshold = 0.4
	trees.cull_mode = BaseMaterial3D.CULL_DISABLED
	trees.roughness = 1.0
	_add_material(&"trees", trees)
	_mats[&"cards"] = [_card_mesh(0), _card_mesh(1)]
	_add_material(&"halo", _haze(Color(SODIUM, 0.7), 25.0, 110.0))
	_add_material(&"resort_glow", _haze(Color(1.0, 0.72, 0.45, 0.35), 60.0, 125.0))
	var city := _haze(Color(1.0, 0.55, 0.22, CITY_ALPHA), 0.0, 0.0)
	city.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED  # it is always CITY_AWAY off
	_add_material(&"city", city)
	_add_material(&"far_light", _haze(Color(1.0, 0.78, 0.5, LIGHT_ALPHA), 40.0, 10.0))  # gone close to its bulb


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Light in the fog, which the renderer's fog cannot make: a soft additive disc that always faces the camera, at full
## strength up to `full` metres and gone by `gone` (it ignores the fog, so it fades by distance instead).
func _haze(color: Color, full: float, gone: float) -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.15, Color(1, 1, 1, 0.35))
	gradient.add_point(0.5, Color(1, 1, 1, 0.08))
	var disc := GradientTexture2D.new()
	disc.gradient = gradient
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1.0, 0.5)
	disc.width = 64
	disc.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = disc
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_fog = true
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_max_distance = full  # less than min: it fades out with distance, not in
	m.distance_fade_min_distance = gone
	return m


# --- textures, drawn in code --------------------------------------------------------------------

## DASH_PERIOD metres of asphalt, 256 px square: dark grain, both edge lines and one centre dash, worn. u runs across
## the road from -EDGE to EDGE.
func _asphalt_texture() -> ImageTexture:
	var size := 256
	var noise := FastNoiseLite.new()
	noise.seed = 1147
	noise.frequency = 0.09
	var grain := noise.get_seamless_image(size, size)
	grain.convert(Image.FORMAT_L8)
	var g := grain.get_data()
	var px := PackedByteArray()
	px.resize(size * size * 3)
	for y in size:
		var along := (y + 0.5) / size * DASH_PERIOD
		for x in size:
			var across := ((x + 0.5) / size * 2.0 - 1.0) * EDGE
			var v := g[y * size + x] / 255.0
			var tone := 0.26 + 0.14 * v  # sRGB bytes below: dark, worn asphalt
			if absf(absf(across) - 3.525) < 0.075 or (absf(across) < 0.06 and along < DASH):
				tone = lerpf(tone, 0.82, 0.45 + 0.5 * v)  # paint, worn where the grain is dark
			var b := int(tone * 255.0)
			px[(y * size + x) * 3] = b
			px[(y * size + x) * 3 + 1] = b
			px[(y * size + x) * 3 + 2] = mini(255, b + 3)
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGB8, px)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A faint mottle for everything vertex-coloured, 128 px, as ApartmentBuilder._plaster draws its own.
func _grain_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 1207
	noise.frequency = 0.06
	var img := noise.get_seamless_image(128, 128)
	img.convert(Image.FORMAT_L8)
	var px := img.get_data()
	for i in px.size():
		px[i] = 175 + px[i] * 80 / 255  # 69-100 %: weathered, not clean
	img = Image.create_from_data(128, 128, false, Image.FORMAT_L8, px)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The printed faces, 256 x 128: a chevron board (x 0-63, y 0-79: black on yellow, pointing right), the winding-road
## diamond (x 64-191) and the bus stop's timetable plate (x 192-255, y 0-95: lines too small to read).
func _sign_texture() -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGB8)
	var yellow := Color(0.96, 0.72, 0.06)
	var black := Color(0.04, 0.04, 0.04)
	img.fill(Color(0.5, 0.5, 0.5))
	img.fill_rect(Rect2i(0, 0, 64, 80), black)
	img.fill_rect(Rect2i(3, 3, 58, 74), yellow)
	for y in 80:
		for x in 64:
			if absf(x - 50.0 + 1.5 * absf(y - 40.0)) < 7.0 and absf(y - 40.0) < 30.0:
				img.set_pixel(x, y, black)
	for y in 128:
		for x in 128:
			var d := absf(x - 63.5) + absf(y - 63.5)
			if d < 62.0:
				img.set_pixel(64 + x, y, black if d > 56.0 else yellow)
	for y in range(34, 92):  # the winding road: a thick S under an arrowhead
		var cx := 63.5 + 11.0 * sin((91.0 - y) / 58.0 * TAU * 0.8)
		for x in range(int(cx) - 5, int(cx) + 6):
			img.set_pixel(64 + x, y, black)
	for y in range(24, 40):
		var half := (y - 24) * 0.8
		var cx := 63.5 + 11.0 * sin(57.0 / 58.0 * TAU * 0.8)
		for x in range(int(cx - half), int(cx + half) + 1):
			img.set_pixel(64 + x, y, black)
	img.fill_rect(Rect2i(192, 0, 64, 96), Color(0.9, 0.9, 0.88))
	img.fill_rect(Rect2i(192, 0, 64, 14), Color(0.1, 0.25, 0.55))
	for y in range(20, 92, 6):
		img.fill_rect(Rect2i(198, y, 22 + (y * 7) % 30, 2), Color(0.35, 0.35, 0.35))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Two tree cards, 256 x 256 each, side by side: a broadleaf crown on its trunk (sunk in the ground it is a bush) and
## a tree fern, the highland roadside's own. The leaves are lumps cut ragged by noise, darker lower down.
func _tree_texture() -> ImageTexture:
	var w := 512
	var h := 256
	var noise := FastNoiseLite.new()
	noise.seed = 1147
	noise.frequency = 0.07
	var leaf_img := noise.get_image(w, h)
	leaf_img.convert(Image.FORMAT_L8)
	var leaf := leaf_img.get_data()
	var shape := PackedFloat32Array()
	shape.resize(w * h)
	shape.fill(-1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 16:  # the crown
		var rx := rng.randf_range(30.0, 54.0)
		_lump(shape, w, rng.randf_range(54.0, 202.0), rng.randf_range(30.0, 140.0), rx, rx * rng.randf_range(0.6, 0.85))
	var fern := Vector2(384.0, 116.0)
	for k in 11:  # the fern's fronds: drooping arcs, each leaflet a short stroke
		var angle := deg_to_rad(lerpf(-172.0, -8.0, k / 10.0) + rng.randf_range(-6.0, 6.0))
		var length := rng.randf_range(88.0, 120.0)
		var dir := Vector2(cos(angle), sin(angle))
		for i in 60:
			var u := i / 59.0
			var at := fern + dir * length * u + Vector2(0.0, 0.75 * length * u * u)
			_lump(shape, w, at.x, at.y, 2.2, 2.2)
			if i % 3 == 0:
				var tangent := (dir + Vector2(0.0, 1.5 * u)).normalized()
				for sgn: float in [-1.0, 1.0]:
					var leaflet := tangent.orthogonal() * sgn * (13.0 * (1.0 - u) + 3.0) + tangent * 3.0
					for q in 6:
						var p := at + leaflet * (q / 5.0)
						_lump(shape, w, p.x, p.y, 1.6, 1.6)
	var px := PackedByteArray()
	px.resize(w * h * 4)
	for y in h:
		var darker := 1.15 - 0.55 * y / h
		for x in w:
			var i := y * w + x
			var v := leaf[i] / 255.0
			var tone := (0.55 + 0.9 * v) * darker
			var green := Vector3(0.1, 0.16, 0.08) if x < 256 else Vector3(0.12, 0.19, 0.09)
			px[i * 4] = mini(255, int(green.x * tone * 255.0))
			px[i * 4 + 1] = mini(255, int(green.y * tone * 255.0))
			px[i * 4 + 2] = mini(255, int(green.z * tone * 255.0))
			px[i * 4 + 3] = 255 if shape[i] + (v - 0.5) * (0.9 if x < 256 else 0.2) > 0.0 else 0
	for y in range(118, h):  # the trunks, over the leaves
		for x in range(-6, 7):
			var tree_x := 128 + x
			var fern_x := 384 + x + int(3.0 * sin(y * 0.03))
			if absf(x) <= 3.0 + (y - 118) * 0.02:
				for at: int in [tree_x, fern_x]:
					var i := y * w + at
					if at >= 256 or absf(x) <= 3.0:
						px[i * 4] = 30
						px[i * 4 + 1] = 26
						px[i * 4 + 2] = 22
						px[i * 4 + 3] = 255
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Raises `shape` towards 1 inside an ellipse.
static func _lump(shape: PackedFloat32Array, w: int, cx: float, cy: float, rx: float, ry: float) -> void:
	var h := shape.size() / w
	for y in range(maxi(0, int(cy - ry)), mini(h, int(cy + ry) + 1)):
		for x in range(maxi(0, int(cx - rx)), mini(w, int(cx + rx) + 1)):
			var f := 1.0 - pow((x - cx) / rx, 2.0) - pow((y - cy) / ry, 2.0)
			if f > shape[y * w + x]:
				shape[y * w + x] = f


## Two quads crossing at right angles, 1 m wide and 1 m tall, standing on the origin, showing card k of the trees.
static func _card_mesh(k: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := k * 0.5
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var n := axis.cross(Vector3.UP)
		var p := [-axis * 0.5, axis * 0.5, axis * 0.5 + Vector3.UP, -axis * 0.5 + Vector3.UP]
		var uv := [Vector2(u0, 1.0), Vector2(u0 + 0.5, 1.0), Vector2(u0 + 0.5, 0.0), Vector2(u0, 0.0)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uv[i])
			st.add_vertex(p[i])
	return st.commit()

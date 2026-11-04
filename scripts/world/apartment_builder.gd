class_name ApartmentBuilder
extends Node3D
## Builds the condo from ApartmentLayout: rooms, walls, doors, lights and the furniture that matters to play.
## Anything tied to a variant is shown, and collides, only while that variant is active. Trim, fittings and
## small things are Decor's.

const WALL := Color(0.83, 0.81, 0.75)
const WALL_GAP := Color(0.5, 0.49, 0.46)  # bare concrete: the gap was never meant to be finished
const WALL_MIRROR := Color(0.6, 0.58, 0.53)  # B-11-07: the same paint, years of nobody
const CEILING_COLOR := Color(0.9, 0.9, 0.88)

# Props: [center, size, color, requires]. Collide unless the size is tiny or the entry says otherwise.
const PROPS := [
	# Living room
	[Vector3(6.5, 0.22, 9.5), Vector3(2.2, 0.44, 0.75), Color(0.3, 0.33, 0.38)],
	[Vector3(6.5, 0.6, 9.8), Vector3(2.2, 0.75, 0.22), Color(0.28, 0.31, 0.36)],
	[Vector3(5.3, 0.35, 9.5), Vector3(0.2, 0.7, 0.85), Color(0.27, 0.3, 0.35)],
	[Vector3(7.7, 0.35, 9.5), Vector3(0.2, 0.7, 0.85), Color(0.27, 0.3, 0.35)],
	[Vector3(6.5, 0.2, 7.3), Vector3(1.1, 0.4, 0.6), Color(0.45, 0.32, 0.22)],
	[Vector3(6.5, 0.25, 4.3), Vector3(2.0, 0.5, 0.45), Color(0.4, 0.29, 0.2)],
	[Vector3(4.5, 0.45, 6.85), Vector3(0.42, 0.06, 0.42), Color(0.45, 0.32, 0.22)],
	[Vector3(4.5, 0.75, 7.05), Vector3(0.42, 0.55, 0.05), Color(0.45, 0.32, 0.22)],
	[Vector3(4.5, 0.45, 5.55), Vector3(0.42, 0.06, 0.42), Color(0.45, 0.32, 0.22), {&"living_chair": &"default"}],
	[Vector3(4.5, 0.75, 5.35), Vector3(0.42, 0.55, 0.05), Color(0.45, 0.32, 0.22), {&"living_chair": &"default"}],
	[Vector3(3.45, 0.45, 5.2), Vector3(0.42, 0.06, 0.42), Color(0.45, 0.32, 0.22), {&"living_chair": &"turned"}],
	[Vector3(3.65, 0.75, 5.2), Vector3(0.05, 0.55, 0.42), Color(0.45, 0.32, 0.22), {&"living_chair": &"turned"}],
	[Vector3(6.5, 2.3, 4.14), Vector3(0.95, 0.3, 0.2), Color(0.9, 0.9, 0.88)],  # aircon above the TV
	[Vector3(6.5, 0.005, 7.5), Vector3(2.4, 0.01, 1.6), Color(0.33, 0.14, 0.12)],  # rug
	[Vector3(2.45, 0.015, 9.6), Vector3(0.1, 0.03, 0.26), Color(0.2, 0.3, 0.6)],  # selipar by the door
	[Vector3(2.6, 0.015, 9.62), Vector3(0.1, 0.03, 0.26), Color(0.2, 0.3, 0.6)],
	# Entrance: shoes on the rack, or lined up facing the hallway
	[Vector3(0.22, 0.64, 7.8), Vector3(0.12, 0.08, 0.28), Color(0.1, 0.1, 0.1), {&"entrance_shoes": &"default"}],
	[Vector3(0.36, 0.64, 7.8), Vector3(0.12, 0.08, 0.28), Color(0.1, 0.1, 0.1), {&"entrance_shoes": &"default"}],
	[Vector3(2.3, 0.04, 8.4), Vector3(0.28, 0.08, 0.12), Color(0.1, 0.1, 0.1), {&"entrance_shoes": &"moved"}],
	[Vector3(2.3, 0.04, 8.6), Vector3(0.28, 0.08, 0.12), Color(0.1, 0.1, 0.1), {&"entrance_shoes": &"moved"}],
	# Kitchen
	[Vector3(0.4, 0.9, 2.95), Vector3(0.7, 1.8, 0.7), Color(0.85, 0.86, 0.86)],
	[Vector3(0.35, 0.45, 4.9), Vector3(0.6, 0.9, 3.0), Color(0.6, 0.55, 0.48)],
	[Vector3(0.22, 2.0, 4.9), Vector3(0.35, 0.7, 3.0), Color(0.62, 0.57, 0.5)],
	[Vector3(0.35, 0.92, 5.6), Vector3(0.5, 0.04, 0.5), Color(0.12, 0.12, 0.12)],
	# Bathroom
	[Vector3(3.6, 1.0, -0.6), Vector3(1.0, 2.0, 0.02), Color(0.7, 0.85, 0.9, 0.25)],
	[Vector3(3.2, 2.0, -1.5), Vector3(0.22, 0.45, 0.3), Color(0.95, 0.95, 0.95)],
	[Vector3(3.22, 0.96, 1.0), Vector3(0.02, 0.1, 0.02), Color(0.6, 0.8, 1.0, 0.6), {&"bathroom_tap": &"running"}],
	# Bedroom
	[Vector3(8.95, 0.25, 0.2), Vector3(1.8, 0.5, 2.0), Color(0.3, 0.21, 0.15)],
	[Vector3(5.85, 1.0, 1.4), Vector3(0.6, 2.0, 1.4), Color(0.5, 0.38, 0.28)],
	[Vector3(6.1, 0.38, -1.25), Vector3(1.0, 0.76, 0.55), Color(0.5, 0.38, 0.28)],
	# Corridor
	[Vector3(-0.95, 0.25, 10.35), Vector3(0.8, 0.5, 0.3), Color(0.35, 0.25, 0.2)],  # shoe racks beside the neighbours' gates
	[Vector3(13.05, 0.25, 10.35), Vector3(0.8, 0.5, 0.3), Color(0.35, 0.25, 0.2)],
	[Vector3(18.96, 1.05, 11.25), Vector3(0.04, 2.1, 1.3), Color(0.6, 0.62, 0.64)],
	# B-11-07: the bedroom, mirrored, dusty
	[Vector3(6.55, 0.25, -16.3), Vector3(1.8, 0.5, 2.0), Color(0.4, 0.38, 0.35), {&"bedroom": &"door"}],
	[Vector3(9.65, 1.0, -15.1), Vector3(0.6, 2.0, 1.4), Color(0.35, 0.28, 0.22), {&"bedroom": &"door"}],
	[Vector3(9.4, 0.38, -17.75), Vector3(1.0, 0.76, 0.55), Color(0.35, 0.28, 0.22), {&"bedroom": &"door"}],
]

# Interactables: id, pos, size, prompt, title, text, requires. Story-driven objects have no text.
const OBJECTS := [
	[&"intercom", Vector3(0.1, 1.45, 8.6), Vector3(0.08, 0.26, 0.14), "Use intercom", "", ""],
	[&"complaint_slips", Vector3(1.5, 0.02, 9.55), Vector3(0.34, 0.03, 0.26), "Pick up the notes", "Notes under the door",
		"A stack of folded notes, pushed under your door.\n\n\"Please stop the knocking. — 11-07\"\n\nAll the same handwriting. The oldest is dated two years before you moved in."],
	[&"notice_fridge", Vector3(0.77, 1.35, 2.95), Vector3(0.02, 0.3, 0.22), "Read the notice", "Management notice",
		"NOTIS KEPADA PENDUDUK / NOTICE TO RESIDENTS\n\nUnit B-11-07 has been vacant since March. Please report any noise or unauthorised entry to the guardhouse.\n\n— Pengurusan Residensi Seri Kenanga"],
	[&"bathroom_mirror", Vector3(3.09, 1.55, 1.0), Vector3(0.03, 0.7, 0.55), "Look in the mirror", "Mirror",
		"Three lines drawn through the steam on the mirror.\n\nYou haven't showered yet. The steam is still warm."],
	[&"bedroom_wall", Vector3(6.6, 1.3, -1.92), Vector3(0.6, 0.6, 0.04), "Touch the wall", "", ""],
	[&"calendar", Vector3(3.09, 1.55, 5.8), Vector3(0.02, 0.45, 0.32), "Look at the calendar", "Calendar",
		"A free calendar from the kedai runcit downstairs. Tonight's date is circled in red pen.\n\nYou don't own a red pen."],
	[&"photo", Vector3(7.5, 1.6, 3.91), Vector3(0.4, 0.3, 0.02), "Look at the photo", "Photo",
		"You, on the day you got the keys, grinning in front of the block.\n\nBehind you, one window on the eleventh floor is lit."],
	[&"tv", Vector3(6.5, 0.95, 4.57), Vector3(1.4, 0.8, 0.06), "Look at the TV", "TV",
		"Off. In the black glass you can see the room behind you."],
	[&"shoe_rack", Vector3(0.25, 0.3, 8.0), Vector3(0.4, 0.6, 1.0), "Look at the shoe rack", "Shoe rack",
		"Your work shoes. The soles are still slick with oil from the mamak floor.", {&"entrance_shoes": &"default"}],
	# Things that have moved (StoryDirector: noticing one puts it back)
	[&"shoes_moved", Vector3(2.3, 0.06, 8.5), Vector3(0.4, 0.12, 0.45), "Look at the shoes", "", "", {&"entrance_shoes": &"moved"}],
	[&"chair_turned", Vector3(3.5, 0.6, 5.2), Vector3(0.5, 0.6, 0.5), "Look at the chair", "", "", {&"living_chair": &"turned"}],
	[&"tap", Vector3(3.22, 1.0, 1.0), Vector3(0.18, 0.2, 0.25), "Turn off the tap", "", "", {&"bathroom_tap": &"running"}],
	# Going to bed (act 1)
	[&"sink", Vector3(3.3, 0.95, 1.0), Vector3(0.42, 0.2, 0.5), "Wash your face", "", "", {&"bathroom_tap": &"default"}],
	[&"bed", Vector3(8.95, 0.6, 0.2), Vector3(1.8, 0.2, 2.0), "Lie down", "", ""],
	[&"aircon", Vector3(9.88, 2.3, 0.2), Vector3(0.2, 0.3, 0.9), "Look at the aircon", "Aircon",
		"Switched off at the wall. The little green light is blinking anyway."],
	[&"bedroom_window", Vector3(7.8, 1.5, -1.9), Vector3(1.5, 1.1, 0.04), "Look outside", "Window",
		"Twelve floors down, the mamak where you work is still open. Someone in your apron is pulling teh tarik. They stop, and look up.", {&"bedroom": &"default"}],
	[&"door_1206", Vector3(-2.0, 1.05, 10.1), Vector3(1.0, 2.1, 0.06), "Knock", "B-12-06",
		"You knock. Nobody answers. A red lantern from last Chinese New Year still hangs by the grille."],
	[&"door_1208", Vector3(12.0, 1.05, 10.1), Vector3(1.0, 2.1, 0.06), "Knock", "B-12-08",
		"Dark behind the grille. A delivery slip is taped to it, dated last month."],
	[&"fire_door", Vector3(-3.95, 1.05, 11.25), Vector3(0.06, 2.1, 1.0), "Open the fire door", "Fire exit",
		"It won't open. Someone has tied it shut with raffia string. From the stairwell side."],
	[&"lift_button", Vector3(18.9, 1.2, 12.1), Vector3(0.05, 0.15, 0.1), "Call the lift", "", ""],
	[&"intercom_mirror", Vector3(5.6, 1.45, -14.6), Vector3(0.08, 0.26, 0.14), "Use intercom", "", "", {&"bedroom": &"door"}],
	[&"mirror_wall", Vector3(7.75, 1.3, -18.41), Vector3(1.8, 1.2, 0.03), "Touch the wall", "", "", {&"bedroom": &"door"}],
]

# Label3D: text, pos, yaw (0 faces +z), pixel size, color, requires
const LABELS := [
	["B-12-07", Vector3(1.5, 2.25, 10.09), 0.0, 0.004, Color(0.85, 0.8, 0.6)],
	["B-12-06", Vector3(-2.0, 2.25, 10.09), 0.0, 0.004, Color(0.85, 0.8, 0.6)],
	["B-12-08", Vector3(12.0, 2.25, 10.09), 0.0, 0.004, Color(0.85, 0.8, 0.6)],
	["LIF · LIFT\nDALAM PENYELENGGARAAN\nUNDER MAINTENANCE", Vector3(18.92, 2.0, 11.25), -PI / 2, 0.003, Color(0.9, 0.3, 0.2)],
	["KELUAR · EXIT", Vector3(-3.92, 2.35, 11.25), PI / 2, 0.003, Color(0.2, 0.9, 0.4)],
	["B-11-07", Vector3(7.7, 2.25, -13.91), 0.0, 0.004, Color(0.85, 0.8, 0.6), {&"bedroom": &"door"}],
	["|||  |||  |||  |||  |||  |||\n|||  |||  |||  |||  |||  |||\n|||  |||  |||  |||  |||  |||\n|||  |||  |||  |||  |||", Vector3(7.75, 1.3, -18.4), 0.0, 0.004, Color(0.15, 0.1, 0.1), {&"bedroom": &"door"}],
]

var decor: Decor
var doors: Dictionary = {}  # door_id -> Door
var lights: Dictionary = {}  # room_id -> Array[RoomLight]
var environment: Environment
var _gated: Array = []  # [Node3D, requires]
var _materials: Dictionary = {}
var _fan: Node3D
var _plaster_tex: ImageTexture


func _ready() -> void:
	build()
	EventBus.variant_changed.connect(func(_a: StringName, _v: StringName) -> void: refresh_variants())
	Settings.changed.connect(_apply_brightness)
	refresh_variants()


func build() -> void:
	decor = Decor.new()
	decor.builder = self
	add_child(decor)
	_build_environment()
	for room_id: StringName in ApartmentLayout.ROOMS:
		_build_room_surfaces(room_id)
	for w: Dictionary in ApartmentLayout.WALLS:
		_build_wall(w)
	for door_id: StringName in ApartmentLayout.DOORS:
		_build_door(door_id, ApartmentLayout.DOORS[door_id])
	for room_id: StringName in ApartmentLayout.LIGHTS:
		_build_lights(room_id, ApartmentLayout.LIGHTS[room_id])
	for p: Array in PROPS:
		var node := _box(self, p[0], p[1], p[2], p[1].y > 0.15)  # flat decor (shoes, pillow, stove top) is walk-through
		var requires: Dictionary = p[3] if p.size() > 3 else {}
		gate(node, requires)
		if p[1].y > 0.15 and p[0].y - p[1].y * 0.5 < 0.02:
			decor.foot(p[0], Vector2(p[1].x, p[1].z) * 0.5, 0.5, requires)
	for o: Array in OBJECTS:
		_build_object(o)
	for l: Array in LABELS:
		_build_label(l)
	_build_fan()
	_build_skyline()
	decor.dress()
	decor.finish()


## Shows and enables exactly the nodes whose variant conditions hold.
func refresh_variants() -> void:
	for entry: Array in _gated:
		var node: Node3D = entry[0]
		var on := ApartmentLayout.requires_met(entry[1], WorldState.variants)
		node.visible = on
		_set_collision(node, on)


func _process(delta: float) -> void:
	if _fan:
		_fan.rotate_y(delta * 2.6)


# --- geometry -----------------------------------------------------------------------------------

func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


## Painted plaster: a faint mottle so walls and ceilings aren't flat colour. One shared 128 px texture.
func _plaster(color: Color) -> StandardMaterial3D:
	var key := "plaster/%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	if _plaster_tex == null:
		var noise := FastNoiseLite.new()
		noise.seed = 1207
		noise.frequency = 0.05
		var img := noise.get_seamless_image(128, 128)
		img.convert(Image.FORMAT_L8)
		var px := img.get_data()
		for i in px.size():
			px[i] = 233 + px[i] * 22 / 255  # 91–100 % brightness: paint, not clouds
		img = Image.create_from_data(128, 128, false, Image.FORMAT_L8, px)
		img.generate_mipmaps()
		_plaster_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _plaster_tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.4  # one tile every 2.5 m
	m.roughness = 0.9
	_materials[key] = m
	return m


func _box(parent: Node3D, center: Vector3, size: Vector3, color: Color, collide := true, material: Material = null) -> Node3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = material if material else _material(color)
	if not collide:
		mesh.position = center
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


func gate(node: Node3D, requires: Dictionary) -> void:
	if not requires.is_empty():
		_gated.append([node, requires])


func _set_collision(node: Node, on: bool) -> void:
	if node is CollisionShape3D:
		node.set_deferred(&"disabled", not on)
	for child in node.get_children():
		_set_collision(child, on)


## Tiles with 2 px grout, projected in world space. size: tile width, and height on walls.
func tile_material(base: Color, grout: Color, size := Vector2(0.6, 0.6)) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(base)
	for i in 64:
		for j in [0, 1]:
			img.set_pixel(i, j, grout)
			img.set_pixel(j, i, grout)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / size.x, 1.0 / size.y, 1.0 / size.x)
	m.roughness = 0.35
	return m


func _build_room_surfaces(room_id: StringName) -> void:
	var room: Dictionary = ApartmentLayout.ROOMS[room_id]
	var requires: Dictionary = room.get("requires", {})
	var floor_mat: Material
	match room_id:
		&"gap":
			floor_mat = _plaster(Color(0.42, 0.41, 0.39))  # screed
		&"mirror_room":
			floor_mat = tile_material(Color(0.48, 0.45, 0.4), Color(0.3, 0.28, 0.25))
		&"corridor":
			floor_mat = tile_material(Color(0.55, 0.55, 0.53), Color(0.4, 0.4, 0.4), Vector2(0.3, 0.3))
		&"bathroom":
			floor_mat = tile_material(Color(0.7, 0.76, 0.78), Color(0.5, 0.55, 0.56), Vector2(0.3, 0.3))
		_:
			floor_mat = tile_material(Color(0.82, 0.76, 0.66), Color(0.62, 0.57, 0.5))
	var sets := [[room["rects"], requires]]
	if room.has("long_rects"):
		sets = [[room["rects"], requires.merged({room_id: &"default"})], [room["long_rects"], requires.merged({room_id: &"long"})]]
	for s: Array in sets:
		var holder := Node3D.new()
		holder.name = "%s_surfaces" % room_id
		add_child(holder)
		gate(holder, s[1])
		for r: Rect2 in s[0]:
			var c := r.get_center()
			_box(holder, Vector3(c.x, -0.05, c.y), Vector3(r.size.x + 0.15, 0.1, r.size.y + 0.15), Color.WHITE, true, floor_mat)
			_box(holder, Vector3(c.x, ApartmentLayout.CEILING + 0.05, c.y), Vector3(r.size.x + 0.15, 0.1, r.size.y + 0.15), CEILING_COLOR, true, _plaster(CEILING_COLOR))


func _build_wall(w: Dictionary) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var requires: Dictionary = w.get("requires", {})
	gate(holder, requires)
	var color := WALL
	var max_z: float = w["at"] if w["axis"] == "x" else w["to"]
	if requires.has(&"gap"):
		color = WALL_GAP
	elif requires.get(&"bedroom") == &"door" and max_z <= -14.0:
		color = WALL_MIRROR
	var h := ApartmentLayout.CEILING
	var t := ApartmentLayout.WALL_T
	var axis := Vector3.RIGHT if w["axis"] == "x" else Vector3.BACK
	var a: float = w["from"]
	var b: float = w["to"]
	var openings: Array = w.get("openings", []).duplicate()
	openings.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var pieces: Array = []  # [from, to, bottom, top]
	# Pieces run half a wall past their ends to close the corners. The gap's walls stop a hair short, so
	# their ends hide inside the walls they meet instead of flickering through the bedroom's.
	var ext := t * 0.5 - (0.004 if requires.has(&"gap") else 0.0)
	var cursor := a - ext
	for o: Array in openings:
		pieces.append([cursor, o[0], 0.0, h])
		if o[3] < h:
			pieces.append([o[0], o[1], o[3], h])
		if o[2] > 0.0:
			pieces.append([o[0], o[1], 0.0, o[2]])
		cursor = o[1]
	pieces.append([cursor, b + ext, 0.0, h])
	for p: Array in pieces:
		if p[1] - p[0] < 0.01 or p[3] - p[2] < 0.01:
			continue
		var along: float = (p[0] + p[1]) * 0.5
		var length: float = p[1] - p[0]
		var y: float = (p[2] + p[3]) * 0.5
		var hh: float = p[3] - p[2]
		var center := Vector3(along, y, w["at"]) if w["axis"] == "x" else Vector3(w["at"], y, along)
		var size := Vector3(length, hh, t) if w["axis"] == "x" else Vector3(t, hh, length)
		_box(holder, center, size, color, true, _plaster(color))
		decor.wall_piece(center, size, axis, requires, not requires.has(&"gap"))
		if w.get("parapet", false) and p[3] < h:
			decor.box(Vector3(center.x, p[3] + 0.025, center.z), Vector3(size.x, 0.05, t + 0.08), Color(0.6, 0.59, 0.56))  # coping
	for o: Array in openings:
		var mid: float = (o[0] + o[1]) * 0.5
		var at_floor := Vector3(mid, 0, w["at"]) if w["axis"] == "x" else Vector3(w["at"], 0, mid)
		if o[2] == 0.0 and is_equal_approx(o[3], ApartmentLayout.DOOR_HEIGHT):
			decor.door_frame(at_floor, axis, o[1] - o[0], _frame_color(at_floor), requires)
		if w.get("window", false):
			var y: float = (o[2] + o[3]) * 0.5
			var center := at_floor + Vector3.UP * y
			var size := Vector3(o[1] - o[0], o[3] - o[2], 0.02) if w["axis"] == "x" else Vector3(0.02, o[3] - o[2], o[1] - o[0])
			_box(holder, center, size, Color(0.55, 0.65, 0.75, 0.18))
			var n := Vector3.BACK if w["axis"] == "x" else Vector3.RIGHT
			var inward := n if ApartmentLayout.room_at(center + n * 0.5, requires) != &"" else -n
			decor.window(center, axis, inward, o[1] - o[0], o[3] - o[2], requires)
	if w.get("parapet", false):
		# Invisible barrier above the corridor's half wall.
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(b - a, h - 1.1, t)
		shape.shape = box
		body.position = Vector3((a + b) * 0.5, 1.1 + (h - 1.1) * 0.5, w["at"])
		body.add_child(shape)
		holder.add_child(body)


## The door frame matches its door, a shade darker.
func _frame_color(at_floor: Vector3) -> Color:
	for id: StringName in ApartmentLayout.DOORS:
		var d: Dictionary = ApartmentLayout.DOORS[id]
		if absf(d["hinge"].z - at_floor.z) < 0.01 and absf(d["hinge"].x + d["width"] * 0.5 - at_floor.x) < 0.1:
			return (d["color"] as Color).darkened(0.25)
	return Decor.WOOD


func _build_door(door_id: StringName, data: Dictionary) -> void:
	var door := Door.new()
	door.name = String(door_id)
	door.setup(door_id, data)
	var width: float = data["width"]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.04, ApartmentLayout.DOOR_HEIGHT - 0.03, 0.05)
	shape.shape = box
	shape.position = Vector3(width * 0.5, ApartmentLayout.DOOR_HEIGHT * 0.5, 0)
	door.add_child(shape)
	_box(door, shape.position, box.size, data["color"], false)
	for s: float in [-1.0, 1.0]:  # lever handles on both sides
		_box(door, Vector3(width - 0.1, 1.0, s * 0.045), Vector3(0.06, 0.06, 0.015), Color(0.7, 0.68, 0.6), false)
		_box(door, Vector3(width - 0.15, 1.0, s * 0.07), Vector3(0.12, 0.02, 0.02), Color(0.7, 0.68, 0.6), false)
	if door_id == &"main_door":
		_box(door, Vector3(width * 0.5, 1.55, 0.0), Vector3(0.025, 0.025, 0.07), Color(0.6, 0.55, 0.4), false)  # peephole
	add_child(door)
	doors[door_id] = door
	gate(door, data.get("requires", {}))


func _build_lights(room_id: StringName, data: Dictionary) -> void:
	var list: Array[RoomLight] = []
	var room_requires: Dictionary = ApartmentLayout.ROOMS[room_id].get("requires", {})
	for i in data["pos"].size():
		var pos: Vector3 = data["pos"][i]
		var holder := Node3D.new()
		add_child(holder)
		gate(holder, _light_requires(room_id, pos, room_requires))
		var fixture := _fixture(room_id, pos, holder)
		fixture.material_override = _material(data["color"], 2.0).duplicate()
		var light := RoomLight.new()
		light.position = pos
		light.light_color = data["color"]
		light.omni_range = data["range"]
		light.omni_attenuation = 2.0  # pools of light; corners fall into shadow
		light.shadow_enabled = false  # omni shadows artifact and cost a lot in WebGL2; the phone light casts shadows
		light.setup(room_id, data["energy"], fixture)
		holder.add_child(light)
		list.append(light)
	lights[room_id] = list
	if data["switch"] != null:
		var sw := Interactable.new()
		sw.object_id = StringName("switch_%s" % room_id)
		sw.light_room = room_id
		sw.position = data["switch"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.1, 0.12, 0.1)
		shape.shape = box
		sw.add_child(shape)
		var room := ApartmentLayout.room_at(sw.position, {})
		var thin_x := ApartmentLayout.room_at(sw.position + Vector3(0.1, 0, 0), {}) != room or ApartmentLayout.room_at(sw.position - Vector3(0.1, 0, 0), {}) != room
		_box(sw, Vector3.ZERO, Vector3(0.012, 0.086, 0.086) if thin_x else Vector3(0.086, 0.086, 0.012), Color(0.9, 0.89, 0.85), false)
		add_child(sw)


## The lamp you can see. It is what lights a room here: a fluorescent tube in the kitchen, bathroom and
## corridor, downlights in the entrance and hallway, a light under the living room fan, a ceiling dome in
## the bedroom, caged bulkheads in the gap, and a bare bulb on a flex in B-11-07. Returns the glowing part.
func _fixture(room_id: StringName, pos: Vector3, holder: Node3D) -> MeshInstance3D:
	var top := ApartmentLayout.CEILING
	var white := Color(0.9, 0.9, 0.88)
	var glow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 20
	match room_id:
		&"kitchen", &"bathroom", &"corridor":
			var along_x := room_id == &"corridor"
			var length := 0.6 if room_id == &"bathroom" else 1.2
			_box(holder, Vector3(pos.x, top - 0.02, pos.z), Vector3(length + 0.04, 0.04, 0.08) if along_x else Vector3(0.08, 0.04, length + 0.04), white, false)
			var tube := BoxMesh.new()
			tube.size = Vector3(length, 0.03, 0.03) if along_x else Vector3(0.03, 0.03, length)
			glow.mesh = tube
			glow.position = Vector3(pos.x, top - 0.055, pos.z)
		&"living":
			cyl.top_radius = 0.09
			cyl.bottom_radius = 0.15
			cyl.height = 0.08
			glow.mesh = cyl
			glow.position = Vector3(pos.x, 2.4, pos.z)
		&"bedroom":
			cyl.top_radius = 0.2
			cyl.bottom_radius = 0.18
			cyl.height = 0.06
			glow.mesh = cyl
			glow.position = Vector3(pos.x, top - 0.03, pos.z)
		&"gap":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.06, 0.22)
			glow.mesh = bm
			glow.position = Vector3(pos.x, top - 0.25, pos.z)
			for dz: float in [-0.06, 0.06]:
				_box(holder, glow.position + Vector3(0, -0.035, dz), Vector3(0.14, 0.012, 0.012), Color(0.15, 0.15, 0.15), false)
			_box(holder, glow.position + Vector3(0, 0.035, 0), Vector3(0.15, 0.02, 0.25), Color(0.3, 0.3, 0.3), false)
		&"mirror_room":
			var bulb := SphereMesh.new()
			bulb.radius = 0.04
			bulb.height = 0.1
			glow.mesh = bulb
			glow.position = pos
			_box(holder, Vector3(pos.x, (top + pos.y) * 0.5 + 0.025, pos.z), Vector3(0.008, top - pos.y - 0.05, 0.008), Color(0.12, 0.12, 0.12), false)
		_:  # recessed downlight
			cyl.top_radius = 0.075
			cyl.bottom_radius = 0.075
			cyl.height = 0.01
			glow.mesh = cyl
			glow.position = Vector3(pos.x, top - 0.004, pos.z)
			_box(holder, glow.position + Vector3.UP * 0.001, Vector3(0.18, 0.006, 0.18), white, false)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(glow)
	return glow


## A light in a room with variant rects exists only in the variants whose rects contain it.
func _light_requires(room_id: StringName, pos: Vector3, room_requires: Dictionary) -> Dictionary:
	var room: Dictionary = ApartmentLayout.ROOMS[room_id]
	if not room.has("long_rects"):
		return room_requires
	var in_default := ApartmentLayout.room_at(pos, room_requires.merged({room_id: &"default"})) == room_id
	var in_long := ApartmentLayout.room_at(pos, room_requires.merged({room_id: &"long"})) == room_id
	if in_default and in_long:
		return room_requires
	return room_requires.merged({room_id: &"default" if in_default else &"long"})


func _build_object(o: Array) -> void:
	var it := Interactable.new()
	it.object_id = o[0]
	it.position = o[1]
	it.prompt = o[3]
	it.title = o[4]
	it.text = o[5]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = o[2]
	shape.shape = box
	it.add_child(shape)
	var color := Color(0.25, 0.25, 0.27)
	match o[0]:
		&"complaint_slips", &"notice_fridge", &"calendar":
			color = Color(0.92, 0.9, 0.82)
		&"photo":
			color = Color(0.5, 0.45, 0.35)
		&"bathroom_mirror":
			color = Color(0.7, 0.78, 0.82)
		&"door_1206", &"door_1208", &"fire_door":
			color = Color(0.35, 0.25, 0.18) if o[0] != &"fire_door" else Color(0.55, 0.15, 0.12)
		&"tv":
			color = Color(0.03, 0.03, 0.04)
		&"shoe_rack":
			color = Color(0.4, 0.3, 0.22)
		&"aircon":
			color = Color(0.92, 0.92, 0.9)
		&"lift_button":
			color = Color(0.7, 0.7, 0.7)
		&"bedroom_wall", &"mirror_wall":
			color = Color(0.79, 0.77, 0.71) if o[0] == &"bedroom_wall" else WALL_MIRROR
	# the window and the moved things are drawn by their props; only the click box is added
	if not [&"bedroom_window", &"shoes_moved", &"chair_turned", &"tap", &"sink", &"bed", &"shoe_rack"].has(o[0]):
		_box(it, Vector3.ZERO, o[2], color, false)
	add_child(it)
	if o.size() > 6:
		gate(it, o[6])


func _build_label(l: Array) -> void:
	var label := Label3D.new()
	label.text = l[0]
	label.position = l[1]
	label.rotation.y = l[2]
	label.pixel_size = l[3]
	label.modulate = l[4]
	label.font_size = 64
	label.outline_size = 0
	label.shaded = true
	add_child(label)
	if l.size() > 5:
		gate(label, l[5])


func _build_fan() -> void:
	_fan = Node3D.new()
	_fan.position = Vector3(6.5, 2.5, 7.0)
	add_child(_fan)
	_box(self, Vector3(6.5, 2.6, 7.0), Vector3(0.03, 0.2, 0.03), Color(0.85, 0.85, 0.82), false)  # downrod
	_box(_fan, Vector3.ZERO, Vector3(0.18, 0.12, 0.18), Color(0.85, 0.85, 0.82), false)
	for i in 3:
		var blade := Node3D.new()
		blade.rotation.y = TAU * i / 3.0
		_fan.add_child(blade)
		_box(blade, Vector3(0.45, 0, 0), Vector3(0.7, 0.015, 0.12), Color(0.55, 0.42, 0.3), false)


# --- outside ------------------------------------------------------------------------------------

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.12, 0.13, 0.17)
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.03, 0.035, 0.06)
	environment.fog_density = 0.012
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	_apply_brightness()
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)


func _apply_brightness() -> void:
	environment.tonemap_exposure = float(Settings.get_value("brightness"))


func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1207
	var img := Image.create(1024, 512, false, Image.FORMAT_RGB8)
	for y in 512:
		var t := y / 511.0
		img.fill_rect(Rect2i(0, y, 1024, 1), Color(0.02, 0.025, 0.06).lerp(Color(0.16, 0.09, 0.08), pow(t, 3.0)))
	var x := 0
	while x < 1024:
		var w := rng.randi_range(30, 90)
		var top := rng.randi_range(170, 330)
		var shade := rng.randf_range(0.02, 0.05)
		img.fill_rect(Rect2i(x, top, w, 512 - top), Color(shade, shade, shade * 1.3))
		for wy in range(top + 6, 500, 9):
			for wx in range(x + 4, x + w - 4, 7):
				if rng.randf() < 0.18:
					var warm := Color(1.0, 0.82, 0.5) if rng.randf() < 0.7 else Color(0.75, 0.85, 1.0)
					img.fill_rect(Rect2i(wx, wy, 3, 4), warm * rng.randf_range(0.4, 0.9))
		x += w + rng.randi_range(0, 12)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_fog = true
	# east (living room window), south (corridor), north (bedroom window)
	for spec: Array in [[Vector3(55, -8, 4), -PI / 2], [Vector3(6, -8, 60), PI], [Vector3(8, -8, -50), 0.0]]:
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(160, 80)
		quad.mesh = qm
		quad.material_override = mat
		quad.position = spec[0]
		quad.rotation.y = spec[1]
		add_child(quad)

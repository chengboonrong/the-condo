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
	# Living room (the sofa, the coffee table and the selipar are Decor's)
	[Vector3(6.5, 2.3, 4.14), Vector3(0.95, 0.3, 0.2), Color(0.9, 0.9, 0.88)],  # aircon above the TV
	[Vector3(6.5, 0.005, 7.5), Vector3(2.4, 0.01, 1.6), Color(0.33, 0.14, 0.12)],  # rug
	# Kitchen
	[Vector3(0.35, 0.45, 4.9), Vector3(0.6, 0.9, 3.0), Color(0.6, 0.55, 0.48)],
	[Vector3(0.22, 2.0, 4.9), Vector3(0.35, 0.7, 3.0), Color(0.62, 0.57, 0.5)],
	[Vector3(0.35, 0.92, 5.6), Vector3(0.5, 0.04, 0.5), Color(0.12, 0.12, 0.12)],
	# Bathroom
	[Vector3(3.6, 1.0, -0.6), Vector3(1.0, 2.0, 0.02), Color(0.7, 0.85, 0.9, 0.25)],
	[Vector3(3.2, 2.0, -1.5), Vector3(0.22, 0.45, 0.3), Color(0.95, 0.95, 0.95)],
	# Bedroom
	[Vector3(5.85, 1.0, 1.4), Vector3(0.6, 2.0, 1.4), Color(0.5, 0.38, 0.28)],
	[Vector3(6.1, 0.38, -1.25), Vector3(1.0, 0.76, 0.55), Color(0.5, 0.38, 0.28)],
	# Corridor
	[Vector3(-0.95, 0.25, 10.35), Vector3(0.8, 0.5, 0.3), Color(0.35, 0.25, 0.2)],  # shoe racks beside the neighbours' gates
	[Vector3(13.05, 0.25, 10.35), Vector3(0.8, 0.5, 0.3), Color(0.35, 0.25, 0.2)],
	[Vector3(18.96, 1.05, 11.25), Vector3(0.04, 2.1, 1.3), Color(0.6, 0.62, 0.64)],
	# B-11-07: the bedroom, mirrored, dusty
	[Vector3(9.65, 1.0, -15.1), Vector3(0.6, 2.0, 1.4), Color(0.35, 0.28, 0.22), {&"bedroom": &"door"}],
	[Vector3(9.4, 0.38, -17.75), Vector3(1.0, 0.76, 0.55), Color(0.35, 0.28, 0.22), {&"bedroom": &"door"}],
]

# Blender models (art/<id>/build.py): [node name, model id, transform, requires, dusty (optional, default
# false)]. A model draws what PROPS boxes drew; COLLIDERS keeps their collision.
const MODELS: Array[Array] = [
	# Entrance: the shoe rack, and the work shoes on it or, when they have moved, lined up facing the living room
	[&"shoe_rack", &"shoe_rack", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.25, 0, 8.0)), {}],
	# The intercom handset unit by the front door, its back on the west wall's face (x = WALL_T / 2).
	[&"intercom", &"intercom", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.075, 1.48, 8.56)), {}],
	[&"shoes_on_rack", &"work_shoes", Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(0.29, 0.6, 7.8)), {&"entrance_shoes": &"default"}],
	[&"shoes_moved", &"work_shoes", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(2.3, 0, 8.5)), {&"entrance_shoes": &"moved"}],
	# Living room: the dining table, with the tudung saji and the teh tarik on it, and its three chairs. The turned
	# one stands at the south edge facing north, through the hallway opening, away from the table.
	[&"dining_table", &"dining_table", Transform3D(Basis(), Vector3(4.5, 0, 6.2)), {}],
	[&"chair_north", &"dining_chair", Transform3D(Basis(Vector3.UP, PI), Vector3(4.5, 0, 6.85)), {}],
	[&"chair_south", &"dining_chair", Transform3D(Basis(), Vector3(4.5, 0, 5.55)), {&"living_chair": &"default"}],
	[&"chair_turned", &"dining_chair", Transform3D(Basis(Vector3.UP, PI), Vector3(3.45, 0, 5.2)), {&"living_chair": &"turned"}],
	# Bathroom: the basin with its tap, shelf, cup and toothbrush, and the water while the tap is left running. The stream
	# starts at the spout (basin/build.py's SPOUT, turned with the basin), which is inside the tap's click box.
	[&"basin", &"basin", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(3.3, 0, 1.0)), {}],
	[&"tap_water", &"tap_water", Transform3D(Basis(), Vector3(3.24, 0.964, 1.0)), {&"bathroom_tap": &"running"}],
	# The bed, with its mattress, pillows, bolster and kicked-down blanket; its headboard is at -Z, towards the wall with the window
	[&"bed", &"bed", Transform3D(Basis(), Vector3(8.95, 0, 0.2)), {}],
	# Kitchen: the fridge, its doors facing east (+X): the management notice hangs on the flat of the nearer one
	[&"fridge", &"fridge", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.4, 0, 2.95)), {}],
	# The TV corner: the chipboard cabinet with the TV, the decoder and the router on it. The TV's glass lies on the `tv` click box.
	[&"tv_cabinet", &"tv_cabinet", Transform3D(Basis(), Vector3(6.5, 0, 4.3)), {}],
	# B-11-07: the same intercom on the mirror room's west wall (face at x = 5.5 + WALL_T / 2), dusty
	[&"intercom_mirror", &"intercom", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(5.575, 1.45, -14.6)), {&"bedroom": &"door"}, true],
	# B-11-07: the same bed, turned half round like the room (headboard at +Z, towards the wall with the door), dusty
	[&"bed_b1107", &"bed", Transform3D(Basis(Vector3.UP, PI), Vector3(6.55, 0, -16.3)), {&"bedroom": &"door"}, true],
	# The mamak apron drying on the laundry rack by the window, folded over its rail, its front to the room: the one the
	# figure wears (art/shared/apron)
	[&"apron_hung", &"apron_hung", Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(9.3, 1.69, 6.82)), {}],
]
# Collision for furniture a model draws: [center, size, requires]. A colliding PROPS entry with no mesh. The chairs'
# seats are too thin to collide; their backs do, from 0.475 m up to the model's 0.9 m. The beds' bases are boxes the
# size of their frames, the fridge's the size of its cabinet. The table's and the basin's are Decor's. The sofa (its
# seat, back and arms) and the coffee table keep the boxes they were drawn as before Decor built them.
const COLLIDERS: Array[Array] = [
	[Vector3(6.5, 0.22, 9.5), Vector3(2.2, 0.44, 0.75), {}],
	[Vector3(6.5, 0.6, 9.8), Vector3(2.2, 0.75, 0.22), {}],
	[Vector3(5.3, 0.35, 9.5), Vector3(0.2, 0.7, 0.85), {}],
	[Vector3(7.7, 0.35, 9.5), Vector3(0.2, 0.7, 0.85), {}],
	[Vector3(6.5, 0.2, 7.3), Vector3(1.1, 0.4, 0.6), {}],
	[Vector3(8.95, 0.25, 0.2), Vector3(1.8, 0.5, 2.0), {}],
	[Vector3(6.55, 0.25, -16.3), Vector3(1.8, 0.5, 2.0), {&"bedroom": &"door"}],
	[Vector3(0.4, 0.9, 2.95), Vector3(0.7, 1.8, 0.7), {}],
	[Vector3(4.5, 0.6875, 7.05), Vector3(0.42, 0.425, 0.05), {}],
	[Vector3(4.5, 0.6875, 5.35), Vector3(0.42, 0.425, 0.05), {&"living_chair": &"default"}],
	[Vector3(3.45, 0.6875, 5.4), Vector3(0.42, 0.425, 0.05), {&"living_chair": &"turned"}],
	[Vector3(6.5, 0.25, 4.3), Vector3(2.0, 0.5, 0.45), {}],
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
		"Twelve floors down, the mamak where you used to work is still open. Someone in your apron is pulling teh tarik. They stop, and look up.", {&"bedroom": &"default"}],
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

# The red earth of the mountain road, tracked in after it: the line he walked from just inside the front door,
# through the entrance's opening (3, 8.5), to where he stands (SPAWN), and the shoe print he left along it.
const TRAIL_PATH: Array[Vector3] = [Vector3(1.1, 0.006, 9.5), Vector3(3.0, 0.006, 8.5), Vector3(ApartmentLayout.SPAWN.x, 0.006, 8.45)]
const TRAIL_PRINTS := 10
const TRAIL_SWAY := 0.07  # each print lies this far to its side of the line, left and right in turn
const RED_EARTH := Color(0.48, 0.22, 0.1)  # laterite: orange-red, not the dark red of blood
const PRINT_SIZE := Vector2(0.105, 0.28)  # one print of his work shoes, across and along, in metres
const TREADS := 4  # the tread texture's cells, heaviest deposit first
const TOE_OUT := 0.12  # radians each foot turns out from the line
const GLINT_LENGTH := 0.15  # metres of stream one glint_texture covers
const GLINT_SPEED := 0.9  # metres a second its glints fall
# The three lines drawn through the mirror's steam, as points (metres across from its left edge, down from its top)
# a finger went through, top first.
const STEAM_LINES := [
	[Vector2(0.205, 0.17), Vector2(0.214, 0.3), Vector2(0.232, 0.43)],
	[Vector2(0.262, 0.155), Vector2(0.27, 0.29), Vector2(0.29, 0.44)],
	[Vector2(0.318, 0.175), Vector2(0.327, 0.31), Vector2(0.344, 0.42)],
]
## The rings where the running water lands, spreading from the middle of a small disc and gone at its edge.
const RIPPLE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, shadows_disabled;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) + 0.05 * sin(atan(p.y, p.x) * 5.0 + TIME * 3.0);
	float ring = pow(0.5 + 0.5 * sin(r * 28.0 - TIME * 40.0), 3.0);
	float fade = (1.0 - smoothstep(0.45, 1.0, r)) * smoothstep(0.05, 0.2, r);
	// Troughs darken the white bowl a little, as water does; crests catch the light.
	ALBEDO = mix(vec3(0.42, 0.47, 0.5), vec3(1.0), ring);
	ROUGHNESS = 0.08;
	EMISSION = vec3(0.35) * ring * fade;
	ALPHA = (0.2 + 0.45 * ring) * fade;
}
"""
## The sole's outline for tread_texture(): [toe (0) to heel (1), half-width inside, half-width outside].
const SOLE := [
	[0.0, 0.0, 0.0], [0.03, 0.5, 0.55], [0.1, 0.86, 0.84], [0.24, 1.0, 0.96], [0.38, 0.86, 0.92], [0.5, 0.5, 0.8],
	[0.6, 0.44, 0.76], [0.7, 0.64, 0.78], [0.82, 0.72, 0.78], [0.93, 0.6, 0.64], [0.985, 0.28, 0.32], [1.0, 0.0, 0.0],
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
var models: Dictionary = {}  # node name -> the placed model, Decor's too (the wall clock and the fan)
var lights: Dictionary = {}  # room_id -> Array[RoomLight]
var environment: Environment
var fan_speed := 1.0  # 1 turns the blades at 2.6 rad/s; AudioDirector winds it to 0 with the fan's sound
var _gated: Array = []  # [Node3D, requires]
var _materials: Dictionary = {}
var _fan: Node3D
var _plaster_tex: ImageTexture
static var _tread: ImageTexture  # tread_texture(), made once
static var _steam := {}  # steam_textures() by mirror size, made once each
var _glint: StandardMaterial3D  # the running water's: _process slides its glints down


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
	for c: Array in COLLIDERS:
		_collider(c[0], c[1], c[2])
	_build_models()
	_build_running_water()
	for o: Array in OBJECTS:
		_build_object(o)
	if Journey.road_ending != &"":
		_build_footprints()
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


## Shows every model whatever its variant, so the shader warm-up sees every material; refresh_variants() puts
## them back.
func warm_up_models() -> void:
	for node: Node3D in models.values():
		node.visible = true


## A model from assets/models, as art/<id>/build.py exported it.
static func model(id: StringName) -> Node3D:
	return (load("res://assets/models/%s.glb" % id) as PackedScene).instantiate()


func _process(delta: float) -> void:
	if _fan:
		_fan.rotate_y(delta * 2.6 * fan_speed)
	if _glint:
		# Triplanar V runs down the world (Godot flips it), so a growing offset carries the glints down.
		_glint.uv1_offset.y = fposmod(_glint.uv1_offset.y + delta * GLINT_SPEED / GLINT_LENGTH, 1.0)


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


## Collision for furniture a model draws, with its contact shadow when it stands on the floor.
func _collider(center: Vector3, size: Vector3, requires: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	gate(body, requires)
	if center.y - size.y * 0.5 < 0.02:
		decor.foot(center, Vector2(size.x, size.z) * 0.5, 0.5, requires)


## Places MODELS. A blended surface is drawn as plain alpha, like the game's other glass and water, and casts no
## shadow (glTF imports it with a depth pre-pass and cannot say no to shadows). B-11-07's dusty copies get their own
## greyed, matte materials.
func _build_models() -> void:
	for m: Array in MODELS:
		var node := model(m[1])
		node.name = m[0]
		node.transform = m[2]
		add_child(node)
		models[m[0]] = node
		gate(node, m[3])
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for s in mesh.mesh.get_surface_count():
				var blend := mesh.get_active_material(s) as BaseMaterial3D
				if blend and blend.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					blend = blend.duplicate()
					blend.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mesh.set_surface_override_material(s, blend)
					mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.size() > 4 and m[4]:
			for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				for s in mesh.mesh.get_surface_count():
					var mat := mesh.get_active_material(s).duplicate() as BaseMaterial3D
					mat.albedo_color *= Color(0.75, 0.73, 0.7)
					mat.roughness = 1.0
					mat.roughness_texture = null  # the baked texture would keep its shine
					mesh.set_surface_override_material(s, mat)


## The running water's life. Its stream keeps its plain colour, a little less blue, and gets a broken glint
## (glint_texture, projected down it in world space as the mesh has no UVs) that _process slides down as it falls.
## Where it lands, rings spread on the bowl's floor: tap_ripple, shown with the stream.
func _build_running_water() -> void:
	var water: Node3D = models[&"tap_water"]
	var stream := water.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_glint = stream.get_active_material(0).duplicate() as StandardMaterial3D
	_glint.albedo_color = Color(0.46, 0.53, 0.58, _glint.albedo_color.a)  # it darkens the white bowl seen through it
	_glint.emission_enabled = true
	_glint.emission = Color.WHITE
	_glint.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY  # the texture says where; ADD would light it all
	_glint.emission_energy_multiplier = 1.0
	_glint.emission_texture = glint_texture()
	_glint.uv1_triplanar = true
	_glint.uv1_world_triplanar = true
	_glint.uv1_scale = Vector3(1.0, 1.0 / GLINT_LENGTH, 1.0)
	stream.set_surface_override_material(0, _glint)
	var ripple := Node3D.new()
	ripple.name = "tap_ripple"
	ripple.position = water.position + Vector3(0.0, -0.142, 0.0)  # 2 mm over the bowl's floor (basin/build.py)
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.07, 0.07)
	disc.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = RIPPLE_SHADER
	disc.material_override = m
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ripple.add_child(disc)
	add_child(ripple)
	models[&"tap_ripple"] = ripple
	gate(ripple, MODELS.filter(func(e: Array) -> bool: return e[0] == &"tap_water")[0][3])


func gate(node: Node3D, requires: Dictionary) -> void:
	if not requires.is_empty():
		_gated.append([node, requires])


func _set_collision(node: Node, on: bool) -> void:
	if node is CollisionShape3D:
		node.set_deferred(&"disabled", not on)
	for child in node.get_children():
		_set_collision(child, on)


## Tiles with 2 px grout, projected in world space. size: tile width, and height on walls. Mipmapped and anisotropic,
## like the road: without mipmaps a far floor samples the grout only now and then, and its lines across the view break
## into dashes.
func tile_material(base: Color, grout: Color, size := Vector2(0.6, 0.6)) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(base)
	for i in 64:
		for j in [0, 1]:
			img.set_pixel(i, j, grout)
			img.set_pixel(j, i, grout)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
		decor.wall_piece(center, size, axis, requires, not requires.has(&"gap"), w.get("parapet", false) and p[3] < h)
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
	var back: float = -data["swing"] * 0.025  # the panel hangs behind its hinge pin (Door.setup)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.046, ApartmentLayout.DOOR_HEIGHT - 0.03, 0.05)  # 3 mm gaps to the frame
	shape.shape = box
	shape.position = Vector3(width * 0.5 - 0.02, ApartmentLayout.DOOR_HEIGHT * 0.5, back)
	door.add_child(shape)
	if door_id == &"main_door":
		# The front door is a model: panel, lever handles, deadbolt and peephole. It fills the collision box, its outside
		# (the model's front) towards the corridor at +z.
		var panel := model(&"front_door")
		panel.name = &"front_door"
		panel.position = Vector3(shape.position.x - box.size.x * 0.5, shape.position.y - box.size.y * 0.5, back)  # its hinge-side bottom edge, mid-thickness
		door.add_child(panel)
		# The peephole (art/front_door/build.py PEEPHOLE): a 2 cm box on the panel's inside face, and its view just
		# outside the outside face, facing the corridor.
		var hole := Peephole.new()
		hole.name = &"peephole"
		hole.object_id = &"peephole"
		hole.prompt = "Look through the peephole"
		hole.position = panel.position + Vector3(0.477, 1.55, -box.size.z * 0.5 - 0.01)
		var knob := CollisionShape3D.new()
		knob.shape = BoxShape3D.new()
		(knob.shape as BoxShape3D).size = Vector3(0.12, 0.12, 0.02)
		hole.add_child(knob)
		hole.view = Camera3D.new()
		hole.view.position.z = box.size.z + 0.02  # 1 cm out of the outside face, clear of the lens
		hole.view.rotation.y = PI
		hole.view.fov = 140.0  # wide enough to see down the corridor both ways once the lens bends it
		hole.view.near = 0.02
		hole.view.far = 120.0  # as the player's camera
		hole.add_child(hole.view)
		door.add_child(hole)
	else:
		_box(door, shape.position, box.size, data["color"], false)
		for s: float in [-1.0, 1.0]:  # lever handles on both sides
			_box(door, Vector3(width - 0.12, 1.0, back + s * 0.045), Vector3(0.06, 0.06, 0.015), Color(0.7, 0.68, 0.6), false)
			_box(door, Vector3(width - 0.17, 1.0, back + s * 0.07), Vector3(0.12, 0.02, 0.02), Color(0.7, 0.68, 0.6), false)
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
			glow.position = Vector3(pos.x, top - 0.045, pos.z)  # screwed to the ceiling, its plate touching it
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
		&"door_1206", &"door_1208", &"fire_door":
			color = Color(0.35, 0.25, 0.18) if o[0] != &"fire_door" else Color(0.55, 0.15, 0.12)
		&"shoe_rack":
			color = Color(0.4, 0.3, 0.22)
		&"aircon":
			color = Color(0.92, 0.92, 0.9)
		&"lift_button":
			color = Color(0.7, 0.7, 0.7)
		&"bedroom_wall", &"mirror_wall":
			color = Color(0.79, 0.77, 0.71) if o[0] == &"bedroom_wall" else WALL_MIRROR
	# these click boxes are drawn by their props or models; only the click box is added
	if not [&"bedroom_window", &"shoes_moved", &"chair_turned", &"tap", &"sink", &"bed", &"shoe_rack", &"intercom", &"intercom_mirror", &"tv", &"footprints", &"bathroom_mirror"].has(o[0]):
		_box(it, Vector3.ZERO, o[2], color, false)
	if o[0] == &"bathroom_mirror":
		_build_steamed_mirror(it, o[2])
	add_child(it)
	if o.size() > 6:
		gate(it, o[6])


## The bathroom mirror on the wall at the back of its click box (size: deep, tall, wide; facing +x): a frameless
## pane, its edge the green of thick glass, and on its face the steam with the three lines drawn through it
## (steam_textures), the room behind you showing dimly in them.
func _build_steamed_mirror(it: Node3D, size: Vector3) -> void:
	var wall := -size.x * 0.5 + 0.012  # on the wall's tiles (Decor._bathroom)
	_box(it, Vector3(wall + 0.003, 0.0, 0.0), Vector3(0.006, size.y, size.z), Color(0.5, 0.6, 0.57), false)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size.z, size.y)
	face.mesh = quad
	face.position = Vector3(wall + 0.0062, 0.0, 0.0)
	face.rotation.y = PI / 2  # the quad faces +z: now +x, its left edge at +z as seen from the room
	var textures := steam_textures(Vector2(size.z, size.y))
	var m := StandardMaterial3D.new()
	m.albedo_texture = textures[0]
	m.roughness_texture = textures[1]
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic_specular = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	face.material_override = m
	it.add_child(face)


## Each print's centre, the door's first, evenly along TRAIL_PATH.
static func footprint_trail() -> Array[Vector3]:
	var total := 0.0
	for i in range(1, TRAIL_PATH.size()):
		total += TRAIL_PATH[i].distance_to(TRAIL_PATH[i - 1])
	var trail: Array[Vector3] = []
	for k in TRAIL_PRINTS:
		var left := total * k / (TRAIL_PRINTS - 1.0)
		var i := 1
		while i < TRAIL_PATH.size() - 1 and left > TRAIL_PATH[i].distance_to(TRAIL_PATH[i - 1]):
			left -= TRAIL_PATH[i].distance_to(TRAIL_PATH[i - 1])
			i += 1
		var dir := (TRAIL_PATH[i] - TRAIL_PATH[i - 1]).normalized()
		trail.append(TRAIL_PATH[i - 1] + dir * left + Vector3(-dir.z, 0.0, dir.x) * (TRAIL_SWAY if k % 2 == 0 else -TRAIL_SWAY))
	return trail


## The prints as flat quads in one mesh (a Decal does not draw in the Compatibility renderer), lit like the floor
## and blended over it: the tread texture says where the earth stuck. Strongest just inside the door and fainter at
## each step after, as his soles ran out of earth, each turned and pressed a little differently. Then the low box
## over the living-room stretch that inspects them, 2 cm tall so he walks over it.
func _build_footprints() -> void:
	var trail := footprint_trail()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1147
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in trail.size():
		var t := i / (trail.size() - 1.0)  # 0 at the door, 1 where he stands
		var line := (trail[mini(i + 1, trail.size() - 1)] - trail[maxi(i - 1, 0)]).normalized()  # not the sway
		var out := 1.0 if i % 2 == 0 else -1.0  # which side of the line the foot is on (footprint_trail's sway)
		var turn := TOE_OUT + rng.randf_range(-0.07, 0.07)
		var fwd := (line + Vector3(-line.z, 0.0, line.x) * out * tan(turn)).normalized()
		var side := Vector3(-fwd.z, 0.0, fwd.x) * out  # towards the foot's outer edge
		var cell := clampi(roundi(t * (TREADS - 1) + rng.randf_range(-0.5, 0.5)), 0, TREADS - 1)
		var earth := Color(RED_EARTH, clampf(lerpf(0.95, 0.5, t) + rng.randf_range(-0.07, 0.07), 0.0, 1.0))
		var corners := []
		var uv := []
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:  # (across, toe to heel)
			corners.append(trail[i] + side * c.x * PRINT_SIZE.x * 0.5 - fwd * c.y * PRINT_SIZE.y * 0.5)
			uv.append(Vector2((cell + (c.x + 1.0) * 0.5) / TREADS, (c.y + 1.0) * 0.5))
		Decor._poly(st, corners, Vector3.UP, earth, uv)
	var prints := MeshInstance3D.new()
	prints.name = "Footprints"
	prints.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = tread_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.95  # dried earth
	prints.material_override = m
	prints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(prints)
	_build_object([&"footprints", Vector3(4.65, 0.01, 8.45), Vector3(2.9, 0.02, 0.5), "Look at the footprints", "Footprints",
		"Red earth, from the mountain road. You don't remember walking in."])


## The tread of his work shoes printed in earth, TREADS cells side by side, each leaving less than the last: white,
## its alpha the earth left on the tile, x across (the outer edge at the right), y from the toe down to the heel.
## The rim and the lugs print, packed earth fills the grooves in places, the arch barely touches, and the earth breaks
## into patches and crumbs at a ragged edge, more in each cell. Made in code, once.
static func tread_texture() -> ImageTexture:
	if _tread:
		return _tread
	var w := 48
	var h := 128
	var patches := FastNoiseLite.new()
	patches.seed = 1147
	patches.frequency = 0.06
	var grit := FastNoiseLite.new()
	grit.seed = 2026
	grit.frequency = 0.45
	var img := Image.create(w * TREADS, h, false, Image.FORMAT_LA8)
	for cell in TREADS:
		var lost := 0.12 + 0.11 * cell
		for py in h:
			for px in w:
				var gx := cell * w + px
				var x := (px + 0.5) / w * 2.2 - 1.1
				var y := (py + 0.5) / h
				var patch := patches.get_noise_2d(gx, py) * 0.5 + 0.5
				var g := grit.get_noise_2d(gx, py) * 0.5 + 0.5
				var inside := _sole_half(y, x > 0.0) - absf(x) + (patches.get_noise_2d(gx * 4.0 + 900.0, py * 4.0) * 0.1)
				var a := 0.0
				if inside > 0.0:
					var lug: float
					if y > 0.7:  # the heel block: bars across
						lug = 1.0 - smoothstep(0.55, 0.7, fposmod(y * 15.0, 1.0))
					else:  # the sole: small lugs laid like bricks
						var row := floorf(y * 19.0)
						var col := fposmod((x + 1.1) * 2.7 + 0.5 * fposmod(row, 2.0), 1.0)
						lug = (1.0 - smoothstep(0.62, 0.78, fposmod(y * 19.0, 1.0))) * (1.0 - smoothstep(0.7, 0.85, col))
					if inside < 0.12:
						lug = 1.0  # the rim prints whole
					var packed := smoothstep(0.45, 0.75, patches.get_noise_2d(gx * 2.0 + 400.0, py * 2.0) * 0.5 + 0.5)
					var arch := smoothstep(0.38, 0.5, y) * (1.0 - smoothstep(0.62, 0.72, y))
					var press := 1.0 - arch * (0.75 if x < 0.0 else 0.15)
					a = smoothstep(0.0, 0.05, inside) * press * lerpf(0.35, 1.0, maxf(lug * (0.55 + 0.45 * g), packed))
					a *= smoothstep(lost - 0.1, lost + 0.1, patch * (0.7 + 0.3 * press))
					if g < lost * 0.4:
						a = 0.0  # crumbled away
				elif inside > -0.25 and g > 0.86 and patch > 0.45:
					a = 0.6  # crumbs knocked off the edge
				var l := 0.8 + 0.2 * g  # thicker earth is darker
				img.set_pixel(gx, py, Color(l, l, l, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_tread = ImageTexture.create_from_image(img)
	return _tread


## The running water's glint along one GLINT_LENGTH of stream (y), the same all the way round (x): a faint sheen
## broken by bright beads and dashes, as a falling stream breaks the light. It wraps, so it can slide. Made in code.
static func glint_texture() -> ImageTexture:
	var h := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 964
	var glints := []  # [centre, half-length, brightness], in texture heights
	for i in 5:
		glints.append([rng.randf(), rng.randf_range(0.006, 0.03), rng.randf_range(0.4, 1.0)])
	var img := Image.create(2, h, false, Image.FORMAT_L8)
	for y in h:
		var v := (y + 0.5) / h
		var l := 0.1
		for g: Array in glints:
			var d := absf(v - g[0])
			d = minf(d, 1.0 - d)  # wrapped
			l = maxf(l, g[2] * exp(-pow(d / g[1], 2.0)))
		for x in 2:
			img.set_pixel(x, y, Color(l, l, l))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The mirror's face (size: wide, tall, in metres) fogged with steam, and the three STEAM_LINES a finger wiped through
## it: [albedo, roughness]. The fog is pale and uneven, piled up a little along each line's soft edges; water has run a
## little way from two of the lines' ends, and a few beads sit in the fog. Through the lines the glass shows the lit
## room behind you, dim, cool and blurred. Made in code, once for each size.
static func steam_textures(size: Vector2) -> Array[ImageTexture]:
	if _steam.has(size):
		return _steam[size]
	var w := 160
	var h := roundi(w * size.y / size.x)
	var mist := FastNoiseLite.new()
	mist.seed = 1155
	mist.frequency = 0.03
	var grain := FastNoiseLite.new()
	grain.seed = 2311
	grain.frequency = 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 1147
	var runs := []  # [x, top, bottom], metres: short runs from the first and last lines' ends, then beads in the fog
	for line: Array in [STEAM_LINES[0], STEAM_LINES[2]]:
		var end: Vector2 = line[-1]
		runs.append([end.x + rng.randf_range(-0.002, 0.002), end.y, end.y + rng.randf_range(0.015, 0.035)])
	for i in 3:
		var top := rng.randf_range(0.35, 0.7) * size.y
		runs.append([rng.randf_range(0.06, 0.94) * size.x, top, top])
	var albedo := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rough := Image.create(w, h, false, Image.FORMAT_L8)
	var hw := 0.0105  # half a finger's width
	var lines := Rect2(STEAM_LINES[0][0], Vector2.ZERO)  # around all three, a finger's width out
	for line: Array in STEAM_LINES:
		for q: Vector2 in line:
			lines = lines.expand(q)
	lines = lines.grow(hw * 2.0)
	for py in h:
		for px in w:
			var p := Vector2((px + 0.5) / w * size.x, (py + 0.5) / h * size.y)
			var edge := minf(minf(p.x, size.x - p.x), minf(p.y, size.y - p.y))
			var m := mist.get_noise_2d(px, py)
			var fog := (0.9 + 0.07 * m + 0.04 * grain.get_noise_2d(px, py)) * lerpf(0.75, 1.0, smoothstep(0.0, 0.04, edge))
			var clear := 0.0
			var ridge := 0.0
			var wobble := 1.0 + 0.15 * grain.get_noise_2d(px * 0.3, py * 0.3) if lines.has_point(p) else 1.0
			for line: Array in STEAM_LINES:
				if not lines.has_point(p) or p.y < line[0].y - 0.03 or p.y > line[-1].y + 0.03:
					continue
				for k in range(1, line.size()):
					var a: Vector2 = line[k - 1]
					var b: Vector2 = line[k]
					var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
					var along := (k - 1 + t) / (line.size() - 1.0)  # 0 where the finger went on, 1 where it lifted
					var r := hw * (1.05 - 0.15 * along) * wobble  # a fingertip keeps its width, lifting a little
					var d := p.distance_to(a.lerp(b, t))
					var smear := 0.12 * (0.5 + 0.5 * sin(d / r * 9.0))  # the finger's ridges leave a little behind
					clear = maxf(clear, (1.0 - smoothstep(r * 0.3, r * 1.3, d)) * (1.0 - smear))
					ridge = maxf(ridge, 1.0 - smoothstep(r * 1.2, r * 2.1, d))
			for run: Array in runs:
				if p.y > run[1] - 0.004 and p.y < run[2] + 0.004:
					var x: float = run[0] + 0.0005 * sin(p.y * 60.0)
					var foot := Vector2(x, clampf(p.y, run[1], run[2]))
					var dr := p.distance_to(foot) * (0.6 if p.y > run[2] else 1.0)  # fatter at the bead
					clear = maxf(clear, 0.45 * (1.0 - smoothstep(0.001, 0.0025, dr)))
					ridge = maxf(ridge, 1.0 - smoothstep(0.002, 0.0035, dr))
			fog = clampf(fog + 0.1 * ridge, 0.0, 1.0) * (1.0 - clear)
			# The room behind you, out of focus: the bathroom's pale tiles, cool and a little dimmer than the fog.
			var room := Color(0.47, 0.52, 0.57).lerp(Color(0.55, 0.6, 0.64), smoothstep(0.15, 0.85, p.y / size.y))
			room = room.lightened(0.06 * m)
			albedo.set_pixel(px, py, room.lerp(Color(0.7, 0.72, 0.73), fog))
			var ro := lerpf(0.2, 0.85, fog)  # wet glass, not a polished one: no dark sky in it
			rough.set_pixel(px, py, Color(ro, ro, ro))
	albedo.generate_mipmaps()
	rough.generate_mipmaps()
	var textures: Array[ImageTexture] = [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(rough)]
	_steam[size] = textures
	return textures


## Half the sole's width (1 at the ball) on its inner (arch) or outer side, from the toe (y 0) to the heel (1).
static func _sole_half(y: float, outer: bool) -> float:
	for i in range(1, SOLE.size()):
		if y <= SOLE[i][0]:
			var k: float = inverse_lerp(SOLE[i - 1][0], SOLE[i][0], y)
			return lerpf(SOLE[i - 1][2 if outer else 1], SOLE[i][2 if outer else 1], k)
	return 0.0


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


## The living room's ceiling fan, hanging from the ceiling above the lamp. Its Blades (housing and blades, pivoting on the
## downrod) are what _process turns.
func _build_fan() -> void:
	var fan := model(&"ceiling_fan")
	fan.name = &"ceiling_fan"
	fan.position = Vector3(6.5, ApartmentLayout.CEILING, 7.0)
	add_child(fan)
	models[&"ceiling_fan"] = fan
	_fan = fan.get_node("Blades")


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

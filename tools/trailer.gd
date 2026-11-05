# Films the trailer (needs a window, not --headless): plays the shot list in the game through its own state, signals and
# nodes, and draws the cuts, the black and the text cards itself, so a Movie Maker recording of the run is the trailer.
#   godot --path . --resolution 1920x1080 --write-movie <abs>/frame.png --script res://tools/trailer.gd [-- --until=<seconds>]
#   godot --path . --resolution 1920x1080 --fixed-fps 60 --script res://tools/trailer.gd [-- --until=<seconds>]
# The second form is the preview. Only --write-movie or --fixed-fps 60 gives true timing: without them the frame counter
# runs at the display rate (120 Hz, say) while fades run in real time.
# Prints TRAILER_FRAMES <first> <count>: the movie frame the trailer starts on and its length in frames (everything
# before is loading, under black). Exits 1 if a figure cue was not seen within 1.5 s. The game's own sighting is what
# plays the stinger and sends the hallway figure away, so a figure that is never seen means the trailer is wrong.
# Movie Maker records at the project's window size, not --resolution: 1920x1080 needs a temporary override.cfg with
# display/window/size/window_width_override=1920 and window_height_override=1080.
extends SceneTree

## Movie Maker's rate: the shot list runs on a frame counter, so every take is the same.
const FPS := 60.0
const FADE := 0.25  # cards fade in and out over this
## Text cards: [font size on the 900 px base, colour, outline, vertical anchor (0.5 = centred), pixels below it].
const CARDS := {
	"red": [56, Color(0.95, 0.4, 0.35, 0.9), 0, 0.5, 0.0],  # the HUD clock's red
	"line": [40, Color(1, 1, 1, 0.92), 8, 0.3, 0.0],  # over the picture, clear of the subtitle
	"title": [72, Color(1, 1, 1), 0, 0.5, 0.0],
	"small": [36, Color(1, 1, 1, 0.8), 0, 0.5, 70.0],  # under the title
}
## The captions are the game's own text (pinned by tests/integration/test_trailer.gd): a --script file can't reach
## StoryDirector or ApartmentLayout while it compiles, so the shot list holds their values.
const ROSNAH := "\"Every night also the same. Knock, knock, knock. From your bedroom.\""
const SHOES := "[Your work shoes, in the middle of the floor. You always leave them on the rack.]"
const CHAIR := "[Someone has turned the chair to face the bedroom.]"
## The storyboard (docs/superpowers/specs/2026-11-05-trailer-design.md). Times in seconds, cue times from the shot's
## start. Yaw 0 faces -z. Lights not listed keep their 11:47 PM state; variant areas not listed are default.
## Cues: [time, "card", style, text, until] / [time, "say", text, seconds] / [time, "sound", id, pos, db] /
## [time, "act", act] / [time, "stop_bed", id] / [time, "variant", area, variant] / [time, "turn", radians, seconds] /
## [time, "figure", anchor, seconds] / [time, "black"]
const SHOTS: Array[Dictionary] = [
	{"name": "open", "at": 0.0, "len": 4.0, "act": 1, "pos": Vector3(1.4, 0, 4.2), "yaw": 0.0, "pitch": 0.0,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": false, "fov": 0.0, "clock": false, "black": true,
		"walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[0.5, "card", "red", "11:47 PM", 3.5]]},  # by the fridge, for its hum
	{"name": "corridor", "at": 4.0, "len": 6.0, "act": 1, "pos": Vector3(13.0, 0, 11.4), "yaw": PI / 2, "pitch": 0.0,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": false, "fov": 0.0, "clock": false, "black": false,
		"walk": Vector2(0, 0.8), "creep": 0.0,  # 1.76 m/s: stops short of x 2.5, before the front door
		"cues": [[0.6, "sound", &"lift_ding", Vector3(18.5, 1.5, 11.25), 0.0],  # ApartmentLayout.LIFT_POS, 1.5 m up
			[0.8, "card", "line", "Home from the night shift at the mamak.", 5.0]]},
	{"name": "home", "at": 10.0, "len": 5.0, "act": 1, "pos": Vector3(6.5, 0, 8.4), "yaw": 0.0, "pitch": 0.15,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": false, "fov": 0.0, "clock": false, "black": false,
		"walk": Vector2.ZERO, "creep": 0.25,
		"cues": []},
	{"name": "intercom", "at": 15.0, "len": 5.0, "act": 1, "pos": Vector3(2.75, 0, 7.25), "yaw": 2.24, "pitch": -0.1,
		"lights_on": [&"entrance"], "lights_off": [], "variants": {}, "phone": false, "fov": 0.0, "clock": false,
		"black": false, "walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[0.0, "sound", &"intercom_ring", Vector3(0.1, 1.45, 8.6), -2.0],  # the phone_intercom anchor
			[0.9, "say", ROSNAH, 4.0]]},
	{"name": "drain", "at": 20.0, "len": 6.0, "act": 1, "pos": Vector3(6.5, 0, 8.4), "yaw": 0.0, "pitch": 0.15,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": false, "fov": 0.0, "clock": false, "black": false,
		"walk": Vector2.ZERO, "creep": 0.0,
		# Act 2 unsettled: the grade eases over its 4 s, and the game's own schedule fades the TV.
		"cues": [[0.0, "act", 2], [0.0, "stop_bed", &"fridge"], [1.6, "stop_bed", &"fan"],
			[2.2, "card", "line", "You haven't made a sound.", 5.6]]},
	{"name": "wall", "at": 26.0, "len": 4.0, "act": 2, "pos": Vector3(7.2, 0, 2.1), "yaw": 0.149, "pitch": -0.12,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": true, "fov": 0.0, "clock": false, "black": false,
		"walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[0.8, "sound", &"knock3", Vector3(6.6, 1.3, -1.9), 0.0],  # the knock_bedroom_north anchor
			[0.8, "say", "[Three knocks from the bedroom]", 3.0]]},
	{"name": "shoes", "at": 30.0, "len": 6.0, "act": 2, "pos": Vector3(2.7, 0, 9.6), "yaw": 0.7, "pitch": -0.66,
		"lights_on": [&"entrance"], "lights_off": [], "variants": {}, "phone": false, "fov": 0.0, "clock": false,
		"black": false, "walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[1.2, "turn", 1.5, 0.5], [1.9, "variant", &"entrance_shoes", &"moved"], [2.1, "turn", -1.5, 0.5],
			[2.6, "say", SHOES, 3.4]]},
	{"name": "chair", "at": 36.0, "len": 3.0, "act": 2, "pos": Vector3(5.5, 0, 7.0), "yaw": 0.723, "pitch": -0.3,
		"lights_on": [], "lights_off": [], "variants": {&"living_chair": &"turned"}, "phone": false, "fov": 0.0,
		"clock": false, "black": false, "walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[0.0, "say", CHAIR, 3.0]]},
	{"name": "tap", "at": 39.0, "len": 3.0, "act": 2, "pos": Vector3(4.4, 0, 0.3), "yaw": 2.137, "pitch": -0.35,
		"lights_on": [], "lights_off": [], "variants": {&"bathroom_tap": &"running"}, "phone": true, "fov": 0.0,
		"clock": false, "black": false, "walk": Vector2.ZERO, "creep": 0.0,
		"cues": []},  # the game's tap player makes the water
	{"name": "still", "at": 42.0, "len": 7.0, "act": 2, "pos": Vector3(3.3, 0, 3.25), "yaw": -PI / 2, "pitch": 0.0,
		"lights_on": [&"hallway"], "lights_off": [&"living", &"kitchen", &"bathroom", &"bedroom"], "variants": {},
		"phone": false, "fov": 0.0, "clock": false, "black": false, "walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[0.0, "figure", &"still_hallway", 8.0], [3.6, "turn", 1.4, 0.4], [4.4, "turn", -1.4, 0.4]]},
	{"name": "kitchen", "at": 49.0, "len": 4.0, "act": 2, "pos": Vector3(1.5, 0, 6.5), "yaw": 0.114, "pitch": -0.05,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": true, "fov": 0.0, "clock": false, "black": false,
		"walk": Vector2.ZERO, "creep": 0.0,
		# Seen at about 0.6 s, the figure plays the game's stinger; cut to black on the bedroom door slamming at 0.7,
		# while the figure is still nearly solid.
		"cues": [[0.3, "figure", &"sil_kitchen", 5.0], [0.7, "black"],
			[0.7, "sound", &"door_slam", Vector3(6.75, 1.2, 2.5), 0.0]]},
	{"name": "clock", "at": 53.0, "len": 4.0, "act": 2, "pos": Vector3(5.3, 0, 5.6), "yaw": 0.0, "pitch": 0.28,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": false, "fov": 28.0, "clock": true, "black": false,
		"walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[0.6, "card", "line", "And it's always 11:47.", 3.8]]},
	{"name": "title", "at": 57.0, "len": 5.0, "act": 2, "pos": Vector3(5.3, 0, 5.6), "yaw": 0.0, "pitch": 0.28,
		"lights_on": [], "lights_off": [], "variants": {}, "phone": false, "fov": 0.0, "clock": false, "black": true,
		"walk": Vector2.ZERO, "creep": 0.0,
		"cues": [[0.4, "card", "title", "THE CONDO: 11:47 PM", 4.6],
			[1.6, "card", "small", "Play free in your browser. GitHub Game Off 2026.", 4.6]]},
]


func _initialize() -> void:
	var until := INF
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--until="):
			until = arg.trim_prefix("--until=").to_float()
	# Black from the first frame: the shader warm-up tour and the start card are never seen.
	var layer := CanvasLayer.new()
	layer.layer = 128
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	root.add_child(layer)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	while not main.loaded:
		await process_frame
	prepare(main)
	var bus := root.get_node("EventBus")  # autoload names don't resolve in --script files
	var world := root.get_node("WorldState")
	var player = main.player  # untyped: project class names can't be referenced from the startup script
	var seen := {}  # anchor -> true once the game has reported the figure there seen
	bus.silhouette_seen.connect(func(anchor: StringName) -> void: seen[anchor] = true)
	var watching := []  # [anchor, frame it must be seen by]
	var missed := 0
	var cards := []  # [label, from, until] in seconds
	var turn := []  # [from (s), from yaw, radians, seconds]
	var shot := {}
	var next_shot := 0
	var next_cue := 0
	var last: Dictionary = SHOTS[-1]
	var total := roundi((last["at"] + last["len"]) * FPS)
	# The movie frame this one is written to: what is set now is drawn this frame.
	var first := Engine.get_process_frames()
	var frames := 0
	while frames < total and frames < until * FPS:
		var t := frames / FPS
		if next_shot < SHOTS.size() and frames >= roundi(SHOTS[next_shot]["at"] * FPS):
			shot = SHOTS[next_shot]
			next_shot += 1
			next_cue = 0
			turn = []
			set_up_shot(main, shot)
			black.visible = shot["black"]
		var cues: Array = shot["cues"]
		while next_cue < cues.size() and frames >= roundi((shot["at"] + cues[next_cue][0]) * FPS):
			var c: Array = cues[next_cue]
			next_cue += 1
			match c[1]:
				"card":
					cards.append([_card(layer, c[2], c[3]), t, shot["at"] + c[4]])
				"say":
					bus.subtitle_requested.emit(c[2], c[3])  # the HUD shows it as in the game
				"sound":
					bus.sound_requested.emit(c[2], c[3], c[4])
				"act":
					world.set_act(c[2])
				"stop_bed":
					main.audio._stopped[c[2]] = true  # never restarted by the act's own schedule
					main.audio._stop_bed(c[2])
				"variant":
					world.set_variant(c[2], c[3])
				"turn":
					turn = [t, player.yaw, c[2], c[3]]
				"figure":
					# The figure's own _physics_process sights it, plays the stinger and hides it, as in the game.
					seen.erase(c[2])
					watching.append([c[2], frames + roundi(1.5 * FPS)])
					bus.silhouette_requested.emit(c[2], c[3])
				"black":
					black.visible = true
		if not turn.is_empty():
			player.set_look(turn[1] + turn[2] * smoothstep(0.0, 1.0, (t - turn[0]) / turn[3]), player.pitch)
		if shot["creep"] > 0.0:  # moved, not walked: player physics is off, so no footsteps
			player.global_position = shot["pos"] - player.global_basis.z * shot["creep"] * (t - shot["at"]) / shot["len"]
		for card: Array in cards.duplicate():
			if t >= card[2]:
				card[0].queue_free()
				cards.erase(card)
			else:
				card[0].modulate.a = clampf(minf(t - card[1], card[2] - t) / FADE, 0.0, 1.0)
		for w: Array in watching.duplicate():
			if seen.has(w[0]):
				watching.erase(w)
			elif frames >= w[1]:
				printerr("the figure at %s was never seen" % w[0])
				missed += 1
				watching.erase(w)
		frames += 1
		await process_frame
	print("TRAILER_FRAMES %d %d" % [first, frames])
	main.queue_free()
	await process_frame
	quit(1 if missed > 0 else 0)


## Films the game as players get it: the shipped settings, in memory only (set_value would write the owner's file),
## no player input (so main never steps the horror runtime or opens the pause menu), and of the HUD only the
## subtitles, drawn larger so they read in a small embed.
static func prepare(main: Node3D) -> void:
	var settings := main.get_node("/root/Settings")
	settings.values = settings.DEFAULTS.duplicate()
	settings._apply_volume()
	settings.changed.emit()
	main.player.input_enabled = false
	var hud = main.hud
	for c: CanvasItem in [hud._start, hud._crosshair, hud._prompt, hud._clock]:
		c.visible = false
	hud._objective.text = ""
	hud._subtitle.add_theme_font_size_override("font_size", 34)


## Cuts to the shot: the condo in its state, the player there, the grade settled.
static func set_up_shot(main: Node3D, shot: Dictionary) -> void:
	var world := main.get_node("/root/WorldState")
	var layout = load("res://scripts/world/apartment_layout.gd")
	var player = main.player
	world.set_act(shot["act"])
	for room: StringName in layout.LIGHTS:
		world.set_light(room, (layout.LIGHTS[room]["on"] or room in shot["lights_on"]) and room not in shot["lights_off"])
	for area: StringName in layout.VARIANT_AREAS:
		world.set_variant(area, shot["variants"].get(area, &"default"))
	player.global_position = shot["pos"]
	player.set_look(shot["yaw"], shot["pitch"])
	player.phone_light.visible = shot["phone"]
	player.camera.fov = shot["fov"] if shot["fov"] > 0.0 else float(main.get_node("/root/Settings").get_value("fov"))
	player.camera.position.y = 0.0  # the walk's head bob, frozen mid-stride when its physics stops
	main.hud._clock.visible = shot["clock"]
	main.silhouette.visible = false
	player.scripted_move = shot["walk"]
	player.use_scripted_move = true
	player.velocity = Vector3.ZERO
	player.set_physics_process(shot["walk"] != Vector2.ZERO)  # walking is the game's own, footsteps and head bob
	# The grade follows the player's room, which main only updates on the next physics tick: set it now so settle()
	# jumps to this shot's grade.
	world.set_player_room(layout.room_at(player.global_position, world.variants))
	main.look.settle()


static func _card(layer: CanvasLayer, style: String, text: String) -> Label:
	var s: Array = CARDS[style]
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", s[0])
	l.add_theme_color_override("font_color", s[1])
	if s[2] > 0:
		l.add_theme_constant_override("outline_size", s[2])
		l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.anchor_right = 1.0
	l.anchor_top = s[3]
	l.anchor_bottom = s[3]
	l.offset_top = s[4] - 100.0
	l.offset_bottom = s[4] + 100.0
	l.modulate.a = 0.0
	layer.add_child(l)  # over the black, added first
	return l

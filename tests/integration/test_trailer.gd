extends TestCase
## The trailer (tools/trailer.gd) keeps to the approved storyboard: its length, words and captions, nothing from the
## window door on, and the game as players get it, with the shipped settings.

const TRAILER := "res://tools/trailer.gd"
const NAMES := ["open", "corridor", "home", "intercom", "drain", "wall", "shoes", "chair", "tap", "still", "kitchen",
	"clock", "title"]


func test_trailer_runs_55_to_65_seconds() -> bool:
	var shots: Array = load(TRAILER).SHOTS
	eq(shots.map(func(s: Dictionary) -> String: return s["name"]), NAMES, "shots in the storyboard's order")
	var end := 0.0
	for s: Dictionary in shots:
		near(s["at"], end, 0.0001, "%s starts where the last shot ended" % s["name"])
		var last := 0.0
		for c: Array in s["cues"]:
			check(c[0] >= 0.0 and c[0] < s["len"], "%s: %s cue at %.2f s is inside the shot" % [s["name"], c[1], c[0]])
			check(c[0] >= last, "%s: %s cue at %.2f s is in time order" % [s["name"], c[1], c[0]])
			last = c[0]
			if c[1] == "card":
				check(c[4] > c[0] and c[4] <= s["len"], "%s: card \"%s\" ends inside the shot" % [s["name"], c[3]])
		end = s["at"] + s["len"]
	check(end >= 55.0 and end <= 65.0, "the trailer ends at %.1f s" % end)
	return true


func test_trailer_cards_are_the_approved_words() -> bool:
	eq(_cues("card").map(func(c: Array) -> String: return c[3]), ["11:47 PM", "Home from the night shift at the mamak.",
		"You haven't made a sound.", "And it's always 11:47.", "THE CONDO: 11:47 PM",
		"Play free in your browser. GitHub Game Off 2026."], "card texts")
	return true


func test_trailer_captions_are_the_games_own() -> bool:
	var said: Array = _cues("say").map(func(c: Array) -> String: return c[2])
	eq(said.size(), 4, "captions")
	if said.size() != 4:
		return true
	var rosnah: String = said[0]
	check(rosnah.begins_with("\"Every night"), "Rosnah's line first, got %s" % rosnah)
	# As written in the story's string literal, quotes escaped.
	check(FileAccess.get_file_as_string("res://scripts/story/story_director.gd").contains(rosnah.c_escape()),
		"Rosnah's line is the story's, verbatim: %s" % rosnah)
	eq(said[1], "[Three knocks from the %s]" % EventContext.new().room_name(&"bedroom"), "the knocks' caption")
	eq(said[2], StoryDirector.NOTICE[&"shoes_moved"][1], "the shoes' caption")
	eq(said[3], StoryDirector.NOTICE[&"chair_turned"][1], "the chair's caption")
	return true


func test_no_trailer_shot_shows_past_the_window_door() -> bool:
	var trailer: GDScript = load(TRAILER)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	for s: Dictionary in trailer.SHOTS:
		trailer.set_up_shot(main, s)
		var tag: String = s["name"] + ": "
		check(WorldState.player_room not in [&"gap", &"mirror_room"], tag + "player in %s" % WorldState.player_room)
		check(WorldState.get_variant(&"bedroom") != &"door", tag + "the bedroom window is a door")
		check(WorldState.act <= 2, tag + "act %d" % WorldState.act)
		for c: Array in s["cues"]:
			if c[1] == "figure":
				var room: StringName = ApartmentLayout.ANCHORS[c[2]]["room"]
				check(room not in [&"gap", &"mirror_room"], tag + "figure at %s in %s" % [c[2], room])
			elif c[1] == "act":
				check(c[2] <= 2, tag + "act cue to %d" % c[2])
			elif c[1] == "variant":
				check(c[2] != &"bedroom", tag + "variant cue on the bedroom")
	main.queue_free()
	return true


func test_trailer_films_with_the_shipped_settings() -> bool:
	if FileAccess.file_exists(Settings.path):
		DirAccess.remove_absolute(Settings.path)
	Settings.values["fov"] = 80.0
	Settings.values["head_bob"] = 0.0
	Settings.values["subtitles"] = false
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	load(TRAILER).prepare(main)
	var player: PlayerController = main.player
	var hud: Hud = main.hud
	eq(Settings.values, Settings.DEFAULTS, "settings")
	eq(player.camera.fov, 72.0, "field of view")
	eq(player.input_enabled, false, "player input")
	for l: CanvasItem in [hud._crosshair, hud._prompt, hud._clock, hud._start]:
		check(not l.visible, "%s hidden" % l)
	eq(hud._subtitle.get_theme_font_size("font_size"), 34, "subtitle font size")
	check(not FileAccess.file_exists(Settings.path), "no settings file written")
	main.queue_free()
	return true


## Every cue of this kind, in the trailer's order.
func _cues(kind: String) -> Array:
	var out := []
	for s: Dictionary in load(TRAILER).SHOTS:
		out.append_array((s["cues"] as Array).filter(func(c: Array) -> bool: return c[1] == kind))
	return out

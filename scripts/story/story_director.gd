class_name StoryDirector
extends RefCounted
## Acts, beats, objectives, dialogue, clues and endings. Reacts to what the player does (EventBus) and
## asks the scheduler for story events. Every beat has a fail-safe, so the story always moves on and
## both endings stay reachable whatever the adaptive director does. Time is simulation time.

## He broke a rule of the flat and dies of `cause` (HorrorRuntime.die).
signal killed(cause: StringName)

const SIGNS_NEEDED := 4
const BED_WAIT := 150.0  # fail-safe: the intercom rings even if the player never goes to bed
const ACT2_MIN := 240.0  # seconds of disturbance before act 3, even with enough signs
const ACT2_MAX := 420.0  # fail-safe: act 3 starts anyway
const DECISION_WAIT := 210.0  # fail-safe: waiting this long in B-11-07 is a choice too
const BEACON_EVERY := 30.0
## The play level of the bedroom's knocks after the intercom's call (the `complained` beat) while he is at the front
## door, 9.6 m and more from that wall: from the intercom, 11.6 m away, they stand 12 dB over the flat's room tone.
## Anywhere nearer they are played at +2, as before, or they would peak over the limit (docs/architecture.md, "The key
## sounds").
const KNOCK_AT_CALL_DB := 8.0
## After the road the flat opens quiet: no event, and no ring, for this long from the story's first tick.
const QUIET := 20.0
const HOME_OBJECTIVE := "Wash up, then get some sleep."
## After the road he is still lost: he washes the mountain off and tries to remember getting home (always shown).
const ROAD_OBJECTIVE := "Wash the mountain off. Lie down. Try to remember."
const ROAD_WASHED := "Lie down. Try to remember."
const ROAD_WASH := "[Cold water. Red earth runs off your hands.]"
## What he remembers last, lying down: the road's end, never getting home.
const LAST_MEMORY := {
	&"caught": "[You try to remember getting home. The bulb at the fruit stall going out. Then nothing.]",
	&"saved": "[You try to remember getting home. The lorry's tailgate in the fog. Then nothing.]",
	&"alive": "[You try to remember getting home. The lorry's tailgate in the fog. Then nothing.]",
}
## New story lines after the road (always shown). SMELL is a copy of Penanggal.SMELL, so the flat doesn't load the road's
## script; a test keeps them equal.
const SMELL := "[A sour smell, like vinegar.]"
const REVERSAL := "[On the road you weren't allowed to look back. Here, you can't look away.]"
## What he finds in the quiet: [seconds after the first tick, line, seconds on screen]. Story lines: always shown.
const OPENING_LINES := [
	[3.0, "[Your phone says 12:41 AM. The clock on the wall says 11:47.]", 4.5],
	[10.0, "[Your uniform is still damp from the fog.]", 3.5],
]

## Clues that count as signs that something is wrong (others are flavour).
const SIGN_CLUES: Array[StringName] = [&"vacant", &"own_unit", &"notes", &"mirror"]
const CLUE_OBJECTS := {
	&"complaint_slips": &"notes", &"notice_fridge": &"vacant", &"calendar": &"calendar", &"photo": &"photo",
	&"bathroom_mirror": &"mirror", &"tv": &"tv", &"aircon": &"aircon",
}
## Objects that only exist after a small shift: noticing one puts it back and counts as a sign.
const NOTICE := {
	&"shoes_moved": [&"entrance_shoes", "[Your work shoes, in the middle of the floor. You always leave them on the rack.]"],
	&"chair_turned": [&"living_chair", "[Someone has turned the chair to face the bedroom.]"],
	&"tap": [&"bathroom_tap", "[You turn the tap off. The handle is warm.]"],
}
const ENDINGS := {
	&"downstairs": ["DOWNSTAIRS", "You knock three times.\n\nUpstairs, someone who has just come home from a shift at the mamak stops in the dark and listens.\n\nThe notes under their door are in your handwriting."],
	&"vacant": ["VACANT", "The lift is warm, as if someone has just stepped out of it.\n\nA week later a new notice goes up by the letterboxes:\nUnit B-12-07 has been vacant since November.\n\nThe knocking never stops."],
}
## The last card after the road. Caught: today's text with a line added (downstairs) or its notice swapped (vacant).
## Saved and alive: their own text. Any other road (the flat opened directly) keeps ENDINGS.
const VACANT_NOTICE := "Unit B-12-07 has been vacant since November."
const CAUGHT_NOTICE := "Unit B-12-07 has been vacant since November. Its tenant was one of three people found on the old road down the mountain."
const ROAD_ENDINGS := {
	&"saved": {
		&"downstairs": "You knock three times.\n\nSomething knocks back, three times, from inside the wall, the way something landed on the roof of Hafiz's car.\n\nHafiz never got home. He's been knocking all night.",
		&"vacant": "The lift is warm, as if someone has just stepped out of it.\n\nYou don't go back up.\n\nHafiz never got home. Some nights you still hear him knocking.",
	},
	&"alive": {
		&"downstairs": "You knock three times.\n\nSomething knocks back.\n\nAll three of you got home. Something else came down the mountain too.\n\nOn the road it had Hafiz's voice. Tonight it has yours.",
		&"vacant": "The lift is warm, as if someone has just stepped out of it.\n\nYou don't go back up.\n\nAll three of you got home. Something else came down the mountain too.\n\nOn the road it had Hafiz's voice. Tonight it has yours.",
	},
}
## The intercom's last call after the road: the first line of the one who is lost.
const LAST_CALL := {
	&"caught": "\"Eh, you going down ah? Jom, we got space.\"",
	&"saved": "\"Wah, so late still working ah? Kesian, bro.\"",
}
## B-11-07's call after `saved`: the one the road took, in the voice that called them out of the car (mimic_open_door).
const HAFIZ_CALL := "\"Bro! Open the door, I found help!\""

var scheduler: EventScheduler
var transformer: RoomTransformer
var beat: StringName = &""
var road: StringName = &""  # how the road ended (Journey); &"" = the flat was opened directly
var beat_started := 0.0
var noticed := 0
## The flat as its current act began, as copies, for Try again (start_at_act). Empty until act 2.
var act_snapshot: Dictionary = {}
var progress: Array[Dictionary] = []  # every beat change, for tests and the playthrough report
var _fired: Dictionary = {}  # one-shot keys in the current beat
var _ever: Dictionary = {}  # one-shot keys for the whole flat (unlike _fired, kept across beats)
var _lines: Array = []  # queued [text, seconds, always]
var _line_left := 0.0
var _last_shift := 0.0
var _bedroom_since := -1.0
var _next_beacon := INF
var _t0 := INF  # when the first tick came
var _asking := false  # the "How did you get home?" objective is showing
var _call_pending := false  # he answered Rosnah on a road with a last call, and it has not played: it waits for the lines


func _init(event_scheduler: EventScheduler, room_transformer: RoomTransformer) -> void:
	scheduler = event_scheduler
	transformer = room_transformer
	road = Journey.road_ending
	EventBus.object_interacted.connect(_on_interacted)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.variant_changed.connect(_on_variant_changed)
	scheduler.run_finished.connect(_on_run_finished)


## The last card ([title, text]) for an ending, as the road changes it.
static func ending_card(ending_id: StringName, road_ending: StringName) -> Array:
	var card: Array = ENDINGS[ending_id]
	if road_ending == &"caught":
		var text: String = card[1]
		return [card[0], text + "\n\nYou never got home." if ending_id == &"downstairs" else text.replace(VACANT_NOTICE, CAUGHT_NOTICE)]
	if ROAD_ENDINGS.has(road_ending):
		return [card[0], ROAD_ENDINGS[road_ending][ending_id]]
	return card


func now() -> float:
	return WorldState.time


func beat_time() -> float:
	return now() - beat_started


## True while the flat is still holding its breath after the road.
func quiet() -> bool:
	return road != &"" and (_t0 == INF or now() - _t0 < QUIET)


func signs() -> int:
	return noticed + SIGN_CLUES.filter(func(c: StringName) -> bool: return WorldState.clues.has(c)).size()


## Where the current objective points (bots use it; a hint system could too). "" = anywhere.
func hint_room() -> StringName:
	match beat:
		&"home": return &"bedroom" if WorldState.has_flag(&"washed") else &"bathroom"
		&"ringing": return &"entrance"
		&"complained", &"knocked": return &"bedroom"
		&"front_door", &"reveal_pending": return &"entrance"
		&"revealed": return &"gap"
		&"in_gap", &"decision": return &"mirror_room"
	return &""


func tick(delta: float) -> void:
	_speak(delta)
	if _t0 == INF:
		_t0 = now()
	if beat == &"":
		_go(&"home")
		_asking = road != &""
		WorldState.set_objective("How did you get home?" if _asking else "You're home from your shift at the mamak. " + HOME_OBJECTIVE)
	if _call_pending:
		_play_last_call()  # once Rosnah has finished, wherever he is
	if road != &"":
		for i in OPENING_LINES.size():
			if now() - _t0 >= float(OPENING_LINES[i][0]) and _once_ever("opening%d" % i):
				say(OPENING_LINES[i][1], OPENING_LINES[i][2], true)
		if not quiet():
			_end_question()
	var t := beat_time()
	match beat:
		&"home":
			if t >= BED_WAIT:
				_ring()  # fail-safe: never went to bed
		&"in_bed":
			if t >= 4.0 and not quiet():
				_ring()
		&"ringing":
			if _once("hint", 30.0):
				WorldState.set_objective("Answer the intercom. It's by the front door.")
			if t > 1.0 and not scheduler.is_running(&"phone_ring") and not scheduler.is_queued(&"phone_ring"):
				say("[The intercom stops ringing.]", 2.5)  # fail-safe: unanswered, the knocks come anyway
				_go(&"complained")
		&"complained":
			if t >= 8.0:
				var at_door := [&"entrance", &"corridor"].has(WorldState.player_room)
				var level := KNOCK_AT_CALL_DB if at_door else 2.0
				scheduler.request(&"knock_wall", {"anchor": &"knock_bedroom_north", "volume_db": level, "sound": _knock(3)})
				WorldState.set_objective("Find where the knocking came from.")
				_go(&"knocked")
		&"knocked":
			if WorldState.player_room == &"bedroom":
				if _bedroom_since < 0.0:
					_bedroom_since = now()
				elif now() - _bedroom_since >= 4.0:
					_smell()
			else:
				_bedroom_since = -1.0
				if _once("again", 45.0):
					scheduler.request(&"knock_wall", {"anchor": &"knock_bedroom_north", "volume_db": 2.0, "sound": _knock(3)}, 5)
			if t >= 120.0 or (_bedroom_since >= 0.0 and now() - _bedroom_since >= 15.0):
				_wall_answers()
		&"disturbance":
			if t >= 30.0 and now() - _last_shift >= 75.0 and not scheduler.is_queued(&"shift") and not scheduler.is_running(&"shift"):
				scheduler.request(&"shift", {}, 5)  # make sure there is something to notice
			if (signs() >= SIGNS_NEEDED and t >= ACT2_MIN) or t >= ACT2_MAX:
				_start_act3()
		&"front_door":
			if t >= 5.0 and [&"entrance", &"corridor"].has(WorldState.player_room):
				_at_front_door()  # already there when the knocking started
			elif t >= 60.0:
				_request_reveal()  # fail-safe: the player never went to the door
		&"reveal_pending":
			if not scheduler.is_queued(&"shift") and not scheduler.is_running(&"shift"):
				scheduler.request(&"shift", {"area": &"bedroom", "variant": &"door"}, 20)  # the last try failed
			# fail-safe: the reveal needs the player out of the bedroom and not looking at it
			if now() >= _next_beacon:
				_next_beacon = now() + BEACON_EVERY
				if WorldState.player_room == &"bedroom":
					scheduler.request(&"knock_wall", {"anchor": &"knock_entrance_door", "volume_db": 3.0}, 5)
				elif WorldState.is_door_open(&"bedroom_door"):
					scheduler.start(&"door_slam", {"door": &"bedroom_door", "open": false, "story": true}, 10)
		&"revealed":
			# fail-safe: knocks from behind the new door keep calling the player back to the bedroom
			if now() >= _next_beacon and not [&"bedroom", &"gap"].has(WorldState.player_room):
				_next_beacon = now() + BEACON_EVERY
				scheduler.request(&"knock_wall", {"anchor": &"knock_bedroom_north", "sound": _knock(3)}, 5)
		&"decision":
			if _once("ring", 5.0):
				scheduler.request(&"phone_ring", {"anchor": &"phone_mirror", "stop_flag": &"answered_mirror"})
				WorldState.set_objective("Answer the intercom.")
			if not _fired.has("choice") and (WorldState.has_flag(&"answered_mirror") or t >= 40.0):
				_offer_choice()
			if _fired.has("choice") and not _fired.has("open") and _lines.is_empty() and _line_left <= 0.0:
				_open_choice()
			if _once("knocks", 120.0):
				scheduler.request(&"knock_wall", {"anchor": &"knock_mirror"}, 5)
			if t >= DECISION_WAIT:
				_end(&"downstairs", "[You waited too long. Your hand is already on the wall.]")


## `always` lines are story, not sound captions: they show whatever "Captions for sounds" says. A caption whose sound
## plays at that moment is not said but emitted on EventBus.subtitle_requested; a said one follows the lines before it.
func say(text: String, seconds := 3.5, always := false) -> void:
	_lines.append([text, seconds, always])


## Debug (F10): jump to the next act.
func debug_skip() -> void:
	match WorldState.act:
		WorldState.Act.COMPLAINT:
			_wall_answers()
		WorldState.Act.DISTURBANCE:
			_start_act3()
		WorldState.Act.IMPOSSIBLE:
			WorldState.set_variant(&"bedroom", &"door")
			_start_act4()
		WorldState.Act.DECISION:
			_end(&"downstairs")


## Try again: the flat as `snapshot` (act_snapshot) kept it when its act began, and that act begun again. The road's quiet and
## the lines of the opening are over for him, as they were.
func start_at_act(snapshot: Dictionary) -> void:
	for flag: StringName in snapshot["flags"]:
		WorldState.set_flag(flag, snapshot["flags"][flag])
	for clue: StringName in snapshot["clues"]:
		WorldState.add_clue(clue)
	for area: StringName in snapshot["variants"]:
		WorldState.set_variant(area, snapshot["variants"][area], false)
	for room: StringName in snapshot["lights"]:
		WorldState.set_light(room, snapshot["lights"][room])
	for door: StringName in snapshot["doors"]:
		WorldState.set_door(door, snapshot["doors"][door], &"restore")  # put back, not opened by him
	noticed = snapshot["noticed"]
	_call_pending = snapshot["call_pending"]
	_ever = snapshot["ever"].duplicate()
	_t0 = now() - QUIET
	match snapshot["act"]:
		WorldState.Act.DISTURBANCE:
			_wall_answers()
		WorldState.Act.IMPOSSIBLE:
			_start_act3()
		WorldState.Act.DECISION:
			_start_act4()


## Kept first thing as an act begins: what start_at_act puts back.
func _keep(act: int) -> void:
	act_snapshot = {"act": act, "flags": WorldState.flags.duplicate(true), "clues": WorldState.clues.duplicate(true),
		"variants": WorldState.variants.duplicate(true), "lights": WorldState.lights.duplicate(true),
		"doors": WorldState.doors.duplicate(true), "noticed": noticed, "call_pending": _call_pending, "ever": _ever.duplicate(true)}


func _go(next: StringName) -> void:
	beat = next
	beat_started = now()
	_fired.clear()
	progress.append({"t": snappedf(now(), 0.1), "beat": next, "act": WorldState.act, "signs": signs()})


func _once(key: String, at: float) -> bool:
	if _fired.has(key) or beat_time() < at:
		return false
	_fired[key] = true
	return true


func _once_ever(key: String) -> bool:
	if _ever.has(key):
		return false
	_ever[key] = true
	return true


## The question gives way to the usual objective (the quiet is over, or he found something).
func _end_question() -> void:
	if not _asking:
		return
	_asking = false
	if beat == &"home":
		WorldState.set_objective(ROAD_WASHED if WorldState.has_flag(&"washed") else ROAD_OBJECTIVE)


func _speak(delta: float) -> void:
	_line_left -= delta
	if _line_left <= 0.0 and not _lines.is_empty():
		var line: Array = _lines.pop_front()
		(EventBus.line_requested if line[2] else EventBus.subtitle_requested).emit(line[0], line[1])
		_line_left = float(line[1]) + 0.3


func _ring() -> void:
	scheduler.request(&"phone_ring", {"anchor": &"phone_intercom", "stop_flag": &"answered_intercom"})
	WorldState.set_objective("Answer the intercom.")
	_go(&"ringing")


## The bedroom wall knocks with the roof's body (thump_roof) after the road, and with plain knocks when the flat is
## opened directly.
func _knock(count: int) -> StringName:
	return StringName(("thump%d" if road != &"" else "knock%d") % count)


## Her smell, once in the flat, after the road. Only ever while he is in the bedroom.
func _smell() -> void:
	if road != &"" and WorldState.player_room == &"bedroom" and _once_ever("smell"):
		say(SMELL, 4.0, true)


## The road's rule turned round, once in the flat, after the road.
func _reversal() -> void:
	if road != &"" and _once_ever("reversal"):
		say(REVERSAL, 5.0, true)


## The wall's caption goes out with its knock, not through say(): it must not wait behind the lines already queued.
func _wall_answers() -> void:
	_keep(WorldState.Act.DISTURBANCE)
	EventBus.sound_requested.emit(_knock(1), ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"], 0.0)
	EventBus.subtitle_requested.emit("[The wall is cold. Something on the other side knocks back. Once.]", 4.0)
	_smell()  # he touched the wall before the 4 s were up: it follows the answer, never comes first
	WorldState.set_act(WorldState.Act.DISTURBANCE)
	WorldState.set_objective("Something in the flat is wrong. Look around.")
	_last_shift = now()
	_go(&"disturbance")


func _start_act3() -> void:
	_keep(WorldState.Act.IMPOSSIBLE)
	WorldState.set_act(WorldState.Act.IMPOSSIBLE)
	scheduler.request(&"knock_wall", {"anchor": &"knock_entrance_door", "volume_db": 3.0}, 10)
	WorldState.set_objective("Someone is knocking at the front door.")
	_go(&"front_door")


func _request_reveal() -> void:
	if beat != &"front_door":
		return
	_go(&"reveal_pending")  # first: a shift that is already safe applies inside request()
	_next_beacon = now() + BEACON_EVERY
	scheduler.request(&"shift", {"area": &"bedroom", "variant": &"door"}, 20)


func _at_front_door() -> void:
	say("[Nobody there. The corridor is empty.]", 3.0, true)
	say("[Deeper in the flat, something heavy settles.]", 3.5)
	_request_reveal()


func _start_act4() -> void:
	_keep(WorldState.Act.DECISION)
	WorldState.set_act(WorldState.Act.DECISION)
	transformer.required_rooms = [&"mirror_room"]
	scheduler.request(&"shift", {"area": &"gap", "variant": &"long"}, 20)
	say("[B-11-07. It's your flat, the wrong way round.]", 4.0, true)
	_go(&"decision")


## The call is over, answered or not (40 s on): Bang Din's rule after the road. Then _open_choice, once it is said.
func _offer_choice() -> void:
	_fired["choice"] = true
	if road != &"":
		say("[Don't answer, Bang Din said. Even if it sounds like %s.]" % ("Hafiz" if road == &"saved" else "you"), 4.0, true)


## Knock back or take the lift, once every line is over.
func _open_choice() -> void:
	_fired["open"] = true
	WorldState.set_prompt(&"mirror_wall", "Answer it: knock back three times")
	WorldState.set_prompt(&"lift_button", "Don't answer: take the lift")
	WorldState.set_objective("Answer it: knock back on the wall. Or don't: the lift is working.")


func choice_open() -> bool:
	return WorldState.act == WorldState.Act.DECISION and _fired.has("open")


func _end(ending_id: StringName, line := "") -> void:
	if WorldState.ending != &"":
		return
	if line != "":
		EventBus.line_requested.emit(line, 4.0)  # what he does: story, not a sound
	match ending_id:
		&"downstairs":
			EventBus.sound_requested.emit(_knock(3), ApartmentLayout.ANCHORS[&"knock_mirror"]["pos"], 2.0)
		&"vacant":
			EventBus.sound_requested.emit(&"lift_ding", ApartmentLayout.LIFT_POS + Vector3.UP * 1.5, 0.0)
	for run in scheduler.running.duplicate():
		scheduler.cancel(run, "story ended")
	scheduler.queue.clear()
	WorldState.set_act(WorldState.Act.ENDED)
	WorldState.set_objective("")
	WorldState.set_ending(ending_id)
	_go(&"ended")


func _on_interacted(object_id: StringName) -> void:
	if WorldState.ending != &"":
		return
	if CLUE_OBJECTS.has(object_id):
		WorldState.add_clue(CLUE_OBJECTS[object_id])
	elif NOTICE.has(object_id):
		var area: StringName = NOTICE[object_id][0]
		if WorldState.get_variant(area) != &"default":
			say(NOTICE[object_id][1], 4.0, true)
			_reversal()  # he has seen that something moved
			WorldState.set_variant(area, &"default", false)  # the player puts it back; not a shift
			noticed += 1
			if beat == &"disturbance" and signs() < SIGNS_NEEDED:
				WorldState.set_objective("Things move when you aren't looking. Keep looking.")
	match object_id:
		&"sink":
			if not WorldState.has_flag(&"washed"):
				WorldState.set_flag(&"washed")
				if road != &"":
					say(ROAD_WASH, 3.5, true)
				else:
					say("[Cold water. Your hands still smell of ghee and teh tarik. The oven clock says 11:47.]", 4.5, true)
				if beat == &"home" and not _asking:
					WorldState.set_objective("Get some sleep." if road == &"" else ROAD_WASHED)
			else:
				say("[Cold water.]", 2.0, true)
		&"bed":
			if beat == &"home":
				if road != &"":
					say(LAST_MEMORY[road], 4.5, true)
					say("[Somewhere in the building, a lift hums and stops.]", 3.5, true)
				else:
					say("[You lie down. Somewhere in the building, a lift hums and stops.]", 4.0, true)
				WorldState.set_objective("")
				_asking = false  # lying down clears the objective, the question with it
				_go(&"in_bed")
			elif WorldState.act < WorldState.Act.ENDED:
				say("[You can't sleep. Not now.]", 2.5, true)
		&"footprints":
			_end_question()
		&"intercom":
			if beat == &"ringing" and scheduler.is_running(&"phone_ring"):
				_answer_rosnah()
			elif WorldState.has_flag(&"answered_intercom"):
				WorldState.add_clue(&"own_unit")
				EventBus.inspect_requested.emit("Intercom", "LAST CALL  23:47\nFROM  B-12-07\n\nB-12-07 is this flat.")
			else:
				EventBus.inspect_requested.emit("Intercom", "The little screen is dark.")
		&"intercom_mirror":
			if beat == &"decision" and scheduler.is_running(&"phone_ring") and not WorldState.has_flag(&"answered_mirror"):
				_answer_upstairs()
			else:
				EventBus.inspect_requested.emit("Intercom", "The screen shows the corridor outside 11-07. Empty.")
		&"bedroom_wall":
			if beat == &"knocked":
				_wall_answers()
			else:
				EventBus.inspect_requested.emit("Bedroom wall", "Cold. Colder than the rest of the room.")
		&"mirror_wall":
			if choice_open():
				_end(&"downstairs")
			else:
				EventBus.inspect_requested.emit("Wall", "Cold. Colder than the rest of the room.")
		&"lift_button":
			if choice_open():
				_end(&"vacant")
			else:
				EventBus.inspect_requested.emit("Lift", "LIF ROSAK — DALAM PENYELENGGARAAN\nUNDER MAINTENANCE\n\nThe button doesn't light up.")


## Once, after the road: the last call plays back by itself, with the road's wind and engine and the one who is lost,
## once Rosnah's lines are over, wherever he is, unless an ending has started. Never over another voice or a knock: it
## waits for the lines and the knocks. A press of the intercom only shows the log's text.
func _play_last_call() -> void:
	if WorldState.ending == &"" and _lines.is_empty() and _line_left <= 0.0 and not scheduler.is_running(&"knock_wall") \
			and not scheduler.is_queued(&"knock_wall") and _once_ever("last_call"):
		_call_pending = false
		EventBus.sound_requested.emit(&"intercom_road", ApartmentLayout.ANCHORS[&"phone_intercom"]["pos"], 0.0)
		say("[The speaker crackles. Wind, and an engine idling.]", 3.0)  # a sound's caption: follows the setting
		say(LAST_CALL[road], 3.5, true)


func _answer_rosnah() -> void:
	WorldState.set_flag(&"answered_intercom")
	say("\"Hello? Sorry ah, so late.\"", 2.5)
	say("\"This is Rosnah. Downstairs, 11-07.\"", 3.0)
	say("\"Every night also the same. Knock, knock, knock. From your bedroom.\"", 4.0)
	say("\"Please. Can you stop the knocking?\"", 3.5)
	say("[The line goes dead.]", 2.5)
	_call_pending = LAST_CALL.has(road)  # alive, or no road: no recording
	WorldState.set_objective("You haven't knocked on anything.")
	_go(&"complained")


func _answer_upstairs() -> void:
	WorldState.set_flag(&"answered_mirror")
	if road == &"saved":
		say(HAFIZ_CALL, 3.5)
		say("[It's Hafiz's voice.]", 3.0, true)
	else:
		say("\"Hello? Sorry, so late. I just finished my shift at the mamak.\"", 3.5)
		say("\"This is upstairs. 12-07.\"", 3.0)
		say("\"Can you please stop the knocking?\"", 3.5)
		say("[It's your voice.]", 3.0, true)
	WorldState.set_objective("")


func _on_room_entered(room_id: StringName) -> void:
	match beat:
		&"front_door":
			if room_id == &"entrance" or room_id == &"corridor":
				_at_front_door()
		&"revealed":
			if room_id == &"bedroom" and _once("window", 0.0):
				say("[The window is a door.]", 3.0, true)
				WorldState.set_objective("Where does it go?")
			elif room_id == &"gap":
				say("[This can't be here. You're on the twelfth floor.]", 4.0, true)
				WorldState.set_objective("Follow the corridor.")
				_go(&"in_gap")
		&"in_gap":
			if room_id == &"mirror_room":
				_start_act4()


func _on_variant_changed(area_id: StringName, variant: StringName) -> void:
	if beat == &"reveal_pending" and area_id == &"bedroom" and variant == &"door":
		transformer.required_rooms = [&"mirror_room"]
		_next_beacon = now() + 60.0
		WorldState.set_objective("Something moved in the bedroom.")
		_go(&"revealed")


func _on_run_finished(run: Dictionary) -> void:
	if run["id"] == &"shift" and run["state"] == EventScheduler.State.COMPLETED:
		_last_shift = now()

extends Node
## Authoritative game state. Mutate only through these methods; each change is announced on EventBus.

enum Act { COMPLAINT = 1, DISTURBANCE = 2, IMPOSSIBLE = 3, DECISION = 4, ENDED = 5 }

const HISTORY_LIMIT := 64

var time := 0.0  # simulation seconds since the game started; never rewinds
var clock_anchor := 0.0  # sim time when the wall clock last read 11:47 PM (every shift resets it)
var act: int = Act.COMPLAINT
var objective := ""
var flags: Dictionary = {}  # StringName -> Variant
var clues: Dictionary = {}  # StringName -> true
var player_room: StringName = &""
var doors: Dictionary = {}  # door_id -> bool (open)
var lights: Dictionary = {}  # room_id -> bool (on)
var variants: Dictionary = {}  # area_id -> StringName
var prompts: Dictionary = {}  # object_id -> String, overrides an interactable's prompt
var entity_room: StringName = &""
var entity_state: StringName = &"dormant"
var event_history: Array[Dictionary] = []
var behavior: Dictionary = {}  # latest BehaviorProfiler summary, for debug and saves
var ending: StringName = &""


func reset() -> void:
	time = 0.0
	clock_anchor = 0.0
	act = Act.COMPLAINT
	objective = ""
	flags.clear()
	clues.clear()
	player_room = &""
	doors.clear()
	lights.clear()
	variants.clear()
	prompts.clear()
	entity_room = &""
	entity_state = &"dormant"
	event_history.clear()
	behavior.clear()
	ending = &""


func advance_time(dt: float) -> void:
	time += dt


## Minutes past midnight shown on the in-game clock. It starts at 11:47 PM and jumps back on every shift.
func clock_minutes() -> int:
	return (23 * 60 + 47 + int((time - clock_anchor) / 60.0)) % (24 * 60)


func set_act(value: int) -> void:
	if value == act:
		return
	act = value
	EventBus.act_changed.emit(act)


func set_objective(text: String) -> void:
	objective = text
	EventBus.objective_changed.emit(text)


func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false) == true


func add_clue(clue_id: StringName) -> int:
	if not clues.has(clue_id):
		clues[clue_id] = true
		EventBus.clue_found.emit(clue_id, clues.size())
	return clues.size()


func set_player_room(room_id: StringName) -> void:
	if room_id == player_room:
		return
	player_room = room_id
	EventBus.room_entered.emit(room_id)


func set_door(door_id: StringName, open: bool, source: StringName) -> void:
	if doors.get(door_id, false) == open and doors.has(door_id):
		return
	doors[door_id] = open
	EventBus.door_changed.emit(door_id, open, source)


func is_door_open(door_id: StringName) -> bool:
	return doors.get(door_id, false)


func set_light(room_id: StringName, on: bool) -> void:
	if lights.get(room_id, false) == on and lights.has(room_id):
		return
	lights[room_id] = on
	EventBus.light_changed.emit(room_id, on)


func is_light_on(room_id: StringName) -> bool:
	return lights.get(room_id, false)


func set_variant(area_id: StringName, variant: StringName) -> void:
	if variants.get(area_id, &"") == variant:
		return
	variants[area_id] = variant
	clock_anchor = time  # the condo shifted: it is 11:47 PM again
	EventBus.variant_changed.emit(area_id, variant)


func get_variant(area_id: StringName) -> StringName:
	return variants.get(area_id, &"default")


func set_prompt(object_id: StringName, text: String) -> void:
	prompts[object_id] = text


func set_entity(room_id: StringName, state: StringName) -> void:
	if room_id == entity_room and state == entity_state:
		return
	entity_room = room_id
	entity_state = state
	EventBus.entity_changed.emit(room_id, state)


func record_event(entry: Dictionary) -> void:
	event_history.append(entry)
	if event_history.size() > HISTORY_LIMIT:
		event_history.pop_front()


func set_ending(ending_id: StringName) -> void:
	if ending != &"":
		return
	ending = ending_id
	set_act(Act.ENDED)
	EventBus.ending_reached.emit(ending_id)

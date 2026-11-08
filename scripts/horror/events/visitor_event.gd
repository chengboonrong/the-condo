class_name VisitorEvent
extends HorrorEvent
## Someone comes to the front door. The lift chimes, footsteps come up the corridor to the door and stop,
## the presentation shows feet under it, and then they vanish without a sound. Opening the door ends it: nobody is there.
## Looking through the peephole does not: the empty corridor is all he sees, and the visit runs on.
## Once he has heard Rosnah's warning (the answered_intercom flag) breaking her rule kills him: the run ends with
## run["kill"] set to the cause (HorrorRuntime makes it his death). Opening the door at any time kills (&"front_door");
## so does any light on when the footsteps stop, his phone's included (&"lights_on"). Unwarned, nothing kills him.

const DOOR := Vector3(1.5, 0, 10.0)  # the front door on the floor (the doorway in ApartmentLayout.CONNECTIONS)
const MIN_DISTANCE := 2.5
const STEP_LENGTH := 0.7
const STEP_TIME := 0.55
const FIRST_STEP := 2.5  # after the chime: long enough to read its caption before the steps' caption replaces it
const WALK_Z := 10.6
const LAST_STEP := Vector3(1.5, 0, 10.35)

@export var steps := 24  # chime to feet must outlast a round of every switch: tests/unit/test_visitor.gd
@export var hold := 15.0  # seconds the feet stay under the door


func prepare(ctx: EventContext, run: Dictionary) -> String:
	if WorldState.is_door_open(&"main_door"):
		return "door_open"
	if not [&"entrance", &"living", &"kitchen"].has(ctx.player_room()):
		return "player_not_inside"
	if ctx.stage.distance_to(DOOR) < MIN_DISTANCE:
		return "player_at_door"
	var path: Array[Vector3] = []
	for i in steps - 1:
		path.append(Vector3(DOOR.x + (steps - 1 - i) * STEP_LENGTH, 0, WALK_Z))
	path.append(LAST_STEP)
	run["steps"] = path
	run["room"] = &"corridor"
	run["position"] = DOOR
	return ""


func start(_ctx: EventContext, run: Dictionary) -> void:
	EventBus.sound_requested.emit(&"lift_ding", ApartmentLayout.LIFT_POS + Vector3.UP * 1.5, -8.0)
	EventBus.subtitle_requested.emit("[A lift chimes down the corridor]", 3.0)
	run["next_step"] = FIRST_STEP


func update(ctx: EventContext, run: Dictionary, _delta: float) -> bool:
	var warned := WorldState.has_flag(&"answered_intercom")
	if WorldState.is_door_open(&"main_door"):
		if warned:
			run["kill"] = &"front_door"
		return true
	var path: Array = run["steps"]
	var i := int(run.get("step_index", 0))
	if run.get("feet", false):
		return run["elapsed"] >= run["feet_at"] + hold
	if run["elapsed"] < run["next_step"]:
		return false
	if i < path.size():
		EventBus.sound_requested.emit(&"footstep", path[i], lerpf(-16.0, -5.0, i / (path.size() - 1.0)))
		if i == 0:
			EventBus.subtitle_requested.emit("[Footsteps in the corridor, coming closer]", 3.0)
		run["step_index"] = i + 1
		run["next_step"] = run["elapsed"] + STEP_TIME
	else:
		run["feet"] = true
		run["feet_at"] = run["elapsed"]
		EventBus.door_feet_requested.emit(true)
		EventBus.subtitle_requested.emit("[The footsteps stop outside your door]", 4.0)
		if warned and _a_light_is_on(ctx):
			run["kill"] = &"lights_on"
			return true
	return false


## Any light of the flat, or his phone's. The corridor's is the building's, not his.
func _a_light_is_on(ctx: EventContext) -> bool:
	return ctx.stage.phone_light_on() or ApartmentLayout.APARTMENT_ROOMS.any(func(room: StringName) -> bool: return WorldState.is_light_on(room))


func finish(_ctx: EventContext, run: Dictionary, _result: StringName) -> void:
	if run.get("feet", false):
		EventBus.door_feet_requested.emit(false)

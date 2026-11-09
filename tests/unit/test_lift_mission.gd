extends TestCase
## Mission 1, the wait for a lift: the opening, the walk to the stop, the wait, and the couple's car stopping for him.

const OPENING := [
	"[12:06 AM. The last staff bus went down the mountain at eleven.]",
	"[Bang Din at the stall says the road down has rules. He only tells them after midnight.]",
	"[You laughed. He didn't.]",
]

var stage: RoadStage
var d: RoadDirector
var cues: Array[StringName] = []
var captions: Array[String] = []
var ended: Array[StringName] = []


## A mission after the lift that never finishes, so the director stays on it.
class Idle extends RoadMission:
	func tick(_delta: float) -> bool:
		return false


func _setup(then_idle := false) -> void:
	stage = RoadStage.new()
	stage.position = RoadLayout.EXIT
	var list: Array[RoadMission] = [LiftMission.new()]  # the lift alone: the other missions have their own tests
	if then_idle:
		list.append(Idle.new())
	d = RoadDirector.new(stage, 1147, list)
	cues.clear()
	captions.clear()
	ended.clear()
	EventBus.road_cue.connect(_on_cue)
	EventBus.line_requested.connect(_on_caption)
	EventBus.road_ended.connect(_on_ended)


func _teardown() -> void:
	EventBus.road_cue.disconnect(_on_cue)
	EventBus.line_requested.disconnect(_on_caption)
	EventBus.road_ended.disconnect(_on_ended)


func _on_cue(cue: StringName) -> void:
	cues.append(cue)


func _on_caption(text: String, _seconds: float) -> void:
	captions.append(text)


func _on_ended(ending: StringName) -> void:
	ended.append(ending)


func _run(seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		d.step(0.1)


## Steps until the cue comes, at most `limit` seconds. True if it came.
func _until(cue: StringName, limit: float) -> bool:
	for i in roundi(limit / 0.1):
		if cues.has(cue):
			return true
		d.step(0.1)
	return cues.has(cue)


func _lift() -> LiftMission:
	return d.missions[0] as LiftMission


func test_opening_then_walk_then_wait() -> bool:
	_setup()
	_run(0.2)
	eq(cues, [&"card_on"], "the opening starts on a black card")
	eq(_lift().beat, &"opening", "the opening")
	_run(13.0)
	eq(captions.slice(0, 3), OPENING, "his thoughts, word for word")
	eq(cues, [&"card_on", &"card_off"], "then the card goes")
	eq(_lift().beat, &"walk", "and he walks")
	eq(WorldState.objective, "Walk down to the bus stop and wait for a lift.", "the objective")
	stage.position = RoadLayout.BUS_STOP
	_run(0.2)
	eq(_lift().beat, &"wait", "at the stop: the wait")
	_run(19.0)
	check(not cues.has(&"lorry_passes"), "no lorry before 20 s")
	_run(1.5)
	eq(cues.back(), &"lorry_passes", "a lorry at 20 s")
	_run(23.0)
	check(not cues.has(&"couple_stops"), "no car before 45 s")
	check(_until(&"couple_stops", 30.0), "the couple stop for him")
	eq(cues, [&"card_on", &"card_off", &"lorry_passes", &"couple_stops"], "the cues in order")
	eq(d.car_s, RoadLayout.BUS_STOP_S, "the car stops exactly at the stop")
	eq(d.car_speed, 0.0, "and stands")
	eq(WorldState.prompts.get(&"car_door"), "Get in", "the door can be used")
	_run(0.2)
	check(captions.has("Mei: \"Eh, you going down ah? Jom, we got space.\""), "Mei calls out")
	eq(_lift().beat, &"get_in", "and waits for him")
	_teardown()
	return true


## Try again after missing the lift: no card and no opening again, he is walking at once (a first play is
## test_opening_then_walk_then_wait).
func test_a_retry_skips_the_opening() -> bool:
	_setup()
	check(not d.retried, "a first play is not a retry")
	d.restore([])
	WorldState.set_objective("")
	_run(0.1)
	eq(_lift().beat, &"walk", "he walks at once")
	eq(WorldState.objective, "Walk down to the bus stop and wait for a lift.", "with the objective")
	eq(cues, [] as Array[StringName], "no black card")
	_run(14.0)
	check(not captions.has(OPENING[0]) and not captions.has(OPENING[2]), "and no opening lines")
	eq(cues, [] as Array[StringName], "nor a card_off later")
	stage.position = RoadLayout.BUS_STOP
	_run(0.2)
	eq(_lift().beat, &"wait", "then the wait, as on a first play")
	_teardown()
	return true


func test_the_car_door_works_only_once_the_car_has_stopped() -> bool:
	_setup()
	_run(14.0)
	stage.position = RoadLayout.BUS_STOP
	_run(50.0)
	EventBus.object_interacted.emit(&"car_door")
	check(not d.seated, "the car is still coming: the door does nothing")
	check(_until(&"couple_stops", 30.0), "the couple stop")
	EventBus.object_interacted.emit(&"car_door")
	check(d.seated, "then he gets in")
	eq(cues.back(), &"seated", "seated cue")
	eq(WorldState.prompts.get(&"car_door"), "", "the prompt goes")
	EventBus.object_interacted.emit(&"car_door")
	eq(cues.count(&"seated"), 1, "once")
	_run(12.0)
	eq(ended, [&"alive"], "the lift is the only mission yet: the road ends after it, all alive")
	eq(d.score(), 0, "nothing broken")
	_teardown()
	return true


func test_waiting_away_from_the_stop_does_not_bring_the_car() -> bool:
	_setup()
	_run(120.0)
	check(not cues.has(&"couple_stops"), "at the staff exit for two minutes: no car")
	eq(_lift().beat, &"walk", "still the walk")
	stage.position = RoadLayout.BUS_STOP
	_run(5.0)
	stage.position = RoadLayout.point(RoadLayout.BUS_STOP_S - 10.0, 4.6)
	_run(120.0)
	check(not cues.has(&"lorry_passes") and not cues.has(&"couple_stops"), "10 m up the road: the wait doesn't count")
	stage.position = RoadLayout.BUS_STOP
	check(_until(&"couple_stops", 70.0), "back at the stop, the car comes")
	_teardown()
	return true


## Walks him to the stop and waits until the couple's car stands there for him.
func _to_get_in() -> void:
	_run(14.0)
	stage.position = RoadLayout.BUS_STOP
	_until(&"couple_stops", 120.0)
	_run(0.2)


func test_bang_din_warns_him_at_the_stop() -> bool:
	_setup()
	_run(14.0)
	check(not captions.has(LiftMission.WARN), "not on the walk")
	stage.position = RoadLayout.BUS_STOP
	_run(0.5)
	check(captions.has(LiftMission.WARN), "at the stop, Bang Din's warning comes back to him")
	stage.position = RoadLayout.point(RoadLayout.BUS_STOP_S - 10.0, 4.6)
	_run(5.0)
	stage.position = RoadLayout.BUS_STOP
	_run(10.0)
	eq(captions.count(LiftMission.WARN), 1, "and only the first time")
	_teardown()
	return true


func test_too_slow_to_get_in_he_is_left_and_dies() -> bool:
	_setup()
	_to_get_in()
	eq(_lift().beat, &"get_in", "(at the car door)")
	_run(10.1)
	check(cues.has(&"couple_leaves"), "10 s with no answer: the couple leave")
	eq(WorldState.prompts.get(&"car_door"), "", "the door is no use now")
	_run(1.0)
	check(d.car_speed > 0.0, "and the car drives off")
	eq(d.dead, &"", "(he is still standing there)")
	_run(LiftMission.LEFT_SECONDS)
	eq(d.dead, &"missed_lift", "left behind on the mountain")
	EventBus.object_interacted.emit(&"car_door")
	check(not d.seated, "too late to get in")
	_teardown()
	return true


func test_getting_in_within_ten_seconds_keeps_him() -> bool:
	_setup()
	_to_get_in()
	_run(9.3)
	EventBus.object_interacted.emit(&"car_door")
	_run(20.0)
	eq(d.dead, &"", "in the car in time")
	check(d.seated, "and still in it")
	check(not cues.has(&"couple_leaves"), "they didn't leave")
	_teardown()
	return true


func test_a_skip_during_the_opening_lifts_the_card() -> bool:
	_setup(true)
	_run(2.0)
	eq(cues, [&"card_on"], "on the black card")
	d.debug_skip()
	_run(3.0)
	eq([d.mission_index, cues], [1, [&"card_on", &"card_off"]], "skipped: the card goes, and nothing else comes")
	_teardown()
	return true


func test_a_skip_at_get_in_leaves_no_prompt_or_objective() -> bool:
	_setup(true)
	_to_get_in()
	eq(_lift().beat, &"get_in", "(at the car door)")
	eq([WorldState.prompts.get(&"car_door"), WorldState.objective], ["Get in", "Walk down to the bus stop and wait for a lift."], "(the prompt and the wait)")
	d.debug_skip()
	eq([WorldState.prompts.get(&"car_door"), WorldState.objective], ["", ""], "skipped: no prompt and no objective left")
	_teardown()
	return true


func test_a_finished_lift_never_seats_him_again() -> bool:
	_setup(true)
	_to_get_in()
	EventBus.object_interacted.emit(&"car_door")
	_run(12.0)
	eq(d.mission_index, 1, "(the lift is over)")
	var heard := captions.size()
	d.seated = false  # standing beside the car, later on
	EventBus.object_interacted.emit(&"car_door")
	_run(1.0)
	check(not d.seated, "the car door doesn't seat him")
	eq([cues.count(&"seated"), captions.size()], [1, heard], "no second seated cue, no second small talk")
	_teardown()
	return true

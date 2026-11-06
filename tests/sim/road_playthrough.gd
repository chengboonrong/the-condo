class_name RoadPlaythrough
extends RefCounted
## Simulated runs of the road: a rule-based bot plays the road's core (RoadDirector on a RoadStage, no physics, no
## rendering) from the opening to an ending. These are bots, not people; their results are never reported as
## playtests.
##
##   keeper   keeps every rule
##   wobbly   breaks a few
##   breaker  breaks most of them
##
## Each follows the policy table in the plan's Task 10, one row per mission as the missions are added. Mission 1 has
## no rule to break, so all three play it alike: walk down to the stop, wait, get in. In mission 2 the keeper follows
## the slow car all three times, the wobbly one overtakes at the third, and the breaker says nothing: Hafiz overtakes.
##
## run(profile, seed) returns the ending, the time it took, the score, the rules broken, every beat, and the errors
## and warnings logged during the run.

const DT := 0.1
const WALK := 2.2  # m/s, along the road
const VERGE := 4.6  # metres left of the centreline: the walk down the verge to the stop
const LIMIT := 40.0 * 60.0  # sim seconds before we call it stuck
const ANSWER_AFTER := 1.0  # seconds after a choice opens
const USE_AFTER := 0.5  # seconds after a prompt appears
## Each profile's answer, by choice id; -1 stays silent. The rows come with their missions.
const ANSWERS := {
	"keeper": {&"overtake_1": 0, &"overtake_2": 0, &"overtake_3": 0},
	"wobbly": {&"overtake_1": 0, &"overtake_2": 0, &"overtake_3": 2},
	"breaker": {&"overtake_1": -1, &"overtake_2": -1, &"overtake_3": -1},
}

var profile: String
var d: RoadDirector
var stage: RoadStage
var _choice: StringName = &""
var _choice_at := 0.0
var _prompts := {}  # object_id -> [text, when it appeared (INF once used)]


static func run(profile_name: String, seed_value: int) -> Dictionary:
	var bot := RoadPlaythrough.new()
	return bot._run(profile_name, seed_value)


func _run(profile_name: String, seed_value: int) -> Dictionary:
	profile = profile_name
	WorldState.reset()
	stage = RoadStage.new()
	stage.position = RoadLayout.EXIT
	d = RoadDirector.new(stage, seed_value)
	var catch := Playthrough.Catch.new()
	OS.add_logger(catch)
	EventBus.choices_requested.connect(_on_choices)
	while d.ending == &"" and WorldState.time < LIMIT:
		_act()
		d.step(DT)
	OS.remove_logger(catch)
	return {
		"profile": profile, "seed": seed_value, "ending": d.ending, "time": snappedf(WorldState.time, 0.1),
		"score": d.score(), "broken": d.broken, "progress": d.progress, "errors": catch.errors, "warnings": catch.warnings,
	}


func _on_choices(choice_id: StringName, _options: PackedStringArray) -> void:
	_choice = choice_id
	_choice_at = WorldState.time


func _act() -> void:
	if _choice != &"" and WorldState.time - _choice_at >= ANSWER_AFTER:
		var id := _choice
		_choice = &""
		var policy: Dictionary = ANSWERS[profile]
		if not policy.has(id):
			push_error("the %s bot has no answer for %s" % [profile, id])
		elif policy[id] >= 0:
			EventBus.choice_made.emit(id, policy[id])
	_use_prompts()
	var m: RoadMission = d.missions[d.mission_index] if d.mission_index < d.missions.size() else null
	if m is LiftMission and m.beat == &"walk":
		_walk_to(RoadLayout.BUS_STOP_S, RoadLayout.BUS_STOP)


## Uses each prompted object USE_AFTER seconds after its prompt appears, once.
func _use_prompts() -> void:
	var now := WorldState.time
	var due: Array[StringName] = []
	for id: StringName in WorldState.prompts:
		var text: String = WorldState.prompts[id]
		if text == "":
			_prompts.erase(id)
		elif not _prompts.has(id) or _prompts[id][0] != text:
			_prompts[id] = [text, now]
		elif now - _prompts[id][1] >= USE_AFTER:
			_prompts[id][1] = INF
			due.append(id)
	for id in due:  # after the loop: using one can change the prompts
		EventBus.object_interacted.emit(id)


func _walk_to(target_s: float, target: Vector3) -> void:
	var s := RoadLayout.closest_s(stage.position)
	if absf(target_s - s) <= WALK * DT:
		stage.position = target
	else:
		stage.position = RoadLayout.point(s + signf(target_s - s) * WALK * DT, VERGE)

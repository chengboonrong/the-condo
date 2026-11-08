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
## no rule to break, so all three play it alike: walk down to the stop, wait, get in (the couple wait 10 s). In mission 2
## the keeper follows the slow car all three times, the wobbly one overtakes at the third, and the breaker says nothing:
## Hafiz overtakes. In mission 3 none of them turns round, and all three say "Three." (the wobbly one asks why first):
## his own rules kill him, so no bot breaks them. In mission 4 all three lock the doors when something lands on the
## roof (5 s), never open the door and stay quiet for the voice; the keeper and the wobbly one stop Mei (the wobbly one
## says nothing), and the breaker says nothing, so she opens hers. In mission 5 all three get out and walk straight down
## the road to the light, never looking back and never standing still. The keeper and the wobbly one hold Mei's hand
## the first time; the breaker says nothing to both, so she looks twice. That brings the keeper home alive with all
## three (score 0), the wobbly one out with Mei (3) and the breaker to be caught with both of them (9). None of them
## dies: a bot that does is a bot that broke a rule it should keep, and the tests say so (`dead`).
##
## run(profile, seed) returns the ending, the time it took, the score, the rules broken, every beat, the rule that
## killed it (&"" if none), and the errors and warnings logged during the run.

const DT := 0.1
const WALK := 2.2  # m/s, along the road
const VERGE := 4.6  # metres left of the centreline: the walk down the verge to the stop
const LIMIT := 40.0 * 60.0  # sim seconds before we call it stuck
const ANSWER_AFTER := 1.0  # seconds after a choice opens
const USE_AFTER := 0.5  # seconds after a prompt appears
const BESIDE := 1.5  # metres to the car's left: where he stands up beside his door (as RoadMain stands him)
## Each profile's answer, by choice id; -1 stays silent. The rows come with their missions.
const ANSWERS := {
	"keeper": {&"overtake_1": 0, &"overtake_2": 0, &"overtake_3": 0, &"count": 0, &"answer_voice": 1, &"stop_mei": 0,
		&"mei_look_1": 0, &"mei_look_2": 0},
	"wobbly": {&"overtake_1": 0, &"overtake_2": 0, &"overtake_3": 2, &"count": 2, &"count_again": 0, &"answer_voice": 1,
		&"stop_mei": -1, &"mei_look_1": 0, &"mei_look_2": 0},
	"breaker": {&"overtake_1": -1, &"overtake_2": -1, &"overtake_3": -1, &"count": 0, &"answer_voice": -1, &"stop_mei": -1,
		&"mei_look_1": -1, &"mei_look_2": -1},
}
## The prompts each profile leaves alone, as "object id: prompt"; it uses every other one once, the lock included.
## Opening the door in the stall kills, so all three leave it.
const LEAVES := {
	"keeper": ["car_door_inside: Open the door"],
	"wobbly": ["car_door_inside: Open the door"],
	"breaker": ["car_door_inside: Open the door"],
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
	EventBus.road_cue.connect(_on_cue)
	while d.ending == &"" and WorldState.time < LIMIT:
		_act()
		d.step(DT)
	OS.remove_logger(catch)
	return {
		"profile": profile, "seed": seed_value, "ending": d.ending, "time": snappedf(WorldState.time, 0.1),
		"score": d.score(), "broken": d.broken, "progress": d.progress, "dead": d.dead, "errors": catch.errors,
		"warnings": catch.warnings,
	}


func _on_choices(choice_id: StringName, _options: PackedStringArray) -> void:
	_choice = choice_id
	_choice_at = WorldState.time


## He gets out of the car (mission 5), and stands up beside his door.
func _on_cue(cue: StringName) -> void:
	if cue == &"get_out":
		stage.position = RoadLayout.point(d.car_s - 0.5, d.lane + BESIDE)


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
	if m is LightMission and m.beat == &"walk":  # never looks back, never stands still
		_walk_to(d.light_s, RoadLayout.point(d.light_s, d.lane + BESIDE), d.lane + BESIDE)


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
			if not LEAVES[profile].has("%s: %s" % [id, text]):
				due.append(id)
	for id in due:  # after the loop: using one can change the prompts
		EventBus.object_interacted.emit(id)


## Walks along the road at WALK, `across` metres left of the centreline, until he is at `target`.
func _walk_to(target_s: float, target: Vector3, across := VERGE) -> void:
	var s := RoadLayout.closest_s(stage.position)
	if absf(target_s - s) <= WALK * DT:
		stage.position = target
	else:
		stage.position = RoadLayout.point(s + signf(target_s - s) * WALK * DT, across)

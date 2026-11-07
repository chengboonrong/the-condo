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
## In mission 3 the keeper never turns round and answers "Three.", the wobbly one asks why and then says "Three.", and
## the breaker turns to her once, after Bang Din has told him not to, and says "Four.".
## In mission 4 the keeper and the wobbly one never open the door, stay quiet for the voice and stop Mei; the breaker
## opens the door once and says nothing to either, so Mei opens hers.
## In mission 5 all three get out and walk straight down the road to the light. The keeper never looks back, the wobbly
## one looks back once and the breaker twice; the keeper and the wobbly one hold Mei's hand both times, and the breaker
## says nothing, so she looks. That brings the keeper home alive with all three (score 0), the wobbly one out with Mei
## (4) and the breaker to be caught with both of them (16).
##
## run(profile, seed) returns the ending, the time it took, the score, the rules broken, every beat, and the errors
## and warnings logged during the run.

const DT := 0.1
const WALK := 2.2  # m/s, along the road
const VERGE := 4.6  # metres left of the centreline: the walk down the verge to the stop
const LIMIT := 40.0 * 60.0  # sim seconds before we call it stuck
const ANSWER_AFTER := 1.0  # seconds after a choice opens
const USE_AFTER := 0.5  # seconds after a prompt appears
const TO_HER := -1.3  # radians: the breaker turns to his right, where the fourth sits...
const TURN_SECONDS := 1.0  # ...this long, once Bang Din has said the rule in mission 3 (CountMission.RECALL_AT)
const BESIDE := 1.5  # metres to the car's left: where he stands up beside his door (as RoadMain stands him)
const LOOK_SECONDS := 1.0  # each look back in mission 5, straight behind him
## Metres down the road from the car at which each profile looks back in mission 5.
const LOOKS := {"keeper": [], "wobbly": [30.0], "breaker": [30.0, 75.0]}
## Each profile's answer, by choice id; -1 stays silent. The rows come with their missions.
const ANSWERS := {
	"keeper": {&"overtake_1": 0, &"overtake_2": 0, &"overtake_3": 0, &"count": 0, &"answer_voice": 1, &"stop_mei": 0,
		&"mei_look_1": 0, &"mei_look_2": 0},
	"wobbly": {&"overtake_1": 0, &"overtake_2": 0, &"overtake_3": 2, &"count": 2, &"count_again": 0, &"answer_voice": 1,
		&"stop_mei": 0, &"mei_look_1": 0, &"mei_look_2": 0},
	"breaker": {&"overtake_1": -1, &"overtake_2": -1, &"overtake_3": -1, &"count": 1, &"answer_voice": -1, &"stop_mei": -1,
		&"mei_look_1": -1, &"mei_look_2": -1},
}
## The prompts each profile leaves alone, as "object id: prompt"; it uses every other one once.
const LEAVES := {
	"keeper": ["car_door_inside: Open the door"],
	"wobbly": ["car_door_inside: Open the door"],
	"breaker": [],
}

var profile: String
var d: RoadDirector
var stage: RoadStage
var _choice: StringName = &""
var _choice_at := 0.0
var _prompts := {}  # object_id -> [text, when it appeared (INF once used)]
var _out_s := NAN  # mission 5: where along the road he got out
var _looks: Array = []  # mission 5: the looks back still to come, in metres from the car
var _look_until := -1.0


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
		"score": d.score(), "broken": d.broken, "progress": d.progress, "errors": catch.errors, "warnings": catch.warnings,
	}


func _on_choices(choice_id: StringName, _options: PackedStringArray) -> void:
	_choice = choice_id
	_choice_at = WorldState.time


## He gets out of the car (mission 5), and stands up beside his door.
func _on_cue(cue: StringName) -> void:
	if cue == &"get_out":
		_out_s = d.car_s - 0.5
		stage.position = RoadLayout.point(_out_s, d.lane + BESIDE)
		_looks = LOOKS[profile].duplicate()


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
	if m is CountMission:
		var told: float = m.beat_t - CountMission.RECALL_AT  # seconds since the rule was said
		stage.view_yaw = TO_HER if profile == "breaker" and m.beat == &"quiet" and told >= 0.0 and told < TURN_SECONDS else 0.0
	if m is LightMission and m.beat == &"walk":
		var walked := RoadLayout.closest_s(stage.position) - _out_s
		if not _looks.is_empty() and walked >= _looks[0]:
			_looks.pop_front()
			_look_until = WorldState.time + LOOK_SECONDS
		stage.view_yaw = PI if WorldState.time < _look_until else 0.0
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

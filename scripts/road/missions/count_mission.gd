class_name CountMission
extends RoadMission
## Mission 3, the extra passenger. A fourth sits beside him in the rear right seat, seen only in the rear-view mirror;
## Mei and Hafiz take her for his friend. The rule is not to turn round to look at her, and not to count her. Turning to
## her shows her to him for a moment and breaks the rule, once at most. Mei asks how many of them there are: "Four."
## counts her, "Three." or saying nothing keeps it, and "Why you ask?" has her ask once more. Whatever he says, Mei
## counts three for herself, Hafiz brakes, and the seat in the mirror is empty, and wet.
##
## Beats: quiet (the mirror on, their talk, the rule), asked, asked_again (only after "Why you ask?"), empty.

const CRUISE_SPEED := 9.0
const START_S := 900.0  # where set_up_skipped puts the car: after the slow car, which ends anywhere from s 680 to 1650
const BRAKE_SPEED := 3.0  # Hafiz brakes when Mei sees the seat
const RULE := &"turned_round"
const OBJECTIVE := "Don't turn round. Don't count her."
const RECALL := "[Bang Din: \"If they say there's one more in the car, don't turn to look. And don't count her.\"]"
## Their talk once the mirror is on, from which he works out who sits beside him.
const FRIEND := [
	["Mei: \"Eh, your friend so quiet one. Shy ah?\"", 3.5, &"mei"],
	["Hafiz: \"Bro, your friend all wet. Kena rain ah?\"", 3.5, &"hafiz"],
]
const RECALL_AT := 9.0  # seconds into the quiet
const COUNT_AT := 22.0
const COUNT := [
	["Mei: \"Eh, how many of us ah? I want to buy drinks at the R&R.\"", 4.0, &"mei"],
	["Hafiz: \"Four people in this small car, also nobody talk.\"", 3.5, &"hafiz"],
]
const ASK_AT := 30.0  # once both have spoken
const AGAIN := "Mei: \"Just answer lah. How many?\""
const THREE := "Mei: \"Three? Then who's sitting—\""
const BRAKE_AT := 2.5  # seconds into the empty beat, as Mei breaks off
const EMPTY_SECONDS := 7.0  # the mirror shows the empty seat, then goes off (leave)

var _mirror := false  # mirror_on sent, and mirror_off not yet
var _seen := 0  # broken rules already looked at for a turn round
var _recalled := false
var _counted := false
var _braked := false


## Seated and cruising at s 900, with no slow car ahead.
func set_up_skipped() -> void:
	d.seated = true
	d.car_s = START_S
	d.car_speed = CRUISE_SPEED
	d.slow_gap = NAN
	d.drive(CRUISE_SPEED)


func begin() -> void:
	d.drive(CRUISE_SPEED)
	_mirror = true
	EventBus.road_cue.emit(&"mirror_on")
	d.watch_look(RULE, 2.2, 1.0, 0.4, 1, 1)
	_seen = d.broken.size()
	_recalled = false
	_counted = false
	_braked = false
	for line: Array in FRIEND:
		d.say(line[0], line[1], line[2])
	go(&"quiet")


func tick(_delta: float) -> bool:
	# The look rule breaks in the director's step, before this tick: turned round to her, he sees her.
	while _seen < d.broken.size():
		if d.broken[_seen]["rule"] == RULE:
			EventBus.road_cue.emit(&"fourth_glimpse")
		_seen += 1
	match beat:
		&"quiet":
			if not _recalled and beat_t >= RECALL_AT:
				_recalled = true
				d.say(RECALL, 5.0)
				WorldState.set_objective(OBJECTIVE)
			if not _counted and beat_t >= COUNT_AT:
				_counted = true
				for line: Array in COUNT:
					d.say(line[0], line[1], line[2])
			if beat_t >= ASK_AT:
				d.ask(&"count", PackedStringArray(["\"Three.\"", "\"Four.\"", "\"Why you ask?\""]), 6.0, PackedInt32Array([0, 2, -1]), &"counted_her")
				go(&"asked")
		&"asked":
			var answer := d.answer(&"count")
			if answer == 2:
				d.say(AGAIN, 3.0, &"mei")
				d.ask(&"count_again", PackedStringArray(["\"Three.\"", "\"Four.\""]), 5.0, PackedInt32Array([0, -1]), &"counted_her")
				go(&"asked_again")
			elif answer != RoadDirector.NONE:
				_empty()
		&"asked_again":
			if d.answer(&"count_again") != RoadDirector.NONE:
				_empty()
		&"empty":
			if not _braked and beat_t >= BRAKE_AT:
				_braked = true
				d.drive(BRAKE_SPEED)
				EventBus.road_cue.emit(&"brake")
				EventBus.road_cue.emit(&"fourth_gone")
			if beat_t >= EMPTY_SECONDS:
				d.drive(CRUISE_SPEED)
				return true  # leave() turns the mirror off and stops the look watch
	return false


## Done or skipped: no mirror, look watch or objective of this mission stays up.
func leave() -> void:
	_off()
	if d.look_rule == RULE:
		d.stop_look()
	if WorldState.objective == OBJECTIVE:
		WorldState.set_objective("")


## Mei counts for herself.
func _empty() -> void:
	d.say(THREE, 2.5, &"mei")
	go(&"empty")


func _off() -> void:
	if _mirror:
		_mirror = false
		EventBus.road_cue.emit(&"mirror_off")


class_name LiftMission
extends RoadMission
## Mission 1, the wait for a lift. The opening, in his thoughts on a black card; the walk down from the staff exit to
## the bus stop; the wait, which counts only while he is at the stop; and the couple's car, which stops for him. There
## is no rule to break yet: it teaches the road and puts him in the back seat.

const OPENING := [
	["[12:06 AM. The last staff bus went down the mountain at eleven.]", 4.0],
	["[Bang Din at the stall says the road down has rules. He only tells them after midnight.]", 5.0],
	["[You laughed. He didn't.]", 3.0],
]
const CARD_OFF := 13.0  # seconds into the opening; the card then fades for 1 s
const NEAR := 3.0  # metres from BUS_STOP that count as being at the stop
const LORRY_AT := 20.0  # seconds of waiting
const CAR_AT := 45.0
const CAR_FROM := -150.0  # where the couple's car comes down from, out of sight up the road
const CAR_SPEED := 9.0
const TALK_SECONDS := 9.0  # the small talk once he is in
const OBJECTIVE := "Walk down to the bus stop and wait for a lift."

var _waited := 0.0
var _talk_ends := INF
var _card_on := false


## The road's start: he is not in the car, and the car is up the road, standing.
func set_up_skipped() -> void:
	d.seated = false
	d.car_s = CAR_FROM
	d.car_speed = 0.0
	d.drive(0.0)


func begin() -> void:
	set_up_skipped()
	_waited = 0.0
	_talk_ends = INF
	_card_on = true
	EventBus.road_cue.emit(&"card_on")
	for line: Array in OPENING:
		d.say(line[0], line[1])
	go(&"opening")


func tick(delta: float) -> bool:
	match beat:
		&"opening":
			if beat_t >= CARD_OFF:
				_card_on = false
				EventBus.road_cue.emit(&"card_off")
				WorldState.set_objective(OBJECTIVE)
				go(&"walk")
		&"walk":
			if _at_stop():
				go(&"wait")
		&"wait":
			if _at_stop():
				_wait(delta)
			# The car stands at the stop once it has come, but only stops for him while he is there.
			if _waited >= CAR_AT and d.car_speed == 0.0 and _at_stop():
				EventBus.road_cue.emit(&"couple_stops")
				d.say("Mei: \"Eh, you going down ah? Jom, we got space.\"", 3.5, &"mei")
				WorldState.set_prompt(&"car_door", "Get in")
				go(&"get_in")
		&"get_in":
			return beat_t >= _talk_ends
	return false


func _wait(delta: float) -> void:
	var before := _waited
	_waited += delta
	if before < LORRY_AT and _waited >= LORRY_AT:
		EventBus.road_cue.emit(&"lorry_passes")
	if before < CAR_AT and _waited >= CAR_AT:
		d.car_s = CAR_FROM
		d.car_speed = CAR_SPEED
		d.drive(CAR_SPEED)
		d.stop_at(RoadLayout.BUS_STOP_S)


func _at_stop() -> bool:
	return d.stage.player_position().distance_to(RoadLayout.BUS_STOP) <= NEAR


## Done or skipped: none of the lift's card, prompt or objective stays up.
func leave() -> void:
	if _card_on:
		_card_on = false
		EventBus.road_cue.emit(&"card_off")
	WorldState.set_prompt(&"car_door", "")
	if WorldState.objective == OBJECTIVE:
		WorldState.set_objective("")


func interacted(object_id: StringName) -> void:
	if object_id != &"car_door" or beat != &"get_in" or d.seated:
		return
	d.seated = true
	EventBus.road_cue.emit(&"seated")
	WorldState.set_prompt(&"car_door", "")
	WorldState.set_objective("")
	d.say("Hafiz: \"Wah, so late still working ah? Kesian, bro.\"", 4.0, &"hafiz")
	d.say("Mei: \"We were at the theme park the whole day. So tired already.\"", 4.0, &"mei")
	_talk_ends = beat_t + TALK_SECONDS

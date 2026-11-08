class_name LightMission
extends RoadMission
## Mission 5, don't look back. The car is dead, and the light Mei saw is 150 m on, a bare bulb at a closed fruit stall.
## He gets out, and he and Mei walk down the road to it while something follows them, calling in Hafiz's voice. The
## rules: don't look back, and keep Mei from looking. 30 m short of the light the count of every rule broken on the
## road decides how it ends, once; that ending plays, and the road is over:
##   alive   Hafiz walks up to the bulb out of the fog below; once they are there the lorry he flagged down comes down
##           behind them, slowly past them, and pulls up past the stall: it will take the three of them down
##   saved   nobody is there but his ringing phone, and a lorry takes the two of them down
##   caught  the bulb dies there, Hafiz walks out of the fog ahead, she catches him and comes for the two of them
## The walk is over (walk_over) 4 m short of the light, or where the light dies. Every beat is timed here, never by the
## presentation: the bots play it with none.
##
## Beats: get_out, walk, then alive, saved or caught.

const DOOR := &"car_door_inside"
const RECALL := "[Bang Din: \"When it goes quiet, walk to the light. Whatever is behind you, don't look back.\"]"
const OBJECTIVE := "Walk to the light. Don't look back."
const KEEP_WALKING := "[Bang Din: \"And keep walking. Stop, and it catches up.\"]"
const VOICE := "[Behind you, Hafiz's voice: \"Mei! Wait for me!\"]"
const LOOKS := "[Mei looks back.]"  # seen or not: she is at his side, out of his view ahead
const ASKS := [[&"mei_look_1", 0.3], [&"mei_look_2", 0.65]]  # [choice, share of the way]: the voice, and Mei wants to look
const STILL_SECONDS := 5.0  # seconds in a row under MIN_PACE: she catches him
const MIN_PACE := 0.5  # m/s along the road; slower is standing still
const DECIDE := 30.0  # metres short of the light: the ending is decided
const THERE := 4.0  # metres short of it: they are there
## Seconds into each ending.
const ALIVE_HAFIZ := 19.5  # the lorry has pulled up (Endings: 18.7 s from 140 m, passing them at 3 m/s)
const ALIVE_CARD := ALIVE_HAFIZ + 4.5  # after his line
const SAVED_MEI := 2.5  # into the ringing
const SAVED_LORRY := 6.5
const SAVED_CARD := 12.0  # the lorry has pulled up behind them
const CARD := 5.5  # the card's caption, before the road is over
const CAUGHT_HAFIZ := 2.5  # after the light dies, he is heard in the fog ahead
const CAUGHT_CATCH := 6.0
## She comes for them once she has him down: the catch from behind them takes about 4 s, and the scream follows it.
const CAUGHT_COMES := 12.5
## The road is over: she has reached the camera and the card is up well before this (Endings), but the core never
## waits on the presentation.
const CAUGHT_END := 18.5

var _from_s := NAN  # where along the road he set off from
var _asking: StringName = &""  # the choice open now, or answered and not yet seen to
var _asked := 0  # of ASKS
var _decided: StringName = &""
var _last_s := NAN  # where along the road he was at the last step of the walk
var _still := 0.0  # seconds he has been under MIN_PACE, in a row


## Out of the car already, standing beside his door: the car dead on the long straight, the light 150 m on.
func set_up_skipped() -> void:
	d.seated = false
	d.car_s = StallMission.STOP_S
	d.car_speed = 0.0
	d.slow_gap = NAN
	d.light_s = StallMission.STOP_S + StallMission.LIGHT_AHEAD
	d.drive(0.0)


func begin() -> void:
	_from_s = NAN
	_last_s = NAN
	_asking = &""
	_asked = 0
	_decided = &""
	_still = 0.0
	d.say(RECALL, 6.0)  # seated, this is all that tells him the door is the way on now
	d.say(KEEP_WALKING, 4.0)
	WorldState.set_objective(OBJECTIVE)
	if d.seated:
		WorldState.set_prompt(DOOR, "Get out")
		go(&"get_out")
	else:
		_walk()


func tick(delta: float) -> bool:
	match beat:
		&"walk":
			_walking(delta)
		&"alive":
			if _passed(ALIVE_HAFIZ, delta):
				d.say("Hafiz: \"Eh! Found this uncle, he's going down. Jom.\"", 3.5, &"hafiz")
			if _passed(ALIVE_CARD, delta):
				_card("[The lorry takes the three of you down the mountain.]")
			return _over(ALIVE_CARD + CARD)
		&"saved":
			if _passed(SAVED_MEI, delta):
				d.say("Mei: \"That's his phone…\"", 3.0, &"mei")
			if _passed(SAVED_LORRY, delta):
				EventBus.road_cue.emit(&"lorry_stops")
			if _passed(SAVED_CARD, delta):
				_card("[The lorry takes the two of you down the mountain.]")
			return _over(SAVED_CARD + CARD)
		&"caught":
			if _passed(CAUGHT_HAFIZ, delta):
				d.say("Hafiz: \"Mei? Bro?\"", 2.5, &"hafiz")
			if _passed(CAUGHT_CATCH, delta):
				EventBus.road_cue.emit(&"her_catches_hafiz")
			if _passed(CAUGHT_COMES, delta):
				EventBus.road_cue.emit(&"her_comes")
			return _over(CAUGHT_END)
	return false


## He gets out: not a break, the way on.
func interacted(object_id: StringName) -> void:
	if object_id != DOOR or beat != &"get_out":
		return
	WorldState.set_prompt(DOOR, "")
	d.seated = false
	EventBus.road_cue.emit(&"get_out")
	_walk()


func leave() -> void:
	WorldState.set_prompt(DOOR, "")
	if WorldState.objective == OBJECTIVE:
		WorldState.set_objective("")
	d.stop_look()


func _walk() -> void:
	d.watch_look(&"looked_back", 1.9, 1.9, 0.25, 1, 1)
	EventBus.road_cue.emit(&"her_behind")
	go(&"walk")


## Along the road to the light: the voice behind them and Mei wanting to look, the ending decided 30 m short of it
## (once no choice is open), and the walk over there if she is to catch them, or 4 m short of it if not. Until it is
## decided, she comes in as long as he goes slower than MIN_PACE, and goes back as soon as he does not.
func _walking(delta: float) -> void:
	var s := RoadLayout.closest_s(d.stage.player_position())
	if is_nan(_from_s):
		_from_s = s
		_last_s = s
	if _decided == &"":
		_still = _still + delta if s - _last_s < MIN_PACE * delta else 0.0
		_last_s = s
		d.closing = clampf(_still / STILL_SECONDS, 0.0, 1.0)
		if _still >= STILL_SECONDS:
			d.die(&"stood_still")
			return
	if _asking != &"" and d.answer(_asking) != RoadDirector.NONE:
		if d.answer(_asking) != 0:
			EventBus.road_cue.emit(&"mei_looks")  # she looks back
			d.say(LOOKS, 2.5)
		_asking = &""
	if _asking == &"" and _asked < ASKS.size() and s - _from_s >= ASKS[_asked][1] * (d.light_s - _from_s):
		_asking = ASKS[_asked][0]
		_asked += 1
		d.say(VOICE, 4.0)
		d.ask(_asking, PackedStringArray(["\"Don't look. Hold my hand.\"", "\"Maybe it's him.\""]), RoadDirector.CHOICE_SECONDS, PackedInt32Array([0]), &"mei_looked", 2)
	if _decided == &"" and s >= d.light_s - DECIDE and d.pending == &"":
		_decided = d.outcome()
		d.stop_look()
		d.closing = 0.0
		match _decided:
			&"caught":
				EventBus.road_cue.emit(&"light_out")
				EventBus.road_cue.emit(&"walk_over")
				go(&"caught")
				return
			&"alive":
				EventBus.road_cue.emit(&"hafiz_at_stall")  # walking up to the bulb out of the fog as they come to it
	if _decided != &"" and s >= d.light_s - THERE:
		EventBus.road_cue.emit(&"walk_over")
		go(_decided)
		match _decided:
			&"alive":
				EventBus.road_cue.emit(&"lorry_flagged")  # the lorry he flagged down comes down behind them
			&"saved":
				EventBus.road_cue.emit(&"phone_rings")


## The black card, and under it how the road ends.
func _card(caption: String) -> void:
	EventBus.road_cue.emit(&"card_on")
	d.say(caption, CARD - 0.5)


## The ending is over `at` seconds in: the road ends as it was decided, whatever broke since.
func _over(at: float) -> bool:
	if beat_t < at:
		return false
	d.end(_decided)
	return true


## Whether `at` seconds into the beat passed in this step.
func _passed(at: float, delta: float) -> bool:
	return beat_t >= at and beat_t - delta < at

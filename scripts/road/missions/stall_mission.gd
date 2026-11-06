class_name StallMission
extends RoadMission
## Mission 4, the car dies. On the long straight the engine and the lights die and the car rolls to a stop; it won't
## start. Hafiz walks off down the road to find help, and he and Mei wait in the car. The insects stop, something lands
## on the roof, a voice outside sounds like Hafiz's, and Mei wants to open her door. The rules: don't open the door,
## and don't answer. When it goes quiet, a light shows far down the road, and Mei sees it.
##
## Beats: cruise (to the long straight), dying, cranking, hafiz_leaves, waiting, thumps, voice, mei, knocks, quiet,
## light.

const CRUISE_SPEED := 9.0
const STOP_S := 2000.0  # where the car stands, on the long straight; the next mission takes it up here
const DYING := 4.0  # seconds the car takes to roll to a stop, slowing evenly: it dies that far short of STOP_S
const LIGHT_AHEAD := 150.0  # metres on from the car to the light, and the stall the next mission walks to
const CRANKS := [1.0, 4.0]  # seconds into cranking: Hafiz tries the key twice
const CRANKING := 6.5
const LEAVE_AT := 8.0  # seconds into hafiz_leaves: his two lines are over, and he gets out
const WAIT := 20.0  # after he has gone, until the insects stop
const THUMPS := [2.0, 8.0, 13.0]  # seconds into thumps; she lands at the first
const THUMPING := 15.0
const ASK_VOICE := 1.5  # seconds into voice: the choice opens under the voice's words
const ASK_MEI := 1.0
const KNOCKS := [1.5, 2.3, 3.1]  # on Mei's window
const KNOCKING := 5.0
const QUIET := 10.0  # after the knocks, until the light
const LIGHT := 4.0  # Mei's line about the light, before the mission is over
const DOOR := &"car_door_inside"
const OBJECTIVE := "Stay in the car. Don't open the door. Don't answer."
const RECALL := "[Bang Din: \"If the car dies, stay inside. Don't open the door. Don't answer, even if it sounds like your own mother.\"]"
const VOICE := "[Outside, in Hafiz's voice: \"Bro! Open the door, I found help!\"]"
const MEI_LINE := "Mei: \"That's him! I'm opening—\""

var _rolling := 0.0  # m/s when it died
var _door := false  # the door's prompt is up: he can still open it
var _asked := false  # the current beat's choice has been asked


## Seated and cruising, down the road from where the extra passenger left them.
func set_up_skipped() -> void:
	d.seated = true
	d.car_s = 1800.0
	d.car_speed = CRUISE_SPEED
	d.slow_gap = NAN
	d.light_s = -1.0
	d.drive(CRUISE_SPEED)


func begin() -> void:
	_door = false
	d.light_s = -1.0
	d.drive(CRUISE_SPEED)
	go(&"cruise")


func tick(delta: float) -> bool:
	match beat:
		&"cruise":
			if d.car_s >= STOP_S - d.car_speed * DYING / 2.0:  # later (a skip): it dies where it is
				_rolling = d.car_speed
				EventBus.road_cue.emit(&"lights_dying")
				go(&"dying")
		&"dying":
			# It rolls to a stop, slowing evenly over DYING: gentler than the director's braking for stop_at.
			d.drive(_rolling * maxf(1.0 - beat_t / DYING, 0.0))
			if d.car_speed == 0.0:
				d.light_s = d.car_s + LIGHT_AHEAD
				go(&"cranking")
		&"cranking":
			for at: float in CRANKS:
				if _passed(at, delta):
					EventBus.road_cue.emit(&"crank")
			if beat_t >= CRANKING:
				d.say("Hafiz: \"Alamak, dead already. Lights also gone, how can?\"", 3.5, &"hafiz")
				d.say("Hafiz: \"No signal here. I jalan down a bit, find help. You two stay in the car, okay?\"", 4.0, &"hafiz")
				go(&"hafiz_leaves")
		&"hafiz_leaves":
			if beat_t >= LEAVE_AT:
				EventBus.road_cue.emit(&"hafiz_leaves")
				d.say(RECALL, 6.0)
				WorldState.set_objective(OBJECTIVE)
				WorldState.set_prompt(DOOR, "Open the door")
				_door = true
				go(&"waiting")
		&"waiting":
			if beat_t >= WAIT:
				EventBus.road_cue.emit(&"insects_stop")
				go(&"thumps")
		&"thumps":
			for i in THUMPS.size():
				if _passed(THUMPS[i], delta):
					EventBus.road_cue.emit(&"thump")
					if i == 0:
						EventBus.road_cue.emit(&"her_on_roof")
			if beat_t >= THUMPING:
				d.say(VOICE, 5.0)
				_asked = false
				go(&"voice")
		&"voice":
			if not _asked and beat_t >= ASK_VOICE:
				_asked = true
				d.ask(&"answer_voice", PackedStringArray(["\"Hafiz? That you?\"", "Stay quiet."]), 6.0, PackedInt32Array([1, -1]), &"answered")
			elif _asked and d.answer(&"answer_voice") != RoadDirector.NONE:
				EventBus.road_cue.emit(&"mei_reaches_door")  # she says it to her door, not to him
				d.say(MEI_LINE, 3.0, &"mei")
				_asked = false
				go(&"mei")
		&"mei":
			if not _asked and beat_t >= ASK_MEI:
				_asked = true
				d.ask(&"stop_mei", PackedStringArray(["\"Mei, don't. That's not him.\"", "\"Okay, open.\""]), 4.0, PackedInt32Array([0]), &"mei_opened")
			elif _asked and d.answer(&"stop_mei") != RoadDirector.NONE:
				if d.answer(&"stop_mei") != 0:  # she opens her door, and something slaps it shut
					EventBus.road_cue.emit(&"mei_door_cracked")
				go(&"knocks")
		&"knocks":
			for at: float in KNOCKS:
				if _passed(at, delta):
					EventBus.road_cue.emit(&"knock_window")
			if beat_t >= KNOCKING:
				go(&"quiet")
		&"quiet":
			if beat_t >= QUIET:
				_door = false  # the light is the way on now: opening the door is no longer a break
				WorldState.set_prompt(DOOR, "")
				EventBus.road_cue.emit(&"light_on")
				d.say("Mei: \"Eh, look. Got a light down there.\"", 3.5, &"mei")
				go(&"light")
		&"light":
			return beat_t >= LIGHT
	return false


## He opens his door, once: it opens a hand's width before something slaps it shut, and the prompt is gone.
func interacted(object_id: StringName) -> void:
	if object_id != DOOR or not _door:
		return
	_door = false
	WorldState.set_prompt(DOOR, "")
	d.break_rule(&"opened_door", 2)
	EventBus.road_cue.emit(&"door_cracked")


func leave() -> void:
	_door = false
	WorldState.set_prompt(DOOR, "")
	if WorldState.objective == OBJECTIVE:
		WorldState.set_objective("")


## Whether `at` seconds into the beat passed in this step.
func _passed(at: float, delta: float) -> bool:
	return beat_t >= at and beat_t - delta < at

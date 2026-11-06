class_name SlowCarMission
extends RoadMission
## Mission 2, the slow car. An old car with nobody at the wheel crawls down the road ahead, and Hafiz wants to potong
## it. Three times he asks, each time less patient; the rule is to follow it, however long. Answering the third option,
## or saying nothing, lets him overtake: the indicator, a rev, across into the other lane and back, and she shows. The
## same car is ahead again twenty seconds later, round a bend. After the third attempt it pulls into a lay-by and its
## lights go out.
##
## Beats: cruise, seen (coming up on it), then per attempt follow, urge, ask and either kept or (signal, pass, away).
## After the last attempt: lay_by, gone. Each ask opens about 40 s after the last: after an overtake and the same car
## ahead again, the next urge comes at once instead of after a long follow.

const CRUISE_SPEED := 9.0
const SLOW_SPEED := 4.0  # the slow car's, and then the couple's behind it
const PASS_SPEED := 14.0
const CRUISE_SECONDS := 8.0
const START_GAP := 60.0  # metres ahead of the couple's car when it first shows
const FOLLOW_GAP := 12.0  # the gap he settles at behind it
## Gap he starts slowing at: the distance it takes to lose the difference in speed at the car's ACCEL.
const BRAKE_GAP := (CRUISE_SPEED - SLOW_SPEED) * (CRUISE_SPEED - SLOW_SPEED) / (2.0 * RoadDirector.ACCEL)
const AHEAD_GAP := 40.0  # where it shows again, after an overtake
const CLEAR := 10.0  # metres past it, in the pass, before the car pulls back in
const SIGNAL_SECONDS := 2.5  # the indicator ticks this long before he pulls out
const AWAY_SECONDS := 20.0  # after the pass, until the same car is ahead again...
const BEND_WAIT := 10.0  # ...and no longer than this extra, waiting for a bend to hide it
const BEND_COS := 0.97  # the road turns by more than 14 degrees within AHEAD_GAP
const FOLLOW_SECONDS := 23.0  # behind it, until he speaks
const URGE_SECONDS := 5.0  # from what he says to the choice
const ASK_SECONDS := 6.0
const KEPT_SECONDS := 11.0  # his grumble, and the crawl on: the attempts come about 40 s apart
const ATTEMPTS := 3
const BEHIND := [&"seen", &"follow", &"urge", &"ask", &"kept", &"signal", &"lay_by"]  # beats spent closing up on it, or behind it
const KEEPS := [0, 1]  # the first two options keep the rule; the third, and silence, break it
## The lay-by, which SlowCar draws and the couple's car goes by: it slows to a stop over PULL_SECONDS, moving across to
## LAY_BY (half on the verge), and the couple's car edges over to clear it, then is back in its lane.
const LAY_BY := 3.3  # across, where the slow car parks
const PULL_SECONDS := 3.0
const PULL_DISTANCE := SLOW_SPEED * PULL_SECONDS / 2.0  # metres it goes on while it slows to a stop
const PASS_ACROSS := 2.4  # between the two cars' centres as the couple go by: their half widths, mirrors and all, and 0.4 m clear
const PASSING_LANE := LAY_BY - PASS_ACROSS
const PAST := PULL_DISTANCE + 6.0  # metres beyond where it began to pull in that end the mission: 6 m clear of it
const OBJECTIVE := "Keep him behind the slow car."
const RECALL := "[Bang Din: \"A slow car with nobody driving, you follow it. However long. Never potong.\"]"
const MEI_LINE := "Mei: \"Eh… isn't that the same car?\""
const GO_LINE := "Hafiz: \"Okay, hold tight! Potong!\""
const URGE := [
	"Hafiz: \"Aiyo, why so slow one? Can potong or not, bro?\"",
	"Hafiz: \"Alamak, still crawling lah. Boleh potong now?\"",
	"Hafiz: \"Weh, enough already! I potong now, okay?\"",
]
const OPTIONS := [
	["Don't, bro. Just follow it.", "Eh… got nobody driving that car.", "Ya lah, go."],
	["Follow it lah. No rush.", "Bang Din says never potong a car like that.", "Faster, go."],
	["Bro, please. Stay behind it.", "Look properly. Nobody at the wheel.", "Okay, last time. Go."],
]
const GRUMBLE := [
	"Hafiz: \"Okay lah, okay lah. Follow only.\"",
	"Hafiz: \"Aiyo… fine. Slow slow also reach.\"",
	"Hafiz: \"Fine, fine! But my petrol also not free, you know.\"",
]

var _attempt := 0  # 1 to ATTEMPTS once the slow car has been seen
var _lay_s := 0.0  # where the slow car pulled in


## Seated and cruising from the start, with nothing ahead.
func set_up_skipped() -> void:
	d.seated = true
	d.car_s = 0.0
	d.car_speed = CRUISE_SPEED
	d.slow_gap = NAN
	d.drive(CRUISE_SPEED)


func begin() -> void:
	_attempt = 0
	d.slow_gap = NAN
	d.drive(CRUISE_SPEED)
	go(&"cruise")


func tick(delta: float) -> bool:
	if not is_nan(d.slow_gap):
		d.slow_gap += (SLOW_SPEED - d.car_speed) * delta  # the slow car crawls on at its own speed
	if BEHIND.has(beat):
		_close_in()
	match beat:
		&"cruise":
			if beat_t >= CRUISE_SECONDS:
				d.slow_gap = START_GAP
				go(&"seen")
		&"seen":
			if is_equal_approx(d.car_speed, SLOW_SPEED):
				EventBus.road_cue.emit(&"slow_car_seen")
				WorldState.set_objective(OBJECTIVE)
				d.say(RECALL, 5.0)
				_next()
		&"follow":
			if beat_t >= FOLLOW_SECONDS:
				_urge()
		&"urge":
			if beat_t >= URGE_SECONDS:
				d.ask(_choice(), PackedStringArray(OPTIONS[_attempt - 1]), ASK_SECONDS, PackedInt32Array(KEEPS), &"overtook")
				go(&"ask")
		&"ask":
			var answer := d.answer(_choice())
			if answer != RoadDirector.NONE:  # it has closed: the rule is broken already if he didn't keep it
				if KEEPS.has(answer):
					d.say(GRUMBLE[_attempt - 1], 3.5, &"hafiz")
					go(&"kept")
				else:
					d.say(GO_LINE, 2.5, &"hafiz")
					EventBus.road_cue.emit(&"indicator")
					go(&"signal")
		&"kept":
			if beat_t >= KEPT_SECONDS:
				_next()
		&"signal":
			if beat_t >= SIGNAL_SECONDS:
				EventBus.road_cue.emit(&"overtake")
				d.lane_to(-RoadLayout.LANE)
				d.drive(PASS_SPEED)
				go(&"pass")
		&"pass":
			if d.slow_gap < -CLEAR:  # well past it: back into his own lane
				d.lane_to(RoadLayout.LANE)
				if is_equal_approx(d.lane, RoadLayout.LANE):
					EventBus.road_cue.emit(&"her_glimpse")
					d.drive(CRUISE_SPEED)
					go(&"away")
		&"away":
			if beat_t >= AWAY_SECONDS and (_round_a_bend() or beat_t >= AWAY_SECONDS + BEND_WAIT):
				d.slow_gap = AHEAD_GAP
				EventBus.road_cue.emit(&"slow_car_ahead")
				d.say(MEI_LINE, 3.5, &"mei")
				_next(true)
		&"lay_by":
			if is_equal_approx(d.car_speed, SLOW_SPEED):
				_lay_s = d.car_s + d.slow_gap
				d.slow_gap = NAN  # gone to the core; SlowCar pulls in and goes dark on the cue
				EventBus.road_cue.emit(&"slow_car_gone")
				d.drive(CRUISE_SPEED)
				d.lane_to(PASSING_LANE)
				go(&"gone")
		&"gone":
			if d.car_s > _lay_s + PAST:  # back in his own lane before the mission is over
				d.lane_to(RoadLayout.LANE)
				return is_equal_approx(d.lane, RoadLayout.LANE)
	return false


func leave() -> void:
	d.slow_gap = NAN
	if WorldState.objective == OBJECTIVE:
		WorldState.set_objective("")


func _choice() -> StringName:
	return StringName("overtake_%d" % _attempt)


## The next attempt, or the lay-by after the last. `at_once`: Hafiz speaks now, not after the long follow.
func _next(at_once := false) -> void:
	if _attempt >= ATTEMPTS:
		go(&"lay_by")
		return
	_attempt += 1
	if at_once:
		_urge()
	else:
		go(&"follow")


func _urge() -> void:
	d.say(URGE[_attempt - 1], 3.5, &"hafiz")
	go(&"urge")


## Closes up on the slow car at cruising speed, and slows in time to settle FOLLOW_GAP behind it.
func _close_in() -> void:
	d.drive(SLOW_SPEED if d.slow_gap <= FOLLOW_GAP + BRAKE_GAP else CRUISE_SPEED)


## The road turns away within AHEAD_GAP, so a car that shows there appears from round the bend.
func _round_a_bend() -> bool:
	return RoadLayout.tangent(d.car_s).dot(RoadLayout.tangent(d.car_s + AHEAD_GAP)) < BEND_COS

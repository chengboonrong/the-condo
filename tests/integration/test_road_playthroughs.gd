extends TestCase
## Three simulated players (bots, not people) play the road's core from the opening to an ending, without errors.

const SEEDS := [1147, 7, 2026]
const PROFILES := ["keeper", "wobbly", "breaker"]


func test_road_bots_reach_an_ending() -> bool:
	for seed_value: int in SEEDS:
		for profile: String in PROFILES:
			var r: Dictionary = RoadPlaythrough.run(profile, seed_value)
			var tag := "%s/%d" % [profile, seed_value]
			var last: Dictionary = r["progress"][-1] if not r["progress"].is_empty() else {}
			check(r["ending"] != &"", "%s reaches an ending (stuck at %s after %.0f s)" % [tag, last, r["time"]])
			eq(r["errors"], [], "%s logs no errors" % tag)
			eq(r["warnings"], [], "%s logs no warnings" % tag)
			print("    %s: %s at %.1f s, score %d" % [tag, r["ending"], r["time"], r["score"]])
	return true


func test_same_seed_same_road() -> bool:
	var a: Dictionary = RoadPlaythrough.run("keeper", 1147)
	var b: Dictionary = RoadPlaythrough.run("keeper", 1147)
	eq(b["time"], a["time"], "same ending time")
	eq(b["progress"], a["progress"], "same beats")
	eq(b["broken"], a["broken"], "same broken rules")
	return true


func test_each_bot_meets_its_ending() -> bool:
	var want := {"keeper": [&"alive", 0], "wobbly": [&"saved", 4], "breaker": [&"caught", 16]}
	for seed_value: int in SEEDS:
		for profile: String in PROFILES:
			var r: Dictionary = RoadPlaythrough.run(profile, seed_value)
			eq([r["ending"], r["score"]], want[profile], "%s/%d: its ending and score" % [profile, seed_value])
	return true


## The spec guessed 10 to 15 minutes for people. The bot answers in a second and walks straight at 2.2 m/s, so its time
## is a lower bound on theirs (about 9 minutes by the missions' beats), not a playtest.
func test_the_keeper_takes_seven_to_fifteen_minutes() -> bool:
	var r: Dictionary = RoadPlaythrough.run("keeper", 1147)
	check(r["time"] >= 420.0 and r["time"] <= 900.0, "the keeper bot reaches its ending in 7 to 15 sim minutes (%.1f s)" % r["time"])
	return true


## After the fourth passenger vanishes nobody speaks and Hafiz drives faster (CountMission.NOBODY): the drive to the long
## straight was 112 s of cruising at 9 m/s, and is about 70 s now (14 m/s, as fast as Mission 2's pass).
func test_the_drive_after_the_count_takes_about_70_seconds() -> bool:
	var r: Dictionary = RoadPlaythrough.run("keeper", 1147)
	var at := {}
	for g: Dictionary in r["progress"]:
		if g["mission"] == 3:  # the stall, the fourth mission
			at[g["beat"]] = g["t"]
	check(at.has(&"cruise") and at.has(&"dying"), "(the keeper cruises and then the car dies)")
	check(float(at.get(&"dying", 0.0)) - float(at.get(&"cruise", 0.0)) <= 74.0, "the cruise takes about 70 s or less (%.1f s)" % (float(at.get(&"dying", 0.0)) - float(at.get(&"cruise", 0.0))))
	return true

extends TestCase
## Phase 5 exit check: three simulated players (bots, not people) play the whole story on the
## simulation core. Each must reach an ending through all four acts without errors, and between them
## both endings must be reached. Seeds other than the default show the fail-safes don't rely on luck.

const SEEDS := [1147, 7, 2026]
## The explorer meets an armed visitor in these (it answered Rosnah, and the footsteps come to the door), and goes out to
## investigate: without the rules it dies of the front door, or of a light left on.
const VISIT_SEEDS := [3, 5]


func test_three_players_reach_both_endings() -> bool:
	var endings := {}
	for seed_value: int in SEEDS:
		for profile: String in ["explorer", "avoider", "passive"]:
			var r: Dictionary = Playthrough.run(profile, seed_value)
			var tag := "%s/%d" % [profile, seed_value]
			check(r["ending"] != &"", "%s reaches an ending (stuck at %s after %.0f s)" % [tag, r["progress"][-1]["beat"], r["time"]])
			var acts: Array = r["progress"].map(func(g: Dictionary) -> int: return g["act"])
			for act: int in [1, 2, 3, 4, 5]:
				check(acts.has(act), "%s goes through act %d" % [tag, act])
			eq(r["errors"], [], "%s logs no errors" % tag)
			eq(r["warnings"], [], "%s logs no warnings" % tag)
			eq(r["violations"], [], "%s never has the entity in the player's room" % tag)
			check(not r["events"].is_empty() and not r["decisions"].is_empty(), "%s: story and director events both fire" % tag)
			endings[r["ending"]] = endings.get(r["ending"], 0) + 1
			if seed_value == SEEDS[0]:
				print("    %s: %s at %.0f s, %d events, %d signs" % [tag, r["ending"], r["time"], r["events"].size(), r["signs"]])
	check(endings.has(&"downstairs") and endings.has(&"vacant"), "both endings are reached (%s)" % endings)
	return true


## Opening the front door in a visit or in act 3, a light on when the feet stop, or his back to the breathing in the
## doorway: all kill. The bots keep every rule, so none of them dies.
func test_no_flat_bot_dies() -> bool:
	for seed_value: int in SEEDS + VISIT_SEEDS:
		for profile: String in ["explorer", "avoider", "passive"]:
			var r: Dictionary = Playthrough.run(profile, seed_value)
			eq(r["dead"], &"", "%s/%d is alive at the end (%s)" % [profile, seed_value, r["ending"]])
	return true


func test_a_bot_that_meets_a_visit_keeps_its_rules() -> bool:
	for seed_value: int in VISIT_SEEDS:
		var r: Dictionary = Playthrough.run("explorer", seed_value)
		var visits: Array = r["events"].filter(func(e: Dictionary) -> bool: return e["id"] == &"visitor")
		check(not visits.is_empty(), "explorer/%d meets the visitor" % seed_value)
		eq(r["dead"], &"", "explorer/%d lives through it" % seed_value)
		check(r["ending"] != &"", "explorer/%d reaches an ending after it" % seed_value)
	return true


func test_same_seed_same_playthrough() -> bool:
	var a: Dictionary = Playthrough.run("avoider", 1147)
	var b: Dictionary = Playthrough.run("avoider", 1147)
	eq(b["time"], a["time"], "same ending time")
	eq(b["events"], a["events"], "same event sequence")
	return true

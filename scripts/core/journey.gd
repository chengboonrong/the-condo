extends Node
## Autoload. The road comes first and the flat follows: this carries the road's outcome into the flat and sends
## a restart back to the road. A death's Try again reloads the scene it happened in, and what that scene starts from
## waits here.

const ROAD_SCENE := "res://scenes/road.tscn"
const FLAT_SCENE := "res://scenes/main.tscn"
## The card's line under GAME OVER, by the cause of death.
const DEATHS := {
	&"turned_round": "[You turned round to look at her.]",
	&"counted_her": "[You counted her.]",
	&"answered": "[You answered it.]",
	&"opened_door": "[You opened the door.]",
	&"looked_back": "[You looked back.]",
	&"missed_lift": "[The car left without you.]",
	&"not_locked": "[You didn't lock the doors.]",
	&"stood_still": "[You stopped walking.]",
	&"front_door": "[You opened the front door.]",
	&"lights_on": "[Your light was on. It knew you were home.]",
	&"faced_away": "[You kept your back to it.]",
}

## How the road ended. &"" means the flat was opened directly, without the road.
var road_ending: StringName = &""
## Tests and tools set this to false to see the state change without the scene change.
var change_scenes := true
## Try again on the road: the mission to start at (0-based, as RoadDirector.mission_index) and the count kept for it.
## -1 is no retry: the road starts as usual. The road reads both and clears them.
var retry_mission := -1
var retry_broken: Array[Dictionary] = []
## Try again in the flat: what the flat restarts from. Empty is no retry.
var flat_retry: Dictionary = {}


## The scene changes deferred, on every call: change_scene_to_file takes the current scene out of the tree at
## once, and whoever calls these (the click that starts the road, the Restart button, Try again) is inside that
## scene with code still to run.
func arrive(ending: StringName) -> void:
	road_ending = ending
	if change_scenes:
		get_tree().change_scene_to_file.call_deferred(FLAT_SCENE)


func retry_road(mission: int, kept: Array[Dictionary]) -> void:
	retry_mission = mission
	retry_broken = kept.duplicate(true)
	if change_scenes:
		get_tree().change_scene_to_file.call_deferred(ROAD_SCENE)


## Keeps road_ending: the flat wakes as the road left it.
func retry_flat(snapshot: Dictionary) -> void:
	flat_retry = snapshot
	if change_scenes:
		get_tree().change_scene_to_file.call_deferred(FLAT_SCENE)


func restart() -> void:
	road_ending = &""
	retry_mission = -1
	retry_broken = []
	flat_retry = {}
	if change_scenes:
		get_tree().change_scene_to_file.call_deferred(ROAD_SCENE)

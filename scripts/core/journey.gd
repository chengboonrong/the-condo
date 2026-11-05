extends Node
## Autoload. The road comes first and the flat follows: this carries the road's outcome into the flat and sends
## a restart back to the road.

const ROAD_SCENE := "res://scenes/road.tscn"
const FLAT_SCENE := "res://scenes/main.tscn"

## How the road ended. &"" means the flat was opened directly, without the road.
var road_ending: StringName = &""
## Tests and tools set this to false to see the state change without the scene change.
var change_scenes := true


func arrive(ending: StringName) -> void:
	road_ending = ending
	if change_scenes:
		get_tree().change_scene_to_file(FLAT_SCENE)


func restart() -> void:
	road_ending = &""
	if change_scenes:
		get_tree().change_scene_to_file(ROAD_SCENE)

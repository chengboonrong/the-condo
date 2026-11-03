class_name Interactable
extends StaticBody3D
## Inspectable object or light switch. Story-driven objects leave text empty; StoryDirector reacts to the id.

@export var object_id: StringName
@export var prompt := "Inspect"
@export var title := ""
@export_multiline var text := ""
## When set, this is a light switch for that room.
@export var light_room: StringName = &""


func get_prompt() -> String:
	if light_room != &"":
		return "Turn light off" if WorldState.is_light_on(light_room) else "Turn light on"
	return WorldState.prompts.get(object_id, prompt)


func interact(_player: Node) -> void:
	if light_room != &"":
		WorldState.set_light(light_room, not WorldState.is_light_on(light_room))
		EventBus.sound_requested.emit(&"switch", global_position, -8.0)
	elif text != "":
		EventBus.inspect_requested.emit(title, text)
	EventBus.object_interacted.emit(object_id)

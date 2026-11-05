class_name Peephole
extends Interactable
## The front door's peephole. Looking through it shows the corridor from just outside the door; the HUD bends the
## view into the lens's fisheye. Nothing to look through while the door is open or still swinging (it hangs on the
## front door, so a moving door would carry the view with it). An empty prompt is how InteractionSystem skips an object.

var view: Camera3D  # outside the door, facing the corridor; ApartmentBuilder places it


func get_prompt() -> String:
	return "" if WorldState.is_door_open(&"main_door") or (get_parent() as Door).is_moving() else super()


func interact(player: Node) -> void:
	EventBus.peephole_requested.emit(view)
	super.interact(player)

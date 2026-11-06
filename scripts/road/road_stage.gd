class_name RoadStage
extends RefCounted
## Where he is and where he looks, for the road's core. Bots and tests set these directly; the game's stage reads them
## from the player.

## Radians: 0 faces the way the car (or the walk) goes, positive is to his left.
var view_yaw := 0.0
var position := Vector3.ZERO


## view_yaw wrapped to [-PI, PI]: a full turn of the mouse is facing forward again.
func relative_yaw() -> float:
	return wrapf(view_yaw, -PI, PI)


func player_position() -> Vector3:
	return position

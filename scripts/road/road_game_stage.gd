class_name RoadGameStage
extends RoadStage
## The road core's view of the real player: where he is, and how far he has turned his head, against the car while he
## rides in it and against the road while he walks, so a hairpin under a player who keeps still never reads as
## turning round.

var player: PlayerController
var car: CarRig


func _init(p: PlayerController, rig: CarRig) -> void:
	player = p
	car = rig


## The camera's forward against the car's (or the road's), positive to his left, in [-PI, PI]. Both are flattened
## onto the car's floor (or level ground), so the grade and his pitch don't change the answer.
func relative_yaw() -> float:
	var seated := player.is_seated()
	var up := car.global_basis.y if seated else Vector3.UP
	var ahead := car.global_basis.z if seated else RoadLayout.tangent(RoadLayout.closest_s(player.global_position))
	return ahead.slide(up).signed_angle_to((-player.camera.global_basis.z).slide(up), up)


func player_position() -> Vector3:
	return player.global_position

class_name GameStage
extends HorrorStage
## In-game answers for the simulation: the real player position, and visibility from the camera frustum
## plus a physics ray (walls and doors occlude).

var player: PlayerController


func _init(room_graph: RoomGraph, p: PlayerController) -> void:
	super(room_graph)
	player = p


func player_position() -> Vector3:
	return player.global_position


func player_yaw() -> float:
	return player.yaw


func player_speed() -> float:
	return player.horizontal_speed()


func phone_light_on() -> bool:
	return player.is_phone_light_on()


func forward() -> Vector3:
	var f := -player.global_basis.z
	f.y = 0
	return f.normalized()


func can_see(point: Vector3) -> bool:
	var cam := player.camera
	if not cam.is_position_in_frustum(point):
		return false
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, point, 1)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(point) < 0.3

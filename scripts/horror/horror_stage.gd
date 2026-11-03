class_name HorrorStage
extends RefCounted
## Answers "where is the player, and can they see this point?" for the simulation core.
## This base version reasons from rooms: a point is visible when its room is the player's room, or next to it
## through an opening or an open door. Simulated playthroughs use it; GameStage asks the real camera instead.

var graph: RoomGraph
var position := Vector3.ZERO
var yaw := 0.0
var speed := 0.0
var phone_light := false


func _init(room_graph: RoomGraph) -> void:
	graph = room_graph


func player_position() -> Vector3:
	return position


func player_yaw() -> float:
	return yaw


func player_speed() -> float:
	return speed


func phone_light_on() -> bool:
	return phone_light


## One BehaviorProfiler sample of what the player is doing now.
func sample() -> Dictionary:
	var room := WorldState.player_room
	var p := player_position()
	var near_door := false
	for c: Dictionary in graph.connections():
		if c["door"] != &"" and (c["a"] == room or c["b"] == room) and Vector2(p.x, p.z).distance_to(Vector2(c["pos"].x, c["pos"].z)) < 1.2:
			near_door = true
	return {
		"room": room, "yaw": player_yaw(), "speed": player_speed(), "near_door": near_door,
		"lit": WorldState.is_light_on(room), "phone_light": phone_light_on(),
	}


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func can_see(point: Vector3) -> bool:
	var room := ApartmentLayout.room_at(point, WorldState.variants)
	var here := WorldState.player_room
	if room == &"" or here == &"":
		return false
	if room == here:
		return true
	var c := graph.connection(here, room)
	return not c.is_empty() and (c["door"] == &"" or WorldState.is_door_open(c["door"]))


func any_visible(points: Array) -> bool:
	for p: Vector3 in points:
		if can_see(p):
			return true
	return false


## True when the point is more than 90° away from where the player faces.
func is_behind(point: Vector3) -> bool:
	var to := point - player_position()
	to.y = 0
	return to.length() > 0.01 and forward().dot(to.normalized()) < 0.0


func distance_to(point: Vector3) -> float:
	var p := player_position()
	return Vector2(p.x, p.z).distance_to(Vector2(point.x, point.z))

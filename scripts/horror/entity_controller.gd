class_name EntityController
extends RefCounted
## The neighbour, as a room and a state only (no body). Events read it: footsteps start from its room,
## and some events score higher while it observes or approaches. It never enters the player's room.
##
##   dormant ──act 2──▶ observing ──(act 3+, after OBSERVE_TIME)──▶ approaching ──(adjacent too long)──┐
##                         ▲                                            │ seen, or the player walks in  │
##                         └──────────── RETREAT_TIME ◀── retreating ◀──┴───────────────────────────────┘

const OBSERVE_TIME := 25.0
const MOVE_TIME := 12.0
const HOLD_TIME := 24.0  # how long it waits next to the player's room before backing off
const RETREAT_TIME := 20.0
const WATCH_DISTANCE := 2

var graph: RoomGraph
var rng: RandomNumberGenerator
var state_time := 0.0
var _move_left := 0.0


func _init(room_graph: RoomGraph, sim_rng: RandomNumberGenerator) -> void:
	graph = room_graph
	rng = sim_rng


func state() -> StringName:
	return WorldState.entity_state


func room() -> StringName:
	return WorldState.entity_room


func tick(delta: float) -> void:
	state_time += delta
	var here := WorldState.player_room
	if WorldState.act < WorldState.Act.DISTURBANCE or WorldState.act >= WorldState.Act.ENDED or here == &"":
		_become(&"", &"dormant")
		return
	if state() == &"dormant":
		_become(_watch_room(), &"observing")
		return
	if room() == here or not graph.rooms().has(room()):
		notice()  # the player walked in, or its room shifted away
		return
	match state():
		&"observing":
			if graph.distance(here, room()) > WATCH_DISTANCE + 1:
				_become(_watch_room(), &"observing")  # keep up with the player
			elif state_time >= OBSERVE_TIME and WorldState.act >= WorldState.Act.IMPOSSIBLE:
				_become(room(), &"approaching")
				_move_left = MOVE_TIME
		&"approaching":
			_move_left -= delta
			if graph.distance(here, room()) <= 1:
				if state_time >= HOLD_TIME:
					notice()
			elif _move_left <= 0.0:
				_move_left = MOVE_TIME
				var path := graph.path(room(), here)
				if path.size() > 2:
					WorldState.set_entity(path[1], &"approaching")  # one room closer, never into the player's room
					state_time = 0.0
		&"retreating":
			if state_time >= RETREAT_TIME:
				_become(_watch_room(), &"observing")


## The player saw it (silhouette) or walked into its room: it backs off as far as it can.
func notice() -> void:
	if state() == &"dormant":
		return
	var here := WorldState.player_room
	var best := room()
	var best_d := -1
	for r: StringName in graph.rooms():
		var d := graph.distance(here, r)
		if d < 999 and d > best_d:
			best = r
			best_d = d
	_become(best, &"retreating")


## A room WATCH_DISTANCE away from the player (or the nearest it can get), preferring rooms they avoid.
func _watch_room() -> StringName:
	var here := WorldState.player_room
	for steps in range(WATCH_DISTANCE, 0, -1):
		var options: Array = []
		for r: StringName in graph.rooms():
			if graph.distance(here, r) == steps:
				options.append([r, 1.0])
		if not options.is_empty():
			return HorrorEvent.pick_weighted(rng, options)
	return here


func _become(room_id: StringName, new_state: StringName) -> void:
	if new_state != state():
		state_time = 0.0
	WorldState.set_entity(room_id, new_state)

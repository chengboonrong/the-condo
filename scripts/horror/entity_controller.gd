class_name EntityController
extends RefCounted
## The neighbour, as a room and a state only (no body). Events read it: footsteps start from its room,
## and some events score higher while it observes or approaches. It never enters the player's room.
## From act 3 it comes for him: next to his room it gives itself away with a rattle from that doorway, and he has
## FACE_SECONDS to turn and look at the doorway. If he doesn't, it kills him (killed).
##
##   dormant ──act 2──▶ observing ──(act 3+, after OBSERVE_TIME)──▶ approaching ──(his back to it FACE_SECONDS)──▶ killed
##                         ▲                                            │ he looks at the doorway, or walks in │
##                         └──────────── RETREAT_TIME ◀── retreating ◀──┴──────────────────────────────────────┘

## He kept his back to it (HorrorRuntime.die answers).
signal killed(cause: StringName)

const OBSERVE_TIME := 25.0
const MOVE_TIME := 12.0
const FACE_SECONDS := 4.0  # how long he has, once it breathes in the doorway, to turn and look at it
const RETREAT_TIME := 20.0
const WATCH_DISTANCE := 2
const RATTLE_DB := 0.0
const WARN := "[Something is breathing in the doorway behind you. Face it.]"  # the first time it comes
const CAPTION := "[Breathing in the doorway]"  # every time after

var graph: RoomGraph
var rng: RandomNumberGenerator
var stage: HorrorStage  # where he looks (HorrorRuntime gives it)
var state_time := 0.0
var _move_left := 0.0
var _face_clock := -1.0  # seconds since it breathed in `_doorway`; -1 while it is not next to him
var _doorway := Vector3.ZERO
var _warned := false


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
				_face_the_sound(here, delta)
			else:
				_face_clock = -1.0  # he got away: it breathes again, with a fresh clock, when it is next to him again
				if _move_left <= 0.0:
					_move_left = MOVE_TIME
					var path := graph.path(room(), here)
					if path.size() > 2:
						WorldState.set_entity(path[1], &"approaching")  # one room closer, never into the player's room
		&"retreating":
			if state_time >= RETREAT_TIME:
				_become(_watch_room(), &"observing")


## Next to his room: it breathes in the doorway between them, then he looks at it (it backs off) or FACE_SECONDS pass (killed).
## The first breath says what to do (WARN); later ones are the sound's caption. A retry makes a new controller, so it warns again.
func _face_the_sound(here: StringName, delta: float) -> void:
	var door: Vector3 = graph.connection(room(), here)["pos"]
	if _face_clock < 0.0 or door != _doorway:
		_doorway = door
		_face_clock = 0.0
		EventBus.sound_requested.emit(&"rattle", door + Vector3.UP * 1.5, RATTLE_DB)
		if _warned:
			EventBus.subtitle_requested.emit(CAPTION, 3.0)
		else:
			_warned = true
			EventBus.line_requested.emit(WARN, 4.0)
	else:
		_face_clock += delta
	if not stage.is_behind(door):
		notice()
	elif _face_clock >= FACE_SECONDS:
		killed.emit(&"faced_away")


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
		_face_clock = -1.0
	WorldState.set_entity(room_id, new_state)

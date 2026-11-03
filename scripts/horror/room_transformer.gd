class_name RoomTransformer
extends RefCounted
## Swaps an area to one of its predefined variants, only after five checks pass:
##   1. the player is outside every room the swap changes;
##   2. no probe point of the area is visible;
##   3. every changed room that still exists is reachable from the player;
##   4. the player stands in a room that still exists and still leads to the corridor (the way out);
##   5. every room the story currently needs (required_rooms) stays reachable.
## check() returns "" or the first failing reason; apply() checks again and then sets the variant
## (which also resets the clock to 11:47 PM).

const EXIT_ROOM := &"corridor"

var graph: RoomGraph
var stage: HorrorStage
## Rooms holding objects the current objective needs. The story sets this.
var required_rooms: Array[StringName] = []


func _init(room_graph: RoomGraph, horror_stage: HorrorStage) -> void:
	graph = room_graph
	stage = horror_stage


## Every room whose shape or existence depends on the area's variant.
static func affected_rooms(area_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(ApartmentLayout.VARIANT_AREAS[area_id]["rooms"])
	for room_id: StringName in ApartmentLayout.ROOMS:
		var room: Dictionary = ApartmentLayout.ROOMS[room_id]
		var depends: bool = room.get("requires", {}).has(area_id) or (room_id == area_id and room.has("long_rects"))
		if depends and not out.has(room_id):
			out.append(room_id)
	return out


func check(area_id: StringName, variant: StringName) -> String:
	var area: Dictionary = ApartmentLayout.VARIANT_AREAS.get(area_id, {})
	if area.is_empty():
		return "unknown_area"
	if not (area["variants"] as Array).has(variant):
		return "unknown_variant"
	if WorldState.get_variant(area_id) == variant:
		return "already_%s" % variant
	var here := WorldState.player_room
	var affected := affected_rooms(area_id)
	# 1. outside the affected area (by room, and by position in case the room lookup lags a frame)
	var pos_room := ApartmentLayout.room_at(stage.player_position(), WorldState.variants)
	if affected.has(here) or affected.has(pos_room):
		return "player_inside"
	# 2. not visible
	for probe: Vector3 in area["probes"]:
		if stage.can_see(probe):
			return "visible"
	var after := WorldState.variants.duplicate()
	after[area_id] = variant
	# 4. not trapped: the player's spot still exists and still leads out
	var spot := ApartmentLayout.room_at(stage.player_position(), after)
	if spot == &"" or not graph.is_reachable(spot, EXIT_ROOM, after):
		return "would_trap_player"
	# 3. the destination stays reachable
	for r: StringName in affected:
		if not ApartmentLayout.room_rects(r, after).is_empty() and not graph.is_reachable(spot, r, after):
			return "unreachable:%s" % r
	# 5. story objects stay reachable
	for r: StringName in required_rooms:
		if not graph.is_reachable(spot, r, after):
			return "story_blocked:%s" % r
	return ""


func apply(area_id: StringName, variant: StringName) -> String:
	var reason := check(area_id, variant)
	if reason == "":
		WorldState.set_variant(area_id, variant)
	return reason

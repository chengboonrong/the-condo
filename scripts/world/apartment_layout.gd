class_name ApartmentLayout
## Single source of truth for the condo: rooms, walls, doors, anchors and props.
## Units are metres. x = east, z = south, y = up. Rects are Rect2(x, z, width, depth).
## Unit B-12-07, Residensi Seri Kenanga (fictional). Corridor runs along the south side.

const CEILING := 2.7
const DOOR_HEIGHT := 2.1
const WALL_T := 0.15

# A room may have several rects; "requires" lists variant conditions for the rect to exist.
const ROOMS := {
	&"corridor": {"name": "Corridor", "rects": [Rect2(-4, 10, 23, 2.5)]},
	&"entrance": {"name": "Entrance", "rects": [Rect2(0, 7, 3, 3)]},
	&"living": {"name": "Living room", "rects": [Rect2(3, 4, 7, 6)]},
	&"kitchen": {"name": "Kitchen", "rects": [Rect2(0, 2.5, 3, 4.5)]},
	&"hallway": {"name": "Hallway", "rects": [Rect2(3, 2.5, 7, 1.5)]},
	&"bathroom": {"name": "Bathroom", "rects": [Rect2(3, -2, 2.5, 4.5)]},
	&"bedroom": {"name": "Bedroom", "rects": [Rect2(5.5, -2, 4.5, 4.5)]},
	&"gap": {
		"name": "???",
		"requires": {&"bedroom": &"door"},
		"rects": [Rect2(7, -14, 1.4, 12)],
		"long_rects": [Rect2(7, -14, 1.4, 6), Rect2(-2, -9.4, 10.4, 1.4), Rect2(-2, -9.4, 1.4, 7.4), Rect2(-2, -3.4, 10.4, 1.4)],
	},
	&"mirror_room": {"name": "B-11-07", "requires": {&"bedroom": &"door"}, "rects": [Rect2(5.5, -18.5, 4.5, 4.5)]},
}

# Rooms the player is told about; the gap and mirror room only exist after the reveal.
const APARTMENT_ROOMS: Array[StringName] = [&"entrance", &"living", &"kitchen", &"hallway", &"bathroom", &"bedroom"]

const CONNECTIONS := [
	{"a": &"corridor", "b": &"entrance", "door": &"main_door", "pos": Vector3(1.5, 0, 10)},
	{"a": &"entrance", "b": &"living", "door": &"", "pos": Vector3(3, 0, 8.5)},
	{"a": &"entrance", "b": &"kitchen", "door": &"kitchen_door", "pos": Vector3(1.45, 0, 7)},
	{"a": &"living", "b": &"hallway", "door": &"", "pos": Vector3(4, 0, 4)},
	{"a": &"hallway", "b": &"bathroom", "door": &"bathroom_door", "pos": Vector3(4.3, 0, 2.5)},
	{"a": &"hallway", "b": &"bedroom", "door": &"bedroom_door", "pos": Vector3(6.75, 0, 2.5)},
	{"a": &"bedroom", "b": &"gap", "door": &"gap_door", "pos": Vector3(7.7, 0, -2), "requires": {&"bedroom": &"door"}},
	{"a": &"gap", "b": &"mirror_room", "door": &"mirror_door", "pos": Vector3(7.7, 0, -14), "requires": {&"bedroom": &"door"}},
]

# Doors: axis "x" = panel runs along x (wall at fixed z). swing = +1 opens towards +z/+x side.
const DOORS := {
	&"main_door": {"hinge": Vector3(1.0, 0, 10), "axis": "x", "width": 1.0, "swing": -1, "color": Color(0.36, 0.25, 0.18)},
	&"kitchen_door": {"hinge": Vector3(1.0, 0, 7), "axis": "x", "width": 0.9, "swing": -1, "color": Color(0.75, 0.72, 0.66)},
	&"bathroom_door": {"hinge": Vector3(3.9, 0, 2.5), "axis": "x", "width": 0.8, "swing": -1, "color": Color(0.75, 0.72, 0.66)},
	&"bedroom_door": {"hinge": Vector3(6.3, 0, 2.5), "axis": "x", "width": 0.9, "swing": -1, "color": Color(0.75, 0.72, 0.66)},
	&"gap_door": {"hinge": Vector3(7.25, 0, -2), "axis": "x", "width": 0.9, "swing": 1, "color": Color(0.75, 0.72, 0.66), "requires": {&"bedroom": &"door"}},
	&"mirror_door": {"hinge": Vector3(7.25, 0, -14), "axis": "x", "width": 0.9, "swing": -1, "color": Color(0.32, 0.3, 0.28), "requires": {&"bedroom": &"door"}},
}

# Wall segments. "x" walls run along x at fixed z; "z" walls run along z at fixed x.
# Openings: [from, to, bottom, top] along the wall axis. "requires" ties a wall to a variant.
const WALLS := [
	{"axis": "x", "at": -2.0, "from": 3.0, "to": 5.5},
	{"axis": "x", "at": -2.0, "from": 5.5, "to": 10.0, "openings": [[7.0, 8.6, 0.9, 2.1]], "window": true, "requires": {&"bedroom": &"default"}},
	{"axis": "x", "at": -2.0, "from": 5.5, "to": 10.0, "openings": [[7.25, 8.15, 0.0, DOOR_HEIGHT]], "requires": {&"bedroom": &"door"}},
	{"axis": "x", "at": 2.5, "from": 0.0, "to": 3.0},
	{"axis": "x", "at": 2.5, "from": 3.0, "to": 10.0, "openings": [[3.9, 4.7, 0.0, DOOR_HEIGHT], [6.3, 7.2, 0.0, DOOR_HEIGHT]]},
	{"axis": "x", "at": 4.0, "from": 3.0, "to": 10.0, "openings": [[3.3, 4.7, 0.0, 2.3]]},
	{"axis": "x", "at": 7.0, "from": 0.0, "to": 3.0, "openings": [[1.0, 1.9, 0.0, DOOR_HEIGHT]]},
	{"axis": "x", "at": 10.0, "from": -4.0, "to": 19.0, "openings": [[1.0, 2.0, 0.0, DOOR_HEIGHT]]},
	{"axis": "x", "at": 12.5, "from": -4.0, "to": 19.0, "openings": [[-4.0, 19.0, 1.1, 2.8]], "window": false, "parapet": true},
	{"axis": "z", "at": -4.0, "from": 10.0, "to": 12.5},
	{"axis": "z", "at": 19.0, "from": 10.0, "to": 12.5},
	{"axis": "z", "at": 0.0, "from": 2.5, "to": 10.0},
	{"axis": "z", "at": 3.0, "from": -2.0, "to": 10.0, "openings": [[7.4, 9.6, 0.0, 2.3]]},
	{"axis": "z", "at": 5.5, "from": -2.0, "to": 2.5},
	{"axis": "z", "at": 10.0, "from": -2.0, "to": 10.0, "openings": [[5.5, 8.5, 0.3, 2.3]], "window": true},
	# The gap: straight (default) or long (after the mirror room door closes).
	{"axis": "z", "at": 7.0, "from": -14.0, "to": -2.0, "requires": {&"bedroom": &"door", &"gap": &"default"}},
	{"axis": "z", "at": 8.4, "from": -14.0, "to": -2.0, "requires": {&"bedroom": &"door", &"gap": &"default"}},
	{"axis": "z", "at": 8.4, "from": -14.0, "to": -8.0, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "z", "at": 7.0, "from": -14.0, "to": -9.4, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "x", "at": -8.0, "from": -0.6, "to": 8.4, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "x", "at": -9.4, "from": -2.0, "to": 7.0, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "z", "at": -2.0, "from": -9.4, "to": -2.0, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "z", "at": -0.6, "from": -8.0, "to": -3.4, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "x", "at": -3.4, "from": -0.6, "to": 8.4, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "z", "at": 8.4, "from": -3.4, "to": -2.0, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	{"axis": "x", "at": -2.0, "from": -2.0, "to": 3.0, "requires": {&"bedroom": &"door", &"gap": &"long"}},
	# Mirror room (B-11-07).
	{"axis": "x", "at": -14.0, "from": 5.5, "to": 10.0, "openings": [[7.25, 8.15, 0.0, DOOR_HEIGHT]], "requires": {&"bedroom": &"door"}},
	{"axis": "x", "at": -18.5, "from": 5.5, "to": 10.0, "requires": {&"bedroom": &"door"}},
	{"axis": "z", "at": 5.5, "from": -18.5, "to": -14.0, "requires": {&"bedroom": &"door"}},
	{"axis": "z", "at": 10.0, "from": -18.5, "to": -14.0, "requires": {&"bedroom": &"door"}},
]

# Ceiling lights per room; switch = wall switch position (null = no switch).
const LIGHTS := {
	&"corridor": {"pos": [Vector3(0, 2.6, 11.2), Vector3(7, 2.6, 11.2), Vector3(14, 2.6, 11.2)], "color": Color(0.85, 0.95, 1.0), "energy": 0.9, "range": 8.0, "on": true, "switch": null},
	&"entrance": {"pos": [Vector3(1.5, 2.6, 8.5)], "color": Color(1.0, 0.85, 0.65), "energy": 0.8, "range": 5.0, "on": false, "switch": Vector3(0.08, 1.2, 9.4)},
	&"living": {"pos": [Vector3(6.5, 2.6, 7)], "color": Color(1.0, 0.82, 0.6), "energy": 1.3, "range": 9.0, "on": true, "switch": Vector3(3.08, 1.2, 9.8)},
	&"kitchen": {"pos": [Vector3(1.5, 2.6, 4.7)], "color": Color(0.9, 0.97, 1.0), "energy": 1.0, "range": 6.0, "on": false, "switch": Vector3(2.1, 1.2, 6.92)},
	&"hallway": {"pos": [Vector3(6.5, 2.6, 3.25)], "color": Color(1.0, 0.85, 0.65), "energy": 0.7, "range": 6.0, "on": false, "switch": Vector3(3.08, 1.2, 3.2)},
	&"bathroom": {"pos": [Vector3(4.25, 2.6, 0.2)], "color": Color(0.92, 0.97, 1.0), "energy": 0.9, "range": 5.0, "on": false, "switch": Vector3(3.7, 1.2, 2.58)},
	&"bedroom": {"pos": [Vector3(7.75, 2.6, 0.25)], "color": Color(1.0, 0.8, 0.6), "energy": 1.0, "range": 7.0, "on": false, "switch": Vector3(7.45, 1.2, 2.42)},
	&"gap": {"pos": [Vector3(7.7, 2.5, -5), Vector3(7.7, 2.5, -11), Vector3(3, 2.5, -8.7), Vector3(-1.3, 2.5, -5.5), Vector3(4, 2.5, -2.7)], "color": Color(1.0, 0.7, 0.45), "energy": 0.5, "range": 5.0, "on": true, "switch": null},
	&"mirror_room": {"pos": [Vector3(7.75, 2.6, -16.25)], "color": Color(0.7, 0.75, 0.9), "energy": 0.35, "range": 6.0, "on": true, "switch": null},
}

# Sound and sighting anchors used by horror events.
const ANCHORS := {
	&"knock_bedroom_north": {"room": &"bedroom", "pos": Vector3(6.6, 1.3, -1.9), "kind": "knock"},
	&"knock_bedroom_west": {"room": &"bedroom", "pos": Vector3(5.6, 1.2, 1.0), "kind": "knock"},
	&"knock_bathroom": {"room": &"bathroom", "pos": Vector3(3.1, 1.0, -1.0), "kind": "knock"},
	&"knock_kitchen": {"room": &"kitchen", "pos": Vector3(0.1, 1.2, 4.5), "kind": "knock"},
	&"knock_living_floor": {"room": &"living", "pos": Vector3(6.0, 0.02, 6.0), "kind": "knock"},
	&"knock_living_east": {"room": &"living", "pos": Vector3(9.9, 1.1, 9.4), "kind": "knock"},
	&"knock_hallway": {"room": &"hallway", "pos": Vector3(9.9, 1.3, 3.25), "kind": "knock"},
	&"knock_entrance_door": {"room": &"entrance", "pos": Vector3(1.5, 1.3, 10.05), "kind": "knock"},
	&"knock_mirror": {"room": &"mirror_room", "pos": Vector3(7.75, 1.3, -18.4), "kind": "knock"},
	&"phone_intercom": {"room": &"entrance", "pos": Vector3(0.1, 1.45, 8.6), "kind": "phone"},
	&"phone_mirror": {"room": &"mirror_room", "pos": Vector3(5.6, 1.45, -14.6), "kind": "phone"},
	&"sil_corridor_west": {"room": &"corridor", "pos": Vector3(-3.3, 0, 11.3), "kind": "silhouette"},
	&"sil_hallway_east": {"room": &"hallway", "pos": Vector3(9.6, 0, 3.25), "kind": "silhouette"},
	&"sil_kitchen": {"room": &"kitchen", "pos": Vector3(0.6, 0, 3.0), "kind": "silhouette"},
	&"sil_living_balcony": {"room": &"living", "pos": Vector3(9.6, 0, 5.0), "kind": "silhouette"},
	&"sil_gap": {"room": &"gap", "pos": Vector3(7.7, 0, -12.5), "kind": "silhouette"},
}

# Areas that can change while unobserved. probes = points that must be unseen for a swap.
const VARIANT_AREAS := {
	&"bedroom": {"rooms": [&"bedroom"], "variants": [&"default", &"door"], "probes": [Vector3(7.7, 1.2, -1.95), Vector3(6.0, 1.2, -1.9), Vector3(9.5, 1.2, -1.9)]},
	&"gap": {"rooms": [&"gap"], "variants": [&"default", &"long"], "probes": [Vector3(7.7, 1.2, -8.6), Vector3(7.7, 1.2, -5.0), Vector3(7.7, 1.2, -2.6)]},
	&"entrance_shoes": {"rooms": [&"entrance"], "variants": [&"default", &"moved"], "probes": [Vector3(0.4, 0.3, 8.0)]},
	&"living_chair": {"rooms": [&"living"], "variants": [&"default", &"turned"], "probes": [Vector3(4.3, 0.6, 5.2)]},
	&"bathroom_tap": {"rooms": [&"bathroom"], "variants": [&"default", &"running"], "probes": [Vector3(3.35, 0.9, 1.0)]},
}

const SPAWN := Vector3(6.5, 0.0, 8.4)
const SPAWN_YAW := 0.0
const LIFT_POS := Vector3(18.5, 0, 11.25)


static func requires_met(cond: Dictionary, variants: Dictionary) -> bool:
	for area: StringName in cond:
		if variants.get(area, &"default") != cond[area]:
			return false
	return true


static func room_rects(room_id: StringName, variants: Dictionary) -> Array:
	var room: Dictionary = ROOMS[room_id]
	if not requires_met(room.get("requires", {}), variants):
		return []
	if room.has("long_rects") and variants.get(room_id, &"default") == &"long":
		return room["long_rects"]
	return room["rects"]


static func room_center(room_id: StringName, variants: Dictionary = {}) -> Vector3:
	var rects := room_rects(room_id, variants)
	if rects.is_empty():
		rects = ROOMS[room_id]["rects"]
	var r: Rect2 = rects[0]
	var c := r.get_center()
	return Vector3(c.x, 0, c.y)


static func room_at(pos: Vector3, variants: Dictionary) -> StringName:
	var p := Vector2(pos.x, pos.z)
	for room_id: StringName in ROOMS:
		for r: Rect2 in room_rects(room_id, variants):
			if r.has_point(p):
				return room_id
	return &""


const INITIAL_OPEN_DOORS: Array[StringName] = [&"kitchen_door", &"bedroom_door", &"mirror_door"]


## Puts lights and doors in their 11:47 PM state. Call once at game start, before building the scene.
static func apply_initial_state() -> void:
	for room_id: StringName in LIGHTS:
		WorldState.set_light(room_id, LIGHTS[room_id]["on"])
	for door_id: StringName in DOORS:
		WorldState.set_door(door_id, INITIAL_OPEN_DOORS.has(door_id), &"init")

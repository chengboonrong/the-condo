class_name RoomGraph
extends RefCounted
## Room connectivity built from ApartmentLayout. Doors never lock, so a door connection is always passable;
## only variant conditions add or remove rooms and connections.

var variants: Dictionary = {}  # usually WorldState.variants (shared reference)


func _init(variant_state: Dictionary = {}) -> void:
	variants = variant_state


func rooms(with_variants: Dictionary = variants) -> Array[StringName]:
	var out: Array[StringName] = []
	for room_id: StringName in ApartmentLayout.ROOMS:
		if not ApartmentLayout.room_rects(room_id, with_variants).is_empty():
			out.append(room_id)
	return out


func connections(with_variants: Dictionary = variants) -> Array:
	return ApartmentLayout.CONNECTIONS.filter(
		func(c: Dictionary) -> bool: return ApartmentLayout.requires_met(c.get("requires", {}), with_variants))


func neighbors(room_id: StringName, with_variants: Dictionary = variants) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Dictionary in connections(with_variants):
		if c["a"] == room_id:
			out.append(c["b"])
		elif c["b"] == room_id:
			out.append(c["a"])
	return out


func connection(a: StringName, b: StringName, with_variants: Dictionary = variants) -> Dictionary:
	for c: Dictionary in connections(with_variants):
		if (c["a"] == a and c["b"] == b) or (c["a"] == b and c["b"] == a):
			return c
	return {}


## Breadth-first path from a to b, inclusive. Empty when unreachable.
func path(a: StringName, b: StringName, with_variants: Dictionary = variants) -> Array[StringName]:
	if a == b:
		return [a]
	var prev := {a: &""}
	var frontier: Array[StringName] = [a]
	while not frontier.is_empty():
		var cur: StringName = frontier.pop_front()
		for n: StringName in neighbors(cur, with_variants):
			if prev.has(n):
				continue
			prev[n] = cur
			if n == b:
				var out: Array[StringName] = [b]
				while out[0] != a:
					out.push_front(prev[out[0]])
				return out
			frontier.append(n)
	return []


func distance(a: StringName, b: StringName, with_variants: Dictionary = variants) -> int:
	var p := path(a, b, with_variants)
	return p.size() - 1 if not p.is_empty() else 999


func is_reachable(a: StringName, b: StringName, with_variants: Dictionary = variants) -> bool:
	return not path(a, b, with_variants).is_empty()


## Rooms within max_steps of room_id, excluding room_id itself.
func rooms_within(room_id: StringName, max_steps: int, with_variants: Dictionary = variants) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: StringName in rooms(with_variants):
		if r != room_id and distance(room_id, r, with_variants) <= max_steps:
			out.append(r)
	return out

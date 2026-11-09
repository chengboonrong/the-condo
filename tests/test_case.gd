class_name TestCase
extends RefCounted
## Base for test files. Test methods start with "test_" and must end with `return true`;
## a method that errors out returns null and is counted as a failure by the runner.

var failures: Array[String] = []
var tree: SceneTree


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float, msg: String) -> void:
	if absf(actual - expected) > tol:
		failures.append("%s: expected %.4f ± %.4f, got %.4f" % [msg, expected, tol, actual])


## Physics frames until `her` (the Penanggal: untyped here, as the runner compiles this before the autoloads she uses)
## reaches `camera` (`reached`), at most `seconds` of them. Returns the seconds she was in its view without a break just
## before, with nothing solid between them (a ray from the camera), above the ground (the road's has no colliders) and
## with `also` holding, if given; or -1 if she never reached it.
func seen_before_reached(her: Node3D, camera: Camera3D, seconds: float, also := Callable()) -> float:
	var reached := [false]
	var on_reached := func() -> void: reached[0] = true
	her.connect(&"reached", on_reached)
	var seen := 0.0
	for i in int(seconds * 60.0):
		await tree.physics_frame
		if reached[0]:
			break
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, her.global_position)
		var clear := camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var above: bool = her.global_position.y > her._ground_under(her.global_position)
		var shown: bool = her.visible and camera.is_position_in_frustum(her.global_position)
		var more: bool = not also.is_valid() or also.call()
		seen = seen + 1.0 / 60.0 if shown and clear and above and more else 0.0
	her.disconnect(&"reached", on_reached)
	return seen if reached[0] else -1.0

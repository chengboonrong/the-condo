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

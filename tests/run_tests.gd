# Headless test runner. Exit code 0 = all passed.
#   godot --headless --path . --script res://tests/run_tests.gd [-- --filter=<substring>]
extends SceneTree

const DIRS := ["res://tests/unit", "res://tests/integration"]

var passed := 0
var failed := 0


func _initialize() -> void:
	await process_frame
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	for dir in DIRS:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				await _run_file(dir.path_join(file), filter)
	print("\nResults: %d passed, %d failed" % [passed, failed])
	await process_frame  # let queue_free()d test scenes go before exit
	quit(1 if failed > 0 else 0)


func _run_file(path: String, filter: String) -> void:
	var script: GDScript = load(path)
	var probe: Object = script.new()
	var names: Array[String] = []
	for m in probe.get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and (filter == "" or (path + ":" + n).contains(filter)):
			names.append(n)
	probe = null
	for n in names:
		root.get_node("WorldState").reset()
		var t: TestCase = script.new()
		t.tree = self
		var started := Time.get_ticks_usec()
		var result: Variant = await t.call(n)
		var ms := (Time.get_ticks_usec() - started) / 1000.0
		await process_frame  # a scene the test queue_free()d must be gone before the next test runs
		if result != true:
			t.failures.append("did not finish (runtime error?)")
		if t.failures.is_empty():
			passed += 1
			print("  PASS %s:%s (%.1f ms)" % [path.get_file(), n, ms])
		else:
			failed += 1
			for f in t.failures:
				printerr("  FAIL %s:%s — %s" % [path.get_file(), n, f])

# Headless test runner. Exit code 0 = all passed.
#   godot --headless --path . --script res://tests/run_tests.gd [-- --filter=<substring>]
extends SceneTree

const DIRS := ["res://tests/unit", "res://tests/integration"]

var passed := 0
var failed := 0


func _initialize() -> void:
	await process_frame
	# The game's 16:9 window (project.godot), not the headless default: a wider view sees more at the
	# sides, and visibility tests must judge what a player would actually see.
	root.size = Vector2i(1600, 900)
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
	if script == null or not script.can_instantiate():
		failed += 1
		printerr("  FAIL %s — does not load (parse error?)" % path.get_file())
		return
	var probe: Object = script.new()
	var names: Array[String] = []
	for m in probe.get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and (filter == "" or (path + ":" + n).contains(filter)):
			names.append(n)
	probe = null
	var settings := root.get_node("Settings")
	settings.path = "user://test_settings.cfg"  # never the player's own settings
	for n in names:
		root.get_node("WorldState").reset()
		settings.values = settings.DEFAULTS.duplicate()
		var t: TestCase = script.new()
		t.tree = self
		var before := root.get_children()
		var started := Time.get_ticks_usec()
		var result: Variant = await t.call(n)
		var ms := (Time.get_ticks_usec() - started) / 1000.0
		# Whatever the test added (even if it bailed out early) must be gone before the next test runs:
		# a leftover scene's StoryDirector would answer the next test's signals.
		for node in root.get_children():
			if not before.has(node):
				node.queue_free()
		await process_frame
		if result != true:
			t.failures.append("did not finish (runtime error?)")
		if t.failures.is_empty():
			passed += 1
			print("  PASS %s:%s (%.1f ms)" % [path.get_file(), n, ms])
		else:
			failed += 1
			for f in t.failures:
				printerr("  FAIL %s:%s — %s" % [path.get_file(), n, f])

extends SceneTree
## Runs every tests/test_*.gd suite without a window:
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed. A test fails on a failed check or on any engine /
## script error raised while it runs.


func _initialize() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)

	var files: Array[String] = []
	for f in DirAccess.open("res://tests").get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()

	var total := 0
	var failed := 0
	if errors.count > 0:
		failed += 1
		print("FAIL  errors before any test ran: ", errors.last)

	for f in files:
		var script := load("res://tests/" + f) as GDScript
		var suite: TestCase = script.new() if script != null and script.can_instantiate() else null
		if suite == null:
			failed += 1
			print("FAIL  %s: suite did not load" % f)
			continue
		print(f)
		for m in suite.get_method_list():
			var method: String = m["name"]
			if not method.begins_with("test_"):
				continue
			suite.failures.clear()
			var errors_before := errors.count
			suite.call(method)
			if errors.count > errors_before:
				suite.failures.append("%d engine error(s), last: %s" % [errors.count - errors_before, errors.last])
			total += 1
			if suite.failures.is_empty():
				print("  ok    ", method)
			else:
				failed += 1
				print("  FAIL  ", method)
				for msg in suite.failures:
					print("        - ", msg)

	print("\n%d tests, %d failed" % [total, failed])
	OS.remove_logger(errors)
	quit(1 if failed > 0 else 0)

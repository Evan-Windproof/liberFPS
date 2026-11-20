# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const ContentLoader = preload("res://src/content/content_loader.gd")
const MAIN := preload("res://scenes/main.tscn")

var _checks := 0
var _failures := 0
var _skipped := 0
var _capture_dir := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	_test_content()
	await _test_scene()
	print("Phase 1 smoke: %d/%d checks passed, %d skipped" % [
		_checks - _failures, _checks, _skipped])
	quit(1 if _failures > 0 else 0)

func _test_content() -> void:
	var loader := ContentLoader.new()
	for kind: String in ["level", "weapon", "ammo", "enemy", "mode"]:
		var result := loader.load_document(kind, "res://content/starter/%s.json" % kind)
		_check(result["ok"], "%s example passes its bundled schema" % kind)

		if result["ok"]:
			var encoded := loader.serialize_document(kind, result["data"])
			_check(encoded["ok"] and loader.parse_document(kind, encoded["json"]) == result,
				"%s example round-trips through JSON" % kind)

	var path := "res://content/starter/level.json"
	var source := FileAccess.get_file_as_string(path)
	_check(not loader.load_document("level", "res://missing.json")["ok"], "missing file is rejected")
	_check(not loader.parse_document("unknown", source)["ok"], "unknown kind is rejected")
	_check(not loader.parse_document("level", "{")["ok"], "malformed JSON is rejected")
	_check(not loader.parse_document("level", "[]")["ok"], "non-object root is rejected")
	_check(not loader.parse_document("level", " ".repeat(ContentLoader.MAX_BYTES + 1))["ok"],
		"oversized input is rejected")

	var level: Dictionary = JSON.parse_string(source)
	level["schema_version"] = 2
	_reject(loader, level, "unsupported version")
	level["schema_version"] = 1
	level["id"] = "../../escape"
	_reject(loader, level, "directory traversal in an ID")
	level["id"] = "training_range\n"
	_reject(loader, level, "newline at the end of an ID")
	level["id"] = "training_range"
	level["script"] = "res://arbitrary.gd"
	_check(not loader.serialize_document("level", level)["ok"],
		"serializer rejects an unexpected script field")
	_reject(loader, level, "unexpected script field")
	level.erase("script")
	level["blocks"][0]["surface"] = "res://arbitrary.tres"
	_reject(loader, level, "resource path in a palette slot")
	level["blocks"][0]["surface"] = "asphalt"
	level["blocks"][0]["size"][0] = -20
	_reject(loader, level, "negative block size")
	level["blocks"][0]["size"][0] = 36
	level["spawn"]["position"] = [18, 0, 0]
	_reject(loader, level, "spawn inside a wall")
	level["spawn"]["position"] = [0, 10, 0]
	_reject(loader, level, "spawn without floor support")
	var weapon: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/starter/weapon.json"))
	weapon["magazine_capacity"] = 2.5
	_check(not loader.parse_document("weapon", JSON.stringify(weapon))["ok"],
		"fractional count is rejected")

func _reject(loader: RefCounted, level: Dictionary, description: String) -> void:
	_check(not loader.parse_document("level", JSON.stringify(level))["ok"],
		description + " is rejected")

func _test_scene() -> void:
	var app := MAIN.instantiate()
	root.add_child(app)
	var primary: Button = app.get_node("UI/Layout/Panel/Rows/Primary")
	var return_button: Button = app.get_node("UI/Layout/Panel/Rows/Return")
	var crosshair: Label = app.get_node("UI/Crosshair")
	_check(primary.is_visible_in_tree() and not primary.disabled and not crosshair.visible,
		"main menu offers the validated arena")
	if primary.disabled:
		return
	_check(app.get_node("World/Arena").get_child_count() > 40, "JSON populated the scene")
	await _capture("main-menu")
	primary.pressed.emit()
	var player: CharacterBody3D = app.get_node("World/Player")
	await _physics_ticks(20)
	_check(player.is_on_floor() and absf(player.position.y) < 0.08, "spawn settles on the floor")
	_check(crosshair.visible and player.view.current and player.has_node("View/TrainingWeapon"),
		"play activates the player view, crosshair, and placeholder")
	await _capture("training-range")

	var start := player.position
	_key(KEY_W, true)
	await _physics_ticks(25)
	_check(start.z - player.position.z > 1.2, "W moves forward")
	var walk_speed := -player.velocity.z
	_key(KEY_SHIFT, true)
	await _physics_ticks(20)
	_check(-player.velocity.z > walk_speed + 2.0, "Shift increases movement speed")
	_key(KEY_SHIFT, false)
	_key(KEY_W, false)
	_key(KEY_A, true)
	await _physics_ticks(16)
	_check(player.position.x < start.x - 0.5, "A strafes left")
	_key(KEY_A, false)
	await _physics_ticks(15)
	_key(KEY_D, true)
	start = player.position
	await _physics_ticks(20)
	_check(player.position.x > start.x + 0.5, "D strafes right")
	_key(KEY_D, false)
	_key(KEY_SPACE, true)
	await _physics_ticks(14)
	_key(KEY_SPACE, false)
	_check(not player.is_on_floor() and player.position.y > 0.7, "Space jumps")
	await _physics_ticks(65)
	_check(player.is_on_floor() and absf(player.position.y) < 0.08, "gravity brings the player down")

	if DisplayServer.get_name() == "headless":
		_skipped += 1
		print("SKIP: mouse capture needs a windowing backend.")
	else:
		var mouse := InputEventMouseMotion.new()
		mouse.screen_relative = Vector2(50, 10000)
		mouse.relative = mouse.screen_relative
		Input.parse_input_event(mouse)
		Input.flush_buffered_events()
		_check(player.rotation.y < -0.05 and is_equal_approx(player.view.rotation.x, deg_to_rad(-88)),
			"mouse motion turns the player and clamps pitch (mode=%s yaw=%s pitch=%s)" % [
				Input.mouse_mode, player.rotation.y, player.view.rotation.x])

	player.reset_position()
	await _physics_ticks(12)
	_key(KEY_S, true)
	await _physics_ticks(80)
	_check(player.position.z > 20.5 and player.position.z < 21.5,
		"S moves backward and the arena wall blocks the player")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	var paused_position := player.position
	await _physics_ticks(10)
	_check(paused and primary.text == "Resume" and player.position == paused_position,
		"Escape pauses controller physics and opens the pause menu")
	await _capture("paused")
	_key(KEY_S, false)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(not paused and crosshair.visible, "Escape resumes play")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	return_button.pressed.emit()
	await process_frame
	_check(not paused and primary.is_visible_in_tree() and not app.has_node("World/Player"),
		"return to menu clears the current session")
	primary.pressed.emit()
	player = app.get_node("World/Player")
	await _physics_ticks(15)
	_check(is_equal_approx(player.position.z, 18.0) and player.is_on_floor(),
		"starting again creates a fresh player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_ticks(ticks: int) -> void:
	for index in ticks:
		await physics_frame
	# physics_frame emits before the controller runs.
	await process_frame

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _capture(name: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.save_png(_capture_dir.path_join(name + ".png")) == OK,
		name + " rendered to PNG")

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)

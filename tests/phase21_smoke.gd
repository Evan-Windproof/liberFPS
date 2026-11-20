# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const ContentLoader = preload("res://src/content/content_loader.gd")
const PlayerController = preload("res://src/player/player_controller.gd")
const TrainingTarget = preload("res://src/levels/training_target.gd")
const MAIN := preload("res://scenes/main.tscn")
const WEAPON := "res://content/starter/weapon.json"
const AMMO := "res://content/starter/ammo.json"

var _checks := 0
var _failures := 0
var _skipped := 0
var _capture_dir := ""
var _graphical: bool
var _loader := ContentLoader.new()
var _base: Dictionary
var _app: Node
var _player: PlayerController
var _target: TrainingTarget
var _ammo_label: Label
var _status_label: Label
var _hit_label: Label
var _primary: Button
var _hits: Array[bool] = []
var _viewmodel: Node3D
var _rest_position: Vector3
var _last_kick := 0.0
var _flash_seen := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_graphical = DisplayServer.get_name() != "headless"
	_run.call_deferred()

func _run() -> void:
	_base = _loader.load_weapon_loadout(WEAPON, AMMO)
	_check(_base["ok"], "the starter loadout validates and links its ammunition")
	if _base["ok"]:
		_test_documents()
		_app = MAIN.instantiate()
		root.add_child(_app)
		_primary = _app.get_node("UI/Layout/Panel/Rows/Primary")
		_check(not _primary.disabled, "main menu permits entry with the validated loadout")
		if not _primary.disabled:
			await _test_gameplay()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Phase 2.1 smoke: %d/%d checks passed, %d skipped" % [
		_checks - _failures, _checks, _skipped])
	quit(1 if _failures > 0 else 0)

func _test_documents() -> void:
	var weapon: Dictionary = _base["weapon"].duplicate(true)
	var ammo: Dictionary = _base["ammo"].duplicate(true)
	for key: String in ["firing_mode", "starting_reserve", "recoil", "max_range_m"]:
		weapon.erase(key)
	var legacy := _load_fixture(weapon, ammo)
	_check(legacy["ok"], "Phase 1 weapons still load without Phase 2.1 fields")

	ammo["id"] = "unrelated_round"
	var mismatch := _load_fixture(weapon, ammo)
	_check(not mismatch["ok"] and "unknown ammunition ID" in mismatch["error"],
		"well-formed but mismatched ammunition IDs are rejected")
	ammo["id"] = weapon["ammo_id"]
	ammo["projectile_speed_mps"] = 0
	_check(not _load_fixture(weapon, ammo)["ok"], "malformed ammunition data is rejected")
	weapon["firing_mode"] = "burst"
	_check(not _loader.parse_document("weapon", JSON.stringify(weapon))["ok"],
		"unsupported firing mode is rejected")
	weapon["firing_mode"] = "semi"
	weapon["recoil"] = {"kick_m": 1.0, "pitch_degrees": 5, "recovery_seconds": 0.1}
	_check(not _loader.parse_document("weapon", JSON.stringify(weapon))["ok"],
		"out-of-range recoil is rejected")

func _test_gameplay() -> void:
	_start_session()
	_ammo_label = _app.get_node("UI/WeaponHUD/Readout/Ammo")
	_status_label = _app.get_node("UI/WeaponHUD/Readout/Status")
	_hit_label = _app.get_node("UI/WeaponHUD/HitConfirmation")
	await _ticks(16)
	_check(_ammo_label.text == "24 / 72" and _ammo_label.is_visible_in_tree(),
		"starter HUD displays the JSON magazine and reserve")

	# The graphical run uses the actual LMB and R action mappings throughout.
	var aim := _player.view.global_basis
	_trigger(true)
	_trigger(false)
	await _ticks(2)
	_check(_player.weapon.magazine == 23 and _ammo_label.text == "23 / 72",
		"a tap consumes one round and updates the HUD")
	_check(_hits == [true] and _target.damageable.health == 20.0,
		"camera hitscan damages the center target using starter ammunition")
	_check(_hit_label.visible and _player.view.global_basis.is_equal_approx(aim),
		"hit confirmation shows while recoil leaves camera aim unchanged")
	_check(_flash_seen and is_equal_approx(_last_kick, 0.06),
		"a shot enables the muzzle flash and applies the starter recoil")
	await _capture("target-hit")
	await _ticks(9)
	_trigger(true)
	await _ticks(13)
	_trigger(false)
	_check(_target.damageable.health == 0.0 and _hits == [true, true, true],
		"holding automatic fire can disable the target at zero health")
	await _ticks(10)
	_trigger(true)
	_trigger(false)
	await _ticks(2)
	_check(_hits.size() == 4 and not _hits.back() and _target.damageable.health == 0.0,
		"disabled targets take no further damage and grant no hit confirmation")

	_key(KEY_ESCAPE)
	var return_button: Button = _app.get_node("UI/Layout/Panel/Rows/Return")
	return_button.pressed.emit()
	await process_frame
	_start_session()
	await _ticks(15)
	_check(_target.damageable.health == 30.0 and _player.weapon.magazine == 24,
		"re-entering the arena resets targets and the weapon")
	_player.position = Vector3(0.0, 0.0, -21.0)
	_player.rotation.y = PI
	await _ticks(6)
	_trigger(true)
	_trigger(false)
	await _ticks(2)
	_check(_hits == [false] and _target.damageable.health == 30.0,
		"the backstop blocks the shot even though the target is directly behind it")
	_player.reset_position()
	await _ticks(16)

	await _test_cadence()
	await _test_semi_and_reload()
	await _test_range()
	await _test_capture()

func _test_cadence() -> void:
	_equip(_base)
	_trigger(true)
	await _ticks(60)
	_trigger(false)
	var starter_shots := _hits.size()
	_check(starter_shots >= 7 and starter_shots <= 8, "420 RPM produces about seven shots per second")
	await _ticks(12)
	_check(_hits.size() == starter_shots, "automatic fire stops on release")

	var faster := _fixture({"rounds_per_minute": 900}, {})
	if not _equip(faster):
		return
	_trigger(true)
	await _ticks(60)
	_trigger(false)
	_check(_hits.size() >= 15 and _hits.size() <= 16 and _hits.size() > starter_shots,
		"900 RPM loaded from different JSON increases automatic cadence")

func _test_semi_and_reload() -> void:
	var semi := _fixture({
		"firing_mode": "semi", "magazine_capacity": 3, "starting_reserve": 2,
		"rounds_per_minute": 600, "reload_seconds": 0.4,
		"recoil": {"kick_m": 0.1, "pitch_degrees": 6, "recovery_seconds": 0.08},
	}, {"damage": 7})
	if not _equip(semi):
		return
	_target.damageable.reset()
	_trigger(true)
	await _ticks(21)
	_trigger(false)
	_check(_hits == [true] and _player.weapon.magazine == 2 and _target.damageable.health == 23,
		"semi-auto fires once per hold and edited ammunition deals seven damage")
	_check(is_equal_approx(_last_kick, 0.1), "edited recoil changes the viewmodel kick")
	for index in 2:
		_trigger(true)
		_trigger(false)
		await _ticks(9)
	_check(_hits.size() == 3 and _player.weapon.magazine == 0 and _ammo_label.text == "00 / 02",
		"new presses fire again, deplete the magazine, and preserve reserve")
	_trigger(true)
	_trigger(false)
	await _ticks(8)
	_check(_hits.size() == 3 and _status_label.text == "R  Reload", "an empty magazine cannot fire")

	_reload()
	await _ticks(3)
	_check(_status_label.text == "Reloading…" and _player.weapon.reserve == 2,
		"reload starts without immediately transferring reserve")
	_key(KEY_ESCAPE)
	await _ticks(30)
	_check(paused and _player.weapon.reserve == 2 and not _ammo_label.is_visible_in_tree(),
		"pause freezes reload past the configured duration and hides HUD")
	_key(KEY_ESCAPE)
	await _ticks(28)
	_check(_ammo_label.text == "02 / 00" and _status_label.text.is_empty(),
		"resume completes a partial reload, consuming only available reserve")

	_equip(semi)
	_trigger(true)
	_trigger(false)
	await _ticks(8)
	_reload()
	await _ticks(3)
	_trigger(true)
	_trigger(false)
	await _ticks(8)
	_check(_hits.size() == 1 and _player.weapon.magazine == 2 and _status_label.text == "Reloading…",
		"with rounds still loaded, firing is blocked during reload")
	await _capture("reloading")
	await _ticks(20)
	_check(_hits.size() == 1 and _ammo_label.text == "03 / 01",
		"0.4-second reload fills only the missing round and never queues the semi-auto shot")

	var no_reserve := _fixture({"firing_mode": "semi", "magazine_capacity": 1,
		"starting_reserve": 0}, {})
	if not _equip(no_reserve):
		return
	_trigger(true)
	_trigger(false)
	await _ticks(8)
	_reload()
	await _ticks(3)
	_check(_status_label.text == "No ammunition" and _player.weapon.magazine == 0,
		"reload is ignored with no reserve")

func _test_range() -> void:
	_target.damageable.reset()
	var cases := [
		{"speed": 40, "lifetime": 0.5, "cap": 80, "hit": false},
		{"speed": 40, "lifetime": 1, "cap": 80, "hit": true},
		{"speed": 80, "lifetime": 0.5, "cap": 80, "hit": true},
		{"speed": 80, "lifetime": 0.5, "cap": 15, "hit": false},
	]
	for record: Dictionary in cases:
		var loaded := _fixture({"max_range_m": record["cap"]}, {
			"projectile_speed_mps": record["speed"], "projectile_lifetime_seconds": record["lifetime"],
			"damage": 1,
		})
		if not _equip(loaded):
			continue
		_trigger(true)
		_trigger(false)
		await _ticks(3)
		_check(_hits == [record["hit"]], "loaded speed, lifetime, and effective range limit hitscan")
	_check(_target.damageable.health == 28, "only the two in-range shots applied their configured damage")

func _test_capture() -> void:
	_equip(_base)
	_trigger(true)
	await _ticks(2)
	_key(KEY_ESCAPE)
	var shot_count := _hits.size()
	await _ticks(14)
	_check(paused and _hits.size() == shot_count, "pause stops a held automatic trigger")
	_key(KEY_ESCAPE)
	await _ticks(14)
	_check(_hits.size() == shot_count, "resuming requires a fresh trigger press")
	_trigger(false)
	if not _graphical:
		_skipped += 1
		print("SKIP: LMB/R event routing and capture-loss checks need a graphical backend.")
		return
	_trigger(true)
	await _ticks(2)
	shot_count = _hits.size()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _ticks(14)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _ticks(14)
	_check(_hits.size() == shot_count, "capture loss clears fire and recapture does not restart it")
	_trigger(false)

func _start_session() -> void:
	_primary.pressed.emit()
	_player = _app.get_node("World/Player")
	_target = _app.get_node("World/Arena/Target3")
	_viewmodel = _player.get_node("View/TrainingWeapon")
	_rest_position = _viewmodel.position
	_hits.clear()
	_player.weapon.shot_fired.connect(_record_shot)

func _record_shot(hit: bool) -> void:
	_hits.append(hit)
	_last_kick = _viewmodel.position.z - _rest_position.z
	_flash_seen = _viewmodel.get_node("MuzzleFlash").visible

func _equip(loadout: Dictionary) -> bool:
	if not loadout["ok"]:
		_check(false, "fixture reload failed: %s" % loadout["error"])
		return false
	_player.equip_weapon(loadout)
	_hits.clear()
	return true

func _fixture(weapon_overrides: Dictionary, ammo_overrides: Dictionary) -> Dictionary:
	var weapon: Dictionary = _base["weapon"].duplicate(true)
	var ammo: Dictionary = _base["ammo"].duplicate(true)
	weapon.merge(weapon_overrides, true)
	ammo.merge(ammo_overrides, true)
	return _load_fixture(weapon, ammo)

func _load_fixture(weapon: Dictionary, ammo: Dictionary) -> Dictionary:
	var weapon_path := "user://phase21_%s_weapon.json" % OS.get_process_id()
	var ammo_path := "user://phase21_%s_ammo.json" % OS.get_process_id()
	if not _write_json(weapon_path, weapon) or not _write_json(ammo_path, ammo):
		DirAccess.remove_absolute(weapon_path)
		DirAccess.remove_absolute(ammo_path)
		return {"ok": false, "error": "Could not write test fixture."}
	var result := _loader.load_weapon_loadout(weapon_path, ammo_path)
	DirAccess.remove_absolute(weapon_path)
	DirAccess.remove_absolute(ammo_path)
	return result

func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	return file != null and file.store_string(JSON.stringify(data))

func _trigger(pressed: bool) -> void:
	if not _graphical:
		_player.weapon.set_trigger(pressed)
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _reload() -> void:
	if _graphical:
		_key(KEY_R)
	else:
		_player.weapon.request_reload()

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _ticks(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

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

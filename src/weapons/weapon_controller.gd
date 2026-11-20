# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

signal ammo_changed(magazine: int, reserve: int, reloading: bool)
signal shot_fired(hit_confirmed: bool)

const ShotResolver = preload("res://src/combat/shot_resolver.gd")

var magazine := 0
var reserve := 0
var _aim: Node3D
var _shooter: RID
var _capacity: int
var _shot_interval: float
var _automatic: bool
var _reload_duration: float
var _reach: float
var _damage: float
var _cooldown := 0.0
var _reload_left := 0.0
var _trigger_held := false
var _trigger_pressed := false
var _reload_requested := false

## Equip a validated weapon/ammunition pair. Each training session starts with fresh counts.
func equip(loadout: Dictionary, aim: Node3D, shooter: RID) -> void:
	var weapon: Dictionary = loadout["weapon"]
	var ammo: Dictionary = loadout["ammo"]
	_aim = aim
	_shooter = shooter
	_capacity = int(weapon["magazine_capacity"])
	_shot_interval = 60.0 / float(weapon["rounds_per_minute"])
	_reload_duration = float(weapon["reload_seconds"])
	_automatic = weapon.get("firing_mode", "semi") == "auto"
	_damage = float(ammo["damage"])
	# Hitscan is instantaneous. This flight budget caps how far the ray may travel.
	_reach = minf(weapon.get("max_range_m", 100.0),
		float(ammo["projectile_speed_mps"]) * float(ammo["projectile_lifetime_seconds"]))
	magazine = _capacity
	reserve = int(weapon.get("starting_reserve", _capacity * 3))
	_cooldown = 0.0
	_reload_left = 0.0
	clear_input()
	_emit_ammo()

func set_trigger(pressed: bool) -> void:
	if pressed and not _trigger_held:
		_trigger_pressed = true
	_trigger_held = pressed

func request_reload() -> void:
	_reload_requested = true

func clear_input() -> void:
	_trigger_held = false
	_trigger_pressed = false
	_reload_requested = false

func _physics_process(delta: float) -> void:
	if _aim == null:
		return
	var wants_shot := _trigger_pressed or (_automatic and _trigger_held)
	var wants_reload := _reload_requested
	_trigger_pressed = false
	_reload_requested = false
	# Preserve the fractional part of a physics tick between automatic shots.
	var previous_cooldown := _cooldown
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_left > 0.0:
		_reload_left = maxf(0.0, _reload_left - delta)
		if _reload_left <= 0.000001:
			_finish_reload()
		return

	if wants_reload and magazine < _capacity and reserve > 0:
		_reload_left = _reload_duration
		_emit_ammo()
		return

	if wants_shot and magazine > 0 and _cooldown <= 0.000001:
		# At most one shot per tick at the supported fire rates and project's 60 Hz.
		# Carry timing only while cooling, never bank elapsed idle time.
		var carry := 0.0
		if _automatic and previous_cooldown > 0.0:
			carry = maxf(0.0, delta - previous_cooldown)
		_cooldown = _shot_interval - carry
		_fire()

func _fire() -> void:
	magazine -= 1
	var aim := _aim.global_transform
	var confirmed := ShotResolver.hitscan(_aim.get_world_3d().direct_space_state,
		aim.origin, -aim.basis.z.normalized(), _reach, _damage, _shooter)
	_emit_ammo()
	shot_fired.emit(confirmed)

func _finish_reload() -> void:
	_reload_left = 0.0
	var transferred := mini(_capacity - magazine, reserve)
	magazine += transferred
	reserve -= transferred
	_emit_ammo()

func _emit_ammo() -> void:
	ammo_changed.emit(magazine, reserve, _reload_left > 0.0)

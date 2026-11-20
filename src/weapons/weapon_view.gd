# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D

@onready var _flash: MeshInstance3D = $MuzzleFlash
@onready var _rest_position := position
@onready var _rest_rotation := rotation

var _kick_m: float
var _kick_pitch: float
var _recovery := 0.10
var _recoil_left := 0.0
var _flash_left := 0.0
var _reloading := false
var _reload_dip := 0.0

func configure(recoil: Dictionary) -> void:
	_kick_m = float(recoil.get("kick_m", 0.035))
	_kick_pitch = deg_to_rad(float(recoil.get("pitch_degrees", 3.0)))
	_recovery = float(recoil.get("recovery_seconds", 0.10))
	_recoil_left = 0.0
	_flash_left = 0.0
	_reload_dip = 0.0
	_flash.hide()
	_apply_pose()

func play_shot(_confirmed: bool) -> void:
	_recoil_left = _recovery
	_flash_left = 0.045
	_flash.show()
	_apply_pose()

func update_reload(_magazine: int, _reserve: int, reloading: bool) -> void:
	_reloading = reloading

func _process(delta: float) -> void:
	_recoil_left = maxf(0.0, _recoil_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	_flash.visible = _flash_left > 0.0
	_reload_dip = move_toward(_reload_dip, 1.0 if _reloading else 0.0, delta * 7.0)
	_apply_pose()

func _apply_pose() -> void:
	var kick := _recoil_left / _recovery
	position = _rest_position + Vector3(0.03 * _reload_dip, -0.13 * _reload_dip, _kick_m * kick)
	rotation = _rest_rotation + Vector3(_kick_pitch * kick - 0.22 * _reload_dip,
		0.0, 0.22 * _reload_dip)

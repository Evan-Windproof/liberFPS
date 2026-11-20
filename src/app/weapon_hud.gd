# SPDX-License-Identifier: GPL-3.0-or-later
extends Control

@onready var _ammo: Label = $Readout/Ammo
@onready var _status: Label = $Readout/Status
@onready var _name: Label = $Readout/WeaponName
@onready var _hit: Label = $HitConfirmation

var _hit_left := 0.0

func set_weapon_name(display_name: String) -> void:
	_name.text = display_name
	_hit_left = 0.0
	_hit.hide()

func update_ammunition(magazine: int, reserve: int, reloading: bool) -> void:
	_ammo.text = "%02d / %02d" % [magazine, reserve]
	_status.text = ""
	if reloading:
		_status.text = "Reloading…"
	elif magazine == 0:
		_status.text = "R  Reload" if reserve > 0 else "No ammunition"

func confirm_shot(hit: bool) -> void:
	if hit:
		_hit_left = 0.18
		_hit.show()

func _process(delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left -= delta
		if _hit_left <= 0.0:
			_hit.hide()

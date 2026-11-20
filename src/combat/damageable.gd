# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

signal health_changed(remaining: float)

var max_health := 1.0
var health := 1.0

func apply_damage(amount: float) -> bool:
	if health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	return true

func reset() -> void:
	health = max_health
	health_changed.emit(health)

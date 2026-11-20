# SPDX-License-Identifier: GPL-3.0-or-later
extends StaticBody3D

const Damageable = preload("res://src/combat/damageable.gd")
const ShotResolver = preload("res://src/combat/shot_resolver.gd")
const READY_FACE := Color("#e4a94c")
const DISABLED_FACE := Color("#474b49")

var damageable: Damageable
var _face: StandardMaterial3D
var _bullseye: MeshInstance3D
var _flash_left := 0.0

func configure(size: Vector3, max_health: float) -> void:
	collision_layer = ShotResolver.DAMAGEABLE_LAYER
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)

	var plate := _box(size, Color("#323d42"))
	add_child(plate)
	var face := _box(Vector3(size.x * 0.67, size.y * 0.66, 0.012), READY_FACE)
	face.position.z = size.z * 0.5 + 0.006
	add_child(face)
	_face = face.material_override
	_bullseye = _box(Vector3(size.x * 0.25, size.y * 0.25, 0.008), Color("#ddd9be"))
	_bullseye.position.z = face.position.z + 0.01
	add_child(_bullseye)

	damageable = Damageable.new()
	damageable.name = "Damageable"
	damageable.max_health = max_health
	damageable.reset()
	add_child(damageable)
	damageable.health_changed.connect(_on_health_changed)

func _on_health_changed(remaining: float) -> void:
	_bullseye.visible = remaining > 0.0
	_flash_left = 0.12 if remaining < damageable.max_health else 0.0
	_face.albedo_color = Color("#fff1b0") if _flash_left > 0.0 else READY_FACE

func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_face.albedo_color = READY_FACE if damageable.health > 0.0 else DISABLED_FACE

static func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance

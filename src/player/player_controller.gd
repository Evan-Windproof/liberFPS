# SPDX-License-Identifier: GPL-3.0-or-later
extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_SPEED := 5.3
const ACCELERATION := 28.0
const AIR_ACCELERATION := 9.0
const LOOK_SENSITIVITY := 0.0023
const PITCH_LIMIT := deg_to_rad(88.0)

@onready var view: Camera3D = $View
var _spawn_position: Vector3
var _spawn_yaw: float
var _grav: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

func set_spawn(feet: Vector3, yaw_degrees: float) -> void:
	_spawn_position = feet
	_spawn_yaw = deg_to_rad(yaw_degrees)
	reset_position()

func reset_position() -> void:
	global_position = _spawn_position
	rotation.y = _spawn_yaw
	view.rotation.x = 0.0
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.screen_relative.x * LOOK_SENSITIVITY)
		view.rotation.x = clampf(view.rotation.x - event.screen_relative.y * LOOK_SENSITIVITY,
			-PITCH_LIMIT, PITCH_LIMIT)

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	if not grounded:
		velocity.y -= _grav * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := transform.basis * Vector3(axis.x, 0.0, axis.y)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var acceleration := ACCELERATION if grounded else AIR_ACCELERATION
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
		Vector2(direction.x, direction.z) * speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	move_and_slide()
	if global_position.y < _spawn_position.y - 20.0:
		reset_position()

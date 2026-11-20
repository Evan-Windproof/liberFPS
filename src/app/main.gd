# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

const ContentLoader = preload("res://src/content/content_loader.gd")
const LevelBuilder = preload("res://src/levels/level_builder.gd")
const PLAYER := preload("res://scenes/player.tscn")
const STARTER_LEVEL := "res://content/starter/level.json"
const CONTROLS := "WASD  Move     Mouse  Look\nShift  Sprint     Space  Jump     Esc  Pause"

enum Screen { MENU, PLAY, PAUSE }

@onready var _world: Node3D = $World
@onready var _overview: Camera3D = $World/Overview
@onready var _crosshair: Label = $UI/Crosshair
@onready var _shade: ColorRect = $UI/Shade
@onready var _layout: CenterContainer = $UI/Layout
@onready var _title: Label = $UI/Layout/Panel/Rows/Title
@onready var _details: Label = $UI/Layout/Panel/Rows/Details
@onready var _primary: Button = $UI/Layout/Panel/Rows/Primary
@onready var _return: Button = $UI/Layout/Panel/Rows/Return
@onready var _quit: Button = $UI/Layout/Panel/Rows/Quit

var _screen := Screen.MENU
var _level: Dictionary
var _load_error := ""
var _player: CharacterBody3D

func _ready() -> void:
	var result := ContentLoader.new().load_document("level", STARTER_LEVEL)
	if result["ok"]:
		_level = result["data"]
		_world.add_child(LevelBuilder.new().build(_level))
		_overview.look_at(Vector3(0, 0.0, -4))
	else:
		_load_error = result["error"]
		push_error(_load_error)

	_primary.pressed.connect(_on_primary_pressed)
	_return.pressed.connect(_return_to_menu)
	_quit.pressed.connect(get_tree().quit)
	_show_menu()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_game") or event.is_echo():
		return
	match _screen:
		Screen.PLAY:
			_show_pause()
		Screen.PAUSE:
			_resume_play()
		_:
			return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _screen == Screen.PLAY:
		_show_pause()

func _on_primary_pressed() -> void:
	if _screen == Screen.PAUSE:
		_resume_play()
	elif _screen == Screen.MENU and not _level.is_empty():
		_player = PLAYER.instantiate()
		_world.add_child(_player)
		var spawn: Dictionary = _level["spawn"]
		_player.set_spawn(ContentLoader.vector3(spawn["position"]), spawn["yaw_degrees"])
		_player.view.make_current()
		_resume_play()

func _resume_play() -> void:
	_screen = Screen.PLAY
	_layout.hide()
	_shade.hide()
	_crosshair.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _show_pause() -> void:
	_screen = Screen.PAUSE
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = "Paused"
	_details.text = CONTROLS
	_primary.text = "Resume"
	_return.show()
	_show_overlay()

func _return_to_menu() -> void:
	_overview.make_current()
	_player.queue_free()
	_player = null
	_show_menu()

func _show_menu() -> void:
	_screen = Screen.MENU
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = "Open FPS Sandbox"
	_details.text = "Training arena unavailable.\n" + _load_error
	if _load_error.is_empty():
		_details.text = _level["name"] + "\n\n" + CONTROLS
	_primary.disabled = not _load_error.is_empty()
	_primary.text = "Enter training arena"
	_return.hide()
	_show_overlay()

func _show_overlay() -> void:
	_crosshair.hide()
	_shade.show()
	_layout.show()
	(_quit if _primary.disabled else _primary).grab_focus()

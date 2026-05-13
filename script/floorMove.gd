extends Node2D

const Width = 336
@onready var cam = _get_camera()
var customCamera: Camera2D
var startPosition: Vector2

func _get_camera() -> Camera2D:
	if customCamera != null:
		return customCamera
	return get_viewport().get_camera_2d()

func set_camera(camera: Camera2D) -> void:
	customCamera = camera
	cam = camera

func _ready() -> void:
	startPosition = position

func reset_floor() -> void:
	position = startPosition

func _physics_process(delta):
	if delta < 0.0:
		return
	if cam == null:
		cam = _get_camera()
	if cam == null:
		return
	if cam.get_screen_center_position().x>position.x+Width*1.5:
		position.x= position.x+ Width*2

extends Node

@export_file("*.tscn") var pipe: String

@export var pipeNumber: int = 4 # (int, 2, 10,1)

@onready var cam = _get_camera()

var pipeScene: PackedScene
var randomX = 450 
var randomY = 192
var pipeColor = 1
var customCamera: Camera2D


func _ready():
	pipeColor = randi() % 2
	if !_ensure_pipe_scene():
		return
	startingPipes()

func _process(_delta):
	rePositionPipes()

func _get_camera() -> Camera2D:
	if customCamera != null:
		return customCamera
	return get_viewport().get_camera_2d()

func set_camera(camera: Camera2D) -> void:
	customCamera = camera
	cam = camera

func _ensure_pipe_scene() -> bool:
	if pipeScene != null:
		return true
	pipeScene = load(pipe) as PackedScene
	if pipeScene == null:
		printerr("Pipe scene could not be loaded: ", pipe)
		return false
	return true
	
func createPipe(posX,posY):
	if !_ensure_pipe_scene():
		return

	var newPipe = pipeScene.instantiate()
	newPipe.position=Vector2(posX,posY)
	add_child(newPipe)
	newPipe.setPipeColor(bool(pipeColor))

func startingPipes():
	createPipe(randomX,randomY)
	for i in range(0, pipeNumber, 1):
		randomY = ceil(randf_range(randomY-100,randomY+100))
		randomY = max(min(randomY,312),88)
		randomX += ceil(randf_range(100,200))
		createPipe(randomX,randomY)

func setup_training_pipes(camera: Camera2D) -> void:
	set_camera(camera)
	pipeColor = randi() % 2
	for child in get_children():
		remove_child(child)
		child.queue_free()
	randomX = 450
	randomY = 192
	startingPipes()

func rePositionPipes():
	if cam == null:
		cam = _get_camera()
	if cam == null:
		return
	for pipeNode in get_children():
		if pipeNode.position.x < cam.get_screen_center_position().x-200:
			randomY = ceil(randf_range(randomY-100,randomY+100))
			randomY = max(min(randomY,310),90)
			randomX += ceil(randf_range(100,200))
			createPipe(randomX,randomY)
			pipeNode.queue_free()

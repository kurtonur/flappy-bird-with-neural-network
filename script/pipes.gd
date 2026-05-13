extends Node

@export_file("*.tscn") var pipe: String

@export var pipeNumber = 4 # (int, 2, 10,1)

@onready var cam = _get_camera()

var pipeScene: PackedScene
var randomX = 450 
var randomY = 192
var pipeColor = 1
var customCamera: Camera2D


func _ready():
	randomize()
	pipeColor = randi() % 2
	if !_ensure_pipe_scene():
		return
	startingPipes()

func _process(_delta):
	rePositionPipes()

func _get_camera() -> Camera2D:
	if customCamera != null:
		return customCamera
	var current_camera := get_viewport().get_camera_2d()
	if current_camera != null:
		return current_camera
	var play_node := get_parent()
	if play_node == null:
		play_node = globe.playNode
	if play_node == null:
		return null
	for child in play_node.get_children():
		if child.get("is_player") == true:
			return child.get_node_or_null("Camera2D") as Camera2D
	for child in play_node.get_children():
		if child.get("is_player") == false:
			return child.get_node_or_null("Camera2D") as Camera2D
	return null

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

extends Node

@export_file("*.tscn") var pipe: String

@export var pipeNumber = 4 # (int, 2, 10,1)

@onready var cam = globe.playNode.get_node("bird/Camera2D")

var pipeScene: PackedScene
var randomX = 450 
var randomY = 192
var pipeColor = 1


func _ready():
	randomize()
	pipeColor = randi() % 2
	pipeScene = load(pipe) as PackedScene
	if pipeScene == null:
		printerr("Pipe scene could not be loaded: ", pipe)
		return
	startingPipes()

func _process(delta):
	rePositionPipes()
	
func createPipe(posX,posY):
	if pipeScene == null:
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

func rePositionPipes():
	for pipeNode in get_children():
		if pipeNode.position.x < cam.get_screen_center_position().x-200:
			randomY = ceil(randf_range(randomY-100,randomY+100))
			randomY = max(min(randomY,310),90)
			randomX += ceil(randf_range(100,200))
			createPipe(randomX,randomY)
			pipeNode.queue_free()

extends Node2D

const Width = 336
@onready var cam = globe.playNode.get_node("bird/Camera2D")


func _physics_process(delta):
	if cam.get_screen_center_position().x>position.x+Width*1.5:
		position.x= position.x+ Width*2

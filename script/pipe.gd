extends Node2D


@onready var pipegreen = get_node("StaticBody2D/CollisionShape2D/pipe-green")
@onready var pipegreen2 = get_node("StaticBody2D/CollisionShape2D2/pipe-green2")
@onready var pipered = get_node("StaticBody2D/CollisionShape2D/pipe-red")
@onready var pipered2 = get_node("StaticBody2D/CollisionShape2D2/pipe-red2")

func _ready() -> void:
	add_to_group("Pipe")

func setPipeColor(isGreen=true):
	if(isGreen):
		pipegreen.visible = true
		pipegreen2.visible = true
	else:
		pipered.visible = true
		pipered2.visible = true
	pass

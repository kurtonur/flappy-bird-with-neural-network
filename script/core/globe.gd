extends Node

var score = 0
var gameState=0

@onready var gameNode = get_tree().get_root().get_node("game")
@onready var playNode = gameNode.get_node("play")


enum GAMESTATE{menu=0,play=1,pause=2,death=10}

func set_playNode(node):
	playNode = node
	pass

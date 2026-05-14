extends Node

var score = 0
var gameState=0
## When true, training scene freezes birds/pipes/floor scroll (T pause button). Autoload so birds/pipes can read it.
var training_simulation_paused: bool = false

@onready var gameNode = get_tree().get_root().get_node_or_null("game")
@onready var playNode = gameNode.get_node_or_null("play") if gameNode != null else null


enum GAMESTATE{menu=0,play=1,pause=2,death=10}

func set_playNode(node):
	playNode = node
	pass

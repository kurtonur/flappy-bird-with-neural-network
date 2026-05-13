extends ParallaxBackground

@onready var backgroundday = get_node("background-day")
@onready var backgroundnight = get_node("background-night")

func _ready():
	randomize_theme()
	pass 

func randomize_theme() -> void:
	var use_day := randi() % 2 == 0
	backgroundday.visible = use_day
	backgroundnight.visible = !use_day

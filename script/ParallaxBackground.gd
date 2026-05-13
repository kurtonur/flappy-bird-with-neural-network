extends ParallaxBackground

@onready var backgroundday = get_node("background-day")
@onready var backgroundnight = get_node("background-night")

func _ready():
	randomize()
	if(randi()%10+1 <= 5):
		backgroundday.visible = true
	else:
		backgroundnight.visible = true
	pass 
	

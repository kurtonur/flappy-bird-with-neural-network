extends CharacterBody2D

const UP= Vector2(0,-1)
const GRAVITY = 25
const ACCELERATION = 30
const MAX_SPEED = 175
const JUMP_HIGH = -350

var motion = Vector2()
var spriteColor = 1
var head_down_tween: Tween

func _ready():
	randomize()
	spriteColor = randi()%3+1
	$AnimatedSprite2D.play("fly"+str(spriteColor))
	
func _physics_process(delta):
	if globe.gameState == globe.GAMESTATE.play:
		gameOver()
		motion.y +=GRAVITY
		motion.x = min(motion.x+ACCELERATION,MAX_SPEED)
		velocity = motion
		up_direction = UP
		move_and_slide()
		motion=velocity
	elif globe.gameState == globe.GAMESTATE.death:
		velocity = Vector2(0,600)
		up_direction = UP
		move_and_slide()
		motion=velocity
	
func _input(event):
	if event is InputEventScreenTouch && event.pressed:
		jump()

func jump():
	if globe.gameState == globe.GAMESTATE.menu:
		globe.gameState=globe.GAMESTATE.play
	if globe.gameState == globe.GAMESTATE.play:
		if !is_on_floor():
			stop_head_down_tween()
		$AnimatedSprite2D.rotation_degrees= -25
		start_head_down_tween(Tween.TRANS_CIRC)
		motion.y=JUMP_HIGH
		$audio/jump.play()
	
func gameOver():
	if is_on_wall() or is_on_floor() or is_on_ceiling():
		globe.gameState=globe.GAMESTATE.death
		stop_head_down_tween()
		$AnimatedSprite2D.play("idle"+str(spriteColor))
		$audio/hit.play()
		$audio/death.play()
		$"../CanvasLayer/flash".emitting = true
		if saveLoad.loadData()["highScore"] <= globe.score:
			saveLoad.saveData()
		globe.score=0
	
func scoreCount():
	globe.score+=1
	$audio/score.play()

func start_head_down_tween(trans_type):
	stop_head_down_tween()
	head_down_tween = create_tween()
	head_down_tween.tween_property($AnimatedSprite2D, "rotation_degrees", 85.0, 1.0).set_trans(trans_type).set_ease(Tween.EASE_IN_OUT)

func stop_head_down_tween():
	if head_down_tween != null and head_down_tween.is_running():
		head_down_tween.kill()



func _on_bird_area_entered_scoreCount(area):
	scoreCount()

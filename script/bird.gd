extends CharacterBody2D

const GRAVITY = 25
const ACCELERATION = 30
const MAX_SPEED = 175
const JUMP_HIGH = -350
const BIRD_COLLISION_LAYER = 2
const WORLD_COLLISION_MASK = 1

enum {Alive, Death}

@export var is_player: bool = false
@export var ai_file: String = "AI_Name"

var motion = Vector2()
var spriteColor = 1
var head_down_tween: Tween
var status: int = Alive
var score: int = 0
var display_name: String = ""

var audio_enabled: bool = true
var training_mode: bool = false

@onready var ai = get_node_or_null("NeuralNetwork")
@onready var name_label: Label = $NameLabel
@onready var score_label: Label = $ScoreLabel
@onready var camera: Camera2D = $Camera2D

func _ready():
	up_direction = Vector2.UP
	collision_layer = BIRD_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_MASK
	if !is_player:
		var has_player := has_player_in_play()
		set_audio_enabled(false)
		camera.enabled = !training_mode and !has_player
		setup_ai()
		if !training_mode and !has_player:
			globe.gameState = globe.GAMESTATE.play
			var message := get_node_or_null("../message")
			if message != null:
				message.visible = false
	else:
		camera.enabled = true
	if camera.enabled:
		camera.make_current()
	spriteColor = randi()%3+1
	$AnimatedSprite2D.play("fly"+str(spriteColor))
	update_labels()
	
func _physics_process(delta):
	update_labels()
	if !is_player:
		AIMove()
	if status == Alive and (training_mode or globe.gameState == globe.GAMESTATE.play):
		motion.y +=GRAVITY
		motion.x = min(motion.x+ACCELERATION,MAX_SPEED)
		velocity = motion
		move_and_slide()
		motion=velocity
		check_game_over()
	elif !training_mode and globe.gameState == globe.GAMESTATE.death:
		velocity = Vector2(0,600)
		move_and_slide()
		motion=velocity
	
func _input(event):
	if is_player and event is InputEventScreenTouch && event.pressed:
		jump()

func setup_ai() -> void:
	if ai == null:
		return
	var ai_file_path := "user://" + ai_file if ai_file != "" else ""
	if ai_file_path != "" and FileAccess.file_exists(ai_file_path):
		ai.LoadNetworkFromFile(ai_file_path)

func has_player_in_play() -> bool:
	var parent_node := get_parent()
	if parent_node == null:
		return is_player
	for child in parent_node.get_children():
		if child.get("is_player") == true:
			return true
	return false

func restart_ai_game() -> void:
	var retry_play = load("res://scene/play.tscn").instantiate()
	if globe.playNode != null:
		globe.playNode.queue_free()
	globe.set_playNode(retry_play)
	globe.gameState = globe.GAMESTATE.menu
	globe.gameNode.add_child(retry_play)

func AIMove() -> void:
	if ai == null:
		return
	if !training_mode and globe.gameState != globe.GAMESTATE.play:
		return

	var output: PackedFloat32Array = ai.FastForward(GetAIInputs())
	if output.is_empty():
		return
	if output[0] >= 0.5:
		jump()

func GetAIInputs() -> Array:
	var input: Array = []
	var pipe_positions = Close2PipePosition()
	for pipe_position in pipe_positions:
		if pipe_position == null:
			input = input + [0.0, 0.0]
			continue
		input = input + [
			pipe_position.x - global_position.x,
			pipe_position.y - global_position.y
		]
	return input

func Close2PipePosition() -> Array:
	var pipes: Array = []
	for item in get_tree().get_nodes_in_group("Pipe"):
		if item is Node2D:
			pipes.append(item)
	pipes.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))

	var result: Array = []
	for i in range(min(2, pipes.size())):
		result.append(pipes[i].global_position)
	while result.size() < 2:
		result.append(null)
	return result

func jump():
	if is_player and globe.gameState == globe.GAMESTATE.menu:
		globe.gameState=globe.GAMESTATE.play
	if status == Alive and (training_mode or globe.gameState == globe.GAMESTATE.play):
		if !is_on_floor():
			stop_head_down_tween()
		$AnimatedSprite2D.rotation_degrees= -25
		start_head_down_tween(Tween.TRANS_CIRC)
		motion.y=JUMP_HIGH
		if audio_enabled:
			$audio/jump.play()
	
func check_game_over() -> void:
	if training_mode and (global_position.y < -50.0 or global_position.y > 420.0):
		Dead()
		return
	if is_on_wall() or is_on_floor() or is_on_ceiling():
		Dead()
		if !is_player:
			if !training_mode and !has_player_in_play():
				call_deferred("restart_ai_game")
			return
		disable_ai_birds_in_play()
		globe.gameState=globe.GAMESTATE.death
		if audio_enabled:
			$audio/hit.play()
			$audio/death.play()
		$"../CanvasLayer/flash".emitting = true
		if saveLoad.loadData()["highScore"] <= globe.score:
			saveLoad.saveData()
		globe.score=0

func disable_ai_birds_in_play() -> void:
	if training_mode:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	for child in parent_node.get_children():
		if child == self or child.get("is_player") != false:
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED

func Dead() -> void:
	if status == Death:
		return
	status = Death
	set_ai_enabled(false)
	modulate.a = 0.35
	stop_head_down_tween()
	$AnimatedSprite2D.play("idle"+str(spriteColor))
	update_labels()

func SetAlive() -> void:
	status = Alive
	set_ai_enabled(true)
	modulate.a = 1.0
	collision_layer = BIRD_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_MASK
	score = 0
	motion = Vector2.ZERO
	velocity = Vector2.ZERO
	stop_head_down_tween()
	$AnimatedSprite2D.rotation_degrees = 0.0
	$AnimatedSprite2D.play("fly"+str(spriteColor))
	update_labels()
	
func scoreCount():
	if status != Alive:
		return
	score += 1
	if ai != null:
		ai.fitness = max(ai.fitness, get_training_fitness())
	if is_player:
		globe.score+=1
	if audio_enabled:
		$audio/score.play()
	update_labels()

func get_training_fitness() -> float:
	return float(score * 1000) + global_position.x

func set_audio_enabled(value: bool) -> void:
	audio_enabled = value and is_player
	for audio_player in $audio.get_children():
		if audio_player is AudioStreamPlayer:
			audio_player.stream_paused = !audio_enabled

func set_ai_enabled(value: bool) -> void:
	if ai != null:
		ai.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
		if OS.is_debug_build():
			if value:
				ai.add_to_group(NeuralNetwork.Debugger)
			else:
				ai.remove_from_group(NeuralNetwork.Debugger)

func set_display_name(value: String) -> void:
	display_name = value
	update_labels()

func update_labels() -> void:
	var show_ai_labels := !is_player and status == Alive and (training_mode or globe.gameState == globe.GAMESTATE.play)
	if name_label != null:
		name_label.visible = show_ai_labels
		name_label.text = display_name if display_name != "" else name
	if score_label != null:
		score_label.visible = show_ai_labels
		score_label.text = str(score)

func start_head_down_tween(trans_type):
	stop_head_down_tween()
	head_down_tween = create_tween()
	head_down_tween.tween_property($AnimatedSprite2D, "rotation_degrees", 85.0, 1.0).set_trans(trans_type).set_ease(Tween.EASE_IN_OUT)

func stop_head_down_tween():
	if head_down_tween != null and head_down_tween.is_running():
		head_down_tween.kill()

func _on_bird_area_entered_scoreCount(area):
	if area.name != "scoreCount":
		return
	scoreCount()

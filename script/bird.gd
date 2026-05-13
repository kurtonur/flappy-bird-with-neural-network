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
var last_label_game_state: int = -1

var audio_enabled: bool = true
var training_mode: bool = false

@onready var ai = get_node_or_null("NeuralNetwork")
@onready var name_label: Label = $NameLabel
@onready var score_label: Label = $ScoreLabel
@onready var camera: Camera2D = $Camera2D

func _ready():
	randomize()
	up_direction = Vector2.UP
	configure_body_collision()
	if !is_player:
		set_audio_enabled(false)
		configure_ai_camera()
		setup_ai()
		start_ai_game()
	else:
		configure_player_camera()
	spriteColor = randi()%3+1
	$AnimatedSprite2D.play("fly"+str(spriteColor))
	update_labels()
	
func _physics_process(delta):
	update_labels_on_game_state_changed()
	if !is_player:
		process_ai()
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

func configure_body_collision() -> void:
	collision_layer = BIRD_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_MASK

func configure_ai_camera() -> void:
	camera.enabled = !training_mode and !has_player_in_play()
	if camera.enabled:
		camera.make_current()

func configure_player_camera() -> void:
	camera.enabled = true
	camera.make_current()

func has_player_in_play() -> bool:
	var parent_node := get_parent()
	if parent_node == null:
		return is_player
	for child in parent_node.get_children():
		if child.get("is_player") == true:
			return true
	return false

func start_ai_game() -> void:
	if training_mode or has_player_in_play():
		return
	globe.gameState = globe.GAMESTATE.play
	var message := get_node_or_null("../message")
	if message != null:
		message.visible = false

func restart_ai_game() -> void:
	var retry_play = load("res://scene/play.tscn").instantiate()
	if globe.playNode != null:
		globe.playNode.queue_free()
	globe.set_playNode(retry_play)
	globe.gameState = globe.GAMESTATE.menu
	globe.gameNode.add_child(retry_play)

func process_ai() -> void:
	if ai == null:
		return
	if !training_mode and globe.gameState != globe.GAMESTATE.play:
		return

	var output: PackedFloat32Array = ai.FastForward(get_ai_inputs())
	if output.is_empty():
		return
	if output[0] > 0.5:
		jump()

func get_ai_inputs() -> Array:
	var viewport_size := get_viewport_rect().size
	var next_pipe := get_next_pipe()
	var pipe_dx := 1.0
	var pipe_dy := 0.0
	if next_pipe != null:
		pipe_dx = clamp((next_pipe.global_position.x - global_position.x) / viewport_size.x, -1.0, 1.0)
		pipe_dy = clamp((next_pipe.global_position.y - global_position.y) / viewport_size.y, -1.0, 1.0)
	return [pipe_dx, pipe_dy]

func get_next_pipe() -> Node2D:
	var pipes_node := get_node_or_null("../pipes")
	if pipes_node == null:
		pipes_node = get_node_or_null("../../pipes")
	if pipes_node == null:
		return null

	var nearest_pipe: Node2D = null
	var nearest_distance := INF
	for pipe_node in pipes_node.get_children():
		if pipe_node is Node2D:
			var distance: float = pipe_node.global_position.x - global_position.x
			if distance > -20.0 and distance < nearest_distance:
				nearest_pipe = pipe_node
				nearest_distance = distance
	return nearest_pipe

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
	configure_body_collision()
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
	return float(score)

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

func update_labels_on_game_state_changed() -> void:
	if last_label_game_state == globe.gameState:
		return
	last_label_game_state = globe.gameState
	update_labels()

func should_show_ai_labels() -> bool:
	return !is_player and status == Alive and (training_mode or globe.gameState == globe.GAMESTATE.play)

func update_labels() -> void:
	var show_ai_labels := should_show_ai_labels()
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

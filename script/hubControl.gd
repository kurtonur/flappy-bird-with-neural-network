extends Control

func _ready():
	$scoreHigh.text="High Score \n"+str(saveLoad.loadData()["highScore"])

func _process(_delta):
	if globe.gameState == globe.GAMESTATE.menu:
		$scoreHigh.visible=true
		$pause.visible=false
		$gameOver.visible=false
		$pauseResume.visible=false
		$scoreWrite.visible=false
		$retry.visible=false
	elif globe.gameState == globe.GAMESTATE.play:
		self.visible=true
		$pause.visible=true
		$gameOver.visible=false
		$pauseResume.visible=false
		$scoreWrite.visible=true
		$scoreWrite.text=str(globe.score)
		$retry.visible=false
		$scoreHigh.visible=false
	elif globe.gameState == globe.GAMESTATE.pause:
		$pause.visible=false
		$gameOver.visible=false
		$pauseResume.visible=true
		$scoreWrite.visible=true
		$retry.visible=false
		$scoreHigh.visible=false
	elif globe.gameState == globe.GAMESTATE.death:
		$pause.visible=false
		$gameOver.visible=true
		$pauseResume.visible=false
		$scoreWrite.visible=true
		$retry.visible=true

func _on_pause_button_up():
	get_tree().paused = true
	globe.gameState = globe.GAMESTATE.pause
	var player := get_player_bird()
	if player != null:
		player.visible=false

func _on_pauseResume_button_up():
	var player := get_player_bird()
	if player != null:
		player.visible=true
	globe.gameState = globe.GAMESTATE.play
	get_tree().paused = false

func get_player_bird() -> Node:
	if globe.playNode == null:
		return null
	for child in globe.playNode.get_children():
		if child.get("is_player") == true:
			return child
	return null

func _on_retry_button_up():
	globe.playNode.queue_free()
	var retryPLay= load("res://scene/play.tscn").instantiate()
	globe.set_playNode(retryPLay)
	globe.gameState=globe.GAMESTATE.menu
	globe.gameNode.add_child(retryPLay)

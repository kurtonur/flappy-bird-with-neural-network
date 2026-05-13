extends Node

@export var population: int = 100
@export var gameSpeed: int = 1
@export var saveFile: String = "AI_Name"
@export var hiddenLayers: Array[int] = [6]
@export var startRandomization: Vector2 = Vector2(-1.0, 1.0)
@export var bias: float = 0.0
@export var learningRate: Vector2 = Vector2(-0.02, 0.02)
@export var networkBestFitness: float = 0.0
@export var mutationFunction: NeuralNetwork.MutationFunctions = NeuralNetwork.MutationFunctions.Default
@export var activationFunction: NeuralNetwork.ActivationFuctions = NeuralNetwork.ActivationFuctions.Default

const AI_INPUT_COUNT: int = 4
const GENERATION_BATCH_SIZE: int = 100

var playerScene: PackedScene = preload("res://sceneObject/bird.tscn")
var playerList: Array = []
var aliveCounter: int = 0
var bestNetworkData: Dictionary = {}
var bestFitness: float = -INF
var isPreparingGeneration: bool = false
var pendingBestNetworkData: Dictionary = {}
var generationIndex: int = 0
var pipesNode: Node
var trainingCamera: Camera2D

@onready var genLabel: Label = get_node("CanvasLayer/Gen")
@onready var popLabel: Label = get_node("CanvasLayer/Pop")
@onready var fpsLabel: Label = get_node("CanvasLayer/Fps")

var generation: int = 0
var lastAliveCount: int = -1
var lastGameSpeed: int = -1
var generationStartDelay: float = 0.0
var spawnPosition: Vector2 = Vector2(144, 224)

func _ready() -> void:
	globe.gameState = globe.GAMESTATE.play
	DisableGameplayUi()
	SetupTrainingCamera()
	SetupFloor()
	SetupTheme()
	SetupPipes()
	LoadSavedBestAI()
	CreateGeneration()

func _process(delta: float) -> void:
	fpsLabel.text = "FPS : " + str(Engine.get_frames_per_second())
	if lastGameSpeed != gameSpeed:
		Engine.time_scale = gameSpeed
		lastGameSpeed = gameSpeed
	UpdateTrainingCamera()
	if isPreparingGeneration:
		ProcessGenerationBatch()
		return
	if generationStartDelay > 0.0:
		generationStartDelay -= delta
		return

	CheckBirds()

func CheckBirds() -> void:
	aliveCounter = 0
	for player in playerList:
		if player.status == player.Alive:
			aliveCounter += 1

	if aliveCounter == 0 and !playerList.is_empty():
		StartNextGeneration()
		return

	if aliveCounter != lastAliveCount:
		popLabel.text = "Pop : " + str(aliveCounter)
		lastAliveCount = aliveCounter

func SetupTrainingCamera() -> void:
	trainingCamera = Camera2D.new()
	trainingCamera.name = "TrainingCamera"
	trainingCamera.position = Vector2(144, 256)
	add_child(trainingCamera)
	trainingCamera.make_current()

func DisableGameplayUi() -> void:
	var control := get_node_or_null("../CanvasLayer/Control")
	if control == null:
		control = get_node_or_null("CanvasLayer/Control")
	if control == null:
		return
	control.visible = false
	control.process_mode = Node.PROCESS_MODE_DISABLED
	for child in control.get_children():
		child.visible = false
		child.process_mode = Node.PROCESS_MODE_DISABLED

func SetupPipes() -> void:
	pipesNode = get_node_or_null("../pipes")
	if pipesNode == null:
		pipesNode = get_node_or_null("pipes")
	if pipesNode == null:
		printerr("Training needs a pipes node.")
		return
	pipesNode.setup_training_pipes(trainingCamera)

func SetupFloor() -> void:
	var floorNode := get_node_or_null("../floor")
	if floorNode == null:
		floorNode = get_node_or_null("floor")
	if floorNode == null:
		return
	for child in floorNode.get_children():
		if child.has_method("set_camera"):
			child.set_camera(trainingCamera)

func SetupTheme() -> void:
	var themeNode := get_node_or_null("../ParallaxBackground")
	if themeNode == null:
		themeNode = get_node_or_null("ParallaxBackground")
	if themeNode != null and themeNode.has_method("randomize_theme"):
		themeNode.randomize_theme()

func UpdateTrainingCamera() -> void:
	if trainingCamera == null:
		return
	var leadX: float = spawnPosition.x
	for player in playerList:
		if player.status == player.Alive:
			leadX = max(leadX, player.global_position.x)
	trainingCamera.global_position = Vector2(leadX, 256.0)

func CreateGeneration(bestAIData: Dictionary = {}) -> void:
	generation += 1
	genLabel.text = "Gen : " + str(generation)
	RemoveExtraPlayers()
	pendingBestNetworkData = bestAIData
	generationIndex = 0
	isPreparingGeneration = true
	for player in playerList:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
	lastAliveCount = population
	popLabel.text = "Pop : " + str(playerList.size())

func ProcessGenerationBatch() -> void:
	for _i in range(GENERATION_BATCH_SIZE):
		if playerList.size() < population:
			AddBird(playerList.size())
			popLabel.text = "Pop : " + str(playerList.size())
			continue
		if generationIndex >= playerList.size():
			FinishGenerationPreparation()
			return

		var player = playerList[generationIndex]
		ApplyNetwork(player, generationIndex, pendingBestNetworkData)
		ResetPlayer(player, generationIndex)
		generationIndex += 1

func RemoveExtraPlayers() -> void:
	while playerList.size() > population:
		var player = playerList.pop_back()
		player.queue_free()

func AddBird(index: int):
	var player = playerScene.instantiate()
	playerList.append(player)
	ConfigurePlayer(player, index)
	add_child(player)
	SetNeuralNetworkName(player)
	return player

func ConfigurePlayer(player, index: int) -> void:
	player.name = "player" + str(index + 1)
	player.is_player = false
	player.training_mode = true
	player.ai_file = ""
	player.position = spawnPosition
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_audio_enabled(false)
	player.set_display_name("p-" + str(index + 1))

func SetNeuralNetworkName(player) -> void:
	if player.ai != null:
		var networkName: String = player.display_name if player.display_name != "" else player.name
		player.ai.name = networkName

func _input(event: InputEvent) -> void:
	if event.is_action_released("Kill"):
		KillThemAll()

func KillThemAll() -> void:
	for player in playerList:
		player.Dead()

func StartNextGeneration() -> void:
	for player in playerList:
		if player.ai != null:
			var fitness: float = player.get_training_fitness()
			if fitness > player.ai.fitness:
				player.ai.fitness = fitness

	UpdateBestAI()
	ResetFloor()
	SetupTheme()
	SetupPipes()
	CreateGeneration(bestNetworkData)
	UpdateTrainingCamera()

func GetBestPlayer():
	var bestPlayer = null
	var bestCurrentFitness: float = 0.0
	for player in playerList:
		if player.ai == null:
			continue
		var fitness: float = player.get_training_fitness()
		player.ai.fitness = fitness
		if fitness > bestCurrentFitness:
			bestCurrentFitness = fitness
			bestPlayer = player
	return bestPlayer

func UpdateBestAI() -> void:
	var bestPlayer = GetBestPlayer()
	if bestPlayer == null or bestPlayer.ai == null:
		return
	var currentFitness: float = bestPlayer.get_training_fitness()
	if currentFitness <= bestFitness:
		return
	bestFitness = currentFitness
	bestPlayer.ai.fitness = currentFitness
	bestPlayer.ai.bestFitness = currentFitness
	bestNetworkData = bestPlayer.ai.GetNetworkData()
	SaveBestAI()

func SaveBestAI() -> void:
	if bestNetworkData.is_empty() or saveFile == "":
		return
	var temp: NeuralNetwork = NeuralNetwork.new()
	temp.SetNetworkData(bestNetworkData)
	temp.fitness = bestFitness
	temp.bestFitness = bestFitness
	temp.SaveNetworkToFile("user://" + saveFile)

func LoadSavedBestAI() -> void:
	bestNetworkData = {}
	bestFitness = 0.0
	if saveFile == "":
		return
	var savePath: String = "user://" + saveFile
	if !FileAccess.file_exists(savePath):
		return
	var temp: NeuralNetwork = NeuralNetwork.new()
	temp.LoadNetworkFromFile(savePath)
	var savedNetworkData: Dictionary = temp.GetNetworkData()
	if !IsValidNetworkData(savedNetworkData):
		return
	bestFitness = temp.GetFitness()
	bestNetworkData = savedNetworkData

func ApplyNetwork(player, index: int, bestAIData: Dictionary) -> void:
	if player.ai == null:
		return
	if generation == 1 or bestAIData.is_empty():
		InitRandomNetwork(player.ai)
	elif index < GetBestKeepCount():
		InitBestNetwork(player.ai, bestAIData)
	elif index < GetBestKeepCount() + GetRandomNetworkCount():
		InitRandomNetwork(player.ai)
	else:
		InitMutatedBestNetwork(player.ai, bestAIData)
	player.ai.fitness = 0.0

func InitRandomNetwork(network: NeuralNetwork) -> void:
	network.Cleaner()
	ApplyNetworkSettings(network)
	network.InitLayers(GetNetworkLayers())
	ApplyNetworkValues(network)

func InitBestNetwork(network: NeuralNetwork, bestAIData: Dictionary) -> void:
	network.SetNetworkData(bestAIData)
	ApplyNetworkSettings(network)
	ApplyNetworkValues(network)

func InitMutatedBestNetwork(network: NeuralNetwork, bestAIData: Dictionary) -> void:
	InitBestNetwork(network, bestAIData)
	network.Mutate()

func GetBestKeepCount() -> int:
	return min(1, population)

func GetRandomNetworkCount() -> int:
	return min(10, max(0, population - GetBestKeepCount()))

func ApplyNetworkSettings(network: NeuralNetwork) -> void:
	network.startRandomization = startRandomization
	network.learningRate = learningRate
	network.bestFitness = networkBestFitness
	network.mutationFunction = mutationFunction
	network.activationFuction = activationFunction

func ApplyNetworkValues(network: NeuralNetwork) -> void:
	network.SetAllBias(bias)

func GetNetworkLayers() -> Array[int]:
	var layers: Array[int] = [AI_INPUT_COUNT]
	for neuronCount in hiddenLayers:
		layers.append(max(1, neuronCount))
	layers.append(1)
	return layers

func IsValidNetworkData(networkData: Dictionary) -> bool:
	if networkData.is_empty() or !networkData.has("layers"):
		return false
	return networkData.layers == GetNetworkLayers()

func ResetPlayer(player, index: int) -> void:
	player.position = spawnPosition
	player.visible = true
	player.set_audio_enabled(false)
	player.SetAlive()
	player.set_display_name("p-" + str(index + 1))
	SetNeuralNetworkName(player)

func FinishGenerationPreparation() -> void:
	isPreparingGeneration = false
	pendingBestNetworkData = {}
	for player in playerList:
		player.process_mode = Node.PROCESS_MODE_INHERIT
	lastAliveCount = playerList.size()
	popLabel.text = "Pop : " + str(lastAliveCount)
	generationStartDelay = 0.25
	UpdateTrainingCamera()

func ResetFloor() -> void:
	var floorNode := get_node_or_null("../floor")
	if floorNode == null:
		floorNode = get_node_or_null("floor")
	if floorNode == null:
		return
	for child in floorNode.get_children():
		if child.has_method("reset_floor"):
			child.reset_floor()

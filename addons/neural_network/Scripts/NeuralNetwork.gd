@icon("res://addons/neural_network/icon.svg")

class_name NeuralNetwork
extends Node

const Debugger :String =  "NN_Game_Debugger" 

enum MutationFunctions {NewRandomByLearningRate,MultiplyByTwo,MultiplyByLearningRate,MultiplyByZeroOne,MultiplyByZeroOnePlus,Custom,Default}
enum ActivationFuctions {Sigmoid,SigmoidDerivative,Tanh,TanhDerivative,ReLU,ReLUDerivative,ELU,ELUDerivative,Linear,LinearDerivative,Custom,Default}

@export var layers :Array[int] = [] # (Array,int)

var neurons :Array = []
var links :Array[Link] = []
var fastValues :Array[PackedFloat32Array] = []
var fastWeights :Array[PackedFloat32Array] = []
var fastBiases :Array[PackedFloat32Array] = []
var fastLinkActive :Array[PackedByteArray] = []
var fastNeuronActive :Array[PackedByteArray] = []
var fastCacheReady :bool = false

var isReady: bool= false

@export var fitness: float = 0.0 # Value will be saved and visible in the property editor.
@export var bestFitness: float = 0.0
@export var startRandomization: Vector2 = Vector2(-0.5,0.5)
@export var learningRate: Vector2 = Vector2(-0.1,0.1)

@export var mutationFunction: MutationFunctions= MutationFunctions.Default
@export var activationFuction: ActivationFuctions= ActivationFuctions.Default

func SetLayers(layers :Array) -> void:
	self.layers.clear()
	self.layers.assign(layers) 

func _enter_tree() -> void:
	randomize()
	self.InitLayers()
	if OS.is_debug_build():
		add_to_group(Debugger)
	pass

func GetFitness() -> float:
	return fitness

func GetBestFitness() -> float:
	return bestFitness

func SetFitness(value :float) -> void:
	self.fitness = value

func SetBestFitness(value :float) -> void:
	self.bestFitness = value

# warning-ignore:shadowed_variable
func SetBias(layer:int,neuron:int,bias:float) -> void:
	if(layer < layers.size()):
		if neuron < neurons[layer].size():
			for link in neurons[layer][neuron].links:
				link.bias = bias
			_MarkFastCacheDirty()
	pass

# warning-ignore:shadowed_variable
func SetAllBias(bias :float) -> void:
	for link in links:
		link.bias = bias
	_MarkFastCacheDirty()
	pass

func SetNeuronAction(layer:int,neuron:int,value:bool = true) -> void:
	if(layer < layers.size()):
		if neuron < neurons[layer].size():
			var tempStatus := Neuron.Status.Active
			if !value:
				tempStatus = Neuron.Status.Passive
			neurons[layer][neuron].status = tempStatus
			_MarkFastCacheDirty()

# warning-ignore:shadowed_variable
func SetAllNeuronsAction(value :bool = true) -> void:
	var tempStatus := Neuron.Status.Active
	if !value:
		tempStatus = Neuron.Status.Passive
	for layer in neurons:
		for neuron in layer:
			neuron.status = tempStatus
	_MarkFastCacheDirty()
	pass

func SetLearningRate(rate :Vector2) -> void:
	self.learningRate = rate
	pass
	
func GetLearningRate() -> Vector2:
	return self.learningRate
	
func SetStartRandomization(random :Vector2) -> void:
	self.startRandomization = random
	pass
	
func GetStartRandomization() -> Vector2:
	return self.startRandomization

func GetIsReady() -> bool:
	return self.isReady
	
# warning-ignore:shadowed_variable
func InitLayers(layers:Array = self.layers) -> void:
	if !isReady:
		if self.layers.size() <= 0:
			for item in layers:
				self.layers.append(item)
		_InitNeurons()
		_InitWeights()
		_RebuildFastCache()
		self.isReady = true
	pass

func _InitNeurons() -> void:
	for layer in range(self.layers.size()):
		self.neurons.append(Array())
		for neuron in range(layers[layer]):
			var tempNeuron :Neuron = Neuron.new()
			tempNeuron.value = randf_range(startRandomization.x,startRandomization.y)
			neurons[layer].append(tempNeuron)
			pass
	pass

func _InitWeights() -> void:
	for layer in range(1,self.layers.size()):
		for neuron in range(self.neurons[layer].size()):
			for from in range(neurons[layer-1].size()):
				var tempLink :Link = neurons[layer][neuron].SetLinkWithWeight(randf_range(startRandomization.x,startRandomization.y),neurons[layer-1][from])
				tempLink.from_ID = Vector2i(layer-1,from)
				tempLink.to_ID = Vector2i(layer,neuron)
				tempLink.from = neurons[tempLink.from_ID.x][tempLink.from_ID.y]
				tempLink.to = neurons[tempLink.to_ID.x][tempLink.to_ID.y]
				self.links.append(tempLink)
				pass
			pass
	pass

func Forward(input :Array,CustomFunction = null) -> Array[float]:
	if(self.isReady):
		
		if(input.size() != layers[0]):
			print("!!! Wrong input size for Neural Network !!!")
			return neurons.back()

		var activationType := activationFuction
		for layer in range(self.layers.size()):
			if layer == 0:
				for neuron in range(neurons[0].size()):
					neurons[0][neuron].value = input[neuron]
				pass
			else:
				for neuron in neurons[layer]:
					if(neuron.status == Neuron.Status.Passive):
						continue
					var value = 0.0
					for link in neuron.links:
						if link.status == Link.Status.Passive:
							continue
						value += link.weight * link.from.value + link.bias
						pass
					neuron.value = _ActivationFuction(value,activationType,CustomFunction)
					pass
		return neurons.back()
	else:
		print("Neural Network is not ready.")
	return neurons.back()
	pass

func FastForward(input :Array, CustomFunction = null, syncNeurons :bool = true) -> PackedFloat32Array:
	if !self.isReady:
		print("Neural Network is not ready.")
		return PackedFloat32Array()
	if(input.size() != layers[0]):
		print("!!! Wrong input size for Neural Network !!!")
		return fastValues.back() if fastValues.size() > 0 else PackedFloat32Array()
	if !fastCacheReady:
		_RebuildFastCache()
	var inputValues :PackedFloat32Array = fastValues[0]
	for neuron in range(inputValues.size()):
		inputValues[neuron] = input[neuron]
	fastValues[0] = inputValues
	var activationType := activationFuction
	for layer in range(1,self.layers.size()):
		var previousValues :PackedFloat32Array = fastValues[layer - 1]
		var currentValues :PackedFloat32Array = fastValues[layer]
		var weights :PackedFloat32Array = fastWeights[layer]
		var biases :PackedFloat32Array = fastBiases[layer]
		var linkActive :PackedByteArray = fastLinkActive[layer]
		var neuronActive :PackedByteArray = fastNeuronActive[layer]
		var previousCount :int = previousValues.size()
		for neuron in range(currentValues.size()):
			if neuronActive[neuron] == 0:
				continue
			var value :float = 0.0
			var baseIndex :int = neuron * previousCount
			for from in range(previousCount):
				var weightIndex :int = baseIndex + from
				if linkActive[weightIndex] == 0:
					continue
				value += weights[weightIndex] * previousValues[from] + biases[weightIndex]
			currentValues[neuron] = _ActivationFuction(value,activationType,CustomFunction)
		fastValues[layer] = currentValues
	if syncNeurons:
		_SyncFastValuesToNeurons()
	return fastValues.back()

func _MarkFastCacheDirty() -> void:
	fastCacheReady = false


## Public: rebuild SIMD-style caches after structural edits (links/neurons). See `FastForward`.
func RebuildFastCache() -> void:
	if not isReady:
		return
	_RebuildFastCache()


## Adds one neuron at the end of hidden layer [layer_index] (not input/output). Returns true on success.
func AppendNeuronToLayer(layer_index: int) -> bool:
	if not isReady:
		return false
	if layers.size() < 3:
		return false
	var L: int = layer_index
	if L < 1 or L >= layers.size() - 1:
		return false
	var new_idx: int = neurons[L].size()
	var new_neuron := Neuron.new()
	new_neuron.value = randf_range(startRandomization.x, startRandomization.y)
	new_neuron.status = Neuron.Status.Active
	new_neuron.ID = Vector2i(L, new_idx)
	neurons[L].append(new_neuron)
	layers[L] = int(layers[L]) + 1
	for from_i in range(neurons[L - 1].size()):
		var temp_link: Link = new_neuron.SetLinkWithWeight(
			randf_range(startRandomization.x, startRandomization.y),
			neurons[L - 1][from_i]
		)
		temp_link.from_ID = Vector2i(L - 1, from_i)
		temp_link.to_ID = Vector2i(L, new_idx)
		temp_link.from = neurons[temp_link.from_ID.x][temp_link.from_ID.y]
		temp_link.to = neurons[temp_link.to_ID.x][temp_link.to_ID.y]
		links.append(temp_link)
	for next_i in range(neurons[L + 1].size()):
		var temp_link2: Link = neurons[L + 1][next_i].SetLinkWithWeight(
			randf_range(startRandomization.x, startRandomization.y),
			new_neuron
		)
		temp_link2.from_ID = Vector2i(L, new_idx)
		temp_link2.to_ID = Vector2i(L + 1, next_i)
		temp_link2.from = neurons[temp_link2.from_ID.x][temp_link2.from_ID.y]
		temp_link2.to = neurons[temp_link2.to_ID.x][temp_link2.to_ID.y]
		links.append(temp_link2)
	_MarkFastCacheDirty()
	return true


func _RebuildFastCache() -> void:
	fastValues.clear()
	fastWeights.clear()
	fastBiases.clear()
	fastLinkActive.clear()
	fastNeuronActive.clear()
	for layer in range(self.layers.size()):
		var layerValues := PackedFloat32Array()
		layerValues.resize(neurons[layer].size())
		var layerNeuronActive := PackedByteArray()
		layerNeuronActive.resize(neurons[layer].size())
		for neuron in range(neurons[layer].size()):
			layerValues[neuron] = neurons[layer][neuron].value
			layerNeuronActive[neuron] = 1 if neurons[layer][neuron].status == Neuron.Status.Active else 0
		fastValues.append(layerValues)
		fastNeuronActive.append(layerNeuronActive)
		if layer == 0:
			fastWeights.append(PackedFloat32Array())
			fastBiases.append(PackedFloat32Array())
			fastLinkActive.append(PackedByteArray())
			continue
		var previousCount :int = neurons[layer - 1].size()
		var linkCount :int = previousCount * neurons[layer].size()
		var layerWeights := PackedFloat32Array()
		var layerBiases := PackedFloat32Array()
		var layerLinkActive := PackedByteArray()
		layerWeights.resize(linkCount)
		layerBiases.resize(linkCount)
		layerLinkActive.resize(linkCount)
		for neuron in range(neurons[layer].size()):
			for link in neurons[layer][neuron].links:
				var fromIndex :int = link.from_ID.y
				if fromIndex < 0 or fromIndex >= previousCount:
					continue
				var weightIndex :int = neuron * previousCount + fromIndex
				layerWeights[weightIndex] = link.weight
				layerBiases[weightIndex] = link.bias
				layerLinkActive[weightIndex] = 1 if link.status == Link.Status.Active else 0
		fastWeights.append(layerWeights)
		fastBiases.append(layerBiases)
		fastLinkActive.append(layerLinkActive)
	fastCacheReady = true

func _SyncFastValuesToNeurons() -> void:
	for layer in range(fastValues.size()):
		var layerValues :PackedFloat32Array = fastValues[layer]
		for neuron in range(layerValues.size()):
			neurons[layer][neuron].value = layerValues[neuron]

func _ActivationFuction(value :float, ActivationType :int = activationFuction, CustomFunction = null) -> float:
	var result :float = 0.0
	match(ActivationType):
		ActivationFuctions.Sigmoid:
			result = 1.0 / (1.0 + exp(-value))
		ActivationFuctions.SigmoidDerivative:
			var sigmoid := 1.0 / (1.0 + exp(-value))
			result = sigmoid * (1.0 - sigmoid)
		ActivationFuctions.Tanh:
			result = tanh(value)
		ActivationFuctions.TanhDerivative:
			var t := tanh(value)
			result = 1.0 - (t * t)
		ActivationFuctions.ReLUDerivative:
			if value > 0:
				result = 1
			else:
				result = 0
		ActivationFuctions.ReLU:
			result = max(0,value)
		ActivationFuctions.ELU:
			if value >= 0:
				result = value
			else:
				result = exp(value)-1
		ActivationFuctions.ELUDerivative:
			if value >= 0:
				result = 1
			else:
				result = exp(value)
		ActivationFuctions.Linear:
			result = value
		ActivationFuctions.LinearDerivative:
			result = 1
		ActivationFuctions.Custom:
			if (CustomFunction):
				result = CustomFunction.call_func(value)
		ActivationFuctions.Default:
			result = 1.0 / (1.0 + exp(-value))
	return result
	pass

func Mutate(MutationFunction:int = mutationFunction,CustomFunction = null) -> void:
	for link in links:
		link.weight = _MutateFunction(link.weight,MutationFunction,CustomFunction)
	_MarkFastCacheDirty()
	pass

func _MutateFunction(weight :float,MutationType :int,CustomFunction = null) -> float:
	var result :float = 0.0
	match(MutationType):
		MutationFunctions.MultiplyByTwo:
			result = weight*2
		MutationFunctions.MultiplyByLearningRate:
			result = weight * randf_range(learningRate.x,learningRate.y)
		MutationFunctions.NewRandomByLearningRate:
			result =randf_range(learningRate.x,learningRate.y)
		MutationFunctions.MultiplyByZeroOne:
			result = weight * randf_range(0.0,1.0)
		MutationFunctions.MultiplyByZeroOnePlus:
			result = weight * (randf_range(0.0,1.0)+1.0)
		MutationFunctions.Custom:
			if (CustomFunction):
				result = CustomFunction.call_func(weight)
		MutationFunctions.Default:
			result = randf_range(learningRate.x,learningRate.y)
	return result
	pass

#### Save Network #####

func SaveNetworkToFile(path: String, password: String = "") -> void:
	var data :Dictionary = GetNetworkData()
	var jsonData = JSON.stringify(data)
	var file :FileAccess = null
	if password != "":
		file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE,password)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	file.store_var(jsonData)
	pass

func LoadNetworkFromFile(path :String, password: String = "") -> void:
	var file :FileAccess = null
	var doFileExists :bool = FileAccess.file_exists(path)
	if(doFileExists):
		if password != "":
			file  = FileAccess.open_encrypted_with_pass(path, FileAccess.READ,password)
		else:
			file = FileAccess.open(path, FileAccess.READ)
		var data = file.get_var()
		Cleaner()
		SetNetworkData(JSON.parse_string(data))
		self.isReady = true
	pass

func GetNetworkData() -> Dictionary:
	var tempNeuronDataArray  :Array = []
	for layer in range(layers.size()):
		tempNeuronDataArray.append(Array())
		for neuron in neurons[layer]:
			tempNeuronDataArray[layer].append(neuron.GetNeuronData())
			
	var data :Dictionary= {
		layers = self.layers,
		neurons = tempNeuronDataArray,
		fitness = self.fitness,
		bestFitness = self.bestFitness,
		startRandomization = self.startRandomization,
		learningRate  = self.learningRate,
		mutationFunction = self.mutationFunction,
		activationFuction  = self.activationFuction,
		isReady = self.isReady
	}
	return data
	pass

func SetNetworkData(data :Dictionary) -> void:
	Cleaner()
	if data.layers:
		SetLayers(data.layers)
	if data.neurons:
		for layer in range(data.layers.size()):
			self.neurons.append(Array())
			for neuron in data.neurons[layer]:
				var tempNeuron :Neuron = Neuron.new()
				tempNeuron.value = neuron.value
				tempNeuron.status = neuron.status
				for link in neuron.links:
					var tempLink :Link = Link.new()
					tempLink.setData(link)
					tempLink.from= self.neurons[tempLink.from_ID.x][tempLink.from_ID.y]
					tempLink.to = tempNeuron
					tempNeuron.SetLink(tempLink)
					self.links.append(tempLink)
					pass
				self.neurons[layer].append(tempNeuron)
				pass
	if data.fitness:
		self.fitness = data.fitness
	if data.bestFitness:
		self.bestFitness = data.bestFitness
	if data.startRandomization:
		self.startRandomization = str_to_var("Vector2" + str(data.startRandomization))
	if data.learningRate:
		self.learningRate = str_to_var("Vector2" + str(data.learningRate))
	if data.mutationFunction:
		self.mutationFunction = data.mutationFunction
	if data.activationFuction:
		self.activationFuction = data.activationFuction
	if data.isReady:
		self.isReady = data.isReady
	_RebuildFastCache()
	pass

func Cleaner()  -> void:
	self.isReady = false
	self.layers  = []
	self.neurons = []
	self.links = []
	self.fastValues = []
	self.fastWeights = []
	self.fastBiases = []
	self.fastLinkActive = []
	self.fastNeuronActive = []
	self.fastCacheReady = false
	self.fitness  = 0
	self.bestFitness  = 0
	self.startRandomization  = Vector2(-0.5,0.5)
	self.learningRate  = Vector2(-0.1,0.1)
	self.mutationFunction = MutationFunctions.Default
	self.activationFuction  = ActivationFuctions.Default
	pass

func CopyFrom(neuralNetwork :NeuralNetwork)  -> void:
	Cleaner()
	SetNetworkData(neuralNetwork.GetNetworkData())
	pass

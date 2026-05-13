extends Control

@onready var list :ItemList = get_node("NeuralNetworkList")
@onready var addLayers  :GridContainer = get_node("View/ScrollContainer/AddLayers")
var layerFile = load("res://addons/neural_network/Editor/Layer.tscn")

var neuralNetwork :NeuralNetwork 

var layers :Array
var weight :Array
var nodeList :Array = Array()

func _ready():
	list.connect("item_activated",Callable(self,"change_in_list"))
	pass

func initNetwork(neuralNetwork):
	addLayers.columns = neuralNetwork.layers.size()
	self.neuralNetwork = neuralNetwork
	for layer in range(neuralNetwork.layers.size()):
		var layerIns = layerFile.instantiate()
		layerIns.ID = layer
		addLayers.add_child(layerIns)
		layers.append(layerIns)
		for neuron in range(neuralNetwork.layers[layer]):
			var temp :Panel
			if(layer == 0):
				temp = layerIns.AddNeuron(neuralNetwork.neurals[layer][neuron],Color.GOLDENROD,Vector2(0,0))
			elif(layer == neuralNetwork.layers.size()-1):
				temp = layerIns.AddNeuron(neuralNetwork.neurals[layer][neuron],Color.BROWN,Vector2(0,0))
			else:
				temp = layerIns.AddNeuron(neuralNetwork.neurals[layer][neuron],Color.FOREST_GREEN,Vector2(layer,neuron))
			temp.connect("On_Click",Callable(self,"On_Click_Neuron"))
			
	for layer in range(1,neuralNetwork.layers.size()):
		for neuron in neuralNetwork.neurals[layer].size():
			for neuronWeight in range(neuralNetwork.layers[layer-1]):
				layers[layer].GetNeuron(neuron).AddNewWeight(neuralNetwork.weights[layer][neuron][neuronWeight],
				Vector2(-110,110*(neuronWeight-neuron)))
				if(!neuralNetwork.GetAllNeuronsAction()[layer][neuron]):
					layers[layer].GetNeuron(neuron).SetDisabled()
				pass
			pass
	pass
	
func SetNeuralValues(neuralNetwork = self.neuralNetwork):
	if neuralNetwork.GetIsReady():
		for layer in range(neuralNetwork.layers.size()):
			for neuron in range(neuralNetwork.layers[layer]):
				layers[layer].GetNeuron(neuron).SetValue(neuralNetwork.neurals[layer][neuron])
				pass
	pass

func removeAll():
	for child in addLayers.get_children():
		child.queue_free()
		pass
	pass
	
	
func change_in_list(id):
	var node = nodeList[id]
	#print(node.has_method("GetIsReady"))
	if node.has_method("GetIsReady") && node.GetIsReady():
		initNetwork(node)
	pass

func AddtoList(node):
	if(list):
		list.clear()
	nodeList = node
	for item in nodeList:
		list.add_item(item.name,get_theme_icon("GraphNode", "EditorIcons"))
		pass
	if(nodeList.size()>0):
		list.select(0)
	pass

func On_Click_Neuron(NeuronNode):
	neuralNetwork.SetNeuronAction(NeuronNode.ID.x,NeuronNode.ID.y,NeuronNode.isActive)
	pass

extends Window

@onready var list: ItemList = get_node("NeuralNetworkList")
@onready var view: GraphEdit  = get_node("View")

var neuronFile: PackedScene = preload("res://addons/neural_network/Editor/Neuron.tscn")

var neuralNetwork :NeuralNetwork

var AllNetworks : Array 
var nodeNeurons :Array[GraphNode]
var nodeNameByID :Dictionary = {}


var run :bool = false
const UPDATE_INTERVAL := 0.1
const LIST_REFRESH_INTERVAL := 1.0
var updateTimer :float = 0.0
var listRefreshTimer :float = 0.0
var networkListSignature :String = ""

func _ready() -> void:
	list.connect("item_activated",Callable(self,"change_in_list"))
	RefreshNetworkList(true)
	pass

func _process(delta) -> void:
	if !visible:
		return
	listRefreshTimer += delta
	if listRefreshTimer >= LIST_REFRESH_INTERVAL:
		listRefreshTimer = 0.0
		RefreshNetworkList()
	if !run or !neuralNetwork or !neuralNetwork.GetIsReady():
		return
	updateTimer += delta
	if updateTimer < UPDATE_INTERVAL:
		return
	updateTimer = 0.0
	SetNeuralValues()
	pass

func initNetwork(neuralNetwork) -> void:
	run = false
	removeAll()
	self.neuralNetwork = neuralNetwork
	for layer in range(neuralNetwork.layers.size()):
		for neuron in range(neuralNetwork.layers[layer]):
			var tempNeuronNode :GraphNode
			if(layer == 0):
				tempNeuronNode = AddNeuron(neuralNetwork.neurons[layer][neuron],Vector2i(layer,neuron),Color.GOLDENROD)
				tempNeuronNode.SetAsInput()
			elif(layer == neuralNetwork.layers.size()-1):
				tempNeuronNode = AddNeuron(neuralNetwork.neurons[layer][neuron],Vector2i(layer,neuron),Color.BROWN)
				tempNeuronNode.SetAsOutput()
			else:
				tempNeuronNode = AddNeuron(neuralNetwork.neurons[layer][neuron],Vector2i(layer,neuron),Color.FOREST_GREEN)
			nodeNeurons.append(tempNeuronNode)
			nodeNameByID[Vector2i(layer,neuron)] = tempNeuronNode.name
	for link in neuralNetwork.links:
		ConnectLink(link)
	run = true
	SetNeuralValues()
	
func ConnectLink(link :Link) -> void:
	if link.status != Link.Status.Active:
		return
	var fromName = nodeNameByID.get(link.from_ID, "")
	var toName = nodeNameByID.get(link.to_ID, "")
	if fromName == "" or toName == "":
		return
	view.connect_node(fromName,0,toName,0)

func SetNeuralValues(neuralNetwork = self.neuralNetwork) -> void:
	for nodeNeuron in nodeNeurons:
		if run and nodeNeuron != null:
			nodeNeuron.SetValue()
	pass

func removeAll() -> void:
	self.run = false
	nodeNeurons.clear()
	nodeNameByID.clear()
	view.clear_connections()
	#
	for child in view.get_children():
		if child is GraphNode:
			view.remove_child(child)
			child.free()
	pass

func change_in_list(id) -> void:
	var node :NeuralNetwork = self.AllNetworks[id]
	if node.has_method("GetIsReady") && node.GetIsReady():
		initNetwork(node)
	pass

func initGroupNN() -> void:
	self.AllNetworks = get_tree().get_nodes_in_group(NeuralNetwork.Debugger)
	for item in self.AllNetworks:
		if item.isReady:
			list.add_item(item.name,load("res://addons/neural_network/icon.svg"))
		else:
			list.add_item(item.name,null,false)
		pass
	pass

func RefreshNetworkList(force :bool = false) -> void:
	var networks :Array = get_tree().get_nodes_in_group(NeuralNetwork.Debugger)
	var signature :String = _GetNetworkListSignature(networks)
	if !force and signature == networkListSignature:
		return
	var selectedNetwork :NeuralNetwork = neuralNetwork
	list.clear()
	AllNetworks = networks
	networkListSignature = signature
	var selectedIndex :int = -1
	for index in range(AllNetworks.size()):
		var item :NeuralNetwork = AllNetworks[index]
		if item.GetIsReady():
			list.add_item(item.name,load("res://addons/neural_network/icon.svg"))
		else:
			list.add_item(item.name,null,false)
		if item == selectedNetwork:
			selectedIndex = index
	if selectedIndex >= 0:
		list.select(selectedIndex)
	elif selectedNetwork != null:
		neuralNetwork = null
		removeAll()

func _GetNetworkListSignature(networks :Array) -> String:
	var signature :String = ""
	for item in networks:
		signature += str(item.get_instance_id()) + ":" + item.name + ":" + str(item.GetIsReady()) + ";"
	return signature

func AddNeuron(neuron :Neuron,neuronID :Vector2i = Vector2.ZERO, color :Color = Color.WHITE) -> GraphNode:
	var neuronIns :GraphNode = neuronFile.instantiate()
	neuronIns.SetData(neuron)
	neuronIns.SetID(neuronID)
	neuronIns.ChangeColor(color)
	neuronIns.position_offset = neuronID * 200
	neuronIns.name = _NeuronNodeName(neuronID)
	view.add_child(neuronIns)
	neuronIns.connect("On_Click",Callable(self,"On_Click_Neuron"))
	return neuronIns
	pass

func _NeuronNodeName(neuronID :Vector2i) -> String:
	return "NeuronNode*" + str(neuronID)

func _on_NeuralNetworkList_item_selected(index) -> void:
	self.run = false
	change_in_list(index)
	self.run = true
	pass 

func _on_Refresh_pressed() -> void:
	RefreshNetworkList(true)
	pass

func _on_game_debugger_about_to_popup() -> void:
	hide()
	removeAll()
	pass

func _on_close_requested() -> void:
	hide()
	removeAll()
	pass 

func _on_view_connection_request(from_node, from_port, to_node, to_port):

	var splitFrom = (from_node as String).split("*")[1]
	var splitTo = (to_node as String).split("*")[1]

	for link in neuralNetwork.links:
		if (str(link.from_ID) == splitFrom) &&  (str(link.to_ID) == splitTo):
			neuralNetwork.neurons[link.from_ID.x][link.from_ID.y].links.erase(link)
			neuralNetwork.neurons[link.to_ID.x][link.to_ID.y].links.erase(link)
			neuralNetwork.links.erase(link)
			neuralNetwork._MarkFastCacheDirty()
			view.disconnect_node(from_node, from_port, to_node, to_port)
			return
	var newLink :Link = Link.new()
	newLink.setData({
		status = Link.Status.Active,
		weight = 0.5,
		bias = 0.0,
		from_ID = splitFrom,
		to_ID = splitTo,
	})
	
	neuralNetwork.links.append(newLink)
	newLink.from = neuralNetwork.neurons[newLink.from_ID.x][newLink.from_ID.y]
	newLink.to = neuralNetwork.neurons[newLink.to_ID.x][newLink.to_ID.y]
	newLink.to.SetLink(newLink)
	neuralNetwork._MarkFastCacheDirty()
	view.connect_node(from_node, from_port, to_node, to_port)
	pass # Replace with function body.

func _on_view_disconnection_request(from_node, from_port, to_node, to_port):
	pass # Replace with function body.

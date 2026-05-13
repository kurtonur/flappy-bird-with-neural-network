@tool
extends EditorPlugin

const version = "0.5.4"

@onready var interface = get_editor_interface()
@onready var selection = interface.get_selection()


func _enter_tree():
	assert(Engine.get_version_info().major >= 4)
	print("Neural Network Plugin Activated")
	add_custom_type("NeuralNetwork","Node",load("res://addons/neural_network/Scripts/NeuralNetwork.gd"),load("res://addons/neural_network/icon.svg"))
	add_custom_type("NEATNetwork","Node",load("res://addons/neural_network/Scripts/NEATNetwork.gd"),load("res://addons/neural_network/icon.svg"))
	#add_custom_type("Neuron","Node",load("res://addons/neural_network/Scripts/Neuron.gd"),load("res://addons/neural_network/icon.svg"))
	#add_custom_type("Link","Node",load("res://addons/neural_network/Scripts/Link.gd"),load("res://addons/neural_network/icon.svg"))
	add_custom_type("NNDebugger","Node",load("res://addons/neural_network/Scripts/NNDebugger.gd"),load("res://addons/neural_network/icon.svg"))
	pass

func _exit_tree():
	print("Neural Network Plugin Deactivated")
	remove_custom_type("NeuralNetwork")
	remove_custom_type("NEATNetwork")
	#remove_custom_type("Neuron")
	#remove_custom_type("Link")
	remove_custom_type("NNDebugger")
	pass

func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_icon("GraphNode", "EditorIcons")

func _get_plugin_name():
	return "NeuralNetwork"
	pass

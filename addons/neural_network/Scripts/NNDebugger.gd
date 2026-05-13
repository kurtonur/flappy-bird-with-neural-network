@icon("res://addons/neural_network/icon.svg")
extends Node

class_name NNDebugger


const debugger: String = "res://addons/neural_network/Editor/NN_Debugger.tscn"

var panel :Window = null

func _init():
	if OS.is_debug_build():
		panel = preload(debugger).instantiate()
		add_child(panel)
	pass

func _input(event):
	if event is InputEventKey and event.pressed:
		if Input.is_action_pressed("ui_text_indent"):
			if !panel.visible:
				panel.show()
			else:
				panel.hide()
	pass

extends GraphNode

var ID :Vector2 = Vector2.ZERO 

var data :Neuron = Neuron.new()

signal On_Click

var baseColor :Color = Color.WHITE
var disableColor :Color = Color.NAVY_BLUE

@onready var valueLabel :Label = get_node("Value")
var lastValueText :String = ""

func SetData(data :Neuron) ->void:
	self.data = data
	pass

func SetDataValue(value :float) ->void:
	self.data.value = value
	_SetValueText(value)
	if(ID.x != 0 and self.data.status == Neuron.Status.Active):
		BgColorChangingByValue(value)
	pass
	
func SetValue() ->void:
	_SetValueText(data.value)
	if(ID.x != 0 and self.data.status == Neuron.Status.Active):
		BgColorChangingByValue(data.value)
	pass

func _SetValueText(value :float) -> void:
	var valueText := str(snapped(value,0.001))
	if valueText == lastValueText:
		return
	if valueLabel == null:
		valueLabel = get_node("Value")
	valueLabel.text = valueText
	lastValueText = valueText

func SetAsInput(value :bool = true)-> void:
	set("slot/0/left_enabled",!value)
	pass

func SetAsOutput(value :bool = true)-> void:
	set("slot/0/right_enabled",!value)
	pass

func SetID(value :Vector2) -> void:
	self.ID = value
	pass

func ChangeColor(color:Color) -> void:
	#set("custom_styles/panel/bg_color",color)
	baseColor = color
	modulate = color
	pass

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# Double-click on non-input: toggle Active / Passive (training soft-off).
	if ID.x != 0 and mb.double_click:
		if data.status == Neuron.Status.Active:
			data.status = Neuron.Status.Passive
		else:
			data.status = Neuron.Status.Active
	CheckClick()
	emit_signal("On_Click", self)

func SetDisabled(value:bool = false) -> void:
	self.isActive = value
	CheckClick()
	pass

func CheckClick() -> void:
	if(self.data.status == Neuron.Status.Active):
		modulate = baseColor
		pass
	else:
		modulate = disableColor
		pass
	pass

func BgColorChangingByValue(value) -> void:
	if value < 0:
		modulate = baseColor/2
		modulate.a = 1.0
	else:
		modulate = baseColor

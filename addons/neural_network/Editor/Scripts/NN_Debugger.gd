extends Window

@onready var list: ItemList = get_node("NeuralNetworkList")
@onready var view: GraphEdit  = get_node("View")

var neuronFile: PackedScene = preload("res://addons/neural_network/Editor/Neuron.tscn")

var neuralNetwork :NeuralNetwork

var AllNetworks : Array 
var nodeNeurons :Array[GraphNode]
var nodeNameByID :Dictionary = {}


var run :bool = false
## When false, graph stops refreshing neuron values (training can keep running).
var value_tracking_enabled :bool = true
var selected_neuron_id :Vector2i = Vector2i(-1, -1)

const UPDATE_INTERVAL := 0.1
const LIST_REFRESH_INTERVAL := 1.0
## Classic MLP diagram: columns left→right, neurons centered vertically per layer.
const GRAPH_LAYER_GAP_X := 240.0
const GRAPH_NEURON_GAP_Y := 96.0
## Padding factor when fitting the whole NN graph into the GraphEdit viewport (0–1).
const GRAPH_FIT_MARGIN := 0.88
## Shift whole stack from graph origin (graph space); scaled by theme. E.g. clear toolbar / minimap overlap.
@export var graph_layout_center_offset: Vector2 = Vector2(56.0, 80.0)

var updateTimer :float = 0.0
var listRefreshTimer :float = 0.0
var networkListSignature :String = ""

var track_values_button :Button
var layer_spin :SpinBox
var ref_layer_spin :SpinBox
var new_hidden_size_spin :SpinBox
var add_neuron_button :Button
var remove_neuron_button :Button
var insert_after_button :Button
var insert_before_button :Button
var selection_label :Label
var graph_toolbar_root :MarginContainer
var _toolbar_panel :PanelContainer
var _graph_fit_pending :bool = false

## GraphEdit places its zoom/grid menu at (10, 10); keep our toolbar just under that strip.
func _graph_edit_menu_left() -> float:
	return 10.0 * view.get_theme_default_base_scale()


func _graph_edit_menu_bottom_y() -> float:
	var scale: float = view.get_theme_default_base_scale()
	var menu_y := 10.0 * scale
	var row_h := 34.0 * scale
	var sb: StyleBox = view.get_theme_stylebox("menu_panel", "GraphEdit")
	if sb != null:
		row_h = max(row_h, sb.get_minimum_size().y)
	return menu_y + row_h + 6.0 * scale


func _refresh_graph_toolbar_position() -> void:
	if not is_instance_valid(graph_toolbar_root) or graph_toolbar_root.get_parent() != view:
		return
	graph_toolbar_root.offset_left = _graph_edit_menu_left()
	graph_toolbar_root.offset_top = _graph_edit_menu_bottom_y()


func _ready() -> void:
	_build_edit_toolbar()
	list.connect("item_activated",Callable(self,"change_in_list"))
	RefreshNetworkList(true)
	theme_changed.connect(_apply_toolbar_card_theme)
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply_toolbar_card_theme()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_graph_toolbox_visibility()
		if visible and run and neuralNetwork != null:
			_schedule_center_graph_view_fit_zoom()


## Card style: prefer GraphEdit menu strip (zoom/grid), then ItemList / PanelContainer theme panels.
func _make_toolbar_card_stylebox() -> StyleBox:
	var ref: Control = list
	var scale: float = view.get_theme_default_base_scale()
	var g: StyleBox = view.get_theme_stylebox("menu_panel", "GraphEdit")
	if g != null:
		var dup: StyleBox = g.duplicate()
		if dup is StyleBoxFlat:
			var f: StyleBoxFlat = dup as StyleBoxFlat
			var pad := 5.0 * scale
			f.content_margin_left = maxf(f.content_margin_left, pad + 2.0)
			f.content_margin_top = maxf(f.content_margin_top, pad)
			f.content_margin_right = maxf(f.content_margin_right, pad + 2.0)
			f.content_margin_bottom = maxf(f.content_margin_bottom, pad)
		return dup
	var list_panel: StyleBox = ref.get_theme_stylebox("panel", "ItemList")
	if list_panel != null:
		return list_panel.duplicate()
	var pc: StyleBox = ref.get_theme_stylebox("panel", "PanelContainer")
	if pc != null:
		return pc.duplicate()
	var fb := StyleBoxFlat.new()
	var fg := ref.get_theme_color("font_color", "Label")
	fb.bg_color = fg.darkened(0.88)
	fb.bg_color.a = 0.94
	var border: Color = fg.lerp(fb.bg_color, 0.55)
	border.a = 0.72
	if ref.has_theme_color("accent_color", "Editor"):
		border = ref.get_theme_color("accent_color", "Editor")
		border.a = 0.55
	fb.border_color = border
	fb.set_border_width_all(maxi(1, int(round(scale))))
	fb.set_corner_radius_all(int(round(6.0 * scale)))
	var pad2 := 5.0 * scale
	fb.content_margin_left = pad2 + 2.0
	fb.content_margin_top = pad2
	fb.content_margin_right = pad2 + 2.0
	fb.content_margin_bottom = pad2
	return fb


func _apply_toolbar_card_theme() -> void:
	if not is_instance_valid(_toolbar_panel):
		return
	var st: StyleBox = _make_toolbar_card_stylebox()
	if st != null:
		_toolbar_panel.add_theme_stylebox_override("panel", st)
	_apply_toolbar_toolbox_buttons_theme()


func _get_toolbar_panel_bg_color() -> Color:
	if is_instance_valid(_toolbar_panel):
		var psb: StyleBox = _toolbar_panel.get_theme_stylebox("panel", "PanelContainer")
		if psb is StyleBoxFlat:
			return (psb as StyleBoxFlat).bg_color
	var ref: Control = list
	var fg: Color = ref.get_theme_color("font_color", "Label")
	var c: Color = fg.darkened(0.88)
	c.a = 0.94
	return c


func _toolbar_button_border_color(bg: Color) -> Color:
	if is_instance_valid(_toolbar_panel):
		var psb: StyleBox = _toolbar_panel.get_theme_stylebox("panel", "PanelContainer")
		if psb is StyleBoxFlat:
			return (psb as StyleBoxFlat).border_color
	var ref: Control = list
	var fg: Color = ref.get_theme_color("font_color", "Label")
	var b: Color = fg.lerp(bg, 0.55)
	b.a = 0.72
	if ref.has_theme_color("accent_color", "Editor"):
		b = ref.get_theme_color("accent_color", "Editor")
		b.a = 0.55
	return b


func _make_toolbar_button_stylebox(scale: float, bg: Color, border: Color, disabled: bool = false) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	var use_bg := bg
	if disabled:
		use_bg = use_bg.darkened(1.12)
		use_bg.a = minf(use_bg.a, 0.88)
	f.bg_color = use_bg
	f.border_color = border.darkened(0.92) if disabled else border
	f.set_border_width_all(maxi(1, int(round(scale))))
	f.set_corner_radius_all(int(round(4.0 * scale)))
	var m := 3.0 * scale
	f.content_margin_left = m
	f.content_margin_top = m * 0.65
	f.content_margin_right = m
	f.content_margin_bottom = m * 0.65
	return f


func _style_single_toolbar_button(btn: Button, scale_tb: float) -> void:
	if btn == null:
		return
	var bg: Color = _get_toolbar_panel_bg_color()
	var border: Color = _toolbar_button_border_color(bg)
	var n := _make_toolbar_button_stylebox(scale_tb, bg, border, false)
	var h: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	var p: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	var d := _make_toolbar_button_stylebox(scale_tb, bg, border, true)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("disabled", d)
	var font_c: Color = list.get_theme_color("font_color", "Label")
	btn.add_theme_color_override("font_color", font_c)
	btn.add_theme_color_override("font_hover_color", font_c)
	btn.add_theme_color_override("font_pressed_color", font_c)
	btn.add_theme_color_override("font_focus_color", font_c)
	btn.add_theme_color_override("font_hover_pressed_color", font_c)
	btn.add_theme_color_override("font_disabled_color", font_c.darkened(1.45))


func _apply_toolbar_toolbox_buttons_theme() -> void:
	if not is_instance_valid(view):
		return
	var s: float = view.get_theme_default_base_scale()
	_style_single_toolbar_button(track_values_button, s)
	_style_single_toolbar_button(remove_neuron_button, s)
	_style_single_toolbar_button(add_neuron_button, s)
	_style_single_toolbar_button(insert_after_button, s)
	_style_single_toolbar_button(insert_before_button, s)


func _raise_graph_toolbar() -> void:
	if not is_instance_valid(graph_toolbar_root) or graph_toolbar_root.get_parent() != view:
		return
	view.move_child(graph_toolbar_root, view.get_child_count() - 1)
	_refresh_graph_toolbar_position()


func _update_graph_toolbox_visibility() -> void:
	if not is_instance_valid(graph_toolbar_root):
		return
	graph_toolbar_root.visible = run and neuralNetwork != null and neuralNetwork.GetIsReady()


func _build_edit_toolbar() -> void:
	var margin := MarginContainer.new()
	graph_toolbar_root = margin
	margin.name = "GraphEditToolbar"
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 0.0
	margin.anchor_bottom = 0.0
	margin.offset_left = _graph_edit_menu_left()
	margin.offset_top = _graph_edit_menu_bottom_y()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	view.add_child(margin)
	view.resized.connect(_refresh_graph_toolbar_position)
	view.resized.connect(_schedule_center_graph_view_fit_zoom)

	var panel := PanelContainer.new()
	_toolbar_panel = panel
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_toolbar_card_theme()
	margin.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 3)
	panel.add_child(outer)

	var scale_tb: float = view.get_theme_default_base_scale()
	var fs_tb: int = maxi(9, int(round(10.0 * scale_tb)))

	# Row 1: live values | selection (ellipsis) | remove
	var row_live := HBoxContainer.new()
	row_live.add_theme_constant_override("separation", 4)
	outer.add_child(row_live)

	track_values_button = Button.new()
	track_values_button.text = "Live: ON"
	track_values_button.focus_mode = Control.FOCUS_NONE
	track_values_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track_values_button.tooltip_text = "Only pauses value labels on the graph, not the game simulation."
	track_values_button.add_theme_font_size_override("font_size", fs_tb)
	track_values_button.pressed.connect(_on_track_values_pressed)
	row_live.add_child(track_values_button)

	row_live.add_child(VSeparator.new())

	selection_label = Label.new()
	selection_label.text = "— Click neuron —"
	selection_label.clip_text = true
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selection_label.custom_minimum_size = Vector2(72, 0)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selection_label.focus_mode = Control.FOCUS_NONE
	selection_label.add_theme_font_size_override("font_size", fs_tb)
	row_live.add_child(selection_label)

	remove_neuron_button = Button.new()
	remove_neuron_button.text = "Remove"
	remove_neuron_button.focus_mode = Control.FOCUS_NONE
	remove_neuron_button.disabled = true
	remove_neuron_button.tooltip_text = "Removes the neuron selected on the graph (hidden/green only). Deletes its links and may drop an empty layer."
	remove_neuron_button.add_theme_font_size_override("font_size", fs_tb)
	remove_neuron_button.pressed.connect(_on_remove_neuron_pressed)
	row_live.add_child(remove_neuron_button)

	# Row 2: add neuron to hidden layer
	var row_add := HBoxContainer.new()
	row_add.add_theme_constant_override("separation", 4)
	outer.add_child(row_add)

	var layer_lbl := Label.new()
	layer_lbl.text = "L"
	layer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer_lbl.tooltip_text = "Hidden layer index for Add neuron."
	layer_lbl.add_theme_font_size_override("font_size", fs_tb)
	row_add.add_child(layer_lbl)

	layer_spin = SpinBox.new()
	layer_spin.min_value = 1.0
	layer_spin.max_value = 1.0
	layer_spin.value = 1.0
	layer_spin.rounded = true
	layer_spin.custom_minimum_size = Vector2(44, 0)
	layer_spin.focus_mode = Control.FOCUS_NONE
	layer_spin.tooltip_text = "Hidden layer index for Add neuron (1 = first hidden column)."
	layer_spin.add_theme_font_size_override("font_size", fs_tb)
	row_add.add_child(layer_spin)

	add_neuron_button = Button.new()
	add_neuron_button.text = "Add"
	add_neuron_button.focus_mode = Control.FOCUS_NONE
	add_neuron_button.tooltip_text = "Append one neuron to the hidden layer chosen above."
	add_neuron_button.add_theme_font_size_override("font_size", fs_tb)
	add_neuron_button.pressed.connect(_on_add_neuron_pressed)
	row_add.add_child(add_neuron_button)

	# Row 3: insert hidden layer
	var row_ins := HBoxContainer.new()
	row_ins.add_theme_constant_override("separation", 4)
	outer.add_child(row_ins)

	var idx_lbl := Label.new()
	idx_lbl.text = "At"
	idx_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	idx_lbl.tooltip_text = "Layer index: 0 = input … last = output."
	idx_lbl.add_theme_font_size_override("font_size", fs_tb)
	row_ins.add_child(idx_lbl)

	ref_layer_spin = SpinBox.new()
	ref_layer_spin.min_value = 0.0
	ref_layer_spin.max_value = 0.0
	ref_layer_spin.value = 0.0
	ref_layer_spin.rounded = true
	ref_layer_spin.custom_minimum_size = Vector2(44, 0)
	ref_layer_spin.focus_mode = Control.FOCUS_NONE
	ref_layer_spin.tooltip_text = "0 = input … last = output. After = insert below; Before = insert above."
	ref_layer_spin.add_theme_font_size_override("font_size", fs_tb)
	ref_layer_spin.value_changed.connect(_update_insert_layer_buttons_enabled)
	row_ins.add_child(ref_layer_spin)

	var size_lbl := Label.new()
	size_lbl.text = "n"
	size_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_lbl.tooltip_text = "Neuron count for the new hidden layer."
	size_lbl.add_theme_font_size_override("font_size", fs_tb)
	row_ins.add_child(size_lbl)

	new_hidden_size_spin = SpinBox.new()
	new_hidden_size_spin.min_value = 1.0
	new_hidden_size_spin.max_value = 32.0
	new_hidden_size_spin.value = 4.0
	new_hidden_size_spin.rounded = true
	new_hidden_size_spin.custom_minimum_size = Vector2(44, 0)
	new_hidden_size_spin.focus_mode = Control.FOCUS_NONE
	new_hidden_size_spin.tooltip_text = "Neuron count for the new hidden layer."
	new_hidden_size_spin.add_theme_font_size_override("font_size", fs_tb)
	row_ins.add_child(new_hidden_size_spin)

	insert_after_button = Button.new()
	insert_after_button.text = "After"
	insert_after_button.focus_mode = Control.FOCUS_NONE
	insert_after_button.tooltip_text = "Insert hidden layer after this layer index. Disabled at the last layer index (nothing to insert after before output)."
	insert_after_button.add_theme_font_size_override("font_size", fs_tb)
	insert_after_button.pressed.connect(_on_insert_hidden_after_pressed)
	row_ins.add_child(insert_after_button)

	insert_before_button = Button.new()
	insert_before_button.text = "Before"
	insert_before_button.focus_mode = Control.FOCUS_NONE
	insert_before_button.tooltip_text = "Insert hidden layer before this layer index. Disabled at 0 (cannot insert before input)."
	insert_before_button.add_theme_font_size_override("font_size", fs_tb)
	insert_before_button.pressed.connect(_on_insert_hidden_before_pressed)
	row_ins.add_child(insert_before_button)

	_apply_toolbar_toolbox_buttons_theme()
	_update_insert_layer_buttons_enabled()
	_update_remove_neuron_button_enabled()
	_update_graph_toolbox_visibility()
	_raise_graph_toolbar()


func _on_track_values_pressed() -> void:
	value_tracking_enabled = !value_tracking_enabled
	track_values_button.text = "Live: ON" if value_tracking_enabled else "Live: OFF"


func _sync_layer_spin_to_network() -> void:
	if layer_spin == null:
		return
	if neuralNetwork == null or neuralNetwork.layers.size() < 2:
		layer_spin.min_value = 1.0
		layer_spin.max_value = 1.0
		layer_spin.value = 1.0
		if ref_layer_spin != null:
			ref_layer_spin.min_value = 0.0
			ref_layer_spin.max_value = 0.0
			ref_layer_spin.value = 0.0
		_update_insert_layer_buttons_enabled()
		return
	if neuralNetwork.layers.size() < 3:
		layer_spin.min_value = 1.0
		layer_spin.max_value = 1.0
		layer_spin.value = 1.0
	else:
		layer_spin.min_value = 1.0
		layer_spin.max_value = float(neuralNetwork.layers.size() - 2)
		if layer_spin.value < layer_spin.min_value or layer_spin.value > layer_spin.max_value:
			layer_spin.value = 1.0
	if ref_layer_spin != null:
		ref_layer_spin.min_value = 0.0
		ref_layer_spin.max_value = float(max(0, neuralNetwork.layers.size() - 1))
		if ref_layer_spin.value > ref_layer_spin.max_value:
			ref_layer_spin.value = ref_layer_spin.max_value
		if ref_layer_spin.value < ref_layer_spin.min_value:
			ref_layer_spin.value = ref_layer_spin.min_value
	_update_selection_summary()
	_update_insert_layer_buttons_enabled()


## Matches InsertHiddenLayerBefore (needs r >= 1) and UI guard for After (needs r <= layers-2).
func _update_insert_layer_buttons_enabled(_value: float = 0.0) -> void:
	if insert_after_button == null or insert_before_button == null or ref_layer_spin == null:
		return
	if neuralNetwork == null or !neuralNetwork.GetIsReady() or neuralNetwork.layers.size() < 2:
		insert_before_button.disabled = true
		insert_after_button.disabled = true
		return
	var r: int = int(ref_layer_spin.value)
	var lc: int = neuralNetwork.layers.size()
	insert_before_button.disabled = r < 1
	insert_after_button.disabled = r > lc - 2


func _removal_target_valid() -> bool:
	if neuralNetwork == null or !neuralNetwork.GetIsReady():
		return false
	var L := selected_neuron_id.x
	var N := selected_neuron_id.y
	if L < 1 or L >= neuralNetwork.layers.size() - 1:
		return false
	if N < 0 or N >= neuralNetwork.neurons[L].size():
		return false
	return true


func _update_remove_neuron_button_enabled() -> void:
	if remove_neuron_button == null:
		return
	remove_neuron_button.disabled = not _removal_target_valid()


func _update_selection_summary() -> void:
	if selection_label == null:
		_update_remove_neuron_button_enabled()
		return
	if neuralNetwork == null or !neuralNetwork.GetIsReady():
		selection_label.text = "— No network selected —"
		_update_remove_neuron_button_enabled()
		return
	if selected_neuron_id.x < 0:
		selection_label.text = "— Click a neuron (single-click) —"
		_update_remove_neuron_button_enabled()
		return
	var L := selected_neuron_id.x
	var N := selected_neuron_id.y
	var lc: int = neuralNetwork.layers.size()
	if L < 0 or L >= lc:
		selection_label.text = "Invalid selection."
		_update_remove_neuron_button_enabled()
		return
	if N < 0 or N >= neuralNetwork.neurons[L].size():
		selection_label.text = "Stale selection — click the neuron again."
		_update_remove_neuron_button_enabled()
		return
	var role := "input"
	if L == lc - 1:
		role = "output"
	elif L >= 1:
		role = "hidden"
	var line := "Layer %d, neuron %d · %s." % [L, N, role]
	if role == "hidden":
		var k: int = neuralNetwork.CountLinksTouchingNeuron(L, N)
		line += " Remove → 1 neuron + %d link(s) (incoming + outgoing)." % k
		if neuralNetwork.neurons[L].size() <= 1:
			line += " Last in layer → layer removed; net rewires to nearest layers."
		if layer_spin != null and L >= 1 and L <= lc - 2:
			layer_spin.value = float(L)
	else:
		line += " Remove: hidden (green) only."
	selection_label.text = line
	_update_remove_neuron_button_enabled()


func _on_add_neuron_pressed() -> void:
	if neuralNetwork == null or !neuralNetwork.GetIsReady():
		return
	var L := int(layer_spin.value)
	if neuralNetwork.AppendNeuronToLayer(L):
		initNetwork(neuralNetwork)
	else:
		push_warning("NN_Debugger: could not add neuron (pick a hidden layer index 1 .. N-1).")


func _on_remove_neuron_pressed() -> void:
	if neuralNetwork == null or !neuralNetwork.GetIsReady():
		return
	if !_removal_target_valid():
		_update_selection_summary()
		push_warning("NN_Debugger: select a valid hidden neuron (green). See panel text.")
		return
	var L := selected_neuron_id.x
	var N := selected_neuron_id.y
	if neuralNetwork.RemoveNeuronFromLayer(L, N):
		selected_neuron_id = Vector2i(-1, -1)
		initNetwork(neuralNetwork)
	else:
		_update_selection_summary()
		push_warning("NN_Debugger: remove failed (invalid index or empty layer).")


func _on_insert_hidden_after_pressed() -> void:
	if neuralNetwork == null or !neuralNetwork.GetIsReady():
		return
	var r := int(ref_layer_spin.value)
	if r > neuralNetwork.layers.size() - 2:
		push_warning("NN_Debugger: \"After idx\" needs layer index <= last hidden (output excluded).")
		return
	var ncount := int(new_hidden_size_spin.value)
	if neuralNetwork.InsertHiddenLayerAfter(r, ncount):
		initNetwork(neuralNetwork)
	else:
		push_warning("NN_Debugger: could not insert hidden layer after index %d." % r)


func _on_insert_hidden_before_pressed() -> void:
	if neuralNetwork == null or !neuralNetwork.GetIsReady():
		return
	var r := int(ref_layer_spin.value)
	if r < 1:
		push_warning("NN_Debugger: \"Before idx\" needs layer index >= 1 (cannot insert before input).")
		return
	var ncount := int(new_hidden_size_spin.value)
	if neuralNetwork.InsertHiddenLayerBefore(r, ncount):
		initNetwork(neuralNetwork)
	else:
		push_warning("NN_Debugger: could not insert hidden layer before index %d." % r)


func On_Click_Neuron(neuron_node :GraphNode) -> void:
	if neuron_node == null:
		return
	selected_neuron_id = Vector2i(int(neuron_node.ID.x), int(neuron_node.ID.y))
	_update_selection_summary()


func _process(delta) -> void:
	if !visible:
		return
	listRefreshTimer += delta
	if listRefreshTimer >= LIST_REFRESH_INTERVAL:
		listRefreshTimer = 0.0
		RefreshNetworkList()
	if !run or !neuralNetwork or !neuralNetwork.GetIsReady():
		return
	if !value_tracking_enabled:
		return
	updateTimer += delta
	if updateTimer < UPDATE_INTERVAL:
		return
	updateTimer = 0.0
	SetNeuralValues()
	pass

func _GetGraphLayoutScale() -> float:
	if is_instance_valid(view):
		return view.get_theme_default_base_scale()
	return 1.0


func _schedule_center_graph_view_fit_zoom() -> void:
	if not run or neuralNetwork == null or not is_instance_valid(view):
		return
	if _graph_fit_pending:
		return
	_graph_fit_pending = true
	call_deferred("_run_center_graph_view_fit_zoom")


func _run_center_graph_view_fit_zoom() -> void:
	_graph_fit_pending = false
	await get_tree().process_frame
	_center_graph_view_fit_zoom()


## Screen pos: position_offset * zoom - scroll_offset (GraphEdit). Fit all GraphNodes, center content.
func _center_graph_view_fit_zoom() -> void:
	if not is_instance_valid(view) or not run or neuralNetwork == null:
		return
	var min_g := Vector2(INF, INF)
	var max_g := Vector2(-INF, -INF)
	var scale: float = _GetGraphLayoutScale()
	var approx := Vector2(84.0, 96.0) * scale
	for c in view.get_children():
		if c is GraphNode:
			var gn: GraphNode = c as GraphNode
			var p: Vector2 = gn.position_offset
			var sz: Vector2 = gn.size
			if sz.x < 4.0 or sz.y < 4.0:
				sz = gn.get_combined_minimum_size()
				if sz.x < 4.0 or sz.y < 4.0:
					sz = approx
			var r_end: Vector2 = p + sz
			min_g.x = minf(min_g.x, p.x)
			min_g.y = minf(min_g.y, p.y)
			max_g.x = maxf(max_g.x, r_end.x)
			max_g.y = maxf(max_g.y, r_end.y)
	if min_g.x > max_g.x or min_g.y > max_g.y:
		return
	var pad: float = 48.0 * scale
	var fit_size: Vector2 = (max_g - min_g) + Vector2(2.0 * pad, 2.0 * pad)
	var center_g: Vector2 = (min_g + max_g) * 0.5
	var vs: Vector2 = view.size
	if vs.x < 8.0 or vs.y < 8.0:
		return
	if fit_size.x < 16.0:
		fit_size.x = 320.0 * scale
	if fit_size.y < 16.0:
		fit_size.y = 220.0 * scale
	var z: float = GRAPH_FIT_MARGIN * minf(vs.x / fit_size.x, vs.y / fit_size.y)
	z = clampf(z, view.zoom_min, view.zoom_max)
	view.zoom = z
	view.scroll_offset = center_g * z - vs * 0.5


## Input on the left, output on the right; each column vertically centered (native NN-style).
func _native_nn_layout_position(layer_index: int, neuron_index_in_layer: int, neuron_count_in_layer: int, total_layer_count: int) -> Vector2:
	var s: float = _GetGraphLayoutScale()
	var gap_x: float = GRAPH_LAYER_GAP_X * s
	var gap_y: float = GRAPH_NEURON_GAP_Y * s
	var x: float = (float(layer_index) - 0.5 * float(max(0, total_layer_count - 1))) * gap_x
	var y: float = 0.0
	if neuron_count_in_layer > 1:
		y = (float(neuron_index_in_layer) - 0.5 * float(neuron_count_in_layer - 1)) * gap_y
	return Vector2(x, y) + graph_layout_center_offset * s


func initNetwork(neuralNetwork) -> void:
	run = false
	removeAll()
	self.neuralNetwork = neuralNetwork
	selected_neuron_id = Vector2i(-1, -1)
	_sync_layer_spin_to_network()
	var total_layers: int = neuralNetwork.layers.size()
	for layer in range(total_layers):
		var n_in_layer: int = int(neuralNetwork.layers[layer])
		for neuron in range(n_in_layer):
			var layout_pos: Vector2 = _native_nn_layout_position(layer, neuron, n_in_layer, total_layers)
			var tempNeuronNode :GraphNode
			if(layer == 0):
				tempNeuronNode = AddNeuron(neuralNetwork.neurons[layer][neuron], Vector2i(layer, neuron), Color.GOLDENROD, layout_pos)
				tempNeuronNode.SetAsInput()
			elif(layer == total_layers - 1):
				tempNeuronNode = AddNeuron(neuralNetwork.neurons[layer][neuron], Vector2i(layer, neuron), Color.BROWN, layout_pos)
				tempNeuronNode.SetAsOutput()
			else:
				tempNeuronNode = AddNeuron(neuralNetwork.neurons[layer][neuron], Vector2i(layer, neuron), Color.FOREST_GREEN, layout_pos)
			nodeNeurons.append(tempNeuronNode)
			nodeNameByID[Vector2i(layer,neuron)] = tempNeuronNode.name
	for link in neuralNetwork.links:
		ConnectLink(link)
	run = true
	SetNeuralValues()
	_raise_graph_toolbar()
	_update_graph_toolbox_visibility()
	_update_selection_summary()
	_schedule_center_graph_view_fit_zoom()


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
	_update_graph_toolbox_visibility()
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
		selected_neuron_id = Vector2i(-1, -1)
		removeAll()
		_update_selection_summary()
		_update_graph_toolbox_visibility()

func _GetNetworkListSignature(networks :Array) -> String:
	var signature :String = ""
	for item in networks:
		signature += str(item.get_instance_id()) + ":" + item.name + ":" + str(item.GetIsReady()) + ";"
	return signature

func AddNeuron(neuron :Neuron, neuronID :Vector2i, color :Color, layout_position :Vector2) -> GraphNode:
	var neuronIns :GraphNode = neuronFile.instantiate()
	neuronIns.SetData(neuron)
	neuronIns.SetID(neuronID)
	neuronIns.ChangeColor(color)
	neuronIns.position_offset = layout_position
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
			neuralNetwork._remove_link_from_network(link)
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

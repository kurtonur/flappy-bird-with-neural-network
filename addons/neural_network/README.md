# Neural Network Addon

Godot 4 addon for creating, running, saving, loading, and mutating simple
feed-forward neural networks.

This addon lets you add a `NeuralNetwork` node inside Godot and use it for AI
behavior experiments. Example use cases include feeding character or environment
data into the network and reading outputs for movement direction, attack
decisions, steering, or other gameplay behavior.

## Install In Another Godot Project

To use this addon in another project, copy only the `addons/neural_network`
folder into that project.

1. Copy this folder from this repository:

   ```text
   addons/neural_network
   ```

2. Paste it into your target Godot project:

   ```text
   your_project/
     addons/
       neural_network/
         plugin.cfg
         neural_network.gd
         icon.svg
         Scripts/
         Editor/
   ```

3. Open the target project in Godot 4.
4. Go to `Project > Project Settings > Plugins`.
5. Enable `Neural Network`.
6. In your scene, click `Add Child Node` and add `NeuralNetwork`.
7. Attach or update your gameplay script and call `InitLayers()` once before
   using the network.

After enabling the plugin, Godot should know the `NeuralNetwork` type globally,
so you can use this in scripts:

```gdscript
@onready var ai: NeuralNetwork = $NeuralNetwork
```

## Minimal Working Scene

Scene example:

```text
Player
  NeuralNetwork
```

Player script:

```gdscript
extends CharacterBody2D

@export var speed: float = 200.0
@onready var ai: NeuralNetwork = $NeuralNetwork

func _ready() -> void:
	# 2 inputs, 1 hidden layer with 4 neurons, 2 outputs.
	ai.InitLayers([2, 4, 2])

func _physics_process(delta: float) -> void:
	var input := [
		0.5,   # example x input
		-0.25, # example y input
	]

	var output := ai.FastForward(input)
	if output.size() < 2:
		return

	var direction := Vector2(output[0], output[1]).normalized()
	velocity = direction * speed
	move_and_slide()
```

## Layer Format

The layer array defines the network shape:

- First number: input count.
- Middle numbers: hidden layer neuron counts.
- Last number: output count.

Examples:

- `[2, 4, 2]`: 2 inputs, 1 hidden layer with 4 neurons, 2 outputs.
- `[3, 8, 4, 2]`: 3 inputs, 2 hidden layers, 2 outputs.
- `[5, 10, 1]`: 5 inputs, 1 hidden layer, 1 output.

Input array size must match the first layer. Output count will match the last
layer.

## Forward vs FastForward

Use `FastForward()` for gameplay loops. It returns `PackedFloat32Array`, so it is
easy and fast to read:

```gdscript
var output := ai.FastForward([food_direction.x, food_direction.y])
var movement := Vector2(output[0], output[1])
```

Use `Forward()` if you need the full output `Neuron` objects:

```gdscript
var result := ai.Forward([food_direction.x, food_direction.y])
var movement := Vector2(result[0].value, result[1].value)
```

Important: `Forward()` returns neurons, so read values with `.value`.
`FastForward()` returns numbers directly.

## Main API

### Network Setup

- `SetLayers(layers: Array)`: sets the layer structure.
- `InitLayers(layers: Array = self.layers)`: creates neurons and weighted links.
- `Cleaner()`: resets the network to default values.
- `CopyFrom(neuralNetwork: NeuralNetwork)`: copies another network's data.
- `SetNetworkData(data: Dictionary)`: loads network data from a dictionary.
- `GetNetworkData() -> Dictionary`: exports network data as a dictionary.

### Running The Network

- `Forward(input: Array, CustomFunction = null) -> Array`: runs a forward pass
  and returns output `Neuron` objects.
- `FastForward(input: Array, CustomFunction = null, syncNeurons: bool = true) ->
  PackedFloat32Array`: runs a faster forward pass and returns output values.

### Mutation

- `Mutate(MutationFunction: int = mutationFunction, CustomFunction = null)`:
  mutates every link weight.
- `SetLearningRate(rate: Vector2)`: sets mutation random range.
- `GetLearningRate() -> Vector2`: returns mutation random range.
- `SetStartRandomization(random: Vector2)`: sets initial random value range.
- `GetStartRandomization() -> Vector2`: returns initial random value range.

Available mutation modes:

- `NewRandomByLearningRate`
- `MultiplyByTwo`
- `MultiplyByLearningRate`
- `MultiplyByZeroOne`
- `MultiplyByZeroOnePlus`
- `Custom`
- `Default`

Example mutation flow:

```gdscript
var child_ai := NeuralNetwork.new()
child_ai.CopyFrom(parent_ai)
child_ai.SetLearningRate(Vector2(-0.1, 0.1))
child_ai.Mutate()
```

### Activation Functions

Available activation modes:

- `Sigmoid`
- `SigmoidDerivative`
- `Tanh`
- `TanhDerivative`
- `ReLU`
- `ReLUDerivative`
- `ELU`
- `ELUDerivative`
- `Linear`
- `LinearDerivative`
- `Custom`
- `Default`

Default activation is sigmoid.

## Save And Load

Save to `user://` if you want data to survive between game runs:

```gdscript
ai.SaveNetworkToFile("user://best_network.save")
ai.LoadNetworkFromFile("user://best_network.save")
```

Encrypted save/load is also supported by passing a password:

```gdscript
ai.SaveNetworkToFile("user://best_network.save", "password")
ai.LoadNetworkFromFile("user://best_network.save", "password")
```

In a training setup, common flow is:

1. Run many agents.
2. Calculate each network's `fitness`.
3. Save the best network.
4. Copy the best network into the next generation.
5. Mutate copies.

## Exported Properties

- `layers`: network layer structure.
- `fitness`: current network score.
- `bestFitness`: best known score.
- `startRandomization`: initial random weight/value range.
- `learningRate`: mutation random range.
- `mutationFunction`: selected mutation mode.
- `activationFuction`: selected activation mode.

Note: `activationFuction` is documented with the current script property name.

## Debugger

The addon also registers `NNDebugger`. In debug builds it can show a neural
network debugger window. Add an `NNDebugger` node if you want to inspect network
state while testing.

## Troubleshooting

### Plugin does not enable

Make sure the folder path is exactly:

```text
res://addons/neural_network/plugin.cfg
```

Godot plugins must live under `addons/`. If you rename the folder, update all
`res://addons/neural_network/...` paths in the addon scripts.

### `NeuralNetwork` type is not found

Check these:

- Plugin is enabled in `Project Settings > Plugins`.
- Godot project was reloaded after copying the addon.
- `addons/neural_network/Scripts/NeuralNetwork.gd` exists.

### Wrong input size

If you see `!!! Wrong input size for Neural Network !!!`, your input array size
does not match the first layer.

Example:

```gdscript
ai.InitLayers([2, 4, 2])
ai.FastForward([0.5, -0.25]) # OK: 2 inputs
ai.FastForward([0.5])        # Wrong: only 1 input
```

### Output reading looks wrong

Remember the difference:

- `FastForward()` returns numbers: `output[0]`.
- `Forward()` returns neurons: `output[0].value`.

### NEATNetwork warning

`neural_network.gd` currently registers `NEATNetwork`, but
`Scripts/NEATNetwork.gd` is not present in this project. If Godot reports an
error while enabling the plugin, either add that missing script or remove/comment
the `NEATNetwork` custom type registration from `neural_network.gd`.

## Known Notes

- Addon script version is `0.5.4`.
- `plugin.cfg` currently lists version `0.5`; update it if you want all version
  fields to match.

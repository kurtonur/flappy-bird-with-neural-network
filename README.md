# Flappy Bird Godot

Godot ile yapılmış basit bir Flappy Bird clone projesi. Project was migrated from Godot 3 to Godot 4 and is currently configured for Godot 4.6.

## Requirements

- Godot 4.6 or newer

## How To Run

1. Open the project folder in Godot.
2. Run the main scene: `res://scene/Game.tscn`.
3. Tap or click to make the bird jump.

## Project Structure

- `scene/`: Main playable scenes.
- `sceneObject/`: Reusable game objects like bird, floor, pipes, and effects.
- `script/`: Gameplay, UI, save/load, and core game state scripts.
- `image/`, `audio/`, `font/`: Game assets.

## Notes

- Save data is stored with Godot's `user://` path.
- Generated Godot cache files such as `.godot/` should not be committed.

extends Node

const FILE_NAME = "user://bird-game-data.save"


func saveData():
	var file = FileAccess.open(FILE_NAME, FileAccess.WRITE)
	if file == null:
		printerr("Could not save data: ", FileAccess.get_open_error())
		return

	#file.open_encrypted_with_pass(FILE_NAME, FileAccess.WRITE, OS.get_unique_id())
	file.store_string(JSON.stringify(get_gameData()))
	file.close()

func loadData():
	if FileAccess.file_exists(FILE_NAME):
		var file = FileAccess.open(FILE_NAME, FileAccess.READ)
		if file == null:
			printerr("Could not load data: ", FileAccess.get_open_error())
			return get_gameData()

		#file.open_encrypted_with_pass(FILE_NAME, FileAccess.READ, OS.get_unique_id())
		var test_json_conv = JSON.new()
		var error = test_json_conv.parse(file.get_as_text())
		var data = test_json_conv.get_data()
		file.close()

		if error == OK and typeof(data) == TYPE_DICTIONARY:
			return data
		else:
			printerr("Corrupted data!")
			return get_gameData()
	else:
		printerr("No saved data!")
		return get_gameData()
		
func get_gameData():
	var player = {
		"game": "TappyBird",
		"highScore": globe.score
	}
	return player

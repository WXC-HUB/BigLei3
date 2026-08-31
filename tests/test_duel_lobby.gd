extends SceneTree
## 对战大厅：房间码展示/提交、连接中也能立刻取消。

const LobbyScript := preload("res://scripts/ui/duel_lobby.gd")
const ConfigScript := preload("res://scripts/net/duel_config.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lobby = LobbyScript.new()
	root.add_child(lobby)
	await process_frame

	var cancelled: Array = []
	var submitted: Array = []
	lobby.cancelled.connect(func() -> void: cancelled.append(1))
	lobby.join_submitted.connect(func(code: String, address: String) -> void:
		submitted.append([code, address])
	)

	lobby.present_host("7K2M")
	assert(lobby.is_open())
	assert(lobby.get("_code_label").text == "7K2M")
	assert(not lobby.get("_code_input").visible)
	lobby.get("_cancel_button").pressed.emit()
	assert(cancelled.size() == 1)

	lobby.present_join()
	lobby.get("_code_input").text = "7k2m"
	lobby.get("_address_input").text = "127.0.0.1"
	lobby.get("_join_button").pressed.emit()
	assert(submitted.size() == 1)
	assert(submitted[0][0] == "7K2M")
	assert(submitted[0][1] == "127.0.0.1")

	lobby.set_joining("7K2M")
	assert(lobby.get("_cancel_button").text == "终止连接")
	assert(not lobby.get("_cancel_button").disabled)
	lobby.get("_cancel_button").pressed.emit()
	assert(cancelled.size() == 2)

	assert(ConfigScript.port_for_room("7K2M") == ConfigScript.port_for_room("7k2m"))
	var code := ConfigScript.generate_room_code()
	assert(code.length() == ConfigScript.ROOM_CODE_LENGTH)
	assert(ConfigScript.normalize_room_code(code) == code)

	lobby.free()
	print("DuelLobby: all tests passed")
	quit()

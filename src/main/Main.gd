extends Node

func _ready():
	if OS.has_feature("server"):
		Game.start_server()
	else:
		Game.start_menu()
	queue_free()

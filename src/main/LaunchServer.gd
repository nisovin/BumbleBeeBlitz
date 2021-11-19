extends Node

func _ready():
	Game.start_server()
	queue_free()
	

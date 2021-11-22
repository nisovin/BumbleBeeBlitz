extends Control

onready var http = $HTTPRequest
onready var name_input = $VBoxContainer/NameBox/Name
onready var status_label = $VBoxContainer/Status/VBoxContainer/Status
onready var join_button = $VBoxContainer/HBoxContainer/Buttons/JoinButton

var server_ip = ""
var server_port = 0

var last_player_count = -1

func _ready():
	if Game.settings.name == "":
		name_input.text = N.rand_array(G.NAMES)
	else:
		name_input.text = Game.settings.name
	check_server_list()

func _on_Name_text_changed(new_text):
	var n = Game.name_regex.sub(new_text, "", true)
	if n != new_text:
		name_input.text = n
		name_input.caret_position = n.length()

func _on_RandomButton_pressed():
	var n = name_input.text
	while n == name_input.text:
		n = N.rand_array(G.NAMES)
	name_input.text = n

func update_name():
	Game.player_name = name_input.text.strip_edges()
	if Game.player_name == "":
		Game.player_name = N.rand_array(G.NAMES)
	Game.settings.name = Game.player_name
	Game.save_settings()

func _on_JoinButton_pressed():
	update_name()
	Game.start_client(server_ip, server_port)
	queue_free()

func _on_SoloButton_pressed():
	update_name()
	Game.start_solo()
	queue_free()

func _on_TutorialButton_pressed():
	update_name()
	Game.start_tutorial()
	queue_free()

func _on_QuitButton_pressed():
	get_tree().quit()
	
func check_server_list():
	http.request("https://nisovin.com/gamejams/get_servers.php?id=2")

func server_update(result, response_code, headers, body: PoolByteArray):
	if response_code == 200:
		var json = body.get_string_from_utf8()
		var data = parse_json(json)
		if data and "servers" in data:
			if data.servers.size() == 0:
				set_server("Not Available")
			else:
				for server in data.servers:
					var player_count = int(server.players)
					if player_count < G.MAX_PLAYERS:
						set_server(str(server.players) + " players, " + server.status, server.ip, server.port)
						if player_count > 0 and last_player_count == 0:
							Game.play_sound("super_spawn")
						last_player_count = player_count
						return
				set_server("Full")
				
		else:
			set_server("ERROR")

func set_server(status, ip = "", port = 0):
	server_ip = ip
	server_port = port
	status_label.text = status
	join_button.disabled = ip == ""







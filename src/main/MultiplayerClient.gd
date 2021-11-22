extends Node
class_name MultiplayerClient

#const URL = "ws://localhost" # 
const URL = "wss://game.nisovin.com"

var client: WebSocketClient = null
var connected = false

func _ready():
	name = "Multiplayer"

func start(ip, port):
	get_tree().connect("connected_to_server", self, "_on_connected")
	get_tree().connect("connection_failed", self, "_on_disconnected")
	get_tree().connect("server_disconnected", self, "_on_disconnected")
	
	var url = ""
	if ip == "localhost":
		url = "ws://localhost:" + str(port)
	else:
		url = "wss://" + ip + ":" + str(port)
	
	client = WebSocketClient.new()
	client.connect_to_url(url, [], true)
	get_tree().network_peer = client
	print("starting client")

func disconnect_client():
	client.disconnect_from_host()
	get_tree().network_peer = null

func _on_connected():
	print("client connected")
	connected = true
	Game.online = true
	Game.player_id = get_tree().get_network_unique_id()
	
func _on_disconnected():
	if connected:
		print("disconnected") # disconnect
	else:
		print("failed") # failed
	connected = false
	Game.online = false
	
func _process(delta):
	if client != null:
		client.poll()

func server_full():
	pass
	
remote func load_game(state):
	if state != null:
		Game.load_level_from_game_state(state)
		rpc_id(1, "player_join", {"name": Game.player_name})

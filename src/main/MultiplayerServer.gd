extends Node
class_name MultiplayerServer

var server: WebSocketServer = null
var http := HTTPRequest.new()

var server_id = 0
var server_port = 44337
var api_key := ""
var auth_password := ""

var players = []

func _ready():
	name = "Multiplayer"
	add_child(http)
	http.connect("request_completed", self, "req_done")
	
	var file = File.new()
	var server_file = "server.txt"
	var args = OS.get_cmdline_args()
	if args.size() >= 2 and args[0] == "--server":
		server_file = args[1]
	if not file.file_exists(server_file):
		print("NO SERVER DATA FILE FOUND!")
		get_tree().quit()
		return
	
	file.open(server_file, File.READ)
	var text = file.get_as_text()
	file.close()
	var json_result = JSON.parse(text)
	if json_result.error == OK:
		var data = json_result.result
		server_id = int(data.id)
		server_port = int(data.port)
		api_key = data.key
		auth_password = data.auth
	print("SERVER: " + str(server_id) + " PORT: " + str(server_port))

func start():
	get_tree().connect("network_peer_connected", self, "_on_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
		
	server = WebSocketServer.new()
	
	var file = File.new()
	if file.file_exists("fullchain.pem"):
		var cert = X509Certificate.new()
		var key = CryptoKey.new()
		var err = cert.load("fullchain.pem")
		print("Loaded cert ", err)
		err = key.load("privkey.pem")
		print("Loaded key ", err)
		server.ssl_certificate = cert
		server.private_key = key
		
	server.listen(server_port, [], true)
	get_tree().network_peer = server
	Game.online = true
	print("Started server")
	update_status()
	
func _process(delta):
	if server != null and server.is_listening():
		server.poll()
	
func _on_player_connected(id):
	print("Player connected ", id)
	if get_tree().multiplayer.get_network_connected_peers().size() >= G.MAX_PLAYERS:
		rpc_id(id, "server_full")
		server.disconnect_peer(id)
	else:
		rpc_id(id, "load_game", Game.get_game_state())
		Game.emit_signal("player_connected", id)
		Game.player_map[id] = {}

remote func player_join(data):
	var id = get_tree().get_rpc_sender_id()
	data.id = id
	var n = Game.name_regex.sub(data.name.strip_edges(), "", true)
	if n == "":
		n = N.rand_array(G.NAMES)
	elif n.length() > 12:
		n = n.substr(0, 12)
	data.name = n
	Game.player_map[id] = data
	print("player join data received ", data)
	Game.emit_signal("player_joined", data)
	
func _on_player_disconnected(id):
	print("DISCONNECT! ", id)
	Game.level.player_left(id)
	Game.player_map.erase(id)

func reset_players():
	rpc("load_game", Game.get_game_state())

func update_status():
	var status = "Not Started"
	if Game.match_started and Game.level != null:
		status = str(Game.level.score[1]) + " to " + str(Game.level.score[2]) + ", "
		var time = Game.level.game_timer
		var minutes = time / 60
		var seconds = time % 60
		status += str(minutes) + ":" + ("0" if seconds < 10 else "") + str(seconds)
	var players = get_tree().multiplayer.get_network_connected_peers().size()
	var url = "https://nisovin.com/gamejams/update_server.php?key=" + api_key + "&id=" + str(server_id) + "&players=" + str(players) + "&status=" + status.replace(" ", "+")
	http.request(url)
	print("Status update: players: " + str(players) + " status: " + status)
	get_tree().create_timer(2).connect("timeout", self, "update_status")

func req_done(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray):
	pass
	#prints("req", str(result), str(response_code), body.size(), body.get_string_from_utf8())

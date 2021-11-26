extends Node

const MainMenu = preload("res://gui/MainMenu.tscn")
const MatchGUI = preload("res://gui/MatchGUI.tscn")
const ChatEntry = preload("res://gui/ChatEntry.tscn")

const Level = preload("res://level/Level.tscn")
const Player = preload("res://player/Player.tscn")
const Flower = preload("res://level/Flower.tscn")
const Nectar = preload("res://level/Nectar.tscn")
const NectarScript = preload("res://level/Nectar.gd")
const Bullet = preload("res://player/Bullet.tscn")
const Ladybug = preload("res://level/Ladybug.tscn")

const FlowerSprites = {
	G.FlowerType.NORMAL: {
		"sprite": preload("res://level/flower_normal.png"),
		"shadow": preload("res://level/flower_normal_shadow.png"),
		"indicator": preload("res://level/indicator_normal.png")
	},
	G.FlowerType.WEAPON: {
		"sprite": preload("res://level/flower_weapon.png"),
		"shadow": preload("res://level/flower_weapon_shadow.png"),
		"indicator": preload("res://level/indicator_weapon.png")
	},
	G.FlowerType.SUPER: {
		"sprite": preload("res://level/flower_super.png"),
		"shadow": preload("res://level/flower_super_shadow.png"),
		"indicator": preload("res://level/indicator_super.png")
	}
}

const SETTINGS_FILE = "user://bumble_settings.dat"

signal player_connected
signal player_joined
signal player_left
signal flower_collected
signal nectar_passed
signal scored
signal bullet_fired
signal bullet_hit
signal chat_received

var level = null
var player = null
var online = false
var is_server = false
var match_started = false
var pause_menu_open = false
var player_id = -1
var player_name = "Bumble"
var player_map = {}
var multiplayer_manager

var name_regex := RegEx.new()
var audio_players = []

var settings = {
	"name": "",
	"vol_music": 1.0,
	"vol_ambient": 1.0,
	"vol_sfx": 1.0
}

func _ready():
	randomize()
	for i in 15:
		var a = AudioStreamPlayer.new()
		a.bus = "SFX"
		a.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(a)
		audio_players.append(a)
	name_regex.compile("[^A-Za-z0-9_]")
	load_settings()
	
func is_host():
	return is_server or not online
	
func is_player():
	return player_id > 0

func load_settings():
	var file = File.new()
	if file.file_exists(SETTINGS_FILE):
		file.open(SETTINGS_FILE, File.READ)
		var s = file.get_var()
		for key in s:
			settings[key] = s[key]
		file.close()
		player_name = settings.name
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(settings.vol_music))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear2db(settings.vol_ambient))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(settings.vol_sfx))

func save_settings():
	var file = File.new()
	file.open(SETTINGS_FILE, File.WRITE)
	file.store_var(settings)
	file.close()

func start_server():
	is_server = true
	
	multiplayer_manager = MultiplayerServer.new()
	add_child(multiplayer_manager)
	multiplayer_manager.start()
	
	start_server_level()

func start_server_level():
	if level != null:
		level.name = "OldLevel"
		level.queue_free()
	match_started = false
	level = Level.instance()
	add_child(level)
	level.init_server()

func start_server_again():
	print("RESETTING!")
	start_server_level()
	multiplayer_manager.reset_players()

func start_menu():
	online = false
	match_started = false
	if multiplayer_manager != null:
		multiplayer_manager.disconnect_client()
		multiplayer_manager = null
	if level != null:
		level.queue_free()
		level = null
	add_child(preload("res://gui/MainMenu.tscn").instance())

func start_tutorial():
	level = load("res://level/Tutorial.tscn").instance()
	add_child(level)

func start_client(ip, port_num):
	multiplayer_manager = MultiplayerClient.new()
	add_child(multiplayer_manager)
	multiplayer_manager.start(ip, port_num)

func start_host():
	pass

func start_solo():
	player_id = 0
	level = Level.instance()
	add_child(level)
	level.init_solo()

func get_game_state():
	var data = {}
	if level != null:
		data = level.get_game_state()
	return data

func load_level_from_game_state(state):
	player = null
	if level != null:
		level.name = "OldLevel"
		level.queue_free()
	level = Level.instance()
	add_child(level)
	level.init_client()
	level.load_game_state(state)

func server_message(msg_id, params):
	var msg = N.rand_array(G.MESSAGES[msg_id])
	for key in params:
		msg = msg.replace("{" + key + "}", params[key])
	server_message_custom(msg)

func server_message_custom(msg):
	N.rpc_or_local(self, "broadcast_message", ["", 0, msg])

func submit_message(msg):
	N.rpc_id_or_local(1, self, "send_message", [msg])

master func send_message(msg):
	var id = get_tree().get_rpc_sender_id()
	if not id in player_map: return
	var p = player_map[id]
	msg = msg.replace("[", "(").replace("]", ")")
	N.rpc_or_local(self, "broadcast_message", [p.name, p.team if "team" in p else 0, msg])
	
puppet func broadcast_message(who, team, msg):
	if get_tree().get_rpc_sender_id() <= 1:
		if who != "":
			var color = "gray"
			if team == 1: color = G.TEAM1_CHAT_COLOR
			elif team == 2: color = G.TEAM2_CHAT_COLOR
			msg = "[color=gray]<[/color][color=" + color + "]" + who + "[/color][color=gray]>[/color] " + msg
		else:
			msg = "[color=aqua]*[/color] " + msg
		emit_signal("chat_received", msg)

func play_sound(sound, bus = "SFX", volume = 1.0):
	for a in audio_players:
		if not a.playing:
			a.stream = G.SOUNDS[sound]
			a.bus = bus
			a.volume_db = linear2db(volume)
			a.play()
			break

func play_sound_at_pos(sound, pos = null, bus = "SFX"):
	if pos == null:
		play_sound(sound, bus, 1.0)
	elif player != null:
		var dist = player.global_position.distance_to(pos)
		if dist < 1000:
			var vol = range_lerp(dist, 0, 1000, 1.0, 0.2)
			play_sound(sound, bus, vol)

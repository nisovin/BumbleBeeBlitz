extends Node2D

const NORMAL_FLOWER_COOLDOWN = 3
const EVENT_DELAY_MIN = 30
const EVENT_DELAY_MAX = 60
const LADYBUG_SWARM_DURATION = 20
const MATCH_DURATION = 180

onready var players_node = $Players
onready var flowers_node = $Flowers
onready var objects_node = $Objects

onready var center = $Center.position

var game_timer = -100
var cpu_counter = 0
var flower_counter = 0
var object_counter = 0
var score = [0, 0, 0]
var player_stats = {}
var cpu_names = []
var team1_name = ""
var team2_name = ""

var nectar_holder = null
var nectar_cd = 0
var weapon_holders = [null, null]
var super_flower = null

var time_since_event = -EVENT_DELAY_MIN
var ladybug_swarm = false

var match_gui = null

func _ready():
	Game.connect("player_joined", self, "player_joined")
	Game.connect("player_left", self, "player_left")
	Game.connect("flower_collected", self, "flower_collected")
	Game.connect("nectar_passed", self, "nectar_passed")
	Game.connect("scored", self, "scored")
	Game.connect("bullet_fired", self, "bullet_fired")
	if not Game.is_server:
		$Ambiance.play()

func init_server():
	spawn_cpu(1, 1)
	spawn_cpu(1, 2)
	spawn_cpu(1, 3)
	spawn_cpu(2, 1)
	spawn_cpu(2, 2)
	spawn_cpu(2, 3)
	choose_team_names()
	
func init_client():
	match_gui = Game.MatchGUI.instance()
	add_child(match_gui)

func init_solo():
	var data = {"id": Game.player_id, "name": Game.player_name, "team": 1, "cpu": false}
	Game.player_map[Game.player_id] = data
	spawn_player(data, 1)
	spawn_cpu(1, 2)
	spawn_cpu(1, 3)
	spawn_cpu(2, 1)
	spawn_cpu(2, 2)
	spawn_cpu(2, 3)
	match_gui = Game.MatchGUI.instance()
	add_child(match_gui)
	choose_team_names()
	start_countdown()
	
func choose_team_names():
	var names = G.TEAM_NAMES
	names.shuffle()
	team1_name = names[0]
	team2_name = names[1]

func get_game_state():
	var players = []
	var flowers = []
	var objects = []
	for p in players_node.get_children():
		if not p.dead:
			players.append(p.get_data())
	for f in flowers_node.get_children():
		if not f.dead:
			flowers.append(f.get_data())
	for o in objects_node.get_children():
		if not o.dead:
			objects.append(o.get_data())
	return {
		"started": Game.match_started,
		"time": game_timer,
		"team1": team1_name,
		"team2": team2_name,
		"score": score,
		"stats": player_stats,
		"players": players,
		"flowers": flowers,
		"objects": objects
	}
	
func load_game_state(state):
	Game.match_started = state.started
	game_timer = state.time
	team1_name = state.team1
	team2_name = state.team2
	score = state.score
	player_stats = state.stats
	for p in state.players:
		add_player(p)
	if Game.match_started:
		match_gui.update_scores()
		match_gui.update_clock()
		match_gui.show_scores()

func start_countdown():
	print("START COUNTDOWN")
	game_timer = -6
	$GameTimer.start()

func timer_tick():
	if game_timer < 0:
		game_timer += 1
		if game_timer == 0:
			game_timer = MATCH_DURATION
			start_game()
	else:
		game_timer -= 1
		if game_timer == 0:
			end_game()
			$GameTimer.stop()
	N.rpc_or_local(self, "update_timer", [game_timer])

remotesync func update_timer(t):
	if get_tree().get_rpc_sender_id() <= 1 and not Game.is_server:
		game_timer = t
		if game_timer == -5 and match_gui != null:
			match_gui.animate_teams(team1_name, team2_name)
		if game_timer == -4:
			$Music.play()
		if match_gui != null:
			match_gui.update_clock()
		
func start_game():
	Game.match_started = true
	Game.server_message_custom("The game has begun!")
	spawn_flower(G.FlowerType.NORMAL)
	$FlowerTick.start()
	N.rpc_or_local(self, "game_started", [])
	
puppet func game_started():
	Game.match_started = true
	if match_gui != null:
		match_gui.show_scores()

func end_game():
	Game.match_started = false
	Game.server_message_custom("The game is over!")
	$FlowerTick.stop()
	for flower in flowers_node.get_children():
		flower.remove()
	for player in players_node.get_children():
		if player.is_carrying():
			N.rpc_or_local(player, "set_carrying", [-1])
	if nectar_holder != null and nectar_holder.is_in_group("nectar"):
		nectar_holder.decay()
	nectar_holder = null
	super_flower = null
	weapon_holders = [null, null]
	if Game.is_server:
		get_tree().create_timer(5).connect("timeout", Game, "start_server_again")
	else:
		get_tree().create_timer(5).connect("timeout", Game, "start_menu")

puppet func game_ended():
	Game.match_started = false

func player_joined(data):
	data.cpu = false
	
	# determine team
	var team1_players = 0
	var team2_players = 0
	for p in get_tree().get_nodes_in_group("players"):
		if p.team == 1 and not p.cpu:
			team1_players += 1
		elif p.team == 2 and not p.cpu:
			team2_players += 1
	if team1_players < team2_players:
		data.team = 1
	elif team2_players < team1_players:
		data.team = 2
	elif team1_players == 0 and team2_players == 0:
		data.team = 1
	else:
		data.team = 1 if randf() < 0.5 else 2
	
	# spawn player
	Game.player_map[data.id] = data
	var spawned = false
	if not Game.match_started:
		var cpu = find_least_important_cpu(data.team)
		if cpu != null:
			var pos = cpu.global_position
			remove_player(cpu.id)
			spawn_player(data, 0, pos)
			spawned = true
	if not spawned:
		spawn_player(data)
	balance_teams()
	
	# start game if not started
	if not Game.match_started and game_timer == -100:
		start_countdown()
	
func player_left(id):
	remove_player(id)
	balance_teams()

func spawn_cpu(team, pos_index = 0):
	cpu_counter += 1
	if cpu_names.size() == 0:
		cpu_names = G.NAMES.duplicate()
		cpu_names.shuffle()
	spawn_player({"id": -cpu_counter, "name": "CPU_" + cpu_names.pop_front(), "team": team, "cpu": true}, pos_index)

func spawn_player(data, pos_index = 0, spawn_point = null):
	if spawn_point == null:
		data.position = find_spawn_point(data.team, pos_index)
	else:
		data.position = spawn_point
	N.rpc_or_local(self, "add_player", [data])
	
func find_spawn_point(team, index = 0):
	return get_node("StartSpawns/T" + str(team) + "_" + str(index)).global_position

remotesync func add_player(data):
	var player = Game.Player.instance()
	players_node.add_child(player)
	player.init(data)

func remove_player(id):
	var p = players_node.get_node_or_null(str(id))
	if p != null:
		if nectar_holder == p:
			p.set_carrying(-1)
			nectar_holder = null
		for i in weapon_holders.size():
			if weapon_holders[i] == p:
				p.set_carrying(-1)
				weapon_holders[i] = null
		p.deactivate_ai()
		p.remove()
	N.rpc_or_local(self, "delete_player", [id])

puppet func delete_player(id):
	var p = players_node.get_node_or_null(str(id))
	if p != null:
		p.remove()
		
func balance_teams():
	var team1_players = 0
	var team1_cpus = 0
	var team2_players = 0
	var team2_cpus = 0
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead: continue
		if p.team == 1:
			if p.cpu:
				team1_cpus += 1
			else:
				team1_players += 1
		elif p.team == 2:
			if p.cpu:
				team2_cpus += 1
			else:
				team2_players += 1
	if team1_players + team2_players == 0:
		Game.start_server_again()
	elif team1_players + team1_cpus > team2_players + team2_cpus:
		if team1_cpus > 0 and team1_players + team1_cpus > 3:
			# remove cpu from team 1
			var cpu = find_least_important_cpu(1)
			if cpu != null:
				remove_player(cpu.id)
				print("REBALANCE: remove cpu from team 1")
		else:
			# add cpu to team 2
			spawn_cpu(2)
			print("REBALANCE: add cpu to team 2")
	elif team1_players + team1_cpus < team2_players + team2_cpus:
		if team2_cpus > 0 and team2_players + team2_cpus > 3:
			# remove cpu from team 2
			var cpu = find_least_important_cpu(2)
			if cpu != null:
				remove_player(cpu.id)
				print("REBALANCE: remove cpu from team 2")
		else:
			# add cpu to team 1
			spawn_cpu(1)
			print("REBALANCE: add cpu to team 1")
			
func find_least_important_cpu(team):
	var cpu = null
	var lowest_points = 1000
	for p in get_tree().get_nodes_in_group("team" + str(team)):
		if p.cpu:
			var points = 0
			if p.carrying == G.FlowerType.NORMAL:
				points = 10
			elif p.carrying == G.FlowerType.WEAPON:
				points = 3
			elif p.gathering == G.FlowerType.SUPER:
				points = 5
			elif p.gathering == G.FlowerType.NORMAL:
				points = 4
			elif p.gathering == G.FlowerType.WEAPON:
				points = 1
			if points < lowest_points:
				lowest_points = points
				cpu = p
	return cpu

func flower_tick():
	if nectar_holder == null:
		if nectar_cd == 0:
			nectar_cd = NORMAL_FLOWER_COOLDOWN
			if super_flower != null:
				nectar_cd *= 3
		else:
			nectar_cd -= 1
		if nectar_cd == 0:
			spawn_flower(G.FlowerType.NORMAL)
			return
	if time_since_event > -1000 and super_flower == null and not ladybug_swarm:
		time_since_event += 1
		if time_since_event > 0:
			var r = randf() * EVENT_DELAY_MAX
			if r < time_since_event:
				start_event()
				return
	for i in weapon_holders.size():
		if weapon_holders[i] == null:
			spawn_flower(G.FlowerType.WEAPON, i)
			return
	
	var ladybug_chance = 0.4 if ladybug_swarm else 0.01
	if randf() < ladybug_chance:
		spawn_ladybug()

func start_event():
	if randf() < 0.7:
		spawn_flower(G.FlowerType.SUPER)
	else:
		start_ladybug_swarm()
	time_since_event = -1000
		
func start_ladybug_swarm():
	ladybug_swarm = true
	Game.server_message("ladybugswarm", [])
	get_tree().create_timer(LADYBUG_SWARM_DURATION, false).connect("timeout", self, "stop_ladybug_swarm")
	
func stop_ladybug_swarm():
	ladybug_swarm = false
	time_since_event = -EVENT_DELAY_MIN

func spawn_flower(type, index = 0):
	flower_counter += 1
	var data = {}
	data.id = flower_counter
	data.type = type
	data.position = find_flower_spawn(type)
	data.index = index
	N.rpc_or_local(self, "spawn_flower_real", [data])
	if type == G.FlowerType.SUPER:
		Game.server_message("superbloom", {})
	
remotesync func spawn_flower_real(data):
	if get_tree().get_rpc_sender_id() > 1: return
	var flower = Game.Flower.instance()
	flowers_node.add_child(flower)
	flower.init(data)
	if data.type == G.FlowerType.NORMAL:
		nectar_holder = flower
	elif data.type == G.FlowerType.WEAPON:
		weapon_holders[data.index] = flower
	elif data.type == G.FlowerType.SUPER:
		super_flower = flower
		
func find_flower_spawn(type):
	var options = []
	if type == G.FlowerType.NORMAL:
		options = get_tree().get_nodes_in_group("fsnormal")
	if type == G.FlowerType.WEAPON:
		options = get_tree().get_nodes_in_group("fsweapon")
	if type == G.FlowerType.SUPER:
		options = get_tree().get_nodes_in_group("fssuper")
	options.shuffle()
	for o in options:
		var col = get_world_2d().direct_space_state.intersect_point(o.global_position, 1, [], G.LAYER_FLOWEREXCL_VAL, false, true)
		if not col:
			return o.global_position
	assert(false)
	return center

func flower_collected(flower, player):
	match flower.type:
		G.FlowerType.NORMAL:
			nectar_holder = player
			N.rpc_or_local(self, "nectar_collected", [flower.global_position])
		G.FlowerType.WEAPON:
			var ok = false
			for i in weapon_holders.size():
				if weapon_holders[i] == flower:
					weapon_holders[i] = player
					ok = true
					break
			assert(ok)
		G.FlowerType.SUPER:
			super_flower = null
			scored(player.team, player.id, G.FlowerType.SUPER)
			time_since_event = -EVENT_DELAY_MIN

remotesync func nectar_collected(pos):
	Game.play_sound_at_pos("pickup", pos)

func spawn_ladybug():
	object_counter += 1
	var data = {}
	data.id = object_counter
	if randf() < 0.5:
		data.start = Vector2(rand_range(-800, 800), -1000)
		data.end = Vector2(rand_range(-800, 800), 1000)
	else:
		data.start = Vector2(rand_range(-800, 800), 1000)
		data.end = Vector2(rand_range(-800, 800), -1000)
	N.rpc_or_local(self, "spawn_ladybug_real", [data])
	
remotesync func spawn_ladybug_real(data):
	var bug = Game.Ladybug.instance()
	objects_node.add_child(bug)
	bug.init(data)
			
func nectar_passed(player, vel):
	assert(nectar_holder == player) # TODO: fix this... race condition maybe?
	if nectar_holder != player:
		#nectar_holder = null
		return
	object_counter += 1
	var data = {
		"id": object_counter,
		"position": player.position,
		"vel": vel,
		"who": player.id
	}
	nectar_holder = null
	N.rpc_or_local(self, "spawn_nectar", [data])
	
remotesync func spawn_nectar(data):
	var proj = Game.Nectar.instance()
	objects_node.add_child(proj)
	proj.init(data)
	if Game.is_host():
		proj.connect("picked_up", self, "nectar_picked_up")
	nectar_holder = proj
	
func nectar_picked_up(nectar, player):
	nectar_holder = player
	if player != null:
		N.rpc_or_local(player, "set_carrying", [G.FlowerType.NORMAL])

func scored(team, who, type = G.FlowerType.NORMAL):
	print("SCORE! ", team, " ", who)
	var amt = 10
	var msg = "score"
	if type == G.FlowerType.SUPER:
		amt = 25
		msg = "superscore"
	elif type == G.ObjectType.LADYBUG:
		amt = 3
		msg = "ladybugscore"
	score[team] += amt
	if type == G.FlowerType.NORMAL:
		nectar_holder = null
	N.rpc_or_local(self, "update_score", [score[1], score[2], team, type])
	var p = players_node.get_node_or_null(str(who))
	if p != null:
		Game.server_message(msg, {
			"TEAMCOLOR": G.TEAM1_CHAT_COLOR if team == 1 else G.TEAM2_CHAT_COLOR,
			"TEAMNAME": team1_name if team == 1 else team2_name,
			"PLAYER": p.nameplate,
			"POINTS": str(amt)
		})
	
remotesync func update_score(team1, team2, team = 0, type = 0):
	if not Game.is_server:
		if type == G.FlowerType.SUPER:
			Game.play_sound("score_super")
		elif type == G.ObjectType.LADYBUG:
			Game.play_sound("score_ladybug")
		else:
			Game.play_sound("score")
	score[1] = team1
	score[2] = team2
	if match_gui != null:
		match_gui.update_scores()

func bullet_fired(player, vel):
	var ok = false
	for i in weapon_holders.size():
		if weapon_holders[i] == player:
			weapon_holders[i] = null
			ok = true
			break
	assert(ok)
	object_counter += 1
	var data = {
		"id": object_counter,
		"position": player.position,
		"vel": vel,
		"team": player.team,
		"who": player.id
	}
	N.rpc_or_local(self, "spawn_bullet", [data])
	
remotesync func spawn_bullet(data):
	var proj = Game.Bullet.instance()
	objects_node.add_child(proj)
	proj.init(data)

func get_hive(team):
	return get_node("Hive" + str(team))

func get_super_flower():
	return super_flower
	
func get_normal_flower():
	if nectar_holder != null and nectar_holder.is_in_group("flowers"):
		return nectar_holder
	return null
	
func get_weapon_flowers():
	var list = []
	for f in weapon_holders:
		if f != null and f.is_in_group("flowers"):
			list.append(f)
	return list

func get_nectar_carrier():
	if nectar_holder != null and nectar_holder.is_in_group("players"):
		return nectar_holder
	return null

func increment_player_stat(id, stat, amt = 1):
	if not id in player_stats:
		player_stats[id] = {}
	if not stat in player_stats[id]:
		player_stats[id][stat] = 0
	player_stats[id][stat] += amt
	N.rpc_or_local(self, "update_player_stat", [id, stat, player_stats[id][stat]])

puppet func update_player_stat(id, stat, value):
	if not id in player_stats:
		player_stats[id] = {}
	player_stats[id][stat] = value

func _on_Music_finished():
	$Music.play(3.412)

func _on_Boundary_body_exited(body):
	body.global_position = get_hive(body.team).global_position

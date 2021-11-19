extends Area2D

const TICK_RATE = 0.1
const COLLECT_TIMES = {
	G.FlowerType.NORMAL: 1.5,
	G.FlowerType.WEAPON: 1.0,
	G.FlowerType.SUPER: 8.0
}

var type = G.FlowerType.NORMAL

var dead = false
var collider
var indicator
var gatherers = {}
var winning = 0
var progress = 0

func _ready():
	set_process(false)

func init(data):
	name = str(data.id)
	position = data.position
	type = data.type
	add_to_group("flower" + str(type))
	var nodes = [$Normal, $Weapon, $Super]
	for i in nodes.size():
		if i == type:
			collider = nodes[i]
		else:
			nodes[i].hide()
			nodes[i].queue_free()
	collider.name = "Flower"
	collider.show()
	indicator = collider.get_node("Indicator")
	indicator.hide()
	var sprite = collider.get_node("Sprite")
	sprite.modulate = Color.transparent
	sprite.scale = Vector2(0.1, 0.1)
	$AnimationPlayer.play("grow")
	
func get_data():
	var data = {}
	data.position = position
	data.type = type
	return data

func tick():
	if dead: return
	
	# find players
	var player_areas = get_overlapping_areas()
	var team1 = []
	var team2 = []
	for p in player_areas:
		var player = p.owner
		if player.is_carrying(): continue
		if player.team == 1:
			team1.append(player)
		elif player.team == 2:
			team2.append(player)
		if not player in gatherers:
			gatherers[player] = 0
			
	# update gatherer contributions
	var new_gatherers = {}
	var top_1 = null
	var top_1_amt = -1
	var top_2 = null
	var top_2_amt = -1
	for g in gatherers:
		if not is_instance_valid(g): continue
		if not g in team1 and not g in team2: continue
		new_gatherers[g] = gatherers[g] + 1
		if g.team == 1 and new_gatherers[g] > top_1_amt:
			top_1 = g
			top_1_amt = new_gatherers[g]
		elif g.team == 2 and new_gatherers[g] > top_2_amt:
			top_2 = g
			top_2_amt = new_gatherers[g]
	gatherers = new_gatherers
	
	# update progress
	var winning_team = []
	if team1.size() > 0 and team2.size() == 0:
		winning_team = team1
		progress -= TICK_RATE / COLLECT_TIMES[type] * min(3, team1.size())
	elif team2.size() > 0 and team1.size() == 0:
		winning_team = team2
		progress += TICK_RATE / COLLECT_TIMES[type] * min(3, team2.size())
	elif team1.size() > team2.size():
		winning_team = team1
		progress -= TICK_RATE / COLLECT_TIMES[type] * 0.5
	elif team2.size() > team1.size():
		winning_team = team2
		progress += TICK_RATE / COLLECT_TIMES[type] * 0.5
	else:
		progress = move_toward(progress, 0, TICK_RATE * 0.25)
		
	# collect if possible
	if progress <= -1.0 and top_1 != null:
		collect(top_1)
	elif progress >= 1.0 and top_2 != null:
		collect(top_2)
	else:
		progress = clamp(progress, -1, 1)
		N.rpc_or_local(self, "update_progress", [progress, team1.size() > 0 or team2.size() > 0])
		
puppet func update_progress(prog, show_if_empty = false):
	progress = prog
	if prog < 0:
		$Progress1.value = -prog
		$Progress2.value = 0
	elif prog > 0:
		$Progress2.value = prog
		$Progress1.value = 0
	if abs(prog) > 0.01 or show_if_empty:
		$Progress1.show()
		$Progress2.show()
	else:
		$Progress1.hide()
		$Progress2.hide()

func collect(player):
	collider.disabled = true
	remove()
	#stop_all_gathering()
	Game.emit_signal("flower_collected", self, player)
	if type != G.FlowerType.SUPER:
		N.rpc_or_local(player, "set_carrying", [type])

func __stop_all_gathering():
	for g in gatherers:
		gatherers[g] = 0
		N.rpc_or_local(g, "set_gathering", [-1])

func remove():
	dead = true
	$Timer.stop()
	N.rpc_or_local(self, "despawn", [])

remotesync func despawn():
	$Progress1.hide()
	$Progress2.hide()
	if Game.is_server:
		queue_free()
	else:
		# TODO: animation
		queue_free()


func _on_Flower_area_entered(area):
	area.owner.set_gathering(type)
	
func _on_Flower_area_exited(area):
	area.owner.set_gathering(-1)


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "grow":
		collider.disabled = false
		if Game.is_host():
			$Timer.start()
		if not Game.is_server:
			set_process(true)
			indicator.show()
			indicator.set_as_toplevel(true)
			if type == G.FlowerType.NORMAL:
				Game.play_sound("flower_spawn")
			elif type == G.FlowerType.SUPER:
				Game.play_sound("super_spawn")
			
func _process(delta):
	N.clamp_node_to_screen(indicator, global_position, 20, false)


extends Node2D

const PASS_RANGE = 300
const PASS_RANGE_SQ = PASS_RANGE * PASS_RANGE
const PASS_MIN_RANGE = 100
const PASS_MIN_RANGE_SQ = PASS_MIN_RANGE * PASS_MIN_RANGE
const PASS_CHARGE_TIME = 0.5

const SHOOT_RANGE_SQ = 200 * 200
const SHOOT_CHARGE_TIME = 0.4

const BOOST_ATTACK_RANGE = 200
const BOOST_ATTACK_RANGE_SQ = BOOST_ATTACK_RANGE * BOOST_ATTACK_RANGE
const BOOST_MIN_DISTANCE_SQ = 600 * 600
const BOOST_CHARGE_TIME = 0.6

const ENEMY_FLOWER_RANGE_SQ = 400 * 400
const AVOID_DETECTION_RANGE = 500

enum Action {
	AQUIRE_NECTAR,
	AQUIRE_WEAPON,
	AQUIRE_SUPER,
	GATHER_FLOWER,
	CHASE_ENEMY_CARRIER,
	ASSIST_ALLY_CARRIER,
	CARRY_TO_GOAL,
	RETRIEVE_NECTAR,
	ATTACK_FLOWER,
	ATTACK_SUPER,
	ATTACK_NECTAR,
	ATTACK_NEARBY,
	PLAY_DEFENSE,
	PLAY_OFFENSE,
}

onready var player = owner
onready var timer = $AITimer
onready var shoot_timer = $ShootTimer
onready var shoot_ray = $ShootRay
onready var obstacle_ray = $ObstacleRay

var team
var enemy_team

var aiming_toward = null
var aiming_at = null
var current_action = null

func enable():
	timer.start()
	set_physics_process(true)
	team = player.team
	enemy_team = 2 if team == 1 else 1
	
func disable():
	timer.stop()
	aiming_toward = null
	aiming_at = null
	set_physics_process(false)

func _physics_process(delta):
	if aiming_toward != null and aiming_at != null:
		var pos = aiming_at.global_position
		if "velocity" in aiming_at:
			pos += aiming_at.velocity * 0.5
		shoot_aim(pos - global_position)

func ai_tick():
	timer.start(rand_range(0.1, 0.3))
	var possible_actions = {}
	
	# GET LEVEL DATA
	var hive = Game.level.get_hive(team)
	var enemy_hive = Game.level.get_hive(enemy_team)
	var nectar_holder = Game.level.nectar_holder
	var flower = nectar_holder if nectar_holder != null and nectar_holder.is_in_group("flowers") else null
	var carrier = nectar_holder if nectar_holder != null and nectar_holder.is_in_group("players") else null
	var nectar_drop = nectar_holder if nectar_holder != null and nectar_holder.is_in_group("nectar") else null
	var weapon_flowers = Game.level.get_weapon_flowers()
	var super_flower = Game.level.get_super_flower()
	var over_flower = player.flower_detector.get_overlapping_areas()
	over_flower = null if over_flower.size() == 0 else over_flower[0]
	
	# ACTIVELY SHOOTING
	if aiming_toward != null:
		hold()
		return
		
	# VALIDATE CURRENT ACTION
	
	var current_weight = 200
	if current_action != null:
		match current_action.action:
			Action.AQUIRE_NECTAR:
				if flower == null: current_action = null
			Action.AQUIRE_WEAPON:
				if not current_action.weapon in weapon_flowers: current_action = null
			Action.AQUIRE_SUPER:
				if super_flower == null: current_action = null
			Action.GATHER_FLOWER:
				if over_flower == null: current_action = null
			Action.CHASE_ENEMY_CARRIER:
				if carrier == null or carrier.team == player.team: current_action = null
			Action.ASSIST_ALLY_CARRIER:
				if carrier == null or carrier.team != player.team: current_action = null
			Action.CARRY_TO_GOAL:
				if carrier != player: current_action = null
			Action.RETRIEVE_NECTAR:
				if nectar_drop == null: current_action = null
			Action.ATTACK_FLOWER:
				if flower == null or not can_attack(): current_action = null
			Action.ATTACK_SUPER:
				if super_flower == null or not can_attack(): current_action = null
			Action.ATTACK_NECTAR:
				if nectar_drop == null or not can_attack(): current_action = null
			Action.ATTACK_NEARBY:
				if not can_attack(): current_action = null
			Action.PLAY_DEFENSE:
				current_weight = 20
			Action.PLAY_OFFENSE:
				current_weight = 20
				
	if current_action != null:
		possible_actions[current_action] = current_weight
	
	# FIND POSSIBLE ACTIONS
	
	if player.carrying == G.FlowerType.NORMAL:
		possible_actions[{"action": Action.CARRY_TO_GOAL}] = 50
		
	elif player.carrying == G.FlowerType.WEAPON:
		if carrier != null and carrier.team != team:
			possible_actions[{"action": Action.CHASE_ENEMY_CARRIER}] = 30
		elif carrier != null and carrier.team == team:
			possible_actions[{"action": Action.ASSIST_ALLY_CARRIER}] = 10
		elif nectar_drop != null:
			possible_actions[{"action": Action.ATTACK_NECTAR}] = 10
		elif flower != null:
			possible_actions[{"action": Action.ATTACK_FLOWER}] = 10
		if super_flower != null:
			possible_actions[{"action": Action.ATTACK_SUPER}] = 20
		possible_actions[{"action": Action.PLAY_DEFENSE}] = 1
		possible_actions[{"action": Action.PLAY_OFFENSE}] = 1
		
	elif over_flower != null and not player.is_carrying():
		if current_action == null or current_action.action != Action.GATHER_FLOWER:
			possible_actions[{"action": Action.GATHER_FLOWER}] = 50
			
	else:
		if super_flower != null:
			possible_actions[{"action": Action.AQUIRE_SUPER}] = 20
			if player.can_boost():
				possible_actions[{"action": Action.ATTACK_SUPER}] = 10
		if carrier != null and carrier.team != team:
			possible_actions[{"action": Action.CHASE_ENEMY_CARRIER}] = 10
		elif carrier != null and carrier.team == team:
			possible_actions[{"action": Action.ASSIST_ALLY_CARRIER}] = 10
		elif nectar_drop != null:
			possible_actions[{"action": Action.RETRIEVE_NECTAR}] = 10
			if player.can_boost():
				possible_actions[{"action": Action.ATTACK_NECTAR}] = 5
		elif flower != null:
			possible_actions[{"action": Action.AQUIRE_NECTAR}] = 20
			if player.can_boost():
				possible_actions[{"action": Action.ATTACK_FLOWER}] = 5
		for weapon in weapon_flowers:
			possible_actions[{"action": Action.AQUIRE_WEAPON, "weapon": weapon}] = 5
		possible_actions[{"action": Action.PLAY_DEFENSE}] = 1
		possible_actions[{"action": Action.PLAY_OFFENSE}] = 1
		
	# SELECT ACTION
	
	assert(possible_actions.size() > 0)
	current_action = N.rand_weighted(possible_actions)
	
	# PERFORM ACTION
	
	match current_action.action:
		Action.AQUIRE_NECTAR:
			move(flower.global_position - global_position, true)
		Action.AQUIRE_WEAPON:
			move(current_action.weapon.global_position - global_position, false)
		Action.AQUIRE_SUPER:
			move(super_flower.global_position - global_position, true)
		Action.GATHER_FLOWER:
			hold()
			if can_attack():
				for p in over_flower.get_overlapping_areas():
					if p.owner.team != team:
						shoot(p.global_position - global_position, p.owner)
						break
		Action.CHASE_ENEMY_CARRIER:
			var vec = carrier.global_position - global_position
			if player.carrying == G.FlowerType.WEAPON:
				if vec.length_squared() < SHOOT_RANGE_SQ:
					shoot(vec, carrier)
					return
			elif player.can_boost() and vec.length_squared() < BOOST_ATTACK_RANGE_SQ:
				boost(vec)
				return
			var tar = carrier.global_position + carrier.global_position.direction_to(enemy_hive.global_position) * 100
			move(tar - global_position, false)
		Action.ASSIST_ALLY_CARRIER:
			var attacked = attack_location(carrier, BOOST_ATTACK_RANGE * 1.5)
			if not attacked:
				var tar_pos = carrier.global_position + carrier.global_position.direction_to(hive.global_position) * 100
				move(tar_pos - global_position, true)
		Action.CARRY_TO_GOAL:
			var vector_to_goal = hive.global_position - global_position
			if vector_to_goal.length_squared() < PASS_RANGE_SQ:
				var col = cast_shoot_ray(hive.global_position)
				if col and col.is_in_group("hive" + str(player.team)):
					shoot(vector_to_goal, null)
					return
			var allies = get_players_in_range(PASS_RANGE, team)
			for p in allies:
				if p.is_carrying(): continue
				var vector_to_player = p.global_position - global_position
				var dist_sq = vector_to_player.length_squared()
				if PASS_MIN_RANGE_SQ < dist_sq and dist_sq < PASS_RANGE_SQ and vector_to_player.dot(vector_to_goal) > 0:
					var col = cast_shoot_ray(p.global_position)
					if col == p:
						shoot(vector_to_player, col)
						return
			move(vector_to_goal, false)
		Action.RETRIEVE_NECTAR:
			move(nectar_drop.global_position - global_position, true)
		Action.ATTACK_FLOWER:
			var attacked = attack_location(flower, BOOST_ATTACK_RANGE * 1.5)
			if not attacked:
				move(flower.global_position - global_position, false)
		Action.ATTACK_SUPER:
			var attacked = attack_location(super_flower, BOOST_ATTACK_RANGE * 1.5)
			if not attacked:
				move(super_flower.global_position - global_position, false)
		Action.ATTACK_NECTAR:
			var attacked = attack_location(nectar_drop, BOOST_ATTACK_RANGE * 1.5)
			if not attacked:
				move(nectar_drop.global_position - global_position, false)
		Action.PLAY_DEFENSE:
			var vec = (enemy_hive.global_position - hive.global_position) * 0.25
			var pos = hive.global_position + vec
			var attacked = attack_location(pos, vec.length())
			if not attacked:
				move(pos - global_position, false)
		Action.PLAY_OFFENSE:
			var vec = (hive.global_position - enemy_hive.global_position) * 0.25
			var pos = enemy_hive.global_position + vec
			var attacked = attack_location(pos, vec.length())
			if not attacked:
				move(pos - global_position, false)

func can_attack():
	return player.carrying == G.FlowerType.WEAPON or player.can_boost()

func attack_location(tar, radius):
	if player.carrying == G.FlowerType.WEAPON or player.can_boost():
		var attack_range_sq = SHOOT_RANGE_SQ if player.carrying == G.FlowerType.WEAPON else BOOST_ATTACK_RANGE_SQ
		var targets = []
		for p in get_players_in_range(radius, enemy_team, tar):
			if p.global_position.distance_squared_to(global_position) < attack_range_sq:
				targets.append(p)
		if targets.size() > 0:
			var target = N.rand_array(targets)
			shoot(target.global_position - global_position, target)
			return true
	return false

func get_players_in_range(dist, in_team, from = null):
	var params = Physics2DShapeQueryParameters.new()
	var shape = CircleShape2D.new()
	shape.radius = dist
	params.set_shape(shape)
	if from == null:
		params.transform = global_transform
	elif from is Transform2D:
		params.transform = from
	elif from is Node2D:
		params.transform = from.global_transform
	elif from is Vector2:
		params.transform = Transform2D(0, from)
	else:
		assert(false)
		return []
	params.exclude = [player]
	if in_team == 1:
		params.collision_layer = G.LAYER_TEAM1_VAL
	elif in_team == 2:
		params.collision_layer = G.LAYER_TEAM2_VAL
	else:
		params.collision_layer = G.LAYER_TEAM1_VAL | G.LAYER_TEAM2_VAL
	var list = []
	for p in get_world_2d().direct_space_state.intersect_shape(params, 15):
		list.append(p.collider)
	return list

func ai_tick_old():

	# GET LEVEL DATA
	var hive = Game.level.get_hive(player.team)
	var nectar_holder = Game.level.nectar_holder
	var flower = nectar_holder if nectar_holder != null and nectar_holder.is_in_group("flowers") else null
	var carrier = nectar_holder if nectar_holder != null and nectar_holder.is_in_group("players") else null
	var nectar_drop = nectar_holder if nectar_holder != null and nectar_holder.is_in_group("nectar") else null
	var weapon_flowers = Game.level.get_weapon_flowers()
	var super_flower = Game.level.get_super_flower()

	# ACTIVELY SHOOTING
	if aiming_toward != null:
		hold()

	# CARRYING NORMAL NECTAR
	elif player.carrying == G.FlowerType.NORMAL:
		# CHECK FOR GOAL SHOT
		var vector_to_goal = hive.global_position - global_position
		var col = cast_shoot_ray(hive.global_position)
		if col and col.is_in_group("hive" + str(player.team)):
			# SHOOT AT GOAL!
			shoot(vector_to_goal, null)
		else:
			# CHECK FOR ALLY PASS
			for p in get_tree().get_nodes_in_group("players"):
				if p.team == player.team:
					var vector_to_player = p.global_position - global_position
					if vector_to_player.length_squared() < PASS_RANGE_SQ and vector_to_player.dot(vector_to_goal) > 0:
						col = cast_shoot_ray(player.global_position)
						if col == player:
							# PASS TO ALLY
							shoot(vector_to_player, col)
							return
			# OTHERWISE MOVE TOWARD GOAL
			move(vector_to_goal)
			
	# CARRYING WEAPON NECTAR
	elif player.carrying == G.FlowerType.WEAPON:
		var shoot_target = null
		# DEFEND SUPER FLOWER
		if super_flower != null:
			# FIND ENEMY GATHERER
			shoot_target = get_enemy_gatherer(super_flower)
			# OR FIND NEARBY ENEMY PLAYER
			if shoot_target == null:
				for p in get_tree().get_nodes_in_group("player"):
					if p.team != player.team and p.global_position.distance_squared_to(super_flower.global_position) < ENEMY_FLOWER_RANGE_SQ:
						shoot_target = p
						break
		# TRACK DOWN CARRIER
		elif carrier != null:
			if carrier.team != player.team:
				shoot_target = carrier
			else:
				pass # TODO: aid carrier
		# DEFEND NORMAL FLOWER
		elif flower != null:
			# FIND ENEMY GATHERER
			shoot_target = get_enemy_gatherer(flower)
			# OR FIND NEAREST PLAYER TO FLOWER
			if shoot_target == null:
				var closest = null
				var closest_dist = 100000
				for p in get_tree().get_nodes_in_group("player"):
					if p.team != player.team:
						var dist = p.global_position.distance_squared_to(flower.global_position)
						if dist < closest_dist:
							closest_dist = dist
							closest = p
				if closest != null:
					shoot_target = closest
		# MOVE AND SHOOT
		if shoot_target != null:
			var shoot_vector = shoot_target.global_position - global_position
			if shoot_vector.length_squared() < SHOOT_RANGE_SQ:
				# SHOOT!
				shoot(shoot_vector, shoot_target)
			else:
				# MOVE TOWARD TARGET
				move(shoot_vector)
		else:
			# NO TARGET, MOVE TOWARD CENTER, NEW TARGET SHOULD APPEAR SOON
			move(Game.level.center - global_position, false)
	
	# CURRENTLY GATHERING
	elif player.gathering >= 0:
		# HOLD POSITION TO GATHER
		hold()
	
	# NOT CARRYING ANYTHING
	else:
		# TARGET SUPER FLOWER
		if super_flower != null:
			var enemy = get_enemy_gatherer(super_flower)
			if enemy != null:
				# ATTACK ENEMY GATHERER
				var enemy_vector = enemy.global_position - global_position
				if player.can_boost() and enemy_vector.length_squared() < BOOST_ATTACK_RANGE_SQ:
					boost(enemy_vector)
				else:
					move(enemy_vector)
			else:
				# GO TO GATHER IT
				move(super_flower.global_position - global_position)
		# TARGET ENEMY CARRIER
		elif carrier != null and carrier.team != player.team:
			var enemy_vector = carrier.global_position - global_position
			if player.can_boost() and enemy_vector.length_squared() < BOOST_ATTACK_RANGE_SQ:
				# ENEMY IN RANGE - ATTACK
				boost(enemy_vector)
			else:
				# LOOK FOR WEAPONS
				var closest = get_closest_weapon(weapon_flowers)
				if closest[0] != null and closest[1] < enemy_vector.length_squared():
					# GO TOWARD WEAPON
					move(closest[0].global_position - global_position)
				else:
					# GO TOWARD CARRIER
					move(enemy_vector, false)
		elif carrier != null and carrier.team == player.team:
			var carrier_to_goal = hive.global_position - carrier.global_position
			var carrier_to_me = global_position - carrier.global_position
			if carrier_to_goal.dot(carrier_to_me) > 0:
				# TODO: search for enemies to clear path
				if carrier_to_goal.length_squared() > PASS_RANGE_SQ:
					var t = carrier_to_goal.clamped(PASS_RANGE) + carrier.global_position
					move(t - global_position)
				else:
					var t = (carrier.global_position + global_position) / 2
					move(t - global_position)
			else:
				var closest = get_closest_weapon(weapon_flowers)
				if closest[0] != null:
					move(closest[0].global_position - global_position)
				else:
					move(hive.global_position - global_position)
		elif flower != null:
			move(flower.global_position - global_position)
		elif nectar_drop != null:
			move(nectar_drop.global_position - global_position)
		else:
			move(Game.level.center - global_position, false)
				
func get_enemy_gatherer(flower):
	for gatherer in flower.gatherers:
		if gatherer.team != player.team:
			return gatherer
	return null
	
func get_closest_weapon(weapon_flowers):
	var closest = null
	var closest_dist = 1000000
	for w in weapon_flowers:
		var dist = w.global_position.distance_squared_to(global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = w
	return [closest, closest_dist]
	
func cast_shoot_ray(at):
	shoot_ray.cast_to = shoot_ray.to_local(at)
	shoot_ray.force_raycast_update()
	return shoot_ray.get_collider()

func move(vector, boost_if_possible = true):
	# TODO: handle "arrlval" better, so the CPU can actually collect flowers
	# TODO: fix steering
	var v = vector.clamped(AVOID_DETECTION_RANGE)
	obstacle_ray.cast_to = v
	obstacle_ray.force_raycast_update()
	var col = obstacle_ray.get_collider()
	if col:
		vector = obstacle_ray.get_collision_point() - global_position
		vector += obstacle_ray.get_collision_normal() * 100
	if boost_if_possible and player.can_boost() and vector.length_squared() > BOOST_MIN_DISTANCE_SQ:
		boost(vector)
	elif not player.is_boosting():
		var desired = vector.normalized()
		var current = player.velocity.normalized()
		update_movement((desired * 3 - current).normalized())

func hold():
	update_movement(Vector2.ZERO)
	
func update_movement(dir):
	N.rpc_or_local(player, "update_movement", [dir])

func boost(vector):
	shoot(vector, null)

func shoot(vector, target):
	hold()
	if player.carrying == G.FlowerType.NORMAL:
		shoot_timer.wait_time = PASS_CHARGE_TIME
	elif player.carrying == G.FlowerType.WEAPON:
		shoot_timer.wait_time = SHOOT_CHARGE_TIME
	else:
		shoot_timer.wait_time = BOOST_CHARGE_TIME
		target = null
	aiming_toward = vector
	aiming_at = target
	shoot_timer.start()
	N.rpc_or_local(player, "shoot_start", [aiming_toward.normalized()])

func shoot_aim(vector):
	aiming_toward = vector
	if Engine.get_physics_frames() % 6 == 0:
		N.rpc_or_local(player, "shoot_aim", [aiming_toward.normalized()])

func shoot_fire():
	var cancel = false
	if player.carrying == G.FlowerType.NORMAL:
		var col = cast_shoot_ray(aiming_toward)
		if col and col.is_in_group("players") and col.team == enemy_team:
			cancel = true
	if cancel:
		N.rpc_or_local(player, "shoot_cancel", [])
	else:
		N.rpc_or_local(player, "shoot", [aiming_toward.normalized()])
	aiming_toward = null
	aiming_at = null



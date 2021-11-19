extends KinematicBody2D

const ACCEL_NORMAL = 600.0
const ACCEL_DISORIENTED = 150.0
const ACCEL_STUNNED = 100.0
const ACCEL_NECTAR = 400.0
const DECEL_FACTOR = 1.3

const MAX_SPEED_NORMAL = 150.0
const MAX_SPEED_NECTAR = 75.0
const MAX_SPEED_WEAPON = 150.0
const MAX_SPEED_BOOST = 400.0

const COLLISION_VELOCITY_FACTOR = 0.9
const COLLISION_STUN_TIME = 0.5
const COLLISION_DISORIENT_TIME = 1.0
const COLLISION_MIN_VEL = 50

const BOOST_MIN_DURATION = 0.2
const BOOST_MAX_DURATION = 0.5
const BOOST_MIN_CHARGE_TIME = 0.3
const BOOST_MAX_CHARGE_TIME = 0.7
const BOOST_COOLDOWN = 5

const PASS_MIN_POWER = 200.0
const PASS_MAX_POWER = 350.0
const PASS_MIN_CHARGE_TIME = 0.2
const PASS_MAX_CHARGE_TIME = 0.5

const FIRE_MIN_POWER = 400.0
const FIRE_MAX_POWER = 600.0
const FIRE_MIN_CHARGE_TIME = 0.2
const FIRE_MAX_CHARGE_TIME = 0.5

const HIT_STUN_TIME = 0.5
const HIT_DISORIENT_TIME = 2.0
const HIT_VEL = 350.0

#const NECTAR_PER_TICK = 1

const SYNC_INTERVAL = 4
const SMOOTHING_SPEED = 25

onready var flower_detector = $FlowerDetector
onready var visual = $Visuals
onready var bee_visual = $Visuals/Bee
onready var shadow = $Visuals/Shadow
onready var sprite = $Visuals/Bee/Holder/Sprite1
onready var sprite_holder = $Visuals/Bee/Holder
onready var bucket_visual = $Visuals/Bucket
onready var bucket_sprite = $Visuals/Bucket/Empty
onready var bucket_filled = $Visuals/Bucket/Nectar
onready var stun_anim = $Visuals/Bee/StunAnim
onready var nameplate_label = $Visuals/Nameplate
onready var indicator = $Indicator
onready var indicator_bucket = $Indicator/IndicatorBucket

var id := 0
var team := 0
var cpu := false
var nameplate = "Bumble"
var velocity := Vector2.ZERO
var movement := Vector2.ZERO
var facing := Vector2.RIGHT
var aim_dir := Vector2.ZERO
var stun_duration := 0.0
var disorient_duration := 0.0
var boost_duration := 0.0
var boost_cd := 0.0
var gathering = -1
var gathering_progress = 0
var carrying = -1
var shoot_start_time = 0
var shoot_type = -1
var dead = false

var actual_position := Vector2.ZERO
var sync_offset = randi() % SYNC_INTERVAL

func _ready():
	indicator.set_as_toplevel(true)

func init(data):
	id = data.id
	name = str(data.id)
	cpu = data.cpu
	nameplate = data.name
	team = data.team
	position = data.position
	actual_position = position
	if team == 2: facing = Vector2.LEFT
	
	add_to_group("team" + str(team))
	
	if data.has("velocity"): velocity = data.velocity
	if data.has("movement"): movement = data.movement
	if data.has("facing"): facing = data.facing
	if data.has("stun"): stun_duration = data.stun
	if data.has("disorient"): disorient_duration = data.disorient
	if data.has("boost"): boost_duration = data.boost
	if data.has("gathering"): gathering = data.gathering
	if data.has("carrying"): carrying = data.carrying
	
	if not Game.is_server and data.id == Game.player_id:
		$Camera2D.current = true
		Game.player = self
	else:
		$PlayerController.queue_free()
		$Camera2D.queue_free()
		
	if Game.is_host():
		set_layers()
	if not Game.is_host() or not cpu:
		$CPUController.queue_free()
	else:
		$CPUController.enable()
		
	if Game.is_server:
		set_process(false)
		
	if team == 1:
		sprite = find_node("Sprite1")
		find_node("Sprite2").queue_free()
		find_node("Indicator2").queue_free()
		nameplate_label.text = "< " + nameplate
		nameplate_label.set("custom_colors/font_color", Color("#f2dfa7"))
	else:
		sprite = find_node("Sprite2")
		find_node("Sprite1").queue_free()
		find_node("Indicator1").queue_free()
		nameplate_label.text = nameplate + " >"
		nameplate_label.set("custom_colors/font_color", Color("#80ccf1"))
	update_facing()
	update_visuals()

func set_layers():
	set_collision_layer_bit(G.LAYER_TEAM1 if team == 1 else G.LAYER_TEAM2, true)
	set_collision_mask_bit(G.LAYER_TEAM2 if team == 1 else G.LAYER_TEAM1, true)

func deactivate_ai():
	if cpu:
		$CPUController.disable()

func remove():
	dead = true
	if Game.is_host():
		deactivate_ai()
	if Game.is_server or not Game.match_started:
		queue_free()
	else:
		var tween = Tween.new()
		add_child(tween)
		tween.interpolate_property(self, "modulate", Color.white, Color.transparent, 1)
		tween.start()
		get_tree().create_timer(1).connect("timeout", self, "queue_free")

func get_data():
	var data = {}
	data.id = id
	data.name = nameplate
	data.cpu = cpu
	data.team = team
	data.position = position
	if velocity != Vector2.ZERO:
		data.velocity = velocity
	else:
		data.facing = facing
	if movement != Vector2.ZERO:
		data.movement = movement
	if stun_duration > 0:
		data.stun = stun_duration
	if disorient_duration > 0:
		data.disorient = disorient_duration
	if boost_duration > 0:
		data.boost = boost_duration
	if gathering >= 0:
		data.gathering = gathering
	if carrying >= 0:
		data.carrying = carrying
	return data

func update_facing():
	if shoot_start_time > 0:
		facing = aim_dir
	elif velocity != Vector2.ZERO:
		facing = velocity.normalized()
	elif movement != Vector2.ZERO:
		facing = movement.normalized()
	if facing.x > 0:
		sprite_holder.scale.x = 1
		bee_visual.rotation = facing.angle()
	elif facing.x < 0:
		sprite_holder.scale.x = -1
		bee_visual.rotation = facing.angle() - PI
	shadow.scale.x = sprite_holder.scale.x
	shadow.rotation = bee_visual.rotation

func update_visuals():
	if gathering >= 0:
		$GatheringParticles.emitting = true
		if gathering == G.FlowerType.NORMAL:
			$GatheringParticles.modulate = Color.gold
		elif gathering == G.FlowerType.WEAPON:
			$GatheringParticles.modulate = Color.hotpink
		elif gathering == G.FlowerType.SUPER:
			$GatheringParticles.modulate = Color.purple
	else:
		$GatheringParticles.emitting = false
	if carrying >= 0:
		bucket_visual.show()
		if carrying == G.FlowerType.NORMAL:
			bucket_filled.modulate = Color.gold
		elif carrying == G.FlowerType.WEAPON:
			bucket_filled.modulate = Color.red
	else:
		bucket_visual.hide()
	indicator_bucket.visible = carrying == G.FlowerType.NORMAL
	if boost_duration > 0:
		pass

func is_carrying():
	return carrying >= 0

func can_gather():
	return carrying < 0 and velocity.length() <= MAX_SPEED_NORMAL

func can_boost():
	return carrying < 0 and boost_cd <= 0

func is_boosting():
	return boost_duration > 0

func _process(delta):
	N.clamp_node_to_screen(indicator, global_position, 10, false)

func _physics_process(delta):
	if not Game.match_started:
		return
	
	if boost_cd > 0:
		boost_cd -= delta
		
	var accel = ACCEL_NORMAL
	var max_speed = MAX_SPEED_NORMAL
	if carrying == G.FlowerType.NORMAL:
		accel = ACCEL_NECTAR
		max_speed = MAX_SPEED_NECTAR
	elif carrying == G.FlowerType.WEAPON:
		max_speed = MAX_SPEED_WEAPON
	elif boost_duration > 0:
		max_speed = MAX_SPEED_BOOST
		
	if stun_duration > 0:
		stun_duration -= delta
		if stun_duration <= 0 and disorient_duration <= 0:
			stun_anim.play("reset")
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL_STUNNED * delta)
	else:
		if disorient_duration > 0:
			disorient_duration -= delta
			accel = ACCEL_DISORIENTED
			if disorient_duration <= 0:
				stun_anim.play("reset")
		if boost_duration > 0:
			boost_duration -= delta
		elif movement == Vector2.ZERO or shoot_start_time > 0:
			velocity = velocity.move_toward(Vector2.ZERO, accel * DECEL_FACTOR * delta)
		else:
			velocity += movement * accel * delta
			velocity = velocity.clamped(max_speed)
	
	sprite.speed_scale = range_lerp(velocity.length(), 0, MAX_SPEED_NORMAL, 0.5, 1.0)
	
	if velocity != Vector2.ZERO:
		update_facing()
		
		var col = move_and_collide(velocity * delta)
		if Game.is_host():
			if col and stun_duration <= 0:
				if col.collider.is_in_group("players"):
					player_collision(col.collider, col.normal)
			if Engine.get_physics_frames() % SYNC_INTERVAL == sync_offset:
				N.rpc_or_local(self, "update_position", [position])
		else:
			position = position.move_toward(actual_position, SMOOTHING_SPEED * delta)

func player_collision(other, normal):
	var vl1 = velocity.length()
	var vl2 = other.velocity.length()
	var nn = -normal
	var f1 = -velocity.rotated(-normal.angle()).x * nn
	var r1 = velocity - f1
	var f2 = -other.velocity.rotated(-nn.angle()).x * normal
	var r2 = other.velocity - f2
	var self_new = f2 + r1
	var other_new = f1 + r2
	var self_disorient = COLLISION_DISORIENT_TIME * (vl2 / (vl1 + vl2))
	var other_disorient = COLLISION_DISORIENT_TIME * (vl1 / (vl1 + vl2))
	var total_vel = self_new.length() + other_new.length()
	if total_vel < COLLISION_MIN_VEL:
		var self_pct = self_new.length() / total_vel
		var other_pct = 1.0 - self_pct
		self_new = self_new.normalized() * self_pct * COLLISION_MIN_VEL
		other_new = other_new.normalized() * other_pct * COLLISION_MIN_VEL
	N.rpc_or_local(self, "update_collision", [self_new, COLLISION_STUN_TIME, self_disorient])
	N.rpc_or_local(other, "update_collision", [other_new, COLLISION_STUN_TIME, other_disorient])
	if carrying == G.FlowerType.NORMAL and vl2 > vl1 and vl2 > MAX_SPEED_NORMAL + 10:
		call_deferred("pass_nectar")
	if other.carrying == G.FlowerType.NORMAL and vl1 > vl2 and vl1 > MAX_SPEED_NORMAL + 10:
		other.call_deferred("pass_nectar")

func hit(vel):
	N.rpc_or_local(self, "update_collision", [vel.normalized() * HIT_VEL, HIT_STUN_TIME, HIT_DISORIENT_TIME, true])
	if carrying == G.FlowerType.NORMAL:
		call_deferred("pass_nectar")

#func player_collision_old(other, normal):
#	var v1 = velocity.length()
#	var v2 = other.velocity.length()
#	var other_vel = other.velocity
#	if other_vel == Vector2.ZERO:
#		other_vel = normal
#	var self_new = velocity.bounce(normal).normalized() * v2 * COLLISION_VELOCITY_FACTOR
#	var other_new = other_vel.bounce(-normal).normalized() * v1 * COLLISION_VELOCITY_FACTOR
#	var self_stun = COLLISION_DISORIENT_TIME * (v2 / (v1 + v2))
#	var other_stun = COLLISION_DISORIENT_TIME * (v1 / (v1 + v2))
#	var total_vel = (self_new + other_new).length()
#	if total_vel < COLLISION_MIN_VEL:
#		var self_pct = self_new.length() / total_vel
#		var other_pct = 1.0 - self_pct
#		self_new = self_new.normalized() * self_pct * COLLISION_MIN_VEL
#		other_new = other_new.normalized() * other_pct * COLLISION_MIN_VEL
#	prints(name, other.name, v1, v2, rad2deg(velocity.angle()), rad2deg(other_vel.angle()), self_new.length(), other_new.length(), rad2deg(self_new.angle()), rad2deg(other_new.angle()))
#	N.rpc_or_local(self, "update_collision", [self_new, self_stun])
#	N.rpc_or_local(other, "update_collision", [other_new, other_stun])
#	if carrying == G.FlowerType.NORMAL:
#		pass_nectar()
#	if other.carrying == G.FlowerType.NORMAL:
#		other.pass_nectar()

remotesync func update_movement(move):
	var sender = get_tree().get_rpc_sender_id()
	if sender <= 1 or sender == id:
		movement = move
		
puppet func update_position(pos):
	if get_tree().get_rpc_sender_id() <= 1:
		actual_position = pos
		if position.distance_squared_to(actual_position) > SMOOTHING_SPEED * SMOOTHING_SPEED:
			position = actual_position

remotesync func update_collision(new_vel, stun, disorient, bullet = false):
	if get_tree().get_rpc_sender_id() > 1: return
	velocity = new_vel
	stun_duration = stun
	disorient_duration = disorient
	boost_duration = 0
	shoot_cancel()
	if stun > 0 or disorient > 0:
		stun_anim.play("stunned")
	if bullet:
		Game.play_sound_at_pos("hit", global_position)
	elif id == Game.player_id:
		pass # TODO: play sound

func get_shoot_arrow_data():
	var length = 0
	var state = 0
	var width = 1.0
	if shoot_start_time > 0:
		var time = (OS.get_ticks_msec() - shoot_start_time) / 1000.0
		if carrying == G.FlowerType.NORMAL:
			var power = 0
			if time < PASS_MIN_CHARGE_TIME:
				power = calc_shoot_power(time, 0, PASS_MIN_CHARGE_TIME, 0, PASS_MIN_POWER)
			elif time > PASS_MAX_CHARGE_TIME:
				power = PASS_MAX_POWER
				state = 2
			else:
				power = calc_shoot_power(time, PASS_MIN_CHARGE_TIME, PASS_MAX_CHARGE_TIME, PASS_MIN_POWER, PASS_MAX_POWER)
				state = 1
			length = (power * (power / Game.NectarScript.DECELERATION)) / 2.0
		elif carrying == G.FlowerType.WEAPON:
			var power = 0
			if time < FIRE_MIN_CHARGE_TIME:
				power = calc_shoot_power(time, 0, FIRE_MIN_CHARGE_TIME, 0, FIRE_MIN_POWER)
			elif time > FIRE_MAX_CHARGE_TIME:
				power = FIRE_MAX_POWER
				state = 2
			else:
				power = calc_shoot_power(time, FIRE_MIN_CHARGE_TIME, FIRE_MAX_CHARGE_TIME, FIRE_MIN_POWER, FIRE_MAX_POWER)
				state = 1
			length = power
		else:
			var dur = 0
			if time < BOOST_MIN_CHARGE_TIME:
				dur = calc_shoot_power(time, 0, BOOST_MIN_CHARGE_TIME, 0, BOOST_MIN_DURATION)
			elif time > BOOST_MAX_CHARGE_TIME:
				dur = BOOST_MAX_DURATION
				state = 2
			else:
				dur = calc_shoot_power(time, BOOST_MIN_CHARGE_TIME, BOOST_MAX_CHARGE_TIME, BOOST_MIN_DURATION, BOOST_MAX_DURATION)
				state = 1
			length = MAX_SPEED_BOOST * dur
	return {
		"len": length,
		"state": state,
		"rot": aim_dir.angle()
	}

remotesync func shoot_start(dir):
	shoot_start_time = OS.get_ticks_msec()
	movement = Vector2.ZERO
	aim_dir = dir
	update_facing()
	stun_anim.play("chargeup")
	
remotesync func shoot_aim(dir):
	aim_dir = dir
	update_facing()

remotesync func shoot_cancel():
	shoot_start_time = 0
	update_facing()
	if stun_anim.current_animation == "chargeup":
		stun_anim.play("reset")

remotesync func shoot(dir):
	if Game.is_host() and shoot_start_time > 0:
		var time = (OS.get_ticks_msec() - shoot_start_time) / 1000.0
		if carrying == G.FlowerType.NORMAL:
			if time >= PASS_MIN_CHARGE_TIME:
				var power = calc_shoot_power(time, PASS_MIN_CHARGE_TIME, PASS_MAX_CHARGE_TIME, PASS_MIN_POWER, PASS_MAX_POWER)
				pass_nectar(dir * power)
		elif carrying == G.FlowerType.WEAPON:
			if time >= FIRE_MIN_CHARGE_TIME:
				var power = calc_shoot_power(time, FIRE_MIN_CHARGE_TIME, FIRE_MAX_CHARGE_TIME, FIRE_MIN_POWER, FIRE_MAX_POWER)
				shoot_bullet(dir * power)
		elif can_boost():
			if time >= BOOST_MIN_CHARGE_TIME:
				var dur = calc_shoot_power(time, BOOST_MIN_CHARGE_TIME, BOOST_MAX_CHARGE_TIME, BOOST_MIN_DURATION, BOOST_MAX_DURATION)
				N.rpc_or_local(self, "boost", [dir, dur])
	shoot_start_time = 0
	if stun_anim.current_animation == "chargeup":
		stun_anim.play("reset")

func calc_shoot_power(time, min_time, max_time, min_power, max_power):
	if time < min_time: return 0
	if time >= max_time: return max_power
	var pct = float(time - min_time) / (max_time - min_time)
	return min_power + (max_power - min_power) * pct

remotesync func set_gathering(type, progress = 0):
	gathering = type
	gathering_progress = progress
	if not Game.is_server:
		update_visuals()
	
remotesync func set_carrying(type):
	carrying = type
	if not Game.is_server:
		update_visuals()
	
remotesync func boost(dir, dur):
	velocity = dir * MAX_SPEED_BOOST
	boost_duration = dur
	boost_cd = BOOST_COOLDOWN
	if not Game.is_server:
		Game.play_sound_at_pos("boost", global_position)
	
func pass_nectar(vel = Vector2.ZERO):
	N.rpc_or_local(self, "set_carrying", [-1])
	Game.emit_signal("nectar_passed", self, vel)

func shoot_bullet(vel):
	N.rpc_or_local(self, "set_carrying", [-1])
	Game.emit_signal("bullet_fired", self, vel)
	

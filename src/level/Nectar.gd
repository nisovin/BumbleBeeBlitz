extends Area2D

signal picked_up

const DECELERATION = 250
const SPIN_SPEED = 6
const PICKUP_DELAY = 0.3
const DECAY_TIME = 10.0

var velocity := Vector2.ZERO
var who = null
var dead = false

func init(data):
	name = "Nectar" + str(data.id)
	global_position = data.position
	velocity = data.vel
	who = data.who
	if Game.is_host():
		connect("area_entered", self, "score")
		# TODO: change this so others can immediately pick up
		get_tree().create_timer(PICKUP_DELAY, false).connect("timeout", self, "enable_pickup")
		get_tree().create_timer(DECAY_TIME, false).connect("timeout", self, "decay")
	if not Game.is_server:
		if velocity != Vector2.ZERO:
			Game.play_sound_at_pos("pass", global_position)
		else:
			Game.play_sound_at_pos("drop", global_position)
		$Indicator.set_as_toplevel(true)
	else:
		set_process(false)

func _process(delta):
	N.clamp_node_to_screen($Indicator, global_position, 10, false)

func _physics_process(delta):
	velocity = velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
	position += velocity * delta

func enable_pickup():
	monitoring = true
	set_collision_mask_bit(G.LAYER_TEAM1, true)
	set_collision_mask_bit(G.LAYER_TEAM2, true)
	connect("body_entered", self, "pickup")
	
func score(hive):
	if dead: return
	dead = true
	Game.emit_signal("scored", hive.team, who)
	N.rpc_or_local(self, "remove", [])
	
func pickup(player):
	if dead or player.is_carrying(): return
	dead = true
	emit_signal("picked_up", self, player)
	N.rpc_or_local(self, "remove", [true])

func decay():
	dead = true
	emit_signal("picked_up", self, null)
	N.rpc_or_local(self, "remove", [])

remotesync func remove(picked_up = false):
	if not Game.is_server and picked_up:
		Game.play_sound_at_pos("pickup", global_position)
	queue_free()

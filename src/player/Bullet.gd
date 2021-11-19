extends Area2D

const DURATION = 0.5

var velocity := Vector2.ZERO
var team = 0
var duration = 0
var who = null
var dead = false

func init(data):
	name = "Bullet" + str(data.id)
	global_position = data.position
	velocity = data.vel
	rotation = velocity.angle()
	team = data.team
	who = data.who
	duration = DURATION
	if Game.is_host():
		set_collision_mask_bit(G.LAYER_TEAM1 if team == 2 else G.LAYER_TEAM2, true)
		connect("area_entered", self, "hit_area")
		connect("body_entered", self, "hit_body")
	if not Game.is_server:
		Game.play_sound_at_pos("shoot", global_position)

func _physics_process(delta):
	if dead: return
	position += velocity * delta
	duration -= delta
	if duration <= 0:
		remove()

func hit_area(area):
	pass
	
func hit_body(body):
	if dead: return
	if body.is_in_group("players"):
		body.hit(velocity)
		Game.emit_signal("bullet_hit", body, who)
	dead = true
	N.rpc_or_local(self, "remove", [])
		
remotesync func remove():
	queue_free()

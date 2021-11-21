extends Line2D

const SPEED = 400

var dead = false

func init(data):
	name = "Ladybug" + str(data.id)
	set_point_position(0, data.start)
	set_point_position(1, data.start)
	$Ladybug.position = data.start
	$Ladybug/Sprite.rotation = (data.end - data.start).angle()
	$Ladybug/Shadow.rotation = $Ladybug/Sprite.rotation
	var time = (data.end - data.start).length() / SPEED
	$Tween.interpolate_method(self, "update_point", data.start, data.end, 1.5)
	$Tween.interpolate_property($Ladybug, "position", data.start, data.end, time, Tween.TRANS_LINEAR, Tween.EASE_IN, 3)
	$Tween.start()
	
	if Game.is_host():
		$Tween.connect("tween_all_completed", self, "end", [], CONNECT_ONESHOT)
		$Ladybug.connect("body_entered", self, "caught")
	
func update_point(p):
	set_point_position(1, p)

func caught(body):
	if dead: return
	dead = true
	Game.emit_signal("scored", body.team, body.id, G.ObjectType.LADYBUG)
	N.rpc_or_local(self, "remove", [])

func end():
	if dead: return
	dead = true
	N.rpc_or_local(self, "remove", [])

remotesync func remove():
	if get_tree().get_rpc_sender_id() <= 1:
		if Game.is_server:
			queue_free()
		else:
			$Ladybug.queue_free()
			$Tween.remove_all()
			$Tween.interpolate_property(self, "modulate", Color.white, Color.transparent, 0.5)
			$Tween.start()
			$Tween.connect("tween_all_completed", self, "queue_free")

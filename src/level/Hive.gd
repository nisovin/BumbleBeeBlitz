extends Area2D

export (int) var team = 0

onready var indicator = $Indicator
onready var indicator_arrow = $IndicatorArrow

var hide_indicator = false

func _ready():
	if team == 2:
		$Sprite.texture = preload("res://level/hive2.png")
		indicator.texture = preload("res://level/hive_indicator2.png")
	indicator.hide()
	indicator_arrow.hide()
	indicator.set_as_toplevel(true)
	indicator_arrow.set_as_toplevel(true)

	add_to_group("hive" + str(team))

	if Game.is_host():
		connect("body_entered", self, "score")
	if Game.is_server:
		
		set_process(false)

func score(body):
	if body.is_in_group("players") and body.carrying == G.FlowerType.NORMAL and team == body.team:
		N.rpc_or_local(body, "set_carrying", [-1])
		Game.emit_signal("scored", body.team, body.id)

func _process(delta):
	if hide_indicator:
		indicator.hide()
		indicator_arrow.hide()
		return
	if Game.player != null and Game.player.team == team and Game.player.carrying == G.FlowerType.NORMAL:
		indicator_arrow.show()
		N.clamp_node_to_screen(indicator_arrow, global_position, 15, true)
	else:
		indicator_arrow.hide()
	N.clamp_node_to_screen(indicator, global_position, 15, false)

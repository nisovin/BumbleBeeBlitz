extends Node2D

onready var players_node = $Players
onready var flowers_node = $Flowers
onready var objects_node = $Objects

onready var match_gui = $MatchGUI
onready var hint_label = $CanvasLayer/Control/HintLabel

var game_timer = -100
var score = [0, 0, 0]

var collecting_normal = false
var collecting_weapon = false
var scoring = false
var shooting = false
	
func _ready():
	Game.level = self
	Game.connect("flower_collected", self, "flower_collected")
	Game.connect("nectar_passed", self, "nectar_passed")
	Game.connect("scored", self, "scored")
	Game.connect("bullet_fired", self, "bullet_fired")
	match_gui.chat_disabled = true
	match_gui.ability_label.hide()
	hint_label.modulate = Color.transparent
	$Hive1.hide_indicator = true
	start()

func show_hint(text):
	if hint_label.modulate != Color.transparent:
		$Tween.interpolate_property(hint_label, "modulate", hint_label.modulate, Color.transparent, 0.4)
	$Tween.interpolate_callback(hint_label, 0.45, "set_text", text)
	$Tween.interpolate_property(hint_label, "modulate", Color.transparent, Color.white, 1.5, Tween.TRANS_QUAD, Tween.EASE_OUT, 0.5)
	$Tween.start()

func flower_collected(flower, player):
	if collecting_normal:
		_on_normal_flower_collected()
	elif collecting_weapon:
		_on_weapon_collected()

func scored(team, who, type = G.FlowerType.NORMAL):
	if scoring:
		_on_score()

func nectar_passed(player, vel):
	var proj = Game.Nectar.instance()
	objects_node.add_child(proj)
	proj.init({
		"id": 1,
		"position": player.position,
		"vel": vel,
		"who": player.id
	})
	proj.connect("picked_up", self, "nectar_picked_up")
	
func nectar_picked_up(nectar, player):
	player.set_carrying(G.FlowerType.NORMAL)
	
func bullet_fired(player, vel):
	var proj = Game.Bullet.instance()
	objects_node.add_child(proj)
	proj.init({
		"id": 2,
		"position": player.position,
		"vel": vel,
		"team": player.team,
		"who": player.id
	})
	if shooting:
		_on_shoot()
	
func start():
	Game.player_id = 0
	var player = Game.Player.instance()
	players_node.add_child(player)
	player.init({
		"id": 0,
		"name": Game.player_name,
		"cpu": false,
		"team": 1,
		"position": $PlayerSpawn.global_position
	})
	Game.match_started = true
	show_hint("Move by holding left-click,\nor use the control stick.")

func _on_MovedDetect_body_entered(body):
	var flower = Game.Flower.instance()
	flowers_node.add_child(flower)
	flower.init({
		"id": 1,
		"type": G.FlowerType.NORMAL,
		"position": $FlowerSpawn.global_position
	})
	show_hint("Follow the indicator at the edge of\nthe screen to find the flower.")
	
func _on_FlowerSpawn_body_entered(body):
	collecting_normal = true
	show_hint("Hover over the flower to collect the nectar.")

func _on_normal_flower_collected():
	collecting_normal = false
	scoring = true
	match_gui.show_scores()
	$NearHive.connect("body_entered", self, "_on_NearHive_body_entered", [], CONNECT_ONESHOT)
	$Hive1.hide_indicator = false
	show_hint("Now carry the nectar back to your hive!\nFollow the indicator on the left")

func _on_NearHive_body_entered(body):
	match_gui.ability_label.show()
	show_hint("Hold right-click (or A on controller) to aim,\nthen throw the nectar into your hive!")

func _on_score():
	show_hint("SCORE! You've earned your team\n10 points!")
	score[1] = 10
	match_gui.update_scores()
	Game.play_sound("score")
	get_tree().create_timer(4, false).connect("timeout", self, "_on_timer1")
	
func _on_timer1():
	collecting_weapon = true
	var flower = Game.Flower.instance()
	flowers_node.add_child(flower)
	flower.init({
		"id": 1,
		"type": G.FlowerType.WEAPON,
		"position": $WeaponSpawn.global_position
	})
	show_hint("Now follow the new indicator\nto collect the next flower.")
	
func _on_weapon_collected():
	collecting_weapon = false
	shooting = true
	var player = Game.Player.instance()
	players_node.add_child(player)
	player.init({
		"id": 1,
		"name": "Zoop",
		"cpu": false,
		"team": 2,
		"position": $EnemySpawn.global_position
	})
	show_hint("You have a stink bomb! Seek out\nthe enemy team and shoot it at them!")

func _on_shoot():
	shooting = false
	show_hint("Stink bombs knock the enemy back\nand disorient them")
	get_tree().create_timer(4, false).connect("timeout", self, "_on_timer2")
	
func _on_timer2():
	show_hint("While not carrying anything, use your\nability button to speed boost.")
	get_tree().create_timer(10, false).connect("timeout", self, "_on_timer3")
	
func _on_timer3():
	show_hint("Your boost has a short cooldown.\nBumping an enemy will knock them back.")
	get_tree().create_timer(10, false).connect("timeout", self, "_on_timer4")

func _on_timer4():
	show_hint("That's it! You're ready to play!")
	get_tree().create_timer(7, false).connect("timeout", self, "_on_timer5")
	
func _on_timer5():
	queue_free()
	Game.start_menu()

extends CanvasLayer

onready var level = get_parent()
onready var team1score = find_node("Team1Score")
onready var team2score = find_node("Team2Score")
onready var clock = find_node("Clock")

onready var team1name = $Control/Team1Name
onready var team2name = $Control/Team2Name
onready var vs = $Control/Vs
onready var tween = $Tween
onready var chat_input = $Control/Chat/LineEdit
onready var chat_scroll = $Control/Chat/ScrollContainer
onready var chat_container = $Control/Chat/ScrollContainer/VBoxContainer
onready var chat_tween = $ChatTween
onready var ability_label = $Control/AbilityLabel
onready var ability_cd = $Control/AbilityLabel/Boost
onready var pause_menu = $Control/PauseMenu

var chatting = false
var chat_disabled = false

func _ready():
	Game.connect("chat_received", self, "add_chat_message")
	close_chat()
	pause_menu.hide()

func _input(event):
	if event.is_action_pressed("ui_accept") and not chatting and not chat_disabled:
		call_deferred("open_chat")

func _process(delta):
	if Game.player != null:
		if Game.player.carrying == G.FlowerType.NORMAL:
			ability_label.text = "PASS"
			ability_label.set("custom_colors/font_color", Color.lightyellow)
		elif Game.player.carrying == G.FlowerType.WEAPON:
			ability_label.text = "SHOOT"
			ability_label.set("custom_colors/font_color", Color.pink)
		else:
			ability_label.text = "BOOST"
			ability_label.set("custom_colors/font_color", Color.aquamarine)
			if Game.player.boost_cd > 0:
				ability_cd.show()
				ability_cd.value = Game.player.boost_cd / Game.player.BOOST_COOLDOWN
			else:
				ability_cd.hide()

func show_scores():
	team1score.show()
	team2score.show()

func update_scores():
	team1score.text = str(level.score[1])
	team2score.text = str(level.score[2])

func update_clock():
	var t = level.game_timer
	if t < 0:
		clock.text = str(-t)
		if t >= -3:
			Game.play_sound("tick")
	else:
		var s = ""
		var minutes = t / 60
		var seconds = t % 60
		s += str(minutes) + ":"
		if seconds < 10: s += "0"
		s += str(seconds)
		clock.text = s

func animate_teams(name1, name2):
	team1name.text = name1
	team2name.text = name2
	
	var start1 = team1name.rect_position
	var start2 = team2name.rect_position
	
	team1name.modulate = Color.transparent
	team2name.modulate = Color.transparent
	vs.modulate = Color.transparent
	team1name.show()
	team2name.show()
	vs.show()
	
	team1name.rect_position -= Vector2(350, 0)
	team2name.rect_position += Vector2(350, 0)
	
	tween.interpolate_property(team1name, "modulate", Color.transparent, Color.white, 1, Tween.TRANS_QUAD, Tween.EASE_OUT, 0)
	tween.interpolate_property(team1name, "rect_position", team1name.rect_position, start1, 1, Tween.TRANS_BOUNCE, Tween.EASE_OUT, 0)
	tween.interpolate_property(vs, "modulate", Color.transparent, Color.white, 1, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.5)
	tween.interpolate_property(vs, "rect_rotation", -1080, 0, 1, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.5)
	tween.interpolate_property(vs, "rect_scale", 0.5, 1.0, 1, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.5)
	tween.interpolate_property(team2name, "modulate", Color.transparent, Color.white, 1, Tween.TRANS_QUAD, Tween.EASE_OUT, 1)
	tween.interpolate_property(team2name, "rect_position", team2name.rect_position, start2, 1, Tween.TRANS_BOUNCE, Tween.EASE_OUT, 1)
	tween.interpolate_property(team1name, "modulate", Color.white, Color.transparent, 1, Tween.TRANS_QUAD, Tween.EASE_OUT, 4)
	tween.interpolate_property(team2name, "modulate", Color.white, Color.transparent, 1, Tween.TRANS_QUAD, Tween.EASE_OUT, 4)
	tween.interpolate_property(vs, "modulate", Color.white, Color.transparent, 1, Tween.TRANS_QUAD, Tween.EASE_OUT, 4)
	tween.interpolate_callback(Game, 0, "play_sound", "swish")
	tween.interpolate_callback(Game, 1, "play_sound", "swish")
	tween.interpolate_callback(Game, 5, "play_sound", "start")
	tween.start()

func add_chat_message(msg):
	var entry = Game.ChatEntry.instance()
	entry.parse_bbcode(msg)
	chat_container.add_child(entry)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	chat_scroll.scroll_vertical = chat_container.rect_size.y + 100
	if not chatting:
		chat_tween.interpolate_property(entry, "modulate", Color.white, Color.transparent, 2, Tween.TRANS_CUBIC, Tween.EASE_IN, 4)
		chat_tween.start()
	
func open_chat():
	chatting = true
	chat_tween.remove_all()
	chat_input.grab_focus()
	chat_input.modulate = Color.white
	chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_scroll.get_v_scrollbar().modulate = Color.white
	chat_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	for c in chat_container.get_children():
		c.modulate = Color.white

func close_chat():
	chat_input.modulate = Color.transparent
	chat_input.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_scroll.get_v_scrollbar().modulate = Color.transparent
	chat_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in chat_container.get_children():
		c.modulate = Color.transparent
	chatting = false

func send_message(new_text):
	if new_text != "":
		close_chat()
		Game.submit_message(new_text)
		chat_input.text = ""
	else:
		close_chat()

func _unhandled_key_input(event):
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			close_pause_menu()
		else:
			open_pause_menu()

func open_pause_menu():
	if not Game.online:
		get_tree().paused = true
	find_node("MusicVolume").value = Game.settings.vol_music
	find_node("AmbianceVolume").value = Game.settings.vol_ambient
	find_node("SFXVolume").value = Game.settings.vol_sfx
	pause_menu.show()
	
func close_pause_menu():
	if not Game.online:
		get_tree().paused = false
	pause_menu.hide()

func _on_ResumeButton_pressed():
	close_pause_menu()
	Game.save_settings()

func _on_LeaveGameButton_pressed():
	close_pause_menu()
	Game.save_settings()
	Game.start_menu()

func _on_MusicVolume_value_changed(value):
	Game.settings.vol_music = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(Game.settings.vol_music))

func _on_AmbianceVolume_value_changed(value):
	Game.settings.vol_ambient = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear2db(Game.settings.vol_ambient))

func _on_SFXVolume_value_changed(value):
	Game.settings.vol_sfx = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(Game.settings.vol_sfx))
	find_node("SFXTimer").start()

func _on_SFXTimer_timeout():
	Game.play_sound("shoot")

extends Node2D

const X_WAY = 16.0

onready var player = owner
onready var aim_arrow = player.get_node("AimArrow")
onready var aim_arrow_line = player.get_node("AimArrow/Line")
onready var aim_arrow_point = player.get_node("AimArrow/Point")

var using_controller = false
var device_id = 0
var last_move_angle = -1
var target = null
var last_aim_sent = 0
var screen_touch_dir = Vector2.ZERO
var screen_touch_status = 0
var screen_touch_last_press = 0
var screen_touch_last_release = 0

func enable():
	set_process(true)
	set_process_input(true)
	
func disable():
	set_process(false)
	set_process_input(false)

func _process(delta):
	var v = Vector2.ZERO
	if using_controller:
		v = get_controller_dir()
	elif Input.is_action_pressed("move"):
		target = get_global_mouse_position()
		v = player.position.direction_to(target)
	elif screen_touch_status > 0:
		v = screen_touch_dir
	else:
		v = Input.get_vector("left", "right", "up", "down")
		if v != Vector2.ZERO:
			v = v.normalized()
#		elif target != null:
#			if player.position.distance_squared_to(target) > 50*50:
#				v = player.position.direction_to(target)
#			else:
#				target = null
	
	var a = -1
	if v != Vector2.ZERO:
		a = wrapf(round(v.angle() / (2 * PI) * X_WAY), 0, X_WAY)
	if a != last_move_angle:
		last_move_angle = a
		if a == -1:
			update_movement(Vector2.ZERO)
		else:
			update_movement(Vector2.RIGHT.rotated(2 * PI / X_WAY * a))
			
	var arrow = player.get_shoot_arrow_data()
	if arrow.len > 0:
		aim_arrow.show()
		aim_arrow.rotation = arrow.rot
		aim_arrow_line.scale.x = arrow.len / 10.0
		if arrow.state == 0:
			aim_arrow_line.color = Color.firebrick
		elif arrow.state == 2:
			aim_arrow_line.color = Color.green
		else:
			aim_arrow_line.color = Color.dodgerblue
		aim_arrow_point.color = aim_arrow_line.color
		aim_arrow_point.position.x = arrow.len
	else:
		aim_arrow.hide()

func get_controller_dir():
	var x = Input.get_joy_axis(device_id, JOY_ANALOG_LX)
	var y = Input.get_joy_axis(device_id, JOY_ANALOG_LY)
	if abs(x) > 0.5 or abs(y) > 0.5:
		return Vector2(x, y).normalized()
	else:
		return Vector2.ZERO

func get_aim_dir():
	if using_controller:
		var v = get_controller_dir()
		if v == Vector2.ZERO:
			return player.facing
		else:
			return v
	elif screen_touch_status > 0:
		return screen_touch_dir
	else:
		return player.position.direction_to(get_global_mouse_position())

func _unhandled_input(event):
	if not using_controller:
		if event is InputEventJoypadButton or (event is InputEventJoypadMotion and event.axis_value > 0.5):
			using_controller = true
			device_id = event.device
	else:
		if event is InputEventKey or event is InputEventMouseButton:
			using_controller = false
			
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			screen_touch_dir = (event.position - (get_viewport().get_size_override() / 2)).normalized()
			if screen_touch_last_press > OS.get_ticks_msec() - 500 and screen_touch_last_release > OS.get_ticks_msec() - 500:
				screen_touch_status = 2
				screen_touch_last_press = 0
				screen_touch_last_release = 0
				start_ability(screen_touch_dir)
			else:
				screen_touch_status = 1
				screen_touch_last_press = OS.get_ticks_msec()
		else:
			if screen_touch_status == 2:
				activate_ability(screen_touch_dir)
				screen_touch_last_press = 0
				screen_touch_last_release = 0
			else:
				screen_touch_last_release = OS.get_ticks_msec()
			screen_touch_status = 0
	elif event is InputEventScreenDrag and event.index == 0:
		screen_touch_dir = (event.position - (get_viewport().get_size_override() / 2)).normalized()
		if screen_touch_status == 2:
			update_ability_aim(screen_touch_dir)
			
	if event.is_action_pressed("ability"):
		start_ability(get_aim_dir())
	elif event.is_action_released("ability"):
		activate_ability(get_aim_dir())
	elif event.is_action_pressed("move"):
		if player.shoot_start_time > 0:
			cancel_ability()
	elif player.shoot_start_time > 0 and last_aim_sent < OS.get_ticks_msec() - 80 and screen_touch_status == 0:
		if event is InputEventJoypadMotion or event is InputEventMouseMotion:
			update_ability_aim(get_aim_dir())
			
		
func start_ability(dir):
	if player.carrying >= 0 or player.can_boost():
		N.rpc_or_local(player, "shoot_start", [dir])
		last_aim_sent = OS.get_ticks_msec()
		last_move_angle = -1

func update_ability_aim(dir):
	N.rpc_or_local(player, "shoot_aim", [dir])
	last_aim_sent = OS.get_ticks_msec()

func activate_ability(dir):
	N.rpc_or_local(player, "shoot", [dir])

func cancel_ability():
	N.rpc_or_local(player, "shoot_cancel", [])

func update_movement(dir):
	N.rpc_or_local(player, "update_movement", [dir])

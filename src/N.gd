extends Node

enum objects { EMPTY = -1 }

func rpc_id_or_local(id: int, node: Node, fn: String, params: Array):
	if typeof(params) != TYPE_ARRAY:
		params = [params]
	if Game.online:
		node.callv("rpc_id", [id, fn] + params)
	else:
		node.callv(fn, params)

func rpc_or_local(node: Node, fn: String, params: Array):
	if typeof(params) != TYPE_ARRAY:
		params = [params]
	if Game.online:
		node.callv("rpc", [fn] + params)
	else:
		node.callv(fn, params)

func clamp_point_to_rect(center: Vector2, extents: Vector2, point: Vector2):
	var normal = (point - center).normalized()
	if abs(normal.x) > abs(extents.normalized().x):
		return center + normal * (extents.x / abs(normal.x))
	else:
		return center + normal * (extents.y / abs(normal.y))

func clamp_node_to_screen(node: Node2D, actual_position: Vector2, margin: int = 10, rotate = false):
	var extents = node.get_viewport().get_size_override() / 2
	var center = -node.get_canvas_transform().origin + extents
	extents -= Vector2(margin, margin)
	if (Rect2(center - extents, extents * 2).has_point(actual_position)):
		node.hide()
	else:
		node.show()
		var clamped = clamp_point_to_rect(center, extents, actual_position)
		node.global_position = clamped
		if rotate:
			node.global_rotation = (clamped - center).angle()
	
func rand_array(array):
	return array[randi() % array.size()]

func rand_weighted(options):
	var total_weight = 0
	for option in options:
		total_weight += options[option]
	var rand = randf() * total_weight
	for option in options:
		rand -= options[option]
		if rand < 0:
			return option
	return options.keys()[0]

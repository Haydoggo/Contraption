extends Node2D

var snap_dist = 16
var vertices := []
var parts := []

var running = false
var _start_vert : Vert = null

class Part:
	pass

class Stick:
	extends Part
	var vert_1 : Vert
	var vert_2 : Vert

class Vert:
	var pos := Vector2(0,0)
	var parts := []

func _process(_delta):
	update()

func get_nearest_vertex(pos : Vector2) -> Vert: 
	for vertex in vertices:
		if (vertex.pos as Vector2).distance_to(pos) < 16:
			return vertex
	return null

func _input(event):
	if event.is_action_pressed("build"):
		_start_vert = get_nearest_vertex(get_global_mouse_position())
		if _start_vert == null:
			_start_vert = Vert.new()
			_start_vert.pos = get_global_mouse_position()
			vertices.append(_start_vert)
	
	if event.is_action_released("build"):
		var _end_vert = get_nearest_vertex(get_global_mouse_position())
		if _end_vert == null:
			_end_vert = Vert.new()
			_end_vert.pos = get_global_mouse_position()
			vertices.append(_end_vert)
		var stick := Stick.new()
		stick.vert_1 = _start_vert
		stick.vert_2 = _end_vert
		_start_vert.parts.append(stick)
		_end_vert.parts.append(stick)
		parts.append(stick)
	
	if event.is_action_pressed("ui_accept"):
		running = !running
		start() if running else stop()

func start():
	print("start")
	
	var part_to_body := {}
	
	for part in parts:
		var stick_body = preload("res://Stick.tscn").instance()
		stick_body.position = 0.5*(part.vert_1.pos + part.vert_2.pos)
		stick_body.rotation = (part.vert_2.pos - part.vert_1.pos).angle()
		stick_body.get_node("CollisionShape2D").shape.extents.x = (part.vert_2.pos - part.vert_1.pos).length()*0.5
		stick_body.mass = max((part.vert_2.pos - part.vert_1.pos).length(), 1) / 100
		add_child(stick_body)
		part_to_body[part] = stick_body
	
	for vertex in vertices:
		vertex = vertex as Vert
		for i in vertex.parts.size():
			var part_1 = vertex.parts[i]
			var part_2 = vertex.parts[i-1]
			if part_1 == part_2:
				break
			var j = PinJoint2D.new()
			part_to_body[part_1].add_child(j)
			j.global_position = vertex.pos
			j.node_a = part_to_body[part_1].get_path()
			j.node_b = part_to_body[part_2].get_path()
			j.softness = 0.1

func stop():
	print("stop")
	for part in get_tree().get_nodes_in_group("Parts"):
		part.free()

func _draw():
	if running: return
	for part in parts:
		draw_line(part.vert_1.pos, part.vert_2.pos, Color.cornflower, 4)
	for vert in vertices:
		draw_circle(vert.pos, 4, Color.white)
		
	if Input.is_action_pressed("build"):
		var nearest_vert = get_nearest_vertex(get_global_mouse_position())
		var mpos = get_global_mouse_position()
		if nearest_vert != null and nearest_vert != _start_vert:
			mpos = nearest_vert.pos
		draw_line(_start_vert.pos, mpos, Color( 0.39, 0.58, 0.93, 0.2), 4)

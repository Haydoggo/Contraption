extends Node2D

var sticks = []
var playing = false
var stick_start = Vector2()

class Stick:
	var start := Vector2()
	var end := Vector2()

func _process(_delta):
	update()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		playing = not playing
		if playing:
			start()
		else:
			clear()
	if event.is_action_pressed("ui_cancel"):
		sticks.clear()
	var mpos = get_global_mouse_position()
	if event is InputEventMouseButton:
		if event.pressed:
			stick_start = mpos
		else:
			var stick = Stick.new()
			stick.start = stick_start
			stick.end = mpos
			sticks.append(stick)

func clear():
	for stick_body in get_tree().get_nodes_in_group("Sticks"):
		stick_body.free()

func start():
	var vertices := []
	var vertex_sticks := {}
	for stick in sticks:
		for pos in [stick.end, stick.start]:
			var no_near_vertices = true
			for vertex in vertices:
				if (pos - vertex).length() < 16:
					no_near_vertices = false
					break
			if no_near_vertices:
				vertices.append(pos)
				vertex_sticks[pos] = []
	
	for vertex in vertices:
		for stick in sticks:
			for pos in [stick.end, stick.start]:
				if (pos - vertex).length() < 16:
					vertex_sticks[vertex].append([stick, pos])
	
	var foo := {}
	
	for stick in sticks:
		var stick_body = preload("res://Stick.tscn").instance()
		stick_body.position = 0.5*(stick.start + stick.end)
		stick_body.rotation = (stick.end - stick.start).angle()
		stick_body.get_node("CollisionShape2D").shape.extents.x = (stick.end - stick.start).length()*0.5
		stick_body.mass = max((stick.end - stick.start).length(), 1) / 100
		add_child(stick_body)
		foo[stick] = stick_body
	
	for vertex in vertices:
		for i in range(1, vertex_sticks[vertex].size()):
			var s = vertex_sticks[vertex][i]
			var j = PinJoint2D.new()
			j.softness = 0.1
			foo[s[0]].add_child(j)
			j.global_position = s[1]
			j.node_a = foo[s[0]].get_path()
			j.node_b = foo[vertex_sticks[vertex][i-1][0]].get_path()

func _draw():
	if not playing:
		for stick in sticks:
			draw_line(stick.start, stick.end, Color.cornflower, 4)
		if Input.get_mouse_button_mask() & BUTTON_MASK_LEFT:
			draw_line(stick_start, get_global_mouse_position(), Color.cornflower, 4)

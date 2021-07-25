extends Node2D

enum PartType {
	STICK_WATER,
	STICK_SOLID,
	WHEEL,
	WHEEL_JOINER,
	CHAIN,
}

var snap_dist = 8
var vertices := []
var parts := []
var part_to_body := {}
var part_type setget _set_part_type
var running = false
var _start_vert : Vert = null
var _start_wheel : Wheel = null

class Part:
	var verts := []
	func get_vert(index : int) -> Vert:
		return verts[index]

class Stick:
	extends Part
	enum VertName {
		START,
		END,
	}
	var solid = false
	
	func _init():
		for i in VertName:
			verts.append(null)

class Wheel:
	extends Part
	var radius = 20
	enum VertName {
		CENTER,
		RIGHT,
		TOP,
		LEFT,
		BOTTOM,
	}
	
	func _init():
		for i in VertName:
			verts.append(null)
	
	func add_verts() -> Array:
		var center_vert := get_vert(VertName.CENTER)
		var new_verts := []
		for i in range(1, VertName.size()):
			var vert = Vert.new()
			vert.pos = center_vert.pos + Vector2(radius, 0).rotated(PI/2 * i)
			vert.parts.append(self)
			verts[i] = vert
			new_verts.append(vert)
		return new_verts

class Vert:
	var pos := Vector2(0,0)
	var parts := []

func _ready():
	_set_part_type(PartType.STICK_WATER)

func _set_part_type(val):
	part_type = val
	$Control/VBoxContainer/Label.text = str(PartType.keys()[part_type])

func _process(_delta):
	update()

func get_nearest_vertex(pos : Vector2) -> Vert: 
	for vertex in vertices:
		if (vertex.pos as Vector2).distance_to(pos) <= snap_dist:
			return vertex
	return null

func _input(event):
	
	if event.is_action_pressed("build"):
		start_build(get_global_mouse_position())
	
	if event.is_action_released("build"):
		end_build(get_global_mouse_position())
	
	if event.is_action_pressed("ui_focus_next"):
		_set_part_type((part_type + 1) % PartType.size())
	
	if event is InputEventMouseMotion and Input.is_action_pressed("pan"):
		$Camera2D.position -= event.relative * $Camera2D.zoom.x
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_WHEEL_UP:
			$Camera2D.zoom /= 1.1
		if event.button_index == BUTTON_WHEEL_DOWN:
			$Camera2D.zoom *= 1.1

func start_build(mpos : Vector2):
	match part_type:
		PartType.STICK_WATER, PartType.STICK_SOLID, PartType.CHAIN:
			_start_vert = get_nearest_vertex(mpos)
			if _start_vert == null:
				_start_vert = Vert.new()
				_start_vert.pos = mpos
				vertices.append(_start_vert)
		
		PartType.WHEEL_JOINER:
			_start_wheel = null
			var vert = get_nearest_vertex(mpos)
			if vert != null :
				for part in vert.parts:
					if not part is Wheel: continue
					var wheel : Wheel = part
					if wheel.get_vert(wheel.VertName.CENTER) == vert:
						_start_wheel = wheel
						_start_vert = vert
						break

func end_build(mpos : Vector2):
	match part_type:
		PartType.STICK_WATER, PartType.STICK_SOLID:
			var _end_vert = get_nearest_vertex(mpos)
			if _end_vert == null:
				_end_vert = Vert.new()
				_end_vert.pos = mpos
				vertices.append(_end_vert)
			# Check the two vertices are not already connected
			for part in _end_vert.parts:
				if not part is Stick: continue	 
				for vert in part.verts:
					if vert == _start_vert:
						return
			var stick := Stick.new()
			stick.solid = part_type == PartType.STICK_SOLID
			stick.verts[stick.VertName.START] = _start_vert
			stick.verts[stick.VertName.END] = _end_vert
			_start_vert.parts.append(stick)
			_end_vert.parts.append(stick)
			parts.append(stick)
			
		PartType.WHEEL:
			var _end_vert = get_nearest_vertex(mpos)
			if _end_vert == null:
				_end_vert = Vert.new()
				_end_vert.pos = mpos
				vertices.append(_end_vert)
			var wheel := Wheel.new()
			wheel.verts[wheel.VertName.CENTER] = _end_vert
			_end_vert.parts.append(wheel)
			vertices.append_array(wheel.add_verts())
			parts.append(wheel)
		
		PartType.WHEEL_JOINER:
			var _end_wheel = null
			var vert = get_nearest_vertex(mpos)
			if vert != null:
				for part in vert.parts:
					if not part is Wheel : continue
					var wheel : Wheel = part
					if wheel == _start_wheel : return
					if wheel.get_vert(wheel.VertName.CENTER) == vert:
						_end_wheel = wheel
						break
			if _end_wheel != null:
				part_type = PartType.STICK_WATER
				for i in range(5):
					start_build(_start_wheel.get_vert(i).pos)
					end_build(_end_wheel.get_vert(i).pos)
				part_type = PartType.WHEEL_JOINER
		
		PartType.CHAIN:
			var start = _start_vert.pos
			var end = mpos
			var diff = end - start
			var num_segments = ceil(diff.length()/16)
			part_type = PartType.STICK_SOLID
			var old_snap_dist = snap_dist
			snap_dist = 0
			for i in range(num_segments):
				start_build(lerp(start, end, i/num_segments))
				if i == num_segments-1:
					snap_dist = old_snap_dist
				end_build(lerp(start, end, (i+1)/num_segments))
			part_type = PartType.CHAIN

func construct_part(part : Part) -> RigidBody2D:
	if part is Stick:
		var stick_body
		if part.solid:
			stick_body = preload("res://StickSolid.tscn").instance()
		else:
			stick_body = preload("res://Stick.tscn").instance()
		var start_vert := part.get_vert(part.VertName.START)
		var end_vert := part.get_vert(part.VertName.END)
		
		stick_body.position = 0.5*(start_vert.pos + end_vert.pos)
		stick_body.rotation = (end_vert.pos - start_vert.pos).angle()
		stick_body.get_node("CollisionShape2D").shape.extents.x = (end_vert.pos - start_vert.pos).length()*0.5
		stick_body.mass = max((end_vert.pos - start_vert.pos).length(), 1) / 100
		return stick_body
		
	if part is Wheel:
		var wheel_body = preload("res://Wheel.tscn").instance()
		var center_vert := part.get_vert(part.VertName.CENTER)
		wheel_body.position = center_vert.pos
		return wheel_body
		
	return null

func start():
	print("start")
	
	for part in parts:
		var body = construct_part(part)
		add_child(body)
		part_to_body[part] = body
	
	for part in parts:
		if part is Wheel:
			var center_vert = part.get_vert(part.VertName.CENTER)
			for connected_part in center_vert.parts:
				if connected_part != part:
					part_to_body[part].motorised_body = part_to_body[connected_part]
					break
	
	for vertex in vertices:
		vertex = vertex as Vert
		var num_joints = vertex.parts.size()
		if num_joints <= 2: num_joints -= 1
		for i in num_joints:
			var part_1 = vertex.parts[i]
			var part_2 = vertex.parts[i-1]
			if part_1 == part_2:
				break
			var j = PinJoint2D.new()
			j.disable_collision = false
			part_to_body[part_1].add_child(j)
			j.global_position = vertex.pos
			j.node_a = part_to_body[part_1].get_path()
			j.node_b = part_to_body[part_2].get_path()
			j.softness = 0.5
			
			for part in vertex.parts:
				if part == part_1: continue
				(part_to_body[part_1] as RigidBody2D).add_collision_exception_with(part_to_body[part])

func stop():
	print("stop")
	part_to_body.clear()
	for part in get_tree().get_nodes_in_group("Parts"):
		part.free()

func _draw():
	if running: return
	for part in parts:
		if part is Stick:
			draw_line(part.get_vert(part.VertName.START).pos, 
					part.get_vert(part.VertName.END).pos,
					Color.sienna if part.solid else Color.cornflower, 4)
		if part is Wheel:
			draw_circle(part.get_vert(part.VertName.CENTER).pos,
					part.radius, Color.coral)

	for vert in vertices:
		draw_circle(vert.pos, 4, Color.white)
		
	if Input.is_action_pressed("build"):
		var nearest_vert := get_nearest_vertex(get_global_mouse_position())
		var mpos := get_global_mouse_position()
		if nearest_vert != null:
			mpos = nearest_vert.pos
		match part_type:
			PartType.STICK_WATER:
				draw_line(_start_vert.pos, mpos, Color( 0.39, 0.58, 0.93, 0.2), 4)
			PartType.STICK_SOLID:
				draw_line(_start_vert.pos, mpos, Color( 0.63, 0.32, 0.18, 0.2), 4)
			PartType.WHEEL:
				draw_circle(mpos, 20, Color( 1, 0.5, 0.31, 0.2))
			PartType.WHEEL_JOINER:
				if _start_wheel != null:
					draw_line(_start_vert.pos, mpos, Color( 0.63, 0.63, 0.63, 0.2), 8)

func _on_StartButton_pressed():
	running = !running
	start() if running else stop()
	$Control/VBoxContainer/StartButton.text = "Stop" if running else "Start"
	$Control/VBoxContainer/ResetButton.visible = not running

func _on_ResetButton_pressed():
	parts.clear()
	vertices.clear()

extends CollisionPolygon2D

func _ready():
	var poly = Polygon2D.new()
	poly.polygon = polygon
	add_child(poly)

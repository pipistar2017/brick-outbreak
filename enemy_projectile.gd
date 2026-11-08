extends Node3D
## Geometry only; flight and collision are owned by the paused battle simulation.
const Parts = preload("res://hero_model.gd")
var form := ""

func block(pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.mesh = Parts.beveled(size)
	node.position = pos
	node.material_override = Parts.mat(color)
	add_child(node)

func bun(y: float, radius: float, height: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius*0.85
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	node.mesh = shape
	node.position.y = y
	node.material_override = Parts.mat(color)
	add_child(node)

func build(kind: String) -> void:
	form = kind
	if kind=="arrow":
		block(Vector3.ZERO,Vector3(0.07,0.07,0.95),Color("d0b37c"))
		block(Vector3(0,0,-0.5),Vector3(0.19,0.1,0.23),Color("dce1da"))
		for side in [-1,1]:
			block(Vector3(side*0.10,0,0.32),Vector3(0.16,0.04,0.24),Color("dfd3b3"))
	elif kind=="snake":
		for i in range(7):
			block(Vector3(sin(i*0.8)*0.08,0,i*0.12),Vector3(0.16,0.14,0.19),Color("36cf65"))
		block(Vector3(0,0,-0.13),Vector3(0.27,0.18,0.3),Color("76ee75"))
		for side in [-1,1]:
			block(Vector3(side*0.085,0.05,-0.27),Vector3(0.04,0.04,0.025),Color("fff56a"))
	elif kind=="catapult":
		# A stone hamburger silhouette: two rounded buns, patty, cheese and lettuce.
		bun(-0.20,0.45,0.18,Color("c49967"))
		bun(0,0.46,0.18,Color("615247"))
		block(Vector3(0,0.12,0),Vector3(0.83,0.07,0.83),Color("b3a264"))
		bun(0.20,0.47,0.12,Color("7b8664"))
		bun(0.37,0.46,0.26,Color("c9a575"))
		for i in range(7):
			var a := i*2.39996
			block(Vector3(sin(a)*0.3,0.515,cos(a)*0.3),Vector3(0.045,0.025,0.10),Color("eee1bf"))
	else:
		var node := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.26
		shape.height = 0.52
		node.mesh = shape
		node.material_override = Parts.mat(Color("ff752e"),false,true)
		add_child(node)

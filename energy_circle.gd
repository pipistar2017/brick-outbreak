extends Node3D
## Brick-built ritual platform inspired by the supplied multi-view photographs.
const Brick = preload("res://hero_model.gd")
const COLORS = [Color("36ed83"), Color("ffdc45"), Color("ff4a53")]
const HEALTH = [1000.0, 1500.0, 2000.0]
var tint: Color
var crown: Node3D
var health: Label3D
var bar: MeshInstance3D
var age := 0.0
var landed := false
var landing := false
var parts := 0

func piece(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = Brick.mat(color, false, glow)
	parent.add_child(node)
	parts += 1
	return node

func block(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return piece(parent, Brick.beveled(size), pos, color)

func disc(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, glow := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	return piece(parent, mesh, pos, color, glow)

func ring(parent: Node3D, y: float, inner: float, outer: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 8
	piece(parent, mesh, Vector3(0,y,0), color, true)

func build(stage: int) -> void:
	tint = COLORS[stage]
	var pale := Color("e8e3cf")
	var armor := tint.darkened(0.45)
	var trim := tint.lightened(0.45)
	position.y = 5.0
	disc(self, Vector3(0,0.38,0), 2.15, 0.5, pale)
	disc(self, Vector3(0,0.69,0), 2.2, 0.16, armor)
	disc(self, Vector3(0,0.8,0), 1.4, 0.1, tint.darkened(0.7))
	ring(self,0.83,1.55,1.78,pale)
	ring(self,0.87,1.25,1.32,tint)
	for i in range(24):
		var a := i*TAU/24
		var radial := Vector3(sin(a),0,cos(a))
		disc(self,radial*1.99+Vector3(0,0.83,0),0.105,0.12,armor)
		if i%3==0:
			var seam := block(self,radial*2.11+Vector3(0,0.37,0),Vector3(0.035,0.40,0.08),armor)
			seam.rotation.y = a
	for i in range(4):
		var a := i*PI/2
		var radial := Vector3(sin(a),0,cos(a))
		disc(self,radial*1.55+Vector3(0,0.1,0),0.19,0.2,armor)
		var plate := block(self,radial*1.25+Vector3(0,0.93,0),Vector3(0.72,0.14,0.66),trim)
		plate.rotation.y = a
		var orb := SphereMesh.new()
		orb.radius = 0.23
		orb.height = 0.46
		piece(self,orb,radial*1.96+Vector3(0,1.14,0),tint,true)
		block(self,radial*1.96+Vector3(0,0.94,0),Vector3(0.5,0.16,0.42),armor)
		disc(self,radial*0.77+Vector3(0,0.96,0),0.36,0.14,trim)
		# Four curved energy claws anchored to the rim.
		for j in range(8 if i==0 else 3):
			var p := radial*(2.03+j*0.16)+Vector3(0,1.05-j*j*0.018,0)
			var next := radial*(2.03+(j+1)*0.16)+Vector3(0,1.05-(j+1)*(j+1)*0.018,0)
			var claw := block(self,(p+next)*0.5,Vector3(0.18-j*0.016,0.12,p.distance_to(next)+0.06),tint)
			claw.basis = Basis.looking_at(next-p)
	ring(self,1.05,0.49,0.64,trim)
	disc(self,Vector3(0,1.35,0),0.1,0.7,armor)
	crown = Node3D.new()
	add_child(crown)
	crown.position.y = 1.85
	disc(crown,Vector3.ZERO,0.56,0.2,armor)
	ring(crown,0,0.53,0.64,trim)
	for i in range(6):
		var a := i*TAU/6
		var radial := Vector3(sin(a),0,cos(a))
		var petal := block(crown,radial*0.62+Vector3(0,0.24,0),Vector3(0.36,0.72,0.17),trim)
		petal.rotation = Vector3(-0.55,a,0)
		# Hollow square sockets echo the reference's raised central assembly.
		var socket := Node3D.new()
		crown.add_child(socket)
		socket.position = radial*0.65+Vector3(0,0.38,0)
		socket.rotation.y = a
		for x in [-1,1]:
			block(socket,Vector3(x*0.17,0,0.08),Vector3(0.07,0.4,0.16),armor)
			block(socket,Vector3(0,x*0.17,0.08),Vector3(0.4,0.07,0.16),armor)
	var core := SphereMesh.new()
	core.radius = 0.3
	core.height = 0.6
	piece(crown,core,Vector3(0,0.25,0),tint,true)
	health = Label3D.new()
	health.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health.no_depth_test = true
	health.font_size = 40
	health.pixel_size = 0.007
	health.position.y = 3.85
	add_child(health)
	var background := QuadMesh.new()
	background.size = Vector2(2.8,0.16)
	var back := piece(self,background,Vector3(0,3.08,0),Color("18202b"))
	back.material_override = Brick.mat(Color("18202b")).duplicate()
	back.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	back.material_override.no_depth_test = true
	bar = piece(self,background,Vector3(0,3.08,0.01),tint,true)
	bar.material_override = Brick.mat(tint,false,true).duplicate()
	bar.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar.material_override.no_depth_test = true
	set_health(HEALTH[stage],HEALTH[stage])

func set_health(value: float, maximum: float) -> void:
	bar.scale.x = maxf(value/maximum,0.001)
	health.text = "能量法阵  %d / %d\n%s" % [ceili(value),int(maximum),"可攻击 · 技能伤害减半" if landed else "击败十名敌人使法阵落地"]
	health.modulate = tint.lightened(0.4)

func animate(delta: float, kills: int) -> void:
	age += delta
	crown.rotation.y += delta*0.45
	if kills>=10: landing = true
	if landing:
		position.y = move_toward(position.y,0,delta*2.5)
		landed = position.y<=0.001
	else:
		position.y = 5.0+sin(age*1.5)*0.22

extends Node3D
## Original articulated brick warriors. Front faces -Z; all details are real 3D geometry.
## Shared beveled meshes/materials keep draw and memory costs predictable.

const PALETTES = [
	{"armor":Color("165c40"),"trim":Color("d9ad49"),"edge":Color("ffe29a"),"energy":Color("36e99a"),"cape":Color("a82f36"),"dark":Color("102d26")},
	{"armor":Color("872c28"),"trim":Color("dba44b"),"edge":Color("ffe1a0"),"energy":Color("ff813b"),"cape":Color("482633"),"dark":Color("30232d")},
	{"armor":Color("284d7c"),"trim":Color("b5cbdc"),"edge":Color("ecfaff"),"energy":Color("64e2ff"),"cape":Color("342c62"),"dark":Color("1b2542")}
]
static var materials: Dictionary = {}
static var meshes: Dictionary = {}
var identity := 0
var rig: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var cape: Node3D
var weapon: Node3D
var walk_phase := 0.0
var attack_time := 0.0
var skill_time := 0.0
var p: Dictionary
var decorative_parts := 0

static func mat(color: Color, metal := false, glow := false) -> StandardMaterial3D:
	var key := str(color)+str(metal)+str(glow)
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.42 if metal else 0.04
	m.roughness = 0.40 if metal else 0.48
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.65
	materials[key] = m
	return m

static func beveled(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if meshes.has(key):
		return meshes[key]
	var b := minf(minf(size.x,size.y),size.z)*0.16
	var x := size.x*0.5
	var y := size.y*0.5
	var z := size.z*0.5
	var points: Array[Vector3] = []
	for layer in range(4):
		var cut := b if layer==0 or layer==3 else 0.0
		var xx := x-cut
		var zz := z-cut
		var yy := [-y,-y+b,y-b,y][layer] as float
		var c := minf(b,minf(xx,zz)*0.45)
		for point in [Vector2(-xx+c,-zz),Vector2(xx-c,-zz),Vector2(xx,-zz+c),Vector2(xx,zz-c),Vector2(xx-c,zz),Vector2(-xx+c,zz),Vector2(-xx,zz-c),Vector2(-xx,-zz+c)]:
			points.append(Vector3(point.x,yy,point.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(3):
		for i in range(8):
			var a := layer*8+i
			var next := layer*8+(i+1)%8
			for v in [points[a],points[next],points[a+8],points[next],points[next+8],points[a+8]]:
				st.add_vertex(v)
	for i in range(1,7):
		for v in [points[0],points[i+1],points[i],points[24],points[24+i],points[24+i+1]]:
			st.add_vertex(v)
	st.generate_normals()
	var result := st.commit()
	meshes[key] = result
	return result

func piece(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metal := false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = beveled(size)
	n.material_override = mat(color,metal)
	n.position = pos
	parent.add_child(n)
	decorative_parts += 1
	return n

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, metal := false, top := -1.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var key := "cyl%s/%s/%s" % [radius,height,top]
	if not meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = radius if top<0 else top
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = 12
		meshes[key] = m
	n.mesh = meshes[key]
	n.material_override = mat(color,metal)
	n.position = pos
	parent.add_child(n)
	decorative_parts += 1
	return n

func gem(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	var n := MeshInstance3D.new()
	n.mesh = m
	n.position = pos
	n.material_override = mat(color,false,true)
	parent.add_child(n)
	decorative_parts += 1
	return n

func pivot(parent: Node3D, pos: Vector3, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = pos
	parent.add_child(node)
	return node

func build(index: int) -> void:
	identity = index
	p = PALETTES[index]
	name = ["JadeGeneral","EmberRanger","FrostOracle"][index]
	rig = pivot(self,Vector3.ZERO,"ArticulatedRig")
	# Broad chest, short limbs and oversized cylindrical stud head: brick toy proportions.
	piece(rig,Vector3(0,1.25,0),Vector3(0.85,0.72,0.5),p.armor)
	piece(rig,Vector3(0,0.87,0),Vector3(0.88,0.16,0.55),p.dark)
	piece(rig,Vector3(0,0.91,-0.30),Vector3(0.82,0.10,0.07),p.trim,true)
	var buckle := cylinder(rig,Vector3(0,0.91,-0.36),0.13,0.06,p.trim,true)
	buckle.rotation.x = PI/2
	gem(rig,Vector3(0,0.91,-0.41),Vector3(0.12,0.15,0.05),p.energy)
	for side in [-1,1]:
		var plate := piece(rig,Vector3(side*0.22,1.32,-0.29),Vector3(0.34,0.48,0.10),p.trim,true)
		plate.rotation.z = side*0.12
		piece(rig,Vector3(side*0.22,1.32,-0.35),Vector3(0.24,0.35,0.035),p.armor,true)
		for row in range(3):
			piece(rig,Vector3(side*0.22,1.20+row*0.10,-0.38),Vector3(0.20,0.025,0.025),p.edge,true)
		var skirt := piece(rig,Vector3(side*0.32,0.72,-0.08),Vector3(0.28,0.38,0.49),p.trim,true)
		skirt.rotation.z = side*0.12
		piece(rig,Vector3(side*0.32,0.73,-0.35),Vector3(0.19,0.25,0.04),p.armor)
	var seal := cylinder(rig,Vector3(0,1.43,-0.36),0.18,0.07,p.trim,true)
	seal.rotation.x = PI/2
	gem(rig,Vector3(0,1.44,-0.43),Vector3(0.18,0.22,0.08),p.energy)
	leg_l = build_leg(-1)
	leg_r = build_leg(1)
	arm_l = build_arm(-1)
	arm_r = build_arm(1)
	build_head()
	build_cape()
	weapon = pivot(arm_r,Vector3(0,-0.55,-0.12),"SignatureWeapon")
	if identity==0:
		build_glaive()
	elif identity==1:
		build_crossbow()
	else:
		build_staff()

func build_leg(side: int) -> Node3D:
	var node := pivot(rig,Vector3(side*0.23,0.77,0),"LeftHip" if side<0 else "RightHip")
	var joint := cylinder(node,Vector3.ZERO,0.17,0.34,p.dark)
	joint.rotation.z = PI/2
	piece(node,Vector3(0,-0.27,0),Vector3(0.34,0.47,0.35),p.armor)
	piece(node,Vector3(0,-0.24,-0.2),Vector3(0.29,0.22,0.08),p.trim,true)
	gem(node,Vector3(0,-0.24,-0.26),Vector3(0.16,0.16,0.05),p.energy)
	piece(node,Vector3(0,-0.53,-0.09),Vector3(0.39,0.24,0.53),p.dark)
	piece(node,Vector3(0,-0.45,-0.23),Vector3(0.30,0.12,0.16),p.trim,true)
	return node

func build_arm(side: int) -> Node3D:
	var node := pivot(rig,Vector3(side*0.58,1.49,0),"LeftShoulder" if side<0 else "RightShoulder")
	var joint := cylinder(node,Vector3.ZERO,0.19,0.3,p.dark)
	joint.rotation.z = PI/2
	piece(node,Vector3(0,-0.17,0),Vector3(0.28,0.40,0.32),p.armor)
	var shoulder := piece(node,Vector3(side*0.04,0.04,0),Vector3(0.46,0.20,0.52),p.trim,true)
	shoulder.rotation.z = -side*0.18
	piece(node,Vector3(side*0.11,-0.01,-0.04),Vector3(0.25,0.12,0.37),p.armor,true)
	# Stylized dragon shoulder: snout, brow and gold eye studs.
	piece(node,Vector3(side*0.08,0.04,-0.30),Vector3(0.28,0.13,0.15),p.armor,true)
	piece(node,Vector3(side*0.08,0.12,-0.32),Vector3(0.30,0.045,0.12),p.trim,true)
	for eye in [-1,1]:
		piece(node,Vector3(side*0.08+eye*0.075,0.07,-0.386),Vector3(0.035,0.035,0.025),p.edge)
	for i in range(2):
		var scale_piece := gem(node,Vector3(side*(0.15+i*0.10),0.15+i*0.07,0.03),Vector3(0.20,0.24,0.24),p.energy)
		scale_piece.rotation.z = -side*0.6
	piece(node,Vector3(0,-0.38,0),Vector3(0.33,0.19,0.37),p.trim,true)
	piece(node,Vector3(0,-0.38,-0.21),Vector3(0.20,0.10,0.07),p.dark)
	var hand := cylinder(node,Vector3(0,-0.57,-0.01),0.14,0.16,Color("d7aa72"))
	hand.rotation.x = PI/2
	var grip := cylinder(node,Vector3(0,-0.57,-0.11),0.085,0.025,p.dark)
	grip.rotation.x = PI/2
	return node

func build_head() -> void:
	var head := pivot(rig,Vector3(0,1.99,0),"CrownedHead")
	cylinder(head,Vector3.ZERO,0.33,0.55,Color("bd8058") if identity==0 else Color("e7bb8a"))
	cylinder(head,Vector3(0,0.33,0),0.14,0.12,p.trim,true)
	# Eyes, eyebrows and nose are geometry, visible from the portrait camera.
	for side in [-1,1]:
		piece(head,Vector3(side*0.12,0.02,-0.315),Vector3(0.10,0.06,0.035),Color("121b23"))
		piece(head,Vector3(side*0.135,0.03,-0.337),Vector3(0.025,0.025,0.01),p.edge)
		var brow := piece(head,Vector3(side*0.12,0.10,-0.32),Vector3(0.16,0.045,0.035),p.dark)
		brow.rotation.z = side*0.22
	piece(head,Vector3(0,-0.035,-0.34),Vector3(0.07,0.10,0.07),Color("c99266"))
	if identity==0:
		var beard := pivot(head,Vector3(0,0,-0.41),"LongBlackBeard")
		blade(beard,PackedVector2Array([Vector2(-0.19,-0.10),Vector2(-0.20,-0.28),Vector2(-0.12,-0.50),Vector2(0,-0.61),Vector2(0.12,-0.50),Vector2(0.20,-0.28),Vector2(0.19,-0.10)]),0.10,Color("14221f"),false,false)
		for i in range(3):
			piece(beard,Vector3((i-1)*0.075,-0.30,-0.06),Vector3(0.025,0.32,0.02),Color("263b31"))
		for side in [-1,1]:
			var moustache := piece(head,Vector3(side*0.08,-0.12,-0.36),Vector3(0.17,0.065,0.07),p.dark)
			moustache.rotation.z = side*0.22
	else:
		piece(head,Vector3(0,-0.15,-0.31),Vector3(0.40,0.17,0.07),p.armor)
		for i in range(3):
			piece(head,Vector3((i-1)*0.09,-0.15,-0.355),Vector3(0.04,0.09,0.025),p.trim,true)
	# Faceted helmet dome, broad golden brow, curved cheek guards.
	cylinder(head,Vector3(0,0.22,0.025),0.385,0.27,p.armor,true,0.29)
	cylinder(head,Vector3(0,0.365,0.025),0.29,0.12,p.armor,true,0.16)
	piece(head,Vector3(0,-0.035,0.255),Vector3(0.62,0.43,0.22),p.armor,true)
	for i in range(3):
		piece(head,Vector3(0,-0.18+i*0.11,0.38),Vector3(0.53,0.035,0.03),p.trim,true)
	piece(head,Vector3(0,0.18,-0.345),Vector3(0.70,0.14,0.13),p.trim,true)
	for side in [-1,1]:
		var cheek := piece(head,Vector3(side*0.32,-0.035,-0.18),Vector3(0.12,0.42,0.29),p.trim,true)
		cheek.rotation.z = -side*0.17
		piece(head,Vector3(side*0.35,-0.04,-0.24),Vector3(0.06,0.24,0.12),p.armor,true)
		var wing := piece(head,Vector3(side*0.37,0.29,-0.11),Vector3(0.14,0.37,0.18),p.trim,true)
		wing.rotation.z = -side*0.40
		gem(head,Vector3(side*0.41,0.48,-0.11),Vector3(0.12,0.25,0.16),p.edge)
	var crest := cylinder(head,Vector3(0,0.23,-0.43),0.145,0.055,p.trim,true)
	crest.rotation.x = PI/2
	gem(head,Vector3(0,0.25,-0.48),Vector3(0.17,0.22,0.07),p.energy)
	for i in range(3):
		var plume := piece(head,Vector3(0,0.49+i*0.105,0.07+i*0.07),Vector3(0.15,0.21,0.23),p.armor if identity==0 else p.energy)
		plume.rotation.x = -0.28
		piece(head,plume.position+Vector3(0,0.01,-0.12),Vector3(0.05,0.12,0.025),p.trim,true)

func build_cape() -> void:
	cape = pivot(rig,Vector3(0,1.55,0.30),"SegmentedCape")
	for side in [-1,1]:
		var clasp := cylinder(rig,Vector3(side*0.32,1.54,-0.30),0.09,0.04,p.trim,true)
		clasp.rotation.x = PI/2
	for i in range(7):
		var x := (i-3)*0.15
		var length := 1.19-absf(x)*0.18
		var strip := piece(cape,Vector3(x,-length*0.5,0.13+absf(x)*0.10),Vector3(0.17,length,0.055),p.cape.lightened(0.04 if i%2==0 else 0.0))
		strip.rotation.x = -0.18
		strip.rotation.z = x*0.22
		var hem := piece(cape,Vector3(x,-length,0.23+absf(x)*0.10),Vector3(0.16,0.055,0.06),p.trim,true)
		hem.rotation.z = x*0.22

func build_glaive() -> void:
	weapon.name = "JadeDragonGlaive"
	cylinder(weapon,Vector3(0,0.17,0),0.045,2.35,p.dark,true)
	for y in [-0.85,-0.25,0.35,0.72]:
		cylinder(weapon,Vector3(0,y,0),0.065,0.11,p.trim,true)
	# Curved polygon blade with raised central ridge, gold socket and jagged spine.
	var outline := PackedVector2Array([Vector2(-0.06,0.75),Vector2(-0.13,1.10),Vector2(-0.11,1.50),Vector2(0.04,1.81),Vector2(0.42,2.06),Vector2(0.31,1.69),Vector2(0.44,1.44),Vector2(0.25,1.20),Vector2(0.23,0.88)])
	blade(weapon,outline,0.085,p.energy)
	for i in range(4):
		var ornament := piece(weapon,Vector3(0.08,0.90+i*0.15,-0.067),Vector3(0.13,0.06,0.035),p.trim,true)
		ornament.rotation.z = i*0.14
	gem(weapon,Vector3(0.13,0.94,-0.1),Vector3(0.19,0.27,0.10),p.edge)
	weapon.rotation.z = -0.16

func blade(parent: Node3D, outline: PackedVector2Array, depth: float, color: Color, metal := true, glow := true) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for side in [-1,1]:
		for i in range(0,indices.size(),3):
			for j in ([0,1,2] if side==1 else [2,1,0]):
				var v := outline[indices[i+j]]
				st.add_vertex(Vector3(v.x,v.y,side*depth*0.5))
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		for v in [Vector3(a.x,a.y,-depth/2),Vector3(b.x,b.y,-depth/2),Vector3(a.x,a.y,depth/2),Vector3(a.x,a.y,depth/2),Vector3(b.x,b.y,-depth/2),Vector3(b.x,b.y,depth/2)]:
			st.add_vertex(v)
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat(color,metal,glow)
	n.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	parent.add_child(n)
	decorative_parts += 1

func build_crossbow() -> void:
	weapon.name = "EmberRepeater"
	piece(weapon,Vector3(0,0,-0.28),Vector3(0.22,0.25,0.95),p.dark,true)
	piece(weapon,Vector3(0,0.09,-0.26),Vector3(0.24,0.11,0.70),p.trim,true)
	piece(weapon,Vector3(0,-0.16,-0.02),Vector3(0.17,0.30,0.24),p.armor)
	for side in [-1,1]:
		var bow := piece(weapon,Vector3(side*0.25,0,-0.48),Vector3(0.48,0.10,0.15),p.trim,true)
		bow.rotation.y = -side*0.35
		gem(weapon,Vector3(side*0.45,0,-0.60),Vector3(0.18,0.29,0.17),p.energy)
	for i in range(3):
		piece(weapon,Vector3(0,0.01,-0.48-i*0.13),Vector3(0.10,0.09,0.06),p.energy)
	var muzzle := cylinder(weapon,Vector3(0,0,-0.81),0.12,0.14,p.trim,true)
	muzzle.rotation.x = PI/2
	gem(weapon,Vector3(0,0.0,-0.92),Vector3(0.14,0.18,0.22),p.energy)

func build_staff() -> void:
	weapon.name = "FrostLotusStaff"
	cylinder(weapon,Vector3(0,0.25,0),0.05,2.35,p.trim,true)
	for y in [-0.65,0.1,0.75]:
		cylinder(weapon,Vector3(0,y,0),0.08,0.14,p.armor,true)
	for side in [-1,1]:
		var prong := piece(weapon,Vector3(side*0.19,1.20,0),Vector3(0.10,0.63,0.13),p.trim,true)
		prong.rotation.z = -side*0.40
		gem(weapon,Vector3(side*0.29,1.46,0),Vector3(0.13,0.27,0.14),p.energy)
	gem(weapon,Vector3(0,1.40,0),Vector3(0.34,0.62,0.31),p.energy)
	var collar := cylinder(weapon,Vector3(0,1.06,0),0.20,0.11,p.trim,true)
	collar.rotation.z = 0.1

func animate(delta: float, walking: bool, enabled := true) -> void:
	if not enabled:
		return
	walk_phase += delta*(11.0 if walking else 1.8)
	attack_time = maxf(0,attack_time-delta)
	skill_time = maxf(0,skill_time-delta)
	var stride := sin(walk_phase)*(0.43 if walking else 0.015)
	leg_l.rotation.x = stride
	leg_r.rotation.x = -stride
	arm_l.rotation.x = -stride*0.65-0.08
	arm_r.rotation.x = stride*0.45-0.13
	rig.position.y = absf(sin(walk_phase))*0.045 if walking else sin(walk_phase)*0.012
	cape.rotation.x = -0.08-sin(walk_phase*0.7)*0.055-(0.15 if walking else 0.0)
	cape.rotation.z = sin(walk_phase*0.55)*0.035
	if attack_time>0:
		var swing := sin((1.0-attack_time/0.32)*PI)
		arm_r.rotation.x += swing*0.22 if identity==1 else -swing*0.9
		arm_r.rotation.z = -swing*0.65 if identity==0 else 0.0
	else:
		arm_r.rotation.z = lerpf(arm_r.rotation.z,0.0,minf(1,delta*12))
	if skill_time>0:
		arm_l.rotation.x -= sin(skill_time*PI)*0.8

func attack() -> void:
	attack_time = 0.32

func cast() -> void:
	skill_time = 0.8

extends Node3D
## Original toy zombies: shared geometry, articulated reach/limp and distinct silhouettes.
const Parts = preload("res://hero_model.gd")
const PALETTES = [
	{"skin":Color("85997a"),"cloth":Color("374751"),"pants":Color("333c47"),"decay":Color("43503a"),"eye":Color("f18a70")},
	{"skin":Color("a0ab78"),"cloth":Color("743e38"),"pants":Color("413b36"),"decay":Color("53553a"),"eye":Color("ffc76c")},
	{"skin":Color("928a96"),"cloth":Color("4a424a"),"pants":Color("3a363b"),"decay":Color("514651"),"eye":Color("ff9c76")},
	{"skin":Color("a2aa62"),"cloth":Color("616341"),"pants":Color("434736"),"decay":Color("566337"),"eye":Color("d9ff7a")},
	{"skin":Color("687c65"),"cloth":Color("373c39"),"pants":Color("343731"),"decay":Color("384837"),"eye":Color("ff6e58")}
]
static var baked_cache: Dictionary = {}
static var surface_cache: Dictionary = {}
static var faded_cache: Dictionary = {}
var cache_namespace := "zombie"
var identity := 0
var variant := 0
var p: Dictionary
var rig: Node3D
var head: Node3D
var jaw: Node3D
var arm_l: Node3D
var arm_r: Node3D
var wrist_l: Node3D
var wrist_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var meshes: Array[MeshInstance3D] = []
var base_materials: Array[Material] = []
var camera_occluded := false
var details := 0
var phase := 0.0
var attack_time := 0.0
var health_height := 2.6
var current_overlay: Material

static func surface(color: Color, metal := false, glow := false) -> StandardMaterial3D:
	var key := str(color)+str(metal)+str(glow)
	if surface_cache.has(key):
		return surface_cache[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.87
	result.metallic = 0.25 if metal else 0.0
	result.metallic_specular = 0.18
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 0.4
	surface_cache[key] = result
	return result

func pivot(parent: Node3D, pos: Vector3, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = pos
	parent.add_child(node)
	return node

func piece(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metal := false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = Parts.beveled(size)
	n.material_override = surface(color,metal)
	n.position = pos
	parent.add_child(n)
	details += 1
	return n

func round_part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 10
	shape.rings = 5
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.scale = size
	n.position = pos
	n.material_override = surface(color)
	parent.add_child(n)
	details += 1
	return n

func face_disc(parent: Node3D, pos: Vector3, radius: float, color: Color, glow := false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = 0.025
	shape.radial_segments = 10
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.position = pos
	n.rotation.x = PI/2
	n.material_override = surface(color,false,glow)
	parent.add_child(n)
	details += 1
	return n

func build(kind: int, color_variant := 0) -> void:
	identity = kind
	variant = color_variant%3
	p = PALETTES[kind].duplicate()
	p.skin = p.skin.lightened((variant-1)*0.035)
	name = ["Shambler","Runner","ArmoredHulk","PlagueSpitter","Abomination"][kind]
	phase = variant*2.1
	rig = pivot(self,Vector3.ZERO,"LimpingRig")
	var broad := 1.15 if kind==4 else 1.02 if kind==2 else 0.72 if kind==3 else 0.58 if kind==1 else 0.72
	piece(rig,Vector3(0,1.17,0),Vector3(broad,0.70,0.43),p.cloth)
	# A torn chest opening, discolored flesh and exposed pale rib motifs.
	piece(rig,Vector3(0.07,1.28,-0.238),Vector3(broad*0.48,0.35,0.045),p.decay)
	for i in range(3):
		var rib := piece(rig,Vector3(0.07,1.15+i*0.105,-0.27),Vector3(broad*0.34,0.038,0.03),Color("b9b797"))
		rib.rotation.z = -0.12
	piece(rig,Vector3(-broad*0.28,1.42,-0.235),Vector3(0.19,0.18,0.055),p.skin)
	for i in range(4):
		var rag := piece(rig,Vector3((i-1.5)*broad/4,0.81-float(i%2)*0.065,-0.02),Vector3(broad/4-0.025,0.22,0.45),p.cloth)
		rag.rotation.z = (i-1.5)*0.09
	leg_l = build_leg(-1,kind)
	leg_r = build_leg(1,kind)
	arm_l = build_arm(-1,kind)
	arm_r = build_arm(1,kind)
	wrist_l = arm_l.get_node("DanglingWrist")
	wrist_r = arm_r.get_node("DanglingWrist")
	build_head(kind)
	if kind==0 or kind==2:
		piece(rig,Vector3(0,1.22,0.24),Vector3(0.27,0.40,0.05),p.decay)
		for i in range(3):
			piece(rig,Vector3(0,1.10+i*0.11,0.28),Vector3(0.10,0.065,0.06),Color("b9b797"))
	if kind==1:
		# Ragged hood, protruding spine and narrow hunched shoulders.
		piece(rig,Vector3(0,1.58,0.15),Vector3(0.53,0.22,0.38),p.cloth)
		for i in range(3):
			piece(rig,Vector3(0,1.02+i*0.17,0.25),Vector3(0.13,0.09,0.10),Color("bbb79b"))
	elif kind==2:
		build_rust_armor()
	elif kind==3:
		# Distended abdomen and acid sacs are readable from the battle camera.
		round_part(rig,Vector3(0,1.14,-0.16),Vector3(0.94,0.83,0.62),p.skin)
		for i in range(3):
			round_part(rig,Vector3((i-1)*0.23,1.44+float(i%2)*0.18,0.23),Vector3(0.36,0.42,0.35),Color("879c42"))
			face_disc(rig,Vector3((i-1)*0.20,1.17,-0.48),0.055,Color("d0e57b"))
	elif kind==4:
		health_height = 2.9
		build_rust_armor()
		for i in range(5):
			var bone := piece(rig,Vector3((i-2)*0.20,1.55+0.10*(2-absi(i-2)),0.25),Vector3(0.12,0.64,0.13),Color("bab69a"))
			bone.rotation.x = -0.45
			bone.rotation.z = -(i-2)*0.18
		piece(arm_r,Vector3(0.12,-0.14,0),Vector3(0.42,0.48,0.48),p.decay)
	bake(rig)
	animate(0,false)

func build_leg(side: int, kind: int) -> Node3D:
	var node := pivot(rig,Vector3(side*0.20,0.78,0),"LeftDraggingLeg" if side<0 else "RightDraggingLeg")
	var width := 0.20 if kind==1 else 0.31
	piece(node,Vector3(0,-0.20,0),Vector3(width,0.39,0.31),p.pants)
	piece(node,Vector3(0,-0.43,0),Vector3(width*0.75,0.22,0.26),p.skin if side<0 else p.pants)
	piece(node,Vector3(0,-0.32,-0.175),Vector3(width*0.55,0.13,0.035),p.decay)
	if side<0:
		piece(node,Vector3(0,-0.34,-0.20),Vector3(0.075,0.12,0.025),Color("bdbb9d"))
	var foot := piece(node,Vector3(0,-0.63,-0.07),Vector3(width+0.04,0.18,0.46),p.skin if kind==1 or side<0 else p.pants.darkened(0.3))
	foot.rotation.y = side*0.15
	return node

func build_arm(side: int, kind: int) -> Node3D:
	var broad := 0.65 if kind==4 else 0.57 if kind==2 else 0.45
	var node := pivot(rig,Vector3(side*broad,1.45,0),"LeftReachingArm" if side<0 else "RightReachingArm")
	var width := 0.33 if kind==4 else 0.28 if kind==2 else 0.18 if kind==1 else 0.23
	piece(node,Vector3(0,-0.14,0),Vector3(width,0.30,0.30),p.cloth if side>0 else p.skin)
	piece(node,Vector3(0,-0.35,0),Vector3(width*0.85,0.25,0.25),p.skin)
	piece(node,Vector3(0,-0.23,-0.15),Vector3(width*0.7,0.09,0.035),p.decay)
	var wrist := pivot(node,Vector3(0,-0.52,0),"DanglingWrist")
	piece(wrist,Vector3(0,-0.09,0),Vector3(width+0.05,0.23,0.16),p.skin)
	for i in range(3):
		var claw := piece(wrist,Vector3((i-1)*0.065,-0.25-float(i%2)*0.04,-0.045),Vector3(0.045,0.18+float(i%2)*0.05,0.06),Color("c9c5a4"))
		claw.rotation.x = -0.28
	return node

func build_head(kind: int) -> void:
	head = pivot(rig,Vector3(0,1.91,-0.015),"TiltedDecayedHead")
	var skull := CylinderMesh.new()
	skull.top_radius = 0.31
	skull.bottom_radius = 0.29
	skull.height = 0.52
	skull.radial_segments = 12
	var n := MeshInstance3D.new()
	n.mesh = skull
	n.material_override = surface(p.skin)
	head.add_child(n)
	details += 1
	piece(head,Vector3(0,0.29,0),Vector3(0.20,0.10,0.19),p.decay)
	# Unequal black eye sockets, tiny luminous pupils and a missing-cheek patch.
	for side in [-1,1]:
		var socket := face_disc(head,Vector3(side*0.12,0.045,-0.279),0.10 if side<0 else 0.085,Color("222a23"))
		socket.scale.z = 0.72
		face_disc(head,Vector3(side*0.12,0.038,-0.302),0.038 if side<0 else 0.028,p.eye,true)
	piece(head,Vector3(0,-0.04,-0.31),Vector3(0.065,0.08,0.04),p.decay)
	piece(head,Vector3(-0.24,-0.02,-0.19),Vector3(0.11,0.18,0.12),p.decay)
	var scar := piece(head,Vector3(0.09,0.19,-0.26),Vector3(0.16,0.065,0.045),p.decay)
	scar.rotation.z = 0.45
	piece(head,Vector3(0,-0.14,-0.29),Vector3(0.28,0.16,0.06),Color("20291f"))
	for i in range(3):
		if i!=1 or kind==4:
			piece(head,Vector3((i-1)*0.075,-0.09,-0.335),Vector3(0.044,0.07,0.025),Color("dad4ad"))
	jaw = pivot(head,Vector3(0,-0.24,-0.17),"HangingJaw")
	piece(jaw,Vector3.ZERO,Vector3(0.28,0.11,0.23),p.skin)
	piece(jaw,Vector3(0,0.03,-0.12),Vector3(0.20,0.05,0.025),p.decay)
	piece(jaw,Vector3(0.07,0.075,-0.12),Vector3(0.045,0.08,0.025),Color("d9d1a5"))
	if kind==0 or kind==1:
		for i in range(3):
			var hair := piece(head,Vector3((i-1)*0.16,0.25,0.08),Vector3(0.13,0.13+0.08*float(i%2),0.30),Color("333d32"))
			hair.rotation.z = (i-1)*0.12
	elif kind==2:
		piece(head,Vector3(0.06,0.28,0.04),Vector3(0.61,0.17,0.52),Color("735648"),true)
		piece(head,Vector3(0.23,0.13,0.02),Vector3(0.13,0.32,0.42),Color("53504b"),true)
	elif kind==3:
		face_disc(head,Vector3(0,-0.14,-0.34),0.15,Color("24351d"))
		face_disc(head,Vector3(0,-0.14,-0.36),0.075,Color("c6ef75"),true)
		for side in [-1,1]:
			piece(head,Vector3(side*0.12,-0.10,-0.363),Vector3(0.045,0.075,0.035),Color("d8d0a1"))
		jaw.scale = Vector3(1.3,1.2,1.0)
	else:
		for side in [-1,1]:
			var horn := piece(head,Vector3(side*0.30,0.20,0.04),Vector3(0.13,0.40,0.15),Color("c3bea0"))
			horn.rotation.z = -side*0.6
		jaw.scale = Vector3(1.2,1.2,1.2)

func build_rust_armor() -> void:
	var plate := piece(rig,Vector3(-0.12,1.29,-0.29),Vector3(0.55,0.43,0.12),Color("715244"),true)
	plate.rotation.z = -0.12
	piece(rig,Vector3(-0.12,1.27,-0.37),Vector3(0.34,0.065,0.035),Color("383a37"))
	for x in [-0.31,0.09]:
		piece(rig,Vector3(x,1.43,-0.36),Vector3(0.06,0.06,0.045),Color("a99167"),true)
	piece(arm_l,Vector3(-0.05,0.03,0),Vector3(0.52,0.26,0.57),Color("625d57"),true)
	piece(arm_l,Vector3(-0.08,0.18,0.05),Vector3(0.11,0.30,0.13),Color("a49776"),true)

func bake(node: Node3D) -> void:
	# Merge static facial/clothing details per bone and material; cache across the horde.
	var raw: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			raw.append(child)
		elif child is Node3D:
			bake(child)
	if raw.is_empty():
		return
	var key := "%s/%d/%d/%s" % [cache_namespace,identity,variant,node.name]
	if not baked_cache.has(key):
		var groups: Dictionary = {}
		for child in raw:
			var material: Material = child.material_override
			var id := material.get_instance_id()
			if not groups.has(id):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[id] = {"tool":st,"material":material}
			groups[id].tool.append_from(child.mesh,0,child.transform)
		var baked: Array = []
		for group in groups.values():
			baked.append({"mesh":group.tool.commit(),"material":group.material})
		baked_cache[key] = baked
	for child in raw:
		node.remove_child(child)
		child.free()
	for data in baked_cache[key]:
		var part := MeshInstance3D.new()
		part.mesh = data.mesh
		part.material_override = data.material
		node.add_child(part)
		meshes.append(part)
		base_materials.append(data.material)

func set_overlay(value: Material) -> void:
	if value==current_overlay:
		return
	current_overlay = value
	for part in meshes:
		part.material_overlay = null if camera_occluded else value

func set_camera_occluded(hidden: bool) -> void:
	if camera_occluded==hidden:
		return
	camera_occluded = hidden
	for i in range(meshes.size()):
		var base: StandardMaterial3D = base_materials[i]
		if hidden:
			var id := base.get_instance_id()
			if not faded_cache.has(id):
				var faded := base.duplicate() as StandardMaterial3D
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				faded.albedo_color.a = 0.28
				faded.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				faded_cache[id] = faded
			meshes[i].material_override = faded_cache[id]
		else:
			meshes[i].material_override = base
		meshes[i].material_overlay = null if hidden else current_overlay

func mouth_position() -> Vector3:
	return head.to_global(Vector3(0,-0.14,-0.40))

func attack() -> void:
	attack_time = 0.42

func animate(delta: float, walking: bool, slowed := false) -> void:
	phase += delta*(10 if identity==1 else 4.2)*(0.5 if slowed else 1.0)
	attack_time = maxf(0,attack_time-delta)
	var sway := sin(phase)
	var stride := sway*(0.50 if identity==1 else 0.27) if walking else 0.015*sway
	leg_l.rotation.x = stride+0.12
	leg_r.rotation.x = -stride*0.55-0.10
	rig.position.y = absf(sin(phase))*0.035 if walking else sin(phase*0.6)*0.015
	rig.rotation.x = -0.38 if identity==1 else -0.12 if identity==2 else -0.19
	rig.rotation.z = sin(phase*0.5)*(0.08 if walking else 0.025)
	head.rotation.z = -0.17+sin(phase*0.45)*0.04
	head.rotation.x = 0.10
	arm_l.rotation.x = 1.45+sway*0.10
	arm_r.rotation.x = 1.15-sway*0.14
	arm_l.rotation.z = -0.10
	arm_r.rotation.z = 0.12
	wrist_l.rotation.x = -0.55+sin(phase*0.7)*0.08
	wrist_r.rotation.x = -0.65
	jaw.rotation.x = 0.12+sin(phase*0.7)*0.06
	if identity==1:
		arm_l.rotation.x = 1.45+sway*0.3
		arm_r.rotation.x = 0.15-sway*0.4
	elif identity==3:
		arm_l.rotation.x = 0.35+sway*0.1
		arm_r.rotation.x = 0.50-sway*0.1
	if attack_time>0:
		var lunge := sin((1-attack_time/0.42)*PI)
		arm_l.rotation.x += lunge*0.65
		arm_r.rotation.x += lunge*0.75
		rig.rotation.x -= lunge*0.18
		jaw.rotation.x += lunge*0.60

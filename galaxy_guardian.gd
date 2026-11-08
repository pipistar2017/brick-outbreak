extends "res://hero_model.gd"
## Procedural red/gold guardian inspired by the supplied mech turnaround.
const RED = Color("c92b32")
const GOLD = Color("eebc43")
const TEAL = Color("15989e")
const DARK = Color("242a34")
var back_rings: Array[MeshInstance3D] = []
var flames: Array[Node3D] = []
var age := 0.0

func energy(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := gem(parent,pos,size,color)
	var translucent: StandardMaterial3D = node.material_override.duplicate()
	translucent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	translucent.albedo_color.a = 0.83
	node.material_override = translucent
	return node

func hoop(parent: Node3D, pos: Vector3, radius: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-0.045
	mesh.outer_radius = radius+0.045
	mesh.rings = 40
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(GOLD,true)
	node.position = pos
	node.rotation.x = PI/2
	parent.add_child(node)
	decorative_parts += 1
	return node

func build_guardian() -> void:
	name = "GalaxyGuardian"
	rig = pivot(self,Vector3.ZERO,"MechRig")
	piece(rig,Vector3(0,2.15,0),Vector3(1.26,0.95,0.70),RED)
	piece(rig,Vector3(0,1.63,0),Vector3(1.12,0.2,0.77),GOLD,true)
	piece(rig,Vector3(0,2.19,-0.38),Vector3(0.96,0.70,0.09),GOLD,true)
	for side in [-1,1]:
		piece(rig,Vector3(side*0.38,1.87,-0.45),Vector3(0.30,0.20,0.08),TEAL)
		for i in range(4):
			var rib := piece(rig,Vector3(side*(0.12+i*0.10),2.22-i*0.06,-0.45),Vector3(0.065,0.25,0.035),DARK)
			rib.rotation.z = side*0.6
	cylinder(rig,Vector3(0,2.22,-0.48),0.16,0.06,TEAL,true).rotation.x = PI/2
	# A small pilot under the chest armour window.
	cylinder(rig,Vector3(0,2.48,-0.43),0.13,0.22,Color("f3d276"))
	piece(rig,Vector3(0,2.47,-0.56),Vector3(0.21,0.05,0.025),DARK)
	for side in [-1,1]:
		var leg := pivot(rig,Vector3(side*0.40,1.5,0),"LeftLeg" if side<0 else "RightLeg")
		piece(leg,Vector3(0,-0.31,0),Vector3(0.52,0.62,0.55),RED)
		cylinder(leg,Vector3(0,-0.62,0),0.24,0.16,DARK).rotation.z = PI/2
		piece(leg,Vector3(0,-0.97,0),Vector3(0.55,0.63,0.59),RED)
		piece(leg,Vector3(0,-0.96,-0.32),Vector3(0.35,0.49,0.12),GOLD,true)
		piece(leg,Vector3(0,-1.33,-0.12),Vector3(0.62,0.28,0.83),DARK)
		piece(leg,Vector3(0,-1.17,-0.37),Vector3(0.43,0.2,0.19),Color("bfc7c7"),true)
		for i in range(4):
			piece(leg,Vector3(side*0.3,-0.85+i*0.14,0),Vector3(0.08,0.08,0.30),GOLD,true)
		var flame := pivot(leg,Vector3(side*0.32,-0.85,0.12),"LegFlames")
		for i in range(3):
			var tip := energy(flame,Vector3(side*i*0.08,i*0.19,0),Vector3(0.13,0.65-i*0.08,0.14),Color("ff9c16"))
			tip.rotation.z = -side*0.25
		flames.append(flame)
		if side<0: leg_l = leg
		else: leg_r = leg
		var arm := pivot(rig,Vector3(side*0.94,2.45,0),"LeftArm" if side<0 else "RightArm")
		cylinder(arm,Vector3.ZERO,0.27,0.28,DARK).rotation.z = PI/2
		piece(arm,Vector3(side*0.10,0.07,0),Vector3(0.65,0.38,0.69),GOLD,true)
		piece(arm,Vector3(side*0.12,-0.30,0),Vector3(0.44,0.5,0.45),RED)
		piece(arm,Vector3(side*0.18,-0.72,-0.04),Vector3(0.48,0.43,0.52),RED)
		piece(arm,Vector3(side*0.18,-0.98,-0.06),Vector3(0.37,0.25,0.38),DARK)
		for i in range(3):
			piece(arm,Vector3(side*0.18,-0.72+i*0.12,-0.32),Vector3(0.33,0.06,0.08),GOLD,true)
		if side<0: arm_l = arm
		else: arm_r = arm
	var head := pivot(rig,Vector3(0,3.02,0),"OrnateHelmet")
	cylinder(head,Vector3.ZERO,0.35,0.63,GOLD,true)
	piece(head,Vector3(0,0,-0.32),Vector3(0.57,0.4,0.12),Color("f1cf65"))
	piece(head,Vector3(0,0.06,-0.40),Vector3(0.55,0.14,0.035),DARK)
	for side in [-1,1]:
		energy(head,Vector3(side*0.15,0.065,-0.43),Vector3(0.19,0.10,0.03),Color("ff4936"))
		piece(head,Vector3(side*0.36,-0.05,0),Vector3(0.14,0.56,0.51),GOLD,true)
		for i in range(3):
			var crest := gem(head,Vector3(side*(0.15+i*0.11),0.4-i*0.02,0.03),Vector3(0.13,0.43+i*0.08,0.15),GOLD)
			crest.rotation.z = -side*(0.12+i*0.14)
	piece(head,Vector3(0,-0.15,-0.40),Vector3(0.25,0.035,0.03),DARK)
	gem(head,Vector3(0,0.48,-0.02),Vector3(0.20,0.45,0.22),GOLD)
	# Red cape and paired circular backpack rings with tall flame fins.
	cape = pivot(rig,Vector3(0,2.55,0.43),"RedCape")
	for i in range(7):
		var fold := piece(cape,Vector3((i-3)*0.22,-0.60,0.24+absf(i-3)*0.03),Vector3(0.24,1.60,0.075),Color("a91d30"))
		fold.rotation.x = -0.17
	for side in [-1,1]:
		back_rings.append(hoop(rig,Vector3(side*0.39,2.29,0.68),0.80))
		piece(rig,Vector3(side*0.36,2.65,0.65),Vector3(0.29,1.35,0.26),GOLD,true)
		for i in range(3):
			var fin := energy(rig,Vector3(side*(0.72+i*0.16),2.65+i*0.18,0.5),Vector3(0.18,0.8,0.14),Color("ff6525"))
			fin.rotation.z = -side*0.45
		# Segmented golden curved blades sweep away from the waist.
		for i in range(7):
			var a := i*0.13
			var blade := piece(rig,Vector3(side*(0.58+i*0.13),1.50-i*0.055,0.45+a*a),Vector3(0.24,0.10,0.22),GOLD,true)
			blade.rotation.y = side*a
	# Right-hand red energy sword and left-hand orange energy disc.
	weapon = pivot(arm_r,Vector3(0.18,-0.95,-0.30),"RedEnergyBlade")
	cylinder(weapon,Vector3.ZERO,0.07,0.55,DARK)
	piece(weapon,Vector3(0,0.25,0),Vector3(0.55,0.10,0.20),GOLD,true)
	energy(weapon,Vector3(0,1.03,0),Vector3(0.42,1.55,0.14),Color("f72d2d"))
	for i in range(4):
		energy(weapon,Vector3(0,0.5+i*0.24,-0.1),Vector3(0.19,0.15,0.035),Color("ffaf42"))
	var shield := pivot(arm_l,Vector3(-0.23,-0.68,-0.35),"OrangeEnergyDisc")
	var disc := cylinder(shield,Vector3.ZERO,0.62,0.09,Color("ff9a17"))
	disc.rotation.x = PI/2
	var transparent: StandardMaterial3D = disc.material_override.duplicate()
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent.albedo_color.a = 0.78
	transparent.emission_enabled = true
	transparent.emission = Color("ff8b12")
	disc.material_override = transparent
	hoop(shield,Vector3(0,0,-0.07),0.60)
	for i in range(12):
		var angle := i*TAU/12
		var ray := piece(shield,Vector3(sin(angle)*0.45,cos(angle)*0.45,-0.10),Vector3(0.055,0.18,0.045),GOLD,true)
		ray.rotation.z = -angle
	animate(0,false)

func animate(delta: float, _walking: bool, _slowed := false) -> void:
	age += delta
	rig.position.y = sin(age*1.6)*0.025
	arm_r.rotation.x = -0.10+sin(age)*0.025
	arm_l.rotation.x = -0.35
	cape.rotation.x = sin(age*1.4)*0.045
	for i in range(flames.size()):
		flames[i].scale.y = 1.0+sin(age*7+i)*0.13

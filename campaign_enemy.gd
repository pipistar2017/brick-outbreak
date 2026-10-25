extends "res://zombie_model.gd"
## Theme-specific articulated toy creatures. Shared feedback and baking come from ZombieVisual.
var stage := 0
var rear_legs: Array[Node3D] = []
var tail: Node3D
var weapon: Node3D

func build_for_stage(stage_index: int, kind: int, color_variant := 0) -> void:
	stage = stage_index
	identity = kind
	variant = color_variant%3
	cache_namespace = "campaign-%d" % stage
	name = ["InfectedAnimal","TombMummy","TerracottaWarrior"][stage]+str(kind)
	phase = variant*2.1
	rig = pivot(self,Vector3.ZERO,"Body")
	if stage==0:
		build_animal()
	else:
		build_soldier()
	bake(rig)
	animate(0,false)

func build_animal() -> void:
	var boar := identity==2
	var lion := identity>=3
	var fur: Color = Color("51463f") if boar else Color("bb8a48") if lion else Color("66706a")
	fur = fur.lightened((variant-1)*0.035)
	var dark := fur.darkened(0.40)
	var sick := Color("83a358")
	var length := 1.65 if boar else 1.9 if lion else 1.65
	var broad := 0.98 if boar else 0.78 if lion else 0.61
	piece(rig,Vector3(0,0.98,0),Vector3(broad,0.64,length),fur)
	piece(rig,Vector3(0,1.30,0.10),Vector3(broad*0.70,0.18,length*0.85),dark)
	piece(rig,Vector3(0,0.72,-0.02),Vector3(broad*0.65,0.20,length*0.70),sick)
	# Four independent legs and broad paws make a true quadruped silhouette.
	for z in [-0.59,0.59]:
		for side in [-1,1]:
			var leg := pivot(rig,Vector3(side*broad*0.39,0.90,z),"Leg%d%d" % [int(z*100),side])
			piece(leg,Vector3(0,-0.17,0),Vector3(0.22,0.43,0.27),fur)
			piece(leg,Vector3(0,-0.48,0.015),Vector3(0.15,0.29,0.18),dark)
			piece(leg,Vector3(0,-0.70,-0.10),Vector3(0.26,0.16,0.36),dark)
			for digit in range(3):
				piece(leg,Vector3((digit-1)*0.07,-0.69,-0.29),Vector3(0.04,0.045,0.13),Color("d4c9a5"))
			if z<0:
				if side<0: leg_l = leg
				else: leg_r = leg
			else:
				rear_legs.append(leg)
	head = pivot(rig,Vector3(0,1.22,-0.88),"AnimalHead")
	if lion:
		for i in range(10):
			var a := i*TAU/10
			var mane := piece(head,Vector3(sin(a)*0.43,cos(a)*0.42,0.10),Vector3(0.32,0.38,0.43),Color("6e4930"))
			mane.rotation.z = -a
	piece(head,Vector3.ZERO,Vector3(0.72 if boar else 0.66,0.52,0.62),fur)
	piece(head,Vector3(0,-0.07,-0.42),Vector3(0.49 if boar else 0.42,0.28,0.52 if not lion else 0.33),fur.lightened(0.15))
	piece(head,Vector3(0,-0.04,-0.71 if not lion else -0.61),Vector3(0.30,0.17,0.09),Color("2c3030"))
	for side in [-1,1]:
		var ear := piece(head,Vector3(side*0.27,0.38,0.02),Vector3(0.17,0.34 if not lion else 0.21,0.19),dark)
		ear.rotation.z = side*0.25
		piece(head,Vector3(side*0.27,0.37,-0.09),Vector3(0.08,0.19 if not lion else 0.10,0.025),sick)
		piece(head,Vector3(side*0.28,0.06,-0.322),Vector3(0.18,0.15,0.04),Color("232a23"))
		face_disc(head,Vector3(side*0.28,0.06,-0.35),0.055,Color("b9f26e"),true)
		var fang := piece(head,Vector3(side*0.18,-0.23,-0.51),Vector3(0.075,0.24 if boar else 0.16,0.09),Color("efe1b5"))
		fang.rotation.z = side*0.25
	jaw = pivot(head,Vector3(0,-0.27,-0.30),"BitingJaw")
	piece(jaw,Vector3(0,0,-0.08),Vector3(0.40,0.13,0.50),dark)
	piece(jaw,Vector3(0,0.06,-0.12),Vector3(0.29,0.045,0.32),Color("917c68"))
	tail = pivot(rig,Vector3(0,1.10,length*0.48),"Tail")
	var tail_part := piece(tail,Vector3(0,0.03,0.35),Vector3(0.15,0.16,0.80),dark)
	tail_part.rotation.x = -0.35
	piece(tail,Vector3(0,0.16,0.73),Vector3(0.26,0.25,0.26),dark)
	# Sickly patches, glowing infection nodes and exposed ribs distinguish infected wildlife.
	for side in [-1,1]:
		piece(rig,Vector3(side*(broad*0.5+0.01),1.05,0.18),Vector3(0.04,0.32,0.65),sick.darkened(0.4))
		for i in range(3):
			var rib := piece(rig,Vector3(side*(broad*0.5+0.04),1.06,-0.02+i*0.18),Vector3(0.045,0.24,0.05),Color("c7c59e"))
			rib.rotation.x = 0.2
		for i in range(2):
			round_part(rig,Vector3(side*broad*0.40,1.30,0.20+i*0.34),Vector3(0.22,0.24,0.22),sick)
	if boar:
		for i in range(5):
			piece(rig,Vector3(0,1.47,-0.55+i*0.27),Vector3(0.12,0.27,0.14),dark)
	health_height = 2.10 if lion else 1.95

func build_soldier() -> void:
	var mummy := stage==1
	var skin := Color("b7aa83") if mummy else Color("a76d4c")
	var cloth := Color("d8c69d") if mummy else Color("6b5140")
	var trim := Color("bd9650") if mummy else Color("c4946b")
	var dark := Color("504c3b") if mummy else Color("50392e")
	var accent := Color("356b77") if mummy else Color("576458")
	skin = skin.lightened((variant-1)*0.035)
	piece(rig,Vector3(0,1.22,0),Vector3(0.80,0.77,0.46),skin)
	piece(rig,Vector3(0,0.85,0),Vector3(0.82,0.13,0.50),dark)
	for side in [-1,1]:
		var leg := pivot(rig,Vector3(side*0.23,0.80,0),"LeftLeg" if side<0 else "RightLeg")
		piece(leg,Vector3(0,-0.27,0),Vector3(0.30,0.52,0.33),skin)
		piece(leg,Vector3(0,-0.66,-0.08),Vector3(0.34,0.25,0.51),skin)
		var arm := pivot(rig,Vector3(side*0.57,1.50,0),"LeftArm" if side<0 else "RightArm")
		piece(arm,Vector3(0,-0.22,0),Vector3(0.28,0.43,0.31),skin)
		piece(arm,Vector3(0,-0.52,0),Vector3(0.23,0.28,0.26),skin)
		piece(arm,Vector3(0,-0.72,0),Vector3(0.27,0.20,0.23),skin)
		if side<0:
			leg_l = leg
			arm_l = arm
		else:
			leg_r = leg
			arm_r = arm
		if mummy:
			for i in range(4):
				piece(leg,Vector3(0,-0.10-i*0.14,-0.005),Vector3(0.32,0.055,0.35),cloth if i%2==0 else skin.darkened(0.12))
				piece(arm,Vector3(0,-0.08-i*0.15,0),Vector3(0.30,0.055,0.34),cloth)
		else:
			for i in range(3):
				piece(arm,Vector3(side*0.03,-0.04-i*0.12,-0.035),Vector3(0.40,0.11,0.40),cloth)
			piece(leg,Vector3(0,-0.38,-0.19),Vector3(0.26,0.30,0.055),cloth)
	head = pivot(rig,Vector3(0,1.98,0),"WrappedHead" if mummy else "ClayHead")
	piece(head,Vector3.ZERO,Vector3(0.57,0.60,0.52),skin)
	if mummy:
		for i in range(6):
			if i!=3:
				var band := piece(head,Vector3(0,-0.24+i*0.10,0),Vector3(0.61,0.065,0.56),cloth)
				band.rotation.z = -0.04
		for i in range(6):
			var band := piece(rig,Vector3(0,0.92+i*0.12,0),Vector3(0.83,0.06,0.49),cloth)
			band.rotation.z = 0.05
		for side in [-1,1]:
			var strip := piece(rig,Vector3(side*0.31,0.72,0.18),Vector3(0.13,0.52,0.035),cloth)
			strip.rotation.z = side*0.25
	else:
		# Segmented lamellar pottery armour, tunic skirt and sculpted topknot.
		for y in range(2 if identity==1 else 4):
			for x in range(5):
				for side in [-1,1]:
					piece(rig,Vector3((x-2)*0.16,0.98+y*0.16,side*0.265),Vector3(0.14,0.14,0.055),cloth)
		for x in range(4):
			piece(rig,Vector3((x-1.5)*0.20,0.66,-0.03),Vector3(0.18,0.30,0.51),cloth)
		piece(head,Vector3(0,0.33,0.05),Vector3(0.59,0.12,0.48),dark)
		piece(head,Vector3(0.13,0.47,0.07),Vector3(0.24,0.21,0.24),dark)
		if identity==1:
			piece(head,Vector3(0,0.23,0),Vector3(0.61,0.10,0.56),Color("805344"))
			var ribbon := piece(head,Vector3(0.24,0.09,0.37),Vector3(0.12,0.50,0.05),Color("805344"))
			ribbon.rotation.z = -0.3
		for side in [-1,1]:
			piece(head,Vector3(side*0.15,0.10,-0.28),Vector3(0.18,0.035,0.035),dark)
			piece(head,Vector3(side*0.08,-0.13,-0.29),Vector3(0.13,0.04,0.035),dark)
		piece(head,Vector3(0,-0.22,-0.25),Vector3(0.18,0.12,0.08),dark)
	# Deep eye sockets and thin lit eyes; visible cracks run across ceramic or bandages.
	for side in [-1,1]:
		piece(head,Vector3(side*0.14,0.015,-0.283),Vector3(0.19,0.12,0.025),dark)
		piece(head,Vector3(side*0.14,0.015,-0.302),Vector3(0.095,0.035,0.02),Color("98dcc4") if not mummy else Color("e4a7f0"))
	piece(head,Vector3(0,-0.055,-0.30),Vector3(0.10,0.14,0.09),skin)
	jaw = pivot(head,Vector3(0,-0.23,-0.21),"Jaw")
	piece(jaw,Vector3.ZERO,Vector3(0.22,0.055,0.08),dark)
	for i in range(3):
		var crack := piece(rig,Vector3(-0.24+i*0.08,1.5-i*0.13,-0.30),Vector3(0.025,0.18,0.018),dark)
		crack.rotation.z = 0.42 if i%2==0 else -0.42
	if identity==1 and mummy:
		piece(head,Vector3(0,0.04,-0.43),Vector3(0.33,0.25,0.40),dark)
		for side in [-1,1]:
			piece(head,Vector3(side*0.22,0.51,0),Vector3(0.14,0.49,0.17),dark)
	if identity==2 or identity==4:
		piece(rig,Vector3(0,1.38,-0.29),Vector3(0.72,0.39,0.10),accent)
		for side in [-1,1]:
			piece(rig,Vector3(side*0.53,1.57,0),Vector3(0.50,0.21,0.61),trim)
		var shield := pivot(arm_l,Vector3(0,-0.42,-0.22),"Shield")
		piece(shield,Vector3.ZERO,Vector3(0.62,0.97,0.13),accent)
		piece(shield,Vector3(0,0,-0.09),Vector3(0.52,0.06,0.04),trim)
	if identity==4:
		if mummy:
			for side in [-1,1]:
				piece(head,Vector3(side*0.40,0,0.04),Vector3(0.23,0.83,0.56),accent)
				for i in range(6):
					piece(head,Vector3(side*0.40,-0.31+i*0.13,-0.26),Vector3(0.25,0.05,0.04),trim)
			piece(head,Vector3(0,0.38,0),Vector3(0.73,0.20,0.59),trim)
		else:
			piece(head,Vector3(0,0.39,0),Vector3(0.76,0.18,0.65),accent)
			piece(head,Vector3(0,0.69,0.02),Vector3(0.17,0.54,0.15),trim)
		piece(rig,Vector3(0,1.13,0.33),Vector3(0.91,0.97,0.08),accent)
	weapon = pivot(arm_r,Vector3(0,-0.59,-0.06),"Weapon")
	if identity==3:
		if mummy:
			piece(weapon,Vector3(0,0.32,-0.10),Vector3(0.10,1.70,0.10),dark)
			round_part(weapon,Vector3(0,1.23,-0.10),Vector3(0.36,0.43,0.31),Color("bc89c6"))
		else:
			piece(weapon,Vector3(0,0.05,-0.24),Vector3(0.15,0.16,1.10),dark)
			piece(weapon,Vector3(0,0.07,-0.63),Vector3(1.18,0.12,0.14),trim)
			piece(weapon,Vector3(0,0.08,-0.48),Vector3(1.04,0.025,0.025),Color("b8b39a"))
			piece(weapon,Vector3(0,0.16,-0.64),Vector3(0.055,0.055,1.10),trim)
	else:
		piece(weapon,Vector3(0,0.13 if identity==1 else 0.30,-0.04),Vector3(0.08,0.45 if identity==1 else 1.34,0.09),dark)
		var blade := piece(weapon,Vector3(0,0.58 if identity==1 else 1.13,-0.04),Vector3(0.18 if identity!=4 else 0.32,0.56,0.065),trim)
		blade.rotation.z = -0.10
	health_height = 2.85 if identity==4 else 2.65

func mouth_position() -> Vector3:
	if stage==2 and identity==3:
		return weapon.to_global(Vector3(0,0.16,-1.19))
	return head.to_global(Vector3(0,-0.05,-0.65 if stage==0 else -0.40))

func animate(delta: float, walking: bool, slowed := false) -> void:
	phase += delta*(10 if identity==1 else 5.8 if stage==0 else 4.2)*(0.5 if slowed else 1.0)
	attack_time = maxf(0,attack_time-delta)
	var stride := sin(phase)*(0.53 if walking else 0.025)
	var lunge := sin((1-attack_time/0.42)*PI) if attack_time>0 else 0.0
	leg_l.rotation.x = stride
	leg_r.rotation.x = -stride
	rig.position.y = absf(sin(phase))*0.045 if walking else sin(phase)*0.012
	if stage==0:
		rear_legs[0].rotation.x = -stride
		rear_legs[1].rotation.x = stride
		head.rotation.x = -lunge*0.28
		jaw.rotation.x = 0.16+lunge*0.72
		tail.rotation.y = sin(phase*0.6)*0.3
		rig.rotation.x = -lunge*0.13
	else:
		leg_r.rotation.x *= 0.8 if stage==1 else 1.0
		arm_l.rotation.x = (1.1 if stage==1 else 0.2)+stride*0.22+lunge*0.6
		arm_r.rotation.x = (0.8 if stage==1 else 0.15)-stride*0.20+lunge*1.6
		if stage==2 and identity==3:
			arm_r.rotation.x = 1.2+lunge*0.12
			weapon.rotation.x = -arm_r.rotation.x
		jaw.rotation.x = lunge*0.6
		head.rotation.z = sin(phase*0.45)*0.05

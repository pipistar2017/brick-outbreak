extends Node3D
## Three original brick dioramas. Decoration stays outside the traversable battlefield.
const Parts = preload("res://hero_model.gd")
var stage := 0
var materials: Dictionary = {}
var rng := RandomNumberGenerator.new()
var landmark_count := 0

func surface(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.95
		materials[color] = m
	return materials[color]

func block(pos: Vector3, size: Vector3, color: Color, angle := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = surface(color)
	mesh.position = pos
	mesh.rotation.y = angle
	add_child(mesh)
	return mesh

func orb(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1
	shape.radial_segments = 10
	shape.rings = 5
	mesh.mesh = shape
	mesh.scale = size
	mesh.position = pos
	mesh.material_override = surface(color)
	add_child(mesh)

func build(index: int) -> void:
	stage = index
	name = ["Savanna","PyramidNecropolis","GreatWallFortress"][stage]
	rng.seed = 8621+index*103
	var ground: Color = [Color("a58c4e"),Color("cfac72"),Color("686e65")][stage]
	block(Vector3(0,-0.56,0),Vector3(49,1,49),ground)
	# Subtle coloured patches in grass/sand, regular stone courses on the fortress.
	for x in range(-12,12):
		for z in range(-12,12):
			var tone := rng.randi_range(0,3)
			var palette: Array = [Color("aa9457"),Color("b09a5f"),Color("a28c51"),Color("b6a267")]
			if stage==1: palette = [Color("d5b57c"),Color("d9bb84"),Color("d0b078"),Color("d3b27a")]
			if stage==2: palette = [Color("788077"),Color("737a72"),Color("80857b"),Color("6f766e")]
			block(Vector3(x*2+1,-0.014,z*2+1),Vector3(1.96 if stage==2 else 2,0.028,1.96 if stage==2 else 2),palette[tone])
	if stage==0: savanna()
	elif stage==1: egypt()
	else: great_wall()
	merge_static()

func outside_battlefield(pos: Vector3, margin: float) -> Vector3:
	var result := pos
	if absf(result.x)<margin and absf(result.z)<margin:
		if absf(result.x)>absf(result.z):
			result.x = (1 if result.x>=0 else -1)*margin
		else:
			result.z = (1 if result.z>=0 else -1)*margin
	return result

func acacia(pos: Vector3, scale_factor: float) -> void:
	landmark_count += 1
	var bark := Color("6d5438")
	var leaf := Color("607a43")
	block(pos+Vector3(0,2.0,0)*scale_factor,Vector3(0.65,4.0,0.65)*scale_factor,bark,0.2)
	for side in [-1,1]:
		var branch := block(pos+Vector3(side*0.8,3.65,0)*scale_factor,Vector3(0.32,2.5,0.35)*scale_factor,bark)
		branch.rotation.z = side*-0.7
	orb(pos+Vector3(0,5.0,0)*scale_factor,Vector3(7.8,1.6,4.8)*scale_factor,leaf)
	orb(pos+Vector3(-2,4.65,0.6)*scale_factor,Vector3(4.8,1.5,4.7)*scale_factor,leaf.lightened(0.08))
	orb(pos+Vector3(2.6,5.0,-0.4)*scale_factor,Vector3(4.6,1.3,4.4)*scale_factor,leaf.darkened(0.1))

func savanna() -> void:
	block(Vector3(0,-0.66,0),Vector3(260,0.3,260),Color("b69a5f"))
	for i in range(24):
		var z := -23+i*2.0
		block(Vector3(sin(z*0.13)*2,0.006,z),Vector3(5,0.02,2.05),Color("bea674"))
	for i in range(18):
		var a := i*TAU/18
		var radius := rng.randf_range(28,43)
		acacia(outside_battlefield(Vector3(cos(a)*radius,0,sin(a)*radius),31.5),rng.randf_range(0.8,1.5))
	for i in range(100):
		var a := rng.randf()*TAU
		var radius := rng.randf_range(25,58)
		var pos := outside_battlefield(Vector3(cos(a)*radius,0,sin(a)*radius),24.8)
		for j in range(3):
			var tuft := block(pos+Vector3((j-1)*0.17,0.35,0),Vector3(0.09,0.7,0.24),Color("d1b76a"))
			tuft.rotation.z = (j-1)*0.3
	for i in range(12):
		var a := i*TAU/12
		var pos := outside_battlefield(Vector3(cos(a)*25,-0.05,sin(a)*25),25.5)
		orb(pos,Vector3(2.0,1.3,1.7),Color("81745a"))
	for i in range(16):
		var a := i*TAU/16
		orb(Vector3(cos(a)*91,0,sin(a)*91),Vector3(30,13+rng.randf()*11,26),Color("b2a078"))
	# Traversable perimeter marked by low stones, with no invisible central obstacles.
	for side in [-1,1]:
		for i in range(24):
			block(Vector3(side*23.8,0.12,-23+i*2),Vector3(0.5,0.26,0.55),Color("d9bf83"))
			block(Vector3(-23+i*2,0.12,side*23.8),Vector3(0.5,0.26,0.55),Color("d9bf83"))

func pyramid(pos: Vector3, width: float, height: float) -> void:
	landmark_count += 1
	for i in range(24):
		var t := float(i)/24
		block(pos+Vector3(0,(i+0.5)*height/24,0),Vector3(width*(1-t),height/24,width*(1-t)),Color("c99b58") if i%3==0 else Color("dab478"))
	block(pos+Vector3(0,1.4,width/2+0.05),Vector3(2.7,2.8,0.22),Color("574b3c"))

func obelisk(pos: Vector3) -> void:
	landmark_count += 1
	block(pos+Vector3(0,0.35,0),Vector3(2.0,0.70,2.0),Color("9c8055"))
	block(pos+Vector3(0,3.3,0),Vector3(0.95,6.0,0.95),Color("d6b275"))
	for i in range(5):
		block(pos+Vector3(0,1.4+i*0.85,-0.49),Vector3(0.36,0.24,0.025),Color("8b754d"))
	for i in range(5):
		block(pos+Vector3(0,6.35+i*0.15,0),Vector3(0.95-i*0.17,0.16,0.95-i*0.17),Color("d8b577"))

func egypt() -> void:
	block(Vector3(0,-0.70,0),Vector3(260,0.3,260),Color("ccab74"))
	pyramid(Vector3(0,-0.25,-55),31,16)
	pyramid(Vector3(-39,-0.25,-42),25,13)
	pyramid(Vector3(39,-0.25,-65),36,17)
	for z in range(-11,12):
		for x in range(-2,2):
			block(Vector3(x*1.7+0.85,0.022,z*2.1),Vector3(1.63,0.06,2.0),Color("b79a69") if (x+z)%2==0 else Color("c2a574"))
	for x in [-26,26]:
		for z in [-22,-8,9,23]:
			obelisk(Vector3(x,0,z))
	for x in [-12,12]:
		obelisk(Vector3(x,0,-26))
	for i in range(14):
		var a := i*TAU/14
		orb(Vector3(cos(a)*86,-1,sin(a)*86),Vector3(35,11,27),Color("d7b984"))
	for side in [-1,1]:
		for i in range(12):
			block(Vector3(side*23.7,0.28,-22+i*4),Vector3(0.75,0.55,1.2),Color("a68d63"))
		# Tomb gate pillars frame the entry to the necropolis.
		block(Vector3(side*7,3.5,27),Vector3(3,7,3),Color("b39460"))
		block(Vector3(side*7,6.0,27),Vector3(3.3,0.55,3.3),Color("4c7779"))
	block(Vector3(0,7.1,27),Vector3(17,1.2,3.4),Color("bfa36f"))

func battlement(pos: Vector3, along_x: bool, length: int) -> void:
	var stone := Color("626e69")
	block(pos+Vector3(0,0.45,0),Vector3(length,0.9,0.70) if along_x else Vector3(0.70,0.9,length),stone)
	for i in range(length/2):
		var shift := -length/2.0+1+i*2
		block(pos+Vector3(shift if along_x else 0,1.23,0 if along_x else shift),Vector3(0.96,0.70,0.92),stone.lightened(0.1))

func tower(pos: Vector3) -> void:
	landmark_count += 1
	var stone := Color("778077")
	block(pos+Vector3(0,2,0),Vector3(6.2,5,6.2),stone)
	for side in [-1,1]:
		block(pos+Vector3(side*3.13,2.6,0),Vector3(0.03,1.5,1.0),Color("343f3c"))
		block(pos+Vector3(0,2.6,side*3.13),Vector3(1.0,1.5,0.03),Color("343f3c"))
	for i in range(5):
		block(pos+Vector3(0,4.6+i*0.30,0),Vector3(8.0-i*0.95,0.32,7.8-i*0.9),Color("3e6258"))
	block(pos+Vector3(0,6.15,0),Vector3(4.2,0.25,0.3),Color("d2b27a"))
	for side in [-1,1]:
		block(pos+Vector3(side*1.7,6.22,0),Vector3(0.4,0.5,0.4),Color("c3a474"))

func great_wall() -> void:
	block(Vector3(0,-9,0),Vector3(280,0.5,280),Color("697c64"))
	block(Vector3(0,-3.7,0),Vector3(49,7,49),Color("535f59"))
	for side in [-1,1]:
		battlement(Vector3(side*23.4,0,0),false,48)
		battlement(Vector3(0,0,side*23.4),true,48)
		for other in [-1,1]:
			tower(Vector3(side*27,0,other*27))
	for i in range(11):
		var x := -90+i*18.0
		var z := -54+sin(i*0.85)*9
		block(Vector3(x,-2,z),Vector3(19,8,5),Color("64756c"))
		battlement(Vector3(x,2,z),true,18)
		if i%3==0: tower(Vector3(x,2,z))
	for i in range(22):
		var a := i*TAU/22
		var radius := rng.randf_range(68,117)
		orb(Vector3(cos(a)*radius,-5,sin(a)*radius),Vector3(32,25+rng.randf()*27,30),Color("6f8978") if i%2==0 else Color("819888"))
	for side in [-1,1]:
		for z in [-16,-6,6,16]:
			var pos := Vector3(side*22.5,0,z)
			block(pos+Vector3(0,2.5,0),Vector3(0.12,5,0.12),Color("6b503a"))
			block(pos+Vector3(side*-0.65,4.0,0),Vector3(1.25,1.6,0.07),Color("9d4c3a"))
	for i in range(12):
		block(Vector3(-22+i*4,0.015,0),Vector3(3.9,0.04,1.1),Color("aaa58c"))

func merge_static() -> void:
	var groups: Dictionary = {}
	for child in get_children():
		if not child is MeshInstance3D: continue
		var m: Material = child.material_override
		var key := m.get_instance_id()
		if not groups.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"tool":tool,"material":m}
		groups[key].tool.append_from(child.mesh,0,child.transform)
		remove_child(child)
		child.free()
	for data in groups.values():
		var mesh := MeshInstance3D.new()
		mesh.mesh = data.tool.commit()
		mesh.material_override = data.material
		add_child(mesh)

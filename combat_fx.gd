extends Node3D
## CPU-updated, bounded effects: deliberately independent from wall-clock tweens.
## The owner advances this only during combat, so pause/upgrade freezes every effect.
const LIMIT := 240
var active: Array = []
var created := 0

func tint(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color,alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m

func mesh(parent: Node3D, shape: Mesh, color: Color, alpha := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = tint(color,alpha)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func add_effect(node: Node3D, life: float, mode := "fade", data := {}) -> Dictionary:
	while active.size()>=LIMIT:
		active.pop_front().node.queue_free()
	add_child(node)
	var entry := {"node":node,"life":life,"age":0.0,"mode":mode,"base":node.scale,"origin":node.position}
	entry.merge(data,true)
	active.append(entry)
	created += 1
	return entry

func clear() -> void:
	for e in active:
		e.node.queue_free()
	active.clear()

func arc_shape(inner: float, outer: float, start: float, sweep: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(12,int(absf(sweep)*14))
	for i in range(segments):
		var a := start+sweep*i/segments
		var b := start+sweep*(i+1)/segments
		var v0 := Vector3(sin(a)*inner,0,-cos(a)*inner)
		var v1 := Vector3(sin(a)*outer,0,-cos(a)*outer)
		var v2 := Vector3(sin(b)*inner,0,-cos(b)*inner)
		var v3 := Vector3(sin(b)*outer,0,-cos(b)*outer)
		for v in [v0,v2,v1,v1,v2,v3]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func slash(pos: Vector3, yaw: float, radius: float, color: Color, full := false) -> void:
	var root := Node3D.new()
	root.position = pos+Vector3(0,0.85,0)
	root.rotation.y = yaw
	var sweep := TAU if full else PI*0.85
	mesh(root,arc_shape(radius*0.70,radius,-sweep/2,sweep),color,0.62)
	var edge := mesh(root,arc_shape(radius*0.96,radius*1.035,-sweep/2,sweep),Color("effff6"),0.95)
	edge.position.y = 0.025
	add_effect(root,0.52 if full else 0.32,"slash",{"sweep":1.6 if full else 0.65})

func wave(pos: Vector3, radius: float, color: Color, life := 0.65, start_scale := 0.15) -> void:
	var root := Node3D.new()
	root.position = pos+Vector3(0,0.12,0)
	mesh(root,arc_shape(radius*0.94,radius,0,TAU),color,0.9)
	var core := mesh(root,arc_shape(radius*0.97,radius*0.985,0,TAU),Color.WHITE,0.8)
	core.position.y = 0.015
	add_effect(root,life,"wave",{"start_scale":start_scale})

func beam(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> MeshInstance3D:
	var delta := end-start
	var shape := CylinderMesh.new()
	shape.top_radius = width
	shape.bottom_radius = width
	shape.height = maxf(0.01,delta.length())
	shape.radial_segments = 6
	var line := mesh(parent,shape,color)
	line.position = (start+end)*0.5
	if delta.length()>0.01:
		line.quaternion = Quaternion(Vector3.UP,delta.normalized())
	return line

func muzzle(pos: Vector3, forward: Vector3, color: Color, strong := false) -> void:
	var root := Node3D.new()
	root.position = pos
	var sphere := SphereMesh.new()
	sphere.radius = 0.28 if strong else 0.20
	sphere.height = sphere.radius*2
	mesh(root,sphere,Color("fff3c2"))
	beam(root,Vector3.ZERO,forward*(0.95 if strong else 0.65),0.07,color)
	for i in range(4):
		var v := Vector3(cos(i*PI/2),sin(i*PI/2),0)*0.4
		beam(root,-v*0.2,v,0.025,color)
	add_effect(root,0.16,"shrink")

func bolt(start: Vector3, end: Vector3, color: Color, duration: float, frost := false) -> Dictionary:
	var root := Node3D.new()
	root.position = start
	if start.distance_to(end)>0.01:
		root.look_at_from_position(start,end)
	if frost:
		var prism := PrismMesh.new()
		prism.size = Vector3(0.42,0.85,0.38)
		var shard := mesh(root,prism,color)
		shard.rotation.x = PI/2
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.30
		mesh(root,sphere,Color("fff5c3"))
	var halo := SphereMesh.new()
	halo.radius = 0.29 if frost else 0.23
	halo.height = halo.radius*2
	mesh(root,halo,color,0.28)
	var core := SphereMesh.new()
	core.radius = 0.10
	core.height = 0.20
	mesh(root,core,Color.WHITE)
	beam(root,Vector3(0,0,0.1),Vector3(0,0,1.45 if not frost else 1.0),0.07,color)
	beam(root,Vector3(0,0,0.05),Vector3(0,0,0.75),0.025,Color.WHITE)
	return add_effect(root,duration,"bolt",{"start":start,"end":end,"travel":duration})

func impact(pos: Vector3, color: Color, heavy := false) -> void:
	var root := Node3D.new()
	root.position = pos+Vector3(0,1.05,0)
	for i in range(7 if heavy else 4):
		var angle := TAU*i/(7.0 if heavy else 4.0)
		var v := Vector3(cos(angle),0.35+sin(angle*2)*0.3,sin(angle))
		beam(root,v*0.12,v*(0.8 if heavy else 0.4),0.035,color)
	add_effect(root,0.26,"burst")
	wave(pos,1.1 if heavy else 0.48,color,0.3)

func number(pos: Vector3, amount: float, color: Color, big := false) -> void:
	var text := Label3D.new()
	text.text = str(roundi(amount))
	text.font = load("res://assets/chinese.otf")
	text.font_size = 72 if big else 56
	text.pixel_size = 0.01
	text.outline_size = 14
	text.modulate = color
	text.outline_modulate = Color("14212d")
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.no_depth_test = true
	text.position = pos+Vector3(randf_range(-0.2,0.2),2.35,0)
	add_effect(text,0.8,"number")

func shards(pos: Vector3, color: Color, count := 6, frost := false) -> void:
	for i in range(count):
		var root := Node3D.new()
		root.position = pos+Vector3(0,0.3,0)
		var shape: Mesh
		if frost:
			var prism := PrismMesh.new()
			prism.size = Vector3(0.20,0.65,0.22)
			shape = prism
		else:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE*0.17
			shape = cube
		mesh(root,shape,color)
		var angle := TAU*i/count
		add_effect(root,0.6,"debris",{"velocity":Vector3(cos(angle)*2,2.5+randf(),sin(angle)*2)})

func frost_field(pos: Vector3, radius: float, large := false) -> void:
	wave(pos,radius,Color("77e9ff"),0.9)
	wave(pos,radius*0.75,Color("c4f8ff"),0.65)
	var root := Node3D.new()
	root.position = pos
	var count := 16 if large else 10
	for i in range(count):
		var angle := TAU*i/count
		var prism := PrismMesh.new()
		prism.size = Vector3(0.30,1.5 if large else 0.85,0.28)
		var n := mesh(root,prism,Color("9beaff"),0.85)
		n.position = Vector3(sin(angle)*radius*0.75,prism.size.y*0.5,-cos(angle)*radius*0.75)
		n.rotation.z = sin(angle)*0.28
		beam(root,Vector3(0,0.06,0),Vector3(sin(angle)*radius,0.06,-cos(angle)*radius),0.018,Color("7de0ff"))
	add_effect(root,1.0,"ice")

func explosion(pos: Vector3, radius: float) -> void:
	wave(pos,radius,Color("ff923e"),0.75)
	var root := Node3D.new()
	root.position = pos+Vector3(0,0.55,0)
	for i in range(6):
		var sphere := SphereMesh.new()
		sphere.radius = 0.38+i*0.035
		sphere.height = sphere.radius*2
		var n := mesh(root,sphere,Color("ffc969") if i%2==0 else Color("ff643b"),0.85)
		n.position = Vector3(sin(i*TAU/6)*1.0,0.25+float(i%2)*0.3,cos(i*TAU/6)*1.0)
	add_effect(root,0.48,"burst")
	shards(pos,Color("ffc77c"),10)

func charge(start: Vector3, end: Vector3, color: Color) -> void:
	var root := Node3D.new()
	beam(root,start+Vector3(0,0.3,0),end+Vector3(0,0.3,0),0.22,color)
	beam(root,start+Vector3(0,0.3,0),end+Vector3(0,0.3,0),0.055,Color.WHITE)
	for i in range(4):
		var shape := BoxMesh.new()
		shape.size = Vector3(0.7,1.2,0.45)
		var ghost := mesh(root,shape,color,0.28)
		ghost.position = start.lerp(end,i/4.0)+Vector3(0,1.0,0)
	add_effect(root,0.45,"fade")
	wave(end,5.0,color,0.65)

func aura(target: Node3D, color: Color, life: float) -> void:
	var root := Node3D.new()
	mesh(root,arc_shape(0.8,0.88,0,TAU),color,0.8)
	for i in range(4):
		beam(root,Vector3(sin(i*PI/2)*0.8,0.1,cos(i*PI/2)*0.8),Vector3(sin(i*PI/2)*0.8,1.2,cos(i*PI/2)*0.8),0.03,color)
	add_effect(root,life,"aura",{"target":target})

func fade_children(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		if not node.has_meta("opacity"):
			node.set_meta("opacity",node.material_override.albedo_color.a)
		node.material_override.albedo_color.a = node.get_meta("opacity")*alpha
	elif node is Label3D:
		node.modulate.a = alpha
	for child in node.get_children():
		fade_children(child,alpha)

func update(delta: float) -> void:
	for i in range(active.size()-1,-1,-1):
		var e: Dictionary = active[i]
		e.age += delta
		var t := clampf(e.age/e.life,0,1)
		var node: Node3D = e.node
		if e.mode in ["bolt","meteor"]:
			node.position = e.start.lerp(e.end,clampf(e.age/e.travel,0,1))
			if e.mode=="bolt" and node.position.distance_to(e.end)>0.01:
				node.look_at(e.end)
		elif e.mode=="dragon":
			node.position = e.origin+e.heading*e.distance*t
			node.scale = e.base*lerpf(0.75,1.2,minf(1,t*4))
		elif e.mode=="wave":
			node.scale = e.base*lerpf(e.start_scale,1,t)
		elif e.mode=="slash":
			node.rotate_y(delta*e.sweep)
			node.scale = e.base*lerpf(0.8,1.05,t)
		elif e.mode=="number":
			node.position.y = e.origin.y+t*1.45
		elif e.mode=="debris":
			node.position += e.velocity*delta
			e.velocity.y -= 7*delta
			node.rotate_x(delta*5)
		elif e.mode=="burst":
			node.scale = e.base*lerpf(0.5,1.9,t)
		elif e.mode=="shrink":
			node.scale = e.base*(1-t*0.8)
		elif e.mode=="ice":
			node.scale.y = minf(1,t*6)*(1-maxf(0,(t-0.65)/0.35)*0.5)
		elif e.mode=="aura":
			if is_instance_valid(e.target):
				node.position = e.target.position+Vector3(0,0.1,0)
				node.rotation.y += delta*1.6
				node.scale = e.base*(1+sin(e.age*12)*0.07)
		fade_children(node,1.0 if e.mode in ["bolt","meteor"] else 1-clampf((t-0.45)/0.55,0,1))
		if t>=1:
			node.queue_free()
			active.remove_at(i)

func dragon_cut(pos: Vector3, heading: Vector3, length: float) -> void:
	var trail := Node3D.new()
	trail.position = pos+Vector3(0,0.18,0)
	beam(trail,Vector3.ZERO,heading*length,0.22,Color("3ee5a0"))
	beam(trail,Vector3.ZERO,heading*length,0.055,Color("efffe0"))
	add_effect(trail,0.85,"fade")
	var dragon := Node3D.new()
	dragon.position = pos+Vector3(0,1.3,0)
	dragon.rotation.y = atan2(-heading.x,-heading.z)
	var spine: Array[Vector3] = []
	for i in range(19):
		var p := Vector3(sin(i*0.70)*0.65,cos(i*0.55)*0.25,-i*0.36)
		spine.append(p)
		if i>0:
			beam(dragon,spine[i-1],p,0.15+i*0.022,Color("27d690"))
			beam(dragon,spine[i-1]+Vector3(0,0.14,0),p+Vector3(0,0.14,0),0.055,Color("d6ffa8"))
		if i>3 and i%2==0:
			beam(dragon,p,p+Vector3(0,0.70,0.2),0.10,Color("d5c36e"))
		if i in [8,14]:
			for side in [-1,1]:
				var foot := p+Vector3(side*1.0,-0.48,-0.2)
				beam(dragon,p,foot,0.13,Color("27d690"))
				for j in range(3): beam(dragon,foot,foot+Vector3(side*0.30,-0.12,-0.30-j*0.12),0.045,Color("f0db8e"))
	var head := Node3D.new()
	head.position = spine.back()+Vector3(0,0,-0.48)
	dragon.add_child(head)
	var skull := BoxMesh.new()
	skull.size = Vector3(1.15,0.85,1.25)
	mesh(head,skull,Color("33f0a0"))
	var snout := BoxMesh.new()
	snout.size = Vector3(0.8,0.36,1.1)
	mesh(head,snout,Color("95f9a8")).position = Vector3(0,-0.17,-0.8)
	for side in [-1,1]:
		var eye := BoxMesh.new()
		eye.size = Vector3(0.20,0.18,0.09)
		mesh(head,eye,Color("fff4a0")).position = Vector3(side*0.43,0.15,-0.65)
		beam(head,Vector3(side*0.40,0.32,0.1),Vector3(side*0.9,1.15,0.62),0.10,Color("f4d782"))
		beam(head,Vector3(side*0.39,-0.12,-1.2),Vector3(side*1.15,-0.05,-1.52),0.045,Color("e4f7a4"))
		beam(head,Vector3(side*0.29,-0.30,-1.14),Vector3(side*0.29,-0.62,-1.14),0.06,Color("fff9d1"))
	add_effect(dragon,1.15,"dragon",{"heading":heading,"distance":minf(length*0.20,10.0)})
	wave(pos,2.2,Color("5ef0a0"),0.5)

func meteor_rain(pos: Vector3, radius: float, travel: float) -> void:
	wave(pos,radius,Color("ffac50"),travel,1.0)
	for i in range(13):
		var a := i*2.39996
		var r := sqrt(float(i)/12)*radius*0.90
		var end := pos+Vector3(sin(a)*r,0.4,cos(a)*r)
		var start := end+Vector3(-2.5,11+float(i%3),1.0)
		var ball := Node3D.new()
		ball.position = start
		var shape := SphereMesh.new()
		shape.radius = 0.40+float(i%3)*0.09
		shape.height = shape.radius*2
		mesh(ball,shape,Color("ff7737"))
		var core := SphereMesh.new()
		core.radius = shape.radius*0.65
		core.height = core.radius*2
		mesh(ball,core,Color("fff0a4"))
		beam(ball,Vector3.ZERO,Vector3(-1.1,2.6,0.45),0.22,Color("ffb447"))
		beam(ball,Vector3.ZERO,Vector3(-0.8,1.9,0.32),0.08,Color("fff2b9"))
		add_effect(ball,travel,"meteor",{"start":start,"end":end,"travel":travel})

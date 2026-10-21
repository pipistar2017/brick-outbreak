extends Node3D

const HEROES = [
	{"name":"青龙战将", "role":"近战横扫 · 220 血量 · 普攻 30", "hp":220.0,"damage":30.0,"rate":0.8,"color":Color("21c78b"),"q":6.0,"e":14.0},
	{"name":"赤焰游侠", "role":"远程速射 · 140 血量 · 普攻 18", "hp":140.0,"damage":18.0,"rate":0.35,"color":Color("ff884b"),"q":5.0,"e":16.0},
	{"name":"寒霜术士", "role":"冰霜控制 · 160 血量 · 普攻 24", "hp":160.0,"damage":24.0,"rate":0.7,"color":Color("64c9ff"),"q":7.0,"e":16.0}
]
const ENEMIES = [
	{"hp":60.0,"damage":10.0,"speed":1.35,"color":Color("7caa66"),"scale":1.0},
	{"hp":40.0,"damage":8.0,"speed":2.8,"color":Color("b4ce53"),"scale":0.8},
	{"hp":240.0,"damage":25.0,"speed":0.8,"color":Color("977892"),"scale":1.45},
	{"hp":80.0,"damage":15.0,"speed":1.0,"color":Color("dfaa54"),"scale":1.0},
	{"hp":1800.0,"damage":30.0,"speed":1.15,"color":Color("e55772"),"scale":2.5}
]
var world: Node3D
var player: Node3D
var camera: Camera3D
var ui: CanvasLayer
var hud: Label
var status: Label
var hp_bar: ProgressBar
var menu: Control
var enemies: Array = []
var effects: Array = []
var bullets: Array = []
var hero := 0
var hp := 220.0
var max_hp := 220.0
var elapsed := 0.0
var spawn_clock := 0.0
var attack_clock := 0.0
var q_clock := 0.0
var e_clock := 0.0
var invuln := 0.0
var dash_clock := 0.0
var buff := 0.0
var kills := 0
var xp := 0
var level := 1
var damage_mult := 1.0
var playing := false
var choosing := false
var paused := false
var boss_spawned := false
var direction := Vector3.FORWARD
var preview := false
var preview_frames := 0
var auto_test := false
var test_steps := 0
var sound: AudioStreamPlayer
var synth: AudioStreamGeneratorPlayback

func material(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func figure(color: Color, armored: bool) -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(0,1.0,0), Vector3(0.62,0.65,0.38),color)
	box(root, Vector3(0,1.58,0), Vector3(0.45,0.45,0.43),Color("e8c79b") if armored else color.lightened(0.2))
	for x in [-0.19,0.19]:
		box(root,Vector3(x,0.39,0),Vector3(0.27,0.55,0.32),Color("27344b"))
		box(root,Vector3(x,0.1,-0.06),Vector3(0.30,0.18,0.44),Color("172131"))
	for x in [-0.46,0.46]:
		box(root,Vector3(x,0.98,0),Vector3(0.23,0.65,0.28),color.darkened(0.15))
	for x in [-0.11,0.11]:
		box(root,Vector3(x,1.62,-0.224),Vector3(0.065,0.065,0.02),Color("10131c"))
	if armored:
		box(root,Vector3(0,1.84,0),Vector3(0.55,0.14,0.48),Color("edc76a"))
		box(root,Vector3(0,2.0,0.06),Vector3(0.12,0.25,0.2),color)
		box(root,Vector3(0,0.95,0.28),Vector3(0.68,0.95,0.08),Color("ba4051"))
		if hero == 1:
			box(root,Vector3(0.54,1.1,-0.4),Vector3(0.20,0.22,0.85),Color("d7b66a"))
			box(root,Vector3(0.54,1.1,-0.85),Vector3(0.13,0.13,0.15),color)
		else:
			box(root,Vector3(0.58,1.1,-0.3),Vector3(0.08,0.95,0.12),Color("edc76a"))
			box(root,Vector3(0.58,1.65,-0.3),Vector3(0.22,0.55,0.12),color.lightened(0.25))
		if hero == 0:
			box(root,Vector3(0,1.38,-0.24),Vector3(0.26,0.25,0.06),Color("162a27"))
			for x in [-0.25,0.25]:
				box(root,Vector3(x,1.68,0),Vector3(0.09,0.45,0.5),Color("edc76a"))
	return root

func _ready() -> void:
	auto_test = "--smoke-test" in OS.get_cmdline_user_args()
	world = Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101c2b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b0c5e0")
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color("ffe5b0")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	box(world,Vector3(0,-0.3,0),Vector3(48,0.5,48),Color("293949"))
	for x in range(-6,7):
		for z in range(-6,7):
			box(world,Vector3(x*3.5,-0.025,z*3.5),Vector3(3.35,0.05,3.35),Color("344757") if (x+z)%2==0 else Color("304150"))
	for i in range(36):
		var angle := i*TAU/36.0
		var pos := Vector3(cos(angle)*23.5,0.5,sin(angle)*23.5)
		box(world,pos,Vector3(1.5,1.2,1.5),Color("4b596b"))
		box(world,pos+Vector3(0,0.85,0),Vector3(0.5,0.5,0.5),Color("c2a261"))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	add_child(camera)
	camera.position = Vector3(0,24,20)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var theme := Theme.new()
	theme.default_font = load("res://assets/chinese.otf")
	ThemeDB.fallback_font = theme.default_font
	ui = CanvasLayer.new()
	add_child(ui)
	for rect in [Rect2(16,16,850,78),Rect2(16,700,1030,80)]:
		var plate := ColorRect.new()
		plate.position = rect.position
		plate.size = rect.size
		plate.color = Color(0.03,0.07,0.11,0.8)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(plate)
	hud = label(ui,"",Vector2(32,24),23)
	status = label(ui,"",Vector2(32,710),18)
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(32,65)
	hp_bar.size = Vector2(290,15)
	hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("35d497")
	fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill",fill)
	ui.add_child(hp_bar)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.12
	sound = AudioStreamPlayer.new()
	sound.stream = gen
	add_child(sound)
	if not auto_test:
		sound.play()
		synth = sound.get_stream_playback()
	show_menu()
	preview = "--preview" in OS.get_cmdline_user_args()
	if preview:
		start_game(0)
		for i in range(16):
			var e := spawn_enemy(i%4)
			e.node.position = Vector3(cos(i*TAU/16.0)*8,0,sin(i*TAU/16.0)*8)
	if auto_test:
		start_game(0)

func label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("e5edf7"))
	parent.add_child(l)
	return l

func panel(title: String, subtitle: String) -> VBoxContainer:
	if is_instance_valid(menu):
		menu.queue_free()
	menu = ColorRect.new()
	menu.color = Color(0.025,0.045,0.08,0.94)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var col := VBoxContainer.new()
	col.position = Vector2(180,140)
	col.custom_minimum_size = Vector2(920,0)
	col.add_theme_constant_override("separation",18)
	menu.add_child(col)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size",48)
	col.add_child(heading)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size",18)
	col.add_child(sub)
	return col

func button(parent: Node, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(920,64)
	b.add_theme_font_size_override("font_size",19)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("173144")
	style.border_color = Color("367765")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("265846")
	b.add_theme_stylebox_override("hover",hover)
	b.pressed.connect(callback)
	parent.add_child(b)

func show_menu() -> void:
	playing = false
	var col := panel("积木 / 尸潮", "积木英雄，迎战尸潮。\n首领在 02:30 出现 · 在 04:00 前击败它即可获胜")
	for i in range(3):
		var h: Dictionary = HEROES[i]
		button(col,"%s    /    %s" % [h.name,h.role],start_game.bind(i))
	var tip := Label.new()
	tip.text = "WASD / 方向键移动    Q / E 技能    空格闪避    Esc 暂停\n自动攻击 · 击杀升级三选一 · 离线单机 · 先点击任一英雄开始"
	col.add_child(tip)

func start_game(index: int) -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	for e in effects:
		e.node.queue_free()
	effects.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	if is_instance_valid(player):
		player.queue_free()
	hero = index
	max_hp = HEROES[hero].hp
	hp = max_hp
	elapsed = 0
	kills = 0
	xp = 0
	level = 1
	damage_mult = 1
	spawn_clock = 0
	attack_clock = 0
	q_clock = 0
	e_clock = 0
	buff = 0
	invuln = 0
	dash_clock = 0
	boss_spawned = false
	choosing = false
	paused = false
	player = figure(HEROES[hero].color,true)
	world.add_child(player)
	playing = true

func spawn_enemy(kind: int) -> Dictionary:
	var data: Dictionary = ENEMIES[kind]
	var node := figure(data.color,false)
	node.scale = Vector3.ONE*data.scale
	var angle := randf()*TAU
	node.position = player.position+Vector3(cos(angle),0,sin(angle))*17
	node.position.x = clampf(node.position.x,-21,21)
	node.position.z = clampf(node.position.z,-21,21)
	world.add_child(node)
	var health_bar := box(node,Vector3(0,2.2,0),Vector3(0.8,0.07,0.08),Color("e36b7e"))
	var e := {"node":node,"bar":health_bar,"kind":kind,"hp":data.hp,"cooldown":1.0,"slow":0.0}
	enemies.append(e)
	return e

func tone(freq: float) -> void:
	if synth == null:
		return
	var count := mini(synth.get_frames_available(),1600)
	for i in range(count):
		var sample := sin(TAU*freq*i/22050.0)*0.12*(1.0-float(i)/count)
		synth.push_frame(Vector2(sample,sample))

func ring(pos: Vector3, radius: float, color: Color) -> void:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	n.mesh = mesh
	var m := material(color,true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.4
	n.material_override = m
	n.position = pos+Vector3(0,0.12,0)
	world.add_child(n)
	effects.append({"node":n,"time":0.3})

func hurt(e: Dictionary, amount: float) -> void:
	e.hp -= amount
	e.bar.scale.x = maxf(0,e.hp/ENEMIES[e.kind].hp)
	if e.hp <= 0 and not e.get("dead",false):
		e.dead = true
		kills += 1
		xp += 1 if e.kind != 4 else 20
		ring(e.node.position,0.6,Color("e6cc80"))
		e.node.queue_free()
		if e.kind == 4:
			finish(true)

func damage_player(amount: float) -> void:
	if invuln > 0 or not playing:
		return
	hp -= amount
	invuln = 0.5
	ring(player.position,0.8,Color("ff4a65"))
	tone(120)
	if hp <= 0:
		finish(false)

func area_damage(radius: float, amount: float, slow := false) -> void:
	ring(player.position,radius,HEROES[hero].color)
	for e in enemies:
		if not e.get("dead",false) and e.node.position.distance_to(player.position) < radius:
			hurt(e,amount*damage_mult)
			if slow:
				e.slow = 3.0

func skill(which: int) -> void:
	if not playing or choosing:
		return
	if which == 0:
		if q_clock > 0:
			return
		q_clock = HEROES[hero].q
		area_damage(4.5 if hero==0 else 6.0,70.0 if hero==0 else 65.0 if hero==1 else 45.0,hero==2)
	else:
		if e_clock > 0:
			return
		e_clock = HEROES[hero].e
		if hero == 0:
			invuln = 1.0
			player.position += direction*6
			player.position.x = clampf(player.position.x,-21,21)
			player.position.z = clampf(player.position.z,-21,21)
			area_damage(5,120)
		elif hero == 1:
			buff = 5
		else:
			area_damage(8,120,true)
	tone(580)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and not choosing and is_instance_valid(player):
		if playing:
			playing = false
			var col := panel("已暂停", "调整呼吸，再战尸潮。")
			paused = true
			button(col,"继续战斗",resume_game)
			button(col,"返回选人",show_menu)
		elif paused:
			resume_game()
		return
	if not playing or choosing:
		return
	if event.keycode == KEY_Q:
		skill(0)
	if event.keycode == KEY_E:
		skill(1)
	if event.keycode == KEY_SPACE and dash_clock<=0:
		dash_clock = 3
		invuln = 0.45
		ring(player.position,1.2,HEROES[hero].color)
		player.position += direction*3

func resume_game() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	paused = false
	playing = true

func upgrade(choice: int) -> void:
	if choice == 0:
		damage_mult += 0.2
	elif choice == 1:
		max_hp += 40
		hp = minf(hp+65,max_hp)
	else:
		hp = minf(hp+100,max_hp)
		q_clock = 0
		e_clock = 0
	choosing = false
	if is_instance_valid(menu):
		menu.queue_free()

func finish(won: bool) -> void:
	playing = false
	var col := panel("黎明已至 · 胜利" if won else "英雄倒下 · 挑战失败", "%s · 击败 %d 只僵尸 · 等级 %d · %02d:%02d" % [HEROES[hero].name,kills,level,int(elapsed)/60,int(elapsed)%60])
	button(col,"再次挑战",start_game.bind(hero))
	button(col,"更换英雄",show_menu)

func _process(delta: float) -> void:
	if preview:
		preview_frames += 1
		if preview_frames == 90:
			get_viewport().get_texture().get_image().save_png("/workspace/brick-outbreak/dist/gameplay.png")
			get_tree().quit()
			return
	if auto_test:
		run_smoke_test()
		return
	if not playing or choosing:
		return
	step(delta)

func step(delta: float) -> void:
	elapsed += delta
	attack_clock -= delta
	q_clock = maxf(0,q_clock-delta)
	e_clock = maxf(0,e_clock-delta)
	invuln = maxf(0,invuln-delta)
	dash_clock = maxf(0,dash_clock-delta)
	buff = maxf(0,buff-delta)
	var movement := Vector3(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if movement.length()>0:
		direction = movement.normalized()
		player.position += direction*5.5*delta
		player.rotation.y = atan2(-direction.x,-direction.z)
	player.position.x = clampf(player.position.x,-21,21)
	player.position.z = clampf(player.position.z,-21,21)
	camera.position = player.position+Vector3(0,24,20)
	camera.look_at(player.position)
	spawn_clock -= delta
	if spawn_clock<=0 and enemies.size()<65:
		spawn_clock = maxf(0.28,1.3-elapsed/160)
		spawn_enemy(randi_range(0,mini(3,int(elapsed/25)) ))
	if elapsed>=150 and not boss_spawned:
		boss_spawned = true
		spawn_enemy(4)
	if elapsed>=240:
		finish(false)
	var nearest: Dictionary = {}
	var nearest_distance := 1000.0
	for e in enemies:
		if e.get("dead",false):
			continue
		var node: Node3D = e.node
		var data: Dictionary = ENEMIES[e.kind]
		var offset: Vector3 = player.position-node.position
		var distance := offset.length()
		if distance<nearest_distance:
			nearest = e
			nearest_distance = distance
		e.cooldown -= delta
		e.slow = maxf(0,e.slow-delta)
		var stop_distance := 8.0 if e.kind==3 else 1.0
		if distance>stop_distance:
			node.position += offset.normalized()*data.speed*delta*(0.5 if e.slow>0 else 1.0)
			for other in enemies:
				if other == e or other.get("dead",false):
					continue
				var apart: Vector3 = node.position-other.node.position
				if apart.length()>0.01 and apart.length()<0.7:
					node.position += apart.normalized()*delta*1.5
		if offset.length()>0.01:
			node.rotation.y = atan2(-offset.x,-offset.z)
		if distance < (12.0 if e.kind==3 else 1.5*data.scale) and e.cooldown<=0:
			e.cooldown = 2.5 if e.kind==3 else 1.5
			if e.kind==3:
				var b := box(world,node.position+Vector3(0,1,0),Vector3(0.3,0.3,0.3),Color("eacb53"))
				bullets.append({"node":b,"velocity":offset.normalized()*6,"time":3.0,"damage":data.damage})
			else:
				damage_player(data.damage)
	if not nearest.is_empty() and attack_clock<=0 and nearest_distance<(3.5 if hero==0 else 12.0):
		attack_clock = HEROES[hero].rate*(0.6 if buff>0 else 1.0)
		player.look_at(Vector3(nearest.node.position.x,0,nearest.node.position.z))
		if hero==0:
			area_damage(3.5,HEROES[hero].damage)
		else:
			ring(nearest.node.position,0.65,HEROES[hero].color)
			hurt(nearest,HEROES[hero].damage*damage_mult)
			if hero==2:
				nearest.slow = 1.0
		tone(330+hero*120)
	for b in bullets:
		b.time -= delta
		b.node.position += b.velocity*delta
		if b.node.position.distance_to(player.position+Vector3(0,1,0))<0.7:
			damage_player(b.damage)
			b.time = 0
	for i in range(bullets.size()-1,-1,-1):
		if bullets[i].time<=0:
			bullets[i].node.queue_free()
			bullets.remove_at(i)
	for i in range(enemies.size()-1,-1,-1):
		if enemies[i].get("dead",false):
			enemies.remove_at(i)
	for i in range(effects.size()-1,-1,-1):
		effects[i].time -= delta
		if effects[i].time<=0:
			effects[i].node.queue_free()
			effects.remove_at(i)
	if xp >= level*8 and playing and not auto_test and not preview:
		xp -= level*8
		level += 1
		choosing = true
		var col := panel("升级 · 等级 %02d" % level,"选择一项强化。选择期间战斗暂停。")
		button(col,"锋利积木    /    伤害增加 20% 基础值",upgrade.bind(0))
		button(col,"坚固装甲    /    血量上限增加 40，恢复 65 血量",upgrade.bind(1))
		button(col,"重整旗鼓    /    恢复 100 血量，立即刷新技能",upgrade.bind(2))
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hud.text = "%s    %d / %d 血量                 %02d:%02d    /    击败 %d    /    等级 %d" % [HEROES[hero].name,maxi(0,int(hp)),int(max_hp),int(elapsed)/60,int(elapsed)%60,kills,level]
	var names: Array = [["青龙横扫","破阵突击"],["爆裂弹","火力全开"],["冰霜新星","极寒爆发"]][hero]
	status.text = "Q %s  %s     E %s  %s     空格闪避  %s\nWASD 移动 · 自动攻击 · 击杀经验 %d / %d · 首领 02:30 出现 · 限时 04:00" % [names[0],"就绪" if q_clock<=0 else "%.1fs" % q_clock,names[1],"就绪" if e_clock<=0 else "%.1fs" % e_clock,"就绪" if dash_clock<=0 else "%.1fs" % dash_clock,xp,level*8]

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: "+description)
		get_tree().quit(1)
		assert(condition,description)
	print("PASS: "+description)

func run_smoke_test() -> void:
	if test_steps>0:
		return
	test_steps += 1
	for index in range(3):
		start_game(index)
		check(hp==HEROES[index].hp,"hero %d stats" % index)
		var e := spawn_enemy(0)
		e.node.position = Vector3(1,0,0)
		step(0.016)
		check(e.hp<60,"hero %d auto attack" % index)
		q_clock = 0
		skill(0)
		check(q_clock>0,"hero %d Q cooldown" % index)
		var target := spawn_enemy(2)
		target.node.position = player.position+Vector3(1,0,0)
		var previous_hp: float = target.hp
		skill(0)
		check(target.hp==previous_hp,"hero %d cannot bypass cooldown" % index)
		q_clock = 0
		skill(0)
		check(target.hp<previous_hp,"hero %d Q damage" % index)
		e_clock = 0
		skill(1)
		check(e_clock>0,"hero %d E cooldown" % index)
	start_game(0)
	var melee := spawn_enemy(0)
	melee.node.position = Vector3(1.2,0,0)
	melee.cooldown = 0
	step(0.01)
	check(hp==210,"melee enemy attacks")
	var spit := spawn_enemy(3)
	spit.node.position = Vector3(5,0,0)
	spit.cooldown = 0
	step(0.01)
	check(bullets.size()==1,"spitter launches projectile")
	start_game(0)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	_unhandled_key_input(key)
	check(paused and not playing,"pause stops combat")
	_unhandled_key_input(key)
	check(playing and not paused,"escape resumes combat")
	xp = 8
	auto_test = false
	step(0.01)
	auto_test = true
	check(choosing and level==2,"experience opens upgrade selection")
	upgrade(0)
	check(not choosing,"upgrade resumes combat")
	start_game(0)
	for kind in range(5):
		var e := spawn_enemy(kind)
		check(e.hp==ENEMIES[kind].hp,"enemy %d stats" % kind)
	var old_hp := hp
	damage_player(10)
	damage_player(10)
	check(hp==old_hp-10,"damage and invulnerability")
	upgrade(0)
	check(damage_mult>1,"damage upgrade")
	upgrade(1)
	check(max_hp==260,"health upgrade")
	var boss := enemies.back() as Dictionary
	hurt(boss,2000)
	check(not playing and kills==1,"boss victory")
	start_game(1)
	invuln = 0
	damage_player(1000)
	check(not playing,"defeat")
	start_game(2)
	check(playing and kills==0 and hp==160,"restart resets state")
	for i in range(600):
		invuln = 1
		step(0.1)
	check(enemies.size()>0 and elapsed>59,"60 second simulation")
	start_game(0)
	elapsed = 149.99
	step(0.02)
	check(boss_spawned and enemies.back().kind==4,"timed boss arrival")
	elapsed = 239.99
	step(0.02)
	check(not playing,"deadline ends run")
	print("SMOKE TEST COMPLETE")
	get_tree().quit(0)

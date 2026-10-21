extends Node3D

const HeroVisual = preload("res://hero_model.gd")
const CombatFX = preload("res://combat_fx.gd")
const ZombieVisual = preload("res://zombie_model.gd")

const HEROES = [
	{"name":"青龙战将", "role":"近战横扫 · 220 血量 · 普攻 30", "hp":220.0,"damage":30.0,"rate":0.8,"color":Color("21c78b"),"q":6.0,"e":14.0},
	{"name":"赤焰游侠", "role":"远程速射 · 140 血量 · 普攻 18", "hp":140.0,"damage":18.0,"rate":0.35,"color":Color("ff884b"),"q":5.0,"e":16.0},
	{"name":"寒霜术士", "role":"冰霜控制 · 160 血量 · 普攻 24", "hp":160.0,"damage":24.0,"rate":0.7,"color":Color("64c9ff"),"q":7.0,"e":16.0}
]
const ENEMIES = [
	{"hp":60.0,"damage":10.0,"speed":1.35,"color":Color("85997a"),"scale":1.0},
	{"hp":40.0,"damage":8.0,"speed":2.8,"color":Color("a0ab78"),"scale":0.8},
	{"hp":240.0,"damage":25.0,"speed":0.8,"color":Color("928a96"),"scale":1.45},
	{"hp":80.0,"damage":15.0,"speed":1.0,"color":Color("a2aa62"),"scale":1.0},
	{"hp":1800.0,"damage":30.0,"speed":1.15,"color":Color("687c65"),"scale":2.5}
]
var fx: Node3D
var shots: Array = []
var swings: Array = []
var skill_buttons: Array = []
var banner: Label
var banner_hint: Label
var banner_time := 0.0
var shake_strength := 0.0
var white_flash: StandardMaterial3D
var ice_overlay: StandardMaterial3D
var combat_preview := -1
var demo_tick := 0
var combat_demo := false
var world: Node3D
var player: Node3D
var camera: Camera3D
var ui: CanvasLayer
var hud: Label
var status: Label
var hp_bar: ProgressBar
var menu: Control
var enemies: Array = []
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
var portrait_rigs: Array = []
var zombie_preview := false
var menu_preview := false
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


func _ready() -> void:
	auto_test = "--smoke-test" in OS.get_cmdline_user_args()
	world = Node3D.new()
	add_child(world)
	fx = CombatFX.new()
	world.add_child(fx)
	white_flash = StandardMaterial3D.new()
	white_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white_flash.albedo_color = Color("fff1c9")
	ice_overlay = StandardMaterial3D.new()
	ice_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ice_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_overlay.albedo_color = Color(0.4,0.85,1.0,0.28)
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
	camera.size = 22
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
	banner = label(ui,"",Vector2(420,110),34)
	banner.add_theme_constant_override("outline_size",8)
	banner.add_theme_color_override("font_outline_color",Color("0e1c28"))
	banner_hint = label(ui,"",Vector2(420,157),18)
	banner_hint.add_theme_constant_override("outline_size",5)
	for i in range(2):
		var skill_button := Button.new()
		skill_button.position = Vector2(1060,640+i*72)
		skill_button.size = Vector2(200,62)
		skill_button.focus_mode = Control.FOCUS_NONE
		skill_button.add_theme_font_size_override("font_size",17)
		skill_button.pressed.connect(skill.bind(i))
		ui.add_child(skill_button)
		skill_buttons.append(skill_button)
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
	menu_preview = "--menu-preview" in OS.get_cmdline_user_args() or "--back-preview" in OS.get_cmdline_user_args()
	if "--back-preview" in OS.get_cmdline_user_args():
		for model in portrait_rigs:
			model.rotation.y = PI
	preview = "--preview" in OS.get_cmdline_user_args()
	if preview:
		start_game(0)
		for i in range(16):
			var e := spawn_enemy(i%4)
			e.node.position = Vector3(cos(i*TAU/16.0)*8,0,sin(i*TAU/16.0)*8)
	for i in range(3):
		if ("--combat-preview="+str(i)) in OS.get_cmdline_user_args():
			combat_preview = i
	if combat_preview>=0:
		start_game(combat_preview)
		attack_clock = 100
		for i in range(10):
			var e := spawn_enemy(2)
			e.node.position = Vector3(cos(i*TAU/10)*4.0,0,sin(i*TAU/10)*4.0)
			e.cooldown = 100
		spawn_clock = 100
		var target := spawn_enemy(2)
		target.node.position = Vector3(2,0,-2)
		target.cooldown = 100
		perform_attack(target)
		skill(0)
	zombie_preview = "--zombie-preview" in OS.get_cmdline_user_args() or "--zombie-back-preview" in OS.get_cmdline_user_args()
	if zombie_preview:
		show_zombie_gallery()
		if "--zombie-back-preview" in OS.get_cmdline_user_args():
			for model in portrait_rigs:
				model.rotation.y = PI
	combat_demo = "--combat-demo" in OS.get_cmdline_user_args()
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
	portrait_rigs.clear()
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
	paused = false
	choosing = false
	var col := panel("积木 / 尸潮", "武将集结 · 拖动模型可旋转查看 · 选择一位英雄出战")
	col.position = Vector2(60,28)
	col.custom_minimum_size = Vector2(1160,0)
	col.add_theme_constant_override("separation",12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	col.add_child(row)
	var descriptions := ["Q 青龙横扫 · 近身清场\nE 破阵突击 · 位移免伤", "Q 爆裂弹 · 范围打击\nE 火力全开 · 连续速射", "Q 冰霜新星 · 群体减速\nE 极寒爆发 · 冰霜爆发"]
	for i in range(3):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(376,0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101f30")
		style.border_color = HeroVisual.PALETTES[i].trim.darkened(0.15)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel",style)
		row.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation",9)
		card.add_child(body)
		make_portrait(body,i)
		for entry in [[HEROES[i].name,26],[HEROES[i].role,16],[descriptions[i],17]]:
			var text := Label.new()
			text.text = entry[0]
			text.add_theme_font_size_override("font_size",entry[1])
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(text)
		button(body,"选择出战",start_game.bind(i))
		body.get_child(body.get_child_count()-1).custom_minimum_size = Vector2(352,50)
	var tip := Label.new()
	tip.text = "WASD / 方向键移动    Q / E 技能    空格闪避    Esc 暂停\n首领 02:30 出现 · 在 04:00 前击败它 · 自动攻击，升级三选一"
	tip.add_theme_font_size_override("font_size",17)
	col.add_child(tip)
	var catalog := Button.new()
	catalog.text = "丧尸图鉴"
	catalog.position = Vector2(1000,50)
	catalog.size = Vector2(210,46)
	catalog.add_theme_font_size_override("font_size",20)
	catalog.pressed.connect(show_zombie_gallery)
	menu.add_child(catalog)

func show_zombie_gallery() -> void:
	playing = false
	paused = false
	choosing = false
	var col := panel("丧尸图鉴", "拖动模型可旋转查看 · 五类敌人的外形与能力")
	col.position = Vector2(60,28)
	col.custom_minimum_size = Vector2(1160,0)
	col.add_theme_constant_override("separation",12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",15)
	col.add_child(row)
	var names := ["蹒跚丧尸","狂奔丧尸","重甲丧尸","疫毒喷吐者","异变首领"]
	var descriptions := ["黑眼窝 · 缺齿垂颌\n残破衣物 · 伸手蹒跚", "低伏前倾 · 骨爪长臂\n破损兜帽 · 快速追击", "锈蚀护甲 · 肿大身躯\n破盔露面 · 重拳压制", "肿胀腹部 · 背部毒囊\n酸蚀巨口 · 喷射毒液", "畸变巨臂 · 骨刺脊背\n断齿利爪 · 巨型压迫"]
	for i in range(5):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(220,0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("111f28")
		style.border_color = ZombieVisual.PALETTES[i].eye.darkened(0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel",style)
		row.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation",9)
		card.add_child(body)
		make_portrait(body,i,true)
		var stats := "血量 %d / 伤害 %d\n体型 ×%.1f" % [ENEMIES[i].hp,ENEMIES[i].damage,ENEMIES[i].scale]
		for entry in [[names[i],22],[stats,16],[descriptions[i],14]]:
			var text := Label.new()
			text.text = entry[0]
			text.add_theme_font_size_override("font_size",entry[1])
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(text)
	button(col,"返回英雄选择",show_menu)

func make_portrait(parent: Control, index: int, is_zombie := false) -> void:
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(196,285) if is_zombie else Vector2(352,300)
	holder.stretch = true
	holder.mouse_default_cursor_shape = Control.CURSOR_DRAG
	parent.add_child(holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(holder.custom_minimum_size)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	holder.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101f30")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d3e1f2")
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30,-35,0)
	key.light_color = Color("ffebc4")
	key.light_energy = 1.25
	viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2,3,-3)
	fill.light_color = Color("9ecbff")
	fill.light_energy = 0.85
	fill.omni_range = 8
	viewport.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(1,3,2)
	rim.light_color = ZombieVisual.PALETTES[index].eye if is_zombie else HeroVisual.PALETTES[index].energy
	rim.light_energy = 1.0
	rim.omni_range = 7
	viewport.add_child(rim)
	var stage := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.15
	disc.bottom_radius = 1.23
	disc.height = 0.12
	disc.radial_segments = 48
	stage.mesh = disc
	stage.position.y = -0.08
	stage.material_override = HeroVisual.mat(Color("26354b"))
	viewport.add_child(stage)
	var model: Node3D = ZombieVisual.new() if is_zombie else HeroVisual.new()
	model.build(index)
	model.rotation.y = -0.1
	viewport.add_child(model)
	portrait_rigs.append(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.4 if is_zombie else 3.85
	cam.position = Vector3(2.3,2.6,-5)
	viewport.add_child(cam)
	cam.look_at(Vector3(0,1.43,0))
	cam.current = true
	holder.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			model.rotation.y += event.relative.x*0.015
	)

func start_game(index: int) -> void:
	fx.clear()
	shots.clear()
	swings.clear()
	banner_time = 0
	banner.text = ""
	banner_hint.text = ""
	shake_strength = 0
	portrait_rigs.clear()
	if is_instance_valid(menu):
		menu.queue_free()
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
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
	player = HeroVisual.new()
	player.build(hero)
	world.add_child(player)
	var halo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.57
	torus.outer_radius = 0.63
	torus.rings = 24
	torus.ring_segments = 6
	halo.mesh = torus
	halo.position.y = 0.035
	halo.material_override = HeroVisual.mat(HEROES[hero].color,false,true)
	player.add_child(halo)
	playing = true

func spawn_enemy(kind: int) -> Dictionary:
	var data: Dictionary = ENEMIES[kind]
	var node := ZombieVisual.new()
	node.build(kind,randi_range(0,2))
	node.phase = randf()*TAU
	node.animate(0,false)
	node.scale = Vector3.ONE*data.scale
	var angle := randf()*TAU
	node.position = player.position+Vector3(cos(angle),0,sin(angle))*17
	node.position.x = clampf(node.position.x,-21,21)
	node.position.z = clampf(node.position.z,-21,21)
	world.add_child(node)
	var health_bar := box(node,Vector3(0,node.health_height,0),Vector3(0.8,0.07,0.08),Color("e36b7e"))
	var e := {"node":node,"bar":health_bar,"kind":kind,"hp":data.hp,"cooldown":1.0,"slow":0.0,"flash":0.0}
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
	fx.wave(pos,radius,color,0.4)

func flash_enemy(e: Dictionary) -> void:
	e.flash = 0.12
	e.node.set_overlay(white_flash)

func hurt(e: Dictionary, amount: float, heavy := false, frost := false) -> void:
	if e.get("dead",false):
		return
	var pos: Vector3 = e.node.position
	e.hp -= amount
	e.bar.scale.x = maxf(0,e.hp/ENEMIES[e.kind].hp)
	flash_enemy(e)
	fx.impact(pos,Color("9deeff") if frost else HEROES[hero].color,heavy)
	fx.number(pos,amount,Color("fff0a9") if heavy else Color("bcefff") if frost else Color.WHITE,heavy)
	if e.hp<=0:
		e.dead = true
		kills += 1
		xp += 1 if e.kind!=4 else 20
		fx.shards(pos,ENEMIES[e.kind].color)
		e.node.queue_free()
		if e.kind==4:
			finish(true)

func perform_attack(target: Dictionary) -> void:
	if target.get("dead",false):
		return
	player.look_at(Vector3(target.node.position.x,0,target.node.position.z))
	player.attack()
	if hero==0:
		swings.append({"delay":0.10,"damage":HEROES[hero].damage*damage_mult})
	else:
		var start: Vector3 = player.emission_point()
		var end: Vector3 = target.node.position+Vector3(0,1.15,0)
		var duration := clampf(start.distance_to(end)/(24.0 if hero==1 else 14.0),0.12 if hero==1 else 0.15,0.8)
		var color := Color("ffd46d") if hero==1 else Color("83e6ff")
		var forward := (end-start).normalized()
		fx.muzzle(start,forward,color,buff>0)
		var visual: Dictionary = fx.bolt(start,end,color,duration,hero==2)
		shots.append({"target":target,"end":end,"elapsed":0.0,"duration":duration,"damage":HEROES[hero].damage*damage_mult,"frost":hero==2,"visual":visual})
	tone(240 if hero==0 else 660 if hero==1 else 880)

func update_swings(delta: float) -> void:
	for i in range(swings.size()-1,-1,-1):
		var swing: Dictionary = swings[i]
		swing.delay -= delta
		if swing.delay<=0:
			fx.slash(player.position,player.rotation.y,3.5,HEROES[0].color)
			fx.wave(player.position,3.5,HEROES[0].color,0.25,0.8)
			for e in enemies:
				if not e.get("dead",false) and e.node.position.distance_to(player.position)<3.5:
					hurt(e,swing.damage)
			swings.remove_at(i)

func update_shots(delta: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var shot: Dictionary = shots[i]
		shot.elapsed += delta
		var target: Dictionary = shot.target
		if not target.get("dead",false):
			shot.end = target.node.position+Vector3(0,1.15,0)
		shot.visual.end = shot.end
		if shot.elapsed>=shot.duration:
			if not target.get("dead",false):
				if shot.frost:
					target.slow = maxf(target.slow,1.0)
					fx.shards(target.node.position,Color("a5eeff"),3,true)
				hurt(target,shot.damage,false,shot.frost)
			shots.remove_at(i)

func announce(title: String, detail: String, color: Color) -> void:
	banner.text = title
	banner_hint.text = detail
	banner.modulate = color.lightened(0.3)
	banner_hint.modulate = Color.WHITE
	banner_time = 1.4

func damage_player(amount: float) -> void:
	if invuln > 0 or not playing:
		return
	hp -= amount
	shake_strength = maxf(shake_strength,0.08)
	invuln = 0.5
	ring(player.position,0.8,Color("ff4a65"))
	tone(120)
	if hp <= 0:
		finish(false)

func area_damage(radius: float, amount: float, slow := false, heavy := true) -> void:
	for e in enemies:
		if not e.get("dead",false) and e.node.position.distance_to(player.position)<radius:
			if slow:
				e.slow = maxf(e.slow,3.0)
			hurt(e,amount*damage_mult,heavy,slow)

func skill(which: int) -> void:
	if not playing or choosing:
		return
	var remaining := q_clock if which==0 else e_clock
	if remaining>0:
		announce("技能冷却中","还需 %.1f 秒" % remaining,Color("c6d2de"))
		return
	var color: Color = HEROES[hero].color
	if which==0:
		q_clock = HEROES[hero].q
		if hero==0:
			fx.slash(player.position,player.rotation.y,4.5,color,true)
			fx.wave(player.position,4.5,color,0.65)
			announce("Q · 青龙横扫","旋身斩击 · 70 范围伤害",color)
		elif hero==1:
			fx.explosion(player.position,6.0)
			announce("Q · 爆裂弹","爆炸冲击 · 65 范围伤害",Color("ffc677"))
		else:
			fx.frost_field(player.position,6.0)
			announce("Q · 冰霜新星","冰晶扩散 · 45 伤害 · 减速 3 秒",color)
		area_damage(4.5 if hero==0 else 6.0,70.0 if hero==0 else 65.0 if hero==1 else 45.0,hero==2)
	else:
		e_clock = HEROES[hero].e
		if hero==0:
			invuln = 1.0
			var before := player.position
			player.position += direction*6
			player.position.x = clampf(player.position.x,-21,21)
			player.position.z = clampf(player.position.z,-21,21)
			fx.charge(before,player.position,color)
			fx.slash(player.position,player.rotation.y,5.0,color,true)
			area_damage(5,120)
			announce("E · 破阵突击","突进残影 · 120 伤害 · 免伤 1 秒",color)
		elif hero==1:
			buff = 5
			fx.aura(player,Color("ff9a47"),5.0)
			fx.wave(player.position,2.0,Color("ffd97c"),0.6)
			announce("E · 火力全开","强化弹道 · 攻击间隔缩短 40% · 持续 5 秒",Color("ffc677"))
		else:
			fx.frost_field(player.position,8.0,true)
			area_damage(8,120,true)
			announce("E · 极寒爆发","冰刺爆发 · 120 伤害 · 减速 3 秒",color)
	player.cast(which)
	shake_strength = maxf(shake_strength,0.12 if which==0 else 0.18)
	tone(180+hero*170+which*70)

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

func demo_segment(index: int) -> void:
	start_game(index)
	spawn_clock = 100
	for i in range(10):
		var e := spawn_enemy(2)
		var angle := i*TAU/10
		var radius := 3.2 if index==0 else 5.0
		e.node.position = Vector3(sin(angle)*radius,0,cos(angle)*radius)
		e.cooldown = 100
	announce(HEROES[index].name+" · 普通攻击","自动锁定 · 观察出手、弹道与命中反馈",HEROES[index].color)

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if combat_demo:
		var local_frame := demo_tick%180
		if local_frame==0:
			demo_segment(demo_tick/180)
		if local_frame==45:
			skill(0)
		if local_frame==100:
			skill(1)
		demo_tick += 1
		if demo_tick>=540:
			get_tree().quit()
			return
	if combat_preview>=0:
		demo_tick += 1
		if demo_tick==12:
			get_viewport().get_texture().get_image().save_png("res://dist/combat-%d.png" % combat_preview)
			get_tree().quit()
			return
	for model in portrait_rigs:
		if is_instance_valid(model):
			model.animate(delta,model is ZombieVisual)
	if zombie_preview:
		preview_frames += 1
		if preview_frames==20:
			get_viewport().get_texture().get_image().save_png("res://dist/zombies-back.png" if "--zombie-back-preview" in OS.get_cmdline_user_args() else "res://dist/zombies.png")
			get_tree().quit()
			return
	if menu_preview:
		preview_frames += 1
		if preview_frames==20:
			get_viewport().get_texture().get_image().save_png("res://dist/heroes-back.png" if "--back-preview" in OS.get_cmdline_user_args() else "res://dist/heroes.png")
			get_tree().quit()
			return
	if preview:
		preview_frames += 1
		if preview_frames == 30:
			get_viewport().get_texture().get_image().save_png("/workspace/brick-outbreak/dist/gameplay.png")
			get_tree().quit()
			return
	if auto_test:
		run_smoke_test()
		return
	if not playing or choosing:
		return
	step(1.0/60.0 if combat_preview>=0 else delta)

func step(delta: float) -> void:
	elapsed += delta
	attack_clock -= delta
	q_clock = maxf(0,q_clock-delta)
	e_clock = maxf(0,e_clock-delta)
	invuln = maxf(0,invuln-delta)
	dash_clock = maxf(0,dash_clock-delta)
	buff = maxf(0,buff-delta)
	var movement := Vector3(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	player.animate(delta,movement.length()>0)
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
		e.flash = maxf(0,e.flash-delta)
		node.scale = Vector3.ONE*data.scale*(1.0+e.flash*0.5)
		node.set_overlay(white_flash if e.flash>0 else ice_overlay if e.slow>0 else null)
		e.cooldown -= delta
		e.slow = maxf(0,e.slow-delta)
		var stop_distance := 8.0 if e.kind==3 else 1.0
		node.animate(delta,distance>stop_distance,e.slow>0)
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
			node.attack()
			if e.kind==3:
				var origin: Vector3 = node.mouth_position()
				var aim := (player.position+Vector3(0,1.15,0)-origin).normalized()
				var b := MeshInstance3D.new()
				var glob := SphereMesh.new()
				glob.radius = 0.20
				glob.height = 0.40
				b.mesh = glob
				b.material_override = HeroVisual.mat(Color("c5ed6a"),false,true)
				b.position = origin
				world.add_child(b)
				fx.muzzle(origin,aim,Color("bce969"))
				bullets.append({"node":b,"velocity":aim*6,"time":3.0,"damage":data.damage})
			else:
				damage_player(data.damage)
	if not nearest.is_empty() and attack_clock<=0 and nearest_distance<(3.5 if hero==0 else 12.0):
		attack_clock = HEROES[hero].rate*(0.6 if buff>0 else 1.0)
		perform_attack(nearest)
	update_swings(delta)
	update_shots(delta)
	fx.update(delta)
	shake_strength = move_toward(shake_strength,0,delta*0.75)
	camera.position += Vector3(sin(elapsed*71),sin(elapsed*53),0)*shake_strength
	banner_time = maxf(0,banner_time-delta)
	banner.modulate.a = minf(1,banner_time*3)
	banner_hint.modulate.a = banner.modulate.a
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
	if xp >= level*8 and playing and not auto_test and not preview and combat_preview<0 and not combat_demo:
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
	for i in range(2):
		var cooldown := q_clock if i==0 else e_clock
		skill_buttons[i].text = ("Q · " if i==0 else "E · ")+names[i]+"\n"+("点击释放" if cooldown<=0 else "%.1f 秒" % cooldown)
		if hero==1 and i==1 and buff>0:
			skill_buttons[i].text = "E · 火力全开\n强化中 %.1f 秒" % buff
			skill_buttons[i].modulate = Color("ffd29a")
		else:
			skill_buttons[i].modulate = Color.WHITE
		skill_buttons[i].disabled = cooldown>0
	status.text = "Q %s  %s     E %s  %s     空格闪避  %s\nWASD 移动 · 自动攻击 · 击杀经验 %d / %d · 首领 02:30 出现 · 限时 04:00" % [names[0],"就绪" if q_clock<=0 else "%.1fs" % q_clock,names[1],"就绪" if e_clock<=0 else "%.1fs" % e_clock,"就绪" if dash_clock<=0 else "%.1fs" % dash_clock,xp,level*8]

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: "+description)
		get_tree().quit(1)
		assert(condition,description)
	print("PASS: "+description)

func zombie_checks() -> void:
	start_game(0)
	var budget := true
	var first: Node3D
	for kind in range(5):
		var e := spawn_enemy(kind)
		var model: Node3D = e.node
		if kind==0:
			first = model
		check(model.identity==kind and model.details>40 and is_instance_valid(model.head),"enemy %d uses its articulated zombie appearance" % kind)
		budget = budget and model.meshes.size()<=36 and model.meshes.size()<model.details
		model.phase = 0
		model.animate(0,false)
		var before: float = model.leg_l.rotation.x
		model.animate(0.1,true)
		var walked: bool = absf(model.leg_l.rotation.x-before)>0.01
		model.attack()
		model.animate(0.12,true)
		check(walked and model.jaw.rotation.x>0.4,"enemy %d limp and open-jaw attack animate" % kind)
		var restored := true
		for overlay in [white_flash,ice_overlay,null]:
			model.set_overlay(overlay)
			for part in model.meshes:
				restored = restored and part.material_overlay==overlay
		check(restored,"enemy %d nested meshes retain flash and freeze feedback" % kind)
		check(e.bar.global_position.y>model.head.global_position.y+0.1,"enemy %d health bar remains above the head" % kind)
	check(budget,"zombie details are merged into a bounded mesh budget")
	var copy := ZombieVisual.new()
	copy.build(0,first.variant)
	check(copy.meshes[0].mesh==first.meshes[0].mesh,"horde instances share baked geometry")
	copy.free()
	var before_phase: float = first.phase
	first.animate(0.1,true,true)
	check(is_equal_approx(first.phase-before_phase,0.21),"frozen zombie gait matches half movement speed")
	start_game(0)
	spawn_clock = 100
	attack_clock = 100
	var spitter := spawn_enemy(3)
	spitter.node.position = Vector3(0,0,-6)
	spitter.cooldown = 0
	step(0.01)
	check(bullets.size()==1 and bullets[0].node.position.distance_to(spitter.node.mouth_position())<0.1,"acid projectile visibly launches from the zombie mouth")
	for i in range(30):
		step(0.05)
	check(hp==205 and bullets.is_empty(),"mouth-launched acid reaches and damages the player once")
	show_zombie_gallery()
	var correct: bool = portrait_rigs.size()==5
	for i in range(portrait_rigs.size()):
		correct = correct and portrait_rigs[i] is ZombieVisual and portrait_rigs[i].identity==i
	check(correct,"zombie bestiary previews all five actual enemy models")
	var model: Node3D = portrait_rigs[0]
	var yaw := model.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = Vector2(40,0)
	model.get_parent().get_parent().gui_input.emit(motion)
	check(model.rotation.y>yaw+0.5,"zombie bestiary drag rotates the 3D model")

func combat_checks() -> void:
	start_game(0)
	attack_clock = 100
	spawn_clock = 100
	var melee_target := spawn_enemy(2)
	melee_target.node.position = Vector3(2,0,0)
	melee_target.cooldown = 100
	perform_attack(melee_target)
	check(melee_target.hp==240 and swings.size()==1,"melee begins with a visible windup")
	step(0.05)
	check(melee_target.hp==240,"melee windup does not deal premature damage")
	step(0.08)
	check(melee_target.hp==210 and swings.is_empty(),"melee damage settles once at the slash")
	for index in [1,2]:
		start_game(index)
		spawn_clock = 100
		attack_clock = 100
		var target := spawn_enemy(2)
		target.node.position = Vector3(0,0,-7)
		target.cooldown = 100
		perform_attack(target)
		check(shots.size()==1 and target.hp==240,"hero %d projectile leaves weapon before damage" % index)
		var shot: Dictionary = shots[0]
		var start: Vector3 = shot.visual.start
		check(start.distance_to(player.emission_point())<0.01 and start.y>0.5,"hero %d projectile begins at held weapon" % index)
		step(shot.duration*0.4)
		check(target.hp==240 and shots.size()==1,"hero %d no premature projectile damage" % index)
		step(shot.duration*0.7)
		check(target.hp==240-HEROES[index].damage and shots.is_empty(),"hero %d damage settles once on arrival" % index)
		var numbers := 0
		for e in fx.active:
			if e.mode=="number" and e.node.text==str(int(HEROES[index].damage)):
				numbers += 1
		check(numbers==1,"hero %d damage popup matches actual hit" % index)
		if index==2:
			check(target.slow>0,"ice projectile applies slow on impact")
	start_game(1)
	var target := spawn_enemy(2)
	target.node.position = Vector3(0,0,-6)
	perform_attack(target)
	hurt(target,1000)
	update_shots(1)
	check(kills==1 and shots.is_empty(),"in-flight bolt cannot reward a dead target twice")
	start_game(0)
	spawn_clock = 100
	attack_clock = 100
	target = spawn_enemy(2)
	target.node.position = Vector3(2,0,0)
	target.cooldown = 100
	hurt(target,10)
	check(target.node.meshes[0].material_overlay==white_flash,"actual hit visibly flashes enemy")
	step(0.2)
	check(target.node.meshes[0].material_overlay==null,"hit flash restores original material")
	for index in range(3):
		start_game(index)
		var count: int = fx.created
		skill(0)
		check(fx.created>count and banner.text.begins_with("Q"),"hero %d Q has visible FX and skill title" % index)
		count = fx.created
		skill(0)
		check(fx.created==count,"hero %d cooldown cannot duplicate attack FX" % index)
		skill(1)
		check(fx.created>count and banner.text.begins_with("E"),"hero %d E has visible FX and skill title" % index)
	start_game(1)
	target = spawn_enemy(2)
	target.node.position = Vector3(0,0,-5)
	perform_attack(target)
	var age: float = fx.active[0].age
	var travel: float = shots[0].elapsed
	playing = false
	auto_test = false
	_process(0.2)
	auto_test = true
	check(fx.active[0].age==age and shots[0].elapsed==travel,"pause freezes effects and projectile flight")
	start_game(0)
	check(fx.active.is_empty() and shots.is_empty(),"restart removes old projectiles and effects")
	for i in range(260):
		fx.wave(Vector3.ZERO,1,Color.WHITE,0.1)
	check(fx.active.size()<=CombatFX.LIMIT,"effect population remains bounded")
	fx.update(1)
	check(fx.active.is_empty(),"expired FX are released")

func run_smoke_test() -> void:
	if test_steps>0:
		return
	test_steps += 1
	var mesh_arrays: Array = HeroVisual.beveled(Vector3.ONE).surface_get_arrays(0)
	var outward := true
	for i in range(0,mesh_arrays[Mesh.ARRAY_VERTEX].size(),3):
		var center: Vector3 = (mesh_arrays[Mesh.ARRAY_VERTEX][i]+mesh_arrays[Mesh.ARRAY_VERTEX][i+1]+mesh_arrays[Mesh.ARRAY_VERTEX][i+2])/3.0
		outward = outward and center.dot(mesh_arrays[Mesh.ARRAY_NORMAL][i])>0
	check(outward,"all beveled armor faces point outward")
	for index in range(3):
		start_game(index)
		check(hp==HEROES[index].hp,"hero %d stats" % index)
		check(player.identity==index and player.decorative_parts>100,"hero %d detailed model is used in battle" % index)
		player.animate(0.1,true)
		check(absf(player.leg_l.rotation.x)>0.1,"hero %d articulated walking" % index)
		player.animate(0.0,false)
		var idle_arm: float = player.arm_r.rotation.x
		player.attack()
		player.animate(0.1,false)
		check(absf(player.arm_r.rotation.x-idle_arm)>0.1,"hero %d weapon attack animation" % index)
		var e := spawn_enemy(0)
		e.node.position = Vector3(1,0,0)
		step(0.016)
		step(0.16)
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
		var before: Vector3 = player.position
		skill(1)
		check(e_clock>0,"hero %d E cooldown" % index)
		var skill_effect: bool = player.position.distance_to(before)>5 and invuln>0 if index==0 else buff==5 if index==1 else target.slow>0 and target.hp<previous_hp-100
		check(skill_effect,"hero %d E effect" % index)
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
	show_menu()
	check(portrait_rigs.size()==3 and portrait_rigs[0].identity==0 and portrait_rigs[2].identity==2,"three distinct live 3D previews")
	var portrait: Node3D = portrait_rigs[0]
	var before_rotation := portrait.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = Vector2(40,0)
	portrait.get_parent().get_parent().gui_input.emit(motion)
	check(portrait.rotation.y>before_rotation+0.5,"drag rotates the actual 3D model")
	combat_checks()
	zombie_checks()
	print("SMOKE TEST COMPLETE")
	get_tree().quit(0)

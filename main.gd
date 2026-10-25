extends Node3D

const HeroVisual = preload("res://hero_model.gd")
const CombatFX = preload("res://combat_fx.gd")
const ZombieVisual = preload("res://zombie_model.gd")
const BattleCamera = preload("res://battle_camera.gd")
const Campaign = preload("res://campaign_data.gd")
const CampaignEnemy = preload("res://campaign_enemy.gd")
const StageWorld = preload("res://stage_world.gd")
var stage_index := 0
var wave_index := 0
var wave_spawned := 0
var stage_spawned := 0
var stage_kills := 0
var stage_cleared := false
var between_stages := false
var campaign_won := false
var gallery_stage := 0
var stage_scenes: Array = [null,null,null]
var stage_hud: Label
var sky: Environment
var sunlight: DirectionalLight3D
var stage_preview := -1
var stage_demo := false
var stage_demo_tick := 0

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
var view_rig: RefCounted
var view_button: Button
var view_hint: Label
var view_controls: Array = []
var view_drag := false
var camera_preview := -1
var camera_demo := false
var camera_tick := 0
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
	env.environment.background_mode = Environment.BG_SKY
	sky = env.environment
	sky.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	sky.tonemap_exposure = 0.85
	sky.sky = Sky.new()
	sky.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b0c5e0")
	env.environment.ambient_light_energy = 0.28
	add_child(env)
	var sun := DirectionalLight3D.new()
	sunlight = sun
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color("ffe5b0")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	activate_scenery(0)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	view_rig = BattleCamera.new(camera)
	view_rig.set_mode(1,Vector3.ZERO,true)
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
	stage_hud = label(ui,"",Vector2(32,108),23)
	stage_hud.add_theme_constant_override("outline_size",6)
	stage_hud.add_theme_color_override("font_outline_color",Color("182a28"))
	banner = label(ui,"",Vector2(420,180),34)
	banner.add_theme_constant_override("outline_size",8)
	banner.add_theme_color_override("font_outline_color",Color("0e1c28"))
	banner_hint = label(ui,"",Vector2(420,227),18)
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
	view_button = Button.new()
	view_button.position = Vector2(880,22)
	view_button.size = Vector2(260,48)
	view_button.focus_mode = Control.FOCUS_NONE
	view_button.add_theme_font_size_override("font_size",18)
	view_button.pressed.connect(cycle_view)
	ui.add_child(view_button)
	var reset_button := Button.new()
	reset_button.text = "R 复位"
	reset_button.position = Vector2(1155,22)
	reset_button.size = Vector2(105,48)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(reset_view)
	ui.add_child(reset_button)
	view_hint = label(ui,"1 俯视 / 2 斜视 / 3 跟随\n右键拖动旋转 · 滚轮缩放",Vector2(885,80),15)
	view_hint.add_theme_constant_override("outline_size",4)
	view_controls = [view_button,reset_button,view_hint]
	update_view_ui()
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
	camera_demo = "--camera-demo" in OS.get_cmdline_user_args()
	for i in range(3):
		if ("--camera-preview="+str(i)) in OS.get_cmdline_user_args():
			camera_preview = i
	if camera_preview>=0:
		setup_camera_scene(camera_preview)
	stage_demo = "--stage-demo" in OS.get_cmdline_user_args()
	for i in range(3):
		if ("--stage-preview="+str(i)) in OS.get_cmdline_user_args():
			stage_preview = i
	if stage_preview>=0:
		setup_stage_preview(stage_preview)
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
	view_drag = false
	banner_time = 0
	banner.modulate.a = 0
	banner_hint.modulate.a = 0
	if is_instance_valid(stage_hud): stage_hud.hide()
	for control in view_controls:
		control.hide()
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
	var col := panel("积木 / 远征", "三关远征：非洲草原 → 埃及金字塔 → 中国长城 · 选择英雄出战")
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
	tip.text = "WASD / 方向键移动    Q / E 技能    空格闪避    Esc 暂停\n三关连续挑战 · 每关三波，清空全部敌人后晋级 · 等级与强化继承\n1/2/3 视角 · V 切换 · 右键旋转 · 滚轮缩放 · R 复位"
	tip.add_theme_font_size_override("font_size",17)
	col.add_child(tip)
	var catalog := Button.new()
	catalog.text = "远征敌人图鉴"
	catalog.position = Vector2(1000,50)
	catalog.size = Vector2(210,46)
	catalog.add_theme_font_size_override("font_size",20)
	catalog.pressed.connect(show_zombie_gallery)
	menu.add_child(catalog)

func show_zombie_gallery() -> void:
	playing = false
	paused = false
	choosing = false
	var col := panel(Campaign.TITLES[gallery_stage]+" · 敌人图鉴", "拖动可旋转模型 · 草原野兽 / 木乃伊 / 兵马俑")
	col.position = Vector2(60,28)
	col.custom_minimum_size = Vector2(1160,0)
	col.add_theme_constant_override("separation",12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",15)
	col.add_child(row)
	var names: Array = Campaign.ENEMY_NAMES[gallery_stage]
	var descriptions: Array = [
		["四足追猎 · 发光感染眼", "迅捷扑咬 · 低伏疾奔", "粗壮獠牙 · 背鬃护体", "浓密鬃毛 · 疫毒喷吐", "巨大雄狮 · 兽群首领"],
		["层叠绷带 · 蹒跚追击", "豺首面具 · 快速追击", "王陵盾甲 · 高血量", "诅咒法杖 · 远程法球", "条纹王冠 · 法老首领"],
		["陶土面孔 · 扎甲长兵", "轻装陶俑 · 快步追击", "层叠重甲 · 持盾守卫", "陶土弩手 · 远程弩箭", "将军冠盔 · 雄关首领"]
	][gallery_stage]
	for i in range(5):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(220,0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("111f28")
		style.border_color = Campaign.COLORS[gallery_stage].darkened(0.3)
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
		var data := Campaign.stats(gallery_stage,i,ENEMIES[i])
		var stats := "血量 %d / 伤害 %d\n体型 ×%.1f" % [data.hp,data.damage,data.scale]
		for entry in [[names[i],22],[stats,16],[descriptions[i],14]]:
			var text := Label.new()
			text.text = entry[0]
			text.add_theme_font_size_override("font_size",entry[1])
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(text)
	var next := Button.new()
	next.text = "切换图鉴："+Campaign.TITLES[(gallery_stage+1)%3]
	next.position = Vector2(890,47)
	next.size = Vector2(325,45)
	next.pressed.connect(func():
		gallery_stage = (gallery_stage+1)%3
		show_zombie_gallery()
	)
	menu.add_child(next)
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
	rim.light_color = Campaign.COLORS[gallery_stage] if is_zombie else HeroVisual.PALETTES[index].energy
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
	var model: Node3D = CampaignEnemy.new() if is_zombie else HeroVisual.new()
	if is_zombie:
		model.build_for_stage(gallery_stage,index)
	else:
		model.build(index)
	model.rotation.y = -0.1
	viewport.add_child(model)
	portrait_rigs.append(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.9 if is_zombie else 3.85
	cam.position = Vector3(2.3,2.6,-5)
	viewport.add_child(cam)
	cam.look_at(Vector3(0,1.1 if is_zombie and gallery_stage==0 else 1.43,0))
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
	campaign_won = false
	between_stages = false
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
	begin_stage(0)

func activate_scenery(index: int) -> void:
	for scene in stage_scenes:
		if is_instance_valid(scene): scene.hide()
	if not is_instance_valid(stage_scenes[index]):
		var scene := StageWorld.new()
		scene.build(index)
		world.add_child(scene)
		stage_scenes[index] = scene
	stage_scenes[index].show()
	var sky_material: ProceduralSkyMaterial = sky.sky.sky_material
	sky_material.sky_top_color = [Color("7baaba"),Color("87adbd"),Color("779baa")][index]
	sky_material.sky_horizon_color = Campaign.SKY[index]
	sky_material.ground_horizon_color = Campaign.SKY[index]
	sky_material.ground_bottom_color = [Color("a18c61"),Color("bc9d6c"),Color("687c6e")][index]
	sky.ambient_light_color = [Color("ffebc3"),Color("ffedcc"),Color("d1e4e3")][index]
	if is_instance_valid(sunlight):
		sunlight.light_color = [Color("ffe1a2"),Color("fff0cd"),Color("e4f3f0")][index]

func clear_battle() -> void:
	for e in enemies:
		e.node.hide()
		e.node.queue_free()
	enemies.clear()
	for b in bullets:
		b.node.hide()
		b.node.queue_free()
	bullets.clear()
	shots.clear()
	swings.clear()
	fx.clear()
	shake_strength = 0

func begin_stage(index: int) -> void:
	clear_battle()
	stage_index = clampi(index,0,2)
	wave_index = 0
	wave_spawned = 0
	stage_spawned = 0
	stage_kills = 0
	stage_cleared = false
	between_stages = false
	boss_spawned = false
	choosing = false
	paused = false
	activate_scenery(stage_index)
	player.position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	hp = max_hp
	q_clock = 0
	e_clock = 0
	dash_clock = 0
	attack_clock = 0.4
	invuln = 1.5
	buff = 0
	spawn_clock = 2.0
	playing = true
	direction = Vector3.FORWARD
	view_drag = false
	view_rig.recenter(player.position,true)
	update_view_ui()
	announce("第 %d 关 · %s" % [stage_index+1,Campaign.TITLES[stage_index]],Campaign.SUBTITLES[stage_index]+" · 清空三波敌人",Campaign.COLORS[stage_index])
	banner_time = 3.0

func update_campaign_spawns(delta: float) -> void:
	if stage_cleared: return
	spawn_clock -= delta
	var queue: Array = Campaign.WAVES[stage_index][wave_index]
	if spawn_clock<=0 and wave_spawned<queue.size() and enemies.size()<12:
		var kind: int = queue[wave_spawned]
		spawn_enemy(kind)
		wave_spawned += 1
		stage_spawned += 1
		spawn_clock = 0.85 if kind!=4 else 2.0
		if kind==4:
			boss_spawned = true
			announce("关底首领 · "+Campaign.ENEMY_NAMES[stage_index][4],"击败首领并清除剩余敌人",Campaign.COLORS[stage_index])

func check_wave_clear() -> void:
	if stage_cleared or not playing or choosing: return
	if wave_spawned<Campaign.WAVES[stage_index][wave_index].size() or not enemies.is_empty(): return
	if wave_index<2:
		wave_index += 1
		wave_spawned = 0
		spawn_clock = 2.5
		announce("第 %d 波 · 来袭" % [wave_index+1],"清理兽群" if stage_index==0 else "守住阵地，清空敌军",Campaign.COLORS[stage_index])
	else:
		stage_cleared = true
		clear_battle()
		if stage_index==2:
			finish(true)
		else:
			between_stages = true
			choosing = true
			var col := panel("%s · 已净化" % Campaign.TITLES[stage_index],"本关 %d / %d 已清除 · 选择强化后前往 %s\n保留等级与强化，恢复全部血量并刷新技能。" % [stage_kills,Campaign.total(stage_index),Campaign.TITLES[stage_index+1]])
			button(col,"强化攻击 +20%   →   进入下一关",upgrade.bind(0))
			button(col,"强化装甲 +40 血量上限   →   进入下一关",upgrade.bind(1))
			button(col,"战地补给 +10% 伤害   →   进入下一关",travel_supply)

func travel_supply() -> void:
	if not between_stages: return
	damage_mult += 0.1
	upgrade(2)

func setup_stage_preview(index: int) -> void:
	start_game(0)
	begin_stage(index)
	spawn_clock = 100
	attack_clock = 100
	var positions := [Vector3(-3,0,-3),Vector3(-5,0,-6),Vector3(3,0,-4),Vector3(5,0,-6),Vector3(0,0,-9)]
	for i in range(5):
		var e := spawn_enemy(i)
		e.node.position = positions[i]
		e.cooldown = 100
	view_rig.set_mode(1,player.position,true)
	view_rig.pitch = deg_to_rad(25)
	view_rig.update(player.position,0,true)
	update_view_ui()
	if stage_preview>=0: banner_time = 0

func spawn_enemy(kind: int) -> Dictionary:
	var data := Campaign.stats(stage_index,kind,ENEMIES[kind])
	var node := CampaignEnemy.new()
	node.build_for_stage(stage_index,kind,randi_range(0,2))
	node.phase = randf()*TAU
	node.animate(0,false)
	node.scale = Vector3.ONE*data.scale
	var angle := randf()*TAU
	node.position = player.position+Vector3(cos(angle),0,sin(angle))*17
	node.position.x = clampf(node.position.x,-21,21)
	node.position.z = clampf(node.position.z,-21,21)
	world.add_child(node)
	var health_bar := MeshInstance3D.new()
	var health_quad := QuadMesh.new()
	health_quad.size = Vector2(0.8,0.09)
	health_bar.mesh = health_quad
	health_bar.position = Vector3(0,node.health_height,0)
	var health_material := material(Color("e36b7e"))
	health_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	health_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar.material_override = health_material
	health_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(health_bar)
	var e := {"node":node,"bar":health_bar,"kind":kind,"hp":data.hp,"data":data,"cooldown":1.0,"slow":0.0,"flash":0.0}
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
	e.bar.scale.x = maxf(0,e.hp/e.data.hp)
	flash_enemy(e)
	fx.impact(pos,Color("9deeff") if frost else HEROES[hero].color,heavy)
	fx.number(pos,amount,Color("fff0a9") if heavy else Color("bcefff") if frost else Color.WHITE,heavy)
	if e.hp<=0:
		e.dead = true
		kills += 1
		stage_kills += 1
		xp += 1 if e.kind!=4 else 20
		fx.shards(pos,e.data.color)
		e.node.queue_free()

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

func update_view_ui() -> void:
	stage_hud.visible = playing and not choosing
	view_button.text = "V · %s  %d/3" % [BattleCamera.NAMES[view_rig.mode],view_rig.mode+1]
	for control in view_controls:
		control.visible = playing and not choosing

func set_view(index: int) -> void:
	if not playing or choosing:
		return
	view_rig.set_mode(index,player.position)
	update_view_ui()

func cycle_view() -> void:
	set_view(view_rig.mode+1)

func reset_view() -> void:
	if not playing or choosing:
		return
	view_rig.recenter(player.position)
	update_view_ui()

func update_camera_occlusion() -> void:
	for e in enemies:
		if not e.get("dead",false):
			e.node.set_camera_occluded(view_rig.blocks_player(e.node.position,e.data.scale,player.position))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		view_drag = false
	if not playing or choosing:
		view_drag = false
		return
	if event is InputEventMouseMotion and view_drag:
		view_rig.orbit(event.relative)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not playing or choosing or not event is InputEventMouseButton:
		return
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		view_drag = true
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		view_rig.zoom(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()

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
	if event.keycode in [KEY_1,KEY_2,KEY_3]:
		set_view(event.keycode-KEY_1)
		return
	if event.keycode==KEY_V:
		cycle_view()
		return
	if event.keycode==KEY_R:
		reset_view()
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
	update_view_ui()

func upgrade(choice: int) -> void:
	var travel := between_stages
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
	update_view_ui()
	if is_instance_valid(menu):
		menu.queue_free()
	if travel:
		begin_stage(stage_index+1)

func finish(won: bool) -> void:
	playing = false
	choosing = false
	paused = false
	campaign_won = won
	var col := panel("三关净化完成 · 远征胜利" if won else "英雄倒下 · 远征失败", "%s · 第 %d 关 %s · 击败 %d 个敌人 · 等级 %d · %02d:%02d" % [HEROES[hero].name,stage_index+1,Campaign.TITLES[stage_index],kills,level,int(elapsed)/60,int(elapsed)%60])
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

func setup_camera_scene(index: int) -> void:
	start_game(0)
	spawn_clock = 100
	attack_clock = 100
	var positions := [Vector3(-3,0,-4),Vector3(-5,0,-7),Vector3(3,0,-5),Vector3(5,0,-8),Vector3(6,0,-7)]
	for i in range(5):
		var e := spawn_enemy(i)
		e.node.position = positions[i]
		e.cooldown = 100
	view_rig.set_mode(index,player.position,true)
	update_view_ui()

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if stage_demo:
		var frame := stage_demo_tick%210
		if frame==0:
			setup_stage_preview(stage_demo_tick/210)
		if frame==40:
			attack_clock = 0
		if frame==80:
			skill(0)
		if frame==135:
			skill(1)
		if frame>140:
			view_rig.orbit(Vector2(1.4,0))
		stage_demo_tick += 1
		if stage_demo_tick>=630:
			get_tree().quit()
			return
	if stage_preview>=0:
		preview_frames += 1
		if preview_frames==25:
			get_viewport().get_texture().get_image().save_png("res://dist/stage-%d.png" % stage_preview)
			get_tree().quit()
			return
	if camera_demo:
		var frame := camera_tick%180
		if frame==0:
			setup_camera_scene(camera_tick/180)
			announce(BattleCamera.NAMES[view_rig.mode],"同一战场 · 镜头旋转与角色朝向独立",Color("d6edff"))
		if frame==30:
			attack_clock = 0
		if frame==60:
			skill(0)
		if frame==110:
			skill(1)
		if frame>120:
			view_rig.orbit(Vector2(2,0))
		camera_tick += 1
		if camera_tick>=540:
			get_tree().quit()
			return
	if camera_preview>=0:
		preview_frames += 1
		if preview_frames==20:
			get_viewport().get_texture().get_image().save_png("res://dist/view-%d.png" % camera_preview)
			get_tree().quit()
			return
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
	var axes := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var movement: Vector3 = view_rig.movement_axis(axes)
	player.animate(delta,movement.length()>0)
	if movement.length()>0:
		direction = movement.normalized()
		player.position += movement*5.5*delta
		player.rotation.y = atan2(-direction.x,-direction.z)
	player.position.x = clampf(player.position.x,-21,21)
	player.position.z = clampf(player.position.z,-21,21)
	view_rig.update(player.position,delta)
	update_campaign_spawns(delta)
	var nearest: Dictionary = {}
	var nearest_distance := 1000.0
	for e in enemies:
		if e.get("dead",false):
			continue
		var node: Node3D = e.node
		var data: Dictionary = e.data
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
				var tint: Color = [Color("c5ed6a"),Color("d99beb"),Color("e8c493")][stage_index]
				if stage_index==2:
					var arrow := BoxMesh.new()
					arrow.size = Vector3(0.08,0.08,0.95)
					b.mesh = arrow
				else:
					var glob := SphereMesh.new()
					glob.radius = 0.20
					glob.height = 0.40
					b.mesh = glob
				b.material_override = HeroVisual.mat(tint,false,true)
				b.position = origin
				world.add_child(b)
				b.look_at(origin+aim)
				fx.muzzle(origin,aim,tint)
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
	update_camera_occlusion()
	update_view_ui()
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
	check_wave_clear()
	if xp >= level*8 and playing and not auto_test and not preview and combat_preview<0 and not combat_demo and not camera_demo and camera_preview<0 and not stage_demo and stage_preview<0 and not choosing:
		xp -= level*8
		level += 1
		choosing = true
		var col := panel("升级 · 等级 %02d" % level,"选择一项强化。选择期间战斗暂停。")
		button(col,"锋利积木    /    伤害增加 20% 基础值",upgrade.bind(0))
		button(col,"坚固装甲    /    血量上限增加 40，恢复 65 血量",upgrade.bind(1))
		button(col,"重整旗鼓    /    恢复 100 血量，立即刷新技能",upgrade.bind(2))
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	stage_hud.text = "第 %d / 3 关 · %s    |    第 %d / 3 波    |    净化 %d / %d" % [stage_index+1,Campaign.TITLES[stage_index],wave_index+1,stage_kills,Campaign.total(stage_index)]
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
	status.text = "Q %s  %s     E %s  %s     空格闪避  %s\nWASD 移动 · 自动攻击 · 击杀经验 %d / %d · 清空本关全部敌人后晋级" % [names[0],"就绪" if q_clock<=0 else "%.1fs" % q_clock,names[1],"就绪" if e_clock<=0 else "%.1fs" % e_clock,"就绪" if dash_clock<=0 else "%.1fs" % dash_clock,xp,level*8]

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: "+description)
		get_tree().quit(1)
		assert(condition,description)
	print("PASS: "+description)

func camera_checks() -> void:
	start_game(0)
	view_rig.set_mode(0,player.position,true)
	check(camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"top view uses an orthographic camera")
	view_rig.set_mode(1,player.position,true)
	var oblique_distance := camera.position.distance_to(player.position)
	check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"oblique view uses perspective")
	view_rig.set_mode(2,player.position,true)
	check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE and camera.position.distance_to(player.position)<oblique_distance,"third-person view is closer to the hero")
	view_rig.set_mode(0,player.position,true)
	for i in range(3):
		cycle_view()
	check(view_rig.mode==0,"view cycling wraps across three modes")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	_unhandled_key_input(key)
	key.keycode = KEY_3
	_unhandled_key_input(key)
	check(view_rig.mode==2,"number keys select battle views")
	key.keycode = KEY_V
	_unhandled_key_input(key)
	check(view_rig.mode==0,"V cycles the battle view")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	_unhandled_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80,-20)
	_input(motion)
	check(view_drag and absf(view_rig.yaw)>0.1,"right drag orbits the battle camera")
	mouse.pressed = false
	_input(mouse)
	check(not view_drag,"right release stops camera orbit")
	var zoom_before: float = view_rig.zoom_value
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	mouse.pressed = true
	_unhandled_input(mouse)
	check(view_rig.zoom_value<zoom_before,"mouse wheel zooms the active view")
	var bounded := true
	for mode in range(3):
		view_rig.set_mode(mode,player.position,true)
		view_rig.zoom(1000)
		bounded = bounded and view_rig.zoom_value==BattleCamera.MAX_ZOOM[mode]
		view_rig.zoom(-1000)
		bounded = bounded and view_rig.zoom_value==BattleCamera.MIN_ZOOM[mode]
	check(bounded,"zoom stays within safe limits in every mode")
	view_rig.orbit(Vector2(100000,100000))
	var safe_pitch: bool = view_rig.pitch<=deg_to_rad(BattleCamera.MAX_PITCH[2])
	view_rig.orbit(Vector2(-100000,-100000))
	check(safe_pitch and view_rig.pitch>=deg_to_rad(BattleCamera.MIN_PITCH[2]) and absf(view_rig.yaw)<=PI,"camera pitch and yaw remain bounded")
	key.keycode = KEY_R
	_unhandled_key_input(key)
	check(view_rig.yaw==0 and view_rig.zoom_value==BattleCamera.DEFAULT_ZOOM[2],"R restores the active camera preset")
	view_rig.set_mode(1,player.position,true)
	view_rig.yaw = PI/2
	view_rig.update(player.position,0,true)
	var forward: Vector3 = view_rig.movement_axis(Vector2(0,-1))
	var right: Vector3 = view_rig.movement_axis(Vector2(1,0))
	check(forward.dot(Vector3.LEFT)>0.99 and right.dot(Vector3.FORWARD)>0.99,"WASD follows the displayed camera heading")
	check(is_equal_approx(view_rig.movement_axis(Vector2(1,-1)).length(),1),"diagonal camera-relative movement has no speed boost")
	start_game(1)
	view_rig.set_mode(2,player.position,true)
	var yaw_before: float = view_rig.yaw
	var eye_before := camera.position
	var target := spawn_enemy(0)
	target.node.position = Vector3(-5,0,-3)
	perform_attack(target)
	view_rig.update(player.position,0.1)
	check(view_rig.yaw==yaw_before and camera.position.distance_to(eye_before)<0.001 and absf(player.rotation.y)>0.1,"automatic attack facing cannot spin the camera")
	var blocker := spawn_enemy(0)
	blocker.node.position = Vector3(0.3,0,3)
	update_camera_occlusion()
	check(blocker.node.camera_occluded and blocker.node.meshes[0].material_override.albedo_color.a<0.4,"enemy between camera and hero becomes translucent")
	check(not target.node.camera_occluded and target.node.meshes[0].material_override.albedo_color.a==1,"occlusion fade leaves other horde instances opaque")
	hurt(blocker,1)
	check(blocker.node.meshes[0].material_overlay==null,"hit flash cannot make a faded blocker opaque")
	view_rig.set_mode(0,player.position,true)
	update_camera_occlusion()
	check(not blocker.node.camera_occluded and blocker.node.meshes[0].material_override==blocker.node.base_materials[0] and blocker.node.meshes[0].material_overlay==white_flash,"leaving occlusion restores original material and hit feedback")
	check(blocker.bar.material_override.billboard_mode==BaseMaterial3D.BILLBOARD_ENABLED,"enemy health bars face every battle camera")
	var safe_edges := true
	for pos in [Vector3(21,0,21),Vector3(-21,0,21),Vector3(21,0,-21),Vector3(-21,0,-21)]:
		view_rig.set_mode(2,pos,true)
		safe_edges = safe_edges and absf(camera.position.x)<=BattleCamera.ARENA_LIMIT+0.001 and absf(camera.position.z)<=BattleCamera.ARENA_LIMIT+0.001 and camera.position.y>3 and camera.position.distance_to(pos)>3
	check(safe_edges,"camera remains inside arena walls and lifts at map corners")
	view_rig.set_mode(0,player.position,true)
	eye_before = camera.position
	view_rig.set_mode(2,player.position)
	var initially_still: bool = camera.position==eye_before
	view_rig.update(player.position,0.016)
	check(initially_still and camera.position.distance_to(eye_before)>0 and camera.position.distance_to(eye_before)<10,"switching views transitions smoothly rather than teleporting")
	playing = false
	zoom_before = view_rig.zoom_value
	yaw_before = view_rig.yaw
	view_drag = true
	_input(motion)
	_unhandled_input(mouse)
	key.keycode = KEY_V
	_unhandled_key_input(key)
	check(not view_drag and view_rig.yaw==yaw_before and view_rig.zoom_value==zoom_before and view_rig.mode==2,"paused battles ignore camera controls")
	playing = true
	view_rig.yaw = 0.7
	start_game(0)
	check(view_rig.mode==2 and view_rig.yaw==0 and camera.position.distance_to(player.position)>3,"restart preserves view choice and recenters safely")
	view_button.pressed.emit()
	check(view_rig.mode==0 and view_button.text.contains(BattleCamera.NAMES[0]) and view_button.visible,"on-screen view button switches mode and updates its label")

func campaign_visual_checks() -> void:
	for stage in range(3):
		start_game(0)
		begin_stage(stage)
		var budget := true
		for kind in range(5):
			var e := spawn_enemy(kind)
			var model: Node3D = e.node
			check(model.stage==stage and model.identity==kind and model.details>40,"stage %d enemy %d uses its themed articulated model" % [stage,kind])
			budget = budget and model.meshes.size()<=48 and model.meshes.size()<model.details
			model.phase = 0
			model.animate(0,false)
			var before: float = model.leg_l.rotation.x
			model.animate(0.1,true)
			var walked: bool = absf(model.leg_l.rotation.x-before)>0.01
			model.attack()
			model.animate(0.12,true)
			check(walked and model.jaw.rotation.x>0.4,"stage %d enemy %d has moving legs and an attack action" % [stage,kind])
			var restored := true
			for overlay in [white_flash,ice_overlay,null]:
				model.set_overlay(overlay)
				for part in model.meshes:
					restored = restored and part.material_overlay==overlay
			check(restored,"stage %d enemy %d retains hit and frost feedback" % [stage,kind])
			check(e.bar.global_position.y>model.head.global_position.y+0.1,"stage %d enemy %d health bar clears its head" % [stage,kind])
			model.set_overlay(white_flash)
			model.set_camera_occluded(true)
			var faded: bool = model.meshes[0].material_override.albedo_color.a<0.4 and model.meshes[0].material_overlay==null
			model.set_camera_occluded(false)
			check(faded and model.meshes[0].material_override==model.base_materials[0] and model.meshes[0].material_overlay==white_flash,"stage %d enemy %d fades and restores its own materials" % [stage,kind])
			model.set_overlay(null)
			var copy := CampaignEnemy.new()
			copy.build_for_stage(stage,kind,model.variant)
			check(copy.meshes[0].mesh==model.meshes[0].mesh,"stage %d enemy %d shares baked geometry within its type" % [stage,kind])
			copy.free()
			if stage==0:
				check(model.rear_legs.size()==2 and model.tail!=null and model.arm_l==null,"infected animal %d has four legs and a tail instead of human arms" % kind)
		check(budget,"stage %d enemy render mesh count stays bounded" % stage)
		var model: Node3D = enemies[0].node
		var before_phase: float = model.phase
		model.animate(0.1,true,true)
		check(is_equal_approx(model.phase-before_phase,0.29 if stage==0 else 0.21),"stage %d frost halves animation speed" % stage)
		clear_battle()
		spawn_clock = 100
		attack_clock = 100
		invuln = 0
		var ranged := spawn_enemy(3)
		ranged.node.position = Vector3(0,0,-6)
		ranged.cooldown = 0
		step(0.01)
		check(bullets.size()==1 and bullets[0].node.position.distance_to(ranged.node.mouth_position())<0.1,"stage %d ranged attack launches from its actual model" % stage)
		for i in range(30): step(0.05)
		check(is_equal_approx(hp,max_hp-ranged.data.damage) and bullets.is_empty(),"stage %d projectile reaches and damages the player once" % stage)
		gallery_stage = stage
		show_zombie_gallery()
		var correct: bool = portrait_rigs.size()==5
		for i in range(portrait_rigs.size()):
			correct = correct and portrait_rigs[i] is CampaignEnemy and portrait_rigs[i].stage==stage and portrait_rigs[i].identity==i
		check(correct,"stage %d bestiary uses all five actual battle models" % stage)
		var portrait: Node3D = portrait_rigs[0]
		var yaw := portrait.rotation.y
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = Vector2(40,0)
		portrait.get_parent().get_parent().gui_input.emit(motion)
		check(portrait.rotation.y>yaw+0.5,"stage %d bestiary supports model rotation" % stage)
	check(stage_scenes[0].name=="Savanna" and stage_scenes[1].name=="PyramidNecropolis" and stage_scenes[2].name=="GreatWallFortress","campaign builds three distinct environment roots")
	var wolf := CampaignEnemy.new()
	var mummy := CampaignEnemy.new()
	var clay := CampaignEnemy.new()
	wolf.build_for_stage(0,0)
	mummy.build_for_stage(1,0)
	clay.build_for_stage(2,0)
	check(wolf.meshes[0].mesh!=mummy.meshes[0].mesh and mummy.meshes[0].mesh!=clay.meshes[0].mesh,"shared mesh cache cannot mix different campaign themes")
	wolf.free()
	mummy.free()
	clay.free()

func campaign_flow_checks() -> void:
	start_game(1)
	var total_kills := 0
	for stage in range(3):
		check(stage_index==stage and playing and not choosing,"stage %d begins in the required campaign order" % stage)
		var visible_maps := 0
		for scene in stage_scenes:
			if is_instance_valid(scene) and scene.visible: visible_maps += 1
		check(visible_maps==1 and stage_scenes[stage].visible and stage_scenes[stage].landmark_count>=3,"stage %d shows only its map and themed landmarks" % stage)
		for wave in range(3):
			attack_clock = 100
			spawn_clock = 0
			var queue: Array = Campaign.WAVES[stage][wave]
			for i in range(queue.size()): update_campaign_spawns(3)
			check(enemies.size()==queue.size() and wave_spawned==queue.size(),"stage %d wave %d spawns its exact finite quota" % [stage,wave])
			var before := enemies.size()
			for i in range(8): update_campaign_spawns(10)
			check(enemies.size()==before,"stage %d wave %d cannot endlessly respawn" % [stage,wave])
			if wave==2:
				var boss: Dictionary = enemies.back()
				check(boss.kind==4 and boss_spawned,"stage %d boss arrives only in the final wave" % stage)
				hurt(boss,boss.hp+1)
				step(0.001)
				check(not choosing and playing and not stage_cleared,"stage %d boss death cannot ignore surviving enemies" % stage)
			for e in enemies: hurt(e,e.hp+1)
			step(0.001)
			if wave<2:
				check(wave_index==wave+1 and wave_spawned==0 and spawn_clock>0,"stage %d advances to wave %d only after clearing enemies" % [stage,wave+1])
			total_kills += queue.size()
		check(stage_kills==Campaign.total(stage) and stage_spawned==Campaign.total(stage),"stage %d completes its full required enemy count" % stage)
		if stage<2:
			check(choosing and between_stages and not campaign_won,"stage %d opens the intermission upgrade instead of final victory" % stage)
			var old_stage := stage_index
			var old_elapsed := elapsed
			auto_test = false
			_process(0.5)
			auto_test = true
			check(stage_index==old_stage and elapsed==old_elapsed,"intermission freezes battle and waits for an upgrade")
			# Leave hostile and friendly flight behind; transition must remove all of it.
			var projectile := Node3D.new()
			world.add_child(projectile)
			bullets.append({"node":projectile})
			shots.append({"unused":true})
			swings.append({"unused":true})
			fx.wave(Vector3.ZERO,2,Color.WHITE,1)
			hp = 1
			q_clock = 20
			e_clock = 20
			xp = 3
			level = 3
			var old_damage := damage_mult
			var old_max := max_hp
			upgrade(stage)
			check(hp==max_hp and q_clock==0 and e_clock==0 and dash_clock==0,"stage transition fully heals and refreshes skills")
			check(kills==total_kills and xp==3 and level==3 and damage_mult>=old_damage and max_hp>=old_max,"stage transition preserves hero progress and upgrades")
			check(enemies.is_empty() and bullets.is_empty() and shots.is_empty() and swings.is_empty() and fx.active.is_empty(),"stage transition removes previous enemies, projectiles and effects")
			check(player.position==Vector3.ZERO and stage_kills==0 and stage_spawned==0,"new stage resets local objectives and safely positions the hero")
	check(campaign_won and not playing and stage_index==2 and kills==84,"all 84 enemies across three cleared stages produce the final victory")
	start_game(2)
	check(stage_index==0 and wave_index==0 and stage_spawned==0 and kills==0 and not campaign_won and damage_mult==1 and level==1,"restart returns to the savanna and clears campaign progress")
	for i in range(50): step(0.05)
	var old_clock := spawn_clock
	var old_count := stage_spawned
	playing = false
	auto_test = false
	_process(5)
	auto_test = true
	check(spawn_clock==old_clock and stage_spawned==old_count,"pause freezes campaign spawn timers and quotas")

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
		attack_clock = 0
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
	invuln = 0
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
		check(e.hp==Campaign.stats(0,kind,ENEMIES[kind]).hp,"campaign enemy %d stats" % kind)
	var old_hp := hp
	invuln = 0
	damage_player(10)
	damage_player(10)
	check(hp==old_hp-10,"damage and invulnerability")
	upgrade(0)
	check(damage_mult>1,"damage upgrade")
	upgrade(1)
	check(max_hp==260,"health upgrade")
	var boss := enemies.back() as Dictionary
	hurt(boss,2000)
	check(playing and kills==1 and not campaign_won,"boss kill alone cannot bypass the campaign")
	start_game(1)
	invuln = 0
	damage_player(1000)
	check(not playing,"defeat")
	start_game(2)
	check(playing and kills==0 and hp==160,"restart resets state")
	for i in range(600):
		invuln = 1
		step(0.1)
	check(stage_spawned>0 and stage_spawned<=Campaign.total(0) and elapsed>59,"60 second finite-wave simulation")
	start_game(0)
	elapsed = 149.99
	step(0.02)
	check(not boss_spawned and stage_spawned<=1,"elapsed time cannot skip waves or spawn an early boss")
	elapsed = 239.99
	step(0.02)
	check(playing,"campaign has no former four-minute survival deadline")
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
	campaign_visual_checks()
	campaign_flow_checks()
	camera_checks()
	print("SMOKE TEST COMPLETE")
	get_tree().quit(0)

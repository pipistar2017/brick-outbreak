extends Node3D
## A deterministic ending sequence; battle timers never advance during this scene.
signal completed
const Guardian = preload("res://galaxy_guardian.gd")
var guardian: Node3D
var overlay: CanvasLayer
var dialogue: Label
var speaker: Label
var next_button: Button
var pillar: MeshInstance3D
var landing_ring: MeshInstance3D
var age := 0.0
var page := -1
var done := false
var landed := false
var lines: Array = []

func setup(hero_name: String) -> void:
	lines = [
		["银河超级英雄","恭喜你，%s！你成功闯过三关，守护了这片大地。" % hero_name],
		[hero_name,"谢谢！你是……？"],
		["银河超级英雄","我是银河超级护卫队的队员。欢迎加入银河超级护卫队！"],
		[hero_name,"我愿意加入！让我们一起守护银河！"],
		["银河超级英雄","接下来的旅途，我们会一起并肩作战！"]
	]
	guardian = Guardian.new()
	guardian.build_guardian()
	add_child(guardian)
	guardian.position = Vector3(2,12,0)
	guardian.rotation.y = PI/3
	landing_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.15
	ring.outer_radius = 1.25
	ring.rings = 48
	ring.ring_segments = 8
	landing_ring.mesh = ring
	landing_ring.material_override = Guardian.mat(Color("ffb943"),false,true)
	landing_ring.position = Vector3(2,0.06,0)
	add_child(landing_ring)
	pillar = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.7
	beam.bottom_radius = 1.2
	beam.height = 14
	pillar.mesh = beam
	pillar.position = Vector3(2,7,0)
	var glow := StandardMaterial3D.new()
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1,0.72,0.18,0.10)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar.material_override = glow
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pillar)
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var input_shield := Control.new()
	input_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(input_shield)
	var title := Label.new()
	title.text = "远征胜利 · 银河来客"
	title.position = Vector2(48,28)
	title.add_theme_font_size_override("font_size",32)
	title.add_theme_color_override("font_color",Color("ffdc82"))
	input_shield.add_child(title)
	var skip := Button.new()
	skip.text = "跳过演出"
	skip.position = Vector2(1090,32)
	skip.size = Vector2(140,44)
	skip.pressed.connect(finish_scene)
	input_shield.add_child(skip)
	var plate := PanelContainer.new()
	plate.position = Vector2(48,575)
	plate.size = Vector2(1184,193)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.045,0.08,0.96)
	style.border_color = Color("d5ad53")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	plate.add_theme_stylebox_override("panel",style)
	input_shield.add_child(plate)
	var content := Control.new()
	content.custom_minimum_size = Vector2(1180,189)
	plate.add_child(content)
	speaker = Label.new()
	speaker.position = Vector2(24,14)
	speaker.add_theme_font_size_override("font_size",24)
	speaker.add_theme_color_override("font_color",Color("ffce6d"))
	content.add_child(speaker)
	dialogue = Label.new()
	dialogue.position = Vector2(24,55)
	dialogue.size = Vector2(1120,64)
	dialogue.add_theme_font_size_override("font_size",24)
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(dialogue)
	next_button = Button.new()
	next_button.position = Vector2(850,135)
	next_button.size = Vector2(300,40)
	next_button.pressed.connect(next_line)
	content.add_child(next_button)
	speaker.text = "天空传来一道金色光芒……"
	dialogue.text = "一位红金机甲超级英雄正从天而降。"
	next_button.text = "超级英雄正在降落"
	next_button.disabled = true

func advance(delta: float) -> void:
	if done: return
	age += maxf(0,delta)
	guardian.animate(delta,false)
	if not landed:
		var t := clampf(age/3.0,0,1)
		guardian.position.y = 12.0*pow(1-t,2)
		landing_ring.scale = Vector3.ONE*(0.7+0.3*sin(age*4))
		if t>=1:
			landed = true
			guardian.position.y = 0
			pillar.hide()
			page = 0
			show_line()
	else:
		landing_ring.scale = Vector3.ONE*(1.0+minf(1,(age-3)*0.7))
		landing_ring.visible = age<4.5

func show_line() -> void:
	speaker.text = lines[page][0]
	dialogue.text = lines[page][1]
	next_button.disabled = false
	next_button.text = "完成对话 · 查看结算" if page==lines.size()-1 else "继续对话  ·  Enter / 空格"

func next_line() -> void:
	if not landed or done: return
	if page+1>=lines.size():
		finish_scene()
	else:
		page += 1
		show_line()

func finish_scene() -> void:
	if done: return
	done = true
	completed.emit()

extends RefCounted
## Camera heading is independent from the hero's automatic attack facing.
const NAMES = ["俯视战场","斜视战场","第三人称跟随"]
const DEFAULT_PITCH = [50.2,36.0,18.0]
const DEFAULT_ZOOM = [22.0,18.0,7.5]
const MIN_ZOOM = [14.0,12.0,5.0]
const MAX_ZOOM = [32.0,26.0,11.0]
const MIN_PITCH = [45.0,25.0,10.0]
const MAX_PITCH = [78.0,58.0,38.0]
const ARENA_LIMIT = 22.2
var camera: Camera3D
var mode := 0
var yaw := 0.0
var pitch := deg_to_rad(50.2)
var zoom_value := 22.0
var focus := Vector3.ZERO

func _init(target: Camera3D) -> void:
	camera = target
	camera.near = 0.1
	camera.far = 120

func set_mode(index: int, player_pos: Vector3, snap := false) -> void:
	var old_projection := camera.projection
	mode = posmod(index,3)
	pitch = deg_to_rad(DEFAULT_PITCH[mode])
	zoom_value = DEFAULT_ZOOM[mode]
	var desired_projection := Camera3D.PROJECTION_ORTHOGONAL if mode==0 else Camera3D.PROJECTION_PERSPECTIVE
	if not snap and old_projection!=desired_projection:
		# Match apparent scale at the projection change, then smoothly approach the preset.
		var distance := maxf(1,camera.position.distance_to(focus))
		if desired_projection==Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = clampf(2*distance*tan(deg_to_rad(camera.fov)*0.5),4,40)
		else:
			camera.fov = clampf(rad_to_deg(2*atan(camera.size/(2*distance))),25,85)
	camera.projection = desired_projection
	update(player_pos,0,snap)

func recenter(player_pos: Vector3, snap := false) -> void:
	yaw = 0
	pitch = deg_to_rad(DEFAULT_PITCH[mode])
	zoom_value = DEFAULT_ZOOM[mode]
	update(player_pos,0,snap)

func orbit(relative: Vector2) -> void:
	yaw = wrapf(yaw-relative.x*0.006,-PI,PI)
	pitch = clampf(pitch+relative.y*0.005,deg_to_rad(MIN_PITCH[mode]),deg_to_rad(MAX_PITCH[mode]))

func zoom(amount: float) -> void:
	zoom_value = clampf(zoom_value+amount*(1.3 if mode==0 else 0.8),MIN_ZOOM[mode],MAX_ZOOM[mode])

func movement_axis(input: Vector2) -> Vector3:
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0
	forward.y = 0
	var result := right.normalized()*input.x-forward.normalized()*input.y
	return result.normalized() if result.length()>1 else result

func update(player_pos: Vector3, delta: float, snap := false) -> void:
	var forward := Vector3.FORWARD.rotated(Vector3.UP,yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP,yaw)
	var pivot := player_pos+Vector3(0,0.65 if mode==0 else 1.45 if mode==2 else 0.9,0)
	var look_ahead := 2.0 if mode==2 else 0.0
	var wanted_focus := pivot+forward*look_ahead
	var distance := 31.0 if mode==0 else zoom_value
	var eye := pivot-forward*cos(pitch)*distance+Vector3.UP*sin(pitch)*distance
	if mode==2:
		eye += right*0.65
	# This arena has no internal walls. Stay inside its perimeter blocks and lift at edges.
	eye.x = clampf(eye.x,-ARENA_LIMIT,ARENA_LIMIT)
	eye.z = clampf(eye.z,-ARENA_LIMIT,ARENA_LIMIT)
	if mode==2:
		var horizontal := Vector2(eye.x-player_pos.x,eye.z-player_pos.z).length()
		eye.y += maxf(0,5-horizontal)
	eye.y = maxf(eye.y,player_pos.y+2.1)
	var weight := 1.0 if snap else 1-exp(-delta*10)
	focus = wanted_focus if snap else focus.lerp(wanted_focus,weight)
	camera.position = eye if snap else camera.position.lerp(eye,weight)
	var fov := 64.0 if mode==2 else 58.0
	camera.fov = fov if snap else lerpf(camera.fov,fov,weight)
	camera.size = zoom_value if snap else lerpf(camera.size,zoom_value,weight)
	if camera.position.distance_to(focus)>0.01:
		camera.look_at(focus,Vector3.UP)

func blocks_player(enemy_pos: Vector3, scale: float, player_pos: Vector3) -> bool:
	if mode==0:
		return false
	var radius := maxf(0.45,scale*0.70)
	var enemy := Vector2(enemy_pos.x,enemy_pos.z)
	var player := Vector2(player_pos.x,player_pos.z)
	if enemy.distance_to(player)<radius+0.25:
		return true
	var eye := Vector2(camera.position.x,camera.position.z)
	var segment := player-eye
	if segment.length_squared()<0.01:
		return false
	var t := (enemy-eye).dot(segment)/segment.length_squared()
	if t<=0.02 or t>=0.98:
		return false
	var closest := eye+segment*t
	var height := lerpf(camera.position.y,player_pos.y+1.4,t)
	return enemy.distance_to(closest)<radius and height>enemy_pos.y+0.1 and height<enemy_pos.y+2.6*scale

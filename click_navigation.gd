extends RefCounted
## Ground-plane picking works for both orthographic and perspective battle cameras.
static func ground_point(camera: Camera3D, screen: Vector2) -> Variant:
	return Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))

static func destination(point: Vector3, origin: Vector3, blocked: bool) -> Vector3:
	var goal := Vector3(clampf(point.x,-21,21),0,clampf(point.z,-21,21))
	if blocked and goal.length()<2.8:
		var outward := origin.normalized() if origin.length()>0.01 else Vector3.BACK
		goal = outward*2.8
	return goal

static func clear_segment(a: Vector3, b: Vector3) -> bool:
	return Geometry3D.get_closest_point_to_segment(Vector3.ZERO,a,b).length()>=2.649

static func route(origin: Vector3, goal: Vector3, blocked: bool) -> Array[Vector3]:
	if not blocked or clear_segment(origin,goal): return [goal]
	# Visibility graph around the landed circle. Decorations are non-colliding scenery.
	var vertices: Array[Vector3] = [origin,goal]
	for i in range(24):
		var angle := i*TAU/24
		vertices.append(Vector3(sin(angle),0,cos(angle))*2.95)
	var distance: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for i in range(vertices.size()):
		distance.append(INF)
		previous.append(-1)
		visited.append(false)
	distance[0] = 0
	for iteration in range(vertices.size()):
		var current := -1
		for i in range(vertices.size()):
			if not visited[i] and (current<0 or distance[i]<distance[current]): current = i
		if current<0 or distance[current]==INF: break
		if current==1: break
		visited[current] = true
		for next in range(vertices.size()):
			if visited[next] or not clear_segment(vertices[current],vertices[next]): continue
			var cost := distance[current]+vertices[current].distance_to(vertices[next])
			if cost<distance[next]:
				distance[next] = cost
				previous[next] = current
	var result: Array[Vector3] = []
	var cursor := 1
	if previous[cursor]<0: return result
	while cursor>0:
		result.push_front(vertices[cursor])
		cursor = previous[cursor]
	return result

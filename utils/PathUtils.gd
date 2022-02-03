class_name PathUtils


static func flatten_curve(curve: Curve3D) -> void:
	var point_count = curve.get_point_count()
	for i in point_count:
		var p = curve.get_point_position(i)
		p.y = 0.0
		curve.set_point_position(i, p)
		p = curve.get_point_in(i)
		p.y = 0
		curve.set_point_in(i, p)
		p = curve.get_point_out(i)
		p.y = 0
		curve.set_point_out(i, p)
	
	
static func twist_curve(curve: Curve3D, path_twists = PoolIntArray()) -> void:
	var twist_count = 0 if path_twists == null else path_twists.size()
	var curve_point_count = curve.get_point_count()
	if twist_count > 0:
		if twist_count > 0:
			for i in curve_point_count:
				var twist_i = i if i < twist_count - 1 else twist_count - 1
				var twist = path_twists[twist_i]
				curve.set_point_tilt(i, twist / 180.0 * PI)
	else:
		for i in curve_point_count:
			curve.set_point_tilt(i, 0.0)
	
	
static func get_curve_center(curve: Curve3D) -> Vector3:
	var point_count = curve.get_point_count()
	var center = Vector3.ZERO
	for i in point_count:
		center += curve.get_point_position(i)
	return center / float(point_count)
	
	
static func move_curve(curve: Curve3D, offset: Vector3) -> void:
	var point_count = curve.get_point_count()
	var center = Vector3.ZERO
	for i in point_count:
		var p = curve.get_point_position(i)
		p += offset
		curve.set_point_position(i, p)
	
	
static func curve_to_points(curve: Curve3D, interpolate: int, inverted: bool) -> PathData:
	var points = curve.tessellate(interpolate, 2)
	var path = PathData.new(points)
	if inverted:
		path = invert(path)
	return path
	
	
static func curve_to_path(curve: Curve3D, interpolate: int, inverted: bool, path_twists = PoolIntArray()) -> PathData:
	curve = curve.duplicate()
	var use_twists = path_twists != null
	if use_twists:
		twist_curve(curve, path_twists)
	var curved_path = curve_to_points(curve, interpolate, inverted)
	var point_count = curved_path.point_count
	var points = PoolVector3Array()
	points.resize(point_count)
	var ups = PoolVector3Array()
	ups.resize(point_count)
	var length = 0.0
	for i in point_count:
		points[i] = curved_path.get_point(i)
		if not use_twists or i == 0:
			ups[i] = Vector3.UP
		else:
			var dif = points[i] - points[i - 1]
			length += dif.length()
			ups[i] = curve.interpolate_baked_up_vector(length, true)
	return PathData.new(points, ups)
	

static func path_to_outline(path: PathData, width: float) -> PathData:
	var point_count = path.points.size()
	var ups_count = path.ups.size()
	var point_total = point_count * 2
	var path_points = PoolVector3Array()
	path_points.resize(point_total)
	var path_ups = PoolVector3Array()
	path_ups.resize(point_total)
	for i in point_count:
		var dir = Vector3.FORWARD
		if i > 0:
			var dif = path.points[i] - path.points[i - 1]
			dir = dif.normalized()
		else:
			dir = (path.points[i + 1] - path.points[i]).normalized()
		
		var up = path.get_up(i)
		var p = path.points[i]
		var out = dir.cross(up)
		var a = p + out * width * 0.5
		var b = p - out * width * 0.5
		path_points[i] = a
		path_points[point_total - 1 - i] = b
		path_ups[i] = up
		path_ups[point_total - 1 - i] = up
	return PathData.new(path_points, path_ups)
	
	
static func move_path(path: PathData, offset: Vector3) -> PathData:
	var point_count = path.points.size()
	var result = PoolVector3Array()
	result.resize(point_count)
	for i in point_count:
		var p = path.points[i]
		p += offset
		result[i] = p
	return PathData.new(result, path.ups)
	
	
static func move_path_down(path: PathData, amount: float = 0.0) -> PathData:
	return move_path_up(path, -amount)
	

static func move_path_up(path: PathData, amount: float = 0.0) -> PathData:
	var point_count = path.points.size()
	var up_count = path.ups.size()
	var result = PoolVector3Array()
	result.resize(point_count)
	for i in point_count:
		var up = Vector3.UP
		if i < up_count:
			up = path.ups[i]
		var p = path.points[i]
		p += up * amount
		result[i] = p
	return PathData.new(result, path.ups)
	
	
static func cap_taper(a: Vector3, b: Vector3, width: float) -> Vector3:
	var right = (b - a).normalized()
	var out = right.cross(Vector3.UP)
	return a + out * width
	
	
static func invert(path: PathData) -> PathData:
	var point_count = path.points.size()
	var result_points = PoolVector3Array()
	result_points.resize(point_count)
	var result_ups = PoolVector3Array()
	result_ups.resize(point_count)
	for i in point_count:
		var index = point_count - 1 - i
		result_points[i] = path.get_point(index)
		result_ups[i] = path.get_up(index)
	return PathData.new(result_points, result_ups)
	
	
static func taper_path(path: PathData, taper: float, clamp_opposite: bool = false) -> PathData:
	var point_count = path.points.size()
	var result = PoolVector3Array()
	result.resize(point_count)
	for i in point_count:
		var a = path.points[i]
		var b = path.points[(i + 1) % point_count]
		var z = path.points[(i + point_count - 1) % point_count]
		var angleb = atan2(b.z - a.z, b.x - a.x);
		var anglea = atan2(a.z - z.z, a.x - z.x);
		var angledif = fmod(angleb - anglea + PI, PI * 2.0) - PI
		var taper_length = taper / cos(angledif * 0.5)
		var taper_angle = anglea + PI * 0.5 + angledif * 0.5
		var taper_vec = Vector3(
			cos(taper_angle) * taper_length, 
			0.0, 
			sin(taper_angle) * taper_length
		)
		result[i] = a + taper_vec
	return PathData.new(result, path.ups)
	
	
static func bevel_path(path: PathData, taper: float) -> PathData:
	var point_count = path.points.size()
	var up_count = path.ups.size()
	var result = PoolVector3Array()
	result.resize(point_count * 2)
	for i in point_count:
		var a = path.points[i]
		var bp = path.points[(i + 1) % point_count]
		var right = (bp - a).normalized()
		var up = path.get_up(i)
		var forward = right.cross(up)
		result[i * 2] = a + forward * taper
		result[i * 2 + 1] = bp + forward * taper
	return result
	
	
static func get_length(points: PoolVector3Array) -> float:
	var point_count = points.size()
	if point_count < 2:
		return 0.0
	var result = 0.0
	for i in range(1, point_count):
		var a = points[i - 1]
		var b = points[i]
		var dist = (a - b).length()
		result += dist
	return result
tool
extends CapBuilder

func build(style, path: PathData):
	var material = style.material
	
	var points = get_cap_points(style, path)
	var point_count = points.size()
	if point_count < 2:
		return
		
	var width = (points[point_count - 1] - points[0]).length()
	
	var sets = []
	
	var length = 0.0
	var line_points = point_count / 2
	for i in range(1, line_points):
		var a = points[i - 1]
		var b = points[i]
		var c = points[point_count - i]
		var d = points[point_count - i - 1]
		var dif = (b - a)
		var l = dif.length()
		var u_size = Vector2(length, length + l)
		var quad = MeshUtils.make_quad(b, a, d, c, u_size)
		quad.uvs = PoolVector2Array([
			Vector2(0, length + l),
			Vector2(0, length),
			Vector2(width, length + l),
			Vector2(width, length),
		])
		quad.normals = PoolVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		
		var quads = split_quad(quad)
		for set in quads:
			sets.append(set)
		#sets.append(quad)
		length += l
		
	var meshset = MeshUtils.weld_sets(sets)
	
	meshset.material = material
	return meshset
	
	
func split_quad(quad: MeshUtils.MeshSet) -> Array:
	return split_quad_four(quad)
	
	
func split_quad_four(quad: MeshUtils.MeshSet) -> Array:
	var sets = []
	var a = quad.clone()
	lerp_set(a, quad, 1, 0, 0.5)
	lerp_set(a, quad, 2, 0, 0.5)
	lerp_set(a, quad, 3, 1, 0.5)
	lerp_set(a, a, 3, 2, 0.5)
	sets.append(a)
	var b = quad.clone()
	lerp_set(b, quad, 0, 1, 0.5)
	lerp_set(b, quad, 3, 1, 0.5)
	lerp_set(b, quad, 2, 3, 0.5)
	lerp_set(b, b, 2, 0, 0.5)
	sets.append(b)
	var c = quad.clone()
	lerp_set(c, quad, 0, 2, 0.5)
	lerp_set(c, quad, 3, 2, 0.5)
	lerp_set(c, quad, 1, 0, 0.5)
	lerp_set(c, c, 1, 3, 0.5)
	sets.append(c)
	var d = quad.clone()
	lerp_set(d, quad, 1, 3, 0.5)
	lerp_set(d, quad, 2, 3, 0.5)
	lerp_set(d, quad, 0, 2, 0.5)
	lerp_set(d, d, 0, 1, 0.5)
	sets.append(d)
	return sets
	
	
func split_quad_length(quad: MeshUtils.MeshSet) -> Array:
	var sets = []
	var a = quad.clone()
	lerp_set(a, quad, 2, 0, 0.5)
	lerp_set(a, quad, 3, 1, 0.5)
	sets.append(a)
	var b = quad.clone()
	lerp_set(b, quad, 0, 2, 0.5)
	lerp_set(b, quad, 1, 3, 0.5)
	sets.append(b)
	return sets
	
	
func lerp_set(set, ref, a: int, b: int, amount: float) -> void:
	set.set_vert(a, lerp(ref.verts[a], ref.verts[b], amount))
	set.set_uv(a, lerp(ref.uvs[a], ref.uvs[b], amount))
	set.set_normal(a, lerp(ref.normals[a], ref.normals[b], amount))
		

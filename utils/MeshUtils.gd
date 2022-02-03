class_name MeshUtils

# mesh set
class MeshSet:
		
	var verts = PoolVector3Array()
	var uvs = PoolVector2Array()
	var normals = PoolVector3Array()
	var tris = PoolIntArray()
	var material: Material = null
	var vert_count setget ,get_vert_count
	var tri_count setget ,get_tri_count

	func set_counts(vert_count: int, tri_count: int) -> void:
		set_vert_count(vert_count)
		set_tri_count(tri_count)
		
	func set_vert_count(count: int) -> void:
		verts.resize(count)
		uvs.resize(count)
		normals.resize(count)
		
	func get_vert_count() -> int:
		return verts.size()
		
	func set_vert(i: int, v: Vector3) -> void:
		verts.set(i, v)
		
	func set_uv(i: int, v: Vector2) -> void:
		uvs.set(i, v)
		
	func set_normal(i: int, v: Vector3) -> void:
		normals.set(i, v)
		
	func set_tri(i: int, vert_i: int) -> void:
		tris.set(i, vert_i)
		
	func set_tri_count(count: int) -> void:
		tris.resize(count)
		
	func get_tri_count() -> int:
		return tris.size()

	func clone() -> MeshSet:
		var result = MeshSet.new()
		result.copy(self)
		return result
		
	func copy(other: MeshSet) -> void:
		verts = other.verts
		uvs = other.uvs
		normals = other.normals
		tris = other.tris
		
		
# statics	
static func make_cap(points: PoolVector3Array) -> MeshSet:
	var point_count = points.size()
	
	var set = MeshSet.new()
	set.set_vert_count(point_count)
	set.verts = points
	
	var tri_points = PoolVector2Array()
	tri_points.resize(point_count)
	
	for i in point_count:
		set.set_uv(i, Vector2(points[i].x, points[i].z))
		set.set_normal(i, Vector3.UP)
		tri_points[i] = Vector2(points[i].x, points[i].z)
	
	set.tris = Geometry.triangulate_polygon(tri_points)
	return set
	
"""
static func make_walls(points: PoolVector3Array, height: float, taper: float = 0.0) -> MeshSet:
	var point_count = points.size()
	var sets = []
	if taper > 0.0:
		var bottom_points = PathUtils.bevel_path(points, taper)
		bottom_points = PathUtils.move_path(bottom_points, Vector3.DOWN * height)
		build_tapered_sets(points, bottom_points, sets)
	else:
		var bottom_points = PathUtils.move_path(points, Vector3.DOWN * height)
		build_extruded_sets(points, bottom_points, sets)
	var set = weld_sets(sets)
	return set
"""


static func make_walls(path: PathData, height: float, taper: float = 0.0, bevel: float = 0.0) -> MeshSet:
	var sets = []
	var top_path = path;
	if bevel > 0.0:
		var bevel_path = PathUtils.taper_path(top_path, bevel)
		bevel_path = PathUtils.move_path_down(bevel_path, bevel)
		build_extruded_sets(top_path.points, bevel_path.points, sets)
		top_path = bevel_path
	var bottom_path = PathUtils.move_path_down(top_path, height - bevel)
	if taper != 0.0:
		bottom_path = PathUtils.taper_path(bottom_path, taper)
	build_extruded_sets(top_path.points, bottom_path.points, sets)
	var set = weld_sets(sets)
	return set
	
	
static func make_walls_tapered(path: PathData, height: float, taper: float = 0.0) -> MeshSet:
	var sets = []
	var bottom_path = PathUtils.taper_path(path, taper)
	bottom_path = PathUtils.move_path(bottom_path, Vector3.DOWN * height)
	build_extruded_sets(path.points, bottom_path.points, sets)
	var set = combine_sets(sets)
	return set
	
""""
static func make_walls_bevelled(path: PathData, height: float, taper: float = 0.0, bevel: float = 0.0, bevel_stages: int = 0) -> MeshSet:
	var point_count = path.points.size()
	var up_count = path.ups.size()
	
	var sets = []
	var bevel_dir = 1.0 if height >= 0.0 else -1.0
	
	var top_path = path
	if bevel_stages > 0 and bevel > 0.0:
		var current_bevel = 0.0
		var bevel_ratio = 1.0 / float(bevel_stages)
		var bevel_inc = bevel_ratio * bevel
		for i in bevel_stages:
			var pc = cos((i + 1) * PI) * 0.5 + 0.5
			current_bevel = pc * bevel - current_bevel
			var bottom_points = PathUtils.bevel_path(top_points, current_bevel)
			bottom_points = PathUtils.move_path(bottom_points, Vector3.DOWN * bevel_inc)
			build_tapered_sets(top_points, bottom_points, sets)
			top_points = bottom_points
		
	var bottom_points = PathUtils.bevel_path(top_points, taper)
	bottom_points = PathUtils.move_path(bottom_points, Vector3.DOWN * (height - taper))
	build_tapered_sets(top_points, bottom_points, sets)
	
	var set = combine_sets(sets)
	return set
"""
	
	
static func build_tapered_sets(points: PoolVector3Array, bevelled_points: PoolVector3Array, sets: Array = []) -> Array:
	var point_count = points.size()
	
	for i in point_count:
		var tl = points[i]
		var tr = points[(i + 1) % point_count]
		var bl = bevelled_points[i * 2]
		var br = bevelled_points[(i * 2 + 1) % (point_count * 2)]
		var brn = bevelled_points[(i * 2 + 2) % (point_count * 2)]
		sets.append(make_quad(tl, tr, bl, br))
		sets.append(make_tri(tr, br, brn))
		
	return sets
	
	
static func build_extruded_sets(points: PoolVector3Array, extruded_points: PoolVector3Array, sets: Array = []) -> Array:
	var point_count = points.size()
	
	var length = 0.0
	for i in point_count:
		var tl = points[i]
		var tr = points[(i + 1) % point_count]
		var tdif = (tr - tl)
		tdif.y = 0
		var length_add = tdif.length()
		var u_size = Vector2(length, length + length_add)
		length += length_add
		var bl = extruded_points[i]
		var br = extruded_points[(i + 1) % point_count]
		sets.append(make_quad(tl, tr, bl, br, u_size))
		
	return sets

	
static func make_quad(tl: Vector3, tr: Vector3, bl: Vector3, br: Vector3, u_size: Vector2 = Vector2.ZERO) -> MeshSet:
	var normal = (tr - tl).cross(bl - tl).normalized()
	var set = MeshSet.new()
	set.verts = PoolVector3Array([tl, tr, bl, br])
	if u_size != Vector2.ZERO:
		set.uvs = PoolVector2Array([
			Vector2(u_size.x, tl.y),
			Vector2(u_size.y, tr.y),
			Vector2(u_size.x, bl.y),
			Vector2(u_size.y, br.y)
		])
	elif false:
		set.uvs = PoolVector2Array([
			Vector2(0, 0),
			Vector2(1, 0),
			Vector2(0, 1),
			Vector2(1, 1)
		])
	else:
		set.uvs = vert_uv(set.verts, normal)
	set.normals = PoolVector3Array([normal, normal, normal, normal])
	set.tris = PoolIntArray([0, 1, 3, 2, 0, 3])
	return set
	
	
static func make_tri(a: Vector3, b: Vector3, c:Vector3) -> MeshSet:
	var normal = -(b - a).cross(c - a)
	var set = MeshSet.new()
	set.verts = PoolVector3Array([a, b, c])
	if false:
		set.uvs = PoolVector2Array([
			Vector2(0, 0),
			Vector2(1, 0),
			Vector2(1, 1)
		])
	else:
		set.uvs = vert_uv(set.verts, normal)
	set.normals = PoolVector3Array([normal, normal, normal])
	set.tris = PoolIntArray([0, 2, 1])
	return set
	
	
static func vert_uv(points: PoolVector3Array, normal: Vector3) -> PoolVector2Array:
	normal.y = 0
	var dot = normal.normalized().dot(Vector3.RIGHT)
	var use_x = abs(dot) < 0.5
	var point_count = points.size()
	var result = PoolVector2Array()
	result.resize(point_count)
	for i in point_count:
		var v = points[i]
		var x = v.x if use_x else v.z
		result.set(i, Vector2(x, v.y))
	return result
	
	
static func flip_normals(meshset: MeshSet) -> MeshSet:
	meshset = meshset.clone()
	var vert_vount = meshset.vert_count
	for i in vert_vount:
		meshset.set_normal(i, -meshset.verts[i])
	return meshset
	

static func wrap_mesh_to_path(meshset: MeshSet, path: PathData, close: bool) -> MeshSet:
	var points = path.points
	var point_count = points.size()
	if point_count < 2:
		return MeshSet.new()
	# close if needed
	if close:
		points.append(points[0])
		point_count += 1
	# calculate directions for segments
	var lengths = []
	lengths.resize(point_count)
	var length = 0.0
	for i in point_count:
		var n = (i + 1) % point_count
		var dif = points[n] - points[i]
		var section_length = dif.length()
		lengths[i] = section_length
		length += section_length
	# calculate segment sizes
	var min_x = INF
	var max_x = -INF
	for v in meshset.verts:
		if v.x < min_x:
			min_x = v.x
		if v.x > max_x:
			max_x = v.x
	var orig_seg_length = max_x - min_x
	var seg_count = int(round(length / orig_seg_length))
	var seg_length = length / seg_count
	var x_multi = seg_length / orig_seg_length
	# tile verts along x, build sets
	var sets = []
	for i in seg_count:
		var set = meshset.clone()
		var vert_count = set.verts.size()
		var start_x = i * seg_length
		for j in vert_count:
			var v = set.verts[j]
			v.x = start_x + v.x * x_multi
			set.set_vert(j, v)
			var uv = set.uvs[j]
			uv *= seg_length
			uv.x += seg_length * i
			set.set_uv(j, uv)
		sets.append(set)
	var set = combine_sets(sets)
	# wrap combined verts around path
	var vert_count = set.verts.size()
	for i in vert_count:
		var v = set.verts[i]
		var ai = 0
		var len_start = 0.0
		var len_end = 0.0
		for j in point_count:
			ai = j
			len_end = len_start + lengths[j]
			if v.x < len_end:
				break
			len_start = len_end
		ai = clampint(ai, 0, point_count - 1)
		var bi = ai + 1
		bi = clampint(bi, 0, point_count - 1)
		var pa = points[ai]
		var pb = points[bi]
		var ua = path.get_up(ai)
		var ub = path.get_up(bi)
		var pc = 0.0 if len_end == len_start else (v.x - len_start) / (len_end - len_start)
		var up = lerp(ua, ub, pc)
		var right = (pb - pa).normalized()
		var out = right.cross(up)
		var down = -up
		var orig_x = v.x - len_start
		var xt = orig_x * right
		var pt = pa + orig_x * right - v.y * down + v.z * out
		set.set_vert(i, pt)
		var n = set.normals[i]
		n = n.cross(-right)
		set.set_normal(i, n)
	return set
	

static func weld_sets(sets: Array, threshhold: float = 0.01) -> MeshSet:
	var merged = combine_sets(sets)
	
	var theshholdsq = threshhold * threshhold
	
	var tri_count = merged.tris.size()
	var trimap = []
	trimap.resize(tri_count)
	
	var vert_i = 0
	var verts = []
	var uvs = []
	var normals = []
	
	var merged_vert_count = merged.verts.size()
	for i in merged_vert_count:
		var ivert = merged.verts[i]
		var remap = -1
		for j in vert_i:
			var jvert = verts[j]
			var difsq = jvert.distance_squared_to(ivert)
			if difsq < theshholdsq:
				remap = j
				break
		if remap < 0:
			verts.append(ivert)
			normals.append(merged.normals[i])
			uvs.append(merged.uvs[i])
			trimap[i] = vert_i
			vert_i += 1
		else:
			trimap[i] = remap
	
	var set = MeshSet.new()
	set.verts = PoolVector3Array(verts)
	set.uvs = PoolVector2Array(uvs)
	set.normals = PoolVector3Array(normals)
	set.set_tri_count(tri_count)
	
	for i in tri_count:
		var value = merged.tris[i]
		set.set_tri(i, trimap[value])
	
	return merged
	
	
static func offset_mesh(meshset: MeshSet, offset: Vector3) -> MeshSet:
	var result = meshset.clone()
	var vert_count = meshset.vert_count
	for i in vert_count:
		var v = result.verts[i]
		v += offset
		result.set_vert(i, v)
	return result
			
			
static func combine_sets(sets: Array) -> MeshSet:
	var tri_count = 0
	var vert_count = 0
	for set in sets:
		tri_count += set.tris.size()
		vert_count += set.verts.size()
		
	var result = MeshSet.new()
	result.set_counts(vert_count, tri_count)
	
	var tri_i = 0
	var vert_i = 0
	var vert_offset = 0
	
	for set in sets:
		if not set is MeshSet:
			push_error("merging sets need to be mesh sets")
			return null
		var set_vert_count = set.verts.size()
		for i in set_vert_count:
			result.set_vert(vert_i, set.verts[i])
			result.set_uv(vert_i, set.uvs[i])
			result.set_normal(vert_i, set.normals[i])
			vert_i += 1
			
		var set_tri_count = set.tris.size()
		for i in set_tri_count:
			result.set_tri(tri_i, set.tris[i] + vert_offset)
			tri_i += 1
			
		vert_offset += set_vert_count
		
	return result
	
	
static func scale_mesh(meshset: MeshSet, new_scale: float) -> MeshSet:
	var result = meshset.clone()
	var vert_count = meshset.verts.size()
	var verts = PoolVector3Array(meshset.verts)
	verts.resize(vert_count)
	for i in vert_count:
		var v = meshset.verts[i]
		var scaled = Vector3(v.x * new_scale, v.y * new_scale, v.z * new_scale)
		verts[i] = scaled
	result.verts = verts
	return result
	
	
static func mesh_to_sets(mesh: Mesh) -> Array:
	var surface_count = mesh.get_surface_count()
	var result = []
	result.resize(surface_count)
	for i in surface_count:
		var meshset = MeshSet.new()
		var arr = mesh.surface_get_arrays(i)
		meshset.verts = arr[ArrayMesh.ARRAY_VERTEX]
		meshset.normals = arr[ArrayMesh.ARRAY_NORMAL]
		meshset.uvs = arr[ArrayMesh.ARRAY_TEX_UV]
		meshset.tris = arr[ArrayMesh.ARRAY_INDEX]
		result[i] = meshset
	return result
	
	
static func build_meshes(meshset_or_array, mesh: ArrayMesh = null) -> ArrayMesh:
	if meshset_or_array is Array:
		for meshset in meshset_or_array:
			mesh = build_mesh(meshset, mesh)
	else:
		mesh = build_mesh(meshset_or_array, mesh)
	return mesh
	
	
static func build_mesh(meshset: MeshSet, mesh: ArrayMesh = null) -> ArrayMesh:
	var arr = []
	arr.resize(ArrayMesh.ARRAY_MAX)
	arr[ArrayMesh.ARRAY_VERTEX] = PoolVector3Array(meshset.verts)
	arr[ArrayMesh.ARRAY_NORMAL] = PoolVector3Array(meshset.normals)
	arr[ArrayMesh.ARRAY_TEX_UV] = PoolVector2Array(meshset.uvs)
	arr[ArrayMesh.ARRAY_INDEX] = PoolIntArray(meshset.tris)
	if mesh == null:
		mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if meshset.material:
		var surf_idx = mesh.get_surface_count() - 1
		mesh.surface_set_material(surf_idx, meshset.material)
	return mesh
	
	
static func append_mesh(base_mesh: ArrayMesh, appendage: ArrayMesh) -> void:
	var surface_count = appendage.get_surface_count()
	for i in surface_count:
		var arr = appendage.surface_get_arrays(i)
		var mat = appendage.surface_get_material(i)
		base_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var surf_idx = base_mesh.get_surface_count() - 1
		base_mesh.surface_set_material(surf_idx, mat)
	

static func clampint(value: int, min_value: int, max_value: int) -> int:
	if value < min_value:
		return min_value
	if value > max_value:
		return max_value
	return value

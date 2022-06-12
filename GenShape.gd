@tool
extends Path3D
class_name GenShape


@export var inverted = false:
	set(value):
		inverted = value
		mark_dirty()
	
	
@export var recenter = false:
	set(value):
		if value:
			recenter_points()
	
	
@export var path_options: Resource:
	set = set_path_options
	
	
@export_file("*.tres") var shaper_file: String:
	set = set_shaper_file,
	get = get_shaper_file
	
	
@export var shaper: Resource:
	set = set_shaper

	
@export var cascade_twists = false:
	set(value):
		cascade_twists = value
		mark_dirty()
		

@export var path_twists : Array[int]:
	set = set_path_twists
	
	
@export var edit_axis_matching = false

var is_line: bool: get = get_is_line
var is_editing: bool: get = _get_is_editing

var is_dirty = false
var is_dragging = false
var edit_proxy = null
var cap_data: PathData = null
var mouse_down = false
var watcher_shaper := ResourceWatcher.new(mark_dirty)
var watcher_pathmod := ResourceWatcher.new(mark_dirty)


func _ready() -> void:
	if curve == null:
		curve = Curve3D.new()
	if not ResourceUtils.is_local(curve):
		curve = curve.duplicate(true)
		

func _enter_tree() -> void:
	set_display_folded(true)
	
	
func _exit_tree() -> void:
	if _get_is_editing():
		_edit_end()
		
		
func _get_is_editing() -> bool:
	return Engine.is_editor_hint() and self.edit_proxy != null
	
		
func _edit_begin(edit_proxy) -> void:
	if _get_is_editing():
		return
	print("editing %s" % name)
	self.edit_proxy = edit_proxy
	set_display_folded(true)
	if not _is_resource(shaper, Shaper):
		print("init shaper")
		_init_shaper()
	if not _is_resource(path_options, PathOptions):
		print("init path mod")
		_init_path_options()
		if not path_options.resource_local_to_scene:
			set_path_options(ResourceUtils.local_duplicate(path_options))
	if not _is_resource(curve, Curve3D) or curve.get_point_count() < 2:
		print("init curve")
		_init_curve()
	curve_changed.connect(mark_dirty)
	watcher_shaper.watch(shaper)
	watcher_pathmod.watch(path_options)
	
	
func _is_resource(resource: Resource, type) -> bool:
	if resource == null:
		return false
	if not resource is type:
		return false
	return true
	
	
func _init_shaper() -> void:
	set_shaper(edit_proxy.create_shaper())
	
	
func _init_path_options() -> void:
	set_path_options(edit_proxy.create_path_options())
	
	
func _init_curve() -> void:
	if not curve is Curve3D:
		curve = Curve3D.new()
	curve.clear_points()
	if path_options.line > 0.0:
		var extent = path_options.line * 0.5
		curve.add_point(Vector3(extent, 0, 0))
		curve.add_point(Vector3(-extent, 0, 0))
	else:
		var extent = 4.0
		curve.add_point(Vector3(-extent, 0, extent))
		curve.add_point(Vector3(extent, 0, extent))
		curve.add_point(Vector3(extent, 0, -extent))
		curve.add_point(Vector3(-extent, 0, -extent))
	
	
func _edit_end() -> void:
	self.edit_proxy = null
	watcher_shaper.unwatch()
	watcher_pathmod.unwatch()
	curve_changed.disconnect(mark_dirty)
	

func set_shaper_file(path: String) -> void:
	if path == null or path.length() < 1:
		return
	var res = load(path)
	set_shaper(res)
	
	
func get_shaper_file() -> String:
	if shaper == null or shaper.resource_local_to_scene:
		return ""
	return shaper.resource_path
	
	
func set_shaper(value: Resource) -> void:
	shaper = value
	watcher_shaper.watch(shaper)
	mark_dirty()
	
	
func set_path_options(value: Resource) -> void:
	path_options = value
	watcher_pathmod.watch(path_options)
	mark_dirty()
	
		
func recenter_points():
	var center = PathUtils.get_curve_center(curve)
	PathUtils.move_curve(curve, -center)
	transform.origin += center
	mark_dirty()

	
func mark_dirty():
	if _get_is_editing():
		is_dirty = true
		call_deferred("_update")
	
	
func get_is_line():
	return path_options.line > 0.0
	
	
func _update():
	if not _get_is_editing():
		return
	if not get_tree():
		return
	if not edit_proxy:
		return
	if not is_dirty:
		return
	if mouse_down:
		_update.call_deferred()
		return
	if is_dragging:
		_update.call_deferred()
		return
	
	build()
	is_dirty = false
	
	
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == 0:
			mouse_down = event.is_pressed()
	
	
func build() -> void:
	if path_options.flatten:
		PathUtils.flatten_curve(curve)
		
	if not path_options.flatten:
		PathUtils.twist_curve(curve)
	
	if not shaper:
		print("no shaper")
		return
	
	var runner = edit_proxy.runner
	if runner.is_busy:
		mark_dirty()
		return
		
	_build(runner)
		

func _build(runner: JobRunner) -> void:
	if not shaper:
		return
	print("Build %s" % name)
	for child in get_children():
		child.free()
	run_build_jobs(runner)
	is_dirty = false
	
	
func run_build_jobs(runner: JobRunner) -> void:
	shaper.build(self, get_path_data(path_options.interpolate))
	
		
func remove_control_points() -> void:
	PathUtils.remove_control_points(curve)
	mark_dirty()
	

func get_path_data(interpolate: int) -> PathData:
	var twists = _get_twists()
	if twists.size() < 1:
		twists = null
	var path_data = PathUtils.curve_to_path(curve, interpolate, inverted, twists)
	if path_options.line != 0:
		path_data = PathUtils.path_to_outline(path_data, path_options.line)
	if path_options.rounding > 0:
		path_data = PathUtils.round_path(path_data, path_options.rounding, interpolate)
	path_data.curve = curve.duplicate()
	return path_data


func _get_twists() -> PackedInt32Array:
	return PackedInt32Array(path_twists)
	

func set_path_twists(value: Array[int]):
	if value != null and path_twists != null and cascade_twists:
		var prev_twist_count = path_twists.size()
		var new_twist_count = value.size()
		if new_twist_count == prev_twist_count:
			var change_i = -1
			var change_a = 0.0
			for i in range(new_twist_count):
				if not value[i]:
					continue
				if value[i] != path_twists[i]:
					change_i = i
					change_a = value[i] - path_twists[i]
					break
			if change_i >= 0 and change_i < new_twist_count - 1:
				value = value.duplicate(true)
				for i in range(change_i + 1, new_twist_count):
					value[i] = value[i] + change_a
	path_twists = value
	mark_dirty()

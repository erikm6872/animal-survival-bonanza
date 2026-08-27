extends CanvasLayer

@onready var label: Label = $PanelContainer/MarginContainer/Label

const UPDATE_INTERVAL: float = 0.25

var _is_linux: bool = OS.get_name() == "Linux"
var _time_since_update: float = 0.0
var _last_cpu_time: float = 0.0
var _last_wall_time: float = 0.0

func _ready() -> void:
	if _is_linux:
		_last_cpu_time = _read_proc_cpu_time()
		_last_wall_time = Time.get_ticks_usec() / 1000000.0
	_update_text()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		visible = not visible

	if not visible:
		return

	_time_since_update += delta
	if _time_since_update < UPDATE_INTERVAL:
		return
	_time_since_update = 0.0
	_update_text()

func _update_text() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	label.text = "FPS: %d\nFrame: %.1f ms\nPhysics: %.1f ms\nRAM: %s\nCPU: %s\nDraw calls: %d\nObjects: %d\nNodes: %d" % [
		fps, frame_ms, physics_ms, _get_ram_string(), _get_cpu_string(), draw_calls, objects, nodes
	]

func _get_ram_string() -> String:
	if _is_linux:
		var vm_rss := _read_proc_status_kb("VmRSS")
		if vm_rss > 0.0:
			return "%.1f MB" % (vm_rss / 1024.0)
	var static_mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	return "%.1f MB (engine)" % (static_mem / 1024.0 / 1024.0)

func _get_cpu_string() -> String:
	if not _is_linux:
		return "N/A"
	var cpu_time := _read_proc_cpu_time()
	var wall_time := Time.get_ticks_usec() / 1000000.0
	var cpu_delta := cpu_time - _last_cpu_time
	var wall_delta := wall_time - _last_wall_time
	_last_cpu_time = cpu_time
	_last_wall_time = wall_time
	if wall_delta <= 0.0:
		return "N/A"
	return "%.1f%%" % ((cpu_delta / wall_delta) * 100.0)

## Reads a "Key:    value kB" line from /proc/self/status. Returns the value in kB, or -1 if not found.
func _read_proc_status_kb(key: String) -> float:
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	if file == null:
		return -1.0
	var result := -1.0
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with(key + ":"):
			var value_str := line.substr(key.length() + 1).strip_edges().replace(" kB", "")
			result = value_str.to_float()
			break
	file.close()
	return result

## Sums utime + stime (fields 14/15) from /proc/self/stat, in seconds, assuming the standard 100Hz clock tick.
func _read_proc_cpu_time() -> float:
	var file := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if file == null:
		return 0.0
	var line := file.get_line()
	file.close()
	var fields := line.split(" ")
	if fields.size() < 15:
		return 0.0
	var utime := fields[13].to_float()
	var stime := fields[14].to_float()
	return (utime + stime) / 100.0

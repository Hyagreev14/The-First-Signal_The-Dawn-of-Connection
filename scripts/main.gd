extends Node2D

const WORLD_SIZE := Vector2(2600, 1800)
const DEVICE_SIZE := Vector2(170, 110)

var devices := [
	{
		"id": 1,
		"name": "COMPUTER 01",
		"kind": "Computer",
		"position": Vector2(720, 720),
		"powered": false,
		"mac": "",
		"ip": ""
	},
	{
		"id": 2,
		"name": "COMPUTER 02",
		"kind": "Computer",
		"position": Vector2(1180, 720),
		"powered": false,
		"mac": "",
		"ip": ""
	}
]

var ethernet_connected := false
var selected_id := 1
var dragging_id := -1
var drag_offset := Vector2.ZERO
var camera_offset := Vector2.ZERO
var zoom := 0.9
var mouse_world := Vector2.ZERO
var toast := ""
var toast_time := 0.0

func _ready() -> void:
	randomize()
	for device in devices:
		device.mac = _make_mac()
	queue_redraw()

func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast = ""
			queue_redraw()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_world = _screen_to_world(event.position)
		if dragging_id != -1:
			var d = _get_device(dragging_id)
			d.position = mouse_world - drag_offset
			queue_redraw()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := _device_at(mouse_world)
			if hit != -1:
				selected_id = hit
				dragging_id = hit
				drag_offset = mouse_world - _get_device(hit).position
			else:
				selected_id = -1
			queue_redraw()
		else:
			dragging_id = -1

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 0.9)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_toggle_selected_power()
		elif event.keycode == KEY_F:
			camera_offset = Vector2.ZERO
			zoom = 0.9
			queue_redraw()

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera_offset += event.relative
		queue_redraw()

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Color("#080b10"))
	_draw_world(screen)
	_draw_header(screen)
	_draw_inspector(screen)
	_draw_controls(screen)
	if toast != "":
		_draw_toast(screen)

func _draw_world(screen: Vector2) -> void:
	var world_rect := Rect2(Vector2(0, 64), Vector2(screen.x, screen.y - 118))
	draw_rect(world_rect, Color("#0b1017"))
	
	# Infinite-feeling technical grid.
	var spacing := 64.0 * zoom
	var origin := Vector2(0, 64) + camera_offset
	while origin.x > 0: origin.x -= spacing
	while origin.y > 64: origin.y -= spacing
	var x := origin.x
	while x < screen.x:
		draw_line(Vector2(x, 64), Vector2(x, screen.y - 54), Color(0.12, 0.16, 0.21, 0.75), 1.0)
		x += spacing
	var y := origin.y
	while y < screen.y - 54:
		if y >= 64:
			draw_line(Vector2(0, y), Vector2(screen.x, y), Color(0.12, 0.16, 0.21, 0.75), 1.0)
		y += spacing

	# Cable first, so devices sit above it.
	if ethernet_connected:
		var a := _world_to_screen(_get_device(1).position)
		var b := _world_to_screen(_get_device(2).position)
		var pa := a + Vector2(DEVICE_SIZE.x * zoom * 0.5, 58 * zoom)
		var pb := b + Vector2(DEVICE_SIZE.x * zoom * 0.5, 58 * zoom)
		draw_line(pa, pb, Color("#18212c"), 10.0 * zoom, true)
		draw_line(pa, pb, Color("#5ee6a8"), 3.0 * zoom, true)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		var packet := pa.lerp(pb, fmod(Time.get_ticks_msec() / 1800.0, 1.0))
		draw_circle(packet, 5.0 + pulse * 2.0, Color("#b8ffdc"))
	
	for d in devices:
		_draw_device(d)

func _draw_device(d: Dictionary) -> void:
	var pos := _world_to_screen(d.position)
	var size := DEVICE_SIZE * zoom
	var rect := Rect2(pos, size)
	var selected := d.id == selected_id
	var body := Color("#141b24") if d.powered else Color("#0f141b")
	var edge := Color("#5ee6a8") if d.powered else Color("#34404d")
	if selected:
		draw_rect(rect.grow(5), Color(0.37, 0.90, 0.66, 0.12), true)
		draw_rect(rect.grow(3), Color("#7df2bd"), false, 2.0)
	draw_rect(rect, Color("#05070a"), true)
	draw_rect(rect.grow(-3), body, true)
	draw_rect(Rect2(pos + Vector2(0, size.y - 30 * zoom), Vector2(size.x, 30 * zoom)), Color("#10161f"), true)
	draw_rect(rect.grow(-3), edge, false, 2.0)
	
	var screen_rect := Rect2(pos + Vector2(20, 17) * zoom, Vector2(130, 55) * zoom)
	draw_rect(screen_rect, Color("#071016"), true)
	draw_rect(screen_rect, Color("#263441"), false, 2.0)
	if d.powered:
		draw_rect(screen_rect.grow(-7), Color("#10251e"), true)
		draw_string(ThemeDB.fallback_font, screen_rect.position + Vector2(8, 24) * zoom, "NETWORK READY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * zoom), Color("#72efb1"))
		draw_string(ThemeDB.fallback_font, screen_rect.position + Vector2(8, 42) * zoom, d.ip if d.ip != "" else "NO IPv4", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * zoom), Color("#9bb2c5"))
	else:
		draw_string(ThemeDB.fallback_font, screen_rect.position + Vector2(8, 33) * zoom, "POWER OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * zoom), Color("#687582"))
	draw_circle(pos + Vector2(size.x - 17, 16) * zoom, 5 * zoom, Color("#5ee6a8") if d.powered else Color("#3a434d"))
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, size.y - 10) * zoom, d.name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * zoom), Color("#dce7ef"))

func _draw_header(screen: Vector2) -> void:
	draw_rect(Rect2(0, 0, screen.x, 64), Color("#0a0e14"))
	draw_line(Vector2(0, 64), Vector2(screen.x, 64), Color("#202b36"), 1)
	draw_string(ThemeDB.fallback_font, Vector2(26, 29), "THE FIRST SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#edf5fa"))
	draw_string(ThemeDB.fallback_font, Vector2(26, 49), "THE DAWN OF CONNECTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 190, 31), "SIMULATION  v0.001", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#6e8190"))
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 190, 48), "WORLD ONLINE: %d DEVICES" % devices.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#536675"))

func _draw_inspector(screen: Vector2) -> void:
	var panel := Rect2(screen.x - 300, 82, 270, 430)
	draw_rect(panel, Color(0.035, 0.05, 0.07, 0.96), true)
	draw_rect(panel, Color("#263541"), false, 1)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 28), "DEVICE INSPECTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#728696"))
	if selected_id == -1:
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 75), "Select a device", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c7d4dc"))
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 101), "Drag devices to build your network.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#647785"))
		return
	var d := _get_device(selected_id)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 72), d.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#eef6fa"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 96), d.kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))
	_field(panel, "POWER", "ON" if d.powered else "OFF", 130)
	_field(panel, "MAC", d.mac, 174)
	_field(panel, "IPv4", d.ip if d.ip != "" else "—", 218)
	_field(panel, "LINK", "ETHERNET" if ethernet_connected else "DISCONNECTED", 262)
	_field(panel, "POSITION", "%d, %d" % [d.position.x, d.position.y], 306)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 360), "P  toggle power", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8fa2b0"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 381), "F  center world", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8fa2b0"))

func _field(panel: Rect2, label: String, value: String, y: float) -> void:
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#596c7a"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, y + 19), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c9d6de"))

func _draw_controls(screen: Vector2) -> void:
	var bar := Rect2(0, screen.y - 54, screen.x, 54)
	draw_rect(bar, Color("#0a0e14"), true)
	draw_line(Vector2(0, screen.y - 54), Vector2(screen.x, screen.y - 54), Color("#202b36"), 1)
	draw_string(ThemeDB.fallback_font, Vector2(22, screen.y - 22), "LMB  SELECT / DRAG     MMB  PAN     WHEEL  ZOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))
	var status := "ETHERNET LINK  ● CONNECTED" if ethernet_connected else "ETHERNET LINK  ○ OFFLINE"
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 270, screen.y - 22), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#72efb1") if ethernet_connected else Color("#718594"))

func _draw_toast(screen: Vector2) -> void:
	var box := Rect2(Vector2(24, screen.y - 104), Vector2(390, 38))
	draw_rect(box, Color("#111922"), true)
	draw_rect(box, Color("#344553"), false, 1)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(14, 24), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#dce8ef"))

func _toggle_selected_power() -> void:
	if selected_id == -1:
		return
	var d := _get_device(selected_id)
	d.powered = not d.powered
	if not d.powered:
		ethernet_connected = false
	_toast(("Powered ON " if d.powered else "Powered OFF ") + d.name)

func _get_device(id: int) -> Dictionary:
	for d in devices:
		if d.id == id:
			return d
	return devices[0]

func _device_at(p: Vector2) -> int:
	for d in devices:
		if Rect2(d.position, DEVICE_SIZE).has_point(p):
			return d.id
	return -1

func _world_to_screen(p: Vector2) -> Vector2:
	return p * zoom + camera_offset + Vector2(0, 64)

func _screen_to_world(p: Vector2) -> Vector2:
	return (p - camera_offset - Vector2(0, 64)) / zoom

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := _screen_to_world(screen_pos)
	zoom = clamp(zoom * factor, 0.45, 1.8)
	var after := _screen_to_world(screen_pos)
	camera_offset += (after - before) * zoom
	queue_redraw()

func _make_mac() -> String:
	var parts := []
	for i in 6:
		parts.append("%02X" % randi_range(0, 255))
	return ":".join(parts)

func _toast(message: String) -> void:
	toast = message
	toast_time = 2.0
	queue_redraw()

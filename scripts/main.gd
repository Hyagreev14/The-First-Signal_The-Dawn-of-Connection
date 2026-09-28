extends Node2D

const WORLD_SIZE := Vector2(2600, 1800)
const DEVICE_SIZE := Vector2(170, 110)
const CREATE_BUTTON := Rect2(24, 78, 190, 42)
const CURRENCY_START := 1000
const COMPUTER_COST := 100
const ETHERNET_COST := 25
const REDEEM_BUTTON := Rect2(24, 128, 190, 36)
const MENU_SIZE := Vector2(250, 240)

var devices: Array = []
var money := CURRENCY_START
var test_mode := false
var paused := false
var redeeming := false
var redeem_buffer := ""
var first_link_reward_claimed := false
var first_ipv4_reward_claimed := false

var ethernet_links: Array = []
var selected_id := -1
var dragging_id := -1
var drag_offset := Vector2.ZERO
var camera_offset := Vector2.ZERO
var zoom := 0.9
var mouse_world := Vector2.ZERO
var toast := ""
var toast_time := 0.0
var toast_is_error := false
var last_error := ""
var error_popup_visible := false
var context_device_id := -1
var context_position := Vector2.ZERO
var connection_menu := false
var connection_source_id := -1
var editing_ip := false
var ip_buffer := ""
var editing_name := false
var name_buffer := ""

func _ready() -> void:
	randomize()
	queue_redraw()

func _process(delta: float) -> void:
	if paused:
		queue_redraw()
		return
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast = ""
			queue_redraw()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not error_popup_visible and not editing_ip and not editing_name and not redeeming:
		paused = not paused
		context_device_id = -1
		connection_menu = false
		connection_source_id = -1
		_toast("GAME PAUSED" if paused else "GAME RESUMED")
		queue_redraw()
		return

	# Error popups must take priority over text editors so their CLOSE button
	# remains clickable even when the error was triggered while editing IPv4.
	if error_popup_visible:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			error_popup_visible = false
			# Keep the active editor open so the player can correct the value.
			queue_redraw()
		return

	if paused:
		return

	if redeeming:
		_handle_redeem_input(event)
		return

	if editing_ip:
		_handle_ip_input(event)
		return
	if editing_name:
		_handle_name_input(event)
		return

	if event is InputEventMouseMotion:
		mouse_world = _screen_to_world(event.position)
		if dragging_id != -1:
			var d = _get_device(dragging_id)
			d.position = mouse_world - drag_offset
			queue_redraw()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if error_popup_visible:
				error_popup_visible = false
				queue_redraw()
				return
			if context_device_id != -1:
				var action := _context_action_at(event.position)
				if action != "":
					_perform_context_action(action)
				else:
					context_device_id = -1
					connection_menu = false
					connection_source_id = -1
					queue_redraw()
				return
			if CREATE_BUTTON.has_point(event.position):
				_create_computer()
				return
			if REDEEM_BUTTON.has_point(event.position):
				_begin_redeem()
				return
			var inspector_action := _inspector_action_at(event.position)
			if inspector_action != "":
				_perform_inspector_action(inspector_action)
				return
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

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var hit := _device_at(mouse_world)
		if hit != -1:
			selected_id = hit
			context_device_id = hit
			connection_menu = false
			connection_source_id = -1
			context_position = event.position
			context_position.x = min(context_position.x, get_viewport_rect().size.x - MENU_SIZE.x - 10)
			context_position.y = min(context_position.y, get_viewport_rect().size.y - MENU_SIZE.y - 64)
			queue_redraw()
		else:
			context_device_id = -1
			connection_menu = false
			connection_source_id = -1
			queue_redraw()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 0.9)

	# Reliable single-key shortcuts. Ctrl/Alt combinations are handled poorly
	# by some Windows keyboard layouts, so the game uses F-keys instead.
	if event is InputEventKey and event.pressed and not event.echo:
		var shortcut_key: Key = event.keycode
		if shortcut_key == KEY_NONE:
			shortcut_key = event.physical_keycode
		if shortcut_key == KEY_F1:
			_toggle_selected_power()
			return
		elif shortcut_key == KEY_F2:
			if selected_id == -1:
				_error("Cannot connect: no computer is selected.")
			else:
				_perform_inspector_action("connect")
			return
		elif shortcut_key == KEY_F3:
			if selected_id == -1:
				_error("Cannot rename: no computer is selected.")
			else:
				_begin_name_edit(selected_id)
			return
		elif shortcut_key == KEY_F4:
			if selected_id == -1:
				_error("Cannot configure IPv4: no computer is selected.")
			else:
				_begin_ip_edit(selected_id)
			return
		elif shortcut_key == KEY_HOME:
			camera_offset = Vector2.ZERO
			zoom = 0.9
			queue_redraw()
			return
		elif shortcut_key == KEY_PAGEUP:
			_zoom_at(get_viewport_rect().size * 0.5, 1.1)
			return
		elif shortcut_key == KEY_PAGEDOWN:
			_zoom_at(get_viewport_rect().size * 0.5, 0.9)
			return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE:
		_delete_selected()
		return

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera_offset += event.relative
		queue_redraw()

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Color("#080b10"))
	_draw_world(screen)
	_draw_header(screen)
	_draw_currency(screen)
	_draw_build_button()
	_draw_inspector(screen)
	_draw_controls(screen)
	if context_device_id != -1:
		_draw_context_menu()
	if toast != "":
		_draw_toast(screen)
	if editing_ip:
		_draw_ip_editor(screen)
	if editing_name:
		_draw_name_editor(screen)
	if redeeming:
		_draw_redeem_editor(screen)
	if paused:
		_draw_pause_overlay(screen)
	if error_popup_visible:
		_draw_error_popup(screen)

func _draw_world(screen: Vector2) -> void:
	var world_rect := Rect2(Vector2(0, 64), Vector2(screen.x, screen.y - 118))
	draw_rect(world_rect, Color("#0b1017"))
	var spacing := 64.0 * zoom
	var origin := Vector2(0, 64) + camera_offset
	while origin.x > 0:
		origin.x -= spacing
	while origin.y > 64:
		origin.y -= spacing
	var x := origin.x
	while x < screen.x:
		draw_line(Vector2(x, 64), Vector2(x, screen.y - 54), Color(0.12, 0.16, 0.21, 0.75), 1.0)
		x += spacing
	var y := origin.y
	while y < screen.y - 54:
		if y >= 64:
			draw_line(Vector2(0, y), Vector2(screen.x, y), Color(0.12, 0.16, 0.21, 0.75), 1.0)
		y += spacing

	for link in ethernet_links:
		var source := _get_device(link.source_id)
		var target := _get_device(link.target_id)
		if source.is_empty() or target.is_empty():
			continue
		var a := _world_to_screen(source.position)
		var b := _world_to_screen(target.position)
		var pa := a + Vector2(DEVICE_SIZE.x * zoom * 0.5, 58 * zoom)
		var pb := b + Vector2(DEVICE_SIZE.x * zoom * 0.5, 58 * zoom)
		draw_line(pa, pb, Color("#18212c"), 10.0 * zoom, true)
		draw_line(pa, pb, Color("#5ee6a8"), 3.0 * zoom, true)
		var time := Time.get_ticks_msec() / 1000.0
		var forward_t := fmod(time * link.forward_speed + link.forward_offset, 1.0)
		var reverse_t := fmod(time * link.reverse_speed + link.reverse_offset, 1.0)
		var pulse_forward := 0.5 + 0.5 * sin(time * link.forward_pulse_speed + link.forward_pulse_offset)
		var pulse_reverse := 0.5 + 0.5 * sin(time * link.reverse_pulse_speed + link.reverse_pulse_offset)
		draw_circle(pa.lerp(pb, forward_t), 5.0 + pulse_forward * 2.0, Color("#b8ffdc"))
		draw_circle(pb.lerp(pa, reverse_t), 5.0 + pulse_reverse * 2.0, Color("#b8ffdc"))

	for d in devices:
		_draw_device(d)

func _draw_currency(screen: Vector2) -> void:
	var box := Rect2(screen.x - 330, 14, 130, 34)
	draw_rect(box, Color("#111a22"), true)
	draw_rect(box, Color("#3b5261"), false, 1.0)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(12, 22), "$ " + ("∞" if test_mode else str(money)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#72efb1"))

func _draw_device(d: Dictionary) -> void:
	var pos := _world_to_screen(d.position)
	var size := DEVICE_SIZE * zoom
	var rect := Rect2(pos, size)
	var selected: bool = d.id == selected_id
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
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 190, 31), "SIMULATION  v0.002", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#6e8190"))
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 190, 48), "WORLD ONLINE: %d DEVICES" % devices.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#536675"))

func _draw_build_button() -> void:
	draw_rect(CREATE_BUTTON, Color("#111a22"), true)
	draw_rect(CREATE_BUTTON, Color("#3b5261"), false, 1.0)
	draw_string(ThemeDB.fallback_font, CREATE_BUTTON.position + Vector2(14, 27), "+  BUILD COMPUTER  $100", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#dce8ef"))
	draw_rect(REDEEM_BUTTON, Color("#111a22"), true)
	draw_rect(REDEEM_BUTTON, Color("#3b5261"), false, 1.0)
	draw_string(ThemeDB.fallback_font, REDEEM_BUTTON.position + Vector2(14, 23), "REDEEM TEST CODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#dce8ef"))

func _draw_inspector(screen: Vector2) -> void:
	var panel := Rect2(screen.x - 300, 82, 270, 620)
	draw_rect(panel, Color(0.035, 0.05, 0.07, 0.96), true)
	draw_rect(panel, Color("#263541"), false, 1)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 28), "DEVICE INSPECTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#728696"))
	if selected_id == -1:
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 75), "No device selected", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c7d4dc"))
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 101), "Build a computer to begin.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#647785"))
		return
	var d := _get_device(selected_id)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 72), d.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#eef6fa"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 96), d.kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))
	_field(panel, "POWER", "ON" if d.powered else "OFF", 130)
	_field(panel, "MAC", d.mac, 174)
	_field(panel, "IPv4", d.ip if d.ip != "" else "—", 218)
	_field(panel, "LINK", "ETHERNET" if _device_has_link(d.id) else "DISCONNECTED", 262)
	_field(panel, "POSITION", "%d, %d" % [d.position.x, d.position.y], 306)
	_draw_inspector_button(panel, Rect2(18, 350, 112, 32), "POWER  [F1]")
	_draw_inspector_button(panel, Rect2(140, 350, 112, 32), "CONNECT  [F2]")
	_draw_inspector_button(panel, Rect2(18, 388, 112, 32), "RENAME  [F3]")
	_draw_inspector_button(panel, Rect2(140, 388, 112, 32), "IPv4  [F4]")
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 448), "DELETE  [Del]     PAUSE  [Esc]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#8fa2b0"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, 474), "HOME center   PgUp / PgDn zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#637684"))

func _draw_inspector_button(panel: Rect2, local_rect: Rect2, label: String) -> void:
	var r := Rect2(panel.position + local_rect.position, local_rect.size)
	draw_rect(r, Color("#111b24"), true)
	draw_rect(r, Color("#344553"), false, 1.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#d2e0e8"))

func _inspector_action_at(screen_pos: Vector2) -> String:
	if selected_id == -1:
		return ""
	var panel := Rect2(get_viewport_rect().size.x - 300, 82, 270, 620)
	var local := screen_pos - panel.position
	if Rect2(18, 350, 112, 32).has_point(local): return "power"
	if Rect2(140, 350, 112, 32).has_point(local): return "connect"
	if Rect2(18, 388, 112, 32).has_point(local): return "rename"
	if Rect2(140, 388, 112, 32).has_point(local): return "ip"
	return ""

func _perform_inspector_action(action: String) -> void:
	if action == "power":
		_toggle_selected_power()
	elif action == "connect":
		_open_connection_menu(selected_id)
	elif action == "rename":
		_begin_name_edit(selected_id)
	elif action == "ip":
		_begin_ip_edit(selected_id)
	elif action == "inspect":
		_toast("Inspecting " + _get_device(selected_id).name + ".")
	queue_redraw()

func _field(panel: Rect2, label: String, value: String, y: float) -> void:
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#596c7a"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(18, y + 19), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c9d6de"))

func _draw_controls(screen: Vector2) -> void:
	var bar := Rect2(0, screen.y - 54, screen.x, 54)
	draw_rect(bar, Color("#0a0e14"), true)
	draw_line(Vector2(0, screen.y - 54), Vector2(screen.x, screen.y - 54), Color("#202b36"), 1)
	draw_string(ThemeDB.fallback_font, Vector2(22, screen.y - 22), "LMB  SELECT / DRAG     RMB  DEVICE MENU     MMB  PAN     WHEEL  ZOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))
	var status := "ETHERNET LINKS  ● %d ACTIVE" % ethernet_links.size() if ethernet_links.size() > 0 else "ETHERNET LINKS  ○ OFFLINE"
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 270, screen.y - 22), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#72efb1") if ethernet_links.size() > 0 else Color("#718594"))

func _draw_context_menu() -> void:
	var menu := Rect2(context_position, MENU_SIZE)
	draw_rect(menu, Color("#0c1219"), true)
	draw_rect(menu, Color("#415462"), false, 1.0)

	if connection_menu:
		var source := _get_device(connection_source_id)
		draw_string(ThemeDB.fallback_font, menu.position + Vector2(14, 23), "CONNECT FROM " + source.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#edf5fa"))
		draw_line(menu.position + Vector2(12, 32), menu.position + Vector2(menu.size.x - 12, 32), Color("#273640"), 1)
		var row := 42.0
		for d in devices:
			if d.id == connection_source_id:
				continue
			var action := "target:%d" % d.id
			_context_item(menu, Rect2(8, row, menu.size.x - 16, 32), d.name, action)
			row += 36.0
		_context_item(menu, Rect2(8, menu.size.y - 40, menu.size.x - 16, 32), "CANCEL", "cancel_connect")
		return

	var d := _get_device(context_device_id)
	draw_string(ThemeDB.fallback_font, menu.position + Vector2(14, 23), d.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#edf5fa"))
	draw_line(menu.position + Vector2(12, 32), menu.position + Vector2(menu.size.x - 12, 32), Color("#273640"), 1)

	_context_item(menu, Rect2(8, 40, menu.size.x - 16, 34), "POWER " + ("OFF" if d.powered else "ON"), "power")
	_context_item(menu, Rect2(8, 76, menu.size.x - 16, 34), "DISCONNECT ETHERNET" if _device_has_link(d.id) else "CONNECT ETHERNET", "disconnect" if _device_has_link(d.id) else "connect")
	_context_item(menu, Rect2(8, 112, menu.size.x - 16, 34), "RENAME COMPUTER", "rename")
	_context_item(menu, Rect2(8, 148, menu.size.x - 16, 34), "CONFIGURE IPv4", "ip")
	_context_item(menu, Rect2(8, 184, menu.size.x - 16, 34), "INSPECT COMPUTER", "inspect")

func _context_item(menu: Rect2, item: Rect2, label: String, action: String) -> void:
	draw_rect(Rect2(menu.position + item.position, item.size), Color("#111b24"), true)
	draw_string(ThemeDB.fallback_font, menu.position + item.position + Vector2(12, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d2e0e8"))

func _context_action_at(pos: Vector2) -> String:
	var local := pos - context_position
	if local.x < 8 or local.x > MENU_SIZE.x - 8:
		return ""
	if connection_menu:
		var row := 42.0
		for d in devices:
			if d.id == connection_source_id:
				continue
			if local.y >= row and local.y < row + 32.0:
				return "target:%d" % d.id
			row += 36.0
		if local.y >= MENU_SIZE.y - 40 and local.y < MENU_SIZE.y - 8:
			return "cancel_connect"
		return ""

	if local.y >= 40 and local.y < 74:
		return "power"
	if local.y >= 76 and local.y < 110:
		return "disconnect" if _device_has_link(context_device_id) else "connect"
	if local.y >= 112 and local.y < 146:
		return "rename"
	if local.y >= 148 and local.y < 182:
		return "ip"
	if local.y >= 184 and local.y < 218:
		return "inspect"
	return ""

func _perform_context_action(action: String) -> void:
	if action == "connect":
		_open_connection_menu(context_device_id)
		return

	if action.begins_with("target:"):
		var target_id := int(action.trim_prefix("target:"))
		_connect_ethernet(connection_source_id, target_id)
		context_device_id = -1
		connection_menu = false
		connection_source_id = -1
		queue_redraw()
		return

	if action == "cancel_connect":
		context_device_id = -1
		connection_menu = false
		connection_source_id = -1
		queue_redraw()
		return

	var id := context_device_id
	context_device_id = -1
	selected_id = id

	if action == "power":
		_toggle_selected_power()
	elif action == "disconnect":
		_disconnect_ethernet()
	elif action == "rename":
		_begin_name_edit(id)
	elif action == "ip":
		_begin_ip_edit(id)
	elif action == "inspect":
		_toast("Inspecting " + _get_device(id).name + ".")
	queue_redraw()

func _open_connection_menu(source_id: int) -> void:
	connection_source_id = source_id
	context_device_id = source_id
	connection_menu = true
	var source := _get_device(source_id)
	var screen_pos := _world_to_screen(source.position)
	var screen := get_viewport_rect().size
	# Keyboard/inspector connection menus are independent of the RMB device menu.
	context_position = screen_pos + Vector2(28, -20)
	context_position.x = clamp(context_position.x, 10.0, screen.x - MENU_SIZE.x - 10.0)
	context_position.y = clamp(context_position.y, 10.0, screen.y - MENU_SIZE.y - 64.0)
	_toast("Choose which computer to connect to.")
	queue_redraw()

func _connect_ethernet(source_id: int, target_id: int) -> void:
	var source := _get_device(source_id)
	var target := _get_device(target_id)
	if source.is_empty() or target.is_empty():
		_error("Cannot connect: device not found.")
		return
	if source_id == target_id:
		_error("Cannot connect: a computer cannot connect to itself.")
		return
	if not source.powered:
		_error("This device, " + source.name + ", is powered off.")
		return
	if not target.powered:
		_error("The destination computer, " + target.name + ", is powered off.")
		return
	if _link_exists(source_id, target_id):
		_error("Cannot connect: these computers already have an Ethernet link.")
		return
	if not test_mode and money < ETHERNET_COST:
		_error("Cannot connect: insufficient funds. Ethernet cable cost: $%d." % ETHERNET_COST)
		return
	var link := {
		"source_id": source_id,
		"target_id": target_id,
		"forward_speed": 0.72,
		"forward_offset": randf(),
		"reverse_speed": 0.91,
		"reverse_offset": randf(),
		"forward_pulse_speed": 5.1,
		"forward_pulse_offset": randf() * TAU,
		"reverse_pulse_speed": 6.4,
		"reverse_pulse_offset": randf() * TAU
	}
	ethernet_links.append(link)
	if not test_mode:
		money -= ETHERNET_COST
	if not first_link_reward_claimed:
		first_link_reward_claimed = true
		if not test_mode:
			money += 150
		_toast("Ethernet connected. First LAN job complete: +$150.")
	else:
		_toast("Ethernet connected: %s ↔ %s" % [source.name, target.name])

func _disconnect_ethernet() -> void:
	ethernet_links.clear()
	_toast("All Ethernet links disconnected.")

func _device_has_link(id: int) -> bool:
	for link in ethernet_links:
		if link.source_id == id or link.target_id == id:
			return true
	return false

func _link_exists(a: int, b: int) -> bool:
	for link in ethernet_links:
		if (link.source_id == a and link.target_id == b) or (link.source_id == b and link.target_id == a):
			return true
	return false

func _disconnect_device_links(id: int) -> void:
	var kept: Array = []
	for link in ethernet_links:
		if link.source_id != id and link.target_id != id:
			kept.append(link)
	ethernet_links = kept
	_toast("Ethernet links disconnected from " + _get_device(id).name + ".")

func _begin_ip_edit(id: int) -> void:
	var d := _get_device(id)
	if d.is_empty():
		_error("Cannot configure IPv4: device not found.")
		return
	if not _device_has_link(id):
		_error("Cannot configure IPv4: no active Ethernet link.")
		return
	if not d.powered:
		_toast("Cannot configure IPv4: " + d.name + " is powered OFF.")
		return
	ip_buffer = d.ip
	editing_ip = true
	_toast("Type IPv4 address, then press Enter. Esc cancels.")
	queue_redraw()

func _handle_ip_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			editing_ip = false
			queue_redraw()
			return
		if event.keycode == KEY_ENTER:
			_set_selected_ip()
			return
		if event.keycode == KEY_BACKSPACE:
			ip_buffer = ip_buffer.left(max(0, ip_buffer.length() - 1))
			queue_redraw()
			return
		if event.unicode >= 48 and event.unicode <= 57:
			if ip_buffer.length() < 15:
				ip_buffer += char(event.unicode)
				queue_redraw()
			return
		if event.unicode == 46:
			if ip_buffer.length() < 15:
				ip_buffer += "."
				queue_redraw()

func _begin_name_edit(id: int) -> void:
	var d := _get_device(id)
	if d.is_empty():
		_error("Cannot rename: device not found.")
		return
	name_buffer = d.name
	editing_name = true
	_toast("Type a computer name, then press Enter. Esc cancels.")
	queue_redraw()

func _handle_name_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			editing_name = false
			queue_redraw()
			return
		if event.keycode == KEY_ENTER:
			_set_selected_name()
			return
		if event.keycode == KEY_BACKSPACE:
			name_buffer = name_buffer.left(max(0, name_buffer.length() - 1))
			queue_redraw()
			return
		if event.unicode >= 32 and event.unicode <= 126 and name_buffer.length() < 24:
			name_buffer += char(event.unicode)
			queue_redraw()

func _set_selected_name() -> void:
	if selected_id == -1:
		editing_name = false
		_error("Cannot rename: no computer is selected.")
		return
	var clean_name := name_buffer.strip_edges()
	if clean_name == "":
		_error("Computer name cannot be empty.")
		return
	for d in devices:
		if d.id != selected_id and d.name.to_lower() == clean_name.to_lower():
			_error("A computer with the name '" + clean_name + "' already exists.")
			return
	var selected_device := _get_device(selected_id)
	selected_device.name = clean_name
	editing_name = false
	_toast("Computer renamed to " + clean_name + ".")
	queue_redraw()

func _set_selected_ip() -> void:
	if selected_id == -1:
		editing_ip = false
		_error("Cannot configure IPv4: no computer is selected.")
		return
	if not _device_has_link(selected_id):
		_error("Cannot configure IPv4: no active Ethernet link.")
		return
	var selected_device := _get_device(selected_id)
	if not selected_device.powered:
		_error("Cannot configure IPv4: computer is powered OFF.")
		return
	if not _valid_ipv4(ip_buffer):
		_error("Cannot configure IPv4: invalid address.")
		return
	if not _valid_ipv4_host_24(ip_buffer):
		_error("Cannot configure IPv4: address cannot be a network or broadcast address.")
		return
	for link in ethernet_links:
		var peer_id := -1
		if link.source_id == selected_id:
			peer_id = link.target_id
		elif link.target_id == selected_id:
			peer_id = link.source_id
		if peer_id != -1:
			var peer_device := _get_device(peer_id)
			if not peer_device.is_empty() and peer_device.ip != "" and not _same_subnet_24(ip_buffer, peer_device.ip):
				_error("Cannot configure IPv4: connected computers must be on the same /24 subnet.")
				return
	for d in devices:
		if d.id != selected_id and d.ip == ip_buffer:
			_error(ip_buffer + " is already in use.")
			return
	selected_device.ip = ip_buffer
	editing_ip = false
	if not first_ipv4_reward_claimed:
		first_ipv4_reward_claimed = true
		if not test_mode:
			money += 50
		_toast("IPv4 configured: " + ip_buffer + " — Network setup job: +$50.")
	else:
		_toast("IPv4 configured: " + ip_buffer)
	queue_redraw()


func _draw_ip_editor(screen: Vector2) -> void:
	var panel := Rect2(Vector2(screen.x * 0.5 - 300, screen.y * 0.5 - 105), Vector2(600, 210))
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.38), true)
	draw_rect(panel, Color("#10171f"), true)
	draw_rect(panel, Color("#4a5d6b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 38), "CONFIGURE IPv4", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#edf5fa"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 67), "Enter an IPv4 address for the selected computer.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8194a1"))
	var field := Rect2(panel.position + Vector2(24, 84), Vector2(panel.size.x - 48, 48))
	draw_rect(field, Color("#071016"), true)
	draw_rect(field, Color("#5ee6a8"), false, 1.0)
	draw_string(ThemeDB.fallback_font, field.position + Vector2(14, 31), ip_buffer + ("_" if fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#dce8ef"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 160), "ENTER  APPLY     ESC  CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))

func _draw_name_editor(screen: Vector2) -> void:
	var panel := Rect2(Vector2(screen.x * 0.5 - 300, screen.y * 0.5 - 105), Vector2(600, 210))
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.38), true)
	draw_rect(panel, Color("#10171f"), true)
	draw_rect(panel, Color("#4a5d6b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 38), "RENAME COMPUTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#edf5fa"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 67), "Enter a new name for the selected computer.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8194a1"))
	var field := Rect2(panel.position + Vector2(24, 84), Vector2(panel.size.x - 48, 48))
	draw_rect(field, Color("#071016"), true)
	draw_rect(field, Color("#5ee6a8"), false, 1.0)
	draw_string(ThemeDB.fallback_font, field.position + Vector2(14, 31), name_buffer + ("_" if fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#dce8ef"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 160), "ENTER  APPLY     ESC  CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))

func _begin_redeem() -> void:
	redeeming = true
	redeem_buffer = ""
	queue_redraw()

func _handle_redeem_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			redeeming = false
			queue_redraw()
			return
		if event.keycode == KEY_ENTER:
			if redeem_buffer == "FIRSTSIGNAL-TEST":
				test_mode = true
				redeeming = false
				_toast("TEST MODE ENABLED — Unlimited funds.")
			else:
				redeeming = false
				_error("Invalid redeem code.")
			queue_redraw()
			return
		if event.keycode == KEY_BACKSPACE:
			redeem_buffer = redeem_buffer.left(max(0, redeem_buffer.length() - 1))
			queue_redraw()
			return
		if event.unicode >= 32 and event.unicode <= 126 and redeem_buffer.length() < 40:
			redeem_buffer += char(event.unicode).to_upper()
			queue_redraw()

func _draw_redeem_editor(screen: Vector2) -> void:
	var panel := Rect2(Vector2(screen.x * 0.5 - 300, screen.y * 0.5 - 105), Vector2(600, 210))
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.38), true)
	draw_rect(panel, Color("#10171f"), true)
	draw_rect(panel, Color("#4a5d6b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 38), "REDEEM TEST CODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#edf5fa"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 67), "Development-only code for unlimited funds.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8194a1"))
	var field := Rect2(panel.position + Vector2(24, 84), Vector2(panel.size.x - 48, 48))
	draw_rect(field, Color("#071016"), true)
	draw_rect(field, Color("#5ee6a8"), false, 1.0)
	draw_string(ThemeDB.fallback_font, field.position + Vector2(14, 31), redeem_buffer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#dce8ef"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 160), "ENTER  REDEEM     ESC  CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))

func _draw_pause_overlay(screen: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.48), true)
	var panel := Rect2(Vector2(screen.x * 0.5 - 180, screen.y * 0.5 - 70), Vector2(360, 140))
	draw_rect(panel, Color("#10151c"), true)
	draw_rect(panel, Color("#52616d"), false, 2.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 48), "SIMULATION PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#edf5fa"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(24, 82), "Press ESC to resume.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8797a3"))

func _draw_toast(screen: Vector2) -> void:
	var box := Rect2(Vector2(24, screen.y - 108), Vector2(560, 46))
	var fill := Color("#241417") if toast_is_error else Color("#111922")
	var edge := Color("#a94d58") if toast_is_error else Color("#344553")
	var text_color := Color("#ffb9bf") if toast_is_error else Color("#dce8ef")
	draw_rect(box, fill, true)
	draw_rect(box, edge, false, 1.0)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(14, 28), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)

func _draw_error_popup(screen: Vector2) -> void:
	var popup := Rect2(Vector2(screen.x * 0.5 - 270, screen.y * 0.5 - 125), Vector2(540, 250))
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.42), true)
	draw_rect(popup.grow(5), Color(0.55, 0.12, 0.16, 0.16), true)
	draw_rect(popup, Color("#10151c"), true)
	draw_rect(popup, Color("#a94d58"), false, 2.0)
	draw_rect(Rect2(popup.position, Vector2(popup.size.x, 48)), Color("#251419"), true)
	draw_string(ThemeDB.fallback_font, popup.position + Vector2(22, 31), "ERROR", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ff8791"))

	# Wrap long messages so they remain fully visible instead of being clipped.
	var message_rect := Rect2(popup.position + Vector2(22, 78), Vector2(popup.size.x - 44, 72))
	draw_multiline_string(ThemeDB.fallback_font, message_rect.position, last_error, HORIZONTAL_ALIGNMENT_LEFT, message_rect.size.x, 14, -1, Color("#edf2f5"))

	draw_string(ThemeDB.fallback_font, popup.position + Vector2(22, 160), "The action could not be completed.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8797a3"))
	var close_button := Rect2(popup.position.x + popup.size.x - 120, popup.position.y + popup.size.y - 54, 96, 34)
	draw_rect(close_button, Color("#1b252e"), true)
	draw_rect(close_button, Color("#52616d"), false, 1.0)
	draw_string(ThemeDB.fallback_font, close_button.position + Vector2(23, 22), "CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#dce6eb"))

func _create_computer() -> void:
	if not test_mode and money < COMPUTER_COST:
		_error("Cannot build computer: insufficient funds. Computer cost: $%d." % COMPUTER_COST)
		return
	var next_id := 1
	for d in devices:
		next_id = max(next_id, int(d.id) + 1)

	var spawn_index := devices.size()
	var new_position := Vector2(350 + (spawn_index % 4) * 250, 260 + (spawn_index / 4) * 180)
	var new_device := {
		"id": next_id,
		"name": "COMPUTER %02d" % next_id,
		"kind": "Computer",
		"position": new_position,
		"powered": false,
		"mac": _make_mac(),
		"ip": ""
	}
	devices.append(new_device)
	if not test_mode:
		money -= COMPUTER_COST
	selected_id = next_id
	_toast("Built " + new_device.name)
	queue_redraw()

func _toggle_selected_power() -> void:
	if selected_id == -1:
		_error("Cannot change power: no computer is selected.")
		return
	var d := _get_device(selected_id)
	d.powered = not d.powered
	if not d.powered and _device_has_link(d.id):
		_disconnect_device_links(d.id)
		_toast("Powered OFF " + d.name + " — Ethernet disconnected.")
	else:
		_toast(("Powered ON " if d.powered else "Powered OFF ") + d.name)

func _delete_selected() -> void:
	if selected_id == -1:
		_error("Cannot delete: no computer is selected.")
		return
	var d := _get_device(selected_id)
	if _device_has_link(selected_id):
		_disconnect_device_links(selected_id)
	devices.erase(d)
	_toast("Deleted " + d.name + ".")
	selected_id = -1
	queue_redraw()

func _get_device(id: int) -> Dictionary:
	for d in devices:
		if d.id == id:
			return d
	return {}

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

func _valid_ipv4_host_24(ip: String) -> bool:
	if not _valid_ipv4(ip):
		return false
	var parts := ip.split(".")
	var last := int(parts[3])
	return last > 0 and last < 255

func _same_subnet_24(a: String, b: String) -> bool:
	if not _valid_ipv4(a) or not _valid_ipv4(b):
		return false
	var ap := a.split(".")
	var bp := b.split(".")
	return ap[0] == bp[0] and ap[1] == bp[1] and ap[2] == bp[2]

func _valid_ipv4(ip: String) -> bool:
	var parts := ip.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if part == "" or not part.is_valid_int():
			return false
		var value := int(part)
		if value < 0 or value > 255:
			return false
	return true

func _make_mac() -> String:
	var parts := []
	for i in 6:
		parts.append("%02X" % randi_range(0, 255))
	return ":".join(parts)

func _toast(message: String) -> void:
	toast = message
	toast_is_error = false
	toast_time = 2.5
	queue_redraw()

func _error(message: String) -> void:
	last_error = message
	error_popup_visible = true
	toast = ""
	toast_is_error = true
	toast_time = 0.0
	queue_redraw()

extends Node2D

const WORLD_SIZE := Vector2(2600, 1800)
const DEVICE_SIZE := Vector2(170, 110)
const SHOP_BUTTON := Rect2(24, 78, 190, 42)
const SHOP_SIZE := Vector2(500, 430)
const CURRENCY_START := 1000
const COMPUTER_COST := 100
const ETHERNET_COST := 25
const COMPUTER_DELIVERY_TIME := 5.0
const ETHERNET_DELIVERY_TIME := 2.0
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
var shop_open := false
var deliveries: Array = []
var ethernet_inventory := 0

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
var inspecting_id := -1

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
	for delivery in deliveries:
		delivery.time_left = max(0.0, delivery.time_left - delta)
	var completed: Array = []
	for delivery in deliveries:
		if delivery.time_left <= 0.0:
			completed.append(delivery)
	for delivery in completed:
		_deliver_order(delivery)
		deliveries.erase(delivery)
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

	if shop_open:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var shop_action := _shop_action_at(event.position)
			if shop_action != "":
				_perform_shop_action(shop_action)
			else:
				shop_open = false
				queue_redraw()
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
			if inspecting_id != -1:
				if _inspect_close_rect().has_point(event.position):
					inspecting_id = -1
					queue_redraw()
				return
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
			if SHOP_BUTTON.has_point(event.position):
				shop_open = true
				queue_redraw()
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
	_draw_shop_button()
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
	if inspecting_id != -1:
		_draw_inspect_panel(screen)
	if shop_open:
		_draw_shop(screen)
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

func _draw_shop_button() -> void:
	draw_rect(SHOP_BUTTON, Color("#111a22"), true)
	draw_rect(SHOP_BUTTON, Color("#3b5261"), false, 1.0)
	draw_string(ThemeDB.fallback_font, SHOP_BUTTON.position + Vector2(14, 27), "OPEN NETWORK SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#dce8ef"))
	draw_rect(REDEEM_BUTTON, Color("#111a22"), true)
	draw_rect(REDEEM_BUTTON, Color("#3b5261"), false, 1.0)
	draw_string(ThemeDB.fallback_font, REDEEM_BUTTON.position + Vector2(14, 23), "REDEEM TEST CODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#dce8ef"))

func _draw_shop(screen: Vector2) -> void:
	var panel := Rect2(Vector2(screen.x * 0.5 - 250, screen.y * 0.5 - 215), SHOP_SIZE)
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(panel, Color("#0d141c"), true)
	draw_rect(panel, Color("#4a5d6b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(22, 35), "NETWORK SUPPLY SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#edf5fa"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(22, 53), "Order equipment and wait for delivery.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#718594"))
	_shop_item(panel, Rect2(18, 78, 464, 92), "COMPUTER", "Basic network computer", 100, 5.0)
	_shop_item(panel, Rect2(18, 180, 464, 92), "ETHERNET CABLE", "Standard Ethernet cable", 25, 2.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(22, 306), "INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#596c7a"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(22, 327), "Ethernet cables ready: %d" % ethernet_inventory, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c9d6de"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(22, 356), "ACTIVE DELIVERIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#596c7a"))
	if deliveries.is_empty():
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(22, 378), "No deliveries in transit.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#718594"))
	else:
		var y := 378.0
		for delivery in deliveries:
			draw_string(ThemeDB.fallback_font, panel.position + Vector2(22, y), "%s — %.1fs" % [delivery.item, delivery.time_left], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#72efb1"))
			y += 20
	var close_rect := Rect2(panel.position + Vector2(panel.size.x - 118, panel.size.y - 48), Vector2(96, 32))
	draw_rect(close_rect, Color("#18232c"), true)
	draw_rect(close_rect, Color("#52616d"), false, 1.0)
	draw_string(ThemeDB.fallback_font, close_rect.position + Vector2(22, 21), "CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#dce6eb"))

func _shop_item(panel: Rect2, local_rect: Rect2, title: String, description: String, cost: int, delivery_time: float) -> void:
	var r := Rect2(panel.position + local_rect.position, local_rect.size)
	draw_rect(r, Color("#111b24"), true)
	draw_rect(r, Color("#344553"), false, 1.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(14, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#edf5fa"))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(14, 45), description, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#718594"))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(14, 68), "Delivery: %.0f seconds" % delivery_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#72efb1"))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(14, 84), "$%d" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c9d6de"))
	var buy := Rect2(r.position + Vector2(r.size.x - 112, 25), Vector2(96, 40))
	var affordable := test_mode or money >= cost
	draw_rect(buy, Color("#17242d") if affordable else Color("#15191d"), true)
	draw_rect(buy, Color("#52616d") if affordable else Color("#30363b"), false, 1.0)
	draw_string(ThemeDB.fallback_font, buy.position + Vector2(24, 26), "ORDER" if affordable else "NO FUNDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#dce8ef") if affordable else Color("#68737b"))

func _shop_action_at(pos: Vector2) -> String:
	var screen := get_viewport_rect().size
	var panel := Rect2(Vector2(screen.x * 0.5 - 250, screen.y * 0.5 - 215), SHOP_SIZE)
	var local := pos - panel.position
	if Rect2(370, 103, 96, 40).has_point(local):
		return "buy_computer"
	if Rect2(370, 205, 96, 40).has_point(local):
		return "buy_ethernet"
	if Rect2(panel.size.x - 118, panel.size.y - 48, 96, 32).has_point(local):
		return "close"
	return ""

func _perform_shop_action(action: String) -> void:
	if action == "close":
		shop_open = false
	elif action == "buy_computer":
		_place_order("COMPUTER", COMPUTER_COST, COMPUTER_DELIVERY_TIME)
	elif action == "buy_ethernet":
		_place_order("ETHERNET CABLE", ETHERNET_COST, ETHERNET_DELIVERY_TIME)
	queue_redraw()

func _place_order(item: String, cost: int, delivery_time: float) -> void:
	if not test_mode and money < cost:
		_error("Cannot order " + item + ": insufficient funds. Cost: $%d." % cost)
		return
	if not test_mode:
		money -= cost
	deliveries.append({"item": item, "time_left": delivery_time})
	_toast(item + " ordered. Delivery in %.0f seconds." % delivery_time)

func _deliver_order(delivery: Dictionary) -> void:
	if delivery.item == "COMPUTER":
		_create_computer(true)
	elif delivery.item == "ETHERNET CABLE":
		ethernet_inventory += 1
		_toast("Delivery arrived: Ethernet cable added to inventory.")


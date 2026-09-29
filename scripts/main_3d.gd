extends Node3D

# The First Signal — 3D simulator foundation.
# This is intentionally world-first: the player physically occupies the network space.

const STARTING_MONEY := 1000
const COMPUTER_COST := 100
const PLAYER_SPEED := 5.5
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.0025
const BUILD_DISTANCE := 3.0

var money := STARTING_MONEY
var player: CharacterBody3D
var first_camera: Camera3D
var third_camera: Camera3D
var camera_pivot: Node3D
var pitch := -0.08
var third_person := false
var shop_open := false
var carrying: Node3D
var computers: Array[Node3D] = []
var computer_counter := 0
var status_text := "Find the Network Supply Terminal."
var status_time := 0.0
var terminal: StaticBody3D

var money_label: Label
var status_label: Label
var crosshair: Label
var interaction_label: Label
var shop_panel: PanelContainer

func _ready() -> void:
    _build_world()
    _build_player()
    _build_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    if status_time > 0.0:
        status_time -= delta
        if status_time <= 0.0:
            status_text = ""
    if carrying:
        _update_carried_object()
    _update_hud()

func _physics_process(delta: float) -> void:
    if not player:
        return

    if not player.is_on_floor():
        player.velocity.y -= 12.0 * delta

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction := (player.transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
    var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else PLAYER_SPEED

    if direction:
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, speed * 8.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, speed * 8.0 * delta)

    if Input.is_action_just_pressed("jump") and player.is_on_floor():
        player.velocity.y = JUMP_VELOCITY

    player.move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        player.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.35, 1.2)
        camera_pivot.rotation.x = pitch

    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            shop_open = false
            _set_mouse_capture(not (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED))
        elif event.keycode == KEY_V:
            _toggle_camera()
        elif event.keycode == KEY_E:
            _interact()
        elif event.keycode == KEY_G:
            _toggle_carry()
        elif event.keycode == KEY_B:
            _open_shop()
        elif event.keycode == KEY_1 and shop_open:
            _buy_computer()

    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if shop_open:
                _buy_computer()
            elif carrying:
                _place_carried_object()
        elif event.button_index == MOUSE_BUTTON_RIGHT and carrying:
            _cancel_carry()

func _set_mouse_capture(capture: bool) -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

func _toggle_camera() -> void:
    third_person = not third_person
    first_camera.current = not third_person
    third_camera.current = third_person
    _set_status("THIRD PERSON" if third_person else "FIRST PERSON")

func _interact() -> void:
    var hit := _raycast()
    if hit.is_empty():
        _set_status("Nothing within reach.")
        return

    var object: Node3D = hit.collider
    var kind := str(object.get_meta("signal_kind", ""))

    if kind == "terminal":
        _open_shop()
    elif kind == "computer":
        _toggle_computer_power(object)
    else:
        _set_status("That object is not interactive yet.")

func _open_shop() -> void:
    shop_open = true
    _set_mouse_capture(false)
    shop_panel.visible = true
    _set_status("SUPPLY TERMINAL — press 1 or click BUY COMPUTER.")

func _buy_computer() -> void:
    if not shop_open:
        return
    if money < COMPUTER_COST:
        _set_status("Insufficient funds.")
        return

    money -= COMPUTER_COST
    computer_counter += 1
    var computer := _create_computer("COMPUTER %02d" % computer_counter)
    var spawn := _floor_point_from_view(BUILD_DISTANCE)
    computer.global_position = spawn
    computers.append(computer)
    shop_open = false
    shop_panel.visible = false
    _set_mouse_capture(true)
    _set_status("Computer delivered. Physically place it with G.")

func _toggle_computer_power(computer: Node3D) -> void:
    var powered := not bool(computer.get_meta("powered", false))
    computer.set_meta("powered", powered)
    var lamp := computer.get_node_or_null("PowerLamp") as MeshInstance3D
    if lamp:
        var material := lamp.material_override as StandardMaterial3D
        if material:
            material.emission_enabled = powered
            material.emission = Color("#58f0a5") if powered else Color("#30151a")
            material.albedo_color = Color("#72efb1") if powered else Color("#5b2730")
    _set_status(("POWER ON — " if powered else "POWER OFF — ") + str(computer.get_meta("display_name")))

func _toggle_carry() -> void:
    if carrying:
        _place_carried_object()
        return

    var hit := _raycast()
    if hit.is_empty():
        _set_status("Aim at a computer first.")
        return

    var object: Node3D = hit.collider
    if str(object.get_meta("signal_kind", "")) != "computer":
        _set_status("Only computers can be moved right now.")
        return

    carrying = object
    _set_status("Carrying " + str(object.get_meta("display_name")) + " — click to place.")

func _update_carried_object() -> void:
    if not carrying:
        return
    carrying.global_position = _floor_point_from_view(BUILD_DISTANCE) + Vector3.UP * 0.55

func _place_carried_object() -> void:
    if not carrying:
        return
    carrying.global_position = _floor_point_from_view(BUILD_DISTANCE)
    _set_status("Placed " + str(carrying.get_meta("display_name")) + ".")
    carrying = null

func _cancel_carry() -> void:
    if carrying:
        _set_status("Placement cancelled.")
        carrying = null

func _raycast() -> Dictionary:
    var camera := third_camera if third_person else first_camera
    var from := camera.global_position
    var to := from + (-camera.global_transform.basis.z * 5.0)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player]
    return get_world_3d().direct_space_state.intersect_ray(query)

func _floor_point_from_view(distance: float) -> Vector3:
    var camera := third_camera if third_person else first_camera
    var origin := camera.global_position
    var forward := -camera.global_transform.basis.z
    var target := origin + forward * distance

    var query := PhysicsRayQueryParameters3D.create(
        target + Vector3.UP * 8.0,
        target + Vector3.DOWN * 8.0
    )
    query.exclude = [player]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        return hit.position
    return Vector3(target.x, 0.55, target.z)

func _build_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#070b10")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#9ab5c8")
    env.ambient_light_energy = 0.45
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.environment = env
    add_child(environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 0.7
    sun.shadow_enabled = true
    add_child(sun)

    _create_box("Floor", Vector3(24, 0.2, 18), Vector3(0, -0.1, 0), Color("#111820"), true)
    _create_box("BackWall", Vector3(24, 4, 0.2), Vector3(0, 2, -9), Color("#0e151c"), true)
    _create_box("LeftWall", Vector3(0.2, 4, 18), Vector3(-12, 2, 0), Color("#0e151c"), true)
    _create_box("RightWall", Vector3(0.2, 4, 18), Vector3(12, 2, 0), Color("#0e151c"), true)

    terminal = _create_terminal(Vector3(0, 0.8, -5.8))
    _create_rack(Vector3(6.5, 1.2, -6.5))
    _create_workbench(Vector3(-6.0, 0.55, -5.8))

func _create_box(label: String, size: Vector3, position: Vector3, color: Color, collision: bool) -> Node3D:
    var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
    body.name = label
    body.position = position
    add_child(body)

    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _material(color)
    body.add_child(mesh)

    if collision:
        var shape := CollisionShape3D.new()
        var box_shape := BoxShape3D.new()
        box_shape.size = size
        shape.shape = box_shape
        body.add_child(shape)
    return body

func _create_terminal(position: Vector3) -> StaticBody3D:
    var body := _create_box("Network Supply Terminal", Vector3(1.6, 1.6, 0.7), position, Color("#182630"), true) as StaticBody3D
    body.set_meta("signal_kind", "terminal")

    var screen := Label3D.new()
    screen.text = "NETWORK\nSUPPLY"
    screen.font_size = 48
    screen.modulate = Color("#72efb1")
    screen.position = Vector3(0, 0.35, -0.38)
    body.add_child(screen)

    var prompt := Label3D.new()
    prompt.text = "E  INTERACT"
    prompt.font_size = 32
    prompt.modulate = Color("#a9bac6")
    prompt.position = Vector3(0, -1.05, 0)
    body.add_child(prompt)
    return body

func _create_rack(position: Vector3) -> void:
    var rack := _create_box("Server Rack", Vector3(2.0, 3.0, 0.9), position, Color("#151c23"), true)
    for i in 4:
        var light := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(0.08, 0.08, 0.04)
        light.mesh = box
        light.position = Vector3(-0.55 + i * 0.36, -0.5 + i * 0.28, -0.48)
        light.material_override = _material(Color("#3e7e91"))
        rack.add_child(light)

    var label := Label3D.new()
    label.text = "SERVER RACK\nOFFLINE"
    label.font_size = 34
    label.modulate = Color("#70828e")
    label.position = Vector3(0, 1.9, 0)
    rack.add_child(label)

func _create_workbench(position: Vector3) -> void:
    var bench := _create_box("Network Workbench", Vector3(3.2, 1.1, 1.3), position, Color("#171d23"), true)
    var top := _create_box("WorkbenchTop", Vector3(3.4, 0.12, 1.45), position + Vector3(0, 0.6, 0), Color("#26343d"), false)
    top.reparent(bench)

    var label := Label3D.new()
    label.text = "NETWORK\nWORKBENCH"
    label.font_size = 30
    label.modulate = Color("#70828e")
    label.position = Vector3(0, 1.2, 0)
    bench.add_child(label)

func _create_computer(display_name: String) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = display_name
    body.set_meta("signal_kind", "computer")
    body.set_meta("display_name", display_name)
    body.set_meta("powered", false)
    add_child(body)

    var case_mesh := MeshInstance3D.new()
    var case_box := BoxMesh.new()
    case_box.size = Vector3(1.3, 1.0, 1.0)
    case_mesh.mesh = case_box
    case_mesh.material_override = _material(Color("#202a33"))
    body.add_child(case_mesh)

    var front := MeshInstance3D.new()
    var front_box := BoxMesh.new()
    front_box.size = Vector3(0.75, 0.58, 0.06)
    front.mesh = front_box
    front.position = Vector3(0, 0.05, -0.53)
    front.material_override = _material(Color("#091116"))
    body.add_child(front)

    var lamp := MeshInstance3D.new()
    var lamp_box := BoxMesh.new()
    lamp_box.size = Vector3(0.08, 0.08, 0.04)
    lamp.mesh = lamp_box
    lamp.position = Vector3(-0.48, 0.33, -0.55)
    lamp.name = "PowerLamp"
    lamp.material_override = _material(Color("#5b2730"))
    body.add_child(lamp)

    var label := Label3D.new()
    label.text = display_name + "\nPOWER OFF"
    label.font_size = 32
    label.modulate = Color("#b9c7d0")
    label.position = Vector3(0, 0.8, 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    body.add_child(label)

    body.set_meta("display_label", label)

    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(1.3, 1.0, 1.0)
    shape.shape = box_shape
    body.add_child(shape)
    return body

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1.1, 4.5)
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)

    camera_pivot = Node3D.new()
    camera_pivot.name = "CameraPivot"
    camera_pivot.position = Vector3(0, 1.55, 0)
    player.add_child(camera_pivot)

    first_camera = Camera3D.new()
    first_camera.name = "FirstPersonCamera"
    first_camera.current = true
    first_camera.fov = 78
    camera_pivot.add_child(first_camera)

    third_camera = Camera3D.new()
    third_camera.name = "ThirdPersonCamera"
    third_camera.position = Vector3(0, 1.0, 5.0)
    third_camera.fov = 70
    third_camera.current = false
    camera_pivot.add_child(third_camera)

func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "HUD"
    add_child(canvas)

    crosshair = Label.new()
    crosshair.text = "+"
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    crosshair.add_theme_font_size_override("font_size", 20)
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-12, -16)
    crosshair.size = Vector2(24, 32)
    canvas.add_child(crosshair)

    money_label = Label.new()
    money_label.position = Vector2(24, 20)
    money_label.add_theme_font_size_override("font_size", 18)
    money_label.modulate = Color("#72efb1")
    canvas.add_child(money_label)

    interaction_label = Label.new()
    interaction_label.position = Vector2(24, 55)
    interaction_label.add_theme_font_size_override("font_size", 14)
    interaction_label.modulate = Color("#d5e0e6")
    canvas.add_child(interaction_label)

    status_label = Label.new()
    status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    status_label.position = Vector2(-360, -70)
    status_label.size = Vector2(720, 44)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 15)
    status_label.modulate = Color("#a9bac5")
    canvas.add_child(status_label)

    shop_panel = PanelContainer.new()
    shop_panel.name = "SupplyPanel"
    shop_panel.set_anchors_preset(Control.PRESET_CENTER)
    shop_panel.position = Vector2(-260, -150)
    shop_panel.size = Vector2(520, 300)
    shop_panel.visible = false
    canvas.add_child(shop_panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    shop_panel.add_child(box)

    var title := Label.new()
    title.text = "NETWORK SUPPLY TERMINAL"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    box.add_child(title)

    var info := Label.new()
    info.text = "Physical equipment\n\n1  COMPUTER       $100\n\nComputers arrive powered off.\nYou can physically move them with G."
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_font_size_override("font_size", 15)
    box.add_child(info)

    var buy := Button.new()
    buy.text = "BUY COMPUTER — $100"
    buy.custom_minimum_size = Vector2(0, 48)
    buy.pressed.connect(_buy_computer)
    box.add_child(buy)

func _update_hud() -> void:
    if not money_label:
        return
    money_label.text = "$%d    |    %s" % [money, "THIRD PERSON" if third_person else "FIRST PERSON"]

    if shop_open:
        interaction_label.text = "SUPPLY TERMINAL OPEN  •  1 / CLICK TO BUY  •  ESC TO CLOSE"
    elif carrying:
        interaction_label.text = "CARRYING %s  •  CLICK TO PLACE  •  RIGHT CLICK TO CANCEL" % str(carrying.get_meta("display_name"))
    else:
        var hit := _raycast()
        if hit.is_empty():
            interaction_label.text = "WASD move  •  SHIFT sprint  •  SPACE jump  •  E interact  •  G move"
        else:
            var object: Node3D = hit.collider
            var kind := str(object.get_meta("signal_kind", ""))
            if kind == "terminal":
                interaction_label.text = "E  OPEN NETWORK SUPPLY"
            elif kind == "computer":
                var powered := bool(object.get_meta("powered", false))
                interaction_label.text = "E  POWER %s  •  G  MOVE" % ("OFF" if powered else "ON")
            else:
                interaction_label.text = "WASD move  •  E interact"

    status_label.text = status_text

func _set_status(message: String) -> void:
    status_text = message
    status_time = 3.0

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    return material

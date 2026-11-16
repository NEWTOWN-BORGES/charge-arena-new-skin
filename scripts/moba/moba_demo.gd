extends Node3D

## MobaDemo: Modo de Jogo MOBA 2v2 Shooter em 1ª Pessoa com Fortalezas Destrutíveis (Lego)
## Arena com 3 rotas, 2 fortalezas em camadas, destruição tijolo por tijolo e respawn.

const CYAN = Color("00caff")
const CORAL = Color("ff2a4b")
const GOLD = Color("ffb703")
const WHITE = Color("f0f5fa")
const DARK = Color("0c1a32")

# Dimensões da arena
const ARENA_WIDTH = 26.0
const ARENA_LENGTH = 44.0
const WALL_HEIGHT = 3.5

# Configurações de Gameplay
const PLAYER_MAX_HP = 100.0
const BOT_MAX_HP = 80.0
const BULLET_SPEED = 32.0
const BULLET_DAMAGE_CHAR = 25.0
const BULLET_DAMAGE_BRICK = 1.0
const RESPAWN_TIME = 4.0

# Nós do mundo
var world_env: WorldEnvironment
var sun_light: DirectionalLight3D
var bullets_container: Node3D

# Fortalezas e tijolos
var blue_bricks: Array = []
var red_bricks: Array = []
var blue_bricks_alive: int = 0
var red_bricks_alive: int = 0
var initial_bricks_per_fortress: int = 0

# Personagens
var player: CharacterBody3D
var player_camera: Camera3D
var player_hp: float = PLAYER_MAX_HP
var player_dead: bool = false
var player_respawn_timer: float = 0.0

var ally_bot: CharacterBody3D
var enemy_bots: Array = []

# Spawns
const BLUE_SPAWN = Vector3(0, 0.9, 18.0)
const RED_SPAWN = Vector3(0, 0.9, -18.0)

# HUD
var hud_layer: CanvasLayer
var crosshair: Control
var hp_bar: ProgressBar
var hp_label: Label
var fortress_label_blue: Label
var fortress_label_red: Label
var status_banner: Label
var respawn_label: Label
var touch_controls: Control

# Estado de Jogo
var match_over: bool = false
var winner_team: int = -1

# Input Móvel / Mouse
var touch_look_index: int = -1
var touch_look_start: Vector2 = Vector2.ZERO
var touch_move_index: int = -1
var touch_move_pos: Vector2 = Vector2.ZERO
var move_stick_vector: Vector2 = Vector2.ZERO
var shoot_requested: bool = false
var shoot_cooldown: float = 0.0
const SHOOT_INTERVAL = 0.18

func _ready() -> void:
	setup_environment()
	build_arena_and_lanes()
	build_fortresses()
	setup_bullets_container()
	setup_hud()
	spawn_player()
	spawn_bots()

func setup_environment() -> void:
	world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a111e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8ea4c4")
	env.ambient_light_energy = 0.9
	world_env.environment = env
	add_child(world_env)

	sun_light = DirectionalLight3D.new()
	sun_light.light_color = Color("fff5e6")
	sun_light.light_energy = 1.2
	sun_light.rotation_degrees = Vector3(-50, -40, 0)
	sun_light.shadow_enabled = true
	add_child(sun_light)

func build_arena_and_lanes() -> void:
	# Chão da arena
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(ARENA_WIDTH + 4.0, ARENA_LENGTH + 4.0)
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color("141e2e")
	floor_mat.roughness = 0.6
	
	var floor_node = MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = floor_mat
	add_child(floor_node)

	# Colisão do chão
	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(ARENA_WIDTH + 6.0, 0.5, ARENA_LENGTH + 6.0)
	floor_col.shape = box_shape
	floor_col.position.y = -0.25
	floor_body.add_child(floor_col)
	add_child(floor_body)

	# Paredes perimetrais da arena
	create_static_wall(Vector3(0, WALL_HEIGHT * 0.5, -ARENA_LENGTH * 0.5), Vector3(ARENA_WIDTH, WALL_HEIGHT, 1.0), Color("223247"))
	create_static_wall(Vector3(0, WALL_HEIGHT * 0.5, ARENA_LENGTH * 0.5), Vector3(ARENA_WIDTH, WALL_HEIGHT, 1.0), Color("223247"))
	create_static_wall(Vector3(-ARENA_WIDTH * 0.5, WALL_HEIGHT * 0.5, 0), Vector3(1.0, WALL_HEIGHT, ARENA_LENGTH), Color("223247"))
	create_static_wall(Vector3(ARENA_WIDTH * 0.5, WALL_HEIGHT * 0.5, 0), Vector3(1.0, WALL_HEIGHT, ARENA_LENGTH), Color("223247"))

	# Paredes que dividem as 3 Rotas (Esquerda, Centro, Direita) estilo MOBA
	# Deixando aberturas de transição no meio da arena
	var lane_wall_x = ARENA_WIDTH * 0.28 # ~7.28
	# Parede divisória 1: separa Rota Esquerda da Central
	create_static_wall(Vector3(-lane_wall_x, WALL_HEIGHT * 0.4, -8.0), Vector3(0.8, WALL_HEIGHT * 0.8, 12.0), Color("1e2a3b"))
	create_static_wall(Vector3(-lane_wall_x, WALL_HEIGHT * 0.4, 8.0), Vector3(0.8, WALL_HEIGHT * 0.8, 12.0), Color("1e2a3b"))
	
	# Parede divisória 2: separa Rota Direita da Central
	create_static_wall(Vector3(lane_wall_x, WALL_HEIGHT * 0.4, -8.0), Vector3(0.8, WALL_HEIGHT * 0.8, 12.0), Color("1e2a3b"))
	create_static_wall(Vector3(lane_wall_x, WALL_HEIGHT * 0.4, 8.0), Vector3(0.8, WALL_HEIGHT * 0.8, 12.0), Color("1e2a3b"))

	# Torres centrais / pilares de cobertura no meio do mapa (jungle/mid)
	create_static_wall(Vector3(0, WALL_HEIGHT * 0.5, 0), Vector3(2.4, WALL_HEIGHT, 2.4), Color("324760"))
	create_static_wall(Vector3(-lane_wall_x * 0.5, WALL_HEIGHT * 0.4, 0), Vector3(1.5, WALL_HEIGHT * 0.8, 1.5), Color("283b52"))
	create_static_wall(Vector3(lane_wall_x * 0.5, WALL_HEIGHT * 0.4, 0), Vector3(1.5, WALL_HEIGHT * 0.8, 1.5), Color("283b52"))

func create_static_wall(pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh_inst = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.5
	mesh_inst.mesh = box_m
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	add_child(body)
	return body

## Constrói as 2 Fortalezas de Tijolos Destrutíveis (tipo Lego, 2 andares, 3 camadas de paredes)
func build_fortresses() -> void:
	blue_bricks.clear()
	red_bricks.clear()

	# Fortaleza Azul (Team 0, ao sul em Z = +18)
	build_single_fortress(0, BLUE_SPAWN, CYAN)
	# Fortaleza Vermelha (Team 1, ao norte em Z = -18)
	build_single_fortress(1, RED_SPAWN, CORAL)

	blue_bricks_alive = blue_bricks.size()
	red_bricks_alive = red_bricks.size()
	initial_bricks_per_fortress = blue_bricks_alive

func build_single_fortress(team: int, base_pos: Vector3, team_color: Color) -> void:
	# Uma fortaleza retangular oca por dentro (sala de nascimento/spawn)
	# Paredes externas com 3 camadas de tijolos destrutíveis e 2 andares de altura
	# Tijolos com dimensões estilo bloco de Lego (Largura: 1.0, Altura: 0.6, Profundidade: 0.6)
	var brick_w = 1.0
	var brick_h = 0.65
	var brick_d = 0.6
	
	var fort_width_blocks = 7  # 7 blocos de largura (~7m)
	var fort_depth_blocks = 6  # 6 blocos de profundidade (~3.6m)
	var num_floors = 2        # 2 andares de tijolos
	var num_layers = 3        # 3 camadas de espessura de tijolo

	var forward_sign = -1.0 if team == 0 else 1.0 # Para onde a fortaleza aponta para o campo

	for floor_idx in range(num_floors):
		var y = (floor_idx + 0.5) * brick_h
		
		# Construir camadas de paredes (camada 0 = externa, 1 = média, 2 = interna)
		for layer in range(num_layers):
			var cur_w_blocks = fort_width_blocks - (layer * 0.5)
			var cur_d_blocks = fort_depth_blocks - (layer * 0.5)
			var half_w = (cur_w_blocks * brick_w) * 0.5
			var half_d = (cur_d_blocks * brick_d) * 0.5

			# Parede da frente (com porta central aberta no andar térreo para sair)
			var front_cols = int(cur_w_blocks)
			for col in range(front_cols):
				# Deixa os 2 blocos centrais abertos na frente como portão de saída
				var is_center_gate = (col >= front_cols / 2 - 1 and col <= front_cols / 2)
				if floor_idx == 0 and is_center_gate:
					continue # Portão aberto para os personagens saírem
				
				var x = (col - (front_cols - 1) * 0.5) * brick_w
				var z = forward_sign * half_d
				var block_pos = base_pos + Vector3(x, y, z)
				spawn_destructible_brick(block_pos, Vector3(brick_w * 0.95, brick_h * 0.95, brick_d * 0.95), team, team_color)

			# Parede traseira
			for col in range(front_cols):
				var x = (col - (front_cols - 1) * 0.5) * brick_w
				var z = -forward_sign * half_d
				var block_pos = base_pos + Vector3(x, y, z)
				spawn_destructible_brick(block_pos, Vector3(brick_w * 0.95, brick_h * 0.95, brick_d * 0.95), team, team_color)

			# Paredes laterais (esquerda e direita)
			var side_rows = int(cur_d_blocks)
			for row in range(side_rows):
				var z = (row - (side_rows - 1) * 0.5) * brick_d
				# Lado esquerdo
				var block_pos_l = base_pos + Vector3(-half_w, y, z)
				spawn_destructible_brick(block_pos_l, Vector3(brick_w * 0.95, brick_h * 0.95, brick_d * 0.95), team, team_color)
				# Lado direito
				var block_pos_r = base_pos + Vector3(half_w, y, z)
				spawn_destructible_brick(block_pos_r, Vector3(brick_w * 0.95, brick_h * 0.95, brick_d * 0.95), team, team_color)

func spawn_destructible_brick(pos: Vector3, size: Vector3, team: int, team_color: Color) -> void:
	var brick_body = StaticBody3D.new()
	brick_body.position = pos
	brick_body.set_meta("is_brick", true)
	brick_body.set_meta("team", team)
	brick_body.set_meta("hp", 3) # 3 hits para destruir cada tijolo

	# Colisão do tijolo
	var col = CollisionShape3D.new()
	var box_s = BoxShape3D.new()
	box_s.size = size
	col.shape = box_s
	brick_body.add_child(col)

	# Visual do tijolo (estilo bloco Lego com botão no topo)
	var mesh_inst = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = size
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = team_color.darkened(0.15)
	mat.metallic = 0.2
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = team_color.darkened(0.5)
	mat.emission_energy_multiplier = 0.4
	mesh_inst.mesh = box_m
	mesh_inst.material_override = mat
	brick_body.add_child(mesh_inst)

	# Lego stud / botão em cima do tijolo
	var stud = MeshInstance3D.new()
	var stud_m = CylinderMesh.new()
	stud_m.top_radius = 0.16
	stud_m.bottom_radius = 0.16
	stud_m.height = 0.08
	stud.mesh = stud_m
	stud.material_override = mat
	stud.position.y = size.y * 0.5 + 0.04
	brick_body.add_child(stud)

	add_child(brick_body)

	if team == 0:
		blue_bricks.append(brick_body)
	else:
		red_bricks.append(brick_body)

func setup_bullets_container() -> void:
	bullets_container = Node3D.new()
	bullets_container.name = "BulletsContainer"
	add_child(bullets_container)

## Cria o Jogador Humano em 1ª Pessoa
func spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = BLUE_SPAWN
	player.set_meta("team", 0)
	player.set_meta("is_character", true)

	var col = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	player.add_child(col)

	# Câmera em Primeira Pessoa
	player_camera = Camera3D.new()
	player_camera.position = Vector3(0, 1.45, 0) # Altura dos olhos
	player_camera.current = true
	player.add_child(player_camera)

	# Arma em 1ª pessoa no canto da tela
	var gun = MeshInstance3D.new()
	var gun_m = BoxMesh.new()
	gun_m.size = Vector3(0.16, 0.18, 0.55)
	var gun_mat = StandardMaterial3D.new()
	gun_mat.albedo_color = Color("283547")
	gun_mat.metallic = 0.8
	gun_mat.roughness = 0.2
	gun_mat.emission_enabled = true
	gun_mat.emission = CYAN
	gun_mat.emission_energy_multiplier = 0.7
	gun.mesh = gun_m
	gun.material_override = gun_mat
	gun.position = Vector3(0.28, -0.22, -0.55)
	player_camera.add_child(gun)

	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Spawna 1 Bot Aliado (Time Azul) e 2 Bots Inimigos (Time Vermelho)
func spawn_bots() -> void:
	# Bot Aliado (Time 0 - Azul)
	ally_bot = create_bot("Bot_Aliado_Azul", 0, BLUE_SPAWN + Vector3(1.5, 0, 0), CYAN)
	
	# 2 Bots Inimigos (Time 1 - Vermelho)
	enemy_bots.clear()
	var bot_red1 = create_bot("Bot_Inimigo_1", 1, RED_SPAWN + Vector3(-1.5, 0, 0), CORAL)
	var bot_red2 = create_bot("Bot_Inimigo_2", 1, RED_SPAWN + Vector3(1.5, 0, 0), CORAL)
	enemy_bots.append(bot_red1)
	enemy_bots.append(bot_red2)

func create_bot(bot_name: String, team: int, pos: Vector3, team_color: Color) -> CharacterBody3D:
	var bot = CharacterBody3D.new()
	bot.name = bot_name
	bot.position = pos
	bot.set_meta("team", team)
	bot.set_meta("is_character", true)
	bot.set_meta("hp", BOT_MAX_HP)
	bot.set_meta("max_hp", BOT_MAX_HP)
	bot.set_meta("dead", false)
	bot.set_meta("respawn_timer", 0.0)
	bot.set_meta("shoot_cd", randf_range(0.2, 0.8))
	bot.set_meta("target_route_x", [-7.0, 0.0, 7.0].pick_random()) # Escolhe uma rota (Esquerda, Centro, Direita)

	var col = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	bot.add_child(col)

	# Modelo visual do robô
	var body_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.38
	cyl.height = 1.4
	var mat = StandardMaterial3D.new()
	mat.albedo_color = team_color
	mat.metallic = 0.5
	mat.roughness = 0.3
	body_mesh.mesh = cyl
	body_mesh.material_override = mat
	body_mesh.position.y = 0.85
	bot.add_child(body_mesh)

	# Cabeça com visor brilhante
	var head = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.45
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color("1e293b")
	h_mat.emission_enabled = true
	h_mat.emission = team_color
	h_mat.emission_energy_multiplier = 1.2
	head.mesh = sphere
	head.material_override = h_mat
	head.position = Vector3(0, 1.55, 0)
	bot.add_child(head)

	# Barra de HP 3D sobre o robô
	var hp_label_3d = Label3D.new()
	hp_label_3d.name = "HPText"
	hp_label_3d.text = "100%"
	hp_label_3d.font_size = 28
	hp_label_3d.pixel_size = 0.01
	hp_label_3d.modulate = team_color
	hp_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label_3d.position = Vector3(0, 2.0, 0)
	bot.add_child(hp_label_3d)

	add_child(bot)
	return bot

func setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	# Mira central (Crosshair)
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_layer.add_child(crosshair)
	
	var ch_tex = ColorRect.new()
	ch_tex.color = Color(1, 1, 1, 0.85)
	ch_tex.size = Vector2(4, 4)
	ch_tex.position = Vector2(-2, -2)
	crosshair.add_child(ch_tex)

	# Topo: Placar das Fortalezas
	var top_panel = PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size = Vector2(0, 60)
	
	var top_box = HBoxContainer.new()
	top_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_panel.add_child(top_box)

	fortress_label_blue = Label.new()
	fortress_label_blue.text = "🔵 SUA FORTALEZA: 100%"
	fortress_label_blue.add_theme_color_override("font_color", CYAN)
	fortress_label_blue.add_theme_font_size_override("font_size", 18)
	top_box.add_child(fortress_label_blue)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_box.add_child(spacer)

	fortress_label_red = Label.new()
	fortress_label_red.text = "🔴 FORTALEZA INIMIGA: 100%"
	fortress_label_red.add_theme_color_override("font_color", CORAL)
	fortress_label_red.add_theme_font_size_override("font_size", 18)
	top_box.add_child(fortress_label_red)

	hud_layer.add_child(top_panel)

	# Fundo: Barra de Vida do Jogador
	var bottom_box = VBoxContainer.new()
	bottom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_box.position = Vector2(30, -80)
	hud_layer.add_child(bottom_box)

	hp_label = Label.new()
	hp_label.text = "VIDA: 100 / 100"
	hp_label.add_theme_color_override("font_color", WHITE)
	hp_label.add_theme_font_size_override("font_size", 16)
	bottom_box.add_child(hp_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(240, 22)
	hp_bar.max_value = PLAYER_MAX_HP
	hp_bar.value = PLAYER_MAX_HP
	hp_bar.show_percentage = false
	bottom_box.add_child(hp_bar)

	# Label de Respawn
	respawn_label = Label.new()
	respawn_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	respawn_label.add_theme_font_size_override("font_size", 28)
	respawn_label.add_theme_color_override("font_color", CORAL)
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_label.text = ""
	hud_layer.add_child(respawn_label)

	# Banner de Fim de Jogo (Vitória / Derrota)
	status_banner = Label.new()
	status_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	status_banner.add_theme_font_size_override("font_size", 38)
	status_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_banner.text = ""
	hud_layer.add_child(status_banner)

	# Botão de Sair / Menu no topo direito
	var btn_exit = Button.new()
	btn_exit.text = "SAIR"
	btn_exit.custom_minimum_size = Vector2(90, 40)
	btn_exit.position = Vector2(1170, 10)
	btn_exit.pressed.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	hud_layer.add_child(btn_exit)

	# Controles de Toque Móvel
	setup_mobile_touch_hud()

func setup_mobile_touch_hud() -> void:
	touch_controls = Control.new()
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(touch_controls)

	# Botão virtual de Atirar no canto inferior direito
	var shoot_btn = Button.new()
	shoot_btn.text = "FOGO"
	shoot_btn.custom_minimum_size = Vector2(90, 90)
	shoot_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	shoot_btn.position = Vector2(-120, -120)
	shoot_btn.add_theme_font_size_override("font_size", 20)
	shoot_btn.button_down.connect(func(): shoot_requested = true)
	shoot_btn.button_up.connect(func(): shoot_requested = false)
	touch_controls.add_child(shoot_btn)

	# Botão de Pular / Correr
	var jump_btn = Button.new()
	jump_btn.text = "PULO"
	jump_btn.custom_minimum_size = Vector2(70, 70)
	jump_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_btn.position = Vector2(-210, -90)
	jump_btn.pressed.connect(func():
		if is_instance_valid(player) and player.is_on_floor():
			player.velocity.y = 5.5
	)
	touch_controls.add_child(jump_btn)

func _unhandled_input(event: InputEvent) -> void:
	if match_over:
		return

	# Tecla ESC para soltar/capturar mouse
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Controle de Câmera pelo Mouse no PC
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player_dead:
		player.rotate_y(-event.relative.x * 0.003)
		player_camera.rotate_x(-event.relative.y * 0.003)
		player_camera.rotation.x = clampf(player_camera.rotation.x, -deg_to_rad(80), deg_to_rad(80))

	# Disparo com clique do mouse
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			shoot_requested = event.pressed

	# Toque na tela (para mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			# Metade esquerda = movimento, metade direita = olhar
			if event.position.x < get_viewport().size.x * 0.5:
				touch_move_index = event.index
				touch_move_pos = event.position
			else:
				touch_look_index = event.index
				touch_look_start = event.position
		else:
			if event.index == touch_move_index:
				touch_move_index = -1
				move_stick_vector = Vector2.ZERO
			elif event.index == touch_look_index:
				touch_look_index = -1

	if event is InputEventScreenDrag:
		if event.index == touch_look_index and not player_dead:
			player.rotate_y(-event.relative.x * 0.005)
			player_camera.rotate_x(-event.relative.y * 0.005)
			player_camera.rotation.x = clampf(player_camera.rotation.x, -deg_to_rad(80), deg_to_rad(80))
		elif event.index == touch_move_index:
			var diff = event.position - touch_move_pos
			move_stick_vector = (diff / 60.0).limit_length(1.0)

func _physics_process(dt: float) -> void:
	if match_over:
		return

	process_player(dt)
	process_bots(dt)
	process_bullets(dt)
	update_hud()

func process_player(dt: float) -> void:
	if not is_instance_valid(player):
		return

	# Respawn se estiver morto
	if player_dead:
		player_respawn_timer -= dt
		respawn_label.text = "VOCÊ FOI DESTRUÍDO!\nRENASCENDO EM: %d s" % int(ceilf(player_respawn_timer))
		if player_respawn_timer <= 0.0:
			respawn_player()
		return

	# Movimento do Jogador
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0

	# Combina teclado e analógico móvel
	if move_stick_vector.length_squared() > 0.01:
		input_dir = move_stick_vector

	input_dir = input_dir.normalized()
	var forward = -player.global_transform.basis.z
	var right = player.global_transform.basis.x
	forward.y = 0; forward = forward.normalized()
	right.y = 0; right = right.normalized()

	var move_speed = 7.0
	var wish_dir = (forward * -input_dir.y + right * input_dir.x).normalized()
	var target_vel = wish_dir * move_speed

	# Gravidade
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * dt
	else:
		if Input.is_key_pressed(KEY_SPACE):
			player.velocity.y = 5.5

	player.velocity.x = lerpf(player.velocity.x, target_vel.x, 14.0 * dt)
	player.velocity.z = lerpf(player.velocity.z, target_vel.z, 14.0 * dt)
	player.move_and_slide()

	# Disparo do Jogador
	shoot_cooldown -= dt
	if (shoot_requested or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and shoot_cooldown <= 0.0:
		shoot_cooldown = SHOOT_INTERVAL
		var shoot_origin = player_camera.global_position + (-player_camera.global_transform.basis.z * 0.5)
		var shoot_dir = -player_camera.global_transform.basis.z
		fire_bullet(shoot_origin, shoot_dir, 0, CYAN)

func respawn_player() -> void:
	player_dead = false
	player_hp = PLAYER_MAX_HP
	respawn_label.text = ""
	player.global_position = BLUE_SPAWN
	player.velocity = Vector3.ZERO
	player_camera.rotation = Vector3.ZERO

## IA dos Bots (Aliado e Inimigos)
func process_bots(dt: float) -> void:
	var all_bots = []
	if is_instance_valid(ally_bot): all_bots.append(ally_bot)
	for b in enemy_bots:
		if is_instance_valid(b): all_bots.append(b)

	for bot in all_bots:
		var dead = bot.get_meta("dead", false)
		if dead:
			var timer = bot.get_meta("respawn_timer", 0.0) - dt
			bot.set_meta("respawn_timer", timer)
			if timer <= 0.0:
				respawn_bot(bot)
			continue

		var team = bot.get_meta("team", 0)
		var shoot_cd = bot.get_meta("shoot_cd", 0.0) - dt

		# Alvo: inimigo ou fortaleza inimiga
		var enemy_char = find_closest_enemy_char(bot, team)
		var target_pos: Vector3

		if enemy_char != null and bot.global_position.distance_to(enemy_char.global_position) < 16.0:
			# Combate contra personagem inimigo
			target_pos = enemy_char.global_position
			
			# Mirar e disparar
			var to_target = (target_pos - bot.global_position)
			to_target.y = 0
			bot.look_at(bot.global_position + to_target.normalized(), Vector3.UP)

			if shoot_cd <= 0.0:
				shoot_cd = randf_range(0.3, 0.6)
				var bullet_origin = bot.global_position + Vector3(0, 1.2, 0)
				var bullet_dir = (enemy_char.global_position + Vector3(0, 1.0, 0) - bullet_origin).normalized()
				fire_bullet(bullet_origin, bullet_dir, team, CYAN if team == 0 else CORAL)
		else:
			# Avançar pela rota em direção à fortaleza adversária
			var route_x = bot.get_meta("target_route_x", 0.0)
			var dest_z = -18.0 if team == 0 else 18.0 # Ataca a base inimiga
			target_pos = Vector3(route_x, bot.global_position.y, dest_z)

			# Atacar tijolos da fortaleza inimiga se estiver perto
			var target_brick = find_closest_enemy_brick(bot.global_position, team)
			if target_brick != null and bot.global_position.distance_to(target_brick.global_position) < 14.0:
				target_pos = target_brick.global_position
				var to_brick = (target_pos - bot.global_position); to_brick.y = 0
				bot.look_at(bot.global_position + to_brick.normalized(), Vector3.UP)
				
				if shoot_cd <= 0.0:
					shoot_cd = randf_range(0.4, 0.7)
					var bullet_origin = bot.global_position + Vector3(0, 1.2, 0)
					var bullet_dir = (target_brick.global_position - bullet_origin).normalized()
					fire_bullet(bullet_origin, bullet_dir, team, CYAN if team == 0 else CORAL)

		# Mover bot em direção ao target_pos
		var move_dir = (target_pos - bot.global_position)
		move_dir.y = 0
		if move_dir.length() > 4.0: # Mantém distância de combate
			move_dir = move_dir.normalized()
			bot.velocity.x = move_dir.x * 4.5
			bot.velocity.z = move_dir.z * 4.5
		else:
			bot.velocity.x = move_toward(bot.velocity.x, 0, 8.0 * dt)
			bot.velocity.z = move_toward(bot.velocity.z, 0, 8.0 * dt)

		if not bot.is_on_floor():
			bot.velocity.y -= 18.0 * dt

		bot.move_and_slide()
		bot.set_meta("shoot_cd", shoot_cd)

func find_closest_enemy_char(from_bot: CharacterBody3D, team: int) -> CharacterBody3D:
	var closest: CharacterBody3D = null
	var min_dist = INF

	if team == 1:
		# Bot vermelho procura jogador azul ou bot aliado azul
		if is_instance_valid(player) and not player_dead:
			var d = from_bot.global_position.distance_to(player.global_position)
			if d < min_dist: min_dist = d; closest = player
		if is_instance_valid(ally_bot) and not ally_bot.get_meta("dead", false):
			var d = from_bot.global_position.distance_to(ally_bot.global_position)
			if d < min_dist: min_dist = d; closest = ally_bot
	else:
		# Bot azul procura bots vermelhos
		for b in enemy_bots:
			if is_instance_valid(b) and not b.get_meta("dead", false):
				var d = from_bot.global_position.distance_to(b.global_position)
				if d < min_dist: min_dist = d; closest = b

	return closest

func find_closest_enemy_brick(pos: Vector3, team: int) -> StaticBody3D:
	var brick_list = red_bricks if team == 0 else blue_bricks
	var closest: StaticBody3D = null
	var min_dist = INF
	for b in brick_list:
		if is_instance_valid(b):
			var d = pos.distance_to(b.global_position)
			if d < min_dist:
				min_dist = d
				closest = b
	return closest

func respawn_bot(bot: CharacterBody3D) -> void:
	bot.set_meta("dead", false)
	bot.set_meta("hp", BOT_MAX_HP)
	var team = bot.get_meta("team", 0)
	bot.global_position = (BLUE_SPAWN if team == 0 else RED_SPAWN) + Vector3(randf_range(-2, 2), 0, 0)
	bot.visible = true
	var hp_txt = bot.get_node_or_null("HPText") as Label3D
	if hp_txt: hp_txt.text = "100%"

## Sistema de Balas e Projéteis
func fire_bullet(origin: Vector3, dir: Vector3, team: int, col: Color) -> void:
	var bullet = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	bullet.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	bullet.material_override = mat

	bullet.position = origin
	bullet.set_meta("dir", dir.normalized())
	bullet.set_meta("team", team)
	bullet.set_meta("life", 3.0) # 3 segundos de vida
	bullets_container.add_child(bullet)

func process_bullets(dt: float) -> void:
	var space_state = get_world_3d().direct_space_state

	for bullet in bullets_container.get_children():
		var life = bullet.get_meta("life", 0.0) - dt
		if life <= 0.0:
			bullet.queue_free()
			continue
		bullet.set_meta("life", life)

		var dir = bullet.get_meta("dir", Vector3.FORWARD)
		var team = bullet.get_meta("team", 0)
		var from_pos = bullet.global_position
		var to_pos = from_pos + dir * BULLET_SPEED * dt

		# Raycast para detectar impacto
		var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		var result = space_state.intersect_ray(query)

		if not result.is_empty():
			var hit_collider = result.collider
			bullet.global_position = result.position

			# Acertou um tijolo da fortaleza
			if hit_collider.has_meta("is_brick"):
				var brick_team = hit_collider.get_meta("team", -1)
				if brick_team != team: # Apenas tijolos da fortaleza inimiga tomam dano
					damage_brick(hit_collider, BULLET_DAMAGE_BRICK)
				bullet.queue_free()
				continue

			# Acertou um personagem (Jogador ou Bot)
			elif hit_collider.has_meta("is_character"):
				var char_team = hit_collider.get_meta("team", -1)
				if char_team != team: # Inimigo
					damage_character(hit_collider, BULLET_DAMAGE_CHAR)
				bullet.queue_free()
				continue

			# Acertou parede ou chão
			bullet.queue_free()
		else:
			bullet.global_position = to_pos

func damage_brick(brick: StaticBody3D, dmg: float) -> void:
	var hp = brick.get_meta("hp", 3) - dmg
	brick.set_meta("hp", hp)

	# Efeito de dano visual (pisca branco ou encolhe ligeiramente)
	brick.scale = Vector3.ONE * (0.6 + 0.13 * hp)

	if hp <= 0:
		var brick_team = brick.get_meta("team", 0)
		if brick_team == 0:
			blue_bricks.erase(brick)
			blue_bricks_alive = maxi(0, blue_bricks_alive - 1)
		else:
			red_bricks.erase(brick)
			red_bricks_alive = maxi(0, red_bricks_alive - 1)
		brick.queue_free()
		check_win_condition()

func damage_character(target: Node, dmg: float) -> void:
	if target == player and not player_dead:
		player_hp = maxf(0.0, player_hp - dmg)
		if player_hp <= 0.0:
			player_dead = true
			player_respawn_timer = RESPAWN_TIME
	elif target is CharacterBody3D:
		var hp = target.get_meta("hp", BOT_MAX_HP) - dmg
		target.set_meta("hp", hp)
		var hp_txt = target.get_node_or_null("HPText") as Label3D
		if hp_txt:
			hp_txt.text = "%d%%" % int(clampf((hp / BOT_MAX_HP) * 100.0, 0, 100))
		if hp <= 0.0:
			target.set_meta("dead", true)
			target.set_meta("respawn_timer", RESPAWN_TIME)
			target.visible = false

func check_win_condition() -> void:
	if match_over:
		return

	if red_bricks_alive <= 0:
		# Time Azul venceu (Destruiu todos os tijolos da fortaleza vermelha!)
		match_over = true
		winner_team = 0
		status_banner.text = "🏆 VITÓRIA! 🏆\nFORTALEZA INIMIGA TOTALMENTE DESTRUÍDA!"
		status_banner.add_theme_color_override("font_color", CYAN)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif blue_bricks_alive <= 0:
		# Time Vermelho venceu
		match_over = true
		winner_team = 1
		status_banner.text = "💀 DERROTA! 💀\nSUA FORTALEZA FOI DESTRUÍDA!"
		status_banner.add_theme_color_override("font_color", CORAL)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_hud() -> void:
	if is_instance_valid(hp_bar):
		hp_bar.value = player_hp
		hp_label.text = "VIDA: %d / %d" % [int(player_hp), int(PLAYER_MAX_HP)]

	if initial_bricks_per_fortress > 0:
		var blue_pct = int((float(blue_bricks_alive) / initial_bricks_per_fortress) * 100.0)
		var red_pct = int((float(red_bricks_alive) / initial_bricks_per_fortress) * 100.0)
		fortress_label_blue.text = "🔵 SUA FORTALEZA: %d%% (%d tijolos)" % [blue_pct, blue_bricks_alive]
		fortress_label_red.text = "🔴 FORTALEZA INIMIGA: %d%% (%d tijolos)" % [red_pct, red_bricks_alive]


extends Node2D

## World scene controller - sets up dark ambient and initial biome

var camera: Camera2D
var player: Node2D
var fog_rect: ColorRect

# Camera bounds (map limits) - sized for expansive cave (600*4=2400 wide, 450*4=1800 tall)
const CAMERA_LEFT: float = -1200.0
const CAMERA_RIGHT: float = 1200.0
const CAMERA_TOP: float = -1500.0
const CAMERA_BOTTOM: float = 400.0

# Debug system
var debug_enabled: bool = false
var debug_overlay: Control = null
var debug_label: Label = null
var map_zoom_enabled: bool = false
var normal_zoom: Vector2 = Vector2(3.5, 3.5)
var map_zoom: Vector2 = Vector2(0.3, 0.3)  # Zoomed out to see entire map

func _ready():
	# Get references
	camera = $Camera2D
	player = $Player
	fog_rect = $FogLayer/Fog
	
	# Set up very dark ambient
	var viewport = get_viewport()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	
	# Set very dark ambient lighting
	RenderingServer.set_default_clear_color(Color(0.01, 0.01, 0.02, 1))  # Almost black
	
	# Initialize biome audio
	AudioManager.play_biome_audio(GameState.current_biome)
	
	# Wait for cave generation to complete, then position player safely
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get safe spawn position from cave generator
	var cave_terrain = $CaveTerrain
	if cave_terrain and cave_terrain.has_method("get_safe_spawn_position"):
		var safe_pos = cave_terrain.get_safe_spawn_position()
		if player:
			player.global_position = safe_pos
			print("Player spawned at safe position: ", safe_pos)
			
			# Verify spawn position is collision-free
			# Wait one more frame for physics to initialize
			await get_tree().process_frame
			verify_player_spawn_position()
	
	# Set up camera to follow player
	if camera and player:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0
		# Zoom camera in for much closer perspective (game-like feel)
		camera.zoom = normal_zoom
		# Set camera limits
		camera.limit_left = int(CAMERA_LEFT)
		camera.limit_right = int(CAMERA_RIGHT)
		camera.limit_top = int(CAMERA_TOP)
		camera.limit_bottom = int(CAMERA_BOTTOM)
	
	# Set up debug system
	setup_debug_overlay()

func _process(_delta: float):
	# Handle debug hotkeys
	handle_debug_input()
	
	# Camera follows player with pixel snapping and bounds clamping
	if camera and player:
		var target_pos = player.global_position
		
		# Clamp to bounds
		target_pos.x = clamp(target_pos.x, CAMERA_LEFT, CAMERA_RIGHT)
		target_pos.y = clamp(target_pos.y, CAMERA_TOP, CAMERA_BOTTOM)
		
		# Smooth camera movement (camera will handle smoothing)
		camera.global_position = target_pos
		
		# Snap camera position to pixels for pixel-perfect rendering
		camera.global_position = camera.global_position.round()
	
	# Update debug display
	if debug_enabled:
		update_debug_display()

## Verify player spawn position is collision-free
func verify_player_spawn_position():
	if not player:
		return
	
	var space_state = get_world_2d().direct_space_state
	var player_collision = player.get_node_or_null("CollisionShape2D")
	
	if not player_collision or not player_collision.shape is RectangleShape2D:
		return
	
	var shape = player_collision.shape as RectangleShape2D
	
	# Check if player is colliding with anything
	var shape_query = PhysicsShapeQueryParameters2D.new()
	shape_query.shape = shape
	shape_query.transform.origin = player.global_position
	shape_query.collision_mask = 1
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(shape_query, 1)
	if results.size() > 0:
		print("World: WARNING - Player spawn position has collision!")
		# Player's own validation will handle finding a safe position
	else:
		print("World: Player spawn position verified as collision-free")

## Set up debug overlay UI
func setup_debug_overlay():
	debug_overlay = Control.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_overlay.visible = false
	add_child(debug_overlay)
	
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	debug_overlay.add_child(debug_label)

## Handle debug input (function keys)
func handle_debug_input():
	# F1: Toggle debug info display
	if Input.is_key_pressed(KEY_F1):
		if not has_meta("f1_pressed"):
			set_meta("f1_pressed", true)
			debug_enabled = not debug_enabled
			if debug_overlay:
				debug_overlay.visible = debug_enabled
			print("Debug info: ", "ON" if debug_enabled else "OFF")
	elif has_meta("f1_pressed"):
		remove_meta("f1_pressed")
	
	# F2: Toggle map zoom (complete zoom out)
	if Input.is_key_pressed(KEY_F2):
		if not has_meta("f2_pressed"):
			set_meta("f2_pressed", true)
			map_zoom_enabled = not map_zoom_enabled
			if camera:
				camera.zoom = map_zoom if map_zoom_enabled else normal_zoom
			print("Map zoom: ", "ON" if map_zoom_enabled else "OFF")
	elif has_meta("f2_pressed"):
		remove_meta("f2_pressed")
	
	# F3: Print player position and state
	if Input.is_key_pressed(KEY_F3):
		if not has_meta("f3_pressed"):
			set_meta("f3_pressed", true)
			if player and player is CharacterBody2D:
				var player_body = player as CharacterBody2D
				print("=== Player Debug Info ===")
				print("Position: ", player_body.global_position)
				print("On Floor: ", player_body.is_on_floor())
				if player_body.is_on_floor():
					var normal = player_body.get_floor_normal()
					print("Floor Normal: ", normal)
				print("Velocity: ", player_body.velocity)
			else:
				print("Player not found or not CharacterBody2D")
	elif has_meta("f3_pressed"):
		remove_meta("f3_pressed")
	
	# F4: Print cave generation info
	if Input.is_key_pressed(KEY_F4):
		if not has_meta("f4_pressed"):
			set_meta("f4_pressed", true)
			var cave_terrain = $CaveTerrain
			if cave_terrain:
				print("=== Cave Generation Debug ===")
				if cave_terrain.has_method("get_safe_spawn_position"):
					var spawn_pos = cave_terrain.get_safe_spawn_position()
					print("Safe Spawn Position: ", spawn_pos)
				if "caverns" in cave_terrain:
					print("Number of Caverns: ", cave_terrain.caverns.size())
			else:
				print("Cave terrain not found")
	elif has_meta("f4_pressed"):
		remove_meta("f4_pressed")
	
	# F5: Print GameState info
	if Input.is_key_pressed(KEY_F5):
		if not has_meta("f5_pressed"):
			set_meta("f5_pressed", true)
			print("=== GameState Debug ===")
			print("Health: ", GameState.health, " / ", GameState.max_health)
			print("Charge: ", GameState.charge, " / ", GameState.max_charge)
			print("Current Biome: ", GameState.current_biome)
			print("Log Entries: ", GameState.log_entries.size())
	elif has_meta("f5_pressed"):
		remove_meta("f5_pressed")

## Update debug display with current information
func update_debug_display():
	if not debug_label or not player:
		return
	
	var info_text = "=== DEBUG INFO ===\n"
	info_text += "F1: Toggle Debug | F2: Map Zoom | F3: Player Info | F4: Cave Info | F5: GameState\n\n"
	
	# Player info
	info_text += "PLAYER:\n"
	info_text += "  Position: " + str(player.global_position.round()) + "\n"
	if player is CharacterBody2D:
		var player_body = player as CharacterBody2D
		info_text += "  Velocity: " + str(player_body.velocity.round()) + "\n"
		info_text += "  On Floor: " + str(player_body.is_on_floor()) + "\n"
		if player_body.is_on_floor():
			var normal = player_body.get_floor_normal()
			info_text += "  Floor Normal: " + str(normal.round()) + "\n"
	
	# Camera info
	if camera:
		info_text += "\nCAMERA:\n"
		info_text += "  Position: " + str(camera.global_position.round()) + "\n"
		info_text += "  Zoom: " + str(camera.zoom) + "\n"
		info_text += "  Map Zoom: " + ("ON" if map_zoom_enabled else "OFF") + "\n"
	
	# GameState info
	info_text += "\nGAMESTATE:\n"
	info_text += "  Health: " + str(int(GameState.health)) + " / " + str(int(GameState.max_health)) + "\n"
	info_text += "  Charge: " + str(int(GameState.charge)) + " / " + str(int(GameState.max_charge)) + "\n"
	info_text += "  Biome: " + str(GameState.current_biome) + "\n"
	
	# Cave info
	var cave_terrain = $CaveTerrain
	if cave_terrain and "caverns" in cave_terrain:
		info_text += "\nCAVE:\n"
		info_text += "  Caverns: " + str(cave_terrain.caverns.size()) + "\n"
	
	debug_label.text = info_text

extends Node2D

## World scene controller - sets up dark ambient and initial biome

var camera: Camera2D
var player: Node2D
var fog_rect: ColorRect

# Camera bounds (map limits)
const CAMERA_LEFT: float = -2000.0
const CAMERA_RIGHT: float = 2000.0
const CAMERA_TOP: float = -400.0
const CAMERA_BOTTOM: float = 450.0

func _ready():
	# Get references
	camera = $Camera2D
	player = $Player
	fog_rect = $FogLayer/Fog
	
	# Set up very dark ambient
	var viewport = get_viewport()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	
	# Initialize biome audio
	AudioManager.play_biome_audio(GameState.current_biome)
	
	# Set up camera to follow player
	if camera and player:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0
		# Set camera limits
		camera.limit_left = int(CAMERA_LEFT)
		camera.limit_right = int(CAMERA_RIGHT)
		camera.limit_top = int(CAMERA_TOP)
		camera.limit_bottom = int(CAMERA_BOTTOM)

func _process(_delta: float):
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

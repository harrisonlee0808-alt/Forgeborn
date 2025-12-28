extends Node2D

## World scene controller - sets up dark ambient and initial biome

var camera: Camera2D
var player: Node2D

func _ready():
	# Get references
	camera = $Camera2D
	player = $Player
	
	# Set up very dark ambient
	var viewport = get_viewport()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	
	# Initialize biome audio
	AudioManager.play_biome_audio(GameState.current_biome)
	
	# Set up camera to follow player
	if camera and player:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0

func _process(_delta: float):
	# Camera follows player with pixel snapping
	if camera and player:
		camera.global_position = player.global_position
		# Snap camera position to pixels for pixel-perfect rendering
		camera.global_position = camera.global_position.round()

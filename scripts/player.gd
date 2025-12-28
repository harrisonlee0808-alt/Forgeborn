extends CharacterBody2D

## Player controller - handles movement and player-specific logic

const SPEED: float = 100.0
const CHARGE_DRAIN_RATE: float = 1.0  # Charge per second

var sprite: ColorRect
var light: Light2D

var charge_drain_timer: float = 0.0

func _ready():
	# Get references
	sprite = $Sprite2D
	light = $Light2D
	
	# Initialize GameState values if needed
	GameState.health = GameState.max_health
	GameState.charge = GameState.max_charge

func _physics_process(delta: float):
	# Handle input
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_vector.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_vector.x += 1
	
	# Normalize for diagonal movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	
	# Apply movement
	velocity = input_vector * SPEED
	move_and_slide()
	
	# Update charge drain
	charge_drain_timer += delta
	if charge_drain_timer >= 1.0:
		GameState.charge = max(0.0, GameState.charge - CHARGE_DRAIN_RATE)
		charge_drain_timer = 0.0

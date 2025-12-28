extends CharacterBody2D

## Player controller - handles platformer movement and player-specific logic

const SPEED: float = 120.0
const JUMP_VELOCITY: float = -300.0
const GRAVITY: float = 980.0
const COYOTE_TIME: float = 0.15  # Time after leaving ground where jump still works
const JUMP_BUFFER_TIME: float = 0.1  # Time before landing where jump input is remembered
const AIR_CONTROL: float = 0.6  # Multiplier for horizontal control in air

const CHARGE_DRAIN_RATE: float = 1.0  # Charge per second

var sprite: ColorRect
var light: Light2D

var charge_drain_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var nearest_interactable: Node = null

func _ready():
	# Get references
	sprite = $Sprite2D
	light = $Light2D
	
	# Add light to group for area trigger access
	if light:
		light.add_to_group("player_light")
	
	# Initialize GameState values if needed
	GameState.health = GameState.max_health
	GameState.charge = GameState.max_charge

func _physics_process(delta: float):
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	
	# Update coyote time
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		was_on_floor = true
	else:
		coyote_timer -= delta
		if was_on_floor:
			was_on_floor = false
	
	# Handle jump input (buffer)
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta
	
	# Handle jumping
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	
	# Handle horizontal movement
	var input_dir = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir += 1.0
	
	# Apply movement with air control
	var control = 1.0 if is_on_floor() else AIR_CONTROL
	velocity.x = input_dir * SPEED * control
	
	# Apply movement and snap positions to pixel grid for pixel-perfect rendering
	move_and_slide()
	global_position = global_position.round()
	
	# Handle interaction
	update_nearest_interactable()
	if Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_E):
		if nearest_interactable and nearest_interactable.has_method("interact"):
			nearest_interactable.interact(self)
	
	# Update charge drain
	charge_drain_timer += delta
	if charge_drain_timer >= 1.0:
		GameState.charge = max(0.0, GameState.charge - CHARGE_DRAIN_RATE)
		charge_drain_timer = 0.0

## Find the nearest interactable within range
func update_nearest_interactable():
	var interactables = get_tree().get_nodes_in_group("interactable")
	var closest_dist = INF
	var closest = null
	
	for interactable in interactables:
		if not interactable.has_method("can_interact") or not interactable.can_interact():
			continue
		
		var dist = global_position.distance_to(interactable.global_position)
		var range_val = 80.0
		if "interaction_range" in interactable:
			range_val = interactable.interaction_range
		
		if dist <= range_val and dist < closest_dist:
			closest_dist = dist
			closest = interactable
	
	nearest_interactable = closest

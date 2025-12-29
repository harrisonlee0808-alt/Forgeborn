extends CharacterBody2D

## Player controller - handles platformer movement and player-specific logic

const MAX_SPEED: float = 140.0
const ACCELERATION: float = 1200.0
const FRICTION: float = 1000.0
const AIR_ACCELERATION: float = 600.0
const AIR_FRICTION: float = 200.0

const JUMP_VELOCITY: float = -380.0
const JUMP_CUT_MULTIPLIER: float = 0.5  # Reduce velocity when releasing jump early
const GRAVITY: float = 1100.0
const MAX_FALL_SPEED: float = 600.0

const COYOTE_TIME: float = 0.12  # Time after leaving ground where jump still works
const JUMP_BUFFER_TIME: float = 0.1  # Time before landing where jump input is remembered

const CHARGE_DRAIN_RATE: float = 1.0  # Charge per second

var sprite: ColorRect
var light: Light2D
var interaction_area: Area2D

var charge_drain_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var nearest_interactable: Node = null
var overlapping_interactables: Array = []

func _ready():
	# Get references
	sprite = $Sprite2D
	light = $Light2D
	interaction_area = $InteractionArea
	
	# Add light to group for area trigger access
	if light:
		light.add_to_group("player_light")
	
	# Connect interaction area signals
	if interaction_area:
		if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
			interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
			interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	# Initialize GameState values if needed
	GameState.health = GameState.max_health
	GameState.charge = GameState.max_charge

func _physics_process(delta: float):
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		if velocity.y > 0:
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
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_space") or Input.is_key_pressed(KEY_SPACE):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta
	
	# Handle jumping
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	
	# Jump cut - reduce jump height when releasing jump early
	if Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_space"):
		if velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER
	
	# Handle horizontal movement
	var input_dir = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir += 1.0
	
	# Apply acceleration/deceleration with friction
	if is_on_floor():
		if input_dir != 0:
			# Accelerate
			velocity.x = move_toward(velocity.x, input_dir * MAX_SPEED, ACCELERATION * delta)
		else:
			# Apply friction
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	else:
		# Air control
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * MAX_SPEED, AIR_ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)
	
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

## Called when interactable enters interaction area
func _on_interaction_area_body_entered(body: Node2D):
	# Check if this is an interactable (has the interactable group or can_interact method)
	if body.is_in_group("interactable") or body.has_method("can_interact"):
		if body != self and not overlapping_interactables.has(body):
			overlapping_interactables.append(body)

## Called when interactable leaves interaction area
func _on_interaction_area_body_exited(body: Node2D):
	if overlapping_interactables.has(body):
		overlapping_interactables.erase(body)
		if nearest_interactable == body:
			nearest_interactable = null

## Find the nearest interactable within range
func update_nearest_interactable():
	var closest = null
	var closest_dist = INF
	
	for interactable in overlapping_interactables:
		if not interactable.has_method("can_interact") or not interactable.can_interact():
			continue
		
		var dist = global_position.distance_to(interactable.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = interactable
	
	nearest_interactable = closest

## Get nearest interactable (for HUD)
func get_nearest_interactable():
	return nearest_interactable

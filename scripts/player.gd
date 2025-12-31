extends CharacterBody2D

## Player controller - handles platformer movement and player-specific logic

const MAX_SPEED: float = 180.0
const ACCELERATION: float = 1800.0
const FRICTION: float = 2500.0  # High friction for responsive stopping
const AIR_ACCELERATION: float = 900.0
const AIR_FRICTION: float = 300.0

const JUMP_VELOCITY: float = -350.0
const JUMP_CUT_MULTIPLIER: float = 0.5  # Reduce velocity when releasing jump early
const GRAVITY: float = 800.0
const MAX_FALL_SPEED: float = 450.0

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

# Track key states for just_pressed/just_released detection
var space_pressed_last_frame: bool = false
var e_pressed_last_frame: bool = false

func _ready():
	# Get references
	sprite = $Sprite2D
	light = $Light2D
	interaction_area = $InteractionArea
	var collision_shape = $CollisionShape2D
	
	# Make sprite match collision shape exactly, offset by 1px up and 1px left for perfect visual alignment
	if sprite and collision_shape:
		var collision = collision_shape.shape
		if collision is RectangleShape2D:
			var shape = collision as RectangleShape2D
			var width = shape.size.x
			var height = shape.size.y
			# Set sprite to match collision shape
			sprite.offset_left = -width / 2.0
			sprite.offset_top = -height / 2.0
			sprite.offset_right = width / 2.0
			sprite.offset_bottom = height / 2.0
	
	# Set up CharacterBody2D physics properties for better collision and slope climbing
	floor_stop_on_slope = false  # Allow movement up slopes
	floor_constant_speed = false  # Allow natural speed variation on slopes
	floor_snap_length = 0.0  # Dynamic - set based on movement direction
	floor_max_angle = deg_to_rad(45)  # Allow walking on slopes up to 45 degrees
	safe_margin = 0.5  # Small margin for edge cases
	max_slides = 6  # Allow more slide attempts for slopes
	
	# Create custom torch light texture (soft circular gradient bubble)
	if light:
		create_torch_light_texture()
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
	
	# Validate spawn position - ensure player isn't colliding with anything
	call_deferred("validate_spawn_position")

func create_torch_light_texture():
	# Create a soft circular gradient texture for the torch light bubble
	var texture_size = 256
	var image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(texture_size / 2.0, texture_size / 2.0)
	var max_dist = texture_size / 2.0
	
	# Generate radial gradient with soft falloff
	for y in range(texture_size):
		for x in range(texture_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			var normalized_dist = dist / max_dist
			
			# Soft falloff curve (smooth fade to edge)
			var alpha = 1.0 - normalized_dist
			alpha = pow(alpha, 2.5)  # Exponential falloff for smooth bubble
			alpha = clamp(alpha, 0.0, 1.0)
			
			# Warm torch color (slightly yellow/orange tint)
			var color = Color(1.0, 0.95, 0.85, alpha)
			image.set_pixel(x, y, color)
	
	# Create texture from image
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	# Apply to light
	light.texture = texture
	light.texture_scale = 3.0
	light.energy = 2.5
	light.color = Color(1, 0.95, 0.85, 1)  # Warm torch color

func _physics_process(delta: float):
	# Track key states for just_pressed/just_released detection
	var space_pressed = Input.is_key_pressed(KEY_SPACE)
	var e_pressed = Input.is_key_pressed(KEY_E)
	var space_just_pressed = space_pressed and not space_pressed_last_frame
	var space_just_released = not space_pressed and space_pressed_last_frame
	var e_just_pressed = e_pressed and not e_pressed_last_frame
	
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
	if Input.is_action_just_pressed("ui_accept") or space_just_pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta
	
	# Handle jumping
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	
	# Jump cut - reduce jump height when releasing jump early
	if Input.is_action_just_released("ui_accept") or space_just_released:
		if velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER
	
	# Handle horizontal movement
	var input_dir = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir += 1.0
	
	# Determine slope state (needed for both movement and step climbing)
	var on_slope = false
	var floor_normal = Vector2.UP
	var slope_angle = 0.0
	if is_on_floor():
		# Get floor normal and determine slope state
		floor_normal = get_floor_normal()
		slope_angle = acos(clamp(floor_normal.dot(Vector2.UP), -1.0, 1.0))
		on_slope = slope_angle > 0.01 and slope_angle < floor_max_angle
	
	# Apply acceleration/deceleration with friction
	# Handle slopes with dynamic floor snap and speed adjustment
	if is_on_floor():
		
		# Determine if moving uphill or downhill
		var moving_uphill = false
		var moving_downhill = false
		if on_slope and input_dir != 0:
			# Uphill: input direction opposes normal.x (moving against the slope)
			# Downhill: input direction aligns with normal.x (moving with the slope)
			moving_uphill = (input_dir * floor_normal.x < 0.0)
			moving_downhill = (input_dir * floor_normal.x > 0.0)
		
		# Dynamic floor snap: ONLY when moving uphill and not jumping
		var is_jumping = velocity.y < 0  # Moving upward = jumping
		if moving_uphill and not is_jumping:
			floor_snap_length = 6.0  # Keep player glued to slope when ascending
		else:
			floor_snap_length = 0.0  # Disable snap downhill and in air to prevent bouncing
		
		if input_dir != 0:
			# Calculate base target speed
			var target_speed = input_dir * MAX_SPEED
			
			# Apply speed multiplier based on slope angle and direction
			if on_slope:
				target_speed *= get_slope_speed_multiplier(slope_angle, moving_uphill)
			
			# Accelerate toward target
			velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta)
		else:
			# Apply friction
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	else:
		# Air control
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * MAX_SPEED, AIR_ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)
	
	
	# Pre-movement collision check to prevent clipping into walls
	# Use shape query to check if player would collide at next position
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape = collision_shape.shape as RectangleShape2D
		var space_state = get_world_2d().direct_space_state
		var test_pos = global_position + velocity * delta
		
		var shape_query = PhysicsShapeQueryParameters2D.new()
		shape_query.shape = shape
		shape_query.transform.origin = test_pos
		shape_query.collision_mask = 1
		shape_query.collide_with_areas = false
		shape_query.collide_with_bodies = true
		
		var results = space_state.intersect_shape(shape_query, 1)
		if results.size() > 0:
			# Would collide, check if it's a horizontal wall
			for result in results:
				var normal = result.get("normal", Vector2.ZERO)
				if abs(normal.x) > 0.7:  # Mostly horizontal collision
					if (normal.x > 0 and input_dir < 0) or (normal.x < 0 and input_dir > 0):
						# We're pushing into a wall, zero horizontal velocity
						velocity.x = 0
						break
	
	# Apply movement with proper slope handling
	var was_on_floor_before = is_on_floor()
	
	# Move and slide - this will automatically handle slopes within floor_max_angle
	move_and_slide()
	
	# Handle step climbing AFTER move_and_slide() using position locking (not velocity)
	# This prevents hops and ensures smooth step traversal
	if is_on_floor() and input_dir != 0 and not on_slope:
		var climb_info = can_climb_step(input_dir)
		if climb_info.can_climb:
			# Smoothly lock onto step y position
			var target_y = climb_info.step_top_y
			var current_y = global_position.y
			var climb_distance = current_y - target_y
			
			if climb_distance > 0.1:  # Only if we need to move up
				# Direct position lock - smoothly interpolate to step position
				var climb_speed = 400.0  # pixels per second for smooth but responsive climbing
				var max_climb_this_frame = climb_speed * delta
				var new_y = current_y - min(climb_distance, max_climb_this_frame)
				
				# Check if the new position fits without overlap before applying
				var test_position = Vector2(global_position.x, new_y)
				if check_can_fit(test_position):
					global_position.y = new_y
				else:
					# Position would overlap, try to find a safe position nearby
					# Try positions slightly above and below to find a fit
					var found_safe = false
					for offset in range(1, 5):  # Check up to 4px above/below
						# Try above first
						var test_y_above = new_y - offset
						var test_pos_above = Vector2(global_position.x, test_y_above)
						if check_can_fit(test_pos_above):
							global_position.y = test_y_above
							found_safe = true
							break
						
						# Try below
						var test_y_below = new_y + offset
						var test_pos_below = Vector2(global_position.x, test_y_below)
						if check_can_fit(test_pos_below):
							global_position.y = test_y_below
							found_safe = true
							break
					
					# If no safe position found, don't move (stay at current position)
					# This prevents overlap
				
				# Ensure we maintain floor contact after position adjustment
				# The verify_collision_positioning() call later will handle any corrections
	
	# Post-movement collision check: Prevent player from moving into walls
	# Simply zero velocity when hitting a wall - no position adjustments to avoid jitter
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var normal = collision.get_normal()
			
			# If we're pushing against a wall horizontally, stop horizontal movement
			if abs(normal.x) > 0.7:  # Mostly horizontal collision
				if (normal.x > 0 and input_dir < 0) or (normal.x < 0 and input_dir > 0):
					# We're pushing into a wall, stop movement
					velocity.x = 0
					# Don't push back - move_and_slide() already handles positioning correctly
	
	# Verify and fix collision shape positioning to prevent clipping into ground
	verify_collision_positioning()
	
	# Snap positions to pixel grid for pixel-perfect rendering
	# Only snap if we're not against a wall to avoid jitter
	var is_against_wall = false
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var normal = collision.get_normal()
			if abs(normal.x) > 0.7:  # Horizontal wall
				is_against_wall = true
				break
	
	if not is_against_wall:
		# Not against a wall, safe to snap
		var snapped_pos = global_position.round()
		if check_can_fit(snapped_pos):
			global_position = snapped_pos
		else:
			# Snapping would cause overlap, don't snap (keep current position)
			pass
	else:
		# Against a wall - don't snap to avoid jitter, just round current position
		global_position = global_position.round()
	
	# Handle interaction
	update_nearest_interactable()
	if Input.is_action_just_pressed("ui_select") or e_just_pressed:
		if nearest_interactable and nearest_interactable.has_method("interact"):
			print("Player: Interacting with: ", nearest_interactable.name)
			nearest_interactable.interact(self)
	
	# Update charge drain
	charge_drain_timer += delta
	if charge_drain_timer >= 1.0:
		GameState.charge = max(0.0, GameState.charge - CHARGE_DRAIN_RATE)
		charge_drain_timer = 0.0
	
	# Update key state tracking
	space_pressed_last_frame = space_pressed
	e_pressed_last_frame = e_pressed

## Called when interactable enters interaction area
func _on_interaction_area_body_entered(body: Node2D):
	# Check if this is an interactable (has the interactable group or can_interact method)
	# body can be Area2D (interactables) or CharacterBody2D (player body itself)
	if body == self or body == interaction_area:
		return
	
	if body.is_in_group("interactable") or body.has_method("can_interact"):
		if not overlapping_interactables.has(body):
			overlapping_interactables.append(body)
			print("Player: Detected interactable: ", body.name)

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

## Get speed multiplier for slopes (subtle speed reduction when ascending, slight boost when descending)
func get_slope_speed_multiplier(slope_angle: float, is_uphill: bool) -> float:
	if not is_uphill:
		# Descending: slight speed boost (gravity assists) - very subtle
		return 1.0 + (slope_angle / deg_to_rad(45.0)) * 0.05  # Up to 5% faster
	else:
		# Ascending: slight speed reduction (climbing takes effort) - subtle
		return 1.0 - (slope_angle / deg_to_rad(45.0)) * 0.15  # Up to 15% slower

## Check if a step can be climbed - validates step height, clearance, and reachability
## Returns dictionary with: {can_climb: bool, step_top_y: float, step_height: float}
func can_climb_step(input_dir: float) -> Dictionary:
	var result = {
		"can_climb": false,
		"step_top_y": 0.0,
		"step_height": 0.0
	}
	
	# Must have input direction
	if input_dir == 0.0:
		return result
	
	# Must be on floor
	if not is_on_floor():
		return result
	
	# Get player's collision shape
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return result
	
	var shape = collision_shape.shape as RectangleShape2D
	var player_bottom = global_position.y + shape.size.y / 2.0  # Bottom of player (feet)
	var player_height = shape.size.y
	var player_width = shape.size.x
	
	# Step detection parameters
	var step_check_distance = 24.0  # Check ahead for steps
	var step_check_height = 4.0  # Maximum step height (1 tile = 4 pixels)
	var min_step_height = 0.3  # Minimum step height to climb
	
	var space_state = get_world_2d().direct_space_state
	var best_step = null
	var best_step_height = INF
	var best_step_top_y = 0.0
	
	# Use multiple raycasts at different heights for reliable detection
	var ray_offsets = [0.0, -0.5, -1.0, -1.5, -2.0]
	
	for offset in ray_offsets:
		var ray_start = Vector2(
			global_position.x + input_dir * (player_width / 2.0 + 0.5),
			player_bottom + offset
		)
		var ray_end = ray_start + Vector2(input_dir * step_check_distance, -step_check_height)
		
		var query = PhysicsRayQueryParameters2D.new()
		query.from = ray_start
		query.to = ray_end
		query.collision_mask = 1
		var step_result = space_state.intersect_ray(query)
		
		if step_result:
			var step_height = ray_start.y - step_result.position.y
			if step_height >= min_step_height and step_height <= step_check_height:
				if step_height < best_step_height:
					best_step = step_result
					best_step_height = step_height
					best_step_top_y = step_result.position.y
	
	# Fallback detection: check if player would be blocked
	if best_step == null or best_step_height > 2.0:
		var test_distance = 8.0
		var test_start = Vector2(
			global_position.x + input_dir * (player_width / 2.0 + test_distance),
			player_bottom
		)
		var test_end = test_start + Vector2(0, -step_check_height)
		
		var test_query = PhysicsRayQueryParameters2D.new()
		test_query.from = test_start
		test_query.to = test_end
		test_query.collision_mask = 1
		var test_result = space_state.intersect_ray(test_query)
		
		if test_result:
			var test_step_height = test_start.y - test_result.position.y
			if test_step_height >= min_step_height and test_step_height <= step_check_height:
				if best_step == null or test_step_height < best_step_height:
					best_step = test_result
					best_step_height = test_step_height
					best_step_top_y = test_result.position.y
	
	# If we found a step, validate it can be climbed
	if best_step:
		# Calculate target y position for player center
		var step_top_y = best_step_top_y
		var target_y = step_top_y - player_height / 2.0  # Player center should be at step top - half height
		var current_y = global_position.y
		
		# Only climb if step is above current position (ascending)
		if target_y < current_y:
			var climb_distance = current_y - target_y
			
			# Verify step is actually climbable (not too high)
			if climb_distance <= step_check_height:
				# Check clearance above step - ensure player can fit
				var clearance_check_y = step_top_y - player_height - 1.0  # Check 1px above player top
				var clearance_start = Vector2(
					global_position.x + input_dir * (player_width / 2.0 + 4.0),
					clearance_check_y
				)
				var clearance_end = clearance_start + Vector2(input_dir * 8.0, 0)
				
				var clearance_query = PhysicsRayQueryParameters2D.new()
				clearance_query.from = clearance_start
				clearance_query.to = clearance_end
				clearance_query.collision_mask = 1
				var clearance_result = space_state.intersect_ray(clearance_query)
				
				# If no ceiling blocking, we can climb
				if not clearance_result:
					result.can_climb = true
					result.step_top_y = target_y
					result.step_height = best_step_height
	
	return result

## Validate spawn position - ensure player collision shape is not in walls
func validate_spawn_position():
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	var space_state = get_world_2d().direct_space_state
	
	# Check multiple points around player collision shape
	var check_points = [
		Vector2(-shape.size.x / 2.0, -shape.size.y / 2.0),  # Top left
		Vector2(shape.size.x / 2.0, -shape.size.y / 2.0),  # Top right
		Vector2(-shape.size.x / 2.0, shape.size.y / 2.0),   # Bottom left
		Vector2(shape.size.x / 2.0, shape.size.y / 2.0),   # Bottom right
		Vector2(0, 0),  # Center
	]
	
	var has_collision = false
	for point_offset in check_points:
		var check_pos = global_position + point_offset
		var query = PhysicsPointQueryParameters2D.new()
		query.position = check_pos
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		if results.size() > 0:
			has_collision = true
			break
	
	# If collision detected, try to find a safe position nearby
	if has_collision:
		print("Player: Spawn position has collision, attempting to find safe position...")
		var safe_pos = find_nearby_safe_position()
		if safe_pos:
			global_position = safe_pos
			print("Player: Moved to safe position: ", safe_pos)
		else:
			print("Player: WARNING - Could not find safe spawn position, may clip into walls")

## Find a nearby safe position that doesn't have collisions
func find_nearby_safe_position() -> Vector2:
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return global_position
	
	var shape = collision_shape.shape as RectangleShape2D
	var space_state = get_world_2d().direct_space_state
	var search_radius = 50.0  # Search within 50 pixels
	var search_steps = 8  # Check 8 directions
	
	# Try positions in a spiral pattern
	for radius in range(5, int(search_radius), 5):
		for step in range(search_steps):
			var angle = (step * 2.0 * PI) / search_steps
			var test_pos = global_position + Vector2(cos(angle), sin(angle)) * radius
			
			# Check if this position is safe
			var query = PhysicsPointQueryParameters2D.new()
			query.position = test_pos
			query.collision_mask = 1
			query.collide_with_areas = false
			query.collide_with_bodies = true
			
			var results = space_state.intersect_point(query)
			if results.size() == 0:
				# This position seems safe, verify with shape test
				var shape_query = PhysicsShapeQueryParameters2D.new()
				shape_query.shape = shape
				shape_query.transform.origin = test_pos
				shape_query.collision_mask = 1
				shape_query.collide_with_areas = false
				shape_query.collide_with_bodies = true
				
				var shape_results = space_state.intersect_shape(shape_query)
				if shape_results.size() == 0:
					return test_pos
	
	# If no safe position found, try moving down (player should spawn on floor)
	var down_test = global_position + Vector2(0, 20)
	var down_query = PhysicsPointQueryParameters2D.new()
	down_query.position = down_test
	down_query.collision_mask = 1
	down_query.collide_with_areas = false
	down_query.collide_with_bodies = true
	
	var down_results = space_state.intersect_point(down_query)
	if down_results.size() == 0:
		return down_test
	
	return global_position  # Fallback: return original position

## Check if player's entire hitbox can fit at a given position without overlapping tiles
## Returns true if the position is safe (no overlap), false if it would overlap
func check_can_fit(test_position: Vector2) -> bool:
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return true  # No collision shape, assume safe
	
	var shape = collision_shape.shape as RectangleShape2D
	var space_state = get_world_2d().direct_space_state
	
	# Create shape query to check if player's entire hitbox would overlap anything
	var shape_query = PhysicsShapeQueryParameters2D.new()
	shape_query.shape = shape
	shape_query.transform.origin = test_position
	shape_query.collision_mask = 1
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true
	
	# Check if there are any collisions at this position
	var results = space_state.intersect_shape(shape_query, 1)
	
	# If no collisions, player can fit
	return results.size() == 0

## Verify and fix collision shape positioning to prevent clipping into ground
## Uses pixel-by-pixel approach like Python resolve_vertical_collisions
## Ensures player bottom edge is exactly at floor level, never inside it
func verify_collision_positioning():
	if not is_on_floor():
		return
	
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	var space_state = get_world_2d().direct_space_state
	var player_bottom = global_position.y + shape.size.y / 2.0
	
	# Like Python: check multiple points along player's bottom edge
	# Find the highest floor point (closest to player)
	var check_points = [
		Vector2(global_position.x, player_bottom),  # Center
		Vector2(global_position.x - shape.size.x / 3.0, player_bottom),  # Left third
		Vector2(global_position.x + shape.size.x / 3.0, player_bottom),  # Right third
	]
	
	var highest_floor_y = -INF
	
	# Cast rays downward from each check point to find floor (like Python collides_at)
	for check_point in check_points:
		var floor_ray = PhysicsRayQueryParameters2D.new()
		floor_ray.from = check_point
		floor_ray.to = check_point + Vector2(0, 10.0)  # Check 10px below
		floor_ray.collision_mask = 1
		var result = space_state.intersect_ray(floor_ray)
		
		if result:
			var floor_y = result.position.y
			# Keep track of highest floor (closest to player, like Python stops at first collision)
			if floor_y > highest_floor_y:
				highest_floor_y = floor_y
	
	# If we found a floor, position player so bottom edge is exactly at floor level
	# This matches Python: stop exactly at collision, never inside
	if highest_floor_y != -INF:
		var current_bottom = player_bottom
		
		# If player's bottom is below the floor (clipping), push up pixel by pixel
		# until we find a position where the entire hitbox fits without overlap
		if current_bottom > highest_floor_y:
			# Start from the floor level and move up until we find a safe position
			var target_y = highest_floor_y - shape.size.y / 2.0
			
			# Check if this position fits without overlap
			var test_pos = Vector2(global_position.x, target_y)
			if check_can_fit(test_pos):
				# Safe position found, use it
				global_position.y = target_y
			else:
				# Position would overlap, try moving up pixel by pixel
				var safe_y = target_y
				var found_safe = false
				
				# Try positions above the floor until we find one that fits
				for offset in range(1, int(shape.size.y) + 1):
					var test_y = target_y - offset
					var test_position = Vector2(global_position.x, test_y)
					if check_can_fit(test_position):
						safe_y = test_y
						found_safe = true
						break
				
				if found_safe:
					global_position.y = safe_y
				else:
					# Fallback: use floor level anyway (shouldn't happen, but safety)
					global_position.y = target_y
			
			# Verify we're now on floor (should be true after adjustment)
			# Small correction move to ensure physics system recognizes floor contact
			var test_velocity = Vector2(0, 1)  # Tiny downward movement
			move_and_slide()

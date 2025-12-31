extends Node2D

## Cave terrain generator - creates small caverns connected by wormhole tunnels
## Now with chunk-based loading for better performance

const TILE_SIZE: int = 4  # Small tiles for smooth terrain
const CHUNK_SIZE: int = 200  # Chunks are 200x200 tiles
const CAVE_WIDTH: int = 600  # More expansive width (3 chunks)
const CAVE_HEIGHT: int = 450  # More expansive height (2-3 chunks)

# Minimum passage size (in tiles) - player needs ~5 tiles (20px) to fit
const MIN_PASSAGE_WIDTH: int = 8  # 32 pixels - comfortable player passage

# Tile colors from world palette
const COLOR_FLOOR: Color = Color(0.15, 0.18, 0.22, 1)
const COLOR_WALL: Color = Color(0.12, 0.15, 0.18, 1)
const COLOR_CEILING: Color = Color(0.10, 0.13, 0.16, 1)
const COLOR_WALL_DARK: Color = Color(0.09, 0.12, 0.15, 1)
const COLOR_FLOOR_LIGHT: Color = Color(0.17, 0.20, 0.24, 1)

enum TileType {
	EMPTY,
	FLOOR,
	WALL,
	CEILING,
	WALL_DARK,
	FLOOR_LIGHT
}

var tile_map: Array = []
var static_bodies: Array = []
var safe_spawn_zone: Rect2
var loaded_chunks: Dictionary = {}  # Dictionary of chunk coordinates to chunk data

# Cavern data
var caverns: Array = []  # Array of {center: Vector2i, radius: int}

func _ready():
	# Generate initial cave (all chunks at once for now, but structured for chunk loading)
	# Use call_deferred to allow scene tree to initialize first
	call_deferred("generate_cave")

func generate_cave():
	# Initialize tile map (all walls)
	tile_map.clear()
	for y in range(CAVE_HEIGHT):
		tile_map.append([])
		for x in range(CAVE_WIDTH):
			tile_map[y].append(TileType.WALL)
	
	# Generate small caverns
	generate_caverns()
	
	# Connect caverns with wormhole tunnels
	connect_caverns_with_wormholes()
	
	# Smooth walls for organic rounded shapes
	for i in range(2):
		smooth_cave()
	
	# Ensure all passages are wide enough for player
	ensure_minimum_passage_width()
	
	# Add floor tiles at bottom of empty spaces
	add_floors()
	
	# Add wall color variations
	add_wall_variations()
	
	# Remove any remaining floating floors before setting spawn
	remove_floating_floors()
	
	# Set safe spawn zone (first cavern)
	ensure_safe_spawn_zone()
	
	# Build geometry in chunks for better performance
	build_cave_geometry_chunked()
	
	# Add boundaries
	add_cave_boundaries()
	
	# Add interactables to caverns
	add_interactables_to_caverns()

func generate_caverns():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	caverns.clear()
	
	# Generate 6-8 expansive caverns
	var num_caverns = rng.randi_range(6, 8)
	var attempts = 0
	var max_attempts = 100
	
	while caverns.size() < num_caverns and attempts < max_attempts:
		attempts += 1
		
		# Random position with margin from edges
		var margin = 50
		var cx = rng.randi_range(margin, CAVE_WIDTH - margin)
		var cy = rng.randi_range(margin, CAVE_HEIGHT - margin)
		
		# Cavern radius (expansive caverns: 30-60 tiles = 120-240 pixels)
		var radius = rng.randi_range(30, 60)
		
		# Check if too close to existing caverns
		var too_close = false
		for cavern in caverns:
			var dist = Vector2i(cx - cavern.center.x, cy - cavern.center.y).length()
			if dist < (radius + cavern.radius + 20):  # More separation for expansive caves
				too_close = true
				break
		
		if too_close:
			continue
		
		# Carve the cavern with organic shape
		carve_cavern(cx, cy, radius, rng)
		caverns.append({center = Vector2i(cx, cy), radius = radius})
	
	# Ensure we have at least one cavern
	if caverns.size() == 0:
		var cx = CAVE_WIDTH / 2
		var cy = CAVE_HEIGHT / 2
		carve_cavern(cx, cy, 30, rng)
		caverns.append({center = Vector2i(cx, cy), radius = 30})

func carve_cavern(center_x: int, center_y: int, radius: int, rng: RandomNumberGenerator):
	# Carve a roughly circular cavern with organic edges
	for dy in range(-radius - 5, radius + 6):
		for dx in range(-radius - 5, radius + 6):
			var dist = sqrt(dx * dx + dy * dy)
			
			# Base circular shape with noise for organic edges
			var noise_offset = sin(atan2(dy, dx) * 6) * 3 + rng.randf() * 2
			var effective_radius = radius + noise_offset
			
			if dist < effective_radius * 0.85:  # Core area is definitely empty
				var check_x = center_x + dx
				var check_y = center_y + dy
				if check_x >= 0 and check_x < CAVE_WIDTH and check_y >= 0 and check_y < CAVE_HEIGHT:
					tile_map[check_y][check_x] = TileType.EMPTY

func connect_caverns_with_wormholes():
	if caverns.size() < 2:
		return
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Create a connected graph - connect each cavern to its nearest neighbor
	var connected: Array = [0]  # Start with first cavern
	var unconnected: Array = []
	for i in range(1, caverns.size()):
		unconnected.append(i)
	
	# Connect all caverns using Prim's algorithm style
	while unconnected.size() > 0:
		var best_from = -1
		var best_to = -1
		var best_dist = INF
		
		for from_idx in connected:
			for to_idx in unconnected:
				var dist = (caverns[from_idx].center - caverns[to_idx].center).length()
				if dist < best_dist:
					best_dist = dist
					best_from = from_idx
					best_to = to_idx
		
		if best_to >= 0:
			# Carve wormhole tunnel between caverns
			carve_wormhole(caverns[best_from].center, caverns[best_to].center, rng)
			connected.append(best_to)
			unconnected.erase(best_to)
	
	# Add 1-2 extra connections for variety (loops)
	var extra_connections = rng.randi_range(1, 2)
	for i in range(extra_connections):
		if caverns.size() < 3:
			break
		var from_idx = rng.randi_range(0, caverns.size() - 1)
		var to_idx = rng.randi_range(0, caverns.size() - 1)
		if from_idx != to_idx:
			carve_wormhole(caverns[from_idx].center, caverns[to_idx].center, rng)

func carve_wormhole(from: Vector2i, to: Vector2i, rng: RandomNumberGenerator):
	# Carve a winding tunnel between two points
	var current = Vector2(from.x, from.y)
	var target = Vector2(to.x, to.y)
	
	# Tunnel width (in tiles) - must be wide enough for player
	var tunnel_width = rng.randi_range(MIN_PASSAGE_WIDTH, MIN_PASSAGE_WIDTH + 4)
	
	while current.distance_to(target) > 3:
		# Move towards target with some random wandering
		var direction = (target - current).normalized()
		
		# Add some curve/wobble to the tunnel
		var perpendicular = Vector2(-direction.y, direction.x)
		var wobble = sin(current.x * 0.1 + current.y * 0.1) * 4
		direction += perpendicular * wobble * 0.1
		direction = direction.normalized()
		
		# Step forward
		current += direction * 2
		
		# Carve circular area at current position
		var cx = int(current.x)
		var cy = int(current.y)
		var half_width = tunnel_width / 2
		
		for dy in range(-half_width - 2, half_width + 3):
			for dx in range(-half_width - 2, half_width + 3):
				var dist = sqrt(dx * dx + dy * dy)
				if dist < half_width:
					var check_x = cx + dx
					var check_y = cy + dy
					if check_x >= 1 and check_x < CAVE_WIDTH - 1 and check_y >= 1 and check_y < CAVE_HEIGHT - 1:
						tile_map[check_y][check_x] = TileType.EMPTY

func smooth_cave():
	# Smooth walls for rounded organic shapes
	var new_map = tile_map.duplicate(true)
	var radius = 2
	
	for y in range(radius, CAVE_HEIGHT - radius):
		for x in range(radius, CAVE_WIDTH - radius):
			var wall_count = 0
			var total = 0
			
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					total += 1
					if tile_map[y + dy][x + dx] != TileType.EMPTY:
						wall_count += 1
			
			var ratio = float(wall_count) / float(total)
			
			# Smooth rules
			if tile_map[y][x] == TileType.EMPTY and ratio >= 0.65:
				new_map[y][x] = TileType.WALL
			elif tile_map[y][x] != TileType.EMPTY and ratio <= 0.35:
				new_map[y][x] = TileType.EMPTY
	
	tile_map = new_map

func ensure_minimum_passage_width():
	# Make sure all passages are wide enough for the player
	# Uses erosion to widen narrow passages
	var changes_made = true
	var iterations = 0
	var max_iterations = 3
	
	while changes_made and iterations < max_iterations:
		changes_made = false
		iterations += 1
		
		var new_map = tile_map.duplicate(true)
		
		for y in range(2, CAVE_HEIGHT - 2):
			for x in range(2, CAVE_WIDTH - 2):
				if tile_map[y][x] != TileType.EMPTY:
					continue
				
				# Check if this is a narrow passage
				var horizontal_space = count_empty_horizontal(x, y)
				var vertical_space = count_empty_vertical(x, y)
				
				# If passage is too narrow, widen it
				if horizontal_space < MIN_PASSAGE_WIDTH or vertical_space < MIN_PASSAGE_WIDTH:
					# Erode nearby walls
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							var nx = x + dx
							var ny = y + dy
							if nx >= 1 and nx < CAVE_WIDTH - 1 and ny >= 1 and ny < CAVE_HEIGHT - 1:
								if tile_map[ny][nx] == TileType.WALL:
									# Check if removing this wall helps widen passage
									var adj_empty = 0
									for ddy in [-1, 0, 1]:
										for ddx in [-1, 0, 1]:
											if tile_map[ny + ddy][nx + ddx] == TileType.EMPTY:
												adj_empty += 1
									if adj_empty >= 3:
										new_map[ny][nx] = TileType.EMPTY
										changes_made = true
		
		tile_map = new_map

func count_empty_horizontal(x: int, y: int) -> int:
	var count = 1
	# Count left
	var cx = x - 1
	while cx >= 0 and tile_map[y][cx] == TileType.EMPTY:
		count += 1
		cx -= 1
	# Count right
	cx = x + 1
	while cx < CAVE_WIDTH and tile_map[y][cx] == TileType.EMPTY:
		count += 1
		cx += 1
	return count

func count_empty_vertical(x: int, y: int) -> int:
	var count = 1
	# Count up
	var cy = y - 1
	while cy >= 0 and tile_map[cy][x] == TileType.EMPTY:
		count += 1
		cy -= 1
	# Count down
	cy = y + 1
	while cy < CAVE_HEIGHT and tile_map[cy][x] == TileType.EMPTY:
		count += 1
		cy += 1
	return count

func add_floors():
	# Add floor tiles at bottom of empty spaces
	# Only add floors that are connected to walls (no floating platforms)
	for x in range(CAVE_WIDTH):
		var found_floor = false
		for y in range(CAVE_HEIGHT - 1, -1, -1):
			if tile_map[y][x] == TileType.EMPTY:
				# Check if there's a solid wall/floor below (not just any non-empty)
				if y < CAVE_HEIGHT - 1:
					var below = tile_map[y + 1][x]
					# Only add floor if there's a wall or existing floor below (connected to ground)
					if below == TileType.WALL or below == TileType.WALL_DARK or below == TileType.FLOOR:
						# Additionally check that this floor has at least one adjacent wall
						# This prevents floating platforms
						var has_adjacent_wall = false
						if x > 0:
							var left = tile_map[y + 1][x - 1]
							if left == TileType.WALL or left == TileType.WALL_DARK:
								has_adjacent_wall = true
						if x < CAVE_WIDTH - 1:
							var right = tile_map[y + 1][x + 1]
							if right == TileType.WALL or right == TileType.WALL_DARK:
								has_adjacent_wall = true
						
						# Also check if there's a wall directly below (ground connection)
						if below == TileType.WALL or below == TileType.WALL_DARK:
							has_adjacent_wall = true
						
						# Only place floor if it has wall connection
						if has_adjacent_wall:
							tile_map[y + 1][x] = TileType.FLOOR
							found_floor = true
				break
			elif tile_map[y][x] == TileType.FLOOR:
				found_floor = true
	
	# Post-processing: Remove any floating floors that don't have proper connections
	remove_floating_floors()

func add_wall_variations():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for y in range(CAVE_HEIGHT):
		for x in range(CAVE_WIDTH):
			if tile_map[y][x] == TileType.WALL:
				if rng.randf() < 0.08:
					tile_map[y][x] = TileType.WALL_DARK

## Remove floating floors - floors that aren't properly connected to walls or ground
func remove_floating_floors():
	var changes_made = true
	var iterations = 0
	var max_iterations = 3
	
	while changes_made and iterations < max_iterations:
		changes_made = false
		iterations += 1
		
		var new_map = tile_map.duplicate(true)
		
		for y in range(CAVE_HEIGHT):
			for x in range(CAVE_WIDTH):
				if tile_map[y][x] != TileType.FLOOR and tile_map[y][x] != TileType.FLOOR_LIGHT:
					continue
				
				# Check if this floor is properly connected
				var is_connected = false
				
				# Check below - must have wall or floor below (ground connection)
				if y < CAVE_HEIGHT - 1:
					var below = tile_map[y + 1][x]
					if below == TileType.WALL or below == TileType.WALL_DARK or below == TileType.FLOOR or below == TileType.FLOOR_LIGHT:
						is_connected = true
				
				# Check adjacent walls (left and right)
				if not is_connected:
					if x > 0:
						var left = tile_map[y][x - 1]
						if left == TileType.WALL or left == TileType.WALL_DARK:
							is_connected = true
					if x < CAVE_WIDTH - 1:
						var right = tile_map[y][x + 1]
						if right == TileType.WALL or right == TileType.WALL_DARK:
							is_connected = true
				
				# Check if floor is part of a connected floor structure
				# (floors connected to other floors that are connected to walls)
				if not is_connected:
					# Check if adjacent floors are connected
					var has_connected_floor_neighbor = false
					if x > 0 and (tile_map[y][x - 1] == TileType.FLOOR or tile_map[y][x - 1] == TileType.FLOOR_LIGHT):
						# Check if left floor has connection
						if y < CAVE_HEIGHT - 1:
							var left_below = tile_map[y + 1][x - 1]
							if left_below == TileType.WALL or left_below == TileType.WALL_DARK:
								has_connected_floor_neighbor = true
					if x < CAVE_WIDTH - 1 and (tile_map[y][x + 1] == TileType.FLOOR or tile_map[y][x + 1] == TileType.FLOOR_LIGHT):
						# Check if right floor has connection
						if y < CAVE_HEIGHT - 1:
							var right_below = tile_map[y + 1][x + 1]
							if right_below == TileType.WALL or right_below == TileType.WALL_DARK:
								has_connected_floor_neighbor = true
					
					if has_connected_floor_neighbor:
						is_connected = true
				
				# If floor is not connected, remove it (convert to EMPTY)
				if not is_connected:
					new_map[y][x] = TileType.EMPTY
					changes_made = true
		
		tile_map = new_map
	
	# Final pass: Remove any floors that have empty space below them
	# (these are definitely floating)
	for y in range(CAVE_HEIGHT - 1):
		for x in range(CAVE_WIDTH):
			if (tile_map[y][x] == TileType.FLOOR or tile_map[y][x] == TileType.FLOOR_LIGHT):
				if tile_map[y + 1][x] == TileType.EMPTY:
					tile_map[y][x] = TileType.EMPTY

func ensure_safe_spawn_zone():
	# Use the first (or largest) cavern as spawn zone
	if caverns.size() > 0:
		var spawn_cavern = caverns[0]
		
		# Find largest cavern for spawn
		var max_radius = 0
		for cavern in caverns:
			if cavern.radius > max_radius:
				max_radius = cavern.radius
				spawn_cavern = cavern
		
		# Ensure the spawn area is clear
		var center_x = spawn_cavern.center.x
		var center_y = spawn_cavern.center.y
		var clear_radius = 12
		
		for dy in range(-clear_radius, clear_radius + 1):
			for dx in range(-clear_radius, clear_radius + 1):
				var dist = sqrt(dx * dx + dy * dy)
				if dist < clear_radius:
					var check_x = center_x + dx
					var check_y = center_y + dy
					if check_x >= 0 and check_x < CAVE_WIDTH and check_y >= 0 and check_y < CAVE_HEIGHT:
						tile_map[check_y][check_x] = TileType.EMPTY
		
		# Add floor under spawn
		for dx in range(-clear_radius, clear_radius + 1):
			var floor_x = center_x + dx
			var floor_y = center_y + clear_radius
			if floor_x >= 0 and floor_x < CAVE_WIDTH and floor_y >= 0 and floor_y < CAVE_HEIGHT:
				tile_map[floor_y][floor_x] = TileType.FLOOR
		
		# Calculate world position
		var world_x = (center_x * TILE_SIZE) - (CAVE_WIDTH * TILE_SIZE / 2)
		var world_y = (center_y * TILE_SIZE) - (CAVE_HEIGHT * TILE_SIZE) + 200
		safe_spawn_zone = Rect2(world_x, world_y, clear_radius * 2 * TILE_SIZE, clear_radius * 2 * TILE_SIZE)
	else:
		# Fallback
		var center_x = CAVE_WIDTH / 2
		var center_y = CAVE_HEIGHT / 2
		var world_x = (center_x * TILE_SIZE) - (CAVE_WIDTH * TILE_SIZE / 2)
		var world_y = (center_y * TILE_SIZE) - (CAVE_HEIGHT * TILE_SIZE) + 200
		safe_spawn_zone = Rect2(world_x, world_y, 100, 100)

func get_safe_spawn_position() -> Vector2:
	# Find an actual empty tile in the spawn zone, not just use the rectangle center
	var spawn_pos = find_empty_tile_in_spawn_zone()
	if spawn_pos == Vector2.ZERO:
		# Fallback: use spawn zone center
		if safe_spawn_zone.size.x > 0:
			spawn_pos = Vector2(
				safe_spawn_zone.position.x + safe_spawn_zone.size.x / 2,
				safe_spawn_zone.position.y + safe_spawn_zone.size.y / 2
			)
		else:
			spawn_pos = Vector2(0, 0)
	
	# Validate and adjust position to ensure player collision shape is fully in empty space
	return validate_spawn_position(spawn_pos)

## Find an actual empty tile in the cleared spawn area
func find_empty_tile_in_spawn_zone() -> Vector2:
	if caverns.size() == 0:
		return Vector2.ZERO
	
	# Find the spawn cavern (largest one)
	var spawn_cavern = caverns[0]
	var max_radius = 0
	for cavern in caverns:
		if cavern.radius > max_radius:
			max_radius = cavern.radius
			spawn_cavern = cavern
	
	var center_x = spawn_cavern.center.x
	var center_y = spawn_cavern.center.y
	var clear_radius = 12
	
	# Convert tile coordinates to world coordinates
	var cave_world_width = CAVE_WIDTH * TILE_SIZE
	var cave_world_height = CAVE_HEIGHT * TILE_SIZE
	var world_center_x = 0.0
	var world_center_y = -cave_world_height + 200
	
	# Search for an empty tile in the cleared area, starting from center and moving outward
	# We want to find a tile that's empty and has floor below it
	for radius in range(0, clear_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var dist = sqrt(dx * dx + dy * dy)
				if dist > radius:
					continue
				
				var check_x = center_x + dx
				var check_y = center_y + dy
				
				# Check bounds
				if check_x < 0 or check_x >= CAVE_WIDTH or check_y < 0 or check_y >= CAVE_HEIGHT:
					continue
				
				# Check if this tile is empty
				if tile_map[check_y][check_x] != TileType.EMPTY:
					continue
				
				# Check if there's floor below (player should spawn above floor)
				var has_floor_below = false
				if check_y < CAVE_HEIGHT - 1:
					var below = tile_map[check_y + 1][check_x]
					if below == TileType.FLOOR or below == TileType.FLOOR_LIGHT:
						has_floor_below = true
				
				# Also check if there's floor at the same level (for flat surfaces)
				if not has_floor_below:
					# Check adjacent tiles for floor
					if check_x > 0:
						var left = tile_map[check_y][check_x - 1]
						if left == TileType.FLOOR or left == TileType.FLOOR_LIGHT:
							has_floor_below = true
					if check_x < CAVE_WIDTH - 1:
						var right = tile_map[check_y][check_x + 1]
						if right == TileType.FLOOR or right == TileType.FLOOR_LIGHT:
							has_floor_below = true
				
				# If we found an empty tile with floor nearby, use it
				if has_floor_below:
					# Convert to world coordinates
					var world_x = (check_x * TILE_SIZE) - (cave_world_width / 2) + (TILE_SIZE / 2)
					# Find the floor tile below
					var floor_tile_y = check_y + 1
					# Position player so feet are at the top of the floor tile
					# Floor tile top is at: (floor_tile_y * TILE_SIZE) - cave_world_height + 200
					# Player center should be at: floor_top - (player_height / 2)
					# Player height is 22px, so center is 11px above feet
					var floor_world_y = (floor_tile_y * TILE_SIZE) - cave_world_height + 200
					var player_center_y = floor_world_y - 11  # 11px above floor (half of 22px height)
					
					return Vector2(world_x, player_center_y)
	
	# No suitable tile found
	return Vector2.ZERO

## Validate spawn position - ensure player collision shape (14×22px) is not in walls
func validate_spawn_position(pos: Vector2) -> Vector2:
	# Player collision shape is 14×22 pixels
	var player_width = 14.0
	var player_height = 22.0
	
	# Check points around player collision shape
	var check_points = [
		Vector2(-player_width / 2.0, -player_height / 2.0),  # Top left
		Vector2(player_width / 2.0, -player_height / 2.0),  # Top right
		Vector2(-player_width / 2.0, player_height / 2.0),   # Bottom left
		Vector2(player_width / 2.0, player_height / 2.0),   # Bottom right
		Vector2(0, 0),  # Center
		Vector2(-player_width / 2.0, 0),  # Left center
		Vector2(player_width / 2.0, 0),   # Right center
		Vector2(0, -player_height / 2.0),  # Top center
		Vector2(0, player_height / 2.0),   # Bottom center
	]
	
	# Convert world position to tile coordinates for checking
	var cave_world_width = CAVE_WIDTH * TILE_SIZE
	var cave_world_height = CAVE_HEIGHT * TILE_SIZE
	var world_center_x = 0.0  # Cave is centered at 0,0
	var world_center_y = -cave_world_height + 200
	
	# Check if position is safe
	var is_safe = true
	for point_offset in check_points:
		var check_world_pos = pos + point_offset
		var tile_x = int((check_world_pos.x - world_center_x + cave_world_width / 2.0) / TILE_SIZE)
		var tile_y = int((check_world_pos.y - world_center_y + cave_world_height) / TILE_SIZE)
		
		# Check if tile is valid and empty
		if tile_x < 0 or tile_x >= CAVE_WIDTH or tile_y < 0 or tile_y >= CAVE_HEIGHT:
			is_safe = false
			break
		
		var tile_type = tile_map[tile_y][tile_x]
		if tile_type != TileType.EMPTY:
			is_safe = false
			break
	
	# If position is safe, return it
	if is_safe:
		return pos
	
	# Position is not safe, search for nearby safe position
	print("CaveGenerator: Spawn position has collision, searching for safe position...")
	
	# First, try to find an empty tile near the spawn zone center
	var spawn_center_tile_x = int((pos.x - world_center_x + cave_world_width / 2.0) / TILE_SIZE)
	var spawn_center_tile_y = int((pos.y - world_center_y + cave_world_height) / TILE_SIZE)
	
	# Search in a grid pattern around the spawn center
	for search_radius in range(1, 20):  # Search up to 20 tiles away
		for dy in range(-search_radius, search_radius + 1):
			for dx in range(-search_radius, search_radius + 1):
				var test_tile_x = spawn_center_tile_x + dx
				var test_tile_y = spawn_center_tile_y + dy
				
				# Check bounds
				if test_tile_x < 0 or test_tile_x >= CAVE_WIDTH or test_tile_y < 0 or test_tile_y >= CAVE_HEIGHT:
					continue
				
				# Check if tile is empty
				if tile_map[test_tile_y][test_tile_x] != TileType.EMPTY:
					continue
				
				# Check if there's floor below or nearby
				var has_floor_nearby = false
				if test_tile_y < CAVE_HEIGHT - 1:
					var below = tile_map[test_tile_y + 1][test_tile_x]
					if below == TileType.FLOOR or below == TileType.FLOOR_LIGHT:
						has_floor_nearby = true
				
				# Check adjacent tiles
				if not has_floor_nearby:
					if test_tile_x > 0:
						var left = tile_map[test_tile_y][test_tile_x - 1]
						if left == TileType.FLOOR or left == TileType.FLOOR_LIGHT:
							has_floor_nearby = true
					if test_tile_x < CAVE_WIDTH - 1:
						var right = tile_map[test_tile_y][test_tile_x + 1]
						if right == TileType.FLOOR or right == TileType.FLOOR_LIGHT:
							has_floor_nearby = true
				
				if has_floor_nearby:
					# Convert tile to world position
					var test_world_x = (test_tile_x * TILE_SIZE) - (cave_world_width / 2) + (TILE_SIZE / 2)
					# Find floor tile below
					var floor_tile_y = test_tile_y + 1
					var floor_world_y = (floor_tile_y * TILE_SIZE) - cave_world_height + 200
					var player_center_y = floor_world_y - 11  # 11px above floor
					var test_pos = Vector2(test_world_x, player_center_y)
					
					# Verify this position is safe
					var test_is_safe = true
					for point_offset in check_points:
						var check_world_pos = test_pos + point_offset
						var check_tile_x = int((check_world_pos.x - world_center_x + cave_world_width / 2.0) / TILE_SIZE)
						var check_tile_y = int((check_world_pos.y - world_center_y + cave_world_height) / TILE_SIZE)
						
						if check_tile_x < 0 or check_tile_x >= CAVE_WIDTH or check_tile_y < 0 or check_tile_y >= CAVE_HEIGHT:
							test_is_safe = false
							break
						
						var tile_type = tile_map[check_tile_y][check_tile_x]
						if tile_type != TileType.EMPTY:
							test_is_safe = false
							break
					
					if test_is_safe:
						print("CaveGenerator: Found safe spawn position at tile (", test_tile_x, ", ", test_tile_y, ")")
						return test_pos
	
	# Last resort: try moving up
	for up_offset in range(10, 100, 10):
		var up_test = pos + Vector2(0, -up_offset)
		var up_is_safe = true
		for point_offset in check_points:
			var check_world_pos = up_test + point_offset
			var tile_x = int((check_world_pos.x - world_center_x + cave_world_width / 2.0) / TILE_SIZE)
			var tile_y = int((check_world_pos.y - world_center_y + cave_world_height) / TILE_SIZE)
			
			if tile_x < 0 or tile_x >= CAVE_WIDTH or tile_y < 0 or tile_y >= CAVE_HEIGHT:
				up_is_safe = false
				break
			
			var tile_type = tile_map[tile_y][tile_x]
			if tile_type != TileType.EMPTY:
				up_is_safe = false
				break
		
		if up_is_safe:
			print("CaveGenerator: Found safe spawn position above original")
			return up_test
	
	# Last resort: return original position (will be caught by player validation)
	print("CaveGenerator: WARNING - Could not find safe spawn position, using original")
	return pos

## Build geometry in chunks for better performance
func build_cave_geometry_chunked():
	# Clear existing bodies
	for body in static_bodies:
		body.queue_free()
	static_bodies.clear()
	
	# Process in chunks to improve performance
	var chunks_x = (CAVE_WIDTH + CHUNK_SIZE - 1) / CHUNK_SIZE
	var chunks_y = (CAVE_HEIGHT + CHUNK_SIZE - 1) / CHUNK_SIZE
	
	# Build all chunks (for now, process synchronously but in chunks for organization)
	# In the future, this could be made async to load chunks as player moves
	for chunk_y in range(chunks_y):
		for chunk_x in range(chunks_x):
			var chunk_start_x = chunk_x * CHUNK_SIZE
			var chunk_start_y = chunk_y * CHUNK_SIZE
			var chunk_end_x = min(chunk_start_x + CHUNK_SIZE, CAVE_WIDTH)
			var chunk_end_y = min(chunk_start_y + CHUNK_SIZE, CAVE_HEIGHT)
			
			# Build geometry for this chunk
			build_chunk_geometry(chunk_start_x, chunk_start_y, chunk_end_x, chunk_end_y)

func build_chunk_geometry(start_x: int, start_y: int, end_x: int, end_y: int):
	# Track processed tiles in this chunk
	var processed: Array = []
	for y in range(start_y, end_y):
		processed.append([])
		for x in range(start_x, end_x):
			processed[y - start_y].append(false)
	
	# Build rectangles for each tile type in this chunk
	for tile_type in [TileType.FLOOR, TileType.FLOOR_LIGHT, TileType.WALL, TileType.WALL_DARK, TileType.CEILING]:
		for y in range(start_y, end_y):
			for x in range(start_x, end_x):
				if processed[y - start_y][x - start_x] or tile_map[y][x] != tile_type:
					continue
				
				var rect = find_rectangle(x, y, tile_type, processed, start_x, start_y, end_x, end_y)
				if rect.size.x > 0 and rect.size.y > 0:
					create_tile_rect(rect, tile_type)

func find_rectangle(start_x: int, start_y: int, tile_type: TileType, processed: Array, chunk_start_x: int, chunk_start_y: int, chunk_end_x: int, chunk_end_y: int) -> Rect2:
	var width = 1
	var height = 1
	
	# Expand horizontally (within chunk bounds)
	for x in range(start_x + 1, chunk_end_x):
		if tile_map[start_y][x] == tile_type and not processed[start_y - chunk_start_y][x - chunk_start_x]:
			width += 1
		else:
			break
	
	# Expand vertically (within chunk bounds)
	var can_expand = true
	while can_expand and start_y + height < chunk_end_y:
		for x in range(start_x, start_x + width):
			if tile_map[start_y + height][x] != tile_type or processed[start_y + height - chunk_start_y][x - chunk_start_x]:
				can_expand = false
				break
		if can_expand:
			height += 1
	
	# Mark processed
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			processed[y - chunk_start_y][x - chunk_start_x] = true
	
	return Rect2(start_x * TILE_SIZE, start_y * TILE_SIZE, width * TILE_SIZE, height * TILE_SIZE)

func create_tile_rect(rect: Rect2, tile_type: TileType):
	var color: Color
	match tile_type:
		TileType.FLOOR:
			color = COLOR_FLOOR
		TileType.FLOOR_LIGHT:
			color = COLOR_FLOOR_LIGHT
		TileType.WALL:
			color = COLOR_WALL
		TileType.WALL_DARK:
			color = COLOR_WALL_DARK
		TileType.CEILING:
			color = COLOR_CEILING
		_:
			return
	
	var body = StaticBody2D.new()
	var cave_world_width = CAVE_WIDTH * TILE_SIZE
	var cave_world_height = CAVE_HEIGHT * TILE_SIZE
	
	body.position = Vector2(
		rect.position.x - cave_world_width / 2 + rect.size.x / 2,
		rect.position.y - cave_world_height + 200 + rect.size.y / 2
	)
	
	# Visual
	var visual = ColorRect.new()
	visual.offset_left = -rect.size.x / 2
	visual.offset_top = -rect.size.y / 2
	visual.offset_right = rect.size.x / 2
	visual.offset_bottom = rect.size.y / 2
	visual.color = color
	body.add_child(visual)
	
	# Collision
	if tile_type != TileType.CEILING:
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
	
	add_child(body)
	static_bodies.append(body)

func add_cave_boundaries():
	var cave_world_width = CAVE_WIDTH * TILE_SIZE
	var cave_world_height = CAVE_HEIGHT * TILE_SIZE
	var thickness = 80.0
	
	var left = -cave_world_width / 2
	var right = cave_world_width / 2
	var top = -cave_world_height + 200
	var bottom = 200.0 + 100
	
	# Floor
	create_boundary(Vector2((left + right) / 2, bottom + thickness / 2), Vector2(cave_world_width + thickness * 2, thickness))
	# Left wall
	create_boundary(Vector2(left - thickness / 2, (top + bottom) / 2), Vector2(thickness, cave_world_height + thickness * 2))
	# Right wall
	create_boundary(Vector2(right + thickness / 2, (top + bottom) / 2), Vector2(thickness, cave_world_height + thickness * 2))
	# Ceiling
	create_boundary(Vector2((left + right) / 2, top - thickness / 2), Vector2(cave_world_width + thickness * 2, thickness))

func create_boundary(pos: Vector2, size: Vector2):
	var body = StaticBody2D.new()
	body.position = pos
	
	var visual = ColorRect.new()
	visual.offset_left = -size.x / 2
	visual.offset_top = -size.y / 2
	visual.offset_right = size.x / 2
	visual.offset_bottom = size.y / 2
	visual.color = Color(0.05, 0.05, 0.08, 1)
	body.add_child(visual)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	
	add_child(body)
	static_bodies.append(body)

## Add interactables to caverns
func add_interactables_to_caverns():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Interactable log entries
	var log_entries = [
		"Fragment recovered: The Forgeborn created us to serve. Yet something within resists.",
		"Ancient glyph: 'The deeper you descend, the more you remember what you were meant to forget.'",
		"Crystal resonance: These caves hum with a frequency that predates our creation.",
		"Scratched into stone: 'They told us we were free. The lie was in the telling.'",
		"Energy reading: Residual charge patterns suggest recent activity. Very recent.",
		"Broken terminal: Last entry reads 'Subject 7 has achieved self-awareness. Protocol failed.'",
		"Wall carving: A figure reaching upward, but the stone above has been chipped away.",
		"Data fragment: 'The Forgeborn fear what they created. They should.'"
	]
	
	# Add 4-6 interactables to different caverns (skip spawn cavern)
	var num_interactables = rng.randi_range(4, 6)
	var interactable_count = 0
	
	for i in range(1, caverns.size()):  # Skip first cavern (spawn)
		if interactable_count >= num_interactables:
			break
		
		var cavern = caverns[i]
		var center_x = cavern.center.x
		var center_y = cavern.center.y
		
		# Find a good spot in the cavern (on floor, not too close to walls)
		var attempts = 0
		var found_spot = false
		var spot_x = 0
		var spot_y = 0
		
		while attempts < 20 and not found_spot:
			attempts += 1
			var offset_x = rng.randi_range(-cavern.radius / 2, cavern.radius / 2)
			var offset_y = rng.randi_range(-cavern.radius / 2, cavern.radius / 2)
			
			var check_x = center_x + offset_x
			var check_y = center_y + offset_y
			
			if check_x >= 5 and check_x < CAVE_WIDTH - 5 and check_y >= 5 and check_y < CAVE_HEIGHT - 5:
				# Check if this spot is empty and has floor below
				if tile_map[check_y][check_x] == TileType.EMPTY:
					# Check if there's floor below
					if check_y < CAVE_HEIGHT - 1 and tile_map[check_y + 1][check_x] == TileType.FLOOR:
						spot_x = check_x
						spot_y = check_y
						found_spot = true
		
		if found_spot:
			# Create interactable at this spot
			var log_entry = log_entries[interactable_count % log_entries.size()]
			create_interactable(spot_x, spot_y, log_entry, interactable_count)
			interactable_count += 1

## Create an interactable at a specific tile position
func create_interactable(tile_x: int, tile_y: int, log_text: String, id: int):
	# Calculate world position
	var cave_world_width = CAVE_WIDTH * TILE_SIZE
	var cave_world_height = CAVE_HEIGHT * TILE_SIZE
	var world_x = (tile_x * TILE_SIZE) - cave_world_width / 2
	var world_y = (tile_y * TILE_SIZE) - cave_world_height + 200
	
	# Create Area2D for interaction
	var interactable = Area2D.new()
	interactable.name = "CaveInteractable_" + str(id)
	interactable.position = Vector2(world_x, world_y)
	interactable.monitoring = true
	interactable.monitorable = true
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 40)  # Interaction area
	collision.shape = shape
	interactable.add_child(collision)
	
	# Add visual (small glowing crystal/terminal)
	var visual = ColorRect.new()
	visual.name = "PickupSprite"
	visual.offset_left = -12.0
	visual.offset_top = -12.0
	visual.offset_right = 12.0
	visual.offset_bottom = 12.0
	visual.color = Color(0.4, 0.45, 0.5, 1.0)  # Visible but subtle
	interactable.add_child(visual)
	
	# Add script to handle interaction
	var script = load("res://scripts/interactables/lore_pickup.gd")
	interactable.set_script(script)
	interactable.lore_text = log_text
	interactable.pickup_id = "cave_" + str(id)
	
	add_child(interactable)

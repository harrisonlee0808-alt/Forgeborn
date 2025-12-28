extends Node

## GameState - Tracks player decisions, flags, and persistent game data
## Flags are set automatically based on player actions (no UI prompts)

# Player resources
var health: float = 100.0
var max_health: float = 100.0
var charge: float = 100.0
var max_charge: float = 100.0

# Encounter tracking (pacifism/violence)
var pacifism_count: int = 0
var violence_count: int = 0

# Story flags dictionary
var story_flags: Dictionary = {}

# Areas visited tracking
var areas_visited: Dictionary = {}

# Current biome context
var current_biome: String = "crystal_chasm"

# Log entries for lore/story
var log_entries: Array[String] = []

func _ready():
	# Initialize with default values
	pass

## Set a story flag with a value
func set_flag(key: String, value):
	story_flags[key] = value
	print("GameState: Set flag '", key, "' = ", value)

## Get a story flag value (returns null if not set)
func get_flag(key: String):
	return story_flags.get(key, null)

## Check if a flag is set
func has_flag(key: String) -> bool:
	return story_flags.has(key)

## Increment pacifism counter (called when player avoids violence)
func increment_pacifism():
	pacifism_count += 1
	print("GameState: Pacifism count: ", pacifism_count)

## Increment violence counter (called when player engages in combat)
func increment_violence():
	violence_count += 1
	print("GameState: Violence count: ", violence_count)

## Mark an area as visited
func visit_area(area_id: String):
	if not areas_visited.has(area_id):
		areas_visited[area_id] = true
		print("GameState: Visited area: ", area_id)

## Set current biome
func set_biome(biome_name: String):
	current_biome = biome_name
	AudioManager.change_biome(biome_name)

## Save game state (stubbed for now)
func save_game() -> Dictionary:
	var save_data = {
		"health": health,
		"charge": charge,
		"pacifism_count": pacifism_count,
		"violence_count": violence_count,
		"story_flags": story_flags,
		"areas_visited": areas_visited,
		"current_biome": current_biome,
		"log_entries": log_entries
	}
	return save_data

## Add entry to log
func add_log_entry(text: String):
	log_entries.append(text)
	print("Log: ", text)

## Get all log entries
func get_log_entries() -> Array[String]:
	return log_entries

## Load game state (stubbed for now)
func load_game(save_data: Dictionary):
	health = save_data.get("health", 100.0)
	charge = save_data.get("charge", 100.0)
	pacifism_count = save_data.get("pacifism_count", 0)
	violence_count = save_data.get("violence_count", 0)
	story_flags = save_data.get("story_flags", {})
	areas_visited = save_data.get("areas_visited", {})
	current_biome = save_data.get("current_biome", "crystal_chasm")
	log_entries = save_data.get("log_entries", [])


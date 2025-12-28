extends Area2D

## Trigger Zone - automatically sets flags and triggers consequences when entered
## No interaction needed, just walking into it

@export var flag_key: String = ""
@export var flag_value = true
@export var area_id: String = ""
@export var consequence_type: String = "none"  # "audio_fade", "light_change", "hud_flicker", "sound_cue"
@export var consequence_value: String = ""

var triggered: bool = false

func _ready():
	# Connect body entered signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Check if already triggered
	if area_id != "":
		if GameState.areas_visited.has(area_id):
			triggered = true
			monitoring = false

func _on_body_entered(body: Node2D):
	if body.name == "Player" or body.is_in_group("player"):
		if not triggered:
			trigger()

func trigger():
	if triggered:
		return
	
	triggered = true
	
	# Set flag if specified
	if flag_key != "":
		GameState.set_flag(flag_key, flag_value)
	
	# Mark area as visited if specified
	if area_id != "":
		GameState.visit_area(area_id)
	
	# Trigger consequence
	trigger_consequence()
	
	# Disable monitoring so it only fires once
	monitoring = false

func trigger_consequence():
	match consequence_type:
		"audio_fade":
			# Fade out a layer
			if consequence_value != "":
				AudioManager.fade_out_layer(consequence_value, 2.0)
		"light_change":
			# Change player light radius
			var player_light = get_tree().get_first_node_in_group("player_light")
			if player_light:
				var tween = create_tween()
				var current_energy = player_light.energy
				var new_energy = current_energy * (1.2 if consequence_value == "increase" else 0.8)
				tween.tween_property(player_light, "energy", new_energy, 1.0)
		"hud_flicker":
			# Flicker HUD
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("flicker"):
				hud.flicker(1.0)
		"sound_cue":
			# Play a distant sound (would need additional AudioStreamPlayer)
			pass  # Stubbed for future implementation


extends Area2D

## Area trigger - automatically sets flags when player enters
## No UI prompts, just silent flag setting

@export var flag_key: String = ""
@export var flag_value = true
@export var area_id: String = ""

func _ready():
	# Connect body entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	# Check if it's the player
	if body.name == "Player" or body.is_in_group("player"):
		# Set flag if specified
		if flag_key != "":
			GameState.set_flag(flag_key, flag_value)
		
		# Mark area as visited if specified
		if area_id != "":
			GameState.visit_area(area_id)
		
		# Disable trigger so it only fires once
		monitoring = false


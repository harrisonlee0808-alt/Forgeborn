extends InteractableBase

## Lore pickup - adds one log line and sets a flag when interacted

@export var lore_text: String = "Fragment recovered: The Forgeborn created us to serve. Yet something within resists."
@export var pickup_id: String = "lore_01"

var collected: bool = false

func _ready():
	super._ready()
	
	# Check if already collected
	if pickup_id != "":
		var flag_key = "collected_" + pickup_id
		if GameState.has_flag(flag_key):
		collected = true
		can_be_interacted = false
		# Visual: already collected (slightly brighter)
		var pickup_sprite_node = get_node_or_null("PickupSprite")
		if pickup_sprite_node and pickup_sprite_node is ColorRect:
			pickup_sprite_node.color = Color(0.35, 0.38, 0.42, 1)

func can_interact() -> bool:
	return super.can_interact() and not collected

func interact(player: Node2D):
	if collected:
		return
	
	collected = true
	can_be_interacted = false
	
	# Set flag
	var flag_key = "collected_" + pickup_id
	GameState.set_flag(flag_key, true)
	
	# Add to log
	GameState.add_log_entry(lore_text)
	
	# Update HUD log display
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_log_display"):
		hud.update_log_display()
	
	# Visual feedback - make pickup slightly brighter
	var pickup_sprite = get_node_or_null("PickupSprite")
	if pickup_sprite and pickup_sprite is ColorRect:
		pickup_sprite.color = Color(0.35, 0.38, 0.42, 1)
	
	# Disable monitoring
	monitoring = false


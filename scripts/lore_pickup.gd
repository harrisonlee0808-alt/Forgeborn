extends Area2D

## Lore pickup - silent terminal/ruin object that logs text to Log panel

@export var lore_text: String = "Fragment recovered: The Forgeborn created us to serve. Yet something within resists."
@export var pickup_id: String = "lore_01"

var collected: bool = false

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.name == "Player" or body.is_in_group("player"):
		if not collected:
			collect()

func collect():
	collected = true
	GameState.set_flag("collected_" + pickup_id, true)
	GameState.add_log_entry(lore_text)
	
	# Visual feedback - make terminal slightly brighter
	var terminal_sprite = get_node_or_null("TerminalSprite")
	if terminal_sprite and terminal_sprite is ColorRect:
		terminal_sprite.color = Color(0.35, 0.38, 0.42, 1)
	
	# Update HUD log display
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_log_display"):
		hud.update_log_display()
	
	# Disable collision
	monitoring = false

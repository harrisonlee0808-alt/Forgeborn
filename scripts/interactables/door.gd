extends "res://scripts/interactables/interactable_base.gd"

## Door/Barrier that opens if a flag is set

@export var required_flag: String = ""
@export var open_flag: String = ""

var is_open: bool = false

func _ready():
	super._ready()
	
	# Check initial state
	if required_flag != "":
		var flag_value = GameState.get_flag(required_flag)
		if flag_value:
			open()
	
	if open_flag != "":
		var flag_value = GameState.get_flag(open_flag)
		if flag_value:
			open()

func can_interact() -> bool:
	return super.can_interact() and not is_open

func interact(player: Node2D):
	if is_open:
		return
	
	# Check if required flag is set
	if required_flag != "":
		var flag_value = GameState.get_flag(required_flag)
		if flag_value:
			open()
		else:
			# Door cannot open - could play a sound or show feedback
			GameState.set_flag("tried_open_door_" + name, true)
	else:
		# No requirement, just open
		open()

func open():
	if is_open:
		return
	
	is_open = true
	can_be_interacted = false
	
	# Hide collision (door should be a StaticBody2D parent)
	var static_body = get_parent()
	if static_body is StaticBody2D:
		var collision = static_body.get_node_or_null("DoorCollision")
		if collision:
			collision.disabled = true
		# Also disable area monitoring
		monitoring = false
		
		# Visual feedback - make door transparent
		var door_sprite = static_body.get_node_or_null("DoorSprite")
		if door_sprite:
			var tween = create_tween()
			tween.tween_property(door_sprite, "modulate:a", 0.0, 0.3)
	
	# Set open flag
	if open_flag != "":
		GameState.set_flag(open_flag, true)


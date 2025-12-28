extends Area2D
class_name InteractableBase

## Base class for all interactable objects
## Extend this to create specific interaction types

@export var interaction_range: float = 80.0
@export var interaction_prompt: String = "Press E to interact"

var can_be_interacted: bool = true

func _ready():
	# Add to interactable group
	add_to_group("interactable")
	
	# Connect area signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

## Check if this interactable can be interacted with
func can_interact() -> bool:
	return can_be_interacted

## Called when player enters interaction range
func _on_body_entered(body: Node2D):
	if body.name == "Player" or body.is_in_group("player"):
		pass  # Can add visual feedback here if needed

## Called when player leaves interaction range
func _on_body_exited(body: Node2D):
	if body.name == "Player" or body.is_in_group("player"):
		pass  # Can add visual feedback here if needed

## Override this method in child classes to define interaction behavior
func interact(player: Node2D):
	push_error("InteractableBase.interact() not overridden in " + name)


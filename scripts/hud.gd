extends CanvasLayer

## HUD controller - displays Health and Charge bars

var health_bar: ProgressBar
var charge_bar: ProgressBar

func _ready():
	# Get references
	health_bar = $HUDContainer/HealthBar
	charge_bar = $HUDContainer/ChargeBar
	
	# Set up bar styles to match world palette (dark, minimal)
	if health_bar:
		health_bar.max_value = GameState.max_health
		health_bar.value = GameState.health
	if charge_bar:
		charge_bar.max_value = GameState.max_charge
		charge_bar.value = GameState.charge

func _process(_delta: float):
	# Update bars from GameState
	if health_bar:
		health_bar.value = GameState.health
	if charge_bar:
		charge_bar.value = GameState.charge
	
	# Low contrast until critical (per GRAPHICS.md)
	# Could modify bar colors here when health/charge is low


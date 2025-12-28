extends CanvasLayer

## HUD controller - displays Health and Charge bars, Log panel

var health_bar: ProgressBar
var charge_bar: ProgressBar
var log_panel: VBoxContainer
var log_scroll: ScrollContainer

func _ready():
	# Add to group for area trigger access
	add_to_group("hud")
	
	# Get references
	health_bar = $HUDContainer/HealthBar
	charge_bar = $HUDContainer/ChargeBar
	log_panel = $LogContainer/LogScroll/LogPanel
	log_scroll = $LogContainer/LogScroll
	
	# Set up bar styles to match world palette (dark, minimal)
	if health_bar:
		health_bar.max_value = GameState.max_health
		health_bar.value = GameState.health
	if charge_bar:
		charge_bar.max_value = GameState.max_charge
		charge_bar.value = GameState.charge
	
	# Set up log panel (initially hidden/minimal)
	if log_panel:
		update_log_display()

func _process(_delta: float):
	# Update bars from GameState
	if health_bar:
		health_bar.value = GameState.health
	if charge_bar:
		charge_bar.value = GameState.charge

## Flicker HUD (called by area triggers)
func flicker(duration: float):
	if health_bar and charge_bar:
		var tween = create_tween()
		tween.set_loops(4)
		tween.tween_property(health_bar, "modulate:a", 0.3, duration / 8.0)
		tween.tween_property(health_bar, "modulate:a", 1.0, duration / 8.0)
		tween.tween_property(charge_bar, "modulate:a", 0.3, duration / 8.0)
		tween.tween_property(charge_bar, "modulate:a", 1.0, duration / 8.0)

## Update log display
func update_log_display():
	if not log_panel:
		return
	
	# Clear existing children
	for child in log_panel.get_children():
		child.queue_free()
	
	# Add log entries
	for entry in GameState.get_log_entries():
		var label = Label.new()
		label.text = entry
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 1))
		log_panel.add_child(label)

## Show/hide log panel
func toggle_log():
	if log_scroll:
		log_scroll.visible = not log_scroll.visible



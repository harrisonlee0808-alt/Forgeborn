extends Node

## AudioManager - Handles biome ambient audio with fade transitions

var current_audio_player: AudioStreamPlayer
var fade_tween: Tween

# Biome audio stream paths (stubbed with placeholders)
var biome_audio_paths: Dictionary = {
	"crystal_chasm": "res://assets/audio/crystal_chasm_ambient.ogg"
}

func _ready():
	# Create audio player for ambient audio
	current_audio_player = AudioStreamPlayer.new()
	add_child(current_audio_player)
	current_audio_player.volume_db = -10.0  # Adjust volume to be subtle
	current_audio_player.autoplay = false
	current_audio_player.stream_paused = false
	current_audio_player.bus = "Master"

## Change biome and fade to new ambient audio
func change_biome(biome_name: String):
	var audio_path = biome_audio_paths.get(biome_name)
	if audio_path == null:
		print("AudioManager: No audio for biome: ", biome_name)
		return
	
	# Load and play new audio with fade
	var new_stream = load(audio_path)
	if new_stream == null:
		print("AudioManager: Failed to load audio: ", audio_path)
		# Still proceed to set up system even without audio file
		return
	
	fade_to_audio(new_stream)

## Fade out current audio and fade in new audio
func fade_to_audio(new_stream: AudioStream):
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	
	# Fade out current audio
	if current_audio_player.playing:
		fade_tween.tween_property(current_audio_player, "volume_db", -80.0, 1.0)
		await fade_tween.finished
	
	# Switch stream and fade in
	current_audio_player.stream = new_stream
	current_audio_player.volume_db = -80.0
	current_audio_player.play()
	
	# Fade in new audio
	fade_tween = create_tween()
	fade_tween.tween_property(current_audio_player, "volume_db", -10.0, 1.5)

## Start playing ambient audio for current biome
func play_biome_audio(biome_name: String):
	var audio_path = biome_audio_paths.get(biome_name)
	if audio_path == null:
		print("AudioManager: No audio path for biome: ", biome_name)
		return
	
	var stream = load(audio_path)
	if stream == null:
		# Audio file doesn't exist yet (placeholder), print message but don't error
		print("AudioManager: Audio file not found (placeholder): ", audio_path)
		return
	
	current_audio_player.stream = stream
	current_audio_player.volume_db = -10.0
	current_audio_player.play()

## Stop ambient audio with fade
func stop_audio():
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(current_audio_player, "volume_db", -80.0, 1.0)
	await fade_tween.finished
	current_audio_player.stop()

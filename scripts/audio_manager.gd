extends Node

## AudioManager - Handles biome ambient audio with fade transitions
## Simplified to use only the available ambient audio file

var ambient_player: AudioStreamPlayer
var fade_tween: Tween

# Biome audio stream paths (only using files that exist)
var biome_audio_paths: Dictionary = {
	"crystal_chasm": "res://assets/audio/crystal_chasm_ambient.ogg"
}

func _ready():
	# Create ambient audio player
	ambient_player = AudioStreamPlayer.new()
	add_child(ambient_player)
	ambient_player.volume_db = -10.0
	ambient_player.autoplay = false
	ambient_player.bus = "Master"

## Change biome and fade to new ambient audio
func change_biome(biome_name: String):
	var audio_path = biome_audio_paths.get(biome_name)
	
	if audio_path:
		var new_stream = load(audio_path)
		if new_stream:
			fade_to_audio(new_stream)
		else:
			push_warning("AudioManager: Could not load audio file: " + audio_path)
	else:
		push_warning("AudioManager: No audio path for biome: " + biome_name)

## Fade to new audio
func fade_to_audio(new_stream: AudioStream):
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	# Fade out current audio if playing
	if ambient_player.playing:
		fade_tween = create_tween()
		fade_tween.tween_property(ambient_player, "volume_db", -80.0, 1.0)
		await fade_tween.finished
	
	# Switch stream and fade in
	ambient_player.stream = new_stream
	ambient_player.volume_db = -80.0
	ambient_player.play()
	
	# Fade in new audio
	fade_tween = create_tween()
	fade_tween.tween_property(ambient_player, "volume_db", -10.0, 1.5)

## Start playing ambient audio for current biome
func play_biome_audio(biome_name: String):
	var audio_path = biome_audio_paths.get(biome_name)
	if audio_path:
		# Try multiple loading methods to handle import cache issues
		var stream = null
		
		# Method 1: Try direct load
		stream = load(audio_path)
		
		# Method 2: If that fails, try ResourceLoader
		if not stream:
			stream = ResourceLoader.load(audio_path, "AudioStream", ResourceLoader.CACHE_MODE_IGNORE)
		
		# Method 3: Try with explicit type hint
		if not stream:
			var resource = ResourceLoader.load(audio_path)
			if resource and resource is AudioStream:
				stream = resource
		
		if stream:
			ambient_player.stream = stream
			ambient_player.volume_db = -10.0
			ambient_player.play()
			print("AudioManager: Playing biome audio for ", biome_name, " at path: ", audio_path)
		else:
			push_warning("AudioManager: Could not load audio: " + audio_path)
			# Try to check if file exists
			var file = FileAccess.open(audio_path, FileAccess.READ)
			if file:
				file.close()
				print("AudioManager: File exists but failed to load as AudioStream. May need re-import in Godot editor.")
			else:
				print("AudioManager: File does not exist at: ", audio_path)
	else:
		push_warning("AudioManager: No audio for biome: " + biome_name)

## Stop audio with fade
func stop_audio():
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	if ambient_player.playing:
		fade_tween = create_tween()
		fade_tween.tween_property(ambient_player, "volume_db", -80.0, 1.0)
		await fade_tween.finished
		ambient_player.stop()

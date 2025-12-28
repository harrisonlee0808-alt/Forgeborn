extends Node

## AudioManager - Handles biome ambient audio with fade transitions and multiple layers

var ambient_player: AudioStreamPlayer
var rumble_player: AudioStreamPlayer
var shimmer_player: AudioStreamPlayer
var fade_tween: Tween

# Biome audio stream paths
var biome_audio_paths: Dictionary = {
	"crystal_chasm": "res://assets/audio/crystal_chasm_ambient.ogg"
}

var biome_rumble_paths: Dictionary = {
	"crystal_chasm": "res://assets/audio/crystal_chasm_rumble.ogg"
}

var biome_shimmer_paths: Dictionary = {
	"crystal_chasm": "res://assets/audio/crystal_chasm_shimmer.ogg"
}

func _ready():
	# Create ambient audio player
	ambient_player = AudioStreamPlayer.new()
	add_child(ambient_player)
	ambient_player.volume_db = -12.0
	ambient_player.autoplay = false
	ambient_player.bus = "Master"
	
	# Create rumble layer (low frequency background)
	rumble_player = AudioStreamPlayer.new()
	add_child(rumble_player)
	rumble_player.volume_db = -20.0
	rumble_player.autoplay = false
	rumble_player.bus = "Master"
	
	# Create shimmer layer (high frequency sparkle)
	shimmer_player = AudioStreamPlayer.new()
	add_child(shimmer_player)
	shimmer_player.volume_db = -25.0
	shimmer_player.autoplay = false
	shimmer_player.bus = "Master"

## Change biome and fade to new ambient audio
func change_biome(biome_name: String):
	var audio_path = biome_audio_paths.get(biome_name)
	var rumble_path = biome_rumble_paths.get(biome_name)
	var shimmer_path = biome_shimmer_paths.get(biome_name)
	
	if audio_path:
		var new_stream = load(audio_path)
		if new_stream:
			fade_to_audio(ambient_player, new_stream)
	
	if rumble_path:
		var new_rumble = load(rumble_path)
		if new_rumble:
			fade_to_audio(rumble_player, new_rumble)
	
	if shimmer_path:
		var new_shimmer = load(shimmer_path)
		if new_shimmer:
			fade_to_audio(shimmer_player, new_shimmer)

## Fade to new audio for a specific player
func fade_to_audio(player: AudioStreamPlayer, new_stream: AudioStream):
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	
	# Fade out current audio
	if player.playing:
		fade_tween.tween_property(player, "volume_db", -80.0, 1.0)
		await fade_tween.finished
	
	# Switch stream and fade in
	player.stream = new_stream
	# Note: Loop is set in the audio file import settings in Godot, not in code
	player.volume_db = -80.0
	player.play()
	
	# Fade in new audio
	fade_tween = create_tween()
	var target_volume = -12.0 if player == ambient_player else (-20.0 if player == rumble_player else -25.0)
	fade_tween.tween_property(player, "volume_db", target_volume, 1.5)

## Start playing ambient audio for current biome
func play_biome_audio(biome_name: String):
	var audio_path = biome_audio_paths.get(biome_name)
	if audio_path:
		var stream = load(audio_path)
		if stream:
			# Note: Loop is set in the audio file import settings in Godot
			ambient_player.stream = stream
			ambient_player.volume_db = -12.0
			ambient_player.play()
	
	var rumble_path = biome_rumble_paths.get(biome_name)
	if rumble_path:
		var stream = load(rumble_path)
		if stream:
			# Note: Loop is set in the audio file import settings in Godot
			rumble_player.stream = stream
			rumble_player.volume_db = -20.0
			rumble_player.play()
	
	var shimmer_path = biome_shimmer_paths.get(biome_name)
	if shimmer_path:
		var stream = load(shimmer_path)
		if stream:
			# Note: Loop is set in the audio file import settings in Godot
			shimmer_player.stream = stream
			shimmer_player.volume_db = -25.0
			shimmer_player.play()

## Fade out a specific layer
func fade_out_layer(layer_name: String, duration: float = 1.0):
	var player_to_fade = null
	match layer_name:
		"ambient":
			player_to_fade = ambient_player
		"rumble":
			player_to_fade = rumble_player
		"shimmer":
			player_to_fade = shimmer_player
	
	if player_to_fade and player_to_fade.playing:
		if fade_tween:
			fade_tween.kill()
		fade_tween = create_tween()
		fade_tween.tween_property(player_to_fade, "volume_db", -80.0, duration)
		await fade_tween.finished
		player_to_fade.stop()

## Fade in a specific layer
func fade_in_layer(layer_name: String, duration: float = 1.0):
	var player_to_fade = null
	match layer_name:
		"ambient":
			player_to_fade = ambient_player
		"rumble":
			player_to_fade = rumble_player
		"shimmer":
			player_to_fade = shimmer_player
	
	if player_to_fade and player_to_fade.stream:
		if fade_tween:
			fade_tween.kill()
		player_to_fade.volume_db = -80.0
		player_to_fade.play()
		fade_tween = create_tween()
		var target_volume = -12.0 if player_to_fade == ambient_player else (-20.0 if player_to_fade == rumble_player else -25.0)
		fade_tween.tween_property(player_to_fade, "volume_db", target_volume, duration)

## Stop all audio with fade
func stop_audio():
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	if ambient_player.playing:
		fade_tween.tween_property(ambient_player, "volume_db", -80.0, 1.0)
	if rumble_player.playing:
		fade_tween.tween_property(rumble_player, "volume_db", -80.0, 1.0)
	if shimmer_player.playing:
		fade_tween.tween_property(shimmer_player, "volume_db", -80.0, 1.0)
	await fade_tween.finished
	ambient_player.stop()
	rumble_player.stop()
	shimmer_player.stop()

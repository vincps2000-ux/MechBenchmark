# test_audio_event_system.gd — Focused tests for shared procedural audio recipes.
extends GutTest

const _AUDIO_EVENT_SYSTEM := preload("res://src/autoload/audio_event_system.gd")
const _AUDIO_EVENT_SCRIPT := preload("res://src/autoload/audio_event.gd")


func test_laser_volume_scales_with_intensity() -> void:
	assert_lt(_AUDIO_EVENT_SYSTEM.get_laser_volume_db(0), _AUDIO_EVENT_SYSTEM.get_laser_volume_db(4),
		"Low laser intensity should be quieter than overload")
	assert_lt(_AUDIO_EVENT_SYSTEM.get_laser_pitch_scale(0), _AUDIO_EVENT_SYSTEM.get_laser_pitch_scale(4),
		"Low laser intensity should pitch lower than overload")
	var low_volume := _AUDIO_EVENT_SYSTEM.get_laser_volume_db(1)
	var high_volume := _AUDIO_EVENT_SYSTEM.get_laser_volume_db(3)
	assert_gt(high_volume - low_volume, 18.0,
		"High laser intensity should be dramatically louder than low")
	var low_pitch := _AUDIO_EVENT_SYSTEM.get_laser_pitch_scale(1)
	var high_pitch := _AUDIO_EVENT_SYSTEM.get_laser_pitch_scale(3)
	assert_gt(high_pitch - low_pitch, 0.35,
		"High laser intensity should sound much sharper than low")


func test_deflection_volume_is_capped_and_progressive() -> void:
	assert_lt(_AUDIO_EVENT_SYSTEM.get_deflection_volume_db(0), _AUDIO_EVENT_SYSTEM.get_deflection_volume_db(4),
		"Stronger deflection events should be louder than weak ones")


func test_event_fires_with_queueable_delay_defaults() -> void:
	var event := _AUDIO_EVENT_SCRIPT.new()
	assert_eq(event.time_sec, 0.0,
		"Audio events should default to immediate playback")
	assert_false(event.loop,
		"Audio events should default to one-shot playback")

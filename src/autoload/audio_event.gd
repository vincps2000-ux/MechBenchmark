class_name AudioEvent
extends RefCounted

enum Kind {
	LASER_LOOP,
	DEFLECTION_SIZZLE,
	EXPLOSION_BOOM,
}

var kind: Kind = Kind.LASER_LOOP
var time_sec: float = 0.0
var sequence: int = 0
var source_id: int = 0
var source_ref: WeakRef = null
var active: bool = false
var position: Vector2 = Vector2.ZERO
var intensity: int = 2
var scale: float = 1.0
var max_distance: float = 800.0
var volume_db: float = NAN
var pitch_scale: float = 1.0
var loop: bool = false
var seed: int = 0
var player: AudioStreamPlayer2D = null
var cancelled: bool = false

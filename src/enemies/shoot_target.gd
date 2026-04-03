# shoot_target.gd — Static shootable target for practice / testing.
# All targets are one-shots — any hit immediately destroys the target.
class_name ShootTarget
extends Area2D

signal destroyed(target: ShootTarget)

const FLASH_COLOR := Color(2.5, 2.5, 2.5, 1.0)

@onready var _sprite: Sprite2D = $Sprite2D

var _flashing: bool = false

## Called externally (e.g. by Laser, Flamethrower) when hit — one-shot kill
func take_damage(_amount: int, _penetration: int = 10) -> void:
	if _flashing:   # already dying
		return
	_flashing = true
	_sprite.modulate = FLASH_COLOR
	destroyed.emit(self)
	# Brief flash before disappearing
	await get_tree().create_timer(0.06).timeout
	queue_free()

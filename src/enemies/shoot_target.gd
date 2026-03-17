# shoot_target.gd — Static shootable target for practice / testing
class_name ShootTarget
extends Area2D

signal destroyed(target: ShootTarget)

const FLASH_COLOR := Color(2.2, 2.2, 2.2, 1.0)

@export var max_health: int = 50

@onready var _sprite:   Sprite2D = $Sprite2D
@onready var _hp_label: Label    = $HPLabel

var _health: int = 0
var _flashing: bool = false

func _ready() -> void:
	_health = max_health
	_update_label()

## Called externally (e.g. by Laser) when hit
func take_damage(amount: int) -> void:
	_health = maxi(_health - amount, 0)
	_update_label()
	if not _flashing:
		_flash()
	if _health <= 0:
		destroyed.emit(self)
		queue_free()

func _update_label() -> void:
	if _hp_label:
		_hp_label.text = "%d" % _health

func _flash() -> void:
	_flashing = true
	_sprite.modulate = FLASH_COLOR
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(_sprite):
		_sprite.modulate = Color.WHITE
	_flashing = false

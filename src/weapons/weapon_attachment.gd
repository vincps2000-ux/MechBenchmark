# weapon_attachment.gd — Base class for all weapon attachments.
# Attachments are Node2D children added to a weapon node.
class_name WeaponAttachment
extends Node2D

## Human-readable name shown in UI.
var display_name: String = "Attachment"

## Whether this attachment is active.
var enabled: bool = true

func _update_visibility() -> void:
	visible = enabled

## Mount all attachments defined in a WeaponData onto the given weapon node.
static func mount_from_data(weapon: Node, data: WeaponData) -> void:
	for att_data: AttachmentData in data.attachments:
		if att_data == null:
			continue
		var attachment: WeaponAttachment = _create_attachment(att_data)
		if attachment:
			weapon.add_child(attachment)

static func _create_attachment(att_data: AttachmentData) -> WeaponAttachment:
	match att_data.attachment_type:
		AttachmentData.AttachmentType.LASER_POINTER:
			var lp := LaserPointerAttachment.new()
			lp.beam_color = att_data.color
			lp.enabled = att_data.enabled
			return lp
		_:
			return null

# attachment_data.gd — Data class for weapon attachment configuration.
class_name AttachmentData
extends Resource

enum AttachmentType {
	LASER_POINTER,
}

@export var attachment_type: AttachmentType = AttachmentType.LASER_POINTER
@export var color: Color = Color.RED
@export var enabled: bool = true

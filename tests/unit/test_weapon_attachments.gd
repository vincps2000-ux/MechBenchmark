# test_weapon_attachments.gd — Unit tests for the weapon attachment system.
extends GutTest

# ─── WeaponAttachment base ────────────────────────────────────────────────────

func test_attachment_has_display_name() -> void:
	var att := WeaponAttachment.new()
	add_child_autofree(att)
	assert_typeof(att.display_name, TYPE_STRING)

func test_attachment_has_enabled_flag() -> void:
	var att := WeaponAttachment.new()
	add_child_autofree(att)
	assert_true(att.enabled, "Attachments should default to enabled")

func test_attachment_disabled_hides_node() -> void:
	var att := WeaponAttachment.new()
	add_child_autofree(att)
	att.enabled = false
	att._update_visibility()
	assert_false(att.visible, "Disabled attachment should be invisible")

func test_attachment_enabled_shows_node() -> void:
	var att := WeaponAttachment.new()
	add_child_autofree(att)
	att.enabled = true
	att._update_visibility()
	assert_true(att.visible, "Enabled attachment should be visible")

# ─── LaserPointerAttachment ──────────────────────────────────────────────────

func test_laser_pointer_is_attachment() -> void:
	var lp := LaserPointerAttachment.new()
	add_child_autofree(lp)
	assert_true(lp is WeaponAttachment, "LaserPointer should extend WeaponAttachment")

func test_laser_pointer_default_color_is_red() -> void:
	var lp := LaserPointerAttachment.new()
	add_child_autofree(lp)
	assert_eq(lp.beam_color, Color.RED, "Default laser pointer color should be red")

func test_laser_pointer_color_can_be_changed() -> void:
	var lp := LaserPointerAttachment.new()
	add_child_autofree(lp)
	lp.beam_color = Color.GREEN
	assert_eq(lp.beam_color, Color.GREEN, "Laser pointer color should be changeable")

func test_laser_pointer_has_beam_length() -> void:
	var lp := LaserPointerAttachment.new()
	add_child_autofree(lp)
	assert_gt(lp.beam_length, 0.0, "Beam length should be positive")

func test_laser_pointer_has_beam_width() -> void:
	var lp := LaserPointerAttachment.new()
	add_child_autofree(lp)
	assert_gt(lp.beam_width, 0.0, "Beam width should be positive")

func test_laser_pointer_display_name() -> void:
	var lp := LaserPointerAttachment.new()
	add_child_autofree(lp)
	assert_eq(lp.display_name, "Laser Pointer", "Display name should be 'Laser Pointer'")

# ─── WeaponData attachment list ──────────────────────────────────────────────

func test_weapon_data_has_attachments_array() -> void:
	var data := WeaponData.new()
	assert_typeof(data.attachments, TYPE_ARRAY)

func test_weapon_data_attachments_default_empty() -> void:
	var data := WeaponData.new()
	assert_eq(data.attachments.size(), 0, "Attachments should default to empty")

# ─── Weapon attachment integration ───────────────────────────────────────────

func test_autocannon_mounts_attachments_from_data() -> void:
	var data := WeaponData.new()
	var att_data := AttachmentData.new()
	att_data.attachment_type = AttachmentData.AttachmentType.LASER_POINTER
	att_data.color = Color.BLUE
	data.attachments.append(att_data)

	var weapon := Autocannon.new()
	add_child_autofree(weapon)
	weapon.setup(data)

	var found := false
	for child in weapon.get_children():
		if child is LaserPointerAttachment:
			found = true
			assert_eq(child.beam_color, Color.BLUE, "Attachment color should match data")
			break
	assert_true(found, "Autocannon should have mounted a LaserPointerAttachment")

# ─── AttachmentData ──────────────────────────────────────────────────────────

func test_attachment_data_default_type() -> void:
	var ad := AttachmentData.new()
	assert_eq(ad.attachment_type, AttachmentData.AttachmentType.LASER_POINTER)

func test_attachment_data_default_color_red() -> void:
	var ad := AttachmentData.new()
	assert_eq(ad.color, Color.RED, "Default attachment color should be red")

func test_attachment_data_enabled_default_true() -> void:
	var ad := AttachmentData.new()
	assert_true(ad.enabled, "Attachment should default to enabled")

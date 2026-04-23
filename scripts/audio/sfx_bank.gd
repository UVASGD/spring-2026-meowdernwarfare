class_name SfxBank
extends Resource

@export var slots: Array[SfxSlot] = []

func get_slot(id: StringName) -> SfxSlot:
	for slot in slots:
		if slot and slot.id == id:
			return slot
	return null

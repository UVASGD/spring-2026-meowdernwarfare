class_name Ability
extends Resource

## Unified ability representation shared by all heroes.
##
## Heroes can own any number of Ability resources. The three kinds are:
##   - COOLDOWN: single timer, ready when cd <= 0.
##   - CHARGES: regenerating pool (used by Loanshark). Timer ticks down; reaching 0 grants +1
##              charge up to max_charges.
##   - SLOTS: fixed-count consumable (Garebare FIEs). No auto-regen.
##
## Call `tick(delta)` every frame (hero does this centrally) and `try_use()` before firing.
## The existing hero scripts can migrate to this incrementally; new heroes should start here.

enum Kind { COOLDOWN, CHARGES, SLOTS }

@export var id: StringName = &""
@export var kind: Kind = Kind.COOLDOWN
@export var cooldown: float = 1.0
@export var max_charges: int = 1
@export var start_full: bool = true

var cd: float = 0.0
var charges: int = 0


func _init(kind_: Kind = Kind.COOLDOWN, cooldown_: float = 1.0, max_charges_: int = 1) -> void:
	kind = kind_
	cooldown = cooldown_
	max_charges = max_charges_
	charges = max_charges if start_full else 0

func reset() -> void:
	cd = 0.0
	charges = max_charges if start_full else 0
	changed.emit()

func tick(delta: float) -> void:
	match kind:
		Kind.COOLDOWN:
			if cd > 0.0:
				cd = maxf(0.0, cd - delta)
				if cd <= 0.0:
					changed.emit()
		Kind.CHARGES:
			if charges >= max_charges:
				return
			cd = maxf(0.0, cd - delta)
			if cd <= 0.0:
				charges = mini(max_charges, charges + 1)
				if charges < max_charges:
					cd = cooldown
				changed.emit()
		Kind.SLOTS:
			pass

func can_use() -> bool:
	match kind:
		Kind.COOLDOWN:
			return cd <= 0.0
		Kind.CHARGES, Kind.SLOTS:
			return charges > 0
	return false

func try_use() -> bool:
	if not can_use():
		return false
	match kind:
		Kind.COOLDOWN:
			cd = cooldown
		Kind.CHARGES:
			charges -= 1
			if cd <= 0.0:
				cd = cooldown
		Kind.SLOTS:
			charges -= 1
	changed.emit()
	return true

func add_charge(n: int = 1) -> void:
	if kind == Kind.COOLDOWN:
		return
	charges = mini(max_charges, charges + n)
	changed.emit()

func get_percent() -> float:
	match kind:
		Kind.COOLDOWN:
			if cooldown <= 0.0:
				return 1.0
			return 1.0 - (cd / cooldown)
		Kind.CHARGES:
			if max_charges <= 0:
				return 1.0
			var per: float = 1.0 / float(max_charges)
			var base: float = float(charges) / float(max_charges)
			if charges >= max_charges:
				return 1.0
			if cooldown <= 0.0:
				return base + per
			return base + per * (1.0 - cd / cooldown)
		Kind.SLOTS:
			return float(charges) / float(max_charges) if max_charges > 0 else 0.0
	return 0.0

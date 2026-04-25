class_name MenuParallax
extends RefCounted

## Helper for menu/lobby parallax effects driven by the mouse. Each menu owns
## a MenuParallax and calls `step(delta, layers)` every frame, passing the
## per-layer strength and the current offset by reference. This replaces the
## near-duplicate _update_bg_* routines in main_menu / joinscreen / lobby.

## Returns normalized mouse coords in [-1, 1] based on the viewport rect.
## Returns (INF, INF) if the viewport is not ready.
static func mouse_norm(viewport: Viewport) -> Vector2:
	var vp := viewport.get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return Vector2.INF
	var m := viewport.get_mouse_position()
	return Vector2((m.x / vp.x) * 2.0 - 1.0, (m.y / vp.y) * 2.0 - 1.0)

## Target offset for a layer whose per-axis amplitudes are `strength`.
static func target(norm: Vector2, strength: Vector2) -> Vector2:
	return Vector2(norm.x * strength.x, -norm.y * strength.y)

## Smooth lerp factor for a given delta and smoothing speed.
static func smooth_k(delta: float, smooth: float) -> float:
	return 1.0 - exp(-delta * smooth)

## One-call convenience: given current offset, strength, and smoothing, returns
## the new offset. Callers that also need to write to shader params can keep doing
## so explicitly using the returned value.
static func step(current: Vector2, norm: Vector2, strength: Vector2, delta: float, smooth: float) -> Vector2:
	return current.lerp(target(norm, strength), smooth_k(delta, smooth))

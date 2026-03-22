extends Sprite2D

func fadeout(param):
	var p = get_parent()
	if p and p.has_method("fadeout"):
		p.fadeout()

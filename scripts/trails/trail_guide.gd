extends Control

const Ink = preload("res://scripts/trails/trail_ink.gd")
var state: RefCounted
var painting: Texture2D

func _draw() -> void:
	if state == null: return
	var origin := size*.5
	var sc := minf(size.x/218.0,size.y/150.0)
	draw_set_transform(origin,0,Vector2.ONE*sc)
	var rect := Rect2(-106,-66,212,132)
	if state.info.kind == "register":
		draw_texture_rect(painting,Rect2(-103,-53,206,106),false)
		draw_rect(Rect2(-103,-53,206,106),Color("cbab70"),false,2)
	else:
		var optics: bool = state.info.kind == "mirror"
		draw_rect(rect,Color("295559") if optics else Color("e4cfaa"))
		Ink.flourish(self,rect.grow(-6),Ink.GOLD if optics else Color("9e7c56"))
		var at := Vector2.ZERO
		if optics:
			draw_polyline(PackedVector2Array([Vector2(-84,27),Vector2(-31,27),Vector2(-31,-16),Vector2(49,-16)]),Ink.GOLD,4,true)
			Ink.mirror(self,Vector2(-31,27),true,.48)
			Ink.mirror(self,Vector2(-31,-16),true,.48)
			if state.id == "zhangye": Ink.wheel(self,at+Vector2(50,-16),.91)
			else: Ink.gate(self,at+Vector2(50,-16),.91)
		else:
			for i in 3:
				var p := Vector2(-59+54*i,18-i*17)
				if state.id == "wuwei": Ink.hoof(self,p,-.28,.72 if i<2 else 1.02,Ink.INK)
				else:
					if i<2: draw_line(p,p+Vector2(53,-17),Ink.JADE,4,true)
					Ink.leaf(self,p,-.32,.72 if i<2 else 1.02)

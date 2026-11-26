extends Node2D

# Eye opening, gaze, brow height, brow inclination, smile and mouth opening.
const POSES := {
	"": [Vector2(1, 1), Vector2(.5, -.3), Vector2.ZERO, Vector2.ZERO, Vector2(.50, .05)],
	"greet": [Vector2(.89, .94), Vector2(-.5, -.8), Vector2(.8, 1.2), Vector2(-.3, .3), Vector2(.92, .58)],
	"look": [Vector2(1.18, 1.13), Vector2(2.0, -1.5), Vector2(1.8, 1.5), Vector2(.7, -.2), Vector2(.1, .25)],
	"think": [Vector2(.68, .90), Vector2(-1.5, -1.35), Vector2(-.6, 1.5), Vector2(1.55, -1.2), Vector2(-.42, .06)],
	"listen": [Vector2(1.02, .81), Vector2(-1.85, .2), Vector2(1.4, -.3), Vector2(-1.3, 1), Vector2(.23, .08)],
	"surprise": [Vector2(1.43, 1.37), Vector2(.4, -.7), Vector2(2.4, 2.5), Vector2(-.4, .3), Vector2(-.92, 1.0)],
	"celebrate": [Vector2(.08, .06), Vector2(.2, -.4), Vector2(1.5, 1.2), Vector2(-.7, .3), Vector2(1.0, 1.0)],
	"draw": [Vector2(.78, .8), Vector2(.4, 1.65), Vector2(-.4, -.55), Vector2(.8, -.6), Vector2(.01, .13)],
	"rest": [Vector2(.03, .04), Vector2(-.2, .8), Vector2(-1.2, -.8), Vector2(-.5, -.2), Vector2(.4, .0)]
}
const INK := Color("#583522")
const LASH := Color("#654021")
const BROW := Color("#b97b39")
const CREAM := Color("#ffedc4")

var mode := ""
var strength := 0.0
var blink := 0.0

func show_pose(action: String, weight: float, blink_amount: float) -> void:
	if action == mode and absf(weight - strength) < .007 and absf(blink_amount - blink) < .009:
		return
	mode = action if POSES.has(action) else ""
	strength = weight
	blink = blink_amount
	queue_redraw()

func _draw() -> void:
	var neutral: Array = POSES[""]
	var style: Array = POSES[mode]
	var opening: Vector2 = neutral[0].lerp(style[0], strength) * (1.0 - blink)
	var gaze: Vector2 = neutral[1].lerp(style[1], strength)
	var brows: Vector2 = neutral[2].lerp(style[2], strength)
	var slopes: Vector2 = neutral[3].lerp(style[3], strength)
	var lip: Vector2 = neutral[4].lerp(style[4], strength)
	var joy := strength if mode == "celebrate" else 0.0
	draw_set_transform(Vector2(17.6, -2.1), -.17, Vector2(.59, .82))
	eye(opening.y, gaze, brows.y, slopes.y, joy, false)
	draw_set_transform(Vector2.ZERO, -.105, Vector2(1.05, 1.0))
	eye(opening.x, gaze, brows.x, slopes.x, joy, true)
	draw_set_transform(Vector2(20.5, 7.3), -.07, Vector2.ONE)
	mouth(lip.x, lip.y)

func eye(opening: float, gaze: Vector2, raised: float, slope: float, joy: float, near: bool) -> void:
	var brow_start := Vector2(-5.7, -6.0 - raised + slope * .55)
	var brow_end := Vector2(4.9, -7.3 - raised - slope * .55)
	var brow_points := PackedVector2Array([brow_start])
	curve(brow_points, Vector2(-3.6, -9.4 - raised + slope), Vector2(2, -9.5 - raised - slope), brow_end)
	curve(brow_points, Vector2(2, -8.4 - raised - slope), Vector2(-2.9, -8.6 - raised + slope), brow_start)
	draw_colored_polygon(brow_points, BROW)
	if opening < .14:
		var closed := PackedVector2Array([Vector2(-6.5, .6)])
		curve(closed, Vector2(-3, lerpf(3.3, -4.2, joy)), Vector2(2, lerpf(2.0, -5.0, joy)), Vector2(6, -.6))
		draw_polyline(closed, LASH, .95, true)
		if near:
			draw_line(Vector2(-5.9, .9), Vector2(-7.5, .2 - joy), LASH, .58, true)
		return
	var left := Vector2(-6.25, .8)
	var right := Vector2(6.2, -.25)
	var border := PackedVector2Array([left])
	curve(border, Vector2(-4.8, -5.05 * opening), Vector2(2.15, -6.4 * opening), right)
	curve(border, Vector2(5.45, 3.35 * opening), Vector2(-1.2, 5.05 * opening), left)
	draw_colored_polygon(border, INK)
	var inside := PackedVector2Array([Vector2(-5.55, .9)])
	curve(inside, Vector2(-4.0, -4.55 * opening), Vector2(2.45, -5.55 * opening), Vector2(5.75, -.15))
	curve(inside, Vector2(5.1, 3.1 * opening), Vector2(-1.0, 4.4 * opening), Vector2(-5.55, .9))
	draw_colored_polygon(inside, CREAM)
	var iris := Vector2(.6, .15) + gaze
	clipped_oval(inside, iris, Vector2(4.35, 4.95), Color("#76461f"))
	clipped_oval(inside, iris + Vector2(.12, -.35), Vector2(3.52, 4.12), Color("#482b1b"))
	clipped_oval(inside, iris + Vector2(.25, -.48), Vector2(2.55, 3.45), Color("#36241b"))
	var glint := iris + Vector2(-.78, -1.55)
	clipped_oval(inside, glint, Vector2(1.15, 1.04), Color("#fffae8"))
	clipped_oval(inside, iris + Vector2(1.68, 1.4), Vector2(.46, .41), Color("#efca82"))
	var top := PackedVector2Array([Vector2(-7.85 if near else -6.9, -.25), left])
	curve(top, Vector2(-4.9, -5.1 * opening), Vector2(2.05, -6.42 * opening), right)
	draw_polyline(top, LASH, .76, true)

func mouth(smile: float, gape: float) -> void:
	var half_width := lerpf(1.45, 3.70, (smile + 1.0) * .5)
	var left := Vector2(-half_width, .12 - smile * .45)
	var right := Vector2(half_width, -.75 - smile * .32)
	var points := PackedVector2Array([left])
	curve(points, Vector2(-half_width * .2, .6 + smile * .9), Vector2(half_width * .7, .1 + smile * .6), right)
	if gape > .16:
		var bottom := .72 + gape * 3.5
		curve(points, Vector2(half_width * .66, bottom), Vector2(-half_width * .74, bottom + .38), left)
		draw_colored_polygon(points, Color("#743f2c"))
		var tongue := PackedVector2Array([Vector2(-half_width * .63, bottom * .55)])
		curve(tongue, Vector2(-half_width * .35, bottom * .39), Vector2(half_width * .18, bottom * .42), Vector2(half_width * .53, bottom * .5))
		curve(tongue, Vector2(half_width * .23, bottom * .83), Vector2(-half_width * .35, bottom * .87), Vector2(-half_width * .63, bottom * .55))
		draw_colored_polygon(tongue, Color("#df8d73"))
	else:
		draw_polyline(points, INK, .74, true)
	var philtrum := PackedVector2Array([right])
	curve(philtrum, right + Vector2(.8, -.35), Vector2(3.25, -2.1), Vector2(3.5, -3.45))
	draw_polyline(philtrum, Color("#8e5a39"), .44, true)

func clipped_oval(clip: PackedVector2Array, at: Vector2, radii: Vector2, color: Color) -> void:
	var oval := PackedVector2Array()
	for i in 24:
		oval.append(at + Vector2.from_angle(TAU * i / 24.0) * radii)
	for shape in Geometry2D.intersect_polygons(clip, oval):
		if shape.size() >= 3:
			draw_colored_polygon(shape, color)

func curve(points: PackedVector2Array, a: Vector2, b: Vector2, end: Vector2) -> void:
	var start := points[-1]
	for i in range(1, 9):
		points.append(start.bezier_interpolate(a, b, end, i / 8.0))

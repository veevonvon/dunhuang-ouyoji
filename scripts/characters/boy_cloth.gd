extends RefCounted


# The uninterrupted painting spans the joint. A third bone keeps the outside
# of a sharply bent sleeve round while the two rigid sections turn independently.
static func bind_cloth(skeleton: Skeleton2D, upper: Bone2D, hinge: Bone2D, lower: Bone2D,
		art: Texture2D, width: float, top: float, bottom: float, bend_band: float,
		layer: int, tint: Color) -> void:
	var skin := Polygon2D.new()
	skin.name = String(upper.name) + "Cloth"
	skeleton.add_child(skin)
	skin.skeleton = skin.get_path_to(skeleton)
	skin.texture = art
	skin.color = tint
	skin.z_index = layer
	var points := PackedVector2Array()
	var texels := PackedVector2Array()
	var tiles: Array[PackedInt32Array] = []
	var upper_weights := PackedFloat32Array()
	var hinge_weights := PackedFloat32Array()
	var lower_weights := PackedFloat32Array()
	var origin := skeleton.to_local(upper.global_position)
	var elbow := lower.position.y
	const ROWS := 16
	const COLUMNS := 3
	for row in ROWS + 1:
		var v := float(row) / ROWS
		var y := lerpf(top, bottom, v)
		var before := 1.0 - smoothstep(elbow - bend_band, elbow, y)
		var after := smoothstep(elbow, elbow + bend_band, y)
		for column in COLUMNS + 1:
			var u := float(column) / COLUMNS
			points.append(origin + Vector2((u - .5) * width, y))
			texels.append(Vector2(u, v) * art.get_size())
			upper_weights.append(before)
			hinge_weights.append(1.0 - before - after)
			lower_weights.append(after)
			if row < ROWS and column < COLUMNS:
				var a := row * (COLUMNS + 1) + column
				tiles.append(PackedInt32Array([a, a + 1, a + COLUMNS + 2, a + COLUMNS + 1]))
	skin.polygon = points
	skin.uv = texels
	skin.polygons = tiles
	skin.add_bone(skeleton.get_path_to(upper), upper_weights)
	skin.add_bone(skeleton.get_path_to(hinge), hinge_weights)
	skin.add_bone(skeleton.get_path_to(lower), lower_weights)

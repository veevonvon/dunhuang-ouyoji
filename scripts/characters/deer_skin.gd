extends RefCounted

# Two vertices per slice keep the paper texture continuous across a bent joint.
static func paint_strip(parent: Node2D, skeleton: Skeleton2D, id: String, texture: Texture2D,
		bones: Array[Bone2D], vertices: PackedVector2Array, uvs: PackedVector2Array,
		influences: PackedFloat32Array, tint := Color.WHITE) -> Polygon2D:
	var per_vertex := PackedFloat32Array()
	for influence in influences:
		per_vertex.append(influence)
		per_vertex.append(influence)
	return paint_grid(parent, skeleton, id, texture, bones, vertices, uvs, per_vertex, 2, tint)

static func paint_grid(parent: Node2D, skeleton: Skeleton2D, id: String, texture: Texture2D,
		bones: Array[Bone2D], vertices: PackedVector2Array, uvs: PackedVector2Array,
		influences: PackedFloat32Array, columns: int, tint: Color) -> Polygon2D:
	var mesh := Polygon2D.new()
	mesh.name = id
	mesh.texture = texture
	mesh.polygon = vertices
	mesh.uv = uvs
	mesh.color = tint
	var slices: Array[PackedInt32Array] = []
	for row in range(floori(float(vertices.size()) / columns) - 1):
		for column in range(columns - 1):
			var left := row * columns + column
			slices.append(PackedInt32Array([left, left + 1, left + columns + 1, left + columns]))
	mesh.polygons = slices
	parent.add_child(mesh)
	mesh.skeleton = mesh.get_path_to(skeleton)
	for i in bones.size():
		var weights := PackedFloat32Array()
		for along in influences:
			weights.append(maxf(0.0, 1.0 - absf(along - i)))
		mesh.add_bone(skeleton.get_path_to(bones[i]), weights)
	return mesh

static func paint_trunk(parent: Node2D, skeleton: Skeleton2D, texture: Texture2D,
		torso: Bone2D, neck: Bone2D, rect: Rect2) -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var influences := PackedFloat32Array()
	for row in 13:
		for column in 17:
			var uv := Vector2(column / 16.0, row / 12.0)
			vertices.append(rect.position + uv * rect.size)
			uvs.append(uv * texture.get_size())
			var shoulder := smoothstep(.51, .81, uv.x) * (1.0 - smoothstep(.42, .78, uv.y))
			influences.append(shoulder)
	var bones: Array[Bone2D] = [torso, neck]
	paint_grid(parent, skeleton, "TorsoInk", texture, bones, vertices, uvs, influences, 17, Color.WHITE)

static func paint_silk(parent: Node2D, skeleton: Skeleton2D, texture: Texture2D,
		bones: Array[Bone2D], size: Vector2, seam_height: float) -> void:
	var seam := skeleton.to_local(bones[0].global_position)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var influences := PackedFloat32Array()
	for i in 17:
		var t := i / 16.0
		var top := seam + Vector2(2 - size.x * t, -size.y * seam_height)
		vertices.append(top)
		vertices.append(top + Vector2(0, size.y))
		var u := texture.get_width() * (1.0 - t)
		uvs.append(Vector2(u, 0))
		uvs.append(Vector2(u, texture.get_height()))
		influences.append(smoothstep(.26, .57, t) + smoothstep(.63, .90, t))
	paint_strip(parent, skeleton, str(bones[0].name) + "Ink", texture, bones, vertices, uvs, influences)

extends SceneTree

func _initialize() -> void:
	var folder := "res://assets/licenses"
	DirAccess.make_dir_recursive_absolute(folder)
	var license := FileAccess.open(folder.path_join("Godot.txt"), FileAccess.WRITE)
	license.store_string(Engine.get_license_text())
	license.close()
	var third_party := FileAccess.open(folder.path_join("Godot-third-party.txt"), FileAccess.WRITE)
	third_party.store_string("Godot %s\n\n" % Engine.get_version_info().string)
	third_party.store_string(JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n")
	for name: String in Engine.get_license_info():
		third_party.store_string("\n=== %s ===\n\n%s\n" % [name, Engine.get_license_info()[name]])
	third_party.close()
	print("已写入当前 Godot 引擎的完整许可与第三方声明。")
	quit()

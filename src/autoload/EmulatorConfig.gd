extends Node

signal emulator_config_changed(emulator_id: String, config: Dictionary)

enum VideoStretchMode {
	SMALL,
	LARGE,
	FILL,
	PROPORTIONAL
}

enum VideoTextureFilter {
	INHERIT,
	NEAREST_MIPMAP,
	LINEAR_MIPMAP
}

var emulator_configs: Dictionary = {}

var default_config = {
	"video": {
		"stretch_mode": VideoStretchMode.FILL,
		"texture_filter": VideoTextureFilter.INHERIT
	},
	"audio": {
		"volume": 1.0
	},
	"core": {
		"path": "",
		"name": "",
		"version": ""
	}
}

func _ready():
	_load_configs()
	_load_cores()

func get_emulator_config(emulator_id: String) -> Dictionary:
	if emulator_configs.has(emulator_id):
		return emulator_configs[emulator_id]
	return default_config.duplicate(true)

func set_emulator_config(emulator_id: String, config: Dictionary):
	emulator_configs[emulator_id] = config
	_save_configs()
	emulator_config_changed.emit(emulator_id, config)

func update_emulator_setting(emulator_id: String, category: String, key: String, value):
	var config = get_emulator_config(emulator_id)
	
	if not config.has(category):
		config[category] = {}
	
	config[category][key] = value
	set_emulator_config(emulator_id, config)

func get_emulator_setting(emulator_id: String, category: String, key: String, default_value = null):
	var config = get_emulator_config(emulator_id)
	
	if config.has(category) and config[category].has(key):
		return config[category][key]
	
	return default_value

func _load_configs():
	var save_path = "user://emulator_configs.json"
	
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		emulator_configs = json.data
	else:
		push_error("emulator_config: failed to parse config file")

func _save_configs():
	var save_path = "user://emulator_configs.json"
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("emulator_config: failed to open config file for writing")
		return
	
	var json_string = JSON.stringify(emulator_configs, "\t")
	file.store_string(json_string)
	file.close()

func get_all_configured_emulators() -> Array:
	return emulator_configs.keys()

func has_emulator_config(emulator_id: String) -> bool:
	return emulator_configs.has(emulator_id)

func remove_emulator_config(emulator_id: String):
	if emulator_configs.has(emulator_id):
		emulator_configs.erase(emulator_id)
		_save_configs()

var libretro_cores: Dictionary = {}

const CORE_EXTENSIONS = {
	"snes": ["smc", "sfc"],
	"snes9x": ["smc", "sfc"],
	"bsnes": ["smc", "sfc"],
	"gba": ["gba"],
	"mgba": ["gba"],
	"vba": ["gba"],
	"genesis": ["md", "gen", "smd", "bin"],
	"megadrive": ["md", "gen", "smd", "bin"],
	"picodrive": ["md", "gen", "smd", "bin"],
}

func get_extensions_for_core(core_path: String) -> PackedStringArray:
	var core_name = core_path.get_file().get_basename().to_lower()
	
	core_name = core_name.replace("_libretro", "").replace("libretro_", "")
	core_name = core_name.replace("_android", "").replace("android_", "")
	core_name = core_name.replace("_linux", "").replace("_windows", "")
	
	var matched_extensions: Array = []
	
	for keyword in CORE_EXTENSIONS.keys():
		if keyword in core_name:
			for ext in CORE_EXTENSIONS[keyword]:
				if ext not in matched_extensions:
					matched_extensions.append(ext)
	
	if matched_extensions.is_empty():
		return PackedStringArray()
	
	return PackedStringArray(matched_extensions)

func set_libretro_core(core_id: String, core_path: String, rooms_folder: String = ""):
	libretro_cores[core_id] = {
		"core_path": core_path,
		"rooms_folder": rooms_folder
	}
	_save_cores()

func get_libretro_core(core_id: String) -> String:
	if libretro_cores.has(core_id):
		return libretro_cores[core_id].get("core_path", "")
	return ""

func get_core_rooms_folder(core_id: String) -> String:
	if libretro_cores.has(core_id):
		return libretro_cores[core_id].get("rooms_folder", "")
	return ""

func set_core_rooms_folder(core_id: String, rooms_folder: String):
	if libretro_cores.has(core_id):
		libretro_cores[core_id]["rooms_folder"] = rooms_folder
		_save_cores()

func get_all_cores() -> Dictionary:
	return libretro_cores.duplicate()

func remove_libretro_core(core_id: String):
	if libretro_cores.has(core_id):
		libretro_cores.erase(core_id)
		_save_cores()

func _save_cores():
	var save_path = "user://libretro_cores.json"
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("emulator_config: failed to save cores")
		return
	
	var json_string = JSON.stringify(libretro_cores, "\t")
	file.store_string(json_string)
	file.close()

func _load_cores():
	var save_path = "user://libretro_cores.json"
	
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		libretro_cores = json.data
	else:
		push_error("emulator_config: failed to parse cores file")

func get_core_path_for_rom(rom_path: String) -> String:
	for core_id in libretro_cores.keys():
		var core_data = libretro_cores[core_id]
		var rooms_folder = core_data.get("rooms_folder", "")
		
		if rooms_folder != "" and rom_path.begins_with(rooms_folder):
			return core_data.get("core_path", "")
	
	return ""

func get_core_id_for_rom(rom_path: String) -> String:
	for core_id in libretro_cores.keys():
		var core_data = libretro_cores[core_id]
		var rooms_folder = core_data.get("rooms_folder", "")
		
		if rooms_folder != "" and rom_path.begins_with(rooms_folder):
			return core_id
	return ""

func get_all_core_folders() -> Dictionary:
	var folders = {}
	for core_id in libretro_cores.keys():
		var core_data = libretro_cores[core_id]
		var rooms_folder = core_data.get("rooms_folder", "")
		if rooms_folder != "":
			folders[rooms_folder] = core_data.get("core_path", "")
	return folders

func get_system_id_from_extension(rom_path: String) -> String:
	var extension = rom_path.get_extension().to_lower()
	match extension:
		"gba": return "gba"
		"sfc", "smc", "snes": return "snes"
		"nes": return "nes"
		"gb", "gbc": return "gb"
		"n64", "z64", "v64": return "n64"
		"iso", "bin", "cue": return "psx"
		_: return ""

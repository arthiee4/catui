extends Node

signal game_data_loaded(rom_path: String, data: Dictionary)
signal cover_downloaded(rom_path: String, local_path: String)
signal queue_progress(current: int, total: int)
signal queue_finished

const BASE_URL = "https://retroachievements.org"
const API_BASE = "https://retroachievements.org/API"
const CACHE_FILE = "user://retroachievements_cache.json"
const COVERS_FOLDER = "user://covers"
const ICONS_FOLDER = "user://icons"

@export_group("API Configuration")
@export var api_key: String = ""
@export var username: String = ""
@export var enabled: bool = true

@export_group("Download Settings")
@export_range(1, 10) var max_concurrent_downloads: int = 2
@export_range(0.5, 5.0) var request_delay: float = 1.0
@export var auto_download_covers: bool = true

@export_group("Search Settings")
@export_range(0.0, 1.0) var min_match_score: float = 0.85
@export var use_fuzzy_search: bool = true

var http_request: HTTPRequest
var image_downloaders: Array = []
var active_downloads: int = 0

var cache: Dictionary = {}
var download_queue: Array = []
var is_processing_queue: bool = false

var lookup_count: int = 0
var lookup_total: int = 0

var games_database: Dictionary = {}

var console_id_map = {
	"gba": 5,
	"gbc": 6,
	"gb": 4,
	"nes": 7,
	"snes": 3,
	"sfc": 3,
	"smc": 3,
	"md": 1,
	"gen": 1,
	"n64": 2,
	"nds": 18,
	"psx": 12,
	"ps1": 12,
	"psp": 41,
	"arcade": 27,
	"mame": 27,
	"neo": 9,
	"pce": 8,
	"sms": 11,
	"gg": 15,
	"a2600": 25,
	"lynx": 13,
	"ws": 53,
	"wsc": 53,
	"ngp": 14
}

func _ready():
	_setup_http_requests()
	_setup_directories()
	_load_cache()

func _setup_http_requests():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 30.0
	
	for i in range(max_concurrent_downloads):
		var downloader = HTTPRequest.new()
		add_child(downloader)
		downloader.timeout = 60.0
		image_downloaders.append(downloader)

func _setup_directories():
	var covers_path = COVERS_FOLDER.replace("user://", OS.get_user_data_dir() + "/")
	var icons_path = ICONS_FOLDER.replace("user://", OS.get_user_data_dir() + "/")
	
	if not DirAccess.dir_exists_absolute(covers_path):
		DirAccess.make_dir_recursive_absolute(covers_path)
	
	if not DirAccess.dir_exists_absolute(icons_path):
		DirAccess.make_dir_recursive_absolute(icons_path)

func _load_cache():
	if not FileAccess.file_exists(CACHE_FILE):
		cache = {}
		return
	
	var file = FileAccess.open(CACHE_FILE, FileAccess.READ)
	if not file:
		cache = {}
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		cache = json.data
	else:
		cache = {}

func _save_cache():
	var file = FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cache, "\t"))
		file.close()

func is_configured() -> bool:
	return not api_key.is_empty() and not username.is_empty()

func get_cache_key(rom_path: String) -> String:
	return rom_path.md5_text()

func has_cached_data(rom_path: String) -> bool:
	var key = get_cache_key(rom_path)
	return cache.has(key)

func get_cached_data(rom_path: String) -> Dictionary:
	var key = get_cache_key(rom_path)
	if cache.has(key):
		return cache[key]
	return {}

func queue_rom_lookup(rom_path: String, console_hint: String = ""):
	if not enabled:
		return
	
	if not is_configured():
		return
	
	if has_cached_data(rom_path):
		var cached_data = get_cached_data(rom_path)
		if cached_data.get("found", false):
			game_data_loaded.emit(rom_path, cached_data)
			return
	
	download_queue.append({
		"rom_path": rom_path,
		"console_hint": console_hint,
		"type": "lookup"
	})
	
	if not is_processing_queue:
		_process_queue()

func queue_multiple_roms(rom_paths: Array, console_hint: String = ""):
	lookup_count = 0
	lookup_total = rom_paths.size()
	
	for path in rom_paths:
		queue_rom_lookup(path, console_hint)

func _process_queue():
	if download_queue.is_empty():
		is_processing_queue = false
		queue_finished.emit()
		return
	
	is_processing_queue = true
	
	var item = download_queue.pop_front()
	
	if item["type"] == "lookup":
		lookup_count += 1
		queue_progress.emit(lookup_count, lookup_total)
		await _lookup_game(item["rom_path"], item["console_hint"])
	elif item["type"] == "cover":
		await _download_image(item["url"], item["local_path"], item["rom_path"])
	
	await get_tree().create_timer(request_delay).timeout
	_process_queue()

func _lookup_game(rom_path: String, console_hint: String):
	var game_name = _clean_rom_name(rom_path.get_file().get_basename())
	var console_id = _get_console_id(rom_path, console_hint)
	
	if not games_database.has(console_id):
		await _fetch_games_list(console_id)
	
	var match_result = _find_best_match(game_name, console_id)
	
	if match_result["score"] >= min_match_score:
		await _fetch_game_details(match_result["id"], rom_path)
	else:
		var empty_data = {
			"title": rom_path.get_file().get_basename(),
			"genre": "",
			"cover_path": "",
			"icon_path": "",
			"found": false
		}
		_cache_result(rom_path, empty_data)
		game_data_loaded.emit(rom_path, empty_data)

func _fetch_games_list(console_id: int):
	var url = API_BASE + "/API_GetGameList.php?z=" + username + "&y=" + api_key + "&i=" + str(console_id) + "&h=0&f=0"
	
	http_request.request(url)
	var result = await http_request.request_completed
	
	if result[1] != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(result[3].get_string_from_utf8())
	
	if error != OK:
		return
	
	games_database[console_id] = []
	
	var games_data = json.data
	var games_array = []
	
	if games_data is Array:
		games_array = games_data
	elif games_data is Dictionary:
		games_array = games_data.values()
	
	for game in games_array:
		if game is Dictionary:
			games_database[console_id].append({
				"id": game.get("ID", 0),
				"title": game.get("Title", ""),
				"title_lower": game.get("Title", "").to_lower(),
				"title_normalized": _normalize_title(game.get("Title", ""))
			})

func _fetch_game_details(game_id: int, rom_path: String):
	var url = API_BASE + "/API_GetGame.php?z=" + username + "&y=" + api_key + "&i=" + str(game_id)
	
	http_request.request(url)
	var result = await http_request.request_completed
	
	if result[1] != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(result[3].get_string_from_utf8())
	
	if error != OK:
		return
	
	var game_data = json.data
	
	var title = game_data.get("Title", "")
	var box_art = game_data.get("ImageBoxArt", "")
	var icon = game_data.get("ImageIcon", "")
	
	var data = {
		"title": title,
		"genre": game_data.get("Genre", ""),
		"developer": game_data.get("Developer", ""),
		"publisher": game_data.get("Publisher", ""),
		"released": game_data.get("Released", ""),
		"cover_url": BASE_URL + box_art if not box_art.is_empty() else "",
		"icon_url": BASE_URL + icon if not icon.is_empty() else "",
		"cover_path": "",
		"icon_path": "",
		"game_id": game_id,
		"found": true
	}
	
	print("retroachievements: ", lookup_count, "/", lookup_total, " - '", title, "'")
	
	if auto_download_covers and not box_art.is_empty():
		var cover_local_path = COVERS_FOLDER + "/" + str(game_id) + "_cover.png"
		if FileAccess.file_exists(cover_local_path):
			data["cover_path"] = cover_local_path
		else:
			download_queue.append({
				"type": "cover",
				"url": BASE_URL + box_art,
				"local_path": cover_local_path,
				"rom_path": rom_path,
				"field": "cover_path"
			})
	
	if auto_download_covers and not icon.is_empty():
		var icon_local_path = ICONS_FOLDER + "/" + str(game_id) + "_icon.png"
		if FileAccess.file_exists(icon_local_path):
			data["icon_path"] = icon_local_path
		else:
			download_queue.append({
				"type": "cover",
				"url": BASE_URL + icon,
				"local_path": icon_local_path,
				"rom_path": rom_path,
				"field": "icon_path"
			})
	
	_cache_result(rom_path, data)
	game_data_loaded.emit(rom_path, data)

func _download_image(url: String, local_path: String, rom_path: String):
	var downloader = _get_available_downloader()
	
	if downloader == null:
		download_queue.push_front({
			"type": "cover",
			"url": url,
			"local_path": local_path,
			"rom_path": rom_path
		})
		return
	
	active_downloads += 1
	
	downloader.request(url)
	var result = await downloader.request_completed
	
	active_downloads -= 1
	
	if result[1] != 200:
		return
	
	var absolute_path = local_path.replace("user://", OS.get_user_data_dir() + "/")
	
	var file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file:
		file.store_buffer(result[3])
		file.close()
		
		var cache_key = get_cache_key(rom_path)
		if cache.has(cache_key):
			if "cover" in local_path:
				cache[cache_key]["cover_path"] = local_path
			elif "icon" in local_path:
				cache[cache_key]["icon_path"] = local_path
			_save_cache()
		
		cover_downloaded.emit(rom_path, local_path)

func _get_available_downloader() -> HTTPRequest:
	for downloader in image_downloaders:
		if downloader.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			return downloader
	return null

func _cache_result(rom_path: String, data: Dictionary):
	var key = get_cache_key(rom_path)
	cache[key] = data
	cache[key]["rom_path"] = rom_path
	cache[key]["cached_at"] = Time.get_unix_time_from_system()
	_save_cache()

func _clean_rom_name(rom_name: String) -> String:
	var cleaned = rom_name
	
	if ", The" in cleaned:
		cleaned = "The " + cleaned.replace(", The", "")
	elif ", A" in cleaned:
		cleaned = "A " + cleaned.replace(", A", "")
	
	var patterns = [
		"\\([^)]*\\)",
		"\\[[^\\]]*\\]",
		"\\s*-\\s*",
		"\\s+v\\d+\\.?\\d*",
		"\\s+rev\\s*\\d*",
		"\\s*\\(.*?\\)\\s*"
	]
	
	var regex = RegEx.new()
	for pattern in patterns:
		regex.compile(pattern)
		cleaned = regex.sub(cleaned, "", true)
	
	cleaned = cleaned.strip_edges()
	cleaned = cleaned.replace("_", " ")
	cleaned = cleaned.replace("  ", " ")
	
	return cleaned

func _normalize_title(title: String) -> String:
	var normalized = title.to_lower()
	
	normalized = normalized.replace(":", " ")
	normalized = normalized.replace("-", " ")
	normalized = normalized.replace("'", "")
	normalized = normalized.replace(".", " ")
	normalized = normalized.replace("!", " ")
	normalized = normalized.replace("?", " ")
	normalized = normalized.replace("&", "and")
	
	var regex = RegEx.new()
	regex.compile("\\s+")
	normalized = regex.sub(normalized, " ", true)
	
	return normalized.strip_edges()

func _get_console_id(rom_path: String, console_hint: String) -> int:
	if not console_hint.is_empty():
		var hint_lower = console_hint.to_lower()
		if console_id_map.has(hint_lower):
			return console_id_map[hint_lower]
	
	var extension = rom_path.get_extension().to_lower()
	
	if console_id_map.has(extension):
		return console_id_map[extension]
	
	return 0

func _find_best_match(search_name: String, console_id: int) -> Dictionary:
	if not games_database.has(console_id):
		return {"id": 0, "score": 0.0, "title": ""}
	
	var search_normalized = _normalize_title(search_name)
	var search_lower = search_name.to_lower()
	
	var best_match = {"id": 0, "score": 0.0, "title": ""}
	
	var penalty_keywords = ["hack", "subset", "prototype", "beta", "demo", "kaizo", "bonus"]
	
	for game in games_database[console_id]:
		var score = 0.0
		var game_title_lower = game["title_lower"]
		var game_title_normalized = game["title_normalized"]
		
		if game_title_normalized == search_normalized:
			score = 1.0
		elif game_title_lower == search_lower:
			score = 0.98
		elif search_normalized in game_title_normalized:
			score = 0.85
		elif game_title_normalized in search_normalized:
			score = 0.80
		elif use_fuzzy_search:
			score = _calculate_similarity(search_normalized, game_title_normalized)
		
		for keyword in penalty_keywords:
			if keyword in game_title_lower and not keyword in search_lower:
				score *= 0.5
		
		if score > best_match["score"]:
			best_match = {
				"id": game["id"],
				"score": score,
				"title": game["title"]
			}
		
		if score >= 0.99:
			break
	
	return best_match

func _calculate_similarity(string1: String, string2: String) -> float:
	if string1.is_empty() or string2.is_empty():
		return 0.0
	
	var words1 = string1.split(" ", false)
	var words2 = string2.split(" ", false)
	
	var matches = 0.0
	var total_weight = 0.0
	
	for word in words1:
		var weight = 1.0 + word.length() * 0.1
		total_weight += weight
		
		if word.length() < 2:
			continue
		
		for other_word in words2:
			if word == other_word:
				matches += weight * 2.0
				break
			elif word.length() >= 3 and other_word.length() >= 3:
				if word in other_word or other_word in word:
					matches += weight
					break
	
	if total_weight == 0:
		return 0.0
	
	return clamp(matches / (total_weight * 2.5), 0.0, 1.0)

func scan_emulator_rooms(emulator_node: Control):
	if not emulator_node:
		return
	
	if not "rooms_folder" in emulator_node:
		return
	
	var folder = emulator_node.rooms_folder
	var extensions = emulator_node.roms_extensions if "roms_extensions" in emulator_node else []
	var console_hint = extensions[0] if not extensions.is_empty() else ""
	
	if folder.is_empty():
		return
	
	if not DirAccess.dir_exists_absolute(folder):
		return
	
	var dir = DirAccess.open(folder)
	if not dir:
		return
	
	var rom_paths = []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var ext = file_name.get_extension().to_lower()
			if extensions.is_empty() or ext in extensions:
				rom_paths.append(folder.path_join(file_name))
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	queue_multiple_roms(rom_paths, console_hint)

func clear_cache():
	cache.clear()
	_save_cache()

func get_stats() -> Dictionary:
	return {
		"cached_games": cache.size(),
		"queue_size": download_queue.size(),
		"active_downloads": active_downloads,
		"is_processing": is_processing_queue
	}

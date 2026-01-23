@tool
extends MenuBase

const SETTINGS_OPTION = preload("res://src/components/settings_option.tscn")
const SETTINGS_BUTTONS = preload("res://src/components/settings_button.tscn")

var option_instances: Array = []
var current_focus_index: int = 0
var current_submenu_index: int = -1
var current_submenu_focus: int = 0
var submenu_buttons: Array = []

const INPUT_DELAY = 0.2

var current_subsubmenu_id: String = ""
var current_subsubmenu_focus: int = 0
var subsubmenu_buttons: Array = []

var is_waiting_for_input: bool = false
var pending_action_name: String = ""
var pending_button: Control = null

var game_screen_node: Control
var focus_bubble_node: Control
var home_menu_node: Control


const CONFIG_FILE = "user://settings.json"
var settings_cache: Dictionary = {}
var is_loading_config: bool = false

func get_menu_id() -> String:
	return "settings"

func get_menu_context() -> GlobalAutoload.Context:
	return GlobalAutoload.Context.SETTINGS

func on_menu_registered():
	initialize_settings()

func initialize_settings():
	if not game_screen_node:
		game_screen_node = get_node_or_null("/root/main/Menus/game_screen")
	
	if not home_menu_node:
		home_menu_node = get_node_or_null("/root/main/Menus/home_menu")
		
	# focus_bubble_node is initialized in _ready now
	# if not focus_bubble_node:
	# 	var home_grid = get_node_or_null("/root/main/home/home_icons_grid")
	# 	if home_grid:
	# 		focus_bubble_node = home_grid.get_node_or_null("focus_bubble")

	_ensure_default_keybinds()
	_load_config()

var core_file_dialog: FileDialog = null
var folder_dialog: FileDialog = null
var pending_core_id: String = ""
var pending_core_path: String = ""

func on_open():
	if Engine.is_editor_hint(): return
	
	reset_menu_state()
	_update_layout()
	_update_focus()
	
	is_active = false
	get_tree().create_timer(INPUT_DELAY).timeout.connect(func(): is_active = true)

func _unhandled_input(event):
	if is_waiting_for_input:
		if event.is_pressed() and not event.is_echo():
			_handle_input_capture(event)
			get_viewport().set_input_as_handled()
		return
		
	super._unhandled_input(event)

func handle_back():
	if is_waiting_for_input:
		return

	if current_subsubmenu_id != "":
		if SFX: SFX.play_back()
		_back_to_submenu()
	elif current_submenu_index >= 0:
		if SFX: SFX.play_back()
		_back_to_main_menu()
	else:
		pass

func on_input(event: InputEvent):
	if is_waiting_for_input:
		_handle_input_capture(event)
		return
	
	if Engine.is_editor_hint(): return
	
	if current_subsubmenu_id != "":
		_handle_subsubmenu_input(event)
	elif current_submenu_index >= 0:
		_handle_submenu_input(event)
	else:
		_handle_main_menu_input(event)

@export_group("Option 1")
@export var option1_enabled: bool = true:
	set(value):
		option1_enabled = value
		_update_options()
@export var option1_active: bool = true:
	set(value):
		option1_active = value
		_update_option(0)
@export var option1_title: String = "Controls":
	set(value):
		option1_title = value
		_update_option(0)
@export var option1_icon: Texture2D:
	set(value):
		option1_icon = value
		_update_option(0)
@export var option1_show_label: bool = true:
	set(value):
		option1_show_label = value
		_update_option(0)

@export_group("Option 2")
@export var option2_enabled: bool = true:
	set(value):
		option2_enabled = value
		_update_options()
@export var option2_active: bool = true:
	set(value):
		option2_active = value
		_update_option(1)
@export var option2_title: String = "Video":
	set(value):
		option2_title = value
		_update_option(1)
@export var option2_icon: Texture2D:
	set(value):
		option2_icon = value
		_update_option(1)
@export var option2_show_label: bool = true:
	set(value):
		option2_show_label = value
		_update_option(1)

@export_group("Option 3")
@export var option3_enabled: bool = true:
	set(value):
		option3_enabled = value
		_update_options()
@export var option3_active: bool = true:
	set(value):
		option3_active = value
		_update_option(2)
@export var option3_title: String = "Audio":
	set(value):
		option3_title = value
		_update_option(2)
@export var option3_icon: Texture2D:
	set(value):
		option3_icon = value
		_update_option(2)
@export var option3_show_label: bool = true:
	set(value):
		option3_show_label = value
		_update_option(2)

@export_group("Option 4")
@export var option4_enabled: bool = true:
	set(value):
		option4_enabled = value
		_update_options()
@export var option4_active: bool = true:
	set(value):
		option4_active = value
		_update_option(3)
@export var option4_title: String = "Interface":
	set(value):
		option4_title = value
		_update_option(3)
@export var option4_icon: Texture2D:
	set(value):
		option4_icon = value
		_update_option(3)
@export var option4_show_label: bool = true:
	set(value):
		option4_show_label = value
		_update_option(3)

@export_group("Option 5")
@export var option5_enabled: bool = true:
	set(value):
		option5_enabled = value
		_update_options()
@export var option5_active: bool = true:
	set(value):
		option5_active = value
		_update_option(4)
@export var option5_title: String = "Emulation":
	set(value):
		option5_title = value
		_update_option(4)
@export var option5_icon: Texture2D:
	set(value):
		option5_icon = value
		_update_option(4)
@export var option5_show_label: bool = true:
	set(value):
		option5_show_label = value
		_update_option(4)

@export_group("Option 6")
@export var option6_enabled: bool = false:
	set(value):
		option6_enabled = value
		_update_options()
@export var option6_active: bool = true:
	set(value):
		option6_active = value
		_update_option(5)
@export var option6_title: String = "Network":
	set(value):
		option6_title = value
		_update_option(5)
@export var option6_icon: Texture2D:
	set(value):
		option6_icon = value
		_update_option(5)
@export var option6_show_label: bool = true:
	set(value):
		option6_show_label = value
		_update_option(5)

@export_group("Option 7")
@export var option7_enabled: bool = false:
	set(value):
		option7_enabled = value
		_update_options()
@export var option7_active: bool = true:
	set(value):
		option7_active = value
		_update_option(6)
@export var option7_title: String = "Privacy":
	set(value):
		option7_title = value
		_update_option(6)
@export var option7_icon: Texture2D:
	set(value):
		option7_icon = value
		_update_option(6)
@export var option7_show_label: bool = true:
	set(value):
		option7_show_label = value
		_update_option(6)

@export_group("Option 8")
@export var option8_enabled: bool = false:
	set(value):
		option8_enabled = value
		_update_options()
@export var option8_active: bool = true:
	set(value):
		option8_active = value
		_update_option(7)
@export var option8_title: String = "About":
	set(value):
		option8_title = value
		_update_option(7)
@export var option8_icon: Texture2D:
	set(value):
		option8_icon = value
		_update_option(7)
@export var option8_show_label: bool = true:
	set(value):
		option8_show_label = value
		_update_option(7)

@export_group("Layout")
@export var spacing: int = 20:
	set(value):
		spacing = value
		_update_layout()

@export_group("Navigation")
@export var columns_for_navigation: int = 4

@export_group("Containers")
@export var options_container: HFlowContainer
@export var submenu_container: VBoxContainer
@export var sub_menu_scroll: ScrollContainer
@export var menu_tittle_label: Label

@export_group("Menus")
@export var keybind_menu: Control

var available_resolutions = ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
var available_fps = [30, 60, 90, 120]
var available_stretch_modes = ["Small", "Large", "Fill", "Proportional"]
var available_texture_filters = ["Inherit", "Nearest Mipmap", "Linear Mipmap"]
var available_auto_save_intervals = ["Off", "1 min", "5 mins", "10 mins", "30 mins"]
var available_controller_layouts = ["Xbox", "PlayStation"]

var controls_submenus = {
	"snes": {
		"label": "SNES Controls",
		"actions": [
			{"action": "snes_up", "label": "Up"},
			{"action": "snes_down", "label": "Down"},
			{"action": "snes_left", "label": "Left"},
			{"action": "snes_right", "label": "Right"},
			{"action": "snes_a", "label": "A"},
			{"action": "snes_b", "label": "B"},
			{"action": "snes_x", "label": "X"},
			{"action": "snes_y", "label": "Y"},
			{"action": "snes_l", "label": "L"},
			{"action": "snes_r", "label": "R"},
			{"action": "snes_start", "label": "Start"},
			{"action": "snes_select", "label": "Select"}
		]
	},
	"gba": {
		"label": "GBA Controls",
		"actions": [
			{"action": "gba_up", "label": "Up"},
			{"action": "gba_down", "label": "Down"},
			{"action": "gba_left", "label": "Left"},
			{"action": "gba_right", "label": "Right"},
			{"action": "gba_a", "label": "A"},
			{"action": "gba_b", "label": "B"},
			{"action": "gba_l", "label": "L"},
			{"action": "gba_r", "label": "R"},
			{"action": "gba_start", "label": "Start"},
			{"action": "gba_select", "label": "Select"}
		]
	},
	"focus_bubble_settings": {
		"label": "Focus Bubble",
		"items": [
			{"type": 0, "label": "Enabled", "setting": "focus_bubble"},
			{"type": 2, "label": "Show Delay", "setting": "bubble_delay", "slider_min": 0.0, "slider_max": 1.0, "slider_step": 0.05},
			{"type": 2, "label": "Auto-Hide Delay", "setting": "bubble_autohide", "slider_min": 0.0, "slider_max": 5.0, "slider_step": 0.1}
		]
	},
	"controller_layout": {
		"label": "Controller Layout",
		"items": [
			{"type": 4, "label": "Xbox", "action": "set_layout_xbox"},
			{"type": 4, "label": "PlayStation", "action": "set_layout_ps"}
		]
	},
	"emulator_gba": {
		"label": "GBA Video Settings",
		"emulator_id": "gba",
		"items": [
			{"type": 5, "label": "Stretch Mode", "setting": "stretch_mode", "options": "stretch_modes", "category": "video"},
			{"type": 5, "label": "Texture Filter", "setting": "texture_filter", "options": "texture_filters", "category": "video"}
		]
	},
	"emulator_snes": {
		"label": "SNES Video Settings",
		"emulator_id": "snes",
		"items": [
			{"type": 5, "label": "Stretch Mode", "setting": "stretch_mode", "options": "stretch_modes", "category": "video"},
			{"type": 5, "label": "Texture Filter", "setting": "texture_filter", "options": "texture_filters", "category": "video"}
		]
	},
	"home_menu_settings": {
		"label": "Home Menu",
		"items": [
			{"type": 2, "label": "Scale Focused", "setting": "hm_scale_focused", "slider_min": 1.0, "slider_max": 2.0, "slider_step": 0.05},
			{"type": 2, "label": "Scale Normal", "setting": "hm_scale_normal", "slider_min": 0.5, "slider_max": 1.5, "slider_step": 0.05},
			{"type": 2, "label": "Lift Amount", "setting": "hm_lift_amount", "slider_min": -100.0, "slider_max": 0.0, "slider_step": 5.0},
			{"type": 2, "label": "Animation Speed", "setting": "hm_anim_duration", "slider_min": 0.05, "slider_max": 0.5, "slider_step": 0.01},
			{"type": 2, "label": "Bounce Scale", "setting": "hm_bounce_scale", "slider_min": 1.0, "slider_max": 1.5, "slider_step": 0.02},
			{"type": 2, "label": "Input Delay", "setting": "hm_input_delay", "slider_min": 0.0, "slider_max": 0.5, "slider_step": 0.05},
			{"type": 0, "label": "Reset Focus on Open", "setting": "home_menu_reset"}
		]
	}
}

var submenu_data = {
	0: [],
	1: [],
	2: [
		{"type": 2, "label": "Emulator Volume", "setting": "emu_volume", "slider_min": 0.0, "slider_max": 100.0},
		{"type": 2, "label": "SFX Volume", "setting": "sfx_volume", "slider_min": 0.0, "slider_max": 100.0}
	],
	3: [
		{"type": 3, "label": "Controller Layout", "submenu_id": "controller_layout"},
		{"type": 3, "label": "Home Menu", "submenu_id": "home_menu_settings"},
		{"type": 3, "label": "Focus Bubble", "submenu_id": "focus_bubble_settings"},
		{"type": 0, "label": "Show Debug Console", "setting": "debug_console"}
	],
	4: [],
	5: [],
	6: [],
	7: []
}

func _ready():
	# forcing vsync off on android for better performance
	if OS.get_name() == "Android":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("settings: android detected, forcing vsync off")
		
	super._ready()
	
	_ensure_options()
	_update_layout()
	_update_focus()
	
	if not Engine.is_editor_hint():
		_ensure_default_keybinds()
		_setup_core_file_dialog()

func reset_menu_state():
	current_subsubmenu_id = ""
	current_subsubmenu_focus = 0
	current_submenu_index = -1
	current_submenu_focus = 0
	subsubmenu_buttons.clear()
	submenu_buttons.clear()
	
	if submenu_container:
		for child in submenu_container.get_children():
			child.queue_free()
		submenu_container.visible = false
	
	if options_container:
		options_container.visible = true
	
	_update_menu_tittle()
	_update_focus()

func _handle_main_menu_input(event: InputEvent):
	if event.is_action_pressed("UI_RIGHT"):
		_navigate(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_LEFT"):
		_navigate(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_DOWN"):
		_navigate(columns_for_navigation)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_UP"):
		_navigate(-columns_for_navigation)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_SELECT"):
		if SFX: SFX.play_select()
		_select_current_option()
		get_viewport().set_input_as_handled()

func _handle_submenu_input(event: InputEvent):
	if event.is_action_pressed("UI_DOWN"):
		_navigate_submenu(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_UP"):
		_navigate_submenu(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_LEFT"):
		_adjust_submenu_value(-0.1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_RIGHT"):
		_adjust_submenu_value(0.1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_SELECT"):
		if SFX: SFX.play_select()
		_select_submenu_item()
		get_viewport().set_input_as_handled()

func _handle_subsubmenu_input(event: InputEvent):
	if event.is_action_pressed("UI_DOWN"):
		_navigate_subsubmenu(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_UP"):
		_navigate_subsubmenu(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_LEFT"):
		_adjust_subsubmenu_value(-0.1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_RIGHT"):
		_adjust_subsubmenu_value(0.1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("UI_SELECT"):
		if SFX: SFX.play_select()
		_select_subsubmenu_item()
		get_viewport().set_input_as_handled()

func _navigate(direction: int):
	var visible_indices = _get_visible_option_indices()
	
	if visible_indices.is_empty():
		return
	
	if SFX:
		SFX.play_nav()
	
	var current_position = visible_indices.find(current_focus_index)
	
	if current_position == -1:
		current_focus_index = visible_indices[0]
	else:
		var new_position = clamp(current_position + direction, 0, visible_indices.size() - 1)
		current_focus_index = visible_indices[new_position]
	
	_update_focus()

func _get_visible_option_indices() -> Array:
	var indices = []
	
	for i in range(8):
		var enabled_prop = "option" + str(i + 1) + "_enabled"
		var active_prop = "option" + str(i + 1) + "_active"
		
		if get(enabled_prop) and get(active_prop):
			indices.append(i)
	
	return indices

func _update_focus():
	for i in range(option_instances.size()):
		var option = option_instances[i]
		if not option:
			continue
		
		var focus_panel = option.get_node_or_null("style/focus")
		if focus_panel:
			focus_panel.visible = (i == current_focus_index)

func _select_current_option():
	var enabled_prop = "option" + str(current_focus_index + 1) + "_enabled"
	var active_prop = "option" + str(current_focus_index + 1) + "_active"
	
	if not get(enabled_prop) or not get(active_prop):
		return
	
	_show_submenu(current_focus_index)

func _show_submenu(submenu_index: int):
	if not submenu_data.has(submenu_index):
		return
	
	current_submenu_index = submenu_index
	
	if options_container:
		options_container.visible = false
	
	if submenu_container:
		for child in submenu_container.get_children():
			child.queue_free()
		
		submenu_buttons.clear()
		
		submenu_container.visible = true
		
		var submenu_items = submenu_data[submenu_index].duplicate()
		
		if submenu_index == 0:
			_build_controls_submenu(submenu_items)
		elif submenu_index == 1:
			_build_video_submenu(submenu_items)
		elif submenu_index == 4:
			_build_emulation_submenu(submenu_items)
		else:
			_build_standard_submenu(submenu_items)
		
		for item_data in submenu_items:
			var button = SETTINGS_BUTTONS.instantiate()
			submenu_container.add_child(button)
			submenu_buttons.append(button)
			
			button.button_type = item_data["type"]
			button.label_text = item_data["label"]
			
			if item_data["type"] == 2:
				if item_data.has("slider_min"):
					button.slider_min = item_data["slider_min"]
				if item_data.has("slider_max"):
					button.slider_max = item_data["slider_max"]
				if item_data.has("slider_step"):
					button.slider_step = item_data["slider_step"]
				button.slider_value = 0.5
			elif item_data["type"] == 3:
				if item_data.has("submenu_id"):
					button.submenu_id = item_data["submenu_id"]
			elif item_data["type"] == 5:
				if item_data.has("options"):
					var options_key = item_data["options"]
					if options_key == "resolutions":
						button.selector_options = available_resolutions.duplicate()
						var current_res = _get_current_resolution_string()
						var res_index = available_resolutions.find(current_res)
						button.selector_index = res_index if res_index >= 0 else 3
					elif options_key == "fps":
						button.selector_options = available_fps.duplicate()
						var fps_index = available_fps.find(Engine.max_fps)
						button.selector_index = fps_index if fps_index >= 0 else 1
					elif options_key == "stretch_modes":
						button.selector_options = available_stretch_modes.duplicate()
						button.selector_index = 2
					elif options_key == "texture_filters":
						button.selector_options = available_texture_filters.duplicate()
						button.selector_index = 0
					elif options_key == "auto_save_intervals":
						button.selector_options = available_auto_save_intervals.duplicate()
						button.selector_index = 2
					elif options_key == "controller_layouts":
						button.selector_options = available_controller_layouts.duplicate()
						var current_layout = settings_cache.get("controller_layout", 0)
						button.selector_index = current_layout if typeof(current_layout) == TYPE_INT else 0
					button.call("_update_selector")
			
			if item_data.has("setting"):
				button.set_meta("setting", item_data["setting"])
				_load_setting_value(button, item_data["setting"])
			
			if item_data.has("action"):
				button.set_meta("action", item_data["action"])
		
		current_submenu_focus = 0
		
		for i in range(submenu_buttons.size()):
			if submenu_buttons[i].button_type != 6:
				current_submenu_focus = i
				break
		
		_update_submenu_focus()
		_update_menu_tittle()
		
		GlobalAutoload.set_context(GlobalAutoload.Context.SUBMENU)

func _build_controls_submenu(submenu_items: Array):
	var cores = EmulatorConfig.get_all_cores().keys()
	for core_id in cores:
		_ensure_core_settings_exist(core_id)
		submenu_items.append({"type": 3, "label": core_id.capitalize(), "submenu_id": core_id})

func _build_video_submenu(submenu_items: Array):
	if OS.get_name() != "Android":
		submenu_items.append({"type": 0, "label": "Fullscreen", "setting": "fullscreen"})
		submenu_items.append({"type": 0, "label": "VSync", "setting": "vsync"})
	submenu_items.append({"type": 5, "label": "FPS Limit", "setting": "fps_limit", "options": "fps"})
	submenu_items.append({"type": 6, "label": ""})
	
	var cores = EmulatorConfig.get_all_cores().keys()
	for core_id in cores:
		_ensure_core_settings_exist(core_id)
		submenu_items.append({"type": 3, "label": core_id.capitalize(), "submenu_id": "emulator_" + core_id})

func _ensure_core_settings_exist(core_id: String):
	if not controls_submenus.has(core_id):
		controls_submenus[core_id] = {
			"label": core_id.capitalize() + " Controls",
			"actions": [
				{"action": core_id + "_up", "label": "Up"},
				{"action": core_id + "_down", "label": "Down"},
				{"action": core_id + "_left", "label": "Left"},
				{"action": core_id + "_right", "label": "Right"},
				{"action": core_id + "_a", "label": "A"},
				{"action": core_id + "_b", "label": "B"},
				{"action": core_id + "_x", "label": "X"},
				{"action": core_id + "_y", "label": "Y"},
				{"action": core_id + "_l", "label": "L"},
				{"action": core_id + "_r", "label": "R"},
				{"action": core_id + "_l2", "label": "L2"},
				{"action": core_id + "_r2", "label": "R2"},
				{"action": core_id + "_l3", "label": "L3"},
				{"action": core_id + "_r3", "label": "R3"},
				{"action": core_id + "_start", "label": "Start"},
				{"action": core_id + "_select", "label": "Select"}
			]
		}
		
		for action_item in controls_submenus[core_id]["actions"]:
			var action = action_item["action"]
			if not InputMap.has_action(action):
				InputMap.add_action(action)
	
	if not controls_submenus.has("emulator_" + core_id):
		controls_submenus["emulator_" + core_id] = {
			"label": core_id.capitalize() + " Video Settings",
			"emulator_id": core_id,
			"items": [
				{"type": 5, "label": "Stretch Mode", "setting": "stretch_mode", "options": "stretch_modes", "category": "video"},
				{"type": 5, "label": "Texture Filter", "setting": "texture_filter", "options": "texture_filters", "category": "video"}
			]
		}

func _build_emulation_submenu(submenu_items: Array):
	submenu_items.append({"type": 1, "label": "Import Core Manually", "action": "import_core"})
	submenu_items.append({"type": 6, "label": ""})
	
	submenu_items.append({"type": 2, "label": "Max Auto-Saves", "setting": "max_save_states", "slider_min": 1.0, "slider_max": 20.0, "slider_step": 1.0})
	submenu_items.append({"type": 5, "label": "Auto-Save Interval", "setting": "auto_save_interval", "options": "auto_save_intervals"})
	submenu_items.append({"type": 6, "label": ""})
	
	
	var cores = EmulatorConfig.get_all_cores()
	for core_id in cores.keys():
		submenu_items.append({"type": 3, "label": core_id.capitalize(), "submenu_id": "core_" + core_id})
		
		controls_submenus["core_" + core_id] = {
			"label": core_id.capitalize() + " Settings",
			"core_id": core_id,
			"items": [
				{"type": 4, "label": "Folder Location", "action": "set_folder", "core_id": core_id},
				{"type": 1, "label": "Delete Core", "action": "delete_core", "core_id": core_id}
			]
		}
	
	_build_standard_submenu(submenu_items)

func _build_standard_submenu(_submenu_items: Array):
	pass

func _navigate_submenu(direction: int):
	if submenu_buttons.is_empty():
		return
	
	if SFX:
		SFX.play_nav()
	
	var new_focus = current_submenu_focus
	
	for _i in range(submenu_buttons.size()):
		new_focus = clamp(new_focus + direction, 0, submenu_buttons.size() - 1)
		
		if new_focus < submenu_buttons.size() and submenu_buttons[new_focus].button_type != 6:
			current_submenu_focus = new_focus
			_update_submenu_focus()
			return
	
	_update_submenu_focus()

func _update_submenu_focus():
	for i in range(submenu_buttons.size()):
		var button = submenu_buttons[i]
		if not button:
			continue
		
		var focus_panel = button.get_node_or_null("style/focus")
		if focus_panel:
			focus_panel.visible = (i == current_submenu_focus)
	
	if current_submenu_focus >= 0 and current_submenu_focus < submenu_buttons.size():
		_scroll_to_focused(submenu_buttons[current_submenu_focus])

func _adjust_submenu_value(amount: float):
	if current_submenu_focus >= submenu_buttons.size():
		return
	
	var button = submenu_buttons[current_submenu_focus]
	if not button:
		return
	
	if button.button_type == 2:
		button.slider_value = clamp(button.slider_value + amount, 0.0, 1.0)
		button.call("_update_slider")
		
		if button.has_meta("setting"):
			_apply_setting(button.get_meta("setting"), button.slider_value)
	elif button.button_type == 5:
		if amount > 0:
			button.selector_next()
		else:
			button.selector_prev()
		
		if button.has_meta("setting"):
			_apply_setting(button.get_meta("setting"), button.get_value())

func _select_submenu_item():
	if current_submenu_focus >= submenu_buttons.size():
		return
	
	var button = submenu_buttons[current_submenu_focus]
	if not button:
		return
	
	if button.button_type == 0:
		button.checkbox_value = !button.checkbox_value
		button.call("_update_checkbox")
		
		if button.has_meta("setting"):
			_apply_setting(button.get_meta("setting"), button.checkbox_value)
	elif button.button_type == 1:
		if button.has_meta("action"):
			_handle_action(button.get_meta("action"))
	elif button.button_type == 3:
		if button.submenu_id != "":
			_show_subsubmenu(button.submenu_id)

func _back_to_main_menu():
	reset_menu_state()
	GlobalAutoload.set_context(GlobalAutoload.Context.SETTINGS)

func _update_menu_tittle():
	if not menu_tittle_label:
		return
	
	if current_subsubmenu_id != "":
		if controls_submenus.has(current_subsubmenu_id):
			menu_tittle_label.text = controls_submenus[current_subsubmenu_id]["label"]
		else:
			menu_tittle_label.text = current_subsubmenu_id
	elif current_submenu_index >= 0:
		var title_prop = "option" + str(current_submenu_index + 1) + "_title"
		menu_tittle_label.text = get(title_prop)
	else:
		menu_tittle_label.text = "Settings"

func _ensure_options():
	if not options_container:
		return
	
	var existing_count = 0
	for child in options_container.get_children():
		if child.get_script() == preload("res://src/components/settings_option.gd"):
			option_instances.append(child)
			existing_count += 1
	
	for i in range(existing_count, 8):
		var option = SETTINGS_OPTION.instantiate()
		option_instances.append(option)
		options_container.add_child(option)
		
		if Engine.is_editor_hint():
			option.set_owner(get_tree().edited_scene_root)
	
	_apply_all_option_properties()

func _apply_all_option_properties():
	for i in range(8):
		var enabled = get("option" + str(i + 1) + "_enabled")
		var active = get("option" + str(i + 1) + "_active")
		var title = get("option" + str(i + 1) + "_title")
		var icon = get("option" + str(i + 1) + "_icon")
		var show_label = get("option" + str(i + 1) + "_show_label")
		
		_apply_option_properties(i, enabled, active, title, icon, show_label)

func _apply_option_properties(index: int, enabled: bool, active: bool, title: String, icon: Texture2D, show_label: bool):
	if index >= option_instances.size():
		return
	
	var option = option_instances[index]
	if not option:
		return
	
	option.visible = enabled
	option.call("update_title", title, show_label)
	option.call("update_icon", icon)
	option.call("set_active", active)

func _update_option(index: int):
	_ensure_options()
	
	if index >= option_instances.size():
		return
	
	var enabled = get("option" + str(index + 1) + "_enabled")
	var active = get("option" + str(index + 1) + "_active")
	var title = get("option" + str(index + 1) + "_title")
	var icon = get("option" + str(index + 1) + "_icon")
	var show_label = get("option" + str(index + 1) + "_show_label")
	
	_apply_option_properties(index, enabled, active, title, icon, show_label)

func _update_options():
	_ensure_options()

func _update_layout():
	if not options_container:
		return
	
	options_container.add_theme_constant_override("h_separation", spacing)
	options_container.add_theme_constant_override("v_separation", spacing)

func _show_subsubmenu(submenu_id: String):
	if not controls_submenus.has(submenu_id):
		return
	
	current_subsubmenu_id = submenu_id
	
	if submenu_container:
		for child in submenu_container.get_children():
			child.queue_free()
		
		subsubmenu_buttons.clear()
		
		var submenu_data_entry = controls_submenus[submenu_id]
		var emulator_id = submenu_data_entry.get("emulator_id", "")
		
		if submenu_data_entry.has("items"):
			var items = submenu_data_entry["items"]
			
			for item_data in items:
				var button = SETTINGS_BUTTONS.instantiate()
				submenu_container.add_child(button)
				subsubmenu_buttons.append(button)
				
				button.button_type = item_data["type"]
				button.label_text = item_data["label"]
				
				if item_data.has("slider_min"):
					button.slider_min = item_data["slider_min"]
					button.slider_max = item_data["slider_max"]
					button.slider_step = item_data.get("slider_step", 1.0)
				
				if item_data.has("options"):
					var options_key = item_data["options"]
					if options_key == "stretch_modes":
						button.selector_options = available_stretch_modes.duplicate()
						if emulator_id != "":
							var saved_mode = EmulatorConfig.get_emulator_setting(emulator_id, "video", "stretch_mode", 2)
							button.selector_index = saved_mode
						else:
							button.selector_index = 2
					elif options_key == "texture_filters":
						button.selector_options = available_texture_filters.duplicate()
						if emulator_id != "":
							var saved_filter = EmulatorConfig.get_emulator_setting(emulator_id, "video", "texture_filter", 0)
							button.selector_index = saved_filter
						else:
							button.selector_index = 0
					button.call("_update_selector")
				
				if item_data.has("setting"):
					button.set_meta("setting", item_data["setting"])
					if emulator_id != "":
						button.set_meta("emulator_id", emulator_id)
						button.set_meta("category", item_data.get("category", ""))
					else:
						_load_setting_value(button, item_data["setting"])
				
				if item_data.has("action"):
					button.set_meta("action", item_data["action"])
					
					if item_data["action"] == "set_layout_xbox":
						var current_layout = settings_cache.get("controller_layout", 0)
						if current_layout == 0:
							button.set_value_text("Active")
						else:
							button.set_value_text("")
					elif item_data["action"] == "set_layout_ps":
						var current_layout = settings_cache.get("controller_layout", 0)
						if current_layout == 1:
							button.set_value_text("Active")
						else:
							button.set_value_text("")
					elif item_data["action"] == "set_folder" and item_data.has("core_id"):
						var current_folder = EmulatorConfig.get_core_rooms_folder(item_data["core_id"])
						if current_folder != "":
							button.set_value_text(current_folder)
						else:
							button.set_value_text("---")
				
				if item_data.has("core_id"):
					button.set_meta("core_id", item_data["core_id"])
				
		elif submenu_data_entry.has("actions"):
			var actions = submenu_data_entry["actions"]
			
			for action_data in actions:
				var button = SETTINGS_BUTTONS.instantiate()
				submenu_container.add_child(button)
				subsubmenu_buttons.append(button)
				
				button.button_type = 4
				button.label_text = action_data["label"]
				button.action_name = action_data["action"]
				button.keybind_text = _get_current_keybind(action_data["action"])
		
		current_subsubmenu_focus = 0
		_update_subsubmenu_focus()
		_update_menu_tittle()

func _navigate_subsubmenu(direction: int):
	if subsubmenu_buttons.is_empty():
		return
	
	if SFX:
		SFX.play_nav()
	
	current_subsubmenu_focus = clamp(current_subsubmenu_focus + direction, 0, subsubmenu_buttons.size() - 1)
	_update_subsubmenu_focus()

func _update_subsubmenu_focus():
	for i in range(subsubmenu_buttons.size()):
		var button = subsubmenu_buttons[i]
		if not button:
			continue
		
		var focus_panel = button.get_node_or_null("style/focus")
		if focus_panel:
			focus_panel.visible = (i == current_subsubmenu_focus)
	
	if current_subsubmenu_focus >= 0 and current_subsubmenu_focus < subsubmenu_buttons.size():
		_scroll_to_focused(subsubmenu_buttons[current_subsubmenu_focus])

func _scroll_to_focused(button: Control):
	if not sub_menu_scroll or not button:
		return
	var scroll_position = button.position.y - (sub_menu_scroll.size.y / 2) + (button.size.y / 2)
	scroll_position = clamp(scroll_position, 0, submenu_container.size.y - sub_menu_scroll.size.y)
	var tween = create_tween()
	tween.tween_property(sub_menu_scroll, "scroll_vertical", int(scroll_position), 0.15)

func _adjust_subsubmenu_value(amount: float):
	if current_subsubmenu_focus >= subsubmenu_buttons.size():
		return
	
	var button = subsubmenu_buttons[current_subsubmenu_focus]
	if not button:
		return
	
	if button.button_type == 2:
		button.slider_value = clamp(button.slider_value + amount, 0.0, 1.0)
		button.call("_update_slider")
		
		if button.has_meta("setting"):
			if button.has_meta("emulator_id"):
				EmulatorConfig.update_emulator_setting(button.get_meta("emulator_id"), button.get_meta("category"), button.get_meta("setting"), button.slider_value)
			else:
				_apply_setting(button.get_meta("setting"), button.slider_value)
	elif button.button_type == 5:
		if amount > 0:
			button.selector_next()
		else:
			button.selector_prev()
		
		if button.has_meta("setting"):
			if button.has_meta("emulator_id"):
				EmulatorConfig.update_emulator_setting(button.get_meta("emulator_id"), button.get_meta("category"), button.get_meta("setting"), button.selector_index)
			else:
				_apply_setting(button.get_meta("setting"), button.get_value())

func _select_subsubmenu_item():
	if current_subsubmenu_focus >= subsubmenu_buttons.size():
		return
	
	var button = subsubmenu_buttons[current_subsubmenu_focus]
	if not button:
		return
	
	if button.button_type == 4:
		if button.has_meta("action"):
			_handle_action(button.get_meta("action"))
		elif "action_name" in button and button.action_name != "":
			_start_input_capture(button, button.action_name)
	elif button.button_type == 1:
		if button.has_meta("action"):
			_handle_action(button.get_meta("action"))
	elif button.button_type == 0:
		button.checkbox_value = !button.checkbox_value
		button.call("_update_checkbox")
		if button.has_meta("setting"):
			_apply_setting(button.get_meta("setting"), button.checkbox_value)

func _back_to_submenu():
	current_subsubmenu_id = ""
	current_subsubmenu_focus = 0
	
	if submenu_container:
		for child in submenu_container.get_children():
			child.queue_free()
		subsubmenu_buttons.clear()
	
	_show_submenu(current_submenu_index)

func _get_current_keybind(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "---"
	
	var events = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "---"
	
	return _get_event_name(events[0])

func _get_event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.keycode)
	elif event is InputEventJoypadButton:
		return "Button " + str(event.button_index)
	elif event is InputEventJoypadMotion:
		return "Axis " + str(event.axis)
	return "???"

func _get_current_resolution_string() -> String:
	var window_size = DisplayServer.window_get_size()
	return str(window_size.x) + "x" + str(window_size.y)

func _load_setting_value(button: Control, setting: String):
	match setting:
		"fullscreen":
			var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			button.checkbox_value = is_fullscreen
			button.call("_update_checkbox")
		"vsync":
			var vsync_mode = DisplayServer.window_get_vsync_mode()
			button.checkbox_value = vsync_mode != DisplayServer.VSYNC_DISABLED
			button.call("_update_checkbox")
		"emu_volume":
			if settings_cache.has("emu_volume"):
				button.slider_value = settings_cache["emu_volume"]
			elif game_screen_node and game_screen_node.get("audio"):
				var audio = game_screen_node.audio
				var db = audio.volume_db
				var linear = db_to_linear(db)
				button.slider_value = linear
				button.call("_update_slider")
		"focus_bubble":
			if focus_bubble_node:
				button.checkbox_value = focus_bubble_node.bubble_enabled
				button.call("_update_checkbox")
		"bubble_delay":
			if focus_bubble_node:
				button.slider_value = clamp(focus_bubble_node.show_delay / 1.0, 0.0, 1.0)
				button.call("_update_slider")
		"bubble_autohide":
			if focus_bubble_node:
				button.slider_value = clamp(focus_bubble_node.auto_hide_delay / 5.0, 0.0, 1.0)
				button.call("_update_slider")
		"home_menu_reset":
			if home_menu_node:
				button.checkbox_value = home_menu_node.reset_focus_on_open
				button.call("_update_checkbox")
		"sfx_volume":
			if SFX:
				var linear = db_to_linear(SFX.master_volume_db)
				button.slider_value = linear
				button.call("_update_slider")
		"hm_scale_focused":
			if home_menu_node:
				button.slider_value = (home_menu_node.scale_focused - 1.0) / 1.0
				button.call("_update_slider")
		"hm_scale_normal":
			if home_menu_node:
				button.slider_value = (home_menu_node.scale_normal - 0.5) / 1.0
				button.call("_update_slider")
		"hm_lift_amount":
			if home_menu_node:
				button.slider_value = (home_menu_node.lift_amount + 100.0) / 100.0
				button.call("_update_slider")
		"hm_anim_duration":
			if home_menu_node:
				button.slider_value = (home_menu_node.anim_duration - 0.05) / 0.45
				button.call("_update_slider")
		"hm_bounce_scale":
			if home_menu_node:
				button.slider_value = (home_menu_node.bounce_scale - 1.0) / 0.5
				button.call("_update_slider")
		"hm_input_delay":
			if home_menu_node:
				button.slider_value = home_menu_node.input_delay / 0.5
				button.call("_update_slider")
		"max_save_states":
			var val = settings_cache.get("max_save_states", 6.0)
			button.slider_value = val 
			button.call("_update_slider")
		"auto_save_interval":
			var val = settings_cache.get("auto_save_interval", 1) 
			button.selector_index = int(val)
			button.call("_update_selector")

func _apply_setting(setting: String, value):
	settings_cache[setting] = value
	if not is_loading_config:
		_save_config()

	match setting:
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			if value:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		"resolution":
			var parts = str(value).split("x")
			if parts.size() == 2:
				var w = int(parts[0])
				var h = int(parts[1])
				DisplayServer.window_set_size(Vector2i(w, h))
				var screen_size = DisplayServer.screen_get_size()
				var pos_x = (screen_size.x - w) / 2
				var pos_y = (screen_size.y - h) / 2
				DisplayServer.window_set_position(Vector2i(pos_x, pos_y))
		"fps_limit":
			Engine.max_fps = int(value)
		"emu_volume":
			if game_screen_node and game_screen_node.get("audio"):
				var audio = game_screen_node.audio
				audio.volume_db = linear_to_db(value)
		"focus_bubble":
			if focus_bubble_node:
				focus_bubble_node.bubble_enabled = value
		"debug_console":
			if DebugCapture:
				DebugCapture.set_visibility(value)
		"bubble_delay":
			if focus_bubble_node:
				focus_bubble_node.show_delay = value * 1.0
		"bubble_autohide":
			if focus_bubble_node:
				focus_bubble_node.auto_hide_delay = value * 5.0
		"home_menu_reset":
			if home_menu_node:
				home_menu_node.reset_focus_on_open = value
		"sfx_volume":
			if SFX:
				var db_value = linear_to_db(value) if value > 0 else -80.0
				SFX.master_volume_db = db_value
		"hm_scale_focused":
			if home_menu_node:
				home_menu_node.scale_focused = 1.0 + (value * 1.0)
		"hm_scale_normal":
			if home_menu_node:
				home_menu_node.scale_normal = 0.5 + (value * 1.0)
		"hm_lift_amount":
			if home_menu_node:
				home_menu_node.lift_amount = -100.0 + (value * 100.0)
		"hm_anim_duration":
			if home_menu_node:
				home_menu_node.anim_duration = 0.05 + (value * 0.45)
		"hm_bounce_scale":
			if home_menu_node:
				home_menu_node.bounce_scale = 1.0 + (value * 0.5)
		"hm_input_delay":
			if home_menu_node:
				home_menu_node.input_delay = value * 0.5
		"controller_layout":
			var manager = get_node_or_null("/root/ButtonLayoutManager")
			if manager:
				var layout_value = int(value) if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) else 0
				manager.current_layout = layout_value
		"max_save_states", "auto_save_interval":
			var manager = get_node_or_null("/root/main/AutoSaveManager")
			if manager and manager.has_method("_update_settings"):
				manager._update_settings()

func _save_config():
	var data = {
		"general": settings_cache,
		"keybinds": _serialize_keybinds()
	}
	print("Settings: Saving config. controller_layout = ", settings_cache.get("controller_layout", "NOT SET"))
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		print("Settings: Config saved to ", CONFIG_FILE)

func _load_config():
	if not FileAccess.file_exists(CONFIG_FILE):
		return
		
	var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if not file: return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.data
		is_loading_config = true
		if data.has("general"):
			var gen = data["general"]
			for key in gen:
				if OS.get_name() == "Android" and key == "vsync":
					_apply_setting(key, false) # Força visual desligado no Android
				else:
					_apply_setting(key, gen[key])
		if data.has("keybinds"):
			_deserialize_keybinds(data["keybinds"])
		is_loading_config = false

func _serialize_keybinds() -> Dictionary:
	var binds = {}
	for category in controls_submenus:
		var entry = controls_submenus[category]
		if entry.has("actions"):
			for action in entry["actions"]:
				var action_name = action["action"]
				if InputMap.has_action(action_name):
					var events = InputMap.action_get_events(action_name)
					var events_list = []
					for event in events:
						var data = _serialize_event(event)
						if not data.is_empty():
							events_list.append(data)
					
					if not events_list.is_empty():
						binds[action_name] = events_list
	return binds

func _serialize_event(event: InputEvent) -> Dictionary:
	var data = {}
	if event is InputEventKey:
		data["type"] = "key"
		data["keycode"] = event.keycode
	elif event is InputEventJoypadButton:
		data["type"] = "joy_btn"
		data["button_index"] = event.button_index
	elif event is InputEventJoypadMotion:
		data["type"] = "joy_axis"
		data["axis"] = event.axis
	return data

func _deserialize_keybinds(binds: Dictionary):
	for action_name in binds:
		var events_data = binds[action_name]
		
		if events_data is Dictionary:
			events_data = [events_data]
			
		if not events_data is Array:
			continue
			
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			
		InputMap.action_erase_events(action_name)
		
		for data in events_data:
			var event = null
			if data["type"] == "key":
				event = InputEventKey.new()
				event.keycode = int(data["keycode"])
			elif data["type"] == "joy_btn":
				event = InputEventJoypadButton.new()
				event.button_index = int(data["button_index"])
			elif data["type"] == "joy_axis":
				event = InputEventJoypadMotion.new()
				event.axis = int(data["axis"])
				
			if event:
				InputMap.action_add_event(action_name, event)

func _ensure_default_keybinds():
	_add_default_action("gba_up", KEY_UP)
	_add_default_action("gba_down", KEY_DOWN)
	_add_default_action("gba_left", KEY_LEFT)
	_add_default_action("gba_right", KEY_RIGHT)
	_add_default_action("gba_a", KEY_Z)
	_add_default_action("gba_b", KEY_X)
	_add_default_action("gba_l", KEY_A)
	_add_default_action("gba_r", KEY_S)
	_add_default_action("gba_start", KEY_ENTER)
	_add_default_action("gba_select", KEY_BACKSPACE)

func _add_default_action(action: String, keycode: int):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	
	if InputMap.action_get_events(action).is_empty():
		var ev = InputEventKey.new()
		ev.keycode = keycode
		InputMap.action_add_event(action, ev)

func _start_input_capture(button: Control, action_name: String):
	is_waiting_for_input = true
	pending_action_name = action_name
	pending_button = button
	
	if button.has_method("set_waiting"):
		button.set_waiting(true)
		
	if keybind_menu:
		keybind_menu.visible = true
		if keybind_menu.has_method("open"):
			keybind_menu.open()

func _cancel_input_capture():
	is_waiting_for_input = false
	if pending_button and pending_button.has_method("set_waiting"):
		pending_button.set_waiting(false)
	pending_button = null
	pending_action_name = ""
	
	if keybind_menu:
		if keybind_menu.has_method("close"):
			keybind_menu.close()
		else:
			keybind_menu.visible = false




func _handle_input_capture(event: InputEvent):
	if not is_waiting_for_input: return
	if event is InputEventMouseMotion: return
	
	if event.is_pressed():
		get_viewport().set_input_as_handled()
		
		InputMap.action_erase_events(pending_action_name)
		InputMap.action_add_event(pending_action_name, event)
		
		_save_config()
		_update_keybind_label(pending_button, pending_action_name)
		
		if SFX: SFX.play_select()
		
		_cancel_input_capture()

func _update_keybind_label(button: Control, action_name: String):
	if not button: return
	var events = InputMap.action_get_events(action_name)
	if not events.is_empty():
		var event = events[0]
		var text = ""
		if event is InputEventKey:
			text = OS.get_keycode_string(event.keycode)
		elif event is InputEventJoypadButton:
			text = "Joy Btn " + str(event.button_index)
		elif event is InputEventJoypadMotion:
			text = "Joy Axis " + str(event.axis)
			
		if button.has_method("set_value_text"):
			button.set_value_text(text)

func _handle_action(action_name: String):
	match action_name:
		"set_layout_xbox":
			_apply_setting("controller_layout", 0)
			if SFX: SFX.play_select()
			_update_controller_layout_indicators()
		"set_layout_ps":
			_apply_setting("controller_layout", 1)
			if SFX: SFX.play_select()
			_update_controller_layout_indicators()
		"import_core":
			_open_import_core_dialog()
		"set_folder":
			if current_subsubmenu_focus >= 0 and current_subsubmenu_focus < subsubmenu_buttons.size():
				var button = subsubmenu_buttons[current_subsubmenu_focus]
				if button.has_meta("core_id"):
					_open_folder_dialog(button.get_meta("core_id"))
		"delete_core":
			if current_subsubmenu_focus >= 0 and current_subsubmenu_focus < subsubmenu_buttons.size():
				var button = subsubmenu_buttons[current_subsubmenu_focus]
				if button.has_meta("core_id"):
					_delete_core(button.get_meta("core_id"))

func _update_controller_layout_indicators():
	var current_layout = settings_cache.get("controller_layout", 0)
	
	for button in subsubmenu_buttons:
		if not button or not button.has_meta("action"):
			continue
		
		var action = button.get_meta("action")
		if action == "set_layout_xbox":
			if current_layout == 0:
				button.set_value_text("Active")
			else:
				button.set_value_text("")
		elif action == "set_layout_ps":
			if current_layout == 1:
				button.set_value_text("Active")
			else:
				button.set_value_text("")

func _setup_core_file_dialog():
	core_file_dialog = FileDialog.new()
	add_child(core_file_dialog)
	
	core_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	core_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	var os_name = OS.get_name()
	var is_android = os_name == "Android"
	var is_mobile = is_android or os_name == "iOS"
	
	if is_android:
		core_file_dialog.use_native_dialog = true
		core_file_dialog.filters = PackedStringArray(["* ; All Files"])
	else:
		core_file_dialog.use_native_dialog = not is_mobile
		match os_name:
			"Windows":
				core_file_dialog.filters = PackedStringArray(["*.dll ; Libretro Core"])
			"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
				core_file_dialog.filters = PackedStringArray(["*.so ; Libretro Core"])
			"macOS":
				core_file_dialog.filters = PackedStringArray(["*.dylib ; Libretro Core"])
			_:
				core_file_dialog.filters = PackedStringArray(["*.dll ; Windows Core", "*.so ; Linux Core", "*.dylib ; MacOS Core"])
	
	core_file_dialog.file_selected.connect(_on_core_file_selected)
	
	folder_dialog = FileDialog.new()
	add_child(folder_dialog)
	
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	if is_android:
		folder_dialog.use_native_dialog = true
	else:
		folder_dialog.use_native_dialog = not is_mobile
	
	folder_dialog.dir_selected.connect(_on_folder_selected)

func _open_import_core_dialog():
	if core_file_dialog:
		core_file_dialog.popup_centered(Vector2i(800, 600))

func _on_core_file_selected(path: String):
	if path.is_empty():
		return
	
	if not FileAccess.file_exists(path):
		var main_ref = get_node_or_null("/root/main")
		if main_ref and main_ref.has_method("show_alert"):
			main_ref.show_alert("Core file not found")
		return
	
	var core_name = path.get_file().get_basename()
	var core_id = core_name.to_lower().replace("_libretro", "").replace("libretro_", "")
	
	EmulatorConfig.set_libretro_core(core_id, path, "")
	
	var main_node = get_node_or_null("/root/main")
	if main_node and main_node.has_method("show_alert"):
		main_node.show_alert("Core imported: " + core_name)
	
	_notify_library_about_new_core(core_id, path)
	
	_show_submenu(4)
	await get_tree().process_frame
	_show_subsubmenu("core_" + core_id)

func _notify_library_about_new_core(core_id: String, core_path: String):
	var rooms_folder = EmulatorConfig.get_core_rooms_folder(core_id)
	var library = get_node_or_null("/root/main/Menus/library")
	if library and library.has_method("add_emulator_from_core"):
		library.add_emulator_from_core(core_id, core_path, rooms_folder)

func _on_folder_selected(dir_path: String):
	if pending_core_id.is_empty():
		return
	
	EmulatorConfig.set_core_rooms_folder(pending_core_id, dir_path)
	
	var library = get_node_or_null("/root/main/Menus/library")
	if library and library.has_method("update_emulator_folder"):
		library.update_emulator_folder(pending_core_id, dir_path)
	
	var main_node = get_node_or_null("/root/main")
	if main_node and main_node.has_method("show_alert"):
		main_node.show_alert("Folder updated for: " + pending_core_id.capitalize())
	
	_update_folder_location_label(dir_path)
	
	pending_core_id = ""
	pending_core_path = ""

func _open_folder_dialog(core_id: String):
	pending_core_id = core_id
	pending_core_path = EmulatorConfig.get_libretro_core(core_id)
	
	var current_folder = EmulatorConfig.get_core_rooms_folder(core_id)
	if current_folder != "" and DirAccess.dir_exists_absolute(current_folder):
		folder_dialog.current_dir = current_folder
	
	if folder_dialog:
		folder_dialog.popup_centered(Vector2i(800, 600))

func _delete_core(core_id: String):
	EmulatorConfig.remove_libretro_core(core_id)
	
	var library = get_node_or_null("/root/main/Menus/library")
	if library and library.has_method("remove_emulator_by_core"):
		library.remove_emulator_by_core(core_id)
	
	var main_node = get_node_or_null("/root/main")
	if main_node and main_node.has_method("show_alert"):
		main_node.show_alert("Core deleted: " + core_id.capitalize())
	
	_back_to_main_menu()

func _update_folder_location_label(new_path: String):
	for i in range(subsubmenu_buttons.size()):
		var button = subsubmenu_buttons[i]
		if button.has_meta("action") and button.get_meta("action") == "set_folder":
			if new_path != "":
				button.set_value_text(new_path)
			else:
				button.set_value_text("---")
			break

extends Control

const CONFIG_PATH: String = "user://settings.cfg"
const STORAGE_ROOT: String = "user://ggg/res/"
const BUILTIN_FONTS_DIR: String = "res://fonts/"
const USER_FONTS_DIR: String = "user://ggg/fonts/"

var config := ConfigFile.new()

var font_size_spin: SpinBox
var font_family_option: OptionButton
var theme_option: OptionButton
var line_numbers_check: CheckButton
var word_wrap_check: CheckButton
var auto_save_check: CheckButton

# Список найденных шрифтов: каждый элемент — {"name": "Имя", "path": "Путь"}
var available_fonts: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Создаём папку для пользовательских шрифтов, если её ещё нет
	DirAccess.make_dir_recursive_absolute(USER_FONTS_DIR)
	
	# Сканируем все доступные шрифты (и встроенные в .exe, и внешние)
	_scan_available_fonts()
	
	_build_ui()
	_load_settings()
	
	font_size_spin.value_changed.connect(func(val): _save_setting("editor", "font_size", int(val)))
	font_family_option.item_selected.connect(_on_font_family_selected)
	theme_option.item_selected.connect(func(idx): _save_setting("editor", "theme", idx))
	line_numbers_check.toggled.connect(func(pressed): _save_setting("editor", "line_numbers", pressed))
	word_wrap_check.toggled.connect(func(pressed): _save_setting("editor", "word_wrap", pressed))
	auto_save_check.toggled.connect(func(pressed): _save_setting("app", "auto_save", pressed))

# Поиск шрифтов, работающий и в редакторе, и в скомпилированном .exe
func _scan_available_fonts() -> void:
	available_fonts.clear()
	# Добавляем стандартный шрифт движка первым пунктом
	available_fonts.append({"name": "Стандартный (По умолчанию)", "path": ""})
	
	# 1. Ищем встроенные шрифты из res://fonts/ (с учётом упаковки в .exe)
	_collect_fonts_from_dir(BUILTIN_FONTS_DIR, true)
	
	# 2. Ищем внешние шрифты, которые пользователь сам положил в папку программы
	_collect_fonts_from_dir(USER_FONTS_DIR, false)

func _collect_fonts_from_dir(dir_path: String, is_builtin: bool) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name = file_name
			# В скомпилированном .exe Godot добавляет .remap к упакованным файлам
			if is_builtin and clean_name.ends_with(".remap"):
				clean_name = clean_name.trim_suffix(".remap")
				
			var ext = clean_name.get_extension().to_lower()
			if ext == "ttf" or ext == "otf":
				var full_path = dir_path.path_join(clean_name)
				# Проверяем, не добавлен ли уже этот файл
				var already_added = false
				for item in available_fonts:
					if item["path"] == full_path:
						already_added = true
						break
				if not already_added:
					available_fonts.append({
						"name": clean_name.get_basename(),
						"path": full_path
					})
		file_name = dir.get_next()
	dir.list_dir_end()

func _apply_button_style(btn: Button) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#e0e0e0")
	normal_style.border_color = Color("#444444")
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(8)
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color.WHITE
	
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color("#cccccc")
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_focus_color", Color.BLACK)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(480, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(box)
	
	var title := Label.new()
	title.text = "Настройки редактора"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.BLACK)
	box.add_child(title)
	
	# 1. Выбор шрифта (выпадающий список всех найденных шрифтов)
	var family_row := HBoxContainer.new()
	family_row.add_theme_constant_override("separation", 12)
	var family_lbl := Label.new()
	family_lbl.text = "Шрифт текста:"
	family_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	family_lbl.add_theme_color_override("font_color", Color.BLACK)
	
	font_family_option = OptionButton.new()
	for i in range(available_fonts.size()):
		font_family_option.add_item(available_fonts[i]["name"], i)
	_apply_button_style(font_family_option)
	
	family_row.add_child(family_lbl)
	family_row.add_child(font_family_option)
	box.add_child(family_row)
	
	# 2. Размер шрифта
	var font_row := HBoxContainer.new()
	font_row.add_theme_constant_override("separation", 12)
	var font_lbl := Label.new()
	font_lbl.text = "Размер шрифта:"
	font_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	font_lbl.add_theme_color_override("font_color", Color.BLACK)
	
	font_size_spin = SpinBox.new()
	font_size_spin.min_value = 10
	font_size_spin.max_value = 40
	font_size_spin.value = 16
	var spin_line := font_size_spin.get_line_edit()
	var spin_bg := StyleBoxFlat.new()
	spin_bg.bg_color = Color("#e0e0e0")
	spin_bg.set_corner_radius_all(4)
	spin_line.add_theme_stylebox_override("normal", spin_bg)
	spin_line.add_theme_color_override("font_color", Color.BLACK)
	
	font_row.add_child(font_lbl)
	font_row.add_child(font_size_spin)
	box.add_child(font_row)
	
	# 3. Тема редактора
	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 12)
	var theme_lbl := Label.new()
	theme_lbl.text = "Тема редактора:"
	theme_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_lbl.add_theme_color_override("font_color", Color.BLACK)
	
	theme_option = OptionButton.new()
	theme_option.add_item("Светлая (Белый лист)", 0)
	theme_option.add_item("Тёмная (Ночная)", 1)
	theme_option.add_item("Сепия (Тёплая бумага)", 2)
	_apply_button_style(theme_option)
	
	theme_row.add_child(theme_lbl)
	theme_row.add_child(theme_option)
	box.add_child(theme_row)
	
	# 4. Переключатели
	line_numbers_check = CheckButton.new()
	line_numbers_check.text = "Показывать номера строк"
	_apply_button_style(line_numbers_check)
	box.add_child(line_numbers_check)
	
	word_wrap_check = CheckButton.new()
	word_wrap_check.text = "Перенос длинных строк"
	_apply_button_style(word_wrap_check)
	box.add_child(word_wrap_check)
	
	auto_save_check = CheckButton.new()
	auto_save_check.text = "Автосохранение при переключении вкладок"
	_apply_button_style(auto_save_check)
	box.add_child(auto_save_check)
	
	# 5. Кнопки папок и возврата
	var open_folder_btn := Button.new()
	open_folder_btn.text = "Открыть папку с документами"
	_apply_button_style(open_folder_btn)
	open_folder_btn.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute(STORAGE_ROOT)
		OS.shell_open(ProjectSettings.globalize_path(STORAGE_ROOT))
	)
	box.add_child(open_folder_btn)
	
	var open_fonts_btn := Button.new()
	open_fonts_btn.text = "Открыть папку для добавления своих шрифтов"
	_apply_button_style(open_fonts_btn)
	open_fonts_btn.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute(USER_FONTS_DIR)
		OS.shell_open(ProjectSettings.globalize_path(USER_FONTS_DIR))
	)
	box.add_child(open_fonts_btn)
	
	var back_btn := Button.new()
	back_btn.text = "Сохранить и вернуться в редактор"
	_apply_button_style(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	box.add_child(back_btn)

func _on_font_family_selected(idx: int) -> void:
	if idx >= 0 and idx < available_fonts.size():
		_save_setting("editor", "font_path", available_fonts[idx]["path"])

func _load_settings() -> void:
	config.load(CONFIG_PATH)
	font_size_spin.value = config.get_value("editor", "font_size", 16)
	theme_option.selected = config.get_value("editor", "theme", 0)
	line_numbers_check.button_pressed = config.get_value("editor", "line_numbers", true)
	word_wrap_check.button_pressed = config.get_value("editor", "word_wrap", true)
	auto_save_check.button_pressed = config.get_value("app", "auto_save", true)
	
	# Восстанавливаем выбранный шрифт в списке
	var saved_font_path: String = config.get_value("editor", "font_path", "")
	for i in range(available_fonts.size()):
		if available_fonts[i]["path"] == saved_font_path:
			font_family_option.selected = i
			break

func _save_setting(section: String, key: String, value: Variant) -> void:
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)

func _on_back_pressed() -> void:
	var main_scene = get_tree().current_scene
	if main_scene.has_method("apply_settings"):
		main_scene.apply_settings()
	if main_scene.has_method("return_to_editor"):
		main_scene.return_to_editor()

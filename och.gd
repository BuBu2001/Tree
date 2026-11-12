extends Node

@onready var file_panel = $FilePanel
@onready var path_label: Label = $FilePathLabel
@onready var editor: CodeEdit = $Editor

# Ссылки на все 5 иконок (Sprite2D)
@onready var icon_1: Sprite2D = $"1"
@onready var icon_2: Sprite2D = $"2"
@onready var icon_3: Sprite2D = $"3"
@onready var icon_4: Sprite2D = $"4"
@onready var icon_5: Sprite2D = $"5"

# Пути к вашим 5 отдельным файлам сцен
const ICON_SCENES: Array[String] = [
	"res://onif_1.tscn",
	"res://bookmarks_2.tscn",
	"res://knowledge_3.tscn",
	"res://information_4.tscn",
	"res://graph_5.tscn"
]

const CONFIG_PATH: String = "user://settings.cfg"

var current_file_path: String = ""
var is_modified: bool = false
var active_subscene: Node = null
var auto_save_enabled: bool = true

func _ready() -> void:
	# Визуальный апгрейд лейбла пути: делаем его чище и современнее
	path_label.add_theme_color_override("font_color", Color("#5f6368"))
	path_label.add_theme_font_size_override("font_size", 15)
	
	file_panel.file_selected.connect(_open_file)
	editor.text_changed.connect(_on_text_changed)
	
	editor.editable = false
	path_label.text = "Файл не выбран"
	
	# Применяем сохранённые настройки при старте программы
	apply_settings()

# --- ПРИМЕНЕНИЕ НАСТРОЕК ИЗ ФАЙЛА (ВИЗУАЛЬНЫЙ АПГРЕЙД РЕДАКТОРА) ---

func apply_settings() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	
	# 1. Размер шрифта
	var f_size: int = config.get_value("editor", "font_size", 16)
	editor.add_theme_font_size_override("font_size", f_size)
	
	# 2. Нумерация строк и перенос длинных строк
	editor.gutters_draw_line_numbers = config.get_value("editor", "line_numbers", true)
	var wrap: bool = config.get_value("editor", "word_wrap", true)
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if wrap else TextEdit.LINE_WRAPPING_NONE
	
	# 3. Автосохранение
	auto_save_enabled = config.get_value("app", "auto_save", true)
	
	# 4. Цветовая тема редактора (ПОЛНАЯ ПЕРЕРАБОТКА СТИЛЕЙ)
	var theme_idx: int = config.get_value("editor", "theme", 0)
	var bg_style := StyleBoxFlat.new()
	bg_style.set_content_margin_all(8)
	bg_style.set_corner_radius_all(4) # Легкие скругления для эстетики
	
	match theme_idx:
		0: # Светлая (Чистый лист, стиль Google Docs)
			bg_style.bg_color = Color.WHITE
			bg_style.border_color = Color("#dadce0")
			bg_style.set_border_width_all(1)
			
			editor.add_theme_color_override("font_color", Color("#202124"))
			editor.add_theme_color_override("font_readonly_color", Color("#5f6368"))
			editor.add_theme_color_override("caret_color", Color("#1a73e8")) # Синий курсор
			editor.add_theme_color_override("current_line_color", Color("#f8f9fa")) # Подсветка строки
			editor.add_theme_color_override("selection_color", Color("#d2e3fc")) # Голубое выделение
			editor.add_theme_color_override("font_selected_color", Color("#202124"))
			editor.add_theme_color_override("number_color", Color("#5f6368"))
			editor.add_theme_color_override("number_background_color", Color.WHITE)
			
		1: # Тёмная (Ночная тема, как в нормальных IDE)
			bg_style.bg_color = Color("#1e1e1e")
			bg_style.border_color = Color("#333333")
			bg_style.set_border_width_all(1)
			
			editor.add_theme_color_override("font_color", Color("#d4d4d4"))
			editor.add_theme_color_override("font_readonly_color", Color("#858585"))
			editor.add_theme_color_override("caret_color", Color("#aeafad"))
			editor.add_theme_color_override("current_line_color", Color("#2a2d2e"))
			editor.add_theme_color_override("selection_color", Color("#264f78"))
			editor.add_theme_color_override("font_selected_color", Color.WHITE)
			editor.add_theme_color_override("number_color", Color("#858585"))
			editor.add_theme_color_override("number_background_color", Color("#1e1e1e")) # <-- ИСПРАВЛЕНО
			
		2: # Сепия (Тёплая бумага, для писателей)
			bg_style.bg_color = Color("#f4ecd8")
			bg_style.border_color = Color("#e0d8c0")
			bg_style.set_border_width_all(1)
			
			editor.add_theme_color_override("font_color", Color("#3b2f2f"))
			editor.add_theme_color_override("font_readonly_color", Color("#7a6a58"))
			editor.add_theme_color_override("caret_color", Color("#8b4513"))
			editor.add_theme_color_override("current_line_color", Color("#ebe3d0"))
			editor.add_theme_color_override("selection_color", Color("#d6c6a9"))
			editor.add_theme_color_override("font_selected_color", Color("#3b2f2f"))
			editor.add_theme_color_override("number_color", Color("#7a6a58"))
			editor.add_theme_color_override("number_background_color", Color("#f4ecd8")) # <-- ИСПРАВЛЕНО
			
	editor.add_theme_stylebox_override("normal", bg_style)
	editor.add_theme_stylebox_override("read_only", bg_style)
	editor.add_theme_stylebox_override("focus", bg_style)
	
	# 5. Применение выбранного шрифта
	var font_path: String = config.get_value("editor", "font_path", "")
	if font_path.is_empty():
		editor.remove_theme_font_override("font")
	elif font_path.begins_with("res://"):
		var loaded_font = load(font_path)
		if loaded_font:
			editor.add_theme_font_override("font", loaded_font)
	else:
		var external_font := FontFile.new()
		if external_font.load_dynamic_font(font_path) == OK:
			editor.add_theme_font_override("font", external_font)

# --- ОБРАБОТКА ГОРЯЧИХ КЛАВИШ ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Сохранение по Ctrl + S (работает и на английской, и на русской раскладке)
		if active_subscene == null and event.ctrl_pressed and (event.keycode == KEY_S or event.physical_keycode == KEY_S):
			_save_current_file()
			get_viewport().set_input_as_handled()
		# Возврат в редактор из любой открытой сцены по клавише Esc
		elif active_subscene != null and event.keycode == KEY_ESCAPE:
			return_to_editor()
			get_viewport().set_input_as_handled()

# --- ОТСЛЕЖИВАНИЕ КЛИКОВ ПО ИКОНКАМ 1–5 ---

func _unhandled_input(event: InputEvent) -> void:
	if active_subscene == null and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var icons: Array[Sprite2D] = [icon_1, icon_2, icon_3, icon_4, icon_5]
			for i in range(icons.size()):
				var icon = icons[i]
				if icon and icon.visible and icon.texture != null:
					if icon.get_rect().has_point(icon.to_local(event.position)):
						# Автосохранение перед переходом на другую вкладку
						if auto_save_enabled and is_modified:
							_save_current_file()
						_open_tab_scene(ICON_SCENES[i])
						get_viewport().set_input_as_handled()
						return

# --- ЗАГРУЗКА СЦЕНЫ ИЗ ФАЙЛА И ВОЗВРАТ В РЕДАКТОР ---

func _open_tab_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		print("Ошибка: файл сцены не найден по пути ", scene_path)
		return
		
	if active_subscene != null:
		active_subscene.queue_free()
		active_subscene = null
		
	var packed_scene = load(scene_path)
	if packed_scene:
		active_subscene = packed_scene.instantiate()
		add_child(active_subscene)
		_set_editor_visible(false)

func return_to_editor() -> void:
	if active_subscene != null:
		active_subscene.queue_free()
		active_subscene = null
	# Обновляем настройки на случай выхода через Esc
	apply_settings()
	_set_editor_visible(true)

# Открывает выбранный документ из вкладки Knowledge и возвращает в главный редактор
func open_document_from_subscene(file_path: String) -> void:
	return_to_editor()
	_open_file(file_path)

func _set_editor_visible(is_vis: bool) -> void:
	for child in get_children():
		if child != active_subscene and "visible" in child:
			child.visible = is_vis

# --- РАБОТА С ДОКУМЕНТАМИ ---

func _open_file(path: String) -> void:
	# Автосохранение текущего документа перед открытием нового
	if auto_save_enabled and is_modified:
		_save_current_file()
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		path_label.text = "Ошибка чтения: " + path.get_file()
		return
		
	current_file_path = path
	editor.text = file.get_as_text()
	editor.editable = true
	is_modified = false
	_update_header()

func _save_current_file() -> void:
	if current_file_path.is_empty():
		return
		
	var file = FileAccess.open(current_file_path, FileAccess.WRITE)
	if file:
		file.store_string(editor.text)
		file.close()
		is_modified = false
		_update_header()
		print("Файл успешно сохранён: ", current_file_path)

func _on_text_changed() -> void:
	if not is_modified and not current_file_path.is_empty():
		is_modified = true
		_update_header()

func _update_header() -> void:
	var file_name: String = current_file_path.get_file()
	path_label.text = "Документ: " + file_name + (" *" if is_modified else "")

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

var current_file_path: String = ""
var is_modified: bool = false
var active_subscene: Node = null

func _ready() -> void:
	path_label.add_theme_color_override("font_color", Color.WHITE)
	path_label.add_theme_font_size_override("font_size", 16)
	
	file_panel.file_selected.connect(_open_file)
	editor.text_changed.connect(_on_text_changed)
	
	editor.gutters_draw_line_numbers = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.editable = false
	path_label.text = "Файл не выбран"

# --- ОБРАБОТКА ГОРЯЧИХ КЛАВИШ (РАБОТАЕТ ДАЖЕ ПРИ АКТИВНОМ ВВОДЕ В EDITOR) ---

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
	_set_editor_visible(true)

func _set_editor_visible(is_vis: bool) -> void:
	for child in get_children():
		if child != active_subscene and "visible" in child:
			child.visible = is_vis

# --- РАБОТА С ДОКУМЕНТАМИ ---

func _open_file(path: String) -> void:
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

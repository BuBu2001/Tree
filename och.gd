extends Node

@onready var file_panel = $FilePanel
@onready var path_label: Label = $FilePathLabel
@onready var editor: CodeEdit = $Editor

var current_file_path: String = ""
var is_modified: bool = false

func _ready() -> void:
	# Делаем текст заголовка ярко-белым и крупным, чтобы он точно был виден
	path_label.add_theme_color_override("font_color", Color.WHITE)
	path_label.add_theme_font_size_override("font_size", 16)
	
	# Подключаем сигналы левой панели и текстового поля
	file_panel.file_selected.connect(_open_file)
	editor.text_changed.connect(_on_text_changed)
	
	# Базовая настройка редактора
	editor.gutters_draw_line_numbers = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.editable = false
	path_label.text = "Файл не выбран"

func _open_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		path_label.text = "Ошибка чтения: " + path.get_file()
		return
		
	current_file_path = path
	editor.text = file.get_as_text()
	editor.editable = true
	is_modified = false
	
	# Выводим название файла в FilePathLabel
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

func _on_text_changed() -> void:
	if not is_modified and not current_file_path.is_empty():
		is_modified = true
		_update_header()

func _update_header() -> void:
	# get_file() извлекает чистое имя файла с расширением (например, "test.txt")
	var file_name: String = current_file_path.get_file()
	if is_modified:
		path_label.text = "Документ: " + file_name + " *"
	else:
		path_label.text = "Документ: " + file_name

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and event.ctrl_pressed:
			_save_current_file()
			get_viewport().set_input_as_handled()

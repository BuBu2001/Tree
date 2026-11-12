extends Control

# Сигнал для передачи пути выбранного файла в MainEditor
signal file_selected(file_path: String)

@onready var tree: Tree = $PanelContainer/Tree
@onready var context_menu: PopupMenu = $ContextMenu
@onready var create_dialog: ConfirmationDialog = $CreateDialog
@onready var name_input: LineEdit = $CreateDialog/NameInput

const STORAGE_ROOT: String = "user://ggg/res/"
const DISPLAY_ROOT: String = "ggg/res/"

# Папка, в которой сейчас создается файл или подпапка
var target_dir: String = STORAGE_ROOT
var is_creating_folder: bool = false

func _ready() -> void:
	# Разрешаем выбор элементов правой кнопкой мыши
	tree.allow_rmb_select = true
	
	# Подключаем сигналы дерева, меню и диалогового окна
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_tree_rmb_selected)
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	create_dialog.confirmed.connect(_on_create_confirmed)
	
	# Настраиваем пункты меню (ID 0 — файл, ID 1 — папка)
	context_menu.add_item("Создать файл", 0)
	context_menu.add_item("Создать папку", 1)
	
	# Настраиваем заголовок окна и подсказку в поле ввода
	create_dialog.title = "Создание элемента"
	name_input.placeholder_text = "Например: note.txt"
	
	_init_storage()
	populate_tree()

func _init_storage() -> void:
	DirAccess.make_dir_recursive_absolute(STORAGE_ROOT)

func populate_tree() -> void:
	tree.clear()
	var root_item = tree.create_item()
	root_item.set_text(0, DISPLAY_ROOT)
	root_item.set_metadata(0, STORAGE_ROOT)
	_scan_directory(STORAGE_ROOT, root_item)

func _scan_directory(path: String, parent_item: TreeItem) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
		
	dir.include_hidden = false
	dir.include_navigational = false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		var item = tree.create_item(parent_item)
		item.set_text(0, file_name)
		item.set_metadata(0, full_path)
		
		if dir.current_is_dir():
			item.collapsed = true
			_scan_directory(full_path, item)
			
		file_name = dir.get_next()
	dir.list_dir_end()

# Вызывается при клике по элементу дерева
func _on_tree_rmb_selected(_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var selected = tree.get_selected()
		if selected:
			var path: String = selected.get_metadata(0)
			# Если кликнули по папке — берем её путь. Если по файлу — берем папку, в которой он лежит
			if DirAccess.dir_exists_absolute(path):
				target_dir = path
			else:
				target_dir = path.get_base_dir()
			
			# Открываем меню в координатах курсора
			context_menu.position = Vector2i(get_global_mouse_position())
			context_menu.popup()

# Вызывается при выборе пункта в контекстном меню
func _on_context_menu_pressed(id: int) -> void:
	is_creating_folder = (id == 1)
	create_dialog.title = "Новая папка" if is_creating_folder else "Новый файл"
	name_input.text = ""
	
	# Показываем окно по центру экрана и ставим курсор в поле ввода
	create_dialog.popup_centered(Vector2i(300, 100))
	name_input.grab_focus()

# Вызывается при нажатии "ОК" в диалоговом окне
func _on_create_confirmed() -> void:
	var new_name = name_input.text.strip_edges()
	if new_name.is_empty() or not new_name.is_valid_filename():
		print("Некорректное имя!")
		return
		
	var full_new_path = target_dir.path_join(new_name)
	
	if is_creating_folder:
		DirAccess.make_dir_recursive_absolute(full_new_path)
		populate_tree()
	else:
		var file = FileAccess.open(full_new_path, FileAccess.WRITE)
		if file:
			file.close()
			populate_tree()
			# Сразу передаем новый файл в редактор, чтобы можно было начать печатать
			file_selected.emit(full_new_path)
		else:
			print("Ошибка создания файла: ", FileAccess.get_open_error())

# Вызывается при двойном клике по элементу дерева
func _on_item_activated() -> void:
	var selected = tree.get_selected()
	if selected:
		var path: String = selected.get_metadata(0)
		# Отправляем сигнал только если это файл, а не папка
		if not DirAccess.dir_exists_absolute(path):
			file_selected.emit(path)

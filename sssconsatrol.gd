extends Control

const STORAGE_ROOT: String = "user://ggg/res/"
const CARD_WIDTH: float = 175.0
const PREVIEW_HEIGHT: float = 180.0

var grid: GridContainer
var search_input: LineEdit
var create_dialog: ConfirmationDialog
var name_input: LineEdit
var all_documents: Array[Dictionary] = []

func _ready() -> void:
	# Принудительно устанавливаем размер видимой области окна
	size = get_viewport_rect().size
	
	# Подключаем сигнал изменения размера viewport
	get_viewport().connect("size_changed", _on_viewport_resized)
	
	# Выводим в консоль Godot реальный путь на диске, куда смотрит скрипт
	print("Ищу документы в папке: ", ProjectSettings.globalize_path(STORAGE_ROOT))
	
	_build_ui()
	_build_create_dialog()
	_reload_documents()
	
	print("Найдено документов: ", all_documents.size())

func _on_viewport_resized() -> void:
	# Обновляем размер при изменении окна
	size = get_viewport_rect().size
	# Также обновляем размер основных контейнеров
	if has_node("ColorRect"):
		get_node("ColorRect").size = size
	if has_node("VBoxContainer"):
		get_node("VBoxContainer").size = size

func _reload_documents() -> void:
	all_documents.clear()
	_scan_all_documents(STORAGE_ROOT)
	_refresh_grid(search_input.text)

func _build_ui() -> void:
	# Основной белый фон страницы
	var root_bg := ColorRect.new()
	root_bg.color = Color.WHITE
	root_bg.size = size
	add_child(root_bg)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.size = size
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)
	
	# --- 1. ВЕРХНЯЯ ПАНЕЛЬ (ШАПКА С ПОИСКОМ) ---
	var header_panel := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color.WHITE
	header_style.border_color = Color("#e0e0e0")
	header_style.border_width_bottom = 1
	header_style.set_content_margin_all(14)
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)
	
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	header_panel.add_child(header_hbox)
	
	var logo_lbl := Label.new()
	logo_lbl.text = "Документы"
	logo_lbl.add_theme_font_size_override("font_size", 22)
	logo_lbl.add_theme_color_override("font_color", Color("#5f6368"))
	header_hbox.add_child(logo_lbl)
	
	# Поле поиска в стиле Google
	search_input = LineEdit.new()
	search_input.placeholder_text = "Поиск"
	search_input.custom_minimum_size = Vector2(450, 38)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color("#f1f3f4")
	search_style.set_corner_radius_all(8)
	search_style.content_margin_left = 14
	search_style.content_margin_right = 14
	search_input.add_theme_stylebox_override("normal", search_style)
	search_input.add_theme_color_override("font_color", Color.BLACK)
	search_input.add_theme_color_override("font_placeholder_color", Color("#5f6368"))
	search_input.text_changed.connect(_refresh_grid)
	header_hbox.add_child(search_input)
	
	var back_btn := Button.new()
	back_btn.text = "В редактор (Esc)"
	_style_light_button(back_btn)
	back_btn.pressed.connect(func():
		var main_scene = get_tree().current_scene
		if main_scene.has_method("return_to_editor"):
			main_scene.return_to_editor()
	)
	header_hbox.add_child(back_btn)
	
	# --- 2. ОБЛАСТЬ ПРОКРУТКИ (ШАБЛОНЫ + НЕДАВНИЕ ДОКУМЕНТЫ) ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	var scroll_content := VBoxContainer.new()
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_theme_constant_override("separation", 0)
	scroll.add_child(scroll_content)
	
	# --- СЕКЦИЯ А: ВЕРХНЯЯ СЕРАЯ ПОЛОСА («СОЗДАТЬ ДОКУМЕНТ») ---
	var template_band := PanelContainer.new()
	var band_style := StyleBoxFlat.new()
	band_style.bg_color = Color("#f1f3f4")
	band_style.content_margin_left = 80
	band_style.content_margin_right = 80
	band_style.content_margin_top = 20
	band_style.content_margin_bottom = 25
	template_band.add_theme_stylebox_override("panel", band_style)
	scroll_content.add_child(template_band)
	
	var band_vbox := VBoxContainer.new()
	band_vbox.add_theme_constant_override("separation", 14)
	template_band.add_child(band_vbox)
	
	var band_title := Label.new()
	band_title.text = "Создать документ"
	band_title.add_theme_font_size_override("font_size", 16)
	band_title.add_theme_color_override("font_color", Color("#202124"))
	band_vbox.add_child(band_title)
	
	var templates_row := HBoxContainer.new()
	templates_row.add_theme_constant_override("separation", 20)
	band_vbox.add_child(templates_row)
	
	# Карточка «Пустой документ» с цветным плюсом
	templates_row.add_child(_create_blank_template_card())
	
	# --- СЕКЦИЯ Б: БЕЛАЯ ОБЛАСТЬ («НЕДАВНИЕ ДОКУМЕНТЫ») ---
	var recent_margin := MarginContainer.new()
	recent_margin.add_theme_constant_override("margin_left", 80)
	recent_margin.add_theme_constant_override("margin_right", 80)
	recent_margin.add_theme_constant_override("margin_top", 25)
	recent_margin.add_theme_constant_override("margin_bottom", 40)
	scroll_content.add_child(recent_margin)
	
	var recent_vbox := VBoxContainer.new()
	recent_vbox.add_theme_constant_override("separation", 18)
	recent_margin.add_child(recent_vbox)
	
	var recent_title := Label.new()
	recent_title.text = "Недавние документы"
	recent_title.add_theme_font_size_override("font_size", 16)
	recent_title.add_theme_color_override("font_color", Color("#202124"))
	recent_vbox.add_child(recent_title)
	
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	recent_vbox.add_child(grid)

# Карточка создания пустого документа
func _create_blank_template_card() -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 180)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.border_color = Color("#dadce0")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	
	var hover := normal.duplicate()
	hover.border_color = Color("#1a73e8")
	hover.set_border_width_all(2)
	
	card.add_theme_stylebox_override("panel", normal)
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", normal))
	
	var plus_lbl := Label.new()
	plus_lbl.text = "+"
	plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus_lbl.add_theme_font_size_override("font_size", 54)
	plus_lbl.add_theme_color_override("font_color", Color("#4285f4"))
	card.add_child(plus_lbl)
	
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			name_input.text = ""
			create_dialog.popup_centered(Vector2i(320, 110))
			name_input.grab_focus()
	)
	
	var lbl := Label.new()
	lbl.text = "Пустой документ"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color("#202124"))
	
	wrapper.add_child(card)
	wrapper.add_child(lbl)
	return wrapper

# Диалог ввода имени при клике на «Пустой документ»
func _build_create_dialog() -> void:
	create_dialog = ConfirmationDialog.new()
	create_dialog.title = "Создать новый документ"
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Например: Новый документ.txt"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_dialog.add_child(name_input)
	add_child(create_dialog)
	
	create_dialog.confirmed.connect(func():
		var file_name := name_input.text.strip_edges()
		if file_name.is_empty():
			file_name = "Новый документ.txt"
		if not file_name.is_valid_filename():
			return
		var full_path := STORAGE_ROOT.path_join(file_name)
		var f := FileAccess.open(full_path, FileAccess.WRITE)
		if f:
			f.close()
			_open_document(full_path)
	)

func _scan_all_documents(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
		
	dir.include_hidden = false
	dir.include_navigational = false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			_scan_all_documents(full_path)
		else:
			var mod_time := FileAccess.get_modified_time(full_path)
			var dt := Time.get_datetime_dict_from_unix_time(mod_time)
			var date_str := "%02d.%02d.%d" % [dt["day"], dt["month"], dt["year"]]
			
			all_documents.append({
				"name": file_name,
				"real_path": full_path,
				"date": date_str,
				"timestamp": mod_time
			})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Сортируем: самые свежие документы сверху
	all_documents.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])

func _refresh_grid(filter_text: String) -> void:
	for child in grid.get_children():
		child.queue_free()
		
	var query = filter_text.strip_edges().to_lower()
	
	for doc in all_documents:
		if query.is_empty() or doc["name"].to_lower().contains(query):
			grid.add_child(_create_doc_card(doc))
			
	if grid.get_child_count() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Ничего не найдено"
		empty_lbl.add_theme_color_override("font_color", Color("#5f6368"))
		grid.add_child(empty_lbl)

# Карточка существующего документа в точном стиле Google Docs
func _create_doc_card(doc: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, PREVIEW_HEIGHT + 65)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.border_color = Color("#dfe1e5")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	
	var hover := normal.duplicate()
	hover.border_color = Color("#1a73e8")
	
	card.add_theme_stylebox_override("panel", normal)
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", normal))
	
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_open_document(doc["real_path"])
	)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)
	
	# Верхняя часть карточки: серый листок-превью
	var sheet_preview := ColorRect.new()
	sheet_preview.color = Color("#f8f9fa")
	sheet_preview.custom_minimum_size = Vector2(CARD_WIDTH, PREVIEW_HEIGHT)
	sheet_preview.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(sheet_preview)
	
	# Разделительная линия между листком и подписью
	var sep := ColorRect.new()
	sep.color = Color("#e0e0e0")
	sep.custom_minimum_size = Vector2(CARD_WIDTH, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(sep)
	
	# Нижняя часть карточки: название документа и дата изменения
	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 12)
	footer_margin.add_theme_constant_override("margin_right", 12)
	footer_margin.add_theme_constant_override("margin_top", 10)
	footer_margin.add_theme_constant_override("margin_bottom", 10)
	footer_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(footer_margin)
	
	var footer_vbox := VBoxContainer.new()
	footer_vbox.add_theme_constant_override("separation", 4)
	footer_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	footer_margin.add_child(footer_vbox)
	
	var name_lbl := Label.new()
	name_lbl.text = doc["name"]
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color("#202124"))
	footer_vbox.add_child(name_lbl)
	
	var date_lbl := Label.new()
	date_lbl.text = "Изменено: " + doc["date"]
	date_lbl.add_theme_font_size_override("font_size", 12)
	date_lbl.add_theme_color_override("font_color", Color("#5f6368"))
	footer_vbox.add_child(date_lbl)
	
	return card

func _style_light_button(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#f1f3f4")
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color("#202124"))

func _open_document(file_path: String) -> void:
	var main_scene = get_tree().current_scene
	if main_scene.has_method("open_document_from_subscene"):
		main_scene.open_document_from_subscene(file_path)

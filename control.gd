extends Control

# Ссылка на контейнер, в котором выстраиваются столбцы
@onready var chart_container: HBoxContainer = $ScrollContainer/ChartContainer

# Путь к вашему хранилищу документов
const STORAGE_ROOT: String = "user://ggg/res/"
# Максимальная высота самого высокого столбца в пикселях
const MAX_BAR_HEIGHT: float = 300.0
# Ширина одной колонки (с запасом под название файла снизу)
const COLUMN_WIDTH: float = 95.0
# Ширина самого цветного столбца
const BAR_WIDTH: float = 45.0

func _ready() -> void:
	build_chart()

func build_chart() -> void:
	# 1. Очищаем старые столбцы перед обновлением
	for child in chart_container.get_children():
		child.queue_free()
		
	# 2. Собираем данные о всех файлах и считаем слова
	var files_data: Array[Dictionary] = []
	_scan_files(STORAGE_ROOT, files_data)
	
	if files_data.is_empty():
		var empty_label = Label.new()
		empty_label.text = "В хранилище пока нет документов"
		empty_label.add_theme_color_override("font_color", Color.BLACK)
		chart_container.add_child(empty_label)
		return
		
	# 3. Находим максимальное количество слов среди всех документов (для масштаба)
	var max_words: int = 1
	for item in files_data:
		if item["words"] > max_words:
			max_words = item["words"]
			
	# 4. Строим столбец для каждого документа
	for item in files_data:
		_create_bar(item["name"], item["words"], max_words)

# Рекурсивный обход папки и подпапок
func _scan_files(path: String, result: Array[Dictionary]) -> void:
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
			_scan_files(full_path, result)
		else:
			var words_count = _count_words_in_file(full_path)
			result.append({
				"name": file_name,
				"words": words_count
			})
		file_name = dir.get_next()
	dir.list_dir_end()

# Подсчёт количества слов в конкретном файле
func _count_words_in_file(file_path: String) -> int:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0
		
	var content: String = file.get_as_text()
	file.close()
	
	var words = content.split(" ", false)
	var total_words: int = 0
	for chunk in words:
		var sub_words = chunk.replace("\n", " ").replace("\t", " ").split(" ", false)
		total_words += sub_words.size()
		
	return total_words

# Создание визуального столбца с полной подписью и всплывающей подсказкой при наведении
func _create_bar(file_name: String, word_count: int, max_words: int) -> void:
	var tooltip_info: String = "Файл: %s\nСлов: %d" % [file_name, word_count]
	
	var column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END # Прижимаем содержимое к низу
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, MAX_BAR_HEIGHT + 80)
	column.mouse_filter = Control.MOUSE_FILTER_STOP
	column.tooltip_text = tooltip_info
	
	# 1. Точное количество слов над столбцом
	var count_label = Label.new()
	count_label.text = str(word_count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 13)
	
	# 2. Сам цветной столбец
	var bar = ColorRect.new()
	var ratio: float = float(word_count) / float(max_words)
	var bar_height: float = max(4.0, ratio * MAX_BAR_HEIGHT)
	bar.custom_minimum_size = Vector2(BAR_WIDTH, bar_height)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.color = Color("#4a90e2")
	
	# Включаем всплывающую подсказку при наведении на столбец и лёгкую подсветку
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.tooltip_text = tooltip_info
	bar.mouse_entered.connect(func(): bar.color = Color("#6ba8f0"))
	bar.mouse_exited.connect(func(): bar.color = Color("#4a90e2"))
	
	# 3. Полное название файла строго под столбцом (чёрного цвета)
	var name_label = Label.new()
	name_label.text = file_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(COLUMN_WIDTH, 40)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.BLACK)
	
	# Собираем колонку сверху вниз
	column.add_child(count_label)
	column.add_child(bar)
	column.add_child(name_label)
	
	chart_container.add_child(column)

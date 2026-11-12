extends Control

const STORAGE_ROOT: String = "user://ggg/res/"

# Настройки физики графа
const REPULSION_FORCE: float = 45000.0  # Сила отталкивания узлов друг от друга
const SPRING_LENGTH: float = 160.0      # Идеальная длина линии связи
const SPRING_STIFFNESS: float = 0.04    # Жёсткость притяжения связанных документов
const CENTER_GRAVITY: float = 0.015     # Лёгкое притяжение к центру экрана
const DAMPING: float = 0.85             # Трение (чтобы узлы плавно останавливались)

# Массив узлов графа: каждый элемент — словарь с координатами, скоростью и данными файла
var nodes: Array[Dictionary] = []
var nodes_by_key: Dictionary = {}
# Список рёбер (линий): {"from": int, "to": int, "is_combo": bool}
var edges: Array[Dictionary] = []

# Управление камерой и мышью
var pan_offset: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var is_panning: bool = false
var dragged_node_idx: int = -1
var hovered_node_idx: int = -1

func _ready() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	
	_build_top_bar()
	_load_graph_data()

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if pan_offset == Vector2.ZERO:
		pan_offset = size / 2.0

func _build_top_bar() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)
	
	var back_btn := Button.new()
	back_btn.text = "← В редактор (Esc)"
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#1e1e1e")
	btn_style.border_color = Color("#444444")
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	back_btn.add_theme_stylebox_override("normal", btn_style)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.pressed.connect(func():
		var main_scene = get_tree().current_scene
		if main_scene.has_method("return_to_editor"):
			main_scene.return_to_editor()
	)
	hbox.add_child(back_btn)
	
	var hint := Label.new()
	hint.text = "ЛКМ: тащить узел | 2xЛКМ: открыть документ | ПКМ: двигать холст | Колёсико: масштаб"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#9aa0a6"))
	hbox.add_child(hint)

# --- СБОР ДОКУМЕНТОВ И ПОСТРОЕНИЕ СВЯЗЕЙ ---

func _load_graph_data() -> void:
	nodes.clear()
	nodes_by_key.clear()
	edges.clear()
	
	var raw_docs: Array[Dictionary] = []
	_scan_files(STORAGE_ROOT, raw_docs)
	
	var count: int = raw_docs.size()
	for i in range(count):
		var doc: Dictionary = raw_docs[i]
		# Явное приведение типов, чтобы Godot не тупил с max() и TAU
		var angle: float = (TAU / float(max(1, count))) * float(i)
		var radius: float = 120.0 + randf_range(-20.0, 20.0)
		var node_dict: Dictionary = {
			"index": i,
			"name": doc["name"],
			"title_key": doc["title_key"],
			"real_path": doc["real_path"],
			"pos": Vector2(cos(angle), sin(angle)) * radius,
			"vel": Vector2.ZERO,
			"raw_links": doc["links"],
			"combos": doc["combos"],
			"degree": 0 # Количество связей (чем больше связей, тем крупнее кружок)
		}
		nodes.append(node_dict)
		nodes_by_key[doc["title_key"]] = i
		
	var added_pairs: Dictionary = {}
	
	for i in range(nodes.size()):
		var node_a: Dictionary = nodes[i]
		var key_a: String = node_a["title_key"]
		
		# Проверяем взаимные ссылки [Б]
		for key_b in node_a["raw_links"]:
			if nodes_by_key.has(key_b) and key_b != key_a:
				var j: int = int(nodes_by_key[key_b])
				var node_b: Dictionary = nodes[j]
				if key_a in node_b["raw_links"]:
					var pair_id: String = _make_pair_id(i, j)
					if not added_pairs.has(pair_id):
						added_pairs[pair_id] = true
						edges.append({"from": i, "to": j, "is_combo": false})
						nodes[i]["degree"] += 1
						nodes[j]["degree"] += 1
						
		# Проверяем комбинации {[Б],[Г]} (создаём фиолетовую линию-мост между Б и Г)
		for combo in node_a["combos"]:
			var k1: String = str(combo[0])
			var k2: String = str(combo[1])
			if nodes_by_key.has(k1) and nodes_by_key.has(k2) and k1 != k2:
				var idx1: int = int(nodes_by_key[k1])
				var idx2: int = int(nodes_by_key[k2])
				var pair_id: String = _make_pair_id(idx1, idx2)
				if not added_pairs.has(pair_id):
					added_pairs[pair_id] = true
					edges.append({"from": idx1, "to": idx2, "is_combo": true})
					nodes[idx1]["degree"] += 1
					nodes[idx2]["degree"] += 1

func _make_pair_id(a: int, b: int) -> String:
	return "%d_%d" % [min(a, b), max(a, b)]

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
			var content: String = ""
			var f = FileAccess.open(full_path, FileAccess.READ)
			if f:
				content = f.get_as_text()
				f.close()
			result.append({
				"name": file_name,
				"title_key": file_name.get_basename().to_lower(),
				"real_path": full_path,
				"links": _extract_links(content),
				"combos": _extract_combos(content)
			})
		file_name = dir.get_next()
	dir.list_dir_end()

func _extract_links(text: String) -> Array[String]:
	var links: Array[String] = []
	var rx := RegEx.new()
	rx.compile("\\[([^\\]]+)\\]")
	for m in rx.search_all(text):
		var target: String = m.get_string(1).strip_edges().get_basename().to_lower()
		if not target in links:
			links.append(target)
	return links

func _extract_combos(text: String) -> Array:
	var combos: Array = []
	var rx := RegEx.new()
	rx.compile("\\{\\s*\\[([^\\]]+)\\]\\s*,\\s*\\[([^\\]]+)\\]\\s*\\}")
	for m in rx.search_all(text):
		var k1: String = m.get_string(1).strip_edges().get_basename().to_lower()
		var k2: String = m.get_string(2).strip_edges().get_basename().to_lower()
		combos.append([k1, k2])
	return combos

# --- ФИЗИКА ДВИЖЕНИЯ УЗЛОВ КАЖДЫЙ КАДР ---

func _process(delta: float) -> void:
	if nodes.is_empty():
		queue_redraw()
		return
		
	var dt: float = minf(delta, 0.05)
	
	# 1. Отталкивание всех узлов друг от друга + притяжение к центру
	for i in range(nodes.size()):
		if i == dragged_node_idx:
			continue
		var force: Vector2 = -nodes[i]["pos"] * CENTER_GRAVITY
		for j in range(nodes.size()):
			if i == j:
				continue
			var diff: Vector2 = nodes[i]["pos"] - nodes[j]["pos"]
			var dist_sq: float = maxf(diff.length_squared(), 100.0)
			force += diff.normalized() * (REPULSION_FORCE / dist_sq)
		nodes[i]["vel"] = (nodes[i]["vel"] + force * dt) * DAMPING
		
	# 2. Пружинное притяжение вдоль линий связей
	for edge in edges:
		var i: int = edge["from"]
		var j: int = edge["to"]
		var diff: Vector2 = nodes[j]["pos"] - nodes[i]["pos"]
		var dist: float = maxf(diff.length(), 1.0)
		var displacement: float = dist - SPRING_LENGTH
		var spring_force: Vector2 = diff.normalized() * displacement * SPRING_STIFFNESS
		
		if i != dragged_node_idx:
			nodes[i]["vel"] += spring_force
		if j != dragged_node_idx:
			nodes[j]["vel"] -= spring_force
			
	# 3. Применяем скорости к координатам
	for i in range(nodes.size()):
		if i != dragged_node_idx:
			nodes[i]["pos"] += nodes[i]["vel"] * dt * 60.0
			
	queue_redraw()

# --- ОТРИСОВКА ГРАФА (ФОН, ЛИНИИ, КРУЖКИ, НАЗВАНИЯ) ---

func _draw() -> void:
	# 1. Тёмный фон в стиле Obsidian
	draw_rect(Rect2(Vector2.ZERO, size), Color("#161618"), true)
	
	if nodes.is_empty():
		var font := get_theme_default_font()
		var text: String = "Нет документов для построения графа"
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw_string(font, (size / 2.0) - Vector2(text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#888888"))
		return
		
	# 2. Рисуем линии связей
	for edge in edges:
		var idx_a: int = edge["from"]
		var idx_b: int = edge["to"]
		var pos_a: Vector2 = _world_to_screen(nodes[idx_a]["pos"])
		var pos_b: Vector2 = _world_to_screen(nodes[idx_b]["pos"])
		
		var is_highlighted: bool = (hovered_node_idx == idx_a or hovered_node_idx == idx_b)
		var line_color: Color
		if edge["is_combo"]:
			line_color = Color("#a855f7") if is_highlighted else Color("#581c87") # Фиолетовый для комбинаций {}
		else:
			line_color = Color("#3b82f6") if is_highlighted else Color("#3f3f46") # Синий/серый для связей []
			
		draw_line(pos_a, pos_b, line_color, (2.5 if is_highlighted else 1.5) * zoom_level, true)
		
	# 3. Рисуем кружки-документы и подписи под ними
	var font := get_theme_default_font()
	var font_size: int = int(clampf(13.0 * zoom_level, 9.0, 22.0))
	
	for i in range(nodes.size()):
		var n: Dictionary = nodes[i]
		var screen_pos: Vector2 = _world_to_screen(n["pos"])
		var base_radius: float = 8.0 + minf(float(n["degree"]) * 2.5, 14.0)
		var radius: float = base_radius * zoom_level
		
		var is_hovered: bool = (i == hovered_node_idx or i == dragged_node_idx)
		var node_color: Color = Color("#60a5fa") if is_hovered else (Color("#a1a1aa") if int(n["degree"]) > 0 else Color("#52525b"))
		
		draw_circle(screen_pos, radius, node_color)
		if is_hovered:
			draw_arc(screen_pos, radius + 3.0, 0, TAU, 32, Color("#93c5fd"), 1.5, true)
			
		var label_text: String = n["name"].get_basename()
		var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = screen_pos + Vector2(-text_size.x / 2.0, radius + float(font_size) + 4.0)
		var text_color: Color = Color.WHITE if is_hovered else Color("#d4d4d8")
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

# --- ВЗАИМОДЕЙСТВИЕ МЫШЬЮ (ПЕРЕТАСКИВАНИЕ, ЗУМ, ОТКРЫТИЕ ФАЙЛА) ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_level = clampf(zoom_level * 1.1, 0.3, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_level = clampf(zoom_level * 0.9, 0.3, 3.0)
			
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit: int = _get_node_at_screen_pos(event.position)
				if hit != -1:
					if event.double_click:
						var main_scene = get_tree().current_scene
						if main_scene.has_method("open_document_from_subscene"):
							main_scene.open_document_from_subscene(nodes[hit]["real_path"])
						return
					dragged_node_idx = hit
				else:
					dragged_node_idx = -1
					
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			
	elif event is InputEventMouseMotion:
		if dragged_node_idx != -1:
			nodes[dragged_node_idx]["pos"] = _screen_to_world(event.position)
			nodes[dragged_node_idx]["vel"] = Vector2.ZERO
		elif is_panning:
			pan_offset += event.relative
		else:
			hovered_node_idx = _get_node_at_screen_pos(event.position)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_node_idx != -1 else Control.CURSOR_ARROW

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return pan_offset + world_pos * zoom_level

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - pan_offset) / zoom_level

func _get_node_at_screen_pos(screen_pos: Vector2) -> int:
	for i in range(nodes.size() - 1, -1, -1):
		var n: Dictionary = nodes[i]
		var n_screen: Vector2 = _world_to_screen(n["pos"])
		var hit_radius: float = (12.0 + minf(float(n["degree"]) * 2.5, 14.0)) * zoom_level
		if screen_pos.distance_to(n_screen) <= hit_radius:
			return i
	return -1

extends Button # Важно! Не Node, а Button

func _ready():
	# Мы уже внутри кнопки, поэтому подключаем сигнал напрямую к себе
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	get_tree().change_scene_to_file("res://scenes/next_scene.tscn")

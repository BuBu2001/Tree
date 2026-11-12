extends Node2D

@onready var button = $Button

func _ready():
	button.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	get_tree().change_scene_to_file("res://och.tscn")

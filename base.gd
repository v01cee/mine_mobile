extends Node2D

# База (поверхность). Пока заготовка: отсюда спускаемся в шахту.
# Позже здесь будут продажа блоков, магазины кирок/скинов, выбор и рефреш шахты.

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "База (поверхность)"
	title.position = Vector2(24, 40)
	layer.add_child(title)

	var to_mine := Button.new()
	to_mine.text = "Спуститься в шахту"
	to_mine.position = Vector2(24, 100)
	to_mine.pressed.connect(_on_to_mine_pressed)
	layer.add_child(to_mine)

func _on_to_mine_pressed() -> void:
	get_tree().change_scene_to_file("res://mine.tscn")

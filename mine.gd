extends Node2D

# --- Настройки сетки ---
const COLS := 9          # ширина шахты в блоках
const ROWS := 12         # глубина (пока фиксированная)
const BLOCK_SIZE := 64   # размер блока в пикселях
const GAP := 2           # зазор между блоками

var broken := 0          # счётчик сломанных блоков

func _ready() -> void:
	_build_grid()

# Строим сетку: на каждую клетку — кликабельный блок
func _build_grid() -> void:
	for row in range(ROWS):
		for col in range(COLS):
			_make_block(col, row)

func _make_block(col: int, row: int) -> void:
	# Button — самый простой кликабельный элемент, ловит тап из коробки
	var block := Button.new()
	block.custom_minimum_size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	block.position = Vector2(
		col * (BLOCK_SIZE + GAP),
		row * (BLOCK_SIZE + GAP)
	)
	block.text = ""  # пока без текста
	# при тапе вызовется _on_block_pressed с этим же блоком
	block.pressed.connect(_on_block_pressed.bind(block))
	add_child(block)

# Реакция на тап по блоку
func _on_block_pressed(block: Button) -> void:
	block.queue_free()   # блок исчезает
	broken += 1
	print("Сломано блоков: ", broken)

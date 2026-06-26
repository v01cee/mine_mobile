extends Node2D

# --- Настройки сетки ---
const COLS := 5          # ширина шахты в блоках
const ROWS := 24         # глубина (поле выше экрана — есть куда копать вглубь)
const BLOCK_SIZE := 128  # размер блока в пикселях
const GAP := 2           # зазор между блоками
const TOP_MARGIN := 110  # отступ сверху, чтобы первый ряд не лез под HUD

# Цвета состояний блока
const COLOR_LOCKED := Color(0.35, 0.35, 0.35)  # закрытый — копать нельзя
const COLOR_OPEN := Color(1, 1, 1)             # открытый — можно тапать

# Накопительный счётчик сломанных блоков. static — переживает смену сцены
# (выход на поверхность и обратно), не сбрасывается. Обнуляется только при перезапуске игры.
static var total_broken := 0

# Кэш состояния поля: какие клетки уже сломаны. Тоже static — поле остаётся
# на месте при выходе на поверхность и обратно. Чистится только рефрешем.
static var _saved_broken: Dictionary = {}

var _origin := Vector2.ZERO          # левый верхний угол сетки
var _blocks: Array = []              # 2D-массив блоков: _blocks[row][col], null если сломан
var _deepest_row := 0                # самый глубокий расчищенный ряд (для камеры)
var _camera: Camera2D                # камера, следующая за фронтом копки
var _broken_label: Label             # счётчик в HUD

func _ready() -> void:
	_build_camera()
	_build_ui()
	_build_grid()

# Камера: едет за расчищенной областью вглубь
func _build_camera() -> void:
	_camera = Camera2D.new()
	# Плавное доезжание, чтобы не дёргалось при копке
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()

# UI поверх сцены (в CanvasLayer, чтобы не двигался вместе с камерой)
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var refresh := Button.new()
	refresh.text = "Обновить"
	refresh.position = Vector2(16, 16)
	refresh.pressed.connect(_on_refresh_pressed)
	layer.add_child(refresh)

	var surface := Button.new()
	surface.text = "На поверхность"
	surface.position = Vector2(16, 56)
	surface.pressed.connect(_on_surface_pressed)
	layer.add_child(surface)

	_broken_label = Label.new()
	_broken_label.position = Vector2(200, 24)
	layer.add_child(_broken_label)
	_update_broken_label()

# Возврат на Базу
func _on_surface_pressed() -> void:
	get_tree().change_scene_to_file("res://base.tscn")

# Сносим текущее поле и строим заново (чистая шахта). Счётчик НЕ трогаем.
func _on_refresh_pressed() -> void:
	for row_blocks in _blocks:
		for block in row_blocks:
			if block != null:
				block.queue_free()
	_blocks.clear()
	_saved_broken.clear()   # рефреш = чистое поле
	_deepest_row = 0
	_build_grid()

# Строим сетку: на каждую клетку — кликабельный блок
func _build_grid() -> void:
	var grid_width := COLS * BLOCK_SIZE + (COLS - 1) * GAP
	# По горизонтали — по центру вьюпорта, по вертикали — от отступа сверху вниз
	_origin = Vector2((get_viewport_rect().size.x - grid_width) * 0.5, TOP_MARGIN)
	for row in range(ROWS):
		var row_blocks: Array = []
		for col in range(COLS):
			row_blocks.append(_make_block(col, row))
		_blocks.append(row_blocks)
	# Восстанавливаем ранее сломанные клетки из кэша
	_deepest_row = 0
	for cell in _saved_broken:
		_blocks[cell.y][cell.x].queue_free()
		_blocks[cell.y][cell.x] = null
		if cell.y > _deepest_row:
			_deepest_row = cell.y
	# Пересчитываем, какие из уцелевших блоков открыты для копки
	_refresh_open_states()
	_update_camera()

# Блок открыт, если он в верхнем ряду (поверхность) или у него есть сломанный сосед
func _refresh_open_states() -> void:
	for row in range(ROWS):
		for col in range(COLS):
			var block: Button = _blocks[row][col]
			if block == null:
				continue
			_set_open(block, row == 0 or _has_broken_neighbor(col, row))

func _has_broken_neighbor(col: int, row: int) -> bool:
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for offset in offsets:
		var c: int = col + offset.x
		var r: int = row + offset.y
		if c < 0 or c >= COLS or r < 0 or r >= ROWS:
			continue
		if _blocks[r][c] == null:
			return true
	return false

func _make_block(col: int, row: int) -> Button:
	# Button — самый простой кликабельный элемент, ловит тап из коробки
	var block := Button.new()
	block.custom_minimum_size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	block.position = _origin + Vector2(
		col * (BLOCK_SIZE + GAP),
		row * (BLOCK_SIZE + GAP)
	)
	block.text = ""
	# Координаты клетки храним прямо на узле — пригодятся при тапе
	block.set_meta("col", col)
	block.set_meta("row", row)
	_set_open(block, false)  # по умолчанию всё закрыто
	block.pressed.connect(_on_block_pressed.bind(block))
	add_child(block)
	return block

# Открыт блок или нет: открытый кликабелен и светлый, закрытый — заблокирован и тёмный
func _set_open(block: Button, is_open: bool) -> void:
	block.disabled = not is_open
	block.modulate = COLOR_OPEN if is_open else COLOR_LOCKED

# Реакция на тап по блоку (срабатывает только на открытых — закрытые disabled)
func _on_block_pressed(block: Button) -> void:
	var col: int = block.get_meta("col")
	var row: int = block.get_meta("row")
	_blocks[row][col] = null  # клетка теперь пустая
	_saved_broken[Vector2i(col, row)] = true  # запоминаем в кэш поля
	block.queue_free()
	total_broken += 1
	_update_broken_label()
	# Сломанный блок расчищает соседей — открываем те, что ещё целы
	_open_neighbors(col, row)
	# Если копнули глубже — двигаем камеру за фронтом
	if row > _deepest_row:
		_deepest_row = row
		_update_camera()

# Открываем 4 соседей клетки (если они в пределах поля и ещё не сломаны)
func _open_neighbors(col: int, row: int) -> void:
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for offset in offsets:
		var c: int = col + offset.x
		var r: int = row + offset.y
		if c < 0 or c >= COLS or r < 0 or r >= ROWS:
			continue
		var neighbor: Button = _blocks[r][c]
		if neighbor != null:
			_set_open(neighbor, true)

# Ручная прокрутка поля свайпом/мышью. Тап по блоку обрабатывают сами кнопки,
# сюда долетают только жесты по пустым местам — поэтому копке не мешает.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_scroll_by(event.relative.y)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_scroll_by(event.relative.y)

func _scroll_by(delta_y: float) -> void:
	# Тянем поле вниз — камера едет вверх, и наоборот
	_camera.position.y = clampf(_camera.position.y - delta_y, _cam_min_y(), _cam_max_y())

# Наводим камеру на фронт копки, не вылезая за края поля
func _update_camera() -> void:
	var target_y: float = _origin.y + _deepest_row * (BLOCK_SIZE + GAP) + BLOCK_SIZE * 0.5
	_camera.position = Vector2(
		get_viewport_rect().size.x * 0.5,
		clampf(target_y, _cam_min_y(), _cam_max_y())
	)

# Границы движения камеры по вертикали (центр вьюпорта не выходит за пределы поля)
func _cam_min_y() -> float:
	return get_viewport_rect().size.y * 0.5

func _cam_max_y() -> float:
	var grid_height := ROWS * BLOCK_SIZE + (ROWS - 1) * GAP
	return maxf(_cam_min_y(), _origin.y + grid_height - get_viewport_rect().size.y * 0.5)

func _update_broken_label() -> void:
	_broken_label.text = "Сломано: %d" % total_broken

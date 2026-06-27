extends Node2D

# --- Настройки сетки ---
const COLS := 5          # ширина шахты в блоках
const BLOCK_SIZE := 128  # размер блока в пикселях
const GAP := 2           # зазор между блоками
const TOP_MARGIN := 110  # отступ сверху, чтобы первый ряд не лез под HUD
const LOCKED_DARKEN := 0.5  # насколько затемняем закрытый блок относительно цвета слоя

var _rows := 0           # глубина текущей шахты (из GameState)
var _origin := Vector2.ZERO          # левый верхний угол сетки
var _blocks: Array = []              # 2D-массив блоков: _blocks[row][col], null если сломан
var _deepest_row := 0                # самый глубокий расчищенный ряд (для камеры)
var _camera: Camera2D                # камера, следующая за фронтом копки
var _hud_label: Label                # счётчик/инфо в HUD

func _ready() -> void:
	_build_camera()
	_build_ui()
	_build_grid()

# Камера: едет за расчищенной областью вглубь
func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()

# UI поверх сцены (в CanvasLayer, чтобы не двигался вместе с камерой)
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hud_button(layer, "↻  Обновить", Vector2(16, 16), _on_refresh_pressed)
	_hud_button(layer, "▲  Наверх", Vector2(16, 84), _on_surface_pressed)

	# Счётчик/инфо — по центру верха экрана
	_hud_label = Label.new()
	_hud_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.offset_top = 14
	_hud_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_hud_label)
	_update_hud()

# Кнопка HUD: крупнее, с иконкой-глифом
func _hud_button(parent: CanvasLayer, text: String, pos: Vector2, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(190, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(handler)
	parent.add_child(b)

# Возврат на Базу (с сохранением)
func _on_surface_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://base.tscn")

# Рефреш = чистое поле для текущей шахты. Счётчик и инвентарь НЕ трогаем.
func _on_refresh_pressed() -> void:
	for row_blocks in _blocks:
		for block in row_blocks:
			if block != null:
				block.queue_free()
	_blocks.clear()
	GameState.clear_field(GameState.current_mine)
	_deepest_row = 0
	_build_grid()

# Строим сетку: на каждую клетку — кликабельный блок
func _build_grid() -> void:
	_rows = GameState.total_rows()
	var grid_width := COLS * BLOCK_SIZE + (COLS - 1) * GAP
	_origin = Vector2((get_viewport_rect().size.x - grid_width) * 0.5, TOP_MARGIN)
	for row in range(_rows):
		var row_blocks: Array = []
		for col in range(COLS):
			row_blocks.append(_make_block(col, row))
		_blocks.append(row_blocks)
	# Восстанавливаем сломанные клетки из кэша шахты
	_deepest_row = 0
	for cell in GameState.field_for(GameState.current_mine):
		_blocks[cell.y][cell.x].queue_free()
		_blocks[cell.y][cell.x] = null
		if cell.y > _deepest_row:
			_deepest_row = cell.y
	_refresh_open_states()
	_update_camera()

func _make_block(col: int, row: int) -> Button:
	var block := Button.new()
	block.custom_minimum_size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	block.position = _origin + Vector2(
		col * (BLOCK_SIZE + GAP),
		row * (BLOCK_SIZE + GAP)
	)
	block.text = ""
	var layer := GameState.layer_for_row(row)
	block.set_meta("col", col)
	block.set_meta("row", row)
	block.set_meta("layer", layer)
	block.set_meta("base_color", layer.color)
	block.set_meta("hp", int(layer.hardness))  # остаток прочности; тап снимает силу кирки
	_set_open(block, false)
	block.pressed.connect(_on_block_pressed.bind(block))
	add_child(block)
	_add_icon(block, layer.get("icon", "rock"))
	return block

# Иконка-эмблема по центру блока (рисуется block_icon.gd, клики пропускает)
func _add_icon(block: Button, kind: String) -> void:
	var icon := preload("res://block_icon.gd").new()
	icon.kind = kind
	var icon_size := BLOCK_SIZE * 0.5
	icon.size = Vector2(icon_size, icon_size)
	icon.position = Vector2((BLOCK_SIZE - icon_size) * 0.5, (BLOCK_SIZE - icon_size) * 0.5)
	block.add_child(icon)

# Блок открыт, если его слой разблокирован И (он у поверхности ИЛИ есть сломанный сосед)
func _refresh_open_states() -> void:
	for row in range(_rows):
		for col in range(COLS):
			var block: Button = _blocks[row][col]
			if block == null:
				continue
			var diggable := row == 0 or _has_broken_neighbor(col, row)
			_set_open(block, diggable)

func _has_broken_neighbor(col: int, row: int) -> bool:
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for offset in offsets:
		var c: int = col + offset.x
		var r: int = row + offset.y
		if c < 0 or c >= COLS or r < 0 or r >= _rows:
			continue
		if _blocks[r][c] == null:
			return true
	return false

# Открыт блок или нет: открытый — цвет слоя (с учётом урона), закрытый — затемнён
func _set_open(block: Button, is_open: bool) -> void:
	block.disabled = not is_open
	var base: Color = block.get_meta("base_color")
	if not is_open:
		_paint_block(block, base.darkened(LOCKED_DARKEN))
		return
	# Открытый блок: чем сильнее повреждён, тем темнее («трещины») — но не «лечится»
	var layer: Dictionary = block.get_meta("layer")
	var hp: int = int(block.get_meta("hp"))
	var dmg := 1.0 - float(hp) / float(int(layer.hardness))
	_paint_block(block, base.darkened(0.45 * dmg))

# Красим блок плоским цветом во всех состояниях кнопки (включая disabled)
func _paint_block(block: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		block.add_theme_stylebox_override(state, sb)

# Реакция на тап по блоку (срабатывает только на открытых — закрытые disabled)
func _on_block_pressed(block: Button) -> void:
	var col: int = block.get_meta("col")
	var row: int = block.get_meta("row")
	var layer: Dictionary = block.get_meta("layer")
	# Бьём по блоку: снимаем прочность на силу кирки
	var hp: int = int(block.get_meta("hp")) - GameState.pickaxe_power()
	if hp > 0:
		# Блок ещё цел — обновляем прочность и перерисовываем «трещины»
		block.set_meta("hp", hp)
		_set_open(block, true)
		return
	# Прочность кончилась — блок сломан
	_blocks[row][col] = null
	GameState.field_for(GameState.current_mine)[Vector2i(col, row)] = true
	GameState.break_block(layer.id)  # +счётчик, +инвентарь (×множитель)
	block.queue_free()
	# Дно шахты — забираем артефакт
	if GameState.is_bottom_row(row):
		GameState.collect_artifact()
	_update_hud()
	# Пересчитываем открытость с учётом новых расчищенных соседей
	_refresh_open_states()
	if row > _deepest_row:
		_deepest_row = row
		_update_camera()

# Ручная прокрутка поля свайпом/мышью
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_scroll_by(event.relative.y)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_scroll_by(event.relative.y)

func _scroll_by(delta_y: float) -> void:
	_camera.position.y = clampf(_camera.position.y - delta_y, _cam_min_y(), _cam_max_y())

func _update_camera() -> void:
	var target_y: float = _origin.y + _deepest_row * (BLOCK_SIZE + GAP) + BLOCK_SIZE * 0.5
	_camera.position = Vector2(
		get_viewport_rect().size.x * 0.5,
		clampf(target_y, _cam_min_y(), _cam_max_y())
	)

func _cam_min_y() -> float:
	return get_viewport_rect().size.y * 0.5

func _cam_max_y() -> float:
	var grid_height := _rows * BLOCK_SIZE + (_rows - 1) * GAP
	return maxf(_cam_min_y(), _origin.y + grid_height - get_viewport_rect().size.y * 0.5)

func _update_hud() -> void:
	# Текущий слой у фронта копки и его прочность (сколько урона на блок)
	var cur: Dictionary = GameState.layer_for_row(_deepest_row)
	var taps := ceili(float(cur.hardness) / float(GameState.pickaxe_power()))
	_hud_label.text = "Сломано %d  ×%d\n%s (проч. %d, ~%d тап.)" % [
		GameState.total_broken, GameState.pickaxe_mult(), cur.name, int(cur.hardness), taps
	]

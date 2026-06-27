extends Node2D

# База (поверхность). Продажа блоков, кирка, выбор/смена/переход шахты, спуск.
# UI на контейнерах — растягивается на весь экран.

const FONT_TITLE := 34
const FONT_INFO := 24
const FONT_BTN := 26
const BTN_HEIGHT := 72

var _money_label: Label
var _mine_label: Label
var _pickaxe_button: Button
var _advance_button: Button
var _inventory_label: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Контейнер на весь экран с полями по краям
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	canvas.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := _label("База (поверхность)", FONT_TITLE)
	box.add_child(title)

	_money_label = _label("", FONT_INFO)
	box.add_child(_money_label)

	_mine_label = _label("", FONT_INFO)
	box.add_child(_mine_label)

	box.add_child(HSeparator.new())

	_add_button(box, "Спуститься в шахту", _on_to_mine_pressed)
	_add_button(box, "Продать всё", _on_sell_pressed)
	_pickaxe_button = _add_button(box, "", _on_pickaxe_pressed)
	_add_button(box, "Сменить шахту", _on_switch_pressed)
	_advance_button = _add_button(box, "", _on_advance_pressed)
	_add_button(box, "⟲ Сбросить прогресс (тест)", _on_reset_pressed)

	box.add_child(HSeparator.new())

	# Инвентарь занимает остаток экрана и скроллится
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_inventory_label = _label("", FONT_INFO)
	_inventory_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inventory_label)

	_refresh_ui()

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l

func _add_button(parent: VBoxContainer, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	b.add_theme_font_size_override("font_size", FONT_BTN)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # длинный текст переносится, не вылезает
	b.pressed.connect(handler)
	parent.add_child(b)
	return b

func _refresh_ui() -> void:
	_money_label.text = "Деньги: %d" % GameState.money
	_mine_label.text = "Шахта: %s" % GameState.mine_def().name

	if GameState.has_next_pickaxe():
		_pickaxe_button.text = "Кирка: %s (×%d)\nКупить %s за %d" % [
			GameState.pickaxe_name(), GameState.pickaxe_mult(),
			GameState.pickaxes[GameState.pickaxe_level + 1].name, GameState.next_pickaxe_price()
		]
		_pickaxe_button.disabled = GameState.money < GameState.next_pickaxe_price()
	else:
		_pickaxe_button.text = "Кирка: %s (×%d) — максимум" % [GameState.pickaxe_name(), GameState.pickaxe_mult()]
		_pickaxe_button.disabled = true

	if not GameState.has_next_mine():
		_advance_button.text = "Это последняя шахта"
		_advance_button.disabled = true
	elif GameState.can_advance():
		var next_name: String = GameState.mines[GameState.current_mine + 1].name
		_advance_button.text = "Перейти в шахту: %s" % next_name
		_advance_button.disabled = false
	else:
		_advance_button.text = "Нужен артефакт: %s (выкопай шахту до дна)" % GameState.mine_def().artifact
		_advance_button.disabled = true

	_inventory_label.text = _inventory_text()

func _inventory_text() -> String:
	if GameState.inventory.is_empty():
		return "Инвентарь пуст"
	var lines: Array[String] = ["Инвентарь:"]
	for block_id in GameState.inventory:
		var count: int = GameState.inventory[block_id]
		var sum: int = count * GameState.block_price(block_id)
		lines.append("  %s ×%d — %d" % [GameState.block_name(block_id), count, sum])
	return "\n".join(lines)

func _on_sell_pressed() -> void:
	GameState.sell_all()
	_refresh_ui()

func _on_pickaxe_pressed() -> void:
	if GameState.buy_pickaxe():
		_refresh_ui()

func _on_switch_pressed() -> void:
	var next := (GameState.current_mine + 1) % GameState.unlocked_mines
	GameState.switch_mine(next)
	_refresh_ui()

func _on_advance_pressed() -> void:
	if GameState.advance_mine():
		_refresh_ui()

func _on_reset_pressed() -> void:
	GameState.reset_progress()
	_refresh_ui()

func _on_to_mine_pressed() -> void:
	get_tree().change_scene_to_file("res://mine.tscn")

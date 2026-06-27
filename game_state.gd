extends Node

# Глобальное состояние игры (autoload-синглтон GameState).
# Единый источник истины: деньги, инвентарь, прогресс шахт, кирка, сохранение.

const SAVE_PATH := "user://save.dat"

# --- Сохраняемое состояние ---
var money := 0
var current_mine := 0                # выбранная шахта
var unlocked_mines := 1              # сколько шахт открыто (индексы 0..unlocked_mines-1)
var pickaxe_level := 0               # индекс в pickaxes
var total_broken := 0               # всего сломано блоков (для лидерборда)
var inventory: Dictionary = {}      # id блока -> штук к продаже (с учётом множителя)
var mined_counts: Dictionary = {}   # id блока -> сколько блоков сломано (для гейтинга)
var artifacts: Dictionary = {}      # индекс шахты -> true, если артефакт собран
var field_cache: Dictionary = {}    # индекс шахты -> { Vector2i: true } сломанные клетки

# --- Статические данные (не сохраняются) ---
var mines: Array = []
var pickaxes: Array = []
var _catalog: Dictionary = {}       # id блока -> слой

func _ready() -> void:
	_init_data()
	_build_catalog()
	load_game()

func _notification(what: int) -> void:
	# Сохраняемся при закрытии окна и при сворачивании на мобиле
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

func _init_data() -> void:
	# mult — сколько лута даёт один блок; power — урон за тап (пробивает прочность блока)
	pickaxes = [
		{"name": "Деревянная", "price": 0,      "mult": 1,   "power": 1},
		{"name": "Каменная",   "price": 100,    "mult": 5,   "power": 3},
		{"name": "Железная",   "price": 5000,   "mult": 25,  "power": 10},
		{"name": "Алмазная",   "price": 250000, "mult": 125, "power": 40},
	]
	mines = [
		{
			"name": "Трава", "artifact": "Семя жизни",
			"layers": [
				{"id": "grass",       "name": "Трава",        "price": 1,  "rows": 3, "hardness": 1, "icon": "blades",  "color": Color(0.45, 0.78, 0.30)},
				{"id": "thick_grass", "name": "Густая трава",  "price": 2,  "rows": 3, "hardness": 1, "icon": "blades",  "color": Color(0.30, 0.62, 0.22)},
				{"id": "fern",        "name": "Папоротник",    "price": 4,  "rows": 3, "hardness": 2, "icon": "leaf",    "color": Color(0.36, 0.55, 0.27)},
				{"id": "roots",       "name": "Корни",         "price": 14, "rows": 3, "hardness": 3, "icon": "root",    "color": Color(0.55, 0.40, 0.24)},
				{"id": "sod",         "name": "Дёрн",          "price": 50, "rows": 3, "hardness": 4, "icon": "clod",    "color": Color(0.40, 0.28, 0.18)},
			],
		},
		{
			"name": "Земля", "artifact": "Ядро земли",
			"layers": [
				{"id": "dirt",       "name": "Земля",            "price": 81,  "rows": 3, "hardness": 5,  "icon": "clod",    "color": Color(0.55, 0.40, 0.26)},
				{"id": "clay",       "name": "Глина",            "price": 130, "rows": 3, "hardness": 6,  "icon": "clod",    "color": Color(0.62, 0.46, 0.34)},
				{"id": "wet_clay",   "name": "Влажная глина",    "price": 210, "rows": 3, "hardness": 8,  "icon": "clod",    "color": Color(0.50, 0.38, 0.30)},
				{"id": "gravel",     "name": "Гравий",           "price": 340, "rows": 3, "hardness": 10, "icon": "pebbles", "color": Color(0.55, 0.53, 0.50)},
				{"id": "red_clay",   "name": "Красная глина",    "price": 540, "rows": 3, "hardness": 12, "icon": "clod",    "color": Color(0.65, 0.34, 0.26)},
				{"id": "packed_dirt","name": "Уплотнённый грунт","price": 860, "rows": 3, "hardness": 15, "icon": "layers",  "color": Color(0.42, 0.32, 0.24)},
			],
		},
		{
			"name": "Камень", "artifact": "Сердце скалы",
			"layers": [
				{"id": "cobble",   "name": "Булыжник",     "price": 1400,  "rows": 3, "hardness": 20,  "icon": "pebbles", "color": Color(0.55, 0.55, 0.57)},
				{"id": "stone",    "name": "Камень",       "price": 2200,  "rows": 3, "hardness": 25,  "icon": "rock",    "color": Color(0.50, 0.50, 0.52)},
				{"id": "granite",  "name": "Гранит",       "price": 3400,  "rows": 3, "hardness": 30,  "icon": "rock",    "color": Color(0.60, 0.52, 0.50)},
				{"id": "basalt",   "name": "Базальт",      "price": 5300,  "rows": 3, "hardness": 40,  "icon": "rock",    "color": Color(0.32, 0.32, 0.36)},
				{"id": "shale",    "name": "Сланец",       "price": 8400,  "rows": 3, "hardness": 50,  "icon": "layers",  "color": Color(0.40, 0.42, 0.46)},
				{"id": "copper",   "name": "Медная руда",  "price": 13000, "rows": 3, "hardness": 65,  "icon": "ore",     "color": Color(0.60, 0.45, 0.32)},
				{"id": "iron",     "name": "Железная руда","price": 20000, "rows": 3, "hardness": 80,  "icon": "ore",     "color": Color(0.58, 0.50, 0.46)},
				{"id": "dense",    "name": "Плотный камень","price": 31000,"rows": 3, "hardness": 100, "icon": "rock",    "color": Color(0.38, 0.38, 0.40)},
			],
		},
	]

func _build_catalog() -> void:
	for mine in mines:
		for layer in mine.layers:
			_catalog[layer.id] = layer

# --- Шахта и слои ---

func mine_def() -> Dictionary:
	return mines[current_mine]

func total_rows() -> int:
	var n := 0
	for layer in mines[current_mine].layers:
		n += int(layer.rows)
	return n

# Индекс слоя для ряда (ряд 0 — у поверхности)
func layer_index_for_row(row: int) -> int:
	var layers: Array = mines[current_mine].layers
	var r := row
	for i in range(layers.size()):
		if r < int(layers[i].rows):
			return i
		r -= int(layers[i].rows)
	return layers.size() - 1

func layer_for_row(row: int) -> Dictionary:
	return mines[current_mine].layers[layer_index_for_row(row)]

# Последний (самый глубокий) ряд шахты — там артефакт
func is_bottom_row(row: int) -> bool:
	return row == total_rows() - 1

# --- Кэш поля (по каждой шахте отдельно) ---

func field_for(mine_index: int) -> Dictionary:
	if not field_cache.has(mine_index):
		field_cache[mine_index] = {}
	return field_cache[mine_index]

func clear_field(mine_index: int) -> void:
	field_cache[mine_index] = {}

# --- Добыча, инвентарь, продажа ---

# Сломали блок: +1 к статистике типа, в инвентарь падает множитель кирки
func break_block(block_id: String) -> void:
	total_broken += 1
	mined_counts[block_id] = int(mined_counts.get(block_id, 0)) + 1
	inventory[block_id] = int(inventory.get(block_id, 0)) + pickaxe_mult()

func inventory_count() -> int:
	var n := 0
	for count in inventory.values():
		n += int(count)
	return n

func block_name(block_id: String) -> String:
	return _catalog[block_id].name

func block_price(block_id: String) -> int:
	return int(_catalog[block_id].price)

func sell_all() -> int:
	var earned := 0
	for block_id in inventory:
		earned += int(inventory[block_id]) * block_price(block_id)
	money += earned
	inventory.clear()
	save_game()
	return earned

# --- Кирка ---

func pickaxe_mult() -> int:
	return int(pickaxes[pickaxe_level].mult)

func pickaxe_power() -> int:
	return int(pickaxes[pickaxe_level].power)

func pickaxe_name() -> String:
	return pickaxes[pickaxe_level].name

func has_next_pickaxe() -> bool:
	return pickaxe_level + 1 < pickaxes.size()

func next_pickaxe_price() -> int:
	return int(pickaxes[pickaxe_level + 1].price)

# Покупаем следующую кирку, если хватает денег. true — куплено.
func buy_pickaxe() -> bool:
	if not has_next_pickaxe():
		return false
	var price := next_pickaxe_price()
	if money < price:
		return false
	money -= price
	pickaxe_level += 1
	save_game()
	return true

# --- Артефакт и переход между шахтами ---

func has_artifact(mine_index: int) -> bool:
	return artifacts.get(mine_index, false)

func collect_artifact() -> void:
	if not has_artifact(current_mine):
		artifacts[current_mine] = true
		save_game()

func has_next_mine() -> bool:
	return current_mine + 1 < mines.size()

# Условие перехода на следующую шахту — собран артефакт текущей
func can_advance() -> bool:
	return has_next_mine() and has_artifact(current_mine)

# Переходим на следующую шахту (и открываем её). true — перешли.
func advance_mine() -> bool:
	if not can_advance():
		return false
	current_mine += 1
	unlocked_mines = max(unlocked_mines, current_mine + 1)
	save_game()
	return true

# Переключиться на уже открытую шахту
func switch_mine(mine_index: int) -> void:
	if mine_index >= 0 and mine_index < unlocked_mines:
		current_mine = mine_index
		save_game()

# --- Сохранение / загрузка ---

func save_game() -> void:
	var data := {
		"money": money,
		"current_mine": current_mine,
		"unlocked_mines": unlocked_mines,
		"pickaxe_level": pickaxe_level,
		"total_broken": total_broken,
		"inventory": inventory,
		"mined_counts": mined_counts,
		"artifacts": artifacts,
		"field_cache": field_cache,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось открыть файл сохранения для записи")
		return
	f.store_string(var_to_str(data))
	f.close()

# Тестовый полный сброс: деньги, инвентарь, кирка, шахты, поля — всё в ноль
func reset_progress() -> void:
	money = 0
	current_mine = 0
	unlocked_mines = 1
	pickaxe_level = 0
	total_broken = 0
	inventory.clear()
	mined_counts.clear()
	artifacts.clear()
	field_cache.clear()
	save_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = str_to_var(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	money = int(data.get("money", 0))
	current_mine = int(data.get("current_mine", 0))
	unlocked_mines = int(data.get("unlocked_mines", 1))
	pickaxe_level = int(data.get("pickaxe_level", 0))
	total_broken = int(data.get("total_broken", 0))
	inventory = data.get("inventory", {})
	mined_counts = data.get("mined_counts", {})
	artifacts = data.get("artifacts", {})
	field_cache = data.get("field_cache", {})

extends Control

# Простая иконка-эмблема на блоке, рисуется кодом (без картинок).
# kind — какой мотив рисовать, задаётся при создании блока.

var kind := "rock"

const INK := Color(0, 0, 0, 0.30)        # «гравировка» — тёмный полупрозрачный
const HILITE := Color(1, 1, 1, 0.35)     # светлые крапины (для руды)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # клики проходят сквозь иконку на блок

func _draw() -> void:
	var s := size.x
	match kind:
		"blades":   # трава: три стебелька
			draw_line(Vector2(s * 0.30, s * 0.88), Vector2(s * 0.20, s * 0.22), INK, 3.0)
			draw_line(Vector2(s * 0.50, s * 0.92), Vector2(s * 0.50, s * 0.12), INK, 3.0)
			draw_line(Vector2(s * 0.70, s * 0.88), Vector2(s * 0.80, s * 0.22), INK, 3.0)
		"leaf":     # папоротник: листок с прожилкой
			var leaf := PackedVector2Array([
				Vector2(s * 0.5, s * 0.12), Vector2(s * 0.78, s * 0.5),
				Vector2(s * 0.5, s * 0.88), Vector2(s * 0.22, s * 0.5)])
			draw_colored_polygon(leaf, INK)
			draw_line(Vector2(s * 0.5, s * 0.16), Vector2(s * 0.5, s * 0.84), HILITE, 2.0)
		"root":     # корни: ветвящиеся линии
			draw_line(Vector2(s * 0.5, s * 0.1), Vector2(s * 0.5, s * 0.6), INK, 3.0)
			draw_line(Vector2(s * 0.5, s * 0.6), Vector2(s * 0.25, s * 0.9), INK, 3.0)
			draw_line(Vector2(s * 0.5, s * 0.6), Vector2(s * 0.75, s * 0.9), INK, 3.0)
		"clod":     # земля/дёрн: округлый комок
			draw_circle(Vector2(s * 0.5, s * 0.55), s * 0.28, INK)
		"pebbles":  # гравий: три камешка
			draw_circle(Vector2(s * 0.35, s * 0.45), s * 0.14, INK)
			draw_circle(Vector2(s * 0.62, s * 0.4), s * 0.11, INK)
			draw_circle(Vector2(s * 0.5, s * 0.68), s * 0.13, INK)
		"layers":   # сланец: горизонтальные пласты
			draw_line(Vector2(s * 0.2, s * 0.38), Vector2(s * 0.8, s * 0.38), INK, 3.0)
			draw_line(Vector2(s * 0.2, s * 0.54), Vector2(s * 0.8, s * 0.54), INK, 3.0)
			draw_line(Vector2(s * 0.2, s * 0.70), Vector2(s * 0.8, s * 0.70), INK, 3.0)
		"ore":      # руда: камень с вкраплениями
			draw_circle(Vector2(s * 0.5, s * 0.55), s * 0.28, INK)
			draw_circle(Vector2(s * 0.42, s * 0.5), s * 0.06, HILITE)
			draw_circle(Vector2(s * 0.6, s * 0.62), s * 0.05, HILITE)
		_:          # камень по умолчанию: круглый булыжник
			draw_circle(Vector2(s * 0.5, s * 0.55), s * 0.3, INK)

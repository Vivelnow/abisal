extends Node2D

const COLUMNAS := 8
const FILAS := 12
const COLOR_FONDO := Color("06121f")
const COLOR_LINEA := Color("1e4a66")

func _draw() -> void:
	var pantalla := get_viewport_rect().size
	var lado := minf(pantalla.x / COLUMNAS, pantalla.y / FILAS)
	var ancho := lado * COLUMNAS
	var alto := lado * FILAS
	var origen := Vector2((pantalla.x - ancho) / 2.0, (pantalla.y - alto) / 2.0)

	draw_rect(Rect2(Vector2.ZERO, pantalla), COLOR_FONDO)

	for c in COLUMNAS + 1:
		var x := origen.x + c * lado
		draw_line(Vector2(x, origen.y), Vector2(x, origen.y + alto), COLOR_LINEA, 2.0)

	for f in FILAS + 1:
		var y := origen.y + f * lado
		draw_line(Vector2(origen.x, y), Vector2(origen.x + ancho, y), COLOR_LINEA, 2.0)

extends Node2D

const COLUMNAS := 8
const FILAS := 12
const COLOR_FONDO := Color("06121f")
const COLOR_LINEA := Color("1e4a66")
const COLOR_BUZO := Color("f2c14e")

# Celda donde está el buzo: columna 3, fila 9 (se cuenta desde 0)
var celda_buzo := Vector2i(3, 9)

# Geometría de la cuadrícula (se rellenan en _calcular_geometria)
var lado := 0.0
var origen := Vector2.ZERO

func _calcular_geometria() -> void:
	var pantalla := get_viewport_rect().size
	lado = minf(pantalla.x / COLUMNAS, pantalla.y / FILAS)
	origen = Vector2(
		(pantalla.x - lado * COLUMNAS) / 2.0,
		(pantalla.y - lado * FILAS) / 2.0
	)

func _draw() -> void:
	_calcular_geometria()

	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_FONDO)

	for c in COLUMNAS + 1:
		var x := origen.x + c * lado
		draw_line(Vector2(x, origen.y), Vector2(x, origen.y + lado * FILAS), COLOR_LINEA, 2.0)

	for f in FILAS + 1:
		var y := origen.y + f * lado
		draw_line(Vector2(origen.x, y), Vector2(origen.x + lado * COLUMNAS, y), COLOR_LINEA, 2.0)

	# El buzo: un círculo en el centro de su celda
	var centro := origen + (Vector2(celda_buzo) + Vector2(0.5, 0.5)) * lado
	draw_circle(centro, lado * 0.35, COLOR_BUZO)

extends Node2D

const COLUMNAS := 8
const FILAS := 12
const COLOR_FONDO := Color("06121f")
const COLOR_LINEA := Color("1e4a66")
const COLOR_BUZO := Color("f2c14e")
const COLOR_TOQUE := Color("4ecdc4")

# Celda donde está el buzo: columna 3, fila 9 (se cuenta desde 0)
var celda_buzo := Vector2i(3, 9)

# Última celda tocada válida. -1,-1 = ninguna todavía.
# Solo para verificar el paso 2 con los ojos; paso 3 la usará para mover al buzo de verdad.
var celda_tocada := Vector2i(-1, -1)

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

# Inversa de _calcular_geometria: de posición en píxeles a coordenada de celda
func _posicion_a_celda(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori((pos.x - origen.x) / lado),
		floori((pos.y - origen.y) / lado)
	)

func _celda_valida(celda: Vector2i) -> bool:
	return celda.x >= 0 and celda.x < COLUMNAS and celda.y >= 0 and celda.y < FILAS

func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var hay_toque := false

	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		hay_toque = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position  # en el portátil, el clic cuenta como toque
		hay_toque = true

	if hay_toque:
		var celda := _posicion_a_celda(pos)
		if _celda_valida(celda):
			celda_tocada = celda
			queue_redraw()
		# fuera de la cuadrícula: se ignora, celda_tocada no cambia

func _draw() -> void:
	_calcular_geometria()

	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_FONDO)

	for c in COLUMNAS + 1:
		var x := origen.x + c * lado
		draw_line(Vector2(x, origen.y), Vector2(x, origen.y + lado * FILAS), COLOR_LINEA, 2.0)

	for f in FILAS + 1:
		var y := origen.y + f * lado
		draw_line(Vector2(origen.x, y), Vector2(origen.x + lado * COLUMNAS, y), COLOR_LINEA, 2.0)

	# Marca de depuración del paso 2: contorno en la última celda tocada
	if _celda_valida(celda_tocada):
		var esquina := origen + Vector2(celda_tocada) * lado
		draw_rect(Rect2(esquina, Vector2(lado, lado)), COLOR_TOQUE, false, 3.0)

	# El buzo: un círculo en el centro de su celda
	var centro := origen + (Vector2(celda_buzo) + Vector2(0.5, 0.5)) * lado
	draw_circle(centro, lado * 0.35, COLOR_BUZO)

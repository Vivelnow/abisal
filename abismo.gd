extends Node2D

const COLUMNAS := 8
const FILAS := 12
const COLOR_FONDO := Color("06121f")
const COLOR_LINEA := Color("1e4a66")
const COLOR_BUZO := Color("f2c14e")
const COLOR_ENEMIGO := Color("c1382d")
const COLOR_TOQUE := Color("4ecdc4")
const COLOR_PIP_LLENO := Color("4ecdc4")
const COLOR_PIP_VACIO := Color("1e4a66")

const PUNTOS_ACCION_MAX := 4
const VIDA_MAX_BUZO := 3
const VIDA_MAX_ENEMIGO := 2
const DANO_ATAQUE := 1
const COSTE_ATAQUE := 1
const ALCANCE_ATAQUE := 1  # Chebyshev: solo celda adyacente, diagonal incluida

# Celda donde está el buzo: columna 3, fila 9 (se cuenta desde 0)
var celda_buzo := Vector2i(3, 9)
var vida_buzo := VIDA_MAX_BUZO  # ahora sí puede bajar: el enemigo ataca en su turno

# Enemigo de prueba. Posición fija solo para verificar la mecánica, no es diseño de misión.
var celda_enemigo := Vector2i(5, 7)
var vida_enemigo := VIDA_MAX_ENEMIGO
var enemigo_vivo := true

# Puntos de acción restantes. Se rellenan al empezar cada turno del buzo.
var puntos_accion := PUNTOS_ACCION_MAX

# Última celda tocada válida (dentro de la cuadrícula, alcanzable o no). -1,-1 = ninguna todavía.
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

# Distancia Chebyshev: la diagonal cuenta igual que un paso recto
func _distancia_celdas(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

# Un paso de origen hacia destino, un eje a la vez. Sin rodeos: es la IA mínima, no pathfinding.
func _paso_hacia(origen_celda: Vector2i, destino: Vector2i) -> Vector2i:
	var dx := 0
	var dy := 0
	if destino.x > origen_celda.x:
		dx = 1
	elif destino.x < origen_celda.x:
		dx = -1
	if destino.y > origen_celda.y:
		dy = 1
	elif destino.y < origen_celda.y:
		dy = -1
	return origen_celda + Vector2i(dx, dy)

# El turno del enemigo: si está pegado, ataca; si no, se acerca un paso. Luego vuelve a tocarte a ti.
func _turno_enemigo() -> void:
	if enemigo_vivo:
		var distancia := _distancia_celdas(celda_enemigo, celda_buzo)
		if distancia <= ALCANCE_ATAQUE:
			vida_buzo = maxi(vida_buzo - DANO_ATAQUE, 0)
		else:
			celda_enemigo = _paso_hacia(celda_enemigo, celda_buzo)
	puntos_accion = PUNTOS_ACCION_MAX

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

			if celda == celda_buzo:
				# Tocar tu propia celda termina el turno aunque te queden puntos
				_turno_enemigo()
			elif enemigo_vivo and celda == celda_enemigo:
				var distancia := _distancia_celdas(celda_buzo, celda)
				if distancia <= ALCANCE_ATAQUE and puntos_accion >= COSTE_ATAQUE:
					vida_enemigo -= DANO_ATAQUE
					puntos_accion -= COSTE_ATAQUE
					if vida_enemigo <= 0:
						enemigo_vivo = false
					if puntos_accion <= 0:
						_turno_enemigo()
			else:
				var distancia := _distancia_celdas(celda_buzo, celda)
				if distancia > 0 and distancia <= puntos_accion:
					celda_buzo = celda
					puntos_accion -= distancia
					if puntos_accion <= 0:
						_turno_enemigo()

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

	# Marca de toque: dónde tocaste, aunque no haya movido ni atacado
	if _celda_valida(celda_tocada):
		var esquina := origen + Vector2(celda_tocada) * lado
		draw_rect(Rect2(esquina, Vector2(lado, lado)), COLOR_TOQUE, false, 3.0)

	# El enemigo: un rombo, para distinguirlo del buzo a simple vista
	if enemigo_vivo:
		var centro_e := origen + (Vector2(celda_enemigo) + Vector2(0.5, 0.5)) * lado
		var r := lado * 0.32
		var puntos_rombo := PackedVector2Array([
			centro_e + Vector2(0, -r),
			centro_e + Vector2(r, 0),
			centro_e + Vector2(0, r),
			centro_e + Vector2(-r, 0),
		])
		draw_colored_polygon(puntos_rombo, COLOR_ENEMIGO)

	# El buzo: un círculo en el centro de su celda
	var centro := origen + (Vector2(celda_buzo) + Vector2(0.5, 0.5)) * lado
	draw_circle(centro, lado * 0.35, COLOR_BUZO)

	# HUD esquina superior izquierda: puntos de acción (fila 1) y vida del buzo (fila 2)
	var radio_pip := lado * 0.12
	for i in PUNTOS_ACCION_MAX:
		var c_pip := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 2.0)
		draw_circle(c_pip, radio_pip, COLOR_PIP_LLENO if i < puntos_accion else COLOR_PIP_VACIO)
	for i in VIDA_MAX_BUZO:
		var c_vida := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 5.0)
		draw_circle(c_vida, radio_pip, COLOR_BUZO if i < vida_buzo else COLOR_LINEA)

	# HUD esquina superior derecha: vida del enemigo, mientras esté vivo
	if enemigo_vivo:
		for i in VIDA_MAX_ENEMIGO:
			var c_ve := origen + Vector2(lado * COLUMNAS - radio_pip * 3.0 * i - radio_pip * 2.0, radio_pip * 2.0)
			draw_circle(c_ve, radio_pip, COLOR_ENEMIGO if i < vida_enemigo else COLOR_LINEA)

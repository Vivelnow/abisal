extends Node2D

const COLUMNAS := 8
const FILAS := 12
const COLOR_FONDO := Color("06121f")
const COLOR_LINEA := Color("1e4a66")
const COLOR_PARED := Color("2a4a5e")
const COLOR_PARED_GRIS := Color("1a2e3a")   # pared ya vista pero fuera de la luz
const COLOR_BUZO := Color("f2c14e")
const COLOR_ENEMIGO := Color("c1382d")
const COLOR_TOQUE := Color("4ecdc4")
const COLOR_PIP_LLENO := Color("4ecdc4")
const COLOR_PIP_VACIO := Color("1e4a66")
const COLOR_NIEBLA := Color(0, 0, 0, 0.92)
const COLOR_GRIS := Color(0, 0, 0, 0.70)    # negro más transparente: "recuerdo" de celda vista

const PUNTOS_ACCION_MAX := 4
const VIDA_MAX_BUZO := 3
const VIDA_MAX_ENEMIGO := 2
const DANO_ATAQUE := 1
const COSTE_ATAQUE := 1
const ALCANCE_ATAQUE := 1
const RADIO_LUZ := 3

const PAREDES := [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(2, 3),
	Vector2i(2, 4),
]

# Memoria de celdas que el buzo ha iluminado alguna vez.
# Clave: Vector2i de la celda. Valor: true (solo nos importa si está o no).
var celdas_vistas := {}

func _es_pared(celda: Vector2i) -> bool:
	return celda in PAREDES

# Trazado de rayo (Bresenham) desde el buzo hasta 'destino'.
# Devuelve true si NO hay ninguna pared en el camino (la celda está iluminada).
# Devuelve false si alguna celda de pared interrumpe la línea antes de llegar.
func _tiene_vision(destino: Vector2i) -> bool:
	var x0 := celda_buzo.x
	var y0 := celda_buzo.y
	var x1 := destino.x
	var y1 := destino.y

	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy

	while true:
		# Si llegamos al destino, no hubo pared en medio: hay visión
		if x0 == x1 and y0 == y1:
			return true
		# Si la celda actual (que NO es el buzo ni el destino) es pared, bloquea
		var actual := Vector2i(x0, y0)
		if actual != celda_buzo and _es_pared(actual):
			return false
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

	return true  # nunca se llega aquí, pero GDScript lo exige

# Una celda está iluminada si está dentro del radio Y el buzo tiene visión hasta ella
func _esta_iluminada(celda: Vector2i) -> bool:
	if _distancia_celdas(celda, celda_buzo) > RADIO_LUZ:
		return false
	return _tiene_vision(celda)

# Actualiza el diccionario de celdas vistas con las que están iluminadas ahora
func _actualizar_memoria() -> void:
	for f in FILAS:
		for c in COLUMNAS:
			var celda := Vector2i(c, f)
			if _esta_iluminada(celda):
				celdas_vistas[celda] = true

var celda_buzo := Vector2i(1, 9)
var vida_buzo := VIDA_MAX_BUZO
var celda_enemigo := Vector2i(5, 6)
var vida_enemigo := VIDA_MAX_ENEMIGO
var enemigo_vivo := true
var puntos_accion := PUNTOS_ACCION_MAX
var celda_tocada := Vector2i(-1, -1)
var lado := 0.0
var origen := Vector2.ZERO

func _ready() -> void:
	# Poblamos la memoria con la posición inicial del buzo
	_actualizar_memoria()

func _calcular_geometria() -> void:
	var pantalla := get_viewport_rect().size
	lado = minf(pantalla.x / COLUMNAS, pantalla.y / FILAS)
	origen = Vector2(
		(pantalla.x - lado * COLUMNAS) / 2.0,
		(pantalla.y - lado * FILAS) / 2.0
	)

func _posicion_a_celda(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori((pos.x - origen.x) / lado),
		floori((pos.y - origen.y) / lado)
	)

func _celda_valida(celda: Vector2i) -> bool:
	return celda.x >= 0 and celda.x < COLUMNAS and celda.y >= 0 and celda.y < FILAS

func _distancia_celdas(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

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
	var siguiente := origen_celda + Vector2i(dx, dy)
	if _es_pared(siguiente):
		return origen_celda
	return siguiente

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
		pos = event.position
		hay_toque = true

	if hay_toque:
		var celda := _posicion_a_celda(pos)
		if _celda_valida(celda):
			celda_tocada = celda

			if celda == celda_buzo:
				_turno_enemigo()
				_actualizar_memoria()
			elif enemigo_vivo and celda == celda_enemigo:
				var distancia := _distancia_celdas(celda_buzo, celda)
				if distancia <= ALCANCE_ATAQUE and puntos_accion >= COSTE_ATAQUE:
					vida_enemigo -= DANO_ATAQUE
					puntos_accion -= COSTE_ATAQUE
					if vida_enemigo <= 0:
						enemigo_vivo = false
					if puntos_accion <= 0:
						_turno_enemigo()
						_actualizar_memoria()
			elif not _es_pared(celda):
				var distancia := _distancia_celdas(celda_buzo, celda)
				if distancia > 0 and distancia <= puntos_accion:
					celda_buzo = celda
					puntos_accion -= distancia
					_actualizar_memoria()
					if puntos_accion <= 0:
						_turno_enemigo()

			queue_redraw()

func _draw() -> void:
	_calcular_geometria()

	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_FONDO)

	# Rejilla completa (siempre, debajo de todo)
	for c in COLUMNAS + 1:
		var x := origen.x + c * lado
		draw_line(Vector2(x, origen.y), Vector2(x, origen.y + lado * FILAS), COLOR_LINEA, 2.0)
	for f in FILAS + 1:
		var y := origen.y + f * lado
		draw_line(Vector2(origen.x, y), Vector2(origen.x + lado * COLUMNAS, y), COLOR_LINEA, 2.0)

	# Marca de toque
	if _celda_valida(celda_tocada):
		var esquina := origen + Vector2(celda_tocada) * lado
		draw_rect(Rect2(esquina, Vector2(lado, lado)), COLOR_TOQUE, false, 3.0)

	# Enemigo: solo si está iluminado
	if enemigo_vivo and _esta_iluminada(celda_enemigo):
		var centro_e := origen + (Vector2(celda_enemigo) + Vector2(0.5, 0.5)) * lado
		var r := lado * 0.32
		var puntos_rombo := PackedVector2Array([
			centro_e + Vector2(0, -r),
			centro_e + Vector2(r, 0),
			centro_e + Vector2(0, r),
			centro_e + Vector2(-r, 0),
		])
		draw_colored_polygon(puntos_rombo, COLOR_ENEMIGO)

	# Buzo
	var centro := origen + (Vector2(celda_buzo) + Vector2(0.5, 0.5)) * lado
	draw_circle(centro, lado * 0.35, COLOR_BUZO)

	# Niebla por capas:
	# - Celda iluminada: se ve normal (no pintamos nada encima)
	# - Celda vista antes pero ahora en sombra: gris semitransparente
	#   - Si es pared: color de pared gris
	#   - Si no: negro semitransparente (COLOR_GRIS)
	# - Celda nunca vista: negro casi opaco (COLOR_NIEBLA)
	for f in FILAS:
		for c in COLUMNAS:
			var celda := Vector2i(c, f)
			var esquina_n := origen + Vector2(celda) * lado
			if _esta_iluminada(celda):
				# Iluminada: dibujamos la pared si la hay, nada más
				if _es_pared(celda):
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_PARED)
			elif celda in celdas_vistas:
				# Vista antes: gris
				if _es_pared(celda):
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_PARED_GRIS)
				else:
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_GRIS)
			else:
				# Nunca vista: negro total
				draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_NIEBLA)

	# HUD encima de todo
	var radio_pip := lado * 0.12
	for i in PUNTOS_ACCION_MAX:
		var c_pip := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 2.0)
		draw_circle(c_pip, radio_pip, COLOR_PIP_LLENO if i < puntos_accion else COLOR_PIP_VACIO)
	for i in VIDA_MAX_BUZO:
		var c_vida := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 5.0)
		draw_circle(c_vida, radio_pip, COLOR_BUZO if i < vida_buzo else COLOR_LINEA)
	if enemigo_vivo:
		for i in VIDA_MAX_ENEMIGO:
			var c_ve := origen + Vector2(lado * COLUMNAS - radio_pip * 3.0 * i - radio_pip * 2.0, radio_pip * 2.0)
			draw_circle(c_ve, radio_pip, COLOR_ENEMIGO if i < vida_enemigo else COLOR_LINEA)

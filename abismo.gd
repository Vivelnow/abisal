extends Node2D

const COLUMNAS := 8
const FILAS := 12
const COLOR_FONDO := Color("06121f")
const COLOR_LINEA := Color("1e4a66")
const COLOR_PARED := Color("2a4a5e")
const COLOR_PARED_GRIS := Color("1a2e3a")
const COLOR_BUZO := Color("f2c14e")
const COLOR_BUZO_ACTIVO := Color("ffffff")
const COLOR_ENEMIGO := Color("c1382d")
const COLOR_TOQUE := Color("4ecdc4")
const COLOR_PIP_LLENO := Color("4ecdc4")
const COLOR_PIP_VACIO := Color("1e4a66")
const COLOR_NIEBLA := Color(0, 0, 0, 0.92)
const COLOR_GRIS := Color(0, 0, 0, 0.70)

const PUNTOS_ACCION_MAX := 4
const VIDA_MAX_BUZO := 3
const VIDA_MAX_ENEMIGO := 2
const DANO_ATAQUE := 1
const COSTE_ATAQUE := 1
const ALCANCE_ATAQUE := 1
const RADIO_LUZ := 3
const OXIGENO_MAX := 12
const COLOR_OXIGENO_LLENO := Color("2a9df4")
const COLOR_OXIGENO_BAJO  := Color("e63946")

const PAREDES := [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(2, 3),
	Vector2i(2, 4),
]

var celdas_buzos := [
	Vector2i(1, 9),
	Vector2i(2, 9),
	Vector2i(1, 10),
	Vector2i(2, 10),
]
var vidas_buzos := [VIDA_MAX_BUZO, VIDA_MAX_BUZO, VIDA_MAX_BUZO, VIDA_MAX_BUZO]
var puntos_buzos := [PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX]
var oxigenos_buzos := [OXIGENO_MAX, OXIGENO_MAX, OXIGENO_MAX, OXIGENO_MAX]
var buzos_vivos := [true, true, true, true]
var buzo_activo := 0

var celdas_vistas := [{}, {}, {}, {}]

var celda_enemigo := Vector2i(5, 3)
var vida_enemigo := VIDA_MAX_ENEMIGO
var enemigo_vivo := true

var celda_tocada := Vector2i(-1, -1)
var lado := 0.0
var origen := Vector2.ZERO

func _ready() -> void:
	for i in 4:
		_actualizar_memoria(i)

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

func _es_pared(celda: Vector2i) -> bool:
	return celda in PAREDES

func _celda_ocupada_por_buzo(celda: Vector2i) -> int:
	for i in 4:
		if buzos_vivos[i] and celdas_buzos[i] == celda:
			return i
	return -1

func _tiene_vision(desde: Vector2i, destino: Vector2i) -> bool:
	var x0 := desde.x
	var y0 := desde.y
	var x1 := destino.x
	var y1 := destino.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		if x0 == x1 and y0 == y1:
			return true
		var actual := Vector2i(x0, y0)
		if actual != desde and _es_pared(actual):
			return false
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return true

func _esta_iluminada_por(celda: Vector2i, buzo_idx: int) -> bool:
	if not buzos_vivos[buzo_idx]:
		return false
	if _distancia_celdas(celda, celdas_buzos[buzo_idx]) > RADIO_LUZ:
		return false
	return _tiene_vision(celdas_buzos[buzo_idx], celda)

func _esta_iluminada(celda: Vector2i) -> bool:
	for i in 4:
		if _esta_iluminada_por(celda, i):
			return true
	return false

func _actualizar_memoria(buzo_idx: int) -> void:
	for f in FILAS:
		for c in COLUMNAS:
			var celda := Vector2i(c, f)
			if _esta_iluminada_por(celda, buzo_idx):
				celdas_vistas[buzo_idx][celda] = true

func _celda_en_memoria(celda: Vector2i) -> bool:
	for i in 4:
		if celda in celdas_vistas[i]:
			return true
	return false

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
	if _celda_ocupada_por_buzo(siguiente) >= 0:
		return origen_celda
	return siguiente

func _todos_sin_puntos() -> bool:
	for i in 4:
		if buzos_vivos[i] and puntos_buzos[i] > 0:
			return false
	return true

func _siguiente_buzo_con_puntos() -> int:
	for i in 4:
		var idx := (buzo_activo + 1 + i) % 4
		if buzos_vivos[idx] and puntos_buzos[idx] > 0:
			return idx
	return buzo_activo

func _siguiente_buzo_vivo() -> int:
	# Devuelve el índice del siguiente buzo vivo, o -1 si no queda ninguno.
	for i in 4:
		var idx := (buzo_activo + 1 + i) % 4
		if buzos_vivos[idx]:
			return idx
	return -1

func _aplicar_muerte_buzo(idx: int) -> void:
	# Marca al buzo como muerto y ajusta el buzo activo si era él.
	buzos_vivos[idx] = false
	if idx == buzo_activo:
		var siguiente := _siguiente_buzo_vivo()
		if siguiente >= 0:
			buzo_activo = siguiente

func _turno_enemigo() -> void:
	if enemigo_vivo:
		var distancia := _distancia_celdas(celda_enemigo, celdas_buzos[buzo_activo])
		if distancia <= ALCANCE_ATAQUE:
			vidas_buzos[buzo_activo] = maxi(vidas_buzos[buzo_activo] - DANO_ATAQUE, 0)
			if vidas_buzos[buzo_activo] <= 0:
				_aplicar_muerte_buzo(buzo_activo)
		else:
			celda_enemigo = _paso_hacia(celda_enemigo, celdas_buzos[buzo_activo])
	for i in 4:
		puntos_buzos[i] = PUNTOS_ACCION_MAX

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
		_calcular_geometria()
		var celda := _posicion_a_celda(pos)
		if not _celda_valida(celda):
			return

		celda_tocada = celda
		var idx_tocado := _celda_ocupada_por_buzo(celda)

		if idx_tocado >= 0:
			if idx_tocado == buzo_activo:
				_turno_enemigo()
				for i in 4:
					_actualizar_memoria(i)
			else:
				buzo_activo = idx_tocado
		elif enemigo_vivo and celda == celda_enemigo:
			var distancia := _distancia_celdas(celdas_buzos[buzo_activo], celda)
			if distancia <= ALCANCE_ATAQUE and puntos_buzos[buzo_activo] >= COSTE_ATAQUE:
				vida_enemigo -= DANO_ATAQUE
				puntos_buzos[buzo_activo] -= COSTE_ATAQUE
				if vida_enemigo <= 0:
					enemigo_vivo = false
				if _todos_sin_puntos():
					_turno_enemigo()
					for i in 4:
						_actualizar_memoria(i)
				elif puntos_buzos[buzo_activo] <= 0:
					buzo_activo = _siguiente_buzo_con_puntos()
		elif not _es_pared(celda):
			var distancia := _distancia_celdas(celdas_buzos[buzo_activo], celda)
			if distancia > 0 and distancia <= puntos_buzos[buzo_activo]:
				celdas_buzos[buzo_activo] = celda
				puntos_buzos[buzo_activo] -= distancia
				oxigenos_buzos[buzo_activo] = maxi(oxigenos_buzos[buzo_activo] - distancia, 0)
				_actualizar_memoria(buzo_activo)
				if _todos_sin_puntos():
					_turno_enemigo()
					for i in 4:
						_actualizar_memoria(i)
				elif puntos_buzos[buzo_activo] <= 0:
					buzo_activo = _siguiente_buzo_con_puntos()

		queue_redraw()

func _draw() -> void:
	_calcular_geometria()

	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_FONDO)

	for c in COLUMNAS + 1:
		var x := origen.x + c * lado
		draw_line(Vector2(x, origen.y), Vector2(x, origen.y + lado * FILAS), COLOR_LINEA, 2.0)
	for f in FILAS + 1:
		var y := origen.y + f * lado
		draw_line(Vector2(origen.x, y), Vector2(origen.x + lado * COLUMNAS, y), COLOR_LINEA, 2.0)

	if _celda_valida(celda_tocada):
		var esquina := origen + Vector2(celda_tocada) * lado
		draw_rect(Rect2(esquina, Vector2(lado, lado)), COLOR_TOQUE, false, 3.0)

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

	for i in 4:
		if not buzos_vivos[i]:
			continue
		var centro := origen + (Vector2(celdas_buzos[i]) + Vector2(0.5, 0.5)) * lado
		if i == buzo_activo:
			draw_circle(centro, lado * 0.40, COLOR_BUZO_ACTIVO)
		draw_circle(centro, lado * 0.32, COLOR_BUZO)

	for f in FILAS:
		for c in COLUMNAS:
			var celda := Vector2i(c, f)
			var esquina_n := origen + Vector2(celda) * lado
			if _esta_iluminada(celda):
				if _es_pared(celda):
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_PARED)
			elif _celda_en_memoria(celda):
				if _es_pared(celda):
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_PARED_GRIS)
				else:
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_GRIS)
			else:
				draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_NIEBLA)

	var radio_pip := lado * 0.12
	for i in PUNTOS_ACCION_MAX:
		var c_pip := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 2.0)
		draw_circle(c_pip, radio_pip, COLOR_PIP_LLENO if i < puntos_buzos[buzo_activo] else COLOR_PIP_VACIO)
	for i in VIDA_MAX_BUZO:
		var c_vida := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 5.0)
		draw_circle(c_vida, radio_pip, COLOR_BUZO if i < vidas_buzos[buzo_activo] else COLOR_LINEA)
	if enemigo_vivo:
		for i in VIDA_MAX_ENEMIGO:
			var c_ve := origen + Vector2(lado * COLUMNAS - radio_pip * 3.0 * i - radio_pip * 2.0, radio_pip * 2.0)
			draw_circle(c_ve, radio_pip, COLOR_ENEMIGO if i < vida_enemigo else COLOR_LINEA)

	var centro_activo := origen + (Vector2(celdas_buzos[buzo_activo]) + Vector2(0.5, 0.5)) * lado
	var barra_ancho := lado * 0.14
	var barra_alto  := lado * 0.80
	var barra_x     := centro_activo.x + lado * 0.42
	var barra_y     := centro_activo.y - barra_alto / 2.0
	draw_rect(Rect2(Vector2(barra_x, barra_y), Vector2(barra_ancho, barra_alto)), COLOR_PIP_VACIO)
	var fraccion     := float(oxigenos_buzos[buzo_activo]) / float(OXIGENO_MAX)
	var relleno_alto := barra_alto * fraccion
	var color_o2     := COLOR_OXIGENO_BAJO if fraccion <= 0.25 else COLOR_OXIGENO_LLENO
	draw_rect(
		Rect2(Vector2(barra_x, barra_y + barra_alto - relleno_alto), Vector2(barra_ancho, relleno_alto)),
		color_o2
	)

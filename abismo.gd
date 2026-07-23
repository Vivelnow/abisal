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
const COLOR_TEXTO := Color("ffffff")

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

# --- BUZOS ---
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

# --- ENEMIGOS: ahora son 4, igual que los buzos ---
var celdas_enemigos := [
	Vector2i(5, 1),
	Vector2i(6, 1),
	Vector2i(5, 2),
	Vector2i(6, 2),
]
var vidas_enemigos := [VIDA_MAX_ENEMIGO, VIDA_MAX_ENEMIGO, VIDA_MAX_ENEMIGO, VIDA_MAX_ENEMIGO]
var enemigos_vivos := [true, true, true, true]

# --- ESTADO DE PARTIDA ---
# "jugando", "victoria", "derrota"
var estado := "jugando"

var celda_tocada := Vector2i(-1, -1)
var lado := 0.0
var origen := Vector2.ZERO

func _ready() -> void:
	for i in 4:
		_actualizar_memoria(i)

func _reiniciar() -> void:
	celdas_buzos = [
		Vector2i(1, 9),
		Vector2i(2, 9),
		Vector2i(1, 10),
		Vector2i(2, 10),
	]
	vidas_buzos = [VIDA_MAX_BUZO, VIDA_MAX_BUZO, VIDA_MAX_BUZO, VIDA_MAX_BUZO]
	puntos_buzos = [PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX]
	oxigenos_buzos = [OXIGENO_MAX, OXIGENO_MAX, OXIGENO_MAX, OXIGENO_MAX]
	buzos_vivos = [true, true, true, true]
	buzo_activo = 0
	celdas_vistas = [{}, {}, {}, {}]
	celdas_enemigos = [
		Vector2i(5, 1),
		Vector2i(6, 1),
		Vector2i(5, 2),
		Vector2i(6, 2),
	]
	vidas_enemigos = [VIDA_MAX_ENEMIGO, VIDA_MAX_ENEMIGO, VIDA_MAX_ENEMIGO, VIDA_MAX_ENEMIGO]
	enemigos_vivos = [true, true, true, true]
	estado = "jugando"
	celda_tocada = Vector2i(-1, -1)
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

func _celda_ocupada_por_enemigo(celda: Vector2i) -> int:
	for i in 4:
		if enemigos_vivos[i] and celdas_enemigos[i] == celda:
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
	if _celda_ocupada_por_enemigo(siguiente) >= 0:
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
	for i in 4:
		var idx := (buzo_activo + 1 + i) % 4
		if buzos_vivos[idx]:
			return idx
	return -1

func _aplicar_muerte_buzo(idx: int) -> void:
	buzos_vivos[idx] = false
	if idx == buzo_activo:
		var siguiente := _siguiente_buzo_vivo()
		if siguiente >= 0:
			buzo_activo = siguiente

func _comprobar_fin() -> void:
	# ¿Quedan enemigos vivos?
	var hay_enemigos := false
	for i in 4:
		if enemigos_vivos[i]:
			hay_enemigos = true
			break
	if not hay_enemigos:
		estado = "victoria"
		return
	# ¿Quedan buzos vivos?
	var hay_buzos := false
	for i in 4:
		if buzos_vivos[i]:
			hay_buzos = true
			break
	if not hay_buzos:
		estado = "derrota"

func _turno_enemigo() -> void:
	# Cada enemigo actúa por separado
	for e in 4:
		if not enemigos_vivos[e]:
			continue
		# Busca el buzo vivo más cercano
		var objetivo := -1
		var dist_min := 9999
		for b in 4:
			if not buzos_vivos[b]:
				continue
			var d := _distancia_celdas(celdas_enemigos[e], celdas_buzos[b])
			if d < dist_min:
				dist_min = d
				objetivo = b
		if objetivo < 0:
			continue
		if dist_min <= ALCANCE_ATAQUE:
			vidas_buzos[objetivo] = maxi(vidas_buzos[objetivo] - DANO_ATAQUE, 0)
			if vidas_buzos[objetivo] <= 0:
				_aplicar_muerte_buzo(objetivo)
		else:
			celdas_enemigos[e] = _paso_hacia(celdas_enemigos[e], celdas_buzos[objetivo])
	# Recarga puntos de todos los buzos
	for i in 4:
		puntos_buzos[i] = PUNTOS_ACCION_MAX
	_comprobar_fin()

func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var hay_toque := false

	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		hay_toque = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		hay_toque = true

	if not hay_toque:
		return

	# Si la partida terminó: victoria manda a la base, derrota reinicia la misión
	if estado != "jugando":
		if estado == "victoria":
			get_tree().change_scene_to_file("res://base.tscn")
		else:
			_reiniciar()
			queue_redraw()
		return

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
	else:
		var idx_enemigo := _celda_ocupada_por_enemigo(celda)
		if idx_enemigo >= 0:
			var distancia := _distancia_celdas(celdas_buzos[buzo_activo], celda)
			if distancia <= ALCANCE_ATAQUE and puntos_buzos[buzo_activo] >= COSTE_ATAQUE:
				vidas_enemigos[idx_enemigo] -= DANO_ATAQUE
				puntos_buzos[buzo_activo] -= COSTE_ATAQUE
				if vidas_enemigos[idx_enemigo] <= 0:
					enemigos_vivos[idx_enemigo] = false
				_comprobar_fin()
				if estado == "jugando":
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

	# Dibujar los 4 enemigos
	for e in 4:
		if not enemigos_vivos[e]:
			continue
		if not _esta_iluminada(celdas_enemigos[e]):
			continue
		var centro_e := origen + (Vector2(celdas_enemigos[e]) + Vector2(0.5, 0.5)) * lado
		var r := lado * 0.32
		var puntos_rombo := PackedVector2Array([
			centro_e + Vector2(0, -r),
			centro_e + Vector2(r, 0),
			centro_e + Vector2(0, r),
			centro_e + Vector2(-r, 0),
		])
		draw_colored_polygon(puntos_rombo, COLOR_ENEMIGO)

	# Dibujar los 4 buzos
	for i in 4:
		if not buzos_vivos[i]:
			continue
		var centro := origen + (Vector2(celdas_buzos[i]) + Vector2(0.5, 0.5)) * lado
		if i == buzo_activo:
			draw_circle(centro, lado * 0.40, COLOR_BUZO_ACTIVO)
		draw_circle(centro, lado * 0.32, COLOR_BUZO)

	# Niebla
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

	# HUD
	var radio_pip := lado * 0.12
	for i in PUNTOS_ACCION_MAX:
		var c_pip := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 2.0)
		draw_circle(c_pip, radio_pip, COLOR_PIP_LLENO if i < puntos_buzos[buzo_activo] else COLOR_PIP_VACIO)
	for i in VIDA_MAX_BUZO:
		var c_vida := origen + Vector2(radio_pip * 3.0 * i + radio_pip * 2.0, radio_pip * 5.0)
		draw_circle(c_vida, radio_pip, COLOR_BUZO if i < vidas_buzos[buzo_activo] else COLOR_LINEA)

	# Barra de oxígeno del buzo activo
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

	# Pantalla de fin: victoria o derrota
	if estado != "jugando":
		var pantalla := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, pantalla), Color(0, 0, 0, 0.75))
		var texto := "VICTORIA" if estado == "victoria" else "DERROTA"
		var color_texto := Color("4ecdc4") if estado == "victoria" else Color("c1382d")
		var tam := lado * 1.2
		var pos_texto := Vector2(pantalla.x / 2.0, pantalla.y / 2.0)
		draw_string(
			ThemeDB.fallback_font,
			pos_texto,
			texto,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			int(tam),
			color_texto
		)
		var texto_accion := "Toca para ir a la base" if estado == "victoria" else "Toca para reiniciar"
		draw_string(
			ThemeDB.fallback_font,
			pos_texto + Vector2(0, tam * 1.4),
			texto_accion,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			int(tam * 0.45),
			COLOR_TEXTO
		)

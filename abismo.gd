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
const COLOR_ENEMIGO_DISTANCIA := Color("e0793e")
const COLOR_ENEMIGO_APAGALUCES := Color("9b59b6")
const COLOR_TOQUE := Color("4ecdc4")
const COLOR_PIP_LLENO := Color("4ecdc4")
const COLOR_PIP_VACIO := Color("1e4a66")
const COLOR_NIEBLA := Color(0, 0, 0, 0.92)
const COLOR_GRIS := Color(0, 0, 0, 0.70)
const COLOR_TEXTO := Color("ffffff")

const PUNTOS_ACCION_MAX := 4
const VIDA_MAX_BUZO := 3
# El arma del buzo: cuánto daño hace, cuánto cuesta en puntos de
# acción y a qué distancia llega. Es del jugador, no del enemigo —
# lo que cada tipo de criatura hace con SU ataque vive en la ficha
# (fichas_criaturas.gd), no aquí.
const DANO_ATAQUE := 1
const COSTE_ATAQUE := 1
const ALCANCE_ATAQUE := 1
const RADIO_LUZ := 3
const OXIGENO_MAX := 40
const DANO_ASFIXIA := 1
const COLOR_OXIGENO_LLENO := Color("2a9df4")
const COLOR_OXIGENO_BAJO  := Color("e63946")

# --- LA SALIDA (submarino) ---
const CELDA_SALIDA := Vector2i(1, 11)
const COLOR_SALIDA := Color("5ec98f")
const COLOR_SALIDA_GRIS := Color("2f5a45")
const COLOR_BOTON := Color("1e4a66")
const COLOR_BOTON_ACT := Color("2a9df4")

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
# Radio de luz por buzo. Antes RADIO_LUZ era una única constante para
# los 4 — el apagaluces necesita poder dejar a UNO sin luz sin tocar
# a los demás, así que cada buzo lleva ahora el suyo. Empiezan todos
# igual a RADIO_LUZ; el apagaluces pone uno a 0.
var radios_luz_buzos := [RADIO_LUZ, RADIO_LUZ, RADIO_LUZ, RADIO_LUZ]
# Turnos que le quedan a cada buzo sin luz. 0 = ve con normalidad.
# Al llegar a 0 se le devuelve su radio_luz_buzos.
var turnos_sin_luz_buzos := [0, 0, 0, 0]
var buzos_vivos := [true, true, true, true]
var buzo_activo := 0

var celdas_vistas := [{}, {}, {}, {}]

# --- ENEMIGOS ---
# Un solo saco por enemigo: cada elemento lleva dentro su celda, su
# vida, su tipo y si sigue vivo. Antes eran tres listas paralelas
# (celdas_enemigos, vidas_enemigos, enemigos_vivos) y bastaba con que
# una se desalineara para que el enemigo 3 tuviera la vida del 2.
# Con esto, desalinearse ya no es posible: no hay tres listas que
# alinear, hay una.
var enemigos := [
	{"celda": Vector2i(5, 1), "tipo": "distancia", "vida": FichasCriaturas.FICHAS["distancia"]["vida"], "vivo": true},
	{"celda": Vector2i(6, 1), "tipo": "mele", "vida": FichasCriaturas.FICHAS["mele"]["vida"], "vivo": true},
	{"celda": Vector2i(5, 2), "tipo": "mele", "vida": FichasCriaturas.FICHAS["mele"]["vida"], "vivo": true},
	{"celda": Vector2i(6, 2), "tipo": "apagaluces", "vida": FichasCriaturas.FICHAS["apagaluces"]["vida"], "vivo": true},
]

# --- ESTADO DE PARTIDA ---
# "jugando", "victoria", "derrota"
var estado := "jugando"

var celda_tocada := Vector2i(-1, -1)
var lado := 0.0
var origen := Vector2.ZERO
var boton_zarpar_rect := Rect2()

# F2.4 — Carga la vida y quién sigue vivo desde la "mochila" (Autoload
# DatosPartida), en vez de empezar siempre con los 4 buzos sanos.
#
# El .duplicate() es obligatorio: en GDScript los Array se pasan por
# REFERENCIA. Sin duplicate(), vidas_buzos y DatosPartida.vidas_guardadas
# serían el mismo array en memoria, y cualquier golpe durante la misión
# mutaría directamente los datos guardados antes de que la misión termine.
#
# Si el buzo activo (índice 0 por defecto) llegó muerto de la misión
# anterior, se pasa el turno inicial al primer buzo vivo que haya.
func _cargar_equipo_desde_mochila() -> void:
	vidas_buzos = DatosPartida.vidas_guardadas.duplicate()
	buzos_vivos = DatosPartida.buzos_vivos_guardados.duplicate()
	buzo_activo = 0
	if not buzos_vivos[buzo_activo]:
		var vivo := _siguiente_buzo_vivo()
		if vivo >= 0:
			buzo_activo = vivo

func _ready() -> void:
	_cargar_equipo_desde_mochila()
	for i in 4:
		_actualizar_memoria(i)

func _reiniciar() -> void:
	celdas_buzos = [
		Vector2i(1, 9),
		Vector2i(2, 9),
		Vector2i(1, 10),
		Vector2i(2, 10),
	]
	# Recarga el mismo equipo con el que se empezó esta misión (no vida
	# completa a pelo): reintentar tiene que ser fiel al estado real,
	# si no, perder y reiniciar se convertiría en curarse gratis.
	_cargar_equipo_desde_mochila()
	puntos_buzos = [PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX, PUNTOS_ACCION_MAX]
	oxigenos_buzos = [OXIGENO_MAX, OXIGENO_MAX, OXIGENO_MAX, OXIGENO_MAX]
	radios_luz_buzos = [RADIO_LUZ, RADIO_LUZ, RADIO_LUZ, RADIO_LUZ]
	turnos_sin_luz_buzos = [0, 0, 0, 0]
	celdas_vistas = [{}, {}, {}, {}]
	enemigos = [
		{"celda": Vector2i(5, 1), "tipo": "distancia", "vida": FichasCriaturas.FICHAS["distancia"]["vida"], "vivo": true},
		{"celda": Vector2i(6, 1), "tipo": "mele", "vida": FichasCriaturas.FICHAS["mele"]["vida"], "vivo": true},
		{"celda": Vector2i(5, 2), "tipo": "mele", "vida": FichasCriaturas.FICHAS["mele"]["vida"], "vivo": true},
		{"celda": Vector2i(6, 2), "tipo": "apagaluces", "vida": FichasCriaturas.FICHAS["apagaluces"]["vida"], "vivo": true},
	]
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
	boton_zarpar_rect = Rect2(
		0,
		pantalla.y - lado * 1.1,
		pantalla.x,
		lado * 1.1
	)

# Cuenta cuántos buzos vivos están ahora mismo sobre la celda de salida.
func _buzos_a_bordo() -> int:
	var cuenta := 0
	for i in 4:
		if buzos_vivos[i] and celdas_buzos[i] == CELDA_SALIDA:
			cuenta += 1
	return cuenta

# Zarpar: quien esté sobre la salida se salva, quien no, se abandona
# (buzos_vivos = false, permanente, igual que morir en combate).
func _zarpar() -> void:
	for i in 4:
		if buzos_vivos[i] and celdas_buzos[i] != CELDA_SALIDA:
			buzos_vivos[i] = false
	# Exterminar es una vía válida hacia la victoria, nunca obligatoria:
	# la otra vía es cumplir el objetivo de la misión (todavía no
	# existe en código — llegará con el roster real, DISEÑO §6). Si al
	# zarpar no queda ningún enemigo, victoria; si queda alguno, es una
	# retirada — te vas sin acabar.
	var hay_enemigos := false
	for i in 4:
		if enemigos[i]["vivo"]:
			hay_enemigos = true
			break
	estado = "victoria" if not hay_enemigos else "retirada"

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
		if enemigos[i]["vivo"] and enemigos[i]["celda"] == celda:
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
	if _distancia_celdas(celda, celdas_buzos[buzo_idx]) > radios_luz_buzos[buzo_idx]:
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

# Espejo de _paso_hacia(): un paso en la dirección contraria a la
# amenaza, en vez de hacia ella. Para el apagaluces huyendo. A
# diferencia de _paso_hacia() (que siempre camina hacia un buzo, y
# por tanto nunca puede salirse del mapa), alejarse sí puede empujar
# hacia el borde — de ahí la comprobación de límites que aquí hace
# falta y allí no.
func _paso_lejos_de(origen_celda: Vector2i, amenaza: Vector2i) -> Vector2i:
	var dx := 0
	var dy := 0
	if amenaza.x > origen_celda.x:
		dx = -1
	elif amenaza.x < origen_celda.x:
		dx = 1
	if amenaza.y > origen_celda.y:
		dy = -1
	elif amenaza.y < origen_celda.y:
		dy = 1
	var siguiente := origen_celda + Vector2i(dx, dy)
	if not _celda_valida(siguiente):
		return origen_celda
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
	# Derrota: no queda ningún buzo vivo. La victoria ya NO se decide
	# aquí — se decide al zarpar (ver _zarpar()), para que exterminar
	# nunca sea obligatorio (lección del género, DISEÑO §10: nunca
	# "busca al último enemigo escondido").
	var hay_buzos := false
	for i in 4:
		if buzos_vivos[i]:
			hay_buzos = true
			break
	if not hay_buzos:
		estado = "derrota"

func _turno_enemigo() -> void:
	# Cada enemigo actúa por separado. Buscar a quién atacar es igual
	# para cualquier tipo de criatura; qué hace con ese objetivo ya no
	# lo es. Añadir un tipo nuevo será escribir una función
	# "_decidir_<tipo>()" y una línea en el match — sin tocar esta.
	for e in 4:
		if not enemigos[e]["vivo"]:
			continue
		var objetivo := _buzo_vivo_mas_cercano(enemigos[e]["celda"])
		if objetivo < 0:
			continue
		match enemigos[e]["tipo"]:
			"mele":
				_decidir_mele(e, objetivo)
			"distancia":
				_decidir_distancia(e, objetivo)
			"apagaluces":
				_decidir_apagaluces(e, objetivo)

	# El mar cobra por turno, no solo por moverse: cada buzo vivo gasta
	# 1 de oxígeno al cerrar la ronda, se haya movido o no. Sin esto,
	# quedarse quieto salía gratis y era la jugada óptima.
	#
	# A oxígeno 0 fuera de la salida empieza la agonía: -1 de vida por
	# ronda hasta que llegue a la salida o se quede sin vida. No es
	# muerte instantánea — el jugador tiene margen para reaccionar y
	# corregir el rumbo, y la barra en rojo ya avisó una ronda antes
	# (DISEÑO §10.7: ningún enemigo, y el mar tampoco, mata sin aviso).
	for i in 4:
		if not buzos_vivos[i]:
			continue
		oxigenos_buzos[i] = maxi(oxigenos_buzos[i] - 1, 0)
		if oxigenos_buzos[i] <= 0 and celdas_buzos[i] != CELDA_SALIDA:
			vidas_buzos[i] = maxi(vidas_buzos[i] - DANO_ASFIXIA, 0)
			if vidas_buzos[i] <= 0:
				_aplicar_muerte_buzo(i)

	# El apagaluces no hace daño: dejó a un buzo sin luz por un número
	# de rondas (turnos_sin_luz_buzos). Aquí se cumple la cuenta atrás
	# y, al llegar a 0, se le devuelve su radio de luz normal.
	for i in 4:
		if not buzos_vivos[i]:
			continue
		if turnos_sin_luz_buzos[i] > 0:
			turnos_sin_luz_buzos[i] -= 1
			if turnos_sin_luz_buzos[i] == 0:
				radios_luz_buzos[i] = RADIO_LUZ

	# Recarga puntos de todos los buzos
	for i in 4:
		puntos_buzos[i] = PUNTOS_ACCION_MAX
	_comprobar_fin()

# Busca, entre los buzos vivos, el más cercano a una celda dada.
# Común a cualquier tipo de criatura: todas necesitan saber a quién
# tienen más cerca antes de decidir qué hacer con él.
func _buzo_vivo_mas_cercano(desde: Vector2i) -> int:
	var objetivo := -1
	var dist_min := 9999
	for b in 4:
		if not buzos_vivos[b]:
			continue
		var d := _distancia_celdas(desde, celdas_buzos[b])
		if d < dist_min:
			dist_min = d
			objetivo = b
	return objetivo

# Comportamiento del melé: si el objetivo está a su alcance, ataca;
# si no, avanza un paso hacia él. Vida, daño y alcance salen de su
# ficha (fichas_criaturas.gd), no de una constante compartida.
func _decidir_mele(idx_enemigo: int, objetivo: int) -> void:
	var ficha: Dictionary = FichasCriaturas.FICHAS["mele"]
	var distancia := _distancia_celdas(enemigos[idx_enemigo]["celda"], celdas_buzos[objetivo])
	if distancia <= ficha["alcance"]:
		vidas_buzos[objetivo] = maxi(vidas_buzos[objetivo] - int(ficha["dano"]), 0)
		if vidas_buzos[objetivo] <= 0:
			_aplicar_muerte_buzo(objetivo)
	else:
		enemigos[idx_enemigo]["celda"] = _paso_hacia(enemigos[idx_enemigo]["celda"], celdas_buzos[objetivo])

# Comportamiento de la distancia: mismo esqueleto que el melé (ataca
# si puede, si no avanza), pero con dos diferencias.
# Primera: su alcance (4) es mayor que RADIO_LUZ (3), así que en
# cuanto está a 4 de un buzo ya puede dispararle sin haber entrado
# en su luz — el daño llega sin que el jugador vea de dónde, tal
# como pide DISEÑO §5. Segunda, y es la que de verdad la distingue
# del melé: "el buzo más cercano" (el objetivo que ya llega
# calculado) no siempre es un tiro posible — puede estar detrás de
# un muro. Por eso no dispara directamente al objetivo recibido:
# busca entre TODOS los buzos vivos si hay alguno disparable de
# verdad (a su alcance y con línea de visión real) y le dispara a
# ese, aunque no sea el más cercano en línea recta. Si ninguno es
# disparable, se acerca al más cercano igualmente — puede que solo
# le falte un paso para tener tiro. No se le añade lógica de huida:
# DISEÑO dice que cae rápido si llegas a ella, así que se queda y
# dispara en cuanto puede.
func _decidir_distancia(idx_enemigo: int, objetivo: int) -> void:
	var ficha: Dictionary = FichasCriaturas.FICHAS["distancia"]
	var celda_enemigo: Vector2i = enemigos[idx_enemigo]["celda"]
	var objetivo_disparable := _buzo_disparable(celda_enemigo, int(ficha["alcance"]))
	if objetivo_disparable >= 0:
		vidas_buzos[objetivo_disparable] = maxi(vidas_buzos[objetivo_disparable] - int(ficha["dano"]), 0)
		if vidas_buzos[objetivo_disparable] <= 0:
			_aplicar_muerte_buzo(objetivo_disparable)
	else:
		enemigos[idx_enemigo]["celda"] = _paso_hacia(celda_enemigo, celdas_buzos[objetivo])

# Busca, entre los buzos vivos, el más cercano al que SÍ se le puede
# disparar de verdad: dentro de alcance Y con línea de visión real.
# Distinto de _buzo_vivo_mas_cercano(), que ignora paredes — esa
# sirve para saber hacia dónde caminar, esta para saber a quién se
# puede herir. Devuelve -1 si ningún buzo vivo es disparable ahora.
func _buzo_disparable(desde: Vector2i, alcance: int) -> int:
	var objetivo := -1
	var dist_min := 9999
	for b in 4:
		if not buzos_vivos[b]:
			continue
		var d := _distancia_celdas(desde, celdas_buzos[b])
		if d <= alcance and d < dist_min and _tiene_vision(desde, celdas_buzos[b]):
			dist_min = d
			objetivo = b
	return objetivo

# Comportamiento del apagaluces: golpea y se retira, cada vez que
# puede. Si está a su alcance, ataca — deja al buzo sin luz
# (turnos_ceguera de la ficha, 0 de daño: DISEÑO §5 es explícito en
# que no hace daño directo) — y en la MISMA ronda da un paso
# alejándose (_paso_lejos_de en vez de _paso_hacia). Si el paso de
# retirada fuera a la ronda siguiente, se quedaría plantado justo
# donde acaba de atacar y el buzo cegado lo tendría a tiro para
# rematarlo gratis. Un solo paso no lo hace invulnerable, pero le da
# opción de escapar en vez de regalar la revancha. No queda ninguna
# marca permanente: a la ronda siguiente vuelve a comportarse con
# normalidad y puede acercarse y golpear de nuevo — al mismo buzo o
# a otro — tantas veces como el jugador se lo permita.
func _decidir_apagaluces(idx_enemigo: int, objetivo: int) -> void:
	var ficha: Dictionary = FichasCriaturas.FICHAS["apagaluces"]
	var celda_enemigo: Vector2i = enemigos[idx_enemigo]["celda"]
	var distancia := _distancia_celdas(celda_enemigo, celdas_buzos[objetivo])
	if distancia <= ficha["alcance"]:
		radios_luz_buzos[objetivo] = 0
		turnos_sin_luz_buzos[objetivo] = int(ficha["turnos_ceguera"])
		enemigos[idx_enemigo]["celda"] = _paso_lejos_de(celda_enemigo, celdas_buzos[objetivo])
	else:
		enemigos[idx_enemigo]["celda"] = _paso_hacia(celda_enemigo, celdas_buzos[objetivo])

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

	# Si la partida terminó: victoria/retirada mandan a la base, derrota reinicia
	if estado != "jugando":
		if estado == "victoria" or estado == "retirada":
			# Guardamos en la mochila los datos de la misión que acaba de
			# terminar, antes de cambiar a la escena de base. Piezas a 0:
			# todavía no existe un sistema que las cuente (decisión 24/07).
			DatosPartida.guardar_partida(vidas_buzos, buzos_vivos, 0)
			get_tree().change_scene_to_file("res://base.tscn")
		else:
			_reiniciar()
			queue_redraw()
		return

	_calcular_geometria()

	# ¿Tocó el botón de Zarpar? Solo hace algo si hay al menos 1 a bordo.
	if boton_zarpar_rect.has_point(pos):
		if _buzos_a_bordo() > 0:
			_zarpar()
			queue_redraw()
		return

	var celda := _posicion_a_celda(pos)
	if not _celda_valida(celda):
		return

	celda_tocada = celda
	var idx_tocado := _celda_ocupada_por_buzo(celda)

	if idx_tocado == buzo_activo:
		# Tocar tu propio buzo activo: fin de turno manual. Vale también
		# estando en la salida.
		_turno_enemigo()
		for i in 4:
			_actualizar_memoria(i)
	elif idx_tocado >= 0 and celda != CELDA_SALIDA:
		# Tocar a otro buzo fuera de la salida: lo seleccionas.
		buzo_activo = idx_tocado
	else:
		# Celda vacía, o la salida con otro buzo ya dentro: intenta
		# moverte o atacar. Esto es lo que permite que varios buzos se
		# junten en la salida antes de zarpar.
		var idx_enemigo := _celda_ocupada_por_enemigo(celda)
		if idx_enemigo >= 0:
			var distancia := _distancia_celdas(celdas_buzos[buzo_activo], celda)
			if distancia <= ALCANCE_ATAQUE and puntos_buzos[buzo_activo] >= COSTE_ATAQUE:
				enemigos[idx_enemigo]["vida"] -= DANO_ATAQUE
				puntos_buzos[buzo_activo] -= COSTE_ATAQUE
				if enemigos[idx_enemigo]["vida"] <= 0:
					enemigos[idx_enemigo]["vivo"] = false
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
				# Llegar a 0 aquí no mata al instante: la barra se pone
				# roja y avisa, pero la agonía (pérdida de vida) solo
				# empieza a cobrarse al cerrar la ronda, en
				# _turno_enemigo(). Da una ronda entera de aviso antes
				# del primer punto de daño.
				if estado == "jugando":
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
		if not enemigos[e]["vivo"]:
			continue
		if not _esta_iluminada(enemigos[e]["celda"]):
			continue
		var centro_e := origen + (Vector2(enemigos[e]["celda"]) + Vector2(0.5, 0.5)) * lado
		var r := lado * 0.32
		var puntos_rombo := PackedVector2Array([
			centro_e + Vector2(0, -r),
			centro_e + Vector2(r, 0),
			centro_e + Vector2(0, r),
			centro_e + Vector2(-r, 0),
		])
		var colores_por_tipo := {
			"distancia": COLOR_ENEMIGO_DISTANCIA,
			"apagaluces": COLOR_ENEMIGO_APAGALUCES,
		}
		var color_rombo: Color = colores_por_tipo.get(enemigos[e]["tipo"], COLOR_ENEMIGO)
		draw_colored_polygon(puntos_rombo, color_rombo)

	# Dibujar los 4 buzos
	for i in 4:
		if not buzos_vivos[i]:
			continue
		var centro := origen + (Vector2(celdas_buzos[i]) + Vector2(0.5, 0.5)) * lado
		# Aro de ceguera: mismo principio que el de agonía, visible esté
		# o no seleccionado el buzo. Reutiliza el color del apagaluces
		# — el aro "firma" quién te lo hizo. Radio mayor que el de
		# agonía para que, si algún día coinciden, se vean los dos.
		if turnos_sin_luz_buzos[i] > 0:
			draw_circle(centro, lado * 0.52, COLOR_ENEMIGO_APAGALUCES, false, 4.0)
		# Aro de agonía: visible esté o no seleccionado el buzo. Sin esto,
		# la única pista de que alguien se está ahogando eran los pips de
		# vida del HUD, y esos solo muestran al buzo activo — invisible
		# si el que agoniza no es el que tienes seleccionado.
		if oxigenos_buzos[i] <= 0 and celdas_buzos[i] != CELDA_SALIDA:
			draw_circle(centro, lado * 0.46, COLOR_OXIGENO_BAJO, false, 4.0)
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
				elif celda == CELDA_SALIDA:
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_SALIDA)
			elif _celda_en_memoria(celda):
				if _es_pared(celda):
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_PARED_GRIS)
				elif celda == CELDA_SALIDA:
					draw_rect(Rect2(esquina_n, Vector2(lado, lado)), COLOR_SALIDA_GRIS)
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

	# Botón Zarpar — solo mientras se está jugando
	if estado == "jugando":
		var a_bordo := _buzos_a_bordo()
		var puede_zarpar := a_bordo > 0
		draw_rect(boton_zarpar_rect, COLOR_BOTON_ACT if puede_zarpar else COLOR_BOTON)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(boton_zarpar_rect.position.x, boton_zarpar_rect.position.y + boton_zarpar_rect.size.y * 0.65),
			"Zarpar (%d a bordo)" % a_bordo,
			HORIZONTAL_ALIGNMENT_CENTER,
			boton_zarpar_rect.size.x,
			int(lado * 0.4),
			COLOR_TEXTO
		)

	# Pantalla de fin: victoria, retirada o derrota
	if estado != "jugando":
		var pantalla := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, pantalla), Color(0, 0, 0, 0.75))
		var texto := "VICTORIA"
		var color_texto := Color("4ecdc4")
		if estado == "derrota":
			texto = "DERROTA"
			color_texto = Color("c1382d")
		elif estado == "retirada":
			texto = "RETIRADA"
			color_texto = Color("f2c14e")
		var tam := lado * 1.2
		var pos_texto := Vector2(0, pantalla.y / 2.0)
		draw_string(
			ThemeDB.fallback_font,
			pos_texto,
			texto,
			HORIZONTAL_ALIGNMENT_CENTER,
			pantalla.x,
			int(tam),
			color_texto
		)
		var texto_accion := "Toca para reiniciar" if estado == "derrota" else "Toca para ir a la base"
		draw_string(
			ThemeDB.fallback_font,
			pos_texto + Vector2(0, tam * 1.4),
			texto_accion,
			HORIZONTAL_ALIGNMENT_CENTER,
			pantalla.x,
			int(tam * 0.45),
			COLOR_TEXTO
		)

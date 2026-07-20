extends Node2D

# La pantalla de base aparece entre misiones.
# Muestra el estado de los 4 buzos y permite curarlos antes de la siguiente misión.

const COLOR_FONDO      := Color("06121f")
const COLOR_TEXTO      := Color("ffffff")
const COLOR_BUZO       := Color("f2c14e")
const COLOR_VIDA_LLENA := Color("4ecdc4")
const COLOR_VIDA_VACIA := Color("1e4a66")
const COLOR_BOTON      := Color("1e4a66")
const COLOR_BOTON_ACT  := Color("2a9df4")
const COLOR_MUERTO     := Color("2a2a2a")

const VIDA_MAX := 3

# Estos datos llegan desde la escena de misión al cambiar de escena.
# Los recibimos a través del Autoload "DatosPartida" (lo crearemos después).
# Por ahora los inicializamos aquí para que la pantalla funcione sola.
var vidas       := [3, 2, 1, 3]   # vida actual de cada buzo
var buzos_vivos := [true, true, true, true]
var piezas      := 2               # piezas recuperadas en la misión

var boton_curar_rect  := []   # guardamos los rectángulos de los botones para detectar toques
var boton_mision_rect := Rect2()

var lado   := 0.0
var origen := Vector2.ZERO

func _ready() -> void:
	# Precalculamos la geometría una sola vez al arrancar
	_calcular_geometria()
	# Construimos los rectángulos de los botones
	_construir_botones()

func _calcular_geometria() -> void:
	var pantalla := get_viewport_rect().size
	# Usamos el mismo sistema de referencia que la misión: lado basado en la cuadrícula
	lado = minf(pantalla.x / 8.0, pantalla.y / 12.0)
	origen = Vector2(
		(pantalla.x - lado * 8.0) / 2.0,
		(pantalla.y - lado * 12.0) / 2.0
	)

func _construir_botones() -> void:
	var pantalla := get_viewport_rect().size
	boton_curar_rect.clear()
	# Un botón de curar por buzo, en la fila de cada uno
	for i in 4:
		var y := origen.y + lado * 2.0 + i * lado * 2.2
		var rect := Rect2(
			pantalla.x - origen.x - lado * 2.5,
			y + lado * 0.2,
			lado * 2.2,
			lado * 0.8
		)
		boton_curar_rect.append(rect)
	# Botón de siguiente misión, al fondo
	boton_mision_rect = Rect2(
		origen.x,
		origen.y + lado * 10.5,
		lado * 8.0,
		lado * 1.2
	)

func _input(event: InputEvent) -> void:
	var pos    := Vector2.ZERO
	var toque  := false

	if event is InputEventScreenTouch and event.pressed:
		pos   = event.position
		toque = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos   = event.position
		toque = true

	if not toque:
		return

	# ¿Tocó el botón de siguiente misión?
	if boton_mision_rect.has_point(pos):
		# Ir a la escena de misión
		get_tree().change_scene_to_file("res://abismo.tscn")
		return

	# ¿Tocó algún botón de curar?
	for i in 4:
		if not buzos_vivos[i]:
			continue
		if vidas[i] >= VIDA_MAX:
			continue
		if piezas <= 0:
			continue
		if boton_curar_rect[i].has_point(pos):
			vidas[i] += 1
			piezas -= 1
			queue_redraw()
			return

func _draw() -> void:
	var pantalla := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, pantalla), COLOR_FONDO)

	# Título
	var tam_titulo := lado * 0.7
	draw_string(
		ThemeDB.fallback_font,
		Vector2(pantalla.x / 2.0, origen.y + lado * 0.9),
		"BASE — CIZH",
		HORIZONTAL_ALIGNMENT_CENTER, -1, int(tam_titulo), COLOR_TEXTO
	)

	# Piezas disponibles
	var tam_texto := lado * 0.45
	draw_string(
		ThemeDB.fallback_font,
		Vector2(pantalla.x / 2.0, origen.y + lado * 1.7),
		"Piezas recuperadas: " + str(piezas),
		HORIZONTAL_ALIGNMENT_CENTER, -1, int(tam_texto), COLOR_VIDA_LLENA
	)

	# Fila por buzo
	for i in 4:
		var y := origen.y + lado * 2.0 + i * lado * 2.2

		# Nombre del buzo
		var nombre := "Buzo " + str(i + 1)
		var color_nombre := COLOR_MUERTO if not buzos_vivos[i] else COLOR_TEXTO
		draw_string(
			ThemeDB.fallback_font,
			Vector2(origen.x + lado * 0.2, y + lado * 0.7),
			nombre,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam_texto), color_nombre
		)

		if not buzos_vivos[i]:
			draw_string(
				ThemeDB.fallback_font,
				Vector2(origen.x + lado * 2.5, y + lado * 0.7),
				"CAÍDO",
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam_texto), COLOR_MUERTO
			)
			continue

		# Pips de vida
		var radio := lado * 0.18
		for v in VIDA_MAX:
			var cx := origen.x + lado * 2.5 + v * lado * 0.55
			var cy := y + lado * 0.55
			draw_circle(
				Vector2(cx, cy),
				radio,
				COLOR_VIDA_LLENA if v < vidas[i] else COLOR_VIDA_VACIA
			)

		# Botón curar (solo si tiene vida perdida y hay piezas)
		var rect: Rect2 = boton_curar_rect[i]
		var puede_curar: bool = vidas[i] < VIDA_MAX and piezas > 0
		draw_rect(rect, COLOR_BOTON_ACT if puede_curar else COLOR_BOTON)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y * 0.72),
			"Curar (1)",
			HORIZONTAL_ALIGNMENT_CENTER, -1, int(tam_texto * 0.85),
			COLOR_TEXTO if puede_curar else COLOR_VIDA_VACIA
		)

	# Botón siguiente misión
	draw_rect(boton_mision_rect, COLOR_BOTON_ACT)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(boton_mision_rect.position.x + boton_mision_rect.size.x / 2.0,
				boton_mision_rect.position.y + boton_mision_rect.size.y * 0.72),
		"Siguiente misión →",
		HORIZONTAL_ALIGNMENT_CENTER, -1, int(tam_texto), COLOR_TEXTO
	)

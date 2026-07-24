extends Node

# --- DatosPartida: la "mochila" que sobrevive al cambio de escena ---
# Este script se registra como Autoload (Proyecto -> Configuración del
# proyecto -> Autoload). Godot lo mantiene cargado todo el tiempo,
# sin importar por cuántas escenas pases.
#
# abismo.gd escribe aquí justo antes de cambiar a base.tscn.
# base.gd lee de aquí en su _ready().

# Vida actual de cada uno de los 4 buzos al terminar la misión.
var vidas_guardadas: Array = [3, 3, 3, 3]

# Quién sigue vivo (true) y quién ha caído (false), en el mismo orden.
var buzos_vivos_guardados: Array = [true, true, true, true]

# Piezas recuperadas en la misión. Placeholder a 0: todavía no existe
# ningún sistema que cuente piezas dentro de abismo.gd (decisión 24/07,
# se diseña más adelante junto con la economía de Fase 3).
var piezas_guardadas: int = 0

# guardar_partida() la llama abismo.gd justo antes de cambiar de escena.
# Recibe los datos de la misión que acaba de terminar y los mete en la
# mochila para que base.gd los pueda leer después.
func guardar_partida(vidas: Array, vivos: Array, piezas: int) -> void:
	vidas_guardadas = vidas.duplicate()
	buzos_vivos_guardados = vivos.duplicate()
	piezas_guardadas = piezas

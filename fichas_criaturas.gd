extends RefCounted
class_name FichasCriaturas

# --- FICHAS DE CRIATURAS ---
# Una entrada por tipo de enemigo. Cambiar el equilibrio de una
# criatura (subirle la vida, bajarle el alcance) es editar los
# números de aquí — nunca hace falta tocar abismo.gd para eso.
# Carril 2 de la metodología: provisional, se ajusta jugando.
#
#   vida:    puntos de vida al aparecer.
#   dano:    daño que inflige cuando ataca a un buzo. 0 si su ataque
#            no quita vida (el apagaluces no hace daño directo — su
#            "dano" vive en un campo propio, turnos_ceguera).
#   alcance: distancia (Chebyshev) a la que puede atacar sin moverse.
#
# El comportamiento (qué hace con ese alcance y ese daño) no vive
# aquí: vive en su propia función "_decidir_<tipo>()" en abismo.gd.
# Esta ficha es solo números.
const FICHAS := {
	"mele": {
		"vida": 2,
		"dano": 1,
		"alcance": 1,
	},
	"distancia": {
		"vida": 1,
		"dano": 1,
		"alcance": 4,
	},
	"apagaluces": {
		"vida": 2,
		"dano": 0,
		"alcance": 1,
		"turnos_ceguera": 3,
	},
}

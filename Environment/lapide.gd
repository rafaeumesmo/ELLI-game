extends CharacterBody2D
## Lapide do CaracolBebe (ver caracol.gd::_virar_lapide). Cai e assenta sozinha
## no chao que existir na hora -- o bloco onde o bebe morreu pode ja ter sido
## destruido depois disso, entao nao da pra confiar numa posicao calculada.
## Decorativa: so colide com parede/chao (layer "parede"), nunca com o player.

## Desiste de cair depois deste tempo (buraco/lava embaixo, sem chao por perto).
@export var tempo_max_queda: float = 2.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _tempo_caindo: float = 0.0

func _physics_process(delta: float) -> void:
	if is_on_floor():
		set_physics_process(false)
		return
	_tempo_caindo += delta
	if _tempo_caindo >= tempo_max_queda:
		set_physics_process(false)
		return
	velocity.y += gravity * delta
	move_and_slide()

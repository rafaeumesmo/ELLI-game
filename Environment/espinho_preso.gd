extends Area2D
## Espinho preso a outra coisa (ex.: embaixo de um BlocoQueCai) -- machuca ao
## encostar e continua machucando enquanto o corpo fica parado nele. Sendo
## filho de outro no, ele se move junto (ex.: cai junto com o bloco que cair).
## Mesma logica de dano do spike_trap.gd, so que sem subir/descer sozinho.

@export var intervalo_dano: float = 0.5
## Se desligado, o espinho começa sem machucar ninguém -- alguém precisa
## chamar ativar() depois (ex.: o BlocoQueCai chama ao começar a cair).
@export var comeca_ativo: bool = true

@onready var _timer: Timer = $DamageTimer

func _ready() -> void:
	monitoring = comeca_ativo
	body_entered.connect(_on_body_entered)
	_timer.timeout.connect(_on_timer_timeout)

## Liga o dano. Chamado pelo bloco que o carrega quando ele começa a cair.
func ativar() -> void:
	monitoring = true

func _on_body_entered(body: Node) -> void:
	_machucar(body)

func _machucar(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(body.max_health)
		_timer.start(intervalo_dano)
	elif body.is_in_group("enemy") and body.has_method("die"):
		body.die()

## Enquanto o player continuar em cima do espinho, repete o dano.
func _on_timer_timeout() -> void:
	var ainda_tocando := false
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(body.max_health)
			ainda_tocando = true
	if ainda_tocando:
		_timer.start(intervalo_dano)

extends Node2D

## Trap de espinhos: quando player ou inimigo entra na zona de gatilho, um pedaco
## de chao (3 blocos + espinhos) sobe rapido do buraco, causa dano, fica exposto
## um instante e recolhe. O bloco e solido, entao empurra quem estiver em cima.
## Posicione o no com a origem na altura do topo do chao onde os blocos param.

## Enquanto o player ficar parado em cima dos espinhos expostos, leva dano de novo
## a cada este intervalo (em segundos) — nao e so um hit unico na entrada.
@export var damage_interval: float = 0.5
## Tempo que os espinhos levam para saltar do chao.
@export var rise_time: float = 0.08
## Tempo que os espinhos ficam expostos antes de recolher.
@export var exposed_time: float = 0.9
## Tempo que os espinhos levam para voltar ao chao.
@export var retract_time: float = 0.35
## Espera depois de recolher antes do trap poder disparar de novo.
@export var rearm_delay: float = 1.0
## Distancia vertical que os espinhos percorrem para sair do chao.
@export var rise_height: float = 24.0

@onready var trigger: Area2D = $Trigger
@onready var riser: AnimatableBody2D = $Riser
@onready var hitbox: Area2D = $Riser/Hitbox
@onready var damage_timer: Timer = $DamageTimer

var _hidden_pos: Vector2
var _armed: bool = true

func _ready() -> void:
	_hidden_pos = riser.position
	trigger.body_entered.connect(_on_trigger_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	damage_timer.timeout.connect(_on_damage_timer_timeout)

func _on_trigger_body_entered(body: Node) -> void:
	if not _armed:
		return
	if body.is_in_group("player") or body.is_in_group("enemy"):
		_spring()

func _spring() -> void:
	_armed = false
	# Processa no passo de fisica pra o bloco solido empurrar quem esta em cima.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(riser, "position", _hidden_pos - Vector2(0.0, rise_height), rise_time)
	tween.tween_callback(_on_spikes_up)
	tween.tween_interval(exposed_time)
	tween.tween_property(riser, "position", _hidden_pos, retract_time)
	tween.tween_interval(rearm_delay)
	tween.tween_callback(func() -> void: _armed = true)

func _on_spikes_up() -> void:
	# Pega quem ja estava parado em cima dos espinhos quando eles subiram.
	for body in hitbox.get_overlapping_bodies():
		_hurt(body)

## Os espinhos machucam sempre que encostados neles, nao importa se estao
## subindo, expostos, recolhendo ou ja recolhidos (parados).
func _on_hitbox_body_entered(body: Node) -> void:
	_hurt(body)

func _hurt(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(body.max_health)
		# Reinicia a contagem: se o player continuar parado nos espinhos,
		# o timeout abaixo bate nele de novo em vez de so uma vez.
		damage_timer.start(damage_interval)
	elif body.is_in_group("enemy") and body.has_method("die"):
		body.die()

## Enquanto o player continuar em cima do hitbox, repete o dano.
func _on_damage_timer_timeout() -> void:
	var still_touching := false
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(body.max_health)
			still_touching = true
	if still_touching:
		damage_timer.start(damage_interval)

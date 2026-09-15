extends Node2D

## Trap de serra: uma serra gira sem parar e, de tempos em tempos, sobe do chao
## (mesmo movimento do SpikeTrap), fica exposta um instante e recolhe. Diferente
## do espinho, ela dispara sozinha num intervalo fixo -- nao depende do player
## estar por perto -- pra dar ritmo numa pista de obstaculos. A lamina mata a
## qualquer contato, parada ou em movimento, subindo, descendo ou no alto.
## Posicione o no com a origem na altura do topo do chao onde a serra para
## quando sobe.

## Velocidade de rotacao da serra (radianos por segundo), sempre girando.
@export var spin_speed: float = 10.0
## Intervalo entre o inicio de uma subida e o inicio da proxima.
@export var interval: float = 4.0
## Tempo que a serra leva para saltar do chao.
@export var rise_time: float = 0.15
## Tempo que a serra fica exposta antes de recolher.
@export var exposed_time: float = 1.2
## Tempo que a serra leva para voltar ao chao.
@export var retract_time: float = 0.35
## Distancia vertical que a serra percorre para sair do chao.
@export var rise_height: float = 24.0
## Atraso antes do primeiro ciclo. Use pra escalonar varias serras numa
## pista de obstaculos, pra nao subirem todas juntas.
@export var start_delay: float = 0.0

@onready var riser: AnimatableBody2D = $Riser
@onready var visual: Polygon2D = $Riser/Visual
@onready var hitbox: Area2D = $Riser/Hitbox

var _hidden_pos: Vector2

func _ready() -> void:
	_hidden_pos = riser.position
	# Sem trava de estado: mata parada, subindo, descendo ou no alto.
	hitbox.body_entered.connect(_hurt)
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_start_loop()

func _process(delta: float) -> void:
	visual.rotation += spin_speed * delta

func _start_loop() -> void:
	# Processa no passo de fisica pra o bloco solido empurrar quem esta em cima.
	var tween := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(riser, "position", _hidden_pos - Vector2(0.0, rise_height), rise_time)
	tween.tween_interval(exposed_time)
	tween.tween_property(riser, "position", _hidden_pos, retract_time)
	var rest := interval - rise_time - exposed_time - retract_time
	tween.tween_interval(max(rest, 0.0))

func _hurt(body: Node) -> void:
	# Serra girando mata na hora, igual ao MovingSaw -- diferente do espinho,
	# que so tira uma parte da vida.
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(body.max_health)
	elif body.is_in_group("enemy") and body.has_method("die"):
		body.die()

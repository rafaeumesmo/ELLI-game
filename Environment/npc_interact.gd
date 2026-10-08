extends Area2D
## Componente de conversa reutilizável: instancie NPCInteract.tscn como filho
## de qualquer NPC, preencha `dialogo` e `personagem` e pronto. Com o player
## dentro da área aparece um "!" sobre o NPC; apertando interagir (E) começa a
## conversa no DialogueManager, com a caixa ancorada no NPC (o pai deste nó).

@export var dialogo: DialogueData
## Quem é este NPC na conversa -- as falas desse personagem saem em cima dele.
@export var personagem: CharacterData
## Só deixa começar com o player no chão (senão ele congelaria no ar).
@export var exigir_chao: bool = true
## Para o NPC (physics_process + animação) enquanto conversa.
@export var pausar_npc: bool = true
## Altura do "!" acima do NPC, em px locais.
@export var altura_indicador: float = 16.0
## Abre a conversa sozinho na 1a vez que o player chega perto (depois só com E).
@export var abrir_sozinho: bool = false
## Libera o dash do player quando a conversa termina (ver player.desbloquear_dash).
@export var desbloquear_dash: bool = false

@onready var _indicador: Sprite2D = $Indicador

var _player: Node2D
var _tempo := 0.0
var _ja_conversou := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_indicador.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null

func _process(delta: float) -> void:
	_tempo += delta
	if abrir_sozinho and not _ja_conversou and _pode_iniciar():
		_iniciar()
	_indicador.visible = _player != null and not DialogueManager.is_active
	if _indicador.visible:
		_indicador.position.y = -altura_indicador - (1.0 if fmod(_tempo, 0.8) < 0.4 else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagir") or event.is_echo():
		return
	if not _pode_iniciar():
		return
	get_viewport().set_input_as_handled()
	_iniciar()

func _pode_iniciar() -> bool:
	if _player == null or dialogo == null or DialogueManager.is_active:
		return false
	return not (exigir_chao and _player is CharacterBody2D and not (_player as CharacterBody2D).is_on_floor())

func _iniciar() -> void:
	_ja_conversou = true
	var npc := get_parent() as Node2D
	var falantes := {}
	if personagem != null and npc != null:
		falantes[personagem.id] = npc
	if pausar_npc and npc != null:
		_pausar(npc, true)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished.bind(npc), CONNECT_ONE_SHOT)
	DialogueManager.start(dialogo, falantes)

func _on_dialogue_finished(_d: DialogueData, npc: Variant) -> void:
	if pausar_npc and is_instance_valid(npc):
		_pausar(npc, false)
	var player := get_tree().get_first_node_in_group("player")
	if desbloquear_dash and player != null and player.has_method("desbloquear_dash"):
		player.desbloquear_dash()

func _pausar(npc: Node2D, pausar: bool) -> void:
	if not is_instance_valid(npc):
		return
	npc.set_physics_process(not pausar)
	var sprite := npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		if pausar:
			sprite.pause()
		else:
			sprite.play()

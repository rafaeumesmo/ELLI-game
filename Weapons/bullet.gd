extends Area2D

@export var speed: float = 500.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()

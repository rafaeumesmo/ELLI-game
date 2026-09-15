extends Area2D

@export var damage: int = 2
@export var damage_interval: float = 0.5

@onready var damage_timer: Timer = $DamageTimer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	damage_timer.timeout.connect(_on_damage_timer_timeout)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_deal_damage(body)
		damage_timer.start(damage_interval)
	elif body.is_in_group("enemy") and body.has_method("die"):
		body.die()

func _on_damage_timer_timeout() -> void:
	var still_touching := false
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_deal_damage(body)
			still_touching = true
	if still_touching:
		damage_timer.start(damage_interval)

func _deal_damage(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)

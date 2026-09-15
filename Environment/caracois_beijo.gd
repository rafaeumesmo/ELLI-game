@tool
extends Node2D
## Par de caracóis se beijando — cenário decorativo puro, sem lógica de jogo.
## Solte esta cena dentro do nó "Cenario" do mapa quantas vezes quiser.
## Os caracóis ficam parados; só os coraçõezinhos saem voando do beijo, em loop.

@export var intervalo_min: float = 0.5
@export var intervalo_max: float = 1.1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_loop_coracoes()

func _loop_coracoes() -> void:
	while is_inside_tree():
		_spawnar_coracao()
		await get_tree().create_timer(randf_range(intervalo_min, intervalo_max)).timeout

## Cria um coraçãozinho no ponto do beijo, que sobe com uma deriva lateral
## aleatória, some e se destrói sozinho.
func _spawnar_coracao() -> void:
	var coracao := Label.new()
	coracao.text = "♥"
	coracao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coracao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coracao.add_theme_color_override("font_color", Color(0.9, 0.08, 0.1))
	coracao.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.85))
	coracao.add_theme_constant_override("outline_size", 2)
	coracao.add_theme_font_size_override("font_size", int(randf_range(4.0, 6.0)))
	coracao.size = Vector2(16, 16)
	coracao.pivot_offset = coracao.size * 0.5
	coracao.position = Vector2(-8, -18)
	coracao.modulate.a = 0.0
	coracao.z_index = 5
	add_child(coracao)

	var pos_final := coracao.position + Vector2(randf_range(-8.0, 8.0), -randf_range(14.0, 22.0))
	var duracao := randf_range(1.1, 1.6)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(coracao, "position", pos_final, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(coracao, "modulate:a", 1.0, duracao * 0.25)
	tw.set_parallel(false)
	tw.tween_interval(duracao * 0.5)
	tw.tween_property(coracao, "modulate:a", 0.0, duracao * 0.35)
	tw.tween_callback(coracao.queue_free)

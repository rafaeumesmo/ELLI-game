extends Node

const SAVE_PATH := "user://savegame.save"

var checkpoint_scene: String = ""
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_camera_path: String = ""
var checkpoint_active: bool = false

## O player ja pegou a espada (commitado no checkpoint). Vale entre fases e persiste
## no arquivo. So volta a false num jogo novo (clear_save).
var tem_espada: bool = false

## O player ja desbloqueou o dash (commitado no checkpoint, mesmo esquema da
## espada). Comeca desligado -- so liga quando alguma fase futura desbloquear.
var tem_dash: bool = false

## O caracol bebe (eh_bebe em caracol.gd) ja morreu nesta run. Diferente dos
## outros caracois, isso NAO depende de checkpoint -- fica true assim que ele
## morre e e' escrito no arquivo na hora (ver registrar_bebe_morto).
var bebe_morto: bool = false
## O player morreu na fase depois de ja ter matado o caracol bebe. A partir daqui
## o bebe vira uma lapide permanente onde estava, pra sempre (ver
## caracol.gd::_virar_lapide). So volta a false num jogo novo (clear_save).
var bebe_lapide: bool = false

## Estado do mundo "congelado" no ultimo checkpoint: NAO volta ao renascer.
## Caracois: caminho do no dentro da cena. Blocos: "x,y" da celula.
var _caracois_mortos: Dictionary = {}
var _blocos_quebrados: Dictionary = {}
## Mortes / quebras desde o ultimo checkpoint. Sao descartadas ao renascer e viram
## permanentes quando o player toca o proximo checkpoint.
var _caracois_mortos_pendentes: Dictionary = {}
var _blocos_quebrados_pendentes: Dictionary = {}
## Checkpoints que o player ja ativou alguma vez ("cena|x,y"). Usado pra curar so
## na primeira ativacao de cada um.
var _checkpoints_ativados: Dictionary = {}

func set_checkpoint(scene_path: String, pos: Vector2, camera_path: String = "") -> void:
	if scene_path != checkpoint_scene:
		# Trocou de fase: o estado do mundo antigo nao vale mais.
		_caracois_mortos.clear()
		_blocos_quebrados.clear()
	checkpoint_scene = scene_path
	checkpoint_position = pos
	checkpoint_camera_path = camera_path
	checkpoint_active = true
	# Congela tudo que morreu / quebrou ate aqui: nao renasce mais.
	_caracois_mortos.merge(_caracois_mortos_pendentes)
	_blocos_quebrados.merge(_blocos_quebrados_pendentes)
	_caracois_mortos_pendentes.clear()
	_blocos_quebrados_pendentes.clear()
	_write_save()

func has_checkpoint(scene_path: String) -> bool:
	return checkpoint_active and checkpoint_scene == scene_path

func clear_checkpoint() -> void:
	checkpoint_scene = ""
	checkpoint_position = Vector2.ZERO
	checkpoint_camera_path = ""
	checkpoint_active = false
	_limpar_estado_mundo()

func save_progress(scene_path: String) -> void:
	checkpoint_scene = scene_path
	checkpoint_position = Vector2.ZERO
	checkpoint_camera_path = ""
	checkpoint_active = false
	_limpar_estado_mundo()
	_write_save()

# --- Estado do mundo: caracois mortos / blocos quebrados ---

## caracol.gd chama isto quando um caracol morre.
func registrar_caracol_morto(id: String) -> void:
	_caracois_mortos_pendentes[id] = true

## blocos_layer.gd chama isto quando uma celula e destruida.
func registrar_bloco_quebrado(cell: Vector2i) -> void:
	_blocos_quebrados_pendentes[_chave_celula(cell)] = true

## Ao renascer no checkpoint: joga fora o que morreu / quebrou depois dele.
func descartar_pendentes() -> void:
	_caracois_mortos_pendentes.clear()
	_blocos_quebrados_pendentes.clear()

## Este caracol (pelo caminho na cena) ficou morto de vez neste checkpoint?
func caracol_esta_morto(scene_path: String, id: String) -> bool:
	return has_checkpoint(scene_path) and _caracois_mortos.has(id)

## Celulas que devem comecar destruidas nesta cena (Array[Vector2i]).
func celulas_quebradas(scene_path: String) -> Array:
	if not has_checkpoint(scene_path):
		return []
	var out: Array = []
	for chave in _blocos_quebrados:
		out.append(_celula_da_chave(chave))
	return out

func _limpar_estado_mundo() -> void:
	_caracois_mortos.clear()
	_blocos_quebrados.clear()
	_caracois_mortos_pendentes.clear()
	_blocos_quebrados_pendentes.clear()
	_checkpoints_ativados.clear()

# --- Checkpoints ja ativados (pra curar so na primeira vez) ---

func _chave_checkpoint(scene_path: String, pos: Vector2) -> String:
	return "%s|%d,%d" % [scene_path, roundi(pos.x), roundi(pos.y)]

## O player ja ativou este checkpoint alguma vez?
func checkpoint_ja_ativado(scene_path: String, pos: Vector2) -> bool:
	return _checkpoints_ativados.has(_chave_checkpoint(scene_path, pos))

## Marca este checkpoint como ja ativado.
func registrar_checkpoint_ativado(scene_path: String, pos: Vector2) -> void:
	_checkpoints_ativados[_chave_checkpoint(scene_path, pos)] = true

func _chave_celula(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _celula_da_chave(chave: String) -> Vector2i:
	var partes := chave.split(",")
	if partes.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(partes[0]), int(partes[1]))

# --- Arquivo ---

func _write_save() -> void:
	var data := {
		"scene": checkpoint_scene,
		"checkpoint_active": checkpoint_active,
		"position_x": checkpoint_position.x,
		"position_y": checkpoint_position.y,
		"camera_path": checkpoint_camera_path,
		"tem_espada": tem_espada,
		"tem_dash": tem_dash,
		"bebe_morto": bebe_morto,
		"bebe_lapide": bebe_lapide,
		"caracois_mortos": _caracois_mortos.keys(),
		"blocos_quebrados": _blocos_quebrados.keys(),
		"checkpoints_ativados": _checkpoints_ativados.keys(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

## Chamado por caracol.gd quando o caracol bebe morre (eh_bebe = true).
## Grava na hora -- diferente da espada/dash, nao espera um checkpoint/portal.
func registrar_bebe_morto() -> void:
	if bebe_morto:
		return
	bebe_morto = true
	_write_save()

## Chamado por player.gd ao morrer. Se o bebe ja estiver morto, trava a lapide
## de vez: ele nunca mais renasce, mesmo depois de um checkpoint.
func marcar_lapide_bebe() -> void:
	if not bebe_morto or bebe_lapide:
		return
	bebe_lapide = true
	_write_save()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_progress() -> String:
	if not has_save():
		return ""
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	checkpoint_scene = parsed.get("scene", "")
	checkpoint_active = parsed.get("checkpoint_active", false)
	checkpoint_position = Vector2(parsed.get("position_x", 0.0), parsed.get("position_y", 0.0))
	checkpoint_camera_path = parsed.get("camera_path", "")
	tem_espada = parsed.get("tem_espada", false)
	tem_dash = parsed.get("tem_dash", false)
	bebe_morto = parsed.get("bebe_morto", false)
	bebe_lapide = parsed.get("bebe_lapide", false)
	_caracois_mortos = _lista_para_set(parsed.get("caracois_mortos", []))
	_blocos_quebrados = _lista_para_set(parsed.get("blocos_quebrados", []))
	_checkpoints_ativados = _lista_para_set(parsed.get("checkpoints_ativados", []))
	_caracois_mortos_pendentes.clear()
	_blocos_quebrados_pendentes.clear()
	return checkpoint_scene

func _lista_para_set(lista: Variant) -> Dictionary:
	var out: Dictionary = {}
	if lista is Array:
		for item in lista:
			out[str(item)] = true
	return out

func clear_save() -> void:
	checkpoint_scene = ""
	checkpoint_position = Vector2.ZERO
	checkpoint_camera_path = ""
	checkpoint_active = false
	tem_espada = false
	tem_dash = false
	bebe_morto = false
	bebe_lapide = false
	_limpar_estado_mundo()
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

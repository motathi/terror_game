extends Node3D
## Diretor de cena 3D: monta o cenário, posiciona o elenco nos slots,
## controla câmera POV (com as mãos do jogador), efeitos de luz e súplicas.

const AssetLib := preload("res://scripts/stage/asset_lib.gd")
const Locations := preload("res://scripts/stage/locations.gd")
const Actor := preload("res://scripts/stage/actor.gd")

var title_font: Font
var body_font: Font
var post_material: ShaderMaterial  # material do pós-processo (flash/blackout)

var camera: Camera3D
var env: Environment
var hands: Node3D
var location_id := ""
var location_cfg: Dictionary = {}
var actors: Dictionary = {}  # slot -> Actor
var _location_root: Node3D
var _actors_root: Node3D
var _cam_base := Transform3D()
var _t := 0.0
var _shake := 0.0
var _walk := 0.0      # segundos restantes de "câmera andando" (balanço de passos)
var _walk_amp := 0.0
var _node_cam := Transform3D()  # câmera do nó atual (para "camera_voltar")
var _cam_tween: Tween


func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	we.environment = env
	add_child(we)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH  # tela em pé: garante os 2 personagens na largura
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 60.0
	camera.current = true
	add_child(camera)

	_build_hands()
	# luz suave "do jogador": ilumina o rosto de quem está na frente
	var face_light := OmniLight3D.new()
	face_light.light_color = Color(1.0, 0.9, 0.8)
	face_light.light_energy = 0.55
	face_light.omni_range = 4.5
	face_light.position = Vector3(0, 0.2, 0.3)
	camera.add_child(face_light)

	_location_root = Node3D.new()
	add_child(_location_root)
	_actors_root = Node3D.new()
	add_child(_actors_root)


func set_location(id: String, force := false) -> void:
	if id == location_id and not force:
		return
	location_id = id
	clear_cast()
	for c in _location_root.get_children():
		c.queue_free()
	location_cfg = Locations.build(id, _location_root)
	env.ambient_light_color = location_cfg["ambient"]
	env.ambient_light_energy = location_cfg["ambient_energy"]
	env.fog_light_color = location_cfg["fog_color"]
	env.fog_density = location_cfg["fog_density"]
	var cam_pos: Vector3 = location_cfg["camera_pos"]
	camera.transform = Transform3D(Basis(), cam_pos).looking_at(location_cfg["camera_look"], Vector3.UP)
	_cam_base = camera.transform
	_node_cam = _cam_base
	_walk = 0.0
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()  # movimento de câmera do cenário anterior não continua aqui
	hands.visible = location_cfg.get("hands", true)
	_view_key = ""
	_loc_view = {}
	for k in ["slot_dist", "slot_spread", "center_dist", "camera_pos", "camera_look"]:
		_loc_view[k] = location_cfg.get(k)


var _view_key := ""
var _loc_view: Dictionary = {}


## Câmera/distâncias só para um nó da história ("camera" no JSON):
## {"pos": [x,y,z], "olhar": [x,y,z], "slot_dist": 1.9, "slot_spread": 0.45,
##  "center_dist": 3.0}. Nó sem "camera" volta ao padrão do cenário.
## Devolve true se mudou (o elenco é refeito nas novas posições).
func apply_node_view(view: Dictionary) -> bool:
	var key := JSON.stringify(view)
	if key == _view_key:
		return false
	_view_key = key
	clear_cast()
	for k in ["slot_dist", "slot_spread", "center_dist"]:
		location_cfg[k] = view.get(k, _loc_view.get(k))
	var pos: Vector3 = _loc_view.get("camera_pos", Vector3(0, 1.62, 0))
	var look: Vector3 = _loc_view.get("camera_look", Vector3(0, 1.45, -3))
	if view.has("pos"):
		pos = Vector3(view["pos"][0], view["pos"][1], view["pos"][2])
	if view.has("olhar"):
		look = Vector3(view["olhar"][0], view["olhar"][1], view["olhar"][2])
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	set_camera(pos, look)
	return true


## Sobrescreve a câmera do cenário (usado pelo menu).
func set_camera(pos: Vector3, look: Vector3) -> void:
	camera.transform = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	_cam_base = camera.transform
	_node_cam = _cam_base


## cast = {"left": {"char": "rafael", "anim": "Idle"}, ...}
func set_cast(cast: Dictionary, characters: Dictionary) -> void:
	for slot in ["left", "right", "center"]:
		var want: Dictionary = cast.get(slot, {})
		var cur: Actor = actors.get(slot)
		if cur != null and (want.is_empty() or cur.char_id != want.get("char", "")):
			cur.queue_free()
			actors.erase(slot)
			cur = null
		if want.is_empty():
			continue
		if cur == null:
			cur = Actor.new()
			_actors_root.add_child(cur)
			cur.position = _slot_position(slot)
			cur.setup(want["char"], characters.get(want["char"], {}), want, title_font, body_font)
			cur.base_anim = want.get("anim", "Idle")
			_face_camera(cur, want.get("facing", "") == "away")
			actors[slot] = cur
		else:
			cur.base_anim = want.get("anim", "Idle")
			cur.play(cur.base_anim)


func clear_cast() -> void:
	for a in actors.values():
		a.queue_free()
	actors.clear()


func actor_for(char_id: String) -> Actor:
	for a in actors.values():
		if a.char_id == char_id:
			return a
	return null


func on_line_start(line: Dictionary) -> void:
	var a := actor_for(line.get("who", ""))
	if a != null:
		# Sentado continua sentado ao falar; senão usa "Talk".
		var cur := a._current_anim.to_lower()
		var busy := cur.ends_with("sit") or cur.contains("walk") or cur.contains("run")
		# sentado/andando continua igual ao falar; parado usa "Talk"
		if line.has("anim"):
			a.play(line["anim"])
		elif not busy:
			a.play("Talk")
	match line.get("fx", ""):
		"flicker":
			flicker_lights(1.2)
		"lights_off":
			lights_off()
	if line.has("sfx") and String(line["sfx"]).begins_with("stinger"):
		scare_flash()


func on_line_end(line: Dictionary, _cast: Dictionary) -> void:
	var a := actor_for(line.get("who", ""))
	if a == null:
		return
	var cur := a._current_anim.to_lower()
	if not (cur.contains("walk") or cur.contains("run")):
		a.play(a.base_anim)


func set_pleads(pleads: Dictionary) -> void:
	for a in actors.values():
		a.set_plead(pleads.get(a.char_id, ""))


func clear_pleads() -> void:
	for a in actors.values():
		a.set_plead("")


## Personagem sob um ponto da tela (toque para escolher). `shrink` = fator
## de redução do SubViewport em relação à tela.
func actor_at_screen(screen_pos: Vector2, shrink: float) -> String:
	var best := ""
	var best_d := 140.0
	for a in actors.values():
		var p: Vector3 = a.chest_position()
		if camera.is_position_behind(p):
			continue
		var sp := camera.unproject_position(p) * shrink
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = a.char_id
	return best


## Mãos em primeira pessoa (PSX FPS Hands, CC0). A pose foi "assada" em dois
## modelos estáticos já em coordenadas de câmera (tools/hands/bake_hands.py):
## antebraço e mão subindo pelas bordas de baixo da tela, como nos vídeos POV.
const HAND_FILES := {
	"L": "fp_hands/mao_L.glb",  # mão da direita da tela
	"R": "fp_hands/mao_R.glb",  # mão da esquerda da tela
}
var _hand_pivots: Dictionary = {}
## A pose foi ajustada para a tela do Safari no iPhone (390x664). Em telas
## mais altas a borda de baixo desce; as mãos acompanham para não "subirem".
const HANDS_DESIGN_TAN := 1.023  # tan(fov/2) vertical em 390x664 com fov 62 na largura
const HANDS_DEPTH := 0.3


func _hands_screen_y() -> float:
	var size := camera.get_viewport().get_visible_rect().size
	if size.x <= 0.0:
		return 0.0
	var t := tan(deg_to_rad(camera.fov * 0.5)) * size.y / size.x
	return -(t - HANDS_DESIGN_TAN) * HANDS_DEPTH


func _build_hands() -> void:
	hands = Node3D.new()
	camera.add_child(hands)
	for side in HAND_FILES:
		var inst := AssetLib.spawn(AssetLib.TP + HAND_FILES[side], Vector3.ZERO)
		AssetLib.psxify(inst)
		# Colado na câmera, o mapeamento afim e o tremido do PSX deformam demais:
		# nas mãos fica desligado, e a pele ganha um pouco de luz própria.
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for i in m.mesh.get_surface_count():
				var mat := (m.get_active_material(i) as ShaderMaterial)
				if mat == null:
					continue
				mat = mat.duplicate()
				mat.set_shader_parameter("affine_strength", 0.0)
				mat.set_shader_parameter("snap_resolution", 900.0)
				var tex = mat.get_shader_parameter("albedo_tex")
				if tex:
					mat.set_shader_parameter("emission_tex", tex)
					mat.set_shader_parameter("emission_strength", 0.45)
				m.set_surface_override_material(i, mat)
		var pivot := Node3D.new()
		pivot.add_child(inst)
		hands.add_child(pivot)
		_hand_pivots[side] = pivot


## Compatível com o código antigo: "grab.L"/"grab.R" estica uma das mãos.
func play_hands(anim: String) -> void:
	if not anim.begins_with("grab."):
		return
	# grab.R = mão da direita da tela = pivô "L" do modelo
	var pivot: Node3D = _hand_pivots.get("L" if anim.ends_with("R") else "R")
	if pivot == null:
		return
	var base := Vector3.ZERO
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(pivot, "position", base + Vector3(0, 0.06, -0.16), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "position", base, 0.45).set_ease(Tween.EASE_IN_OUT)


## Mão estica na direção do personagem escolhido (como nos vídeos).
func reach_towards(char_id: String) -> void:
	var a := actor_for(char_id)
	var side := "R"
	if a != null and camera.to_local(a.global_position).x < 0.0:
		side = "L"
	play_hands("grab." + side)


func shake(amount := 0.06) -> void:
	_shake = maxf(_shake, amount)


func scare_flash() -> void:
	shake(0.08)
	if post_material:
		var tw := create_tween()
		tw.tween_method(func(v): post_material.set_shader_parameter("flash", v), 0.9, 0.0, 0.6)


# --- sustos (jumpscare) ------------------------------------------------------------

## Alguém salta na frente da câmera e o rosto enche a tela. O som fica por conta
## de quem chama (ação "susto" da história). Opções (dicionário da ação):
##   anim     animação durante o bote (padrão "ZombieAttack")
##   de/ate   distância inicial e final até a câmera (2.2 -> 0.5 m)
##   lado     deslocamento lateral inicial (vem do canto da tela)
##   de_cima  altura extra inicial (despenca de cima)
##   rapido   duração do bote em s (0.14)
##   segura   quanto tempo fica tremendo na sua cara (0.8)
##   depois   "sumir" (corte seco para o preto) ou "recuar"
##   inclinar graus que o corpo pende para trás, para o rosto encarar a câmera (20)
func jumpscare(char_id: String, def: Dictionary, o: Dictionary) -> void:
	var a := Actor.new()
	_actors_root.add_child(a)
	a.setup(char_id, def, {"anim": o.get("anim", "ZombieAttack")}, title_font, body_font)
	a.set_name_visible(false)
	a._current_anim = ""
	a.play(o.get("anim", "ZombieAttack"), 0.0)  # sem transição
	a.visible = false  # dois quadros escondido: a animação assenta (nada de pose T)
	_cine_extra.append(a)
	var head := _head_bone(a)
	var face := _face_height(a)
	# luz de baixo para cima, fria e esverdeada: a "lanterna no queixo" dos filmes de terror
	a.key.light_color = Color(0.72, 0.95, 0.75)
	a.key.light_energy = 1.5
	a.key.omni_range = 2.2
	a.key.position = Vector3(0, face - 0.55, 0.35)
	var recuar: bool = o.get("depois", "sumir") == "recuar"
	_scare_place(0.0, a, o, face, head)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(a):
		return
	a.visible = true
	# posição presa ao referencial da câmera: se a câmera anda, o monstro vem junto
	var tw := create_tween()
	tw.tween_method(_scare_place.bind(a, o, face, head), 0.0, 1.0, maxf(float(o.get("rapido", 0.14)), 0.02)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(scare_impact.bind(true))
	tw.tween_method(_scare_hold.bind(a, o, face, head), 0.0, 1.0, maxf(float(o.get("segura", 0.8)), 0.05))
	if recuar:
		tw.tween_method(_scare_place.bind(a, o, face, head), 1.0, 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_callback(post_tween.bind("blackout", 0.0, 1.0, 0.04))
		tw.tween_interval(0.1)
	tw.tween_callback(_scare_end.bind(a, not recuar))


## k = 0 no começo do bote (longe), 1 na sua cara. Com o osso da cabeça, o rosto
## fica no centro mesmo quando a animação de ataque abaixa ou projeta a cabeça.
func _scare_place(k: float, a: Actor, o: Dictionary, face: float, head: Array, jitter := Vector3.ZERO) -> void:
	if not is_instance_valid(a):
		return
	var dist := lerpf(float(o.get("de", 2.2)), float(o.get("ate", 0.5)), k)
	var local := Vector3(float(o.get("lado", 0.0)) * (1.0 - k), float(o.get("de_cima", 0.0)) * (1.0 - k), -dist)
	var target := _cam_base.origin + _cam_base.basis * local + Vector3.DOWN * (0.04 * k)
	_face_point(a, _cam_base.origin)
	# inclina o corpo para trás: o ataque projeta a cabeça e, de perto, mostraria o topo dela
	# + a inclinação da câmera: olhando para baixo, o rosto precisa olhar para cima
	var cam_pitch := rad_to_deg(asin(clampf(-(-_cam_base.basis.z).y, -1.0, 1.0)))
	a.rotate_object_local(Vector3.RIGHT, -deg_to_rad(float(o.get("inclinar", 20.0)) + maxf(cam_pitch, 0.0)))
	var off := Vector3(0, face, 0)
	if not head.is_empty():
		var skel: Skeleton3D = head[0]
		off = skel.global_transform * skel.get_bone_global_pose(head[1]).origin - a.global_position
		off.y += 0.07
		if off.length() > 3.0 or off.y < 0.3:  # esqueleto com escala estranha: usa a altura medida
			off = Vector3(0, face, 0)
	a.global_position = target - off + jitter


func _scare_hold(k: float, a: Actor, o: Dictionary, face: float, head: Array) -> void:
	_scare_place(1.0, a, o, face, head, Vector3(sin(k * 97.0), cos(k * 71.0), 0.0) * 0.014)


func _head_bone(a: Actor) -> Array:
	for sk in a.model.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for i in skel.get_bone_count():
			var bn := skel.get_bone_name(i).to_lower()
			if bn.contains("head") and not bn.contains("end") and not bn.contains("top"):
				return [skel, i]
	return []


## O impacto do susto: tranco na câmera, mãos recuando e (opcional) flash vermelho.
## Sozinho serve para sustos sem monstro (alarme, algo caindo).
func scare_impact(red := true) -> void:
	shake(0.1)
	flinch_hands()
	post_tween("static_amount", 0.35, 0.0, 0.35)  # chiado de estática no impacto
	if red:
		post_tween("flash", 0.55, 0.0, 0.45)  # vermelho rápido: o rosto tem que aparecer


func flinch_hands() -> void:
	for p in _hand_pivots.values():
		var pv := p as Node3D
		var tw := create_tween().set_trans(Tween.TRANS_QUAD)
		tw.tween_property(pv, "position", Vector3(0, 0.07, 0.06), 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(pv, "position", Vector3.ZERO, 0.6).set_ease(Tween.EASE_IN_OUT)


func _scare_end(a: Actor, fade_in: bool) -> void:
	if is_instance_valid(a):
		_cine_extra.erase(a)
		a.queue_free()
	if fade_in:
		post_tween("blackout", 1.0, 0.0, 0.45)


## Altura do rosto acima dos pés (para pôr o rosto no centro da tela): pelo osso
## da cabeça do esqueleto; sem esqueleto, pela caixa do modelo.
func _face_height(a: Actor) -> float:
	for sk in a.model.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for i in skel.get_bone_count():
			var bn := skel.get_bone_name(i).to_lower()
			if bn.ends_with("head") or bn == "head" or bn.contains("head") and not bn.contains("end") and not bn.contains("top"):
				var p := skel.global_transform * skel.get_bone_global_rest(i).origin
				var h := p.y - a.global_position.y
				if h > 0.4 and h < 2.6:
					print("[susto] rosto pelo osso ", skel.get_bone_name(i), ": ", snappedf(h, 0.01))
					return h + 0.07
	var top := 0.0
	var inv := a.global_transform.affine_inverse()
	for n in a.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box: AABB = inv * mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y)
	print("[susto] rosto pela caixa: ", snappedf(top, 0.01))
	return clampf(top, 0.9, 2.4) - 0.13 if top > 0.0 else 1.55


func flicker_lights(duration: float) -> void:
	var lights := get_tree().get_nodes_in_group("scene_lights")
	var originals := {}
	for l in lights:
		originals[l] = l.light_energy
	var steps := int(duration / 0.06)
	for i in steps:
		for l in lights:
			if is_instance_valid(l):
				l.light_energy = originals[l] * (0.0 if randf() < 0.5 else 1.2)
		await get_tree().create_timer(0.06).timeout
	for l in lights:
		if is_instance_valid(l):
			l.light_energy = originals[l]


func lights_off() -> void:
	shake(0.05)
	for l in get_tree().get_nodes_in_group("main_lights"):
		create_tween().tween_property(l, "light_energy", 0.0, 0.15)
	if post_material:
		var tw := create_tween()
		tw.tween_method(func(v): post_material.set_shader_parameter("blackout", v), 0.0, 0.85, 0.1)
		tw.tween_interval(0.5)
		tw.tween_method(func(v): post_material.set_shader_parameter("blackout", v), 0.85, 0.0, 0.8)


func _process(delta: float) -> void:
	_t += delta
	if hands:
		# respiração das mãos
		hands.position = Vector3(sin(_t * 1.1) * 0.004, sin(_t * 2.2) * 0.005 - 0.002 + _hands_screen_y(), 0)
	# respiração da câmera + tremor
	var bob := Vector3(sin(_t * 0.9) * 0.008, sin(_t * 1.8) * 0.006, 0)
	# andando: balanço lateral + passos (a câmera sobe e desce)
	_walk = maxf(_walk - delta, 0.0)
	_walk_amp = move_toward(_walk_amp, 1.0 if _walk > 0.0 else 0.0, delta * 4.0)
	if _walk_amp > 0.0:
		var ph := _t * 8.5
		bob += Vector3(sin(ph * 0.5) * 0.035, -absf(sin(ph * 0.5)) * 0.06, 0) * _walk_amp
		if hands:
			hands.position += Vector3(sin(ph * 0.5) * 0.012, absf(sin(ph * 0.5)) * 0.02, 0) * _walk_amp
	var tilt := sin(_t * 0.6) * 0.004
	_shake = move_toward(_shake, 0.0, delta * 0.25)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
	camera.transform = _cam_base.translated_local(bob + jitter).rotated_local(Vector3.FORWARD, tilt)
	# zumbi se aproximando (cenários com approach_center)
	if location_cfg.get("approach_center", false) and actors.has("center"):
		var z: Node3D = actors["center"]
		var to_cam := _cam_base.origin - z.global_position
		to_cam.y = 0
		if to_cam.length() > 2.6:
			z.global_position += to_cam.normalized() * delta * 0.45


## Slots calculados a partir da câmera: dois personagens lado a lado,
## centralizados na tela em pé, e um terceiro mais ao fundo.
func _slot_position(slot: String) -> Vector3:
	var custom: Dictionary = location_cfg.get("slots", {})
	if custom.has(slot):
		return custom[slot]
	var fwd := -_cam_base.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	var dist: float = location_cfg.get("slot_dist", 2.6)
	var spread: float = location_cfg.get("slot_spread", 0.6)
	var p := _cam_base.origin
	match slot:
		"left":
			p += fwd * dist - right * spread
		"right":
			p += fwd * dist + right * spread
		_:
			p += fwd * float(location_cfg.get("center_dist", 4.6))
	p.y = location_cfg.get("floor_y", 0.0)
	return p


func _face_camera(actor: Actor, away: bool) -> void:
	var target := _cam_base.origin
	target.y = actor.global_position.y
	if target.distance_to(actor.global_position) < 0.01:
		return
	actor.look_at(target, Vector3.UP, true)
	if away:
		actor.rotate_y(PI)
		if actor.key:
			actor.key.position.z = -actor.key.position.z  # luz continua do lado da câmera


# --- cinemáticas (finais animados) ---------------------------------------------------

var _cine_labels: Dictionary = {}
var _cine_extra: Array = []


func tween_camera(pos: Vector3, look: Vector3, dur: float) -> void:
	var from := _cam_base
	var to := Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()  # um movimento novo substitui o anterior
	if dur <= 0.0:
		_cam_base = to
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween = tw
	tw.tween_method(func(k: float): _cam_base = from.interpolate_with(to, k), 0.0, 1.0, dur)


func move_actor(char_id: String, to: Vector3, dur: float) -> void:
	var a := actor_for(char_id)
	if a == null:
		return
	_face_point(a, to if to.distance_to(a.global_position) > 0.3 else _cam_base.origin)
	create_tween().tween_property(a, "global_position", to, maxf(dur, 0.01))


func face_camera_now(char_id: String) -> void:
	var a := actor_for(char_id)
	if a:
		_face_camera(a, false)


## Troca um personagem por outro no mesmo lugar (ex.: vira zumbi).
func swap_actor(char_id: String, new_id: String, def: Dictionary, anim: String) -> void:
	for slot in actors:
		var old: Actor = actors[slot]
		if old.char_id != char_id:
			continue
		var a := Actor.new()
		_actors_root.add_child(a)
		a.global_position = old.global_position
		a.setup(new_id, def, {"anim": anim}, title_font, body_font)
		a.global_rotation = old.global_rotation
		a.set_name_visible(false)
		old.queue_free()
		actors[slot] = a
		return


func shake_actor(char_id: String, dur: float) -> void:
	var a := actor_for(char_id)
	if a == null or a.model == null:
		return
	var base: Vector3 = a.model.position  # modelos escalados têm deslocamento em y
	var tw := create_tween()
	for i in int(dur / 0.05):
		tw.tween_property(a.model, "position", base + Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.04, 0.04)), 0.05)
	tw.tween_property(a.model, "position", base, 0.05)


func hide_names() -> void:
	for a in actors.values():
		a.set_name_visible(false)


## Texto no mundo 3D (relógio, tela de celular, placa...). Reutiliza pela chave.
func world_text(key: String, text: String, pos: Vector3, size: int, color: Color) -> void:
	var l: Label3D = _cine_labels.get(key)
	if l == null:
		l = Label3D.new()
		l.font = body_font
		l.outline_size = 10
		l.outline_modulate = Color.BLACK
		l.pixel_size = 0.003
		l.no_depth_test = true
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(l)
		_cine_labels[key] = l
	l.text = text
	l.position = pos
	l.font_size = size
	l.modulate = color


func point_light(pos: Vector3, color: Color, energy: float, light_range: float, flicker := false) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	if flicker:
		l.add_child(Locations.Flicker.new(0.6, 7.0))
	add_child(l)
	_cine_extra.append(l)


func tween_env(ambient: Color, energy: float, fog_color: Color, fog_density: float, background: Color, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(env, "ambient_light_color", ambient, dur)
	tw.tween_property(env, "ambient_light_energy", energy, dur)
	tw.tween_property(env, "fog_light_color", fog_color, dur)
	tw.tween_property(env, "fog_density", fog_density, dur)
	tw.tween_property(env, "background_color", background, dur)


## Mãos mudando de cor (ex.: infecção). Duplica o material para não sujar o cache.
func tint_hands(color: Color, dur: float) -> void:
	for mi in hands.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(i) as ShaderMaterial
			if mat == null:
				continue
			mat = mat.duplicate()
			m.set_surface_override_material(i, mat)
			var from: Color = mat.get_shader_parameter("albedo_color")
			create_tween().tween_method(func(c: Color): mat.set_shader_parameter("albedo_color", c), from, color, dur)


# --- direção de cena (ações por fala/nó; ver docs/FORMATO_HISTORIA.md) ------------

## Base da câmera só com a rotação horizontal: offsets "à esquerda/à frente".
func _yaw_basis() -> Basis:
	var fwd := -_cam_base.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	return Basis.looking_at(fwd.normalized(), Vector3.UP)


## Offset no referencial da câmera: x = direita, y = cima, z = para trás (+) / frente (-).
func cam_offset(v: Vector3) -> Vector3:
	return _yaw_basis() * v


## Câmera andando até pos/olhar (com balanço de passos).
func walk_camera(pos: Vector3, look: Vector3, dur: float) -> void:
	tween_camera(pos, look, dur)
	_walk = dur


## Move a câmera relativa a ela mesma; olhar = ponto absoluto ou à frente.
func camera_rel(offset: Vector3, dur: float, walk := false, look = null) -> void:
	var pos := _cam_base.origin + cam_offset(offset)
	var target: Vector3 = look if look is Vector3 else pos + (-_cam_base.basis.z) * 3.0
	tween_camera(pos, target, dur)
	if walk:
		_walk = dur


func camera_look_actor(char_id: String, dur: float) -> void:
	var a := actor_for(char_id)
	if a:
		tween_camera(_cam_base.origin, a.global_position + Vector3(0, a.head_height * 0.82, 0), dur)


func camera_look_point(p: Vector3, dur: float) -> void:
	tween_camera(_cam_base.origin, p, dur)


func camera_back(dur: float) -> void:
	tween_camera(_node_cam.origin, _node_cam.origin - _node_cam.basis.z * 3.0, dur)


## Personagem entra em cena: começa deslocado (offset da câmera) e anda até o slot.
func enter_actor(char_id: String, offset: Vector3, dur: float, anim := "Walk", end_anim := "Idle") -> void:
	var a := actor_for(char_id)
	if a == null:
		return
	var slot := a.global_position
	a.global_position = slot + cam_offset(offset)
	a.visible = true
	a.play(anim)
	_face_point(a, slot)
	var tw := create_tween()
	tw.tween_property(a, "global_position", slot, maxf(dur, 0.01))
	tw.tween_callback(func():
		if is_instance_valid(a):
			a.base_anim = end_anim
			a.play(end_anim)
			_face_camera(a, false))


## Personagem sai de cena andando para o offset e some no fim.
func exit_actor(char_id: String, offset: Vector3, dur: float, anim := "Walk", hide := true) -> void:
	var a := actor_for(char_id)
	if a == null:
		return
	var to := a.global_position + cam_offset(offset)
	a.play(anim)
	_face_point(a, to)
	var tw := create_tween()
	tw.tween_property(a, "global_position", to, maxf(dur, 0.01))
	if hide:
		tw.tween_callback(func():
			if is_instance_valid(a):
				a.visible = false)


## Anda relativo à posição atual; no fim volta a encarar a câmera (opcional).
func move_actor_rel(char_id: String, offset: Vector3, dur: float, anim := "", end_anim := "", face_cam := true) -> void:
	var a := actor_for(char_id)
	if a == null:
		return
	var to := a.global_position + cam_offset(offset)
	if not anim.is_empty():
		a.play(anim)
	if Vector2(offset.x, offset.z).length() > 0.05:
		_face_point(a, to)
	var tw := create_tween()
	tw.tween_property(a, "global_position", to, maxf(dur, 0.01))
	tw.tween_callback(func():
		if not is_instance_valid(a):
			return
		if not end_anim.is_empty():
			a.base_anim = end_anim
			a.play(end_anim)
		if face_cam:
			_face_camera(a, false))


func face_actor(char_id: String, target_id: String) -> void:
	var a := actor_for(char_id)
	var b := actor_for(target_id)
	if a and b:
		_face_point(a, b.global_position)


func set_actor_visible(char_id: String, v: bool) -> void:
	var a := actor_for(char_id)
	if a:
		a.visible = v


## Liga/desliga (energia) uma luz do cenário pelo nome (ex.: postes apagando).
func tween_light(node_name: String, energy: float, dur: float) -> void:
	var l := _location_root.find_child(node_name, true, false) as Light3D
	if l:
		for c in l.get_children():
			if c.get_script() != null:
				c.queue_free()  # tira o pisca-pisca para a luz obedecer
		create_tween().tween_property(l, "light_energy", energy, maxf(dur, 0.01))


## Move um nó do cenário pelo nome (ex.: portas do elevador).
func move_location_node(node_name: String, to: Vector3, dur: float) -> void:
	var n := _location_root.find_child(node_name, true, false) as Node3D
	if n:
		create_tween().set_trans(Tween.TRANS_SINE).tween_property(n, "position", to, maxf(dur, 0.01))


func post_tween(param: String, from: float, to: float, dur: float) -> void:
	if post_material == null:
		return
	create_tween().tween_method(func(v: float): post_material.set_shader_parameter(param, v), from, to, maxf(dur, 0.01))


func clear_cinematic() -> void:
	for l in _cine_labels.values():
		l.queue_free()
	_cine_labels.clear()
	for n in _cine_extra:
		if is_instance_valid(n):
			n.queue_free()
	_cine_extra.clear()


func _face_point(actor: Actor, target: Vector3) -> void:
	target.y = actor.global_position.y
	if target.distance_to(actor.global_position) > 0.01:
		actor.look_at(target, Vector3.UP, true)

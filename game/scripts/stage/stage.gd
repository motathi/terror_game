extends Node3D
## Diretor de cena 3D: monta o cenário, posiciona o elenco nos slots,
## controla câmera POV (com as mãos do jogador), efeitos de luz e súplicas.

const AssetLib := preload("res://scripts/stage/asset_lib.gd")
const Locations := preload("res://scripts/stage/locations.gd")
const Actor := preload("res://scripts/stage/actor.gd")

## Ajuste fino das mãos em primeira pessoa (modelo arms_rig.glb).
## O rig tem um osso "camera" em y=1.743 olhando para -Z: alinhamos ele à câmera.
const HANDS_OFFSET := Vector3(0, -1.743, 0.0)
const HANDS_IDLE_ANIM := "guard_idle"

var title_font: Font
var body_font: Font
var post_material: ShaderMaterial  # material do pós-processo (flash/blackout)

var camera: Camera3D
var env: Environment
var hands: Node3D
var hands_anim: AnimationPlayer
var location_id := ""
var location_cfg: Dictionary = {}
var actors: Dictionary = {}  # slot -> Actor
var _location_root: Node3D
var _actors_root: Node3D
var _cam_base := Transform3D()
var _hands_skel: Skeleton3D
var _hands_cam_bone := -1
var _hand_l := -1
var _hand_r := -1
## Onde o ponto médio entre as duas mãos fica, em coordenadas da câmera:
## parte de baixo da tela, como nos vídeos POV.
const HANDS_TARGET := Vector3(0, -0.36, -0.6)
## Base do osso "camera" do rig expressa em coordenadas de câmera Godot:
## no rig, +Y do osso aponta para a frente e +X para baixo.
const _BONE_TO_CAM := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
var _t := 0.0
var _shake := 0.0


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
	hands.visible = location_cfg.get("hands", true)


## Sobrescreve a câmera do cenário (usado pelo menu).
func set_camera(pos: Vector3, look: Vector3) -> void:
	camera.transform = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	_cam_base = camera.transform


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
			_face_camera(cur, want.get("facing", "") == "away")
			actors[slot] = cur
		else:
			cur.play(want.get("anim", "Idle"))


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
		var sitting := a._current_anim.to_lower().ends_with("sit")
		a.play(line.get("anim", "Sit" if sitting else "Talk"))
	match line.get("fx", ""):
		"flicker":
			flicker_lights(1.2)
		"lights_off":
			lights_off()
	if line.has("sfx") and String(line["sfx"]).begins_with("stinger"):
		scare_flash()


func on_line_end(line: Dictionary, cast: Dictionary) -> void:
	var a := actor_for(line.get("who", ""))
	if a == null:
		return
	for slot in actors:
		if actors[slot] == a:
			a.play(cast.get(slot, {}).get("anim", "Idle"))


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


## Mãos em primeira pessoa (PSX FPS Hands, CC0): duas cópias do modelo, cada
## uma mostrando só um braço, posicionadas nas bordas de baixo da tela como
## nos vídeos POV. Pose calculada no visualizador (rotação YXZ em graus).
const HAND_POSE := {
	"L": {"rot": Vector3(0.87, -67.29, -153.58), "pos": Vector3(0.397, -0.585, 0.355)},  # mão da direita da tela
	"R": {"rot": Vector3(0.87, 67.29, 153.58), "pos": Vector3(-0.397, -0.585, 0.355)},   # mão da esquerda da tela
}
var _hand_pivots: Dictionary = {}


func _build_hands() -> void:
	hands = Node3D.new()
	camera.add_child(hands)
	for side in ["L", "R"]:
		var inst := AssetLib.spawn(AssetLib.model_path("hands"), Vector3.ZERO)
		AssetLib.psxify(inst)
		var other := "R" if side == "L" else "L"
		for sk in inst.find_children("*", "Skeleton3D", true, false):
			var skel := sk as Skeleton3D
			for b in skel.get_bone_count():
				var bn := skel.get_bone_name(b).replace(".", "").replace("_", "").to_lower()
				if bn == "upperarm" + other.to_lower():
					skel.set_bone_pose_scale(b, Vector3.ONE * 0.0001)  # esconde o outro braço
		var pivot := Node3D.new()
		pivot.add_child(inst)
		pivot.rotation_degrees = HAND_POSE[side]["rot"]
		pivot.position = HAND_POSE[side]["pos"]
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
	var base: Vector3 = HAND_POSE["L" if anim.ends_with("R") else "R"]["pos"]
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
		hands.position = Vector3(sin(_t * 1.1) * 0.004, sin(_t * 2.2) * 0.005 - 0.002, 0)
	# respiração da câmera + tremor
	var bob := Vector3(sin(_t * 0.9) * 0.008, sin(_t * 1.8) * 0.006, 0)
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
## Mantém o osso "camera" do rig colado na câmera (as animações das mãos
## foram feitas a partir desse ponto de vista).
func _align_hands() -> void:
	if _hands_skel == null or not hands.visible:
		return
	var skel_in_hands := Transform3D.IDENTITY
	var n: Node = _hands_skel
	while n != null and n != hands:
		if n is Node3D:
			skel_in_hands = (n as Node3D).transform * skel_in_hands
		n = n.get_parent()
	if _hand_l >= 0 and _hand_r >= 0:
		# Translada o rig para o meio das mãos cair em HANDS_TARGET.
		var mid := (_hands_skel.get_bone_global_pose(_hand_l).origin + _hands_skel.get_bone_global_pose(_hand_r).origin) * 0.5
		var mid_in_hands := skel_in_hands * mid
		hands.transform = Transform3D(Basis(), HANDS_TARGET - mid_in_hands)
		return
	var bone := _hands_skel.get_bone_global_pose(_hands_cam_bone)
	var cam_in_hands := skel_in_hands * bone * Transform3D(_BONE_TO_CAM, Vector3.ZERO)
	hands.transform = cam_in_hands.affine_inverse()


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
	if dur <= 0.0:
		_cam_base = to
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	var tw := create_tween()
	for i in int(dur / 0.05):
		tw.tween_property(a.model, "position", Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.04, 0.04)), 0.05)
	tw.tween_property(a.model, "position", Vector3.ZERO, 0.05)


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

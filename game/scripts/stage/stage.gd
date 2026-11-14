extends Node3D
## Diretor de cena 3D: monta o cenário, posiciona o elenco nos slots,
## controla câmera POV (com as mãos do jogador), efeitos de luz e súplicas.

const AssetLib := preload("res://scripts/stage/asset_lib.gd")
const Locations := preload("res://scripts/stage/locations.gd")
const Actor := preload("res://scripts/stage/actor.gd")

## Ajuste fino das mãos em primeira pessoa (modelo arms_rig.glb).
const HANDS_OFFSET := Vector3(0, -1.58, 0.05)
const HANDS_IDLE_ANIM := "relax"

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
	camera.fov = 74.0
	camera.near = 0.05
	camera.far = 60.0
	camera.current = true
	add_child(camera)

	hands = AssetLib.spawn(AssetLib.model_path("arms"), Vector3.ZERO)
	AssetLib.psxify(hands)
	hands.position = HANDS_OFFSET
	camera.add_child(hands)
	hands_anim = AssetLib.find_animation_player(hands)
	play_hands(HANDS_IDLE_ANIM)

	_location_root = Node3D.new()
	add_child(_location_root)
	_actors_root = Node3D.new()
	add_child(_actors_root)


func set_location(id: String) -> void:
	if id == location_id:
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
		a.play(line.get("anim", "Talk"))
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


func play_hands(anim: String) -> void:
	var found := AssetLib.find_animation(hands_anim, anim)
	if found.is_empty():
		return
	var a := hands_anim.get_animation(found)
	if anim == HANDS_IDLE_ANIM and a != null:
		a.loop_mode = Animation.LOOP_LINEAR
	hands_anim.play(found, 0.2)


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


func _slot_position(slot: String) -> Vector3:
	return location_cfg.get("slots", {}).get(slot, Vector3.ZERO)


func _face_camera(actor: Node3D, away: bool) -> void:
	var target := _cam_base.origin
	target.y = actor.global_position.y
	if target.distance_to(actor.global_position) < 0.01:
		return
	actor.look_at(target, Vector3.UP, true)
	if away:
		actor.rotate_y(PI)

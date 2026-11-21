extends RefCounted
## Catálogo de modelos + utilitários para carregar com fallback e aplicar o
## material PSX. Se um pacote não foi baixado (tools/fetch_assets.py), o jogo
## continua rodando com formas provisórias no lugar.

const TP := "res://assets/third_party/"
const PSX_SHADER := preload("res://shaders/psx_lit.gdshader")

## Personagens: chave usada em "model" no JSON da história.
const MODELS := {
	"office_worker": TP + "everyday_npcs/NPC_OfficeWorker/NPC_OfficeWorker.glb",
	"nurse": TP + "everyday_npcs/NPC_Nurse/NPC_Nurse.glb",
	"zombie_student": TP + "everyday_npcs/NPC_Student_Zombie/NPC_Student_Zombie.glb",
	"zombie_retro": TP + "zombie_retro/zombie 2.glb",
	"zombie_male": TP + "zombies_lowho/FBX/Characters/Zombie_Male_01.fbx",
	"zombie_female": TP + "zombies_lowho/FBX/Characters/Zombie_Female_01.fbx",
	"zombie_big": TP + "zombies_lowho/FBX/Characters/Zombie_Behemoth_01.fbx",
	"arms": TP + "fp_arms/arms_rig.glb",
	"hands": TP + "fp_hands/hands.glb",
	"alien_shellback": TP + "psx_aliens/glb/drone.glb",
	"alien_grey": TP + "alien_grey/Alien.fbx",
	"dog": TP + "psx_dog/DogGlb.glb",
	"dog_head": TP + "psx_dog/dog_head.glb",  # gerado por tools/dog_head.py
	"skinwalker": TP + "psx_creatures/zombie_woman.glb",
	# feitos no projeto (Blender, tools/blender/)
	"rastejante": "res://assets/models/rastejante.glb",  # zumbi sem pernas: Idle, Crawl, Attack
}

## Ajustes por modelo, aplicados pelo Actor:
## tex = textura (o GLB do cachorro vem sem ela), rot_y = para onde o modelo
## olha (o Actor espera +Z), altura = altura padrão em metros (medida pelos
## ossos), olhos = osso da cabeça + posição dos olhos no espaço do osso.
const MODEL_META := {
	"dog": {
		"tex": TP + "psx_dog/BlackDog.png",
		"rot_y": 180.0,  # o GLB do cachorro olha para -Z
		"altura": 0.72,
		"osso_cabeca": "spine.011",
		"olhos": [Vector3(-0.087, 0.228, 0.101), Vector3(0.087, 0.228, 0.101)],
		"raio_olho": 0.034,
	},
}

## O skinwalker: corpo humano alto e magro vestindo a cabeça do cachorro como
## máscara (anexo preso no osso "Head"; posição ajustada no visualizador).
const _DOG_EYES := [Vector3(-0.087, 0.228, 0.101), Vector3(0.087, 0.228, 0.101)]
const SKINWALKER_META := {
	"magro": 0.8,
	"anexos": [{
		"model": "dog_head", "osso": "Head",
		"pos": Vector3(-0.0007, 0.1839, -0.0098), "rot": Vector3(54.61, 0.49, 0.35), "escala": 0.8,
		"tex": TP + "psx_dog/BlackDog.png", "pelagem": "morta",
		"olhos": _DOG_EYES, "raio_olho": 0.034,
	}],
}


static func meta(key: String) -> Dictionary:
	if key == "skinwalker":
		return SKINWALKER_META
	return MODEL_META.get(key, {})


## Pelagens para "pelagem" no personagem: [tom escuro, tom claro].
const PELAGENS := {
	"caramelo": ["#2e1408", "#ffb860"],
	"morta": ["#241c16", "#c0ac90"],
	"cinza": ["#101012", "#a8a8b0"],
}

static var _mat_cache: Dictionary = {}


static func model_path(key: String) -> String:
	return MODELS.get(key, key)


## Instancia um modelo. Se não existir, devolve um placeholder do tamanho
## aproximado (`fallback_size`). `kind` = "human" gera uma silhueta.
static func spawn(path: String, fallback_size := Vector3(0.5, 0.5, 0.5), kind := "box") -> Node3D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is PackedScene:
			var inst = res.instantiate()
			if inst is Node3D:
				return inst
			var holder := Node3D.new()
			holder.add_child(inst)
			return holder
		if res is Mesh:  # .obj é importado como Mesh por padrão
			var mi := MeshInstance3D.new()
			mi.mesh = res
			var root := Node3D.new()
			root.add_child(mi)
			return root
	if kind == "human":
		return placeholder_human()
	return placeholder_box(fallback_size, Color(0.35, 0.35, 0.38))


static func placeholder_box(size: Vector3, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position.y = size.y * 0.5
	mi.material_override = make_material(color)
	var root := Node3D.new()
	root.add_child(mi)
	return root


static func placeholder_human() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 1.45
	body.mesh = cap
	body.position.y = 0.75
	body.material_override = make_material(Color(0.25, 0.25, 0.28))
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.3
	head.mesh = sph
	head.position.y = 1.62
	head.material_override = make_material(Color(0.8, 0.8, 0.78))
	root.add_child(head)
	return root


## Material PSX sólido (sem textura).
static func make_material(color: Color, emission := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PSX_SHADER
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("use_texture", false)
	if emission > 0.0:
		var img := Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
		img.fill(color)
		m.set_shader_parameter("emission_tex", ImageTexture.create_from_image(img))
		m.set_shader_parameter("emission_strength", emission)
	return m


## Troca os materiais de todos os MeshInstance3D por materiais PSX,
## preservando textura, cor e emissão. `tint` multiplica a cor (útil para
## reaproveitar o mesmo modelo como outro personagem).
static func psxify(root: Node, tint := Color.WHITE) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		for i in mesh_inst.mesh.get_surface_count():
			var src := mesh_inst.get_active_material(i)
			mesh_inst.set_surface_override_material(i, _convert(src, tint))


static func _convert(src: Material, tint: Color) -> Material:
	if src is ShaderMaterial and (src as ShaderMaterial).shader == PSX_SHADER:
		return src
	var key := [src, tint]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = PSX_SHADER
	var color := Color.WHITE
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		color = b.albedo_color
		if b.vertex_color_use_as_albedo:
			m.set_shader_parameter("use_vertex_color", true)
		if b.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", b.albedo_texture)
			m.set_shader_parameter("use_texture", true)
		if b.emission_enabled:
			var etex: Texture2D = b.emission_texture
			if etex != null:
				m.set_shader_parameter("emission_tex", etex)
				m.set_shader_parameter("emission_strength", 1.5 * b.emission_energy_multiplier)
		if b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			m.set_shader_parameter("alpha_scissor", 0.0)
	m.set_shader_parameter("albedo_color", color * tint)
	_mat_cache[key] = m
	return m


## Procura o AnimationPlayer de um modelo importado.
static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return found[0] if found.size() > 0 else null


## Encontra uma animação pelo nome, tolerando prefixo de biblioteca
## ("Library/Idle") e diferenças de maiúsculas.
static func find_animation(player: AnimationPlayer, wanted: String) -> String:
	if player == null or wanted.is_empty():
		return ""
	if player.has_animation(wanted):
		return wanted
	var low := wanted.to_lower()
	for a in player.get_animation_list():
		var n := String(a)
		var short := n.get_slice("/", n.get_slice_count("/") - 1).to_lower()
		if short == low:
			return n
	for a in player.get_animation_list():
		if String(a).to_lower().contains(low):
			return String(a)
	return ""

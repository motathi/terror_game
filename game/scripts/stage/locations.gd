extends RefCounted
## Monta os cenários a partir dos pacotes PSX baixados.
##
## Convenção: a câmera (olhos do jogador) fica perto da origem olhando para -Z.
## Os slots dos personagens são calculados a partir da câmera (Stage), como
## nos vídeos verticais: left/right lado a lado a `slot_dist` metros, center
## mais ao fundo. Cada cenário só informa a altura do chão (`floor_y`) e,
## se precisar, sobrescreve slots em "slots". Teste com ?cena=<nó> na web.

const AssetLib := preload("res://scripts/stage/asset_lib.gd")
const OFF := AssetLib.TP + "office/"
const HOUSE := AssetLib.TP + "house_interior/"
const CAR := AssetLib.TP + "cars/Car 02/Car2.obj"

const DEFAULT := {
	"camera_pos": Vector3(0, 1.62, 0),
	"camera_look": Vector3(0, 1.45, -3.0),
	"slots": {},
	"floor_y": 0.0,
	"slot_dist": 2.6,
	"slot_spread": 0.6,
	"center_dist": 4.6,
	"ambient": Color(0.42, 0.42, 0.5),
	"ambient_energy": 0.7,
	"fog_color": Color(0.03, 0.03, 0.04),
	"fog_density": 0.03,
	"hands": true,
}


static func build(id: String, root: Node3D) -> Dictionary:
	var cfg := DEFAULT.duplicate(true)
	match id:
		"escritorio":
			_escritorio(root, cfg, false)
		"escritorio_escuro":
			_escritorio(root, cfg, true)
		"escada":
			_escada(root, cfg)
		"garagem":
			_garagem(root, cfg)
		"carro":
			_carro(root, cfg)
		"rua":
			_rua(root, cfg)
		"casa":
			_casa(root, cfg)
		_:
			push_warning("Locations: cenário desconhecido '%s'" % id)
			box(root, Vector3(10, 0.1, 10), Vector3(0, -0.05, -3), Color(0.1, 0.1, 0.1))
	return cfg


# --- cenários -----------------------------------------------------------------

static func _escritorio(root: Node3D, cfg: Dictionary, dark: bool) -> void:
	for x in range(-6, 6, 2):
		for z in range(2, -10, -2):
			prop(root, OFF + "carpet_floor/floor_2x2.glb", Vector3(x, 0, z), 0, 1, Vector3(2, 0.02, 2))
	box(root, Vector3(12, 0.1, 12), Vector3(0, 3.0, -4), Color(0.55, 0.55, 0.52))
	box(root, Vector3(12, 3.0, 0.2), Vector3(0, 1.5, -7.0), Color(0.62, 0.6, 0.52))
	box(root, Vector3(0.2, 3.0, 12), Vector3(-5.0, 1.5, -4), Color(0.6, 0.58, 0.5))
	box(root, Vector3(0.2, 3.0, 12), Vector3(5.0, 1.5, -4), Color(0.6, 0.58, 0.5))
	# janelas com a cidade lá fora (fim de tarde / noite)
	var sky := Color(0.9, 0.45, 0.25) if not dark else Color(0.05, 0.06, 0.12)
	box(root, Vector3(0.05, 1.2, 3.0), Vector3(4.88, 1.7, -3.5), sky, 1.2)

	prop(root, OFF + "desks/desk1_weathered.glb", Vector3(-2.1, 0, -1.1), 90, 1, Vector3(2.2, 0.9, 1.1))
	prop(root, OFF + "computers/computer_monitor.glb", Vector3(-2.2, 0.89, -1.1), 90)
	prop(root, OFF + "computers/computer_keyboard.glb", Vector3(-1.75, 0.89, -1.1), 90)
	prop(root, OFF + "extras/mug_alt.glb", Vector3(-1.8, 0.89, -0.5), 0)
	prop(root, OFF + "chairs/office_chair_black.glb", Vector3(-1.2, 0, -1.3), -100)

	prop(root, OFF + "desks/desk2.glb", Vector3(2.2, 0, -1.0), -90, 1, Vector3(2.2, 0.9, 1.1))
	prop(root, OFF + "computers/computer_monitor.glb", Vector3(2.3, 0.89, -1.2), -90)
	prop(root, OFF + "extras/desk_phone_with_cable.glb", Vector3(1.9, 0.89, -0.5), -70)
	prop(root, OFF + "extras/square_desklamp.glb", Vector3(2.4, 0.89, -0.2), -90)
	prop(root, OFF + "chairs/office_chair_grey.glb", Vector3(1.3, 0, -1.6), 110)

	prop(root, OFF + "dividers/divider_full_c.glb", Vector3(-2.7, 0, -4.8), 0, 1, Vector3(3, 1.5, 0.1))
	prop(root, OFF + "dividers/divider_full_c_blue.glb", Vector3(2.7, 0, -4.8), 0, 1, Vector3(3, 1.5, 0.1))
	prop(root, OFF + "extras/water_cooler.glb", Vector3(3.6, 0, -2.8), -90, 1, Vector3(0.4, 1.4, 0.4))
	prop(root, OFF + "extras/whiteboard.glb", Vector3(-3.4, 0, -6.6), 0, 1, Vector3(2.1, 2.5, 0.1))
	prop(root, OFF + "extras/wall_clock.glb", Vector3(2.4, 2.2, -6.88), 0)
	prop(root, OFF + "extras/coffee_machine.glb", Vector3(4.4, 0.9, -5.5), -90)
	prop(root, OFF + "book_things/book_case_small.glb", Vector3(4.5, 0, -5.5), -90, 1, Vector3(0.5, 0.9, 1.0))

	# TV ao fundo, entre os dois personagens
	box(root, Vector3(1.4, 1.0, 0.5), Vector3(0, 0.5, -6.6), Color(0.25, 0.18, 0.12))
	prop(root, OFF + "computers/TV.glb", Vector3(-0.1, 1.0, -6.6), 0, 1.1, Vector3(0.8, 0.9, 0.6))
	var screen := box(root, Vector3(0.62, 0.45, 0.02), Vector3(0.02, 1.62, -6.27), Color(0.35, 0.5, 1.0), 2.0)
	screen.add_to_group("tv_screen")
	var tv_light := omni(root, Vector3(0, 1.7, -5.6), Color(0.45, 0.6, 1.0), 1.2, 5.0)
	tv_light.add_child(Flicker.new(0.35, 9.0))

	if not dark:
		for z in [-2.8, -5.8]:
			var l := omni(root, Vector3(0, 2.8, z), Color(1.0, 0.95, 0.85), 1.2, 7.0)
			l.add_to_group("main_lights")
			box(root, Vector3(1.0, 0.03, 0.25), Vector3(0, 2.94, z), Color(1, 1, 0.95), 1.2)
		cfg["ambient_energy"] = 0.8
		cfg["fog_density"] = 0.015
		cfg["fog_color"] = Color(0.1, 0.09, 0.08)
	else:
		var red := omni(root, Vector3(-4.0, 2.6, -5.5), Color(1.0, 0.1, 0.05), 2.2, 9.0)
		red.add_child(Pulse.new(0.6, 1.6))
		box(root, Vector3(0.3, 0.15, 0.1), Vector3(-4.0, 2.6, -6.88), Color(1, 0.1, 0.05), 3.0)
		cfg["ambient_energy"] = 0.45
		cfg["ambient"] = Color(0.45, 0.35, 0.45)
		cfg["fog_density"] = 0.035


static func _escada(root: Node3D, cfg: Dictionary) -> void:
	var concrete := Color(0.42, 0.42, 0.4)
	box(root, Vector3(2.8, 0.2, 3.0), Vector3(0, -0.1, 0), concrete)  # patamar
	for i in 14:
		var top := -(i + 1) * 0.18
		box(root, Vector3(2.4, 0.18, 0.3), Vector3(0, top - 0.09, -1.65 - i * 0.3), concrete.darkened(0.05 * (i % 2)))
	box(root, Vector3(2.8, 0.2, 4.0), Vector3(0, -2.6, -7.5), concrete)
	box(root, Vector3(0.2, 7.0, 12), Vector3(-1.3, 0.5, -3), concrete.darkened(0.15))
	box(root, Vector3(0.2, 7.0, 12), Vector3(1.3, 0.5, -3), concrete.darkened(0.15))
	box(root, Vector3(2.8, 0.2, 12), Vector3(0, 3.2, -3), concrete.darkened(0.3))
	box(root, Vector3(2.8, 7.0, 0.2), Vector3(0, 0.5, -9.4), concrete.darkened(0.2))
	# corrimãos
	for x in [-1.15, 1.15]:
		var rail := box(root, Vector3(0.05, 0.05, 6.0), Vector3(x, -0.3, -3.8), Color(0.6, 0.15, 0.1))
		rail.rotation.x = deg_to_rad(-31)
	# porta do elevador acesa, na parede da esquerda
	box(root, Vector3(0.06, 2.1, 1.1), Vector3(-1.19, 1.05, 0.6), Color(1.0, 0.95, 0.75), 2.5)
	omni(root, Vector3(-0.8, 1.6, 0.6), Color(1.0, 0.9, 0.7), 0.8, 3.0)
	# placa SAÍDA
	box(root, Vector3(0.6, 0.22, 0.05), Vector3(0, 2.7, -1.2), Color(0.1, 1.0, 0.3), 2.5)
	var sign := Label3D.new()
	sign.text = "SAÍDA"
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.modulate = Color(0.0, 0.15, 0.0)
	sign.position = Vector3(0, 2.7, -1.17)
	root.add_child(sign)
	omni(root, Vector3(0, 2.5, -1.0), Color(0.2, 1.0, 0.4), 0.7, 4.0)
	var bulb := omni(root, Vector3(0, 2.9, -4.0), Color(1.0, 0.9, 0.7), 1.3, 6.0)
	bulb.add_child(Flicker.new(0.7, 14.0))
	cfg["floor_y"] = -0.54  # personagens ~3 degraus abaixo
	cfg["slot_dist"] = 2.5
	cfg["camera_look"] = Vector3(0, 0.75, -3.0)
	cfg["fog_density"] = 0.04
	cfg["ambient_energy"] = 0.5


static func _garagem(root: Node3D, cfg: Dictionary) -> void:
	box(root, Vector3(16, 0.1, 26), Vector3(0, -0.05, -8), Color(0.22, 0.22, 0.22))
	box(root, Vector3(16, 0.2, 26), Vector3(0, 2.9, -8), Color(0.3, 0.3, 0.3))
	for z in [-2.5, -8.0, -13.5]:
		for x in [-3.2, 3.2]:
			box(root, Vector3(0.55, 2.9, 0.55), Vector3(x, 1.45, z), Color(0.5, 0.5, 0.48))
			box(root, Vector3(0.57, 0.5, 0.57), Vector3(x, 0.25, z), Color(0.75, 0.6, 0.05))
	for z in range(0, -20, -3):
		box(root, Vector3(0.1, 0.01, 1.6), Vector3(-1.6, 0.01, z), Color(0.8, 0.7, 0.1))
		box(root, Vector3(0.1, 0.01, 1.6), Vector3(1.6, 0.01, z), Color(0.8, 0.7, 0.1))
	car(root, Vector3(-4.8, 0, -4.5), 0, Color(0.5, 0.15, 0.12))
	car(root, Vector3(4.8, 0, -6.0), 180, Color(0.2, 0.25, 0.35))
	car(root, Vector3(-4.8, 0, -11.0), 0, Color(0.35, 0.35, 0.3))
	car(root, Vector3(2.4, 0, -14.5), 90, Color(0.75, 0.75, 0.78))  # o carro prata do Rafael
	var lamp := omni(root, Vector3(0, 2.6, -6.0), Color(0.85, 0.95, 1.0), 1.6, 5.5)
	lamp.add_child(Flicker.new(0.9, 7.0))
	box(root, Vector3(1.0, 0.05, 0.15), Vector3(0, 2.78, -6.0), Color(0.9, 1, 1), 1.5)
	omni(root, Vector3(0, 2.6, -1.0), Color(0.85, 0.95, 1.0), 0.5, 4.0)
	cfg["center_dist"] = 6.0
	cfg["fog_density"] = 0.035
	cfg["ambient_energy"] = 0.5


static func _carro(root: Node3D, cfg: Dictionary) -> void:
	# Banco de trás de um carro, olhando para a frente: os dois personagens
	# sentados de frente para a câmera (enquadramento de vídeo POV).
	var dark := Color(0.16, 0.16, 0.18)
	box(root, Vector3(2.2, 0.1, 3.8), Vector3(0, 0.1, -0.7), dark)  # assoalho
	box(root, Vector3(2.2, 0.08, 3.8), Vector3(0, 1.75, -0.7), dark.lightened(0.15))  # teto
	for x in [-1.1, 1.1]:
		box(root, Vector3(0.08, 0.7, 3.8), Vector3(x, 0.45, -0.7), dark)
		box(root, Vector3(0.02, 0.75, 3.6), Vector3(x, 1.2, -0.7), Color(0.04, 0.05, 0.1), 0.5)  # janelas
	box(root, Vector3(2.2, 0.8, 0.02), Vector3(0, 1.2, -2.6), Color(0.04, 0.05, 0.1), 0.5)  # para-brisa
	box(root, Vector3(2.2, 0.5, 0.4), Vector3(0, 0.75, -2.45), dark.lightened(0.05))  # painel
	box(root, Vector3(2.2, 0.03, 0.3), Vector3(0, 1.0, -2.3), Color(0.3, 0.5, 1.0), 1.2)  # luz do painel
	var seat := Color(0.32, 0.26, 0.22)
	box(root, Vector3(2.0, 0.18, 0.6), Vector3(0, 0.5, -1.55), seat)  # banco da frente
	box(root, Vector3(2.0, 0.9, 0.18), Vector3(0, 0.95, -1.95), seat)
	for i in 3:
		for x in [1.9, -1.9]:
			var l := omni(root, Vector3(x, 2.0, -7.0 + i * 4.0), Color(1.0, 0.65, 0.3), 2.0, 4.0)
			l.add_child(PassBy.new(Vector3(0, 0, 9.0), 12.0))
	omni(root, Vector3(0, 1.5, -1.0), Color(0.45, 0.55, 1.0), 0.8, 3.0)  # luz interna
	cfg["camera_pos"] = Vector3(0, 1.2, 0.55)
	cfg["camera_look"] = Vector3(0, 0.95, -1.5)
	cfg["floor_y"] = 0.12
	cfg["slot_dist"] = 1.95
	cfg["slot_spread"] = 0.5
	cfg["center_dist"] = 1.95
	cfg["fog_density"] = 0.0
	cfg["ambient_energy"] = 0.5


static func _rua(root: Node3D, cfg: Dictionary) -> void:
	box(root, Vector3(9, 0.1, 50), Vector3(0, -0.05, -18), Color(0.13, 0.13, 0.14))
	box(root, Vector3(3, 0.3, 50), Vector3(-6, 0.1, -18), Color(0.35, 0.35, 0.33))
	box(root, Vector3(3, 0.3, 50), Vector3(6, 0.1, -18), Color(0.35, 0.35, 0.33))
	for z in range(0, -42, 2):
		box(root, Vector3(0.15, 0.01, 1.0), Vector3(0, 0.01, z), Color(0.75, 0.7, 0.55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1312
	for side in [-1, 1]:
		for i in 7:
			var h := rng.randf_range(5.0, 14.0)
			var z := -2.0 - i * 6.5
			box(root, Vector3(5, h, 6), Vector3(side * 10.0, h * 0.5, z), Color(0.18, 0.18, 0.2).lightened(rng.randf() * 0.1))
			for w in 6:
				if rng.randf() < 0.18:
					box(root, Vector3(0.05, 0.7, 0.9), Vector3(side * 7.47, rng.randf_range(2.0, h - 1.0), z + rng.randf_range(-2.0, 2.0)), Color(1.0, 0.8, 0.4), 1.6)
		for i in 5:
			var z := -3.0 - i * 9.0
			box(root, Vector3(0.12, 4.5, 0.12), Vector3(side * 4.6, 2.25, z), Color(0.25, 0.25, 0.25))
			var l := omni(root, Vector3(side * 4.0, 4.3, z), Color(1.0, 0.6, 0.25), 1.6, 8.0)
			if i % 2 == 1:
				l.add_child(Flicker.new(0.95, 5.0))
	car(root, Vector3(-2.6, 0, -6.5), 20, Color(0.3, 0.32, 0.36))
	car(root, Vector3(2.4, 0, -15.0), -160, Color(0.45, 0.1, 0.08))
	cfg["center_dist"] = 10.0
	cfg["camera_look"] = Vector3(0, 1.35, -6.0)
	cfg["fog_density"] = 0.03
	cfg["fog_color"] = Color(0.05, 0.04, 0.05)
	cfg["ambient_energy"] = 0.5
	cfg["approach_center"] = true


static func _casa(root: Node3D, cfg: Dictionary) -> void:
	for cell in [Vector2(-2, 0), Vector2(2, 0), Vector2(-2, -4), Vector2(2, -4)]:
		var c := Vector3(cell.x, 0, cell.y)
		prop(root, HOUSE + "geometry/floorWood.glb", c, 0, 1, Vector3(4, 0.05, 4), Vector3(0, 0, 0))
		prop(root, HOUSE + "geometry/ceilingPlaster.glb", c, 0, 1, Vector3(4, 0.05, 4), Vector3(0, 3.95, 0))
	wall(root, "wallPlaster", Vector3(-2, 0, 0), -90)
	wall(root, "wallWindowPlaster", Vector3(-2, 0, -4), -90)
	wall(root, "wallPlaster", Vector3(2, 0, 0), 90)
	wall(root, "wallPlaster", Vector3(2, 0, -4), 90)
	wall(root, "wallPlaster", Vector3(-2, 0, -4), 180)
	wall(root, "wallPlaster2", Vector3(2, 0, -4), 180)
	wall(root, "wallDoorPlaster", Vector3(-2, 0, 0), 0)
	wall(root, "wallPlaster", Vector3(2, 0, 0), 0)

	prop(root, HOUSE + "props/couchBig.glb", Vector3(-3.2, 0, -1.2), 90, 1, Vector3(1.2, 1.1, 2.4))
	prop(root, HOUSE + "props/carpet.glb", Vector3(-1.0, 0.06, -1.6), 0)
	prop(root, HOUSE + "props/sideboard.glb", Vector3(3.5, 0, -1.2), -90, 1, Vector3(0.5, 0.8, 1.5))
	prop(root, HOUSE + "props/tv.glb", Vector3(3.5, 0.8, -1.2), -90, 1, Vector3(0.6, 0.5, 0.4))
	var tv_light := omni(root, Vector3(2.8, 1.3, -1.2), Color(0.5, 0.6, 1.0), 1.0, 4.5)
	tv_light.add_child(Flicker.new(0.4, 11.0))
	prop(root, HOUSE + "props/table.glb", Vector3(-1.6, 0, -4.3), 0, 1, Vector3(1.7, 0.72, 1.1))
	prop(root, HOUSE + "props/chair.glb", Vector3(-2.4, 0, -4.3), 90)
	prop(root, HOUSE + "props/chair2.glb", Vector3(-0.8, 0, -4.4), -80)
	prop(root, HOUSE + "props/fridge.glb", Vector3(-3.3, 0, -5.4), 0, 1, Vector3(0.8, 2.0, 0.7))
	prop(root, HOUSE + "props/cabinetLow.glb", Vector3(-1.4, 0, -5.55), 0, 1, Vector3(1.5, 0.9, 0.6))
	prop(root, HOUSE + "props/knife.glb", Vector3(-1.2, 0.73, -4.1), 30)
	prop(root, HOUSE + "props/teddybear.glb", Vector3(0.6, 0.06, -3.3), 200)
	prop(root, HOUSE + "props/painting3.glb", Vector3(0.2, 1.8, -5.85), 0)
	prop(root, HOUSE + "props/lamp.glb", Vector3(-3.4, 0, 0.2), 0)
	# luar entrando pela janela
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.9)
	moon.light_energy = 2.0
	moon.spot_range = 9.0
	moon.spot_angle = 35.0
	moon.position = Vector3(-4.5, 2.8, -4.0)
	moon.rotation_degrees = Vector3(-35, -90, 0)
	root.add_child(moon)
	cfg["floor_y"] = 0.06
	cfg["slot_dist"] = 3.0
	cfg["camera_pos"] = Vector3(0, 1.68, 0.6)
	cfg["fog_density"] = 0.025
	cfg["ambient_energy"] = 0.45


# --- utilitários ----------------------------------------------------------------

static func prop(root: Node3D, path: String, pos: Vector3, rot_y := 0.0, s := 1.0,
		fallback := Vector3(0.4, 0.4, 0.4), offset := Vector3.ZERO, tint := Color.WHITE) -> Node3D:
	var n := AssetLib.spawn(path, fallback)
	AssetLib.psxify(n, tint)
	n.position = pos + offset
	n.rotation.y = deg_to_rad(rot_y)
	n.scale = Vector3.ONE * s
	root.add_child(n)
	return n


## Parede modular do pacote de casa (4x4m, encostada na borda +Z da célula).
static func wall(root: Node3D, piece: String, cell: Vector3, rot_y: float) -> void:
	var path := HOUSE + "geometry/" + piece + ".glb"
	if ResourceLoader.exists(path):
		prop(root, path, cell, rot_y)
		return
	var b := box(root, Vector3(4, 4, 0.2), Vector3.ZERO, Color(0.55, 0.5, 0.45))
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y))
	b.position = cell + basis * Vector3(0, 2, 1.9)
	b.rotation.y = deg_to_rad(rot_y)


static func car(root: Node3D, pos: Vector3, rot_y: float, color: Color) -> void:
	prop(root, CAR, pos, rot_y, 0.72, Vector3(2.0, 1.4, 4.4), Vector3.ZERO, color.lightened(0.3))


static func box(root: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = AssetLib.make_material(color, emission)
	root.add_child(mi)
	return mi


static func omni(root: Node3D, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.add_to_group("scene_lights")
	root.add_child(l)
	return l


# --- comportamentos de luz ------------------------------------------------------

## Lâmpada falhando. Filho de uma Light3D.
class Flicker extends Node:
	var amount := 0.5
	var speed := 10.0
	var _base := -1.0
	var _t := randf() * 100.0

	func _init(p_amount := 0.5, p_speed := 10.0) -> void:
		amount = p_amount
		speed = p_speed

	func _process(delta: float) -> void:
		var light := get_parent() as Light3D
		if light == null:
			return
		if _base < 0.0:
			_base = light.light_energy
		_t += delta * speed
		var n := sin(_t) * sin(_t * 2.31) * sin(_t * 0.53)
		var off := 1.0 if randf() > 0.015 * amount * speed else 0.0
		light.light_energy = _base * clampf(1.0 - amount * 0.5 + n * amount * 0.5, 0.0, 2.0) * off


## Luz de emergência pulsando.
class Pulse extends Node:
	var amount := 0.5
	var speed := 1.5
	var _base := -1.0
	var _t := 0.0

	func _init(p_amount := 0.5, p_speed := 1.5) -> void:
		amount = p_amount
		speed = p_speed

	func _process(delta: float) -> void:
		var light := get_parent() as Light3D
		if light == null:
			return
		if _base < 0.0:
			_base = light.light_energy
		_t += delta * speed
		light.light_energy = _base * (1.0 - amount * 0.5 * (1.0 + sin(_t * TAU)))


## Luz que passa (postes vistos de dentro do carro).
class PassBy extends Node:
	var velocity := Vector3(0, 0, 9)
	var span := 12.0
	var _start := Vector3.ZERO
	var _ready_done := false

	func _init(p_velocity := Vector3(0, 0, 9), p_span := 12.0) -> void:
		velocity = p_velocity
		span = p_span

	func _process(delta: float) -> void:
		var n := get_parent() as Node3D
		if n == null:
			return
		if not _ready_done:
			_start = n.position
			_ready_done = true
		n.position += velocity * delta
		if n.position.distance_to(_start) > span:
			n.position -= velocity.normalized() * span

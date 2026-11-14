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
		"campo":
			_campo(root, cfg)
		"fazenda_casa":
			_fazenda_casa(root, cfg)
		"celeiro":
			_celeiro(root, cfg)
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
	cfg["floor_y"] = -0.12
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


static func _campo(root: Node3D, cfg: Dictionary) -> void:
	# Fazenda / milharal à noite: celeiro, cerca, plantação e lua.
	box(root, Vector3(60, 0.1, 60), Vector3(0, -0.05, -20), Color(0.16, 0.14, 0.08))
	box(root, Vector3(3.0, 0.02, 40), Vector3(0, 0.0, -18), Color(0.25, 0.2, 0.12))  # estradinha de terra
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for side in [-1, 1]:
		for row in 6:
			for i in 14:
				var h := rng.randf_range(1.4, 2.2)
				var stalk := box(root, Vector3(0.12, h, 0.12), Vector3(side * (2.3 + row * 0.8) + rng.randf_range(-0.2, 0.2), h * 0.5, -1.5 - i * 1.6 + rng.randf_range(-0.3, 0.3)), Color(0.32, 0.3, 0.12).darkened(rng.randf() * 0.4))
				stalk.rotation.z = rng.randf_range(-0.15, 0.15)
		for i in 10:
			box(root, Vector3(0.1, 1.1, 0.1), Vector3(side * 1.8, 0.55, -1.0 - i * 2.2), Color(0.3, 0.22, 0.14))
		box(root, Vector3(0.05, 0.08, 22), Vector3(side * 1.8, 0.9, -11), Color(0.3, 0.22, 0.14))
	# celeiro ao fundo
	box(root, Vector3(6, 4, 5), Vector3(-5, 2, -22), Color(0.35, 0.08, 0.06))
	var roof := box(root, Vector3(4.6, 0.2, 5.4), Vector3(-6.6, 4.6, -22), Color(0.2, 0.18, 0.16))
	roof.rotation.z = deg_to_rad(35)
	var roof2 := box(root, Vector3(4.6, 0.2, 5.4), Vector3(-3.4, 4.6, -22), Color(0.2, 0.18, 0.16))
	roof2.rotation.z = deg_to_rad(-35)
	box(root, Vector3(0.8, 0.6, 0.05), Vector3(-5, 2.8, -19.47), Color(1.0, 0.75, 0.35), 1.5)  # janela acesa
	omni(root, Vector3(-5, 2.6, -18.5), Color(1.0, 0.7, 0.35), 1.2, 6.0)
	# lua
	var moon := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 2.5
	sph.height = 5.0
	moon.mesh = sph
	moon.position = Vector3(10, 16, -45)
	moon.material_override = AssetLib.make_material(Color(0.85, 0.88, 1.0), 2.0)
	root.add_child(moon)
	var moonlight := DirectionalLight3D.new()
	moonlight.light_color = Color(0.5, 0.6, 0.9)
	moonlight.light_energy = 0.75
	moonlight.rotation_degrees = Vector3(-35, 160, 0)
	root.add_child(moonlight)
	# luz da varanda da casa (atrás do jogador) e o disco voador parado no céu
	omni(root, Vector3(-1.2, 2.6, 1.6), Color(1.0, 0.75, 0.45), 1.3, 8.0)
	var u := ufo(root, Vector3(3.5, 9.0, -24.0))
	u.scale = Vector3.ONE * 1.4
	cfg["camera_look"] = Vector3(0, 1.5, -6.0)
	cfg["center_dist"] = 5.0
	cfg["fog_density"] = 0.03
	cfg["fog_color"] = Color(0.05, 0.07, 0.1)
	cfg["ambient_energy"] = 0.7


static func _fazenda_casa(root: Node3D, cfg: Dictionary) -> void:
	# Cozinha de casa de fazenda (PSX Horror Farm Kit). Paredes de 2x3m.
	var K := AssetLib.TP + "horror_farm_kit/glb/"
	for x in [-2, 0, 2]:
		for z in [0, -2, -4]:
			prop(root, K + "floor_lino.glb", Vector3(x, 0, z), 0, 1, Vector3(2, 0.02, 2))
	box(root, Vector3(6.4, 0.1, 6.6), Vector3(0, 3.0, -2), Color(0.32, 0.26, 0.2))  # teto
	prop(root, K + "wall_kitchen.glb", Vector3(-2, 0, -5), 0, 1, Vector3(2, 3, 0.2))
	prop(root, K + "wall_window_kitchen.glb", Vector3(0, 0, -5), 0, 1, Vector3(2, 3, 0.2))
	prop(root, K + "wall_doorway_kitchen.glb", Vector3(2, 0, -5), 0, 1, Vector3(2, 3, 0.2))
	prop(root, K + "door_interior.glb", Vector3(2, 0, -5), 0, 1, Vector3(1, 2.2, 0.1))
	for z in [-4, -2, 0]:
		prop(root, K + ("wall_window_kitchen.glb" if z == -2 else "wall_kitchen.glb"), Vector3(-3, 0, z), 90, 1, Vector3(2, 3, 0.2))
		prop(root, K + "wall_kitchen.glb", Vector3(3, 0, z), -90, 1, Vector3(2, 3, 0.2))
	for p in [Vector3(-3, 0, -5), Vector3(3, 0, -5)]:
		prop(root, K + "wall_post_farm.glb", p, 0)
	prop(root, K + "cookstove.glb", Vector3(-2.2, 0, -4.45), 0, 1, Vector3(1.1, 1.0, 0.7))
	prop(root, K + "hoosier.glb", Vector3(0.9, 0, -4.6), 0, 1, Vector3(1.1, 1.9, 0.6))
	prop(root, K + "icebox.glb", Vector3(2.55, 0, -2.6), -90, 1, Vector3(0.8, 1.4, 0.6))
	prop(root, K + "pump_sink.glb", Vector3(-2.5, 0, -1.2), 90, 1, Vector3(1.2, 1.0, 0.6))
	prop(root, K + "calendar_farm.glb", Vector3(-1.2, 0, -4.88), 0)
	prop(root, K + "sampler.glb", Vector3(2.88, 0, -1.0), -90)
	prop(root, K + "window_curtained.glb", Vector3(0, 0, -4.88), 0)
	# mesa com a lamparina
	box(root, Vector3(1.4, 0.08, 0.9), Vector3(0, 0.78, -2.6), Color(0.35, 0.22, 0.12))
	for lx in [-0.6, 0.6]:
		for lz in [-0.35, 0.35]:
			box(root, Vector3(0.07, 0.78, 0.07), Vector3(lx, 0.39, -2.6 + lz), Color(0.3, 0.19, 0.1))
	box(root, Vector3(0.12, 0.22, 0.12), Vector3(0.3, 0.93, -2.6), Color(1.0, 0.7, 0.3), 2.0)
	var lamp := omni(root, Vector3(0.3, 1.2, -2.6), Color(1.0, 0.65, 0.3), 1.6, 5.5)
	lamp.add_child(Flicker.new(0.3, 8.0))
	# luz verde lá fora, entrando pelas janelas
	var green := omni(root, Vector3(0, 1.8, -6.2), Color(0.35, 1.0, 0.45), 3.5, 6.0)
	green.add_child(Pulse.new(0.5, 0.4))
	omni(root, Vector3(-4.2, 1.8, -2), Color(0.35, 1.0, 0.45), 2.0, 4.0)
	cfg["floor_y"] = 0.0
	cfg["slot_dist"] = 2.5
	cfg["camera_pos"] = Vector3(0, 1.62, 0.8)
	cfg["fog_density"] = 0.03
	cfg["fog_color"] = Color(0.05, 0.06, 0.04)
	cfg["ambient_energy"] = 0.45


static func _celeiro(root: Node3D, cfg: Dictionary) -> void:
	var wood := Color(0.36, 0.24, 0.14)
	box(root, Vector3(9, 0.1, 14), Vector3(0, -0.05, -5), Color(0.24, 0.18, 0.1))  # chão de terra
	for side in [-1, 1]:
		for i in 14:
			box(root, Vector3(0.12, 4.5, 1.0), Vector3(side * 4.4, 2.25, 1.5 - i * 1.0), wood.darkened(0.15 * (i % 2)))
		for z in [-1.0, -5.0, -9.0]:
			box(root, Vector3(0.3, 4.6, 0.3), Vector3(side * 3.6, 2.3, z), wood.darkened(0.25))
	for z in [-1.0, -5.0, -9.0]:
		box(root, Vector3(7.5, 0.3, 0.3), Vector3(0, 4.2, z), wood.darkened(0.3))  # vigas
	box(root, Vector3(9, 0.2, 14), Vector3(0, 4.7, -5), wood.darkened(0.45))
	# fundo: portão aberto com a luz verde lá fora
	box(root, Vector3(2.8, 4.5, 0.12), Vector3(-2.9, 2.25, -11.5), wood.darkened(0.2))
	box(root, Vector3(2.8, 4.5, 0.12), Vector3(2.9, 2.25, -11.5), wood.darkened(0.2))
	box(root, Vector3(3.0, 3.6, 0.05), Vector3(0, 1.8, -12.0), Color(0.3, 0.9, 0.45), 1.4)
	var outside := omni(root, Vector3(0, 2.0, -12.8), Color(0.35, 1.0, 0.45), 4.0, 9.0)
	outside.add_child(Pulse.new(0.4, 0.5))
	# fardos de feno e sangue
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 9:
		var p := Vector3(rng.randf_range(-3.6, -1.8) if i % 2 == 0 else rng.randf_range(1.8, 3.6), 0.3, rng.randf_range(-10.0, -1.0))
		var bale := box(root, Vector3(1.0, 0.6, 0.6), p, Color(0.62, 0.52, 0.22).darkened(rng.randf() * 0.3))
		bale.rotation.y = rng.randf_range(-0.5, 0.5)
	box(root, Vector3(1.8, 0.01, 1.2), Vector3(0.2, 0.01, -4.8), Color(0.3, 0.02, 0.02))
	box(root, Vector3(0.6, 0.01, 0.4), Vector3(-0.8, 0.01, -3.6), Color(0.28, 0.02, 0.02))
	# lampião pendurado
	box(root, Vector3(0.02, 1.2, 0.02), Vector3(-0.6, 3.6, -3.2), Color(0.1, 0.1, 0.1))
	box(root, Vector3(0.2, 0.28, 0.2), Vector3(-0.6, 2.9, -3.2), Color(1.0, 0.7, 0.3), 2.0)
	var lantern := omni(root, Vector3(-0.6, 2.8, -3.2), Color(1.0, 0.65, 0.3), 1.8, 6.0)
	lantern.add_child(Flicker.new(0.6, 9.0))
	cfg["center_dist"] = 5.0
	cfg["camera_look"] = Vector3(0, 1.3, -6.0)
	cfg["fog_density"] = 0.04
	cfg["fog_color"] = Color(0.04, 0.06, 0.04)
	cfg["ambient_energy"] = 0.4


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


# --- disco voador (procedural, estilo PSX) -------------------------------------------

## Disco voador flutuando e girando, com luzes piscando, feixe de abdução
## e partículas subindo pelo feixe.
static func ufo(root: Node3D, pos: Vector3, beam_color := Color(0.4, 1.0, 0.55)) -> Node3D:
	var u := Node3D.new()
	u.position = pos
	root.add_child(u)
	var body := Node3D.new()
	u.add_child(body)
	var hull := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 2.4
	cyl.height = 0.38
	cyl.radial_segments = 12
	hull.mesh = cyl
	hull.material_override = AssetLib.make_material(Color(0.45, 0.47, 0.52))
	body.add_child(hull)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 2.4
	rc.bottom_radius = 1.5
	rc.height = 0.3
	rc.radial_segments = 12
	rim.mesh = rc
	rim.position.y = -0.33
	rim.material_override = AssetLib.make_material(Color(0.3, 0.31, 0.35))
	body.add_child(rim)
	var dome := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.85
	sph.height = 1.1
	sph.radial_segments = 10
	sph.rings = 5
	dome.mesh = sph
	dome.position.y = 0.35
	dome.material_override = AssetLib.make_material(Color(0.5, 0.9, 0.8), 1.2)
	body.add_child(dome)
	var core := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.7
	cc.bottom_radius = 0.7
	cc.height = 0.08
	core.mesh = cc
	core.position.y = -0.5
	core.material_override = AssetLib.make_material(beam_color, 3.0)
	body.add_child(core)
	for i in 8:
		var a := TAU * i / 8.0
		var lamp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.22, 0.12, 0.22)
		lamp.mesh = bm
		lamp.position = Vector3(cos(a) * 2.25, -0.12, sin(a) * 2.25)
		lamp.material_override = AssetLib.make_material(Color(1.0, 0.9, 0.3) if i % 2 == 0 else Color(1.0, 0.2, 0.15), 3.0)
		lamp.add_child(Blink.new(0.25 * i))
		body.add_child(lamp)
	body.add_child(Hover.new())
	var beam := SpotLight3D.new()
	beam.light_color = beam_color
	beam.light_energy = 9.0
	beam.spot_range = pos.y + 4.0
	beam.spot_angle = 16.0
	beam.rotation_degrees = Vector3(-90, 0, 0)
	beam.position.y = -0.5
	beam.add_child(Flicker.new(0.15, 6.0))
	u.add_child(beam)
	var glow := OmniLight3D.new()
	glow.light_color = beam_color
	glow.light_energy = 2.0
	glow.omni_range = 4.0
	glow.position.y = -pos.y + 0.3  # poça de luz no chão
	u.add_child(glow)
	var dust := BeamDust.new()
	dust.height = pos.y
	dust.color = beam_color
	u.add_child(dust)
	return u


## Faz o disco girar e balançar.
class Hover extends Node:
	var _t := randf() * 10.0

	func _process(delta: float) -> void:
		var n := get_parent() as Node3D
		if n == null:
			return
		_t += delta
		n.rotation.y += delta * 0.8
		n.position.y = sin(_t * 1.3) * 0.15
		n.rotation.z = sin(_t * 0.9) * 0.05


## Pisca uma luzinha (alterna visível/invisível).
class Blink extends Node:
	var _t := 0.0

	func _init(offset := 0.0) -> void:
		_t = offset

	func _process(delta: float) -> void:
		_t += delta
		var n := get_parent() as Node3D
		if n:
			n.visible = fmod(_t, 1.0) < 0.55


## Partículas subindo pelo feixe de abdução.
class BeamDust extends Node3D:
	var height := 7.0
	var color := Color(0.4, 1.0, 0.55)
	var _bits: Array[MeshInstance3D] = []

	func _ready() -> void:
		var mat := AssetLib.make_material(color, 3.0)
		for i in 18:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * randf_range(0.04, 0.09)
			b.mesh = bm
			b.material_override = mat
			add_child(b)
			_reset(b, randf() * height)
			_bits.append(b)

	func _reset(b: MeshInstance3D, y_up: float) -> void:
		var r := randf() * 0.9
		var a := randf() * TAU
		b.position = Vector3(cos(a) * r, -height + y_up, sin(a) * r)

	func _process(delta: float) -> void:
		for b in _bits:
			b.position.y += delta * randf_range(0.8, 1.6)
			b.rotate_y(delta * 2.0)
			if b.position.y > -0.6:
				_reset(b, 0.0)


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

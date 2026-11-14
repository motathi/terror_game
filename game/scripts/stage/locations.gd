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
		"elevador":
			_elevador(root, cfg)
		"fazenda_casa":
			_fazenda_casa(root, cfg)
		"celeiro":
			_celeiro(root, cfg)
		"quintal":
			_quintal(root, cfg)
		"avenida":
			_avenida(root, cfg)
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


static func _elevador(root: Node3D, cfg: Dictionary) -> void:
	# Cabine de elevador com portas que abrem (nós "porta_e"/"porta_d") e um
	# corredor escuro com luz de emergência do outro lado.
	var metal := Color(0.52, 0.54, 0.58)
	box(root, Vector3(2.0, 0.1, 2.2), Vector3(0, -0.05, 0.5), Color(0.25, 0.25, 0.27))
	box(root, Vector3(2.0, 0.1, 2.2), Vector3(0, 2.6, 0.5), metal.darkened(0.3))
	box(root, Vector3(1.2, 0.04, 0.5), Vector3(0, 2.54, 0.5), Color(0.9, 0.95, 1.0), 1.5)
	for x in [-1.0, 1.0]:
		box(root, Vector3(0.08, 2.6, 2.2), Vector3(x, 1.3, 0.5), metal)
	box(root, Vector3(2.0, 2.6, 0.08), Vector3(0, 1.3, 1.6), metal)
	box(root, Vector3(0.3, 2.6, 0.1), Vector3(-0.85, 1.3, -0.6), metal.darkened(0.1))
	box(root, Vector3(0.3, 2.6, 0.1), Vector3(0.85, 1.3, -0.6), metal.darkened(0.1))
	box(root, Vector3(2.0, 0.4, 0.1), Vector3(0, 2.4, -0.6), metal.darkened(0.1))
	box(root, Vector3(0.24, 0.16, 0.02), Vector3(0, 2.4, -0.54), Color(0.05, 0.02, 0.02))
	var pe := box(root, Vector3(0.7, 2.2, 0.05), Vector3(-0.35, 1.1, -0.64), metal.lightened(0.1))
	pe.name = "porta_e"
	var pd := box(root, Vector3(0.7, 2.2, 0.05), Vector3(0.35, 1.1, -0.64), metal.lightened(0.1))
	pd.name = "porta_d"
	var cab := omni(root, Vector3(0, 2.3, 0.5), Color(0.85, 0.92, 1.0), 1.2, 4.0)
	cab.add_child(Flicker.new(0.3, 10.0))
	# corredor do 4º andar
	box(root, Vector3(3.0, 0.1, 9.0), Vector3(0, -0.05, -5.2), Color(0.2, 0.19, 0.18))
	box(root, Vector3(3.0, 0.1, 9.0), Vector3(0, 2.8, -5.2), Color(0.25, 0.24, 0.22))
	for x in [-1.5, 1.5]:
		box(root, Vector3(0.1, 2.8, 9.0), Vector3(x, 1.4, -5.2), Color(0.42, 0.4, 0.34))
	box(root, Vector3(3.0, 2.8, 0.1), Vector3(0, 1.4, -9.6), Color(0.35, 0.33, 0.3))
	box(root, Vector3(1.2, 0.01, 0.9), Vector3(0.3, 0.01, -2.8), Color(0.3, 0.02, 0.02))
	box(root, Vector3(0.1, 1.2, 0.6), Vector3(-1.44, 1.0, -3.6), Color(0.3, 0.02, 0.02))
	var red := omni(root, Vector3(0, 2.5, -4.5), Color(1.0, 0.12, 0.08), 2.5, 8.0)
	red.add_child(Pulse.new(0.6, 1.4))
	cfg["camera_pos"] = Vector3(0, 1.62, 0.7)
	cfg["camera_look"] = Vector3(0, 1.5, -3.0)
	cfg["hands"] = false
	cfg["fog_density"] = 0.04
	cfg["ambient_energy"] = 0.35


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


static func _avenida(root: Node3D, cfg: Dictionary) -> void:
	# Avenida principal vista de fora: carros abandonados de porta aberta, um
	# capotado, outro pegando fogo, fumaça e incêndio no horizonte, um posto de
	# gasolina e o carro prata do Rafael (nó "carro_prata", anda pela cena).
	box(root, Vector3(9, 0.1, 130), Vector3(0, -0.05, -45), Color(0.12, 0.12, 0.13))
	for side in [-1, 1]:
		box(root, Vector3(3, 0.3, 130), Vector3(side * 6, 0.1, -45), Color(0.33, 0.33, 0.31))
	for z in range(14, -108, -3):
		box(root, Vector3(0.15, 0.01, 1.2), Vector3(0, 0.01, z), Color(0.75, 0.7, 0.55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for side in [-1, 1]:
		for i in 17:
			var z := 8.0 - i * 7.0
			if side == 1 and z < -13.0 and z > -30.0:
				continue  # espaço do posto
			var h := rng.randf_range(6.0, 16.0)
			box(root, Vector3(5, h, 6.4), Vector3(side * 10.0, h * 0.5, z), Color(0.17, 0.16, 0.17).lightened(rng.randf() * 0.1))
			for w in 5:
				if rng.randf() < 0.14:
					box(root, Vector3(0.05, 0.7, 0.9), Vector3(side * 7.47, rng.randf_range(2.0, h - 1.0), z + rng.randf_range(-2.4, 2.4)), Color(1.0, 0.75, 0.35), 1.4)
		for i in 9:
			var z := 6.0 - i * 12.0
			box(root, Vector3(0.12, 4.5, 0.12), Vector3(side * 4.6, 2.25, z), Color(0.25, 0.25, 0.25))
			if (i + (1 if side > 0 else 0)) % 3 != 0:
				var l := omni(root, Vector3(side * 4.0, 4.3, z), Color(1.0, 0.62, 0.3), 2.4, 11.0)
				if i % 2 == 1:
					l.add_child(Flicker.new(0.95, 5.0))
	# carros abandonados, portas abertas
	for c in [[-2.3, -4.0, 20.0, Color(0.3, 0.32, 0.36)], [2.5, -15.0, 170.0, Color(0.45, 0.1, 0.08)],
			[-2.0, -31.0, 60.0, Color(0.2, 0.3, 0.22)], [2.2, -46.0, 195.0, Color(0.6, 0.55, 0.4)], [-2.5, -62.0, -15.0, Color(0.25, 0.25, 0.4)]]:
		var n := car_node(root, Vector3(c[0], 0, c[1]), c[2], c[3])
		var hinge := Node3D.new()
		hinge.position = Vector3(1.05, 0.75, 1.2)
		hinge.rotation.y = deg_to_rad(65)
		n.add_child(hinge)
		box(hinge, Vector3(0.06, 0.8, 1.1), Vector3(0, 0, -0.55), (c[3] as Color).lightened(0.2))
	# capotado no meio da pista
	var flip := car_node(root, Vector3(-0.6, 1.58, -38.0), 75.0, Color(0.5, 0.5, 0.52))
	flip.rotation.z = PI
	# carro pegando fogo
	car_node(root, Vector3(2.4, 0, -54.0), 160.0, Color(0.2, 0.2, 0.2))
	var fire := omni(root, Vector3(2.4, 1.8, -54.0), Color(1.0, 0.45, 0.12), 3.0, 9.0)
	fire.add_child(Flicker.new(0.7, 9.0))
	box(root, Vector3(1.2, 0.6, 2.0), Vector3(2.4, 1.4, -54.0), Color(1.0, 0.45, 0.1), 3.0)
	root.add_child(Smoke.new(Vector3(2.4, 2.0, -54.0), 0.9))
	# entulho
	for i in 26:
		var deb := box(root, Vector3(rng.randf_range(0.2, 0.7), rng.randf_range(0.05, 0.25), rng.randf_range(0.2, 0.7)),
			Vector3(rng.randf_range(-4.0, 4.0), 0.05, rng.randf_range(-70.0, 6.0)), Color(0.3, 0.28, 0.25).darkened(rng.randf() * 0.5))
		deb.rotation.y = rng.randf() * TAU
	# incêndio e fumaça no horizonte
	box(root, Vector3(40, 7, 1), Vector3(0, 3.5, -112), Color(1.0, 0.42, 0.12), 2.0)
	omni(root, Vector3(0, 6.0, -98), Color(1.0, 0.45, 0.15), 4.0, 40.0)
	for x in [-14.0, -4.0, 7.0, 16.0]:
		root.add_child(Smoke.new(Vector3(x, 5.0, -104.0), 3.5))
	# posto de gasolina (lado direito)
	box(root, Vector3(6.5, 0.35, 6.0), Vector3(9.0, 4.0, -21.0), Color(0.8, 0.15, 0.1))
	box(root, Vector3(6.0, 0.03, 5.5), Vector3(9.0, 3.8, -21.0), Color(1.0, 1.0, 0.95), 1.6)
	for z in [-19.0, -23.0]:
		box(root, Vector3(0.35, 3.8, 0.35), Vector3(7.6, 1.9, z), Color(0.75, 0.75, 0.75))
		box(root, Vector3(0.6, 1.4, 0.9), Vector3(9.2, 0.7, z), Color(0.85, 0.85, 0.82))
		box(root, Vector3(0.5, 0.25, 0.04), Vector3(8.88, 1.1, z), Color(0.3, 1.0, 0.4), 1.2)
	box(root, Vector3(6.5, 0.12, 7.0), Vector3(9.5, 0.06, -21.0), Color(0.3, 0.3, 0.3))
	omni(root, Vector3(8.0, 3.4, -21.0), Color(0.95, 1.0, 1.0), 3.5, 12.0)
	# o carro prata, com faróis e lanternas
	var mine := car_node(root, Vector3(1.4, 0, 10.0), 180.0, Color(0.75, 0.75, 0.78))
	mine.name = "carro_prata"
	for x in [-0.62, 0.62]:
		box(mine, Vector3(0.3, 0.14, 0.05), Vector3(x, 0.62, 2.36), Color(1, 1, 0.9), 3.0)
		box(mine, Vector3(0.28, 0.14, 0.05), Vector3(x, 0.8, -2.36), Color(1, 0.05, 0.05), 3.0)
		var hl := SpotLight3D.new()
		hl.position = Vector3(x, 0.65, 2.4)
		hl.light_color = Color(1.0, 0.95, 0.8)
		hl.light_energy = 3.0
		hl.spot_range = 22.0
		hl.spot_angle = 26.0
		hl.rotation_degrees = Vector3(-4, 0, 0)  # o carro olha para +Z (local)
		hl.rotate_object_local(Vector3.UP, PI)
		mine.add_child(hl)
	var tail := omni(mine, Vector3(0, 0.9, -2.8), Color(1.0, 0.1, 0.05), 0.8, 3.0)
	tail.remove_from_group("scene_lights")
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.6, 0.6)
	moon.light_energy = 0.5
	moon.rotation_degrees = Vector3(-35, 30, 0)
	root.add_child(moon)
	var glow := DirectionalLight3D.new()  # clarão laranja do incêndio, vindo do horizonte
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 0.7
	glow.rotation_degrees = Vector3(-12, 180, 0)
	root.add_child(glow)
	cfg["camera_pos"] = Vector3(4.0, 2.6, 16.0)
	cfg["camera_look"] = Vector3(1.4, 0.8, 6.0)
	cfg["hands"] = false
	cfg["center_dist"] = 6.0
	cfg["fog_density"] = 0.01
	cfg["fog_color"] = Color(0.32, 0.15, 0.08)
	cfg["ambient"] = Color(0.6, 0.48, 0.44)
	cfg["ambient_energy"] = 1.1


static func _quintal(root: Node3D, cfg: Dictionary) -> void:
	# Quintal de casa no interior, à noite: muro de bloco, portão, casinha do
	# Caramelo, varal, mangueira e o poste da rua do outro lado do muro.
	box(root, Vector3(30, 0.1, 30), Vector3(0, -0.05, -8), Color(0.13, 0.15, 0.07))  # grama
	box(root, Vector3(4.5, 0.03, 3.2), Vector3(0, 0.0, -0.4), Color(0.36, 0.35, 0.33))  # cimentado
	var block := Color(0.46, 0.43, 0.38)
	box(root, Vector3(12.5, 2.3, 0.25), Vector3(0, 1.15, -9.5), block)
	for side in [-1, 1]:
		box(root, Vector3(0.25, 2.3, 10.5), Vector3(side * 6.2, 1.15, -4.4), block.darkened(0.12))
	for i in 7:
		box(root, Vector3(0.3, 0.12, 0.3), Vector3(-6 + i * 2, 2.33, -9.5), block.darkened(0.25))  # pilaretes
	box(root, Vector3(1.6, 2.0, 0.08), Vector3(2.6, 1.0, -9.34), Color(0.1, 0.11, 0.12))  # portão
	for i in 8:
		box(root, Vector3(0.03, 1.9, 0.1), Vector3(1.9 + i * 0.2, 1.0, -9.3), Color(0.16, 0.17, 0.18))
	# casinha do Caramelo
	var dh := Node3D.new()
	dh.position = Vector3(-2.7, 0, -4.6)
	dh.rotation.y = deg_to_rad(22)
	root.add_child(dh)
	var wood := Color(0.5, 0.3, 0.15)
	box(dh, Vector3(1.0, 0.75, 1.15), Vector3(0, 0.375, 0), wood)
	var r1 := box(dh, Vector3(0.66, 0.06, 1.3), Vector3(-0.27, 0.92, 0), Color(0.55, 0.12, 0.08))
	r1.rotation.z = deg_to_rad(38)
	var r2 := box(dh, Vector3(0.66, 0.06, 1.3), Vector3(0.27, 0.92, 0), Color(0.55, 0.12, 0.08))
	r2.rotation.z = deg_to_rad(-38)
	box(dh, Vector3(0.44, 0.5, 0.02), Vector3(0, 0.27, 0.58), Color(0.02, 0.02, 0.02))
	var plate := Label3D.new()
	plate.text = "CARAMELO"
	plate.font_size = 40
	plate.pixel_size = 0.004
	plate.modulate = Color(0.95, 0.9, 0.75)
	plate.outline_size = 6
	plate.position = Vector3(0, 0.62, 0.59)
	plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dh.add_child(plate)
	box(root, Vector3(0.3, 0.08, 0.3), Vector3(-1.9, 0.04, -3.7), Color(0.7, 0.12, 0.1))  # pote de ração
	# varal com lençóis balançando
	for x in [1.6, 4.6]:
		box(root, Vector3(0.07, 2.0, 0.07), Vector3(x, 1.0, -6.0), Color(0.4, 0.4, 0.42))
	box(root, Vector3(3.0, 0.015, 0.015), Vector3(3.1, 1.95, -6.0), Color(0.2, 0.2, 0.2))
	for i in 3:
		var sheet := box(root, Vector3(0.75, 0.95, 0.02), Vector3(2.15 + i * 0.95, 1.45, -6.0), Color(0.85, 0.85, 0.82).darkened(0.1 * i))
		sheet.add_child(Sway.new(0.06 + 0.02 * i, 1.1 + 0.3 * i))
	# mangueira
	box(root, Vector3(0.35, 2.6, 0.35), Vector3(4.6, 1.3, -8.2), Color(0.25, 0.17, 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 9:
		var leaf := box(root, Vector3(1.4, 1.0, 1.4), Vector3(4.6 + rng.randf_range(-1.2, 1.2), 3.0 + rng.randf_range(-0.3, 0.8), -8.2 + rng.randf_range(-1.0, 1.0)), Color(0.07, 0.13, 0.06).darkened(rng.randf() * 0.4))
		leaf.rotation.y = rng.randf_range(0, 1.5)
	# poste da rua atrás do muro
	box(root, Vector3(0.15, 5.0, 0.15), Vector3(-3.2, 2.5, -11.0), Color(0.3, 0.3, 0.3))
	box(root, Vector3(0.5, 0.12, 0.25), Vector3(-3.0, 4.95, -10.9), Color(1.0, 0.65, 0.3), 2.5)
	var street := omni(root, Vector3(-3.0, 4.6, -10.5), Color(1.0, 0.6, 0.28), 1.6, 9.0)
	street.add_child(Flicker.new(0.25, 6.0))
	# luz da área (atrás de você, na porta da cozinha)
	omni(root, Vector3(0.4, 2.6, 1.0), Color(1.0, 0.82, 0.55), 2.0, 11.0)
	var moonlight := DirectionalLight3D.new()
	moonlight.light_color = Color(0.5, 0.6, 0.9)
	moonlight.light_energy = 0.8
	moonlight.rotation_degrees = Vector3(-40, 150, 0)
	root.add_child(moonlight)
	cfg["camera_look"] = Vector3(0, 1.25, -5.0)
	cfg["center_dist"] = 4.4
	cfg["fog_density"] = 0.035
	cfg["fog_color"] = Color(0.04, 0.05, 0.07)
	cfg["ambient"] = Color(0.42, 0.44, 0.58)
	cfg["ambient_energy"] = 0.85


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


## Carro dentro de um Node3D (frente para +Z local; tamanho real ~2 x 4.7 m),
## para poder mover, girar e pendurar portas/luzes nele.
static func car_node(root: Node3D, pos: Vector3, rot_y: float, color: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y)
	root.add_child(n)
	prop(n, CAR, Vector3.ZERO, 0.0, 0.72, Vector3(2.0, 1.4, 4.4), Vector3.ZERO, color.lightened(0.3))
	return n


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


## Coluna de fumaça: blocos escuros subindo e se abrindo, em loop.
class Smoke extends Node3D:
	var base := Vector3.ZERO
	var size := 1.0
	var _puffs: Array = []

	func _init(p_base := Vector3.ZERO, p_size := 1.0) -> void:
		base = p_base
		size = p_size

	func _ready() -> void:
		for i in 14:
			var mi := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3.ONE
			mi.mesh = m
			mi.material_override = AssetLib.make_material(Color(0.12, 0.1, 0.1).lightened(randf() * 0.12))
			add_child(mi)
			_puffs.append([mi, randf()])

	func _process(delta: float) -> void:
		for p in _puffs:
			p[1] = fmod(p[1] + delta * 0.05, 1.0)
			var k: float = p[1]
			var mi: MeshInstance3D = p[0]
			mi.position = base + Vector3(sin(k * 9.0 + mi.get_index()) * size * 0.6 + k * size * 2.0, k * size * 10.0, cos(k * 7.0 + mi.get_index()) * size * 0.4)
			mi.scale = Vector3.ONE * size * (0.6 + k * 2.2)
			mi.rotation = Vector3(k * 2.0, k * 3.0 + mi.get_index(), 0)


## Pano no varal balançando com o vento.
class Sway extends Node:
	var amount := 0.06
	var speed := 1.2
	var _t := randf() * 10.0

	func _init(p_amount := 0.06, p_speed := 1.2) -> void:
		amount = p_amount
		speed = p_speed

	func _process(delta: float) -> void:
		_t += delta * speed
		var n := get_parent() as Node3D
		if n:
			n.rotation.x = sin(_t) * amount + sin(_t * 2.7) * amount * 0.3


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

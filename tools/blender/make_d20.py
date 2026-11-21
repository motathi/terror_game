#!/usr/bin/env python3
"""Modela o d20 do teste de dado no Blender e exporta para o jogo.

Uso (Blender como módulo Python, `pip install bpy`):
  python3 tools/blender/make_d20.py [--preview arquivo.png]
ou dentro do Blender:
  blender -b -P tools/blender/make_d20.py -- [--preview arquivo.png]

Gera:
  game/assets/models/d20.glb       icosaedro chanfrado de resina com números dourados em relevo
  game/scripts/ui/d20_faces.gd     para cada número, a normal da face e o "para cima" do número
                                   (o jogo gira o dado até o número sorteado ficar de frente)

O dado é feito do zero aqui (licença do projeto). Os números usam a fonte
Silkscreen (OFL), que já está no projeto, convertida em malha.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT = os.path.join(ROOT, "game", "assets", "fonts", "Silkscreen-Regular.ttf")
OUT_GLB = os.path.join(ROOT, "game", "assets", "models", "d20.glb")
OUT_GD = os.path.join(ROOT, "game", "scripts", "ui", "d20_faces.gd")

RADIUS = 1.0          # raio da esfera que passa pelos vértices
BEVEL = 0.07          # chanfro das arestas (dado gasto, menos "geométrico")
NUM_RAISE = 0.012     # números em relevo sobre a face
NUM_W, NUM_H = 0.50, 0.31   # caixa máxima do número dentro da face

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None


def material(name, color, rough, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m


def to_gltf(v):  # Blender (Z para cima) -> glTF/Godot (Y para cima)
    return (round(v.x, 5), round(v.z, 5), round(-v.y, 5))


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- corpo: icosaedro (subdivisão 1 = 20 faces) --------------------------------------
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=RADIUS, location=(0, 0, 0))
die = bpy.context.active_object
die.name = "d20"
mesh = die.data
faces = []
for p in mesh.polygons:
    vs = [mesh.vertices[i].co.copy() for i in p.vertices]
    faces.append({"n": p.normal.copy(), "c": p.center.copy(), "v": vs})

# Opostos somam 21, como num d20 de verdade. As faces "de cima" (normal.z > 0, ou
# empate resolvido pelo ângulo) recebem 1..10 em espiral; a oposta recebe 21 - n.
order = sorted(range(20), key=lambda i: (-round(faces[i]["n"].z, 3), math.atan2(faces[i]["n"].y, faces[i]["n"].x)))
number = {}
k = 1
for i in order:
    if i in number:
        continue
    opp = min(range(20), key=lambda j: (faces[j]["n"] + faces[i]["n"]).length)
    # alterna altos e baixos em volta do dado (o 20 fica longe do 19, como nos dados reais)
    hi = 21 - k if k % 2 else k
    number[i] = hi
    number[opp] = 21 - hi
    k += 1

body = material("Resina", (0.32, 0.02, 0.04), 0.28)
gold = material("Ouro", (1.0, 0.60, 0.16), 0.3, 0.0, 0.15)
mesh.materials.append(body)

bev = die.modifiers.new("chanfro", "BEVEL")
bev.width = BEVEL
bev.segments = 1
bev.limit_method = "ANGLE"
bev.angle_limit = math.radians(30)

# --- números: texto da Silkscreen convertido em malha, deitado em cada face -----------
font = bpy.data.fonts.load(FONT)
num_objs = []
face_data = {}
for i, f in enumerate(faces):
    n = number[i]
    curve = bpy.data.curves.new(f"num_{n}", "FONT")
    curve.body = f"{n}." if n in (6, 9) else str(n)   # ponto tira a dúvida entre 6 e 9
    curve.font = font
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = NUM_RAISE
    curve.resolution_u = 1
    curve.fill_mode = "BOTH"
    ob = bpy.data.objects.new(f"num_{n}", curve)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.update()
    # escala para caber na face
    dims = ob.dimensions
    s = min(NUM_W / max(dims.x, 1e-6), NUM_H / max(dims.y, 1e-6))
    # base local: X = direita, Y = para cima (aponta para um vértice), Z = normal da face
    nz = f["n"].normalized()
    up = (f["v"][0] - f["c"])
    up = (up - nz * up.dot(nz)).normalized()
    right = up.cross(nz).normalized()
    basis = Matrix((right, up, nz)).transposed().to_4x4()
    pos = f["c"] + nz * (NUM_RAISE * 0.6)
    ob.matrix_world = Matrix.Translation(pos) @ basis @ Matrix.Scale(s, 4)
    face_data[n] = (to_gltf(nz), to_gltf(up))
    num_objs.append(ob)

bpy.ops.object.select_all(action="DESELECT")
for ob in num_objs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = num_objs[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
nums = bpy.context.active_object
nums.name = "numeros"
nums.data.materials.clear()
nums.data.materials.append(gold)

# aplica o chanfro e junta tudo num objeto só (o jogo gira um nó)
bpy.ops.object.select_all(action="DESELECT")
die.select_set(True)
bpy.context.view_layer.objects.active = die
bpy.ops.object.modifier_apply(modifier="chanfro")
nums.select_set(True)
bpy.ops.object.join()
for p in die.data.polygons:
    p.use_smooth = False

os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT")
tris = sum(len(p.vertices) - 2 for p in die.data.polygons)
print(f"d20: {tris} triângulos -> {OUT_GLB}")

with open(OUT_GD, "w", encoding="utf-8") as fh:
    fh.write("## Gerado por tools/blender/make_d20.py: não edite à mão.\n")
    fh.write("## Para cada número do d20: [normal da face, \"para cima\" do número], no espaço do modelo.\n\n")
    fh.write("const FACES := {\n")
    for n in sorted(face_data):
        nz, up = face_data[n]
        fh.write(f"\t{n}: [Vector3{nz}, Vector3{up}],\n")
    fh.write("}\n")
print("faces ->", OUT_GD)

if PREVIEW:  # foto de conferência (Workbench, sem GPU)
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.location = (0, -4.2, 1.6)
    cam.rotation_euler = (math.radians(70), 0, 0)
    cam.data.lens = 60
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("prévia ->", PREVIEW)

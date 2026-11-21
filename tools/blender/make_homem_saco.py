#!/usr/bin/env python3
"""Modela o Homem do Saco (versão de perto, para os sustos) no Blender.

Uso (Blender como módulo Python, `pip install bpy`):
  python3 tools/blender/make_homem_saco.py [--preview pasta]

Gera game/assets/models/homem_saco.glb:
  - homem alto (2 m) e esquálido, sobretudo escuro e comprido, mãos enormes
  - chapéu de palha de aba larga, rosto encovado e cinzento
  - olhos fundos com um brilho alaranjado (emissão), nariz comprido,
    sorriso largo demais com dentes tortos
  - o saco de estopa na mão esquerda, com volumes de alguma coisa lá dentro
  - esqueleto com osso "head" (o susto do jogo segue o osso da cabeça)
  - animações: Idle (balança, inclina a cabeça), Walk (arrastando o saco), Grab (estica o braço)

Feito do zero aqui (licença do projeto). Frente do modelo = -Y no Blender
(+Z no glTF/Godot), em pé.
"""
import math
import os
import random
import sys

import bpy  # antes do bmesh (o bmesh vem junto com o bpy)
import bmesh  # noqa: E402
import numpy as np
from mathutils import Euler, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models", "cinzento.glb")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
random.seed(11)
np.random.seed(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 24


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models", "homem_saco.glb")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
random.seed(31)
np.random.seed(31)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 24

# --- textura ------------------------------------------------------------------------------
TEX = 128
REG = {"pele": (0.0, 0.0, 0.5, 0.5), "cabeca": (0.5, 0.0, 1.0, 0.5),
       "casaco": (0.0, 0.5, 0.5, 1.0), "palha": (0.5, 0.5, 0.75, 1.0), "estopa": (0.75, 0.5, 1.0, 1.0)}


def noise(h, w, scale, octaves=3):
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        small = np.random.rand(h // s + 2, w // s + 2)
        out += np.kron(small, np.ones((s, s)))[:h, :w] * amp
        amp *= 0.5
    return out / out.max()


img = np.zeros((TEX, TEX, 3))


def fill(reg, base, var, spots=None, scale=8):
    u0, v0, u1, v1 = REG[reg]
    x0, x1, y0, y1 = int(u0 * TEX), int(u1 * TEX), int(v0 * TEX), int(v1 * TEX)
    h, w = y1 - y0, x1 - x0
    col = np.array(base)[None, None, :] + (noise(h, w, scale)[..., None] - 0.5) * np.array(var)[None, None, :]
    if spots:
        m = noise(h, w, scale * 2) > (1.0 - spots[1])
        col[m] = col[m] * 0.5 + np.array(spots[0]) * 0.5
    img[y0:y1, x0:x1] = np.clip(col, 0, 1)
    return x0, y0, w, h


fill("pele", (0.52, 0.48, 0.42), (0.12, 0.1, 0.1), spots=((0.36, 0.3, 0.26), 0.2))
fill("casaco", (0.2, 0.16, 0.13), (0.1, 0.08, 0.07), spots=((0.12, 0.08, 0.06), 0.25), scale=4)
fill("palha", (0.62, 0.52, 0.3), (0.2, 0.16, 0.08), spots=((0.4, 0.3, 0.16), 0.2), scale=2)
fill("estopa", (0.5, 0.4, 0.26), (0.18, 0.14, 0.08), spots=((0.3, 0.2, 0.1), 0.25), scale=2)
x0, y0, w, h = fill("cabeca", (0.55, 0.5, 0.44), (0.1, 0.08, 0.08), spots=((0.4, 0.34, 0.3), 0.18))
# rosto: órbitas fundas e escuras, sorriso largo de orelha a orelha com dentes tortos
yy, xx = np.mgrid[0:h, 0:w]
U, V = xx / w, yy / h
face = img[y0:y0 + h, x0:x0 + w]
for cx in (0.44, 0.56):
    d = ((U - cx) / 0.05) ** 2 + ((V - 0.6) / 0.06) ** 2
    face[d < 1.0] = face[d < 1.0] * 0.12
    face[(d >= 1.0) & (d < 2.0)] *= 0.6
grin = (np.abs(V - (0.3 + 0.9 * (U - 0.5) ** 2)) < 0.025) & (np.abs(U - 0.5) < 0.2)
face[grin] = (0.12, 0.03, 0.03)
teeth = grin & ((xx % 2) == 0) & (np.abs(V - (0.3 + 0.9 * (U - 0.5) ** 2)) < 0.012)
face[teeth] = (0.78, 0.72, 0.5)
for k in range(10):  # rugas e cicatrizes
    yk = 0.15 + 0.07 * k
    face[(np.abs(V - yk) < 0.004) & (noise(h, w, 2) > 0.7)] *= 0.7

image = bpy.data.images.new("homem_saco_tex", TEX, TEX, alpha=False)
image.pixels.foreach_set(np.concatenate([img, np.ones((TEX, TEX, 1))], axis=2).astype(np.float32).ravel())
image.pack()
mat = bpy.data.materials.new("HomemSaco")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tn = mat.node_tree.nodes.new("ShaderNodeTexImage")
tn.image = image
tn.interpolation = "Closest"
mat.node_tree.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9
eye_mat = bpy.data.materials.new("OlhosBrasa")
eye_mat.use_nodes = True
eb = eye_mat.node_tree.nodes["Principled BSDF"]
eb.inputs["Base Color"].default_value = (1.0, 0.55, 0.15, 1)
eb.inputs["Emission Color"].default_value = (1.0, 0.45, 0.1, 1)
eb.inputs["Emission Strength"].default_value = 2.5
dark_mat = bpy.data.materials.new("Sombra")
dark_mat.use_nodes = True
dm = dark_mat.node_tree.nodes["Principled BSDF"]
dm.inputs["Base Color"].default_value = (0.02, 0.015, 0.01, 1)
dm.inputs["Roughness"].default_value = 1.0

# --- malha ---------------------------------------------------------------------------------
parts = []  # (bmesh, osso, região, mapeamento, material)


def cylinder(a, b, r0, r1, seg=6, rings=1):
    bm = bmesh.new()
    a, b = Vector(a), Vector(b)
    axis = b - a
    z = axis.normalized()
    x = z.orthogonal().normalized()
    y = z.cross(x)
    rows = []
    for i in range(rings + 1):
        t = i / rings
        c = a + axis * t
        r = r0 + (r1 - r0) * t
        rows.append([bm.verts.new(c + (x * math.cos(k / seg * math.tau) + y * math.sin(k / seg * math.tau)) * r) for k in range(seg)])
    for i in range(rings):
        for k in range(seg):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % seg], rows[i + 1][(k + 1) % seg], rows[i + 1][k]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    return bm


def blob(center, size, subdiv=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
    return bm


def add(bm, bone, region="pele", mapping="cil", mat_i=0):
    parts.append((bm, bone, region, mapping, mat_i))


# cabeça comprida e encovada, nariz comprido, orelhas
HEAD_C = Vector((0, 0, 1.78))
head = blob(HEAD_C, (0.1, 0.11, 0.135), subdiv=2)
for v in head.verts:
    t = (v.co.z - (HEAD_C.z - 0.135)) / 0.27
    v.co.x *= 0.78 + 0.22 * min(1.0, t * 1.6)  # queixo fino, maçãs saltadas
    if v.co.y < HEAD_C.y - 0.07 and abs(v.co.z - (HEAD_C.z + 0.02)) < 0.04:
        v.co.y -= 0.012  # testa e sobrancelha pesadas
add(head, "head", "cabeca", "cabeca")
add(cylinder((0, -0.1, 1.8), (0, -0.155, 1.74), 0.016, 0.01, seg=5), "head", "pele")  # nariz
for s in (1, -1):
    add(blob((0.1 * s, 0.0, 1.79), (0.015, 0.03, 0.04)), "head", "pele")  # orelhas
    add(blob((0.036 * s, -0.093, 1.81), (0.012, 0.006, 0.01)), "head", mapping="olho", mat_i=1)  # brasa no fundo da órbita
# chapéu de palha de aba larga (sombra no rosto)
brim = cylinder((0, 0.0, 1.885), (0, 0.0, 1.9), 0.3, 0.3, seg=12)
for v in brim.verts:  # aba caída, desfiada
    v.co.z -= 0.02 * (math.hypot(v.co.x, v.co.y) / 0.3) + random.uniform(-0.008, 0.008)
add(brim, "head", "palha")
add(cylinder((0, 0.0, 1.89), (0, 0.0, 2.02), 0.12, 0.1, seg=10), "head", "palha")
add(cylinder((0, 0.0, 1.9), (0, 0.0, 1.93), 0.123, 0.123, seg=10), "head", mapping="olho", mat_i=2)  # fita escura
add(cylinder((0, 0.01, 1.58), (0, 0.0, 1.68), 0.04, 0.035, seg=6), "neck", "pele")
# sobretudo comprido até a canela, ombros ossudos
coat = cylinder((0, 0.0, 0.5), (0, 0.0, 1.6), 0.24, 0.17, seg=9, rings=4)
for v in coat.verts:
    v.co.y *= 0.72
    v.co.x += random.uniform(-0.01, 0.01)
add(coat, "spine", "casaco")
for s in (1, -1):
    add(blob((0.19 * s, 0.0, 1.55), (0.06, 0.06, 0.05)), "spine", "casaco")
add(blob((0, 0.0, 0.92), (0.16, 0.12, 0.1)), "root", "casaco")
# pernas finas saindo do casaco, botinas
for s, side in ((1, "L"), (-1, "R")):
    hip, knee, ankle = Vector((0.08 * s, 0, 0.92)), Vector((0.09 * s, -0.01, 0.5)), Vector((0.09 * s, 0.01, 0.07))
    add(cylinder(hip, knee, 0.05, 0.04, seg=6, rings=2), "thigh." + side, "casaco")
    add(cylinder(knee, ankle, 0.04, 0.03, seg=6, rings=2), "shin." + side, "casaco")
    add(blob(ankle + Vector((0, -0.05, -0.035)), (0.045, 0.1, 0.035)), "shin." + side, mapping="olho", mat_i=2)
    # braços compridos (as mãos passam dos joelhos) e mãos enormes de dedos longos
    sh, el, wr = Vector((0.2 * s, 0, 1.54)), Vector((0.25 * s, 0.0, 1.12)), Vector((0.27 * s, -0.03, 0.72))
    add(cylinder(sh, el, 0.05, 0.042, seg=6, rings=2), "upper_arm." + side, "casaco")
    add(cylinder(el, wr, 0.042, 0.032, seg=6, rings=2), "forearm." + side, "casaco")
    add(blob(wr + Vector((0, 0, -0.05)), (0.045, 0.025, 0.06)), "hand." + side, "pele")
    for f in range(4):
        base = wr + Vector(((f - 1.5) * 0.02 * s, -0.01, -0.1))
        add(cylinder(base, base + Vector(((f - 1.5) * 0.008 * s, -0.02, -0.13)), 0.01, 0.006, seg=4, rings=2), "hand." + side, "pele")
# o saco de estopa na mão esquerda, com volumes de alguma coisa lá dentro
sack = blob((0.33, 0.02, 0.36), (0.2, 0.17, 0.3), subdiv=2)
for v in sack.verts:
    v.co += Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * 0.015
    if v.co.z > 0.58:
        v.co.x = 0.33 + (v.co.x - 0.33) * 0.35  # boca do saco amarrada
        v.co.y = 0.02 + (v.co.y - 0.02) * 0.35
add(sack, "hand.L", "estopa")
for c, r in (((0.38, -0.12, 0.42), 0.07), ((0.26, -0.1, 0.3), 0.06)):  # volumes (um joelho? uma mão?)
    add(blob(c, (r, r * 0.8, r)), "hand.L", "estopa")
add(cylinder((0.3, 0.02, 0.6), (0.29, 0.0, 0.72), 0.02, 0.012, seg=5), "hand.L", "estopa")  # boca amarrada

mesh = bpy.data.meshes.new("homem_saco")
obj = bpy.data.objects.new("homem_saco", mesh)
bpy.context.collection.objects.link(obj)
for m in (mat, eye_mat, dark_mat):
    obj.data.materials.append(m)
big = bmesh.new()
uv_layer = big.loops.layers.uv.new("UVMap")
deform = big.verts.layers.deform.verify()
bone_names = ["root", "spine", "neck", "head"] + [f"{b}.{s}" for s in "LR" for b in ("upper_arm", "forearm", "hand", "thigh", "shin")]
for name in bone_names:
    obj.vertex_groups.new(name=name)
for bm, bone, region, mapping, mat_i in parts:
    vmap = {}
    for v in bm.verts:
        nv = big.verts.new(v.co)
        nv[deform][bone_names.index(bone)] = 1.0
        vmap[v] = nv
    zs = [v.co.z for v in bm.verts]
    zmin, zmax = min(zs), max(zs) + 1e-6
    c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    for f in bm.faces:
        try:
            nf = big.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        nf.material_index = mat_i
        if mapping == "olho":
            continue
        u0, v0, u1, v1 = REG[region]
        for loop, ov in zip(nf.loops, f.verts):
            p = ov.co - c
            uu = math.atan2(p.x, -p.y) / math.tau + 0.5
            vv = (ov.co.z - zmin) / (zmax - zmin)
            loop[uv_layer].uv = (u0 + (u1 - u0) * (0.04 + 0.92 * uu), v0 + (v1 - v0) * (0.04 + 0.92 * vv))
    bm.free()
big.normal_update()
big.to_mesh(mesh)
big.free()
for p in mesh.polygons:
    p.use_smooth = False

# --- esqueleto -------------------------------------------------------------------------------
arm_data = bpy.data.armatures.new("esqueleto")
arm = bpy.data.objects.new("HomemSaco", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
BONES = {
    "root": ((0, 0, 0.88), (0, 0, 1.05), None),
    "spine": ((0, 0, 1.05), (0, 0, 1.58), "root"),
    "neck": ((0, 0, 1.58), (0, 0, 1.68), "spine"),
    "head": ((0, 0, 1.68), (0, 0, 2.0), "neck"),
}
for s, side in ((1, "L"), (-1, "R")):
    BONES["upper_arm." + side] = ((0.2 * s, 0, 1.54), (0.25 * s, 0.0, 1.12), "spine")
    BONES["forearm." + side] = ((0.25 * s, 0.0, 1.12), (0.27 * s, -0.03, 0.72), "upper_arm." + side)
    BONES["hand." + side] = ((0.27 * s, -0.03, 0.72), (0.27 * s, -0.05, 0.5), "forearm." + side)
    BONES["thigh." + side] = ((0.08 * s, 0, 0.92), (0.09 * s, -0.01, 0.5), "root")
    BONES["shin." + side] = ((0.09 * s, -0.01, 0.5), (0.09 * s, 0.01, 0.07), "thigh." + side)
for name, (hd, tl, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = hd, tl
    b.roll = 0.0
    if parent:
        b.parent = arm_data.edit_bones[parent]
        b.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
obj.parent = arm
obj.modifiers.new("esqueleto", "ARMATURE").object = arm

# --- animações -----------------------------------------------------------------------------
arm.animation_data_create()
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = "XYZ"


def anim(name, keys):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for frame, rots, locs in keys:
        for b in pb:
            b.rotation_euler = Euler([math.radians(a) for a in rots.get(b.name, (0, 0, 0))], "XYZ")
            b.keyframe_insert("rotation_euler", frame=frame)
            b.location = locs.get(b.name, (0, 0, 0))
            b.keyframe_insert("location", frame=frame)
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 0, act)
    tr.mute = True
    arm.animation_data.action = None


def aim(name, target):
    """Rotação local (graus) que faz o osso apontar para `target` (direção no espaço do esqueleto)."""
    rest = arm_data.bones[name].matrix_local.to_3x3()
    cur = (rest @ Vector((0, 1, 0))).normalized()
    q = cur.rotation_difference(Vector(target).normalized())
    return tuple(math.degrees(x) for x in (rest.inverted() @ q.to_matrix() @ rest).to_euler("XYZ"))



anim("Idle", [
    (0, {"head": (0, 0, 0), "spine": (4, 0, 0)}, {}),
    (24, {"head": (-8, 14, 6), "neck": (0, 5, 0), "spine": (6, 3, 0)}, {}),   # inclina a cabeça, curioso
    (30, {"head": (-10, 16, 6), "neck": (0, 5, 0), "spine": (6, 3, 0), "hand.R": (-15, 0, 0)}, {}),
    (48, {"head": (4, -10, -4), "neck": (0, -3, 0), "spine": (3, -2, 0)}, {}),
    (72, {"head": (0, 0, 0), "spine": (4, 0, 0)}, {}),
])


def walk(phase):
    a = math.sin(phase * math.tau)
    return ({"thigh.L": (-16 * a, 0, 0), "shin.L": (max(0, 20 * a), 0, 0), "thigh.R": (16 * a, 0, 0), "shin.R": (max(0, -20 * a), 0, 0),
             "upper_arm.R": (-12 * a, 0, 0), "upper_arm.L": (4 * a, 0, 0), "spine": (6, 0, 3 * a), "head": (0, 0, -4 * a)},
            {"root": (0, 0, 0.015 * abs(math.cos(phase * math.tau)))})


anim("Walk", [(f, *walk(f / 40)) for f in range(0, 41, 5)])
grab = {"upper_arm.R": aim("upper_arm.R", (-0.06, -0.3, 0.06)), "forearm.R": (0, 0, 0), "hand.R": (-15, 0, 0),
        "spine": (14, 0, 0), "head": (-10, 0, 0), "neck": (-6, 0, 0)}
grab2 = {k: (v[0] - 4, v[1] + 3, v[2] + 3) for k, v in grab.items()}
anim("Grab", [(0, grab, {}), (4, grab2, {}), (8, grab, {}), (12, grab2, {}), (16, grab, {})])

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True)
print(f"homem_saco: {sum(len(p.vertices) - 2 for p in mesh.polygons)} triângulos, {len(parts)} partes -> {OUT}")

if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    for loc, e in (((1.0, -2.0, 1.8), 220), ((-1.2, -1.0, 0.6), 60)):
        L = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT"))
        L.data.energy = e
        L.location = loc
        sc.collection.objects.link(L)
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 12
    sc.render.resolution_x, sc.render.resolution_y = 240, 320
    views = {"corpo": ((0, -4.2, 1.1), (88, 0, 0), 50), "rosto": ((0, -0.95, 1.78), (90, 0, 0), 50), "lado": ((4.2, 0, 1.1), (88, 0, 90), 50)}
    for name, frame in (("Idle", 20), ("Walk", 8), ("Grab", 4)):
        for t in arm.animation_data.nla_tracks:
            t.mute = t.name != name
        sc.frame_set(frame)
        for vname, (loc, rot, lens) in views.items():
            cam.location = loc
            cam.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
            cam.data.lens = lens
            sc.render.filepath = os.path.join(PREVIEW, f"{name}_{vname}.png")
            bpy.ops.render.render(write_still=True)

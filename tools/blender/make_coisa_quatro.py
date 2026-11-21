#!/usr/bin/env python3
"""Modela a coisa de quatro (a skinwalker andando de quatro) no Blender.

Uso (Blender como módulo Python, `pip install bpy`):
  python3 tools/blender/make_coisa_quatro.py [--preview pasta]

Gera game/assets/models/coisa_quatro.glb:
  - corpo comprido e esquelético, cinza-morto, com costelas e espinha saltadas
  - a pele do Caramelo jogada por cima das costas e da cabeça (pelo caramelo)
  - cabeça canina com focinho, orelhas e olhos pálidos que brilham
  - patas da frente compridas demais, traseiras dobradas ao contrário, garras
  - esqueleto com osso "head" (o susto do jogo segue o osso da cabeça)
  - animações: Idle (fareja e torce a cabeça), Crawl (anda de quatro), Rise (empina com os braços abertos)

Feito do zero aqui (licença do projeto). Frente do modelo = -Y no Blender
(+Z no glTF/Godot).
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
OUT = os.path.join(ROOT, "game", "assets", "models", "coisa_quatro.glb")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
random.seed(23)
np.random.seed(23)
FPS = 24

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS

# --- textura (atlas 128x128) ----------------------------------------------------------
TEX = 128
REG = {  # região do atlas: (u0, v0, u1, v1)
    "pele": (0.0, 0.0, 0.5, 0.5),     # pele cinza esticada (patas)
    "cabeca": (0.5, 0.0, 1.0, 0.5),   # pelo caramelo da cabeça, com focinho escuro
    "sangue": (0.0, 0.5, 0.5, 0.75),
    "osso": (0.5, 0.5, 0.75, 0.75),
    "boca": (0.75, 0.5, 1.0, 0.75),
    "braco": (0.0, 0.75, 0.5, 1.0),   # pelo caramelo das costas (a pele roubada)
    "garra": (0.5, 0.75, 1.0, 1.0),
}


def noise(h, w, scale, octaves=3):
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        small = np.random.rand(h // s + 2, w // s + 2)
        big = np.kron(small, np.ones((s, s)))[:h, :w]
        out += big * amp
        amp *= 0.5
    return out / out.max()


img = np.zeros((TEX, TEX, 3))


def fill(reg, base, var, spots=None, scale=8):
    u0, v0, u1, v1 = REG[reg]
    x0, x1, y0, y1 = int(u0 * TEX), int(u1 * TEX), int(v0 * TEX), int(v1 * TEX)
    h, w = y1 - y0, x1 - x0
    n = noise(h, w, scale)
    col = np.array(base)[None, None, :] + (n[..., None] - 0.5) * np.array(var)[None, None, :]
    if spots:
        sc, amount = spots
        m = noise(h, w, scale * 2) > (1.0 - amount)
        col[m] = col[m] * 0.4 + np.array(sc) * 0.6
    img[y0:y1, x0:x1] = np.clip(col, 0, 1)
    return x0, y0, w, h


# pele roubada: pelo caramelo com falhas e sangue seco; por baixo, pele cinza esticada
fill("pele", (0.46, 0.44, 0.4), (0.14, 0.14, 0.12), spots=((0.3, 0.12, 0.1), 0.15))
fill("braco", (0.62, 0.4, 0.2), (0.25, 0.16, 0.08), spots=((0.28, 0.08, 0.05), 0.25), scale=4)
fill("sangue", (0.38, 0.03, 0.03), (0.25, 0.05, 0.05), spots=((0.12, 0.0, 0.0), 0.3), scale=4)
fill("osso", (0.82, 0.78, 0.66), (0.15, 0.15, 0.12), spots=((0.5, 0.1, 0.08), 0.15), scale=4)
fill("boca", (0.16, 0.02, 0.02), (0.1, 0.02, 0.02), scale=4)
fill("garra", (0.15, 0.12, 0.1), (0.08, 0.06, 0.05), scale=4)
x0, y0, w, h = fill("cabeca", (0.64, 0.42, 0.21), (0.22, 0.14, 0.07), spots=((0.3, 0.1, 0.06), 0.18), scale=4)
yy, xx = np.mgrid[0:h, 0:w]
U, V = xx / w, yy / h
face = img[y0:y0 + h, x0:x0 + w]
snout = np.abs(U - 0.5) < 0.12
face[snout & (V < 0.45)] *= 0.55  # focinho escuro, sujo de terra
face[(np.abs(U - 0.5) < 0.05) & (np.abs(V - 0.42) < 0.04)] = (0.05, 0.03, 0.03)  # trufa

image = bpy.data.images.new("coisa_quatro_tex", TEX, TEX, alpha=False)
rgba = np.concatenate([img, np.ones((TEX, TEX, 1))], axis=2)
image.pixels.foreach_set(rgba.astype(np.float32).ravel())
image.pack()

mat = bpy.data.materials.new("CoisaQuatro")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
texnode = nt.nodes.new("ShaderNodeTexImage")
texnode.image = image
texnode.interpolation = "Closest"
nt.links.new(texnode.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9

eye_mat = bpy.data.materials.new("Olhos")
eye_mat.use_nodes = True
eb = eye_mat.node_tree.nodes["Principled BSDF"]
eb.inputs["Base Color"].default_value = (1.0, 0.95, 0.72, 1)
eb.inputs["Emission Color"].default_value = (1.0, 0.94, 0.7, 1)
eb.inputs["Emission Strength"].default_value = 2.0

# --- malha ---
parts = []  # (bmesh, bone, region, mapping)


def add_part(bm, bone, region, mapping="cil", jitter=0.0):
    if jitter:
        for v in bm.verts:
            v.co += Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * jitter
    parts.append((bm, bone, region, mapping))


def cylinder(a, b, r0, r1, seg=6, rings=1):
    """Tubo de a até b, raio r0 -> r1."""
    bm = bmesh.new()
    a, b = Vector(a), Vector(b)
    axis = (b - a)
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


def box(center, size):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
    return bm


S = 1.0
# tronco comprido, quadril mais alto que o peito (anda de quatro, curvado)
torso = cylinder((0, 0.46, 0.74), (0, -0.36, 0.8), 0.11, 0.14, seg=7, rings=4)
for v in torso.verts:
    v.co.x *= 1.05
add_part(torso, "spine", "braco", jitter=0.01)
add_part(blob((0, 0.5, 0.72), (0.12, 0.1, 0.1)), "root", "braco", jitter=0.012)
for i in range(7):  # espinha saltada
    yv = 0.38 - i * 0.11
    add_part(blob((0, yv, 0.89 + 0.012 * math.sin(i)), (0.025, 0.03, 0.03)), "spine", "osso")
for i in range(4):  # costelas
    for sx in (1, -1):
        add_part(box((sx * 0.135, 0.05 - i * 0.09, 0.73), (0.02, 0.016, 0.1)), "spine", "osso")
for sx, ln in ((0.04, 0.35), (-0.05, 0.28)):  # pele solta pendurada da barriga
    add_part(cylinder((sx, 0.2 - ln * 0.4, 0.66), (sx * 1.6, 0.1 - ln * 0.4, 0.46), 0.03, 0.012, seg=5, rings=2), "spine", "braco", jitter=0.01)
# pescoço comprido e cabeça de cachorro
add_part(cylinder((0, -0.34, 0.84), (0, -0.6, 0.9), 0.06, 0.045, seg=6), "neck", "braco", jitter=0.006)
skull = blob((0, -0.68, 0.92), (0.085, 0.1, 0.085), subdiv=2)
add_part(skull, "head", "cabeca", mapping="cabeca", jitter=0.004)
add_part(cylinder((0, -0.74, 0.9), (0, -0.96, 0.85), 0.05, 0.03, seg=6, rings=2), "head", "cabeca", mapping="cabeca")
add_part(blob((0, -0.88, 0.83), (0.035, 0.08, 0.018)), "jaw", "boca")
for k in range(5):  # dentes
    add_part(box(((k - 2) * 0.012, -0.93 + abs(k - 2) * 0.02, 0.85), (0.008, 0.008, 0.022)), "jaw", "osso")
for s in (1, -1):  # orelhas (uma rasgada)
    tip_h = 0.12 if s > 0 else 0.07
    add_part(cylinder((0.05 * s, -0.64, 0.98), (0.075 * s, -0.62, 0.98 + tip_h), 0.03, 0.004, seg=4), "head", "cabeca")
for sx in (0.04, -0.04):  # olhos pálidos que brilham
    parts.append((blob((sx, -0.765, 0.945), (0.016, 0.01, 0.013), subdiv=1), "head", "olho", "olho"))
# patas: da frente compridas demais; de trás dobradas ao contrário
for s, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.14 * s, -0.34, 0.76)), Vector((0.19 * s, -0.4, 0.4)), Vector((0.17 * s, -0.5, 0.05))
    add_part(cylinder(sh, el, 0.045, 0.034, seg=6, rings=2), "upper_arm." + side, "pele", jitter=0.005)
    add_part(cylinder(el, wr, 0.034, 0.026, seg=6, rings=2), "forearm." + side, "pele", jitter=0.005)
    add_part(box(wr + Vector((0, -0.05, -0.02)), (0.06, 0.08, 0.02)), "hand." + side, "pele")
    for f in range(4):
        base = Vector((wr.x + (f - 1.5) * 0.018 * s, wr.y - 0.09, 0.02))
        add_part(cylinder(base, base + Vector(((f - 1.5) * 0.01 * s, -0.08, -0.015)), 0.009, 0.003, seg=4), "hand." + side, "garra")
    hp, kn, an, ft = Vector((0.12 * s, 0.46, 0.7)), Vector((0.16 * s, 0.26, 0.42)), Vector((0.15 * s, 0.56, 0.18)), Vector((0.15 * s, 0.46, 0.03))
    add_part(cylinder(hp, kn, 0.05, 0.035, seg=6, rings=2), "thigh." + side, "braco", jitter=0.006)
    add_part(cylinder(kn, an, 0.035, 0.024, seg=6, rings=2), "shin." + side, "pele", jitter=0.005)
    add_part(cylinder(an, ft, 0.024, 0.02, seg=5, rings=1), "foot." + side, "pele")
    for f in range(3):
        base = ft + Vector(((f - 1) * 0.016 * s, -0.02, -0.01))
        add_part(cylinder(base, base + Vector((0, -0.06, -0.012)), 0.008, 0.003, seg=4), "foot." + side, "garra")

# junta tudo num objeto, com UV por parte e grupos de vértices por osso
mesh = bpy.data.meshes.new("coisa_quatro")
obj = bpy.data.objects.new("coisa_quatro", mesh)
bpy.context.collection.objects.link(obj)
obj.data.materials.append(mat)
obj.data.materials.append(eye_mat)
big = bmesh.new()
uv_layer = big.loops.layers.uv.new("UVMap")
deform = big.verts.layers.deform.verify()
bone_names = ["root", "spine", "neck", "head", "jaw"] + [f"{b}.{s}" for s in "LR" for b in ("upper_arm", "forearm", "hand", "thigh", "shin", "foot")]
for name in bone_names:
    obj.vertex_groups.new(name=name)
for bm, bone, region, mapping in parts:
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
        nf.material_index = 1 if mapping == "olho" else 0
        if mapping == "olho":
            continue
        u0, v0, u1, v1 = REG[region]
        for loop, ov in zip(nf.loops, f.verts):
            p = ov.co - c
            if mapping == "cabeca":
                uu = (math.atan2(p.x, -p.y) / math.tau + 0.5)
                vv = (ov.co.z - zmin) / (zmax - zmin)
            else:
                uu = (math.atan2(p.x, p.z) / math.tau + 0.5)
                vv = (ov.co.y - min(v.co.y for v in bm.verts)) / (max(v.co.y for v in bm.verts) - min(v.co.y for v in bm.verts) + 1e-6)
            loop[uv_layer].uv = (u0 + (u1 - u0) * (0.04 + 0.92 * uu), v0 + (v1 - v0) * (0.04 + 0.92 * vv))
    bm.free()
big.normal_update()
big.to_mesh(mesh)
big.free()
for p in mesh.polygons:
    p.use_smooth = False

# --- esqueleto -----------------------------------------------------------------------
arm_data = bpy.data.armatures.new("esqueleto")
arm = bpy.data.objects.new("CoisaQuatro", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
BONES = {
    "root": ((0, 0.5, 0.72), (0, 0.3, 0.75), None),
    "spine": ((0, 0.3, 0.75), (0, -0.34, 0.8), "root"),
    "neck": ((0, -0.34, 0.82), (0, -0.6, 0.9), "spine"),
    "head": ((0, -0.6, 0.9), (0, -0.82, 0.92), "neck"),
    "jaw": ((0, -0.76, 0.86), (0, -0.94, 0.83), "head"),
}
for s, side in ((1, "L"), (-1, "R")):
    BONES["upper_arm." + side] = ((0.14 * s, -0.34, 0.76), (0.19 * s, -0.4, 0.4), "spine")
    BONES["forearm." + side] = ((0.19 * s, -0.4, 0.4), (0.17 * s, -0.5, 0.05), "upper_arm." + side)
    BONES["hand." + side] = ((0.17 * s, -0.5, 0.05), (0.17 * s, -0.62, 0.02), "forearm." + side)
    BONES["thigh." + side] = ((0.12 * s, 0.46, 0.7), (0.16 * s, 0.26, 0.42), "root")
    BONES["shin." + side] = ((0.16 * s, 0.26, 0.42), (0.15 * s, 0.56, 0.18), "thigh." + side)
    BONES["foot." + side] = ((0.15 * s, 0.56, 0.18), (0.15 * s, 0.46, 0.03), "shin." + side)
for name, (h, t, parent) in BONES.items():
    eb_ = arm_data.edit_bones.new(name)
    eb_.head, eb_.tail = h, t
    eb_.roll = 0.0
    if parent:
        eb_.parent = arm_data.edit_bones[parent]
        eb_.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
obj.parent = arm
mod = obj.modifiers.new("esqueleto", "ARMATURE")
mod.object = arm

# --- animações ---------------------------------------------------------------------
arm.animation_data_create()
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = "XYZ"


def anim(name, length, keys):
    """keys: lista de (frame, {osso: (rx, ry, rz) em graus}, {osso: (x, y, z) local})."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for frame, rots, locs in keys:
        for b in pb:
            r = rots.get(b.name, (0, 0, 0))
            b.rotation_euler = Euler([math.radians(a) for a in r], "XYZ")
            b.keyframe_insert("rotation_euler", frame=frame)
            b.location = locs.get(b.name, (0, 0, 0))
            b.keyframe_insert("location", frame=frame)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    track.mute = True
    arm.animation_data.action = None
    return act


def crawl_pose(phase):
    """Andar de quatro: pata da frente esquerda junto com a de trás direita."""
    a = math.sin(phase * math.tau)
    return ({
        "upper_arm.L": (-24 * a, 0, 0), "forearm.L": (18 * max(a, 0), 0, 0),
        "upper_arm.R": (24 * a, 0, 0), "forearm.R": (18 * max(-a, 0), 0, 0),
        "thigh.L": (22 * a, 0, 0), "shin.L": (-14 * max(-a, 0), 0, 0),
        "thigh.R": (-22 * a, 0, 0), "shin.R": (-14 * max(a, 0), 0, 0),
        "spine": (0, 6 * a, 0), "neck": (4 * abs(a), 0, 8 * a), "head": (-6 * abs(a), 0, -10 * a), "jaw": (8, 0, 0),
    }, {"root": (0, 0.02 * abs(math.cos(phase * math.tau)), 0)})


anim("Crawl", 24, [(f, *crawl_pose(f / 24)) for f in range(0, 25, 3)])
anim("Idle", 48, [
    (0, {"head": (0, 0, 0), "neck": (0, 0, 0), "jaw": (4, 0, 0)}, {}),
    (12, {"head": (-12, 0, 24), "neck": (6, 0, 10), "jaw": (10, 0, 0)}, {}),   # fareja
    (15, {"head": (8, 30, -18), "neck": (-4, 0, -8), "jaw": (2, 0, 0)}, {}),   # torce a cabeça de repente
    (30, {"head": (6, 34, -14), "neck": (-2, 0, -6), "jaw": (18, 0, 0)}, {}),
    (40, {"head": (-4, -8, 6), "neck": (2, 0, 2), "jaw": (6, 0, 0)}, {}),
    (48, {"head": (0, 0, 0), "neck": (0, 0, 0), "jaw": (4, 0, 0)}, {}),
])
rise = {"root": (-42, 0, 0), "spine": (-10, 0, 0), "neck": (24, 0, 0), "head": (16, 0, 0), "jaw": (36, 0, 0),
        "upper_arm.L": (-55, 0, 0), "upper_arm.R": (-55, 0, 0), "forearm.L": (-15, 0, 0), "forearm.R": (-15, 0, 0),
        "thigh.L": (40, 0, 0), "thigh.R": (40, 0, 0)}
shake = {k: (v[0] + 5, v[1] + 4, v[2] - 4) for k, v in rise.items()}
anim("Rise", 12, [(0, rise, {}), (3, shake, {}), (6, rise, {}), (9, shake, {}), (12, rise, {})])

# --- exportar ---------------------------------------------------------------------------
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=False,
                          export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_skins=True, export_materials="EXPORT", export_image_format="AUTO")
tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
print(f"coisa_quatro: {tris} triângulos, {len(parts)} partes -> {OUT}")

if PREVIEW:  # fotos de conferência (Cycles CPU): cada animação de frente e de lado
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    for loc, e in (((1.5, -2.0, 2.0), 300), ((-1.5, -1.0, 1.0), 120)):
        L = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT"))
        L.data.energy = e
        L.location = loc
        sc.collection.objects.link(L)
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 12
    sc.render.resolution_x, sc.render.resolution_y = 320, 240
    views = {"frente": ((0, -3.2, 1.0), (84, 0, 0)), "lado": ((3.4, 0.0, 1.0), (84, 0, 90))}
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    for name, frame in (("Idle", 15), ("Crawl", 6), ("Crawl", 18), ("Rise", 3)):
        for t in arm.animation_data.nla_tracks:
            t.mute = t.name != name
        sc.frame_set(frame)
        for vname, (loc, rot) in views.items():
            cam.location = loc
            cam.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
            sc.render.filepath = os.path.join(PREVIEW, f"{name}_{frame}_{vname}.png")
            bpy.ops.render.render(write_still=True)
    print("prévias ->", PREVIEW)

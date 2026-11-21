#!/usr/bin/env python3
"""Modela o Rastejante (zumbi sem pernas que se arrasta pelos braços) no Blender.

Uso (Blender como módulo Python, `pip install bpy`):
  python3 tools/blender/make_rastejante.py [--preview pasta]

Gera game/assets/models/rastejante.glb:
  - malha low-poly no estilo PSX (tronco, toco rasgado com tripas, costelas
    expostas, cabeça com mandíbula solta, braços compridos com garras)
  - textura procedural 128x128 (pele morta esverdeada, hematomas, sangue, osso)
  - olhos com emissão (brilham no escuro)
  - esqueleto com ossos "head" e "jaw" (o susto do jogo segue o osso da cabeça)
  - animações: Idle (se contorcendo), Crawl (se arrastando), Attack (bote)

Feito do zero aqui (licença do projeto). Frente do modelo = -Y no Blender
(+Z no glTF/Godot), deitado de bruços.
"""
import math
import os
import random
import sys

import bpy  # antes do bmesh (o bmesh vem junto com o bpy)
import bmesh  # noqa: E402
import numpy as np
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models", "rastejante.glb")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
random.seed(7)
np.random.seed(7)
FPS = 24

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS

# --- textura (atlas 128x128) ----------------------------------------------------------
TEX = 128
REG = {  # região do atlas: (u0, v0, u1, v1)
    "pele": (0.0, 0.0, 0.5, 0.5),
    "cabeca": (0.5, 0.0, 1.0, 0.5),
    "sangue": (0.0, 0.5, 0.5, 0.75),
    "osso": (0.5, 0.5, 0.75, 0.75),
    "boca": (0.75, 0.5, 1.0, 0.75),
    "braco": (0.0, 0.75, 0.5, 1.0),
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


# pele morta: cinza-esverdeada, hematomas roxos e sangue seco
fill("pele", (0.42, 0.47, 0.36), (0.18, 0.18, 0.14), spots=((0.28, 0.12, 0.2), 0.18))
fill("braco", (0.40, 0.44, 0.34), (0.2, 0.2, 0.16), spots=((0.35, 0.05, 0.04), 0.22))
fill("sangue", (0.38, 0.03, 0.03), (0.25, 0.05, 0.05), spots=((0.12, 0.0, 0.0), 0.3), scale=4)
fill("osso", (0.82, 0.78, 0.66), (0.15, 0.15, 0.12), spots=((0.5, 0.1, 0.08), 0.15), scale=4)
fill("boca", (0.16, 0.02, 0.02), (0.1, 0.02, 0.02), scale=4)
fill("garra", (0.22, 0.18, 0.12), (0.1, 0.08, 0.05), scale=4)
x0, y0, w, h = fill("cabeca", (0.45, 0.49, 0.38), (0.15, 0.15, 0.12), spots=((0.3, 0.1, 0.12), 0.12))
# rosto pintado na frente da cabeça (u = 0.5 da região = frente): órbitas fundas,
# nariz carcomido e boca rasgada até as bochechas
yy, xx = np.mgrid[0:h, 0:w]
U, V = xx / w, yy / h
face = img[y0:y0 + h, x0:x0 + w]
for cx in (0.44, 0.56):  # órbitas
    d = ((U - cx) / 0.045) ** 2 + ((V - 0.62) / 0.07) ** 2
    face[d < 1.0] = face[d < 1.0] * 0.15
    face[(d >= 1.0) & (d < 1.8)] *= 0.55
d = ((U - 0.5) / 0.025) ** 2 + ((V - 0.48) / 0.04) ** 2  # nariz
face[d < 1.0] = (0.08, 0.02, 0.02)
mouth = (np.abs(V - 0.36) < 0.035 + 0.02 * np.abs(U - 0.5) * 8) & (np.abs(U - 0.5) < 0.12)
face[mouth] = (0.25, 0.02, 0.02)
teeth = mouth & (np.abs(V - 0.36) < 0.012) & ((xx % 3) == 0)
face[teeth] = (0.85, 0.8, 0.6)
blood = (V < 0.36) & (np.abs(U - 0.5) < 0.1) & (noise(h, w, 2) > 0.55)
face[blood] = face[blood] * 0.3 + np.array((0.4, 0.0, 0.0)) * 0.7

image = bpy.data.images.new("rastejante_tex", TEX, TEX, alpha=False)
rgba = np.concatenate([img, np.ones((TEX, TEX, 1))], axis=2)
image.pixels.foreach_set(rgba.astype(np.float32).ravel())
image.pack()

mat = bpy.data.materials.new("Rastejante")
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
eb.inputs["Base Color"].default_value = (1.0, 0.9, 0.55, 1)
eb.inputs["Emission Color"].default_value = (1.0, 0.85, 0.4, 1)
eb.inputs["Emission Strength"].default_value = 2.0

# --- malha: cada parte é presa a um osso (pele rígida, bem PSX) ------------------------
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


# tronco: peito erguido nos braços, afinando até o toco
torso = cylinder((0, 0.42, 0.16), (0, -0.16, 0.36), 0.15, 0.19, seg=7, rings=3)
for v in torso.verts:  # achata (mais largo que alto)
    v.co.x *= 1.15
    v.co.z = 0.16 + (v.co.z - 0.16) * 0.85
add_part(torso, "spine", "pele", jitter=0.012)
# toco rasgado e tripas penduradas
stump = blob((0, 0.47, 0.15), (0.15, 0.08, 0.12))
add_part(stump, "root", "sangue", jitter=0.03)
for sx, ln in ((0.05, 0.42), (-0.06, 0.32), (0.0, 0.55)):
    add_part(cylinder((sx, 0.5, 0.14), (sx * 2.5, 0.5 + ln, 0.02), 0.035, 0.02, seg=5, rings=3), "root", "sangue", jitter=0.02)
# costelas expostas nas laterais
for i in range(4):
    yv = 0.18 - i * 0.09
    for sx in (1, -1):
        add_part(box((sx * 0.19, yv, 0.27 + i * 0.015), (0.025, 0.018, 0.13)), "spine", "osso")
# pescoço, cabeça e mandíbula
add_part(cylinder((0, -0.12, 0.34), (0, -0.3, 0.45), 0.07, 0.055, seg=6), "neck", "pele")
head = blob((0, -0.38, 0.5), (0.1, 0.115, 0.115), subdiv=2)
add_part(head, "head", "cabeca", mapping="cabeca", jitter=0.004)
jaw = blob((0, -0.42, 0.41), (0.075, 0.08, 0.035), subdiv=1)
add_part(jaw, "jaw", "boca", mapping="cil")
for k in range(6):  # dentes da mandíbula
    a = math.pi * (0.15 + 0.7 * k / 5)
    add_part(box((math.cos(a) * 0.055, -0.42 - math.sin(a) * 0.06, 0.445), (0.012, 0.012, 0.03)), "jaw", "osso")
# olhos que brilham, fundos nas órbitas
for sx in (0.032, -0.032):
    e = blob((sx, -0.478, 0.525), (0.014, 0.01, 0.014), subdiv=1)
    parts.append((e, "head", "olho", "olho"))
# braços compridos, cotovelos para fora, mãos espalmadas no chão com garras
for s, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.2 * s, -0.08, 0.36)), Vector((0.34 * s, -0.32, 0.2)), Vector((0.3 * s, -0.58, 0.04))
    add_part(cylinder(sh, el, 0.055, 0.045, seg=6, rings=2), "upper_arm." + side, "braco", jitter=0.006)
    add_part(cylinder(el, wr, 0.045, 0.035, seg=6, rings=2), "forearm." + side, "braco", jitter=0.006)
    add_part(box(wr + Vector((0, -0.06, -0.015)), (0.07, 0.09, 0.025)), "hand." + side, "braco")
    for f in range(4):  # dedos longos terminando em garra
        fx = wr.x + (f - 1.5) * 0.022 * s
        base = Vector((fx, wr.y - 0.1, 0.02))
        add_part(cylinder(base, base + Vector(((f - 1.5) * 0.012 * s, -0.09, -0.015)), 0.011, 0.004, seg=4), "hand." + side, "garra")

# junta tudo num objeto, com UV por parte e grupos de vértices por osso
mesh = bpy.data.meshes.new("rastejante")
obj = bpy.data.objects.new("rastejante", mesh)
bpy.context.collection.objects.link(obj)
obj.data.materials.append(mat)
obj.data.materials.append(eye_mat)
big = bmesh.new()
uv_layer = big.loops.layers.uv.new("UVMap")
deform = big.verts.layers.deform.verify()
bone_names = ["root", "spine", "neck", "head", "jaw"] + [f"{b}.{s}" for s in "LR" for b in ("upper_arm", "forearm", "hand")]
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
arm = bpy.data.objects.new("Rastejante", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
BONES = {
    "root": ((0, 0.42, 0.16), (0, 0.12, 0.22), None),
    "spine": ((0, 0.12, 0.22), (0, -0.12, 0.34), "root"),
    "neck": ((0, -0.12, 0.34), (0, -0.3, 0.45), "spine"),
    "head": ((0, -0.3, 0.45), (0, -0.48, 0.52), "neck"),
    "jaw": ((0, -0.34, 0.44), (0, -0.48, 0.41), "head"),
}
for s, side in ((1, "L"), (-1, "R")):
    BONES["upper_arm." + side] = ((0.2 * s, -0.08, 0.36), (0.34 * s, -0.32, 0.2), "spine")
    BONES["forearm." + side] = ((0.34 * s, -0.32, 0.2), (0.3 * s, -0.58, 0.04), "upper_arm." + side)
    BONES["hand." + side] = ((0.3 * s, -0.58, 0.04), (0.3 * s, -0.72, 0.02), "forearm." + side)
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
    """phase 0..1: braço esquerdo estica enquanto o direito puxa (e vice-versa)."""
    a = math.sin(phase * math.tau)
    b = math.cos(phase * math.tau)
    return ({
        "upper_arm.L": (-22 * a, 0, 14 * a), "forearm.L": (28 * max(a, 0), 0, 0),
        "upper_arm.R": (22 * a, 0, -14 * a), "forearm.R": (28 * max(-a, 0), 0, 0),
        "spine": (4 * abs(b), 9 * a, 0), "neck": (-6 * abs(a), 0, 10 * a),
        "head": (8 * b, 0, -12 * a), "jaw": (12 + 10 * abs(b), 0, 0),
        "root": (0, -6 * a, 0),
    }, {"root": (0, 0.015 * abs(b), 0)})


anim("Crawl", 24, [(f, *crawl_pose(f / 24)) for f in range(0, 25, 3)])
anim("Idle", 48, [
    (0, {"head": (0, 0, 0), "jaw": (6, 0, 0), "neck": (0, 0, 0), "hand.L": (0, 0, 0)}, {}),
    (10, {"head": (-10, 18, 14), "jaw": (22, 0, 0), "neck": (5, 0, 8), "hand.L": (-25, 0, 0)}, {}),
    (13, {"head": (6, -8, -20), "jaw": (4, 0, 0), "neck": (-4, 0, -6), "hand.L": (10, 0, 0)}, {}),  # espasmo
    (26, {"head": (-4, 26, 6), "jaw": (30, 0, 0), "neck": (2, 0, 4), "hand.L": (-30, 0, 0), "spine": (0, 6, 0)}, {}),
    (36, {"head": (2, -6, -4), "jaw": (10, 0, 0), "neck": (0, 0, -2), "hand.L": (5, 0, 0)}, {}),
    (48, {"head": (0, 0, 0), "jaw": (6, 0, 0), "neck": (0, 0, 0), "hand.L": (0, 0, 0)}, {}),
])
# bote: empina nos braços, cabeça projetada, boca escancarada, garras para a frente
rear = {"spine": (-28, 0, 0), "neck": (-18, 0, 0), "head": (12, 0, 0), "jaw": (42, 0, 0),
        "upper_arm.L": (-60, 0, 10), "forearm.L": (-20, 0, 0), "upper_arm.R": (-60, 0, -10), "forearm.R": (-20, 0, 0),
        "hand.L": (-30, 0, 0), "hand.R": (-30, 0, 0)}
shake = {k: (v[0] + 6, v[1] + 4, v[2] - 5) for k, v in rear.items()}
anim("Attack", 12, [(0, rear, {"root": (0, 0, 0)}), (3, shake, {"root": (0, 0.04, 0)}),
                    (6, rear, {"root": (0, 0.02, 0)}), (9, shake, {"root": (0, 0.05, 0)}), (12, rear, {"root": (0, 0, 0)})])

# --- exportar ---------------------------------------------------------------------------
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=False,
                          export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_skins=True, export_materials="EXPORT", export_image_format="AUTO")
tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
print(f"rastejante: {tris} triângulos, {len(parts)} partes -> {OUT}")

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
    views = {"frente": ((0, -1.9, 0.55), (82, 0, 0)), "lado": ((1.9, -0.1, 0.5), (80, 0, 90))}
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    for name, frame in (("Idle", 10), ("Crawl", 6), ("Crawl", 18), ("Attack", 3)):
        for t in arm.animation_data.nla_tracks:
            t.mute = t.name != name
        sc.frame_set(frame)
        for vname, (loc, rot) in views.items():
            cam.location = loc
            cam.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
            sc.render.filepath = os.path.join(PREVIEW, f"{name}_{frame}_{vname}.png")
            bpy.ops.render.render(write_still=True)
    print("prévias ->", PREVIEW)

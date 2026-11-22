#!/usr/bin/env python3
"""Modela a Vó Celeste (campanha Exorcismo) no Blender, normal e possuída.

Uso (Blender como módulo Python, `pip install bpy`):
  python3 tools/blender/make_vo_celeste.py [--possuida] [--preview pasta]

Gera game/assets/models/vo_celeste.glb (normal) ou vo_possuida.glb (--possuida):
  - senhora de 1,55 m, um pouco curvada, camisola comprida até a canela, pés descalços
  - normal: cabelo grisalho preso num coque, olhos castanhos, bochecha rosada,
    terço no pescoço com crucifixo no peito
  - possuída: pele cinzenta com veias escuras, olhos todos pretos com um brilho
    amarelado no fundo, boca rachada, cabelo solto e sujo caindo no rosto,
    camisola manchada, unhas compridas
  - esqueleto com osso "head" (o susto do jogo segue o osso da cabeça)
  - animações (as mesmas nas duas versões):
      Idle          em pé, curvada, com tiques de cabeça
      SitIdle       sentada na cadeira de balanço, mãos no colo
      Walk          andando arrastando os pés
      HeadTurn      o corpo parado e a cabeça girando 180 graus para trás (para e segura)
      LieIdle       deitada de barriga para cima, braços cruzados no peito
      LevitateIdle  deitada no ar, costas arqueadas, braços e cabeça pendurados
      FloatIdle     em pé no ar, pés apontando para baixo, braços abertos
      Crawl         de quatro, de bruços (o jogo gira para andar na parede e no teto)
      SpiderCrawl   em ponte, de barriga para cima, cabeça de ponta-cabeça olhando para a frente
      Attack        bote com os braços esticados

Feito do zero aqui (licença do projeto). Frente do modelo = -Y no Blender
(+Z no glTF/Godot). As poses são dadas por direção de cada osso no espaço do
esqueleto (ver `solve`), o que deixa deitar, ficar de quatro e de ponte sem
contas de ângulo na mão.
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
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
POSS = "--possuida" in argv
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
OUT = os.path.join(ROOT, "game", "assets", "models", "vo_possuida.glb" if POSS else "vo_celeste.glb")
random.seed(53)
np.random.seed(53)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 24

# --- textura (atlas 128x128) ----------------------------------------------------------------
TEX = 128
REG = {"pele": (0.0, 0.0, 0.5, 0.5), "cabeca": (0.5, 0.0, 1.0, 0.5),
       "camisola": (0.0, 0.5, 0.5, 1.0), "cabelo": (0.5, 0.5, 0.75, 1.0), "unha": (0.75, 0.5, 1.0, 1.0)}


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
        col[m] = col[m] * 0.4 + np.array(spots[0]) * 0.6
    img[y0:y1, x0:x1] = np.clip(col, 0, 1)
    return x0, y0, w, h


if POSS:
    SKIN = (0.56, 0.58, 0.52)
    fill("pele", SKIN, (0.1, 0.1, 0.1), spots=((0.3, 0.26, 0.32), 0.22))  # hematomas arroxeados
    fill("camisola", (0.72, 0.68, 0.58), (0.14, 0.12, 0.1), spots=((0.42, 0.12, 0.08), 0.18), scale=4)  # manchas de sangue
    fill("cabelo", (0.42, 0.4, 0.37), (0.16, 0.15, 0.14), scale=2)
    fill("unha", (0.25, 0.22, 0.16), (0.08, 0.07, 0.05))
else:
    SKIN = (0.84, 0.7, 0.62)
    fill("pele", SKIN, (0.08, 0.07, 0.07), spots=((0.7, 0.55, 0.5), 0.12))
    fill("camisola", (0.9, 0.87, 0.8), (0.06, 0.06, 0.05), scale=4)
    x0c, y0c, wc, hc = REG["camisola"][0] * TEX, REG["camisola"][1] * TEX, 64, 64
    yy, xx = np.mgrid[0:64, 0:64]  # florzinhas azuis na camisola
    flores = ((xx % 9 == 4) & (yy % 9 == 4)) | ((xx % 9 == 0) & (yy % 9 == 0))
    img[int(y0c):int(y0c) + 64, int(x0c):int(x0c) + 64][flores] = (0.5, 0.6, 0.85)
    fill("cabelo", (0.78, 0.77, 0.75), (0.12, 0.12, 0.12), scale=2)
    fill("unha", (0.8, 0.66, 0.6), (0.05, 0.05, 0.05))
x0, y0, w, h = fill("cabeca", SKIN, (0.06, 0.06, 0.06), spots=((SKIN[0] * 0.8, SKIN[1] * 0.75, SKIN[2] * 0.75), 0.15))
yy, xx = np.mgrid[0:h, 0:w]
U, V = xx / w, yy / h
face = img[y0:y0 + h, x0:x0 + w]
for k in range(5):  # rugas na testa e no canto dos olhos
    face[(np.abs(V - (0.74 + 0.03 * k)) < 0.005) & (np.abs(U - 0.5) < 0.09)] *= 0.82
for cx in (0.44, 0.56):
    sock = ((U - cx) / 0.045) ** 2 + ((V - 0.6) / 0.03) ** 2
    if POSS:
        face[sock < 1.6] = (0.02, 0.02, 0.02)  # olhos todos pretos
        face[(sock >= 1.6) & (sock < 4.0)] *= 0.45  # olheira funda
    else:
        face[sock < 1.0] = (0.95, 0.93, 0.88)
        iris = ((U - cx) / 0.018) ** 2 + ((V - 0.6) / 0.024) ** 2
        face[iris < 1.0] = (0.3, 0.18, 0.1)
        face[(sock >= 1.0) & (sock < 1.5)] *= 0.8
        brow = (np.abs(V - 0.67) < 0.008) & (np.abs(U - cx) < 0.04)
        face[brow] = (0.7, 0.7, 0.68)
        cheek = ((U - cx) / 0.04) ** 2 + ((V - 0.5) / 0.03) ** 2
        face[cheek < 1.0] = face[cheek < 1.0] * 0.85 + np.array((0.9, 0.45, 0.45)) * 0.15
mouth_v = 0.38 + 0.2 * (U - 0.5) ** 2
if POSS:
    m = (np.abs(V - mouth_v) < 0.02) & (np.abs(U - 0.5) < 0.07)
    face[m] = (0.15, 0.02, 0.02)
    for k in range(7):  # rachaduras nos lábios e veias escuras saindo dos olhos
        face[(np.abs(U - (0.45 + 0.017 * k)) < 0.003) & (np.abs(V - 0.38) < 0.04)] = (0.35, 0.05, 0.05)
    veins = noise(h, w, 2) > 0.8
    around = (np.abs(U - 0.5) < 0.16) & (V > 0.45) & (V < 0.75)
    face[veins & around] = face[veins & around] * 0.4 + np.array((0.2, 0.08, 0.25)) * 0.6
    for s in (-1, 1):  # arranhões na bochecha
        for k in range(3):
            line = np.abs((U - 0.5) * s - (0.07 + 0.015 * k) - (V - 0.5) * 0.4) < 0.004
            face[line & (V > 0.42) & (V < 0.55)] = (0.45, 0.06, 0.05)
else:
    m = (np.abs(V - mouth_v) < 0.008) & (np.abs(U - 0.5) < 0.05)
    face[m] = (0.65, 0.38, 0.38)

image = bpy.data.images.new("vo_tex", TEX, TEX, alpha=False)
image.pixels.foreach_set(np.concatenate([img, np.ones((TEX, TEX, 1))], axis=2).astype(np.float32).ravel())
image.pack()


def material(name, color=None, emission=None, tex=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    if tex:
        tn = m.node_tree.nodes.new("ShaderNodeTexImage")
        tn.image = image
        tn.interpolation = "Closest"
        m.node_tree.links.new(tn.outputs["Color"], b.inputs["Base Color"])
    if color:
        b.inputs["Base Color"].default_value = (*color, 1)
    if emission:
        b.inputs["Emission Color"].default_value = (*emission[0], 1)
        b.inputs["Emission Strength"].default_value = emission[1]
    b.inputs["Roughness"].default_value = 0.9
    return m


mat = material("VoCeleste", tex=True)
eye_mat = material("BrilhoOlho", (0.9, 0.85, 0.4), ((0.9, 0.8, 0.3), 1.6))
dark_mat = material("Escuro", (0.05, 0.04, 0.04))

# --- malha ----------------------------------------------------------------------------------
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


HEAD_C = Vector((0, -0.01, 1.44))
head = blob(HEAD_C, (0.082, 0.092, 0.105), subdiv=2)
for v in head.verts:
    t = (v.co.z - (HEAD_C.z - 0.105)) / 0.21
    v.co.x *= 0.8 + 0.2 * min(1.0, t * 1.5)  # queixo miúdo
    if POSS and v.co.y < HEAD_C.y - 0.05:
        v.co.y -= 0.004 * random.uniform(-1, 1)  # rosto repuxado
add(head, "head", "cabeca", "cabeca")
add(cylinder((0, -0.09, 1.45), (0, -0.115, 1.41), 0.013, 0.008, seg=5), "head", "pele")  # nariz
for s in (1, -1):
    add(blob((0.083 * s, -0.005, 1.44), (0.012, 0.022, 0.03)), "head", "pele")  # orelhas
    if POSS:
        add(blob((0.034 * s, -0.087, 1.465), (0.009, 0.004, 0.006)), "head", mapping="olho", mat_i=1)  # brilho no fundo do olho
# cabelo
cap = blob(HEAD_C + Vector((0, 0.012, 0.03)), (0.09, 0.095, 0.095), subdiv=2)
for v in cap.verts:
    if v.co.z < HEAD_C.z - 0.005 and v.co.y < HEAD_C.y + 0.02:
        v.co.z = HEAD_C.z - 0.005 + (v.co.z - HEAD_C.z) * 0.2  # deixa o rosto à mostra
    v.co += Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * (0.008 if POSS else 0.003)
add(cap, "head", "cabelo")
if POSS:
    for k in range(18):  # cabelo solto, comprido e sujo, caindo dos lados do rosto e nas costas
        a = k / 18 * math.tau
        if math.cos(a) < -0.55:
            continue  # o rosto fica à mostra
        top = HEAD_C + Vector((math.sin(a) * 0.078, math.cos(a) * 0.08, 0.055))
        side = math.cos(a) < 0.0  # mechas que emolduram o rosto
        length = random.uniform(0.3, 0.45)
        end = top + Vector((math.sin(a) * (0.03 if side else 0.05), math.cos(a) * 0.05 - (0.04 if side else 0), -length))
        add(cylinder(top, end, 0.016, 0.005, seg=4, rings=2), "head", "cabelo")
else:
    add(blob(HEAD_C + Vector((0, 0.1, 0.03)), (0.045, 0.04, 0.045)), "head", "cabelo")  # coque
add(cylinder((0, 0.0, 1.25), (0, -0.01, 1.35), 0.035, 0.03, seg=6), "neck", "pele")
# camisola: tronco
torso = cylinder((0, 0.0, 0.88), (0, 0.0, 1.27), 0.16, 0.14, seg=9, rings=3)
for v in torso.verts:
    v.co.y *= 0.75
    if v.co.z > 1.0 and v.co.y < -0.04:
        v.co.y -= 0.02  # busto
add(torso, "spine", "camisola")
for s in (1, -1):
    add(blob((0.15 * s, 0.0, 1.22), (0.055, 0.055, 0.05)), "spine", "camisola")
add(blob((0, 0.0, 0.84), (0.17, 0.13, 0.1)), "root", "camisola")
# saia em dois tubos que se encostam (de pé parece uma camisola; dobra junto com as pernas)
for s, side in ((1, "L"), (-1, "R")):
    hip, knee, ankle = Vector((0.08 * s, 0, 0.8)), Vector((0.08 * s, 0, 0.44)), Vector((0.08 * s, 0.01, 0.06))
    add(cylinder(hip, knee, 0.13, 0.13, seg=7, rings=2), "thigh." + side, "camisola")
    add(cylinder(knee, (0.08 * s, 0.005, 0.2), 0.13, 0.14, seg=7, rings=2), "shin." + side, "camisola")
    add(cylinder((0.08 * s, 0.005, 0.22), ankle, 0.03, 0.025, seg=5), "shin." + side, "pele")  # canela fina
    add(blob(ankle + Vector((0, -0.045, -0.03)), (0.03, 0.075, 0.025)), "shin." + side, "pele")  # pé descalço
    # braços com manga comprida, mãos ossudas
    sh, el, wr = Vector((0.16 * s, 0, 1.22)), Vector((0.19 * s, 0, 0.98)), Vector((0.2 * s, -0.02, 0.76))
    add(cylinder(sh, el, 0.045, 0.04, seg=6, rings=2), "upper_arm." + side, "camisola")
    add(cylinder(el, wr, 0.04, 0.035, seg=6, rings=2), "forearm." + side, "camisola")
    add(blob(wr + Vector((0, -0.005, -0.045)), (0.03, 0.017, 0.045)), "hand." + side, "pele")
    nail = 0.11 if POSS else 0.07
    for f in range(4):
        base = wr + Vector(((f - 1.5) * 0.013 * s, -0.012, -0.08))
        add(cylinder(base, base + Vector(((f - 1.5) * 0.004 * s, -0.01, -nail)), 0.007, 0.004, seg=4), "hand." + side,
            "unha" if POSS else "pele")
if not POSS:  # terço: contas no pescoço e o crucifixo no peito
    for k in range(14):
        a = k / 14 * math.tau
        p = Vector((math.sin(a) * 0.075, math.cos(a) * 0.06 - 0.02, 1.25 - 0.08 * max(0.0, -math.cos(a))))
        add(blob(p, (0.008, 0.008, 0.008)), "spine", mapping="olho", mat_i=2)
    add(cylinder((0, -0.12, 1.13), (0, -0.12, 1.06), 0.006, 0.006, seg=4), "spine", mapping="olho", mat_i=2)
    add(cylinder((-0.02, -0.12, 1.11), (0.02, -0.12, 1.11), 0.006, 0.006, seg=4), "spine", mapping="olho", mat_i=2)

mesh = bpy.data.meshes.new("vo")
obj = bpy.data.objects.new("vo", mesh)
bpy.context.collection.objects.link(obj)
for m in (mat, eye_mat, dark_mat):
    obj.data.materials.append(m)
big = bmesh.new()
uv_layer = big.loops.layers.uv.new("UVMap")
deform = big.verts.layers.deform.verify()
BONE_NAMES = ["root", "spine", "neck", "head"] + [f"{b}.{s}" for s in "LR" for b in ("upper_arm", "forearm", "hand", "thigh", "shin")]
for name in BONE_NAMES:
    obj.vertex_groups.new(name=name)
for bm, bone, region, mapping, mat_i in parts:
    vmap = {}
    for v in bm.verts:
        nv = big.verts.new(v.co)
        nv[deform][BONE_NAMES.index(bone)] = 1.0
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
arm = bpy.data.objects.new("VoCeleste", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
BONES = {
    "root": ((0, 0, 0.8), (0, 0, 0.92), None),
    "spine": ((0, 0, 0.92), (0, 0, 1.26), "root"),
    "neck": ((0, 0, 1.26), (0, -0.01, 1.34), "spine"),
    "head": ((0, -0.01, 1.34), (0, -0.01, 1.56), "neck"),
}
for s, side in ((1, "L"), (-1, "R")):
    BONES["upper_arm." + side] = ((0.16 * s, 0, 1.22), (0.19 * s, 0, 0.98), "spine")
    BONES["forearm." + side] = ((0.19 * s, 0, 0.98), (0.2 * s, -0.02, 0.76), "upper_arm." + side)
    BONES["hand." + side] = ((0.2 * s, -0.02, 0.76), (0.2 * s, -0.03, 0.62), "forearm." + side)
    BONES["thigh." + side] = ((0.08 * s, 0, 0.8), (0.08 * s, 0, 0.44), "root")
    BONES["shin." + side] = ((0.08 * s, 0, 0.44), (0.08 * s, 0.01, 0.06), "thigh." + side)
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

# --- poses por direção ---------------------------------------------------------------------------
REST = {n: arm_data.bones[n].matrix_local.to_3x3() for n in BONE_NAMES}
REST_HEAD = {n: Vector(BONES[n][0]) for n in BONE_NAMES}
PARENT = {n: BONES[n][2] for n in BONE_NAMES}
FRONT = Vector((0, -1, 0))


def _orient(name, d, f):
    """Rotação (espaço do esqueleto) do osso apontando para d, com a 'frente' (o -Y do repouso) virada para f."""
    rest = REST[name]
    d = Vector(d).normalized()
    r1 = (rest @ Vector((0, 1, 0))).rotation_difference(d).to_matrix()
    if f is not None:
        fr = r1 @ FRONT
        fr_p = fr - d * fr.dot(d)
        f = Vector(f)
        f_p = f - d * f.dot(d)
        if fr_p.length > 1e-4 and f_p.length > 1e-4:
            fr_p.normalize()
            f_p.normalize()
            ang = fr_p.angle(f_p)
            if fr_p.cross(f_p).dot(d) < 0:
                ang = -ang
            r1 = Matrix.Rotation(ang, 3, d) @ r1
    return r1 @ rest


def solve(pose, hips=None):
    """pose = {osso: (direção, frente ou None)} no espaço do esqueleto -> {osso: quaternion local}, loc da raiz."""
    world, out = {}, {}
    for n in BONE_NAMES:  # pais antes dos filhos
        p = PARENT[n]
        base = world[p] @ REST[p].inverted() @ REST[n] if p else REST[n]
        if n in pose:
            d, f = pose[n]
            world[n] = _orient(n, d, f)
        else:
            world[n] = base
        out[n] = (base.inverted() @ world[n]).to_quaternion()
    loc = Vector((0, 0, 0))
    if hips is not None:
        loc = REST["root"].inverted() @ (Vector(hips) - REST_HEAD["root"])
    return out, loc


arm.animation_data_create()
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = "QUATERNION"


def anim(name, keys):
    """keys = [(frame, pose, hips)]"""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    prev = {}
    for frame, pose, hips in keys:
        rots, loc = solve(pose, hips)
        for b in pb:
            q = rots[b.name]
            if b.name in prev and prev[b.name].dot(q) < 0:
                q.negate()  # mesmo hemisfério do quadro anterior: nada de giro pelo lado errado
            prev[b.name] = q.copy()
            b.rotation_quaternion = q
            b.keyframe_insert("rotation_quaternion", frame=frame)
            b.location = loc if b.name == "root" else Vector((0, 0, 0))
            b.keyframe_insert("location", frame=frame)
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 0, act)
    tr.mute = True
    arm.animation_data.action = None


def rotz(v, deg):
    return tuple(Matrix.Rotation(math.radians(deg), 3, "Z") @ Vector(v))


def lr(dic, name, d, f=None):
    """Põe o mesmo osso dos dois lados (x espelhado)."""
    dic[name + ".L"] = ((d[0], d[1], d[2]), f)
    dic[name + ".R"] = ((-d[0], d[1], d[2]), (None if f is None else (-f[0], f[1], f[2])))
    return dic


def stand(head_front=(0, -1, 0), neck_turn=0.0, extra=None):
    p = {"spine": ((0, -0.22, 1), (0, -1, 0)), "neck": ((0, -0.35, 1), rotz((0, -1, 0), neck_turn)),
         "head": ((0, -0.08, 1), head_front)}
    lr(p, "upper_arm", (0.15, -0.12, -1))
    lr(p, "forearm", (0.06, -0.45, -1))
    lr(p, "hand", (0.02, -0.4, -1))
    lr(p, "thigh", (0.0, 0.0, -1))
    lr(p, "shin", (0.0, 0.03, -1))
    p.update(extra or {})
    return p


# Idle: curvada, tiques de cabeça
anim("Idle", [
    (0, stand(), None),
    (20, stand(head_front=(0.25, -1, 0.1)), None),
    (24, stand(head_front=(0.45, -1, -0.15)), None),   # tique
    (44, stand(head_front=(-0.2, -1, 0.05)), None),
    (60, stand(), None),
])

# SitIdle: cadeira de balanço
def sit(rock):
    p = {"root": ((0, 0.2 + rock, 1), (0, -1, 0)), "spine": ((0, 0.15 + rock, 1), (0, -1, 0)),
         "neck": ((0, -0.1, 1), (0, -1, 0)), "head": ((0, -0.05, 1), (0, -1, 0))}
    lr(p, "thigh", (0.06, -1, 0.05))
    lr(p, "shin", (0.0, 0.05, -1))
    lr(p, "upper_arm", (0.12, -0.25, -1))
    lr(p, "forearm", (-0.25, -1, -0.15))
    lr(p, "hand", (-0.2, -1, -0.3))
    return p


anim("SitIdle", [(0, sit(0.0), (0, 0.08, 0.5)), (30, sit(0.12), (0, 0.1, 0.52)), (60, sit(0.0), (0, 0.08, 0.5))])


def walk(ph):
    a = math.sin(ph * math.tau)
    p = stand(head_front=(0.1 * a, -1, 0))
    lr(p, "thigh", (0.0, 0.0, -1))
    p["thigh.L"] = ((0.0, -0.22 * a, -1), None)
    p["thigh.R"] = ((0.0, 0.22 * a, -1), None)
    p["shin.L"] = ((0.0, 0.15 * max(0, a), -1), None)
    p["shin.R"] = ((0.0, 0.15 * max(0, -a), -1), None)
    return p


anim("Walk", [(f, walk(f / 40), (0, 0, 0.8 + 0.01 * abs(math.cos(f / 40 * math.tau)))) for f in range(0, 41, 5)])

# HeadTurn: o corpo parado, a cabeça girando 180 graus aos trancos, até o rosto ficar nas costas
turn_keys = []
for frame, ang in ((0, 0), (10, 0), (18, 35), (22, 38), (34, 95), (38, 98), (52, 178), (56, 180), (80, 180)):
    hf = rotz((0, -1, 0), ang)
    turn_keys.append((frame, stand(head_front=hf, neck_turn=ang * 0.4), None))
turn_keys.append((86, stand(head_front=rotz((0.2, -1, -0.25), 180), neck_turn=72), None))  # inclina a cabeça, curiosa
anim("HeadTurn", turn_keys)


# LieIdle: deitada de costas (cabeça para +Y, barriga para cima), braços cruzados no peito
def lie(arch=0.0, dangle=False, head_drop=0.0):
    up = (0, 0, 1)
    p = {"root": ((0, 1, arch), up), "spine": ((0, 1, arch), up), "neck": ((0, 1, -head_drop * 0.5), up),
         "head": ((0, 1, -head_drop), up)}
    lr(p, "thigh", (0.03, -1, -arch * 0.6), up)
    lr(p, "shin", (0.02, -1, -arch * 0.3), up)
    if dangle:
        lr(p, "upper_arm", (0.35, -0.1, -1))
        lr(p, "forearm", (0.1, 0.0, -1))
        lr(p, "hand", (0.05, 0.0, -1))
    else:
        lr(p, "upper_arm", (0.25, -1, 0.1))
        lr(p, "forearm", (-1, 0.35, 0.25))
        lr(p, "hand", (-1, 0.3, 0.1))
    return p


anim("LieIdle", [(0, lie(), (0, -0.05, 0.62)), (40, lie(0.02), (0, -0.05, 0.625)), (80, lie(), (0, -0.05, 0.62))])
anim("LevitateIdle", [
    (0, lie(0.35, True, 0.7), (0, -0.05, 0.62)),
    (24, lie(0.42, True, 0.85), (0, -0.05, 0.64)),
    (48, lie(0.35, True, 0.7), (0, -0.05, 0.62)),
])


# FloatIdle: em pé no ar, pés apontando para baixo, braços abertos, cabeça tombada
def float_pose(sway):
    p = {"spine": ((0, 0.05, 1), (0, -1, 0)), "neck": ((0.3 * sway, 0.1, 1), (0, -1, 0)),
         "head": ((0.55 * sway + 0.15, 0.25, 1), (0, -1, -0.2))}
    lr(p, "upper_arm", (1, -0.1, -0.35))
    lr(p, "forearm", (1, -0.15, -0.5))
    lr(p, "hand", (1, -0.1, -0.9))
    lr(p, "thigh", (0.02, 0.05, -1))
    lr(p, "shin", (0.0, 0.18, -1))
    return p


anim("FloatIdle", [(0, float_pose(-0.3), None), (36, float_pose(0.3), None), (72, float_pose(-0.3), None)])


# Crawl: de quatro, de bruços, indo para -Y; o jogo gira o boneco para andar na parede e no teto
def crawl(ph):
    a = math.sin(ph * math.tau)
    down = (0, 0, -1)
    p = {"root": ((0, -1, 0.05), down), "spine": ((0, -1, 0.08), down), "neck": ((0, -1, 0.6), down),
         "head": ((0, -0.55, 1), (0, -1, 0))}
    p["upper_arm.L"] = ((0.15, -0.25 - 0.3 * a, -1), None)
    p["upper_arm.R"] = ((-0.15, -0.25 + 0.3 * a, -1), None)
    lr(p, "forearm", (0.05, -0.15, -1))
    lr(p, "hand", (0.0, -1, -0.25))
    p["thigh.L"] = ((0.2, -0.15 + 0.3 * a, -1), None)
    p["thigh.R"] = ((-0.2, -0.15 - 0.3 * a, -1), None)
    lr(p, "shin", (0.05, 1, -0.2))
    return p


anim("Crawl", [(f, crawl(f / 24), (0, 0.18, 0.62)) for f in range(0, 25, 3)])


# SpiderCrawl: em ponte, barriga para cima, andando para -Y com a cabeça de ponta-cabeça olhando para a frente
def spider(ph):
    a = math.sin(ph * math.tau)
    up = (0, 0, 1)
    p = {"root": ((0, -1, 0.15), up), "spine": ((0, -1, 0.05), up), "neck": ((0, -0.6, -0.8), (0, 0, 1)),
         "head": ((0, -0.15, -1), (0, -1, 0))}
    p["upper_arm.L"] = ((0.25, -0.15 - 0.25 * a, -1), None)
    p["upper_arm.R"] = ((-0.25, -0.15 + 0.25 * a, -1), None)
    lr(p, "forearm", (0.05, -0.05, -1))
    lr(p, "hand", (0.0, -0.7, -0.6))
    p["thigh.L"] = ((0.22, 0.6 - 0.2 * a, -0.6), None)
    p["thigh.R"] = ((-0.22, 0.6 + 0.2 * a, -0.6), None)
    lr(p, "shin", (0.03, 0.12, -1))
    return p


anim("SpiderCrawl", [(f, spider(f / 20), (0, 0.22, 0.76)) for f in range(0, 21, 2)])


def attack(k):
    p = stand(head_front=(0, -1, 0.15 * k))
    p["spine"] = ((0, -0.7 - 0.1 * k, 1), (0, -1, 0))
    p["neck"] = ((0, -0.8, 1), (0, -1, 0))
    p["head"] = ((0, -0.5, 1), (0, -1, 0.1))
    lr(p, "upper_arm", (0.25, -1, 0.15 + 0.1 * k))
    lr(p, "forearm", (0.15, -1, 0.1))
    lr(p, "hand", (0.1, -1, 0.0))
    return p


anim("Attack", [(0, attack(0), None), (4, attack(1), None), (8, attack(0), None), (12, attack(1), None), (16, attack(0), None)])

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True)
print(f"vo ({'possuída' if POSS else 'normal'}): {sum(len(p.vertices) - 2 for p in mesh.polygons)} triângulos, {len(parts)} partes -> {OUT}")

if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    for loc, e in (((1.0, -2.0, 1.8), 220), ((-1.2, -1.0, 0.6), 60), ((0, 1.5, 2.5), 80)):
        L = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT"))
        L.data.energy = e
        L.location = loc
        sc.collection.objects.link(L)
    floor = bpy.data.objects.new("chao", bpy.data.meshes.new("chao"))
    fb = bmesh.new()
    bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=3)
    fb.to_mesh(floor.data)
    sc.collection.objects.link(floor)
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 10
    sc.render.resolution_x, sc.render.resolution_y = 240, 320
    views = {"frente": ((0, -3.6, 0.9), (85, 0, 0), 50), "rosto": ((0, -0.8, 1.44), (90, 0, 0), 50), "lado": ((3.6, 0, 0.9), (85, 0, 90), 50)}
    for name, frame in (("Idle", 24), ("SitIdle", 0), ("HeadTurn", 80), ("LieIdle", 0), ("LevitateIdle", 24),
                        ("FloatIdle", 0), ("Crawl", 6), ("SpiderCrawl", 5), ("Attack", 4)):
        for t in arm.animation_data.nla_tracks:
            t.mute = t.name != name
        sc.frame_set(frame)
        for vname, (loc, rot, lens) in views.items():
            if vname == "rosto" and name not in ("Idle", "HeadTurn"):
                continue
            cam.location = loc
            cam.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
            cam.data.lens = lens
            sc.render.filepath = os.path.join(PREVIEW, f"{name}_{vname}.png")
            bpy.ops.render.render(write_still=True)

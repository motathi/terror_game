#!/usr/bin/env python3
"""Modela o Cinzento (alienígena clássico) no Blender.

Uso (Blender como módulo Python, `pip install bpy`):
  python3 tools/blender/make_cinzento.py [--preview pasta]

Gera game/assets/models/cinzento.glb:
  - corpo magro e baixo (1,25 m), cabeça enorme em forma de gota invertida
  - olhos pretos amendoados e inclinados, com um brilho verde (emissão)
  - braços compridos demais, mãos de três dedos longos
  - textura procedural 128x128 (pele cinza úmida, manchas, sombra nas órbitas)
  - esqueleto com osso "head" (o susto do jogo segue o osso da cabeça)
  - animações: Idle (inclina a cabeça, curioso), Walk (passos lentos), Reach (estica os braços)

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

# --- textura ------------------------------------------------------------------------------
TEX = 128
REG = {"pele": (0.0, 0.0, 0.5, 0.5), "cabeca": (0.5, 0.0, 1.0, 0.5),
       "escuro": (0.0, 0.5, 0.5, 1.0), "unha": (0.5, 0.5, 1.0, 1.0)}


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


fill("pele", (0.5, 0.54, 0.56), (0.12, 0.12, 0.12), spots=((0.38, 0.44, 0.42), 0.22))
fill("escuro", (0.32, 0.35, 0.36), (0.08, 0.08, 0.08))
fill("unha", (0.18, 0.2, 0.2), (0.05, 0.05, 0.05), scale=4)
x0, y0, w, h = fill("cabeca", (0.54, 0.58, 0.6), (0.1, 0.1, 0.1), spots=((0.42, 0.47, 0.46), 0.18))
# sombra funda em volta dos olhos, boca fina, narinas
yy, xx = np.mgrid[0:h, 0:w]
U, V = xx / w, yy / h
face = img[y0:y0 + h, x0:x0 + w]
for cx in (0.42, 0.58):
    d = ((U - cx) / 0.06) ** 2 + ((V - 0.55) / 0.08) ** 2
    face[d < 1.0] *= 0.78
face[(np.abs(V - 0.2) < 0.008) & (np.abs(U - 0.5) < 0.04)] = (0.2, 0.2, 0.22)
for cx in (0.485, 0.515):
    face[(np.abs(V - 0.33) < 0.012) & (np.abs(U - cx) < 0.006)] = (0.15, 0.15, 0.16)

image = bpy.data.images.new("cinzento_tex", TEX, TEX, alpha=False)
image.pixels.foreach_set(np.concatenate([img, np.ones((TEX, TEX, 1))], axis=2).astype(np.float32).ravel())
image.pack()
mat = bpy.data.materials.new("Cinzento")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tn = mat.node_tree.nodes.new("ShaderNodeTexImage")
tn.image = image
tn.interpolation = "Closest"
mat.node_tree.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.6
eye_mat = bpy.data.materials.new("OlhosPretos")
eye_mat.use_nodes = True
eb = eye_mat.node_tree.nodes["Principled BSDF"]
eb.inputs["Base Color"].default_value = (0.01, 0.015, 0.012, 1)
eb.inputs["Roughness"].default_value = 0.05
eb.inputs["Emission Color"].default_value = (0.01, 0.03, 0.015, 1)
eb.inputs["Emission Strength"].default_value = 0.3
glint_mat = bpy.data.materials.new("Brilho")
glint_mat.use_nodes = True
gb = glint_mat.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0.5, 1.0, 0.6, 1)
gb.inputs["Emission Color"].default_value = (0.4, 1.0, 0.5, 1)
gb.inputs["Emission Strength"].default_value = 3.0

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


# cabeça: gota invertida (larga em cima, queixo fino)
HEAD_C = Vector((0, 0, 1.08))
head = blob(HEAD_C, (0.17, 0.185, 0.2), subdiv=2)
for v in head.verts:
    t = (v.co.z - (HEAD_C.z - 0.2)) / 0.4  # 0 no queixo, 1 no topo
    k = 0.42 + 0.58 * min(1.0, t * 1.25)
    v.co.x *= k
    v.co.y = HEAD_C.y + (v.co.y - HEAD_C.y) * (0.6 + 0.4 * min(1.0, t * 1.3))
    if t > 0.75:  # crânio alto
        v.co.z += (t - 0.75) * 0.06
add(head, "head", "cabeca", "cabeca")
# olhos: amêndoas pretas, grandes e inclinadas, quase encostando na pele
for s in (1, -1):
    e = blob((0, 0, 0), (0.05, 0.016, 0.03), subdiv=2)
    rot = Euler((math.radians(-8), 0, math.radians(-24 * s)), "XYZ").to_matrix()
    for v in e.verts:
        v.co = rot @ v.co + Vector((0.058 * s, -0.146, 1.085))
    add(e, "head", mapping="olho", mat_i=1)
    g = blob((0.07 * s, -0.16, 1.098), (0.007, 0.003, 0.005), subdiv=1)
    add(g, "head", mapping="olho", mat_i=2)
add(cylinder((0, 0.01, 0.84), (0, 0.0, 0.92), 0.028, 0.025, seg=6), "neck")
torso = cylinder((0, 0.0, 0.5), (0, 0.0, 0.86), 0.075, 0.11, seg=7, rings=3)
for v in torso.verts:
    v.co.y *= 0.7
add(torso, "spine")
add(blob((0, 0.0, 0.5), (0.09, 0.065, 0.06)), "root")
for s, side in ((1, "L"), (-1, "R")):
    hip, knee, ankle = Vector((0.05 * s, 0, 0.48)), Vector((0.06 * s, -0.01, 0.25)), Vector((0.06 * s, 0.01, 0.04))
    add(cylinder(hip, knee, 0.032, 0.026, seg=6, rings=2), "thigh." + side)
    add(cylinder(knee, ankle, 0.026, 0.018, seg=6, rings=2), "shin." + side)
    add(blob(ankle + Vector((0, -0.04, -0.025)), (0.03, 0.06, 0.018)), "shin." + side)
    sh, el, wr = Vector((0.12 * s, 0, 0.84)), Vector((0.17 * s, -0.01, 0.6)), Vector((0.2 * s, -0.03, 0.36))
    add(cylinder(sh, el, 0.022, 0.018, seg=6, rings=2), "upper_arm." + side)
    add(cylinder(el, wr, 0.018, 0.014, seg=6, rings=2), "forearm." + side)
    add(blob(wr + Vector((0, 0, -0.025)), (0.022, 0.012, 0.03)), "hand." + side)
    for f in range(3):  # três dedos longos e um polegar curto
        a = math.radians(-25 + 25 * f)
        base = wr + Vector((0.008 * (f - 1) * s, -0.004 * (f - 1), -0.05))
        tip = base + Vector((math.sin(a) * 0.03 * s, -0.012, -0.12))
        add(cylinder(base, tip, 0.006, 0.003, seg=4, rings=2), "hand." + side)
        add(blob(tip, (0.006, 0.006, 0.008)), "hand." + side, "unha")
    th = wr + Vector((0.0, -0.02, -0.03))
    add(cylinder(th, th + Vector((-0.02 * s, -0.04, -0.04)), 0.005, 0.003, seg=4), "hand." + side)

mesh = bpy.data.meshes.new("cinzento")
obj = bpy.data.objects.new("cinzento", mesh)
bpy.context.collection.objects.link(obj)
for m in (mat, eye_mat, glint_mat):
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
    p.use_smooth = True

# --- esqueleto -------------------------------------------------------------------------------
arm_data = bpy.data.armatures.new("esqueleto")
arm = bpy.data.objects.new("Cinzento", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
BONES = {
    "root": ((0, 0, 0.46), (0, 0, 0.56), None),
    "spine": ((0, 0, 0.56), (0, 0, 0.86), "root"),
    "neck": ((0, 0, 0.86), (0, 0, 0.93), "spine"),
    "head": ((0, 0, 0.93), (0, 0, 1.3), "neck"),
}
for s, side in ((1, "L"), (-1, "R")):
    BONES["upper_arm." + side] = ((0.12 * s, 0, 0.84), (0.17 * s, -0.01, 0.6), "spine")
    BONES["forearm." + side] = ((0.17 * s, -0.01, 0.6), (0.2 * s, -0.03, 0.36), "upper_arm." + side)
    BONES["hand." + side] = ((0.2 * s, -0.03, 0.36), (0.2 * s, -0.04, 0.2), "forearm." + side)
    BONES["thigh." + side] = ((0.05 * s, 0, 0.48), (0.06 * s, -0.01, 0.25), "root")
    BONES["shin." + side] = ((0.06 * s, -0.01, 0.25), (0.06 * s, 0.01, 0.04), "thigh." + side)
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


ARMS_DOWN = {"upper_arm.L": (0, 0, 4), "upper_arm.R": (0, 0, -4)}
anim("Idle", [
    (0, {**ARMS_DOWN, "head": (0, 0, 0)}, {}),
    (20, {**ARMS_DOWN, "head": (-6, 16, 4), "neck": (0, 4, 0)}, {}),  # inclina a cabeça, curioso
    (34, {**ARMS_DOWN, "head": (-6, 18, 4), "neck": (0, 4, 0), "hand.L": (-12, 0, 0)}, {}),
    (40, {**ARMS_DOWN, "head": (4, -14, -6), "neck": (0, -3, 0)}, {}),  # vira de repente
    (60, {**ARMS_DOWN, "head": (2, -12, -4), "hand.R": (-10, 0, 0)}, {}),
    (72, {**ARMS_DOWN, "head": (0, 0, 0)}, {}),
])


def walk(phase):
    a = math.sin(phase * math.tau)
    return ({"thigh.L": (-22 * a, 0, 0), "shin.L": (max(0, 26 * a), 0, 0), "thigh.R": (22 * a, 0, 0), "shin.R": (max(0, -26 * a), 0, 0),
             "upper_arm.L": (10 * a, 0, 4), "upper_arm.R": (-10 * a, 0, -4), "spine": (0, 0, 4 * a), "head": (0, 0, -5 * a)},
            {"root": (0, 0, 0.012 * abs(math.cos(phase * math.tau)))})


anim("Walk", [(f, *walk(f / 32)) for f in range(0, 33, 4)])
def aim(name, target):
    """Rotação local (graus) que faz o osso apontar para `target` (direção no espaço do esqueleto)."""
    rest = arm_data.bones[name].matrix_local.to_3x3()
    cur = (rest @ Vector((0, 1, 0))).normalized()
    q = cur.rotation_difference(Vector(target).normalized())
    return tuple(math.degrees(x) for x in (rest.inverted() @ q.to_matrix() @ rest).to_euler("XYZ"))


# braços esticados para a frente, na altura do peito, um pouco abertos
reach = {"upper_arm.L": aim("upper_arm.L", (0.07, -0.25, 0.01)), "upper_arm.R": aim("upper_arm.R", (-0.07, -0.25, 0.01)),
         "forearm.L": (0, 0, 0), "forearm.R": (0, 0, 0),
         "hand.L": (-20, 0, 0), "hand.R": (-20, 0, 0), "spine": (-8, 0, 0), "head": (14, 0, 0)}
shiver = {k: (v[0] - 5, v[1] + 3, v[2] + 4) for k, v in reach.items()}
anim("Reach", [(0, reach, {}), (4, shiver, {}), (8, reach, {}), (12, shiver, {}), (16, reach, {})])

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True)
print(f"cinzento: {sum(len(p.vertices) - 2 for p in mesh.polygons)} triângulos, {len(parts)} partes -> {OUT}")

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
    views = {"corpo": ((0, -2.6, 0.75), (88, 0, 0), 50), "rosto": ((0, -0.75, 1.08), (90, 0, 0), 50), "lado": ((2.6, 0, 0.75), (88, 0, 90), 50)}
    for name, frame in (("Idle", 20), ("Walk", 8), ("Reach", 4)):
        for t in arm.animation_data.nla_tracks:
            t.mute = t.name != name
        sc.frame_set(frame)
        for vname, (loc, rot, lens) in views.items():
            cam.location = loc
            cam.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
            cam.data.lens = lens
            sc.render.filepath = os.path.join(PREVIEW, f"{name}_{vname}.png")
            bpy.ops.render.render(write_still=True)

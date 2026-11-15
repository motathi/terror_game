#!/usr/bin/env python3
"""Recorta só a cabeça do PSX Dog (MCSTEEG) em um GLB estático.

Uso: python3 tools/dog_head.py <pasta do psx_dog>
Lê DogGlb.glb e grava dog_head.glb na mesma pasta. Roda no
tools/fetch_assets.py logo depois de baixar o pacote: o arquivo gerado é um
derivado do pacote e, como ele, não vai para o git.

A cabeça sai no espaço do osso da cabeça ("spine.011"), já sem esqueleto:
o jogo pendura ela no osso "Head" de outro modelo (máscara do skinwalker).
Sem dependências além da biblioteca padrão (roda no build da Vercel).
"""
import json
import os
import struct
import sys

HEAD = {"spine.011", "ear.L", "ear.R", "Bone", "Bone.001"}
COMP = {5126: ("f", 4), 5125: ("I", 4), 5123: ("H", 2), 5121: ("B", 1)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    data = open(path, "rb").read()
    magic, _ver, _len = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "não é GLB"
    off, js, blob = 12, None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            blob = chunk
        off += 8 + clen
    return js, blob


def accessor(js, blob, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    stride = bv.get("byteStride", size * n)
    base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [list(struct.unpack_from("<" + fmt * n, blob, base + k * stride)) for k in range(a["count"])]


def mat_mul_vec(m, v, w):  # m: 16 floats coluna-major (glTF)
    x, y, z = v
    return [m[0] * x + m[4] * y + m[8] * z + m[12] * w,
            m[1] * x + m[5] * y + m[9] * z + m[13] * w,
            m[2] * x + m[6] * y + m[10] * z + m[14] * w]


def main(folder):
    js, blob = read_glb(os.path.join(folder, "DogGlb.glb"))
    prim = js["meshes"][0]["primitives"][0]
    at = prim["attributes"]
    pos = accessor(js, blob, at["POSITION"])
    nor = accessor(js, blob, at["NORMAL"])
    uv = accessor(js, blob, at["TEXCOORD_0"])
    joints = accessor(js, blob, at["JOINTS_0"])
    weights = accessor(js, blob, at["WEIGHTS_0"])
    idx = [i[0] for i in accessor(js, blob, prim["indices"])]
    skin = js["skins"][0]
    names = [js["nodes"][j]["name"] for j in skin["joints"]]
    ibm = accessor(js, blob, skin["inverseBindMatrices"])
    head_j = names.index("spine.011")
    head_set = {i for i, n in enumerate(names) if n in HEAD}

    def dominant(v):
        w = weights[v]
        return joints[v][w.index(max(w))]

    keep = [v for v in range(len(pos)) if dominant(v) in head_set]
    keep_set = set(keep)
    tris = [idx[t:t + 3] for t in range(0, len(idx), 3) if all(v in keep_set for v in idx[t:t + 3])]
    remap = {}
    P, N, U = [], [], []
    m = ibm[head_j]
    for tri in tris:
        for v in tri:
            if v not in remap:
                remap[v] = len(P)
                P.append(mat_mul_vec(m, pos[v], 1.0))
                n = mat_mul_vec(m, nor[v], 0.0)
                ln = max((n[0] ** 2 + n[1] ** 2 + n[2] ** 2) ** 0.5, 1e-6)
                N.append([c / ln for c in n])
                U.append(uv[v])
    I = [remap[v] for tri in tris for v in tri]

    def pack(fmt, rows):
        return b"".join(struct.pack("<" + fmt * len(r), *r) for r in rows)

    bins = [pack("f", P), pack("f", N), pack("f", U), struct.pack("<" + "I" * len(I), *I)]
    views, out, off = [], b"", 0
    for k, b in enumerate(bins):
        pad = (4 - len(b) % 4) % 4
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(b), "target": 34963 if k == 3 else 34962})
        out += b + b"\0" * pad
        off += len(b) + pad
    mn = [min(p[c] for p in P) for c in range(3)]
    mx = [max(p[c] for p in P) for c in range(3)]
    gl = {
        "asset": {"version": "2.0", "generator": "escolha-me dog_head.py"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "cabeca_cachorro", "mesh": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [{"name": "BlackDog", "doubleSided": True, "pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 1}}],
        "buffers": [{"byteLength": len(out)}],
        "bufferViews": views,
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(P), "type": "VEC3", "min": mn, "max": mx},
            {"bufferView": 1, "componentType": 5126, "count": len(N), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(U), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5125, "count": len(I), "type": "SCALAR"},
        ],
    }
    j = json.dumps(gl, separators=(",", ":")).encode()
    j += b" " * ((4 - len(j) % 4) % 4)
    glb = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(out))
    glb += struct.pack("<II", len(j), 0x4E4F534A) + j + struct.pack("<II", len(out), 0x004E4942) + out
    dst = os.path.join(folder, "dog_head.glb")
    open(dst, "wb").write(glb)
    print(f"  cabeça do cachorro: {len(P)} vértices, {len(I) // 3} triângulos -> {dst}")


if __name__ == "__main__":
    main(sys.argv[1])

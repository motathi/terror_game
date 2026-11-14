import json, struct, numpy as np, pygltflib
from scipy.spatial.transform import Rotation as Rot
src = pygltflib.GLTF2().load('hands.glb')
blob = src.binary_blob()
def acc(i):
    A = src.accessors[i]; bv = src.bufferViews[A.bufferView]
    n = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[A.type]
    dt = {5126:np.float32,5123:np.uint16,5121:np.uint8,5125:np.uint32}[A.componentType]
    off = (bv.byteOffset or 0) + (A.byteOffset or 0)
    stride = bv.byteStride or n*np.dtype(dt).itemsize
    raw = np.frombuffer(blob, dtype=np.uint8, count=stride*(A.count-1)+n*np.dtype(dt).itemsize, offset=off)
    return np.stack([np.frombuffer(raw[k*stride:k*stride+n*np.dtype(dt).itemsize].tobytes(), dtype=dt) for k in range(A.count)])
pr = src.meshes[0].primitives[0]
P = acc(pr.attributes.POSITION).astype(float); N = acc(pr.attributes.NORMAL).astype(float)
UV = acc(pr.attributes.TEXCOORD_0).astype(float); J = acc(pr.attributes.JOINTS_0); Wt = acc(pr.attributes.WEIGHTS_0)
I = acc(pr.indices).reshape(-1).astype(np.int64).reshape(-1,3)
joints = [src.nodes[j].name for j in src.skins[0].joints]
dom = J[np.arange(len(J)), Wt.argmax(1)]
isL = np.array([joints[d].endswith('.L') for d in dom])
s = 11.3591651916504
rest = np.c_[P[:,0], P[:,2], -P[:,1]] * s           # Rx(-90) * escala (pose de descanso)
nrest = np.c_[N[:,0], N[:,2], -N[:,1]]
POSE = json.load(open('pose.json'))
img = src.images[0]; bv = src.bufferViews[img.bufferView]
png = blob[(bv.byteOffset or 0):(bv.byteOffset or 0)+bv.byteLength]
open('FPSarm_tex.png','wb').write(png)
for side in ('L','R'):
    p = POSE[side]; e = p['rot']   # [x, y, z] graus, ordem YXZ
    R = Rot.from_euler('YXZ', [e[1], e[0], e[2]], degrees=True)
    m = isL if side == 'L' else ~isL
    tri = I[m[I].all(1)]
    used = np.unique(tri); remap = -np.ones(len(P), int); remap[used] = np.arange(len(used))
    pos = R.apply(rest[used]) + np.array(p['pos'])
    nor = R.apply(nrest[used])
    post = POSE.get('post')  # ajuste fino em espaço de câmera, espelhado para R
    if post:
        sx = 1 if side == 'L' else -1
        c = np.array(post.get('centro', [0.2, -0.45, -0.25])) * [sx, 1, 1]
        Rp = Rot.from_euler('ZYX', [sx * post.get('rz', 0), sx * post.get('ry', 0), post.get('rx', 0)], degrees=True)
        pos = Rp.apply((pos - c) * post.get('esc', 1.0)) + c + np.array(post.get('off', [0, 0, 0])) * [sx, 1, 1]
        nor = Rp.apply(nor)
    pos = pos.astype(np.float32); nor = nor.astype(np.float32)
    uv = UV[used].astype(np.float32); idx = remap[tri].astype(np.uint32).reshape(-1)
    bins = [pos.tobytes(), nor.tobytes(), uv.tobytes(), idx.tobytes(), png]
    offs = np.cumsum([0]+[ (len(b)+3)//4*4 for b in bins])
    data = b''.join(b + b'\0'*((4-len(b)%4)%4) for b in bins)
    g = pygltflib.GLTF2(
        scene=0, scenes=[pygltflib.Scene(nodes=[0])],
        nodes=[pygltflib.Node(name='mao_'+side, mesh=0)],
        meshes=[pygltflib.Mesh(primitives=[pygltflib.Primitive(attributes=pygltflib.Attributes(POSITION=0, NORMAL=1, TEXCOORD_0=2), indices=3, material=0)])],
        materials=[pygltflib.Material(name='mao', pbrMetallicRoughness=pygltflib.PbrMetallicRoughness(baseColorTexture=pygltflib.TextureInfo(index=0), metallicFactor=0, roughnessFactor=1))],
        textures=[pygltflib.Texture(source=0, sampler=0)], samplers=[pygltflib.Sampler(magFilter=9728, minFilter=9728)],
        images=[pygltflib.Image(bufferView=4, mimeType='image/png')],
        buffers=[pygltflib.Buffer(byteLength=len(data))],
        bufferViews=[pygltflib.BufferView(buffer=0, byteOffset=int(offs[k]), byteLength=len(bins[k]), target=(34962 if k<3 else (34963 if k==3 else None))) for k in range(5)],
        accessors=[
          pygltflib.Accessor(bufferView=0, componentType=5126, count=len(pos), type='VEC3', min=pos.min(0).tolist(), max=pos.max(0).tolist()),
          pygltflib.Accessor(bufferView=1, componentType=5126, count=len(nor), type='VEC3'),
          pygltflib.Accessor(bufferView=2, componentType=5126, count=len(uv), type='VEC2'),
          pygltflib.Accessor(bufferView=3, componentType=5125, count=len(idx), type='SCALAR')])
    g.set_binary_blob(data)
    g.save(f'mao_{side}.glb')
    print(side, 'verts', len(pos), 'tris', len(idx)//3, 'bbox', pos.min(0).round(2), pos.max(0).round(2))

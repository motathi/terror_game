import numpy as np, json, sys
from scipy.spatial.transform import Rotation as Rot
tip=np.array([0.55,-0.68,-0.06]); sh=np.array([0.23,0.26,0.0])
def solve(T,S,roll):
    d=tip-sh; D=T-S
    r1,_=Rot.align_vectors([D],[d])
    r=Rot.from_rotvec(D/np.linalg.norm(D)*np.radians(roll))*r1
    pos=T-r.apply(tip)
    e=r.as_euler('YXZ',degrees=True)  # [y, x, z] intrínseco
    return {"rot":[round(e[1],2),round(e[0],2),round(e[2],2)],"pos":[round(float(v),3) for v in pos]}
T=np.array(json.loads(sys.argv[1])); S=np.array(json.loads(sys.argv[2])); roll=float(sys.argv[3])
L=solve(T,S,roll); R={"rot":[L["rot"][0],-L["rot"][1],-L["rot"][2]],"pos":[-L["pos"][0],L["pos"][1],L["pos"][2]]}
print(json.dumps({"L":L,"R":R}))

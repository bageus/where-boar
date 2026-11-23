"""Solves the hunter rig's attack poses (game/features/hunter/public/hunter_rig.gd): for each key, the right or
left arm's upper arm, forearm and hand rotations (model frame, as HunterRig poses) that put the fist (HunterRig.PALM)
at a place and point the held weapon (out of the thumb side of the fist) in a direction, with little wrist bend.
Prints GDScript quaternions to paste into hunter_rig.gd. Needs numpy and scipy. Usage: python tools/solve_arm_poses.py [key...]
"""
import sys, numpy as np
from scipy.spatial.transform import Rotation as Rot
from scipy.optimize import minimize
# Bone rest origins of the bearded hunter (prehistoric_hunter.glb), model space.
B={k:np.array(v) for k,v in {
    "spine": (0.0000, 0.6156, -0.0137),
    "chest": (0.0000, 0.8512, -0.0137),
    "upper_arm.L": (0.4651, 1.0389, -0.0137),
    "forearm.L": (0.6574, 1.0290, -0.0015),
    "hand.L": (0.9477, 1.0199, 0.0144),
    "upper_arm.R": (-0.4651, 1.0389, -0.0137),
    "forearm.R": (-0.6574, 1.0290, -0.0015),
    "hand.R": (-0.9477, 1.0199, 0.0144),
}.items()}
def rx(d): return Rot.from_euler('x',d,degrees=True)
def ry(d): return Rot.from_euler('y',d,degrees=True)
def rz(d): return Rot.from_euler('z',d,degrees=True)
I=Rot.identity()
PALM=0.15
def fk(side, spine, chest, upper, fore, hand):
    """returns palm pos, thumb dir, finger dir, elbow pos"""
    s='.'+side
    chain=[('spine',spine),('chest',chest),('upper_arm'+s,upper),('forearm'+s,fore),('hand'+s,hand)]
    def M(p, upto):
        for name,P in reversed(chain[:upto]):
            o=B[name]; p=o+P.apply(p-o)
        return p
    R=I
    for _,P in chain: R=R*P
    sx=1 if side=='L' else -1
    rest_y=np.array([sx,0,0.]); rest_x=np.array([0,0,1.])*sx  # hand bone rest: Y out along arm, X front (L) / back (R)
    palm=M(B['hand'+s]+rest_y*PALM, 5)
    thumb=R.apply(rest_x*sx)  # thumb faces front for both: +Xb (L) / -Xb (R)
    fingers=R.apply(rest_y)
    return palm, thumb, fingers, M(B['forearm'+s],3), M(B['hand'+s],4)
def solve(side, spine, chest, palm_t, dir_t, fingers_t=None, seed=None, rest_down=True):
    sx=1 if side=='L' else -1
    dir_t=np.array(dir_t)/np.linalg.norm(dir_t)
    def unpack(x):
        up=Rot.from_rotvec(x[0:3]); flex=x[3]; hd=Rot.from_rotvec(x[4:7])
        fore=ry(-flex*sx)  # elbow flexes the forearm toward the front
        return up, fore, hd
    def cost(x):
        up,fore,hd=unpack(x)
        palm,thumb,fing,elbow,wrist=fk(side,spine,chest,up,fore,hd)
        c=40*np.sum((palm-palm_t)**2)+1.5*(1-np.dot(thumb,dir_t))
        if fingers_t is not None: c+=1.5*(1-np.dot(fing,np.array(fingers_t)/np.linalg.norm(fingers_t)))
        c+=0.8*np.dot(x[4:7],x[4:7])  # wrist bends little
        c+=5*max(0,-x[3])**2+5*max(0,x[3]-np.radians(150))**2
        # elbow and fist stay out of the body
        for p in (elbow,wrist,palm):
            if abs(p[0])<0.22 and p[2]<0.2 and 0.6<p[1]<1.25: c+=20*(0.22-abs(p[0]))**2
        return c
    best=None
    seeds=[seed] if seed is not None else []
    rng=np.random.default_rng(1)
    for k in range(14):
        x0=np.concatenate([rng.normal(0,1.2,3),[rng.uniform(0,2.4)],rng.normal(0,0.3,3)]) if k>=len(seeds) else seeds[k]
        r=minimize(cost,x0,method='Nelder-Mead',options={'maxiter':6000,'xatol':1e-5,'fatol':1e-8})
        r=minimize(cost,r.x,method='BFGS')
        if best is None or r.fun<best.fun: best=r
    up,fore,hd=unpack(best.x)
    palm,thumb,fing,elbow,wrist=fk(side,spine,chest,up,fore,hd)
    return dict(cost=best.fun, palm=palm.round(3), thumb=thumb.round(2), fingers=fing.round(2), elbow=elbow.round(3),
        upper=up.as_quat(), fore=fore.as_quat(), hand=hd.as_quat(), flex=np.degrees(best.x[3]).round(1), wrist=np.degrees(np.linalg.norm(best.x[4:7])).round(1))
def gd(q): return "Quaternion(%.3f, %.3f, %.3f, %.3f)"%tuple(q)

keys = {
 # name: side, spine, chest, palm, dir(thumb), fingers
 'club_raised': ('R', rx(-8), ry(-20), [-0.30,1.50,-0.18], [0.1,0.35,-0.95], None),
 'club_struck': ('R', rx(18), ry(15), [-0.18,0.95,0.55], [0.05,-0.35,0.95], None),
 'thrust_low':  ('R', I, I, [-0.33,0.80,0.05], [0.05,0.05,1], None),
 'thrust_jab':  ('R', rx(12), ry(10), [-0.18,0.85,0.62], [0.0,0.05,1], None),
 'spear_raised':('R', rx(-6), ry(-20), [-0.30,1.48,-0.08], [0.05,-0.12,1], None),
 'spear_struck':('R', rx(18), ry(15), [-0.15,1.00,0.55], [0.0,-0.45,0.9], None),
 'bow_aim':     ('L', I, ry(-20), [0.08,1.28,0.68], [0,1,0], [0,0,1]),
 'bow_drawn':   ('R', I, ry(-20), [-0.06,1.32,0.18], [0,1,0], [0.15,0,1]),
 'bow_loose':   ('R', I, ry(-20), [-0.20,1.34,0.02], [0,1,0], [0.3,0.3,1]),
 'bow_nock':    ('R', I, ry(-20), [0.0,1.20,0.45], [0,1,0], None),
}
import sys
for name in (sys.argv[1:] or keys):
    side,sp,ch,p,d,f=keys[name]
    r=solve(side,sp,ch,np.array(p),d,f)
    print(name, 'cost %.4f'%r['cost'], 'palm',r['palm'],'thumb',r['thumb'],'fing',r['fingers'],'elbow',r['elbow'],'flex',r['flex'],'wrist',r['wrist'])
    s='.'+side
    print('   "upper_arm%s": %s, "forearm%s": %s, "hand%s": %s'%(s,gd(r['upper']),s,gd(r['fore']),s,gd(r['hand'])))

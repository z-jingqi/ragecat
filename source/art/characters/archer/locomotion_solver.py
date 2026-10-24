"""Continuous adult foot/cloth pose solver. No frame-rate dependent motion.
Anatomical rest bones remain unchanged; upper spine/chest anchors stay exact.
"""
import math
from mathutils import Matrix,Vector
def solve_two_bone(shoulder, wrist, upper_length, forearm_length, pole, bend_gap=0.0008):
    """No-stretch analytic two-bone IK. Returns elbow, achieved wrist, reach error.
    shoulder/wrist/pole accept vectors or coordinate lists. bend_gap uses the same
    units as lengths. Actual target joints, not source chibi lengths, determine IK.
    """
    S,W,P=Vector(shoulder),Vector(wrist),Vector(pole)
    delta=W-S
    if delta.length < 1e-9:
        delta=Vector((0,-1,0))*1e-9
    requested=delta.length;d=delta.normalized()
    distance=max(abs(upper_length-forearm_length)+bend_gap,min(upper_length+forearm_length-bend_gap,requested))
    along=(upper_length**2-forearm_length**2+distance**2)/(2*distance)
    rise=math.sqrt(max(0,upper_length**2-along**2))
    p=P-S;p=p-d*p.dot(d)
    if p.length<1e-9:
        p=d.cross(Vector((0,0,1)))
        if p.length<1e-9:p=d.cross(Vector((1,0,0)))
    elbow=S+d*along+p.normalized()*rise
    achieved=S+d*distance
    return elbow,achieved,(achieved-W).length

def matrix_at(rotation,position):
    m=rotation.to_4x4();m.translation=Vector(position);return m

def stable_pose_basis(target_pose_matrix,bone_rest_matrix,parent_target_pose_matrix=None,parent_rest_matrix=None):
    """Convert desired ARMATURE-space matrix to matrix_basis without stale depsgraph
    reads. Pass the desired parent matrix from the same frame, not pb.parent.matrix
    immediately after changing it. Assumes normal/full bone transform inheritance.
    """
    if parent_target_pose_matrix is None:
        return bone_rest_matrix.inverted()@target_pose_matrix
    return bone_rest_matrix.inverted()@parent_rest_matrix@parent_target_pose_matrix.inverted()@target_pose_matrix

def transport_segment(rest_matrix,rest_head,rest_tail,new_head,new_tail):
    """Rigid bone orientation preserving rest roll by shortest-arc transport."""
    old=(Vector(rest_tail)-Vector(rest_head)).normalized()
    new=(Vector(new_tail)-Vector(new_head)).normalized()
    R=old.rotation_difference(new).to_matrix()@rest_matrix.to_3x3()
    return matrix_at(R,new_head)



def smooth(x):
 x=max(0,min(1,x));return x*x*(3-2*x)
def cyclic_foot(q,stride=1.95,duty=.32):
 q%=1;stroke=stride*duty
 if q<duty:
  u=q/duty;return stroke/2-stride*q,0,math.radians(10)*smooth((u-.75)/.25),'flat' if u<=.75 else 'toe_off'
 u=(q-duty)/(1-duty);a=-stroke/2;b=stroke/2;m=-stride*(1-duty)
 p=(2*u**3-3*u*u+1)*a+(u**3-2*u*u+u)*m+(-2*u**3+3*u*u)*b+(u**3-u*u)*m
 return p,.18*math.sin(math.pi*u)**1.5,math.radians(10)*(1-smooth(u/.28))-math.radians(8)*math.sin(math.pi*u)**2,'swing'

def solve_motion(ctx,travel,phase,idle=False):
 R,B,L,H,CORE,R0,sole=ctx['R'],ctx['B'],ctx['L'],ctx['H'],ctx['CORE'],ctx['R0'],ctx['sole']
 bodyforward=R0@Vector((0,-1,0));bodylateral=R0@Vector((1,0,0));D=Vector(travel).normalized();angle=math.atan2(D.dot(bodylateral),D.dot(bodyforward))
 # Side-facing lower body, upper chest/shoulder world matrices unchanged. Backward
 # motion remains backward stepping, never a 180-degree inverted knee pole.
 facing=angle if abs(angle)<=math.pi/2 else angle-math.copysign(math.pi,angle)
 footyaw=facing*.84;hipyaw=facing*.50;sidefactor=math.sin(angle)**2
 stride=1.95-.15*sidefactor;extra_crouch=.015*sidefactor
 if idle:footyaw=hipyaw=0;extra_crouch=0
 # Keep hips tail / spine attachment EXACT. Rotating around hips head would break
 # the fixed torso chain; pivoting around its tail preserves every bone length.
 top=H@Vector((0,L['hips'],0));Q=Matrix.Translation(top)@Matrix.Rotation(hipyaw,4,'Z')@Matrix.Translation(-top);hip=Q@H
 yawR=Matrix.Rotation(footyaw,3,'Z');footbase=R0@yawR;lane=footbase@Vector((1,0,0));facingforward=footbase@Vector((0,-1,0));pelvisR=Q.to_3x3()@R0
 bob=Vector() if idle else lane*(.01*math.sin(2*math.pi*phase))+Vector((0,0,-.064+.025*math.cos(4*math.pi*(phase-.425))-extra_crouch))
 M={n:m.copy() for n,m in CORE.items()};M['hips']=hip;M['root']=ctx['CROOT'].copy();feet={};reach={};angles={}
 for s,sg,shift in [('l',1,0),('r',-1,.5)]:
  p,lift,pitch,mode=(0,0,0,'flat') if idle else cyclic_foot(phase+shift,stride)
  pitchR=Matrix.Rotation(pitch,3,'X');footR=footbase@pitchR;minsole=min((pitchR@v).z for v in sole[s]);height=-minsole+lift;toe=min(sole[s],key=lambda v:v.y);correction=toe-pitchR@toe;correction.z=0
  actual=R0@Vector((.0111724,0,0))+lane*(sg*(.125+.035*sidefactor))+D*p+Vector((0,0,height))+footbase@correction
  A=actual-bob;S=hip@R['hips'].inverted()@B['thigh.'+s][0];pole=S+facingforward*.8+lane*(sg*.05)
  E,W,err=solve_two_bone(S,A,L['thigh.'+s],L['shin.'+s],pole,bend_gap=.004);reach[s]=err
  M['thigh.'+s]=transport_segment(R['thigh.'+s],*B['thigh.'+s],S,E);M['shin.'+s]=transport_segment(R['shin.'+s],*B['shin.'+s],E,W);M['foot.'+s]=matrix_at(footR@R['foot.'+s].to_3x3(),W)
  lowest=min([W+bob+footR@v for v in sole[s]],key=lambda v:v.z);angles[s]=math.atan2((E-S).dot(pelvisR@Vector((0,-1,0))),S.z-E.z)
  feet[s]={'mode':mode,'ankle':list(W+bob),'lowest_sole':list(lowest),'virtual_world_sole':list(lowest+D*(stride*phase)),'pitch_deg':math.degrees(pitch),'phase':(phase+shift)%1,'reach_error_m':err}
 for q in ctx['chains']:
  hM=hip@R['hips'].inverted();sg=q['side'];s='l' if sg>0 else 'r';direction=-1 if q['front'] else 1
  push=max(0,angles[s] if q['front'] else -angles[s]);is_ribbon=q['name'].startswith('Scarlet');amp=0 if idle else min(.65,(.23 if is_ribbon else .15)+push*(.85 if is_ribbon else 1.10));flutter=0 if idle else .035*math.sin(2*math.pi*phase+(0 if sg>0 else math.pi)-.5)
  local=Matrix.Rotation(direction*amp+flutter,3,'X')@Matrix.Rotation(0 if idle else sg*.055,3,'Y');wr=pelvisR@local@pelvisR.transposed();a=hM@q['a'];b=a+wr@(hM.to_3x3()@(q['b']-q['a']));tip=Matrix.Rotation(0 if idle else direction*(amp*.28)+.025*math.sin(2*math.pi*phase-.8),3,'X');wt=pelvisR@tip@pelvisR.transposed();c=b+wt@wr@(hM.to_3x3()@(q['c']-q['b']))
  M[q['names'][0]]=transport_segment(R[q['names'][0]],q['a'],q['b'],a,b);M[q['names'][1]]=transport_segment(R[q['names'][1]],q['b'],q['c'],b,c)
 return {'bones':M,'bob':bob,'feet':feet,'reach':reach,'stride_m':stride,'pelvis_yaw_deg':math.degrees(hipyaw),'foot_yaw_deg':math.degrees(footyaw),'travel_direction':D,'phase':phase,'pelvis_rotation':pelvisR,'idle':idle}

import bpy
from mathutils.bvhtree import BVHTree

def make_context(rig,idle_packet):
 R={b.name:b.matrix_local.copy() for b in rig.data.bones};B={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in rig.data.bones};L={b.name:b.length for b in rig.data.bones};CORE={n:Matrix(m) for n,m in idle_packet['bones'].items()};H=CORE['hips'];CROOT=CORE['root'];R0=CROOT.to_3x3()@R['root'].to_3x3().inverted();coats=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('independent_coat_panel')];chains=[];bases={};groups={};keys={};outlocals={}
 for o in coats:
  names=sorted([g.name for g in o.vertex_groups if g.name.startswith('cloth_')],key=lambda n:0 if n.endswith('_upper') else 1);a,b,c=B[names[0]][0],B[names[0]][1],B[names[1]][1];side=1 if (a.x+c.x)>0 else -1;front=(a.y+c.y)<0;chains.append({'name':o.name,'names':names,'a':a,'b':b,'c':c,'side':side,'front':front});bases[o.name]=[v.co.copy() for v in o.data.shape_keys.key_blocks['Basis'].data];groups[o.name]=[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices];keys[o.name]=o.data.shape_keys.key_blocks['Runtime_leg_clearance'];outlocals[o.name]=Vector((side,0,0)) if 'side' in str(o.get('bone_part','')) else Vector((0,-1 if front else 1,0))
 sole={s:[v.co-B['foot.'+s][0] for pre in ['Stitched_boot_outsole_','Structured_boot_block_heel_'] for v in bpy.data.objects[pre+cap].data.vertices] for s,cap in [('l','L'),('r','R')]}
 return dict(R=R,B=B,L=L,CORE=CORE,H=H,CROOT=CROOT,R0=R0,coats=coats,chains=chains,bases=bases,groups=groups,keys=keys,outlocals=outlocals,sole=sole,rig=rig,pants=bpy.data.objects['Loose_dark_bloused_trousers_CC0'])
def geometry(ob):
 ev=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();vs=[ev.matrix_world@v.co for v in me.vertices];fs=[tuple(p.vertices) for p in me.polygons];attr=me.attributes.get('PanelLengthFraction');param=[v.value for v in attr.data] if attr else None;ev.to_mesh_clear();return vs,fs,param

def apply_pose(ctx,row,correct=True):
 rig=ctx["rig"];R=ctx["R"];coats=ctx["coats"];keys=ctx["keys"];bases=ctx["bases"];groups=ctx["groups"];outlocals=ctx["outlocals"];pants=ctx["pants"]
 M=row['bones']
 for n,m in M.items():
  pb=rig.pose.bones[n];par=pb.parent.name if pb.parent else None;pb.rotation_mode='QUATERNION';pb.matrix_basis=stable_pose_basis(m,R[n],M[par] if par else None,R[par] if par else None)
 for o in coats:keys[o.name].value=0
 bpy.context.view_layer.update()
 stats={'max_correction_m':0,'corrected_vertices':0};skinmats={}
 if correct:
  vs,fs,_=geometry(pants);bvh=BVHTree.FromPolygons(vs,fs);D={n:m@R[n].inverted() for n,m in M.items()}
  for o in coats:
   direction=row['pelvis_rotation']@outlocals[o.name];mats=[];worlds=[];need=[]
   for org,w in zip(bases[o.name],groups[o.name]):
    mat=Matrix([[0.0]*4 for _ in range(4)])
    for n,weight in w.items():mat+=D[n]*weight
    world=mat@org;hit=bvh.ray_cast(world+direction*.9,-direction,1.8);push=0
    if hit[0] is not None and world.z<1.075:push=max(0,(hit[0]+direction*.020-world).dot(direction))
    mats.append(mat);worlds.append(world);need.append(push)
   assert len(worlds)==667
   rp=[max(need[r*23:(r+1)*23]) for r in range(29)];safe=[max(rp[max(0,r-1):min(29,r+2)]) for r in range(29)];sm=[max(safe[r],sum(safe[max(0,r-1):min(29,r+2)])/len(safe[max(0,r-1):min(29,r+2)])) for r in range(29)]
   for i,(v,mat) in enumerate(zip(worlds,mats)):
    # Waist attachments stay authored; concealed first rows may overlap sewn pants.
    t=(i//23)/28;weight=min(1,t/.14);push=sm[i//23]*weight;keys[o.name].data[i].co=mat.inverted_safe()@(v+direction*push);stats['max_correction_m']=max(stats['max_correction_m'],push);stats['corrected_vertices']+=push>1e-6
   keys[o.name].value=1;skinmats[o.name]=mats
  # Subdivision can bow a span back through trousers even when authored sample
  # vertices pass ray tests. Resolve only actual free-panel overlap rows locally.
  for attempt in range(3):
   bpy.context.view_layer.update();remaining=0
   for o in coats:
    ov,of,param=geometry(o);pairs=BVHTree.FromPolygons(ov,of).overlap(bvh);bad=set()
    for a,b in pairs:
     t=sum(param[i] for i in of[a])/len(of[a]) if param else 0
     if t>.25:bad.add(round(t*28))
    if not bad:continue
    remaining+=len(bad);direction=row['pelvis_rotation']@outlocals[o.name]
    for i,kp in enumerate(keys[o.name].data):
     dist=min(abs(i//23-r) for r in bad);push=.02*max(0,1-dist/3)
     if push>0:kp.co+=skinmats[o.name][i].inverted_safe().to_3x3()@(direction*push)
   if not remaining:break
 bpy.context.view_layer.update();return stats

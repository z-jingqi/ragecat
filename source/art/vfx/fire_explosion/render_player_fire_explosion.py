"""Original pressure-burst fire volume, authored for RageCat.
Rebuild: blender -b --factory-startup -t 2 --python render_player_fire_explosion.py -- --out DIR
No external textures, no alpha cards, no bloom. A single Cycles volume material
contains unequal curved pressure jets, turbulent density, and cooling heat.
The saved .blend is fully editable and all 24 frames are keyframed.
"""
import bpy, math, os, sys, argparse
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--samples',type=int,default=32);p.add_argument('--size',type=int,default=256);p.add_argument('--ortho',type=float,default=2.5);p.add_argument('--frames',default='all');p.add_argument('--save',action='store_true');p.add_argument('--stop-file',default='');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
os.makedirs(a.out,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=a.samples;s.cycles.use_denoising=False;s.cycles.volume_step_rate=.4;s.cycles.volume_preview_step_rate=.8;s.cycles.volume_max_steps=512;s.cycles.max_bounces=6;s.cycles.volume_bounces=2
s.render.resolution_x=a.size;s.render.resolution_y=a.size;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8';s.render.fps=72;s.frame_start=1;s.frame_end=24
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.world.color=(.005,.005,.005)
bpy.ops.object.camera_add(location=(0,0,8));cam=bpy.context.object;cam.name='Front orthographic atlas camera';cam.data.type='ORTHO';cam.data.ortho_scale=a.ortho;s.camera=cam
# One bounded domain, not overlapping sphere objects.
bpy.ops.mesh.primitive_cube_add(size=4.0);ob=bpy.context.object;ob.name='Turbulent fire volume domain';ob.scale=(.60,.60,.18)
mat=bpy.data.materials.new('Pressure jets | turbulent density + thermal emission');mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
ob.data.materials.append(mat)

def mathnode(op,*ins,name=None):
 node=n.new('ShaderNodeMath');node.operation=op
 if name:node.name=name;node.label=name
 for i,x in enumerate(ins):
  if isinstance(x,(int,float)):node.inputs[i].default_value=x
  else:l.new(x,node.inputs[i])
 return node.outputs[0]
def vec(op,*ins):
 node=n.new('ShaderNodeVectorMath');node.operation=op
 for i,x in enumerate(ins):
  if isinstance(x,(tuple,list)):node.inputs[i].default_value=x
  elif isinstance(x,(int,float)):node.inputs[3].default_value=x
  else:l.new(x,node.inputs[i])
 return node.outputs['Value'] if op in ['DOT_PRODUCT','LENGTH','DISTANCE'] else node.outputs['Vector']
def ramp(value,stops,name):
 node=n.new('ShaderNodeValToRGB');node.name=name;node.label=name;node.color_ramp.interpolation='EASE';node.color_ramp.elements.remove(node.color_ramp.elements[1])
 for i,(pos,color) in enumerate(stops):
  el=node.color_ramp.elements[0] if not i else node.color_ramp.elements.new(pos);el.position=pos;el.color=color
 l.new(value,node.inputs[0]);return node.outputs['Color']
def grey(x):return (x,x,x,1)
def val(name,values):
 node=n.new('ShaderNodeValue');node.name=name;node.label=name
 for frame,value in enumerate(values,1):node.outputs[0].default_value=value;node.outputs[0].keyframe_insert('default_value',frame=frame)
 return node.outputs[0]
def noise(position,scale,detail,rough=.65,dist=.1):
 node=n.new('ShaderNodeTexNoise');node.inputs['Scale'].default_value=scale;node.inputs['Detail'].default_value=detail;node.inputs['Roughness'].default_value=rough;node.inputs['Distortion'].default_value=dist;l.new(position,node.inputs['Vector']);return node

ts=[i/23 for i in range(24)]
age=val('Normalized burst age',ts)
# Immediate ignition with quick ballistic expansion, followed by fast cooling.
expansion=[.38+.70*(1-math.exp(-t*17)) for t in ts]
opacity=[max(0,1-t/.77)**.65 for t in ts]
exp=val('Pressure expansion',expansion);cool=val('Cooling / density collapse',opacity)
geo=n.new('ShaderNodeNewGeometry');pos=geo.outputs['Position']
adv=n.new('ShaderNodeCombineXYZ');l.new(mathnode('MULTIPLY',age,.23),adv.inputs['X']);l.new(mathnode('MULTIPLY',age,-.8),adv.inputs['Y']);l.new(mathnode('MULTIPLY',age,.45),adv.inputs['Z']);flow=vec('ADD',pos,adv.outputs[0])
warp=noise(flow,2.8,3,.7,.35)
micro=noise(flow,11.5,3,.72,.25)
warped=vec('ADD',vec('ADD',pos,vec('SCALE',vec('SUBTRACT',warp.outputs['Color'],(.5,.5,.5)),.24)),vec('SCALE',vec('SUBTRACT',micro.outputs['Color'],(.5,.5,.5)),.095))
fine=noise(flow,13.0,2.5,.7,.2);fold=noise(flow,5.3,3,.68,.3)
# Unequal, non-repeating jets. Entries: angle, reach, girth, bend, birth, death.
jets=[(9,.84,.235,.08,0,.31),(88,.67,.22,-.06,0,.27),(154,.96,.25,-.10,0,.39),(215,.76,.225,.10,0,.29),(279,.87,.24,-.07,0,.35),(333,.69,.21,.08,0,.27),(43,.64,.19,-.05,.03,.24),(124,.72,.21,.04,.02,.29)]
fields=[];thermal_fields=[]
for i,(ang,reach,girth,bend,birth,death) in enumerate(jets):
 theta=math.radians(ang);dc=n.new('ShaderNodeCombineXYZ');pc=n.new('ShaderNodeCombineXYZ')
 for k,t in enumerate(ts,1):
  turn=theta+.16*(math.sin(t*6+i)-math.sin(i));dc.inputs['X'].default_value=math.cos(turn);dc.inputs['Y'].default_value=math.sin(turn);pc.inputs['X'].default_value=-math.sin(turn);pc.inputs['Y'].default_value=math.cos(turn)
  for nd in [dc,pc]:
   for channel in ['X','Y']:nd.inputs[channel].keyframe_insert('default_value',frame=k)
 d=dc.outputs[0];perp=pc.outputs[0]
 # Later frames drift away from center rather than forming a shrinking disk.
 detach=val(f'Jet {i+1} separation',[max(0,t-.13)*(.48+(i%3)*.07) for t in ts])
 # Vector Math scale takes vector then scalar; use input link explicitly.
 offset=n.new('ShaderNodeVectorMath');offset.operation='SCALE';l.new(d,offset.inputs[0]);l.new(detach,offset.inputs[3]);q=vec('SUBTRACT',warped,offset.outputs[0])
 length=mathnode('MULTIPLY',exp,reach)
 u=mathnode('DIVIDE',vec('DOT_PRODUCT',q,d),length)
 uc=mathnode('MINIMUM',mathnode('MAXIMUM',u,0),1)
 curve=mathnode('ADD',mathnode('MULTIPLY',mathnode('SINE',mathnode('MULTIPLY',uc,math.pi)),bend),mathnode('MULTIPLY',mathnode('POWER',uc,2),-.2*bend))
 cross=mathnode('SUBTRACT',vec('DOT_PRODUCT',q,perp),mathnode('MULTIPLY',curve,exp))
 taper=mathnode('MULTIPLY',mathnode('POWER',mathnode('MAXIMUM',mathnode('SUBTRACT',1,uc),.001),.8),mathnode('ADD',.62,mathnode('MULTIPLY',mathnode('SINE',mathnode('MULTIPLY',uc,math.pi)),.55)))
 width=mathnode('MULTIPLY',mathnode('MULTIPLY',exp,girth),mathnode('MAXIMUM',taper,.015))
 z=vec('DOT_PRODUCT',q,(0,0,1))
 qrad=mathnode('ADD',mathnode('POWER',mathnode('DIVIDE',cross,width),2),mathnode('POWER',mathnode('DIVIDE',z,mathnode('MULTIPLY',width,.72)),2))
 radial=mathnode('MAXIMUM',mathnode('SUBTRACT',1,qrad),0)
 axial=mathnode('MULTIPLY',mathnode('GREATER_THAN',u,-.03),mathnode('LESS_THAN',u,1))
 # Fine turbulent erosion cuts irregular holes and broken tips into the volume.
 erode=mathnode('ADD',mathnode('MULTIPLY',fold.outputs['Fac'],.7),mathnode('MULTIPLY',fine.outputs['Fac'],.3))
 eroded=mathnode('MAXIMUM',mathnode('SUBTRACT',radial,mathnode('MULTIPLY',mathnode('SUBTRACT',1,erode),mathnode('ADD',.52,mathnode('MULTIPLY',age,1.55)))),0)
 life=val(f'Jet {i+1} cooling',[max(0,1-max(0,t-birth)/death)**1.1 for t in ts])
 thermal_fields.append(mathnode('MULTIPLY',radial,axial))
 field=mathnode('MULTIPLY',mathnode('MULTIPLY',eroded,axial),life)
 fields.append(field)
# The pressure body owns two-thirds of the peak silhouette. Its unequal
# internal folds separate and erode independently, rather than stretching
# into long arms or fading as one orange ball.
bodyexp=val('Pressure folds thinning',[expansion[k]*(1-.42*t) for k,t in enumerate(ts)])
folds=[(-.18,.13,.45,.39,.30,.30),(.20,.07,.43,.33,.26,.35),(.07,-.22,.36,.45,.30,.28),(-.18,-.18,.32,.31,.25,.25),(.15,.22,.27,.34,.22,.31)]
for j,(cx,cy,rx,ry,rz,life_end) in enumerate(folds):
 center=n.new('ShaderNodeCombineXYZ');l.new(val(f'Pressure fold {j+1} X',[cx*(expansion[k]+max(0,t-.09)*2.9) for k,t in enumerate(ts)]),center.inputs['X']);l.new(val(f'Pressure fold {j+1} Y',[cy*(expansion[k]+max(0,t-.09)*2.9) for k,t in enumerate(ts)]),center.inputs['Y'])
 q=vec('SUBTRACT',warped,center.outputs[0]);qs=vec('DIVIDE',q,(rx,ry,rz));bodyrad=mathnode('MAXIMUM',mathnode('SUBTRACT',1,mathnode('POWER',mathnode('DIVIDE',vec('LENGTH',qs),bodyexp),2)),0)
 erosion=mathnode('MULTIPLY',mathnode('SUBTRACT',1,fold.outputs['Fac']),mathnode('ADD',.47,mathnode('MULTIPLY',age,3.1)))
 raw=mathnode('MAXIMUM',mathnode('SUBTRACT',bodyrad,erosion),0)
 blife=val(f'Pressure fold {j+1} life',[max(0,1-t/life_end)**.63 for t in ts]);fields.append(mathnode('MULTIPLY',raw,blife));thermal_fields.append(bodyrad)

field=fields[0]
for f in fields[1:]:field=mathnode('MAXIMUM',field,f)
# Compact core only lives for the first 1/5, never a giant white glow disk.
r=vec('LENGTH',warped)
core_radius=val('Small core radius',[.13+.16*math.exp(-((t-.09)/.08)**2) for t in ts])
core=mathnode('MAXIMUM',mathnode('SUBTRACT',1,mathnode('DIVIDE',r,core_radius)),0)
core_gain=val('Core heat pulse',[max(0,1-t/.23)**.7 for t in ts]);core=mathnode('MULTIPLY',core,core_gain)
field=mathnode('MAXIMUM',field,core)
# Density and heat are distinct. Outer cool folds absorb some bright interior.
density=mathnode('MULTIPLY',field,18.0)
thermal=thermal_fields[0]
for tf in thermal_fields[1:]:thermal=mathnode('MAXIMUM',thermal,tf)
heat=mathnode('SUBTRACT',mathnode('ADD',mathnode('MULTIPLY',mathnode('POWER',thermal,2.3),.84),mathnode('MULTIPLY',fine.outputs['Fac'],.12)),mathnode('MULTIPLY',age,.13))
heat=mathnode('ADD',heat,mathnode('MULTIPLY',core,.66))
colors=ramp(heat,[(0,(.065,.001,.0001,1)),(.16,(.25,.007,.0002,1)),(.33,(.8,.045,.001,1)),(.46,(1,.18,.008,1)),(.61,(1,.46,.065,1)),(.78,(1,.77,.30,1)),(.95,(1,.92,.66,1))],'Volumetric thermal structure')
volume=n.new('ShaderNodeVolumePrincipled');volume.name='Depth shaded emitting fire';volume.inputs['Color'].default_value=(.14,.058,.024,1);volume.inputs['Anisotropy'].default_value=.18;l.new(density,volume.inputs['Density']);l.new(colors,volume.inputs['Emission Color']);l.new(mathnode('MULTIPLY',mathnode('POWER',field,1.05),22),volume.inputs['Emission Strength'])
# Extinction supports a readable alpha edge without a black smoke halo.
out=n.new('ShaderNodeOutputMaterial');l.new(volume.outputs[0],out.inputs['Volume'])
# Five short-lived irregular ember volumes, staying subordinate to the burst.
# Mesh flecks are original curved shards rather than generic star particles.
for j,(angle,speed,life) in enumerate([(32,1.4,.74),(126,1.15,.91),(205,1.2,.66),(275,1.27,.81),(337,1.0,.61)]):
 theta=math.radians(angle);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1);e=bpy.context.object;e.name=f'Cooling ember {j+1}';m=bpy.data.materials.new(f'Ember heat {j+1}');m.use_nodes=True;nn=m.node_tree.nodes;nn.clear();em=nn.new('ShaderNodeEmission');em.inputs[0].default_value=(1,.22,.008,1);oo=nn.new('ShaderNodeOutputMaterial');m.node_tree.links.new(em.outputs[0],oo.inputs[0]);e.data.materials.append(m)
 for k,t in enumerate(ts,1):
  travel=.18+t*speed;e.location=(math.cos(theta)*travel,math.sin(theta)*travel+.10*t*t,.05);vis=max(0,math.sin(min(1,max(0,(t-.13)/(life-.13)))*math.pi)) if .13<t<life else 0;size=(.017-j*.001)*vis;e.scale=(size*.6,size*(1.35 if j%2 else .9),size);e.rotation_euler[2]=theta+t*3;e.keyframe_insert('location',frame=k);e.keyframe_insert('scale',frame=k);e.keyframe_insert('rotation_euler',frame=k)
# Linear interpolation preserves the authored fast envelope.
for action in bpy.data.actions:
 for fc in action.fcurves:
  for kp in fc.keyframe_points:kp.interpolation='LINEAR'
for frame,t in enumerate(ts,1):
 ob.hide_render=t>=.40;ob.keyframe_insert('hide_render',frame=frame)
s.frame_set(5)
# Arrange the editable material nodes by node order for discovery.
for i,node in enumerate(n):node.location=((i%12)*210,-(i//12)*170)
if a.save:
 blend_path=os.path.join(os.path.dirname(a.out),'source','player_fire_explosion.blend')
 os.makedirs(os.path.dirname(blend_path),exist_ok=True)
 bpy.ops.wm.save_as_mainfile(filepath=blend_path,compress=True)
frames=range(24) if a.frames=='all' else [int(x) for x in a.frames.split(',')]
for i in frames:
 if a.stop_file and os.path.exists(a.stop_file):break
 s.frame_set(i+1);s.render.filepath=os.path.join(a.out,f'{i:03d}.png');bpy.ops.render.render(write_still=True)

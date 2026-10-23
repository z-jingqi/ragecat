"""Deterministic Blender 4.3+ VFX source. Render RGBA frames; pack with pack_assets.py.
Usage: blender -b -t 2 -P render_assets.py -- --output /tmp/stone_arcane/frames [--sample]
"""
import bpy, math, random, argparse, sys, os
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--sample',action='store_true');p.add_argument('--effect',default='all');a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
S=bpy.context.scene
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
S.render.engine='CYCLES';S.cycles.samples=48;S.cycles.use_denoising=False;S.cycles.transparent_max_bounces=64
S.render.resolution_x=S.render.resolution_y=256;S.render.resolution_percentage=100
S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.render.film_transparent=True
S.view_settings.view_transform='Standard';S.view_settings.look='Medium High Contrast';S.view_settings.exposure=0;S.view_settings.gamma=1
S.world.color=(.04,.04,.05)
bpy.ops.object.camera_add(location=(0,0,8));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=6.8;cam.rotation_euler=(0,0,0);S.camera=cam
for pos,power,size in [((-3,-4,6),700,5),((4,2,4),250,4)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
BASE=set(bpy.data.objects)
M={}
def mat(name,c,alpha=1,diff=False,soft=False):
 key=(name,round(alpha,3));
 if key in M:return M[key]
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links
 out=n.new('ShaderNodeOutputMaterial');mix=n.new('ShaderNodeMixShader');tr=n.new('ShaderNodeBsdfTransparent');shader=n.new('ShaderNodeBsdfDiffuse' if diff else 'ShaderNodeEmission');shader.inputs['Color'].default_value=(*c,1)
 l.new(tr.outputs[0],mix.inputs[1]);l.new(shader.outputs[0],mix.inputs[2]);mix.inputs[0].default_value=alpha
 if soft:
  tc=n.new('ShaderNodeTexCoord');dist=n.new('ShaderNodeVectorMath');dist.operation='DISTANCE';dist.inputs[1].default_value=(.5,.5,0);l.new(tc.outputs['UV'],dist.inputs[0]);r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.05;r.color_ramp.elements[0].color=(alpha,alpha,alpha,1);r.color_ramp.elements[1].position=.5;r.color_ramp.elements[1].color=(0,0,0,1);l.new(dist.outputs['Value'],r.inputs[0]);l.new(r.outputs[0],mix.inputs[0])
 l.new(mix.outputs[0],out.inputs[0]);M[key]=m;return m
def disc(x,y,r,c,alpha,z=0):
 bpy.ops.mesh.primitive_plane_add(size=2,location=(x,y,z));o=bpy.context.object;o.scale=(r,r,1);o.data.materials.append(mat('soft'+str(c),c,alpha,soft=True));return o
def rock(x,y,z,scale,seed,alpha=1):
 rr=random.Random(seed);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=scale,location=(x,y,z));o=bpy.context.object
 for v in o.data.vertices:v.co*=rr.uniform(.75,1.25)
 o.scale=(1,.7,1.1);o.rotation_euler=[rr.random()*6 for _ in range(3)];o.data.materials.append(mat('stone',(.33,.28,.22),alpha,True));return o
def ribbon(points,width,c,alpha=1):
 verts=[]
 for i,p0 in enumerate(points):
  prev=Vector(points[max(0,i-1)]);nxt=Vector(points[min(len(points)-1,i+1)]);d=nxt-prev;side=Vector((-d.y,d.x,0)).normalized()*width*(.3+.7*math.sin(math.pi*i/max(1,len(points)-1)))
  verts.extend([Vector(p0)+side,Vector(p0)-side])
 me=bpy.data.meshes.new('ribbon');me.from_pydata(verts,[],[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)]);me.update();o=bpy.data.objects.new('ribbon',me);S.collection.objects.link(o);o.data.materials.append(mat('ribbon'+str(c),c,alpha));return o
def arc(rad,start,length,w,col,alpha,z=0,phase=0):
 pts=[]
 for j in range(33):
  t=j/32;ang=start+length*t;r=rad*(1+.07*math.sin(ang*5+phase));pts.append((math.cos(ang)*r,math.sin(ang)*r,z))
 return ribbon(pts,w,col,alpha)
def build(kind,t):
 rr=random.Random(713);fade=max(0,1-t)
 if kind in ('stone_impact','charge_dust'):
  for k in range(17):
   ang=rr.random()*math.tau;r=(.1+rr.random()*2.2)*(t**.55);x=math.cos(ang)*r;y=math.sin(ang)*r
   if kind=='charge_dust':x=-1.7*t+rr.uniform(-.6,.6);y=rr.uniform(-.6,.6)*(t+.3)
   disc(x,y,.25+rr.random()*.5+t*.42,(.50,.39,.27),fade**1.6*.65,z=-.1+k*.001)
  for k in range(15):
   ang=rr.random()*math.tau;r=(.7+rr.random()*2.2)*t**.6;sz=rr.uniform(.04,.18)*(1-.65*t);rock(math.cos(ang)*r,math.sin(ang)*r,.1+math.sin(t*math.pi)*rr.uniform(.1,.5),sz,k,fade**.5)
  if kind=='stone_impact':
   for k in range(8):arc(.2+t*2.4,k*math.tau/8,.35,.025,(.84,.65,.38),fade**3,.3)
 elif kind=='stone_fall':
  o=rock(0,0,.3,.82,9,1);o.rotation_euler.z+=t*1.3
  for k in range(5):
   x=rr.uniform(-.5,.5);ribbon([(x,-.1,.1),(x+.1,-.6,.1),(x+.2,-1.5-rr.random(),.1)],.05,(.72,.55,.31),.3)
 elif kind=='energy_orb':
  ph=t*math.tau
  disc(0,0,1.7,(.29,.16,.9),.38)
  disc(0,0,.7,(.32,.55,1),.6,.1)
  for k in range(7):
   start=k*math.tau/7+ph*(1 if k%2 else -1);r=.6+.12*k;arc(r,start,1.7,.045,(.55,.34,1),.85,.2,ph)
  rock(0,0,.3,.3,13);disc(0,0,.44,(.81,.91,1),1,.7)
  for k in range(8):
   ang=k*math.tau/8+ph;r=1.25+.1*math.sin(ph+k);disc(math.cos(ang)*r,math.sin(ang)*r,.10,(.6,.74,1),.9,.4)
 elif kind=='summon':
  ph=t*math.tau;strength=math.sin(math.pi*t)**.6
  disc(0,0,2,(.32,.17,.76),strength*.25)
  for k in range(8):
   ang=k*math.tau/8;arc(1.65,ang+ph*.1,.45,.035,(.51,.36,1),strength,.1)
   p0=Vector((math.cos(ang),math.sin(ang),0));p1=Vector((math.cos(ang+.14),math.sin(ang+.14),0));pts=[tuple(p0*.9+Vector((0,0,.3))),tuple(p1*1.4+Vector((0,0,.3))),tuple(p0*1.9+Vector((0,0,.3)))];ribbon(pts,.04,(.65,.48,1),strength)
  for k in range(12):
   ang=k*math.tau/12+ph*.3;r=(1-t)*1.4+.25;disc(math.cos(ang)*r,math.sin(ang)*r,.07,(.8,.75,1),strength,.5)
  disc(0,0,.3+t*.6,(.76,.7,1),max(0,1-abs(t-.75)*5)*.7,.6)
 elif kind=='lightning_impact':
  disc(0,0,.5+t*1.5,(.23,.38,1),fade**2*.4)
  for k in range(9):
   ang=k*math.tau/9+rr.uniform(-.15,.15);r=(.5+rr.random()*1.8)*(.3+.7*t);pts=[]
   for j in range(6):
    d=r*j/5;off=rr.uniform(-.16,.16)*math.sin(j*math.pi/5);pts.append((math.cos(ang)*d-math.sin(ang)*off,math.sin(ang)*d+math.cos(ang)*off,.2))
   ribbon(pts,.018,(.65,.78,1),fade**1.3)
   if k%2==0:
    q=pts[3];ribbon([q,(q[0]+rr.uniform(-.4,.4),q[1]+rr.uniform(-.4,.4),.2)],.01,(.42,.52,1),fade**2)
  disc(0,0,.28,(.9,.95,1),fade**3,.3)
effects=['stone_impact','charge_dust','stone_fall','energy_orb','summon','lightning_impact'] if a.effect=='all' else [a.effect]
for kind in effects:
 frames=[2,6,11,17] if a.sample else list(range(24))
 for i in frames:
  for o in list(bpy.data.objects):
   if o not in BASE:bpy.data.objects.remove(o,do_unlink=True)
  for m in list(bpy.data.materials):
   if m.users==0:bpy.data.materials.remove(m)
  M.clear();t=i/24 if kind=='energy_orb' else i/23
  build(kind,t);os.makedirs(os.path.join(a.output,kind),exist_ok=True);S.render.filepath=os.path.join(a.output,kind,f'{i:03}.png');bpy.ops.render.render(write_still=True)

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
 if diff:
  shader.inputs['Roughness'].default_value=.75
  tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=7;tex.inputs['Detail'].default_value=3
  tone=n.new('ShaderNodeMixRGB');tone.blend_type='MULTIPLY';tone.inputs[0].default_value=.6;tone.inputs[1].default_value=(*c,1);l.new(tex.outputs['Fac'],tone.inputs[2]);l.new(tone.outputs[0],shader.inputs['Color'])
  bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.32;bump.inputs['Distance'].default_value=.09;l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],shader.inputs['Normal'])
 if soft:
  tc=n.new('ShaderNodeTexCoord');dist=n.new('ShaderNodeVectorMath');dist.operation='DISTANCE';dist.inputs[1].default_value=(.5,.5,0);l.new(tc.outputs['UV'],dist.inputs[0]);r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.05;r.color_ramp.elements[0].color=(alpha,alpha,alpha,1);r.color_ramp.elements[1].position=.5;r.color_ramp.elements[1].color=(0,0,0,1);l.new(dist.outputs['Value'],r.inputs[0]);l.new(r.outputs[0],mix.inputs[0])
 l.new(mix.outputs[0],out.inputs[0]);M[key]=m;return m
def disc(x,y,r,c,alpha,z=0):
 bpy.ops.mesh.primitive_plane_add(size=2,location=(x,y,z));o=bpy.context.object;o.scale=(r,r,1);o.data.materials.append(mat('soft'+str(c),c,alpha,soft=True));return o
def rock(x,y,z,scale,seed,alpha=1):
 rr=random.Random(seed);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2 if scale > .5 else 1,radius=scale,location=(x,y,z));o=bpy.context.object
 for v in o.data.vertices:v.co*=rr.uniform(.82,1.15)
 o.scale=(1,.7,1.1);o.rotation_euler=[rr.random()*6 for _ in range(3)];
 for face in o.data.polygons:
  # Authored facet tones keep a solid, readable rock at gameplay size.
  tone=rr.uniform(.91,1.07);o.data.materials.append(mat('stone_face'+str(face.index),(.14*tone,.15*tone,.145*tone),alpha,True));face.material_index=len(o.data.materials)-1
 return o
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
 if kind=='stone_impact':
  # Short, grounded dust compression with four weighty chips, no luminous arcs.
  for k in range(7):
   ang=rr.random()*math.tau;r=(.2+rr.random()*1.7)*(t**.45)
   disc(math.cos(ang)*r,math.sin(ang)*r*.65,.5+rr.random()*.4+t*.35,(.40,.38,.33),fade**1.7*.60,z=-.1+k*.001)
  for k in range(4):
   ang=k*math.tau/4+.35;r=(1.4+rr.random()*.6)*t**.62;lift=math.sin(t*math.pi)*rr.uniform(.25,.7)
   rock(math.cos(ang)*r,math.sin(ang)*r*.65+lift,.15,rr.uniform(.25,.39)*(1-.25*t),k+60,fade**.55)
 elif kind=='charge_dust':
  for k in range(17):
   x=-1.7*t+rr.uniform(-.6,.6);y=rr.uniform(-.6,.6)*(t+.3)
   disc(x,y,.25+rr.random()*.5+t*.42,(.50,.39,.27),fade**1.6*.65,z=-.1+k*.001)
  for k in range(15):
   ang=rr.random()*math.tau;r=(.7+rr.random()*2.2)*t**.6;sz=rr.uniform(.04,.18)*(1-.65*t);rock(math.cos(ang)*r,math.sin(ang)*r,.1+math.sin(t*math.pi)*rr.uniform(.1,.5),sz,k,fade**.5)
 elif kind=='stone_fall':
  o=rock(0,0,.3,1.65,4,1);o.rotation_euler.z+=t*.45
  for k in range(3):
   x=rr.uniform(-.65,.65);rock(x,.9+rr.random()*.65,.1,.045+rr.random()*.04,k+80,.45)
 elif kind=='energy_orb':
  ph=t*math.tau
  # Compact body and sparse currents; the sphere itself is the projectile,
  # never an orbiting decorative circle or a large white central flare.
  disc(0,0,1.90,(.20,.12,.38),.35)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1.66,location=(0,0,.15))
  o=bpy.context.object;o.data.materials.append(mat('orb_body',(.18,.105,.31),.94,True))
  for k in range(3):
   pts=[]
   for j in range(15):
    u=j/14;ang=ph+k*2.1+u*1.6;r=1.45*(.55+.45*math.sin(u*math.pi))
    pts.append((math.cos(ang)*r,math.sin(ang)*r,1.2))
   ribbon(pts,.035,(.48,.35,.82),.55)
  disc(-.35,.38,.45,(.67,.55,.93),.5,1.9)
 elif kind=='summon':
  strength=.30+.70*math.sin(math.pi*min(.90,t))**.65
  # Broken inward curls gather above a softly grounded base, not a sigil.
  for k in range(5):
   ang=k*2.4;phase=(t*.8+k*.23)%1;r=(1-phase)*1.65+.25
   pts=[]
   for j in range(12):
    u=j/11;theta=ang+u*.45;r0=r*(1-u*.45)
    pts.append((math.cos(theta)*r0,math.sin(theta)*r0*.72+.6*t*u,.15))
   ribbon(pts,.04,(.62,.50,.82),strength*.8)
  for k in range(5):
   x=rr.uniform(-.65,.65);y=rr.uniform(-.55,.55)+t*.65
   disc(x,y,.42+rr.random()*.35,(.27,.19,.39),strength*.27,.1+k*.01)
  # Condensed upper mass gives an emergence cue before the real actor spawns.
  disc(0,.25+t*.2,.65+t*.60,(.52,.44,.69),(.55+t*.35),.3)
  disc(-.12,.42+t*.35,.24+t*.22,(.74,.66,.86),(.35+t*.35),.35)
 elif kind=='lightning_impact':
  disc(0,0,.35+t*.55,(.23,.38,1),fade**3*.20)
  for k in range(5):
   ang=k*math.tau/5+rr.uniform(-.15,.15);r=(.35+rr.random()*1.25)*(.3+.7*t);pts=[]
   for j in range(6):
    d=r*j/5;off=rr.uniform(-.16,.16)*math.sin(j*math.pi/5);pts.append((math.cos(ang)*d-math.sin(ang)*off,math.sin(ang)*d+math.cos(ang)*off,.2))
   ribbon(pts,.018,(.65,.78,1),fade**1.3)
   if k%2==0:
    q=pts[3];ribbon([q,(q[0]+rr.uniform(-.4,.4),q[1]+rr.uniform(-.4,.4),.2)],.01,(.42,.52,1),fade**2)
  disc(0,0,.16,(.9,.95,1),fade**4*.7,.3)
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

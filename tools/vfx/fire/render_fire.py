"""Reproducible Blender 4.3+ top-down fire flipbooks; no simulation cache.
blender -b --factory-startup --python tools/vfx/fire/render_fire.py -- --effect burst --out /tmp/fire --frames 24
Pack with pack_fire.py. Source frame times are half-open for seamless loops.
"""
import bpy, math, random, argparse, sys, os
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--effect', choices=['burst','burn','ground','ring','skyfire'],default='burst');p.add_argument('--out',required=True);p.add_argument('--frames',type=int,default=24);p.add_argument('--size',type=int,default=256);p.add_argument('--sample',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=128 if a.effect=='burst' else 32;s.cycles.use_denoising=False;s.render.resolution_x=a.size;s.render.resolution_y=a.size;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8';s.view_settings.view_transform='Standard';s.view_settings.look='Medium High Contrast' if False else 'None';s.world.color=(0,0,0)
bpy.ops.object.camera_add(location=(0,0,8));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=4.8;s.camera=cam
# A layered emissive surface remains legible when rendered small; edge opacity
# is encoded in PNG alpha, not a black background or simulated smoke cache.
def mat(name,c,alpha=1):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*c,1);e.inputs[1].default_value=1
 if alpha<1:
  t=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha;m.node_tree.links.new(t.outputs[0],mix.inputs[1]);m.node_tree.links.new(e.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],o.inputs[0])
 else:m.node_tree.links.new(e.outputs[0],o.inputs[0])
 return m
mats=[mat('ember edge',(0.48,.018,.002),.2),mat('deep vermilion',(.95,.055,.003),.8),mat('hot orange',(1,.24,.006)),mat('gold',(1,.62,.065)),mat('ivory core',(1,.92,.51))]
smoke=mat('cooling ash',(.12,.045,.028),.22)
objects=[]
def mesh(name,v,f,material):
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.materials.append(material);ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);objects.append(ob);return ob

def ribbon(name,points,width,material,z=0):
 v=[]
 for i,pt in enumerate(points):
  before=points[max(0,i-1)];after=points[min(len(points)-1,i+1)];dx=after[0]-before[0];dy=after[1]-before[1];le=max(.001,math.hypot(dx,dy));w=width[i] if isinstance(width,list) else width
  v.extend([(pt[0]-dy/le*w,pt[1]+dx/le*w,z),(pt[0]+dy/le*w,pt[1]-dx/le*w,z)])
 return mesh(name,v,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(points)-1)],material)
def flame(seed,start,angle,length,width,phase,fade=1):
 rng=random.Random(seed);bend=(rng.random()-.5)*1.8;ps=[];ws=[]
 for i in range(15):
  t=i/14;rad=length*t;side=math.sin(t*math.pi)*bend*length*.24+math.sin(t*6+phase)*length*.07*t
  ps.append((start[0]+math.cos(angle)*rad-math.sin(angle)*side,start[1]+math.sin(angle)*rad+math.cos(angle)*side));ws.append(width*(math.sin(math.pi*(t*.87+.07))**.8)*(1-t)**.6*fade)
 for layer,(scale,mi,trim) in enumerate([(1.20,0,0),(1,1,0),(.69,2,1),(.36,3,3),(.12,4,6)]):
  end=len(ps)-trim;ribbon('flame',ps[:end],[x*scale for x in ws[:end]],mats[mi],.003*layer)
def spark(x,y,r,angle=0,fade=1):
 dx=math.cos(angle)*r;dy=math.sin(angle)*r;mesh('ember',[(x-dx,y-dy,.04),(x-dy*.25,y+dx*.25,.04),(x+dx,y+dy,.04),(x+dy*.25,y-dx*.25,.04)],[(0,1,2,3)],mats[3 if fade>.5 else 1])

def draw(t):
 if a.effect=='burst':
  if t<=0 or t>=1:return
  advance=1-math.exp(-t*12)
  # A fused volumetric fire body: no repeated star/cel-puff silhouettes.
  mb=bpy.data.metaballs.new('turbulent fire volume');mb.resolution=.09;mb.render_resolution=.07;mb.threshold=.6
  ob=bpy.data.objects.new('continuous fire body',mb);s.collection.objects.link(ob);objects.append(ob);ob.scale=(1.5,1.5,.8)
  for j in range(9):
   rng=random.Random(j+331);ang=rng.random()*math.tau;spread=advance*(.4+1.0*t)*rng.uniform(.15,.95)
   el=mb.elements.new();el.co=(math.cos(ang)*spread,math.sin(ang)*spread,rng.uniform(-.1,.1));el.radius=(.45+rng.random()*.28)*advance**.4*max(0,1-t)**.9
  volume=bpy.data.materials.new('living fire volume');volume.use_nodes=True;n=volume.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');tex=n.new('ShaderNodeTexNoise');tex.noise_dimensions='4D';tex.inputs['Scale'].default_value=5.5;tex.inputs['Detail'].default_value=3;tex.inputs['Roughness'].default_value=.65;tex.inputs['W'].default_value=t*2.5
  coord=n.new('ShaderNodeTexCoord');volume.node_tree.links.new(coord.outputs['Generated'],tex.inputs['Vector'])
  density=n.new('ShaderNodeMath');density.operation='MULTIPLY';density.inputs[1].default_value=18*max(0,1-t)**.4;cut=n.new('ShaderNodeMath');cut.operation='SUBTRACT';cut.inputs[1].default_value=.38;volume.node_tree.links.new(tex.outputs['Fac'],cut.inputs[0]);volume.node_tree.links.new(cut.outputs[0],density.inputs[0]);volume.node_tree.links.new(density.outputs[0],v.inputs['Density'])
  ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1]);ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=(.38,.008,.001,1)
  for pos,col in [(.38,(1,.012,.001,1)),(.52,(1,.055,.001,1)),(.65,(1,.35,.009,1)),(.78,(1,.72,.12,1)),(.9,(1,.95,.46,1))]:ramp.color_ramp.elements.new(pos).color=col
  volume.node_tree.links.new(tex.outputs['Fac'],ramp.inputs[0])
  # A brief local hot core, never a full-image flash or added outer halo.
  dist=n.new('ShaderNodeVectorMath');dist.operation='DISTANCE';dist.inputs[1].default_value=(.5,.5,.5);volume.node_tree.links.new(coord.outputs['Generated'],dist.inputs[0])
  core=n.new('ShaderNodeMapRange');core.clamp=True;core.inputs['From Min'].default_value=0;core.inputs['From Max'].default_value=.27;core.inputs['To Min'].default_value=max(0,1-t/.22);core.inputs['To Max'].default_value=0;volume.node_tree.links.new(dist.outputs['Value'],core.inputs['Value'])
  hot=n.new('ShaderNodeMixRGB');hot.inputs[2].default_value=(1,.92,.5,1);volume.node_tree.links.new(core.outputs[0],hot.inputs[0]);volume.node_tree.links.new(ramp.outputs[0],hot.inputs[1]);volume.node_tree.links.new(hot.outputs[0],v.inputs['Emission Color']);v.inputs['Emission Strength'].default_value=8.5*max(0,1-t)**.5;v.inputs['Color'].default_value=(.22,.035,.006,1);volume.node_tree.links.new(v.outputs[0],o.inputs['Volume']);mb.materials.append(volume)
  bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');ob=bpy.context.object;objects[-1]=ob
  dis=ob.modifiers.new('turbulent surface', 'DISPLACE');cloud=bpy.data.textures.new('fire surface noise',type='CLOUDS');cloud.noise_scale=.23;cloud.noise_depth=2;dis.texture=cloud;dis.strength=.38*advance*max(0,1-t);dis.mid_level=.5
  ob.select_set(False)
  for j in range(12):
   rng=random.Random(j+700);ang=rng.random()*math.tau;r=.1+1.8*advance*rng.uniform(.55,1);spark(math.cos(ang)*r,math.sin(ang)*r,.035*max(0,1-t)**1.2,ang,1-t)
 elif a.effect in ['burn','ground']:
  count=9 if a.effect=='burn' else 25
  for j in range(count):
   rng=random.Random(j+490);ang=rng.random()*math.tau;r=rng.uniform(.05,.65 if a.effect=='burn' else 1.25);phase=t*math.tau+j*1.4
   # Tilted curved tongues, not a planar colored disk.
   length=rng.uniform(.65,1.25)*(1+.18*math.sin(phase));orientation=math.pi*.5+.35*math.sin(phase*.0+j)
   if a.effect=='ground':
    ang=j*2.399963;r=1.52*math.sqrt((j+.5)/count);length=rng.uniform(.4,.72)*(1+.18*math.sin(phase))
   flame(800+j,(math.cos(ang)*r,math.sin(ang)*r-.35),orientation,length,.15 if a.effect=='burn' else .17,phase)
  for j in range(10):
   phase=(t+j*.173)%1;ang=j*2.4;spark(math.cos(ang)*(.6+phase*.4),-.25+phase*1.9,.022*(1-phase),math.pi/2)
 elif a.effect=='ring':
  # Horizontal periodic fire strip. Runtime maps it onto a fixed-width annulus.
  # Periodic copies preserve both edges; transparent center/outside preserves hazards.
  for j in range(-2,14):
   k=j%12;phase=t*math.tau+k*1.2;x=j*4.8/12-2.4
   flame(140+k,(x,-.58),math.pi*.5+.18*math.sin(k),1.05+.15*math.sin(phase),.15,phase)
 elif a.effect=='skyfire':
  for j in range(7):
   phase=t*math.tau+j*.9;x=(j-3)*.12
   flame(920+j,(x,-.95+abs(j-3)*.06),math.pi*.5+(j-3)*.055,2.25-abs(j-3)*.28,.29-abs(j-3)*.035,phase)
  # A fractured molten head, not concentric target circles.
  for k,(rad,mi) in enumerate([(.49,1),(.43,2)]):
   verts=[(-.03,-.79,.10+k*.01)]
   for q in range(24):
    an=q*math.tau/24;r=rad*(1+.12*math.sin(an*5+.6)+.07*math.sin(an*9))
    verts.append((math.cos(an)*r,-.82+math.sin(an)*r,.10+k*.01))
   mesh('molten meteor rim',verts,[(0,q+1,(q+1)%24+1) for q in range(24)],mats[mi])
  verts=[(-.12,-.68,.14)]
  for q in range(16):
   an=q*math.tau/16;r=.30*(1+.16*math.sin(an*5+1))
   verts.append((-.04+math.cos(an)*r,-.78+math.sin(an)*r,.14))
  ob=mesh('fractured incandescent facets',verts,[(0,q+1,(q+1)%16+1) for q in range(16)],mats[3]);ob.data.materials.append(mats[2]);ob.data.materials.append(mats[4])
  for q,poly in enumerate(ob.data.polygons):poly.material_index=[0,0,1,0,2,0,1,0,0,1,0,0,2,0,0,1][q]
os.makedirs(a.out,exist_ok=True)
indices=[0,3,6,9,13,17,21,23] if a.sample and a.frames==24 else list(range(a.frames))
for i in indices:
 for ob in objects:bpy.data.objects.remove(ob,do_unlink=True)
 objects.clear();t=i/(a.frames-1) if a.effect=='burst' else i/a.frames;draw(t);s.render.filepath=os.path.join(a.out,f'{i:03d}.png');bpy.ops.render.render(write_still=True)

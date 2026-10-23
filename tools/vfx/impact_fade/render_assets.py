"""Blender 4.3+ original smoke dissolve and shield fragments, no cache or external art."""
import bpy, math, random, argparse, sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--effect',choices=['death_smoke','shield_break'],required=True);p.add_argument('--sample',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=128;s.cycles.use_denoising=False;s.cycles.transparent_max_bounces=16;s.render.resolution_x=s.render.resolution_y=256;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.view_settings.view_transform='Standard';s.world.color=(0,0,0)
bpy.ops.object.camera_add(location=(0,0,8));s.camera=bpy.context.object;s.camera.data.type='ORTHO';s.camera.data.ortho_scale=4.6
objects=[]
def emission(name,color,alpha):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*color,1);e.inputs[1].default_value=.85;t=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha;l=m.node_tree.links;l.new(t.outputs[0],mix.inputs[1]);l.new(e.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],o.inputs[0]);return m
def mesh(name,verts,faces,m):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(m);ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);objects.append(ob);return ob

def smoke(t):
 if t>=1:return
 mb=bpy.data.metaballs.new('soft expanding vapor');mb.resolution=.08;mb.render_resolution=.06;mb.threshold=.6;ob=bpy.data.objects.new('dissolve volume',mb);s.collection.objects.link(ob);objects.append(ob);ob.scale=(1.0,.85,.6)
 growth=1-math.exp(-t*7)
 for j in range(8):
  rng=random.Random(527+j);ang=rng.uniform(0,math.tau);spread=(.25+.75*growth)*rng.uniform(.5,1)
  el=mb.elements.new();el.co=(math.cos(ang)*spread,math.sin(ang)*spread+.28*t,rng.uniform(-.12,.12));el.radius=rng.uniform(.48,.68)*(1+.25*growth)*(1-.34*t)
 m=bpy.data.materials.new('cool thin smoke');m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links;o=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');tex=n.new('ShaderNodeTexNoise');tex.noise_dimensions='4D';tex.inputs['Scale'].default_value=5;tex.inputs['Detail'].default_value=3;tex.inputs['Roughness'].default_value=.65;tex.inputs['W'].default_value=t*1.7
 co=n.new('ShaderNodeTexCoord');l.new(co.outputs['Generated'],tex.inputs['Vector']);cut=n.new('ShaderNodeMath');cut.operation='SUBTRACT';cut.inputs[1].default_value=.32;l.new(tex.outputs['Fac'],cut.inputs[0]);den=n.new('ShaderNodeMath');den.operation='MULTIPLY';den.inputs[1].default_value=3.2*(1-t)**1.9;l.new(cut.outputs[0],den.inputs[0]);l.new(den.outputs[0],v.inputs['Density']);v.inputs['Color'].default_value=(.36,.42,.48,1);v.inputs['Emission Color'].default_value=(.32,.39,.46,1);v.inputs['Emission Strength'].default_value=.6*(1-t)**.5;l.new(v.outputs[0],o.inputs['Volume']);mb.materials.append(m)
 bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');ob=bpy.context.object;objects[-1]=ob;ob.select_set(False);dis=ob.modifiers.new('irregular smoke surface','DISPLACE');cloud=bpy.data.textures.new('cloud turbulence',type='CLOUDS');cloud.noise_scale=.3;cloud.noise_depth=2;dis.texture=cloud;dis.strength=.25+.16*t;dis.mid_level=.5

def shield(t):
 if t>=1:return
 fade=(1-t)**1.6
 # An incomplete expanding wave and a few genuinely three-dimensional fragments.
 m=emission('faint cyan wave',(.28,.72,.9),.28*fade)
 radius=.8+.55*(1-math.exp(-t*6));width=.014*(1-t)
 verts=[];faces=[]
 for j in range(72):
  ang=j/72*math.tau
  for r in [radius-width,radius+width]:verts.append((math.cos(ang)*r,math.sin(ang)*r,0))
 for j in range(71):
  if j%24<18:faces.append((j*2,j*2+1,j*2+3,j*2+2))
 mesh('broken ripple',verts,faces,m)
 for j in range(7):
  rng=random.Random(932+j);ang=j*math.tau/7+rng.uniform(-.12,.12);r=.7+t*.8;size=rng.uniform(.10,.17)*(1-.45*t)
  col=(.32,.71,.9) if j%2 else (.62,.86,.94)
  mat=emission('shield facet',col,.8*fade)
  ob=mesh('shield shard',[(-size*.5,-size,0),(size*.55,-size*.4,0),(size*.2,size,.05),(-size*.35,size*.45,.02),(0,0,.07)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],mat);ob.location=(math.cos(ang)*r,math.sin(ang)*r,0);ob.rotation_euler=(t*(j%3-1),t*.4,ang+t*(.7 if j%2 else -.8))
  darker=emission('dim shard face',(.2,.45,.62),.65*fade);ob.data.materials.append(darker);ob.data.polygons[0].material_index=1;ob.data.polygons[3].material_index=1
count=12 if a.effect=='death_smoke' else 8
indices=[0,2,4,7,count-1] if a.sample else range(count)
out=Path(a.out)/a.effect;out.mkdir(parents=True,exist_ok=True)
for i in sorted(set(indices)):
 for ob in objects:bpy.data.objects.remove(ob,do_unlink=True)
 objects.clear();t=i/(count-1)
 (smoke if a.effect=='death_smoke' else shield)(t)
 s.render.filepath=str(out/f'{i:03d}.png');bpy.ops.render.render(write_still=True)

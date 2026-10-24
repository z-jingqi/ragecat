"""Original deterministic Blender fire surfaces/geometry, without external art.
blender -b --factory-startup -t 2 --python tools/vfx/fire/render_fire.py -- --effect burst --out /tmp/fire
Loops sample [0,1); burst samples [0,1] and ends transparent.
"""
import argparse, math, os, random, sys
import bpy
from mathutils import Vector, noise
p=argparse.ArgumentParser()
p.add_argument('--effect',choices=['burst','burn','ground','ring','skyfire'],default='burst')
p.add_argument('--out',required=True);p.add_argument('--frames',type=int,default=24)
p.add_argument('--size',type=int,default=256);p.add_argument('--samples',type=int,default=32)
p.add_argument('--sample',action='store_true');args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=args.samples;s.cycles.use_denoising=False
s.render.resolution_x=args.size;s.render.resolution_y=args.size;s.render.resolution_percentage=100
s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8'
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.world.color=(.02,.02,.02)
bpy.ops.object.camera_add(location=(0,0,8));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=2.8 if args.effect=='skyfire' else 4.8;s.camera=camera
bpy.ops.object.light_add(type='AREA',location=(-3,-2,5));bpy.context.object.data.energy=180;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
objects=[];materials=[]

def material_tree(name):
 m=bpy.data.materials.new(name);m.use_nodes=True;materials.append(m);n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');return m,n,m.node_tree.links,o

def calc(n,l,op,a,b=None):
 out=n.new('ShaderNodeMath');out.operation=op
 for i,v in enumerate([a,b] if b is not None else [a]):
  if isinstance(v,(int,float)):out.inputs[i].default_value=v
  else:l.new(v,out.inputs[i])
 return out.outputs[0]

def ramp(n,l,value,stops):
 out=n.new('ShaderNodeValToRGB');out.color_ramp.elements.remove(out.color_ramp.elements[1])
 for i,(at,c) in enumerate(stops):
  el=out.color_ramp.elements[0] if i==0 else out.color_ramp.elements.new(at);el.position=at;el.color=c
 l.new(value,out.inputs[0]);return out.outputs['Color']

def grey(v):return (v,v,v,1)

def flame_material(name,phase,opacity=1,heat=.65,continuous=False):
 # Layered convection/filament noise on actual bent 3D flame sheets. No radial
 # gradient, puff, star, bloom or compositor glow. Dark red folds outlive gold.
 m,n,l,o=material_tree(name);uv=n.new('ShaderNodeTexCoord');xyz=n.new('ShaderNodeSeparateXYZ');l.new(uv.outputs['UV'],xyz.inputs[0])
 scale=n.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(2.3,.55,1)
 if continuous:
  circular=n.new('ShaderNodeCombineXYZ');angle=calc(n,l,'MULTIPLY',xyz.outputs['X'],math.tau);l.new(calc(n,l,'SINE',angle),circular.inputs['X']);l.new(xyz.outputs['Y'],circular.inputs['Y']);l.new(calc(n,l,'COSINE',angle),circular.inputs['Z']);l.new(circular.outputs[0],scale.inputs[0])
 else:l.new(uv.outputs['UV'],scale.inputs[0])
 offset=n.new('ShaderNodeVectorMath');offset.operation='ADD';offset.inputs[1].default_value=(.28*math.cos(phase),.28*math.sin(phase),0);l.new(scale.outputs[0],offset.inputs[0])
 tex=n.new('ShaderNodeTexNoise');tex.noise_dimensions='4D';tex.inputs['Scale'].default_value=3.6;tex.inputs['Detail'].default_value=4;tex.inputs['Roughness'].default_value=.72;tex.inputs['Distortion'].default_value=.55;tex.inputs['W'].default_value=.4+.32*math.sin(phase);l.new(offset.outputs[0],tex.inputs['Vector'])
 small=n.new('ShaderNodeTexNoise');small.inputs['Scale'].default_value=17;small.inputs['Detail'].default_value=2;l.new(offset.outputs[0],small.inputs['Vector'])
 mixed=calc(n,l,'ADD',calc(n,l,'MULTIPLY',tex.outputs['Fac'],.78),calc(n,l,'MULTIPLY',small.outputs['Fac'],.22))
 distance=calc(n,l,'ABSOLUTE',calc(n,l,'SUBTRACT',xyz.outputs['X'],.5))
 side=ramp(n,l,distance,[(0,grey(1)),(.20,grey(1)),(.46,grey(.20)),(.5,grey(0))])
 length=ramp(n,l,xyz.outputs['Y'],[(0,grey(0)),(.12,grey(1)),(.68,grey(.82)),(1,grey(0))])
 density=ramp(n,l,mixed,[(.25,grey(0)),(.38,grey(.15)),(.58,grey(.92)),(.76,grey(1))])
 if continuous:
  # The all-x ember density floor guarantees an unbroken band after UV mapping.
  side=1.;length=ramp(n,l,xyz.outputs['Y'],[(0,grey(0)),(.15,grey(.35)),(.4,grey(1)),(.64,grey(.9)),(.95,grey(0))]);density=calc(n,l,'ADD',calc(n,l,'MULTIPLY',density,.60),.40)
 alpha=calc(n,l,'MULTIPLY',calc(n,l,'MULTIPLY',density,side),calc(n,l,'MULTIPLY',length,opacity))
 if args.effect=='ring':
  # Final silhouette modulation is in original world geometry coordinates so
  # both bed and individual tongues soften together. Only the inner fringe
  # is eroded: the center stays continuous and no pixel expands the band.
  geometry=n.new('ShaderNodeNewGeometry');position=n.new('ShaderNodeSeparateXYZ');l.new(geometry.outputs['Position'],position.inputs[0])
  angle=calc(n,l,'MULTIPLY',position.outputs['X'],math.tau/4.8)
  periodic=n.new('ShaderNodeCombineXYZ');l.new(calc(n,l,'SINE',angle),periodic.inputs['X']);l.new(calc(n,l,'COSINE',angle),periodic.inputs['Z']);periodic.inputs['Y'].default_value=.22*math.sin(phase)
  edge_noise=n.new('ShaderNodeTexNoise');edge_noise.inputs['Scale'].default_value=9.;edge_noise.inputs['Detail'].default_value=2.;l.new(periodic.outputs[0],edge_noise.inputs['Vector'])
  reach=calc(n,l,'ADD',.70,calc(n,l,'MULTIPLY',edge_noise.outputs['Fac'],.30))
  across=calc(n,l,'DIVIDE',calc(n,l,'ABSOLUTE',position.outputs['Y']),.9)
  feather=n.new('ShaderNodeMapRange');feather.clamp=True;feather.interpolation_type='SMOOTHSTEP';l.new(across,feather.inputs['Value']);l.new(calc(n,l,'SUBTRACT',reach,.16),feather.inputs['From Min']);l.new(reach,feather.inputs['From Max']);feather.inputs['To Min'].default_value=1.;feather.inputs['To Max'].default_value=0.
  alpha=calc(n,l,'MULTIPLY',alpha,feather.outputs[0])
 hot=calc(n,l,'MULTIPLY',side,calc(n,l,'MULTIPLY',calc(n,l,'SUBTRACT',1,xyz.outputs['Y']),heat))
 temp=calc(n,l,'ADD',mixed,calc(n,l,'MULTIPLY',hot,.33))
 color=ramp(n,l,temp,[(.23,(.065,.002,.0003,1)),(.39,(.25,.009,.001,1)),(.50,(.72,.042,.002,1)),(.60,(1,.16,.009,1)),(.69,(1,.43,.048,1)),(.79,(1,.78,.26,1)),(.90,(1,.88,.48,1))])
 emit=n.new('ShaderNodeEmission');emit.inputs['Strength'].default_value=1.1;l.new(color,emit.inputs[0]);transparent=n.new('ShaderNodeBsdfTransparent');blend=n.new('ShaderNodeMixShader');l.new(alpha,blend.inputs[0]);l.new(transparent.outputs[0],blend.inputs[1]);l.new(emit.outputs[0],blend.inputs[2]);l.new(blend.outputs[0],o.inputs['Surface']);return m

def mesh(name,verts,faces,material,uvs=None):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.materials.append(material)
 if uvs:
  layer=data.uv_layers.new(name='FlameFlow')
  for poly in data.polygons:
   for li in poly.loop_indices:layer.data[li].uv=uvs[data.loops[li].vertex_index]
 ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);objects.append(ob);return ob

def tongue(seed,origin,angle,length,width,phase,opacity=1,heat=.65,z=0):
 rng=random.Random(seed);bend=rng.uniform(-.18,.18);verts=[];uvs=[];faces=[];rows=28;cols=10
 for row in range(rows+1):
  v=row/rows;center=bend*length*math.sin(v*math.pi)+.055*length*math.sin(phase+v*11+seed)*v;half=width*(.55+math.sin(v*math.pi)*.45)*(1-v)**.68*(1+.15*math.sin(v*35+phase+seed)+.09*math.sin(v*71-phase))+.001
  for col in range(cols+1):
   u=col/cols;xx=center+(u*2-1)*half;yy=length*v;fold=math.sin(u*5+v*9+phase)*.08*(1-v)
   verts.append((origin[0]+math.cos(angle)*yy-math.sin(angle)*xx,origin[1]+math.sin(angle)*yy+math.cos(angle)*xx,z+fold+.1*math.sin(v*math.pi)));uvs.append((u,v))
 for row in range(rows):
  for col in range(cols):
   q=row*(cols+1)+col;faces.append((q,q+1,q+cols+2,q+cols+1))
 return mesh('curled convection flame',verts,faces,flame_material('turbulent fire surface',phase+seed*.1,opacity,heat),uvs)

def ember(x,y,size,phase,opacity=1):
 # Small irregular flecks, not bright four-point stars or radial rays.
 m,n,l,o=material_tree('cooling ember');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(1,.24+.12*math.sin(phase),.014,1);tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=opacity;l.new(tr.outputs[0],mix.inputs[1]);l.new(e.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],o.inputs[0])
 mesh('ember fragment',[(x-size*.6,y-size,.2),(x+size*.8,y-size*.5,.22),(x+size*.3,y+size,.21),(x-size*.5,y+size*.45,.2)],[(0,1,2,3)],m)

def molten_stone(t):
 m,n,l,o=material_tree('charred crust with incandescent fissures');coord=n.new('ShaderNodeTexCoord');vor=n.new('ShaderNodeTexVoronoi');vor.feature='DISTANCE_TO_EDGE';vor.inputs['Scale'].default_value=4.8
 warp=n.new('ShaderNodeTexNoise');warp.inputs['Scale'].default_value=4.5;warp.inputs['Detail'].default_value=3;l.new(coord.outputs['Generated'],warp.inputs['Vector'])
 scale=n.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs[3].default_value=.27;l.new(warp.outputs['Color'],scale.inputs[0]);distort=n.new('ShaderNodeVectorMath');distort.operation='ADD';l.new(coord.outputs['Generated'],distort.inputs[0]);l.new(scale.outputs[0],distort.inputs[1]);l.new(distort.outputs[0],vor.inputs['Vector'])
 cracks=ramp(n,l,vor.outputs['Distance'],[(0,(1,.34,.018,1)),(.008,(.45,.025,.001,1)),(.025,(.055,.024,.013,1)),(.06,(.035,.027,.02,1))])
 tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=15;tex.inputs['Detail'].default_value=3;l.new(coord.outputs['Generated'],tex.inputs['Vector']);bsdf=n.new('ShaderNodeBsdfPrincipled');bsdf.inputs['Roughness'].default_value=.86;l.new(cracks,bsdf.inputs['Base Color']);emission_mask=n.new('ShaderNodeMixRGB');emission_mask.blend_type='MULTIPLY';emission_mask.inputs[0].default_value=1;l.new(cracks,emission_mask.inputs[1]);l.new(warp.outputs['Fac'],emission_mask.inputs[2]);l.new(emission_mask.outputs[0],bsdf.inputs['Emission Color']);bsdf.inputs['Emission Strength'].default_value=.7
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.6;bump.inputs['Distance'].default_value=.08;l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],bsdf.inputs['Normal']);l.new(bsdf.outputs[0],o.inputs[0])
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=.62,location=(0,-.48,.08));ob=bpy.context.object;objects.append(ob);ob.data.materials.append(m)
 for v in ob.data.vertices:
  value=noise.noise_vector(v.co*5.1);v.co*=.87+.18*value.x+.08*math.sin(v.co.x*18);v.co.y*=1.08
 ob.rotation_euler=(.12*math.sin(t*math.tau),.12*math.cos(t*math.tau),.16)

def draw(t):
 phase=t*math.tau
 if args.effect=='burst':
  if t<=0 or t>=1:return
  expansion=1-math.exp(-t*15);fade=(1-t)**1.7
  # Unequal upward-curled flame folds create brief ignition, not an orange ball.
  for j in range(5):
   rng=random.Random(715+j);tongue(710+j,((j-2)*.13,-.52),math.pi/2+rng.uniform(-.2,.2),rng.uniform(.85,1.16)*expansion*(1-.35*t),.36*expansion,phase+j,min(1,fade*1.9),max(0,1-t/.34),-.02+j*.01)
  for j in range(9):
   rng=random.Random(183+j);theta=rng.uniform(0,math.tau);distance=expansion*rng.uniform(.05,.50);origin=(math.cos(theta)*distance,math.sin(theta)*distance-.30)
   tongue(581+j,origin,rng.uniform(.86,2.24),rng.uniform(.55,1.25)*expansion*(1-.45*t),rng.uniform(.16,.32)*expansion,phase+j*.9,min(1,fade*1.7),max(0,1-t/.30),j*.013)
  for j in range(9):
   rng=random.Random(308+j);angle=rng.random()*math.tau;travel=(.3+t*1.65)*rng.uniform(.65,1);ember(math.cos(angle)*travel,math.sin(angle)*travel,.019*(1-t)**.7,phase+j,min(1,fade*1.2))
 elif args.effect in ['burn','ground']:
  count=6 if args.effect=='burn' else 21
  for j in range(count):
   rng=random.Random(491+j);angle=j*2.399963;r=(.4 if args.effect=='burn' else 1.72)*math.sqrt((j+.5)/count);origin=(math.cos(angle)*r,math.sin(angle)*r-.24)
   if args.effect=='ground':
    patch=random.Random(661+j//3);angle=patch.uniform(0,math.tau);r=patch.uniform(.25,1.55);origin=(math.cos(angle)*r+rng.uniform(-.18,.18),math.sin(angle)*r+rng.uniform(-.14,.14)-.12)
   length=rng.uniform(.65,1.1) if args.effect=='burn' else rng.uniform(.26,.52);length*=1+.19*math.sin(phase+j*.94)
   tongue(691+j,origin,math.pi/2+rng.uniform(-.32,.32),length,rng.uniform(.12,.21),phase+j*.94,.9 if args.effect=='burn' else .62+.22*math.sin(phase+j),.70 if args.effect=='burn' else .38,j*.003)
  for j in range(4 if args.effect=='burn' else 7):
   age=(t+j*.173)%1;angle=j*2.4;ember(math.cos(angle)*(.35 if args.effect=='burn' else 1.3),-.3+math.sin(angle)*(.3 if args.effect=='burn' else 1.25)+age*.5,.014*(1-age),phase+j,math.sin(age*math.pi)*.65)
 elif args.effect=='ring':
  # Full-width textured ember bed; crop middle 96 pixels to the exact annulus.
  mesh('continuous ember bed',[(-2.4,-.9,-.01),(2.4,-.9,-.01),(2.4,.9,-.01),(-2.4,.9,-.01)],[(0,1,2,3)],flame_material('unbroken turbulent fire strip',phase,.82,.5,True),[(0,0),(1,0),(1,1),(0,1)])
  for j in range(-2,15):
   k=j%12;tongue(991+k,(j*.4-2.4,-.55),math.pi/2+.1*math.sin(k),.9+.16*math.sin(phase+k*.8),.19,phase+k*.8,.86,.6,.03)
 elif args.effect=='skyfire':
  # Real irregular basalt mass wrapped in short flame sheets, not a long comet.
  for j in range(9):
   rng=random.Random(1221+j);x=rng.uniform(-.42,.42);tongue(180+j,(x,-.5+rng.uniform(-.15,.3)),math.pi/2+rng.uniform(-.2,.2),rng.uniform(.65,1.40),rng.uniform(.13,.24),phase+j*.9,.92,.8,-.15+j*.01)
  molten_stone(t)
  for j in range(4):
   age=(t+j*.28)%1;ember(math.sin(j*2.4)*(.45+age*.1),.1+age*.95,.015*(1-age),phase+j,.65)

os.makedirs(args.out,exist_ok=True)
indices=[0,3,6,9,13,17,21,23] if args.sample and args.frames==24 else range(args.frames)
for frame in indices:
 for ob in objects:
  data=ob.data;bpy.data.objects.remove(ob,do_unlink=True)
  if data.users==0 and isinstance(data,bpy.types.Mesh):bpy.data.meshes.remove(data)
 objects.clear()
 for material in materials:
  if material.users==0:bpy.data.materials.remove(material)
 materials.clear();t=frame/(args.frames-1) if args.effect=='burst' else frame/args.frames;draw(t);s.render.filepath=os.path.join(args.out,f'{frame:03d}.png');bpy.ops.render.render(write_still=True)

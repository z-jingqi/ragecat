import bpy,math,sys,argparse
from pathlib import Path
from mathutils import Vector
parser=argparse.ArgumentParser();parser.add_argument('--out',default=str(Path(__file__).resolve().parent));parser.add_argument('--frames',default='0');parser.add_argument('--samples',type=int,default=48);parser.add_argument('--size',type=int,default=192);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=Path(args.out).resolve();OUT.mkdir(parents=True,exist_ok=True);bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=args.samples;sc.cycles.use_denoising=False;sc.cycles.volume_step_rate=.5;sc.render.film_transparent=True;sc.render.resolution_x=args.size;sc.render.resolution_y=round(args.size*9/16);sc.render.resolution_percentage=100
sc.view_settings.view_transform='Standard';sc.view_settings.look='None';sc.world=bpy.data.worlds.new('Unlit void');sc.world.use_nodes=True;sc.world.node_tree.nodes.get('Background').inputs[0].default_value=(0,0,0,1)
camd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',camd);sc.collection.objects.link(cam);cam.location=(-.9,-6,2.4);cam.rotation_euler=(Vector((-.9,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=5.1;sc.camera=cam
m=bpy.data.materials.new('Advected hot combustion volume');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;n.clear()
def node(t):return n.new(t)
def mathn(op,a,b=None):
 o=node('ShaderNodeMath');o.operation=op
 for i,v in enumerate([a,b]):
  if v is None:continue
  if isinstance(v,(int,float)):o.inputs[i].default_value=v
  else:l.new(v,o.inputs[i])
 return o.outputs[0]
def vm(op,a,b=None):
 o=node('ShaderNodeVectorMath');o.operation=op;l.new(a,o.inputs[0])
 if b is not None:
  if isinstance(b,tuple):o.inputs[1].default_value=b
  else:l.new(b,o.inputs[1])
 return o.outputs['Value'] if op=='LENGTH' else o.outputs[0]
def combine(x,y,z):
 o=node('ShaderNodeCombineXYZ')
 for i,v in enumerate([x,y,z]):
  if isinstance(v,(int,float)):o.inputs[i].default_value=v
  else:l.new(v,o.inputs[i])
 return o.outputs[0]
def ramp(v,lo,hi):
 o=node('ShaderNodeMapRange');l.new(v,o.inputs[0]);o.inputs[1].default_value=lo;o.inputs[2].default_value=hi;o.clamp=True;return o.outputs[0]
tex=node('ShaderNodeTexCoord');p=tex.outputs['Object'];xyz=node('ShaderNodeSeparateXYZ');l.new(p,xyz.inputs[0]);x,y,z=[xyz.outputs[i] for i in range(3)]
time=node('ShaderNodeValue');time.name='Loop_phase';time.outputs[0].default_value=0;t=time.outputs[0]
# 3D advection and noise eat through the envelope, rather than coloring a ball.
flow=combine(mathn('ADD',mathn('MULTIPLY',x,1.7),mathn('MULTIPLY',mathn('SINE',t),1.5)),mathn('MULTIPLY',y,2.2),mathn('MULTIPLY',z,2.2))
noise=node('ShaderNodeTexNoise');noise.noise_dimensions='4D';l.new(flow,noise.inputs['Vector']);noise.inputs['Scale'].default_value=1.15;noise.inputs['Detail'].default_value=3.0;noise.inputs['Roughness'].default_value=.7;l.new(mathn('MULTIPLY',mathn('COSINE',t),1.5),noise.inputs['W'])
f=noise.outputs['Fac'];cloud=ramp(f,.38,.73)
warp=vm('MULTIPLY',vm('SUBTRACT',noise.outputs['Color'],(.5,.5,.5)),(.75,.75,.75))
# The head is four unequal interleaving 3D flame lobes, never a sphere.
u=ramp(mathn('DIVIDE',mathn('SUBTRACT',.96,x),2.25),0,1)
swell=mathn('MAXIMUM',mathn('SINE',mathn('MULTIPLY',u,math.pi)),0)
body=0.0
for j,(angle,girth) in enumerate([(.15,.35),(1.8,.28),(3.5,.39),(5.15,.3)]):
 spin=mathn('ADD',angle,mathn('ADD',mathn('MULTIPLY',u,4.2),t))
 roll=mathn('MULTIPLY',swell,.54)
 cy=mathn('MULTIPLY',mathn('COSINE',spin),roll);cz=mathn('MULTIPLY',mathn('SINE',spin),roll)
 cross=vm('LENGTH',combine(0,mathn('SUBTRACT',y,cy),mathn('SUBTRACT',z,cz)))
 thickness=mathn('MULTIPLY',mathn('POWER',swell,.58),girth)
 lobe=ramp(mathn('SUBTRACT',thickness,cross),0,.2)
 body=mathn('MAXIMUM',body,lobe)
# A small elongated ignition core binds the four lobes without filling the head.
core=vm('LENGTH',combine(mathn('MULTIPLY',mathn('SUBTRACT',x,.1),2.0),mathn('MULTIPLY',y,4.8),mathn('MULTIPLY',z,4.8)))
body=mathn('MAXIMUM',body,ramp(mathn('SUBTRACT',1,core),0,.4))
# Three tapering moving strands flow out of the burning mass, each curling in 3D.
taper=ramp(mathn('MULTIPLY',x,-1),0,3.05);width=mathn('MULTIPLY',mathn('SUBTRACT',1,taper),.67)
shape=body
for j in range(3):
 ang=j*math.tau/3
 wave=mathn('ADD',mathn('MULTIPLY',x,3.8),mathn('ADD',t,j*2.1))
 wy=mathn('MULTIPLY',mathn('SINE',wave),mathn('MULTIPLY',taper,.43))
 wz=mathn('MULTIPLY',mathn('COSINE',wave),mathn('MULTIPLY',taper,.36))
 cy=mathn('ADD',mathn('MULTIPLY',taper,math.cos(ang)*.32),wy);cz=mathn('ADD',mathn('MULTIPLY',taper,math.sin(ang)*.32),wz)
 dist=vm('LENGTH',combine(0,mathn('SUBTRACT',y,cy),mathn('SUBTRACT',z,cz)))
 strand=ramp(mathn('SUBTRACT',width,dist),0,.25);strand=mathn('MULTIPLY',strand,ramp(mathn('MULTIPLY',x,-1),0,.5));shape=mathn('MAXIMUM',shape,strand)
raw=mathn('MULTIPLY',shape,cloud);density=mathn('MULTIPLY',raw,4.0)
vol=node('ShaderNodeVolumePrincipled');l.new(mathn('MULTIPLY',raw,10),vol.inputs['Density']);vol.inputs['Color'].default_value=(.14,.058,.024,1);vol.inputs['Anisotropy'].default_value=.18
heat=mathn('ADD',mathn('MULTIPLY',raw,1.35),mathn('MULTIPLY',f,.15))
thermal=node('ShaderNodeValToRGB');thermal.name='Thermal hot core and cooler folds';thermal.color_ramp.interpolation='EASE';thermal.color_ramp.elements.remove(thermal.color_ramp.elements[1])
for i,(stop,color) in enumerate([(0,(.065,.001,.0001,1)),(.16,(.25,.007,.0002,1)),(.33,(.8,.045,.001,1)),(.46,(1,.18,.008,1)),(.61,(1,.46,.065,1)),(.78,(1,.77,.30,1)),(.95,(1,.92,.66,1))]):
 e=thermal.color_ramp.elements[0] if i==0 else thermal.color_ramp.elements.new(stop);e.position=stop;e.color=color
l.new(heat,thermal.inputs[0]);l.new(thermal.outputs['Color'],vol.inputs['Emission Color']);l.new(mathn('MULTIPLY',mathn('POWER',raw,1.1),12),vol.inputs['Emission Strength'])
out=node('ShaderNodeOutputMaterial');l.new(vol.outputs[0],out.inputs['Volume'])
bpy.ops.mesh.primitive_cube_add(size=1,location=(-1.0,0,0));o=bpy.context.object;o.name='Combustion_volume_domain';o.dimensions=(4.5,2.8,2.8);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
# Use an untransformed coordinate anchor so the front combustion center stays x=0.
anchor=bpy.data.objects.new('Volume_coordinate_origin',None);sc.collection.objects.link(anchor);tex.object=anchor
sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGBA';sc.render.fps=30;sc.frame_start=1;sc.frame_end=24
for i in range(25):
 time.outputs[0].default_value=math.tau*i/24;time.outputs[0].keyframe_insert('default_value',frame=i+1)
for action in bpy.data.actions:
 for fc in action.fcurves:
  for point in fc.keyframe_points:point.interpolation='LINEAR'
sc.frame_set(1);sc.render.filepath='//frame_000.png';bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fireball.blend'),compress=True)
for i in (range(24) if args.frames=='all' else [int(x) for x in args.frames.split(',')]):
 sc.frame_set(i+1);sc.render.filepath=str(OUT/('frame_%03d.png'%i));bpy.ops.render.render(write_still=True)

"""Rebuild the projectile from the Archer's actual stored cedar arrow mesh."""
import bpy, math, argparse, sys
from pathlib import Path
from mathutils import Vector, Matrix
p=argparse.ArgumentParser();p.add_argument('--archer',required=True);p.add_argument('--output',required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(Path(a.archer).resolve()))
source=bpy.data.objects['Stored_Arrow_01_Draw_Mesh']; mesh=source.data.copy()
# Work from local original geometry; preserve cedar, wrapping and real feather vanes.
for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
shaft=bpy.data.objects.new('Cedar_shaft_binding_and_fletching',mesh);bpy.context.collection.objects.link(shaft)
zmin=min(v.co.z for v in mesh.vertices);zmax=max(v.co.z for v in mesh.vertices);L=zmax-zmin
shaft_vertices={i for poly in mesh.polygons if poly.material_index <= 2 for i in poly.vertices}
for v in mesh.vertices:
 x,y,z=v.co
 # Preserve the real feather silhouette. Only shaft and serving receive the
 # modest raster-readability correction (~1.2 game pixels, <1px at 960 width).
 transverse=3.5 if v.index in shaft_vertices else 1.8
 v.co=Vector((.40-(z-zmin)/L*.86,x/L*transverse,y/L*transverse))
wood=bpy.data.materials.get('Brown cedar arrow shaft')
if wood and wood.use_nodes:
 wood.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.25,.125,.047,1)
# A narrow forged socketed broadhead, not a flat geometric triangle: bevelled
# silver faces, central ridge, clipped shoulders and a bound socket.
def mat(n,c,metal=0,rough=.5):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*c,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=rough;return m
steel=mat('Forged silver steel',(.42,.49,.53),.78,.31);edge=mat('Honed pale steel edge',(.68,.74,.77),.82,.24)
verts=[(.51,0,0),(.414,-.047,0),(.39,-.027,0),(.39,.027,0),(.414,.047,0),(.435,0,.016),(.435,0,-.012)]
faces=[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5),(0,6,1),(1,6,2),(2,6,3),(3,6,4),(4,6,0)]
me=bpy.data.meshes.new('Forged broadhead geometry');me.from_pydata(verts,[],faces);me.materials.append(steel);me.materials.append(edge);head=bpy.data.objects.new('Forged_arrowhead',me);bpy.context.collection.objects.link(head)
for i,f in enumerate(me.polygons):f.material_index=1 if i in (0,4) else 0
bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.012,depth=.07,location=(.387,0,0),rotation=(0,math.pi/2,0));socket=bpy.context.object;socket.name='Bound_arrowhead_socket';socket.data.materials.append(bpy.data.materials.get('Waxed dark binding'))
# Fixed side-on camera: +X is projectile travel. Native export 4x game size.
scene=bpy.context.scene;scene.use_nodes=False;scene.node_tree.nodes.clear();scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.film_transparent=True;scene.render.resolution_x=160;scene.render.resolution_y=48;scene.render.resolution_percentage=100
camdata=bpy.data.cameras.new('Projectile_camera');cam=bpy.data.objects.new('Projectile_camera',camdata);scene.collection.objects.link(cam);cam.location=(.025,0,3);cam.rotation_euler=(0,0,0);camdata.type='ORTHO';camdata.ortho_scale=1.11;scene.camera=cam
scene.world.color=(.15,.15,.15)
for n,loc,power,size in [('Key',(-.3,-1,2),80,2),('Rim',(1,1,1.2),55,1.5)]:
 d=bpy.data.lights.new(n,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(n,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='Standard';scene.view_settings.look='Medium High Contrast';scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.filepath=str(out/'arrow_base.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'projectile_arrow.blend'));bpy.ops.render.render(write_still=True)
# Accent mask is actual feather and metal surface coverage, never the cedar shaft.
white=mat('Accent coverage',(1,1,1));bs=white.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(1,1,1,1);bs.inputs['Emission Strength'].default_value=1
transparent=bpy.data.materials.new('No accent');transparent.use_nodes=True;nt=transparent.node_tree;nt.nodes.clear();o=nt.nodes.new('ShaderNodeOutputMaterial');t=nt.nodes.new('ShaderNodeBsdfTransparent');nt.links.new(t.outputs[0],o.inputs[0])
for o in [shaft,head,socket]:
 for slot in o.material_slots:
  n=slot.material.name;slot.material=white if ('feather' in n.lower() or 'steel' in n.lower()) else transparent
scene.render.filepath=str(out/'arrow_accent.png');bpy.ops.render.render(write_still=True)

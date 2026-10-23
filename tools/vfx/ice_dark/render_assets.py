"""Deterministic Blender 4.3+ authoring for ice and gravity flipbooks.

Run with Blender, not regular Python:
 blender -b --factory-startup -t 2 --python render_assets.py -- --effect all --output /tmp/ice_dark_frames
Each frame is rendered to straight-alpha RGBA; pack_assets.py creates the game atlases.
No simulation cache, external texture, add-on, or third-party asset is required.
"""
import argparse, math, os, random, sys
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument('--effect', choices=['all','ice_growth','ice_shatter','ice_thaw','dark_vortex'], default='all')
p.add_argument('--output', default='/tmp/ice_dark_frames')
p.add_argument('--preview', action='store_true')
p.add_argument('--frames', help='Optional comma-separated frame indices for individual retakes.')
p.add_argument('--size', type=int, default=256)
p.add_argument('--loop-boundary', action='store_true', help='Also render frame 24 for vortex seam validation; not packed.')
a=p.parse_args(ARGS)
N=24


def material(name, color, alpha=1.0, metallic=0.0, rough=.28, emission=0.0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    ns=m.node_tree.nodes; ns.clear(); out=ns.new('ShaderNodeOutputMaterial')
    bs=ns.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metallic
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Emission Color'].default_value=(*color,1)
    bs.inputs['Emission Strength'].default_value=emission
    if alpha < .999:
        tr=ns.new('ShaderNodeBsdfTransparent'); mix=ns.new('ShaderNodeMixShader'); mix.inputs[0].default_value=alpha
        m.node_tree.links.new(tr.outputs[0],mix.inputs[1]); m.node_tree.links.new(bs.outputs[0],mix.inputs[2]); m.node_tree.links.new(mix.outputs[0],out.inputs[0])
    else: m.node_tree.links.new(bs.outputs[0],out.inputs[0])
    return m


def mesh(name, verts, faces, mats, indices=None):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
    for ma in mats: me.materials.append(ma)
    if indices:
        for poly,idx in zip(me.polygons,indices): poly.material_index=idx
    return ob


def curve(name, points, width, mat):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=1;cu.bevel_depth=width;cu.bevel_resolution=2
    spl=cu.splines.new('POLY');spl.points.add(len(points)-1)
    for po,co in zip(spl.points,points):po.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob);cu.materials.append(mat);return ob


def crystal(name, pos, length, width, rot, mats):
    # Oblique hexagonal prism with a chipped six-facet point.
    verts=[]
    for z,r in [(0,.70),(length*.18,1),(length*.70,.77)]:
        for k in range(6):
            ang=k*math.tau/6;verts.append((math.cos(ang)*width*r,math.sin(ang)*width*r,z))
    verts.append((width*.23,-width*.15,length))
    faces=[]
    for layer in range(2):
        for k in range(6):faces.append((layer*6+k,layer*6+(k+1)%6,(layer+1)*6+(k+1)%6,(layer+1)*6+k))
    for k in range(6):faces.append((12+k,12+(k+1)%6,18))
    faces.append(tuple(reversed(range(6))))
    ob=mesh(name,verts,faces,mats,[(i*7+3)%len(mats) for i in range(len(faces))]);ob.location=pos;ob.rotation_euler=rot;return ob


def setup():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for datablocks in [bpy.data.meshes,bpy.data.curves,bpy.data.materials]:
        for x in list(datablocks):
            if x.users==0:datablocks.remove(x)
    sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.device='CPU';sc.cycles.samples=256;sc.cycles.use_denoising=False
    sc.cycles.max_bounces=4;sc.cycles.transparent_max_bounces=16
    sc.render.resolution_x=a.size;sc.render.resolution_y=a.size;sc.render.resolution_percentage=100
    sc.render.film_transparent=True;sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGBA';sc.render.image_settings.color_depth='8'
    sc.view_settings.view_transform='Standard';sc.view_settings.look='Medium High Contrast';sc.view_settings.exposure=0;sc.view_settings.gamma=1
    sc.world.color=(.12,.16,.22)
    bpy.ops.object.camera_add(location=(0,-6.3,10));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.20))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.0;sc.camera=cam
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,7));bpy.context.object.data.energy=430;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
    bpy.ops.object.light_add(type='AREA',location=(3,1,5));bpy.context.object.data.energy=180;bpy.context.object.data.color=(.22,.56,1);bpy.context.object.data.size=3
    return sc


def ice(t, kind):
    rng=random.Random(2742)
    if kind=='ice_growth':
        opacity=min(1,t/.12);growth=min(1,(t/.85)**.72);spread=1
    elif kind=='ice_shatter':
        opacity=max(0,1-(max(0,t-.36)/.64)**1.5);growth=1;spread=1+1.08*t
    else:
        opacity=(1-t)**1.5;growth=1-.34*t;spread=1
    colors=[(.18,.63,.88),(.35,.86,1.0),(.65,.96,1.0),(.90,1.0,1.0),(.13,.43,.67)]
    body_alpha=opacity*(.38 if kind!='ice_shatter' else .38+.62*min(1,t/.13))
    mats=[material('Ice facet '+str(i),c,body_alpha,.06,.22,.65) for i,c in enumerate(colors)]
    edge=material('Ice glint',(.58,.94,1),opacity*.82,emission=1.1)
    for i in range(14):
        ang=i*math.tau/14+rng.uniform(-.12,.12);radius=rng.uniform(.62,1.04);length=rng.uniform(.65,1.3);width=rng.uniform(.115,.23)
        if kind=='ice_growth':
            local=max(0,min(1,(t-i*.012)/.72));local=math.sin(local*math.pi*.5);lg=length*local
        else:lg=length*growth
        z=.03
        if kind=='ice_shatter':
            # Launch outward, tumble, and shrink: no rigid starburst still-frame.
            radius=radius*spread + .15*t
            z=.15+math.sin(t*math.pi)*rng.uniform(.25,.65)-.2*t
            lg*=max(.05,1-.75*t)
        tilt=rng.uniform(.3,.75)
        rot=(math.sin(ang)*tilt, -math.cos(ang)*tilt,ang)
        if kind=='ice_shatter':rot=(rot[0]+t*rng.uniform(-4,4),rot[1]+t*rng.uniform(-3,3),rot[2]+t*3)
        if kind=='ice_thaw':z-=.28*t
        if lg>.005:
            ob=crystal('Ice shard %02d'%i,(math.cos(ang)*radius,math.sin(ang)*radius,z),lg,width*growth,rot,mats)
            # High-transparency faces plus narrow luminous fracture edges preserve enemy visibility.
            q=ob.rotation_euler.to_quaternion(); w=width*growth
            for corner in (1,4):
                aa=corner*math.tau/6
                local=[Vector((math.cos(aa)*w*.7,math.sin(aa)*w*.7,0)),Vector((math.cos(aa)*w,math.sin(aa)*w,lg*.18)),Vector((math.cos(aa)*w*.77,math.sin(aa)*w*.77,lg*.70)),Vector((w*.23,-w*.15,lg))]
                curve('Ice luminous facet edge',[tuple(ob.location+q@v) for v in local],.011*growth,edge)
    # Tiny detached splinters and glints enrich shattering without hiding the subject.
    if kind=='ice_shatter':
        for i in range(18):
            ang=rng.random()*math.tau;radius=.55+t*rng.uniform(.7,1.7);z=.1+math.sin(math.pi*t)*rng.uniform(.1,.7)
            l=rng.uniform(.09,.25)*(1-t)
            if l>.005:crystal('Fine splinter',(math.cos(ang)*radius,math.sin(ang)*radius,z),l,l*.21,(t*4,ang,t*7),mats)
    elif kind=='ice_growth':
        # Faceted thin frost creases leave the enemy silhouette unobscured.
        for i in range(7):
            ang=i*math.tau/7;rr=.38+.33*growth
            pts=[(math.cos(ang)*rr*.28,math.sin(ang)*rr*.28,.02),(math.cos(ang+.12)*rr*.64,math.sin(ang+.12)*rr*.64,.025),(math.cos(ang-.08)*rr,math.sin(ang-.08)*rr,.04)]
            curve('Frost vein',pts,.010*growth,edge)
    elif kind=='ice_thaw':
        mist=material('Thaw motes',(.28,.65,.86),opacity*.32,emission=.25)
        for i in range(16):
            ang=rng.random()*math.tau;rad=rng.uniform(.5,1.1);z=t*.8+rng.random()*.2
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.028*(1+t),location=(math.cos(ang)*rad,math.sin(ang)*rad,z));bpy.context.object.data.materials.append(mist)


def vortex(t):
    phase=t*math.tau
    # Actual twisted 3D ribbons, layered in depth with tapered widths and open gaps.
    body=material('Vortex deep violet',(.12,.016,.23),.65,.15,.35,.18)
    mid=material('Vortex lilac',(.36,.055,.60),.72,.1,.3,.6)
    bright=material('Vortex hot edge',(.74,.16,.70),.83,emission=.95)
    fine=material('Vortex silver violet',(.57,.39,.90),.65,emission=.7)
    for arm in range(3):
        offset=arm*math.tau/3+phase
        verts=[];faces=[];n=76
        for j in range(n):
            u=j/(n-1);radius=.18+1.62*u
            theta=offset-5.30*(1-u)+.095*math.sin(u*math.tau*2+phase*2+arm)
            taper=math.sin(math.pi*u)**.75 * (.52+.48*math.sin(u*26+phase*2+arm)**2)
            width=(.018+(.075+.022*arm)*u)*taper
            z=.10+.15*math.sin(u*math.pi+arm*.7+phase)
            for side in [-1,1]:
                r=radius+width*side
                verts.append((math.cos(theta)*r,math.sin(theta)*r,z+side*.02))
            if j<n-1:faces.append((2*j,2*j+1,2*j+3,2*j+2))
        wave_mats=[]
        for band in range(12):
            v=band/11
            wave_mats.append(material('Stream gradient %d %d'%(arm,band),(.11+.31*v,.015+.06*v,.20+.48*v),.25+.55*v,emission=.25+.6*v))
        indices=[]
        for j in range(n-1):
            u=j/(n-1)
            # Two bright pulses travel inward along a stable spiral each loop.
            pulse=(.5+.5*math.sin(u*math.tau*2+phase*2+arm))**5
            indices.append(min(11,int((.25+.75*pulse)*11)))
        mesh('Accretion ribbon',verts,faces,wave_mats,indices)
        # Very fine asymmetrical edge filaments, not a broad opaque neon donut.
        pts=[]
        for j in range(60):
            u=.15+.79*j/59;radius=.18+1.62*u;theta=offset-5.30*(1-u)+.095*math.sin(u*math.tau*2+phase*2+arm)
            pts.append((math.cos(theta)*(radius+.055),math.sin(theta)*(radius+.055),.14+.15*math.sin(u*math.pi+arm*.7+phase)))
        curve('Accretion lip',pts,.006 if arm%2 else .009,bright if arm%2 else fine)
    # Secondary strands have unequal lengths and altitude; they flow inward rather than forming fan blades.
    for strand in range(7):
        offset=strand*math.tau/7+phase + .23*math.sin(strand*2.1)
        end=.66+.30*((strand*3)%7)/7
        pts=[]
        for j in range(72):
            u=.08+(end-.08)*j/71; radius=.13+1.80*u
            theta=offset-6.5*(1-u)+.045*math.sin(u*24+strand+phase)
            pts.append((math.cos(theta)*radius,math.sin(theta)*radius,.06+.07*math.sin(u*11+phase+strand)))
        curve('Infall filament',pts,.0035+(strand%3)*.0015,mid if strand%2 else fine)
    # Slender tilted inner lens, with a dark transparent core so the arrow remains readable.
    pts=[]
    for j in range(90):
        u=j/89;ang=u*math.tau
        pts.append((math.cos(ang)*.28,math.sin(ang)*.23,.19+.025*math.sin(ang*3+phase)))
    curve('Event horizon lip',pts,.027,mid)
    core=material('Soft dark core',(.018,.006,.042),.64,emission=.05)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=12,radius=1,location=(0,0,.12));ob=bpy.context.object;ob.scale=(.255,.215,.055);ob.data.materials.append(core)
    # Orbiting diamonds, with continuous cyclic motion and no random resampling.
    rng=random.Random(615)
    for i in range(16):
        seed=rng.random(); travel=(seed+t)%1.0
        r=1.9-1.65*travel
        ang=rng.random()*math.tau+phase+travel*3.2
        envelope=math.sin(math.pi*travel)**.65
        pos=(r*math.cos(ang),r*math.sin(ang),rng.uniform(.05,.2));size=rng.uniform(.025,.052)*envelope
        ob=crystal('Infall fragment',pos,size*2,size*.55,(math.pi*.5,0,ang),[fine,bright,mid]);ob.rotation_euler.z=ang
        pts=[]
        for j in range(8):
            q=j/7;rr=r+.12*q;aa=ang-.15*q
            pts.append((rr*math.cos(aa),rr*math.sin(aa),pos[2]))
        curve('Infall streak',pts,.004*envelope,mid)


os.makedirs(a.output,exist_ok=True)
effects=['ice_growth','ice_shatter','ice_thaw','dark_vortex'] if a.effect=='all' else [a.effect]
for effect in effects:
    directory=os.path.join(a.output,effect);os.makedirs(directory,exist_ok=True)
    frames=[0,5,11,17,23] if a.preview else range(N)
    if a.loop_boundary and effect=='dark_vortex': frames=list(frames)+[N]
    if a.frames: frames=[int(value) for value in a.frames.split(',')]
    for frame in frames:
        sc=setup();t=frame/N if effect=='dark_vortex' else frame/(N-1)
        if effect=='dark_vortex':vortex(t)
        else:ice(t,effect)
        sc.render.filepath=os.path.join(directory,'%03d.png'%frame)
        bpy.ops.render.render(write_still=True)

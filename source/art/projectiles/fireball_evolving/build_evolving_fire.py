"""Blender 4.5.15 / Cycles CPU builder for original evolving flame tongues.

This file NEVER starts Blender, Godot, or an encoder. Invoke it inside Blender
only during an authorized render window. Default operation creates the scene
without rendering. --frames explicitly opts into a bounded keyframe proof.
Motion combines a real geometric lifecycle with head-only gas-source UV transport, baked into the pose atlas.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from evolving_geometry import make_tongues, vertices, faces, source_uv, controls, HEAD_CROP_SPECS


def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, default=HERE/'source_gas/gas_straight_rgba.png')
    p.add_argument('--source-prompt', type=Path, default=HERE/'source_gas/black_prompt.txt')
    p.add_argument('--source-provenance', type=Path, default=HERE/'source_gas/gas_alpha_provenance.json')
    p.add_argument('--source-mode', choices=['branch'], default='branch')
    p.add_argument('--orientation', choices=['base-right','base-left','base-up'], default='base-right')
    p.add_argument('--out', type=Path, default=Path('/tmp/ragecat-evolving-fire-frames'))
    p.add_argument('--frames', default='none', help='none, all, or comma-separated zero-based frame IDs')
    p.add_argument('--loop-frames', type=int, default=32)
    p.add_argument('--samples', type=int, default=2)
    p.add_argument('--quality',choices=['proof','final'],default='proof',help='proof: 1–8 samples; final: explicitly 64 or 128 samples only.')
    p.add_argument('--threads', type=int, default=2)
    p.add_argument('--width', type=int, default=192)
    p.add_argument('--height', type=int, default=128)
    p.add_argument('--steps', type=int, default=36)
    p.add_argument('--across', type=int, default=6)
    p.add_argument('--seed', type=int, default=24026)
    p.add_argument('--view-width', type=float, default=4.8)
    p.add_argument('--time-budget-seconds', type=float, default=55)
    p.add_argument('--max-rss-mib', type=float, default=740)
    p.add_argument('--save-blend', action='store_true')
    p.add_argument('--bake-loop', action='store_true', help='Bake shape keys and material controls; otherwise direct-update proof only.')
    p.add_argument('--burn-strength',type=float,default=0.0,help='Defaults to 0: preserve the real gas source; optional rear burn-through remains bounded 0..1.')
    p.add_argument('--flat-proof', action='store_true', help='Diagnostic colored tongues, not final fire material.')
    return p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


def validate_quality_limits(args):
    # Only the explicitly authorized sample count changes; dimensions and all
    # independent resource/time guards are retained without expansion.
    if args.width>384 or args.height>256:
        raise ValueError('Resolution guard unchanged: at most 384x256.')
    if args.quality=='proof' and not 1<=args.samples<=8:
        raise ValueError('Proof quality permits only 1–8 samples.')
    if args.quality=='final' and args.samples not in (64,128):
        raise ValueError('Final quality requires explicit --samples 64 or --samples 128.')


def current_rss_mib():
    try:
        for line in Path('/proc/self/status').read_text().splitlines():
            if line.startswith('VmRSS:'):
                return int(line.split()[1])/1024
    except OSError:
        pass
    return None


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_material(bpy, tongue, image, args):
    m=bpy.data.materials.new(tongue.name+'_straight_alpha_material')
    m.use_nodes=True
    # Transparent+Emission is composited once, never additive layer accumulation.
    if hasattr(m,'surface_render_method'):
        m.surface_render_method='DITHERED'
    n=m.node_tree.nodes
    links=m.node_tree.links
    n.clear()
    def node(kind, name=None):
        q=n.new(kind)
        if name:
            q.name=name
        return q
    def calc(op, a, b=None):
        q=node('ShaderNodeMath')
        q.operation=op
        for i,value in enumerate((a,b)):
            if value is None:
                continue
            if isinstance(value,(int,float)):
                q.inputs[i].default_value=value
            else:
                links.new(value,q.inputs[i])
        return q.outputs[0]
    def smoother(value,lo,hi):
        q=node('ShaderNodeMapRange')
        q.interpolation_type='SMOOTHSTEP'
        q.clamp=True
        links.new(value,q.inputs['Value'])
        q.inputs['From Min'].default_value=lo
        q.inputs['From Max'].default_value=hi
        return q.outputs['Result']
    def value_node(name):
        q=node('ShaderNodeValue',name)
        q.outputs[0].default_value=0
        return q
    c={name:value_node(name) for name in ['opacity','rupture','tip_death','age']}
    uv=node('ShaderNodeUVMap')
    uv.uv_map='SourceFoldUV'
    tex=node('ShaderNodeTexImage','Original_gas_flame_color_source')
    tex.image=image
    tex.extension='CLIP'
    tex.interpolation='Linear'
    links.new(uv.outputs[0],tex.inputs['Vector'])
    logical=node('ShaderNodeUVMap')
    logical.uv_map='LifecycleUV'
    sep=node('ShaderNodeSeparateXYZ')
    links.new(logical.outputs[0],sep.inputs[0])
    u,v=sep.outputs[0],sep.outputs[1]
    if tongue.head:
        # Positive source X shift transports gas features backwards along +u.
        # Only the tiny leading point is protected, not the whole front half.
        source_xy=node('ShaderNodeSeparateXYZ')
        links.new(uv.outputs[0],source_xy.inputs[0])
        moved=node('ShaderNodeCombineXYZ')
        speed=HEAD_CROP_SPECS[int(tongue.name.rsplit('_',1)[1])][4]
        shift=calc('MULTIPLY',speed,calc('MULTIPLY',c['age'].outputs[0],smoother(u,.01,.10)))
        links.new(calc('ADD',source_xy.outputs[0],shift),moved.inputs[0])
        links.new(source_xy.outputs[1],moved.inputs[1])
        for previous in list(tex.inputs['Vector'].links): links.remove(previous)
        links.new(moved.outputs[0],tex.inputs['Vector'])
    edge=calc('SUBTRACT',1,smoother(calc('ABSOLUTE',calc('SUBTRACT',calc('MULTIPLY',v,2),1)),.70,1))
    neck=calc('SUBTRACT',1,smoother(calc('ABSOLUTE',calc('SUBTRACT',u,tongue.neck_u)),.026,.085))
    gap=calc('SUBTRACT',1,calc('MULTIPLY',neck,c['rupture'].outputs[0]))
    tip=calc('SUBTRACT',1,calc('MULTIPLY',smoother(u,tongue.neck_u+.01,tongue.neck_u+.17),c['tip_death'].outputs[0]))
    alpha=calc('MULTIPLY',c['opacity'].outputs[0],calc('MULTIPLY',edge,calc('MULTIPLY',gap,tip)))
    if not args.flat_proof:
        alpha=calc('MULTIPLY',alpha,tex.outputs['Alpha'])
    # Optional low-frequency coherent burn-through advects along each living ribbon.
    # This exact warped-wave field is mirrored in evolving_material.py for tests.
    # Optional burn-through changes opacity, not coordinates. Head-only UV
    # transport above is independent, and the geometric lifecycle stays intact.
    age=c['age'].outputs[0]
    q=calc('ADD',calc('SUBTRACT',calc('MULTIPLY',u,3.4),calc('MULTIPLY',age,1.6)),tongue.seed)
    r=calc('ADD',calc('MULTIPLY',calc('SUBTRACT',v,.5),2.1),tongue.seed*.31)
    a_wave=calc('SINE',calc('ADD',calc('MULTIPLY',q,2.4),calc('MULTIPLY',.9,calc('SINE',calc('ADD',calc('MULTIPLY',r,2.2),calc('MULTIPLY',q,.6))))))
    b_wave=calc('SINE',calc('ADD',calc('SUBTRACT',calc('MULTIPLY',r,3.0),calc('MULTIPLY',q,1.35)),calc('MULTIPLY',.7,calc('SINE',calc('ADD',calc('MULTIPLY',q,1.3),r)))))
    field=calc('ADD',.5,calc('ADD',calc('MULTIPLY',a_wave,.28),calc('MULTIPLY',b_wave,.22)))
    geometry=node('ShaderNodeNewGeometry')
    world=node('ShaderNodeSeparateXYZ')
    links.new(geometry.outputs['Position'],world.inputs[0])
    rear=calc('SUBTRACT',1,smoother(world.outputs[0],-.40,.05))
    side=smoother(calc('ABSOLUTE',calc('SUBTRACT',calc('MULTIPLY',v,2),1)),.25,.90)
    luminance=node('ShaderNodeRGBToBW')
    links.new(tex.outputs['Color'],luminance.inputs[0])
    heat=smoother(luminance.outputs[0],.30,.72)
    hole=smoother(calc('ADD',field,calc('MULTIPLY',side,.12)),.58,.77)
    retained=calc('MULTIPLY',calc('ADD',.48,calc('MULTIPLY',heat,.44)),calc('SUBTRACT',1,calc('MULTIPLY',hole,calc('SUBTRACT',.94,calc('MULTIPLY',heat,.37)))))
    burned_alpha=calc('SUBTRACT',1,calc('MULTIPLY',args.burn_strength,calc('MULTIPLY',rear,calc('SUBTRACT',1,retained))))
    if not args.flat_proof:
        alpha=calc('MULTIPLY',alpha,burned_alpha)
    ridge=calc('SUBTRACT',1,smoother(calc('ABSOLUTE',calc('SUBTRACT',field,.56)),.025,.10))
    accent=calc('ADD',1,calc('MULTIPLY',.18*args.burn_strength,calc('MULTIPLY',rear,calc('MULTIPLY',heat,ridge))))
    # Straight source RGB goes only to color. Opacity is NOT multiplied into RGB.
    emission=node('ShaderNodeEmission')
    emission.inputs['Strength'].default_value=1.0
    if not args.flat_proof:
        links.new(accent,emission.inputs['Strength'])
    if args.flat_proof:
        emission.inputs['Color'].default_value=(.95,.1+.12*(int(tongue.name[-2:])%4),.015,1)
    else:
        tint=node('ShaderNodeMixRGB')
        tint.blend_type='MULTIPLY'
        tint.inputs[0].default_value=1
        links.new(tex.outputs['Color'],tint.inputs[1])
        # No new broad white core: retain the source's narrow hottest folds.
        tint.inputs[2].default_value=(1.0,tongue.heat,.55+.35*tongue.heat,1)
        links.new(tint.outputs[0],emission.inputs['Color'])
    transparent=node('ShaderNodeBsdfTransparent')
    mix=node('ShaderNodeMixShader')
    links.new(alpha,mix.inputs[0])
    links.new(transparent.outputs[0],mix.inputs[1])
    links.new(emission.outputs[0],mix.inputs[2])
    output=node('ShaderNodeOutputMaterial')
    links.new(mix.outputs[0],output.inputs['Surface'])
    return m,c


def set_controls(control_nodes,tongue,t,keyframe=None):
    c=controls(tongue,t)
    for name,node in control_nodes.items():
        node.outputs[0].default_value=c[name]
        if keyframe is not None:
            node.outputs[0].keyframe_insert('default_value',frame=keyframe)


def bake_animation(ob,control_nodes,tongue,args):
    ob.shape_key_add(name='Basis')
    for frame in range(args.loop_frames):
        key=ob.shape_key_add(name=f'Loop_{frame:02d}')
        key.data.foreach_set('co',[v for p in vertices(tongue,frame/args.loop_frames,args.steps,args.across) for v in p])
        # A one-hot piecewise-linear basis, with a duplicate closing pose.
        points=[(1,0),(args.loop_frames+1,0)]
        if frame==0:
            points=[(1,1),(2,0),(args.loop_frames,0),(args.loop_frames+1,1)]
        else:
            points += [(frame,0),(frame+1,1),(frame+2,0)]
        for f,value in sorted(dict(points).items()):
            key.value=value
            key.keyframe_insert('value',frame=f)
    for frame in range(args.loop_frames+1):
        set_controls(control_nodes,tongue,frame/args.loop_frames,keyframe=frame+1)


def build_scene(args):
    import bpy
    from mathutils import Vector
    if bpy.app.version[:2] != (4,5):
        raise RuntimeError(f'Expected Blender 4.5.x; got {bpy.app.version_string}. Do not switch runtimes silently.')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene
    sc.render.engine='CYCLES'
    sc.cycles.device='CPU'
    sc.cycles.samples=args.samples
    sc.cycles.seed=args.seed
    sc.cycles.use_animated_seed=False
    sc.cycles.use_denoising=False
    sc.cycles.use_adaptive_sampling=False
    sc.cycles.max_bounces=1
    sc.cycles.diffuse_bounces=0
    sc.cycles.glossy_bounces=0
    sc.cycles.transmission_bounces=0
    sc.cycles.volume_bounces=0
    sc.cycles.transparent_max_bounces=16
    sc.render.threads_mode='FIXED'
    sc.render.threads=args.threads
    sc.render.use_persistent_data=True
    sc.render.film_transparent=True
    sc.render.resolution_x=args.width
    sc.render.resolution_y=args.height
    sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'
    sc.render.image_settings.color_mode='RGBA'
    sc.render.image_settings.color_depth='8'
    sc.view_settings.view_transform='Standard'
    sc.view_settings.look='None'
    sc.view_settings.exposure=0
    sc.view_settings.gamma=1
    sc.render.fps=args.loop_frames
    sc.frame_start=1
    sc.frame_end=args.loop_frames
    sc.world=bpy.data.worlds.new('No_environment_light')
    sc.world.use_nodes=True
    sc.world.node_tree.nodes['Background'].inputs[0].default_value=(0,0,0,1)
    sc.world.node_tree.nodes['Background'].inputs[1].default_value=0
    camera_data=bpy.data.cameras.new('Stationary_orthographic_camera')
    camera=bpy.data.objects.new('Stationary_orthographic_camera',camera_data)
    sc.collection.objects.link(camera)
    camera.location=(-.70,-7.0,0)
    camera.rotation_euler=(Vector((-.70,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO'
    camera_data.sensor_fit='HORIZONTAL'
    camera_data.ortho_scale=args.view_width
    camera_data.clip_start=.1
    camera_data.clip_end=20
    sc.camera=camera
    image=bpy.data.images.load(str(args.source.resolve()),check_existing=True)
    image.alpha_mode='STRAIGHT'
    image.colorspace_settings.name='sRGB'
    image.pack()
    tongues=make_tongues(args.seed,args.loop_frames)
    objects=[]
    for tongue in tongues:
        mesh=bpy.data.meshes.new(tongue.name+'_evolving_mesh')
        mesh.from_pydata(vertices(tongue,0,args.steps,args.across),[],faces(args.steps,args.across))
        mesh.update()
        material,control_nodes=make_material(bpy,tongue,image,args)
        mesh.materials.append(material)
        ob=bpy.data.objects.new(tongue.name,mesh)
        sc.collection.objects.link(ob)
        ob['motion_method']='Procedural birth, growth, backwards convection, curl, neck rupture, and tip death. Head-only gas-source UV transport supplements the geometric lifecycle.'
        ob['collision_radius']=1.0
        ob['source_branch']=tongue.branch
        for name in ['SourceFoldUV','LifecycleUV']:
            layer=mesh.uv_layers.new(name=name)
            for loop in mesh.loops:
                vi=loop.vertex_index
                u=(vi//(args.across+1))/args.steps
                v=(vi%(args.across+1))/args.across
                layer.data[loop.index].uv=(source_uv(tongue,u,v*2-1,args.orientation,args.source_mode)
                                           if name=='SourceFoldUV' else (u,v))
        set_controls(control_nodes,tongue,0)
        if args.bake_loop:
            bake_animation(ob,control_nodes,tongue,args)
        objects.append((ob,control_nodes,tongue))
    if args.bake_loop:
        for action in bpy.data.actions:
            for curve in action.fcurves:  # Blender 4.5 supported legacy compatibility API.
                for key in curve.keyframe_points:
                    key.interpolation='LINEAR'
    sc['original_material_source']=str(args.source.resolve())
    sc['motion_provenance']='Original generated gas-flame color source, geometric lifecycle, and head-only UV transport baked offline.'
    sc['loop_frames']=args.loop_frames
    sc['leading_collision_x']=1.0
    sc['view_width_world']=args.view_width
    sc.frame_set(1)
    return bpy,sc,objects


def update_pose(sc,objects,frame,args):
    t=frame/args.loop_frames
    sc.frame_set(frame+1)
    if not args.bake_loop:
        for ob,control_nodes,tongue in objects:
            ob.data.vertices.foreach_set('co',[v for p in vertices(tongue,t,args.steps,args.across) for v in p])
            ob.data.update()
            set_controls(control_nodes,tongue,t)


def main():
    started=time.monotonic()
    args=parse_args()
    if not args.source.is_file():
        raise FileNotFoundError(f'Original isolated tongue source missing: {args.source}')
    if args.source_provenance.is_file():
        provenance=json.loads(args.source_provenance.read_text())
        expected=provenance.get('output_sha256')
        if expected and sha256(args.source)!=expected:
            raise ValueError('Gas source hash does not match its alpha-conversion provenance.')
    if not 0<=args.burn_strength<=1:
        raise ValueError('--burn-strength must stay within 0..1.')
    if args.loop_frames < 24 or args.loop_frames > 32:
        raise ValueError('This prototype explicitly targets 24–32 unique poses.')
    validate_quality_limits(args)
    if args.frames=='none':
        requested=[]
    elif args.frames=='all':
        requested=list(range(args.loop_frames))
    else:
        requested=[int(x) for x in args.frames.split(',')]
    if any(f<0 or f>=args.loop_frames for f in requested):
        raise ValueError('Frame ID is outside the configured loop.')
    args.out.mkdir(parents=True,exist_ok=True)
    bpy,sc,objects=build_scene(args)
    if args.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=str((args.out/'evolving_fire.blend').resolve()),compress=True)
    summary={
        'source_file':str(args.source.resolve()),'source_sha256':sha256(args.source),
        'geometry_script_sha256':sha256(HERE/'evolving_geometry.py'),
        'builder_script_sha256':sha256(Path(__file__).resolve()),
        'material_reference_sha256':sha256(HERE/'evolving_material.py'),
        'material_revision':'Original gas straight-alpha source with head-only UV transport; optional erosion disabled',
        'geometry_revision':'Release head patches: local lower shoulder <=.032R and upper shoulder <=.025R; six outer tongues unchanged',
        'head_source_transport':'positive source-X, continuous age, leading u<=.01 fixed; full transport by u=.10; reset hidden by zero lifecycle opacity',
        'head_crop_specs':HEAD_CROP_SPECS,
        'head_patch_uv_rectangles':[list(spec[:4]) for spec in HEAD_CROP_SPECS],
        'pixel_safety_thresholds':{'alpha_0.1_both_sides_min_R':.9,'alpha_0.5_both_sides_min_R':.75},
        'head_lifecycle_cycles':[1,2,1,2],
        'burn_strength':args.burn_strength,
        'source_prompt_file':str(args.source_prompt.resolve()),
        'source_prompt_sha256':sha256(args.source_prompt) if args.source_prompt.is_file() else None,
        'source_provenance_file':str(args.source_provenance.resolve()),
        'motion':'original gas-flame artwork plus geometric lifecycle and head-only UV transport, baked offline',
        'source_sampling':'four head surfaces use near-isometric internal 2D gas patches; six outer tongues retain their internal filament paths; cropped right edge excluded',
        'unique_frames':args.loop_frames,'loop_seconds':1.0,'width':args.width,'height':args.height,
        'view_width':args.view_width,'pixels_per_collision_radius':args.width/args.view_width,
        'camera_center_x':-.70,'collision_radius':1.0,'leading_collision_x':1.0,
        'tongues':len(objects),'contour_tongues':6,'ignition_tongues':4,
        'object_transforms_animated':False,'alpha':'straight source RGB; source alpha and lifecycle applied once in transparent/emission mix',
        'blender_version':bpy.app.version_string,'engine':'Cycles CPU','threads':args.threads,'samples':args.samples,'quality_mode':args.quality,
        'seed':args.seed,'baked_animation':args.bake_loop,'requested_frames':requested,
        'rendered_frames':[],'stopped_reason':None,
    }
    meta=args.out/'render_manifest.json'
    meta.write_text(json.dumps(summary,indent=2)+'\n')
    for frame in requested:
        elapsed=time.monotonic()-started
        rss=current_rss_mib()
        if elapsed>=args.time_budget_seconds or (rss is not None and rss>args.max_rss_mib):
            summary['stopped_reason']='time budget reached' if elapsed>=args.time_budget_seconds else 'RSS guard reached'
            break
        update_pose(sc,objects,frame,args)
        sc.render.filepath=str((args.out/f'frame_{frame:03d}.png').resolve())
        before=time.monotonic()
        bpy.ops.render.render(write_still=True)
        summary['rendered_frames'].append({'frame':frame,'seconds':time.monotonic()-before,'rss_mib':current_rss_mib()})
        summary['elapsed_seconds']=time.monotonic()-started
        meta.write_text(json.dumps(summary,indent=2)+'\n')
        print('EVOLVING_FIRE_FRAME',frame,'ELAPSED',round(summary['elapsed_seconds'],3),'RSS_MIB',current_rss_mib(),flush=True)
    summary['elapsed_seconds']=time.monotonic()-started
    summary['complete_requested_frames']=len(summary['rendered_frames'])==len(requested)
    meta.write_text(json.dumps(summary,indent=2)+'\n')
    print('EVOLVING_FIRE_RESULT',json.dumps(summary),flush=True)
    if not summary['complete_requested_frames']:
        raise SystemExit(2)


if __name__=='__main__':
    main()

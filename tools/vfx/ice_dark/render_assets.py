"""Original restrained ice and dark-material flipbooks, authored in Blender 4.3+.

Only native meshes, lights and procedural materials are used. Regeneration is
fully deterministic and never borrows a texture, model, or simulation cache.
See README.md for packing and registration contracts.
"""
import argparse
import math
import os
import random
import sys

import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--effect', choices=['all', 'ice_growth', 'ice_shatter', 'ice_thaw', 'dark_vortex'], default='all')
p.add_argument('--output', default='/tmp/ice_dark_frames')
p.add_argument('--preview', action='store_true')
p.add_argument('--frames', help='Comma-separated frame indices for retakes.')
p.add_argument('--size', type=int, default=256)
p.add_argument('--samples', type=int, default=64)
p.add_argument('--loop-boundary', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
N = 24
ICE_PALETTE = [(.16, .29, .40), (.25, .43, .59), (.39, .65, .82), (.62, .81, .90), (.10, .22, .34)]


def material(name, color, alpha=1.0, rough=.34, grain=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    ns = m.node_tree.nodes
    ns.clear()
    out = ns.new('ShaderNodeOutputMaterial')
    bs = ns.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Specular IOR Level'].default_value = .32
    # There is deliberately no emission or bloom. Shaded volume reads as ice.
    if grain:
        noise = ns.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 25
        noise.inputs['Detail'].default_value = 2
        bump = ns.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .13
        bump.inputs['Distance'].default_value = .035
        m.node_tree.links.new(noise.outputs['Fac'], bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'], bs.inputs['Normal'])
    if alpha < .999:
        transparent = ns.new('ShaderNodeBsdfTransparent')
        mix = ns.new('ShaderNodeMixShader')
        mix.inputs[0].default_value = alpha
        m.node_tree.links.new(transparent.outputs[0], mix.inputs[1])
        m.node_tree.links.new(bs.outputs[0], mix.inputs[2])
        m.node_tree.links.new(mix.outputs[0], out.inputs[0])
    else:
        m.node_tree.links.new(bs.outputs[0], out.inputs[0])
    return m


def mesh(name, verts, faces, mats, indices=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for ma in mats:
        me.materials.append(ma)
    if indices:
        for poly, idx in zip(me.polygons, indices):
            poly.material_index = idx
    return ob


def crystal(name, pos, length, width, rot, mats, seed):
    """Irregular broad prism: different side widths, chipped shoulder and tip."""
    rng = random.Random(seed)
    radii = [rng.uniform(.72, 1.18) for _ in range(6)]
    verts = []
    for z, r, turn in [(0, .78, 0), (length * .28, 1, .05), (length * .69, .80, -.07)]:
        for k in range(6):
            angle = k * math.tau / 6 + turn
            verts.append((math.cos(angle) * width * r * radii[k], math.sin(angle) * width * r * radii[k], z))
    verts.extend([(width * .31, -width * .13, length), (-width * .18, width * .17, length * .93)])
    faces = []
    for layer in range(2):
        for k in range(6):
            faces.append((layer * 6 + k, layer * 6 + (k + 1) % 6, (layer + 1) * 6 + (k + 1) % 6, (layer + 1) * 6 + k))
    for k in range(6):
        faces.append((12 + k, 12 + (k + 1) % 6, 18 if k < 3 else 19))
    faces.extend([(12, 18, 19), (15, 19, 18), tuple(reversed(range(6)))])
    ob = mesh(name, verts, faces, mats, [(i * 3 + seed) % len(mats) for i in range(len(faces))])
    ob.location = pos
    ob.rotation_euler = rot
    return ob


def setup():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for blocks in [bpy.data.meshes, bpy.data.curves, bpy.data.materials]:
        for block in list(blocks):
            if block.users == 0:
                blocks.remove(block)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = a.samples
    sc.cycles.use_denoising = False
    sc.cycles.seed = 2742
    sc.cycles.max_bounces = 4
    sc.cycles.transparent_max_bounces = 16
    sc.render.resolution_x = a.size
    sc.render.resolution_y = a.size
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'Medium High Contrast'
    sc.view_settings.exposure = 0
    sc.view_settings.gamma = 1
    sc.world.color = (.16, .18, .20)
    bpy.ops.object.camera_add(location=(0, -6.3, 10))
    cam = bpy.context.object
    cam.rotation_euler = (Vector((0, 0, .20)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 5.0
    sc.camera = cam
    bpy.ops.object.light_add(type='AREA', location=(-3, -4, 7))
    bpy.context.object.data.energy = 370
    bpy.context.object.data.size = 4
    bpy.ops.object.light_add(type='AREA', location=(3, 1, 5))
    bpy.context.object.data.energy = 150
    bpy.context.object.data.color = (.65, .78, .88)
    bpy.context.object.data.size = 3
    return sc


def ice(t, kind):
    # Shared descriptors give identical shell / shatter / thaw registration at
    # the transition. No random stream is sampled differently by animation kind.
    rng = random.Random(2742)
    descriptors = []
    for i in range(11):
        angle = i * math.tau / 11 + rng.uniform(-.20, .20)
        descriptors.append((angle, rng.uniform(.62, .91), rng.uniform(.98, 1.56), rng.uniform(.20, .30), rng.uniform(.13, .36), rng.uniform(-3, 3), rng.uniform(-3, 3)))
    fade = 1.0
    if kind == 'ice_shatter':
        fade = max(0.0, 1 - max(0.0, t - .42) / .58) ** 1.1
    elif kind == 'ice_thaw':
        fade = (1 - t) ** 1.35
    if fade <= 0 or (kind == 'ice_growth' and t <= 0):
        return
    opacity = .54 * fade
    mats = [material('Gray-blue ice facet %d' % i, color, opacity, .24 + i * .045, True) for i, color in enumerate(ICE_PALETTE)]
    frost = material('Matte white root frost', (.64, .70, .71), .44 * fade, .66, True)
    catch = material('Sparse frost face catch', (.74, .90, .96), .60 * fade, .34)
    for i, (angle, radius, length, width, tilt, tumble_x, tumble_y) in enumerate(descriptors):
        # Frost grows from roots in slightly different phases, not by enlarging
        # the complete effect or moving it off the actor's local center.
        local = min(1.0, max(0.0, (t - i * .010) / .82)) if kind == 'ice_growth' else 1.0
        growth = math.sin(local * math.pi * .5)
        if growth <= .002:
            continue
        z = .03
        if kind == 'ice_shatter':
            radius += t * (1.08 + .13 * (i % 3))
            z += math.sin(t * math.pi) * (.28 + .10 * (i % 4)) - .13 * t
            growth *= 1 - .66 * t
        elif kind == 'ice_thaw':
            growth *= 1 - .68 * t
            z -= .18 * t
        rot = (math.sin(angle) * tilt, -math.cos(angle) * tilt, angle)
        if kind == 'ice_shatter':
            rot = (rot[0] + t * tumble_x, rot[1] + t * tumble_y, rot[2] + t * 2.1)
        ob = crystal('Broad ice facet %02d' % i, (math.cos(angle) * radius, math.sin(angle) * radius, z), length * growth, width * growth, rot, mats, 100 + i)
        if i % 2 == 0:
            # One short broken catch on selected faces, not a continuous edge.
            w, h = width * growth, length * growth
            q = ob.rotation_euler.to_quaternion()
            # Follow a real front-facing crystal ridge rather than placing a
            # highlight inside the solid, where the face could hide it.
            start = ob.data.vertices[11].co.lerp(ob.data.vertices[17].co, .22)
            end = ob.data.vertices[17].co.lerp(ob.data.vertices[18].co, .18)
            lift = Vector((.006, -.012, .002))
            edge = Vector((w * .11, w * .025, 0))
            local = [start + lift, start + lift + edge, end + lift + edge * .35, end + lift]
            vertices = [tuple(ob.location + q @ point) for point in local]
            mesh('Small frost face catch', vertices, [(0, 1, 2, 3)], [catch])
    # Two thin low-opacity panes bridge the body, so frozen reads as a shell
    # rather than a necklace of stones at the actor's feet. Shared registration
    # includes these panes in the first shatter/thaw frame as well.
    pane_mats = [material('Thin body ice plane %d' % i, color, .22 * fade, .26, True)
                 for i, color in enumerate([(.20, .40, .57), (.40, .66, .82), (.58, .78, .89)])]
    for i in range(2):
        local = min(1.0, max(0.0, (t - .08 * i) / .86)) if kind == 'ice_growth' else 1.0
        growth = math.sin(local * math.pi * .5)
        if growth <= .002:
            continue
        x, y, z = (-.20 if i == 0 else .21), (-.20 if i == 0 else .06), .03
        rotation = (.13, -.16 if i == 0 else .14, .3 + i * 1.8)
        if kind == 'ice_shatter':
            x += (-1 if i == 0 else 1) * t * 1.20
            y -= t * .45
            z += .35 * math.sin(math.pi * t)
            growth *= 1 - .66 * t
            rotation = (rotation[0] + t * 2.4, rotation[1] - t * 1.8, rotation[2] + t * 2)
        elif kind == 'ice_thaw':
            growth *= 1 - .68 * t
            z -= .18 * t
        crystal('Thin central ice pane', (x, y, z), (1.28 - i * .14) * growth,
                .34 * growth, rotation, pane_mats, 501 + i)
    # Small broken matte deposits, not white wire outlines or a bright root ring.
    roots = random.Random(908)
    root_growth = min(1.0, t / .5) if kind == 'ice_growth' else 1.0
    for i in range(17):
        angle = roots.uniform(0, math.tau)
        radius = roots.uniform(.43, 1.04)
        width = roots.uniform(.025, .068) * root_growth
        if kind == 'ice_shatter':
            radius += t * (.85 + .25 * math.sin(i * 3.1))
            width *= 1 - t
        elif kind == 'ice_thaw':
            width *= 1 - t
        if width > .002:
            crystal('Root frost chip', (math.cos(angle) * radius, math.sin(angle) * radius, .025), width * .8, width, (0, .2, angle), [frost], 700 + i)
    # Additional solid fragments appear only after separation; no expanding halo.
    if kind == 'ice_shatter' and 0 < t < 1:
        debris = random.Random(319)
        for i in range(7):
            angle = debris.uniform(0, math.tau)
            radius = .66 + t * debris.uniform(.7, 1.5)
            width = debris.uniform(.045, .078) * math.sin(math.pi * t) ** .4
            crystal('Detached solid chip', (math.cos(angle) * radius, math.sin(angle) * radius, .05 + .26 * math.sin(math.pi * t)), width * 2.2, width, (t * 3, angle, t * 4), mats, 900 + i)


def vortex(t):
    # Open short folded material shreds. Nothing closes into a ring or event
    # horizon. Cyclic travel is inward, and every phase is deterministic.
    phase = t * math.tau
    mats = [material('Dark folded matter %d' % i, (.085 + i * .034, .065 + i * .027, .125 + i * .048), .20 + i * .04, .7, True) for i in range(5)]
    for strand in range(13):
        travel = (t + strand * .61803398875) % 1
        envelope = math.sin(math.pi * travel) ** .8
        radius = 1.84 - travel * 1.56
        offset = strand * 2.39996323 + .26 * math.sin(phase + strand)
        vertices = []
        faces = []
        for j in range(24):
            u = j / 23
            r = radius + (u - .5) * .40
            angle = offset + .50 * (u - .5) + .24 * travel
            width = (.035 + .050 * (strand % 3)) * math.sin(math.pi * u) ** .8 * envelope
            ripple = .06 * math.sin(u * math.tau * 2 + phase + strand)
            for side in [-1, 1]:
                rr = r + side * width
                vertices.append((math.cos(angle) * rr, math.sin(angle) * rr, .04 + ripple + side * .035))
            if j < 23:
                faces.append((2 * j, 2 * j + 1, 2 * j + 3, 2 * j + 2))
        mesh('Inward folded wisp', vertices, faces, mats, [(j + strand) % 5 for j in range(23)])
    # Unequal broad open folds converge to the arrow tip. Raised ridges create
    # localized pale planes and deep undersides, not one globally bright disk.
    core_mats = [material('Converging dark fold %d' % i, color, alpha, .54, True)
                 for i, (color, alpha) in enumerate([((.07, .045, .12), .42), ((.21, .16, .30), .49), ((.40, .32, .51), .57)])]
    for strand in range(5):
        vertices, faces, indices = [], [], []
        for j in range(36):
            u = j / 35
            radius = .10 + (1.04 + .30 * math.sin(strand * 2.1)) * u
            angle = strand * 2.39996323 + .85 * u + .12 * math.sin(u * 5 + phase)
            width = (.09 + .17 * u) * math.sin(math.pi * u) ** .62 * (.48 + .52 * math.sin(u * 13 + strand) ** 2)
            for cross in [-1, 0, 1]:
                rr = radius + cross * width
                vertices.append((math.cos(angle) * rr, math.sin(angle) * rr,
                                 .10 + (1 - abs(cross)) * .12 * (.55 + .45 * math.sin(u * 11 + strand) ** 2) + .035 * math.sin(u * 8 + phase)))
            if j < 35:
                faces.extend([(3*j, 3*j+1, 3*j+4, 3*j+3), (3*j+1, 3*j+2, 3*j+5, 3*j+4)])
                indices.extend([0 if (j // 7 + strand) % 3 == 0 else 1, 2 if (j // 5 + strand) % 3 == 0 else 1])
        mesh('Open inward core fold', vertices, faces, core_mats, indices)
    # Broad uneven core folds imply dense material, never a neon donut.
    for i in range(5):
        angle = i * 2.4 + .20 * math.sin(phase + i)
        radius = .17 + .09 * math.sin(phase + i) ** 2
        crystal('Core folded chip', (math.cos(angle) * radius, math.sin(angle) * radius, .025), .13 + .05 * math.sin(phase + i), .15, (.7, .3, angle), mats, 310 + i)


os.makedirs(a.output, exist_ok=True)
effects = ['ice_growth', 'ice_shatter', 'ice_thaw', 'dark_vortex'] if a.effect == 'all' else [a.effect]
for effect in effects:
    directory = os.path.join(a.output, effect)
    os.makedirs(directory, exist_ok=True)
    frames = [0, 5, 11, 17, 23] if a.preview else list(range(N))
    if a.loop_boundary and effect == 'dark_vortex':
        frames.append(N)
    if a.frames:
        frames = [int(value) for value in a.frames.split(',')]
    for frame in frames:
        sc = setup()
        t = frame / N if effect == 'dark_vortex' else frame / (N - 1)
        vortex(t) if effect == 'dark_vortex' else ice(t, effect)
        sc.render.filepath = os.path.join(directory, '%03d.png' % frame)
        bpy.ops.render.render(write_still=True)

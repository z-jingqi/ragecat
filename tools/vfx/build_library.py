#!/usr/bin/env python3
"""Build the explicit Godot atlas resource registry from Blender export manifests."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
entries = []
for path in sorted((ROOT / 'assets/vfx/blender').glob('*/manifest.json')):
    data = json.loads(path.read_text())
    entries.extend(data if isinstance(data,list) else data['effects'])
keys=set()
for item in entries:
    if item['key']=='skyfire': item['key']='skyfire_fall'
    assert item['key'] not in keys, item['key']
    keys.add(item['key'])
text=['[gd_resource type="Resource" script_class="VfxAtlasLibrary" load_steps=%d format=3]' % (3+len(entries)*2), '', '[ext_resource type="Script" path="res://scripts/feedback/atlas/vfx_atlas_library.gd" id="1"]', '[ext_resource type="Script" path="res://scripts/feedback/atlas/vfx_atlas_clip.gd" id="2"]']
for i,item in enumerate(entries): text.append('[ext_resource type="Texture2D" path="%s" id="tex%d"]' %(item['path'],i))
for i,item in enumerate(entries):
    text.extend(['','[sub_resource type="Resource" id="clip%d"]'%i,'script = ExtResource("2")','id = &"%s"'%item['key'],'texture = ExtResource("tex%d")'%i])
    for key in ['columns','rows','frames','fps']: text.append('%s = %s'%(key,item[key]))
    text.append('loop = '+str(item['loop']).lower())
    opacity={'fire_burst':.82,'fire_ground':.65,'fire_loop':.78,'ice_shatter':.85,'summon':.75,'energy_orb':.9,'dark_vortex':.88,'lightning_impact':.8}.get(item['key'],1.0)
    text.append('opacity = '+str(opacity))
    size={'ice_shell':1.65,'ice_shatter':1.65,'ice_thaw':1.65,'dark_vortex':1.3}.get(item['key'],1.0)
    text.append('size_multiplier = '+str(size))
text.extend(['','[resource]','script = ExtResource("1")','clips = Array[ExtResource("2")](['+', '.join('SubResource("clip%d")'%i for i in range(len(entries)))+'])',''])
(ROOT/'resources/feedback/atlas/library.tres').write_text('\n'.join(text))
print('Registered',len(entries),'baked clips')

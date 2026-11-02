#!/usr/bin/env python3
"""Fast source/config and mathematical specification tests, not an engine portability or compilation test."""
import importlib.util
import json
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('adapter', ROOT / 'build_shaders.py')
adapter = importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)

def cross(a, b): return a[0]*b[1]-a[1]*b[0]
def sub(a,b): return a[0]-b[0], a[1]-b[1]
def tri(p,a,b,c,va,vb,vc):
    area=cross(sub(b,a),sub(c,a))
    if abs(area)<.00001: return (-1,-1)
    wb=cross(sub(p,a),sub(c,a))/area; wc=cross(sub(b,a),sub(p,a))/area; wa=1-wb-wc
    if min(wa,wb,wc)<-.00001:return (-1,-1)
    return tuple(va[i]*wa+vb[i]*wb+vc[i]*wc for i in range(2))
class Contract(unittest.TestCase):
    def test_generated_adapter_current(self):
        self.assertEqual(adapter.OUT.read_text(),adapter.generated_shader())
    def test_triangle_reverse(self):
        p=(.2,.2); a=(0,0); b=(1,0); c=(0,1)
        first=tri(p,a,b,c,(.2,0),(.5,1),(1,1))
        reverse=tri(p,c,b,a,(1,1),(.5,1),(.2,0))
        for x,y in zip(first,reverse):self.assertAlmostEqual(x,y)
        self.assertEqual(tri((2,2),a,b,c,(.2,0),(.5,1),(1,1)),(-1,-1))
    def test_degenerate_triangle(self):
        self.assertEqual(tri((0,0),(0,0),(1,0),(2,0),(1,0),(1,1),(1,1)),(-1,-1))
    def test_taper_clean_zero(self):
        widths=[.68 * life**1.35 for life in [0,.25,.5,.75,1]]
        self.assertEqual(widths[0],0)
        self.assertEqual(widths,sorted(widths))
    def test_presets_real_ranges(self):
        data=json.loads((ROOT/'config/presets.json').read_text())
        for p in data['presets'].values():
            self.assertTrue(.02<=p['lifetime']<=.6)
            self.assertTrue(2<=p['max_samples']<=64)
            self.assertTrue(.005<=p['min_sample_distance']<=.5)
            self.assertTrue(0<p['width_fraction']<=1)
            self.assertIn(p['fade_mode'],['hard','stepped'])
    def test_runtime_no_texture_dependency(self):
        shader=adapter.generated_shader()
        self.assertNotIn('sampler',shader)
        self.assertIn('floor(world_pixels)',shader)
        source=(adapter.REPO/'preview/godot/effects/VFX-02_weapon_trail/trail_history.gd').read_text()
        self.assertIn('distance < min_sample_distance',source)
        self.assertIn('CAPACITY := 64',source)
if __name__=='__main__':unittest.main(verbosity=2)

"""Optional analytic convected burn-through field; reference for matching shader nodes.

A small, continuous warped-wave field creates a few coherent holes, not white
noise. Its q coordinate moves from root to tip (+u) as lifetime age advances.
The source is still one original gas-flame color source, not a whole-ball UV warp.
"""
import math
from evolving_geometry import smooth


def flow_field(u,v,age,seed):
    q=u*3.4-age*1.6+seed
    r=(v-.5)*2.1+seed*.31
    a=math.sin(q*2.4+.9*math.sin(r*2.2+.6*q))
    b=math.sin(r*3.0-q*1.35+.7*math.sin(q*1.3+r))
    return .5+.28*a+.22*b


def material_controls(u,v,age,seed,world_x,source_luminance):
    field=flow_field(u,v,age,seed)
    rear=1-smooth(-.40,.05,world_x)
    side=smooth(.25,.90,abs(v*2-1))
    heat=smooth(.30,.72,source_luminance)
    hole=smooth(.58,.77,field+.12*side)
    retained=(.48+.44*heat)*(1-hole*(.94-.37*heat))
    opacity_multiplier=1-rear*(1-retained)
    moving_ridge=1-smooth(.025,.10,abs(field-.56))
    emission_strength=1+.18*rear*heat*moving_ridge
    return opacity_multiplier,emission_strength

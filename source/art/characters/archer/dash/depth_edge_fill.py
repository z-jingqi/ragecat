"""Small deterministic packing helper. Input arrays share PNG/EXR row order.
Changes depth only at alpha-covered pixels whose raw Blender Z is background.
Does not normalize, dilate RGBA, modify opaque valid Z, or touch source files.
"""
import numpy as np

def fill_alpha_edge_depth(depth, alpha, background_cutoff=100.0):
    depth=np.asarray(depth,dtype=np.float32)
    alpha=np.asarray(alpha)
    out=depth.copy()
    valid=np.isfinite(depth) & (depth>0) & (depth<background_cutoff) & (alpha>0)
    missing=(alpha>0) & ~valid
    source=np.argwhere(valid)
    dest=np.argwhere(missing)
    if len(dest)==0:
        return out,{'filled_pixels':0,'max_nearest_distance_px':0.0}
    if len(source)==0:
        raise ValueError('No valid alpha-covered surface depth exists')
    longest=0.0
    for start in range(0,len(dest),128):
        targets=dest[start:start+128]
        distance2=((targets[:,None,:]-source[None,:,:])**2).sum(axis=2)
        closest=distance2.argmin(axis=1)
        nearest=source[closest]
        out[targets[:,0],targets[:,1]]=depth[nearest[:,0],nearest[:,1]]
        longest=max(longest,float(np.sqrt(distance2[np.arange(len(targets)),closest].max())))
    return out,{'filled_pixels':len(dest),'max_nearest_distance_px':longest}

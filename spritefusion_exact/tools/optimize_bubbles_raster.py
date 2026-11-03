"""Wire direct source-equivalent loops after `transpile.cjs bubbles.ts bubbles.gd --native-px`."""
import pathlib,re,sys
path=pathlib.Path(sys.argv[1]);text=path.read_text()
assert 'const C_Px = preload("res://scripts/core/sf_px_source.gd")' in text
text=text.replace('const JS = ', 'const Raster = preload("res://scripts/effects/bubbles_raster.gd")\nconst JS = ',1)
def cap(name):
 return re.search(r'_cap\d+\["'+name+r'_\d+"\]',text).group()
for name,native,args in [
 ('drawSurface','surface',['TOP','X0','X1','t','HI','LIT','RIM','SHADE']),
 ('drawCaustics','caustics',['TOP','X0','X1','t','groundAt','LIT','RIM']),
 ('tintWater','tint',['TOP','X0','X1','groundAt'])]:
 bind=re.search(r'\t'+re.escape(cap(name))+r' = (_lambda\d+)',text)
 fn=bind.group(1);start=text.index('\tvar '+fn+' = func(');end=bind.start()
 signature=text[start:text.index('\n',start)]
 params=signature.split('func(')[1].split(')')[0].split(', ')
 call=[p+'._pixels' for p in params]+[cap(a) for a in args]
 if name=='tintWater':call+=['SFExactBubbles._g_WATER']
 text=text[:start]+signature+'\n\t\tRaster.'+native+'('+', '.join(call)+')\n'+text[end:]
path.write_text(text)

extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var args:=OS.get_cmdline_user_args()
 assert(args.size()==2,"Usage: MANIFEST_JSON MOTION_TRES")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var motion:ArcherDashMotionDefinition=load(args[1])
 var frames:=0
 var pixels:=0
 for clip in data.clips:
  var d:Dictionary=data.clips[clip]
  var library:ArcherPoseLibrary=motion.body if d.role=="body" else motion.guard
  for index in d.frames.size():
   var actual_index:int=index+(int(d.base_frame_count) if d.role=="guard_move" else 0)
   var atlas:AtlasTexture=library.colors.get_frame_texture(clip,actual_index)
   var canvas:=Image.create(192,192,false,Image.FORMAT_RGBA8)
   canvas.fill(Color.TRANSPARENT)
   canvas.blit_rect(atlas.atlas.get_image(),Rect2i(atlas.region),Vector2i(atlas.margin.position))
   var source_path:String=d.frames[index].color
   if not source_path.is_absolute_path(): source_path=args[0].get_base_dir().path_join(source_path)
   var original:=Image.load_from_file(source_path)
   original.convert(Image.FORMAT_RGBA8)
   var a:=canvas.get_data()
   var b:=original.get_data()
   for p in range(0,a.size(),4):
    assert(a[p+3]==b[p+3],"Atlas trim changed alpha")
    if b[p+3]>0:
     assert(a[p]==b[p] and a[p+1]==b[p+1] and a[p+2]==b[p+2],"Atlas packing changed visible source pixels")
     pixels+=1
   assert(not library.sample(clip,float(actual_index)/(library.colors.get_frame_count(clip)-1)).is_empty())
   frames+=1
 print("DASH IMPORT PIXEL PARITY: ",frames," frames; ",pixels," visible pixels identical")
 quit()

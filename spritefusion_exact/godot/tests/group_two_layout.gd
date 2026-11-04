# UI-only portability test: real shaped fonts, captions and window resizing.
# Reads only shared host text/cases. Never loads effects, scenes, core or a lens.
# Actual native scene, effect lifecycle and lens gates remain separate tests.
extends SceneTree
const HOST_PATH = "res://scripts/previews/group_two_preview.gd"
const CASES_PATH = "res://scripts/previews/group_two_cases.json"
const SLUGS = ["ice", "poison", "energy", "shield", "black-hole", "holy-light", "power-up"]

func _initialize(): call_deferred("run")

func sha(bytes: PackedByteArray) -> String:
 var context = HashingContext.new()
 context.start(HashingContext.HASH_SHA256)
 context.update(bytes)
 return context.finish().hex_encode()

func fixture_script(host_source: String) -> GDScript:
 # Compile the production formatter verbatim, without its unrelated preloads.
 # Extraction fails closed if the shared host no longer has the expected API.
 var source = "extends Node2D\nvar slug: String\nvar current: Dictionary\nvar tick := 0\nvar label: Label\n"
 for constant in ["STAGE_SIZE", "LOGICAL_SIZE", "FOOTER_RECT"]:
  var prefix = "const " + constant + " "
  var matches: Array[String] = []
  for line in host_source.split("\n"):
   if line.begins_with(prefix): matches.append(line)
  assert(matches.size() == 1, "Missing or ambiguous host constant: " + constant)
  source += matches[0] + "\n"
 var start = host_source.find("\nfunc update_footer() -> void:\n")
 assert(start >= 0, "Missing shared host footer formatter")
 var finish = host_source.find("\nfunc ", start + 1)
 assert(finish > start, "Cannot locate footer formatter end")
 source += host_source.substr(start + 1, finish - start - 1) + "\n"
 var script = GDScript.new()
 script.source_code = source
 assert(script.reload() == OK, "Cannot compile isolated production footer formatter")
 return script

func run():
 var host_source = FileAccess.get_file_as_string(HOST_PATH)
 var cases_source = FileAccess.get_file_as_string(CASES_PATH)
 assert(host_source.contains('label.add_theme_font_size_override("font_size", 13)'), "Update UI fixture when the production font size changes")
 var cases = JSON.parse_string(cases_source)
 assert(cases is Array and cases.size() == 17)
 var script = fixture_script(host_source)
 var records: Array = []
 var variant_count = 0
 for slug in SLUGS:
  var fixture = script.new()
  fixture.slug = slug
  root.add_child(fixture)
  root.content_scale_size = fixture.LOGICAL_SIZE
  root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
  root.size = Vector2i(960,684)
  assert(fixture.STAGE_SIZE == Vector2i(640,400))
  assert(fixture.LOGICAL_SIZE == Vector2i(640,456))
  assert(fixture.FOOTER_RECT == Rect2(8,408,624,40))
  fixture.label = Label.new()
  fixture.label.position = fixture.FOOTER_RECT.position
  fixture.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  fixture.label.add_theme_font_size_override("font_size",13)
  fixture.add_child(fixture.label)
  for item in cases:
   if item.slug != slug: continue
   variant_count += 1
   fixture.current = item
   for sample_tick in [0,120,99999]:
    fixture.tick = sample_tick
    fixture.update_footer()
    var label: Label = fixture.label
    assert(label.text.split("\n").size() == 2)
    assert(label.text.contains("Hooks recorded; flash/shake/darken not applied."))
    var font: Font = label.get_theme_font("font")
    var font_size = label.get_theme_font_size("font_size")
    var shaped = font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
    var font_rect = Rect2(label.position,shaped)
    var control_rect = label.get_rect()
    assert(fixture.FOOTER_RECT.encloses(font_rect), "Shaped font exceeds footer: "+item.id)
    assert(fixture.FOOTER_RECT.encloses(control_rect), "Label exceeds footer: "+item.id)
    assert(not control_rect.intersects(Rect2(Vector2.ZERO,Vector2(fixture.STAGE_SIZE))))
    records.append({"id":item.id,"tick":sample_tick,"font_width":shaped.x,"font_height":shaped.y,"label_width":control_rect.size.x,"label_height":control_rect.size.y})
  for window_size in [Vector2i(640,456),Vector2i(960,684),Vector2i(480,342),Vector2i(1280,912)]:
   root.size = window_size
   await process_frame
   assert(root.content_scale_size == Vector2i(640,456))
   assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)
   assert(fixture.FOOTER_RECT.encloses(fixture.label.get_rect()))
  fixture.queue_free()
  await process_frame
 assert(variant_count == 17 and records.size() == 51)
 var result = {"passed":true,"scope":"UI-only: exact shared-host footer formatter/constants with real fonts; no effects, scenes, core or lens loaded.","cases":records.size(),"variants":variant_count,"window_size_checks":28,"stage":[640,400],"logical_viewport":[640,456],"requested_window":[960,684],"footer":[8,408,624,40],"records":records,"host_sha256":sha(host_source.to_utf8_buffer()),"cases_sha256":sha(cases_source.to_utf8_buffer()),"required_files":[HOST_PATH,CASES_PATH],"native_framebuffer_verified":false,"effect_lifecycle_verified":false,"black_hole_lens_verified":false,"portability":"Runs with only this test, shared host text and shared cases JSON. Native per-effect and lens acceptance remain separate."}
 var args = OS.get_cmdline_user_args()
 if args.size(): FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("PASS UI-only: 51 shaped-font and Label rectangles, 17 captions, 28 window sizes; no effects, scenes, core or lens loaded.")
 quit()

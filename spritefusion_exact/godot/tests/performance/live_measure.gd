extends SceneTree
const Observed = preload("res://tests/performance/observed_preview.gd")
const Frame = preload("res://scripts/core/sf_frame.gd")
var preview
var output=""
var case_id=""
var rendered=[]
var initial_rendered=false
var finishing=false
var startup_usec=0
var began_usec=0
var initial_draw_usec=0
var last_marker=""
var last_unique_draw_usec=0
var previous_frame_draw_usec=0
var last_warm_draw_usec=0
var complete_warmup_ticks=0
var failures=[]
var initial_input_hashes={}
var selected_slug=""
func _initialize(): call_deferred("run")
func digest(bytes):
	var h=HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()
func stats(values):
	if values.is_empty(): return {"count":0}
	var a=values.duplicate()
	a.sort()
	var sum=0.0
	for x in a: sum+=x
	return {"count":a.size(),"mean_ms":sum/a.size()/1000.0,"p50_ms":a[maxi(0,int(ceil(a.size()*0.50))-1)]/1000.0,"p95_ms":a[maxi(0,int(ceil(a.size()*0.95))-1)]/1000.0,"p99_ms":a[maxi(0,int(ceil(a.size()*0.99))-1)]/1000.0,"worst_ms":a[-1]/1000.0}
func input_hashes():
	# Before/after metadata only: no filesystem reads in the measured interval.
	var paths=["res://project.godot","res://previews/group_three/preview.gd","res://previews/group_three/cases-f64.json","res://tests/performance/observed_preview.gd","res://tests/performance/live_measure.gd"]
	for folder in ["res://scripts/core", "res://scripts/effects"]:
		for file_name in DirAccess.get_files_at(folder):
			if file_name.ends_with(".gd"): paths.append(folder+"/"+file_name)
	paths.append("res://tests/fixtures/"+selected_slug+"/oracle/"+case_id+"/expected.json")
	paths.sort()
	var hashes={}
	for path in paths: hashes[path]=digest(FileAccess.get_file_as_bytes(path))
	return hashes
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()!=2 or not args[0] in ["sparkle","fog","embers"]:
		printerr("Usage: native --script live_measure.gd -- sparkle|fog|embers ABSOLUTE_FRESH_OUTPUT")
		quit(2)
		return
	var disallowed_time_mode=false
	for argument in OS.get_cmdline_args():
		if argument=="--fixed-fps" or argument.begins_with("--fixed-fps=") or argument=="--write-movie" or argument.begins_with("--write-movie=") or argument=="--time-scale" or argument.begins_with("--time-scale="):
			disallowed_time_mode=true
	if DisplayServer.get_name()=="headless" or disallowed_time_mode or Engine.time_scale!=1.0:
		printerr("Native ordinary-time run required; no headless/fixed-fps/MovieWriter/time-scale overrides")
		quit(2)
		return
	output=args[1].simplify_path()
	# Supported layout is <repository>/spritefusion_exact/godot.
	var project_directory=ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var repository_directory=project_directory.get_base_dir().get_base_dir()
	if not output.is_absolute_path() or output==repository_directory or output.begins_with(repository_directory+"/"):
		printerr("Output must be an absolute path outside the entire repository")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		printerr("Output directory must be fresh")
		quit(2)
		return
	# Directory creation before measurement; all telemetry stays in memory until end.
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		printerr("Could not create fresh output directory")
		quit(2)
		return
	selected_slug=args[0]
	case_id={"sparkle":"sparkle-glint","fog":"fog-night","embers":"embers-embers"}[selected_slug]
	initial_input_hashes=input_hashes()
	began_usec=Time.get_ticks_usec()
	preview=Observed.new()
	preview.slug=args[0]
	preview.paused=true
	root.add_child(preview)
	startup_usec=Time.get_ticks_usec()-began_usec
	if case_id!=preview.c.id: failures.append("Selected default fixture changed")
	complete_warmup_ticks=preview.warmup_remaining
	RenderingServer.frame_post_draw.connect(on_post_draw)
func on_post_draw():
	if finishing: return
	var now=Time.get_ticks_usec()
	if not initial_rendered:
		initial_rendered=true
		initial_draw_usec=now
		last_unique_draw_usec=now
		previous_frame_draw_usec=now
		last_warm_draw_usec=now
		last_marker=str(preview.sim_frame)+":"+str(preview.warmup_remaining)
		preview.paused=false
		preview.observations_active=true
		return
	var phase="warmup" if preview.sim_frame==0 else "measured"
	var marker=str(preview.sim_frame)+":"+str(preview.warmup_remaining)
	var unique=marker!=last_marker
	rendered.append({"phase":phase,"source_tick":preview.sim_frame,"warmup_remaining":preview.warmup_remaining,"post_draw_usec":now,"wall_frame_interval_usec":now-previous_frame_draw_usec,"new_source_state":unique,"source_presentation_interval_usec":now-last_unique_draw_usec if unique else 0})
	previous_frame_draw_usec=now
	if unique:
		last_marker=marker
		last_unique_draw_usec=now
	if preview.sim_frame==0 and unique and complete_warmup_ticks>0: last_warm_draw_usec=now
	if preview.sim_frame>=60:
		finishing=true
		preview.paused=true
		preview.observations_active=false
		call_deferred("finish")
func finish():
	var final_input_hashes=input_hashes()
	if final_input_hashes!=initial_input_hashes: failures.append("Runtime or fixture files changed during observation")
	if Engine.time_scale!=1.0: failures.append("Engine.time_scale changed during observation")
	if not preview.interaction_events.is_empty(): failures.append("User input attempted during observation")
	var measured=[]
	var warm=[]
	for row in preview.process_samples:
		if row.phase=="measured": measured.append(row)
		else: warm.append(row)
	var cadence=[]
	var presentation=[]
	var seen={}
	var warm_seen={}
	var measured_renders=0
	for row in rendered:
		if row.phase=="measured":
			measured_renders+=1
			cadence.append(row.wall_frame_interval_usec)
			if row.new_source_state:
				presentation.append(row.source_presentation_interval_usec)
				seen[int(row.source_tick)]=true
		elif row.new_source_state: warm_seen[int(row.warmup_remaining)]=true
	if measured.size()!=60: failures.append("Expected exactly60 measured source updates")
	if warm.size()!=complete_warmup_ticks: failures.append("Original warmup update count changed")
	for tick in range(1,61):
		if not seen.has(tick): failures.append("No distinct native presentation for source tick"+str(tick))
	if warm_seen.size()!=complete_warmup_ticks: failures.append("Warmup source presentation count differs")
	var final_wall=rendered[-1].post_draw_usec
	var measured_wall=final_wall-last_warm_draw_usec
	var stages={}
	for key in ["cpu_update_usec","cpu_draw_buffers_usec","cpu_present_including_image_texture_label_usec","cpu_host_total_usec"]:
		var samples=[]
		for row in measured: samples.append(row[key])
		stages[key]=stats(samples)
	# Actual final combined bytes and separate-layer source hashes after measured
	# rendering stops. No hash/disk/screenshot work occurs inside the measured loop.
	var composite={}
	for channel in ["color","light"]:
		composite[channel]=digest(preview.composite_frame.get(channel).to_image().get_data())
	var golden_path="res://tests/fixtures/"+preview.slug+"/oracle/"+case_id+"/expected.json"
	var golden_bytes=FileAccess.get_file_as_bytes(golden_path)
	var golden=JSON.parse_string(golden_bytes.get_string_from_utf8())
	var expected={"buffers":{},"golden_path":golden_path,"golden_sha256":digest(golden_bytes)}
	if golden is Dictionary:
		for row in golden.get("hashes",[]):
			if int(row.frame)==60: expected.buffers=row.buffers
	if expected.buffers.is_empty(): failures.append("Missing existing fixture tick60 golden: "+golden_path)
	var actual={}
	var frame=Frame.new(320,200)
	for layer in ["back","front"]:
		frame.clear()
		for fx in preview.live: fx.draw(frame,layer)
		for channel in ["color","light"]:
			var key=layer+"-"+channel
			actual[key]=digest(PackedInt32Array(Array(frame.get(channel).data)).to_byte_array())
			if actual[key]!=expected.buffers.get(key,""): failures.append("Tick60 source hash mismatch "+key)
	var result={"case":case_id,"complete_original_warmup_updates":complete_warmup_ticks,"observed_warmup_updates":warm.size(),"warmup_unique_rendered_states":warm_seen.size(),"startup_ready_cpu_ms":startup_usec/1000.0,"startup_to_initial_render_ms":(initial_draw_usec-began_usec)/1000.0,"warmup_wall_ms":(last_warm_draw_usec-initial_draw_usec)/1000.0,"measured_source_seconds":60.0/60.0,"measured_wall_seconds":measured_wall/1000000.0,"source_updates":measured.size(),"native_render_callbacks":measured_renders,"unique_presented_source_ticks":seen.size(),"wall_frame_cadence":stats(cadence),"source_presentation_cadence":stats(presentation),"cpu_stages":stages,"actual_tick60_source_hashes":actual,"tick60_composite_hashes":composite,"golden_provenance":expected,"fixture_sha256":digest(FileAccess.get_file_as_bytes("res://previews/group_three/cases-f64.json")),"input_file_sha256":final_input_hashes,"initial_input_file_sha256":initial_input_hashes,"interaction_events":preview.interaction_events,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"api":RenderingServer.get_video_adapter_api_version(),"display":DisplayServer.get_name(),"godot":Engine.get_version_info().string,"window_size":[root.size.x,root.size.y],"logical_viewport":[root.content_scale_size.x,root.content_scale_size.y],"ordinary_engine_time":true,"no_movie_writer":true,"no_sparse_warmup":true,"no_pre_rendered_frames":true,"telemetry_buffered_until_finish":true,"failures":failures,"process_samples":preview.process_samples,"render_samples":rendered}
	var file=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("LIVE_NATIVE_RESULT ",case_id," wall_s=",result.measured_wall_seconds," render_states=",seen.size()," failures=",failures)
	preview.free()
	quit(0 if failures.is_empty() else 1)

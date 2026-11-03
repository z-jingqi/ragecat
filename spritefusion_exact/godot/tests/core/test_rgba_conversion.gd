extends SceneTree
const Candidate = preload("res://scripts/core/sf_pixel_buffer.gd")
var checks = 0
var failures = []
func check(ok, label):
	checks += 1
	if not ok: failures.append(label)
# Frozen original scalar byte conversion as an independent test oracle.
func original_rgba_bytes(words):
	var bytes = PackedByteArray()
	bytes.resize(words.size() * 4)
	for i in range(words.size()):
		var c: int = words[i]
		bytes[i*4] = c & 255
		bytes[i*4+1] = (c >> 8) & 255
		bytes[i*4+2] = (c >> 16) & 255
		bytes[i*4+3] = (c >> 24) & 255
	return bytes
func check_words(words, width, height, label):
	var candidate = Candidate.new(width,height)
	candidate.data = words.duplicate()
	var bytes = original_rgba_bytes(words)
	check(candidate.rgba_bytes() == bytes, label + " bytes")
	check(candidate.to_image().get_data() == Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,bytes).get_data(), label + " Image data")
	check(candidate.to_image().get_size() == Vector2i(width,height), label + " Image dimensions")
	check(candidate.to_image().get_format() == Image.FORMAT_RGBA8, label + " Image format")
	check(candidate.data == words, label + " source unmodified")
	var supported = Candidate._bulk_rgba_supported
	Candidate._bulk_rgba_supported = false
	check(candidate.rgba_bytes() == bytes, label + " forced scalar bytes")
	check(candidate.to_image().get_data() == bytes, label + " forced scalar Image")
	Candidate._bulk_rgba_supported = supported
	var output = candidate.rgba_bytes()
	output[0] = (output[0] + 1) & 255
	check(candidate.data == words, label + " output does not alias source")
	check(bytes.size() == width * height * 4, label + " byte length")
func _initialize(): call_deferred("run")
func run():
	var extremes = PackedInt64Array([0,1,0x04030201,0x80706050,0x7fffffff,0x80000000,0xffffffff,-1,-2147483648,0x100000000,0x123456789abcdef0,0x7fffffffffffffff,-9223372036854775807-1])
	check_words(extremes,extremes.size(),1,"extreme lanes")
	var rng = RandomNumberGenerator.new()
	rng.seed = 0x51f1a57
	var words = PackedInt64Array()
	for i in range(2048): words.append(rng.randi())
	check_words(words,64,32,"uint32 fuzz")
	var bits = PackedByteArray()
	bits.resize(8)
	for i in range(2048):
		bits.encode_u32(0,rng.randi())
		bits.encode_u32(4,rng.randi())
		words[i] = bits.decode_s64(0)
	check_words(words,64,32,"int64 fuzz")
	words.resize(320*200)
	words.fill(0)
	check_words(words,320,200,"zero light frame")
	for i in range(words.size()): words[i] = rng.randi()
	check_words(words,320,200,"full RGBA frame")
	var probe = Candidate.new(1,1)
	probe.data[0] = 0x04030201
	check(probe.rgba_bytes() == PackedByteArray([1,2,3,4]),"explicit RGBA order")
	# Unsupported platforms are valid: the original scalar path remains in use.
	check(Candidate._bulk_rgba_supported == Candidate._supports_bulk_rgba(),"stored availability matches probe")
	print(JSON.stringify({"checks":checks,"failures":failures,"bulk_available":Candidate._bulk_rgba_supported}))
	quit(0 if failures.is_empty() else 1)

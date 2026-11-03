extends RefCounted
## Test data only. Verify byte-exact reconstruction before parsing oracle values.
static func read(path: String) -> Dictionary:
 var index = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not index is Dictionary: return {}
 if index.get("format", "") != "split-json-v1": return index
 var text := ""
 for chunk in index.chunks:
  text += FileAccess.get_file_as_string(path.get_base_dir().path_join(chunk))
 if text.to_utf8_buffer().size() != int(index.bytes) or text.sha256_text() != index.sha256:
  push_error("Oracle fixture reconstruction failed: " + path)
  return {}
 var decoded = JSON.parse_string(text)
 return decoded if decoded is Dictionary else {}

# Focused Fog checks

After the normal Godot 4.6.3 headless editor import, from the repository root:

```sh
godot --headless --path spritefusion_exact/godot --script tests/effects/fog/test_sampling.gd
godot --headless --path spritefusion_exact/godot --script tests/effects/fog/test_lifecycle.gd
python3 spritefusion_exact/tools/test_effect.py fog --output /absolute/fresh/output
```

Use writable XDG data/cache/config paths where required. Keep logs outside the
repository. A zero exit code and no engine/script errors are required.

The sampling test preserves the former helper-based interpolation as the scalar
reference. It compares exact binary64 results over four deterministic Float32
fields, boundary inputs decoded from IEEE754 hex, and deterministic fractional
coordinate pairs inside and outside the guarded domain. NaNs are equivalent;
signed zero is compared by bits. A changed-field negative control must be detected.
This test checks numerical equivalence, not performance or native presentation.

The lifecycle test exercises repeated stop/dispose, stop completion, empty final
buffers, fresh reconfiguration, and shared-Frame versus dictionary adapters at
integer and fractional origins. It does not create a native renderer window.
The complete saved-source Fog oracle remains required in addition to these tests.

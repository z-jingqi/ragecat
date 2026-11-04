"""Compare full-precision native reports with the unmodified TypeScript hook stream."""
import json
import pathlib
import sys
oracle, output = map(pathlib.Path, sys.argv[1:3])
cases = json.loads((oracle / 'cases.json').read_text())
selected = set(sys.argv[3].split(',')) if len(sys.argv) > 3 else set()
count = 0
for case in cases:
    if selected and case['id'] not in selected and case['slug'] not in selected:
        continue
    actual = json.loads((output / (case['id'] + '.json')).read_text())
    expected = json.loads((oracle / case['id'] / 'frames.json').read_text())
    assert actual['passed'], case['id']
    assert actual['hooks'] == expected['hooks'], case['id'] + ': hooks differ'
    assert actual['doneFrame'] == expected['doneFrame'], case['id'] + ': lifecycle differs'
    assert actual['frames'] == len(expected['hashes']), case['id'] + ': frame count differs'
    count += 1
assert count > 0, 'No matching cases'
print(f'PASS {count} cases: exact hooks, lifecycle and frame counts')

#!/usr/bin/env python3
"""Black-box failure-path tests for test_effect.py, using a local fake engine."""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

HARNESS = pathlib.Path(os.environ.get('SF_TEST_HARNESS_PATH', pathlib.Path(__file__).with_name('test_effect.py')))
FAKE_ENGINE = r'''
import json, os, pathlib, sys
output = pathlib.Path(os.environ['HOME']).parent
phase = 'import' if '--editor' in sys.argv else 'runtime'
if os.environ.get('FAKE_' + phase.upper() + '_EARLY_EXIT') == '1':
    sys.exit(0)
with (output / 'calls.jsonl').open('a') as log:
    log.write(json.dumps({'phase': phase}) + '\n')
(output / 'environment.json').write_text(json.dumps({key: os.environ[key] for key in ['HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_CONFIG_HOME']}))
print(os.environ.get('FAKE_' + phase.upper() + '_STDOUT', phase + ' stdout sentinel'))
print(os.environ.get('FAKE_' + phase.upper() + '_STDERR', phase + ' stderr sentinel'), file=sys.stderr)
if phase == 'runtime':
    destination = pathlib.Path(sys.argv[-1])
    (destination / 'frames.json').write_text(json.dumps({'frames': 0, 'doneFrame': None, 'hooks': [], 'hashes': []}))
sys.exit(int(os.environ.get('FAKE_' + phase.upper() + '_CODE', '0')))
'''

class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sf-harness-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        tools = self.root / 'spritefusion_exact/tools'
        tools.mkdir(parents=True)
        shutil.copyfile(HARNESS, tools / 'test_effect.py')
        self.script = tools / 'test_effect.py'
        fixtures = self.root / 'spritefusion_exact/godot/tests/fixtures/probe/oracle'
        (fixtures / 'probe-case').mkdir(parents=True)
        (fixtures / 'cases.json').write_text(json.dumps([{'id': 'probe-case'}]))
        (fixtures / 'probe-case/expected.json').write_text(json.dumps({'frames': 0, 'doneFrame': None, 'hooks': [], 'hashes': []}))
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        engine = self.bin / 'godot'
        engine.write_text('#!' + sys.executable + '\n' + FAKE_ENGINE)
        engine.chmod(0o700)
        (self.root / 'anchor').mkdir()
        self.output = self.root / 'results'

    def run_harness(self, **overrides):
        env = os.environ.copy()
        env['PATH'] = str(self.bin) + os.pathsep + env.get('PATH', '')
        env.update(overrides)
        return subprocess.run([sys.executable, str(self.script), 'probe', '--suite', 'oracle', '--output', 'anchor/../results', '--timeout', '5'], cwd=self.root, env=env, capture_output=True, text=True, timeout=15)

    def phases(self):
        return [json.loads(line)['phase'] for line in (self.output / 'calls.jsonl').read_text().splitlines()]

    def test_clean_import_preserves_both_streams_and_resolves_output(self):
        result = self.run_harness()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.phases(), ['import', 'runtime'])
        log = (self.output / 'editor-import.log').read_text()
        self.assertIn('import stdout sentinel', log)
        self.assertIn('import stderr sentinel', log)
        for value in json.loads((self.output / 'environment.json').read_text()).values():
            path = pathlib.Path(value)
            self.assertTrue(path.is_absolute())
            self.assertEqual(str(path), str(path.resolve()))
        self.assertTrue((self.output / 'summary.json').is_file())

    def check_import_failure(self, **overrides):
        result = self.run_harness(**overrides)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.phases(), ['import'])
        self.assertIn('Godot editor import failed:', result.stderr)
        self.assertTrue((self.output / 'editor-import.log').is_file())
        self.assertFalse((self.output / 'summary.json').exists())

    def test_zero_exit_import_stderr_error_is_fatal(self):
        self.check_import_failure(FAKE_IMPORT_STDERR='ERROR: synthetic import failure')

    def test_zero_exit_import_stdout_error_is_fatal(self):
        self.check_import_failure(FAKE_IMPORT_STDOUT='SCRIPT ERROR: synthetic parse failure')

    def test_nonzero_import_is_fatal(self):
        self.check_import_failure(FAKE_IMPORT_CODE='7')

    def check_runtime_failure(self, **overrides):
        result = self.run_harness(**overrides)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.phases(), ['import', 'runtime'])
        self.assertIn('Native run failed:', result.stderr)
        self.assertTrue((self.output / 'oracle/probe-case/engine.log').is_file())
        self.assertFalse((self.output / 'summary.json').exists())

    def test_zero_exit_runtime_stdout_error_is_fatal(self):
        self.check_runtime_failure(FAKE_RUNTIME_STDOUT='ERROR: synthetic render failure')

    def test_zero_exit_runtime_stderr_error_is_fatal(self):
        self.check_runtime_failure(FAKE_RUNTIME_STDERR='SCRIPT ERROR: synthetic runtime failure')

    def test_nonzero_runtime_is_fatal(self):
        self.check_runtime_failure(FAKE_RUNTIME_CODE='9')

    def test_existing_empty_output_directory_is_allowed(self):
        self.output.mkdir()
        result = self.run_harness()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.output / 'summary.json').is_file())

    def test_existing_output_file_is_rejected_without_modification(self):
        self.output.write_bytes(b'preserve this existing file')
        before = self.output.read_bytes(), self.output.stat().st_mtime_ns
        result = self.run_harness(FAKE_IMPORT_EARLY_EXIT='1', FAKE_RUNTIME_EARLY_EXIT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Output directory must be absent or empty', result.stderr)
        self.assertEqual((self.output.read_bytes(), self.output.stat().st_mtime_ns), before)

    def test_stale_frames_and_summary_are_rejected_and_preserved(self):
        destination = self.output / 'oracle/probe-case'
        destination.mkdir(parents=True)
        (destination / 'frames.json').write_text(json.dumps({'frames': 0, 'doneFrame': None, 'hooks': [], 'hashes': []}))
        (destination / 'engine.log').write_bytes(b'previous successful engine log')
        (self.output / 'summary.json').write_bytes(b'[{"previous_run": true}]')
        before = {str(p.relative_to(self.output)): (p.read_bytes(), p.stat().st_mtime_ns)
                  for p in self.output.rglob('*') if p.is_file()}
        tree_before = sorted(str(p.relative_to(self.output)) for p in self.output.rglob('*'))
        result = self.run_harness(FAKE_IMPORT_EARLY_EXIT='1', FAKE_RUNTIME_EARLY_EXIT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Output directory must be absent or empty', result.stderr)
        self.assertNotIn('PASS', result.stdout)
        after = {str(p.relative_to(self.output)): (p.read_bytes(), p.stat().st_mtime_ns)
                 for p in self.output.rglob('*') if p.is_file()}
        self.assertEqual(after, before)
        self.assertEqual(sorted(str(p.relative_to(self.output)) for p in self.output.rglob('*')), tree_before)
        self.assertFalse((self.output / 'home').exists())
        self.assertFalse((self.output / 'editor-import.log').exists())
        self.assertFalse((self.output / 'calls.jsonl').exists())

    def test_fresh_output_cannot_pass_if_runtime_exits_zero_without_frames(self):
        result = self.run_harness(FAKE_RUNTIME_EARLY_EXIT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('PASS', result.stdout)
        self.assertFalse((self.output / 'oracle/probe-case/frames.json').exists())
        self.assertFalse((self.output / 'summary.json').exists())

    def test_warning_is_retained_without_false_failure(self):
        result = self.run_harness(FAKE_IMPORT_STDERR='WARNING: harmless synthetic notice')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('WARNING: harmless synthetic notice', (self.output / 'editor-import.log').read_text())

if __name__ == '__main__':
    unittest.main(verbosity=2)

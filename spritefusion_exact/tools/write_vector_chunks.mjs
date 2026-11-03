import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
// Test-data packaging only. Concatenation must reproduce the original JSON bytes.
export function writeVectors(target, text) {
  const directory = path.join(path.dirname(target), path.basename(target, '.json') + '.parts');
  fs.mkdirSync(directory, {recursive: true});
  const chunks = [];
  for (let i = 0; i < text.length; i += 60000) {
    const name = `part-${String(chunks.length).padStart(3, '0')}.txt`;
    fs.writeFileSync(path.join(directory, name), text.slice(i, i + 60000));
    chunks.push(path.basename(directory) + '/' + name);
  }
  fs.writeFileSync(target, JSON.stringify({format: 'split-json-v1', bytes: Buffer.byteLength(text),
    sha256: crypto.createHash('sha256').update(text).digest('hex'), chunks}, null, 2) + '\n');
}

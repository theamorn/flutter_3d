// node waits.mjs prof.json — for samples blocked in semaphore_wait_trap, the
// named frames between the wait and the first flutter_scene frame.
import fs from 'node:fs';
const cs = JSON.parse(fs.readFileSync(process.argv[2]));
const name = (f) => { const fn = f.function ?? {}; const o = fn.owner?.name && fn.owner.type !== '@Library' ? fn.owner.name + '.' : ''; return o + (fn.name ?? '?'); };
const url = (f) => f.resolvedUrl ?? '';
const n = cs.samples.length; const agg = new Map();
for (const s of cs.samples) {
  if (!s.stack?.length || name(cs.functions[s.stack[0]]) !== 'semaphore_wait_trap') continue;
  const chain = [];
  for (const i of s.stack.slice(1)) {
    const f = cs.functions[i]; const nm = name(f);
    // Skip redacted natives and the FFI plumbing between the wait and the pass.
    if (nm === '<redacted>' || /InternalFlutterGpu_|\$Method\$FfiNative|\._initialize$|\.CommandBuffer\._$|\._overwrite$/.test(nm)) continue;
    chain.push(nm.replace(/\(.*$/, ''));
    if (/flutter_scene/.test(url(f))) break;
    if (chain.length > 7) break;
  }
  const k = chain.join('  <-  '); agg.set(k, (agg.get(k) ?? 0) + 1);
}
for (const [k, v] of [...agg].sort((a, b) => b[1] - a[1]).slice(0, 12)) console.log(`${(100 * v / n).toFixed(1).padStart(5)}%  ${k}`);

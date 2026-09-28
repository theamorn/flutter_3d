// node cpuprof.mjs <ws-url> <seconds> <label> [out.json]
// Samples the main isolate's CPU (the Flutter UI thread) for <seconds> via the
// VM service and prints where the time went: top functions by self time, and
// package code (flutter_scene and the app, not Flutter or dart:) by inclusive time.
import fs from 'node:fs';
const [url, secs = '4', label = '', out] = process.argv.slice(2);
const ws = new WebSocket(url);
let id = 0;
const pending = new Map();
const call = (method, params = {}) =>
  new Promise((res, rej) => {
    const i = String(++id);
    pending.set(i, { res, rej });
    ws.send(JSON.stringify({ jsonrpc: '2.0', id: i, method, params }));
  });
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  const p = pending.get(d.id);
  if (!p) return;
  pending.delete(d.id);
  d.error ? p.rej(new Error(JSON.stringify(d.error))) : p.res(d.result);
};
ws.onerror = (e) => { console.log(`${label} ws error ${e.message ?? e}`); process.exit(3); };
const nameOf = (f) => {
  const fn = f.function ?? {};
  const own = fn.owner?.name && fn.owner.type !== '@Library' ? `${fn.owner.name}.` : '';
  return `${own}${fn.name ?? '?'}`;
};
const pkg = (f) => (f.resolvedUrl ?? '').replace(/^.*\/(lib|packages)\//, '').replace(/^package:/, '');
ws.onopen = async () => {
  const vm = await call('getVM');
  const iso = vm.isolates.find((i) => i.name === 'main') ?? vm.isolates[0];
  const t0 = (await call('getVMTimelineMicros')).timestamp;
  await new Promise((r) => setTimeout(r, Number(secs) * 1000));
  const cs = await call('getCpuSamples', {
    isolateId: iso.id, timeOriginMicros: t0, timeExtentMicros: Number(secs) * 1e6,
  });
  if (out) fs.writeFileSync(out, JSON.stringify(cs));
  const n = cs.sampleCount ?? cs.samples.length;
  if (!n) { console.log(`${label}: NO SAMPLES`); process.exit(2); }
  // Inclusive ticks per function, counted once per sample (recursion-safe).
  const incl = new Array(cs.functions.length).fill(0);
  const excl = new Array(cs.functions.length).fill(0);
  for (const s of cs.samples) {
    if (!s.stack?.length) continue;
    excl[s.stack[0]]++;
    for (const i of new Set(s.stack)) incl[i]++;
  }
  const pct = (t) => ((100 * t) / n).toFixed(1).padStart(5) + '%';
  console.log(`== ${label}: ${n} samples over ${secs}s (period ${cs.samplePeriod} us)`);
  const rows = cs.functions.map((f, i) => ({ i, name: nameOf(f), pkg: pkg(f), kind: f.kind, incl: incl[i], excl: excl[i] }));
  console.log('-- top self time');
  for (const r of [...rows].sort((a, b) => b.excl - a.excl).slice(0, 25))
    console.log(`${pct(r.excl)} self ${pct(r.incl)} incl  ${r.name}  [${r.kind} ${r.pkg}]`);
  // Package code only (URLs are file paths): skips the Flutter SDK, the
  // engine's natives and vector_math, keeps flutter_scene and the app.
  const ours = (u = '') =>
    u.startsWith('file:') && !/\/packages\/flutter\/lib\/|\/bin\/cache\/|\/vector_math-/.test(u);
  console.log('-- package code (flutter_scene + app) by inclusive time');
  for (const r of rows
    .filter((r) => ours(cs.functions[r.i].resolvedUrl))
    .sort((a, b) => b.incl - a.incl).slice(0, 60))
    console.log(`${pct(r.incl)} incl ${pct(r.excl)} self  ${r.name}  [${r.pkg}]`);
  process.exit(0);
};

// node frames.mjs <ws-url> <seconds> [label]
// Listens to the VM service Extension stream for the engine's Flutter.Frame
// events (debug and profile builds) and prints frames per second plus build
// (UI) and raster mean/p90 in ms. The stream first replays a backlog of older
// frames, so frames are deduplicated by number and only the last <seconds>
// seconds (by the frames' own start times) are counted.
const [url, secs = '5', label = ''] = process.argv.slice(2);
if (!url) {
  console.log('usage: node frames.mjs ws://127.0.0.1:PORT/TOKEN=/ws <seconds> [label]');
  process.exit(1);
}
const ws = new WebSocket(url);
const byNumber = new Map();
const pct = (a, p) => [...a].sort((x, y) => x - y)[Math.min(a.length - 1, Math.floor(p * a.length))];
const mean = (a) => a.reduce((x, y) => x + y, 0) / a.length;
ws.onopen = () => {
  ws.send(JSON.stringify({ jsonrpc: '2.0', id: '1', method: 'streamListen', params: { streamId: 'Extension' } }));
  setTimeout(() => {
    ws.close();
    const all = [...byNumber.values()].sort((a, b) => a.startTime - b.startTime);
    if (all.length < 2) {
      console.log(`${label} NO FRAMES in ${secs}s (is the app idle, or the URL wrong?)`);
      process.exit(2);
    }
    const cut = all[all.length - 1].startTime - Number(secs) * 1e6;
    const f = all.filter((x) => x.startTime >= cut);
    const span = (f[f.length - 1].startTime - f[0].startTime) / 1e6;
    const ms = (k) => f.map((x) => x[k] / 1000);
    const [b, r, e] = [ms('build'), ms('raster'), ms('elapsed')];
    console.log(
      `${label} fps=${((f.length - 1) / span).toFixed(1)} n=${f.length} ` +
        `build ${mean(b).toFixed(1)}/${pct(b, 0.9).toFixed(1)} ` +
        `raster ${mean(r).toFixed(1)}/${pct(r, 0.9).toFixed(1)} ` +
        `frame ${mean(e).toFixed(1)}/${pct(e, 0.9).toFixed(1)} ms (mean/p90)`,
    );
    process.exit(0);
  }, Number(secs) * 1000);
};
ws.onmessage = (m) => {
  const ev = JSON.parse(m.data).params?.event;
  if (ev?.kind === 'Extension' && ev.extensionKind === 'Flutter.Frame') byNumber.set(ev.extensionData.number, ev.extensionData);
};
ws.onerror = (e) => {
  console.log(`${label} ws error: ${e.message ?? e}`);
  process.exit(3);
};

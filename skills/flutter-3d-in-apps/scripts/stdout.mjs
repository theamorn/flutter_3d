// node stdout.mjs <ws-url> <pattern> [maxSeconds]
// Streams the app's stdout (print/debugPrint) from the VM service until a
// line contains <pattern>, then exits 0; exits 2 after maxSeconds (default
// 900). Use it for probe output: in profile runs, `flutter run`'s own log can
// stop showing the app's output while the VM service still has every line.
const [url, pattern, max = '900'] = process.argv.slice(2);
if (!url || !pattern) {
  console.log('usage: node stdout.mjs ws://127.0.0.1:PORT/TOKEN=/ws <pattern> [maxSeconds]');
  process.exit(1);
}
const ws = new WebSocket(url);
ws.onopen = () => {
  ws.send(JSON.stringify({ jsonrpc: '2.0', id: '1', method: 'streamListen', params: { streamId: 'Stdout' } }));
  setTimeout(() => process.exit(2), Number(max) * 1000);
};
ws.onmessage = (m) => {
  const ev = JSON.parse(m.data).params?.event;
  if (!ev?.bytes) return;
  const text = Buffer.from(ev.bytes, 'base64').toString();
  process.stdout.write(text);
  if (text.includes(pattern)) process.exit(0);
};
ws.onerror = (e) => {
  console.log(`ws error: ${e.message ?? e}`);
  process.exit(3);
};

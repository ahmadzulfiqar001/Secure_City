"""Dev-only browser test page for the /ws gateway. Not mounted in
production — see main.py, which only includes this router when
settings.environment != "production"."""
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["realtime"])

_PAGE = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>SecureCity WS Test</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 2rem; background: #0f1115; color: #e6e6e6; }
  input, button { font-size: 0.95rem; padding: 0.4rem 0.6rem; margin-right: 0.5rem; }
  #status { font-weight: bold; }
  #log { margin-top: 1rem; border: 1px solid #333; border-radius: 6px; padding: 0.75rem;
         height: 60vh; overflow-y: auto; background: #1a1d24; white-space: pre-wrap; font-family: monospace; font-size: 0.85rem; }
  .ok { color: #4ade80; } .bad { color: #f87171; } .evt { color: #60a5fa; } .hb { color: #a1a1aa; }
</style>
</head>
<body>
  <h2>SecureCity /ws test page (dev only)</h2>
  <p>Paste an access token from <code>POST /api/v1/auth/login</code>, then Connect. Open this page in two tabs and POST an alert via Swagger to see both receive <code>alert.new</code>.</p>
  <div>
    <input id="token" type="text" placeholder="access token" size="60">
    <button id="connectBtn">Connect</button>
    <button id="disconnectBtn">Disconnect</button>
    <span id="status">disconnected</span>
  </div>
  <div id="log"></div>

<script>
let ws = null;
let manualClose = false;
let reconnectAttempt = 0;
const logEl = document.getElementById('log');
const statusEl = document.getElementById('status');

function log(msg, cls) {
  const line = document.createElement('div');
  if (cls) line.className = cls;
  line.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
  logEl.appendChild(line);
  logEl.scrollTop = logEl.scrollHeight;
}

function setStatus(text, cls) {
  statusEl.textContent = text;
  statusEl.className = cls || '';
}

function connect() {
  const token = document.getElementById('token').value.trim();
  if (!token) { alert('paste a token first'); return; }
  manualClose = false;
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  ws = new WebSocket(`${proto}://${location.host}/ws?token=${encodeURIComponent(token)}`);

  ws.onopen = () => {
    reconnectAttempt = 0;
    setStatus('connected', 'ok');
    log('connected', 'ok');
  };

  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.event === 'ping') {
      ws.send(JSON.stringify({ event: 'pong' }));
      log('ping -> pong', 'hb');
      return;
    }
    log(`${msg.event}: ${JSON.stringify(msg.data)}`, 'evt');
  };

  ws.onclose = (ev) => {
    setStatus('disconnected', 'bad');
    log(`closed (code=${ev.code})`, 'bad');
    if (!manualClose) scheduleReconnect();
  };

  ws.onerror = () => log('error', 'bad');
}

function scheduleReconnect() {
  const delay = Math.min(30000, 1000 * Math.pow(2, reconnectAttempt));
  reconnectAttempt += 1;
  setStatus(`reconnecting in ${Math.round(delay / 1000)}s`, 'bad');
  setTimeout(() => { if (!manualClose) connect(); }, delay);
}

document.getElementById('connectBtn').onclick = connect;
document.getElementById('disconnectBtn').onclick = () => {
  manualClose = true;
  if (ws) ws.close();
};
</script>
</body>
</html>
"""


@router.get("/ws-test", response_class=HTMLResponse)
def ws_test_page():
    return HTMLResponse(_PAGE)

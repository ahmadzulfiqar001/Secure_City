// SecureCity admin dashboard — wires the static UI in index.html to the
// FastAPI backend (REST polling for health/stats/history, WebSocket for the
// live alert feed, MJPEG <img> already handled by the browser itself).

const $ = (id) => document.getElementById(id);

const els = {
  engineStatus: $("engine-status"),
  clock: $("clock"),
  cameraSelect: $("camera-select"),
  btnWebcam: $("btn-webcam"),
  videoUpload: $("video-upload"),
  btnDemo: $("btn-demo"),
  statTotal: $("stat-total"),
  statHigh: $("stat-high"),
  statRisk: $("stat-risk"),
  statPersons: $("stat-persons"),
  wsStatus: $("ws-status"),
  liveAlerts: $("live-alerts"),
  filterSev: $("filter-sev"),
  btnRefresh: $("btn-refresh"),
  btnClear: $("btn-clear"),
  historyBody: $("history-body"),
  modal: $("modal"),
  modalImg: $("modal-img"),
  modalClose: $("modal-close"),
};

let currentSource = "0"; // "0" = webcam, otherwise an uploaded file path
let liveCount = 0;

// ── clock ──────────────────────────────────────────────────────────
function tickClock() {
  els.clock.textContent = new Date().toLocaleTimeString();
}
setInterval(tickClock, 1000);
tickClock();

// ── helpers ────────────────────────────────────────────────────────
function fmtTime(iso) {
  return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function setEngineStatus(ok, label) {
  els.engineStatus.classList.toggle("ok", ok === true);
  els.engineStatus.classList.toggle("err", ok === false);
  els.engineStatus.innerHTML = `<span class="dot"></span> ${label}`;
}

// ── cameras ────────────────────────────────────────────────────────
async function loadCameras() {
  const res = await fetch("/api/cameras");
  const cams = await res.json();
  els.cameraSelect.innerHTML = cams
    .map((c) => `<option value="${c.id}">${c.id} — ${c.name}${c.status === "active" ? " (active)" : ""}</option>`)
    .join("");
}

async function setSource(source, cameraId) {
  await fetch("/api/source", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ source, camera_id: cameraId || els.cameraSelect.value || undefined }),
  });
}

els.cameraSelect.addEventListener("change", () => setSource(currentSource, els.cameraSelect.value));

els.btnWebcam.addEventListener("click", async () => {
  currentSource = "0";
  await setSource(currentSource);
});

els.videoUpload.addEventListener("change", async (e) => {
  const file = e.target.files[0];
  if (!file) return;
  const form = new FormData();
  form.append("file", file);
  const res = await fetch("/api/upload", { method: "POST", body: form });
  const data = await res.json();
  if (data.ok) {
    currentSource = data.path;
    await setSource(currentSource, els.cameraSelect.value);
  }
  e.target.value = "";
});

els.btnDemo.addEventListener("click", async () => {
  await fetch("/api/demo-alert", { method: "POST" });
  refreshHistory();
});

// ── health + stats polling ───────────────────────────────────────────
async function pollHealth() {
  try {
    const res = await fetch("/api/health");
    const data = await res.json();
    setEngineStatus(data.source_ok, data.model_ready ? "Live" : "Loading model…");
    if (data.camera && els.cameraSelect.value !== data.camera.id) {
      els.cameraSelect.value = data.camera.id;
    }
  } catch {
    setEngineStatus(false, "Offline");
  }
}

async function pollStats() {
  try {
    const res = await fetch("/api/stats");
    const data = await res.json();
    els.statTotal.textContent = data.total_alerts ?? "–";
    els.statHigh.textContent = data.high ?? "–";
    els.statRisk.textContent = data.risk_level ?? "–";
    els.statPersons.textContent = data.person_count ?? "–";
  } catch {
    // backend unreachable; leave last known values on screen
  }
}

setInterval(() => {
  pollHealth();
  pollStats();
}, 3000);
pollHealth();
pollStats();

// ── alert history table ─────────────────────────────────────────────
function renderHistoryRow(a) {
  const snap = a.snapshot
    ? `<span class="snap-link" data-snap="${a.snapshot}">View</span>`
    : "–";
  return `<tr>
    <td>${a.id}</td>
    <td>${fmtTime(a.ts)}</td>
    <td class="type">${a.type}</td>
    <td>${a.camera_name}</td>
    <td><span class="sev ${a.severity}">${a.severity.toUpperCase()}</span></td>
    <td>${a.details && Object.keys(a.details).length ? JSON.stringify(a.details) : "–"}</td>
    <td>${snap}</td>
  </tr>`;
}

async function refreshHistory() {
  const sev = els.filterSev.value;
  const url = sev ? `/api/alerts?limit=100&severity=${sev}` : "/api/alerts?limit=100";
  const res = await fetch(url);
  const rows = await res.json();
  els.historyBody.innerHTML = rows.map(renderHistoryRow).join("") ||
    `<tr><td colspan="7" style="text-align:center;color:var(--muted)">No alerts yet</td></tr>`;
}

els.filterSev.addEventListener("change", refreshHistory);
els.btnRefresh.addEventListener("click", refreshHistory);

els.btnClear.addEventListener("click", async () => {
  if (!confirm("Clear all alert history? This cannot be undone.")) return;
  await fetch("/api/alerts", { method: "DELETE" });
  liveCount = 0;
  els.liveAlerts.innerHTML = `<li class="empty">Waiting for detections…</li>`;
  refreshHistory();
});

els.historyBody.addEventListener("click", (e) => {
  const target = e.target.closest(".snap-link");
  if (!target) return;
  els.modalImg.src = `/api/snapshots/${target.dataset.snap}`;
  els.modal.hidden = false;
});

els.modalClose.addEventListener("click", () => {
  els.modal.hidden = true;
  els.modalImg.src = "";
});
els.modal.addEventListener("click", (e) => {
  if (e.target === els.modal) els.modalClose.click();
});

// ── live alert feed over WebSocket ──────────────────────────────────
function connectAlertsSocket() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  const ws = new WebSocket(`${proto}//${location.host}/ws/alerts`);

  ws.onopen = () => {
    els.wsStatus.textContent = "live";
    els.wsStatus.classList.add("on");
  };

  ws.onclose = () => {
    els.wsStatus.textContent = "offline";
    els.wsStatus.classList.remove("on");
    setTimeout(connectAlertsSocket, 2000); // auto-reconnect
  };

  ws.onerror = () => ws.close();

  ws.onmessage = (evt) => {
    const alert = JSON.parse(evt.data);
    if (liveCount === 0) els.liveAlerts.innerHTML = "";
    const li = document.createElement("li");
    li.className = `live-item ${alert.severity}`;
    li.innerHTML = `
      <div>
        <div class="t">${alert.type}</div>
        <div class="loc">${alert.camera_name}</div>
      </div>
      <div class="time">${fmtTime(alert.ts)}</div>`;
    els.liveAlerts.prepend(li);
    liveCount++;
    while (els.liveAlerts.children.length > 20) {
      els.liveAlerts.removeChild(els.liveAlerts.lastChild);
    }
    pollStats();
    refreshHistory();
  };
}

// ── boot ──────────────────────────────────────────────────────────
loadCameras();
refreshHistory();
connectAlertsSocket();

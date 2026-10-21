"use strict";

const REFRESH_MS = 5000;
const FETCH_TIMEOUT_MS = 6000;

const PILL_LABELS = {
  active: "Aktiv",
  ready: "Bereit",
  connected: "Verbunden",
  paired: "Gekoppelt",
  offline: "Offline",
  missing: "Nicht gefunden",
  error: "Fehler"
};

const PILL_TONES = {
  active: "good",
  ready: "info",
  connected: "good",
  paired: "warn",
  offline: "warn",
  missing: "idle",
  error: "bad"
};

let inFlight = false;
let nextTimer = 0;
let lastFetch = 0;

const byId = (id) => document.getElementById(id);

function setText(id, text, tone) {
  const element = byId(id);
  if (!element) return;
  element.textContent = text;
  element.classList.toggle("is-warn", tone === "warn");
  element.classList.toggle("is-good", tone === "good");
}

function setPill(id, status, labelOverride) {
  const pill = byId(id);
  if (!pill) return;
  const label = pill.querySelector(".pill-text");
  if (!label) return;
  pill.dataset.tone = PILL_TONES[status] || "idle";
  label.textContent = labelOverride || PILL_LABELS[status] || "Unbekannt";
}

function setHero(id, value, isEmpty) {
  const element = byId(id);
  if (!element) return;
  element.textContent = value;
  element.classList.toggle("is-empty", Boolean(isEmpty));
}

function setNote(id, text, isError) {
  const note = byId(id);
  if (!note) return;
  note.textContent = text;
  note.classList.toggle("is-error", Boolean(isError));
}

function setCardError(id, isError) {
  const card = byId(id);
  if (card) card.classList.toggle("is-error", Boolean(isError));
}

function plural(count, one, many) {
  return count === 1 ? one : many;
}

function formatTime(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "gerade eben";
  return new Intl.DateTimeFormat("de-DE", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit"
  }).format(date);
}

function renderList(listId, items, emptyText) {
  const list = byId(listId);
  if (!list) return;
  list.textContent = "";

  if (!items.length) {
    const empty = document.createElement("li");
    empty.className = "empty";
    empty.textContent = emptyText;
    list.appendChild(empty);
    return;
  }

  for (const item of items) {
    const row = document.createElement("li");

    const name = document.createElement("span");
    name.className = "item-name";

    if (item.tone) {
      const dot = document.createElement("span");
      dot.className = "status-dot";
      dot.dataset.tone = item.tone;
      name.appendChild(dot);
    }

    const text = document.createElement("span");
    text.textContent = item.name;
    text.title = item.title || item.name;
    name.appendChild(text);
    row.appendChild(name);

    if (item.meta) {
      const meta = document.createElement("span");
      meta.className = "item-meta";
      meta.textContent = item.meta;
      row.appendChild(meta);
    }

    list.appendChild(row);
  }
}

function renderLocalSend(section) {
  const data = section || {};
  const peers = Array.isArray(data.peers) ? data.peers : [];
  const firewall = Array.isArray(data.firewallProfiles) ? data.firewallProfiles : [];
  const networks = Array.isArray(data.networkProfiles) ? data.networkProfiles : [];
  const status = data.status || "missing";
  const exposed = firewall.some((profile) => String(profile).toLowerCase() === "public");
  const publicNetwork = networks.some((network) => String(network.category).toLowerCase() === "public");

  setPill("ls-pill", status, status === "missing" ? "Nicht installiert" : undefined);
  setCardError("card-localsend", status === "error");

  const showCount = status === "active" || status === "ready";
  setHero("ls-hero", showCount ? String(peers.length) : "—", !showCount);
  setText(
    "ls-hero-label",
    showCount ? plural(peers.length, "aktive Verbindung", "aktive Verbindungen") : "keine Abfrage möglich"
  );

  setText("ls-version", data.version || "—");
  setText("ls-port", data.port ? String(data.port) : "—");
  setText("ls-firewall", firewall.length ? firewall.join(" + ") : "Keine Regel", exposed ? "warn" : undefined);
  const publicNames = networks
    .filter((network) => String(network.category).toLowerCase() === "public")
    .map((network) => network.name || "Netzwerk");
  const networkText = !networks.length
    ? "Keine Profile"
    : publicNames.length
      ? `Public · ${publicNames.join(", ")}`
      : "Privat";

  setText("ls-network", networkText, publicNetwork ? "warn" : undefined);

  const networkElement = byId("ls-network");
  if (networkElement) {
    networkElement.title = networks
      .map((network) => `${network.name || "Netzwerk"} (${network.category || "?"})`)
      .join(" · ");
  }

  setText("ls-peer-count", peers.length ? `${peers.length} aktiv` : "keine");
  renderList(
    "ls-peers",
    peers.map((peer) => ({
      name: String(peer.address || "Unbekannt"),
      meta: peer.port ? `TCP ${peer.port}` : "TCP",
      tone: "good"
    })),
    "Keine aktiven Übertragungen"
  );

  if (data.error) {
    setNote("ls-note", `Abfragefehler: ${data.error}`, true);
  } else if (!data.installed) {
    setNote("ls-note", "LocalSend ist nicht installiert. Dieses Dashboard installiert nichts.");
  } else if (data.listening) {
    setNote(
      "ls-note",
      `App läuft und lauscht auf ${data.port || 53317}. Peers erscheinen nur während einer Übertragung.`
    );
  } else {
    setNote("ls-note", `Kein Listener auf ${data.port || 53317}. App starten, um Übertragungen zu sehen.`);
  }
}

function renderAirPods(section) {
  const data = section || {};
  const endpoints = Array.isArray(data.endpoints) ? data.endpoints : [];
  const status = data.status || "missing";
  const hasA2dp = endpoints.some((endpoint) => endpoint.kind === "A2DP");
  const hasHfp = endpoints.some((endpoint) => endpoint.kind === "HFP");
  const idle = endpoints.filter((endpoint) => !endpoint.active).length;
  const showCount = status === "connected" || status === "paired";

  setPill("ap-pill", status, status === "missing" ? "Nicht gefunden" : undefined);
  setCardError("card-airpods", status === "error");

  setHero("ap-hero", showCount ? String(endpoints.length) : "—", !showCount);
  setText(
    "ap-hero-label",
    showCount ? plural(endpoints.length, "Audio-Endpunkt", "Audio-Endpunkte") : "keine Endpunkte"
  );

  setText("ap-device", data.deviceName || "—", status === "paired" ? "warn" : undefined);
  setText("ap-a2dp", hasA2dp ? "vorhanden" : "fehlt", hasA2dp ? "good" : "warn");
  setText("ap-hfp", hasHfp ? "vorhanden" : "fehlt", hasHfp ? "good" : "warn");
  setText("ap-idle", endpoints.length ? `${idle} von ${endpoints.length}` : "—");

  setText("ap-endpoint-count", endpoints.length ? `${endpoints.length} gesamt` : "keine");
  renderList(
    "ap-endpoints",
    endpoints.map((endpoint) => {
      const fullName = String(endpoint.name || "Endpunkt");
      const shortName = fullName.replace(/\s*\([^)]*\)\s*$/, "").trim() || fullName;

      return {
        name: endpoint.kind === "HFP" ? `${shortName} · Hands-Free` : shortName,
        title: fullName,
        meta: endpoint.active ? `${endpoint.kind} · aktiv` : `${endpoint.kind} · im Case`,
        tone: endpoint.active ? "good" : "idle"
      };
    }),
    "Keine Endpunkte gefunden"
  );

  if (data.error) {
    setNote("ap-note", `Abfragefehler: ${data.error}`, true);
  } else if (status === "connected") {
    setNote("ap-note", "Mindestens ein Endpunkt ist aktiv. Batteriestand ist unter Windows nicht abrufbar.");
  } else if (status === "paired") {
    setNote("ap-note", "Gekoppelt, aber im Case oder getrennt. Endpunkte erscheinen beim Einsetzen.");
  } else {
    setNote("ap-note", "Keine AirPods in den Bluetooth-Geräten gefunden.");
  }
}

function renderDeskreen(section) {
  const data = section || {};
  const status = data.status || "missing";
  const connections = Number.isFinite(data.connections) ? data.connections : 0;
  const viewers = [];

  for (let index = 1; index <= connections; index += 1) {
    viewers.push({ name: `Viewer ${index}`, meta: "WebRTC", tone: "good" });
  }

  setPill("dk-pill", status, status === "missing" ? "Nicht installiert" : undefined);
  setCardError("card-deskreen", status === "error");

  setHero("dk-hero", data.running ? String(connections) : "—", !data.running);
  setText(
    "dk-hero-label",
    data.running ? plural(connections, "aktiver Viewer", "aktive Viewer") : "App nicht aktiv"
  );

  setText("dk-version", data.version || "—");
  setText("dk-virtual", data.virtualDisplay ? "vorhanden" : "fehlt", data.virtualDisplay ? "good" : "warn");
  setText("dk-process", data.running ? "läuft" : "nein");
  setText("dk-mode", data.virtualDisplay ? "Erweitern möglich" : "nur Spiegeln");

  setText("dk-session-count", connections ? `${connections} verbunden` : "keine");
  renderList("dk-sessions", viewers, "Keine aktive Freigabe");

  if (data.error) {
    setNote("dk-note", `Abfragefehler: ${data.error}`, true);
  } else if (status === "active") {
    setNote("dk-note", `${connections} Viewer verbunden. Freigabe beenden trennt die Sitzung sofort.`);
  } else if (data.installed) {
    setNote(
      "dk-note",
      data.virtualDisplay
        ? "Bereit. Ein virtueller Monitor ist vorhanden, Erweitern ist möglich."
        : "Bereit. Ohne virtuellen Monitor ist nur Spiegeln möglich."
    );
  } else {
    setNote("dk-note", "Nicht installiert. Ohne virtuellen Monitor wäre ohnehin nur Spiegeln möglich.");
  }
}

function renderBaseline(section) {
  const data = section || {};
  const settings = Array.isArray(data.settings) ? data.settings : [];
  const segments = byId("baseline-segments");

  if (segments) {
    segments.textContent = "";
    for (const setting of settings) {
      const segment = document.createElement("span");
      segment.className = "segment";
      segment.dataset.state = String(setting.status || "").toLowerCase();
      segment.title = `${setting.label || setting.id || "Wert"}: ${setting.status || "?"}`;
      segments.appendChild(segment);
    }
  }

  setText("baseline-count", `${data.pass || 0}/${settings.length} konform`);

  const taskbar = byId("taskbar-tag");
  if (taskbar) {
    taskbar.textContent = `Taskleiste: ${data.taskbarMode || "—"}`;
    taskbar.dataset.tone = data.seelenRunning ? "warn" : "";
  }

  const protectedTag = byId("protected-tag");
  if (protectedTag) {
    protectedTag.textContent = `TaskbarDa: ${data.taskbarDaProtected ? "geschützt" : "ok"}`;
    protectedTag.dataset.tone = data.taskbarDaProtected ? "warn" : "";
  }
}

function render(data) {
  const host = data.host || {};

  renderLocalSend(data.localsend);
  renderAirPods(data.airpods);
  renderDeskreen(data.deskreen);
  renderBaseline(data.baseline);

  const hostNote = byId("host-note");
  if (hostNote) {
    const build = host.build ? ` · Build ${host.build}` : "";
    hostNote.textContent = `${host.name || "Lokaler PC"}${build}`;
  }
}

function setLive(tone, label, stamp) {
  const dot = byId("live-dot");
  if (dot) dot.dataset.tone = tone;

  const labelElement = byId("live-label");
  if (labelElement) labelElement.textContent = label;

  if (stamp) {
    const updated = byId("last-updated");
    if (updated) updated.textContent = `Zuletzt ${stamp}`;
  }
}

async function refresh() {
  if (inFlight) return;
  inFlight = true;

  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const response = await fetch("/api/status", {
      cache: "no-store",
      signal: controller.signal,
      headers: { Accept: "application/json" }
    });

    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const data = await response.json();
    render(data);

    document.body.classList.add("is-ready");
    byId("error-banner").hidden = true;
    byId("main").classList.remove("is-stale");
    byId("main").setAttribute("aria-busy", "false");

    lastFetch = Date.now();
    setLive("good", "Live", formatTime(data.generatedAt));
  } catch (error) {
    const reason = error.name === "AbortError" ? "Zeitüberschreitung" : error.message;
    setLive("bad", "Collector offline");
    byId("error-banner").hidden = false;
    byId("error-text").textContent = `Status nicht erreichbar (${reason}). Der letzte Wert bleibt sichtbar.`;
    byId("main").classList.add("is-stale");
    byId("main").setAttribute("aria-busy", "false");
  } finally {
    window.clearTimeout(timeout);
    inFlight = false;
    window.clearTimeout(nextTimer);
    nextTimer = window.setTimeout(refresh, REFRESH_MS);
  }
}

byId("retry").addEventListener("click", () => {
  if (!inFlight) refresh();
});

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && Date.now() - lastFetch > REFRESH_MS && !inFlight) {
    refresh();
  }
});

refresh();

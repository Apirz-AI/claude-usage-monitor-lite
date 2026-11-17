// ClaudeUsage – Scriptable widget for your Claude plan limit (Claude Usage Monitor)
// Zeigt Sitzungs-Limit (5 Stunden) und Wochen-Limit (7 Tage) mit Reset-Countdown.
// Einrichtung: QR-Code vom Windows-Setup-Skript mit der iPhone-Kamera scannen.
// Hinweis: Nutzt einen inoffiziellen Endpunkt von Anthropic – kann sich jederzeit aendern.

const CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
const TOKEN_URLS = [
  "https://platform.claude.com/v1/oauth/token",
  "https://console.anthropic.com/v1/oauth/token",
];
const USAGE_URL = "https://api.anthropic.com/api/oauth/usage";
const KC_RT = "claudeusage_rt";
const KC_AT = "claudeusage_at";
const KC_EXP = "claudeusage_exp";

// Sprache automatisch nach iPhone-Einstellung / language follows the iPhone setting
const DE = (Device.language() || "").toLowerCase().startsWith("de");
function L(de, en) { return DE ? de : en; }

const fm = FileManager.local();
const CACHE = fm.joinPath(fm.documentsDirectory(), "claudeusage_cache.json");

// ---------- Einrichtung ueber QR-Code ----------
const qp = args.queryParameters || {};
if (qp.rt) {
  Keychain.set(KC_RT, qp.rt);
  if (Keychain.contains(KC_AT)) Keychain.remove(KC_AT);
  Keychain.set(KC_EXP, "0");
  const a = new Alert();
  a.title = L("Verbunden ✓", "Connected ✓");
  a.message = L("Zugang gespeichert. Leg jetzt das Widget „ClaudeUsage“ auf den Home- oder Sperrbildschirm.", "Access saved. Now add the “ClaudeUsage” widget to your Home or Lock Screen.");
  a.addAction("OK");
  await a.present();
}

function kc(k) { return Keychain.contains(k) ? Keychain.get(k) : null; }

// ---------- Token erneuern ----------
async function refreshToken() {
  const rt = kc(KC_RT);
  if (!rt) throw new Error(L("Nicht eingerichtet – QR-Code vom PC scannen.", "Not set up – scan the QR code from your PC."));
  let lastErr = "";
  for (const url of TOKEN_URLS) {
    try {
      const r = new Request(url);
      r.method = "POST";
      r.headers = { "Content-Type": "application/json" };
      r.body = JSON.stringify({ grant_type: "refresh_token", refresh_token: rt, client_id: CLIENT_ID });
      const j = await r.loadJSON();
      const code = r.response.statusCode;
      if (code === 200 && j.access_token) {
        Keychain.set(KC_AT, j.access_token);
        if (j.refresh_token) Keychain.set(KC_RT, j.refresh_token);
        Keychain.set(KC_EXP, String(Date.now() + (j.expires_in || 3600) * 1000));
        return j.access_token;
      }
      lastErr = j.error_description || j.error || ("HTTP " + code);
      if (code === 400 || code === 401) break; // Token ungueltig – zweiter Server hilft nicht
    } catch (e) { lastErr = e.message; }
  }
  throw new Error(L("Anmeldung abgelaufen – Setup am PC neu ausführen. (", "Login expired – run the setup on your PC again. (") + lastErr + ")");
}

async function getToken(force) {
  const at = kc(KC_AT);
  const exp = Number(kc(KC_EXP) || 0);
  if (!force && at && exp > Date.now() + 5 * 60 * 1000) return at;
  return await refreshToken();
}

// ---------- Verbrauch abrufen ----------
async function callUsage(token) {
  const r = new Request(USAGE_URL);
  r.headers = {
    "Authorization": "Bearer " + token,
    "anthropic-beta": "oauth-2025-04-20",
    "User-Agent": "claude-cli/1.0",
  };
  const j = await r.loadJSON();
  return { code: r.response.statusCode, json: j };
}

async function loadUsage() {
  let res = await callUsage(await getToken(false));
  if (res.code === 401) res = await callUsage(await getToken(true));
  if (res.code !== 200) throw new Error(L("Abruf fehlgeschlagen (HTTP ", "Request failed (HTTP ") + res.code + ")");
  const data = { ...res.json, fetchedAt: Date.now() };
  fm.writeString(CACHE, JSON.stringify(data));
  return data;
}

function readCache() {
  try { return fm.fileExists(CACHE) ? JSON.parse(fm.readString(CACHE)) : null; } catch (e) { return null; }
}

// ---------- Hilfsfunktionen ----------
function pct(bucket) { return bucket && bucket.utilization != null ? Math.round(bucket.utilization) : 0; }

function countdown(iso) {
  if (!iso) return "–";
  let s = Math.max(0, Math.floor((new Date(iso).getTime() - Date.now()) / 1000));
  const d = Math.floor(s / 86400); s -= d * 86400;
  const h = Math.floor(s / 3600); s -= h * 3600;
  const m = Math.floor(s / 60);
  if (d > 0) return d + (DE ? " T " : " d ") + h + " h";
  if (h > 0) return h + " h " + m + " min";
  return m + " min";
}

function levelColor(p) {
  if (p >= 90) return new Color("#FF3B30");
  if (p >= 75) return new Color("#FF9500");
  return new Color("#D97757");
}

function bar(p, w, h) {
  const dc = new DrawContext();
  dc.size = new Size(w, h);
  dc.opaque = false;
  dc.respectScreenScale = true;
  const bg = new Path();
  bg.addRoundedRect(new Rect(0, 0, w, h), h / 2, h / 2);
  dc.addPath(bg);
  dc.setFillColor(new Color("#8E8E93", 0.3));
  dc.fillPath();
  if (p > 0) {
    const fw = Math.max(h, (w * Math.min(p, 100)) / 100);
    const fg = new Path();
    fg.addRoundedRect(new Rect(0, 0, fw, h), h / 2, h / 2);
    dc.addPath(fg);
    dc.setFillColor(levelColor(p));
    dc.fillPath();
  }
  return dc.getImage();
}

// ---------- Widget bauen ----------
const FG = Color.dynamic(new Color("#000000"), new Color("#FFFFFF"));
const BG = Color.dynamic(new Color("#FFFFFF"), new Color("#000000"));
const SUB = new Color("#8E8E93");

function row(w, label, p, width) {
  const s = w.addStack();
  s.centerAlignContent();
  const l = s.addText(label);
  l.font = Font.mediumSystemFont(12);
  l.textColor = SUB;
  s.addSpacer();
  const v = s.addText(p == null ? "–" : p + " %");
  v.font = Font.boldRoundedSystemFont(16);
  v.textColor = FG;
  w.addSpacer(3);
  const img = w.addImage(bar(p || 0, width, 8));
  img.imageSize = new Size(width, 8);
}

function buildHome(data, err, family) {
  const w = new ListWidget();
  w.backgroundColor = BG;
  w.setPadding(14, 14, 14, 14);
  const width = family === "medium" ? 300 : 130;

  const head = w.addText("✳︎ Claude");
  head.font = Font.boldSystemFont(15);
  head.textColor = new Color("#D97757");
  w.addSpacer(8);

  if (!data) {
    const t = w.addText(err || L("Keine Daten", "No data"));
    t.font = Font.systemFont(11);
    t.textColor = FG;
    return w;
  }

  const s5 = pct(data.five_hour), s7 = pct(data.seven_day);
  row(w, L("Sitzung", "Session"), s5, width);
  w.addSpacer(8);
  row(w, L("Woche", "Week"), s7, width);
  w.addSpacer();

  const r5 = data.five_hour && data.five_hour.resets_at;
  const r = w.addText(r5 ? "Reset in " + countdown(r5) : L("Keine aktive Sitzung", "No active session"));
  r.font = Font.semiboldSystemFont(12);
  r.textColor = FG;
  if (family === "medium") {
    const r2 = w.addText(L("Woche: Reset in ", "Week: reset in ") + countdown(data.seven_day && data.seven_day.resets_at));
    r2.font = Font.systemFont(11);
    r2.textColor = SUB;
  }
  const st = w.addText((err ? "⚠︎ offline · " : "") + L("Stand ", "Updated ") + new Date(data.fetchedAt).toLocaleTimeString(DE ? "de-DE" : undefined, { hour: "2-digit", minute: "2-digit" }));
  st.font = Font.systemFont(9);
  st.textColor = SUB;
  return w;
}

function buildLock(data, err, family) {
  const w = new ListWidget();
  if (!data) { w.addText(err ? L("Claude: Fehler", "Claude: error") : "Claude: –").font = Font.systemFont(12); return w; }
  const s5 = pct(data.five_hour), s7 = pct(data.seven_day);
  if (family === "accessoryCircular") {
    const t = w.addText((s5 ?? "–") + "%");
    t.font = Font.boldRoundedSystemFont(16);
    t.centerAlignText();
    const u = w.addText(L("Sitz.", "Sess."));
    u.font = Font.systemFont(9);
    u.centerAlignText();
    return w;
  }
  if (family === "accessoryInline") {
    w.addText("Claude " + (s5 ?? "–") + "% · " + L("Woche ", "Week ") + (s7 ?? "–") + "%");
    return w;
  }
  const a = w.addText("✳︎ Claude");
  a.font = Font.boldSystemFont(13);
  const b = w.addText(L("Sitzung ", "Session ") + (s5 ?? "–") + "%  ·  " + L("Woche ", "Week ") + (s7 ?? "–") + "%");
  b.font = Font.systemFont(12);
  const r5l = data.five_hour && data.five_hour.resets_at;
  const c = w.addText(r5l ? "Reset in " + countdown(r5l) : L("Keine aktive Sitzung", "No active session"));
  c.font = Font.systemFont(11);
  return w;
}

// ---------- Ablauf ----------
let data = null, err = null;
try { data = await loadUsage(); } catch (e) { err = e.message; data = readCache(); }

const family = config.widgetFamily || "medium";
const widget = family.startsWith("accessory") ? buildLock(data, err, family) : buildHome(data, err, family);
widget.refreshAfterDate = new Date(Date.now() + 5 * 60 * 1000);

if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  if (err && !data) {
    const a = new Alert();
    a.title = "Claude Usage";
    a.message = err;
    a.addAction("OK");
    await a.present();
  }
  await widget.presentMedium();
}
Script.complete();

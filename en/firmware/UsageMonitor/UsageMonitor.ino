// =====================================================================
//  Claude Usage Monitor – zeigt das Claude-Abo-Limit (Sitzung + Woche) auf einem
//  kleinen Retro-Bildschirm an.
//  Hardware: ESP32-2432S028 ("CYD", 2.8 Zoll, quer, 320x240, Touch) – ohne Akku
//
//  Bibliotheken (Arduino Bibliotheksverwalter):
//    - LovyanGFX        (lovyan03)
//    - ArduinoJson      (Benoit Blanchon, Version 7)
//    - WiFiManager      (tzapu)
//
//  Hinweis: Nutzt einen inoffiziellen Endpunkt. Kein Produkt von
//  Anthropic. Kann sich jederzeit aendern.
// =====================================================================
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <WiFiManager.h>
#include <ArduinoJson.h>
#include <LovyanGFX.hpp>
#include <time.h>
#include "config.h"

// Sprache / language: siehe config.h
#define TR(de, en) (LANGUAGE_EN ? (en) : (de))

static const char* CLIENT_ID  = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
static const char* TOKEN_URLS[] = {
  "https://platform.claude.com/v1/oauth/token",
  "https://console.anthropic.com/v1/oauth/token",
};
static const char* USAGE_URL = "https://api.anthropic.com/api/oauth/usage";

// ---------------------------------------------------------------------
// Display-Treiber
// ---------------------------------------------------------------------
#if defined(DISPLAY_ST7789)
typedef lgfx::Panel_ST7789  PanelType;   // seltene Board-Variante, siehe config.h
#else
typedef lgfx::Panel_ILI9341 PanelType;   // Standard
#endif

class LGFX : public lgfx::LGFX_Device {
  PanelType             _panel;
  lgfx::Bus_SPI         _bus;
  lgfx::Touch_XPT2046   _touch;
public:
  LGFX() {
    {
      auto cfg = _bus.config();
      cfg.spi_host    = HSPI_HOST;          // Display haengt an HSPI
      cfg.spi_mode    = 0;
      cfg.freq_write  = 40000000;
      cfg.freq_read   = 16000000;
      cfg.spi_3wire   = false;
      cfg.use_lock    = true;
      cfg.dma_channel = SPI_DMA_CH_AUTO;
      cfg.pin_sclk    = PIN_LCD_SCK;
      cfg.pin_mosi    = PIN_LCD_MOSI;
      cfg.pin_miso    = PIN_LCD_MISO;
      cfg.pin_dc      = PIN_LCD_DC;
      _bus.config(cfg);
      _panel.setBus(&_bus);
    }
    {
      auto cfg = _panel.config();
      cfg.pin_cs        = PIN_LCD_CS;
      cfg.pin_rst       = PIN_LCD_RST;
      cfg.pin_busy      = -1;
      cfg.panel_width   = 240;
      cfg.panel_height  = 320;
      cfg.memory_width  = 240;
      cfg.memory_height = 320;
      cfg.offset_x      = 0;
      cfg.offset_y      = 0;
      cfg.offset_rotation = 0;
      cfg.readable      = false;
      cfg.invert        = DISPLAY_INVERT;
      cfg.rgb_order     = DISPLAY_RGB_ORDER;
      cfg.dlen_16bit    = false;
      cfg.bus_shared    = false;
      _panel.config(cfg);
    }
    {   // Touch (XPT2046) hat eigene Pins auf dem zweiten SPI (VSPI)
      auto cfg = _touch.config();
      cfg.x_min = 300;  cfg.x_max = 3900;
      cfg.y_min = 200;  cfg.y_max = 3800;
      cfg.pin_int  = PIN_TOUCH_IRQ;
      cfg.bus_shared = false;
      cfg.offset_rotation = 0;
      cfg.spi_host = VSPI_HOST;
      cfg.freq     = 1000000;
      cfg.pin_sclk = PIN_TOUCH_SCK;
      cfg.pin_mosi = PIN_TOUCH_MOSI;
      cfg.pin_miso = PIN_TOUCH_MISO;
      cfg.pin_cs   = PIN_TOUCH_CS;
      _touch.config(cfg);
      _panel.setTouch(&_touch);
    }
    setPanel(&_panel);
  }
};

LGFX tft;
LGFX_Sprite canvas(&tft);
Preferences prefs;

// Farben
#define C_BG      0x0000
#define C_TEXT    0xFFFF
#define C_SUB     0x8C71   // grau
#define C_CLAUDE  0xDBAA   // Claude-Orange (#D97757)
#define C_OK      0xDBAA
#define C_WARN    0xFD20
#define C_CRIT    0xF9A6
#define C_FRAME   0x4208

// ---------------------------------------------------------------------
// Zustand
// ---------------------------------------------------------------------
struct Usage {
  bool   valid = false;
  bool   hasSession = false;
  float  session = 0;
  float  week = 0;
  time_t sessionReset = 0;
  time_t weekReset = 0;
  time_t fetchedAt = 0;
} usage;

String statusMsg = "";
bool   needToken = false;
uint32_t lastPollMs = 0;
bool   pollNow = true;

// ---------------------------------------------------------------------
// Hilfsfunktionen Zeit
// ---------------------------------------------------------------------
static int64_t daysFromCivil(int y, unsigned m, unsigned d) {
  y -= m <= 2;
  const int era = (y >= 0 ? y : y - 399) / 400;
  const unsigned yoe = (unsigned)(y - era * 400);
  const unsigned doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
  const unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  return (int64_t)era * 146097 + (int64_t)doe - 719468;
}

static time_t parseIsoUtc(const char* s) {
  if (!s) return 0;
  int Y, M, D, h, m, sec;
  if (sscanf(s, "%d-%d-%dT%d:%d:%d", &Y, &M, &D, &h, &m, &sec) != 6) return 0;
  int64_t t = daysFromCivil(Y, M, D) * 86400LL + h * 3600 + m * 60 + sec;
  // Zeitzonen-Offset (+hh:mm / -hh:mm) beruecksichtigen
  const char* tz = strpbrk(s + 19, "+-Z");
  if (tz && *tz != 'Z') {
    int oh = 0, om = 0;
    if (sscanf(tz + 1, "%d:%d", &oh, &om) >= 1) {
      int off = oh * 3600 + om * 60;
      t += (*tz == '+') ? -off : off;
    }
  }
  return (time_t)t;
}

static bool timeReady() { return time(nullptr) > 1700000000; }

static String countdown(time_t target) {
  if (!target || !timeReady()) return "-";
  long s = (long)(target - time(nullptr));
  if (s < 0) s = 0;
  long d = s / 86400; s %= 86400;
  long h = s / 3600;  s %= 3600;
  long m = s / 60;
  char buf[24];
  if (d > 0)      snprintf(buf, sizeof buf, "%ldT %ldh", d, h);
  else if (h > 0) snprintf(buf, sizeof buf, "%ldh %02ldm", h, m);
  else            snprintf(buf, sizeof buf, "%ldm", m);
  return String(buf);
}

// ---------------------------------------------------------------------
// Token-Verwaltung
// ---------------------------------------------------------------------
static String getRefreshToken() { return prefs.getString("rt", ""); }

// 1 = ok, 0 = Netzwerkfehler, -1 = Token ungueltig
static int refreshAccessToken(String& accessOut) {
  String rt = getRefreshToken();
  if (rt.isEmpty()) return -1;

  for (const char* url : TOKEN_URLS) {
    WiFiClientSecure cli;
    cli.setInsecure();
    HTTPClient http;
    if (!http.begin(cli, url)) continue;
    http.addHeader("Content-Type", "application/json");
    JsonDocument req;
    req["grant_type"] = "refresh_token";
    req["refresh_token"] = rt;
    req["client_id"] = CLIENT_ID;
    String body;
    serializeJson(req, body);
    int code = http.POST(body);
    String resp = http.getString();
    http.end();

    if (code == 200) {
      JsonDocument doc;
      if (deserializeJson(doc, resp)) return 0;
      const char* at = doc["access_token"];
      const char* nrt = doc["refresh_token"];
      long expiresIn = doc["expires_in"] | 3600;
      if (!at) return 0;
      // SOFORT speichern: der alte Refresh-Token ist ab jetzt ungueltig
      if (nrt) prefs.putString("rt", nrt);
      prefs.putString("at", at);
      prefs.putLong64("exp", (int64_t)time(nullptr) + expiresIn);
      accessOut = at;
      return 1;
    }
    if (code == 400 || code == 401) return -1;
  }
  return 0;
}

static int getAccessToken(String& out, bool force) {
  String at = prefs.getString("at", "");
  int64_t exp = prefs.getLong64("exp", 0);
  if (!force && at.length() && timeReady() && exp > (int64_t)time(nullptr) + 300) {
    out = at;
    return 1;
  }
  return refreshAccessToken(out);
}

// ---------------------------------------------------------------------
// Verbrauch abrufen
// ---------------------------------------------------------------------
static int callUsage(const String& token, String& resp) {
  WiFiClientSecure cli;
  cli.setInsecure();
  HTTPClient http;
  if (!http.begin(cli, USAGE_URL)) return -1;
  http.addHeader("Authorization", "Bearer " + token);
  http.addHeader("anthropic-beta", "oauth-2025-04-20");
  http.addHeader("User-Agent", "claude-cli/1.0");
  int code = http.GET();
  resp = http.getString();
  http.end();
  return code;
}

static void fetchUsage() {
  String token, resp;
  int t = getAccessToken(token, false);
  if (t == -1) { needToken = true; statusMsg = TR("Anmeldung abgelaufen","Login expired"); return; }
  if (t == 0)  { statusMsg = TR("Netzwerkfehler","Network error"); return; }

  int code = callUsage(token, resp);
  if (code == 401) {
    t = getAccessToken(token, true);
    if (t == -1) { needToken = true; statusMsg = TR("Anmeldung abgelaufen","Login expired"); return; }
    if (t == 0)  { statusMsg = TR("Netzwerkfehler","Network error"); return; }
    code = callUsage(token, resp);
  }
  if (code != 200) { statusMsg = TR("Fehler HTTP ","HTTP error ") + String(code); return; }

  JsonDocument doc;
  if (deserializeJson(doc, resp)) { statusMsg = TR("Antwort unlesbar","Bad response"); return; }

  JsonVariant fh = doc["five_hour"];
  JsonVariant sd = doc["seven_day"];
  usage.hasSession = !fh.isNull() && !fh["utilization"].isNull();
  usage.session = usage.hasSession ? fh["utilization"].as<float>() : 0;
  usage.sessionReset = fh.isNull() ? 0 : parseIsoUtc(fh["resets_at"] | (const char*)nullptr);
  usage.week = sd.isNull() ? 0 : (sd["utilization"] | 0.0f);
  usage.weekReset = sd.isNull() ? 0 : parseIsoUtc(sd["resets_at"] | (const char*)nullptr);
  usage.fetchedAt = time(nullptr);
  usage.valid = true;
  statusMsg = "";
}

// ---------------------------------------------------------------------
// Zeichnen
// ---------------------------------------------------------------------
static uint16_t levelColor(float p) {
  if (p >= CRIT_PERCENT) return C_CRIT;
  if (p >= WARN_PERCENT) return C_WARN;
  return C_OK;
}

static void drawStar(int cx, int cy, int r, uint16_t col) {
  for (int i = 0; i < 8; i++) {
    float a = i * PI / 4;
    int x = cx + cosf(a) * r, y = cy + sinf(a) * r;
    canvas.drawLine(cx, cy, x, y, col);
    canvas.drawLine(cx + 1, cy, x + 1, y, col);
    canvas.drawLine(cx, cy + 1, x, y + 1, col);
  }
}

// Balken im Stil eines Batteriesymbols mit Segmenten
static void drawBar(int x, int y, int w, int h, float p) {
  canvas.drawRoundRect(x, y, w, h, 4, C_FRAME);
  canvas.fillRoundRect(x + w, y + h / 4, 5, h / 2, 2, C_FRAME);  // "Nase"
  const int segs = 12, gap = 3;
  int inner = w - 8;
  int sw = (inner - gap * (segs - 1)) / segs;
  int lit = (int)roundf(constrain(p, 0, 100) / 100.0f * segs);
  if (p > 0 && lit == 0) lit = 1;
  uint16_t col = levelColor(p);
  for (int i = 0; i < segs; i++) {
    int sx = x + 4 + i * (sw + gap);
    canvas.fillRect(sx, y + 4, sw, h - 8, i < lit ? col : 0x18E3);
  }
}

static void drawMessage(const char* title, const char* l1, const char* l2, const char* l3) {
  canvas.fillScreen(C_BG);
  drawStar(30, 30, 11, C_CLAUDE);
  canvas.setTextColor(C_TEXT);
  canvas.setFont(&fonts::FreeSansBold12pt7b);
  canvas.drawString("Claude", 48, 18);
  canvas.setFont(&fonts::FreeSansBold9pt7b);
  canvas.setTextColor(C_CLAUDE);
  canvas.drawString(title, 18, 80);
  canvas.setFont(&fonts::FreeSans9pt7b);
  canvas.setTextColor(C_TEXT);
  canvas.drawString(l1, 18, 112);
  canvas.drawString(l2, 18, 136);
  canvas.setTextColor(C_SUB);
  canvas.drawString(l3, 18, 168);
  canvas.pushSprite(0, 0);
}

static void drawMain() {
  const int W = canvas.width();
  const int R = W - 18;               // rechter Rand
  canvas.fillScreen(C_BG);

  // Kopfzeile
  drawStar(30, 30, 11, C_CLAUDE);
  canvas.setTextColor(C_TEXT);
  canvas.setFont(&fonts::FreeSansBold12pt7b);
  canvas.drawString("Claude", 48, 18);

  if (!usage.valid) {
    canvas.setFont(&fonts::FreeSans9pt7b);
    canvas.setTextColor(C_SUB);
    canvas.drawString(statusMsg.length() ? statusMsg : String(TR("Lade Daten ...","Loading ...")), 18, 110);
    canvas.pushSprite(0, 0);
    return;
  }

  char buf[16];
  // Sitzung
  canvas.setFont(&fonts::FreeSans9pt7b);
  canvas.setTextColor(C_SUB);
  canvas.drawString(TR("Sitzung","Session"), 18, 60);
  snprintf(buf, sizeof buf, "%d%%", (int)roundf(usage.session));
  canvas.setFont(&fonts::FreeSansBold18pt7b);
  canvas.setTextColor(C_TEXT);
  canvas.setTextDatum(textdatum_t::top_right);
  canvas.drawString(buf, R, 50);
  canvas.setTextDatum(textdatum_t::top_left);
  drawBar(18, 84, W - 44, 22, usage.session);

  // Woche
  canvas.setFont(&fonts::FreeSans9pt7b);
  canvas.setTextColor(C_SUB);
  canvas.drawString(TR("Woche","Week"), 18, 122);
  snprintf(buf, sizeof buf, "%d%%", (int)roundf(usage.week));
  canvas.setFont(&fonts::FreeSansBold18pt7b);
  canvas.setTextColor(C_TEXT);
  canvas.setTextDatum(textdatum_t::top_right);
  canvas.drawString(buf, R, 112);
  canvas.setTextDatum(textdatum_t::top_left);
  drawBar(18, 146, W - 44, 22, usage.week);

  // Reset-Zeiten
  canvas.setFont(&fonts::FreeSansBold12pt7b);
  canvas.setTextColor(C_TEXT);
  if (usage.hasSession && usage.sessionReset)
    canvas.drawString(String(TR("Reset in ","Reset in ")) + countdown(usage.sessionReset), 18, 182);
  else
    canvas.drawString(TR("Keine Sitzung","No session"), 18, 182);
  canvas.setFont(&fonts::FreeSans9pt7b);
  canvas.setTextColor(C_SUB);
  canvas.drawString(String(TR("Woche: Reset in ","Week: reset in ")) + countdown(usage.weekReset), 18, 210);

  if (statusMsg.length()) {
    canvas.setTextColor(C_WARN);
    canvas.setFont(&fonts::Font0);
    canvas.setTextDatum(textdatum_t::top_right);
    canvas.drawString(statusMsg, R, 214);
    canvas.setTextDatum(textdatum_t::top_left);
  }
  canvas.pushSprite(0, 0);
}

// ---------------------------------------------------------------------
// Einrichtung (WLAN + Token) ueber Handy/Laptop
// ---------------------------------------------------------------------
static void showSetupScreen(WiFiManager*) {
  drawMessage(TR("Einrichtung","Setup"), TR("WLAN verbinden:","Join Wi-Fi:"), SETUP_AP_NAME,
              TR("Seite oeffnet sich selbst","Page opens by itself"));
}

static void runSetupPortal(bool force) {
  WiFiManager wm;
  WiFiManagerParameter pToken("token", TR("Claude Refresh-Token (vom PC-Skript, Strg+V)","Claude refresh token (from the PC script, Ctrl+V)"), "", 400);
  wm.addParameter(&pToken);
  wm.setAPCallback(showSetupScreen);
  wm.setTitle("Claude Usage Monitor");
  wm.setConnectTimeout(20);

  bool ok = force ? wm.startConfigPortal(SETUP_AP_NAME) : wm.autoConnect(SETUP_AP_NAME);

  String tok = String(pToken.getValue());
  tok.trim();
  if (tok.length() > 20) {
    prefs.putString("rt", tok);
    prefs.remove("at");
    prefs.remove("exp");
    needToken = false;
    usage.valid = false;
    statusMsg = "";
  }
  if (!ok) ESP.restart();
}

// ---------------------------------------------------------------------
// Ausschalten / Zuruecksetzen
// ---------------------------------------------------------------------
static void factoryReset() {
  drawMessage(TR("Zuruecksetzen","Reset"), TR("WLAN und Anmeldung","Wi-Fi and login"), TR("werden geloescht ...","are being erased ..."), "");
  prefs.clear();
  WiFiManager wm;
  wm.resetSettings();
  delay(1500);
  ESP.restart();
}

// Antippen des Bildschirms ODER BOOT-Taste:
//   kurz = neu laden, 10 s halten = alles zuruecksetzen
static bool pressedNow = false;

static bool isPressed() {
  uint16_t tx, ty;
  return digitalRead(PIN_BOOT_BTN) == LOW || tft.getTouch(&tx, &ty);
}

static void handleButton() {
  static uint32_t downAt = 0;
  static bool wasDown = false;
  bool down = isPressed();
  pressedNow = down;
  uint32_t now = millis();

  if (down && !wasDown) downAt = now;
  if (down) {
    uint32_t held = now - downAt;
    if (held > 10000) factoryReset();
    else if (held > 3000)
      drawMessage(TR("Weiter halten","Keep holding"), TR("10 Sekunden =","10 seconds ="), TR("alles zuruecksetzen","full reset"), TR("Loslassen = abbrechen","Release = cancel"));
  }
  if (!down && wasDown) {
    uint32_t held = now - downAt;
    if (held > 50 && held <= 3000) pollNow = true;   // kurz tippen = neu laden
  }
  wasDown = down;
}

// ---------------------------------------------------------------------
// Setup & Loop
// ---------------------------------------------------------------------
void setup() {
  pinMode(PIN_BOOT_BTN, INPUT_PULLUP);
  pinMode(PIN_LCD_BL, OUTPUT);
  digitalWrite(PIN_LCD_BL, HIGH);
  // Die kleine RGB-LED auf dem Board ausschalten (leuchtet bei LOW)
  const int leds[] = {PIN_LED_R, PIN_LED_G, PIN_LED_B};
  for (int p : leds) { pinMode(p, OUTPUT); digitalWrite(p, HIGH); }

  Serial.begin(115200);
  prefs.begin("usagemonitor", false);

  tft.init();
  tft.setRotation(DISPLAY_ROTATION);
  // Dieser ESP32 hat keinen Zusatzspeicher (PSRAM). 8 Bit = halber Speicherbedarf,
  // laesst genug Platz fuer die verschluesselte Verbindung. (config.h: SPRITE_BITS)
  canvas.setColorDepth(SPRITE_BITS);
  if (!canvas.createSprite(tft.width(), tft.height())) {
    canvas.setColorDepth(8);
    canvas.createSprite(tft.width(), tft.height());
  }
  canvas.setTextDatum(textdatum_t::top_left);

  drawMessage("Start", TR("Verbinde mit WLAN ...","Connecting Wi-Fi ..."), "", "");

  bool noToken = getRefreshToken().isEmpty();
  runSetupPortal(noToken);

  configTime(0, 0, "pool.ntp.org", "time.google.com");
  for (int i = 0; i < 40 && !timeReady(); i++) delay(250);
}

void loop() {
  handleButton();

  if (needToken) {
    drawMessage(TR("Neue Anmeldung","New login"), TR("Bitte Token neu","Please enter a"), TR("eingeben.","new token."), TR("Laptop-Skript starten","Run the PC script"));
    delay(3000);
    runSetupPortal(true);
    pollNow = true;
  }

  uint32_t now = millis();
  if (pollNow || now - lastPollMs > POLL_INTERVAL_S * 1000UL) {
    pollNow = false;
    lastPollMs = now;
    if (WiFi.status() != WL_CONNECTED) {
      statusMsg = TR("WLAN getrennt","Wi-Fi lost");
      WiFi.reconnect();
    } else {
      fetchUsage();
    }
  }

  static uint32_t lastDraw = 0;
  if (now - lastDraw > 1000) {
    lastDraw = now;
    if (!pressedNow) drawMain();
  }
  delay(20);
}

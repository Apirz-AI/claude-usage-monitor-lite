// =====================================================================
//  Einstellungen – Claude Usage Monitor Lite (ESP32-2432S028, "CYD")
//  Die Pins gelten fuer das uebliche Board mit 2.8" ILI9341-Display.
// =====================================================================
#pragma once

// Display (ILI9341, HSPI)
#define PIN_LCD_MISO 12
#define PIN_LCD_MOSI 13
#define PIN_LCD_SCK  14
#define PIN_LCD_CS   15
#define PIN_LCD_DC   2
#define PIN_LCD_RST  -1     // am Reset des ESP32 angeschlossen
#define PIN_LCD_BL   21     // Hintergrundlicht

// Touch (XPT2046, eigener SPI)
#define PIN_TOUCH_SCK  25
#define PIN_TOUCH_MOSI 32
#define PIN_TOUCH_MISO 39
#define PIN_TOUCH_CS   33
#define PIN_TOUCH_IRQ  36

#define PIN_BOOT_BTN 0      // BOOT-Taste
#define PIN_LED_R 4         // RGB-LED (leuchtet bei LOW, wird ausgeschaltet)
#define PIN_LED_G 16
#define PIN_LED_B 17

// Sprache: 0 = Deutsch, 1 = English (wird je Ordner/Build gesetzt)
#ifndef LANGUAGE_EN
#define LANGUAGE_EN 0
#endif

#define POLL_INTERVAL_S 120
#define SETUP_AP_NAME "UsageMonitor-Setup"

// Selten: Manche Boards haben statt ILI9341 einen ST7789-Chip (Bild bleibt weiss/Streifen).
// Dann die naechste Zeile aktivieren (Arduino IDE) und DISPLAY_INVERT auf true stellen:
// #define DISPLAY_ST7789

// Farben/Anzeige: Wenn die Farben vertauscht oder wie ein Negativ aussehen,
// hier umstellen (manche Boards haben ein anderes Display-Modell).
#define DISPLAY_INVERT false
#define DISPLAY_RGB_ORDER false

// Drehung: 1 = Querformat, 3 = Querformat um 180 Grad gedreht
#ifndef DISPLAY_ROTATION
#define DISPLAY_ROTATION 1
#endif

// Zwischenspeicher fuer das Bild: 8 (sparsam, empfohlen) oder 16 (schoener, braucht mehr RAM)
#ifndef SPRITE_BITS
#define SPRITE_BITS 8
#endif

#define WARN_PERCENT 75
#define CRIT_PERCENT 90

// =====================================================================
//  Claude Usage Monitor Lite – Gehaeuse im Look eines 90er-Jahre-Roehrenmonitors
//  Fuer: ESP32-2432S028 ("CYD"), 2.8 Zoll, quer eingebaut, OHNE Akku
//  Eine Farbe (Cremeweiss / Beige / Hellgrau), keine Stuetzen noetig.
//
//  ZWEI VARIANTEN (unten bei "usb" waehlen):
//   "links"  – USB-Buchse des Boards sitzt im Querformat LINKS
//              (Firmware-Datei "usb-links" verwenden)
//   "rechts" – USB-Buchse sitzt RECHTS (Firmware-Datei "usb-rechts")
//   Das Kabel geht seitlich durch eine Oeffnung im Gehaeuse.
//   Welche Seite bei deinem Board stimmt, siehst du beim ersten Einschalten:
//   steht das Bild auf dem Kopf, nimm die andere Datei/Variante.
//
//  Bedienung (OpenSCAD, kostenlos):
//    1. Datei oeffnen, "usb" und "teil" einstellen
//    2. F6 druecken (rendern), dann Datei -> Exportieren -> STL
//
//  Druck: PLA, 0.2 mm Schicht, 15 % Fuellung, keine Stuetzen
//    - Gehaeuse: Bildschirmseite nach unten aufs Druckbett
//    - Deckel:   flach, Lippe nach oben
//    - Fuss:     flach, breite Seite unten
//
//  Alle Masse in Millimeter. ACHTUNG: Die Masse sind aus Datenblaettern und
//  noch NICHT am echten Board geprueft. Board mit Schieblehre nachmessen und
//  die Werte im Abschnitt "MASSE DER BAUTEILE" anpassen.
// =====================================================================

usb   = "links";   // [links, rechts]
teil  = "alles";   // [gehaeuse, deckel, fuss, alles]

// ---------------- MASSE DER BAUTEILE (nachmessen!) --------------------
board_l   = 86.0;    // Platine lang
board_h   = 50.0;    // Platine hoch (im Querformat)
pcb_t     = 1.6;     // Platinendicke
modul_l   = 70.0;    // Display-Modul (Glas + Licht) lang
modul_h   = 50.0;    // Display-Modul hoch
modul_t   = 4.2;     // Display-Modul ragt so weit ueber die Platine
glas_b    = 58.0;    // sichtbares Bild: Breite (2.8" Bild ca. 57 x 43)
glas_h    = 44.0;    // sichtbares Bild: Hoehe
glas_ende = 36.0;    // Bildmitte, Abstand vom Ende OHNE USB (nachmessen)
rueck_t   = 9.0;     // Platz hinter der Platine (Buchsen, SD-Slot, Lautsprecherstecker)

// USB-Buchse (an der kurzen Platinenkante)
usb_mitte  = 25.0;   // Mitte der Buchse ab Platinen-Oberkante
usb_oeff_b = 14.0;   // Oeffnung in der Seitenwand: Hoehe (Richtung Bildschirm-oben)
usb_oeff_t = 11.0;   // Oeffnung: Tiefe (Richtung Gehaeuse-hinten)

// ---------------- GEHAEUSE -------------------------------------------
wand      = 2.4;
front     = 2.6;     // Vorderwand
spiel     = 0.4;
rand_o    = 5.0;     // Rahmen oben/unten/seitlich um die Platine
ecke_r    = 3.5;
ruecken_r = 3.0;
front_d   = 9.0;     // Tiefe des geraden Rahmens vorne
tiefe_extra = 7.0;   // zusaetzliche Tiefe fuer den Roehren-Look
deckel_t  = 2.4;
lippe_t   = 3.0;
toleranz  = 0.25;

$fn = 48;

// ---------------- Abgeleitete Masse ----------------------------------
links = (usb == "links");
inn_b = board_l + 2*spiel;
inn_h = board_h + 2*spiel;
bett_t = pcb_t + rueck_t;                       // Platine + Platz dahinter
inn_t = bett_t + lippe_t + 0.5 + tiefe_extra;   // Innenraum ab Modul-Tasche

kinn  = 11.0;                                   // unterer Rahmen (Roehren-Kinn)
aus_b = inn_b + 2*(rand_o + wand);
aus_h = kinn + inn_h + wand + rand_o;
aus_t = front + modul_t + inn_t;

inn_x = rand_o + wand;
inn_z = kinn;
rue_x = rand_o;  rue_b = aus_b - 2*rand_o;
rue_z = 0;       rue_h = aus_h - rand_o;

// Platine im Querformat: USB-Ende links oder rechts
board_x = inn_x + spiel;
board_z = inn_z + spiel;
// Display-Modul sitzt am Ende gegenueber der USB-Buchse
modul_x = links ? board_x + board_l - modul_l : board_x;
modul_z = board_z + (board_h - modul_h)/2;
// Bildmitte
bild_cx = links ? board_x + board_l - glas_ende : board_x + glas_ende;
g_x = bild_cx - glas_b/2;
g_z = board_z + board_h/2 - glas_h/2;

// Fuss-Aufnahme
zap_b = 14; zap_t = 8; zap_h = 4.5;
zap_cy = aus_t*0.5;
zap_x = aus_b/2 - zap_b/2;  zap_y = zap_cy - zap_t/2;

// ---------------- Hilfsformen ----------------------------------------
module rrect2d(b, h, r) { offset(r=r) offset(delta=-r) square([b, h]); }
module slab(x, z, b, h, r, y0, t) {
  translate([0, y0 + t, 0]) rotate([90,0,0]) linear_extrude(t)
    translate([x, z]) rrect2d(b, h, r);
}

// ---------------- Gehaeuse -------------------------------------------
module koerper() {
  slab(0, 0, aus_b, aus_h, ecke_r, 0, front_d);
  hull() {
    slab(0, 0, aus_b, aus_h, ecke_r, front_d - 0.01, 0.01);
    slab(rue_x, rue_z, rue_b, rue_h, ruecken_r, aus_t - 0.01, 0.01);
  }
}

module gehaeuse() {
  kz = (g_z - 1.0 - 3.0) / 2 + 1.0;            // Mitte des Kinns
  difference() {
    koerper();

    // Innenraum (hinten offen), beginnt hinter der Modul-Tasche
    translate([inn_x, front + modul_t, inn_z]) cube([inn_b, inn_t + 1, inn_h]);

    // Tasche fuer das Display-Modul (liegt am Rahmen an)
    translate([modul_x - spiel, front - 0.001, modul_z - spiel])
      cube([modul_l + 2*spiel, modul_t + 0.01, modul_h + 2*spiel]);

    // Bildfenster mit schraeger Einfassung
    slab(g_x, g_z, glas_b, glas_h, 3, -1, front + 2);
    hull() {
      slab(g_x - 2.5, g_z - 2.5, glas_b + 5, glas_h + 5, 5.5, -0.5, 0.5);
      slab(g_x, g_z, glas_b, glas_h, 3, 1.0, 0.01);
    }

    // USB-Oeffnung in der Seitenwand (Kabel faehrt seitlich raus)
    ux = links ? -1 : aus_b - inn_x - 1;
    uz = board_z + board_h - usb_mitte - usb_oeff_b/2;
    translate([ux, front + modul_t + pcb_t + 0.5, uz])
      cube([inn_x + 2, usb_oeff_t, usb_oeff_b]);

    // Kinn: Regler-Mulden rechts, Power-LED links
    for (i = [0:3])
      translate([aus_b - 9 - i*4.6, -0.1, kz]) rotate([-90,0,0]) cylinder(d=2.8, h=0.7);
    translate([8, -0.1, kz]) rotate([-90,0,0]) cylinder(d=1.8, h=0.7);

    // Lueftungsschlitze oben und seitlich am Ruecken
    for (i = [0:4])
      translate([rue_x + 8, aus_t - 5 - i*2.6, inn_z + inn_h - 0.5]) cube([rue_b - 16, 1.2, 20]);
    for (i = [0:3])
      translate([links ? aus_b - rand_o - wand - 1 : -1, aus_t - 5 - i*2.6, inn_z + 8])
        cube([rand_o + wand + 2, 1.2, inn_h - 16]);

    // Aufnahme fuer den Fuss
    translate([zap_x, zap_y, -1]) cube([zap_b, zap_t, zap_h + 1]);
  }
  // Kinn: Netzschalter-Optik (erhaben)
  translate([12, 0, kz - 1.6]) rotate([90,0,0])
    linear_extrude(0.8) rrect2d(6, 3.2, 1.2);
}

// ---------------- Standfuss (oval, Dreh-Fuss-Optik) ------------------
fuss_b = aus_b*0.62;
fuss_t = aus_t*0.85;
module fuss() {
  hull() {
    translate([fuss_b/2, fuss_t/2, 0]) scale([fuss_b/2, fuss_t/2, 1]) cylinder(r=1, h=0.01, $fn=96);
    translate([fuss_b/2, fuss_t/2, 3]) scale([fuss_b/2 - 1.5, fuss_t/2 - 1.5, 1]) cylinder(r=1, h=0.01, $fn=96);
  }
  hull() {
    translate([fuss_b/2, fuss_t/2, 2.99]) scale([12, 6, 1]) cylinder(r=1, h=0.01, $fn=64);
    translate([fuss_b/2, fuss_t/2, 6.0])  scale([10, 5, 1]) cylinder(r=1, h=0.01, $fn=64);
  }
  translate([fuss_b/2 - (zap_b - 2*toleranz)/2, fuss_t/2 - (zap_t - 2*toleranz)/2, 5.99])
    cube([zap_b - 2*toleranz, zap_t - 2*toleranz, zap_h - 0.4]);
}

// ---------------- Rueckdeckel ----------------------------------------
module deckel() {
  lx = inn_x - rue_x;  lz = inn_z - rue_z;
  difference() {
    union() {
      linear_extrude(deckel_t) rrect2d(rue_b, rue_h, ruecken_r);
      translate([lx + toleranz, lz + toleranz, deckel_t])
        difference() {
          cube([inn_b - 2*toleranz, inn_h - 2*toleranz, lippe_t]);
          translate([1.6, 1.6, -1]) cube([inn_b - 2*toleranz - 3.2, inn_h - 2*toleranz - 3.2, lippe_t + 2]);
        }
      // Druckleisten: halten die Platine sanft nach vorne
      for (dz = [0.25, 0.75])
        translate([lx + 4, lz + inn_h*dz - 1, deckel_t])
          cube([inn_b - 8, 2, lippe_t + tiefe_extra - 1.0]);
    }
  }
}

// ---------------- Ausgabe --------------------------------------------
fuss_hoehe = 6;
if (teil == "gehaeuse") {
  gehaeuse();
} else if (teil == "deckel") {
  deckel();
} else if (teil == "fuss") {
  fuss();
} else {
  translate([0, 0, fuss_hoehe]) gehaeuse();
  translate([aus_b/2 - fuss_b/2, zap_cy - fuss_t/2, 0]) fuss();
  translate([rue_x, aus_t + 10, rue_z + fuss_hoehe]) rotate([90,0,0]) translate([0,0,-deckel_t]) deckel();
}

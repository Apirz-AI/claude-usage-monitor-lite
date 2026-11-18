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
farbe = "#EDE6D6";  // Knochenweiss / Cremeweiss = Farbe des Filaments. So zeigt die Vorschau (F5)
                    // das Gehaeuse, wie es gedruckt aussieht. Andere Filamentfarbe? Hier anpassen.


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
rand_s    = 5.0;     // Rahmen seitlich
rand_o    = 14.0;    // Rahmen oben  } Front ca. 4:3 wie ein Roehrenmonitor
boden     = 18.0;    // Kinn unten   } (Knoepfe, LED, Schalter-Optik)
ecke_r    = 3.5;
ruecken_r = 3.0;
front_d   = 9.0;     // Tiefe des geraden Rahmens vorne
tiefe_extra = 29.0;  // zusaetzliche Tiefe: der typische Roehren-"Buckel" hinten
deckel_t  = 2.4;
lippe_t   = 3.0;
toleranz  = 0.25;

$fn = 48;

// ---------------- Abgeleitete Masse ----------------------------------
// Das Bild sitzt MITTIG in der Front (wie beim Akku-Modell). Weil das Board
// auf der USB-Seite laenger ist als das Display, wird das Gehaeuse
// symmetrisch gebaut; auf der anderen Seite bleibt massive Wand.
links = (usb == "links");
bl_usb = board_l - glas_ende;                   // Bildmitte bis USB-Ende
halb   = max(glas_ende, bl_usb) + spiel;        // halbe Innenbreite (symmetrisch)
aus_b  = 2*(halb + rand_s + wand);
cx     = aus_b/2;                               // Bildmitte (waagerecht)

inn_b = board_l + 2*spiel;
bett_t = pcb_t + rueck_t;                       // Platine + Platz dahinter
inn_t = bett_t + lippe_t + 0.5 + tiefe_extra;   // Innenraum ab Modul-Tasche
inn_h = board_h + 2*spiel;
// Board: USB-Ende liegt an der Seitenwand mit der Kabeloeffnung
board_x = links ? cx - bl_usb : cx - glas_ende;
inn_x   = board_x - spiel;

aus_h = boden + inn_h + wand + rand_o;
aus_t = front + modul_t + inn_t;
inn_z = boden;
rue_x = rand_s;  rue_b = aus_b - 2*rand_s;
rue_z = 0;       rue_h = inn_z + inn_h + wand + 1;   // Ruecken oben deutlich niedriger (Roehren-Haube)

board_z = inn_z + spiel;
// Display-Modul sitzt am Ende gegenueber der USB-Buchse
modul_x = links ? board_x + board_l - modul_l : board_x;
modul_z = board_z + (board_h - modul_h)/2;
// Bild
g_x = cx - glas_b/2;
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

// Innenraum ausserhalb des Board-Schachts: hohl, damit nicht unnoetig
// viel Filament verbraucht wird (Wandstaerke "wand" ueberall gleich)
module koerper_innen() {
  slab(wand, wand, aus_b - 2*wand, aus_h - 2*wand, max(ecke_r - wand, 0.5), front, front_d - front + 0.01);
  hull() {
    slab(wand, wand, aus_b - 2*wand, aus_h - 2*wand, max(ecke_r - wand, 0.5), front_d, 0.01);
    slab(rue_x + wand, rue_z + wand, rue_b - 2*wand, rue_h - 2*wand, max(ruecken_r - wand, 0.5), aus_t, 1);
  }
}
module hohlraum() {
  difference() {
    koerper_innen();
    // Schacht fuer das Board (Waende bleiben stehen, Deckel-Lippe greift hinein)
    translate([inn_x - wand, -1, inn_z - wand]) cube([inn_b + 2*wand, aus_t + 3, inn_h + 2*wand]);
    // Block um die Fuss-Aufnahme
    translate([zap_x - wand, zap_y - wand, -1]) cube([zap_b + 2*wand, zap_t + 2*wand, zap_h + wand + 1]);
  }
}

module gehaeuse() {
  kz = (g_z - 4) / 2;                            // Mitte des Kinns
  difference() {
    koerper();

    hohlraum();

    // Innenraum (hinten offen), beginnt hinter der Modul-Tasche
    translate([inn_x, front + modul_t, inn_z]) cube([inn_b, inn_t + 1, inn_h]);

    // Tasche fuer das Display-Modul (liegt am Rahmen an)
    translate([modul_x - spiel, front - 0.001, modul_z - spiel])
      cube([modul_l + 2*spiel, modul_t + 0.01, modul_h + 2*spiel]);

    // Bildfenster mit schraeger Einfassung
    slab(g_x, g_z, glas_b, glas_h, 3, -1, front + 2);
    hull() {
      slab(g_x - 4, g_z - 4, glas_b + 8, glas_h + 8, 7, -0.5, 0.5);
      slab(g_x, g_z, glas_b, glas_h, 3, 1.0, 0.01);
    }

    // USB-Oeffnung in der Seitenwand (Kabel faehrt seitlich raus)
    ux = links ? -1 : inn_x + inn_b - 1;
    uz = board_z + board_h - usb_mitte - usb_oeff_b/2;
    translate([ux, front + modul_t + pcb_t + 0.5, uz])
      cube([links ? inn_x + 2 : aus_b - (inn_x + inn_b) + 2, usb_oeff_t, usb_oeff_b]);

    // Kinn: Regler-Mulden rechts, Power-LED links
    for (i = [0:3])
      translate([aus_b - 14 - i*7.5, -0.1, kz]) rotate([-90,0,0]) cylinder(d=4.6, h=1.0);
    translate([12, -0.1, kz]) rotate([-90,0,0]) cylinder(d=2.8, h=1.0);

    // Lueftungsschlitze oben und seitlich am Ruecken
    for (i = [0:4])
      translate([rue_x + 8, aus_t - 5 - i*2.6, inn_z + inn_h - 0.5]) cube([rue_b - 16, 1.2, 20]);
    for (i = [0:4])
      translate([-1, aus_t - 5 - i*2.6, inn_z + 6]) cube([aus_b + 2, 1.2, inn_h - 12]);

    // Aufnahme fuer den Fuss
    translate([zap_x, zap_y, -1]) cube([zap_b, zap_t, zap_h + 1]);
  }
  // Kinn: Netzschalter-Optik (erhaben)
  translate([19, 0, kz - 2.5]) rotate([90,0,0])
    linear_extrude(1.0) rrect2d(10, 5, 1.8);
}

// ---------------- Standfuss (oval, Dreh-Fuss-Optik) ------------------
fuss_b = aus_b*0.7;
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
      // Druckstege: halten die Platine sanft nach vorne
      // Laenge so, dass sie genau am Ende von "rueck_t" hinter der Platine enden
      // 6 kurze Stege statt durchgehender Leisten: spart Filament
      for (dz = [0.25, 0.75]) for (fx = [0.12, 0.5, 0.88])
        translate([lx + inn_b*fx - 6, lz + inn_h*dz - 1.2, deckel_t])
          cube([12, 2.4, aus_t - (front + modul_t + pcb_t + rueck_t)]);
    }
  }
}

// ---------------- Ausgabe --------------------------------------------
fuss_hoehe = 6;
color(farbe) {
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
}

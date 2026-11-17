# =====================================================================
#  Claude Usage Monitor - Einrichtung (Windows)
#  Holt einen eigenen Claude-Zugang und gibt ihn an EIN Geraet weiter:
#    [1] iPhone-Widget (per QR-Code)
#    [2] Claude Usage Monitor-Geraet (per Zwischenablage)
#
#  Start (PowerShell):
#    powershell -ExecutionPolicy Bypass -File .\UsageMonitor-Einrichtung.ps1
#
#  Wichtig: Jedes Geraet braucht seinen EIGENEN Zugang. Das Skript
#  meldet Claude Code danach am Laptop ab (Datei wird umbenannt),
#  damit sich Laptop und Geraet nicht gegenseitig aussperren.
# =====================================================================

$ErrorActionPreference = "Stop"
$credDir  = Join-Path $env:USERPROFILE ".claude"
$cred     = Join-Path $credDir ".credentials.json"

# Sprache nach Windows-Einstellung / language follows Windows
$script:DE = (Get-Culture).TwoLetterISOLanguageName -eq "de"
function T($de, $en) { if ($script:DE) { $de } else { $en } }
function Pause-Enter($text) { Read-Host $text | Out-Null }

function Find-Claude {
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $cands = @(
        (Join-Path $env:USERPROFILE ".local\bin\claude.exe")
    )
    $cands += Get-ChildItem (Join-Path $env:LOCALAPPDATA "Claude-Data") -Filter claude.exe -Recurse -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | ForEach-Object { $_.FullName }
    foreach ($p in $cands) { if ($p -and (Test-Path $p)) { return $p } }
    return $null
}

function Get-Login {
    if (-not (Test-Path $cred)) { return $null }
    try {
        $o = (Get-Content $cred -Raw | ConvertFrom-Json).claudeAiOauth
        if ($o -and $o.refreshToken) { return $o }
    } catch {}
    return $null
}

function Start-Login {
    $exe = Find-Claude
    if (-not $exe) {
        Write-Host ""
        Write-Host (T "Claude Code ist nicht installiert." "Claude Code is not installed.") -ForegroundColor Yellow
        Write-Host (T "Bitte in PowerShell eingeben:  irm https://claude.ai/install.ps1 | iex" "Please run in PowerShell:  irm https://claude.ai/install.ps1 | iex")
        Write-Host (T "Danach dieses Skript erneut starten." "Then start this script again.")
        Pause-Enter (T "Enter zum Beenden" "Press Enter to exit")
        exit
    }
    $dir = Join-Path $env:USERPROFILE "usagemonitor-login"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host ""
    Write-Host (T "Gleich startet Claude Code. Dort:" "Claude Code starts now. There:") -ForegroundColor Cyan
    Write-Host (T "  1. Fragen mit Enter bestaetigen" "  1. Confirm questions with Enter")
    Write-Host (T "  2. Ordnerfrage: 'Yes, I trust this folder' (der Ordner ist leer)" "  2. Folder question: 'Yes, I trust this folder' (the folder is empty)")
    Write-Host (T "  3. Eintippen: /login  -> 'Claude account with subscription' -> im Browser erlauben" "  3. Type: /login  -> 'Claude account with subscription' -> allow in the browser")
    Write-Host (T "  4. Wenn 'Login successful' erscheint: /exit eintippen" "  4. When 'Login successful' appears: type /exit")
    Pause-Enter (T "Enter zum Starten" "Press Enter to start")
    Push-Location $dir
    & $exe
    Pop-Location
}

function Retire-Login {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Rename-Item $cred (".credentials.vergeben-" + $stamp + ".json") -Force
}

# ---------------------------------------------------------------------
Write-Host ""
Write-Host (T "=== Claude Usage Monitor - Einrichtung ===" "=== Claude Usage Monitor - Setup ===") -ForegroundColor Cyan

$o = Get-Login
if (-not $o) {
    Write-Host (T "Es gibt noch keinen freien Claude-Zugang auf diesem Laptop." "There is no free Claude login on this PC yet.")
    Start-Login
    $o = Get-Login
    if (-not $o) {
        Write-Host (T "Anmeldung nicht gefunden. Bitte Skript erneut starten." "Login not found. Please start the script again.") -ForegroundColor Yellow
        Pause-Enter (T "Enter zum Beenden" "Press Enter to exit")
        exit
    }
}

# Test: funktioniert der Zugang?
try {
    $h = @{ "Authorization" = "Bearer " + $o.accessToken; "anthropic-beta" = "oauth-2025-04-20"; "User-Agent" = "claude-cli/1.0" }
    $u = Invoke-RestMethod -Uri "https://api.anthropic.com/api/oauth/usage" -Headers $h
    Write-Host ((T "Test OK  ->  Sitzung: {0} %   Woche: {1} %" "Test OK  ->  Session: {0} %   Week: {1} %") -f [math]::Round($u.five_hour.utilization), [math]::Round($u.seven_day.utilization)) -ForegroundColor Green
} catch {
    Write-Host (T "Test uebersprungen (kurzer Zugang abgelaufen - das Geraet erneuert ihn selbst)." "Test skipped (short-lived access expired - the device renews it itself).") -ForegroundColor DarkGray
}

Write-Host ""
Write-Host (T "Fuer welches Geraet?" "Which device?")
Write-Host (T "  [1] iPhone-Widget (QR-Code scannen)" "  [1] iPhone widget (scan QR code)")
Write-Host (T "  [2] Claude Usage Monitor-Geraet (Token einfuegen)" "  [2] Claude Usage Monitor device (paste token)")
$wahl = Read-Host (T "Zahl eingeben" "Enter number")

if ($wahl -eq "1") {
    $link = "scriptable:///run/ClaudeUsage?rt=" + [uri]::EscapeDataString($o.refreshToken)
    $html = @'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Claude Usage Monitor Setup</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<style>
:root{--bg:#fff;--fg:#000;--sub:#6e6e73;--card:#f5f5f7}
:root[data-theme="dark"]{--bg:#000;--fg:#fff;--sub:#98989d;--card:#1c1c1e}
body{margin:0;background:var(--bg);color:var(--fg);font-family:-apple-system,"Segoe UI",sans-serif;display:flex;justify-content:center}
main{max-width:520px;padding:32px 16px;text-align:center}
#qr{display:inline-block;background:#fff;padding:16px;border-radius:16px;margin:16px 0}
p{color:var(--sub);line-height:1.5}
button{position:fixed;top:12px;right:12px;border:0;border-radius:20px;padding:8px 14px;background:var(--card);color:var(--fg);cursor:pointer}
</style></head><body>
<button onclick="var r=document.documentElement;r.dataset.theme=r.dataset.theme==='dark'?'light':'dark'">&#9680;</button>
<main><h1>Claude Usage Monitor</h1><p>__P1__</p>
<div id="qr"></div>
<p>__P2__</p></main>
<script>new QRCode(document.getElementById("qr"),{text:"__LINK__",width:280,height:280,correctLevel:QRCode.CorrectLevel.M});</script>
</body></html>
'@
    $html = $html.Replace("__LINK__", $link)
    $html = $html.Replace("__P1__", (T "Mit der iPhone-Kamera scannen &rarr; &bdquo;In Scriptable &ouml;ffnen&ldquo;" "Scan with the iPhone camera &rarr; &ldquo;Open in Scriptable&rdquo;"))
    $html = $html.Replace("__P2__", (T "<b>Niemandem zeigen</b> &ndash; das ist der Schl&uuml;ssel zu deinem Claude-Konto." "<b>Show nobody</b> &ndash; this is the key to your Claude account."))
    $file = Join-Path $env:TEMP "usagemonitor-setup.html"
    [IO.File]::WriteAllText($file, $html, [Text.Encoding]::UTF8)
    Start-Process $file
    Write-Host ""
    Write-Host (T "QR-Code ist im Browser offen. Mit dem iPhone scannen." "The QR code is open in your browser. Scan it with your iPhone.")
    Pause-Enter (T "Wenn 'Verbunden' auf dem iPhone steht: Enter druecken" "When the iPhone shows 'Connected': press Enter")
    Remove-Item $file -Force -ErrorAction SilentlyContinue
}
elseif ($wahl -eq "2") {
    Set-Clipboard -Value $o.refreshToken
    Write-Host ""
    Write-Host (T "Der Token ist jetzt in der Zwischenablage." "The token is now in your clipboard.") -ForegroundColor Green
    Write-Host (T "  1. Claude Usage Monitor einschalten - auf dem Bildschirm steht 'Einrichtung'" "  1. Turn on the Claude Usage Monitor - the screen shows 'Setup'")
    Write-Host (T "  2. Am Laptop/Handy mit dem WLAN 'UsageMonitor-Setup' verbinden" "  2. On your laptop/phone, join the Wi-Fi 'UsageMonitor-Setup'")
    Write-Host (T "  3. Die Einrichtungsseite oeffnet sich (sonst Browser: 192.168.4.1)" "  3. The setup page opens (otherwise browser: 192.168.4.1)")
    Write-Host (T "  4. 'Configure WiFi' -> dein WLAN waehlen -> Passwort eingeben" "  4. 'Configure WiFi' -> pick your Wi-Fi -> enter password")
    Write-Host (T "  5. Im Feld 'Claude Refresh-Token' mit Strg+V einfuegen -> Save" "  5. Paste into the 'Claude refresh token' field with Ctrl+V -> Save")
    Pause-Enter (T "Wenn das Geraet Werte anzeigt: Enter druecken" "When the device shows values: press Enter")
    Set-Clipboard -Value " "
}
else {
    Write-Host (T "Abgebrochen." "Cancelled.") ; exit
}

Retire-Login
Write-Host ""
Write-Host (T "Fertig. Der Zugang gehoert jetzt dem Geraet." "Done. The login now belongs to the device.") -ForegroundColor Green
Write-Host (T "Fuer ein weiteres Geraet einfach dieses Skript erneut starten." "For another device, just run this script again.")
Start-Sleep -Seconds 3

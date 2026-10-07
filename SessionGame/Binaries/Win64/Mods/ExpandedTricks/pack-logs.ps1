# Expanded Tricks -- pack the logs for a bug report. Run pack-logs.bat (it starts this script).
# Puts ExpandedTricks-logs-<date>.zip on your desktop: the mod's logs and settings, UE4SS's log, SessionTweaks' log
# and settings if you have that mod, and a short note of what is installed. The zip is kept under 8 MB so it goes
# through Discord (the logs' newest parts are what is kept).
# Nothing is sent anywhere: you attach the zip yourself. (GPLv3, see LICENSE.)
param([string]$OutDir = "", [int]$MaxMB = 8, [switch]$NoPause)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path          # ...\Win64\Mods\ExpandedTricks
$win64 = Split-Path -Parent (Split-Path -Parent $here)

function Done([int]$code) {
    if (-not $NoPause) { Write-Host ""; Read-Host "Press Enter to close" | Out-Null }
    exit $code
}
# anything not foreseen: say it and keep the window open (a double-clicked window closes by itself otherwise)
trap {
    Write-Host ("  Stopped on an error: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "  Send ExpandedTricks.log and ExpandedTricks.native.log from the game's SessionGame\Binaries\Win64 folder by hand instead." -ForegroundColor Red
    Done 1
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

# the last $max bytes of a file, from the start of a line (the file may be open in the game: shared read)
function Copy-Tail([string]$from, [string]$to, [long]$max) {
    $fs = [System.IO.File]::Open($from, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
    try {
        $len = $fs.Length
        $start = [Math]::Max([long]0, $len - $max)
        $fs.Position = $start
        $buf = New-Object byte[] ($len - $start)
        $got = 0
        while ($got -lt $buf.Length) { $r = $fs.Read($buf, $got, $buf.Length - $got); if ($r -le 0) { break }; $got += $r }
        $skip = 0
        if ($start -gt 0) { while ($skip -lt $got -and $buf[$skip] -ne 10) { $skip++ }; if ($skip -lt $got) { $skip++ } else { $skip = 0 } }
        $out = [System.IO.File]::Create($to)
        try {
            if ($start -gt 0) { $note = [System.Text.Encoding]::ASCII.GetBytes("(the last " + [Math]::Round(($got - $skip) / 1MB, 1) + " MB of " + [Math]::Round($len / 1MB, 1) + " MB)`r`n"); $out.Write($note, 0, $note.Length) }
            $out.Write($buf, $skip, $got - $skip)
        } finally { $out.Dispose() }
    } finally { $fs.Dispose() }
}

Write-Host ""
Write-Host "Expanded Tricks -- packing the logs"
Write-Host "-----------------------------------"
if (-not (Test-Path -LiteralPath (Join-Path $win64 'SessionGame-Win64-Shipping.exe'))) {
    Write-Host "  This script belongs in the game's Mods\ExpandedTricks folder (it looks for the logs two folders up)." -ForegroundColor Red
    Done 1
}
# where the zip goes: the folder asked for, else the desktop; with no desktop folder (a redirected one that is off
# line) Documents, then the temp folder -- not the game's folder, which may not be writable
if (-not $OutDir -or -not (Test-Path -LiteralPath $OutDir -PathType Container)) {
    $OutDir = $null
    foreach ($c in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'), [System.IO.Path]::GetTempPath())) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Container)) { $OutDir = $c; break }
    }
    if (-not $OutDir) { $OutDir = $win64 }
}
$OutDir = (Get-Item -LiteralPath $OutDir).FullName
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$zip = Join-Path $OutDir ("ExpandedTricks-logs-" + $stamp + ".zip")
$limit = [long]$MaxMB * 1MB

# name, the most of it that is taken on each try (bytes), smaller each time the zip comes out too big
$wanted = @(
    @{ n = 'ExpandedTricks.log';            caps = @(4MB, 2MB, 1MB, 400KB) },
    @{ n = 'ExpandedTricks.log.old';        caps = @(2MB, 500KB, 0, 0) },
    @{ n = 'ExpandedTricks.native.log';     caps = @(24MB, 10MB, 4MB, 1MB) },
    @{ n = 'ExpandedTricks.native.log.old'; caps = @(4MB, 0, 0, 0) },
    @{ n = 'ExpandedTricks.tweaks.log';     caps = @(1MB, 500KB, 200KB, 100KB) },
    @{ n = 'ExpandedTricks.ini';            caps = @(2MB, 2MB, 2MB, 2MB) },
    @{ n = 'UE4SS.log';                     caps = @(1MB, 500KB, 200KB, 100KB) },
    @{ n = 'SessionTweaks.log';             caps = @(2MB, 500KB, 0, 0) },
    @{ n = 'SessionTweaks.ini';             caps = @(200KB, 200KB, 0, 0) }
)

$ok = $false
for ($try = 0; $try -lt 4 -and -not $ok; $try++) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ExpandedTricks-logs-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $count = 0
        $about = New-Object System.Collections.Generic.List[string]
        foreach ($w in $wanted) {
            $cap = [long]$w.caps[$try]
            $p = Join-Path $win64 $w.n
            if ($cap -le 0 -or -not (Test-Path -LiteralPath $p)) { continue }
            try { Copy-Tail $p (Join-Path $tmp $w.n) $cap; $count++ } catch { $about.Add("could not read " + $w.n + ": " + $_.Exception.Message) }
        }
        # what is installed
        $about.Add("Expanded Tricks log pack, " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        $about.Add("Windows: " + [Environment]::OSVersion.VersionString)
        $about.Add("Game folder: " + $win64)
        foreach ($f in @('SessionGame-Win64-Shipping.exe', 'UE4SS.dll', 'dwmapi.dll', 'Mods\ExpandedTricks\Scripts\main.lua', 'Mods\ExpandedTricksNative\dlls\main.dll', 'ExpandedTricks.poses.bin')) {
            $p = Join-Path $win64 $f
            if (Test-Path -LiteralPath $p) { $i = Get-Item -LiteralPath $p; $about.Add(("{0}: {1} bytes, {2}" -f $f, $i.Length, $i.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))) } else { $about.Add($f + ": not there") }
        }
        $modsDir = Join-Path $win64 'Mods'
        if (Test-Path -LiteralPath $modsDir) {
            $about.Add("Mods folder: " + ((Get-ChildItem -LiteralPath $modsDir -Directory | ForEach-Object { $_.Name }) -join ', '))
            $mt = Join-Path $modsDir 'mods.txt'
            if (Test-Path -LiteralPath $mt) { $about.Add("mods.txt:"); foreach ($l in (Get-Content -LiteralPath $mt)) { $about.Add("  " + $l) } }
        }
        [System.IO.File]::WriteAllLines((Join-Path $tmp 'about.txt'), $about, (New-Object System.Text.UTF8Encoding($true)))
        if ($count -eq 0) {
            Write-Host "  No logs could be read beside the game's exe. Start the game with the mod once, then run this again." -ForegroundColor Yellow
            Write-Host "  If there is still no UE4SS.log after that, the mod loader did not start: check that UE4SS.dll and dwmapi.dll are" -ForegroundColor Yellow
            Write-Host "  beside the game's exe, and install the Microsoft Visual C++ 2015-2022 Redistributable (x64)." -ForegroundColor Yellow
            Done 1
        }
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
        # (not Compress-Archive: it takes [ ] in a folder's name for a wildcard and then packs nothing or fails)
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        $size = (Get-Item -LiteralPath $zip).Length
        if ($size -le $limit -or $try -eq 3) { $ok = $true }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
$size = (Get-Item -LiteralPath $zip).Length
Write-Host ("  Made: {0} ({1:N1} MB)" -f $zip, ($size / 1MB))
if ($size -gt $limit) { Write-Host ("  It is over {0} MB all the same; if it will not upload, send ExpandedTricks.log on its own." -f $MaxMB) -ForegroundColor Yellow }
Write-Host "  Attach that file to your message. Say what you did and roughly when (the logs have the time of day on every line)."
if (-not $NoPause) { try { Start-Process explorer.exe -ArgumentList ('/select,"' + $zip + '"') } catch { } }
Done 0

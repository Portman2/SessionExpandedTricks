# Expanded Tricks -- pack the logs for a bug report. Run pack-logs.bat (it starts this script).
# Puts ExpandedTricks-logs-<date>.zip on your desktop: the mod's logs and settings, UE4SS's log, SessionTweaks' log
# and settings if you have that mod, the GAME's own settings files (its options, so that what you see can be played
# again with your settings), and a short note of what is installed. The zip is kept under 8 MB so it goes through
# Discord: it holds the NEWEST part of every log. The skeleton of your newest tricks goes in too
# (ExpandedTricks.poses.bin: the mod records it unless RecordPoses=0 in ExpandedTricks.ini).
# What did not fit is not thrown away: the next older part of the logs goes into a second zip, and the part before
# that into a third (...-older-2.zip, ...-older-3.zip; three files at most). Send the first one; keep the others in
# case you are asked for more.
# The logs are running logs: they go on from one play session to the next (the game starts a new one, and keeps the
# one before it as .old, once a log is over a megabyte), so "the newest part" is your last sessions, the last one last.
# Nothing is sent anywhere: you attach the zip yourself. (GPLv3, see LICENSE.)
param([string]$OutDir = "", [int]$MaxMB = 8, [int]$MaxParts = 3, [switch]$NoPause)

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

function Open-Shared([string]$p) {                                # (the file may be open in the game)
    return [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
}
# A log's bytes before $end (-1 = its end), $max of them at most, from the start of a line.
# -> where the copy starts in the file (= what is still to pack ends there); $end itself when nothing was copied
function Copy-Slice([string]$from, [string]$to, [long]$end, [long]$max) {
    $fs = Open-Shared $from
    try {
        $len = $fs.Length
        if ($end -lt 0 -or $end -gt $len) { $end = $len }
        if ($end -le 0) { return [long]0 }
        $start = [Math]::Max([long]0, $end - $max)
        $fs.Position = $start
        $buf = New-Object byte[] ($end - $start)
        $got = 0
        while ($got -lt $buf.Length) { $r = $fs.Read($buf, $got, $buf.Length - $got); if ($r -le 0) { break }; $got += $r }
        $skip = 0
        if ($start -gt 0) { while ($skip -lt $got -and $buf[$skip] -ne 10) { $skip++ }; if ($skip -lt $got) { $skip++ } else { $skip = 0 } }
        if ($got - $skip -le 0) { return [long]$end }
        $out = [System.IO.File]::Create($to)
        try {
            if ($start -gt 0 -or $end -lt $len) {
                $note = [System.Text.Encoding]::ASCII.GetBytes(("(bytes {0:N0} to {1:N0} of this file's {2:N0}: {3} MB)`r`n" -f ($start + $skip), ($start + $got), $len, [Math]::Round(($got - $skip) / 1MB, 1)))
                $out.Write($note, 0, $note.Length)
            }
            $out.Write($buf, $skip, $got - $skip)
        } finally { $out.Dispose() }
        return [long]($start + $skip)
    } finally { $fs.Dispose() }
}
# The pose recorder's file (ExpandedTricks.poses.bin, and the .old one it was set aside as when it got full): the
# NEWEST whole recordings before $end (-1 = its end) that fit in $max bytes. It is a chain of recordings, each
# starting with 'ETPD' and saying its own length at byte 8, so a cut is made at the start of one (a cut anywhere else
# could not be read back). -> Start (where the copy starts), End, Count (recordings copied), Total (recordings before $end)
function Copy-PoseSlice([string]$from, [string]$to, [long]$end, [long]$max) {
    $fs = Open-Shared $from
    try {
        $len = $fs.Length
        $h = New-Object byte[] 12
        $starts = New-Object 'System.Collections.Generic.List[long]'
        $off = [long]0
        while ($off + 160 -le $len) {
            if ($end -ge 0 -and $off -ge $end) { break }
            $fs.Position = $off
            if ($fs.Read($h, 0, 12) -lt 12) { break }
            if ($h[0] -ne 0x45 -or $h[1] -ne 0x54 -or $h[2] -ne 0x50 -or $h[3] -ne 0x44) { break }
            $seg = [long][BitConverter]::ToUInt32($h, 8)
            if ($seg -lt 160 -or $off + $seg -gt $len) { break }      # (the last one may still be being written)
            $starts.Add($off)
            $off += $seg
        }
        $stop = $off
        $first = -1
        for ($i = 0; $i -lt $starts.Count; $i++) { if ($stop - $starts[$i] -le $max) { $first = $i; break } }
        if ($first -lt 0) { return @{ Start = $stop; End = $stop; Count = 0; Total = $starts.Count } }
        $fs.Position = $starts[$first]
        $left = $stop - $starts[$first]
        $buf = New-Object byte[] (1MB)
        $out = [System.IO.File]::Create($to)
        try {
            while ($left -gt 0) {
                $r = $fs.Read($buf, 0, [int][Math]::Min([long]$buf.Length, $left))
                if ($r -le 0) { break }
                $out.Write($buf, 0, $r)
                $left -= $r
            }
        } finally { $out.Dispose() }
        return @{ Start = $starts[$first]; End = $stop; Count = ($starts.Count - $first); Total = $starts.Count }
    } finally { $fs.Dispose() }
}
# a small file as it is (2 MB at most). -> $true when it was copied
function Copy-Small([string]$from, [string]$to) {
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { return $false }
    $fs = Open-Shared $from
    try {
        if ($fs.Length -gt 2MB) { return $false }
        $buf = New-Object byte[] ($fs.Length)
        $got = 0
        while ($got -lt $buf.Length) { $r = $fs.Read($buf, $got, $buf.Length - $got); if ($r -le 0) { break }; $got += $r }
        [System.IO.File]::WriteAllBytes($to, $buf)
        return $true
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
$limit = [long]$MaxMB * 1MB
if ($MaxParts -lt 1) { $MaxParts = 1 }

# name; caps = the most of it that goes into the FIRST zip on each try (bytes), smaller each time the zip comes out too
# big; more = the same for the zips with the older parts (0 = that file has no older part worth a zip)
$wanted = @(
    @{ n = 'ExpandedTricks.log';            caps = @(4MB, 2MB, 1MB, 400KB);       more = @(40MB, 20MB, 8MB, 3MB) },
    @{ n = 'ExpandedTricks.log.old';        caps = @(2MB, 500KB, 0, 0);           more = @(40MB, 20MB, 8MB, 3MB) },
    @{ n = 'ExpandedTricks.native.log';     caps = @(24MB, 10MB, 4MB, 1MB);       more = @(40MB, 20MB, 8MB, 3MB) },
    @{ n = 'ExpandedTricks.native.log.old'; caps = @(4MB, 0, 0, 0);               more = @(40MB, 20MB, 8MB, 3MB) },
    @{ n = 'ExpandedTricks.tweaks.log';     caps = @(1MB, 500KB, 200KB, 100KB);   more = @(0, 0, 0, 0) },
    @{ n = 'ExpandedTricks.ini';            caps = @(2MB, 2MB, 2MB, 2MB);         more = @(0, 0, 0, 0) },
    @{ n = 'UE4SS.log';                     caps = @(1MB, 500KB, 200KB, 100KB);   more = @(0, 0, 0, 0) },
    @{ n = 'SessionTweaks.log';             caps = @(2MB, 500KB, 0, 0);           more = @(20MB, 10MB, 4MB, 1MB) },
    @{ n = 'SessionTweaks.ini';             caps = @(200KB, 200KB, 0, 0);         more = @(0, 0, 0, 0) },
    @{ n = 'ExpandedTricks.poses.bin';      caps = @(8MB, 6MB, 3MB, 1MB);         more = @(11MB, 8MB, 5MB, 2MB); pose = $true },   # (it packs to about 60 % of its size)
    @{ n = 'ExpandedTricks.poses.bin.old';  caps = @(8MB, 6MB, 3MB, 1MB);         more = @(11MB, 8MB, 5MB, 2MB); pose = $true; rest = $true }   # (the one before it: only into the room the newer one left)
)
# the game's own settings: its options save (controls, gameplay and advanced settings), the experimental and the
# camera ones, and its window / quality ini. Small files, copied as they are: put into another install's
# %LOCALAPPDATA%\SessionGame\Saved folders they make the game play with these settings.
$gameSaved = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SessionGame\Saved'
$gameSettings = @('SaveGames\OptionsSaveSlot.sav', 'SaveGames\ExperimentalSaveSlot.sav', 'SaveGames\FilmerModeSaveSlot.sav', 'SaveGames\ReplayEditorSaveSlot.sav',
                  'SaveGames\TDV_ControlVibration_Settings.sav', 'Config\WindowsNoEditor\GameUserSettings.ini', 'Config\WindowsNoEditor\Input.ini', 'Config\WindowsNoEditor\Engine.ini')

$ends = @{}                                      # per file: where what is still to pack ends (-1 = at the file's end)
foreach ($w in $wanted) { $ends[$w.n] = [long]-1 }
$zips = New-Object System.Collections.Generic.List[string]
for ($part = 1; $part -le $MaxParts; $part++) {
    $zip = Join-Path $OutDir ("ExpandedTricks-logs-" + $stamp + $(if ($part -gt 1) { "-older-" + $part } else { "" }) + ".zip")
    $ok = $false
    $nothing = $false
    for ($try = 0; $try -lt 4 -and -not $ok; $try++) {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ExpandedTricks-logs-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $count = 0
            $taken = @{}                                       # what this try took: file -> where its copy starts
            $poseLeft = [long]-1                               # (room left for the older pose file: not known until the newer one is in)
            $about = New-Object System.Collections.Generic.List[string]
            foreach ($w in $wanted) {
                $cap = [long]$(if ($part -eq 1) { $w.caps[$try] } else { $w.more[$try] })
                $p = Join-Path $win64 $w.n
                $end = [long]$ends[$w.n]
                if ($cap -le 0 -or $end -eq 0 -or -not (Test-Path -LiteralPath $p)) { continue }
                if ($w.pose) {                                 # (not counted as a log: a pack of poses alone says nothing)
                    $take = $cap
                    if ($w.rest -and $poseLeft -ge 0) { $take = [Math]::Min($cap, $poseLeft) }
                    if ($take -ge 1MB) {
                        try {
                            $r = Copy-PoseSlice $p (Join-Path $tmp $w.n) $end $take
                            if ($r.Count -gt 0) {
                                $taken[$w.n] = [long]$r.Start
                                $about.Add(("{0}: {1} of its {2} recordings not packed before are in this zip (the newest of them)" -f $w.n, $r.Count, $r.Total))
                            }
                            if (-not $w.rest) { $poseLeft = $cap - ($r.End - $r.Start) }
                        } catch { $about.Add("could not read " + $w.n + ": " + $_.Exception.Message) }
                    }
                    continue
                }
                try {
                    $s = Copy-Slice $p (Join-Path $tmp $w.n) $end $cap
                    if (Test-Path -LiteralPath (Join-Path $tmp $w.n)) { $taken[$w.n] = [long]$s; $count++ }
                } catch { $about.Add("could not read " + $w.n + ": " + $_.Exception.Message) }
            }
            if ($part -eq 1) {
                # the game's own settings
                $gs = Join-Path $tmp 'game-settings'
                New-Item -ItemType Directory -Path $gs | Out-Null
                $got = New-Object System.Collections.Generic.List[string]
                foreach ($f in $gameSettings) {
                    try { if (Copy-Small (Join-Path $gameSaved $f) (Join-Path $gs (Split-Path -Leaf $f))) { $got.Add((Split-Path -Leaf $f)) } } catch { $about.Add("could not read the game's " + $f + ": " + $_.Exception.Message) }
                }
                if ($got.Count -eq 0) { Remove-Item -LiteralPath $gs -Recurse -Force -ErrorAction SilentlyContinue; $about.Add("the game's settings files were not found under " + $gameSaved) }
                else { $about.Add("game-settings: " + ($got -join ', ') + " (from " + $gameSaved + ")") }
                # what is installed
                $about.Add("Expanded Tricks log pack, " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
                $about.Add("Windows: " + [Environment]::OSVersion.VersionString)
                $about.Add("Game folder: " + $win64)
                foreach ($f in @('SessionGame-Win64-Shipping.exe', 'UE4SS.dll', 'dwmapi.dll', 'Mods\ExpandedTricks\Scripts\main.lua', 'Mods\ExpandedTricksNative\dlls\main.dll', 'ExpandedTricks.poses.bin', 'ExpandedTricks.poses.bin.old')) {
                    $p = Join-Path $win64 $f
                    if (Test-Path -LiteralPath $p) { $i = Get-Item -LiteralPath $p; $about.Add(("{0}: {1} bytes, {2}" -f $f, $i.Length, $i.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))) } else { $about.Add($f + ": not there") }
                }
                $modsDir = Join-Path $win64 'Mods'
                if (Test-Path -LiteralPath $modsDir) {
                    $about.Add("Mods folder: " + ((Get-ChildItem -LiteralPath $modsDir -Directory | ForEach-Object { $_.Name }) -join ', '))
                    $mt = Join-Path $modsDir 'mods.txt'
                    if (Test-Path -LiteralPath $mt) { $about.Add("mods.txt:"); foreach ($l in (Get-Content -LiteralPath $mt)) { $about.Add("  " + $l) } }
                }
                if ($count -eq 0) {
                    Write-Host "  No logs could be read beside the game's exe. Start the game with the mod once, then run this again." -ForegroundColor Yellow
                    Write-Host "  If there is still no UE4SS.log after that, the mod loader did not start: check that UE4SS.dll and dwmapi.dll are" -ForegroundColor Yellow
                    Write-Host "  beside the game's exe, and install the Microsoft Visual C++ 2015-2022 Redistributable (x64)." -ForegroundColor Yellow
                    Done 1
                }
            } else {
                if ($taken.Count -eq 0) { $nothing = $true; $ok = $true; continue }      # no older part is left: no further zip
                $about.Insert(0, ("Expanded Tricks log pack {0}, zip {1}: the OLDER part of the logs, what the zip(s) before this one had no room for. Each log says in its first line which bytes of the file it holds." -f $stamp, $part))
            }
            [System.IO.File]::WriteAllLines((Join-Path $tmp 'about.txt'), $about, (New-Object System.Text.UTF8Encoding($true)))
            if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
            # (not Compress-Archive: it takes [ ] in a folder's name for a wildcard and then packs nothing or fails)
            [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
            $size = (Get-Item -LiteralPath $zip).Length
            if ($size -le $limit -or $try -eq 3) {
                $ok = $true
                foreach ($k in @($taken.Keys)) { $ends[$k] = [long]$taken[$k] }
                $zips.Add($zip)
            }
        } finally {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    if ($nothing) { break }
}
$first = $zips[0]
$size = (Get-Item -LiteralPath $first).Length
Write-Host ("  Made: {0} ({1:N1} MB)" -f $first, ($size / 1MB))
if ($size -gt $limit) { Write-Host ("  It is over {0} MB all the same; if it will not upload, send ExpandedTricks.log on its own." -f $MaxMB) -ForegroundColor Yellow }
Write-Host "  Attach that file to your message. Say what you did and roughly when (the logs have the time of day on every line)."
if ($zips.Count -gt 1) {
    Write-Host ""
    Write-Host "  The logs were longer than one file holds. Their OLDER part is in:"
    for ($i = 1; $i -lt $zips.Count; $i++) { Write-Host ("    {0} ({1:N1} MB)" -f $zips[$i], ((Get-Item -LiteralPath $zips[$i]).Length / 1MB)) }
    Write-Host "  Keep those; send them only if you are asked for more."
}
if (-not $NoPause) { try { Start-Process explorer.exe -ArgumentList ('/select,"' + $first + '"') } catch { } }
Done 0

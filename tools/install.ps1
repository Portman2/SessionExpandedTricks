# Expanded Tricks -- installer. Run install.bat (it starts this script), or:
#   powershell -ExecutionPolicy Bypass -File tools\install.ps1 [-GameDir "D:\Games\Session"]
# What it does: finds the game, puts UE4SS in if the game has no mod loader yet, copies the mod's two folders
# into SessionGame\Binaries\Win64\Mods, and (unless -NoBoard) the Hippie Exterminator board's files into SessionGame\Content
# as loose files over the game's pak. The pak itself is not touched. (GPLv3, see LICENSE.)
param([string]$GameDir = "", [switch]$NoPause, [switch]$NoBoard)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$pkg = Split-Path -Parent $here

function Done([int]$code) {
    if (-not $NoPause) { Write-Host ""; Read-Host "Press Enter to close" | Out-Null }
    exit $code
}
# anything not foreseen: say it and keep the window open (a double-clicked window closes by itself otherwise)
trap {
    Write-Host ("  Stopped on an error: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "  Nothing more was done. Please report this line." -ForegroundColor Red
    Done 1
}
. (Join-Path $here 'common.ps1')

Write-Host ""
Write-Host "Expanded Tricks for Session: Skate Sim -- install"
Write-Host "------------------------------------------------"

$src = Join-Path $pkg 'SessionGame\Binaries\Win64\Mods'
$parts = @('ExpandedTricks\Scripts\main.lua', 'ExpandedTricks\enabled.txt', 'ExpandedTricksNative\dlls\main.dll', 'ExpandedTricksNative\enabled.txt')
foreach ($need in $parts) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $need))) {
        Write-Host "  This package is not complete ($need is missing). Unzip the whole download and run install.bat from there." -ForegroundColor Red
        Done 1
    }
}

$win64 = Select-Win64 $GameDir
if (-not $win64) { Write-Host "  Nothing installed."; Done 1 }
Write-Host "  Game: $win64"

if (Test-GameRunning) {
    Write-Host "  Session is running. Close the game and run install.bat again." -ForegroundColor Yellow
    Done 1
}

try {
    $mods = Join-Path $win64 'Mods'
    # --- the mod loader (UE4SS), only when the game has none
    $hasUe4ss = Test-Path -LiteralPath (Join-Path $win64 'UE4SS.dll')
    $hasProxy = Test-Path -LiteralPath (Join-Path $win64 'dwmapi.dll')
    if ($hasUe4ss) {
        # the native half is built against UE4SS 3.0.1's C++ mod interface and nothing else: say so when another build is there
        $same = $false
        try { $same = ((Get-FileHash -LiteralPath (Join-Path $win64 'UE4SS.dll') -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath (Join-Path $pkg 'ue4ss\UE4SS.dll') -Algorithm SHA256).Hash) } catch { }
        if ($same) {
            Write-Host "  UE4SS 3.0.1 (the mod loader) is already there -- left as it is."
        } else {
            Write-Host "  UE4SS (the mod loader) is already there, but it is not the 3.0.1 release this mod is built for. It is left as it is." -ForegroundColor Yellow
            Write-Host "  If the game closes at start-up or the mod does not load: put UE4SS 3.0.1 in (UE4SS.dll and dwmapi.dll from this package's ue4ss folder)." -ForegroundColor Yellow
        }
        if (-not $hasProxy) { Write-Host "  (There is no dwmapi.dll beside it, though: if the mod does not load, UE4SS itself is not being started.)" -ForegroundColor Yellow }
    } elseif ($hasProxy) {
        Write-Host "  The game folder has a dwmapi.dll but no UE4SS.dll beside it: another loader (or a newer UE4SS in its own ue4ss folder) is installed." -ForegroundColor Yellow
        Write-Host "  It is left alone. Expanded Tricks needs UE4SS 3.0.1: install that (or SessionOpenMP, which brings it) and run this again." -ForegroundColor Yellow
        Done 1
    } else {
        $ue = Join-Path $pkg 'ue4ss'
        foreach ($f in @('UE4SS.dll', 'dwmapi.dll', 'UE4SS-settings.ini')) {
            if (-not (Test-Path -LiteralPath (Join-Path $ue $f))) { throw "The package's ue4ss folder is missing $f." }
        }
        foreach ($f in @('UE4SS.dll', 'dwmapi.dll')) { Copy-Item -LiteralPath (Join-Path $ue $f) -Destination (Join-Path $win64 $f) -Force }
        if (-not (Test-Path -LiteralPath (Join-Path $win64 'UE4SS-settings.ini'))) { Copy-Item -LiteralPath (Join-Path $ue 'UE4SS-settings.ini') -Destination (Join-Path $win64 'UE4SS-settings.ini') }
        if (-not (Test-Path -LiteralPath $mods)) { New-Item -ItemType Directory -Path $mods | Out-Null }
        if (-not (Test-Path -LiteralPath (Join-Path $mods 'mods.txt'))) {
            Set-Content -LiteralPath (Join-Path $mods 'mods.txt') -Encoding ASCII -Value "; UE4SS mod list. Mods with an enabled.txt in their folder (Expanded Tricks has one) load without a line here."
        }
        Set-Content -LiteralPath (Join-Path $mods 'ExpandedTricks.installed-ue4ss.txt') -Encoding ASCII -Value "UE4SS.dll, dwmapi.dll and UE4SS-settings.ini were put here by the Expanded Tricks installer; uninstall.bat offers to take them out again."
        Write-Host "  UE4SS 3.0.1 (the mod loader) installed."
    }
    if (-not (Test-Path -LiteralPath $mods)) { New-Item -ItemType Directory -Path $mods | Out-Null }

    # --- the mod: its two folders, whole. The native half first: its dll is the one file something may hold open, and
    # a failure there must not leave a new main.lua beside an old main.dll. No wildcards: the package may sit in a
    # folder with [ ] in its name.
    foreach ($m in @('ExpandedTricksNative', 'ExpandedTricks')) {
        $dst = Join-Path $mods $m
        if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
        foreach ($item in (Get-ChildItem -LiteralPath (Join-Path $src $m) -Force)) {
            Copy-Item -LiteralPath $item.FullName -Destination $dst -Recurse -Force
        }
    }
    foreach ($need in $parts) {
        $a = Join-Path $src $need; $b = Join-Path $mods $need
        if (-not (Test-Path -LiteralPath $b) -or ((Get-Item -LiteralPath $a).Length -ne (Get-Item -LiteralPath $b).Length)) { throw "$need did not arrive in the game's Mods folder." }
    }
    Write-Host "  Expanded Tricks installed in $mods"

    # --- the Hippie Exterminator board: a deck in ThankYou's "Bad Clouds 8.25" slot and its grip in DGK's "Serape" slot,
    # loose files over the game's pak under SessionGame\Content. Another mod's file already in one of those places is
    # kept beside it as <name>.expandedtricks.bak (uninstall.bat puts it back). Mods\ExpandedTricks\board-files.txt lists
    # what was put in, with each file's hash, so the uninstaller takes out only what is still ours.
    $csrc = Join-Path $pkg 'SessionGame\Content'
    if ($NoBoard) {
        Write-Host "  The Hippie Exterminator board is left out (-NoBoard)."
    } elseif (Test-Path -LiteralPath $csrc) {
        $content = Join-Path (Split-Path -Parent (Split-Path -Parent $win64)) 'Content'
        $list = New-Object System.Collections.Generic.List[string]
        $kept = 0
        foreach ($f in (Get-ChildItem -LiteralPath $csrc -Recurse -File)) {
            $rel = $f.FullName.Substring($csrc.Length + 1)
            $dst = Join-Path $content $rel
            $dir = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
            if (Test-Path -LiteralPath $dst) {
                $bak = $dst + '.expandedtricks.bak'
                if (((Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash -ne $hash) -and -not (Test-Path -LiteralPath $bak)) {
                    Copy-Item -LiteralPath $dst -Destination $bak -Force
                    $kept++
                }
            }
            Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
            $list.Add($rel + "`t" + $hash)
        }
        Set-Content -LiteralPath (Join-Path $mods 'ExpandedTricks\board-files.txt') -Encoding ASCII -Value $list
        Write-Host "  The Hippie Exterminator board installed: the deck under ThankYou (in place of Bad Clouds 8.25) and its grip under DGK (in place of Serape)."
        if ($kept -gt 0) { Write-Host ("  {0} files another mod had in those places are kept beside them as .expandedtricks.bak; uninstall.bat puts them back." -f $kept) -ForegroundColor Yellow }
    }

    # --- things worth knowing
    foreach ($old in @('HippieJump', 'HippieNative')) {
        if (Test-Path -LiteralPath (Join-Path $mods $old)) {
            Write-Host "  An older build of this mod is still there ($old). Delete the folder Mods\${old}: two copies fight each other." -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "Done. Start the game; the first time, quit and start it once more (the game reads its grab switch at start-up)."
    Write-Host "Settings are in the pause menu under 'Expanded Tricks' and in ExpandedTricks.ini beside the game's exe."
    Write-Host "Something wrong? Run Mods\ExpandedTricks\pack-logs.bat and send the zip it puts on your desktop."
    Done 0
} catch [System.UnauthorizedAccessException] {
    Write-Host "  Windows would not let this write into the game's folder." -ForegroundColor Red
    Write-Host "  Right-click install.bat and choose 'Run as administrator'." -ForegroundColor Red
    Done 1
} catch {
    Write-Host ("  Install failed: " + $_.Exception.Message) -ForegroundColor Red
    if ($_.Exception -is [System.IO.IOException]) { Write-Host "  If the game or a file manager has the mod's files open, close it and try again." -ForegroundColor Red }
    Done 1
}

# Expanded Tricks -- uninstaller. Run uninstall.bat (it starts this script).
# Takes the mod's two folders out of the game. Asks before removing your settings and logs, and before removing
# UE4SS if this package's installer was the one that put it in. (GPLv3, see LICENSE.)
param([string]$GameDir = "", [switch]$NoPause)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Done([int]$code) {
    if (-not $NoPause) { Write-Host ""; Read-Host "Press Enter to close" | Out-Null }
    exit $code
}
function Ask([string]$q) {
    $a = ([string](Read-Host ($q + " (y/n)"))).Trim()
    return ($a -match '^(y|yes)$')
}
# anything not foreseen: say it and keep the window open (a double-clicked window closes by itself otherwise)
trap {
    Write-Host ("  Stopped on an error: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "  Nothing more was done. Please report this line." -ForegroundColor Red
    Done 1
}
. (Join-Path $here 'common.ps1')

Write-Host ""
Write-Host "Expanded Tricks for Session: Skate Sim -- uninstall"
Write-Host "--------------------------------------------------"

$win64 = Select-Win64 $GameDir
if (-not $win64) { Write-Host "  Nothing removed."; Done 1 }
Write-Host "  Game: $win64"
if (Test-GameRunning) {
    Write-Host "  Session is running. Close the game and run uninstall.bat again." -ForegroundColor Yellow
    Done 1
}

try {
    $mods = Join-Path $win64 'Mods'
    $n = 0
    foreach ($m in @('ExpandedTricks', 'ExpandedTricksNative')) {
        $p = Join-Path $mods $m
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force; $n++ }
    }
    if ($n -gt 0) { Write-Host "  The mod's folders are removed." } else { Write-Host "  The mod's folders were not there." }

    $own = @(Get-ChildItem -LiteralPath $win64 -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'ExpandedTricks.*' })
    if ($own.Count -gt 0) {
        Write-Host ("  Your settings and logs are still there ({0} files beside the game's exe):" -f $own.Count)
        foreach ($f in ($own | Select-Object -First 12)) { Write-Host ("    " + $f.Name) }
        if ($own.Count -gt 12) { Write-Host ("    ... and {0} more named ExpandedTricks.*" -f ($own.Count - 12)) }
        if (Ask "  Remove them too?") {
            foreach ($f in $own) { Remove-Item -LiteralPath $f.FullName -Force }
            Write-Host "  Removed."
        } else { Write-Host "  Kept." }
    }

    $marker = Join-Path $mods 'ExpandedTricks.installed-ue4ss.txt'
    if (Test-Path -LiteralPath $marker) {
        $others = @(Get-ChildItem -LiteralPath $mods -Directory -ErrorAction SilentlyContinue)
        if ($others.Count -gt 0) {
            Write-Host ("  UE4SS (the mod loader) was installed by this mod, but other mods use it now ({0}) -- it stays." -f (($others | ForEach-Object { $_.Name }) -join ', '))
        } elseif (Ask "  UE4SS (the mod loader) was installed by this mod and nothing else uses it. Remove it too?") {
            foreach ($f in @('UE4SS.dll', 'dwmapi.dll', 'UE4SS-settings.ini', 'UE4SS.log')) {
                $p = Join-Path $win64 $f
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
            }
            Remove-Item -LiteralPath $marker -Force
            # the installer's own mods.txt (one comment line), and the Mods folder if that leaves it empty
            $mt = Join-Path $mods 'mods.txt'
            if (Test-Path -LiteralPath $mt) {
                $lines = @(Get-Content -LiteralPath $mt | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith(';') })
                if ($lines.Count -eq 0) { Remove-Item -LiteralPath $mt -Force }
            }
            if (@(Get-ChildItem -LiteralPath $mods -Force).Count -eq 0) { Remove-Item -LiteralPath $mods -Force }
            Write-Host "  UE4SS removed."
        } else { Write-Host "  UE4SS kept." }
    }
    Write-Host ""
    Write-Host "Done. The grab switch the mod set in the game's own save is harmless and stays"
    Write-Host "(the save as it was before is beside it: %LOCALAPPDATA%\SessionGame\Saved\SaveGames\ExperimentalSaveSlot.sav.expandedtricks.bak)."
    Done 0
} catch [System.UnauthorizedAccessException] {
    Write-Host "  Windows would not let this change the game's folder. Right-click uninstall.bat and choose 'Run as administrator'." -ForegroundColor Red
    Done 1
} catch {
    Write-Host ("  Uninstall failed: " + $_.Exception.Message) -ForegroundColor Red
    Done 1
}

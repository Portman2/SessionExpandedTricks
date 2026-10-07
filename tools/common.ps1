# Expanded Tricks -- shared by install.ps1 and uninstall.ps1: finding the game's Win64 folder.
# (GPLv3, see LICENSE.)

# Two path parts put together as plain text. (Join-Path stops the script on a drive that is not there -- a Steam
# library on an unplugged disk, a mistyped letter -- and on characters Windows does not allow in a path.)
function Join-Plain([string]$a, [string]$b) {
    try { return [System.IO.Path]::Combine($a, $b) } catch { return $null }
}

function Test-Win64([string]$p) {
    if (-not $p) { return $false }
    $exe = Join-Plain $p 'SessionGame-Win64-Shipping.exe'
    if (-not $exe) { return $false }
    try { return [bool](Test-Path -LiteralPath $exe -PathType Leaf -ErrorAction Stop) } catch { return $false }
}

# A path the player typed or dragged in: the Win64 folder itself, the game's root, anything in between, or the exe.
function Resolve-Win64([string]$p) {
    if (-not $p) { return $null }
    $p = $p.Trim().Trim('"', "'").Trim()
    if (-not $p) { return $null }
    try {
        if ($p -like '*.exe') { $p = [System.IO.Path]::GetDirectoryName($p) }
        foreach ($c in @($p, (Join-Plain $p 'SessionGame\Binaries\Win64'), (Join-Plain $p 'Binaries\Win64'), (Join-Plain $p 'Win64'))) {
            if (Test-Win64 $c) { return (Get-Item -LiteralPath $c).FullName.TrimEnd('\') }
        }
    } catch { }
    return $null
}

# Every installed copy of Session this machine's launchers know about (Epic's manifests, Steam's libraries).
function Find-Session {
    $found = New-Object System.Collections.Generic.List[string]
    # Epic Games Launcher: one .item file (JSON, UTF-8) per installed game
    $man = Join-Plain $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if ($man -and (Test-Path -LiteralPath $man)) {
        foreach ($f in (Get-ChildItem -LiteralPath $man -Filter *.item -ErrorAction SilentlyContinue)) {
            try {
                $j = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($j.InstallLocation) { $found.Add((Join-Plain ([string]$j.InstallLocation) 'SessionGame\Binaries\Win64')) }
            } catch { }
        }
    }
    # Steam: its own folder from the registry (HKLM first: it has the folder's name as it is on disk, HKCU's is lower
    # case), then every library in libraryfolders.vdf (UTF-8)
    $steam = New-Object System.Collections.Generic.List[string]
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam', 'HKCU:\Software\Valve\Steam')) {
        try {
            $v = Get-ItemProperty -Path $k -ErrorAction Stop
            foreach ($n in @('InstallPath', 'SteamPath')) { if ($v.$n) { $steam.Add(([string]$v.$n).Replace('/', '\').TrimEnd('\')) } }
        } catch { }
    }
    foreach ($s in $steam) {
        $libs = New-Object System.Collections.Generic.List[string]
        $libs.Add($s)
        try {
            $vdf = Join-Plain $s 'steamapps\libraryfolders.vdf'
            if ($vdf -and (Test-Path -LiteralPath $vdf)) {
                foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw -Encoding UTF8), '"path"\s+"([^"]+)"')) { $libs.Add($m.Groups[1].Value.Replace('\\', '\').TrimEnd('\')) }
            }
        } catch { }
        foreach ($l in $libs) {
            foreach ($name in @('Session', 'Session Skate Sim', 'SessionSkateSim')) {
                $found.Add((Join-Plain $l ("steamapps\common\" + $name + "\SessionGame\Binaries\Win64")))
            }
        }
    }
    # one line per folder, whatever case it was spelled in
    $out = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $found) {
        if (Test-Win64 $p) {
            $r = $null
            try { $r = (Get-Item -LiteralPath $p).FullName.TrimEnd('\') } catch { }
            if ($r -and $seen.Add($r)) { $out.Add($r) }
        }
    }
    return $out.ToArray()
}

# The folder to work on: the one given, the only one found, the one the player picks, or the one they type.
function Select-Win64([string]$given) {
    if ($given) {
        $r = Resolve-Win64 $given
        if ($r) { return $r }
        # a folder was named and it is wrong: stop, do not go and work on some other copy of the game
        Write-Host "  That folder does not hold SessionGame-Win64-Shipping.exe: $given" -ForegroundColor Yellow
        Write-Host "  Give the game's folder (the one that holds SessionGame), or leave -GameDir out to have the game looked for." -ForegroundColor Yellow
        return $null
    }
    $all = @(Find-Session)
    if ($all.Count -eq 1) { return $all[0] }
    if ($all.Count -gt 1) {
        Write-Host "  More than one copy of Session was found:"
        for ($i = 0; $i -lt $all.Count; $i++) { Write-Host ("    {0}. {1}" -f ($i + 1), $all[$i]) }
        while ($true) {
            $a = ([string](Read-Host "  Which one? (number, or leave it empty to give up)")).Trim()
            if (-not $a) { return $null }
            $n = 0
            if ([int]::TryParse($a, [ref]$n) -and $n -ge 1 -and $n -le $all.Count) { return $all[$n - 1] }
        }
    }
    Write-Host "  Session was not found by itself."
    Write-Host "  Paste the game's folder here (the one that holds SessionGame, or its Binaries\Win64) and press Enter."
    Write-Host "  Leave it empty to give up."
    while ($true) {
        $a = Read-Host "  Folder"
        if (-not $a -or -not ([string]$a).Trim()) { return $null }
        $r = Resolve-Win64 $a
        if ($r) { return $r }
        Write-Host "  SessionGame-Win64-Shipping.exe is not in there. Try again." -ForegroundColor Yellow
    }
}

function Test-GameRunning {
    return [bool](Get-Process -Name 'SessionGame-Win64-Shipping' -ErrorAction SilentlyContinue)
}

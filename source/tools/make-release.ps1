# Expanded Tricks -- put a release together.
#   powershell -ExecutionPolicy Bypass -File source\tools\make-release.ps1 [-Root <the package folder>] [-Out <folder>] [-KeyFile <file>]
#   powershell -ExecutionPolicy Bypass -File source\tools\make-release.ps1 -NewKey [-KeyFile <file>]
# Reads the version and the build number out of main.lua, checks the package is whole, and writes into <Out>:
#   ExpandedTricks-<version>.zip             the download
#   update.txt, update.txt.sig, main.lua, main.dll   the four loose files the in-game updater reads
# Attach all five to ONE GitHub release, under exactly these names (the updater fetches
# releases/latest/download/<name>).
#
# A release only reaches players' games when its build number is higher than theirs: raise NATIVE.BUILD (and the
# "loaded (v...)" line) in main.lua for every release.
#
# THE SIGNING KEY. update.txt is signed (ECDSA P-256) with a private key that lives only on the author's machine
# (default %USERPROFILE%\.expandedtricks\release-key.ecc). Its public half is compiled into main.dll (kUpdKey in
# hn_main.cpp), and the game installs nothing whose update.txt that key did not sign. Keep the key file safe and
# backed up, and never put it in the repository: whoever has it can push code to every player, and without it you
# cannot publish an update players' games will accept. -NewKey makes one and prints the lines for hn_main.cpp.
# (GPLv3, see LICENSE.)
param([string]$Root = "", [string]$Out = "", [string]$KeyFile = "", [switch]$NewKey)

$ErrorActionPreference = 'Stop'
if (-not $KeyFile) { $KeyFile = Join-Path (Join-Path $env:USERPROFILE '.expandedtricks') 'release-key.ecc' }
$KeyFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KeyFile)

function Get-PublicBlob([byte[]]$priv) {
    $k = [System.Security.Cryptography.CngKey]::Import($priv, [System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
    try { return ,$k.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob) } finally { $k.Dispose() }
}
function Format-Blob([byte[]]$b) {
    $lines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $b.Length; $i += 12) {
        $n = [Math]::Min(12, $b.Length - $i)
        $lines.Add("    " + ((($b[$i..($i + $n - 1)]) | ForEach-Object { '0x{0:x2}' -f $_ }) -join ', ') + ',')
    }
    return ($lines -join "`r`n")
}

if ($NewKey) {
    if (Test-Path -LiteralPath $KeyFile) { Write-Host "There is a key already: $KeyFile -- not replaced. (Games in players' hands only accept the key they were built with.)" -ForegroundColor Red; exit 1 }
    $dir = Split-Path -Parent $KeyFile
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $cp = New-Object System.Security.Cryptography.CngKeyCreationParameters
    $cp.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowPlaintextExport
    $k = [System.Security.Cryptography.CngKey]::Create([System.Security.Cryptography.CngAlgorithm]::ECDsaP256, $null, $cp)
    try {
        $priv = $k.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
        $pub = $k.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    } finally { $k.Dispose() }
    [System.IO.File]::WriteAllBytes($KeyFile, $priv)
    Write-Host "New signing key: $KeyFile"
    Write-Host "Back it up somewhere safe. Never commit it. Its public half, for kUpdKey in hn_main.cpp:"
    Write-Host (Format-Blob $pub)
    exit 0
}

if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) }
$Root = (Resolve-Path -LiteralPath $Root).Path
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $Root) 'dist' }
# a relative -Out, made whole against PowerShell's own location: the .NET calls below go by the process's current directory
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
if ($Out.TrimEnd('\').StartsWith($Root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) { Write-Host "-Out must not be inside the package folder (it would be packed into the zip)." -ForegroundColor Red; exit 1 }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
# every file under $dir into $zip, names relative to $dir with / between the parts (Compress-Archive on Windows
# PowerShell 5.1 writes \ in the names, and it takes [ ] in a path for a wildcard)
function New-Zip([string]$dir, [string]$zip) {
    $dir = $dir.TrimEnd('\')
    $fs = [System.IO.File]::Create($zip)
    try {
        $za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File -Force)) {
                $name = $f.FullName.Substring($dir.Length + 1).Replace('\', '/')
                [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $f.FullName, $name, [System.IO.Compression.CompressionLevel]::Optimal)
            }
        } finally { $za.Dispose() }
    } finally { $fs.Dispose() }
}
function Find-Bytes([byte[]]$hay, [byte[]]$needle) {
    for ($i = 0; $i -le $hay.Length - $needle.Length; $i++) {
        if ($hay[$i] -eq $needle[0]) { $j = 1; while ($j -lt $needle.Length -and $hay[$i + $j] -eq $needle[$j]) { $j++ }; if ($j -eq $needle.Length) { return $true } }
    }
    return $false
}

$luaPath = Join-Path $Root 'SessionGame\Binaries\Win64\Mods\ExpandedTricks\Scripts\main.lua'
$dllPath = Join-Path $Root 'SessionGame\Binaries\Win64\Mods\ExpandedTricksNative\dlls\main.dll'
$cppPath = Join-Path $Root 'source\ExpandedTricksNative\hn_main.cpp'
$problems = New-Object System.Collections.Generic.List[string]
foreach ($f in @($luaPath, $dllPath, $cppPath,
        (Join-Path $Root 'install.bat'), (Join-Path $Root 'uninstall.bat'), (Join-Path $Root 'tools\install.ps1'), (Join-Path $Root 'tools\uninstall.ps1'), (Join-Path $Root 'tools\common.ps1'),
        (Join-Path $Root 'ue4ss\UE4SS.dll'), (Join-Path $Root 'ue4ss\dwmapi.dll'), (Join-Path $Root 'ue4ss\UE4SS-settings.ini'),
        (Join-Path $Root 'SessionGame\Binaries\Win64\Mods\ExpandedTricks\enabled.txt'), (Join-Path $Root 'SessionGame\Binaries\Win64\Mods\ExpandedTricksNative\enabled.txt'),
        (Join-Path $Root 'SessionGame\Binaries\Win64\Mods\ExpandedTricks\pack-logs.bat'), (Join-Path $Root 'SessionGame\Binaries\Win64\Mods\ExpandedTricks\pack-logs.ps1'),
        (Join-Path $Root 'README.md'), (Join-Path $Root 'LICENSE'), (Join-Path $Root 'THIRD_PARTY.md'), (Join-Path $Root 'CHANGELOG.md'))) {
    if (-not (Test-Path -LiteralPath $f)) { $problems.Add("missing: " + $f) }
}
if (-not (Test-Path -LiteralPath $KeyFile)) { $problems.Add("no signing key at $KeyFile (the author's own; -KeyFile names another place, -NewKey makes one -- only before the first release)") }
if ($problems.Count -gt 0) { $problems | ForEach-Object { Write-Host $_ -ForegroundColor Red }; exit 1 }

$lua = [System.IO.File]::ReadAllText($luaPath)
$cpp = [System.IO.File]::ReadAllText($cppPath)
$version = if ($lua -match 'local MOD_VERSION = "([0-9A-Za-z.\-]+)"') { $Matches[1] } else { $null }
$build = if ($lua -match '(?m)^NATIVE\.BUILD = (\d+)') { [int]$Matches[1] } else { 0 }
$loaded = if ($lua -match 'loaded \(v(\d+) / native v(\d+)') { @([int]$Matches[1], [int]$Matches[2]) } else { @(0, 0) }
$native = if ($cpp -match '(?m)^#define HJN_VERSION (\d+)') { [int]$Matches[1] } else { 0 }
$stamp = if ($cpp -match 'constexpr uint32_t\s+kExeStamp\s*=\s*0x([0-9a-fA-F]+);') { $Matches[1].ToLower().PadLeft(8, '0') } else { $null }
if (-not $version) { $problems.Add("main.lua: MOD_VERSION not found") }
elseif ($version.Length -gt 24) { $problems.Add("main.lua: MOD_VERSION '$version' is longer than 24 characters -- the in-game updater refuses such an update.txt") }
if ($build -le 0) { $problems.Add("main.lua: NATIVE.BUILD not found") }
if ($loaded[0] -ne $build) { $problems.Add("main.lua: NATIVE.BUILD is $build but its 'loaded (v...)' line says v$($loaded[0])") }
if ($native -le 0) { $problems.Add("hn_main.cpp: HJN_VERSION not found") }
if ($loaded[1] -ne $native) { $problems.Add("main.lua says native v$($loaded[1]) but hn_main.cpp is v$native") }
if (-not $stamp) { $problems.Add("hn_main.cpp: kExeStamp not found") }
if ($lua -notmatch '(?m)^\s+RecordPoses = 1,') { $problems.Add("main.lua: the pose recorder is not on by default (RecordPoses = 1)") }
if ($lua -notmatch '(?m)^\s+DevKeys = 0,') { $problems.Add("main.lua: the developer keys are not off by default (DevKeys = 0)") }
if ($lua -notmatch '(?m)^\s+HippieJump\s*= 1,') { $problems.Add("main.lua: hippie jumps do not ship with the jump animation (HippieJump = 1)") }
if ($lua -notmatch '(?m)^\s+SpeedScale\s*= 1\.0,' -or $lua -notmatch '(?m)^\s+PushScale\s*= 1\.0,' -or $lua -notmatch '(?m)^\s+StickTurn\s*= 1,' -or $lua -notmatch '(?m)^\s+ThrowdownScale\s*= 1\.0,' -or $lua -notmatch '(?m)^\s+ThrowdownRateMax\s*= 2\.5,') { $problems.Add("main.lua: the general gameplay defaults are not neutral (SpeedScale 1.0, PushScale 1.0, StickTurn 1)") }
# the release made before this one (its update.txt is still in <Out>): a build number that is not higher reaches no player
$before = Join-Path $Out 'update.txt'
if (Test-Path -LiteralPath $before) {
    $bm = [regex]::Match([System.IO.File]::ReadAllText($before), '(?m)^build=(\d+)')
    if ($bm.Success -and [int]$bm.Groups[1].Value -gt $build) { $problems.Add("main.lua: NATIVE.BUILD is $build, lower than the release already in $Out (build $($bm.Groups[1].Value)) -- no player would get this one") }
    elseif ($bm.Success -and [int]$bm.Groups[1].Value -eq $build) { Write-Host "NOTE: the release already in $Out is build $build too. If that one is published, raise NATIVE.BUILD: the updater only installs a higher build." -ForegroundColor Yellow }
}
# the dll that ships must be the one built from the source that ships (it carries its build number as text: kBuildTag),
# and it must trust the key this release is signed with
$dllBytes = [System.IO.File]::ReadAllBytes($dllPath)
if (-not (Find-Bytes $dllBytes ([System.Text.Encoding]::ASCII.GetBytes("ExpandedTricksNative-build-$native" + [char]0)))) {
    $problems.Add("main.dll is not native v$native (its build tag 'ExpandedTricksNative-build-$native' was not found in it) -- build it from source\ExpandedTricksNative and copy it in")
}
$priv = [System.IO.File]::ReadAllBytes($KeyFile)
$pub = Get-PublicBlob $priv
if (-not (Find-Bytes $dllBytes $pub)) { $problems.Add("main.dll does not carry this signing key's public half (kUpdKey in hn_main.cpp) -- players' games would refuse the update") }
$junk = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object { $_.Name -match '\.(bak|prev|new|old|log|pdb|ilk|exp|obj|ecc)$' -or $_.Name -like '*.poses*.bin' -or $_.Name -like 'ExpandedTricks.ini*' })
foreach ($j in $junk) { $problems.Add("left-over file in the package: " + $j.FullName.Substring($Root.Length + 1)) }
# (build 194) THE LUA FILE IS STARTED BY THE REAL LUA BEFORE IT SHIPS. Build 193 went to a tester with "Mods\ExpandedTricks"
# in a string: an invalid escape that the mod's own syntax checker passed and Lua 5.4 refused -- the whole Lua half did
# not load, for anyone. luareal.exe (source\tools\luareal) loads main.lua with the Lua inside UE4SS.dll and runs its top
# level and timers against a stand-in for the game, as the exe the mod was written against (0) and as another build (1).
$lr = Join-Path (Join-Path $env:USERPROFILE '.expandedtricks') 'luareal'
$lrExe = Join-Path $lr 'luareal.exe'
$lrBox = $null
if ((Test-Path -LiteralPath $lrExe) -and (Test-Path -LiteralPath (Join-Path $lr 'dryrun.lua')) -and (Test-Path -LiteralPath (Join-Path $lr 'UE4SS.dll'))) {
    $lrBox = Join-Path ([System.IO.Path]::GetTempPath()) ('et-luareal-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $lrBox | Out-Null
    foreach ($sc in 0, 1) {
        $b = Join-Path $lrBox "s$sc"
        New-Item -ItemType Directory -Path $b | Out-Null
        Set-Content -LiteralPath (Join-Path $b 'scenario.txt') -Value "$sc" -Encoding ASCII
        $res = Join-Path $b 'result.txt'
        $p = Start-Process -FilePath $lrExe -ArgumentList @('-run', ('"' + (Join-Path $lr 'dryrun.lua') + '"'), ('"' + $res + '"'), ('"' + $luaPath + '"')) -WorkingDirectory $b -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $b 'out.txt')
        if (-not $p.WaitForExit(60000)) { try { $p.Kill() } catch { }; $problems.Add("main.lua: the real-Lua dry run (scenario $sc) did not finish"); continue }
        $line = if (Test-Path -LiteralPath $res) { [string](Get-Content -LiteralPath $res -TotalCount 1) } else { '' }
        if ($line -notlike 'SYNTAX OK*') { $problems.Add("main.lua does NOT start in real Lua (scenario $sc): $line -- the run's output is in " + (Join-Path $b 'out.txt')) }
    }
    if ($problems.Count -eq 0) { Write-Host "main.lua loads and starts in real Lua 5.4 (the one inside UE4SS.dll): checked"; Remove-Item -LiteralPath $lrBox -Recurse -Force -ErrorAction SilentlyContinue }
} else {
    Write-Host "WARNING: main.lua was NOT started in real Lua ($lrExe with dryrun.lua and UE4SS.dll beside it is not there: see source\BUILD.md)." -ForegroundColor Yellow
    Write-Host "         Start the game with this build once and read ExpandedTricks.log and UE4SS.log before you publish it." -ForegroundColor Yellow
}
if ($problems.Count -gt 0) { $problems | ForEach-Object { Write-Host $_ -ForegroundColor Red }; exit 1 }

if (-not (Test-Path -LiteralPath $Out)) { New-Item -ItemType Directory -Path $Out | Out-Null }
$zip = Join-Path $Out ("ExpandedTricks-" + $version + ".zip")
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
# the zip holds one folder, ExpandedTricks-<version>, whatever the package folder is called here
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("et-release-" + [Guid]::NewGuid().ToString('N'))
$inner = Join-Path $tmp ("ExpandedTricks-" + $version)
New-Item -ItemType Directory -Path $inner | Out-Null
try {
    foreach ($item in (Get-ChildItem -LiteralPath $Root -Force | Where-Object { $_.Name -notin @(".git", ".gitignore", ".gitattributes") })) { Copy-Item -LiteralPath $item.FullName -Destination $inner -Recurse -Force }
    New-Zip $tmp $zip
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

Copy-Item -LiteralPath $luaPath -Destination (Join-Path $Out 'main.lua') -Force
Copy-Item -LiteralPath $dllPath -Destination (Join-Path $Out 'main.dll') -Force
$hl = (Get-FileHash -LiteralPath $luaPath -Algorithm SHA256).Hash.ToLower()
$hd = (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash.ToLower()
$hz = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
$txt = (@(
    "version=$version",
    "build=$build",
    "native=$native",
    "game_stamp=$stamp",
    "lua_sha256=$hl",
    "dll_sha256=$hd"
) -join "`n") + "`n"
$txtBytes = [System.Text.Encoding]::ASCII.GetBytes($txt)
[System.IO.File]::WriteAllBytes((Join-Path $Out 'update.txt'), $txtBytes)
# the signature over update.txt's exact bytes: r || s, 64 bytes, written as 128 hex digits
$k = [System.Security.Cryptography.CngKey]::Import($priv, [System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
try {
    $ec = New-Object System.Security.Cryptography.ECDsaCng($k)
    try {
        $ec.HashAlgorithm = [System.Security.Cryptography.CngAlgorithm]::Sha256
        $sig = $ec.SignData($txtBytes)
        if ($sig.Length -ne 64 -or -not $ec.VerifyData($txtBytes, $sig)) { throw "the signature did not come out as expected" }
    } finally { $ec.Dispose() }
} finally { $k.Dispose() }
[System.IO.File]::WriteAllText((Join-Path $Out 'update.txt.sig'), ((($sig | ForEach-Object { '{0:x2}' -f $_ }) -join '') + "`n"), (New-Object System.Text.ASCIIEncoding))
[System.IO.File]::WriteAllText($zip + '.sha256', "$hz  ExpandedTricks-$version.zip`n", (New-Object System.Text.ASCIIEncoding))

Write-Host ("Expanded Tricks {0}, build {1} (native v{2}, game build {3})" -f $version, $build, $native, $stamp)
Write-Host ("  {0}  ({1:N1} MB)" -f $zip, ((Get-Item -LiteralPath $zip).Length / 1MB))
foreach ($n in @('update.txt', 'update.txt.sig', 'main.lua', 'main.dll')) { Write-Host ("  {0}" -f (Join-Path $Out $n)) }
Write-Host "Attach all five to one GitHub release (tag v$version). The updater reads the release marked 'latest'."

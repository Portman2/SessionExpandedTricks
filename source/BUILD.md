# Building the native half

`ExpandedTricksNative` is a UE4SS 3.0.1 C++ mod: `hn_main.cpp` with two headers beside it (`hn_sigs.h`, generated, and
`hn_sigscan.h`), built into `Mods/ExpandedTricksNative/dlls/main.dll`.

Needs: Visual Studio 2022 Build Tools (MSVC x64, C++20) and CMake 3.20+.

1. Generate the UE4SS import library from the UE4SS.dll installed in your game (the RE-UE4SS source ships no prebuilt
   lib): follow `ExpandedTricksNative/third_party/ue4ss/README.md`; it produces `third_party/ue4ss/UE4SS.lib` from
   `UE4SS.def`.
2. Configure and build:

       cmake -S ExpandedTricksNative -B build -G "Visual Studio 17 2022" -A x64
       cmake --build build --config Release

3. Copy `build/Release/main.dll` to `SessionGame/Binaries/Win64/Mods/ExpandedTricksNative/dlls/main.dll`. A dll the
   running game has loaded can be renamed away and the new one copied in; it loads at the next start.

The native half is written against one game build (`kExeStamp` in `hn_main.cpp`, the exe's PE TimeDateStamp); every
`RVA_*` in the file comes from that build's PDB and is used as it stands there. On any other exe (Steam's, a game
update) the functions are found by signature in the exe on disk (`hn_sigs.h`, `hn_sigscan.h`) and the mod runs only
if every one is found; the log lists what each signature found.

- `tools/gen_sigs.pl <exe> <pdb> <symcache> hn_main.cpp hn_sigs.h` makes the table from the exe the RVAs belong to
  (it needs the session-mod skill's PdbDis.exe for the disassembly) and fails if any signature is not unique there.
  Run it again whenever an `RVA_*` is added or the constants are moved to a new game build.
- `tools/sigcheck.cpp` is the same search as a command-line program: `sigcheck <exe>` prints what every signature
  finds in that exe (build line in the file). Use it on any exe a player's log is about.
- `tools/gen_layout.pl <exe> <pdb> <symcache> layout.lua.inc` makes the Lua half's `NATIVE.LAYOUT` table (every reflected
  property, with its offset, of the 16 game and engine classes the native half reads by fixed offset) from the same
  exe. On another build the Lua compares the live offsets with it and stands down if a game class differs. Paste the
  result over the table in `main.lua` when the constants move to a new game build.
- `tools/luareal/` is the real-Lua check: `luareal.exe` loads `main.lua` with the Lua 5.4 inside `UE4SS.dll`
  (`luareal main.lua`), or runs its whole top level and timers against a stand-in for the game
  (`luareal -run dryrun.lua result.txt main.lua`, in an empty folder holding `scenario.txt`). Build it with
  `build_luareal.bat`, then copy `luareal.exe`, `dryrun.lua` and a copy of `UE4SS.dll` and `UE4SS-settings.ini` into
  `%USERPROFILE%\.expandedtricks\luareal\`: `make-release.ps1` then refuses a `main.lua` that does not start.
  Never run it inside a game's folder.
- `tools/luareal/test_*.lua` (27 suites) each cut one piece out of `main.lua` and run it in real Lua against a stand-in
  for the game and the native half: `luareal -run test_<name>.lua result.txt main.lua`, each in its own empty folder;
  each writes its checks (`ok` / `FAIL`) to a `*_out.txt` there and fails the run if any check fails. The first
  comment lines of each file say what it covers (throwdown speed, the grab hands in both stick modes, the two-hand
  grabs and the bone, hops, the no comply's step-off, the drop-in's set-down, GO and arms, the trick display's
  stutter fixes, the pause menu and its guard, the stick clicks handed on to the game, the caveman, the wallride, the alternate flip set, other mods, the class layout check). Checks marked `[new]` must fail
  on the build before the one that added them. Run all of them after every change to `main.lua`.

The Lua half needs no build: it is `Mods/ExpandedTricks/Scripts/main.lua`. `tools/snapshot_defaults.pl` rewrites its
shipped defaults from an `ExpandedTricks.ini` (`perl snapshot_defaults.pl main.lua ExpandedTricks.ini --globals`).

The updater in the native half uses WinHTTP and BCrypt (both part of Windows; linked by `#pragma comment`).

## Tools (`source/tools`)

- `make-release.ps1` checks the package and writes the release files: the zip, and `update.txt`, `update.txt.sig`,
  `main.lua`, `main.dll` for the in-game updater. Attach all five to one GitHub release.

## The Hippie Exterminator board (`SessionGame/Content/Customization`)

Cooked game assets, not built from source here: four of the game's shop items overridden as loose files (the
ThankYou deck *Bad Clouds 8.25*: graphic, item, icon; the DGK grip *Serape*: material, item, icon, and the grip's
own texture `TEX_GT_DGK_Hippie`). They were made with cooked-asset tools (texture cooking, a renamed shop item, a
grip material cloned from DGK's *Rosary*), no Unreal Editor. `tools/install.ps1` copies them in and records them in
`Mods/ExpandedTricks/board-files.txt`; `tools/uninstall.ps1` takes out only the ones still as installed.
- `snapshot_defaults.pl` bakes an `ExpandedTricks.ini` into main.lua's shipped defaults.
- `menutext.pl` prints the pause-menu pages as plain text and checks them against the native half's limits (a
  description holds 239 characters: run it with `check` after every change to a row's text).
- `posedump/` reads `ExpandedTricks.poses.bin` (the pose recorder, `RecordPoses=1`, which is how it ships).

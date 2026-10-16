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
  Never run it inside a game's folder. `test_throwdown.lua` runs one piece of `main.lua` the same way, the throwdown
  speed setting's watch, against made-up throwdowns (`luareal -run test_throwdown.lua result.txt main.lua`, in an empty
  folder; it writes `tdtest_out.txt` there). `test_grabswap.lua` does the same for which hand a bumper is in the game's two stick modes and which way the toe
  side is (`gstest_out.txt`), `test_grabown.lua` for a grab the game picked itself (`optest_out.txt`),
  `test_doubles.lua` for the two-hand grabs' pick, the bone and the ollie animation test on a hop (`dbtest_out.txt`), and
  `test_menuguard.lua` for the pause menu's focus guard
  (`mgtest_out.txt`).

The Lua half needs no build: it is `Mods/ExpandedTricks/Scripts/main.lua`. `tools/snapshot_defaults.pl` rewrites its
shipped defaults from an `ExpandedTricks.ini` (`perl snapshot_defaults.pl main.lua ExpandedTricks.ini --globals`).

The updater in the native half uses WinHTTP and BCrypt (both part of Windows; linked by `#pragma comment`).

## Tools (`source/tools`)

- `make-release.ps1` checks the package and writes the release files: the zip, and `update.txt`, `main.lua`, `main.dll`
  for the in-game updater. Attach all four to one GitHub release.
- `snapshot_defaults.pl` bakes an `ExpandedTricks.ini` into main.lua's shipped defaults.
- `menutext.pl` prints the pause-menu pages as plain text and checks them against the native half's limits (a
  description holds 239 characters: run it with `check` after every change to a row's text).
- `posedump/` reads `ExpandedTricks.poses.bin` (the pose recorder, `RecordPoses=1`, which is how it ships).

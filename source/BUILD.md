# Building the native half

`ExpandedTricksNative` is a UE4SS 3.0.1 C++ mod: one file, `hn_main.cpp`, built into `Mods/ExpandedTricksNative/dlls/main.dll`.

Needs: Visual Studio 2022 Build Tools (MSVC x64, C++20) and CMake 3.20+.

1. Generate the UE4SS import library from the UE4SS.dll installed in your game (the RE-UE4SS source ships no prebuilt
   lib): follow `ExpandedTricksNative/third_party/ue4ss/README.md`; it produces `third_party/ue4ss/UE4SS.lib` from
   `UE4SS.def`.
2. Configure and build:

       cmake -S ExpandedTricksNative -B build -G "Visual Studio 17 2022" -A x64
       cmake --build build --config Release

3. Copy `build/Release/main.dll` to `SessionGame/Binaries/Win64/Mods/ExpandedTricksNative/dlls/main.dll`. A dll the
   running game has loaded can be renamed away and the new one copied in; it loads at the next start.

The native half is pinned to one game build (`kExeStamp` in `hn_main.cpp`, the exe's PE TimeDateStamp); every RVA in
the file comes from that build's PDB. On another build it logs that it stood down and does nothing.

The Lua half needs no build: it is `Mods/ExpandedTricks/Scripts/main.lua`. `tools/snapshot_defaults.pl` rewrites its
shipped defaults from an `ExpandedTricks.ini` (`perl snapshot_defaults.pl main.lua ExpandedTricks.ini --globals`).

The updater in the native half uses WinHTTP and BCrypt (both part of Windows; linked by `#pragma comment`).

## Tools (`source/tools`)

- `make-release.ps1` checks the package and writes the release files: the zip, and `update.txt`, `main.lua`, `main.dll`
  for the in-game updater. Attach all four to one GitHub release.
- `snapshot_defaults.pl` bakes an `ExpandedTricks.ini` into main.lua's shipped defaults.
- `menutext.pl` prints the pause-menu pages as plain text and checks them against the native half's limits.
- `posedump/` reads `ExpandedTricks.poses.bin` (the pose recorder, `PoseRecorder=1`).

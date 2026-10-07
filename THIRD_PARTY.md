# Third-party notices

Expanded Tricks (GPLv3) is built with, and in part from, the following.

## RE-UE4SS — MIT
The mod loader. `ue4ss/UE4SS.dll` and `ue4ss/dwmapi.dll` in this package are RE-UE4SS 3.0.1, redistributed unmodified
(`ue4ss/LICENSE-UE4SS.txt`); the installer copies them only into a game that has no mod loader yet. The Lua half runs in its Lua API; the native half is a UE4SS 3.0.1 C++ mod and links against an
import library generated from the installed `UE4SS.dll` (`source/ExpandedTricksNative/third_party/ue4ss/README.md`).
https://github.com/UE4SS-RE/RE-UE4SS

## SessionOpenMP by matsix — GPLv3
- `source/ExpandedTricksNative/third_party/ue4ss_abi/ue4ss_abi.h` and the UE4SS import-library approach come from the
  SessionOpenMP source tree (its pinned UE4SS 3.0.1 ABI).
- The in-game settings pages follow SessionOpenMP's pause-menu design: the native half hosts its own pages at the same seams in the game's menu code,
  with or without SessionOpenMP (one flat page through SessionOpenMP's menu is the fall-back).
Expanded Tricks as a whole is distributed under the GPLv3 accordingly (see `LICENSE`).

## SessionTweaks by matsix — GPLv3 (part of the SessionOpenMP package)
- The native half's pose-buffer layout and its two-bone arm solve follow SessionTweaks' `src/tweaks/sit.cpp`.
- Not required at run time. With `NativePad=0` the mod reads controller presses from `SessionTweaks.log` instead of
  the game's key events (SessionTweaks' `CatchClickToCatch=1` / `CatchClickProbe=2000000000` make it log them).

## Session: Skate Sim — crea-ture Studios / Nacon
The game. No game assets are redistributed: the mod uses the game's own animations, sounds and widgets at run time.
The grabs are the game's own unfinished feature, switched on through its experimental settings save.

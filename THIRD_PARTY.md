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
The game. The mod uses the game's own animations, sounds and widgets at run time. The one exception is the Hippie
Exterminator board under `SessionGame/Content/Customization`: eighteen cooked files that override four of the game's
shop items (a ThankYou deck's graphic, item and icon; a DGK grip's material, item and icon). They are the game's own
assets of those slots, with the picture, the name and the grip material changed; they work only over the game's pak.

## The Hippie Exterminator artwork
The deck and grip print a scene from *South Park* (Cartman in a hazmat suit, "Die Hippie Die", 2005). *South Park*
is (c) Comedy Central / South Park Studios. This is fan art: Expanded Tricks is not affiliated with or endorsed by
them, and the artwork is not covered by this package's GPLv3.
The grabs are the game's own unfinished feature, switched on through its experimental settings save.

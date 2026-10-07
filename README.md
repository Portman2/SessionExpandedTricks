# Expanded Tricks 1.0.0 for Session: Skate Sim

Hippie jumps, grabs, no complies, bonelesses, finger flips and drop-ins for Session, with its own settings pages in the
pause menu. Source and releases: https://github.com/Portman2/SessionExpandedTricks

## What it adds

- **Hippie jumps.** Crouch with one stick and click the other stick: you jump, the board rolls on under you, you land
  back on it. Click both sticks for a mini hippie jump. Hold a trigger in the air to spin: a half turn is a 180 and
  lands you switch.
- **Grabs.** The game's own twelve grabs, switched on and finished. In the air hold LB (front hand, the left stick
  picks the grab) or RB (back hand, the right stick picks). Hold both bumpers for a two-hand grab (Cannonball, Gorilla
  Grab, Quasimodo).
- **No comply.** The game's unused no-comply animation, on the pressure kickflip's input (riding regular: left stick
  down + right stick left). Regular and goofy, and riding switch.
- **Boneless and bean plant.** Hold RB (back hand) or LB (front hand) so a hand is on the board, then do a no comply.
- **Rolling grabs and finger flips.** Riding on the ground, hold RB or LB to put a hand on the board. Flick a flip
  trick with the hand on and the hand flips the board.
- **Drop-ins.** On foot, standing still at the edge of a ledge, bank or ramp with the board in your hand, press Y
  (Triangle). The board is set tail-down on the edge; push a stick up to drop in, LB or RB to step back, Y to step off.
- **Jumping onto the board.** On foot next to your board lying on the ground, click a stick.
- **Trick names** in the game's own trick display.
- **Settings in the pause menu** under *Expanded Tricks*, and everything else in `ExpandedTricks.ini`.

## Requirements

- Session: Skate Sim on PC, the build current in October 2026 (Epic's launcher lists it as 1.0.6.42; its exe was built
  on 30 March 2026). The mod checks the game's build and switches itself off on any other, and says so in
  `ExpandedTricks.log`: after a game update expect the mod to do nothing until the mod is updated.
- A controller.
- UE4SS 3.0.1, the mod loader. **The installer puts it in for you if the game has none.** If you already use
  SessionOpenMP or SessionTweaks you have it, and it is left as it is.
- The Microsoft Visual C++ 2015-2022 Redistributable (x64), a current one. Most PCs with games have it; UE4SS does not
  start without it.

No other mod is needed. SessionOpenMP (co-op) and SessionTweaks can stay installed next to it.

Do not use it together with the *NoComplyWayBetter* mod: both put the no comply into the same trick.

## Install

1. Unzip the whole download somewhere (not inside the game's folder).
2. Close the game. Double-click **install.bat** (if Windows asks whether to run it, choose Run). It finds the game
   (Steam or Epic) and copies the mod in. If it cannot find the game, or finds more than one copy, it asks you. From a
   command prompt you can name the folder yourself: `install.bat -GameDir "D:\Games\Session"`.
3. Start the game. The first time, quit and start it once more: the mod switches on the game's own grab feature in
   its save, and the game only reads that at start-up. If you had never started the game before installing the mod,
   it takes one start more.

By hand instead: copy this package's `SessionGame` folder over the game's `SessionGame` folder, so that you end up with
`SessionGame\Binaries\Win64\Mods\ExpandedTricks` and `...\Mods\ExpandedTricksNative`. If the game has no `UE4SS.dll` in
`SessionGame\Binaries\Win64`, also copy `UE4SS.dll`, `dwmapi.dll` and `UE4SS-settings.ini` from the package's `ue4ss`
folder there.

## Updating

The mod looks for a new version on its GitHub page each time you start the game. It downloads it, checks that it
carries the author's signature, and puts it in place for the next start. You are told on the trick display and in the
log. The *Automatic updates* row on the *General gameplay settings* page changes that: 2 = install by itself,
1 = only tell me, 0 = never look.

Your settings (`ExpandedTricks.ini`) are never part of an update.

## Controls

LS / RS = left / right stick, L3 / R3 = a stick clicked in, LB / RB = bumpers, LT / RT = triggers.
Written for a regular rider; riding goofy or switch the sticks swap as they do for the game's own tricks.

| Trick | Input |
|---|---|
| Hippie jump | Stick down (crouch) + the other stick's click: LS down + R3, or RS down + L3 |
| Mini hippie jump | L3 + R3 |
| Spin in a hippie jump | LT or RT, held in the air |
| Grab, front hand | LB + LS direction, in the air |
| Grab, back hand | RB + RS direction, in the air |
| Two-hand grab | LB + RB, in the air |
| No comply | LS down + RS left (the pressure kickflip's input) |
| Boneless | RB + no comply |
| Bean plant | LB + no comply |
| Rolling grab | RB or LB, riding |
| Finger flip | RB or LB + a flip trick's flick |
| Drop-in | Y at an edge, on foot and standing still, board in hand; then Stick up to go, LB / RB to step back, Y to step off |
| Jump onto the board | L3 or R3, on foot next to the board |

## Settings

Pause the game and open **Expanded Tricks**. Every row says what it does and in what unit, and ends with its default.
The pages: General gameplay settings, Quick settings, Hippie Jumps, Drop-ins, Grabs, Rolling Grabs and Finger Flips,
No Comply and Boneless.

Everything, including the fine tuning of each grab's hand, is in `ExpandedTricks.ini` beside the game's exe. The game
re-reads it every second, so you can edit and save while playing. Each line has a comment.

## Something wrong?

1. Run **`Mods\ExpandedTricks\pack-logs.bat`** in the game's `SessionGame\Binaries\Win64` folder.
2. It puts `ExpandedTricks-logs-<date>.zip` on your desktop (under 8 MB, so it fits in a Discord message).
3. Send that file and say what you did and roughly when. Every log line has the time of day.

The zip holds the mod's logs and settings, UE4SS's log, SessionTweaks' log and settings if you have that mod, and a
short list of what is installed: your Windows version, the names of the folders in `Mods`, `mods.txt` and the path of
your game folder. That path, and the path of the game's save folder in the mod's first log, can show your Windows user
name. Nothing is sent anywhere by itself.

For a bad-looking pose, set `PoseRecorder=1` in `ExpandedTricks.ini`, do the trick again and send
`ExpandedTricks.poses.bin` as well (it can get large).

## Uninstall

Double-click **uninstall.bat**. It removes the mod's two folders, and asks before removing your settings and logs,
and before removing UE4SS if this installer was what put it in and no other mod is left in `Mods`.

## Known limits

- One game build (see Requirements).
- The game's grab animations are unfinished; the mod poses the hand, arm, legs and deck on top of them. Odd poses
  happen, and the per-grab numbers in the ini are there to tune them.
- In the replay editor the mod's poses are replayed as recorded, not re-made.
- A goofy rider's switch no comply, boneless and bean plant are new in this build and little tested.

## Building from source

See `source/BUILD.md`. The Lua half is `SessionGame/Binaries/Win64/Mods/ExpandedTricks/Scripts/main.lua`; the native
half is one C++ file, `source/ExpandedTricksNative/hn_main.cpp`. `source/tools/make-release.ps1` puts a release
together and signs it.

## Licence

Copyright (C) 2026 Portman2. GPLv3 (`LICENSE`), with an added permission to run it inside the game (`LICENSE-EXCEPTION.txt`). Third-party notices are in `THIRD_PARTY.md`. This mod is not made or endorsed by the game's
developers.

# Expanded Tricks 1.1.2 for Session: Skate Sim

New flip tricks (monster, dolphin, porpoise, nightmare, daydream, underflips, the hospital flip), wallrides, the caveman,
hippie jumps, grabs, no complies, bonelesses, finger flips and drop-ins for Session, with its own settings pages in the
pause menu. Source and releases: https://github.com/Portman2/SessionExpandedTricks

The full list of tricks with their inputs is in [docs/TRICKS.md](docs/TRICKS.md). What changed since 1.0.0 is in
[CHANGELOG.md](CHANGELOG.md).

## What it adds

- **Hippie jumps.** Crouch with one stick and click the other stick: you jump, the board rolls on under you, and you land
  back on it. Click both sticks for a mini hippie jump. Hold a trigger in the air to spin: a half turn is a 180 and
  lands you switch, a full turn a 360. They work riding switch too. *Hippie jumps* in the menu picks the animation: the
  jump, the game's ollie, or one or the other at random.
- **An alternate flip set.** Push the back-foot stick **up** (the game does nothing with it) and you crouch for a second
  set of flip tricks. From that crouch, the front-foot stick: **down** for a **Monster Flip** (the board turns a full
  circle end over end), **up** for a **Dolphin Flip** (end over end forward, then a half flip; it lands reversed), up
  and leaning toward your heelflip's side for a **Porpoise Flip** (the dolphin with the half flip the heelflip's way).
  Your varial flip's scoop and flick from it is a **Nightmare Flip** (a 180 shove-it with a double kickflip). Your varial
  heelflip's is a **Daydream Flip** (the same with a double heelflip). Hold the **front-foot stick down** instead and the
  back-foot stick does the nollie versions (fakie when you ride switch).
- **Underflips.** From the alternate crouch, do your kickflip or heelflip, then flick a stick sideways again while the
  board is upside down. It turns back the way it came and lands grip up: the **Kickflip Underflip** and the
  **Heelflip Cancel Flip**. From the crouch's shove-it, a late sideways flick adds a whole flip the other way: the
  **Shuv-it Underflip**. Scoop half way round (the 360 shove-it's scoop) and it is the **Shuv-it Under Varial Flip**,
  where the spin and the flip finish together.
- **Hospital Flip.** Switch on *Caspers* in the game's experimental settings. Catch a kickflip in a casper, then, still
  in the air, pull the front-foot stick **back**. The board turns 180 end over end on your front foot and lands grip up,
  reversed. *Hospital flip: time* on the Flip Tricks page sets how slow it turns.
- **Wallrides.** Fly into a wall at a shallow angle in any air on the board and you ride along it for a moment. There is
  no button. It works frontside and backside, and on curved walls too. Push a stick up on the wall to pop off it.
  With *Wallride from the ground* switched on (Wallrides page; on by default) you can also ride straight up onto a wall
  from the ground: crouch as you roll into it and the board wallies up onto the wall. The game had the animation but
  never used it.
- **Caveman.** On foot with the board in your hand, jump (X), then press Y in the air. The board swings from your hand
  down under your feet, your hand holds it (a Melon or an Indy) with the knees up, lets go, and you land and roll away.
  Tap Y twice for a switch caveman. The game's own version moved the board to your feet in one frame.
- **No comply.** The game's unused no-comply animation, on the pressure kickflip's input (riding regular: left stick
  down + right stick left). Regular and goofy, and riding switch.
- **Boneless and bean plant.** Hold RB (back hand) or LB (front hand) so a hand is on the board, then do a no comply.
  The game catches the board for you and the hand lets go as the board comes back under your feet. Let the bumper go
  before the next grab. A bumper pressed late in the trick puts no hand on.
- **Grabs.** The game's own twelve grabs, switched on and finished. In the air, hold LB (front hand; the left stick picks
  the grab) or RB (back hand; the right stick picks). Hold both bumpers for a two-hand grab. Moving a stick off the
  direction it picked a grab with tweaks the grab. Four grabs between the legs (Chicken Salad, Taipan, Roast Beef and
  Canadian Bacon) are off as the mod ships, so the stick's diagonal picks the grab next to them; put
  `GrabBlocked=None` in the ini to have all twelve.
- **Rolling grabs and finger flips.** Riding on the ground, hold RB or LB to put a hand on the board. Flick a flip
  trick with the hand on and the hand lets go as the board leaves the ground, so it looks as if the hand flipped it.
- **Drop-ins.** On foot at the edge of a ledge, bank or ramp (within about 90 cm of it) with the board in your hand,
  press Y. The board is set tail-down on the coping and you step on. Then push a stick up to drop in, press LB or RB to
  step back, or press Y to step off. Tap Y twice to be put on in switch, facing away from the drop. Farther from an
  edge, Y is the game's own throwdown.
- **Throwdown speed.** A slider on the General gameplay settings page. The game's own throwdown plays faster and you
  roll away faster, as a percentage of the speed you were moving at. 100 % (as it ships) = unchanged.
- **Jumping onto the board.** On foot next to your board lying on the ground, click a stick. Run at it and your speed
  is carried onto the board.
- **Legs that look right.** The mod straightens the shins that the game's animations warp above the ankle, in hippie
  jumps, no complies, bonelesses, bean plants and wallrides.
- **Trick names** in the game's own trick display, for every stance: regular, switch, nollie and fakie, with the
  game's rotation names (for example *FS Monster Flip 360* or *Half Cab Dolphin Flip*).
- **Settings in the pause menu** under *Expanded Tricks*, and everything else in `ExpandedTricks.ini`.
- **The Hippie Exterminator board.** A deck and a matching full-colour grip, both called *Hippie Exterminator* in the
  shop: the deck under **ThankYou** (in place of *Bad Clouds 8.25*), the grip under **DGK** (in place of *Serape*).
  They are loose files over the game's pak under `SessionGame\Content`; nothing in the pak is changed. To leave
  them out: `install.bat -NoBoard`.

## Requirements

- Session: Skate Sim on PC, from Epic or Steam. The mod was written against Epic's build of October 2026 (the launcher
  lists it as 1.0.6.42; its exe was built on 30 March 2026). On any other exe (Steam's is one, and so is any game
  update) it looks for the game's functions by their byte patterns when the game starts and runs only if it finds
  every one of them. Otherwise it switches itself off and says so in `ExpandedTricks.log`. Steam's exe has been run
  by a tester (every function found) but not by the author.
  **On any exe other than Epic's**, the alternate flip set (the monster, dolphin, porpoise, nightmare and daydream flips,
  the underflips and the hospital flip), wallrides and the drop-in set-down on the coping stand down, and the log says
  so. They write parts of the game that were only checked on Epic's exe. Everything else runs.
- The game's stick mode (Options > Gameplay) set to *front foot / back foot* or *left foot / right foot* for the
  alternate flip set. It is off in the *Legacy* mode.
- Steam Deck / Linux: copy the files by hand (the installer is Windows-only) and set the game's launch option to
  `WINEDLLOVERRIDES="dwmapi=n,b" %command%` so the mod loader starts. Untested.
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
`SessionGame\Binaries\Win64\Mods\ExpandedTricks` and `...\Mods\ExpandedTricksNative` (and the board's files under
`SessionGame\Content\Customization`; leave the package's `SessionGame\Content` folder out if you do not want the
board). If the game has no `UE4SS.dll` in `SessionGame\Binaries\Win64`, also copy `UE4SS.dll`, `dwmapi.dll` and
`UE4SS-settings.ini` from the package's `ue4ss` folder there.

## Updating

The mod looks for a new version on its GitHub page each time you start the game. It downloads it, checks that it
carries the author's signature, and puts it in place for the next start. You are told on the trick display
("Expanded Tricks updated - restart the game") and in the log. The *Automatic updates* row on the *General gameplay
settings* page changes that: 2 = install by itself, 1 = only tell me, 0 = never look.

From 1.0.0: if you have 1.0.0 and left *Automatic updates* at 2, the game installs 1.1.0 by itself the next time you
start it, and you are on 1.1.0 from the start after that. The files it had before are kept as `main.lua.prev` and
`main.dll.prev`. Your settings are kept. New settings are added to your ini with their defaults, and settings you
already had keep your values. The update replaces only the mod's two files, so for the new README and trick list
download the zip as well (the in-game files are the same).

Your settings (`ExpandedTricks.ini`) are never part of an update.

## Controls

The mod's flip tricks work in two of the game's stick modes (Options > Gameplay). The table has a column for each way
your feet can sit on the sticks:

- **Front foot / back foot** (first column, shown for a **regular rider riding forward**): the left stick is your front
  foot and the right stick your back foot, in every stance. A regular rider riding forward in the *left foot / right
  foot* mode uses this column too, as the left foot is the front one.
- **Left foot / right foot, left foot at the back** (second column): each stick is that foot, so with your left foot at
  the back the **left stick is your back foot** and the right stick your front foot. That is a **goofy rider riding
  forward** or a **regular rider riding switch**, in the *left foot / right foot* mode. Both get the same inputs: the
  game's switch tricks are its regular ones with the sticks traded and left and right swapped, as a goofy rider's are.
- In the *front foot / back foot* mode the sticks never trade, but left and right swap as they do for the game's own
  kickflip: riding goofy forward or regular switch, take the first column with every left and right swapped and every
  sweep going round the other way (a 12 to 9 becomes a 12 to 3). A goofy rider riding switch has his left foot in front
  again: in either mode, the first column.

Reading the icons: <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> is a stick pushed that way;
<img src="docs/buttons/RS-12-9.svg" alt="RS 12 to 9" height="28"> is a stick swept round its rim, from the dot to the
arrow, as on a clock (12 o'clock is up, 3 is right, 6 is down, 9 is left). Steps are done in order, left to right.

- **The alternate crouch** hands the game your back stick turned upside down: pushed up, the game reads it as its own
  crouch (down). So a sweep from 12 to 9 is, to the game, its shove-it scoop from 6 to 9.
- **Nollie and fakie:** the alternate flip set has its own nollie crouch (below). The underflips, the hospital flip and
  the trick names follow the stance you pop from (riding switch the tricks are the switch and fakie versions).
- **Fakie shuv-its:** the second column's nollie shuv-it rows are a goofy rider's nollie ones. A regular rider riding
  fakie gets the game's own fakie shove-its, whose scoops go round the other way: 6 to 3 is his fakie backside one (late
  flick <img src="docs/buttons/LS-right.svg" alt="LS right" height="28">) and 6 to 9 his frontside one (late flick <img src="docs/buttons/LS-left.svg" alt="LS left" height="28">), the same late flick for each name as in the
  row.
- **The hospital flip** needs *Caspers* switched on in the game's own experimental settings. The casper is the game's:
  caught with the board half flipped, upside down on your front foot.
- **The underflips' second flick** is shown on one stick. Any side flick of either stick, while the board is
  upside down (kickflip / heelflip) or late in a shove-it's air, is read too: the kickflip and heelflip ones either way,
  the shuv-it ones only on the side shown.
- Left and right on a stick are the sides of the board. Your *toe side* is on the right when you ride regular and roll
  forward, on the left when you ride goofy, and the other way round riding switch. The *heelflip's side* is the way
  you flick for the game's heelflip: right in the first column, left in the second.

| Trick | Front foot / back foot (regular riding forward) | Left foot / right foot, left foot at the back (goofy forward, regular switch) |
|---|---|---|
| Hippie jump | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> + <img src="docs/buttons/R3.svg" alt="R3" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> + <img src="docs/buttons/L3.svg" alt="L3" height="28"> | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> + <img src="docs/buttons/R3.svg" alt="R3" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> + <img src="docs/buttons/L3.svg" alt="L3" height="28"> |
| Mini hippie jump | <img src="docs/buttons/L3.svg" alt="L3" height="28"> + <img src="docs/buttons/R3.svg" alt="R3" height="28"> | <img src="docs/buttons/L3.svg" alt="L3" height="28"> + <img src="docs/buttons/R3.svg" alt="R3" height="28"> |
| 180 / 360 hippie jump | <img src="docs/buttons/LT.svg" alt="LT" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/RT.svg" alt="RT" height="28"> held in the air | <img src="docs/buttons/LT.svg" alt="LT" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/RT.svg" alt="RT" height="28"> held in the air |
| Alternate crouch | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> from a centred stick, held | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> from a centred stick, held |
| Monster Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> held, then <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> held, then <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> |
| Dolphin Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> held, then <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> held, then <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> |
| Porpoise Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> held, then <img src="docs/buttons/LS-up-right.svg" alt="LS up, leaning right" height="28"> (up, leaning about 20 to 30 degrees toward your heelflip's side) | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> held, then <img src="docs/buttons/RS-up-left.svg" alt="RS up left" height="28"> (up, leaning about 20 to 30 degrees toward your heelflip's side) |
| Nightmare Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28">, then <img src="docs/buttons/RS-12-9.svg" alt="RS 12 to 9" height="28">, then <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28">, then <img src="docs/buttons/LS-12-3.svg" alt="LS 12 to 3" height="28">, then <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> |
| Daydream Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28">, then <img src="docs/buttons/RS-12-3.svg" alt="RS 12 to 3" height="28">, then <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28">, then <img src="docs/buttons/LS-12-9.svg" alt="LS 12 to 9" height="28">, then <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> |
| Kickflip Underflip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> held, then <img src="docs/buttons/LS-left.svg" alt="LS left" height="28">; the board upside down, in the air: <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> held, then <img src="docs/buttons/RS-right.svg" alt="RS right" height="28">; the board upside down, in the air: <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> |
| Heelflip Cancel Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> held, then <img src="docs/buttons/LS-right.svg" alt="LS right" height="28">; the board upside down, in the air: <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> held, then <img src="docs/buttons/RS-left.svg" alt="RS left" height="28">; the board upside down, in the air: <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> |
| BS Shuv-it Underflip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28">, then <img src="docs/buttons/RS-12-9.svg" alt="RS 12 to 9" height="28">, let go; late, in the air: <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28">, then <img src="docs/buttons/LS-12-3.svg" alt="LS 12 to 3" height="28">, let go; late, in the air: <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> |
| FS Shuv-it Underflip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28">, then <img src="docs/buttons/RS-12-3.svg" alt="RS 12 to 3" height="28">, let go; late, in the air: <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28">, then <img src="docs/buttons/LS-12-9.svg" alt="LS 12 to 9" height="28">, let go; late, in the air: <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> |
| BS Shuv-it Under Varial Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28">, then <img src="docs/buttons/RS-12-6ccw.svg" alt="RS 12 to 6 by 9" height="28"> (round by 9, at least 135 degrees), let go; late, in the air: <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28">, then <img src="docs/buttons/LS-12-6cw.svg" alt="LS 12 6cw" height="28"> (round by 3, at least 135 degrees), let go; late, in the air: <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> |
| FS Shuv-it Under Varial Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28">, then <img src="docs/buttons/RS-12-6cw.svg" alt="RS 12 to 6 by 3" height="28"> (round by 3, at least 135 degrees), let go; late, in the air: <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28">, then <img src="docs/buttons/LS-12-6ccw.svg" alt="LS 12 6ccw" height="28"> (round by 9, at least 135 degrees), let go; late, in the air: <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> |
| Alternate nollie crouch | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> from a centred stick, held | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> from a centred stick, held |
| Nollie Monster Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> held, then <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> held, then <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> |
| Nollie Dolphin Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> held, then <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> held, then <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> |
| Nollie Porpoise Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> held, then <img src="docs/buttons/RS-up-right.svg" alt="RS up, leaning right" height="28"> (up, leaning toward your heelflip's side) | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> held, then <img src="docs/buttons/LS-up-left.svg" alt="LS up left" height="28"> (up, leaning toward your heelflip's side) |
| Nollie Nightmare Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28">, then <img src="docs/buttons/LS-6-9.svg" alt="LS 6 to 9" height="28"> or <img src="docs/buttons/LS-6-3.svg" alt="LS 6 to 3" height="28">, then <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28">, then <img src="docs/buttons/RS-6-3.svg" alt="RS 6 to 3" height="28"> or <img src="docs/buttons/RS-6-9.svg" alt="RS 6 to 9" height="28">, then <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> |
| Nollie Daydream Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28">, then <img src="docs/buttons/LS-6-3.svg" alt="LS 6 to 3" height="28"> or <img src="docs/buttons/LS-6-9.svg" alt="LS 6 to 9" height="28">, then <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28">, then <img src="docs/buttons/RS-6-9.svg" alt="RS 6 to 9" height="28"> or <img src="docs/buttons/RS-6-3.svg" alt="RS 6 to 3" height="28">, then <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> |
| Nollie Kickflip Underflip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> held, then <img src="docs/buttons/RS-left.svg" alt="RS left" height="28">; the board upside down, in the air: <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> held, then <img src="docs/buttons/LS-right.svg" alt="LS right" height="28">; the board upside down, in the air: <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> |
| Nollie Heelflip Cancel Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> held, then <img src="docs/buttons/RS-right.svg" alt="RS right" height="28">; the board upside down, in the air: <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> held, then <img src="docs/buttons/LS-left.svg" alt="LS left" height="28">; the board upside down, in the air: <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> |
| Nollie BS Shuv-it Underflip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28">, then <img src="docs/buttons/LS-6-3.svg" alt="LS 6 to 3" height="28">, let go; late, in the air: <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28">, then <img src="docs/buttons/RS-6-9.svg" alt="RS 6 to 9" height="28">, let go; late, in the air: <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> (fakie: see the note) |
| Nollie FS Shuv-it Underflip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28">, then <img src="docs/buttons/LS-6-9.svg" alt="LS 6 to 9" height="28">, let go; late, in the air: <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28">, then <img src="docs/buttons/RS-6-3.svg" alt="RS 6 to 3" height="28">, let go; late, in the air: <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> (fakie: see the note) |
| Nollie BS Shuv-it Under Varial Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28">, then <img src="docs/buttons/LS-6-12ccw.svg" alt="LS 6 to 12 by 3" height="28"> (round by 3), let go; late, in the air: <img src="docs/buttons/RS-left.svg" alt="RS left" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28">, then <img src="docs/buttons/RS-6-12cw.svg" alt="RS 6 12cw" height="28"> (round by 9), let go; late, in the air: <img src="docs/buttons/LS-right.svg" alt="LS right" height="28"> (fakie: see the note) |
| Nollie FS Shuv-it Under Varial Flip | <img src="docs/buttons/LS-down.svg" alt="LS down" height="28">, then <img src="docs/buttons/LS-6-12cw.svg" alt="LS 6 to 12 by 9" height="28"> (round by 9), let go; late, in the air: <img src="docs/buttons/RS-right.svg" alt="RS right" height="28"> | <img src="docs/buttons/RS-down.svg" alt="RS down" height="28">, then <img src="docs/buttons/RS-6-12ccw.svg" alt="RS 6 12ccw" height="28"> (round by 3), let go; late, in the air: <img src="docs/buttons/LS-left.svg" alt="LS left" height="28"> (fakie: see the note) |
| Hospital Flip | <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> held, then <img src="docs/buttons/LS-left.svg" alt="LS left" height="28">; catch a casper in the air; then <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> | <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> held, then <img src="docs/buttons/RS-right.svg" alt="RS right" height="28">; catch a casper in the air; then <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> |
| Wallride | automatic: in the air on the board, fly into a wall at a shallow angle; <img src="docs/buttons/stick-up.svg" alt="stick up" height="28"> on the wall pops you off | automatic: in the air on the board, fly into a wall at a shallow angle; <img src="docs/buttons/stick-up.svg" alt="stick up" height="28"> on the wall pops you off |
| Wallride from the ground | roll into a wall at a shallow angle holding the crouch | roll into a wall at a shallow angle holding the crouch |
| Caveman | <img src="docs/buttons/X.svg" alt="X" height="28"> (jump, on foot, board in hand), then <img src="docs/buttons/Y.svg" alt="Y" height="28"> in the air | <img src="docs/buttons/X.svg" alt="X" height="28"> (jump, on foot, board in hand), then <img src="docs/buttons/Y.svg" alt="Y" height="28"> in the air |
| Switch caveman | <img src="docs/buttons/X.svg" alt="X" height="28">, then <img src="docs/buttons/Y.svg" alt="Y" height="28"> <img src="docs/buttons/Y.svg" alt="Y" height="28"> (tapped twice) in the air | <img src="docs/buttons/X.svg" alt="X" height="28">, then <img src="docs/buttons/Y.svg" alt="Y" height="28"> <img src="docs/buttons/Y.svg" alt="Y" height="28"> (tapped twice) in the air |
| No comply | <img src="docs/buttons/RS-left.svg" alt="RS left" height="28">, then <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> | <img src="docs/buttons/LS-right.svg" alt="LS right" height="28">, then <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> |
| Boneless | <img src="docs/buttons/RB.svg" alt="RB" height="28">, then <img src="docs/buttons/RS-left.svg" alt="RS left" height="28">, then <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> | <img src="docs/buttons/LB.svg" alt="LB" height="28"> (your back hand), then <img src="docs/buttons/LS-right.svg" alt="LS right" height="28">, then <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> |
| Bean plant | <img src="docs/buttons/LB.svg" alt="LB" height="28">, then <img src="docs/buttons/RS-left.svg" alt="RS left" height="28">, then <img src="docs/buttons/LS-down.svg" alt="LS down" height="28"> | <img src="docs/buttons/RB.svg" alt="RB" height="28"> (your front hand), then <img src="docs/buttons/LS-right.svg" alt="LS right" height="28">, then <img src="docs/buttons/RS-down.svg" alt="RS down" height="28"> |
| Grab, front hand | <img src="docs/buttons/LB.svg" alt="LB" height="28"> + <img src="docs/buttons/LS.svg" alt="LS" height="28"> in the air | <img src="docs/buttons/RB.svg" alt="RB" height="28"> (the right hand) + <img src="docs/buttons/RS.svg" alt="RS" height="28"> in the air |
| Grab, back hand | <img src="docs/buttons/RB.svg" alt="RB" height="28"> + <img src="docs/buttons/RS.svg" alt="RS" height="28"> in the air | <img src="docs/buttons/LB.svg" alt="LB" height="28"> (the left hand) + <img src="docs/buttons/LS.svg" alt="LS" height="28"> in the air |
| Grab tweak: bone (forward) | while holding a grab, turn its stick round the rim from where it picked the grab, either way; an Indy for example: <img src="docs/buttons/RB.svg" alt="RB" height="28"> + <img src="docs/buttons/RS-right.svg" alt="RS right" height="28">, then <img src="docs/buttons/RS-3-1.svg" alt="RS 3 to 1" height="28"> or <img src="docs/buttons/RS-3-5.svg" alt="RS 3 to 5" height="28">. The board is poked out toward the nose (depending on settings: *Grab tweak* on 1 = bone, as the mod ships; how far: *All grabs: bone distance*, *Boned grabs: how far out*; what moves: *Bone moves*) | an Indy for example: <img src="docs/buttons/LB.svg" alt="LB" height="28"> + <img src="docs/buttons/LS-left.svg" alt="LS left" height="28">, then <img src="docs/buttons/LS-9-11.svg" alt="LS 9 to 11" height="28"> or <img src="docs/buttons/LS-9-7.svg" alt="LS 9 to 7" height="28"> |
| Grab tweak: rotate | the same turn of the stick: <img src="docs/buttons/RS-3-1.svg" alt="RS 3 to 1" height="28"> and <img src="docs/buttons/RS-3-5.svg" alt="RS 3 to 5" height="28"> twist your legs and the board opposite ways (depending on settings: *Grab tweak* on 0 = rotate; *Invert grab tweak direction* swaps the two ways; *Tweak only when the stick moves* off lets the game's twist in at once). Nose and tail grabs always rotate | <img src="docs/buttons/LS-9-11.svg" alt="LS 9 to 11" height="28"> and <img src="docs/buttons/LS-9-7.svg" alt="LS 9 to 7" height="28"> twist opposite ways (the same settings) |
| Two-hand grab | <img src="docs/buttons/LB.svg" alt="LB" height="28"> + <img src="docs/buttons/RB.svg" alt="RB" height="28"> in the air | <img src="docs/buttons/LB.svg" alt="LB" height="28"> + <img src="docs/buttons/RB.svg" alt="RB" height="28"> in the air |
| Two-hand grab tweak | <img src="docs/buttons/LB.svg" alt="LB" height="28"> + <img src="docs/buttons/RB.svg" alt="RB" height="28">, then turn the stick you swing further, as above; a pair picked with both sticks to a side (Truck Driver, Drunk Driver, Squirrel): <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> + <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> after the grab is made bones it | <img src="docs/buttons/LB.svg" alt="LB" height="28"> + <img src="docs/buttons/RB.svg" alt="RB" height="28">, then turn the stick you swing further, as above; a pair picked with both sticks to a side (Truck Driver, Drunk Driver, Squirrel): <img src="docs/buttons/LS-up.svg" alt="LS up" height="28"> + <img src="docs/buttons/RS-up.svg" alt="RS up" height="28"> after the grab is made bones it |
| Rolling grab | <img src="docs/buttons/RB.svg" alt="RB" height="28"> (back hand) &nbsp;or&nbsp; <img src="docs/buttons/LB.svg" alt="LB" height="28"> (front hand) while riding | <img src="docs/buttons/LB.svg" alt="LB" height="28"> (back hand) &nbsp;or&nbsp; <img src="docs/buttons/RB.svg" alt="RB" height="28"> (front hand) while riding |
| Finger flip | <img src="docs/buttons/RB.svg" alt="RB" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/LB.svg" alt="LB" height="28"> + a flip trick's flick | <img src="docs/buttons/RB.svg" alt="RB" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/LB.svg" alt="LB" height="28"> + a flip trick's flick |
| Drop-in | <img src="docs/buttons/Y.svg" alt="Y" height="28"> at an edge, on foot, board in hand; then <img src="docs/buttons/stick-up.svg" alt="stick up" height="28"> to go, <img src="docs/buttons/LB.svg" alt="LB" height="28"> / <img src="docs/buttons/RB.svg" alt="RB" height="28"> to step back, <img src="docs/buttons/Y.svg" alt="Y" height="28"> to step off | <img src="docs/buttons/Y.svg" alt="Y" height="28"> at an edge, on foot, board in hand; then <img src="docs/buttons/stick-up.svg" alt="stick up" height="28"> to go, <img src="docs/buttons/LB.svg" alt="LB" height="28"> / <img src="docs/buttons/RB.svg" alt="RB" height="28"> to step back, <img src="docs/buttons/Y.svg" alt="Y" height="28"> to step off |
| Drop-in in switch | <img src="docs/buttons/Y.svg" alt="Y" height="28"> <img src="docs/buttons/Y.svg" alt="Y" height="28"> (tapped twice) at an edge, on foot, board in hand | <img src="docs/buttons/Y.svg" alt="Y" height="28"> <img src="docs/buttons/Y.svg" alt="Y" height="28"> (tapped twice) at an edge, on foot, board in hand |
| Jump onto the board | <img src="docs/buttons/L3.svg" alt="L3" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/R3.svg" alt="R3" height="28"> near the board | <img src="docs/buttons/L3.svg" alt="L3" height="28"> &nbsp;or&nbsp; <img src="docs/buttons/R3.svg" alt="R3" height="28"> near the board |

How each one is done, in more detail and for every stance: [docs/TRICKS.md](docs/TRICKS.md).

L3 is also the game's own button for the missions. A click the mod uses (a hippie jump, a mini hop, a jump onto the
board) is kept from the game; any other click goes on to it. SessionTweaks' *Click to catch* (its Catch page) keeps
both stick clicks to itself while you are on the board, so with it on, L3 opens no missions there.

## Settings

Pause the game and open **Expanded Tricks**. Every row says what it does and in what unit, and ends with its default.
The pages:

- **General gameplay settings:** max speed, push strength, throwdown speed, left-stick steering, trick names and
  automatic updates. They all ship at the game's own behaviour (100 %, steering on).
- **Hippie Jumps:** the hippie and mini hippie jumps, their heights, spinning, bailing on a bad spin, jumping onto the
  board, and the caveman.
- **Drop-ins:** the drop-in, its launch speed, the arms and crouch on the way down, and vert walls.
- **Grabs:** air grabs, two-hand grabs, tweaking and boning, the head, letting go on landing, and moving every grab's
  hand at once.
- **No Comply and Boneless:** the no comply, the boneless and the bean plant: the planted foot, the pop and the scoop.
- **Rolling Grabs and Finger Flips:** the rolling grab's squat and hands, and finger flips.
- **Flip Tricks:** the alternate flip set and its nollie set on or off, how far the stick goes, the flip speeds, the
  porpoise's lean, and the hospital flip with its time.
- **Wallrides:** on or off, frontside walls, wallrides from the ground, when a ride starts, how long it lasts, gravity
  on the wall, popping off and the wheels' sound.

Everything else, including each trick's fine tuning and the per-trick switches, is in `ExpandedTricks.ini` beside the
game's exe. The game re-reads it every second, so you can edit and save while playing. Each line has a comment.

## Something wrong?

1. Run **`Mods\ExpandedTricks\pack-logs.bat`** in the game's `SessionGame\Binaries\Win64` folder.
2. It puts `ExpandedTricks-logs-<date>.zip` on your desktop (under 8 MB, so it fits in a Discord message). It holds
   the newest part of the logs. When they are longer than that, the older part goes into one or two more files
   beside it (`...-older-2.zip`, `...-older-3.zip`): keep those, and send them only if you are asked for more.
3. Send that file and say what you did and roughly when. Every log line has the time of day.

The zip holds the mod's logs and settings, UE4SS's log, SessionTweaks' log and settings if you have that mod, the
game's own settings files (your options: controls, gameplay and advanced settings, window and quality, so that
what you saw can be played again with your settings; no progress, inventory or account data), and a
short list of what is installed: your Windows version, the names of the folders in `Mods`, `mods.txt` and the path of
your game folder. That path, and the path of the game's save folder in the mod's first log, can show your Windows user
name. Nothing is sent anywhere by itself.

For a bad-looking pose, run `pack-logs.bat` soon after it happened. The mod records the skeleton of every trick you
do, and the zip carries the newest of them (about the last fifteen), so the pose can be looked at exactly as it was
on your screen. The recording is `ExpandedTricks.poses.bin` beside the logs. When it is full it is set aside as a
`.old` file, so it takes 64 MB on disk at most. `RecordPoses=0` in `ExpandedTricks.ini` switches it off.

## Uninstall

Double-click **uninstall.bat**. It removes the mod's two folders and the board's files (putting back any other mod's
files the installer had set aside as `.expandedtricks.bak`), and asks before removing your settings and logs,
and before removing UE4SS if this installer was what put it in and no other mod is left in `Mods`.

## Known limits

- Written against one game build. Other builds (Steam, game updates) run only if the start-up check passes, and even
  then without the alternate flip set and wallrides (see Requirements).
- The game's grab animations are unfinished; the mod poses the hand, arm, legs and deck on top of them. Odd poses
  happen, and the per-grab numbers in the ini are there to tune them.
- In the replay editor the mod's poses are replayed as recorded, not re-made.
- The hospital flip needs the game's experimental *Caspers*, and comes only out of a kickflip's casper, in the air.
- Wallrides from the ground are on by default (switch them off on the Wallrides page). They are not taken at benches, ledges, curbs or ramps, while you push,
  manual or powerslide, or twice at one wall.
- A monster flip needs some height (about 45 cm under the board) before it turns: an ollie that never gets that high
  stays an ollie.

## Building from source

See `source/BUILD.md`. The Lua half is `SessionGame/Binaries/Win64/Mods/ExpandedTricks/Scripts/main.lua`; the native
half is one C++ file, `source/ExpandedTricksNative/hn_main.cpp`. `source/tools/make-release.ps1` puts a release
together and signs it.

## Licence

Copyright (C) 2026 Portman2. GPLv3 (`LICENSE`), with an added permission to run it inside the game (`LICENSE-EXCEPTION.txt`). Third-party notices are in `THIRD_PARTY.md`. This mod is not made or endorsed by the game's
developers.

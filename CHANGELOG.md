# Changelog

## 1.0.0 -- first public release
Lua build 194, native v105. For Session: Skate Sim 1.0.6.42 on PC (exe stamp 69ca6d05, built 30 March 2026).

- Hippie jumps and mini hippie jumps, with body spins (180 / 360) and landings in switch.
- The game's twelve grabs switched on and posed (hand, arm, fingers, knees, feet, the deck's tilt), three two-hand
  grabs, per-grab tuning in the ini and three sliders that move every grab's hand at once.
- The no comply (the game's own unused animation, on the pressure kickflip's input), regular, goofy and switch.
- Other builds of the game (Steam's exe, game updates): the native half finds the game's functions by signature at
  start-up and runs if it finds them all, and the Lua half checks that the game's classes are laid out as on the build
  the mod was written against before it lets the native half touch them. Until now the mod ran on Epic's exe only.
  (Build 193, which first had this, did not load at all: a broken text string in main.lua. Fixed in 194.)
- Boneless and bean plant: a hand on the board through a no comply. The game catches the board for these two
  whatever the no comply's own catch setting says, and the hand lets go by itself as the board comes back under the feet.
- Rolling grabs and finger flips.
- Drop-ins from ledges, banks, ramps and vert walls.
- Jumping onto the board from on foot.
- Trick names in the game's own trick display.
- Its own settings pages in the pause menu (seven pages, every row with its unit and default); no other mod needed.
- Installer and uninstaller (`install.bat`, `uninstall.bat`); UE4SS 3.0.1 is put in when the game has no mod loader.
- Automatic updates from the mod's GitHub releases (each release signed by the author, each file checked against its
  SHA-256, applied at the next start; `AutoUpdate` 0 / 1 / 2).
- `pack-logs.bat` zips the logs for a bug report (under 8 MB).

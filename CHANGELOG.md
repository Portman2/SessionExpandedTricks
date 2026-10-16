# Changelog

## 1.0.0 -- first public release
Lua build 224, native v122. For Session: Skate Sim 1.0.6.42 on PC (exe stamp 69ca6d05, built 30 March 2026).

- Hippie jumps and mini hippie jumps, with body spins (180 / 360) and landings in switch.
- The game's twelve grabs switched on and posed (hand, arm, fingers, knees, feet, the deck's tilt), six two-hand
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
- Throwdown speed (builds 195 to 197): a slider on the General gameplay settings page, a percentage of the speed
  you were moving at when you threw the board down. The game's own throwdown is played that much faster (the
  run-up, the throw and the step onto the board) and you roll away that much faster. Standing still, nothing is
  added. 100 % = unchanged, which is how it ships. `ThrowdownRateMax` in the ini caps how much faster the throw
  is played.
- Trick names (build 208): the mod's trick names no longer stay on the screen while the replay editor is open.
- Trick names (build 196): a flip's name and a grab's name no longer end up drawn on top of each other.
- Three more two-hand grabs (build 205): with both bumpers held, each stick picks the toe side or the heel side
  for its own hand, by the same map as the one-hand grabs (stance and stick mode). Both to the toes is the
  Gorilla as before; front hand to the heels is the Truck Driver (Melon + Indy), back hand to the heels the
  Drunk Driver (Mute + Stalefish), both to the heels the Squirrel (Melon + Stalefish). The snowboard names:
  skateboarding has none for these. Both sticks have to be pushed; one stick alone, or none, stays the Gorilla
  (`DoubleBothSticks=0` makes one stick enough). Each has the full set of per-grab numbers in the ini.
- The bone (build 205): in a Gorilla, Truck Driver, Drunk Driver or Squirrel, push both sticks up after the grab
  is made and the front leg straightens, the board poked toward the nose (`Bone<Grab>` cm per grab in the ini;
  the menu's *Bone two-hand grabs* switches it off). A stick swung up from where it picked the grab no longer
  twists the body in these four grabs; swung down, it does as before. (Build 206: it now goes by the sticks as
  they are on the pad. In 205 it never came: the game reads the right stick's up and down the other way round,
  so it waited for the left stick up and the right stick pulled down.) Build 207: the board really goes as far
  as the number says (the hands' reach took about half of it back), turning the sticks half way up is enough,
  and *Two-hand grabs: bone distance* on the Grabs page adds to every grab's own number at once.
- Build 224, native v122:
  - *the Hippie Exterminator board* ships with the mod: a deck under ThankYou (in place of Bad Clouds 8.25) and its
    grip under DGK (in place of Serape), loose files under `SessionGame\Content`. install.bat puts them in (or not,
    with `-NoBoard`), setting aside another mod's files in those places; uninstall.bat takes them out and puts those
    back.
  - *the pause menu:* no Quick settings page in the mod's own pages (it stays only as SessionOpenMP's one flat
    page, MenuOwnPages=0).
  - *drop-ins:* where the board's nose would meet a ramp's face before its front wheels (a steep lip over a
    flatter face), the board is hung further out until the wheels meet it first, or else let go along the face;
    it was let go with the deck against the ramp and pushed off it or bounced into the air.
- Build 223, native v121: drop-ins --
  - *switch on the coping:* a double tap of Y now sets the board down on the coping and puts you on in switch
    (it was the old set-down behind the edge). `DropInSetSwitch=0` is the old way.
  - *the crouch* works on steep ramps (it is measured over the deck, not the world's up), no longer twists a
    thigh at the drop, and eases in and out; the riding height it starts from is learned on a level board.
  - *the arms:* the back arm goes out to the front instead of back up the ramp, and is no longer left flung back
    and snapped into place at the let-go.
- Build 222, native v120: the drop-in's crouch is a depth, not an addition: holding the crouch stick takes you
  further down instead of standing you up to crouch again. Drop-ins are written to the pose recorder.
- Build 221, native v119: drop-ins --
  - *the drop is measured properly:* the way down is traced out to 4 m, so a quarter pipe counts its full
    height (the scan alone took a point part way down the transition, about half of it);
  - *a crouch:* the hips go down and the back leans toward the drop as you tip in, by the size of the drop
    (*Drop-in: crouch*, 18 cm as it ships, and *Drop-in crouch: lowest at*), up again once you are down;
  - *the shoulder twist:* the game's own twist of the upper body, which swings the back arm behind you as the
    board tips in, is held off until you are down (*Drop-in: hold the shoulder twist*, on as it ships).
- Build 220: the drop-in's arms by the size of the drop. How far they come out is the drop's share of
  *Drop-in arms: full at a drop of* (200 cm as it ships: a 1 m drop gets half of the arms slider), and they
  come out with the way down, fully out at *Drop-in arms: fully out at* (50 % of the way down), then go down
  over 0.7 s once you are down. Both are new sliders on the Drop-ins page.
- Build 219: the drop-in's arms come up when you drop in (GO), not while you stand on the board at the edge.
- Build 218, native v118:
  - *Stutter:* a short freeze about once a second after a grab (until the next bail), worse on big custom
    maps, is gone. While one of the mod's trick names was on the books, the mod checked the game's trick
    display once a second by going through every object in the game; it now asks the display itself. A
    hippie jump, a jump onto the board, a drop-in and a throwdown no longer start with such a look either.
  - *Stutter, without SessionTweaks:* the mod looked for SessionTweaks on the game's own thread every 10
    seconds for the first two minutes of a run. That look is made in the background now, three times.
  - *Drop-ins:* your arms come up and out for balance as you tip in (from build 219: only from the GO),
    and drop again once you ride away or land. *Drop-in: arms out for balance* on the Drop-ins page, in
    degrees (40 as it ships; 0 = the game's own arms).
  - *Logs:* a frame that the mod's own work makes long is now written to both logs (`slow frame:` and
    `long frame:` lines), so a log pack shows a stutter and where it was spent.
- Build 217:
  - *Drop-ins off a plain ledge or wall:* launched straight out again. Since build 212 the floor under a
    ledge, the riser of a step below it, or a plain wall could be taken for a ramp or a vert wall, and the
    board was tipped into the floor or down the face. Ramps and vert ramps are as they were
    (`DropInPlain=0` is the old way).
- Build 216, native v117:
  - *Jumping onto the board:* build 215 lifted the whole body at the landing, which stuttered. Now only the
    feet are placed: each ankle at the height it rides at, sole flat on the deck, and the legs bend to it
    (the game's own feet dip under the deck and then bounce a foot's length over it). The head is kept
    level through the hop (`BoardHopHead`).
  - *Grabs, the head:* the two sliders now aim where you LOOK. *Head up* raises the gaze toward just under
    level and stops there; *head toward travel* turns it from where it is and stops when you look that
    way. The head stays level and over the body's middle (it was laid over in a Melon).
  - *Drop-ins:* the set-down on the coping no longer stutters at the edge. Your middle stays just short of
    the edge until the last moment, and those last steps to the board are taken at your own height
    (`DropInSetFly=0` is the old way).
- Build 215, native v116:
  - *Jumping onto the board:* a foot no longer dips through the deck to the ground as you land. The game
    blends from the standing pose, whose feet are lower than the board; the body is held up by what the
    foot lacks until that blend is over (`BoardHopFeet=0` is the old way).
  - *Grabs, the head:* the turn toward travel now goes round level and the right way (it rolled the head
    onto an ear and looked backwards); it still ships off. Both head sliders go to 90 degrees, and the
    raise is no longer held to nine tenths of the back's fold.
  - *Landings that stop you dead:* being looked into. While you are in the air the game's hold-still flag
    is let go of (`LandHoldFix`), and every landing that loses its speed is written to the log.
- Drop-ins (build 213): the set-down on the coping is the drop-in now. Y on foot with the board in your hand,
  within 45 cm of an edge (`DropInSetReach`; toes over the edge count): the board comes down on the coping,
  tail down, and you step on. Farther off, Y is the game's own throwdown: the old way, where you got on
  behind the edge and slid out to it, is gone (`DropInFar=1` in the ini has it back). A press made right
  after picking the board up waits for the board instead of being refused, and a slow walk up to the edge
  counts as standing (`DropInWalkSpeed`). The two test rows of the Drop-ins page are gone.
- Jumping onto the board (build 213, native v115): no more quarter turn for a frame as you land. The game
  turns you to the board on the jump's last frame and blends that away over an eighth of a second; the
  mod now holds your body's heading through that blend, so you land facing as you flew (`BoardHopKeep`,
  seconds; 0 = off).
- Grabs (build 213, native v115): the head. *Grabs: head up* raises it when your back is folded toward
  the board (30 degrees as it ships), so you look ahead and the head stays clear of the knees. *Grabs: head
  toward travel* is off as it ships (build 214): in this build it turns the head the wrong way. 0 and 0 =
  the head as the game has it.
- The mod switching itself off every two seconds, fixed (build 212): after some level restarts builds 210
  and 211 logged "level change (a new skater)" every 2 s and stood the native half down each time, so
  drop-ins, grabs and hops did nothing until the next map change. Build 210's rule that the skater is looked
  for twice a second at most refused the mod's own second look.
- Boned grabs go further (build 212, native v114): what held every bone was not the slider but a rule that
  the hips may not go behind the back foot (16 to 28 cm came of 45 to 73 asked). *Boned grabs: how far out*
  (Grabs page, 20 cm as it ships, 0 = as before) lets the board go that much further, until the front leg
  is straight or a hand would come off. *All grabs: bone distance* now goes to 80. A grab picked with the
  stick centred can have its board pushed out too (`GrabBoneShowStick`). Letting go of a boned grab no
  longer steps the body 8 to 15 cm in one frame.
- Jumping onto the board (build 212, native v114): the deck could turn half a turn under you at the mount
  (the game re-labelled regular as fakie inside its own mount when the loose board was moving): the board is
  stopped and its old move direction cleared first. The landing height is learned on level ground only
  (hops landed 8 to 18 cm low after riding a quarter pipe). A test, on as it ships: the turn to the riding
  direction is spread over the jump instead of made on its last frame (`BoardHopTurnHold=0` is the old way).
- Drop-ins, the set-down test (build 212, native v114): with *Set the board down at the edge (test)* on,
  *Set it ON the coping (test)* has you stand right at the edge: Y within 45 cm of it, the board comes down
  over the edge and tips tail-down as your back foot comes on, and you are put on it there with no slide
  out. Press Y once (a second tap means switch and goes the build 211 way). Off = build 211's set-down.
- Jumping onto the board (build 211, native v113):
  - *The half turn on landing.* A hop that put you on in switch snapped your body half a turn the moment
    you were on: the game turns a switch rider round itself at the mount, and the hop had not allowed for
    it. You now land facing the way you flew, and a switch hop leaves you riding switch.
    (`BoardHopSwitchFix=0` in the ini is the old way.)
  - *Your run-up is carried onto the board.* Until now the board only kept its own roll. It now rolls away
    along its length at your run-up speed times *Jumping onto the board: speed* (Hippie Jumps page, 120 %
    as it ships; 0 = the old way). *Side-on run-ups* says how much of a run-up from the side counts.
- Boned grabs (build 211, native v113): the grabbing hands stay on their spots through the whole bone.
  They used to be slid along the board past 16 cm and lifted off when the arm ran out. The back now leans
  further while a grab is boned (*Boned grabs: extra lean*, Grabs page), and what the arm still cannot
  reach is taken off the bone instead of off the hand. A test, off as it ships: *Bone moves* = 1 keeps your
  body where it is and pushes the board out toward the nose (only in airs that began with a pop).
- Drop-ins (build 211, native v113): a test, off as it ships. *Set the board down at the edge (test)* on
  the Drop-ins page skips the game's throw and plays its throwdown animation close to the edge: the board
  comes down by the coping, you step on, and only a short slide out is left.
- Controls dead on foot after stepping off (build 211): a Y press in the split second after the wheels
  leave the ground makes the game start its board pick-up with no animation, and only that animation's end
  ever ends it: on foot the jump and Y stayed dead until a session-marker teleport. The mod now sees that
  state and has the game finish the pick-up (`StepOffUnstick=0` in the ini only logs it).
- The log (build 211): the fault and level-change lines of SessionTweaks and SessionOpenMP are copied into
  ExpandedTricks.log (their own logs start again at every launch), and the map is named at every level
  change.
- A crash at a map change, fixed (build 210, native v112): two seconds into a new map the game could stop with an
  access violation inside UE4SS. The mod looked through every object the game has (UE4SS's `FindAllOf`) while
  the engine was still destroying the old map's objects on another thread. It did that once a second while a
  trick name was up, at every level change and at the first hop on a map. Now each look first asks the engine
  whether a purge is on (its own two flags, read by the native half) and waits when one is; where the flags
  cannot be read nothing is looked through for 8 s after a level change. The skater is looked for twice a
  second at most.
- Drop-ins (build 210, native v112):
  - *Stepped off the board while it was being set on the edge.* By an edge the game's own throwdown sends the
    board over the drop and the mod puts you on the board itself. The game's throwdown animation was still
    playing, and when it ended it toggled you off the board again, about a second later (half of the set-ups
    on a small quarter pipe). That toggle is now dropped while the drop-in holds you on the board, and should
    the game step you off anyway with no Y pressed, you are put back on (twice at most).
  - *A low vert wall gets less speed.* `DropInVertSpeed` and `DropInVertBoost` are what a wall
    `DropInVertRef` cm tall gets (350 in the ini). A lower wall gets less of both, as the square root of its
    height, never under half: a 2 m quarter gets about 0.78 of them. `DropInVertRef=0` gives every wall the
    same, as before.
  - A Y press on foot that nothing comes of has two more readings in the log (whether the game had you
    falling at the press, and its own on-a-grind test).
- Rotate or bone, for every grab (build 209): *Grab tweak* on the Grabs page says what moving the stick off the
  direction it picked a grab with does. 0 = rotate: your legs and the board twist (the game's own tweak, as the
  one-hand grabs have always had). 1 = bone: your body goes back over the back foot and the board is poked out
  toward the nose, by that grab's `Bone<Grab>` cm in the ini plus the menu's *All grabs: bone distance*. The
  grabs on the board's tips (Nose, Tail, Crail, Seatbelt, Cannonball, Quasimodo) have no bone and rotate either
  way. A two-hand grab bones when either stick is swung. The bone itself now goes along the board: until
  build 208 most of it pushed the hips down into the tucked board, which is why it could hardly be seen.
  (*Bone two-hand grabs* of build 205 is gone: this setting is for all of them.)
- Hippie jumps (build 209): a stick click shortly after a hippie jump no longer starts another one without a
  crouch (a crouch that was over still counted for four seconds). With the ollie animation the back foot no
  longer goes down through the board at the take-off: the body goes up by what that leg pushes down
  (`HopOllieDeck=0` in the ini leaves the animation as it is).
- Grabs on a board that has turned round (build 207): a Nose or Tail grab out of a shove-it tipped the grabbed
  end the wrong way. The tilt is now steered the other way when the board has turned round under you since
  the wheels left the ground (`GrabTurnedSense=0` in the ini switches that off).
- The hippie jump's animation (builds 205 to 207): *Hippie jumps* on the Hippie Jumps page has four settings.
  0 = off. 1 = the jump animation (stand up out of the crouch, then the in-air pose: the hop as it always was,
  and how it ships). 2 = the game's ollie animation (its pop, then its tucked knees; the board stays on the
  ground all the same). 3 = one or the other at random, jump by jump. The mini hippie jump takes the same
  animation. The ollie is the one of the stance you ride, and its own sounds (the pop) are silenced for the
  hop; `HopOllieSound=1` in the ini leaves them. (The *Ollie animation (test)* switch of build 205 is gone.)
- Diagnostics (build 204): when a Y press on foot starts no throwdown, the log says what the game's own tests for
  getting on the board read at that moment.
- Map changes (build 203): the mod no longer stops after a change of map when the mod loader has stopped running
  its game-thread work (seen after the game's window had lost the front: grabs and hippie jumps were gone on the
  new map). The log now says when the game's window is not the one in front (`window:` lines).
- Pause menu (build 198): a pause menu that comes up without the controller (drawn, but every press still goes
  to the game; seen when Start is pressed right after leaving the replay editor or jumping to the marker) is
  handed the controller back, and the log says so.
- Stick mode (builds 199 and 200): in the game's left foot / right foot stick mode LB is the left hand and RB the
  right, as the sticks are the left and the right foot. The two bumpers change places whenever your left foot is
  the back one: a regular rider riding switch, a goofy rider riding forward. In the front foot / back foot mode
  nothing changes (LB is the front hand). `GrabFollowStickMode=0` in the ini switches this off.
- Grab directions (builds 201 and 202): left and right on a grab's stick are the sides of the board, whether the
  bumper or the stick comes first (with the stick pushed first the game picks the grab itself, by its own fixed
  directions: build 202 puts that right). Push toward your toes
  for Mute, Taipan, Indy or Canadian Bacon and toward your heels for Melon, Chicken Salad, Stalefish or Roast Beef.
  For a goofy rider that is the other way round from before (the game's own map has the toe side on the right for
  everyone); a regular rider rolling forward notices no change. `GrabToeSide` in the ini: 1 = by the rider,
  0 = right always, 2 = left always.
- Trick names in the game's own trick display.
- Its own settings pages in the pause menu (seven pages, every row with its unit and default); no other mod needed.
- Installer and uninstaller (`install.bat`, `uninstall.bat`); UE4SS 3.0.1 is put in when the game has no mod loader.
- Automatic updates from the mod's GitHub releases (each release signed by the author, each file checked against its
  SHA-256, applied at the next start; `AutoUpdate` 0 / 1 / 2).
- `pack-logs.bat` (build 203) also packs the game's own settings files, so a report can be played again with the
  reporter's options, and puts the older part of long logs into up to two more zips instead of dropping it.
- `pack-logs.bat` zips the logs for a bug report (under 8 MB), with the skeleton of your newest tricks: since
  build 196 the mod records it by itself (`RecordPoses` in the ini; two files of 32 MB at most beside the logs).

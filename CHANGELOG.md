# Changelog

## 1.1.0 -- new flip tricks, wallrides and the caveman
Lua build 265, native v162. For Session: Skate Sim 1.0.6.42 on PC (exe stamp 69ca6d05, built 30 March 2026). Everything
since 1.0.0 (builds 225 to 264). A 1.0.0 install with *Automatic updates* at 2 installs it by itself at its next start.
How to do each trick: [docs/TRICKS.md](docs/TRICKS.md).

### New flip tricks: the alternate flip set
Push the back-foot stick up (the game did nothing with it) and you crouch for a second set of flip tricks. It needs
Epic's exe and the front foot / back foot or left foot / right foot stick mode, and works regular and goofy, forward and
switch.
- **Monster Flip** (front stick down): the board turns a full circle end over end under you, nose first, as fast as
  you flick. With manual catch it keeps turning until you catch it, and two turns are a Double Monster Flip. It wobbles
  and scoops a little off a perfect pinwheel.
- **Dolphin Flip** (front stick up): end over end forward, then a half flip; it lands reversed.
- **Porpoise Flip** (front stick up, leaning toward your heelflip's side): the dolphin with the half flip the other way.
- **Nightmare Flip** and **Daydream Flip** (your varial flip's or varial heelflip's scoop and flick): a 180 shove-it
  with a double kickflip or a double heelflip.
- **Kickflip Underflip** and **Heelflip Cancel Flip**: your kickflip or heelflip, then flick either stick sideways
  while the board is upside down, and it turns back from underneath and lands grip up. The flicking foot really meets
  the board's edge.
- **Shuv-it Underflip** and **Shuv-it Under Varial Flip**: the crouch's shove-it with a late sideways flick adds a
  whole flip. A quarter scoop spins 180; a half scoop spins 360 with the flip, as one varial flip. One rule in every
  stance and stick mode: the foot that shoves does the underflip.
- **The nollie set**: hold the front-foot stick down instead, and the back-foot stick does the nollie versions of all
  of them (fakie when you ride switch).
- Every one is named in the trick display in every stance, with the game's rotation names (*FS Monster Flip 360*,
  *Half Cab Dolphin Flip*, *Switch Nightmare Flip Body Varial* ...).
- The game's bone ollie still works: a stick coming up out of the game's own crouch is never the alternate crouch.

### Hospital Flip
Switch on the game's experimental *Caspers*, catch a kickflip in a casper, and in the air pull the front-foot stick
back: the board turns 180 end over end on your front foot and lands grip up, reversed, named on the trick display. The
feet tuck out of the board's way and come back for the catch. The return flip is a little dirty: it banks and scoops
sideways and settles exactly at the catch. Out of the alternate crouch's kickflip the back foot stays off the board,
over the tail. *Hospital flip: time* on the Flip Tricks page sets how slow it turns.

### Wallrides
- Fly into a wall at a shallow angle in any air on the board and you ride along it, with no button. Backside takes the
  game's own unused wallride animation; frontside is your riding pose leaned out from the wall.
- The wheels roll on the wall with the game's rolling sound for the wall's material (recorded into replays too). You
  ride down off the wall, the board rolls flat and you land turned away from it.
- Push a stick up on the wall to pop off it.
- Curved walls: a ride follows the curve.
- **Wallride from the ground** (Wallrides page, on by default): crouch as you roll into a wall at a shallow angle and the
  board wallies up onto it, nose first, into a wallride, with no ollie.
- The body on the wall: hips in their sockets, a clean bend at the waist, knees the way the hips face, the upper body
  and arms easing in and out, the board flat on the wall and no longer ringing in and out.

### Caveman
On foot with the board in your hand, jump, then press Y in the air: the board swings from your hand down under your
feet (the game moved it there in one frame), your hand holds it (Melon or Indy) with the knees up in a deep crouch, the
head looks ahead, the hand lets go before you land and your fall keeps its speed. Tap Y twice for a switch caveman.

### Legs: the shin fix
The game's animations twisted the shin above the ankle. Each shin is now turned back onto its knee-to-ankle line in
hippie jumps and mini hippie jumps, no complies, bonelesses and bean plants (regular and switch), and wallrides. It
holds through big errors and stays on for a moment after the trick, so it no longer wobbles.

### Camera
The camera no longer jolts when a 180 hippie jump lands: it follows the board's travel until the body has turned
round.

### Menus
- The settings have a **Flip Tricks** page and a **Wallrides** page, and the caveman's settings are on the Hippie
  Jumps page. The General gameplay page keeps six rows.
- The Flip Tricks and Wallrides pages keep only the core settings. Everything else is still in the ini, with your
  values kept.
- New: *Hospital flip: time*.

### Stick clicks
The game opens its missions with L3, and every hippie jump opened them. A click the mod uses (a hippie jump, a mini
hop, a jump onto the board) is now kept from the game; one it does nothing with goes on to the game.

### Crash and freeze fixes
- A rare crash inside UE4SS is much rarer: the mod no longer asks UE4SS to change its table of Lua threads several
  times a second.
- A pause menu left without the controller (after the Windows Start or Search window came in front) could not be
  closed and the game had to be ended. The menu now gets the controller back.

### Build by build
The full history of these builds, for testers:
- Build 265, native v162: the release's starting settings: Wallride from the ground is on and the Hospital Flip takes 0.4 s (`WallRideFromGround`, `AltHospitalSecs`; an ini that already has them keeps its values).
- Build 264, native v162: the Monster Flip's off-axis scoop runs through the whole rotation, not only its second half ("apply the dirtiness to the whole rotation"). Version 1.1.0: the README's trick guide, docs/TRICKS.md and this changelog rewritten for the release.
- Build 263, native v161: Hospital Flip: the return 180 scoops -- the board turns about its own up (Z) axis, its rising end swinging out toward the toes and back (`AltHospitalZScoop` 35; negative scoops toward the heels), the face tilt reversed (`AltHospitalBankSide`), still landing grip up and reversed; the front foot rides just under the board's rising end at the board's own speed instead of passing through it (`AltHospitalFootGap`). Monster Flip: its second half gets a slighter scoop about the board's Z axis, back to straight before the catch (`AltMonsterZScoop` 18; 0 = the old monster). The heelflip version of the underflip is now named Heelflip Cancel Flip (the kickflip one stays Kickflip Underflip). Fixed: a pause menu left without the controller (after Windows' Start/Search window came in front) could not be closed -- the menu gets the controller back, and the mod's own button moves do nothing while it is up.
- Build 262, native v160: shuv-it underflips follow one rule in every stance, foot and stick mode: the foot that pops the shove-it does the underflip (off the tail for regular and switch: backside = the kickflip's way, frontside = the heelflip's; off the nose for nollie and fakie: mirrored), started by the flick toward the other flip's side, rolling the way the game's own kickflip / heelflip rolls for your foot and stance -- fixing switch (the flip), nollie (the flick and the flip) and fakie (the flick). The Shuv-it Under Varial Flip's second half is a straight varial flip: the rest of the spin is paced with the flip so they finish together (`AltUnderShuvVarialSync`). Hospital Flip: only out of a kickflip casper (`AltHospitalKickOnly`); the front foot comes back toward the back foot as it lifts (`AltHospitalFootBack`); the return flip banks harder, always toward the toes (`AltHospitalToeScoop`).
- Build 261, native v159: the underflip footwork. Kickflip / heelflip underflip: from the second flick the shoe meets the board (half a centimetre off its edge) instead of stopping 3-12 cm short -- the kickflip's foot comes up under the edge it lifts, the heelflip's comes down onto the edge it pushes -- held through the strike and never into the board, the push kept smooth (`AltUnderTouch`). Shuv-it underflip and under varial flip: the back foot stays where it let go of the scoop (no push down: the board comes up to it), then rises and strikes the lifting edge from below as the flip starts, rides it, and floats back for the catch; before, the hold never held and the foot stayed 9-25 cm above the board (`AltUnderShuvStrike`).
- Build 260, native v158: a rare crash made much rarer: the game crashed inside UE4SS (22 Oct 21:40) while its table of Lua threads was being changed by another thread as the game thread read it; the mod asked UE4SS for that change several times a second (one game-thread request per queued action), and now keeps at most one request waiting (the same actions, the same order, the same moment), with a log line counting the requests.
- Build 259, native v157: an alternate casper: a casper caught from the alt crouch's kickflip / heelflip keeps the back foot off the board, hovering over the tail, through the casper and into the Hospital Flip (`AltHospitalCasperFoot`). Shuv-it underflips ridden goofy flip the right way (the game turns a flip round for goofy; the shuv-it underflip's roll now follows the stance, varials included). The camera no longer jolts when a 180 hippie jump lands: it follows the board's travel until the body has turned round, the game's own way after a powerslide (`HopCamSmooth`).
- Build 258, native v156: the shin fix no longer wobbles: it held only up to 75-90 degrees of error and let go above (the no comply's plant, the hippie jump's pop) and stopped at the end of the trick while the game's shin was still far off; now it corrects any error, rolls the shin onto the knee's hinge on big turns, and stays on for a second of riding after the trick. The Shuv-it Under Varial Flip: from the alt crouch roll the back stick round at least 135 degrees (a half scoop) and the shove-it spins 360 with the late flick (`AltUnderShuvHalf`; the game read every half scoop from the alt crouch as its plain shove-it). Menus pared: Flip Tricks 36 -> 11 rows, Wallrides 32 -> 10 (the removed settings stay in the ini), and a Hospital flip time slider. Fixed: two settings re-sent and logged every 2 s since build 254.
- Build 257, native v155: the shin fix on the no comply, the boneless and the bean plant, regular and switch: each shin bone is turned back onto its knee-to-ankle line through the pop, the plant, the hop back on and the landing, every joint where it was (`NoComplyShinFix`). The Hospital Flip's return is dirtier: the bank and the heading drift now add up on every flip instead of cancelling on half of them, x1.5 by default, the end-over-end turn a little uneven and the swells off-centre, still landing exactly grip up (`AltHospitalDirt`, 1 = build 256's); and the push that keeps the feet out of the turning board's way now really runs (it never read the board in 255/256).
- Build 256, native v154: hippie and mini hippie jumps get the wallride's shin fix: each shin bone is turned back onto its knee-to-ankle line after the legs are posed (the feet stay put), so the skin above the ankle no longer warps toward the landing (`HopShinFix`). Shuv-it underflips: a backside one is the kickflip's way and a frontside one the heelflip's way, and each starts only on its own flick (regular: front stick right for backside, left for frontside; switch and fakie the other way round, goofy mirrored); a flick the other way leaves the game's own shove-it (`AltUnderShuvPair`: 2 = the other flicks, 0 = build 255's).
- Build 255, native v153: Hospital Flip: the feet stay sole down and tuck out of the turning board's way (like the monster flip), back on it for the catch (`AltHospitalFeet`, `AltHospitalClear`), and the board banks and drifts a few degrees through the 180, settling exact at the catch (`AltHospitalWobble`, `AltHospitalDrift`). Heelflip underflip: the back foot hovers high, knee up, once the board is upside down and stomps the edge down on the second flick; kickflip underflip: the foot drops about 15% further out and down (`AltUnderFeetBig`). Shuv-it underflips are two tricks: the roll follows the shove (backside or frontside), whichever way you flick; a quarter scoop plus the flick stops the spin at 180 (Shuv-it Underflip) and a half scoop spins 360 (Shuv-it Under Varial Flip) (`AltUnderShuvShove`). Curved walls: ride-ons and ollie-ins feel their way along a curve instead of treating it as a corner, and a ride follows the curve (`WallRideCurveRadius`, `WallRideMaxTurn`). Kickflip / heelflip underflips are recorded.
- Build 254, native v152: kickflip underflip: the front foot flicks down past the board's edge from the start of the flip and waits under it, so the second flick just lifts it into the edge; heelflip underflip: the back foot does it, pushing the upside-down board's edge down (`AltUnderFeet`, 0 = build 253's legs). Shuv-it underflip: the back foot waits where the scoop left it until the board is about 150 degrees round, then rises into it, and no longer pushes down (`AltUnderShuvRise`); shuv-it underflips are now recorded. Hospital Flip: the flick is the front stick pulled BACK (`AltHospitalFlick`, 0 = up as before; up was also the game's anti casper), it now works out of an alt underflip that was waiting for its second flick, and its name is shown with our own trick line when it lands. Wallrides: the upper body and arms ease into the wall pose instead of jumping, and the release blends into the game's pose (`WallRideUpperEase`, `WallRideArmEase`, `WallRideReleaseBlend`; 0 = build 253's).
- Build 253, native v151: the Hospital Flip in the air: in a casper, flick the front stick up and the casper ends the game's way and the board turns 180 end over end, landing grip up and reversed, named on the trick display (`AltHospitalSecs` 0.24; on the ground the game's own flip out of the casper stays). The underflips' foot goes under the board: the flicking front foot for a kickflip / heelflip underflip, the back foot for a shuv-it underflip, out past the lifted edge and back on top for the catch, knee kept bent (`AltUnderLeg`). Ride-on wallrides: at the wall the board does a wallie first -- the nose pitched up to 45 degrees, the feet on it and the body leaning back over the tail -- then rolls flat onto the wall (`WallRideGroundWallie`, `WallRideGroundWallieRate`, `WallRideGroundWallieBody`); the board's own head-on slam held through a steep ride-on; and a ride-on now exits down and away like an ollie-in (the game held the board on the body's approach heading: the body is turned off the wall with it).
- Build 252, native v150: the kickflip / heelflip underflip really turns back now (the game takes a flip's direction from its rate, not its target: the second flick reverses the rate and the board rolls back upright). The shuv-it underflip also arms on the alt crouch's no-pop shove-it, and rolls the opposite way to the game's own late flip of the side you flick. A frontside ride-on from the ground takes off a little earlier, as your hand reaches the wall instead of after it hits (`WallRideGroundFrontLead` 14 cm; backside unchanged). The hospital watch logs 8 poses after a front-stick flick in a casper, and names the game's own flip-trick way out of a ridden casper.
- Build 251, native v149: new flips. Kickflip and Heelflip Underflip: from the alt crouch flick the front stick sideways for the game's own kickflip or heelflip, then flick either stick sideways again while the board is upside down and it turns back the way it came and lands grip up (`AltKickUnderflip`; nollie and fakie from the alt nollie set). Shuv-it Underflip: the alt crouch's pop shove-it, then a late sideways flick adds a whole flip (`AltShuvUnderflip`). Porpoise Flip: the dolphin's mirror -- the up flick leaning toward the heelflip side; end over end first, then a half flip the heelflip way, landing reversed (`AltPorpoise`, `AltPorpoiseLean`). Hospital flip, first step: the game's own Casper is watched and logged with the hospital flick (`AltHospital`); the flip itself comes next.
- Build 250, native v148: bone ollies work again: a stick coming up out of the game's own crouch is never taken as the alt crouch and reaches the game untouched (the alt set still starts from a centred stick, 0.1 s after a crouch). The ride-on wallride from the ground rides again: 249's lower take-off was about 60 cm/s too slow for the ride to take over (every take-off was refused and you bailed); the take-off's least push is now worked out on the arc the ride really measures.
- Build 249, native v147: the double-tap Y switch throwdown works again (since build 237 the caveman could open on a Y press on the ground and pull the board as the game threw it, so the game cancelled the throw; it now opens only while falling). Nollie Nightmare and Nollie Daydream Flips (and Fakie in switch) now happen: in the alt nollie crouch the game read the scoop backwards and took a hardflip or inward heel (`AltNollieVarial`). The alt set works from the first ride after loading in (the game keeps you in its getting-on-the-board mode after a spawn; `AltSpawnLimbo`). Wallrides: build 248's ride-in settings never reached the native half (it read 9 of 11) and now do, so the board leaves the ground lower and rolls flat onto the wall faster; an ollie-in's ride down waits for the board to lie on the wall (`WallRideDownSettle`); the shin no longer points off the line to the ankle (the warping above the ankle); the backside entry no longer thrusts the hips out and back. Caveman: the upper body leans gently toward the board while the hand holds, so the grip rests on the board (`CavemanHandLean`), and the head no longer jumps up at the mount (`CavemanHeadEase`). A test now fails any build whose native half drops a setting the Lua sends.
- Build 248, native v146: the Nollie Monster and Nollie Dolphin flip the other way end over end from the ollie ones (`AltNollieFlipWay`); the ollie monster and dolphin are unchanged. Wallrides from the ground: the deck is rolled flat onto the wall about twice as fast (`WallRideGroundFlat`) and the take-off pops up less (`WallRideGroundRise`), so the feet are flat on the wall at about half the height. The shin no longer wrings above the ankle: on the way off the wall the knee eases only a little toward the game's own (which points far to the side on a wall), ankle twist past 15 degrees goes into the knee's turn, and the legs keep their length. Caveman: the holding arm reaches again after the deeper crouch is drawn, so the elbow straightens and the hand stays on the board instead of hanging over it with the elbow bent (`CavemanHandReach`).
- Build 247, native v145: the settings menu has a Wallrides page and a Flip Tricks page (their rows moved off General, which keeps six), and the caveman's settings are on the Hippie Jumps page; the native half now holds 12 pages (8 before). Crouched into a wall, even nearly head-on, you take off as a wallride, carved along the wall the way you were heading, the way you are turning, or with your back to it (`WallRideGroundHeadOn` 90); standing it is still the game's own crash. Goofy: the monster's and dolphin's flick push was laid on the wrong feet (the back foot pushed out behind you); fixed. A dolphin that lands before its half turn is done no longer turns you 180 on the landing. Caveman: every joint of the crouch bends 12 % more (`CavemanScrunch`, `CavemanScrunchSwitch`), and the switch's one-frame drop at the mount is smoothed (`CavemanBendSmooth`). A settings line no longer repeats in the logs every 2 s.
- Build 246, native v144: the alt set's front stick is swapped: in the alt crouch pull it DOWN for the Monster Flip, push it UP for the Dolphin Flip (`AltFrontSwap`). A new alt NOLLIE set: hold the front-foot stick down, then the back-foot stick -- down a Nollie Monster, up a Nollie Dolphin, a varial flick a Nollie Nightmare or Daydream (Fakie in switch; `AltNollieSet`). The monster turns 20 % faster at every flick, so the hardest flick comes round on flat ground (`AltFlipPaceUp`). The dolphin keeps your stance and your kickflip's flick: the board goes end over end first, then a half flip about its long axis, landing reversed (`AltDolphinStyle` 2, `AltDolphinPitchEnd`, `AltDolphinRollStart`, `AltDolphinRollWay`; 1 = 245's varial dolphin). Wallrides: the head looks ahead along the wall over the leading shoulder (`WallRideHeadForward`); where the body is held off the wall the board reaches the wall by itself and its heading is trimmed along the wall (`WallRideBoardReach`). Caveman: the head looks along the travel from Y to the release (`CavemanHeadLook`, `CavemanHeadDown`), the whole crouch is deeper (`CavemanDeeper` 15 %, `CavemanDeeperSwitch` 10 %) and starts as the board comes up, and the switch's feet come round over 50 ms (`CavemanSwitchEase`).
- Build 245, native v143: the dolphin flip is the game's own varial flip turned the nollie way (from regular the game's Nollie Varial Flip, from switch its Fakie Varial Flip, with its own pop, animation, catch and feet), shown as "Dolphin Flip"; the mod no longer turns the board for it (`AltDolphinVarial`; 0 = 244's dolphin). The caveman reads the toe side from the feet (after riding switch it was read backwards: hips on the toes, knees splayed, back upright) and crouches: the back bends at least 30 degrees at the waist (`CavemanCrouch`, lean capped by `CavemanCrouchTilt` 50), the knees aim over the toes (`CavemanKneeAim`), and the hand is kept out of the body (`CavemanHandClear`). Wallrides: the backside torso keeps its length (the game also pulls spine_01 off the pelvis; it is put back with the hips), the frontside back knee sits over its own foot, and the board closes big gaps faster and is trimmed until the real deck lies flat on the wall (`WallRideBoardHold`).
- Build 244, native v142: wallrides: the game pulls both hip joints out of the pelvis in its wallride pose (12 cm frontside, about 25 cm backside); they are put back before the body is leaned, so the torso sits on the legs with a clean bend at the hips (the "broken waist"). The knees bend the way the hips face, not toward the travel (`WallRideKneeWay` 0; `WallRideKneeTurn` is no longer read), and the backside torso leans along the legs (`WallRideTorsoLeanBack` 45; `WallRideTorsoLeanBS` is no longer read). The board no longer rings in and out on the wall: the gap loop allows for the board trailing the body by about 60 ms (`WallRideGapPredict`). Caveman: the legs crouch less (`CavemanLegMin` 0.45), the holding shoulder drops toward the board when the arm is short (`CavemanShoulder`), the head keeps its look (`CavemanHeadHold`), and a switch caveman puts the feet straight onto their switch spots instead of swinging them round (`CavemanSwitchDirect`).
- Build 243, native v141: wallrides from the ground take off only while you hold the crouch as you reach the wall (`WallRideGroundCrouch`; 0 = standing as in 242, 2 = either); rolling in standing is the game's own crash, and the take-off uses up the crouch. The board's falling bail is held on the way off while the board is still against the wall. On the wall the legs lean from the ankles but the upper body stands upright (`WallRideTorsoLean`; backside `WallRideTorsoLeanBS` 20), the knees bend (`WallRideLegReach` 82, replacing `WallRideLineReach`), the backside arms hang out to the sides, and the board no longer drifts off the wall as the hips lean out. A ride now rides on down the wall, rolls flat in the air, turns `WallRideExitAngle` away and lands softer (`WallRideRideDown`); a stick pushed up pops you off early (`WallRidePopUp`). The wheels' sound on the wall is the game's own rolling sound set to the wall's material, recorded into replays (`WallRideSoundReach`). The dolphin's 180 is spread over more of the flip and a caught dolphin finishes at its own pace (`AltDolphinSpread`, `AltDolphinFinish`); the monster is unchanged. The caveman's bend is capped and eased in (`CavemanTilt`, `CavemanBendRate`, the head kept up), and it waits for a second Y before committing to a stance, so a switch caveman no longer starts regular (`CavemanTapWait`).
- Build 242, native v140: the monster and dolphin flips' board no longer twists round as it stands on end (the borrowed kickflip/heelflip animation asked the game for a board flip, and the game took the board as caught; that request is now refused). The dolphin's 180 turns about the board's own up near the upside-down point, so it keeps flipping forward and lands reversed (`AltDolphinTurn`). The feet get your double flips' pushes, the popping foot past the board's end and the other off its side (`AltFlipSteer`, 40 cm), and the body holds the flip pose until the board comes round (`AltFlipLoop`); 241's `AltFlipBackFoot` is gone. The caveman bends at the waist toward the toes (`CavemanBend`, `CavemanReach`), turns into the stance more gently (`CavemanGrabTurn`) and holds the edge clear of the front shin (`CavemanHandOut`); the switch caveman leans toward the switch toes, keeps the hand on the board through the landing and swings the passing foot round inside the hand (`CavemanSwing`). Wallrides from rolling take off with the nose at the wall and roll up it from the ground (`WallRideGroundTouch`, `WallRideGroundClose`, `WallRideGroundRoll`); shorter walls get a lower ride (`WallRideGroundPop` is now the most); the wheels touching the wall no longer bail you (`WallRideFallGuard`); the body is one straight, untwisted line from the ankles (`WallRideLine`, `WallRideLineReach`, `WallRideKneeTurn`), the board lies flat on the wall (`WallRideFlat`), and you come off turned 25 degrees from it (`WallRideExitAngle`).
- Build 241, native v139: the monster and dolphin flips no longer speed up mid-turn (a leftover check took the game's foot IK being on as a fault and hurried the board 2.5x), turn at 70 % of your kickflip's speed (`AltFlipPace`), and the back foot goes 40 cm out toward the heels while the board tumbles (`AltFlipBackFoot`; + toward the toes). The dolphin's 180 comes around the upside-down point instead of all through the flip.
- Build 240, native v138: the monster and dolphin flips' feet no longer stick to the tumbling board: while it turns, the game's foot targets are your flip animation's own foot positions (the game re-attached them to the real deck, which tumbles end over end while the animation's board rolls), back on the deck as it comes upright for the catch.
- Build 239, native v137: the monster and dolphin flips' feet are your own flips': the game plays your kickflip's (monster) or heelflip's (dolphin) animation in the air, its foot IK puts the feet, and SessionTweaks' foot steer pushes them out with the sticks you hold, as in your double flips. The mod no longer draws the legs (`AltFlipFeet`, 1; 0 = drawn as before).
- Build 238, native v136: the monster and dolphin flips' feet no longer fly over your head (a 237 slip left the leg's reach and lift unset). `CavemanRelease` (0.1 s): how long after the board comes under your feet the caveman's hand lets go.
- Build 237, native v135: the monster and dolphin flips' feet are always your four double flips (the flips you do later no longer replace them; no sideways push). The caveman is build 234/235's again (the hand stays on the board into the grab), its crouch held so no leg folds under 35 % of its length, and its window opened on the Y press itself (in 236 it opened 60-80 ms late, the board crossing in 0.12 s). The wallride's rolling sound keeps playing through the ride once the wheels touch the wall.
- Build 236, native v134:
  - *the monster flip:* the board turns low under you (it rose to your knees and clipped the legs; `AltMonsterBoardLow`, 66 cm under the
    hips), and the feet replay the whole path of your own double flips (your four of 18 Oct to begin with, then the last four you do),
    always one foot out to each end; a small sideways guard only where a foot would still meet the board (`AltMonsterGuard`).
  - *the Dolphin Flip:* from the alternate crouch, pull the front stick DOWN: the board flips forward end over end with a backside 180,
    and lands reversed like a varial. `AltDolphin`, `AltDolphinSide`.
  - *wallrides:* the body leans 45 deg away from the wall, frontside and backside, the legs reaching to the board (`WallRideLean`,
    `WallRideLeanLegs`). Riding into a wall from the ground (no ollie) can start a ride: `WallRideFromGround`, off until you switch
    it on (General page).
- Build 235, native v133: the monster flip's feet copy one of your recorded flips whole (it averaged them before, which put the feet back over the board) and a foot in the board's way moves out sideways, toward the toes or the heels, not along the board; the wallride's rolling sound always stops when the wheels leave the wall (it could stay on).
- Build 234, native v132:
  - *the alternate flip set no longer switches itself off after one caught monster flip:* its landing summary read one of
    its numbers wrongly and faulted, and a fault turned the whole set off for the session. Fixed; a fault now only pauses
    the set for a second (the third in a session turns it off).
  - *the monster flip's feet* kick out the way your own flips kick them: the mod watches the game's kickflips, heelflips
    and the rest that you do (SessionTweaks' foot steer included) and copies where the feet go; until it has seen one, the
    game's varial flip. Where a foot would be in the tumbling board's way it goes on out past the board's end: front foot
    forward, back foot back, at riding height. No more tucked, sideways feet. `AltMonsterLegs` (0 = like your flips, 1-4
    = 233's sideways splays) replaces `AltMonsterSplayStyle`; `AltMonsterLift` (0) replaces `AltMonsterTuck`.
  - *the caveman:* the hand stays on the board: as the board swings under your feet the hand moves to the grab's spot (the
    Melon or the Indy), the body crouching and leaning for it, and the grab is already on when the game puts you on the
    board (the hand no longer lets go and catches up).
  - *wallrides:* the wheels ride on the wall (they stayed 10-15 cm off it), the board is tilted further onto it (72 deg,
    from 60), and the wheels' rolling sound plays while they are on the wall. `WallRideWheelGap` (1.5) replaces
    `WallRideGap`, `WallRideDeckTilt` (72) replaces `WallRideTilt`; `WallRideSound` sets the sound's volume.
- Build 233, native v131:
  - *the caveman:* the feet stay on the board through the mount (the game's foot targets no longer swoop down from
    above), the body turns into your stance as the board comes under you, and the switch caveman (Y twice) no
    longer spins the board: the feet swing round to the switch side instead. `CavemanTurn` in the ini.
  - *the Daydream Flip:* the heelflip version of the nightmare flip -- from the alternate crouch, your varial
    heelflip's scoop and flick: a 180 shove-it with a double heelflip.
  - *the monster flip:* turns as fast as you flick (as the game's own flips do with its flick-speed setting); with
    manual catch it keeps spinning until you catch it (flick either stick as the board comes round level), and not
    catching it is a bail; two turns show as Double Monster Flip; the feet move out to the board's sides while it
    tumbles, and the spin wobbles a little off a perfect pinwheel. `AltMonsterFlick`, `AltMonsterCatch`,
    `AltMonsterSplay`, `AltMonsterWobble`, `AltMonsterDrift` in the ini.
  - *wallrides:* approaches up to 60 deg start a ride (it was 35), the board's own head-on slam is held off around a
    steep wall, the landing is turned along the way you leave (rides used to land and then bail into the wall), and
    the legs stand on the tilted board in your own stance (they folded). `WallRideMaxApproach` replaces
    `WallRideMaxAngle`; `WallRideCarveKeep`, `WallRideSlamGuard`, `WallRideExitTurn`.
- Build 232, native v130: the monster flip turns the other way (the board's nose comes up first; `AltMonsterNoseUp`, now 1).
  The caveman: the feet come down onto the board's riding spots before the game puts you on it (they hovered 30-50 cm
  over it for a moment), the grab after the mount is on the board within a few frames, and the 228 guess that drew
  the board nose-back in one case is gone (it guessed wrong).
- Build 231, native v129:
  - *the alternate flip set:* in the front foot / back foot stick mode, the back-foot stick pushed UP (which the game
    did nothing with) is a second crouch with its own tricks. Flick the front stick forward from it: a MONSTER FLIP (the
    board turns once end over end). Scoop the back stick from up toward your varial's side and flick: a NIGHTMARE FLIP
    (a 180 shove-it with a double kickflip). Anything else from it is the game's own trick. The trick names show as
    Monster Flip / Nightmare Flip (Switch ...). `AltFlips` and its settings in the ini; three rows on the General
    gameplay settings page. Not in the Legacy stick mode, not on Steam's exe yet.
  - *wallrides from an ollie on the flat:* build 229 never started one (the ollie's own board roll shut the start for
    the whole air, and the body's first touch of the wall bailed you before any ride code ran). A shallow wall ahead now
    keeps the game's impact bail off from the pop on and the ride starts on the first frame in the air; only faces within
    10 deg of plumb are ridden; every air that meets a wall without a ride says why in the log. `WallRideTopRoom` and
    `WallRideArm` in the ini.
- Build 230, native v128: *the caveman's grab* is now the carrying hand's middle grab: the Melon with the front hand
  (riding regular, the left), the Indy with the back hand (riding goofy, the left), and the hand keeps the grip it
  carries the board by on the way down. The two keys are renamed `CavemanHold` and `CavemanSquat` (the old ones had
  kept build 227's 0.2 s and 25 cm in the ini).
- Build 229, native v127: *wallrides.* Fly into a wall at a shallow angle (35 deg or less) in any air on the board and
  you ride along it for up to a second, no button; a head-on hit still bails you. The board tilts against the wall and
  the body takes the game's own unused backside wallride animation (frontside: your own pose leaned out from the
  wall). You come off when the wall ends, after the longest ride, near the ground or when too slow. Three rows on the
  General gameplay settings page (Wallrides, steepest approach, longest ride) and 16 `WallRide*` keys in the ini. Not
  on Steam's exe yet (it needs three of the game's functions that the signature scan does not find).
- Builds 227-228, native v125-v126: *the caveman, closer to the real thing:* the hand reaches for the board's tip on
  the way down (it used to keep the carry grip and let go half way, the elbow bent the wrong way), and once you are on
  the board in the air it holds the tip (the nose with the front hand, the tail with the back hand) with the knees up
  and the hips down, letting go just before the wheels come down. The board is drawn nose-back where the game is about
  to put it on that way round. `CavemanHold` (the longest hold, 0.6 s), `CavemanSquat` (40 cm) and `CavemanLetGo`
  (0.1 s before touchdown) in the ini. The trick is named Caveman.
- Build 226, native v124: *the caveman:* jump on foot with the board in your hand, then press Y in the air. The game puts
  you on the board 0.22 s after Y with no animation, the board jumping from your hand to your feet in one frame; now
  the board swings from your hand, out in front and down, to the spot under your feet in that time, the hand on it
  as far as it reaches. The game's mount also stopped your fall for a moment (you hung in the air): the fall's speed
  is given back. A double tap of Y (the game's switch) draws the board the other way round. On the Hippie Jumps page
  (*Caveman*), with `CavemanTime`, `CavemanOut`, `CavemanLift` and `CavemanKeepFall` in the ini.
- Build 225, native v123: *stick clicks and the game:* the game opens its missions with L3. Every stick click went
  to the game as well as to the mod, so each hippie jump brought up the mission viewer. Now a click the mod uses (a
  hippie jump, a mini hop, a jump onto the board, a click grab) is kept from the game, and one it does nothing with
  goes on to the game (on the board a moment later: the other stick's click may still make it a mini hop).
  `StickClickPass=0` in the ini sends every click to the game as before.

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

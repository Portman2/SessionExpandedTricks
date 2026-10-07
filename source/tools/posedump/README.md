# posedump -- see what a pose fix does

The native half can record every trick's full skeleton to a file: each pose as the game handed it over and as the mod
drew it. These tools read that file. Use them before theorising about a bad-looking pose: draw it, measure it.

| file | what |
|---|---|
| `poseview.ps1` | the viewer: contact sheets (PNG), plots, and with `-Metrics` a ranked list of events (PowerShell 5.1 + System.Drawing; the work is C# compiled by `Add-Type`) |
| `pd_list.pl` | an independent reader: `perl pd_list.pl <bin> [segment]` lists the segments, or one line per pose |
| `legpos.pl` | `<bin> <seg> <pose,pose,...>`: pelvis, hip, knee and ankle places and thigh / shin lengths, arrived and drawn |
| `mirsim.pl`, `pdlib.pl` | native v103's rule for a goofy rider's caught switch landing (a foot socket that comes back mirrored across the board is held on its own side) replayed over a recording; `pdlib.pl` is the reader and vector maths it uses |
| `tear.pl` | per segment and leg: bone lengths as % of the leg's own, the knee's way round the leg, the foot's heading against the pelvis |
| `joints.pl`, `hipreach.pl` | the hip joints' distance from their sockets; what that does to the leg's reach |
| `sock.pl`, `socksim.pl` | the game's foot sockets against the feet; the socket rule of native v100 replayed over a recording |
| `deckpose.pl`, `origin.pl`, `lag.pl` | joints, the mesh origin and the deck in the drawn deck's own frame; the deck's lag against the speed |
| `raw.pl`, `turn.pl`, `yaws.pl`, `whip.pl` | headings of hips, shoulders, feet, deck and mesh; how far each bone moves in one pose |
| `hinge.pl`, `ankle2.pl`, `ankletw.pl`, `toebend.pl` | the knee's hinge roll, the ankle's flex and twist, the toe joint |
| `kneeway.pl`, `landstep.pl`, `shinsim.pl`, `twistsim.pl` | hippie jumps: the knee's side at take-off, its steps at touchdown, replays of two knee rules |

Every Perl tool says in its first comment lines what it takes and prints. They need Perl 5 and nothing else.

## 1. The recorder

It is part of `hn_main.cpp` (`PoseDump`, `PdFill`, `PdSwitch`, `struct PdFrame`) and off by default. Switch it on with
`PoseRecorder=1` in `ExpandedTricks.ini`; the Lua half sends `HJN_Set("posedump", 1)`.

- Every pose that reaches the end of the pose pass is copied into a ring of 40. When one of the mod's windows is on
  (a hop's air or landing, a plant, a hand on the board, held feet, a grab, a trick trace), the ring and every pose
  after it make one **segment**. It ends 60 poses after the last window shut, or 600 poses after it began (the next
  segment then "goes on" from it), or when no pose came for 0.5 s (a bail).
- One write per segment, appended to `ExpandedTricks.poses.bin` beside the game's exe, with one line in
  `ExpandedTricks.native.log` (`pose dump: segment N written -- ...`).
- At 96 MB it stops and logs once: move the file away. A fault inside the recorder turns it off for the run.
- It changes nothing in the pose. Cost per pose: a copy of about 2 KB and one ray under the skater.
- What is still open when the game closes is lost.

The file grows by 0.2 to 1.3 MB per trick, so rename it between test sessions (the tools take any file name).

## 2. The file

Segments back to back, no file header. Little endian, floats IEEE 32 bit, cm, UE axes, quaternions x y z w.

**Segment header** (`hdrBytes` bytes; the next segment starts `segBytes` after this one's first byte)

| at | type | field |
|---|---|---|
| 0 | char[4] | `ETPD` |
| 4 | u16 | version = 1 |
| 6 | u16 | hdrBytes: from the magic to the first pose (= 160 + 2 * bones, rounded up to 4) |
| 8 | u32 | segBytes = hdrBytes + frames * frameBytes |
| 12 | u32 | frames |
| 16 | u16 | bones (`g_n`) |
| 18 | u16 | frameHdrBytes = 308 (to native v98) or 512 (v99+): always read it, the pose's bones begin there |
| 20 | u32 | frameBytes = frameHdrBytes + bones * 24 |
| 24 | u16 | preFrames: the index of the pose that started the segment (= the pre-roll poses in it) |
| 26 | u8 | endReason: 1 its windows shut, 2 the 600 poses, 3 a 0.5 s gap, 4 switched off, 5 another rig |
| 27 | u8 | segFlags: bit 0 = goes on from a segment that was cut at 600 |
| 28 | u32 | seq: the segment's number this run of the game (from 1) |
| 32 | u32 | flagsAny: every pose's flags OR-ed |
| 36 | u16 | modVersion (`kVersion`) |
| 38 | u16 | rigCount = 36 |
| 40 | u16[8] | SYSTEMTIME (local) of the starting pose: year, month, weekday, day, hour, minute, second, ms |
| 56 | u64 | `GetTickCount64()` of the starting pose |
| 64 | f32 x3 | deck half length, half width, centre x (`HalfLen() HalfWidth() CentreX()`) |
| 76 | f32 x2 | `g_footAnkle`, `g_footToe` (a standing foot's ankle / toe joint over the ground) |
| 84 | u32 | 0 |
| 88 | i16[36] | the rig, -1 = not there: 0 pelvis, 1-2 thigh L R, 3-4 calf L R, 5-6 foot L R, 7-8 toe L R, 9 spineN, 10-15 spine[6], 16 neck, 17 head, 18-19 upper arm L R, 20-21 forearm L R, 22-23 hand L R, 24 flipper, 25-26 foot anchor L R, 27-28 hand anchor L R, 29 chest, 30 spine1, 31 the pelvis's parent, 32-35 spare |
| 160 | i16[bones] | `g_parent` (then padding to a multiple of 4) |

**Pose** (`frameBytes` each)

| at | type | field |
|---|---|---|
| 0 | u32 | flags (below) |
| 4 | u32 | `(uint32)GetTickCount64()` (steps of 15.6 ms) |
| 8 | f64 | `NowS()` -- the QPC time in seconds; the viewer's ms come from this |
| 16 | f32 x10 | the mesh's component-to-world: q(4), p(3), s(3) |
| 56 | f32 x7 | the DRAWN deck in the mesh's space: `g_dq`(4), `g_dp`(3); identity / 0 when flag 0x100000 is off |
| 84 | f32 x2 | `FootA(anim, 0)`, `FootA(anim, 1)` |
| 92 | f32 | the ground's world z under the mesh's origin (the mesh's own z when flag 0x200000 is off) |
| 96 | f32 x3 | that ground's normal |
| 108 | f32 x7 | `g_plantD g_plantW g_hopFrac g_hopReach g_boneW g_feetHoldW g_legFixW` |
| 136 | i16 x6 | `g_plantFoot g_plantStage g_landFrames g_landTotal g_grabKind g_stCur` |
| 148 | f32[2][5][4] | rotations, [0] from `g_C` [1] from `g_Ct`: pelvis, foot L, foot R, toe L, toe R |
| 308 | f32[2][4][4] | (v99+) `q2`: the rotations of thigh L, thigh R, shin L, shin R -- [0] `g_C`, [1] `g_Ct` |
| 436 | f32[2][6] | (v99+) the anim instance's foot sockets L / R as the pose pass found them: location (3), rotation (pitch yaw roll) |
| 484 | f32[2] | (v99+) the DRAWN hip joints off their sockets, cm |
| 492 | f32[2][2] | (v99+) the hinge roll the last solve of leg L / R put into thigh, shin (deg) |
| 508 | u32 | (v99+) `more`: 1 the sockets were turned for this pose, 2 both knees' hinges known, 4 a hop's hips put back, 8 the plant foot swivels, 16 the plant foot's ankle is being brought back, 32 (v103) a foot socket was held on its own side of the deck (the recorded socket is the held one) |
| frameHdrBytes | f32[bones][3] | `g_C[i].p` -- "the game's pose" |
| frameHdrBytes + 12 * bones | f32[bones][3] | `g_Ct[i].p` -- "the mod's pose" |

Flags: `0x1` air, `0x2` land, `0x4` plant, `0x8` bone, `0x10` fhold, `0x20` phOn, `0x40` gfeet, `0x80` y180, `0x100` grab,
`0x200` tt (these ten start a segment); `0x400` calib, `0x800` **changed**, `0x1000` hold, `0x2000` held, `0x4000` guard,
`0x8000` trace, `0x10000` unstr; added by the recorder: `0x100000` deck read, `0x200000` ground found, `0x400000`
`g_riding`, `0x800000` `g_offBoard`, `0x1000000` `g_mirror`, `0x2000000` the pose **would be rejected** by PosePass's
v10 test (the recorder repeats it), `0x4000000` `g_legFix`.

Three things the layout does not say:
- **What the screen had** is `g_Ct` only on a pose with `changed` and without `rejected`; otherwise the pose as it arrived.
- **Half-turn poses** (`0x80`): PosePass turns `g_C` *in place* before `g_Ct` is copied from it, so the file's "game"
  pose is already turned. The pose as it arrived is that turn undone: with `r` = the position of bone `rig[31]` (the
  pelvis's parent, which the turn leaves where it is), every bone under it becomes `(2*r.x - p.x, 2*r.y - p.y, p.z)`.
  The viewer does this by default (`-AsRecorded` shows the file's).
- `left` / `0` is always the MESH's own left bone, mirror or not; `FootA` already goes through `AnimSlot`.

## 3. The viewer

```
powershell -File poseview.ps1 -Bin <ExpandedTricks.poses.bin> [-Segment N | -All] [-Out <dir>] [-Every K] [-Metrics] [-List]
```
Without `-Segment` / `-All` it takes the **last** segment. `-List` only lists. It may be run while the game writes.
Outputs in `-Out` (default `.\poseview_out`): `segNNN_sheet.png`, `segNNN_plots.png`, and with `-Metrics`
`segNNN_metrics.csv`, `segNNN_events.csv` plus the ranked events on the console. NNN = the segment's place in the file.

**To look at a sheet with an image reader that shrinks big pictures** (Claude's shrinks to 2000 px on the long side):
`-PageSize 2000` (pages `_p1 _p2 ...`, each legible 1:1), with `-Scale 2` for an overview or `-From 200 -To 500 -Every 1`
(ms from the start) and `-Focus legs` for a close look. The default sheet (3 px/cm, 4000 px wide) is for a viewer that zooms.

Other switches: `-Scale` px/cm, `-MaxWidth`, `-MaxHeight` (taller = more pages), `-Full` (all poses: by default the
sheet runs from 10 poses before the start to 20 after the last window shut; `-PreShow -PostShow`), `-MaxCells 160`,
`-Views side,front,top`, `-AllBones`, `-AsRecorded` (half-turn poses: the file's `g_C` instead of the pose as it
arrived), `-NoSheet -NoPlots`, and the thresholds `-JumpCm 4 -SlideCm 2 -PlantCm 3 -BonePct 3 -ExtHi 99 -ExtLo 30
-PitchDeg 60 -PitchNearCm 10 -TurnDeg 25 -Top 25`.

### The contact sheet
One column per pose (every K-th; the starting pose -- gold label -- and every event's worst pose are always there),
labelled `#index`, ms from the start, the flag letters `ALPBFHGYRT` (hop-**A**ir **L**anding-blend **P**lant **B**one-hand
**F**eet-hold pose-**H**old foot-**G**round half-turn **Y** g**R**ab trick-**T**race), then `c` (riding-learn), and
`*` written back / `=` not written (drawn = the game's) / `!` rejected; a third line names the events on that pose.
Three rows, all in the WORLD (mesh component-to-world applied, scale included):
- **SIDE**: the vertical plane through the deck's long axis as it stood at the starting pose; its +x end to the right.
- **FRONT**: the vertical plane across it, seen from the +x end (+y to the right).
- **TOP**: from above (+x right, +y up).

Each cell is centred on the mesh origin's horizontal place *at that pose* (a rolling skater stays in his cell);
heights are true world heights on one baseline per row of cells, with lines every 50 cm over that row's first ground.
Grey thin = the game's pose. Colour = what was drawn: left leg red, right leg blue, feet (ankle to toe) thick, spine and
head black, arms dark grey. Orange = the drawn deck: thick along its x axis (its measured half length, 40 if unknown),
a tick along its up and a cross bar at the +x end, its outline thin. Dashed olive = the skeleton's own board (through the
flipper bone, along its two hand anchors). Brown line over a tan fill = the ground plane (dashed where a pose had no
ground of its own). A magenta ring = an event at that joint on that pose.

### The plots
x = ms from the start; yellow = a window open; red left, blue right, **solid = drawn, dashed = the game's**; magenta
triangles / bars = events. Panels: ankle over the ground; toe joint over the ground; ankle over the deck's plane; along
the deck; across it; hip to ankle (lines at 99 % and 30 % of the leg); thigh length; shin length; foot pitch (ankle to
toe against the horizontal, - = toe down; a flat foot of this skeleton reads about -36); pelvis over the ground; pelvis
yaw (the hips' line R->L, with the deck's and the mesh's yaw); the jump series. Below: every flag as a bar.
Ground heights are against the plane through the hit under the mesh's origin, carried out to the joint with the hit's
normal: exact on flat ground and banks, wrong where the foot is over another surface (a kerb, a ledge).

### `-Metrics`: the events
Ranked by a severity that is roughly "times the threshold"; those the game's own pose shows as well are marked
`(the game's own)` and ranked low. `#` = the pose's index in the segment.
- **JUMP** (ankle, knee, pelvis): what the joint moved in one pose beyond what its last pose's speed explains --
  `|(p[i]-p[i-1]) - (p[i-1]-p[i-2]) * dt/dt'|`, in the world, about the mesh's origin (a takeoff or landing moves all
  joints alike: that is the minor `mesh jump`). Reported at its onset, as a ONE-POSE POP (back on the next pose), a STEP
  (stays) or neither; the mesh-space figure and the game's are given. A note says when the pose is one where the mod's
  edits start / stop being written or was rejected. (The raw `*_jump` series reads 2x on the pose after a pop.)
- **TURN** (pelvis, feet): the same for the recorded rotations, degrees.
- **SLIDE**: a foot whose sole is within `-PlantCm` of the ground (lower of ankle - `g_footAnkle`, toe - `g_footToe`)
  for 3+ poses: the horizontal path of its ankle and of its toe joint over those poses, in the world and in the mesh's
  space, with the game's for the same poses. It is a SLIDE when the smaller of the two world paths exceeds `-SlideCm`
  (a pivot about the toe moves only the ankle); a foot that holds in the world while the mesh rolls on is listed as minor.
- **UNDER THE DECK**: an ankle under the deck's plane (0 to 45 cm) and inside its outline. **UNDER THE GROUND**: an ankle
  below the ground; `toe under the ground`: the toe joint more than 1 cm below while the ankle is above.
- **BONE LENGTH**: thigh or shin more than `-BonePct` % off its own length (the median of the game's pose where no
  window is open). **LEG STRAIGHT / FOLDED**: hip to ankle over `-ExtHi` % / under `-ExtLo` % of thigh + shin.
- **FOOT PITCH**: beyond `-PitchDeg` while the sole is within `-PitchNearCm` of the ground.
- **REJECTED**, `not written` (g_Ct differs but `changed` is off), **BAD NUMBERS**.

The csv has one line per pose: every series of the plots for both poses (`d_` drawn, `g_` the game's; `L_` `R_`),
the jumps, the deck's yaw / pitch / roll, the mesh's place and speed, the recorded state (`plant_w`, `hop_frac`, ...)
and the world positions of ankles, knees, toes, hips and pelvis (`*_wx _wy _wz`).

## 4. Reading the numbers

- **Arrived against drawn.** A defect already in the arrived pose is the game's (or another mod's); one only in the
  drawn pose is this mod's. Most tools print both.
- **The game squeezes shins.** It takes the thigh from the animation and drags the foot to its socket on the board, so
  an arrived shin can be 30 to 100 % of its length while riding. The mod puts bones back to their own length only while
  one of its windows is on.
- **Left is the mesh's left.** `left` / `0` is always the mesh's own left bone, whether the game mirrors the pose
  (a goofy rider) or not.
- **Tearing is roll, hip joints and bone length**, not joint places: a leg can have every joint where it should be and
  still look torn because a bone is rolled about its own length. `hinge.pl` and `ankletw.pl` show that.
- **The legs' own lengths** are taken from the file itself (riding medians), so a file with only a few squeezed poses in
  it gives a wrong reference. `tear.pl` prints the reference it used; check it (thigh about 42.6, shin about 41.5 cm
  on the stock rig).
- The viewer's event thresholds are defaults, not truths: a 4 cm one-pose jump can be an ordinary kick.

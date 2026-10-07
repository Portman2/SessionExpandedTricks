# posedump -- see what a pose fix does

Three parts: a recorder inside the native half (a patch, **not applied to the game folder**), a viewer that turns its
file into pictures and numbers, and a test rig that runs the recorder without the game.

| file | what |
|---|---|
| `v94_posedump.pl` | the patch: `perl v94_posedump.pl <hn_main.cpp in> <hn_main.cpp out>` |
| `poseview.ps1` | the viewer (PowerShell 5.1 + System.Drawing; the work is C# compiled by `Add-Type`) |
| `pd_list.pl` | a second, independent reader: `perl pd_list.pl <poses.bin> [segment]` lists segments / one line per pose |
| `zs.bat`, `compile_obj.bat` | MSVC `/Zs` syntax check and full `/c /O2 /W4` compile of a scratch copy (`work\hn_main.cpp`) |
| `test\run_all.sh` | everything below in one go (`bash test/run_all.sh`): patch, syntax check, harness, viewer, truth check |
| `test\pd_harness.cpp` | compiles the recorder **as cut out of the patched copy** against stand-ins; `logic` / `cap` / `synth` |
| `test\synth.poses.bin`, `test\synth_truth.txt` | three synthetic tricks with planted defects, and what was planted |
| `test\check_truth.ps1` | 63 numbers of the viewer's csv against the planted ones |
| `NOTES.md` | working notes |

## 1. Merging the recorder

`perl v94_posedump.pl in.cpp out.cpp` makes four literal replacements, each of which must match exactly once (nothing is
written otherwise; an already patched file is refused; LF and CRLF both work). `kVersion` / `ModVersion` are not touched.
Against v93 (md5 `4850e0d8...`) all four match; the result passes `cl /Zs` and a full `/c /O2 /W4` compile with no
warning in the inserted lines. By hand it is:

1. **The recorder** (239 lines: constants, the two packed structs, globals, `PdAlloc PdBegin PdEnd PdQ PdFill PdPose
   PoseDump PdSwitch`) -- immediately before `void PosePass(void* mesh) {`.
2. **The one call in the hook** -- its own line immediately before `    if (!changed) return;` (the line after the
   `FootUnderWatch(...)` call, before the `// (v10) never hand the renderer a broken pose` comment):
   ```cpp
   PoseDump(mesh, anim, n, (air ? 0x1u : 0u) | (land ? 0x2u : 0u) | (plant ? 0x4u : 0u) | (bone ? 0x8u : 0u) | (fhold ? 0x10u : 0u) | (phOn ? 0x20u : 0u) | (gfeet ? 0x40u : 0u) | (y180 ? 0x80u : 0u) | (grab ? 0x100u : 0u) | (tt ? 0x200u : 0u) | (calib ? 0x400u : 0u) | (changed ? 0x800u : 0u) | (hold ? 0x1000u : 0u) | (held ? 0x2000u : 0u) | (guard ? 0x4000u : 0u) | (trace ? 0x8000u : 0u) | (unstr ? 0x10000u : 0u));
   ```
3. **The one `HJN_Set` key** -- anywhere in the chain (the script puts it before `"stickbank"`, away from the feet's keys):
   ```cpp
   else if (k == "posedump") PdSwitch(v != 0);
   ```
4. **`PdGround()`** (13 lines, the recorder's one ray) -- immediately before `bool PtrOk(const void* p, size_t need) {`.
   **This is a fourth edit, one more than asked for.** It cannot sit with the rest: `RayHit`, `GetWorldFn` and
   `RVA_ACTOR_GETWORLD` are defined 1100 lines after the hook, so the function that casts the ray has to be defined
   after them (the block before the hook only declares it, the way `GroundFeet` is declared at line 2346). The anchor
   is `PtrOk`'s own definition line, which is in none of PlantSoft / GroundFeet / BoneHand / HopReach / LandBlend / Hold.

No Lua change is needed (it is ON by default). `HJN_Set("posedump", 0)` stops it and writes the segment that is open;
`1` starts it again and re-reads the file's size. **For a release build set `g_pdOn = 0`** (or send it from the ini):
as delivered every player would write up to 96 MB beside the logs.

What it does at run time:
- every pose that reaches the end of `PosePass` (so: not while nothing is active and you are not riding, not during a
  bail) is copied into a ring of 40; when any of `air land plant bone fhold phOn gfeet y180 grab tt` is on, the ring and
  all poses after it are one **segment**; it ends 60 poses after the last of them went off, or 600 poses after it
  began (the next segment then "goes on" from it), or when no pose came for 0.5 s (a bail: it is written when poses
  come again), or on `HJN_Set("posedump", 0)`, or when the rig's bone count changes.
- one `WriteFile` per segment, appended to `ExpandedTricks.poses.bin` in the exe's folder (where
  `ExpandedTricks.native.log` is); the file is opened and closed for each one. One log line per segment
  (`pose dump: segment N written -- ...`), one at the first pose (`pose dump: on -- ...`).
- at 96 MB it stops and logs once: move the file away and `HJN_Set("posedump", 1)`. The same when the file cannot be
  opened or written (something else holds it without sharing, a full disk).
- cost per pose: one `DeckXf`, two `FootA`, one ray (mesh origin +60 .. -1000 cm), a copy of `bones * 24 + 308` bytes
  (1988 for the live rig's 70 bones). Memory: one allocation per bone count (`HeapAlloc`), 1.3 MB for 70 bones.
- it changes nothing: `g_dq / g_dp` are put back after its `DeckXf` (which also refreshes `g_ms` and the deck's bounds
  to the values any other call that pose gives them); `Ray` counts in `g_rays`.
- it runs in its own `__try`: a fault turns the recorder off for the run and logs; the grab arms are not touched.
- what is still open when the game is closed is lost (send `posedump 0` first if it matters).

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
| 508 | u32 | (v99+) `more`: 1 the sockets were turned for this pose, 2 both knees' hinges known, 4 a hop's hips put back, 8 the plant foot swivels |
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

## 4. What was checked, and what was not

Checked (all of it without the game, `bash test/run_all.sh` repeats it):
- the patch against v93: 4 of 4, `/Zs` clean, `/c /O2 /W4` clean; also on a copy with stand-in edits in the six
  functions others are patching, a new `HJN_Set` key beside `footheel` and a new line in the hook.
- the recorder itself, compiled from the patched copy against stand-ins with faked time: 54 checks of the state machine
  (pre-roll, post-roll, the 600 cut and "goes on", the gap, switching off -- also while the hook holds the lock --,
  another rig, no deck / no ground, nothing changed in `g_dq g_dp g_C g_Ct`, the file held open by something else, a
  fault inside leaves the caller alive),
  and the cap (stops at 95.6 MB, logs once, goes on after the file is moved and `posedump 1`).
- the layout, three ways: the C++ writer, the viewer's reader (explicit offsets) and `pd_list.pl` agree.
- the viewer on `test\synth.poses.bin`: 63 numbers of its csv against the planted values (`check_truth.ps1`), every
  planted defect in the event list, the PNGs looked at 1:1 (`-PageSize 2000`): labels legible, colours as stated.
- cut, junk-filled and empty files: warnings, a resync to the next header, no crash.

NOT checked -- there is no real pose file yet, and the game was not started:
- `PdGround` (the real ray: `Ray`, `GetWorldFn`, the world pointer) only compiles; the harness uses a plane instead.
- the real `DeckXf` / `FootA` / mesh offsets, the real rig's chains (the synthetic skeleton is the asset's tree without
  its `AMXX_D_*` bones: 72 bones with the live rig's leg / arm / spine indices, but the live rig has 70).
- the cost in the game (frame time, the hitch of a 0.3-1.3 MB write at a segment's end), and that `HJN_Set` reaches
  `PdSwitch` from Lua.
- which end of the drawn deck (+x) is the nose, the facing of the real skater in the views, and whether the events'
  default thresholds are quiet enough on real motion (4 cm jumps may be ordinary in a kick).

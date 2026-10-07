-- ============================================================================
--  EXPANDED TRICKS  --  Session: Skate Sim   (UE4SS Lua)  -- hippie jumps, grabs, drop-ins
--  Copyright (C) 2026 Portman2. GPLv3 with the linking permission in LICENSE-EXCEPTION.txt (see LICENSE).
--
--  HIPPIE JUMP: crouch with one stick, click the OTHER one (whichever stick your control mode and stance put
--    the crouch on: pulled down = the ollie crouch, pushed up = the nollie one).
--    e.g. right stick pulled down (regular/switch crouch) + L3, left stick pushed up (nollie/fakie) + R3
--  MINI HOP: click BOTH sticks together (no crouch needed): a small dip, a half-height
--    hop with the feet staying closer to the board, and a light landing.
--  During either, hold a TRIGGER to spin your body (body varial) -- it follows the game's
--  own trigger rotation. The triggers do NOT carve the board while you are in the air, and
--  the sticks do nothing until you land (no flip tricks, no ollie from letting go of the crouch).
--  What you spin is what you land:
--    near a full turn  -> clean landing (the body twists the last few degrees into line)
--    near a half turn  -> you ride away turned round (SwitchLanding: the game's own revert, kept quiet --
--                         the board jumps to its new heading once and the revert pose is not played)
--    anything between  -> you bail, like landing sideways on a real board
--  GRABS: the game's own (unfinished, switched off in the game's hidden experimental settings --
--    the mod's setup turns IsGrabsEnabled on in ExperimentalSaveSlot.sav): in the air press and
--    HOLD LB (front hand, left stick picks the grab) or RB (back hand, right stick); let go to let
--    go. The mod starts the grab (the game only would while its catch-orient is up) and adds a tuck
--    (the board comes up to the hand, knees up). ClickGrabs=1 brings back the stick-click grabs too.
--  TRICK NAMES: hippie jumps and grabs show in the game's own trick display ("180 Hippie Jump",
--    "Crail Grab"), made with the game's own text widget.
--
--  SETTINGS: ExpandedTricks.ini next to the game exe. Re-read every second -- edit and
--  save while playing; the next jump uses the new values. Missing settings are added
--  and duplicates removed automatically; your values are always kept.
--
--  HOW IT WORKS:
--   * You never leave "riding" as far as the game knows, so the board keeps rolling
--     under you at any speed. A per-frame hook raises the body mesh and drives the
--     anim blueprint's states: stand up out of the crouch, its in-air ("Street Trick
--     PreLand") pose, then its own landing with a deeper absorb.
--   * The skeleton carries its own copy of the board (bone SKXX_SkateSkel_Flipper), and
--     in ITS air mode the game pulls the real board toward it. The anim blueprint's
--     ModifyBone node on that bone holds it at ride height -- measured and corrected every
--     frame, because the in-air pose itself tucks the board up to the feet -- so roll off
--     a drop mid-hop and the board falls with you instead of flying up to your feet.
--   * If the game bails you out of a hop (you clipped something), the mod lets go at once
--     and, when you are back on the board, puts you back where the jump started.
--   * Stick clicks, triggers, bumpers and Y are read by the native half from the game's own key events
--     (NativePad=1, the default). With NativePad=0 they come from SessionTweaks.log instead, which needs in
--     SessionTweaks.ini:  CatchClickToCatch=1   CatchClickProbe=2000000000   CatchClickForceOrient=0
--
--  KEYS (keyboard testing): F11 mini hop, F12 hippie jump (no crouch check),
--        F7 read-only survey of the board's parts (logged).
--        (F6/F8/F9 belong to SessionOpenMP, F10 to the console, F1 to its menu.)
-- ============================================================================

------------------------------------------------------------------- settings
local MOD_VERSION = "1.0.0"               -- (v121) the release version (the Lua and native halves keep their own build numbers)
local S = {
    Height = 60.0,
    GameGravity   = 1,
    GravityFactor = 1.3,
    AirTime = 0.5,
    StandTime = 0.25,
    Pose          = 1,
    NeedCrouch    = 1,
    LandAbsorb    = 0.9,
    LandAbsorbTime = 1.15,
    LegReachStart = 0.8,
    LegReachMax   = 0.85,
    HippieJump    = 1,
    SpeedScale = 1.0,
    PushScale = 1.0,
    StickTurn = 1,
    NoComply      = 1,
    NoComplyInputAngle = 5,
    NoComplyExtraPop = -34.0,
    NoComplyPopForwardMin = 3,
    NoComplyPopForwardMax = 10.0,
    NoComplyPopHeightMin = 15,
    NoComplyPopHeightMax = 25,
    NoComplyStartPitchMin = 20,
    NoComplyStartPitchMax = 35.0,
    NoComplyStartPitchTime = 0.16,
    NoComplyEndPitchMax = 10,
    NoComplyEndPitchTimeMin = 0.2,
    NoComplyEndPitchTimeMax = 0.42,
    NoComplyPopNotify = 0.015,
    NoComplyAutoCatch = 1,
    NoComplyNoBail = 1,
    NoComplyFootFix = 1,
    NoComplyFootHeight = 10,
    Boneless = 1,
    GroundGrabs = 1,
    GroundGrabCrouch = 55,
    GroundGrabHips = 56.0,
    GroundGrabBack = 18,
    NoComplyPlantFlex = 85,
    GroundGrabSplay = 0.45,
    GroundGrabFrontAlong = 30.0,
    GroundGrabBackAlong = -18.0,
    GroundGrabAirCrouch = 20,
    GroundGrabLean = 55.0,
    GroundGrabBlockFlips = 0,
    GroundGrabFingerFlip = 1,
    FingerFlipHold = 0.14,
    NoComplySwitchMirror = 1,
    NoComplySwitchHold = 10,
    NoComplySwitchTurn = 1,
    NoComplySwitchPlant = 1,
    NoComplySwitchFeet = 1,
    NoComplyGoofyMirror = 1,
    NoComplySwivel = 1,
    NoComplyAnkle = 1,
    NoComplyPlant = 1,
    NoComplyPlantDrop = 45,
    NoComplyStepTime = 0.1,
    NoComplyStepLead = 60,
    NoComplyPlantBack = 0,
    NoComplyPlantClear = 22,
    NoComplyPlantForward = 0,
    NoComplyPlantStick = 1,
    NoComplyPlantTime = 0.12,
    NoComplyBackFootFlat = 1,
    NoComplyKneeKeep = 1,
    NoComplyOriginal = 0,
    BonelessExtraPop = -24.0,
    BonelessBoardPopMin = 45,
    BonelessBoardPopMax = 54,
    BonelessAutoCatch = 1,
    BonelessHandTime = 0.4,
    MiniHop       = 1,
    MiniHeight    = 45,
    MiniCrouch    = 0.25,
    MiniCrouchTime = 0.15,
    MiniFootPull  = 0.35,
    MiniLandAbsorb = 0.4,
    Sounds        = 1,
    SoundVolume = 5,
    Sound2D = 0,
    TakeoffSound  = "/Game/Audio/SoundCues/OnBoard/FlipTrick/BoardAndFoot/SCU_FootScratchBoard_Short.SCU_FootScratchBoard_Short",
    LandSound     = "/Game/Audio/SoundCues/OnBoard/FlipTrick/BoardAndFoot/SCU_FootOnBoard.SCU_FootOnBoard",
    Varial        = 1,
    VarialStyle   = 1,
    VarialRateScale = 1.5,
    VarialNeedsPress = 1,
    VarialMinRate = 25,
    VarialDegrees = 360,
    VarialInvert  = 0,
    VarialLandWindow = 40,
    SwitchLanding = 4,
    VarialBail    = 1,
    VarialSettleTime = 0.15,
    VarialLandAssist = 0.3,
    VarialForceManual = 1,
    BlockCarve    = 1,
    TrickBlock    = 1,
    StickRelease  = 0.3,
    LiftMethod    = 2,
    BailReturn    = 1,
    BailSetback   = 60,
    DropSafety    = 1,
    DebugBoardLog = 1,
    TrickNames    = 1,
    GrabStart     = 1,
    GrabLBNeutral = "Mute",
    GrabRBNeutral = "Indy",
    ClickGrabs    = 0,
    GrabHold      = 1,
    GrabLetGo = 0,
    GrabMaxTime   = 3,
    GrabMinTime   = 0.25,
    GrabCrouch    = 0,
    GrabTuckTime  = 0.12,
    GrabHandIK    = 1,
    GrabHandReach = 30,
    GrabLock      = 0,
    GrabLockMax   = 35,
    GrabTweakGate = 1,
    GrabTweakDead = 20,
    GrabTweakRamp = 40,
    GrabTweakMaxTurn = 45,
    GrabTweakInvert = 0,
    GrabKeepFirst = 1,
    GrabLog       = 1,
    GrabWait      = 0.12,
    GrabChord     = 0.07,
    DoubleClean   = 1,
    GrabRepick    = 0.35,
    NativeGrab    = 1,
    NativeGrabStrength = 1.0,
    NativeHandUp  = -4,
    NativeTweak   = 90,
    NativeTweakShare = 1.0,
    NativeLegs    = 1,
    NativeLean    = 20,
    NativePull    = 6,
    NativeFeet    = 1,
    NativeElbowOut = 0.6,
    NativeKneeAway = 0,
    NativeHandFull = 0.8,
    NativeGuard   = 1,
    NativeRevertCtl = 1,
    NativeEase    = 0.2,
    NativeHold    = 1,
    NativeTweakMode = 3,
    NativeFitGain = 0.08,
    NativeHeel    = 40,
    NativeLegSearch = 1,
    NativeNosePitch = 25,
    NativeTailPitch = 40,
    NativeMelonBack = 25,
    NativeProfileLift = 0,
    NativeTailFromNose = 1,
    NativeIndyPitch = 15,
    NativeMelonPitch = 25,
    NativeOwnSpots = 1,
    NativeDeckHalfLen = 0,
    NativeDeckHalfWidth = 0,
    NativeSpotUp = 5,
    NativeSpotIn = 3,
    NativeSpotUpEdge = 5,
    NativeMelonFwd = 6,
    NativeMelonLift = 10,
    NativeIndyLift = 8,
    NativeMelonDrop = 12,
    NativeIndyDrop = 6,
    NativeLeanTuck = 2,
    NativeFootSlide = 8,
    NativeDeckUp = 1,
    NativeHandAvoid = 1,
    GrabBlockFlips = 1,
    GrabAllAlong = 0,
    GrabAllAcross = 0,
    GrabAllUp = 0,
    GrabBlocked   = "ChickenSalad,Taipan,RoastBeef,CanadianBacon",
    DoubleGrabs   = 1,
    DoubleCannonball = "Nose+Tail",
    DoubleGorilla = "Mute+Indy",
    DoubleRocket  = "Nose+Crail",
    DoubleCannonballBase = "Indy",
    DoubleGorillaBase = "Indy",
    DoubleRocketBase = "Nose",
    NativeHandAim = 2,
    NativeCatchHold = 1,
    NativeGrabStance = 1,
    NativePad = 1,
    DevKeys = 0,
    MenuOwnPages = 1,
    NativeFingerCurl = 1,
    NativeFingerCurlRoot = 60,
    NativeFingerCurlMid = 10,
    NativeFingerCurlTip = 10,
    DropIn        = 1,
    DropInRange   = 90,
    DropInMinDrop = 25,
    DropInFace = 30.0,
    DropInStillSpeed = 0.01,
    DropInBack    = 34,
    DropInHang    = 4,
    DropInTail    = 17,
    DropInKick = 7,
    DropInPitch   = 25,
    DropInTilt    = 15,
    DropInVertDrop = 40,
    DropInVertTilt = 75.0,
    DropInVertSpeed = 1056,
    DropInVertSpin = 150,
    DropInVertBack = 250.0,
    DropInVertBoost = 1194,
    DropInSpin    = 90,
    DropInSetTime = 0.8,
    DropInAlignTime = 0.4,
    DropInTime = 0.45,
    DropInSpeed = 972,
    DropInMaxSlope = 89,
    DropInRampSlope = 20,
    DropInPush    = 1,
    DropInStart   = 65,
    DropInSounds  = 1,
    DropInSoundVolume = 1.5,
    DropInStartSound = "/Game/Audio/SoundCues/OffBoard/SCU_BoardImpactGround.SCU_BoardImpactGround",
    DropInSetSound = "/Game/Audio/SoundCues/Cinematic/SCU_BoardLittleImpact.SCU_BoardLittleImpact",
    DropInEndSound = "/Game/Audio/SoundCues/OnBoard/Ground/SCU_BoardImpact_Soft.SCU_BoardImpact_Soft",
    BoardHop      = 1,
    BoardHopRange = 250,
    BoardHopTime  = 0.45,
    BoardHopHeight = 40,
    BoardHopRideZ = 95,
    NativeBoardEase = 0.12,
    NativeEdgeRoll = 1,
    NativeArmSearch = 1,
    LandFeetFrames = 10,
    HopPlan = 0.6,
    HopLegBend = 0.92,
    HopCarry = 1,
    HopLagFix = 1,
    HopKneeToes = 1,
    HopKneeKeep = 1,
    HopKneeLand = 1,
    HopLandOwnTurn = 1,
    HopKneeRide = 1,
    TweaksLearnGuard = 1,
    LegHingeRoll = 1,
    HopHipFix = 1,
    HopShinTight = 1,
    HopFeetFree = 1,
    HopAnkleLimit = 18,
    HopCarryTurn = 1,
    AutoUpdate = 2,
    PoseRecorder = 0,
    TraceLog = 1,
    HopLock = 1,
    HopHold = 1,
    HopPlanStraight = 2,
    HopSinkFade = 0.22,
    HopLandOwn = 6,
    HopHoldOmega = 22,
    NativeFitHand = 2.0,
    NativeFitMove = 15,
    NativeHoldBleed = 0.12,
    MuteRevertSound = 1,
    GrabLeftUp        = "Nose",
    GrabLeftUpToe     = "Mute",
    GrabLeftToe       = "SeatBelt",
    GrabLeftDownToe   = "Taipan",
    GrabLeftDown      = "Tail",
    GrabLeftDownHeel  = "ChickenSalad",
    GrabLeftHeel      = "Melon",
    GrabLeftUpHeel    = "Melon",
    GrabLeftNeutral   = "Nose",
    GrabRightUp       = "Crail",
    GrabRightUpToe    = "CanadianBacon",
    GrabRightToe      = "Indy",
    GrabRightDownToe  = "Indy",
    GrabRightDown     = "Tail",
    GrabRightDownHeel = "RoastBeef",
    GrabRightHeel     = "StaleFish",
    GrabRightUpHeel   = "RoastBeef",
    GrabRightNeutral  = "Indy",
}

local SPEC = {   -- key, kind, lo, hi, comment
    { "Height",        "num", 0, 400,  "how high your body rises in the hippie jump, in cm (60 = hop, 95 = normal, 150 = big)" },
    { "GameGravity",   "num", 0, 1,    "1 = hang time comes from the game's gravity (Options > Advanced > Gravity)\n; and the jump follows a real falling arc. 0 = use AirTime below instead" },
    { "GravityFactor", "num", 0.3, 4,  "feel correction on top of the game's gravity. >1 = heavier / snappier,\n; <1 = floatier. Hang time scales with 1/sqrt(this): 1.3 -> about 12% shorter" },
    { "AirTime",       "num", 0.15, 3, "seconds in the air when GameGravity=0 (0.45 snappy .. 0.9 floaty)" },
    { "StandTime",     "num", 0, 1.5,  "seconds standing up out of the crouch before leaving the board.\n; The game's own blend out of the crouch is 0.33 -- lower = leave before fully upright" },
    { "Pose",          "num", 0, 1,    "1 = the game's in-air pose, 0 = plain standing lift" },
    { "NeedCrouch",    "num", 0, 1,    "1 = the hippie jump's stick click only works while crouched, 0 = any time" },
    { "LandAbsorb",    "num", 0, 2,    "how deep you absorb the landing. 0 = the game's light landing,\n; 1 = its full ollie-landing crouch, 2 = a big-drop squat. Try 0.7 .. 1.3" },
    { "LandAbsorbTime","num", 0, 3,    "seconds the landing absorb is held (the game holds a landing ~0.6s, then blends out)" },
    { "LegReachStart", "num", 0.5, 0.99, "point of the air time where the legs start reaching down for the board. The reach is slow at first and fastest at touchdown, so most of the stretch comes in the last few cm over the board (at 0.8: half of it with the body about 12-15 cm up).\n; Lower = they start reaching while still high; higher = later still, and faster" },
    { "LegReachMax",   "num", 0, 1,    "how far the legs reach for the board at touchdown (1 = the game's full reach)" },
    { "HippieJump",    "num", 0, 1,    "1 = the crouched hippie jump: crouch with one stick and click the other (0 = off; the mini hop has its own switch, MiniHop)" },
    { "SpeedScale",    "num", 0.5, 3,  "the skater's TOP SPEED: the game's top skateboarding speed and the speed pushing can take you to, as a multiple of the game's own (1 = the game's; 1.5 = half again as fast). A push is as strong as ever: see PushScale" },
    { "PushScale",     "num", 0.5, 3,  "how hard each PUSH is: the game's push impulse as a multiple of its own (1 = the game's)" },
    { "StickTurn",     "num", 0, 1,    "1 = the game's own: in the foot-stick control mode the left stick's sideways push banks (turns) the board; 0 = that bank is OFF -- only the triggers turn, and a stick trick is not pulled sideways" },
    { "NoComply",      "num", 0, 1,    "1 = the NO COMPLY: the game's own unused no-comply animation wired into the Pressure Kickflip slot (its input: left stick down + right stick left, regular;\n; mirrored in switch), at run time -- what the NoComplyWayBetter mod did with loose files, with its numbers as the defaults below. 0 = the game's pressure kickflip" },
    { "NoComplyInputAngle", "num", 0, 90, "no comply: how exactly the sticks must match its input, degrees (the mod used 5; the game's own tricks use 85)" },
    { "NoComplyExtraPop", "num", -90, 45, "no comply: extra pop height, cm (AdditionalPopHeightMax). The game's pop is (101 + this) x 1.2: +9 (the old mod's) = 132, which lifted the skater 104 cm -- 'four feet in the air, it should only be two'; -46 = half of that. The pressure kickflip's own: -20" },
    { "NoComplyPopForwardMin", "num", -40, 40, "no comply: the board's forward push at the pop, least, cm (3)" },
    { "NoComplyPopForwardMax", "num", -40, 40, "no comply: ...most, cm (13)" },
    { "NoComplyPopHeightMin", "num", -45, 60, "no comply: the board's extra height at the pop, least, cm (15; the pressure kickflip: -20)" },
    { "NoComplyPopHeightMax", "num", -45, 60, "no comply: ...most, cm (25)" },
    { "NoComplyStartPitchMin", "num", -90, 90, "no comply: the board's nose-up pitch as it is scooped, least, degrees (20)" },
    { "NoComplyStartPitchMax", "num", -90, 90, "no comply: ...most, degrees (the old mod's 85 stood the board up to 65 deg, the back foot far off the tail; 40 now)" },
    { "NoComplyStartPitchTime", "num", 0, 1, "no comply: seconds into the trick the scoop pitch is reached (0.16)" },
    { "NoComplyEndPitchMax", "num", -45, 45, "no comply: the board's pitch as it comes down to be caught, degrees (10)" },
    { "NoComplyEndPitchTimeMin", "num", 0, 1.5, "no comply: seconds into the trick the board starts levelling (0.2)" },
    { "NoComplyEndPitchTimeMax", "num", 0, 1.5, "no comply: ...and is level for the catch (0.42)" },
    { "NoComplyPopNotify", "num", -0.2, 0.3, "no comply (the ini only; AN EXPERIMENT -- 0.015 is what the mod has always written): seconds added to the moment the BOARD pops in this trick. The game throws the SKATER up at the flick and pops the board later: 0.133 to 0.2 s by its trick database, plus what the trick itself adds (this number at most; 0 at least). In the traces the board still lies flat on the ground 0.15 s in, with the skater already 38 cm up and the back leg at full stretch down to it. Under 0 = the board pops that much EARLIER, at least and at most (the game's own nollie 360 shove-it has -0.06): it tops out earlier, so the planted foot leaves the ground earlier and the body is held down for it less. The no comply clip itself has the board off the ground at about 0.2 s and the planted foot lifting at 0.27 s. Not tried in the game yet" },
    { "NoComplyAutoCatch", "num", 0, 1, "no comply: 1 = the game catches the board for you (the mod's choice), 0 = you catch" },
    { "NoComplyNoBail", "num", 0, 1, "no comply: 1 = the planted foot cannot bail you (the game bails you for ANY hit on a leg while it counts you as in the air; from the trick being taken until you land that check is passed over), 0 = the game's own" },
    { "NoComplyFootFix", "num", 0, 1, "no comply: 1 = the planted foot is kept ON the ground (the animation plants it lower than the ground you roll on: each frame the foot is traced onto the world and lifted to NoComplyFootHeight over it), 0 = the animation's own" },
    { "NoComplyFootHeight", "num", 0, 30, "no comply: how high the planted foot's ANKLE is kept over the ground, cm (the ankle sits about 10 cm over the sole)" },
    { "Boneless",      "num", 0, 1,    "1 = the BONELESS, as it is done: a hand already on the board (GroundGrabs: RB = the Indy hand, LB = the Mute hand -- or pressed in the trick's first fifth of a second) stays on it through a no comply's pop and lets go as the board comes back under the feet (BonelessHandTime); the game catches the board (BonelessAutoCatch). Only the arm and the crouch are posed, the game's grab is not used, and the bumpers are kept from the game for the trick. The game's own line then reads 'Boneless' (and 'FS Boneless' ... with a turn)" },
    { "GroundGrabs",   "num", 0, 1,    "1 = GRABS WHILE ROLLING: on the board, on the ground, hold RB and the back hand takes the toe edge between your feet (the Indy), hold LB and the front hand takes it by the front foot (the Mute); you crouch as far as it takes (GroundGrabCrouch at most). The hand stays on while you hold the bumper -- into an ollie, a drop, a no comply (the boneless) and the landing. Let go = stand up. (A bumper first pressed in the air is the game's own grab, as before)" },
    { "GroundGrabCrouch", "num", 0, 70, "grabs while rolling: the MOST the hips may come down, cm. (They go down to GroundGrabHips over the board; this is only the limit)" },
    { "GroundGrabHips", "num", 25, 80, "grabs while rolling: THE SQUAT -- the height the hips go down to, cm over the board. 46 is the game's own Indy grab (its hips are 44-48 over the board). A height, not an amount: crouching yourself adds nothing on top. Lower = a deeper squat and a straighter back, higher = more of the reach is left to the back" },
    { "GroundGrabBack", "num", 0, 35, "grabs while rolling: how far BACK from the grabbed edge the hips sit in the full squat, cm. More = the shins stand up and the thighs lie flat (the knee nearer a right angle: straight down over the feet 'the knees were too close to the ground'), and the back leans further forward to reach" },
    { "NoComplyPlantFlex", "num", 0, 120, "boneless / bean plant (a no comply with a hand on the board): the plant foot's HEEL COMES UP when its ankle would have to bend further than this -- the angle from the shin to the foot, degrees (riding in a crouch is 93, a no comply's standing foot 100-115; with the hips down for the hand it was 67-84: the foot folded up against the shin, 'fixed leg warping'). The foot rolls onto its ball about the toes, which stay where they stand. 85 = the heel up to 20 degrees; 90 = up to 25 (a softer ankle, a higher heel); smaller = the foot stays flat longer; 0 = off, flat whatever the leg does (native v95). A no comply without a hand never uses it" },
    { "GroundGrabSplay", "num", 0, 1.5, "grabs while rolling: how far the knees part along the board in the squat (0.45 = about 25 degrees each): room for the arm between them" },
    { "GroundGrabFrontAlong", "num", -30, 30, "grabs while rolling: the FRONT hand's (LB) place along the board, cm from the Mute grab's own spot: + toward the front foot, - toward the back foot. (-12: the spot by the front foot had the arm going through the front leg)" },
    { "GroundGrabBackAlong", "num", -30, 30, "grabs while rolling: the BACK hand's (RB) place along the board, cm from the Indy grab's own spot: + toward the front foot, - toward the back foot" },
    { "GroundGrabAirCrouch", "num", 0, 70, "...and the most they may come down IN THE AIR (an ollie, a no comply / boneless with the hand on), cm. Less than on the ground: in the air the hips dragged down to the board read as a jump that 'doesn't pop that high'" },
    { "GroundGrabLean", "num", 0, 85, "grabs while rolling: the MOST the back may bend toward the board, degrees. It bends only as far as the arm still needs once the hips are down, and the bend is shared by the hips and every joint of the spine -- a round back, not a fold at the waist (55 at one joint was 'bent almost in half')" },
    { "GroundGrabBlockFlips", "num", 0, 2, "flip tricks with a hand on the board: 0 = ALL flips can be flicked out of a rolling grab (the finger flip, GroundGrabFingerFlip), 1 = ONLY THE PRESSURE FLIPS (they do not flick: they make the best finger flips) -- kickflips, heelflips, shuvits are blocked, 2 = NO flips. The no comply (the boneless) and the low-pop ollie always work" },
    { "GroundGrabFingerFlip", "num", 0, 1, "1 = THE FINGER FLIP: flick a flip trick with a hand on the board and the hand LETS GO as the board leaves the ground -- it reads as the hand flipping the board. (The same when a late flip comes out of a grab carried into an ollie.) You grab again by letting the bumper go and pressing it again. 0 = the hand stays on the flipping board for as long as the bumper is held" },
    { "FingerFlipHold", "num", 0, 0.5, "finger flip: seconds the hand stays on the board AFTER THE BOARD HAS LEFT THE GROUND (its deck 4 cm up from where it rode); it then eases off over a few frames. (v160 counted from the game's 'in the air', which starts with the flick, 0.1-0.15 s before the board moves: the hand let go 'as soon as the input was done'.) More = the hand follows the turning board longer" },
    { "NoComplySwitchMirror", "num", 0, 1, "1 = a SWITCH no comply plants the LEADING foot: from the pop to the landing the GAME is given the other stance (the way it draws a rider of that stance -- animation, feet, lean, all its own), then yours again. 0 = the game's own: the same foot as riding normally (the trailing one in switch)" },
    { "NoComplySwitchHold", "num", 0, 40, "SWITCH no comply ridden in the other stance (NoComplySwitchMirror=1): for how many poses (1/60 s each) after each of its two stance swaps the hips keep their place ACROSS the board. After a swap the game itself fades from the old stance's pose to the new one over about 16 poses, and for that long its body stands up to 50 cm on the wrong side of the board; the mod keeps the whole body for 4 poses and blends back over 5 -- and then, for this many more, keeps only the hips' place across the board (the feet stay where they are). 10 = until the game's fade is done. 0 = native v95: the hips swing 20 cm toward the board and back out after each swap" },
    { "NoComplySwitchTurn", "num", 0, 1, "SWITCH no comply / boneless / bean plant ridden in the other stance: where the half turn that stance needs comes from. 1 = the game's own half turn of the body is switched off in its anim graph for the trick (v182; riding regular): nothing is turned, so the game's replay has no jump in it (with the mesh turned it blended one frame of a body spun about its own axis at each of the trick's two stance swaps). 0 = the mesh is turned half round for the trick (v161-v180; always so for a rider whose own stance is goofy)" },
    { "NoComplyGoofyMirror", "num", 0, 1, "a GOOFY rider's switch no comply / boneless / bean plant: 1 = the other stance's pose comes out of the game's own anim graph with its half turn kept -- the graph's mirror is switched off for the trick (its mirror table is taken away and put back), the stance itself is not swapped, nothing is turned afterwards (v189). 0 = the stance swap with the mesh turned half round, the feet pinned (v182)" },
    { "NoComplySwitchFeet", "num", 0, 1, "SWITCH no comply / boneless / bean plant ridden in the other stance: who places the feet. 1 = the GAME does, as on the regular side: its foot sockets are turned half round with the body for the trick, its foot IK stays on, and the plant is the regular side's own (native v99; riding regular; it needs NoComplySwitchTurn=1). 0 = the game's foot IK is off there and the mod holds the feet on their riding spots (v162-v182: on a pitched board under a bent-over body the legs came out scrambled)" },
    { "NoComplySwivel", "num", 0, 1,   "the PLANT FOOT TURNS WITH YOU while it stands on the ground: the share of the hips' turn its heading follows, about the ball of the foot (1 = all of it, 0 = it keeps the heading it came down with, v94-v98: in a 180 no comply the leg was wrung between a trunk that turned and a foot that did not)" },
    { "NoComplyAnkle", "num", 0, 1,    "the plant foot's way back onto the board: 1 = its turn is blended IN ITS ANKLE (against its own shin, to the game's foot against the game's shin; native v99, it needs LegHingeRoll=1). 0 = blended in the world (v94-v98: the ankle was 50-150 deg round on the last two poses of the way back)" },
    { "NoComplySwitchPlant", "num", 0, 2, "SWITCH plants ridden in the other stance: which plant they get. 0 = the pinned one for all three (v163-v180). 1 = the switch BONELESS and BEAN PLANT get the regular side's own plant (the soft plant: the step off, the stuck foot, the heel up under low hips, the way back heel first -- native v97; it needs NoComplySwitchTurn=1), the plain switch no comply keeps the pinned one. 2 = all three get the regular side's" },
    { "NoComplyPlant", "num", 0, 2, "the PLANT FOOT STAYS DOWN (the game lifts the skater 60-75 cm from the instant a no comply pops, so the animation's planted foot hangs in the air). 1 = THE SOFT PLANT: nothing is pinned -- the whole body is let down by as far as that foot hangs over the ground (NoComplyPlantDrop at most), the back foot kept on the deck, and let up again when the board is at its top: the animation, as fluid as with this off, with the foot on the ground. 2 = the pinned plant of before (the foot held at one spot, the step up and over, both feet held to their places on the board). 0 = the animation as it is" },
    { "NoComplyPlantDrop", "num", 0, 90, "plant foot: the most the hips are kept down so the planted leg still reaches the ground, cm. More = the foot stays planted longer (45: about 0.3 s, until the board stands up) and the push-off is a bigger jump" },
    { "NoComplyStepTime", "num", 0.04, 0.4, "plant foot: seconds it takes from the ground to its place on the board, once the board is at its top. It goes UP first (the first 60 % of the time, beside the board), then OVER onto its spot" },
    { "NoComplyStepLead", "num", -200, 600, "plant foot: it leaves the ground when the board's rise, having been fast, has slowed to this, cm/s. 0 = exactly at the board's top, more = a little before it (60: about 0.02 s before), less than 0 = after it" },
    { "NoComplyPlantStick", "num", 0, 1, "plant foot (no comply, boneless, bean plant): 1 = it STICKS to the ground where it comes down while you roll on, and leaves when the leg runs out (native v95). 0 = it stands at a fixed place beside you, which slides it along the ground at your speed (v94). Both plants read this since native v96: the soft one (NoComplyPlant=1 in your own stance) and the pinned one (a SWITCH no comply ridden in the other stance, NoComplySwitchMirror=1, and NoComplyPlant=2)" },
    { "NoComplyBackFootFlat", "num", 0, 1, "back foot (no comply, boneless, bean plant in your own stance): 1 = its sole lies flat on the board while the other foot is planted, as it does riding (native v96). The game tips it 60-75 deg off the board there -- its clip stands that foot level on the ground while the clip's board levers up under it, and the real board never pitches that far. 0 = the game's own foot (v95); between = that share of the tilt taken out. The soft plant only: a SWITCH no comply ridden in the other stance stands the back foot on its riding spot already" },
    { "NoComplyKneeKeep", "num", 0, 1, "back leg (no comply): 1 = where the game hands in that leg with its knee on the line from hip to ankle (dead straight, or its shin squeezed to a few cm -- the first no comply of 4 Oct 23:59), the knee keeps the side it was drawn on the pose before instead of taking it from that pose (native v96). 0 = v95: the knee's side is always the pose's own" },
    { "NoComplyPlantTime", "num", 0, 1, "plant foot: the LONGEST it stands on the ground, seconds, counted from the moment it is down. Smaller = it leaves sooner (this is the setting for 'the foot comes back late'; NoComplyStepTime is only how long the way back takes and cannot go under 0.04). 0 = no limit: with NoComplyPlantStick 0 it stands until the board is at its top, about 0.28 s (v94); with NoComplyPlantStick 1 until the leg runs out, the hips pulled down by up to NoComplyPlantDrop first. Both plants since native v96, as NoComplyPlantStick" },
    { "NoComplyPlantBack", "num", 0, 1, "plant foot: how much of the animation's own movement of the planted foot is kept. 0 = the foot stays exactly where it went down, beside the board (it 'was sliding along the ground'), 1 = the animation's: 40 cm back along the board, 13 cm sideways" },
    { "NoComplyPlantForward", "num", -100, 40, "plant foot (NoComplyPlant=1, no hand on the board): it goes down this many cm AHEAD of where it rides on the board (toward the nose for the leading foot) and stays there, beside the board, until it steps back on -- it does not travel back along the ground and forward again. 15 = about where it comes back onto the board, so the step is straight up. 0 = beside its riding spot. -100 = off: the animation's own track (it drifts 25-35 cm back). NoComplyPlantBack mixes the animation's movement back in" },
    { "NoComplyPlantClear", "num", 0, 40, "plant foot: it goes down at least this far from the board's centre line, cm (the board is 20 wide): beside the deck, so it can lift straight up past the edge" },
    { "NoComplyOriginal", "num", 0, 1, "1 = the no comply AS THE GAME ITSELF PLAYS IT, to compare with: for the whole trick nothing of the mod touches the pose -- no planted foot, no body let down, no foot lifted onto the ground, and a switch one is not ridden in the other stance. (The planted foot still cannot bail you, a hand on the board still makes it a boneless, and the trick is still traced in the native log: its 'anim' and 'drawn' columns then read the same.) 0 = the mod's planted foot. Read every frame: no restart needed" },
    { "BonelessExtraPop", "num", -90, 45, "the BONELESS's own pop height (the no comply's NoComplyExtraPop while a hand is on the board). The game's pop is (101 + this) x 1.2: +3 = 125, a third more than v164's -24 ('it's not getting very high ... like 35 % more': the body is held low over the board for the hand, so the same pop reads lower)" },
    { "BonelessAutoCatch", "num", 0, 1, "the BONELESS and BEAN PLANT: 1 = with a hand on the board the game always catches the board for you (the catch starts about 0.37 s after the pop, the board is back under the feet at about half a second), whatever NoComplyAutoCatch says. 0 = NoComplyAutoCatch decides. With the boneless's board pop (BonelessBoardPopMin..Max) a board nobody catches stays at hip height to the landing and the body is folded onto it" },
    { "BonelessHandTime", "num", 0, 3, "the BONELESS and BEAN PLANT: the hand lets go of the board in the air this many seconds after the trick began, even with the bumper still held, and sooner (from 0.25 s) when a stick is pushed to catch. The bumper has to be let go before a new grab, and a bumper pressed later than 0.2 s before this time puts no hand on. 0 = the hand stays on for as long as the bumper is held" },
    { "BonelessBoardPopMin", "num", -45, 120, "the BONELESS: cm the BOARD rises at the pop, least (the no comply's NoComplyPopHeightMin while a hand is on the board). The no comply has 15..25: the board peaks about 55 cm over the ground whatever the body does, 25-30 cm BELOW where it rides under you -- so with a hand on it the whole body was held down to it, hips 50 cm over a low board and the back bent 45 deg ('slouched the whole time'). Higher = the board comes up to the body: the back leg folds, the back straightens, he stands up on the planted leg" },
    { "BonelessBoardPopMax", "num", -45, 120, "the BONELESS: ...most, cm (the no comply's NoComplyPopHeightMax while a hand is on the board)" },
    { "MiniHop",       "num", 0, 1,    "1 = clicking BOTH sticks together does a mini hop (no crouch needed)" },
    { "MiniHeight",    "num", 0, 200,  "how high the mini hop goes, in cm" },
    { "MiniCrouch",    "num", 0, 1,    "how deep the mini hop dips before it springs up (1 = a full ~45 cm crouch)" },
    { "MiniCrouchTime","num", 0.05, 0.6, "seconds the mini hop takes to dip before leaving the board" },
    { "MiniFootPull",  "num", 0, 1,    "how much the feet stay down toward the board during the mini hop\n; (0 = the full in-air tuck, 1 = feet glued to the board)" },
    { "MiniLandAbsorb","num", 0, 2,    "landing absorb for the mini hop (see LandAbsorb)" },
    { "Sounds",        "num", 0, 1,    "1 = play a take-off and a landing sound" },
    { "SoundVolume",   "num", 0, 8,    "volume of both sounds. 1 = the sound's authored level; values above 1 boost it" },
    { "Sound2D",       "num", 0, 1,    "1 = play the sounds straight to your speakers (louder, no distance fade)\n; 0 = play them in the world at the skater (quieter, fades with camera distance)" },
    { "TakeoffSound",  "str", 0, 0,    "sound when your feet leave the board (any /Game/... SoundCue path)" },
    { "LandSound",     "str", 0, 0,    "sound when your feet land back on the board" },
    { "Varial",        "num", 0, 1,    "1 = hold a trigger during the jump to spin your body (a body varial)" },
    { "VarialStyle",   "num", 0, 1,    "1 = follow the game's own trigger rotation (rate, easing, release to stop)\n; 0 = a fixed spin of VarialDegrees started by a trigger press" },
    { "VarialRateScale","num", 0, 5,   "multiplier on the spin rate -- set it to match your Body Rotation Rate slider\n; (Options > Advanced). The mod also tries to read the slider itself; see the log" },
    { "VarialNeedsPress","num", 0, 1,  "1 = the hop only spins from a trigger pressed for it (from just before the click on); a trigger you were already holding to carve does not spin you. 0 = any trigger rotation spins" },
    { "VarialMinRate", "num", 0, 200,  "spin rates below this (deg/s) are ignored -- a light touch on a trigger does not turn you" },
    { "VarialDegrees", "num", 0, 1080, "fixed spin amount, used when VarialStyle=0 or in the pinned rotation modes" },
    { "VarialInvert",  "num", 0, 1,    "1 = swap which trigger spins which way" },
    { "VarialLandWindow","num", 5, 85, "how many degrees off you can land and still ride away. Within this of a full\n; turn = clean, within this of a half turn = a switch landing (SwitchLanding). Anything else = bail" },
    { "SwitchLanding", "num", 0, 4,    "landing a half turn (a 180 body varial):\n; 4 = DECK STAYS PUT (v73): the game is told the deck is now reversed under you -- the same state a pop\n;     shove-it leaves -- so you ride away fakie/switch with the board exactly as it was (graphic and shape\n;     unchanged), no revert, no spin, no sound. Falls back to 2 if the native half can't do it that frame\n; 2 = QUIET REVERT: the game's own revert (so the game knows you are turned round -- switch/fakie, your own\n;     stance), with none of it showing: the deck jumps to its new heading once (a near-symmetric deck changing\n;     ends looks the same) and is held there, the revert pose is not played, and your body is held still\n; 1 = the game's revert with the board swing showing\n; 3 = stance swap (v63): the game's stance changes regular <-> goofy until the next half turn\n; 0 = a half turn is a bail (if VarialBail=1)" },
    { "VarialBail",    "num", 0, 1,    "1 = landing outside the windows makes you bail (the game's own bail)\n; 0 = the body is twisted back to the nearest full turn instead" },
    { "VarialSettleTime","num", 0, 1,  "seconds after touchdown for the body to twist the leftover degrees into line with the board" },
    { "VarialLandAssist","num", 0, 0.5, "part of the air time (at the end) where the spin is steered toward the landing it is\n; closest to. 0 = no help: exactly what you spin is what you land" },
    { "VarialForceManual","num", 0, 1, "1 = the game's spin mode is set to Manual for a hippie jump (its Pressure, Speed and Time modes spin you a full turn by themselves) and put back when you land" },
    { "BlockCarve",    "num", 0, 1,    "1 = during the jump the triggers only spin your body; the board keeps rolling straight\n; instead of carving/banking on the ground" },
    { "TrickBlock",    "num", 0, 1,    "1 = once a hop starts, the game stops seeing your sticks until you land: no flip tricks\n; mid-jump, and letting go of the crouch stick cannot fire an ollie (the triggers still spin you)" },
    { "StickRelease",  "num", 0, 1,    "seconds the mod takes to bring the crouch stick back to centre for the game when a hippie\n; jump starts. Slow and smooth = the game sees you stand up, not an ollie flick" },
    { "LiftMethod",    "num", 0, 2,    "how the body is lifted. 2 = whole mesh, with the skeleton's board bone held down, so the\n; point the game pulls the board toward in ITS air stays at your feet: off a drop the board\n; falls with you instead of flying up. 1 = experimental: lift only the body's bones.\n; 0 = whole mesh, nothing held down (old; off a drop DropSafety hands back)" },
    { "BailReturn",    "num", 0, 1,    "1 = if you bail during a hop (or right after it), once you are back on the board you\n; are put back where the jump started -- the game's own reset can land you inside what you hit" },
    { "BailSetback",   "num", 0, 500,  "extra distance, in cm, to set you back behind the jump's starting point after such a bail" },
    { "DropSafety",    "num", 0, 1,    "1 = if the GAME pops a real ollie under you mid-jump (or goes airborne with LiftMethod=0),\n; hand control back to the game (lift fades, its own air + landing take over)" },
    { "DebugBoardLog", "num", 0, 1,    "1 = log movement-state changes and body/board heights during each jump to ExpandedTricks.log" },
    { "TrickNames",    "num", 0, 1,    "1 = hippie jumps and grabs show up in the game's own trick display (\"180 Hippie Jump\", \"Crail Grab\")\n; -- the game's own text line, stacking and fading with its other trick names. 0 = off" },
    { "GrabStart",     "num", 0, 1,    "GRABS are the game's own. 1 = press and HOLD LB or RB in the air to grab (let go to let go):\n; LB = front hand, the LEFT stick's direction picks it: up Nose, right Mute, left Melon, down-right Taipan,\n;      down-left Chicken Salad, down Seatbelt (right = your toe side riding regular)\n; RB = back hand, the RIGHT stick (the game reads its up/down the other way round): pulled DOWN Crail,\n;      down-right Canadian Bacon, down-left Roast Beef, right Indy, left Stalefish, pushed UP Tail\n; This is the game's own direction map; the mod starts the grab because the game would only while its\n; catch-orient is up. Needs IsGrabsEnabled in the game's ExperimentalSaveSlot.sav (see the log). 0 = off" },
    { "GrabLBNeutral", "str", 0, 0,    "the grab LB does with the left stick centred (a grab name, see GrabLeftUp below)" },
    { "GrabRBNeutral", "str", 0, 0,    "the grab RB does with the right stick centred" },
    { "ClickGrabs",    "num", 0, 1,    "1 = ALSO the mod's older stick-CLICK grabs: push a stick and click it (left = front hand, right = back\n; hand; the Grab... table below picks the grab). 0 = off" },
    { "GrabHold",      "num", 0, 1,    "1 = the grab lasts while you keep the stick pushed; let the stick go and you let go of the board.\n; 0 = the grab lasts until you are about to land (or click the same stick again)" },
    { "GrabLetGo",     "num", 0, 1,    "1 = you let go by yourself when the game says you are about to land.\n; 0 = you hold on as long as you like -- still holding the board when the wheels touch down = a bail" },
    { "GrabMaxTime",   "num", 0.2, 10, "longest a grab is held, in seconds" },
    { "GrabMinTime",   "num", 0, 2,    "a grab is held at least this long (seconds) before the landing can make you let go" },
    { "GrabCrouch",    "num", -40, 60, "extra crouch on top of the game's grab pose, in cm: + = board (and knees) further up,\n; - = board lower / legs longer (the game's pose alone is already tight). 0 = the game's pose" },
    { "GrabTuckTime",  "num", 0, 1,    "seconds to ease the grab adjustments in (and back out)" },
    { "GrabHandIK",    "num", 0, 1,    "1 = help the game's hand IK: the game already aims your LEFT hand (front hand riding forward, back\n; hand riding switch) at the board's hand anchor, but the arm stops short -- the mod keeps pushing the target\n; past the anchor until the hand gets there (up to GrabHandReach). The right hand has no IK in the game's rig" },
    { "GrabHandReach", "num", 0, 80,   "most the left-hand target is pushed past the board anchor, in cm" },
    { "GrabLock",      "num", 0, 1,    "1 = LOCK the grabbing hand to the board: the board is brought to the hand (either hand), closing\n; whatever gap the pose and the hand IK leave -- measured to the game's own grab point on the deck you see.\n; The feet follow the board. 0 = the pose (and the left-hand IK) only" },
    { "GrabLockMax",   "num", 0, 80,   "most the board may be moved to meet the hand, in cm (a bigger gap is left open)" },
    { "GrabTweakGate",  "num", 0, 1,    "1 = the game's grab TWEAK (your lower half turned by the stick) is held off while the stick stays where it picked the grab;\n; move it toward a diagonal and the tweak comes in. 0 = the game's own behaviour" },
    { "GrabTweakDead",  "num", 0, 90,   "degrees the stick may wander from where it picked the grab before any tweak" },
    { "GrabTweakRamp",  "num", 1, 120,  "degrees beyond that over which the tweak grows to the game's full amount" },
    { "GrabTweakMaxTurn","num", 10, 90, "the furthest from the pick direction the game is ever shown the stick, in degrees (45 = as far as the diagonal: it never sees the next grab's direction)" },
    { "GrabTweakInvert", "num", 0, 1,    "1 = the grab tweak turns the other way: turning the stick clockwise twists you counter-clockwise (every grab; needs GrabTweakGate=1)" },
    { "GrabKeepFirst",  "num", 0, 1,    "1 = the grab the game took stays yours until you let go: moving the stick tweaks it, it does not pick another (0 = the old re-pick window)" },
    { "GrabLog",       "num", 0, 1,    "1 = log each grab's numbers: how far each hand is from the board's hand anchors, and how deep the\n; crouch is (hips above the board), before the grab, 0.3 s in and at the end" },
    { "NativeGrab",    "num", 0, 1,    "1 = the grabbing hand is put ON the board by the native half (Mods\\ExpandedTricksNative, C++): the arm is\n; solved in the finished pose, either hand, onto the game's own grab point on the deck you see -- the body\n; and the crouch stay as they are. (Replaces GrabHandIK / GrabLock while it is running.) 0 = off" },
    { "NativeGrabStrength","num", 0, 1, "how far the native arm goes to the board: 1 = all the way, 0.5 = half way" },
    { "NativeTweak",   "num", 0, 120,  "TWEAK: most the board may be turned toward the grab, in degrees (any axis: nose up, tail up, edge up, twisted). 0 = off" },
    { "NativeTweakMode","num", 1, 3,   "3 = the DECK YOU SEE is driven by your limbs: its foot sockets and grab spot are pulled toward the animated feet and hand, a little each frame, and the feet stand on it; 2 = the v72 fit of the skeleton board; 1 = the v70 swing" },
    { "NativeFitGain", "num", 0, 0.5,  "mode 3: how fast the deck follows the limbs (share of the remaining turn per frame; higher = snappier, too high = wobbly)" },
    { "NativeHeel",    "num", 0, 60,   "most a heel may lift off the deck over the toe joint when the board tips further than the ankle bends, in degrees (0 = feet always flat)" },
    { "NativeLegSearch","num", 0, 1,   "1 = each leg picks the knee swing (hip rotation) and heel lift that keep the ankle natural and the knee clear of the grabbing arm; 0 = plain two-bone legs" },
    { "NativeProfileLift","num", -20, 20, "Nose/Tail/Indy: cm the board is lifted toward the hand (0 = the tilt alone; the v77 lift of 15 folded the rising leg into the body)" },
    { "NativeTailFromNose","num", 0, 1, "Tail: 1 = the hand goes to the Nose grab's spot mirrored to the tail end (the Nose spot is learned from your Nose grabs; until then the game's own tail spot)" },
    { "NativeOwnSpots","num", 0, 1,    "1 = the grabbing hand goes to OUR grab spot on the deck (Nose: nose tip, Tail: tail tip, Indy: toe edge between the feet, Melon: heel edge); 0 = the game's own grab point" },
    { "NativeDeckHalfLen","num", 0, 50, "cm from the deck's centre to a tip (for the Nose/Tail spots). 0 = measured from your deck's own mesh (v84)" },
    { "NativeDeckHalfWidth","num", 0, 15, "cm from the deck's centre line to its edge (for the Indy/Melon spots). 0 = measured from your deck's own mesh" },
    { "NativeSpotUp",  "num", -5, 20,  "cm the wrist sits over the deck top at the Nose/Tail tip" },
    { "NativeSpotIn",  "num", 0, 20,   "cm the wrist sits in from the Nose/Tail tip (the fingers wrap the end)" },
    { "NativeSpotUpEdge","num", -5, 20, "cm the wrist sits over the deck top at the Indy/Melon edge" },
    { "NativeMelonFwd","num", -20, 20, "Melon: the hand this many cm toward the front foot from the middle between the feet (just behind the front heel)" },
    { "NativeLeanTuck","num", 0, 3,    "Melon/Indy: the spine may lean NativeLean x this toward the hand" },
    { "NativeHandAvoid","num", 0, 1,   "1 = on its way to the board the wrist is pushed out of the legs (it used to go straight through them); fades out as it arrives" },
    { "GrabBlockFlips","num", 0, 1,    "1 = no late flips out of a grab: while LB/RB is down or a grab is held the game's late-trick check is kept switched off;\n; let go and (0.2 s on, once the sticks have been through centre) late flips work as ever" },
    { "GrabAllAlong",  "num", -20, 20, "EVERY GRAB'S HAND AT ONCE: cm added to each grab's own Hand...Along (and a two-hand grab's Hand2...Along) -- + toward the nose, - toward the tail. 0 = each grab's own number alone. The per-grab numbers further down are not changed by it" },
    { "GrabAllAcross", "num", -20, 20, "...added to each grab's own Hand...Across: cm, + toward your toes, - toward your heels" },
    { "GrabAllUp",     "num", -20, 20, "...added to each grab's own Hand...Up: cm, + off the deck, - into it" },
    { "GrabBlocked",   "str", 0, 0,    "grabs that are switched OFF, by name, commas between (the stick's diagonal then picks the grab next to it): e.g.\n; ChickenSalad,Taipan,RoastBeef,CanadianBacon -- write None to have all 12" },
    { "DoubleGrabs",   "num", 0, 1,    "1 = the TWO-HAND grabs (the mod's own): hold LB AND RB in the air; the two grabs your sticks pick make the pair" },
    { "DoubleCannonball", "str", 0, 0, "Cannonball (front hand on the nose, back hand on the tail): the LB grab + the RB grab that make it" },
    { "DoubleGorilla", "str", 0, 0,    "Gorilla (both hands on the toe edge): the LB grab + the RB grab that make it (Mute and Indy are the centred sticks)" },
    { "DoubleRocket",  "str", 0, 0,    "Quasimodo (both hands on the nose, both feet on the tail): the LB grab + the RB grab that make it.\n; Nose+Crail = left stick up, right stick pulled DOWN (both sticks up is Nose+Tail = the Cannonball; swap the two lines' values if you want it the other way)" },
    { "DoubleCannonballBase", "str", 0, 0, "the game's grab whose crouch the Cannonball is built on" },
    { "DoubleGorillaBase", "str", 0, 0, "the game's grab whose crouch the Gorilla is built on" },
    { "DoubleRocketBase", "str", 0, 0,  "the game's grab whose crouch the Quasimodo is built on" },
    { "NativeHandAim", "num", 0, 2,    "the hand TURNED to the board (fingers down past the edge, palm toward the deck): 0 = off (the game's own hand pose, which lies flat on the deck),\n; 1 = in the two-hand grabs only, 2 = in every grab (the default since v114: the grabbing hand)" },
    { "NativeCatchHold", "num", 0, 1,  "1 = when a grab is handed to the game with its catch orient still off, it is set as the game's own grab pick would set it: the deck follows the board bone\n; (the tilt) only in that state -- grabs that started without it took no tilt at all (a Crail / Seatbelt / Stalefish that worked one time and not the next)" },
    { "NativeGrabStance", "num", 0, 1, "1 = a grab plants the feet in the TAIL layout (back foot on the tail, front foot over the front truck), whichever layout you last rode:\n; the game shifts the feet forward for a nollie / fakie crouch and after a revert, and a grab took that (0 = as last ridden)" },
    { "DevKeys",   "num", 0, 1,      "1 = the keyboard test keys: F11 mini hop, F12 hippie jump (no crouch check), F7 board survey (logged), the numpad nudges the last grab's hand numbers and saves them here. 0 = the keyboard is left alone (the release's default)" },
    { "NativePad", "num", 0, 1,      "1 = the controller's stick clicks, triggers, bumpers and Y are read by the native half from the game's own key events;\n; 0 = from SessionTweaks.log as before (needs its CatchClickToCatch=1 and CatchClickProbe keys)" },
    { "MenuOwnPages", "num", 0, 1,   "where the settings pages live: 1 = the mod's own NESTED pages in the pause menu (an Expanded Tricks row that opens Quick settings, Hippie Jumps, Drop-ins, Grabs, No Comply), with or without SessionOpenMP;\n; 0 = one flat page of 14 rows inside SessionOpenMP's pause menu (what the nested pages fall back to if they cannot be placed)" },
    { "NativeFingerCurl", "num", 0, 1.5, "how far the four fingers curl round the edge where the hand is turned (1 = 50 / 60 / 35 degrees at the three joints; 0 = as animated)" },
    { "NativeFingerCurlRoot", "num", -30, 120, "degrees the fingers' ROOT joint (at the knuckle) curls toward the palm, x NativeFingerCurl" },
    { "NativeFingerCurlMid",  "num", -30, 120, "degrees the fingers' MIDDLE joint curls toward the palm, x NativeFingerCurl" },
    { "NativeFingerCurlTip",  "num", -30, 120, "degrees the fingers' TIP joint curls toward the palm, x NativeFingerCurl" },
    { "DropIn",        "num", 0, 1,    "DROP-INS. 1 = on foot, close to the edge of a ledge, ramp or bank, Y / triangle (the get-on-the-board button) sets you up to drop in:\n; the game puts you on the board, the mod sets the board up as a skater does: the back wheels hung out past the edge, the tail down on the ledge, the deck rising over the drop.\n; Then: a stick pushed UP = drop in; LB or RB = back onto the ledge; Y = step off. 0 = off" },
    { "DropInRange",   "num", 20, 200, "how close to the edge you must stand, in cm (from the middle of your body)" },
    { "DropInMinDrop", "num", 8, 300,  "how far the ground must fall away past an edge for it to count, in cm" },
    { "DropInFace",    "num", 0, 180,  "how far off square to the edge you may face and still get a drop-in: 0 = any way; 30 = up to 30 deg left or right of straight at the drop" },
    { "DropInStillSpeed", "num", 0, 100, "drop-ins: Y sets one up only when you stand STILL -- moving faster than this (cm/s) it is the game's own throwdown. 0.01 = a standstill (it was 40: a slow walk still counted)" },
    { "DropInBack",    "num", 10, 80,  "where the game first stands the board: its middle this many cm back from the edge (all four wheels on the ledge)" },
    { "DropInHang",    "num", -5, 20,  "the drop-in stance: the back wheels hang this many cm out PAST the edge (their axle), the tail down on the ledge behind it" },
    { "DropInTail",    "num", 5, 40,   "the board's tail: from the back axle to the tail's tip, in cm (sets where the tail meets the ledge)" },
    { "DropInKick",    "num", 0, 8,    "how far the tail's tip kicks up off the deck's flat underside, in cm (the tip rests on the ledge; a flat deck = 0)" },
    { "DropInPitch",   "num", 0, 45,   "how steeply the deck rises from the tail while you wait, in degrees (raised by itself if a coping stands in the way)" },
    { "DropInTilt",    "num", 0, 60,   "a straight drop (nothing for the front wheels to meet): the board is tipped this many degrees nose-DOWN before it is let go" },
    { "DropInVertDrop", "num", 10, 200, "a VERT drop-in: the ground just past the edge is at least this far down (cm) and 90 cm or more down further out, so the front wheels find nothing to pivot onto (a wall with coping, FDR). Then the vert numbers below are used" },
    { "DropInVertTilt", "num", 20, 89,  "vert: the board is tipped this many degrees nose-DOWN before it is let go (steep: the wheels must meet the wall, not fly over it)" },
    { "DropInVertSpeed", "num", 0, 2000, "vert: the speed the board is let go with, cm/s along the board (little: the wall gives the speed)" },
    { "DropInVertSpin", "num", 0, 400,  "vert: how fast the board keeps tipping nose-down as it goes, deg/s" },
    { "DropInVertBack", "num", 0, 400,  "vert: the board is pushed back toward the wall this fast as it is let go, cm/s (the wheels meet a wall that hangs under the coping instead of falling past it)" },
    { "DropInVertBoost", "num", 0, 2000, "vert: once the wheels are on the wall (riding, 0.3 s after the let-go) this much speed is added down the wall, cm/s (the let-go itself is slow so the wheels meet the wall)" },
    { "DropInSpin",    "num", 0, 400,  "the board is let go still tipping forward at this many degrees a second (so it lands on its wheels, not flat)" },
    { "DropInSetTime", "num", 0.05, 2, "seconds the slide out (and back) takes" },
    { "DropInAlignTime", "num", 0, 2, "seconds the first move takes: from where the game put you on the board to square to the edge, the board's middle DropInBack cm from it. It was one frame (a teleport); 0 = that again" },
    { "DropInTime",    "num", 0.05, 2, "seconds the board takes to pivot down onto the ramp when you drop in" },
    { "DropInSpeed",   "num", 0, 2000,  "the speed the board is let go with, in cm/s (down the ramp; straight out over a plain ledge)" },
    { "DropInMaxSlope","num", 10, 89,  "the steepest the board may be pivoted down to meet the ground, in degrees; past that (a plain wall) it rolls off level instead" },
    { "DropInRampSlope","num", 0, 89, "ground steeper than this where the front wheels would meet it counts as a ramp to pivot down onto; flatter (the floor below a plain ledge) = a straight drop" },
    { "DropInPush",    "num", 0, 1,    "1 = if the board does not get going after a drop-in, the skater gives one push" },
    { "DropInStart",   "num", 0, 200,  "the game's throwdown needs room: closer to the edge than this (cm) you are first stepped back to here, facing as you were (0 = never)" },
    { "DropInSounds",  "num", 0, 1,    "1 = the drop-in's own sounds: the throwdown sound when the mod mounts you itself (not when the game's own throwdown already dropped the board), a board tap as it settles and as it is let go (Sounds must be on too)" },
    { "DropInSoundVolume", "num", 0, 8, "volume of the drop-in's three sounds (SoundVolume is the hippie jump's): 1 = as authored, above 1 boosts" },
    { "DropInStartSound", "str", 0, 0, "sound when the mod puts you on the board itself (the game's own throwdown keeps its own); any /Game/... SoundCue path" },
    { "DropInSetSound",   "str", 0, 0, "sound as the board settles into the stance (the tail down on the ledge): the cue to push the stick" },
    { "DropInEndSound", "str", 0, 0,  "sound as the board is let go onto the ramp" },
    { "NativeDeckUp",  "num", 0, 1,    "1 = the deck's own up axis is its mesh's Z (v82; the skater mesh leans ~9 deg forward riding, which tilted the\n; learned 'up' -- the Nose hand under the nose, the Tail hand floating); 0 = the up learned from the skater mesh (v81)" },
    { "BoardHop",      "num", 0, 1,    "1 = on foot after a bail, a click (L3 or R3) near the board lying on the ground jumps you onto it and you ride away (the board stays where it lies, keeps its heading; you ride the way you face, in your stance)" },
    { "BoardHopRange", "num", 50, 600, "how far away the board may be for the hop, in cm" },
    { "BoardHopTime",  "num", 0.2, 1.5, "how long the hop onto the board takes, in seconds" },
    { "BoardHopHeight","num", 0, 120,  "how high the hop arcs, in cm" },
    { "BoardHopRideZ", "num", 40, 160, "how high over the deck the hop lands you until the mod has measured it while riding, in cm" },
    { "NativeBoardEase","num", 0.01, 1, "how fast the board eases into (and height follows) the grab's tweak, share per frame" },
    { "NativeEdgeRoll","num", 0, 1,    "grabs: feet may roll onto a sole edge pinned to the deck (Nose: front foot on its outer edge; Tail/Indy/Melon: front foot inner edge, back foot outer edge). 1 = full, 0 = feet flat" },
    { "NativeArmSearch","num", 0, 1,   "1 = the grabbing arm's elbow side is chosen to go round the knees, feet and the deck edge instead of through them" },
    { "LandFeetFrames","num", 1, 40,   "180 landings (deck stays put): the feet ease onto the board over this many frames after touchdown instead of snapping" },
    { "HopPlan",       "num", 0, 0.9,  "THE PLANNED LANDING (native v94). The point of the air time from which a hop's landing is one plan: the hips are\n; let down so the legs arrive bent and the feet are on the deck AT touchdown (not 2-7 frames after it, on straight legs),\n; each foot is carried to the spot the game stood it on at the last landing, a spin LOCKS onto the half turn it is coming\n; up to unless it can make the next one, and the body's heading is eased through the landing. 0 = off: v93's reach, hold\n; and assist exactly (change it while playing to compare)" },
    { "HopLock",       "num", 0, 1,    "a hop's turn: 1 = it LOCKS onto the half turn it is coming up to when it cannot make the next landing, and the landing\n; assist measures the spin over the frames it really turned (v94). 0 = v177's assist exactly" },
    { "HopHold",       "num", 0, 2,    "the body's heading through a landing: 0 = v93's hold (180 landings only), 1 = on springs after a 180 (v94), 2 = on springs\n; after a straight / full-turn landing as well" },
    { "HopPlanStraight","num", 0, 2,   "a hop that is still STRAIGHT when its planned landing would begin: 0 = it lands as in v93; 1 = it is planned too; 2 = planned only where the legs cannot reach the board otherwise (riding regular, where the game does not bend the knees for the landing, and the mini hop) -- the switch / crouched straight hops stay exactly as they were" },
    { "HopSinkFade",   "num", 0.05, 1, "the planned landing: seconds over which the hips' let-down is given back after touchdown" },
    { "HopLandOwn",    "num", 0, 120,  "a hop that lands the way it took off: the longest, in seconds from touchdown, that a leg the game draws SQUEEZED is drawn\n; its own length instead, the knee bent for the difference (riding regular the game shortens the front shin to 17-19 cm in the\n; landing's crouch, where the bone is 41, and after a mini hop keeps it at 30 or so while you roll on). It ends by itself as soon\n; as the game's legs are whole again, and is handed back over half a second when its time is up or you start something else\n; (a push, a powerslide, a trick). 0 = v179: the game's legs from the touchdown frame. Riding switch the game bends both knees\n; itself and nothing changes" },
    { "HopHoldOmega",  "num", 4, 80,   "the sprung hold: the springs' stiffness, 1/s (22 = two thirds of a step in a tenth of a second)" },
    { "HopLegBend",    "num", 0.8, 0.98, "the planned landing: a leg's length at touchdown as a share of its full length (0.92 = knees clearly bent, 0.97 = nearly straight)" },
    { "HopCarry",      "num", 0, 2,    "the planned landing: are the feet carried to the spots the last landing ended on? 0 = never, 1 = only in a hop that does not turn (native v95), 2 = in every hop (v94). A hop that turns (a half turn or a full one) comes down where the body has its feet and the game slides them into place after touchdown" },
    { "HopLagFix",     "num", 0, 1,    "a 180's landing: 1 = the hips stay where they were over the board while the game turns your skater round after touchdown (it does that a step late: the hips swung 20-25 cm sideways in one frame). 0 = v94" },
    { "HopKneeToes",   "num", 0, 1,    "a hop's poses: 1 = a leg the game draws nearly straight bends its knee over its toes. 0 = v94" },
    { "HopKneeKeep",   "num", 0, 1,    "a hop's air: 1 = a knee keeps bending the way the game's pose has it, however often the leg is solved on that pose (native v96:\n; in a crouched 180 from regular the left knee swung 28 deg inward over the last tenth of a second of the air). 0 = v95" },
    { "HopKneeLand",   "num", 0, 1,    "a 180's landing: 1 = the knees go from where the air had them to the game's by the landing's blend, as the feet do (native v96:\n; with hips and feet held still a knee stepped 14-20 cm in one frame on the second or fourth frame after touchdown). 0 = v95" },
    { "HopKneeRide",   "num", 0, 1,    "a hop's straight or squeezed leg (the air's ends, and the legs that keep their own length after the landing): 1 = its knee bends the way that shin stands on its foot when you ride -- out over the foot (native v97). 0 = toward the toes (v95-v96: riding regular the leading knee swung inside its ankle for half a second after every landing, the ankle rolled over)" },
    { "LegHingeRoll",  "num", 0, 1,    "every leg the mod solves (a hop's landing, a plant, a held foot): 1 = the thigh and the shin are rolled about their own length until the knee's hinge lies on the leg's plane (native v99; the hinge is read from your riding poses). 0 = each keeps the roll the pose came in with (to v98: a knee bent another way than the pose had it came out sheared sideways, the skin wrung at the knee and the ankle)" },
    { "HopShinTight",  "num", 0, 1,    "a hippie jump's legs: 1 = a leg bone is put back to its own length from half a centimetre over it (native v99). 0 = only from 4 % over (to v98: the drawn shin was 1.3-1.6 cm long on a few poses of every touchdown, the ankle off the end of the shin)" },
    { "HopFeetFree",   "num", 0, 1,    "a hippie jump's air: 1 = the feet are free to turn with their shins, and a leg the mod has made longer or shorter bends over its own foot (native v100: the game's tuck has the knees out to the sides and the feet straight ahead -- the ankle wrung 43-75 deg, the trouser cuff flat between shin and shoe). 0 = v99's air" },
    { "HopAnkleLimit", "num", 0, 90,   "...the twist a foot may keep against its shin in a hop's air, degrees (18; 15 % of what is over it is left in)" },
    { "AutoUpdate",    "num", 0, 2,    "new versions of the mod: 0 = never looked for. 1 = looked for once a run, at its start, and you are told in ExpandedTricks.log and on the trick display. 2 = also downloaded from the mod's GitHub page (github.com/Portman2/SessionExpandedTricks, its latest release), checked (the release must carry the author's signature, each file its SHA-256) and put in place for the NEXT start of the game; the files before it are kept as main.lua.prev and main.dll.prev (native v101)" },
    { "PoseRecorder",  "num", 0, 1,    "1 = every trick's skeleton is written to ExpandedTricks.poses.bin beside the logs (up to 96 MB; tools/posedump draws it). For chasing a bad pose; 0 = off (the release's default)" },
    { "TraceLog",      "num", 0, 1,    "1 = the native half writes its per-pose traces of hops and plants to ExpandedTricks.native.log (what a bug report needs); 0 = quiet" },
    { "HopCarryTurn",  "num", 0, 1,    "a hop that TURNS: 1 = its feet are carried to their landing spots too, by the share of the turn that is done -- nothing while more than 60 deg are left, all of it from 15 (native v100: a 180 mini hop came down 23-25 cm off the deck's middle line, both ankles 13 cm outside its edge). 0 = v95's: a turned hop comes down where the body has its feet (HopCarry=1)" },
    { "HopHipFix",     "num", 0, 1,    "a hippie jump's air and landing, and a hand on the board: 1 = the hip joints are put back in their sockets (native v99: the game has both thighs 12-19 cm out of the pelvis on the touchdown pose of every hop, and 13-20 cm while a hand is on the board). 0 = left as the game has them" },
    { "TweaksLearnGuard","num", 0, 1,  "1 = while a trick of this mod's is drawn (a hippie jump's air and landing, a plant, a held pose) SessionTweaks' idle re-learn waits (native v97; SessionTweaks 3.19.607 -- another build is left alone and the native log says so). It learns your idle afresh after every switch plant, and it once learned it from a hippie jump's poses: every landing floated 13 cm for half a second from then on. 0 = off" },
    { "HopLandOwnTurn","num", 0, 1,    "a 180's landing: 1 = the legs keep their own length after it too (the straight landing's HopLandOwn, native v96: riding regular\n; into a 180 the game draws the left shin 16-19 cm for most of a second after touchdown). 0 = only after a hop that lands the way it took off" },
    { "NativeFitHand", "num", 0, 10,   "how hard the grab spot pulls the board to the hand against each foot holding it (1 = equal, 2 = twice as hard: a bigger tweak, the legs fold a bit more)" },
    { "NativeFitMove", "num", 0, 40,   "most the board's centre may be shifted by the fit, in cm" },
    { "NativeHoldBleed","num", 0.01, 1, "180 landings: how fast the held heading lets go per frame after the sudden turn is cancelled (lower = smoother, slower)" },
    { "NativeTweakShare","num", 0, 1,  "how much of the full turn toward the hand the tweak takes (1 = all of it, up to NativeTweak)" },
    { "NativeLegs",    "num", 0, 1,    "1 = the feet stay on the tipped board (the legs are re-solved); 0 = legs as animated" },
    { "NativeLean",    "num", 0, 60,   "when the grab point is out of the arm's reach, the spine bends toward it (the least that gets it\n; in reach), at most this many degrees. 0 = off" },
    { "NativePull",    "num", 0, 40,   "the board is drawn up toward the grabbing shoulder by up to this many cm while the hand still\n; can't reach it (it grows until the hand is on). 0 = off" },
    { "NativeFeet",    "num", 0, 1,    "1 = during grabs the feet stand on the deck you SEE (its foot sockets; stops feet sinking through\n; the board); 0 = the feet ride the skeleton's board" },
    { "NativeElbowOut","num", 0, 2,    "the grabbing elbow is pushed out sideways by this much, so the arm goes round the legs. 0 = as animated" },
    { "NativeKneeAway","num", 0, 1,    "1 = a knee the grabbing arm would pass through is swung out of its way (the foot stays put)" },
    { "NativeHandFull","num", 0.05, 1, "the game's grab weight at which the hand is all the way on the board (lower = latches sooner)" },
    { "NativeGuard",   "num", 0, 2,    "180 landings: 1 = for the second after touchdown the native half un-twists a lower body facing the\n; other way and un-crosses crossed legs; 2 = always; 0 = off" },
    { "NativeRevertCtl","num", 0, 1,   "1 = the instant revert also turns the board's own heading in the same frame (no visible spin back)" },
    { "NativeEase",    "num", 0.02, 1, "how fast the grab corrections (lean, feet onto the deck, knees out of the way) ease in: the share of\n; the way they move each frame. Lower = smoother but slower, 1 = instant (v70, twitchy)" },
    { "NativeHold",    "num", 0, 1,    "1 = after a 180 landing the native half holds the body's heading in the world until it settles (no swing\n; when the revert completes and the skater turns with the board)" },
    { "MuteRevertSound","num", 0, 1,   "1 = no revert sound on our 180 landings (the game's own reverts keep theirs)" },
    { "GrabWait",      "num", 0, 0.5,  "seconds the grab waits after LB/RB for your stick to pick a direction (it goes the moment the stick\n; is past half way); still centred after this = the centred grab (GrabLBNeutral / GrabRBNeutral)" },
    { "GrabChord",     "num", 0, 0.3,  "seconds a ONE-bumper grab waits for the other bumper when BOTH sticks are pushed (a two-hand grab's gesture). A Cannonball whose left bumper landed first went to the game as a Nose Grab and was then changed under it: the board stayed tipped 16-25 deg and the body was bent double to reach it (5 of 5 on 4 Oct). 0 = no wait" },
    { "DoubleClean",   "num", 0, 1,    "1 = a two-hand grab begun while the game already holds a one-hand grab of the FRONT hand lets that one go first and starts afresh. Riding regular, every Cannonball begun over a Nose Grab (the left bumper a moment early, or the game picking the Nose Grab itself) kept that grab's tipped board under the Cannonball's body: lean 39-40 deg, the board tipped 18 (14:20:05 and 14:21:23 on 4 Oct; the two pressed together: lean 10, tipped 1)" },
    { "GrabRepick",    "num", 0, 1,    "for this long after the grab starts, pushing the stick firmly to another direction switches to that grab" },
    { "NativeHandUp",  "num", -20, 20, "the wrist this many cm above the game's grab point, along the deck's own up (negative = down into the grab; -4 puts the palm on the grip)" },
    { "GrabLeftUp",       "str", 0, 0, "which grab each direction does. Names: Nose Melon Mute ChickenSalad Taipan SeatBelt (front-hand\n; grabs) and Tail Indy StaleFish RoastBeef Crail CanadianBacon (back-hand grabs); anything else = none.\n; LEFT stick pushed up (toward the nose)" },
    { "GrabLeftUpToe",    "str", 0, 0, "left stick up + toward your toes" },
    { "GrabLeftToe",      "str", 0, 0, "left stick toward your toes" },
    { "GrabLeftDownToe",  "str", 0, 0, "left stick down + toward your toes" },
    { "GrabLeftDown",     "str", 0, 0, "left stick down (toward the tail)" },
    { "GrabLeftDownHeel", "str", 0, 0, "left stick down + toward your heels" },
    { "GrabLeftHeel",     "str", 0, 0, "left stick toward your heels" },
    { "GrabLeftUpHeel",   "str", 0, 0, "left stick up + toward your heels" },
    { "GrabLeftNeutral",  "str", 0, 0, "left stick clicked without pushing it anywhere" },
    { "GrabRightUp",      "str", 0, 0, "RIGHT stick pushed up (toward the nose)" },
    { "GrabRightUpToe",   "str", 0, 0, "right stick up + toward your toes" },
    { "GrabRightToe",     "str", 0, 0, "right stick toward your toes" },
    { "GrabRightDownToe", "str", 0, 0, "right stick down + toward your toes" },
    { "GrabRightDown",    "str", 0, 0, "right stick down (toward the tail)" },
    { "GrabRightDownHeel","str", 0, 0, "right stick down + toward your heels" },
    { "GrabRightHeel",    "str", 0, 0, "right stick toward your heels" },
    { "GrabRightUpHeel",  "str", 0, 0, "right stick up + toward your heels" },
    { "GrabRightNeutral", "str", 0, 0, "right stick clicked without pushing it anywhere" },
}

------------------------------------------------------------------- constants
local LOG     = "ExpandedTricks.log"
local INI     = "ExpandedTricks.ini"
local TWKLOG  = "SessionTweaks.log"
local HOOK    = "/Script/SessionGame.SkaterCharacterBase:GetSkateboardingAnimParams"
local BANK_HOOK = "/Script/SessionGame.SkaterCharacterBase:MulticastRPCSetTargetBankingRatio"
local POLL_MS = 10
local MANUAL_MODE = 4                     -- EBodyRotationMode::Manual, the game's default
local MODE_RIDING, MODE_AIR, MODE_BAILING = 1, 2, 5   -- ESkaterMovementMode (the custom movement mode)
local MODE_TO_BOARD = 4   -- ToSkateboarding: after a spawn the game can sit here for ~10 s while you already roll

-- ABP_AMXX_Skater anim nodes (FAnimNode_ModifyBone): their Translation / TranslationMode are
-- never written by the anim blueprint, so a write sticks until we put it back.
local NODE_BODY  = "AnimGraphNode_ModifyBone_1"   -- bone AMXX_Root: the whole body, not the board
local NODE_BOARD = "AnimGraphNode_ModifyBone"     -- bone SKXX_SkateSkel_Flipper: the board's deck
local BMM_IGNORE, BMM_ADDITIVE = 0, 2             -- EBoneModificationMode
local LIFT_MESH, LIFT_BODY, LIFT_COUNTER = 0, 1, 2
local SOCK_HEAD  = "AMXX_HeadSocket"
local SOCK_BOARD = "SKXX_SkateSkel_FlipperSocket"
local FULL_CROUCH_CM = 45                         -- MiniCrouch = 1 dips this far

local RIGHT_CLICK = { ["Gamepad_RightThumbstick"] = true, ["GenericUSBController_Button10"] = true,
                      ["GenericUSBController_Button12"] = true }
local LEFT_CLICK  = { ["Gamepad_LeftThumbstick"]  = true, ["GenericUSBController_Button9"] = true,
                      ["GenericUSBController_Button11"] = true }
local TRIGGER     = { ["Gamepad_LeftTrigger"] = -1, ["Gamepad_RightTrigger"] = 1 }

local PAIR     = { L3 = { stick = "Right", dir = "Down" }, R3 = { stick = "Left", dir = "Up" } }
local FRESH    = 4.0
local MINI_WINDOW  = 0.25                 -- both clicks within this = a mini hop
local MINI_CONVERT = 0.30                 -- a hippie jump this young (still standing) becomes the mini hop
local OPPOSITE = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
local pressedAt = { Left = {}, Right = {} }

------------------------------------------------------------------- state
local cached, s0, mesh, inst, mv = nil, nil, nil, nil, nil
local active, t0, myAddr = false, 0, nil
local meshZ0, yaw0 = nil, 0
local airT, gravityUsed = 0.6, false
local tookOff = false
local stateLogged = {}
-- the hop being done: "hippie" or "mini", with its own numbers
local P = { kind = "hippie", height = 95, pre = 0.33, dip = 0, footPull = 0, absorb = 0.9 }
-- varial
local yawAcc, lastFrameT = 0, nil
local assistFrom, assistYaw, assistTarget = nil, 0, 0
local rotMode, rateMult = MANUAL_MODE, 1.0
local fixedDir, fixedFrom = 0, 0
local lastTrig, lastTrigAt = 0, -1e9
-- game-air handling
local liftScale, airFrames, handedBack, gameAirSeen, landingFade = 1.0, 0, false, false, false
-- lift method + board hold
local liftMode, liftBroken, nodeTouched = LIFT_BODY, {}, {}
local lastDz, holdExtra = 0, 0
-- where the hop started (for the bail return)
local start = { x = 0, y = 0, z = 0, yaw = 0, dx = 0, dy = 0 }
local lastHopEndAt = -1e9
-- landing absorb + yaw settle + bails
local LA = { t0 = nil, saved = nil, stance = 1, amount = 0.9 }
local YS = { t0 = nil, residual = 0, len = 0.15 }
local BV = { pending = false, t0 = 0, residual = 0 }                    -- our varial bail: did it take?
local BY = { pending = false, t0 = 0, sawBail = false }                 -- restore the body yaw after it
local BR = { pending = false, t0 = 0, sawBail = false, backAt = nil }   -- put you back after a hop bail
local SB = { pc = nil, stick = nil }                                    -- the sticks the game sees during a hop
local RV = { pending = false }                                          -- a switch landing through the game's revert
-- the native half (Mods/ExpandedTricksNative, C++): the grab hand IK in the finished pose. Filled in by NATIVE.sync.
local NATIVE = { v = nil, mesh = nil, anim = nil, rigFor = nil, set = nil, live = false, rig = 0 }
function NATIVE.grab() return NATIVE.live and NATIVE.rig > 0 and S.NativeGrab ~= 0 end
-- (v189, review) ANOTHER BUILD OF THE GAME. The native half checks the exe's build stamp and leaves its hook out on any
-- other -- but the Lua half went on: the 2 s tick still wired the no comply and wrote the trick names through natives
-- that call fixed addresses in the exe. HJN_PushCap answers "0 not this game build" before it touches anything; that
-- is asked once here, and everything of the mod's that touches the game stands down on it (only the update check runs).
do
    local okb, ans = pcall(function() return HJN_PushCap(0, 1) end)
    NATIVE.off = (okb and tostring(ans):find("not this game build", 1, true) ~= nil) or false
end

-- (v96) EVERY GRAB'S OWN NUMBERS. All 12 of the game's grabs, 15 settings each, in the ini as <Setting><Grab>
-- (HandNoseAlong, TiltIndy, SplayBackIndy, RollFrontNose...). The native half reads them per grab (HJN_GrabSet).
do
    -- name, the game's id, then the defaults: tilt, lift, drop, splay front, splay back, roll front, roll back, back, slide, via across, via up
    NATIVE.GRABS = {
        { "Nose",          1,   25,  0,  0, 15, 15, -40,   0,  0, 8,  0,  0 },
        { "Melon",         2,   15, 10, 12, 10, 10,  15, -15, 25, 0,  0,  0 },
        { "Mute",          3,   10,  8,  6, 15, 15,   8,  -8,  0, 0, 15,  8 },
        { "ChickenSalad",  4,   10,  8,  6, 25, 25,  10, -10,  0, 0,  0,  0 },
        { "Taipan",        5,   10,  8,  6, 25, 25,   8,  -8,  0, 0,  0,  0 },
        { "Seatbelt",      6,   20,  0,  0, 15, 15,  20, -20,  0, 8,  0,  0 },
        { "Tail",          100, 35,  0,  0, 15, 15,  25, -25,  0, 8,  0,  0 },
        { "Stalefish",     101, 10,  8,  6, 10, 10,  10, -10,  0, 0,  0,  0 },
        { "Indy",          102, 10,  8,  6, 10, 30,   8,  -8,  0, 0, 18, 10 },
        { "RoastBeef",     103, 10,  8,  6, 25, 25,  10, -10,  0, 0,  0,  0 },
        { "CanadianBacon", 104, 10,  8,  6, 25, 25,   8,  -8,  0, 0,  0,  0 },
        { "Crail",         105, 20,  0,  0, 15, 15, -30,   0,  0, 8,  0,  0 },
        -- (v97) the two-hand grabs, the mod's own (ids 200+ are the native half's, not the game's)
        -- (v98: + the 14th number, the most the back may fold forward)
        { "Cannonball",    200,  0, 12,  6, 30, 30,   0,   0,  0, 6,  0,  0, 60 },
        { "Gorilla",       201, 10, 10,  8, 30, 30,   8,  -8,  0, 0, 15,  8, 45 },
        { "Rocket",        202, 50,  0,  0, 20, 20,   0,   0,  0, 22, 0,  0, 45 },
    }
    S.HandRocketAcross, S.Hand2RocketAcross, S.Via2RocketAcross, S.Via2RocketUp = -5, 5, 15, 10   -- (side by side on the nose)
    -- prefix, suffix, the native half's index, lowest, highest, which default column (0 = 0), what it is
    NATIVE.PARAMS = {
        { "Hand", "Along",  0, -40, 40,  0, "where the hand ends up: cm toward the nose (+) or the tail (-) from the mod's own spot" },
        { "Hand", "Across", 1, -40, 40,  0, "where the hand ends up: cm toward your toes (+) or heels (-)" },
        { "Hand", "Up",     2, -40, 40,  0, "where the hand ends up: cm off the deck (+) or into it (-)" },
        { "Via",  "Along",  3, -60, 60,  0, "the hand's path: the wrist swings through a point this many cm toward the nose (+) off the straight line's middle" },
        { "Via",  "Across", 4, -60, 60, 12, "the hand's path: ... this many cm toward your toes (+) / heels (-) -- e.g. 20 = out past the toe edge, then in" },
        { "Via",  "Up",     5, -60, 60, 13, "the hand's path: ... this many cm up (+)" },
        { "Tilt", "",       6, -60, 80,  3, "the board's tilt: the rising end (the nose for Nose/Crail, else the tail) this many degrees over the horizon" },
        { "Lift", "",       7, -20, 25,  4, "cm the board comes up toward the hand (the tuck)" },
        { "Drop", "",       8,   0, 25,  5, "cm the hips drop toward the board (the knees fold more) so the hand reaches" },
        { "SplayFront", "", 9, -60, 60,  6, "degrees the FRONT knee stands out from the other knee (0 = as the animation has it)" },
        { "SplayBack", "", 10, -60, 60,  7, "degrees the BACK knee stands out from the other knee" },
        { "RollFront", "", 11, -70, 70,  8, "degrees the FRONT foot rolls onto a sole edge: + the inner edge (toward the other foot), - the outer edge; 0 = flat" },
        { "RollBack", "",  12, -70, 70,  9, "degrees the BACK foot rolls onto a sole edge: + inner, - outer; 0 = flat" },
        { "Back", "",      13, -40, 40, 10, "cm the body shifts toward the heels, off the board (the boned Melon has 25)" },
        { "Slide", "",     14,   0, 40, 11, "cm the foot on the grabbed END of the board slides toward the middle, out of the hand's way (tip grabs; Rocket: the front foot's way back to the tail)" },
        -- (v97) the two-hand grabs only: the BACK hand's own spot and path (Hand... / Via... are the front hand's)
        { "Hand2", "Along", 15, -40, 40,  0, "the BACK hand's spot: cm toward the nose (+) or the tail (-) from the mod's own spot", true },
        { "Hand2", "Across",16, -40, 40,  0, "the BACK hand's spot: cm toward your toes (+) or heels (-)", true },
        { "Hand2", "Up",    17, -40, 40,  0, "the BACK hand's spot: cm off the deck (+) or into it (-)", true },
        { "Via2", "Along",  18, -60, 60,  0, "the BACK hand's path: its via point, cm toward the nose (+)", true },
        { "Via2", "Across", 19, -60, 60, 12, "the BACK hand's path: its via point, cm toward your toes (+) / heels (-)", true },
        { "Via2", "Up",     20, -60, 60, 13, "the BACK hand's path: its via point, cm up (+)", true },
        { "Fold", "",      21,   0, 85, 14, "the most the back may fold forward (degrees, spread over the spine) so that BOTH hands reach; the search uses the least it needs", true },
        -- (v110) the deck's roll about its long axis; (v113) RELATIVE to the game's own pose, which rolls a regular Nose some 20 deg so the hand wraps the edge
        { "DeckRoll", "",  22, -45, 45,  0, "degrees ADDED to the roll the game's own pose gives the deck in the grab: + the toe-side edge further up, - the heel-side; 0 = as the game poses it (a regular Nose rolls ~20, switch ~0). The same number in both stances" },
        -- (v111) the elbow: with the shoulder and the hand set, swinging the elbow round the reach line is what makes the forearm hang steeper or flatter
        { "Elbow", "",     23, -90, 90,  0, "degrees the grabbing elbow is swung round the line from shoulder to hand: + one way, - the other (the forearm steeper or flatter; 0 = as the arm solver has it)" },
        -- (v111) riding SWITCH add-ons for the DECK too: the game's switch grab poses hold the board differently from the regular ones
        { "SwTilt", "",   106, -60, 80,  0, "riding SWITCH, added to the board's tilt (Tilt): degrees more (+) or less (-) the rising end stands up in switch" },
        { "SwDeckRoll", "",122, -45, 45, 0, "riding SWITCH, added on top of DeckRoll: + the toe-side edge further up in switch (20 brings a switch Nose up to about the regular one's roll)" },
        -- (v103) riding SWITCH: the game's switch animation reaches differently, so the same numbers put the hand elsewhere.
        -- These are ADDED to the hand's spot while you ride switch (the numpad writes them when you nudge in switch)
        { "SwHand", "Along", 100, -40, 40, 0, "riding SWITCH, added to the hand's spot: cm toward the nose (+) or the tail (-); 0 = the same as regular" },
        { "SwHand", "Across",101, -40, 40, 0, "riding SWITCH, added to the hand's spot: cm toward your toes (+) or heels (-)" },
        { "SwHand", "Up",    102, -40, 40, 0, "riding SWITCH, added to the hand's spot: cm off the deck (+) or into it (-)" },
        { "SwHand2", "Along",115, -40, 40, 0, "riding SWITCH, added to the BACK hand's spot: cm toward the nose (+)", true },
        { "SwHand2", "Across",116,-40, 40, 0, "riding SWITCH, added to the BACK hand's spot: cm toward your toes (+)", true },
        { "SwHand2", "Up",   117, -40, 40, 0, "riding SWITCH, added to the BACK hand's spot: cm off the deck (+)", true },
    }
    -- GRAB_TUNED_BEGIN (written by tools/snapshot_defaults.pl from the author's ExpandedTricks.ini -- do not edit by hand)
    -- THE RELEASE'S TUNED GRABS: per grab, only the numbers that differ from the rows above; a user's own ini still wins.
    NATIVE.GRAB_TUNED = {
        Nose = { Drop = 2, HandAcross = -2, HandAlong = 7, HandUp = 10, Lift = 2, RollBack = 10, SwHandAlong = -3, SwHandUp = -2, SwTilt = 15, Tilt = 17 },
        Melon = { Back = 15, Drop = 0, HandUp = 6, Lift = 0 },
        Mute = { HandUp = 6, SplayFront = 25, ViaAlong = 20 },
        Seatbelt = { HandAcross = 3, HandAlong = -4, HandUp = 9, SwHandUp = 8, SwTilt = -20, ViaAcross = 30, ViaAlong = 30, ViaUp = 10 },
        Tail = { HandAcross = 1, HandAlong = -7, HandUp = 9, Lift = 3, RollFront = 40, SwHandAcross = 2, SwHandAlong = 4, Tilt = 30, ViaAcross = 50, ViaAlong = -60, ViaUp = 10 },
        Stalefish = { Back = 10, Drop = 0, HandAlong = -3, HandUp = 6, Lift = 2, SwHandUp = 5, Tilt = -10 },
        Indy = { Drop = 0, HandAlong = 3, HandUp = 6, Lift = 0, RollBack = -20, RollFront = 0, SplayBack = -40, Tilt = -30, ViaAcross = 40, ViaAlong = 40, ViaUp = 0 },
        Crail = { HandAlong = 4, HandUp = 9, Tilt = 45, ViaAcross = 50, ViaAlong = 5, ViaUp = 10 },
        Cannonball = { Back = -5, Drop = 1, Fold = 10, Hand2Along = -3, Hand2Up = 8, HandAlong = 3, HandUp = 8, Lift = 19, RollBack = -10, RollFront = -10, Slide = 0, Via2Along = -30, ViaAlong = 60 },
        Gorilla = { Drop = 15, Hand2Along = 16, Hand2Up = 7, HandAlong = 15, HandUp = 6, Lift = -10, RollBack = 0, RollFront = 0, SplayBack = 50, SplayFront = 40, SwHand2Along = -8, SwHandAlong = -8, Via2Across = 35, ViaAcross = 25 },
        Rocket = { Hand2Across = 7, Hand2Along = 3, Hand2Up = 8, HandAcross = -11, HandAlong = 3, HandUp = 5, Lift = -10, RollBack = 60, RollFront = -60, SplayBack = -40, SplayFront = 40, SwHand2Along = 1, SwHand2Up = 1, SwHandAcross = 2, SwHandUp = 1, Via2Across = 15, Via2Up = 10, ViaUp = 3 },
    }
    -- GRAB_TUNED_END
    for _, g in ipairs(NATIVE.GRABS) do
        for _, p in ipairs(NATIVE.PARAMS) do
            if not p[8] or g[2] >= 200 then
                local key = p[1] .. g[1] .. p[2]
                local tv = NATIVE.GRAB_TUNED and NATIVE.GRAB_TUNED[g[1]]   -- (v121) the author's tuned numbers, baked for a fresh install
                if S[key] == nil then S[key] = (tv and tv[p[1] .. p[2]]) or ((p[6] > 0) and g[p[6]] or 0) end
                SPEC[#SPEC + 1] = { key, "num", p[4], p[5], g[1] .. ((g[2] >= 200) and " (two hands) -- " or " grab -- ") .. p[7] }
            end
        end
    end
    NATIVE.DEF = {}                                      -- (v184) every setting as it ships, before any ini is read: the menu prints it ("Default: 95 cm.")
    for k, v in pairs(S) do NATIVE.DEF[k] = v end
end
local ensureHook                                                          -- the per-frame hook; defined further down

------------------------------------------------------------------- helpers
local function q(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

local function alive(x)
    if x == nil then return nil end
    -- (v83) IsValid READS the object's index first, and a level change can give a dead object's memory back to
    -- the OS before the 2 s watch looks (the apartment crash: an access violation at the old skater + 0xC, from
    -- inside UE4SS). The native half checks the page is still mapped before anything touches the object.
    if type(HJN_Readable) == "function" then
        local a = q(function() return x:GetAddress() end, nil)
        if a == nil or tonumber(HJN_Readable(a)) ~= 1 then return nil end
    end
    if q(function() return x:IsValid() end, false) then return x end
    return nil
end

local function log(s)
    local f = io.open(LOG, "a")
    if f then f:write(os.date("%H:%M:%S ") .. s .. "\n") f:close() end
end

local onceLog = {}
local function logOnce(key, msg) if not onceLog[key] then onceLog[key] = true log(msg) end end
-- (v185) THE MOD'S OWN GAME-THREAD QUEUE. On 5 Oct, from 17:35:38 to the end of the session, UE4SS ran nothing more of what
-- the mod handed to ExecuteInGameThread while its timers and the frame hook went on: 31 Y presses and 20 stick clicks in
-- SessionTweaks' log met no line of ours ("it's blocking throwdowns ... now blocking hippie jumps"), and the 2 s tick
-- that writes the speed, the push, the no comply's numbers and the native half's switches never came again ("most of
-- these options are not working": SpeedScale 3.0 -> 0.5 at 17:43:48, no 'speed:' line after it). Everything goes through
-- this queue now. UE4SS is still asked to run it; when the oldest entry has waited 0.3 s the frame hook runs it instead
-- (it is on the game thread too) and says so once. The one thing that must not run inside the animation update -- the
-- ragdoll of a hop's bail -- is dropped in that case (the hop is landed).
NATIVE.GT = { q = {} }
NATIVE.gtDrain = function(hook)
    local G = NATIVE.GT
    if G.busy then return end
    G.busy = true
    if not hook then
        G.servedAt = os.clock()
        if G.fallback then
            log(string.format("game thread: UE4SS runs the mod's queued actions again (%.1f s after it stopped)", os.clock() - G.fallback))
            G.fallback = nil
        end
    end
    for _ = 1, #G.q do
        local it = table.remove(G.q, 1)
        if not it then break end
        if hook and it[2] then
            log("game thread: " .. tostring(it[2]) .. " is not run from the frame hook -- dropped")
            if it[4] then pcall(it[4]) end
        else
            G.running = it[2] or "an action"
            local ok, err = pcall(it[1])
            G.running = nil
            if not ok then log("game thread: an action failed: " .. tostring(err)) end
        end
    end
    G.busy = false
end
NATIVE.gt = function(fn, tag, onDrop)
    local G = NATIVE.GT
    local now = os.clock()
    G.q[#G.q + 1] = { fn, tag, now, onDrop }
    if G.fallback and now - (G.probeAt or 0) < 5 then return end      -- (UE4SS is asked again every 5 s: should it come back, it is used)
    G.probeAt = now
    local ok, err = pcall(ExecuteInGameThread, function() NATIVE.gtDrain(false) end)
    if not ok and not G.errTold then G.errTold = true log("game thread: ExecuteInGameThread itself failed: " .. tostring(err)) end
end
NATIVE.gtPump = function()                              -- every frame, from the hook
    local G = NATIVE.GT
    local it = G.q[1]
    if not it then return end
    local now = os.clock()
    if now - it[3] < (G.fallback and 0.05 or 0.3) then return end   -- (review) once UE4SS is known to be away the wait is not paid on every input
    if not G.fallback then
        G.fallback = now
        log(string.format("game thread: UE4SS has not run the mod's queued actions for %.1f s (%d waiting; it last ran them %s%s) -- the frame hook runs them from here on",
            now - it[3], #G.q, G.servedAt and string.format("%.1f s ago", now - G.servedAt) or "never", G.running and (", and one was still running: " .. tostring(G.running)) or ""))
    end
    NATIVE.gtDrain(true)
end

local function skater()
    local s = alive(cached)
    if s then return s end
    -- (v140) SEVERAL SKATERS: the game's filmer mode has your own and the replay's on the map at once, and FindFirstOf gave
    -- whichever came first (a hop on the replay's skater was the "chaos"). The player-controlled one is yours
    local all = q(function() return FindAllOf("SkaterCharacter") end, nil) or {}
    local pick, names = nil, {}
    for _, o in ipairs(all) do
        if alive(o) then
            local pcd = q(function() return o:IsPlayerControlled() end, false) == true
            names[#names + 1] = (q(function() return o:GetFName():ToString() end, "?")) .. (pcd and " (player)" or "")
            if pcd and not pick then pick = o end
        end
    end
    if #all > 1 then log(string.format("skaters on the map: %d (%s) -- taking %s", #all, table.concat(names, ", "), pick and "the player-controlled one" or "the first")) end
    cached = alive(pick) or alive(q(function() return FindFirstOf("SkaterCharacter") end))
    return cached
end

local function addr(o) return q(function() return o:GetAddress() end, nil) end

local function refs()
    s0 = skater()
    if not s0 then s0, mesh, inst, mv = nil, nil, nil, nil return false end
    mesh = alive(q(function() return s0.Mesh end))
    inst = mesh and alive(q(function() return mesh:GetAnimInstance() end)) or nil
    mv   = alive(q(function() return s0:GetSkaterMovement() end))
    return mesh ~= nil
end

-- THE REVERT SOUND of our 180s. ASkateboardEx::PlayRevertSound plays USkateboardAudioDataAsset's
-- _revertSoundCue and skips a null one. The board audio assets are found once (at a quiet moment, from the
-- 2 s loop -- FindAllOf is too slow for a landing) and kept as ADDRESSES only; the native half clears the
-- cue field while our 180 lands and puts it back after, checking the field holds what we expect first.
-- The game's own reverts keep their sound.
NATIVE.audio = nil                         -- { { assetAddress, cueAddress }, ... } once found
NATIVE.findAudio = function()
    local list = {}
    local all = q(function() return FindAllOf("SkateboardAudioDataAsset") end, nil)
    for _, asset in ipairs(all or {}) do
        local cue = alive(q(function() return asset._revertSoundCue end))
        local a, c = addr(asset), cue and addr(cue)
        if a and c then list[#list + 1] = { a, c } end
    end
    NATIVE.audio = list
    log(string.format("revert sound: %d board audio asset(s) found for muting our 180s", #list))
end
NATIVE.mute = function(on)
    if type(HJN_MuteRevert) ~= "function" then return end
    if on then
        if NATIVE.muted or S.MuteRevertSound == 0 or not NATIVE.audio then return end
        local n = 0
        for _, p in ipairs(NATIVE.audio) do n = n + (tonumber(HJN_MuteRevert(p[1], p[2], 1)) or 0) end
        NATIVE.muted = true
        if n == 0 then logOnce("mutefail", "   revert sound: could not mute (the audio asset changed?) -- looking again") NATIVE.audio = nil end
    elseif NATIVE.muted then
        for _, p in ipairs(NATIVE.audio or {}) do HJN_MuteRevert(p[1], p[2], 0) end
        NATIVE.muted = nil
    end
end

local function crouching()
    return inst ~= nil and q(function() return inst.IsCranking end, false) == true
end

NATIVE.rawMode = function() return q(function() return mv.CustomMovementMode end, -1) end
-- (v132) THE GAME'S FILMER MODE keeps the skater in custom mode 6 the whole run, riding or airborne -- the number the replay
-- editor shows as well. You are live when the player controller still drives your skater (in the editor it drives a camera)
NATIVE.liveIn6 = function()
    -- (v149) MODE 6 IS THE GAME'S REPLAY -- its editor and its filmer camera. The skater there is played back, never driven:
    -- the mod stands by. (v140-v148 took "the controller's pawn is our skater" for live; it always is, also in the editor --
    -- so a stick click there could hop the replay's skater.) What "the stick clicks do not work in filmer mode" was: the
    -- editor's own L3 / R3 (switch to the filmer camera, clip start / end, scrub speed) swallowed by SessionTweaks'
    -- click-to-catch; the native half now hands them to the game there (v67) and keeps them from this script
    return false
end
local function modeNow()
    local cm = NATIVE.rawMode()
    -- (v130) AFTER A SPAWN the game can sit in ToSkateboarding (4) while you already roll, pop and land -- for a while, or
    -- until a bail resets it. Everything gated on AIR (the grabs, from the bumper press on) was dead in that limbo: "the
    -- grabs don't work on spawn until I bail". On the board in that mode, the anim's own wheel contact says air or riding.
    -- (v132) The same for filmer mode's 6 while you are live. During the mod's own hop the wheel flag is the mod's own
    -- (airPose clears it), so that reads as riding, as the game's own mode would
    if (cm == MODE_TO_BOARD or (cm == 6 and NATIVE.liveIn6())) and q(function() return mv._isOnBoard end, false) == true then
        if active then return MODE_RIDING end
        -- (v136) THE BOARD'S OWN MOVEMENT MODE says ground or air (1 rolling, 3 falling): in filmer mode the anim's wheel
        -- flag read false while rolling, so every click was "not rolling on the ground (mode=2)" and a grab ran 110 s
        if type(HJN_BoardState) == "function" then
            local bs = tonumber(HJN_BoardState()) or -1
            local bmode = (bs >= 0) and ((bs >> 4) & 0xff) or -1
            if bmode == 1 then return MODE_RIDING elseif bmode == 3 then return MODE_AIR end
        end
        return (q(function() return inst.IsGroundedWheels end, true) == false) and MODE_AIR or MODE_RIDING
    end
    return cm
end

local function stateNow()
    if not inst then return "?" end
    local st    = q(function() return inst:GetActiveStateName():ToString() end, "?")
    local board = q(function() return inst:GetCurrentStateName(5):ToString() end, "?")
    return st .. " | onboard-machine: " .. board
end

local function stanceNow()
    local fp = q(function() return s0:GetCurrentFootPosition() end, "?")
    local sw = q(function() return s0:IsSkatingSwitch() end, "?")
    return string.format("footPosition=%s switch=%s", tostring(fp), tostring(sw))
end

local function smooth(x)
    if x <= 0 then return 0 elseif x >= 1 then return 1 end
    return x * x * (3 - 2 * x)
end

local function actorZ()
    return q(function() return s0:K2_GetActorLocation().Z end, nil)
end

local function actorXYZ()
    local l = q(function() return s0:K2_GetActorLocation() end)
    if not l then return nil end
    return q(function() return l.X end, 0), q(function() return l.Y end, 0), q(function() return l.Z end, 0)
end

-- world Z of a socket on the skater mesh (last evaluated pose). FName() is UE4SS's constructor.
local fnames = {}
local function fname(name)
    if fnames[name] == nil then
        logOnce("fn" .. name, "   TRY FName " .. name .. " (first time)")
        fnames[name] = q(function() return FName(name) end, false)
    end
    return fnames[name] or nil
end

local function socketZ(name)
    local n = fname(name)
    if not n then return nil end
    return q(function() return mesh:GetSocketLocation(n).Z end, nil)
end

-- your board's deck: the "Flipper" part of the PBP_SkateboardEx_C nearest to you (co-op peers'
-- boards are elsewhere; the actor's own root does not follow the physics -- F7 showed it
-- hundreds of metres from the parts). Found once, kept while it stays valid. Read-only: its
-- pitch shows whether a slow roll-off made the board nose-dive.
local BD = { comp = nil, maxAir = 0 }
local function findFlipper()
    if alive(BD.comp) then return BD.comp end
    BD.comp = nil
    local ok = pcall(function()
        local all = FindAllOf("PBP_SkateboardEx_C")
        local pcls = StaticFindObject("/Script/Engine.PrimitiveComponent")
        local here = s0:K2_GetActorLocation()
        local ax, ay, az = here.X, here.Y, here.Z
        if type(all) ~= "table" or not pcls then return end
        local bestD = 1e18
        for _, b in ipairs(all) do
            local list = b:K2_GetComponentsByClass(pcls)
            local n = list and (q(function() return #list end, nil) or q(function() return list:GetArrayNum() end, 0)) or 0
            for i = 1, n do
                local c = list[i]:get()
                if c and c:IsValid() and c:GetFName():ToString() == "Flipper" then
                    local l = c:K2_GetComponentLocation()
                    local dx, dy, dz = l.X - ax, l.Y - ay, l.Z - az
                    local d = dx * dx + dy * dy + dz * dz
                    if d < bestD then BD.comp, bestD = c, d end
                    break
                end
            end
        end
    end)
    if not ok then BD.comp = nil end
    logOnce("flipper" .. tostring(BD.comp ~= nil), BD.comp and "   board deck found (its tilt is logged in drops)"
                                                        or "   board deck NOT found -- no tilt in the log")
    return BD.comp
end

local function boardPitch()
    local c = BD.comp
    if not c then return nil end
    return q(function() return c:K2_GetComponentRotation().Pitch end, nil)
end

-- " (board tipped N deg)" for the log when a drop made the deck tilt
local function tiltNote()
    if BD.maxAir < 5 then return "" end
    return string.format(" (board tipped up to %.0f deg in the drop)", BD.maxAir)
end

------------------------------------------------------------------- game settings
-- Session's Advanced sliders live in UOptionsSaveGame.AdvancedSettingsPresets
-- .Presets[ActivePresetIndex] (FAdvancedSettings, PDB-confirmed). That object is only
-- alive around settings load/save, so values are read opportunistically and cached.
local advCache = {}
local function readAdvanced(field)
    local opts = alive(q(function() return FindFirstOf("OptionsSaveGame") end))
    if not opts then return advCache[field], "cached/none" end
    local p   = q(function() return opts.AdvancedSettingsPresets end)
    local idx = p and q(function() return p.ActivePresetIndex end) or nil
    local arr = p and q(function() return p.Presets end) or nil
    if not idx or not arr then return advCache[field], "cached/none" end
    local e = q(function() return arr[idx + 1] end)          -- UE4SS arrays are 1-based
    local v = e and (q(function() return e[field] end) or q(function() return e:get()[field] end)) or nil
    if type(v) == "number" then advCache[field] = v return v, "preset " .. tostring(idx) end
    return advCache[field], "cached/none"
end

-- once per session: the game's own numbers the switch landing depends on
local gameNumbersLogged = false
local function logGameNumbers()
    if gameNumbersLogged then return end
    gameNumbersLogged = true
    local db = alive(q(function() return FindFirstOf("RevertsDatabase") end))
    if db then
        log(string.format("   game reverts: RevertRotationRate=%s deg/s  RevertEndDelay=%s s  (%s)",
            tostring(q(function() return db.RevertRotationRate end, "?")), tostring(q(function() return db.RevertEndDelay end, "?")),
            q(function() return db:GetFullName() end, "?")))
    else
        log("   game reverts: RevertsDatabase not found")
    end
    local cfg = alive(q(function() return mv.SkaterConfig end))
    if cfg then
        log(string.format("   game bail limits: board sideways to its travel > %s..%s deg (slow..fast) above %s cm/s",
            tostring(q(function() return cfg.BailingLandingMinSpeedAngle end, "?")),
            tostring(q(function() return cfg.BailingLandingMaxSpeedAngle end, "?")),
            tostring(q(function() return cfg.BailingMinSpeed end, "?"))))
    end
end

local gravityTried = false
local function gameGravity()
    if not gravityTried then gravityTried = true log("   TRY read game gravity (first time)") end
    -- MEASURED: GetGravityZ already includes the Gravity slider (-1127 = -980 x 1.15).
    local gz   = q(function() return mv:GetGravityZ() end, nil)
    local g = math.abs(gz or -980) * S.GravityFactor
    logOnce("grav" .. tostring(gz) .. S.GravityFactor, string.format(
        "   gravity: GetGravityZ=%s (includes the slider) x GravityFactor %g -> %.0f cm/s2", tostring(gz), S.GravityFactor, g))
    return g
end

------------------------------------------------------------------- sounds
local soundCache, soundBroken = {}, false
local statics = nil

local function soundAsset(path)
    if soundCache[path] ~= nil then return soundCache[path] or nil end
    logOnce("find" .. path, "   TRY find sound " .. (path:match("[^%.]+$") or path))
    local s = alive(q(function() return StaticFindObject(path) end))
    if not s then
        logOnce("load" .. path, "   TRY LoadAsset (not in memory yet)")
        pcall(function() LoadAsset(path) end)
        s = alive(q(function() return StaticFindObject(path) end))
    end
    soundCache[path] = s or false
    logOnce("res" .. path, string.format("   sound %s -> %s", path:match("[^%.]+$") or path, s and "loaded" or "NOT FOUND"))
    return s
end

local function playSound(path, vol)                  -- (v114) vol: the drop-in's own volume; the hippie jump's SoundVolume otherwise
    if soundBroken or S.Sounds == 0 or not path or path == "" then return end
    vol = vol or S.SoundVolume
    local snd = soundAsset(path)
    if not snd then return end
    statics = statics or alive(q(function() return StaticFindObject("/Script/Engine.Default__GameplayStatics") end))
    if not statics then soundBroken = true log("   sound: GameplayStatics not found -- sounds off") return end
    local ok, err
    if S.Sound2D ~= 0 then
        logOnce("p2d", "   TRY PlaySound2D (first time)")
        ok, err = pcall(function() statics:PlaySound2D(s0, snd, vol, 1.0, 0.0, nil, nil, false) end)
    else
        local x, y, z = actorXYZ()
        logOnce("p3d", "   TRY PlaySoundAtLocation (first time)")
        ok, err = pcall(function()
            statics:PlaySoundAtLocation(s0, snd, { X = x or 0, Y = y or 0, Z = z or 0 }, { Pitch = 0, Yaw = 0, Roll = 0 },
                vol, 1.0, 0.0, nil, nil, nil)
        end)
    end
    if not ok then soundBroken = true log("   sound FAILED, sounds off for this session: " .. tostring(err)) end
end

------------------------------------------------------------------- the pose
-- From the decompiled ABP_AMXX_Skater state machines: a crouch holds the graph in
-- "Crank State", which exits to the standing "Idle Skate State" once IsCranking and
-- IsTrickPending are false (0.33s blend). From Idle, IsFalling AND IsLanding enters
-- "Street Trick PreLand State" -- the ollie in-air loop. USkaterAnimInstance recomputes
-- every one of these natively each frame BEFORE our hook, so writes stick for that frame
-- and stopping restores the game by itself. ONLY anim-instance fields are written: the
-- skater's gameplay crouch flag (_isCranking) broke powerslides when we touched it.
local BLOCKERS = {
    "IsCranking", "IsTrickPending", "IsPushing", "IsKickTurnLeft", "IsKickTurnRight",
    "IsInManual", "IsInNoseManual", "IsInPowerslideStance", "IsInPrimo", "IsGrinding",
    "IsGrindingInLiptrick", "IsInCasper", "IsInAntiCasper", "HasLateTrick",
}

local function standUp()
    if not inst then return end
    for i = 1, #BLOCKERS do
        local k = BLOCKERS[i]
        q(function() inst[k] = false end)
    end
    q(function() inst.CrankPocketRatio = 0.0 end)
end

local function footIK(alpha)
    q(function() inst.LeftFootIKAlpha  = alpha end)
    q(function() inst.RightFootIKAlpha = alpha end)
end
-- (v167) THE HOP'S FOOT PULL, FADED WITH THE TURN. "The mini jump is definitely jarring: quite a bit of a suck up on the way
-- up, and then it stretches on the way down." Both mini hops in that log were 180s: the mini's pull (MiniFootPull 0.35,
-- the game's foot IK toward the board's sockets) was cut to 0 in ONE frame as the body passed 90 deg -- the sockets are on
-- the wrong sides from there -- and the legs went from 70/64 cm to 47/32 on the next pose, then back down over the landing.
-- Now the game's pull fades out between 20 and 80 deg of turn, and the native half (v83, HJN_Air's second number: the pull
-- wanted) lets each foot down by the share the game no longer gives, in height only: the feet stay as low through a 180
-- as in a straight mini hop. The crouched hop has no pull: nothing changes there.
NATIVE.hopPull = function()
    local p = P.footPull or 0
    if p <= 0 then return 0 end
    local a = math.abs(yawAcc)
    if a <= 20 then return p end
    if a >= 80 then return 0 end
    local f = (80 - a) / 60
    return p * f * f * (3 - 2 * f)
end

-- (v168) THE REACH FOR THE BOARD, AS A NUMBER FOR THE NATIVE HALF (the same 0..LegReachMax airPose gives the game). The
-- game's pose follows its LandHeightRatio only riding SWITCH; riding regular the legs stayed in the tuck to the last pose of
-- the air and went straight in one pose at touchdown (every regular hop traced). The native half (v84) makes the reach
-- itself, in either stance.
NATIVE.hopReach = function(frac)
    if S.Pose == 0 or frac <= S.LegReachStart or S.LegReachStart >= 1 then return 0 end
    local r = (frac - S.LegReachStart) / (1 - S.LegReachStart)
    if r > 1 then r = 1 end
    return r * r * S.LegReachMax
end
-- (v170) ...and, for the native half's v86: the reach as 0..1 (how much of the way to its LANDING SPOT a foot is carried), and
-- whether the body's turn so far lands a half turn round (then each foot goes to the other foot's spot)
NATIVE.hopReach01 = function(frac)
    if S.Pose == 0 or frac <= S.LegReachStart or S.LegReachStart >= 1 then return 0 end
    local r = (frac - S.LegReachStart) / (1 - S.LegReachStart)
    if r > 1 then r = 1 end
    return r * r
end
NATIVE.hopFlip = function()
    local y, sure = yawAcc, true
    -- (v94) the native half plans the feet's landing spots from this: it has to say how the hop will LAND -- the turn's
    -- target once it is locked or assisted; before that where its speed takes it, and that is a guess (+ 2): the native
    -- half carries no foot to a spot on a guess, nor for a turn that is heading for no landing at all (a bail)
    if (S.HopPlan or 0) > 0 then
        local H = NATIVE.spinH
        if assistFrom then y = assistTarget
        elseif H and H[1] and H[5] and H[1] - H[5] > 0.01 and H[1] - H[5] < 0.25 then
            local rate = (H[2] - H[6]) / (H[1] - H[5])
            if math.abs(rate) >= 40 then y, sure = H[2] + rate * (1 - H[1]), false end
        end
        local r = math.abs(y - 360 * math.floor(y / 360 + 0.5))
        if r > S.VarialLandWindow and r < 180 - S.VarialLandWindow then sure = false end
    end
    -- (v184 / native v100) HOW FAR THE BODY STILL HAS TO TURN to the heading it lands on. "The 180 mini hippie jumps: he's
    -- landing way off the board. He used to be dead on." Since v95 a hop that turns was not carried to its landing spots at all
    -- (the carry had the feet there with 40 deg of the turn to go): it came down where the mini hop keeps its feet under the
    -- hips -- 23 and 25 cm off the deck's middle line in the recording of 5 Oct 14:25:45. The native half now carries a turned
    -- hop's feet by the share of its turn that is done (HopCarryTurn), and this is the number it goes by; 999 = not known
    NATIVE.turnLeft = sure and math.abs(180 * math.floor(y / 180 + 0.5) - (yawAcc or 0)) or 999
    local half = math.floor(math.abs(y) / 180 + 0.5)
    if half >= 2 and (S.HopCarry or 1) == 1 and (S.HopCarryTurn == 0 or (tonumber(NATIVE.v) or 0) < 100) then sure = false end   -- (v179) a full turn is a hop that turns too: with HopCarry 1 no foot is carried to a spot (+ 2 = the native half's 'no spots')
    return ((half % 2 == 1) and 1 or 0) + (sure and 0 or 2)
end
local function airPose(frac)
    if not inst then return end
    standUp()
    q(function() inst.IsFalling        = true  end)
    q(function() inst.IsLanding        = true  end)
    q(function() inst.IsGrounded       = false end)
    q(function() inst.IsGroundedWheels = false end)
    q(function() inst.IsJustLanded     = false end)
    q(function() inst.RevertType       = 0 end)
    q(function() inst.GrabState        = 0 end)
    q(function() inst.CatchOrientState = 0 end)
    -- legs reach for the board only near touchdown. Ramping this over the whole descent
    -- (from the apex) straightened the legs while still 60+cm up -- the "feet warp to the
    -- board" in the screenshot.
    local reach = 0
    if frac > S.LegReachStart then reach = (frac - S.LegReachStart) / (1 - S.LegReachStart) end
    -- (v164) slowly at first, fastest at touchdown: the even ramp over the last fifth of the air had the legs go from tucked
    -- to straight in two or three frames (the two stills of 22:37, two frames apart)
    -- (v165) "move the stretch point further down in the landing ... much closer to the board": back to the last fifth of
    -- the air (v164's 0.6 had the legs stretching while still high), squared -- half the reach in the last 6 % of it
    -- (v169) NOT RIDING REGULAR. The traces of 4 Oct 12:07-12:09: riding switch or fakie the game's pose answers this number by
    -- bending the knee (the bones stay 84 cm); riding regular (foot position 1) it SHRINKS the leg's bones instead, 84 cm to
    -- 70 over the last five poses of the air, and they snap back on the touchdown pose -- "the feet warp toward the end of
    -- the trick, when he's landing". There the native half's own reach does all of it (the same curve, HJN_Air's third number).
    local fpNow = q(function() return inst.FootPositionType end, nil)
    q(function() inst.LandHeightRatio  = (fpNow == 1) and 0.0 or (reach * reach) * S.LegReachMax end)
    q(function() inst.FlipTrickPopRatio            = 1.0 end)
    q(function() inst.FlipTrickStanceTransferRatio = 0.0 end)
    -- the feet's IK targets are anchors on the skeleton's board bone, which is held at the
    -- real board's height: 0 = the free in-air tuck, more = the feet stay down toward the board
    -- (v74: once the body has turned past 90 the deck's foot sockets are on the wrong sides -- pulling the feet
    -- to them wound the legs up like a tornado toward the landing: no pull then)
    footIK(NATIVE.hopPull())                                 -- (v167: faded with the turn, not cut at 90)
    local lfp = q(function() return inst.LandingFootPositionType end, nil)
    if lfp == 0 then
        local fp = q(function() return inst.FootPositionType end, nil)
        if fp then q(function() inst.LandingFootPositionType = fp end) end
    end
end

------------------------------------------------------------------- landing absorb
-- LandDropHeightRatio (USkaterAnimInstance) picks how deep the "Street Trick Land State"
-- blendspace absorbs: low = the game's light Lo_Land, the stance's Hi sample = its full
-- ollie-landing crouch (knees, torso, arms). Anim-only, no gameplay effect. The Hi sample
-- sits at a different Y per stance (1 Regular, 2 Fakie, 3 Nollie, 4 Switch).
local HI_Y = { [1] = 0.375, [2] = 0.5, [3] = 0.5, [4] = 0.5 }

local function absorbRatio(a, st)
    local hi = HI_Y[st] or 0.5
    if a <= 1 then return hi * a end
    return math.min(1.0, hi + (1.0 - hi) * (a - 1.0))
end

local function landAbsorbStart()
    if P.absorb <= 0 or not inst then return end
    LA.t0 = os.clock()
    LA.amount = P.absorb
    LA.saved = q(function() return inst.LandDropHeightRatio end, 0)
    local st = q(function() return inst.LandingFootPositionType end, nil)
    if type(st) ~= "number" or st < 1 or st > 4 then
        local fp = q(function() return inst.FootPositionType end, nil)
        st = (type(fp) == "number" and fp >= 1 and fp <= 4) and fp or 1
        q(function() inst.LandingFootPositionType = st end)
    end
    LA.stance = st
end

local function landAbsorbTick()
    if not LA.t0 or not inst then return end
    local dt = os.clock() - LA.t0
    LA.say = LA.say or function(when)                    -- (v180) for the log: riding regular the game's rig squeezes the front shin after a hop, and not after its own ollies
        log("   " .. when .. ": " .. stateNow() .. " | LandHeightRatio " .. tostring(q(function() return inst.LandHeightRatio end, "?"))
            .. ", LandDropHeightRatio " .. tostring(q(function() return inst.LandDropHeightRatio end, "?"))
            .. ", foot position " .. tostring(q(function() return inst.FootPositionType end, "?")) .. " (landing " .. tostring(q(function() return inst.LandingFootPositionType end, "?")) .. ")"
            .. ", IsLanding " .. tostring(q(function() return inst.IsLanding end, "?")) .. ", IsJustLanded " .. tostring(q(function() return inst.IsJustLanded end, "?"))
            .. ", foot IK L " .. tostring(q(function() return inst.LeftFootIKAlpha end, "?")) .. " R " .. tostring(q(function() return inst.RightFootIKAlpha end, "?")))
    end
    if dt > 0.3 and LA.toldAt ~= LA.t0 then LA.toldAt = LA.t0 LA.say("0.3 s into the landing") end
    local trick   = q(function() return inst.IsTrickPending end, false)
    local grind   = q(function() return inst.IsGrinding end, false)
    local falling = q(function() return inst.IsFalling end, false)
    if dt > S.LandAbsorbTime or trick or grind or (dt > 0.05 and falling) then
        LA.say(string.format("the landing's absorb ends after %.2f s", dt))
        if LA.saved then q(function() inst.LandDropHeightRatio = LA.saved end) end
        LA.t0 = nil
        return
    end
    q(function() inst.LandDropHeightRatio = absorbRatio(LA.amount, LA.stance) end)
end

------------------------------------------------------------------- body yaw
-- The game re-commits whatever mesh yaw it is given (it never resets it), so every offset
-- we put there must be taken back explicitly.
-- commit = also push it into the mesh's transform now (K2_SetRelativeRotation). A plain write only
-- reaches the screen when the capsule next moves -- next frame. Use it where the skater actor has just
-- turned THIS frame (the revert hold): the v64 trace showed the actor's turn lands before our hook.
local function setYaw(offset, commit)
    if not mesh then return end
    q(function() mesh.RelativeRotation.Yaw = yaw0 + offset end)
    if commit then
        local p = q(function() return mesh.RelativeRotation.Pitch end, 0.0)
        local r = q(function() return mesh.RelativeRotation.Roll end, 0.0)
        q(function() mesh:K2_SetRelativeRotation({ Pitch = p, Yaw = yaw0 + offset, Roll = r }, false, {}, false) end)
    end
end

-- after touchdown the body twists the last few degrees into line with the board
local function yawSettleTick()
    if not YS.t0 or not mesh then return end
    local k = (YS.len > 0) and smooth((os.clock() - YS.t0) / YS.len) or 1
    if k >= 1 then
        YS.t0 = nil
        setYaw(0)
        return
    end
    setYaw(YS.residual * (1 - k))
end

-- bigger leftovers take longer
local function startSettle(residual)
    if math.abs(residual) <= 0.5 then setYaw(0) return end
    YS.residual = residual
    YS.t0 = os.clock()
    YS.len = S.VarialSettleTime * math.max(1, math.abs(residual) / 45)
    setYaw(residual)                       -- this frame too: no one-frame snap
end

------------------------------------------------------------------- height + lift
local function heightAt(frac)
    local h = P.height
    local y = gravityUsed and (h * 4 * frac * (1 - frac)) or (h * math.sin(frac * math.pi))
    -- a mini hop leaves from its dip: spring up out of it over the first quarter of the air
    if P.dip > 0 and frac < 0.25 then y = y - P.dip * (1 - smooth(frac / 0.25)) end
    return y
end

-- Write (or reset, dz = nil) an additive component-space translation on one of the anim
-- blueprint's ModifyBone nodes. First use of each node is breadcrumbed.
local abpChecked, abpOk = nil, false
local function nodeLift(node, dz, dx, dy)          -- dx, dy: optional (component space)
    -- the nodes are properties of ABP_AMXX_Skater_C only; reading a property a class does not
    -- have can hard-crash, so check the anim instance's class first (once per instance)
    if abpChecked ~= inst then
        abpChecked = inst
        local cls = q(function() return inst:GetClass():GetFName():ToString() end, "?")
        abpOk = (cls:find("ABP_AMXX_Skater", 1, true) ~= nil)
        logOnce("abp" .. cls, "   anim blueprint class: " .. cls .. (abpOk and "" or " -- NOT the skater ABP, node lift off"))
    end
    if not abpOk then return dz == nil end
    if dz == nil then
        if not nodeTouched[node] then return true end
        nodeTouched[node] = nil
        return pcall(function()
            local n = inst[node]
            n.Translation.X = 0.0
            n.Translation.Y = 0.0
            n.Translation.Z = 0.0
            n.TranslationMode = BMM_IGNORE
        end)
    end
    if not nodeTouched[node] then
        logOnce("node" .. node, "   TRY write " .. node .. ".Translation (first time)")
        local mode = q(function() return inst[node].TranslationMode end, "?")
        local space = q(function() return inst[node].TranslationSpace end, "?")
        logOnce("nodeinfo" .. node, string.format("   %s: TranslationMode=%s TranslationSpace=%s (1 = component)",
            node, tostring(mode), tostring(space)))
    end
    nodeTouched[node] = true
    return pcall(function()
        local n = inst[node]
        n.TranslationMode = BMM_ADDITIVE
        n.Translation.X = dx or 0.0
        n.Translation.Y = dy or 0.0
        n.Translation.Z = dz
    end)
end

-- dz > 0 lifts the body; dz < 0 dips it (with the board bone held and the game's own foot IK
-- pinning the feet to it, the legs bend: a real crouch)
local function applyLift(dz)
    lastDz = dz
    if liftMode == LIFT_BODY then
        if not nodeLift(NODE_BODY, dz) then
            if NATIVE.rawMode() ~= 6 then liftBroken[LIFT_BODY] = true end   -- (v140) not remembered from filmer mode
            log("   body lift write FAILED -- switching to LiftMethod 2 for this session")
            liftMode = LIFT_COUNTER
        else
            return
        end
    end
    if liftMode == LIFT_MESH and dz < 0 then dz = 0 end         -- a mesh dip would sink the feet
    q(function() mesh.RelativeLocation.Z = meshZ0 + dz end)
    if liftMode == LIFT_COUNTER then
        if not nodeLift(NODE_BOARD, -(dz + holdExtra)) then
            if NATIVE.rawMode() ~= 6 then liftBroken[LIFT_COUNTER] = true end   -- (v140) not remembered from filmer mode
            log("   board hold-down write FAILED -- switching to LiftMethod 0 for this session")
            liftMode = LIFT_MESH
        elseif dz > 0.5 then
            footIK(NATIVE.hopPull())
        end
    end
end

local function clearLift()
    nodeLift(NODE_BODY, nil)
    nodeLift(NODE_BOARD, nil)
    if mesh and meshZ0 then q(function() mesh.RelativeLocation.Z = meshZ0 end) end
    lastDz, holdExtra = 0, 0
end

-- body/board heights relative to the actor, read at the top of the pre-hook (last evaluated
-- pose on the last committed mesh transform)
local H = { head0 = nil, board0 = nil, checked = false }
local function heights()
    local az = actorZ()
    if not az then return nil, nil end
    local hz, bz = socketZ(SOCK_HEAD), socketZ(SOCK_BOARD)
    return hz and (hz - az) or nil, bz and (bz - az) or nil
end

-- BOARD HOLD, closed loop. The mesh lift is cancelled exactly by the counter-translation, but
-- the in-air pose itself carries the board bone up with the tucked feet (~37 cm), and in the
-- game's air that is where it pulls the real board. So measure where the board socket really
-- is against where it was at the start, and hold it down by that much more. The reading is of
-- last frame's pose with last frame's correction in it, so adding it on converges in a frame.
local function holdTick()
    if liftMode ~= LIFT_COUNTER or not H.board0 then return end
    local az, bz = actorZ(), socketZ(SOCK_BOARD)
    if not az or not bz then return end
    holdExtra = holdExtra + ((bz - az) - H.board0)
    if holdExtra < -40 then holdExtra = -40 elseif holdExtra > 120 then holdExtra = 120 end
end

-- checked once near the apex. If the body did not rise with LiftMethod 1 the bone write is not
-- reaching the pose; if the board socket rose with LiftMethod 2 the hold-down is not working.
local function liftCheck(frac)
    if H.checked or frac < 0.35 then return end
    H.checked = true
    local head, board = heights()
    if not head or not H.head0 then log("   lift check: sockets unreadable") return end
    local rise, want = head - H.head0, heightAt(frac)
    local bdrop = (board and H.board0) and (board - H.board0) or 0
    log(string.format("   lift check (method %d) at %.0f%%: head %+.0f cm (lift %.0f), board socket %+.0f cm (held down %.0f extra)",
        liftMode, frac * 100, rise, want, bdrop, holdExtra))
    if liftMode == LIFT_BODY and want > 20 and rise < 0.3 * want then
        if NATIVE.rawMode() ~= 6 then liftBroken[LIFT_BODY] = true end   -- (v140) not remembered from filmer mode
        log("   body lift is NOT reaching the pose -- switching to LiftMethod 2 for this session")
        nodeLift(NODE_BODY, nil)
        liftMode = LIFT_COUNTER
    elseif liftMode == LIFT_COUNTER and want > 20 and bdrop > 0.5 * want then
        if NATIVE.rawMode() ~= 6 then liftBroken[LIFT_COUNTER] = true end   -- (v140) not remembered from filmer mode
        log("   board bone is NOT held down (it rose with the body) -- switching to LiftMethod 0 for this session")
        nodeLift(NODE_BOARD, nil)
        liftMode = LIFT_MESH
    end
end

------------------------------------------------------------------- bail
-- The game's own impact bail: HandleOnMeshHit (reflected, bound to the mesh's hit event)
-- -> ImpactBailCheck -> Bail(). Needs |NormalImpulse| >= 10000 while rolling; the hit's bone
-- must not be a hand/arm (an empty hit = no bone). v57 passed nil for the two actor/component
-- arguments and the call never reached Bail (SessionTweaks logs every Bail on your skater and
-- showed none), so now every argument is a real object: the other "actor" is your own player
-- controller (anything that is neither you nor your board takes the impact path).
local bailBroken = false
local function doBail(why, residual)
    if bailBroken then return false end
    local other = alive(q(function() return s0:GetController() end))
    if not other then other = alive(q(function() return FindFirstOf("SessionPlayerController") end)) end
    if not other then log("   bail: no controller to use as the other actor -- landing it instead") return false end
    log(string.format("   BAIL (%s) -- TRY HandleOnMeshHit  (onBoard=%s falling=%s)", why,
        tostring(q(function() return mv._isOnBoard end, "?")), tostring(q(function() return mv:IsFalling() end, "?"))))
    BV.pending, BV.t0, BV.residual = true, os.clock(), residual
    -- THE HIT MUST NAME A BONE (v61 crash, EXCEPTION_ACCESS_VIOLATION reading 0x14): after the bail,
    -- HandleOnMeshHit runs ImpactAudioCheck, which for a hit with no MyBoneName asks FindClosestBone(
    -- Hit.ImpactPoint) and looks that bone up in a table the skater filled at BeginPlay -- with no
    -- null check. An empty hit put the "impact" at the world origin, so the closest bone was
    -- whichever part of the skeleton happened to face there; after the replay editor rebuilt things
    -- it was one the table did not know. So: the pelvis (a bone the table always has, and not a
    -- hand/arm, which ImpactBailCheck refuses), at the pelvis.
    local pelvis = fname("AMXX_Pelvis")
    local p = q(function() return mesh:GetSocketLocation(fname("AMXX_PelvisSocket")) end, nil)
    local px = p and q(function() return p.X end, 0) or 0
    local py = p and q(function() return p.Y end, 0) or 0
    local pz = p and q(function() return p.Z end, 0) or 0
    if not pelvis then log("   bail: no pelvis bone name -- landing it instead") BV.pending = false return false end
    -- not from inside this hook: a bail turns the mesh into a ragdoll, and we are in the middle of
    -- that very mesh's animation update. The next game tick is where a real hit would come from.
    -- v62 still crashed the same way (ImpactAudioCheck+0x17b): the named bone evidently does not
    -- survive UE4SS's table -> FHitResult conversion. HandleOnMeshHit runs ImpactAudioCheck only after
    -- a bail took, and ImpactAudioCheck returns at once when the skater's _audioData (reflected, +0x4e8)
    -- is null. Bail and everything it calls never read _audioData (checked in the disassembly), so it
    -- is nulled for exactly this one synchronous call and put back straight after -- no impact sound
    -- for our bail, no lookup, no crash. If the null does not take, there is no bail at all.
    local sk, m = s0, mesh
    NATIVE.gt(function()
        local audio = alive(q(function() return sk._audioData end))
        local nulled = false
        if audio then
            logOnce("audionull", "   TRY null _audioData around the bail (first time)")
            pcall(function() sk._audioData = nil end)
            nulled = not alive(q(function() return sk._audioData end))
        end
        if audio and not nulled then
            pcall(function() sk._audioData = audio end)
            BV.pending = false
            log("   bail SKIPPED: could not switch off the impact sound it would crash on -- landing it instead")
            startSettle(residual)
            return
        end
        local ok, err = pcall(function()
            local hit = { MyBoneName = pelvis, BoneName = pelvis,
                          ImpactPoint = { X = px, Y = py, Z = pz }, Location = { X = px, Y = py, Z = pz },
                          ImpactNormal = { X = 0.0, Y = 0.0, Z = 1.0 }, Normal = { X = 0.0, Y = 0.0, Z = 1.0 } }
            sk:HandleOnMeshHit(m, other, m, { X = 0.0, Y = 0.0, Z = 50000.0 }, hit)
        end)
        if audio then
            pcall(function() sk._audioData = audio end)
            if not alive(q(function() return sk._audioData end)) then log("   WARNING: _audioData did not come back after the bail") end
        end
        if not ok then
            bailBroken = true
            log("   bail call FAILED, bails off for this session: " .. tostring(err))
        end
    end, "the ragdoll of a hop's bail", function() BV.pending = false end)
    return true
end

------------------------------------------------------------------- carve block
-- The PC turns the triggers into BOTH the body spin (_currentRotationRate) and a board
-- banking target; the latter reaches the board through the reflected
-- MulticastRPCSetTargetBankingRatio right after the native set. Answering it with our own
-- ServerRPCSetTargetBankingRatio(0) zeroes the board's target before physics reads it.
local bankGuard, bankHooked, bankZeroed = false, false, 0
local function zeroBank()
    if bankGuard or not s0 then return end
    bankGuard = true
    local ok, err = pcall(function() s0:ServerRPCSetTargetBankingRatio(0.0) end)
    bankGuard = false
    if not ok then logOnce("bankfail", "   carve block FAILED: " .. tostring(err)) end
    bankZeroed = bankZeroed + 1
end

------------------------------------------------------------------- trick block
-- WHY THIS WORKS: Session's PlayerTick runs InGame_Tick (InputHandler::Tick, CheckForCrank,
-- CheckForTrick...) FIRST and only then the engine's input processing, which writes the four
-- stick axes into the controller (+0x728..+0x734, via its LeftStick/RightStick_X/Y_Axis handlers).
-- So the stick values the trick checks read were written at the end of the PREVIOUS frame --
-- and our per-frame hook (the skater's animation update) runs in between. The reflected
-- SimulateInput_*Stick* calls go through those same handlers, so writing them here decides what
-- the game's trick logic sees next frame. The triggers are left alone: they spin the varial.
-- The crouch stick is not dropped to centre at once (a spring-back past centre IS the ollie
-- flick): it is eased back over StickRelease, so the game sees you stand up, not pop.
-- Stick axes as the game reads them: RightStick_Y is +1 pulled DOWN, LeftStick_Y is +1 pushed UP.
local function stickBlockTick(el)
    if S.TrickBlock == 0 or not SB.pc then return end
    -- (v124) EASE-OUT, and EVERY axis from where it was at the click. v59-v123 snapped the three non-crouch axes to centre in
    -- one frame: a thumb that wiggled the stick as it clicked read as a flick (a shove-it 0.04-0.13 s into the hop). And
    -- the crouch stick's smoothstep return was fastest half way: now it is fastest at once and arrives at centre with no
    -- speed at all (the pop is a stick returning fast)
    local T = math.max(0.05, S.StickRelease)
    local u = math.max(0, math.min(1, el / T))
    local k = (S.StickRelease > 0) and (1 - u) * (1 - u) or 0
    local lx, ly, rx, ry = 0.0, 0.0, 0.0, 0.0
    if SB.v0 then
        lx, ly, rx, ry = SB.v0[1] * k, SB.v0[2] * k, SB.v0[3] * k, -SB.v0[4] * k   -- (the game's right-stick Y is the raw one negated)
    elseif SB.stick == "Right" then ry = k elseif SB.stick == "Left" then ly = k end
    local pc = SB.pc
    logOnce("sbtry", "   TRY SimulateInput sticks (first time)")
    local ok, err = pcall(function()
        pc:SimulateInput_LeftStick_X_Axis(lx)
        pc:SimulateInput_LeftStick_Y_Axis(ly)
        pc:SimulateInput_RightStick_X_Axis(rx)
        pc:SimulateInput_RightStick_Y_Axis(ry)
    end)
    if not ok then SB.pc = nil log("   trick block FAILED, off for this jump: " .. tostring(err)) end
end

------------------------------------------------------------------- quiet revert (SwitchLanding 2)
-- The game can only have you turned round on the board by turning the BOARD: its revert (at its own
-- RevertRotationRate, 600 deg/s -- v66 raised that to snap it round and the revert went wrong two times
-- in three: it doubled to 360 or cancelled) turns the board's target heading, the deck follows on a
-- spring, the skater actor follows the deck, and the anim plays its revert pose (RevertType != 0 sends
-- the ground state machines into their revert states). The quiet revert lets the game do all of that
-- at its normal pace -- so it counts you switch/fakie in your own stance -- but shows none of it:
--  * the deck is put on its FINAL heading the frame the revert starts and held there every frame until
--    the game's target has arrived (teleported, its spin zeroed; a 180 about the vertical negates its
--    pitch and roll): one jump of a near-symmetric deck changing ends;
--  * RevertType is written 0 every frame: no revert pose;
--  * the body is held still in the world while the skater actor turns under it.
-- A per-frame trace from touchdown logs what every part does.
local revertSnap = {}
do
local HOLD = { on = false, p = 0, y = 0, r = 0, frames = 0 }
revertSnap.forget = function() HOLD.on = false end

-- every frame while the game's target is still on its way
revertSnap.hold = function()
    if not HOLD.on then return end
    local flip = BD.comp
    if not alive(flip) then HOLD.on = false return end
    HOLD.frames = HOLD.frames + 1
    q(function() flip:K2_SetWorldRotation({ Pitch = HOLD.p, Yaw = HOLD.y, Roll = HOLD.r }, false, {}, true) end)
    q(function() flip:SetPhysicsAngularVelocityInDegrees({ X = 0.0, Y = 0.0, Z = 0.0 }, false, FName("None")) end)
end

-- the frame the game's revert starts: note the deck's final heading and go there
revertSnap.fire = function()
    local flip = findFlipper()
    local r = flip and q(function() return flip:K2_GetComponentRotation() end)
    local p, y, rl = r and q(function() return r.Pitch end, nil), r and q(function() return r.Yaw end, nil), r and q(function() return r.Roll end, nil)
    if not (p and y and rl) then log("   quiet revert: the deck was not found -- it swings") return false end
    HOLD.on, HOLD.p, HOLD.y, HOLD.r, HOLD.frames = true, -p, y + 180.0, -rl, 0
    logOnce("snapfire", "   TRY deck held on its final heading (K2_SetWorldRotation teleport + spin zeroed, first time)")
    revertSnap.hold()
    local y2 = q(function() return flip:K2_GetComponentRotation().Yaw end, nil)
    log(string.format("   quiet revert: deck %.0f -> %s (held there until the game's revert has arrived)", y,
        y2 and string.format("%.0f", y2) or "?"))
    return true
end

revertSnap.release = function(why)
    if not HOLD.on then return end
    HOLD.on = false
    log(string.format("   quiet revert: deck let go after %d held frames (%s)", HOLD.frames, why))
end

-- v69: turn the board's physics bodies (the deck and the six hung off it: both truck hangers, four wheels)
-- by yaw about the deck's centre, teleported (a turn about the vertical keeps pitch and roll; velocities are
-- world-space and stay). Returns how many bodies were moved.
local BODIES = { "Flipper", "TruckHangerFront", "TruckHangerBack", "WheelFront_L", "WheelFront_R", "WheelBack_L", "WheelBack_R" }
revertSnap.turnBoard = function(yaw)
    local flip = findFlipper()
    local owner = flip and alive(q(function() return flip:GetOwner() end))
    local pcls = alive(q(function() return StaticFindObject("/Script/Engine.PrimitiveComponent") end))
    local cl = flip and q(function() return flip:K2_GetComponentLocation() end)
    local cx, cy = cl and q(function() return cl.X end, nil), cl and q(function() return cl.Y end, nil)
    if not (owner and pcls and cx and cy) then log("   instant revert: the board's parts were not found") return 0 end
    local byName = {}
    local list = q(function() return owner:K2_GetComponentsByClass(pcls) end)
    local n = list and (q(function() return #list end, nil) or q(function() return list:GetArrayNum() end, 0)) or 0
    for i = 1, n do
        local c = alive(q(function() return list[i]:get() end))
        if c then byName[q(function() return c:GetFName():ToString() end, "")] = c end
    end
    local rad = math.rad(yaw)
    local cs, sn = math.cos(rad), math.sin(rad)
    logOnce("turnboard", "   TRY board bodies teleported round (K2_SetWorldLocationAndRotation teleport, first time)")
    local moved = 0
    for _, name in ipairs(BODIES) do
        local c = byName[name]
        local l = c and q(function() return c:K2_GetComponentLocation() end)
        local r = c and q(function() return c:K2_GetComponentRotation() end)
        local lx, ly, lz = l and q(function() return l.X end, nil), l and q(function() return l.Y end, nil), l and q(function() return l.Z end, nil)
        local p, y, rl = r and q(function() return r.Pitch end, nil), r and q(function() return r.Yaw end, nil), r and q(function() return r.Roll end, nil)
        if lx and ly and lz and p and y and rl then
            local dx, dy = lx - cx, ly - cy
            local ok = pcall(function()
                c:K2_SetWorldLocationAndRotation({ X = cx + dx * cs - dy * sn, Y = cy + dx * sn + dy * cs, Z = lz },
                    { Pitch = p, Yaw = y + yaw, Roll = rl }, false, {}, true)
            end)
            if ok then moved = moved + 1 end
        end
    end
    return moved
end

-- per-frame trace around a switch landing: yaws of each part, in the world
local LT = { frames = 0, n = 0, t0 = 0 }
local function lineYaw(a, b)
    local pa = a and fname(a) and q(function() return mesh:GetSocketLocation(fname(a)) end)
    local pb = b and fname(b) and q(function() return mesh:GetSocketLocation(fname(b)) end)
    local ax, ay = pa and q(function() return pa.X end, nil), pa and q(function() return pa.Y end, nil)
    local bx, by = pb and q(function() return pb.X end, nil), pb and q(function() return pb.Y end, nil)
    if not (ax and ay and bx and by) then return nil end
    return math.deg(math.atan(by - ay, bx - ax))
end
revertSnap.traceStart = function(frames) LT.frames, LT.n, LT.t0 = frames, 0, os.clock() end
revertSnap.traceTick = function()
    if LT.frames <= 0 or not mesh then return end
    LT.frames, LT.n = LT.frames - 1, LT.n + 1
    local function f(v) return v and string.format("%.0f", v) or "?" end
    local flip = BD.comp
    log(string.format("   landing trace +%d (%.0f ms): actor %s | mesh %s | deck %s | skeleton board %s | feet %s | "
        .. "revert pose %s | reverting %s", LT.n, (os.clock() - LT.t0) * 1000,
        f(q(function() return s0:K2_GetActorRotation().Yaw end, nil)), f(q(function() return mesh:K2_GetComponentRotation().Yaw end, nil)),
        f(flip and q(function() return flip:K2_GetComponentRotation().Yaw end, nil)),
        f(lineYaw("SKXX_SkateSkel_Truck_Back", "SKXX_SkateSkel_Truck_Front")), f(lineYaw("AMXX_L_Foot", "AMXX_R_Foot")),
        tostring(q(function() return inst.RevertType end, "?")), tostring(q(function() return s0:IsReverting() end, "?"))))
end
end   -- quiet revert + landing trace

------------------------------------------------------------------- switch landing (the game's revert)
-- A ground REVERT is the game's own 180 that turns board and stance (Skate_CheckForReverts ->
-- ASkaterCharacterBase::Revert). It is a trigger double-tap, detected in InputHandler::Tick from
-- the trigger values -- which, like the sticks, are written after the game has read them, so a
-- double-tap fed through the reflected SimulateInput_BankLeft/Right from this hook is seen next
-- frame. During the revert the body is held still in the world (its mesh yaw is taken back by
-- exactly as much as the skater turns), so the board turns under the feet and you ride away
-- fakie. Needs the game to allow reverts on the ground (Skate_CanRevert + the profile's revert
-- option); if it does not start, you are twisted to the nearest full turn as before.
local TAP = { 0.0, 1.0, 0.0, 1.0, 0.0 }
local function yawNow() return q(function() return s0:K2_GetActorRotation().Yaw end, nil) end
local function wrap180(a) return a - 360 * math.floor(a / 360 + 0.5) end

local function startRevertLanding(total, quiet, swap)
    if not SB.pc then return false, "no player controller" end
    local y = yawNow()
    if not y then return false, "cannot read your heading" end
    RV = { pending = true, t0 = os.clock(), frame = 0, total = total, right = (total > 0),
           lastYaw = y, turned = 0, started = false, stance0 = stanceNow(), quiet = quiet, tries = 1, swap = false }
    setYaw(total)                                          -- the body stays where it landed
    -- v73: SwitchLanding 4 -- no revert at all: the native half turns the rider's frame 180 and marks the deck
    -- as reversed under it in the same frame (the state a pop shove-it leaves), so the deck does not move
    if swap and NATIVE.live and type(HJN_ReverseSwap) == "function" then
        if tonumber(HJN_ReverseSwap(y)) == 1 then            -- (v135) y: the capsule's yaw, for the native gate
            RV.swap, RV.started, RV.startAt, RV.tries = true, true, os.clock(), 2
            log("   switch landing: DECK STAYS PUT -- the game now has the deck reversed under you (no revert); was " .. RV.stance0)
            -- (v94) no foot pull on this frame either: the game's own was back at 1.00 on the touchdown pose, toward sockets that
            -- are still at the opposite ends (every 180 traced: 'the game's foot pull L 1.00 R 1.00' on landing pose 1, then 0.10)
            if (S.HopPlan or 0) > 0 then footIK(0) end
        else
            log("   switch landing: the reversed-deck swap was refused (" .. tostring(HJN_ReverseSwapWhy and HJN_ReverseSwapWhy() or "?")
                .. ") -- the quiet revert instead")
        end
    end
    if not RV.swap then
        log(string.format("   switch landing: asking the game for a revert (%s trigger double-tap)%s", RV.right and "right" or "left",
            quiet and ", QUIET (deck held on its final heading, no revert pose)" or ""))
    end
    if S.TraceLog ~= 0 then revertSnap.traceStart(30) end
    if NATIVE.live and S.TraceLog ~= 0 and type(HJN_Trace) == "function" and (NATIVE.landTraces or 0) < 24 then NATIVE.landTraces = (NATIVE.landTraces or 0) + 1 HJN_Trace(90, "switch landing " .. string.format("%+.0f", total)) end
    if NATIVE.live and type(HJN_Guard) == "function" then
        -- (v75: not for a deck-stays-put landing -- the touchdown frame still has the deck reversed, and the guard's
        -- foot swap flipped the feet for that one frame: the "vertical 360". The feet are eased on instead.)
        HJN_Guard((S.NativeGuard == 1 and not RV.swap) and 90 or 0)
    end
    if NATIVE.live and S.NativeHold == 1 and type(HJN_Hold) == "function" then
        if (S.HopHold or 0) >= 1 and RV.swap then HJN_Hold(60, 14, S.HopHoldOmega or 22) else HJN_Hold(75) end   -- (v94) the sprung hold: the mesh's lag taken out for 14 poses' time (it is 45 x 0.75^n deg)
    end
    if quiet and not RV.swap then NATIVE.mute(true) end
    return true
end

-- The game turns the board's TARGET heading at its RevertRotationRate (600 deg/s: 180 in 0.3 s)
-- and the physical board follows that target through a spring, ~25 deg behind; the game's
-- IsReverting ends when the TARGET arrives. The body is held until the skater actor has stopped.
local function revertEnd(msg, settle)
    RV.pending = false
    NATIVE.mute(false)
    revertSnap.release("the revert is over")
    log(msg)
    startSettle(wrap180(settle))
end

local function revertTick(now)
    if not RV.pending then return end
    RV.frame = RV.frame + 1
    if RV.frame <= #TAP and SB.pc and not RV.swap then
        local v, pc = TAP[RV.frame], SB.pc
        pcall(function()
            if RV.right then pc:SimulateInput_BankRight(v) else pc:SimulateInput_BankLeft(v) end
        end)
    end
    local reverting = (not RV.swap) and q(function() return s0:IsReverting() end, false) == true
    if reverting and not RV.started then
        RV.started, RV.startAt = true, now
        log(string.format("   revert started %.0f ms after touchdown", (now - RV.t0) * 1000))
        -- (v67 held the deck on its final heading here: the game reads the deck as the revert's progress, ended
        -- it early and left the skater half turned.) v69: the NATIVE half finishes the game's revert from
        -- inside -- its target heading turned the whole way at once, the angle left at a hair so the game
        -- completes it next frame -- and the board's bodies are put on that heading in the same frame.
        if RV.quiet and NATIVE.live and type(HJN_InstantRevert) == "function" then
            local yaw = tonumber(HJN_InstantRevert()) or 0
            if yaw ~= 0 then
                local n = revertSnap.turnBoard(yaw)
                log(string.format("   instant revert: the game's target turned %+.0f deg at once, %d board bodies put there", yaw, n))
            else
                log("   instant revert: the native half found no revert running")
            end
        end
    end
    if RV.quiet and not RV.swap then
        q(function() inst.RevertType = 0 end)              -- no revert pose (the anim fields are rebuilt every frame)
    end
    local y, d = yawNow(), 0
    if y then
        d = wrap180(y - RV.lastYaw)
        RV.turned = RV.turned + d                          -- unwrapped: how far the skater has turned
        RV.lastYaw = y
    end
    if not RV.started then
        if now - RV.t0 > 0.45 then
            revertEnd("   the game did not revert (are trigger reverts on in its options?) -- twisting to the nearest full turn", RV.total)
        end
        return
    end
    setYaw(RV.total - RV.turned, true)                     -- hold the body still in the world, this frame
    if reverting then
        if now - RV.t0 > 2.0 then revertEnd("   revert took too long -- settling where it is", RV.total - RV.turned) end
        return
    end
    if RV.swap then
        -- the skater actor turns to the rider's new frame over a few frames; the body is held still meanwhile
        if RV.frame <= S.LandFeetFrames then footIK(math.min(1, RV.frame / S.LandFeetFrames)) end
        RV.still = (math.abs(d) < 0.3) and ((RV.still or 0) + 1) or 0
        if (math.abs(RV.turned) >= 150 and RV.still >= 3) or now - RV.t0 > 1.0 then
            revertEnd(string.format("   deck-stays-put landing done: the skater turned %+.0f deg in %.0f ms; was %s -> now %s",
                RV.turned, (now - RV.t0) * 1000, RV.stance0, stanceNow()), RV.total - RV.turned)
        end
        return
    end
    if not RV.endAt then RV.endAt, RV.turnedAtEnd, RV.still = now, RV.turned, 0 end
    RV.still = (math.abs(d) < 0.3) and (RV.still + 1) or 0
    if RV.still >= 3 or now - RV.endAt > 0.6 then
        -- a revert that came undone (the skater ended where it started) would twist the body back round
        if math.abs(RV.turned) < 90 and RV.tries < 2 then
            log(string.format("   the revert came undone (the skater turned only %+.0f deg) -- asking once more", RV.turned))
            RV.tries, RV.frame, RV.started, RV.endAt, RV.t0 = RV.tries + 1, 0, false, nil, now
            RV.total, RV.turned = RV.total - RV.turned, 0
            return
        end
        revertEnd(string.format("   revert done: the skater turned %+.0f deg in %.0f ms (%+.0f when the game's revert ended, "
            .. "then %.0f ms catching up); was %s -> now %s", RV.turned, (now - RV.startAt) * 1000, RV.turnedAtEnd,
            (now - RV.endAt) * 1000, RV.stance0, stanceNow()), RV.total - RV.turned)
    end
end

------------------------------------------------------------------- stance swap (a 180 without the revert)
-- The game draws a GOOFY rider as the regular animations MIRRORED plus a 180 yaw of the body root, on
-- the SAME board -- exactly a rider after a 180 body varial: body turned, feet swapped, board untouched.
-- v61/v62 flipped that mirror in the anim instance every frame; the rest of the game still thought
-- "regular" (lean, push foot, the skater-side anim params...) and the body warped. v63 changes the
-- stance where the GAME reads it: ASkaterCharacter::GetCurrentStance returns _skaterDefinition.Stance
-- (USkaterVisualsDefinition, reflected, EStanceType 0 Regular / 1 Goofy) unless that definition's
-- IsStanceCustomizable is set, in which case it returns your options' stance. So a switch landing
-- clears IsStanceCustomizable and writes the opposite Stance: from the next frame the whole game --
-- animation, IK, lean, stick mapping -- treats you as the other stance, natively. The game's "switch"
-- (rolling tail-first) is not involved, so trick names are those of that stance riding forward.
-- Put back by the next half-turn landing, a bail, or leaving the board. The definition is a shared
-- asset: in co-op a partner on the same definition would change stance on YOUR screen too.
-- Lua allows 200 locals in the main chunk (v61 first shipped with 201 and did not load at all), so
-- this section keeps its helpers private inside do ... end and only these few leave it.
local VS, NAT, stanceWrite, stanceSwap, stanceSwapTick, grabClick, grabTick
local grabKick, trickName, trickNameLater, trickNameTick, trickNameHide, swapCommit, swapTraceTick
do
VS = { on = false, def = nil, cust = nil, stance = nil }
NAT = { goofy = false, switch = false, mirror = nil, bank = nil }   -- this frame's native values

do   -- trick names + swap trace: their helpers stay in here (the 200-locals limit)
------------------------------------------------------------------- trick names
-- The game's trick names are a UTrickDisplayWidget (the player controller makes it from its
-- _trickDisplayWidgetBlueprint). Its private AddTrickDisplayTextWidget(text): CreateWidget of
-- _trickDisplayTextBlueprint, SetText on the new line's _text, AddChild into _trickDisplayPanel (a
-- canvas; slot alignment 1,1), render scale MaxTextScale / opacity MaxTextAlpha -- and every new line
-- pushes the older ones up a tier: slot Y = -tier * slot height - TrickDisplayTextWidgetPadding, scale
-- and opacity each stepped down by Min/Max (never below Min), gone after NumberOfTiers tiers; each line
-- also times itself out after MaxTextDuration. That function is not reflected, so the mod builds the
-- same line from the reflected parts and ages its own lines by the same rules. A game line that comes
-- in after a mod line pushes it up; a mod line pushes the game's lines up one tier when it comes in.
local TD = { w = nil, panel = nil, cls = nil, pc = nil, wbl = nil, lines = {}, known = {}, failed = 0, later = {}, calmSince = nil }
NATIVE.forgetUi = function()        -- (map changes: the widgets die with the level -- see forgetWorld)
    TD.w, TD.panel, TD.cls, TD.pc = nil, nil, nil, nil
    TD.lines, TD.later, TD.known = {}, {}, {}
end

local function tdNum(k, d) local v = q(function() return TD.w[k] end, nil) return type(v) == "number" and v or d end

local function tdFind()
    if alive(TD.w) and alive(TD.panel) and alive(TD.cls) then return true end
    if TD.failed >= 3 then return false end
    local pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
    if not pc then return false end
    local bp = alive(q(function() return pc._trickDisplayWidgetBlueprint end))
    local cname = bp and q(function() return bp:GetFName():ToString() end, nil)
    if not cname then TD.failed = TD.failed + 1 log("   trick names: the controller has no trick display class") return false end
    local pcA, found = addr(pc), nil
    TD.cname = cname                                   -- (v145) for tdLive
    local all = q(function() return FindAllOf(cname) end, nil)
    for _, w in ipairs(all or {}) do
        local full = q(function() return w:GetFullName() end, "")
        if alive(w) and not full:find("Default__", 1, true) then
            local owner = alive(q(function() return w:GetOwningPlayer() end))
            if not found or (owner and addr(owner) == pcA) then found = w end
        end
    end
    if not found then TD.failed = TD.failed + 1 log("   trick names: no " .. cname .. " on screen") return false end
    TD.w, TD.pc = found, pc
    TD.panel = alive(q(function() return found._trickDisplayPanel end))
    TD.cls = alive(q(function() return found._trickDisplayTextBlueprint end))
    TD.wbl = alive(q(function() return StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary") end))
    if not (TD.panel and TD.cls and TD.wbl) then
        TD.failed = TD.failed + 1
        log(string.format("   trick names: incomplete (panel %s, text class %s, widget library %s)", tostring(TD.panel ~= nil),
            tostring(TD.cls ~= nil), tostring(TD.wbl ~= nil)))
        TD.w = nil
        return false
    end
    log(string.format("   trick names: using %s (tiers %d, %.1fs, scale %.2f..%.2f, alpha %.2f..%.2f, padding %.0f)", cname,
        tdNum("NumberOfTiers", 0), tdNum("MaxTextDuration", 0), tdNum("MinTextScale", 0), tdNum("MaxTextScale", 0),
        tdNum("MinTextAlpha", 0), tdNum("MaxTextAlpha", 0), tdNum("TrickDisplayTextWidgetPadding", 0)))
    return true
end

-- the panel's trick lines right now (children of the text line class only), by address
local function tdChildren()
    local out = {}
    local n = q(function() return TD.panel:GetChildrenCount() end, 0) or 0
    for i = 0, n - 1 do
        local c = alive(q(function() return TD.panel:GetChildAt(i) end))
        local a = c and addr(c)
        if a and q(function() return c:IsA(TD.cls) end, false) == true then out[#out + 1] = { w = c, a = a } end
    end
    return out
end

local function isMod(a) for _, l in ipairs(TD.lines) do if l.a == a then return true end end return false end

-- one tier up: the game's own step (scale and opacity lose Min/Max each tier, never below Min)
local function tdStep(v, lo, hi) local n = v - lo / math.max(hi, 1e-3) if n < lo then return lo end return math.min(hi, n) end

local function tdPlace(l)
    local minS, maxS = tdNum("MinTextScale", 0.5), tdNum("MaxTextScale", 1)
    local minA, maxA = tdNum("MinTextAlpha", 0.3), tdNum("MaxTextAlpha", 1)
    local s, a = maxS, maxA
    for _ = 1, l.tier do s, a = tdStep(s, minS, maxS), tdStep(a, minA, maxA) end
    local slot = alive(q(function() return l.w.Slot end))          -- (v145) fetched fresh, never kept
    if not slot then return end
    local h = q(function() return slot:GetSize().Y end, 30) or 30
    local y = (l.tier > 0) and (-l.tier * h - tdNum("TrickDisplayTextWidgetPadding", 0)) or 0
    q(function() slot:SetPosition({ X = 0.0, Y = y }) end)
    q(function() l.w:SetRenderScale({ X = s, Y = s }) end)
    q(function() l.w:SetRenderOpacity(a) end)
end

-- (v145) ONLY A LINE STILL IN THE PANEL IS TAKEN OUT. The four UE4SS faults of 3 Oct all came from this code touching a
-- widget the game had already destroyed (its bail replay rebuilds the trick display); a line no longer among the panel's
-- children is simply forgotten
local function tdDrop(i, present)
    local l = table.remove(TD.lines, i)
    if not l then return end
    if present == nil then present = {} for _, c in ipairs(tdChildren()) do present[c.a] = true end end
    if present[l.a] then q(function() l.w:RemoveFromParent() end) end
end

-- (v145) is the display we hold still the game's? (its address among the live instances, once a second)
local function tdLive()
    if not TD.cname or not alive(TD.w) then return false end
    local mine = addr(TD.w)
    for _, w in ipairs(q(function() return FindAllOf(TD.cname) end, nil) or {}) do
        if addr(w) == mine then return true end
    end
    return false
end

-- a game line under the mod's: push it up one tier (its own counter does not know about ours)
local function tdNudgeGame(c)
    local slot = alive(q(function() return c.w.Slot end))
    if not slot then return end
    local h = q(function() return slot:GetSize().Y end, 30) or 30
    local y = q(function() return slot:GetPosition().Y end, 0) or 0
    local pad = tdNum("TrickDisplayTextWidgetPadding", 0)
    local tier = (y < -0.5) and math.floor((-y - pad) / math.max(h, 1) + 0.5) or 0
    q(function() slot:SetPosition({ X = 0.0, Y = -(tier + 1) * h - pad }) end)
    local s = q(function() return c.w.RenderTransform.Scale.X end, nil)
    if type(s) == "number" then
        s = tdStep(s, tdNum("MinTextScale", 0.5), tdNum("MaxTextScale", 1))
        q(function() c.w:SetRenderScale({ X = s, Y = s }) end)
    end
    local a = q(function() return c.w:GetRenderOpacity() end, nil)
    if type(a) == "number" then q(function() c.w:SetRenderOpacity(tdStep(a, tdNum("MinTextAlpha", 0.3), tdNum("MaxTextAlpha", 1))) end) end
end

-- (v144) A BAIL REBUILDS THE GAME'S TRICK DISPLAY (since the bail replay camera: 3 Oct's three crashes were UE4SS faulting
-- on a child of that panel within seconds of a bail). On the bail frame our lines are taken off while they are still ours,
-- the panel is forgotten (found again, afresh, for the next name) and nothing of the display is touched for four seconds
NATIVE.tdBail = function()
    for i = #TD.lines, 1, -1 do tdDrop(i) end
    TD.later, TD.calmSince, TD.hideUntil, TD.known, TD.born = {}, nil, nil, {}, {}
    NATIVE.forgetUi()
    TD.quietUntil = os.clock() + 4
end
trickName = function(text)
    if TD.quietUntil and os.clock() < TD.quietUntil then return false end       -- (v144) the display is being rebuilt after a bail
    if S.TrickNames == 0 or not tdFind() then return false end
    if q(function() return TD.w:IsInViewport() end, true) == false then return false end   -- trick display off
    logOnce("tdtry", "   TRY trick name line (CreateWidget + SetText + AddChild, first time)")
    local line = alive(q(function() return TD.wbl:Create(TD.w, TD.cls, TD.pc) end))
    local tb = line and alive(q(function() return line._text end))
    if not tb then TD.failed = TD.failed + 1 log("   trick names: could not make the text line") return false end
    local ok, err = pcall(function() tb:SetText(FText(text)) end)
    if not ok then TD.failed = TD.failed + 1 log("   trick names: SetText failed: " .. tostring(err)) return false end
    local before = tdChildren()
    local slot = alive(q(function() return TD.panel:AddChild(line) end))
    if not slot then TD.failed = TD.failed + 1 log("   trick names: AddChild failed") return false end
    q(function() slot:SetAlignment({ X = 1.0, Y = 1.0 }) end)
    for _, c in ipairs(before) do if not isMod(c.a) then tdNudgeGame(c) end end
    for _, l in ipairs(TD.lines) do l.tier = l.tier + 1 tdPlace(l) end
    local l = { w = line, slot = slot, a = addr(line), t0 = os.clock(), tier = 0 }
    table.insert(TD.lines, l)
    tdPlace(l)
    -- (v177) ...BUT NOT A GAME LINE THAT HAS NOT BEEN READ YET. "Ollies and grabs: the trick names are still showing up together."
    -- The game's ' Ollie' line and the grab's name both come up as you land; a game line is read a tenth of a second after
    -- it appears, and when the grab's name was put up inside that tenth, this marked the unread Ollie line as known -- it was
    -- never looked at again, so never hidden (5 of 9 grabs on 4 Oct 20:23-20:30). While a hide is on, only lines already
    -- known (and the mod's own) are marked.
    do
        local was, hiding = TD.known or {}, TD.hideUntil and os.clock() < TD.hideUntil
        TD.known = {}
        for _, c in ipairs(tdChildren()) do if not hiding or was[c.a] or isMod(c.a) then TD.known[c.a] = true end end
    end
    for i = #TD.lines, 1, -1 do if TD.lines[i].tier > tdNum("NumberOfTiers", 3) - 1 then tdDrop(i) end end
    log("   trick name: " .. text)
    return true
end

-- for a moment, take away any new game line containing `word` (the hidden revert's "Revert")
trickNameHide = function(word, secs, force)
    if (S.TrickNames == 0 and not force) or not tdFind() then return end
    TD.hideWord, TD.hideUntil = word:lower(), os.clock() + secs
    -- (v177) a matching line that is ALREADY up and was read in the last 3 s (this pop's) goes too; a line not read yet stays
    -- unread, so the tick looks at it
    local was, nowT = TD.known or {}, os.clock()
    TD.known = {}
    for _, c in ipairs(tdChildren()) do
        if isMod(c.a) then TD.known[c.a] = true
        elseif was[c.a] then
            TD.known[c.a] = true
            local r = TD.txt and TD.txt[c.a]
            if r and nowT - r[2] < 3 and r[1]:lower():find(TD.hideWord, 1, true) then
                q(function() c.w:SetVisibility(1) end)
                log("   trick names: hid the game's '" .. r[1] .. "' line (it was already up)")
            end
        end
    end
end

-- (v141) A LINE'S TEXT, ONCE THE WIDGET HAS SETTLED. v140 read every new game line the frame it appeared; one of them had no
-- text data yet and FText::ToString went through a null pointer inside UE4SS (the crash at 12:28 on 3 Oct, three drop-ins
-- in). A widget is read a tenth of a second after it was first seen; until then it is not "known", so it is looked at again
-- next frame. A widget half a second old that still gives nothing is given up on (counted as known)
local function tdText(c, now)
    TD.born = TD.born or {}
    local b = TD.born[c.a]
    if not b then TD.born[c.a] = now return nil, false end
    if now - b < 0.1 then return nil, false end
    local tx = q(function() return c.w._text:GetText():ToString() end, nil)
    if type(tx) == "string" then TD.txt = TD.txt or {} TD.txt[c.a] = TD.txt[c.a] or { tx, b } return tx, true end   -- (v177) kept: text, first seen
    return nil, now - b > 0.5
end
local function tdForget(seen)
    for a in pairs(TD.born or {}) do if not seen[a] then TD.born[a] = nil end end
    for a in pairs(TD.txt or {}) do if not seen[a] then TD.txt[a] = nil end end
end

local function tdHidden(c, t)
    if type(t) == "string" and t:lower():find(TD.hideWord, 1, true) then
        -- COLLAPSED, never removed: the game keeps its lines in a private list the garbage collector cannot
        -- see, so a line taken out of the panel was freed under it -- v67's crash in UpdateTrickDisplayTextWidgets
        q(function() c.w:SetVisibility(1) end)
        log("   trick names: hid the game's '" .. t .. "' line")
        return true
    end
    return false
end

-- a name for when you have landed it: shown once you have been rolling 0.3 s without a bail, dropped if you bail
trickNameLater = function(text)
    if S.TrickNames == 0 then return end
    TD.later[#TD.later + 1] = text
end

local function tdLaterTick(now)
    if #TD.later == 0 then return end
    local cm = modeNow()
    if cm == MODE_BAILING or cm == 0 or cm == 3 then
        log("   trick names: not shown (" .. #TD.later .. " pending) -- you bailed")
        TD.later, TD.calmSince = {}, nil
    elseif cm == MODE_RIDING and not active then
        TD.calmSince = TD.calmSince or now
        if now - TD.calmSince >= 0.3 then
            local l = TD.later
            TD.later, TD.calmSince = {}, nil
            for _, t in ipairs(l) do trickName(type(t) == "function" and t() or t) end   -- (v108) a name decided when shown
        end
    else
        TD.calmSince = nil
    end
end

-- per frame while mod lines are up: a new game line pushes them up; time and tiers take them away
trickNameTick = function(now)
    if TD.quietUntil and now < TD.quietUntil then return end                      -- (v144) hands off the display after a bail
    if alive(TD.panel) and now - (TD.validAt or -1e9) > 1 then                     -- (v145) still the game's display?
        TD.validAt = now
        if not tdLive() then
            log("   trick names: the game rebuilt its trick display -- ours forgotten, found afresh for the next name")
            TD.lines, TD.later = {}, {}
            NATIVE.forgetUi()
            TD.quietUntil = now + 2
            return
        end
    end
    tdLaterTick(now)
    -- (v142) THE GAME'S REPLAY / FILMER MODE (mode 6, a replay camera): its HUD is swapped under us -- both crashes of 3 Oct
    -- (12:28, 12:32) were UE4SS faulting on a widget read right as a bail put the game there. Nothing of the HUD is touched
    -- in that mode, and the game's lines are only read in the second around a pop (v140 read them every frame)
    -- (v150) ...and the mod's own lines are NOT forgotten there: v142 dropped them from the list with their widgets still in
    -- the panel, so a name on screen when the replay editor opened stayed on screen for good ("some trick names stay on the
    -- screen": the Switch Cannonball of 17:22:54, the editor opened two seconds later). They are left alone while the replay
    -- is up and taken out, by age, on the first frame after it
    if NATIVE.rawMode() == 6 then TD.hideUntil = nil return end
    local hiding = TD.hideUntil and now < TD.hideUntil
    if not alive(TD.panel) then TD.lines = {} TD.hideUntil = nil return end
    if #TD.lines == 0 and not hiding then
        local cm = modeNow()
        if cm == MODE_AIR then TD.airAt = now end
        if not (TD.airAt and now - TD.airAt < 0.8) or now - (TD.scanAt or -1e9) < 0.1 then return end
        TD.scanAt = now
        local seenG, present = {}, {}
        for _, c in ipairs(tdChildren()) do
            present[c.a] = true
            if TD.known[c.a] then seenG[c.a] = true
            else
                local tx, settled = tdText(c, now)                    -- (v141) read once settled; not known until then
                if tx and NATIVE.gameLine then pcall(NATIVE.gameLine, tx, now) end
                if settled then seenG[c.a] = true end
            end
        end
        TD.known = seenG
        tdForget(present)
        return
    end
    local kids, bumped = tdChildren(), 0
    local seen, present = {}, {}
    for _, c in ipairs(kids) do
        present[c.a] = true
        if not TD.known[c.a] and not isMod(c.a) then
            local tx, settled = tdText(c, now)                        -- (v141) a new game line, once its text is there
            if settled then
                if tx and NATIVE.gameLine then pcall(NATIVE.gameLine, tx, now) end
                if not (hiding and tdHidden(c, tx)) then bumped = bumped + 1 end
                seen[c.a] = true                              -- (v109) hidden or not, it is known now
            end
        else
            seen[c.a] = true
        end
    end
    TD.known = seen
    tdForget(present)
    local dur, tiers = tdNum("MaxTextDuration", 3), tdNum("NumberOfTiers", 3)
    for i = #TD.lines, 1, -1 do
        local l = TD.lines[i]
        if bumped > 0 then l.tier = l.tier + bumped tdPlace(l) end
        if not seen[l.a] or now - l.t0 > dur or l.tier > tiers - 1 then tdDrop(i, seen) end   -- (v145) a line gone from the panel is only forgotten
    end
end

------------------------------------------------------------------- stance swap: same-frame yaw
-- The body's yaw goes into the mesh's RelativeRotation, which the engine only turns into the mesh's
-- world transform when something moves it -- next frame, when the movement moves the capsule. The
-- stance swap flips the anim mirror (a 180 in the pose) THIS frame, so for one frame the mirrored pose
-- stood on the old 180 of yaw: the "360 tornado" flash (v63). swapCommit pushes the new yaw into the
-- transform at once (the reflected K2_SetRelativeRotation), and a short trace logs what the next
-- frames looked like.
local ST = { frames = 0, n = 0 }

local function meshYaws()
    local w = q(function() return mesh:K2_GetComponentRotation().Yaw end, nil)
    local r = q(function() return mesh.RelativeRotation.Yaw end, nil)
    return w, r
end

local function traceLine(tag)
    local w, r = meshYaws()
    log(string.format("   swap trace %s: mesh yaw world %s rel %s | mirror %s goofy %s switch %s | %s", tag,
        w and string.format("%.0f", w) or "?", r and string.format("%.0f", r - yaw0) or "?",
        tostring(q(function() return inst.IsAnimMirrorOn end, "?")), tostring(q(function() return inst.IsSkatingGoofy end, "?")),
        tostring(q(function() return inst.IsSkatingSwitch end, "?")), stateNow()))
end

-- v64 pushed the yaw in at once (K2_SetRelativeRotation): the trace then showed the SKATER ACTOR turns
-- 180 one frame after the stance changes (mesh world yaw 16 -> -164 with the same relative yaw), so the
-- swap frame itself was the wrong one. Trace only now.
swapCommit = function()
    if not mesh then return end
    ST.frames, ST.n = 6, 0
    traceLine("swap frame")
end

swapTraceTick = function()
    if ST.frames <= 0 then return end
    ST.frames, ST.n = ST.frames - 1, ST.n + 1
    traceLine("+" .. ST.n)
end

end  -- trick names + swap trace

-- the frame of the swap only: the game's own mirror follows from the next frame (the anim update
-- already ran this frame), so this frame's anim fields are flipped by hand -- no one-frame flicker
stanceWrite = function(swapped)
    if NAT.mirror == nil or not inst then return end
    q(function() inst.IsAnimMirrorOn = (swapped ~= NAT.mirror) end)
    q(function() inst.IsSkatingGoofy = (swapped ~= NAT.goofy) end)
    if type(NAT.bank) == "number" then q(function() inst.BankingRatio = swapped and -NAT.bank or NAT.bank end) end
end

-- (v182) THE OTHER STANCE'S HALF TURN, SWITCHED OFF WHERE THE GAME MAKES IT. A switch plant rides the other stance on a
-- board that rolls tail first, and that stance's pose stands half a turn round from where the rider is. v161 turned the
-- skater's mesh half round for the trick (right on the screen; in the game's replay one frame of a body spun about its own
-- axis at each of the two stance swaps, the replay blending the mesh's turn and the bones separately). v181 turned the
-- finished pose instead -- and the upper body flipped half round every frame of the trick: it is physics-blended, its
-- bodies are set from the pose that is WRITTEN and again from the pose the game's graph hands in, and those two were half
-- a turn apart. The turn has to come out of the game's graph already right. The game makes its goofy half turn in one
-- node of ABP_AMXX_Skater: AnimGraphNode_ModifyBone_1 on AMXX_Root, an additive yaw of -180 x IsAnimMirrorOn, straight
-- after the mirror node (the blueprint's own code; the flipper's node does the same for the AFXX skeleton). The mirror
-- WITHOUT that turn is exactly the pose a switch plant needs -- so for the poses the game rides the other stance the
-- node's RotationMode (never written by the blueprint, like the Translation the hop's lift uses) is set to "ignore", and
-- back to "additive" on the pose your own stance returns. Nothing is turned afterwards: the mesh keeps its place (the
-- replay has no jump in it) and the pose that is drawn is the one the game's physics already has.
-- For a rider whose own stance is goofy the same trick needs the turn ON with the mirror off, which no node gives: there
-- the mesh's turn stays (v161).
NATIVE.graphTurn = function(off)                      -- off = true: the graph's half turn is not made; false = as the blueprint has it
    if not inst then return false end
    local cls = q(function() return inst:GetClass():GetFName():ToString() end, "?")
    if cls:find("ABP_AMXX_Skater", 1, true) == nil then return false end
    local mode = off and BMM_IGNORE or BMM_ADDITIVE
    return (pcall(function()
        inst[NODE_BODY].RotationMode = mode
        inst[NODE_BOARD].RotationMode = mode
    end))
end

-- (v189) THE GOOFY RIDER'S SWITCH PLANTS: THE MIRROR SWITCHED OFF, THE TURN LEFT ON. "Switch no comply [riding goofy]: the first
-- one did a 360. The rest of them have a lot of leg tearing." v188 gave him the regular rider's feet but had to keep the half
-- turn in the MESH -- and the recording of 6 Oct 07:34 shows what that costs: the game cross-fades into the other stance's pose
-- in the mesh's own space, and with the mesh turned half round under it the fade starts from a body standing the other way:
-- the hips came in 44 cm across the board from where they were (y +27 -> -17 on the deck) and took twelve poses to swing
-- back, the legs pulled to their sockets all the while -- both hip joints 24 cm out of the pelvis on 30 poses, the plant
-- side's shin up to 175 deg off its knee's hinge on 40-80 (the regular rider's switch plant: 8-13 cm on 9-16, 60 on 10).
-- What he needs is his own half turn WITH the mirror off, and the stance swap cannot give it: the graph makes the turn from
-- the same flag as the mirror (the root's yaw = -180 x IsAnimMirrorOn). But the mirror node has a second condition. Read
-- off the exe (FAnimNode_Mirror::Evaluate_AnyThread): it mirrors only if its switch is on AND it has a mirror table
-- (MirrorDataAsset, +0x28; no table = the pose is passed through), and the blueprint never writes that table. So: the
-- stance is NOT swapped -- the game goes on riding him goofy, flag, turn and all -- and the table is taken away for the
-- trick: the regular clip, unmirrored, under his own half turn. That is the exact mirror image of what the regular rider's
-- switch plant draws (the mirror without the turn). No flag changes, so the game cross-fades nothing and the mesh is not
-- touched. The foot sockets come from the pose (a pose late), so they are kept as the regular rider's are (SockTurn).
NATIVE.mirrorCan = function()
    if S.NoComplyGoofyMirror == 0 or not inst then return false end
    if q(function() return inst:GetClass():GetFName():ToString() end, "?"):find("ABP_AMXX_Skater", 1, true) == nil then return false end
    return alive(q(function() return inst.AnimGraphNode_Mirror.MirrorDataAsset end)) ~= nil or NATIVE.mirrorAsset ~= nil
end
NATIVE.mirrorOff = function(on)
    if on then
        -- (review) ONLY FROM THE FRAME HOOK: the mirror node re-reads its table without testing it once an evaluation has
        -- begun, so a table taken away while this instance is being evaluated would fault. In the hook (the blueprint's
        -- update) the last evaluation is done and this pose's not begun. Putting it BACK is safe from anywhere.
        if NATIVE.mirrorAsset then
            if inst and addr(NATIVE.mirrorInst) ~= nil and addr(NATIVE.mirrorInst) == addr(inst) then return true end
            NATIVE.mirrorEnd("left over from another skater")
        end
        if not NATIVE.mirrorCan() then return false, "this skater's anim blueprint has no mirror table to take away" end
        local a = alive(q(function() return inst.AnimGraphNode_Mirror.MirrorDataAsset end))
        if not a then return false, "no mirror table" end
        local ok = pcall(function() inst.AnimGraphNode_Mirror.MirrorDataAsset = nil end)
        if not ok or alive(q(function() return inst.AnimGraphNode_Mirror.MirrorDataAsset end)) then
            pcall(function() inst.AnimGraphNode_Mirror.MirrorDataAsset = a end)
            return false, "the mirror node would not give up its table"
        end
        NATIVE.mirrorAsset, NATIVE.mirrorInst, NATIVE.mirrorAt = a, inst, os.clock()
        -- the pose is the unmirrored one from THIS pose on: the frame's flags (read before this) and the native half are told now
        NAT.goofy, NAT.mirror = false, false
        if type(HJN_Set) == "function" then NATIVE.mirrorSent = 0 pcall(HJN_Set, "mirror", 0) end
        return true
    end
    local a, i = NATIVE.mirrorAsset, NATIVE.mirrorInst
    if not a then return true end
    NATIVE.mirrorAsset, NATIVE.mirrorInst = nil, nil
    i, a = alive(i), alive(a)
    local ok = (i and a) and pcall(function() i.AnimGraphNode_Mirror.MirrorDataAsset = a end) or false
    if not ok and i then ok = pcall(function() i.AnimGraphNode_Mirror.MirrorDataAsset = i.AnimGraphNode_Mirror_1.MirrorDataAsset end) end   -- (review) the blueprint's other mirror node holds the same table
    if ok and inst and addr(i) == addr(inst) then
        NAT.goofy, NAT.mirror = true, true
        if type(HJN_Set) == "function" then NATIVE.mirrorSent = 1 pcall(HJN_Set, "mirror", 1) end
    end
    return ok
end
-- the trick is over (or anything else ended it): the table back, the sockets watched three poses more
NATIVE.mirrorEnd = function(why)
    if not NATIVE.mirrorAsset then return end
    local ok = NATIVE.mirrorOff(false)
    if type(HJN_Set) == "function" then pcall(HJN_Set, "swapturn", 0) end
    -- (v190 / native v102) the game hands in a squeezed, straight left leg for 1-3 s after a goofy rider's switch boneless
    -- (the recording of 6 Oct): the native half's bone-length repair stays on until the legs arrive sound, 4 s at most
    if type(HJN_Set) == "function" and (tonumber(NATIVE.v) or 0) >= 102 then pcall(HJN_Set, "leglinger", 4) end
    local G = VS.graph
    if G and G.m then G.mOn, G.done, G.doneAt = false, true, os.clock() end
    if why or not ok then log("   mirror: the graph's mirror table is back" .. (why and (" (" .. why .. ")") or "") .. (ok and "" or " -- IT COULD NOT BE WRITTEN: the next skater has its own")) end
end

-- on = ride the other stance; false = back to your own. Returns ok, why
stanceSwap = function(on)
    if on then
        local def = alive(q(function() return s0._skaterDefinition end))
        if not def then return false, "no skater definition" end
        local cust = q(function() return def.IsStanceCustomizable end, nil)
        local st = q(function() return def.Stance end, nil)
        if cust == nil or st == nil then return false, "cannot read the skater definition's stance" end
        logOnce("stancetry", "   TRY write _skaterDefinition.Stance / IsStanceCustomizable (first time)")
        local target = (NAT.goofy or NATIVE.mirrorAsset ~= nil) and 0 or 1   -- EStanceType: 0 Regular, 1 Goofy (the mirror switch fakes NAT.goofy: the game's own stance is goofy then)
        local ok = pcall(function() def.Stance = target end) and pcall(function() def.IsStanceCustomizable = false end)
        if not ok then
            pcall(function() def.Stance = st end) pcall(function() def.IsStanceCustomizable = cust end)
            return false, "the skater definition would not take the stance"
        end
        VS.on, VS.def, VS.cust, VS.stance = true, def, cust, st
        return true
    end
    if not VS.on then return true end
    local def = alive(VS.def)
    if def then
        pcall(function() def.Stance = VS.stance end)
        pcall(function() def.IsStanceCustomizable = VS.cust end)
    end
    VS.on = false
    if type(HJN_Set) == "function" then pcall(HJN_Set, "swapturn", 0) end   -- (v181) the native half's note of the swap may end: it does on the pose the game shows your own stance again
    if VS.graph then VS.graph.done, VS.graph.doneAt = true, os.clock() end  -- (v182) ...and so does the anim graph's half turn come back on (stanceSwapTick)
    return true
end

local function stanceSwapOff(why)
    if not VS.on then return end
    stanceSwap(false)
    log("   stance swap OFF (" .. why .. ") -- back to your own stance")
end

-- every frame, first thing in the pre-hook: read the game's values (a swap shows up in them natively)
stanceSwapTick = function()
    if not inst then return end
    NAT.goofy  = q(function() return inst.IsSkatingGoofy end, false) == true
    NAT.switch = q(function() return inst.IsSkatingSwitch end, false) == true
    NAT.mirror = q(function() return inst.IsAnimMirrorOn end, nil)
    NAT.bank   = q(function() return inst.BankingRatio end, nil)
    -- (v182) a switch plant's other stance: the game's own half turn of the body is off in its anim graph on exactly the poses
    -- it rides that stance -- read from the flag the game has just built for THIS pose (the note at NATIVE.graphTurn)
    -- (v189) the goofy rider's switch plant: the game's flags stay goofy, the POSE is the unmirrored one -- what everything after
    -- this reads. And the table never stays away: no trick on, four seconds gone, a bail or off the board = it is put back
    if NATIVE.mirrorAsset then
        local NCm, cmm = NATIVE.noComply, modeNow()
        if not (NCm and NCm.flip) or os.clock() - (NATIVE.mirrorAt or 0) > 4 or cmm == MODE_BAILING or cmm == 0 or cmm == 3 or cmm == 7 then
            NATIVE.mirrorEnd((cmm == MODE_BAILING) and "a bail" or ((NCm and NCm.flip) and ("mode " .. tostring(cmm) .. ", " .. string.format("%.1f s", os.clock() - (NATIVE.mirrorAt or 0))) or "no trick on"))
            if NCm and NCm.flip then NCm.flip, NCm.flipYaw, NCm.flipN = nil, nil, nil pcall(HJN_Set, "plantfoot", -1) end
        else
            NAT.goofy, NAT.mirror = false, false
        end
    end
    local G = VS.graph
    if G then
        local other
        if G.m then other = (G.mOn == true)
        else other = ((NAT.mirror == true) ~= G.home) or (NAT.goofy ~= G.goofy) end   -- (the game builds both flags from one call; either says it)
        if other ~= G.off then
            G.off = other
            local ok = G.m or NATIVE.graphTurn(other)                    -- (v189) G.m: his own turn stays on, the node is not touched
            if not G.m and (NATIVE.graphTold or 0) < 12 then
                NATIVE.graphTold = (NATIVE.graphTold or 0) + 1
                log(string.format("   stance swap: the game's anim graph %s its own half turn of the body from this pose on (%s)",
                    other and "does NOT make" or "makes", ok and "node written" or "the node WOULD NOT TAKE IT"))
            end
        end
        -- (v183 / native v99) ...and so are the game's foot sockets turned, on exactly those poses (the note at TAKEN): the native
        -- half does it now -- the game has just worked them out for this pose, its graph has not read them yet. On the poses
        -- your own stance is ridden they are only noted (the middle of the stance, for the turn's centre)
        if G.sock and type(HJN_Set) == "function" then
            -- (v184 / native v100) ...ON EVERY POSE OF THE SWAP, and three poses after it. "Switch no comply: for like one or two
            -- frames during the trick the feet switch places." The sockets follow the stance flag ONE POSE LATE at both ends of
            -- a swap (the recording of 5 Oct 14:24:54, poses 42 and 76: turned by the flag, the feet stood at each other's ends
            -- for a pose each). The native half no longer goes by the flag: it keeps the sockets where the pose before had
            -- them, turning them on the poses that takes -- so it is called for all of them
            if other or (tonumber(NATIVE.v) or 0) >= 100 then
                local tail4 = G.m and G.done and not other and (tonumber(NATIVE.v) or 0) >= 103     -- (v191 / native v103) the goofy rider's switch plant, the table back: 4 = hold a socket that came back across the board (a caught trick's; the note at SockMirror)
                local ok, r = pcall(HJN_Set, "sockturn", tail4 and 4 or ((other and (tonumber(NATIVE.v) or 0) >= 100) and 3 or 1))
                G.hold = (tail4 and ok and r == 2) or nil   -- (3 = the flag names the other stance: the native half's last word when the sockets do not say)
                G.turned = (ok and r == 1) or nil
                if other and not G.turned and not G.sockTold then
                    G.sockTold = true
                    log("   stance swap: the native half did NOT turn the foot sockets on this pose -- the game's foot IK is zeroed for it instead (as v182)")
                end
            else
                pcall(HJN_Set, "sockturn", 2)
                G.turned = nil
            end
        end
        if G.done and (not other or os.clock() - (G.doneAt or 0) > 1.0) then
            if G.off then if not G.m then NATIVE.graphTurn(false) end G.off = false end
            G.tail = (G.tail or 0) + 1                          -- (v184) ...the sockets come back to your own stance a pose after the flag
            if not G.sock or (tonumber(NATIVE.v) or 0) < 100 or ((G.tail > 3 or os.clock() - (G.doneAt or 0) > 1.0) and not (G.hold and os.clock() - (G.doneAt or 0) < 2.0)) then VS.graph = nil end
        end
    end
    -- (v82) the native half undoes the mirror on the animation's hand/foot sides (goofy, a stance swap): with it
    -- on, the animation's LEFT hand is the mesh's RIGHT hand bone -- v81 put a goofy Nose grab on the back hand
    if type(HJN_Set) == "function" then
        local m = (NAT.mirror == true) and 1 or 0
        if m ~= NATIVE.mirrorSent then NATIVE.mirrorSent = m pcall(HJN_Set, "mirror", m) end
        local sw = NAT.switch and 1 or 0                    -- (v103) the grab numbers' switch add-ons follow your stance
        if sw ~= NATIVE.switchSent then NATIVE.switchSent = sw pcall(HJN_Set, "switch", sw) end
        -- (v87) the native half learns where your feet ride on the deck ONLY on the ground, on the board: v86 also
        -- learned from landings and the pop before a grab, so the grab spots wandered a few cm between grabs
        local r = (modeNow() == MODE_RIDING) and 1 or 0
        if r ~= NATIVE.ridingSent then NATIVE.ridingSent = r pcall(HJN_Set, "riding", r) end
    end
    if not VS.on then return end
    local cm = modeNow()
    if cm == MODE_BAILING then stanceSwapOff("bail") return end
    if cm == 0 or cm == 3 or cm == 7 then stanceSwapOff("off the board (mode " .. cm .. ")") return end
end

-- the rider as they look -- the game's own stance, which includes a swap
local function visualGoofy() return NAT.goofy end

------------------------------------------------------------------- sticks (for grabs)
-- The stick direction at the moment of the click. First choice: the engine's reflected
-- APlayerController:GetInputAnalogStickState(stick, out X, out Y) -- raw pad values, untouched by our
-- SimulateInput writes. How UE4SS 3.3.8 hands back primitive OUT parameters is not documented, so the
-- first call probes the two plausible shapes (extra return values / filled tables) and logs what came
-- back. Fallback: the latest direction presses SessionTweaks logged for that stick (digital, no release).
-- v61 found: passing numbers errors; passing two tables fills the FIRST table only (x = -0.0 came
-- back, the second table stayed empty) -- so UE4SS likely writes the out values into that table under
-- their parameter names (StickX / StickY). v62 dumps the tables once and reads the names it finds.
local AS = { mode = nil, sign = { Left = { 1, 1 }, Right = { 1, 1 } } }   -- sign: the XInput pad's axes against the game's read (v134)         -- nil = not probed yet, "named" / "tbl" = works, false = unavailable
local function numOf(v)
    if type(v) == "number" then return v end
    local g = q(function() return v:get() end, nil)
    return type(g) == "number" and g or nil
end
local function dumpTable(t)
    local parts = {}
    for k, v in pairs(t) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function analogStick(which)                  -- which: "Left"/"Right" -> x (right +), y (up +)
    if AS.mode == false then return nil end
    local pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
    if not pc then return nil end
    local idx = (which == "Right") and 1 or 0     -- EControllerAnalogStick: CAS_LeftStick 0, CAS_RightStick 1
    local ox, oy = {}, {}
    local ok, err = pcall(function() pc:GetInputAnalogStickState(idx, ox, oy) end)
    local x = numOf(ox.StickX) or numOf(oy.StickX)
    local y = numOf(ox.StickY) or numOf(oy.StickY)
    local mode = (x and y) and "named" or nil
    if not mode then                                -- unnamed: the first number in each table
        for _, v in pairs(ox) do x = x or numOf(v) end
        for _, v in pairs(oy) do y = y or numOf(v) end
        if x and y then mode = "tbl" end
    end
    if AS.mode == nil then
        log(string.format("   TRY GetInputAnalogStickState(%d, {}, {}): ok=%s %s  first=%s second=%s", idx, tostring(ok),
            ok and "" or tostring(err), dumpTable(ox), dumpTable(oy)))
        AS.mode = mode or false
        log(AS.mode and ("   stick reading: analog (" .. AS.mode .. ") -- letting go of the stick lets go of the board") or
            "   stick reading: analog NOT available -- using the stick presses in SessionTweaks.log (no stick-release detection)")
    end
    -- (v134) THE PAD AT THE SOURCE when the game's own read shows the stick centred: the game's filmer mode takes the
    -- sticks' analog input before the player controller sees it (both sticks read 0,0 there with the thumb hard over, so
    -- no crouch, no grab pick). The native half reads the first XInput pad; its axes' signs against the game's read are
    -- learned whenever both show a push, so the substituted values mean the same thing
    if type(HJN_PadSticks) == "function" and (not (AS.mode and x and y) or (x * x + y * y < 0.04)) then
        local s = tostring(HJN_PadSticks() or "")
        local px, py, qx, qy = s:match("^(%S+) (%S+) (%S+) (%S+)")   -- (v142: 4 or 6 numbers)
        px, py, qx, qy = tonumber(px), tonumber(py), tonumber(qx), tonumber(qy)
        if px then
            local rx, ry = (which == "Right") and qx or px, (which == "Right") and qy or py
            if rx * rx + ry * ry >= 0.04 then
                if not AS.padTold then
                    AS.padTold = true
                    log("   stick reading: the game's read has the " .. which .. " stick centred while the pad has it pushed -- the pad's own values are used (the filmer mode)")
                end
                local sg = AS.sign[which]
                return rx * sg[1], ry * sg[2]
            end
        end
    end
    if AS.mode and x and y then
        if type(HJN_PadSticks) == "function" and (math.abs(x) >= 0.5 or math.abs(y) >= 0.5) and os.clock() - (AS.calAt or -1e9) > 0.5 then
            AS.calAt = os.clock()                            -- (v134) the pad's axis signs against the game's read
            local s = tostring(HJN_PadSticks() or "")
            local px, py, qx, qy = s:match("^(%S+) (%S+) (%S+) (%S+)")
            px, py, qx, qy = tonumber(px), tonumber(py), tonumber(qx), tonumber(qy)
            if px then
                local rx, ry = (which == "Right") and qx or px, (which == "Right") and qy or py
                local sg = AS.sign[which]
                if math.abs(x) >= 0.5 and math.abs(rx) >= 0.5 then sg[1] = (x * rx > 0) and 1 or -1 end
                if math.abs(y) >= 0.5 and math.abs(ry) >= 0.5 then sg[2] = (y * ry > 0) and 1 or -1 end
            end
        end
        return x, y
    end
    return nil
end

NATIVE.analog = analogStick                        -- (v126) for the hop's capture of the sticks at the click: hippie() lives outside this block

local function digitalStick(which, now)
    local p, W = pressedAt[which], 1.2
    local function recent(d) local t = p[d] return (t and now - t <= W) and t or nil end
    local u, d, l, r = recent("Up"), recent("Down"), recent("Left"), recent("Right")
    local y = (u and (not d or u > d)) and 1 or (d and -1 or 0)
    local x = (r and (not l or r > l)) and 1 or (l and -1 or 0)
    return x, y
end

local function stickNow(which, now)
    local x, y = analogStick(which)
    if x then return x, y, "analog" end
    x, y = digitalStick(which, now)
    return x, y, "presses"
end
NATIVE.stickNow = stickNow                             -- (v98) for the drop-in, further down

------------------------------------------------------------------- grabs
-- Session ships an UNFINISHED grab system: LB/RB + a stick direction in InAirHandler::CheckForGrabs
-- -> ASkaterCharacterBase::SetGrab (the skater's grab byte, +0x648) -> the anim instance's GrabState ->
-- ABP_AMXX_Skater "Catch Orient State" -> "(Regular|Switch) Catch Orient Grab State Machine" -> one
-- pose per grab. Switched off by default (the profile's ExperimentalSettings.IsGrabsEnabled; every
-- CheckForGrabs gate that fails does SetGrab(0)), and it only PICKS a grab while catch-orient is up --
-- so the mod turns the switch on in the save and starts the grab on the LB/RB press (grabKick); the
-- game then holds it while the bumper is held. NativeUpdateAnimation aims the grabbing hand at the
-- board's hand anchor (GetHandIKBaseTransform -> Left/RightHandIKLocation, component space), but the
-- control rig (PowerIK) only has a LEFT hand effector, and even that stops short: grabVisuals helps.
-- The mod's own stick-CLICK grabs (ClickGrabs=1, v62) drive the anim side directly instead.
local GRAB_ID = { nose = 1, melon = 2, mute = 3, chickensalad = 4, taipan = 5, seatbelt = 6,
                  tail = 100, stalefish = 101, indy = 102, roastbeef = 103, canadianbacon = 104, crail = 105 }
local GRAB_NAME = { [1] = "Nose", [2] = "Melon", [3] = "Mute", [4] = "Chicken Salad", [5] = "Taipan", [6] = "Seatbelt",
                    [100] = "Tail", [101] = "Stalefish", [102] = "Indy", [103] = "Roast Beef", [104] = "Canadian Bacon", [105] = "Crail" }
local GR = { on = false, id = 0, stick = nil, t0 = 0, checked = false, neutralSince = nil, blockUntilLand = false,
             pending = nil, tuck = 0, tuckTouched = false, ik = 0, ikHand = false, lastT = nil,
             native = 0, nativeT0 = nil, named = false, kick = nil, kicks = 0, drops = 0,
             push = { 0, 0, 0 }, reach = { 0, 0, 0 }, boardOff = { 0, 0, 0 }, boardTouched = false, ikWritten = false,
             crouch0 = nil, logged03 = false }
-- (map changes: the trick display widgets and the grab state die with the level -- see forgetWorld)
NATIVE.forgetGrab = function() GR.on, GR.dbl = false, nil end
NATIVE.GR = GR                                          -- (v97) for the numpad block further down (GR is this block's local)
local function grabTitle(id) return (GRAB_NAME[id] or "?") .. " Grab" end

-- 8 directions relative to the board: Up = toward the nose (the end you travel toward), Toe/Heel =
-- the side of the board your toes/heels are on. Camera behind you: a regular rider rolling forward
-- faces screen-right (toes right); goofy, or rolling switch/fakie, flips that.
local SECTORS = { "Up", "UpToe", "Toe", "DownToe", "Down", "DownHeel", "Heel", "UpHeel" }
local function grabDirection(x, y)
    local toeRight = (visualGoofy() == NAT.switch)
    local side = toeRight and x or -x
    if math.sqrt(x * x + y * y) < 0.35 then return "Neutral", toeRight end
    local a = math.deg(math.atan(side, y))                      -- 0 = up, +90 = toes, +-180 = down
    local i = math.floor(((a + 360 + 22.5) % 360) / 45) + 1
    return SECTORS[i], toeRight
end

local function grabRelease(why)
    if not GR.on then return end
    GR.on = false
    local held = os.clock() - GR.t0
    log(string.format("   let go of the %s after %.2fs (%s)", GRAB_NAME[GR.id] or "?", held, why))
end

NATIVE.grabAbort = function(why)                      -- (v135) a bail: the grab and everything hanging off it
    if GR.on then grabRelease(why) end
    GR.want, GR.pick, GR.gate, GR.kick, GR.dbl, GR.dblLock, GR.bothSince = nil, nil, nil, nil, nil, nil, nil
    GR.gateLogged, GR.named = nil, true
    if type(HJN_Set) == "function" then pcall(HJN_Set, "double", 0) end
end

local function grabStart(id, stick, where, now)
    GR.on, GR.id, GR.stick, GR.t0, GR.checked, GR.neutralSince, GR.pending = true, id, stick, now, false, nil, nil
    GR.blockUntilLand = true
    -- the rig's one hand: the anim-space left hand = front-hand grabs riding forward, back-hand
    -- grabs riding switch (the SWS grab animations swap hands)
    GR.ikHand = ((id < 100) ~= NAT.switch)
    log(string.format("GRAB %s -- %s hand%s; %s  [late trick %s, board flipping %s, catch orient %s]",
        GRAB_NAME[id], (id < 100) and "front" or "back", GR.ikHand and " (hand IK to the board)" or " (pose + tuck, no hand IK)",
        where, tostring(q(function() return inst.HasLateTrick end, "?")),
        tostring(q(function() return inst.IsBoardFlipping end, "?")), tostring(q(function() return inst.CatchOrientState end, "?"))))
    trickNameLater(grabTitle(id))
end

-- LB / RB pressed (SessionTweaks.log): start the game's OWN grab. InAirHandler::CheckForGrabs, every
-- air frame, only PICKS a grab while the skater's catch-orient is up -- and drops everything (SetGrab 0)
-- unless the profile's ExperimentalSettings.IsGrabsEnabled is on (off by default; ExperimentalSaveSlot.sav)
-- -- but once the skater holds a grab it keeps that grab for as long as LB or RB is held, and drops it
-- when both are let go. So the mod picks the grab from the stick with the game's own map
-- (a = atan2(x, y) / pi: 0 up, +0.5 right, +-1 down; LB = front hand off the left stick, RB = back hand
-- off the right stick) and hands it over through the reflected ServerRPCSetGrab; the game holds it
-- from there. The gaps in the game's map (up-left/up-right for LB) go to the nearest grab.
-- (v97) GrabBlocked: grabs switched off by name. The stick's diagonal then goes to the grab next to it.
GR.idOf = function(name) return type(name) == "string" and GRAB_ID[name:lower():gsub("[%s_%-]", "")] or nil end
GR.blocked = function(id)
    local text = tostring(S.GrabBlocked or "")
    if text ~= GR.blockedText then
        GR.blockedText, GR.blockedSet = text, {}
        for name in text:gmatch("[^,;]+") do
            local bid = GR.idOf(name)
            if bid then GR.blockedSet[bid] = true end
        end
    end
    return GR.blockedSet[id] == true
end
local function gameGrabFor(bumper, x, y)
    if math.sqrt(x * x + y * y) < 0.3 then
        local name = (bumper == "LB") and S.GrabLBNeutral or S.GrabRBNeutral
        return type(name) == "string" and GRAB_ID[name:lower():gsub("[%s_%-]", "")] or nil
    end
    -- the game reads the right stick with Y the other way round (its RightStick_Y is +1 pulled DOWN): the
    -- v64 log had it pick Tail for RB with the right stick pushed UP. Same map as the game, so flip it.
    if bumper == "RB" then y = -y end
    local a = math.atan(x, y) / math.pi
    local m, right = math.abs(a), a > 0
    local id
    if bumper == "LB" then
        if m < 0.28 then id = 1                                         -- Nose
        elseif m <= 0.6 then id = right and 3 or 2                      -- Mute / Melon
        elseif m < 0.84 then id = right and 5 or 4                      -- Taipan / Chicken Salad
        else id = 6 end                                                 -- Seatbelt
        if (id == 4 or id == 5) and GR.blocked(id) then id = (m < 0.72) and (right and 3 or 2) or 6 end
    else
        if m <= 0.16 then id = 105                                      -- Crail
        elseif m < 0.4 then id = right and 104 or 103                   -- Canadian Bacon / Roast Beef
        elseif m <= 0.6 then id = right and 102 or 101                  -- Indy / Stalefish
        else id = 100 end                                               -- Tail
        if (id == 103 or id == 104) and GR.blocked(id) then id = (m < 0.28) and 105 or (right and 102 or 101) end
    end
    if GR.blocked(id) then return nil end
    return id
end

-- (v97) THE TWO-HAND GRABS, the mod's own (the game has none). Both bumpers held in the air and the two grabs the
-- sticks pick (LB's off the left stick, RB's off the right) make one of the pairs in the ini (DoubleCannonball =
-- Nose+Tail ...): the game is handed the pair's BASE grab (its crouch: DoubleCannonballBase = Indy) and the native
-- half, told which two-hand grab it is and which hand is the front one, puts both hands on the board. It lasts
-- until the grab ends (both bumpers let go, or the landing).
-- (v108) "180 Indy Grab": how far you turned from the grab's start to the landing, to the nearest half turn
GR.turnName = function(base)
    local n = math.floor(math.abs(GR.turn or 0) / 180 + 0.5) * 180
    local name = (n > 0) and (n .. " " .. base) or base
    local sw = GR.sw if sw == nil then sw = NAT.switch end          -- (v129) the stance the grab started in (hippie jumps say Switch the same way)
    return sw and ("Switch " .. name) or name
end
GR.DOUBLES = { { "Cannonball", 200, "Cannonball" }, { "Gorilla", 201, "Gorilla Grab" }, { "Rocket", 202, "Quasimodo" } }   -- (v129) the third is the display name
GR.doubleFor = function(idL, idR)
    for _, d in ipairs(GR.DOUBLES) do
        local a, b = tostring(S["Double" .. d[1]] or ""):match("^%s*([^%+]-)%s*%+%s*([^%+]-)%s*$")
        local ia, ib = GR.idOf(a), GR.idOf(b)
        if ia and ib and ((ia == idL and ib == idR) or (ia == idR and ib == idL)) then return d end
    end
    return nil
end

-- hand a grab to the game (the reflected ServerRPCSetGrab); it holds it while LB/RB is held
local function grabSet(id, why)
    logOnce("kicktry", "   TRY ServerRPCSetGrab to start the game's grab (first time)")
    local ok, err = pcall(function() s0:ServerRPCSetGrab(id) end)
    if not ok then log("   grab start failed: " .. tostring(err)) return false end
    log("   " .. why)
    -- (v117) the game's catch orient, set as its own grab pick would have (the deck follows the board bone only in that
    -- state: a grab started with it at 0 took no tilt at all -- the Crail / Seatbelt / Stalefish "sometimes")
    if S.NativeCatchHold ~= 0 and type(HJN_CatchOrient) == "function" then
        local st = tonumber(HJN_CatchOrient((id < 100) and 1 or 2))
        if st and st <= 0 then log(string.format("   catch orient: still %d after the game's own call -- the deck may not follow the tilt this grab", st)) end
    end
    return true
end
NATIVE.grabSet = grabSet                                -- (v149) for the boneless (further down)

-- The stick is read when the grab is CHOSEN, not on the bumper's press: v68 read it the frame the press
-- came in, when a thumb moving with the finger is often still centred (0.00-0.41 logged, 0.7-1.0 a frame
-- later), so 9 in 10 grabs fell to the centred defaults (Melon / Indy). The press now only arms a latch
-- (GR.want); grabTick chooses the moment the stick is past half way, or after GrabWait with it centred.
-- For GrabRepick seconds after that, a firm push to another direction switches to that grab.
grabKick = function(bumper)
    if S.GrabStart == 0 or active then return end
    if S.Boneless ~= 0 and NATIVE.noComply and NATIVE.noComply.guard then return end   -- (v150/v151) a bumper during a no comply is the boneless's
    if not refs() then return end
    local cm = modeNow()
    if cm ~= MODE_AIR then
        if S.GroundGrabs ~= 0 and cm == MODE_RIDING then return end                    -- (v151) on the board it is the rolling grab (NATIVE.groundGrab)
        if os.clock() - (GR.refusedAt or -1e9) > 2 and cm ~= 6 then   -- (v130) never silent again: the log says why (v137: quiet in filmer mode)
            GR.refusedAt = os.clock()
            log(string.format("%s pressed: no grab -- not in the air (game mode %s, raw mode %s, wheels grounded %s, on board %s)", bumper, tostring(cm),
                tostring(q(function() return mv.CustomMovementMode end, "?")), tostring(q(function() return inst.IsGroundedWheels end, "?")),
                tostring(q(function() return mv._isOnBoard end, "?"))))
        end
        return
    end
    if q(function() return inst.IsGrinding end, false) == true then return end
    myAddr = addr(s0)
    if not ensureHook() then return end
    SB.pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
    if GR.dbl then return end                          -- (v97) a two-hand grab is on: it stays what it is
    GR.want = { bumper = bumper, t0 = os.clock() }
end

local function grabLatchTick(now, native)
    local wnt = GR.want
    if wnt then
        local stick = (wnt.bumper == "LB") and "Left" or "Right"
        local x, y, how = stickNow(stick, now)
        local mag = math.sqrt(x * x + y * y)
        if native ~= 0 then                               -- the game picked one itself (its catch-orient was up)
            GR.want, GR.pick = nil, { bumper = wnt.bumper, at = now }
        elseif mag >= 0.5 or now - wnt.t0 >= S.GrabWait then
            GR.want = nil
            local id = gameGrabFor(wnt.bumper, x, y)
            if not id then log(string.format("%s in the air: no grab for that direction", wnt.bumper)) return end
            if grabSet(id, string.format("%s in the air: %s (%s stick %s %.2f,%.2f, chosen %.0f ms after the press) -- handed to the game",
                wnt.bumper, grabTitle(id), stick, how, x, y, (now - wnt.t0) * 1000)) then
                GR.kick, GR.kicks = { id = id, at = now, bumper = wnt.bumper }, GR.kicks + 1
                GR.pick = { bumper = wnt.bumper, at = now }
            end
        end
        return
    end
    local pk = GR.pick
    if not pk then return end
    if native == 0 or now - pk.at > S.GrabRepick then GR.pick = nil return end
    -- (v109) the grab the game took is the grab: moving the stick past the diagonal used to pick the next one over
    if S.GrabKeepFirst ~= 0 and native ~= 0 then GR.pick = nil return end
    local x, y = stickNow((pk.bumper == "LB") and "Left" or "Right", now)
    if math.sqrt(x * x + y * y) < 0.6 then return end
    local id = gameGrabFor(pk.bumper, x, y)
    if id and id ~= native then
        grabSet(id, string.format("   ...switched to %s (stick %.2f,%.2f)", grabTitle(id), x, y))
    end
end

-- (v97) every air frame: the two-hand grabs. Returns the game's grab as it is after this.
GR.doubleTick = function(now, native, cm)
    if GR.dbl and (cm ~= MODE_AIR or (native == 0 and now - (GR.dblT0 or 0) > 0.15)) then   -- the grab is over, the two-hand grab with it
        log(string.format("   two-hand grab %s ended after %.2fs", GR.dbl[3], now - (GR.dblT0 or now)))
        GR.lastKind, GR.dbl, GR.dblLock = GR.dbl[2], nil, true     -- (the next one needs a bumper let go first)
        pcall(HJN_Set, "double", 0)
        return native
    end
    if S.DoubleGrabs == 0 or S.GrabStart == 0 or cm ~= MODE_AIR or type(HJN_Bumpers) ~= "function" or not NATIVE.grab() then return native end
    if q(function() return inst.IsGrinding end, false) == true then return native end
    if (tonumber(HJN_Bumpers()) or 0) ~= 3 then GR.bothSince, GR.dblLock, GR.dblDrop = nil, nil, nil return native end
    if GR.dblLock then return native end
    GR.bothSince = GR.bothSince or now
    if GR.dbl and now - GR.dblT0 > S.GrabRepick then return native end   -- chosen, and the moment to re-pick is past
    local lx, ly = stickNow("Left", now)
    local rx, ry = stickNow("Right", now)
    -- a moment for the sticks to get there (as with one bumper): until GrabWait is over only pushed sticks count
    if (math.sqrt(lx * lx + ly * ly) < 0.5 or math.sqrt(rx * rx + ry * ry) < 0.5) and now - GR.bothSince < S.GrabWait then return native end
    local idL, idR = gameGrabFor("LB", lx, ly), gameGrabFor("RB", rx, ry)
    local d = idL and idR and GR.doubleFor(idL, idR)
    if not d or d == GR.dbl then return native end
    local base = GR.idOf(S["Double" .. d[1] .. "Base"]) or 102
    -- the FRONT hand as the mesh has it: the animation's left hand riding forward, its right riding switch/fakie
    -- (the front-hand grabs' hand); the mirrored pose (goofy) swaps the bones
    local frontLeft = (NAT.switch ~= true) ~= (NAT.mirror == true)
    pcall(HJN_Set, "dblfront", frontLeft and 0 or 1)
    pcall(HJN_Set, "double", d[2])
    GR.want, GR.pick = nil, nil
    -- (v171) said in the log: a two-hand grab begun over a one-hand grab the game already holds
    local over = (native ~= 0 and native ~= base) and string.format(" -- begun OVER the game's %s, %.0f ms into it", grabTitle(native), (now - ((GR.native == native and GR.nativeT0) or now)) * 1000) or ""
    if native ~= base then
        if not grabSet(base, string.format("LB+RB in the air: %s (%s + %s; sticks L %.2f,%.2f R %.2f,%.2f) -- the game holds %s for the crouch",
            d[3], grabTitle(idL), grabTitle(idR), lx, ly, rx, ry, grabTitle(base))) then
            pcall(HJN_Set, "double", 0)
            return native
        end
        GR.kick, GR.kicks = { id = base, at = now, bumper = "LB+RB" }, GR.kicks + 1
        native = q(function() return s0:GetGrabState() end, 0) or 0
        if type(native) ~= "number" then native = 0 end
    else
        log(string.format("   LB+RB in the air: %s (%s + %s; sticks L %.2f,%.2f R %.2f,%.2f) on the %s already held",
            d[3], grabTitle(idL), grabTitle(idR), lx, ly, rx, ry, grabTitle(base)))
    end
    log(string.format("TWO-HAND GRAB %s -- front hand = the mesh's %s, %s%s", d[3], frontLeft and "LEFT" or "RIGHT",
        visualGoofy() and "goofy" or "regular", NAT.switch and " switch" or "") .. over)
    GR.dbl, GR.dblT0, GR.lastKind, GR.named, GR.sw = d, now, d[2], true, NAT.switch   -- (v129)
    trickNameLater(function() return GR.turnName(d[3]) end)
    trickNameHide("ollie", 6)
    return native
end

-- a stick click while airborne. Returns true if it was taken as a grab click.
grabClick = function(which)
    if S.ClickGrabs == 0 or active then return false end
    if not refs() then return false end
    if modeNow() ~= MODE_AIR then return false end
    if q(function() return inst.IsGrinding end, false) == true then return false end
    -- the per-frame work (holding the pose, letting go, the stick block) runs in the anim hook: make
    -- sure it is registered and knows which skater is ours even if no hop has been done yet
    myAddr = addr(s0)
    if not ensureHook() then return false end
    if not VS.on then                                  -- the anim fields hold the game's own values now
        NAT.goofy  = q(function() return inst.IsSkatingGoofy end, false) == true
        NAT.switch = q(function() return inst.IsSkatingSwitch end, false) == true
    end
    local stick = (which == "L3") and "Left" or "Right"
    local now = os.clock()
    if GR.on and GR.stick == stick then grabRelease("clicked again") return true end
    SB.pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
    local x, y, how = stickNow(stick, now)
    local dir, toeRight = grabDirection(x, y)
    local name = S["Grab" .. stick .. dir]
    local id = type(name) == "string" and GRAB_ID[name:lower():gsub("[%s_%-]", "")] or nil
    local where = string.format("%s stick %s (%s %.2f,%.2f; %s%s, toes %s)", stick, dir, how, x, y,
        visualGoofy() and "goofy" or "regular", NAT.switch and " switch" or "", toeRight and "right" or "left")
    if not id then log("   " .. where .. " -> '" .. tostring(name) .. "' is not a grab name -- nothing") return true end
    -- the pose machine only leaves a grab through "no grab", so a new grab mid-air lets go first and
    -- takes hold a moment later (grabTick)
    if GR.on then
        grabRelease("switching to " .. GRAB_NAME[id])
        GR.pending = { id = id, stick = stick, where = where, at = now + 0.1 }
        return true
    end
    grabStart(id, stick, where, now)
    return true
end

-- no late flips from a stick you are grabbing with: the game sees centred sticks until the landing
-- (or until you let the stick go), exactly like the hop's trick block
local function grabStickBlock()
    local pc = SB.pc
    if not pc then return end
    local ok = pcall(function()
        pc:SimulateInput_LeftStick_X_Axis(0.0)  pc:SimulateInput_LeftStick_Y_Axis(0.0)
        pc:SimulateInput_RightStick_X_Axis(0.0) pc:SimulateInput_RightStick_Y_Axis(0.0)
    end)
    if not ok then GR.blockUntilLand = false end
end

-- component-space position of a bone or socket (cm), or nil
local function compPos(name)
    local n = fname(name)
    if not n or not mesh then return nil end
    local t = q(function() return mesh:GetSocketTransform(n, 2).Translation end, nil)
    if not t then return nil end
    local x, y, z = q(function() return t.X end, nil), q(function() return t.Y end, nil), q(function() return t.Z end, nil)
    if x and y and z then return { x, y, z } end
    return nil
end
local V = { ZERO = { 0, 0, 0 } }                     -- 3-vectors { x, y, z }
function V.sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
function V.add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
function V.mul(a, k) return { a[1] * k, a[2] * k, a[3] * k } end
function V.len(a) return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) end
function V.clamp(a, m) local l = V.len(a) if l > m and l > 0 then return V.mul(a, m / l) end return a end
function V.toward(a, b, step)                          -- a moved toward b by at most step
    local d = V.sub(b, a)
    local l = V.len(d)
    if l <= step or l == 0 then return { b[1], b[2], b[3] } end
    return V.add(a, V.mul(d, step / l))
end

-- the hand the game gives a grab (ASkaterCharacterBase::HasLeft/RightHandGrab): riding forward the
-- front-hand grabs (1-6) are the LEFT hand, the back-hand grabs (100-105) the RIGHT; switch/fakie swaps
local function grabAnimLeft(id) return (id < 100) ~= (NAT.switch == true) end
-- ...and which hand bone of the MESH that is: the game draws goofy (and a stance swap) as the MIRRORED pose, so the
-- animation's left hand is then the right hand bone (v82)
local function grabLeftHand(id) return grabAnimLeft(id) ~= (NAT.mirror == true) end
NATIVE.grabLeftHand = grabLeftHand                      -- (v150) for the boneless (further down)

local function crouchNow()
    local pel, brd = compPos("AMXX_Pelvis"), compPos("SKXX_SkateSkel_Flipper")
    return (pel and brd) and (pel[3] - brd[3]) or nil
end

-- the game's own hand target for a grab: NativeUpdateAnimation writes Left/RightHandIKLocation every frame the
-- skater has a grab for that hand -- the skeleton board's hand anchor carried over onto the REAL board
-- (GetHandIKBaseTransform), in component space. nil when the game has not set it.
local function gameTarget(left)
    local v = q(function() if left then return inst.LeftHandIKLocation end return inst.RightHandIKLocation end, nil)
    local x, y, z = v and q(function() return v.X end, nil), v and q(function() return v.Y end, nil), v and q(function() return v.Z end, nil)
    if x and y and z and (x ~= 0 or y ~= 0 or z ~= 0) then return { x, y, z } end
    return nil
end

-- one log line of grab numbers: each hand's gap to its board anchor (component space: the skater's
-- mesh axes, cm) and how deep the crouch is (hips above the board)
local function grabNumbers(tag, id)
    if S.GrabLog == 0 or not mesh then return end
    local left = grabLeftHand(id)
    local hand = compPos(left and "AMXX_L_Hand" or "AMXX_R_Hand")
    local tgt = GR.tgt or gameTarget(grabAnimLeft(id))
    local skel = compPos(left and "SKXX_SkateSkel_Hand_Anchor_L" or "SKXX_SkateSkel_Hand_Anchor_R")
    local function gap(h, a)
        if not h or not a then return "?" end
        local d = V.sub(a, h)
        return string.format("%.0f cm (%+.0f,%+.0f,%+.0f)", V.len(d), d[1], d[2], d[3])
    end
    local c = crouchNow()
    log(string.format("   grab %s %s: %s hand -> the board (the game's target on the real deck) %s | the skeleton's anchor is %s from that"
        .. " | hips above the board %s%s | game IK L %.2f R %.2f, mod push %.0f cm, board moved %.0f cm", GRAB_NAME[id] or tostring(id), tag,
        (left and "LEFT" or "RIGHT") .. ((NAT.mirror == true) and " (mirrored pose)" or ""), gap(hand, tgt), (tgt and skel) and string.format("%.0f cm", V.len(V.sub(tgt, skel))) or "?",
        c and string.format("%.0f cm", c) or "?",
        GR.crouch0 and string.format(" (%.0f before the grab)", GR.crouch0) or "",
        tonumber(q(function() return inst.LeftHandIKAlpha end, 0)) or 0, tonumber(q(function() return inst.RightHandIKAlpha end, 0)) or 0,
        V.len(GR.push), V.len(GR.boardOff)) .. " | pose machine: " .. (GR.poseState and GR.poseState() or "?"))
    if NATIVE.grab() and type(HJN_Stats) == "function" then log("      " .. tostring(HJN_Stats())) end
end

-- per frame: the adjustments ease in while grabbing and out after.
--  * LEFT hand (the rig's one hand effector): the game already aims it at the board's hand anchor
--    (LeftHandIKLocation, component space) but the arm stops short -- so the target is pushed past the
--    anchor by what is still missing, a little more each frame, up to GrabHandReach.
--  * LOCK (either hand): whatever gap is left, the board comes to the hand (the skeleton's board bone,
--    which the real board follows in the air; closed loop on the game's target on the real deck),
--    up to GrabLockMax; the feet follow the board. The RIGHT hand has no effector: this is all it gets.
--  * GrabCrouch: extra board height on top of the game's grab pose (+ tighter, - looser).
local function grabReset()
    GR.push, GR.reach = V.ZERO, V.ZERO
    if GR.boardTouched then GR.boardOff, GR.boardTouched = V.ZERO, false nodeLift(NODE_BOARD, nil) end
    if GR.ikWritten and GR.ik > 0 then q(function() inst.LeftHandIKAlpha = 0.0 end) end
    GR.ik, GR.ikWritten = 0, false
end

local function grabVisuals(dt)
    local id = (GR.native ~= 0) and GR.native or (GR.on and GR.id or 0)
    local left = (id ~= 0) and grabLeftHand(id)
    local hand, anchor
    if id ~= 0 then
        hand = compPos(left and "AMXX_L_Hand" or "AMXX_R_Hand")
        -- v65 aimed at the skeleton's anchor; the board you see is the real one: use the game's own target
        anchor = gameTarget(grabAnimLeft(id)) or compPos(left and "SKXX_SkateSkel_Hand_Anchor_L" or "SKXX_SkateSkel_Hand_Anchor_R")
    end
    GR.tgt = anchor
    local k = math.min(1, 6 * dt)
    -- the board bone
    local want = V.ZERO
    if id ~= 0 then
        if S.GrabLock ~= 0 and S.GrabLockMax > 0 and hand and anchor and not NATIVE.grab() then
            GR.reach = V.clamp(V.add(GR.reach, V.mul(V.sub(hand, anchor), math.min(1, 5 * dt))), S.GrabLockMax)
        end
        want = { GR.reach[1], GR.reach[2], GR.reach[3] + S.GrabCrouch }
    else
        GR.reach = V.ZERO
    end
    local speed = (S.GrabTuckTime > 0) and (math.max(V.len(want), V.len(GR.boardOff), 1) / S.GrabTuckTime) or 1e9
    GR.boardOff = V.toward(GR.boardOff, want, speed * dt)
    if V.len(GR.boardOff) > 0.05 then
        logOnce("grabboard", "   TRY grab board adjust (board bone moved, first time)")
        nodeLift(NODE_BOARD, GR.boardOff[3], GR.boardOff[1], GR.boardOff[2])
        GR.boardTouched = true
    elseif GR.boardTouched then
        GR.boardOff, GR.boardTouched = V.ZERO, false
        nodeLift(NODE_BOARD, nil)
    end
    -- the left hand
    if id ~= 0 and left and S.GrabHandIK ~= 0 and hand and anchor and not NATIVE.grab() then
        local miss = V.sub(anchor, hand)
        if V.len(miss) > 4 then GR.push = V.clamp(V.add(GR.push, V.mul(miss, k)), S.GrabHandReach) end
        local tgt = V.add(anchor, GR.push)
        logOnce("grabik", "   TRY grab hand IK push (LeftHandIKLocation/Alpha, first time)")
        GR.ik = math.min(1, GR.ik + 6 * dt)
        q(function() inst.LeftHandIKLocation.X = tgt[1] end)
        q(function() inst.LeftHandIKLocation.Y = tgt[2] end)
        q(function() inst.LeftHandIKLocation.Z = tgt[3] end)
        local a = tonumber(q(function() return inst.LeftHandIKAlpha end, 0)) or 0
        if GR.ik > a then q(function() inst.LeftHandIKAlpha = GR.ik end) GR.ikWritten = true end
    else
        GR.push = V.ZERO
        if GR.ik > 0 then
            GR.ik = math.max(0, GR.ik - 8 * dt)
            if GR.ikWritten then q(function() inst.LeftHandIKAlpha = GR.ik end) end
            if GR.ik <= 0 then GR.ikWritten = false end
        end
    end
end

-- (v173) WHAT THE GAME'S POSE MACHINE IS SHOWN. "Switch Cannonballs, fine. Regular Cannonball is not fine." Found by reading
-- the animation blueprint: its grab state machine has only 'Empty -> grab N' transitions -- no grab state has an exit --
-- and it restarts only when its parent state has been left and blended out, which takes GrabState == 0 for 0.4 s. So the
-- first grab it SEES is the pose it plays for the whole grab: a Cannonball begun over a Nose Grab (the left bumper a few
-- ms early, or the game picking the Nose itself) plays the Nose Grab's body and board -- deck rolled 19-23 deg, pitched
-- 8-12, the right hand's anchor 110 cm up -- under the Cannonball's hands (all 9 bad ones in the logs; the 7 good ones:
-- roll 0-1). One frame is enough, and v172's let-go could not help: the 0 lived for one controller tick. So the mod now
-- decides what the machine reads (the anim instance's GrabState, written here in the pre-hook, after the game's copy):
-- a one-hand grab is not shown for GrabChord seconds (the other bumper may still come); a grab begun while the machine
-- still sits in another grab's state is not shown until that has had its 0.45 s to blend out; otherwise it is shown as
-- the game has it NOW. Hands, the native posing, the catch orient and the trick name are not delayed.
GR.poseState = function()   -- the blueprint's nodes: 5 on-board, 225 the catch-orient machine, 332 / 371 the regular / switch grab machine
    if not inst then return "?" end
    local function nm(k) return q(function() return inst:GetCurrentStateName(k):ToString() end, "?") end
    return nm(5) .. " > " .. nm(225) .. " > " .. nm((NAT.switch == true) and 371 or 332)
end
GR.animShow = function(now, native, cm)
    if cm ~= MODE_AIR or GR.on or not inst then return end
    if GR.shown and now - (GR.shownAt or now) > 0.45 then GR.shown = nil end
    if native == 0 then GR.heldWhy = nil return end
    local why, chord = nil, false
    if GR.shown and GR.shown ~= native then
        why = "its machine still sits in the " .. grabTitle(GR.shown) .. "'s state (0.4 s to blend out)"
    elseif not GR.shown and not GR.dbl and not GR.dblLock and S.DoubleGrabs ~= 0 and (S.GrabChord or 0) > 0 and NATIVE.grab() then
        local age = now - (GR.nativeT0 or now)
        if age < S.GrabChord or (GR.bothSince and age < 0.25 and now - GR.bothSince <= S.GrabWait + 0.02) then
            why, chord = "the other bumper may still come", true
        end
    end
    if why then
        if GR.heldWhy ~= why then GR.heldWhy = why log("   pose machine: not shown the " .. grabTitle(native) .. " yet -- " .. why) end
        if chord then   -- not in the catch-orient state yet either: both arrive together (its own 0.33 s entry, as before)
            local st = q(function() return inst:GetCurrentStateName(5):ToString() end, nil)
            if st and st ~= "Catch Orient State" then q(function() inst.CatchOrientState = 0 end) end
        end
        q(function() inst.GrabState = 0 end)
        return
    end
    if GR.shown ~= native then
        log(string.format("   pose machine: shown the %s, %.0f ms into it (%s)", grabTitle(native), (now - (GR.nativeT0 or now)) * 1000, GR.poseState()))
    end
    GR.shown, GR.shownAt, GR.heldWhy = native, now, nil
    q(function() inst.GrabState = native end)   -- the byte as it is NOW, not this frame's earlier copy
end
grabTick = function(now)
    local dt = GR.lastT and (now - GR.lastT) or 0
    if dt < 0 or dt > 0.1 then dt = 0 end
    GR.lastT = now
    local cm = modeNow()
    -- the game's OWN grab (LB/RB + a stick direction, InAirHandler::CheckForGrabs): watched every air
    -- frame so the tuck can go with it, and logged so the direction map can be learned
    local native = 0
    if cm == MODE_AIR or GR.native ~= 0 or GR.kick then
        native = (cm == MODE_AIR) and (q(function() return s0:GetGrabState() end, 0) or 0) or 0
        if type(native) ~= "number" then native = 0 end
    end
    -- (v97) an angle grab that is switched off (GrabBlocked), picked by the game itself: handed back as its neighbour
    if native ~= 0 and cm == MODE_AIR and not GR.dbl and GR.blocked(native) then
        local bumper = (native < 100) and "LB" or "RB"
        local x, y = stickNow((bumper == "LB") and "Left" or "Right", now)
        local id = gameGrabFor(bumper, x, y)
        if id and id ~= native and now - (GR.unblockAt or -1) > 0.2 then
            GR.unblockAt = now
            if grabSet(id, string.format("   the game picked the %s, which is switched off (GrabBlocked) -> %s", grabTitle(native), grabTitle(id))) then
                native = q(function() return s0:GetGrabState() end, 0) or 0
                if type(native) ~= "number" then native = 0 end
            end
        end
    end
    -- (v97) the two-hand grabs
    if GR.dbl or cm == MODE_AIR then
        local okd, nat2 = pcall(GR.doubleTick, now, native, cm)
        if okd and type(nat2) == "number" then native = nat2
        elseif not okd then logOnce("dblerr", "   two-hand grab error: " .. tostring(nat2)) end
    end
    -- LB/RB: the latch that waits for the stick, and the early re-pick
    if cm ~= MODE_AIR then GR.want, GR.pick = nil, nil
    elseif GR.want or GR.pick then grabLatchTick(now, native) end
    -- a grab the mod handed over: did the game keep it?
    if GR.kick and now - GR.kick.at > 0.12 then
        local k = GR.kick
        GR.kick = nil
        if native == 0 and GR.native == 0 then
            GR.drops = GR.drops + 1
            log(string.format("   the game dropped the %s at once (%d of %d so far) -- %s", grabTitle(k.id), GR.drops, GR.kicks,
                (GR.drops == GR.kicks and GR.kicks >= 2) and
                "EVERY one: the game's grabs are switched off (IsGrabsEnabled in ExperimentalSaveSlot.sav), or its other gates refuse"
                or ("was " .. k.bumper .. " still held?")))
        end
    end
    if native ~= GR.native then
        if native ~= 0 then
            GR.nativeT0, GR.named, GR.sw = now, false, NAT.switch   -- (v129) GR.sw: the stance at the start, for the name
            GR.tgt = nil
            GR.crouch0, GR.logged03 = crouchNow(), false
            grabNumbers("at the start", native)
            local lx, ly = analogStick("Left")
            local rx, ry = analogStick("Right")
            -- (v108) the sticks as they picked the grab: the tweak gate's baseline; the turn count starts here
            GR.gate = { Left = { lx or 0, ly or 0, lx and math.sqrt(lx * lx + ly * ly) or 0, lx and math.deg(math.atan(ly, lx)) or 0 },
                        Right = { rx or 0, ry or 0, rx and math.sqrt(rx * rx + ry * ry) or 0, rx and math.deg(math.atan(ry, rx)) or 0 } }
            GR.gateLogged, GR.turn, GR.turnEnd = false, 0, nil
            GR.caught, GR.catchTries = nil, 0           -- (v118) the gate waits for the game's catch
            GR.turnYaw = q(function() return s0:K2_GetActorRotation().Yaw end, nil)
            log(string.format("GAME GRAB %s (LB/RB) -- sticks L %s R %s, %s%s  [land ratio %s]", GRAB_NAME[native] or tostring(native),
                lx and string.format("%.2f,%.2f", lx, ly) or "?", rx and string.format("%.2f,%.2f", rx, ry) or "?",
                visualGoofy() and "goofy" or "regular", NAT.switch and " switch" or "",
                tostring(q(function() return inst.LandHeightRatio end, "?"))))
        elseif GR.native ~= 0 then
            grabNumbers("at the end", GR.native)
            log(string.format("   game grab %s ended after %.2fs (%s)  [land ratio %s]", GRAB_NAME[GR.native] or tostring(GR.native),
                now - (GR.nativeT0 or now), cm == MODE_AIR and "LB/RB let go" or "touched down",
                tostring(q(function() return inst.LandHeightRatio end, "?"))))
            -- (v186) HELD INTO THE LANDING. "The auto release before landing, whether it's on or off, I'm not bailing at all."
            -- GrabLetGo was only read by the mod's old stick-click grabs; the game's own grab (LB / RB, the one that is used) just
            -- ends at touchdown. With GrabLetGo=0 a grab that ends because the wheels came down, the bumper still held, is a bail.
            if cm == MODE_RIDING and S.GrabLetGo == 0 and q(function() return inst.IsGrinding end, false) ~= true then
                doBail("landed still holding the " .. tostring(GRAB_NAME[GR.native] or "grab"), 0)
            end
            GR.collUntil = now + 3                          -- (v95) its limb audit follows once the pose lets go
            GR.endT, GR.lateUntil = now, now + 1.5
            GR.gate, GR.turnEnd = nil, now             -- (v108) the sticks are the game's again; the turn is counted 2 s more
            GR.caught = nil
        end
        GR.native = native
        if native ~= 0 and not GR.dbl then GR.lastKind = native end   -- (v86) the numpad hand nudges apply to this grab
    end
    do local oka, erra = pcall(GR.animShow, now, native, cm) if not oka then logOnce("animshow", "   pose machine error: " .. tostring(erra)) end end   -- (v173)
    -- (v108) how far you have turned since the grab began (the name's 180 / 360): counted until 2 s after it ends
    if GR.turnYaw then
        if native ~= 0 or (GR.turnEnd and now - GR.turnEnd < 2) then
            local y = q(function() return s0:K2_GetActorRotation().Yaw end, nil)
            if y then GR.turn = (GR.turn or 0) + ((y - GR.turnYaw + 180) % 360 - 180) GR.turnYaw = y end
        else GR.turnYaw = nil end
    end
    -- (v118) THE GAME'S CATCH COMES FIRST. In manual catch the game's catch orient (which foot has caught the board; the
    -- deck follows the board bone only then) comes from the STICKS, and the gate below hid them: a grab whose stick was
    -- pushed after the bumper never caught (v56's SetCatchOrient took and the game cleared it the next frame, every frame).
    -- So the game is shown the real sticks until it has its catch; the gate then takes over. The v117 call is kept as a
    -- nudge, three times at most
    if native ~= 0 and type(HJN_CatchState) == "function" then
        local cs = tonumber(HJN_CatchState()) or 0
        if cs > 0 and not GR.caught then GR.caught = now end
        if cs <= 0 and S.NativeCatchHold ~= 0 and type(HJN_CatchOrient) == "function" and GR.catchTries < 3 and now - (GR.catchAt or 0) > 0.15 then
            GR.catchAt, GR.catchTries = now, GR.catchTries + 1
            pcall(HJN_CatchOrient, (native < 100) and 1 or 2)
        end
    end
    -- (v108) THE GAME'S TWEAK, GATED. The stick that picked the grab stays where it is, and the game turns your lower
    -- half by that whole deflection. So once the grab has taken, the game is shown the stick RELATIVE to where it was
    -- at the pick: nothing while it stays within GrabTweakDead degrees of that direction, then the real stick, scaled
    -- up over GrabTweakRamp degrees -- move to the diagonal and the tweak comes in. (v112 showed it the stick held at
    -- the pick instead, which turned the lower half the whole grab: the flat hand it meant to cure was the deck held
    -- level under the game's hand, native v50.) (SimulateInput writes what the game's trick logic reads next frame;
    -- the mod's own stick reads go through the engine's input state, untouched.)
    if native ~= 0 and GR.gate and AS.mode and S.GrabTweakGate ~= 0 then   -- (v125) from the first frame: the stick the game is shown is deflected, so its catch comes from it
        local pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
        if pc then
            SB.pc = pc
            local function masked(which)
                local x, y = analogStick(which)
                if not x then return nil end
                local b = GR.gate[which]
                local m = math.sqrt(x * x + y * y)
                if m < 0.25 or not b or b[3] < 0.3 then return x, y, 1 end     -- (centred, or picked with a centred stick: as it is)
                local rel = (math.deg(math.atan(y, x)) - b[4] + 180) % 360 - 180
                local d = math.abs(rel)
                local k = math.max(0, math.min(1, (d - S.GrabTweakDead) / math.max(1, S.GrabTweakRamp)))
                -- (v125) THE GAME'S TWEAK IS THE STICK'S SIDEWAYS PART. Its catch orient takes a yaw ratio from the stick's X
                -- and a pitch ratio from its Y (the mod holds the deck's pitch anyway): a side grab picked with the stick full
                -- sideways twisted the body some 30 deg at once, and swinging it only changed the pitch ("no response"); the
                -- up/down grabs twisted a little from the thumb's slant. So the game is shown the stick STRAIGHT along the
                -- vertical (up for an up pick, down otherwise), at the stick's own deflection -- it has its catch from that --
                -- and your swing off the pick becomes its sideways part: no twist at the pick for any grab, and the same swing
                -- gives the same twist for all of them (never further than GrabTweakMaxTurn: past the diagonal the game would
                -- pick the next grab over). The old sticks still pick the grab; only what the game sees after is remapped
                -- (v126) the side picks are shown on the SAME vertical as Nose/Tail (+y), not the opposite one: the game's twist
                -- comes from the stick's X alone, and a swing from the top and the same swing from the bottom give opposite X,
                -- so a side grab shown on the bottom twisted the other way from Nose/Tail for the same turn of the stick.
                -- Only a pick on the far vertical (Crail, Seatbelt: the stick pushed the other way) stays where it is
                -- (v127) ...and Crail / Seatbelt too: EVERY pick is shown on the +y vertical, so one turn of the stick is one
                -- twist, whatever the grab. GrabTweakInvert turns all of them the other way (the menu's "Invert tweak direction")
                local inv = (S.GrabTweakInvert ~= 0) and -1 or 1
                local swing = math.rad(k * math.max(-S.GrabTweakMaxTurn, math.min(S.GrabTweakMaxTurn, rel)))
                return -inv * m * math.sin(swing), m * math.cos(swing), k
            end
            local lx2, ly2, lk = masked("Left")
            local rx2, ry2, rk = masked("Right")
            if not GR.gateLogged and ((lk and lk < 1) or (rk and rk < 1)) then
                GR.gateLogged = true
                log(string.format("   tweak gate: the game is shown the stick straight along the vertical, your swing as its sideways part (picks: L %.0f deg, R %.0f deg): dead %g, ramp %g",
                    GR.gate.Left[4], GR.gate.Right[4], S.GrabTweakDead, S.GrabTweakRamp))
            end
            pcall(function()
                if lx2 then pc:SimulateInput_LeftStick_X_Axis(lx2)  pc:SimulateInput_LeftStick_Y_Axis(ly2) end
                if rx2 then pc:SimulateInput_RightStick_X_Axis(rx2) pc:SimulateInput_RightStick_Y_Axis(-ry2) end
            end)
        end
    end
    -- its name, once it has really taken hold (not a grab the game threw away the same instant)
    if native ~= 0 and not GR.named and not GR.on and not GR.dbl and now - (GR.nativeT0 or now) >= S.GrabRepick + 0.02 then
        GR.named = true
        local kind = native
        local bone = (kind == 102) and GR.boneAt ~= nil and (now - GR.boneAt) < 2.5      -- (v149) an Indy out of a no comply
        trickNameLater(function() return GR.turnName(bone and "Boneless" or grabTitle(kind)) end)
        trickNameHide(bone and "no comply" or "ollie", 6)              -- (v108) the game's own "Ollie" / "Nollie" line for this pop is not wanted beside it
    end
    -- (v97) a late trick during a grab or just after it: logged, with when -- what the block lets through
    if native ~= 0 or (GR.lateUntil and now < GR.lateUntil) then
        local lt = q(function() return inst.HasLateTrick end, false) == true
        if lt ~= (GR.lateWas == true) then
            GR.lateWas = lt
            if lt then
                log((native ~= 0) and string.format("   LATE TRICK %.2f s into the %s (it should not start while a grab is held)", now - (GR.nativeT0 or now), grabTitle(native))
                    or string.format("   late trick %.2f s after the grab was let go", now - (GR.endT or now)))
            end
        end
    end
    if native ~= 0 and not GR.logged03 and now - (GR.nativeT0 or now) >= 0.3 then GR.logged03 = true grabNumbers("0.3 s in", native) end
    if GR.collUntil and type(HJN_Collisions) == "function" then   -- (v95) the finished grab's limb audit, when the native half has it
        local r = tostring(HJN_Collisions() or "")
        if r ~= "" and r ~= GR.collLast then
            GR.collLast, GR.collUntil = r, nil
            log("      LIMBS " .. r)
        elseif now > GR.collUntil then GR.collUntil = nil end
    end
    if not GR.on and not GR.blockUntilLand and not GR.pending and not GR.boardTouched and GR.ik <= 0.001 and GR.native == 0 then return end
    if cm ~= MODE_AIR or q(function() return inst.IsGrinding end, false) == true then
        if GR.on then
            if cm == MODE_RIDING and S.GrabLetGo == 0 and S.VarialBail ~= 0 then
                local name = GRAB_NAME[GR.id]
                grabRelease("touched down still holding")
                if doBail("landed still holding the " .. tostring(name), 0) then end
            else
                grabRelease(cm == MODE_RIDING and "touched down" or ("mode " .. tostring(cm)))
            end
        end
        GR.blockUntilLand, GR.pending = false, nil
        grabReset()
        return
    end
    -- (v97) no late flips out of the GAME's grabs: the native half keeps the game's late-trick check switched off while
    -- LB/RB is down or a grab is held (HJN_Set("lateblock")). v96 fed the game centred sticks here instead -- that armed
    -- its late trick, and the real stick coming back at the release read as a flick. The stick block is the click grabs' now.
    if GR.blockUntilLand then grabStickBlock() end
    if GR.pending and not GR.on and now >= GR.pending.at then
        local p = GR.pending
        GR.pending = nil
        grabStart(p.id, p.stick, p.where, now)
    end
    if GR.on then
        -- keep the pose machine in its grab state
        if q(function() return inst.CatchOrientState end, 0) == 0 then q(function() inst.CatchOrientState = 1 end) end
        q(function() inst.GrabState = GR.id end)
        local el = now - GR.t0
        if not GR.checked and el > 0.2 then
            GR.checked = true
            grabNumbers("0.2 s in (pose " .. stateNow() .. ")", GR.id)
        end
        -- (v62 let go on the anim's IsLanding: it comes on almost at once in the air, so every grab
        -- lasted the 0.25 s minimum. IsAboutToLand never came before touchdown at all.)
        local about = q(function() return s0._skateboardingAnimParams.IsAboutToLand end, false) == true
        if S.GrabLetGo ~= 0 and el >= S.GrabMinTime and about then
            grabRelease("the game is about to land you")
        elseif el > S.GrabMaxTime then
            grabRelease("GrabMaxTime")
        elseif S.GrabHold ~= 0 and AS.mode then
            local x, y = analogStick(GR.stick)
            if x and math.sqrt(x * x + y * y) < 0.3 then
                GR.neutralSince = GR.neutralSince or now
                if now - GR.neutralSince > 0.08 then grabRelease("stick let go") end
            else
                GR.neutralSince = nil
            end
        end
    end
    grabVisuals(dt)
end
end   -- stance swap / sticks / grabs

------------------------------------------------------------------- varial
-- The game's trigger rotation: the PC stores the LT/RT values, Skate_CheckForRotations
-- shapes them by the current body-rotation mode and calls SetTargetRotationRatio, which
-- (in the default MANUAL mode) smooths USkaterMovementComponent._currentRotationRate --
-- signed degrees/second, + = right trigger, back to 0 when released. On the ground the
-- game does not rotate anything with it (only a pre-wind pose), so integrating it onto
-- the mesh yaw does not double up. The game applies BodyRotationRateMultiplier only in
-- the air, so we apply it here. In a REAL air (mv:IsFalling) the game rotates the capsule
-- itself, so we stop integrating. Other modes (Pressure/Speed/Timed) are pinned: they
-- fall back to the fixed spin.

-- where a total spin lands: "clean" (near a full turn), "switch" (near a half turn) or
-- "bail", with the nearest target angle
local function landingOf(total)
    local r = total - 360 * math.floor(total / 360 + 0.5)          -- -180 .. 180
    local a = math.abs(r)
    if a <= S.VarialLandWindow then return "clean", total - r end
    if a >= 180 - S.VarialLandWindow then return "switch", total - r + ((r >= 0) and 180 or -180) end
    return "bail", total - r
end

-- (v174) the spin as it has gone over the last poses: degrees per unit of the air's fraction (for the landing assist)
NATIVE.spinNote = function(frac, yaw)
    local H = NATIVE.spinH
    if not H or frac < (H[1] or 0) then H = {} NATIVE.spinH = H end
    H[5], H[6] = H[3], H[4]
    H[3], H[4] = H[1], H[2]
    H[1], H[2] = frac, yaw
end
NATIVE.spinRate = function(frac, yaw)
    local H = NATIVE.spinH
    if not H then return 0 end
    local f0, y0 = H[5] or H[3] or H[1], H[6] or H[4] or H[2]
    if not f0 or frac - f0 < 0.01 or frac - f0 > 0.25 then return 0 end
    return (yaw - y0) / (frac - f0)
end
-- (v94) THE TURN LOCKS ON THE HALF TURN IT IS COMING UP TO. "Once the 180 is locked on the way down, you plot the
-- trajectory." Six of the thirteen half-turn landings of 4 Oct 19:57-20:34 were already PAST the half turn when the landing
-- assist began (-192, -215, -186, -194 deg at 71-73 % of the air; +213), heading for -240..-281: no landing at all, so the
-- assist took them BACK to -180 -- the body turned 6-35 deg the wrong way over the last 150 ms. Now, from 35 % of the air,
-- the half turn AHEAD of the spin is taken as soon as two things hold: at the speed it has the spin cannot make the landing
-- after that one (its end would fall short of that landing's window), and it is as late as a smooth stop allows (three
-- times what is left to turn is no more than what the speed would still cover: the cubic from here, with the speed it has
-- now, then ends on the half turn with no speed and never passes it). From there the trigger no longer turns the body.
-- A spin that can make the next landing goes on as before; a slow one is finished by the landing assist as before.
NATIVE.lockAt = function(frac, y)
    if (S.HopLock or 0) == 0 or frac < 0.35 then return nil end
    local w = NATIVE.spinRate(frac, y)                           -- deg per whole air, over the last three frames
    if math.abs(w) < 40 then return nil end
    local s = (w > 0) and 1 or -1
    local D = 1 - frac
    local T = s * 180 * math.ceil(s * y / 180 - 1e-6)            -- the half turn ahead of it
    if T == 0 then return nil end                                -- (turning back to where it began: left alone)
    local gap = s * (T - y)
    if s * (y + w * D) >= s * T + 180 - S.VarialLandWindow then return nil end   -- it will make the landing after this one
    if 3 * gap > math.abs(w) * D then return nil end              -- still far enough off to stop on smoothly later
    return T, w
end
local function varialYaw(frac, now)
    if S.Varial == 0 then return nil end
    if NATIVE.rotPending and now - t0 >= S.StickRelease + 0.05 then   -- (v120) the crouch stick is back: Manual now
        NATIVE.rotPending = nil
        if q(function() s0:SetBodyRotationMode(MANUAL_MODE) return true end, false) then log(string.format("   body rotation mode -> Manual (4) %.2f s into the jump", now - t0))
        else NATIVE.rotRestore = nil end
    end
    local sign = (S.VarialInvert ~= 0) and -1 or 1
    local assistAt = 1 - S.VarialLandAssist

    if (S.VarialStyle ~= 0) and (rotMode == MANUAL_MODE) then
        if frac < assistAt and not assistFrom then               -- (v94) 'and not assistFrom': a locked turn is no longer the trigger's
            local dt = lastFrameT and (now - lastFrameT) or 0
            if dt < 0 or dt > 0.1 then dt = 0 end
            local realAir = q(function() return mv:IsFalling() end, false)
            if not realAir then
                local rate = q(function() return mv._currentRotationRate end, 0)
                if S.VarialNeedsPress ~= 0 and not (lastTrigAt and lastTrigAt >= t0 - 0.25) then rate = 0 end
                if math.abs(rate) < S.VarialMinRate then rate = 0 end
                if not NATIVE.rotPending then yawAcc = yawAcc + rate * rateMult * S.VarialRateScale * dt end   -- (v120) not before the game is in Manual
            end
            local lockT, lockW = NATIVE.lockAt(frac, yawAcc)      -- (v94)
            if lockT then
                local D = math.max(0.01, 1 - frac)
                assistFrom, assistYaw, assistTarget = frac, yawAcc, lockT
                local m0, dlt = lockW * D, lockT - yawAcc
                if m0 * dlt <= 0 then m0 = 0 elseif math.abs(m0) > 3 * math.abs(dlt) then m0 = 3 * dlt end
                NATIVE.spinM0 = m0
                log(string.format("   varial: %+.0f deg spun at %.0f %% of the air, turning %+.0f deg per whole air, heading for %+.0f -- LOCKED onto %+.0f (it cannot make the landing after that one; eased to rest there over the rest of the air)",
                    yawAcc, frac * 100, lockW, yawAcc + lockW * D, lockT))
                return yawAcc * sign
            end
            NATIVE.spinNote(frac, yawAcc)
            return yawAcc * sign
        end
    else
        -- fixed spin, started by a trigger press
        if fixedDir == 0 and frac < 0.6 and lastTrigAt >= t0 - 0.35 then
            fixedDir, fixedFrom = lastTrig, frac
            log(string.format("   varial (fixed) %s %d deg", fixedDir > 0 and "right" or "left", S.VarialDegrees))
        end
        if fixedDir == 0 then return nil end
        local span = math.max(0.95, assistAt) - fixedFrom
        if span <= 0.05 then return nil end
        yawAcc = fixedDir * S.VarialDegrees * smooth((frac - fixedFrom) / span)
        if frac < assistAt then NATIVE.spinNote(frac, yawAcc) return yawAcc * sign end
    end

    -- landing assist: steer what is left toward the landing it is closest to
    if not assistFrom then
        assistFrom, assistYaw = frac, yawAcc
        -- (v94) ...FROM THE LAST FRAME THE TRIGGER TURNED. On the frame the assist begins the trigger's turn is no longer added,
        -- so the yaw here is the frame before's: begun at THIS frame's point of the air the cubic stood still for a frame
        -- (20:34:33: 14, 8, 8, 5 deg) and took the spin's speed a third too low (two frames' turn over three frames' air:
        -- 'turning -130 deg per whole air' for a spin doing 219). It begins where that yaw was reached.
        if (S.HopLock or 0) ~= 0 and (S.VarialStyle ~= 0) and (rotMode == MANUAL_MODE) then
            local H = NATIVE.spinH
            if H and H[1] and H[2] == yawAcc and H[1] < frac and frac - H[1] < 0.1 then assistFrom = H[1] end
        end
        -- (v174) THE TURN IS FINISHED FOR YOU. "I don't know if you're snapping him to a perfect 180 ... if you snap it to the
        -- 180, that might help" (the tester, three rounds ago; I answered that the turn was not the cause). It is what is
        -- left: the eleven 180s of 4 Oct 19:24-19:40 ended -21, -12, +10, -5, +26, -15, -34, -9, -11, +38, -23 deg off the
        -- half turn (VarialLandAssist was 0: 'exactly what you spin is what you land'), so the feet came down that far
        -- round from the board's line and were then drawn onto their spots ON the deck -- up to 15 cm of slide per foot,
        -- most visible in the mini, whose feet arrive low. Now, over the last VarialLandAssist of the air, the spin is
        -- taken to the landing it is HEADING for (where it would end at the speed it has -- not where it is now: at this
        -- point a 180 is typically 130-150 deg round and still turning), and without a stop: the turn keeps the speed it
        -- has and eases to rest on the half or full turn (a cubic from its speed now to none). A spin heading for a bail
        -- just coasts to a stop.
        local D = math.max(0.01, 1 - assistFrom)
        local rateF = NATIVE.spinRate(assistFrom, yawAcc)
        local pred = yawAcc + rateF * D
        local kind
        kind, assistTarget = landingOf(pred)
        -- (v94) ...AND A SPIN THAT WOULD RUN PAST THE LANDING IT IS COMING UP TO, but not far enough for the one after, is stopped
        -- ON it (the lock's own rule, for a spin the lock did not need to take earlier): 'heading for' 40-140 deg past a half
        -- turn used to be no landing at all -- a bail, or the turn BACK to the landing behind
        if (S.HopLock or 0) ~= 0 and math.abs(rateF) >= 40 then
            local sgn = (rateF > 0) and 1 or -1
            local ahead = sgn * 180 * math.ceil(sgn * yawAcc / 180 - 1e-6)
            if ahead ~= 0 and sgn * pred >= sgn * ahead - S.VarialLandWindow and sgn * pred < sgn * ahead + 180 - S.VarialLandWindow then
                kind, assistTarget = ((ahead / 180) % 2 == 0) and "clean" or "switch", ahead
            end
        end
        if kind == "bail" then kind, assistTarget = landingOf(yawAcc) end
        if kind == "bail" then assistTarget = yawAcc + rateF * D * 0.5 end          -- no help for a bail: it coasts out
        local m0, dlt = rateF * D, assistTarget - assistYaw
        if m0 * dlt <= 0 then m0 = 0 elseif math.abs(m0) > 3 * math.abs(dlt) then m0 = 3 * dlt end   -- never past the landing and back
        NATIVE.spinM0 = m0
        if math.abs(yawAcc) > 1 or math.abs(assistTarget) > 1 then
            log(string.format("   varial: %+.0f deg spun at %.0f %% of the air, turning %+.0f deg per whole air, heading for %+.0f -- landing assist -> %+.0f (%s)",
                yawAcc, frac * 100, rateF, pred, assistTarget, kind))
        end
    end
    local u = math.min(1, math.max(0, (frac - assistFrom) / math.max(0.01, 1 - assistFrom)))
    local u2, u3 = u * u, u * u * u
    yawAcc = (2 * u3 - 3 * u2 + 1) * assistYaw + (u3 - 2 * u2 + u) * (NATIVE.spinM0 or 0) + (3 * u2 - 2 * u3) * assistTarget
    return yawAcc * sign
end

------------------------------------------------------------------- board trace
-- At the top of the pre-hook the anim fields still hold the GAME's values (native update
-- ran; we have not written yet this frame). The skater-side _skateboardingAnimParams is
-- never written by us.
local dbgKey, actorZ0 = nil, 0
local function traceAndDetect(el)
    local cm = modeNow()
    local gw = q(function() return inst.IsGroundedWheels end, true)
    local pF = q(function() return s0._skateboardingAnimParams.IsFalling end, false)
    local tp = q(function() return inst.IsTrickPending end, false)
    local gameAir = (cm == MODE_AIR) or (gw == false) or (pF == true)

    -- how far the deck tips while the wheels are off the ground (a roll-off)
    local pitch = nil
    if gameAir then
        pitch = boardPitch()
        if pitch and math.abs(pitch) > BD.maxAir then BD.maxAir = math.abs(pitch) end
    end

    if S.DebugBoardLog ~= 0 then
        local cr = q(function() return s0:IsCranking() end, "?")
        local key = table.concat({ tostring(cm), tostring(gw), tostring(pF), tostring(tp), tostring(cr) }, "/")
        if key ~= dbgKey then
            dbgKey = key
            local az = actorZ() or actorZ0
            local head, board = heights()
            pitch = pitch or boardPitch()
            log(string.format("   [board] %.2fs mode=%s%s wheelsGrounded=%s skaterFalling=%s trickPending=%s crouch=%s actorZ %+.0f  head %s board %s  deck pitch %s",
                el, tostring(cm), cm == MODE_AIR and "(AIR)" or (cm == MODE_BAILING and "(BAILING)" or ""),
                tostring(gw), tostring(pF), tostring(tp), tostring(cr), az - actorZ0,
                head and H.head0 and string.format("%+.0f", head - H.head0) or "?",
                board and H.board0 and string.format("%+.0f", board - H.board0) or "?",
                pitch and string.format("%+.0f", pitch) or "?"))
        end
    end
    return gameAir, (tp == true), cm
end

------------------------------------------------------------------- per frame
local function cancelJump(why)
    active = false if NATIVE.rotBack then NATIVE.rotBack() end
    clearLift()
    setYaw(0)
    log("   CANCELLED before take-off: " .. why .. " -- the game's own move plays out")
end

-- the game bailed you out of the hop (you clipped something): let go at once, and put you
-- back where the jump started once you are riding again
local function armBailReturn()
    if S.BailReturn == 0 or BR.pending then return end
    BR.pending, BR.t0, BR.sawBail, BR.backAt = true, os.clock(), true, nil
end

local function abortForBail()
    active = false if NATIVE.rotBack then NATIVE.rotBack() end
    clearLift()
    setYaw(0)
    lastHopEndAt = os.clock()
    log("   the GAME bailed you mid-hop -- letting go" .. (S.BailReturn ~= 0 and "; you go back to the jump's start" or "")
        .. tiltNote())
    armBailReturn()
end

-- the game took you off the board mid-hop without a ragdoll: SessionTweaks turns a low trick bail
-- into its run-out (you land on your feet, mode 0), and the game's own step-off does the same.
-- v59 kept lifting the walking skater and played a board landing. Let go; nothing to put back.
local function abortOffBoard(cm)
    active = false if NATIVE.rotBack then NATIVE.rotBack() end
    clearLift()
    setYaw(0)
    lastHopEndAt = os.clock()
    log(string.format("   the game took you OFF the board mid-hop (mode %s -- a run-out or a step-off) -- letting go%s",
        tostring(cm), tiltNote()))
end

-- the landed hop's name in the game's trick display: "Hippie Jump", "180 Mini Hippie Jump", ...
local function hopName(target)
    local spin = math.floor(math.abs(target or 0) / 180 + 0.5) * 180
    local name = (P.kind == "mini") and "Mini Hippie Jump" or "Hippie Jump"
    if spin > 0 then name = spin .. " " .. name end
    if P.switch then name = "Switch " .. name end
    trickNameLater(name)
end

-- the varial's outcome at touchdown. total = the body's yaw offset relative to the board.
-- Returns true if a bail was started (its outcome is checked a few frames later).
local function varialLanding(total)
    local full = 360 * math.floor(total / 360 + 0.5)          -- nearest full turn
    local kind, target = landingOf(total)
    log(string.format("   varial: %+.0f deg spun -> %s (%+.0f off %+.0f)", total, kind, total - target, target))
    if kind ~= "bail" and NATIVE.live and type(HJN_Land) == "function" then HJN_Land(S.LandFeetFrames, S.HopSinkFade or 0.22) end
    if kind == "clean" and (S.HopHold or 0) >= 2 and NATIVE.live and S.NativeHold == 1 and type(HJN_Hold) == "function" then HJN_Hold(36, 0, S.HopHoldOmega or 22) end   -- (v94) the body's heading eased through the landing pose's own step

    if kind == "switch" then
        if S.SwitchLanding == 0 then
            kind = (S.VarialBail ~= 0) and "bail" or "clean"
            target = full
        elseif S.SwitchLanding == 3 and inst then
            -- the other stance's pose carries its own 180 (the anim root turn), so the mesh keeps only
            -- what is left over and the body does not move in the world
            local wasGoofy = NAT.goofy
            local ok, why = stanceSwap(not VS.on)
            if ok then
                stanceWrite(true)                             -- this frame too: no one-frame flicker
                local left = wrap180(total - 180)
                log(string.format("   STANCE SWAP %s: the game now has you %s (the board never moved); %+.0f deg left to settle",
                    VS.on and "ON" or "OFF (back to your own stance)", wasGoofy and "REGULAR" or "GOOFY", left))
                startSettle(left)
                swapCommit()                                  -- (v65: trace only -- the actor turns a frame later)
                hopName(total - left)
                return false
            end
            log("   stance swap unavailable (" .. tostring(why) .. ") -- twisting to the nearest full turn")
            kind, target = "clean", full
        else
            -- the game's revert (2 = quiet: the deck held on its final heading, no revert pose); a leftover stance swap goes first
            if VS.on then stanceSwap(false) log("   (stance swap from before put back first)") end
            local ok, why = startRevertLanding(total, S.SwitchLanding >= 2, S.SwitchLanding == 4)
            if ok then                                        -- revertTick takes it from here
                if S.SwitchLanding >= 2 and not RV.swap then
                    trickNameHide("Revert", 2.0)              -- the game's own "Revert" line would give it away
                end
                hopName(target)
                return false
            end
            log("   switch landing unavailable (" .. tostring(why) .. ") -- twisting to the nearest full turn")
            kind, target = "clean", full
        end
    end
    if kind == "bail" then
        target = full
        if S.VarialBail ~= 0 then
            setYaw(total)                                        -- fall from where you are
            if doBail(string.format("landed %+.0f deg off the board", total - full), total - full) then return true end
        end
    end
    startSettle(total - target)
    hopName(target)
    return false
end

local function endJump(gameAirNow)
    local total = yawAcc * ((S.VarialInvert ~= 0) and -1 or 1)     -- the yaw actually applied
    active = false if NATIVE.rotBack then NATIVE.rotBack() end
    lastHopEndAt = os.clock()
    clearLift()
    if handedBack then setYaw(0) log("   end (handed back to the game): " .. stateNow()) return end
    if gameAirNow then
        -- the game is airborne under us (a drop): its own air + landing take it from here
        setYaw(0)
        log("   end in the game's air (drop) -- its own landing takes over: " .. stateNow() .. tiltNote())
        if tookOff then hopName(0) end
        return
    end

    if S.Varial ~= 0 and tookOff and math.abs(total) > 1 then
        if varialLanding(total) then return end                  -- a bail: its watcher decides the rest
    else
        setYaw(0)
        if tookOff then hopName(0) end
        -- (v168) A STRAIGHT HOP HAS A LANDING BLEND TOO (it was only called for a spun one): the feet go from where the air had
        -- them to the game's landing feet over a few poses, and the landing's poses are watched for a stretched leg -- the
        -- game stands the legs straight AND 12-15 cm long on the touchdown pose (bones 96/99 cm where 83/84 is theirs)
        if tookOff and NATIVE.live and type(HJN_Land) == "function" then HJN_Land(math.min(S.LandFeetFrames, 4), S.HopSinkFade or 0.22) end
        -- (v94) ...and its heading eased: riding regular the landing pose turns the hips 35 deg in four poses at touchdown
        if tookOff and (S.HopHold or 0) >= 2 and NATIVE.live and S.NativeHold == 1 and type(HJN_Hold) == "function" then HJN_Hold(36, 0, S.HopHoldOmega or 22) end
    end
    if tookOff then playSound(S.LandSound) end
    landAbsorbStart()
    log("   end: " .. stateNow() .. "  " .. stanceNow() .. (bankZeroed > 0 and
        string.format("  (carve blocked %d frames)", bankZeroed) or ""))
end

-- our varial bail: did the game take it? If not, land it after all.
local function bailWatchTick(now, cm)
    if not BV.pending then return end
    if cm == MODE_BAILING then
        BV.pending = false
        log("   bail took effect")
        BY.pending, BY.t0, BY.sawBail = true, now, true
    elseif now - BV.t0 > 0.35 then
        BV.pending = false
        log(string.format("   bail did NOT take effect (mode stayed %s) -- landing it instead; SessionTweaks.log shows whether Bail() was reached",
            tostring(cm)))
        startSettle(BV.residual)
        playSound(S.LandSound)
        landAbsorbStart()
    end
end

-- after a varial bail the body kept the landing yaw for the fall; restore it once riding again
local function bailYawTick(now, cm)
    if not BY.pending then return end
    if cm == MODE_BAILING then BY.sawBail = true end
    -- (v166) as soon as the fall is over, on the board OR on foot (it waited for riding, 8 s at most: on foot you faced one way
    -- and ran the other until then)
    if (BY.sawBail and cm ~= MODE_BAILING) or (now - BY.t0 > 8) then
        BY.pending = false
        setYaw(0)
        log("   body yaw restored after the bail")
    end
end

-- after a bail during (or right after) a hop: once the game has you riding again, put you back
-- where the jump started, set back a little further along the way you were going. The skater's
-- own TeleportTo (reached through the reflected K2_TeleportTo) also snaps the board to the
-- ground -- it is what the game's quest and transit teleports use.
local function bailReturnTick(now, cm)
    if not BR.pending then return end
    if now - BR.t0 > 12 then BR.pending = false log("   bail return: gave up waiting for you to ride again") return end
    if cm == MODE_BAILING then BR.sawBail = true BR.backAt = nil return end
    if not (BR.sawBail and cm == MODE_RIDING) then return end
    BR.backAt = BR.backAt or now
    if now - BR.backAt < 0.05 then return end
    BR.pending = false
    local x = start.x - start.dx * S.BailSetback
    local y = start.y - start.dy * S.BailSetback
    local z, yaw, sk = start.z, start.yaw, s0
    logOnce("tp", "   TRY K2_TeleportTo (first time)")
    NATIVE.gt(function()                    -- outside the animation update
        local ok, res = pcall(function()
            return sk:K2_TeleportTo({ X = x, Y = y, Z = z }, { Pitch = 0.0, Yaw = yaw, Roll = 0.0 })
        end)
        log(string.format("   bail return: back to the jump's start (%.0f cm behind it) -> %s", S.BailSetback,
            ok and tostring(res) or ("FAILED: " .. tostring(res))))
    end)
end

-- a bail can also come a moment AFTER the hop (landing into what you hopped at)
local function lateBailTick(now, cm)
    if cm == MODE_BAILING and not BV.pending and not BY.pending and now - lastHopEndAt < 1.0 then
        if not BR.pending and S.BailReturn ~= 0 then
            log("   the GAME bailed you just after a hop -- you go back to the jump's start" .. tiltNote())
            armBailReturn()
        end
    end
end

local function isMine(ctx)
    if not myAddr then return true end
    local who = q(function() return addr(ctx:get()) end, nil)
    return (who == nil) or (who == myAddr)
end

-- (v135) THE BAIL RESET. A bail in the middle of anything -- a grab, a hop's landing, a held deck tilt, the native half's
-- guard / hold / landing-feet windows -- used to leave those running on a ragdolling skater ("his legs got all
-- scrambled"). The first bailing frame closes every window on both halves and centres the sticks the game is shown;
-- riding (or standing) again reopens the native half
-- (v140) the no comply's outcome: the game's "No Comply" trick line marks the pop; the first riding frame after it = landed,
-- a bail within 2.5 s = bailed (the count is the tuning's yardstick: "one in three bails")
NATIVE.gameLine = function(text, now)
    -- (v148) the count is the window's below now (it needed the trick names on)
end
-- (v151) GRABS WHILE ROLLING, AND THE BONELESS AS IT IS DONE. On the board, on the ground, RB held = the back hand on the toe
-- edge between the feet (the Indy's spot), LB held = the front hand on it by the front foot (the Mute's); the native half
-- poses the arm, the lean and a crouch that goes only as deep as the hand is short (HJN_Bone). Slap a no comply with the hand
-- on the board and it STAYS there through the trick -- that is the boneless (v149 handed the game its Indy mid-trick: the
-- legs scrambled; v150 posed the hand only from the pop). The bumpers are read off the pad itself, and kept from the game
-- during the trick (it would pick a grab of its own once the board is caught). In any other air the hand lets go and the
-- game's own grabs are what they were.
NATIVE.gg = { kind = nil, frames = 0 }
NATIVE.groundGrab = function(cm, now)
    local GG = NATIVE.gg
    if type(HJN_Bone) ~= "function" or not NATIVE.grabLeftHand then return end
    if not GG.kind and GG.muted then GG.muted = nil pcall(HJN_TrickMute, 0) end       -- (v157) no hand on the board: no mute, whatever happened
    local NC = NATIVE.noComply
    local inNC = (NC ~= nil) and (NC.guard ~= nil)
    -- (v191) HAS HE RISEN SINCE THE WINDOW OPENED? The window also opens on a drop or a bounce with no flick when the last
    -- flip trick was a no comply (22:12:18 on 6 Oct: "TAKEN ... landed 0.33 s", the plant foot never down). The boneless's
    -- let-go below is for a real trick only: the mesh 15 cm up since the window opened WITH THE BOARD STILL WITHIN 6 CM
    -- of where it stood over the ground then -- a no comply's pop lifts the body while the board is still down (the deck
    -- -0.5..+3.6 cm up when the mesh is 15 up, all 190 recorded tricks, 67-158 ms in); a launch off a ramp carries the
    -- board up with it (+8 cm and more, 44 recorded airs) and a drop only falls. Not readable = as if risen.
    if not inNC then GG.ncAt, GG.ncZ0, GG.ncUp = nil, nil, nil
    else
        if GG.ncAt ~= NC.guard then GG.ncAt, GG.ncZ0, GG.ncUp = NC.guard, nil, nil end
        if not GG.ncUp then
            local z = q(function() return mesh:K2_GetComponentLocation().Z end, nil) or actorZ()
            local over = (type(HJN_DeckOver) == "function") and q(function() return tonumber(HJN_DeckOver()) end, nil) or nil
            if type(z) ~= "number" then GG.ncUp = true
            else
                if not GG.ncZ0 then GG.ncZ0, GG.ncOver0 = z, over end
                if z - GG.ncZ0 >= 15 and (not GG.ncOver0 or (over ~= nil and over - GG.ncOver0 < 6)) then GG.ncUp = true end
            end
        end
    end
    if not GG.kind and not GG.ffLatch and not inNC and (S.GroundGrabs == 0 or cm ~= MODE_RIDING) then return end      -- nothing on, nothing could start: no pad read
    local btn = tonumber((tostring(type(HJN_PadSticks) == "function" and HJN_PadSticks() or "")):match("^%S+ %S+ %S+ %S+ %S+ %S+ (%d+)"))
    local lb, rb
    if btn then lb, rb = (math.floor(btn / 256) % 2) == 1, (math.floor(btn / 512) % 2) == 1     -- XInput's shoulders: 0x0100, 0x0200
    else
        local held = tonumber(type(HJN_Bumpers) == "function" and HJN_Bumpers() or 0) or 0
        lb, rb = (held == 1 or held == 3), (held == 2 or held == 3)
    end
    -- (v152) THE HAND STAYS ON INTO THE AIR. v151 kept it on the ground and through a no comply only, and let go 0.2 s after
    -- every no comply's pop (18:03:58.6, 18:04:04.1, 18:04:21.4: each time a fifth of a second after the pop -- the "is it
    -- grinding" test, new in v151, is the suspect; it now only stops a grab from STARTING) and in every other air ("if I'm
    -- grabbing the board on the ground and I go get air, it also releases"). A grab starts on the ground (or in a no
    -- comply); once on, it holds while its bumper is down and you are on the board -- rolling, an ollie, a drop, a no
    -- comply -- and a reason to let go has to last 0.12 s (one odd frame does not drop the hand). The log says the reason.
    -- (v160) after a finger flip the bumper is still down: no new grab until it has been let go, and in the air the game is
    -- not shown it (it would pick a grab of its own in the middle of the flip)
    if GG.ffLatch then
        if not (lb or rb) or cm == MODE_BAILING then GG.ffLatch = nil
        else
            if btn and cm == MODE_AIR then pcall(HJN_Set, "bumpermask", 0.3) end
            if not GG.kind then return end
        end
    end
    local onBoard = (cm == MODE_RIDING or cm == MODE_AIR)
    local busy = active or (NATIVE.dropBusy and NATIVE.dropBusy()) or false
    local ncOff = inNC and S.Boneless == 0                             -- the boneless switched off: no hand in a no comply
    local canStart = not busy and not ncOff and ((S.GroundGrabs ~= 0 and cm == MODE_RIDING) or (inNC and onBoard))
    local canKeep = not busy and not ncOff and onBoard and (S.GroundGrabs ~= 0 or inNC)
    -- the bumpers are the hand's, not the game's: during a no comply, and in any air the hand is carried into (the game,
    -- seeing a bumper held once the board is caught, would pick a grab of its own and pose the legs for it)
    if btn and ((inNC and S.Boneless ~= 0) or (GG.kind and cm == MODE_AIR)) then pcall(HJN_Set, "bumpermask", 0.3) end
    local want, why = nil, nil
    if GG.kind then
        local held = (GG.kind == 102 and rb) or (GG.kind == 3 and lb)
        -- (v160) THE FINGER FLIP. "I can hold a grab, do a flip input, the game will flip -- and you need to force it to release
        -- the hand": a flip trick in the air with the hand on (not the no comply, not an ollie) lets the hand go FingerFlipHold
        -- seconds after it is seen; the native half eases it off over a few frames, on the turning board
        local flip = nil
        -- (v161) where the board rides over the ground with the hand on (for "it has left the ground")
        local over = (S.GroundGrabFingerFlip ~= 0 and type(HJN_DeckOver) == "function") and tonumber(HJN_DeckOver()) or nil
        if cm == MODE_RIDING and over then GG.rideOver = over end
        if S.GroundGrabFingerFlip ~= 0 and cm == MODE_AIR and not inNC then
            local tn = tostring(q(function() return s0:GetCurrentFlipTrickName():ToString() end, "") or ""):lower()
            if tn ~= "" and tn ~= "none" and not tn:find("ollie$") and not tn:find("rgs_pressure_kickflip", 1, true) and not tn:find("sws_pressure_kickflip", 1, true) then
                GG.flipAt = GG.flipAt or now
                -- (v161) THE CLOCK STARTS WHEN THE BOARD LEAVES THE GROUND: the ten finger flips of 21:02-21:03 all let go 0.05-0.07 s
                -- after the game's "in the air" -- which starts with the flick, while the board is still down ("it was letting go as
                -- soon as the input was done"). Lift-off = the deck 4 cm over where it rode (without the native half's ray:
                -- 0.12 s after the flick); and 0.6 s after the flick whatever happens
                if not GG.liftAt then
                    local lifted
                    if over then lifted = over > (GG.rideOver or 6) + 4 else lifted = (now - GG.flipAt) >= 0.12 end
                    if lifted then GG.liftAt, GG.liftOver = now, over end
                end
                if (GG.liftAt and now - GG.liftAt >= S.FingerFlipHold) or now - GG.flipAt >= 0.6 then flip = tn end
            end
        else
            GG.flipAt, GG.liftAt = nil, nil
        end
        -- (v191) THE BONELESS'S HAND LETS GO AS THE BOARD GOES BACK UNDER THE FEET. The two bonelesses the regular rider
        -- accepted had the hand on for the first 0.2 and 0.4 s; with the bumper held on through the air and the board caught
        -- (5 Oct 20:02-20:04) the hand reached after a board that had gone back down, 14-31 cm short of it, the back bent 55
        -- deg and the hips raised 18 cm, to the landing. The hand comes off BonelessHandTime (0.4 s) after the trick began:
        -- where the accepted switch boneless's hand began to ease (+383 ms). The game's catch-orient state is the STICKS'
        -- (it comes up only while a stick is pushed at the catch: 35 of 62 pops on 5 Oct, 250-384 ms in, never before): from
        -- a quarter second on it lets the hand go too. The native half eases it off. As after a finger flip the bumper has
        -- to be let go before a new grab. Only in a trick that has left the ground (GG.ncUp).
        local blOff = nil
        if inNC and GG.ncUp and not flip and S.BonelessHandTime > 0 and cm == MODE_AIR then
            local t = now - NC.guard
            local cs = (t >= 0.25 and type(HJN_CatchState) == "function") and (tonumber(HJN_CatchState()) or 0) or 0
            if cs > 0 then blOff = string.format("a stick is on the game's catch (catch-orient state %d, %.0f ms into the trick)", cs, t * 1000)
            elseif t >= S.BonelessHandTime then blOff = string.format("%.2f s into the trick (BonelessHandTime; the game's catch-orient state %d)", t, cs) end
        end
        if flip then
            why = string.format("THE FINGER FLIP: '%s' flicked with the hand on -- the hand lets go %.0f ms after the flick, %s (press the bumper again for a new grab)", flip,
                (now - (GG.flipAt or now)) * 1000, GG.liftAt and string.format("%.0f ms after the board left the ground (the deck %s cm up then, %s now)", (now - GG.liftAt) * 1000,
                    GG.liftOver and string.format("%.0f", GG.liftOver) or "?", over and string.format("%.0f", over) or "?") or "the board never seen off the ground")
            GG.ffLatch, GG.offSince = true, now - 1
            GG.flips = (GG.flips or 0) + 1
        elseif blOff then
            why = "THE BONELESS: " .. blOff .. " -- the hand lets go (press the bumper again for a new grab)"
            GG.ffLatch, GG.offSince = true, now - 1
        elseif canKeep and held then want = GG.kind
        elseif not held then why = string.format("%s let go (the pad reads %s)", (GG.kind == 102) and "RB" or "LB", btn and string.format("0x%04x", btn) or "no XInput")
        elseif busy then why = active and "a hippie jump" or "a drop-in"
        elseif ncOff then why = "a no comply with the boneless switched off" GG.offSince = now - 1   -- (v186) at once: it stayed on 0.13 s into the trick and read as a boneless
        else why = "off the board (mode " .. tostring(cm) .. ")" end
    elseif canStart and q(function() return inst.IsGrinding end, false) ~= true then
        want = (rb and 102) or (lb and 3) or nil
        -- (v191) too late in a no comply's air for a hand (it would arrive as it is let go: 22:12:28 on 6 Oct, pressed 0.25 s
        -- in, on at 0.5 s): no hand, the trick keeps its name, and the bumper has to be let go as after the let-go itself
        if want and inNC and GG.ncUp and cm == MODE_AIR and S.BonelessHandTime > 0 then
            local t = now - NC.guard
            if t >= math.max(S.BonelessHandTime - 0.2, 0.1) or (t >= 0.25 and type(HJN_CatchState) == "function" and (tonumber(HJN_CatchState()) or 0) > 0) then
                want = nil GG.ffLatch = true
                GG.lateTold = (GG.lateTold or 0) + 1
                if GG.lateTold <= 20 then log(string.format("rolling grab: the bumper came %.2f s into a no comply -- too late for a hand (BonelessHandTime %g): none goes on; let the bumper go for a new grab", t, S.BonelessHandTime)) end
            end
        end
    end
    if not want then
        if not GG.kind then return end
        GG.offSince = GG.offSince or now
        if now - GG.offSince < 0.12 and cm ~= MODE_BAILING then
            want = GG.kind                                              -- held on through the odd frame
        else
            pcall(HJN_Bone, 0, 0)
            if (GG.told or 0) <= 60 then
                log(string.format("rolling grab: let go after %.2f s -- %s (%d frames; mode %s%s; the hand came within %s cm of its spot, the hips came down %s cm at most, the back bent %s deg at most)",
                    now - (GG.t0 or now), tostring(why), GG.frames, tostring(cm), inNC and ", in a no comply" or "",
                    GG.gap and string.format("%.0f", GG.gap) or "?", GG.drop and string.format("%.0f", GG.drop) or "?", GG.lean and string.format("%.0f", GG.lean) or "?"))
            end
            GG.kind, GG.offSince, GG.flipAt, GG.liftAt = nil, nil, nil, nil
            if GG.muted then GG.muted = nil pcall(HJN_TrickMute, 0) end                   -- (v155) the flip tricks are back
            return
        end
    else
        GG.offSince = nil
    end
    if GG.kind ~= want then
        if inNC and NATIVE.noComplyCatchNow then pcall(NATIVE.noComplyCatchNow) end      -- (v191) a hand that goes on inside the trick: the game catches this one too
        GG.kind, GG.t0, GG.frames, GG.gap, GG.drop, GG.airTold = want, now, 0, nil, nil, nil
        GG.lean, GG.flipAt, GG.liftAt, GG.rideOver = nil, nil, nil, nil
        pcall(HJN_Set, "bonehips", S.GroundGrabHips)                                   -- (v156) the squat's height over the deck
        pcall(HJN_Set, "boneback", S.GroundGrabBack) pcall(HJN_Set, "bonesplay", S.GroundGrabSplay) pcall(HJN_Set, "bonealongf", S.GroundGrabFrontAlong) pcall(HJN_Set, "bonealongb", S.GroundGrabBackAlong)   -- (v158)
        pcall(HJN_Set, "plantflex", S.NoComplyPlantFlex or 85)                         -- (v180) the plant foot's heel comes up where the ankle cannot bend that far (native v96: PlantHeel)
        pcall(HJN_Set, "bonelean", S.GroundGrabLean)                                   -- (v155) the back bends first
        -- (v155) no flip tricks with a hand on the board: every trick definition but the no comply's two and the low-pop
        -- ollies is muted in the game's own list until the hand lets go
        if S.GroundGrabBlockFlips ~= 0 and type(HJN_TrickMute) == "function" and not GG.muted then
            local n = tonumber(HJN_TrickMute((S.GroundGrabBlockFlips >= 2) and 1 or 2)) or -1    -- (v162) the native half: 1 = every flip, 2 = the pressure flips left on
            GG.muted = n >= 0
            if n < 0 then logOnce("mutefail", "rolling grab: the game's trick list could not be reached -- flip tricks are NOT blocked while grabbing") end
        end
        GG.left = (NATIVE.grabLeftHand(want) == true) ~= (NATIVE.mirrorAsset ~= nil)   -- (review) the mirror switch fakes NAT.mirror; which hand trails is the game's real mirror's
        GG.told = (GG.told or 0) + 1
        if GG.told <= 60 then
            log(string.format("rolling grab: %s held %s -- the %s hand goes to the %s spot on the board (the hips down to %g cm over the deck, %g cm at most; the back up to %g deg)", (want == 102) and "RB" or "LB",
                inNC and "in a no comply" or "on the board", GG.left and "left" or "right", (want == 102) and "Indy's" or "Mute's", S.GroundGrabHips, S.GroundGrabCrouch, S.GroundGrabLean))
        end
    end
    -- (v153) in the air the hips come down less ("it doesn't really pop that high": the game's pop was the same 132 cm with
    -- the hand on or off -- the hips, pulled 45 cm down to the board, made it read low); and with the switch no comply drawn
    -- mirrored the back hand is the mesh's other one
    -- (v157) ...but in a NO COMPLY the full crouch: the hand stays ON the board from the pop (the skater is lifted 40 cm in
    -- 0.15 s while the board is still down: v156 let the hand come 37 cm off it), the hips coming up as the board does.
    -- And no hand swap in switch: the mirrored trick keeps each foot at its own end of the board (see the wiring)
    local crouch = (cm == MODE_AIR and not inNC) and math.min(S.GroundGrabAirCrouch, S.GroundGrabCrouch) or S.GroundGrabCrouch
    local left = GG.left
    local r = tostring(HJN_Bone(0.25, left and 0 or 1, want, crouch) or "")
    GG.frames = GG.frames + 1
    local gap, drop, lean = r:match("^%S+ (%S+) %S+ (%S+) ?(%S*)")
    gap, drop, lean = tonumber(gap), tonumber(drop), tonumber(lean)
    if lean then GG.lean = math.max(GG.lean or 0, lean) end
    if gap and GG.frames > 8 then GG.gap = GG.gap and math.min(GG.gap, gap) or gap end
    if drop then GG.drop = math.max(GG.drop or 0, drop) end
    if inNC then NC.bone = true NC.boneName = (GG.kind == 3) and "Bean Plant" or "Boneless" end   -- (v164) the front hand's is a bean plant
    if cm == MODE_AIR and not GG.airTold then
        GG.airTold = true
        if (GG.told or 0) <= 60 then log(string.format("rolling grab:    carried into the air %.2f s after it started%s", now - (GG.t0 or now), inNC and " (a no comply: the boneless)" or "")) end
    end
end
-- (v151) THE TRICK'S NAMES, the game's own line: "No Comply" / "Boneless", and with a turn "FS No Comply", "BS Boneless 360"...
-- ("when I do a 180 no comply, it calls it a FS or BS pressure kickflip": the definition keeps a second set of names, by
-- rotation, that only the native half can write; "it says no comply and then it says boneless": the mod showed a line of
-- its own beside the game's -- now the game's line itself says it)
NATIVE.noComplyNames = function(base)
    local NC = NATIVE.noComply
    if not NC or NC.namesAre == base then return end
    local n = 0
    for _, nm in ipairs({ "TRICK_RGS_Pressure_KickFlip", "TRICK_SWS_Pressure_KickFlip" }) do
        local d = alive(q(function() return StaticFindObject("/Game/Data/Input/FlipTricks/" .. nm .. "." .. nm) end))
        if d then
            local pre = nm:find("SWS", 1, true) and "Switch " or ""
            if pcall(function() d.DisplayName = FText(pre .. base) end) then n = n + 1 end
            local a = addr(d)
            if a and type(HJN_TrickName) == "function" and NC.rotKeys then
                for key, fmt in pairs({ Frontside = "FS %s", Backside = "BS %s", Frontside360 = "FS %s 360", Backside360 = "BS %s 360" }) do
                    local kv = NC.rotKeys[key]
                    if kv and tonumber(HJN_TrickName(a, kv, pre .. string.format(fmt, base))) == 1 then n = n + 1 end
                end
            end
        end
    end
    NC.namesAre = base
    NC.namesTold = NC.namesTold or {}
    if not NC.namesTold[base] then
        NC.namesTold[base] = true
        log(string.format("no comply: the game's trick names read '%s' now, with its FS / BS / 360 names (%d of 10 texts written)", base, n))
    end
end
-- (v148) THE PLANTED FOOT. Every no comply of 3 Oct bailed 0.1 s after its pop, by the game's impact bail
-- (ASkaterCharacterBase::ImpactBailCheck, SessionTweaks' "[runout] bail ... exe+0xff6958"): the animation plants the front
-- foot on the ground while the game counts you as in the air, and in the air ANY hit on a body part that is not a hand or
-- an arm bails you (riding, it takes an impulse of 10000). From the moment the game takes the trick (its current flip trick
-- is the pressure kickflip slot the no comply lives in) until 0.2 s after the wheels are down, the native half passes that
-- check over (HJN_Set("nobail"), held open a frame at a time: it shuts by itself). The board's own collision bails still run.
-- (v149) the same window keeps the planted foot ON the ground (HJN_Set("footground"): the native half traces each foot onto
-- the world and lifts one the animation left under it) and runs the boneless
-- (v156) THE BONELESS'S OWN POP. "It's not getting very high ... he doesn't fully extend that plant leg": the traces of 19:18
-- have the skater 46 cm up at the top with the hips pulled 16-23 cm down for the leg AND the hand -- the plant leg bent.
-- With a hand on the board the game's pop for the trick is BonelessExtraPop (higher: the hips are held at the plant leg's
-- full stretch, so the board comes up to the hand); without, NoComplyExtraPop. One number in the two definitions, written
-- when the hand goes on or comes off -- never during a trick (the game takes the pop at the flick).
-- (v157) what could be holding the game's own controls, for the log line of every Y on foot (3 Oct 19:47:35: six presses in
-- five seconds after a grabbed low-pop ollie and the game put the board down for none of them; nothing of the mod's was
-- open by its own log -- this says what the GAME held)
NATIVE.heldNote = function()
    if type(HJN_Held) ~= "function" then return "" end
    local on, muted, num, bump, grab, mask = tostring(HJN_Held() or ""):match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+)")
    if not on then return "" end
    local GG, NC = NATIVE.gg, NATIVE.noComply
    return string.format(" [the game's trick list: %s of %s muted (our mute %s); bumper byte %s, grab state %s, bumper mask %s; rolling grab %s, no comply window %s]",
        muted, num, on == "1" and "ON" or "off", bump, grab, mask == "1" and "ON" or "off", (GG and GG.kind) and tostring(GG.kind) or "none", (NC and NC.guard) and "OPEN" or "shut")
end
-- (v191) A HAND PUT ON AFTER THE POP: the pop numbers are the no comply's (the game took them at the flick) but the game
-- reads ForceAutoCatch every tick of the trick (FlipTricksHandler::CheckForBoardFlipOrRotationContinuousInput, off the
-- skater's current trick), so the catch can still be given. The sync writes both definitions afresh once the window shuts.
NATIVE.noComplyCatchNow = function()
    local NC = NATIVE.noComply
    if not NC or not NC.applied or S.NoComply == 0 or S.BonelessAutoCatch == 0 then return end
    local n = 0
    for _, nm in ipairs({ "TRICK_RGS_Pressure_KickFlip", "TRICK_SWS_Pressure_KickFlip" }) do
        local d = alive(q(function() return StaticFindObject("/Game/Data/Input/FlipTricks/" .. nm .. "." .. nm) end))
        if d and pcall(function() d.ForceAutoCatch = true end) then n = n + 1 end
    end
    NC.popIs = nil
    NC.catchTold = (NC.catchTold or 0) + 1
    if NC.catchTold <= 20 then log(string.format("no comply: a hand went on after the pop -- the game catches the board for this trick (written to %d of the 2 definitions; the pop stays the no comply's)", n)) end
end
NATIVE.noComplyPopSync = function()
    local NC = NATIVE.noComply
    if not NC or not NC.applied or NC.guard or S.NoComply == 0 then return end
    local GG = NATIVE.gg
    local hand = (GG ~= nil) and (GG.kind ~= nil) and S.Boneless ~= 0
    local want = hand and S.BonelessExtraPop or S.NoComplyExtraPop
    -- (v170) THE BONELESS'S BOARD COMES UP TO THE BODY. "The back leg needs to bend and come up. The front leg just needs to
    -- plant and be vertical. The whole board needs to rise and his back needs to straighten -- he needs to stand upright, he's
    -- slouched the whole time." The trace of 13:04:25: the skater's root rises 83 cm, the board 52 (its own pop: the same
    -- 15..25 as the no comply's), so at the top it hangs 31 cm lower under him than it rides -- and with a hand on it the
    -- body is held to the BOARD: the hips 50 cm over it (107 over the ground where the animation has 152), the back bent
    -- 38-48 deg, all trick long. With a hand on the board the trick's board pop is BonelessBoardPopMin..Max instead: the
    -- board rises to the body, and the squat and the lean (which only ever do what the hand needs) let go by themselves.
    local bMin = hand and S.BonelessBoardPopMin or S.NoComplyPopHeightMin
    local bMax = hand and S.BonelessBoardPopMax or S.NoComplyPopHeightMax
    -- (v191) ...AND THE GAME CATCHES IT. "The boneless are something nightmares are made of." Every boneless the regular
    -- rider did and accepted (5 Oct 17:31-20:04) ran with NoComplyAutoCatch 1: the game brought the board back under the
    -- feet 0.35-0.4 s after the pop. The setting went to 0 in the menu at 20:18:51 and every boneless since, the goofy
    -- rider's all of them, kept its board at hip height, pitched 30 deg, until it fell to the ground: the deck 53-62 cm
    -- above where it rides under him from +450 ms, the hips 13-19 cm over it, the front ankle above the hips, the body 26-37
    -- cm into the ground at the landing (19 of 19 recordings; the regular rider's own no complies changed the same way at
    -- that minute). A board popped 45..54 cm up to a hand has to be caught: with a hand on, the definition's ForceAutoCatch
    -- is on (BonelessAutoCatch); without, it is NoComplyAutoCatch's as before.
    local catch = (hand and S.BonelessAutoCatch ~= 0) or (S.NoComplyAutoCatch ~= 0)
    local key = string.format("%g/%g/%g/%s", want, bMin, bMax, catch and "c" or "m")
    if NC.popIs == key then return end
    local n = 0
    for _, nm in ipairs({ "TRICK_RGS_Pressure_KickFlip", "TRICK_SWS_Pressure_KickFlip" }) do
        local d = alive(q(function() return StaticFindObject("/Game/Data/Input/FlipTricks/" .. nm .. "." .. nm) end))
        if d and pcall(function() d.AdditionalPopHeightMax = want d.PopBoardHeightAdditionalOffsetMin = bMin d.PopBoardHeightAdditionalOffsetMax = bMax end) then n = n + 1 end
        if d and pcall(function() d.ForceAutoCatch = catch end) then NC.catchBack = tostring(q(function() return d.ForceAutoCatch end, "?")) else NC.catchBack = "NOT WRITTEN" end
    end
    NC.popIs = key
    NC.popTold = (NC.popTold or 0) + 1
    if NC.popTold <= 60 then
        log(string.format("no comply: the pop height is %g and the board's own pop %g..%g now (%s), %s (ForceAutoCatch reads %s) -- written to %d of the 2 definitions", want, bMin, bMax,
            hand and "a hand is on the board: the boneless's" or "no hand on the board: the no comply's", catch and "the game catches the board" or "you catch the board", tostring(NC.catchBack), n))
    end
end
-- (v161) the switch no comply's other stance, put back: the stance, and the mesh's half turn with it
NATIVE.ncSwapOff = function()
    local NC = NATIVE.noComply
    -- (v168) the body is held as it stands over the swap's own frames (the traces of 23:52:58-23:53:15: two poses at the landing
    -- with the animation's feet at the opposite ends, then the hips 70 deg round) -- the native half, four poses and a blend
    if NC and NC.flip and type(HJN_Set) == "function" and not (VS.graph and VS.graph.sock and VS.graph.turned) then pcall(HJN_Set, "posehold", 4) end   -- (v183: not while the game's foot sockets are turned -- its feet no longer jump to the other stance's on the swap's last pose, and the held hips whipped 45 deg in four poses after it)
    if NATIVE.mirrorAsset then NATIVE.mirrorEnd() else stanceSwap(false) end   -- (v189)
    if NC and NC.flipYaw and mesh then q(function() mesh.RelativeRotation.Yaw = NC.flipYaw end) end
    if NC then NC.flip, NC.flipYaw, NC.flipN = nil, nil, nil end
    pcall(HJN_Set, "plantfoot", -1)
end
NATIVE.noComplyResult = function(cm, now)
    local NC = NATIVE.noComply
    if not NC then return end
    local hasNoBail = type(HJN_NoBail) == "function"
    if NC.guard then
        local why = nil
        if cm == MODE_BAILING then why = "BAILED" NC.bails = (NC.bails or 0) + 1
        elseif cm == MODE_AIR then
            if not NC.guardAir then NC.guardAir = now NC.pops = (NC.pops or 0) + 1 end
            NC.guardLand = nil
        elseif NC.guardAir and cm == MODE_RIDING then
            -- (v171) THE SWITCH TRICK'S PLANT IS LET GO AT THE LANDING. The plant's window was renewed until the guard closed
            -- (0.2 s after the wheels came down) and then ran its last 0.25 s: for 0.45 s of riding the planted foot was kept
            -- on the spot of the stance the trick was SHOWN in (R at -13 cm along the deck in the trace of 13:36:2x) while
            -- the game, back in your own stance, wanted it at -26 -- then it slid there. Now the window ends 0.12 s after
            -- the touchdown and is not renewed after it.
            -- (v191) the goofy rider's NORMAL boneless: 2 of the 9 recorded landed with the right shin at 65-80 % of its length
            -- for a second and more (6 Oct 21:58:09, 5 Oct 22:01:41), as the switch one did before v190. The switch trick
            -- gets the native half's watch through mirrorEnd; this one gets it here (its log line reads "switch plant")
            if not NC.guardLand and NC.bone and NAT.goofy and not NC.guardSws and not NC.flip and not VS.on and S.NoComplyOriginal == 0
                and type(HJN_Set) == "function" and (tonumber(NATIVE.v) or 0) >= 102 then
                pcall(HJN_Set, "leglinger", 4)
                NC.lingerTold = (NC.lingerTold or 0) + 1
                if NC.lingerTold <= 20 then log("no comply: a goofy rider's boneless is down -- the legs are watched for up to 4 s (the native half's line reads 'after a goofy switch plant')") end
            end
            if NC.guardSws and not NC.guardLand and S.NoComplyPlant ~= 0 and S.NoComplyOriginal == 0 then pcall(HJN_Set, "plant", 0.12) end
            NC.guardLand = NC.guardLand or now
            if NC.flip then NATIVE.ncSwapOff() end                                        -- (v160) the wheels are down: your own stance again
            if now - NC.guardLand >= 0.2 then why = "landed" end
        elseif not NC.guardAir and now - NC.guard > 0.8 then why = "not popped"
        end
        if not why and now - NC.guard > 3 then why = "three seconds on, still not down" end
        if why then
            pcall(HJN_Set, "nobail", 0) pcall(HJN_Set, "footground", 0) pcall(HJN_Set, "plant", 0) pcall(HJN_Set, "yaw180", 0)
            if NC.flip then NATIVE.ncSwapOff() end                                        -- (v160) whatever ended it: your own stance again
            local pr = tostring(type(HJN_Plant) == "function" and HJN_Plant() or "")
            local held, kept = pr:match("^(%d+) (%S+)")
            local stepMs = tonumber(pr:match("^%S+ %S+ %S+ %S+ (%S+)"))            -- (v156) ms from the plant to the step onto the board
            local _, skips = tostring(hasNoBail and HJN_NoBail() or ""):match("^(%-?%d+) (%d+)")
            local lifts, most = tostring(type(HJN_FootGround) == "function" and HJN_FootGround() or ""):match("^(%d+) (%S+)")
            local b = NC.bone
            log(string.format("no comply: %s %.2f s after the game took the trick -- %d body hits passed over, the planted foot lifted onto the ground on %d frames (by up to %.0f cm)%s (%d bails in %d pops so far)",
                why, now - NC.guard, (tonumber(skips) or 0) - (NC.guardSkips or 0), (tonumber(lifts) or 0) - (NC.guardLifts or 0), tonumber(most) or 0,
                string.format("; the plant foot held on %d poses, the hips kept down up to %s cm, %s", (tonumber(held) or 0) - (NC.guardPlant or 0), tostring(kept or "?"),
                    (stepMs and stepMs >= 0) and string.format("it left the ground for the board %.0f ms after it went down", stepMs) or "it did not step onto the board")
                    .. (b and "; a BONELESS: a hand was on the board (the game's line says so)" or ""),
                NC.bails or 0, NC.pops or 0))
            NC.guard, NC.guardAir, NC.guardLand, NC.bone, NC.flip = nil, nil, nil, nil, nil
        else
            if S.NoComplyNoBail ~= 0 then pcall(HJN_Set, "nobail", 0.3) end
            if S.NoComplyFootFix ~= 0 and S.NoComplyOriginal == 0 then pcall(HJN_Set, "footground", 0.3) end
            -- (v154) the plant foot stays down (the native half lets it push off when the leg can reach no longer; the window is
            -- held for at most 0.9 s after the pop)
            if NC.flipN then NC.flipN = NC.flipN + 1 end
            -- (v162) ...AND THE GAME'S FOOT IK OFF. v161: "the upper half is in the right location, but his bottom half spins
            -- 180 -- hippie jumps all over again". The same cause as there: the game's foot IK holds each foot to its own
            -- socket on the board, whichever way the body is turned (the trace of v161: the mesh turned 180, the feet's places
            -- along the deck unchanged). With the other stance on, both foot IK weights are zeroed every frame (as the hippie
            -- jump does past a quarter turn): the legs are the animation's, turned with the body
            -- (v183) ...unless the game's foot sockets are turned with the body (NoComplySwitchFeet, native v99): then its feet are
            -- right, on this pose as on the regular side's, and its IK stays on
            local swG = VS.graph
            if NC.flip and not (swG and swG.sock and (swG.turned or not swG.off)) then footIK(0) end
            -- (v161) in a switch trick the plant waits until the other stance is on the screen: the frames before it still show
            -- your own stance's pose, whose OTHER foot goes down first
            local swWait = NC.guardSws and S.NoComplySwitchMirror ~= 0 and S.NoComplyOriginal == 0 and (not NC.flipTried or (NC.flip and (NC.flipN or 0) < 3))
            -- (v163) ...and until then BOTH FEET STAND ON THEIR RIDING SPOTS (the native half): the first frames of the trick are
            -- your own stance's (its other foot steps off), then the swap lands -- "his feet right at the start do some squirrely
            -- things, they almost try to step on the other side of the board"
            if swWait then pcall(HJN_Set, "feethold", 0.06) end
            if S.NoComplyPlant ~= 0 and S.NoComplyOriginal == 0 and not swWait and (not NC.guardAir or now - NC.guardAir < 0.9) and not (NC.guardSws and NC.guardLand) then pcall(HJN_Set, "plant", 0.25) end
            if NC.bone and NC.namesAre ~= (NC.boneName or "Boneless") then pcall(NATIVE.noComplyNames, NC.boneName or "Boneless") if S.TrickNames == 0 then pcall(trickNameHide, (NC.boneName or "Boneless"), 5, true) end end   -- (v151) a hand went on during the trick
            if NC.guardAir then
                -- (v153) THE SWITCH NO COMPLY, MIRRORED. The game has ONE no-comply animation, made for the regular stance;
                -- in switch (the deck turned round under you, the other foot leading) it planted the trailing foot. From
                -- the pop on, the anim instance's own mirror flag is flipped each frame, here in the pre-hook (the game sets
                -- it afresh every frame): the same mirror that draws a goofy rider, so the leading foot plants. For the
                -- airborne part only -- the pose the trick blends in from and out to is mirrored with it for those frames
                -- (v160) THE GAME RIDES THE OTHER STANCE. v153-v159 mirrored the POSE (the anim instance's mirror flag, then a
                -- half turn of the bones on top): the game's own foot targets, worked out for your real stance, dragged the
                -- mirrored feet back -- the trace of 20:51:59 has the pose swinging half round and back inside 0.75 s with
                -- the board still ("a tornado", in every version). "Do whatever they do when the character switches stances,
                -- because that just works": the stance is changed where the GAME reads it (stanceSwap, the body varial's:
                -- the skater definition's Stance) on the first frame in the air, so from the next frame its animation, feet,
                -- lean are all those of a rider of the other stance -- for whom this trick is the plain one; and changed
                -- back on the first frame the wheels are down (or a bail)
                if NC.guardSws and S.NoComplySwitchMirror ~= 0 and S.NoComplyOriginal == 0 and not NC.flip and not NC.flipTried and cm == MODE_AIR then
                    NC.flipTried = true
                    if VS.on then
                        logOnce("ncswapbusy", "no comply: SWITCH -- a stance swap is already on (the body varial's): the trick is left as the game draws it")
                    else
                        local was = NAT.goofy
                        local ok, swWhy
                        local mOff = was and NC.sock and NATIVE.mirrorOff(true)      -- (v189) a goofy rider: the graph's mirror off, his stance and his turn kept
                        if mOff then ok = true else ok, swWhy = stanceSwap(true) end
                        if was and NC.sock and not mOff then NC.sock = false pcall(HJN_Set, "plantstep", math.max(S.NoComplyStepTime, 0.22)) pcall(HJN_Set, "plantmode", 2) logOnce("ncmirrorfail", "no comply: SWITCH (goofy) -- the graph's mirror could not be switched off: the stance swap with the mesh's turn and the pinned feet instead (v182)") end
                        if ok then
                            NC.flip, NC.flipN = true, 0
                            -- (v164) ...and the native half is told WHICH foot plants: the other stance's (the animation's left
                            -- foot: the mesh's right for a goofy pose). It took the first foot down -- your own stance's, in the
                            -- frames before the swap showed -- or, with a hand on the board, none at all
                            pcall(HJN_Set, "plantfoot", was and 0 or 1)
                            -- (v161) ...AND THE MESH TURNED HALF ROUND. The other stance's pose carries a half turn of its own (the
                            -- game draws a goofy rider as the mirrored animation turned 180): v160's traces have the right foot
                            -- planting but each foot at the WRONG END of the board (riding L +26 / R -13, the trick L -18..-32 and
                            -- R from +11) -- "the mesh does a 180 and it's all discombobulated". The mesh component is turned
                            -- 180 with the swap and back with it (a plain write: it lands next frame, as the stance does)
                            -- (v181 / native v97) ...IN THE POSE, NOT IN THE MESH. The mesh's half turn was right on the screen and wrong
                            -- in the REPLAY: the game's replay keeps the mesh's turn and every bone's place in the mesh, pose by pose,
                            -- and plays them back blended between two kept poses -- across a swap that is a mesh turned half round
                            -- against bones turned half round the other way: one replayed frame of a body spun about its own axis
                            -- ("the player body does a full 360 in about a frame right before the trick"; the recording of 5 Oct has
                            -- the drawn body steady through both swaps as played, and the replay run back over the trick right
                            -- after). The native half turns the body half round in the pose, on exactly the poses the game's anim
                            -- instance rides the other stance; the mesh is left alone. NoComplySwitchTurn=0 = the mesh's turn.
                            -- (v182) ...and not in the finished pose either (v181 did: the physics-blended upper body flipped half
                            -- round every frame). You ride regular: the game's own half turn is switched off in its anim graph for
                            -- the trick (NATIVE.graphTurn) -- nothing is turned afterwards. You ride goofy: the mesh's turn, as v161.
                            if mOff then
                                NC.flipYaw = nil
                                VS.graph = { m = true, mOn = true, off = false, sock = true }
                                pcall(HJN_Set, "swapturn", 4)            -- (review) 4 = your home is goofy: with 3 the native half saw "the other stance" on every pose and kept its swap note 30 poses past the landing
                                pcall(HJN_Set, "sockturn", 2)
                            elseif S.NoComplySwitchTurn ~= 0 and (tonumber(NATIVE.v) or 0) >= 98 and not was and NAT.mirror == false and NATIVE.graphTurn(false) then
                                NC.flipYaw = nil
                                VS.graph = { home = false, goofy = false, off = false, sock = NC.sock }
                                pcall(HJN_Set, "swapturn", 3)
                                if NC.sock then pcall(HJN_Set, "sockturn", 2) end   -- (v183) the foot sockets as they stand for your own stance, on the last pose it is ridden: the middle of the stance, for the turn the native half gives them from the next pose on
                            else
                                NC.flipYaw = q(function() return mesh.RelativeRotation.Yaw end, nil)
                                if NC.flipYaw then q(function() mesh.RelativeRotation.Yaw = NC.flipYaw + 180 end) end
                                -- (v188) THE GOOFY RIDER'S SWITCH PLANTS ARE THE REGULAR RIDER'S. "When I'm in regular and I do a no comply,
                                -- that's the exact same as a switch goofy. And switch regular is the exact same as a normal goofy." Since
                                -- v183 only a rider whose own stance is regular got the fixed switch plant (the game's own feet on its
                                -- foot sockets, turned with the body; the regular side's soft plant); a goofy rider still had v182's:
                                -- both foot IK weights zeroed and the feet pinned to their riding spots. The half turn itself cannot
                                -- come out of the anim graph for him (the graph turns with the mirror, and his other stance has the
                                -- mirror OFF), so it stays the mesh's -- but the feet do not care whose turn it is: the sockets are
                                -- kept in the DECK's frame, which a turned mesh does not move. So the same socket rule runs
                                -- (G.mesh = the graph is left alone), and everything gated on NC.sock is his as well.
                                -- (v189) ...which tore (the note at NATIVE.mirrorOff): with the mesh's turn the feet are pinned again, as v182
                            end
                            -- (v183) ...not when the turn is the anim graph's and the feet are the game's: nothing flashes then (the recording
                            -- of 5 Oct 12:05: the game's hips' line goes -143, -130, -126 deg over the swap, no mirrored pose), and the hold
                            -- only froze the body for five poses of the pop and let it catch up 16 deg in the next three
                            if not (VS.graph and VS.graph.sock) then pcall(HJN_Set, "posehold", 4) end   -- (v168) ...and the body held over the swap's frames (one pose, 16 ms in, has it mirrored across the board)
                            if (NC.flipTold or 0) < 6 then NC.flipTold = (NC.flipTold or 0) + 1 log(string.format("no comply: SWITCH -- the game rides you %s from the pop to the landing (you are %s)", was and "REGULAR" or "GOOFY", was and "goofy" or "regular")) end
                        else
                            logOnce("ncswapfail", "no comply: SWITCH -- the game would not take the other stance (" .. tostring(swWhy) .. "): the trick is left as the game draws it")
                        end
                    end
                end
                -- (v153) the trick trace: the feet, the hips and the hand against the drawn deck, pose by pose, in the native log
                if not NC.traced and S.TraceLog ~= 0 and type(HJN_TrickTrace) == "function" then
                    NC.traced = true
                    NC.traces = (NC.traces or 0) + 1
                    if NC.traces <= 16 then
                        pcall(HJN_TrickTrace, 78, string.format("#%d %s%s%s", NC.traces, NC.bone and "BONELESS, a hand on the board" or "no comply, no hand",
                            NC.guardSws and ", switch" or "", NC.flip and ", the other stance" or ""))
                    end
                end
            end
        end
        NC.cmWas = cm
        return
    end
    if S.NoComply == 0 or not NC.applied then NC.cmWas = cm return end
    local name = q(function() return s0:GetCurrentFlipTrickName():ToString() end, "")
    -- (v153) only the two definitions the no comply is wired into: v148-v152 matched the fakie and nollie pressure kickflips
    -- too (the game's real ones), and held their impact bails off and "lifted the planted foot" on 122 frames of them
    local low = (type(name) == "string") and name:lower() or ""
    local match = (low:find("rgs_pressure_kickflip", 1, true) or low:find("sws_pressure_kickflip", 1, true)) ~= nil
    -- (v173) NOT TAKEN AGAIN AT A THROWDOWN. "Sometimes his foot gets stuck below the board when doing like a throwdown -- I
    -- think it was after one of the bonelesses." Off the board this forgot that the name had matched (matchWas = false), and
    -- the game still names the last flip trick while you walk: on the first frame back on the board the old no comply's
    -- name read as a NEW one. The guard opened with no trick -- 18:09:55 / :57 / :59, each a throwdown: 'BAILED 0.43 s',
    -- 'not popped ... the plant foot held on 45 poses, the hips kept down up to 14 cm' -- and the plant took the foot nearest
    -- the ground and lowered the whole body to keep it there: that ankle 4 cm over the deck where it rides 15, for 0.8 s.
    -- Off the board the name is still followed (a name that was there before the mount is not new), nothing is taken in
    -- the first half second on the board, and 'into the air' counts from riding only.
    if cm ~= MODE_RIDING and cm ~= MODE_AIR then NC.matchWas, NC.cmWas, NC.onAt = match, cm, nil return end
    NC.onAt = NC.onAt or now
    if match and now - NC.onAt > 0.5 and (not NC.matchWas or (cm == MODE_AIR and NC.cmWas == MODE_RIDING)) then
        log(string.format("no comply: TAKEN '%s' in mode %d (was %s), the name %s before, %.1f s on the board", name, cm, tostring(NC.cmWas), NC.matchWas and "matched" or "did not match", now - NC.onAt))
        -- (native v94) THE ORIGINAL, TO COMPARE WITH (NoComplyOriginal=1, the ini only): "we had the original animation in the game
        -- ... maybe go back to the original to understand how they did it". No plant window, no ground lift, no other stance
        -- for a switch one: the pose is the game's own for the whole trick (its plant foot is aimed at a place on the REAL
        -- board -- under the ground at first, then hanging at full stretch: the native half's note at g_plPhase). Only the bail
        -- guard stays.
        if S.NoComplyOriginal ~= 0 and (NC.origTold or 0) < 5 then
            NC.origTold = (NC.origTold or 0) + 1
            log("no comply: NoComplyOriginal=1 -- this one is the GAME's own pose from start to end (no planted foot, no ground lift, no other stance); the trick trace still logs it")
        end
        if S.NoComplyNoBail ~= 0 then pcall(HJN_Set, "nobail", 0.3) end
        if S.NoComplyFootFix ~= 0 and S.NoComplyOriginal == 0 then pcall(HJN_Set, "footankle", S.NoComplyFootHeight) pcall(HJN_Set, "footground", 0.3) end
        local st, skips = tostring(hasNoBail and HJN_NoBail() or ""):match("^(%-?%d+) (%d+)")
        local lifts = tostring(type(HJN_FootGround) == "function" and HJN_FootGround() or ""):match("^(%d+)")
        NC.guard, NC.guardAir, NC.guardLand, NC.bone = now, nil, nil, nil
        pcall(HJN_Set, "plantmax", S.NoComplyPlantDrop)                                  -- (v154)
        -- (v181 / native v97) THE SWITCH BONELESS AND BEAN PLANT GET THE REGULAR SIDE'S PLANT. "The switch bean plant and boneless
        -- work, but it's almost like they're holding old code. They don't really mirror what the regular side does." They did
        -- hold older code: the pinned plant of v163 (the game's foot pull is off in the other stance, and the soft plant leaves
        -- from and comes back to the game's own foot). Native v97 gives the soft plant the foot's riding spot on the drawn deck
        -- for that while a swap is on, so with a hand on the board (NoComplySwitchPlant=1) -- or always (=2) -- the switch
        -- trick runs the same plant, with the same step time, as the regular one. The plain switch no comply keeps the pinned
        -- plant at 1: it is the one that was called fine.
        local swOther = low:find("sws_", 1, true) ~= nil and S.NoComplySwitchMirror ~= 0
        -- (v183 / native v99) THE SWITCH PLANTS' FEET ARE THE GAME'S OWN. "Switch no comply is no good. Again, it's pretty scrambled."
        -- With the game's foot IK off in the other stance (v162) nothing carried the feet through the trick but the mod, which
        -- held them on their riding spots: on a board pitched 28 deg in the air, under a body the game had bent over and carried
        -- 25 cm along it (the recording of 5 Oct 12:05:23, at 459 cm/s), the legs came out folded wrong. The regular side has
        -- no such hold: its feet are the game's, on sockets that follow the real board through the clip. The other stance's
        -- sockets are half a turn round from this rider's feet -- so the native half turns them (stanceSwapTick calls it each
        -- pose the other stance is ridden), the IK weights are left alone, and all three switch plants run the regular side's
        -- own plant. NoComplySwitchFeet=0 = v182.
        local swSock = swOther and S.NoComplyPlant < 2 and S.NoComplySwitchFeet ~= 0 and S.NoComplySwitchTurn ~= 0 and (tonumber(NATIVE.v) or 0) >= 99 and (not NAT.goofy or NATIVE.mirrorCan())
        NC.sock = swSock and true or false
        local swSoft = (swSock or (swOther and S.NoComplyPlant < 2 and S.NoComplySwitchTurn ~= 0 and (tonumber(NATIVE.v) or 0) >= 98 and not NAT.goofy
            and (S.NoComplySwitchPlant >= 2 or (S.NoComplySwitchPlant == 1 and NATIVE.gg and NATIVE.gg.kind and S.Boneless ~= 0)))) and true or false
        if swOther and (NC.swSoftTold or 0) < 6 then
            NC.swSoftTold = (NC.swSoftTold or 0) + 1
            log("no comply: SWITCH -- its plant is " .. (swSock and "the regular side's own, on the game's own feet (its foot sockets are turned with the body while the other stance is on; NoComplySwitchFeet=0 = as v182)"
                or swSoft and "the regular side's (the soft plant, on the foot's riding spot while the other stance is on; NoComplySwitchPlant=0 = the pinned one)"
                or "the pinned one (NoComplySwitchPlant=" .. tostring(S.NoComplySwitchPlant) .. ", a hand on the board " .. tostring(NATIVE.gg and NATIVE.gg.kind and true or false) .. ")"))
        end
        pcall(HJN_Set, "plantstep", (swOther and not swSoft) and math.max(S.NoComplyStepTime, 0.22) or S.NoComplyStepTime)
        pcall(HJN_Set, "plantlead", S.NoComplyStepLead)   -- (v156) the step onto the board
        pcall(HJN_Set, "plantclear", S.NoComplyPlantClear)
        pcall(HJN_Set, "plantfwd", S.NoComplyPlantForward)                             -- (v173) the soft plant's foot: down ahead of its riding spot, and kept there
        -- (v163) ...and in a SWITCH trick ridden in the other stance always the pinned one: the game's foot IK is off there, so
        -- nothing but the mod holds the feet to the board (the trace of 21:53: the back foot wandered 39 cm along the deck and
        -- 38 across it) -- the back foot on its riding spot, the plant foot on the ground and then up and over to its own
        pcall(HJN_Set, "plantmode", (S.NoComplyPlant >= 2 or (swOther and not swSoft)) and 2 or 1)
        pcall(HJN_Set, "poselat", S.NoComplySwitchHold or 10)                            -- (native v96) the hips' place across the board over the game's own cross-fade after each stance swap
        pcall(HJN_Set, "plantback", S.NoComplyPlantBack)                                -- (v158) the foot goes down by its place on the board
        NC.guardPlant = tonumber((tostring(type(HJN_Plant) == "function" and HJN_Plant() or "")):match("^(%d+)")) or 0
        -- (v151) the names for THIS trick: a hand already on the board = the boneless (NATIVE.groundGrab runs after this, each frame)
        NC.boneName = nil
        if NATIVE.gg and NATIVE.gg.kind and S.Boneless ~= 0 then NC.bone = true NC.boneName = (NATIVE.gg.kind == 3) and "Bean Plant" or "Boneless" end
        pcall(NATIVE.noComplyNames, NC.bone and (NC.boneName or "Boneless") or "No Comply")
        -- (v186) "The show trick names does not apply to no comply or the grab plants": with the names off the game's own line
        -- for this trick (it would read No Comply / Boneless / Bean Plant) is taken away as it comes up
        if S.TrickNames == 0 then pcall(trickNameHide, NC.bone and (NC.boneName or "Boneless") or "No Comply", 5, true) end
        pcall(HJN_Set, "plantfoot", -1)                                                 -- (v164) the first foot down, unless a switch trick names it
        NC.guardSws, NC.traced, NC.flip = (low:find("sws_", 1, true) ~= nil), nil, nil       -- (v153)
        NC.flipTried, NC.flipN = nil, nil
        NC.guardSkips, NC.guardLifts = tonumber(skips) or 0, tonumber(lifts) or 0
        if cm == MODE_AIR then NC.guardAir = now NC.pops = (NC.pops or 0) + 1 end
        if S.NoComplyNoBail ~= 0 and tonumber(st) ~= 1 and not NC.guardNo then
            NC.guardNo = true
            log("no comply: the game's impact-bail check could not be hooked on this game build -- the planted foot can bail you (see ExpandedTricks.native.log)")
        end
        if (NC.guardTold or 0) < 3 then
            NC.guardTold = (NC.guardTold or 0) + 1
            log(string.format("no comply: the game took it ('%s', mode %d) -- until the wheels are down the planted foot %s and %s", name, cm,
                (S.NoComplyNoBail ~= 0) and "cannot bail you" or "can bail you (NoComplyNoBail=0)", (S.NoComplyFootFix ~= 0) and "is kept on the ground" or "is the animation's (NoComplyFootFix=0)"))
        end
    end
    NC.matchWas, NC.cmWas = match, cm
end
NATIVE.bailWatch = function(cm)
    -- (v191) ...and once BEFORE a trick can be taken: the hand's rule (NATIVE.groundGrab) runs after this, each frame, so a
    -- hand that went on or came off in the frame before the take was to be synced by the call below -- which, the window
    -- just opened, returns. That one trick ran as a Boneless with the no comply's board pop and catch (or the other way round)
    if NATIVE.noComplyPopSync then pcall(NATIVE.noComplyPopSync) end
    if NATIVE.noComplyResult then pcall(NATIVE.noComplyResult, cm, os.clock()) end
    if NATIVE.noComplyPopSync then pcall(NATIVE.noComplyPopSync) end               -- (v156)
    if cm == MODE_BAILING then
        if SB.bailing then return end
        SB.bailing = true
        if NATIVE.tdBail then pcall(NATIVE.tdBail) end                               -- (v144) the trick display: ours off now, then hands off
        if NATIVE.grabAbort then pcall(NATIVE.grabAbort, "the game bailed you") end
        if type(HJN_Set) == "function" then pcall(HJN_Set, "bail", 1) end
        if type(HJN_Guard) == "function" then pcall(HJN_Guard, 0) end
        if type(HJN_Hold) == "function" then pcall(HJN_Hold, 0) end
        if type(HJN_Land) == "function" then pcall(HJN_Land, 0) end
        local pc = alive(SB.pc)
        if pc then pcall(function()
            pc:SimulateInput_LeftStick_X_Axis(0.0)  pc:SimulateInput_LeftStick_Y_Axis(0.0)
            pc:SimulateInput_RightStick_X_Axis(0.0) pc:SimulateInput_RightStick_Y_Axis(0.0)
        end) end
        log("bail: every window closed (grab, guard, hold, landing feet, the native pose) -- the game's ragdoll runs clean")
    elseif SB.bailing and cm ~= MODE_BAILING and cm ~= -1 then
        SB.bailing = false
        if type(HJN_Set) == "function" then pcall(HJN_Set, "bail", 0) end
    end
end

-- (v168) OFF THE BOARD. "When I kickflip and then try to grab and bail, his real legs become invisible and he has fake legs
-- that dangle around, attached to the board." 23:57:47 and 23:58:01: a Tail grab handed to the game mid-flip, then you
-- stepped off (not a ragdoll: no bail was seen) -- the game keeps its grab state at 100 for as long as you walk, the hand
-- IK's weight is up whenever the board is carried, and the native half went on solving the legs onto the carried board
-- (412 poses the first time). On foot, stepping off or bailing the native half is told so (it poses no grab), and a grab
-- state the game left on is put back to none.
NATIVE.offBoardTick = function(cm)
    local off = (cm == 0 or cm == 3 or cm == MODE_BAILING)
    if off ~= NATIVE.offWas then
        NATIVE.offWas = off
        if type(HJN_Set) == "function" then pcall(HJN_Set, "offboard", off and 1 or 0) end
    end
    if not off or not s0 then return end
    local now = os.clock()
    if now - (NATIVE.offGrabAt or -1) < 0.5 then return end
    local g = q(function() return s0:GetGrabState() end, 0)
    if type(g) ~= "number" or g == 0 then return end
    NATIVE.offGrabAt = now
    pcall(function() s0:ServerRPCSetGrab(0) end)
    if NATIVE.grabAbort then pcall(NATIVE.grabAbort, "off the board") end
    NATIVE.offGrabs = (NATIVE.offGrabs or 0) + 1
    if NATIVE.offGrabs <= 20 then
        log(string.format("grab: off the board (mode %s) with the game's grab state still at %s -- put back to none (it had the native half posing the legs onto the carried board)", tostring(cm), tostring(g)))
    end
end

-- (v169) THE GAME'S POWERSLIDE GATE, WATCHED. "Right after a 180 hippie jump or a mini it blocks the power slide input -- maybe
-- other inputs too. I can't do power slides after that." The game's own check (Skate_CanPowerSlide) has a dozen conditions;
-- the native half reads them (HJN_SlideGate). Riding on the ground with BOTH STICKS AT REST the gate should be open: five
-- times a second it is looked at, and whenever what it says has held for 0.75 s and differs from what was last logged, it
-- is logged with the raw fields. The one stuck state that is known -- the trick handler's crouch timer still running, or
-- the skater's crouch / pop-pending flag up, with nothing on the sticks -- is finished after a second (HJN_CrankFix: the
-- game's own ResetCrank).
NATIVE.slideWatch = function(cm, now)
    if type(HJN_SlideGate) ~= "function" or type(HJN_PadSticks) ~= "function" then return end
    local W = NATIVE.sw
    if not W then W = { at = 0, logs = 0 } NATIVE.sw = W end
    if now - W.at < 0.2 then return end
    W.at = now
    if cm ~= MODE_RIDING then W.why, W.since = nil, nil return end
    local lx, ly, rx, ry = tostring(HJN_PadSticks() or ""):match("^(%S+) (%S+) (%S+) (%S+)")
    lx, ly, rx, ry = tonumber(lx), tonumber(ly), tonumber(rx), tonumber(ry)
    -- (v170) BOTH STICKS PUSHED: a powerslide's gesture. The gate was only looked at with the sticks at rest (open, each time);
    -- now the try itself is logged -- the pad, the game's own stick values, the gate, whether the game went into its slide
    if lx and ly and rx and ry and math.sqrt(lx * lx + ly * ly) >= 0.5 and math.sqrt(rx * rx + ry * ry) >= 0.5 then
        W.tryN = (W.tryN or 0) + 1
        if (W.tryN == 2 or W.tryN == 6) and (W.tries or 0) < 60 then
            W.tries = (W.tries or 0) + 1
            local g = tostring(HJN_SlideGate() or "")
            local b = {}
            for v in g:gmatch("%S+") do b[#b + 1] = tonumber(v) end
            log(string.format("powerslide try (both sticks pushed, %.1f s): pad L %.2f,%.2f R %.2f,%.2f | the game %s | foot position %s (was %s), deck yaw offset %s, board mode %s | gate [%s] | the left stick's bank zeroed %d times so far, %.1f s after the last hop",
                W.tryN * 0.2, lx, ly, rx, ry, (b[4] and math.floor(b[4]) & 1 ~= 0) and "IS SLIDING" or "is not sliding",
                tostring(b[14]), tostring(b[15]), tostring(b[16]), tostring(b[17]), g, NATIVE.bankZeros or 0, now - (lastHopEndAt or 0)))
        end
    else
        W.tryN = 0
    end
    if not (lx and ly and rx and ry) or math.max(math.abs(lx), math.abs(ly), math.abs(rx), math.abs(ry)) > 0.15 then W.why, W.since = nil, nil return end
    local g = tostring(HJN_SlideGate() or "")
    local a = {}
    for v in g:gmatch("%S+") do a[#a + 1] = tonumber(v) end
    if #a < 13 then return end
    local f710, f651, f918 = math.floor(a[1]), math.floor(a[2]), math.floor(a[4])
    local r = {}
    if f710 & 2 ~= 0 then r[#r + 1] = "the skater's crouch flag is up" end
    if f710 & 4 ~= 0 then r[#r + 1] = "a pop is pending" end
    if a[3] > 0 then r[#r + 1] = string.format("the skater's timer at +0x8e8 is at %.2f s", a[3]) end
    if f651 & 2 ~= 0 then r[#r + 1] = "the skater's flag at +0x651 bit 1" end
    if a[6] ~= 0 then r[#r + 1] = "the board's byte at +0x684" end
    if a[7] > 0 then r[#r + 1] = string.format("the trick handler's crouch timer is at %.2f s", a[7]) end
    if f918 & 6 ~= 0 then r[#r + 1] = "the skater's flags at +0x918 bits 1-2" end
    if a[5] ~= 0 then r[#r + 1] = "a primo" end
    if a[8] == 0 then r[#r + 1] = string.format("the sticks have not been seen at rest (the game has them at %.4f %.4f %.4f %.4f)", a[9], a[10], a[11], a[12]) end
    if a[13] == 0 then r[#r + 1] = "the controller's option bit is off" end
    local why = (#r > 0) and table.concat(r, "; ") or ""
    if why ~= W.why then W.why, W.since, W.told, W.fixed = why, now, false, false return end
    local held = now - W.since
    if not W.told and held >= 0.75 then
        W.told = true
        if why ~= W.lastTold then
            W.lastTold = why
            W.logs = W.logs + 1
            if W.logs <= 60 then
                log(string.format("powerslide gate (sticks at rest, %.1f s after the last hop): %s  [%s]", now - (lastHopEndAt or 0),
                    (why == "") and "open" or ("SHUT -- " .. why), g))
            end
        end
    end
    if not W.fixed and held >= 1.0 and (a[7] > 0 or f710 & 6 ~= 0) and type(HJN_CrankFix) == "function" then
        W.fixed = true
        local how = tonumber(HJN_CrankFix()) or 0
        log(string.format("powerslide gate: a crouch left half-finished (nothing on the sticks for %.1f s) -- %s", held,
            (how > 0) and "finished with the game's own crank reset (see ExpandedTricks.native.log)" or "the native half could not reset it"))
        W.why, W.since = nil, nil
    end
end

local function idleTick()
    local cm0 = modeNow()
    pcall(NATIVE.bailWatch, cm0)
    pcall(NATIVE.offBoardTick, cm0)                                                  -- (v168)
    pcall(NATIVE.slideWatch, cm0, os.clock())                                        -- (v169)
    if NATIVE.groundGrab then                              -- (v151) the rolling grab / the boneless hand
        local okg, errg = pcall(NATIVE.groundGrab, cm0, os.clock())
        if not okg then logOnce("ggerr", "rolling grab error: " .. tostring(errg)) end
    end
    landAbsorbTick()
    revertSnap.traceTick()
    grabTick(os.clock())
    if NATIVE.dropTick then NATIVE.dropTick(os.clock()) end   -- (v98) the drop-in
    if RV.pending then revertTick(os.clock()) else yawSettleTick() end
    if BV.pending or BY.pending or BR.pending or (os.clock() - lastHopEndAt < 1.0) then
        local now, cm = os.clock(), modeNow()
        bailWatchTick(now, cm)
        bailYawTick(now, cm)
        lateBailTick(now, cm)
        bailReturnTick(now, cm)
    end
end

-- (v133) THE STICK DIRECTIONS FROM THE ANALOG READ, every frame, as the engine's own direction keys would report them. In
-- the game's filmer mode those key events never arrive (v132 read the stick at the click instead, but a stick being
-- clicked loses its deflection for that instant: 30 clicks in a row still saw it "held 125 s ago"). Sampled on the game
-- thread here, the timestamps are fresh wherever the stick has been pushed in the last frames, in every mode
NATIVE.stickSample = function()
    if not NATIVE.analog then return end
    local now = os.clock()
    for _, which in ipairs({ "Left", "Right" }) do
        local x, y = NATIVE.analog(which)
        if y then
            local p = pressedAt[which]
            if y >= 0.5 then p.Up = now elseif y <= -0.5 then p.Down = now end
            if x >= 0.5 then p.Right = now elseif x <= -0.5 then p.Left = now end
        end
    end
end

-- (v166) THE BODY'S YAW, WATCHED. "One or two bails doing the 180 hippie jump caused the player to be permanently
-- disoriented: he faces one direction and runs the other, and on the board his lower half is backwards -- I can't reset it
-- at all. If there is a dismount or a return to a session marker, clear the flags out." Every turn the mod gives the body
-- goes into the mesh's yaw against its capsule, on top of a base that was read afresh at each hop -- so one turn left
-- behind (a hop started over a landing, a bail's hold) became the base, and stayed for good. Now: the base is the yaw the
-- mesh had when it was first seen; and on every frame with nothing of the mod's turning the body (no hop, no landing
-- settle, no bail hold, no switch trick) a mesh more than a degree off it for a quarter second is put back -- on the
-- board, on foot, after a marker, anywhere. A switch no comply's other stance left on with no trick running goes too.
NATIVE.yawGuard = function()
    if not mesh then return end
    -- (v167) NOT IN THE GAME'S REPLAY (mode 6): it plays the mesh's turn back as it was recorded, the mod's hops and all --
    -- the log of 23:25:04-14 has the watch 'putting back' 30 turns in ten seconds of replay, each a jolt in the playback
    if NATIVE.rawMode() == 6 then if NATIVE.yb then NATIVE.yb.offAt = nil end return end
    local y = q(function() return mesh.RelativeRotation.Yaw end, nil)
    local a = addr(mesh)
    if not y or not a then return end
    local Y = NATIVE.yb
    if not Y then Y = {} NATIVE.yb = Y end
    if Y.addr ~= a then                                    -- a mesh not seen before: its yaw as the game made it
        Y.addr, Y.base, Y.offAt = a, y, nil
        yaw0 = y
        log(string.format("body yaw: this skater's mesh stands at %.0f deg to its capsule -- that is its base (it is put back to it whenever nothing of the mod's is turning the body)", y))
        return
    end
    local NC = NATIVE.noComply
    local cm = modeNow()
    local onBoard = (cm == MODE_RIDING or cm == MODE_AIR)
    if NC and NC.flip and (not NC.guard or not onBoard) then
        NATIVE.ncSwapOff()
        log("body yaw: a switch no comply's other stance was still on with no trick running -- put back")
    end
    local swapLive = (NC ~= nil) and (NC.guard ~= nil) and (NC.flip == true)
    if VS.on and S.SwitchLanding ~= 3 and not swapLive then
        stanceSwap(false)
        log("body yaw: a stance swap was still on with nothing running -- your own stance again")
    end
    if active or YS.t0 or BY.pending or RV.pending or BV.pending or swapLive then Y.offAt = nil return end
    yaw0 = Y.base
    local d = wrap180(y - Y.base)
    if math.abs(d) <= 1 then Y.offAt = nil return end
    local now = os.clock()
    Y.offAt = Y.offAt or now
    if now - Y.offAt < 0.25 then return end
    Y.offAt = nil
    local p = q(function() return mesh.RelativeRotation.Pitch end, 0.0)
    local r = q(function() return mesh.RelativeRotation.Roll end, 0.0)
    q(function() mesh.RelativeRotation.Yaw = Y.base end)
    q(function() mesh:K2_SetRelativeRotation({ Pitch = p, Yaw = Y.base, Roll = r }, false, {}, false) end)
    Y.fixes = (Y.fixes or 0) + 1
    if Y.fixes <= 30 then log(string.format("body yaw: the mesh stood %+.0f deg off its base with nothing of the mod's running (mode %s) -- put back", d, tostring(cm))) end
end

local function onFrame(ctx)
    if not isMine(ctx) then return end
    pcall(NATIVE.gtPump)                                                             -- (v185)
    -- (v185) ALLOW GRABS OFF MEANS NO GRABS. GrabStart=0 only stopped the mod STARTING a grab; the game starts its own from
    -- the same bumper (its grabs are on in the save), so the switch did nothing (5 Oct 17:50:41 off, 17:50:51 a Nose Grab).
    -- With it off the game is not shown LB / RB while you are in the air (the native half's bumper mask)
    if S.GrabStart == 0 and type(HJN_Set) == "function" and modeNow() == MODE_AIR then pcall(HJN_Set, "bumpermask", 0.2) end
    pcall(NATIVE.stickSample)
    stanceSwapTick()
    pcall(NATIVE.yawGuard)                                                           -- (v166)
    swapTraceTick()
    trickNameTick(os.clock())
    if not active then idleTick() return end

    local now = os.clock()
    local el  = now - t0
    local gameAir, popped, cm = traceAndDetect(el)

    if cm == MODE_BAILING then abortForBail() return end
    -- -1 = the mode could not be read this frame: not a reason to stop
    if cm ~= MODE_RIDING and cm ~= MODE_AIR and cm ~= MODE_TO_BOARD and cm ~= -1 then abortOffBoard(cm) return end
    stickBlockTick(el)
    -- only while the hold-down is actually being written: before that (the hippie jump's
    -- stand-up) the reading would just pile up a correction nothing applies
    if liftMode == LIFT_COUNTER and nodeTouched[NODE_BOARD] then holdTick() end

    if el < P.pre then
        -- a real pop (releasing the crouch stick can ollie) or leaving the ground before we
        -- take off: let the game's own move happen, untouched
        if popped or cm == MODE_AIR then
            cancelJump(popped and "the game popped a real ollie (crouch stick released fast)"
                                or "the game went airborne")
            return
        end
        if P.dip > 0 then
            applyLift(-P.dip * smooth(el / P.pre))           -- the mini hop's dip
        elseif S.Pose ~= 0 then
            standUp()
        end
        if not stateLogged.stand and el >= P.pre * 0.8 then
            stateLogged.stand = true
            log((P.dip > 0 and "   dipped: " or "   stood: ") .. stateNow())
        end
        lastFrameT = now
        return
    end

    local frac = (el - P.pre) / airT
    if frac >= 1 then endJump(cm == MODE_AIR) return end     -- a wheel bump is not the game's air
    if not tookOff then
        tookOff = true
        H.head0 = heights()
        local x, y = actorXYZ()
        if x then
            local dx, dy = x - start.x, y - start.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 5 then start.dx, start.dy = dx / d, dy / d end
        end
        playSound(S.TakeoffSound)
        if S.BlockCarve ~= 0 then zeroBank() end
    end

    -- the game went airborne under us mid-jump
    if gameAir and not gameAirSeen then
        gameAirSeen = true
        log(string.format("   game airborne at %.0f%% (%s) -- %s", frac * 100, popped and "a real pop" or "drop/bump",
            (popped or liftMode == LIFT_MESH) and "handing back" or "board held at your feet, jump continues"))
    end
    if S.DropSafety ~= 0 and not handedBack then
        if popped then
            handedBack = true                        -- a real ollie: the board pops with you
        elseif liftMode == LIFT_MESH then
            airFrames = gameAir and (airFrames + 1) or 0
            if airFrames >= 2 then handedBack = true end
        end
    end
    -- in the game's air, once it says you are about to land, come down onto the board: its
    -- pre-land board target is built from the (lifted) pelvis, not from the held board bone
    if cm == MODE_AIR and not landingFade and not handedBack and
       q(function() return s0._skateboardingAnimParams.IsAboutToLand end, false) == true then
        landingFade = true
        log(string.format("   the game is about to land you (at %.0f%%) -- bringing the body down to the board", frac * 100))
    end
    if handedBack or landingFade then
        liftScale = liftScale * (handedBack and 0.5 or 0.6)
        if liftScale < 0.05 then endJump(cm == MODE_AIR) return end
    end

    applyLift(heightAt(frac) * liftScale)
    local yaw = varialYaw(frac, now)
    -- (review) a hop that is still straight when its plan would begin lands as in v93 (HopPlanStraight 0): decided once, on the first frame past HopPlan
    -- (v178) ...or, HopPlanStraight 2, planned only where it is needed: "sometimes just hippie jump warps" are the straight hops
    -- riding REGULAR (the hips end the air 100 cm over the ankles' riding level, a leg is 84; riding switch 87-89, and the
    -- game bends the knees for it) and the minis (legs already 78 / 67 in the air)
    if P.plan == nil and frac >= (S.HopPlan or 0) then
        local hs = S.HopPlanStraight or 0
        P.plan = (hs == 1) or (hs >= 2 and (P.kind == "mini" or q(function() return inst.FootPositionType end, 0) == 1))
            or (assistFrom ~= nil) or (math.abs(yawAcc) > 20)
        if (P.planTold or 0) < 1 then P.planTold = 1 log(string.format("   hop: landing %s (foot position %s, %s, %+.0f deg turned at %.0f %% of the air)",
            P.plan and "PLANNED" or "as in v93 (a straight hop the legs reach from)", tostring(q(function() return inst.FootPositionType end, "?")),
            tostring(P.kind), yawAcc, frac * 100)) end
    end
    if NATIVE.live and type(HJN_Air) == "function" then HJN_Air(frac, P.footPull or 0, NATIVE.hopReach(frac), NATIVE.hopFlip(), NATIVE.hopReach01(frac), (P.plan ~= false) and (S.HopPlan or 0) or 0, S.HopLegBend or 0.92, lastDz or 0) if (tonumber(NATIVE.v) or 0) >= 100 then pcall(HJN_Set, "hopturnleft", NATIVE.turnLeft or 0) end end   -- (v94: + where the planned landing begins, the leg at touchdown, the lift on this frame)   -- (v167: + the pull wanted) (v165: + how far through the air: the native half's leg limit is for the way down)   -- (v76: the native half remembers the feet for the landing blend)
    if yaw then setYaw(yaw * liftScale) end
    if math.abs(yawAcc) > 90 and NATIVE.live and S.NativeGuard ~= 0 and type(HJN_Guard) == "function" then
        HJN_Guard(20)
        if not P.airTraced and not P.downTraced and S.TraceLog ~= 0 and type(HJN_Trace) == "function" and (NATIVE.airTraces or 0) < 24 then P.airTraced = true NATIVE.airTraces = (NATIVE.airTraces or 0) + 1 HJN_Trace(40, "air, turned past 90") end
    end
    -- (v166) the legs on the way down, pose by pose, in the native log ("the warp point ... is still there"): the first 14 hops
    -- (v167) ...ALL of it, from the first frame in the air, 180s too (v166 began at 45 % and left the turned ones out: the mini's
    -- snap showed only because a second trace began at 90 deg)
    if not P.downTraced and NATIVE.live and S.TraceLog ~= 0 and type(HJN_Trace) == "function" and (NATIVE.hopTraces or 0) < 24 then
        P.downTraced = true
        NATIVE.hopTraces = (NATIVE.hopTraces or 0) + 1
        HJN_Trace(70, string.format("hop %d, all of it: %s, height %g, air %.2f s, foot pull %g", NATIVE.hopTraces, tostring(P.kind), P.height or 0, airT or 0, P.footPull or 0))
    end
    if S.Pose ~= 0 and not handedBack then airPose(frac) end
    lastFrameT = now
    liftCheck(frac)

    if frac >= 0.5 and not stateLogged.mid then
        stateLogged.mid = true
        log("   apex: " .. stateNow() .. string.format("  [foot position %s, landing foot position %s]", tostring(q(function() return inst.FootPositionType end, "?")), tostring(q(function() return inst.LandingFootPositionType end, "?"))))
    end
end

local function onFramePost(ctx)
    if not isMine(ctx) then return end
    if not active then
        landAbsorbTick()
        if not RV.pending then yawSettleTick() end
        return
    end
    if liftMode == LIFT_COUNTER and lastDz > 0.5 then footIK(NATIVE.hopPull()) end
    local el = os.clock() - t0
    if el < P.pre then
        if P.dip == 0 and S.Pose ~= 0 then standUp() end
        return
    end
    if S.Pose == 0 then return end
    local frac = (el - P.pre) / airT
    if frac < 1 and not handedBack then airPose(frac) end
end

local hooked = false
ensureHook = function()
    if not hooked then
        local ok, err = pcall(function()
            RegisterHook(HOOK, function(ctx) pcall(onFrame, ctx) end,
                               function(ctx) pcall(onFramePost, ctx) end)
        end)
        hooked = ok
        log(ok and "hook registered" or ("hook FAILED: " .. tostring(err)))
    end
    if hooked and not bankHooked then
        bankHooked = true
        local ok, err = pcall(function()
            RegisterHook(BANK_HOOK, function(ctx, ratio)
                if bankGuard then return end
                if not isMine(ctx) then return end
                local r = q(function() return ratio:get() end, 0)
                if type(r) ~= "number" or math.abs(r) <= 1e-4 then return end
                if active then
                    if S.BlockCarve ~= 0 and tookOff then zeroBank() end
                    return
                end
                -- (v142) STICK TURN OFF. In the foot-stick control mode the left stick's sideways push banks the board: the
                -- controller's InGame_Tick sets the skater's target banking ratio from it every tick (the triggers go another
                -- way: Skate_BankLeft/Right -> the board physics' bank input). With StickTurn=0 that ratio is zeroed the moment
                -- it is set, while the left stick is pushed sideways and neither trigger is pulled -- so a trigger turn is left alone
                if S.StickTurn == 0 and NATIVE.rawMode() ~= 6 and type(HJN_PadSticks) == "function" then
                    -- (v170) ...AND THE RIGHT STICK IS AT REST. "The power slide block is still in place." The game's own gate
                    -- (v169's watch) reads OPEN with the sticks at rest after every 180 of 4 Oct 12:53-13:05 -- the block is not
                    -- there. A powerslide is a TWO-stick gesture, and while it slides the game's tick steers it with this same
                    -- banking ratio (InGame_Tick: IsPowerSliding -> the bank input's sign against the slide's -> SetTargetBanking-
                    -- Ratio): with the left stick pushed sideways and no trigger pulled, this zeroed it on every tick of the
                    -- gesture. StickTurn=0 is for the left stick ALONE steering the board; with the right stick off centre too
                    -- it is a trick's gesture and the bank is the game's.
                    local lx, rx, ry, lt, rt = tostring(HJN_PadSticks() or ""):match("^(%S+) %S+ (%S+) (%S+) (%S+) (%S+)")
                    lx, rx, ry, lt, rt = tonumber(lx), tonumber(rx), tonumber(ry), tonumber(lt), tonumber(rt)
                    if lx and math.abs(lx) >= 0.3 and (lt or 0) < 0.2 and (rt or 0) < 0.2
                       and math.max(math.abs(rx or 0), math.abs(ry or 0)) < 0.3 then
                        NATIVE.bankZeros = (NATIVE.bankZeros or 0) + 1
                        zeroBank()
                        if not SB.stickTurnTold then SB.stickTurnTold = true log("stick turn: the left stick's bank zeroed (StickTurn=0) -- the triggers' turn is left alone") end
                    end
                end
            end)
        end)
        log(ok and "carve-block hook registered" or ("carve-block hook FAILED: " .. tostring(err)))
    end
    return hooked
end

-- crouchStick = "Right"/"Left": the stick held in the crouch that started it (eased back to
-- centre for the game by the trick block); nil for the mini hop and the keyboard
NATIVE.rotBack = function()                                -- (v106) the spin mode put back after a jump
    local m = NATIVE.rotRestore
    NATIVE.rotPending = nil                                 -- (v120)
    if m == nil then return end
    NATIVE.rotRestore = nil
    if alive(s0) then pcall(function() s0:SetBodyRotationMode(m) end) log("body rotation mode put back to " .. tostring(m)) end
end
local function hippie(source, requireCrouch, kind, crouchStick)
    kind = kind or "hippie"
    if active then return end
    if kind == "mini" and S.MiniHop == 0 then return end
    if kind == "hippie" and S.HippieJump == 0 then logOnce("hjoff" .. math.floor(os.clock() / 10), "hippie jumps are switched off (HippieJump=0; the menu's Allow hippie jumps)") return end   -- (v136)
    if not refs() then return end
    if requireCrouch and not crouching() then
        log(source .. ": ignored -- not crouched")
        return
    end
    -- only from the ground: the log caught a hippie jump started mid-air after a trick
    -- ("Catch Orient State", game air mode from frame one). Outside our jump nothing
    -- overwrites these anim fields, so they are the game's own verdict.
    local cm = modeNow()
    local gw = q(function() return inst.IsGroundedWheels end, true)
    local tp = q(function() return inst.IsTrickPending end, false)
    local riding = (cm == MODE_RIDING) or (cm == MODE_TO_BOARD and q(function() return mv._isOnBoard end, false) == true)
    if not riding or gw == false or tp == true then
        log(string.format("%s: ignored -- not rolling on the ground (mode=%s wheelsGrounded=%s trickPending=%s)",
            source, tostring(cm), tostring(gw), tostring(tp)))
        return
    end
    meshZ0 = q(function() return mesh.RelativeLocation.Z end, nil)
    if not meshZ0 then return end
    -- the game keeps the mesh yaw we give it, so never read a baseline that still carries our
    -- own offset (a landing twist, a revert or a post-bail restore still in progress)
    if YS.t0 or BY.pending or RV.pending then
        setYaw(0)
        YS.t0, BY.pending, RV.pending = nil, false, false
        revertSnap.release("a new hop")
    else
        -- (v166) the base is the mesh's own, kept from when it was first seen: reading it afresh here made any left-over turn
        -- the new base, for good
        local yb = NATIVE.yb
        yaw0 = (yb and yb.base and yb.addr == addr(mesh)) and yb.base or q(function() return mesh.RelativeRotation.Yaw end, 0)
    end
    myAddr = addr(s0)
    if not ensureHook() then return end

    if kind == "mini" then
        P = { kind = "mini", height = S.MiniHeight, pre = S.MiniCrouchTime, dip = S.MiniCrouch * FULL_CROUCH_CM,
              footPull = S.MiniFootPull, absorb = S.MiniLandAbsorb }
    else
        P = { kind = "hippie", height = S.Height, pre = S.StandTime, dip = 0, footPull = 0, absorb = S.LandAbsorb }
    end
    P.switch = q(function() return inst.IsSkatingSwitch end, false) == true   -- for its name

    gravityUsed = (S.GameGravity ~= 0)
    if gravityUsed then
        local g = gameGravity()
        airT = (g > 1) and (2 * math.sqrt(2 * P.height / g)) or S.AirTime
    else
        airT = S.AirTime * ((kind == "mini") and math.sqrt(P.height / math.max(S.Height, 1)) or 1)
    end
    if airT < 0.15 then airT = 0.15 end

    liftMode = math.floor(S.LiftMethod + 0.5)
    if liftMode == LIFT_BODY and liftBroken[LIFT_BODY] then liftMode = LIFT_COUNTER end
    if liftMode == LIFT_COUNTER and liftBroken[LIFT_COUNTER] then liftMode = LIFT_MESH end
    if P.dip > 0 and liftMode == LIFT_MESH then P.dip = 0 end    -- a mesh dip would sink the feet

    -- varial inputs for this jump
    rotMode  = q(function() return s0:GetBodyRotationMode() end, MANUAL_MODE)
    -- (v106) the game's Pressure / Speed / Time spin modes drive the body round to a full turn on their own, whatever the
    -- trigger does; for the jump's own spin the mode is set to Manual and put back on landing (NATIVE.rotBack)
    -- (v120) ...but NOT at the jump's start: with the game put in Manual while the crouch stick was still being eased back,
    -- it read the stick's return as a trick (a shove-it, "a real pop" at 0.34 s: 6 of 8 jumps tonight against 1 of 34
    -- before v106). The game keeps its own mode until the stick is back (StickRelease + 0.05 s; at once for a mini hop,
    -- which eases no stick), and the mod spins by Manual's rule from the moment the switch is made (varialYaw)
    NATIVE.rotPending = nil
    if S.VarialForceManual ~= 0 and rotMode ~= MANUAL_MODE and rotMode ~= nil then
        NATIVE.rotRestore = rotMode
        local trigHeld = lastTrigAt and (os.clock() - lastTrigAt) < 0.35
        if crouchStick == nil or trigHeld then         -- (v123) a trigger already held: in the game's own modes that makes the pop a spin trick (a shove-it), so Manual now
            if q(function() s0:SetBodyRotationMode(MANUAL_MODE) return true end, false) then
                log("body rotation mode " .. tostring(rotMode) .. " -> Manual (4) for this jump" .. (trigHeld and " (a trigger is held: at once)" or ""))
                rotMode = MANUAL_MODE
            else NATIVE.rotRestore = nil end
        else
            NATIVE.rotPending = true
            log(string.format("body rotation mode %s -> Manual (4) for this jump, once the crouch stick is back (%.2f s)", tostring(rotMode), S.StickRelease + 0.05))
            rotMode = MANUAL_MODE
        end
    end
    local m, why = readAdvanced("BodyRotationRateMultiplier")
    rateMult = (type(m) == "number" and m > 0) and m or 1.0
    yawAcc, lastFrameT, assistFrom, fixedDir = 0, nil, nil, 0
    P.airTraced = false

    stateLogged, tookOff, dbgKey = {}, false, nil
    liftScale, airFrames, handedBack, gameAirSeen, landingFade = 1.0, 0, false, false, false
    lastDz, holdExtra = 0, 0
    LA.t0 = nil
    BR.pending = false                     -- riding again already: an old return is no longer wanted
    SB.pc = alive(q(function() return s0:GetController() end))
    SB.stick = crouchStick
    do                                                   -- (v124) every axis as it was at the click: the block eases them all from here
        local alx, aly, arx, ary
        if NATIVE.analog then alx, aly = NATIVE.analog("Left") arx, ary = NATIVE.analog("Right") end   -- (v126: analogStick is out of scope here)
        SB.v0 = (alx and arx) and { alx, aly, arx, ary } or nil
    end
    bankZeroed = 0
    logGameNumbers()
    BD.maxAir = 0
    findFlipper()
    actorZ0 = actorZ() or 0
    H.head0, H.checked = nil, false
    local _, b0 = heights()
    H.board0 = b0
    local x, y, z = actorXYZ()
    start.x, start.y, start.z = x or 0, y or 0, z or 0
    start.yaw = q(function() return s0:K2_GetActorRotation().Yaw end, 0)
    start.dx, start.dy = 0, 0

    log(string.format("%s: %s  height=%g hang=%.2fs (%s)  lift=%d  rotMode=%s rateMult=%g (%s)  %s  start: %s",
        source, (kind == "mini") and "MINI HOP" or "JUMP", P.height, airT, gravityUsed and "game gravity" or "AirTime",
        liftMode, tostring(rotMode), rateMult, why, stanceNow(), stateNow()))
    t0, active = os.clock(), true
    LoopAsync(math.floor((P.pre + airT) * 1000) + 400, function()     -- safety net
        if active then NATIVE.gt(function() if active then endJump(false) end end) end
        return true
    end)
end

-- both sticks clicked: a mini hop. A hippie jump started by the first of the two clicks is
-- still standing up at this point, so it simply becomes the mini hop.
local function startMini(source)
    if not refs() then return end
    -- a crouch stick still held must be eased back to centre for the game (a snap to centre
    -- could read as an ollie flick): keep the one a converted hippie jump was easing, else guess
    -- from the latest stick directions if the game has you crouched
    local stick = nil
    if active then
        if P.kind == "hippie" and not tookOff and (os.clock() - t0) < MINI_CONVERT then
            log(source .. ": both sticks clicked -- turning the jump into a MINI HOP")
            stick = SB.stick
            active = false if NATIVE.rotBack then NATIVE.rotBack() end
            clearLift()
            setYaw(0)
        else
            return
        end
    elseif crouching() then
        local rd = (pressedAt.Right.Down or 0) - (pressedAt.Right.Up or 0)
        local lu = (pressedAt.Left.Up or 0) - (pressedAt.Left.Down or 0)
        if rd > 0 or lu > 0 then
            stick = ((pressedAt.Right.Down or 0) >= (pressedAt.Left.Up or 0)) and "Right" or "Left"
        end
    end
    local okj, errj = pcall(hippie, source, false, "mini", stick) if not okj then log("mini hop error: " .. tostring(errj)) end   -- (v126) logged
end

------------------------------------------------------------------- controller (via SessionTweaks.log)
do
local tailPos = nil
local lastClickAt = { L3 = -1e9, R3 = -1e9 }

local function sizeOf(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local n = f:seek("end")
    f:close()
    return n
end

-- a stick click on the ground: the mini hop (both sticks) or the hippie jump (crouch + other stick)
local function groundClick(which, now)
    local other = (which == "L3") and "R3" or "L3"
    if S.MiniHop ~= 0 and now - lastClickAt[other] <= MINI_WINDOW then
        startMini("L3+R3")
        return
    end
    -- (v105) WHICH STICK HOLDS THE CROUCH depends on the game's control mode (left stick = left foot, or = front foot)
    -- and on your stance, so the click takes the OTHER stick held EITHER way: pulled down = the ollie crouch (regular /
    -- switch), pushed up = the nollie one (nollie / fakie). The game's own crank flag is the confirmation.
    local stick = PAIR[which].stick
    local function fresh(st)
        local tD, tU = pressedAt[st]["Down"] or 0, pressedAt[st]["Up"] or 0
        local a = math.max(tD, tU)
        return (tU > tD) and "Up" or "Down", a, (a > 0), now - a
    end
    local dir, at, held, age = fresh(stick)
    if not refs() then return end
    -- (v132) the stick-direction key events do not arrive in the game's filmer mode (its focused widget takes them as menu
    -- navigation; the clicks still come, so every click saw a stick "held 30 s ago"): the analog read says where the
    -- stick is NOW, and that is what the crouch is taken from
    if NATIVE.analog then
        local ax, ay = NATIVE.analog(stick)
        if ay and math.abs(ay) >= 0.5 then dir, at, held, age = (ay > 0) and "Up" or "Down", now, true, 0 end
    end
    -- (v135) the crouch may sit on the clicked stick's own side (the filmer mode puts its camera on one stick): a fresh
    -- push of EITHER stick counts, the paired one first
    if age > FRESH then
        local o = (stick == "Right") and "Left" or "Right"
        local d2, a2, h2, g2 = fresh(o)
        if h2 and g2 <= FRESH then stick, dir, at, held, age = o, d2, a2, h2, g2 end
    end
    local crouched = crouching()
    local ok = (S.NeedCrouch == 0) or (held and (crouched or age <= FRESH))
    local function sv(st) if not NATIVE.analog then return "?" end local x, y = NATIVE.analog(st) return x and string.format("%.2f,%.2f", x, y) or "nil" end
    log(string.format("%s click  the %s stick %s | %s, %.2fs ago, crouched=%s -> %s  [sticks L %s R %s; pad %s]",
        which, stick, dir, held and "held" or "not held", age, tostring(crouched),
        ok and "JUMP" or "no", sv("Left"), sv("Right"), (type(HJN_PadSticks) == "function") and tostring(HJN_PadSticks() or "") or "-"))
    if ok then local okj, errj = pcall(hippie, which, false, "hippie", stick) if not okj then log("hippie error: " .. tostring(errj)) end end   -- (v126) logged
end

-- in the air a click is a grab; on the ground it is a hop
local function onClick(which)
    local now = os.clock()
    if NATIVE.dropBusy and NATIVE.dropBusy() then return end      -- (v99) a drop-in is being set up or held
    if now - lastClickAt[which] < 0.15 then return end
    lastClickAt[which] = now
    NATIVE.gt(function()
        local okh, hopped = pcall(function() return NATIVE.hopTry and NATIVE.hopTry(which) end)   -- (v78: on foot by a loose board)
        if okh and hopped then return end
        local ok, took = pcall(grabClick, which)
        if not ok then log("grab click error: " .. tostring(took)) end
        if ok and took then return end
        local ok2, err = pcall(groundClick, which, now)
        if not ok2 then log("click error: " .. tostring(err)) end
    end)
end

-- LB / RB: in the air, the game's own grab (grabKick checks everything else)
local BUMPER = { ["Gamepad_LeftShoulder"] = "LB", ["Gamepad_RightShoulder"] = "RB" }
local function onBumper(which)
    NATIVE.gt(function()
        local ok, err = pcall(grabKick, which)
        if not ok then log("grab start error: " .. tostring(err)) end
    end)
end

-- a key pressed (its engine name: the stick-direction keys, the clicks, the triggers, the bumpers, Y)
local function onKey(key)
    if NATIVE.off then return end
    local stick, dir = key:match("^Gamepad_(%a+)Stick_(%a+)$")
    if stick == "Left" or stick == "Right" then
        pressedAt[stick][dir] = os.clock()
    elseif TRIGGER[key] then
        lastTrig, lastTrigAt = TRIGGER[key], os.clock()
    elseif RIGHT_CLICK[key] then onClick("R3")
    elseif LEFT_CLICK[key] then onClick("L3")
    elseif BUMPER[key] then onBumper(BUMPER[key])
    elseif key == "Gamepad_FaceButton_Top" and NATIVE.dropKey then            -- (v98) Y / triangle: a drop-in?
        NATIVE.gt(function()
            local ok, err = pcall(NATIVE.dropKey)
            if not ok then log("drop-in key error: " .. tostring(err)) end
        end)
    end
end

-- (v122) THE PAD, from the native half when it has the game's key events (HJN_PadOn; no other mod needed), else from
-- SessionTweaks.log as before
local function pollController()
    if NATIVE.pad then
        local q = tostring(HJN_PadEvents() or "")
        if q ~= "" then for key in q:gmatch("[^\n]+") do onKey(key) end end
        return
    end
    local size = sizeOf(TWKLOG)
    if not size then return end
    if tailPos == nil or size < tailPos then tailPos = size return end
    if size == tailPos then return end
    local f = io.open(TWKLOG, "rb")
    if not f then return end
    f:seek("set", tailPos)
    local chunk = f:read(size - tailPos) or ""
    f:close()
    local lastNL = chunk:match(".*()\n")
    if not lastNL then return end
    tailPos = tailPos + lastNL
    for line in chunk:sub(1, lastNL):gmatch("[^\n]+") do
        local key = line:match("%[catch%] key '([^']+)' pressed")
        if key then onKey(key) end
    end
end

LoopAsync(POLL_MS, function() pcall(pollController) return false end)
end   -- controller

------------------------------------------------------------------- the ini
do
local function iniText()
    local out = { "; EXPANDED TRICKS settings -- edit and save while the game is running.\n",
                  "; The mod re-reads this file every second; the NEXT jump uses the new values.\n" }
    for _, sp in ipairs(SPEC) do
        out[#out + 1] = string.format("\n; %s\n%s=%s\n", sp[5], sp[1], tostring(S[sp[1]]))
    end
    return table.concat(out)
end

-- parse: FIRST occurrence of each key wins; count duplicates. Keys may contain digits
-- (an earlier build's [%a_]+ pattern could not see "Sound2D" and appended it every second).
local function parseIni(text)
    local vals, count = {}, {}
    for key, val in ("\n" .. text):gmatch("\n%s*([%w_]+)%s*=%s*([^\r\n;]*)") do
        count[key] = (count[key] or 0) + 1
        if vals[key] == nil then vals[key] = val end
    end
    return vals, count
end

local lastApplied = nil
local function applyVals(vals)
    for _, sp in ipairs(SPEC) do
        local key, kind, lo, hi = sp[1], sp[2], sp[3], sp[4]
        local v = vals[key]
        if v ~= nil then
            if kind == "num" then
                local n = tonumber(v)
                if n then
                    if n < lo then n = lo elseif n > hi then n = hi end
                    S[key] = n
                end
            else
                local sv = (v:gsub("^%s+", ""):gsub("%s+$", ""))
                if sv ~= "" then S[key] = sv end
            end
        end
    end
    local parts = {}
    for _, sp in ipairs(SPEC) do
        if sp[2] == "num" then parts[#parts + 1] = sp[1] .. "=" .. tostring(S[sp[1]]) end
    end
    local summary = table.concat(parts, " ")
    if summary ~= lastApplied then                     -- only log real changes
        lastApplied = summary
        log("settings: " .. summary)
        soundCache = {}
    end
end

local lastIni = nil
NATIVE.iniText = iniText                               -- (v97) for the numpad block (these are this block's locals)
NATIVE.iniNote = function(t) lastIni = t end
-- (v102) WHAT YOU TWEAK: every setting you change -- the ini, re-read as you save it, or a numpad nudge -- is logged and
-- appended to ExpandedTricks.tweaks.log (next to the ini). The values people reach for are the ones a settings screen should carry.
NATIVE.tweak = function(key, old, new, how)
    log(string.format("tweak: %s %s -> %s (%s)", key, tostring(old), tostring(new), how))
    if key:sub(1, 8) == "NoComply" and NATIVE.noComply then NATIVE.noComply.done = false end   -- (v137) applied again
    if (key == "SpeedScale" or key == "PushScale") and NATIVE.speed then NATIVE.speed.applied = nil end   -- (v147/v149) applied again
    if NATIVE.tweakVals then NATIVE.tweakVals[key] = new end
    local f = io.open("ExpandedTricks.tweaks.log", "a")
    if f then f:write(string.format("%s %s %s -> %s (%s)\n", os.date("%Y-%m-%d %H:%M:%S"), key, tostring(old), tostring(new), how)) f:close() end
end
NATIVE.tweakScan = function(how)
    local was = NATIVE.tweakVals
    if was then
        for _, sp in ipairs(SPEC) do
            local k = sp[1]
            if was[k] ~= nil and S[k] ~= nil and tostring(was[k]) ~= tostring(S[k]) then NATIVE.tweak(k, was[k], S[k], how) end
        end
    end
    local now = {}
    for _, sp in ipairs(SPEC) do now[sp[1]] = S[sp[1]] end
    NATIVE.tweakVals = now
end
-- (v105) THE IN-GAME SETTINGS PAGES: "Expanded Trick Settings" in the game's own pause menu, through the native half --
-- which for now rides SessionOpenMP's pause-menu seam (its main.dll fills the game's native menu with rows a guest
-- declares; SessionTweaks' pages come the same way). Without that host the rows are never shown and the ini stays the
-- way to set things; a host of our own is the next step, and these rows stay as they are.
-- A row: { kind, ini key, label, scale, step, description }. The game prints a slider as a WHOLE number, so `scale`
-- is how many row units make one ini unit: seconds go up as milliseconds (1000), factors as percent (100).
-- The row's range comes from the ini's own limits (SPEC). A "page" row opens another page by its title.
NATIVE.MENU = {
    -- (v184) THE RELEASE'S TEXT PASS: every row once, on its own page, with a description that says what the setting does and
    -- in what unit; the Quick page is put together from these rows by key (NATIVE.MENU_QUICK below), so a setting has one
    -- text. `unit` is what the menu prints the default with (menuSend adds "Default: 95 cm." to every description).
    { "General gameplay settings", {
        { "slider", "SpeedScale", "Max speed", 100, 10, "How fast pushing can take you, as a percentage (%) of the game's own top speed. 100 = unchanged, 150 = half again as fast. Hills can still carry you faster. Each push is as strong as before (see Push strength).", 0.5, 3, unit = "%" },
        { "slider", "PushScale", "Push strength", 100, 10, "How hard each push accelerates you, as a percentage (%) of the game's own push. 100 = unchanged. Raise it to get up to speed in fewer pushes.", 0.5, 3, unit = "%" },
        { "toggle", "StickTurn", "Left stick steers the board", 1, 1, "On: the game's own steering, where pushing the left stick sideways leans and turns the board. Off: only the triggers turn you, so doing a stick trick no longer pulls the board off its line." },
        { "toggle", "TrickNames", "Show trick names", 1, 1, "Shows this mod's tricks in the game's trick display when you land them, for example 180 Hippie Jump, Crail Grab, No Comply, Boneless or Bean Plant. Off: none of them are shown." },
        { "slider", "AutoUpdate", "Automatic updates", 1, 1, "0 = off. 1 = tells you, in the log and on the trick display, when a new version of the mod is out. 2 = also downloads it from the mod's GitHub page, checks it and installs it for the next time you start the game.", 0, 2 },
    } },
    { "Hippie Jumps", {
        { "toggle", "HippieJump", "Allow hippie jumps", 1, 1, "Jump straight up off the board while it rolls on under you, then land back on it. Hold one stick down to crouch, then click the other stick (L3 or R3) to jump." },
        { "toggle", "MiniHop", "Allow mini hippie jumps", 1, 1, "A small, quick hop off the board: click both sticks (L3 + R3) at the same time. No crouch is needed. Its height is set by Mini hippie jump height." },
        { "slider", "Height", "Hippie jump height", 1, 5, "How high your body rises off the board in a hippie jump, in centimetres (cm). 60 = a low jump, 95 = a medium one, 150 = a big one.", 30, 220, unit = "cm" },
        { "slider", "MiniHeight", "Mini hippie jump height", 1, 5, "How high your body rises off the board in a mini hippie jump, in centimetres (cm).", 20, 120, unit = "cm" },
        { "toggle", "Varial", "Allow rotation in hippie jumps", 1, 1, "Hold a trigger (LT or RT) while you are in the air to spin your body above the board. A half turn is a 180 and lands you switch, a full turn is a 360." },
        { "toggle", "VarialBail", "Bail on a bad rotation", 1, 1, "On: landing too far from a clean half or full turn makes you bail, as it would on a real board. Off: your body is turned the rest of the way for you and you ride away." },
        { "toggle", "VarialInvert", "Swap the rotation triggers", 1, 1, "Swaps which trigger spins you which way. Turn it on if LT and RT rotate you the opposite way to what feels natural." },
        { "toggle", "BoardHop", "Allow jumping onto the board", 1, 1, "On foot next to your board lying on the ground (after a bail, for example), click a stick (L3 or R3) to jump onto it and ride away the way you are facing." },
    } },
    { "Drop-ins", {
        { "toggle", "DropIn", "Allow drop-ins", 1, 1, "On foot at the edge of a ledge, bank or ramp, press Y (Triangle) to set up with the tail on the edge. Then push a stick up to drop in, press LB or RB to go back onto the ledge, or Y to step off." },
        { "slider", "DropInSpeed", "Drop-in launch speed", 0.036, 1, "How fast the board is launched when you drop in, in km/h: down a ramp, or straight out over a plain ledge. 10 km/h is about 6 mph.", 0, 2000, unit = "km/h" },
        { "slider", "DropInPitch", "Drop-in deck angle", 1, 5, "How steeply the deck points up from the tail while you wait on the edge, in degrees. It is raised by itself when a coping is in the way.", 0, 45, unit = "degrees" },
        { "slider", "DropInRange", "Drop-in edge distance", 1, 10, "How close to the edge you have to stand to set up a drop-in, in centimetres (cm) from the middle of your body. Higher = you can set up from further back.", 20, 200, unit = "cm" },
        { "slider", "DropInFace", "Drop-in facing limit", 1, 15, "How far off straight toward the drop you may face and still set up, in degrees to either side. 30 = up to 30 degrees left or right. 0 = no limit, any direction works.", 0, 180, unit = "degrees" },
        { "slider", "DropInVertSpeed", "Vert wall: launch speed", 0.036, 1, "On a ramp that goes vertical at the top: how fast the board is let go, in km/h. Lower lets the wheels meet the wall sooner; the wall itself gives you speed.", 0, 2000, unit = "km/h" },
        { "slider", "DropInVertBoost", "Vert wall: speed boost", 0.036, 1, "On a vert wall: extra speed added down the wall once the wheels are riding it, about 0.3 seconds after the board is let go, in km/h.", 0, 2000, unit = "km/h" },
        { "slider", "DropInVertTilt", "Vert wall: nose-down tilt", 1, 5, "On a vert wall: how far the board is tipped nose-down before it is let go, in degrees. It has to be steep so the wheels meet the wall instead of flying out over it.", 20, 89, unit = "degrees" },
        { "slider", "DropInVertBack", "Vert wall: push toward the wall", 0.036, 1, "On a vert wall: how fast the board is pushed back toward the wall as it is let go, in km/h. It helps the wheels catch a wall that hangs back under the coping.", 0, 400, unit = "km/h" },
    } },
    { "Grabs", {
        { "toggle", "GrabStart", "Allow grabs", 1, 1, "Hold LB or RB in the air to grab, let go to release. LB = front hand, picked with the left stick (Nose, Mute, Melon...). RB = back hand, picked with the right stick (Tail, Indy, Crail...)." },
        { "toggle", "DoubleGrabs", "Allow two-hand grabs", 1, 1, "Hold LB and RB together in the air for a two-hand grab. The two grabs your sticks point at make the pair: Cannonball, Gorilla Grab or Quasimodo." },
        { "toggle", "GrabTweakInvert", "Invert grab tweak direction", 1, 1, "Reverses the grab tweak: turning the stick clockwise twists your legs and board counter-clockwise. Applies to every grab. Needs Tweak only when the stick moves." },
        { "toggle", "GrabTweakGate", "Tweak only when the stick moves", 1, 1, "On: a grab starts untweaked, and your legs and board twist only once you move the stick away from where it picked the grab. Off: the game's own behaviour, where the tweak can come in straight away." },
        { "toggle", "GrabKeepFirst", "Lock the grab until release", 1, 1, "On: the grab you took stays until you let go of the bumper, and moving the stick only tweaks it. Off: moving the stick just after grabbing can switch you to a different grab." },
        { "toggle", "GrabLetGo", "Let go on landing", 1, 1, "On: a grab you hold into the landing simply ends as the wheels touch down. Off: still holding the board when the wheels touch down makes you bail, so you have to let go in time." },
        { "toggle", "GrabBlockFlips", "Block late flips while grabbing", 1, 1, "On: stick movements do not start a late flip while a bumper is held or a grab is on, so picking or tweaking a grab cannot flip the board by accident. Late flips work again 0.2 seconds after you let go." },
        { "slider", "GrabAllAlong", "All grabs: hand along the board", 1, 1, "Moves the grabbing hand along the board for every grab at once, on top of each grab's own setting, in centimetres (cm). + = toward the nose, - = toward the tail. 0 = no change.", -20, 20, unit = "cm" },
        { "slider", "GrabAllAcross", "All grabs: hand across the board", 1, 1, "Moves the grabbing hand across the board for every grab at once, on top of each grab's own setting, in centimetres (cm). + = toward your toes, - = toward your heels. 0 = no change.", -20, 20, unit = "cm" },
        { "slider", "GrabAllUp", "All grabs: hand up or down", 1, 1, "Moves the grabbing hand up or down for every grab at once, on top of each grab's own setting, in centimetres (cm). + = up off the deck, - = down into it. 0 = no change.", -20, 20, unit = "cm" },
    } },
    { "No Comply and Boneless", {
        { "toggle", "NoComply", "Allow no complies", 1, 1, "Adds the no comply: your front foot steps off and plants on the ground as the board pops. It takes the place of the pressure kickflip and uses its input (riding regular: left stick down + right stick left)." },
        { "toggle", "Boneless", "Allow boneless and bean plant", 1, 1, "A hand on the board through a no comply. Hold RB (back hand) for a Boneless or LB (front hand) for a Bean Plant while rolling, then do the no comply. The hand lets go by itself as the board comes back under your feet." },
        { "toggle", "NoComplyPlant", "Plant foot reaches the ground", 1, 1, "On: your body is let down during the pop so the planted foot really stands on the ground until the board is at its highest. Off: the animation as the game plays it, with that foot hanging in the air." },
        { "slider", "NoComplyExtraPop", "No comply pop height", 1, 2, "How high a no comply pops, in centimetres (cm) added to the game's own pop. -46 lifts you about 50 cm, +9 about 105 cm.", -90, 45, unit = "cm" },
        { "slider", "BonelessExtraPop", "Boneless pop height", 1, 2, "Pop height for the Boneless and Bean Plant, in centimetres (cm) added to the game's own pop. Lower = a smaller pop. Used in place of No comply pop height while a hand is on the board.", -90, 45, unit = "cm" },
        { "slider", "NoComplyPopHeightMax", "No comply board height", 1, 1, "How much extra height the board itself gets at the pop, at most, in centimetres (cm). Higher = the board comes up further under you.", -45, 60, unit = "cm" },
        { "slider", "NoComplyPopForwardMax", "No comply forward push", 1, 1, "How far the board is pushed forward at the pop, at most, in centimetres (cm). Negative values push it backward.", -40, 40, unit = "cm" },
        { "slider", "NoComplyStartPitchMax", "No comply scoop angle", 1, 5, "How far the nose of the board is tipped up as it is scooped off the ground, at most, in degrees. Higher = the board stands up steeper at the pop.", -90, 90, unit = "degrees" },
    } },
    { "Rolling Grabs and Finger Flips", {
        { "toggle", "GroundGrabs", "Allow grabs while rolling", 1, 1, "Riding on the ground, hold RB to put your back hand on the toe edge between your feet (Indy), or LB for the front hand (Mute). The hand stays on while the bumper is held: through an ollie, a drop or a no comply." },
        { "slider", "GroundGrabHips", "Rolling grab: hip height", 1, 2, "How low you squat to reach the board: the height of your hips above the board, in centimetres (cm). Lower = a deeper squat and a straighter back. 46 matches the game's own Indy grab.", 25, 80, unit = "cm" },
        { "slider", "GroundGrabBack", "Rolling grab: hips back", 1, 2, "How far back from the grabbed edge your hips sit in the full squat, in centimetres (cm). Higher = shins more upright and knees nearer a right angle, with the back leaning further forward to reach.", 0, 35, unit = "cm" },
        { "slider", "GroundGrabLean", "Rolling grab: max back bend", 1, 5, "The most your back may bend toward the board, in degrees. It bends only as far as the arm needs to reach, and the bend is spread along the whole spine.", 0, 85, unit = "degrees" },
        { "slider", "GroundGrabFrontAlong", "Rolling grab: front hand position", 1, 1, "Moves the front hand (LB) along the board from its usual spot, in centimetres (cm). + = toward your front foot, - = toward your back foot.", -30, 30, unit = "cm" },
        { "slider", "GroundGrabBackAlong", "Rolling grab: back hand position", 1, 1, "Moves the back hand (RB) along the board from its usual spot, in centimetres (cm). + = toward your front foot, - = toward your back foot.", -30, 30, unit = "cm" },
        { "slider", "GroundGrabBlockFlips", "Rolling grab: flips allowed", 1, 1, "Which flip tricks can be flicked while a hand is on the board. 0 = all flips, 1 = pressure flips only (they make the best finger flips), 2 = no flips. The no comply and the ollie always work.", 0, 2 },
        { "toggle", "GroundGrabFingerFlip", "Allow finger flips", 1, 1, "On: flick a flip trick with a hand on the board and the hand lets go as the board leaves the ground, so it looks like the hand flips it. Off: the hand stays on the flipping board while the bumper is held." },
        { "slider", "FingerFlipHold", "Finger flip: release delay", 1000, 10, "How long the hand stays on the board after it has left the ground in a finger flip, in milliseconds (ms). 1000 ms = 1 second. Higher = the hand follows the turning board for longer.", 0, 0.5, unit = "ms" },
    } },
    { "Expanded Tricks", {
        { "page", "General gameplay settings", "General gameplay settings", 1, 0, "Top speed, push strength, left-stick steering and on-screen trick names." },
        { "page", "Quick", "Quick settings", 1, 0, "The most used switches and sliders from all the pages, in one place." },
        { "page", "Hippie Jumps", "Hippie Jumps", 1, 0, "The hippie jump and the mini hippie jump: their heights, spinning in the air, and jumping back onto your board." },
        { "page", "Drop-ins", "Drop-ins", 1, 0, "Setting up on the edge of a ledge, bank or ramp and dropping in, including vert walls." },
        { "page", "Grabs", "Grabs", 1, 0, "Grabs in the air with the bumpers: two-hand grabs, tweaking, letting go and where the hand goes." },
        { "page", "Rolling Grabs and Finger Flips", "Rolling Grabs and Finger Flips", 1, 0, "Grabbing the board while you roll, the squat that takes, and flipping the board out of your hand." },
        { "page", "No Comply and Boneless", "No Comply and Boneless", 1, 0, "The no comply, the boneless and the bean plant: the planted foot, the pop and the scoop." },
    } },
}
-- (v140) QUICK: the main switches -- what SessionOpenMP's one flat page (14 rows, pages in order, each key once) shows when
-- the mod's own nested pages cannot be placed, so it stays the FIRST page. (v184) Its rows are the other pages' own
NATIVE.MENU_QUICK = { "HippieJump", "MiniHop", "Varial", "SpeedScale", "Height", "BoardHop", "DropIn", "DropInSpeed", "GrabStart", "DoubleGrabs", "GrabTweakInvert", "NoComply", "StickTurn" }
NATIVE.menuQuick = function()
    local by, rows = {}, {}
    for _, pg in ipairs(NATIVE.MENU) do
        for _, r in ipairs(pg[2]) do if r[1] ~= "page" and not by[r[2]] then by[r[2]] = r end end
    end
    for _, k in ipairs(NATIVE.MENU_QUICK) do if by[k] then rows[#rows + 1] = by[k] end end
    table.insert(NATIVE.MENU, 1, { "Quick", rows })
end
NATIVE.menuQuick()
NATIVE.menuRow = {}
                                    -- ini key -> its row (for the units and limits)
NATIVE.menuSend = function()
    if type(HJN_MenuPage) ~= "function" then return end
    local by = {}
    for _, sp in ipairs(SPEC) do by[sp[1]] = sp end
    -- (v123) SessionOpenMP's dll stays loaded when mods.txt disables it, and its menu is never shown: our page went into a
    -- menu nobody sees. So mods.txt decides -- disabled there (or MenuOwnPages=1) means the mod's own pages
    if type(HJN_Set) == "function" then
        local own = S.MenuOwnPages ~= 0
        local mf = io.open("Mods\\mods.txt", "r")
        if mf then
            local txt = mf:read("*a") or "" mf:close()
            local v = txt:match("\n%s*SessionOpenMP%s*:%s*(%d)") or txt:match("^%s*SessionOpenMP%s*:%s*(%d)")
            if v == "0" then own = true end
        end
        HJN_Set("menuown", own and 1 or 0)
    end
    HJN_MenuPage("")                                   -- (a reload starts over)
    local pages, rows = 0, 0
    for _, pg in ipairs(NATIVE.MENU) do
        if (tonumber(HJN_MenuPage(pg[1])) or 0) > 0 then
            pages = pages + 1
            for _, r in ipairs(pg[2]) do
                local kind, key, label, scale, step, desc = r[1], r[2], r[3], r[4], r[5], r[6]
                local sp = by[key]
                if kind == "page" then
                    if (tonumber(HJN_MenuRow(3, key, label, desc, 0, 0, 0, "", "")) or 0) > 0 then rows = rows + 1 end   -- (review: it returns the page's running count)
                elseif not sp or sp[2] ~= "num" then
                    log("menu: no ini setting called " .. tostring(key) .. " -- row skipped")
                else
                    local lo, hi = r[7] or sp[3], r[8] or sp[4]      -- (v106) a row may narrow the ini's own range
                    NATIVE.menuRow[key] = { scale = scale, lo = lo, hi = hi, kind = kind }
                    local d = NATIVE.DEF and NATIVE.DEF[key]            -- (v184) ...and ends with the setting's default, in the row's own unit
                    if type(d) == "number" then
                        if kind == "toggle" then desc = desc .. " Default: " .. ((d ~= 0) and "On" or "Off") .. "."
                        else desc = desc .. " Default: " .. string.format("%.0f", d * scale) .. ((r.unit and r.unit ~= "") and (" " .. r.unit) or "") .. "." end
                    end
                    if (tonumber(HJN_MenuRow(kind == "toggle" and 1 or 2, key, label, desc, lo * scale, hi * scale, step, "Off", "On")) or 0) > 0 then rows = rows + 1 end
                end
            end
        end
    end
    log(string.format("menu: %d pages, %d rows described to the native half (shown once a pause-menu host is found)", pages, rows))
end
NATIVE.menuPush = function()                           -- what every row shows now
    if type(HJN_MenuValue) ~= "function" then return end
    for key, r in pairs(NATIVE.menuRow) do HJN_MenuValue(key, math.floor((tonumber(S[key]) or 0) * r.scale + 0.5)) end   -- (v186) a whole number, as the row shows it
end
NATIVE.menuDrain = function()                          -- what the player changed in the menu -> the ini
    if type(HJN_MenuTake) ~= "function" then return end
    local q = tostring(HJN_MenuTake() or "")
    if q == "" then return end
    local changed = false
    for key, v in q:gmatch("([%w_]+)=([%-%d%.e]+);") do
        local r, n = NATIVE.menuRow[key], tonumber(v)
        if r and n then
            n = math.floor(n + 0.5) / r.scale                    -- (v186) the row's whole number (km/h rows: 29 = 805.6 cm/s)
            if n < r.lo then n = r.lo elseif n > r.hi then n = r.hi end
            if r.kind == "toggle" then n = (n >= 0.5) and 1 or 0 end
            if tostring(S[key]) ~= tostring(n) then
                NATIVE.tweak(key, S[key], n, "menu")
                S[key] = n
                changed = true
            end
        end
    end
    if changed then
        local w = io.open(INI, "w")
        if w then local t = iniText() w:write(t) w:close() NATIVE.iniNote(t)
        else logOnce("iniro", "settings: " .. INI .. " could not be written -- what you change in the menu lasts only until you quit") end
        NATIVE.menuPush()
    end
end
NATIVE.menuTick = function()                           -- once a second, from the ini poll
    if type(HJN_MenuRegister) ~= "function" then return end
    if not NATIVE.menuSent then NATIVE.menuSent = true pcall(NATIVE.menuSend) pcall(NATIVE.menuPush) end
    if NATIVE.menuReg ~= 1 and NATIVE.menuReg ~= -1 and NATIVE.menuReg ~= 2 then      -- (v148: 2 is final too -- it was asked, and logged, every second)
        NATIVE.menuReg = tonumber(HJN_MenuRegister()) or 0
        if NATIVE.menuReg == 1 then log("menu: Expanded Tricks is in the pause menu (one flat page through SessionOpenMP's menu)")
        elseif NATIVE.menuReg == 2 then log("menu: Expanded Tricks is in the pause menu (the mod's own nested pages; ExpandedTricks.native.log says how they were placed)") end
    end
    pcall(NATIVE.menuDrain)
end

local function pollIni()
    -- (v156) the pause-menu pages first: what was changed there is written to the ini BEFORE the file is read. (It was read
    -- first: the text in hand was then the old one, and the menu's change was undone for a second and re-applied --
    -- 19:20:07 'NoComplyExtraPop -42 -> -46 (ini)', and the no comply wired three times over)
    if not NATIVE.off then pcall(NATIVE.menuTick) end
    local f = io.open(INI, "r")
    local text = f and (f:read("*a") or "") or nil
    if f then f:close() end

    if not text then
        local w = io.open(INI, "w")
        if w then w:write(iniText()) w:close() end
        return
    end
    if text == lastIni or active then return end
    lastIni = text

    local vals, count = parseIni(text)
    applyVals(vals)
    NATIVE.tweakScan("ini")
    pcall(NATIVE.menuPush)                             -- (v105) the rows show the ini's values
    if next(count) == nil then return end              -- (review) an editor caught mid-save: nothing parsed is not "every key missing"

    -- normalize: rewrite the whole file if anything is missing, duplicated or retired
    local known, missing, dupes, retired = {}, 0, 0, 0
    for _, sp in ipairs(SPEC) do
        known[sp[1]] = true
        local c = count[sp[1]] or 0
        if c == 0 then missing = missing + 1 elseif c > 1 then dupes = dupes + (c - 1) end
    end
    for k in pairs(count) do if not known[k] then retired = retired + 1 end end
    if missing > 0 or dupes > 0 or retired > 0 then
        local w = io.open(INI, "w")
        if w then
            local t = iniText()
            w:write(t) w:close()
            lastIni = t
            log(string.format("settings: rewrote %s cleanly (%d added, %d duplicate lines removed, %d retired; your values kept)",
                INI, missing, dupes, retired))
        end
    end
end

------------------------------------------------------------------- start
-- keep the log from growing forever: rotate at launch past 1 MB
do
    local f = io.open(LOG, "rb")
    if f then
        local n = f:seek("end")
        f:close()
        if n and n > 1024 * 1024 then
            os.remove(LOG .. ".old")
            os.rename(LOG, LOG .. ".old")
        end
    end
end

-- (v106) THE SETTINGS FILE'S NEW NAME: an old HippieJump.ini is carried over once, values and all
do
    local n = io.open(INI, "r")
    if n then n:close() else
        local o = io.open("HippieJump.ini", "r")
        if o then
            local body = o:read("*a") o:close()
            local w = io.open(INI, "w")
            if w then w:write(body) w:close() log("settings: HippieJump.ini carried over to " .. INI .. " (the old file is left as it is)") end
        end
    end
end
pcall(pollIni)
LoopAsync(1000, function() pcall(pollIni) return false end)
end   -- the ini

-- F7: READ-ONLY survey of the ridden board's parts, for the switch landing (a half-turn
-- body varial needs the board's heading turned 180 under you, so we need to know which of
-- its parts the physics actually moves). Nothing is written.
local function boardProbe()
    if not refs() then log("F7 board probe: skater not found") return end
    local function yawOf(r) return r and q(function() return r.Yaw end, 0) or 0 end
    local function v3(v)
        if not v then return "?" end
        return string.format("(%.0f,%.0f,%.0f)", q(function() return v.X end, 0), q(function() return v.Y end, 0),
            q(function() return v.Z end, 0))
    end
    log("F7 board probe: " .. stanceNow() .. "  mode=" .. tostring(modeNow())
        .. "  skater yaw " .. string.format("%.1f", yawOf(q(function() return s0:K2_GetActorRotation() end)))
        .. "  reverting=" .. tostring(q(function() return s0:IsReverting() end, "?")))
    -- your ridden board is the PBP_SkateboardEx_C actor named exactly "Skateboard" (co-op peers'
    -- boards carry numbered names). GetSkateboardMesh came back empty in v58.
    logOnce("probe1", "   TRY FindAllOf PBP_SkateboardEx_C (first time)")
    local owner = nil
    local all = q(function() return FindAllOf("PBP_SkateboardEx_C") end)
    if type(all) == "table" then
        for _, b in ipairs(all) do
            local nm = q(function() return b:GetFName():ToString() end, "")
            if nm == "Skateboard" then owner = alive(b) break end
        end
        log(string.format("   %d board actor(s) found", #all))
    end
    if not owner then log("   your board actor ('Skateboard') not found") return end
    log("   board actor " .. q(function() return owner:GetFullName() end, "?")
        .. " yaw " .. string.format("%.1f", yawOf(q(function() return owner:K2_GetActorRotation() end))))
    local pcls = alive(q(function() return StaticFindObject("/Script/Engine.PrimitiveComponent") end))
    if not pcls then log("   PrimitiveComponent class not found") return end
    logOnce("probe2", "   TRY K2_GetComponentsByClass (first time)")
    local list = q(function() return owner:K2_GetComponentsByClass(pcls) end)
    local n = list and (q(function() return #list end, nil) or q(function() return list:GetArrayNum() end, 0)) or 0
    for i = 1, n do
        local c = alive(q(function() return list[i]:get() end))
        if c then
            local name = q(function() return c:GetFName():ToString() end, "?")
            local cls  = q(function() return c:GetClass():GetFName():ToString() end, "?")
            local yaw  = yawOf(q(function() return c:K2_GetComponentRotation() end))
            local vel  = q(function() return c:GetComponentVelocity() end)
            local loc  = q(function() return c:K2_GetComponentLocation() end)
            log(string.format("   [%d] %s (%s) yaw=%.1f vel=%s loc=%s", i, name, cls, yaw, v3(vel), v3(loc)))
        end
    end
    log("   (" .. n .. " primitive components)")
end

RegisterKeyBind(Key.F7, function() if (S.DevKeys or 0) == 0 or NATIVE.off then return end NATIVE.gt(function()
    local ok, err = pcall(boardProbe)
    if not ok then log("F7 board probe error: " .. tostring(err)) end
end) end)
RegisterKeyBind(Key.F11, function() if (S.DevKeys or 0) == 0 or NATIVE.off then return end NATIVE.gt(function() pcall(startMini, "F11") end) end)

-- (v86) LIVE HAND TUNING: the numpad nudges the hand offset of the grab you did last (or are holding), 1 cm a press,
-- the native half takes it at once and the ini keeps it -- tuned by eye once, locked in
do
    local HAND_OF = {}                                   -- (v96) all 12 grabs
    for _, g in ipairs(NATIVE.GRABS) do HAND_OF[g[2]] = g[1] end
    local function saveIni()
        local w = io.open(INI, "w")
        if not w then return false end
        local t = NATIVE.iniText()
        w:write(t) w:close()
        NATIVE.iniNote(t)
        return true
    end
    local what = "Hand"                                  -- (v95) "Hand" = the grab spot, "Via" = the hand path's via point
    local back = false                                   -- (v97) two-hand grabs: the numpad's hand (1 swaps front / back)
    local function nudge(axis, delta)
        if axis == "Toggle" then
            what = (what == "Hand") and "Via" or "Hand"
            log("numpad now nudges " .. (what == "Hand" and "the grab SPOT (where the hand ends up)" or "the hand path's VIA point (what the wrist swings through on its way)"))
            return
        end
        if axis == "Hand" then
            back = not back
            log("numpad now nudges the " .. (back and "BACK" or "FRONT") .. " hand of a two-hand grab (one-hand grabs have the one)")
            return
        end
        local G = NATIVE.GR
        local kind = (G.dbl and G.dbl[2]) or ((G.native ~= 0) and G.native) or G.lastKind
        local name = kind and HAND_OF[kind]
        if not name then log("hand nudge: do a grab first (the nudge applies to your last grab)") return end
        local pre = ((what == "Hand" and NAT.switch) and "Sw" or "") .. what .. ((back and kind >= 200) and "2" or "")   -- (v103) in switch: the switch add-on
        local lim = (what == "Hand") and 40 or 60
        if axis then
            local k = pre .. name .. axis
            local old = tonumber(S[k]) or 0
            S[k] = math.max(-lim, math.min(lim, old + delta))
            if S[k] ~= old then NATIVE.tweak(k, old, S[k], "numpad") end
        end
        pcall(NATIVE.hands)
        local saved = axis and saveIni()
        log(string.format("hand %s%s %s: along %+g across %+g up %+g cm (+ = toward the nose / your toes / off the deck)%s", name,
            (kind >= 200) and (back and " BACK hand" or " FRONT hand") or "",
            what == "Hand" and (NAT.switch and "spot's SWITCH add-on" or "spot") or "path via point",
            S[pre .. name .. "Along"], S[pre .. name .. "Across"], S[pre .. name .. "Up"],
            axis and (saved and " -- saved to " .. INI or " -- could NOT write " .. INI) or ""))
    end
    local binds = { { Key.NUM_FOUR, "Along", -1 }, { Key.NUM_SIX, "Along", 1 }, { Key.NUM_SEVEN, "Across", -1 }, { Key.NUM_NINE, "Across", 1 },
                    { Key.NUM_EIGHT, "Up", 1 }, { Key.NUM_TWO, "Up", -1 }, { Key.NUM_FIVE, nil, 0 }, { Key.NUM_ZERO, "Toggle", 0 },
                    { Key.NUM_ONE, "Hand", 0 } }
    for _, b in ipairs(binds) do
        local axis, delta = b[2], b[3]
        pcall(RegisterKeyBind, b[1], function() if (S.DevKeys or 0) == 0 or NATIVE.off then return end NATIVE.gt(function() pcall(nudge, axis, delta) end) end)
    end
end
RegisterKeyBind(Key.F12, function() if (S.DevKeys or 0) == 0 or NATIVE.off then return end NATIVE.gt(function() pcall(hippie, "F12", false, "hippie") end) end)

-- THE NATIVE HALF. Mods\ExpandedTricksNative\dlls\main.dll (C++, source in Mods\ExpandedTricksNative\src) registers the
-- HJN_* functions into this mod's Lua before it starts. It takes over the skater mesh's
-- FinalizeBoneTransform and, while the game has a grab for a hand (Left/RightHandIKAlpha), solves that
-- arm onto the game's own grab point in the finished pose. From here it needs our mesh and anim instance,
-- the bone table (parents) and the arm chain, and the settings.
-- (v84) THE DECK'S REAL SIZE, from its own mesh: the Nose/Tail tips are at the deck mesh bounds' half length
-- (v81-v83 guessed 40 cm and put the hand "too far in"). Measured once per skater/board, again after a settings
-- change; NativeDeckHalfLen / NativeDeckHalfWidth = 0 use it, anything else overrides it.
NATIVE.measureDeck = function()
    if type(HJN_Set) ~= "function" or NATIVE.deckMeasured then return end
    local c = findFlipper()
    if not c then return end
    -- (v85) the reflected properties first (v84's GetStaticMesh():GetBounds() came back nil through UE4SS), each step logged
    local sm = q(function() return c.StaticMesh end, nil) or q(function() return c:GetStaticMesh() end, nil)
    local how = sm and "StaticMesh" or "no static mesh"
    local b = sm and q(function() return sm.ExtendedBounds end, nil)
    if b then how = how .. " + ExtendedBounds" else b = sm and q(function() return sm:GetBounds() end, nil) if b then how = how .. " + GetBounds()" end end
    local ext = b and q(function() return b.BoxExtent end, nil)
    local org = b and q(function() return b.Origin end, nil)
    local ex = ext and tonumber(q(function() return ext.X end, nil))
    local ey = ext and tonumber(q(function() return ext.Y end, nil))
    local ez = ext and tonumber(q(function() return ext.Z end, nil))
    local ox = org and tonumber(q(function() return org.X end, nil))
    local oz = org and tonumber(q(function() return org.Z end, nil))
    local sc = q(function() return c.RelativeScale3D end, nil) or q(function() return c:K2_GetComponentScale() end, nil)
    local sx = (sc and tonumber(q(function() return sc.X end, nil))) or 1
    local sy = (sc and tonumber(q(function() return sc.Y end, nil))) or 1
    NATIVE.deckMeasured = true
    if not (ex and ey and ox) or ex * sx < 15 or ex * sx > 80 then
        logOnce("deckmeasure", string.format("   deck mesh: Lua could not measure it (%s; bounds %s, extent %s x %s, origin %s, scale %s) -- the native half sizes it from the deck component's bounds instead",
            how, tostring(b ~= nil), tostring(ex), tostring(ey), tostring(ox), tostring(sx)))
        return
    end
    local hl, hw, cx = ex * sx, ey * sy, ox * sx
    local useL, useW = (S.NativeDeckHalfLen == 0), (S.NativeDeckHalfWidth == 0)
    HJN_Set("deckhalflen", useL and hl or S.NativeDeckHalfLen)
    HJN_Set("deckhalfwidth", useW and hw or S.NativeDeckHalfWidth)
    HJN_Set("deckcentre", useL and cx or 0)
    HJN_Set("deckmeasured", (useL or useW) and 1 or 0)
    local key = string.format("%.1f %.1f %.1f", hl, hw, cx)
    if key ~= NATIVE.deckKey then
        NATIVE.deckKey = key
        log(string.format("deck mesh measured: %.1f cm long, %.1f wide, %.1f tall (bounds centre %+.1f along, %+.1f up, scale %.2f) -> Nose/Tail tips %s, edges %s",
            2 * hl, 2 * hw, 2 * (ez or 0) * sx, cx, (oz or 0) * sx, sx,
            useL and string.format("%.1f cm from the centre (measured)", hl) or string.format("%.0f cm (your setting)", S.NativeDeckHalfLen),
            useW and string.format("%.1f cm out (measured)", hw) or string.format("%.1f cm out (your setting)", S.NativeDeckHalfWidth)))
    end
end

function NATIVE.sync()
    if NATIVE.audio == nil and S.MuteRevertSound ~= 0 then pcall(NATIVE.findAudio) end
    if type(HJN_Version) ~= "function" then
        if NATIVE.v == nil then NATIVE.v = false log("native half: *** NOT LOADED (Mods\\ExpandedTricksNative\\dlls\\main.dll; UE4SS.log says why) -- no settings pages, no grab hands, and without SessionTweaks no controller input: the mod does next to nothing on this run") end
        return
    end
    if not NATIVE.v then
        NATIVE.v = HJN_Version()
        log("native half: ExpandedTricksNative v" .. tostring(NATIVE.v))
        -- (v191, review) AN OLDER NATIVE HALF BESIDE THIS FILE (main.lua copied by hand, or main.dll not replaced because the
        -- game held it): everything runs, what needs the newer one is left out -- and nothing said so
        if (tonumber(NATIVE.v) or 0) < (NATIVE.WANT or 0) then
            log("native half: *** v" .. tostring(NATIVE.v) .. " IS OLDER than this main.lua is made for (v" .. tostring(NATIVE.WANT) .. "): close the game and copy the release's Mods\\ExpandedTricksNative\\dlls\\main.dll too (or run its install.bat). Until then a goofy rider's caught switch boneless lands with the feet turned round for half a second")
            NATIVE.upd = NATIVE.upd or {}
            if not NATIVE.upd.show then NATIVE.upd.show, NATIVE.upd.tries = "Expanded Tricks: native half is old - see the log", 0 end
        end
        -- (v122) the controller from the native half: the game's own key events, no SessionTweaks needed
        if S.NativePad ~= 0 and type(HJN_PadOn) == "function" and type(HJN_PadEvents) == "function" then
            NATIVE.pad = (tonumber(HJN_PadOn(1)) or 0) == 1
            local tw = io.open(TWKLOG, "rb") if tw then tw:close() end
            log(NATIVE.pad and "controller: read natively (the game's key events) -- SessionTweaks.log is not needed"
                or (tw and "controller: the native read was refused -- falling back to SessionTweaks.log (needs CatchClickToCatch=1)"
                or "controller: *** the native read was refused (ExpandedTricks.native.log says why) and there is no SessionTweaks.log to fall back to: stick clicks, bumpers, triggers and Y do nothing on this run"))
        else
            NATIVE.pad = false
            local tw = io.open(TWKLOG, "rb")
            if tw then tw:close() else log("controller: *** not read natively (NativePad=0, or an older native half) and there is no SessionTweaks.log: stick clicks, bumpers, triggers and Y do nothing -- set NativePad=1 in ExpandedTricks.ini") end
        end
    end
    if not alive(mesh) or not alive(inst) then return end
    local ma, ia, sa = addr(mesh), addr(inst), addr(s0)
    if ma and ia and sa and (ma ~= NATIVE.mesh or ia ~= NATIVE.anim or sa ~= NATIVE.skater) then
        NATIVE.live = (HJN_SetMesh(ma, ia, sa) == 1)
        NATIVE.mesh, NATIVE.anim, NATIVE.skater = ma, ia, sa
        log("native: our mesh and anim instance handed over -- pose hook " .. (NATIVE.live and "LIVE" or "NOT installed (see ExpandedTricks.native.log)"))
    end
    -- (v97) our player controller: the native half reads LB/RB off it and keeps its late-trick check off during grabs
    if type(HJN_SetPC) == "function" then
        local pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
        local pa = pc and addr(pc) or 0
        if pa ~= NATIVE.pc then
            NATIVE.pc = pa
            log("native: our player controller handed over -- " .. ((HJN_SetPC(pa) == 1) and "late-trick block and two-hand grabs ready" or "NOT taken (no late-trick block, no two-hand grabs)"))
        end
    end
    -- the bone table, once per skeletal mesh (a costume change can swap it)
    local skm = alive(q(function() return mesh.SkeletalMesh end))
    local ska = skm and addr(skm)
    if ska and ska ~= NATIVE.rigFor then
        NATIVE.rigFor = ska
        local n = tonumber(q(function() return mesh:GetNumBones() end, 0)) or 0
        local par, names = {}, {}
        for i = 0, n - 1 do
            local nm = q(function() return mesh:GetBoneName(i) end)
            local pn = nm and q(function() return mesh:GetParentBone(nm) end)
            local pi = pn and q(function() return mesh:GetBoneIndex(pn) end, -1) or -1
            par[#par + 1] = tostring(tonumber(pi) or -1)
            names[#names + 1] = (nm and q(function() return nm:ToString() end, nil)) or "?"
        end
        logOnce("bones" .. tostring(n), "native: bones: " .. table.concat(names, " "))   -- (v86) once: are there finger bones?
        local chain = {}
        for _, b in ipairs({ "AMXX_L_UpperArm", "AMXX_L_Forearm", "AMXX_L_Hand", "AMXX_R_UpperArm", "AMXX_R_Forearm", "AMXX_R_Hand",
                             "AMXX_L_Thigh", "AMXX_L_Calf", "AMXX_L_Foot", "AMXX_R_Thigh", "AMXX_R_Calf", "AMXX_R_Foot",
                             "SKXX_SkateSkel_Flipper", "SKXX_SkateSkel_Foot_Anchor_L", "SKXX_SkateSkel_Foot_Anchor_R",
                             "SKXX_SkateSkel_Hand_Anchor_L", "SKXX_SkateSkel_Hand_Anchor_R", "AMXX_L_Toe0", "AMXX_R_Toe0",
                             "AMXX_Neck", "AMXX_Head",
                             -- (v98) the fingers, thumb to pinky, root to tip: the hand's grip on the board
                             "AMXX_L_Finger0", "AMXX_L_Finger01", "AMXX_L_Finger02", "AMXX_L_Finger1", "AMXX_L_Finger11", "AMXX_L_Finger12",
                             "AMXX_L_Finger2", "AMXX_L_Finger21", "AMXX_L_Finger22", "AMXX_L_Finger3", "AMXX_L_Finger31", "AMXX_L_Finger32",
                             "AMXX_L_Finger4", "AMXX_L_Finger41", "AMXX_L_Finger42",
                             "AMXX_R_Finger0", "AMXX_R_Finger01", "AMXX_R_Finger02", "AMXX_R_Finger1", "AMXX_R_Finger11", "AMXX_R_Finger12",
                             "AMXX_R_Finger2", "AMXX_R_Finger21", "AMXX_R_Finger22", "AMXX_R_Finger3", "AMXX_R_Finger31", "AMXX_R_Finger32",
                             "AMXX_R_Finger4", "AMXX_R_Finger41", "AMXX_R_Finger42" }) do                      -- (v95: the limb audit's head)
            local f = fname(b)
            chain[#chain + 1] = tostring(f and q(function() return mesh:GetBoneIndex(f) end, -1) or -1)
        end
        NATIVE.rig = tonumber(HJN_SetRig(table.concat(par, " "), table.concat(chain, " "))) or 0
        log(string.format("native: bone table of %d bones, arm chain %s -> %s", n, table.concat(chain, " "),
            NATIVE.rig > 0 and "accepted" or "REFUSED (see ExpandedTricks.native.log)"))
    end
    if NATIVE.set96nc ~= tostring(S.NoComplyBackFootFlat) .. " " .. tostring(S.NoComplyKneeKeep) then   -- (v180) native v96: the soft plant's back foot and back knee
        NATIVE.set96nc = tostring(S.NoComplyBackFootFlat) .. " " .. tostring(S.NoComplyKneeKeep)
        pcall(HJN_Set, "backflat", S.NoComplyBackFootFlat or 1)
        pcall(HJN_Set, "kneekeep", S.NoComplyKneeKeep or 1)
        log("native: no comply -- back foot flat on the board " .. tostring(S.NoComplyBackFootFlat) .. ", back knee keeps its side " .. tostring(S.NoComplyKneeKeep)
            .. (((tonumber(NATIVE.v) or 0) >= 96) and "" or (" -- NOT TAKEN: the native half is v" .. tostring(NATIVE.v) .. ", these two need v96")))
    end
    if NATIVE.setOwn ~= S.HopLandOwn then                -- (v180) native v96: a straight hop's legs keep their own length through the landing
        NATIVE.setOwn = S.HopLandOwn
        pcall(HJN_Set, "landown", tonumber(S.HopLandOwn) or 6)
        log("native: a straight hop's legs keep their own length for " .. tostring(S.HopLandOwn) .. " s after touchdown at most"
            .. (((tonumber(NATIVE.v) or 0) >= 96) and "" or (" -- NOT TAKEN: the native half is v" .. tostring(NATIVE.v) .. ", this needs v96")))
    end
    do                                                   -- (v180) native v96: a hop's knees (the pose's own way through the air, blended through a 180's landing)
        local kk = tostring(S.HopKneeKeep) .. " " .. tostring(S.HopKneeLand) .. " " .. tostring(S.HopLandOwnTurn)
        if kk ~= NATIVE.setKnee then
            NATIVE.setKnee = kk
            pcall(HJN_Set, "hopknee", tonumber(S.HopKneeKeep) or 1)
            pcall(HJN_Set, "landknee", tonumber(S.HopKneeLand) or 1)
            pcall(HJN_Set, "landownturn", tonumber(S.HopLandOwnTurn) or 1)   -- (the straight landing's own-length legs, after a turned landing too: that part's key; a native half without it takes no notice)
            log("native: a hop's knees keep the pose's way " .. tostring(S.HopKneeKeep) .. ", are blended through a 180's landing " .. tostring(S.HopKneeLand)
                .. "; own-length legs after a 180's landing " .. tostring(S.HopLandOwnTurn)
                .. (((tonumber(NATIVE.v) or 0) >= 96) and "" or (" -- NOT TAKEN: the native half is v" .. tostring(NATIVE.v) .. ", these need v96")))
        end
    end
    do                                                   -- (v183) native v99: the knee's hinge, a hop's hips, the plant foot's swivel and ankle, the other stance's foot sockets
        if tostring(S.PoseRecorder) ~= NATIVE.set101 then            -- (v189) native v101: the pose recorder is off unless the ini asks
            NATIVE.set101 = tostring(S.PoseRecorder)
            pcall(HJN_Set, "posedump", (tonumber(S.PoseRecorder) or 0) ~= 0 and 1 or 0)
            log("native: the pose recorder is " .. (((tonumber(S.PoseRecorder) or 0) ~= 0) and "ON (ExpandedTricks.poses.bin)" or "off (PoseRecorder=1 switches it on)"))
        end
        local k100 = tostring(S.HopFeetFree) .. " " .. tostring(S.HopAnkleLimit) .. " " .. tostring(S.HopCarryTurn)   -- (v184) native v100: a hop's feet free in its air, a turned hop carried to its spots
        if k100 ~= NATIVE.set100 then
            NATIVE.set100 = k100
            pcall(HJN_Set, "hopfree", tonumber(S.HopFeetFree) or 1)
            pcall(HJN_Set, "anklim", tonumber(S.HopAnkleLimit) or 18)
            pcall(HJN_Set, "hopturn", tonumber(S.HopCarryTurn) or 1)
            log("native: in a hop's air the feet turn with their shins " .. tostring(S.HopFeetFree) .. " (the twist a foot may keep: " .. tostring(S.HopAnkleLimit)
                .. " deg); a hop that turns is carried to its landing spots as its turn completes " .. tostring(S.HopCarryTurn)
                .. (((tonumber(NATIVE.v) or 0) >= 100) and "" or (" -- NOT TAKEN: the native half is v" .. tostring(NATIVE.v) .. ", these need v100")))
        end
        local k99 = tostring(S.LegHingeRoll) .. " " .. tostring(S.HopHipFix) .. " " .. tostring(S.NoComplySwivel) .. " " .. tostring(S.NoComplyAnkle) .. " " .. tostring(S.NoComplySwitchFeet) .. " " .. tostring(S.HopShinTight)
        if k99 ~= NATIVE.set99 then
            NATIVE.set99 = k99
            pcall(HJN_Set, "legroll", tonumber(S.LegHingeRoll) or 1)
            pcall(HJN_Set, "hophips", tonumber(S.HopHipFix) or 1)
            pcall(HJN_Set, "shintight", tonumber(S.HopShinTight) or 1)
            pcall(HJN_Set, "plswivel", tonumber(S.NoComplySwivel) or 1)
            pcall(HJN_Set, "plankle", tonumber(S.NoComplyAnkle) or 1)
            pcall(HJN_Set, "sockon", tonumber(S.NoComplySwitchFeet) or 1)
            log("native: a solved leg is rolled onto its knee's hinge " .. tostring(S.LegHingeRoll) .. "; a hop's hip joints go back in their sockets " .. tostring(S.HopHipFix)
                .. "; the plant foot swivels with the hips " .. tostring(S.NoComplySwivel) .. " and comes back in its ankle " .. tostring(S.NoComplyAnkle)
                .. "; a switch plant's feet are the game's own (its foot sockets turned with the body) " .. tostring(S.NoComplySwitchFeet)
                .. (((tonumber(NATIVE.v) or 0) >= 99) and "" or (" -- NOT TAKEN: the native half is v" .. tostring(NATIVE.v) .. ", these five need v99")))
        end
    end
    do                                                   -- (v181) native v97: a hop's knee the riding shin's way; SessionTweaks' idle re-learn waits while a trick is drawn
        local k97 = tostring(S.HopKneeRide) .. " " .. tostring(S.TweaksLearnGuard)
        if k97 ~= NATIVE.set97 then
            NATIVE.set97 = k97
            pcall(HJN_Set, "shinride", tonumber(S.HopKneeRide) or 1)
            pcall(HJN_Set, "stquiet", tonumber(S.TweaksLearnGuard) or 1)
            log("native: a hop's straight or squeezed leg bends its knee the way that shin stands on its foot riding " .. tostring(S.HopKneeRide)
                .. "; SessionTweaks' idle re-learn waits while a trick of the mod's is drawn " .. tostring(S.TweaksLearnGuard)
                .. (((tonumber(NATIVE.v) or 0) >= 97) and "" or (" -- NOT TAKEN: the native half is v" .. tostring(NATIVE.v) .. ", these two need v97")))
        end
    end
    do                                                   -- (v179) the hops' and the plant's switches of native v95 (before the old block: a setting that %d cannot format stops that one)
        local k95 = table.concat({ tostring(S.HopCarry), tostring(S.HopLagFix), tostring(S.HopKneeToes), tostring(S.NoComplyPlantStick), tostring(S.NoComplyPlantTime) }, " ")
        if k95 ~= NATIVE.set95 then
            NATIVE.set95 = k95
            pcall(HJN_Set, "hopcarry", S.HopCarry or 1)
            pcall(HJN_Set, "holdplace", S.HopLagFix or 1)
            pcall(HJN_Set, "kneetoes", S.HopKneeToes or 1)
            pcall(HJN_Set, "plantstick", S.NoComplyPlantStick or 1)
            pcall(HJN_Set, "plantstand", S.NoComplyPlantTime or 0.12)
            log(string.format("native: hop carry %s, landing lag fix %s, knee over toes %s; plant foot sticks %s, stands %s s at most",
                tostring(S.HopCarry), tostring(S.HopLagFix), tostring(S.HopKneeToes), tostring(S.NoComplyPlantStick), tostring(S.NoComplyPlantTime))
                .. (((tonumber(NATIVE.v) or 0) >= 95) and "" or (" -- NOT TAKEN: the native half is v" .. tostring(NATIVE.v) .. ", these five need v95")))
        end
    end
    local want = string.format("%d %.3f %.1f %.1f %.2f %d %.1f %.1f %d %.2f %d %.2f %d %d %.2f %d %.2f %.1f %.2f %.3f %.1f %d %.1f %.1f %.3f %.2f %d %.1f %.1f %d %.1f %.1f %d %.1f %.1f %.1f %.1f %.1f %d %.1f %.1f %.1f %.1f %.1f %.1f %.2f", S.NativeGrab, S.NativeGrabStrength,
        S.NativeHandUp, S.NativeTweak, S.NativeTweakShare, S.NativeLegs, S.NativeLean, S.NativePull, S.NativeFeet,
        S.NativeElbowOut, S.NativeKneeAway, S.NativeHandFull, S.NativeGuard, S.NativeRevertCtl, S.NativeEase, S.NativeTweakMode, S.NativeFitHand, S.NativeFitMove, S.NativeHoldBleed, S.NativeFitGain, S.NativeHeel, S.NativeLegSearch, S.NativeNosePitch, S.NativeTailPitch, S.NativeBoardEase, S.NativeEdgeRoll, S.NativeArmSearch, S.NativeMelonBack, S.NativeProfileLift, S.NativeTailFromNose, S.NativeIndyPitch, S.NativeMelonPitch, S.NativeOwnSpots, S.NativeDeckHalfLen, S.NativeDeckHalfWidth, S.NativeSpotUp, S.NativeSpotIn, S.NativeFootSlide, S.NativeDeckUp,
        S.NativeSpotUpEdge, S.NativeMelonFwd, S.NativeMelonLift, S.NativeIndyLift, S.NativeMelonDrop, S.NativeIndyDrop, S.NativeLeanTuck)
    if want ~= NATIVE.set then
        NATIVE.set = want
        HJN_Set("grab", S.NativeGrab)
        HJN_Set("strength", S.NativeGrabStrength)
        HJN_Set("handup", S.NativeHandUp)
        HJN_Set("tweak", S.NativeTweak)
        HJN_Set("tweakshare", S.NativeTweakShare)
        HJN_Set("legs", S.NativeLegs)
        HJN_Set("lean", S.NativeLean)
        HJN_Set("pull", S.NativePull)
        HJN_Set("feet", S.NativeFeet)
        HJN_Set("elbowout", S.NativeElbowOut)
        HJN_Set("kneeaway", S.NativeKneeAway)
        HJN_Set("handfull", S.NativeHandFull)
        HJN_Set("guard", S.NativeGuard)
        HJN_Set("revertctl", S.NativeRevertCtl)
        HJN_Set("ease", S.NativeEase)
        HJN_Set("tweakmode", S.NativeTweakMode)
        HJN_Set("fithand", S.NativeFitHand)
        HJN_Set("fitmove", S.NativeFitMove)
        HJN_Set("holdbleed", S.NativeHoldBleed)
        HJN_Set("fitgain", S.NativeFitGain)
        HJN_Set("heel", S.NativeHeel)
        HJN_Set("legsearch", S.NativeLegSearch)
        HJN_Set("nosepitch", S.NativeNosePitch)
        HJN_Set("tailpitch", S.NativeTailPitch)
        HJN_Set("boardease", S.NativeBoardEase)
        HJN_Set("edgeroll", S.NativeEdgeRoll)
        HJN_Set("armsearch", S.NativeArmSearch)
        HJN_Set("melonback", S.NativeMelonBack)
        HJN_Set("profilelift", S.NativeProfileLift)
        HJN_Set("tailfromnose", S.NativeTailFromNose)
        HJN_Set("indypitch", S.NativeIndyPitch)
        HJN_Set("melonpitch", S.NativeMelonPitch)
        HJN_Set("ownspots", S.NativeOwnSpots)
        HJN_Set("deckhalflen", S.NativeDeckHalfLen)              -- (v85) 0 = the native half sizes the deck from its bounds (or Lua's measurement)
        HJN_Set("deckhalfwidth", S.NativeDeckHalfWidth)
        HJN_Set("spotup", S.NativeSpotUp)
        HJN_Set("spotin", S.NativeSpotIn)
        HJN_Set("footslide", S.NativeFootSlide)
        HJN_Set("deckup", S.NativeDeckUp)
        HJN_Set("spotupedge", S.NativeSpotUpEdge)
        HJN_Set("melonfwd", S.NativeMelonFwd)
        HJN_Set("melonlift", S.NativeMelonLift)
        HJN_Set("indylift", S.NativeIndyLift)
        HJN_Set("melondrop", S.NativeMelonDrop)
        HJN_Set("indydrop", S.NativeIndyDrop)
        HJN_Set("leantuck", S.NativeLeanTuck)
        NATIVE.mirrorSent = nil                          -- (v82) the mirror goes again with the next frame
        NATIVE.deckMeasured = nil                        -- (v84) the deck is measured again (the half len/width settings may have changed)
    end
    pcall(NATIVE.measureDeck)
    pcall(NATIVE.hands)
end

-- (v86) your per-grab hand offsets -> the native half, whenever they change (the ini, or a numpad nudge)
NATIVE.hands = function(force)
    if type(HJN_GrabSet) ~= "function" then return end    -- (v96) all 12 grabs x 15 numbers
    local parts = {}
    for _, g in ipairs(NATIVE.GRABS) do
        for _, p in ipairs(NATIVE.PARAMS) do
            if not p[8] or g[2] >= 200 then parts[#parts + 1] = tostring(S[p[1] .. g[1] .. p[2]]) end
        end
    end
    parts[#parts + 1] = tostring(S.NativeHandAvoid)
    parts[#parts + 1] = tostring(S.GrabAllAlong) .. "/" .. tostring(S.GrabAllAcross) .. "/" .. tostring(S.GrabAllUp)   -- (v184)
    parts[#parts + 1] = tostring(S.GrabBlockFlips)
    parts[#parts + 1] = tostring(S.NativeHandAim) .. "/" .. tostring(S.NativeFingerCurl) .. "/" .. tostring(S.NativeFingerCurlRoot) .. "/" .. tostring(S.NativeFingerCurlMid) .. "/" .. tostring(S.NativeFingerCurlTip) .. "/" .. tostring(S.NativeCatchHold) .. "/" .. tostring(S.NativeGrabStance)
    local key = table.concat(parts, " ")
    if key == NATIVE.handsSet and not force then return end
    NATIVE.handsSet = key
    for _, g in ipairs(NATIVE.GRABS) do
        for _, p in ipairs(NATIVE.PARAMS) do
            if not p[8] or g[2] >= 200 then
                if p[3] >= 100 then
                    if type(HJN_GrabSetSw) == "function" then HJN_GrabSetSw(g[2], p[3] - 100, tonumber(S[p[1] .. g[1] .. p[2]]) or 0) end
                else
                    -- (v184) EVERY GRAB'S HAND AT ONCE: GrabAllAlong / Across / Up are added to each grab's own hand spot (both hands'
                    -- in a two-hand grab), here, on the way to the native half -- the per-grab numbers stay as they are in the ini
                    local v = tonumber(S[p[1] .. g[1] .. p[2]]) or 0
                    if (p[1] == "Hand" or p[1] == "Hand2") and p[2] ~= "" then v = v + (tonumber(S["GrabAll" .. p[2]]) or 0) end
                    HJN_GrabSet(g[2], p[3], v)
                end
            end
        end
    end
    HJN_Set("handavoid", S.NativeHandAvoid)
    HJN_Set("grabstance", S.NativeGrabStance)              -- (v119) the tail layout for every grab
    HJN_Set("catchhold", S.NativeCatchHold)               -- (v116) the deck keeps following the bone through the game's grabs
    HJN_Set("lateblock", S.GrabBlockFlips)               -- (v97) no late flips out of a grab
    HJN_Set("handaim", S.NativeHandAim)                  -- (v98) the hand turned to the board, the fingers round its edge
    HJN_Set("fingercurl", S.NativeFingerCurl)
    HJN_Set("curlroot", S.NativeFingerCurlRoot)           -- (v115) the three joints' own degrees
    HJN_Set("curlmid", S.NativeFingerCurlMid)
    HJN_Set("curltip", S.NativeFingerCurlTip)
end

-- MAP CHANGES. Every UObject this script caches (the skater, its mesh and anim instance, the deck, the
-- controller, the trick display widgets) dies with the old level. v68/v69 crashed on a map change: the
-- 2 s native sync kept reading the dead mesh (mesh.SkeletalMesh on freed memory -> an access violation
-- inside UE4SS). v70 dropped everything from UE4SS's RegisterLoadMapPreHook -- but on this UE4SS (3.0.1)
-- that hook itself throws a C++ exception inside the engine's map load (UEngine::Browse -> LoadMap) =
-- the v70 crash. v71: no engine hook at all. The 2 s loop notices the skater is gone (or a new one is
-- there) and drops the rest then; the native half is stood down in the same step.
NATIVE.forgetWorld = function(why)
    if NATIVE.mirrorAsset then                           -- (review) the goofy rider's mirror table is not left away over a level change
        pcall(NATIVE.mirrorEnd, "level change: " .. tostring(why))
        local NCm = NATIVE.noComply
        if NCm and NCm.flip then NCm.flip, NCm.flipYaw, NCm.flipN = nil, nil, nil if type(HJN_Set) == "function" then pcall(HJN_Set, "plantfoot", -1) end end
        VS.graph = nil
    end
    cached, s0, mesh, inst, mv = nil, nil, nil, nil, nil
    active = false if NATIVE.rotBack then NATIVE.rotBack() end
    SB.pc, BD.comp = nil, nil
    if NATIVE.forgetUi then NATIVE.forgetUi() end
    if NATIVE.forgetGrab then NATIVE.forgetGrab() end
    if revertSnap.forget then revertSnap.forget() end
    RV = { pending = false }
    NATIVE.mute(false)
    NATIVE.mesh, NATIVE.anim, NATIVE.skater, NATIVE.rigFor, NATIVE.live = nil, nil, nil, nil, false
    NATIVE.deckMeasured = nil                            -- (v84) the next board is measured afresh
    liftBroken = {}                                      -- (v139) a lift method given up on (filmer mode's hop) is tried again with the next skater
    if NATIVE.gg then NATIVE.gg.kind, NATIVE.gg.offSince, NATIVE.gg.muted = nil, nil, nil end   -- (v155) a rolling grab ends with the skater
    if type(HJN_TrickMute) == "function" then pcall(HJN_TrickMute, 0) end
    if NATIVE.noComply then                                                                   -- (v138) wired again for the new skater
        NATIVE.noComply.done, NATIVE.noComply.tries = false, 0
        NATIVE.noComply.guard, NATIVE.noComply.matchWas = nil, false                          -- (v148)
        if type(HJN_Set) == "function" then pcall(HJN_Set, "nobail", 0) end
    end
    NATIVE.pc = nil                                      -- (v97)
    if NATIVE.forgetDrop then pcall(NATIVE.forgetDrop) end   -- (v98)
    if type(HJN_SetPC) == "function" then pcall(HJN_SetPC, 0) pcall(HJN_Set, "double", 0) end
    if type(HJN_SetMesh) == "function" then pcall(HJN_SetMesh, 0, 0, 0) end
    log("level change (" .. why .. "): cached game objects dropped, the native half stood down")
end

-- THE BOARD HOP (v78). On foot after a bail the board lies loose on the ground (a "ragdoll" physics body);
-- the game's own toggle would put it in your hand first. A click (L3 or R3) while on foot within BoardHopRange
-- of that board: the skater jumps onto it on an arc (like the end of a hippie jump) and, on touchdown, the native
-- half readies the game's own mount-where-it-lies path (stance, the deck keeps its heading, the ragdoll flag
-- cleared) and SetPendingApplyToggleOnBoard runs it (the skater's next Tick -> ApplyToggleOnBoard(true)).
-- A separate module: it only acts while you are OFF the board, which the hippie jump never is.
do
    local HOP = { on = false, rideZ = nil, after = nil, chest = nil }   -- chest: +1 your toes point right of the capsule while riding, -1 left (v127)
    local function deckWorld()
        if type(HJN_DeckWorld) ~= "function" then return nil end
        local s = HJN_DeckWorld()
        if not s or s == "" then return nil end
        local x, y, z, yaw, upz = s:match("^(%S+) (%S+) (%S+) (%S+) (%S+)$")
        if not x then return nil end
        return { x = tonumber(x), y = tonumber(y), z = tonumber(z), yaw = tonumber(yaw), upz = tonumber(upz) }
    end
    local function wrapA(a) return a - 360 * math.floor(a / 360 + 0.5) end

    -- while riding: how high the capsule rides over the deck (where a hop lands)
    NATIVE.hopMeasure = function()
        if not s0 or not NATIVE.live or modeNow() ~= MODE_RIDING then return end
        local d = deckWorld()
        local loc = q(function() return s0:K2_GetActorLocation() end)
        if not d or not loc then return end
        local off = loc.Z - d.z
        if off < 20 or off > 200 then return end
        local first = HOP.rideZ == nil
        HOP.rideZ = first and off or (HOP.rideZ + (off - HOP.rideZ) * 0.2)
        if first then log(string.format("board hop: the skater rides %.0f cm over the deck (the hop lands there)", off)) end
        -- (v127) which way your chest faces on the board, from your toes: they point to the toe side, across the capsule's
        -- forward (right for a regular rider, left for goofy; the game keeps the pose natural to the capsule in switch too,
        -- the capsule being the thing it turns round). A hop lands you facing that way
        local tl = q(function() return mesh:GetSocketLocation(fname("AMXX_L_Toe0")) end)
        local fl = q(function() return mesh:GetSocketLocation(fname("AMXX_L_Foot")) end)
        local tr = q(function() return mesh:GetSocketLocation(fname("AMXX_R_Toe0")) end)
        local fr = q(function() return mesh:GetSocketLocation(fname("AMXX_R_Foot")) end)
        local rot = q(function() return s0:K2_GetActorRotation() end)
        if tl and fl and tr and fr and rot then
            local tx, ty = (tl.X - fl.X) + (tr.X - fr.X), (tl.Y - fl.Y) + (tr.Y - fr.Y)
            local yr = math.rad(rot.Yaw)
            local across = tx * -math.sin(yr) + ty * math.cos(yr)         -- onto the capsule's right
            local along  = tx * math.cos(yr) + ty * math.sin(yr)
            if math.abs(across) > 6 and math.abs(across) > math.abs(along) then
                local side = (across > 0) and 1 or -1
                if HOP.chest ~= side then
                    HOP.chest = side
                    log(string.format("board hop: riding, your toes point to the %s of the way the capsule faces -- a hop lands you facing that way", side > 0 and "right" or "left"))
                end
            end
        end
    end

    -- (v131) THE BOARD CONTROLLER MUST SIT ON YOUR AXIS (0 or 180 deg) while you ride. On 2 Oct an interrupted game revert
    -- left it 130 deg off with the deck offset at 360, and the next deck-stays-put landing made a rider twisted in two
    -- (feet with the deck, torso with the skeleton). The native half refuses the swap in that state now (the game's own
    -- revert runs instead); this watches for the state itself and says so, once per 10 s
    NATIVE.axisCheck = function()
        if not s0 or not NATIVE.live or type(HJN_CtrlYaw) ~= "function" or modeNow() ~= MODE_RIDING or (RV and RV.pending) then return end
        -- (v135) against the CAPSULE's yaw (the controller quat is a world yaw: v131 compared it with world 0/180 and warned
        -- whenever you were not riding along the world's X); 45 deg, three looks in a row
        local ay = q(function() return s0:K2_GetActorRotation().Yaw end, nil)
        if not ay then return end
        local s = tostring(HJN_CtrlYaw(ay) or "")
        local cy, dof, rev = s:match("^(%S+) (%S+) (%S+)$")
        cy, dof = tonumber(cy), tonumber(dof)
        if not cy or rev ~= "0" then return end
        local off = math.min(math.abs(cy), math.abs(math.abs(cy) - 180))
        HOP.axisN = (off > 45) and ((HOP.axisN or 0) + 1) or 0
        if HOP.axisN >= 3 and os.clock() - (HOP.axisAt or -1e9) > 10 then
            HOP.axisAt = os.clock()
            log(string.format("board controller: the board's target sits %.0f deg off your capsule while riding (deck offset %.0f) -- the lower half follows the deck, the torso the skeleton; a game revert (trigger double-tap) squares it", cy, dof))
        end
    end

    -- (v127) WHERE THE BOARD WILL BE when the hop lands, and the yaws that go with it. A board still rolling used to be
    -- aimed at where it lay at the click: you landed there and the game's mount snapped you to wherever it had rolled
    -- to. Its speed is read from the deck's own movement between ticks (smoothed), the aim is renewed every tick, so the
    -- arc bends with the board and ends on it exactly, rolling or not
    local function hopAim(d, now)
        local dt = now - HOP.bt
        if dt >= 0.03 then
            local vx, vy, vz = (d.x - HOP.bp[1]) / dt, (d.y - HOP.bp[2]) / dt, (d.z - HOP.bp[3]) / dt
            if math.abs(vx) < 2000 and math.abs(vy) < 2000 and math.abs(vz) < 2000 then      -- (a teleport is not a speed)
                HOP.bv[1] = HOP.bv[1] + (vx - HOP.bv[1]) * 0.5
                HOP.bv[2] = HOP.bv[2] + (vy - HOP.bv[2]) * 0.5
                HOP.bv[3] = HOP.bv[3] + (vz - HOP.bv[3]) * 0.5
            end
            HOP.bp[1], HOP.bp[2], HOP.bp[3], HOP.bt = d.x, d.y, d.z, now
        end
        local rem = math.max(0, math.max(0.1, S.BoardHopTime) - (now - HOP.t0))
        local rideZ = HOP.rideZ or S.BoardHopRideZ
        HOP.p1 = { d.x + HOP.bv[1] * rem, d.y + HOP.bv[2] * rem, d.z + HOP.bv[3] * rem + rideZ }
        local H = HOP.nose and d.yaw or (d.yaw + 180)
        HOP.yc = HOP.sw and (H + 180) or H                            -- the capsule's yaw at the mount (the game turns the board to it)
        HOP.y1 = HOP.y0 + wrapA(HOP.yc + HOP.side * 90 - HOP.y0)     -- in the air: the chest to the toe side, the feet along the deck
    end

    NATIVE.hopTry = function(which)
        if S.BoardHop == 0 or HOP.on or HOP.after or not NATIVE.live or type(HJN_BoardState) ~= "function" then return false end
        if not refs() then return false end
        local st = tonumber(HJN_BoardState()) or -1
        if st < 0 or (st & 4) ~= 0 then return false end                 -- no board / riding: not ours
        if (st & 1) == 0 or (st & 8) ~= 0 then return false end          -- in your hand, or the game is busy with it
        local d = deckWorld()
        if not d then return false end
        if d.upz < 0.7 then log("board hop: the board is lying upside down or on its side -- no hop") return true end
        local loc = q(function() return s0:K2_GetActorLocation() end)
        local rot = q(function() return s0:K2_GetActorRotation() end)
        if not loc or not rot then return false end
        local dx, dy = d.x - loc.X, d.y - loc.Y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > S.BoardHopRange then
            log(string.format("board hop: the board is %.0f cm away (BoardHopRange %d) -- walk closer", dist, S.BoardHopRange))
            return true
        end
        -- ride the way you face: the board's end nearer your facing is the front; keep your stance
        local F = rot.Yaw
        -- (v186) ...WITH THE LEAST TURN OF YOUR BODY. "It seems to know what the back of the board is and what the front is. But
        -- that could mean a full 180 for the player." The front was the end nearer your facing and the stance was kept as it
        -- was, which fixes the side your chest faces on the board: up to half a turn away from where you look. On a board
        -- there are only two ways to stand (chest to one side of it or to the other); the one nearer your facing is taken, and
        -- of the two ways to ride it (nose-first regular, or tail-first switch for the same chest) the one that rolls the way
        -- you face -- regular unless that rolls more than 100 deg away from it
        local side0 = HOP.chest or (NAT.goofy and -1 or 1)
        local noseReg = math.abs(wrapA(F - (d.yaw + 90 * side0))) <= 90      -- chest to the deck's +side with the nose in front
        local sw = math.abs(wrapA(F - (noseReg and d.yaw or (d.yaw + 180)))) > 100
        local nose = (sw ~= noseReg)
        -- (v127) IN THE AIR YOU FACE THE WAY YOU WILL FACE ON THE BOARD: the chest to the toe side (HOP.chest, from your toes
        -- while riding; until measured, regular = right, goofy = left), the feet along the deck -- you used to fly facing
        -- along the deck and land across it. The capsule must face the ride at the mount (the game turns the board to the
        -- capsule's yaw), so the last frame turns it there: the riding pose faces the chest the same way, so nothing swings
        local side = HOP.chest or (NAT.goofy and -1 or 1)                -- (NAT is the global frame table; visualGoofy is out of scope here)
        local now = os.clock()
        HOP = { on = true, t0 = now, rideZ = HOP.rideZ, chest = HOP.chest,
                p0 = { loc.X, loc.Y, loc.Z }, b0 = { d.x, d.y }, bp = { d.x, d.y, d.z }, bt = now, bv = { 0, 0, 0 },
                y0 = F, nose = nose, sw = sw, side = side, flip = (sw ~= (not nose)) }
        hopAim(d, now)
        q(function() mv:SetMovementMode(3, 0) end)                          -- airborne: the on-foot jump pose
        log(string.format("board hop (%s): %.0f cm to the board, riding %s %s, facing the deck's %s side in the air (%s), landing %.0f cm over the deck",
            which, dist, nose and "nose-first" or "tail-first", sw and "switch" or "regular", side > 0 and "right" or "left",
            HOP.chest and "your toes while riding" or "by your stance", HOP.rideZ or S.BoardHopRideZ))
        return true
    end

    NATIVE.hopTick = function()
        if HOP.after then
            -- (v128) THE BOARD KEEPS ITS SPEED. The game's mount (SetOnBoardMode + SnapToGround) leaves the board standing
            -- still, whatever it was doing. So once the game has you on it, every part gets the velocity the board was met
            -- with (HJN_BoardKick: the drop-in's own release), and again a frame or two later should the mount's first frame
            -- have zeroed it; then the game's own speed reading is logged
            local A = HOP.after
            local now = os.clock()
            local onb = q(function() return s0:IsOnBoard() end, false) == true
            if onb then
                if A.kicks == 0 or (A.kicks == 1 and now >= A.nextKick) then
                    local n = 0
                    if A.speed >= 30 and type(HJN_BoardKick) == "function" and type(HJN_BoardParts) == "function" and NATIVE.boardParts then
                        local parts = NATIVE.boardParts()
                        local took = parts and tonumber(HJN_BoardParts(table.unpack(parts))) or 0
                        if took > 0 then n = tonumber(HJN_BoardKick(A.vx, A.vy, 0, 0, A.vx / A.speed, A.vy / A.speed)) or 0 end
                        pcall(HJN_BoardParts)                                  -- (the parts let go of again)
                    end
                    A.kicks, A.nextKick = A.kicks + 1, now + 0.06
                    if A.kicks == 1 then
                        log((A.speed >= 30) and string.format("board hop: riding -- the board's %.0f cm/s given back to it (%d parts%s)", A.speed, n, (n > 0) and "" or " -- NOT kicked")
                            or "board hop: riding")
                    elseif A.kicks >= 2 then
                        HOP.after = nil
                        if A.speed >= 30 then
                            log(string.format("board hop:    the game reads %.0f cm/s %.0f ms after the mount", tonumber(q(function() return mv:GetCurrentSpeed() end, -1)) or -1, (now - A.t0) * 1000))
                        end
                    end
                end
            elseif now >= A.deadline then
                HOP.after = nil
                if type(HJN_BoardRagdoll) == "function" then HJN_BoardRagdoll() end
                log("board hop: the game did not mount you (board flag put back) -- mode " .. tostring(modeNow()))
            end
            return
        end
        if not HOP.on then return end
        if not alive(s0) then HOP.on = false return end
        local now = os.clock()
        local d = deckWorld()
        if d and d.upz > 0.5 then hopAim(d, now) end                     -- (v127) the board may be rolling: aim again
        local k = math.min(1, (now - HOP.t0) / math.max(0.1, S.BoardHopTime))
        local e = k * k * (3 - 2 * k)
        local x = HOP.p0[1] + (HOP.p1[1] - HOP.p0[1]) * e
        local y = HOP.p0[2] + (HOP.p1[2] - HOP.p0[2]) * e
        local z = HOP.p0[3] + (HOP.p1[3] - HOP.p0[3]) * e + 4 * S.BoardHopHeight * k * (1 - k)
        local yaw = (k < 1) and (HOP.y0 + (HOP.y1 - HOP.y0) * e) or HOP.yc   -- the last frame: the capsule faces the ride
        pcall(function() s0:K2_SetActorLocationAndRotation({ X = x, Y = y, Z = z }, { Pitch = 0, Yaw = yaw, Roll = 0 }, false, {}, true) end)
        pcall(function() mv.Velocity = { X = 0, Y = 0, Z = 0 } end)
        if k < 1 then return end
        HOP.on = false
        local rolled = math.sqrt((HOP.bp[1] - HOP.b0[1]) ^ 2 + (HOP.bp[2] - HOP.b0[2]) ^ 2)
        local speed = math.sqrt(HOP.bv[1] ^ 2 + HOP.bv[2] ^ 2)
        if tonumber(HJN_BoardMount(HOP.sw and 1 or 0, HOP.flip and 1 or 0)) == 1 then
            local ok, err = pcall(function() s0:SetPendingApplyToggleOnBoard() end)
            log(ok and string.format("board hop: landed%s -- the game mounts you on the board where it is",
                    (rolled > 15) and string.format(" (the board rolled %.0f cm during the hop, met at %.0f cm/s)", rolled, speed) or "")
                or ("board hop: mount call failed: " .. tostring(err)))
            if not ok and type(HJN_BoardRagdoll) == "function" then HJN_BoardRagdoll() end
            HOP.after = { t0 = os.clock(), deadline = os.clock() + 0.6, speed = speed, vx = HOP.bv[1], vy = HOP.bv[2], kicks = 0, nextKick = 0 }   -- (v128)
        else
            q(function() mv:SetMovementMode(1, 0) end)
            log("board hop: the native half refused the mount (see ExpandedTricks.native.log) -- back on foot")
        end
    end

    LoopAsync(10, function()
        if HOP.on or HOP.after then NATIVE.gt(function() pcall(NATIVE.hopTick) end) end
        return false
    end)
end

-- THE DROP-IN (v98). The game has no marked ledges: its grind detector finds edges by sweeping the level's collision and
-- comparing the two faces it hits. So the native half looks the same way, with rays (HJN_Ledge): the ground you stand
-- on, where it drops away, which way that drop faces, and at what angle a board pivoting on the edge meets the ground
-- below. On foot and close to such an edge, Y / triangle:
--   mount  the game's own throwdown puts you on the board where you stand (the mod cannot stop that press); it throws
--          the board out ahead of you and bails when that spot is past the edge, so closer than DropInStart you are
--          first stepped back to there (v103); should it still fail, the mod mounts you itself (v99);
--   set    the game's teleport stands you and the board square to the edge, all wheels on the ledge (it snaps a board
--          to the ground under its middle, so it cannot be put out over the drop);
--   out    the board's parts are moved into the drop-in stance, every frame, by the native half (HJN_BoardStance:
--          teleported, velocities zeroed): the back wheels hung out past the edge, the tail down on the ledge, the
--          deck rising over the drop -- and the game is told the board is grounded the while (HJN_GroundHold, v102:
--          a vtable hook; on a coping it did not count the tail and went to "air", where a leg's touch bails);
--   wait   held there. A stick pushed UP = drop in; LB or RB = back onto the ledge; Y = the game takes you off.
--   in     the way down is traced (HJN_BoardMeet: the front wheels swung about the hung back axle until they meet the
--          ground), the board tips down to a degree short of that, is let go with DropInSpeed along it and the game
--          rides it from there. Nothing met within DropInMaxSlope (a plain wall with the ground far below) = it tips
--          DropInTilt nose-down and rolls off instead.
-- While the board is held the game sees centred sticks (a stick let go would be a flick = a pop).
do
    local DI = { state = nil }
    local PARTS = { "Flipper", "TruckHangerFront", "TruckHangerBack", "WheelFront_L", "WheelFront_R", "WheelBack_L", "WheelBack_R" }
    local function parseLedge(s)
        if type(s) ~= "string" or s:sub(1, 4) ~= "edge" then return nil, tostring(s) end
        local n = {}
        for v in s:gmatch("%-?%d+%.?%d*") do n[#n + 1] = tonumber(v) end
        if #n < 15 then return nil, "could not read: " .. s end
        return { x = n[1], y = n[2], top = n[3], ox = n[4], oy = n[5], dist = n[6], near = n[8], far = n[9], meet = n[10],
                 nx = n[11], ny = n[12], nz = n[13], slope = n[14], toptilt = n[15], lip = n[16] or 0 }
    end
    local function boardParts()
        BD.comp = nil                                    -- (look again: the board you stand on now)
        local flip = findFlipper()
        local owner = flip and alive(q(function() return flip:GetOwner() end))
        local pcls = alive(q(function() return StaticFindObject("/Script/Engine.PrimitiveComponent") end))
        if not (owner and pcls) then return nil end
        local byName = {}
        local list = q(function() return owner:K2_GetComponentsByClass(pcls) end)
        local n = list and (q(function() return #list end, nil) or q(function() return list:GetArrayNum() end, 0)) or 0
        for i = 1, n do
            local c = alive(q(function() return list[i]:get() end))
            if c then byName[q(function() return c:GetFName():ToString() end, "")] = c end
        end
        local out = {}
        for _, name in ipairs(PARTS) do
            local a = byName[name] and addr(byName[name])
            if a then out[#out + 1] = a elseif name == "Flipper" then return nil end
        end
        return out
    end
    NATIVE.boardParts = boardParts                   -- (v128) the board hop gives the board its speed back through the same parts
    DI.pitchNow = function()
        local up = tonumber((tostring(type(HJN_DeckWorld) == "function" and HJN_DeckWorld() or ""):match("(%S+)$"))) 
        return up and string.format("%.0f deg off level", math.deg(math.acos(math.max(-1, math.min(1, up))))) or "?"
    end
    local function letGo(why)
        if type(HJN_BoardParts) == "function" then pcall(HJN_BoardParts) end
        if DI.ground and type(HJN_GroundHold) == "function" then
            local n = tonumber(HJN_GroundHold(0)) or 0
            if DI.state then log(string.format("drop-in:    the game's grounded check given back (answered for the held board %d times)", n)) end
        end
        DI.ground, DI.held = nil, nil
        if DI.state then log("drop-in: " .. why) end
        DI.state, DI.rideAt = nil, nil
    end
    NATIVE.forgetDrop = function() letGo("the level changed") end
    local function sticksCentred()
        local pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
        if not pc then return end
        SB.pc = pc
        pcall(function()
            pc:SimulateInput_LeftStick_X_Axis(0.0)  pc:SimulateInput_LeftStick_Y_Axis(0.0)
            pc:SimulateInput_RightStick_X_Axis(0.0) pc:SimulateInput_RightStick_Y_Axis(0.0)
        end)
    end
    local function place(k, phi, ctrl)                   -- (v101) k 0..1 into the stance, phi deg tipped nose-down from it
        local L = DI.L
        return tonumber(HJN_BoardStance(DI.hang, DI.pitch, S.DropInTail, S.DropInKick, L.lip, L.ox, L.oy, L.x, L.y, L.top, k, phi, ctrl and 1 or 0)) or 0
    end

    -- Y / triangle
    NATIVE.dropKey = function()
        -- (v123) a second tap of Y while the board is still being set out = you want on in SWITCH (the game's own throwdown
        -- does that by itself; on the dropped quarter pipe it fails and the mod's own mount took no notice of the tap)
        if DI.state == "mount" and not DI.sw and os.clock() - (DI.t0 or 0) < 0.6 then
            DI.sw = true
            log("drop-in: Y tapped again -- you will be put on in SWITCH")
            return
        end
        if S.DropIn == 0 or DI.state or active then return end
        if type(HJN_Ledge) ~= "function" or type(HJN_BoardStance) ~= "function" or type(HJN_BoardMeet) ~= "function" or not NATIVE.live then return end
        if not refs() then return end
        local cm = modeNow()
        if q(function() return s0:IsOnBoard() end, false) == true or (cm ~= 0 and cm ~= MODE_TO_BOARD) then return end   -- the press that gets you ON, only
        -- (v102) standing still, on the ground: a press while walking, running or in a jump is the game's own throwdown
        local vel = q(function() return mv.Velocity end)
        local sp = vel and math.sqrt((tonumber(vel.X) or 0) ^ 2 + (tonumber(vel.Y) or 0) ^ 2) or 0
        -- (v180) ...AND BY HOW FAST YOU REALLY MOVE. "The drop in mechanic still seems to be firing when the player is moving."
        -- 5 Oct 00:05:20: SessionTweaks had just turned a bail into a run-out (911 cm/s kept) and the movement component's
        -- Velocity read 0 for half a second -- 'standing still', so the drop-in set you 267 cm back and turned you round.
        -- The native half measures the mesh's own travel over the ground; over 20 cm/s is moving whatever Velocity says.
        do
            local real = type(HJN_MeshSpeed) == "function" and tonumber(HJN_MeshSpeed()) or -1
            if real > math.max(S.DropInStillSpeed, 20) and real > sp then sp = real end
        end
        local jumping = q(function() return mv:IsFalling() end, false) == true
        if jumping or sp > S.DropInStillSpeed then                                    -- (v166) a standstill (it was 40 cm/s)
            log(string.format("Y on foot: %s -- no drop-in (stand still by the edge for one); the game's own throwdown%s",
                jumping and "you are in the air" or string.format((sp < 10) and "you are moving at %.2f cm/s" or "you are moving at %.0f cm/s", sp), NATIVE.heldNote()))
            return
        end
        -- (v180, review) ...AND ONLY WITH THE BOARD IN YOUR HAND, NOT JUST PICKED UP. What "firing while I am moving" was, by
        -- SessionTweaks.log of 5 Oct: with the board in your hand (board mode 5) Y is the game's throwdown (5 -> 6 -> you are on
        -- 0.6-1.5 s later: the three drop-ins of 00:12-00:13); with the board lying where a fall left it (mode 8) Y only PICKS IT
        -- UP (8 -> 5, 0.22 s after the press, nobody is mounted) and you press Y again 0.6-0.9 s later (00:05:22.09 / :22.69,
        -- 00:06:20.35 / :21.28, 00:12:47.29 / :48.19). At 00:05:20.69 -- 0.6 s after a run-out, at rest (SessionTweaks' own
        -- trace: speed 0 for the half second before; its 911 cm/s is the run-out AFTER this drop-in began), 0 cm from an edge --
        -- that pick-up press was taken for a drop-in: stepped back 65 cm, and as the game threw nothing down the mod's own
        -- mount put you on half a second later, where the BOARD lay, 267 cm off, and the first move dragged you back. The same
        -- in the five of 4 Oct (20:09:42, 20:40:18, 22:27:34, 22:27:49, 22:30:53: each seconds after a fall, "the game's
        -- throwdown did not mount you (board in your hand)", moved 22-174 cm, four of them off the board or bailed). None of
        -- the 31 drop-ins that worked in those logs came this way: the game's own throwdown mounted every one of them.
        -- So: no drop-in on a press made while the board lies loose (its mode is read before the game acts on the press), nor
        -- for 1.5 s after it last did -- that second press is your way back onto the board after a fall, the game's own.
        do
            local bs = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            local loose = bs >= 0 and ((bs >> 4) & 0xff) == 8
            if loose or (DI.looseAt and os.clock() - DI.looseAt < 1.5) then
                log(string.format("Y on foot: %s -- no drop-in; the game's own way back onto the board (for a drop-in: the board in your hand, stand still by the edge, Y)%s",
                    loose and "the board is not in your hand (it lies loose, board mode 8): this press picks it up"
                           or string.format("the board lay loose %.1f s ago (just picked up after a fall)", os.clock() - DI.looseAt), NATIVE.heldNote()))
                return
            end
        end
        local rot = q(function() return s0:K2_GetActorRotation() end)
        local yaw = rot and q(function() return rot.Yaw end, nil)
        -- (v112) the native look is told which way you face and prefers a drop within DropInFace of it: on a dropped quarter
        -- pipe's small deck the back edge is the NEARER drop, and the old nearest-first look never gave the transition a go
        -- (v113) the floor the game stands you on and its collision object type: a dropped quarter pipe is a physics object,
        -- which none of our looks saw (v49's wide look found our own skater first and gave up)
        local base = q(function() return s0.BasedMovement.MovementBase end)
        local gtype = base and tonumber(q(function() return base:GetCollisionObjectType() end)) or -1
        if base then log(string.format("drop-in:    standing on %s (collision object type %s)", tostring(q(function() return base:GetFullName() end, "?")), tostring(gtype))) end
        local L, why = parseLedge(HJN_Ledge(S.DropInRange, S.DropInMinDrop, yaw or 0, S.DropInFace, gtype))
        if not L then log("Y on foot: no drop-in here (" .. tostring(why) .. ") -- the game's own throwdown" .. NATIVE.heldNote()) return end
        -- (v185) A BANK IS FACED BY ITS OWN SLOPE. "Some of the drop-ins on banks ... he aligns off perpendicular. He might be
        -- 30 degrees off." Where the flat runs into a bank there is no sharp edge for the rays to follow: on the 17 deg bank
        -- of 5 Oct 17:32:33 the edge's fitted line turned 'out' to 24 deg where the bank's face runs down at 70 (the same bank
        -- at 17:35:12: 70.5, and square). The face the front wheels will meet says which way is down: its normal's level part.
        -- Taken where that face is a slope (8-80 deg) and lies within 60 deg of the way the look found.
        if L.slope and L.slope >= 8 and L.slope <= 80 and L.nx and L.ny then
            local h = math.sqrt(L.nx * L.nx + L.ny * L.ny)
            if h > 0.1 then
                local nx, ny = L.nx / h, L.ny / h
                local d = nx * L.ox + ny * L.oy
                if d > 0.5 and d < 0.9986 then
                    log(string.format("drop-in:    the edge was found facing %.0f deg, the %.0f deg slope below it runs down toward %.0f deg -- the slope's way is taken (%.0f deg apart)",
                        math.deg(math.atan(L.oy, L.ox)), L.slope, math.deg(math.atan(ny, nx)), math.deg(math.acos(d))))
                    L.ox, L.oy = nx, ny
                end
            end
        end
        -- (v102) how far off square to the edge you face: 0 = straight at the drop, 90 = along the edge, 180 = away from it
        local off = yaw and math.deg(math.acos(math.max(-1, math.min(1, math.cos(math.rad(yaw)) * L.ox + math.sin(math.rad(yaw)) * L.oy)))) or 0
        -- (v175) 'off' is measured to the edge's TRUE line now (native v91: until then a drop found at the rim of your facing
        -- cone was taken to face the way that one ray pointed, so facing 46 deg off read as 26). The look itself only takes
        -- a drop inside DropInFace of where you face; what is refused here is an edge that runs nearly ALONG your facing.
        if S.DropInFace > 0 and off > math.min(80, S.DropInFace + 30) then
            log(string.format("Y on foot: an edge %.0f cm away, but you face %.0f deg off square to it (DropInFace %g) -- the game's own throwdown", L.dist, off, S.DropInFace))
            return
        end
        DI.state, DI.L, DI.t0, DI.rideAt, DI.tries, DI.tryAt, DI.hang, DI.pitch, DI.pulled, DI.held, DI.ground = "mount", L, os.clock(), nil, 0, nil, S.DropInHang, S.DropInPitch, false, nil, nil
        DI.sw, DI.boosted, DI.nb0 = nil, nil, nil
        myAddr = addr(s0)
        ensureHook()
        -- (v103) THE GAME'S THROWDOWN NEEDS ROOM: it throws the board out ahead of you and bails when that spot is past the
        -- edge (from 57 cm back it landed, from 50 it bailed; v102's hold of the board on the ledge only made it bail on its
        -- first tick and flung the board). So you are set DropInStart cm back from the edge first, facing as you were.
        if S.DropInStart > 0 and L.dist < S.DropInStart then
            local loc = q(function() return s0:K2_GetActorLocation() end)
            local bx, by = L.x - L.ox * S.DropInStart, L.y - L.oy * S.DropInStart
            local moved = loc and pcall(function() s0:K2_SetActorLocation({ X = bx, Y = by, Z = loc.Z }, false, {}, true) end)
            log(string.format("drop-in:    stepped back from %.0f to %.0f cm from the edge for the game's throwdown (%s)", L.dist, S.DropInStart, moved and "ok" or "FAILED"))
        end
        log(string.format("DROP-IN: an edge %.0f cm from you (you face %.0f deg off square to it), the ground %.0f cm down just past it, %.0f cm down further out (slope there %.0f deg), "
            .. "a lip of %.1f cm on the edge -- waiting for the game to put you on the board", L.dist, off, L.near, L.far, L.slope, L.lip))
    end

    NATIVE.dropBusy = function() return DI.state ~= nil and DI.state ~= "ride" end   -- (v106) the ride monitor after a drop-in does not block clicks
    NATIVE.dropTick = function(now)
        if type(HJN_BoardState) == "function" then       -- (v180, review) the board's own movement mode 8 = it lies loose (a fall, a failed throwdown): see dropKey
            local bs = tonumber(HJN_BoardState()) or -1
            if bs >= 0 and ((bs >> 4) & 0xff) == 8 then DI.looseAt = now end
        end
        if DI.trace and now >= DI.trace.nxt then          -- (v187)
            local T = DI.trace
            T.nxt = now + 0.25
            local vel = q(function() return mv.Velocity end, nil)
            log(string.format("drop-in:    ride +%.2f s: mode %s, the game's speed %.0f cm/s, moving %.0f cm/s over the ground (down %.0f), deck %s",
                now - T.t0, tostring(modeNow()), tonumber(q(function() return mv:GetCurrentSpeed() end, -1)) or -1,
                type(HJN_MeshSpeed) == "function" and tonumber(HJN_MeshSpeed()) or -1, vel and -(tonumber(vel.Z) or 0) or 0, DI.pitchNow()))
            if now - T.t0 > 4 then DI.trace = nil end
        end
        local st = DI.state
        if not st then return end
        if not alive(s0) then letGo("the skater is gone") return end
        local cm, L = modeNow(), DI.L
        if st == "mount" then
            if now - DI.t0 > 6 then letGo("no way onto the board within 6 s -- nothing done") return end
            if cm == MODE_RIDING and q(function() return s0:IsOnBoard() end, false) == true then
                DI.rideAt = DI.rideAt or now
                if now - DI.rideAt < 0.15 then return end
                local x, y, z = L.x - L.ox * S.DropInBack, L.y - L.oy * S.DropInBack, L.top + 90
                -- (v104) a double tap of Y put you on in SWITCH: the game has a switch rider face AWAY from the board's nose (the
                -- board hop's rule), so square to the edge means facing away from the drop -- the nose still points at it
                local sw = DI.sw == true or q(function() return s0:IsSkatingSwitch() end, false) == true   -- (v123)
                local yaw, sk = math.deg(math.atan(L.oy, L.ox)) + (sw and 180 or 0), s0
                -- (v175) THE FIRST MOVE IS A MOVE. "There's an initial alignment move that snaps the board roughly perpendicular to
                -- the coping. That move is incredibly fast and jarring -- triple or quadruple the time it takes." It was one
                -- teleport. Now the same place and heading are reached over DropInAlignTime seconds, eased, a small step a frame
                -- (at the height you stand at: the ledge is level between the two places).
                do
                    local loc0, rot0 = q(function() return sk:K2_GetActorLocation() end), q(function() return sk:K2_GetActorRotation() end)
                    local x0, y0, z0 = loc0 and q(function() return loc0.X end), loc0 and q(function() return loc0.Y end), loc0 and q(function() return loc0.Z end)
                    local yaw0 = rot0 and q(function() return rot0.Yaw end)
                    -- (v180) more than 1.5 m from the spot by the time you are on the board = you were moving (or the game put you
                    -- on somewhere else): nothing is done, you ride on
                    if x0 and y0 and math.sqrt((x - x0) ^ 2 + (y - y0) ^ 2) > 150 then
                        letGo(string.format("you were %.0f cm from the edge's spot by the time you were on the board (you were moving) -- nothing done", math.sqrt((x - x0) ^ 2 + (y - y0) ^ 2)))
                        return
                    end
                    local T = S.DropInAlignTime or 0
                    if T > 0.03 and x0 and y0 and z0 and yaw0 then
                        DI.state, DI.t0 = "align", now
                        DI.al = { x0 = x0, y0 = y0, z0 = z0, yaw0 = yaw0, x = x, y = y, dyaw = ((yaw - yaw0 + 540) % 360) - 180, yaw = yaw, T = T, sw = sw }
                        return
                    end
                end
                DI.state, DI.t0 = "set", now
                NATIVE.gt(function()                -- (outside the animation update, like the bail return)
                    local ok, res = pcall(function() return sk:K2_TeleportTo({ X = x, Y = y, Z = z }, { Pitch = 0.0, Yaw = yaw, Roll = 0.0 }) end)
                    log(string.format("drop-in: stood square to the edge, the board's middle %.0f cm back from it, heading %.0f%s -> %s", S.DropInBack, yaw,
                        sw and " (riding SWITCH: you face away from the drop, the nose points at it)" or "",
                        ok and tostring(res) or ("FAILED: " .. tostring(res))))
                    if not ok then letGo("the teleport failed") end
                end)
                return
            end
            DI.rideAt = nil
            -- (v99) BY AN EDGE THE GAME'S OWN THROWDOWN MOSTLY FAILS: it throws the board out over the drop and bails
            -- (the v98 log: board mode 5 -> 6 -> 8 within 0.4 s, "bail from ... PhysThrowdown"; the drop-in then only
            -- went on when you clicked the sticks = the mod's board hop mounted you). So once the game is done with the
            -- board and you are still on foot, the mod mounts you itself, the board hop's way: the board set down on the
            -- ledge (if it lies loose), you stood over it, the game told to mount you where the board is.
            if cm ~= 0 or now - DI.t0 < 0.5 or (DI.tryAt and now - DI.tryAt < 1.2) or (DI.tries or 0) >= 3 then return end
            if type(HJN_BoardState) ~= "function" or type(HJN_BoardMount) ~= "function" or type(HJN_BoardPut) ~= "function" then return end
            local bs = tonumber(HJN_BoardState()) or -1
            if bs < 0 or (bs & 4) ~= 0 or (bs & 8) ~= 0 then return end   -- no board / riding / the game is busy with it
            DI.tries, DI.tryAt = (DI.tries or 0) + 1, now
            local x, y = L.x - L.ox * S.DropInBack, L.y - L.oy * S.DropInBack
            local yaw, sk, loose, try = math.deg(math.atan(L.oy, L.ox)), s0, (bs & 1) ~= 0, DI.tries
            NATIVE.gt(function()
                local put = 0
                if loose then
                    local parts = boardParts()
                    local took = parts and tonumber(HJN_BoardParts(table.unpack(parts))) or 0
                    put = (took > 0) and (tonumber(HJN_BoardPut(x, y, L.top + 12, yaw)) or 0) or 0
                    pcall(HJN_BoardParts)
                end
                local moved = pcall(function() sk:K2_SetActorLocationAndRotation({ X = x, Y = y, Z = L.top + 95 }, { Pitch = 0, Yaw = yaw, Roll = 0 }, false, {}, true) end)
                local okm = tonumber(HJN_BoardMount(DI.sw and 1 or 0, 0)) == 1   -- (v123) switch when Y was tapped twice
                local okp = okm and pcall(function() sk:SetPendingApplyToggleOnBoard() end)
                log(string.format("drop-in: the game's throwdown did not mount you (board %s) -- the mod's own mount, try %d: board set on the ledge %s, you stood over it %s, mount %s",
                    loose and "lying loose" or "in your hand", try, loose and (put .. " parts") or "(not needed)", moved and "ok" or "FAILED",
                    okp and "asked of the game" or (okm and "call FAILED" or "refused by the native half")))
                -- (v103) the throwdown's sound, as the game's own would -- (v114) but NOT when the game's throwdown already threw the board
                -- and it landed loose (its own impact played): on the dropped quarter pipe that doubled the sound on every drop-in
                if okp and S.DropInSounds ~= 0 and not loose then playSound(S.DropInStartSound, S.DropInSoundVolume) end
                if okm and not okp and type(HJN_BoardRagdoll) == "function" and loose then HJN_BoardRagdoll() end
            end)
            return
        end
        if cm == MODE_BAILING then letGo("the game bailed you") return end
        if st == "align" then                             -- (v175) the first move, a step a frame
            local A = DI.al
            if not A then DI.state, DI.t0 = "set", now return end
            local k = math.min(1, (now - DI.t0) / A.T)
            local e = k * k * (3 - 2 * k)
            local x, y, yaw, sk, last = A.x0 + (A.x - A.x0) * e, A.y0 + (A.y - A.y0) * e, A.yaw0 + A.dyaw * e, s0, k >= 1
            if last then DI.state, DI.t0, DI.al = "set", now, nil end
            NATIVE.gt(function()
                local ok, res = pcall(function() return sk:K2_TeleportTo({ X = x, Y = y, Z = A.z0 }, { Pitch = 0.0, Yaw = yaw, Roll = 0.0 }) end)
                if last then
                    log(string.format("drop-in: stood square to the edge over %.2f s (turned %+.0f deg, moved %.0f cm), the board's middle %.0f cm back from it, heading %.0f%s -> %s",
                        A.T, A.dyaw, math.sqrt((A.x - A.x0) ^ 2 + (A.y - A.y0) ^ 2), S.DropInBack, A.yaw,
                        A.sw and " (riding SWITCH: you face away from the drop, the nose points at it)" or "", ok and tostring(res) or ("FAILED: " .. tostring(res))))
                    if not ok then letGo("the teleport failed") end
                end
            end)
            return
        end
        if st == "set" then
            if now - DI.t0 < 0.3 then return end
            if cm ~= MODE_RIDING then
                if now - DI.t0 > 3 then letGo("not riding 3 s after the teleport (mode " .. tostring(cm) .. ")") end
                return
            end
            local parts = boardParts()
            local took = parts and tonumber(HJN_BoardParts(table.unpack(parts))) or 0
            local cap = (took > 0) and (tonumber(HJN_BoardCapture()) or 0) or 0
            if cap < 1 then letGo(string.format("the board's parts were not found (%d named, %d taken, %d captured)", parts and #parts or 0, took, cap)) return end
            local dz = tonumber((tostring(type(HJN_DeckWorld) == "function" and HJN_DeckWorld() or ""):match("^%S+ %S+ (%S+)")))
            DI.state, DI.t0, DI.k, DI.phi, DI.parts, DI.modeWas = "out", now, 0, 0, cap, cm
            DI.ground = (type(HJN_GroundHold) == "function" and tonumber(HJN_GroundHold(1)) == 1) or nil
            log(string.format("drop-in: %d board parts taken; the deck stands %s cm over the ledge; the game %s", cap, dz and string.format("%.1f", dz - L.top) or "?",
                DI.ground and "is told the board is grounded while it is held" or "keeps its own grounded check (the hold is off)"))
            return
        end
        if st == "ride" then                              -- let go: what the game makes of it
            if now - DI.t0 < 0.3 then sticksCentred() end
            if DI.ground and DI.holdUntil and now >= DI.holdUntil then   -- (v138/v139) the vert's grounded hold given back after the quarter second
                DI.ground, DI.holdUntil = nil, nil pcall(HJN_GroundHold, 0)
                log(string.format("drop-in:    the grounded hold given back %.2f s after the let-go (mode %s)", now - DI.t0, tostring(cm)))
            end
            if cm ~= DI.modeWas then
                log(string.format("drop-in:    %.2f s after letting go: mode %s -> %s, deck pitch %s, speed %.0f cm/s", now - DI.t0, tostring(DI.modeWas), tostring(cm),
                    DI.pitchNow(), tonumber(q(function() return mv:GetCurrentSpeed() end, -1)) or -1))
                DI.modeWas = cm
            end
            -- (v176) a vert drop: for the first 0.7 s the body's own touches cannot bail you (the wheels fall free to the wall with
            -- the coping at your back; the game's impact check needs no force at all in the air). The board's own bails still run.
            if DI.vert and type(HJN_Set) == "function" and type(HJN_NoBail) == "function" then
                local _, sk = tostring(HJN_NoBail() or ""):match("^(%-?%d+) (%d+)")
                DI.nb0 = DI.nb0 or tonumber(sk) or 0
                DI.nbNow = tonumber(sk) or DI.nb0
                if now - DI.t0 < 0.7 then pcall(HJN_Set, "nobail", 0.15) end
            end
            if now - DI.t0 < 1.5 then
                -- (v147) THE VERT'S BOOST: the let-go is slow so the wheels meet the wall; once they ride it, the speed the
                -- user set is added down the wall (the met-wall drop-ins get their boost at the let-go: this one could not)
                if DI.vert and not DI.boosted and now - DI.t0 > 0.3 and cm == MODE_RIDING and S.DropInVertBoost > 0 and NATIVE.boardParts and type(HJN_BoardKick) == "function" then
                    DI.boosted = true
                    local vel = q(function() return mv.Velocity end, nil)
                    local vx, vy, vz = vel and (tonumber(vel.X) or 0) or 0, vel and (tonumber(vel.Y) or 0) or 0, vel and (tonumber(vel.Z) or 0) or 0
                    local sp = math.sqrt(vx * vx + vy * vy + vz * vz)
                    -- (v149) ALONG THE DECK. v147/v148 boosted along the velocity, and with the board at rest on the wall (both
                    -- logged boosts read 0 cm/s) fell back to 45 deg out and down: 350 cm/s straight AWAY from the wall ("once the
                    -- wheels hit the wall, it pushes the whole skater away"). The board lies on the wall: its long axis, the end
                    -- that points down, IS down the wall (also on a wall that leans back under the coping), and a little of the
                    -- deck's underside direction presses the wheels onto it. No deck read = straight down, never outward
                    local dx, dy, dz, how = 0, 0, -1, "straight down (the deck could not be read)"
                    local ax = tostring(type(HJN_DeckAxes) == "function" and HJN_DeckAxes() or "")
                    local fx, fy, fz, ux, uy, uz = ax:match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+)")
                    fx, fy, fz, ux, uy, uz = tonumber(fx), tonumber(fy), tonumber(fz), tonumber(ux), tonumber(uy), tonumber(uz)
                    if fx and uz then
                        local sgn = (fz < -0.2) and 1 or ((fz > 0.2) and -1 or (((fx * L.ox + fy * L.oy) >= 0) and 1 or -1))
                        local px, py, pz = fx * sgn - ux * 0.15, fy * sgn - uy * 0.15, fz * sgn - uz * 0.15
                        local pn = math.sqrt(px * px + py * py + pz * pz)
                        if pn > 1e-3 then
                            dx, dy, dz = px / pn, py / pn, pz / pn
                            -- (v176) ...AND NONE OF IT AWAY FROM THE WALL. "Some pretty vanilla, straightforward drop-ins bail." Two
                            -- of the six of 20:13-20:15, all square to the same wall: both went from riding to off the board 0.04 s
                            -- after this boost. The deck lies 67-69 deg off level on a wall that is 79 deg steep, so 'along the deck'
                            -- read '0.97 down, 0.24 OUT from the wall': 190 cm/s of the 800 straight away from it -- the wheels came
                            -- off, and in the air any touch of the body on the coping bails. What points away from the wall is taken
                            -- out and a little pressed INTO it (0.08).
                            local outw = dx * L.ox + dy * L.oy
                            -- (v187) ...ONLY WHILE THE DECK STANDS STEEP. "Every time I get to the bottom of the vert ramp, his velocity
                            -- would go almost to zero." FDR's ramp is 2.9 m of wall, then a transition: 0.3 s after the let-go the deck
                            -- already lay 17-45 deg off level on that curve, pointing 0.6-0.9 OUT from the wall -- and with all of that
                            -- 'out' taken away the boost came down as 0.97-1.00 straight DOWN: 12 m/s driven into the transition, 2.6-6
                            -- left of it a second later. Over 53 deg the wall rule holds; flatter, the boost goes the way the deck
                            -- points, which is along the ramp.
                            if math.abs(fz) > 0.8 and outw > -0.08 then
                                dx, dy = dx - (outw + 0.08) * L.ox, dy - (outw + 0.08) * L.oy
                                local n2 = math.sqrt(dx * dx + dy * dy + dz * dz)
                                if n2 > 1e-3 then dx, dy, dz = dx / n2, dy / n2, dz / n2 end
                            end
                            how = string.format("along the deck, none of it away from the wall (%.2f down, %.2f out from the wall; the deck %s; it lay %.2f out)", -dz, dx * L.ox + dy * L.oy, DI.pitchNow(), outw)
                        end
                    end
                    local parts = NATIVE.boardParts()
                    local took = parts and tonumber(HJN_BoardParts(table.unpack(parts))) or 0
                    local n = 0
                    if took > 0 then n = tonumber(HJN_BoardKick(vx + dx * S.DropInVertBoost, vy + dy * S.DropInVertBoost, vz + dz * S.DropInVertBoost, 0, L.ox, L.oy)) or 0 end
                    pcall(HJN_BoardParts)
                    log(string.format("drop-in:    on the wall %.2f s after the let-go at %.0f cm/s -> boosted %.0f cm/s %s (%d parts)", now - DI.t0, sp, S.DropInVertBoost, how, n))
                end
                if not DI.pushed and now - DI.t0 > 0.45 and S.DropInPush ~= 0 and cm == MODE_RIDING then
                    local sp = tonumber(q(function() return mv:GetCurrentSpeed() end, -1)) or -1
                    if sp >= 0 and sp < 40 then
                        DI.pushed = true
                        log(string.format("drop-in:    too slow (%.0f cm/s) -> one push: %s", sp, pcall(function() s0:Push() end) and "ok" or "FAILED"))
                    end
                end
                return
            end
            log(string.format("drop-in: 1.5 s on -- mode %s, speed %.0f cm/s, deck pitch %s%s", tostring(cm),
                tonumber(q(function() return mv:GetCurrentSpeed() end, -1)) or -1, DI.pitchNow(),
                (DI.vert and DI.nb0) and string.format("; %d body hits passed over in the first 0.7 s", (DI.nbNow or DI.nb0) - DI.nb0) or ""))
            DI.state = nil
            return
        end
        -- from here the board is held, every frame -- riding or, as the game sees it once the wheels hang free, in the air
        -- (v98 let go the moment the game said "air": the pivot never ran and you came off the ledge flat)
        if cm ~= MODE_RIDING and cm ~= MODE_AIR and cm ~= MODE_TO_BOARD and cm ~= -1 then
            letGo("you are off the board (mode " .. tostring(cm) .. ") -- the board is let go")
            return
        end
        if cm ~= DI.modeWas and cm ~= -1 then
            log(string.format("drop-in:    held (%s, %.0f%% into the stance, tipped %.0f deg): the game's mode %s -> %s%s", st, (DI.k or 0) * 100, DI.phi or 0,
                tostring(DI.modeWas), tostring(cm), (q(function() return inst.IsGrinding end, false) == true) and " (the game says GRINDING)" or ""))
            DI.modeWas = cm
        end
        sticksCentred()
        local function eased(t) local k = math.min(1, (now - DI.t0) / math.max(0.05, t)) return k, k * k * (3 - 2 * k) end
        -- (v101) WAITING, THE GAME MUST GO ON SEEING YOU RIDE: once it thinks the board is in the air any touch of your legs on
        -- the ledge bails you. The tail down on the ledge should keep it riding (the game checks the deck's tail for ground
        -- as it does a wheel). Should it say "air" all the same, the board is drawn back a quarter cm a frame until the
        -- back wheels sit on the edge, and stays there.
        if (st == "out" or st == "wait") and cm == MODE_AIR and (DI.k or 0) >= 1 then
            DI.hang = math.max(-1, DI.hang - 0.25)
            if not DI.pulled then DI.pulled = true log("drop-in:    the game took the held board for airborne -- drawing it back until it rides again") end
        end
        if st == "out" then
            local k, e = eased(S.DropInSetTime)
            DI.k, DI.phi = e, 0
            local n = place(e, 0)
            if n < 1 then letGo("the native half could not move the board") return end
            if k >= 1 then
                DI.state, DI.t0 = "wait", now
                log(string.format("drop-in: SET -- %d board parts: the back wheels hung %.1f cm past the edge, the tail down on the ledge, the deck up %.0f deg. Stick UP = drop in, LB/RB = back, Y = off", n, DI.hang, DI.pitch))
                if S.DropInSounds ~= 0 then playSound(S.DropInSetSound, S.DropInSoundVolume) end   -- (v104) the tail down: the cue to push the stick
            end
            return
        end
        if st == "wait" then
            if place(1, 0) < 1 then letGo("the native half let the board go") return end
            if now - DI.t0 < 0.3 then return end
            local _, ly = NATIVE.stickNow("Left", now)
            local _, ry = NATIVE.stickNow("Right", now)
            if (tonumber(HJN_Bumpers()) or 0) ~= 0 then
                DI.state, DI.t0 = "back", now
                log("drop-in: LB/RB -- back onto the ledge")
            elseif math.max(ly or 0, ry or 0) > 0.6 then
                -- (v101) the way down traced now, from the stance as it stands: the front wheels' bottoms and the nose swung
                -- about the hung back axle, a degree at a time, until one meets the ground (v100 took the angle from chords
                -- of a guessed circle: the wheels ended 10 cm inside the ramp and the board stuck fast)
                local meet, pu, slope = HJN_BoardMeet(DI.hang, DI.pitch, S.DropInTail, S.DropInKick, L.lip, L.ox, L.oy, L.x, L.y, L.top, S.DropInMaxSlope + DI.pitch)
                meet, DI.pitch, slope = tonumber(meet) or -1, tonumber(pu) or DI.pitch, tonumber(slope) or 0
                -- (v102) the floor below a plain ledge is "met" too, 40-odd degrees down: only ground steeper than
                -- DropInRampSlope is a ramp to pivot onto (v101 planted the nose into the floor below a 40 cm ledge)
                local ramp = meet >= 1 and slope >= S.DropInRampSlope
                -- (v139) THE WHEELS MUST MEET THE WALL. As hung (the back wheels 4 cm past the edge) the front wheels' arc passed
                -- a vert wall 4 cm behind them and met nothing (v137's "vert" then let the board fall free to the wall: a
                -- hiccup as the game went to air and back). Now the way down is traced again with the board hung further and
                -- further out, 6 cm at a time, until the wheels DO meet ground steep enough; the board slides out to that
                -- hang as it tips and is let go the moment the wheels touch -- on any ledge, not only a vert
                DI.hangTo, DI.hang0 = nil, DI.hang
                if not ramp then
                    for _, h in ipairs({ 10, 16, 22, 28, 34, 40 }) do
                        local m2, pu2, sl2 = HJN_BoardMeet(h, DI.pitch, S.DropInTail, S.DropInKick, L.lip, L.ox, L.oy, L.x, L.y, L.top, S.DropInMaxSlope + DI.pitch)
                        m2, sl2 = tonumber(m2) or -1, tonumber(sl2) or 0
                        if m2 >= 1 and sl2 >= S.DropInRampSlope then
                            meet, slope, ramp, DI.hangTo = m2, sl2, true, h
                            log(string.format("drop-in: hung %.0f cm past the edge the front wheels would meet the ground %.0f deg down the way (%.0f deg steep there); the board slides out to that as it tips", h, m2, sl2))
                            break
                        end
                    end
                end
                -- (v137) A VERT WALL (FDR's coping'd quarters): just past the edge the ground is far down (75 cm at FDR) and
                -- further out further still, yet the front wheels swung about the hung axle met nothing within 114 deg -- the
                -- wall is right under the coping, 4 cm behind their arc. v98-v136 took that for "a straight drop": 15 deg
                -- nose-down with the full boost, and you launched out over the wall. Now it is a VERT drop-in: tipped steep,
                -- let go slowly, kept tipping, so the wheels meet the wall and the wall gives the speed
                local vert = (not ramp) and (L.near or 0) >= S.DropInVertDrop and (L.far or 0) >= 90
                DI.state, DI.t0, DI.ramp, DI.vert = "in", now, ramp, vert
                DI.down = ramp and meet or (DI.pitch + (vert and S.DropInVertTilt or S.DropInTilt))
                log(string.format("drop-in: GO (stick %.2f) -- %s", math.max(ly or 0, ry or 0),
                    ramp and string.format("the board tips %.0f deg nose-down about its back wheels, to %.0f deg below level, where its front wheels meet the ramp (%.0f deg steep there)", DI.down, DI.down - DI.pitch, slope)
                          or (vert and string.format("a VERT wall (%.0f cm down just past the edge, %.0f further out, nothing for the wheels to pivot onto): it tips to %.0f deg nose-down, goes slowly and keeps tipping", L.near or 0, L.far or 0, DI.down - DI.pitch))
                          or string.format("a straight drop%s: it tips to %.0f deg nose-down and goes",
                                (meet >= 1) and string.format(" (the ground the wheels would meet is only %.0f deg steep)", slope) or "", DI.down - DI.pitch)))
            end
            return
        end
        if st == "back" then
            local k, e = eased(S.DropInSetTime)
            DI.k = 1 - e
            if place(1 - e, 0) < 1 then letGo("the native half let the board go") return end
            if k >= 1 then letGo("back on the ledge -- the board is yours") end
            return
        end
        if st == "in" then
            local k = math.min(1, (now - DI.t0) / math.max(0.05, DI.ramp and S.DropInTime or 0.6 * S.DropInTime))
            DI.phi = DI.down * k * k                          -- (it starts slowly and falls in)
            -- about the hung back axle, the game's board controller turned with the board (v99 let go of a board 56 deg
            -- down whose controller was still level -- the game had it level again 0.13 s later and bailed you)
            if DI.hangTo then DI.hang = DI.hang0 + (DI.hangTo - DI.hang0) * math.min(1, k * 2) end   -- (v139) out to the hang the wheels meet from, over the first half of the tip
            if place(1, DI.phi, true) < 1 then letGo("the native half let the board go") return end
            if k < 1 then return end
            -- let go: the game's own grounded check back, then a little speed the way the board points; over a straight drop still tipping forward
            if DI.ground and not DI.vert then DI.ground = nil pcall(HJN_GroundHold, 0) end   -- (v138) a vert keeps the hold a moment: the wheels fall free to the wall
            DI.holdUntil = DI.vert and (now + 0.25) or nil
            if S.DropInSounds ~= 0 then playSound(S.DropInEndSound, S.DropInSoundVolume) end        -- (v103) the board's tap as it goes
            local a, v, spin = math.rad(DI.down - DI.pitch), DI.vert and S.DropInVertSpeed or S.DropInSpeed, DI.vert and math.min(S.DropInVertSpin, math.max(0, 92 - (DI.down - DI.pitch)) / 0.3) or (DI.ramp and 0 or S.DropInSpin)   -- (v137/v147) vert: the spin that brings the nose to 90 deg in 0.3 s and no more (150 deg/s took a 290 cm wall's board to 126 deg: off the far side)
            local back = DI.vert and S.DropInVertBack or 0                       -- (v140) a vert: pushed back toward the wall so the wheels meet it instead of falling free
            local kicked = tonumber(HJN_BoardKick(L.ox * (math.cos(a) * v - back), L.oy * (math.cos(a) * v - back), -math.sin(a) * v, spin, L.ox, L.oy)) or 0
            pcall(HJN_BoardParts)
            DI.state, DI.t0, DI.pushed, DI.modeWas = "ride", now, false, cm
            DI.trace = { t0 = now, nxt = now + 0.25 }      -- (v187) what the ride makes of it, four times a second for 4 s
            log(string.format("drop-in: let go %.0f deg nose-down with %.0f cm/s along the board, tipping on at %.0f deg/s (%d parts; the game's mode %s)",
                DI.down - DI.pitch, v, spin, kicked, tostring(cm)))
            return
        end
    end
end

-- (v137) THE NO COMPLY. The game ships a no-comply animation it never uses (BLD_RGS_NoComply). The NoComplyWayBetter mod
-- wired it into the Pressure Kickflip's trick definition with loose cooked files (two replaced assets); this does the same
-- to the loaded definitions at run time, with that mod's numbers as the ini defaults and every one of them tunable, and
-- puts the game's own numbers back when NoComply is switched off. The parts that mod left at the class defaults (the flip
-- and scoop data, the pop curves, the board-control and catch numbers) are taken from the class default object the same way
-- (v148) KEPT FOR THE WHOLE RUN. The engine's garbage collector did not count the reference the wiring adds: BLD_RGS_NoComply
-- (referenced by nothing else in the game) was freed about a minute after each wiring with the definition still pointing at
-- it -- "the no comply worked once, then broke" (a new skater wired a freshly loaded one, so it came back for a minute), and
-- reading that pointer was the UE4SS fault. Every object the wiring puts in, every object it takes out (NoComply=0 writes
-- them back) and the two definitions are rooted through the native half (UE4SS's SetRootSet = the engine's AddToRoot)
NATIVE.rooted = {}
NATIVE.root = function(o, what)
    o = alive(o)
    if not o or type(HJN_Root) ~= "function" then return false end
    local a = addr(o)
    if not a then return false end
    if NATIVE.rooted[a] then return true end
    local r = tostring(HJN_Root(a) or "")
    if r == "" then log("root: " .. tostring(what) .. " could NOT be rooted") return false end
    NATIVE.rooted[a] = true
    log("root: " .. tostring(what) .. " is kept for the whole run (" .. r .. ")")
    return true
end
NATIVE.noComply = { done = false, tries = 0, saved = {} }
NATIVE.noComplyApply = function()
    local NC = NATIVE.noComply
    -- (v146) NO PERIODIC SWEEP. v140-v145 read every FlipTrickDefinition in memory every 5 s to see whether the game had put the
    -- pressure kickflip back; each of the five UE4SS faults of 3 Oct fell on that cadence (the last one 5 s after the wiring
    -- with the trick names off). The wiring is done once per skater (a new skater wires again) and then left alone
    if NC.done or NC.tries >= 90 then return end
    local want = S.NoComply ~= 0
    if not want and not NC.applied then NC.done = true return end
    if want and type(HJN_Root) ~= "function" then                                   -- (v148)
        NC.done = true
        log("no comply: NOT wired -- it needs the native half v66 (the animation it puts into the game's trick has to be kept from the garbage collector)")
        return
    end
    -- (v147) BY PATH, never a sweep: StaticFindObject resolves a live object or nothing (FindAllOf over the 158 definitions
    -- handed back one that was gone -- the UE4SS faults of 3 Oct)
    local defs = {}
    for _, n in ipairs({ "TRICK_RGS_Pressure_KickFlip", "TRICK_SWS_Pressure_KickFlip" }) do
        local path = "/Game/Data/Input/FlipTricks/" .. n .. "." .. n
        local o = alive(q(function() return StaticFindObject(path) end))
        if not o then pcall(function() LoadAsset(path) end) o = alive(q(function() return StaticFindObject(path) end)) end
        if o then defs[n] = o NATIVE.root(o, n) end                                     -- (v148)
    end
    if not (defs.TRICK_RGS_Pressure_KickFlip and defs.TRICK_SWS_Pressure_KickFlip) then
        NC.tries = NC.tries + 1
        if NC.tries == 90 then log("no comply: the pressure kickflip definitions were not found in 3 minutes -- not wired") end
        return
    end
    local cdo = alive(q(function() return StaticFindObject("/Script/SessionGame.Default__FlipTrickDefinition") end))
    local function enumValue(path, suffix, fallback)
        local en = alive(q(function() return StaticFindObject(path) end))
        if en then
            for v = 0, 15 do
                local nm = q(function() return en:GetNameByValue(v):ToString() end, nil)
                if nm and nm:sub(-#suffix) == suffix then return v end
            end
        end
        return fallback
    end
    -- (v151) the keys of the definition's names-by-rotation map (the native half writes its texts)
    if not NC.rotKeys then
        local P = "/Script/SessionGame.EEventLineTrickRotationType"
        NC.rotKeys = { Frontside = enumValue(P, "ELTRT_Frontside", nil), Backside = enumValue(P, "ELTRT_Backside", nil),
                       Frontside360 = enumValue(P, "ELTRT_Frontside360", nil), Backside360 = enumValue(P, "ELTRT_Backside360", nil) }
        log(string.format("no comply: the rotation name keys -- FS %s, BS %s, FS 360 %s, BS 360 %s", tostring(NC.rotKeys.Frontside), tostring(NC.rotKeys.Backside),
            tostring(NC.rotKeys.Frontside360), tostring(NC.rotKeys.Backside360)))
    end
    local SCALAR = { "PopBoardForwardOffsetAlignRatioCurve", "PopBoardHeightOffsetCurve", "FirstInputAngleThreshold", "AdditionalPopHeightMax", "AdditionalPopHeightMin", "FlipInputSpeedMinMultiplier", "FlipInputSpeedMaxMultiplier",
                     "PopBoardForwardOffsetMin", "PopBoardForwardOffsetMax", "PopBoardHeightAdditionalOffsetMin", "PopBoardHeightAdditionalOffsetMax",
                     "ForceAutoCatch", "DefaultCatchFootType", "PopType", "IsPressureTrick",
                     "BoardControlExtraPitchDown", "BoardControlExtraPitchUp", "BoardControlExtraScoopBS", "BoardControlExtraScoopFS",
                     "BoardControlMaxSideMovementBS", "BoardControlMaxSideMovementFS", "CatchPitchAlignDelay", "CatchPitchAlignSmoothing",
                     "YawAlignMinCatchRatio", "CatchRollAlignSmoothing", "CatchManualFlipAngleThreshold", "CatchManualRotationAngleThreshold",
                     "BoardFlipPreCatchAngle", "BoardRotationPreCatchAngle", "OtherFootCatchTime" }
    local STRUCTS = { TrickFlipData = { "TargetAngleMin", "TargetAngleMax", "CatchManualFlipAxisRollAngle", "FlipSpeedModifierInput" },
                      TrickScoopData = { "RotationSpeedModifierInput", "BoardRotationEaseInSmoothing" },
                      TrickStartPitchData = { "TimeMin", "TimeMax", "TargetAngleMin", "TargetAngleMax" },
                      TrickEndPitchData = { "TimeMin", "TimeMax", "TargetAngleMin", "TargetAngleMax" },
                      AnimNotifiesMin = { "PopNotifyTime", "TrickStartPitchNotifyTime", "TrickEndPitchNotifyTime" },
                      AnimNotifiesMax = { "PopNotifyTime", "TrickStartPitchNotifyTime", "TrickEndPitchNotifyTime" },
                      LocalPivotOffset = { "X", "Y", "Z" } }
    local ANIMS = { "AnimSet", "AnimSet_AFXX" }
    local SETS = { "TrickBlendSpace", "TrickLoopBlendSpace", "CatchBlendSpace", "LandBlendSpace" }
    local function snapshot(def, name)
        local s = { scalar = {}, struct = {}, anim = {}, text = q(function() return def.DisplayName:ToString() end, nil) }
        for _, k in ipairs(SCALAR) do s.scalar[k] = q(function() return def[k] end, nil) end
        for sn, fields in pairs(STRUCTS) do s.struct[sn] = {} for _, k in ipairs(fields) do s.struct[sn][k] = q(function() return def[sn][k] end, nil) end end
        for _, an in ipairs(ANIMS) do s.anim[an] = {} for _, k in ipairs(SETS) do s.anim[an][k] = alive(q(function() return def[an][k] end)) end end
        -- (v148) what the wiring takes out is kept alive too, and the pop curves are held as objects or as "none"
        for _, an in ipairs(ANIMS) do for _, k in ipairs(SETS) do NATIVE.root(s.anim[an][k], name .. " " .. an .. "." .. k) end end
        s.none = {}
        for _, k in ipairs({ "PopBoardForwardOffsetAlignRatioCurve", "PopBoardHeightOffsetCurve" }) do
            local o = alive(s.scalar[k])
            s.scalar[k] = o or nil
            if o then NATIVE.root(o, name .. " " .. k) else s.none[k] = true end
        end
        NC.saved[name] = s
    end
    local function restore(def, name)
        local s = NC.saved[name]
        if not s then return 0 end
        local n = 0
        for k, v in pairs(s.scalar) do if v ~= nil and pcall(function() def[k] = v end) then n = n + 1 end end
        for sn, fields in pairs(s.struct) do for k, v in pairs(fields) do if v ~= nil and pcall(function() def[sn][k] = v end) then n = n + 1 end end end
        for an, fields in pairs(s.anim) do for k, v in pairs(fields) do if v and pcall(function() def[an][k] = v end) then n = n + 1 end end end
        for k in pairs(s.none or {}) do pcall(function() def[k] = nil end) end              -- (v148) a curve the game had none of
        if s.text then pcall(function() def.DisplayName = FText(s.text) end) end
        return n
    end
    local function wire(def, name, sws)
        local n, fails = 0, {}
        local function set(fn, what) if pcall(fn) then n = n + 1 else fails[#fails + 1] = what end end
        local rgsPath = "/Game/Animation/AMXX/OnBoard/Regular/FlipTrick/"
        local function bs(path)
            local o = alive(q(function() return StaticFindObject(path) end))
            if not o then pcall(function() LoadAsset(path) end) o = alive(q(function() return StaticFindObject(path) end)) end
            return o
        end
        local trick = bs(rgsPath .. "NoComply/BLD_RGS_NoComply.BLD_RGS_NoComply")
        local catch = bs(rgsPath .. "BLD_RGS_Ollie_CatchLoops.BLD_RGS_Ollie_CatchLoops")
        local land  = bs(rgsPath .. "BLD_RGS_Ollie_Lands_New.BLD_RGS_Ollie_Lands_New")
        if not trick then return 0, "the BLD_RGS_NoComply blend space could not be loaded" end
        -- (v148) rooted BEFORE it goes into the definition
        if not NATIVE.root(trick, "BLD_RGS_NoComply") then return 0, "the BLD_RGS_NoComply blend space could not be rooted" end
        NATIVE.root(catch, "BLD_RGS_Ollie_CatchLoops") NATIVE.root(land, "BLD_RGS_Ollie_Lands_New")
        for _, an in ipairs(ANIMS) do
            set(function() def[an].TrickBlendSpace = trick end, an .. ".TrickBlendSpace")
            if catch then set(function() def[an].CatchBlendSpace = catch end, an .. ".CatchBlendSpace") end
            if land then set(function() def[an].LandBlendSpace = land end, an .. ".LandBlendSpace") end
            -- (v138) the loop blend space as the class default has it (v137 wrote nil: the trick then fell through to an ollie)
            local loopBs = cdo and alive(q(function() return cdo[an].TrickLoopBlendSpace end))
            if loopBs then NATIVE.root(loopBs, "the class default's loop blend space") set(function() def[an].TrickLoopBlendSpace = loopBs end, an .. ".TrickLoopBlendSpace")
            elseif not pcall(function() def[an].TrickLoopBlendSpace = nil end) then fails[#fails + 1] = an .. ".TrickLoopBlendSpace=nil" end
        end
        set(function() def.DisplayName = FText(sws and "Switch No Comply" or "No Comply") end, "DisplayName")
        set(function() def.FirstInputAngleThreshold = S.NoComplyInputAngle end, "FirstInputAngleThreshold")
        set(function() def.AdditionalPopHeightMax = S.NoComplyExtraPop end, "AdditionalPopHeightMax")
        set(function() def.FlipInputSpeedMinMultiplier = 0 def.FlipInputSpeedMaxMultiplier = 0 end, "FlipInputSpeed")
        set(function() def.PopBoardForwardOffsetMin = S.NoComplyPopForwardMin def.PopBoardForwardOffsetMax = S.NoComplyPopForwardMax end, "PopBoardForwardOffset")
        set(function() def.PopBoardHeightAdditionalOffsetMin = S.NoComplyPopHeightMin def.PopBoardHeightAdditionalOffsetMax = S.NoComplyPopHeightMax end, "PopBoardHeightAdditionalOffset")
        set(function() def.ForceAutoCatch = (S.NoComplyAutoCatch ~= 0) end, "ForceAutoCatch")
        -- (v157) THE SWITCH DEFINITION IS THE OTHER WAY ROUND. The game's own switch pressure kickflip scoops to -5..-45 deg
        -- where the regular one has +5..+30 (riding switch the board travels tail first: its OTHER end comes up), and its
        -- catch foot is the other one. v137-v156 wrote the regular numbers into both: in switch the board's trailing end came
        -- up, under the foot that should be popping it ("mirrored front to back"), and swung through level to -30 deg
        local sg = sws and -1 or 1
        set(function() def.DefaultCatchFootType = enumValue("/Script/SessionGame.ECatchFootType", "CF_RightFoot", 1) end, "DefaultCatchFootType")   -- (v158: both, as before v157 -- the catch foot was a guess)
        set(function() def.TrickStartPitchData.TimeMin = S.NoComplyStartPitchTime def.TrickStartPitchData.TimeMax = S.NoComplyStartPitchTime
                       def.TrickStartPitchData.TargetAngleMin = sg * S.NoComplyStartPitchMin def.TrickStartPitchData.TargetAngleMax = sg * S.NoComplyStartPitchMax end, "TrickStartPitchData")
        set(function() def.TrickEndPitchData.TimeMin = S.NoComplyEndPitchTimeMin def.TrickEndPitchData.TimeMax = S.NoComplyEndPitchTimeMax
                       def.TrickEndPitchData.TargetAngleMin = (cdo and q(function() return cdo.TrickEndPitchData.TargetAngleMin end, nil)) or 0 def.TrickEndPitchData.TargetAngleMax = sg * S.NoComplyEndPitchMax end, "TrickEndPitchData")
        set(function() def.AnimNotifiesMin.TrickStartPitchNotifyTime = S.NoComplyStartPitchTime def.AnimNotifiesMin.TrickEndPitchNotifyTime = S.NoComplyStartPitchTime def.AnimNotifiesMin.PopNotifyTime = (S.NoComplyPopNotify < 0) and S.NoComplyPopNotify or ((cdo and q(function() return cdo.AnimNotifiesMin.PopNotifyTime end, nil)) or 0) end, "AnimNotifiesMin")
        set(function() def.AnimNotifiesMax.PopNotifyTime = S.NoComplyPopNotify def.AnimNotifiesMax.TrickStartPitchNotifyTime = (cdo and q(function() return cdo.AnimNotifiesMax.TrickStartPitchNotifyTime end, nil)) or 0 def.AnimNotifiesMax.TrickEndPitchNotifyTime = (cdo and q(function() return cdo.AnimNotifiesMax.TrickEndPitchNotifyTime end, nil)) or 0 end, "AnimNotifiesMax")
        -- what the mod left at the class defaults: the flip, the scoop, the pivot, the pop type and the board-control / catch numbers
        if cdo then
            for _, k in ipairs({ "PopType", "IsPressureTrick", "AdditionalPopHeightMin", "BoardControlExtraPitchDown", "BoardControlExtraPitchUp", "BoardControlExtraScoopBS",
                                 "BoardControlExtraScoopFS", "BoardControlMaxSideMovementBS", "BoardControlMaxSideMovementFS", "CatchPitchAlignDelay", "CatchPitchAlignSmoothing",
                                 "YawAlignMinCatchRatio", "CatchRollAlignSmoothing", "CatchManualFlipAngleThreshold", "CatchManualRotationAngleThreshold",
                                 "BoardFlipPreCatchAngle", "BoardRotationPreCatchAngle", "OtherFootCatchTime" }) do
                local v = q(function() return cdo[k] end, nil)
                if v ~= nil then set(function() def[k] = v end, k) end
            end
            for _, sn in ipairs({ "TrickFlipData", "TrickScoopData", "LocalPivotOffset" }) do
                for _, k in ipairs(STRUCTS[sn]) do
                    local v = q(function() return cdo[sn][k] end, nil)
                    if v ~= nil then set(function() def[sn][k] = v end, sn .. "." .. k) end
                end
            end
            -- (v139) the pop curves too: the old files had none (the class default, usually none), the pressure kickflip has two
            -- that shape the board's rise -- with them left in, the board kept its ollie-like path under the foot
            for _, k in ipairs({ "PopBoardForwardOffsetAlignRatioCurve", "PopBoardHeightOffsetCurve" }) do
                local cv = alive(q(function() return cdo[k] end))
                NATIVE.root(cv, "the class default's " .. k)
                set(function() def[k] = cv end, k .. (cv and "" or "=none"))
            end
        end
        return n, (#fails > 0) and ("could not set: " .. table.concat(fails, ", ")) or nil
    end
    local total, notes = 0, {}
    for name, def in pairs(defs) do
        local sws = (name == "TRICK_SWS_Pressure_KickFlip")
        if want then
            if not NC.saved[name] then snapshot(def, name) end
            local n, why = wire(def, name, sws)
            total = total + n
            if why then notes[#notes + 1] = name .. ": " .. why end
        else
            total = total + restore(def, name)
            local da = addr(def)                                       -- (v151) the game's own names by rotation, put back
            if da and type(HJN_TrickName) == "function" and NC.rotKeys then
                for _, kv in pairs(NC.rotKeys) do pcall(HJN_TrickName, da, kv, "") end
            end
        end
    end
    NC.done, NC.applied, NC.checkAt = true, want, os.clock()   -- (v143) no object kept
    NC.popIs = want and S.NoComplyExtraPop or nil                -- (v156) what the wiring just wrote
    NC.namesAre = nil
    if want then pcall(NATIVE.noComplyNames, "No Comply") end                -- (v151) with the FS / BS / 360 names
    log(string.format("no comply: %s -- %d values written to the two pressure kickflip definitions%s", want and "WIRED (left stick down + right stick left)" or "OFF: the game's pressure kickflip is back",
        total, (#notes > 0) and (" (" .. table.concat(notes, "; ") .. ")") or ""))
    -- (v138) read back: what the definition really holds now (a nested struct write that did not take would show here)
    local d = defs.TRICK_RGS_Pressure_KickFlip
    local function nm(o) o = alive(o) return o and q(function() return o:GetFName():ToString() end, "?") or "none" end
    log(string.format("no comply:    RGS now: trick anim %s, loop %s, catch %s, land %s | input angle %s, extra pop %s, pop height %s..%s, scoop pitch %s..%s at %s s, auto-catch %s, flip %s deg, pop type %s",
        nm(q(function() return d.AnimSet.TrickBlendSpace end)), nm(q(function() return d.AnimSet.TrickLoopBlendSpace end)),
        nm(q(function() return d.AnimSet.CatchBlendSpace end)), nm(q(function() return d.AnimSet.LandBlendSpace end)),
        tostring(q(function() return d.FirstInputAngleThreshold end, "?")), tostring(q(function() return d.AdditionalPopHeightMax end, "?")),
        tostring(q(function() return d.PopBoardHeightAdditionalOffsetMin end, "?")), tostring(q(function() return d.PopBoardHeightAdditionalOffsetMax end, "?")),
        tostring(q(function() return d.TrickStartPitchData.TargetAngleMin end, "?")), tostring(q(function() return d.TrickStartPitchData.TargetAngleMax end, "?")),
        tostring(q(function() return d.TrickStartPitchData.TimeMax end, "?")), tostring(q(function() return d.ForceAutoCatch end, "?")),
        tostring(q(function() return d.TrickFlipData.TargetAngleMax end, "?")), tostring(q(function() return d.PopType end, "?"))))
    do
        local w = defs.TRICK_SWS_Pressure_KickFlip
        log(string.format("no comply:    SWS now: scoop pitch %s..%s (the other way round), end pitch max %s, catch foot %s, extra pop %s",
            tostring(q(function() return w.TrickStartPitchData.TargetAngleMin end, "?")), tostring(q(function() return w.TrickStartPitchData.TargetAngleMax end, "?")),
            tostring(q(function() return w.TrickEndPitchData.TargetAngleMax end, "?")), tostring(q(function() return w.DefaultCatchFootType end, "?")),
            tostring(q(function() return w.AdditionalPopHeightMax end, "?"))))
    end
    log(string.format("no comply:    RGS also: pop curves %s / %s, pop notify %s..%s s, pitch notifies min %s/%s max %s/%s, end pitch min %s, catch foot %s, pivot %s, pressure %s",
        nm(q(function() return d.PopBoardForwardOffsetAlignRatioCurve end)), nm(q(function() return d.PopBoardHeightOffsetCurve end)),
        tostring(q(function() return d.AnimNotifiesMin.PopNotifyTime end, "?")), tostring(q(function() return d.AnimNotifiesMax.PopNotifyTime end, "?")),
        tostring(q(function() return d.AnimNotifiesMin.TrickStartPitchNotifyTime end, "?")), tostring(q(function() return d.AnimNotifiesMin.TrickEndPitchNotifyTime end, "?")),
        tostring(q(function() return d.AnimNotifiesMax.TrickStartPitchNotifyTime end, "?")), tostring(q(function() return d.AnimNotifiesMax.TrickEndPitchNotifyTime end, "?")),
        tostring(q(function() return d.TrickEndPitchData.TargetAngleMin end, "?")), tostring(q(function() return d.DefaultCatchFootType end, "?")),
        tostring(q(function() return d.LocalPivotOffset.X end, "?")), tostring(q(function() return d.IsPressureTrick end, "?"))))
end

-- (v147) SPEED. The game's skater config (one data asset, DefaultSkaterConfig) holds the top skateboarding speed, the top
-- pushing speed and the push impulse; SpeedScale multiplies the three (the game's own numbers are kept, and put back by 1)
-- (v180) ...BUT NOT MaxPushingSpeed ANY MORE. "The grinds sound dull and not as grindy": the board's SOUNDS divide the speed
-- by that very number (read off the exe: ASkateboardEx::AdjustOnBoardGrindingAudio and StartGrindSounds set the grind loop's
-- volume 0..1 and pitch 0.8..1.2 and the first scrape's volume from speed / MaxPushingSpeed, clamped to 0..1; the roll, the
-- surface change and the push sound from speed / (MaxPushingSpeed x 1.52)). At SpeedScale 3 it was 1590 instead of 530, so
-- every grind and every roll played like one at a third of its speed -- at the 312 cm/s you ride at (the median of the
-- session of 4 Oct) a grind at volume 0.20 and pitch 0.88 where the game has 0.59 and 1.04. Since v147.
-- The push's top speed is a product: MaxPushingSpeed x the skater's own "max push speed" multiplier (the game's advanced
-- setting; no sound reads it) x its progression stat. SpeedScale goes into that multiplier now (HJN_PushCap, native v96) and
-- the config's number stays the game's. It is asked for on every 2 s tick: the game writes its own option back over the
-- skater's when one spawns and when its advanced-settings page is applied. Without the native half: the old way, old sound.
-- (v189 / native v101) NEW VERSIONS. Once a run, twenty seconds in, the native half looks at the mod's GitHub page (the
-- latest release's update.txt: its version, build number, the game build it is for and the two files' SHA-256). With
-- AutoUpdate=2 a newer build is downloaded, checked and put in place for the next start; with 1 you are only told.
-- NATIVE.BUILD is this file's own build number: the release's update.txt carries the same number, and that is what is compared.
NATIVE.BUILD = 193
NATIVE.WANT = 104      -- (v191) the native half this file is made for (the 'native v' number of the "loaded" line): an older one beside it is said once, in NATIVE.sync
NATIVE.updateTick = function(live)
    local U = NATIVE.upd or {}
    NATIVE.upd = U
    if U.show and live then                            -- told on the trick display too, once it takes a line (a level is up)
        U.tries = (U.tries or 0) + 1
        if U.tries > 60 or (trickName and trickName(U.show) ~= false) then U.show = nil end
    end
    if U.done then return end
    if type(HJN_Update) ~= "function" or type(HJN_UpdateStatus) ~= "function" then
        -- (review) said once: without a native half of v101 or later nothing looks for new versions, and nothing said so
        if live and NATIVE.v ~= nil then
            U.done = true
            log("update: new versions are NOT looked for -- the native half does that (Mods\\ExpandedTricksNative, v101 or later) and it is " .. (NATIVE.v and ("v" .. tostring(NATIVE.v)) or "not loaded") .. "; update by hand from the mod's GitHub page")
        end
        return
    end
    if not U.asked then
        local mode = math.floor(tonumber(S.AutoUpdate) or 0)
        if mode < 1 then logOnce("updoff", "update: new versions are not looked for (AutoUpdate=0)") return end   -- (review) not latched: switched on in the menu, it is asked then
        -- (review) asked at the first tick, in the menu as well: the work is on a thread of the native half's own, and a
        -- release that breaks once a skater is there can only be replaced by the next one if this ran before the level
        U.asked = true
        pcall(HJN_Update, math.min(2, mode), NATIVE.BUILD)
        return
    end
    local st, text = tostring(HJN_UpdateStatus() or ""):match("^(%d+) ?(.*)$")
    st = tonumber(st) or 0
    if st < 2 then return end
    U.done = true
    log("update: " .. tostring(text))
    if st == 4 then U.show = "Expanded Tricks updated - restart the game" elseif st == 3 then U.show = "Expanded Tricks: a new version is out" end
end
NATIVE.speed = { applied = nil, orig = nil, tries = 0 }
NATIVE.speedApply = function()
    local want, push = tonumber(S.SpeedScale) or 1, tonumber(S.PushScale) or 1
    local cap = "0 no native half v96"
    if type(HJN_PushCap) == "function" then
        cap = tostring(q(function() return HJN_PushCap(NATIVE.skater or 0, want) end, "0 the call failed"))
        if cap:match("^0 wait") then                                         -- no live skater with the native half yet: asked again in 2 s
            NATIVE.speed.waits = (NATIVE.speed.waits or 0) + 1                --   (five times; then the old way rather than no speed setting at all)
            if NATIVE.speed.waits <= 5 then return end
        else NATIVE.speed.waits = 0 end
    end
    local how, base, now = cap:match("^([12]) (%S+) (%S+)")                  -- 1 = it was what it should be, 2 = written
    local own = how ~= nil
    if how == "2" and NATIVE.speed.applied then
        log(string.format("speed: the skater had the game's own max-push-speed multiplier again (%s: a new skater, or its advanced settings applied) -- x%.2f once more: %s", base, want, now))
    end
    local key = want .. "/" .. push .. "/" .. tostring(own)
    if NATIVE.speed.applied == key or NATIVE.speed.tries >= 5 then return end
    local path = "/Game/Data/Skater/DefaultSkaterConfig.DefaultSkaterConfig"
    local cfg = alive(q(function() return StaticFindObject(path) end))
    if not cfg then pcall(function() LoadAsset(path) end) cfg = alive(q(function() return StaticFindObject(path) end)) end
    if not cfg then
        NATIVE.speed.tries = NATIVE.speed.tries + 1
        if NATIVE.speed.tries == 5 then log("speed: the skater config (DefaultSkaterConfig) was not found -- SpeedScale / PushScale not applied") end
        return
    end
    -- (v149) the two top speeds by SpeedScale, the push itself by PushScale (v147 scaled all three by the one number: "it's
    -- increasing the momentum of each push")
    local keys = { { "MaxSkateboardingSpeed", want }, { "MaxPushingSpeed", own and 1 or want }, { "PushImpulse", push } }
    if not NATIVE.speed.orig then
        NATIVE.speed.orig = {}
        for _, k in ipairs(keys) do NATIVE.speed.orig[k[1]] = q(function() return cfg[k[1]] end, nil) end
    end
    local parts = {}
    for _, k in ipairs(keys) do
        local o = NATIVE.speed.orig[k[1]]
        if type(o) == "number" then
            local ok = pcall(function() cfg[k[1]] = o * k[2] end)
            parts[#parts + 1] = string.format("%s %.0f -> %.0f%s", k[1], o, o * k[2], ok and "" or " (FAILED)")
        else parts[#parts + 1] = k[1] .. " unreadable" end
    end
    NATIVE.speed.applied = key
    log(string.format("speed: top speed x%.2f, push x%.2f -- %s; %s", want, push, table.concat(parts, ", "),
        own and string.format("the push's top speed through the skater's own max-push-speed multiplier instead (%s -> %s): MaxPushingSpeed is what the board's sounds divide the speed by, and it stays the game's", base, now)
             or ("NOT through the skater's multiplier (" .. cap .. "): MaxPushingSpeed is also what the board's sounds divide the speed by -- grinds and rolling sound slower than they are")))
end

-- the per-frame hook is needed without any hop too (the game's own LB/RB grabs get the tuck from it):
-- register it as soon as your skater exists, and follow a new skater after a respawn or level change
LoopAsync(2000, function()
    NATIVE.gt(function()
        if NATIVE.off then
            logOnce("offbuild", "*** THIS IS ANOTHER BUILD OF THE GAME than this version of the mod was made for: Expanded Tricks is switched off (nothing of the game is touched) until the mod is updated -- only the update check runs. The native half looked for the game's functions by signature and did not find them all: ExpandedTricks.native.log has the list (send it: Mods\ExpandedTricks\pack-logs.bat)")
            if NATIVE.updateTick then pcall(NATIVE.updateTick, false) end
            return
        end
        local live = false
        pcall(function()
            if active and alive(cached) then live = (alive(mesh) ~= nil) return end
            if not refs() then
                if myAddr or active then myAddr = nil NATIVE.forgetWorld("your skater is gone") end
                return
            end
            local a = addr(s0)
            if a and a ~= myAddr then
                if myAddr then
                    NATIVE.forgetWorld("a new skater")
                    if not refs() then return end
                end
                myAddr = a
            end
            live = true
            ensureHook()
        end)
        if NATIVE.updateTick then pcall(NATIVE.updateTick, live) end   -- (v189; review) BEFORE the skater test: it has to run in the menu too
        if not live then return end
        local ok, err = pcall(NATIVE.sync)
        if not ok then logOnce("nativesync", "native sync error: " .. tostring(err)) end
        if NATIVE.hopMeasure then pcall(NATIVE.hopMeasure) end
        if NATIVE.axisCheck then pcall(NATIVE.axisCheck) end       -- (v131)
        if NATIVE.noComplyApply then pcall(NATIVE.noComplyApply) end   -- (v143) once the skater is there: the level's definitions are the ones that count
        if NATIVE.speedApply then pcall(NATIVE.speedApply) end         -- (v147)
        -- (v86) is the pose hook live in the replay editor? (then the numpad hand nudges show while you scrub a grab)
        pcall(function()
            if modeNow() ~= 6 then NATIVE.replayPosed, NATIVE.replayChecks = nil, 0 return end
            if NATIVE.replayTold or not NATIVE.grab() or type(HJN_Stats) ~= "function" then return end
            local posed = tonumber((tostring(HJN_Stats())):match("(%d+) grab frames posed")) or 0
            if NATIVE.replayPosed then
                NATIVE.replayChecks = (NATIVE.replayChecks or 0) + 1
                if posed > NATIVE.replayPosed then
                    NATIVE.replayTold = true
                    log("replay: the pose hook is LIVE in the replay editor -- scrub to a grab and tune the hand with the numpad")
                elseif NATIVE.replayChecks >= 8 then
                    NATIVE.replayTold = true
                    log("replay: no grab was posed by the hook during 16 s of replay (it plays the recorded pose, or no grab was on screen) -- tune after live grabs")
                end
            end
            NATIVE.replayPosed = posed
        end)
    end)
    return false
end)

log("Expanded Tricks " .. MOD_VERSION .. " -- loaded (v193 / native v104)")   -- (the builds' history is in CHANGELOG.md and the source's own comments)

-- the game's grabs need IsGrabsEnabled in its experimental save (the profile loads it at start-up). (v121) If it is off or
-- missing, the save is PATCHED here: a BoolProperty tag put into FExperimentalSettings -- the bytes the game's own serializer
-- writes for a true flag -- with the struct's size told of it; a backup is kept beside the save, and the game's grabs come
-- on at the NEXT launch (the profile has already loaded the save by the time this runs)
pcall(function()
    local path = (os.getenv("LOCALAPPDATA") or "") .. "\\SessionGame\\Saved\\SaveGames\\ExperimentalSaveSlot.sav"
    local f = io.open(path, "rb")
    if NATIVE.off then if f then f:close() end log("grabs: another build of the game -- its save is not touched") return end
    if not f then log("grabs: ExperimentalSaveSlot.sav not found (" .. path .. ") -- the game writes it on its first start: start the game twice more (once for the mod to switch the grabs on in it, once for the game to read it)") return end
    local data = f:read("*a")
    f:close()
    local function u32(s, at) local a, b, c2, d = s:byte(at, at + 3) if not d then return nil end return a + b * 256 + c2 * 65536 + d * 16777216 end
    local function p32(n) return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256) end
    local function tag(name, typ) return p32(#name + 1) .. name .. "\0" .. p32(#typ + 1) .. typ .. "\0" end
    -- the struct's tag: name, type, int32 size, int32 index, the struct's name, a 16-byte guid, a has-guid byte, then its
    -- own tagged properties up to a None
    local sTag = tag("ExperimentalSettings", "StructProperty")
    local sAt = data:find(sTag, 1, true)
    if not sAt then log("grabs: FExperimentalSettings not found in ExperimentalSaveSlot.sav -- not touched; the game's grabs stay off") return end
    local sizeAt = sAt + #sTag
    local size = u32(data, sizeAt)
    local nameLen = u32(data, sizeAt + 8)
    if not size or not nameLen or nameLen > 64 then log("grabs: the save's struct tag reads wrong -- not touched") return end
    local dataAt = sizeAt + 8 + 4 + nameLen + 16 + 1
    if data:byte(dataAt - 1) == 1 then dataAt = dataAt + 16 end          -- a property guid follows the has-guid byte
    local dataEnd = dataAt + size
    local gTag = tag("IsGrabsEnabled", "BoolProperty")
    local gAt = data:find(gTag, dataAt, true)
    local what
    if gAt and gAt < dataEnd then
        local valAt = gAt + #gTag + 8                       -- int32 size (0), int32 index, then the bool
        if data:byte(valAt) == 1 then log("grabs: IsGrabsEnabled is ON in the game's experimental save") return end
        data = data:sub(1, valAt - 1) .. "\1" .. data:sub(valAt + 1)
        what = "was OFF"
    else
        local noneTag = p32(5) .. "None\0"
        local nAt = data:find(noneTag, dataAt, true)
        if not nAt or nAt >= dataEnd then log("grabs: the struct's end was not found in the save -- not touched; the game's grabs stay off") return end
        local ins = gTag .. p32(0) .. p32(0) .. "\1" .. "\0"   -- size 0, index 0, true, no guid: 46 bytes
        data = data:sub(1, nAt - 1) .. ins .. data:sub(nAt)
        data = data:sub(1, sizeAt - 1) .. p32(size + #ins) .. data:sub(sizeAt + 4)
        what = "was missing"
    end
    local bakPath = path .. ".expandedtricks.bak"
    local b = io.open(bakPath, "rb")
    if b then b:close() else
        local orig = io.open(path, "rb") local ob = orig and orig:read("*a") if orig then orig:close() end
        local o = ob and io.open(bakPath, "wb") or nil
        if not o then log("grabs: no backup could be written beside the save -- the save is not touched; the game's grabs stay off") return end
        o:write(ob) o:close()
    end
    local o = io.open(path, "wb")
    if not o then log("grabs: could not write ExperimentalSaveSlot.sav -- the game's grabs stay off") return end
    o:write(data) o:close()
    log(string.format("grabs: IsGrabsEnabled %s in the game's experimental save -- switched ON (backup: %s). RESTART the game once: its LB/RB grabs come on then", what, bakPath))
    print("[ExpandedTricks] the game's grabs have been switched on in its experimental save -- restart the game once\n")
end)
print("[ExpandedTricks] ready\n")

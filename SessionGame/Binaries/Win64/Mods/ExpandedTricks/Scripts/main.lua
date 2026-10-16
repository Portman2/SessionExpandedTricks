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
    ThrowdownScale = 1.0,
    ThrowdownRateMax = 2.5,
    StepOffUnstick = 1,
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
    GrabFollowStickMode = 1,
    GrabToeSide = 1,
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
    GrabAllBone = 0,
    GrabTurnedSense = 1,
    GrabBlocked   = "ChickenSalad,Taipan,RoastBeef,CanadianBacon",
    DoubleGrabs   = 1,
    DoubleCannonball = "Nose+Tail",
    DoubleGorilla = "Mute+Indy",
    DoubleRocket  = "Nose+Crail",
    DoubleTruckDriver = "Melon+Indy",
    DoubleDrunkDriver = "Mute+Stalefish",
    DoubleSquirrel = "Melon+Stalefish",
    DoubleCannonballBase = "Indy",
    DoubleGorillaBase = "Indy",
    DoubleRocketBase = "Nose",
    DoubleTruckDriverBase = "Indy",
    DoubleDrunkDriverBase = "Indy",
    DoubleSquirrelBase = "Indy",
    DoubleBothSticks = 1,
    GrabTweakStyle = 1,
    GrabBoneMove = 0,
    GrabBoneHands = 1,
    GrabBoneLean = 25,
    GrabHeadUp = 30,
    GrabHeadTurn = 0,
    GrabBoneBehind = 20,
    GrabBoneShowStick = 1,
    HopOllieDeck = 1,
    HopOlliePre = 0.06,
    HopOllieSpan = 0.6,
    HopOllieLand = 0.72,
    HopOllieSound = 0,
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
    DropInVertRef = 350,
    DropInSpin    = 90,
    DropInSetTime = 0.8,
    DropInSetDown = 1,
    DropInSetOutTime = 0.35,
    DropInSetEdge = 1,
    DropInSetReach = 45,
    DropInFar = 0,
    DropInWalkSpeed = 120,
    DropInSetPitchTime = 0.22,
    DropInSetRise = 0,
    DropInSetFeet = 1,
    DropInSetOver = 1,
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
    BoardHopSpeedScale = 1.2,
    BoardHopSpeedAcross = 0.5,
    BoardHopSwitchFix = 1,
    BoardHopStanceLock = 1,
    BoardHopLandLift = 3,
    BoardHopAirKeep = 1,
    BoardHopTurnHold = 1,
    BoardHopTurnHoldSwitch = 0,
    BoardHopRecord = 1,
    BoardHopKeep = 0.3,
    BoardHopFeet = 1,
    BoardHopHead = 1,
    DropInSetFly = 1,
    DropInSetSwitch = 1,
    DropInPlain = 1,
    DropInArms = 40,
    DropInArmsFull = 200,
    DropInArmsPeak = 50,
    DropInCrouch = 18,
    DropInCrouchPeak = 25,
    DropInNoTwist = 1,
    DropInPoses = 0,
    LandHoldFix = 1,
    BoardHopPoses = 1,
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
    RecordPoses = 1,
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
    { "HippieJump",    "num", 0, 3,    "the crouched hippie jump: crouch with one stick and click the other. 0 = off. 1 = with the jump animation (stand up out of the crouch, then the in-air pose).\n; 2 = with the game's ollie animation (its pop, then its tucked knees; the board stays on the ground all the same). 3 = one or the other at random, jump by jump.\n; The mini hop has its own switch (MiniHop) and takes the same animation" },
    { "SpeedScale",    "num", 0.5, 3,  "the skater's TOP SPEED: the game's top skateboarding speed and the speed pushing can take you to, as a multiple of the game's own (1 = the game's; 1.5 = half again as fast). A push is as strong as ever: see PushScale" },
    { "PushScale",     "num", 0.5, 3,  "how hard each PUSH is: the game's push impulse as a multiple of its own (1 = the game's)" },
    { "ThrowdownScale", "num", 1, 4, "THROWDOWN SPEED: how fast the game's own throwdown (Y / triangle on foot) sends you off, as a multiple of the speed you were moving at when you threw the board down (1 = the game's own; 1.5 = half again as fast as you ran). The run-up and the throw are played that much faster to match (see ThrowdownRateMax). Standing still, nothing is added. Not for the mod's drop-ins: those have DropInSpeed. (Builds 195 and 196 had ThrowdownBoost, an ADDED speed in cm/s)" },
    { "ThrowdownRateMax", "num", 1, 4, "throwdown speed: the most the throw itself is sped up by. With ThrowdownScale over 1 the run-up, the throw and the step onto the board are played ThrowdownScale times as fast (the skater covers that many times the ground, so he leaves it at the speed the board is then given), and never more than this. 1 = the throw is left as the game plays it and all of the speed comes once you are on the board" },
    { "StepOffUnstick", "num", 0, 1, "1 = a step-off the game never finishes is finished by the mod. (Y pressed on the board in the split second after the wheels leave the ground with no pop: the game starts its pick-up with no animation, and only that animation's end ever ends a pick-up -- on foot Y and the jump then stay dead until a teleport to the session marker. A quarter second on, the mod asks the game for the end that animation would have asked for; the log has a 'step-off:' line.) 0 = it is only logged" },
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
    { "GrabFollowStickMode", "num", 0, 1, "1 = the bumpers follow the game's stick mode (Options > Gameplay: left foot / right foot, or front foot / back foot). In the left-foot / right-foot mode (and Legacy) LB is the LEFT hand and RB the right, as the sticks are the left and the right foot: the two change places whenever your left foot is the back one -- a regular rider riding switch, a goofy rider riding forward -- for the air grabs, the two-hand grabs, the rolling grabs, the boneless and the bean plant. In the front-foot / back-foot mode LB is always the front hand. 0 = LB is the front hand whatever the mode (as before build 199)" },
    { "GrabToeSide",   "num", 0, 2,    "which way a grab's stick is pushed for the TOE-side grabs (Mute, Taipan, Indy, Canadian Bacon; the other way for the heel-side ones: Melon, Chicken Salad, Stalefish, Roast Beef). 1 = toward the side of the board your toes are on as you see it from behind: right for a regular rider rolling forward, LEFT for a goofy one, and the other way round riding switch. 0 = right, always (the game's own map, as before build 201). 2 = left, always" },
    { "GrabStart",     "num", 0, 1,    "GRABS are the game's own. 1 = press and HOLD LB or RB in the air to grab (let go to let go):\n; LB = front hand, the LEFT stick's direction picks it: up Nose, toward your toes Mute, toward your heels Melon,\n;      down and toward your toes Taipan, down and toward your heels Chicken Salad, down Seatbelt\n; RB = back hand, the RIGHT stick (the game reads its up/down the other way round): pulled DOWN Crail, down and toward\n;      your toes Canadian Bacon, down and toward your heels Roast Beef, toward your toes Indy, toward your heels Stalefish, pushed UP Tail\n; (Your toes: right for a regular rider rolling forward, left for a goofy one, the other way round riding switch -- GrabToeSide.\n;  Which bumper is which hand in the game's left-foot / right-foot stick mode: GrabFollowStickMode.)\n; The mod starts the grab because the game would only while its catch-orient is up. Needs IsGrabsEnabled in the game's\n; ExperimentalSaveSlot.sav (see the log). 0 = off" },
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
    { "DoubleRocket",  "str", 0, 0,    "Quasimodo (both hands on the nose, both feet on the tail): the LB grab + the RB grab that make it.\n; Nose+Crail = BOTH sticks pushed up (the left stick up and the right stick pulled down is Nose+Tail = the Cannonball; swap the two lines' values if you want it the other way)" },
    { "DoubleTruckDriver", "str", 0, 0, "Truck Driver (front hand on the heel edge, back hand on the toe edge: Melon + Indy): the LB grab + the RB grab that make it" },
    { "DoubleDrunkDriver", "str", 0, 0, "Drunk Driver (front hand on the toe edge, back hand on the heel edge: Mute + Stalefish): the LB grab + the RB grab that make it" },
    { "DoubleSquirrel", "str", 0, 0,    "Squirrel (both hands on the heel edge: Melon + Stalefish): the LB grab + the RB grab that make it" },
    { "DoubleCannonballBase", "str", 0, 0, "the game's grab whose crouch the Cannonball is built on" },
    { "DoubleGorillaBase", "str", 0, 0, "the game's grab whose crouch the Gorilla is built on" },
    { "DoubleRocketBase", "str", 0, 0,  "the game's grab whose crouch the Quasimodo is built on" },
    { "DoubleTruckDriverBase", "str", 0, 0, "the game's grab whose crouch the Truck Driver is built on" },
    { "DoubleDrunkDriverBase", "str", 0, 0, "the game's grab whose crouch the Drunk Driver is built on" },
    { "DoubleSquirrelBase", "str", 0, 0, "the game's grab whose crouch the Squirrel is built on" },
    { "DoubleBothSticks", "num", 0, 1, "1 = the Truck Driver, Drunk Driver and Squirrel need BOTH sticks pushed to a side (toward your toes or your heels, each for its own hand);\n; one stick alone, or none, stays the Gorilla. 0 = a centred stick counts as the toe side, so one stick is enough" },
    { "GrabTweakStyle","num", 0, 1,    "what moving the stick off where it picked a grab does (the menu's Grab tweak): 0 = ROTATE, the game's own tweak (your legs and the board twist);\n; 1 = BONE: the board is poked out toward the nose by that grab's Bone<Grab> cm -- by the body going back over the back foot, or by the board itself moving out (GrabBoneMove). A grab whose Bone is 0 rotates either way" },
    { "GrabBoneMove",  "num", 0, 1,    "what moves when a grab is boned (the menu's 'Bone moves'): 0 = the BODY goes back over the back foot, as before build 211;\n; 1 = a TEST: the BOARD is pushed out toward the nose under a body that stays -- in an air that began with a pop; in any other air the body goes back as with 0. Takes the native half v113" },
    { "GrabBoneHands", "num", 0, 1,    "1 = a boned grab's hands stay on their spots on the board: the back leans further (GrabBoneLean) and what the arm still cannot reach the bone gives back, so a bone may come out smaller;\n; 0 = as before build 211: past 16 cm of bone the spots slide toward the tail and the hand comes off. Takes the native half v113" },
    { "GrabBoneLean",  "num", 0, 45,   "degrees the back may lean toward the board past the grab's own limit while it is boned, so that the hand stays on (the menu's 'Boned grabs: extra lean'). 0 = no further: the bone is cut back wherever the arm cannot reach" },
    { "GrabHeadUp",    "num", 0, 90,   "every grab: degrees your head is raised, at the most, from where the game has you look (45 to 65 degrees down, at the board) toward 12 degrees under level, so you look ahead and the head stays clear of the knees; the head is kept level with it. 0 = the head as the game has it (native v117 aims the gaze itself; v116 went by the shoulders' line, which a reaching arm slants: the Melon's crooked head)" },
    { "GrabHeadTurn",  "num", 0, 90,   "every grab: degrees your gaze is turned toward the way you travel, at the most, from where you look (native v117; v116 turned it by where your toes point, whatever the head already did, and overshot); 0 = not turned" },
    { "GrabBoneBehind", "num", 0, 45,  "how far out a boned grab goes (the menu's 'Boned grabs: how far out'): cm your hips may end BEHIND the back foot's place on the board at the full bone.\n; 0 = no further than over it, as build 211: there every grab stopped at 16-28 cm of bone, whatever it was asked. It never goes past what the front leg can reach or the hands can hold.\n; A two-hand grab gets it only where the board is what moves (GrabBoneMove 1). Takes the native half v114" },
    { "GrabBoneShowStick", "num", 0, 1, "with GrabBoneMove 1 and GrabBoneHands 1: a grab picked with the stick centred has no catch in the game, so the board cannot be moved for it and the body went back instead.\n; 1 = the game is shown that stick pushed straight for such a grab, as it is for one picked with the stick (shown again, up to three times, where the catch does not come); 0 = as build 211" },
    { "HopOllieDeck",  "num", 0, 1,    "the ollie animation on a hippie jump: 1 = the body is raised as the back foot pushes down, so that foot stays on the board (in the game's ollie the tail goes down with it); 0 = as the animation has it" },
    { "GrabAllBone",   "num", -40, 100, "cm ADDED to every grab's own Bone<Grab> that is over 0 (the menu's 'All grabs: bone distance'): + = more is asked of the bone, - = less; no grab's total goes under 0.\n; This is what is ASKED at the full swing of the stick. How far the board really goes is held by GrabBoneBehind, the front leg and the arms; the native half moves 80 cm at the most" },
    { "GrabTurnedSense","num", 0, 1,   "1 = a grab on a board that has turned round under you in this air (a shove-it into a Nose or Tail grab) has its tilt steered the other way: there the deck answers the\n; skeleton's board the other way round, and the grabbed end dipped where it should rise. 0 = as before build 207" },
    { "HopOlliePre",   "num", 0, 0.5,  "HopOllie: seconds between the ollie animation's start and leaving the board (the stand-up time of the usual hop is not used)" },
    { "HopOllieSpan",  "num", 0, 1,    "HopOllie: the share of the air the ollie's trick animation is played over (it is sped up or slowed to fit; the tucked loop follows). 0 = at its own speed" },
    { "HopOllieLand",  "num", 0.3, 1,  "HopOllie: the share of the air after which the legs go for the landing (the usual hop's landing pose from there)" },
    { "HopOllieSound", "num", 0, 1,    "HopOllie: 1 = the ollie animation's own sounds are heard (its pop, the foot on the grip); 0 = silenced for the hop, which has its own take-off and landing sounds" },
    { "NativeHandAim", "num", 0, 2,    "the hand TURNED to the board (fingers down past the edge, palm toward the deck): 0 = off (the game's own hand pose, which lies flat on the deck),\n; 1 = in the two-hand grabs only, 2 = in every grab (the default since v114: the grabbing hand)" },
    { "NativeCatchHold", "num", 0, 1,  "1 = when a grab is handed to the game with its catch orient still off, it is set as the game's own grab pick would set it: the deck follows the board bone\n; (the tilt) only in that state -- grabs that started without it took no tilt at all (a Crail / Seatbelt / Stalefish that worked one time and not the next)" },
    { "NativeGrabStance", "num", 0, 1, "1 = a grab plants the feet in the TAIL layout (back foot on the tail, front foot over the front truck), whichever layout you last rode:\n; the game shifts the feet forward for a nollie / fakie crouch and after a revert, and a grab took that (0 = as last ridden)" },
    { "DevKeys",   "num", 0, 1,      "1 = the keyboard test keys: F11 mini hop, F12 hippie jump (no crouch check), F7 board survey (logged), the numpad nudges the last grab's hand numbers and saves them here. 0 = the keyboard is left alone (the release's default)" },
    { "NativePad", "num", 0, 1,      "1 = the controller's stick clicks, triggers, bumpers and Y are read by the native half from the game's own key events;\n; 0 = from SessionTweaks.log as before (needs its CatchClickToCatch=1 and CatchClickProbe keys)" },
    { "MenuOwnPages", "num", 0, 1,   "where the settings pages live: 1 = the mod's own NESTED pages in the pause menu (an Expanded Tricks row that opens General gameplay settings, Hippie Jumps, Drop-ins, Grabs, No Comply), with or without SessionOpenMP;\n; 0 = one flat page of 14 rows inside SessionOpenMP's pause menu (what the nested pages fall back to if they cannot be placed)" },
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
    { "DropInVertRef", "num", 0, 1000, "vert: the wall height (cm) DropInVertSpeed and DropInVertBoost are set for. A lower wall gets less of both, as the square root of its height (the way the speed of a fall goes), never under half: a 2 m quarter is not a 4 m vert. 0 = the same on every wall" },
    { "DropInSpin",    "num", 0, 400,  "the board is let go still tipping forward at this many degrees a second (so it lands on its wheels, not flat)" },
    { "DropInSetTime", "num", 0.05, 2, "seconds the slide out (and back) takes" },
    { "DropInSetDown", "num", 0, 1, "EXPERIMENTAL (the menu's 'Set the board down at the edge (test)'): 1 = at a drop-in's Y press the game's own throw is refused and the mod plays the game's throwdown animation itself, square to the edge and close to it:\n; the board comes down with its middle DropInBack cm from the edge, you are walked onto it where it lies and put on at the animation's own moment, and it slides out over DropInSetOutTime with no move before that.\n; Takes the native half v113. Where a step fails the drop-in goes on the old way and the log says which step. 0 = the drop-in of build 210 (but for its first move, which is no longer made where you already stand right).\n; (build 212) With DropInSetEdge 1 and the native half v114 a press made within DropInSetReach cm of the edge sets the board ON the coping instead: see DropInSetEdge" },
    { "DropInSetOutTime", "num", 0.05, 2, "with DropInSetDown: seconds the slide out (and back) takes after a set-down (DropInSetTime stays the old way's)" },
    { "DropInSetEdge", "num", 0, 1, "with DropInSetDown (the menu's 'Set it ON the coping (test)'): 1 = a Y press made within DropInSetReach cm of the edge sets the board ON the coping: you are stood right at the edge (toes over it), the board comes down level out over the edge, its tail goes down and it STAYS there while you step on; you are put on where it is, with no slide.\n; Takes the native half v114. Farther off, in SWITCH (a second tap of Y) and wherever a step of it does not come it is build 211's set-down or the old way, and the log says which. 0 = build 211's set-down on every press (the board comes down behind the edge and slides out)" },
    { "DropInSetReach", "num", 10, 90, "THE DROP-IN: Y / triangle on foot, the board in your hand, within this many cm of an edge (from the middle of your body; toes over the edge count too): the board is set ON the coping, tail down, and you step on. Farther off, Y is the game's own throwdown" },
    { "DropInFar", "num", 0, 1, "0 = a Y press made farther from the edge than DropInSetReach is no drop-in (the game's own throwdown); 1 = as build 212: the board is set down behind the edge and slides out to it" },
    { "DropInWalkSpeed", "num", 0, 300, "a Y press made while you still move this slowly (cm/s) counts as standing still when an edge is within DropInSetReach: you may walk right up to the edge and press. 0 = a standstill only" },
    { "DropInSetPitchTime", "num", 0.02, 1, "set-down on the coping: seconds the tail takes to go down once the board has landed" },
    { "DropInSetRise", "num", 0, 1, "set-down on the coping: 1 = the mod lifts you toward the board's height before the mount by moving you (it only holds where the game finds no floor under you; 0 = you come up about 9 cm at the mount)" },
    { "DropInSetFeet", "num", 0, 1, "set-down on the coping: how much a foot that is on the animation's board is carried onto the real one (0 = the animation's feet as they are)" },
    { "DropInSetOver", "num", 0, 1, "set-down on the coping: 1 = you are moved out over the edge as the animation drags its board under you (held back by itself where the game is seen to lower you); 0 = your middle stays on the ledge until just before the mount, your feet are carried to the board from there" },
    { "DropInSetFly", "num", 0, 1, "set-down on the coping: 1 = your middle stays 2 cm short of the edge until the last 0.15 s before the mount, and for those you are taken over the edge in the engine's flying mode, at your height (on foot the engine set you lower every frame once your middle was past the edge and the mod set you back: the stutter; over a real drop you fell 14 cm before the mount); 0 = as build 215" },
    { "DropInSetSwitch", "num", 0, 1, "set-down on the coping: 1 = Y tapped twice (switch) is set ON the coping as well: you stand and face the drop as for a regular one, the switch stance's own animation sets the board down, and the game's switch mount turns you half a turn -- you face away from the drop, the nose points at it, your other foot on the tail; 0 = as build 222: a switch drop-in is build 211's set-down (the board set down behind the edge and slid out)" },
    { "DropInPlain", "num", 0, 1, "1 = off a plain ledge or a plain wall (the same level ground just past the edge and further out, or flat floor right under the hung board) the drop-in is a straight drop: tipped DropInTilt and launched straight out, as it was to build 211; 0 = as build 216, which looked further out for a ramp and took the floor, a step's riser or the wall itself for one" },
    { "DropInArms", "num", 0, 80, "drop-ins: degrees your arms are raised out to your sides for balance from the moment you drop in (GO: not while you stand on the board at the edge), through the tip-in, until you ride or land (they come down over 0.7 s); each upper arm is turned about its shoulder toward a pose 18 to 24 degrees under level, never past it and not where the game already has it higher, so about 60 is all the way (native v118). 0 = the arms as the game has them" },
    { "DropInArmsFull", "num", 30, 500, "drop-ins: the drop (cm, from the ledge's top down) that gets all of DropInArms; a smaller one gets its share of it (a 100 cm drop with 200 here: half the degrees), a bigger one all of it. The drop is what the ledge scan measured below the edge" },
    { "DropInArmsPeak", "num", 10, 100, "drop-ins: how far down the drop the arms are fully out, in percent of its height (50 = halfway down); they come out with the way down from the GO, and go down over 0.7 s once you are down" },
    { "DropInCrouch", "num", 0, 40, "drop-ins: cm your hips are let down as you drop in, at a drop of DropInArmsFull and more (a smaller drop gets its share): the knees bend to the feet where the game has them and the back leans toward the drop. It comes in with the tip and the first part of the way down and goes back up once you are down. It is a DEPTH (native v120): the crouch stick's own crouch is not added to it, the deeper of the two shows. 0 = no crouch (native v119)" },
    { "DropInCrouchPeak", "num", 10, 100, "drop-ins: how far down the drop you are at your lowest, in percent of its height (the tip itself takes you halfway there)" },
    { "DropInNoTwist", "num", 0, 1, "drop-ins: 1 = the game's own shoulder twist is held off from the GO until you are down (as the board tips in the game twists the upper body and swings the back arm behind you); 0 = the game's own" },
    { "DropInPoses", "num", 0, 1, "1 = the first 8 drop-ins of a run are written to the pose recorder, two recordings each: 150 poses from the moment the arms come up and 240 from the GO (needs RecordPoses and TraceLog); 0 = no" },
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
    { "BoardHopSpeedScale", "num", 0, 3, "BOARD HOP SPEED: how fast you roll away after the hop onto the board, as a multiple of the speed you ran up to it at (1 = as fast as you ran, which is what the game's own throwdown gives; 1.2 = a little faster; 1.5 = half again as fast). The speed goes along the board, the way you ride off; a board already rolling faster that way keeps its own speed. Standing still, nothing is added. 0 = the board only keeps its own roll (builds 128 to 210)" },
    { "BoardHopSpeedAcross", "num", 0, 1, "board hop speed: a board only rolls along its length. 0 = only the part of your run-up that points along the board is carried onto it (a run-up square to the board gives nothing); 1 = all of your speed, whichever way you came at the board; between the two = that share of the part that points across it" },
    { "BoardHopSwitchFix", "num", 0, 1, "1 = a hop that mounts you in switch hands the game your capsule half a turn round, because the game's own switch mount turns it half a turn itself (build 211: you land facing the way you flew and stay in switch); 0 = as build 210 (you snap half a turn on landing a switch hop)" },
    { "BoardHopStanceLock", "num", 0, 1, "1 = as you land from a hop the board is stopped and its old direction of travel wiped (the wipe: native v114), so that the game's mount cannot re-label your stance from the loose board's own travel and turn the deck half a turn under you (10 Oct; which of the game's tests did it that day is not known: the wipe shuts two of the three, the stop the third -- both are needed); 0 = as build 211" },
    { "BoardHopLandLift", "num", 0, 15, "how many cm over your riding height a hop onto the board ends: clear of the ground, so that the game's own landing does not cut in before the mount (the game lets you down the rest). The riding height is read on level ground only (build 212)" },
    { "BoardHopAirKeep", "num", 0, 1, "1 = in a hop onto the board you are put back in the air when the game's own landing cuts in on the way (the first two times at the take-off and the first two on the way down, no more); 0 = you are not: the game lands you there by itself, as in build 211. The 'as you land' line of the log counts the frames either way (build 212)" },
    { "BoardHopTurnHold", "num", 0, 2, "AN EXPERIMENT against the quarter-turn flick as you land from a hop onto the board: your body is kept facing the side of the board by the mesh's own turn, let out as the game blends you into your stance. 1 = the capsule is eased to the riding direction on the way; 2 = the capsule flies as in build 211 and the turn is taken up on the last frame only; 0 = as build 211. On a regular hop; a switch hop only with BoardHopTurnHoldSwitch" },
    { "BoardHopTurnHoldSwitch", "num", 0, 1, "1 = the hold of BoardHopTurnHold also on a switch hop. Off until the 'frames' lines of a switch hop have shown which way the game turns your body in its own half turn: if that is not as reasoned, the hold would spin you half a turn for a moment" },
    { "BoardHopRecord", "num", 0, 1, "1 = every hop onto the board writes a line of numbers a frame to the log, from the end of its arc to 0.7 s after the mount (the 'frames' lines); 0 = no" },
    { "BoardHopKeep", "num", 0, 0.6, "the hop onto the board: seconds your body's heading is held through the mount (native v115). The game turns the capsule a quarter turn to the board on the last frame and blends it away over an eighth of a second: held, you land facing as you flew. 0 = not held (build 212, with its BoardHopTurnHold)" },
    { "BoardHopFeet", "num", 0, 1, "the hop onto the board: 1 = your feet stand on the deck through the mount -- each ankle is drawn at the height it rides at, its sole flat, and the legs bend to it (the game's own feet dip under the deck and then bounce 28 cm over it, after its board bone, which is still coming down from your hand); the body is not lifted (build 215 lifted it: the stutter). 0 = the game's own feet. Needs native v117" },
    { "BoardHopHead", "num", 0, 1, "the hop onto the board: 1 = your head is kept level through the hop (the game's jump pose lays it over onto a shoulder); 0 = the game's own head. Needs native v117" },
    { "LandHoldFix", "num", 0, 1, "1 = while you are in the air on the board the game's hold-still flag is let go of (left up, it stops the board dead at touchdown), and a landing that loses your speed is written to the log; 0 = only the log line" },
    { "BoardHopPoses", "num", 0, 1, "1 = the first 8 hops onto the board of a run are written to the pose recorder, 120 poses each (needs RecordPoses and TraceLog); 0 = no" },
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
    { "RecordPoses",   "num", 0, 1,    "1 = the skeleton of every trick you do is written to ExpandedTricks.poses.bin beside the logs, and pack-logs.bat puts the newest of them in its zip: a pose that looks wrong can then be looked at exactly as it was on your screen. At 32 MB the file is set aside as ExpandedTricks.poses.bin.old and begun anew (64 MB on disk at most). 0 = nothing is recorded. (It was PoseRecorder, off, until build 195)" },
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
-- (v194 / native v105) ON ANOTHER BUILD OF THE GAME THE CLASSES ARE CHECKED BEFORE THE NATIVE HALF MAY TOUCH THEM. Since
-- native v104 the mod runs on an exe it was not written against (Steam's) when every game function it uses is found there
-- by signature. The functions are one half; the other is where the game keeps its data: the native half reads some
-- ninety members of the skater, its animation instance, the board, its movement, the player controller and the menu by
-- fixed offset, in the pose pass, sixty times a second. A build whose classes are laid out differently would not fail
-- the signatures for certain -- it would read the wrong bytes. So the Lua asks the game itself (UE4SS's reflection)
-- where every reflected property of those classes sits and compares with where it sits in the exe the native half was
-- written against (the table below: 420 properties of 16 classes, the game's and the engine's, from that exe's own
-- property tables). A GAME class's property at another offset, on a build found by signature = the mod stands down as it
-- did before v104, and the log says which. The ENGINE's classes are the check on the check: they are the same in every
-- build of this game, so if they do not read as expected it is the reading that is off, not the game -- the result is
-- then logged and not acted on. A class that cannot be read is said and not counted. On the exe the mod was written
-- against the result is only logged.
-- GENERATED by source/tools/gen_layout.pl from the game exe with PE stamp 69ca6d05. Do not edit by hand.
NATIVE.LAYOUT = {
    { "/Script/SessionGame.SkaterAnimInstance", {
        ["_lookAtOffset"] = 0x2b8, ["BankingRatio"] = 0x2c8, ["BodyRotationRatio"] = 0x2cc, ["ShoulderAdditiveAlpha"] = 0x2d0, ["ShoulderRotationRatio"] = 0x2d4, ["PowerslideCOMOffsetRatio"] = 0x2dc,
        ["PowerslidePitchRatio"] = 0x2e0, ["PowerslideRatio"] = 0x2e4, ["PowerslideTargetRatio"] = 0x2e8, ["PowerslideExitRatio"] = 0x2ec, ["PowerslideExitTime"] = 0x2f0, ["SpeedRatio"] = 0x2f4,
        ["Speed"] = 0x2f8, ["OnFootTurnRatio"] = 0x2fc, ["FootPositionType"] = 0x305, ["LandingFootPositionType"] = 0x306, ["FootPositionTransitionType"] = 0x307, ["FootToBoardTransitionType"] = 0x308,
        ["BoardToFootTransitionType"] = 0x309, ["FlipTrickStanceTransferRatio"] = 0x30c, ["CatchMode"] = 0x311, ["CatchOrientState"] = 0x312, ["CatchOrientYawRatio"] = 0x318, ["CatchOrientPitchRatio"] = 0x31c,
        ["CatchOrientPreLandRatio"] = 0x324, ["GrabState"] = 0x328, ["ManualRatio"] = 0x330, ["CasperRatio"] = 0x338, ["GrindAnimSetIndex"] = 0x33e, ["GrindAnimSet01"] = 0x340,
        ["GrindAnimSet02"] = 0x350, ["GrindAnimSet03"] = 0x360, ["GrindAnimSet04"] = 0x370, ["GrindPreLandRatio"] = 0x380, ["LiptrickAnimSetIndex"] = 0x384, ["LiptrickAnimSet01"] = 0x388,
        ["LiptrickAnimSet02"] = 0x398, ["LiptrickAnimSet03"] = 0x3a8, ["LiptrickAnimSet04"] = 0x3b8, ["WallRideAngleRatio"] = 0x3d0, ["WallRideState"] = 0x3d4, ["ThrowdownFeetIKAlpha"] = 0x3d8,
        ["HipOffset"] = 0x3dc, ["FootIKAutoAdjustSmoothing"] = 0x3ec, ["FootIKAutoAdjustMaxExtentX"] = 0x3f0, ["FootIKAutoAdjustMaxExtentY"] = 0x3f4, ["FootIKAutoAdjustMaxExtentZ"] = 0x3f8, ["LeftFootIKAlpha"] = 0x3fc,
        ["RightFootIKAlpha"] = 0x400, ["LeftFootSocketLocation"] = 0x404, ["LeftFootSocketRotation"] = 0x410, ["RightFootSocketLocation"] = 0x41c, ["RightFootSocketRotation"] = 0x428, ["LeftFootBoneLocationAdjust"] = 0x434,
        ["RightFootBoneLocationAdjust"] = 0x440, ["PelvisLocationAlpha"] = 0x44c, ["LeftHandIKAlpha"] = 0x458, ["RightHandIKAlpha"] = 0x45c, ["LeftHandIKLocation"] = 0x460, ["LeftHandIKRotation"] = 0x46c,
        ["RightHandIKLocation"] = 0x478, ["RightHandIKRotation"] = 0x484, ["CrankPocketRatio"] = 0x498, ["CrankInBlendSpace"] = 0x4a0, ["CrankLoopBlendSpace"] = 0x4a8, ["CrankGrindsLoopBlendSpace"] = 0x4b0,
        ["CrankManualsLoopBlendSpace"] = 0x4b8, ["CrankInStartTime"] = 0x4c0, ["FlipTrick"] = 0x4c8, ["FlipTrickPopRatio"] = 0x4d0, ["FlipTrickPlaybackRate"] = 0x4d4, ["RevertType"] = 0x4d8,
        ["RevertRatio"] = 0x4dc, ["RevertBlendSpace"] = 0x4e0, ["FlipTrickAnimSetIndex"] = 0x4e8, ["FlipTrickAnimSet01"] = 0x4f0, ["FlipTrickStanceTransferAnimSet01"] = 0x510, ["FlipTrickAnimSet02"] = 0x530,
        ["FlipTrickStanceTransferAnimSet02"] = 0x550, ["HeadLookAtLocalLocation"] = 0x570, ["HeadLookAtAlpha"] = 0x57c, ["OnFootPreLandRatio"] = 0x5a0, ["PelvisAdditionalOffset"] = 0x5a4, ["PelvisAdditionalRotation"] = 0x5b0,
        ["OnBoardToggleTransitionPose"] = 0x5c0, ["LandHeightRatio"] = 0x600, ["LandDropHeightRatio"] = 0x604,
    } },
    { "/Script/SessionGame.SkaterCharacterBase", {
        ["SkateboardBlueprint"] = 0x4c0, ["SkateboardExBlueprint"] = 0x4c8, ["SkaterBodyPrimitive"] = 0x4d0, ["_trajectorySpline"] = 0x4d8, ["_skaterTrickComponent"] = 0x4e0, ["_audioData"] = 0x4e8,
        ["ResetRagDollDelay"] = 0x4f4, ["PhysicalAnimationBlendWeightMultiplier"] = 0x548, ["_skaterDefinition"] = 0x570, ["_skateboardingAnimParams"] = 0x610, ["_onFootAnimParams"] = 0x628, ["_replicatedBankingRatio"] = 0x634,
        ["_replicatedTargetRotationRatio"] = 0x638, ["_boardControlMode"] = 0x63c, ["_catchMode"] = 0x63d, ["_catchOrientState"] = 0x63e, ["_catchOrientPitchRatio"] = 0x640, ["_catchOrientYawRatio"] = 0x644,
        ["_grindPitchRatio"] = 0x6d8, ["_grindYawRatio"] = 0x6dc, ["_replicatedGrindName"] = 0x6f0, ["_replicatedGrindActor"] = 0x700, ["_trickPopHeight"] = 0x8f4, ["_replicatedMeshRotator"] = 0x8fc,
        ["_replicatedSkateboardMeshRotator"] = 0x908,
    } },
    { "/Script/SessionGame.SkateboardEx", {
        ["_root"] = 0x290, ["_skateboardMovement"] = 0x298, ["_grindDetector"] = 0x2a0, ["_physMaterialFlipper"] = 0x2a8, ["_physMaterialFlipperGripTape"] = 0x2b0, ["_physMaterialFlipperGrinds"] = 0x2b8,
        ["_physMaterialFlipperGripTapeGrinds"] = 0x2c0, ["_physMaterialFlipperPowerSlides"] = 0x2c8, ["_physMaterialFlipperWithoutFriction"] = 0x2d0, ["_physMaterialFlipperCaspers"] = 0x2d8, ["_physMaterialFlipperPrimo"] = 0x2e0, ["_physMaterialTruck"] = 0x2e8,
        ["_physMaterialTruckGrinds"] = 0x2f0, ["_physMaterialTruckWithoutFriction"] = 0x2f8, ["_physMaterialWheel"] = 0x300, ["_physMaterialWheelGrinds"] = 0x308, ["_physMaterialWheelPowerSlides"] = 0x310, ["_physMaterialWheelWithoutFriction"] = 0x318,
        ["_physMaterialWheelPrimo"] = 0x320, ["_brokenBoardStateDataAsset"] = 0x328, ["_audioData"] = 0x330, ["_pmatFlipperAdjusted"] = 0x750, ["_pmatTruckAdjusted"] = 0x758, ["_pmatWheelAdjusted"] = 0x760,
    } },
    { "/Script/SessionGame.SkateboardExMovementComponent", {
        ["_skateboardConfig"] = 0x330,
    } },
    { "/Script/SessionGame.SessionPlayerController", {
        ["DebugHUDRef"] = 0x570, ["SkaterCameraBlueprint"] = 0x578, ["ChallengeManagerBlueprint"] = 0x580, ["QuestManagerBlueprint"] = 0x588, ["StatTrackerBlueprint"] = 0x590, ["TrackingManagerBlueprint"] = 0x598,
        ["PartyGamesManagerBlueprint"] = 0x5a0, ["_maxRepairBoardInputDelay"] = 0x5a8, ["_spotMarkerWidget_Blueprint"] = 0x5b0, ["_spotMarkerVisuals_Blueprint"] = 0x5b8, ["_setSpotTimeDelaySeconds"] = 0x5c0, ["_minGotoMarkerTimeDelaySeconds"] = 0x5c4,
        ["_maxGotoMarkerTimeDelaySeconds"] = 0x5c8, ["_minSpotDistanceTimeDelayAffect"] = 0x5cc, ["_maxSpotDistanceTimeDelayAffect"] = 0x5d0, ["_trickDisplayWidgetBlueprint"] = 0x5d8, ["_introUIBlueprint"] = 0x5e0, ["PauseMenuPageContainerBlueprint"] = 0x5e8,
        ["VideoMontagePauseMenuPageContainerBlueprint"] = 0x5f0, ["_brokenBoardPopupWidgetBlueprint"] = 0x5f8, ["DefaultFilmerModeManager"] = 0x660, ["_introUI"] = 0x670, ["_activePauseMenuPageContainer"] = 0x710,
    } },
    { "/Script/SessionGame.MenuPage", {
        ["PageItem_SelectionBlueprint"] = 0x260, ["PageItem_MultiOptionBlueprint"] = 0x268, ["PageItem_ProgressBarBlueprint"] = 0x270, ["PageItem_SliderBarBlueprint"] = 0x278, ["_scrollBarPanel"] = 0x280, ["_scrollBarSlider"] = 0x288,
        ["_maxVisibleItems"] = 0x290,
    } },
    { "/Script/SessionGame.MenuPageContainer", {
        ["_rootPageDefinition"] = 0x260, ["_inputModePush"] = 0x26b, ["_progressCircleWidgetName"] = 0x26c, ["_confirmButtonWidgetName"] = 0x274, ["_defaultAudioSet"] = 0x280,
    } },
    { "/Script/SessionGame.ReplayManager", {
        ["_replayFPS"] = 0x220, ["_replayBufferLength"] = 0x224, ["_cameraShakeConfig"] = 0x228, ["_replayAudioSynthComponent"] = 0x240, ["_audioReplayComponent"] = 0x248, ["_replayEditorCameraBlueprint"] = 0x250,
        ["_replayEditorUIBlueprint"] = 0x258, ["_replayEditorUIZOrder"] = 0x260, ["InstancesData"] = 0x268,
    } },
    { "/Script/SessionGame.FlipTrickDefinition", {
        ["Name"] = 0x30, ["FootPosition"] = 0x38, ["LocalPivotOffset"] = 0x3c, ["PopType"] = 0x48, ["MaxCrankRatioOnGrinds"] = 0x4c, ["DefaultCatchFootType"] = 0x50,
        ["AdditionalPopHeightMin"] = 0x54, ["AdditionalPopHeightMax"] = 0x58, ["AdditionalPopHeightGrind"] = 0x5c, ["DisplayName"] = 0x68, ["_displayNamesWithRotation"] = 0x80, ["FirstInputAngleThreshold"] = 0xd0,
        ["Inputs"] = 0xd8, ["LegacyInputs"] = 0xe8, ["FlipInputSpeedMinMultiplier"] = 0xf8, ["FlipInputSpeedMaxMultiplier"] = 0xfc, ["AnimSet"] = 0x100, ["AnimSet_AFXX"] = 0x120,
        ["AnimTrickTimeMin"] = 0x140, ["AnimTrickTimeMax"] = 0x144, ["AnimNotifiesMin"] = 0x148, ["AnimNotifiesMax"] = 0x15c, ["FootAutoAdjustMultiplier"] = 0x170, ["PopBoardForwardOffsetMin"] = 0x174,
        ["PopBoardForwardOffsetMax"] = 0x178, ["PopBoardForwardOffsetCurve"] = 0x180, ["PopBoardForwardOffsetAlignRatioCurve"] = 0x188, ["PopBoardSideOffsetMin"] = 0x190, ["PopBoardSideOffsetMax"] = 0x194, ["PopBoardSideOffsetCurve"] = 0x198,
        ["PopBoardHeightAdditionalOffsetMin"] = 0x1a0, ["PopBoardHeightAdditionalOffsetMax"] = 0x1a4, ["PopBoardHeightOffsetCurve"] = 0x1a8, ["TrickFlipData"] = 0x1b0, ["TrickScoopData"] = 0x1c8, ["TrickStartPitchData"] = 0x1e8,
        ["TrickEndPitchData"] = 0x208, ["BoardControlExtraPitchDown"] = 0x22c, ["BoardControlExtraPitchUp"] = 0x230, ["BoardControlExtraRollPitchDown"] = 0x234, ["BoardControlExtraRollPitchUp"] = 0x238, ["BoardControlExtraScoopBS"] = 0x23c,
        ["BoardControlExtraScoopFS"] = 0x240, ["BoardControlExtraRollScoopBS"] = 0x244, ["BoardControlExtraRollScoopFS"] = 0x248, ["BoardControlMaxSideMovementBS"] = 0x24c, ["BoardControlMaxSideMovementFS"] = 0x250, ["BoardFlipPreCatchAngle"] = 0x258,
        ["BoardRotationPreCatchAngle"] = 0x25c, ["BoardPitchPreCatchAngleMin"] = 0x260, ["BoardPitchPreCatchAngleMax"] = 0x264, ["OtherFootCatchTime"] = 0x268, ["CatchTargetPitchAngle"] = 0x26c, ["CatchTargetRollAngle"] = 0x270,
        ["CatchPitchAlignDelay"] = 0x274, ["CatchPitchAlignSmoothing"] = 0x278, ["CatchYawAlignCurve"] = 0x280, ["YawAlignMinCatchRatio"] = 0x288, ["CatchRollAlignSmoothing"] = 0x28c, ["CatchManualFlipAngleThreshold"] = 0x290,
        ["CatchManualRotationAngleThreshold"] = 0x294, ["CasperPopHeightMultiplierOverride"] = 0x298, ["DarkSlideOverrides"] = 0x2a0, ["CasperOverrides"] = 0x2b0, ["AdditionalPopHeightProgression"] = 0x2c0,
    } },
    { "/Script/Engine.Actor", {
        ["PrimaryActorTick"] = 0x28, ["UpdateOverlapsMethodDuringLevelStreaming"] = 0x5d, ["DefaultUpdateOverlapsMethodDuringLevelStreaming"] = 0x5e, ["RemoteRole"] = 0x5f, ["ReplicatedMovement"] = 0x60, ["InitialLifeSpan"] = 0x94,
        ["CustomTimeDilation"] = 0x98, ["AttachmentReplication"] = 0xa0, ["Owner"] = 0xe0, ["NetDriverName"] = 0xe8, ["Role"] = 0xf0, ["NetDormancy"] = 0xf1,
        ["SpawnCollisionHandlingMethod"] = 0xf2, ["AutoReceiveInput"] = 0xf3, ["InputPriority"] = 0xf4, ["InputComponent"] = 0xf8, ["NetCullDistanceSquared"] = 0x100, ["NetTag"] = 0x104,
        ["NetUpdateFrequency"] = 0x108, ["MinNetUpdateFrequency"] = 0x10c, ["NetPriority"] = 0x110, ["Instigator"] = 0x118, ["Children"] = 0x120, ["RootComponent"] = 0x130,
        ["ControllingMatineeActors"] = 0x138, ["Layers"] = 0x150, ["ParentComponent"] = 0x160, ["Tags"] = 0x170, ["OnTakeAnyDamage"] = 0x180, ["OnTakePointDamage"] = 0x181,
        ["OnTakeRadialDamage"] = 0x182, ["OnActorBeginOverlap"] = 0x183, ["OnActorEndOverlap"] = 0x184, ["OnBeginCursorOver"] = 0x185, ["OnEndCursorOver"] = 0x186, ["OnClicked"] = 0x187,
        ["OnReleased"] = 0x188, ["OnInputTouchBegin"] = 0x189, ["OnInputTouchEnd"] = 0x18a, ["OnInputTouchEnter"] = 0x18b, ["OnInputTouchLeave"] = 0x18c, ["OnActorHit"] = 0x18d,
        ["OnDestroyed"] = 0x18e, ["OnEndPlay"] = 0x18f, ["InstanceComponents"] = 0x1f0, ["BlueprintCreatedComponents"] = 0x200,
    } },
    { "/Script/Engine.ActorComponent", {
        ["PrimaryComponentTick"] = 0x30, ["ComponentTags"] = 0x60, ["AssetUserData"] = 0x70, ["UCSSerializationIndex"] = 0x84, ["CreationMethod"] = 0x8c, ["OnComponentActivated"] = 0x8d,
        ["OnComponentDeactivated"] = 0x8e, ["UCSModifiedProperties"] = 0x90,
    } },
    { "/Script/Engine.SceneComponent", {
        ["PhysicsVolume"] = 0xb8, ["AttachParent"] = 0xc0, ["AttachSocketName"] = 0xc8, ["AttachChildren"] = 0xd0, ["ClientAttachedChildren"] = 0xe0, ["RelativeLocation"] = 0x11c,
        ["RelativeRotation"] = 0x128, ["RelativeScale3D"] = 0x134, ["ComponentVelocity"] = 0x140, ["Mobility"] = 0x14f, ["DetailMode"] = 0x150, ["PhysicsVolumeChangedDelegate"] = 0x151,
    } },
    { "/Script/Engine.SkinnedMeshComponent", {
        ["SkeletalMesh"] = 0x480, ["MasterPoseComponent"] = 0x488, ["SkinCacheUsage"] = 0x490, ["VertexOffsetUsage"] = 0x4a0, ["PhysicsAssetOverride"] = 0x5a8, ["ForcedLodModel"] = 0x5b0,
        ["MinLodModel"] = 0x5b4, ["StreamingDistanceMultiplier"] = 0x5c0, ["LODInfo"] = 0x5d0, ["VisibilityBasedAnimTickOption"] = 0x604, ["CapsuleIndirectShadowMinVisibility"] = 0x60c, ["CachedWorldSpaceBounds"] = 0x620,
        ["CachedWorldToLocalTransform"] = 0x640,
    } },
    { "/Script/Engine.SkeletalMeshComponent", {
        ["AnimBlueprintGeneratedClass"] = 0x6a0, ["AnimClass"] = 0x6a8, ["AnimScriptInstance"] = 0x6b0, ["PostProcessAnimInstance"] = 0x6b8, ["AnimationData"] = 0x6c0, ["RootBoneTranslation"] = 0x6e8,
        ["LineCheckBoundsScale"] = 0x6f4, ["LinkedInstances"] = 0x730, ["CachedBoneSpaceTransforms"] = 0x740, ["CachedComponentSpaceTransforms"] = 0x750, ["GlobalAnimRateScale"] = 0x8b0, ["KinematicBonesUpdateType"] = 0x8b4,
        ["PhysicsTransformUpdateMode"] = 0x8b5, ["AnimationMode"] = 0x8b7, ["CachedAnimCurveUidVersion"] = 0x8c6, ["ClothBlendWeight"] = 0x8c8, ["DisallowedAnimCurves"] = 0x8d0, ["BodySetup"] = 0x8e0,
        ["OnConstraintBroken"] = 0x8f0, ["ClothingSimulationFactory"] = 0x900, ["TeleportDistanceThreshold"] = 0x9d8, ["TeleportRotationThreshold"] = 0x9dc, ["LastPoseTickFrame"] = 0x9e8, ["ClothingInteractor"] = 0xa40,
        ["OnAnimInitialized"] = 0xb10,
    } },
    { "/Script/Engine.PlayerController", {
        ["Player"] = 0x298, ["AcknowledgedPawn"] = 0x2a0, ["ControllingDirTrackInst"] = 0x2a8, ["MyHUD"] = 0x2b0, ["PlayerCameraManager"] = 0x2b8, ["PlayerCameraManagerClass"] = 0x2c0,
        ["TargetViewRotation"] = 0x2cc, ["SmoothTargetViewRotationSpeed"] = 0x2e4, ["HiddenActors"] = 0x2f0, ["HiddenPrimitiveComponents"] = 0x300, ["LastSpectatorStateSynchTime"] = 0x314, ["LastSpectatorSyncLocation"] = 0x318,
        ["LastSpectatorSyncRotation"] = 0x324, ["ClientCap"] = 0x330, ["CheatManager"] = 0x338, ["CheatClass"] = 0x340, ["PlayerInput"] = 0x348, ["ActiveForceFeedbackEffects"] = 0x350,
        ["NetPlayerIndex"] = 0x3d4, ["PendingSwapConnection"] = 0x410, ["NetConnection"] = 0x418, ["InputYawScale"] = 0x42c, ["InputPitchScale"] = 0x430, ["InputRollScale"] = 0x434,
        ["ForceFeedbackScale"] = 0x43c, ["ClickEventKeys"] = 0x440, ["DefaultMouseCursor"] = 0x450, ["CurrentMouseCursor"] = 0x451, ["DefaultClickTraceChannel"] = 0x452, ["CurrentClickTraceChannel"] = 0x453,
        ["HitResultTraceDistance"] = 0x454, ["SeamlessTravelCount"] = 0x458, ["LastCompletedSeamlessTravelCount"] = 0x45a, ["InactiveStateInputComponent"] = 0x4d0, ["CurrentTouchInterface"] = 0x4f0, ["SpectatorPawn"] = 0x548,
        ["SpawnLocation"] = 0x558,
    } },
    { "/Script/Engine.AudioComponent", {
        ["Sound"] = 0x1f8, ["InstanceParameters"] = 0x200, ["SoundClassOverride"] = 0x210, ["AudioComponentUserID"] = 0x220, ["PitchModulationMin"] = 0x228, ["PitchModulationMax"] = 0x22c,
        ["VolumeModulationMin"] = 0x230, ["VolumeModulationMax"] = 0x234, ["VolumeMultiplier"] = 0x238, ["EnvelopeFollowerAttackTime"] = 0x23c, ["EnvelopeFollowerReleaseTime"] = 0x240, ["Priority"] = 0x244,
        ["SubtitlePriority"] = 0x248, ["SourceEffectChain"] = 0x250, ["PitchMultiplier"] = 0x258, ["LowPassFilterFrequency"] = 0x25c, ["AttenuationSettings"] = 0x268, ["AttenuationOverrides"] = 0x270,
        ["ConcurrencySettings"] = 0x610, ["ConcurrencySet"] = 0x618, ["AutoAttachLocationRule"] = 0x674, ["AutoAttachRotationRule"] = 0x675, ["AutoAttachScaleRule"] = 0x676, ["ModulationRouting"] = 0x678,
        ["OnAudioPlayStateChanged"] = 0x6c0, ["OnAudioVirtualizationChanged"] = 0x6e8, ["OnAudioFinished"] = 0x710, ["OnAudioPlaybackPercent"] = 0x738, ["OnAudioSingleEnvelopeValue"] = 0x760, ["OnAudioMultiEnvelopeValue"] = 0x788,
        ["OnQueueSubtitles"] = 0x7b0, ["AutoAttachParent"] = 0x7c0, ["AutoAttachSocketName"] = 0x7c8,
    } },
}
NATIVE.layoutCheck = function()
    local r = { ok = 0, total = 0, bad = 0, miss = 0, cant = 0, engOk = 0, engBad = 0, notes = {} }
    for _, c in ipairs(NATIVE.LAYOUT) do
        local live, n, short = {}, 0, (c[1]:match("%.([^.]+)$") or c[1])
        local eng = c[1]:find("/Script/Engine.", 1, true) == 1
        local okc, err = pcall(function()
            local cls = StaticFindObject(c[1])
            if not cls or not cls:IsValid() then error("the class is not there", 0) end
            cls:ForEachProperty(function(p)
                live[p:GetFName():ToString():lower()] = p:GetOffset_Internal()     -- (an FName shows the spelling it was FIRST registered with in this run, not necessarily the property's own: compared without case)
                n = n + 1
            end)
        end)
        if not okc or n == 0 then
            r.cant = r.cant + 1
            r.notes[#r.notes + 1] = short .. " could not be read (" .. tostring((not okc) and err or "no properties") .. ")"
        else
            for name, off in pairs(c[2]) do
                r.total = r.total + 1
                local l = live[name:lower()]
                if l == off then
                    r.ok = r.ok + 1
                    if eng then r.engOk = r.engOk + 1 end
                elseif l == nil then
                    r.miss = r.miss + 1
                    if #r.notes < 16 then r.notes[#r.notes + 1] = short .. "." .. name .. " is not there" end
                else
                    r.bad = r.bad + 1
                    if eng then r.engBad = r.engBad + 1 end
                    if #r.notes < 16 then r.notes[#r.notes + 1] = string.format("%s.%s is at %s, not at 0x%x", short, name, (math.type(l) == "integer") and string.format("0x%x", l) or tostring(l), off) end
                end
            end
        end
    end
    return r
end
-- true = a property of one of the GAME's classes sits at another offset on this build, and the reading can be trusted
-- (the engine's read as expected): the mod stands down. A property that is not there at all is said, not acted on: if
-- a member really was taken out, the ones after it have moved and say so.
NATIVE.layoutVerdict = function(r)
    return NATIVE.buildMode == 1 and (r.bad - r.engBad) > 0 and r.engBad == 0 and r.engOk > 0
end
-- (v189, review) ANOTHER BUILD OF THE GAME. The native half checks the exe's build stamp and leaves its hook out on any
-- other -- but the Lua half went on: the 2 s tick still wired the no comply and wrote the trick names through natives
-- that call fixed addresses in the exe. HJN_PushCap answers "0 not this game build" before it touches anything; that
-- is asked once here, and everything of the mod's that touches the game stands down on it (only the update check runs).
do
    local okb, ans = pcall(function() return HJN_PushCap(0, 1) end)
    NATIVE.off = (okb and tostring(ans):find("not this game build", 1, true) ~= nil) or false
    -- (v194) HJN_BuildMode: 0 = the exe the native half was written against, 1 = another one, its functions found by
    -- signature, -1 = another one, not all found (the answer above says so too). Not there = an older native half
    local okm, mode = pcall(function() return HJN_BuildMode() end)
    NATIVE.buildMode = (okm and tonumber(mode)) or 0
    local okl, res = pcall(NATIVE.layoutCheck)
    NATIVE.layoutRes = okl and res or { ok = 0, total = 0, bad = 0, miss = 0, cant = #NATIVE.LAYOUT, engOk = 0, engBad = 0, notes = { "the check itself failed: " .. tostring(res) } }
    if NATIVE.layoutVerdict(NATIVE.layoutRes) then NATIVE.off, NATIVE.offWhy = true, "layout" end
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
        { "Gorilla",       201, 10, 10,  8, 30, 30,   8,  -8,  0, 0, 15,  8, 45, 18 },
        { "Rocket",        202, 50,  0,  0, 20, 20,   0,   0,  0, 22, 0,  0, 45 },
        -- (v205) three more, each hand doing what its one-hand grab does (203 Melon + Indy, 204 Mute + Stalefish, 205 Melon +
        -- Stalefish). Their numbers are put together from the author's ini of 9 Oct: each hand's spot and path, and each
        -- leg's splay and roll, from that hand's own grab (GRAB_TUNED below has the hands); tilt and back the mean of the
        -- two; lift, drop and fold the Gorilla's, the two-hand crouch as it was tuned. (+ the 15th number: the bone, cm)
        { "TruckDriver",   203, -8, -10, 15, 10, -40,  15, -20,  8, 0,  0,  0, 45, 18 },
        { "DrunkDriver",   204,  0, -10, 15, 25,  10,   8, -10,  5, 0, 15,  8, 45, 18 },
        { "Squirrel",      205,  3, -10, 15, 10,  10,  15, -10, 18, 0,  0,  0, 45, 18 },
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
        -- (v205 / native v109) the edge two-hand grabs' bone
        -- (v212) its range doubled with the menu's slider, 45 -> 90 ("maybe double the limit or more"). It is what a grab
        -- ASKS: on 10 Oct no bone came near what was asked (16-28 cm of 45-73), GrabBoneBehind is what lets it out
        { "Bone", "",      24,   0, 90, 15, "THE BONE (the menu's Grab tweak on bone): cm asked at the full swing of the stick off where it picked the grab -- the body goes back over the back foot, the board poked out toward the nose (or the board itself moves out: GrabBoneMove); 0 = this grab rotates instead. How far a bone really goes is held by GrabBoneBehind" },
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
        TruckDriver = { Hand2Along = 3, Hand2Up = 6, HandUp = 6, Via2Across = 40, Via2Along = 40 },
        DrunkDriver = { Hand2Along = -3, Hand2Up = 6, HandUp = 6, SwHand2Up = 5, Via2Across = 0, Via2Up = 0, ViaAlong = 20 },
        Squirrel = { Hand2Along = -3, Hand2Up = 6, HandUp = 6, SwHand2Up = 5 },
    }
    -- GRAB_TUNED_END
    for _, g in ipairs(NATIVE.GRABS) do
        for _, p in ipairs(NATIVE.PARAMS) do
            if not p[8] or g[2] >= 200 then
                local key = p[1] .. g[1] .. p[2]
                local tv = NATIVE.GRAB_TUNED and NATIVE.GRAB_TUNED[g[1]]   -- (v121) the author's tuned numbers, baked for a fresh install
                -- (v209) the one-hand grabs on the board's edges bone 15 cm; the ones on its tips (Nose, Tail, Crail, Seatbelt) rotate
                if S[key] == nil and p[1] == "Bone" and g[2] < 200 then S[key] = ({ Melon = 15, Mute = 15, ChickenSalad = 15, Taipan = 15, Stalefish = 15, Indy = 15, RoastBeef = 15, CanadianBacon = 15 })[g[1]] or 0 end
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
            local t0, n0 = os.clock(), NATIVE.WK.n                -- (v218, the review) a stick click, a bumper, Y and the timers' work come through here, not through the frame hook: timed the same way
            local ok, err = pcall(it[1])
            G.running = nil
            if not hook and NATIVE.slow then                     -- (run from the frame hook it is inside that hook's own time already)
                local dt = os.clock() - t0
                if dt >= 0.004 then NATIVE.slow(dt, NATIVE.WK.n - n0, it[2] or "a queued action") end
            end
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
        local fg = (type(HJN_Foreground) == "function") and tonumber(HJN_Foreground()) or -1     -- (v203 / native v107)
        log(string.format("game thread: UE4SS has not run the mod's queued actions for %.1f s (%d waiting; it last ran them %s%s) -- the frame hook runs them from here on [%s]",
            now - it[3], #G.q, G.servedAt and string.format("%.1f s ago", now - G.servedAt) or "never", G.running and (", and one was still running: " .. tostring(G.running)) or "",
            (fg == 0) and "the game is NOT the window in front: ExpandedTricks.native.log's 'window:' lines say since when and what is" or ((fg == 1) and "the game is the window in front" or "whether the game is the window in front is not known")))
    end
    NATIVE.gtDrain(true)
end

-- (v210) THE GAME'S OBJECTS ARE NOT WALKED WHILE THE ENGINE IS CLEARING THEM OUT. The crash at the map change of 9 Oct
-- 22:37:24 (EXCEPTION_ACCESS_VIOLATION reading 0x6c2cd719; its report shows 82 frames of UE4SS under this file's frame
-- hook): two seconds into the new map UE4SS's FindAllOf, which walks every object the game has, read one whose class
-- pointer was garbage. After a level change (and about once a minute in play) the engine destroys the objects it has
-- dropped ON ANOTHER THREAD, and an object can be freed between the walk reading its slot and reading the object.
-- This file walked once a second while a trick name was up, at every level change, at the first hop on a map and
-- twice at every look for a skater that is not there (the menus). Now every walk asks first: the native half (v112,
-- HJN_GcBusy) reads the engine's own two "a purge is on" flags, and while either is set nothing is walked -- the
-- caller is told "not now" and each of them asks again later. The skater is looked for twice a second at most. Where
-- the flags cannot be read (an older native half, a game build they are not found on): no walks for 8 s after a level
-- change, bar the look for the skater.
-- (v212) ...twice a second WHILE THERE IS NONE: a look that found the skater holds no later look back (skater()).
NATIVE.WK = { n = 0, no = 0 }
-- (v218) A FRAME THE MOD'S OWN WORK MAKES LONG IS SAID. "When I do a grab then I get some stuttering, like a micro
-- freeze ... and eventually it stops. I was hoping the log showed you the issue." (The Steam tester, 13 Oct.) It did
-- not: nothing timed the mod. His pose recordings did -- one frame of 29-32 ms (11 usual) every 1.00 s for as long as
-- the mod held the game's trick display, which a grab's name starts and a bail ends: the display's once-a-second check
-- walked EVERY object the game has (FindAllOf), 19 ms on a stock map on his machine, 6.5 on the developer's, more on a
-- map with more objects. That check now looks the widget up by its own name (tdLive), and the other walks that fell on
-- a trick's first frame are gone (a hop's look for the options, the board's parts). The frame hook is timed from here
-- on: 4 ms or more of the mod's own work in one frame is a line (the first 200 of a run, one in 2 s unless it is 12 ms
-- or more), with how many looks through the game's objects were in it.
NATIVE.slow = function(dt, walks, what)
    local W, now = NATIVE.WK, os.clock()
    W.slowN = (W.slowN or 0) + 1
    if dt > (W.slowMax or 0) then W.slowMax = dt end
    if (W.slowTold or 0) >= 200 or (W.slowAt and now - W.slowAt < 2 and dt < 0.012) then return end
    W.slowAt, W.slowTold = now, (W.slowTold or 0) + 1
    log(string.format("slow frame: the mod's own work (%s) took %.0f ms of this frame (%d look(s) through all the game's objects in it; %d such frames so far, the longest %.0f ms)",
        tostring(what or "the frame hook"), dt * 1000, walks, W.slowN, W.slowMax * 1000))
end
NATIVE.timed = function(fn, ctx)
    local t0, n0 = os.clock(), NATIVE.WK.n
    pcall(fn, ctx)
    local dt = os.clock() - t0
    if dt >= 0.004 then NATIVE.slow(dt, NATIVE.WK.n - n0) end
end
NATIVE.walkOk = function(kind)
    local W, now = NATIVE.WK, os.clock()
    local b = -1
    if type(HJN_GcBusy) == "function" then local ok, r = pcall(HJN_GcBusy) b = ok and tonumber(r) or -1 end
    local why = nil
    if b == 1 then why = "the engine is clearing objects out"
    elseif kind == "skater" then if W.skAt and now - W.skAt < 0.5 then why = "spaced" end
    elseif b ~= 0 and W.lvlAt and now - W.lvlAt < 8 then why = "a level change under 8 s ago (the engine's purge flags cannot be read)" end
    if why then
        if why ~= "spaced" then
            W.no = W.no + 1
            if not W.told or now - W.told > 60 then
                W.told = now
                log(string.format("objects: a look through the game's objects put off -- %s (%d looks made, %d put off so far)", why, W.n, W.no))
            end
        end
        return false
    end
    if kind == "skater" then W.skAt = now end                   -- (v212) taken back by skater() when this look finds one
    W.n = W.n + 1
    return true
end
NATIVE.all = function(cn) if not NATIVE.walkOk() then return nil end return FindAllOf(cn) end
NATIVE.first = function(cn) if not NATIVE.walkOk() then return nil end return FindFirstOf(cn) end

local function skater()
    local s = alive(cached)
    if s then return s end
    if not NATIVE.walkOk("skater") then return nil end          -- (v210) not now: asked again at the next call
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
    -- (v212) ONLY A LOOK THAT FOUND NOBODY HOLDS THE NEXT ONE BACK. The half second between two looks (NATIVE.walkOk) is
    -- there so that a state with NO skater -- the menus, a map loading -- does not walk the game's objects at every
    -- call. Build 210 counted it from every look, and a look that FOUND the skater held back the one after it. 10 Oct:
    -- the 2 s loop found a new map's skater, dropped all it held (forgetWorld) and looked again in the same step --
    -- "spaced", so it gave up, and did the same two seconds later: "level change (a new skater)" 175 times from
    -- 09:49:17 to 09:55:06. Two stick clicks in that time (09:54:58.7, 09:55:00.7 in SessionTweaks.log) have no line
    -- of the mod's -- a look refused as "spaced" says nothing; the third, at 09:55:04.8, found the skater (its "L3
    -- click" lines), and the loop's next turn was its last. A skater that is found is kept and asks for no look
    -- while it lives, so the look made right after one that found a skater is not the menus' look over again: it
    -- is made.
    if cached then NATIVE.WK.skAt = nil end
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
    if not NATIVE.walkOk() then return end                      -- (v210) not now: the 2 s loop asks again (NATIVE.audio stays nil)
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
    if BD.lookAt and os.clock() - BD.lookAt < 0.5 then return nil end   -- (v210) a look that found none is not made again at once
    if not NATIVE.walkOk() then return nil end
    BD.lookAt = os.clock()
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
    -- (v212) ...AND ONE THAT FOUND THE DECK HOLDS NO LATER LOOK BACK: the skater's trap (see skater()) sat here too.
    -- boardParts drops the deck it holds and looks again at every call ("the board you stand on now"), and build 210's
    -- half second, counted from every look, refused the second of two calls made inside it. All four board hops of
    -- 10 Oct (09:55:27, 09:55:37, 09:56:08, 09:56:22) gave the board its speed with "(7 parts ...)" and 64 to 67 ms
    -- later "given once more, as always (0 parts)": nothing was given the second time. What the watch after it gives
    -- again inside that half second would have gone the same way, and the throwdown's second kick, 0.12 s after its
    -- first. The drop-in's own mount looks too, and its hold looks again 0.45 s after he is first seen riding:
    -- refused, that is "the board's parts were not found" and the drop-in let go (on 10 Oct 09:47:41 it got its 7).
    if BD.comp then BD.lookAt = nil end
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
-- (v218) NOT AT A HOP'S START. The object is only there around a settings load / save: 45 of the tester's 45 hops and
-- 7 of the developer's 8 walked every object of the game for nothing, on the frame of the stick click (+19..22 ms on
-- his machine). It is looked for when a pause menu comes up (NATIVE.menuWatch: a walk under a menu is not felt, and
-- that is when the object can be there); a hop takes the kept value.
local function readAdvanced(field, look)
    local opts = look and NATIVE.walkOk() and alive(q(function() return FindFirstOf("OptionsSaveGame") end)) or nil   -- (v210) not now = the kept value
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
    if not NATIVE.walkOk() then return end                      -- (v210) said at a later hop
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
    local ho = NATIVE.HO ~= nil and NATIVE.HO.on == true     -- (v205) the ollie's animation, a test (NATIVE.HO, below)
    if ho then NATIVE.HO.flags() else standUp() end
    q(function() inst.IsFalling        = true  end)
    q(function() inst.IsLanding        = (not ho) or frac >= (tonumber(S.HopOllieLand) or 0.72) end)
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

-- (v205) THE OLLIE'S ANIMATION ON A HIPPIE JUMP (v207: HippieJump = 2, or 3 for one or the other at random; 1 is the hop as it always was).
-- "I believe we are using the jumping or falling animation for the hippie jumps; I would like to try the ollie animation
-- if possible in a test. So don't torch the current configs/code." What the hop plays is the game's "Street Trick
-- PreLand State" (airPose above), reached by standing up out of the crouch. The ollie is another state of the same
-- machine, "Street Trick State": entered from the crouch or the idle on IsTrickPending, it plays the trick blend space
-- of one of the anim instance's two trick slots (FlipTrickAnimSet01 / 02, the one FlipTrickAnimSetIndex names) at
-- FlipTrickPlaybackRate, then goes on to the slot's catch loop (the tucked knees: IsFalling, HasCatchLoop, not landing)
-- and, once IsLanding is up, to the PreLand and landing states the hop has always used. USkaterAnimInstance::
-- SetFlipTrick fills a slot when the game starts a trick (read off the exe: the slot whose trick blend space is this
-- one already, else the other one; the definition's four blend spaces copied in). The same is done here with the
-- stance's ollie -- the definition by the foot position the crouch has -- and the flags are written every frame, as the
-- hop's always were. Only the ANIMATION is the ollie's: the game's pop belongs to its movement component, which goes by
-- the trick it is doing and not by what the graph plays, so the board stays on the ground and rolls on.
-- The trick animation is fitted into HopOllieSpan of the air (the rate from the animation's own length), the tucked loop
-- follows, and IsLanding comes up at HopOllieLand of the air. No stand-up and no dip: the animation has its own pop.
NATIVE.HO = { on = false, DEFS = { [1] = "TRICK_RGS_Ollie", [2] = "TRICK_FKS_Ollie", [3] = "TRICK_NLS_Nollie", [4] = "TRICK_SWS_Ollie" } }
NATIVE.HO.arm = function(kind)
    local H = NATIVE.HO
    H.on, H.rate, H.len, H.s1, H.s2, H.inState = false, nil, nil, nil, nil, nil
    if H.muted then H.quiet(false) end                    -- (v206) should a hop ever have ended without HO.off
    H.tb, H.cb = nil, nil
    -- (v207) "Make it a four-state slider. State one is off, like no jumps. State two is the first animation, our jump
    -- animation. State three is the ollie animation. State four ... let's just do a random one. Then you can drop the
    -- experimental setting." HippieJump: 0 off, 1 the jump animation, 2 the ollie's, 3 one or the other, jump by jump
    local mode = tonumber(S.HippieJump) or 1
    if not inst or not (mode == 2 or (mode >= 3 and math.random() < 0.5)) then return false end
    local cls = q(function() return inst:GetClass():GetFName():ToString() end, "?")
    if cls:find("ABP_AMXX_Skater", 1, true) == nil then
        logOnce("ho-cls", "hop ollie: this is not the skater's own animation blueprint (" .. cls .. ") -- the hop as it was")
        return false
    end
    local fp = q(function() return inst.FootPositionType end, 1)
    local nm = H.DEFS[fp] or H.DEFS[1]
    local d = alive(q(function() return StaticFindObject("/Game/Data/Input/FlipTricks/" .. nm .. "." .. nm) end))
    if not d then logOnce("ho-def" .. nm, "hop ollie: " .. nm .. " is not in memory -- the hop as it was") return false end
    local slotN, len, hasCatch
    local ok, err = pcall(function()
        local set = d.AnimSet
        local tb = alive(set.TrickBlendSpace)
        if not tb then error("the definition has no trick blend space") end
        local cb = alive(set.CatchBlendSpace)
        -- the slot the game's own trick is NOT in (the same one when its trick is this very ollie): see HO.hold
        local idx = tonumber(inst.FlipTrickAnimSetIndex) or 0
        local cur = alive(((idx == 0) and inst.FlipTrickAnimSet01 or inst.FlipTrickAnimSet02).TrickBlendSpace)
        H.own = (cur ~= nil and addr(cur) == addr(tb))
        if not H.own then idx = (idx == 0) and 1 or 0 end
        H.idx, H.tb, H.cb = idx, tb, cb
        slotN, hasCatch = idx + 1, cb ~= nil
        -- how long the animation is: the longest of the blend space's samples (its own AnimLength is only what was last blended)
        pcall(function()
            local sd = tb.SampleData
            for i = 1, sd:GetArrayNum() do
                local an = alive(q(function() return sd[i]:get().Animation end, nil))   -- (v206: :get(), as this file reads its other arrays)
                local l = an and tonumber(q(function() return an.SequenceLength end, nil))
                if l and (not len or l > len) then len = l end
            end
        end)
        if not len then len = tonumber(q(function() return tb.AnimLength end, nil)) end
    end)
    if not ok then
        logOnce("ho-err" .. tostring(err), "hop ollie: the trick slot could not be written (" .. tostring(err) .. ") -- the hop as it was")
        return false
    end
    H.on, H.t0, H.len, H.def, H.slot, H.kind, H.hasCatch = true, os.clock(), len, nm, slotN, kind, hasCatch
    H.hold()
    H.quiet(true)
    return true
end
-- (v206) HELD EVERY FRAME. "If you revert and switch stances it's like he ollies in the wrong direction ... he looks
-- backwards when he ollies." The recording of 9 Oct 20:41:13 (riding switch after a 180 hop, the log saying
-- "TRICK_SWS_Ollie's animation in trick slot 1"): the feet go through the very poses of the REGULAR hop of 20:37:56, to
-- the centimetre, the foot at the back of the way he rolls lifting first and sliding away from it. v205 filled the
-- slot once, at the hop's start -- and USkaterAnimInstance::NativeUpdateAnimation calls SetFlipTrick EVERY frame with
-- the trick the skater did last (skater + 0x590): a slot whose trick blend space is not that one loses the index to
-- the other slot, which is filled with the game's trick again. So the hop played the last trick the GAME did,
-- whatever it was -- the regular ollie all through that session, until one real switch ollie (20:41:18) made the
-- switch hops right. The slot the game's trick is not in is this hop's, and after the game's update the index is put
-- on it every frame, the two blend spaces written again; the game goes on filling the other slot and takes the index
-- back the frame the hop is over.
NATIVE.HO.hold = function()
    local H = NATIVE.HO
    if not inst or not H.tb then return end
    q(function()
        local slot = (H.idx == 0) and inst.FlipTrickAnimSet01 or inst.FlipTrickAnimSet02
        slot.TrickBlendSpace = H.tb
        if H.cb then slot.CatchBlendSpace = H.cb end
        inst.FlipTrickAnimSetIndex = H.idx
        return true
    end)
end
-- (v206) AND QUIET. "It just plays the ollie sound every time he does it, so you're going to have to mute that." The pop
-- of the board is no sound of the game's code here: the ollie's animations carry their sounds as notifies (in
-- AMXX_RGS_Ollie_Hi: AnimNotify_PlaySoundRecorded with SCU_Pop_Hi_Jump and the foot on the grip tape, and
-- AnimNotify_PlaySurfaceTypeSound, which is the same with the ground's kind told to the sound), played whenever the
-- animation is. Read off the exe, UAnimNotify_PlaySoundRecorded::PlaySound hands the notify's own VolumeMultiplier to
-- the sound it starts -- so for the length of the hop every sound notify of the trick's and the catch loop's
-- animations has that at 0, and gets its own back when the hop is over (and before the next hop is silenced, should
-- that ever have been missed). The notifies are read off the blend spaces' animations; where that finds none they are
-- looked for by name, once (every sound notify in memory whose animation is this stance's ollie, the landings left
-- out). HopOllieSound=1 leaves them all as they are.
NATIVE.HO.quiet = function(on)
    local H = NATIVE.HO
    local was = H.muted or {}
    for i = #was, 1, -1 do                                   -- back as they were
        local e = was[i]
        if alive(e.n) then q(function() e.n.VolumeMultiplier = e.vol return true end) end
    end
    H.muted = nil
    if not on or (tonumber(S.HopOllieSound) or 0) ~= 0 then return end
    local list, seen, names, how = {}, {}, {}, "read off its animations"
    local function mute(n)
        local a = n and addr(n)
        if not a or seen[a] then return end
        local cls = q(function() return n:GetClass():GetFName():ToString() end, "")
        if not cls:find("Sound", 1, true) then return end     -- (only a sound notify has the property that is read next)
        seen[a] = true
        local vol = tonumber(q(function() return n.VolumeMultiplier end, nil))
        list[#list + 1] = { n = n, vol = (vol and vol > 0) and vol or 1.0 }
        q(function() n.VolumeMultiplier = 0.0 return true end)
        names[cls] = (names[cls] or 0) + 1
    end
    for _, bs in ipairs({ H.tb, H.cb }) do
        pcall(function()
            local sd = bs.SampleData
            for i = 1, sd:GetArrayNum() do
                local an = alive(q(function() return sd[i]:get().Animation end, nil))
                if an then
                    local nf = an.Notifies
                    for j = 1, nf:GetArrayNum() do mute(alive(q(function() return nf[j]:get().Notify end, nil))) end
                end
            end
        end)
    end
    if #list == 0 then
        how = "found by name"
        local pat = tostring(H.def):gsub("^TRICK_", "AMXX_") .. "_"            -- TRICK_RGS_Ollie -> AMXX_RGS_Ollie_
        H.byName = H.byName or {}
        local found = H.byName[pat]
        if not found and not NATIVE.walkOk() then H.muted = list return end   -- (v210) not now: this hop's ollie is heard, the next hop looks again
        if not found then
            found = {}
            for _, cn in ipairs({ "AnimNotify_PlaySoundRecorded", "AnimNotify_PlaySurfaceTypeSound" }) do
                for _, o in ipairs(q(function() return FindAllOf(cn) end, nil) or {}) do
                    local full = q(function() return o:GetFullName() end, "")
                    if full:find(pat, 1, true) and not full:find("Land", 1, true) and not full:find("Drop", 1, true) then found[#found + 1] = o end
                end
            end
            H.byName[pat] = found
        end
        for _, o in ipairs(found) do mute(alive(o)) end
        if #found > 0 and #list == 0 then H.byName[pat] = nil end             -- (all gone: another level's -- looked for again next hop)
    end
    H.muted = list
    local parts = {}
    for k, v in pairs(names) do parts[#parts + 1] = v .. " x " .. k end
    table.sort(parts)
    local e1 = list[1]
    logOnce("ho-quiet" .. tostring(H.def), string.format("hop ollie: %d sound notifies of %s's trick and catch animations silenced for the hop (%s; %s)%s", #list, tostring(H.def), how,
        (#parts > 0) and table.concat(parts, ", ") or "NONE FOUND: its sounds will be heard",
        e1 and string.format("; the first one's volume reads %s now", tostring(q(function() return e1.n.VolumeMultiplier end, "?"))) or ""))
end
NATIVE.HO.flags = function()                          -- every frame of the hop, where the usual hop stands up
    local H = NATIVE.HO
    if not inst then return end
    local el = os.clock() - (H.t0 or os.clock())
    for i = 1, #BLOCKERS do
        local k = BLOCKERS[i]
        if k ~= "IsTrickPending" then q(function() inst[k] = false end) end
    end
    q(function() inst.CrankPocketRatio = 0.0 end)
    H.hold()                                              -- (v206) after the game's own SetFlipTrick of this frame
    -- (v209 / native v111) "the back foot goes below the board": the ollie's back foot pushes down as the tail would go, and on a
    -- board that stays flat the native half raises the body by it instead, for the first part of the hop (HopOllieDeck)
    if (tonumber(S.HopOllieDeck) or 1) ~= 0 and el < (P.pre or 0) + 0.45 * (airT or 0) and type(HJN_Set) == "function" then pcall(HJN_Set, "hopdeck", 8) end
    if not H.rate then
        local span = (tonumber(S.HopOllieSpan) or 0) * (airT or 0)
        H.rate = (H.len and H.len > 0.1 and span > 0.05) and math.max(0.4, math.min(3.0, H.len / span)) or 1.0
        log(string.format("hop ollie (%s): %s's animation in trick slot %s (%s) -- %s, played x%.2f (to fit %.0f %% of %.2f s of air), then its tucked loop%s; the legs go for the landing from %.0f %% of the air",
            tostring(H.kind), tostring(H.def), tostring(H.slot), H.own and "the game's last trick was this one: its own slot" or "the game's last trick is another: held against it every frame",
            H.len and string.format("%.2f s long", H.len) or "its length not known",
            H.rate, (tonumber(S.HopOllieSpan) or 0) * 100, airT or 0, H.hasCatch and "" or " (this definition has NO catch loop)",
            (tonumber(S.HopOllieLand) or 0.72) * 100))
    end
    -- the way in: up until the machine has taken it (a hop begun while pushing has the push state to leave first), 0.3 s
    -- at most; the state is left by its own rules. Without it the idle goes to the catch loop on IsFalling: no pop, the tuck
    if not H.inState and el < 0.3 and q(function() return inst:GetCurrentStateName(5):ToString() end, "") == "Street Trick State" then H.inState = true end
    q(function() inst.IsTrickPending = (not H.inState) and el < 0.3 end)
    q(function() inst.HasCatchLoop = true end)
    q(function() inst.HasTrickLoop = false end)
    q(function() inst.IsAutoCatching = true end)
    q(function() inst.FlipTrickPlaybackRate = H.rate end)
    q(function() inst.FlipTrickPopRatio = 1.0 end)
    q(function() inst.FlipTrickStanceTransferRatio = 0.0 end)
    -- what the game's machine made of it, twice a hop (the usual "apex" line says it a third time)
    if not H.s1 and el >= 0.15 then H.s1 = true log("   hop ollie, 0.15 s in: " .. stateNow()) end
    if not H.s2 and el >= (P.pre or 0) + 0.88 * (airT or 0) then H.s2 = true log("   hop ollie, 88 % of the air: " .. stateNow()) end
end
NATIVE.HO.off = function()                            -- the hop is over, however it ended
    local H = NATIVE.HO
    if not H.on then return end
    H.on = false
    if inst then q(function() inst.IsTrickPending = false end) end
    H.quiet(false)                                        -- (v206) the animation's sounds back; the slot's index the game takes back itself
    H.tb, H.cb = nil, nil
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
    if not other then other = alive(q(function() return NATIVE.first("SessionPlayerController") end)) end
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
    TD.w, TD.panel, TD.cls, TD.pc, TD.path, TD.full, TD.kept, TD.keptFull = nil, nil, nil, nil, nil, nil, nil, nil
    TD.lines, TD.later, TD.known, TD.veiled, TD.above = {}, {}, {}, {}, {}
end
-- (v218) IS IT THE OBJECT IT WAS? Asked of the object itself, without a look through the game's objects and without
-- a look-up by name. UE4SS 3.0.1's IsValid is: the pointer is there, the engine has not marked the object unreachable,
-- and its address is in UE4SS's own list of the objects it has handed to Lua -- from which the engine's "object
-- deleted" notice takes it the moment the object is freed. So a valid object is a live one at that address: the one
-- that was found, or one made later in the same place. Its full name tells the two apart: an object's number
-- ("PBP_TrickDisplayWidget_C_2147482414") is given once in a run of the game.
TD.same = function(o, full)
    if type(full) ~= "string" or not alive(o) then return false end
    return q(function() return o:GetFullName() end, nil) == full
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
    -- (v218) THE DISPLAY HELD BEFORE THE BAIL, WHERE IT IS STILL THE GAME'S. A bail forgets the display (tdBail), and the
    -- next name looked for it through every object of the game: 0.37 s into the first grab after each bail. The one
    -- that was held is asked first: is it there under the name it had (TD.same), on the screen, and this player's?
    -- Then it is the game's display still, and nothing is walked. Any other answer: the look, as before.
    local kept, keptFull, how = TD.kept, TD.keptFull, "found by a look through the game's objects"
    if keptFull then
        if type(HJN_GcBusy) == "function" and tonumber(q(HJN_GcBusy, -1)) == 1 then return false end   -- the engine is clearing objects out: asked again at the next name
        TD.kept, TD.keptFull = nil, nil
        if TD.same(kept, keptFull) and q(function() return kept:IsInViewport() end, false) == true
            and addr(alive(q(function() return kept:GetOwningPlayer() end))) == pcA then
            found, how = kept, "the one held before the bail (asked: still there, on the screen, this player's) -- no look through the game's objects"
        end
    end
    if not found then
        if not NATIVE.walkOk() then return false end            -- (v210) not now: not counted as a failure, asked again at the next name
        local all = q(function() return FindAllOf(cname) end, nil)
        for _, w in ipairs(all or {}) do
            local full = q(function() return w:GetFullName() end, "")
            if alive(w) and not full:find("Default__", 1, true) then
                local owner = alive(q(function() return w:GetOwningPlayer() end))
                if not found or (owner and addr(owner) == pcA) then found = w end
            end
        end
    end
    if not found then TD.failed = TD.failed + 1 log("   trick names: no " .. cname .. " on screen") return false end
    TD.w, TD.pc, TD.asked = found, pc, nil
    -- (v218) WHAT IT CALLS ITSELF, for the once-a-second check (tdLive, TD.same). NOT looked up by that name: UE4SS
    -- 3.0.1's StaticFindObject is a table of the paths it has found before, and a path that is not in it yet (a new
    -- display's) or not in it any more (a freed one's) is found by going through every object of the game and
    -- writing out the full name of each one in the same package -- a longer walk than the one this replaces.
    TD.full = q(function() return found:GetFullName() end, nil)
    if type(TD.full) ~= "string" or TD.full == "" then TD.full = nil end
    TD.path = nil
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
    log(string.format("   trick names: using %s (tiers %d, %.1fs, scale %.2f..%.2f, alpha %.2f..%.2f, padding %.0f); %s; %s", cname,
        tdNum("NumberOfTiers", 0), tdNum("MaxTextDuration", 0), tdNum("MinTextScale", 0), tdNum("MaxTextScale", 0),
        tdNum("MinTextAlpha", 0), tdNum("MaxTextAlpha", 0), tdNum("TrickDisplayTextWidgetPadding", 0), how,
        TD.full and "checked once a second by asking it its own name (no look through the game's objects)"
            or "checked once a second by a look through all the game's objects (it gave no name)"))
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

-- (v196) A GAME LINE THAT CANNOT BE READ YET IS NOT SEEN YET. "A flip to a grab off a tall ledge: sometimes the tricks come
-- on screen at the same time and overlap." The game puts its new line at the bottom, where the mod's newest one is; the
-- mod's line moves up a tier for it -- but only once the game's line has been read (is it one to hide, an ' Ollie' under
-- a grab's name?), and a line is not read for its first tenth of a second (v141: reading one sooner crashed), half a
-- second when its text is slow to come. For that long the two lay on top of each other. While one of the mod's lines is
-- up, a game line that is new and not read yet is drawn at no opacity; the frame it is read it gets its own back and
-- the mod's line moves up in the same frame, or it is hidden as before. (Only its render opacity: the widget is the
-- game's, in the game's list, exactly where the game put it.)
TD.veiled, TD.above = {}, {}
TD.veilOn = function(c)
    if TD.veiled[c.a] ~= nil then return end
    local a = q(function() return c.w:GetRenderOpacity() end, nil)
    TD.veiled[c.a] = { (type(a) == "number" and a > 0) and a or 1, os.clock() }
    q(function() c.w:SetRenderOpacity(0.0) end)
end
TD.veilOff = function(c)                               -- one line (-> how long it was unseen), or with no argument every one still in the panel
    if c then
        local v = TD.veiled[c.a]
        if not v then return nil end
        TD.veiled[c.a] = nil
        q(function() c.w:SetRenderOpacity(v[1]) end)
        return os.clock() - v[2]
    end
    if next(TD.veiled) == nil then return nil end
    for _, k in ipairs(tdChildren()) do
        local v = TD.veiled[k.a]
        if v then q(function() k.w:SetRenderOpacity(v[1]) end) end
    end
    TD.veiled = {}
    return nil
end

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
    if not TD.cname or not alive(TD.w) then TD.gone = "it is not a valid object any more" return false end
    if TD.full then                                             -- (v218) the object is asked itself (TD.same): nothing is looked up, nothing is walked
        if type(HJN_GcBusy) == "function" and tonumber(q(HJN_GcBusy, -1)) == 1 then return true end   -- the engine is clearing objects out: taken as still there, asked again in a second
        local nm = q(function() return TD.w:GetFullName() end, nil)
        TD.asked = (TD.asked or 0) + 1
        if nm == TD.full then
            logOnce("tdasked", "   trick names: the display was asked its name -- '" .. nm .. "', as when it was found: still the game's (asked once a second from here on; a line only when the answer changes)")
            return true
        end
        TD.gone = "what is at its address now calls itself '" .. tostring(nm) .. "', not '" .. TD.full .. "'"
        return false
    end
    local mine = addr(TD.w)
    if not NATIVE.walkOk() then return true end                 -- (v210) not now: taken as still there, asked again in a second
    for _, w in ipairs(q(function() return FindAllOf(TD.cname) end, nil) or {}) do
        if addr(w) == mine then return true end
    end
    TD.gone = "it is not among the game's " .. TD.cname .. " objects any more"
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
    if (TD.asked or 0) > 0 and (TD.askTold or 0) < 12 then      -- (v218) what the once-a-second check was, for the log
        TD.askTold = (TD.askTold or 0) + 1
        log(string.format("   trick names: the display was asked its name %d time(s) since it was found; the game's objects were not looked through for it", TD.asked))
    end
    TD.asked = nil
    local kept, keptFull = TD.w, TD.full                        -- (v218) not touched while the game rebuilds its display; asked when the next name wants it (tdFind)
    if not kept then kept, keptFull = TD.kept, TD.keptFull end  -- (a second bail before any name of the mod's: what the first one kept is kept)
    NATIVE.forgetUi()
    TD.kept, TD.keptFull = kept, keptFull
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
    TD.veilOff()                                         -- (v196) every game line as the game drew it, before it is pushed up
    local before = tdChildren()
    local slot = alive(q(function() return TD.panel:AddChild(line) end))
    if not slot then TD.failed = TD.failed + 1 log("   trick names: AddChild failed") return false end
    q(function() slot:SetAlignment({ X = 1.0, Y = 1.0 }) end)
    for _, c in ipairs(before) do if not isMod(c.a) then tdNudgeGame(c) TD.above[c.a] = true end end   -- (v196) remembered: not a new line when it is read later
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
    for a in pairs(TD.veiled or {}) do if not seen[a] then TD.veiled[a] = nil end end   -- (v196)
    for a in pairs(TD.above or {}) do if not seen[a] then TD.above[a] = nil end end
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
            log("   trick names: the game rebuilt its trick display (" .. tostring(TD.gone or "?") .. ") -- ours forgotten, found afresh for the next name")
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
    if NATIVE.rawMode() == 6 then
        TD.hideUntil = nil
        -- (v208) ...AND NOT LEFT UP FOR THE WHOLE REPLAY. "A lot of the trick names are staying on the screen during the replay
        -- editor." v150 left the mod's lines alone in this mode -- their clock stands still here, so a name up when the editor
        -- opened stayed for as long as it was open (the game's own lines fade by themselves). The widget reads that crashed
        -- on 3 Oct were made in the very frames a bail threw the game into this mode: so half a second in, and only when the
        -- once-a-second check above has just found the display to be the game's own still, the mod's lines are taken out.
        TD.m6At = TD.m6At or now
        if #TD.lines > 0 and now - TD.m6At >= 0.5 and alive(TD.panel) and now - (TD.validAt or -1e9) <= 1 then
            local n = #TD.lines
            for i = n, 1, -1 do tdDrop(i) end
            log(string.format("   trick names: %d of ours taken off the screen -- the replay editor (or a replay camera) is up", n))
        end
        return
    end
    TD.m6At = nil
    local hiding = TD.hideUntil and now < TD.hideUntil
    if not alive(TD.panel) then TD.lines = {} TD.hideUntil = nil return end
    if #TD.lines == 0 and not hiding then
        TD.veilOff()                                     -- (v196) none of ours is up: nothing of the game's stays unseen
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
                local unseen = TD.veilOff(c)                  -- (v196) seen from this frame on, and ours moves up in this frame
                if tx and NATIVE.gameLine then pcall(NATIVE.gameLine, tx, now) end
                if hiding and tdHidden(c, tx) then TD.above[c.a] = nil
                elseif TD.above[c.a] then                     -- (v196) pushed above ours when ours was put up: ours stays where it is
                    TD.above[c.a] = nil
                    log("   trick names: the game's '" .. tostring(tx or "?") .. "' line was up, unread, when ours was put under it -- ours stays (it used to be moved up onto it)")
                else
                    bumped = bumped + 1
                    if #TD.lines > 0 then
                        log(string.format("   trick names: the game's '%s' line came up %.2f s after ours -- ours moved up a tier%s", tostring(tx or "?"), now - TD.lines[#TD.lines].t0,
                            unseen and string.format(" (it was kept unseen for the %.0f ms until it could be read)", unseen * 1000) or ""))
                    end
                end
                seen[c.a] = true                              -- (v109) hidden or not, it is known now
            elseif (#TD.lines > 0 or hiding) and not TD.above[c.a] then
                TD.veilOn(c)                                  -- (v196) not read yet: not seen yet (one already pushed above ours is in nobody's way)
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
-- (v199) THE GAME'S LEFT-FOOT / RIGHT-FOOT STICK MODE. "There is a stick input mode. I play front and back foot: my left
-- stick is always front and right is always back. The other mode is left and right foot, so depending on which way the
-- player is facing the sticks swap. We need to tap into that mode and switch our grabs around -- find what flag the game
-- uses itself, and just swap RB and LB for the grabs." The game's own grab pick (InAirHandler::CheckForGrabs, read off the
-- exe) is LB + the left stick = the front hand's six grabs, RB + the right stick = the back hand's six -- EXCEPT when
-- IsSkatingSwitch and the controller's input mode is not FrontFootBackFoot (EInputModeType: 1 LeftFootRightFoot,
-- 2 FrontFootBackFoot, 3 Legacy; InputHandler+0x20, the controller's reflected GetInputModeType): then RB + the right
-- stick picks the front hand's and LB + the left stick the back hand's. The mod's own pick (the map below) knew only the
-- first half, so in that mode, riding switch, it handed the game the other hand's grab. GR.swap() is the game's test;
-- every place of the mod's that tells LB from RB asks it: the air grabs, the two-hand grabs, the click grabs, and the
-- hand on the board while riding (the rolling grab, the boneless, the bean plant, the finger flip). Each stick keeps
-- its own reading (the right stick's Y is the other way round in the game's read, whichever hand it picks for).
-- GrabFollowStickMode=0 switches it off.
GR.MODE_NAME = { [0] = "none", [1] = "left foot / right foot", [2] = "front foot / back foot", [3] = "legacy" }
GR.swap = function(now)
    if S.GrabFollowStickMode == 0 then return false end
    now = now or os.clock()
    if not GR.modeAt or now - GR.modeAt > 1 or now < GR.modeAt then
        GR.modeAt = now
        local pc = alive(SB.pc) or (alive(s0) and alive(q(function() return s0:GetController() end)))
        local m = pc and tonumber(q(function() return pc:GetInputModeType() end, nil)) or nil
        if m ~= nil and m ~= GR.mode then
            GR.mode = m
            log(string.format("grabs: the game's stick mode is '%s' (%d) -- %s", GR.MODE_NAME[m] or "?", m,
                (m == 1 or m == 3) and "LB is the LEFT hand and RB the right, as the sticks are the left and the right foot: they change places whenever the left foot is the back one (a regular rider riding switch, a goofy rider riding forward)"
                    or "LB is the front hand and RB the back hand, whichever way you ride"))
        elseif m == nil and GR.mode == nil then
            logOnce("grabmode", "grabs: the game's stick mode could not be read (GetInputModeType) -- LB stays the front hand")
        end
    end
    -- (v200) ...BY THE FEET, NOT BY THE GAME'S GRAB PICK. "I think you have it reversed." v199 took the game's own test
    -- (switch, and not the front-foot / back-foot mode), and the game's grab pick does not look at goofy: for the goofy
    -- rider of 7 Oct 23:18-23:20 it left LB the front hand riding forward -- his RIGHT hand, with the left stick his
    -- left, back, foot -- and made it the back hand riding switch, where his left foot leads. The sticks themselves the
    -- game does turn for goofy (InputHandler::ConvertToCurrentInputModeInput takes switch AND goofy): in this mode the
    -- left stick is the left foot whoever rides and however. So LB is the left hand: the back hand whenever the left
    -- foot is the back foot -- a regular rider riding switch, a goofy rider riding forward.
    return (GR.mode == 1 or GR.mode == 3) and ((NAT.goofy == true) ~= (NAT.switch == true))
end
-- (v201) THE STICK POINTS AT THE SIDE OF THE BOARD THE HAND GOES TO. "A left stick, left direction plus the left bumper
-- should be the Mute, and to the right the Melon. And vice versa for the right side" -- from a goofy rider. The game's
-- map is right = the toe-side grabs (Mute, Taipan / Indy, Canadian Bacon), left = the heel-side ones, whoever rides:
-- right IS the toe side for a regular rider rolling forward, the camera behind him -- and the heel side for a goofy
-- one, whose toes point left (7 Oct 23:32: left gave him the Stalefish and the Melon, right the Indy and the Mute).
-- The click grabs have had it by the board from the start (grabDirection: "goofy, or rolling switch/fakie, flips
-- that"); the bumpers' map takes the same rule. GrabToeSide: 1 = by the rider (this), 0 = right always, 2 = left always.
GR.toeLeft = function()
    local how = tonumber(S.GrabToeSide) or 1
    if how < 0.5 then return false elseif how > 1.5 then return true end
    return (NAT.goofy == true) ~= (NAT.switch == true)
end
-- the game's own grab pick's test (v199's): it differs from GR.swap for a goofy rider, and only there
GR.gameSwap = function() return (GR.mode == 1 or GR.mode == 3) and NAT.switch == true end
NATIVE.grabSwap = GR.swap                              -- (the hand on the board is outside this block, where GR is not known)
local function gameGrabFor(bumper, x, y, swap)
    local front = (bumper == "LB") ~= (swap == true)       -- (v199) the front hand's grabs, or the back hand's
    if math.sqrt(x * x + y * y) < 0.3 then
        local name = front and S.GrabLBNeutral or S.GrabRBNeutral
        return type(name) == "string" and GRAB_ID[name:lower():gsub("[%s_%-]", "")] or nil
    end
    -- the game reads the right stick with Y the other way round (its RightStick_Y is +1 pulled DOWN): the
    -- v64 log had it pick Tail for RB with the right stick pushed UP. Same map as the game, so flip it.
    if bumper == "RB" then y = -y end
    local a = math.atan(x, y) / math.pi
    local m, right = math.abs(a), a > 0
    if GR.toeLeft() then right = not right end           -- (v201) 'right' below = toward the toes
    local id
    if front then
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
GR.DOUBLES = { { "Cannonball", 200, "Cannonball" }, { "Gorilla", 201, "Gorilla Grab" }, { "Rocket", 202, "Quasimodo" },   -- (v129) the third is the display name
               -- (v205) "A double grab that is both bumpers with a left or right stick direction ... depending on stance
               -- could be a melon or a mute plus an indy or a stalefish ... technically 4 button/stick states, our current
               -- gorilla the one with both sticks toeside." Skateboarding has no names for the other three; snowboarding
               -- has all of them (chosen: the snowboard names). Each stick picks toe side or heel side for its own hand by
               -- the map the one-hand grabs go by (gameGrabFor: the stick mode, the stance, the toes' side), so the four
               -- states fall out of the pairs: toe + toe the Gorilla, heel + toe the Truck Driver, toe + heel the Drunk
               -- Driver, heel + heel the Squirrel.
               { "TruckDriver", 203, "Truck Driver" }, { "DrunkDriver", 204, "Drunk Driver" }, { "Squirrel", 205, "Squirrel" } }
GR.EDGE = { [201] = true, [203] = true, [204] = true, [205] = true }      -- (v205) the two-hand grabs on the board's edges: the ones that bone
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
    GR.setId, GR.setAt = id, os.clock()                  -- (v202) the mod's own: GR.ownPick leaves it alone
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

-- (v202) A GRAB THE GAME PICKED ITSELF GOES BY THE MOD'S MAP TOO. "Mute and Indy should always be toe-side grabs: the
-- stick direction should match depending on the stance, not be the same every time. Riding goofy my toes point left, so
-- an Indy is the right bumper and the right stick to the LEFT; in switch they point right, and it is the right stick to
-- the RIGHT ... a dynamic system instead of a stale direction always equals a certain grab." v201 did that for the
-- grabs the MOD picks -- but with a stick already pushed when the bumper comes down, the game's catch-orient is up and
-- its own pick takes the grab in that very frame, by its own map: right = the toe-side grabs for everyone, LB = the
-- front hand whatever the feet. The mod's latch then found a grab held and stood back. 7 Oct 23:45-23:47, one goofy
-- rider, rolling forward: bumper and stick together (the mod's pick) left = Mute, left = Indy, right = Stalefish; stick
-- first (the game's) right = Mute twice, left = Melon twice, right = Indy -- "stale". So a grab that appears without
-- the mod having handed it over is looked at once, the tick it appears: where the game's map is not the mod's (the
-- toes are on the left, or the bumpers have changed places and the game's own swap has not) the mod's map is asked,
-- with the bumper that was pressed (the latch's; else the one the game's pick goes by) and the DIRECTION of its stick
-- alone -- the game picks by direction at any deflection -- and the game is handed that grab instead. Elsewhere the
-- game's pick stands, as it always has. Twice a grab at most; not with both bumpers down (the two-hand grabs').
GR.ownPick = function(now, native)
    local sw, toeLeft = GR.swap(now), GR.toeLeft()
    if not toeLeft and sw == GR.gameSwap() then return native end           -- the game's map is the mod's here
    if type(HJN_Bumpers) == "function" and (tonumber(HJN_Bumpers()) or 0) == 3 then return native end
    local bumper = (GR.want and GR.want.bumper) or (((native < 100) ~= GR.gameSwap()) and "LB" or "RB")
    local stick = (bumper == "LB") and "Left" or "Right"
    local x, y = stickNow(stick, now)
    local mag = math.sqrt(x * x + y * y)
    if mag < 0.05 then return native end                                    -- (no direction to go by)
    local id = gameGrabFor(bumper, x / mag, y / mag, sw)
    if not id or id == native then return native end
    GR.ownFixes = (GR.ownFixes or 0) + 1
    if not grabSet(id, string.format("%s in the air: the game picked the %s itself (the %s stick was pushed first: %.2f,%.2f) -- by its own map, which has %s -> %s",
            bumper, grabTitle(native), stick, x, y,
            ((native < 100) ~= (id < 100)) and "this bumper as the other hand in this stick mode" or "the toe side on the right for everyone (yours is on the left now)",
            grabTitle(id))) then return native end
    GR.kick, GR.kicks = { id = id, at = now, bumper = bumper }, GR.kicks + 1
    local n2 = q(function() return s0:GetGrabState() end, 0) or 0
    return (type(n2) == "number" and n2 ~= 0) and n2 or id
end

local function grabLatchTick(now, native)
    local wnt = GR.want
    if wnt then
        local stick = (wnt.bumper == "LB") and "Left" or "Right"
        local x, y, how = stickNow(stick, now)
        local mag = math.sqrt(x * x + y * y)
        if native ~= 0 then                               -- the game picked one itself (its catch-orient was up)
            local sw = GR.swap(now)
            GR.want, GR.pick = nil, { bumper = wnt.bumper, at = now, swap = sw }
            -- (v202: a grab the game picked against the mod's map has been put right before this is called -- GR.ownPick)
        elseif mag >= 0.5 or now - wnt.t0 >= S.GrabWait then
            GR.want = nil
            local sw = GR.swap(now)                          -- (v199) the game's own swap of the bumpers, as it is at the pick
            local id = gameGrabFor(wnt.bumper, x, y, sw)
            if not id then log(string.format("%s in the air: no grab for that direction", wnt.bumper)) return end
            if grabSet(id, string.format("%s in the air: %s (%s stick %s %.2f,%.2f, chosen %.0f ms after the press)%s -- handed to the game",
                wnt.bumper, grabTitle(id), stick, how, x, y, (now - wnt.t0) * 1000,
                sw and " [left/right-foot sticks, the left foot is the back one: this bumper is the " .. ((id < 100) and "front" or "back") .. " hand's]" or "")) then
                GR.kick, GR.kicks = { id = id, at = now, bumper = wnt.bumper }, GR.kicks + 1
                GR.pick = { bumper = wnt.bumper, at = now, swap = sw }
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
    local id = gameGrabFor(pk.bumper, x, y, pk.swap)
    if id and id ~= native then
        grabSet(id, string.format("   ...switched to %s (stick %.2f,%.2f)", grabTitle(id), x, y))
    end
end

-- (v205 - v208) THE BONE came with the three edge pairs: "curious if there is a way to tweak them ... not a rocket or dip this
-- time, but to 'bone' them", and of the ways to read it "board toward the nose: the front leg straightens and pokes the board
-- forward along its length while the back knee stays tucked; the board stays level". v205 waited for the right stick
-- pulled DOWN (the game's read of that stick is the other way up: v206), then for both sticks within 20 degrees of
-- straight up (v207: the diagonal) -- and all along the native half pushed the hips more down than back (native v111).
-- (v209) ROTATE OR BONE, FOR EVERY GRAB. "The setting should be a rotate versus bone setting. Something like just the base
-- melon grab: we should be boning that, but right now that move creates a rotational move, which is not bad -- some
-- players may want that instead ... even the double grabs might benefit from this: they can either bone or they can
-- either rotate." GrabTweakStyle: 0 = the stick moved off where it picked the grab TWISTS the legs and the board (the
-- game's own tweak, through the gate in GR.tweak); 1 = the same move BONES the grab instead -- the body goes back over
-- the back foot and the board is poked out toward the nose, Bone<Grab> cm (+ GrabAllBone) at the full swing -- and the
-- game is shown no swing at all. A grab whose own Bone is 0 (the grabs on the board's tips) twists in either style.
-- The swing is the gate's: GrabTweakDead degrees of play, full GrabTweakRamp further, either way round; a stick that
-- was centred at the pick counts by how far it is pushed. A one-hand grab goes by its own stick, a two-hand grab by
-- whichever stick is swung further (once its pick is settled: a pair picked with a stick still centred may yet change).
GR.KEY = {}
for _, g in ipairs(NATIVE.GRABS) do GR.KEY[g[2]] = g[1] end
GR.boneCm = function(kind)                             -- cm this grab bones by; 0 = it twists
    if (tonumber(S.GrabTweakStyle) or 0) == 0 then return 0 end
    local own = tonumber(S["Bone" .. tostring(GR.KEY[kind] or "?")]) or 0
    if own <= 0 then return 0 end
    return math.max(0, own + (tonumber(S.GrabAllBone) or 0))
end
GR.stickOf = function(native, now)                     -- the stick a ONE-hand grab was picked with
    local k, p = GR.kick, GR.pick
    local b = (k and k.id == native and (k.bumper == "LB" or k.bumper == "RB") and k.bumper) or (p and p.bumper)
        or ((((native < 100) ~= (GR.swap(now) == true))) and "LB" or "RB")
    return (b == "LB") and "Left" or "Right"
end
-- (v211) WHAT MOVES IN A BONE, AND THE HANDS STAY ON. "During the tweak move the hands just come off the board ... it
-- just has to not move. ... in the game the bones are happening by the body moving backwards. IRL it would be the
-- opposite, where the torso, the upper body stays put and the board moves. I got a feeling that's going to break a
-- lot of stuff though. So we can try it, but be revert ready." (9 Oct.) Measured on that night's 15 boned grabs: past
-- 16 cm of bone the hand's spot itself was slid toward the tail (an Indy's hand went 20.8 cm along the edge), and with
-- the arm at 98 % of its length and the lean at its 40 deg limit the hand also lifted 5 to 9 cm off the board. Both
-- were the native half's own doing. v113 mends them, and three settings go to it (NATIVE.hands):
--   GrabBoneHands  1 = the spots stay put, the back may lean GrabBoneLean deg further (25) to keep the hand on, and
--                  what the arm still cannot reach the bone gives back on the same pose; 0 = the hands of v112;
--   GrabBoneMove   0 = the body goes back over the back foot (what ships); 1 = THE TEST: the real board is pushed out
--                  toward the nose under a body that stays. The game only holds the board off its place that way in
--                  an air that began with a pop: in any other air the body goes back, as with 0.
-- Revert: "Bone moves" 0 in the menu (GrabBoneMove=0) is the body's way with the new hands; GrabBoneHands=0 as well is
-- build 210's bone. What moved is in the grab's "bone:" line below.
-- (v212) HOW FAR OUT. "I feel like the tweak is working, but it's not moving as much as I would hope. So maybe double the
-- limit or more of the tweak slider in the menu, and I'll try that out." (10 Oct.) That morning's 13 boned grabs, on the
-- native trace and in the pose recorder: the slider was never what held them. Every one stopped where the hips came
-- over the back foot's place on the board -- 16-21 cm of bone in the one-hand grabs, 22-28 in the Truck Driver -- with
-- 45 to 73 cm asked; "All grabs: bone distance" went 30 -> 40 in mid-session and the next Melon was asked 19.6 for the
-- 19-20 before. That stop was a rule of the native half's (v111), not the rig's: the front leg stood at 45-74 % of its
-- length there and the arms allowed 60. So:
--   GrabBoneBehind     cm the hips may end BEHIND the back foot's place (20; the menu's "Boned grabs: how far out");
--                      0 = build 211's stop. What holds a bone then is the front leg's reach and the arms (native
--                      v114). A two-hand grab gets it only where the board is what moves;
--   the ranges         doubled as asked -- the menu's slider to 80, GrabAllBone to 100 and every Bone<Grab> to 90 in
--                      the ini, the native half's own stops 60 -> 80 -- but they are not the lever: with 20 behind a
--                      Melon's or a Mute's slider is used up from about +25, and nothing ever moves more than 80;
--   GrabBoneShowStick  "some tricks the board moved forward and some tricks the guy moved backwards": the grabs picked
--                      with the stick centred (GR.tweak, below).
GR.boneK = { Left = 0, Right = 0 }
GR.boneSet = function(amt, title, cm, key)             -- told to the native half when it changes; said once a grab
    if type(HJN_Set) ~= "function" then return end
    if amt ~= GR.boneNow then
        GR.boneNow = amt
        pcall(HJN_Set, "bone", amt)
    end
    if amt > 0.5 and key ~= nil and GR.boneSaid ~= key then
        GR.boneSaid = key
        local old = (tonumber(NATIVE.v) or 0) < 113           -- (v211) which of the two moves, and what the hands do
        local board, hands = not old and (tonumber(S.GrabBoneMove) or 0) ~= 0, not old and (tonumber(S.GrabBoneHands) or 1) ~= 0
        -- (v212) ...and how far out it may go, so that the distance is not read as a promise: it is what is ASKED, and
        -- on 10 Oct every bone was held at 16-28 cm of 45-73 by the hips over the back foot's place. With the native
        -- half v114 and the hands staying on, that stop is GrabBoneBehind's (two hands: only where the board moves)
        local far = ""
        if hands and (tonumber(NATIVE.v) or 0) >= 114 then
            local behind = tonumber(S.GrabBoneBehind) or 0
            if GR.dbl and not board then far = ", and no further than where the hips are over the back foot's place (two hands get GrabBoneBehind only where the board is what moves) or a hand would come off"
            elseif behind > 0 then far = string.format(", and no further than where the hips are %g cm behind the back foot's place (GrabBoneBehind%s), the front leg is straight or a hand would come off",
                behind, GR.dbl and "; two hands: only while the board is what moves" or "")
            else far = ", and no further than where the hips are over the back foot's place (GrabBoneBehind 0) or a hand would come off" end
            if (tonumber(cm) or 0) > 80 then far = far .. "; 80 cm is the most that is ever moved" end
        end
        log(string.format("   bone: the %s is boned (a stick swung off where it picked the grab) -- %s: %s cm at the full swing%s; %s",
            tostring(title),
            board and "the BOARD is pushed out toward the nose and the body stays (GrabBoneMove 1; in an air that began without a pop the body goes back over the back foot instead)"
                   or ("the body goes back over the back foot, the board out toward the nose" .. (old and "" or " (GrabBoneMove 0)")),
            tostring(cm), far,
            hands and string.format("the hands stay on their spots: the back may lean %g deg further to keep them on, and what the arm cannot reach the bone gives back", tonumber(S.GrabBoneLean) or 0)
                   or (old and "the native half is older than v113: the bone and its hands are as before build 211" or "the hands as before build 211 (GrabBoneHands 0)")))
    end
end
GR.tweak = function(now, native)
    local boneCm = (native ~= 0) and GR.boneCm((GR.dbl and GR.dbl[2]) or native) or 0
    if native ~= 0 and GR.gate and AS.mode and (S.GrabTweakGate ~= 0 or boneCm > 0) then   -- (v125) from the first frame: the stick the game is shown is deflected, so its catch comes from it
        local pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
        if pc then
            SB.pc = pc
            -- (v212) ...AND A SECOND CHANCE for a pick the game is shown pushed (THE CENTRED PICK, below). From no catch at
            -- all the game takes one only on the tick a stick BECOMES pushed (its CanCatchOrient, read off the exe: a
            -- stick counts if it was not pushed last tick and is now), and only if its other conditions hold on that
            -- very tick (the controller's action flags, no pop pending). A stick shown pushed from the grab's first
            -- frame gives it exactly one such tick. So where the game still has no catch 0.15 s on, the stick is shown
            -- centred for ONE tick -- the next tick's push is a fresh one -- three times a grab at most. One decision a
            -- tick, so both sticks of a two-hand grab drop together. (On the tick of the mod's own nudge, v118, the
            -- state reads as a catch until the game clears it: no drop on that tick, the next one decides.)
            local stickDrop = false
            if GR.stickShown and (GR.stickTries or 0) < 3 and now - (GR.stickEdgeAt or GR.stickShown) > 0.15
                and type(HJN_CatchState) == "function" and (tonumber(HJN_CatchState()) or 0) <= 0 then
                GR.stickTries, GR.stickEdgeAt, stickDrop = (GR.stickTries or 0) + 1, now, true
            end
            local function masked(which)
                local x, y = analogStick(which)
                if not x then return nil end
                local b = GR.gate[which]
                local m = math.sqrt(x * x + y * y)
                if boneCm > 0 then
                    -- (v209) THIS GRAB BONES (GrabTweakStyle 1): the swing is the bone's, and the game is shown the stick as it
                    -- stood at the pick -- straight, or centred -- so none of its own twist comes with it
                    local centred = (not b) or b[3] < 0.3
                    local k = 0
                    if centred then k = math.max(0, math.min(1, (m - 0.3) / 0.4))                 -- picked with the stick centred: pushing it
                    elseif m >= 0.25 then
                        local rel = (math.deg(math.atan(y, x)) - b[4] + 180) % 360 - 180
                        k = math.max(0, math.min(1, (math.abs(rel) - S.GrabTweakDead) / math.max(1, S.GrabTweakRamp)))
                    end
                    GR.boneK[which] = k
                    if centred then
                        -- (v212) THE CENTRED PICK HAD NO CATCH, SO NO BOARD TO MOVE. "I also feel like some tricks the board
                        -- moved forward and some tricks the guy moved backwards." 10 Oct, Bone moves on 1: 8 boned grabs
                        -- went by the board and 2 by the body -- the Gorilla of 09:45:27 and the Indy of 09:46:21, the two
                        -- picked with no stick. The native trace reads 'catch-orient state 0' on every line of both, and
                        -- without that state the game does not read the board's offset. Its catch comes from the sticks
                        -- (v57 / v118: its handler rebuilds the state every tick from which sticks are pushed), and this
                        -- gate showed it a centred one. So while the board is what a bone moves, such a grab is shown its
                        -- stick pushed straight, from its first frame -- exactly what a grab picked with the stick is
                        -- shown ('return 0, m, 1' below). One hand: its own stick; two hands: both, where neither was
                        -- pushed at the pick (sent as +1 and -(+1) like every pair's: the game's state 5, never its
                        -- dark-slide 10 / 11 -- the minus on the right stick's Y further down is not to be tidied away).
                        -- Such a grab then has the game's catch whether you bone it or not: the game's own board offset
                        -- for that state and a deck that follows the board bone, as a stick-picked one always had.
                        -- Read off the exe and the trace, NOT yet seen in the game: the log says what came of it.
                        -- GrabBoneShowStick 0 = as build 211; so is GrabBoneHands 0 (there no board is ever moved).
                        local ob = GR.gate[(which == "Left") and "Right" or "Left"]
                        local mine = (GR.dbl and ((not ob) or ob[3] < 0.3)) or ((not GR.dbl) and which == GR.stickOf(native, now))
                        if mine and (tonumber(S.GrabBoneMove) or 0) ~= 0 and (tonumber(S.GrabBoneHands) or 1) ~= 0
                            and (tonumber(S.GrabBoneShowStick) or 1) ~= 0 and (tonumber(NATIVE.v) or 0) >= 113 then
                            GR.stickShown = GR.stickShown or now
                            if stickDrop then return 0, 0, 1 end        -- one tick centred: the next tick's push is a fresh one
                            return 0, 1, 1
                        end
                        return 0, 0, 1
                    end
                    return 0, m, 1
                end
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
            GR.boneK.Left, GR.boneK.Right = 0, 0
            local lx2, ly2, lk = masked("Left")
            local rx2, ry2, rk = masked("Right")
            if boneCm > 0 then                               -- (v209) what the swing comes to: a one-hand grab's own stick, a two-hand grab's further one
                local amt = 0
                if not GR.dbl then amt = GR.boneK[GR.stickOf(native, now)] or 0
                elseif (GR.dblPick and GR.dblPick.both) or now - (GR.dblT0 or now) > S.GrabRepick then amt = math.max(GR.boneK.Left or 0, GR.boneK.Right or 0) end
                GR.boneSet(amt, (GR.dbl and GR.dbl[3]) or grabTitle(native), boneCm, (GR.dbl and GR.dblT0) or GR.nativeT0)
            elseif (GR.boneNow or 0) ~= 0 then GR.boneSet(0) end
            if not GR.gateLogged and ((lk and lk < 1) or (rk and rk < 1)) then
                GR.gateLogged = true
                log(string.format("   tweak gate: the game is shown the stick straight along the vertical, your swing as its sideways part (picks: L %.0f deg, R %.0f deg): dead %g, ramp %g",
                    GR.gate.Left[4], GR.gate.Right[4], S.GrabTweakDead, S.GrabTweakRamp))
            end
            pcall(function()
                if lx2 then pc:SimulateInput_LeftStick_X_Axis(lx2)  pc:SimulateInput_LeftStick_Y_Axis(ly2) end
                if rx2 then pc:SimulateInput_RightStick_X_Axis(rx2) pc:SimulateInput_RightStick_Y_Axis(-ry2) end
            end)
            -- (v212) THE CENTRED PICK SHOWN PUSHED: what came of it, said once, 0.3 s in -- and once more where the game had
            -- no catch by then: when it has one, or when the three more pushes are used up. Never read on the tick
            -- of the mod's own nudge (v118: its SetCatchOrient reads as a state until the game clears it the next frame)
            if GR.stickShown and GR.stickShownSaid ~= 2 and GR.catchAt ~= now then
                local cs = type(HJN_CatchState) == "function" and (tonumber(HJN_CatchState()) or 0) or nil
                local what = tostring((GR.dbl and GR.dbl[3]) or grabTitle(native))
                if not GR.stickShownSaid and now - GR.stickShown >= 0.3 then
                    GR.stickShownSaid = (cs == nil or cs > 0) and 2 or 1
                    log(string.format("   tweak gate: the %s was picked with the stick centred -- the game is shown it pushed straight so that it has its catch (GrabBoneShowStick 1): catch-orient state %s after 0.3 s (%d more pushes)",
                        what, tostring(cs or "?"), GR.stickTries or 0))
                elseif GR.stickShownSaid == 1 and cs and (cs > 0 or ((GR.stickTries or 0) >= 3 and now - (GR.stickEdgeAt or now) > 0.15)) then
                    GR.stickShownSaid = 2
                    log((cs > 0) and string.format("   tweak gate: ...the %s has its catch now: catch-orient state %d, %.2f s after its stick was first shown, %d more pushes", what, cs, now - GR.stickShown, GR.stickTries or 0)
                        or string.format("   tweak gate: ...the %s never had a catch: catch-orient state 0 after %d more pushes -- with no catch the board cannot be moved, the body is what bones this grab", what, GR.stickTries or 0))
                end
            end
        end
    end
end

-- (v97) every air frame: the two-hand grabs. Returns the game's grab as it is after this.
GR.doubleTick = function(now, native, cm)
    if GR.dbl and (cm ~= MODE_AIR or (native == 0 and now - (GR.dblT0 or 0) > 0.15)) then   -- the grab is over, the two-hand grab with it
        log(string.format("   two-hand grab %s ended after %.2fs", GR.dbl[3], now - (GR.dblT0 or now)))
        GR.lastKind, GR.dbl, GR.dblLock = GR.dbl[2], nil, true     -- (the next one needs a bumper let go first)
        GR.dblPick = nil                                          -- (v209: the bone goes with the game's grab -- GR.boneSet(0) in the grab tick)
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
    local sw = GR.swap(now)                                  -- (v199) which is the front hand's grab and which the back's does not matter to the pair
    local idL, idR = gameGrabFor("LB", lx, ly, sw), gameGrabFor("RB", rx, ry, sw)
    local d = idL and idR and GR.doubleFor(idL, idR)
    local ml, mr = math.sqrt(lx * lx + ly * ly), math.sqrt(rx * rx + ry * ry)
    -- (v205) "Both sticks must be pushed": the Truck Driver, Drunk Driver and Squirrel need each stick pushed to its side.
    -- With one stick alone (a centred stick is the toe-side grab of its hand) the pair is the Gorilla, as with none
    if d and d[2] >= 203 and S.DoubleBothSticks ~= 0 and (ml < 0.3 or mr < 0.3) then
        for _, e in ipairs(GR.DOUBLES) do if e[2] == 201 then d = e end end
    end
    -- (v205) a pair picked with both sticks pushed to a side stays an edge grab: both sticks UP from there is the bone,
    -- not a Cannonball (a Gorilla begun with a stick still centred becomes one inside GrabRepick, as before)
    if d and GR.dbl and GR.EDGE[GR.dbl[2]] and GR.dblPick and GR.dblPick.both and not GR.EDGE[d[2]] then return native end
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
    -- (v205) where the sticks stood at this pick (degrees off straight up, and how far out): the bone is measured from
    -- here. And the game's tweak too, for an edge pair picked with both sticks: its gate kept the sticks as they were when
    -- the BASE grab began -- a stick still centred then is shown to the game as it is, and pushed full to a side for the
    -- pair that is the game's whole twist at once
    GR.dblPick = { both = (ml >= 0.3 and mr >= 0.3) }
    GR.boneSaid, GR.boneNow = nil, nil
    if GR.dblPick.both and GR.gate then
        GR.stickShown, GR.stickTries, GR.stickEdgeAt = nil, nil, nil   -- (v212) picked with both sticks pushed: no centred pick any more, the game has the real sticks' catch
        local gx, gy = analogStick("Left")
        if gx then GR.gate.Left = { gx, gy, math.sqrt(gx * gx + gy * gy), math.deg(math.atan(gy, gx)) } end
        gx, gy = analogStick("Right")
        if gx then GR.gate.Right = { gx, gy, math.sqrt(gx * gx + gy * gy), math.deg(math.atan(gy, gx)) } end
    end
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
    -- (v199) the click grabs' two lists are the front hand's (GrabLeft...) and the back hand's (GrabRight...): the same swap
    local name = S["Grab" .. (GR.swap(now) and ((stick == "Left") and "Right" or "Left") or stick) .. dir]
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
        local sw = GR.swap(now)                              -- (v199) the bumper that picks this hand's grabs now
        local bumper = ((native < 100) ~= sw) and "LB" or "RB"
        local x, y = stickNow((bumper == "LB") and "Left" or "Right", now)
        local id = gameGrabFor(bumper, x, y, sw)
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
    -- (v202) a grab that is new this tick and not one the mod handed over = the game's own pick: by the mod's map too
    if native == 0 then GR.ownFixes = 0
    elseif native ~= GR.native and cm == MODE_AIR and not GR.dbl and (GR.ownFixes or 0) < 2
        and not (GR.setId == native and now - (GR.setAt or -1e9) < 0.5) then
        local okf, natf = pcall(GR.ownPick, now, native)
        if okf and type(natf) == "number" then native = natf
        elseif not okf then logOnce("ownpick", "   grab map error: " .. tostring(natf)) end
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
            GR.boneNow, GR.boneSaid = nil, nil               -- (v209) the first amount of this grab is told, whatever the last one's was
            GR.stickShown, GR.stickShownSaid, GR.stickTries, GR.stickEdgeAt = nil, nil, nil, nil   -- (v212) nor is the last grab's centred pick this one's (GR.tweak)
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
    if native == 0 and (GR.boneNow or 0) ~= 0 then GR.boneSet(0) end           -- (v209) the bone ends with its grab
    GR.tweak(now, native)                                    -- (v108 / v209) the game's tweak, gated -- or the bone: GR.tweak, further up
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
    -- (v199) from here on 'lb' is the FRONT hand's bumper and 'rb' the BACK hand's: in the game's left-foot / right-foot
    -- stick mode they change places whenever the left foot is the back one (GR.swap). Kept as it was when the hand went on: a turn with the
    -- hand on the board must not read as the bumper let go. (NATIVE.grabSwap: GR is a local of the grabs' block)
    do
        local sw
        if GG.kind then sw = GG.swap == true else sw = (NATIVE.grabSwap and NATIVE.grabSwap(now)) == true GG.swap = sw end
        if sw then lb, rb = rb, lb end
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
        elseif not held then why = string.format("%s let go (the pad reads %s)", ((GG.kind == 102) ~= (GG.swap == true)) and "RB" or "LB", btn and string.format("0x%04x", btn) or "no XInput")
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
            log(string.format("rolling grab: %s held %s -- the %s hand goes to the %s spot on the board (the hips down to %g cm over the deck, %g cm at most; the back up to %g deg)", ((want == 102) ~= (GG.swap == true)) and "RB" or "LB",
                (inNC and "in a no comply" or "on the board") .. (GG.swap and " [left/right-foot sticks, the left foot is the back one: LB and RB have changed places]" or ""), GG.left and "left" or "right", (want == 102) and "Indy's" or "Mute's", S.GroundGrabHips, S.GroundGrabCrouch, S.GroundGrabLean))
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
    -- (v212) ...nor while a hop onto the board holds your body's turn in the mesh (BoardHopTurnHold, NATIVE.hopTry). A
    -- stamp, not a flag: the hop renews it at every tick it writes the mesh, so a hop that dies half way leaves a stamp
    -- that runs out in 0.3 s, and this watch then puts the mesh back a quarter second on
    if active or YS.t0 or BY.pending or RV.pending or BV.pending or swapLive or (NATIVE.hopTurnUntil ~= nil and os.clock() < NATIVE.hopTurnUntil) then Y.offAt = nil return end
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
    -- (v203) THE QUEUE IS RUN FROM ANY SKATER'S FRAME. "I couldn't grab or hippie jump any more after switching to the beach
    -- map" (9 Oct). At 17:56:29 UE4SS had stopped running what the mod hands to its game thread (v185's case: eight seconds
    -- after two Win+Alt key presses in the replay editor), and the frame hook ran the queue instead -- but only on a frame
    -- of the skater the mod HOLDS. The one thing that takes up a new map's skater is the 2 s tick, and that is in the
    -- queue: at 18:05:28 the beach map's skater came, no frame was "ours" any more, the queue was never run again, and
    -- the mod never learned of the skater it was waiting for. (The night before the same build followed two map changes:
    -- UE4SS was running the queue then.) The pump does not need the skater to be ours -- any skater's frame is the game
    -- thread -- so it comes first.
    pcall(NATIVE.gtPump)                                                             -- (v185)
    if not isMine(ctx) then return end
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
            if NATIVE.HO.on then NATIVE.HO.flags() else standUp() end   -- (v205)
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
        if P.dip == 0 and S.Pose ~= 0 then if NATIVE.HO.on then NATIVE.HO.flags() else standUp() end end   -- (v205)
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
            RegisterHook(HOOK, function(ctx) NATIVE.timed(onFrame, ctx) end,       -- (v218) timed: a frame the mod makes long is said (NATIVE.slow)
                               function(ctx) NATIVE.timed(onFramePost, ctx) end)
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
    if NATIVE.HO and NATIVE.HO.on then NATIVE.HO.off() end  -- (v205) every way a hop ends comes through here
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
    if kind == "hippie" and S.HippieJump == 0 then logOnce("hjoff" .. math.floor(os.clock() / 10), "hippie jumps are switched off (HippieJump=0; the menu's Hippie jumps)") return end   -- (v136)
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
    if S.Pose ~= 0 and NATIVE.HO.arm(kind) then P.pre, P.dip = math.max(0, tonumber(S.HopOlliePre) or 0.06), 0 end   -- (v205) the ollie's animation, a test

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
    -- (v209) ...AND A PRESS THAT IS OVER IS NO CROUCH. "If I did a hippie jump and then just pressed one of the sticks, it
    -- would do another hippie jump ... it seemed like there was a window after the hippie jump that allowed that."
    -- 9 Oct 22:02:49: 'L3 click  the Right stick Down | held, 0.27s ago, crouched=false -> JUMP  [sticks L 0,0 R 0,0]', and
    -- again 1.78, 2.91, 1.59 and 3.00 s after the crouch of the jump before -- 'held' only ever meant that a push of the
    -- stick had been SEEN, and one up to FRESH (4 s) old counted as the crouch (v105: for the frames the game's own crank
    -- flag lags a push). With a read of the sticks themselves the crouch is a stick that is pushed NOW (the paired one, or
    -- v135's other one) or the game's own flag; the remembered press counts only where there is no such read.
    local function pushedNow(st)                             -- true / false, and its y; nil = no read of this stick
        if not NATIVE.analog then return nil end
        local ax, ay = NATIVE.analog(st)
        if not ay then return nil end
        return math.abs(ay) >= 0.5, ay
    end
    local o = (stick == "Right") and "Left" or "Right"
    local p1, y1 = pushedNow(stick)
    local p2, y2 = pushedNow(o)
    if p1 then dir, at, held, age = (y1 > 0) and "Up" or "Down", now, true, 0
    elseif p2 then stick, dir, at, held, age = o, (y2 > 0) and "Up" or "Down", now, true, 0      -- (v135: the crouch on the clicked stick's own side)
    elseif p1 == nil and age > FRESH then                    -- (no read at all: v135 by the key presses)
        local d2, a2, h2, g2 = fresh(o)
        if h2 and g2 <= FRESH then stick, dir, at, held, age = o, d2, a2, h2, g2 end
    end
    local crouched = crouching()
    local freshOk = (age <= FRESH) and (p1 == nil or p1 == true or p2 == true)
    local ok = (S.NeedCrouch == 0) or (held and (crouched or freshOk))
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
    -- (v198) a pause menu is up (NATIVE.mg.a, from the look four times a second) and this press reached the game: see NATIVE.menuWatch
    if NATIVE.mg and NATIVE.mg.a and NATIVE.menuWatch and (key:find("^Gamepad_DPad_") or key == "Gamepad_FaceButton_Bottom" or key == "Gamepad_FaceButton_Right") then
        NATIVE.gt(function() pcall(NATIVE.menuWatch, key) end)
    end
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

-- (v211) WHAT THE OTHER MODS SAY IS KEPT IN THIS LOG. "Got another fatal error crash in the last session" (9 Oct
-- 23:30:15, and 19:00:08 before it): both in the first seconds of a new map, in the engine's own drawing, nothing of
-- this mod's on the game, render or crashing thread. The one thing caught using dead objects in that window is
-- SessionTweaks: its log has "[quad] pump faulted (1)" at 23:30:15.358 and "(2)" at .562, and the crash followed at once
-- (three more at the map change of 23:25:55, which the game survived). But SessionTweaks.log and SessionOpenMP.log
-- start again at every launch: for the crashes of 19:00 and 22:37 nothing of theirs was left to read. This log is kept
-- over a launch. So their fault lines and their level-change lines are copied into it as they are written: looked at
-- every 50 ms (the first fault line came 204 ms before the crash; a slower look would miss it), from the byte the look
-- before stopped at. The FIRST look starts at the log's end -- with SessionTweaks switched off for a test, its log of
-- the session before is still on disk and must not be told again as this session's; a log that has become SHORTER has
-- started again and is read from its start. Only whole lines are taken (the rest waits for the next look), 500 a
-- session at most. "fault" is not taken where it is the end of "default" or a count ("faults=3", SessionOpenMP's
-- statistics). Nothing of the game is touched; it runs on UE4SS's own timer thread, like the pad's tail above.
NATIVE.STW = { n = 0, files = {
    { TWKLOG, "SessionTweaks", { "faulted", "FAULTED", "caught fatal", "replay mode 1 -> 0", "garment component is gone", "new character", "garment component BUILT" } },
    { "SessionOpenMP.log", "SessionOpenMP", { "[drop/map]", "own pawn", "fault", "FAULT" } } } }
NATIVE.stwHit = function(line, words)                    -- does the line hold one of the words (as plain text)?
    for _, w in ipairs(words) do
        local p = 1
        while true do
            local a, b = line:find(w, p, true)
            if not a then break end
            if not ((a > 2 and line:sub(a - 2, a + 4):lower() == "default") or line:sub(b + 1, b + 2) == "s=") then return true end
            p = b + 1
        end
    end
    return false
end
NATIVE.stwTail = function()
    local T = NATIVE.STW
    for _, F in ipairs(T.files) do
        local size = sizeOf(F[1])
        if size then
            if F.pos == nil then F.pos = size elseif size < F.pos then F.pos = 0 end   -- the first look: from its end; shorter than it was: it started again
            if size > F.pos then
                local f = io.open(F[1], "rb")
                if f then
                    f:seek("set", F.pos)
                    local chunk = f:read(math.min(size - F.pos, 262144)) or ""
                    f:close()
                    local lastNL = chunk:match("^.*()\n")
                    if lastNL then
                        F.pos = F.pos + lastNL
                        for line in chunk:sub(1, lastNL):gmatch("[^\r\n]+") do
                            if NATIVE.stwHit(line, F[3]) then
                                T.n = T.n + 1
                                if T.n <= 500 then log(F[2] .. " said: " .. line:sub(1, 200))
                                elseif T.n == 501 then log("the other mods' logs: 500 of their lines are in this log now -- no more are copied this session") end
                            end
                        end
                    elseif #chunk >= 262144 then F.pos = F.pos + #chunk end   -- (a quarter megabyte without a line end: passed over)
                end
            end
        end
    end
end
LoopAsync(50, function()
    local ok, err = pcall(NATIVE.stwTail)
    if not ok then logOnce("stwerr", "the other mods' logs: the look at them failed: " .. tostring(err)) end
    return false
end)
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
        { "slider", "ThrowdownScale", "Throwdown speed", 100, 10, "How fast the game's own throwdown (Y on foot) sends you off, as a percentage (%) of the speed you were moving at. 100 = unchanged. The throw plays faster to match. Standing still, nothing is added.", 1, 4, unit = "%" },
        { "toggle", "StickTurn", "Left stick steers the board", 1, 1, "On: the game's own steering, where pushing the left stick sideways leans and turns the board. Off: only the triggers turn you, so doing a stick trick no longer pulls the board off its line." },
        { "toggle", "TrickNames", "Show trick names", 1, 1, "Shows this mod's tricks in the game's trick display when you land them, for example 180 Hippie Jump, Crail Grab, No Comply, Boneless or Bean Plant. Off: none of them are shown." },
        { "slider", "AutoUpdate", "Automatic updates", 1, 1, "0 = off. 1 = tells you, in the log and on the trick display, when a new version of the mod is out. 2 = also downloads it from the mod's GitHub page, checks it and installs it for the next time you start the game.", 0, 2 },
    } },
    { "Hippie Jumps", {
        { "slider", "HippieJump", "Hippie jumps", 1, 1, "Hold one stick down to crouch, then click the other stick (L3 or R3) to jump off the board while it rolls on. 0 = off. 1 = the jump animation. 2 = the ollie animation. 3 = one or the other at random, jump by jump.", 0, 3 },
        { "toggle", "MiniHop", "Allow mini hippie jumps", 1, 1, "A small, quick hop off the board: click both sticks (L3 + R3) at the same time. No crouch is needed. Its height is set by Mini hippie jump height." },
        { "slider", "Height", "Hippie jump height", 1, 5, "How high your body rises off the board in a hippie jump, in centimetres (cm). 60 = a low jump, 95 = a medium one, 150 = a big one.", 30, 220, unit = "cm" },
        { "slider", "MiniHeight", "Mini hippie jump height", 1, 5, "How high your body rises off the board in a mini hippie jump, in centimetres (cm).", 20, 120, unit = "cm" },
        { "toggle", "Varial", "Allow rotation in hippie jumps", 1, 1, "Hold a trigger (LT or RT) while you are in the air to spin your body above the board. A half turn is a 180 and lands you switch, a full turn is a 360." },
        { "toggle", "VarialBail", "Bail on a bad rotation", 1, 1, "On: landing too far from a clean half or full turn makes you bail, as it would on a real board. Off: your body is turned the rest of the way for you and you ride away." },
        { "toggle", "VarialInvert", "Swap the rotation triggers", 1, 1, "Swaps which trigger spins you which way. Turn it on if LT and RT rotate you the opposite way to what feels natural." },
        { "toggle", "BoardHop", "Allow jumping onto the board", 1, 1, "On foot next to your board lying on the ground (after a bail, for example), click a stick (L3 or R3) to jump onto it and ride away the way you are facing." },
        { "slider", "BoardHopSpeedScale", "Jumping onto the board: speed", 100, 10, "How fast you roll away after jumping onto your board, as a percentage (%) of the speed you ran up to it at. 100 = as fast as you ran. 0 = the board only keeps its own roll. Standing still, nothing is added.", 0, 3, unit = "%" },
        { "slider", "BoardHopSpeedAcross", "Jumping onto the board: side-on run-ups", 100, 10, "A board only rolls along its length. 0 = only the part of your run-up that points along the board counts, so running at it from the side gives no speed. 100 = all of your speed counts, from any side.", 0, 1, unit = "%" },
    } },
    { "Drop-ins", {
        { "toggle", "DropIn", "Allow drop-ins", 1, 1, "On foot at the edge of a ledge, bank or ramp, press Y (Triangle) to set up with the tail on the edge. Then push a stick up to drop in, press LB or RB to go back onto the ledge, or Y to step off." },
        { "slider", "DropInSpeed", "Drop-in launch speed", 0.036, 1, "How fast the board is launched when you drop in, in km/h: down a ramp, or straight out over a plain ledge. 10 km/h is about 6 mph.", 0, 2000, unit = "km/h" },
        { "slider", "DropInPitch", "Drop-in deck angle", 1, 5, "How steeply the deck points up from the tail while you wait on the edge, in degrees. It is raised by itself when a coping is in the way.", 0, 45, unit = "degrees" },
        { "slider", "DropInArms", "Drop-in: arms out for balance", 1, 5, "How far your arms come up and out to your sides for balance as you tip in and drop, in degrees. About 60 is as far as they go. They drop again once you ride away or land. 0 = the game's own arms.", 0, 80, unit = "degrees" },
        { "slider", "DropInArmsFull", "Drop-in arms: full at a drop of", 1, 10, "The height of drop that gets all of the arms slider, in cm. A smaller drop gets its share: with 200, a 1 m drop gets half. Small drops, small arms; big drops, big arms.", 30, 500, unit = "cm" },
        { "slider", "DropInArmsPeak", "Drop-in arms: fully out at", 1, 5, "How far down the drop your arms are fully out, in percent of its height. 50 = halfway down. They rise with the way down from the moment you drop in.", 10, 100, unit = "%" },
        { "slider", "DropInCrouch", "Drop-in: crouch", 1, 1, "How far your hips go down as you drop in, in cm, on a drop of the full height (a smaller drop gets its share). The knees bend and you lean toward the drop; holding the crouch stick takes you further down. 0 = no crouch.", 0, 40, unit = "cm" },
        { "slider", "DropInCrouchPeak", "Drop-in crouch: lowest at", 1, 5, "How far down the drop you are at your lowest, in percent of its height. The tip-in itself takes you halfway there.", 10, 100, unit = "%" },
        { "toggle", "DropInNoTwist", "Drop-in: hold the shoulder twist", 1, 1, "On: the game's own twist of the upper body, which swings the back arm behind you as the board tips in, is held off until you are down. Off: the game's own." },
        { "slider", "DropInRange", "Drop-in edge distance", 1, 10, "How close to the edge you have to stand to set up a drop-in, in centimetres (cm) from the middle of your body. Higher = you can set up from further back.", 20, 200, unit = "cm" },
        { "slider", "DropInFace", "Drop-in facing limit", 1, 15, "How far off straight toward the drop you may face and still set up, in degrees to either side. 30 = up to 30 degrees left or right. 0 = no limit, any direction works.", 0, 180, unit = "degrees" },
        { "slider", "DropInVertSpeed", "Vert wall: launch speed", 0.036, 1, "On a ramp that goes vertical at the top: how fast the board is let go, in km/h. Lower lets the wheels meet the wall sooner; the wall itself gives you speed.", 0, 2000, unit = "km/h" },
        { "slider", "DropInVertBoost", "Vert wall: speed boost", 0.036, 1, "On a vert wall: extra speed added down the wall once the wheels are riding it, about 0.3 seconds after the board is let go, in km/h.", 0, 2000, unit = "km/h" },
        { "slider", "DropInVertTilt", "Vert wall: nose-down tilt", 1, 5, "On a vert wall: how far the board is tipped nose-down before it is let go, in degrees. It has to be steep so the wheels meet the wall instead of flying out over it.", 20, 89, unit = "degrees" },
        { "slider", "DropInVertBack", "Vert wall: push toward the wall", 0.036, 1, "On a vert wall: how fast the board is pushed back toward the wall as it is let go, in km/h. It helps the wheels catch a wall that hangs back under the coping.", 0, 400, unit = "km/h" },
        -- (v212) the variant has its own switch, so one test compares both ways without a new build (his ini has DropInSetDown=1)
        -- (v213) the two test rows of builds 211 and 212 are gone: the set-down on the coping IS the drop-in now (DropInSetDown and DropInSetEdge stay in the ini)
    } },
    { "Grabs", {
        { "toggle", "GrabStart", "Allow grabs", 1, 1, "Hold LB or RB in the air to grab, let go to release. LB = front hand with the left stick, RB = back hand with the right. Push toward your toes for Mute or Indy, toward your heels for Melon or Stalefish." },
        { "toggle", "DoubleGrabs", "Allow two-hand grabs", 1, 1, "Hold LB and RB together in the air for a two-hand grab. The two grabs your sticks point at make the pair: Cannonball, Gorilla, Quasimodo, or with both sticks to a side Truck Driver, Drunk Driver or Squirrel." },
        { "slider", "GrabTweakStyle", "Grab tweak", 1, 1, "What moving the stick off its grab direction does while you hold a grab. 0 = rotate: your legs and the board twist. 1 = bone: the board is poked out toward the nose; your back leans further to keep the hand on. See Bone moves.", 0, 1 },
        { "slider", "GrabAllBone", "All grabs: bone distance", 1, 1, "With Grab tweak on bone: centimetres (cm) added to what each grab asks for at the full swing of the stick. How far the board really goes is held by Boned grabs: how far out. 0 = no change.", -20, 80, unit = "cm" },
        { "slider", "GrabBoneBehind", "Boned grabs: how far out", 1, 5, "With Grab tweak on bone: how far a boned board may go. 0 = until your hips are over your back foot, as before. Higher = that many centimetres (cm) further. It stops where the front leg is straight or a hand would come off.", 0, 45, unit = "cm" },
        { "slider", "GrabBoneMove", "Bone moves", 1, 1, "With Grab tweak on bone: what moves. 0 = your body goes back over the back foot. 1 = a test: your body stays and the board is pushed out toward the nose, in airs that began with a pop (in other airs as 0).", 0, 1 },
        { "slider", "GrabBoneLean", "Boned grabs: extra lean", 1, 5, "How much further your back may lean toward the board while a grab is boned, so that the hand stays on it, in degrees. 0 = no further: the bone gets smaller wherever the arm cannot reach.", 0, 45, unit = "degrees" },
        { "slider", "GrabHeadUp", "Grabs: head up", 1, 5, "How far your head is raised in a grab, at the most, in degrees: you look ahead instead of down at the deck. It stops by itself when you look just under level. 0 = the head as the game has it.", 0, 90, unit = "degrees" },
        { "slider", "GrabHeadTurn", "Grabs: head toward travel", 1, 5, "How far your gaze is turned toward the way you travel in a grab, at the most, in degrees. It stops by itself when you look that way. 0 = not turned.", 0, 90, unit = "degrees" },
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
    local own = S.MenuOwnPages ~= 0
    if type(HJN_Set) == "function" then
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
        -- (v224) the user dropped the Quick settings page from the mod's own nested pages; it stays only as what
        -- SessionOpenMP's one flat page shows (MenuOwnPages=0)
        if not (own and pg[1] == "Quick") and (tonumber(HJN_MenuPage(pg[1])) or 0) > 0 then
            pages = pages + 1
            for _, r in ipairs(pg[2]) do
                local kind, key, label, scale, step, desc = r[1], r[2], r[3], r[4], r[5], r[6]
                local sp = by[key]
                if kind == "page" then
                    if not (own and key == "Quick") and (tonumber(HJN_MenuRow(3, key, label, desc, 0, 0, 0, "", "")) or 0) > 0 then rows = rows + 1 end   -- (review: it returns the page's running count)
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
    local all = q(function() return NATIVE.all("PBP_SkateboardEx_C") end)
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
        if tostring(S.RecordPoses) ~= NATIVE.set101 then            -- (v189) native v101: the pose recorder is off unless the ini asks -- (v196) which it does as it ships: RecordPoses
            NATIVE.set101 = tostring(S.RecordPoses)
            pcall(HJN_Set, "posedump", (tonumber(S.RecordPoses) or 0) ~= 0 and 1 or 0)
            log("native: the pose recorder is " .. (((tonumber(S.RecordPoses) or 0) ~= 0) and "ON (ExpandedTricks.poses.bin)" or "off (RecordPoses=1 switches it on)"))
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
    parts[#parts + 1] = tostring(S.GrabAllAlong) .. "/" .. tostring(S.GrabAllAcross) .. "/" .. tostring(S.GrabAllUp) .. "/" .. tostring(S.GrabAllBone) .. "/" .. tostring(S.GrabTurnedSense) .. "/" .. tostring(S.GrabHeadUp) .. "/" .. tostring(S.GrabHeadTurn) .. "/" .. tostring(S.GrabBoneMove) .. "/" .. tostring(S.GrabBoneHands) .. "/" .. tostring(S.GrabBoneLean) .. "/" .. tostring(S.GrabBoneBehind)   -- (v184; v207; v211; v212)
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
                    if p[1] == "Bone" then v = (v > 0) and math.max(0, v + (tonumber(S.GrabAllBone) or 0)) or 0 end   -- (v207) "a global boned setting ... a global adder for all of them" (v209: where a grab has a bone)
                    HJN_GrabSet(g[2], p[3], v)
                end
            end
        end
    end
    HJN_Set("handavoid", S.NativeHandAvoid)
    HJN_Set("grabstance", S.NativeGrabStance)              -- (v119) the tail layout for every grab
    HJN_Set("catchhold", S.NativeCatchHold)               -- (v116) the deck keeps following the bone through the game's grabs
    HJN_Set("lateblock", S.GrabBlockFlips)               -- (v97) no late flips out of a grab
    pcall(HJN_Set, "turnsense", S.GrabTurnedSense)       -- (v207 / native v110) a deck that turned round in this air is steered the other way
    pcall(HJN_Set, "boneboard", S.GrabBoneMove)          -- (v211 / native v113) a boned grab: 1 = the board moves out and the body stays, 0 = the body goes back
    pcall(HJN_Set, "bonehands", S.GrabBoneHands)         --   1 = its hands stay on their spots (0 = as v112)
    pcall(HJN_Set, "boneleanadd", S.GrabBoneLean)        --   deg the back may lean further to keep them there
    pcall(HJN_Set, "headup", S.GrabHeadUp)             -- (v213) the head in a grab: raised by this much at the most (native v115; an older one answers 0)
    pcall(HJN_Set, "headturn", S.GrabHeadTurn)         --   and turned toward the way of travel
    pcall(HJN_Set, "hophead", S.BoardHopHead)          -- (v216) the hop onto the board: the head kept level (native v117)
    pcall(HJN_Set, "bonebehind", S.GrabBoneBehind)       -- (v212 / native v114) cm its hips may end behind the back foot's place: how far out it goes (0 = no further than over it, as v113)
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
    -- (v212) A SKATER THAT LIVES IS DROPPED (the 2 s loop found a new one and lets go of all it held): the look that
    -- comes after is not the menus' look over again, and the half second is not counted against it. skater() already
    -- sees to that -- a skater held alive means the last look found one -- so this says it a second time, at the one
    -- place the skater is dropped, for whoever calls this next. A skater that is gone (dead) changes nothing here.
    if alive(cached) then NATIVE.WK.skAt = nil end
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
    NATIVE.WK.lvlAt = os.clock()                          -- (v210) see NATIVE.walkOk
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
        -- (v212) ON LEVEL GROUND ONLY. The reading is world z, and on a bank the capsule stands along the board's up: 85 cm
        -- reads 65 on a 40 deg transition. 10 Oct, after the quarter pipe of 09:47-09:49: the four hops landed 67, 70,
        -- 77 and 77 cm over the deck where all 13 hops of 9 Oct had 83 to 85 and every session's first reading is 85 --
        -- 8 to 18 cm low, the arc's last 23 to 55 ms spent pushing the capsule into the ground. In three of the four
        -- the engine landed you on foot by itself 66, 51 and 33 ms before the mount (SessionTweaks.log: "movement
        -- 1/0"), and the game had to lift you back to riding height after it: a part of "every time he lands on the
        -- board, it's still a bit sketchy. It jitters" (only a part: he saw it on 9 Oct too, at 83 to 85). A deck that
        -- leans more than 10 deg is not read; what was read on the flat is kept. Nor is one read round a drop-in (the
        -- mod places the board's parts itself while it holds them).
        -- THAT THE TILT PULLED THE AVERAGE DOWN IS A FIT, NOT A MEASUREMENT: the three drop-in holds of that session
        -- lasted 1 to 3 s and the riding between them is in no log. So a LEVEL reading more than 4 cm from the average
        -- is said (once in 20 s at the most): if such a line ever shows a level reading far from 85, the tilt was not
        -- the cause, and the line has what was read
        if (d.upz or 0) >= 0.985 and not (NATIVE.dropBusy and NATIVE.dropBusy()) then
            local first = HOP.rideZ == nil
            if not first and math.abs(off - HOP.rideZ) > 4 and os.clock() - (HOP.rideSaid or -1e9) > 20 then
                HOP.rideSaid = os.clock()
                log(string.format("board hop: riding height read %.0f cm on level ground, the average stands at %.0f", off, HOP.rideZ))
            end
            HOP.rideZ = first and off or (HOP.rideZ + (off - HOP.rideZ) * 0.2)
            if first then log(string.format("board hop: the skater rides %.0f cm over the deck (the hop lands there)", off)) end
        end
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
                    -- (v211) A NEW SIDE ONLY AFTER FIVE READINGS IN A ROW (this runs every 2 s: 8 s of the one side); the first
                    -- one is taken as it comes. 9 Oct: "toes point to the right" was read four times, each in the second of a
                    -- powerslide try, and at 22:57:05 you stepped off the board with that wrong side stored -- a hop then
                    -- would have flown you facing the other side of the deck. FIVE, not three: a fifth wrong one, at
                    -- 23:20:31 with no powerslide (what it was is not known), was only read back at 23:20:37 -- it may have
                    -- stood for three turns of this loop. The side is a constant of the stance: a slow yes costs nothing
                    HOP.chestN = (HOP.chestSeen == side) and ((HOP.chestN or 0) + 1) or 1
                    HOP.chestSeen = side
                    if HOP.chest == nil or HOP.chestN >= 5 then
                        HOP.chest = side
                        log(string.format("board hop: riding, your toes point to the %s of the way the capsule faces -- a hop lands you facing that way", side > 0 and "right" or "left"))
                    end
                else
                    HOP.chestN, HOP.chestSeen = 0, nil
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
        local rideZ = (HOP.rideZ or S.BoardHopRideZ) + math.max(0, tonumber(S.BoardHopLandLift) or 0)   -- (v212) BoardHopLandLift over the riding height: clear of the ground, so that the game's own landing does not cut in before the mount (the game lets you down the rest)
        HOP.p1 = { d.x + HOP.bv[1] * rem, d.y + HOP.bv[2] * rem, d.z + HOP.bv[3] * rem + rideZ }
        local H = HOP.nose and d.yaw or (d.yaw + 180)
        HOP.H = H                                                     -- (v211) the way you will roll: the end taken as the front (the speed goes that way)
        HOP.yc = HOP.sw and (H + 180) or H                            -- the capsule's yaw ON the board: with the roll, against it in switch (the game turns the board to the capsule)
        HOP.y1 = HOP.y0 + wrapA(HOP.yc + HOP.side * 90 - HOP.y0)     -- in the air: the chest to the toe side, the feet along the deck
        HOP.ym = (HOP.sw and HOP.fix) and (HOP.yc + 180) or HOP.yc    -- (v211) the yaw HANDED TO the mount: the game's switch mount turns the capsule half a turn itself (see hopTry; HOP.fix = BoardHopSwitchFix as it stood at the click)
        HOP.c1 = (HOP.c1 or HOP.y0) + wrapA(HOP.ym - (HOP.c1 or HOP.y0))   -- (v212) where the capsule's yaw ends when it is turned to the mount on the way (BoardHopTurnHold 1): the yaw handed over, the short way round from where you faced -- and from where it stood a tick ago, so a board that turns under the hop cannot flip it the long way round
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
        -- (v211: true of a regular hop only -- in a switch mount the game turns the capsule half a turn first, see below)
        local side = HOP.chest or (NAT.goofy and -1 or 1)                -- (NAT is the global frame table; visualGoofy is out of scope here)
        local now = os.clock()
        -- (v211) A SWITCH HOP NO LONGER SWINGS YOU HALF A TURN AS YOU LAND. 9 Oct, twelve mounted hops: the six regular
        -- ones ended standing as planned, all six switch ones half a turn from it (nose-first and tail-first alike), and
        -- five of those six lost "switch" within the second. For a switch mount (foot position 4) the game's
        -- ApplyToggleOnBoard turns the capsule half a turn ITSELF (exe 0xfeaca0) before the board is snapped to it. The
        -- hop handed over the yaw it wanted you to ride at (yc): you flew with your chest to one side of the deck and
        -- were stood on it with it to the other, facing along the roll, which the game calls not-switch. Now a switch
        -- hop is handed over half a turn round (HOP.ym, hopAim) and the game's own turn lands the capsule on yc.
        -- THE FLIP FLAG GOES WITH IT -- the two change together, or the deck spins under you instead. v78's rule (switch
        -- XOR tail-first) kept the deck's heading only because the capsule had been turned away; with the capsule
        -- ending on yc the deck keeps its heading when the flag says "riding tail-first", switch or not.
        -- BoardHopSwitchFix=0 = build 210's yaw and flag
        -- ...AND BOTH FROM ONE READING OF THE SETTING, made here (HOP.fix). The flag is fixed at the click, the yaw is
        -- worked out again on every tick of the hop (hopAim) and read the setting as it stood THEN: an ini saved in the
        -- 0.45 s of a switch hop would have handed over one half of the pair without the other
        local fix = S.BoardHopSwitchFix ~= 0
        local flipFlag = (sw ~= (not nose))
        if fix then flipFlag = not nose end
        -- (v211) HOW FAST YOU RAN UP TO IT, for the speed the board gets at the mount (BoardHopSpeedScale): the movement
        -- component's Velocity, or the mesh's own travel over the ground when that says more (after a SessionTweaks run-out
        -- Velocity reads 0 for half a second while you run on: v180). Its way: Velocity's, else the way you face
        local rv = q(function() return mv.Velocity end, nil)
        local rx, ry = rv and (tonumber(rv.X) or 0) or 0, rv and (tonumber(rv.Y) or 0) or 0
        local rvel = math.sqrt(rx * rx + ry * ry)
        local rmesh = type(HJN_MeshSpeed) == "function" and tonumber(HJN_MeshSpeed()) or -1
        local rsp, rhow = rvel, "the game's Velocity"
        if rvel >= 30 then rx, ry = rx / rvel, ry / rvel else rx, ry = math.cos(math.rad(F)), math.sin(math.rad(F)) end
        if rmesh > 30 and rmesh > rvel and rmesh < 1200 then rsp, rhow = rmesh, (rvel >= 30) and "the mesh's own travel" or "the mesh's own travel, taken the way you face" end
        -- (v212) NO QUARTER-TURN FLICK AS YOU LAND -- AN EXPERIMENT (BoardHopTurnHold): reasoned from the code, not yet
        -- seen in any recording. In the air the capsule faces a quarter turn off the ride (your chest to the toe side);
        -- the last frame turned it to the yaw the mount wants; and the game's anim blueprint then draws a SNAPSHOT of
        -- the on-foot pose (root state OnFootToOnBoard, entered with no blend) and crossfades to the riding pose in
        -- 0.15 s. The on-foot pose faces along the capsule, the riding pose stands side-on to it: so the body would
        -- snap a quarter turn in one frame and turn back over 0.15 s, at every mount, regular and switch -- "every
        -- time he lands on the board, it's still a bit sketchy. It jitters". Now your body's facing through the hop
        -- stays what it was, but wherever the capsule does not face the chest's way the MESH's yaw against its capsule
        -- carries the difference (setYaw, the hippie jump's own way), and that turn is let out as the game's blend
        -- turns the pose (the watch in hopTick):
        --   1 = the capsule is eased to the mount's yaw over the whole arc (hopping on the way you ran it hardly turns
        --       at all), and nothing turns on the last frame;
        --   2 = the capsule flies as in build 211 and the mesh takes up the turn on the last frame only -- for when the
        --       capsule turned on the way shows anything odd on foot (the camera, another mod);
        --   0 = build 211.
        -- It rests on the snapshot being drawn as it was taken and on the blend turning the pose the short way; where
        -- one of them does not hold the body is off by up to a quarter turn for those 0.15 s, as it is today. The
        -- frame lines (NATIVE.hopFrame, column t) say what it did, with the hold on and with it off.
        -- ON REGULAR HOPS ONLY, UNLESS BoardHopTurnHoldSwitch. A quarter turn, a HALF on a switch hop: there the hold
        -- also rests on the game turning its snapshot with the capsule's own half turn, and of the function that takes
        -- the snapshot (SaveFootToBoardTransition) only a switch test (exe+0xf61fe6) and a half-turn about up have been
        -- read, not the whole. If it does not turn it, the hold would spin you half a turn for those 0.15 s -- which
        -- would read as "it still rotates 180" and muddle the test of the real fix for that (BoardHopStanceLock). So a
        -- switch hop flies as build 211 until its frame lines have been seen. What they must show, hold off, on the
        -- first riding frame: column t near the yaw HANDED OVER (the snapshot was turned with the capsule: the hold's
        -- arithmetic is right as it stands and BoardHopTurnHoldSwitch can go on), or near the capsule's RIDING yaw (not
        -- turned: the mesh's turn for a switch mount must then be the chest against the riding yaw, not against the
        -- yaw handed over). Both yaws are in the frame lines' legend
        local th = math.floor((tonumber(S.BoardHopTurnHold) or 0) + 0.5)
        HOP = { on = true, t0 = now, rideZ = HOP.rideZ, chest = HOP.chest,
                p0 = { loc.X, loc.Y, loc.Z }, b0 = { d.x, d.y }, bp = { d.x, d.y, d.z }, bt = now, bv = { 0, 0, 0 },
                y0 = F, nose = nose, sw = sw, side = side, flip = flipFlag, fix = fix, d0 = d.yaw,
                -- (v213) THE BODY'S HEADING IS KEPT BY THE NATIVE HALF NOW (BoardHopKeep, native v115: the note at HopKeep there).
                -- 10 Oct, the frame lines of four hops: in the three that had no hold the toes went 71 -> -16 on the arc's last
                -- frame (the capsule handed to the mount) and came back over eight frames of the game's blend: "for like one
                -- frame when he lands just does that 90 degree turn ... and then he tweaks back 90 again". In the one that had
                -- build 212's hold: 29 -> 2 -> 53 -> 63 -> 64 -> 57 -> 44. With keep, the turn is not carried in the mesh at all
                -- (hold = nil, whatever BoardHopTurnHold says): the capsule turns on the last frame as in build 211 and the
                -- pose itself is turned back to the heading it had in the air, closed loop, until the blend is over.
                keep = ((tonumber(S.BoardHopKeep) or 0) > 0 and (tonumber(NATIVE.v) or 0) >= 115 and type(HJN_Set) == "function") and math.min(0.6, tonumber(S.BoardHopKeep) or 0.3) or nil,
                hold = ((tonumber(S.BoardHopKeep) or 0) <= 0 or (tonumber(NATIVE.v) or 0) < 115) and (mesh ~= nil and (th == 1 or th == 2) and (not sw or (tonumber(S.BoardHopTurnHoldSwitch) or 0) ~= 0)) and th or nil,   -- (v212) the turn held in the mesh (above): a regular hop, or a switch one with BoardHopTurnHoldSwitch
                fr = {}, n = (HOP.n or 0) + 1, rideSaid = HOP.rideSaid,       -- (v212) this hop's frame lines (NATIVE.hopFrame), which hop of the run it is, and when a level riding height off the average was last said (NATIVE.hopMeasure): kept over the hop like rideZ
                run = { x = rx, y = ry, sp = rsp, vel = rvel, mesh = rmesh },                                       -- (v211) the run-up, as read above
                glide = ((tonumber(S.BoardHopSpeedScale) or 0) > 0 and rsp >= 30) and math.min(1, rsp / 300) or 0 }   -- (v211) how much of the arc's braking into the landing is taken out (hopTick)
        hopAim(d, now)
        local mm0 = q(function() return mv.MovementMode end, nil)           -- (v212) 1 = the game has you walking at the click (the standing height in the line below)
        q(function() mv:SetMovementMode(3, 0) end)                          -- airborne: the on-foot jump pose
        -- (v211) the DECK's side, as the line says: it printed the capsule's toe side, and the capsule rides the deck either
        -- way round (tail-first regular and nose-first switch have it facing the tail) -- 8 of the 13 lines of 9 Oct were wrong
        local dside = (math.abs(wrapA(HOP.yc - d.yaw)) < 90) and side or -side
        -- (v212) the landing height as hopAim has it and where it is from; and, when the game has you walking at the
        -- click, how high you stand over the deck's level: on level ground that is the capsule's STANDING height, the
        -- figure the lift is to clear (85 fits the three engine landings of 10 Oct, and so does 90: it was never read)
        local lift = math.max(0, tonumber(S.BoardHopLandLift) or 0)
        log(string.format("board hop (%s): %.0f cm to the board, riding %s %s, facing the deck's %s side in the air (your toes point to the %s of the capsule: %s), landing %.0f cm over the deck (%s%s)%s",
            which, dist, nose and "nose-first" or "tail-first", sw and "switch" or "regular", dside > 0 and "right" or "left", side > 0 and "right" or "left",
            HOP.chest and "your toes while riding" or "by your stance", (HOP.rideZ or S.BoardHopRideZ) + lift,
            HOP.rideZ and "measured on level ground" or "not measured yet: BoardHopRideZ", (lift > 0) and string.format(", and BoardHopLandLift %g over it", lift) or "",
            (mm0 == 1) and string.format("; you stand %.0f cm over the deck's level", loc.Z - d.z) or ""))
        log(string.format("board hop:    plan: you face %.0f, the deck's nose points %.0f; on the board the capsule will face %.0f, your chest %.0f; handed to the game at %.0f%s; flip flag %d",
            F, d.yaw, wrapA(HOP.yc), wrapA(HOP.yc + side * 90), wrapA(HOP.ym), (HOP.ym ~= HOP.yc) and " (switch: the game turns it half a turn itself)" or "", HOP.flip and 1 or 0))
        do
            local Hr = math.rad(HOP.H or F)
            local c = math.max(-1, math.min(1, rx * math.cos(Hr) + ry * math.sin(Hr)))
            log((rsp >= 30) and string.format("board hop:    you ran up at %.0f cm/s (%s; Velocity %.0f, the mesh %.0f), %.0f deg off the way the board will roll; BoardHopSpeedScale x%.2f, BoardHopSpeedAcross %.2f",
                    rsp, rhow, rvel, rmesh, math.deg(math.acos(c)), tonumber(S.BoardHopSpeedScale) or 0, tonumber(S.BoardHopSpeedAcross) or 0)
                or string.format("board hop:    you stood still (Velocity %.0f cm/s, the mesh %.0f): nothing of yours to give the board", rvel, rmesh))
        end
        -- (v212) THE POSE RECORDER OVER THE HOP (BoardHopPoses: the first 8 hops of a run). No board hop has ever been
        -- recorded -- a hop opens none of the recorder's windows -- so what the frames at a mount look like is known
        -- from the code alone. A trick trace is one of those windows: 120 poses, the click to about a second and a half
        -- after the mount (the whole skeleton, the mesh in the world, the deck in the mesh's space: RecordPoses writes
        -- them to ExpandedTricks.poses.bin, TraceLog the trace's own lines to the native log). Not the word "switch"
        -- in the tag: the native half then logs every pose instead of every third. New ground for the native pose
        -- pass, which does not as a rule run on while you are on foot: "fault while posing" in the native log after a
        -- hop = BoardHopPoses=0
        if (tonumber(S.BoardHopPoses) or 0) ~= 0 and S.TraceLog ~= 0 and HOP.n <= 8 and type(HJN_TrickTrace) == "function" then
            pcall(HJN_TrickTrace, 120, string.format("board hop %d %s %s", HOP.n, nose and "nose-first" or "tail-first", sw and "sw" or "reg"))
        end
        return true
    end

    -- (v211) WHICH WAY THE MOUNT STOOD YOU, said on the first frame riding and half a second on: the capsule against the
    -- plan (about 0 off = right; 180 off = the yaw handed over is wrong), the deck's nose against where it pointed (turned
    -- 180 = the flip flag is wrong), and the game's own foot position and switch flag (after a switch hop they must still
    -- say 4 and true half a second on: until build 210 the game took "switch" back within the second in 5 of 6).
    -- BoardHopSwitchFix=0 must show 180 off on the switch hops: the A/B without a rebuild
    NATIVE.hopFacing = function(A, tag)
        local ay = tonumber(q(function() return s0:K2_GetActorRotation().Yaw end, nil))
        local d = deckWorld()
        if not ay or not d or not d.yaw then log("board hop:    facing " .. tag .. ": not read") return end
        local cs = (type(HJN_CtrlYaw) == "function") and tostring(HJN_CtrlYaw(ay) or "") or "?"
        log(string.format("board hop:    facing %s: capsule %.0f (planned %.0f, %+.0f off; handed over at %.0f), deck nose %.0f (was %.0f, turned %+.0f), board target to capsule / deck offset / reverting [%s], foot position %s, the game says switch %s (asked %s)",
            tag, wrapA(ay), wrapA(A.yc), wrapA(ay - A.yc), wrapA(A.ym or A.yc), d.yaw, wrapA(A.d0), wrapA(d.yaw - A.d0), cs,
            tostring(q(function() return s0:GetCurrentFootPosition() end, "?")), tostring(q(function() return s0:IsSkatingSwitch() end, nil)), tostring(A.sw)))
        -- (v212) THE DECK'S 180 OF 10 OCT 09:55:37, NAMED WHEN IT HAPPENS, AND ON WHICH SIDE OF THE MOUNT'S LAST ResetBoard: on
        -- the first frame riding the game's switch flag is not the one the hop asked for, or the deck's nose has turned
        -- more than a quarter turn. The deck offset in the bracket of the line above says which of the game's tests did
        -- it. The mount's last ResetBoard writes that offset from "is switch" against the flip flag (unequal = 180), and
        -- SnapToGround turns the board on the same compare a moment later. An offset that is NOT what the stance asked
        -- for gives against the flip flag = the stance was re-labelled BEFORE that ResetBoard: the game's first two
        -- tests, which go by the board's old direction of travel -- the wipe should have shut them (10 Oct 09:55:37 was
        -- this: asked regular, flip flag 0, offset 180). The offset as asked WITH the deck turned = re-labelled AFTER
        -- it, between the two compares: the third test, which reads what the game's own stop leaves of the board's
        -- motion, its vertical speed, along a pitched deck -- the stop of the board did not hold. With
        -- BoardHopStanceLock, native v114 and "stopped before the mount" none of it should come again; if it does,
        -- that hop's "mounting where the board lies" line in the native log and its "as you land" line here have the
        -- numbers each test goes by
        if tag == "on the first frame riding" then
            local swn = q(function() return s0:IsSkatingSwitch() end, nil)
            local turned = math.abs(wrapA(d.yaw - A.d0)) > 90
            if (swn ~= nil and swn ~= (A.sw == true)) or turned then
                local dof = tonumber(cs:match("^%S+ (%S+)"))
                local asked = ((A.sw == true) ~= (A.flip == true)) and 180 or 0
                local route
                if not turned then route = "the deck was not turned: the label changed after the board was snapped to you, not in one of the mount's three tests"
                elseif not dof then route = "the deck offset was not read, so which of the mount's tests did it cannot be said"
                elseif math.abs(wrapA(dof - asked)) > 90 then route = string.format("deck offset %.0f where the stance and flip flag asked for give %d: re-labelled BEFORE the mount's last ResetBoard, by one of its first two tests (the board's own travel taken for the way you move) -- the wipe of the board's old direction should have shut those", dof, asked)
                else route = string.format("deck offset %.0f, as the stance and flip flag asked for give it, and the deck turned all the same: re-labelled AFTER the mount's last ResetBoard, by its third test (a pitched board with vertical speed) -- the stop of the board should have shut that", dof) end
                log("board hop:    THE MOUNT RE-LABELLED YOUR STANCE OR TURNED THE DECK (the game's switch flag is not the one asked for, or the deck's nose turned over a quarter turn): the 180 under you. " .. route
                    .. ". This hop's 'mounting where the board lies' line in ExpandedTricks.native.log has the board's old move direction, its speed along it and whether the game counted it grounded; the 'as you land' line here its tilt and vertical speed")
            end
        end
    end

    -- (v212) THE HOP'S FRAMES, IN NUMBERS (BoardHopRecord): an entry a frame of the game from the last third of the arc
    -- to 0.7 s after the mount call, written to the log when the watch ends. "Every time he lands on the board, it's
    -- still a bit sketchy. It jitters" -- and no hop has ever been looked at frame by frame: the two lines above have
    -- no pose in them and the pose recorder never ran over one. What the columns are for:
    --   t  the way your toes point (both feet, ankle to toe) = the way your chest faces, on foot and riding alike.
    --      With BoardHopTurnHold 0 a jump of about 90 deg at the mount that is back by +150 ms IS the quarter-turn
    --      flick; with the hold on it should stay within about 20 deg of the planned chest. No jump with the hold
    --      off = there is no flick, and the hold comes out again;
    --   z  the capsule over the deck: a dip under its riding value = you were let into the ground and lifted back;
    --   the movement mode: 3/0 (in the air) until 6/x (riding); a 1/0 before the mount = the engine's own landing;
    --   v  the capsule's travel over the ground since the entry before, w the native half's reading of the same (the
    --      mesh's travel pose to pose, eased by half). The game's mount stops the board dead for a frame or two
    --      before the speed is given (its ForceStop): at 400 cm/s that is an entry of v near 0 between two near 400,
    --      or a dip of w to about half -- v only when this loop's tick falls on the same side of the game's own in
    --      both frames, w whenever a pose was drawn;
    --   a / r  the deck ahead of / to the right of the capsule: how far the mount had to bring the two together.
    -- An entry is read BEFORE the mod's own writes of that tick, and only when the game's own clock has moved on (two
    -- ticks of this loop can fall into one frame of the game, and would read as a standstill): the pose and the
    -- places of one drawn frame, as near as a loop that is not the game's tick gets to it. A dozen reflected calls an
    -- entry, some 60 entries a hop
    NATIVE.hopFrame = function(F, ms)
        if not F or #F >= 90 or (tonumber(S.BoardHopRecord) or 0) == 0 then return end
        local now = os.clock()
        local gt = (not F.noClock) and tonumber(q(function() return s0:GetGameTimeSinceCreation() end, nil)) or nil
        if gt and F.gt == gt then
            if now - F.at < 0.05 then return end                          -- the same frame of the game
            F.noClock, gt = true, nil                                     -- 50 ms on the same stroke: that clock does not run -- this loop's own from here on
        end
        if not gt and F.at and now - F.at < 0.012 then return end         -- (the game's clock not read: 12 ms apart at the least)
        local rot = q(function() return s0:K2_GetActorRotation() end, nil)
        local loc = q(function() return s0:K2_GetActorLocation() end, nil)
        local d = deckWorld()
        if not rot or not loc or not d then return end
        local my = tonumber(q(function() return mesh:K2_GetComponentRotation().Yaw end, nil))
        local tl = q(function() return mesh:GetSocketLocation(fname("AMXX_L_Toe0")) end)
        local fl = q(function() return mesh:GetSocketLocation(fname("AMXX_L_Foot")) end)
        local tr = q(function() return mesh:GetSocketLocation(fname("AMXX_R_Toe0")) end)
        local fr = q(function() return mesh:GetSocketLocation(fname("AMXX_R_Foot")) end)
        local toe = (tl and fl and tr and fr) and math.deg(math.atan((tl.Y - fl.Y) + (tr.Y - fr.Y), (tl.X - fl.X) + (tr.X - fr.X))) or nil
        local yr = math.rad(rot.Yaw)
        local dx, dy = d.x - loc.X, d.y - loc.Y
        local v = nil
        if F.px then
            local dt = (gt and F.gt and gt - F.gt > 0.001) and (gt - F.gt) or (now - F.at)
            if dt > 0.001 then v = math.sqrt((loc.X - F.px) ^ 2 + (loc.Y - F.py) ^ 2) / dt end
        end
        F.px, F.py, F.at, F.gt = loc.X, loc.Y, now, gt
        local w = type(HJN_MeshSpeed) == "function" and tonumber(HJN_MeshSpeed()) or nil
        F[#F + 1] = string.format("%+.0f:%s/%s z%.0f c%.0f m%s t%s d%.0f a%+.0f r%+.0f f%s v%s w%s", ms,
            tostring(q(function() return mv.MovementMode end, "?")), tostring(q(function() return mv.CustomMovementMode end, "?")),
            loc.Z - d.z, wrapA(rot.Yaw), my and string.format("%+.0f", wrapA(my - rot.Yaw - yaw0)) or "?", toe and string.format("%.0f", toe) or "?",
            d.yaw, dx * math.cos(yr) + dy * math.sin(yr), dy * math.cos(yr) - dx * math.sin(yr),
            tostring(q(function() return s0:GetCurrentFootPosition() end, "?")), v and string.format("%.0f", v) or "?", (w and w >= 0) and string.format("%.0f", w) or "?")
    end
    NATIVE.hopFramesOut = function(A)
        local F = A and A.fr
        if not F or #F == 0 then return end
        log(string.format("board hop:    frames (BoardHopTurnHold %s), ms from the mount call, one a frame of the game, each as it stood before the mod's own writes of that frame: movement mode / custom, z = capsule over the deck cm, c = capsule yaw, m = the mesh's turn against it, t = the way your toes point (your chest: planned %.0f, and still turning there in the arc; the capsule was handed to the mount at %.0f and rides at %.0f), d = the deck's nose, a / r = the deck ahead of / to the right of the capsule cm, f = foot position, v = the capsule's travel over the ground cm/s since the entry before, w = the same as the native half has it (eased by half a pose)",
            (A.sw and not A.hold and (tonumber(S.BoardHopTurnHold) or 0) ~= 0) and "not used -- a switch hop without BoardHopTurnHoldSwitch" or tostring(A.hold or 0), wrapA(A.chest or 0), wrapA(A.ym or A.yc or 0), wrapA(A.yc or 0)))
        for i = 1, #F, 8 do log("board hop:      " .. table.concat(F, " | ", i, math.min(#F, i + 7))) end
    end
    -- (v212) THE ONE WAY OUT OF THE WATCH: what the hop left in the mesh's yaw is taken out, the yaw watch is let back
    -- in, the frame lines are written. Whatever ends the watch calls this -- a turn left in the mesh is the "he faces
    -- one direction and runs the other" of v166
    NATIVE.hopEnd = function()
        local A = HOP.after
        HOP.after = nil
        if not A then return end
        if A.m1 then A.m1 = nil pcall(setYaw, 0, true) end
        NATIVE.hopTurnUntil = nil
        pcall(NATIVE.hopFramesOut, A)
    end

    NATIVE.hopTick = function()
        if HOP.after then
            -- (v128) THE BOARD KEEPS ITS SPEED. The game's mount (SetOnBoardMode + SnapToGround) leaves the board standing
            -- still, whatever it was doing. So once the game has you on it, every part gets the velocity the board was met
            -- with (HJN_BoardKick: the drop-in's own release), and again a frame or two later should the mount's first frame
            -- have zeroed it; then the game's own speed reading is logged
            -- (v211) ...AND GETS YOUR RUN-UP. "When I mount the board, the velocity seems stifled ... you run up to it and you
            -- jump on it. You should be imparting velocity into it." 9 Oct, twelve hops: the board rolled off with 0 to 311
            -- cm/s (its own roll, half of them under 105) from a run of 460. The game does this itself when it mounts you
            -- from a board in the hand or thrown (USkateboardExMovementComponent::OnMovementModeChanged hands the walk's
            -- velocity to ApplyOnFootVelocityTransfer: 460 in, 460 out); from a board lying loose it calls ForceStop
            -- instead. So the mod gives it: the speed you ran up at (read at the click) x BoardHopSpeedScale ("there should
            -- be a little speed boost": 1.2), ALONG THE BOARD the way you ride off (a board only rolls along its length: a
            -- kick across it is scrubbed off or tips it) -- the part of the run-up that points along the board, and
            -- BoardHopSpeedAcross of the part that points across. A board already rolling faster that way keeps its own
            -- speed (v128); standing still nothing is added.
            -- ForceStop also sets the game's "hold still" (board movement +0x7eb bit 4, a timer of SkaterConfig
            -- SlopeDetectionSpawnDelay = 0.5 s): while it is up PrePhysSkateboarding zeroes the board's speed over the
            -- ground every tick. On level ground it drops on the first tick; on a slope over about 11 deg it stays the
            -- half second. HJN_Set("boardgo") (native v113) lets go of it -- what the game does when it hands a walk's
            -- velocity on -- and with or without it the speed is given again whenever the game reads under half of it,
            -- for 0.8 s, until it has once been read at half or more: from then on a slower board is the world's doing,
            -- not the hold's (the note at the test below). (v128's "the game reads" line was taken right after its own
            -- second kick: it read back what had just been written, 7 of 10 to the cm/s.)
            -- The same watch says which way the mount stood you (NATIVE.hopFacing), at once and half a second on. How it
            -- runs: the first frame riding -> the facing, then what the board is to get; nothing to give -> said, and only
            -- the second facing line is waited for; else given, read 60 ms on and then every 0.2 s (and given again when
            -- taken back) until 0.8 s; over when both are done. A bail or a drop-in ends it at once; off the board
            -- again ends it; never mounted within 0.6 s -> the board's flag is put back, as before
            -- (v212) ONE KICK, NOT TWO. "Given once more 60 ms on" gave nothing in any of the four hops of 10 Oct -- "(0
            -- parts)": the second look for the board's parts inside half a second was refused (findFlipper) -- and the
            -- speed held without it: the game read 131, 370, 148 and 494 cm/s at 65 ms and the same to within 5 cm/s half
            -- a second on. With the look mended it would be a second shove at a board already rolling. What stays is
            -- "given again when the game has taken it back", and that now reaches the board: the parts are the ones
            -- looked up as you landed (A.parts), for as long as the deck they belong to lives (A.deck) -- a list of
            -- addresses is not used on a board the game has put away (an engine call on a dead part corrupts the
            -- engine's object tables: the native half's note at its board parts).
            -- (v212, the review of 10 Oct) THEIR deck, kept with them as you landed -- not BD.comp, which is whichever
            -- deck the mod holds by now: every look for a board's parts drops it and takes the nearest board's, and the
            -- list would then pass on the strength of ANOTHER board's deck. No such order of events was found in play
            -- (it takes the hop's board gone and another found inside the 0.8 s, while you ride), but the list is
            -- raw addresses and goes to the engine as it is. The other way round too: a deck the mod has let go of
            -- (a look put off while the engine clears objects out drops it and finds none) no longer costs the watch
            -- the parts of a board that is still there.
            -- The watch also takes the frame lines (NATIVE.hopFrame) and lets out the turn the hop left in the mesh
            -- (BoardHopTurnHold, the note in hopTry); every way out of it goes through NATIVE.hopEnd
            local A = HOP.after
            local now = os.clock()
            local onb = q(function() return s0:IsOnBoard() end, false) == true
            if A.fr and now - A.t0 < 0.7 then pcall(NATIVE.hopFrame, A.fr, (now - A.t0) * 1000) end   -- (v212) the frame as it stood, before anything below is written
            if A.m1 then                                                   -- (v212) the body's turn still in the mesh
                if active then
                    -- a hippie jump of yours inside that tenth of a second: the mesh's yaw is its own from here on. What
                    -- the hop still has in it is taken out FIRST: the jump starts from the mesh's base without looking at
                    -- the mesh, and with the body varial off (Varial 0) it writes no yaw at all until it ends -- left in,
                    -- up to a quarter turn stood in the mesh for as long as the jump ran (the stand-in world: 88 deg at
                    -- a jump started one frame after the mount). The rest of the game's blend then shows as it did in
                    -- build 211
                    A.m1, NATIVE.hopTurnUntil = nil, nil
                    pcall(setYaw, 0, true)
                else
                    NATIVE.hopTurnUntil = now + 0.3                        -- (the yaw watch stands back the while: NATIVE.yawGuard)
                    if A.mounted then
                        -- from the tick AFTER the one that first saw you riding (A.mounted and A.tm are set further down, on
                        -- purpose: the game's first riding frame draws the snapshot unblended, so that tick keeps the whole turn).
                        -- By the game's own clock where it runs (A.gm): the blend is counted in the game's frames, and two
                        -- ticks of this loop inside one frame then write the same turn -- by this loop's own clock they are
                        -- 10 ms of the blend apart, up to 6 deg mid-way, a wobble of the hold's own making
                        local el = now - A.tm
                        local g = A.gm and tonumber(q(function() return s0:GetGameTimeSinceCreation() end, nil)) or nil
                        if g and (g > A.gm or el < 0.05) then el = g - A.gm end
                        local xx = math.min(1, el / 0.15)                  -- the game's blend out of the on-foot snapshot: 0.15 s (anim blueprint, OnFootToOnBoard -> OnBoard)
                        local al = xx * xx * (3 - 2 * xx)                  -- its curve (HermiteCubic)
                        pcall(setYaw, A.m1 * (1 - math.deg(math.atan(al, 1 - al)) / 90), true)   -- a quarter turn blended in by a share al has turned atan(al / (1 - al))
                        if xx >= 1 then A.m1 = nil pcall(setYaw, 0, true) NATIVE.hopTurnUntil = nil end
                    end
                end
            end
            if onb then
                if not A.mounted then                                      -- the first frame on the board
                    A.mounted, A.tm, A.checkAt = true, now, now + 0.5      -- the mount as the mod first sees it; the facing is read again half a second on
                    A.gm = A.m1 and tonumber(q(function() return s0:GetGameTimeSinceCreation() end, nil)) or nil   -- (v212) ...and by the game's own clock, for the turn that is let out of the mesh (above)
                    pcall(NATIVE.hopFacing, A, "on the first frame riding")   -- (before anything is given: what the mount alone did)
                    local R = A.run or { x = 1, y = 0, sp = 0 }
                    local Hr = math.rad(A.H or 0)
                    local ux, uy = math.cos(Hr), math.sin(Hr)
                    local uz = 0
                    -- the deck as the game's mount left it: the same line to the degree, and its rise on a slope (the speed goes along the deck, not into the bank)
                    local fx, fy, fz = tostring(type(HJN_DeckAxes) == "function" and HJN_DeckAxes() or ""):match("^(%S+) (%S+) (%S+)")
                    fx, fy, fz = tonumber(fx), tonumber(fy), tonumber(fz)
                    local fl = fx and fy and fz and math.sqrt(fx * fx + fy * fy) or 0
                    if fl > 0.7 then
                        local sgn = ((fx * ux + fy * uy) >= 0) and 1 or -1
                        if (fx * ux + fy * uy) * sgn / fl > 0.7 then ux, uy, uz = fx * sgn / fl, fy * sgn / fl, fz * sgn / fl end
                    end
                    local dot = math.max(-1, math.min(1, R.x * ux + R.y * uy))
                    local along = math.max(0, dot)
                    local share = along + (tonumber(S.BoardHopSpeedAcross) or 0) * (1 - along)
                    local scale = tonumber(S.BoardHopSpeedScale) or 0
                    local mine = (R.sp >= 30) and math.min(2000, R.sp * share * scale) or 0
                    local own = A.vx * ux + A.vy * uy                      -- the board's own roll, the same way
                    if math.abs(own) < 0.5 then own = 0 end                -- (a board that lay still: 0, not the "-0" of a rounding crumb in the log)
                    if mine >= 30 and mine > own then
                        A.want, A.tx, A.ty, A.tz, A.ux, A.uy = mine, ux * mine, uy * mine, uz * mine, ux, uy
                        A.what = string.format("%.0f cm/s (%.0f km/h) given to the board, along it: your run-up's %.0f cm/s x %.0f %% (it came in %.0f deg off the board's line) x BoardHopSpeedScale %.2f; the board's own roll that way was %.0f",
                            mine, mine * 0.036, R.sp, share * 100, math.deg(math.acos(dot)), scale, own)
                    else
                        A.want, A.tx, A.ty, A.tz = A.speed, A.vx, A.vy, 0
                        A.ux, A.uy = (A.speed >= 30) and A.vx / A.speed or ux, (A.speed >= 30) and A.vy / A.speed or uy
                        A.what = (A.speed >= 30) and string.format("the board's own %.0f cm/s given back to it (your run-up would have given %.0f: %.0f cm/s x %.0f %% x BoardHopSpeedScale %.2f)", A.speed, mine, R.sp, share * 100, scale)
                            or string.format("nothing given (the board lay still and your run-up gives %.0f: %.0f cm/s x %.0f %% x BoardHopSpeedScale %.2f)", mine, R.sp, share * 100, scale)
                    end
                end
                if not A.over then                                         -- the speed (over = settled: only the second facing line is still waited for)
                    local function give()
                        local n = 0
                        if type(HJN_BoardKick) == "function" and type(HJN_BoardParts) == "function" and NATIVE.boardParts then
                            local parts = (A.parts and alive(A.deck)) and A.parts or NATIVE.boardParts()   -- (v212) the parts looked up as you landed, while THEIR deck lives (the note above); else looked up afresh
                            local took = parts and tonumber(HJN_BoardParts(table.unpack(parts))) or 0
                            if took > 0 then n = tonumber(HJN_BoardKick(A.tx, A.ty, A.tz or 0, 0, A.ux, A.uy)) or 0 end
                            pcall(HJN_BoardParts)                              -- (the parts let go of again)
                        end
                        return n
                    end
                    if A.want < 30 then
                        A.over = true
                        log("board hop: riding -- " .. A.what)
                    elseif modeNow() == MODE_BAILING or (NATIVE.dropBusy and NATIVE.dropBusy()) then
                        log(string.format("board hop:    a bail or a drop-in %.0f ms after the mount -- the speed is left alone", (now - A.tm) * 1000))
                        NATIVE.hopEnd()
                    elseif A.kicks == 0 then
                        local go = type(HJN_Set) == "function" and tonumber(HJN_Set("boardgo", 1)) or 0   -- 1 = the game's hold was up and is let go, 2 = it was not up, 0 = not looked at: v112 and older have no such thing, and v113 answers so on another build of the game or when it finds no board
                        local n = give()
                        A.kicks, A.nextKick = 1, now + 0.06
                        log(string.format("board hop: riding -- %s (%d parts%s; the game's hold-still after a mount: %s)", A.what, n, (n > 0) and "" or " -- NOT kicked",
                            (go == 1) and "let go" or (go == 2) and "was not up" or "not looked at by this native half (v112 and older have no such thing; v113 says so on another build of the game or when it finds no board)"))
                    elseif now >= A.nextKick then
                        -- (read BEFORE anything is given again: the game's reading is the board's velocity as it stands, so read
                        -- right after a kick, as build 128 did, it only says what was just written)
                        local cur = tonumber(q(function() return mv:GetCurrentSpeed() end, -1)) or -1
                        local real = type(HJN_MeshSpeed) == "function" and tonumber(HJN_MeshSpeed()) or -1
                        local ms = (now - A.tm) * 1000
                        -- taken back = the game reads under half AND the mesh's own travel does not say otherwise (the game's
                        -- reading is the velocity along ITS move direction, which may not have turned to the board's line yet)
                        -- (v211) ...AND ONLY UNTIL THE SPEED HAS BEEN READ ONCE (A.took). The hold wipes it from the first tick
                        -- on, so a board that HAS rolled at the speed and is slower afterwards was slowed by the world -- a
                        -- bank rolled up, a kerb, your own brake -- not by the hold. Without this it was shoved again at the
                        -- full speed along the line of the mount and logged as "the game had taken it back": in the
                        -- stand-in world, 552 cm/s kept for 0.3 s and then down to 150 on a bank = shoved at 663 and 863 ms.
                        -- With native v113 letting go of the hold that would have been most of what the watch ever did.
                        -- (The mesh's travel counts from the third reading on: 60 ms after the mount it still carries the
                        -- hop's own arc.)
                        if cur >= 0.5 * A.want or (A.kicks >= 2 and real >= 0.5 * A.want) then A.took = true end
                        if not A.took and cur >= 0 and cur < 0.5 * A.want and real < 0.5 * A.want and A.kicks < 7 then   -- (v212) no longer "once more, as always" at the first reading: the note at the top
                            local n = give()
                            log(string.format("board hop:    %.0f ms after the mount the game reads %.0f cm/s, you move %.0f over the ground (%.0f asked for) -> given AGAIN: the game had taken it back (%d parts)", ms, cur, real, A.want, n))
                        else
                            log(string.format("board hop:    %.0f ms after the mount the game reads %.0f cm/s, you move %.0f over the ground (%.0f asked for)", ms, cur, real, A.want))
                        end
                        A.kicks, A.nextKick = A.kicks + 1, now + 0.2
                        if now - A.tm > 0.8 then A.over = true end
                    end
                end
                if HOP.after and A.checkAt and now >= A.checkAt then A.checkAt = nil pcall(NATIVE.hopFacing, A, "0.5 s on") end
                if HOP.after and A.over and not A.checkAt then NATIVE.hopEnd() end
            elseif A.mounted then                                          -- (v211) mounted, and off the board again inside the watch: nothing to put back, and no "did not mount you"
                log(string.format("board hop:    off the board again %.0f ms after the mount", (now - A.tm) * 1000))
                NATIVE.hopEnd()
            elseif now >= A.deadline then
                if type(HJN_BoardRagdoll) == "function" then HJN_BoardRagdoll() end
                log("board hop: the game did not mount you (board flag put back) -- mode " .. tostring(modeNow()))
                NATIVE.hopEnd()
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
        local eh = e + (k - e) * (HOP.glide or 0)                       -- (v211) over the ground: no braking into the landing when you ran up (the height and the turn keep their ease)
        if k >= 0.7 then pcall(NATIVE.hopFrame, HOP.fr, (now - HOP.t0 - math.max(0.1, S.BoardHopTime)) * 1000) end   -- (v212) the last third of the arc, each frame as it stood before this tick's writes
        -- (v212) STILL IN THE AIR, FOR THE GAME TOO. 10 Oct, the hop of 09:55:26: the engine had you "walking" again 16 ms
        -- after the click, for 100 ms (its first falling step started on the ground), and in three hops of four it
        -- landed you by itself 2 to 4 frames before the mount (SessionTweaks.log: "movement 1/0" 66, 51 and 33 ms before
        -- "onBoard 1"). A walking character is kept on its floor by the engine while the arc carries it: put back in
        -- the air when that is seen, and counted for the log (the ticks of this loop it was seen on) -- the way down
        -- (0 is the aim) apart from the take-off (the engine's first step after the click can land you before the
        -- arc's first tick: 0 to 2 there is normal). THE FIRST TWO TIMES OF EACH END ONLY: where the arc ends inside
        -- something -- a kerb beside the board, a bank, a board on a ledge, a height still read wrong -- the engine
        -- lands you again on its next tick, every frame, with the game's own landing handling each time; build 211's
        -- one landing there is the lesser evil. 3 or more on the way down in the "as you land" line = the arc ended
        -- in the ground: the frame lines' z column says how deep.
        -- Mounted from the air the game also brings the board under the capsule instead of leaving it where it lay
        -- (the skater movement's OnMovementModeChanged, exe+0xffa426: previous mode Falling): the hop of 09:56:22,
        -- the one with no engine landing logged before it, came out as planned
        if q(function() return mv.MovementMode end, 3) == 1 then
            local n
            if k >= 0.5 then n = HOP.walked or 0  HOP.walked = n + 1 else n = HOP.walked0 or 0  HOP.walked0 = n + 1 end
            -- (v212, the review of 10 Oct) BoardHopAirKeep 0 = seen and counted, and left alone as build 211 left it.
            -- The stop, the wipe, the lift, the turn's hold and the frame lines each have their setting; this had
            -- none, and "if the landing feels worse there is no A/B" for it without a new build
            if n < 2 and (tonumber(S.BoardHopAirKeep) or 1) ~= 0 then q(function() mv:SetMovementMode(3, 0) end) end
        end
        local x = HOP.p0[1] + (HOP.p1[1] - HOP.p0[1]) * eh
        local y = HOP.p0[2] + (HOP.p1[2] - HOP.p0[2]) * eh
        local z = HOP.p0[3] + (HOP.p1[3] - HOP.p0[3]) * e + math.max(4 * S.BoardHopHeight * k * (1 - k), 3 * (1 - k))   -- (v212) ...and 3 cm clear of the ground from the first tick on (the arc's own height is more than that from the second)
        -- (v212) WHERE YOUR BODY FACES AND WHERE THE CAPSULE DOES (BoardHopTurnHold, the note in hopTry). The body's facing is
        -- build 211's: from where you faced to the chest's side of the deck. Without the hold the capsule IS that facing
        -- until the last frame hands it to the mount; with it the capsule is eased to the mount's yaw on the way (1) or
        -- flies as before (2), and the mesh carries what the capsule lacks -- written in the same slice as the capsule,
        -- so that no frame is drawn with the one turned and the other not
        local body = (k < 1) and (HOP.y0 + (HOP.y1 - HOP.y0) * e) or HOP.y1
        local cap = body
        if k >= 1 then cap = HOP.ym or HOP.yc                            -- the last frame: the capsule is handed to the mount (v211: ym -- yc, or half a turn round for a switch mount, which the game turns back)
        elseif HOP.hold == 1 then cap = HOP.y0 + (HOP.c1 - HOP.y0) * e end
        if HOP.keep then                                                 -- (v213) the native half follows the body's heading through the arc...
            if k < 1 then pcall(HJN_Set, "hopkeep", 0.3) else pcall(HJN_Set, "hopkeep", -HOP.keep) end   -- ...and holds it from the last frame on, asked BEFORE the capsule is turned
        end
        -- (v215) THE FEET STAY ON THE DECK THROUGH THE MOUNT (BoardHopFeet). "I think the last issue is his foot dips below
        -- the board and touches the ground before it rebounds to touch the board. Seems pretty consistent." (10 Oct.) The
        -- game's mount sets the capsule to its riding height and blends from a snapshot of the STANDING pose, whose feet
        -- are at the capsule's foot: 5 cm and more under the deck's top for the eighth of a second the blend takes. The
        -- native half already has the cure, made for the ollie hop (v111, HJN_Set "hopdeck"): for that many poses neither
        -- foot is drawn lower over the deck than it rides -- the body is held up by what a foot lacks, eased off as the
        -- blend brings the feet up. Asked on the arc's last frame, for the mount's own frames.
        -- (v216) ...BUT NOT BY LIFTING THE BODY. "The board mount is less smooth. Like it stutters as the character rotates
        -- to align to the board ... and his legs still kind of bounce off the board." (11 Oct.) "hopdeck" raised the
        -- whole body 14-15 cm in one pose and eased it off against a need that jumped: the stutter. And the bounce is
        -- the game's own feet, after its board bone (the note at HopFeet in the native half). Native v117's "hopfeet":
        -- for these poses each ankle is drawn at its riding height over the deck, sole flat, the legs bent to it.
        if k >= 1 and (tonumber(S.BoardHopFeet) or 1) ~= 0 and (tonumber(NATIVE.v) or 0) >= 117 and type(HJN_Set) == "function" then pcall(HJN_Set, "hopfeet", 22) end
        pcall(function() s0:K2_SetActorLocationAndRotation({ X = x, Y = y, Z = z }, { Pitch = 0, Yaw = cap, Roll = 0 }, false, {}, true) end)
        if HOP.hold == 1 or (HOP.hold == 2 and k >= 1) then
            HOP.moff = wrapA(body - cap)                                 -- the body's turn against the capsule, carried by the mesh
            NATIVE.hopTurnUntil = now + 0.3                              -- (the yaw watch stands back the while: NATIVE.yawGuard)
            pcall(setYaw, HOP.moff, true)
        end
        pcall(function() mv.Velocity = { X = 0, Y = 0, Z = 0 } end)
        if k < 1 then return end
        HOP.on = false
        local rolled = math.sqrt((HOP.bp[1] - HOP.b0[1]) ^ 2 + (HOP.bp[2] - HOP.b0[2]) ^ 2)
        local speed = math.sqrt(HOP.bv[1] ^ 2 + HOP.bv[2] ^ 2)
        -- (v212) THE MOUNT MUST NOT RE-LABEL YOUR STANCE: THE BOARD IS STOPPED AS YOU COME DOWN ON IT AND ITS OLD DIRECTION
        -- OF TRAVEL WIPED (BoardHopStanceLock). 10 Oct 09:55:37, "the board literally rotated 180 beneath the character":
        -- planned nose-first regular with flip flag 0, mounted with foot position 2, "the game says switch true (asked
        -- false)", the deck's nose turned 180. Inside its own mount, before the board is snapped to you, the game can
        -- re-label your stance from the way the LOOSE BOARD travels (AdjustFootPositionAndMoveDirection, exe+0xfe95a0,
        -- reached from UpdateMoveDirection and from SetOnBoardMode); re-labelled, "is switch" no longer matches the
        -- flip flag, and the mount's own snap turns the board half a turn. WHICH of its tests did it that day is NOT
        -- known: by the deck's travel the board slid broadside at 115 cm/s, which as the exe reads passes none of
        -- them on a level board, and two other hops onto boards moving straight against the ride did not turn. (A
        -- candidate, not a measurement: that board was the one still SKIDDING a second and three quarters after a hard
        -- throw -- likely up on an edge and bouncing, and a tilted board with vertical speed is what the tests that
        -- come after the game's own stop of the board go by. Neither its tilt nor its vertical speed was in any log;
        -- both are in the "as you land" line now.) So every route in the mount is shut, and that takes BOTH halves:
        --   THE WIPE (native v114 zeroes the board's stored move direction) shuts the two tests that run before the
        --     mount's last ResetBoard. The game measures the board's speed ALONG that direction: zeroed, it reads 0 and
        --     takes the way the board points for the way you move;
        --   THE STOP shuts the third. UpdateMoveDirection inside that last ResetBoard (exe+0xfe0774) reads the
        --     direction the game has just written again against what its own ForceStop leaves of the board's velocity,
        --     (0, 0, vz): on a pitched board with vertical speed over 50 / sin(pitch) it re-labels all the same. The
        --     board is stopped here, in the same slice (HJN_BoardKick with zeros: vz too).
        -- Nothing is lost by the stop: the game stops the board in the mount anyway and the watch gives it its speed
        -- afterwards. With a v113 native half only the stop is made. Where the stop cannot be made (the parts not
        -- found, or not taken) the mount is made all the same, and the "as you land" line says what is then still open.
        -- The order in the slice: the parts, the board's velocity, the stop, the mount call (the wipe), the game's toggle.
        -- The board's parts are looked up ONCE for the whole mount and kept for the watch (A.parts) with the deck they
        -- are of (A.deck: the watch uses the list only while that deck lives). A look that is PUT OFF (the engine
        -- clearing objects out: NATIVE.walkOk, about once a minute in play) finds no parts either, and the "as you
        -- land" line says which of the two it was -- told from the walk gate's own count of looks put off, taken on
        -- both sides of the look (the engine's flag itself may have changed by the time the line is written: it is
        -- another thread's). Its velocity is
        -- read off its physics body before the stop and handed to the native half for its log line: the deck's travel
        -- (HOP.bv) is a half-eased average of places 30 ms apart, blind to the last frames -- the very ones the capsule
        -- may be pressing on the board in. The speed the board is given afterwards still comes from HOP.bv, as before
        local lock = (tonumber(S.BoardHopStanceLock) or 0) ~= 0
        local putOff = NATIVE.WK and tonumber(NATIVE.WK.no) or 0         -- (v212) the looks put off so far (NATIVE.walkOk's count)...
        local parts = NATIVE.boardParts and NATIVE.boardParts() or nil
        putOff = (NATIVE.WK and tonumber(NATIVE.WK.no) or 0) > putOff    -- ...one more = this look was: not a board that is not there
        local deck = parts and BD.comp or nil                            -- (v212) the deck those parts are of (boardParts has just taken it), kept with them: A.deck
        local pvx, pvy, pvz = nil, nil, nil
        if alive(BD.comp) then
            local pv = q(function() return BD.comp:GetPhysicsLinearVelocity(fname("None")) end, nil)
            if pv then pvx, pvy, pvz = q(function() return tonumber(pv.X) end, nil), q(function() return tonumber(pv.Y) end, nil), q(function() return tonumber(pv.Z) end, nil) end
        end
        local fromBody = pvx ~= nil and pvy ~= nil
        if not fromBody then pvx, pvy, pvz = HOP.bv[1], HOP.bv[2], nil end
        pvz = pvz or HOP.bv[3] or 0                                      -- (the board's vertical speed: its body's, else the deck's own rise and fall over the hop)
        local stopped = -1
        if lock and parts and type(HJN_BoardParts) == "function" and type(HJN_BoardKick) == "function" then
            stopped = ((tonumber(HJN_BoardParts(table.unpack(parts))) or 0) > 0) and (tonumber(HJN_BoardKick(0, 0, 0, 0, 1, 0)) or 0) or 0
            pcall(HJN_BoardParts)                                        -- (the parts let go of again)
        end
        local mm = q(function() return mv.MovementMode end, -1)
        if tonumber(HJN_BoardMount(HOP.sw and 1 or 0, HOP.flip and 1 or 0, lock and 1 or 0, pvx, pvy, pvz)) == 1 then   -- (v212) + wipe 0/1 and the board's motion for the native log; a v113 native half reads the first two
            local ok, err = pcall(function() s0:SetPendingApplyToggleOnBoard() end)
            log(ok and string.format("board hop: landed%s -- the game mounts you on the board where it is",
                    (rolled > 15) and string.format(" (the board rolled %.0f cm during the hop, met at %.0f cm/s)", rolled, speed) or "")
                or ("board hop: mount call failed: " .. tostring(err)))
            do
                -- (v212) what the landing slice found and did, in one line. With the native log's "mounting where the board
                -- lies" line (the old direction, the speed along it, grounded or not) it has what each of the game's
                -- three tests goes by: the board's motion over the ground, and for the one after the game's own stop
                -- the deck's tilt (its up z, as last read) and the board's vertical speed. A stop that was NOT made
                -- is said with what it leaves open; the mount is not refused for it
                local ch, sh = math.cos(math.rad(HOP.H or 0)), math.sin(math.rad(HOP.H or 0))
                local stop, wipe
                if not lock then stop, wipe = "left as it is", "left as it is (BoardHopStanceLock 0)"
                else
                    if stopped > 0 then stop = string.format("stopped before the mount (%d parts)", stopped)
                    -- (v212, the review of 10 Oct) a look that was put off is not a look that found no board: "stopped
                    -- before the mount (7 parts)" is what a test of the 180 looks for, and this hop is no failure of it
                    elseif not parts then stop = (putOff and "NOT stopped: the look for the board's parts was put off (the engine was clearing objects out, or a level had just changed)" or "NOT stopped: the board's parts were not found")
                        .. " -- a pitched board with vertical speed can then still turn under you"
                    else stop = "NOT stopped: the native half took none of its parts -- a pitched board with vertical speed can then still turn under you" end
                    wipe = ((tonumber(NATIVE.v) or 0) >= 114) and "the native half's to wipe (its 'mounting where the board lies' line says ZEROED)"
                        or string.format("NOT wiped: that takes native v114, this is v%s -- the stop alone holds only while nothing sets the board moving again before the game's mount", tostring(NATIVE.v or "?"))
                end
                log(string.format("board hop:    as you land: the board's own motion %s, by the deck's travel %.0f cm/s (%+.0f along, %+.0f across), deck up z %s, vertical %+.0f cm/s -- the board %s; its old direction of travel %s; the game has you %s; its own landing cut in on %d frames on the way down (%d at the take-off; %s)",
                    fromBody and string.format("by its physics body %.0f cm/s (%+.0f along the way you will ride, %+.0f across it to the right)", math.sqrt(pvx * pvx + pvy * pvy), pvx * ch + pvy * sh, pvy * ch - pvx * sh)
                        or "by its physics body: not read",
                    speed, HOP.bv[1] * ch + HOP.bv[2] * sh, HOP.bv[2] * ch - HOP.bv[1] * sh,
                    (d and d.upz) and string.format("%.2f", d.upz) or "?", pvz, stop, wipe,
                    (mm == 3) and "in the air" or ("in movement mode " .. tostring(mm)), HOP.walked or 0, HOP.walked0 or 0,
                    ((tonumber(S.BoardHopAirKeep) or 1) ~= 0) and "put back in the air the first two times of each" or "NOT put back in the air: BoardHopAirKeep 0"))   -- (v212) which of the two it was
            end
            if not ok and type(HJN_BoardRagdoll) == "function" then HJN_BoardRagdoll() end
            HOP.after = { t0 = os.clock(), deadline = os.clock() + 0.6, speed = speed, vx = HOP.bv[1], vy = HOP.bv[2], kicks = 0, nextKick = 0,   -- (v128)
                          run = HOP.run, H = HOP.H,                                                    -- (v211) the run-up and the way the board will roll
                          yc = HOP.yc, ym = HOP.ym, sw = HOP.sw, d0 = (d and d.yaw) or HOP.d0 or 0,    -- (v211) for the facing check: the plan, and the deck's nose as you land
                          flip = HOP.flip, parts = parts, deck = deck, fr = HOP.fr, hold = HOP.hold, m1 = HOP.hold and HOP.moff or nil, chest = HOP.y1 }   -- (v212) the flip flag (the deck offset the mount should leave: NATIVE.hopFacing), the board's parts as looked up above and the deck they are of, the frame lines, the body's turn still in the mesh, where your chest is to point
        else
            q(function() mv:SetMovementMode(1, 0) end)
            if HOP.hold then pcall(setYaw, 0, true) NATIVE.hopTurnUntil = nil end   -- (v212) no mount: the body's turn comes out of the mesh at once
            log("board hop: the native half refused the mount (see ExpandedTricks.native.log) -- back on foot")
        end
    end

    LoopAsync(10, function()
        if HOP.on or HOP.after then
            NATIVE.gt(function()
                local ok, err = pcall(NATIVE.hopTick)
                if not ok then                                         -- (v211) it was swallowed: a hop left half done blocked the next one for good
                    -- (v212) ...and what it had put in the mesh's yaw is taken out, the frame lines it had are written
                    if HOP.hold or (HOP.after and HOP.after.m1) then pcall(setYaw, 0, true) end
                    HOP.on = false
                    pcall(NATIVE.hopEnd)
                    HOP.after, NATIVE.hopTurnUntil = nil, nil
                    log("board hop: error, the hop is dropped: " .. tostring(err))
                end
            end)
        end
        return false
    end)
end

-- THE DROP-IN (v98). The game has no marked ledges: its grind detector finds edges by sweeping the level's collision and
-- comparing the two faces it hits. So the native half looks the same way, with rays (HJN_Ledge): the ground you stand
-- on, where it drops away, which way that drop faces, and at what angle a board pivoting on the edge meets the ground
-- below. On foot and close to such an edge, Y / triangle:
--   throw  (v211, with DropInSetDown only: an experiment) the game's own throw is refused and its throwdown animation
--          is played by the mod, square to the edge and close to it: the board comes down there, you are walked onto
--          it and put on. Then "mount" below finds you on the board, and where you stand right there is no first move;
--          (v212, with DropInSetEdge too and the press made within DropInSetReach of the edge) the board is set ON
--          the coping: held out over the edge where the stance will have it while you step on, and you are put on
--          there -- no "mount", "set" or "out" after it: straight to "wait";
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
        -- (v218) ...LOOKED FOR AGAIN ONLY WHEN IT IS NOT THE ONE BY YOU: every board hop, drop-in and throwdown walked
        -- every object of the game here (+7..9 ms on the developer's machine, about 20 on the tester's). The deck that
        -- is kept is still yours while it is within 4 m of you (a co-op peer's is elsewhere; a new level forgets it)
        if alive(BD.comp) then
            local far = true
            pcall(function()
                -- (the review) ...and only YOUR board's: the ridden board is the actor named exactly "Skateboard" (a co-op
                -- peer's carries a numbered name, and at a shared spawn point a peer's deck can be the nearest one)
                if BD.comp:GetOwner():GetFName():ToString() ~= "Skateboard" then return end
                local p, h = BD.comp:K2_GetComponentLocation(), s0:K2_GetActorLocation()
                far = ((p.X - h.X) ^ 2 + (p.Y - h.Y) ^ 2 + (p.Z - h.Z) ^ 2) > 400 * 400
            end)
            if far then BD.comp = nil end
        else BD.comp = nil end
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
    -- (v218) ARMS OUT FOR BALANCE. "The arms while dropping in stay along the body; you should have them go in the air a
    -- bit for balance, like when grinding / sliding." (The Steam tester, 13 Oct.) The game has no input for that: a
    -- grind's arms are part of its whole-body grind poses, picked by the game's own grind state. So the native half
    -- (v118) turns each upper arm about its shoulder in the finished pose, toward a balance pose, by DropInArms degrees
    -- at the most (the note at DropArms there). What is sent here is this frame's weight, 0..1, on every frame of a
    -- drop-in that wants them up; the native half eases it, and lets go by itself a quarter second after the last
    -- asking -- so whatever ends a drop-in ends the arms. Beside an older native half, or with DropInArms 0, nothing is sent.
    -- (Fields of DI, not locals: the main chunk stands at 196 of Lua's 200 locals.)
    DI.sm01 = function(x) x = math.max(0, math.min(1, x)) return x * x * (3 - 2 * x) end
    DI.armsRec = function(n, tag)                        -- the first 16 of a run go to the pose recorder (DropInPoses)
        if (tonumber(S.DropInPoses) or 0) == 0 or S.TraceLog == 0 or (DI.recN or 0) >= 16 or type(HJN_TrickTrace) ~= "function" then return end
        DI.recN = (DI.recN or 0) + 1
        pcall(HJN_TrickTrace, n, tag)
    end
    DI.arms = function(w)
        local deg = tonumber(S.DropInArms) or 0
        if deg <= 0 or (tonumber(NATIVE.v) or 0) < 118 or type(HJN_Set) ~= "function" then return end
        if DI.armsDeg ~= deg then DI.armsDeg = deg pcall(HJN_Set, "droparmsdeg", deg) end
        DI.armsYawSend()
        pcall(HJN_Set, "droparms", math.max(0, math.min(1, w)))
        if not DI.armsN then
            log(string.format("drop-in:    arms out for balance: up to %g deg (DropInArms; 0 = the game's own arms)", deg))
            DI.armsRec(150, "drop-in arms up")
        end
        DI.armsN = (DI.armsN or 0) + 1
    end
    -- (v220) BY THE SIZE OF THE DROP. "It only takes like two or three frames and he's fully extended ... make the arm
    -- swing proportional to the height of the drop: small drops are small, big drops are big; and the raising of the
    -- arms also in proportion: on a tall one, figure the halfway point is when they're fully extended." (13 Oct.) The
    -- drop is the ledge scan's (the deeper of the ground just past the edge and further out: what the vert's speeds
    -- go by too). How far: its share of DropInArmsFull. When: by how much of it he has come down since the GO -- the
    -- skater's own height against where he stood -- fully out at DropInArmsPeak % of it, eased, never back down
    -- before the end. -> the weight for this frame, the share come down, the share of the slider
    DI.armsYawSend = function()                          -- the way he will ride: out over the edge (in SWITCH too: the nose points at the drop)
        local L = DI.L
        local yaw = L and math.deg(math.atan(L.oy, L.ox)) or nil
        if yaw and DI.armsYaw ~= yaw then DI.armsYaw = yaw pcall(HJN_Set, "droparmsyaw", yaw) end
    end
    -- (v221) ...AND THE CROUCH: DropInCrouch cm at the full height, its share below it, coming in with the tip (the tip
    -- itself half of it) and the way down, lowest DropInCrouchPeak % of the way. -> arms' weight, share come down, the
    -- drop's share of the full height, the crouch in cm
    DI.armsRise = function()
        local arms, crouch = tonumber(S.DropInArms) or 0, tonumber(S.DropInCrouch) or 0
        if arms <= 0 and crouch <= 0 then return 0, 0, 0, 0 end
        local H = math.max(10, DI.armsH or 0)
        local amt = math.max(0, math.min(1, H / math.max(10, tonumber(S.DropInArmsFull) or 200)))
        local z = q(function() return s0:K2_GetActorLocation().Z end, nil)
        if z and DI.armsZ0 then DI.armsFrac = math.max(DI.armsFrac or 0, math.min(1, (DI.armsZ0 - z) / H)) end
        local f = DI.armsFrac or 0
        local w = (arms > 0) and amt * DI.sm01(f / math.max(0.1, (tonumber(S.DropInArmsPeak) or 50) / 100)) or 0
        local cc = (crouch > 0) and crouch * amt * DI.sm01(math.max(0.5 * (DI.armsTip or 0), f / math.max(0.1, (tonumber(S.DropInCrouchPeak) or 25) / 100))) or 0
        return w, f, amt, cc
    end
    DI.crouch = function(cm)                             -- (v221) this frame's crouch, cm (native v119 lets go a quarter second after the last asking)
        if (tonumber(S.DropInCrouch) or 0) <= 0 or (tonumber(NATIVE.v) or 0) < 119 or type(HJN_Set) ~= "function" then return end
        DI.armsYawSend()
        pcall(HJN_Set, "dropcrouch", math.max(0, math.min(40, cm)))
        if not DI.crouchN then log(string.format("drop-in:    crouch: up to %g cm (DropInCrouch, at the full height; 0 = none)", tonumber(S.DropInCrouch) or 0)) end
        DI.crouchN = (DI.crouchN or 0) + 1
    end
    DI.twist = function()                                -- (v221) the game's own upper-body twist held off for this frame (DropInNoTwist)
        if (tonumber(S.DropInNoTwist) or 0) == 0 then return end
        q(function() inst.ShoulderAdditiveAlpha = 0.0 end)
        if not DI.twistSaid then DI.twistSaid = true log("drop-in:    the game's shoulder twist is held off through the drop (DropInNoTwist)") end
    end
    DI.armsOff = function()                              -- shut now (the native half eases them down; on a bail it drops them at once)
        if DI.armsN and type(HJN_Set) == "function" then pcall(HJN_Set, "droparms", 0) end
        if DI.crouchN and type(HJN_Set) == "function" then pcall(HJN_Set, "dropcrouch", 0) end   -- (v221)
        DI.armsN, DI.armsAt, DI.armsAir, DI.armsDeg, DI.armsYaw = nil, nil, nil, nil, nil
        DI.crouchN, DI.crouchTop, DI.twistSaid = nil, nil, nil
    end
    local function letGo(why)
        DI.armsOff()                                      -- (v218)
        if type(HJN_Set) == "function" then pcall(HJN_Set, "notoggle", 0) end   -- (v210)
        if DI.th and type(HJN_Set) == "function" then pcall(HJN_Set, "throwanim", 0) end   -- (v211) a set-down's animation ends with it (the native half's own watch would end it 0.4 s on)
        if DI.th and DI.th.pinned and type(HJN_SetDown) == "function" then pcall(HJN_SetDown, "end") end   -- (v212) ...and so does a set-down on the coping's hold of the board bone, and its mount's gate should that be up (the parts and the grounded hold are given back below)
        if type(HJN_BoardParts) == "function" then pcall(HJN_BoardParts) end
        if DI.ground and type(HJN_GroundHold) == "function" then
            local n = tonumber(HJN_GroundHold(0)) or 0
            if DI.state then log(string.format("drop-in:    the game's grounded check given back (answered for the held board %d times)", n)) end
        end
        DI.ground, DI.held = nil, nil
        if DI.state then log("drop-in: " .. why) end
        DI.state, DI.rideAt = nil, nil
        DI.th, DI.sd, DI.tapOver = nil, nil, nil                   -- (v211)
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
        DI.yPress = os.clock()                                 -- (v210) a Y press: the one thing that steps you off a held board on purpose
        -- (v211) ...AND A Y PRESS MADE ON THE BOARD starts a step-off: what the game reads in the frames after it is kept
        -- for DI.stepOffWatch (0.6 s of it; a second press inside that is a row of the same trace)
        do
            local bs0 = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            local T = DI.offTr
            if T and DI.yPress - T.t0 <= 0.6 then T.rows[#T.rows + 1] = string.format("%d:Y again", math.floor((DI.yPress - T.t0) * 1000 + 0.5))
            elseif bs0 >= 0 and (bs0 & 4) ~= 0 then DI.offTr = { t0 = DI.yPress, rows = {} } end
        end
        -- (v204) A Y PRESS ON FOOT THAT NOTHING COMES OF. "The game got into a bad state where it wasn't accepting controls"
        -- (9 Oct 18:59:44 on: put back on the board after a bail he was on foot 50 ms later, and from then nineteen Y
        -- presses in four seconds started no throwdown, the board in his hand). Which of the game's own tests said no
        -- was in no log. A press made on foot with the board in the hand is noted here; dropTick looks 0.7 s later
        -- (the game's throw shows as board mode 6 within a quarter second) and, when nothing has come of it, logs what
        -- those tests read (HJN_ToggleGates, native v108). Read only: nothing of the game's is changed.
        do
            local bs = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            if bs >= 0 and (bs & 4) == 0 and (bs & 1) == 0 and ((bs >> 4) & 0xff) == 5 then
                if not DI.yAt then DI.yFall = tostring(q(function() return mv:IsFalling() end, "?")) end   -- (v210) falling = the game takes its instant way, not the throw
                DI.yAt = DI.yAt or os.clock()
            end
        end
        -- (v123) a second tap of Y while the board is still being set out = you want on in SWITCH (the game's own throwdown
        -- does that by itself; on the dropped quarter pipe it fails and the mod's own mount took no notice of the tap)
        -- (v211) ...and in a set-down for as long as its animation has not begun (the first quarter second): the clip is
        -- picked by the stance. Later than that the press is said and nothing more (the game's own Y is refused the while)
        -- ...AND NOT ONCE A SET-DOWN HAS LEFT ITS "throw" STATE (DI.tapOver): the window is counted from DI.t0, until
        -- build 210 always the press -- but every way out of "throw" (on the board, or the old way) writes a new DI.t0
        -- and the state "mount", which opened the window again. A Y pressed in the moment after a regular set-down's
        -- mount (he mashes it during the 1.8 s of the animation) was "Y tapped again -- you will be put on in SWITCH",
        -- and the first move then turned him and the board half round (the review's run in the stand-in world:
        -- "turned -180 deg ... riding SWITCH"). The old way's own window, with no set-down tried, is as it was
        -- (v223) ...AND WHILE A DROP-IN WAITS FOR THE BOARD (DI.again: Y pressed at the edge with the board only just
        -- picked up, the note at "JUST PICKED UP, AT AN EDGE"): a second tap within 0.6 s of the first is the same double
        -- tap. Build 222 took it for a new press (the wait began again, and the drop-in was regular); now it is kept with
        -- the wait, and dropTick hands it on as DI.sw when the set-down starts
        if DI.again and not DI.state and os.clock() - (DI.again.at or 0) < 0.6 then
            if not DI.again.sw then
                DI.again.sw = true
                log("drop-in: Y tapped again while the drop-in waits for the board -- you will be put on in SWITCH")
            end
            return
        end
        if DI.state == "throw" and DI.th and DI.th.started and not DI.sw and not DI.th.late then
            DI.th.late = true
            log(string.format("drop-in: Y tapped again %.2f s after the first -- too late for SWITCH in a set-down (its animation has begun)", os.clock() - (DI.t0 or 0)))
        end
        if ((DI.state == "mount" and not DI.tapOver) or (DI.state == "throw" and DI.th and not DI.th.started)) and not DI.sw and os.clock() - (DI.t0 or 0) < 0.6 then
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
        -- (v213) ...OR A SLOW WALK RIGHT UP TO THE EDGE. "I feel like a couple of those should have worked, but they
        -- didn't." (10 Oct: Y at 79 cm/s, the last steps to a coping, was "you are moving".) Under DropInWalkSpeed the
        -- press goes on to the look for an edge and is a drop-in only for one within DropInSetReach, where the set-down
        -- on the coping stands him still itself (dropTick's "throw" moves him and zeroes his speed every frame)
        local slow = (not jumping and sp > S.DropInStillSpeed and sp <= (tonumber(S.DropInWalkSpeed) or 0)) and sp or nil
        if jumping or (sp > S.DropInStillSpeed and not slow) then                     -- (v166) a standstill (it was 40 cm/s)
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
        -- (v213) THE SET-DOWN ON THE COPING IS THE DROP-IN. "The drop-ins look great ... the mode of starting behind the
        -- edge, getting on the board and sliding forward, just turn that off. Where he sets it right on the coping is
        -- money. So let's just embrace that ... Put a buffer zone ... I think you have 450 millimeters or something. So
        -- that's probably fine ... if the toes are overhanging it also engages." (10 Oct: 35 set-downs on the coping,
        -- 35 mounted there and reached SET.) coping = that way can be had here (the settings, native v114, this build of
        -- the game); it decides three things below: a press from farther off than DropInSetReach, a slow walk-up, and a
        -- press made on a board that was only just picked up.
        local coping = S.DropInSetDown ~= 0 and (S.DropInSetEdge or 1) ~= 0 and (tonumber(NATIVE.v) or 0) >= 114 and type(HJN_SetDown) == "function" and type(HJN_Set) == "function"
        local waitBoard = nil
        do
            local bs = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            local loose = bs >= 0 and ((bs >> 4) & 0xff) == 8
            -- (v213) JUST PICKED UP, AT AN EDGE: THE DROP-IN WAITS FOR THE BOARD. Nine presses of 10 Oct came 0.4 to
            -- 0.9 s after the press that picked the board up after a fall, by an edge: "the board lay loose 0.6 s ago
            -- -- no drop-in", and the game's own throw went over the drop. The v180 rule below was written for the
            -- old drop-in, which mounted him wherever the board lay; the set-down takes a board that is free in the
            -- hand and nothing else. So with an edge in reach the press is kept (waitBoard: decided once the edge is
            -- known), the game's own throw is held back, and dropTick asks again the moment the board is free.
            if not loose and not DI.againNow and coping and DI.looseAt and os.clock() - DI.looseAt < 1.5 then
                waitBoard = os.clock() - DI.looseAt
            elseif loose or (not DI.againNow and DI.looseAt and os.clock() - DI.looseAt < 1.5) then
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
        -- (v211) THE SET-DOWN, AN EXPERIMENT (DropInSetDown; with 0 all of it is passed over and the drop-in is build 210's,
        -- bar one thing of build 211's that no setting takes back: no first move where he already stands right, dropTick).
        -- "Right now for the drop-in he sets the board down in front of the coping, gets on the board, and then it just
        -- kind of rides him into position like a ghost movement ... What is the hope of actually getting an animation
        -- where he sets the board directly on the coping and then steps on it? Since it's not a baked-in animation, I
        -- don't know how we'd do that ... we'll see if it bears any fruit with one test. If not, we'll revert back."
        -- (9 Oct.) What was found: the game has NO animation in which a hand takes the board to the ground (its standing
        -- throwdown drops it from hip height 35.8 cm ahead and 16 cm to the left, drags it back under the feet and steps
        -- on), and its mount wants the board level with ground under all four wheels -- so the last 57 cm out and the
        -- tail going down are always made with him on it. What CAN be had: the game's own throw is refused (it is
        -- physics, and by an edge it lost the board over the drop in 12 of that night's 26 set-ups; its Y acts 0.216 s
        -- after the press, and until then the controller's own toggle timer can be made to say no: HJN_Set "ygate",
        -- native v113), and the mod plays the game's throwdown ANIMATION itself, on foot, square to the edge and as
        -- close to it as the mount allows (HJN_Set "throwanim": on foot the board follows the skeleton's board bone, no
        -- physics). The board comes down with its middle DropInBack cm from the edge, he is walked onto it where it
        -- lies and put on at the animation's own moment, and the slide out takes DropInSetOutTime (0.35 s) with no first
        -- move before it: about 2.4 s from Y to SET against 3.45. He stands DropInBack + 35.8 cm back and 16 cm to the
        -- right of the edge point's line for it. The state is "throw" (dropTick); a step that does not come there =
        -- the old way from that step on, and the log says which.
        -- (v213) ONLY AT THE EDGE (the note at 'coping' above). Farther off than DropInSetReach there is no drop-in
        -- any more (build 212 set the board down 70 cm back there and slid it out: DropInFar=1 has that back); nor
        -- for a walk-up that is not at an edge; and a press on a board just picked up waits for it.
        if coping then
            local reach = tonumber(S.DropInSetReach) or 45
            if L.dist > reach and (tonumber(S.DropInFar) or 0) == 0 then
                log(string.format("Y on foot: an edge %.0f cm away, farther than DropInSetReach (%g cm) -- no drop-in (stand at the edge for one: the board is set on the coping there); the game's own throwdown%s", L.dist, reach, NATIVE.heldNote()))
                return
            end
            if slow and L.dist > reach then
                log(string.format("Y on foot: you are moving at %.0f cm/s -- no drop-in (stand still by the edge for one, or walk right up to it); the game's own throwdown%s", slow, NATIVE.heldNote()))
                return
            end
            if waitBoard then
                if L.dist <= reach then
                    DI.again = { at = os.clock(), till = os.clock() + 1.8 }
                    pcall(HJN_Set, "ygate", 0.5)
                    log(string.format("Y on foot: an edge %.0f cm away and the board picked up %.1f s ago -- the drop-in waits until the board is free in your hand (the game's own throw is held back meanwhile)", L.dist, waitBoard))
                else
                    log(string.format("Y on foot: the board lay loose %.1f s ago (just picked up after a fall) -- no drop-in; the game's own way back onto the board%s", waitBoard, NATIVE.heldNote()))
                end
                return
            end
        elseif slow then
            log(string.format("Y on foot: you are moving at %.0f cm/s -- no drop-in (stand still by the edge for one); the game's own throwdown%s", slow, NATIVE.heldNote()))
            return
        end
        DI.th, DI.sd, DI.tapOver = nil, nil, nil
        local th, thNo, thSay = nil, nil, {}                       -- (v212) thSay: what the set-down on the coping has to say, logged under the DROP-IN line
        if S.DropInSetDown ~= 0 then
            local bs = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            local loc = q(function() return s0:K2_GetActorLocation() end)
            local x0, y0, z0 = loc and tonumber(q(function() return loc.X end)), loc and tonumber(q(function() return loc.Y end)), loc and tonumber(q(function() return loc.Z end))
            if (tonumber(NATIVE.v) or 0) < 113 then thNo = "the native half is " .. (NATIVE.v and ("v" .. tostring(NATIVE.v)) or "not known yet") .. " and this takes v113"
            elseif type(HJN_DeckWorld) ~= "function" or type(HJN_BoardMount) ~= "function" then thNo = "the native half's board calls are not there"
            elseif not (yaw and x0 and y0 and z0) then thNo = "where you stand or which way you face could not be read"
            elseif bs < 0 or (bs & 13) ~= 0 or ((bs >> 4) & 0xff) ~= 5 then
                thNo = (bs < 0) and "no board was found" or string.format("the board is not free in your hand (board mode %d, flags %d: 1 = it lies loose, 4 = you are on it, 8 = the game is busy with it)", (bs >> 4) & 0xff, bs & 15)
            elseif (tonumber(HJN_Set("ygate", 0.6)) or 0) ~= 1 then thNo = "the game's own Y could not be refused (the native half did not write the controller's timer)"
            else
                local sq, back = math.deg(math.atan(L.oy, L.ox)), S.DropInBack + 35.8      -- the clip sets the board down 35.8 cm ahead and 16.0 to the left
                th = { x0 = x0, y0 = y0, z0 = z0, yaw0 = yaw, dyaw = ((sq - yaw + 540) % 360) - 180,
                       sx = L.x - L.ox * back - L.oy * 16.0, sy = L.y - L.oy * back + L.ox * 16.0 }
                -- (v212) THE SET-DOWN ON THE COPING (DropInSetEdge; native v114). "Can't we stand in front of the edge
                -- anymore? We're almost going to have to be standing on it, almost like less than a foot's length away, or
                -- almost even where the feet are hanging over the edge for it to make sense." (10 Oct.) Build 211 stood
                -- him DropInBack + 35.8 = 70 cm back by design (10 Oct 11:21:38, pressed 6 cm from the edge: "moved 65 cm,
                -- turned -3 deg to stand 70 cm from the edge"), because the game's mount was taken to need a level board
                -- with all four wheels on the ledge. Read off the exe, its test is made at HIS FEET and can be answered
                -- for (the native half's note at HJN_SetDown) -- so for a press made within DropInSetReach of the edge
                -- the board is held ON the coping while he steps on, and he is put on there: th.edge, and the rest is in
                -- dropTick's "throw". FARTHER OFF IT IS BUILD 211's SET-DOWN, not the game's own throw: that throw is
                -- what loses the board over the drop by an edge (15 of its 30 throws on 10 Oct), and 21 of the 29 presses
                -- on file were made from farther than 45 cm. SWITCH (a second tap) was build 211's set-down too, until
                -- build 223 (DropInSetSwitch: the note at "SWITCH ON THE COPING" in dropTick's "throw").
                local edgeWay = (S.DropInSetEdge or 1) ~= 0
                if edgeWay and not ((tonumber(NATIVE.v) or 0) >= 114 and type(HJN_SetDown) == "function") then
                    edgeWay = false
                    thSay[#thSay + 1] = string.format("the board is set ON the coping only with the native half v114 (this one is v%s) -- this one is set down behind the edge and slides out (build 211's way)", tostring(NATIVE.v))
                elseif edgeWay and L.dist > (S.DropInSetReach or 45) then
                    edgeWay = false
                    thSay[#thSay + 1] = string.format("an edge %.0f cm away, farther than DropInSetReach (%g cm): the board is set ON the coping only for a press made at the edge -- this one is set down behind it and slides out (build 211's way)", L.dist, S.DropInSetReach or 45)
                end
                if edgeWay then th.edge = true end
                -- (review) A PRESS MADE HANGING ON THE EDGE (his middle out past it, the capsule's round bottom on the
                -- edge): he stood lower than a man on the ledge does, and the set-down moves him at the height he was
                -- pressed at -- that much INTO the ledge on every frame, against the game's walking lifting him back.
                -- The ledge's own height then: its top by the edge (the look's: the ground 6 to 14 cm behind it, where
                -- he will stand) + the capsule's half height + the 2.15 cm the game's walking keeps a capsule over its
                -- floor. On the coping the same serves a top that rises to its edge. Not for one pressed HIGHER than
                -- that: the game's walking sets him down by itself.
                -- FROM 1 CM LOW (review 2; it was 3). 10 Oct 11:22:05 is such a press: his middle 10 cm past a coping,
                -- at a standstill, in the game's walking (build 211 lost it -- "an edge 18 cm away, but you face 178
                -- deg off square to it" -- and the game's own throw bailed him; native v114 finds it). A capsule
                -- hanging there is 1.5 cm low with a radius of 34 and 2.7 with one of 20: under 3 both. A man standing
                -- on the ledge reads within a quarter cm of that height (the walking keeps 1.9 to 2.4 cm under him),
                -- so 1 cm does not catch him.
                -- FOR THE COPING VARIANT -- AND FOR ANY SET-DOWN OF A PRESS MADE PAST THE EDGE (the look's distance
                -- under 0): with the menu's row off (DropInSetEdge 0) it is build 211's set-down that takes such a
                -- press, and it would move him 80 cm back over the ledge at the height he hung at.
                -- th.zp = the height he was pressed at: where the coping is given up before the animation with him
                -- pressed ON the ledge (dropTick: the arming refused, SWITCH) he goes to build 211's spot, 70 cm back,
                -- and that is not at the edge's height on a top that rises to it. Where he hung is no floor's height
                if edgeWay or L.dist < 0 then
                    local hh = tonumber(q(function() return s0.CapsuleComponent:GetScaledCapsuleHalfHeight() end))
                    local zs = hh and hh > 40 and hh < 140 and (L.top + hh + 2.15) or nil
                    if zs and z0 < zs - 1 and z0 > zs - 30 then
                        thSay[#thSay + 1] = string.format("you stood %.1f cm lower than a man stands at this edge (hanging on it, or the top rises to it) -- the set-down stands you at the height of the ledge's top by the edge", zs - z0)
                        th.z0, th.zp = zs, z0
                    end
                end
            end
        end
        DI.state, DI.L, DI.t0, DI.rideAt, DI.tries, DI.tryAt, DI.hang, DI.pitch, DI.pulled, DI.held, DI.ground = th and "throw" or "mount", L, os.clock(), nil, 0, nil, S.DropInHang, S.DropInPitch, false, nil, nil
        if th then th.t0, DI.th = DI.t0, th end
        DI.sw, DI.boosted, DI.nb0 = nil, nil, nil
        DI.remounts, DI.vk = 0, 1                                  -- (v210)
        DI.edgeAt = nil                                            -- (v212) when a set-down on the coping last put you on (dropTick)
        DI.armsN, DI.armsAt, DI.armsAir, DI.armsDeg, DI.armsYaw = nil, nil, nil, nil, nil   -- (v218) a new drop-in: the arms' numbers are sent again
        DI.crouchN, DI.crouchTop, DI.twistSaid, DI.armsTip = nil, nil, nil, nil   -- (v221)
        myAddr = addr(s0)
        ensureHook()
        -- (v103) THE GAME'S THROWDOWN NEEDS ROOM: it throws the board out ahead of you and bails when that spot is past the
        -- edge (from 57 cm back it landed, from 50 it bailed; v102's hold of the board on the ledge only made it bail on its
        -- first tick and flung the board). So you are set DropInStart cm back from the edge first, facing as you were.
        if not th and S.DropInStart > 0 and L.dist < S.DropInStart then      -- (v211) not for a set-down: the game throws nothing there, and he is moved to his own spot in "throw"
            local loc = q(function() return s0:K2_GetActorLocation() end)
            local bx, by = L.x - L.ox * S.DropInStart, L.y - L.oy * S.DropInStart
            local moved = loc and pcall(function() s0:K2_SetActorLocation({ X = bx, Y = by, Z = loc.Z }, false, {}, true) end)
            log(string.format("drop-in:    stepped back from %.0f to %.0f cm from the edge for the game's throwdown (%s)", L.dist, S.DropInStart, moved and "ok" or "FAILED"))
        end
        log(string.format("DROP-IN: an edge %.0f cm from you (you face %.0f deg off square to it), the ground %.0f cm down just past it, %.0f cm down further out (slope there %.0f deg), "
            .. "a lip of %.1f cm on the edge -- %s", L.dist, off, L.near, L.far, L.slope, L.lip,
            th and (th.edge and "a SET-DOWN ON THE COPING (DropInSetDown, DropInSetEdge): the game's own throw is refused, its throwdown animation is played at the edge and the board held on the coping"
                     or "a SET-DOWN (DropInSetDown): the game's own throw is refused, its throwdown animation will be played by the edge") or "waiting for the game to put you on the board"))
        -- (v212) THE LOOK CAN NOW SAY THE EDGE IS BEHIND HIS MIDDLE (native v114: where the ground under his middle is not
        -- the floor he stands on, it starts from the ledge behind him, and it counts the distance from where he really
        -- stands). "An edge -10 cm from you" is then what the line above reads; said in words here. 10 Oct 11:22:05
        -- was such a press, his middle 10 cm past a coping with his toes out over it -- where he asked to stand
        if L.dist <= -0.5 then log(string.format("drop-in:    your middle is %.0f cm PAST that edge (you stand out over it): the native half looked from the ledge behind you", -L.dist)) end
        if thNo then log("drop-in:    DropInSetDown is on, but this one goes the old way: " .. thNo) end
        for _, say in ipairs(thSay) do log("drop-in:    " .. say) end   -- (v212)
    end

    -- (v195) THE THROWDOWN'S SPEED. A tester's idea: "a speed burst for the game's native throwdowns". The game's own
    -- throwdown, by SessionTweaks' trace of 7 Oct (20:37:22, 20:42:15): 0.22 s after Y the board's movement mode goes 5 (in
    -- your hand) -> 6 (thrown), and 0.52 s later, in one frame, 6 -> 1 with you on it. So: mode 6 seen while you are off
    -- the board and you on the board within 0.3 s of it = the game's throwdown has mounted you. Then every part of the
    -- board gets a new velocity, the way it rolls (HJN_BoardKick: the drop-in's own release). 120 ms after that the game's
    -- own reading is logged, and the kick given once more should the mount have taken it back. (7 Oct, some thirty throws:
    -- the game then reads 88 to 90 % of what was asked for, whatever the speed, and caps none of it.)
    -- Not for the mod's own ways onto the board: a drop-in holds DI.state from the Y press on (its throwdown only sets
    -- you on the ledge), and the board hop mounts a board that lies loose, which never passes through mode 6.
    -- (v196) ...AND THE THROW ITSELF IS PLAYED FASTER. "Just because we speed up the player after he throws down doesn't
    -- mean it looks natural: he's throwing down the board at the same rate every time. Can you pre-read the throwdown
    -- speed and speed up the throwdown animation as well?" What times the game's throwdown is its animation (the exe:
    -- ASkaterCharacterBase::DoBoardThrowdown sets the skater's throwdown flag and the board's mode 6; the animation's
    -- ThrowdownCompleted notify asks for the mount; USkaterMovementComponent::ConsumeInputVector keeps him walking, the
    -- while, the way and at the share of his top speed he had at the press). So for the length of the throw the SKATER'S
    -- OWN CLOCK runs fast -- the actor's CustomTimeDilation: the engine hands every tick of the actor and of its
    -- components (the walk, the animation and its notifies) that many times the frame's time. At k he covers k times the
    -- ground on k times the steps and is on the board in 1/k of the time; nothing of the game's own sequence is touched.
    -- Never over ThrowdownRateMax (2.5 -- past that it reads as fast-forward; what k cannot carry still comes at the
    -- mount). The clock is put back the frame you are on the board, the frame the throw ends any other way, after 1.5 s
    -- whatever happens, and by the 2 s tick should this watch stop being called. The kick comes 20 ms after the mount.
    -- (v197) ...AND IT IS A MULTIPLE OF THE SPEED YOU THROW AT, NOT AN ADDED SPEED. "If the player is standing still, the
    -- throwdown shouldn't add any velocity. In other words it's a multiplier, not an adder." v195/196 added ThrowdownBoost
    -- cm/s to whatever the board had -- from a standstill it shot you off the way you faced (7 Oct 21:24:12, 21:25:15,
    -- 21:27:07: 0 -> 490, 1333, 270 cm/s). ThrowdownScale (1 = the game's own) multiplies: the throw is played that many
    -- times as fast (k = the scale, up to ThrowdownRateMax) and the board gets its velocity times the scale. Under 30
    -- cm/s at the press it is a standing throw: its clock is left alone and nothing is given to the board.
    DI.td = {}
    DI.tdSlow = function(why)                                -- the skater's clock back to the game's (why = nil: you are on the board)
        local D = DI.td.fast
        if not D then return end
        DI.td.fast = nil
        local ok = alive(D.sk) and pcall(function() D.sk.CustomTimeDilation = 1.0 end)
        if why or not ok then
            log(string.format("throwdown:    the throw's speed-up taken off after %.2f s (%s)%s", os.clock() - D.t0, tostring(why or "you are on the board"),
                ok and "" or " -- the skater is gone, or its clock could NOT be written"))
        end
    end
    NATIVE.tdBackstop = function()                           -- (the 2 s tick)
        local T = DI.td
        if T.fast then
            if os.clock() - T.fast.t0 > 2 then DI.tdSlow("by the 2 s tick: the watch had not") end
            return
        end
        -- (v197) ...and with no throw on, a clock that still runs at the rate the last throw was given is put back
        if T.lastK and alive(s0) then
            local sk = s0
            local cur = tonumber(q(function() return sk.CustomTimeDilation end, nil))
            if cur and math.abs(cur - 1) > 0.001 and math.abs(cur - T.lastK) < 0.001 then
                local ok = pcall(function() sk.CustomTimeDilation = 1.0 end)
                log(string.format("throwdown: the skater's own clock still ran at x%.2f with no throw on -- put back by the 2 s tick (%s)", cur, ok and "ok" or "FAILED"))
            end
        end
    end
    DI.tdFast = function(now)                                -- the first frame of a throw
        local T = DI.td
        local scale, kmax = tonumber(S.ThrowdownScale) or 1, tonumber(S.ThrowdownRateMax) or 1
        T.still = false
        if scale < 1.005 or DI.state ~= nil or T.fast then return end
        local v0 = math.sqrt((T.fx or 0) ^ 2 + (T.fy or 0) ^ 2)
        if v0 < 30 then
            T.still = true
            log(string.format("throwdown: thrown standing still (%.0f cm/s) -- the game's own throw, nothing added (ThrowdownScale x%.2f is a multiple of the speed you throw at)", v0, scale))
            return
        end
        local k = math.min(kmax, scale)
        if k < 1.02 then return end
        local sk = s0
        local was = tonumber(q(function() return sk.CustomTimeDilation end, nil))
        if not was or math.abs(was - 1) > 0.001 then
            log("throwdown: the throw is not sped up -- the skater's own clock " .. (was and string.format("already runs at x%.2f (something else has set it)", was) or "could not be read"))
            return
        end
        if not pcall(function() sk.CustomTimeDilation = k end) then
            log("throwdown: the throw is not sped up -- the skater's own clock could not be written")
            return
        end
        T.fast, T.lastK = { t0 = now, k = k, sk = sk }, k
        log(string.format("throwdown: thrown at %.0f cm/s with ThrowdownScale x%.2f -> the throw is played x%.2f (ThrowdownRateMax %g): about %.0f cm/s over the ground, on the board in about %.2f s",
            v0, scale, k, kmax, v0 * k, 0.52 / k))
    end
    DI.tdWatch = function(now, bs)
        local T = DI.td
        if bs < 0 then DI.tdSlow("no board, or no skater") return end
        local onb, bmode = (bs & 4) ~= 0, (bs >> 4) & 0xff
        if not onb then
            T.on, T.go = false, nil
            if bmode == 6 then                               -- thrown: how you move, read while you are still on foot
                local first = not T.thrown0
                if first then T.thrown0, T.real, T.gap = now, 0, nil end
                T.thrown, T.drop = now, DI.state ~= nil
                local vel = q(function() return mv.Velocity end, nil)
                T.fx, T.fy = vel and (tonumber(vel.X) or 0) or 0, vel and (tonumber(vel.Y) or 0) or 0   -- (in the skater's own time: under the speed-up the ground sees k times this)
                if first then DI.tdFast(now) end
                if T.fast then
                    if now - T.fast.t0 > 1.5 then DI.tdSlow("1.5 s and still not on the board") end
                    -- for the log: how fast he really went, and how far off the board was (it is steered after him)
                    local real = type(HJN_MeshSpeed) == "function" and tonumber(HJN_MeshSpeed()) or 0
                    if real > T.real then T.real = real end
                    local loc = q(function() return s0:K2_GetActorLocation() end)
                    local dxs, dys = tostring(type(HJN_DeckWorld) == "function" and HJN_DeckWorld() or ""):match("^(%S+) (%S+)")
                    local lx, ly = loc and tonumber(q(function() return loc.X end, nil)), loc and tonumber(q(function() return loc.Y end, nil))
                    if lx and ly and tonumber(dxs) and tonumber(dys) then T.gap = math.sqrt((tonumber(dxs) - lx) ^ 2 + (tonumber(dys) - ly) ^ 2) end
                end
            else
                if T.thrown0 then DI.tdSlow("the throw ended off the board, board mode " .. bmode) end
                T.thrown0 = nil
            end
            return
        end
        local F = T.fast
        if F then DI.tdSlow(nil) end                         -- on the board: the game's own time again, this frame
        if not T.on then                                     -- the frame you are on the board
            T.on = true
            local thrown, t00 = T.thrown, T.thrown0
            T.thrown, T.thrown0 = nil, nil
            local scale = tonumber(S.ThrowdownScale) or 1
            if scale < 1.005 or T.still or not thrown or now - thrown > 0.3 or T.drop or DI.state ~= nil then return end
            T.go = { t0 = now, at = now + 0.02, scale = scale, kicks = 0,
                     note = F and string.format("; the throw took %.2f s at x%.2f, up to %.0f cm/s over the ground, the board %s from you at its end", now - (t00 or now), F.k, T.real or 0,
                                               T.gap and string.format("%.0f cm", T.gap) or "?")
                              or string.format("; the throw took %.2f s, not sped up", now - (t00 or now)) }
        end
        local G = T.go
        if not G or now < G.at then return end
        if DI.state ~= nil or modeNow() == MODE_BAILING or not NATIVE.boardParts or type(HJN_BoardKick) ~= "function" or type(HJN_BoardParts) ~= "function" then
            T.go = nil
            return
        end
        local function kick()
            local parts = NATIVE.boardParts()
            local took = parts and tonumber(HJN_BoardParts(table.unpack(parts))) or 0
            local n = 0
            if took > 0 then n = tonumber(HJN_BoardKick(G.tx, G.ty, G.tz, 0, G.ox, G.oy)) or 0 end
            pcall(HJN_BoardParts)                            -- (the parts let go of again)
            return n
        end
        if G.kicks == 0 then
            local vel = q(function() return mv.Velocity end, nil)
            local vx, vy, vz = vel and (tonumber(vel.X) or 0) or 0, vel and (tonumber(vel.Y) or 0) or 0, vel and (tonumber(vel.Z) or 0) or 0
            local sp = math.sqrt(vx * vx + vy * vy + vz * vz)
            -- (v196) this soon after the mount the board may not have been handed the walk's velocity yet: then that is
            -- what is multiplied (should the game write it afterwards, the check below gives the speed again)
            local fsp, base = math.sqrt((T.fx or 0) ^ 2 + (T.fy or 0) ^ 2), ""
            if fsp >= 30 and sp < 0.5 * fsp then base = string.format(" (the walk's: the board read %.0f so soon)", sp) vx, vy, vz, sp = T.fx, T.fy, 0, fsp end
            if sp < 30 then                                  -- (v197) nothing to multiply
                T.go = nil
                log(string.format("throwdown: on the board at %.0f cm/s -- nothing added (ThrowdownScale x%.2f is a multiple of the speed you throw at)%s", sp, G.scale, G.note or ""))
                return
            end
            local on = math.sqrt(vx * vx + vy * vy)
            G.ox, G.oy = (on > 0.1 * sp) and vx / on or 1, (on > 0.1 * sp) and vy / on or 0
            G.tx, G.ty, G.tz, G.sp0, G.add = vx * G.scale, vy * G.scale, vz * G.scale, sp, sp * (G.scale - 1)
            G.n = kick()
            G.kicks, G.at = 1, now + 0.12
            log(string.format("throwdown: the game's own throwdown put you on the board at %.0f cm/s%s (you ran at %.0f) -> x%.2f = %.0f cm/s (%.0f km/h), the way the board rolls (%d parts%s)%s",
                sp, base, fsp, G.scale, sp * G.scale, sp * G.scale * 0.036, G.n, (G.n > 0) and "" or " -- NOT kicked", G.note or ""))
            return
        end
        local cur = tonumber(q(function() return mv:GetCurrentSpeed() end, -1)) or -1
        if G.kicks == 1 and G.n > 0 and cur >= 0 and cur < G.sp0 + G.add * 0.5 then
            G.kicks, G.at = 2, now + 0.12
            log(string.format("throwdown:    the game reads %.0f cm/s %.0f ms after the mount (%.0f was asked for) -> the speed given once more (%d parts)",
                cur, (now - G.t0) * 1000, G.sp0 + G.add, kick()))
            return
        end
        log(string.format("throwdown:    the game reads %.0f cm/s %.0f ms after the mount (%.0f before, %.0f asked for)", cur, (now - G.t0) * 1000, G.sp0, G.sp0 + G.add))
        T.go = nil
    end

    -- (v211) THE STEP-OFF THAT NEVER ENDS. "The game was stuck in a state and I couldn't input any controls, so I had to
    -- teleport and then it came back." 9 Oct 23:26:07.6 to 23:26:16.4: a Y press on the board put him on foot with no
    -- step-off animation, and for 8.8 s seven X presses, two Y, four A and a B did nothing; D-pad Up (the session marker)
    -- ended it. The one reading of that stretch (23:26:12, v204's "NOTHING came of that press") has "pick-up flag 1": the
    -- game's own IsPickingUp, left set. Read off the exe: while it is set the controller's CanToggleOnBoard says no (Y),
    -- OnFoot_Jump returns (X), and the walk follows the stick by 2 % a tick (he keeps running the way he stepped off). A
    -- step-off (DoBoardPickup) sets the flag and picks its animation by whether the board is on the ground: not on the
    -- ground = BoardToFootTransitionType 0 = NO animation -- and the one thing that ever ends a pick-up is that
    -- animation's own end (its ThrowdownCompleted notify asks for the toggle, the skater's next Tick runs
    -- ApplyToggleOnBoard, and SetOnFootMode clears the flag). The game steps off this way whenever the board is not
    -- "falling", and a board that leaves the ground without a pop is not falling for its first 75 to 200 ms: a Y press
    -- (acted on 0.2 s late) that lands in that gap sets the flag with nothing to clear it. A bail, a new skater or the
    -- marker teleport clear it; nothing else does. None of the mod's own holds was on (no drop-in state, no hop, the
    -- bumper mask and the mute off, native v112's toggle drop never fired): it is a race of the game's own.
    -- So: on foot, in play, the flag set and no throwdown on -- with the animation type at 0 for a quarter second of
    -- frames (a healthy step-off shows 1 or 2 until its end, and 0 for one frame at most), or the flag standing for 2 s
    -- whatever the type (the step-offs of 9 Oct ended 0.47 to 0.65 s in) -- the mod asks the game for what the missing
    -- notify would have asked for: SetPendingApplyToggleOnBoard, the end every step-off gets. Asked again half a second
    -- on, three times at most, then left alone. StepOffUnstick=0: the game is asked nothing, it is only logged.
    -- THE TRIGGER IS INFERRED: no reading of the board's grounded and falling flags exists for the frame of that toggle.
    -- So a Y press made on the board opens a trace (dropKey), a row whenever one of those readings changes, and the
    -- first try's log line carries it -- if the cause is as read here, the row where "B" turns to "f" has neither G nor
    -- F, with P and the animation type 0.
    DI.so = {}
    DI.stepOffWatch = function(now)
        local P = DI.so
        local dt = math.min(math.max(now - (P.last or now), 0), 0.05)   -- a pause or a hitch counts as one frame
        P.last = now
        if not alive(s0) then
            if P.acc then DI.so = { last = now } end
            DI.offTr = nil
            return
        end
        local an = nil
        local T = DI.offTr
        if T then                                             -- the frames after a Y press on the board (dropKey)
            if now - T.t0 > 0.6 or #T.rows >= 40 then DI.offTrLast, DI.offTr = T, nil
            else
                an = alive(inst)
                if an then
                    local bs = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
                    local row = string.format("%s%s%s%s b%d t%s",
                        (q(function() return an.IsOnBoard end, false) == true) and "B" or "f",
                        (q(function() return an.IsGrounded end, false) == true) and "G" or "-",
                        (q(function() return an.IsFalling end, false) == true) and "F" or "-",
                        (q(function() return an.IsPickingUp end, false) == true) and "P" or "-",
                        (bs >= 0) and ((bs >> 4) & 0xff) or -1, tostring(q(function() return an.BoardToFootTransitionType end, "?")))
                    if row ~= T.was then                      -- a row whenever a reading changes
                        T.was = row
                        T.rows[#T.rows + 1] = string.format("%d:%s", math.floor((now - T.t0) * 1000 + 0.5), row)
                    end
                end
            end
        end
        local flag = q(function() return s0:IsPickingUp() end, false) == true
        local pu = flag and q(function() return s0:IsOnBoard() end, true) ~= true
            and q(function() return s0:IsDoingThrowdown() end, true) ~= true
            and modeNow() == 0                                -- on foot and in play (a bail is mode 5, the replay editor 6)
        if not pu then
            if P.asked then
                local how = P.did and "the mod asked the game to end it" or "it was logged (the game was asked nothing)"
                if flag then
                    log(string.format("step-off: %.2f s after %s its flag still stands, but you are no longer on foot in play (mode %s) -- the watch starts over",
                        now - P.asked, how, tostring(modeNow())))
                else
                    log(string.format("step-off: ended %.2f s after %s%s", now - P.asked, how, P.did and " -- Y and the jump are yours again" or ""))
                end
            end
            if P.acc then DI.so = { last = now } end
            return
        end
        if not an then an = alive(inst) end
        local bt = an and tonumber(q(function() return an.BoardToFootTransitionType end, nil)) or nil
        P.acc = (P.acc or 0) + dt
        P.zero = (bt == 0) and ((P.zero or 0) + dt) or nil       -- 0 on frames in a row: a healthy step-off shows it for one frame at most, at its end
        local why = (P.zero and P.zero >= 0.25) and "no step-off animation is playing (the game's animation type has read 0 for a quarter second)"
            or (P.acc >= 2.0) and string.format("its flag has stood for %.1f s, longer than any step-off lasts (animation type %s)", P.acc, tostring(bt)) or nil
        if not why then return end
        if P.asked and now - P.asked < 0.5 then return end
        if (P.tries or 0) >= 3 then
            if not P.told then P.told = true log("step-off: still not ended after 3 tries -- left alone (a teleport to the session marker ends it)") end
            return
        end
        P.tries = (P.tries or 0) + 1
        local act = (tonumber(S.StepOffUnstick) or 1) ~= 0
        -- what the animation's ThrowdownCompleted notify does: the skater's next Tick -> ApplyToggleOnBoard(true) -> SetOnFootMode
        local ok = act and pcall(function() s0:SetPendingApplyToggleOnBoard() end)
        P.asked, P.did = now, P.did or (ok == true)
        local tr = DI.offTr or DI.offTrLast
        log(string.format("step-off: the game's pick-up has not ended -- %s; %s. On foot Y and the jump are dead while its flag stands. %s%s | the game's own tests read: %s | %s",
            why, DI.yPress and string.format("%.2f s after the last Y press", now - DI.yPress) or "no Y press was seen",
            act and (ok and "The mod asked the game to end it (what the end of the step-off animation asks)" or "The mod's call to end it FAILED")
                or "StepOffUnstick=0: only logged, the game is asked nothing",
            (P.tries > 1) and string.format(" (try %d of 3)", P.tries) or "",
            tostring(type(HJN_ToggleGates) == "function" and HJN_ToggleGates() or "(the native half is older than v108)"),
            (P.tries > 1) and "(what the game read after the Y press: in the first try's line)"
                or tr and string.format("what the game read after the Y press made on the board %.2f s ago (ms after it: B on the board / f on foot, G grounded, F falling, P picking up, b the board's mode, t the step-off animation's type; a row whenever one changes): %s",
                                        now - tr.t0, table.concat(tr.rows, ", "))
                or "no Y press on the board was seen before it (no frames kept)"))
        if not act then P.tries, P.told = 3, true end         -- logged once; nothing more until it ends
    end

    NATIVE.dropBusy = function() return DI.state ~= nil and DI.state ~= "ride" end   -- (v106) the ride monitor after a drop-in does not block clicks
    NATIVE.dropTick = function(now)
        if DI.flyT and DI.th ~= DI.flyT then   -- (v216) a set-down that ended while he was flown over the edge (a bail, the old way): the engine's falling takes him
            if q(function() return mv.MovementMode end, 0) == 5 and q(function() return s0:IsOnBoard() end, false) ~= true then
                q(function() mv:SetMovementMode(3, 0) end)
                log("drop-in:    the set-down ended while you were held over the edge -- handed to the engine's falling")
            end
            DI.flyT = nil
        end
        do   -- (v215) A LANDING THAT STOPS YOU DEAD. "I just did a stalefish grab at 8:24-ish ... I landed with zero velocity.
            -- That is something I see like every 10 to 30 tricks, grabs ... you land and it just kills all the velocity."
            -- (10 Oct: the Stalefish of 20:24:54 and the Melon of 20:26:28, both held to the touchdown; SessionTweaks has
            -- "riding fakie" within a tenth of a second of both landings, which is what the game makes of a board that
            -- stands.) The one thing in the exe that stops a board at a landing: StartSkateboardingPhysics calls ForceStop
            -- when the board's hold-still flag is parked (board movement +0x7eb, 0x10 parked as 0x20 when it goes into the
            -- air; the flag is raised by ForceStop itself at a mount and after the replay editor, and is meant to drop
            -- by itself). Whether that is what happens here is NOT established -- so two things: while you are on the
            -- board in the air the flag is let go of (HJN_Set "boardgo", native v113; it answers 1 when it was up, and
            -- that is logged: a line here before a landing that keeps its speed is the proof), and every landing that
            -- loses the speed is logged with what was read, whether or not the flag was up.
            local bs0 = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            local onb, bm0 = bs0 >= 0 and (bs0 & 4) ~= 0, (bs0 >= 0) and ((bs0 >> 4) & 0xff) or -1
            local LS = DI.ls or {}
            DI.ls = LS
            local sp0 = type(HJN_MeshSpeed) == "function" and tonumber(HJN_MeshSpeed()) or -1
            if onb and bm0 == 3 then
                LS.air, LS.land = now, nil
                if sp0 >= 0 then LS.sp = sp0 end
                if (tonumber(S.LandHoldFix) or 1) ~= 0 and (tonumber(NATIVE.v) or 0) >= 113 and type(HJN_Set) == "function" then
                    if (tonumber(HJN_Set("boardgo", 1)) or 0) == 1 then
                        LS.n, LS.hit = (LS.n or 0) + 1, now
                        if LS.n <= 60 then log(string.format("landing: the game's hold-still flag was up on the board in this air (left up it stops the board dead at touchdown) -- let go (%d so far)", LS.n)) end
                    end
                end
            elseif onb and bm0 == 1 and LS.air then
                LS.land = LS.land or now
                if now - LS.land >= 0.2 then
                    if (LS.sp or 0) > 250 and sp0 >= 0 and sp0 < 0.3 * LS.sp then
                        LS.lost = (LS.lost or 0) + 1
                        if LS.lost <= 60 then
                            log(string.format("landing: the speed was LOST at touchdown -- %.0f cm/s over the ground in the air, %.0f cm/s 0.2 s after it (%d such landings so far; the hold-still flag %s; %s)",
                                LS.sp, sp0, LS.lost, (LS.hit and LS.land - LS.hit < 3) and "WAS up in this air and was let go: it is not what stopped you" or "was not up in this air",
                                tostring(type(HJN_ToggleGates) == "function" and HJN_ToggleGates() or "?"):sub(1, 160)))
                        end
                    end
                    LS.air, LS.land, LS.sp = nil, nil, nil
                end
            elseif not onb or (bm0 ~= 1 and bm0 ~= 3) then LS.air, LS.land, LS.sp = nil, nil, nil end
        end
        if DI.again then                                 -- (v213) a drop-in asked for while the board was still on its way into the hand (dropKey's note)
            local G = DI.again
            local bs = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            if DI.state or active or now > G.till or bs < 0 or (bs & 4) ~= 0 then DI.again = nil
            elseif (bs & 13) == 0 and ((bs >> 4) & 0xff) == 5 and now - G.at >= 0.15 then
                DI.again = nil
                DI.againNow = true
                local okg, errg = pcall(NATIVE.dropKey)
                DI.againNow = nil
                if not okg then log("drop-in: the waiting drop-in could not be started: " .. tostring(errg)) end
                if okg and G.sw and (DI.state == "throw" or DI.state == "mount") and not DI.sw then   -- (v223) the second tap made while it waited (dropKey): the drop-in begun just now is a switch one
                    DI.sw = true
                    log("drop-in: Y was tapped twice while it waited for the board -- you will be put on in SWITCH")
                end
            elseif type(HJN_Set) == "function" then pcall(HJN_Set, "ygate", 0.3) end
        end
        do   -- (v211) THE STEP-OFF THAT NEVER ENDS (DI.stepOffWatch): looked for every frame, whatever the drop-in is doing
            local okp, errp = pcall(DI.stepOffWatch, now)
            if not okp then logOnce("soerr", "step-off watch error: " .. tostring(errp)) end
        end
        if type(HJN_BoardState) == "function" then       -- (v180, review) the board's own movement mode 8 = it lies loose (a fall, a failed throwdown): see dropKey
            local bs = tonumber(HJN_BoardState()) or -1
            if bs >= 0 and ((bs >> 4) & 0xff) == 8 then DI.looseAt = now end
            if DI.yAt then                                    -- (v204) see dropKey
                local bmode = (bs >= 0) and ((bs >> 4) & 0xff) or -1
                if bs < 0 or (bs & 4) ~= 0 or bmode ~= 5 or DI.state ~= nil then DI.yAt = nil      -- on the board, thrown, or the mod's own drop-in: something came of it
                elseif now - DI.yAt >= 0.7 then
                    DI.yAt = nil
                    if now - (DI.yTold or -1e9) > 3 then
                        DI.yTold = now
                        log("Y on foot: NOTHING came of that press in 0.7 s (no throwdown; the board is still in your hand) -- the game's own tests read: "
                            .. tostring(type(HJN_ToggleGates) == "function" and HJN_ToggleGates() or "(the native half is older than v108)")
                            .. "; at the press the game had you falling: " .. tostring(DI.yFall)
                            .. " (the controller's timer is set to 0.5 when its Y handler passes its own test: far under 0 here = it did not pass, or was never called)")
                    end
                end
            end
            if s0 and mv then                             -- (v195) the throwdown's speed burst (v196: also with no board -- a sped-up throw is ended)
                local okt, errt = pcall(DI.tdWatch, now, bs)
                if not okt then logOnce("tderr", "throwdown burst error: " .. tostring(errt)) end
            end
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
        -- (v210) NO BOARD TOGGLE OF THE GAME'S WHILE YOU ARE HELD ON THE BOARD. Five drop-in set-ups of ten on 9 Oct
        -- (22:33-22:35) ended "you are off the board (mode 0)" about a second after the board's parts were taken: no bail,
        -- no Y pressed, and each after the same number of the game's grounded checks (1348..1351) -- one fixed time. Read
        -- off the exe and the anim blueprint: ApplyToggleOnBoard is a true toggle (on the board = stepped off), and the
        -- blueprint asks for one (SetPendingApplyToggleOnBoard) when the throwdown ANIMATION ends. By an edge the game's
        -- throw sends the board over the drop, the mod mounts you itself half a second on -- and the animation, still
        -- playing, ends a second later and toggles you off. The native half (v112) drops a pending toggle found while you
        -- are ON the board for as long as this is refreshed (on foot it is the mount itself and is left alone).
        if st ~= "ride" and type(HJN_Set) == "function" then pcall(HJN_Set, "notoggle", 0.3) end
        -- (v211) THE SET-DOWN (DropInSetDown, an experiment: the note in dropKey). On foot all the way to the mount:
        --   0 - 0.30 s  turned square to the edge and moved to the spot the animation is played from, eased;
        --   0.24 s      the game's own throw has not come (board mode 6 = the veto came too late: the old way) -> the
        --               native half starts the game's throwdown animation (clip type 1 or 2 by stance, 2 for a goofy
        --               rider). To the game the board is still in the hand: it follows the skeleton's board bone down;
        --   landed      the deck within 9 cm of the ledge top, 0.5 to 0.6 s in. From here the animation drags the board
        --               back under him (36 cm back and 17 across, at up to 150 cm/s) -- instead HE is moved on by what
        --               the deck moved, three tenths of the gap a frame, so the deck stays where it came down. (Half
        --               the gap, the first plan, holds it a cm or two closer but swings for good where a move of his
        --               takes four frames to show in the deck; three tenths still settles there. Replayed on the
        --               clip's own board track at 60 frames a second the deck strays 6 to 10 cm at the drag's fastest
        --               and is back within a cm by the mount: the "on the board" line has what it really did);
        --   mountAt     the animation's own moment (its ThrowdownCompleted notify: 1.57 s in, 1.275 s in the other clip;
        --               the notify itself does nothing here, the game's throwdown flag is not set): the game is asked
        --               for the mount, the way the mod's own mount asks;
        --   on the board  the state "mount" takes over: it reads how he stands on it, and there is no first move
        --               where he stands right.
        -- The game's own Y stays refused the while (a press now would start its throw in the middle of this). Whatever
        -- does not come = the animation's flag cleared and the old way from there. The "notoggle" refresh above does
        -- nothing on foot (the native half only drops a toggle found while he is ON the board), so the mount asked
        -- for here is not touched by it -- and once he is on, it guards this drop-in as it does any other.
        if st == "throw" then
            local T = DI.th
            if not T then DI.state, DI.t0, DI.tapOver = "mount", now, true return end
            if cm == MODE_BAILING then letGo("the game bailed you") return end
            -- (v211) THE GAME'S REPLAY (mode 6) OPENED WHILE THE BOARD IS BEING SET DOWN: let go. Every held state lets go on
            -- a mode that is not riding or air, and "mount" only mounts on foot; this state went on -- in the stand-in
            -- world, mode 6 from half a second in: he was moved 80 more times, the animation's flag kept 81 more times
            -- and the mount asked for. The frame hook runs in the replay, and the skater there is played back, never
            -- driven (v149)
            if cm == 6 then letGo("the game's replay was opened while the board was being set down -- nothing more is done") return end
            local bs = type(HJN_BoardState) == "function" and tonumber(HJN_BoardState()) or -1
            local bmode = (bs >= 0) and ((bs >> 4) & 0xff) or -1
            local onb = q(function() return s0:IsOnBoard() end, false) == true
            local function oldWay(why, own)                  -- the old way from here; own = straight to the mod's own mount
                pcall(HJN_Set, "throwanim", 0)
                -- (v212) ...and a set-down ON THE COPING first lets go of what it holds: the skeleton's board bone (the
                -- native half's own watch would let it go 0.4 s on) and its mount's gate, the board's parts it was armed
                -- with, and the grounded hold the mount's asking raised
                if T.pinned then
                    T.pinned = nil
                    pcall(HJN_SetDown, "end") pcall(HJN_BoardParts)
                    if DI.ground and type(HJN_GroundHold) == "function" then pcall(HJN_GroundHold, 0) end
                    DI.ground = nil
                end
                log("drop-in: " .. why .. " -- today's way from here")
                DI.th, DI.sd, DI.tapOver = nil, nil, true        -- (tapOver: DI.t0 is not the press any more -- "mount" opens no second-tap window from it, the note in dropKey)
                DI.state, DI.t0, DI.rideAt, DI.tries, DI.tryAt = "mount", own and (now - 0.5) or now, nil, 0, nil
            end
            if bmode == 6 then oldWay("the game's own throwdown started all the same (the veto came too late)", false) return end
            if onb and not T.asked then oldWay("you are on the board already, and not by the set-down's own mount", false) return end
            if not onb and bmode ~= 5 then oldWay("the board left your hand (board mode " .. bmode .. ")", true) return end
            if T.failed then oldWay(T.failed, true) return end
            pcall(HJN_Set, "ygate", 0.3)
            -- (v212) THE SET-DOWN ON THE COPING (T.edge: the note in dropKey). What it does differently from build 211's:
            --   first tick   the native half is armed (HJN_SetDown "arm", v114): it lays the board's parts level in memory
            --                and says where the board will be -- level out over the edge (its middle about 28 cm past
            --                it), and in the stance (22 cm past it, 8 cm higher). He is stood so that the clip's own
            --                board, 35.8 cm ahead of him, comes down on the first of the two: about 8 cm behind the edge;
            --   the clip     as its board falls (from 45 cm over his floor to 9) the board leaves the clip's path for that
            --                place: the native half holds the skeleton's board bone there ("pin"; on foot the real board
            --                follows that bone). Down, its tail goes down over DropInSetPitchTime, and it STAYS;
            --   the walk     he is moved on by what the clip drags its own board, so that its board stays on the held one
            --                -- out past the edge with DropInSetOver, and held back where the game is seen to lower him;
            --   the mount    asked of the native half ("mount": the game's test at his feet is answered for, and the parts
            --                go back into the stance inside the game's own mount call). On the board with the parts put
            --                back = SET: straight to "wait", with no slide.
            -- NONE OF IT HAD RUN IN THE GAME WHEN IT WAS WRITTEN. The arming refused, or SWITCH = build 211's set-down;
            -- anything later that does not come = the old way; on the board without the parts put back = one teleport
            -- to the old spot and the slide out. The log says which, and a trace line five times a second says the rest.
            -- (v223) SWITCH ON THE COPING. "The double click Y to drop in switch is not connected, it still runs the old drop
            -- in." (14 Oct; 00:02:34 that night: armed on the coping, the tap, then build 211's 70 cm back and the slide.)
            -- Nothing of the coping is regular-only: both throwdown clips carry the board on ONE track (35.8 cm ahead, 16 to
            -- the left, its nose away from him: the switch run of 00:02:35 put clip 1's board 37 ahead and 15 left), so he
            -- stands and faces the drop as for a regular one and the board is held where it is held for one. The clip is
            -- the stance's own ("throwanim" 2: clip 1 for a goofy rider, AMXX_GRD_LH_Idle_To_RGS_SkateIdle at 1.3 -- its
            -- first foot steps on the tail, walks to the front bolts, the other comes onto the tail last, by the mount at
            -- 1.275 s). The mount is asked for the switch foot with flip flag 0 (HJN_SetDown "mount", 1): the game's own
            -- switch mount turns the CAPSULE half a turn (exe 0xfeaca0) -- he ends facing away from the drop, as a switch
            -- rider stands -- and its snap turns the board half a turn back because "is switch" is not the flip flag
            -- (SnapToGround, exe 0xfd9700), so the deck keeps its nose to the drop and the native half puts the parts in
            -- the stance from that heading. No yaw is handed over turned (the hop's way): he must face the drop on foot
            -- for the clip to set the board on the coping, and the game's own turn is the one wanted. Decided once, at
            -- the first tick that sees the tap; DropInSetSwitch 0 = build 222 (build 211's set-down, below)
            if T.edge and DI.sw and T.swEdge == nil then
                T.swEdge = (tonumber(S.DropInSetSwitch) or 1) ~= 0
                if T.swEdge then log("drop-in:    SWITCH ON THE COPING (DropInSetSwitch): you stand and face the drop as for a regular one; the switch stance's own animation sets the board down and the game's switch mount turns you half a turn -- you face away from the drop, the nose points at it, your other foot on the tail") end
            end
            if T.edge and DI.sw and not T.swEdge then
                if T.pinned then                              -- (review) the tap came after the arming: let go, and ease again from where he is to build 211's spot
                    T.pinned = nil
                    pcall(HJN_SetDown, "end") pcall(HJN_BoardParts)
                    local e1 = math.min(1, (now - T.t0) / 0.30)
                    local s1 = e1 * e1 * (3 - 2 * e1)
                    T.xp, T.yp, T.dyawp = T.xp or T.x0, T.yp or T.y0, T.dyawp or T.dyaw   -- (where he was pressed, for the SET-DOWN line)
                    T.x0, T.y0, T.yaw0, T.dyaw = T.x0 + (T.sx - T.x0) * s1, T.y0 + (T.sy - T.y0) * s1, T.yaw0 + T.dyaw * s1, T.dyaw * (1 - s1)
                    T.sx, T.sy, T.t0 = T.sx211 or T.sx, T.sy211 or T.sy, now   -- (the clip starts 0.24 s after the tap; the game's Y stays refused by the line above)
                end
                T.edge = nil
                if T.zp and L.dist >= 0 then T.z0, T.zp = T.zp, nil end   -- (pressed ON the ledge, lower than its edge: build 211's spot is not at the edge -- at the height he was pressed at, as build 211 moves him)
                log("drop-in:    SWITCH: DropInSetSwitch is 0 -- build 211's set-down, from its own spot")
            end
            if T.edge and not T.armed then                -- the first tick
                T.armed = true
                local parts = boardParts()
                local took = parts and tonumber(HJN_BoardParts(table.unpack(parts))) or 0
                local a = (took > 0) and tostring(HJN_SetDown("arm", DI.hang, DI.pitch, S.DropInTail, S.DropInKick, L.lip, L.ox, L.oy, L.x, L.y, L.top, S.DropInBack, S.DropInSetFeet or 1) or "") or ""
                local m0, m1, z0, z1, pu = a:match("^(%S+) (%S+) (%S+) (%S+) (%S+)")
                m0, m1, z0, z1 = tonumber(m0), tonumber(m1), tonumber(z0), tonumber(z1)
                if m0 and m1 and z0 and z1 then
                    T.pinned = true
                    local back = math.max(3, 35.8 - m0)        -- the clip sets the board 35.8 cm ahead and 16 to the left: he stands that far behind the level board's middle, his own middle never past the edge
                    T.sx211, T.sy211 = T.sx, T.sy              -- (build 211's spot: where a second tap sends him)
                    T.sx, T.sy, T.back = L.x - L.ox * back - L.oy * 16.0, L.y - L.oy * back + L.ox * 16.0, back
                    -- (review) NO RISE ON THE ACTOR unless asked (DropInSetRise): on foot the engine's walking sets the capsule
                    -- back onto its floor every tick, so a lift made by moving him holds only where it finds no floor
                    T.rise = ((S.DropInSetRise or 0) ~= 0) and math.max(0, math.min(20, z1 - z0)) or 0
                    T.pitch = tonumber(pu)
                    -- (what he will come up by at the mount, for the line below: the game sets the capsule 3.1 cm lower over a
                    -- deck than over the deck's own height, and on foot keeps it some 2.2 over its floor: 14.6 - 5.3 = 9)
                    local cap = q(function() return s0.CapsuleComponent end)
                    log(string.format("drop-in:    on the coping: the board will come down level with its middle %.0f cm PAST the edge and end tail-down %.0f cm past it, %.0f cm higher; you stand %.0f cm behind the edge (your capsule: radius %s, half height %s; the game's movement mode %s); at the mount you will come up about %.0f cm",
                        m0, m1, z1 - z0, back, tostring(cap and q(function() return cap:GetScaledCapsuleRadius() end, "?") or "?"), tostring(cap and q(function() return cap:GetScaledCapsuleHalfHeight() end, "?") or "?"),
                        tostring(q(function() return mv.MovementMode end, "?")), math.max(0, z1 - 5.3 - T.rise)))
                else
                    T.edge = nil
                    if T.zp and L.dist >= 0 then T.z0, T.zp = T.zp, nil end   -- (as at SWITCH above: build 211's spot, at the height he was pressed at)
                    pcall(HJN_BoardParts)
                    log("drop-in:    the set-down on the coping was not armed (ExpandedTricks.native.log says why) -- build 211's set-down: you stand DropInBack + 36 cm back")
                end
            end
            if T.edge and not T.started then pcall(HJN_SetDown, "pin", 0, 0) end   -- (the native half lets the bone go 0.4 s after the last asking: asked from the first tick on, with no weight yet)
            local e = now - T.t0
            local k = math.min(1, e / 0.30)
            local s = k * k * (3 - 2 * k)
            local px, py, pyaw = T.x0 + (T.sx - T.x0) * s, T.y0 + (T.sy - T.y0) * s, T.yaw0 + T.dyaw * s
            if not T.started and e >= 0.24 then
                local ty = tonumber(HJN_Set("throwanim", DI.sw and 2 or 1)) or 0
                if ty < 1 then oldWay("the native half would not start the animation", true) return end
                T.started, T.ts, T.type, T.mountAt = true, now, ty, now + ((ty == 2) and 1.57 or 1.275)
                log(string.format("drop-in: SET-DOWN -- the game's throw refused, its animation started by the mod (clip type %d%s); moved %.0f cm, turned %+.0f deg to stand %.0f cm from the edge",
                    ty, DI.sw and ", SWITCH" or "", math.sqrt((T.sx - (T.xp or T.x0)) ^ 2 + (T.sy - (T.yp or T.y0)) ^ 2), T.dyawp or T.dyaw, T.edge and (T.back or 0) or (S.DropInBack + 35.8)))   -- (v212) on the coping: where the arming stood him
            end
            if T.started then
                if (tonumber(HJN_Set("throwanim", -1)) or 0) < 1 and not T.asked then oldWay("the animation's flag was taken back", true) return end
                if onb then                                                         -- (asked for above, a frame or two ago)
                    pcall(HJN_Set, "throwanim", 0)
                    if T.edge then
                        -- (v212) ON THE COPING: the native half says how many of the board's parts it put back into the stance
                        -- inside the game's own mount (HJN_SetDown "state"; 0 = its hook on the board's SetOnBoardMode was
                        -- not reached, under 0 = it failed). Put back = SET, here and now: the board is where it will
                        -- wait, so there is no "mount" (how he stands), "set" (the parts taken) or "out" (the slide) --
                        -- and the stance is placed on this very frame: from the mount on the board's physics is on, and
                        -- a frame with nobody placing the parts would let it start to fall (review)
                        local put = tonumber(HJN_SetDown("state")) or 0
                        local loc2 = q(function() return s0:K2_GetActorLocation() end)
                        local z2 = loc2 and tonumber(q(function() return loc2.Z end))
                        T.pinned = nil                              -- (the native half let the bone go itself, inside the mount)
                        if put >= 1 then
                            log(string.format("drop-in:    on the board %.2f s after the animation began, ON THE COPING: no slide (%d parts put back in the stance inside the game's own mount); walked %.0f cm to it, your middle %+.0f cm from the edge by then (+ = past it)%s; the animation's own board was %+.1f cm out and %+.1f across from the held deck's middle (- = behind it); you are now %s cm higher than the mod had you on foot; the held deck was at most %.1f cm from its place; the game had you at most %.1f cm lower than the mod set you; the anim's Speed read %.0f at most (over 14 = the walk clip mixed in)",
                                now - T.ts, put, math.sqrt((T.wx or 0) ^ 2 + (T.wy or 0) ^ 2), T.alLast or 0, T.alHold and string.format(" (held %.0f cm past the edge)", T.alHold) or "",
                                T.ga or 0, T.gs or 0, (z2 and T.zSet) and string.format("%.1f", z2 - T.zSet) or "?", T.dev or 0, T.sink or 0, T.spd or 0))
                            if DI.sw then
                                -- (v223) SWITCH ON THE COPING: what the game's switch mount made of him and of the board. Planned: he
                                -- was turned half a turn by the game, to face away from the drop, and the deck's nose points at it
                                -- (the note at "SWITCH ON THE COPING" above). Said, not acted on: the first run shows it. Off by
                                -- half a turn = the game did not turn him, or its snap turned the board (the native log's
                                -- "inside the game's own mount" line: how far the snap turned the deck from the stance, ~30 = right)
                                local r2 = q(function() return s0:K2_GetActorRotation() end)
                                local y2 = r2 and tonumber(q(function() return r2.Yaw end))
                                local dy2 = tonumber((tostring(HJN_DeckWorld() or "")):match("^%S+ %S+ %S+ (%S+)"))
                                local sq2 = math.deg(math.atan(L.oy, L.ox))
                                local cOff = y2 and (((y2 - sq2 - 180) + 540) % 360 - 180)
                                local nOff = dy2 and (((dy2 - sq2) + 540) % 360 - 180)
                                log(string.format("drop-in:    SWITCH on the coping: you face %s off the way away from the drop, the deck's nose %s off the way down (0 wanted for both); the game says switch %s%s",
                                    cOff and string.format("%+.0f deg", cOff) or "?", nOff and string.format("%+.0f deg", nOff) or "?", tostring(q(function() return s0:IsSkatingSwitch() end, "?")),
                                    ((cOff and math.abs(cOff) > 45) or (nOff and math.abs(nOff) > 45)) and " -- NOT AS PLANNED: the game's switch mount did not turn you, or it turned the board (ExpandedTricks.native.log, 'inside the game's own mount': how far its snap turned the deck)" or ""))
                            end
                            DI.th, DI.sd, DI.tapOver = nil, true, true
                            DI.state, DI.t0, DI.k, DI.phi, DI.parts, DI.modeWas, DI.rideAt = "wait", now, 1, 0, put, cm, nil
                            DI.ground = (type(HJN_GroundHold) == "function" and tonumber(HJN_GroundHold(1)) == 1) or nil   -- (raised by the mount's asking; asked again as "set" does, so that what is logged is what holds)
                            DI.edgeAt = now
                            log(string.format("drop-in: SET -- %d board parts: the back wheels hung %.1f cm past the edge, the tail down on the ledge, the deck up %.0f deg. Stick UP = drop in, LB/RB = back, Y = off (set down ON THE COPING: no slide; the game %s)",
                                put, DI.hang, T.pitch or DI.pitch, DI.ground and "is told the board is grounded while it is held" or "keeps its own grounded check (the hold is off)"))
                            if S.DropInSounds ~= 0 then playSound(S.DropInSetSound, S.DropInSoundVolume) end
                            place(1, 0)
                            return
                        end
                        -- on the board, but the parts were not put back: the board lies as the game's own snap left it (level in
                        -- the air out over the edge, or nose-down on a bank), its physics on. One teleport to the old spot,
                        -- then "set" takes the parts and the slide out is build 211's
                        pcall(HJN_SetDown, "end") pcall(HJN_BoardParts)
                        if DI.ground and type(HJN_GroundHold) == "function" then pcall(HJN_GroundHold, 0) end
                        DI.ground = nil
                        log(string.format("drop-in:    on the board %.2f s after the animation began, but the board was NOT put back in the stance (the native half says %d; ExpandedTricks.native.log says why) -- the old spot and the slide out from here", now - T.ts, put))
                        local x, y, yaw, sk = L.x - L.ox * S.DropInBack, L.y - L.oy * S.DropInBack, math.deg(math.atan(L.oy, L.ox)) + ((DI.sw == true or q(function() return s0:IsSkatingSwitch() end, false) == true) and 180 or 0), s0
                        DI.th, DI.sd, DI.tapOver = nil, true, true
                        DI.state, DI.t0, DI.rideAt, DI.tries, DI.tryAt = "set", now, nil, 0, nil
                        NATIVE.gt(function()                          -- (outside the animation update, as the first move's teleport)
                            if DI.state ~= "set" or DI.L ~= L then return end   -- (the queue can run late: not once this drop-in is over)
                            local ok, res = pcall(function() return sk:K2_TeleportTo({ X = x, Y = y, Z = L.top + 90 }, { Pitch = 0.0, Yaw = yaw, Roll = 0.0 }) end)
                            log(string.format("drop-in: stood square to the edge, the board's middle %.0f cm back from it, heading %.0f -> %s", S.DropInBack, yaw, ok and tostring(res) or ("FAILED: " .. tostring(res))))
                            if not ok then letGo("the teleport failed") end
                        end)
                        return
                    end
                    log(string.format("drop-in:    on the board %.2f s after the animation began; walked %.0f cm onto it, the deck at most %.1f cm from where it came down; the anim's Speed read %.0f at most (over 14 = the walk clip mixed in)",
                        now - T.ts, math.sqrt((T.wx or 0) ^ 2 + (T.wy or 0) ^ 2), T.dev or 0, T.spd or 0))
                    DI.th, DI.sd, DI.tapOver = nil, true, true
                    DI.state, DI.t0, DI.rideAt, DI.tries, DI.tryAt = "mount", now, nil, 0, nil
                    return
                end
                if T.edge then
                    -- (v212) ON THE COPING: the board is HELD where the stance will have it, and he comes to it
                    local function sm(x) x = math.max(0, math.min(1, x)) return x * x * (3 - 2 * x) end
                    T.spd = math.max(T.spd or 0, tonumber(q(function() return inst.Speed end, 0)) or 0)
                    local r = tostring(HJN_SetDown("pin", T.w or 0, T.kS or 0) or "")
                    -- "" = the bone is not held any more (the native half's watch, a fault). Not so once the mount has been asked
                    -- and made: the native half lets go itself inside the game's mount, and he is seen on the board next
                    if r == "" and not (T.asked and (tonumber(HJN_SetDown("state")) or 0) ~= 0) then
                        oldWay("the native half let the board bone go", true)
                        return
                    end
                    local cx, cy, ch, qx, qy, qz, off = r:match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%S+)")
                    cx, cy, ch, qx, qy, qz, off = tonumber(cx), tonumber(cy), tonumber(ch), tonumber(qx), tonumber(qy), tonumber(qz), tonumber(off)
                    if cx and cy and ch and qx and qy then
                        -- the board leaves the clip's path for the held place as it falls: from 45 cm over his floor to 9 (0.27 to 0.54 s in this clip); never back
                        T.w = math.max(T.w or 0, sm((45 - ch) / 36))
                        if not T.landed and now - T.ts > 0.35 and ch < 9 then
                            T.landed, T.landAt, T.wx, T.wy = true, now, 0, 0
                            T.alLast = (px - L.x) * L.ox + (py - L.y) * L.oy   -- (his middle from the edge as the walk begins, behind it: what the game makes of his height is counted from this frame on)
                            log(string.format("drop-in:    the board came down %.2f s into the animation, HELD on the coping: its middle %.0f cm past the edge, %.0f cm off the line; the real deck %.1f cm from where it is held; the animation's own board %.0f cm from it",
                                now - T.ts, (qx - L.x) * L.ox + (qy - L.y) * L.oy, (qx - L.x) * -L.oy + (qy - L.y) * L.ox, off or -1, math.sqrt((qx - cx) ^ 2 + (qy - cy) ^ 2)))
                        end
                        if T.landed then
                            T.kS = sm((now - T.landAt - 0.04) / math.max(0.02, S.DropInSetPitchTime or 0.22))   -- the tail goes down as his back foot comes onto it (0.67 s in)
                            if T.kS >= 1 and not T.tailSaid then
                                T.tailSaid = true
                                log(string.format("drop-in:    tail down %.2f s into the animation: the deck %s, its middle %.0f cm past the edge; the real deck %.1f cm from where it is held", now - T.ts, DI.pitchNow(), (qx - L.x) * L.ox + (qy - L.y) * L.oy, off or -1))
                            end
                            T.ex, T.ey = qx - cx, qy - cy                  -- he is walked on by what the clip drags its own board: its board kept on the held one
                            T.ga, T.gs = -(T.ex * L.ox + T.ey * L.oy), -(T.ey * L.ox - T.ex * L.oy)   -- (for the log: the clip's board from the held one, out along the way over the edge and across it)
                            local ex, ey = 0.3 * T.ex, 0.3 * T.ey          -- three tenths of the gap a frame, as build 211's walk
                            local n = math.sqrt(ex * ex + ey * ey)
                            if n > 3 then ex, ey = ex * 3 / n, ey * 3 / n end   -- 3 cm a frame at most
                            T.wx, T.wy = T.wx + ex, T.wy + ey
                            local wl = math.sqrt(T.wx ^ 2 + T.wy ^ 2)
                            if wl > 60 then T.wx, T.wy = T.wx * 60 / wl, T.wy * 60 / wl end
                            do  -- (review) HIS MIDDLE OUT PAST THE EDGE, ON FOOT. By the clip's own board track the walk takes his middle
                                -- past the edge 0.87 s in and 22 cm past it by 1.2 s. On foot he is in the engine's walking, which
                                -- sets the capsule onto the floor it finds every tick: one whose round bottom hangs on an edge is
                                -- set LOWER (a radius of 34: 1.5 cm at 10 cm past it, 8 at 22), further out it falls. Nobody has
                                -- read the capsule's radius, so it is measured: how far under the height the mod moves him at
                                -- the game has him now, counted from what that read while he still stood well on the ledge (a
                                -- top that is not level is not the edge). Over 1.5 cm = he is held 3 cm short of there until the
                                -- mount is near (first seen in those last 0.15 s nothing is held: the most he was lowered is
                                -- kept for the log); his feet reach the board from there (DropInSetFeet), the last 0.15 s close
                                -- what they can and the game's mount takes the rest. DropInSetOver 0 = his middle is not taken
                                -- past the edge at all. Against T.z0, not the last move's own height: a lift of DropInSetRise
                                -- is not in it (on a floor the game takes that lift back every tick -- that is not the edge)
                                local lz = q(function() return s0:K2_GetActorLocation() end)
                                local zn = lz and tonumber(q(function() return lz.Z end))
                                if zn then
                                    local sink = T.z0 - zn
                                    if (T.alLast or 0) <= -4 then T.sink0 = sink end
                                    sink = sink - (T.sink0 or 0)
                                    T.sinkNow = sink
                                    if sink > (T.sink or 0) then T.sink = sink end
                                    if sink > 1.5 and not T.alHold and (T.alLast or -99) > -2 and now < T.mountAt - 0.15 then
                                        T.alHold = math.max(-2, T.alLast - 3)
                                        log(string.format("drop-in:    %.2f s in, your middle %.0f cm past the edge: the game had you %.1f cm lower than the mod set you (the capsule hangs on the edge) -- held %.0f cm past the edge until the mount is near", now - T.ts, T.alLast, sink, T.alHold))
                                    end
                                end
                                local al = (px + T.wx - L.x) * L.ox + (py + T.wy - L.y) * L.oy      -- his middle, cm past the edge
                                local lim = T.alHold
                                -- (v216) NOT PAST THE EDGE ON FOOT AT ALL (DropInSetFly). "The drop-ins are super stuttery as well.
                                -- Like when you hit the button to drop in and he slides into position, it's very choppy." (11 Oct,
                                -- six set-downs over real drops, 38 to 54 cm.) The log of each: his middle 5 to 15 cm past the edge
                                -- before the engine was SEEN to set him lower (1.5 to 4.3 cm, every frame, against the mod's own
                                -- move back up: the stutter), then held; and in the last 0.15 s let go to the mount's place, 24 cm
                                -- out, where the engine dropped him 14 cm before the game's mount raised him 22. Now his middle
                                -- stays 2 cm short of the edge from the start -- nothing to see first -- and the last 0.15 s are
                                -- flown (the move below)
                                if not lim and (tonumber(S.DropInSetFly) or 1) ~= 0 then lim = -2 end
                                if (S.DropInSetOver or 1) == 0 then lim = math.min(lim or -1, -1) end
                                if lim and now < T.mountAt - 0.15 and al > lim then
                                    T.wx, T.wy, al = T.wx - L.ox * (al - lim), T.wy - L.oy * (al - lim), lim
                                end
                                T.alLast = al
                            end
                            px, py = px + T.wx, py + T.wy
                            if T.kS >= 1 and off and off >= 0 then T.dev = math.max(T.dev or 0, off) end
                            -- the first rendition: its numbers five times a second, for whoever reads the log after the test
                            if now >= (T.trAt or 0) then
                                T.trAt = now + 0.2
                                log(string.format("drop-in:    +%.2f s: the board bone held %.0f%%, the tail %.0f%% down; your middle %+.0f cm from the edge (+ = past it), %.1f cm lower than the mod set you; the real deck %.1f cm from where it is held; the animation's own board %+.1f cm out and %+.1f across from it (- = behind it)",
                                    now - T.ts, T.w * 100, T.kS * 100, T.alLast or 0, T.sinkNow or 0, off or -1, T.ga, T.gs))
                            end
                        end
                        T.zr = (T.rise or 0) * sm((now - (T.mountAt - 0.45)) / 0.40)   -- (DropInSetRise only) raised toward the board's height before the mount
                    elseif T.landed then
                        px, py = px + T.wx, py + T.wy                      -- (no pose to read on this frame: he stays where the walk has him)
                    end
                    if not T.landed and now - T.ts > 0.9 then
                        oldWay(string.format("the board did not come down in 0.9 s (the animation did not play: its board bone reads %s cm over your floor)", ch and string.format("%.0f", ch) or "?"), true)
                        return
                    end
                else
                    local dx, dy, dz = tostring(HJN_DeckWorld() or ""):match("^(%S+) (%S+) (%S+)")
                    dx, dy, dz = tonumber(dx), tonumber(dy), tonumber(dz)
                    T.spd = math.max(T.spd or 0, tonumber(q(function() return inst.Speed end, 0)) or 0)
                    if not T.landed and dx and dy and dz and now - T.ts > 0.35 and dz - L.top < 9 then
                        T.landed, T.lx, T.ly, T.wx, T.wy = true, dx, dy, 0, 0
                        local al = (dx - L.x) * L.ox + (dy - L.y) * L.oy                 -- along 'out': negative = behind the edge
                        if al > -26 then T.lx, T.ly = dx - L.ox * (al + 26), dy - L.oy * (al + 26) end   -- all four wheels on the ledge for the mount
                        log(string.format("drop-in:    the board came down %.2f s into the animation, its middle %.0f cm back from the edge, %.0f cm off the line",
                            now - T.ts, -al, (dx - L.x) * -L.oy + (dy - L.y) * L.ox))
                    end
                    if T.landed and dx and dy then                                      -- he is walked onto it: the deck stays where it came down
                        local ex, ey = 0.3 * (T.lx - dx), 0.3 * (T.ly - dy)
                        T.dev = math.max(T.dev or 0, math.sqrt((T.lx - dx) ^ 2 + (T.ly - dy) ^ 2))
                        local n = math.sqrt(ex * ex + ey * ey)
                        if n > 3 then ex, ey = ex * 3 / n, ey * 3 / n end                -- 3 cm a frame at most
                        T.wx, T.wy = T.wx + ex, T.wy + ey
                        local w = math.sqrt(T.wx ^ 2 + T.wy ^ 2)
                        if w > 60 then T.wx, T.wy = T.wx * 60 / w, T.wy * 60 / w end     -- (the clip drags it 40 cm)
                        px, py = px + T.wx, py + T.wy
                    end
                    if not T.landed and now - T.ts > 0.9 then
                        oldWay(string.format("the board did not come down in 0.9 s (the animation did not play: the deck reads %s cm over the ledge)", dz and string.format("%.0f", dz - L.top) or "?"), true)
                        return
                    end
                end
                if not T.asked and now >= T.mountAt then
                    T.asked = true
                    local sk, sw = s0, DI.sw
                    NATIVE.gt(function()
                        if DI.th ~= T then return end                 -- (the queue can run late, the note at the move below: no mount is asked for once the set-down is over -- a bail in between, the old way)
                        local okm
                        if T.edge then
                            -- (v212) ON THE COPING: asked of the native half's set-down -- what HJN_BoardMount writes, the grounded
                            -- hold raised before the game looks, and for 0.6 s the game's test at his feet answered for and
                            -- the parts put back inside its mount. The body's own touches cannot bail him in that moment
                            if T.fly then q(function() mv:SetMovementMode(1, 0) end) T.fly = nil DI.flyT = nil end   -- (v216) walking again for the game's own mount, in the same slice: the engine has no tick to drop him in
                            pcall(HJN_Set, "nobail", 0.4)
                            okm = tonumber(HJN_SetDown("mount", sw and 1 or 0)) == 1
                            if okm then DI.ground = true end
                            log(string.format("drop-in:    at the mount's asking: the game's movement mode %s, falling %s; your middle %+.0f cm from the edge (+ = past it), %.1f cm lower than the mod set you; the animation's own board %+.1f cm out and %+.1f across from the held deck's middle (- = behind it); raised %.1f cm",
                                tostring(q(function() return mv.MovementMode end, "?")), tostring(q(function() return mv:IsFalling() end, "?")), T.alLast or 0, T.sinkNow or 0, T.ga or 0, T.gs or 0, T.zr or 0)
                                .. (sw and "; SWITCH: foot position 4, flip flag 0 -- the game turns you half a turn itself and its snap keeps the deck's nose to the drop" or ""))   -- (v223)
                        else
                            okm = tonumber(HJN_BoardMount(sw and 1 or 0, 0)) == 1
                        end
                        local okp = okm and pcall(function() sk:SetPendingApplyToggleOnBoard() end)
                        log("drop-in:    the mount at the animation's own moment: " .. (okp and "asked of the game" or (okm and "call FAILED" or "refused by the native half")))
                        if not okp then T.failed = "the mount could not be asked for at the animation's own moment" end
                    end)
                end
                if T.asked and now - T.mountAt > 0.8 then oldWay("not on the board 0.8 s after the mount was asked", true) return end
            end
            local sk, z = s0, T.z0 + (T.zr or 0)             -- (v212) + the rise, with DropInSetRise only
            T.zSet = z                                       -- (v212) the height of the mod's last move on foot: the "on the board ... ON THE COPING" line says how far the game's mount raised him from it
            -- (v211) ...AND NEVER ONCE HE IS ON THE BOARD OR THE SET-DOWN IS OVER. The move is handed to the game thread's
            -- queue on every tick, and the queue can be run later than it was filled: when UE4SS stops running it the
            -- frame hook does (NATIVE.gtPump, v185, seen 5 Oct), a twentieth of a second on. The move of the last tick on
            -- foot then came AFTER the game's mount: the capsule set to the on-foot height and yaw with him on the board,
            -- a jolt of a few cm -- and in SWITCH the half turn of the game's mount undone, which "mount" then made
            -- again over 0.4 s with the board under him (the review's run: "moved on the board by the on-foot call")
            NATIVE.gt(function()                              -- outside the animation update, as "align" does
                if DI.th ~= T or q(function() return sk:IsOnBoard() end, false) == true then return end
                -- (v216) THE LAST 0.15 s OVER THE EDGE, FLOWN (DropInSetFly, the note at "NOT PAST THE EDGE ON FOOT"): the
                -- engine's walking sets a capsule past an edge lower or drops it, every tick; its flying mode leaves him
                -- where the mod moves him, at his own height. Walking again in the slice that asks the game's mount
                if T.edge and T.started and not T.asked and not T.fly and T.mountAt and now >= T.mountAt - 0.15 and (tonumber(S.DropInSetFly) or 1) ~= 0
                    and q(function() return mv.MovementMode end, 0) == 1 then
                    if pcall(function() mv:SetMovementMode(5, 0) end) then
                        T.fly, DI.flyT = true, T
                        log(string.format("drop-in:    %.2f s in: over the edge in the engine's flying mode for the last steps to the mount (your middle was %+.0f cm from the edge; at your own height)", now - T.ts, T.alLast or 0))
                    end
                end
                pcall(function() sk:K2_SetActorLocationAndRotation({ X = px, Y = py, Z = z }, { Pitch = 0, Yaw = pyaw, Roll = 0 }, false, {}, true) end)
                pcall(function() mv.Velocity = { X = 0, Y = 0, Z = 0 } end)
            end)
            sticksCentred()
            return
        end
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
                    -- (v211) "AFTER A SET-DOWN" BELOW = WITH NO MOUNT OF THE MOD'S OWN SINCE (sdm). Should the game step him off
                    -- after one (the re-mount, further down) or the mod have to mount him itself, that mount is the old
                    -- way's -- he is set over the board from 95 cm up -- and it gets the old way's 0.3 s to settle and its
                    -- 3 cm and 2 deg (DI.sd alone gave it neither: the board's parts were taken 0.18 s after such a mount
                    -- instead of 0.45). DI.sd itself stays: the slide out keeps DropInSetOutTime. And with DropInAlignTime 0
                    -- (no eased first move: one teleport) a set-down that stands right is not teleported either -- that
                    -- pop is what it is to spare him; one that stands wrong gets the one teleport, as before
                    local sdm = DI.sd and (DI.tries or 0) == 0
                    if (T > 0.03 or sdm) and x0 and y0 and z0 and yaw0 then
                        -- (v211) ...AND NO MOVE WHERE THERE IS NOTHING TO MOVE. 9 Oct: every one of the mod's own mounts (12 of that
                        -- night's 26 set-ups) stood him on the spot itself, and each then spent the whole DropInAlignTime on
                        -- "stood square to the edge over 0.40 s (turned +0 deg, moved 0 cm)". Under 3 cm and 2 deg there is no
                        -- first move. After a SET-DOWN (sdm) he stands where the board came down: up to 12 cm and 6 deg are
                        -- left as they are -- the slide out takes the board from wherever it stands, and a first move there
                        -- would be the glide the set-down is to spare him. Further off than that he is squared as before
                        -- (a set-down in SWITCH too, should the game not have turned him round at its mount).
                        local far, turn = math.sqrt((x - x0) ^ 2 + (y - y0) ^ 2), ((yaw - yaw0 + 540) % 360) - 180
                        if far < (sdm and 12 or 3) and math.abs(turn) < (sdm and 6 or 2) then
                            DI.state, DI.t0 = "set", sdm and (now - 0.3) or now   -- ("set" waits 0.3 s for a teleport to settle; a set-down made none)
                            log(string.format("drop-in: on the board %.0f cm from the spot and %+.0f deg off square to the edge%s -- no first move%s", far, turn,
                                sw and " (riding SWITCH: you face away from the drop, the nose points at it)" or "",
                                sdm and " after the set-down: the board is taken where it stands" or ""))
                            return
                        end
                        if T > 0.03 then                           -- (v211) (with DropInAlignTime 0 a set-down that stands wrong goes on to the one teleport below)
                            DI.state, DI.t0 = "align", now
                            DI.al = { x0 = x0, y0 = y0, z0 = z0, yaw0 = yaw0, x = x, y = y, dyaw = ((yaw - yaw0 + 540) % 360) - 180, yaw = yaw, T = T, sw = sw }
                            return
                        end
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
            do  -- (v220) the arms: out with the way down (DI.armsRise), held, and down over 0.7 s once he is down: landed
                -- from the air, at the bottom (95 % of the drop, or no further down for 0.2 s past the peak), or 1.2 s on
                DI.armsTip = 1
                local w, f, _, cc = DI.armsRise()
                if cm == MODE_AIR then DI.armsAir = true end
                if not DI.armsAt then
                    if f > (DI.armsFmax or 0) + 0.01 then DI.armsFmax, DI.armsFt = f, now end
                    local peak = math.max(0.1, (tonumber(S.DropInArmsPeak) or 50) / 100)
                    if (DI.armsAir and cm ~= MODE_AIR) or f >= 0.95 or (f >= math.min(0.9, peak) and now - (DI.armsFt or now) > 0.2) or now - DI.t0 >= 1.2 then
                        DI.armsAt, DI.armsTop, DI.crouchTop = now, w, cc
                    end
                end
                if DI.armsAt then local fade = 1 - DI.sm01((now - DI.armsAt) / 0.7) w, cc = (DI.armsTop or 0) * fade, (DI.crouchTop or 0) * fade end
                if w > 0.01 then DI.arms(w) end
                if cc > 0.2 then DI.crouch(cc) end                -- (v221) the crouch: up again with the arms
                if not DI.armsAt or now - DI.armsAt < 0.7 then DI.twist() end
            end
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
                    local boost = S.DropInVertBoost * (DI.vk or 1)                    -- (v210) less on a low wall
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
                    if took > 0 then n = tonumber(HJN_BoardKick(vx + dx * boost, vy + dy * boost, vz + dz * boost, 0, L.ox, L.oy)) or 0 end
                    pcall(HJN_BoardParts)
                    log(string.format("drop-in:    on the wall %.2f s after the let-go at %.0f cm/s -> boosted %.0f cm/s %s (%d parts)", now - DI.t0, sp, boost, how, n))
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
            DI.armsOff()                                    -- (v218)
            DI.state = nil
            return
        end
        -- from here the board is held, every frame -- riding or, as the game sees it once the wheels hang free, in the air
        -- (v98 let go the moment the game said "air": the pivot never ran and you came off the ledge flat)
        -- (v212) ...NOR IS A MODE THAT READS "ON FOOT" A STEP-OFF IN THE HALF SECOND AFTER A MOUNT ON THE COPING, WHILE THE
        -- GAME SAYS HE IS ON THE BOARD. Build 211 came here through "mount" and "set", which waited for riding; a
        -- set-down on the coping is in "wait" from the frame of the mount, with the board hung out over the drop -- to
        -- give it back there (the re-mount below, or the let-go) on a mode that has not caught up would drop it
        if cm ~= MODE_RIDING and cm ~= MODE_AIR and cm ~= MODE_TO_BOARD and cm ~= -1
            and not (cm == 0 and DI.edgeAt and now - DI.edgeAt < 0.5 and q(function() return s0:IsOnBoard() end, false) == true) then
            -- (v210) ...AND SHOULD ONE GET THROUGH ALL THE SAME: off the board with no Y pressed in the last second, while
            -- the board was being set out or stood ready = the game stepped you off, you did not. The board is given back
            -- and the drop-in goes round again from its first step (the mod's own mount puts you on), twice at most.
            local yAgo = now - (DI.yPress or -1e9)
            if cm == 0 and yAgo > 1.0 and (DI.remounts or 0) < 2 and (st == "out" or st == "wait") then
                DI.remounts = (DI.remounts or 0) + 1
                if type(HJN_BoardParts) == "function" then pcall(HJN_BoardParts) end
                if DI.ground and type(HJN_GroundHold) == "function" then pcall(HJN_GroundHold, 0) end
                DI.ground, DI.held = nil, nil
                log(string.format("drop-in: the game stepped you off the board (%s, no Y pressed%s; %s board toggles dropped by the native half so far) -- put back on, try %d of 2",
                    (st == "out") and "while the board was set out" or "while it stood ready", (yAgo < 60) and string.format(" in the last %.1f s", yAgo) or "",
                    tostring(type(HJN_NoToggle) == "function" and HJN_NoToggle() or "?"), DI.remounts))
                DI.state, DI.t0, DI.rideAt, DI.tries, DI.tryAt, DI.hang, DI.pitch, DI.pulled = "mount", now, nil, 0, nil, S.DropInHang, S.DropInPitch, false
                return
            end
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
        -- (v212, review) ...BUT NOT IN THE HALF SECOND AFTER A MOUNT ON THE COPING (DI.edgeAt): for a frame or more after a
        -- mount the board is in its own mode 7 and the skater in ToSkateboarding, which reads here as "air" by the
        -- anim's wheel flag (modeNow) -- and build 211 never was in "wait" that early
        if (st == "out" or st == "wait") and cm == MODE_AIR and (DI.k or 0) >= 1 and not (DI.edgeAt and now - DI.edgeAt < 0.5) then
            DI.hang = math.max(-1, DI.hang - 0.25)
            if not DI.pulled then DI.pulled = true log("drop-in:    the game took the held board for airborne -- drawing it back until it rides again") end
        end
        if st == "out" then
            local k, e = eased(DI.sd and S.DropInSetOutTime or S.DropInSetTime)   -- (v211) after a set-down the slide out is the one move left: DropInSetOutTime
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
                local meet, pu, slope, what = HJN_BoardMeet(DI.hang, DI.pitch, S.DropInTail, S.DropInKick, L.lip, L.ox, L.oy, L.x, L.y, L.top, S.DropInMaxSlope + DI.pitch)
                meet, DI.pitch, slope, what = tonumber(meet) or -1, tonumber(pu) or DI.pitch, tonumber(slope) or 0, tonumber(what) or 0
                -- (v102) the floor below a plain ledge is "met" too, 40-odd degrees down: only ground steeper than
                -- DropInRampSlope is a ramp to pivot onto (v101 planted the nose into the floor below a 40 cm ledge)
                local ramp = meet >= 1 and slope >= S.DropInRampSlope
                -- (v139) THE WHEELS MUST MEET THE WALL. As hung (the back wheels 4 cm past the edge) the front wheels' arc passed
                -- a vert wall 4 cm behind them and met nothing (v137's "vert" then let the board fall free to the wall: a
                -- hiccup as the game went to air and back). Now the way down is traced again with the board hung further and
                -- further out, 6 cm at a time, until the wheels DO meet ground steep enough; the board slides out to that
                -- hang as it tips and is let go the moment the wheels touch -- on any ledge, not only a vert
                DI.hangTo, DI.hang0, DI.noseOn = nil, DI.hang, nil
                -- (v217) A PLAIN LEDGE IS A STRAIGHT DROP AGAIN. "When I drop in off a ledge, not necessarily a quarter pipe, it
                -- just bails the character or it tries to drop him in down the face of it if it's tall enough, which is not
                -- good. It used to shoot him out straight." (11 Oct.) The native log of that session, four kinds of edge:
                --   a ledge of 51 cm over flat ground: as hung the nose meets the floor, flat -- no ramp; but the look further
                --     out (below) went on, and hung 40 cm out the nose met the same floor where its normal read 22 deg:
                --     "a ramp", tipped 90 deg, the nose planted, a bail (twice);
                --   a ledge of 54 cm with another drop beyond it: the same, and further out the nose met the RISER of the
                --     next step, 90 deg steep: "a ramp", tipped 108 deg;
                --   plain walls of 140 and 240 cm (the same flat ground just past the edge and further out): nothing met,
                --     and deep enough for "a VERT wall" -- tipped 75 deg and let go slowly down the face: a bail, a dead stop.
                -- (The set-down on the coping stands the board 30 deg up, so the trace swings 15 deg further than it did.)
                -- So: the look further out is only for a board whose front wheels met NOTHING as hung (what it was made
                -- for: a wall right under the coping, behind their arc) -- a floor met flat under the ledge is the answer;
                -- and where the ledge scan has the same level ground just past the edge and further out (within 8 cm, under
                -- 8 deg) there is no ramp to find and no vert wall: a ramp's surface falls away from its coping, a vert
                -- ramp's too (159 and 214 cm at Cakovice). DropInPlain 0 = as build 216.
                local plain = (tonumber(S.DropInPlain) or 1) ~= 0 and (L.slope or 0) < 8 and math.abs((L.far or 0) - (L.near or 0)) < 8
                local floorMet = (tonumber(S.DropInPlain) or 1) ~= 0 and meet >= 1 and not ramp
                if plain and ramp then ramp = false end
                -- (v224) THE NOSE MET THE FACE FIRST. Two drop-ins of 14 Oct went wrong the moment the board was let go, on a
                -- 64 deg face under a 52 cm lip (FDR's coping and bunker wall): one was pushed 1.2 m out of the ramp in a
                -- frame and stepped off, the other bounced out into the air at a fifth of the speed. They were the only two of
                -- the day where the NOSE met the face before the front wheels (native v122 says which): let go there, the
                -- wheels were off the ramp and the deck itself against it. So the board is hung further out, 6 cm at a
                -- time as for a vert wall, until its front wheels meet first; failing that it is let go along the face
                -- (the slope met) instead of along the board, so it is not driven into the ramp
                if ramp and what == 2 then
                    for _, dh in ipairs({ 6, 12, 18, 24, 30, 36 }) do
                        local h = (DI.hang or 4) + dh
                        local m2, _, sl2, w2 = HJN_BoardMeet(h, DI.pitch, S.DropInTail, S.DropInKick, L.lip, L.ox, L.oy, L.x, L.y, L.top, S.DropInMaxSlope + DI.pitch)
                        m2, sl2, w2 = tonumber(m2) or -1, tonumber(sl2) or 0, tonumber(w2) or 0
                        if m2 >= 1 and sl2 >= S.DropInRampSlope and w2 == 1 then
                            log(string.format("drop-in: the nose would meet the face before the front wheels (%.0f deg down the way); hung %.0f cm past the edge the wheels meet it first, %.0f deg down (%.0f deg steep there): the board slides out to that as it tips", meet, h, m2, sl2))
                            meet, slope, DI.hangTo = m2, sl2, h
                            break
                        end
                    end
                    if not DI.hangTo then
                        DI.noseOn = slope
                        log(string.format("drop-in: the nose meets the face before the front wheels from every hang tried: it will be let go along the face (%.0f deg) instead of along the board", slope))
                    end
                end
                if not ramp and not plain and not floorMet then
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
                local vert = (not ramp) and (not plain) and (not floorMet) and (L.near or 0) >= S.DropInVertDrop and (L.far or 0) >= 90   -- (v217: not a plain wall, and not where the hung board's nose meets a flat floor)
                DI.state, DI.t0, DI.ramp, DI.vert = "in", now, ramp, vert
                DI.armsRec(240, "drop-in GO")                -- (v218)
                do  -- (v220) the arms: the drop, and where he stands as it begins
                    DI.armsH = math.max(L.near or 0, L.far or 0)
                    -- (v221) the ledge scan's second look lands part way down a quarter's transition: the way down is
                    -- traced as well (native v119), and the deeper of the two is the drop
                    DI.armsDepth, DI.armsDepthAt, DI.armsTip = nil, nil, 0
                    if (tonumber(NATIVE.v) or 0) >= 119 and type(HJN_DropDepth) == "function" then
                        local okd, dd, at = pcall(HJN_DropDepth, L.x, L.y, L.top, L.ox, L.oy)
                        dd, at = okd and tonumber(dd) or -1, okd and tonumber(at) or 0
                        if dd and dd > 0 then DI.armsDepth, DI.armsDepthAt = dd, at if dd > DI.armsH then DI.armsH = dd end end
                    end
                    DI.armsZ0 = q(function() return s0:K2_GetActorLocation().Z end, nil)
                    DI.armsFrac, DI.armsFmax, DI.armsFt, DI.armsAt, DI.armsTop, DI.armsAir = 0, 0, now, nil, nil, nil
                    if (tonumber(S.DropInArms) or 0) > 0 or (tonumber(S.DropInCrouch) or 0) > 0 then
                        local full = tonumber(S.DropInArmsFull) or 200
                        log(string.format("drop-in:    arms: a drop of %.0f cm -> %.0f %% of DropInArms' %g deg (all of it at %g cm and more), fully out %g %% of the way down",
                            DI.armsH, 100 * math.max(0, math.min(1, math.max(10, DI.armsH) / math.max(10, full))), tonumber(S.DropInArms) or 0, full, tonumber(S.DropInArmsPeak) or 50)
                            .. string.format("; the crouch the same share of %g cm, lowest %g %% of the way down; the drop: the ledge scan %.0f cm, the way down traced %s",
                                tonumber(S.DropInCrouch) or 0, tonumber(S.DropInCrouchPeak) or 25, math.max(L.near or 0, L.far or 0),
                                DI.armsDepth and string.format("%.0f cm (its bottom %.0f cm out)", DI.armsDepth, DI.armsDepthAt or 0) or "-- (not traced: native v119 needed, or nothing found)"))
                    end
                end
                -- (v210) A LOW WALL GETS LESS. "A ton of issues trying to drop in on what should have been an easy vert ramp"
                -- (9 Oct 22:32-22:35, Cakovice's radius_gate_2: 159 cm down just past the edge, 214 further out). Let go at
                -- 1056 cm/s and boosted to 1194 on the wall -- the speeds set for a full vert -- he came off a 2 m quarter at
                -- 37 km/h and was off the board within four seconds, four drops of four. The two speeds are now what a wall
                -- DropInVertRef cm tall gets; a lower one gets less, as the square root of its height (what a fall from it
                -- gives), never under half.
                DI.vk = 1
                if vert and (S.DropInVertRef or 0) > 0 then
                    local h = math.max(L.near or 0, L.far or 0)
                    DI.vk = math.max(0.5, math.min(1, math.sqrt(h / S.DropInVertRef)))
                    if DI.vk < 0.995 then
                        log(string.format("drop-in:    a wall of %.0f cm: its two speeds x%.2f, %.0f and %.0f cm/s (DropInVertRef: they are set for a wall of %.0f cm)",
                            h, DI.vk, S.DropInVertSpeed * DI.vk, S.DropInVertBoost * DI.vk, S.DropInVertRef))
                    end
                end
                DI.down = ramp and meet or (DI.pitch + (vert and S.DropInVertTilt or S.DropInTilt))
                log(string.format("drop-in: GO (stick %.2f) -- %s", math.max(ly or 0, ry or 0),
                    ramp and string.format("the board tips %.0f deg nose-down about its back wheels, to %.0f deg below level, where its front wheels meet the ramp (%.0f deg steep there)", DI.down, DI.down - DI.pitch, slope)
                          or (vert and string.format("a VERT wall (%.0f cm down just past the edge, %.0f further out, nothing for the wheels to pivot onto): it tips to %.0f deg nose-down, goes slowly and keeps tipping", L.near or 0, L.far or 0, DI.down - DI.pitch))
                          or string.format("a straight drop%s%s: it tips to %.0f deg nose-down and goes",
                                plain and string.format(" off a plain ledge (the same level ground %.0f cm down just past the edge and further out)", L.near or 0) or "",
                                (meet >= 1) and string.format(" (the ground the wheels would meet is only %.0f deg steep)", slope) or "", DI.down - DI.pitch)))
            end
            return
        end
        if st == "back" then
            local k, e = eased(DI.sd and S.DropInSetOutTime or S.DropInSetTime)   -- (v211)
            DI.k = 1 - e
            if place(1 - e, 0) < 1 then letGo("the native half let the board go") return end
            if k >= 1 then letGo("back on the ledge -- the board is yours") end
            return
        end
        if st == "in" then
            local k = math.min(1, (now - DI.t0) / math.max(0.05, DI.ramp and S.DropInTime or 0.6 * S.DropInTime))
            DI.phi = DI.down * k * k                          -- (it starts slowly and falls in)
            -- (v219) THE ARMS COME UP WITH THE DROP-IN ITSELF. "His arms go up when he is posed on the board; it should only be
            -- when the actual drop-in motion starts." (13 Oct.) Build 218 raised them from the moment he stood on the board at
            -- the edge; now nothing is asked of them until GO, and from its first frame they come up (the native half eases
            -- them in over about a third of a second) and are held through the tip-in and the ride's first moments
            do  -- (v220) the tip-in: as far as the way down so far says (the native half adds what the board's tipping does); (v221) the crouch too, half of it with the tip itself, and the game's shoulder twist held off
                DI.armsTip = k
                local w, _, _, cc = DI.armsRise()
                if w > 0.01 then DI.arms(w) end
                if cc > 0.2 then DI.crouch(cc) end
                DI.twist()
            end
            -- about the hung back axle, the game's board controller turned with the board (v99 let go of a board 56 deg
            -- down whose controller was still level -- the game had it level again 0.13 s later and bailed you)
            if DI.hangTo then DI.hang = DI.hang0 + (DI.hangTo - DI.hang0) * math.min(1, k * 2) end   -- (v139) out to the hang the wheels meet from, over the first half of the tip
            if place(1, DI.phi, true) < 1 then letGo("the native half let the board go") return end
            if k < 1 then return end
            -- let go: the game's own grounded check back, then a little speed the way the board points; over a straight drop still tipping forward
            if DI.ground and not DI.vert then DI.ground = nil pcall(HJN_GroundHold, 0) end   -- (v138) a vert keeps the hold a moment: the wheels fall free to the wall
            DI.holdUntil = DI.vert and (now + 0.25) or nil
            if S.DropInSounds ~= 0 then playSound(S.DropInEndSound, S.DropInSoundVolume) end        -- (v103) the board's tap as it goes
            local a, v, spin = math.rad(DI.noseOn or (DI.down - DI.pitch)), DI.vert and S.DropInVertSpeed * (DI.vk or 1) or S.DropInSpeed, DI.vert and math.min(S.DropInVertSpin, math.max(0, 92 - (DI.down - DI.pitch)) / 0.3) or (DI.ramp and 0 or S.DropInSpin)   -- (v137/v147) vert: the spin that brings the nose to 90 deg in 0.3 s and no more (150 deg/s took a 290 cm wall's board to 126 deg: off the far side)
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
NATIVE.BUILD = 224
NATIVE.WANT = 122      -- (v191) the native half this file is made for (the 'native v' number of the "loaded" line): an older one beside it is said once, in NATIVE.sync
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
-- (v198) THE PAUSE MENU THAT IS UP WITHOUT THE PAD. "The start menu got stuck on and I had to force close the game" --
-- three times on 7 Oct (21:26:47, 21:27:41, 21:37:22). SessionTweaks' key log and the mod's own say what "stuck" was: the
-- menu was drawn, and every D-pad, A and B press after it went to the GAME (the marker set and gone to, a push, a
-- powerslide) -- none to the menu. The game's menu takes its keys as the widget that has the pad's focus
-- (UMenuPageContainer::NativeOnKeyDown), and a second Start does nothing while the controller holds a menu
-- (ASessionPlayerController::ShowPauseMenu, _activePauseMenuPageContainer), so there is no way out but ending the game.
-- All three came within two seconds of leaving the replay editor or of a jump to the marker, each after a bail; what
-- takes the focus then is NOT known, and nothing of this mod's sets a focus or an input mode. So the state itself is
-- watched for and mended: four times a second, and at every D-pad / A / B press that reaches the game, the controller's
-- pause menu is asked whether it or one of its parts has the pad's focus. It is handed the focus (SetUserFocus) when
--   a press reached the game while the menu is up and unfocused -- a menu that has the pad lets none through -- and
--     it has never had the focus, or came up less than 6 s ago (the two pages that hand the pad to the game themselves,
--     the party game's and the filmer's gamepad assignment, are reached later than that and through a menu that had it);
--   or, once the question has been seen answered "yes" in this run (so a "no" means something), when a menu has not had
--     the focus in its first 0.4 s -- before any press is lost to the game.
-- Three times a menu at most; every one is logged with what the menu answered before and after.
NATIVE.mg = { proven = false }
NATIVE.menuWatch = function(key)                         -- (on the game thread) key = a press that reached the game, nil = the look four times a second
    local M, now = NATIVE.mg, os.clock()
    if not alive(s0) then M.a = nil return end
    local pc = alive(SB.pc) or alive(q(function() return s0:GetController() end))
    local cont = pc and alive(q(function() return pc._activePauseMenuPageContainer end))
    if not cont then
        -- (v218, the review) ...and as the menu GOES: the game makes its options object when options are saved or
        -- loaded, so a slider changed in this menu is read here, not at the look made as the menu came up
        if M.a then M.a = nil pcall(readAdvanced, "BodyRotationRateMultiplier", true) end
        return
    end
    local a = addr(cont)
    if M.a ~= a then
        M.a, M.t0, M.ever, M.cures, M.off, M.told = a, now, false, 0, nil, false
        pcall(readAdvanced, "BodyRotationRateMultiplier", true)   -- (v218) a pause menu has come up: the game's Advanced numbers, looked for here and not at a hop's start
    end
    local function asked()
        local own, part = q(function() return cont:HasUserFocus(pc) end, nil), q(function() return cont:HasUserFocusedDescendants(pc) end, nil)
        return own, part
    end
    local own, part = asked()
    if type(own) ~= "boolean" and type(part) ~= "boolean" then return end      -- (the question cannot be asked: nothing is done)
    if own == true or part == true then M.ever, M.off = true, nil NATIVE.mg.proven = true return end
    M.off = M.off or now
    local why
    if key then
        if not M.ever or now - M.t0 < 6 then why = "a " .. key .. " press went to the game" end
        if not M.told then
            M.told = true
            log(string.format("pause menu: up %.1f s and a %s press went to the GAME -- the menu does not have the pad (focus: its own %s, a part of it %s; it %s since it came up)%s",
                now - M.t0, key, tostring(own), tostring(part), M.ever and "has had it" or "has NOT had it", why and "" or " -- left alone: it had the focus and it is over 6 s old (a page that hands the pad to the game itself?)"))
        end
    elseif NATIVE.mg.proven and not M.ever and now - M.off >= 0.4 then
        why = string.format("it has not had the focus in the %.1f s since it came up", now - M.t0)
    end
    if not why or M.cures >= 3 then return end
    M.cures = M.cures + 1
    local ok, err = pcall(function() cont:SetUserFocus(pc) end)
    local own2, part2 = asked()
    log(string.format("pause menu: handed the pad's focus (%s) -- try %d: %s; it answers now: its own %s, a part of it %s%s", why, M.cures,
        ok and "asked of the game" or ("FAILED: " .. tostring(err)), tostring(own2), tostring(part2),
        (own2 == true or part2 == true) and "" or " (it may take a frame; looked at again in a quarter of a second)"))
end
LoopAsync(250, function()
    if not NATIVE.off and NATIVE.live then NATIVE.gt(function() pcall(NATIVE.menuWatch) end) end
    return false
end)

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
        if NATIVE.tdBackstop then pcall(NATIVE.tdBackstop) end   -- (v196) a sped-up throwdown's clock is never left running fast
        -- (v194) the classes' layout (the note at NATIVE.layoutCheck): said once. Classes that could not be read while the
        -- script loaded are read again now, before the skater is handed to the native half
        if NATIVE.layoutRes and not NATIVE.layoutTold then
            NATIVE.layoutTold = true
            if NATIVE.layoutRes.cant > 0 then
                local okl, res = pcall(NATIVE.layoutCheck)
                if okl then NATIVE.layoutRes = res end
                if NATIVE.layoutVerdict(NATIVE.layoutRes) then NATIVE.off, NATIVE.offWhy = true, "layout" end
            end
            local L = NATIVE.layoutRes
            local gameBad = L.bad - L.engBad
            log(string.format("layout: %d of %d reflected properties of the game's and the engine's classes are where the native half was written for; %d elsewhere, %d not there, %d of %d classes not readable (%s)%s%s",
                L.ok, L.total, L.bad, L.miss, L.cant, #NATIVE.LAYOUT,
                (NATIVE.buildMode == 1) and "ANOTHER BUILD of the game than the mod was written against: its functions were found by signature"
                    or ((NATIVE.buildMode == 0) and "the build the mod was written against" or "the native half does not run on this build"),
                (NATIVE.buildMode == 1 and gameBad > 0 and not NATIVE.off) and " -- NOT ACTED ON: the engine's own classes do not read as expected either, so it is the reading that is off, not the game" or "",
                (#L.notes > 0) and (" -- " .. table.concat(L.notes, "; ")) or ""))
        end
        if NATIVE.off then
            logOnce("offbuild", "*** THIS IS ANOTHER BUILD OF THE GAME than this version of the mod was written against, and "
                .. ((NATIVE.offWhy == "layout") and "its classes are laid out differently (the 'layout:' line above has the list)"
                    or "the native half did not find all of the game's functions in it (ExpandedTricks.native.log has the list)")
                .. ": Expanded Tricks is switched off (nothing of the game is touched) until the mod is updated -- only the update check runs. Please send the logs: run pack-logs.bat in the game's Mods/ExpandedTricks folder")
            if NATIVE.updateTick then pcall(NATIVE.updateTick, false) end
            return
        end
        local live = false
        pcall(function()
            if active and alive(cached) then live = (alive(mesh) ~= nil) return end
            if not refs() then
                if myAddr or active then myAddr = nil NATIVE.mapDue = true NATIVE.forgetWorld("your skater is gone") end   -- (v212) mapDue: below
                return
            end
            local a = addr(s0)
            if a and a ~= myAddr then
                -- (v212) THE NEW SKATER'S ADDRESS IS TAKEN FIRST, AND THIS NEVER LEAVES HOLDING THE OLD ONE. Build 211 took
                -- it after the forget's second look and left without it when that look was refused -- so the next turn
                -- found "a new skater" again, and the one after. 10 Oct 09:49:17 to 09:55:06, after a map change so
                -- quick that no turn of this loop saw a moment without a skater (SessionTweaks.log: the old level left
                -- and the new skater dressed inside 09:49:16): "level change (a new skater)" 175 times, every 2 s, the
                -- native half stood down each time. "I can't really get the drop-in to work that well right now ... I
                -- did a ton of them": 73 Y presses fell in those six minutes, and none got a line of the mod's.
                -- What refused the look was the half second between two looks for the skater: no longer counted from
                -- a look that found one (skater()), and taken back by forgetWorld as it drops a skater that lives.
                -- Refused all the same (the engine clearing objects out: NATIVE.walkOk), or a skater whose mesh is
                -- not there yet: the mod then holds NO skater, as after "your skater is gone" -- the next turn that
                -- finds one takes it with no second forget, whatever must be done for a new skater (the hook,
                -- NATIVE.sync, the no comply's wiring) is done from that turn, and the "map:" line owed is written
                -- then (NATIVE.mapDue; also when a click or a bumper took the skater's address before this loop
                -- came round)
                local was = myAddr
                myAddr = a
                NATIVE.mapDue = true
                if was then
                    NATIVE.forgetWorld("a new skater")
                    if not refs() then myAddr = nil return end
                    myAddr = addr(s0) or a
                end
            end
            if NATIVE.mapDue then
                NATIVE.mapDue = nil
                -- (v211) WHICH MAP. The look into the crashes of 9 Oct did not have it: 4 of that day's 14 level changes left
                -- a map no log names, and the map entered at each of the two crashes is in none either. The skater's full
                -- name holds its level's path (one line a new skater, so every map change that is survived can be counted)
                log("map: " .. tostring(q(function() return s0:GetFullName() end, "?")))
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

log("Expanded Tricks " .. MOD_VERSION .. " -- loaded (v224 / native v122)")   -- (the builds' history is in CHANGELOG.md and the source's own comments)

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

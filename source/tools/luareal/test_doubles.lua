-- test_doubles.lua: the two-hand grabs' pick (GR.doubleTick with the map it asks), the tweak (GR.tweak: rotate or bone) and the ollie's
-- animation on a hop (NATIVE.HO), cut out of main.lua and run in real Lua against a stand-in for the game.
-- luareal -run test_doubles.lua result.txt main.lua   (writes dbtest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local function at(s, from, what) return assert(src:find(s, from, true), what .. " was not found") end
local a = at("GR.MODE_NAME = {", 1, "the map's start")
local b0 = at("local function gameGrabFor(bumper, x, y, swap)", a, "gameGrabFor")
local b = at("\n    return id\nend\n", b0, "gameGrabFor's end") + #"\n    return id\nend\n"
local c = at("GR.DOUBLES = {", b, "GR.DOUBLES")
local c2 = at("\n-- hand a grab to the game", c, "the pairs' end")
local d = at("GR.KEY = {}", c2, "the tweak's helpers")
local d2 = at("\n-- a stick click while airborne.", d, "GR.doubleTick's end")
local body = src:sub(a, b - 1) .. "\n" .. src:sub(c, c2) .. "\n" .. src:sub(d, d2)

local NAME = { [1] = "Nose", [2] = "Melon", [3] = "Mute", [4] = "Chicken Salad", [5] = "Taipan", [6] = "Seatbelt",
               [100] = "Tail", [101] = "Stalefish", [102] = "Indy", [103] = "Roast Beef", [104] = "Canadian Bacon", [105] = "Crail" }
local GRAB_ID = {} for id, n in pairs(NAME) do GRAB_ID[n:lower():gsub("[%s_%-]", "")] = id end
local MODE_AIR = 3
local function world(o)
    local W = { logs = {}, sets = {}, nat = {}, t = 100, mode = 2, switch = false, goofy = false, bumpers = 3, L = { 0, 0 }, R = { 0, 0 }, game = 0 }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    env.NAT = setmetatable({}, { __index = function(_, k) if k == "switch" then return W.switch elseif k == "goofy" then return W.goofy elseif k == "mirror" then return W.goofy end end })
    env.HJN_Bumpers = function() return W.bumpers end
    env.HJN_Set = function(k, v) W.nat[k] = v end
    local SV = { GrabLBNeutral = "Mute", GrabRBNeutral = "Indy", GrabFollowStickMode = 1, GrabToeSide = 1, GrabWait = 0.12, GrabRepick = 0.35,
        DoubleGrabs = 1, GrabStart = 1, DoubleBothSticks = 1, GrabTweakStyle = 1, GrabTweakGate = 1, GrabTweakDead = 20, GrabTweakRamp = 40, GrabTweakMaxTurn = 45, GrabTweakInvert = 0,
        BoneNose = 0, BoneMelon = 15, BoneMute = 15, BoneTail = 0, BoneStalefish = 15, BoneIndy = 15, BoneCrail = 0, BoneCannonball = 0, BoneRocket = 0,
        DoubleCannonball = "Nose+Tail", DoubleGorilla = "Mute+Indy", DoubleRocket = "Nose+Crail",
        DoubleTruckDriver = "Melon+Indy", DoubleDrunkDriver = "Mute+Stalefish", DoubleSquirrel = "Melon+Stalefish",
        DoubleCannonballBase = "Indy", DoubleGorillaBase = "Indy", DoubleRocketBase = "Nose",
        DoubleTruckDriverBase = "Indy", DoubleDrunkDriverBase = "Indy", DoubleSquirrelBase = "Indy",
        BoneGorilla = 18, BoneTruckDriver = 18, BoneDrunkDriver = 18, BoneSquirrel = 18, GrabAllBone = 0 }
    for k, v in pairs(W.S or {}) do SV[k] = v end
    local GR = { blocked = function() return false end, kicks = 0, turnName = function(n) return n end,
                 idOf = function(name) return type(name) == "string" and GRAB_ID[name:lower():gsub("[%s_%-]", "")] or nil end }
    W.sim = {}
    local pc = { GetInputModeType = function() return W.mode end,
        SimulateInput_LeftStick_X_Axis = function(_, v) W.sim.LX = v end, SimulateInput_LeftStick_Y_Axis = function(_, v) W.sim.LY = v end,
        SimulateInput_RightStick_X_Axis = function(_, v) W.sim.RX = v end, SimulateInput_RightStick_Y_Axis = function(_, v) W.sim.RY = v end }
    local q = function(fn, dflt) local ok, r = pcall(fn) if ok and r ~= nil then return r end return dflt end
    local s0 = { GetController = function() return pc end, GetGrabState = function() return W.game end }
    local stickNow = function(which) local v = (which == "Left") and W.L or W.R return v[1], v[2], "test" end
    local analogStick = function(which) local v = (which == "Left") and W.L or W.R return v[1], v[2] end
    local grabSet = function(id, why) W.sets[#W.sets + 1] = id W.logs[#W.logs + 1] = why W.game = id return true end
    local grabTitle = function(id) return (NAME[id] or "?") .. " Grab" end
    local chunk = "local GR, S, GRAB_ID, SB, alive, q, s0, log, logOnce, NATIVE, stickNow, analogStick, grabSet, grabTitle, MODE_AIR, inst, visualGoofy, trickNameLater, trickNameHide, AS = ...\n"
        .. body .. "\nreturn GR"
    local fn = assert(load(chunk, "=doubles", "t", env))
    W.GR = fn(GR, SV, GRAB_ID, {}, function(x) return x end, q, s0, function(s) W.logs[#W.logs + 1] = s end, function() end,
        { grab = function() return true end, GRABS = { { "Nose", 1 }, { "Melon", 2 }, { "Mute", 3 }, { "Tail", 100 }, { "Stalefish", 101 }, { "Indy", 102 }, { "Crail", 105 },
            { "Cannonball", 200 }, { "Gorilla", 201 }, { "Rocket", 202 }, { "TruckDriver", 203 }, { "DrunkDriver", 204 }, { "Squirrel", 205 } } },
        stickNow, analogStick, grabSet, grabTitle, MODE_AIR, { IsGrinding = false },
        function() return W.goofy end, function() end, function() end, { mode = "named" })
    -- some frames go by (60 a second); -> the two-hand grab's display name, or "none"
    W.run = function(sec)
        local n = math.max(1, math.floor(sec * 60 + 0.5))
        for _ = 1, n do
            W.t = W.t + 1 / 60
            W.game = W.GR.doubleTick(W.t, W.game, MODE_AIR) or W.game
            if W.game ~= W.gnat then                             -- (as the grab tick has it: a grab begins -- the sticks as they stand are the gate's)
                W.gnat = W.game
                if W.game ~= 0 then
                    local function g(v) return { v[1], v[2], math.sqrt(v[1] * v[1] + v[2] * v[2]), math.deg(math.atan(v[2], v[1])) } end
                    W.GR.nativeT0, W.GR.gate = W.t, { Left = g(W.L), Right = g(W.R) }
                    W.GR.boneNow, W.GR.boneSaid = nil, nil
                end
            end
            if W.game == 0 and (W.GR.boneNow or 0) ~= 0 then W.GR.boneSet(0) end
            W.GR.tweak(W.t, W.game)
        end
        return W.GR.dbl and W.GR.dbl[3] or "none"
    end
    return W
end
local out = {}
local function check(name, got, want) local ok = got == want out[#out + 1] = (ok and "ok   " or "FAIL ") .. name .. (ok and "" or ("  -- got " .. tostring(got) .. ", wanted " .. tostring(want))) return ok end
local all = true
local LEFT, RIGHT, UP, MID = { -1, 0 }, { 1, 0 }, { 0, 1 }, { 0, 0 }
local RUP, RDOWN = { 0, -1 }, { 0, 1 }      -- the RIGHT stick as the game reads it: pushed up on the pad is -1, pulled down +1
local function pair(o, l, r, sec) o.L, o.R = l, r local W = world(o) return W.run(sec or 0.05), W end

-- the four states, front foot / back foot: a regular rider rolling forward has his toes on the right
all = check("regular: both sticks to the toes (right)        ", pair({}, RIGHT, RIGHT), "Gorilla Grab") and all
all = check("regular: front stick to the heels, back to toes ", pair({}, LEFT, RIGHT), "Truck Driver") and all
all = check("regular: front stick to the toes, back to heels ", pair({}, RIGHT, LEFT), "Drunk Driver") and all
all = check("regular: both sticks to the heels (left)        ", pair({}, LEFT, LEFT), "Squirrel") and all
-- goofy rolling forward: the toes are on the LEFT, the same four turn round
all = check("goofy: both sticks to the toes (left)           ", pair({ goofy = true }, LEFT, LEFT), "Gorilla Grab") and all
all = check("goofy: front stick to the heels (right)         ", pair({ goofy = true }, RIGHT, LEFT), "Truck Driver") and all
all = check("goofy: back stick to the heels (right)          ", pair({ goofy = true }, LEFT, RIGHT), "Drunk Driver") and all
all = check("goofy: both sticks to the heels (right)         ", pair({ goofy = true }, RIGHT, RIGHT), "Squirrel") and all
-- goofy riding switch: the toes are on the right again
all = check("goofy switch: front heels (left), back toes     ", pair({ goofy = true, switch = true }, LEFT, RIGHT), "Truck Driver") and all
all = check("goofy switch: both to the heels (left)          ", pair({ goofy = true, switch = true }, LEFT, LEFT), "Squirrel") and all
-- left foot / right foot, goofy rolling forward: LB (the left stick) is the BACK hand, the toes are on the left
all = check("left/right goofy: both to the toes (left)       ", pair({ mode = 1, goofy = true }, LEFT, LEFT), "Gorilla Grab") and all
all = check("left/right goofy: left stick (back hand) heels  ", pair({ mode = 1, goofy = true }, RIGHT, LEFT), "Drunk Driver") and all
all = check("left/right goofy: right stick (front hand) heels", pair({ mode = 1, goofy = true }, LEFT, RIGHT), "Truck Driver") and all
all = check("left/right goofy: both to the heels (right)     ", pair({ mode = 1, goofy = true }, RIGHT, RIGHT), "Squirrel") and all
-- left foot / right foot, regular: LB is the front hand as in the other mode
all = check("left/right regular: left stick heels            ", pair({ mode = 1 }, LEFT, RIGHT), "Truck Driver") and all
-- what the native half is told
do local n, W = pair({}, LEFT, LEFT)
    all = check("Squirrel: the native half is told kind 205", W.nat.double, 205) and all
    all = check("Squirrel: the game holds the Indy for the crouch", W.game, 102) and all
    n, W = pair({}, LEFT, RIGHT) all = check("Truck Driver: kind 203", W.nat.double, 203) and all
    n, W = pair({}, RIGHT, LEFT) all = check("Drunk Driver: kind 204", W.nat.double, 204) and all end
-- both sticks must be pushed: one stick alone, or none, is the Gorilla
all = check("one stick to the heels, the other centred       ", pair({}, LEFT, MID, 0.3), "Gorilla Grab") and all
all = check("the back stick alone to the heels               ", pair({}, MID, LEFT, 0.3), "Gorilla Grab") and all
all = check("no stick at all                                 ", pair({}, MID, MID, 0.3), "Gorilla Grab") and all
all = check("one stick, before GrabWait is over: nothing yet ", pair({}, LEFT, MID, 0.05), "none") and all
all = check("DoubleBothSticks=0: one stick is enough         ", pair({ S = { DoubleBothSticks = 0 } }, LEFT, MID, 0.3), "Truck Driver") and all
-- the second stick comes a moment later: the Gorilla becomes the pair inside GrabRepick
do local n, W = pair({}, LEFT, MID, 0.2)
    W.R = RIGHT all = check("the second stick 0.2 s later: Gorilla -> Truck Driver", W.run(0.05), "Truck Driver") and all end
do local n, W = pair({}, LEFT, MID, 0.2)
    W.run(0.4) W.R = LEFT all = check("the second stick after GrabRepick: it stays the Gorilla", W.run(0.05), "Gorilla Grab") and all end
-- the old pairs are as they were
all = check("left up, right pulled down: Cannonball          ", pair({}, UP, RDOWN), "Cannonball") and all
all = check("both sticks up: Quasimodo                       ", pair({}, UP, RUP), "Quasimodo") and all
do local n, W = pair({}, MID, MID, 0.2)
    W.L, W.R = UP, RUP all = check("a no-stick Gorilla, both sticks up inside GrabRepick: Quasimodo", W.run(0.05), "Quasimodo") and all end

-- THE TWEAK: ROTATE OR BONE (GR.tweak, run after the pairs as the grab tick runs it)
local function sw(at0, by) local a2 = math.rad(at0 + by) return { math.cos(a2), math.sin(a2) } end   -- a stick at at0 degrees (0 = right, 90 = up in the read), swung by `by`
local function saidBone(W) local n, last = 0, nil for _, l in ipairs(W.logs) do if tostring(l):find("bone:", 1, true) then n, last = n + 1, l end end return n, last end
do local n, W = pair({}, LEFT, RIGHT)                                     -- a Truck Driver, both sticks where they picked it
    all = check("tweak: a pair at its pick -- no bone", W.nat.bone or 0, 0) and all
    all = check("tweak: ...and the game is shown both sticks straight", W.sim.LX == 0 and W.sim.RX == 0 and W.sim.LY == 1 and W.sim.RY == -1, true) and all
    W.L = sw(180, -60) W.run(0.05)
    all = check("bone: one stick swung 60 degrees off its pick -- the full bone", W.nat.bone, 1) and all
    all = check("bone: ...and the game is shown no swing", W.sim.LX == 0 and W.sim.RX == 0, true) and all
    W.L = sw(180, 61) W.run(0.05) all = check("bone: swung the other way round -- the same", W.nat.bone, 1) and all
    W.L = sw(180, -30) W.run(0.05) all = check("bone: 30 degrees -- a quarter (20 of play, 40 more to the full)", math.floor(W.nat.bone * 100 + 0.5), 25) and all
    W.L = sw(180, -15) W.run(0.05) all = check("bone: inside the play -- none", W.nat.bone, 0) and all
    W.L, W.R = LEFT, sw(0, 70) W.run(0.05) all = check("bone: the other stick alone does it too", W.nat.bone, 1) and all
    W.L, W.R = UP, RUP
    all = check("bone: both sticks turned up -- still the Truck Driver, not a Quasimodo", W.run(0.05), "Truck Driver") and all
    all = check("bone: ...at the full bone", W.nat.bone, 1) and all
    local cnt, last = saidBone(W)
    all = check("bone: said once in the log, with its distance", cnt == 1 and last:find("Truck Driver", 1, true) ~= nil and last:find("18 cm", 1, true) ~= nil, true) and all
    out[#out + 1] = "       " .. tostring(last)
    W.game, W.bumpers = 0, 0 W.run(0.3)
    all = check("the grab ended: no two-hand grab any more, the native half told 'double' 0 and bone 0", W.GR.dbl == nil and W.nat.double == 0 and W.nat.bone == 0, true) and all
end
do local n, W = pair({ S = { GrabTweakStyle = 0 } }, LEFT, RIGHT)        -- the same pair with the style on ROTATE
    W.L = sw(180, -60) W.run(0.05)
    all = check("rotate: the same swing is the game's twist (its sideways part shown) and nothing is boned", (W.nat.bone or 0) == 0 and math.abs(W.sim.LX) > 0.5, true) and all end
do local n, W = pair({}, UP, RDOWN)                                      -- a Cannonball has no bone of its own: it rotates in either style
    W.L = sw(90, 60) W.run(0.05)
    all = check("a pair without a bone (Cannonball) rotates in the bone style too", (W.nat.bone or 0) == 0 and math.abs(W.sim.LX) > 0.5, true) and all end
do local n, W = pair({ goofy = true }, RIGHT, RIGHT)                      -- a goofy Squirrel
    W.L, W.R = sw(0, 60), sw(0, -60) W.run(0.05)
    all = check("bone: a goofy Squirrel, both sticks turned forward on the pad", W.GR.dbl[3] == "Squirrel" and W.nat.bone == 1, true) and all end
do local n, W = pair({}, MID, MID, 0.2)                                   -- a Gorilla picked with no stick
    W.run(0.4) W.L, W.R = LEFT, RIGHT
    all = check("a no-stick Gorilla, the sticks pushed after GrabRepick -- it stays the Gorilla", W.run(0.05), "Gorilla Grab") and all
    all = check("bone: ...and that push is its bone (the game still shown the sticks centred)", W.nat.bone == 1 and W.sim.LX == 0 and W.sim.LY == 0, true) and all end
do local n, W = pair({}, LEFT, MID, 0.2)                                  -- a Gorilla by the both-sticks rule, its pick not settled yet
    all = check("bone: a pair picked with a stick still centred does not bone inside GrabRepick", W.nat.bone or 0, 0) and all end
do local n, W = pair({ S = { GrabAllBone = 10 } }, LEFT, RIGHT)
    W.L = sw(180, -60) W.run(0.05) local cnt, last = saidBone(W)
    all = check("bone: the adder for all is in the distance (18 + 10)", cnt == 1 and last:find("28 cm", 1, true) ~= nil, true) and all end
-- one-hand grabs: the grab's own stick
do local W = world({ bumpers = 1, L = LEFT })                             -- regular, LB and the left stick to the heels: a Melon the mod handed over
    W.game = 2 W.GR.kick = { id = 2, at = W.t, bumper = "LB" } W.run(0.05)
    all = check("one hand: a Melon at its pick -- no bone, no twist", (W.nat.bone or 0) == 0 and W.sim.LX == 0, true) and all
    W.L = sw(180, -60) W.run(0.05)
    all = check("one hand: its stick swung 60 degrees -- the full bone, the game shown no swing", W.nat.bone == 1 and W.sim.LX == 0, true) and all
    W.L, W.R = LEFT, RIGHT W.run(0.05)
    all = check("one hand: the OTHER stick pushed is not this grab's bone", W.nat.bone, 0) and all
    W.L = sw(180, 45) W.run(0.05) local cnt, last = saidBone(W)
    all = check("one hand: said with the Melon's own distance", cnt == 1 and last:find("Melon Grab", 1, true) ~= nil and last:find("15 cm", 1, true) ~= nil, true) and all
    out[#out + 1] = "       " .. tostring(last) end
do local W = world({ bumpers = 2, R = RIGHT })                            -- an Indy the GAME picked (no hand-over of the mod's): RB, so the right stick
    W.game = 102 W.run(0.05) W.R = sw(0, 60) W.run(0.05)
    all = check("one hand: a grab the game picked itself goes by its hand's stick (Indy: the right one)", W.nat.bone, 1) and all
    W.R, W.L = RIGHT, sw(0, 60) W.run(0.05)
    all = check("one hand: ...and not by the left one", W.nat.bone, 0) and all end
do local W = world({ bumpers = 1, L = UP })                               -- a Nose grab has no bone: it rotates
    W.game = 1 W.GR.kick = { id = 1, at = W.t, bumper = "LB" } W.run(0.05) W.L = sw(90, 60) W.run(0.05)
    all = check("one hand: a Nose grab (no bone of its own) rotates in the bone style", (W.nat.bone or 0) == 0 and math.abs(W.sim.LX) > 0.5, true) and all end
do local W = world({ bumpers = 1, L = LEFT, S = { GrabTweakStyle = 0 } }) -- the style on ROTATE: the Melon twists as it always did
    W.game = 2 W.GR.kick = { id = 2, at = W.t, bumper = "LB" } W.run(0.05) W.L = sw(180, -60) W.run(0.05)
    all = check("one hand: rotate style -- the Melon twists, nothing is boned", (W.nat.bone or 0) == 0 and math.abs(W.sim.LX) > 0.5, true) and all end
do local W = world({ bumpers = 1, L = MID })                              -- a Mute picked with the stick centred (LB alone): pushing the stick is the tweak
    W.game = 3 W.GR.kick = { id = 3, at = W.t, bumper = "LB" } W.run(0.05) W.L = LEFT W.run(0.05)
    all = check("one hand: picked with the stick centred -- pushing it is the bone, the game still shown it centred", W.nat.bone == 1 and W.sim.LX == 0 and W.sim.LY == 0, true) and all end
do local W = world({ bumpers = 1, L = LEFT, S = { GrabTweakGate = 0 } })  -- the gate switched off does not switch the bone off
    W.game = 2 W.GR.kick = { id = 2, at = W.t, bumper = "LB" } W.run(0.05) W.L = sw(180, -60) W.run(0.05)
    all = check("one hand: GrabTweakGate=0 -- a grab that bones still bones", W.nat.bone, 1) and all end

-- THE OLLIE'S ANIMATION ON A HOP (NATIVE.HO)
do
    local h0 = at("NATIVE.HO = { on = false", 1, "NATIVE.HO")
    local h1 = at("\n------------------------------------------------------------------- landing absorb", h0, "NATIVE.HO's end")
    local hbody = src:sub(h0, h1)
    local function hop(o)
        local W = { logs = {}, t = 50, asked = {}, fp = 1, cls = "ABP_AMXX_Skater_C", S = { HippieJump = 2, HopOlliePre = 0.06, HopOllieSpan = 0.6, HopOllieLand = 0.72, HopOllieDeck = 1 }, nat = {} }
        for k, v in pairs(o or {}) do if k == "S" then for a2, b2 in pairs(v) do W.S[a2] = b2 end else W[k] = v end end
        local function arr(t) for _, e in ipairs(t) do e.get = function(self) return self end end return setmetatable(t, { __index = { GetArrayNum = function() return #t end } }) end
        local function note(cls) return { NotifyTriggerChance = 1.0, Notify = cls and { VolumeMultiplier = 0.8, GetClass = function() return { GetFName = function() return { ToString = function() return cls end } end } end,
            GetFullName = function() return cls .. " /Game/Animation/AMXX/OnBoard/Regular/FlipTrick/AMXX_RGS_Ollie_Hi.AMXX_RGS_Ollie_Hi:" .. cls .. "_0" end } or nil } end
        W.notes = arr({ note("AnimNotify_PlaySoundRecorded"), note("AnimNotify_Pop"), note("AnimNotify_PlaySurfaceTypeSound"), note(nil) })
        local function anim(len) return { Animation = { SequenceLength = len, Notifies = (len > 0.6 and not W.bare) and W.notes or arr({}) } } end
        W.TB = { name = "ollie trick", AnimLength = 0, SampleData = arr((function() local a = anim(0.62) return { anim(0.50), a, a } end)()) }
        W.CB, W.LD, W.KF = { name = "ollie catch", SampleData = arr({}) }, { name = "ollie land" }, { name = "kickflip trick" }
        local def = { AnimSet = { TrickBlendSpace = W.TB, CatchBlendSpace = W.CB, LandBlendSpace = W.LD } }
        W.inst = { FootPositionType = W.fp, FlipTrickAnimSetIndex = 0, FlipTrickAnimSet01 = { TrickBlendSpace = W.KF }, FlipTrickAnimSet02 = {},
            GetClass = function() return { GetFName = function() return { ToString = function() return W.cls end } end } end,
            GetCurrentStateName = function() return { ToString = function() return W.state or "Crank State" end } end }
        local env = setmetatable({}, { __index = _G })
        env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
        env.StaticFindObject = function(p) W.asked[#W.asked + 1] = p if W.nodef then return nil end return def end
        env.FindAllOf = function(cn) return W.all and W.all[cn] or nil end
        env.HJN_Set = function(k, v) W.nat[k] = (W.nat[k] or 0) + 1 W.nat["last " .. k] = v end
        env.math = setmetatable({ random = function() return W.rnd or 0 end }, { __index = math })
        local q = function(fn, dflt) local ok, r = pcall(fn) if ok and r ~= nil then return r end return dflt end
        local chunk = "local NATIVE, S, inst, q, alive, addr, log, logOnce, BLOCKERS, airT, P, stateNow = ...\n" .. hbody .. "\nreturn NATIVE"
        local fn = assert(load(chunk, "=hopollie", "t", env))
        -- (build 210) the walk gate: NATIVE.walkOk says whether the game's objects may be walked now
        W.N = fn({ walkOk = function() W.walkAsked = (W.walkAsked or 0) + 1 return not W.busy end }, W.S, W.inst, q, function(x) return x end, function(x2) return x2 end, function(s) W.logs[#W.logs + 1] = s end,
            function(_, s) W.logs[#W.logs + 1] = s end, { "IsCranking", "IsTrickPending", "IsPushing", "HasLateTrick" }, 0.57, { pre = 0.06 }, function() return "Street Trick State" end)
        return W
    end
    do local W = hop({ S = { HippieJump = 1 } })
        all = check("hop ollie: HippieJump=1, the jump animation -- not armed", W.N.HO.arm("hippie"), false) and all
        all = check("hop ollie: HippieJump=1 -- nothing asked of the game, nothing written", #W.asked == 0 and W.inst.FlipTrickAnimSetIndex == 0 and W.inst.FlipTrickAnimSet01.TrickBlendSpace == W.KF, true) and all end
    do local W = hop()
        all = check("hop ollie: armed", W.N.HO.arm("hippie"), true) and all
        all = check("hop ollie: the regular ollie's definition was asked for", W.asked[1], "/Game/Data/Input/FlipTricks/TRICK_RGS_Ollie.TRICK_RGS_Ollie") and all
        all = check("hop ollie: the other slot is taken (the kickflip's stays)", W.inst.FlipTrickAnimSetIndex == 1 and W.inst.FlipTrickAnimSet01.TrickBlendSpace == W.KF, true) and all
        all = check("hop ollie: the slot has the ollie's trick and catch blend spaces (and nothing else is written)", W.inst.FlipTrickAnimSet02.TrickBlendSpace == W.TB and W.inst.FlipTrickAnimSet02.CatchBlendSpace == W.CB and W.inst.FlipTrickAnimSet02.LandBlendSpace == nil, true) and all
        all = check("hop ollie: the animation's sounds are silenced (2 sound notifies of 4; the pop notify is left alone)",
            W.notes[1].Notify.VolumeMultiplier == 0 and W.notes[3].Notify.VolumeMultiplier == 0 and W.notes[2].Notify.VolumeMultiplier == 0.8 and W.notes[1].NotifyTriggerChance == 1, true) and all
        -- the game's own update: its trick is not in this hop's slot, so it takes the index back and fills the other slot
        W.inst.FlipTrickAnimSetIndex = 0 W.inst.FlipTrickAnimSet01.TrickBlendSpace = W.KF
        W.t = W.t + 0.016 W.N.HO.flags()
        all = check("hop ollie: the game took the index back -- put on this hop's slot again, the ollie still in it", W.inst.FlipTrickAnimSetIndex == 1 and W.inst.FlipTrickAnimSet02.TrickBlendSpace == W.TB and W.inst.FlipTrickAnimSet01.TrickBlendSpace == W.KF, true) and all
        W.inst.IsCranking, W.inst.IsPushing = true, true
        W.t = W.t + 0.02 W.N.HO.flags()
        all = check("hop ollie: the first frames -- IsTrickPending up, the crouch let go", W.inst.IsTrickPending == true and W.inst.IsCranking == false and W.inst.IsPushing == false, true) and all
        all = check("hop ollie: the catch loop is asked for", W.inst.HasCatchLoop == true and W.inst.HasTrickLoop == false and W.inst.IsAutoCatching == true, true) and all
        all = check("hop ollie: 0.62 s of animation into 60 % of 0.57 s of air = x1.81", math.floor(W.inst.FlipTrickPlaybackRate * 100 + 0.5), 181) and all
        all = check("hop ollie: the feet are asked to be kept on the board from the first frame (8 poses at a time)", (W.nat.hopdeck or 0) >= 1 and W.nat["last hopdeck"] == 8, true) and all
        W.t = W.t + 0.1 W.N.HO.flags()
        all = check("hop ollie: 0.12 s in, the machine still in the crouch -- IsTrickPending stays up", W.inst.IsTrickPending, true) and all
        W.state = "Street Trick State" W.t = W.t + 0.02 W.N.HO.flags()
        all = check("hop ollie: the machine has taken it -- IsTrickPending down", W.inst.IsTrickPending, false) and all
        local asked = W.nat.hopdeck W.t = W.t + 0.3
        W.state = "Street Trick Catch State" W.t = W.t + 0.02 W.N.HO.flags()
        all = check("hop ollie: past 45 % of the air the feet are no longer asked for", W.nat.hopdeck, asked) and all
        all = check("hop ollie: ...and it stays down in the states after", W.inst.IsTrickPending, false) and all
        W.inst.IsTrickPending = true W.N.HO.off()
        all = check("hop ollie: the hop over -- off, IsTrickPending down", W.N.HO.on == false and W.inst.IsTrickPending == false, true) and all
        all = check("hop ollie: ...and the sounds are back as they were", W.notes[1].Notify.VolumeMultiplier == 0.8 and W.notes[3].Notify.VolumeMultiplier == 0.8, true) and all
        W.inst.FlipTrickAnimSetIndex = 0 W.inst.FlipTrickAnimSet01.TrickBlendSpace = W.KF          -- (the game's own again)
        all = check("hop ollie: armed again -- the other slot again", W.N.HO.arm("mini") and W.inst.FlipTrickAnimSetIndex, 1) and all
        W.N.HO.off()
        W.inst.FlipTrickAnimSetIndex = 1 W.inst.FlipTrickAnimSet02.TrickBlendSpace = W.TB           -- the game's last trick IS this ollie
        all = check("hop ollie: the game's last trick is this ollie -- its own slot is used", W.N.HO.arm("hippie") and W.inst.FlipTrickAnimSetIndex == 1 and W.N.HO.own, true) and all
        W.N.HO.off()
        for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. tostring(l) end
    end
    do local W = hop({ S = { HippieJump = 3 } })                              -- one or the other, jump by jump
        W.rnd = 0.2 all = check("hop ollie: HippieJump=3, the draw under a half -- the ollie", W.N.HO.arm("hippie"), true) and all W.N.HO.off()
        W.rnd = 0.8 all = check("hop ollie: HippieJump=3, the draw over a half -- the jump animation", W.N.HO.arm("hippie"), false) and all
        all = check("hop ollie: ...and nothing is left on from the hop before", W.N.HO.on, false) and all end
    do local W = hop({ S = { HippieJump = 0 } })                              -- hippie jumps off: a mini hop (its own switch) has the jump animation
        all = check("hop ollie: HippieJump=0 -- a mini hop is not armed", W.N.HO.arm("mini"), false) and all end
    do local W = hop({ fp = 3 }) W.N.HO.arm("hippie")
        all = check("hop ollie: out of the nollie crouch -- the nollie's definition", W.asked[1], "/Game/Data/Input/FlipTricks/TRICK_NLS_Nollie.TRICK_NLS_Nollie") and all end
    do local W = hop({ fp = 4 }) W.N.HO.arm("hippie")
        all = check("hop ollie: riding switch -- the switch ollie's", W.asked[1], "/Game/Data/Input/FlipTricks/TRICK_SWS_Ollie.TRICK_SWS_Ollie") and all end
    do local W = hop({ cls = "ABP_Other_C" })
        all = check("hop ollie: another animation blueprint -- not armed", W.N.HO.arm("hippie"), false) and all end
    do local W = hop({ nodef = true })
        all = check("hop ollie: the definition not in memory -- not armed, the slots untouched", W.N.HO.arm("hippie") == false and W.inst.FlipTrickAnimSetIndex == 0, true) and all end
    do local W = hop({ S = { HopOllieSound = 1 } }) W.N.HO.arm("hippie")
        all = check("hop ollie: HopOllieSound=1 -- the animation's sounds are left", W.notes[1].Notify.VolumeMultiplier == 0.8, true) and all end
    do local W = hop({ bare = true })                                        -- the animations give no notifies: looked for by name
        W.all = { AnimNotify_PlaySoundRecorded = { W.notes[1].Notify, { VolumeMultiplier = 0.7, GetClass = W.notes[1].Notify.GetClass, GetFullName = function() return "AnimNotify_PlaySoundRecorded /Game/x/AMXX_RGS_Ollie_Hi_Land.AMXX_RGS_Ollie_Hi_Land:n" end },
                    { VolumeMultiplier = 0.6, GetClass = W.notes[1].Notify.GetClass, GetFullName = function() return "AnimNotify_PlaySoundRecorded /Game/x/AMXX_SWS_Ollie_Hi.AMXX_SWS_Ollie_Hi:n" end } },
                  AnimNotify_PlaySurfaceTypeSound = { W.notes[3].Notify } }
        W.N.HO.arm("hippie")
        all = check("hop ollie: found by name -- this stance's ollie silenced, its landing and the switch ollie left", W.notes[1].Notify.VolumeMultiplier == 0 and W.notes[3].Notify.VolumeMultiplier == 0
            and W.all.AnimNotify_PlaySoundRecorded[2].VolumeMultiplier == 0.7 and W.all.AnimNotify_PlaySoundRecorded[3].VolumeMultiplier == 0.6, true) and all
        W.N.HO.off()
        all = check("hop ollie: found by name -- back after the hop", W.notes[1].Notify.VolumeMultiplier == 0.8 and W.notes[3].Notify.VolumeMultiplier == 0.8, true) and all end
    do local W = hop({ bare = true, busy = true })                           -- (build 210) the engine is clearing objects out: no walk
        local walked = 0
        W.all = setmetatable({}, { __index = function(_, cn) walked = walked + 1 return (cn == "AnimNotify_PlaySoundRecorded") and { W.notes[1].Notify } or { W.notes[3].Notify } end })
        all = check("walk gate: the hop is armed all the same", W.N.HO.arm("hippie"), true) and all
        all = check("walk gate: while the engine clears objects out the notifies are NOT looked for by name (asked, no walk made)", (W.walkAsked or 0) >= 1 and walked == 0, true) and all
        all = check("walk gate: ...so this hop's sounds are left as they are", W.notes[1].Notify.VolumeMultiplier == 0.8 and W.notes[3].Notify.VolumeMultiplier == 0.8, true) and all
        W.N.HO.off()
        W.busy = false
        W.N.HO.arm("hippie")
        all = check("walk gate: the next hop, the purge over -- looked for (nothing was kept from the hop before) and silenced", walked == 2 and W.notes[1].Notify.VolumeMultiplier == 0 and W.notes[3].Notify.VolumeMultiplier == 0, true) and all
        W.N.HO.off()
        all = check("walk gate: ...and back after it", W.notes[1].Notify.VolumeMultiplier == 0.8 and W.notes[3].Notify.VolumeMultiplier == 0.8, true) and all end
    do local W = hop({ S = { HopOllieDeck = 0 } }) W.N.HO.arm("hippie") W.N.HO.flags()
        all = check("hop ollie: HopOllieDeck=0 -- not asked for at all", W.nat.hopdeck, nil) and all end
    do local W = hop({ S = { HopOllieSpan = 0 } }) W.N.HO.arm("hippie") W.N.HO.flags()
        all = check("hop ollie: HopOllieSpan=0 -- at its own speed", W.inst.FlipTrickPlaybackRate, 1.0) and all
        W.t = W.t + 0.35 W.N.HO.flags()
        all = check("hop ollie: the machine never took it -- IsTrickPending down after 0.3 s", W.inst.IsTrickPending, false) and all end
end

-- THE WALK GATE (build 210): NATIVE.walkOk / NATIVE.all / NATIVE.first
do
    local g0 = at("NATIVE.WK = { n = 0, no = 0 }", 1, "the walk gate")
    local g1 = at("\nlocal function skater()", g0, "the walk gate's end")
    local function gate(o)
        local W = { t = 100, logs = {}, walks = 0 }
        for k, v in pairs(o or {}) do W[k] = v end
        local env = setmetatable({}, { __index = _G })
        env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
        if W.busy ~= "none" then env.HJN_GcBusy = function() if W.busy == "fault" then error("x") end return W.busy or 0 end end
        env.FindAllOf = function(cn) W.walks = W.walks + 1 return { cn } end
        env.FindFirstOf = function(cn) W.walks = W.walks + 1 return cn end
        local fn = assert(load("local NATIVE, log = ...\n" .. src:sub(g0, g1) .. "\nreturn NATIVE", "=walkgate", "t", env))
        W.N = fn({}, function(s) W.logs[#W.logs + 1] = s end)
        return W
    end
    do local W = gate()
        all = check("walk gate: no purge on -- a walk is made", W.N.all("X") ~= nil and W.walks == 1, true) and all
        W.busy = 1
        all = check("walk gate: a purge on -- FindAllOf is not called, the caller gets nil", W.N.all("X") == nil and W.N.first("X") == nil and W.walks == 1, true) and all
        all = check("walk gate: ...said once in the log, not at every look", #W.logs, 1) and all
        all = check("walk gate: ...the look for the skater waits as well", W.N.walkOk("skater"), false) and all
        W.busy = 0
        all = check("walk gate: the purge over -- walks again", W.N.first("X") == "X" and W.walks == 2, true) and all
        all = check("walk gate: the skater is looked for", W.N.walkOk("skater"), true) and all
        W.t = W.t + 0.2
        all = check("walk gate: ...not again 0.2 s later (the menus: no skater, a look at every call)", W.N.walkOk("skater"), false) and all
        all = check("walk gate: ...which holds no other look back", W.N.walkOk(), true) and all
        W.t = W.t + 0.4
        all = check("walk gate: ...and again 0.6 s after the first", W.N.walkOk("skater"), true) and all
        for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. tostring(l) end
    end
    for _, how in ipairs({ "none", -1, "fault" }) do                         -- the flags cannot be read: an older native half, an unknown build, a fault
        local W = gate({ busy = how })
        all = check("walk gate (flags not readable, " .. tostring(how) .. "): no level change yet -- walks", W.N.walkOk(), true) and all
        W.N.WK.lvlAt = W.t
        W.t = W.t + 3
        all = check("walk gate (flags not readable, " .. tostring(how) .. "): 3 s after a level change -- no walk", W.N.all("X") == nil, true) and all
        all = check("walk gate (flags not readable, " .. tostring(how) .. "): ...but the skater is looked for", W.N.walkOk("skater"), true) and all
        W.t = W.t + 6
        all = check("walk gate (flags not readable, " .. tostring(how) .. "): 9 s after it -- walks again", W.N.all("X") ~= nil, true) and all
    end
    do local W = gate({ busy = 0 })                                           -- the flags read: a level change holds nothing back by itself
        W.N.WK.lvlAt = W.t W.t = W.t + 1
        all = check("walk gate: the flags read and clear 1 s after a level change -- walks", W.N.all("X") ~= nil, true) and all end
end

local o = assert(io.open("dbtest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the two-hand grabs' test failed: see dbtest_out.txt", 0) end

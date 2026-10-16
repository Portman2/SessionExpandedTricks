-- test_bone212.lua: build 212's bone, the Lua side (mk212_bone.pl), cut out of main.lua and run in real Lua against a
-- stand-in for the game:
--   A  the settings and their ranges, read off the file's own tables (the defaults, the ini's rows, the menu's rows);
--   B  NATIVE.hands: GrabBoneBehind on its way to the native half (HJN_Set "bonebehind");
--   C  what a boned grab's log line says about how far out it may go (GR.boneSet);
--   D  THE CENTRED PICK (GR.tweak): a grab picked with the stick centred is shown that stick pushed straight while the
--      board is what a bone moves, and pushed AGAIN where the game has taken no catch.
-- The stand-in's "game" for D is a MODEL of what was read off the exe (verdict_bone.txt, extra evidence 1), not the
-- game: its handler reads the sticks it was shown on the tick before; from no catch it takes one only on a tick a
-- stick BECOMES pushed (and W.refuse of those ticks are refused, standing for its other conditions); with a catch it
-- keeps one for as long as a stick stays pushed; the state is 1 (left), 2 (right) or 5 (both). The mod's own nudge
-- (v118, the grab tick's own lines, run here as they are) reads as state 2 until the model's next tick.
-- Checks marked [new] are what build 212 adds: they must FAIL on the input file (l1.lua); the others hold on both.
-- luareal -run test_bone212.lua result.txt main.lua   (writes bone212_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local function at(s, from, what) return assert(src:find(s, from, true), what .. " was not found") end
-- the grabs' map, the pairs, the bone and the tweak (test_doubles.lua's own cut)
local a = at("GR.MODE_NAME = {", 1, "the map's start")
local b0 = at("local function gameGrabFor(bumper, x, y, swap)", a, "gameGrabFor")
local b = at("\n    return id\nend\n", b0, "gameGrabFor's end") + #"\n    return id\nend\n"
local c = at("GR.DOUBLES = {", b, "GR.DOUBLES")
local c2 = at("\n-- hand a grab to the game", c, "the pairs' end")
local d = at("GR.KEY = {}", c2, "the tweak's helpers")
local d2 = at("\n-- a stick click while airborne.", d, "GR.doubleTick's end")
local body = src:sub(a, b - 1) .. "\n" .. src:sub(c, c2) .. "\n" .. src:sub(d, d2)
-- the grab tick's own lines: what a new grab of the game's resets, and the mod's own nudge (v118)
local r0 = at("            GR.gateLogged, GR.turn, GR.turnEnd = false, 0, nil\n", 1, "the new grab's resets")
local r1 = at("            GR.turnYaw = q(function()", r0, "the new grab's resets' end")
local resets = src:sub(r0, r1 - 1)
local n0 = at("    if native ~= 0 and type(HJN_CatchState) == \"function\" then\n        local cs = tonumber(HJN_CatchState()) or 0\n", r1, "the nudge")
local n1 = at("    -- (v108) THE GAME'S TWEAK, GATED.", n0, "the nudge's end")
local nudge = src:sub(n0, n1 - 1)
-- NATIVE.hands and GR.boneSet (test_bonepush.lua's own cuts)
local ha = at("NATIVE.hands = function(force)", 1, "NATIVE.hands")
local hb = at("\n-- MAP CHANGES.", ha, "NATIVE.hands' end")
local hands = src:sub(ha, hb)
local sa = at("GR.boneK = { Left = 0, Right = 0 }", 1, "GR.boneSet's start")
local sb = at("GR.tweak = function(now, native)", sa, "GR.boneSet's end")
local said = src:sub(sa, sb - 1)
local SHIP = {}
do
    local s0 = at("\nlocal S = {\n", 1, "the settings table")
    local s1 = at("\n}\n", s0, "the settings table's end")
    for line in src:sub(s0, s1):gmatch("[^\n]+") do
        local k, v = line:match("^%s+([%w_]+)%s*=%s*(-?[%d%.]+)%s*,")
        if k then SHIP[k] = tonumber(v) end
    end
end

local out = {}
local all = true
local function check(name, cond, more)
    cond = cond and true or false
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and more then out[#out + 1] = "       " .. tostring(more) end
    all = all and cond
    return cond
end
local function note(s) out[#out + 1] = "       " .. tostring(s) end

------------------------------------------------------------------- A: the settings and their ranges
local function spec(key)                                 -- the ini's row: lowest, highest, its text
    local lo, hi, txt = src:match('\n    { "' .. key .. '",%s*"num",%s*(-?[%d%.]+),%s*(-?[%d%.]+),%s*"([^\n]*)" },\n')
    return tonumber(lo), tonumber(hi), txt
end
local function menuRows(page)
    local m0 = at("\nNATIVE.MENU = {\n", 1, "the menu table")
    local m1 = at("\nNATIVE.menuRow = {}\n", m0, "the menu table's end")
    local menu = src:sub(m0, m1)
    local p0 = menu:find('\n    { "' .. page .. '", {\n', 1, true)
    if not p0 then return {} end
    local p1 = menu:find("\n    } },", p0, true) or #menu
    local rows = {}
    for line in menu:sub(p0, p1):gmatch("[^\n]+") do
        local kind, key, label, scale, step, desc, rest = line:match('^%s*{ "(%a+)", "([%w_]+)", "([^"]+)", (-?[%d%.]+), (-?[%d%.]+), "([^"]*)"(.*)}')
        if kind then
            local lo, hi = rest:match("^%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)")
            rows[#rows + 1] = { kind = kind, key = key, label = label, desc = desc, lo = tonumber(lo), hi = tonumber(hi), unit = rest:match('unit = "([^"]*)"'), scale = tonumber(scale), step = tonumber(step) }
            rows[key] = #rows
        end
    end
    return rows
end
do
    check("A: what ships has not moved: the body moves (GrabBoneMove 0), the hands stay on (GrabBoneHands 1), 25 deg of extra lean, nothing added for all (GrabAllBone 0)",
        SHIP.GrabBoneMove == 0 and SHIP.GrabBoneHands == 1 and SHIP.GrabBoneLean == 25 and SHIP.GrabAllBone == 0)
    check("[new] A: the two new settings ship as GrabBoneBehind 20 and GrabBoneShowStick 1", SHIP.GrabBoneBehind == 20 and SHIP.GrabBoneShowStick == 1,
        "GrabBoneBehind " .. tostring(SHIP.GrabBoneBehind) .. ", GrabBoneShowStick " .. tostring(SHIP.GrabBoneShowStick))
    local lo, hi = spec("GrabAllBone")
    check("[new] A: the ini takes GrabAllBone from -40 to 100 (it was 60)", lo == -40 and hi == 100, tostring(lo) .. " .. " .. tostring(hi))
    local blo, bhi = src:match('\n        { "Bone", "",%s*24,%s*(-?%d+),%s*(-?%d+),%s*15,')
    check("[new] A: every grab's own Bone<Grab> goes to 90 in the ini (it was 45: at least double)", tonumber(blo) == 0 and tonumber(bhi) == 90, tostring(blo) .. " .. " .. tostring(bhi))
    lo, hi = spec("GrabBoneBehind")
    check("[new] A: the ini has GrabBoneBehind, 0 to 45 (what the native half v114 takes)", lo == 0 and hi == 45, tostring(lo) .. " .. " .. tostring(hi))
    lo, hi = spec("GrabBoneShowStick")
    check("[new] A: the ini has GrabBoneShowStick, 0 or 1", lo == 0 and hi == 1, tostring(lo) .. " .. " .. tostring(hi))
    local rows = menuRows("Grabs")
    local ra, rb2 = rows[rows.GrabAllBone or 0], rows[rows.GrabBoneBehind or 0]
    check("A: the Grabs page has the slider 'All grabs: bone distance'", ra ~= nil and ra.kind == "slider" and ra.label == "All grabs: bone distance")
    check("[new] A: ...and it runs from -20 to 80 cm (its top was 40: 'double the limit or more')", ra ~= nil and ra.lo == -20 and ra.hi == 80 and ra.unit == "cm", ra and (tostring(ra.lo) .. " .. " .. tostring(ra.hi)))
    check("[new] A: ...and its text names the row that decides how far the board really goes", ra ~= nil and ra.desc:find("How far the board really goes is held by Boned grabs: how far out.", 1, true) ~= nil, ra and ra.desc)
    check("[new] A: the new row 'Boned grabs: how far out' (GrabBoneBehind) stands directly under it, 0 to 45 cm in steps of 5",
        rb2 ~= nil and rows.GrabBoneBehind == (rows.GrabAllBone or -9) + 1 and rb2.kind == "slider" and rb2.label == "Boned grabs: how far out" and rb2.lo == 0 and rb2.hi == 45 and rb2.step == 5 and rb2.unit == "cm",
        "row " .. tostring(rows.GrabBoneBehind) .. " (the slider is row " .. tostring(rows.GrabAllBone) .. ")")
    local function fits(r) local def = SHIP[r.key] return def ~= nil and #(r.desc .. " Default: " .. string.format("%.0f", def * r.scale) .. " " .. (r.unit or "") .. ".") <= 239 and not r.desc:find("[^\32-\126]") end
    check("A: the slider's text fits the native half's 239 characters with its default, plain ASCII", ra ~= nil and fits(ra))
    check("[new] A: ...and so does the new row's", rb2 ~= nil and fits(rb2))
    check("A: the page stays inside the native half's 48 rows", #rows <= 48, #rows .. " rows")
    note("the Grabs page: " .. #rows .. " rows")
end

------------------------------------------------------------------- B: on its way to the native half
local function handsWorld(o)
    o = o or {}
    local W = { calls = {}, grab = {}, logs = {} }
    local S = {}
    for k, v in pairs(SHIP) do S[k] = v end
    S.BoneMelon, S.HandMelonAlong = 15, 2
    for k, v in pairs(o.S or {}) do S[k] = v end
    W.S = S
    local env = setmetatable({}, { __index = _G })
    env.HJN_GrabSet = function(id, i, v) W.grab[#W.grab + 1] = { id, i, v } end
    env.HJN_GrabSetSw = function() end
    env.HJN_Set = function(k, v)
        W.calls[#W.calls + 1] = { k, v }
        if o.oldNative and (k == "bonebehind") then return 0 end          -- (a key a v113 native half does not know)
        return 1
    end
    local NATIVE = { v = o.v or 114, GRABS = { { "Melon", 2 } }, PARAMS = { { "Bone", "", 5 }, { "Hand", "Along", 0 } } }
    W.NATIVE = assert(load("local NATIVE, S = ...\n" .. hands .. "\nreturn NATIVE", "=hands", "t", env))(NATIVE, S)
    W.GR = assert(load("local GR, S, NATIVE, log = ...\n" .. said .. "\nreturn GR", "=said", "t", env))({ dbl = o.dbl }, S, NATIVE, function(s) W.logs[#W.logs + 1] = tostring(s) end)
    W.last = function(k) local v, n = nil, 0 for _, c in ipairs(W.calls) do if c[1] == k then v, n = c[2], n + 1 end end return v, n end
    return W
end
do local W = handsWorld({})
    W.NATIVE.hands()
    local v, n = W.last("bonebehind")
    check("[new] B: the first push tells the native half 'bonebehind' 20, once, beside the three of build 211", v == 20 and n == 1 and W.last("boneboard") == 0 and W.last("bonehands") == 1 and W.last("boneleanadd") == 25,
        "bonebehind " .. tostring(v) .. " x " .. tostring(n))
    local cnt = #W.calls
    W.NATIVE.hands()
    check("B: nothing changed: nothing is sent again", #W.calls == cnt)
    W.S.GrabBoneBehind = 40 W.NATIVE.hands()
    v, n = W.last("bonebehind")
    check("[new] B: 'Boned grabs: how far out' set to 40 (the menu or the ini): sent at the next push", v == 40 and n == 2, "bonebehind " .. tostring(v) .. " x " .. tostring(n))
    cnt = #W.calls
    W.NATIVE.hands()
    check("B: ...and nothing more until a change", #W.calls == cnt)
    W.S.GrabAllBone = 80 W.NATIVE.hands()
    check("B: the slider at its new top (80): the Melon's bone goes over as 15 + 80 = 95 cm asked", W.grab[#W.grab - 1] ~= nil and W.grab[#W.grab - 1][3] == 95, W.grab[#W.grab - 1] and W.grab[#W.grab - 1][3])
end
do local W = handsWorld({ oldNative = true, v = 113 })
    local ok = pcall(W.NATIVE.hands)
    check("B: a native half that does not know 'bonebehind' (v113): no error, the rest is still sent", ok and W.last("curltip") ~= nil and W.last("boneleanadd") == 25) end

------------------------------------------------------------------- C: the boned grab's own line
local function line(o, cm)
    local W = handsWorld(o)
    W.GR.boneSet(1, o.dbl and o.dbl[3] or "Indy Grab", cm or 55, 7.5)
    return W.logs[1] or "", W
end
do
    local l = line({ v = 113 })
    check("C: a native half v113: the line is build 211's to the letter (nothing about how far out)",
        l:find("(GrabBoneMove 0): 55 cm at the full swing; the hands stay on their spots: the back may lean 25 deg further", 1, true) ~= nil and not l:find("GrabBoneBehind", 1, true), l)
    l = line({})
    check("[new] C: v114, as shipped: '55 cm at the full swing, and no further than where the hips are 20 cm behind the back foot's place (GrabBoneBehind)'",
        l:find("55 cm at the full swing, and no further than where the hips are 20 cm behind the back foot's place (GrabBoneBehind), the front leg is straight or a hand would come off; the hands stay on their spots", 1, true) ~= nil, l)
    note(l)
    l = line({ S = { GrabBoneBehind = 0 } })
    check("[new] C: with GrabBoneBehind 0 it says build 211's stop: the hips over the back foot's place", l:find("no further than where the hips are over the back foot's place (GrabBoneBehind 0) or a hand would come off; the hands stay", 1, true) ~= nil, l)
    l = line({ S = { GrabBoneMove = 1 } })
    check("[new] C: with Bone moves 1 the BOARD is named as before, and the same stop after the distance",
        l:find("-- the BOARD is pushed out toward the nose and the body stays (GrabBoneMove 1;", 1, true) ~= nil and l:find("55 cm at the full swing, and no further than where the hips are 20 cm behind", 1, true) ~= nil, l)
    l = line({ dbl = { "TruckDriver", 203, "Truck Driver" } })
    check("[new] C: a two-hand grab while the BODY moves: it is told that it keeps the old stop",
        l:find("the Truck Driver is boned", 1, true) ~= nil and l:find("no further than where the hips are over the back foot's place (two hands get GrabBoneBehind only where the board is what moves)", 1, true) ~= nil, l)
    l = line({ dbl = { "TruckDriver", 203, "Truck Driver" }, S = { GrabBoneMove = 1 } })
    check("[new] C: a two-hand grab with Bone moves 1: 20 cm behind, only while the board is what moves",
        l:find("20 cm behind the back foot's place (GrabBoneBehind; two hands: only while the board is what moves)", 1, true) ~= nil, l)
    note(l)
    l = line({ S = { GrabBoneHands = 0 } })
    check("C: with GrabBoneHands 0 (the native half's v112 bone) nothing is claimed about how far out", l:find("55 cm at the full swing; the hands as before build 211 (GrabBoneHands 0)", 1, true) ~= nil, l)
    l = line({}, 113)
    check("[new] C: more asked than is ever moved (the slider at 80 + a Truck Driver's 33): '80 cm is the most that is ever moved'",
        l:find("113 cm at the full swing, and no further than", 1, true) ~= nil and l:find("; 80 cm is the most that is ever moved; the hands stay", 1, true) ~= nil, l)
    l = line({}, 80)
    check("C: ...and not said at 80 or under", not l:find("is ever moved", 1, true), l)
end

------------------------------------------------------------------- D: the centred pick
local NAME = { [1] = "Nose", [2] = "Melon", [3] = "Mute", [4] = "Chicken Salad", [5] = "Taipan", [6] = "Seatbelt",
               [100] = "Tail", [101] = "Stalefish", [102] = "Indy", [103] = "Roast Beef", [104] = "Canadian Bacon", [105] = "Crail" }
local GRAB_ID = {} for id, n in pairs(NAME) do GRAB_ID[n:lower():gsub("[%s_%-]", "")] = id end
local MODE_AIR = 3
local function world(o)
    local W = { logs = {}, sets = {}, nat = {}, t = 100, dt = 1 / 60, mode = 2, switch = false, goofy = false, bumpers = 3, L = { 0, 0 }, R = { 0, 0 }, game = 0,
                cstate = 0, refuse = 0, fresh = 0, nudges = 0, hist = {}, v = 114 }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    env.NAT = setmetatable({}, { __index = function(_, k) if k == "switch" then return W.switch elseif k == "goofy" then return W.goofy elseif k == "mirror" then return W.goofy end end })
    env.HJN_Bumpers = function() return W.bumpers end
    env.HJN_Set = function(k, v) W.nat[k] = v end
    env.HJN_CatchState = function() return W.nudged and 2 or W.cstate end      -- (the mod's own SetCatchOrient reads as 2 until the game's next tick)
    env.HJN_CatchOrient = function() W.nudged, W.nudges = true, W.nudges + 1 end
    local SV = { GrabLBNeutral = "Mute", GrabRBNeutral = "Indy", GrabFollowStickMode = 1, GrabToeSide = 1, GrabWait = 0.12, GrabRepick = 0.35,
        DoubleGrabs = 1, GrabStart = 1, DoubleBothSticks = 1, GrabTweakStyle = 1, GrabTweakGate = 1, GrabTweakDead = 20, GrabTweakRamp = 40, GrabTweakMaxTurn = 45, GrabTweakInvert = 0,
        BoneNose = 0, BoneMelon = 15, BoneMute = 15, BoneTail = 0, BoneStalefish = 15, BoneIndy = 15, BoneCrail = 0, BoneCannonball = 0, BoneRocket = 0,
        DoubleCannonball = "Nose+Tail", DoubleGorilla = "Mute+Indy", DoubleRocket = "Nose+Crail",
        DoubleTruckDriver = "Melon+Indy", DoubleDrunkDriver = "Mute+Stalefish", DoubleSquirrel = "Melon+Stalefish",
        DoubleCannonballBase = "Indy", DoubleGorillaBase = "Indy", DoubleRocketBase = "Nose",
        DoubleTruckDriverBase = "Indy", DoubleDrunkDriverBase = "Indy", DoubleSquirrelBase = "Indy",
        BoneGorilla = 18, BoneTruckDriver = 18, BoneDrunkDriver = 18, BoneSquirrel = 18, NativeCatchHold = 1,
        -- the bone's own settings as the file ships them
        GrabAllBone = SHIP.GrabAllBone, GrabBoneMove = SHIP.GrabBoneMove, GrabBoneHands = SHIP.GrabBoneHands, GrabBoneLean = SHIP.GrabBoneLean,
        GrabBoneBehind = SHIP.GrabBoneBehind, GrabBoneShowStick = SHIP.GrabBoneShowStick }
    for k, v in pairs(W.S or {}) do SV[k] = v end
    W.SV = SV
    local GR = { blocked = function() return false end, kicks = 0, turnName = function(n) return n end, catchTries = 0,
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
    local log = function(s) W.logs[#W.logs + 1] = tostring(s) end
    local chunk = "local GR, S, GRAB_ID, SB, alive, q, s0, log, logOnce, NATIVE, stickNow, analogStick, grabSet, grabTitle, MODE_AIR, inst, visualGoofy, trickNameLater, trickNameHide, AS = ...\n"
        .. body .. "\nreturn GR"
    W.GR = assert(load(chunk, "=bone212", "t", env))(GR, SV, GRAB_ID, {}, function(x) return x end, q, s0, log, function() end,
        { v = W.v, grab = function() return true end, GRABS = { { "Nose", 1 }, { "Melon", 2 }, { "Mute", 3 }, { "Tail", 100 }, { "Stalefish", 101 }, { "Indy", 102 }, { "Crail", 105 },
            { "Cannonball", 200 }, { "Gorilla", 201 }, { "Rocket", 202 }, { "TruckDriver", 203 }, { "DrunkDriver", 204 }, { "Squirrel", 205 } } },
        stickNow, analogStick, grabSet, grabTitle, MODE_AIR, { IsGrinding = false },
        function() return W.goofy end, function() end, function() end, { mode = "named" })
    local resetFn = assert(load("local GR = ...\n" .. resets, "=resets", "t", env))
    local nudgeFn = assert(load("local GR, S, native, now = ...\n" .. nudge, "=nudge", "t", env))
    local function pushed(x, y) return math.abs(x or 0) > 0.3 or math.abs(y or 0) > 0.3 end
    -- THE MODEL of the game's catch (the head of this file): it reads what it was shown on the tick before
    local function gameTick()
        local sh = W.shown or { LX = W.L[1], LY = W.L[2], RX = W.R[1], RY = -W.R[2] }
        local l, r = pushed(sh.LX, sh.LY), pushed(sh.RX, sh.RY)
        local can = W.cstate ~= 0
        if not can and ((l and not W.wasL) or (r and not W.wasR)) then
            W.fresh = W.fresh + 1
            if W.refuse > 0 then W.refuse = W.refuse - 1 else can = true end
        end
        W.cstate = can and ((l and r) and 5 or (l and 1) or (r and 2) or 0) or 0
        W.wasL, W.wasR, W.nudged = l, r, false
    end
    -- some frames go by; -> the two-hand grab's display name, or "none"
    W.run = function(sec)
        local n = math.max(1, math.floor(sec / W.dt + 0.5))
        for _ = 1, n do
            W.t = W.t + W.dt
            gameTick()
            W.sim = { LX = W.L[1], LY = W.L[2], RX = W.R[1], RY = -W.R[2] }      -- the real sticks, unless the gate writes over them
            W.game = W.GR.doubleTick(W.t, W.game, MODE_AIR) or W.game
            if W.game ~= W.gnat then                             -- (as the grab tick has it: a grab begins -- the sticks as they stand are the gate's)
                W.gnat = W.game
                if W.game ~= 0 then
                    local function g(v) return { v[1], v[2], math.sqrt(v[1] * v[1] + v[2] * v[2]), math.deg(math.atan(v[2], v[1])) } end
                    W.GR.nativeT0, W.GR.gate = W.t, { Left = g(W.L), Right = g(W.R) }
                    resetFn(W.GR)
                    W.t0 = W.t
                else W.GR.gate = nil end
            end
            nudgeFn(W.GR, SV, W.game, W.t)
            local wasNudge = W.nudged
            if W.game == 0 and (W.GR.boneNow or 0) ~= 0 then W.GR.boneSet(0) end
            local nl = #W.logs
            W.GR.tweak(W.t, W.game)
            W.shown = W.sim
            local saidNow = false                                -- (a line about the centred pick was written on this tick)
            for i = nl + 1, #W.logs do if W.logs[i]:find("   tweak gate: the ", 1, true) and W.logs[i]:find("picked with the stick centred", 1, true) or W.logs[i]:find("   tweak gate: ...the ", 1, true) then saidNow = true end end
            W.hist[#W.hist + 1] = { t = W.t, LX = W.sim.LX, LY = W.sim.LY, RX = W.sim.RX, RY = W.sim.RY, cs = W.cstate, grab = W.game, nudge = wasNudge, said = saidNow }
        end
        return W.GR.dbl and W.GR.dbl[3] or "none"
    end
    -- the ticks of the grab now held on which the game was shown the right / left stick centred, after its first
    W.centredTicks = function(key)
        local ts, first = {}, true
        for _, h in ipairs(W.hist) do
            if h.grab ~= 0 and h.t >= (W.t0 or 0) then
                if not first and h[key] == 0 then ts[#ts + 1] = h.t end
                first = false
            end
        end
        return ts
    end
    W.lines = function(piece) local n, last = 0, nil for _, l in ipairs(W.logs) do if tostring(l):find(piece, 1, true) then n, last = n + 1, l end end return n, last end
    W.at = function(i) return W.hist[i] or {} end
    return W
end
local LEFT, RIGHT, UP, MID = { -1, 0 }, { 1, 0 }, { 0, 1 }, { 0, 0 }
local BOARD = { GrabBoneMove = 1 }                       -- the tester's own setting: "Bone moves" 1
local function with(t) local r = {} for k, v in pairs(BOARD) do r[k] = v end for k, v in pairs(t or {}) do r[k] = v end return r end
-- an Indy picked with RB and no stick (the Indy of 09:46:21): the game holds 102, the right stick centred
local function indy(o) o = o or {} o.bumpers, o.R, o.L = 2, o.R or MID, o.L or MID local W = world(o) W.game = 102 return W end

do local W = indy({})                                    -- as the file ships: Bone moves 0
    W.run(0.5)
    local shownOff = false for _, h in ipairs(W.hist) do if h.RX ~= 0 or h.RY ~= 0 or h.LX ~= 0 or h.LY ~= 0 then shownOff = true end end
    check("D: as shipped (Bone moves 0) an Indy picked with no stick is shown centred, as build 211 showed it", not shownOff and W.lines("picked with the stick centred") == 0)
end
do local W = indy({ S = with() })                        -- Bone moves 1: the board is what a bone moves
    W.run(1 / 60)
    local h = W.at(1)
    check("[new] D: Bone moves 1 -- from the grab's first tick the game is shown the right stick pushed straight (X 0, Y -1 as the right stick is sent)", h.RX == 0 and h.RY == -1,
        "shown R " .. tostring(h.RX) .. "," .. tostring(h.RY))
    check("D: ...and the left stick, not this grab's, as it is: centred", h.LX == 0 and h.LY == 0)
    W.run(0.6)
    check("[new] D: the model's game takes its catch from that push: state 2 (right stick alone) from the next tick on, to the end", W.at(2).cs == 2 and W.cstate == 2 and W.fresh == 1,
        "state " .. tostring(W.cstate) .. ", fresh pushes " .. tostring(W.fresh))
    check("[new] D: ...and with a catch the stick is never dropped: no tick centred, no more pushes", #W.centredTicks("RY") == 0 and (W.GR.stickTries or 0) == 0 and W.GR.stickShown ~= nil)
    local n, l = W.lines("picked with the stick centred")
    check("[new] D: said once, 0.3 s in: '...the game is shown it pushed straight so that it has its catch (GrabBoneShowStick 1): catch-orient state 2 after 0.3 s (0 more pushes)'",
        n == 1 and l:find("tweak gate: the Indy Grab was picked with the stick centred -- the game is shown it pushed straight so that it has its catch (GrabBoneShowStick 1): catch-orient state 2 after 0.3 s (0 more pushes)", 1, true) ~= nil
        and W.lines("tweak gate: ...the") == 0, l)
    if l then note(l) end
    check("D: no bone yet: the real stick has not moved", (W.nat.bone or 0) == 0)
    W.R = RIGHT W.run(0.05)
    check("[new] D: the real stick pushed now is the bone (as for every centred pick), the game still shown the straight one", W.nat.bone == 1 and W.sim.RX == 0 and W.sim.RY == -1,
        "bone " .. tostring(W.nat.bone) .. ", shown R " .. tostring(W.sim.RX) .. "," .. tostring(W.sim.RY))
end
do local W = indy({ S = with(), refuse = 1 })            -- the game's other conditions fail on the first push
    W.run(0.7)
    local ts = W.centredTicks("RY")
    check("[new] D: the first push refused -- 0.15 s on the stick is shown centred for ONE tick, then pushed again", #ts == 1 and ts[1] - W.t0 > 0.15 and ts[1] - W.t0 < 0.25 and W.GR.stickTries == 1,
        #ts .. " centred ticks" .. (ts[1] and string.format(", the first %.3f s in", ts[1] - W.t0) or "") .. ", tries " .. tostring(W.GR.stickTries))
    check("[new] D: ...and that second push is a fresh one to the game: it has its catch (state 2) and keeps it", W.cstate == 2 and W.fresh == 2, "state " .. tostring(W.cstate) .. ", fresh pushes " .. tostring(W.fresh))
    local n, l = W.lines("picked with the stick centred")
    check("[new] D: ...said with the count: 'catch-orient state 2 after 0.3 s (1 more pushes)', and no second line", n == 1 and l:find("catch-orient state 2 after 0.3 s (1 more pushes)", 1, true) ~= nil and W.lines("tweak gate: ...the") == 0, l)
end
do local W = indy({ S = with(), refuse = 2 })            -- ...and on the second: the catch comes after the first line
    W.run(0.9)
    local n, l = W.lines("picked with the stick centred")
    local n2, l2 = W.lines("tweak gate: ...the Indy Grab has its catch now: catch-orient state 2,")
    check("[new] D: two pushes refused -- the first line reads state 0 after 0.3 s, a second says when the catch came: '...has its catch now: catch-orient state 2, ... 2 more pushes'",
        n == 1 and l:find("catch-orient state 0 after 0.3 s (1 more pushes)", 1, true) ~= nil and n2 == 1 and l2:find(", 2 more pushes", 1, true) ~= nil and W.cstate == 2 and W.GR.stickTries == 2, tostring(l) .. " | " .. tostring(l2))
    if l2 then note(l2) end
end
do local W = indy({ S = with(), refuse = 99 })           -- the game never takes one
    W.run(1.5)
    local ts = W.centredTicks("RY")
    local apart = true for i = 2, #ts do if ts[i] - ts[i - 1] <= 0.15 then apart = false end end
    check("[new] D: the game never takes a catch -- three more pushes and no fourth: 3 single ticks centred, each more than 0.15 s after the last", #ts == 3 and apart and W.GR.stickTries == 3 and W.fresh == 4,
        #ts .. " centred ticks, tries " .. tostring(W.GR.stickTries) .. ", fresh pushes seen " .. tostring(W.fresh))
    local n, l = W.lines("picked with the stick centred")
    local n2, l2 = W.lines("tweak gate: ...the Indy Grab never had a catch: catch-orient state 0 after 3 more pushes")
    check("[new] D: ...said: state 0 after 0.3 s, then once '...never had a catch: catch-orient state 0 after 3 more pushes -- ... the body is what bones this grab'",
        n == 1 and l:find("catch-orient state 0 after 0.3 s", 1, true) ~= nil and n2 == 1 and l2:find("the body is what bones this grab", 1, true) ~= nil and W.lines("has its catch now") == 0, tostring(l) .. " | " .. tostring(l2))
    if l2 then note(l2) end
    check("D: the mod's own nudge (v118) ran beside it as the grab tick has it: three times", W.nudges == 3, W.nudges .. " nudges")
    -- the grab ends, the next one begins: its own three pushes, its own line
    W.game, W.bumpers = 0, 0 W.run(0.2)
    W.game, W.bumpers, W.refuse = 102, 2, 0 W.run(0.5)
    check("[new] D: the next grab starts clean: shown pushed again from its first tick, its own count (0), its own line", W.GR.stickTries == nil and W.cstate == 2 and select(1, W.lines("picked with the stick centred")) == 2,
        "tries " .. tostring(W.GR.stickTries) .. ", state " .. tostring(W.cstate) .. ", lines " .. tostring((W.lines("picked with the stick centred"))))
end
do local W = indy({ S = with(), refuse = 99, dt = 0.04 }) -- 25 frames a second: the mod's third nudge falls on the very tick the line is due (0.32 s in)
    W.run(1.0)
    local n, l = W.lines("picked with the stick centred")
    local onNudge, dueOn = false, nil
    for _, h in ipairs(W.hist) do
        if h.said and h.nudge then onNudge = true end
        if not dueOn and h.t - W.t0 >= 0.3 - 1e-9 then dueOn = h end
    end
    check("D: (the stand-in at 25 frames a second: the first tick 0.3 s into the grab is one of the mod's own nudge, where the state reads 2)", dueOn ~= nil and dueOn.nudge == true and W.nudges == 3,
        dueOn and string.format("the first tick due is %.2f s in, nudge %s", dueOn.t - W.t0, tostring(dueOn.nudge)))
    check("[new] D: the mod's own nudge is not read as the game's catch: the line waits a tick and reads state 0, not the nudge's 2", n == 1 and l:find("catch-orient state 0 after 0.3 s", 1, true) ~= nil and not onNudge, l)
    local ts = W.centredTicks("RY")
    check("[new] D: ...nor is the stick dropped on a nudge's tick, and the three more pushes still come", #ts == 3 and W.GR.stickTries == 3, #ts .. " centred ticks, tries " .. tostring(W.GR.stickTries))
end
do local W = indy({ S = with({ GrabBoneShowStick = 0 }) }) W.run(0.5)
    check("D: GrabBoneShowStick 0 -- as build 211: shown centred, no catch, nothing said", W.at(1).RY == 0 and W.sim.RY == 0 and W.cstate == 0 and W.lines("picked with the stick centred") == 0 and W.GR.stickShown == nil) end
do local W = indy({ S = with({ GrabBoneHands = 0 }) }) W.run(0.5)
    check("D: GrabBoneHands 0 (the native half never moves the board then) -- as build 211: shown centred", W.at(1).RY == 0 and W.sim.RY == 0 and W.cstate == 0 and W.GR.stickShown == nil) end
do local W = indy({ S = with(), v = 112 }) W.run(0.5)
    check("D: a native half older than v113 (it has no board to move) -- shown centred", W.at(1).RY == 0 and W.sim.RY == 0 and W.GR.stickShown == nil) end
do local W = indy({ S = with({ GrabTweakStyle = 0 }) }) W.run(0.5)
    check("D: Grab tweak on ROTATE -- nothing is boned, the centred stick is shown as it is", W.at(1).RY == 0 and W.sim.RY == 0 and W.GR.stickShown == nil) end
do local W = world({ bumpers = 1, L = MID, S = with() })  -- a Nose grab has no bone of its own
    W.game = 1 W.GR.kick = { id = 1, at = W.t, bumper = "LB" } W.run(0.5)
    check("D: a grab without a bone (Nose) picked centred is shown as it is", W.at(1).LY == 0 and W.sim.LY == 0 and W.GR.stickShown == nil) end
do local W = world({ bumpers = 1, L = MID, S = with() })  -- a Mute by LB: the left stick is its own
    W.game = 3 W.GR.kick = { id = 3, at = W.t, bumper = "LB" } W.run(0.5)
    check("[new] D: a Mute picked with LB and no stick: the LEFT stick is shown pushed straight (X 0, Y +1), the right one stays centred -- state 1", W.sim.LX == 0 and W.sim.LY == 1 and W.sim.RX == 0 and W.sim.RY == 0 and W.cstate == 1,
        "shown L " .. tostring(W.sim.LX) .. "," .. tostring(W.sim.LY) .. " R " .. tostring(W.sim.RX) .. "," .. tostring(W.sim.RY) .. ", state " .. tostring(W.cstate))
    W.L = LEFT W.run(0.05)
    check("[new] D: ...and pushing the real stick bones it", W.nat.bone == 1 and W.sim.LX == 0 and W.sim.LY == 1)
end
do local W = indy({ S = with(), R = RIGHT })             -- an Indy picked WITH the stick: nothing changes for it
    W.run(0.6)
    check("D: a grab picked with the stick pushed is shown straight at its own deflection as before, never dropped, nothing said",
        W.sim.RX == 0 and W.sim.RY == -1 and #W.centredTicks("RY") == 0 and W.lines("picked with the stick centred") == 0 and W.GR.stickShown == nil and W.cstate == 2)
end
-- two hands
do local W = world({ L = MID, R = MID, S = with() })      -- a Gorilla picked with no stick (the Gorilla of 09:45:27)
    local name = W.run(0.6)
    check("[new] D: a Gorilla picked with no stick: BOTH sticks are shown pushed straight (left Y +1, right Y -1: opposite signs as sent) -- state 5", name == "Gorilla Grab" and W.sim.LX == 0 and W.sim.LY == 1 and W.sim.RX == 0 and W.sim.RY == -1 and W.cstate == 5,
        tostring(name) .. ": shown L " .. tostring(W.sim.LX) .. "," .. tostring(W.sim.LY) .. " R " .. tostring(W.sim.RX) .. "," .. tostring(W.sim.RY) .. ", state " .. tostring(W.cstate))
    local n, l = W.lines("picked with the stick centred")
    check("[new] D: ...said under the pair's own name", n == 1 and l:find("the Gorilla Grab was picked with the stick centred", 1, true) ~= nil, l)
end
do local W = world({ L = MID, R = MID, S = with(), refuse = 1 })
    W.run(0.7)
    local tl, tr = W.centredTicks("LY"), W.centredTicks("RY")
    local together = #tr == 1 and #tl == 1 and tl[1] == tr[1]
    check("[new] D: a no-stick Gorilla whose first push is refused: both sticks drop on the SAME single tick, and the pair has its catch after (state 5)", together and W.cstate == 5 and W.GR.stickTries == 1,
        #tl .. " / " .. #tr .. " centred ticks, state " .. tostring(W.cstate) .. ", tries " .. tostring(W.GR.stickTries))
end
do local W = world({ L = LEFT, R = MID, S = with() })     -- a Gorilla by the both-sticks rule: one stick pushed at the pick
    local name = W.run(0.6)
    check("D: a pair picked with ONE stick pushed: that one is shown straight as before, the centred one is NOT shown pushed (the game has the first one's catch)",
        name == "Gorilla Grab" and W.sim.LX == 0 and W.sim.LY == 1 and W.sim.RX == 0 and W.sim.RY == 0 and W.GR.stickShown == nil and W.cstate == 1,
        tostring(name) .. ": shown L " .. tostring(W.sim.LX) .. "," .. tostring(W.sim.LY) .. " R " .. tostring(W.sim.RX) .. "," .. tostring(W.sim.RY) .. ", state " .. tostring(W.cstate))
end
do local W = world({ L = MID, R = MID, S = with() })      -- a no-stick Gorilla turned into a Truck Driver inside GrabRepick
    W.run(0.2)
    local was = W.GR.stickShown
    W.L, W.R = LEFT, RIGHT
    local name = W.run(0.05)
    check("[new] D: a no-stick Gorilla (its sticks shown pushed)...", W.GR.dbl ~= nil and was ~= nil)
    W.run(0.6)
    check("D: ...turned into a Truck Driver by both sticks inside GrabRepick: it is a stick-picked pair now -- no stamp kept, no 'picked with the stick centred' line, shown straight",
        name == "Truck Driver" and W.GR.stickShown == nil and W.lines("picked with the stick centred") == 0 and W.sim.LX == 0 and W.sim.LY == 1 and W.sim.RX == 0 and W.sim.RY == -1, tostring(name))
end

local o = assert(io.open("bone212_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("build 212's bone test failed: see bone212_out.txt", 0) end

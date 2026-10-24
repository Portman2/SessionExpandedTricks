-- test_cave233.lua (builds 226-233, mk226.pl / mk227c.pl / mk228c.pl / mk230c.pl / mkc_lua.pl): THE CAVEMAN. Y on foot in the air with the board in the hand
-- arms the native half's HJN_Cave (the board drawn from the hand to under the feet before the game's own mount, 0.217 s
-- after the press); a second Y inside that window is the game's switch mount (the board drawn the other way round); on
-- the first frame on the board the fall's speed is given back (the game's mount sets it to 0), the trick is named, and
-- (227) the hand that carried the board holds it -- (230) its middle grab: the Melon with the front hand, the Indy with the back --
-- with the rolling grab's crouch (HJN_Bone), (228) until CavemanLetGo before touchdown (the time to the ground from the
-- height over it and the fall), CavemanGrab at most; the game's "riding" in the first frames after the mount is not the landing.
-- NATIVE.caveTry / caveSwitch / caveTick are cut out of main.lua and run in real Lua against stand-ins.
-- (233) the arm sends CavemanTurn (the body's turn into the stance in the air, native v131) as its 6th number; a second Y's
-- line says what native v131 does with it (2: the board keeps its way, the body and the feet go round) or an older one (1).
-- luareal -run test_cave233.lua result.txt main.lua   (writes cave233_out.txt)
-- Run on build 229 the suite fails as a whole: no Melon / Indy (CavemanHold is not there). On build 232: no CavemanTurn (S, A, E fail).
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("\n    NATIVE.caveTry = function(vel)", 1, true), "NATIVE.caveTry was not found (build 225?)")
local b = assert(src:find("\n    -- Y / triangle\n    NATIVE.dropKey = function()", a, true), "the end of the caveman's functions was not found")
local body = src:sub(a + 1, b)
assert(body:find("HJN_Cave(\"ground\")", 1, true), "the caveman's let-go before touchdown is not there (build 227?)")
assert(src:find("CavemanHold = 0.6", 1, true), "the caveman's Melon / Indy and its renamed keys are not there (build 229?)")

local out, all = {}, true
local function check(name, cond, W)
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        for _, c in ipairs(W.cave) do out[#out + 1] = "       HJN_Cave(" .. table.concat(c, ", ") .. ")" end
        for _, c in ipairs(W.bones) do out[#out + 1] = "       HJN_Bone(" .. table.concat(c, ", ") .. ")" end
        for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l:sub(1, 300) end
    end
    return cond
end

local function world(opt)
    local W = { logs = {}, cave = {}, kicks = {}, bones = {}, sets = {}, names = {}, t = 50.0, onBoard = false, state = 0x50, arm = "ok 0.450 120 30",
        g = -1127, vz = 0, partsHeld = 0, z = 1000, mode = 2, caveState = "0 1 1 0", noseLeft = true, h = 100 }
    for k, v in pairs(opt or {}) do W[k] = v end
    local env = { ipairs = ipairs, pairs = pairs, next = next, tonumber = tonumber, tostring = tostring, type = type, pcall = pcall, setmetatable = setmetatable, select = select,
        string = string, table = table, math = math, os = { clock = function() return W.t end } }
    env.HJN_Cave = function(op, ...) local r = { op } for _, v in ipairs({ ... }) do r[#r + 1] = tostring(v) end W.cave[#W.cave + 1] = r
        if op == "arm" then return W.arm elseif op == "switch" then return (W.swAns == nil) and 2 or W.swAns elseif op == "state" then return W.caveState elseif op == "ground" then return W.h end return 1 end
    env.HJN_BoardState = function() return W.state end
    env.HJN_BoardParts = function(...) local n = select("#", ...) W.partsHeld = n return n end
    env.HJN_BoardKick = function(x, y, z, s, ox, oy) W.kicks[#W.kicks + 1] = { x, y, z, s, ox, oy } return 7 end
    env.HJN_Bone = function(s, side, kind, crouch) W.bones[#W.bones + 1] = { tostring(s), tostring(side), tostring(kind), tostring(crouch) } return "5 3.5 1.00 22 30" end
    env.HJN_Set = function(k, v) W.sets[k] = v return 1 end
    local S = { Caveman = (W.caveman == nil) and 1 or W.caveman, CavemanTime = 200, CavemanOut = 28, CavemanLift = 14, CavemanTurn = (W.turn == nil) and 0.75 or W.turn, CavemanKeepFall = (W.keep == nil) and 1 or W.keep,
        CavemanHold = (W.grab == nil) and 0.6 or W.grab, CavemanSquat = 40, CavemanLetGo = 0.1, GroundGrabHips = 56, GroundGrabBack = 18, GroundGrabSplay = 0.45,
        GroundGrabFrontAlong = 30, GroundGrabBackAlong = -18, NoComplyPlantFlex = 85, GroundGrabLean = 55 }
    local NATIVE = { boardParts = function() return { "deck", "w1", "w2" } end, grabLeftHand = function(id) return (id == 2) == W.noseLeft end }
    local prelude = [[
local NATIVE, S, W = ...
local MODE_AIR = 2
local function log(s) W.logs[#W.logs + 1] = tostring(s) end
local function q(fn, dflt) local ok, v = pcall(fn) if ok and v ~= nil then return v end return dflt end
local function modeNow() return W.mode end
local function trickNameLater(s) W.names[#W.names + 1] = s end
local mv = { GetGravityZ = function() return W.g end }
mv.Velocity = setmetatable({}, { __index = function(_, k) return (k == "Z") and W.vzNow or 0 end })
local s0 = { IsOnBoard = function() return W.onBoard end, K2_GetActorLocation = function() return { X = 0, Y = 0, Z = W.z } end }
]]
    local chunk = prelude .. body .. "\nreturn NATIVE\n"
    W.N = assert(load(chunk, "=cave", "t", env))(NATIVE, S, W)
    return W
end
local vel = { X = 300, Y = 400, Z = 150 }
local function near(a, b, e) return math.abs(a - b) <= (e or 0.5) end
local function lastLog(W, pat) for i = #W.logs, 1, -1 do if W.logs[i]:find(pat) then return W.logs[i] end end end
-- run frames of dt until the clock has moved by `span`
local function frames(W, span, dt) local t1 = W.t + span while W.t < t1 - 1e-9 do W.t = W.t + (dt or 1 / 60) W.N.caveTick() end end

-- A. the board in the hand, in the air: armed; the press time taken from the native half's own (30 ms ago)
do local W = world()
    W.N.caveTry(vel)
    local c = W.cave[1]
    all = check("A: HJN_Cave('arm', 200, vz 150, g 1127, 28, 14, CavemanTurn 0.75) (" .. (c and table.concat(c, ",") or "none") .. ")",
        c and c[1] == "arm" and c[2] == "200" and c[3] == "150" and c[4] == "1127" and c[5] == "28" and c[6] == "14" and c[7] == "0.75" and #c == 7, W) and all
    all = check("A: ...armed, Y counted 30 ms back", W.N.cave ~= nil and near(W.N.cave.at, 49.97, 1e-6) and W.N.cave.vz == 150, W) and all
end
-- B. not in the hand (on the board / lying loose / thrown): HJN_Cave is not asked
for _, st in ipairs({ 0x14, 0x81, 0x60 }) do
    local W = world({ state = st })
    W.N.caveTry(vel)
    all = check(string.format("B: board state 0x%02x: not asked", st), #W.cave == 0 and W.N.cave == nil, W) and all
end
-- C. the native half says no (landing before the game's mount): nothing armed, said why
do local W = world({ arm = "no you land in 180 ms and the game puts you on the board in 190: that is its throwdown on the ground (40 cm over the ground)" })
    W.N.caveTry(vel)
    all = check("C: refused: nothing armed, the reason in the log", W.N.cave == nil and W.logs[1] and W.logs[1]:find("not this time %-%- you land in 180 ms") ~= nil, W) and all
end
-- D. Caveman=0: not asked
do local W = world({ caveman = 0 })
    W.N.caveTry(vel)
    all = check("D: Caveman=0: not asked", #W.cave == 0 and W.N.cave == nil, W) and all
end
-- E. a second Y inside the game's window: switch, once; after the window: not ours
do local W = world()
    W.N.caveTry(vel)
    W.t = W.t + 0.1
    local s1 = W.N.caveSwitch(W.t)
    local s2 = W.N.caveSwitch(W.t + 0.01)
    all = check("E: second Y at 130 ms: switch asked once (" .. tostring(s1) .. ", " .. tostring(s2) .. ")", s1 == true and s2 == false and W.cave[2] and W.cave[2][1] == "switch" and #W.cave == 2, W) and all
end
do local W = world()
    W.N.caveTry(vel)
    W.t = W.t + 0.25
    all = check("E: a Y 280 ms after the first is not the switch tap", W.N.caveSwitch(W.t) == false and #W.cave == 1, W) and all
end
do local W = world()
    all = check("E: no caveman on: caveSwitch says no", W.N.caveSwitch(W.t) == false and #W.cave == 0, W) and all
end
-- F. the mount: the fall's speed given back (vz at the press 150 up, 230 ms later: 150 - 1127 * 0.23 = -109), the name,
--    the read-back from the skater's own height, then the nose grab for 0.2 s with the front (left) hand
do local W = world()
    W.N.caveTry(vel)
    W.t = W.t + 0.1 W.N.caveTick()
    local before = #W.kicks
    W.t = W.t + 0.1 W.onBoard = true W.N.caveTick()
    local k = W.kicks[1]
    all = check("F: nothing kicked before the mount", before == 0, W) and all
    all = check("F: on the board: kicked once with your speed along and the fall's (" .. (k and string.format("%.0f %.0f %.1f", k[1], k[2], k[3]) or "none") .. ")",
        #W.kicks == 1 and k[1] == 300 and k[2] == 400 and near(k[3], 150 - 1127 * 0.23, 0.6) and k[4] == 0 and near(k[5], 0.6, 1e-6) and near(k[6], 0.8, 1e-6) and W.partsHeld == 0, W) and all
    all = check("F: the trick is named Caveman", W.names[1] == "Caveman", W) and all
    all = check("F: the rolling grab's crouch numbers handed over", W.sets.bonehips == 56 and W.sets.bonelean == 55 and W.sets.bonealongb == -18, W) and all
    all = check("F: the grab comes in fast (bonefast for the hold + 0.2 s)", W.sets.bonefast and math.abs(W.sets.bonefast - 0.8) < 1e-6, W) and all
    -- the game says "riding" for the first frames after an in-air mount (the board's mode 1, then 3): not the landing
    W.mode = 1
    frames(W, 0.066)
    all = check("F: the game's 'riding' in the first 66 ms after the mount: still holding", #W.bones >= 3 and W.bones[#W.bones][1] ~= "0" and W.N.cave and W.N.cave.grabUntil ~= nil, W) and all
    W.mode = 2
    W.z = 989
    frames(W, 0.05)
    local rb = tonumber((lastLog(W, "after the mount you move") or ""):match("move (%S+) cm/s"))
    all = check("F: the fall read back from the skater's height 0.1 s on (" .. tostring(rb) .. " cm/s, about -100)", rb and rb <= -88 and rb >= -115, W) and all
    local b1 = W.bones[1]
    all = check("F: the left (front) hand: the Melon, with the crouch (" .. (b1 and table.concat(b1, ",") or "none") .. ")", b1 and b1[2] == "0" and b1[3] == "2" and b1[4] == "40", W) and all
    -- high over the ground and not falling: it holds on past the old 0.2 s
    frames(W, 0.2)
    all = check("F: 100 cm over the ground, not falling: still holding at 0.32 s", W.N.cave and W.N.cave.grabUntil ~= nil and W.bones[#W.bones][1] ~= "0", W) and all
    -- now 15 cm over it falling at 300 cm/s: the ground in about 0.05 s, under CavemanLetGo 0.1 -> let go
    W.h = 15
    local nb = #W.bones
    for _ = 1, 3 do W.t = W.t + 1 / 60 W.z = W.z - 5 W.N.caveTick() end
    local lastB = W.bones[#W.bones]
    all = check("F: ...and bonefast is let go with it", W.sets.bonefast == 0 or (W.N.cave and W.N.cave.grabUntil), W) and all
    all = check("F: let go just before touchdown: HJN_Bone(0, 0), said, done", lastB and lastB[1] == "0" and lastB[2] == "0" and W.N.cave == nil and #W.bones > nb
        and (lastLog(W, "let go of the Melon") or ""):find("ms before touchdown %(the hand came within 4 cm of its spot") ~= nil, W) and all
    local n = #W.bones
    frames(W, 0.1)
    all = check("F: nothing more after that", #W.bones == n and #W.kicks == 1, W) and all
end
-- M. no air at all within 0.25 s of the mount (put on close to the ground): let go then
do local W = world({ mode = 1 })
    W.N.caveTry(vel)
    W.t = W.t + 0.2 W.onBoard = true W.N.caveTick()
    frames(W, 0.2)
    local held = W.N.cave and W.N.cave.grabUntil ~= nil
    frames(W, 0.1)
    all = check("M: never in the air: held through 0.2 s, let go by 0.3 s as a touchdown", held and W.N.cave == nil and (lastLog(W, "let go of the Melon") or ""):find("touched down first") ~= nil, W) and all
end
-- N. CavemanGrab is the longest hold
do local W = world({ grab = 0.3 })
    W.N.caveTry(vel)
    W.t = W.t + 0.2 W.onBoard = true W.N.caveTick()
    frames(W, 0.35)
    all = check("N: CavemanGrab 0.3: let go at 0.3 s high over the ground", W.N.cave == nil and (lastLog(W, "let go of the Melon") or ""):find("the longest hold") ~= nil, W) and all
end
-- G. CavemanKeepFall=0: no kick, still the grab
do local W = world({ keep = 0 })
    W.N.caveTry(vel)
    W.t = W.t + 0.2 W.onBoard = true W.N.caveTick()
    frames(W, 0.05)
    all = check("G: KeepFall=0: no kick, the grab still on", #W.kicks == 0 and #W.bones >= 2 and W.N.cave ~= nil, W) and all
end
-- H. no mount at all: forgotten after 3 s
do local W = world()
    W.N.caveTry(vel)
    W.t = W.t + 3.1 W.N.caveTick()
    all = check("H: no mount: forgotten after 3 s", W.N.cave == nil and #W.kicks == 0 and #W.bones == 0, W) and all
end
-- I. the back hand carried it (the nose is the other hand's): the tail with that hand
do local W = world({ noseLeft = false })
    W.N.caveTry(vel)
    W.t = W.t + 0.2 W.onBoard = true W.N.caveTick()
    frames(W, 0.02)
    local b1 = W.bones[1]
    all = check("I: the back hand: the Indy (" .. (b1 and table.concat(b1, ",") or "none") .. ")", b1 and b1[2] == "0" and b1[3] == "102", W) and all
end
-- J. in the air, then touching down before the let-go: let go at once
do local W = world({ grab = 0.5 })
    W.N.caveTry(vel)
    W.t = W.t + 0.2 W.onBoard = true W.N.caveTick()
    frames(W, 0.1)
    W.mode = 1
    frames(W, 0.02)
    local lastB = W.bones[#W.bones]
    all = check("J: touched down: let go at once", lastB and lastB[1] == "0" and (lastLog(W, "let go of the Melon") or ""):find("touched down first") ~= nil, W) and all
end
-- K. CavemanGrab=0: no grab; done after the read-back
do local W = world({ grab = 0 })
    W.N.caveTry(vel)
    W.t = W.t + 0.2 W.onBoard = true W.N.caveTick()
    frames(W, 0.15)
    all = check("K: CavemanGrab=0: no hand on the board, done", #W.bones == 0 and W.N.cave == nil and #W.kicks == 1, W) and all
end
-- L. an older native half (no hand in its state answer): no grab, said once
do local W = world({ caveState = "0 1 1" })
    W.N.caveTry(vel)
    W.t = W.t + 0.2 W.onBoard = true W.N.caveTick()
    frames(W, 0.15)
    all = check("L: no hand known: no grab, said", #W.bones == 0 and lastLog(W, "did not say which hand") ~= nil and W.N.cave == nil, W) and all
end
-- (233) A2. CavemanTurn = 0 is sent as 0 (the native half then turns the body not at all)
do local W = world({ turn = 0 })
    W.N.caveTry(vel)
    local c = W.cave[1]
    all = check("A2: CavemanTurn 0 sent as the 6th number (" .. (c and table.concat(c, ",") or "none") .. ")", c and c[1] == "arm" and c[7] == "0", W) and all
end
-- (233) E2. the second Y's line: native v131 answers 2 (the board keeps its way), an older one 1, none 0
do local W = world()
    W.N.caveTry(vel)
    W.t = W.t + 0.12
    local s1 = W.N.caveSwitch(W.t)
    all = check("E2: answer 2: switch, 'the board keeps its way, your body turns the other way and the feet swing round'", s1 == true
        and (lastLog(W, "Y tapped again") or ""):find("SWITCH, turned half round: the board keeps its way, your body turns the other way and the feet swing round to the switch side", 1, true) ~= nil
        and (lastLog(W, "Y tapped again") or ""):find("drawn the other way round", 1, true) == nil, W) and all
end
do local W = world({ swAns = 1 })
    W.N.caveTry(vel)
    W.t = W.t + 0.12
    W.N.caveSwitch(W.t)
    all = check("E2: answer 1 (an older native half): the old words", (lastLog(W, "Y tapped again") or ""):find(": the board is drawn the other way round", 1, true) ~= nil, W) and all
end
do local W = world({ swAns = 0 })
    W.N.caveTry(vel)
    W.t = W.t + 0.12
    W.N.caveSwitch(W.t)
    local l = lastLog(W, "Y tapped again") or ""
    all = check("E2: answer 0: the line alone", l == "caveman: Y tapped again -- the game puts you on in SWITCH, turned half round", W) and all
end
-- (233) S. the key in main.lua: its default, its ini line (0..1), naming the native half this main.lua is made for
do
    local want = tonumber(src:match("\nNATIVE%.WANT = (%d+) "))
    local def = src:match("\n    CavemanTurn = ([%d%.]+),")
    local lo, hi, txt = src:match('\n    { "CavemanTurn", "num", (%S+), (%S+), "([^\n]-)" },\n')
    all = check("S: CavemanTurn defaults to 0.75 (" .. tostring(def) .. ")", tonumber(def) == 0.75) and all
    all = check("S: its ini line: 0..1", tonumber(lo) == 0 and tonumber(hi) == 1) and all
    all = check("S: ...naming the native half v" .. tostring(want) .. " (NATIVE.WANT, 131 or later)", want and want >= 131 and txt and txt:find("Takes the native half v" .. want, 1, true) ~= nil) and all
    all = check("S: ...right after CavemanLift's", src:find('"CavemanLift", "num", 0, 40, [^\n]*\n    { "CavemanTurn", "num"') ~= nil) and all
end
local o = assert(io.open("cave233_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("build 233's caveman test failed: see cave233_out.txt", 0) end

-- test_wall233.lua (the wallride's Lua half, ROUND 4: w4/wimpl/mkw_lua.pl; made for build 233, stackable and version-generic: the
-- build and native numbers are read off the file). It replaces test_wall231.lua. Round 4 (18 Oct, after build 232's "hard to
-- trigger ... bails a lot ... legs break in half"): HJN_Wall("cfg") takes 21 numbers -- WallRideMaxApproach (60, 10..75) in
-- WallRideMaxAngle's place (the user's ini pins that one at 35; it stays in S and the ini, "no longer used"), WallRideCarveKeep,
-- WallRideSlamGuard and WallRideExitTurn the 19th-21st (the two switches whole); the menu's slider is WallRideMaxApproach's; the
-- native half's new news (the board's own slam held off / given back, a START's carve) is logged as it comes (V). Run on build 232
-- (no WallRideMaxApproach) the suite fails as a whole.
-- What follows is test_wall231.lua's header, still true:
-- WALLRIDES. "Automatic on shallow wall hits, any air including ollies" (17 Oct); build 229 never rode one ("just bailed as
-- soon as he touched the wall"): the native half now arms the no-bail window from the trick's start and starts on the
-- first air pose (w3/wdiag/fix_plan.md). This half sends the settings (HJN_Wall("cfg", 18 numbers: WallRideTopRoom in
-- WallRideMinWall's place, WallRideArm the 18th)), holds a quarter-second window open every frame while no trick of the
-- mod's own has the board or the body (HJN_Wall("ok", s)), and copies the native half's news into the log, naming a clean
-- ride on the trick display; a refused line that names the shut window gets the reason in plain words (T).
-- NATIVE.wallBlock / wallTick / wallCfg are cut out of main.lua and run in real Lua against stand-ins for the native half
-- and the game; the defaults, the ini's limits and the wiring (onFrame, NATIVE.sync, the drop-in's state, the menu, the
-- build numbers) are read off the file itself. The fixer's cases (17 Oct) follow the Lua review: the native half's real
-- code-9 sentence (K), the mod switched off (N), a fractional WallRide (O), a short clean ride (P), the click grabs (Q),
-- TraceLog=0 (R), a window held shut in the air is said once (S: after 0.1 s since build 231), a native half without
-- HJN_Wall named by the function (D). Build 231's: the two keys (0, A, B3), the shut window in a refused line (T), the
-- arm's news (U), the wiring of the keys (M).
-- luareal -run test_wall233.lua result.txt main.lua   (writes wall233_out.txt)
-- Run on a build without round 4 (no WallRideMaxApproach, e.g. build 232), without the take-off or without the wallride the suite
-- fails as a whole.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
assert(src:find("WallRideMaxApproach", 1, true), "WallRideMaxApproach was not found (a build before the wallride's round 4, 233?)")
assert(src:find("WallRideArm", 1, true), "WallRideArm was not found (a build before the wallride's take-off, 231?)")
local a = assert(src:find("\nNATIVE.wallBlock = function(", 1, true), "NATIVE.wallBlock was not found (a build without the wallride?)")
local b = assert(src:find("\nlocal function onFrame(ctx)", a, true), "the end of the wallride's functions was not found")
local body = src:sub(a + 1, b)
local BUILD = tonumber(src:match("\nNATIVE%.BUILD = (%d+)\n"))
local WANTV = tonumber(src:match("\nNATIVE%.WANT = (%d+) "))
assert(BUILD and WANTV, "NATIVE.BUILD / NATIVE.WANT not found")
local CODE9 = "stopped by the Lua (a trick of the mod's, the menu or a setting)"   -- the native half's own sentence (WallTick, end code 9)

-- the settings as the file has them: S's defaults and SPEC's limits
local DEF, SPEC, SPECN = {}, {}, 0
do
    local sa = assert(src:find("\nlocal S = {\n", 1, true), "the S table was not found")
    local sb = assert(src:find("\n}\n", sa, true))
    for k, v in src:sub(sa, sb):gmatch("\n    (WallRide%w*) = (%-?[%d%.]+),") do DEF[k] = tonumber(v) end
    for k, lo, hi in src:gmatch('\n    { "(WallRide%w*)",%s*"num",%s*(%-?[%d%.]+),%s*(%-?[%d%.]+),') do
        SPEC[#SPEC + 1] = { k, "num", tonumber(lo), tonumber(hi), "" } SPECN = SPECN + 1
    end
end

local out, all = {}, true
local function check(name, cond, W)
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        for _, c in ipairs(W.calls) do local t = {} for i = 1, #c do t[i] = tostring(c[i]) end out[#out + 1] = "       HJN_Wall(" .. table.concat(t, ", ") .. ")" end
        for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l:sub(1, 300) end
        for _, n in ipairs(W.names) do out[#out + 1] = "       trick name: " .. n end
    end
    return cond
end

-- a world: W.okAns / W.cfgAns (what the native half answers), W.news (its queued lines), W.g (GetGravityZ), the mod's
-- trick states (W.active, W.YS, W.BY, W.RV, W.BV, W.VS, W.cave, W.DI, W.noComply, W.gg, W.GR, W.HO, W.hopTurnUntil, W.raw),
-- W.off (the mod switched off on this build)
local function world(opt)
    local W = { logs = {}, calls = {}, news = {}, names = {}, t = 100.0, g = -1127, okAns = 1, cfgAns = 21, nv = WANTV,
        active = false, YS = {}, BY = { pending = false }, RV = { pending = false }, BV = { pending = false }, VS = { on = false }, raw = 2 }
    for k, v in pairs(opt or {}) do W[k] = v end
    local env = { ipairs = ipairs, pairs = pairs, next = next, tonumber = tonumber, tostring = tostring, type = type, pcall = pcall, select = select,
        string = string, table = table, math = math, os = { clock = function() return W.t end } }
    if not W.noWall then
        env.HJN_Wall = function(op, ...)
            W.calls[#W.calls + 1] = { op, ... }
            if W.throw then error("the stand-in throws", 0) end
            if op == "ok" then return W.okAns end
            if op == "news" then return table.remove(W.news, 1) or "" end
            if op == "cfg" then return W.cfgAns end
            return 1
        end
    end
    local S = { SwitchLanding = W.switchLanding or 4, TraceLog = 1 }
    for k, v in pairs(DEF) do S[k] = v end
    for k, v in pairs(W.set or {}) do S[k] = v end
    local NATIVE = { v = W.nv, DEF = DEF, off = W.off, cave = W.cave, DI = W.DI, noComply = W.noComply, gg = W.gg, GR = W.GR, HO = W.HO, hopTurnUntil = W.hopTurnUntil }
    NATIVE.rawMode = function() return W.raw end
    local prelude = [[
local NATIVE, S, W, SPEC = ...
local active, YS, BY, RV, BV, VS = W.active, W.YS, W.BY, W.RV, W.BV, W.VS
local MODE_RIDING, MODE_AIR, MODE_BAILING = 1, 2, 5
local function log(s) W.logs[#W.logs + 1] = tostring(s) end
local function q(fn, dflt) local ok, v = pcall(fn) if ok and v ~= nil then return v end return dflt end
local mv = { GetGravityZ = function() if W.gErr then error("not readable") end return W.g end }
local function trickNameLater(t) W.names[#W.names + 1] = t end
]]
    local chunk = prelude .. body .. "\nreturn NATIVE\n"
    W.N = assert(load(chunk, "=wall", "t", env))(NATIVE, S, W, SPEC)
    W.S = S
    return W
end
local function near(x, y, e) return type(x) == "number" and math.abs(x - y) <= (e or 1e-6) end
local function calls(W, op) local r = {} for _, c in ipairs(W.calls) do if c[1] == op then r[#r + 1] = c end end return r end
local function logged(W, pat) local n = 0 for _, l in ipairs(W.logs) do if l:find(pat, 1, true) then n = n + 1 end end return n end
local function lastOk(W) local c = calls(W, "ok") return c[#c] and c[#c][2] end

-- HJN_Wall("cfg", ...)'s 21 numbers (build 231: WallRideTopRoom in WallRideMinWall's place, WallRideArm the 18th; build 233:
-- WallRideMaxApproach in WallRideMaxAngle's place, WallRideCarveKeep, WallRideSlamGuard, WallRideExitTurn the 19th-21st)
local KEYS = { "WallRide", "WallRideMaxApproach", "WallRideMinSpeed", "WallRideMinHeight", "WallRideTime", "WallRideGravity", "WallRideBleed", "WallRideGap",
    "WallRideTilt", "WallRidePitch", "WallRidePopOut", "WallRideFrontside", "WallRideReach", "WallRideTopRoom", "WallRideTraces", "g", "WallRideTraj", "WallRideArm",
    "WallRideCarveKeep", "WallRideSlamGuard", "WallRideExitTurn" }
local WANT = { 1, 60, 300, 40, 1.0, 0.35, 0.1, 4, 60, 0.5, 100, 1, 70, 30, 4, 1127, 1, 0.55, 0.6, 1, 1 }
local NK = #KEYS
local LIMITS = { WallRide = { 0, 1 }, WallRideMaxAngle = { 5, 60 }, WallRideMinSpeed = { 100, 1500 }, WallRideMinHeight = { 10, 200 }, WallRideReach = { 30, 150 },
    WallRideMinWall = { 20, 150 }, WallRideTime = { 0.3, 3 }, WallRideGravity = { 0, 1 }, WallRideBleed = { 0, 2 }, WallRideGap = { 1, 20 }, WallRideTilt = { 20, 80 },
    WallRidePitch = { 0, 1 }, WallRidePopOut = { 0, 400 }, WallRideFrontside = { 0, 1 }, WallRideTraj = { 0, 1 }, WallRideTraces = { 0, 20 },
    WallRideTopRoom = { 10, 150 }, WallRideArm = { 0, 1 }, WallRideMaxApproach = { 10, 75 }, WallRideCarveKeep = { 0, 1 }, WallRideSlamGuard = { 0, 1 }, WallRideExitTurn = { 0, 1 } }

-- 0. the 21 settings: a default in S and a line in the ini's SPEC with its limits (WallRideMinWall and WallRideMaxAngle stay in S
--    and the ini: the user's ini keeps their lines; they are no longer sent)
do
    local bad = {}
    for i, k in ipairs(KEYS) do if k ~= "g" and not near(DEF[k], WANT[i]) then bad[#bad + 1] = k .. "=" .. tostring(DEF[k]) end end
    if not near(DEF.WallRideMinWall, 50) then bad[#bad + 1] = "WallRideMinWall=" .. tostring(DEF.WallRideMinWall) end
    if not near(DEF.WallRideMaxAngle, 35) then bad[#bad + 1] = "WallRideMaxAngle=" .. tostring(DEF.WallRideMaxAngle) end
    all = check("0: the 21 defaults in S (" .. ((#bad == 0) and "all as designed: WallRideMaxApproach 60, WallRideCarveKeep 0.6, WallRideSlamGuard 1, WallRideExitTurn 1; WallRideMinWall 50 and WallRideMaxAngle 35 kept" or table.concat(bad, " ")) .. ")", #bad == 0) and all
    local seen, badl = {}, {}
    for _, sp in ipairs(SPEC) do seen[sp[1]] = true local L = LIMITS[sp[1]] if not L or sp[3] ~= L[1] or sp[4] ~= L[2] then badl[#badl + 1] = sp[1] end end
    for k in pairs(LIMITS) do if not seen[k] then badl[#badl + 1] = k .. " (missing)" end end
    all = check("0: 22 SPEC lines with the designed limits (" .. SPECN .. " found" .. ((#badl == 0) and "" or ("; wrong: " .. table.concat(badl, " "))) .. ")", SPECN == 22 and #badl == 0) and all
end
-- A. the settings to the native half: HJN_Wall("cfg", 21 numbers) in the native half's order, g from GetGravityZ -1127
do local W = world()
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    local same = c ~= nil and #c == NK + 1
    if same then for i = 1, NK do if not near(c[i + 1], WANT[i]) then same = false end end end
    local shown = {} if c then for i = 2, #c do shown[#shown + 1] = tostring(c[i]) end end
    all = check("A: HJN_Wall('cfg', " .. table.concat(shown, " ") .. ")", same and #W.calls == 1, W) and all
    local l = W.logs[1] or ""
    all = check("A: the log says ON with the numbers, nothing refused", #W.logs == 1 and l:find("native: wallrides ON: a wall met at up to 60 deg", 1, true) ~= nil
        and l:find("from 300 cm/s", 1, true) ~= nil and l:find("(gravity 1127 cm/s2)", 1, true) ~= nil and l:find(" -- ", 1, true) == nil
        and l:find("the wall rising 30 cm over the highest the board will reach (WallRideTopRoom), armed 0.55 s ahead (WallRideArm); at most 1.0 s on the wall", 1, true) ~= nil
        and l:find("; a steep approach carved 0.6 of the way along the wall (WallRideCarveKeep), the board's own slam held off 1 (WallRideSlamGuard), the landing turned along the exit 1 (WallRideExitTurn); the first 4 rides traced", 1, true) ~= nil, W) and all
    all = check("A: (233) the 2nd number is WallRideMaxApproach's 60 (WallRideMaxAngle, the user's 35, is not sent); the 19th-21st 0.6, 1, 1", c ~= nil and c[3] == 60 and near(c[20], 0.6) and c[21] == 1 and c[22] == 1 and #c == 22, W) and all
    all = check("A: WallRideMinWall (the user's old 50) is not sent: the 14th number is WallRideTopRoom's", c ~= nil and c[15] == 30, W) and all
end
-- B. sent again only when something changed
do local W = world()
    W.N.wallCfg() W.N.wallCfg() W.N.wallCfg()
    local n1 = #calls(W, "cfg")
    W.S.WallRideTime = 1.5
    W.N.wallCfg()
    local cs = calls(W, "cfg")
    all = check("B: unchanged: sent once (" .. n1 .. "); WallRideTime 1.5: sent again with 1.5", n1 == 1 and #cs == 2 and near(cs[2][6], 1.5) and #W.logs == 2, W) and all
    W.N.wallCfg(true)
    all = check("B: forced: sent again", #calls(W, "cfg") == 3, W) and all
    W.S.WallRide = 0
    W.N.wallCfg()
    cs = calls(W, "cfg")
    all = check("B: WallRide 0: sent with on = 0, the log says off", #cs == 4 and cs[4][2] == 0 and W.logs[#W.logs]:find("native: wallrides off:", 1, true) ~= nil, W) and all
end
-- B2. each number held to its SPEC limits once more, the switches whole
do local W = world({ set = { WallRideMaxApproach = 90, WallRideTraces = 3.6, WallRideGap = -5, WallRideFrontside = 0.4 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("B2: 90 deg -> 75 (233: WallRideMaxApproach), 3.6 traces -> 4, gap -5 -> 1, frontside 0.4 -> 0", c and c[3] == 75 and c[16] == 4 and math.type(c[16]) == "integer" and c[9] == 1 and c[13] == 0, W) and all
end
-- B3. (231) the two new keys held to their limits too, the arm not rounded (a fraction of a second), the old key not looked at
do local W = world({ set = { WallRideTopRoom = 5, WallRideArm = 3, WallRideMinWall = 999 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("B3: WallRideTopRoom 5 -> 10, WallRideArm 3 -> 1 (WallRideMinWall 999 changes nothing)", c and c[15] == 10 and c[19] == 1 and #c == NK + 1, W) and all
end
do local W = world({ set = { WallRideTopRoom = 200, WallRideArm = -1 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("B3: WallRideTopRoom 200 -> 150, WallRideArm -1 -> 0 (no arming)", c and c[15] == 150 and c[19] == 0, W) and all
end
do local W = world({ set = { WallRideArm = 0.37 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("B3: WallRideArm 0.37 is sent as it is (not rounded)", c and near(c[19], 0.37) and (W.logs[1] or ""):find("armed 0.37 s ahead (WallRideArm)", 1, true) ~= nil, W) and all
    W.S.WallRideArm = 0.4
    W.N.wallCfg()
    all = check("B3: ...and sent again when it changes", #calls(W, "cfg") == 2 and near(calls(W, "cfg")[2][19], 0.4), W) and all
end
-- B4. (233) the four new keys held to their limits, the two switches whole; the old WallRideMaxAngle not looked at
do local W = world({ set = { WallRideMaxApproach = 80, WallRideCarveKeep = -1, WallRideSlamGuard = 0.6, WallRideExitTurn = 0.4, WallRideMaxAngle = 10 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("B4: WallRideMaxApproach 80 -> 75, WallRideCarveKeep -1 -> 0, WallRideSlamGuard 0.6 -> 1, WallRideExitTurn 0.4 -> 0 (WallRideMaxAngle 10 changes nothing)",
        c and c[3] == 75 and c[20] == 0 and c[21] == 1 and math.type(c[21]) == "integer" and c[22] == 0 and math.type(c[22]) == "integer" and #c == NK + 1, W) and all
end
do local W = world({ set = { WallRideMaxApproach = 5, WallRideCarveKeep = 0.35, WallRideSlamGuard = 0, WallRideExitTurn = 1 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    local l = W.logs[1] or ""
    all = check("B4: WallRideMaxApproach 5 -> 10, WallRideCarveKeep 0.35 sent as it is (not rounded), the guard off: said so", c and c[3] == 10 and near(c[20], 0.35) and c[21] == 0 and c[22] == 1
        and l:find("a steep approach carved 0.35 of the way along the wall (WallRideCarveKeep), the board's own slam held off 0 (WallRideSlamGuard), the landing turned along the exit 1 (WallRideExitTurn)", 1, true) ~= nil, W) and all
    W.S.WallRideSlamGuard = 1
    W.N.wallCfg()
    all = check("B4: ...and sent again when the guard changes", #calls(W, "cfg") == 2 and calls(W, "cfg")[2][21] == 1, W) and all
end
-- C. the gravity unreadable or 0: 980
do local W = world({ gErr = true })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("C: GetGravityZ unreadable: g 980", c and c[17] == 980, W) and all
end
do local W = world({ g = 0 })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("C: GetGravityZ 0: g 980", c and c[17] == 980, W) and all
end
-- D. a native half without HJN_Wall (older, or one of the same number made without the wallride): nothing called, said
--    once, by the function and not by the number (Lua review F7)
do local W = world({ noWall = true, nv = WANTV - 1 })
    for _ = 1, 100 do W.N.wallTick() end
    for _ = 1, 100 do W.N.wallCfg() end
    all = check("D: no HJN_Wall (v" .. (WANTV - 1) .. "): one line over 100 frames, naming v" .. WANTV, logged(W, "wallride: the native half beside this file (v" .. (WANTV - 1)
        .. ") has no HJN_Wall: it is not the one made with this main.lua (v" .. WANTV .. ", with wallrides) -- NOT TAKEN: no wallrides on this run") == 1, W) and all
    all = check("D: ...and one settings line, NOT TAKEN", logged(W, "NOT TAKEN: the native half (v" .. (WANTV - 1) .. ") has no HJN_Wall; these need the v" .. WANTV .. " made with this main.lua") == 1 and #W.logs == 2, W) and all
end
do local W = world({ noWall = true, nv = WANTV })
    W.N.wallTick()
    all = check("D: a v" .. WANTV .. " without HJN_Wall is not called 'older'", #W.logs == 1 and W.logs[1]:find("(v" .. WANTV .. ") has no HJN_Wall", 1, true) ~= nil and W.logs[1]:find("need the native half", 1, true) == nil, W) and all
end
do local W = world({ noWall = true, nv = WANTV - 1, set = { WallRide = 0 } })
    for _ = 1, 100 do W.N.wallTick() end
    all = check("D: no HJN_Wall and WallRide 0: nothing said by the frame", #W.logs == 0, W) and all
end
-- E. the window: a quarter second every frame while nothing of the mod's runs; 0 with WallRide 0
do local W = world()
    for _ = 1, 3 do W.N.wallTick() W.t = W.t + 0.016 end
    local ok = calls(W, "ok")
    all = check("E: 3 frames: 'ok', 0.25 each time", #ok == 3 and ok[1][2] == 0.25 and ok[2][2] == 0.25 and ok[3][2] == 0.25 and #W.logs == 0, W) and all
end
do local W = world({ set = { WallRide = 0 } })
    W.N.wallTick()
    local ok = calls(W, "ok")
    all = check("E: WallRide 0: 'ok', 0", #ok == 1 and ok[1][2] == 0, W) and all
end
-- F. each of the mod's own tricks shuts it (and only while it runs)
local BLOCK = {
    { "a hippie jump", { active = true } }, { "the hop's ollie", { HO = { on = true } } }, { "the landing's yaw settle", { YS = { t0 = 99 } } },
    { "the varial bail's yaw", { BY = { pending = true } } }, { "a switch landing", { RV = { pending = true } } }, { "a varial bail", { BV = { pending = true } } },
    { "the caveman", { cave = { at = 99 } } }, { "a drop-in", { DI = { state = "wait" } } }, { "the drop-in's ride watch", { DI = { state = "ride" } } },
    { "a no comply", { noComply = { guard = 99.5 } } }, { "a hand on the board", { gg = { kind = "Indy" } } }, { "a stance swap", { VS = { on = true } } },
    { "a board hop's turn", { hopTurnUntil = 100.2 } }, { "the replay", { raw = 6 } },
    { "a stick-click grab", { GR = { on = true } } }, { "a stick-click grab about to switch", { GR = { on = false, pending = { id = 3 } } } } }
for _, bl in ipairs(BLOCK) do
    local W = world(bl[2])
    W.N.wallTick()
    local ok = calls(W, "ok")
    all = check("F: " .. bl[1] .. ": 'ok', 0", #ok == 1 and ok[1][2] == 0, W) and all
end
local OPEN = { { "a board hop's turn that ran out", { hopTurnUntil = 99.9 } }, { "a stance kept by SwitchLanding 3", { VS = { on = true }, switchLanding = 3 } },
    { "no drop-in", { DI = { state = nil } } }, { "the hop's ollie off", { HO = { on = false } } }, { "no hand on the board", { gg = { kind = nil } } },
    { "no stick-click grab", { GR = { on = false } } } }
for _, op in ipairs(OPEN) do
    local W = world(op[2])
    W.N.wallTick()
    local ok = calls(W, "ok")
    all = check("F: " .. op[1] .. ": 'ok', 0.25", #ok == 1 and ok[1][2] == 0.25, W) and all
end
-- G. the news: in order, without the tag, the empty answer stops it, 8 a frame at the most
do local W = world({ news = { "start #1 backside: you face away from the wall, the wall on your right, met at 18 deg", "end #1 backside clean: over after 0.84 s (51 poses): ride time over" } })
    W.N.wallTick()
    all = check("G: two lines in order", #W.logs == 2 and W.logs[1] == "wallride: #1 backside: you face away from the wall, the wall on your right, met at 18 deg"
        and W.logs[2] == "wallride: #1 backside clean: over after 0.84 s (51 poses): ride time over", W) and all
    all = check("G: the third ask (\"\") stopped it", #calls(W, "news") == 3, W) and all
end
do local W = world()
    for i = 1, 11 do W.news[#W.news + 1] = "refused a wall " .. i .. "0 cm away, met at 48 deg: too steep to ride (the most is 35)" end
    W.N.wallTick()
    local first = #W.logs
    W.N.wallTick()
    all = check("G: 11 queued: 8 the first frame (" .. first .. "), the other 3 the next (" .. #W.logs .. ")", first == 8 and #W.logs == 11 and W.logs[1]:find("^wallride: a wall 10 cm away") ~= nil, W) and all
end
do local long = "end #9 backside clean: over after 0.84 s (51 poses): ride time over. " .. string.rep("x", 1300)   -- (the native ring now holds 1400 a line)
    local W = world({ news = { long } })
    W.N.wallTick()
    all = check("G: a 1370-character END line is logged whole and named", #W.logs == 1 and #W.logs[1] == #long - 4 + #"wallride: " and #W.names == 1, W) and all
end
-- H. a clean end names the trick (shown once you ride away); an aborted one does not; a start does not
do local W = world({ news = { "start #2 backside: ...", "end #2 backside clean: over after 0.9 s: the wall ended" } })
    W.N.wallTick()
    all = check("H: backside clean -> 'Backside Wallride'", #W.names == 1 and W.names[1] == "Backside Wallride", W) and all
end
do local W = world({ news = { "end #3 frontside clean: over after 0.5 s: the ground is near" } })
    W.N.wallTick()
    all = check("H: frontside clean -> 'Frontside Wallride'", #W.names == 1 and W.names[1] == "Frontside Wallride", W) and all
end
do local W = world({ news = { "end #4 backside abort: over after 0.2 s: you bailed", "info ready (native v" .. WANTV .. "): the clip table has 3 x 25 poses" } })
    W.N.wallTick()
    all = check("H: an aborted ride and an info line: no trick name, both logged", #W.names == 0 and #W.logs == 2 and W.logs[2] == "wallride: ready (native v" .. WANTV .. "): the clip table has 3 x 25 poses", W) and all
end
-- I. stood down (another build of the game): said once, no news asked
do local W = world({ okAns = -1, news = { "info should not be read" } })
    for _ = 1, 100 do W.N.wallTick() end
    all = check("I: 'ok' answers -1: one 'not on this build' line over 100 frames, no news drained", logged(W, "wallride: not on this build of the game") == 1 and #W.logs == 1 and #calls(W, "news") == 0, W) and all
end
-- J. HJN_Wall raising an error: nothing escapes, said once
do local W = world({ throw = true })
    local escaped = 0
    for _ = 1, 10 do if not pcall(W.N.wallTick) then escaped = escaped + 1 end end
    all = check("J: a throwing HJN_Wall: no error escapes the frame (" .. escaped .. "), one line (" .. #W.logs .. ")", escaped == 0 and #W.logs == 1 and W.logs[1]:find("raised an error", 1, true) ~= nil, W) and all
    W.N.wallCfg()
    all = check("J: ...and the settings line says REFUSED, no error", logged(W, "REFUSED by the native half (0 of 21 taken") == 1, W) and all
end
-- K. a ride the window ended (the native half's own code-9 sentence): the END line says why in plain words (Lua review F6)
do local W = world({ active = true, news = { "end #5 backside clean: over after 0.40 s (24 poses): " .. CODE9 .. ". Rode 120 cm along the wall" } })
    W.N.wallTick()
    all = check("K: a hippie jump shut it -> 'stopped by the Lua: a hippie jump began'", W.logs[1] == "wallride: #5 backside clean: over after 0.40 s (24 poses): stopped by the Lua: a hippie jump began (no wallride runs through one). Rode 120 cm along the wall", W) and all
    all = check("K: ...and the ride is still named (0.40 s)", #W.names == 1 and W.names[1] == "Backside Wallride", W) and all
end
do local W = world({ news = { "end #6 backside clean: over after 0.31 s (19 poses): " .. CODE9 .. ". Rode 60 cm" } })
    W.N.wallTick()
    all = check("K: nothing of the mod's ran -> 'its window ran out'", W.logs[1] == "wallride: #6 backside clean: over after 0.31 s (19 poses): stopped by the Lua: its window ran out (no frame of the mod's for a quarter second: the game hitched or was paused). Rode 60 cm", W) and all
end
do local W = world({ set = { WallRide = 0 }, news = { "end #7 backside clean: over after 0.5 s (30 poses): " .. CODE9 .. ". Rode 80 cm" } })
    W.N.wallTick()
    all = check("K: WallRide set to 0 -> said so", W.logs[1] == "wallride: #7 backside clean: over after 0.5 s (30 poses): stopped by the Lua: WallRide was set to 0. Rode 80 cm", W) and all
end
do local W = world({ active = true, news = { "end #8 backside clean: over after 0.4 s (24 poses): wallrides were switched off. Rode 80 cm", "end #9 frontside clean: over after 0.6 s (36 poses): ended by the Lua. Rode 90 cm" } })
    W.N.wallTick()
    all = check("K: the native half's other code-9 sentences are kept as they came", W.logs[1] == "wallride: #8 backside clean: over after 0.4 s (24 poses): wallrides were switched off. Rode 80 cm"
        and W.logs[2] == "wallride: #9 frontside clean: over after 0.6 s (36 poses): ended by the Lua. Rode 90 cm", W) and all
end
do local W = world({ news = { "end #10 backside clean: over after 0.4 s (24 poses): " .. CODE9 .. ". Rode 100 % of 80 cm" } })
    W.N.wallTick()
    all = check("K: a '%' in the line comes through", W.logs[1] ~= nil and W.logs[1]:find("Rode 100 % of 80 cm", 1, true) ~= nil, W) and all
end
-- L. what the native half answers to the settings
do local W = world({ cfgAns = -1 })
    W.N.wallCfg()
    all = check("L: 'cfg' answers -1: the line says stood down", logged(W, " -- stood down: not on this build of the game") == 1, W) and all
end
do local W = world({ cfgAns = 0 })
    W.N.wallCfg()
    all = check("L: 'cfg' answers 0: the line says REFUSED", logged(W, " -- REFUSED by the native half (0 of 21 taken") == 1, W) and all
end
do local W = world({ cfgAns = 18 })   -- (merge, review A #9) v130 takes the first 18 of the 21 and answers 18
    W.N.wallCfg()
    all = check("L: 'cfg' answers 18 (an older native half): said as such, not REFUSED", logged(W, " -- an older native half took the first 18 of 21: WallRideMaxApproach is its approach limit there") == 1 and logged(W, "REFUSED") == 0, W) and all
end
-- N. the mod switched off on this build (NATIVE.off): the window shut every frame, nothing else asked or said (F8)
do local W = world({ off = true, news = { "start #1 backside: should not be read" } })
    for _ = 1, 5 do W.N.wallTick() end
    local ok = calls(W, "ok")
    all = check("N: NATIVE.off: 'ok', 0 on each of 5 frames, no news drained, nothing said", #ok == 5 and ok[1][2] == 0 and ok[5][2] == 0 and #calls(W, "news") == 0 and #W.logs == 0, W) and all
end
do local W = world({ off = true, noWall = true })
    for _ = 1, 5 do W.N.wallTick() end
    all = check("N: NATIVE.off and no HJN_Wall: nothing said", #W.logs == 0, W) and all
end
-- O. a fractional WallRide: the window and the settings agree on what "on" is (F10)
do local W = world({ set = { WallRide = 0.4 } })
    W.N.wallTick() W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("O: WallRide 0.4: window 0 and on = 0", lastOk(W) == 0 and c and c[2] == 0, W) and all
end
do local W = world({ set = { WallRide = 0.6 } })
    W.N.wallTick() W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("O: WallRide 0.6: window 0.25 and on = 1", lastOk(W) == 0.25 and c and c[2] == 1, W) and all
end
-- P. a clean end shorter than a quarter second is no wallride's name (F5)
do local W = world({ news = { "end #3 backside clean: over after 0.03 s (2 poses): the wall ended (the follow ray missed twice). Rode 9 cm",
        "end #4 backside clean: over after 0.24 s (14 poses): the wall ended ahead. Rode 70 cm", "end #5 backside clean: over after 0.25 s (15 poses): ride time over. Rode 75 cm" } })
    W.N.wallTick()
    all = check("P: 0.03 s and 0.24 s: not named; 0.25 s: named once", #W.logs == 3 and #W.names == 1 and W.names[1] == "Backside Wallride", W) and all
end
-- R. TraceLog=0: no per-pose traces, the wallride's either (F9)
do local W = world({ set = { TraceLog = 0 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("R: TraceLog 0: traces sent as 0", c and c[16] == 0 and math.type(c[16]) == "integer", W) and all
end
do local W = world({ set = { TraceLog = 1, WallRideTraces = 7 } })
    W.N.wallCfg()
    local c = calls(W, "cfg")[1]
    all = check("R: TraceLog 1, WallRideTraces 7: traces 7", c and c[16] == 7, W) and all
end
-- S. a window held shut in the air by the mod's own state is said once a run for each reason, after a tenth of a second (F3;
--    build 231: it was half a second, and build 229's airs lasted 0.15-0.5 s)
do local W = world({ active = true, raw = 2 })
    W.N.wallTick() W.t = W.t + 0.05 W.N.wallTick() W.t = W.t + 0.04 W.N.wallTick()
    local early = #W.logs
    W.t = W.t + 0.03 W.N.wallTick() W.t = W.t + 0.5 W.N.wallTick()
    all = check("S: a hippie jump holding it shut in the air: nothing at 0.09 s (" .. early .. "), one line by 0.12 s (and no more by 0.62)", early == 0 and #W.logs == 1
        and W.logs[1] == "wallride: none can start in this air while a hippie jump runs (a trick of the mod's has the board or the body; said once a run for each)", W) and all
    W.raw = 1 W.t = W.t + 0.1 W.N.wallTick()
    W.raw = 2 for _ = 1, 10 do W.t = W.t + 0.1 W.N.wallTick() end
    all = check("S: ...the next air with the same reason: not said again", #W.logs == 1, W) and all
end
do local W = world({ active = true, raw = 1 })
    for _ = 1, 20 do W.t = W.t + 0.1 W.N.wallTick() end
    all = check("S: held shut while riding on the ground: nothing said", #W.logs == 0, W) and all
end
do local W = world({ raw = 6 })
    for _ = 1, 20 do W.t = W.t + 0.1 W.N.wallTick() end
    all = check("S: the replay: nothing said", #W.logs == 0 and lastOk(W) == 0, W) and all
end
do local W = world({ active = true, raw = 2, set = { WallRide = 0 } })
    for _ = 1, 20 do W.t = W.t + 0.1 W.N.wallTick() end
    all = check("S: WallRide 0: nothing said", #W.logs == 0, W) and all
end
do local W = world({ active = true, raw = 2 })
    W.N.wallTick() W.t = W.t + 0.12 W.N.wallTick()
    local first = #W.logs
    W.raw = 1 W.t = W.t + 0.1 W.N.wallTick()
    W.raw = 2 W.t = W.t + 0.1 W.N.wallTick() W.t = W.t + 0.05 W.N.wallTick()
    all = check("S: said at 0.12 s in the first air (" .. first .. "); a short second air (0.05 s) adds nothing", first == 1 and #W.logs == 1, W) and all
end
-- T. (231) a refused line that names the native half's gate "the Lua's window is shut (a trick of the mod's)": the parenthesis
--    in plain words, as for the code-9 END line -- which of the mod's tricks holds it shut, WallRide 0, or the window lapsed
local SHUT = "the Lua's window is shut (a trick of the mod's)"
do local W = world({ active = true, news = { "refused a wall 52 cm away, met at 18 deg: no ride: " .. SHUT } })
    W.N.wallTick()
    all = check("T: a hippie jump runs -> 'the Lua's window is shut: a hippie jump runs'", W.logs[1] == "wallride: a wall 52 cm away, met at 18 deg: no ride: the Lua's window is shut: a hippie jump runs" and #W.names == 0, W) and all
end
do local W = world({ news = { "refused no ride in this air (you landed 0.61 s after the take-off, 0.83 s after the trick began): the nearest wall the rays saw: 60 cm from the board's middle, met at 20 deg, closing at 171 cm/s, the body 0.15 s from it; what held: "
        .. SHUT .. " (9 poses with the wall near); body hits passed over: 0" } })
    W.N.wallTick()
    all = check("T: nothing of the mod's ran -> 'its window ran out', the rest of the air's line kept", W.logs[1] ~= nil and W.logs[1]:find("what held: the Lua's window is shut: its window ran out (no frame of the mod's for a quarter second) (9 poses with the wall near); body hits passed over: 0", 1, true) ~= nil
        and W.logs[1]:find("^wallride: no ride in this air %(you landed 0%.61 s after the take%-off") ~= nil, W) and all
end
do local W = world({ set = { WallRide = 0 }, news = { "refused a wall 40 cm away, met at 12 deg: no ride: " .. SHUT } })
    W.N.wallTick()
    all = check("T: WallRide 0 -> 'WallRide was set to 0'", W.logs[1] == "wallride: a wall 40 cm away, met at 12 deg: no ride: the Lua's window is shut: WallRide was set to 0", W) and all
end
do local W = world({ news = { "refused a wall 61 cm away, met at 22 deg: no ride: a flip or a scoop turns the board", "end #2 backside abort: over after 0.10 s (6 poses): " .. SHUT } })
    W.N.wallTick()
    all = check("T: another gate, and an END line with the same words: kept as they came", W.logs[1] == "wallride: a wall 61 cm away, met at 22 deg: no ride: a flip or a scoop turns the board"
        and W.logs[2] == "wallride: #2 backside abort: over after 0.10 s (6 poses): " .. SHUT, W) and all
end
-- U. (231) the arm's news ("info armed: ...") and a bail's air line are logged as they came, and name no trick
do local W = world({ news = { "info armed: a wall 83 cm from the board's middle, met at 20 deg, closing at 205 cm/s (600 along the ground, the deck's movement speed), the body 0.23 s from it; the pop pending, 0.02 s after the trick began -- the impact bail is passed over while it holds",
        "refused no ride in this air (you bailed 0.03 s after the take-off, 0.27 s after the trick began): the nearest wall the rays saw: 35 cm from the board's middle, met at 20 deg, closing at 205 cm/s, the body 0.00 s from it; what held: under 0.10 s in the air (not armed) (2 poses with the wall near); body hits passed over: 0" } })
    W.N.wallTick()
    all = check("U: 'wallride: armed: a wall 83 cm ...' and the bail's line, no trick name", #W.logs == 2 and W.logs[1]:find("^wallride: armed: a wall 83 cm from the board's middle") ~= nil
        and W.logs[2]:find("^wallride: no ride in this air %(you bailed") ~= nil and #W.names == 0, W) and all
end
-- V. (233) the native half's round-4 news -- the board's own slam held off and given back, a START's carve, the short-ride
--    refusal -- logged as they came, no trick named
do local W = world({ news = { "info the board's own head-on slam is held off (SkateboardCollisionSlamConfig.SpeedMin 300 -> off) while a 47-deg wall is armed",
        "start #4 frontside: you face toward the wall (your front foot is the mesh's left), the wall on your right, met at 47 deg; 410 cm/s along it (carved: 410 of 520 cm/s along the wall, 355 along it before), +300 up",
        "info the board's own head-on slam given back (lapsed) after 1.12 s (SpeedMin 300 again; the 47-deg wall was ridden)",
        "refused a wall 61 cm away, met at 14 deg: the ride would be over in under 0.20 s (the ground 118 cm under the board, -101 cm/s): the game's own air" } })
    W.N.wallTick()
    all = check("V: the slam held / given back, a carved START and the short-ride refusal logged as they came, no trick named", #W.logs == 4 and #W.names == 0
        and W.logs[1] == "wallride: the board's own head-on slam is held off (SkateboardCollisionSlamConfig.SpeedMin 300 -> off) while a 47-deg wall is armed"
        and W.logs[2]:find("(carved: 410 of 520 cm/s along the wall, 355 along it before)", 1, true) ~= nil
        and W.logs[3] == "wallride: the board's own head-on slam given back (lapsed) after 1.12 s (SpeedMin 300 again; the 47-deg wall was ridden)"
        and W.logs[4]:find("^wallride: a wall 61 cm away, met at 14 deg: the ride would be over in under 0%.20 s") ~= nil, W) and all
end
-- M. the wiring, read off the file
do
    local pair = "    if NATIVE.cave and NATIVE.caveTick then pcall(NATIVE.caveTick) end               -- (v226) the caveman's mount: the fall's speed given back\n    if not isMine(ctx) then return end\n"
    local p = src:find(pair, 1, true)
    all = check("M: onFrame: pcall(NATIVE.wallTick) right after our skater's test", p ~= nil and src:sub(p + #pair, p + #pair + 25) == "    pcall(NATIVE.wallTick)") and all
    local s1 = src:find("\nfunction NATIVE.sync()\n", 1, true)
    local s2 = s1 and src:find("-- (v181) native v97", s1, true)
    local c = s1 and src:find("if NATIVE.wallCfg then pcall(NATIVE.wallCfg) end", s1, true)
    all = check("M: NATIVE.sync sends the settings (before the v97 block)", c ~= nil and s2 ~= nil and c < s2) and all
    all = check("M: the drop-in's state is seen (NATIVE.DI = DI)", src:find("    local DI = { state = nil }\n    NATIVE.DI = DI ", 1, true) ~= nil) and all
    all = check("M: the click grabs are seen (NATIVE.GR = GR)", src:find("\nNATIVE.GR = GR ", 1, true) ~= nil) and all
    local m1 = src:find('\n    { "General gameplay settings", {\n', 1, true)
    local m2 = m1 and src:find("\n    } },\n", m1, true)
    local page = (m1 and m2) and src:sub(m1, m2) or ""
    all = check("M: the menu's General page has the three rows", page:find('{ "toggle", "WallRide", "Wallrides", 1, 1,', 1, true) ~= nil
        and page:find('{ "slider", "WallRideMaxApproach", "Wallride: steepest approach", 1, 5, ', 1, true) ~= nil and page:find('"WallRideMaxAngle"', 1, true) == nil and page:find('{ "slider", "WallRideTime", "Wallride: longest ride", 1000, 100,', 1, true) ~= nil) and all
    local quick = src:match("\nNATIVE%.MENU_QUICK = (%b{})") or ""
    local nq = 0 for _ in quick:gmatch('"%w+"') do nq = nq + 1 end
    all = check("M: the Quick page lists WallRide (" .. nq .. " rows, 14 at most)", quick:find('"NoComply", "WallRide", "StickTurn"', 1, true) ~= nil and nq <= 14) and all
    all = check("M: build " .. BUILD .. " / native v" .. WANTV .. " (233 / 131 or later), and the loaded line says so", BUILD >= 233 and WANTV >= 131 and BUILD - WANTV == 102
        and src:find("loaded (v" .. BUILD .. " / native v" .. WANTV .. ")", 1, true) ~= nil) and all
    all = check("M: the WallRide ini line names the native half v" .. WANTV, src:find("0 = off, the game's own. Takes the native half v" .. WANTV .. '" },', 1, true) ~= nil) and all
    all = check("M: the older-native warning names no one feature's loss (wallrides need v" .. WANTV .. ")", src:find("Until then what needs the newer one is left out, each saying so in its own line (wallrides need v" .. WANTV .. ": without it the log says NOT TAKEN)", 1, true) ~= nil
        and src:find("Until then a goofy rider's caught switch boneless", 1, true) == nil) and all
    local sd = src:find("\n    WallRideTraces = 4,\n    WallRideTopRoom = 30,\n    WallRideArm = 0.55,\n", 1, true)
    local sp = src:find('\\n; (every wallride\'s poses are marked in the pose recorder whatever this says)" },\n    { "WallRideTopRoom", "num", 10, 150, ', 1, true)
    local sp2 = sp and src:find('\n    { "WallRideArm", "num", 0, 1, ', sp, true)
    local trl = src:find('\n    { "WallRideTopRoom", "num", 10, 150, ', 1, true)
    local sp3 = trl and src:find("\n", trl + 1, true)                          -- the end of WallRideTopRoom's line: WallRideArm's comes next
    all = check("M: the two new keys sit right after WallRideTraces in S and in the ini", sd ~= nil and sp ~= nil and sp2 ~= nil and sp3 ~= nil and sp2 == sp3) and all
    local sw = src:find("\n    WallRideFrontside = ", 1, true)
    local de = src:find("\n    DevKeys = 0,\n", 1, true)
    all = check("M: the wallride's keys sit in S before DevKeys (after the caveman's)", sw ~= nil and de ~= nil and sd ~= nil and sw < sd and sd < de) and all
    local s4 = src:find("\n    WallRideArm = 0.55,\n    WallRideMaxApproach = 60,\n    WallRideCarveKeep = 0.6,\n    WallRideSlamGuard = 1,\n    WallRideExitTurn = 1,\n", 1, true)
    local arl = src:find('\n    { "WallRideArm", "num", 0, 1, ', 1, true)
    local ae = arl and src:find("\n", arl + 1, true)
    local p1 = src:find('\n    { "WallRideMaxApproach", "num", 10, 75, ', 1, true)
    local p2 = src:find('\n    { "WallRideCarveKeep", "num", 0, 1, ', 1, true)
    local p3 = src:find('\n    { "WallRideSlamGuard", "num", 0, 1, ', 1, true)
    local p4 = src:find('\n    { "WallRideExitTurn", "num", 0, 1, ', 1, true)
    all = check("M: (233) the four new keys sit right after WallRideArm in S (before DevKeys) and in the ini, in that order", s4 ~= nil and de ~= nil and s4 < de and ae ~= nil and p1 == ae and p2 ~= nil and p3 ~= nil and p4 ~= nil and p1 < p2 and p2 < p3 and p3 < p4) and all
    all = check("M: (233) WallRideMaxAngle's ini line says it is no longer used (since build " .. BUILD .. " or before)", src:find('{ "WallRideMaxAngle", "num", 5, 60, "no longer used since build ', 1, true) ~= nil) and all
    all = check("M: (233) the switches are rounded whole before they are sent", src:find('or k == "WallRideSlamGuard" or k == "WallRideExitTurn" then v = math.floor(v + 0.5) end', 1, true) ~= nil) and all
    all = check("M: WallRideMinWall's ini line says it is no longer used (since build " .. BUILD .. " or before)", src:find('{ "WallRideMinWall", "num", 20, 150, "no longer used since build ', 1, true) ~= nil) and all
    local keys = src:match("\nNATIVE%.WALL_KEYS = (%b{})") or ""
    local nk, k14, k18, k2, k19, k20, k21 = 0, nil, nil, nil, nil, nil, nil
    for k in keys:gmatch('"(%w+)"') do nk = nk + 1 if nk == 14 then k14 = k elseif nk == 18 then k18 = k elseif nk == 2 then k2 = k elseif nk == 19 then k19 = k elseif nk == 20 then k20 = k elseif nk == 21 then k21 = k end end
    all = check("M: NATIVE.WALL_KEYS: " .. nk .. " names, the 2nd " .. tostring(k2) .. ", the 14th " .. tostring(k14) .. ", the 18th " .. tostring(k18) .. ", the 19th-21st " .. tostring(k19) .. " " .. tostring(k20) .. " " .. tostring(k21), nk == 21 and k14 == "WallRideTopRoom" and k18 == "WallRideArm" and k2 == "WallRideMaxApproach" and k19 == "WallRideCarveKeep" and k20 == "WallRideSlamGuard" and k21 == "WallRideExitTurn"
        and keys:find('"WallRideMinWall"', 1, true) == nil and keys:find('"WallRideMaxAngle"', 1, true) == nil) and all
end
local o = assert(io.open("wall233_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the wallride test failed (build " .. tostring(BUILD) .. "): see wall233_out.txt", 0) end

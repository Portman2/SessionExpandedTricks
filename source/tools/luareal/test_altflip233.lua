-- test_altflip233.lua (the alt flip set's Lua half with ROUND 2, w4\fimpl\mkf_lua.pl; made for build 233, stackable: the
-- build and native numbers are read off the file; it replaces test_altflip231.lua). ROUND 2 (18 Oct): the varial heel from
-- the alt crouch becomes a DAYDREAM FLIP (kind 4, its names); the monster's rate from the flick (AltMonsterFlick), its
-- MANUAL catch (AltMonsterCatch: the native half's "bail" news asks the mod's own doBail), its feet out (AltMonsterSplay,
-- AltMonsterSplayStyle) and wobble (AltMonsterWobble, AltMonsterDrift): 18 settings, 12 definitions, 4 more menu rows.
-- Run on build 232 (without round 2) the suite fails as a whole (the 18 keys, the 12 definitions, the daydream's names).
-- THE ALT FLIP SET: the back-foot stick pushed UP crouches for a second set of flip tricks -- the
-- game's ollie from there becomes a Monster Flip, its varial flip a Nightmare Flip (17 Oct). The native half (HJN_Alt)
-- does the stick and the board pose by pose; this half sends the settings (HJN_Alt("cfg", 18 numbers)) and the twelve
-- definitions (HJN_Alt("defs", ...)), holds a quarter-second window open every frame while no trick of the mod's own has
-- the board or the body, copies the native half's news into the log, renames the taken definition while HJN_Alt("state")
-- says its line is pending (and puts the game's own names back), scales the game's foot IK by HJN_Alt("feet"), keeps a
-- wallride from starting under an alt trick in the air and starts the trick traces.
-- NATIVE.ALT_PATHS .. "-- end of the alt flip set" is cut out of main.lua and run in real Lua against stand-ins for the
-- native half and the game: the engage / disengage as the Lua sees it (the window and the phases), the base trick ->
-- Monster / Nightmare mapping (the names), the turn's schedule as it reaches the feet, the names, the logs, the refusals.
-- The defaults, the ini's limits, the menu rows and the wiring (onFrame, NATIVE.sync, forgetWorld, the build numbers) are
-- read off the file itself. (The native half's own parts -- the back stick by stick mode / stance / switch, the input
-- machine, the monster's schedule -- run in alt_unit.cpp, cut out of hn_main.cpp, and in HJN_Alt("selftest") in game.)
-- luareal -run test_altflip233.lua result.txt main.lua   (writes altflip233_out.txt)
-- Run on a build without the alt flip set the suite fails as a whole: NATIVE.ALT_PATHS is not there.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("\nNATIVE.ALT_PATHS = {", 1, true), "NATIVE.ALT_PATHS was not found (a build without the alt flip set?)")
local b = assert(src:find("\n-- end of the alt flip set\n", a, true), "the end of the alt flip set was not found")
local body = src:sub(a + 1, b)
local BUILD = tonumber(src:match("\nNATIVE%.BUILD = (%d+)\n"))
local WANTV = tonumber(src:match("\nNATIVE%.WANT = (%d+) "))
assert(BUILD and WANTV, "NATIVE.BUILD / NATIVE.WANT not found")

-- the settings as the file has them: S's defaults and SPEC's limits and texts
local DEF, SPEC, SPECTXT = {}, {}, {}
do
    local sa = assert(src:find("\nlocal S = {\n", 1, true), "the S table was not found")
    local sb = assert(src:find("\n}\n", sa, true))
    for k, v in src:sub(sa, sb):gmatch("\n    (Alt%w*) = (%-?[%d%.]+),") do DEF[k] = tonumber(v) end
    DEF.TrickNames = tonumber(src:sub(sa, sb):match("\n    TrickNames%s*=%s*(%d+),"))
    for line in src:gmatch("\n(    { \"[%w]+\", \"num\",[^\n]*)") do
        local k, lo, hi, txt = line:match('^    { "(%w+)",%s*"num",%s*(%-?[%d%.]+),%s*(%-?[%d%.]+),%s*"(.*)" },?%s*$')
        if k and (k:sub(1, 3) == "Alt" or k == "TrickNames") then SPEC[#SPEC + 1] = { k, "num", tonumber(lo), tonumber(hi), txt } SPECTXT[k] = txt end
    end
end

local out, all = {}, true
local function check(name, cond, W)
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        for _, c in ipairs(W.calls) do local t = {} for i = 1, #c do t[i] = tostring(c[i]) end out[#out + 1] = "       HJN_Alt(" .. table.concat(t, ", ") .. ")" end
        for _, c in ipairs(W.tn) do out[#out + 1] = "       HJN_TrickName(" .. table.concat({ tostring(c[1]), tostring(c[2]), tostring(c[3]) }, ", ") .. ")" end
        for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l:sub(1, 300) end
    end
    return cond
end

local PATHS = { "/Game/Data/Input/FlipTricks/TRICK_RGS_Ollie.TRICK_RGS_Ollie", "/Game/Data/Input/FlipTricks/TRICK_SWS_Ollie.TRICK_SWS_Ollie",
    "/Game/Data/Input/FlipTricks/TRICK_NLS_Nollie.TRICK_NLS_Nollie", "/Game/Data/Input/FlipTricks/TRICK_FKS_Ollie.TRICK_FKS_Ollie",
    "/Game/Data/Input/FlipTricks/TRICK_RGS_VarialFlip.TRICK_RGS_VarialFlip", "/Game/Data/Input/FlipTricks/TRICK_SWS_VarialFlip.TRICK_SWS_VarialFlip",
    "/Game/Data/Input/FlipTricks/TRICK_NLS_VarialFlip.TRICK_NLS_VarialFlip", "/Game/Data/Input/FlipTricks/TRICK_FKS_VarialFlip.TRICK_FKS_VarialFlip",
    "/Game/Data/Input/FlipTricks/TRICK_RGS_VarialHeel.TRICK_RGS_VarialHeel", "/Game/Data/Input/FlipTricks/TRICK_SWS_VarialHeel.TRICK_SWS_VarialHeel",
    "/Game/Data/Input/FlipTricks/TRICK_NLS_VarialHeel.TRICK_NLS_VarialHeel", "/Game/Data/Input/FlipTricks/TRICK_FKS_VarialHeel.TRICK_FKS_VarialHeel" }
local ORIG = { TRICK_RGS_Ollie = "Ollie", TRICK_SWS_Ollie = "Switch Ollie", TRICK_NLS_Nollie = "Nollie", TRICK_FKS_Ollie = "Fakie Ollie", TRICK_RGS_VarialFlip = "Varial Flip",
    TRICK_SWS_VarialFlip = "Switch Varial Flip", TRICK_NLS_VarialFlip = "Nollie Varial Flip", TRICK_FKS_VarialFlip = "Fakie Varial Flip",
    TRICK_RGS_VarialHeel = "Varial Heel", TRICK_SWS_VarialHeel = "Switch Varial Heel", TRICK_NLS_VarialHeel = "Nollie Varial Heel", TRICK_FKS_VarialHeel = "Fakie Varial Heel" }
local NDEF = #PATHS   -- 12
local ENUMP = "/Script/SessionGame.EEventLineTrickRotationType"
-- the enum's names (values moved off the exe's on purpose, so a key read off the enum is told from the fallback)
local ENUM = { [0] = "ELTRT_None", [11] = "ELTRT_Frontside", [12] = "ELTRT_Frontside360", [13] = "ELTRT_Frontside540", [14] = "ELTRT_Frontside720",
    [3] = "ELTRT_Backside", [4] = "ELTRT_Backside360", [5] = "ELTRT_Backside540", [6] = "ELTRT_Backside720" }
local ENUMKEY = { Frontside = 11, Frontside360 = 12, Frontside540 = 13, Frontside720 = 14, Backside = 3, Backside360 = 4, Backside540 = 5, Backside720 = 6 }
local FALLBACK = { Frontside = 1, Frontside360 = 2, Frontside540 = 3, Frontside720 = 4, Backside = 7, Backside360 = 8, Backside540 = 9, Backside720 = 10 }

-- a world: the native half's answers (W.okAns, W.cfgAns, W.defsAns, W.state, W.feet, W.news), the eight definitions and the
-- enum (W.missing = a definition not found, W.noEnum), the mod's settings (W.set), W.wallWhy (NATIVE.wallBlock's answer), W.off
local function world(opt)
    local W = { logs = {}, calls = {}, news = {}, tn = {}, traces = {}, wall = {}, dn = {}, okAns = 1, cfgAns = 18, defsAns = 12, state = "0 0 0 0 0", feet = -1, nv = WANTV,
        inst = { LeftFootIKAlpha = 1.0, RightFootIKAlpha = 1.0 }, objs = {}, byName = {}, bails = {}, bailAns = true }
    for k, v in pairs(opt or {}) do W[k] = v end
    for i, path in ipairs(PATHS) do
        local name = path:match("%.([%w_]+)$")
        if name ~= W.missing then
            local o = { _name = name, _addr = 0x7ff600000000 + i * 0x1000, _display = (W.pre and W.pre[name]) or ORIG[name], _valid = true }
            setmetatable(o, {
                __index = function(t, k)
                    if k == "DisplayName" then return { ToString = function() return rawget(t, "_display") end } end
                    if k == "GetAddress" then return function() return rawget(t, "_addr") end end
                    if k == "IsValid" then return function() return rawget(t, "_valid") end end
                    return nil
                end,
                __newindex = function(t, k, v)
                    if k == "DisplayName" then rawset(t, "_display", type(v) == "table" and v.text or tostring(v)) W.dn[#W.dn + 1] = rawget(t, "_name") .. "=" .. tostring(rawget(t, "_display"))
                    else rawset(t, k, v) end
                end })
            W.objs[path] = o W.byName[name] = o
        end
    end
    if not W.noEnum then
        W.objs[ENUMP] = { GetNameByValue = function(_, v) local nm = ENUM[v] return { ToString = function() return nm and ("EEventLineTrickRotationType::" .. nm) or "" end } end,
            IsValid = function() return true end, GetAddress = function() return 0x7ff6ffff0000 end }
    end
    local env = { ipairs = ipairs, pairs = pairs, next = next, tonumber = tonumber, tostring = tostring, type = type, pcall = pcall, select = select, error = error,
        setmetatable = setmetatable, rawget = rawget, rawset = rawset, string = string, table = table, math = math }
    if not W.noAlt then
        env.HJN_Alt = function(op, ...)
            W.calls[#W.calls + 1] = { op, ... }
            if W.throw then error("the stand-in throws", 0) end
            if op == "ok" then return W.okAns end
            if op == "news" then return table.remove(W.news, 1) or "" end
            if op == "cfg" then return W.cfgAns end
            if op == "defs" then return W.defsAns end
            if op == "state" then return W.state end
            if op == "feet" then return W.feet end
            if op == "selftest" then return "ok 35 checks; the stick mode 2 (front/back-foot), the back stick RIGHT" end
            return 1
        end
    end
    env.HJN_TrickName = function(ad, key, text) W.tn[#W.tn + 1] = { ad, key, text } return 1 end
    env.HJN_TrickTrace = function(n, tag) W.traces[#W.traces + 1] = tostring(n) .. " " .. tostring(tag) return n end
    env.HJN_Wall = function(op, v) W.wall[#W.wall + 1] = tostring(op) .. " " .. tostring(v) return 1 end
    -- (round 2) the mod's own doBail (a file-level local of main.lua, an upvalue there: a stand-in here) -- W.noBail: none in reach
    if not W.noBail then env.doBail = function(why, residual) W.bails[#W.bails + 1] = { why, residual } return W.bailAns end end
    env.FText = function(s) return { text = s } end
    env.StaticFindObject = function(p) return W.objs[p] end
    local S = { TraceLog = 1 }
    for k, v in pairs(DEF) do S[k] = v end
    for k, v in pairs(W.set or {}) do S[k] = v end
    local NATIVE = { v = W.nv, WANT = WANTV, DEF = DEF, off = W.off }
    NATIVE.wallBlock = function() return W.wallWhy end
    local prelude = [[
local NATIVE, S, W, SPEC = ...
local inst = W.inst
local function log(s) W.logs[#W.logs + 1] = tostring(s) end
local function q(fn, dflt) local ok, v = pcall(fn) if ok and v ~= nil then return v end return dflt end
local function alive(x) if x == nil then return nil end if q(function() return x:IsValid() end, false) then return x end return nil end
local function addr(o) return q(function() return o:GetAddress() end, nil) end
]]
    W.N = assert(load(prelude .. body .. "\nreturn NATIVE\n", "=altflip", "t", env))(NATIVE, S, W, SPEC)
    W.S = S
    return W
end
local function near(x, y, e) return type(x) == "number" and math.abs(x - y) <= (e or 1e-6) end
local function calls(W, op) local r = {} for _, c in ipairs(W.calls) do if c[1] == op then r[#r + 1] = c end end return r end
local function logged(W, pat) local n = 0 for _, l in ipairs(W.logs) do if l:find(pat, 1, true) then n = n + 1 end end return n end
local function lastOk(W) local c = calls(W, "ok") return c[#c] and c[#c][2] end
local function addrOf(W, name) return W.byName[name] and rawget(W.byName[name], "_addr") end
local function displayOf(W, name) return W.byName[name] and rawget(W.byName[name], "_display") end
local function ready(W) W.N.altCfg() W.calls = {} W.logs = {} return W end   -- the settings sent and the definitions found, as NATIVE.sync does first

local KEYS = { "AltFlips", "AltFlipEngage", "AltFlipRelease", "AltMonster", "AltMonsterSpeed", "AltMonsterNoseUp", "AltMonsterClear", "AltMonsterTuck", "AltNightmare", "AltNightmareSpeed", "AltFlipTraces",
    "AltDaydream", "AltMonsterFlick", "AltMonsterCatch", "AltMonsterSplay", "AltMonsterSplayStyle", "AltMonsterWobble", "AltMonsterDrift" }
local WANTDEF = { AltFlips = 1, AltFlipEngage = 0.5, AltFlipRelease = 0.3, AltMonster = 1, AltMonsterSpeed = 1.0, AltMonsterNoseUp = 1, AltMonsterClear = 45, AltMonsterTuck = 15,
    AltNightmare = 1, AltNightmareSpeed = 2.0, AltFlipTraces = 3,
    AltDaydream = 1, AltMonsterFlick = 1, AltMonsterCatch = 1, AltMonsterSplay = 4, AltMonsterSplayStyle = 0, AltMonsterWobble = 12, AltMonsterDrift = 8 }
local LIMITS = { AltFlips = { 0, 1 }, AltFlipEngage = { 0.25, 0.95 }, AltFlipRelease = { 0.1, 0.6 }, AltMonster = { 0, 1 }, AltMonsterSpeed = { 0.5, 2.5 }, AltMonsterNoseUp = { 0, 1 },
    AltMonsterClear = { 25, 90 }, AltMonsterTuck = { 0, 40 }, AltNightmare = { 0, 1 }, AltNightmareSpeed = { 1, 3 }, AltFlipTraces = { 0, 20 },
    AltDaydream = { 0, 1 }, AltMonsterFlick = { 0, 1 }, AltMonsterCatch = { 0, 2 }, AltMonsterSplay = { 0, 20 }, AltMonsterSplayStyle = { 0, 3 }, AltMonsterWobble = { 0, 30 }, AltMonsterDrift = { 0, 20 } }
local CFG0 = { 1, 0.5, 0.3, 1, 1.0, 1, 45, 15, 1, 2.0, 1, 1, 1, 1, 4, 0, 12, 8 }
local NCFG = #CFG0   -- 18

-- A. the 18 settings: a default in S, an ini line with its limits, the default inside them; the menu; the numbers
do
    local bad = {}
    for _, k in ipairs(KEYS) do if not near(DEF[k], WANTDEF[k]) then bad[#bad + 1] = k .. "=" .. tostring(DEF[k]) end end
    all = check("A: the 18 defaults in S (" .. ((#bad == 0) and "all as designed" or table.concat(bad, " ")) .. ")", #bad == 0) and all
    local seen, badl, nAlt = {}, {}, 0
    for _, sp in ipairs(SPEC) do
        if sp[1]:sub(1, 3) == "Alt" then
            nAlt = nAlt + 1 seen[sp[1]] = true
            local L = LIMITS[sp[1]]
            if not L or sp[3] ~= L[1] or sp[4] ~= L[2] then badl[#badl + 1] = sp[1] end
            if not (DEF[sp[1]] and DEF[sp[1]] >= sp[3] and DEF[sp[1]] <= sp[4]) then badl[#badl + 1] = sp[1] .. " (default outside)" end
        end
    end
    for k in pairs(LIMITS) do if not seen[k] then badl[#badl + 1] = k .. " (missing)" end end
    all = check("A: 18 ini lines with the designed limits, every default inside them (" .. nAlt .. " found" .. ((#badl == 0) and "" or ("; wrong: " .. table.concat(badl, " "))) .. ")", nAlt == 18 and #badl == 0) and all
    all = check("A: the AltFlips line names the native half v" .. WANTV .. ", the scoop's SAME side and the Daydream Flip", (SPECTXT.AltFlips or ""):find("Takes the native half v" .. WANTV, 1, true) ~= nil
        and (SPECTXT.AltFlips or ""):find("SAME side", 1, true) ~= nil and (SPECTXT.AltFlips or ""):find("= Daydream Flip", 1, true) ~= nil) and all
    all = check("A: the texts name the daydream's speed (AltNightmareSpeed), the flick (AltMonsterSpeed) and the manual catch (AltMonster)", (SPECTXT.AltNightmareSpeed or ""):find("daydream", 1, true) ~= nil
        and (SPECTXT.AltMonsterSpeed or ""):find("AltMonsterFlick", 1, true) ~= nil and (SPECTXT.AltMonster or ""):find("AltMonsterCatch", 1, true) ~= nil
        and (SPECTXT.AltDaydream or ""):find("AltNightmareSpeed", 1, true) ~= nil) and all
    all = check("A: build " .. BUILD .. " / native v" .. WANTV .. " (233 / 131 or later), and the loaded line says so", BUILD >= 233 and WANTV >= 131
        and src:find("loaded (v" .. BUILD .. " / native v" .. WANTV .. ")", 1, true) ~= nil) and all
    local m1 = src:find('\n    { "General gameplay settings", {\n', 1, true)
    local m2 = m1 and src:find("\n    } },\n", m1, true)
    local page = (m1 and m2) and src:sub(m1, m2) or ""
    local rows = {
        { '{ "toggle", "AltFlips", "Alt flip set (back stick up)", 1, 1, "', "On" },
        { '{ "toggle", "AltMonsterNoseUp", "Monster flip: nose up first", 1, 1, "', "On" },
        { '{ "slider", "AltNightmareSpeed", "Nightmare flip: flip speed", 100, 10, "', "200 %" },
        { '{ "toggle", "AltDaydream", "Daydream flip (varial heel)", 1, 1, "', "On" },
        { '{ "slider", "AltMonsterCatch", "Monster flip: catch", 1, 1, "', "1" },
        { '{ "slider", "AltMonsterSplay", "Monster flip: feet out", 1, 1, "', "4 cm" },
        { '{ "slider", "AltMonsterWobble", "Monster flip: wobble", 1, 1, "', "12 degrees" } }
    local badr, lens = {}, {}
    for _, r in ipairs(rows) do
        local p = page:find(r[1], 1, true)
        local desc = p and page:sub(p + #r[1]):match('^(.-)"') or nil
        if not desc then badr[#badr + 1] = r[1]:match('"(Alt%w+)"') .. " (missing)"
        else
            lens[#lens + 1] = tostring(#desc + #(" Default: " .. r[2] .. "."))
            if #desc + #(" Default: " .. r[2] .. ".") > 239 then badr[#badr + 1] = r[1]:match('"(Alt%w+)"') .. " (" .. #desc .. " characters)" end
        end
    end
    all = check("A: seven rows on General gameplay settings, each text within 239 with its default (" .. table.concat(lens, " ") .. "; " .. ((#badr == 0) and "ok" or table.concat(badr, ", ")) .. ")", #badr == 0) and all
    all = check("A: the AltFlips row names the Daydream Flip; the four new rows come right after the nightmare's speed", (page:match('"AltFlips", "Alt flip set %(back stick up%)", 1, 1, "([^"]*)"') or ""):find("Daydream Flip", 1, true) ~= nil
        and page:find('unit = "%%" },\n        { "toggle", "AltDaydream",') ~= nil and page:find('"AltMonsterCatch", "Monster flip: catch", 1, 1, "[^"]*", 0, 2 }') ~= nil
        and page:find('"AltMonsterSplay", "Monster flip: feet out", 1, 1, "[^"]*", 0, 20, unit = "cm" }') ~= nil and page:find('"AltMonsterWobble", "Monster flip: wobble", 1, 1, "[^"]*", 0, 30, unit = "degrees" }') ~= nil) and all
    local nrows = 0 for _ in page:gmatch('\n        { "[a-z]+", "') do nrows = nrows + 1 end
    all = check("A: the General page holds " .. nrows .. " rows (48 at the most in the native half)", nrows >= 16 and nrows <= 48) and all
    all = check("A: the nightmare's slider runs 100..300 %", page:find('"Nightmare flip: flip speed", 100, 10, "[^"]*", 1%.0, 3%.0, unit = "%%" }') ~= nil) and all
    local quick = src:match("\nNATIVE%.MENU_QUICK = (%b{})") or ""
    local nq = 0 for _ in quick:gmatch('"%w+"') do nq = nq + 1 end
    all = check("A: the Quick page is left as it was (" .. nq .. " rows, no AltFlips: design_review 10)", nq <= 14 and not quick:find("Alt", 1, true) and not src:find("MENU_QUICK[#NATIVE.MENU_QUICK + 1]", 1, true)) and all
end
-- B. the settings to the native half: HJN_Alt("cfg", 18 numbers) in its order, once per change, clamped; the definitions and the self-test once
do local W = world()
    W.N.altCfg()
    local c = calls(W, "cfg")[1]
    local same = c ~= nil and #c == NCFG + 1
    if same then for i = 1, NCFG do if not near(c[i + 1], CFG0[i]) then same = false end end end
    local shown = {} if c then for i = 2, #c do shown[#shown + 1] = tostring(c[i]) end end
    all = check("B: HJN_Alt('cfg', " .. table.concat(shown, " ") .. ") -- 18 numbers, the 7 new ones last", same, W) and all
    local l = W.logs[1] or ""
    all = check("B: the settings line says ON with the numbers, nothing refused", l:find("native: alt flips ON: the back-foot stick up past 0.50 (within 40 deg of straight up) crouches for the alt set, let go inside 0.30;", 1, true) ~= nil
        and l:find("(x1.00 your kickflip speed, the leading end up first, room 45 cm, the feet tucked 15 cm)", 1, true) ~= nil and l:find("(its flip x2.00;", 1, true) ~= nil
        and l:find("the first 3 traced", 1, true) ~= nil and l:find(" -- ", 1, true) == nil, W) and all
    all = check("B: ...and its round-2 tail", l:find("the alt names on the trick display on; Daydream Flip on the varial heel on; the monster's speed from your flick on, its catch as your game's Catch setting, the feet out 4 cm (the leading foot toward the toes), wobble 12 deg, drift 8 deg; the first 3 traced", 1, true) ~= nil, W) and all
    local d = calls(W, "defs")[1]
    local order = d ~= nil and #d == NDEF + 1
    if order then for i, p in ipairs(PATHS) do if d[i + 1] ~= addrOf(W, p:match("%.([%w_]+)$")) then order = false end end end
    all = check("B: HJN_Alt('defs', the 12 addresses in the native half's order: RGS/SWS ollie, nollie, fakie ollie, the 4 varial flips, the 4 varial heels)", order, W) and all
    all = check("B: '12 of 12 trick definitions found ... 12 taken'; the self-test logged once", logged(W, "alt flips: 12 of 12 trick definitions found (ollie x4, varial flip x4, varial heel x4), 12 taken by the native half") == 1
        and logged(W, "alt flips: the native half's self-test: ok 35 checks") == 1, W) and all
    W.N.altCfg() W.N.altCfg()
    all = check("B: sent once while nothing changes (no second defs / self-test)", #calls(W, "cfg") == 1 and #calls(W, "defs") == 1 and #calls(W, "selftest") == 1, W) and all
    W.S.AltMonsterSpeed = 1.5
    W.N.altCfg()
    all = check("B: sent again when a setting changes", #calls(W, "cfg") == 2 and near(calls(W, "cfg")[2][6], 1.5), W) and all
    W.S.AltMonsterWobble = 20
    W.N.altCfg()
    all = check("B: ...a new one too (AltMonsterWobble 20: the 17th number)", #calls(W, "cfg") == 3 and near(calls(W, "cfg")[3][18], 20), W) and all
end
do local W = world({ set = { AltFlipEngage = 2, AltFlipRelease = 0.6, AltFlips = 0.6, AltMonster = 0.4, AltMonsterClear = 5, AltNightmareSpeed = 9, TrickNames = 0 } })
    W.N.altCfg()
    local c = calls(W, "cfg")[1] or {}
    all = check("B: clamped: engage 0.95, release kept under it (0.6 -> 0.6), toggles rounded (0.6 -> 1, 0.4 -> 0), room 25, nightmare x3, names off",
        near(c[3], 0.95) and near(c[4], 0.6) and c[2] == 1 and c[5] == 0 and near(c[8], 25) and near(c[11], 3) and c[12] == 0, W) and all
end
do local W = world({ set = { AltDaydream = 0.4, AltMonsterFlick = 0.6, AltMonsterCatch = 2.6, AltMonsterSplay = -5, AltMonsterSplayStyle = 9, AltMonsterWobble = 99, AltMonsterDrift = 21 } })
    W.N.altCfg()
    local c = calls(W, "cfg")[1] or {}
    all = check("B: the new ones clamped by the ini's limits, the toggles rounded (daydream 0.4 -> 0, flick 0.6 -> 1, catch 2.6 -> 2, splay -5 -> 0, style 9 -> 3, wobble 99 -> 30, drift 21 -> 20)",
        c[13] == 0 and c[14] == 1 and c[15] == 2 and near(c[16], 0) and c[17] == 3 and near(c[18], 30) and near(c[19], 20), W) and all
    local l = W.logs[1] or ""
    all = check("B: ...said so (daydream off, catch always manual, feet out 0 cm, both toward the toes)", l:find("Daydream Flip on the varial heel off; the monster's speed from your flick on, its catch always manual, the feet out 0 cm (both toward the toes), wobble 30 deg, drift 20 deg", 1, true) ~= nil, W) and all
end
do local W = world({ set = { AltMonsterSplayStyle = 1.4, AltMonsterCatch = 0.4 } })
    W.N.altCfg()
    local c = calls(W, "cfg")[1] or {}
    all = check("B: style 1.4 -> 1, catch 0.4 -> 0 (one turn by itself)", c[17] == 1 and c[15] == 0 and (W.logs[1] or ""):find("its catch one turn by itself", 1, true) ~= nil, W) and all
end
do local W = world({ set = { AltFlipEngage = 0.4, AltFlipRelease = 0.5 } })
    W.N.altCfg()
    local c = calls(W, "cfg")[1] or {}
    all = check("B: the release kept under the engage (0.4 / 0.5 -> 0.35)", near(c[3], 0.4) and near(c[4], 0.35, 1e-9), W) and all
end
do local W = world({ noAlt = true })
    W.N.altCfg() W.N.altTick() W.N.altTick()
    all = check("B: a native half without HJN_Alt: the settings line NOT TAKEN naming v" .. WANTV .. ", nothing else, no error", #W.logs == 1
        and logged(W, "-- NOT TAKEN: the native half (v" .. WANTV .. ") has no HJN_Alt; the alt flip set needs the v" .. WANTV .. " made with this main.lua") == 1, W) and all
end
do local W = world({ cfgAns = -1 })
    W.N.altCfg()
    all = check("B: stood down (another build): said in the settings line", logged(W, " -- stood down: not on this build of the game") == 1, W) and all
end
do local W = world({ cfgAns = 7 })
    W.N.altCfg()
    all = check("B: a short answer: REFUSED (7 of 18 taken)", logged(W, " -- REFUSED by the native half (7 of 18 taken;") == 1, W) and all
end
do local W = world({ cfgAns = 11 })
    W.N.altCfg()
    all = check("B: an older native half (it takes the first 11): REFUSED (11 of 18 taken) -- said", logged(W, " -- REFUSED by the native half (11 of 18 taken;") == 1, W) and all
end
do local W = world({ set = { TraceLog = 0 } })
    W.N.altCfg()
    all = check("B: TraceLog=0: the first 0 traced", logged(W, "the first 0 traced") == 1, W) and all
end
-- C. the definitions: a missing one is a 0 in its slot, said; none at all: looked for again later (not sent)
do local W = world({ missing = "TRICK_NLS_Nollie", defsAns = 11 })
    W.N.altCfg()
    local d = calls(W, "defs")[1] or {}
    all = check("C: a definition not found: 0 in its slot (the 3rd), said by name", d[4] == 0 and d[2] == addrOf(W, "TRICK_RGS_Ollie")
        and logged(W, "11 of 12 trick definitions found (ollie x4, varial flip x4, varial heel x4), 11 taken by the native half -- not found: TRICK_NLS_Nollie") == 1, W) and all
end
do local W = world({ missing = "TRICK_SWS_VarialHeel", defsAns = 11 })
    W.N.altCfg()
    local d = calls(W, "defs")[1] or {}
    all = check("C: a varial heel not found: 0 in its slot (the 10th), the others sent, said by name", #d == NDEF + 1 and d[11] == 0 and d[10] == addrOf(W, "TRICK_RGS_VarialHeel") and d[13] == addrOf(W, "TRICK_FKS_VarialHeel")
        and logged(W, "11 of 12 trick definitions found (ollie x4, varial flip x4, varial heel x4), 11 taken by the native half -- not found: TRICK_SWS_VarialHeel") == 1, W) and all
end
do local W = world()
    for _, p in ipairs(PATHS) do W.objs[p] = nil end
    W.N.altCfg() W.N.altCfg()
    all = check("C: none found yet: nothing sent, looked for again at the next pass", #calls(W, "defs") == 0 and #calls(W, "selftest") == 0 and W.N.alt.tries == 2, W) and all
end
-- D. the window: 0.25 s every frame when on and free; shut for AltFlips 0, the mod off, each trick of the mod's; the refusals
do local W = ready(world())
    W.N.altTick() W.N.altTick() W.N.altTick()
    local oks = calls(W, "ok")
    all = check("D: 3 frames: 'ok', 0.25 each time", #oks == 3 and oks[1][2] == 0.25 and oks[3][2] == 0.25, W) and all
end
do local W = ready(world({ set = { AltFlips = 0 } }))
    W.N.altTick()
    all = check("D: AltFlips=0: 'ok', 0 (the window shut)", lastOk(W) == 0, W) and all
end
do local W = ready(world({ set = { AltFlips = 0.4 } }))
    W.N.altTick()
    all = check("D: AltFlips=0.4 counts as off (rounded as the settings line does)", lastOk(W) == 0, W) and all
end
for _, why in ipairs({ "a hippie jump", "a no comply", "the caveman", "a drop-in", "the replay" }) do
    local W = ready(world({ wallWhy = why }))
    W.N.altTick()
    all = check("D: " .. why .. " (NATIVE.wallBlock): 'ok', 0", lastOk(W) == 0, W) and all
end
do local W = ready(world({ off = true }))
    W.N.altTick()
    all = check("D: the mod switched off on this build: 'ok', 0 and nothing else asked", lastOk(W) == 0 and #W.calls == 1, W) and all
end
do local W = ready(world({ okAns = -1 }))
    W.N.altTick() W.N.altTick() W.N.altTick()
    all = check("D: stood down: said once in 3 frames, nothing else asked", logged(W, "alt flips: not on this build of the game") == 1 and #calls(W, "state") == 0, W) and all
end
do local W = ready(world({ okAns = 0 }))
    W.N.altTick() W.N.altTick()
    all = check("D: the native half turned the set off (a fault): said once", logged(W, "alt flips: the native half has turned the alt flip set off for this run") == 1, W) and all
end
do local W = ready(world())
    W.throw = true
    W.N.altTick() W.N.altTick()
    all = check("D: HJN_Alt raising an error: said once, no error out of altTick", logged(W, "alt flips: the native half's HJN_Alt raised an error (the stand-in throws)") == 1, W) and all
end
-- E. the news: into the log, its tag dropped, at most 8 a frame
do local W = ready(world())
    for i = 1, 10 do W.news[#W.news + 1] = (i == 1 and "taken #1 MONSTER FLIP on Ollie (TRICK_RGS_Ollie), 0.21 s after the alt crouch began" or ("info line " .. i)) end
    W.N.altTick()
    local n1 = logged(W, "alt flips: ")
    W.N.altTick()
    all = check("E: 10 news lines: 8 this frame, 2 the next", n1 == 8 and logged(W, "alt flips: ") == 10, W) and all
    all = check("E: the tag dropped ('taken #1 ...' -> 'alt flips: #1 MONSTER FLIP on Ollie ...')", W.logs[1] == "alt flips: #1 MONSTER FLIP on Ollie (TRICK_RGS_Ollie), 0.21 s after the alt crouch began", W) and all
end
-- F. the names: the taken definition renamed while its line is pending, put back after; never two; TrickNames=0 none
do local W = ready(world())
    local ra = addrOf(W, "TRICK_RGS_Ollie")
    W.state = string.format("2 1 %d 1 1", ra)
    W.N.altTick()
    local keys, texts = {}, {}
    for _, c in ipairs(W.tn) do if c[1] == ra then keys[c[2]] = c[3] end end
    local ok = displayOf(W, "TRICK_RGS_Ollie") == "Monster Flip"
    for k, v in pairs(ENUMKEY) do texts[v] = k end
    local want = { Frontside = "Frontside Monster Flip 180", Backside = "Backside Monster Flip 180", Frontside360 = "FS Monster Flip 360", Backside360 = "BS Monster Flip 360",
        Frontside540 = "FS Monster Flip 540", Backside540 = "BS Monster Flip 540", Frontside720 = "FS Monster Flip 720", Backside720 = "BS Monster Flip 720" }
    local nk = 0
    for kv, text in pairs(keys) do nk = nk + 1 if want[texts[kv] or "?"] ~= text then ok = false end end
    all = check("F: an alt monster on the Ollie: DisplayName 'Monster Flip' and its 8 rotation texts by the enum's keys (the 180 kept)", ok and nk == 8, W) and all
    all = check("F: ...said once", logged(W, "alt flips: the game's names for TRICK_RGS_Ollie read 'Monster Flip' until its line is shown (9 of 9 texts written)") == 1, W) and all
    local n0 = #W.tn
    W.state = string.format("3 1 %d 1 1", ra) W.N.altTick() W.N.altTick()
    all = check("F: landed, its line pending: nothing written again", #W.tn == n0 and #W.dn == 1, W) and all
    W.state = string.format("0 0 0 1 0") W.N.altTick()
    local back = 0
    for i = n0 + 1, #W.tn do if W.tn[i][1] == ra and W.tn[i][3] == "" then back = back + 1 end end
    all = check("F: its line shown: the game's own 'Ollie' back and '' for each of the 8 keys", displayOf(W, "TRICK_RGS_Ollie") == "Ollie" and back == 8 and W.N.alt.renamed == nil, W) and all
end
do local W = ready(world())
    local sa, va = addrOf(W, "TRICK_SWS_Ollie"), addrOf(W, "TRICK_RGS_VarialFlip")
    W.state = string.format("2 1 %d 1 1", sa) W.N.altTick()
    W.state = string.format("2 2 %d 2 1", va) W.N.altTick()
    all = check("F: a nightmare while a switch monster's line is pending: 'Switch Ollie' back first, then 'Nightmare Flip'", displayOf(W, "TRICK_SWS_Ollie") == "Switch Ollie"
        and displayOf(W, "TRICK_RGS_VarialFlip") == "Nightmare Flip" and W.dn[2] == "TRICK_SWS_Ollie=Switch Ollie" and W.dn[3] == "TRICK_RGS_VarialFlip=Nightmare Flip", W) and all
    local bs
    for _, c in ipairs(W.tn) do if c[1] == va and c[2] == ENUMKEY.Backside then bs = c[3] end end
    all = check("F: the nightmare's BS text 'BS Big Nightmare Flip' (from the game's 'BS Big Flip')", bs == "BS Big Nightmare Flip", W) and all
end
do local W = ready(world({ set = { TrickNames = 0 } }))
    W.state = string.format("2 1 %d 1 1", addrOf(W, "TRICK_RGS_Ollie")) W.N.altTick()
    all = check("F: TrickNames=0: nothing renamed", #W.dn == 0 and #W.tn == 0, W) and all
end
do local W = ready(world({ pre = { TRICK_RGS_Ollie = "Monster Flip" } }))
    local ra = addrOf(W, "TRICK_RGS_Ollie")
    W.state = string.format("2 1 %d 1 1", ra) W.N.altTick()
    W.state = "0 0 0 1 0" W.N.altTick()
    all = check("F: a definition left renamed by a run that stopped: the game's own 'Ollie' put back, not 'Monster Flip'", displayOf(W, "TRICK_RGS_Ollie") == "Ollie", W) and all
end
do local W = ready(world({ noEnum = true }))
    local ra = addrOf(W, "TRICK_RGS_Ollie")
    W.state = string.format("2 1 %d 1 1", ra) W.N.altTick()
    local fs
    for _, c in ipairs(W.tn) do if c[3] == "Frontside Monster Flip 180" then fs = c[2] end end
    all = check("F: no enum to read: the exe's keys (FS 1 ... BS 720 10)", fs == FALLBACK.Frontside and logged(W, "-- 0 of 8 read off the game's enum (FS 1, BS 7, FS 360 2, BS 360 8, FS 540 3, BS 540 9, FS 720 4, BS 720 10)") == 1, W) and all
end
do local W = ready(world())
    local ra = addrOf(W, "TRICK_RGS_Ollie")
    W.state = string.format("2 1 %d 1 1", ra) W.N.altTick()
    W.N.altNames(nil)
    rawset(W.byName.TRICK_RGS_Ollie, "_valid", false)
    W.state = string.format("2 1 %d 1 1", ra) W.N.altTick()
    all = check("F: a definition gone dead (a level change): not written through", displayOf(W, "TRICK_RGS_Ollie") == "Ollie" and #W.dn == 2, W) and all
end
-- (round 2) the daydream's names: kind 4 on TRICK_RGS_VarialHeel / TRICK_SWS_VarialHeel
do local W = ready(world())
    local ha = addrOf(W, "TRICK_RGS_VarialHeel")
    W.state = string.format("2 4 %d 7 1", ha) W.N.altTick()
    local keys = {}
    for _, c in ipairs(W.tn) do if c[1] == ha then keys[c[2]] = c[3] end end
    local nk = 0 for _ in pairs(keys) do nk = nk + 1 end
    all = check("F: a daydream on the Varial Heel: DisplayName 'Daydream Flip', 'FS Big Daydream Flip' / 'Daydream Flip Body Varial' by the enum's keys", displayOf(W, "TRICK_RGS_VarialHeel") == "Daydream Flip"
        and keys[ENUMKEY.Frontside] == "FS Big Daydream Flip" and keys[ENUMKEY.Backside] == "Daydream Flip Body Varial" and nk == 2
        and logged(W, "alt flips: the game's names for TRICK_RGS_VarialHeel read 'Daydream Flip' until its line is shown (3 of 3 texts written)") == 1, W) and all
    local n0 = #W.tn
    W.state = "0 0 0 7 0" W.N.altTick()
    local back = 0
    for i = n0 + 1, #W.tn do if W.tn[i][1] == ha and W.tn[i][3] == "" then back = back + 1 end end
    all = check("F: ...its line shown: the game's own 'Varial Heel' back and '' for both keys", displayOf(W, "TRICK_RGS_VarialHeel") == "Varial Heel" and back == 2 and W.N.alt.renamed == nil, W) and all
end
do local W = ready(world())
    local sa = addrOf(W, "TRICK_SWS_VarialHeel")
    W.state = string.format("2 4 %d 8 1", sa) W.N.altTick()
    all = check("F: a switch daydream: 'Switch Daydream Flip'", displayOf(W, "TRICK_SWS_VarialHeel") == "Switch Daydream Flip", W) and all
end
-- G. the feet: the game's foot IK scaled by HJN_Alt("feet") (the turn's schedule: 1 .. 0 .. 1), left alone at -1 and at 1
do local W = ready(world())
    local seen = {}
    for _, fv in ipairs({ -1, 1, 0.47, 0, 0, 0.5, 1, -1 }) do
        W.inst.LeftFootIKAlpha, W.inst.RightFootIKAlpha = 0.9, 1.0
        W.feet = fv W.N.altTick()
        seen[#seen + 1] = string.format("%.3f/%.3f", W.inst.LeftFootIKAlpha, W.inst.RightFootIKAlpha)
    end
    all = check("G: the feet over a turn: " .. table.concat(seen, " "), seen[1] == "0.900/1.000" and seen[2] == "0.900/1.000" and seen[3] == "0.423/0.470" and seen[4] == "0.000/0.000"
        and seen[6] == "0.450/0.500" and seen[7] == "0.900/1.000" and seen[8] == "0.900/1.000", W) and all
end
do local W = ready(world({ inst = false }))
    W.feet = 0 W.N.altTick()
    all = check("G: no anim instance: no error", true, W) and all
end
-- H. the traces: the first AltFlipTraces monsters / nightmares of a run, none for the game's own tricks, none with TraceLog=0
do local W = ready(world())
    local ra, va = addrOf(W, "TRICK_RGS_Ollie"), addrOf(W, "TRICK_RGS_VarialFlip")
    local seq = { { 2, 1, ra, 1 }, { 2, 1, ra, 1 }, { 3, 1, ra, 1 }, { 2, 3, 0, 2 }, { 2, 2, va, 3 }, { 2, 1, ra, 4 }, { 2, 2, va, 5 } }
    for _, s in ipairs(seq) do W.state = string.format("%d %d %d %d 1", s[1], s[2], s[3], s[4]) W.N.altTick() end
    all = check("H: traced: monster #1, nightmare #3, monster #4 (" .. table.concat(W.traces, ", ") .. ")", #W.traces == 3 and W.traces[1] == "90 alt monster 1"
        and W.traces[2] == "90 alt nightmare 3" and W.traces[3] == "90 alt monster 4", W) and all
end
do local W = ready(world({ set = { TraceLog = 0 } }))
    W.state = string.format("2 1 %d 1 1", addrOf(W, "TRICK_RGS_Ollie")) W.N.altTick()
    all = check("H: TraceLog=0: no trace", #W.traces == 0, W) and all
end
do local W = ready(world())   -- (round 2) the daydream traced as such
    local ha, ra = addrOf(W, "TRICK_RGS_VarialHeel"), addrOf(W, "TRICK_RGS_Ollie")
    local seq = { { 2, 4, ha, 1 }, { 2, 4, ha, 1 }, { 2, 1, ra, 2 }, { 2, 4, ha, 3 }, { 2, 4, ha, 4 } }
    for _, s in ipairs(seq) do W.state = string.format("%d %d %d %d 1", s[1], s[2], s[3], s[4]) W.N.altTick() end
    all = check("H: daydream #1, monster #2, daydream #3 traced, the 4th not (AltFlipTraces 3): " .. table.concat(W.traces, ", "), #W.traces == 3 and W.traces[1] == "90 alt daydream 1"
        and W.traces[2] == "90 alt monster 2" and W.traces[3] == "90 alt daydream 3", W) and all
end
-- M. (round 2) the native half's "bail" news: the mod's own doBail asked once, the line logged without its tag
do local W = ready(world())
    W.news[1] = "bail #3 monster flip NOT caught: down at 455 deg (the deck 95 deg from upright)"
    W.news[2] = "cancel #3 MONSTER FLIP on Ollie (pop ratio 1.00): ...; MANUAL (your game's Catch setting): NOT caught -- down at 455 deg, the deck 95 deg from upright: BAIL asked | landed 0.81 s after the trick began"
    W.N.altTick()
    all = check("M: a bail news line: doBail('alt flips: #3 monster flip NOT caught: ...', 0) once, the line logged, 'BAIL asked (taken to the game)'", #W.bails == 1
        and W.bails[1][1] == "alt flips: #3 monster flip NOT caught: down at 455 deg (the deck 95 deg from upright)" and W.bails[1][2] == 0
        and logged(W, "alt flips: #3 monster flip NOT caught: down at 455 deg (the deck 95 deg from upright)") == 1 and logged(W, "alt flips: BAIL asked (taken to the game)") == 1
        and logged(W, "alt flips: #3 MONSTER FLIP on Ollie") == 1, W) and all
    W.news[1] = "monster #4 MONSTER FLIP on Ollie (pop ratio 1.00): ... | landed 0.92 s after the trick began; display: Double (2 turns)"
    W.N.altTick()
    all = check("M: any other tag asks for no bail", #W.bails == 1, W) and all
end
do local W = ready(world({ bailAns = false }))
    W.news[1] = "bail #5 monster flip: a bad catch -- the deck 151 deg from upright (the game's tolerance 120)"
    W.N.altTick()
    all = check("M: doBail answering false (bails off this session): said", #W.bails == 1 and logged(W, "alt flips: BAIL asked (not possible: bails are off this session)") == 1, W) and all
end
do local W = ready(world({ noBail = true }))
    W.news[1] = "bail #6 monster flip caught too late: 64 deg short at the landing"
    local ok = pcall(W.N.altTick)
    all = check("M: no doBail in reach: no error out of altTick, said", ok and logged(W, "alt flips: #6 monster flip caught too late: 64 deg short at the landing") == 1
        and logged(W, "alt flips: BAIL asked (not possible: ") == 1, W) and all
end
do  -- the real file: doBail is a file-level local declared before the alt block (an upvalue there, not a global)
    local db = src:find("\nlocal function doBail(why, residual)\n", 1, true)
    local ap = src:find("\nNATIVE.ALT_PATHS = {", 1, true)
    all = check("M: doBail is a file-level local declared before the alt block", db ~= nil and ap ~= nil and db < ap and body:find('pcall(doBail, "alt flips: " .. text, 0)', 1, true) ~= nil) and all
end
-- I. the engage / disengage as the Lua sees it: no wallride starts under an alt trick in the air; nothing renamed in the alt crouch
do local W = ready(world())
    W.state = "1 0 0 0 0" W.N.altTick()
    local w1, d1 = #W.wall, #W.dn
    W.state = string.format("2 1 %d 1 1", addrOf(W, "TRICK_RGS_Ollie")) W.N.altTick() W.N.altTick()
    local w2 = #W.wall
    W.state = string.format("3 1 %d 1 1", addrOf(W, "TRICK_RGS_Ollie")) W.N.altTick()
    all = check("I: the alt crouch (phase 1): no rename, no wallride window touched", w1 == 0 and d1 == 0, W) and all
    all = check("I: an alt trick in the air (phase 2): HJN_Wall('ok', 0) each frame, said once", w2 == 2 and W.wall[1] == "ok 0" and logged(W, "alt flips: no wallride starts while a monster flip is in the air") == 1, W) and all
    all = check("I: landed (phase 3): the wallride's window left alone", #W.wall == 2, W) and all
end
do local W = ready(world())   -- (review F8) a nightmare (or the game's own trick from the alt crouch) leaves the wallride's window alone
    W.state = string.format("2 2 %d 1 1", addrOf(W, "TRICK_RGS_VarialFlip")) W.N.altTick() W.N.altTick()
    all = check("I: a nightmare in the air (phase 2, kind 2): the wallride's window left alone", #W.wall == 0, W) and all
end
-- K. (merge) review F9: the first look-ups wait for the object walk's gate (NATIVE.walkOk); the names go back with the keys they were
-- written with (an uncached fallback while the walk was refused); review F10: the hop's capture of a mirrored stick
do local W = world()
    W.N.walkOk = function() return false end
    W.N.altCfg() W.N.altCfg()
    local d0, t0 = #calls(W, "defs"), W.N.alt and W.N.alt.tries or 0
    W.N.walkOk = function() return true end
    W.N.altCfg()
    all = check("K: (merge) the walk refused: no definition looked up nor counted; let through: found and sent once", d0 == 0 and t0 == 0 and #calls(W, "defs") == 1
        and logged(W, "12 of 12 trick definitions found") == 1, W) and all
end
do local W = ready(world())
    local ra = addrOf(W, "TRICK_RGS_Ollie")
    W.N.walkOk = function() return false end
    W.state = string.format("2 1 %d 1 1", ra) W.N.altTick()
    local wrote, nw = {}, 0
    for _, c in ipairs(W.tn) do if c[1] == ra and c[3] ~= "" then wrote[c[2]] = true nw = nw + 1 end end
    local fb = true
    for k, v in pairs(FALLBACK) do if not wrote[v] then fb = false end end
    all = check("K: (merge) a rename while the walk is refused: the exe's keys (the fallback), the enum not read nor cached", nw == 8 and fb and W.N.alt.rot == nil, W) and all
    W.N.walkOk = function() return true end
    local n0 = #W.tn
    W.state = "0 0 0 1 0" W.N.altTick()
    local back, other = 0, 0
    for i = n0 + 1, #W.tn do local c = W.tn[i] if c[1] == ra and c[3] == "" then if wrote[c[2]] then back = back + 1 else other = other + 1 end end end
    all = check("K: (merge) ...put back with the very keys it was written with (8 of 8, none other)", back == 8 and other == 0 and displayOf(W, "TRICK_RGS_Ollie") == "Ollie"
        and W.N.alt.renamed == nil and W.N.alt.renamedRot == nil, W) and all
end
do
    local h1 = src:find("        SB.v0 = (alx and arx) and { alx, aly, arx, ary } or nil\n", 1, true)
    local b1 = h1 and src:find("        if SB.v0 and type(HJN_Alt) == \"function\" then", h1, true)
    local b2 = b1 and src:find("\n        end\n", b1, true)
    local ok = b1 ~= nil and b2 ~= nil and b1 - h1 < 80
    local function run(state, v0)
        local SB = { v0 = { v0[1], v0[2], v0[3], v0[4] } }
        local env = { SB = SB, type = type, pcall = pcall, tostring = tostring, math = math, HJN_Alt = function(op) if op == "state" then return state end return 1 end }
        local fn = load(src:sub(b1, b2 + 12), "=hopcapture", "t", env)
        if not fn then return nil end
        fn()
        return SB.v0
    end
    local r1 = ok and run("1 0 0 0 0 1", { 0.1, 0.2, 0.0, 0.9 })
    local r2 = ok and run("1 0 0 0 0 2", { 0.0, 0.6, 0.3, 0.4 })
    local r0 = ok and run("1 0 0 0 0 0", { 0.0, 0.6, 0.0, 0.9 })
    local r5 = ok and run("1 0 0 0 0", { 0.0, 0.6, 0.0, 0.9 })
    all = check("K: (merge) review F10: the hop's capture out of the alt crouch takes the right stick mirrored at full throw (0, 0.9 -> 0, -1), the left with 2, nothing with 0 or a 5-number state",
        ok and r1 and near(r1[3], 0) and near(r1[4], -1) and near(r1[1], 0.1) and near(r1[2], 0.2)
        and r2 and near(r2[1], 0) and near(r2[2], -1) and near(r2[3], 0.3) and near(r2[4], 0.4)
        and r0 and near(r0[4], 0.9) and r5 and near(r5[4], 0.9)) and all
end
do local W = ready(world())
    W.state = "-1 0 0 0 0" W.N.altTick()
    all = check("I: phase -1 (stood down in the native half): nothing renamed, no wall call", #W.dn == 0 and #W.wall == 0, W) and all
end
-- J. the base trick -> alt trick mapping as the names table has it, and the wiring read off the file
do local W = world()
    local T = W.N.ALT_NAMES
    local n, bad = 0, {}
    for i, p in ipairs(PATHS) do
        local name = p:match("%.([%w_]+)$")
        local t = T[name]
        n = n + (t and 1 or 0)
        if not t then bad[#bad + 1] = name
        else
            if t.orig ~= ORIG[name] then bad[#bad + 1] = name .. " orig" end
            local want = (i <= 4) and "Monster Flip" or (i <= 8) and "Nightmare Flip" or "Daydream Flip"
            if not t.display:find(want, 1, true) then bad[#bad + 1] = name .. " display" end
            for k, v in pairs(t.rot) do if not FALLBACK[k] then bad[#bad + 1] = name .. " key " .. k end if not v:find(want, 1, true) then bad[#bad + 1] = name .. " " .. k end end
        end
        if W.N.ALT_PATHS[i] ~= p then bad[#bad + 1] = "path " .. i end
    end
    all = check("J: 12 definitions in the native half's order, ollies -> Monster Flip, varial flips -> Nightmare Flip, varial heels -> Daydream Flip, every rotation key one of the 8 (" .. ((#bad == 0) and "ok" or table.concat(bad, ", ")) .. ")", n == 12 and #bad == 0) and all
    all = check("J: the names as designed (RGS: 'Monster Flip' / 'Frontside Monster Flip 180'; SWS: 'Switch Monster Flip'; varial: 'Nightmare Flip' / 'Nightmare Flip Body Varial')",
        T.TRICK_RGS_Ollie.display == "Monster Flip" and T.TRICK_RGS_Ollie.rot.Frontside == "Frontside Monster Flip 180" and T.TRICK_SWS_Ollie.display == "Switch Monster Flip"
        and T.TRICK_SWS_Ollie.rot.Backside == "Switch BS Monster Flip" and T.TRICK_RGS_VarialFlip.display == "Nightmare Flip" and T.TRICK_RGS_VarialFlip.rot.Frontside == "Nightmare Flip Body Varial"
        and T.TRICK_FKS_Ollie.rot.Backside360 == "Caballerial Monster Flip") and all
    local function NT(k) local t = T[k] or {} t.rot = t.rot or {} return t end
    all = check("J: the daydream's names as designed (RGS 'Daydream Flip' FS 'FS Big Daydream Flip' BS 'Daydream Flip Body Varial'; SWS 'Switch Daydream Flip'; FKS FS360 'FS Full Cab Big Daydream Flip'; NLS BS 'Nollie Big Daydream Flip')",
        NT("TRICK_RGS_VarialHeel").display == "Daydream Flip" and NT("TRICK_RGS_VarialHeel").rot.Frontside == "FS Big Daydream Flip" and NT("TRICK_RGS_VarialHeel").rot.Backside == "Daydream Flip Body Varial"
        and NT("TRICK_SWS_VarialHeel").display == "Switch Daydream Flip" and NT("TRICK_FKS_VarialHeel").rot.Frontside360 == "FS Full Cab Big Daydream Flip" and NT("TRICK_NLS_VarialHeel").rot.Backside == "Nollie Big Daydream Flip"
        and NT("TRICK_FKS_VarialHeel").rot.Backside360 == "Fakie Big Daydream Flip Body Varial") and all
    local of = src:find("\nlocal function onFrame(ctx)\n", 1, true)
    local oe = of and src:find("\nend\n", of, true)
    local fr = (of and oe) and src:sub(of, oe) or ""
    local pw, pa, ps = fr:find("pcall(NATIVE.wallTick)", 1, true), fr:find("pcall(NATIVE.altTick)", 1, true), fr:find("pcall(NATIVE.stickSample)", 1, true)
    all = check("J: onFrame calls altTick after wallTick and before stickSample", pw and pa and ps and pw < pa and pa < ps) and all
    local s1 = src:find("\nfunction NATIVE.sync()\n", 1, true)
    local s2 = s1 and src:find("-- (v181) native v97", s1, true)
    local cw = s1 and src:find("if NATIVE.wallCfg then pcall(NATIVE.wallCfg) end", s1, true)
    local ca = s1 and src:find("if NATIVE.altCfg then pcall(NATIVE.altCfg) end", s1, true)
    all = check("J: NATIVE.sync sends the alt settings (after the skater is handed over, before the v97 block)", ca and s2 and cw and ca < s2 and ca > cw) and all
    local f1 = src:find("\nNATIVE.forgetWorld = function(why)\n", 1, true)
    local f2 = f1 and src:find("\n    NATIVE.pc = nil  ", f1, true)
    local fw = (f1 and f2) and src:sub(f1, f2) or ""
    all = check("J: forgetWorld puts the names back and forgets the definitions (HJN_Alt('defs', 0 x8))", fw:find("pcall(NATIVE.altNames, nil)", 1, true) ~= nil
        and fw:find('pcall(HJN_Alt, "defs", 0, 0, 0, 0, 0, 0, 0, 0)', 1, true) ~= nil and fw:find("NATIVE.alt.obj, NATIVE.alt.byAddr, NATIVE.alt.tries, NATIVE.alt.renamed, NATIVE.alt.renamedRot = nil, nil, 0, nil, nil", 1, true) ~= nil) and all
end
local o = assert(io.open("altflip233_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the alt flip set's test failed (build " .. tostring(BUILD) .. "): see altflip233_out.txt", 0) end

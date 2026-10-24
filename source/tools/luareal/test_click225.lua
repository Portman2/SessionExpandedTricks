-- test_click225.lua (build 225, mk225.pl): A STICK CLICK THE MOD DOES NOT USE GOES ON TO THE GAME. The game's own L3
-- opens the missions (ShowTrackedQuestInfo); a tester: "when missions are active, clicking the stick toggles the mission
-- viewer" -- every hippie jump's click went to the game too. Native v123 keeps each click from the game until the Lua
-- answers HJN_Click(which, used). The click code (NATIVE.ckSay / ckTick, groundClick, onClick) is cut out of main.lua and
-- run in real Lua against stand-ins for the hop, the grab click, the jump and the native half.
-- luareal -run test_click225.lua result.txt main.lua   (writes click225_out.txt)
-- Run on build 224 the suite fails as a whole: NATIVE.ck is not there.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("\nlocal lastClickAt = ", 1, true), "lastClickAt was not found")
local b = assert(src:find("\n-- LB / RB: in the air", a, true), "the end of onClick was not found")
local body = src:sub(a + 1, b)
assert(body:find("NATIVE.ck = {", 1, true), "NATIVE.ck is not in the click code (build 224?)")

local out, all = {}, true
local function check(name, cond, W)
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        for _, c in ipairs(W.calls) do out[#out + 1] = "       HJN_Click(" .. c[1] .. ", " .. c[2] .. ") at " .. string.format("%.3f", c[3]) end
        for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l:sub(1, 300) end
    end
    return cond
end

-- a world: W.mode (1 riding, 2 air, 0 on foot), W.crouch, W.hop (nil / "far" / "start"), W.grab, W.drop, W.jumpOk
local function world(opt)
    local W = { calls = {}, logs = {}, t = 100.0, mode = 1, crouch = false, hop = nil, grab = false, drop = false, jumpOk = true, minis = 0, jumps = 0 }
    for k, v in pairs(opt or {}) do W[k] = v end
    local env = { ipairs = ipairs, pairs = pairs, next = next, tonumber = tonumber, tostring = tostring, type = type, pcall = pcall,
        string = string, table = table, math = math, io = { open = function() return nil end },
        os = { clock = function() return W.t end } }
    env.HJN_Click = function(w, u) W.calls[#W.calls + 1] = { w, u, W.t } return 1 end
    local NATIVE = { ck = nil }
    NATIVE.gt = function(fn) fn() end
    NATIVE.dropBusy = function() return W.drop end
    NATIVE.hopTry = function(which)
        if W.hop == "far" then return true end
        if W.hop == "start" then return true, true end
        return false
    end
    local S = { MiniHop = (W.miniHop == nil) and 1 or W.miniHop, NeedCrouch = 1 }
    local prelude = [[
local NATIVE, S, W = ...
local MODE_RIDING, MINI_WINDOW, FRESH = 1, 0.25, 4.0
local PAIR = { L3 = { stick = "Right", dir = "Down" }, R3 = { stick = "Left", dir = "Up" } }
local pressedAt = { Left = {}, Right = {} }
local active = false
local function log(s) W.logs[#W.logs + 1] = tostring(s) end
local function modeNow() return W.mode end
local function refs() return true end
local function crouching() return W.crouch end
local function grabClick(which) return W.grab end
local function hippie(source, req, kind, stick)
    if not W.jumpOk or W.mode ~= 1 then return end
    active = true
    if kind == "mini" then W.minis = W.minis + 1 else W.jumps = W.jumps + 1 end
end
local function startMini(source) hippie(source, false, "mini", nil) end
W.land = function() active = false end
]]
    local chunk = prelude .. body .. "\nreturn onClick, groundClick, NATIVE\n"
    local onClick, groundClick, N = assert(load(chunk, "=click", "t", env))(NATIVE, S, W)
    W.N, W.onClick = N, onClick
    W.click = function(which) S.NeedCrouch = W.crouch and 0 or 1 onClick(which) end   -- (the crouch: the stand-in has no stick read)
    W.frame = function() if N.ck.on and next(N.ck.due) then N.ckTick() end end
    W.N.ck.on = (W.on == nil) and true or W.on
    return W
end
local function said(W, which) local r = {} for _, c in ipairs(W.calls) do if c[1] == which then r[#r + 1] = c[2] end end return r end

-- A. the hold is off (StickClickPass=0 or an older native half): no answers at all
do local W = world({ on = false, crouch = true })
    W.click("L3")
    all = check("A: hold off: the jump starts, no HJN_Click", W.jumps == 1 and #W.calls == 0, W) and all
end
-- B. riding, crouched: a hippie jump starts -> the click is the mod's at once
do local W = world({ crouch = true })
    W.click("L3")
    local s = said(W, "L3")
    all = check("B: a hippie jump: L3 kept from the game at once (" .. table.concat(s, ",") .. ")", W.jumps == 1 and #s == 1 and s[1] == 1, W) and all
end
-- C. riding, no crouch, MiniHop on: nothing started -> waits the mini window, then goes on to the game
do local W = world({ crouch = false })
    W.click("L3")
    local early = #W.calls
    W.t = W.t + 0.20 W.frame()
    local mid = #W.calls
    W.t = W.t + 0.06 W.frame()
    local s = said(W, "L3")
    all = check("C: no jump on the board: nothing said for 0.25 s (" .. early .. ", " .. mid .. ")", early == 0 and mid == 0, W) and all
    all = check("C: ...then handed on to the game once (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 0 and next(W.N.ck.due) == nil, W) and all
end
-- D. L3 (no crouch) then R3 inside the window: a mini hop -> both kept, the waiting L3 never handed on
do local W = world({ crouch = false })
    W.click("L3")
    W.t = W.t + 0.10
    W.click("R3")
    W.t = W.t + 0.50 W.frame()
    local l, r = said(W, "L3"), said(W, "R3")
    all = check("D: both clicks: a mini hop (" .. W.minis .. ")", W.minis == 1, W) and all
    all = check("D: ...L3 kept (" .. table.concat(l, ",") .. ") and R3 kept (" .. table.concat(r, ",") .. "), nothing handed on later", #l == 1 and l[1] == 1 and #r == 1 and r[1] == 1, W) and all
end
-- E. on foot, no loose board near: handed on at once (no mini window off the board)
do local W = world({ mode = 0 })
    W.click("L3")
    local s = said(W, "L3")
    all = check("E: on foot: L3 handed on at once (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 0, W) and all
end
-- F. on foot by a loose board: too far (logged, no hop) -> the game's; a board hop that starts -> the mod's
do local W = world({ mode = 0, hop = "far" })
    W.click("L3")
    local s = said(W, "L3")
    all = check("F: board too far for a hop: handed on (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 0, W) and all
end
do local W = world({ mode = 0, hop = "start" })
    W.click("R3")
    local s = said(W, "R3")
    all = check("F: a board hop started: R3 kept (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 1, W) and all
end
-- G. a click grab in the air took it -> the mod's
do local W = world({ mode = 2, grab = true })
    W.click("R3")
    local s = said(W, "R3")
    all = check("G: a click grab: kept (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 1, W) and all
end
-- H. in the air with no click grab: handed on at once (SessionTweaks' click-to-catch is not kept waiting)
do local W = world({ mode = 2 })
    W.click("L3")
    local s = said(W, "L3")
    all = check("H: in the air, nothing of the mod's: handed on at once (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 0, W) and all
end
-- I. a drop-in busy, and a click on the heels of the last: handed on
do local W = world({ drop = true, crouch = true })
    W.click("L3")
    W.t = W.t + 0.3 W.frame()
    local s = said(W, "L3")
    all = check("I: a drop-in being set up: handed on, no jump (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 0 and W.jumps == 0, W) and all
end
do local W = world({ crouch = true })
    W.click("L3") W.land()
    W.t = W.t + 0.05
    W.click("L3")
    W.t = W.t + 0.3 W.frame()
    local s = said(W, "L3")
    all = check("I: a second click 0.05 s after the first: the first kept, the second handed on (" .. table.concat(s, ",") .. ")", #s == 2 and s[1] == 1 and s[2] == 0 and W.jumps == 1, W) and all
end
-- J. MiniHop off: a click that started nothing goes on at once
do local W = world({ miniHop = 0 })
    W.click("L3")
    local s = said(W, "L3")
    all = check("J: MiniHop=0: handed on at once (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 0, W) and all
end
-- K. hippie jumps switched off (the jump refuses): the click goes on (the missions open as in the plain game)
do local W = world({ crouch = true, jumpOk = false, miniHop = 0 })
    W.click("L3")
    local s = said(W, "L3")
    all = check("K: hippie jumps off: handed on (" .. table.concat(s, ",") .. ")", #s == 1 and s[1] == 0 and W.jumps == 0, W) and all
end
-- L. a jump already running (the earlier click's) and a lone click: not counted as this click's
do local W = world({ crouch = true, miniHop = 0 })
    W.click("L3")
    W.t = W.t + 0.5
    W.crouch = false
    W.click("L3")
    local s = said(W, "L3")
    all = check("L: a click while the first jump is still in the air: that one handed on (" .. table.concat(s, ",") .. ")", #s == 2 and s[1] == 1 and s[2] == 0, W) and all
end
local o = assert(io.open("click225_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("build 225's click test failed: see click225_out.txt", 0) end

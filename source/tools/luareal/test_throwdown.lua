-- test_throwdown.lua: the throwdown speed's watch (DI.tdWatch and its helpers), cut out of main.lua and run in real Lua
-- against a stand-in for the game.  luareal -run test_throwdown.lua result.txt main.lua   (writes tdtest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("    DI.td = {}", 1, true), "the watch's start was not found")
local b = assert(src:find("    NATIVE.dropBusy = function()", a, true), "the watch's end was not found")
local body = src:sub(a, b - 1)

local function world(o)
    local W = { kicks = {}, logs = {}, vel = { X = 0, Y = 0, Z = 0 }, speed = 0, partsHeld = 0, clock = 1.0, clockWrites = 0 }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.HJN_BoardParts = function(...) if select("#", ...) > 0 then W.partsHeld = W.partsHeld + 1 return select("#", ...) end W.partsHeld = W.partsHeld - 1 return 0 end
    env.HJN_BoardKick = function(x, y, z, spin, ox, oy) W.kicks[#W.kicks + 1] = { x, y, z, spin, ox, oy } return 7 end
    env.HJN_MeshSpeed = function() return math.sqrt(W.vel.X ^ 2 + W.vel.Y ^ 2) * W.clock end
    env.HJN_DeckWorld = function() return "30 40 5 0 1" end
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })   -- the watch's time base is the test's own
    local DI = { state = W.state }
    local S = { ThrowdownScale = W.scale or 1.6, ThrowdownRateMax = W.kmax or 2.5 }
    local q = function(fn, d) local ok, r = pcall(fn) if ok then return r end return d end
    local s0 = setmetatable({ K2_GetActorLocation = function() return { X = 0, Y = 0, Z = 0 } end },
        { __index = function(_, k) if k == "CustomTimeDilation" then return W.clock end end,
          __newindex = function(_, k, v) if k == "CustomTimeDilation" then W.clock = v W.clockWrites = W.clockWrites + 1 else error("unexpected write: " .. tostring(k)) end end })
    local mv = setmetatable({ GetCurrentSpeed = function() return W.speed end }, { __index = function(_, k) if k == "Velocity" then return W.vel end end })
    local NATIVE = { boardParts = function() return { 1, 2, 3, 4, 5, 6, 7 } end }
    local chunk = "local DI, S, q, s0, mv, log, modeNow, MODE_BAILING, NATIVE, alive = ...\n" .. body .. "\nreturn DI, NATIVE"
    local fn = assert(load(chunk, "=watch", "t", env))
    W.t = 100
    W.DI, W.N = fn(DI, S, q, s0, mv, function(s) W.logs[#W.logs + 1] = s end, function() return W.mode or 1 end, 5, NATIVE, function(x) return (not W.dead) and x or nil end)
    W.tick = function(bmode, onb, n) for _ = 1, (n or 1) do W.t = W.t + 0.0125 W.DI.tdWatch(W.t, (bmode < 0) and -1 or ((bmode << 4) | (onb and 4 or 0))) end end
    return W
end
local function near(x, y) return math.abs(x - y) < 0.01 end
local out = {}
local function check(name, cond, W) out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then out[#out + 1] = "       clock " .. tostring(W.clock) .. ", written " .. W.clockWrites for _, l in ipairs(W.logs) do out[#out + 1] = "       log: " .. l end for _, k in ipairs(W.kicks) do out[#out + 1] = "       kick: " .. table.concat(k, " ") end end
    return cond end
local all = true

-- A. a running throwdown at x1.6: the throw at x1.6, the clock back at the mount, the board's 450 times 1.6
do local W = world({})
    W.tick(5, false, 20) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 1)
    all = check("A: the throw's first frame sets the clock to the scale", near(W.clock, 1.6), W) and all
    W.tick(6, false, 25)
    W.vel = { X = 450, Y = 0, Z = 0 } W.speed = 450 W.tick(1, true, 1)
    all = check("A: the clock is back at 1 on the first frame on the board, no kick in that frame", W.clock == 1 and #W.kicks == 0, W) and all
    W.tick(1, true, 3) W.speed = 720 W.tick(1, true, 30)
    all = check("A: one kick of 720 0 0 along +X", #W.kicks == 1 and near(W.kicks[1][1], 720) and near(W.kicks[1][2], 0) and near(W.kicks[1][5], 1), W) and all
    all = check("A: three log lines, the parts let go of, the clock written twice", #W.logs == 3 and W.partsHeld == 0 and W.clockWrites == 2, W) and all
    for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l end
end
-- B. from a standstill: NOTHING -- the clock is not touched, the board is given nothing
do local W = world({ scale = 2.5 })
    W.tick(5, false, 20) W.tick(6, false, 60) W.speed = 0 W.tick(1, true, 60)
    all = check("B: standing still = the clock never written, no kick, one line saying so", W.clockWrites == 0 and #W.kicks == 0 and #W.logs == 1, W) and all
    out[#out + 1] = "       " .. tostring(W.logs[1])
end
-- B2. thrown at a crawl that has stopped by the mount (40 cm/s at the press, the board at 10): sped up, but nothing to multiply
do local W = world({}) W.vel = { X = 40, Y = 0, Z = 0 } W.tick(6, false, 20) W.vel = { X = 10, Y = 0, Z = 0 }
    W.tick(6, false, 5) W.tick(1, true, 20)
    all = check("B2: under 30 cm/s on the board = no kick, the clock back at 1", #W.kicks == 0 and W.clock == 1, W) and all end
-- C. the setting at 1: nothing at all
do local W = world({ scale = 1 }) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 40) W.tick(1, true, 60) all = check("C: x1 = no kick, no log, the clock never written", #W.kicks == 0 and #W.logs == 0 and W.clockWrites == 0, W) and all end
-- D. the mod's own drop-in is at work: nothing
do local W = world({ state = "mount" }) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 40) W.tick(1, true, 60) all = check("D: a drop-in's throwdown = no kick, the clock never written", #W.kicks == 0 and W.clockWrites == 0, W) and all end
-- E. on the board with no throw before it (a respawn, the board hop): nothing
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(5, false, 40) W.tick(1, true, 60) all = check("E: a mount without a throw = no kick", #W.kicks == 0 and W.clockWrites == 0, W) and all end
-- F. a failed throw (the board lies loose), then on the board another way: the clock back at once, no kick
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 10) local k = W.clock W.tick(8, false, 1)
    all = check("F: a throw that fails puts the clock back in that frame", k > 1.5 and W.clock == 1, W) and all
    W.tick(8, false, 80) W.tick(1, true, 60) all = check("F: ...and there is no kick a second later", #W.kicks == 0, W) and all end
-- G. off the board again before the kick is due (a bail in the mount's first frame): nothing
do local W = world({}) W.vel = { X = 300, Y = 0, Z = 0 } W.tick(6, false, 40) W.tick(1, true, 1) W.tick(8, false, 10) W.tick(1, true, 60) all = check("G: bailed before the kick = no kick, the clock at 1", #W.kicks == 0 and W.clock == 1, W) and all end
-- H. a slope: the board rolls down and forward -> all three parts of its velocity are multiplied
do local W = world({}) W.vel = { X = 300, Y = 0, Z = 0 } W.tick(6, false, 40) W.vel = { X = 240, Y = 0, Z = -180 } W.speed = 480 W.tick(1, true, 40)
    all = check("H: on a slope the velocity is multiplied as it is", #W.kicks == 1 and near(W.kicks[1][1], 384) and near(W.kicks[1][3], -288), W) and all end
-- I. x4: the throw's rate stops at ThrowdownRateMax, the board still gets x4
do local W = world({ scale = 4 }) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 5) local k = W.clock W.speed = 1840 W.tick(1, true, 40)
    all = check("I: x4 = the throw at x2.5, the board 1840", near(k, 2.5) and #W.kicks == 1 and near(W.kicks[1][1], 1840), W) and all end
-- J. ThrowdownRateMax 1: the throw is left alone, the board still gets its speed
do local W = world({ kmax = 1 }) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 40) W.speed = 736 W.tick(1, true, 40) all = check("J: rate 1 = the clock never written, one kick of 736", W.clockWrites == 0 and #W.kicks == 1 and near(W.kicks[1][1], 736), W) and all end
-- K. the throw never ends (stuck in mode 6): the clock is back after 1.5 s
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 100) local k = W.clock W.tick(6, false, 40)
    all = check("K: still thrown after 1.5 s = the clock back at 1 and not set again", k > 1.5 and W.clock == 1 and W.clockWrites == 2, W) and all end
-- L. the board is gone mid-throw (a level change): the clock is put back
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 10) W.tick(-1, false, 1) all = check("L: no board mid-throw = the clock back at 1", W.clock == 1 and W.clockWrites == 2, W) and all end
-- M. the watch stops being called mid-throw: the 2 s tick puts the clock back
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 10) W.t = W.t + 1 W.N.tdBackstop() local k = W.clock W.t = W.t + 1.5 W.N.tdBackstop()
    all = check("M: the 2 s tick leaves a young speed-up, ends one older than 2 s", k > 1.5 and W.clock == 1, W) and all end
-- N. something else already runs the skater's clock (slow motion): it is left alone
do local W = world({ clock = 0.5 }) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 40) W.speed = 736 W.tick(1, true, 40) W.N.tdBackstop()
    all = check("N: a clock that is not 1 is not touched, by the throw or the 2 s tick; the board still gets its speed", W.clockWrites == 0 and W.clock == 0.5 and #W.kicks == 1, W) and all end
-- O. so soon after the mount the board reads 0: the walk's velocity is what is multiplied
do local W = world({}) W.vel = { X = 0, Y = 460, Z = 0 } W.tick(6, false, 40) W.vel = { X = 0, Y = 0, Z = 0 } W.speed = 736 W.tick(1, true, 40)
    all = check("O: the board at 0 right after the mount = the walk's 460 times 1.6", #W.kicks == 1 and near(W.kicks[1][1], 0) and near(W.kicks[1][2], 736), W) and all end
-- P. a clock left at the last throw's rate with no throw on (it must not happen): the 2 s tick puts it back
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.tick(6, false, 20) W.speed = 736 W.tick(1, true, 40) W.clock = 1.6 W.N.tdBackstop()
    all = check("P: the 2 s tick puts back a clock that still runs at the last throw's rate", W.clock == 1, W) and all end
-- Q. a slow walk (100 cm/s) at x2: the throw at x2, the board 200
do local W = world({ scale = 2 }) W.vel = { X = 100, Y = 0, Z = 0 } W.tick(6, false, 20) local k = W.clock W.speed = 200 W.tick(1, true, 40)
    all = check("Q: a walk at 100 = the throw at x2, the board 200", near(k, 2) and #W.kicks == 1 and near(W.kicks[1][1], 200), W) and all end

local o = assert(io.open("tdtest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the throwdown speed's test failed: see tdtest_out.txt", 0) end

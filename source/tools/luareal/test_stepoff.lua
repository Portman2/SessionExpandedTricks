-- test_stepoff.lua: the watch for a step-off the game never ends (DI.stepOffWatch), the trace a Y press on the board
-- opens (dropKey's first lines) and the watch's call in dropTick, cut out of main.lua and run in real Lua against a
-- stand-in for the game.  luareal -run test_stepoff.lua result.txt main.lua   (writes sotest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("    DI.so = {}", 1, true), "the watch's start was not found")
local b = assert(src:find("    NATIVE.dropBusy = function()", a, true), "the watch's end was not found")
local body = src:sub(a, b - 1)
local ya = assert(src:find("        DI.yPress = os.clock()", 1, true), "dropKey's first line was not found")
local ka = assert(src:find("        -- (v211) ...AND A Y PRESS MADE ON THE BOARD", ya, true), "the trace's start in dropKey was not found")
local kb = assert(src:find("        -- (v204) A Y PRESS ON FOOT THAT NOTHING COMES OF", ka, true), "the trace's end in dropKey was not found")
assert(ka - ya < 200, "the trace does not follow dropKey's first line")
local key = src:sub(ya, kb - 1)
local tick = "    NATIVE.dropTick = function(now)\n"
local ta = assert(src:find(tick, 1, true), "dropTick was not found")
local tb = assert(src:find("        if type(HJN_BoardState) == \"function\" then       -- (v180, review)", ta, true), "dropTick's next statement was not found")
local call = src:sub(ta + #tick, tb - 1)
assert(call:find("pcall(DI.stepOffWatch, now)", 1, true), "the watch is not called first thing in dropTick")

local FR = 1 / 120
local function world(o)
    local W = { logs = {}, once = {}, asks = 0, askAt = {}, t = 100, flag = false, onb = true, throw = false, mode = 1, bt = 0, grounded = true,
                falling = false, bmode = 1, unstick = 1, obeys = true, flagReads = 0, animReads = 0 }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.HJN_BoardState = function() if W.noBoard then return -1 end return (W.bmode << 4) | (W.onb and 4 or 0) | ((W.flag or W.throw or W.pending) and 8 or 0) end
    env.HJN_ToggleGates = function() return string.format("throwdown flag %d, pick-up flag %d", W.throw and 1 or 0, W.flag and 1 or 0) end
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })   -- the time base is the test's own
    local DI = {}
    local S = { StepOffUnstick = W.unstick }
    local q = function(fn, d) local ok, v = pcall(fn) if ok and v ~= nil then return v end return d end   -- (main.lua's own)
    local function bad(what) W.bad = what error(what) end
    local s0 = setmetatable({}, {
        __index = function(_, k)
            if k == "IsPickingUp" then return function() W.flagReads = W.flagReads + 1 return W.flag end
            elseif k == "IsOnBoard" then return function() return W.onb end
            elseif k == "IsDoingThrowdown" then return function() return W.throw end
            elseif k == "SetPendingApplyToggleOnBoard" then
                return function() W.asks = W.asks + 1 W.askAt[#W.askAt + 1] = W.t if W.callFails then error("no such function") end W.pending = true end
            end
            bad("unexpected read of the skater: " .. tostring(k))
        end,
        __newindex = function(_, k) bad("unexpected write to the skater: " .. tostring(k)) end })
    local inst = setmetatable({}, {
        __index = function(_, k)
            W.animReads = W.animReads + 1
            if k == "IsOnBoard" then return W.onb elseif k == "IsGrounded" then return W.grounded elseif k == "IsFalling" then return W.falling
            elseif k == "IsPickingUp" then return W.flag elseif k == "BoardToFootTransitionType" then return W.bt end
            bad("unexpected read of the animation: " .. tostring(k))
        end,
        __newindex = function(_, k) bad("unexpected write to the animation: " .. tostring(k)) end })
    local function alive(x)
        if x == s0 then return (not W.noSkater) and x or nil end
        if x == inst then return (not W.noAnim) and x or nil end
        return x
    end
    local log = function(s) W.logs[#W.logs + 1] = s end
    local chunk = "local DI, S, q, s0, inst, log, modeNow, alive = ...\n" .. body .. "\nreturn DI"
    W.DI = assert(load(chunk, "=watch", "t", env))(DI, S, q, s0, inst, log, function() return W.mode end, alive)
    W.press = assert(load("local DI = ...\n" .. key, "=dropkey", "t", env))
    W.call = assert(load("local DI, logOnce, now = ...\n" .. call, "=droptick", "t", env))
    -- one frame: the game's own Tick first (a pending toggle is applied: ApplyToggleOnBoard(true)), then the mod's watch
    W.frame = function(n, dt)
        for _ = 1, (n or 1) do
            W.t = W.t + (dt or FR)
            if W.pending then
                W.pending = false
                if W.onb then W.onb, W.steppedOff = false, true                     -- on the board it is a true toggle: stepped off
                elseif W.flag and W.obeys then W.flag = false end                    -- on foot with the pick-up flag: SetOnFootMode clears it
            end
            W.DI.stepOffWatch(W.t)
        end
    end
    W.stepOff = function(bt) W.onb, W.flag, W.bt, W.mode, W.bmode = false, true, bt, 0, 5 end   -- the toggle lands: on foot, the board in the hand
    W.has = function(i, s) return W.logs[i] ~= nil and W.logs[i]:find(s, 1, true) ~= nil end
    return W
end
local out = {}
local function check(name, cond, W) out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if W and W.bad then cond = false out[#out + 1] = "FAIL " .. name .. " -- " .. W.bad end
    if not cond and W then
        out[#out + 1] = string.format("       asks %d, flag %s, on board %s, mode %s, pending %s", W.asks, tostring(W.flag), tostring(W.onb), tostring(W.mode), tostring(W.pending))
        for _, l in ipairs(W.logs) do out[#out + 1] = "       log: " .. l end
    end
    return cond end
local all = true

-- A. THE STUCK STEP-OFF of 9 Oct: Y on the board, the wheels leave the ground 183 ms on, the toggle lands 33 ms after
-- that with no animation (type 0) -> asked once, a quarter second on; the game's next Tick ends it
do local W = world({})
    W.frame(60) W.press(W.DI) W.frame(22) W.grounded = false W.frame(4) W.stepOff(0) W.frame(1) W.falling = true
    W.frame(26)
    all = check("A: nothing is asked in the first 0.22 s of the stuck flag", W.asks == 0 and #W.logs == 0, W) and all
    local n = 0
    while W.asks == 0 and n < 20 do W.frame(1) n = n + 1 end
    all = check("A: asked once after a quarter second of frames (the 30th or 31st stuck frame at 120 a second)", W.asks == 1 and #W.logs == 1 and (n == 3 or n == 4) and W.pending == true, W) and all
    all = check("A: the line says what was done and what the game's tests read", W.has(1, "The mod asked the game to end it") and W.has(1, "pick-up flag 1") and W.has(1, "no step-off animation is playing"), W) and all
    all = check("A: the line has the frames after the Y press: on the board off the ground, then on foot with P and type 0",
        W.has(1, ":BG-- b1 t0, ") and W.has(1, ":B--- b1 t0, ") and W.has(1, ":f--P b5 t0, ") and W.has(1, ":f-FP b5 t0"), W) and all
    all = check("A: ...and how long after the Y press", W.has(1, "s after the last Y press") and W.has(1, "the Y press made on the board 0."), W) and all
    W.frame(1)
    all = check("A: the game's next Tick ends it, and that is said", W.flag == false and #W.logs == 2 and W.has(2, "step-off: ended") and W.has(2, "Y and the jump are yours again"), W) and all
    W.frame(600)
    all = check("A: nothing more is asked or logged afterwards, he was never stepped off the board by it", W.asks == 1 and #W.logs == 2 and not W.steppedOff, W) and all
    for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l end
end
-- B. a healthy step-off: type 2 for 0.65 s, then the animation's own end (type 0 for one frame, the game's own pending toggle)
do local W = world({})
    W.frame(60) W.press(W.DI) W.frame(26) W.stepOff(2) W.frame(78) W.bt = 0 W.frame(1) W.pending = true W.frame(1)
    all = check("B: a healthy step-off ends by itself", W.flag == false, W) and all
    W.frame(240)
    all = check("B: a healthy step-off: nothing asked, nothing logged", W.asks == 0 and #W.logs == 0, W) and all end
-- B2. a healthy one that takes 1.9 s (type 1): still nothing; B3. one whose flag stands 2.1 s with its type at 1: the 2 s rule
do local W = world({}) W.frame(10) W.stepOff(1) W.frame(228) W.pending = true W.frame(120)
    all = check("B2: a step-off of 1.9 s with its animation playing: nothing asked", W.asks == 0 and #W.logs == 0 and W.flag == false, W) and all end
do local W = world({}) W.frame(10) W.stepOff(1) W.frame(236)
    all = check("B3: the flag at 1.97 s with the animation type 1: not yet", W.asks == 0, W) and all
    W.frame(10)
    all = check("B3: ...standing 2 s whatever the type: asked once, and the line says why", W.asks == 1 and W.has(1, "its flag has stood for 2.0 s") and W.has(1, "(animation type 1)"), W) and all
    all = check("B3: with no Y press seen the line says so", W.has(1, "no Y press was seen") and W.has(1, "no Y press on the board was seen before it"), W) and all end
-- C. StepOffUnstick=0: logged once, nothing asked
do local W = world({ unstick = 0 }) W.frame(10) W.stepOff(0) W.frame(600)
    all = check("C: StepOffUnstick=0 = one line in 5 s, the game asked nothing", W.asks == 0 and #W.logs == 1 and W.has(1, "StepOffUnstick=0: only logged") and W.flag == true, W) and all
    W.flag, W.onb, W.mode, W.bmode = false, true, 1, 1 W.frame(1)                 -- (the marker teleport)
    all = check("C: ...and its end is said without claiming the mod ended it", #W.logs == 2 and W.has(2, "step-off: ended") and W.has(2, "it was logged (the game was asked nothing)") and not W.has(2, "yours again"), W) and all
    W.frame(240)
    all = check("C: ...riding on: nothing more", W.asks == 0 and #W.logs == 2, W) and all end
-- D. the game does not end it: three tries half a second apart, then left alone
do local W = world({ obeys = false }) W.frame(10) W.stepOff(0) W.frame(1200)
    all = check("D: three tries in 10 s, no more", W.asks == 3, W) and all
    all = check("D: ...half a second apart", #W.askAt == 3 and W.askAt[2] - W.askAt[1] >= 0.49 and W.askAt[2] - W.askAt[1] < 0.53 and W.askAt[3] - W.askAt[2] >= 0.49, W) and all
    all = check("D: ...three lines and one that it is left alone", #W.logs == 4 and W.has(2, "(try 2 of 3)") and W.has(3, "(try 3 of 3)") and W.has(4, "left alone") and W.has(2, "in the first try's line"), W) and all
    W.flag, W.onb, W.mode, W.bmode = false, true, 1, 1 W.frame(1)                 -- (the marker teleport)
    all = check("D: ...the teleport's end is said", #W.logs == 5 and W.has(5, "step-off: ended"), W) and all
    W.obeys = true W.frame(60) W.stepOff(0) W.frame(40)
    all = check("D: a later stuck step-off gets its own tries, and is ended", W.asks == 4 and W.flag == false and #W.logs == 7 and W.has(6, "The mod asked the game to end it") and not W.has(6, "(try"), W) and all end
-- D2. the call itself fails (the function is not there): said, three times, then left alone
do local W = world({ callFails = true }) W.frame(10) W.stepOff(0) W.frame(600)
    all = check("D2: a failing call is said and given up after three", W.asks == 3 and #W.logs == 4 and W.has(1, "The mod's call to end it FAILED") and W.has(4, "left alone"), W) and all end
-- E. on the board: never
do local W = world({ flag = true, bt = 0 }) W.frame(600)
    all = check("E: on the board with the flag set: nothing", W.asks == 0 and #W.logs == 0, W) and all end
do local W = world({ flag = true, bt = 0, mode = 0 }) W.frame(600)       -- (the game's own "on the board" is what counts, whatever the mode reads)
    all = check("E2: ...nor when the movement mode reads 0 while the game has you on the board", W.asks == 0 and #W.logs == 0 and not W.steppedOff, W) and all end
-- F. the replay editor (mode 6), a bail (mode 5), a throwdown on as well: never
do local W = world({}) W.stepOff(0) W.mode = 6 W.frame(600)
    all = check("F: in the replay editor: nothing", W.asks == 0 and #W.logs == 0, W) and all end
do local W = world({}) W.stepOff(0) W.mode = 5 W.frame(600)
    all = check("F2: in a bail: nothing", W.asks == 0 and #W.logs == 0, W) and all end
do local W = world({}) W.stepOff(0) W.throw = true W.frame(600)
    all = check("F3: with the throwdown flag set as well: nothing", W.asks == 0 and #W.logs == 0, W) and all end
-- F4. the replay editor entered while stuck and waiting: the watch stands by, and starts over when play is back
do local W = world({ obeys = false }) W.stepOff(0) W.frame(40) local n = W.asks W.mode = 6 W.frame(600)
    all = check("F4: stuck, then the replay editor: one try before it, none in it, and that is said", n == 1 and W.asks == 1 and #W.logs == 2 and W.has(2, "no longer on foot in play (mode 6)"), W) and all
    W.mode = 0 W.frame(40)
    all = check("F4: ...back in play the watch starts over", W.asks == 2, W) and all end
-- G. no skater: nothing, no error, an open trace is dropped
do local W = world({ noSkater = true }) W.DI.offTr = { t0 = W.t, rows = {} } W.stepOff(0)
    local ok, err = pcall(W.frame, 600)
    all = check("G: no skater: no error, nothing asked, the trace dropped", ok and W.asks == 0 and #W.logs == 0 and W.DI.offTr == nil and W.flagReads == 0, W) and all end
-- H. a hitch: frames half a second apart count as one frame each (0.05 s)
do local W = world({}) W.stepOff(0) W.frame(4, 0.5)
    all = check("H: four frames half a second apart are not a quarter second of frames", W.asks == 0, W) and all
    W.frame(3, 0.5)
    all = check("H: ...seven are", W.asks == 1, W) and all end
-- I. the type flickers off 0: the quarter second starts again (only frames in a row count)
do local W = world({ obeys = false }) W.stepOff(0)
    for _ = 1, 8 do W.bt = 0 W.frame(24) W.bt = 2 W.frame(1) end
    all = check("I: type 0 for 0.2 s at a time, eight times (1.67 s): nothing asked", W.asks == 0, W) and all
    W.bt = 0 W.frame(24) W.bt = 2 W.frame(20)
    all = check("I: ...until the flag has stood 2 s", W.asks == 1 and W.has(1, "its flag has stood for 2.0 s"), W) and all end
-- J. the animation cannot be read: the 2 s rule alone
do local W = world({ noAnim = true }) W.stepOff(0) W.frame(230)
    all = check("J: no animation instance: nothing in the first 1.9 s", W.asks == 0, W) and all
    W.frame(20)
    all = check("J: ...asked at 2 s, the type said as not read", W.asks == 1 and W.has(1, "(animation type nil)"), W) and all end
do local W = world({}) W.stepOff(0) W.bt = nil W.frame(230)
    all = check("J2: the type reads nothing: nothing in the first 1.9 s", W.asks == 0, W) and all
    W.frame(20)
    all = check("J2: ...asked at 2 s", W.asks == 1, W) and all end
-- K. the call in dropTick: an error in the watch is logged once and not raised; the watch gets the frame's time
do local W = world({})
    local got, once = nil, {}
    local ok = pcall(W.call, { stepOffWatch = function(now) got = now end }, function(k, m) once[#once + 1] = k .. "|" .. m end, 123.5)
    all = check("K: dropTick calls the watch with the frame's time", ok and got == 123.5 and #once == 0, W) and all
    ok = pcall(W.call, { stepOffWatch = function() error("boom") end }, function(k, m) once[#once + 1] = k .. "|" .. m end, 124)
    all = check("K: an error in the watch is logged (once) and not raised into dropTick", ok and #once == 1 and once[1]:find("soerr|step-off watch error: ", 1, true) == 1 and once[1]:find("boom", 1, true) ~= nil, W) and all end
-- L. dropKey's first lines: a Y press on the board opens the trace, one on foot does not
do local W = world({ onb = false, bmode = 5 }) W.press(W.DI)
    all = check("L: a Y press on foot: its time kept, no trace", W.DI.yPress == W.t and W.DI.offTr == nil, W) and all end
do local W = world({ noBoard = true }) W.press(W.DI)
    all = check("L: no board: no trace", W.DI.offTr == nil, W) and all end
do local W = world({}) W.press(W.DI) local t0 = W.t
    all = check("L: a Y press on the board opens a trace at the press", W.DI.offTr ~= nil and W.DI.offTr.t0 == t0 and #W.DI.offTr.rows == 0, W) and all
    W.t = W.t + 0.3 W.onb = false W.press(W.DI)
    all = check("L: a second press 0.3 s on is a row of the same trace", W.DI.offTr.t0 == t0 and W.DI.offTr.rows[1] == "300:Y again", W) and all
    W.t = W.t + 0.7 W.onb = true W.press(W.DI)
    all = check("L: a press on the board a second on opens a new trace", W.DI.offTr.t0 == W.t and #W.DI.offTr.rows == 0, W) and all end
-- M. the trace: a row only when a reading changes, shut after 0.6 s, 40 rows at most
do local W = world({}) W.press(W.DI) W.frame(30)
    local function rows() return (W.DI.offTr or { rows = {} }).rows end
    all = check("M: riding on after the press: one row", #rows() == 1 and rows()[1] == "8:BG-- b1 t0", W) and all
    W.grounded = false W.frame(10) W.grounded = true W.frame(10)
    all = check("M: ...a row a change", #rows() == 3 and rows()[2] == "258:B--- b1 t0" and rows()[3] == "342:BG-- b1 t0", W) and all
    W.frame(40)
    all = check("M: ...shut 0.6 s after the press and kept as the last one", W.DI.offTr == nil and W.DI.offTrLast ~= nil and #W.DI.offTrLast.rows == 3, W) and all
    local n = W.animReads W.frame(120)
    all = check("M: ...and with no trace open the animation is not read at all", W.animReads == n and W.flagReads == 210, W) and all end
do local W = world({}) W.press(W.DI)
    for _ = 1, 60 do W.grounded = not W.grounded W.frame(1, 1 / 240) end
    all = check("M2: 40 rows at most", (W.DI.offTr == nil) and W.DI.offTrLast ~= nil and #W.DI.offTrLast.rows == 40, W) and all end
-- N. the stuck line with a trace that is shut already (the 2 s rule): the last trace is given, with its age
do local W = world({}) W.press(W.DI) W.frame(26) W.stepOff(1) W.frame(260)
    all = check("N: the 2 s rule after a Y press: the shut trace is in the line", W.asks == 1 and W.DI.offTr == nil and W.has(1, "8:BG-- b1 t0, 225:fG-P b5 t1") and W.has(1, "the Y press made on the board 2."), W) and all end

local o = assert(io.open("sotest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the step-off watch's test failed: see sotest_out.txt", 0) end

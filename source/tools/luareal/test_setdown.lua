-- test_setdown.lua: the drop-in's set-down (DropInSetDown: the state "throw" in dropKey / dropTick), its fallbacks to
-- the old way, letGo's clean-up, the skipped first move and build 210's pieces around them -- the whole drop-in block
-- cut out of main.lua and run in real Lua against a stand-in for the game: an edge, a skater on foot with the board
-- in his hand, the game's Y (acted on 0.216 s late unless the controller's timer says no), its throwdown, its mount
-- (a pending toggle applied by the next tick; dropped by the native half only while he is ON the board) and the
-- throwdown clip's own board-bone track (decoded from the pak: v128/dropanim/clip_throw_idle_SWS.txt; the other clip
-- has the same track played 1.3 times as fast), shown in the drawn deck some frames late.
-- luareal -run test_setdown.lua result.txt main.lua   (writes sdtest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("    local PARTS = { \"Flipper\"", 1, true), "the drop-in block's start was not found")
local b = assert(src:find("\nend\n\n-- (v137) THE NO COMPLY.", a, true), "the drop-in block's end was not found")
local body = src:sub(a, b)
assert(body:find("        if st == \"throw\" then", 1, true), "the state \"throw\" is not in dropTick")
-- the settings as they ship
local SHIP = {}
do
    local s0 = assert(src:find("\nlocal S = {\n", 1, true), "the settings table was not found")
    local s1 = assert(src:find("\n}\n", s0, true), "the settings table's end was not found")
    for line in src:sub(s0, s1):gmatch("[^\n]+") do
        local k, v = line:match("^%s+([%w_]+)%s*=%s*(-?[%d%.]+)%s*,")
        if k then SHIP[k] = tonumber(v) else
            k, v = line:match("^%s+([%w_]+)%s*=%s*\"(.-)\"%s*,")
            if k then SHIP[k] = v end
        end
    end
end

local TR = {   -- { ms, forward, right (- = left), up } of the board bone, 30 frames a second
    {0,4.3,-27.5,71.4}, {33,4.3,-27.5,71.4}, {67,6.0,-26.9,69.7}, {100,12.0,-25.9,62.4}, {133,17.6,-24.9,56.5},
    {167,20.3,-24.4,53.6}, {200,23.0,-23.9,50.9}, {233,30.7,-22.9,45.2}, {267,33.0,-21.8,43.8},
    {300,35.4,-20.9,42.9}, {333,37.8,-20.4,42.2}, {367,37.7,-20.1,41.1}, {400,37.6,-19.7,36.5},
    {433,37.5,-19.4,31.2}, {467,37.3,-18.9,23.7}, {500,37.0,-18.2,16.2}, {533,36.7,-17.4,10.0},
    {567,36.3,-16.8,6.1}, {600,35.8,-16.0,5.3}, {633,35.2,-14.7,5.8}, {667,34.5,-13.3,6.4}, {700,33.6,-12.0,5.5},
    {733,32.6,-10.9,5.5}, {767,31.5,-9.8,5.6}, {800,30.3,-8.8,4.8}, {833,25.2,-7.8,5.3}, {867,21.0,-6.8,5.9},
    {900,17.4,-5.9,5.1}, {933,14.3,-5.0,5.5}, {967,11.9,-4.1,5.5}, {1000,9.9,-3.4,5.4}, {1033,8.1,-2.7,5.4},
    {1067,6.3,-2.1,5.4}, {1100,4.8,-1.6,5.3}, {1133,3.4,-1.1,5.3}, {1167,2.2,-0.7,5.3}, {1200,1.3,-0.4,5.3},
    {1233,0.6,-0.2,5.3}, {1267,0.2,-0.1,5.3}, {1300,-0.0,0.0,5.3}, {1333,0.0,0.0,5.3}, {1367,0.1,0.0,5.3},
    {1400,0.2,0.0,5.3}, {1433,0.2,0.0,5.3}, {1467,0.3,0.0,5.3}, {1500,0.3,0.0,5.3}, {1533,0.3,0.0,5.3},
    {1567,0.3,0.0,5.3}, {1600,0.3,0.0,5.3}, {2100,0.0,0.0,5.3},
}
local function bone(ms)
    if ms <= 0 then return TR[1][2], TR[1][3], TR[1][4] end
    for i = 2, #TR do
        if ms <= TR[i][1] then
            local p, n = TR[i - 1], TR[i]
            local k = (ms - p[1]) / (n[1] - p[1])
            return p[2] + (n[2] - p[2]) * k, p[3] + (n[3] - p[3]) * k, p[4] + (n[4] - p[4]) * k
        end
    end
    return TR[#TR][2], TR[#TR][3], TR[#TR][4]
end
local MODE_RIDING, MODE_AIR, MODE_BAILING, MODE_TO_BOARD = 1, 2, 5, 4
local PARTNAMES = { "Flipper", "TruckHangerFront", "TruckHangerBack", "WheelFront_L", "WheelFront_R", "WheelBack_L", "WheelBack_R" }

-- o: fps, late (frames from a command to its showing in the drawn deck), outDeg (the way the edge faces), dist (cm
-- from the edge), side (cm to the right of the edge point's line), face (deg off square), goofy, S = settings over
-- the shipped ones, v (the native half's version), and the game's quirks (see W.* below)
local function world(o)
    o = o or {}
    local W = { t = 100, fr = 0, dt = 1 / (o.fps or 60), late = o.late or 2, logs = {}, calls = {}, q = {}, hist = {}, events = {}, unk = {},
                onb = false, mode = 0, bmode = 5, loose = false, busy = false, pending = false, goofy = o.goofy ~= false,
                refused = 0, threw = 0, moves = 0, stepBacks = 0, teleports = 0, pendAsks = 0, dropped = 0, gateWrites = {}, animAsks = {},
                animEnds = 0, mountCalls = {}, centred = 0, sounds = 0, notog = 0, stance = {}, top = 50, mirror = o.mirror or 1,
                animPlays = true, speed = 0 }
    for k, v in pairs(o.W or {}) do W[k] = v end
    local od = math.rad(o.outDeg or 0)
    W.ox, W.oy, W.ex, W.ey, W.sq = math.cos(od), math.sin(od), 1000, 2000, o.outDeg or 0
    local dist, side = o.dist or 60, o.side or 0
    W.act = { x = W.ex - W.ox * dist - W.oy * side, y = W.ey - W.oy * dist + W.ox * side, z = W.top + 93, yaw = W.sq + (o.face or 20) }
    local S = {}
    for k, v in pairs(SHIP) do S[k] = v end
    S.DropInSetFly = 0                                              -- (build 216) ...and build 215's rule at the edge
    S.DropInSetDown, S.DropInFar, S.DropInWalkSpeed = 0, 1, 0       -- (build 213) this suite's worlds are builds 211/212's: the set-down off unless a case turns it on, a far press set down behind the edge, a standstill only (build 213's own rules: test_drop213.lua)
    for k, v in pairs(o.S or {}) do S[k] = v end
    W.S = S
    W.spot = { W.ex - W.ox * S.DropInBack, W.ey - W.oy * S.DropInBack }
    local G = { math = math, string = string, table = table, tostring = tostring, tonumber = tonumber, type = type, pcall = pcall,
                ipairs = ipairs, pairs = pairs, select = select, error = error, next = next,
                os = setmetatable({ clock = function() return W.t end }, { __index = os }) }
    local function call(k, v) W.calls[#W.calls + 1] = { k = k, v = v, t = W.t } end
    G.HJN_Set = function(k, v)
        call(k, v)
        if k == "ygate" then
            if W.noGate then return 0 end
            W.gateUntil = W.t + v  W.gateWrites[#W.gateWrites + 1] = v
            return 1
        elseif k == "throwanim" then
            if (W.v or 113) < 113 then return 0 end
            if v >= 1 then
                W.animAsks[#W.animAsks + 1] = v
                if W.animRefuses or W.onb or W.busy or W.pending or W.anim then return 0 end
                local ty = ((W.goofy ~= (v >= 2)) and 2 or 1)          -- as the game picks its clip
                W.anim = { type = ty, t0 = W.t, keep = W.t + 0.4, rate = (ty == 2) and 1.0 or 1.3 }
                return ty
            elseif v < 0 then
                if not W.anim then return 0 end
                if W.takeBackAt and W.t >= W.takeBackAt then W.anim = nil return 0 end
                W.anim.keep = W.t + 0.4
                return W.anim.type
            end
            W.animEnds = W.animEnds + 1  W.anim = nil
            return 1
        elseif k == "notoggle" then
            W.notogUntil = (v > 0) and (W.t + v) or 0
            if v > 0 then W.notog = W.notog + 1 end
            return 1
        end
        return 0
    end
    G.HJN_BoardState = function() if W.noBoard then return -1 end return (W.bmode << 4) | (W.loose and 1 or 0) | (W.onb and 4 or 0) | ((W.busy or W.pending) and 8 or 0) end
    G.HJN_Ledge = function()
        local d = (W.ex - W.act.x) * W.ox + (W.ey - W.act.y) * W.oy
        return string.format("edge %.2f %.2f %.2f %.5f %.5f %.2f 0 %.1f %.1f %.1f %.3f %.3f %.3f %.1f %.1f %.1f", W.ex, W.ey, W.top, W.ox, W.oy, d, 120, 120, -1, 0, 0, 1, 0, 0, 0)
    end
    G.HJN_DeckWorld = function() if not W.deck then return "" end return string.format("%.2f %.2f %.2f %.2f %.3f", W.deck[1], W.deck[2], W.deck[3], W.act.yaw, 1) end
    G.HJN_BoardStance = function(...) local n = select("#", ...) W.stance[#W.stance + 1] = { t = W.t, k = select(11, ...), n = n } return W.stanceFails and 0 or 7 end
    G.HJN_BoardMeet = function() return -1, S.DropInPitch, 0 end
    G.HJN_BoardParts = function(...) return select("#", ...) end
    G.HJN_BoardCapture = function() return 7 end
    G.HJN_GroundHold = function() return 1 end
    G.HJN_BoardMount = function(sw, flip)
        W.mountCalls[#W.mountCalls + 1] = { sw = sw, flip = flip, t = W.t }
        if W.mountRefused or W.onb or W.busy or W.pending then return 0 end
        W.pendFoot = (sw ~= 0) and 4 or 1
        return 1
    end
    G.HJN_BoardPut = function(x, y) W.put = { x, y } W.loose = false W.bmode = 5 return 7 end
    G.HJN_BoardRagdoll = function() end
    G.HJN_MeshSpeed = function() return 0 end
    G.HJN_Bumpers = function() return W.bumpers or 0 end
    G.HJN_NoToggle = function() return tostring(W.dropped) end
    G.HJN_ToggleGates = function() return "(the test)" end
    G.StaticFindObject = function() return {} end
    local env = setmetatable({}, { __index = function(_, k)
        local v = G[k]
        if v ~= nil then return v end
        if type(k) == "string" and k:sub(1, 4) == "HJN_" then return nil end
        error("a name the test does not know: " .. tostring(k), 2)
    end })
    local pc = setmetatable({}, { __index = function(_, k)
        if k:find("^SimulateInput_") then return function() W.centred = W.centred + 1 end end
        W.unk["pc." .. k] = true
    end })
    local sk = {
        K2_GetActorLocation = function() return { X = W.act.x, Y = W.act.y, Z = W.act.z } end,
        K2_GetActorRotation = function() return { Pitch = 0, Yaw = W.act.yaw, Roll = 0 } end,
        K2_SetActorLocationAndRotation = function(_, loc, rot)
            W.moves = W.moves + 1
            if W.onb then W.movedOnBoard = true end
            W.act.x, W.act.y, W.act.z, W.act.yaw = loc.X, loc.Y, loc.Z, rot.Yaw
        end,
        K2_SetActorLocation = function(_, loc) W.stepBacks = W.stepBacks + 1 W.act.x, W.act.y, W.act.z = loc.X, loc.Y, loc.Z end,
        K2_TeleportTo = function(_, loc, rot)
            W.teleports = W.teleports + 1
            W.act.x, W.act.y, W.act.yaw = loc.X, loc.Y, rot.Yaw
            if W.onb then W.board = { loc.X, loc.Y } end
            return true
        end,
        IsOnBoard = function() return W.onb end,
        IsSkatingSwitch = function() return W.switch == true end,
        IsPickingUp = function() return false end,
        IsDoingThrowdown = function() return W.bmode == 6 end,
        SetPendingApplyToggleOnBoard = function() W.pendAsks = W.pendAsks + 1 W.pending = true end,
        GetController = function() return pc end,
        GetFullName = function() return "the test's skater" end,
        GetAddress = function() return 4096 end,
        CustomTimeDilation = 1.0,
    }
    local s0 = setmetatable({}, { __index = function(_, k) local v = sk[k] if v == nil and k ~= "BasedMovement" then W.unk["skater." .. tostring(k)] = true end return v end,
                                  __newindex = function(_, k, v) if k == "CustomTimeDilation" then sk[k] = v else W.unk["skater." .. tostring(k) .. " (written)"] = true end end })
    local mv = { Velocity = { X = 0, Y = 0, Z = 0 }, IsFalling = function() return false end, GetCurrentSpeed = function() return 0 end }
    local inst = setmetatable({}, { __index = function(_, k) if k == "Speed" then return W.speed elseif k == "IsGrinding" then return false end W.unk["anim." .. tostring(k)] = true end })
    local q = function(fn, d) local ok, v = pcall(fn) if ok and v ~= nil then return v end return d end   -- (main.lua's own)
    local alive = function(x) if x == s0 and W.noSkater then return nil end return x end
    local list = {}
    for i, name in ipairs(PARTNAMES) do
        local comp = { GetFName = function() return { ToString = function() return name end } end, GetAddress = function() return 8192 + i end }
        list[i] = { get = function() return comp end }
    end
    local owner = { K2_GetComponentsByClass = function() return list end }
    local findFlipper = function() return { GetOwner = function() return owner end } end
    local NATIVE = { v = o.v or 113, live = true, gt = function(fn) W.q[#W.q + 1] = fn end, heldNote = function() return "" end, stickNow = function() return 0, (W.stickUp or 0) end }
    W.v = NATIVE.v
    local log = function(s) W.logs[#W.logs + 1] = tostring(s) end
    local chunk = "local DI, S, NATIVE, q, alive, addr, log, logOnce, modeNow, MODE_RIDING, MODE_AIR, MODE_BAILING, MODE_TO_BOARD, s0, mv, inst, SB, BD, findFlipper, playSound, refs, active, myAddr, ensureHook = ...\n"
        .. body .. "\nreturn DI"
    W.DI = assert(load(chunk, "=dropin", "t", env))({ state = nil }, S, NATIVE, q, alive, function(x) return x:GetAddress() end, log,
        function(k, m) log("ONCE " .. k .. ": " .. m) end, function() return W.mode end, MODE_RIDING, MODE_AIR, MODE_BAILING, MODE_TO_BOARD,
        s0, mv, inst, { pc = nil }, { comp = nil }, findFlipper, function() W.sounds = W.sounds + 1 end, function() return true end, false, nil, function() end)
    W.NATIVE = NATIVE

    -- the game's own half of a frame
    local function mount(bx, by)
        W.onb, W.mode, W.bmode, W.busy, W.loose = true, MODE_RIDING, 1, false, false
        W.board = { bx, by }
        W.act.x, W.act.y = bx, by
        W.mountedAt = W.t
        W.anim = nil                                              -- (the native half's watch ends the flag at the mount)
    end
    local function game()
        if W.tapAt and W.t >= W.tapAt then                       -- the game's Y, 0.216 s after the press
            W.tapAt = nil
            if W.t < (W.gateUntil or -1) and not W.gateBroken then W.refused = W.refused + 1
            elseif not W.onb and W.bmode == 5 and not W.busy then W.bmode, W.busy, W.gameMountAt, W.threw = 6, true, W.t + 0.52, W.threw + 1 end
        end
        if W.gameMountAt and W.t >= W.gameMountAt then            -- its throwdown puts him on where he stands
            W.gameMountAt = nil
            if W.gameMountTo then
                W.act.x, W.act.y = W.spot[1] - W.ox * W.gameMountTo.far, W.spot[2] - W.oy * W.gameMountTo.far
                W.act.yaw = W.sq + W.gameMountTo.turn
            end
            mount(W.act.x, W.act.y)
        end
        if W.anim and W.t > W.anim.keep then W.anim, W.animTimedOut = nil, true end   -- the native watch: 0.4 s without a refresh
        for _, ev in ipairs(W.events) do if not ev.done and W.t >= ev.at - 1e-9 then ev.done = true ev.fn() end end
        if W.pending then                                         -- a toggle asked for: applied by this tick
            W.pending = false
            if W.onb then
                if W.t < (W.notogUntil or 0) then W.dropped = W.dropped + 1                     -- (native v112: dropped while he is ON the board)
                else W.onb, W.mode, W.bmode, W.steppedOff = false, 0, 5, true end
            elseif not W.ignoreMount then
                local bx, by = W.act.x, W.act.y
                if W.put then bx, by = W.put[1], W.put[2]
                elseif W.anim and W.deck and W.deck[3] - W.top < 9 then bx, by = W.deck[1], W.deck[2] end   -- the board where it lies
                if W.pendFoot == 4 then W.switch = true if W.swTurns then W.act.yaw = W.act.yaw + 180 end end
                mount(bx, by)
                W.put = nil
            end
        end
        W.fr = W.fr + 1
        W.hist[W.fr] = { W.act.x, W.act.y, W.act.yaw }
        if W.onb then W.deck = { W.board[1], W.board[2], W.top + 6.3 }
        elseif W.loose then W.deck = { W.loosePos and W.loosePos[1] or W.act.x, W.loosePos and W.loosePos[2] or W.act.y, W.top + 6.3 }
        else
            local h = W.hist[math.max(1, W.fr - (W.late - 1))]   -- the place of his the drawn deck shows
            local ms = (W.anim and W.animPlays) and (W.t - W.dt - W.anim.t0) * 1000 * W.anim.rate or 0
            local bf, br, bz = bone(ms)
            br = br * W.mirror
            local c, s = math.cos(math.rad(h[3])), math.sin(math.rad(h[3]))
            W.deck = { h[1] + bf * c - br * s, h[2] + bf * s + br * c, W.top + bz }
        end
        if W.watch then W.watch() end
    end
    W.frame = function(n)
        for _ = 1, (n or 1) do
            W.t = W.t + W.dt
            game()
            NATIVE.dropTick(W.t)
            local qd = W.q
            W.q = {}
            for _, fn in ipairs(qd) do fn() end
        end
    end
    W.run = function(sec) W.frame(math.floor(sec / W.dt + 0.5)) end
    W.till = function(pred, sec) local n = math.floor((sec or 8) / W.dt) while n > 0 and not pred() do W.frame(1) n = n - 1 end return pred() end
    W.press = function()                                          -- Y: the game notes the tap, the mod's key handler runs
        W.pressT = W.pressT or W.t
        if not W.tapAt and not W.onb then W.tapAt = W.t + 0.216 end
        local ok, err = pcall(NATIVE.dropKey)
        if not ok then W.logs[#W.logs + 1] = "DROPKEY ERROR " .. tostring(err) W.err = err end
    end
    W.at = function(sec, fn) W.events[#W.events + 1] = { at = (W.pressT or W.t) + sec, fn = fn } end
    W.has = function(s, from) for i = (from or 1), #W.logs do if W.logs[i]:find(s, 1, true) then return i end end return nil end
    W.count = function(s) local n = 0 for _, l in ipairs(W.logs) do if l:find(s, 1, true) then n = n + 1 end end return n end
    W.sent = function(k, v) local n = 0 for _, c in ipairs(W.calls) do if c.k == k and (v == nil or c.v == v) then n = n + 1 end end return n end
    W.off = function() return math.sqrt((W.act.x - W.spot[1]) ^ 2 + (W.act.y - W.spot[2]) ^ 2) end
    W.cameDown = function()                                       -- the "came down" line's two numbers: cm back from the edge, cm off the line
        local i = W.has("the board came down")
        local back, off = (i and W.logs[i] or ""):match("its middle (%-?%d+) cm back from the edge, (%-?%d+) cm off the line")
        return tonumber(back), tonumber(off)
    end
    W.frame(3)                                                    -- (a few frames of standing there)
    return W
end
local out = {}
local function check(name, cond, W)
    if W and (W.err or next(W.unk)) then
        cond = false
        for k in pairs(W.unk) do out[#out + 1] = "FAIL " .. name .. " -- the mod touched something the test does not have: " .. k end
        if W.err then out[#out + 1] = "FAIL " .. name .. " -- " .. tostring(W.err) end
    end
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        out[#out + 1] = string.format("       state %s, on board %s, mode %s, board mode %s, %.2f s after the press, %.1f cm from the spot", tostring(W.DI.state), tostring(W.onb),
            tostring(W.mode), tostring(W.bmode), W.t - (W.pressT or W.t), W.off())
        for _, l in ipairs(W.logs) do out[#out + 1] = "       log: " .. l:sub(1, 330) end
    end
    return cond
end
local all = true
local function near(x, y, tol) return x ~= nil and math.abs(x - y) <= tol end
local function show(W) for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l:sub(1, 330) end end

-- 0. what ships
all = check("0: the set-down ships ON since build 213 (it is the drop-in), its slide out 0.35 s (DropInSetDown 1, DropInSetOutTime 0.35)", SHIP.DropInSetDown == 1 and SHIP.DropInSetOutTime == 0.35) and all
all = check("0: the old way's numbers are as they were (DropInSetTime 0.8, DropInAlignTime 0.4, DropInStart 65, DropInBack 34)",
    SHIP.DropInSetTime == 0.8 and SHIP.DropInAlignTime == 0.4 and SHIP.DropInStart == 65 and SHIP.DropInBack == 34) and all

-- A. THE GOOD PATH: 60 cm from the edge, facing 20 deg off square, goofy, 60 frames a second, the deck two frames late
do local W = world({ S = { DropInSetDown = 1 } })
    local devMax, devLate, landT, deck0 = 0, 0, nil, nil
    W.watch = function()
        local T = W.DI.th
        if T and T.landed and not W.onb then
            landT = landT or W.t
            local dv = math.sqrt((W.deck[1] - T.lx) ^ 2 + (W.deck[2] - T.ly) ^ 2)
            devMax = math.max(devMax, dv)
            if T.mountAt and W.t > T.mountAt - 0.2 then devLate = math.max(devLate, dv) end
        end
    end
    W.press()
    all = check("A: Y by the edge with DropInSetDown on: the state is \"throw\", the game's Y refused for 0.6 s, no step back", W.DI.state == "throw" and #W.gateWrites == 1 and W.gateWrites[1] == 0.6
        and W.stepBacks == 0 and W.DI.th ~= nil and W.DI.sd == nil, W) and all
    all = check("A: the DROP-IN line says it is a set-down", W.has("DROP-IN: an edge 60 cm from you") ~= nil and W.has("a SET-DOWN (DropInSetDown)") ~= nil and W.count("goes the old way") == 0, W) and all
    all = check("A: he stands 69.8 cm back and 16 cm to the right of the edge point for it", near(W.DI.th.sx, W.ex - 69.8, 0.01) and near(W.DI.th.sy, W.ey + 16, 0.01) and near(W.DI.th.dyaw, -20, 0.01), W) and all
    W.run(0.2)
    all = check("A: 0.2 s on: on his way there, no animation asked yet", #W.animAsks == 0 and W.moves >= 10 and W.act.x < W.ex - 60 and W.act.x > W.ex - 69.8, W) and all
    W.run(0.03)
    all = check("A: 0.23 s: the game's own Y came and was refused (no throw of the game's)", W.refused == 1 and W.threw == 0 and W.bmode == 5, W) and all
    W.run(0.04)
    all = check("A: 0.25 s: the animation asked for once, regular (1) -> a goofy rider's clip 2", #W.animAsks == 1 and W.animAsks[1] == 1 and W.anim ~= nil and W.anim.type == 2 and W.DI.th.started == true
        and near(W.DI.th.ts - W.pressT, 0.25, 0.012), W) and all
    all = check("A: ...and said, with the clip, the move and the turn", W.has("SET-DOWN -- the game's throw refused, its animation started by the mod (clip type 2); moved 19 cm, turned -20 deg to stand 70 cm from the edge") ~= nil, W) and all
    W.run(0.07)
    all = check("A: 0.32 s: he stands on his spot, square to the edge", near(W.act.x, W.ex - 69.8, 0.05) and near(W.act.y, W.ey + 16, 0.05) and near(W.act.yaw, 0, 0.05), W) and all
    W.till(function() return W.DI.th and W.DI.th.landed end, 2)
    local T = W.DI.th
    all = check("A: the board comes down 0.5 to 0.6 s into the animation and that is said with where", T and T.landed and near(W.t - T.ts, 0.57, 0.04)
        and W.has("the board came down 0.5") ~= nil and near(W.cameDown(), 33.5, 1) and near(select(2, W.cameDown()), 0, 1), W) and all
    local moves0 = W.moves
    W.till(function() return W.pendAsks > 0 end, 3)
    all = check("A: the mount is asked at the animation's own moment, 1.57 s in, regular", W.pendAsks == 1 and #W.mountCalls == 1 and W.mountCalls[1].sw == 0 and W.mountCalls[1].flip == 0
        and near(W.mountCalls[1].t - T.ts, 1.57, 0.02), W) and all
    all = check(string.format("A: walked onto the board: the deck stays within 10 cm of where it came down (%.1f) and within 1 cm for the last 0.2 s (%.2f)", devMax, devLate),
        devMax < 10 and devMax > 2 and devLate < 1 and W.moves > moves0 + 50, W) and all
    all = check(string.format("A: he is moved on to stand where the board lies: %.1f cm toward the edge, %.1f to the left", W.act.x - (W.ex - 69.8), (W.ey + 16) - W.act.y),
        near(W.act.x - (W.ex - 69.8), 36, 1.5) and near((W.ey + 16) - W.act.y, 16.6, 1.5), W) and all
    W.frame(2)
    all = check("A: on the board the frame after: the \"mount\" state has him, the animation's flag ended, DI.sd set", W.onb and W.DI.state == "mount" and W.DI.th == nil and W.DI.sd == true
        and W.animEnds == 1 and W.has("the mount at the animation's own moment: asked of the game") ~= nil, W) and all
    all = check("A: ...and the line has the time (1.57 s and the two frames the mount takes), the walk, how far the deck strayed and the Speed",
        W.has("on the board 1.60 s after the animation began; walked 40 cm onto it, the deck at most 7.") ~= nil and W.has("cm from where it came down; the anim's Speed read 0 at most") ~= nil, W) and all
    all = check("A: the game's Y stayed refused through the animation (0.3 s, written every frame)", W.sent("ygate", 0.3) > 80 and W.refused == 1 and W.threw == 0, W) and all
    all = check("A: build 210's toggle guard was refreshed every frame of it -- and the mount, asked on foot, went through", W.notog >= 100 and W.dropped == 0 and not W.steppedOff, W) and all
    all = check("A: the sticks were shown centred every frame of it", W.centred >= 4 * 100, W) and all
    W.run(0.13)
    all = check("A: 0.13 s on the board: still waiting to read how he stands", W.DI.state == "mount", W) and all
    W.run(0.05)
    all = check("A: 0.15 s on the board: no first move, no teleport -- straight to the board's parts", (W.DI.state == "out" or W.DI.state == "set") and W.teleports == 0 and W.count("stood square to the edge") == 0
        and W.has("-- no first move after the set-down: the board is taken where it stands") ~= nil, W) and all
    W.frame(2)
    local outAt = W.t
    all = check("A: the board's parts are taken, the slide out begins", W.DI.state == "out" and W.has("7 board parts taken") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 3)
    all = check(string.format("A: the slide out takes DropInSetOutTime (0.35 s): %.2f", W.t - outAt), near(W.t - outAt, 0.35, 0.04) and W.has("drop-in: SET --") ~= nil, W) and all
    all = check(string.format("A: Y to SET in about 2.4 s (%.2f: 0.25 to the animation, 1.60 to the board, 0.15 + 3 frames to the parts, 0.35 out)", W.t - W.pressT), near(W.t - W.pressT, 2.41, 0.05), W) and all
    all = check("A: he was never moved by the on-foot call once on the board, and nothing was asked of the game twice", not W.movedOnBoard and W.pendAsks == 1 and #W.animAsks == 1, W) and all
    -- LB / RB: back onto the ledge takes the same 0.35 s
    W.run(0.4) W.bumpers = 1 W.frame(1) W.bumpers = 0
    local backAt = W.t
    W.till(function() return W.DI.state == nil end, 3)
    all = check(string.format("A: LB/RB back onto the ledge takes 0.35 s too (%.2f), and the drop-in's marks are cleared", W.t - backAt), near(W.t - backAt, 0.35, 0.04) and W.DI.sd == nil and W.DI.th == nil, W) and all
    show(W)
end
-- A2. the same on an edge that faces 120 deg, from the left and nearer: the board must still come down on the line
do local W = world({ S = { DropInSetDown = 1 }, outDeg = 120, dist = 45, side = -12, face = -25 })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("A2: an edge facing 120 deg, pressed 45 cm from it: the board comes down 33 or 34 cm back, on the line; SET",
        W.DI.state == "wait" and near(W.cameDown(), 33.5, 1) and near(select(2, W.cameDown()), 0, 1)
        and W.has("-- no first move after the set-down") ~= nil and W.teleports == 0 and W.stepBacks == 0, W) and all end
-- A3. the deck one frame late, three frames late, and at 120 frames a second: the walk-on holds
for _, c in ipairs({ { 60, 1 }, { 60, 3 }, { 60, 4 }, { 120, 2 }, { 120, 4 }, { 30, 2 } }) do
    local W = world({ S = { DropInSetDown = 1 }, fps = c[1], late = c[2] })
    local devMax, devLate = 0, 0
    W.watch = function()
        local T = W.DI.th
        if T and T.landed and not W.onb then
            local dv = math.sqrt((W.deck[1] - T.lx) ^ 2 + (W.deck[2] - T.ly) ^ 2)
            devMax = math.max(devMax, dv)
            if T.mountAt and W.t > T.mountAt - 0.2 then devLate = math.max(devLate, dv) end
        end
    end
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("A3: %d frames a second, the deck %d late: SET with no first move; the deck strayed %.1f cm at most, %.2f in the last 0.2 s", c[1], c[2], devMax, devLate),
        W.DI.state == "wait" and W.has("-- no first move after the set-down") ~= nil and devMax < ((c[1] == 30) and 18 or 11) and devLate < 1.5, W) and all
end
-- B. THE VETO CAME TOO LATE: the game throws all the same -> the old way, the game's own mount, first move, slide of 0.8 s
do local W = world({ S = { DropInSetDown = 1 }, W = { gateBroken = true } })
    W.press() W.run(0.24)
    all = check("B: the game's throw started all the same: the old way, said; no animation asked, the flag cleared", W.threw == 1 and W.DI.state == "mount" and W.DI.th == nil and W.DI.sd == nil
        and #W.animAsks == 0 and W.sent("throwanim", 0) == 1 and W.has("the game's own throwdown started all the same (the veto came too late) -- today's way from here") ~= nil, W) and all
    local moves = W.moves
    W.run(0.3)
    all = check("B: ...and he is not moved any more while the game throws, no mount of the mod's own", W.moves == moves and W.pendAsks == 0, W) and all
    W.till(function() return W.DI.state == "out" end, 4)
    local outAt = W.t
    all = check("B: the game mounts him, the first move squares him as before", W.onb and W.has("stood square to the edge over 0.40 s") ~= nil and W.pendAsks == 0 and W.off() < 0.01, W) and all
    W.till(function() return W.DI.state == "wait" end, 3)
    all = check(string.format("B: the slide out takes the old DropInSetTime (0.8 s): %.2f", W.t - outAt), near(W.t - outAt, 0.8, 0.04), W) and all
end
-- C. THE BOARD LEFT THE HAND (it lies loose, board mode 8) half a second in -> the mod's own mount at once
do local W = world({ S = { DropInSetDown = 1 } })
    W.press() W.at(0.5, function() W.bmode, W.loose, W.loosePos = 8, true, { W.act.x + 30, W.act.y } end)
    W.till(function() return W.DI.state == "mount" end, 2)
    all = check("C: the board left the hand: said with its mode, the animation's flag cleared", near(W.t - W.pressT, 0.5, 0.02) and W.has("the board left your hand (board mode 8) -- today's way from here") ~= nil
        and W.anim == nil and W.DI.th == nil and W.DI.sd == nil, W) and all
    W.frame(2)
    all = check("C: the mod's own mount within two frames: the board set on the ledge, he over the spot, the mount asked", W.pendAsks == 1 and W.has("the mod's own mount, try 1: board set on the ledge 7 parts") ~= nil, W) and all
    W.till(function() return W.DI.state == "out" end, 3)
    all = check("C: on the board at the spot: no first move there either (0 cm, 0 deg), and no \"after the set-down\"", W.onb and W.off() < 0.01 and W.count("stood square to the edge") == 0
        and W.has("on the board 0 cm from the spot and +0 deg off square to the edge -- no first move") ~= nil and W.count("after the set-down") == 0, W) and all
    local outAt = W.t
    W.till(function() return W.DI.state == "wait" end, 3)
    all = check(string.format("C: ...and the slide out is the old 0.8 s (%.2f)", W.t - outAt), near(W.t - outAt, 0.8, 0.04), W) and all
end
-- D. THE ANIMATION REFUSED by the native half -> the mod's own mount at once
do local W = world({ S = { DropInSetDown = 1 }, W = { animRefuses = true } })
    W.press() W.till(function() return W.DI.state == "mount" end, 2)
    all = check("D: the animation refused: said at 0.25 s, asked once", near(W.t - W.pressT, 0.25, 0.012) and #W.animAsks == 1 and W.has("the native half would not start the animation -- today's way from here") ~= nil, W) and all
    W.frame(2)
    all = check("D: the mod's own mount within two frames (the board in the hand)", W.pendAsks == 1 and W.has("the mod's own mount, try 1: board set on the ledge (not needed)") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("D: ...and on to SET the old way", W.DI.state == "wait" and W.DI.sd == nil and W.has("-- no first move") ~= nil, W) and all
end
-- E. THE BOARD NOT DOWN IN 0.9 s (the flag is set but nothing plays)
do local W = world({ S = { DropInSetDown = 1 }, W = { animPlays = false } })
    W.press() W.till(function() return W.DI.state == "mount" end, 3)
    all = check("E: the board did not come down: given up 0.9 s after the animation was asked, with what the deck read", near(W.t - W.pressT, 0.25 + 0.9, 0.03)
        and W.has("the board did not come down in 0.9 s (the animation did not play: the deck reads 71 cm over the ledge) -- today's way from here") ~= nil and W.anim == nil and W.sent("throwanim", 0) == 1, W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("E: ...the mod's own mount, and on to SET", W.DI.state == "wait" and W.pendAsks == 1 and W.has("the mod's own mount, try 1") ~= nil, W) and all
end
-- F. NOT MOUNTED 0.8 s AFTER ASKING (the game lets the request go)
do local W = world({ S = { DropInSetDown = 1 }, W = { ignoreMount = true } })
    W.press() W.till(function() return W.pendAsks == 1 end, 3)
    local askAt = W.t
    W.till(function() return W.DI.state == "mount" end, 2)
    all = check(string.format("F: not on the board 0.8 s after the mount was asked: given up (%.2f s after)", W.t - askAt), near(W.t - askAt, 0.8, 0.04)
        and W.has("not on the board 0.8 s after the mount was asked -- today's way from here") ~= nil and W.DI.th == nil, W) and all
    W.ignoreMount = false
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("F: ...the mod's own mount gets him on, SET", W.DI.state == "wait" and W.pendAsks == 2 and W.has("the mod's own mount, try 1") ~= nil, W) and all
end
-- F2. ...and where the game never mounts him at all: three tries of the old way, then it is let go inside 6 s
do local W = world({ S = { DropInSetDown = 1 }, W = { ignoreMount = true } })
    W.press() W.till(function() return W.DI.state == nil end, 12)
    all = check("F2: never mounted: the old way's three tries, then let go -- no state, no flag, no marks left", W.DI.state == nil and W.pendAsks == 4 and W.has("no way onto the board within 6 s") ~= nil
        and W.anim == nil and W.DI.th == nil and W.DI.sd == nil, W) and all
end
-- G. A BAIL while it plays
do local W = world({ S = { DropInSetDown = 1 } })
    W.press() W.at(1.0, function() W.mode = MODE_BAILING end)
    W.till(function() return W.DI.state == nil end, 2)
    all = check("G: a bail a second in: let go, the animation's flag ended, the toggle guard shut, the marks cleared", near(W.t - W.pressT, 1.0, 0.02) and W.has("drop-in: the game bailed you") ~= nil
        and W.anim == nil and W.sent("throwanim", 0) == 1 and W.sent("notoggle", 0) == 1 and W.DI.th == nil and W.DI.sd == nil, W) and all
    local moves, gates = W.moves, W.sent("ygate")
    W.run(0.5)
    all = check("G: ...and nothing more is done to him", W.moves == moves and W.sent("ygate") == gates and W.pendAsks == 0, W) and all
end
-- H. THE ANIMATION'S FLAG TAKEN BACK by the game
do local W = world({ S = { DropInSetDown = 1 } })
    W.takeBackAt = W.t + 0.8
    W.press() W.till(function() return W.DI.state == "mount" end, 2)
    all = check("H: the flag taken back 0.8 s in: given up at once, said", near(W.t - W.pressT, 0.8, 0.03) and W.has("the animation's flag was taken back -- today's way from here") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("H: ...the mod's own mount, SET", W.DI.state == "wait" and W.pendAsks == 1, W) and all
end
-- I. A SECOND TAP inside the first quarter second = SWITCH
for _, turns in ipairs({ true, false }) do
    local W = world({ S = { DropInSetDown = 1 }, W = { swTurns = turns } })
    W.press() W.run(0.15) W.press()
    all = check("I: Y again 0.15 s on, the animation not begun: SWITCH, said", W.DI.sw == true and W.DI.state == "throw" and W.has("Y tapped again -- you will be put on in SWITCH") ~= nil, W) and all
    W.till(function() return W.pendAsks > 0 end, 3)
    all = check("I: the animation asked for with 2 -> a goofy rider's clip 1; the mount asked at its moment (1.275 s in) for the switch foot",
        #W.animAsks == 1 and W.animAsks[1] == 2 and W.has("clip type 1, SWITCH") ~= nil and #W.mountCalls == 1 and W.mountCalls[1].sw == 1 and near(W.mountCalls[1].t - (W.pressT + 0.25), 1.275, 0.03), W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    if turns then
        all = check("I: the game turned him round at the switch mount (he faces away from the drop): no first move", W.DI.state == "wait" and W.count("stood square to the edge") == 0
            and W.has("(riding SWITCH: you face away from the drop, the nose points at it) -- no first move after the set-down") ~= nil and near(math.abs(W.act.yaw), 180, 0.1), W) and all
    else
        all = check("I: the game did NOT turn him round: the first move does, as before a set-down existed", W.DI.state == "wait" and W.has("stood square to the edge over 0.40 s (turned") ~= nil
            and W.has("180 deg, moved") ~= nil and W.count("-- no first move") == 0 and near(math.abs(W.act.yaw), 180, 0.1), W) and all
    end
    all = check("I: the game's own Y was refused both times it could have acted (one tap window)", W.threw == 0 and W.refused == 1, W) and all
end
-- J. a second tap after the animation has begun: too late, said once; the set-down goes on regular
do local W = world({ S = { DropInSetDown = 1 } })
    W.press() W.run(0.35) W.press() W.run(0.1) W.press()
    all = check("J: Y again 0.35 s on: too late for switch, said once, not acted on", W.DI.sw == nil and W.count("too late for SWITCH in a set-down") == 1 and W.has("Y tapped again 0.35 s after the first") ~= nil
        and W.count("you will be put on in SWITCH") == 0 and W.DI.state == "throw", W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("J: ...and it ends regular: one animation (1), one mount (regular), SET; the game threw nothing", W.DI.state == "wait" and #W.animAsks == 1 and W.animAsks[1] == 1 and W.mountCalls[1].sw == 0 and W.threw == 0, W) and all
end
-- K. NOT TAKEN: the setting off; an older native half; the game's Y cannot be refused
do local W = world({})
    W.press()
    all = check("K: DropInSetDown 0 (as shipped): the state is \"mount\", nothing of the set-down is touched, stepped back to 65 cm as before", W.DI.state == "mount" and W.DI.th == nil and W.sent("ygate") == 0
        and W.sent("throwanim") == 0 and W.stepBacks == 1 and W.has("stepped back from 60 to 65 cm from the edge for the game's throwdown (ok)") ~= nil
        and W.has("-- waiting for the game to put you on the board") ~= nil and W.count("DropInSetDown") == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("K: ...the game throws and mounts, the first move squares him (31 cm), the slide out 0.8 s: SET %.2f s after Y", W.t - W.pressT), W.DI.state == "wait" and W.threw == 1 and W.refused == 0
        and W.has("stood square to the edge over 0.40 s (turned -20 deg, moved 31 cm)") ~= nil and W.sent("ygate") == 0 and W.sent("throwanim") == 0 and near(W.t - W.pressT, 0.216 + 0.52 + 0.15 + 0.4 + 0.3 + 0.8, 0.12), W) and all
end
do local W = world({ S = { DropInSetDown = 1 }, v = 112 })
    W.press()
    all = check("K2: the native half v112: the old way, and the log says why", W.DI.state == "mount" and W.sent("ygate") == 0 and W.stepBacks == 1
        and W.has("DropInSetDown is on, but this one goes the old way: the native half is v112 and this takes v113") ~= nil and W.has("-- waiting for the game to put you on the board") ~= nil, W) and all end
do local W = world({ S = { DropInSetDown = 1 }, W = { noGate = true } })
    W.press()
    all = check("K3: the controller's timer not written: the old way, said", W.DI.state == "mount" and W.sent("ygate") == 1 and W.stepBacks == 1
        and W.has("goes the old way: the game's own Y could not be refused") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("K3: ...and the game's own throw mounts him as ever", W.DI.state == "wait" and W.threw == 1 and W.sent("throwanim") == 0, W) and all end
do local W = world({ S = { DropInSetDown = 1 }, W = { busy = true } })
    W.press()
    all = check("K4: the game busy with the board at the press: the old way, said with the board's state", W.DI.state == "mount" and W.sent("ygate") == 0
        and W.has("goes the old way: the board is not free in your hand (board mode 5, flags 8: 1 = it lies loose, 4 = you are on it, 8 = the game is busy with it)") ~= nil, W) and all end
do local W = world({ S = { DropInSetDown = 1 }, v = false })
    W.NATIVE.v = nil W.press()
    all = check("K5: the native half's version not known yet: the old way, said so", W.DI.state == "mount" and W.sent("ygate") == 0
        and W.has("goes the old way: the native half is not known yet and this takes v113") ~= nil, W) and all end
-- L. THE FIRST MOVE: skipped under 3 cm and 2 deg, made beyond (the old way); after a set-down up to 12 cm and 6 deg
for _, c in ipairs({ { 2.5, 1.5, false }, { 3.5, 0, true }, { 0, 2.5, true }, { 0, -1.9, false } }) do
    local W = world({ W = { gameMountTo = { far = c[1], turn = c[2] } } })
    W.press() W.till(function() return W.DI.state == "set" or W.DI.state == "align" end, 3)
    local moved = W.DI.state == "align"
    all = check(string.format("L: the game put him on %.1f cm and %+.1f deg off: %s", c[1], c[2], c[3] and "the first move, as before" or "no first move"),
        moved == c[3] and (c[3] or (W.has("-- no first move") ~= nil and W.count("after the set-down") == 0 and W.teleports == 0)), W) and all
    if not moved then
        local t0 = W.t
        W.till(function() return W.DI.state == "out" end, 2)
        all = check(string.format("L: ...and the old way still waits its 0.3 s before the board's parts are taken (%.2f)", W.t - t0), near(W.t - t0, 0.3, 0.035), W) and all
    end
end
do local W = world({ S = { DropInSetDown = 1 }, mirror = -1 })       -- (the clip's side the other way round: the board comes down 32 cm off the line)
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("L2: a set-down whose board came down 32 cm off the line: said, he is squared and moved by the first move, then SET", W.DI.state == "wait" and near(select(2, W.cameDown()), 32.5, 1)
        and W.has("stood square to the edge over 0.40 s") ~= nil and W.count("-- no first move") == 0 and W.off() < 0.01, W) and all end
-- M. a level change while it plays
do local W = world({ S = { DropInSetDown = 1 } })
    W.press() W.run(0.7) W.NATIVE.forgetDrop()
    all = check("M: the level changes 0.7 s in: let go, the flag ended, the marks cleared", W.DI.state == nil and W.DI.th == nil and W.DI.sd == nil and W.anim == nil and W.sent("throwanim", 0) == 1
        and W.has("drop-in: the level changed") ~= nil, W) and all
    local g, an, mv0 = W.sent("ygate"), W.sent("throwanim"), W.moves
    W.run(0.3)
    all = check("M: ...and no call more to the native half's set-down, he is not moved", W.sent("ygate") == g and W.sent("throwanim") == an and W.moves == mv0, W) and all
end
-- N. BUILD 210's RE-MOUNT after a set-down: stepped off by the game while it stood ready -> put back on, the same quick slide
do local W = world({ S = { DropInSetDown = 1 } })
    W.press() W.till(function() return W.DI.state == "wait" end, 5) W.run(0.5)
    W.notogUntil = 0 W.onb, W.mode, W.bmode = false, 0, 5             -- (one gets through all the same)
    W.frame(1)
    all = check("N: stepped off while it stood ready, no Y in the last second: put back on (try 1 of 2)", W.DI.state == "mount" and W.DI.remounts == 1 and W.has("the game stepped you off the board (while it stood ready") ~= nil, W) and all
    W.till(function() return W.DI.state == "out" end, 4)
    local outAt = W.t
    W.till(function() return W.DI.state == "wait" end, 3)
    all = check(string.format("N: ...the mod's own mount, no first move, and the slide out is the set-down's 0.35 s again (%.2f)", W.t - outAt), W.DI.state == "wait" and W.has("the mod's own mount, try 1") ~= nil
        and W.count("stood square to the edge") == 0 and near(W.t - outAt, 0.35, 0.04) and #W.animAsks == 1, W) and all
    -- a toggle that comes up while he is held is dropped by the native half (the guard is refreshed in every state but "ride")
    W.pending = true W.frame(2)
    all = check("N: a board toggle while it stands ready is dropped (the guard is kept open)", W.dropped == 1 and W.onb and W.DI.state == "wait", W) and all
end
-- O. the native half refuses the mount at the animation's own moment
do local W = world({ S = { DropInSetDown = 1 }, W = { mountRefused = true } })
    W.press() W.till(function() return #W.mountCalls == 1 end, 3)
    W.mountRefused = false
    W.frame(1)
    all = check("O: the mount refused by the native half: given up the next frame, said twice over", W.DI.state == "mount" and W.has("the mount at the animation's own moment: refused by the native half") ~= nil
        and W.has("the mount could not be asked for at the animation's own moment -- today's way from here") ~= nil and W.anim == nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("O: ...the mod's own mount, SET", W.DI.state == "wait" and #W.mountCalls == 2 and W.pendAsks == 1, W) and all
end
-- P. on the board before the animation was asked for (not by the set-down)
do local W = world({ S = { DropInSetDown = 1 } })
    W.press() W.at(0.1, function() W.onb, W.mode, W.bmode, W.board = true, MODE_RIDING, 1, { W.act.x, W.act.y } end)
    W.till(function() return W.DI.state == "mount" end, 1)
    all = check("P: on the board 0.1 s in, not by the set-down: the old way from there, he is not moved on the board", near(W.t - W.pressT, 0.1, 0.02)
        and W.has("you are on the board already, and not by the set-down's own mount -- today's way from here") ~= nil and #W.animAsks == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("P: ...and on to SET the old way", W.DI.state == "wait" and not W.movedOnBoard and W.pendAsks == 0, W) and all
end
-- R. DropInBack under 26 cm: the board would come down with its front wheels past the edge -> it is kept 26 cm back for the mount
do local W = world({ S = { DropInSetDown = 1, DropInBack = 20 } })
    W.press() W.till(function() return W.onb end, 4)
    all = check(string.format("R: DropInBack 20: the board comes down 20 cm back, and he is put on it 26 cm back (%.1f): all four wheels on the ledge", W.ex - W.board[1]),
        W.onb and near(W.cameDown(), 19.5, 1) and near(W.ex - W.board[1], 26, 1.2), W) and all
    W.till(function() return W.DI.state == "wait" end, 4)
    all = check("R: ...6 cm from the spot is inside what a set-down leaves alone: no first move, SET", W.DI.state == "wait" and W.has("on the board 6 cm from the spot") ~= nil and W.count("stood square to the edge") == 0, W) and all
end
-- Q. no skater any more while it plays
do local W = world({ S = { DropInSetDown = 1 } })
    W.press() W.run(0.6) W.noSkater = true W.frame(2)
    all = check("Q: the skater gone 0.6 s in: let go, the flag ended", W.DI.state == nil and W.DI.th == nil and W.sent("throwanim", 0) == 1 and W.has("drop-in: the skater is gone") ~= nil, W) and all
end

local o = assert(io.open("sdtest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the set-down's test failed: see sdtest_out.txt", 0) end

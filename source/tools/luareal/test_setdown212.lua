-- test_setdown212.lua (build 212, mk212_setdown.pl): THE SET-DOWN ON THE COPING, the Lua side -- the whole drop-in block
-- cut out of main.lua and run in real Lua against a stand-in for the game and for the native half v114. The world is
-- test_setdown.lua's (an edge, a skater on foot with the board in his hand, the game's Y, its mount, the throwdown
-- clip's own board-bone track) with what the coping variant needs added:
--   HJN_SetDown   "arm" -> "28.10 22.40 6.20 14.60 30.0" (the deck's middle past the edge and over the top: level over
--                 the stance, and in it); "pin", w, k -> the clip's own board carried by the stand-in's skater, the
--                 pin's place, the drawn deck's distance from it ("" once let go, "wait" with no pose); "mount" -> the
--                 gate up for 0.6 s; "state" -> 7 once the game has mounted him with the gate up; "end";
--   the drawn deck  follows the held bone by the pin's weight;
--   the game's test at his feet  a mount asked WITHOUT the gate closer than 24 cm to the edge bails him (the imagined
--                 board's front wheels find no ground): what a mount on the coping asked through HJN_BoardMount would get;
--   the engine's walking (capR)  on foot the capsule is set onto its floor every tick: lower where its middle is out
--                 past the edge (a round bottom of radius capR hanging on it), whatever height the mod moved it to;
--   his capsule (CapsuleComponent) and the movement mode, which the new log lines print.
-- luareal -run test_setdown212.lua result.txt main.lua   (writes sd212_out.txt)
-- Run on the file BEFORE this step (l2.lua) the checks marked [new] must FAIL: that is what shows they look at the
-- thing built. The others hold on both. The stand-ins are models of the game, not the game.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("    local PARTS = { \"Flipper\"", 1, true), "the drop-in block's start was not found")
local b = assert(src:find("\nend\n\n-- (v137) THE NO COMPLY.", a, true), "the drop-in block's end was not found")
local body = src:sub(a, b)
assert(body:find("        if st == \"throw\" then", 1, true), "the state \"throw\" is not in dropTick")
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

local TR = {   -- { ms, forward, right (- = left), up } of the board bone, 30 frames a second (test_setdown.lua's)
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
-- from the edge; under 0 = his middle out past it), side (cm to the right of the edge point's line), face (deg off
-- square), S = settings over the shipped ones, v (the native half's version; 114 here), capR (the engine's walking:
-- the capsule's radius), slope (a top that falls toward its edge, cm a cm), low (a top that RISES to its edge: the
-- floor where he pressed is that many cm under the edge's top, evenly up to it), noSetDown (a native half without
-- HJN_SetDown) and the quirks (W.*) below
local function world(o)
    o = o or {}
    local W = { t = 100, fr = 0, dt = 1 / (o.fps or 60), late = o.late or 2, logs = {}, calls = {}, q = {}, hist = {}, events = {}, unk = {},
                onb = false, mode = 0, bmode = 5, loose = false, busy = false, pending = false, goofy = o.goofy ~= false,
                refused = 0, threw = 0, moves = 0, stepBacks = 0, teleports = 0, pendAsks = 0, dropped = 0, gateWrites = {}, animAsks = {},
                animEnds = 0, mountCalls = {}, centred = 0, sounds = 0, notog = 0, stance = {}, top = 50, mirror = o.mirror or 1,
                animPlays = true, speed = 0,
                sd = {}, sdOn = false, sdEnds = 0, sdArms = 0, sdPins = 0, sdMounts = {}, sdMounted = 0, edgeMounts = 0,
                partsTaken = 0, partsBack = 0, groundOn = 0, groundOff = 0, states = {}, stepMax = 0,
                hh = 90.85, capR = o.capR, slope = o.slope, low = o.low, m0 = 28.10, m1 = 22.40, z0 = 6.20, z1 = 14.60 }
    for k, v in pairs(o.W or {}) do W[k] = v end
    local od = math.rad(o.outDeg or 0)
    W.ox, W.oy, W.ex, W.ey, W.sq = math.cos(od), math.sin(od), 1000, 2000, o.outDeg or 0
    local dist, side = o.dist or 20, o.side or 0
    W.stand = W.top + W.hh + 2.15                                  -- a man on the ledge: its top + the capsule's half height + what walking keeps under it
    W.act = { x = W.ex - W.ox * dist - W.oy * side, y = W.ey - W.oy * dist + W.ox * side, z = W.stand, yaw = W.sq + (o.face or 10) }
    W.d0 = -dist
    local S = {}
    for k, v in pairs(SHIP) do S[k] = v end
    S.DropInSetFly = 0                                              -- (build 216) ...and build 215's rule at the edge (seen to be lowered, then held): build 216's own is case K4
    S.DropInSetDown, S.DropInFar, S.DropInWalkSpeed = 0, 1, 0       -- (build 213) this suite's worlds are build 212's: the set-down off unless a case turns it on, a far press set down behind the edge, a standstill only (build 213's own rules: test_drop213.lua)
    for k, v in pairs(o.S or {}) do S[k] = v end
    W.S = S
    W.spot = { W.ex - W.ox * S.DropInBack, W.ey - W.oy * S.DropInBack }
    W.past = function() return (W.act.x - W.ex) * W.ox + (W.act.y - W.ey) * W.oy end       -- his middle, cm past the edge
    W.across = function() return (W.act.y - W.ey) * W.ox - (W.act.x - W.ex) * W.oy end     -- ...and to the right of the edge point's line
    W.pin = function(k) local al = W.m0 + (W.m1 - W.m0) * k return W.ex + W.ox * al, W.ey + W.oy * al, W.top + W.z0 + (W.z1 - W.z0) * k end
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
            if (W.v or 114) < 113 then return 0 end
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
        elseif k == "nobail" then return 1 end
        return 0
    end
    -- the native half v114's set-down
    if not o.noSetDown then
        G.HJN_SetDown = function(op, ...)
            local n, a = select("#", ...), { ... }
            W.sd[#W.sd + 1] = { op = op, a = a, n = n, t = W.t }
            if op == "arm" then
                W.sdArms = W.sdArms + 1
                if n ~= 12 or W.armRefuses or W.onb or W.bmode ~= 5 or W.partsTaken < 1 then return "" end
                W.sdOn, W.sdUntil, W.sdMounted, W.sdGate, W.pinW, W.pinK, W.pose = true, W.t + 0.4, 0, nil, 0, 0, nil
                return string.format("%.2f %.2f %.2f %.2f %.1f", W.m0, W.m1, W.z0, W.z1, 30.0)
            elseif op == "pin" then
                if n ~= 2 then W.unk["HJN_SetDown pin with " .. n .. " numbers"] = true end
                if not W.sdOn then return "" end
                W.sdPins = W.sdPins + 1
                W.pinW, W.pinK, W.sdUntil = a[1], a[2], W.t + 0.4
                if (a[1] or 0) < (W.pinWmax or 0) - 1e-9 then W.pinWentBack = true end
                W.pinWmax = math.max(W.pinWmax or 0, a[1] or 0)
                local P = W.pose
                if not P then return "wait" end
                return string.format("%.2f %.2f %.2f %.2f %.2f %.2f %.2f", P.cx, P.cy, P.ch, P.px, P.py, P.pz, P.off)
            elseif op == "mount" then
                W.sdMounts[#W.sdMounts + 1] = { sw = a[1], t = W.t, past = W.past(), across = W.across(), z = W.act.z }
                if not W.sdOn or W.sdMountRefused or W.onb or W.busy or W.pending then return 0 end
                W.pendFoot = (a[1] ~= 0) and 4 or 1
                W.sdGate = W.t + 0.6
                W.groundOn, W.ground = W.groundOn + 1, true
                return 1
            elseif op == "state" then return W.sdMounted
            elseif op == "end" then W.sdEnds = W.sdEnds + 1 W.sdOn, W.sdGate = false, nil return 1 end
            W.unk["HJN_SetDown " .. tostring(op)] = true
            return 0
        end
    end
    G.HJN_BoardState = function() if W.noBoard then return -1 end return (W.bmode << 4) | (W.loose and 1 or 0) | (W.onb and 4 or 0) | ((W.busy or W.pending) and 8 or 0) end
    G.HJN_Ledge = function()
        local d = (W.ex - W.act.x) * W.ox + (W.ey - W.act.y) * W.oy       -- (v114: from where he really stands, under 0 past the edge)
        return string.format("edge %.2f %.2f %.2f %.5f %.5f %.2f 0 %.1f %.1f %.1f %.3f %.3f %.3f %.1f %.1f %.1f", W.ex, W.ey, W.top, W.ox, W.oy, d, W.near or 120, W.far or 120, -1, 0, 0, 1, W.fslope or 0, 0, 0)   -- (build 217: the drop just past the edge, further out, and the slope there, as a case sets them)
    end
    G.HJN_DeckWorld = function() if not W.deck then return "" end return string.format("%.2f %.2f %.2f %.2f %.3f", W.deck[1], W.deck[2], W.deck[3], W.act.yaw + ((W.onb and W.switch) and 180 or 0) + (W.deckTurn or 0), 1) end   -- (build 223) on the board the deck's heading is the game's snap's: the capsule's, half a turn round when "is switch" is not the flip flag (0 in every mount of the drop-in); W.deckTurn = a snap that turned it wrong
    G.HJN_BoardStance = function(...)
        local n = select("#", ...)
        W.stance[#W.stance + 1] = { t = W.t, k = select(11, ...), n = n, taken = W.partsTaken }
        return (W.stanceFails or W.partsTaken < 1) and 0 or 7                -- (the native half: no parts taken = nothing placed)
    end
    G.HJN_BoardMeet = function(hang) W.meetCalls = (W.meetCalls or 0) + 1 if W.meets then return W.meets(hang) end return -1, S.DropInPitch, 0 end   -- (build 217: the way down as a case has it, by how far the board is hung)
    G.HJN_BoardKick = function(vx, vy, vz, spin) W.kick = { vx, vy, vz, spin } return 7 end   -- (build 224: the let-go's velocity, for the M8-M10 cases)
    G.HJN_BoardParts = function(...)
        local n = select("#", ...)
        if n > 0 then W.partsTaken = n else W.partsBack, W.partsTaken = W.partsBack + 1, 0 end
        return n
    end
    G.HJN_BoardCapture = function() return (W.partsTaken > 0) and 7 or 0 end
    G.HJN_GroundHold = function(on)
        if on ~= 0 then W.groundOn, W.ground = W.groundOn + 1, true return 1 end
        W.groundOff, W.ground = W.groundOff + 1, false
        return 3
    end
    G.HJN_BoardMount = function(sw, flip)
        W.mountCalls[#W.mountCalls + 1] = { sw = sw, flip = flip, t = W.t, past = W.past() }
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
    local capsule = { GetScaledCapsuleRadius = function() return W.capR or 34 end, GetScaledCapsuleHalfHeight = function() return W.hh end }
    local sk = {
        K2_GetActorLocation = function() return { X = W.act.x, Y = W.act.y, Z = W.act.z } end,
        K2_GetActorRotation = function() return { Pitch = 0, Yaw = W.act.yaw, Roll = 0 } end,
        K2_SetActorLocationAndRotation = function(_, loc, rot)
            W.moves = W.moves + 1
            if W.onb then W.movedOnBoard = true end
            if not W.onb then
                W.zMin, W.zMax = math.min(W.zMin or loc.Z, loc.Z), math.max(W.zMax or loc.Z, loc.Z)
                local step = math.sqrt((loc.X - W.act.x) ^ 2 + (loc.Y - W.act.y) ^ 2)
                W.stepMax, W.stepLast = math.max(W.stepMax, step), step
                W.zFirst = W.zFirst or loc.Z
                W.zLastSet = loc.Z
            end
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
        CapsuleComponent = capsule,
        CustomTimeDilation = 1.0,
    }
    local s0 = setmetatable({}, { __index = function(_, k) local v = sk[k] if v == nil and k ~= "BasedMovement" then W.unk["skater." .. tostring(k)] = true end return v end,
                                  __newindex = function(_, k, v) if k == "CustomTimeDilation" then sk[k] = v else W.unk["skater." .. tostring(k) .. " (written)"] = true end end })
    local mv = { Velocity = { X = 0, Y = 0, Z = 0 }, MovementMode = 1, IsFalling = function() return false end, GetCurrentSpeed = function() return 0 end }
    mv.SetMovementMode = function(self, m) self.MovementMode = m W.mvModes[#W.mvModes + 1] = { t = W.t, m = m, past = W.past() } end   -- (build 216) the engine's movement mode, asked for
    W.mv, W.mvModes = mv, {}
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
    local NATIVE = { v = (o.v == nil) and 114 or o.v, live = true, gt = function(fn) W.q[#W.q + 1] = fn end, heldNote = function() return "" end, stickNow = function() return 0, (W.stickUp or 0) end }
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
            mount(W.act.x, W.act.y)
        end
        if W.anim and W.t > W.anim.keep then W.anim, W.animTimedOut = nil, true end   -- the native watch: 0.4 s without a refresh
        if W.sdOn and W.t > W.sdUntil then W.sdOn, W.sdGate, W.sdTimedOut = false, nil, true end   -- ...and the set-down's: the bone let go 0.4 s after the last asking
        for _, ev in ipairs(W.events) do if not ev.done and W.t >= ev.at - 1e-9 then ev.done = true ev.fn() end end
        -- the engine's walking, every tick he is on foot: the capsule set onto the floor it finds
        if not W.onb and W.mode == 0 and not (W.mv and W.mv.MovementMode ~= 1) then   -- (build 216: its flying and its falling find no floor to set him on)
            local d = W.past()
            if W.slope then W.act.z = W.stand - W.slope * (math.min(d, 0) - W.d0)         -- a top that is not level (lower toward the edge; past it, as at it)
            elseif W.low then W.act.z = W.stand - W.low * math.max(0, math.min(1, math.min(d, 0) / W.d0))   -- a top that rises to its edge (as low as where he pressed further back, too)
            elseif W.capR then
                if d <= 0 then W.act.z = W.stand
                elseif d < W.capR then W.act.z = W.stand - (W.capR - math.sqrt(W.capR ^ 2 - d ^ 2))   -- its round bottom hangs on the edge
                else W.act.z, W.fell = W.act.z - 0.3, true end                             -- no floor: it falls
                W.sinkMax = math.max(W.sinkMax or 0, W.stand - W.act.z)
            end
        end
        if W.pending then                                         -- a toggle asked for: applied by this tick
            W.pending = false
            if W.onb then
                if W.t < (W.notogUntil or 0) then W.dropped = W.dropped + 1                     -- (native v112: dropped while he is ON the board)
                else W.onb, W.mode, W.bmode, W.steppedOff = false, 0, 5, true end
            elseif not W.ignoreMount then
                local gate = W.sdOn and W.sdGate and W.t < W.sdGate
                if not gate and not W.put and W.past() > -24 then
                    -- the game's own test at his feet (IsBoardEncroachedAtLocation): the imagined board's front wheels are out
                    -- past the edge with nothing under them -> "Skateboard encroached", he is bailed
                    W.mode, W.bailedByTest = MODE_BAILING, true
                else
                    local bx, by = W.act.x, W.act.y
                    if gate then                                  -- answered for: mounted where the board is held; the hook puts the parts back in the stance
                        bx, by = W.pin(1)
                        W.askGap = math.sqrt((W.act.x - bx) ^ 2 + (W.act.y - by) ^ 2)
                        if W.sdPutFails == nil then W.sdMounted = 7 else W.sdMounted = W.sdPutFails end
                        W.sdOn, W.sdGate, W.pose = false, nil, nil
                        W.edgeMounts = W.edgeMounts + 1
                        W.act.z = W.stand + 9.3                   -- (the game sets him over the deck: 14.6 - 3.1 - 2.2 higher than on foot)
                        W.modeQ = W.modeSeq and { table.unpack(W.modeSeq) } or nil
                    elseif W.put then bx, by = W.put[1], W.put[2]
                    elseif W.anim and W.deck and W.deck[3] - W.top < 9 then bx, by = W.deck[1], W.deck[2] end   -- the board where it lies
                    if W.pendFoot == 4 then W.switch = true if W.swTurns then W.act.yaw = W.act.yaw + 180 end end
                    mount(bx, by)
                    W.put = nil
                end
            end
        end
        if W.onb and W.modeQ then                                 -- what the game's mode reads in the frames after a mount on the coping
            if #W.modeQ > 0 then W.mode = table.remove(W.modeQ, 1) else W.mode, W.modeQ = MODE_RIDING, nil end
        end
        W.fr = W.fr + 1
        W.hist[W.fr] = { W.act.x, W.act.y, W.act.yaw }
        if W.onb then W.deck = { W.board[1], W.board[2], W.top + 6.3 } W.pose = nil
        elseif W.loose then W.deck = { W.loosePos and W.loosePos[1] or W.act.x, W.loosePos and W.loosePos[2] or W.act.y, W.top + 6.3 } W.pose = nil
        else
            local h = W.hist[math.max(1, W.fr - (W.late - 1))]   -- the place of his the drawn deck shows
            local ms = (W.anim and W.animPlays) and (W.t - W.dt - W.anim.t0) * 1000 * W.anim.rate or 0
            local bf, br, bz = bone(ms)
            br = br * W.mirror
            local c, s = math.cos(math.rad(h[3])), math.sin(math.rad(h[3]))
            W.deck = { h[1] + bf * c - br * s, h[2] + bf * s + br * c, W.top + bz }
            W.pose = nil
            if W.sdOn and W.bmode == 5 then
                -- the native half's pose hook: the clip's own board as the last pose had it (the mesh where it stood for
                -- that pose: a move of his shows in it as late as in the drawn deck), the pin's place by the share last
                -- asked, and the drawn deck -- which follows the held bone
                local cx, cy = W.deck[1], W.deck[2]
                local px, py, pz = W.pin(W.pinK or 0)
                local w = W.noFollow and 0 or (W.pinW or 0)
                W.deck = { W.deck[1] + (px - W.deck[1]) * w, W.deck[2] + (py - W.deck[2]) * w, W.deck[3] + (pz - W.deck[3]) * w }
                if not W.noPose then
                    W.pose = { cx = cx, cy = cy, ch = bz, px = px, py = py, pz = pz,
                               off = math.sqrt((W.deck[1] - px) ^ 2 + (W.deck[2] - py) ^ 2 + (W.deck[3] - pz) ^ 2) }
                end
            end
        end
        if W.watch then W.watch() end
    end
    W.frame = function(n)
        for _ = 1, (n or 1) do
            W.t = W.t + W.dt
            game()
            NATIVE.dropTick(W.t)
            W.states[W.DI.state or "-"] = true
            local qd = W.q
            W.q = {}
            if W.qLate then qd, W.qHeld = (W.qHeld or {}), qd end   -- the game thread's queue run a frame late
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
    W.ops = function(op) local n = 0 for _, c in ipairs(W.sd) do if c.op == op then n = n + 1 end end return n end
    W.off = function() return math.sqrt((W.act.x - W.spot[1]) ^ 2 + (W.act.y - W.spot[2]) ^ 2) end
    W.boardPast = function() return W.board and ((W.board[1] - W.ex) * W.ox + (W.board[2] - W.ey) * W.oy) or nil end
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
        out[#out + 1] = string.format("       state %s, on board %s, mode %s, board mode %s, %.2f s after the press, his middle %.1f cm past the edge", tostring(W.DI.state), tostring(W.onb),
            tostring(W.mode), tostring(W.bmode), W.t - (W.pressT or W.t), W.past())
        for _, l in ipairs(W.logs) do out[#out + 1] = "       log: " .. l:sub(1, 420) end
    end
    return cond and true or false
end
local all = true
local function near(x, y, tol) return x ~= nil and math.abs(x - y) <= tol end
local function show(W) for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l:sub(1, 520) end end
local ON = { DropInSetDown = 1 }                                  -- the user's ini: the test is on, the rest as shipped
local function with(t) local r = { DropInSetDown = 1 } for k, v in pairs(t) do r[k] = v end return r end
local function setOnCoping(W)                                     -- SET, by the coping variant: on the board where the stance has it, in "wait", never slid
    return W.DI.state == "wait" and W.onb and W.edgeMounts == 1 and W.has("ON THE COPING: no slide") ~= nil and not W.states["out"] and not W.states["set"]
        and near(W.boardPast(), W.m1, 0.01)
end
local function setOldSlide(W)                                     -- SET, by build 211's set-down or the old way: the stance reached by the slide out
    return W.DI.state == "wait" and W.onb and W.edgeMounts == 0 and W.states["out"] == true and W.count("ON THE COPING: no slide") == 0 and not W.bailedByTest
end

-- M. (build 217) THE GO: a plain ledge and a plain wall are a straight drop; a ramp and a vert ramp are what they were
do
    local function go(o)
        local W = world({ S = o.S or ON })
        W.near, W.far, W.fslope, W.meets = o.near, o.far, o.fslope or 0, o.meets
        W.press() W.till(function() return W.DI.state == "wait" end, 5)
        W.meetCalls = 0
        W.stickUp = 1 W.till(function() return W.DI.state == "in" end, 1)
        return W, W.DI
    end
    local P = SHIP.DropInPitch
    -- the ledge of 51 cm of 11 Oct 12:32:12: flat floor under the hung board; hung 40 cm out the floor's normal reads 22 deg
    local W, D = go({ near = 50.6, far = 50.6, meets = function(h) if h == 10 then return -1, P, 0 elseif h == 40 then return 90, P, 22 end return 89, P, 0 end })
    all = check("[217] M1: a ledge of 51 cm over flat ground: a straight drop off a plain ledge, said; no look further out (one trace), no ramp, no vert, no slide out",
        D.state == "in" and D.ramp == false and D.vert == false and D.hangTo == nil and W.meetCalls == 1
        and W.has("-- a straight drop off a plain ledge (the same level ground 51 cm down just past the edge and further out) (the ground the wheels would meet is only 0 deg steep): it tips to") ~= nil, W) and all
    -- the ledge of 54 cm with another drop beyond it (12:32:27): flat under the board, the next step's riser further out
    W, D = go({ near = 54.0, far = 96.9, meets = function(h) if h < 8 then return 102, P, 0 end return 108, P, 90 end })
    all = check("[217] M2: a ledge with a second drop beyond it: the floor met flat under the board is the answer -- a straight drop, the riser further out is not looked for",
        D.state == "in" and D.ramp == false and D.vert == false and D.hangTo == nil and W.meetCalls == 1 and W.has("-- a straight drop (the ground the wheels would meet is only 0 deg steep): it tips to") ~= nil, W) and all
    -- the plain walls of 140 and 240 cm (12:32:37, 12:32:47): nothing for the wheels to meet, the same level ground near and far
    W, D = go({ near = 239.8, far = 239.8, meets = function() return -1, P, 0 end })
    all = check("[217] M3: a plain wall of 240 cm: a straight drop off a plain ledge, not a VERT wall",
        D.state == "in" and D.ramp == false and D.vert == false and W.meetCalls == 1 and W.count("a VERT wall") == 0 and W.has("-- a straight drop off a plain ledge (the same level ground 240 cm down") ~= nil, W) and all
    -- Cakovice's vert quarter (9 Oct): 159 cm down just past the edge, 214 further out: still a VERT wall
    W, D = go({ near = 159, far = 214, fslope = 40, meets = function() return -1, P, 0 end })
    all = check("[217] M4: a vert ramp (the ground falls away from the coping: 159 and 214 cm): a VERT wall as before, after the look further out (7 traces)",
        D.state == "in" and D.ramp == false and D.vert == true and W.meetCalls == 7 and W.has("-- a VERT wall (159 cm down just past the edge, 214 further out") ~= nil, W) and all
    -- a bank / a quarter met as hung (01:14:58): a ramp as before
    W, D = go({ near = 10, far = 29, fslope = 29, meets = function() return 63, P, 29 end })
    all = check("[217] M5: a ramp met as hung: pivoted down onto it as before (one trace)",
        D.state == "in" and D.ramp == true and D.vert == false and D.hangTo == nil and W.meetCalls == 1 and W.has("where its front wheels meet the ramp (29 deg steep there)") ~= nil, W) and all
    -- a quarter whose wall is behind the hung wheels' arc: found hung further out, as build 139 made it
    W, D = go({ near = 39, far = 106, fslope = 57, meets = function(h) if h == 16 then return 80, P, 68 end return -1, P, 0 end })
    all = check("[217] M6: nothing met as hung on a ramp: the look further out finds it (hung 16 cm), the board slides out to that as it tips",
        D.state == "in" and D.ramp == true and D.hangTo == 16 and W.meetCalls == 3 and W.has("drop-in: hung 16 cm past the edge the front wheels would meet the ground") ~= nil, W) and all
    -- DropInPlain 0: build 216's GO
    W, D = go({ S = with({ DropInPlain = 0 }), near = 50.6, far = 50.6, meets = function(h) if h == 10 then return -1, P, 0 elseif h == 40 then return 90, P, 22 end return 89, P, 0 end })
    all = check("[217] M7: DropInPlain 0: build 216's -- the 51 cm ledge's floor, hung 40 cm out, is taken for a ramp",
        D.state == "in" and D.ramp == true and D.hangTo == 40 and W.has("where its front wheels meet the ramp (22 deg steep there)") ~= nil, W) and all
    -- (build 224) THE NOSE MEETS THE FACE FIRST (14 Oct, FDR: a 64 deg face under a 52 cm lip; native v122's 4th value: 2)
    local function angle(W) local k = W.kick if not k then return -1 end return math.deg(math.atan(-k[3], math.sqrt(k[1] * k[1] + k[2] * k[2]))) end
    W, D = go({ near = 52, far = 82, fslope = 64, meets = function(h) if h >= 16 then return 98, P, 70, 1 end return 103, P, 64, 2 end })
    all = check("[224] M8: the nose meets the face first as hung: hung further out (16 cm, 6 cm at a time) the front wheels meet it first -- the board slides out to that, said; let go along the board as before",
        D.state == "in" and D.ramp == true and D.hangTo == 16 and D.noseOn == nil and W.meetCalls == 3 and D.down == 98
        and W.has("drop-in: the nose would meet the face before the front wheels (103 deg down the way); hung 16 cm past the edge the wheels meet it first, 98 deg down (70 deg steep there)") ~= nil, W) and all
    W.till(function() return D.state == "ride" end, 3)
    all = check(string.format("[224] M8: ...let go %.1f deg below level, along the board (%.0f)", angle(W), D.down - D.pitch), D.state == "ride" and near(angle(W), D.down - D.pitch, 0.5), W) and all
    W, D = go({ near = 52, far = 82, fslope = 64, meets = function() return 103, P, 64, 2 end })
    all = check("[224] M9: the nose first from every hang tried (7 traces): pivoted down to where the nose meets, and to be let go along the face, said",
        D.state == "in" and D.ramp == true and D.hangTo == nil and D.noseOn == 64 and W.meetCalls == 7 and D.down == 103
        and W.has("let go along the face (64 deg) instead of along the board") ~= nil, W) and all
    W.till(function() return D.state == "ride" end, 3)
    all = check(string.format("[224] M9: ...let go %.1f deg below level: the face's 64, not the board's %.0f", angle(W), D.down - D.pitch), D.state == "ride" and near(angle(W), 64, 0.5), W) and all
    W, D = go({ near = 10, far = 29, fslope = 29, meets = function() return 63, P, 29, 1 end })
    all = check("[224] M10: a front wheel first (the native half says 1): one trace, nothing changed",
        D.state == "in" and D.ramp == true and D.hangTo == nil and D.noseOn == nil and W.meetCalls == 1 and W.count("the nose") == 0, W) and all
    all = check("[217] M: DropInPlain ships 1 and the ini knows it", SHIP.DropInPlain == 1 and src:find("\n    { \"DropInPlain\", \"num\", ", 1, true) ~= nil) and all
end
-- 0. what ships, the menu, the build
all = check("[new] 0: the coping variant's settings as they ship: DropInSetEdge 1, DropInSetReach 45, DropInSetPitchTime 0.22, DropInSetRise 0 (no rise on the actor), DropInSetFeet 1, DropInSetOver 1",
    SHIP.DropInSetEdge == 1 and SHIP.DropInSetReach == 45 and SHIP.DropInSetPitchTime == 0.22 and SHIP.DropInSetRise == 0 and SHIP.DropInSetFeet == 1 and SHIP.DropInSetOver == 1) and all
all = check("0: the set-down ships ON since build 213 (it is the drop-in), and the old numbers are as they were (DropInSetDown 1, DropInSetOutTime 0.35, DropInBack 34, DropInStart 65)",
    SHIP.DropInSetDown == 1 and SHIP.DropInSetOutTime == 0.35 and SHIP.DropInBack == 34 and SHIP.DropInStart == 65) and all
do
    local r1 = src:find("        { \"toggle\", \"DropInSetDown\", \"Set the board down at the edge (test)\"", 1, true)
    local r2 = src:find("        { \"toggle\", \"DropInSetEdge\", \"Set it ON the coping (test)\", 1, 1, \"", 1, true)
    local r3 = src:find("\n    } },\n", r1 or 1, true)
    all = check("[213] 0: the menu's two test rows are gone (the set-down on the coping is the drop-in; the ini keeps both keys)", r1 == nil and r2 == nil and r3 ~= nil) and all
    for _, k in ipairs({ "DropInSetEdge", "DropInSetReach", "DropInSetPitchTime", "DropInSetRise", "DropInSetFeet", "DropInSetOver" }) do
        all = check("[new] 0: the ini knows " .. k, src:find("\n    { \"" .. k .. "\", \"num\", ", 1, true) ~= nil) and all
    end
    all = check("[213] 0: the DropInSetReach text says farther off Y is the game's own throwdown",
        src:find("Farther off, Y is the game's own throwdown\" },", 1, true) ~= nil) and all
    do                                                              -- (build 213) the number itself is each build's own; what must hold is that the three agree and the native half is v114 or later
        local b, wv = src:match("\nNATIVE%.BUILD = (%d+)\n"), src:match("\nNATIVE%.WANT = (%d+) ")
        local lb, ln = src:match("%-%- loaded %(v(%d+) / native v(%d+)%)\"%)")
        all = check("[new] 0: build 212 or later for the native half v114 or later, and the banner says the same two numbers", b ~= nil and tonumber(b) >= 212 and tonumber(wv) >= 114 and lb == b and ln == wv) and all
    end
end

-- A. THE GOOD PATH: 20 cm from the edge, facing 10 deg off square, goofy, 60 frames a second, the deck two frames late
do local W = world({ S = ON })
    local pastMax, deckOffLate, stanceAtMount = -99, 0, nil
    W.watch = function()
        if not W.onb then pastMax = math.max(pastMax, W.past()) end
        local T = W.DI.th
        if T and T.tailSaid and W.pose then deckOffLate = math.max(deckOffLate, W.pose.off) end
    end
    W.press()
    all = check("[new] A: Y 20 cm from the edge with the test on: the state is \"throw\", marked for the coping, the game's Y refused for 0.6 s, no step back", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge == true
        and #W.gateWrites == 1 and W.gateWrites[1] == 0.6 and W.stepBacks == 0 and W.DI.sd == nil, W) and all
    all = check("[new] A: the DROP-IN line says it is a set-down ON THE COPING, and nothing is said under it", W.has("DROP-IN: an edge 20 cm from you") ~= nil and W.has("-- a SET-DOWN ON THE COPING (DropInSetDown, DropInSetEdge)") ~= nil
        and W.count("build 211's way") == 0 and W.count("goes the old way") == 0, W) and all
    all = check("A: nothing is asked of the native half's set-down at the press itself", #W.sd == 0, W) and all
    W.frame(1)
    local arm = W.sd[1]
    all = check("[new] A: the first tick: the board's 7 parts taken, then the arming with the stance's 12 numbers (hang 4, pitch 25, tail 17, kick 7, lip, out, edge, top, DropInBack 34, feet 1)",
        arm ~= nil and arm.op == "arm" and arm.n == 12 and W.sdArms == 1 and W.partsTaken == 7 and arm.a[1] == 4 and arm.a[2] == 25 and arm.a[3] == 17 and arm.a[4] == 7 and arm.a[5] == 0
        and near(arm.a[6], 1, 1e-6) and near(arm.a[7], 0, 1e-6) and arm.a[8] == W.ex and arm.a[9] == W.ey and arm.a[10] == W.top and arm.a[11] == 34 and arm.a[12] == 1, W) and all
    local T = W.DI.th
    all = check("[new] A: he is to stand 7.7 cm behind the edge and 16 cm to the right of the edge point's line (the clip's board, 35.8 cm ahead, then comes down 28.1 cm past the edge); build 211's spot is kept",
        T ~= nil and near(T.sx, W.ex - 7.7, 0.01) and near(T.sy, W.ey + 16, 0.01) and near(T.sx211, W.ex - 69.8, 0.01) and near(T.sy211, W.ey + 16, 0.01) and near(T.back, 7.7, 0.01), W) and all
    all = check("[new] A: ...and that is said, with the capsule the game has him in and the rise to expect at the mount",
        W.has("on the coping: the board will come down level with its middle 28 cm PAST the edge and end tail-down 22 cm past it, 8 cm higher; you stand 8 cm behind the edge (your capsule: radius 34, half height 90.85; the game's movement mode 1); at the mount you will come up about 9 cm") ~= nil, W) and all
    all = check("[new] A: no rise on the actor as shipped", T ~= nil and T.rise == 0, W) and all
    W.run(0.2)
    local pins0 = 0
    for _, c in ipairs(W.sd) do if c.op == "pin" and c.a[1] == 0 and c.a[2] == 0 then pins0 = pins0 + 1 end end
    all = check("[new] A: 0.2 s on: the bone asked for on every tick with no weight yet (the native half lets go 0.4 s after the last asking), no animation yet", pins0 >= 12 and pins0 == W.ops("pin") and #W.animAsks == 0 and W.sdOn, W) and all
    W.run(0.07)
    all = check("[new] A: 0.25 s: the game's own Y came and was refused; the animation asked for once (1 -> a goofy rider's clip 2), and the line says where he stands", W.refused == 1 and W.threw == 0 and #W.animAsks == 1 and W.animAsks[1] == 1
        and W.has("SET-DOWN -- the game's throw refused, its animation started by the mod (clip type 2); moved 20 cm, turned -10 deg to stand 8 cm from the edge") ~= nil, W) and all
    W.run(0.07)
    all = check(string.format("[new] A: 0.32 s: he stands at the edge, square to it: %.1f cm behind it, %.1f to the right of the line", -W.past(), W.across()), near(W.past(), -7.7, 0.05) and near(W.across(), 16, 0.05) and near(W.act.yaw, 0, 0.05), W) and all
    W.till(function() return W.DI.th and W.DI.th.landed end, 2)
    T = W.DI.th
    local landAt = W.t
    W.frame(1)
    all = check("[new] A: the board comes down 0.5 to 0.6 s into the animation HELD on the coping, 28 cm past the edge and on the line, the real deck with it; the bone's weight is 1 from the next tick and never went back",
        T ~= nil and T.landed and near(landAt - T.ts, 0.57, 0.04) and W.has("HELD on the coping: its middle 28 cm past the edge, 0 cm off the line; the real deck 0.") ~= nil
        and W.pinWmax == 1 and not W.pinWentBack, W) and all
    W.till(function() return W.DI.th and W.DI.th.tailSaid end, 1)
    local tailAt = W.t
    W.frame(1)
    all = check(string.format("[new] A: the tail goes down over DropInSetPitchTime (0.22 s) from 0.04 s after the landing: down %.2f s after it, said; the native half is then asked for the whole stance (k 1)", (T and T.landAt) and (tailAt - T.landAt) or -1),
        T ~= nil and T.landAt ~= nil and near(tailAt - T.landAt, 0.26, 0.035) and W.pinK == 1 and W.has("tail down 0.8") ~= nil, W) and all
    W.till(function() return W.pendAsks > 0 end, 3)
    local m = W.sdMounts[1]
    all = check("[new] A: the mount is asked at the animation's own moment (1.57 s in) of the native half's set-down, regular, once -- NOT through HJN_BoardMount (the game's test at his feet would bail him there)",
        W.pendAsks == 1 and #W.sdMounts == 1 and m.sw == 0 and #W.mountCalls == 0 and T ~= nil and near(m.t - T.ts, 1.57, 0.02) and W.sent("nobail", 0.4) == 1
        and W.has("the mount at the animation's own moment: asked of the game") ~= nil, W) and all
    all = check(string.format("[new] A: he was walked to the held board: at the asking his middle is %.1f cm past the edge and %.1f cm off the line (the board's middle: 22.4 past it)", m and m.past or -99, m and m.across or -99),
        m ~= nil and near(m.past, 22.1, 1.0) and near(m.across, 0, 1.0), W) and all
    all = check("[new] A: ...and the asking's line has the game's movement mode, whether it has him falling, where he stands and what he was raised",
        W.has("at the mount's asking: the game's movement mode 1, falling false; your middle +22 cm from the edge (+ = past it), 0.0 cm lower than the mod set you") ~= nil and W.has("raised 0.0 cm") ~= nil, W) and all
    all = check(string.format("[new] A: the real deck stayed on the held bone through the walk (at most %.2f cm off once the tail was down)", deckOffLate), deckOffLate < 0.01 and W.sdPins > 80, W) and all
    all = check("A: every move on foot was made at the height he was pressed at (no rise), a step a frame of 6 cm at most", W.zMin == W.stand and W.zMax == W.stand and W.stepMax < 6 and W.stepMax > 1, W) and all
    local stances0 = #W.stance
    W.frame(1)
    all = check("[new] A: the frame after: the game's test at his feet was answered for (no bail), he is on the board where the stance has it, the parts put back inside the mount", W.onb and not W.bailedByTest and W.edgeMounts == 1
        and near(W.boardPast(), 22.4, 0.01) and W.sdMounted == 7, W) and all
    all = check("[new] A: ...and on that very frame the drop-in is in \"wait\" and has placed the stance (k 1): no frame with nobody placing the parts; the marks of a set-down are set",
        W.DI.state == "wait" and W.DI.th == nil and W.DI.sd == true and W.DI.tapOver == true and W.DI.ground == true and W.DI.edgeAt == W.t and W.DI.k == 1
        and #W.stance == stances0 + 1 and W.stance[#W.stance].t == W.t and W.stance[#W.stance].k == 1 and W.stance[#W.stance].taken == 7, W) and all
    all = check("[new] A: the two lines: on the board ON THE COPING with what the walk did and the rise (9.3 cm), and SET with the deck angle the native half really used (30) and no slide",
        W.has("on the board 1.60 s after the animation began, ON THE COPING: no slide (7 parts put back in the stance inside the game's own mount); walked 3") ~= nil
        and W.has("you are now 9.3 cm higher than the mod had you on foot; the held deck was at most 0.0 cm from its place; the game had you at most 0.0 cm lower than the mod set you") ~= nil
        and W.has("drop-in: SET -- 7 board parts: the back wheels hung 4.0 cm past the edge, the tail down on the ledge, the deck up 30 deg. Stick UP = drop in, LB/RB = back, Y = off (set down ON THE COPING: no slide; the game is told the board is grounded while it is held)") ~= nil
        and W.sounds == 1 and W.animEnds == 1, W) and all
    all = check(string.format("[new] A: Y to SET in about 1.85 s (%.2f: 0.25 to the animation, 1.57 to the asking, 2 frames; build 211: 2.4), with no \"mount\", \"set\" or \"out\" state on the way", W.t - W.pressT),
        near(W.t - W.pressT, 1.86, 0.04) and not W.states["mount"] and not W.states["set"] and not W.states["out"] and not W.states["align"], W) and all
    all = check("A: no teleport, no step back, no throw of the game's; he was never moved by the on-foot call once on the board; the native half was never told to end it (it lets go itself inside the mount)",
        W.teleports == 0 and W.stepBacks == 0 and W.threw == 0 and W.refused == 1 and not W.movedOnBoard and W.sdEnds == 0 and W.pendAsks == 1, W) and all
    all = check(string.format("[new] A: five trace lines or more while the board was held (%d), each with the bone's weight, his place, the deck and the gap", W.count("s: the board bone held ")),
        W.count("s: the board bone held ") >= 5 and W.has("the board bone held 100%, the tail 100% down; your middle +") ~= nil, W) and all
    W.run(0.2)
    all = check("[new] A: held: the stance placed on every frame, the toggle guard kept open", #W.stance == stances0 + 1 + 12 and W.DI.state == "wait" and W.notog > 100, W) and all
    -- LB / RB: back onto the ledge takes the set-down's 0.35 s, and everything is given back
    W.run(0.3) W.bumpers = 1 W.frame(1) W.bumpers = 0
    local backAt = W.t
    W.till(function() return W.DI.state == nil end, 3)
    all = check(string.format("[new] A: LB/RB back onto the ledge takes 0.35 s (%.2f); the parts and the grounded hold are given back, the marks cleared", W.t - backAt), near(W.t - backAt, 0.35, 0.04) and W.DI.sd == nil and W.DI.th == nil
        and W.partsTaken == 0 and W.partsBack == 1 and W.groundOff == 1 and W.sdEnds == 0, W) and all
    show(W)
end
-- A2. the same on an edge that faces 120 deg, from the left and further back
do local W = world({ S = ON, outDeg = 120, dist = 40, side = -12, face = -25 })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] A2: an edge facing 120 deg, pressed 40 cm from it and 12 to the left: SET on the coping, the board 22.4 cm past the edge on the line", setOnCoping(W)
        and W.has("HELD on the coping: its middle 28 cm past the edge, ") ~= nil and W.has("0 cm off the line; the real deck 0.") ~= nil
        and W.has("moved 43 cm, turned +25 deg to stand 8 cm from the edge") ~= nil and near(W.sdMounts[1].past, 22.1, 1.0) and near(W.sdMounts[1].across, 0, 1.0), W) and all end
-- A3. other frame rates and a deck shown later
for _, c in ipairs({ { 60, 1 }, { 60, 3 }, { 120, 2 }, { 30, 2 } }) do
    local W = world({ S = ON, fps = c[1], late = c[2] })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    local m = W.sdMounts[1]
    all = check(string.format("[new] A3: %d frames a second, the deck %d late: SET on the coping; at the asking his middle %.1f cm past the edge, %.1f off the line", c[1], c[2], m and m.past or -99, m and m.across or -99),
        setOnCoping(W) and m ~= nil and near(m.past, 22.1, 1.5) and near(m.across, 0, 1.5), W) and all
end
-- A4. a regular-footed rider: the other clip (the same track 1.3 times as fast), the mount at 1.275 s
do local W = world({ S = ON, goofy = false })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    local m = W.sdMounts[1]
    all = check("[new] A4: a regular-footed rider (clip 1): SET on the coping, the mount asked 1.275 s in", setOnCoping(W) and W.has("clip type 1)") ~= nil and m ~= nil and near(m.t - (W.pressT + 0.25), 1.275, 0.03)
        and near(m.past, 22.1, 1.5), W) and all end

-- B. FARTHER THAN DropInSetReach: build 211's set-down, said -- NOT the game's own throw
do local W = world({ S = ON, dist = 60, face = 20 })
    W.press()
    all = check("B: Y 60 cm from the edge: a set-down, not on the coping; the game's Y refused", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge == nil and #W.gateWrites == 1
        and W.has("-- a SET-DOWN (DropInSetDown): the game's own throw is refused") ~= nil, W) and all
    all = check("[new] B: ...and the line under it says why: farther than DropInSetReach, set down behind the edge and slid out",
        W.has("drop-in:    an edge 60 cm away, farther than DropInSetReach (45 cm): the board is set ON the coping only for a press made at the edge -- this one is set down behind it and slides out (build 211's way)") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("B: ...build 211's set-down to its end: he stands 70 cm back, the board comes down 33 cm back, SET %.2f s after Y through the slide out; the game threw nothing", W.t - W.pressT),
        setOldSlide(W) and W.threw == 0 and W.refused == 1 and W.has("to stand 70 cm from the edge") ~= nil and W.has("its middle 33 cm back from the edge") ~= nil
        and W.has("-- no first move after the set-down") ~= nil and near(W.t - W.pressT, 2.41, 0.06) and #W.mountCalls == 1, W) and all
    all = check("B: the native half's set-down was never asked anything", #W.sd == 0, W) and all
end
for _, c in ipairs({ { 45, true }, { 46, false } }) do
    local W = world({ S = ON, dist = c[1] })
    W.press()
    all = check(string.format("%sB2: pressed %d cm from the edge with DropInSetReach 45: %s", c[2] and "[new] " or "", c[1], c[2] and "on the coping" or "behind the edge"), W.DI.th ~= nil and (W.DI.th.edge == true) == c[2], W) and all
end
do local W = world({ S = with({ DropInSetReach = 70 }), dist = 60 })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] B3: DropInSetReach 70, pressed 60 cm from the edge: on the coping (he is moved 53 cm to the edge first)", setOnCoping(W) and W.has("moved 55 cm") ~= nil, W) and all end
-- C. NOT TAKEN: the row off; an older native half; a native half without the call; the test itself off
do local W = world({ S = with({ DropInSetEdge = 0 }) })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("C: DropInSetEdge 0, pressed 20 cm from the edge: build 211's set-down (70 cm back, the slide out), nothing said about the coping, the native half's set-down never asked",
        setOldSlide(W) and #W.sd == 0 and W.has("-- a SET-DOWN (DropInSetDown): the game's own throw is refused") ~= nil and W.count("coping") == 0 and W.count("build 211's way") == 0
        and W.has("to stand 70 cm from the edge") ~= nil and W.threw == 0, W) and all end
do local W = world({ S = ON, v = 113 })
    W.press()
    all = check("[new] C2: the native half v113: build 211's set-down, and the line under the DROP-IN line says the coping takes v114", W.DI.th ~= nil and W.DI.th.edge == nil
        and W.has("drop-in:    the board is set ON the coping only with the native half v114 (this one is v113) -- this one is set down behind the edge and slides out (build 211's way)") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("C2: ...to its end, the native half's set-down never asked", setOldSlide(W) and #W.sd == 0, W) and all end
do local W = world({ S = ON, noSetDown = true })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("C3: a native half that says 114 but has no HJN_SetDown: build 211's set-down to its end, no error", setOldSlide(W) and W.DI.th == nil and W.threw == 0, W) and all end
do local W = world({})
    W.press()
    all = check("C4: DropInSetDown 0 (as shipped), 20 cm from the edge: the old drop-in -- the state is \"mount\", stepped back to 65 cm, nothing of either set-down touched",
        W.DI.state == "mount" and W.DI.th == nil and W.sent("ygate") == 0 and W.sent("throwanim") == 0 and W.stepBacks == 1 and #W.sd == 0
        and W.has("stepped back from 20 to 65 cm from the edge for the game's throwdown (ok)") ~= nil and W.has("-- waiting for the game to put you on the board") ~= nil
        and W.count("DropInSetDown") == 0 and W.count("coping") == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("C4: ...the game throws and mounts, the first move, the 0.8 s slide: SET", W.DI.state == "wait" and W.threw == 1 and W.states["out"] == true and #W.sd == 0 and W.sent("ygate") == 0, W) and all
end

-- D. THE ARMING REFUSED by the native half -> build 211's set-down, from its own spot
do local W = world({ S = ON, W = { armRefuses = true } })
    W.press() W.frame(1)
    all = check("[new] D: the arming refused: said, the parts given back, the mark taken off -- and he goes to build 211's spot, 70 cm back", W.sdArms == 1 and W.partsTaken == 0 and W.partsBack == 1 and W.DI.th ~= nil and W.DI.th.edge == nil
        and near(W.DI.th.sx, W.ex - 69.8, 0.01) and W.has("the set-down on the coping was not armed (ExpandedTricks.native.log says why) -- build 211's set-down: you stand DropInBack + 36 cm back") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("D: ...build 211's set-down to its end: the slide out, the mount through HJN_BoardMount, the bone never asked for", setOldSlide(W) and W.ops("pin") == 0 and W.ops("mount") == 0 and #W.mountCalls == 1
        and W.has("to stand 70 cm from the edge") ~= nil and W.has("-- no first move after the set-down") ~= nil, W) and all
end
-- D2. armed, but THE ANIMATION IS REFUSED a quarter second on; D3. armed, but THE GAME THROWS ALL THE SAME (the veto came too late)
do local W = world({ S = ON, W = { animRefuses = true } })
    W.press() W.till(function() return W.DI.state == "mount" end, 2)
    all = check("[new] D2: the animation refused after the arming: the old way, said -- and the set-down is ended, the parts given back", near(W.t - W.pressT, 0.25, 0.012) and W.sdArms == 1 and W.sdEnds == 1 and not W.sdOn
        and W.partsTaken == 0 and W.has("the native half would not start the animation -- today's way from here") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("D2: ...the mod's own mount from the old spot, SET", setOldSlide(W) and #W.mountCalls == 1 and near(W.mountCalls[1].past, -34, 0.01), W) and all
end
do local W = world({ S = ON, W = { gateBroken = true } })
    W.press() W.run(0.24)
    all = check("[new] D3: the game's throw started all the same after the arming: the old way, said -- the set-down ended and the parts given back before the game does anything with the board", W.threw == 1 and W.DI.state == "mount"
        and W.DI.th == nil and W.sdEnds == 1 and not W.sdOn and W.partsTaken == 0 and #W.animAsks == 0 and W.has("the game's own throwdown started all the same (the veto came too late) -- today's way from here") ~= nil, W) and all
    local moves = W.moves
    W.run(0.3)
    all = check("D3: ...and he is not moved any more while the game throws", W.moves == moves and W.pendAsks == 0, W) and all
end
-- E. A SECOND TAP (SWITCH) after the arming, DropInSetSwitch 0 (build 222): let go, and build 211's set-down from where he is
-- (build 223: the shipped 1 keeps the coping in switch, cases E3-E8)
do local W = world({ S = with({ DropInSetSwitch = 0 }), W = { swTurns = true } })
    W.press() W.run(0.15)
    local x0, y0, stepBefore = W.act.x, W.act.y, W.stepLast or 0
    W.press()
    all = check("E: Y again 0.15 s on, the animation not begun: SWITCH, said", W.DI.sw == true and W.DI.state == "throw" and W.has("Y tapped again -- you will be put on in SWITCH") ~= nil, W) and all
    W.frame(1)
    all = check("[new] E: the next tick: the native half's set-down ended once, the parts given back, the mark off, build 211's spot his aim -- said", W.sdEnds == 1 and not W.sdOn and W.partsTaken == 0 and W.partsBack == 1
        and W.DI.th ~= nil and W.DI.th.edge == nil and near(W.DI.th.sx, W.ex - 69.8, 0.01) and near(W.DI.th.sy, W.ey + 16, 0.01)
        and W.has("SWITCH: DropInSetSwitch is 0 -- build 211's set-down, from its own spot") ~= nil, W) and all
    all = check(string.format("E: ...and he is not jerked: %.2f cm moved on that tick, %.2f on the tick before (he eases again from where the first ease has him)", math.sqrt((W.act.x - x0) ^ 2 + (W.act.y - y0) ^ 2), stepBefore),
        stepBefore > 0.5 and math.abs(math.sqrt((W.act.x - x0) ^ 2 + (W.act.y - y0) ^ 2) - stepBefore) < 0.3, W) and all
    local pins = W.ops("pin")
    W.till(function() return #W.animAsks > 0 end, 1)
    all = check(string.format("[new] E: the animation starts 0.24 s after the tap (%.2f s after the first press), asked for with 2 -> a goofy rider's clip 1; the line counts the move from where he was pressed (52 cm, -10 deg); the bone is not asked for any more", W.t - W.pressT),
        near(W.t - W.pressT, 0.15 + 0.017 + 0.25, 0.03) and W.animAsks[1] == 2 and W.has("clip type 1, SWITCH); moved 52 cm, turned -10 deg to stand 70 cm from the edge") ~= nil and W.ops("pin") == pins, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] E: ...build 211's set-down to its end in SWITCH: the board 33 cm back, the mount through HJN_BoardMount for the switch foot, the slide out; no step over 8 cm a frame; the game threw nothing",
        setOldSlide(W) and #W.mountCalls == 1 and W.mountCalls[1].sw == 1 and W.ops("mount") == 0 and W.has("its middle 33 cm back from the edge") ~= nil and W.stepMax < 8 and W.threw == 0 and W.sdEnds == 1, W) and all
end
do local W = world({ S = with({ DropInSetSwitch = 0 }) })
    W.press() W.press()                                           -- (twice before the first tick)
    W.frame(2)
    all = check("[new] E2: the second tap before the first tick: never armed, nothing to end, build 211's set-down in SWITCH", W.DI.sw == true and W.sdArms == 0 and W.sdEnds == 0 and W.DI.th ~= nil and W.DI.th.edge == nil
        and near(W.DI.th.sx, W.ex - 69.8, 0.01) and W.has("SWITCH: DropInSetSwitch is 0 -- build 211's set-down") ~= nil, W) and all end
-- E3. (build 223) A SECOND TAP (SWITCH) after the arming with DropInSetSwitch 1 (as shipped): THE COPING IS KEPT. He stands
-- and faces the drop as for a regular one, the switch stance's own clip (a goofy rider's clip 1: the same track 1.3 times
-- as fast), the mount asked of the native half for the switch foot at 1.275 s; the game's switch mount turns him half a
-- turn (swTurns) and its snap keeps the deck's nose to the drop (the stand-in's HJN_DeckWorld): SET on the coping, no slide
do local W = world({ S = ON, W = { swTurns = true } })
    all = check("[new] E3: DropInSetSwitch ships 1, and the ini knows it (no menu row)", W.S.DropInSetSwitch == 1 and src:find("\n    { \"DropInSetSwitch\", \"num\", 0, 1, ", 1, true) ~= nil
        and select(2, src:gsub("\"DropInSetSwitch\"", "")) == 1, W) and all
    W.press() W.run(0.15)
    local sx, sy = W.DI.th and W.DI.th.sx, W.DI.th and W.DI.th.sy
    W.press()
    all = check("E3: Y again 0.15 s on, the animation not begun: SWITCH, said", W.DI.sw == true and W.DI.state == "throw" and W.has("Y tapped again -- you will be put on in SWITCH") ~= nil, W) and all
    W.frame(1)
    all = check("[new] E3: the next tick: the coping is KEPT -- nothing ended or given back, the mark on, the aim still the coping's own spot (8 cm behind the edge, 16 to the right); said once",
        W.sdEnds == 0 and W.sdOn and W.partsTaken == 7 and W.partsBack == 0 and W.DI.th ~= nil and W.DI.th.edge == true and W.DI.th.swEdge == true
        and near(W.DI.th.sx, sx, 0.001) and near(W.DI.th.sy, sy, 0.001) and near(W.DI.th.sx, W.ex - 7.7, 0.01) and near(W.DI.th.sy, W.ey + 16, 0.01)
        and W.count("SWITCH ON THE COPING (DropInSetSwitch)") == 1 and W.count("build 211's set-down") == 0, W) and all
    W.till(function() return #W.animAsks > 0 end, 1)
    all = check(string.format("[new] E3: the animation starts 0.24 s after the press (%.2f), asked for with 2 -> a goofy rider's clip 1; the line counts the move to the coping's spot", W.t - W.pressT),
        near(W.t - W.pressT, 0.25, 0.012) and W.animAsks[1] == 2 and W.has("clip type 1, SWITCH); moved 20 cm, turned -10 deg to stand 8 cm from the edge") ~= nil, W) and all
    local yawFoot, pastMax = nil, -99
    W.watch = function() if not W.onb then yawFoot = W.act.yaw pastMax = math.max(pastMax, W.past()) end end
    W.till(function() return W.DI.state == "wait" end, 5)
    local m = W.sdMounts[1]
    all = check(string.format("[new] E3: the mount asked of the native half for the SWITCH foot %.3f s into the clip (1.275), his middle %.1f cm past the edge; HJN_BoardMount never called; the asking line says switch",
        m and (m.t - W.pressT - 0.25) or -1, m and m.past or -99),
        m ~= nil and m.sw == 1 and near(m.t - (W.pressT + 0.25), 1.275, 0.03) and near(m.past, 22.1, 1.5) and #W.mountCalls == 0
        and W.has("; SWITCH: foot position 4, flip flag 0 -- the game turns you half a turn itself") ~= nil, W) and all
    all = check(string.format("[new] E3: SET ON THE COPING in switch: no slide, no teleport, no step over 8 cm (%.1f), the game's switch flag up; he faced the drop on foot (%.1f) and faces away from it on the board (%.1f)",
        W.stepMax, yawFoot or -999, W.act.yaw),
        setOnCoping(W) and W.switch == true and W.teleports == 0 and W.threw == 0 and W.stepMax < 8 and near(yawFoot or -999, W.sq, 0.5)
        and near(((W.act.yaw - W.sq - 180) + 540) % 360 - 180, 0, 0.5) and not W.movedOnBoard, W) and all
    local said = nil
    for _, l in ipairs(W.logs) do if l:find("SWITCH on the coping: you face [%+%-]0 deg off the way away from the drop, the deck's nose [%+%-]0 deg off the way down %(0 wanted for both%); the game says switch true") then said = l end end
    all = check("[new] E3: ...and the line after the mount says both are as planned (he faces away from the drop, the deck's nose points at it)", said ~= nil and W.count("NOT AS PLANNED") == 0, W) and all
end
-- E4. ...a switch mount in which the game does NOT turn him (no swTurns): SET on the coping all the same, said loudly
do local W = world({ S = ON })
    W.press() W.run(0.15) W.press()
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] E4: the game did not turn him at its switch mount: SET on the coping all the same, the line says NOT AS PLANNED once (said, not acted on: no teleport, no move on the board)",
        setOnCoping(W) and W.switch == true and W.count("NOT AS PLANNED") == 1 and W.has("you face -180 deg off the way away from the drop") ~= nil and W.teleports == 0 and not W.movedOnBoard, W) and all
end
do local W = world({ S = ON, W = { swTurns = true, deckTurn = 180 } })
    W.press() W.run(0.15) W.press()
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] E4: ...nor where the game's snap turned the board half a turn: said (the deck's nose 180 deg off)", setOnCoping(W) and W.count("NOT AS PLANNED") == 1
        and W.has("the deck's nose -180 deg off the way down") ~= nil, W) and all
end
-- E5. a regular-footed rider tapping twice: his switch clip is type 2 (the game's own pick), the mount at its 1.57 s
do local W = world({ S = ON, goofy = false, W = { swTurns = true } })
    W.press() W.run(0.15) W.press()
    W.till(function() return W.DI.state == "wait" end, 5)
    local m = W.sdMounts[1]
    all = check(string.format("[new] E5: a regular-footed rider in switch: clip type 2, the mount %.3f s into it (1.57) for the switch foot; SET on the coping facing away from the drop", m and (m.t - W.pressT - 0.25) or -1),
        setOnCoping(W) and W.has("clip type 2, SWITCH)") ~= nil and m ~= nil and m.sw == 1 and near(m.t - (W.pressT + 0.25), 1.57, 0.03) and near(m.past, 22.1, 1.5)
        and near(((W.act.yaw - W.sq - 180) + 540) % 360 - 180, 0, 0.5) and W.count("NOT AS PLANNED") == 0, W) and all
end
-- E6. the second tap before the first tick: armed all the same, the coping kept
do local W = world({ S = ON, W = { swTurns = true } })
    W.press() W.press()                                           -- (twice before the first tick)
    W.frame(2)
    all = check("[new] E6: the second tap before the first tick: armed all the same, the coping kept, said once", W.DI.sw == true and W.sdArms == 1 and W.sdEnds == 0
        and W.DI.th ~= nil and W.DI.th.edge == true and W.count("SWITCH ON THE COPING (DropInSetSwitch)") == 1, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] E6: ...SET on the coping in switch, the mount through the native half's set-down only", setOnCoping(W) and W.switch == true and W.sdMounts[1] ~= nil and W.sdMounts[1].sw == 1 and #W.mountCalls == 0, W) and all
end
-- E7. decided once: DropInSetSwitch saved as 0 in the middle of the set-down changes nothing of this one
do local W = world({ S = ON, W = { swTurns = true } })
    W.press() W.run(0.15) W.press() W.frame(1)
    W.S.DropInSetSwitch = 0
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] E7: DropInSetSwitch turned 0 after the tap was taken: this set-down goes on as decided (on the coping, in switch), nothing given back half way",
        setOnCoping(W) and W.switch == true and W.sdEnds == 0 and W.count("DropInSetSwitch is 0") == 0, W) and all
end
-- E8. at other frame rates, a deck shown later, the queue a frame late
for _, c in ipairs({ { 30, 2, false }, { 120, 3, false }, { 60, 2, true } }) do
    local W = world({ S = ON, fps = c[1], late = c[2], W = { swTurns = true, qLate = c[3] } })
    W.press() W.run(0.15) W.press()
    W.till(function() return W.DI.state == "wait" end, 5)
    local m = W.sdMounts[1]
    all = check(string.format("[new] E8: %d frames a second, the deck %d late%s: SET on the coping in switch, the mount at %.1f cm past the edge", c[1], c[2], c[3] and ", the queue a frame late" or "", m and m.past or -99),
        setOnCoping(W) and W.switch == true and m ~= nil and m.sw == 1 and near(m.past, 22.1, 2.5) and W.stepMax < 8 and not W.movedOnBoard, W) and all
end

-- F. THE NATIVE HALF LETS THE BONE GO (a fault, its own watch) 0.9 s in -> the old way at once
do local W = world({ S = ON })
    W.press() W.at(0.9, function() W.sdOn = false end)
    W.till(function() return W.DI.state == "mount" end, 2)
    all = check("[new] F: the bone let go 0.9 s in: given up on that tick, said; the set-down ended, the parts given back, the animation's flag cleared", near(W.t - W.pressT, 0.9, 0.02)
        and W.has("drop-in: the native half let the board bone go -- today's way from here") ~= nil and W.sdEnds == 1 and W.partsTaken == 0 and W.anim == nil and W.DI.th == nil and W.DI.sd == nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] F: ...the mod's own mount stands him over the old spot first (34 cm back: the game's test passes there) and on to SET the old way", setOldSlide(W) and #W.mountCalls == 1 and near(W.mountCalls[1].past, -34, 0.01)
        and W.has("the mod's own mount, try 1") ~= nil and W.ops("mount") == 0, W) and all
end
-- G. ON THE BOARD BUT THE PARTS NOT PUT BACK (the hook failed: -3; the hook was not reached: 0) -> one teleport to the old spot, the slide out
for _, st in ipairs({ -3, 0 }) do
    local W = world({ S = ON, W = { sdPutFails = st } })
    W.press() W.till(function() return W.onb end, 4)
    W.frame(1)
    all = check(string.format("[new] G: on the board, the native half says %d: said; let go of the bone, the parts and the grounded hold; the state \"set\" and ONE teleport to the old spot", st),
        W.DI.state == "set" and W.has(string.format("but the board was NOT put back in the stance (the native half says %d; ExpandedTricks.native.log says why) -- the old spot and the slide out from here", st)) ~= nil
        and W.sdEnds == 1 and W.partsTaken == 0 and W.groundOff == 1 and W.DI.ground == nil and W.teleports == 1 and W.off() < 0.01 and W.DI.th == nil and W.DI.sd == true
        and W.has("drop-in: stood square to the edge, the board's middle 34 cm back from it") ~= nil and W.count("ON THE COPING: no slide") == 0, W) and all
    local t0 = W.t
    W.till(function() return W.DI.state == "wait" end, 3)
    all = check(string.format("[new] G: ...the parts taken 0.3 s on and slid out over the set-down's 0.35 s: SET %.2f s later, the board over the old spot", W.t - t0), W.DI.state == "wait" and W.states["out"] == true
        and near(W.t - t0, 0.3 + 0.35, 0.06) and W.has("7 board parts taken") ~= nil and W.teleports == 1 and near(W.boardPast(), -34, 0.01), W) and all
end
do local W = world({ S = ON, W = { sdPutFails = -3, qLate = true } })   -- ...and that teleport, queued, is not made once the drop-in is over
    W.press() W.till(function() return W.onb end, 4)              -- (the tick that sees him on the board queues it; the queue is a frame late)
    local queued = W.DI.state == "set" and W.teleports == 0
    W.NATIVE.forgetDrop()
    W.frame(2)
    all = check("[new] G3: the last-resort teleport still in the queue when the level changes: it is not made (the queue can run late)", queued and W.DI.state == nil and W.teleports == 0
        and W.count("stood square to the edge") == 0, W) and all
end
-- H. THE MOUNT REFUSED by the native half at the animation's own moment
do local W = world({ S = ON, W = { sdMountRefused = true } })
    W.press() W.till(function() return #W.sdMounts == 1 end, 3)
    W.frame(1)
    all = check("[new] H: the mount refused by the native half: given up the next tick, said twice over; the set-down ended, the parts given back", W.DI.state == "mount" and W.has("the mount at the animation's own moment: refused by the native half") ~= nil
        and W.has("the mount could not be asked for at the animation's own moment -- today's way from here") ~= nil and W.sdEnds == 1 and W.partsTaken == 0 and W.pendAsks == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] H: ...the mod's own mount from the old spot, SET", setOldSlide(W) and #W.mountCalls == 1 and near(W.mountCalls[1].past, -34, 0.01), W) and all
end
-- I. NOT MOUNTED 0.8 s AFTER THE ASKING (the game lets the request go)
do local W = world({ S = ON, W = { ignoreMount = true } })
    W.press() W.till(function() return W.pendAsks == 1 end, 3)
    local askAt = W.t
    all = check("[new] I: the asking raised the grounded hold and the gate", W.ground == true and W.sdGate ~= nil and W.DI.ground == true, W) and all
    W.till(function() return W.DI.state == "mount" end, 2)
    all = check(string.format("[new] I: not on the board 0.8 s after the mount was asked (%.2f): given up; the set-down ended (its gate down), the parts and the grounded hold given back", W.t - askAt), near(W.t - askAt, 0.8, 0.04)
        and W.has("not on the board 0.8 s after the mount was asked -- today's way from here") ~= nil and W.sdEnds == 1 and W.sdGate == nil and W.partsTaken == 0 and W.groundOff == 1 and W.DI.ground == nil and W.DI.th == nil, W) and all
    W.ignoreMount = false
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] I: ...the mod's own mount gets him on from the old spot, SET", setOldSlide(W) and W.pendAsks == 2 and #W.mountCalls == 1 and near(W.mountCalls[1].past, -34, 0.01), W) and all
end
-- J. A BAIL, A LEVEL CHANGE, THE GAME'S REPLAY while the board is held on the coping
do local W = world({ S = ON })
    W.press() W.at(1.0, function() W.mode = MODE_BAILING end)
    W.till(function() return W.DI.state == nil end, 2)
    all = check("[new] J: a bail a second in: let go -- the set-down ended, the parts given back, the animation's flag ended, the toggle guard shut, the marks cleared", near(W.t - W.pressT, 1.0, 0.02)
        and W.has("drop-in: the game bailed you") ~= nil and W.sdEnds == 1 and not W.sdOn and W.partsTaken == 0 and W.anim == nil and W.sent("throwanim", 0) == 1 and W.sent("notoggle", 0) == 1
        and W.DI.th == nil and W.DI.sd == nil, W) and all
    local moves, n = W.moves, #W.sd
    W.run(0.5)
    all = check("J: ...and nothing more is done to him or asked of the native half", W.moves == moves and #W.sd == n and W.pendAsks == 0, W) and all
end
do local W = world({ S = ON })
    W.press() W.run(0.7) W.NATIVE.forgetDrop()
    all = check("[new] J2: the level changes 0.7 s in: let go, the set-down ended, the parts given back", W.DI.state == nil and W.DI.th == nil and W.sdEnds == 1 and W.partsTaken == 0 and W.anim == nil
        and W.has("drop-in: the level changed") ~= nil, W) and all
    local n, mv0 = #W.sd, W.moves
    W.run(0.3)
    all = check("J2: ...and no call more", #W.sd == n and W.moves == mv0, W) and all
end
do local W = world({ S = ON })
    W.press() W.at(0.6, function() W.mode = 6 end)
    W.till(function() return W.DI.state == nil end, 2)
    all = check("[new] J3: the game's replay opened 0.6 s in: let go, the set-down ended", W.DI.state == nil and W.sdEnds == 1 and W.partsTaken == 0 and W.has("the game's replay was opened while the board was being set down") ~= nil, W) and all end
do local W = world({ S = ON })                                    -- a bail between the asking and the mount: the grounded hold is given back
    W.press() W.till(function() return W.pendAsks == 1 end, 3)
    W.pending = false W.mode = MODE_BAILING W.frame(1)
    all = check("[new] J4: a bail right after the mount was asked: let go, the gate down, the grounded hold given back", W.DI.state == nil and W.sdEnds == 1 and W.sdGate == nil and W.groundOff == 1 and W.DI.ground == nil, W) and all end

-- K. THE WALK OUT PAST THE EDGE, MEASURED: the engine's walking lowers a capsule that hangs on the edge (radius 34)
do local W = world({ S = ON, capR = 34 })
    local pastSeen, pastHeld, sinkEarly, T0, heldLast = -99, -99, 0, nil, false
    W.watch = function()
        local T = W.DI.th
        if T then T0 = T end
        if T and T.mountAt and not W.onb and W.t < T.mountAt - 0.15 then
            if heldLast then pastHeld = math.max(pastHeld, W.past()) else pastSeen = math.max(pastSeen, W.past()) end   -- (a tick's move shows on the next)
            sinkEarly = math.max(sinkEarly, W.stand - W.act.z)
            heldLast = T.alHold ~= nil
        end
    end
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    local hold = T0 and T0.alHold
    all = check(string.format("[new] K: the game had him lower as his middle went out past the edge: seen over 1.5 cm (his middle %.1f cm past it by then), said once, and he is held 3 cm short of there (%s cm past the edge)", pastSeen, tostring(hold and string.format("%.1f", hold))),
        hold ~= nil and hold > 4 and hold < 12 and near(pastSeen - hold, 3, 0.01) and W.count("(the capsule hangs on the edge) -- held ") == 1 and W.has("the game had you 1.") ~= nil, W) and all
    all = check(string.format("[new] K: ...until 0.15 s before the mount: from then on his middle was at most %.2f cm past the edge, and the game never had him over %.1f cm low until then (22 cm out it would be 8.1); he did not fall", pastHeld, sinkEarly),
        hold ~= nil and pastHeld <= hold + 0.01 and pastHeld > hold - 0.5 and sinkEarly < 2.5 and sinkEarly > 1.5 and not W.fell, W) and all
    local m = W.sdMounts[1]
    all = check(string.format("[new] K: in the last 0.15 s the walk closes what it can (his middle %.1f cm past the edge at the asking), the game's mount takes the rest: SET on the coping, and the line has the hold and the most he was lowered", m and m.past or -99),
        setOnCoping(W) and m ~= nil and hold ~= nil and m.past > hold + 5 and m.past < 22.5 and W.has(string.format("(held %.0f cm past the edge)", hold)) ~= nil and W.count("the game had you at most 0.0 cm lower") == 0, W) and all
end
do local W = world({ S = with({ DropInSetOver = 0 }), capR = 34 })
    local pastEarly, sinkEarly = -99, 0
    W.watch = function()
        local T = W.DI.th
        if T and T.mountAt and not W.onb and W.t < T.mountAt - 0.15 then pastEarly, sinkEarly = math.max(pastEarly, W.past()), math.max(sinkEarly, W.stand - W.act.z) end
    end
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("[new] K2: DropInSetOver 0: his middle stays on the ledge until 0.15 s before the mount (at most %.2f cm past the edge, the game never lowers him until then: %.2f), then SET on the coping; nothing is said of a hold in those last frames", pastEarly, sinkEarly),
        setOnCoping(W) and pastEarly <= -0.99 and pastEarly > -1.5 and sinkEarly == 0 and W.count("the capsule hangs on the edge") == 0, W) and all
end
do local W = world({ S = ON, slope = 0.12 })                      -- the ledge's top falls 0.12 cm a cm toward the edge: he is 1.5 cm lower at the edge's spot than where he pressed
    local T0
    W.watch = function() if W.DI.th then T0 = W.DI.th end end
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("[new] K3: a top that is not level is not the edge: no hold (what the game makes of his height is counted from what it read while he stood well on the ledge: %.1f cm), SET on the coping", T0 and T0.sink0 or -1),
        setOnCoping(W) and T0 ~= nil and T0.alHold == nil and T0.sink0 ~= nil and T0.sink0 > 1.2 and W.count("the capsule hangs on the edge") == 0, W) and all
    -- ...from the walk's FIRST frame: the 1.5 cm the top itself is lower at his spot is not "the game had you lower" (the next round reads the capsule's radius off these numbers)
    all = check(string.format("[new] K3: ...counted from the walk's first frame on: 'the game had you at most' reads %.2f cm (the top's own 1.5 cm at his spot is not in it; the last 0.6 past the count's end are)", T0 and T0.sink or -1),
        T0 ~= nil and T0.sink ~= nil and T0.sink < 1.0 and W.has("the game had you at most 0.") ~= nil, W) and all
end
-- K4. (build 216) DropInSetFly: on foot his middle stays 2 cm short of the edge; the last 0.15 s are flown, at his own height
do local W = world({ S = with({ DropInSetFly = 1 }), capR = 34 })
    local pastEarly, sinkFoot, T0, askedAt = -99, 0, nil, nil
    W.watch = function()
        local T = W.DI.th
        if T then T0 = T end
        if T and T.mountAt and not W.onb then
            if not T.asked then sinkFoot = math.max(sinkFoot, W.stand - W.act.z) elseif not askedAt then askedAt = W.t end
            if W.t < T.mountAt - 0.15 then pastEarly = math.max(pastEarly, W.past()) end
        end
    end
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    local m, f = W.sdMounts[1], W.mvModes
    all = check(string.format("[216] K4: DropInSetFly 1: until 0.15 s before the mount his middle is at most %.2f cm past the edge (2 short of it), and nothing is said of a hold", pastEarly),
        pastEarly <= -1.99 and pastEarly > -2.6 and W.count("the capsule hangs on the edge") == 0 and T0 ~= nil and T0.alHold == nil, W) and all
    all = check(string.format("[216] K4: ...the last 0.15 s in the engine's flying mode (asked %d time(s), %.2f s before the mount), said once; the game never had him lower before the asking (%.2f cm) and he did not fall",
            #f > 0 and 1 or 0, (f[1] and T0) and (T0.mountAt - f[1].t) or -1, sinkFoot),
        #f == 2 and f[1].m == 5 and T0 ~= nil and near(T0.mountAt - f[1].t, 0.15, 0.04) and sinkFoot < 0.05 and not W.fell and W.count("over the edge in the engine's flying mode for the last steps to the mount") == 1, W) and all
    all = check(string.format("[216] K4: ...walking again in the slice that asks the mount (his middle %.1f cm past the edge by then), SET on the coping, nothing left flying", m and m.past or -99),
        setOnCoping(W) and m ~= nil and #f == 2 and f[2].m == 1 and f[2].t <= m.t + 1e-9 and m.past > 12 and m.past < 26 and W.mv.MovementMode == 1 and W.DI.flyT == nil, W) and all
end
do local W = world({ S = with({ DropInSetFly = 1 }), capR = 34 })   -- a bail while he is flown over the edge: the engine's falling takes him
    W.press() W.till(function() return #W.mvModes == 1 end, 3)
    local flown = #W.mvModes == 1 and W.mvModes[1].m == 5
    W.mode = MODE_BAILING W.frame(2)
    all = check("[216] K5: a bail in those last steps: the set-down ends, and the flying mode is handed to the engine's falling (said once)",
        flown and W.DI.state == nil and W.mv.MovementMode == 3 and W.DI.flyT == nil and W.count("the set-down ended while you were held over the edge") == 1, W) and all
end
do local W = world({ S = with({ DropInSetFly = 0 }), capR = 34 })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[216] K6: DropInSetFly 0: build 215's rule -- the flying mode is never asked for, the hold is said when the game is seen to lower him",
        setOnCoping(W) and #W.mvModes == 0 and W.count("(the capsule hangs on the edge) -- held ") == 1, W) and all
end
-- L. A PRESS MADE HANGING ON THE EDGE: his middle 16 cm past it, the capsule 4 cm lower than a man on the ledge
do local W = world({ S = ON, capR = 34, dist = -16 })
    all = check("L: (the world) he hangs 4.0 cm low before the press", near(W.stand - W.act.z, 4.0, 0.05), W) and all
    W.press()
    all = check("[new] L: pressed hanging on the edge (the look says -16 cm): on the coping, stood at the ledge's own height, said under the DROP-IN line", W.DI.th ~= nil and W.DI.th.edge == true and near(W.DI.th.z0, W.stand, 0.001)
        and W.has("DROP-IN: an edge -16 cm from you") ~= nil and W.has("drop-in:    you stood 4.0 cm lower than a man stands at this edge (hanging on it, or the top rises to it) -- the set-down stands you at the height of the ledge's top by the edge") ~= nil, W) and all
    all = check("[new] L: ...and the line under the DROP-IN line says in words that his middle is 16 cm PAST the edge", W.count("drop-in:    your middle is 16 cm PAST that edge (you stand out over it): the native half looked from the ledge behind you") == 1
        and W.has("your middle is 16 cm PAST that edge") == W.has("DROP-IN: an edge -16 cm from you") + 1, W) and all
    W.frame(2)
    all = check("[new] L: ...the first move is made at that height, not 4 cm into the ledge", W.zFirst ~= nil and near(W.zFirst, W.stand, 0.001), W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] L: ...and on to SET on the coping (he is moved back to 8 cm behind the edge first)", setOnCoping(W) and W.has("to stand 8 cm from the edge") ~= nil, W) and all
end
do local W = world({ S = ON, dist = 10 })
    W.press()
    all = check("L2: pressed standing on the ledge: his height is left as it is, nothing said about hanging nor about his middle past the edge", W.DI.th ~= nil and W.DI.th.z0 == W.stand and W.DI.th.zp == nil
        and W.count("lower than a man stands at this edge") == 0 and W.count("PAST that edge") == 0, W) and all end
-- L3. THE PRESS OF 10 OCT 11:22:05 (the verdict's correction 12): his middle 10 cm past a coping. The capsule hangs 1.5 cm low
-- there with a radius of 34 and 2.7 with one of 20 -- under the 3 cm the rule first had
for _, c in ipairs({ { 34, 1.5 }, { 20, 2.7 } }) do
    local W = world({ S = ON, capR = c[1], dist = -10 })
    local hung = W.stand - W.act.z
    W.press()
    all = check(string.format("[new] L3: pressed 10 cm past the edge with a capsule of radius %d (he hangs %.2f cm low): on the coping, stood at the ledge's own height (from 1 cm low), said; the height he was pressed at is kept", c[1], hung),
        near(hung, c[2], 0.06) and W.DI.th ~= nil and W.DI.th.edge == true and near(W.DI.th.z0, W.stand, 0.001) and near(W.DI.th.zp, W.stand - hung, 0.001)
        and W.has(string.format("drop-in:    you stood %.1f cm lower than a man stands at this edge", hung)) ~= nil and W.has("your middle is 10 cm PAST that edge") ~= nil, W) and all
    W.frame(2)
    all = check("[new] L3: ...the first move is made at the ledge's height", W.zFirst ~= nil and near(W.zFirst, W.stand, 0.001), W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] L3: ...and on to SET on the coping (moved back 18 cm and 16 across to stand 8 cm behind the edge)", setOnCoping(W) and W.has("moved 24 cm") ~= nil and W.has("to stand 8 cm from the edge") ~= nil, W) and all
end
-- ...and a man who STANDS on the ledge is not caught by the 1 cm: the game's walking keeps 1.9 to 2.4 cm under a capsule (2.15 here)
for _, c in ipairs({ { 0.25, false }, { -0.25, false }, { 0.9, false }, { 1.1, true } }) do
    local W = world({ S = ON, dist = 10 })
    W.act.z = W.stand - c[1]
    W.press()
    local T = W.DI.th
    all = check(string.format("%sL3: pressed on the ledge %.2f cm %s than the 2.15 cm the look reckons with: %s", c[2] and "[new] " or "", math.abs(c[1]), c[1] > 0 and "lower" or "higher", c[2] and "stood at the ledge's height" or "left as he is"),
        T ~= nil and ((c[2] and T.edge == true and near(T.z0, W.stand, 0.001) and W.count("lower than a man stands at this edge") == 1)
            or (not c[2] and near(T.z0, W.stand - c[1], 0.001) and T.zp == nil and W.count("lower than a man stands at this edge") == 0)), W) and all
end
-- L4. PRESSED ON THE LEDGE, LOWER THAN ITS EDGE (a top that rises to its edge over his 20 cm): the coping variant stands him
-- at the edge's height -- and where it is given up before the animation, build 211's spot 70 cm back gets the height he
-- was pressed at again (the floor there is as low as where he pressed). 4 cm for the two give-ups: more than the 3 the
-- rule first had, so that they look at the giving back and not at the 1 cm
do local W = world({ S = ON, low = 2, dist = 20 })
    all = check("L4: (the world) he stands 2.0 cm lower than a man at the edge before the press", near(W.stand - W.act.z, 2.0, 0.001), W) and all
    W.press()
    all = check("[new] L4: pressed 20 cm from an edge the top rises 2 cm to: on the coping, stood at the edge's height, said; nothing about his middle past the edge", W.DI.th ~= nil and W.DI.th.edge == true and near(W.DI.th.z0, W.stand, 0.001)
        and near(W.DI.th.zp, W.stand - 2, 0.001) and W.has("drop-in:    you stood 2.0 cm lower than a man stands at this edge") ~= nil and W.count("PAST that edge") == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] L4: ...and on to SET on the coping, every move on foot made at the edge's height", setOnCoping(W) and near(W.zMin, W.stand, 0.001) and near(W.zMax, W.stand, 0.001), W) and all
end
do local W = world({ S = ON, low = 4, dist = 20, W = { armRefuses = true } })
    W.press() W.frame(2)
    -- (not [new]: build 211 itself moves him at the height he was pressed at -- this is the coping variant not undoing that)
    all = check("L4: a top that rises 4 cm, the arming refused: build 211's set-down, moved at the height he was pressed at from the first move on (as build 211 moves him)", W.DI.th ~= nil and W.DI.th.edge == nil
        and near(W.DI.th.z0, W.stand - 4, 0.001) and W.DI.th.zp == nil and W.zFirst ~= nil and near(W.zFirst, W.stand - 4, 0.001), W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("L4: ...to its end, never moved at another height on foot", setOldSlide(W) and near(W.zMin, W.stand - 4, 0.001) and near(W.zMax, W.stand - 4, 0.001), W) and all
end
do local W = world({ S = with({ DropInSetSwitch = 0 }), low = 4, dist = 20, W = { swTurns = true } })   -- (build 223: with the switch set-down's fallback)
    W.press() W.run(0.15)
    local zBefore = W.zLastSet
    W.press() W.frame(2)
    all = check("[new] L4: a top that rises 4 cm, a second tap (SWITCH) 0.15 s on: moved at the edge's height until the tap, at the height he was pressed at from it on", near(zBefore, W.stand, 0.001) and W.DI.th ~= nil and W.DI.th.edge == nil
        and near(W.DI.th.z0, W.stand - 4, 0.001) and W.DI.th.zp == nil and near(W.zLastSet, W.stand - 4, 0.001), W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("L4: ...and build 211's set-down to its end in SWITCH", setOldSlide(W) and W.mountCalls[1] ~= nil and W.mountCalls[1].sw == 1, W) and all
end
-- L4b. (build 223) ...and with DropInSetSwitch 1 the switch tap keeps the coping: every move on foot at the edge's height
do local W = world({ S = ON, low = 4, dist = 20, W = { swTurns = true } })
    W.press() W.run(0.15) W.press()
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] L4b: a top that rises 4 cm, a second tap (SWITCH) 0.15 s on: the coping kept, every move on foot at the edge's height, SET on the coping in switch",
        setOnCoping(W) and W.switch == true and near(W.zMin, W.stand, 0.001) and near(W.zMax, W.stand, 0.001), W) and all
end
-- L5. ...but a press made HANGING on the edge keeps the ledge's height when the coping is given up: where he hung is no floor's height
do local W = world({ S = ON, capR = 34, dist = -16, W = { armRefuses = true } })
    W.press() W.frame(2)
    all = check("[new] L5: pressed hanging 16 cm past the edge, the arming refused: build 211's set-down, moved at the ledge's own height (not 4 cm into it)", W.DI.th ~= nil and W.DI.th.edge == nil
        and near(W.DI.th.z0, W.stand, 0.001) and W.zFirst ~= nil and near(W.zFirst, W.stand, 0.001), W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("L5: ...to its end (he is moved 86 cm back to stand 70 cm from the edge)", setOldSlide(W) and W.has("to stand 70 cm from the edge") ~= nil, W) and all
end
-- L6. THE MENU'S ROW OFF (DropInSetEdge 0) AND A PRESS MADE PAST THE EDGE: native v114 finds the edge, build 211's set-down
-- takes the press -- and it too stands him at the ledge's height (it moves him 86 cm back over the ledge)
do local W = world({ S = with({ DropInSetEdge = 0 }), capR = 34, dist = -16 })
    W.press()
    all = check("[new] L6: DropInSetEdge 0, pressed hanging 16 cm past the edge (4 cm low): build 211's set-down, stood at the ledge's own height, said under the DROP-IN line with his middle past the edge", W.DI.th ~= nil and W.DI.th.edge == nil
        and near(W.DI.th.z0, W.stand, 0.001) and W.has("-- a SET-DOWN (DropInSetDown): the game's own throw is refused") ~= nil and W.has("your middle is 16 cm PAST that edge") ~= nil
        and W.has("drop-in:    you stood 4.0 cm lower than a man stands at this edge") ~= nil, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] L6: ...to its end, every move on foot made at the ledge's height; the native half's set-down never asked", setOldSlide(W) and #W.sd == 0 and near(W.zMin, W.stand, 0.001) and near(W.zMax, W.stand, 0.001), W) and all
end
do local W = world({ S = with({ DropInSetEdge = 0 }), low = 4, dist = 20 })
    W.press()
    all = check("L6: DropInSetEdge 0, pressed ON the ledge 4 cm lower than its edge: build 211's set-down at the height he was pressed at, nothing said (as build 211)", W.DI.th ~= nil and W.DI.th.edge == nil
        and near(W.DI.th.z0, W.stand - 4, 0.001) and W.DI.th.zp == nil and W.count("lower than a man stands at this edge") == 0, W) and all
end

-- M. THE FRAMES AFTER THE MOUNT: "air" for four frames (the board in its own mode 7), then riding
do local W = world({ S = ON, W = { modeSeq = { MODE_AIR, MODE_AIR, MODE_AIR, MODE_AIR } } })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    W.run(0.3)
    all = check("[new] M: \"air\" in the four frames after a mount on the coping: the board is not drawn back (the hang stays 4.0), nothing said of airborne; held on", W.DI.state == "wait" and W.DI.hang == 4 and not W.DI.pulled
        and W.count("drawing it back") == 0 and W.has("held (wait, 100% into the stance, tipped 0 deg): the game's mode 2 -> 1") ~= nil and W.partsTaken == 7, W) and all
    W.run(0.3) W.mode = MODE_AIR W.frame(4)
    all = check("M: ...half a second on the old rule holds again: \"air\" draws the board back a quarter cm a frame", W.DI.hang == 3 and W.DI.pulled == true and W.count("drawing it back") == 1, W) and all
end
-- M2. ...or the mode still reads "on foot" (0) for two frames while the game says he is on the board
do local W = world({ S = ON, W = { modeSeq = { 0, 0 } } })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    W.run(0.2)
    all = check("[new] M2: \"on foot\" read for two frames after a mount on the coping while he is ON the board: not a step-off -- the board is not given back, no re-mount", W.DI.state == "wait" and W.DI.remounts == 0 and W.partsTaken == 7
        and W.count("the game stepped you off") == 0 and W.count("you are off the board") == 0 and W.states["mount"] == nil, W) and all
    -- a real step-off right after (he is NOT on the board any more): build 210's re-mount, as ever
    W.notogUntil = 0 W.onb, W.mode, W.bmode = false, 0, 5
    W.frame(1)
    all = check("M2: ...a real step-off 0.2 s after the mount (no Y in the last second): put back on, try 1 of 2; the parts and the hold given back first", W.DI.state == "mount" and W.DI.remounts == 1 and W.partsTaken == 0
        and W.groundOff == 1 and W.has("the game stepped you off the board (while it stood ready") ~= nil, W) and all
    W.till(function() return W.DI.state == "out" end, 4)
    local outAt = W.t
    W.till(function() return W.DI.state == "wait" end, 3)
    all = check(string.format("[new] M2: ...the mod's own mount from the old spot, and the slide out is the set-down's 0.35 s (%.2f); the native half's set-down was armed once only", W.t - outAt), W.DI.state == "wait"
        and W.has("the mod's own mount, try 1") ~= nil and near(W.t - outAt, 0.35, 0.04) and W.sdArms == 1 and #W.animAsks == 1 and not W.bailedByTest, W) and all
    W.pending = true W.frame(2)
    all = check("M2: a board toggle while it stands ready is dropped (the guard is kept open)", W.dropped == 1 and W.onb and W.DI.state == "wait", W) and all
end
-- N. Y MASHED during the animation: too late for SWITCH, said once; the coping variant goes on regular
do local W = world({ S = ON })
    W.press() W.run(0.35) W.press() W.run(0.1) W.press()
    all = check("[new] N: Y again 0.35 s on: too late for switch, said once, the coping variant kept", W.DI.sw == nil and W.count("too late for SWITCH in a set-down") == 1 and W.DI.th ~= nil and W.DI.th.edge == true and W.sdEnds == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] N: ...SET on the coping, regular; the game threw nothing", setOnCoping(W) and W.sdMounts[1].sw == 0 and W.threw == 0, W) and all
    W.run(0.1) W.press()                                          -- ...and a press once it stands ready opens no SWITCH window
    all = check("N: a Y press once it stands ready is not \"the second tap\"", W.DI.sw == nil and W.count("you will be put on in SWITCH") == 0, W) and all
end
-- O. DropInSetRise 1 (ini only): the lift toward the board's height before the mount, by moving him
do local W = world({ S = with({ DropInSetRise = 1 }) })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("[new] O: DropInSetRise 1: he is moved up to %.1f cm higher before the mount (the stance is 8.4 over the level board), and the asking's line says so", (W.zMax or 0) - W.stand),
        setOnCoping(W) and near((W.zMax or 0) - W.stand, 8.4, 0.05) and W.zMin == W.stand and W.has("raised 8.4 cm") ~= nil and W.has("at the mount you will come up about 1 cm") ~= nil, W) and all
end
-- O2. ...and where the game takes that lift back (a floor under him: the engine's walking sets the capsule onto it every tick)
-- that is not "the capsule hangs on the edge". DropInSetOver 0 keeps his middle on the ledge the while
do local W = world({ S = with({ DropInSetRise = 1, DropInSetOver = 0 }), capR = 34 })
    local T0
    W.watch = function() if W.DI.th then T0 = W.DI.th end end
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("[new] O2: DropInSetRise 1 with a floor under him (DropInSetOver 0): the lift the game takes back every tick is not read as hanging on the edge -- no hold (%s), nothing said of one, SET on the coping", tostring(T0 and T0.alHold)),
        setOnCoping(W) and T0 ~= nil and T0.alHold == nil and W.count("the capsule hangs on the edge") == 0 and W.has("raised 8.4 cm") ~= nil, W) and all
end
-- P. THE GAME THREAD'S QUEUE RUN A FRAME LATE
do local W = world({ S = ON, W = { qLate = true } })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] P: the queue a frame late: SET on the coping all the same; he is never moved by the on-foot call once on the board, the mount is asked once", setOnCoping(W) and not W.movedOnBoard and W.pendAsks == 1
        and #W.sdMounts == 1 and W.teleports == 0, W) and all
    W.run(0.5)
    all = check("P: ...and held on", W.DI.state == "wait" and not W.movedOnBoard and W.partsTaken == 7, W) and all
end
-- R. NO POSE FROM THE NATIVE HALF ("wait" for ever), and THE ANIMATION NOT PLAYING (the bone stays in the hand)
do local W = world({ S = ON, W = { noPose = true } })
    W.press() W.till(function() return W.DI.state == "mount" end, 3)
    all = check("[new] R: the native half has no pose to read: given up 0.9 s after the animation was asked, said; the set-down ended", near(W.t - W.pressT, 0.25 + 0.9, 0.03)
        and W.has("the board did not come down in 0.9 s (the animation did not play: its board bone reads ? cm over your floor) -- today's way from here") ~= nil and W.sdEnds == 1 and W.partsTaken == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] R: ...the mod's own mount from the old spot, SET", setOldSlide(W) and near(W.mountCalls[1].past, -34, 0.01), W) and all
end
do local W = world({ S = ON, W = { animPlays = false } })
    W.press() W.till(function() return W.DI.state == "mount" end, 3)
    all = check("[new] R2: the animation's flag is set but nothing plays: given up after 0.9 s with what the bone read; the bone was never given a weight", near(W.t - W.pressT, 0.25 + 0.9, 0.03)
        and W.has("its board bone reads 71 cm over your floor) -- today's way from here") ~= nil and (W.pinWmax or 0) == 0 and W.sdEnds == 1, W) and all
end
do local W = world({ S = ON })                                    -- the native half has no pose for three frames in the middle of the walk
    W.press() W.at(1.1, function() W.noPose = true end) W.at(1.15, function() W.noPose = nil end)
    local stepAtGap, was
    W.watch = function() if W.noPose and not stepAtGap and was ~= nil then stepAtGap = true W.stepAtGap = 0 end was = W.noPose
        if W.noPose and W.stepLast then W.stepAtGap = math.max(W.stepAtGap or 0, W.stepLast) end end
    W.till(function() return W.DI.state == "wait" end, 5)
    all = check(string.format("[new] R3: no pose to read for three frames 1.1 s in (he has walked 25 cm by then): he stays where the walk has him (%.1f cm moved a frame at most in those frames, %.1f at most in all) and it goes on to SET on the coping",
        W.stepAtGap or -1, W.stepMax), setOnCoping(W) and W.stepAtGap ~= nil and W.stepAtGap < 3.5 and W.stepMax < 6, W) and all
end
-- S. THE REAL BOARD DOES NOT FOLLOW THE HELD BONE (what is not shown: the game following an overridden bone on foot)
do local W = world({ S = ON, W = { noFollow = true } })
    W.press() W.till(function() return W.DI.state == "wait" end, 5)
    all = check("[new] S: the real deck does not follow the held bone: nothing breaks -- the mount is where the pin is all the same -- and the log has how far off it was",
        setOnCoping(W) and W.has("the real deck 2") ~= nil and W.count("the held deck was at most 0.0 cm from its place") == 0, W) and all
end
-- T. BUILD 210's re-mount after a SET on the coping that has stood a while
do local W = world({ S = ON })
    W.press() W.till(function() return W.DI.state == "wait" end, 5) W.run(0.8)
    W.notogUntil = 0 W.onb, W.mode, W.bmode = false, 0, 5
    W.frame(1)
    all = check("T: stepped off by the game 0.8 s after a SET on the coping: put back on (try 1 of 2)", W.DI.state == "mount" and W.DI.remounts == 1 and W.partsTaken == 0, W) and all
    W.till(function() return W.DI.state == "wait" end, 6)
    all = check("[new] T: ...the mod's own mount and the slide out: SET again; nothing more asked of the native half's set-down", W.DI.state == "wait" and W.onb and W.states["out"] == true and W.sdArms == 1 and #W.sdMounts == 1 and W.sdEnds == 0, W) and all
end

local o = assert(io.open("sd212_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("build 212's set-down test failed: see sd212_out.txt", 0) end

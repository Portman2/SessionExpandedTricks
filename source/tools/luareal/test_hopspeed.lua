-- test_hopspeed.lua (build 211, adapted from v128/hopspeed/test_hopspeed.lua to the merged hop): the board hop (its
-- click, its arc, its mount, the speed the board gets, the watch and the facing check that shares it, the loop's guard),
-- cut out of main.lua and run in real Lua against a stand-in for the game.
--   luareal -run test_hopspeed.lua result.txt main.lua   (writes hoptest_out.txt into the working directory)
-- The stand-in's mount is the game's as read from the exe (finding_hop180): a switch mount turns the capsule half a
-- turn, then the board is turned to the capsule, half a turn more when switch ~= the flip flag. It is a model, not the game.
-- (build 212, mk_test212_hop.pl) main.lua's BD is stood in for (no deck held: the parts are looked up at every kick),
-- and the speed is given ONCE: no second kick 60 ms on (checks A, C, F2). The six settings of build 212 are not in
-- S below -- unset = off, the hop as build 211 flew it; test_hop212.lua runs what the file ships.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("    local HOP = { on = false, rideZ = nil", 1, true), "the hop's start was not found")
local b = assert(src:find("\nend\n\n-- THE DROP-IN (v98)", a, true), "the hop's end was not found")
local body = src:sub(a, b)
assert(body:find("LoopAsync(10, function()", 1, true), "the hop's loop is not in the slice")
-- the defaults the file ships
local function default(k) return tonumber(src:match("\n    " .. k .. "%s*=%s*([%-%d%.]+),")) end
local DEF = { scale = default("BoardHopSpeedScale"), across = default("BoardHopSpeedAcross"), fix = default("BoardHopSwitchFix") }

local function wrap(x) return x - 360 * math.floor(x / 360 + 0.5) end
local function world(o)
    local W = { kicks = {}, logs = {}, logT = {}, moves = {}, vel = { X = 0, Y = 0, Z = 0 }, mesh = -1, t = 100,
                loc = { X = 0, Y = 0, Z = 100 }, yaw = 0, deck = { x = 150, y = 0, z = 10, yaw = 0 }, dv = { 0, 0 },
                onboard = false, pending = false, mounts = true, ragdollPuts = 0, go = 0, goCalls = 0, speedFn = nil, mode = 0, partsHeld = 0, foot = 0, dof = 0 }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.HJN_BoardState = function() return (W.onboard and 4 or 1) | (8 << 4) end
    env.HJN_DeckWorld = function() return string.format("%.2f %.2f %.2f %.2f 1.000", W.deck.x, W.deck.y, W.deck.z, W.deck.yaw) end
    env.HJN_DeckAxes = function() if W.noAxes then return "" end local r = math.rad(W.deck.yaw) local c = math.cos(math.rad(W.slope or 0))
        return string.format("%.4f %.4f %.4f 0 0 1", math.cos(r) * c, math.sin(r) * c, math.sin(math.rad(W.slope or 0))) end
    env.HJN_BoardMount = function(sw, flip) if W.refuse then return 0 end W.msw, W.mflip = sw, flip return 1 end
    env.HJN_BoardRagdoll = function() W.ragdollPuts = W.ragdollPuts + 1 return 1 end
    env.HJN_BoardParts = function(...) if select("#", ...) > 0 then W.partsHeld = W.partsHeld + 1 return select("#", ...) end W.partsHeld = W.partsHeld - 1 return 0 end
    env.HJN_BoardKick = function(x, y, z, spin, ox, oy)
        W.kicks[#W.kicks + 1] = { x, y, z, spin, ox, oy, t = W.t } W.given = math.sqrt(x * x + y * y) W.kdir = { x / math.max(1e-6, W.given), y / math.max(1e-6, W.given) } return 7 end
    env.HJN_MeshSpeed = function() return W.mesh end
    env.HJN_CtrlYaw = function() return string.format("%.1f %d 0", 0, W.dof) end
    env.HJN_Set = function(k, v) if k == "boardgo" then W.goCalls = W.goCalls + 1 return W.go end return 1 end
    env.LoopAsync = function(ms, fn) W.loopMs, W.loop = ms, fn end
    env.BD = { comp = nil }                              -- (build 212) main.lua's own BD, as the hop's block reads it
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    local S = { BoardHop = 1, BoardHopRange = 250, BoardHopTime = 0.45, BoardHopHeight = 40, BoardHopRideZ = 95,
                BoardHopSpeedScale = W.scale or 1.0, BoardHopSpeedAcross = W.across or 0.5, BoardHopSwitchFix = W.fix or 1 }
    local q = function(fn, d) local ok, r = pcall(fn) if ok then return r end return d end
    local s0 = {
        K2_GetActorLocation = function() return W.loc end,
        K2_GetActorRotation = function() return { Pitch = 0, Yaw = W.yaw, Roll = 0 } end,
        K2_SetActorLocationAndRotation = function(_, p, r) W.moves[#W.moves + 1] = { p.X, p.Y, p.Z, r.Yaw, t = W.t } W.loc = { X = p.X, Y = p.Y, Z = p.Z } W.yaw = r.Yaw end,
        IsOnBoard = function() return W.onboard end,
        SetPendingApplyToggleOnBoard = function() W.pending = true end,
        GetCurrentFootPosition = function() return W.foot end,
        IsSkatingSwitch = function() return W.foot == 4 or W.foot == 2 end,
    }
    local mv = setmetatable({ GetCurrentSpeed = function() if W.speedFn then return W.speedFn(W) end return W.given or 0 end,
                              SetMovementMode = function(_, m) W.mvmode = m end },
        { __index = function(_, k) if k == "Velocity" then return W.vel end end, __newindex = function(_, k, v) if k == "Velocity" then W.velWrites = (W.velWrites or 0) + 1 else error("unexpected write: " .. tostring(k)) end end })
    local NATIVE = { live = true, boardParts = function() return { 1, 2, 3, 4, 5, 6, 7 } end,
                     dropBusy = function() if W.dropFails then error("the drop-in's stand-in was told to fail") end return W.drop end,
                     gt = function(fn) fn() end }                 -- (the game thread's queue: run at once)
    local chunk = "local S, q, s0, mv, log, modeNow, MODE_RIDING, MODE_BAILING, NATIVE, alive, refs, NAT = ...\n" .. body .. "\nreturn NATIVE"
    local fn = assert(load(chunk, "=hop", "t", env))
    local function log(s) W.logs[#W.logs + 1] = s W.logT[#W.logT + 1] = W.t if s:find("board hop: error", 1, true) then W.err = s end end
    W.N = fn(S, q, s0, mv, log, function() return W.mode end, 1, 5, NATIVE, function(x) return x end, function() return true end, { goofy = false })
    W.S = S
    assert(W.loop and W.loopMs == 10, "the hop's loop was not registered")
    -- one frame: the board rolls, a pending mount happens (the game stops the board and turns things its way), the game
    -- relabels the stance by the way you roll, the hop's own loop runs (through its guard)
    W.tick = function(n)
        for _ = 1, (n or 1) do
            W.t = W.t + 0.0125
            if not W.onboard then W.deck.x, W.deck.y = W.deck.x + W.dv[1] * 0.0125, W.deck.y + W.dv[2] * 0.0125 end
            if W.pending then W.pending = false
                if W.mounts then
                    local sw, flip = W.msw == 1, W.mflip == 1
                    if sw then W.yaw = W.yaw + 180 end                                   -- ApplyToggleOnBoard, foot position 4
                    W.deck.yaw = wrap(W.yaw + ((sw ~= flip) and 180 or 0))               -- SnapToGround
                    W.dof = (sw ~= flip) and 180 or 0                                    -- ResetBoard's deck offset
                    W.foot = sw and 4 or 1
                    W.onboard = true W.mode = 1 W.mountT = W.t W.given = 0
                end
            end
            if W.onboard and (W.given or 0) >= 50 and W.kdir then                        -- AdjustFootPositionAndMoveDirection (50 cm/s and up)
                local alongF = (W.kdir[1] * math.cos(math.rad(W.yaw)) + W.kdir[2] * math.sin(math.rad(W.yaw))) > 0
                if alongF then W.foot = (W.foot == 4) and 3 or ((W.foot == 2) and 1 or W.foot)
                else W.foot = (W.foot == 1) and 2 or ((W.foot == 3) and 4 or W.foot) end
            end
            local ok, err = pcall(W.loop)
            if not ok then W.err = "the loop itself raised: " .. tostring(err) end
        end
    end
    W.has = function(piece) for i, l in ipairs(W.logs) do if l:find(piece, 1, true) then return i end end return nil end
    W.count = function(piece) local n = 0 for _, l in ipairs(W.logs) do if l:find(piece, 1, true) then n = n + 1 end end return n end
    -- is the hop's watch over? (a click is only taken when neither a hop nor its watch is running; asked off the board, in range)
    W.free = function()
        local keep = { W.onboard, W.loc, W.deck.x, W.deck.y, W.yaw, W.ragdollPuts, W.msw, W.mflip, W.err }
        W.onboard = false W.loc = { X = W.deck.x - 100, Y = W.deck.y, Z = 100 }
        local n0, m0 = #W.logs, #W.moves
        local took = W.N.hopTry("test") == true
        if took then                                              -- undo: let that hop run out without a mount
            for _ = 1, 120 do W.t = W.t + 0.0125 W.pending = false pcall(W.loop) end
            W.pending = false
        end
        for i = #W.logs, n0 + 1, -1 do W.logs[i] = nil W.logT[i] = nil end
        for i = #W.moves, m0 + 1, -1 do W.moves[i] = nil end
        W.onboard, W.loc, W.deck.x, W.deck.y, W.yaw, W.ragdollPuts, W.msw, W.mflip, W.err = keep[1], keep[2], keep[3], keep[4], keep[5], keep[6], keep[7], keep[8], keep[9]
        return took
    end
    return W
end
local function near(x, y, tol) return math.abs(x - y) < (tol or 0.5) end
local out = {}
local all = true
local nchecks = 0
local function check(name, cond, W)
    nchecks = nchecks + 1
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then all = false
        out[#out + 1] = "       err " .. tostring(W.err)
        for _, l in ipairs(W.logs) do out[#out + 1] = "       log: " .. l end
        for _, k in ipairs(W.kicks) do out[#out + 1] = string.format("       kick: %.1f %.1f %.1f | o %.2f %.2f at +%.0f ms", k[1], k[2], k[3], k[5], k[6], (k.t - (W.mountT or k.t)) * 1000) end
    end
    return cond
end
local function show(W) for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l end end

-- 0. what the file ships
do local W = { logs = {}, kicks = {} }
    check(string.format("defaults: BoardHopSpeedScale %s (1.2 = 'a little speed boost'), BoardHopSpeedAcross %s, BoardHopSwitchFix %s", tostring(DEF.scale), tostring(DEF.across), tostring(DEF.fix)),
        DEF.scale == 1.2 and DEF.across == 0.5 and DEF.fix == 1, W)
end
-- A. run at 460 straight at a board lying still along your run: it gets 460 along it, once (build 212: no second kick 60 ms on), and no more
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.mesh = 455
    check("A: the click takes the hop", W.N.hopTry("L3") == true, W)
    W.tick(120)
    check("A: no error, on the board", W.err == nil and W.onboard, W)
    check("A: one kick of 460 0 0 along +X, and no 'once more, as always' (build 212)", #W.kicks == 1 and near(W.kicks[1][1], 460) and near(W.kicks[1][2], 0) and near(W.kicks[1][3], 0) and near(W.kicks[1][5], 1, 0.01) and W.has("once more, as always") == nil, W)
    check("A: the first reading about 60 ms after the kick, and nothing given at it (build 212)", #W.kicks >= 1 and W.has("ms after the mount the game reads") ~= nil
        and near(W.logT[W.has("ms after the mount the game reads") or 1] - W.kicks[1].t, 0.0625, 0.02) and W.count("-> given") == 0, W)
    check("A: the parts let go of", W.partsHeld == 0, W)
    check("A: the arc ends on the board (150, 0) at riding height", near(W.moves[#W.moves][1], 150, 1) and near(W.moves[#W.moves][2], 0, 1) and near(W.moves[#W.moves][3], 105, 1), W)
    check("A: the older native half is said in the log (boardgo answered 0)", W.has("not looked at by this native half") ~= nil and W.goCalls == 1, W)
    check("A: the watch is over (a new hop is possible)", W.free(), W)
    show(W)
    -- the arc does not brake into the landing: the last 12.5 ms cover about as much ground as the middle ones
    local n = #W.moves
    local last, mid = W.moves[n][1] - W.moves[n - 1][1], W.moves[n // 2][1] - W.moves[n // 2 - 1][1]
    check(string.format("A: the arc's last step %.1f cm against %.1f in the middle (glide)", last, mid), last > 0.6 * mid, W)
end
-- A2. the same with the shipped scale: 460 x 1.2 = 552
do local W = world({ scale = DEF.scale }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("A2: the shipped BoardHopSpeedScale gives 552 along +X", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 552, 1) and near(W.kicks[1][2], 0, 1), W)
    show(W)
end
-- B. the same run at a board lying square to it, BoardHopSpeedAcross 0.5: half the speed, along the board
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.deck.yaw = 90
    W.N.hopTry("L3") W.tick(120)
    local k = W.kicks[1]
    check("B: 230 along the board (Y), nothing across it", W.err == nil and k and near(math.abs(k[2]), 230, 2) and near(k[1], 0, 2), W)
    show(W)
end
-- B0. ... with BoardHopSpeedAcross 0: nothing of the run (and the board lay still: no kick at all)
do local W = world({ across = 0 }) W.vel = { X = 460, Y = 0, Z = 0 } W.deck.yaw = 90
    W.N.hopTry("L3") W.tick(120)
    check("B0: square to the board with Across 0 = no kick", W.err == nil and #W.kicks == 0 and W.onboard, W)
    show(W)
end
-- B1. ... with BoardHopSpeedAcross 1: all of it
do local W = world({ across = 1 }) W.vel = { X = 460, Y = 0, Z = 0 } W.deck.yaw = 90
    W.N.hopTry("L3") W.tick(120)
    check("B1: square to the board with Across 1 = 460 along it", W.err == nil and W.kicks[1] and near(math.abs(W.kicks[1][2]), 460, 2), W)
end
-- C. standing still by a board that rolls at 200: its own 200 given back (build 128's rule)
do local W = world({}) W.dv = { 200, 0 } W.deck.x = 60
    W.N.hopTry("L3") W.tick(120)
    check("C: the board's own speed given back, about 200 along +X, once (build 212)", W.err == nil and #W.kicks == 1 and near(W.kicks[1][1], 200, 15) and near(W.kicks[1][2], 0, 2), W)
    show(W)
end
-- D. run at 460 after a board that rolls away at 600: the board keeps its 600
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.dv = { 600, 0 } W.deck.x = 60
    W.N.hopTry("L3") W.tick(120)
    check("D: the faster board keeps its own speed", W.err == nil and W.kicks[1] and W.kicks[1][1] > 500, W)
    show(W)
end
-- D2. run at 460 at a board rolling TOWARD you at 200: you win, 460 the way you ran
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.dv = { -200, 0 } W.deck.x = 200
    W.N.hopTry("L3") W.tick(120)
    check("D2: a board rolling at you is turned round: +460", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 460, 2), W)
end
-- E. BoardHopSpeedScale 0: build 210 again (a still board gets nothing)
do local W = world({ scale = 0 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("E: scale 0 and a still board = no kick", W.err == nil and #W.kicks == 0 and W.onboard, W)
    local n = #W.moves
    local last, mid = W.moves[n][1] - W.moves[n - 1][1], W.moves[n // 2][1] - W.moves[n // 2 - 1][1]
    check(string.format("E: the arc brakes into the landing as before (last step %.2f cm, middle %.1f)", last, mid), last < 0.2 * mid, W)
    show(W)
end
-- F. the game holds the board still for half a second (a slope) and this native half cannot let go: given again until it sticks
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 }
    W.speedFn = function(w) return (w.mountT and w.t - w.mountT > 0.5) and (w.given or 0) or 0 end
    W.N.hopTry("L3") W.tick(140)
    check("F: given again while the game reads nothing, 7 kicks at most, the hold asked about once", W.err == nil and #W.kicks >= 4 and #W.kicks <= 7 and W.goCalls == 1, W)
    check("F: 'given AGAIN' is in the log", W.has("given AGAIN: the game had taken it back") ~= nil, W)
    check("F: a new hop is possible again (the watch let go)", W.free(), W)
    show(W)
end
-- F2. ... and with the native half's boardgo (returns 1): said so in the log
do local W = world({ go = 1 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("F2: the hold let go is in the log, one kick (build 212)", W.err == nil and #W.kicks == 1 and W.has("the game's hold-still after a mount: let go") ~= nil, W)
end
-- F3. ... boardgo returns 2: the hold was not up
do local W = world({ go = 2 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("F3: 'was not up' is in the log", W.err == nil and W.has("the game's hold-still after a mount: was not up") ~= nil, W)
end
-- G. the board lies tail toward your run (yaw 180): tail-first, the speed still the way you ran
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.deck.yaw = 180
    W.N.hopTry("L3") W.tick(120)
    check("G: tail-first = +460 along X all the same", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 460, 2), W)
    show(W)
end
-- H. the game does not mount you: the board's flag put back, no kick, a new hop possible
do local W = world({ mounts = false }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(140)
    check("H: no mount = the ragdoll flag put back once, no kick, no facing line", W.err == nil and W.ragdollPuts == 1 and #W.kicks == 0 and W.has("the game did not mount you") ~= nil and W.count("facing") == 1, W)   -- (1 = the click's own "facing the deck's ... side" line)
    check("H: a new hop is possible", W.free(), W)
end
-- I. a bail right after the mount: the speed is left alone
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(38) W.mode = 5 W.tick(100)
    check("I: bailing = no further kicks, the watch over", W.err == nil and #W.kicks <= 1 and W.has("a bail or a drop-in") ~= nil and W.free(), W)
    show(W)
end
-- I2. off the board again 100 ms after the mount (no bail mode seen): the watch ends, the flag is NOT put back
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(45) W.onboard = false W.tick(100)
    check("I2: off the board again = the watch ends, no ragdoll flag put back, no 'did not mount you'", W.err == nil and W.ragdollPuts == 0 and W.has("off the board again") ~= nil and W.has("did not mount you") == nil, W)
    check("I2: ... and only the first facing line", W.count("facing on the first frame riding") == 1 and W.count("facing 0.5 s on") == 0, W)
end
-- I3. the same with nothing to give (standing, a still board): off again inside the half second -- still no flag put back (A.mounted, not the kick count)
do local W = world({})
    W.N.hopTry("L3") W.tick(45) W.onboard = false W.tick(100)
    check("I3: nothing given, then off the board again = no ragdoll flag put back, no 'did not mount you'", W.err == nil and #W.kicks == 0 and W.ragdollPuts == 0 and W.has("off the board again") ~= nil and W.has("did not mount you") == nil, W)
    show(W)
end
-- J. after a run-out: Velocity reads 0, the mesh travels at 800: 800 the way you face
do local W = world({}) W.mesh = 800
    W.N.hopTry("L3") W.tick(120)
    check("J: the mesh's 800 the way you face", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 800, 2), W)
    show(W)
end
-- K. BoardHopSpeedScale 1.5: 690
do local W = world({ scale = 1.5 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("K: x1.5 = 690", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 690, 2), W)
end
-- K2. the cap: 1100 x 3 = 3300 -> 2000
do local W = world({ scale = 3 }) W.vel = { X = 1100, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("K2: never over 2000 cm/s", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 2000, 2), W)
end
-- L. a board on a 20 deg bank, lying up it: the speed goes along the deck (it rises)
do local W = world({ slope = 20 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("L: 460 over the ground and 167 up, along the deck", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 460, 2) and near(W.kicks[1][3], 460 * math.tan(math.rad(20)), 3), W)
end
-- M. the deck's axes cannot be read: the way the hop aimed is used
do local W = world({ noAxes = true }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    check("M: no deck axes = still 460 along +X", W.err == nil and W.kicks[1] and near(W.kicks[1][1], 460, 2) and near(W.kicks[1][3], 0), W)
end
-- N. a run at 45 deg to the board, Across 0.5: 460 x (0.707 + 0.5 x 0.293) = 393
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.deck.yaw = 45
    W.N.hopTry("L3") W.tick(120)
    local k = W.kicks[1]
    check("N: 45 deg off = 393 along the board", W.err == nil and k and near(math.sqrt(k[1] ^ 2 + k[2] ^ 2), 392.6, 2) and near(k[1], k[2], 2), W)
end

-- THE MERGED WATCH: the facing check (hop180) and the speed (hopspeed) in one HOP.after block
-- P. something given: facing first, then the kick; the second facing line half a second on; the watch runs to 0.8 s and ends
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(60)                                   -- about 280 ms after the mount
    local i1, ik = W.has("facing on the first frame riding"), W.has("board hop: riding -- ")
    check("P: the first facing line comes before anything is given", W.err == nil and i1 and ik and i1 < ik and W.logT[i1] == W.kicks[1].t, W)
    check("P: 280 ms on the watch still runs (a click is not taken) and the second facing line is not there yet", not W.free() and W.count("facing 0.5 s on") == 0, W)
    W.tick(22)                                                    -- about 555 ms
    local i2 = W.has("facing 0.5 s on")
    check("P: the second facing line half a second after the first", i2 and near(W.logT[i2] - W.logT[i1], 0.5, 0.02), W)
    check("P: ... and the speed's watch is still on at 555 ms", not W.free(), W)
    W.tick(30)                                                    -- about 930 ms
    check("P: over after 0.8 s: both facing lines once, speed readings at about 60, 260, 460, 660, 860 ms", W.free() and W.count("facing on the first frame riding") == 1 and W.count("facing 0.5 s on") == 1 and W.count("ms after the mount the game reads") == 5, W)
    show(W)
end
-- Q. nothing to give (standing, a still board): said at once, the watch waits for the second facing line only, then ends
do local W = world({})
    W.N.hopTry("L3") W.tick(60)
    local i1, ik = W.has("facing on the first frame riding"), W.has("board hop: riding -- nothing given")
    check("Q: facing, then 'nothing given', no kick, the hold not asked about", W.err == nil and i1 and ik and i1 < ik and #W.kicks == 0 and W.goCalls == 0, W)
    check("Q: 280 ms on the watch still waits for the facing check", not W.free() and W.count("facing 0.5 s on") == 0, W)
    W.tick(25)
    local i2 = W.has("facing 0.5 s on")
    check("Q: the second facing line half a second on, then over ('nothing given' said once)", i2 and near(W.logT[i2] - W.logT[i1], 0.5, 0.02) and W.free() and W.count("nothing given") == 1, W)
    show(W)
end
-- R. the facing lines read right: a regular hop stands you as planned, the deck does not turn
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(120)
    local l1 = W.logs[W.has("facing on the first frame riding") or 0] or ""
    check("R: 'capsule 0 (planned 0, +0 off; handed over at 0), deck nose 0 (was 0, turned +0)', foot position 1", l1:find("capsule 0 (planned 0, +0 off; handed over at 0), deck nose 0 (was 0, turned +0)", 1, true) ~= nil and l1:find("foot position 1, the game says switch false (asked false)", 1, true) ~= nil, W)
end
-- S. THE LOOP'S GUARD: an error in the hop's tick is said and the hop dropped (it was swallowed and blocked the next hop for good)
do local W = world({ dropFails = true }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(60)
    check("S: an error at the mount is in the log, once, and the hop is dropped", W.count("board hop: error, the hop is dropped") == 1 and W.has("the drop-in's stand-in was told to fail") ~= nil and W.partsHeld == 0, W)
    W.err = nil W.dropFails = false
    check("S: ... a new hop is possible", W.free(), W)
end
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 }
    W.N.hopTry("L3") W.tick(10) W.S.BoardHopTime = "x" W.tick(10)     -- (a setting that cannot be compared: the arc's own arithmetic fails)
    check("S2: an error in the arc is in the log, once", W.count("board hop: error, the hop is dropped") == 1, W)
    W.S.BoardHopTime = 0.45 W.err = nil
    check("S2: ... a new hop is possible", W.free(), W)
end

out[#out + 1] = string.format("%d checks", nchecks)
local o = assert(io.open("hoptest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the board hop's test failed: see hoptest_out.txt", 0) end

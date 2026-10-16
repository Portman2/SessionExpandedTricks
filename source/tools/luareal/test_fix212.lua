-- test_fix212.lua (build 212, mk212_fix.pl; made by mk_test212_fix.pl): the fix pass after the four reviews of 10 Oct.
--   F1  the board's parts looked up as he lands are used by the watch while THEIR deck lives (A.deck), not while
--       whichever deck the mod holds by then does (BD.comp);
--   F2  a look for the parts that was PUT OFF as he lands (the engine clearing objects out) is said as that in the
--       "as you land" line, not as "the board's parts were not found";
--   F3  BoardHopAirKeep: 0 = he is not put back in the air when the game's own landing cuts in during a hop.
-- The hop's block is cut out of main.lua and run in real Lua against test_hop212.lua's stand-in for the game (taken
-- over as it stands; what it models, and that it is a MODEL, is said at the head of that file). The settings are
-- the ones the file SHIPS.
--   luareal -run test_fix212.lua result.txt main.lua   (writes fix212_out.txt)
-- Run on the pass's input (l3.lua) the checks marked [fix] must FAIL and the others pass: that is what shows they
-- look at the thing changed.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local function at(s, from, what) return assert(src:find(s, from, true), what .. " was not found") end
local function cut(from, to, what) local a = at(from, 1, what) local b = at(to, a, what .. "'s end") return src:sub(a, b - 1) end
local body      = cut("    local HOP = { on = false, rideZ = nil", "\nend\n\n-- THE DROP-IN (v98)", "the board hop") .. "\n"
local setYawSrc = cut("local function setYaw(offset, commit)", "\n-- after touchdown the body twists", "setYaw")
local guardSrc  = cut("NATIVE.yawGuard = function()", "\nlocal function onFrame(ctx)", "the yaw watch")
assert(body:find("LoopAsync(10, function()", 1, true), "the hop's loop is not in the slice")
local function default(k) return tonumber(src:match("\n    " .. k .. "%s*=%s*([%-%d%.]+),")) end
local function spec(k) local lo, hi = src:match('\n    { "' .. k .. '",%s*"num",%s*([%-%d%.]+),%s*([%-%d%.]+),') return tonumber(lo), tonumber(hi) end

local function wrap(x) return x - 360 * math.floor(x / 360 + 0.5) end
local function near(x, y, tol) return x ~= nil and y ~= nil and math.abs(x - y) <= (tol or 0.5) end
local function nearA(x, y, tol) return x ~= nil and y ~= nil and math.abs(wrap(x - y)) <= (tol or 0.5) end
local function smooth(x) x = math.max(0, math.min(1, x)) return x * x * (3 - 2 * x) end

-- the game's mount, as read (see the head of this file)
local function mount(W)
    local sw, flip = W.m.sw == 1, W.m.flip == 1
    if W.again then W.dv = { W.again[1], W.again[2] } W.dvz = W.again[3] or W.dvz end   -- a physics step set the board moving again after the Lua's slice
    local v, md = W.dv, W.moveDir
    local sp = math.sqrt(v[1] ^ 2 + v[2] ^ 2)
    local deckYawWas = W.deck.yaw
    if sw then W.yaw = W.yaw + 180 end                                       -- ApplyToggleOnBoard, foot position 4
    local foot = sw and 4 or 1
    local Hy = math.rad(sw and (W.yaw + 180) or W.yaw)                       -- the way you will ride
    local along = math.sqrt(md[1] ^ 2 + md[2] ^ 2) * math.abs(md[1] * v[1] + md[2] * v[2])   -- the board's GetCurrentSpeed
    W.alongAtMount = along
    if along > 50 and sp > 0 then                                            -- UpdateMoveDirection takes the board's travel for the way you move...
        local tx, ty = v[1] / sp, v[2] / sp
        local fy = math.rad(deckYawWas)
        if tx * math.cos(Hy) + ty * math.sin(Hy) < 0 and math.abs(tx * math.cos(fy) + ty * math.sin(fy)) > 0.8 then   -- ...against the ride, along the board: AdjustFoot
            foot = (foot == 1) and 2 or 3
            W.relabelled, W.route = true, "A"
        end
    end
    local swReset = (foot == 2 or foot == 4)                                 -- "is switch" as the mount's last ResetBoard compares it with the flip flag
    -- rule C: what ForceStop leaves of the board's motion is its vertical speed; along a deck whose riding end stands
    -- W.pitchRide deg higher (lower: negative) that is |vz| x sin(pitch), and "down, laid in the deck" points at the lower end
    W.cAlong = math.abs(W.dvz) * math.sin(math.rad(math.abs(W.pitchRide)))
    if W.cAlong > 50 and W.dvz * W.pitchRide < 0 and not W.relabelled then
        foot = (foot == 1) and 2 or 3
        W.relabelled, W.route = true, "C"
    end
    local swNow = (foot == 2 or foot == 4)
    W.dof = (swReset ~= flip) and 180 or 0                                   -- ResetBoard: the deck offset
    W.deck.yaw = wrap(W.yaw + ((swNow ~= flip) and 180 or 0))                -- SnapToGround: the board to the capsule, half a turn round when "is switch" is not the flip flag
    if W.lateRelabel then foot = (foot == 1) and 2 or 3 end                   -- (a test's own case: the label changed after the snap, by none of the mount's tests)
    W.foot = foot
    W.fromAir = (W.mm == 3)
    if W.fromAir then W.deck.x, W.deck.y = W.loc.X, W.loc.Y                  -- mounted from falling: the board is brought under the capsule
    else W.loc.X, W.loc.Y = W.deck.x, W.deck.y end                           -- from walking: the capsule goes to the board
    W.loc.Z = W.deck.z + W.ride
    W.dv = { 0, 0 } W.dvz = 0 W.given = 0                                    -- ForceStop (and the snap)
    W.onboard = true W.mode = 1 W.mm, W.cm = 6, 1
    W.mountT, W.mountFrame = W.t, W.frame
    W.snap = sw and 180 or 0                                                 -- the snapshot of the on-foot pose (half a turn round for a switch mount)
    W.after = { capsule = W.yaw, deck = W.deck.yaw, foot = foot }
end

local function world(o)
    local W = { t = 100, frame = 0, dt = 1 / 60, order = 2, logs = {}, logT = {}, moves = {}, body = {}, kicks = {}, stops = {}, mcalls = {}, traces = {}, setMM = {}, drawn = {},
                loc = { X = 0, Y = 0, Z = 95 }, yaw = 0, mm = 1, cm = 0, vel = { X = 0, Y = 0, Z = 0 }, meshSp = -1,
                deck = { x = 150, y = 0, z = 10, yaw = 0, upz = 1 }, dv = { 0, 0 }, dvz = 0, pitchRide = 0, moveDir = { 0, 0 }, stand = 85, ride = 85,
                onboard = false, pending = false, mountsOk = true, foot = 0, dof = 0, mode = 0, side = -1, chestRel = 0, snap = 0,
                nativeV = 114, go = 1, partCalls = 0, partsHeld = 0, ragdollPuts = 0, meshWrites = 0, relMax = 0, velReads = 0, landings = 0,
                rel = { Yaw = 0, Pitch = 0, Roll = 0 } }
    for k, v in pairs(o or {}) do W[k] = v end
    W.nextLoop = W.t + 0.004
    local env = setmetatable({}, { __index = _G })
    W.env = env                                                          -- (test_fix212) for a test that looks at what the native half is handed
    env.HJN_BoardState = function() return (W.onboard and 4 or 1) | (8 << 4) end
    env.HJN_DeckWorld = function() return string.format("%.2f %.2f %.2f %.2f %.3f", W.deck.x, W.deck.y, W.deck.z, W.deck.yaw, W.deck.upz) end
    env.HJN_DeckAxes = function() local r = math.rad(W.deck.yaw) return string.format("%.4f %.4f %.4f 0 0 1", math.cos(r), math.sin(r), 0) end
    env.HJN_BoardMount = function(...)
        local sw, flip, wipe, vx, vy = ...
        local c = { n = select("#", ...), sw = sw, flip = flip, wipe = wipe, vx = vx, vy = vy, t = W.t, mm = W.mm, stopsBefore = #W.stops, dv = { W.dv[1], W.dv[2] }, held = W.partsHeld }
        W.mcalls[#W.mcalls + 1] = c
        if W.refuse then return 0 end
        W.m = c
        if W.nativeV >= 114 and wipe == 1 then W.moveDir = { 0, 0 } W.wiped = true end   -- native v114: the stored move direction zeroed
        return 1
    end
    env.HJN_BoardRagdoll = function() W.ragdollPuts = W.ragdollPuts + 1 return 1 end
    env.HJN_BoardParts = function(...)
        if select("#", ...) > 0 then if W.takeNone then return 0 end W.partsHeld = W.partsHeld + 1 return select("#", ...) end
        W.partsHeld = math.max(0, W.partsHeld - 1) return 0
    end
    env.HJN_BoardKick = function(x, y, z, spin, ox, oy)
        if W.partsHeld < 1 then return 0 end
        if not W.onboard then W.stops[#W.stops + 1] = { x, y, z, t = W.t, was = { W.dv[1], W.dv[2], W.dvz } } W.dv = { x, y } W.dvz = z return W.kickParts or 7 end   -- the board lies loose: its velocity is set, the vertical too
        W.kicks[#W.kicks + 1] = { x, y, z, spin, ox, oy, t = W.t }
        W.given = math.sqrt(x * x + y * y) W.kdir = { x / math.max(1e-6, W.given), y / math.max(1e-6, W.given) }
        return 7
    end
    env.HJN_MeshSpeed = function() return W.meshSp end
    env.HJN_CtrlYaw = function() return string.format("%.1f %d 0", 0, W.dof) end
    env.HJN_Set = function(k) if k == "boardgo" then return W.go end return 1 end
    env.HJN_TrickTrace = function(n, tag) W.traces[#W.traces + 1] = { n = n, tag = tag } return n end
    env.LoopAsync = function(ms, fn) W.loopMs, W.loop = ms, fn end
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    local S = { BoardHop = 1, BoardHopRange = 250, BoardHopTime = 0.45, BoardHopHeight = 40, BoardHopRideZ = 95, TraceLog = 1 }
    for _, k in ipairs({ "BoardHopSpeedScale", "BoardHopSpeedAcross", "BoardHopSwitchFix", "BoardHopStanceLock", "BoardHopLandLift", "BoardHopTurnHold", "BoardHopTurnHoldSwitch", "BoardHopRecord", "BoardHopPoses" }) do S[k] = default(k) end
    for k, v in pairs(W.set or {}) do S[k] = v end
    local q = function(fn, d) local ok, v = pcall(fn) if ok and v ~= nil then return v end return d end
    local s0 = {
        K2_GetActorLocation = function() return { X = W.loc.X, Y = W.loc.Y, Z = W.loc.Z } end,
        K2_GetActorRotation = function() return { Pitch = 0, Yaw = wrap(W.yaw), Roll = 0 } end,
        K2_SetActorLocationAndRotation = function(_, p, r)
            W.moves[#W.moves + 1] = { p.X, p.Y, p.Z, r.Yaw, t = W.t, step = math.abs(wrap(r.Yaw - W.yaw)) }
            W.loc = { X = p.X, Y = p.Y, Z = p.Z } W.yaw = r.Yaw
        end,
        IsOnBoard = function() return W.onboard end,
        SetPendingApplyToggleOnBoard = function() W.pending = true end,
        GetCurrentFootPosition = function() return W.foot end,
        IsSkatingSwitch = function() return W.foot == 4 or W.foot == 2 end,
        GetGameTimeSinceCreation = function() if W.noClock then error("not there") end return W.frame * W.dt end,
    }
    local mv = setmetatable({ GetCurrentSpeed = function() if W.speedFn then return W.speedFn(W) end return W.given or 0 end,
                              SetMovementMode = function(_, m) W.setMM[#W.setMM + 1] = { m = m, t = W.t } W.mm = m end },
        { __index = function(_, k) if k == "Velocity" then return W.vel elseif k == "MovementMode" then return W.mm elseif k == "CustomMovementMode" then return W.cm end end,
          __newindex = function(_, k) if k ~= "Velocity" then error("unexpected write: " .. tostring(k)) end end })
    -- the mesh: its yaw against the capsule, and the toes -- they point where the chest does, in both poses
    local mesh = { RelativeRotation = W.rel,
        K2_SetRelativeRotation = function(_, r) W.meshWrites = W.meshWrites + 1 W.rel.Yaw = r.Yaw W.relMax = math.max(W.relMax, math.abs(wrap(r.Yaw))) end,
        K2_GetComponentRotation = function() return { Pitch = 0, Yaw = wrap(W.yaw + W.rel.Yaw), Roll = 0 } end,
        GetSocketLocation = function(_, n)
            local a = math.rad(W.yaw + W.rel.Yaw + W.chestRel)
            if n:find("Toe", 1, true) then return { X = W.loc.X + 10 * math.cos(a), Y = W.loc.Y + 10 * math.sin(a), Z = 0 } end
            return { X = W.loc.X, Y = W.loc.Y, Z = 0 }
        end }
    W.flipper = { dead = false, GetPhysicsLinearVelocity = function() W.velReads = W.velReads + 1 if W.noVel then error("no such function") end return { X = W.dv[1], Y = W.dv[2], Z = W.dvz } end }
    local BD = { comp = nil }
    local NATIVE = { live = true, v = W.nativeV, gt = function(fn) fn() end,
                     dropBusy = function() if W.dropFails then error("the drop-in's stand-in was told to fail") end return W.dropNow == true end,
                     boardParts = function() W.partCalls = W.partCalls + 1 BD.comp = nil if W.noParts then return nil end BD.comp = W.flipper return { 1, 2, 3, 4, 5, 6, 7 } end }
    local alive = function(x) if x == nil or (type(x) == "table" and x.dead) then return nil end return x end
    local chunk = "local S, q, s0, mv, log, modeNow, MODE_RIDING, MODE_BAILING, NATIVE, alive, refs, NAT, BD, mesh, fname, addr = ...\n"
        .. "local active, yaw0 = false, 0\n" .. setYawSrc .. "\n" .. body .. "\nreturn NATIVE, function(v) active = v end"
    local fn = assert(load(chunk, "=hop", "t", env))
    local function log(s) W.logs[#W.logs + 1] = s W.logT[#W.logT + 1] = W.t if s:find("board hop: error", 1, true) then W.err = s end end
    W.N, W.setActive = fn(S, q, s0, mv, log, function() return W.mode end, 1, 5, NATIVE, alive, function() return true end, { goofy = W.side < 0 }, BD, mesh,
        function(s) return s end, function() return 1 end)
    W.S, W.BD = S, BD
    assert(W.loop and W.loopMs == 10, "the hop's loop was not registered")
    W.step = function()
        if not W.onboard then W.deck.x, W.deck.y = W.deck.x + W.dv[1] * W.dt, W.deck.y + W.dv[2] * W.dt end
        if W.pending then W.pending = false if W.mountsOk then mount(W) end end
        if not W.onboard then
            local floor = W.deck.z + W.stand                                 -- the capsule standing on the ground the board lies on
            if W.forceWalk and W.forceWalk(W) then W.mm = 1
            elseif W.mm == 3 and W.loc.Z <= floor + 0.001 then W.mm = 1 W.loc.Z = floor W.landings = W.landings + 1   -- the engine's own landing
            elseif W.mm == 1 and W.loc.Z > floor + 2.4 then W.mm = 3 end       -- walked off its floor: falling
            W.chestRel = 0                                                   -- the on-foot pose faces along the mesh
        else
            if W.speedFn then W.meshSp = W.speedFn(W) end
            local sp = W.speedFn and W.speedFn(W) or (W.given or 0)
            if sp > 0 and W.kdir then
                W.loc.X, W.loc.Y = W.loc.X + W.kdir[1] * sp * W.dt, W.loc.Y + W.kdir[2] * sp * W.dt
                W.deck.x, W.deck.y = W.loc.X, W.loc.Y
            end
            local al = smooth((W.frame - W.mountFrame) * W.dt / 0.15)        -- the game's blend out of the snapshot
            W.chestRel = W.snap + wrap(W.side * 90 - W.snap) * math.deg(math.atan(al, 1 - al)) / 90
        end
    end
    W.slices = function(t1)
        while W.nextLoop <= t1 do
            W.t = W.nextLoop
            local ok, err = pcall(W.loop)
            if not ok then W.err = "the loop itself raised: " .. tostring(err) end
            W.body[#W.body + 1] = { t = W.t, cap = W.yaw, rel = W.rel.Yaw, stamp = NATIVE.hopTurnUntil }
            W.nextLoop = W.nextLoop + 0.010
        end
    end
    W.tick = function(n)
        for _ = 1, (n or 1) do
            local t1 = W.t0f + (W.frame + 1) * W.dt
            W.frame = W.frame + 1
            if W.order == 2 then W.step() W.slices(t1) else W.slices(t1) W.step() end
            W.t = t1
            W.drawn[W.frame] = { t = W.t, chest = wrap(W.yaw + W.rel.Yaw + W.chestRel), onboard = W.onboard, mm = W.mm, z = W.loc.Z - W.deck.z }
        end
    end
    W.t0f = W.t
    W.wait = function(s) W.t, W.t0f, W.nextLoop = W.t + s, W.t0f + s, W.nextLoop + s end   -- time passes with nothing run (the frames' own clock is not moved)
    W.has = function(piece) for i, l in ipairs(W.logs) do if l:find(piece, 1, true) then return i end end return nil end
    W.line = function(piece) local i = W.has(piece) return i and W.logs[i] or nil end
    W.count = function(piece) local n = 0 for _, l in ipairs(W.logs) do if l:find(piece, 1, true) then n = n + 1 end end return n end
    W.stamp = function() return NATIVE.hopTurnUntil end
    -- he rides first (the riding height and the toe side are read), then stands on the ground
    W.rideFirst = function(z)
        W.onboard, W.mode, W.mm, W.cm = true, 1, 6, 1
        W.loc.Z = W.deck.z + (z or W.ride) W.chestRel = W.side * 90
        W.N.hopMeasure()
    end
    W.onFoot = function()
        W.onboard, W.mode, W.mm, W.cm = false, 0, 1, 0
        W.loc.Z = W.deck.z + W.stand W.chestRel = 0
    end
    W.hop = function(frames) W.rideFirst() W.onFoot() W.tc = W.t W.took = W.N.hopTry("L3") == true W.tick(frames or 100) return W end
    -- the frame lines of the log, parsed
    W.frames = function()
        local F = {}
        for _, l in ipairs(W.logs) do
            if l:find("board hop:      ", 1, true) == 1 then
                for e in (l:sub(17) .. " | "):gmatch("(.-) | ") do
                    local ms, mode, z, c, m, t, d, a, r, ft, v, w = e:match("^([%+%-]%d+):(%S+) z(%-?%d+) c(%-?%d+) m(%S+) t(%S+) d(%-?%d+) a([%+%-]%d+) r([%+%-]%d+) f(%S+) v(%S+) w(%S+)$")
                    F[#F + 1] = { raw = e, ms = tonumber(ms), mode = mode, z = tonumber(z), c = tonumber(c), m = tonumber(m), t = tonumber(t), d = tonumber(d), a = tonumber(a), r = tonumber(r), f = ft, v = tonumber(v), w = tonumber(w) }
                end
            end
        end
        return F
    end
    return W
end
local out, all, nchecks = {}, true, 0
local function check(name, cond, W)
    nchecks = nchecks + 1
    local err = W and W.err
    if err then cond = false end                                               -- (an error the hop's own guard caught, or the loop raised)
    out[#out + 1] = ((cond and true) and "ok   " or "FAIL ") .. name
    if not cond then all = false
        if err then out[#out + 1] = "       err: " .. tostring(err) end
        for _, l in ipairs(W and W.logs or {}) do out[#out + 1] = "       log: " .. tostring(l):sub(1, 420) end
    end
    return cond
end
local function show(W, piece) for _, l in ipairs(W.logs) do if not piece or l:find(piece, 1, true) then out[#out + 1] = "       " .. l:sub(1, 700) end end end
local function speedKicks(W) local n = 0 for _, k in ipairs(W.kicks) do if math.abs(k[1]) + math.abs(k[2]) > 1 then n = n + 1 end end return n end

-- =================================================================== F1. the parts go with their deck
-- A run at 460 at a still board with the game's hold up for 0.3 s (a slope, no boardgo): the speed is given at the
-- mount and AGAIN at the two readings after it. The look for the board's parts is main.lua's boardParts as the hop
-- sees it: the deck the mod held is dropped, the nearest living board's is taken and its parts are handed back
-- (the hop's board: addresses 1 to 7; another board: 11 to 17); told that the look is put off, it drops the deck
-- and finds none. W.handed = every list of addresses the native half was handed (HJN_BoardParts with arguments).
out[#out + 1] = "--- F1. the parts looked up as he lands are used while THEIR deck lives"
local function held()
    local W = world({ go = 0 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.speedFn = function(w) return (w.mountT and w.t - w.mountT > 0.3) and (w.given or 0) or 0 end
    W.other = { dead = true }
    W.handed = {}
    local take = W.env.HJN_BoardParts
    W.env.HJN_BoardParts = function(...) if select("#", ...) > 0 then W.handed[#W.handed + 1] = { ... } end return take(...) end
    W.N.boardParts = function()
        W.partCalls = W.partCalls + 1 W.BD.comp = nil
        if W.lookOff then return nil end
        if not W.flipper.dead then W.BD.comp = W.flipper return { 1, 2, 3, 4, 5, 6, 7 } end
        if not W.other.dead then W.BD.comp = W.other return { 11, 12, 13, 14, 15, 16, 17 } end
        return nil
    end
    W.rideFirst() W.onFoot() W.took = W.N.hopTry("L3") == true
    for _ = 1, 40 do W.tick(1) if speedKicks(W) >= 1 then break end end           -- to the first kick, given with the parts looked up as he landed
    W.n0 = #W.handed
    return W
end
local function handedSince(W)                                                    -- lists handed over after the first kick: the hop's board's, another's
    local old, new = 0, 0
    for i = W.n0 + 1, #W.handed do if W.handed[i][1] == 1 then old = old + 1 else new = new + 1 end end
    return old, new
end
do local W = held() W.tick(80)
    local old, new = handedSince(W)
    check(string.format("nothing happens to the board: one look for the whole hop, three kicks (the stop before the mount and the first kick: %d lists handed; the two given AGAIN: %d more, all the hop's board's)", W.n0, old),
        W.took and W.onboard and W.partCalls == 1 and speedKicks(W) == 3 and W.n0 == 2 and old == 2 and new == 0 and W.count("given AGAIN: the game had taken it back (7 parts)") == 2 and W.partsHeld == 0, W)
end
do local W = held()
    W.flipper.dead = true W.other.dead = false W.BD.comp = W.other                 -- the hop's board is put away, and a look made in between has pointed the mod at ANOTHER board's deck
    W.tick(80)
    local old, new = handedSince(W)
    check(string.format("[fix] the hop's board is gone and the mod holds another board's deck by then: the dead board's addresses are NOT handed to the native half again (handed %d times), the parts are looked up afresh for each of the two later kicks (%d looks in all, %d lists of the board found then)", old, W.partCalls, new),
        W.took and old == 0 and new == 2 and W.partCalls == 3 and W.partsHeld == 0, W)
end
do local W = held()
    W.BD.comp = nil W.lookOff = true                                              -- the other way round: the mod has let go of the deck it held and a new look finds none (put off), the hop's board still there
    W.tick(80)
    local old, new = handedSince(W)
    check(string.format("[fix] the mod has let go of the deck it held (a look put off dropped it) while the hop's board lives: the watch still has its parts -- given AGAIN twice with 7 parts, no new look (%d looks in all, %d kicks)", W.partCalls, speedKicks(W)),
        W.took and W.onboard and speedKicks(W) == 3 and old == 2 and new == 0 and W.partCalls == 1 and W.count("given AGAIN: the game had taken it back (7 parts)") == 2 and W.partsHeld == 0, W)
end
do local W = held()
    W.flipper.dead = true                                                          -- the hop's board is gone and no other is found
    W.tick(80)
    local old, new = handedSince(W)
    check(string.format("the hop's board is gone and none is found: nothing is handed to the native half (%d lists), the two later readings say '(0 parts)', and the hop does not raise", old + new),
        W.took and old == 0 and new == 0 and speedKicks(W) == 1 and W.partCalls == 3 and W.count("given AGAIN: the game had taken it back (0 parts)") == 2 and W.partsHeld == 0, W)
end

-- =================================================================== F2. a look put off is not a board not found
-- test_hop212's board that rolls at him (200 cm/s along its old move direction, he runs at it at 300). The stand-in
-- NATIVE gets main.lua's count of looks put off (NATIVE.WK.no), and the look for the parts raises it when it is
-- put off, as NATIVE.walkOk does
out[#out + 1] = "--- F2. the 'as you land' line: the look for the board's parts put off, or the parts not found"
local function landing(o, setup)
    local W = world(o or {})
    W.deck.x = 240 W.dv = { -200, 0 } W.moveDir = { -1, 0 } W.vel = { X = 300, Y = 0, Z = 0 }
    if setup then setup(W) end
    return W.hop(100)
end
do
    local W = landing({}, function(W)
        W.N.WK = { n = 5, no = 2 }
        W.N.boardParts = function()
            W.partCalls = W.partCalls + 1 W.BD.comp = nil
            if W.partCalls == 1 then W.N.WK.no = W.N.WK.no + 1 return nil end      -- as he lands: put off (the engine is clearing objects out)
            W.N.WK.n = W.N.WK.n + 1 W.BD.comp = W.flipper return { 1, 2, 3, 4, 5, 6, 7 }   -- a frame later the look is made
        end
    end)
    local c = W.mcalls[1] or {}
    check("[fix] the look for the board's parts is put off as he lands: the line says 'NOT stopped: the look for the board's parts was put off' with what that leaves open, and does not say the parts 'were not found'",
        W.took and W.has("-- the board NOT stopped: the look for the board's parts was put off (the engine was clearing objects out, or a level had just changed) -- a pitched board with vertical speed can then still turn under you; its old direction of travel the native half's to wipe") ~= nil
        and W.has("were not found") == nil, W)
    check("...the mount is made all the same with wipe 1, nothing is stopped, and the watch looks again and gives the speed with 7 parts",
        W.took and W.onboard and c.wipe == 1 and #W.stops == 0 and W.partCalls == 2 and speedKicks(W) == 1 and (W.line("board hop: riding --") or ""):find("(7 parts", 1, true) ~= nil, W)
    show(W, "as you land")
end
do
    local W = landing({}, function(W)
        W.N.WK = { n = 5, no = 2 }
        W.N.boardParts = function() W.partCalls = W.partCalls + 1 W.BD.comp = nil W.N.WK.n = W.N.WK.n + 1 return nil end   -- the look is made and finds no board
    end)
    check("a look that is MADE and finds no board still reads 'NOT stopped: the board's parts were not found', and nothing about a look put off",
        W.took and W.onboard and W.has("-- the board NOT stopped: the board's parts were not found -- a pitched board with vertical speed can then still turn under you; its old direction of travel the native half's to wipe") ~= nil
        and W.has("put off") == nil, W)
end
do
    local W = landing({ noParts = true })                                          -- a NATIVE with no count at all (test_hop212's stand-in as it stands)
    check("...and the same where the walk gate's count is not there to read: 'were not found', no error",
        W.took and W.onboard and W.has("-- the board NOT stopped: the board's parts were not found -- a pitched board with vertical speed can then still turn under you") ~= nil and W.has("put off") == nil, W)
end
do
    local W = landing({}, function(W) W.N.WK = { n = 5, no = 2 } end)               -- the count there, the look made, the board found
    check("with the board found nothing changes: 'the board stopped before the mount (7 parts)'",
        W.took and W.onboard and #W.stops == 1 and W.has("-- the board stopped before the mount (7 parts); its old direction of travel the native half's to wipe") ~= nil and W.has("put off") == nil, W)
end

-- =================================================================== F3. BoardHopAirKeep
out[#out + 1] = "--- F3. BoardHopAirKeep: put back in the air when the game's own landing cuts in, or not"
do
    local lo, hi = spec("BoardHopAirKeep")
    check(string.format("[fix] the setting: BoardHopAirKeep %s by default, the ini takes %s to %s", tostring(default("BoardHopAirKeep")), tostring(lo), tostring(hi)),
        default("BoardHopAirKeep") == 1 and lo == 0 and hi == 1)
end
local function cutIn(set, when, from, to)
    local W = world({ set = set or { BoardHopAirKeep = default("BoardHopAirKeep") } }) W.rideFirst() W.onFoot() W.tc = W.t   -- (no setting given: the one the file ships, read off it)
    W.forceWalk = when
    W.took = W.N.hopTry("L3") == true W.tick(100)
    local al = W.line("as you land") or ""
    local re = 0 for _, s in ipairs(W.setMM) do if s.m == 3 and s.t > W.tc + 0.001 and s.t - W.tc >= 0.45 * from and s.t - W.tc < 0.45 * to then re = re + 1 end end
    return W, al, tonumber(al:match("cut in on (%d+) frames on the way down")) or -1, tonumber(al:match("%((%d+) at the take%-off")) or -1, re
end
local function wayDown(w) local k = (w.t - w.tc) / 0.45 return k > 0.62 and k < 0.72 end   -- the engine lands him by itself for a few frames of the way down
local function takeOff(w) return (w.t - w.tc) / 0.45 < 0.3 end                               -- ...and at the take-off (hop 1 of 10 Oct: "walking" for 100 ms after the click)
do
    local W, al, n, n0, re = cutIn(nil, wayDown, 0.6, 9)
    check(string.format("as shipped (1) the engine's landing on the way down is seen on %d ticks and he is put back in the air twice (%d): '(1 at the take-off; put back in the air the first two times of each)'", n, re),
        W.took and W.onboard and n >= 2 and re == 2 and al:find("(1 at the take-off; put back in the air the first two times of each)", 1, true) ~= nil, W)
    W, al, n, n0, re = cutIn({ BoardHopAirKeep = 0 }, wayDown, 0.6, 9)
    check(string.format("[fix] BoardHopAirKeep 0: seen on %d ticks of the way down and counted, he is NOT put back in the air (%d times), the line says so, and the game mounts him all the same", n, re),
        W.took and W.onboard and n >= 2 and re == 0 and al:find("frames on the way down (" .. n0 .. " at the take-off; NOT put back in the air: BoardHopAirKeep 0)", 1, true) ~= nil and #W.mcalls == 1, W)
    out[#out + 1] = "       " .. al:sub(al:find("the game has you", 1, true) or 1, -1)
    W, al, n, n0, re = cutIn({ BoardHopAirKeep = 0 }, takeOff, 0, 0.5)
    check(string.format("[fix] ...nor at the take-off: seen walking on %d ticks there, put back in the air %d times -- the click's own 'in the air' (build 211's) is still made", n0, re),
        W.took and W.onboard and n0 >= 3 and re == 0 and W.setMM[1] and W.setMM[1].m == 3 and W.setMM[1].t <= W.tc + 0.001, W)
    W, al, n, n0, re = cutIn({ BoardHopAirKeep = 0 }, nil, 0, 9)
    check(string.format("[fix] BoardHopAirKeep 0 with nothing cutting in but the take-off's own landing: the line still counts (%d on the way down, %d at the take-off) and names the setting", n, n0),
        W.took and W.onboard and n == 0 and n0 >= 0 and al:find("; NOT put back in the air: BoardHopAirKeep 0)", 1, true) ~= nil, W)
end

out[#out + 1] = string.format("%d checks", nchecks)
local o = assert(io.open("fix212_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the test of build 212's fix pass failed: see fix212_out.txt", 0) end

-- test_hop212.lua (build 212, mk212_hop.pl): the board hop's step of build 212 -- the deck's 180 at the mount, the
-- board's parts and the one kick, the landing height, the turn held in the mesh, the frame lines and the recorder.
-- Cut out of main.lua and run in real Lua against a stand-in for the game: the whole hop block, main.lua's own setYaw
-- and its yaw watch (NATIVE.yawGuard), as they stand in the file. The settings are the ones the file SHIPS.
--   luareal -run test_hop212.lua result.txt main.lua   (writes hop212_out.txt)
-- Run on the step's input (l0.lua) the checks marked [new] must FAIL and the others pass: that is what shows they
-- look at the thing changed.
-- (Second pass, the verdict of 10 Oct 15:11: the stop as half of the cure and the mount's third test, the route in the
-- RE-LABELLED line, the deck's tilt and the board's vertical speed in the "as you land" line, the capped re-assert of
-- "in the air", the level reading that strays, the drop-in shut out, no hold on a switch hop without
-- BoardHopTurnHoldSwitch, and a hippie jump started inside the game's blend. Run on the first pass's l1.lua those
-- checks fail: v131\hop2\all_out.txt, section 4b.)
-- THE STAND-IN IS A MODEL, NOT THE GAME, and for two things it is a model of a READING of the game:
--   the mount's re-label (finding_hop.txt / verdict_hop.txt, UpdateMoveDirection's rule A): the board's speed along
--     its stored move direction over 50 cm/s, its travel against the way you will ride and within 37 deg of the
--     board's own line -> foot position 1 becomes 2 (4 becomes 3), and the snap then turns the deck half a turn. A
--     native half of v114 zeroes the stored direction when asked to (HJN_BoardMount's third argument); v113 does not
--     read that argument. And the verdict's rule C, the test the wipe does NOT shut: the mount's own stop leaves the
--     board its vertical speed; on a deck pitched by p that is |vz| x sin p along the direction the game has just
--     written again, and over 50 the travel "down, laid in the deck" is taken -- where the end you ride toward is the
--     higher one that points against the ride, and the stance is re-labelled AFTER the mount's last ResetBoard has
--     written the deck offset and BEFORE the snap turns the board by it. Only the Lua's stop of the board (vz too)
--     shuts that. Which of the game's tests turned the deck on 10 Oct is NOT known: this model shows that the Lua
--     does what the fix needs, not that the fix is the cure;
--   the quarter-turn flick: the on-foot pose faces along the mesh, the riding pose a quarter turn to the toe side;
--     from the mount the game draws a snapshot of the on-foot pose (half a turn round for a switch mount) and blends
--     to the riding pose in 0.15 s (HermiteCubic), the short way. The hold was written from the same reading, so E
--     checks its arithmetic and its exits, not that the game does this.
-- A frame of the stand-in: the game's clock moves on; then (order 2) the game's own step -- the board rolls, a
-- pending mount is made, the engine lands or drops a walking / falling capsule, the pose is evaluated -- and after it
-- the hop's loop, every 10 ms of the frame; order 1 runs the loop BEFORE the game's step. Which of the two the real
-- game does is not known (the loop is not the game's tick): the hold's own clock is exact in order 2 and a frame
-- late in order 1, and E2 says how far off the body is drawn in each.
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

-- =================================================================== A. what the file ships
out[#out + 1] = "--- A. the settings"
do
    local lo, hi = spec("BoardHopTurnHold")
    check(string.format("[new] defaults: BoardHopStanceLock %s, BoardHopLandLift %s, BoardHopTurnHold %s, BoardHopTurnHoldSwitch %s, BoardHopRecord %s, BoardHopPoses %s; the ini takes BoardHopTurnHold %s to %s",
        tostring(default("BoardHopStanceLock")), tostring(default("BoardHopLandLift")), tostring(default("BoardHopTurnHold")), tostring(default("BoardHopTurnHoldSwitch")), tostring(default("BoardHopRecord")), tostring(default("BoardHopPoses")), tostring(lo), tostring(hi)),
        default("BoardHopStanceLock") == 1 and default("BoardHopLandLift") == 3 and default("BoardHopTurnHold") == 1 and default("BoardHopTurnHoldSwitch") == 0 and default("BoardHopRecord") == 1 and default("BoardHopPoses") == 1 and lo == 0 and hi == 2
        and select(2, spec("BoardHopStanceLock")) == 1 and select(2, spec("BoardHopLandLift")) == 15 and select(2, spec("BoardHopTurnHoldSwitch")) == 1 and select(2, spec("BoardHopRecord")) == 1 and select(2, spec("BoardHopPoses")) == 1)
    check(string.format("the three older ones as they were: BoardHopSpeedScale %s, BoardHopSpeedAcross %s, BoardHopSwitchFix %s", tostring(default("BoardHopSpeedScale")), tostring(default("BoardHopSpeedAcross")), tostring(default("BoardHopSwitchFix"))),
        default("BoardHopSpeedScale") == 1.2 and default("BoardHopSpeedAcross") == 0.5 and default("BoardHopSwitchFix") == 1)
end

-- =================================================================== B. the deck's 180
-- a board that rolls at him at 200 cm/s along its old move direction, he runs at it at 300: the travel is against the
-- way he will ride and along the board -- rule A of the reading
out[#out + 1] = "--- B. the mount must not re-label the stance (the model's rule A: a board rolling at you along its old direction)"
local function rolling(o)
    local W = world(o)
    W.deck.x = 240 W.dv = { -200, 0 } W.moveDir = { -1, 0 } W.vel = { X = 300, Y = 0, Z = 0 }
    return W.hop(100)
end
do local W = rolling({})
    local c = W.mcalls[1] or {}
    out[#out + 1] = string.format("       the mount call: %d arguments (switch %s, flip flag %s, wipe %s, the board's motion %s %s); the board stopped before it: %s; at the mount the board's speed along its old direction read %.0f; foot position %s, deck nose %s",
        c.n or 0, tostring(c.sw), tostring(c.flip), tostring(c.wipe), tostring(c.vx), tostring(c.vy), tostring(c.stopsBefore), W.alongAtMount or -1, tostring(W.after and W.after.foot), tostring(W.after and W.after.deck))
    check("the click takes the hop and the game mounts him", W.took and W.onboard and #W.mcalls == 1, W)
    check("[new] the native half is asked to wipe: HJN_BoardMount(switch 0, flip flag 0, wipe 1, vx, vy, vz)", c.n == 6 and c.sw == 0 and c.flip == 0 and c.wipe == 1 and type(c.vx) == "number" and type(c.vy) == "number", W)
    check("[new] the board is stopped BEFORE the mount call: one kick of 0 0 0 at all 7 parts while it lies loose, and the parts are let go of again",
        #W.stops == 1 and c.stopsBefore == 1 and W.stops[1][1] == 0 and W.stops[1][2] == 0 and W.stops[1][3] == 0 and c.dv[1] == 0 and c.held == 0 and W.partsHeld == 0, W)
    check("[new] ...and the velocity handed over is the one its physics body had before the stop (-200 0), not what the stop left", near(c.vx, -200, 0.01) and near(c.vy, 0, 0.01) and W.velReads == 1, W)
    check("[new] the mount leaves him as planned: foot position 1, the deck's nose where it was -- not re-labelled, not turned", W.after and W.after.foot == 1 and nearA(W.after.deck, 0) and not W.relabelled, W)
    local l1 = W.line("facing on the first frame riding") or ""
    check("[new] the log: 'the board stopped before the mount (7 parts)', the wipe named as the native half's, 'turned +0', and no RE-LABELLED line",
        W.has("-- the board stopped before the mount (7 parts); its old direction of travel the native half's to wipe (its 'mounting where the board lies' line says ZEROED)") ~= nil and (l1:find("turned +0", 1, true) or l1:find("turned -0", 1, true)) ~= nil and W.has("RE-LABELLED") == nil, W)
    check("[new] the 'as you land' line has both readings of the board's motion -- by its physics body 200 cm/s (-200 along the ride), and by the deck's travel -- and the deck's tilt and the board's vertical speed: 'deck up z 1.00, vertical +0 cm/s'",
        (W.line("as you land") or ""):find("by its physics body 200 cm/s (-200 along the way you will ride, +0 across it to the right), by the deck's travel", 1, true) ~= nil
        and (W.line("as you land") or ""):find(", deck up z 1.00, vertical +0 cm/s -- the board stopped", 1, true) ~= nil, W)
    show(W, "as you land")
end
do local W = rolling({ set = { BoardHopStanceLock = 0 } })
    local c = W.mcalls[1] or {}
    check("BoardHopStanceLock 0 (the A/B): wipe 0, the board is not stopped -- and in the model the mount re-labels him (foot position 2) and turns the deck 180, as on 10 Oct 09:55:37",
        W.took and c.sw == 0 and c.flip == 0 and (c.wipe == 0 or c.wipe == nil) and #W.stops == 0 and W.relabelled == true and W.after.foot == 2 and nearA(W.after.deck, 180), W)
    check("[new] ...which the log names: 'THE MOUNT RE-LABELLED YOUR STANCE OR TURNED THE DECK', once, and 'the board left as it is; its old direction of travel left as it is (BoardHopStanceLock 0)'",
        W.count("THE MOUNT RE-LABELLED YOUR STANCE OR TURNED THE DECK") == 1 and W.has("-- the board left as it is; its old direction of travel left as it is (BoardHopStanceLock 0)") ~= nil, W)
    check("[new] ...with the route, from the deck offset (the model's rule A re-labels before the last ResetBoard: offset 180 where regular and flip flag 0 give 0, as in the log of 10 Oct 09:55:37): 're-labelled BEFORE the mount's last ResetBoard'",
        W.route == "A" and W.dof == 180 and (W.line("RE-LABELLED") or ""):find("deck offset 180 where the stance and flip flag asked for give 0: re-labelled BEFORE the mount's last ResetBoard", 1, true) ~= nil
        and (W.line("RE-LABELLED") or ""):find("AFTER the mount's last ResetBoard", 1, true) == nil, W)
    check("[new] ...and the native half still gets the board's motion for its line (-200 0)", near(c.vx, -200, 0.01) and near(c.vy, 0, 0.01), W)
    show(W, "RE-LABELLED")
end
do  -- the same on a tail-first regular hop (he faces 0, the nose points -170: flip flag 1), where the mount leaves deck offset 180 when all is well
    local function tail(o)
        local W = world(o)
        local h = math.rad(10)                                                    -- the way he will ride: the tail's end
        W.deck.yaw = -170 W.deck.x = 240 W.dv = { -200 * math.cos(h), -200 * math.sin(h) } W.moveDir = { -math.cos(h), -math.sin(h) } W.vel = { X = 300, Y = 0, Z = 0 }
        return W.hop(100)
    end
    local W = tail({})
    check("[new] a tail-first regular hop (flip flag 1) onto a board rolling at him: not re-labelled, the deck's nose kept, deck offset 180 -- and no RE-LABELLED line for that 180",
        W.took and W.line("riding tail-first regular") ~= nil and W.mcalls[1].flip == 1 and not W.relabelled and W.after.foot == 1 and nearA(W.after.deck, -170) and W.dof == 180 and W.has("RE-LABELLED") == nil, W)
    W = tail({ set = { BoardHopStanceLock = 0 } })
    check("[new] ...and with BoardHopStanceLock 0 the model's rule A turns it, leaving deck offset 0 where this stance and flag give 180: the line still says BEFORE (the route is told from the offset the stance ASKED for, not from 180 as such)",
        W.took and W.relabelled == true and W.route == "A" and W.dof == 0 and nearA(W.after.deck, 10)
        and (W.line("RE-LABELLED") or ""):find("deck offset 0 where the stance and flip flag asked for give 180: re-labelled BEFORE the mount's last ResetBoard", 1, true) ~= nil, W)
end
do local W = rolling({ nativeV = 113 })
    check("[new] a v113 native half (it does not read the third argument): the stop alone keeps the stance in the model, and the log says the wipe was NOT made",
        W.took and #W.stops == 1 and not W.relabelled and W.after.foot == 1 and W.has("its old direction of travel NOT wiped: that takes native v114, this is v113 -- the stop alone holds only while nothing sets the board moving again before the game's mount") ~= nil, W)
    W = rolling({ nativeV = 113, again = { -200, 0 } })
    check("[new] ...but not when the board is set moving again between the Lua's slice and the mount: re-labelled, and named in the log with its route (BEFORE: the wipe's half was missing)",
        W.took and #W.stops == 1 and W.relabelled == true and W.after.foot == 2 and W.count("THE MOUNT RE-LABELLED YOUR STANCE OR TURNED THE DECK") == 1
        and (W.line("RE-LABELLED") or ""):find("re-labelled BEFORE the mount's last ResetBoard", 1, true) ~= nil, W)
    W = rolling({ nativeV = 114, again = { -200, 0 } })
    check("[new] with v114 the wipe holds even then: the board moves at the mount, its speed along the (zeroed) old direction reads 0, foot position 1, the deck not turned",
        W.took and W.wiped == true and W.alongAtMount == 0 and not W.relabelled and W.after.foot == 1 and nearA(W.after.deck, 0) and W.has("RE-LABELLED") == nil, W)
end
do local W = rolling({ noParts = true })
    local c = W.mcalls[1] or {}
    check("[new] the board's parts are not found as he lands: the mount is made all the same with wipe 1, nothing is kicked, and the log says 'NOT stopped: the board's parts were not found' with what that leaves open",
        W.took and W.onboard and c.wipe == 1 and #W.stops == 0 and not W.relabelled
        and W.has("-- the board NOT stopped: the board's parts were not found -- a pitched board with vertical speed can then still turn under you; its old direction of travel the native half's to wipe") ~= nil, W)
    check("[new] ...and the velocity handed over is then the deck's travel as the hop read it (about -200)", near(c.vx, -200, 25) and near(c.vy, 0, 5) and W.has("by its physics body: not read") ~= nil, W)
    W = rolling({ takeNone = true })
    check("[new] the parts are found but the native half takes none of them: 'NOT stopped: the native half took none of its parts', with the same warning; the mount is made",
        W.took and W.onboard and W.has("-- the board NOT stopped: the native half took none of its parts -- a pitched board with vertical speed can then still turn under you;") ~= nil, W)
end
-- the test the wipe does not shut (the verdict's C): a board lying pitched -- the end he will ride toward 30 deg up -- and still
-- coming down at 120 cm/s as he lands: 120 x sin 30 = 60 along the deck, over the game's 50. Nothing of its motion over the ground
out[#out + 1] = "--- B. ...nor by the mount's last test, which the wipe does not shut (the model's rule C: a pitched board with vertical speed)"
local function pitched(o)
    local W = world(o)
    W.deck.x = 240 W.pitchRide = 30 W.dvz = -120 W.vel = { X = 300, Y = 0, Z = 0 }
    W.rideFirst() W.deck.upz = math.cos(math.rad(30)) W.onFoot() W.tc = W.t W.took = W.N.hopTry("L3") == true W.tick(100)
    return W
end
do local W = pitched({})
    local c, al = W.mcalls[1] or {}, W.line("as you land") or ""
    check("[new] the stop takes the vertical speed too (one kick of 0 0 0 before the mount call): at the mount the model reads 0 along the deck, foot position 1, the deck not turned, no RE-LABELLED line",
        W.took and W.onboard and #W.stops == 1 and c.stopsBefore == 1 and W.stops[1].was[3] == -120 and W.cAlong == 0 and not W.relabelled and W.after.foot == 1 and nearA(W.after.deck, 0) and W.has("RE-LABELLED") == nil, W)
    check("[new] the 'as you land' line has what that test goes by: 'deck up z 0.87, vertical -120 cm/s'", al:find(", deck up z 0.87, vertical -120 cm/s -- the board stopped before the mount (7 parts);", 1, true) ~= nil, W)
    out[#out + 1] = "       " .. al:sub(1, 700)
    W = pitched({ noParts = true })
    check("[new] the same board with its parts NOT found (no stop), native v114 wiping: the wipe alone does not hold -- the model's rule C re-labels him (foot position 2) and turns the deck, with the deck offset as asked (0)",
        W.took and W.wiped == true and #W.stops == 0 and W.relabelled == true and W.route == "C" and W.after.foot == 2 and nearA(W.after.deck, 180) and W.dof == 0, W)
    check("[new] ...and the log says both: 'NOT stopped ... a pitched board with vertical speed can then still turn under you' as he lands, and the route on the first riding frame: 're-labelled AFTER the mount's last ResetBoard'",
        W.has("NOT stopped: the board's parts were not found -- a pitched board with vertical speed can then still turn under you") ~= nil
        and (W.line("RE-LABELLED") or ""):find("deck offset 0, as the stance and flip flag asked for give it, and the deck turned all the same: re-labelled AFTER the mount's last ResetBoard", 1, true) ~= nil
        and (W.line("RE-LABELLED") or ""):find("BEFORE the mount's last ResetBoard", 1, true) == nil, W)
    show(W, "RE-LABELLED")
    W = pitched({ again = { 0, 0, -120 } })
    check("[new] ...and when the board is set falling again between the Lua's slice and the mount the stop does not hold either: re-labelled by the same route, and named (the guarantee is 'stopped' AND nothing moving it again)",
        W.took and #W.stops == 1 and W.relabelled == true and W.route == "C" and (W.line("RE-LABELLED") or ""):find("re-labelled AFTER the mount's last ResetBoard", 1, true) ~= nil, W)
    W = pitched({ set = { BoardHopStanceLock = 0 } })
    check("BoardHopStanceLock 0 on the pitched board: nothing stopped, nothing wiped, and the model's rule C turns the deck (the A/B for that route)", W.took and #W.stops == 0 and W.relabelled == true and W.route == "C" and nearA(W.after.deck, 180), W)
end
do  -- the label changes with the deck NOT turned (not one of the mount's tests): said as such
    local W = world({ lateRelabel = true }) W.vel = { X = 300, Y = 0, Z = 0 } W.hop(100)
    check("[new] the game's switch flag is not the one asked for but the deck did not turn: the line says so, and names no test of the mount",
        W.took and W.onboard and W.after.foot == 2 and nearA(W.after.deck, 0) and (W.line("RE-LABELLED") or ""):find("the deck was not turned: the label changed after the board was snapped to you", 1, true) ~= nil
        and (W.line("RE-LABELLED") or ""):find("the mount's last ResetBoard", 1, true) == nil, W)
end
do local W = rolling({ noVel = true })
    local c = W.mcalls[1] or {}
    check("[new] the physics body cannot be read (the call fails): the deck's travel is handed over instead, the board is stopped as before", W.took and #W.stops == 1 and near(c.vx, -200, 25) and W.has("by its physics body: not read") ~= nil, W)
end
do  -- a switch hop: he faces -150, the board lies behind him (nose 0) and rolls at +200 along its old direction = against the way he will ride (-X)
    local function swroll(o)
        local W = world(o)
        W.yaw = -150 W.deck.x = -240 W.dv = { 200, 0 } W.moveDir = { 1, 0 } W.vel = { X = -300, Y = 0, Z = 0 }
        return W.hop(100)
    end
    local W = swroll({})
    local c = W.mcalls[1] or {}
    check("[new] a switch hop onto a board rolling at him: foot position 4 kept, the deck's nose kept, wipe 1 (" .. tostring(W.line("riding tail-first switch") ~= nil) .. ")",
        W.took and W.line("riding tail-first switch") ~= nil and c.sw == 1 and c.wipe == 1 and W.after.foot == 4 and nearA(W.after.deck, 0) and not W.relabelled and W.has("RE-LABELLED") == nil, W)
    W = swroll({ set = { BoardHopStanceLock = 0 } })
    check("...and with BoardHopStanceLock 0 the model takes switch away (4 becomes 3) and turns the deck", W.took and W.relabelled == true and W.after.foot == 3 and nearA(W.after.deck, 180), W)
end

-- =================================================================== C. the parts and the kick
out[#out + 1] = "--- C. one look for the board's parts a hop, one kick"
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.meshSp = 455 W.hop(110)
    check("[new] a run at 460 at a still board: the parts are looked up once for the whole hop (as he lands), the speed is given once (552 along +X) and not 'once more'",
        W.took and W.onboard and W.partCalls == 1 and speedKicks(W) == 1 and near(W.kicks[1][1], 552, 1) and near(W.kicks[1][2], 0, 1) and W.has("once more, as always") == nil and W.partsHeld == 0, W)
    check("[new] the first reading comes 60 ms after the kick and gives nothing; five readings in all, the watch over after 0.8 s",
        W.count("ms after the mount the game reads") == 5 and W.count("-> given") == 0 and near(W.logT[W.has("ms after the mount the game reads") or 1] - (W.kicks[1] and W.kicks[1].t or 0), 0.06, 0.012)
        and (function() W.onFoot() W.loc = { X = W.deck.x - 100, Y = W.deck.y, Z = W.deck.z + W.stand } return W.N.hopTry("again") == true end)(), W)
    show(W, "board hop: riding")
end
do local W = world({ go = 0 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.speedFn = function(w) return (w.mountT and w.t - w.mountT > 0.3) and (w.given or 0) or 0 end      -- the game's hold for 0.3 s (a slope, no boardgo)
    W.hop(110)
    check("[new] the game takes the speed back for 0.3 s: given AGAIN at each reading until it sticks -- with the parts looked up as he landed (still one look), 7 parts each time",
        W.took and speedKicks(W) == 3 and W.count("given AGAIN: the game had taken it back (7 parts)") == 2 and W.partCalls == 1, W)
end
do local W = world({ go = 0 }) W.vel = { X = 460, Y = 0, Z = 0 }
    W.speedFn = function(w) return (w.mountT and w.t - w.mountT > 0.3) and (w.given or 0) or 0 end
    W.rideFirst() W.onFoot() W.took = W.N.hopTry("L3") == true
    for _ = 1, 40 do W.tick(1) if speedKicks(W) >= 1 then break end end           -- the first kick, with the parts looked up as he landed
    W.flipper.dead = true W.tick(80)                                            -- then the deck those parts were looked up on is gone
    check("...and when that deck no longer lives the list is not used: the parts are looked up afresh for each of the two later kicks (" .. W.partCalls .. " looks for " .. speedKicks(W) .. " kicks; the input file looks at every kick anyway)",
        W.took and W.onboard and speedKicks(W) == 3 and W.partCalls == 3, W)
end

-- =================================================================== D. the landing height
out[#out + 1] = "--- D. the landing height: level ground only, the lift, still in the air"
do local W = world({}) W.rideFirst()
    for _ = 1, 12 do W.deck.upz = 0.766 W.loc.Z = W.deck.z + 65 W.N.hopMeasure() end      -- 24 s on a 40 deg bank: 85 cm along the board's up reads 65
    W.deck.upz = 1 W.onFoot() W.took = W.N.hopTry("L3") == true
    local l = W.line("board hop (L3)") or ""
    check("[new] riding height read 85 on the flat, then twelve readings of 65 on a 40 deg bank: the hop still lands at 85 + 3 -- 'landing 88 cm over the deck (measured on level ground, and BoardHopLandLift 3 over it)'",
        W.took and l:find("landing 88 cm over the deck (measured on level ground, and BoardHopLandLift 3 over it)", 1, true) ~= nil, W)
    check("[new] ...and the same line has his standing height: 'you stand 85 cm over the deck's level'", l:find("; you stand 85 cm over the deck's level", 1, true) ~= nil, W)
    W.tick(100)
    local last = W.moves[#W.moves] or {}
    check(string.format("[new] the arc ends 88 cm over the deck (%.1f), its first tick 3 cm or more over where he stood (%.1f)", (last[3] or 0) - W.deck.z, (W.moves[1] and W.moves[1][3] or 0) - 95),
        near((last[3] or 0) - W.deck.z, 88, 0.6) and ((W.moves[1] and W.moves[1][3] or 0) - 95) >= 2.9, W)
    local al = W.line("as you land") or ""
    check("[new] the engine's own landing does not cut in on the way down ('on 0 frames on the way down'), he is mounted from the air ('the game has you in the air') and the model's engine landed him once only, at the take-off",
        al:find("the game has you in the air; its own landing cut in on 0 frames on the way down (1 at the take-off; put back in the air the first two times of each)", 1, true) ~= nil and W.landings == 1 and W.fromAir == true and W.mcalls[1].mm == 3, W)
    out[#out + 1] = "       " .. l:sub(1, 400)
end
do local W = world({}) W.rideFirst()                                                        -- the level reading that strays from the average is said
    W.loc.Z = W.deck.z + 78 W.N.hopMeasure()
    local l = W.line("riding height read") or ""
    check("[new] a LEVEL reading more than 4 cm off the average is said, with both: 'riding height read 78 cm on level ground, the average stands at 85' -- and the average then moves as it did (83.6)",
        l == "board hop: riding height read 78 cm on level ground, the average stands at 85" and W.count("riding height read") == 1, W)
    W.wait(2) W.loc.Z = W.deck.z + 70 W.N.hopMeasure() W.wait(2) W.N.hopMeasure()
    check("[new] ...once in 20 s at the most (two more such readings 2 and 4 s on: no second line)", W.count("riding height read") == 1, W)
    W.wait(20) W.N.hopMeasure()
    check("[new] ...and again after that (24 s on: a second line)", W.count("riding height read") == 2, W)
    W.wait(30) W.deck.upz = 0.9 W.loc.Z = W.deck.z + 60 W.N.hopMeasure()
    check("[new] a reading on a slope is neither taken nor said, however far off", W.count("riding height read") == 2, W)
    -- the stamp of the last line is kept over a hop (hopTry makes the hop's table anew)
    W.deck.upz = 1 W.loc.Z = W.deck.z + 85 W.wait(30) W.N.hopMeasure()
    local n = W.count("riding height read")
    W.onFoot() W.tc = W.t W.took = W.N.hopTry("L3") == true W.tick(100)
    W.mode = 1 W.loc.Z = W.deck.z + 60 W.N.hopMeasure()
    check(string.format("[new] ...and the 20 s are counted over a hop too (a line just before it, none %d ms after: %d lines then, %d now)", math.floor((W.t - W.tc) * 1000), n, W.count("riding height read")),
        W.took and W.onboard and n >= 3 and W.count("riding height read") == n, W)
end
do local W = world({}) W.rideFirst()                                                        -- round a drop-in the riding height is not read at all
    W.dropNow = true
    for _ = 1, 12 do W.loc.Z = W.deck.z + 60 W.N.hopMeasure() end
    W.dropNow = false W.onFoot() W.took = W.N.hopTry("L3") == true
    check("[new] while a drop-in is being set up or held (NATIVE.dropBusy) the riding height is not read, level deck or not: twelve readings of 60 change nothing -- 'landing 88 cm over the deck', and no 'riding height read' line",
        W.took and (W.line("board hop (L3)") or ""):find("landing 88 cm over the deck (measured on level ground", 1, true) ~= nil and W.count("riding height read") == 0, W)
end
do local W = world({}) W.onboard, W.mode, W.mm, W.cm = true, 1, 6, 1
    W.deck.upz = 0.766 W.loc.Z = W.deck.z + 65 W.chestRel = W.side * 90 W.N.hopMeasure()
    check("[new] a first reading on a bank is not taken: no 'the skater rides' line (the toe side is read all the same)", W.has("the skater rides") == nil and W.has("your toes point to the left") ~= nil, W)
    W.deck.upz = 1 W.onFoot() W.took = W.N.hopTry("L3") == true
    check("[new] ...and a hop then says 'landing 98 cm over the deck (not measured yet: BoardHopRideZ, and BoardHopLandLift 3 over it)'",
        W.took and (W.line("board hop (L3)") or ""):find("landing 98 cm over the deck (not measured yet: BoardHopRideZ, and BoardHopLandLift 3 over it)", 1, true) ~= nil, W)
end
do local W = world({ set = { BoardHopLandLift = 0 } }) W.hop(100)
    local last = W.moves[#W.moves] or {}
    check("BoardHopLandLift 0: the arc ends at the riding height, 85 over the deck, as build 211's did", W.took and near((last[3] or 0) - W.deck.z, 85, 0.6), W)
end
do local W = world({}) W.rideFirst() W.onFoot() W.mm = 3 W.loc.Z = W.deck.z + W.stand + 20            -- his own on-foot jump: in the air at the click
    W.took = W.N.hopTry("L3") == true
    check("in the air at the click (his own jump): no 'you stand' in the line", W.took and (W.line("board hop (L3)") or ""):find("you stand", 1, true) == nil, W)
end
do local W = world({}) W.rideFirst() W.onFoot() W.tc = W.t
    W.forceWalk = function(w) local k = (w.t - w.tc) / 0.45 return k > 0.62 and k < 0.72 end          -- the engine lands him by itself for a few frames of the way down
    W.took = W.N.hopTry("L3") == true W.tick(100)
    local al = W.line("as you land") or ""
    local n = tonumber(al:match("cut in on (%d+) frames on the way down")) or -1
    local re = 0 for _, s in ipairs(W.setMM) do if s.m == 3 and s.t - W.tc > 0.45 * 0.6 then re = re + 1 end end
    check(string.format("[new] the engine's landing on the way down is counted apart from the take-off (seen on %d ticks of the way down) and he is put back in the air the first two times (%d times), no more; it lets go of him again and he is mounted from the air", n, re),
        W.took and n >= 2 and re == 2 and al:find("(1 at the take-off; put back in the air the first two times of each)", 1, true) ~= nil and W.mcalls[1] and W.mcalls[1].mm == 3, W)
end
do local W = world({}) W.rideFirst() W.onFoot() W.tc = W.t
    W.forceWalk = function(w) return (w.t - w.tc) / 0.45 > 0.62 end                                    -- the arc ends inside something: the engine lands him at every frame from there on
    W.took = W.N.hopTry("L3") == true W.tick(100)
    local al = W.line("as you land") or ""
    local n = tonumber(al:match("cut in on (%d+) frames on the way down")) or -1
    local re = 0 for _, s in ipairs(W.setMM) do if s.m == 3 and s.t - W.tc > 0.45 * 0.6 then re = re + 1 end end
    check(string.format("[new] where the arc ends inside something the engine is NOT fought every tick: seen walking on %d ticks of the way down, put back in the air twice (%d), then left -- build 211's one landing; he is mounted all the same, 'the game has you in movement mode 1'", n, re),
        W.took and W.onboard and n >= 5 and re == 2 and al:find("the game has you in movement mode 1;", 1, true) ~= nil and W.mcalls[1] and W.mcalls[1].mm == 1, W)
    out[#out + 1] = "       " .. al:sub(al:find("the game has you", 1, true) or 1, -1)
end
do local W = world({}) W.rideFirst() W.onFoot() W.tc = W.t
    W.forceWalk = function(w) return (w.t - w.tc) / 0.45 < 0.3 end                                     -- the same at the take-off (hop 1 of 10 Oct: "walking" for 100 ms after the click)
    W.took = W.N.hopTry("L3") == true W.tick(100)
    local al = W.line("as you land") or ""
    local n0 = tonumber(al:match("%((%d+) at the take%-off")) or -1
    local re = 0 for _, s in ipairs(W.setMM) do if s.m == 3 and s.t > W.tc + 0.001 and s.t - W.tc < 0.45 * 0.5 then re = re + 1 end end
    check(string.format("[new] ...and the take-off has its own two: seen walking on %d ticks there, put back in the air twice (%d); 0 on the way down, mounted from the air", n0, re),
        W.took and W.onboard and n0 >= 3 and re == 2 and al:find("cut in on 0 frames on the way down", 1, true) ~= nil and W.mcalls[1] and W.mcalls[1].mm == 3, W)
end

-- =================================================================== E. the turn held in the mesh
out[#out + 1] = "--- E. BoardHopTurnHold: the body's turn carried by the mesh (regular: he faces 0, the board's nose points 0, toes left: the chest -90)"
local function hold(th, order, o)
    o = o or {} o.order = order or 2 o.set = o.set or {} o.set.BoardHopTurnHold = th
    local W = world(o) W.vel = { X = 300, Y = 0, Z = 0 }
    return W
end
-- how far from the planned chest the body is drawn, from the arc's last two frames (he has turned there by then) to 0.3 s after the mount;
-- and the biggest turn of the capsule in one write
local function drawnOff(W, chest)
    local worst, at = 0, nil
    for fr, d in pairs(W.drawn) do
        if W.mountT and d.t > W.mountT - 0.03 and d.t < W.mountT + 0.3 then
            local e = math.abs(wrap(d.chest - chest))
            if e > worst then worst, at = e, (d.t - W.mountT) * 1000 end
        end
    end
    return worst, at
end
local function capStep(W) local m = 0 for _, mv in ipairs(W.moves) do if mv.step > m then m = mv.step end end return m end
local function loggedOff(W, chest) local worst = 0 for _, e in ipairs(W.frames()) do if e.t then worst = math.max(worst, math.abs(wrap(e.t - chest))) end end return worst end
do
    local W0 = hold(0, 2).hop(100)
    local w0, a0 = drawnOff(W0, -90)
    check(string.format("BoardHopTurnHold 0 (build 211): the capsule turns %.0f deg in one write (the last frame), the mesh's yaw is never written, and in the model the body is drawn %.0f deg off the planned chest at %+.0f ms: the flick the hold is against",
        capStep(W0), w0, a0 or 0), W0.took and W0.onboard and capStep(W0) > 80 and W0.meshWrites == 0 and w0 > 70, W0)
    local W1 = hold(1, 2).hop(100)
    local w1 = drawnOff(W1, -90)
    check(string.format("[new] BoardHopTurnHold 1: the capsule never turns more than %.1f deg in one write (he hops on the way he ran: it hardly turns at all), and the body is drawn within %.1f deg of the planned chest from the arc through the game's blend",
        capStep(W1), w1), W1.took and W1.onboard and capStep(W1) < 5 and W1.relMax > 80 and w1 < 8, W1)
    -- the body's facing through the arc is build 211's: from where he faced (0) to the chest's side (-90), eased
    local worst = 0
    for _, b in ipairs(W1.body) do
        local k = (b.t - W1.tc) / 0.45
        if k > 0 and k < 1 then worst = math.max(worst, math.abs(wrap(b.cap + b.rel - (-90 * smooth(k))))) end
    end
    check(string.format("[new] ...and his facing through the arc (capsule + mesh) is build 211's own, to %.2f deg", worst), W1.relMax > 80 and worst < 0.05, W1)
    local fin = W1.body[#W1.body]
    local back = nil for _, b in ipairs(W1.body) do if W1.mountT and b.t > W1.mountT and math.abs(wrap(b.rel)) < 0.01 then back = (b.t - W1.mountT) * 1000 break end end
    check(string.format("[new] the mesh is back on its base %s ms after the mount (the game's blend is 150), the yaw watch's stamp is taken away, and it stood ahead of the clock while the mesh was turned",
        tostring(back and math.floor(back + 0.5))), W1.relMax > 80 and back and back > 140 and back < 200 and math.abs(wrap(fin.rel)) < 0.01 and W1.stamp() == nil
        and (function() for _, b in ipairs(W1.body) do if math.abs(wrap(b.rel)) > 1 and not (b.stamp and b.stamp > b.t) then return false end end return true end)(), W1)
    local W2 = hold(2, 2).hop(100)
    local w2 = drawnOff(W2, -90)
    local same, early = #W2.moves == #W0.moves, 0
    for i = 1, math.min(#W2.moves, #W0.moves) do if not nearA(W2.moves[i][4], W0.moves[i][4], 0.001) then same = false end end
    for _, b in ipairs(W2.body) do if b.t < W2.tc + 0.44 and math.abs(wrap(b.rel)) > 0.01 then early = early + 1 end end
    check(string.format("[new] BoardHopTurnHold 2: the capsule flies exactly as with 0 (%d writes, the same yaws), the mesh is not touched before the last frame and then takes the quarter turn; the body is drawn within %.1f deg of the planned chest",
        #W2.moves, w2), W2.took and W2.onboard and same and early == 0 and W2.relMax > 80 and w2 < 8 and W2.stamp() == nil and math.abs(wrap(W2.rel.Yaw)) < 0.01, W2)
    -- the other order of a frame: the loop before the game's own step
    local V0, V1, V2 = hold(0, 1).hop(100), hold(1, 1).hop(100), hold(2, 1).hop(100)
    local v0, v1, v2 = drawnOff(V0, -90), drawnOff(V1, -90), drawnOff(V2, -90)
    check(string.format("[new] with the loop BEFORE the game's step in a frame the hold's clock is a frame late: the body is drawn up to %.0f deg (hold 1) / %.0f deg (hold 2) off for a frame or two mid-blend, against %.0f with no hold",
        v1, v2, v0), V1.took and V2.took and V1.relMax > 80 and v1 < 25 and v2 < 25 and v0 > 70, V1)
    -- the frame lines' own t column
    local l0, l1 = loggedOff(W0, -90), loggedOff(W1, -90)
    check(string.format("[new] the frame lines show it: column t strays %.0f deg from the planned chest with no hold and %.0f with the hold (the PASS line is 'within about 20')", l0, l1),
        #W1.frames() > 20 and l0 > 70 and l1 < 25, W1)
end
do  -- a switch hop: he faces -150, the board behind him, nose 0: tail-first switch, the capsule ends on 0, the chest -90, handed over at 180
    local function sw(th, order, hs) local W = hold(th, order, { set = { BoardHopTurnHoldSwitch = hs } }) W.yaw = -150 W.deck.x = -150 W.vel = { X = -300, Y = 0, Z = 0 } return W.hop(100) end
    local W0, Wd, W1 = sw(0, 2), sw(1, 2), sw(1, 2, 1)
    local w0, wd, w1 = drawnOff(W0, -90), drawnOff(Wd, -90), drawnOff(W1, -90)
    local same = #Wd.moves == #W0.moves
    for i = 1, math.min(#Wd.moves, #W0.moves) do if not nearA(Wd.moves[i][4], W0.moves[i][4], 0.001) then same = false end end
    check(string.format("a switch hop as the file ships (BoardHopTurnHold 1, BoardHopTurnHoldSwitch 0) is NOT held, as in build 211 (not marked as new: the input file holds nothing either; the first pass of this step held it): it flies exactly as with the hold off (%d writes of the capsule, the same yaws), the mesh's yaw is never written, no stamp for the yaw watch",
        #Wd.moves), Wd.took and Wd.onboard and Wd.line("riding tail-first switch") ~= nil and same and Wd.meshWrites == 0 and Wd.relMax == 0 and Wd.stamp() == nil
        and (function() for _, b in ipairs(Wd.body) do if b.stamp ~= nil then return false end end return true end)() and Wd.after.foot == 4 and nearA(Wd.after.capsule, 0, 0.01), Wd)
    -- what its frame lines are for: which way the game turns the snapshot in its own half turn of the capsule. In this model it
    -- turns it WITH the capsule, so on the first riding entry the toes stand at the yaw handed over (180), not at the riding yaw (0)
    local fe = nil for _, e in ipairs(Wd.frames()) do if e.mode == "6/1" then fe = e break end end
    local lg = Wd.line("board hop:    frames") or ""
    local hy, ry = lg:match("the capsule was handed to the mount at (%-?%d+) and rides at (%-?%d+)%)")
    check(string.format("[new] ...and its frame lines say so and carry the two yaws to read column t against (handed to the mount at %s, rides at %s); in this model the first riding entry has t %s (the yaw handed over: the snapshot turned with the capsule)", tostring(hy), tostring(ry), tostring(fe and fe.t)),
        lg:find("frames (BoardHopTurnHold not used -- a switch hop without BoardHopTurnHoldSwitch), ms from the mount call", 1, true) ~= nil
        and nearA(tonumber(hy), 180, 0.5) and nearA(tonumber(ry), 0, 0.5) and fe ~= nil and nearA(fe.t, 180, 2), Wd)
    check(string.format("[new] with BoardHopTurnHoldSwitch 1 a switch hop is held (handed over at 180, the game turns the capsule to 0 and, in this model, the snapshot half a turn): BoardHopSwitchFix as it was -- capsule %s, foot position %s -- and the body drawn within %.1f deg of the planned chest with the hold, %.0f off without",
        tostring(W1.after and wrap(W1.after.capsule)), tostring(W1.after and W1.after.foot), w1, w0),
        W1.took and W1.line("riding tail-first switch") ~= nil and nearA(W1.mcalls[1] and W1.moves[#W1.moves][4], 180, 0.01) and nearA(W1.after.capsule, 0, 0.01) and W1.after.foot == 4 and nearA(W1.after.deck, 0)
        and W1.relMax > 80 and w1 < 8 and w0 > 70 and wd > 70 and capStep(W1) < 40, W1)
end
out[#out + 1] = "--- E. every way out of the hop takes the turn out of the mesh"
local function exits(name, setup, during, piece)
    local W = hold(1, 2, setup) W.rideFirst() W.onFoot() W.tc = W.t W.took = W.N.hopTry("L3") == true
    if during then during(W) else W.tick(100) end
    check("[new] " .. name .. ": the mesh was turned and is back on its base, the yaw watch's stamp is gone, a new hop can be taken",
        W.took and W.relMax > 30 and math.abs(wrap(W.rel.Yaw)) < 0.01 and W.stamp() == nil and (piece == nil or W.has(piece) ~= nil)
        and (function() W.err = nil W.onFoot() W.loc = { X = W.deck.x - 100, Y = W.deck.y, Z = W.deck.z + W.stand } return W.N.hopTry("again") == true end)(), W)
end
exits("the native half refuses the mount", { refuse = true }, nil, "the native half refused the mount")
exits("the game never mounts him", { mountsOk = false }, nil, "the game did not mount you")
exits("a bail right after the mount", {}, function(W) W.tick(29) W.mode = 5 W.tick(60) end, "a bail or a drop-in")
exits("off the board again inside the blend", {}, function(W) W.tick(30) W.onboard = false W.tick(60) end, "off the board again")
exits("an error in the watch", {}, function(W) W.dropFails = true W.tick(60) W.dropFails = false end, "board hop: error, the hop is dropped")
exits("an error in the arc", {}, function(W) W.tick(15) W.S.BoardHopTime = "x" W.tick(5) W.S.BoardHopTime = 0.45 W.tick(40) end, "board hop: error, the hop is dropped")
do local W = hold(1, 2) W.rideFirst() W.onFoot() W.tc = W.t W.took = W.N.hopTry("L3") == true
    W.tick(30) local n0, rel0 = W.meshWrites, W.rel.Yaw
    W.setActive(true) W.tick(20)
    check(string.format("[new] a hippie jump of his own inside the blend (the mod's 'active'): the hop takes its turn out of the mesh (it stood at %+.0f deg) and lets go at once -- one write that puts it on its base, no more of its own, no stamp", wrap(rel0)),
        W.took and W.onboard and math.abs(wrap(rel0)) > 30 and W.meshWrites == n0 + 1 and math.abs(wrap(W.rel.Yaw)) < 0.01 and W.stamp() == nil, W)
end
for _, th in ipairs({ 1, 2 }) do for _, n in ipairs({ 1, 4, 8 }) do                     -- (the first pass let go without putting it back: up to 88 deg stood in the mesh for the whole jump)
    local W = hold(th, 2) W.rideFirst() W.onFoot() W.tc = W.t W.took = W.N.hopTry("L3") == true
    local guard = 0
    while not W.onboard and guard < 200 do W.tick(1) guard = guard + 1 end
    W.tick(n) W.setActive(true) W.tick(40)
    check(string.format("[new] ...BoardHopTurnHold %d, the jump started %d frames after the mount: nothing of the hop's is left in the mesh while the jump runs (%.1f deg)", th, n, wrap(W.rel.Yaw)),
        W.took and W.onboard and W.relMax > 80 and math.abs(wrap(W.rel.Yaw)) < 0.01 and W.stamp() == nil, W)
end end
do  -- the yaw watch itself, as it stands in the file
    local rel, puts, t = { Yaw = 0, Pitch = 0, Roll = 0 }, 0, 500
    local genv = setmetatable({ os = setmetatable({ clock = function() return t end }, { __index = os }) }, { __index = _G })
    local N = { rawMode = function() return 0 end }
    local gfn = assert(load("local mesh, NATIVE, q, addr, log, modeNow, MODE_RIDING, MODE_AIR, VS, S, stanceSwap, YS, BY, RV, BV, wrap180 = ...\nlocal active, yaw0 = false, 0\n" .. guardSrc .. "\nreturn NATIVE.yawGuard", "=guard", "t", genv))
    local glog = {}
    local guard = gfn({ RelativeRotation = rel, K2_SetRelativeRotation = function(_, r) rel.Yaw = r.Yaw puts = puts + 1 end }, N,
        function(fn, d) local ok, v = pcall(fn) if ok and v ~= nil then return v end return d end, function() return 1 end, function(s) glog[#glog + 1] = s end,
        function() return 0 end, 1, 2, { on = false }, { SwitchLanding = 0 }, function() end, {}, {}, {}, {}, wrap)
    guard()                                                                    -- the mesh as first seen: its base
    rel.Yaw = -90                                                              -- the hop's turn
    for _ = 1, 40 do t = t + 1 / 60 N.hopTurnUntil = t + 0.3 guard() end           -- 0.67 s of a hop renewing its stamp
    check("[new] the yaw watch stands back while a hop holds the turn (0.67 s under the stamp: the mesh is left at -90)", puts == 0 and rel.Yaw == -90, { logs = glog })
    local tEnd = t
    for _ = 1, 40 do t = t + 1 / 60 guard() if puts > 0 then break end end        -- the hop died: nothing renews the stamp
    check(string.format("[new] a hop that dies leaves a stamp that runs out: the watch puts the mesh back %.2f s on (0.3 s of stamp and its own quarter second)", t - tEnd), puts == 1 and rel.Yaw == 0 and t - tEnd > 0.5 and t - tEnd < 0.62, { logs = glog })
end

-- =================================================================== F. the frame lines and the recorder
out[#out + 1] = "--- F. the frame lines (BoardHopRecord) and the pose recorder over the hop (BoardHopPoses)"
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.hop(110)
    local F = W.frames()
    local parsed, dup, modes = 0, 0, {}
    for i, e in ipairs(F) do if e.ms and e.z and e.c and e.d then parsed = parsed + 1 end modes[e.mode or "?"] = true if i > 1 and e.ms == F[i - 1].ms then dup = dup + 1 end end
    local first, last = F[1] or {}, F[#F] or {}
    local spanFrames = math.floor(((last.ms or 0) - (first.ms or 0)) / 1000 * 60 + 0.5) + 1
    check(string.format("[new] the hop writes its frame lines when the watch ends: a legend and %d entries from %+.0f to %+.0f ms, every one read back whole, one a frame of the game (%d frames in that span; the loop ran %d times)",
        #F, first.ms or 0, last.ms or 0, spanFrames, #W.body), W.count("board hop:    frames (BoardHopTurnHold 1), ms from the mount call") == 1 and #F > 30 and parsed == #F and dup == 0 and math.abs(#F - spanFrames) <= 2 and #W.body > #F + 15, W)
    check("[new] the columns: in the air 3/0 before the mount and riding 6/1 after, the capsule never under 85 over the deck and 85 riding, the mesh's turn and the toes read on every entry, foot position 1",
        modes["3/0"] and modes["6/1"] and near(last.z, 85, 1) and last.f == "1"
        and (function() for _, e in ipairs(F) do if not e.z or e.z < 84.5 or not e.m or not e.t then return false end end return true end)(), W)
    local riding = {} for _, e in ipairs(F) do if e.ms > 150 and e.v then riding[#riding + 1] = e.v end end
    table.sort(riding)
    check(string.format("[new] column v: riding off at 552 cm/s reads %s to %s (the game's own clock between two entries)", tostring(riding[1]), tostring(riding[#riding])), #riding > 10 and near(riding[1], 552, 6) and near(riding[#riding], 552, 6), W)
    out[#out + 1] = "       " .. (W.line("board hop:    frames") or ""):sub(1, 600)
    out[#out + 1] = "       " .. (W.logs[(W.has("board hop:    frames") or 0) + 4] or ""):sub(1, 700)
end
do local W = world({ noClock = true }) W.vel = { X = 460, Y = 0, Z = 0 } W.hop(110)
    local F, close = W.frames(), 0
    for i = 2, #F do if F[i].ms - F[i - 1].ms < 11 then close = close + 1 end end
    check(string.format("[new] the game's clock cannot be read: entries all the same, 12 ms apart at the least (%d entries, %d closer than that)", #F, close), #F > 30 and close == 0, W)
end
do local W = world({ set = { BoardHopRecord = 0 } }) W.hop(110)
    check("BoardHopRecord 0: no frame lines", W.took and W.onboard and W.count("board hop:    frames") == 0 and #W.frames() == 0, W)
end
do local W = world({}) W.hop(110)
    local tr = W.traces[1] or {}
    check("[new] the pose recorder is opened at the click: HJN_TrickTrace(120, 'board hop 1 nose-first reg')", #W.traces == 1 and tr.n == 120 and tr.tag == "board hop 1 nose-first reg", W)
    for i = 2, 9 do W.onFoot() W.loc = { X = W.deck.x - 100, Y = W.deck.y, Z = W.deck.z + W.stand } W.yaw = 0 W.N.hopTry("L3") W.tick(110) end
    check(string.format("[new] ...for the first 8 hops of a run and no more (9 hops: %d traces, the last one '%s')", #W.traces, tostring(W.traces[#W.traces] and W.traces[#W.traces].tag)),
        #W.traces == 8 and W.traces[8].tag == "board hop 8 nose-first reg", W)
    local Ws = world({}) Ws.yaw = -150 Ws.deck.x = -150 Ws.hop(110)
    check("[new] a switch hop's tag says 'sw', not 'switch' (the native half would log every pose)", #Ws.traces == 1 and Ws.traces[1].tag == "board hop 1 tail-first sw" and not Ws.traces[1].tag:find("switch", 1, true), Ws)
    local Wn, Wt = world({ set = { BoardHopPoses = 0 } }).hop(60), world({ set = { TraceLog = 0 } }).hop(60)
    check("BoardHopPoses 0, or TraceLog 0: the recorder is not opened", Wn.took and Wt.took and #Wn.traces == 0 and #Wt.traces == 0, Wn)
end

-- =================================================================== G. what must work as it did
out[#out + 1] = "--- G. BoardHopSwitchFix, BoardHopSpeedScale and BoardHopSpeedAcross work as they did"
do local W = world({}) W.vel = { X = 460, Y = 0, Z = 0 } W.deck.yaw = 90 W.hop(110)                       -- a run square to the board
    local k = W.kicks[1]
    check("a run at 460 square to the board, BoardHopSpeedAcross 0.5 x BoardHopSpeedScale 1.2: 276 along the board, nothing across it", W.took and k and near(math.abs(k[2]), 276, 2) and near(k[1], 0, 2), W)
    W = world({ set = { BoardHopSpeedScale = 0 } }) W.vel = { X = 460, Y = 0, Z = 0 } W.hop(110)
    check("BoardHopSpeedScale 0 and a still board: nothing given", W.took and W.onboard and speedKicks(W) == 0 and W.has("nothing given") ~= nil, W)
    local function sw(fix) local V = world({ set = { BoardHopSwitchFix = fix } }) V.yaw = -150 V.deck.x = -150 V.hop(110) return V end
    local W1, W0 = sw(1), sw(0)
    check("a switch hop, BoardHopSwitchFix 1: handed over at 180 with flip flag 1 (tail-first), the capsule ends on the plan (0), the deck's nose kept, switch kept",
        W1.took and W1.mcalls[1].sw == 1 and W1.mcalls[1].flip == 1 and nearA(W1.moves[#W1.moves][4], 180, 0.01) and nearA(W1.after.capsule, 0, 0.01) and nearA(W1.after.deck, 0) and W1.after.foot == 4, W1)
    check("...BoardHopSwitchFix 0 (build 210): handed over at 0 with flip flag 0, the capsule ends half a turn from the plan, the deck's nose kept",
        W0.took and W0.mcalls[1].sw == 1 and W0.mcalls[1].flip == 0 and nearA(W0.moves[#W0.moves][4], 0, 0.01) and nearA(W0.after.capsule, 180, 0.01) and nearA(W0.after.deck, 0), W0)
end

out[#out + 1] = string.format("%d checks", nchecks)
local o = assert(io.open("hop212_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the board hop's build 212 test failed: see hop212_out.txt", 0) end

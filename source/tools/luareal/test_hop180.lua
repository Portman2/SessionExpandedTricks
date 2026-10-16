-- test_hop180.lua (build 211): the board hop's four cases (nose-first / tail-first x regular / switch) through the mod's
-- own hop code, cut out of main.lua and run in real Lua: the yaw handed to the game's mount, the flip flag, and where the
-- game's mount then leaves the capsule and the deck -- with BoardHopSwitchFix 1 and 0. Also the chest side's five
-- readings in a row (test_hop180.lua counted to three: build 211 before its review; made by mk_test_hop180_five.pl).
--   luareal -run test_hop180_five.lua result.txt main.lua   (writes hop180_out.txt)
-- THE GAME'S MOUNT HERE IS A MODEL of what the exe was read to do (finding_hop180 and its checker):
--   ApplyToggleOnBoard: pending foot position 4 (switch) turns the capsule half a turn (0xfeaca0), then
--   SnapToGround: the board is turned to the capsule, and half a turn more when IsSkatingSwitch ~= the flip flag;
--   AdjustFootPositionAndMoveDirection (50 cm/s and up): rolling along the capsule's forward makes 4 -> 3 and 2 -> 1,
--   against it 1 -> 2 and 3 -> 4.
-- It shows that the hop's numbers are consistent with that reading; only the game can show the reading is right.
-- Run against build 210's main.lua (no BoardHopSwitchFix in it) it expects 9 Oct's result instead: the half turn.
-- (build 212, mk_test212_hop.pl) main.lua's BD is stood in for; no check is changed. The six settings of build 212 are
-- not in S below -- unset = off, the hop as build 211 flew it; test_hop212.lua runs what the file ships.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("    local HOP = { on = false, rideZ = nil", 1, true), "the hop's start was not found")
local b = assert(src:find("\nend\n\n-- THE DROP-IN (v98)", a, true), "the hop's end was not found")
local body = src:sub(a, b)
local B211 = src:find("BoardHopSwitchFix", 1, true) ~= nil

local function wrap(x) return x - 360 * math.floor(x / 360 + 0.5) end
local function same(x, y, tol) return math.abs(wrap(x - y)) < (tol or 0.01) end
local function world(o)
    local W = { kicks = {}, logs = {}, moves = {}, vel = { X = 0, Y = 0, Z = 0 }, mesh = -1, t = 100, toe = { 0, 10 },
                loc = { X = 0, Y = 0, Z = 100 }, yaw = 0, deck = { x = 120, y = 0, z = 10, yaw = 0 }, onboard = false, pending = false, mode = 0, foot = 0, dof = 0 }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.HJN_BoardState = function() return (W.onboard and 4 or 1) | (8 << 4) end
    env.HJN_DeckWorld = function() return string.format("%.2f %.2f %.2f %.2f 1.000", W.deck.x, W.deck.y, W.deck.z, W.deck.yaw) end
    env.HJN_DeckAxes = function() local r = math.rad(W.deck.yaw) return string.format("%.4f %.4f %.4f 0 0 1", math.cos(r), math.sin(r), 0) end
    env.HJN_BoardMount = function(sw, flip) W.msw, W.mflip = sw, flip return 1 end
    env.HJN_BoardRagdoll = function() return 1 end
    env.HJN_BoardParts = function(...) return select("#", ...) end
    env.HJN_BoardKick = function(x, y) local n = math.sqrt(x * x + y * y) W.kicks[#W.kicks + 1] = { x, y } W.given = n W.kdir = { x / math.max(1e-6, n), y / math.max(1e-6, n) } return 7 end
    env.HJN_MeshSpeed = function() return W.mesh end
    env.HJN_CtrlYaw = function() return string.format("%.1f %d 0", 0, W.dof) end
    env.HJN_Set = function() return 0 end
    env.LoopAsync = function(_, fn) W.loop = fn end
    env.BD = { comp = nil }                              -- (build 212) main.lua's own BD, as the hop's block reads it
    env.fname = function(s) return s end
    env.mesh = { GetSocketLocation = function(_, n) if n:find("Toe", 1, true) then return { X = W.toe[1], Y = W.toe[2], Z = 0 } end return { X = 0, Y = 0, Z = 0 } end }
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    local S = { BoardHop = 1, BoardHopRange = 250, BoardHopTime = 0.45, BoardHopHeight = 40, BoardHopRideZ = 95,
                BoardHopSpeedScale = 1.2, BoardHopSpeedAcross = 0.5, BoardHopSwitchFix = W.fix }
    local q = function(fn, d) local ok, r = pcall(fn) if ok then return r end return d end
    local s0 = {
        K2_GetActorLocation = function() return W.loc end,
        K2_GetActorRotation = function() return { Pitch = 0, Yaw = wrap(W.yaw), Roll = 0 } end,
        K2_SetActorLocationAndRotation = function(_, p, r) W.moves[#W.moves + 1] = { p.X, p.Y, p.Z, r.Yaw } W.loc = { X = p.X, Y = p.Y, Z = p.Z } W.yaw = r.Yaw end,
        IsOnBoard = function() return W.onboard end,
        SetPendingApplyToggleOnBoard = function() W.pending = true end,
        GetCurrentFootPosition = function() return W.foot end,
        IsSkatingSwitch = function() return W.foot == 4 or W.foot == 2 end,
    }
    local mv = setmetatable({ GetCurrentSpeed = function() return W.given or 0 end, SetMovementMode = function() end },
        { __index = function(_, k) if k == "Velocity" then return W.vel end end, __newindex = function() end })
    local NATIVE = { live = true, boardParts = function() return { 1, 2, 3, 4, 5, 6, 7 } end, dropBusy = function() return false end, gt = function(fn) fn() end }
    local chunk = "local S, q, s0, mv, log, modeNow, MODE_RIDING, MODE_BAILING, NATIVE, alive, refs, NAT = ...\n" .. body .. "\nreturn NATIVE"
    local fn = assert(load(chunk, "=hop", "t", env))
    local function log(s) W.logs[#W.logs + 1] = s if s:find("board hop: error", 1, true) then W.err = s end end
    W.N = fn(S, q, s0, mv, log, function() return W.mode end, 1, 5, NATIVE, function(x) return x end, function() return true end, { goofy = W.goofy == true })
    W.tick = function(n)
        for _ = 1, (n or 1) do
            W.t = W.t + 0.0125
            if W.pending then W.pending = false
                W.handed, W.airYaw, W.deckWas = W.yaw, W.moves[#W.moves - 1][4], W.deck.yaw     -- as the mod left things for the mount
                local sw, flip = W.msw == 1, W.mflip == 1
                if sw then W.yaw = W.yaw + 180 end                                   -- ApplyToggleOnBoard, foot position 4
                W.deck.yaw = wrap(W.yaw + ((sw ~= flip) and 180 or 0))               -- SnapToGround
                W.dof = (sw ~= flip) and 180 or 0                                    -- ResetBoard's deck offset
                W.foot = sw and 4 or 1
                W.onboard = true W.mode = 1 W.given = 0
                W.capsule0, W.deck0, W.foot0 = W.yaw, W.deck.yaw, W.foot             -- right after the mount
            end
            if W.onboard and (W.given or 0) >= 50 and W.kdir then                    -- AdjustFootPositionAndMoveDirection
                local alongF = (W.kdir[1] * math.cos(math.rad(W.yaw)) + W.kdir[2] * math.sin(math.rad(W.yaw))) > 0
                if alongF then W.foot = (W.foot == 4) and 3 or ((W.foot == 2) and 1 or W.foot)
                else W.foot = (W.foot == 1) and 2 or ((W.foot == 3) and 4 or W.foot) end
            end
            local ok, err = pcall(W.loop)
            if not ok then W.err = "the loop itself raised: " .. tostring(err) end
        end
    end
    W.line = function(piece) for _, l in ipairs(W.logs) do if l:find(piece, 1, true) then return l end end return nil end
    return W
end
local out, all, nchecks = {}, true, 0
local function check(name, cond, W)
    nchecks = nchecks + 1
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then all = false
        out[#out + 1] = "       err " .. tostring(W and W.err)
        for _, l in ipairs(W and W.logs or {}) do out[#out + 1] = "       log: " .. l end
    end
    return cond
end

-- THE FOUR CASES. The deck's nose points D = 30; a regular rider (toes to the capsule's right). Where you face picks the case:
local D = 30
local CASES = {                                                   -- F, the click's own words, the roll H, switch, what the plan is
    { F = 60,   name = "nose-first regular", nose = true,  sw = false },
    { F = -100, name = "tail-first regular", nose = false, sw = false },
    { F = 0,    name = "nose-first switch",  nose = true,  sw = true },
    { F = 200,  name = "tail-first switch",  nose = false, sw = true },
}
-- what is handed over and what the flag is, per the checker's table (fix 1) and per build 210 (fix 0)
local function expect(c, fix)
    local H = c.nose and D or (D + 180)                           -- the way you roll
    local yc = c.sw and (H + 180) or H                            -- the capsule's yaw wanted on the board
    local e = { H = H, yc = yc }
    if fix ~= 0 then e.handed, e.flag = (c.sw and (yc + 180) or yc), (not c.nose)
    else e.handed, e.flag = yc, (c.sw ~= (not c.nose)) end
    return e
end
local function run(c, fix)
    local W = world({ fix = fix })
    W.yaw = c.F W.deck.yaw = D
    W.vel = { X = 460 * math.cos(math.rad(c.F)), Y = 460 * math.sin(math.rad(c.F)), Z = 0 }
    W.took = W.N.hopTry("L3") == true
    W.tick(40)                                                    -- the arc (0.45 s) and the mount
    W.mid = { capsule = W.capsule0, deck = W.deck0, foot = W.foot0 }
    W.tick(50)                                                    -- 0.5 s and more of riding
    return W
end
local modes = B211 and { 1, 0 } or { "210" }
for _, fix in ipairs(modes) do
    out[#out + 1] = (fix == "210") and "--- build 210's file (no BoardHopSwitchFix): 9 Oct's result is expected"
        or string.format("--- BoardHopSwitchFix %d%s", fix, (fix == 0) and " (build 210's yaw and flag: the half turn must be back, the A/B)" or "")
    for _, c in ipairs(CASES) do
        local fx = (fix == "210") and 0 or fix
        local W = run(c, (fix ~= "210") and fix or nil)
        local e = expect(c, fx)
        local tag = string.format("%s %s:", (fix == "210") and "b210" or ("fix " .. fix), c.name)
        local okRun = W.took and W.err == nil and W.onboard and W.handed ~= nil
        check(tag .. " the click says 'riding " .. c.name .. "' and the hop mounts", okRun and W.line("riding " .. c.name .. ",") ~= nil, W)
        if okRun then
            local chestAir, chestOn = W.airYaw, W.mid.capsule + 90      -- in the air the capsule's forward IS the chest; riding it is the toe side (+90 for these toes)
            out[#out + 1] = string.format("       handed %4.0f, flip flag %d, foot position %d | the game's mount: capsule ends %4.0f (planned %4.0f), deck nose ends %4.0f (was %d), deck offset %d | chest in the air %4.0f, on the board %4.0f",
                wrap(W.handed), W.mflip, W.msw == 1 and 4 or 1, wrap(W.mid.capsule), wrap(e.yc), wrap(W.mid.deck), D, W.dof, wrap(chestAir), wrap(chestOn))
            check(string.format("%s handed over at %.0f, flip flag %d, mounted as %s", tag, wrap(e.handed), e.flag and 1 or 0, c.sw and "switch (4)" or "regular (1)"),
                same(W.handed, e.handed) and (W.mflip == 1) == e.flag and (W.msw == 1) == c.sw, W)
            check(tag .. " the deck keeps its heading through the mount", same(W.mid.deck, D), W)
            if fx ~= 0 then
                check(tag .. " the capsule ends where it was planned, and the chest where it was in the air (no turn of the body)", same(W.mid.capsule, e.yc) and same(chestOn, chestAir, 3), W)
                check(tag .. " the speed goes the way you ride off (along H), and the game still says " .. (c.sw and "switch (4)" or "regular (1)") .. " half a second on",
                    W.kicks[1] and same(math.deg(math.atan(W.kicks[1][2], W.kicks[1][1])), e.H, 0.5) and W.foot == (c.sw and 4 or 1), W)
                if B211 then
                    local l1, l2 = W.line("facing on the first frame riding") or "", W.line("facing 0.5 s on") or ""
                    check(tag .. " the log's two facing lines say '+0 off' and 'turned +0', and switch " .. tostring(c.sw),
                        (l1:find("+0 off", 1, true) or l1:find("-0 off", 1, true)) and (l1:find("turned +0", 1, true) or l1:find("turned -0", 1, true))
                        and l2:find("the game says switch " .. tostring(c.sw) .. " (asked " .. tostring(c.sw) .. ")", 1, true) ~= nil, W)
                end
            else
                -- build 210 / fix 0: a switch hop is stood half a turn from the plan and from the air
                local off = c.sw and 180 or 0
                check(string.format("%s the capsule ends %d deg from the plan, the chest %d deg from where it was in the air", tag, off, off),
                    same(W.mid.capsule, e.yc + off) and same(chestOn, chestAir + off, 3), W)
                if B211 then
                    local l1, l2 = W.line("facing on the first frame riding") or "", W.line("facing 0.5 s on") or ""
                    local saysOff
                    if c.sw then saysOff = l1:find("180 off", 1, true) ~= nil else saysOff = (l1:find("+0 off", 1, true) or l1:find("-0 off", 1, true)) ~= nil end
                    check(tag .. " the log's first facing line says '" .. (c.sw and "180 off" or "0 off") .. "'" .. (c.sw and ", and half a second on the game has taken switch back" or ""),
                        saysOff and (not c.sw or l2:find("the game says switch false (asked true)", 1, true) ~= nil), W)
                end
            end
        end
    end
end

if B211 then
    -- THE DECK'S SIDE in the click's line: the chest in the air against the deck's own right (nose + 90), not the capsule's toe side
    out[#out + 1] = "--- the click's line: the deck's side"
    for _, c in ipairs(CASES) do
        local W = world({ fix = 1 }) W.yaw = c.F W.deck.yaw = D
        W.N.hopTry("L3") W.tick(36)
        local chest = W.moves[#W.moves - 1] and W.moves[#W.moves - 1][4] or 0          -- the capsule's yaw late in the air = the chest
        local right = math.abs(wrap(chest - (D + 90))) < 90
        check(string.format("%s: chest in the air at %.0f = the deck's %s side, and the line says so", c.name, wrap(chest), right and "right" or "left"),
            W.line("facing the deck's " .. (right and "right" or "left") .. " side in the air (your toes point to the right of the capsule") ~= nil, W)
    end

    -- THE CHEST SIDE: the first reading is taken, a new side only after five readings in a row
    out[#out + 1] = "--- the chest side while riding (hopMeasure, every 2 s)"
    local W = world({ fix = 1 }) W.mode = 1 W.onboard = true
    local function read(y) W.toe = { 0, y } W.N.hopMeasure() end
    local function said(side) local n = 0 for _, l in ipairs(W.logs) do if l:find("your toes point to the " .. side .. " of the way the capsule faces", 1, true) then n = n + 1 end end return n end
    read(10)
    check("the first reading (right) is taken at once", said("right") == 1 and said("left") == 0, W)
    read(-10)
    check("one reading of the other side (a powerslide) changes nothing", said("left") == 0, W)
    read(-10) read(-10)
    check("three lefts in a row change nothing either (9 Oct 23:20:31 to :37: a wrong side may have stood for three turns of the loop)", said("left") == 0 and said("right") == 1, W)
    read(-10) read(10)
    check("a fourth left, then a right: nothing, and the count starts again", said("left") == 0 and said("right") == 1, W)
    read(-10) read(-10) read(-10) read(-10)
    check("four lefts after that right: still nothing", said("left") == 0 and said("right") == 1, W)
    read(-10)
    check("the fifth left in a row is taken", said("left") == 1, W)
    read(10) read(10) read(10) read(10)
    check("four rights after that: not yet", said("right") == 1, W)
    read(10)
    check("the fifth right: taken again", said("right") == 2, W)
    -- and a hop uses it
    read(-10) read(-10) read(-10) read(-10) read(-10)
    W.mode = 0 W.onboard = false W.yaw = 60 W.deck.yaw = D
    W.N.hopTry("L3")
    check("a hop after that flies with the toes to the left of the capsule, measured", W.line("your toes point to the left of the capsule: your toes while riding") ~= nil, W)
end

out[#out + 1] = string.format("%d checks", nchecks)
local o = assert(io.open("hop180_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the board hop's facing test failed: see hop180_out.txt", 0) end

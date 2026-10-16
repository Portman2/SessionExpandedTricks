-- test_droparms218.lua (a DRAFT for build 218): ARMS OUT FOR BALANCE THROUGH A DROP-IN, the Lua side. What is checked is
-- what the Lua SENDS to the native half -- HJN_Set("droparms", w) on every frame that wants the arms up, with the
-- slider ("droparmsdeg") and the way he will ride ("droparmsyaw") in front of it -- in which states, with what weight,
-- and that it STOPS: after a bail, a step back, a level change, the replay, the ride's end. The pose itself is the
-- native half's (sim.pl replays its maths on recorded poses).
-- The world is test_setdown212.lua's (found beside this file or beside the main.lua), with one thing added: the board's
-- let-go (HJN_BoardKick), which none of the older suites runs through.
-- luareal -run test_droparms218.lua result.txt main.lua   (writes droparms218_out.txt)
local dirs = { (debug.getinfo(1, "S").source:gsub("^@", ""):gsub("[^/\\]+$", "")), (MAIN:gsub("[^/\\]+$", "")) }
local function slurp(name)
    for _, d in ipairs(dirs) do
        local f = io.open(d .. name, "rb")
        if f then local s = f:read("a") f:close() return (s:gsub("\r\n", "\n")) end
    end
    error(name .. " was not found beside this test or beside the main.lua", 0)
end
local world
do
    local hs = slurp("test_setdown212.lua")
    local cut = assert(hs:find("\nlocal all = true\n", 1, true), "the drop-in's stand-in world: its end was not found")
    hs = hs:sub(1, cut)
    local anchor = "    G.HJN_Bumpers = function() return W.bumpers or 0 end\n"
    local at = assert(hs:find(anchor, 1, true), "the stand-in world: the place for the let-go was not found")
    hs = hs:sub(1, at + #anchor - 1) .. "    G.HJN_BoardKick = function() W.kicks = (W.kicks or 0) + 1 return 7 end\n    G.HJN_DropDepth = function(...) W.depthAsked = { ... } return W.depth or -1, W.depthAt or 0 end\n" .. hs:sub(at + #anchor)
    do local ia = assert(hs:find("\n    local inst = setmetatable(", 1, true), "the stand-in world: its anim instance was not found")   -- (build 221) the anim instance seen by the test
       local ie = assert(hs:find("\n", ia + 1, true)) hs = hs:sub(1, ie) .. "    W.inst = inst\n" .. hs:sub(ie + 1) end
    world = assert(load(hs .. "\nreturn world", "=dropworld212"))()
end
local MODE_RIDING, MODE_AIR, MODE_BAILING = 1, 2, 5
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"):gsub("\r\n", "\n"); f:close()
local out, all = {}, true
local function check(name, cond, W)
    if W and (W.err or next(W.unk)) then
        cond = false
        for k in pairs(W.unk) do out[#out + 1] = "FAIL " .. name .. " -- the mod touched something the test does not have: " .. k end
        if W.err then out[#out + 1] = "FAIL " .. name .. " -- " .. tostring(W.err) end
    end
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        out[#out + 1] = string.format("       state %s, on board %s, mode %s, %d droparms calls", tostring(W.DI.state), tostring(W.onb), tostring(W.mode), W.sent("droparms"))
        for i = math.max(1, #W.logs - 14), #W.logs do out[#out + 1] = "       log: " .. W.logs[i]:sub(1, 300) end
    end
    if not cond then all = false end
end
local function near(x, y, tol) return x ~= nil and math.abs(x - y) <= tol end
local function S(t) local r = { DropInSetDown = 1, DropInFar = 0, DropInPush = 0 } for k, v in pairs(t or {}) do r[k] = v end return r end
-- the "droparms" calls from call number `from` on: { t, v }
local function arms(W, from)
    local r = {}
    for i = (from or 1), #W.calls do local c = W.calls[i] if c.k == "droparms" then r[#r + 1] = { t = c.t, v = c.v } end end
    return r
end
local function rising(a) for i = 2, #a do if a[i].v < a[i - 1].v - 1e-9 then return false end end return true end
local function falling(a) for i = 2, #a do if a[i].v > a[i - 1].v + 1e-9 then return false end end return true end
local function toSet(W) W.press() return W.till(function() return W.DI.state == "wait" end, 6) end

-- 0. what ships
do
    local function ship(k) return tonumber(src:match("\n    " .. k .. " *= *([%-%d%.]+),")) end
    check("0: DropInArms ships 40 (degrees), DropInPoses 0; the ini knows both", ship("DropInArms") == 40 and ship("DropInPoses") == 0
        and src:find("\n    { \"DropInArms\", \"num\", 0, 80, ", 1, true) ~= nil and src:find("\n    { \"DropInPoses\", \"num\", 0, 1, ", 1, true) ~= nil)
    local row = src:match("\n        { \"slider\", \"DropInArms\", \"([^\"]+)\", 1, 5, \"[^\n]*\", 0, 80, unit = \"degrees\" },\n")
    local desc = src:match("\n        { \"slider\", \"DropInArms\", \"[^\"]+\", 1, 5, \"([^\n]*)\", 0, 80, unit = \"degrees\" },\n")
    check("0: the Drop-ins page has the row, its label 63 characters at the most, its text with the default 239 at the most, plain ASCII",
        row ~= nil and #row <= 63 and desc ~= nil and #(desc .. " Default: 40 degrees.") <= 239 and not desc:find("[^\32-\126]"))
    do local b, wv = tonumber(src:match("\nNATIVE%.BUILD = (%d+)\n")), tonumber(src:match("\nNATIVE%.WANT = (%d+) "))
    check("0: build 218 or later for the native half v118 or later, and the banner says the same two numbers",
        b ~= nil and b >= 218 and wv ~= nil and wv >= 118 and src:find(string.format("(v%d / native v%d)", b, wv), 1, true) ~= nil) end
end

do local function ship(k) return tonumber(src:match("\n    " .. k .. " *= *([%-%d%.]+),")) end
    check("0: [220] DropInArmsFull ships 200 (cm), DropInArmsPeak 50 (%); the ini and the Drop-ins page know both", ship("DropInArmsFull") == 200 and ship("DropInArmsPeak") == 50
        and src:find("\n    { \"DropInArmsFull\", \"num\", 30, 500, ", 1, true) ~= nil and src:find("\n    { \"DropInArmsPeak\", \"num\", 10, 100, ", 1, true) ~= nil
        and src:find("{ \"slider\", \"DropInArmsFull\", ", 1, true) ~= nil and src:find("{ \"slider\", \"DropInArmsPeak\", ", 1, true) ~= nil) end

-- the skater comes down `cm` over `secs`, frame by frame (the world itself does not move him once he is on the board)
local function descend(W, cm, secs)
    local n = math.max(1, math.floor(secs / W.dt + 0.5))
    for _ = 1, n do W.act.z = W.act.z - cm / n W.frame(1) end
end
local function maxv(a) local m = 0 for _, c in ipairs(a) do if c.v > m then m = c.v end end return m end
-- a quarter pipe: 39 cm down just past the edge, 106 further out (the 11 Oct 10:31 one), the wheels meet it as hung
local function quarter(W) W.near, W.far, W.fslope, W.meets = 39, 106, 57, function() return 102, W.S.DropInPitch, 68 end end

-- A. the set-down on the coping, a quarter of 106 cm: nothing while he stands there; from GO out with the way down,
-- fully out halfway (53 cm) at 106 / 200 of the slider, held to the bottom, down over 0.7 s
for _, fps in ipairs({ 60, 90 }) do
    local tag = string.format("A (%d frames a second): ", fps)
    local W = world({ S = S(), dist = 20, v = 118, fps = fps, outDeg = 30 })
    quarter(W)
    W.press()
    W.till(function() return W.onb end, 4)
    check(tag .. "on foot, through the whole set-down's animation, nothing is asked of the arms (no droparms, no number)", W.sent("droparms") == 0 and W.sent("droparmsdeg") == 0 and W.sent("droparmsyaw") == 0, W)
    W.run(1.0)
    check(tag .. "SET on the coping, 1 s of standing there: still nothing asked of the arms", W.DI.state == "wait" and W.sent("droparms") == 0 and W.sent("droparmsdeg") == 0, W)
    local n0 = #W.calls
    W.stickUp = 1 W.till(function() return W.DI.state == "in" end, 1) W.stickUp = 0
    check(tag .. "[220] GO: the drop and its share are said (106 cm -> 53 % of 40 deg, fully out 50 % of the way down)", W.count("arms: a drop of 106 cm -> 53 % of DropInArms' 40 deg (all of it at 200 cm and more), fully out 50 % of the way down") == 1, W)
    W.till(function() return W.DI.state == "ride" end, 2)
    check(tag .. "[220] the tip-in, with no way down yet: the arms are not snapped up (nothing over 0.02 asked)", maxv(arms(W, n0 + 1)) <= 0.02, W)
    local n1 = #W.calls
    descend(W, 53, 0.3)                                              -- halfway down
    local half = arms(W, n1 + 1)
    check(string.format("%s[220] ...out with the way down: rising, and at halfway (53 cm) at their full share, 0.53 (%.3f)", tag, half[#half] and half[#half].v or -1),
        #half >= 5 and rising(half) and near(half[#half].v, 0.53, 0.01) and half[1].v < 0.2, W)
    local n2 = #W.calls
    descend(W, 40, 0.25)                                             -- on down, not yet at the bottom
    local held = arms(W, n2 + 1)
    local allTop = #held > 0 for _, c in ipairs(held) do if not near(c.v, 0.53, 0.01) then allTop = false end end
    check(tag .. "[220] ...held at that share on the way down past halfway (never more)", allTop, W)
    local n3, botAt = #W.calls, nil
    descend(W, 13, 0.1) botAt = W.t                                  -- the bottom (106 cm)
    W.run(1.2)
    local r = arms(W, n3 + 1)
    local lastT, lastV = nil, nil
    for _, c in ipairs(r) do if c.v > 0 then lastT, lastV = c.t, c.v end end
    check(string.format("%s[220] ...at the bottom: down over 0.7 s (the last asking over 0 is %.2f s after it, %.2f left), then shut", tag, lastT and (lastT - botAt) or -1, lastV or -1),
        #r > 0 and falling(r) and lastT ~= nil and lastT - botAt <= 0.85 and lastV <= 0.05 and r[#r].v == 0, W)
    check(tag .. "...said once that they are out; the slider (40) and the way he will ride (30 deg) went once each", W.count("arms out for balance: up to 40 deg") == 1 and W.sent("droparmsdeg") == 1 and W.sent("droparmsdeg", 40) == 1 and W.sent("droparmsyaw") == 1, W)
    W.run(1.0)
    check(tag .. "...and the drop-in over, nothing more is asked", W.DI.state == nil and W.DI.armsN == nil, W)
end

-- B. a straight drop off a plain ledge of 51 cm: out while he falls, fully out halfway down, down from the landing
do
    local W = world({ S = S(), dist = 20, v = 118 })
    W.near, W.far = 51, 51
    toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0
    W.frame(3) W.mode = MODE_AIR
    local n1 = #W.calls
    descend(W, 51, 0.32)
    local air = arms(W, n1 + 1)
    check(string.format("B: [220] through the fall the arms rise to their share, 51 / 200 = 0.255 (%.3f), never more", maxv(air)), #air >= 10 and rising(air) and near(maxv(air), 0.255, 0.01), W)
    W.mode = MODE_RIDING
    local landAt, n2 = W.t, #W.calls
    W.run(1.2)
    local r = arms(W, n2 + 1)
    local lastT, lastV = nil, nil
    for _, c in ipairs(r) do if c.v > 0 then lastT, lastV = c.t, c.v end end
    check(string.format("B: ...and from the landing they come down over 0.7 s (the last asking over 0 is %.2f s after it), then shut", lastT and (lastT - landAt) or -1),
        #r > 0 and falling(r) and lastT ~= nil and lastT - landAt <= 0.75 and lastV <= 0.05 and r[#r].v == 0 and W.DI.state == nil, W)
end

-- C. what ends it -- and what never starts it
do
    local W = world({ S = S(), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.mode = MODE_BAILING W.frame(1)
    local n = #W.calls
    W.frame(120)
    check("C: a bail while he stands SET: the drop-in is let go; the arms were never asked for, before or after", W.DI.state == nil and W.sent("droparms") == 0 and #arms(W, n + 1) == 0, W)
end
do
    local W = world({ S = S(), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "in" end, 1) W.stickUp = 0
    descend(W, 30, 0.1)                                              -- (on the way down already)
    W.mode = MODE_BAILING W.frame(1)
    local a = arms(W) local n = #W.calls
    W.frame(60)
    check("C: a bail on the way down: shut (0), nothing after", W.DI.state == nil and #a >= 2 and a[#a].v == 0 and a[#a - 1].v > 0.1 and #arms(W, n + 1) == 0, W)
end
do
    local W = world({ S = S(), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.bumpers = 1 W.frame(1) W.bumpers = 0
    W.till(function() return W.DI.state == nil end, 2)
    W.frame(60)
    check("C: LB/RB, back onto the ledge: the arms are never asked for", W.DI.state == nil and W.sent("droparms") == 0, W)
end
do
    local W = world({ S = S(), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.NATIVE.forgetDrop()
    W.frame(60)
    check("C: the level changes while he stands SET: nothing asked of the arms", W.DI.state == nil and W.sent("droparms") == 0, W)
end
do
    local W = world({ S = S(), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.mode = 6 W.frame(1)                                             -- the game's replay
    W.frame(60)
    check("C: the game's replay opened while he stands SET: nothing asked of the arms", W.DI.state == nil and W.sent("droparms") == 0, W)
end

-- D. the old way (what a build found by signature gets: no set-down): nothing until GO, then out with the way down
do
    local W = world({ S = S({ DropInSetDown = 0 }), dist = 20, v = 118 })
    quarter(W)
    W.press()
    W.till(function() return W.DI.state == "wait" end, 8) W.run(0.6)
    check("D: the old way: on foot, on the board squared to the edge, through the slide out and SET: nothing asked of the arms", W.DI.state == "wait" and W.sent("droparms") == 0, W)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0
    local n0 = #W.calls
    descend(W, 53, 0.3)
    local g = arms(W, n0 + 1)
    check("D: [220] ...GO and the way down: out to their share halfway (0.53)", #g >= 5 and rising(g) and near(g[#g].v, 0.53, 0.01), W)
end

-- E. switched off, beside an older native half, the slider moved, and the two new settings
do
    local W = world({ S = S({ DropInArms = 0, DropInCrouch = 0 }), dist = 20, v = 118 })   -- (build 221: the crouch off too, or the GO's line is said for it)
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0 descend(W, 106, 0.6)
    check("E: DropInArms 0: a whole drop-in asks nothing of the arms, and says nothing", W.sent("droparms") == 0 and W.sent("droparmsdeg") == 0 and W.sent("droparmsyaw") == 0 and W.count("arms out for balance") == 0 and W.count("arms: a drop of") == 0, W)
end
do
    local W = world({ S = S(), dist = 20, v = 117 })
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0 descend(W, 106, 0.6)
    check("E: beside the native half v117: nothing is asked (it has no arms pass)", W.sent("droparms") == 0 and W.sent("droparmsdeg") == 0, W)
end
do
    local W = world({ S = S({ DropInArms = 65 }), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0
    descend(W, 30, 0.15) W.S.DropInArms = 25 descend(W, 10, 0.05)     -- the menu's slider moved on the way down
    check("E: the slider moved during the drop-in: the new number is sent once more (65, then 25)", W.sent("droparmsdeg") == 2 and W.sent("droparmsdeg", 65) == 1 and W.sent("droparmsdeg", 25) == 1, W)
end
do
    local W = world({ S = S({ DropInArmsFull = 100 }), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0
    local n0 = #W.calls
    descend(W, 53, 0.3)
    check(string.format("E: [220] DropInArmsFull 100: a drop of 106 cm gets all of the slider (1 halfway down: %.3f)", maxv(arms(W, n0 + 1))), near(maxv(arms(W, n0 + 1)), 1, 0.01), W)
end
do
    local W = world({ S = S({ DropInArmsPeak = 100 }), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0
    local n0 = #W.calls
    descend(W, 53, 0.3)
    local a = arms(W, n0 + 1)
    local n1 = #W.calls
    descend(W, 50, 0.3)
    check(string.format("E: [220] DropInArmsPeak 100: halfway down they are half out (%.3f of 0.53), all out only near the bottom (%.3f)", a[#a] and a[#a].v or -1, maxv(arms(W, n1 + 1))),
        a[#a] ~= nil and near(a[#a].v, 0.265, 0.01) and maxv(arms(W, n1 + 1)) >= 0.52, W)
end

-- F. a second drop-in sends its numbers again
do
    local W = world({ S = S(), dist = 20, v = 118 })
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0
    descend(W, 106, 0.6)
    W.till(function() return W.DI.state == nil end, 3)
    check("F: after the first drop-in is over: one slider number, one heading sent so far", W.sent("droparmsdeg") == 1 and W.sent("droparmsyaw") == 1, W)
    check("F: dropKey clears the arms' numbers for the next drop-in", src:find("DI.armsN, DI.armsAt, DI.armsAir, DI.armsDeg, DI.armsYaw = nil, nil, nil, nil, nil   -- (v218) a new drop-in", 1, true) ~= nil, W)
end

-- G. (build 221) the drop traced down the way, the crouch, the game's shoulder twist held off (native v119)
local function crouchv(W, from)
    local r = {}
    for i = (from or 1), #W.calls do local c = W.calls[i] if c.k == "dropcrouch" then r[#r + 1] = { t = c.t, v = c.v } end end
    return r
end
do
    local W = world({ S = S(), dist = 20, v = 119 })
    quarter(W) W.depth, W.depthAt = 150, 180                        -- the quarter as traced: 150 cm deep, its bottom 1.8 m out
    toSet(W) W.run(0.6)
    check("G: [221] while he stands SET: no crouch, the twist not touched", W.sent("dropcrouch") == 0 and rawget(W.inst, "ShoulderAdditiveAlpha") == nil, W)
    local n0 = #W.calls
    W.stickUp = 1 W.till(function() return W.DI.state == "in" end, 1) W.stickUp = 0
    check("G: [221] GO: the way down is traced (HJN_DropDepth asked for the edge's own place and way), and the deeper drop is the one taken: 150 cm -> 75 %",
        W.depthAsked ~= nil and #W.depthAsked == 5 and W.count("arms: a drop of 150 cm -> 75 % of DropInArms' 40 deg") == 1 and W.count("the ledge scan 106 cm, the way down traced 150 cm (its bottom 180 cm out)") == 1, W)
    W.till(function() return W.DI.state == "ride" end, 2)
    local tip = crouchv(W, n0 + 1)
    local m = 0 for _, c in ipairs(tip) do if c.v > m then m = c.v end end
    check(string.format("G: [221] the tip-in: the crouch comes in with the tip, to half its share (18 x 0.75 / 2 = 6.75 cm: %.2f), rising", m), #tip >= 5 and rising(tip) and near(m, 6.75, 0.3), W)
    check("G: [221] ...and the game's shoulder twist is held off from the GO (its alpha 0), said once", rawget(W.inst, "ShoulderAdditiveAlpha") == 0 and W.count("shoulder twist is held off") == 1, W)
    local n1 = #W.calls
    descend(W, 37.5, 0.2)                                            -- a quarter of the way down
    local c1 = crouchv(W, n1 + 1) local a1 = arms(W, n1 + 1)
    check(string.format("G: [221] a quarter of the way down: the crouch at its lowest, 13.5 cm (%.2f); the arms at 0.375 (%.3f)", c1[#c1] and c1[#c1].v or -1, a1[#a1] and a1[#a1].v or -1),
        c1[#c1] ~= nil and near(c1[#c1].v, 13.5, 0.2) and a1[#a1] ~= nil and near(a1[#a1].v, 0.375, 0.01), W)
    local n2 = #W.calls
    descend(W, 112.5, 0.4) W.run(1.5)                                -- the bottom, and the ride's end
    local c2 = crouchv(W, n2 + 1)
    check("G: [221] at the bottom: up again with the arms (never lower), and shut at the end (0)", #c2 > 3 and falling(c2) and c2[#c2].v == 0 and W.DI.state == nil, W)
end
do
    local W = world({ S = S({ DropInNoTwist = 0, DropInCrouch = 0 }), dist = 20, v = 119 })
    quarter(W) toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0 descend(W, 106, 0.5)
    check("G: [221] DropInNoTwist 0 and DropInCrouch 0: the twist never touched, no crouch asked", rawget(W.inst, "ShoulderAdditiveAlpha") == nil and W.sent("dropcrouch") == 0 and W.count("shoulder twist") == 0, W)
end
do
    local W = world({ S = S(), dist = 20, v = 118 })
    quarter(W) W.depth = 150 toSet(W) W.run(0.6)
    W.stickUp = 1 W.till(function() return W.DI.state == "ride" end, 2) W.stickUp = 0 descend(W, 106, 0.5)
    check("G: [221] beside the native half v118: no crouch asked and the way down not traced (the scan's 106 cm is the drop)", W.sent("dropcrouch") == 0 and W.depthAsked == nil and W.count("arms: a drop of 106 cm") == 1, W)
end

-- H. (build 223) A SWITCH set-down on the coping (Y tapped twice): the arms as for a regular one -- nothing on foot or
-- standing ready, from GO out with the way down; the way he will ride is still out over the edge (the nose points at it)
do local W = world({ S = S(), dist = 20, v = 118, outDeg = 30, W = { swTurns = true } })
    quarter(W)
    W.press() W.run(0.15) W.press()
    W.till(function() return W.DI.state == "wait" end, 6)
    W.run(1.0)
    check("[new] H: SET on the coping in SWITCH (no slide), 1 s of standing there: nothing asked of the arms", W.DI.state == "wait" and W.onb and W.switch == true
        and W.has("ON THE COPING: no slide") ~= nil and W.sent("droparms") == 0 and W.sent("droparmsdeg") == 0, W)
    local n0 = #W.calls
    W.stickUp = 1 W.till(function() return W.DI.state == "in" end, 1) W.stickUp = 0
    W.till(function() return W.DI.state == "ride" end, 2)
    descend(W, 53, 0.3)
    local a = arms(W, n0 + 1)
    check(string.format("H: ...from GO out with the way down, as a regular one (%.3f at halfway); the way he will ride sent as the edge's way out (30 deg)", a[#a] and a[#a].v or -1),
        #a >= 5 and rising(a) and near(a[#a].v, 0.53, 0.01) and W.sent("droparmsyaw") == 1 and near((function() for _, c in ipairs(W.calls) do if c.k == "droparmsyaw" then return c.v end end end)() or -999, 30, 0.01), W)
end
local o = assert(io.open("droparms218_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("build 218's drop-in arms: a check failed, see droparms218_out.txt", 0) end

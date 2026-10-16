-- test_grabown.lua: a grab the GAME picked itself is put right by the mod's map (GR.ownPick), cut out of main.lua with
-- the map it asks (GR.swap, GR.toeLeft, gameGrabFor) and run in real Lua against a stand-in for the game.
-- luareal -run test_grabown.lua result.txt main.lua   (writes optest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("GR.MODE_NAME = {", 1, true), "the map's start was not found")
local b0 = assert(src:find("local function gameGrabFor(bumper, x, y, swap)", a, true), "gameGrabFor was not found")
local b = assert(src:find("\n    return id\nend\n", b0, true), "gameGrabFor's end was not found") + #"\n    return id\nend\n"
local c = assert(src:find("GR.ownPick = function(now, native)", b, true), "GR.ownPick was not found")
local d = assert(src:find("\nlocal function grabLatchTick(now, native)", c, true), "GR.ownPick's end was not found")
local body = src:sub(a, b - 1) .. "\n" .. src:sub(c, d)

local NAME = { [1] = "Nose", [2] = "Melon", [3] = "Mute", [4] = "Chicken Salad", [5] = "Taipan", [6] = "Seatbelt",
               [100] = "Tail", [101] = "Stalefish", [102] = "Indy", [103] = "Roast Beef", [104] = "Canadian Bacon", [105] = "Crail" }
local ID = {} for id, n in pairs(NAME) do ID[n] = id end
local function world(o)
    local W = { logs = {}, sets = {}, t = 100, mode = 2, switch = false, goofy = false, bumpers = 1, L = { 0, 0 }, R = { 0, 0 } }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    env.NAT = setmetatable({}, { __index = function(_, k) if k == "switch" then return W.switch elseif k == "goofy" then return W.goofy end end })
    env.HJN_Bumpers = function() return W.bumpers end
    local S = setmetatable({ GrabLBNeutral = "Mute", GrabRBNeutral = "Indy" },
        { __index = function(_, k) if k == "GrabFollowStickMode" then return 1 elseif k == "GrabToeSide" then return W.toe or 1 end end })
    local GR = { blocked = function() return false end, kicks = 0 }
    local GRAB_ID = { mute = 3, indy = 102 }
    local pc = { GetInputModeType = function() return W.mode end }
    local q = function(fn, dflt) local ok, r = pcall(fn) if ok then return r end return dflt end
    local s0 = { GetController = function() return pc end, GetGrabState = function() return W.game end }
    local stickNow = function(which) local v = (which == "Left") and W.L or W.R return v[1], v[2], "test" end
    local grabSet = function(id, why) W.sets[#W.sets + 1] = id W.logs[#W.logs + 1] = why W.game = id return true end
    local grabTitle = function(id) return (NAME[id] or "?") .. " Grab" end
    local chunk = "local GR, S, GRAB_ID, SB, alive, q, s0, log, logOnce, NATIVE, stickNow, grabSet, grabTitle = ...\n" .. body .. "\nreturn GR"
    local fn = assert(load(chunk, "=grabown", "t", env))
    W.GR = fn(GR, S, GRAB_ID, {}, function(x) return x end, q, s0, function(s) W.logs[#W.logs + 1] = s end, function() end, {}, stickNow, grabSet, grabTitle)
    -- the game has picked `name` itself; -> what it holds after the mod has looked
    W.picked = function(name) W.game = ID[name] W.t = W.t + 0.02 return NAME[W.GR.ownPick(W.t, W.game)] end
    return W
end
local out = {}
local function check(name, got, want) local ok = got == want out[#out + 1] = (ok and "ok   " or "FAIL ") .. name .. (ok and "" or ("  -- got " .. tostring(got) .. ", wanted " .. tostring(want))) return ok end
local all = true
local LEFT, RIGHT, UP = { -1, 0 }, { 1, 0 }, { 0, 1 }

-- front foot / back foot, GOOFY rolling forward (toes left): what the game picked on 7 Oct 23:46, and what it should be
do local W = world({ goofy = true, L = RIGHT, bumpers = 1 })
    all = check("goofy forward: LB, left stick right -- the game's Mute becomes", W.picked("Mute"), "Melon") and all
    W.L = LEFT   all = check("goofy forward: LB, left stick left -- the game's Melon becomes", W.picked("Melon"), "Mute") and all
    W.bumpers, W.R = 2, RIGHT all = check("goofy forward: RB, right stick right -- the game's Indy becomes", W.picked("Indy"), "Stalefish") and all
    W.R = LEFT   all = check("goofy forward: RB, right stick left -- the game's Stalefish becomes", W.picked("Stalefish"), "Indy") and all
    W.bumpers, W.L = 1, UP all = check("goofy forward: LB, left stick up -- the game's Nose stays", W.picked("Nose"), "Nose") and all
    W.L = { 0.2, 0.01 } all = check("goofy forward: LB, left stick a little to the right -- by its direction", W.picked("Mute"), "Melon") and all
    W.L = { 0, 0 } all = check("goofy forward: no stick to go by -- left as the game has it", W.picked("Mute"), "Mute") and all
    W.L, W.bumpers = RIGHT, 3 all = check("goofy forward: both bumpers down -- the two-hand grabs' business", W.picked("Mute"), "Mute") and all
    -- (the log's first line is the stick mode's, said once)
    all = check("goofy forward: five put right, each said and counted", #W.sets == 5 and #W.logs == 6 and W.GR.ownFixes == 5 and W.GR.kicks == 5, true) and all
    out[#out + 1] = "       " .. tostring(W.logs[2]) out[#out + 1] = "       " .. tostring(W.logs[4])
end
-- goofy riding SWITCH (toes right) and a regular rider rolling forward: the game's map is the mod's -- nothing is touched
do local W = world({ goofy = true, switch = true, L = RIGHT })
    all = check("goofy switch: LB, left stick right -- Mute stays", W.picked("Mute"), "Mute") and all
    W.L = LEFT all = check("goofy switch: LB, left stick left -- Melon stays", W.picked("Melon"), "Melon") and all
    W.bumpers, W.R = 2, RIGHT all = check("goofy switch: RB, right stick right -- Indy stays", W.picked("Indy"), "Indy") and all
    all = check("goofy switch: the game was handed nothing", #W.sets, 0) and all end
do local W = world({ L = RIGHT })
    all = check("regular forward: LB, left stick right -- Mute stays", W.picked("Mute"), "Mute") and all
    all = check("regular forward: the game was handed nothing", #W.sets, 0) and all end
-- a regular rider riding switch (toes left): the same turn as the goofy rider's
do local W = world({ switch = true, L = RIGHT })
    all = check("regular switch: LB, left stick right -- the game's Mute becomes", W.picked("Mute"), "Melon") and all end
-- left foot / right foot, goofy rolling forward: LB is the LEFT hand = the back hand, and the toes are on the left
do local W = world({ mode = 1, goofy = true, L = LEFT, bumpers = 1 })
    all = check("left/right, goofy forward: LB, left stick left -- the game's Melon (front hand) becomes", W.picked("Melon"), "Indy") and all
    W.L = RIGHT all = check("left/right, goofy forward: LB, left stick right -- the game's Mute becomes", W.picked("Mute"), "Stalefish") and all
    W.bumpers, W.R = 2, LEFT all = check("left/right, goofy forward: RB, right stick left -- the game's Stalefish (back hand) becomes", W.picked("Stalefish"), "Mute") and all
    W.R = RIGHT all = check("left/right, goofy forward: RB, right stick right -- the game's Indy becomes", W.picked("Indy"), "Melon") and all
    W.R = UP all = check("left/right, goofy forward: RB, right stick up -- the game's Tail (back hand) becomes the front hand's", W.picked("Tail"), "Seatbelt") and all
    out[#out + 1] = "       " .. tostring(W.logs[2])
end
-- left foot / right foot, goofy riding switch: the left foot leads, the toes are on the right; the game's own swap is the wrong way round
do local W = world({ mode = 1, goofy = true, switch = true, R = RIGHT, bumpers = 2 })
    all = check("left/right, goofy switch: RB, right stick right -- the game's Mute (its swap: RB the front hand) becomes", W.picked("Mute"), "Indy") and all
    W.bumpers, W.L = 1, LEFT all = check("left/right, goofy switch: LB, left stick left -- the game's Stalefish becomes", W.picked("Stalefish"), "Melon") and all end
-- the latch's bumper goes before the guess from the grab
do local W = world({ mode = 1, goofy = true, R = LEFT, L = RIGHT, bumpers = 2 }) W.GR.want = { bumper = "RB" }
    all = check("the pressed bumper (RB) is the one asked, not the grab's", W.picked("Melon"), "Mute") and all end
-- GrabToeSide=0 (the game's sides for everyone) in front/back: nothing to put right
do local W = world({ goofy = true, toe = 0, L = RIGHT })
    all = check("GrabToeSide=0: the game's Mute stays", W.picked("Mute"), "Mute") and all end

local o = assert(io.open("optest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the own-pick test failed: see optest_out.txt", 0) end

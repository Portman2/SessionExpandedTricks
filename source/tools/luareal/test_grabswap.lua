-- test_grabswap.lua: which hand a bumper is (GR.swap), which way the toe side is (GR.toeLeft) and the grab a bumper and
-- its stick pick (gameGrabFor), cut out of main.lua and run in real Lua against a stand-in for the game.
-- luareal -run test_grabswap.lua result.txt main.lua   (writes gstest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("GR.MODE_NAME = {", 1, true), "the start was not found")
local b0 = assert(src:find("local function gameGrabFor(bumper, x, y, swap)", a, true), "gameGrabFor was not found")
local b = assert(src:find("\n    return id\nend\n", b0, true), "gameGrabFor's end was not found") + #"\n    return id\nend\n"
local body = src:sub(a, b - 1)

local NAME = { [1] = "Nose", [2] = "Melon", [3] = "Mute", [4] = "Chicken Salad", [5] = "Taipan", [6] = "Seatbelt",
               [100] = "Tail", [101] = "Stalefish", [102] = "Indy", [103] = "Roast Beef", [104] = "Canadian Bacon", [105] = "Crail" }
local function world(o)
    local W = { logs = {}, t = 100, mode = 2, switch = false, goofy = false, follow = 1, toe = 1 }
    for k, v in pairs(o or {}) do W[k] = v end
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    env.NAT = setmetatable({}, { __index = function(_, k) if k == "switch" then return W.switch elseif k == "goofy" then return W.goofy end end })
    local S = setmetatable({ GrabLBNeutral = "Melon", GrabRBNeutral = "Indy" },
        { __index = function(_, k) if k == "GrabFollowStickMode" then return W.follow elseif k == "GrabToeSide" then return W.toe end end })
    local GR = { blocked = function() return false end }
    local GRAB_ID = { melon = 2, indy = 102 }
    local pc = { GetInputModeType = function() if W.mode == nil then error("no such function") end return W.mode end }
    local q = function(fn, d) local ok, r = pcall(fn) if ok then return r end return d end
    local chunk = "local GR, S, GRAB_ID, SB, alive, q, s0, log, logOnce, NATIVE = ...\n" .. body .. "\nreturn GR, gameGrabFor"
    local fn = assert(load(chunk, "=grabswap", "t", env))
    local said = {}
    W.GR, W.pick = fn(GR, S, GRAB_ID, {}, function(x) return x end, q, { GetController = function() return pc end },
        function(s) W.logs[#W.logs + 1] = s end, function(k, s) if not said[k] then said[k] = true W.logs[#W.logs + 1] = s end end, {})
    -- a bumper with its own stick pushed (x, y as the pad has them: +x = right, +y = pushed up)
    W.grab = function(bumper, x, y) W.t = W.t + 0.02 return NAME[W.pick(bumper, x, y, W.GR.swap(W.t))] end
    return W
end
local out = {}
local function check(name, got, want) local ok = got == want out[#out + 1] = (ok and "ok   " or "FAIL ") .. name .. (ok and "" or ("  -- got " .. tostring(got) .. ", wanted " .. tostring(want))) return ok end
local all = true
-- what a rider should get: lbBack = LB is the back hand's bumper (and RB the front hand's); toeLeft = his toes point left
local function expect(o, tag, lbBack, toeLeft)
    local W = world(o)
    local toe, heel = toeLeft and -1 or 1, toeLeft and 1 or -1
    local function hand(bumper, back)
        local up, down                                    -- (the right stick's up and down are the other way round in the game's read)
        if back then up, down = (bumper == "LB") and "Crail" or "Tail", (bumper == "LB") and "Tail" or "Crail"
        else up, down = (bumper == "LB") and "Nose" or "Seatbelt", (bumper == "LB") and "Seatbelt" or "Nose" end
        local st = (bumper == "LB") and "left" or "right"
        all = check(string.format("%s: %s + %s stick up", tag, bumper, st), W.grab(bumper, 0, 1), up) and all
        all = check(string.format("%s: %s + %s stick down", tag, bumper, st), W.grab(bumper, 0, -1), down) and all
        all = check(string.format("%s: %s + %s stick toward the toes (%s)", tag, bumper, st, toeLeft and "left" or "right"), W.grab(bumper, toe, 0), back and "Indy" or "Mute") and all
        all = check(string.format("%s: %s + %s stick toward the heels", tag, bumper, st), W.grab(bumper, heel, 0), back and "Stalefish" or "Melon") and all
        all = check(string.format("%s: %s, stick centred", tag, bumper), W.grab(bumper, 0, 0), back and "Indy" or "Melon") and all
    end
    hand("LB", lbBack) hand("RB", not lbBack)
    return W
end
-- front foot / back foot: LB is the front hand whoever rides and however; the toes: right for regular forward and goofy switch
expect({ mode = 2 },                               "front/back, regular        ", false, false)
expect({ mode = 2, switch = true },                "front/back, regular SWITCH ", false, true)
expect({ mode = 2, goofy = true },                 "front/back, goofy          ", false, true)
expect({ mode = 2, goofy = true, switch = true },  "front/back, goofy SWITCH   ", false, false)
-- left foot / right foot: LB is the LEFT hand -- the back one when the left foot is the back foot
expect({ mode = 1 },                               "left/right, regular        ", false, false)
expect({ mode = 1, switch = true },                "left/right, regular SWITCH ", true, true)
expect({ mode = 1, goofy = true },                 "left/right, goofy          ", true, true)
expect({ mode = 1, goofy = true, switch = true },  "left/right, goofy SWITCH   ", false, false)
expect({ mode = 3, goofy = true },                 "legacy, goofy              ", true, true)
-- the two ini switches
expect({ mode = 1, goofy = true, follow = 0 },     "GrabFollowStickMode=0      ", false, true)
expect({ mode = 2, goofy = true, toe = 0 },        "GrabToeSide=0 (goofy)      ", false, false)
expect({ mode = 2, toe = 2 },                      "GrabToeSide=2 (regular)    ", false, true)
do local W = expect({ goofy = true, mode = false }, "mode not readable          ", false, true)   -- (mode = false: the stand-in's GetInputModeType gives nothing a number can be made of)
    all = check("mode not readable: said once", #W.logs, 1) and all end
-- the game's own pick's test differs from the mod's for a goofy rider, and only there
do
    local function differ(o) local W = world(o) return W.GR.swap(W.t) ~= W.GR.gameSwap() end
    all = check("the two tests agree for a regular rider (left/right, forward)", differ({ mode = 1 }), false) and all
    all = check("the two tests agree for a regular rider (left/right, switch)", differ({ mode = 1, switch = true }), false) and all
    all = check("the two tests differ for a goofy rider (left/right, forward)", differ({ mode = 1, goofy = true }), true) and all
    all = check("the two tests differ for a goofy rider (left/right, switch)", differ({ mode = 1, goofy = true, switch = true }), true) and all
    all = check("the two tests agree in front/back (goofy, switch)", differ({ mode = 2, goofy = true, switch = true }), false) and all
end
-- the mode changed in the game's options while playing: followed within a second, and said
do local W = world({ mode = 2, goofy = true })
    all = check("mode changed: before", W.grab("LB", 0, 1), "Nose") and all
    W.mode = 1 W.t = W.t + 1.5
    all = check("mode changed: after a second", W.grab("LB", 0, 1), "Crail") and all
    all = check("mode changed: two lines in the log", #W.logs, 2) and all end

local o = assert(io.open("gstest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the grab swap's test failed: see gstest_out.txt", 0) end

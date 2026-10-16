-- test_drop213.lua (build 213, mk213.pl): WHO GETS A DROP-IN. The set-down on the coping is the drop-in now: a Y press
-- from farther off than DropInSetReach is the game's own throwdown (DropInFar 1 = build 212's set-down behind the edge),
-- a press on a board that was only just picked up waits for the board, and the menu's two test rows are gone.
-- The world is test_setdown212.lua's (an edge, a skater on foot with the board in his hand, the game's Y and its throw,
-- a stand-in for the native half v114), found beside this file or beside the main.lua.
-- luareal -run test_drop213.lua result.txt main.lua   (writes drop213_out.txt)
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
    world = assert(load(hs:sub(1, cut) .. "\nreturn world", "=dropworld212"))()
end
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"):gsub("\r\n", "\n"); f:close()
local out, all = {}, true
local function check(name, cond, W)
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        out[#out + 1] = string.format("       state %s, on board %s, board mode %s, the game threw %s, gate writes %d", tostring(W.DI.state), tostring(W.onb), tostring(W.bmode), tostring(W.threw), #W.gateWrites)
        for _, l in ipairs(W.logs) do out[#out + 1] = "       log: " .. l:sub(1, 300) end
    end
    if not cond then all = false end
end
local NOW = { DropInSetDown = 1, DropInFar = 0 }                    -- as build 213 ships
local function with(t) local r = { DropInSetDown = 1, DropInFar = 0 } for k, v in pairs(t) do r[k] = v end return r end

-- 0. what ships
do
    local function ship(k) return tonumber(src:match("\n    " .. k .. " *= *([%-%d%.]+),")) end
    check("0: the set-down on the coping ships as THE drop-in: DropInSetDown 1, DropInSetEdge 1, DropInSetReach 45, DropInFar 0, DropInWalkSpeed 120",
        ship("DropInSetDown") == 1 and ship("DropInSetEdge") == 1 and ship("DropInSetReach") == 45 and ship("DropInFar") == 0 and ship("DropInWalkSpeed") == 120)
    check("0: the menu has neither test row any more", src:find("\"Set the board down at the edge (test)\"", 1, true) == nil and src:find("\"Set it ON the coping (test)\"", 1, true) == nil)
    check("0: the ini knows DropInFar and DropInWalkSpeed", src:find("\n    { \"DropInFar\", \"num\", ", 1, true) ~= nil and src:find("\n    { \"DropInWalkSpeed\", \"num\", ", 1, true) ~= nil)
end

-- A. at the edge: the set-down on the coping, as before
do local W = world({ S = NOW, dist = 20 })
    W.press()
    check("A: Y 20 cm from the edge: the set-down on the coping (state \"throw\", marked for the edge, the game's Y refused)", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge == true and #W.gateWrites == 1, W)
    W.run(4)
    check("A: ...and he is put on it there: SET with no slide, the game threw nothing", W.DI.state == "wait" and W.onb and W.has("ON THE COPING: no slide") ~= nil and W.threw == 0, W)
end

-- B. farther off than the reach: no drop-in, the game's own throwdown
do local W = world({ S = NOW, dist = 60 })
    W.press()
    check("B: Y 60 cm from the edge: no drop-in (no state, the game's Y NOT refused), and the log says why", W.DI.state == nil and #W.gateWrites == 0
        and W.has("Y on foot: an edge 60 cm away, farther than DropInSetReach (45 cm) -- no drop-in") ~= nil, W)
    W.run(0.4)
    check("B: ...the game's own throw goes", W.threw == 1 and W.DI.state == nil, W)
end
do local W = world({ S = NOW, dist = 46 })
    W.press()
    check("B: 46 cm with a reach of 45: no drop-in either", W.DI.state == nil and #W.gateWrites == 0, W)
end
do local W = world({ S = with({ DropInSetReach = 70 }), dist = 60 })
    W.press()
    check("B: 60 cm with DropInSetReach 70: on the coping", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge == true, W)
end
do local W = world({ S = with({ DropInFar = 1 }), dist = 60 })
    W.press()
    check("B: 60 cm with DropInFar 1: build 212's set-down behind the edge (state \"throw\", not for the coping)", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge ~= true
        and W.has("build 211's way") ~= nil, W)
end
do local W = world({ S = with({ DropInSetEdge = 0 }), dist = 60 })
    W.press()
    check("B: with DropInSetEdge 0 (the coping way off in the ini) a far press is build 211's set-down as it was: the new rule is the coping way's", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge ~= true, W)
end
do local W = world({ S = NOW, dist = 60, v = 113 })
    W.press()
    check("B: beside native v113 (no coping way to be had) a far press is build 211's set-down as it was", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge ~= true, W)
end

-- C. the board only just picked up
do local W = world({ S = NOW, dist = 20 })
    W.DI.looseAt = W.t - 0.6                                          -- it lay loose 0.6 s ago...
    W.busy = true                                                     -- ...and the game is still busy picking it up
    W.press()
    check("C: Y at the edge 0.6 s after the pick-up: no drop-in yet, but it is kept (DI.again), the game's own throw held back", W.DI.state == nil and W.DI.again ~= nil and #W.gateWrites == 1 and W.gateWrites[1] == 0.5
        and W.has("the drop-in waits until the board is free in your hand") ~= nil, W)
    W.run(0.3)
    check("C: ...while the game is busy with the board nothing starts, and its throw stays held back", W.DI.state == nil and W.DI.again ~= nil and W.threw == 0 and #W.gateWrites >= 2, W)
    W.busy = false
    W.run(0.1)
    check("C: ...the moment the board is free in the hand the set-down on the coping starts by itself", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge == true and W.DI.again == nil and W.threw == 0, W)
    W.run(4)
    check("C: ...and runs to SET on the coping", W.DI.state == "wait" and W.onb and W.has("ON THE COPING: no slide") ~= nil and W.threw == 0, W)
end
do local W = world({ S = NOW, dist = 20 })
    W.DI.looseAt = W.t - 0.6
    W.busy = true
    W.press()
    W.run(2.2)
    check("C: a board the game never frees: the wait is given up after 1.8 s, nothing started", W.DI.state == nil and W.DI.again == nil, W)
end
do local W = world({ S = NOW, dist = 60 })
    W.DI.looseAt = W.t - 0.6
    W.press()
    check("C: just picked up but 60 cm from the edge: no drop-in and nothing kept (the far rule comes first), the game's Y not refused", W.DI.state == nil and W.DI.again == nil and #W.gateWrites == 0, W)
end
do local W = world({ S = with({ DropInSetEdge = 0 }), dist = 20 })
    W.DI.looseAt = W.t - 0.6
    W.press()
    check("C: with the coping way off, a press 0.6 s after the pick-up is refused as before (build 180's rule)", W.DI.state == nil and W.DI.again == nil and #W.gateWrites == 0
        and W.has("the board lay loose 0.6 s ago (just picked up after a fall) -- no drop-in") ~= nil, W)
end
do local W = world({ S = NOW, dist = 20 })
    W.DI.looseAt = W.t - 2.0
    W.press()
    check("C: 2 s after the pick-up there is nothing to wait for: the set-down at once", W.DI.state == "throw" and W.DI.again == nil, W)
end

-- D. (build 223) SWITCH: Y tapped twice at the edge is the set-down on the coping too, and so is a double tap made while
-- the drop-in waits for a board just picked up (build 222 took that second tap for a new, regular press)
do local W = world({ S = NOW, dist = 20, W = { swTurns = true } })
    W.press() W.run(0.15) W.press()
    W.run(4)
    check("[new] D: Y tapped twice 20 cm from the edge: SET ON THE COPING in switch (no slide), the mount asked for the switch foot, the game threw nothing",
        W.DI.state == "wait" and W.onb and W.switch == true and W.has("ON THE COPING: no slide") ~= nil and W.count("build 211's set-down") == 0
        and W.sdMounts[1] ~= nil and W.sdMounts[1].sw == 1 and #W.mountCalls == 0 and W.threw == 0, W)
end
do local W = world({ S = NOW, dist = 20, W = { swTurns = true } })
    W.DI.looseAt = W.t - 0.6
    W.busy = true
    W.press() W.run(0.15) W.press()
    check("[new] D: the board just picked up: Y, and Y again 0.15 s on -- the second tap is kept with the wait (not a new press), said", W.DI.state == nil and W.DI.again ~= nil and W.DI.again.sw == true
        and W.count("the drop-in waits until the board is free in your hand") == 1 and W.has("Y tapped again while the drop-in waits for the board -- you will be put on in SWITCH") ~= nil, W)
    W.run(0.2) W.busy = false W.run(0.1)
    check("[new] D: ...the board free: the set-down on the coping starts by itself, in SWITCH", W.DI.state == "throw" and W.DI.th ~= nil and W.DI.th.edge == true and W.DI.sw == true
        and W.has("Y was tapped twice while it waited for the board -- you will be put on in SWITCH") ~= nil, W)
    W.run(4)
    check("[new] D: ...and runs to SET on the coping in switch; the game threw nothing", W.DI.state == "wait" and W.onb and W.switch == true and W.has("ON THE COPING: no slide") ~= nil
        and W.sdMounts[1] ~= nil and W.sdMounts[1].sw == 1 and W.threw == 0, W)
end
do local W = world({ S = NOW, dist = 20 })
    W.DI.looseAt = W.t - 0.6
    W.busy = true
    W.press() W.run(0.7) W.press()
    check("D: ...a second press 0.7 s after the first is not the double tap: a new press, the wait begun again, regular", W.DI.again ~= nil and W.DI.again.sw == nil
        and W.count("the drop-in waits until the board is free in your hand") == 2 and W.count("you will be put on in SWITCH") == 0, W)
end
local o = assert(io.open("drop213_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("build 213's drop-in rules: a check failed, see drop213_out.txt", 0) end

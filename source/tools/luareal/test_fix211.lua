-- test_fix211.lua (build 211 after its review, mk211_fix.pl): what the review's fixes change, each in the stand-in
-- world its own step was tested in -- the board hop's (test_hopspeed.lua's world()) and the drop-in's (test_setdown.lua's
-- world()), both read as text and used unchanged, bar the order of a frame in the drop-in's (when the game thread's
-- queue is run: see ORDER).
--   luareal -run test_fix211.lua result.txt main.lua   (writes fix211_out.txt)
-- Run on the candidate BEFORE the fixes (l3.lua) the checks marked [fix] must FAIL: that is what shows they look at
-- the thing fixed. The stand-ins are models of the game, not the game.
-- (build 212, mk_test212_hop.pl) the board hop gives the speed ONCE now, not "once more, as always" 60 ms on: the five
-- checks that counted that kick are corrected (one kick fewer where it was a kick for nothing; where the game had
-- taken the speed back, the kick at the first reading is "given AGAIN" like the later ones).
-- The two tests whose worlds are borrowed are looked for beside this file, then beside the main.lua
local dirs = { (debug.getinfo(1, "S").source:gsub("^@", ""):gsub("[^/\\]+$", "")), (MAIN:gsub("[^/\\]+$", "")) }
local function slurp(name)
    for _, d in ipairs(dirs) do
        local f = io.open(d .. name, "rb")
        if f then local s = f:read("a") f:close() return (s:gsub("\r\n", "\n")) end
    end
    error(name .. " was not found beside this test or beside the main.lua", 0)
end
local function wrap(x) return x - 360 * math.floor(x / 360 + 0.5) end
local function near(x, y, tol) return x ~= nil and math.abs(x - y) <= (tol or 0.5) end
local out, all, nchecks = {}, true, 0
local function check(name, cond, W)
    nchecks = nchecks + 1
    if W and (W.err or (W.unk and next(W.unk))) then
        cond = false
        for k in pairs(W.unk or {}) do out[#out + 1] = "FAIL " .. name .. " -- the mod touched something the test does not have: " .. k end
        if W.err then out[#out + 1] = "FAIL " .. name .. " -- " .. tostring(W.err) end
    end
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then all = false
        for _, l in ipairs(W and W.logs or {}) do out[#out + 1] = "       log: " .. tostring(l):sub(1, 300) end
    end
    return cond
end

-- =================================================================== THE BOARD HOP
local hworld
do
    local tsrc = slurp("test_hopspeed.lua")
    local cut = assert(tsrc:find("\nlocal function near(", 1, true), "the hop's stand-in world: its end was not found")
    hworld = assert(load(tsrc:sub(1, cut) .. "\nreturn world\n", "=hopworld", "t", setmetatable({ MAIN = MAIN }, { __index = _G })))()
end
out[#out + 1] = "--- the board hop: the speed is given again only until it has been read once (A.took)"
-- a run at 460 straight at a still board, BoardHopSpeedScale 1.2: 552 asked for. reading(t, W) = what the game reads
-- t seconds after the mount; the mesh moves as the board does
local function hop(go, reading)
    local W = hworld({ scale = 1.2, go = go })
    W.vel = { X = 460, Y = 0, Z = 0 } W.mesh = 455
    W.speedFn = function(w) return reading(w.t - (w.mountT or w.t), w) end
    W.N.hopTry("L3")
    for _ = 1, 200 do
        W.tick(1)
        if W.onboard then W.mesh = W.speedFn(W) end
    end
    local at = {}
    for _, k in ipairs(W.kicks) do at[#at + 1] = string.format("%.0f", (k.t - W.mountT) * 1000) end
    W.kat = table.concat(at, " ")
    return W
end
do local W = hop(1, function(t) if t < 0.3 then return 552 end return math.max(150, 552 - (t - 0.3) * 1400) end)
    check(string.format("[fix] a bank rolled up (552 kept for 0.3 s, then down to 150; native v113 let go of the hold): one kick (build 212) and no 'given AGAIN' (kicks at %s ms, %d x AGAIN)",
        W.kat, W.count("given AGAIN")), #W.kicks == 1 and W.count("given AGAIN") == 0 and W.free(), W)
end
do local W = hop(0, function(t, w) if t < 0.3 then return 0 end if t < 0.55 then return w.given or 0 end return 100 end)
    check(string.format("[fix] the hold for 0.3 s, then the speed kept, then the world slows the board to 100 from 0.55 s: given again while held, not after (kicks at %s ms, %d x AGAIN)",
        W.kat, W.count("given AGAIN")), #W.kicks == 3 and W.count("given AGAIN") == 2 and W.free(), W)   -- (build 212: the kick at the first reading is "given AGAIN" too)
end
do local W = hop(0, function(t, w) if t < 0.5 then return 0 end return w.given or 0 end)
    check(string.format("the game's hold for 0.5 s (native v112 on a slope): given again until it sticks, as before (kicks at %s ms, %d x AGAIN)", W.kat, W.count("given AGAIN")),
        #W.kicks == 4 and W.count("given AGAIN") == 3 and near(W.kicks[#W.kicks][1], 552, 1) and W.free(), W)   -- (build 212: as above)
end
-- (build 212) the wipe is modelled now: the game's first tick takes the first kick away (the stand-in used to keep it
-- and only READ 0 for 30 ms: the second kick "as always" made that pass either way). What gives it back is the first
-- reading, 60 ms on
do local W = hop(0, function(t, w) if not w.wipedOnce then w.wipedOnce = true w.given = 0 end return w.given or 0 end)
    check(string.format("level ground, the first kick wiped (native v112): given AGAIN at the first reading (build 212), and that sticks, no more (kicks at %s ms, %d x AGAIN)", W.kat, W.count("given AGAIN")),
        #W.kicks == 2 and W.count("given AGAIN") == 1 and W.free(), W)
end
do local W = hop(0, function() return 0 end)
    check(string.format("never read at all (the game reads 0 and he does not move for the whole 0.8 s): given at every reading, as before (kicks at %s ms, %d x AGAIN)", W.kat, W.count("given AGAIN")),
        #W.kicks == 6 and W.count("given AGAIN") == 5 and W.free(), W)   -- (build 212: as above)
end
out[#out + 1] = "--- the board hop: what 'boardgo answered 0' is called"
do local W = hop(0, function(t, w) return w.given or 0 end)
    check("[fix] boardgo answered 0: 'not looked at by this native half', with both reasons (v112 and older; v113 on another build or with no board), and no word that v113 lets go of it",
        W.has("the game's hold-still after a mount: not looked at by this native half (v112 and older have no such thing; v113 says so on another build of the game or when it finds no board)") ~= nil
        and W.has("native v113 lets go of it") == nil, W)
    local W1, W2 = hop(1, function(t, w) return w.given or 0 end), hop(2, function(t, w) return w.given or 0 end)
    check("boardgo answered 1 and 2: 'let go' and 'was not up', as before", W1.has("the game's hold-still after a mount: let go)") ~= nil and W2.has("the game's hold-still after a mount: was not up)") ~= nil, W1)
end
out[#out + 1] = "--- the board hop: BoardHopSwitchFix is read once a hop (the yaw handed over and the flip flag are a pair)"
-- a nose-first switch hop (you face -30, the deck's nose points 0): the plan is the capsule at 180 on the board.
-- the setting is changed 0.125 s into the 0.45 s of the hop, as the ini's poll would
local function swhop(fixAtClick, fixLater)
    local W = hworld({ fix = fixAtClick })
    W.yaw = -30
    W.N.hopTry("L3")
    W.tick(10)
    if fixLater ~= nil then W.S.BoardHopSwitchFix = fixLater end
    W.tick(110)
    local l = W.logs[W.has("facing on the first frame riding") or 0] or ""
    W.off, W.turned = tonumber(l:match("planned %-?%d+, ([%+%-]%d+) off")), tonumber(l:match("turned ([%+%-]%d+)%)"))
    W.said = l
    return W
end
do local W = swhop(1, nil)
    check(string.format("a switch hop with the fix on, the setting left alone: handed over half a turn round, flip flag 0; the capsule on the plan (%s off), the deck's nose kept (turned %s)",
        tostring(W.off), tostring(W.turned)), W.has("riding nose-first switch") ~= nil and W.msw == 1 and W.mflip == 0 and W.off == 0 and W.turned == 0, W)
    W = swhop(1, 0)
    check(string.format("[fix] ...the setting turned OFF in mid hop: this hop is finished as it was begun -- the capsule on the plan (%s off), the deck's nose kept (turned %s), flip flag %s",
        tostring(W.off), tostring(W.turned), tostring(W.mflip)), W.msw == 1 and W.mflip == 0 and W.off == 0 and W.turned == 0, W)
    W = swhop(0, nil)
    check(string.format("a switch hop with the fix off (build 210): the capsule half a turn off the plan (%s off), the deck's nose kept (turned %s), flip flag %s",
        tostring(W.off), tostring(W.turned), tostring(W.mflip)), W.msw == 1 and W.mflip == 1 and math.abs(W.off or 0) == 180 and W.turned == 0, W)
    W = swhop(0, 1)
    check(string.format("[fix] ...the setting turned ON in mid hop: finished as build 210 would -- %s off, the deck's nose kept (turned %s): the deck is not spun under him",
        tostring(W.off), tostring(W.turned)), W.msw == 1 and W.mflip == 1 and math.abs(W.off or 0) == 180 and W.turned == 0, W)
end

-- =================================================================== THE DROP-IN'S SET-DOWN
-- ORDER = when what a tick handed to the game thread's queue is run:
--   "ue4ss"  in the same frame, after the tick (the harness's own order: UE4SS runs the queue);
--   "pump"   at the start of the NEXT frame's hook, before its tick (the review's order);
--   "late"   a whole frame on, after the next tick (main.lua's NATIVE.gtPump runs the queue 0.05 s after it was filled).
local ORDER = "ue4ss"
FX_ORDER = function() return ORDER end
local dworld
do
    local hs = slurp("test_setdown.lua")
    local cut = assert(hs:find("\nlocal all = true\n", 1, true), "the drop-in's stand-in world: its end was not found")
    hs = hs:sub(1, cut)
    local old = "            game()\n            NATIVE.dropTick(W.t)\n            local qd = W.q\n            W.q = {}\n            for _, fn in ipairs(qd) do fn() end\n"
    local a0 = assert(hs:find(old, 1, true), "the drop-in's stand-in world: its frame was not found")
    local new = "            game()\n"
        .. "            local o = FX_ORDER()\n"
        .. "            if o == 'pump' then local qd = W.q W.q = {} for _, fn in ipairs(qd) do fn() end end\n"
        .. "            NATIVE.dropTick(W.t)\n"
        .. "            if o == 'ue4ss' then local qd = W.q W.q = {} for _, fn in ipairs(qd) do fn() end\n"
        .. "            elseif o == 'late' then local qd = W.qOld or {} W.qOld = W.q W.q = {} for _, fn in ipairs(qd) do fn() end end\n"
    hs = hs:sub(1, a0 - 1) .. new .. hs:sub(a0 + #old)
    dworld = assert(load(hs .. "\nreturn world", "=dropworld"))()
end
local function toWait(W, sec) return W.till(function() return W.DI.state == "wait" or W.DI.state == nil end, sec or 6) end

out[#out + 1] = "--- the set-down: a Y press after it has left its 'throw' state is not the second tap (DI.tapOver)"
do local W = dworld({ S = { DropInSetDown = 1 } })
    W.press()
    W.till(function() return W.onb end, 4)
    W.frame(2)
    local st, over = W.DI.state, W.DI.tapOver
    W.press()                                                    -- two frames after the set-down's mount
    local sw = W.DI.sw
    toWait(W, 4)
    -- (a Y press made ON the board also starts build 211's step-off trace, DI.stepOffWatch, which reads five values of
    -- the anim instance this stand-in does not have: reads only, and test_stepoff.lua's matter, not this check's)
    for k in pairs(W.unk) do if k:find("^anim%.") then W.unk[k] = nil end end
    check(string.format("[fix] Y pressed two frames after a REGULAR set-down's mount (state '%s'): not taken for SWITCH, no half turn (DI.sw %s, yaw %.0f, %d teleports, ends '%s')",
        tostring(st), tostring(sw), W.act.yaw, W.teleports, tostring(W.DI.state)),
        st == "mount" and over == true and sw ~= true and W.DI.state == "wait" and W.teleports == 0 and near(wrap(W.act.yaw - W.sq), 0, 1) and not W.has("you will be put on in SWITCH"), W)
end
do local W = dworld({ S = { DropInSetDown = 1 }, W = { animRefuses = true } })
    W.press() W.till(function() return W.DI.state == "mount" end, 2)
    W.press()                                                    -- at once after "the native half would not start the animation"
    local sw = W.DI.sw
    toWait(W, 5)
    check(string.format("[fix] the animation refused -> the mod's own mount; Y again at once: a REGULAR mount (DI.sw %s, mounted for the %s foot, yaw %.0f, ends '%s')",
        tostring(sw), (W.mountCalls[#W.mountCalls] or {}).sw == 1 and "SWITCH" or "regular", W.act.yaw, tostring(W.DI.state)),
        sw ~= true and #W.mountCalls >= 1 and W.mountCalls[#W.mountCalls].sw == 0 and W.DI.state == "wait" and near(wrap(W.act.yaw - W.sq), 0, 1), W)
end
do local W = dworld({ S = { DropInSetDown = 1 }, W = { gateBroken = true } })
    W.press() W.run(0.5)
    local st = W.DI.state
    W.press()                                                    -- 0.5 s after the first press; the game threw at 0.216 s on ONE tap
    local sw = W.DI.sw
    toWait(W, 6)
    check(string.format("[fix] the veto too late (the game threw on one tap), Y again 0.5 s after the first: not SWITCH, he is not turned round (DI.sw %s, yaw %.0f, ends '%s')",
        tostring(sw), W.act.yaw, tostring(W.DI.state)),
        st == "mount" and W.has("the veto came too late") ~= nil and sw ~= true and W.DI.state == "wait" and near(wrap(W.act.yaw - W.sq), 0, 1) and not W.has("riding SWITCH"), W)
end
do local W = dworld({ S = { DropInSetDown = 1 }, W = { swTurns = true } })
    W.press() W.run(0.15) W.press()                               -- the second tap before the animation has begun: this IS switch
    local sw = W.DI.sw
    toWait(W, 5)
    check(string.format("a second tap 0.15 s in, before the animation has begun, is still SWITCH (DI.sw %s, clip asked %s, mounted for the %s foot, ends '%s')",
        tostring(sw), tostring(W.animAsks[1]), (W.mountCalls[1] or {}).sw == 1 and "SWITCH" or "regular", tostring(W.DI.state)),
        sw == true and W.animAsks[1] == 2 and #W.mountCalls == 1 and W.mountCalls[1].sw == 1 and W.DI.state == "wait" and W.teleports == 0, W)
end
do local W = dworld({})                                          -- DropInSetDown 0: the old drop-in
    W.press() W.run(0.3) W.press()
    check("the old way (DropInSetDown 0): a second tap 0.3 s after the first is SWITCH, as in build 210", W.DI.state == "mount" and W.DI.sw == true and W.DI.tapOver == nil, W)
    W = dworld({ S = { DropInSetDown = 1 }, v = 112 })           -- no set-down is tried (an older native half): the old way from the press
    W.press() W.run(0.3) W.press()
    check("DropInSetDown 1 beside native v112 (no set-down tried): the old way's window is as it was", W.has("this one goes the old way") ~= nil and W.DI.sw == true and W.DI.tapOver == nil, W)
end
do local W = dworld({ S = { DropInSetDown = 1 } })
    W.press() toWait(W, 5)
    local over = W.DI.tapOver
    W.mode = 5 W.frame(2)
    check("[fix] DI.tapOver is up after a set-down and gone when the drop-in is let go (a bail)", over == true and W.DI.state == nil and W.DI.tapOver == nil, W)
    -- a drop-in that ends riding off ("1.5 s on") does not go through letGo: the next one must begin with it cleared
    W = dworld({})
    W.DI.tapOver = true                                          -- as such a set-down would have left it
    W.press() W.run(0.3) W.press()
    check("[fix] a new drop-in begins with DI.tapOver cleared: the old way's second tap is SWITCH although the one before was a set-down", W.DI.state == "mount" and W.DI.tapOver == nil and W.DI.sw == true, W)
end

out[#out + 1] = "--- the set-down: the game's replay (mode 6) opened while it plays"
do local W = dworld({ S = { DropInSetDown = 1 } })
    W.press() W.run(0.5)
    local st, m0, a0, p0 = W.DI.state, W.moves, W.sent("throwanim", -1), W.pendAsks
    W.mode = 6
    W.run(1.6)
    check(string.format("[fix] mode 6 from 0.5 s in: let go (state %s; moved %d more times, the animation's flag kept %d more times, the mount asked %d times, on the board %s)",
        tostring(W.DI.state), W.moves - m0, W.sent("throwanim", -1) - a0, W.pendAsks - p0, tostring(W.onb)),
        st == "throw" and W.DI.state == nil and W.moves == m0 and W.sent("throwanim", -1) == a0 and W.pendAsks == p0 and not W.onb
        and W.has("the game's replay was opened while the board was being set down") ~= nil and W.sent("throwanim", 0) >= 1 and W.sent("notoggle", 0) >= 1 and W.DI.th == nil, W)
end

out[#out + 1] = "--- the set-down: what it queued is not done once he is on the board or it is over"
for _, order in ipairs({ "pump", "late" }) do
    for _, sw in ipairs({ false, true }) do
        ORDER = order
        local W = dworld({ S = { DropInSetDown = 1 }, W = { swTurns = true } })
        W.press()
        if sw then W.run(0.15) W.press() end
        W.till(function() return W.onb end, 4)
        local yawAtMount = W.act.yaw
        W.frame(3)
        local yaw3 = W.act.yaw
        toWait(W, 5)
        check(string.format("[fix] the queue run %s, %s: not moved by the on-foot call once on the board (%s), the yaw of the game's mount kept (%.0f -> %.0f), no first move (%d teleports), ends '%s'",
            order == "pump" and "at the start of the next frame" or "a whole frame late", sw and "SWITCH" or "regular", tostring(W.movedOnBoard), yawAtMount, yaw3, W.teleports, tostring(W.DI.state)),
            not W.movedOnBoard and near(wrap(yaw3 - yawAtMount), 0, 0.01) and W.teleports == 0 and W.DI.state == "wait" and W.onb and (W.DI.sw == true) == sw, W)
        ORDER = "ue4ss"
    end
end
do  ORDER = "late"
    local W = dworld({ S = { DropInSetDown = 1 } })
    W.press() W.run(0.5)
    local m0 = W.moves                                            -- (the last tick's move is still in the queue)
    W.mode = 5 W.frame(3)
    check(string.format("[fix] the queue a whole frame late, a bail 0.5 s in: the move queued before the bail is not made after it (%d moves after 'the game bailed you')", W.moves - m0),
        W.DI.state == nil and W.has("the game bailed you") ~= nil and W.moves == m0, W)
    W = dworld({ S = { DropInSetDown = 1 } })
    W.press() W.till(function() return W.DI.th and W.DI.th.asked end, 4)
    local asked = W.DI.th and W.DI.th.asked
    W.mode = 5 W.frame(4)                                         -- the bail comes in the frame after the mount was queued
    check(string.format("[fix] the queue a whole frame late, a bail in the frame after the mount was queued: no mount is asked of the game after the bail (%d native mount calls, %d toggles asked, on the board %s)",
        #W.mountCalls, W.pendAsks, tostring(W.onb)), asked == true and W.DI.state == nil and #W.mountCalls == 0 and W.pendAsks == 0 and not W.onb, W)
    ORDER = "ue4ss"
end

out[#out + 1] = "--- the set-down: a re-mount after it is the mod's own mount; DropInAlignTime 0"
do local W = dworld({ S = { DropInSetDown = 1 } })
    W.press() W.till(function() return W.DI.state == "wait" end, 5) W.run(0.5)
    W.notogUntil = 0 W.onb, W.mode, W.bmode = false, 0, 5        -- the game steps him off although the toggle guard was up
    W.frame(1)
    W.till(function() return W.onb end, 4)
    local m = W.t
    W.till(function() return W.DI.state == "out" end, 4)
    local o = W.t
    W.till(function() return W.DI.state == "wait" end, 4)
    check(string.format("[fix] stepped off after a set-down and put back by the mod's own mount: the board's parts are taken %.2f s after that mount (0.15 + the 0.3 s a teleport gets), and the slide out still takes DropInSetOutTime (%.2f s)",
        o - m, W.t - o), W.has("put back on, try 1 of 2") ~= nil and o - m >= 0.44 and o - m < 0.60 and near(W.t - o, 0.35, 0.05) and W.DI.state == "wait" and W.DI.sd == true, W)
end
do local W = dworld({ S = { DropInSetDown = 1, DropInAlignTime = 0 } })
    W.press() toWait(W, 5)
    check(string.format("[fix] DropInAlignTime 0, a set-down that stands right: no teleport after it (%d), SET", W.teleports),
        W.DI.state == "wait" and W.teleports == 0 and W.has("no first move after the set-down: the board is taken where it stands") ~= nil, W)
    W = dworld({ S = { DropInSetDown = 1, DropInAlignTime = 0 } })   -- a switch set-down in which the game does NOT turn him at its mount: he stands half a turn wrong
    W.press() W.run(0.15) W.press() toWait(W, 6)
    check(string.format("DropInAlignTime 0, a set-down that stands half a turn wrong: the one teleport, as before (%d), SET", W.teleports),
        W.DI.state == "wait" and W.teleports == 1 and W.has("stood square to the edge, the board's middle") ~= nil, W)
    W = dworld({ S = { DropInAlignTime = 0 }, W = { gameMountTo = { far = 0, turn = 0 } } })
    W.press() toWait(W, 6)
    check(string.format("DropInAlignTime 0, the old way (DropInSetDown 0), mounted on the spot itself: build 210's one teleport is still made (%d), SET", W.teleports),
        W.DI.state == "wait" and W.teleports == 1 and W.has("stood square to the edge, the board's middle") ~= nil, W)
end

out[#out + 1] = string.format("%d checks", nchecks)
local o = assert(io.open("fix211_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the review fixes' test failed: see fix211_out.txt", 0) end

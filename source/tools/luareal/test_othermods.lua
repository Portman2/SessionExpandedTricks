-- test_othermods.lua: the tail that copies what the other mods say into the mod's own log (NATIVE.STW / stwHit / stwTail
-- and its 50 ms loop) and the "map:" line of the 2 s loop, cut out of main.lua and run in real Lua.
--   luareal -run test_othermods.lua result.txt main.lua   (writes omtest_out.txt)
-- Run it in an EMPTY folder: it writes SessionTweaks.log and SessionOpenMP.log there (and refuses to start where
-- either is already present, so it can never touch a game folder's own). Two files may be put beside it first,
-- real_SessionTweaks.log and real_SessionOpenMP.log (copies of a session's logs): they are then played through the tail.
local TW, OMP = "SessionTweaks.log", "SessionOpenMP.log"
do local t, o = io.open(TW, "rb"), io.open(OMP, "rb")
    if t then t:close() end if o then o:close() end
    assert(not t and not o, "run this test in an EMPTY folder: a SessionTweaks.log or SessionOpenMP.log is already here")
end
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local function at(s, from, what) return assert(src:find(s, from, true), what .. " was not found") end
local s0 = at("local function sizeOf(path)\n", 1, "sizeOf")
local s1 = at("\nend\n", s0, "sizeOf's end") + #"\nend\n"
local a = at("NATIVE.STW = { n = 0, files = {", s1, "the tail's start")
local b = at("LoopAsync(50, function()", a, "the tail's loop")
local c = at("end   -- controller", b, "the controller block's end")
assert(src:sub(a, c):find("LoopAsync(POLL_MS", 1, true) == nil and at("LoopAsync(POLL_MS, function() pcall(pollController) return false end)", s1, "the pad's loop") < a, "the tail is not after the pad's loop")
local tailSrc = "local NATIVE, TWKLOG, log = ...\n" .. src:sub(s0, s1 - 1) .. "\n" .. src:sub(a, b - 1) .. "\nreturn NATIVE"
local loopSrc = "local NATIVE, logOnce, LoopAsync = ...\n" .. src:sub(b, c - 1)
local m0 = at("        local live = false\n        pcall(function()\n            if active and alive(cached) then", c, "the 2 s loop's skater part")
local m1 = at("        if NATIVE.updateTick then pcall(NATIVE.updateTick, live) end", m0, "the 2 s loop's skater part's end")
local mapSrc = "local W, q, log = ...\nlocal active, cached, mesh, s0, myAddr = false, nil, nil, nil, W.myAddr\n"
    .. "local function alive(x) return x end\nlocal function addr(o) return o and o.addr end\n"
    .. "local function refs() s0 = W.skater return s0 ~= nil end\n"
    .. "local NATIVE = { forgetWorld = function(why) W.forgot[#W.forgot + 1] = why s0 = nil end }\n"
    .. "local function ensureHook() W.hooked = W.hooked + 1 end\n" .. src:sub(m0, m1 - 1) .. "\nW.myAddr = myAddr return live"

local made = {}
local function put(path, text, mode) local h = assert(io.open(path, mode or "ab")) h:write(text) h:close() made[path] = true end
local function gone(path) if made[path] then os.remove(path) made[path] = nil end end
local function size(path) local h = io.open(path, "rb") if not h then return nil end local n = h:seek("end") h:close() return n end
local function world(tw, omp)                              -- the two logs as they are when the mod loads (nil = not there)
    gone(TW) gone(OMP)
    if tw then put(TW, tw, "wb") end
    if omp then put(OMP, omp, "wb") end
    local W = { logs = {} }
    W.N = assert(load(tailSrc, "=tail", "t", setmetatable({}, { __index = _G })))({}, TW, function(s) W.logs[#W.logs + 1] = s end)
    W.look = function(n) for _ = 1, (n or 1) do W.N.stwTail() end end
    W.pos = function(i) return W.N.STW.files[i].pos end
    return W
end
local out = {}
local function check(name, cond, W) out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        out[#out + 1] = string.format("       %d lines copied; positions %s / %s; sizes %s / %s", #W.logs, tostring(W.pos(1)), tostring(W.pos(2)), tostring(size(TW)), tostring(size(OMP)))
        for i = 1, math.min(#W.logs, 12) do out[#out + 1] = "       log: " .. W.logs[i]:sub(1, 200) end
    end
    return cond end
local all = true
local F1 = "[23:30:15.358] [quad] pump faulted (1) -- dropped our cached state, will rebuild on the next dress"
local F2 = "[23:30:15.562] [quad] pump faulted (2) -- dropped our cached state, will rebuild on the next dress"
local STALE = "[23:19:50.718] SessionTweaks 3.19.607\r\n" .. F1 .. "\r\n[23:30:15.400] [cloth] merge #14 from exe+0xfe7907 (another skater): 5 sources\r\n" .. F2 .. "\r\n"

-- A. THE FIRST LOOK SKIPS WHAT IS ALREADY THERE (a log of the session before, its owner switched off)
do local W = world(STALE, nil)
    W.look(3)
    all = check("A: a log that is already there is not told again: nothing copied, the place is its end", #W.logs == 0 and W.pos(1) == #STALE, W) and all
    put(TW, "[23:41:00.000] [cloth] merge #1\r\n" .. F1 .. "\r\n")
    W.look()
    all = check("A: a fault line written after that is copied, whole, with whose it is", #W.logs == 1 and W.logs[1] == "SessionTweaks said: " .. F1, W) and all
    W.look(3)
    all = check("A: ...and once only", #W.logs == 1 and W.pos(1) == size(TW), W) and all
    -- B. A PARTIAL LAST LINE IS KEPT FOR THE NEXT LOOK
    local before = W.pos(1)
    put(TW, "[23:30:15.562] [quad] pump fau")
    W.look(2)
    all = check("B: half a line: nothing copied, the place not moved", #W.logs == 1 and W.pos(1) == before, W) and all
    put(TW, "lted (2) -- dropped our cached state, will rebuild on the next dress\r\n")
    W.look()
    all = check("B: ...its other half arrives: the whole line is copied", #W.logs == 2 and W.logs[2] == "SessionTweaks said: " .. F2, W) and all
    put(TW, "[23:41:02.000] [cloth] new character -- dressing from scratch\r\n[23:41:02.001] [quad] pump faul")
    W.look()
    all = check("B: a whole line and half of the next in one look: the whole one only", #W.logs == 3 and W.logs[3]:find("new character", 1, true) ~= nil and W.pos(1) == size(TW) - #"[23:41:02.001] [quad] pump faul", W) and all
    put(TW, "ted (3)\n")
    W.look()
    all = check("B: ...and the half once it is whole (a bare LF ends a line too)", #W.logs == 4 and W.logs[4] == "SessionTweaks said: [23:41:02.001] [quad] pump faulted (3)", W) and all
    -- C. A LOG THAT STARTED AGAIN IS READ FROM ITS START
    put(TW, "[23:50:00.000] SessionTweaks 3.19.607\r\n[23:50:07.000] [sit] replay mode 1 -> 0\r\n[23:50:07.001] [sit] replay mode 0 -> 1\r\n", "wb")
    W.look()
    all = check("C: a log that is shorter than it was has started again: read from byte 0", #W.logs == 5 and W.logs[5] == "SessionTweaks said: [23:50:07.000] [sit] replay mode 1 -> 0" and W.pos(1) == size(TW), W) and all
    W.look(3)
    all = check("C: ...and not read twice", #W.logs == 5, W) and all
end
-- D. a log that is not there: no error; once it is there, its first look starts at its end
do local W = world(nil, nil)
    local ok = pcall(W.look, 3)
    all = check("D: no logs at all: no error, nothing copied", ok and #W.logs == 0 and W.pos(1) == nil and W.pos(2) == nil, W) and all
    put(OMP, "[23:19:57.969] [mod] own pawn = 00000201500B8D40\n")
    W.look()
    all = check("D: a log that appears: its first look starts at its end", #W.logs == 0 and W.pos(2) == size(OMP) and W.pos(1) == nil, W) and all
    put(OMP, "[23:22:40.964] [mod] own pawn = 0000020136C28D40 (via PlayerController 00000201376EB700 +0x250, IsLocallyControlled confirmed)\n")
    W.look()
    all = check("D: ...and what is written after that is copied", #W.logs == 1 and W.logs[1]:find("SessionOpenMP said: [23:22:40.964] [mod] own pawn = 0000020136C28D40", 1, true) == 1, W) and all
end
-- E. THE WORDS. SessionOpenMP: "fault" in either case, not as the end of "default", not as a count
do local W = world("", "")
    W.look()
    local yes = { "[drop/map] the dropper applied this player's save -- captured 0 map default(s)",
                  "[mod] own pawn = 000002015E8A0DC0 (via PlayerController 00000201538D9BA0 +0x250, IsLocallyControlled confirmed)",
                  "[proxy] spawn FAULTED code=0xC0000005 at=00007FF6 (try 1) -- half-built actor",
                  "[maps] transit map: adding custom maps faulted -- the screen is unchanged",
                  "[net] the default route, then a fault in the relay",
                  "[net] 12 FAULTS in a row",
                  "fault" }
    local no = { "[cfg] the default port is 7777", "[cfg] DEFAULT settings loaded", "[cfg] Defaulted to english", "[menu] defaults restored",
                 "[audio] d=1 started=2 stopped=2 nfyMuted=0 locMuted=0 noCue=0 faults=0", "[drop] map default seam", "own  pawn", "[x] nothing here", "de" }
    local t = {}
    for i = 1, math.max(#yes, #no) do if no[i] then t[#t + 1] = no[i] end if yes[i] then t[#t + 1] = yes[i] end end
    put(OMP, table.concat(t, "\r\n") .. "\r\n")
    W.look()
    local good = #W.logs == #yes
    for i = 1, #yes do good = good and W.logs[i] == "SessionOpenMP said: " .. yes[i] end
    all = check("E: SessionOpenMP: its level-change and fault lines are copied, 'default' and 'faults=0' are not", good, W) and all
end
do local W = world("", "")
    W.look()
    local yes = { "[23:19:58.047] [catch] the left trigger read faulted (0xc0000005 at exe+0x30868c6, player input 0000020123238200)",
                  "[cloth] the dress FAULTED -- cloth off", "[scoop] caught fatal in InputHandler::Tick", "[23:22:40.895] [sit] replay mode 1 -> 0",
                  "[cloth] slot 0: its garment component is gone (destroyed by a re-dress) -- forgetting it and asking for a fresh dress",
                  "[cloth] new character -- dressing from scratch", "[cloth] slave garment component BUILT (00000201326D8080) for slot 0 on skater 0000020136C28D40" }
    local no = { "[fsr] FAILED: ffx runtime load", "[sit] replay mode 0 -> 1", "[catch] key 'Gamepad_FaceButton_Top' pressed, onBoard=1", "[cfg] a default value",
                 "[cfg] defaulted to 3", "[mod] own pawn = 1", "[sit] state: movement 3/0, foot->board 0, board->foot 0, onBoard 0" }
    put(TW, table.concat(no, "\n") .. "\n" .. table.concat(yes, "\n") .. "\n")
    W.look()
    local good = #W.logs == #yes
    for i = 1, #yes do good = good and W.logs[i] == "SessionTweaks said: " .. yes[i] end
    all = check("E: SessionTweaks: each of its seven words is taken, other lines are not (nor SessionOpenMP's words in it)", good, W) and all
    -- F. a long line is cut to 200 characters
    put(TW, "[x] pump faulted " .. string.rep("y", 500) .. "\n")
    W.look()
    all = check("F: a long line is cut to 200 characters", #W.logs == #yes + 1 and #W.logs[#W.logs] == #"SessionTweaks said: " + 200, W) and all
end
-- G. 500 lines a session, and that is said once
do local W = world("", "")
    W.look()
    local t = {}
    for i = 1, 300 do t[#t + 1] = "[x] pump faulted (" .. i .. ")" end
    put(TW, table.concat(t, "\n") .. "\n") put(OMP, table.concat(t, "\n") .. "\n")
    W.look()
    all = check("G: 600 fault lines: 500 copied and one line that no more are", #W.logs == 501 and W.logs[500]:find("SessionOpenMP said: [x] pump faulted (200)", 1, true) == 1 and W.logs[501]:find("500 of their lines", 1, true) ~= nil, W) and all
    put(TW, "[x] pump faulted (again)\n") W.look(2)
    all = check("G: ...and nothing after that, the places still kept up", #W.logs == 501 and W.pos(1) == size(TW), W) and all
end
-- H. a quarter megabyte without a line end is passed over, quickly; what follows is read
do local W = world("", nil)
    W.look()
    put(TW, string.rep("x", 300000))
    local t0 = os.clock() W.look() local took = os.clock() - t0
    all = check(string.format("H: 300 000 bytes with no line end: 262 144 passed over, in %.3f s", took), #W.logs == 0 and W.pos(1) == 262144 and took < 2, W) and all
    W.look()
    all = check("H: ...the rest waits for its line end", W.pos(1) == 262144, W) and all
    put(TW, "\n" .. F1 .. "\n") W.look()
    all = check("H: ...and the line after it is copied", #W.logs == 1 and W.logs[1] == "SessionTweaks said: " .. F1 and W.pos(1) == size(TW), W) and all
end
-- I. more than a quarter megabyte of lines in one go: read over two looks, nothing lost, nothing twice
do local W = world("", nil)
    W.look()
    local t = {}
    for i = 1, 6000 do t[#t + 1] = (i % 100 == 0) and string.format("[%05d] [quad] pump faulted -- a line of sixty bytes, more or less...", i) or string.format("[%05d] [cloth] merge from exe+0xfe7907 (another skater): 5 srcs", i) end
    local text = table.concat(t, "\r\n") .. "\r\n"
    put(TW, text) W.look()
    local n1, p1 = #W.logs, W.pos(1)
    W.look(2)
    local good = #W.logs == 60
    for i = 1, 60 do good = good and W.logs[i] ~= nil and W.logs[i]:find(string.format("said: [%05d] ", i * 100), 1, true) ~= nil end
    all = check(string.format("I: %d bytes of lines: %d copied in the first look (to byte %d), all 60 after the second, in order", #text, n1, p1), good and n1 > 0 and n1 < 60 and p1 <= 262144 and W.pos(1) == #text, W) and all
end
-- J. the loop: every 50 ms, goes on for ever, an error in the look is logged once and not raised
do local got, once, calls = nil, {}, 0
    local N = { stwTail = function() calls = calls + 1 end }
    assert(load(loopSrc, "=loop", "t", setmetatable({}, { __index = _G })))(N, function(k, m) once[#once + 1] = k .. "|" .. m end, function(ms, fn) got = { ms = ms, fn = fn } end)
    local r1 = got and got.fn()
    all = check("J: the look is on a 50 ms loop that goes on (its function returns false)", got ~= nil and got.ms == 50 and r1 == false and calls == 1 and #once == 0) and all
    N.stwTail = function() error("boom") end
    local ok, r2 = pcall(got.fn)
    all = check("J: an error in the look is logged and not raised", ok and r2 == false and #once == 1 and once[1]:find("stwerr|", 1, true) == 1 and once[1]:find("boom", 1, true) ~= nil) and all
end
-- K. THE MAP LINE of the 2 s loop: one a new skater
do local W = { myAddr = nil, forgot = {}, hooked = 0, logs = {} }
    local q = function(fn, d) local ok, v = pcall(fn) if ok and v ~= nil then return v end return d end   -- (main.lua's own)
    local run = assert(load(mapSrc, "=twosec", "t", setmetatable({}, { __index = _G })))
    local function go() return run(W, q, function(s) W.logs[#W.logs + 1] = s end) end
    local TF = "PBP_SkaterCharacter_C /Game/CustomMaps/Noksy/TrainingFacility_V3.TrainingFacility_V3:PersistentLevel.PBP_SkaterCharacter_C_2147482518"
    W.skater = { addr = 0x1000, GetFullName = function() return TF end }
    local live = go()
    all = check("K: the first skater: its map is said", live == true and W.myAddr == 0x1000 and #W.logs == 1 and W.logs[1] == "map: " .. TF and #W.forgot == 0 and W.hooked == 1) and all
    go() go()
    all = check("K: the same skater two looks on: not said again", #W.logs == 1 and W.hooked == 3) and all
    W.skater = { addr = 0x2000, GetFullName = function() return "PBP_SkaterCharacter_C /Game/CustomMaps/Honza/Chkvc/Map/Cakovice.Cakovice:PersistentLevel.PBP_SkaterCharacter_C_1" end }
    live = go()
    all = check("K: a new skater: the level change is taken and the new map said", live == true and W.myAddr == 0x2000 and #W.forgot == 1 and W.forgot[1] == "a new skater" and #W.logs == 2 and W.logs[2]:find("Cakovice", 1, true) ~= nil) and all
    W.skater = nil
    live = go()
    all = check("K: the skater gone: no map line", live == false and W.myAddr == nil and W.forgot[2] == "your skater is gone" and #W.logs == 2) and all
    W.skater = { addr = 0x3000, GetFullName = function() error("dead object") end }
    live = go()
    all = check("K: a skater whose name cannot be read: said as '?', and the mod goes on with it", live == true and W.myAddr == 0x3000 and #W.logs == 3 and W.logs[3] == "map: ?" and W.hooked == 5) and all
end
-- L. a session's real logs, when copies are beside the test: played through the tail a piece at a time
do local rt, ro = io.open("real_SessionTweaks.log", "rb"), io.open("real_SessionOpenMP.log", "rb")
    if rt and ro then
        local tt, to = rt:read("a"), ro:read("a")
        local W = world("", "")
        W.look()
        local function play(path, text, piece) local p = 1 while p <= #text do put(path, text:sub(p, p + piece - 1)) p = p + piece W.look() end end
        play(TW, tt, 7001) local nt = #W.logs
        play(OMP, to, 997) local no = #W.logs - nt
        local known = (#tt == 989749 and #to == 24901)                 -- the logs of 9 Oct 23:19-23:30: 21 and 9 lines by hand (grep)
        all = check(string.format("L: the real logs (%d and %d bytes) through the tail in pieces: %d of SessionTweaks' lines and %d of SessionOpenMP's copied%s",
            #tt, #to, nt, no, known and " (21 and 9 counted by hand)" or " (other logs than 9 Oct's: not compared)"),
            W.pos(1) == #tt and W.pos(2) == #to and (not known or (nt == 21 and no == 9)), W) and all
        for i = 1, #W.logs do out[#out + 1] = "       " .. W.logs[i]:sub(1, 150) end
    else out[#out + 1] = "skip L: no copies of a session's real logs beside the test" end
    if rt then rt:close() end if ro then ro:close() end
end
gone(TW) gone(OMP)

local o = assert(io.open("omtest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the other mods' logs test failed: see omtest_out.txt", 0) end

-- test_loop212.lua (build 212, mk212_loop.pl): the 2 s loop that found "a new skater" every two seconds, and the look
-- for the board's deck that got nothing the second time. Cut out of main.lua and run in real Lua against a stand-in
-- for the game: main.lua's own q / alive, its walk gate, skater(), addr(), refs(), findFlipper(), forgetWorld(),
-- boardParts() and the skater part of the 2 s loop -- all as they stand in the file, none re-written here.
--   luareal -run test_loop212.lua result.txt main.lua   (writes loop212_out.txt)
-- Run on build 211's main.lua the checks marked [fix] must FAIL (18 of the 41) and the others pass: that is what
-- shows they look at the thing fixed. A is the loop of 10 Oct 09:49:17 to 09:55:06 itself (on build 211: a level
-- change more at every turn, the old address held); F is that day's "given once more, as always (0 parts)".
-- The stand-in is a model of the game, not the game.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local function at(s, from, what) return assert(src:find(s, from, true), what .. " was not found") end
local function cut(from, to, what) local a = at(from, 1, what) local b = at(to, a, what .. "'s end") return src:sub(a, b - 1) end
local helpers = cut("local function q(fn, d)", "\nlocal function log(s)", "q and alive")
local gate    = cut("NATIVE.WK = { n = 0, no = 0 }", "\n-- THE REVERT SOUND of our 180s.", "the walk gate, skater, addr and refs")
local deck    = cut("local BD = { comp = nil, maxAir = 0 }", "\nlocal function boardPitch()", "findFlipper")
local forget  = cut("NATIVE.forgetWorld = function(why)", "\n-- THE BOARD HOP (v78).", "forgetWorld")
local partsL  = cut("    local PARTS = { \"Flipper\"", "\n", "the board's part names")
local parts   = cut("    local function boardParts()\n", "    NATIVE.boardParts = boardParts", "boardParts")
local loop    = cut("        local live = false\n        pcall(function()\n            if active and alive(cached) then",
                    "        if NATIVE.updateTick then pcall(NATIVE.updateTick, live) end", "the 2 s loop's skater part")
local chunk = "local W, log, logOnce = ...\n"
    .. "local cached, s0, mesh, inst, mv = nil, nil, nil, nil, nil\n"            -- (main.lua's own file-level names)
    .. "local active, t0, myAddr = false, 0, nil\n"
    .. "local NATIVE = { live = true, mute = function() end }\n"
    .. "local VS, SB, RV, liftBroken, revertSnap = {}, {}, { pending = false }, {}, {}\n"
    .. helpers .. "\n" .. gate .. "\n" .. deck .. "\n" .. forget .. "\n" .. partsL .. "\n" .. parts .. "\n"
    .. "local function ensureHook() W.hooked = W.hooked + 1 return true end\n"
    .. "W.N, W.BD = NATIVE, BD\n"
    .. "W.tick = function()\n" .. loop .. "\n    return live\nend\n"
    .. "W.refs = function() return refs() end\n"
    -- what a click, a bumper or a hop does once it has the skater (main.lua: "myAddr = addr(s0)" before ensureHook)
    .. "W.take = function() if not refs() then return false end myAddr = addr(s0) return true end\n"
    .. "W.my = function() return myAddr end\n"
    .. "W.held = function() return cached end\n"
    .. "W.findFlipper, W.boardParts = findFlipper, boardParts\n"

local function obj(a) return { a = a, dead = false, GetAddress = function(self) return self.a end, IsValid = function(self) return not self.dead end } end
local function world()
    local W = { t = 100, logs = {}, once = {}, walks = 0, gc = 0, busy = 0, hooked = 0, stood = 0, skaters = {}, boards = {}, unmapped = {} }
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    -- the engine's "a purge is on" flags: 0 / 1 / -1, or a function of how many times they have been read
    env.HJN_GcBusy = function() W.gc = W.gc + 1 if type(W.busy) == "function" then return W.busy(W.gc) end return W.busy end
    env.HJN_Readable = function(a) return W.unmapped[a] and 0 or 1 end
    env.HJN_SetMesh = function(m) if m == 0 then W.stood = W.stood + 1 if W.onForget then W.onForget() end end return 1 end
    env.HJN_SetPC = function() return 1 end
    env.HJN_Set = function() return 0 end
    env.HJN_TrickMute = function() return 0 end
    local function live(list) local o = {} for _, x in ipairs(list) do if not x.dead then o[#o + 1] = x end end return o end
    env.FindAllOf = function(cn)
        W.walks = W.walks + 1
        if cn == "SkaterCharacter" then return live(W.skaters) end
        if cn == "PBP_SkateboardEx_C" then return live(W.boards) end
        return {}
    end
    env.FindFirstOf = function(cn) W.walks = W.walks + 1 if cn == "SkaterCharacter" then return live(W.skaters)[1] end return nil end
    local pcls = obj(0x50)
    env.StaticFindObject = function() return pcls end
    local fn = assert(load(chunk, "=loop212", "t", env))
    fn(W, function(s) W.logs[#W.logs + 1] = s end, function(k, s) if not W.once[k] then W.once[k] = true W.logs[#W.logs + 1] = s end end)
    W.spawn = function(a, name)
        local s, m, i, v = obj(a), obj(a + 0x10), obj(a + 0x20), obj(a + 0x30)
        m.GetAnimInstance = function() return i end
        s.Mesh, s.GetSkaterMovement = m, function() return v end
        s.IsPlayerControlled = function() return true end
        s.GetFName = function() return { ToString = function() return "Skater" end } end
        s.GetFullName = function() return name end
        s.K2_GetActorLocation = function() return { X = 0, Y = 0, Z = 0 } end
        W.skaters[#W.skaters + 1] = s
        return s
    end
    -- a map change takes the old skater: its object is dead and its memory given back (alive() asks the native half first)
    W.kill = function(s) s.dead, s.Mesh.dead = true, true W.unmapped[s.a] = true end
    W.board = function(a)
        local owner, list = obj(a), {}
        for k, name in ipairs({ "Flipper", "TruckHangerFront", "TruckHangerBack", "WheelFront_L", "WheelFront_R", "WheelBack_L", "WheelBack_R" }) do
            local c = obj(a + k)
            c.GetFName = function() return { ToString = function() return name end } end
            c.K2_GetComponentLocation = function() return { X = W.deckX or 10, Y = 0, Z = 0 } end   -- (build 218: a case can put the board far off)
            c.GetOwner = function() return owner end
            list[#list + 1] = { get = function() return c end }
        end
        owner.K2_GetComponentsByClass = function() return list end
        owner.GetFName = function() return { ToString = function() return W.boardName or "Skateboard" end } end   -- (build 218: the ridden board's own name; a co-op peer's is numbered)
        W.boards[#W.boards + 1] = owner
        return owner
    end
    W.count = function(pat) local n = 0 for _, l in ipairs(W.logs) do if tostring(l):find(pat, 1, true) then n = n + 1 end end return n end
    W.turn = function() W.t = W.t + 2 return W.tick() end                  -- the loop's next turn, 2 s on
    return W
end

local out, all, nchecks = {}, true, 0
local function check(name, cond, W)
    nchecks = nchecks + 1
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then all = false
        for _, l in ipairs(W and W.logs or {}) do out[#out + 1] = "       log: " .. tostring(l):sub(1, 200) end
    end
    return cond
end
local NYC = "Session_BP_Mod_Loader_C /Game/Art/Env/NYC/NYC01_BH_Persistent.NYC01_BH_Persistent:PersistentLevel.Skater"
local LUX = "Session_BP_Mod_Loader_C /Game/CustomMaps/EMU/LUX/LUX01_PEI_Persistent.LUX01_PEI_Persistent:PersistentLevel.Skater"

-- A. THE LOOP OF 10 OCT: a map change so quick that no turn of the loop sees a moment without a skater. The turn's first
-- look finds the new skater; what it held is dropped; the look after the drop decides what the next turn finds
do local W = world()
    local a = W.spawn(0x1000, NYC)
    local live = W.tick()
    check("A: the first skater: taken, its map said, nothing dropped", live == true and W.my() == 0x1000 and W.count("map: ") == 1 and W.count("level change") == 0 and W.hooked == 1, W)
    live = W.turn()
    check("A: the same skater 2 s on: no look through the game's objects, nothing said", live == true and W.walks == 1 and #W.logs == 1, W)
    W.kill(a) W.spawn(0x2000, LUX)
    live = W.turn()
    check("[fix] A: the new map's skater, found by the turn's first look: taken IN THAT TURN (address, map line, the mod live)",
        live == true and W.my() == 0x2000 and W.count("level change (a new skater)") == 1 and W.count("map: ") == 2 and W.logs[#W.logs] == "map: " .. LUX, W)
    check("[fix] A: ...the look that found it holds no later look back (NATIVE.WK.skAt is clear)", W.N.WK.skAt == nil, W)
    local n1 = W.count("level change")
    for _ = 1, 5 do live = W.turn() end
    out[#out + 1] = string.format("       level changes: %d in the turn that found the new skater, %d five turns on; native half stood down %d times; the mod holds %s",
        n1, W.count("level change"), W.stood, tostring(W.my()))
    check("[fix] A: ...and five turns on still ONE level change (build 211: one more every turn, the old address held, never live)",
        live == true and W.count("level change") == 1 and W.stood == 1 and W.my() == 0x2000 and W.count("map: ") == 2, W)
    check("[fix] A: ...the old skater's things were dropped once and the new skater's taken (cached = the new one)", W.held() ~= nil and W.held().a == 0x2000, W)
end
-- B. THE PURGE COMES ON BETWEEN THE TURN'S TWO LOOKS (the engine clears objects out on another thread: HJN_GcBusy 0 at
-- the first look, 1 from the second on). No walk may be made then: the purge rule stays as it is
do local W = world()
    local a = W.spawn(0x1000, NYC)
    W.tick()
    W.kill(a) W.spawn(0x2000, LUX)
    local g0 = W.gc
    W.busy = function(n) return (n > g0 + 1) and 1 or 0 end
    local w0 = W.walks
    local live = W.turn()
    check("B: the purge on at the second look: no walk is made for it (one walk in the turn: the first look's)", W.walks == w0 + 1 and W.count("the engine is clearing objects out") == 1, W)
    check("[fix] B: ...one level change, and the mod holds NO skater -- not the old one", live == false and W.count("level change (a new skater)") == 1 and W.my() == nil and W.held() == nil, W)
    live = W.turn()
    check("[fix] B: the purge still on a turn later: nothing more is dropped or said (build 211: 'your skater is gone', a second level change)",
        live == false and W.count("level change") == 1 and W.stood == 1 and W.my() == nil and W.walks == w0 + 1, W)
    W.busy = 0
    live = W.turn()
    check("[fix] B: the purge over: the skater is taken, its map said, the mod live -- still ONE level change",
        live == true and W.my() == 0x2000 and W.count("level change") == 1 and W.count("map: ") == 2 and W.logs[#W.logs] == "map: " .. LUX, W)
    for _ = 1, 3 do live = W.turn() end
    check("[fix] B: ...and it stays so", live == true and W.count("level change") == 1 and W.count("map: ") == 2 and W.my() == 0x2000, W)
end
-- B2. the same, the purge over again by the next turn (build 211: the first look finds the skater again, the old
-- address is still held, and the loop of A begins)
do local W = world()
    local a = W.spawn(0x1000, NYC)
    W.tick()
    W.kill(a) W.spawn(0x2000, LUX)
    local g0 = W.gc
    W.busy = function(n) return (n > g0 + 1) and 1 or 0 end
    W.turn()
    W.busy = 0
    local live
    for _ = 1, 5 do live = W.turn() end
    out[#out + 1] = string.format("       level changes five turns after a second look the purge refused: %d", W.count("level change"))
    check("[fix] B2: the second look refused by the purge, the purge over at the next turn: one level change in all, the new skater held",
        live == true and W.count("level change") == 1 and W.my() == 0x2000 and W.count("map: ") == 2, W)
end
-- C. the look after the drop finds the skater, but its mesh is not there (refs() says no for another reason than a
-- refused look): the same way out
do local W = world()
    local a = W.spawn(0x1000, NYC)
    W.tick()
    W.kill(a)
    local b = W.spawn(0x2000, LUX)
    W.onForget = function() b.Mesh.dead = true end                         -- (gone by the time the forget has run)
    local live = W.turn()
    W.onForget = nil
    check("[fix] C: the new skater's mesh gone at the second look: one level change, no skater held, no map line yet",
        live == false and W.count("level change") == 1 and W.my() == nil and W.count("map: ") == 1, W)
    b.Mesh.dead = false
    live = W.turn()
    check("[fix] C: the mesh there a turn later: taken, map said, still one level change (build 211: a second one)",
        live == true and W.my() == 0x2000 and W.count("level change") == 1 and W.count("map: ") == 2, W)
end
-- D. THE MAP LINE IS OWED TO THE SKATER, whoever takes its address first: a click or a bumper on the new map before
-- the loop comes round (they write myAddr themselves)
do local W = world()
    local a = W.spawn(0x1000, NYC)
    W.tick()
    W.kill(a)
    local live = W.turn()
    check("D: the skater gone, none there yet: 'your skater is gone', once", live == false and W.my() == nil and W.count("level change (your skater is gone)") == 1 and W.count("map: ") == 1, W)
    live = W.turn()
    check("D: ...and not again while there is none", live == false and W.count("level change") == 1, W)
    W.spawn(0x2000, LUX)
    W.t = W.t + 0.7
    check("D: a click on the new map takes the skater before the loop does", W.take() == true and W.my() == 0x2000, W)
    live = W.turn()
    check("[fix] D: the loop's next turn: no second level change, and the new map's line is written all the same",
        live == true and W.count("level change") == 1 and W.count("map: ") == 2 and W.logs[#W.logs] == "map: " .. LUX, W)
    live = W.turn()
    check("[fix] D: ...once", live == true and W.count("map: ") == 2, W)
end
-- E. THE WALK GATE WITH THE LOOK FOR THE SKATER BEHIND IT (test_doubles.lua's walk-gate checks, with skater() itself
-- asking): what the half second is for stays, what it cost goes
do local W = world()
    check("E: no skater (the menus): the look is made -- two walks (all of them, then the first)", W.refs() == false and W.walks == 2, W)
    for _ = 1, 5 do W.t = W.t + 0.08 W.refs() end
    check("E: ...five more calls in the next 0.4 s: no walk at all", W.walks == 2, W)
    W.t = W.t + 0.2
    check("E: ...0.6 s after the first: looked for again", W.refs() == false and W.walks == 4, W)
    local s = W.spawn(0x1000, NYC)
    W.t = W.t + 0.6
    check("E: a skater is there: found (one walk), and kept", W.refs() == true and W.walks == 5 and W.held() == s, W)
    W.t = W.t + 0.05
    check("E: ...asked again while it lives: no walk", W.refs() == true and W.walks == 5, W)
    W.kill(s)
    local s2 = W.spawn(0x2000, LUX)
    check("[fix] E: that skater gone and another there 0.05 s after the look that FOUND the first: looked for and found (build 211: 'spaced', nobody)",
        W.refs() == true and W.held() == s2 and W.walks == 6, W)
    W.t = W.t + 0.6
    check("E: ...0.6 s on it is the one held (on either build)", W.refs() == true and W.held() == s2, W)
    W.kill(s2)
    W.t = W.t + 0.6
    local w = W.walks
    check("E: gone again, nobody there: the look is made (two walks) and finds nobody", W.refs() == false and W.walks == w + 2, W)
    W.t = W.t + 0.1
    check("E: ...and THAT look holds the next one back: no walk 0.1 s on", W.refs() == false and W.walks == w + 2, W)
    W.t = W.t + 0.5
    W.busy = 1
    check("E: a purge on: the skater is not looked for either, and it is said once", W.refs() == false and W.walks == w + 2 and W.count("the engine is clearing objects out") == 1, W)
    W.busy = -1                                                            -- the flags cannot be read: the 8 s rule, bar the look for the skater
    W.N.WK.lvlAt = W.t
    W.t = W.t + 3
    check("E: the flags not readable, 3 s after a level change: no other walk, but the skater is looked for",
        W.N.all("X") == nil and W.refs() == false and W.walks == w + 4, W)
end
-- F. THE DECK: boardParts drops the deck it holds and looks again at every call; the board hop gives the board its
-- speed, gives it once more 60 ms on, and again every 0.2 s if the game took it back (10 Oct: "(7 parts ...)", then
-- "given once more, as always (0 parts)" at 64 to 67 ms, four hops of four)
do local W = world()
    W.spawn(0x1000, NYC) W.board(0x7000)
    W.refs()
    local w0 = W.walks
    local p = W.boardParts()
    check("F: the board's parts are found: seven of them, the deck first", p ~= nil and #p == 7 and p[1] == 0x7001 and W.walks == w0 + 1, W)
    local got = {}
    for _, dt in ipairs({ 0.066, 0.2, 0.2, 0.2 }) do W.t = W.t + dt local p2 = W.boardParts() got[#got + 1] = p2 and #p2 or 0 end
    out[#out + 1] = "       parts found 66, 266, 466 and 666 ms after the first look: " .. table.concat(got, ", ")
    check("[fix] F: asked again 66 ms on (the hop's 'given once more'): seven parts again (build 211: none -- '(0 parts)')", got[1] == 7, W)
    check("[218] F: ...and at 266 and 466 ms (the watch's 'AGAIN: the game had taken it back'): seven parts each time, and NO walk more -- the deck that is kept is the one by you (10 cm off)",
        got[2] == 7 and got[3] == 7 and got[4] == 7 and W.walks == w0 + 1, W)
    W.deckX = 900                                                          -- the board 9 m off (another's, or left behind): looked for again
    local pf = W.boardParts()
    check("[218] F: the kept deck 9 m from you: dropped and looked for again (one walk)", pf ~= nil and #pf == 7 and W.walks == w0 + 2, W)
    W.deckX = nil
    W.boardName = "Skateboard_2"                                           -- the deck that is kept is a co-op peer's (10 cm off): not kept
    local wq = W.walks
    local pq = W.boardParts()
    check("[218] F: a kept deck whose board is not named 'Skateboard' (a co-op peer's): looked for again at every call (one walk), as before build 218", pq ~= nil and #pq == 7 and W.walks == wq + 1, W)
    W.boardName = nil
    W.boards[1].dead = true                                                -- the board gone (no deck anywhere)
    if W.BD.comp then W.BD.comp.dead = true end
    W.t = W.t + 0.6
    local w1 = W.walks
    check("F: no board there: looked for, not found", W.findFlipper() == nil and W.walks == w1 + 1, W)
    W.t = W.t + 0.1
    check("F: ...a look that found none is not made again at once", W.findFlipper() == nil and W.boardParts() == nil and W.walks == w1 + 1, W)
    W.t = W.t + 0.5
    W.board(0x8000)
    check("F: ...0.6 s on it is, and the new board's deck is found", W.findFlipper() ~= nil and W.findFlipper().a == 0x8001 and W.walks == w1 + 2, W)
    W.busy = 1
    do local pp = W.boardParts()
    check("[218] F: a purge on: no walk is made -- and none is needed, the kept deck's parts are given", pp ~= nil and #pp == 7 and pp[1] == 0x8001 and W.walks == w1 + 2, W) end
    W.busy = 0
    local p3 = W.boardParts()
    check("[fix] F: the purge over, at once: found (neither the look that found the deck nor the one the purge refused holds it back)",
        p3 ~= nil and #p3 == 7 and p3[1] == 0x8001 and W.walks == w1 + 2, W)   -- (build 218: the kept deck, no walk)
end
-- G. WHAT ENDED THE LOOP ON BUILD 211 (10 Oct 09:55:04.8: a stick click looked for the skater between two turns and
-- found it; "L3: ignored -- not rolling on the ground", so it did not write the address), and forgetWorld's own word
-- on the half second
do local W = world()
    local a = W.spawn(0x1000, NYC)
    W.tick()
    W.kill(a) W.spawn(0x2000, LUX)
    W.t = W.t + 1.2
    check("G: a click between two turns finds the new skater; the address held is still the old one's", W.refs() == true and W.held().a == 0x2000 and W.my() == 0x1000, W)
    W.t = W.t + 0.8
    local live = W.tick()
    check("G: the loop's next turn: one level change, the new skater taken (on build 211 as well: this is how its loop ended)",
        live == true and W.my() == 0x2000 and W.count("level change") == 1 and W.count("map: ") == 2, W)
end
do local W = world()
    local a = W.spawn(0x1000, NYC)
    W.tick()
    W.kill(a) W.spawn(0x2000, LUX)
    W.t = W.t + 1.9
    W.refs()                                                               -- the new skater is held and alive, the address the old one's
    W.N.WK.skAt = W.t                                                      -- (not so on build 212 while a skater is held: put there to show forgetWorld's line by itself)
    W.t = W.t + 0.1
    local live = W.tick()
    check("[fix] G: the forget drops a skater that lives: the half second is not counted against the look after it",
        live == true and W.my() == 0x2000 and W.count("level change") == 1 and W.N.WK.skAt == nil, W)
end

out[#out + 1] = string.format("%d checks", nchecks)
local o = assert(io.open("loop212_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the 2 s loop's test failed: see loop212_out.txt", 0) end

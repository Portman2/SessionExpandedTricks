-- test_td_review.lua (review of build 218): the trick display's "is it still the game's" check, cut out of main.lua
-- and run in real Lua against a stand-in for UE4SS 3.0.1 as its DLL reads (the review's disassembly of UE4SS.dll):
--   StaticFindObject(path) = UE4SS's own table path -> object (a hit hands the pointer back); a path not in it is
--     found by a WALK over every object, and what is found is put in the table; an object's entry goes when the
--     engine frees the object (bUseUObjectArrayCache on: W.listeners)
--   IsValid = the pointer is there, the object is not unreachable, and its address is in UE4SS's list of the objects
--     it has handed to Lua (every wrapper made adds it; the engine's "deleted" notice takes it out)
--   FindAllOf = a walk
-- main.lua's own q / alive, walk gate, addr, TD .. tdLive, tdBail and the head of trickNameTick, none re-written.
--   luareal -run test_td_review.lua result.txt <main.lua>     (writes td_review_out.txt)
-- Run on the candidate (l218.lua) it prints what the candidate does; run on the review's l218_td.lua the [rec]
-- checks must pass. The stand-in is a model, not the game.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local REC = src:find("TD.same = function(o, full)", 1, true) ~= nil
local function at(s, from, what) return assert(src:find(s, from, true), what .. " was not found") end
local function cut(from, to, what) local a = at(from, 1, what) local b = at(to, a, what .. "'s end") return src:sub(a, b - 1) end
local helpers = cut("local function q(fn, d)", "\nlocal function log(s)", "q and alive")
local gate    = cut("NATIVE.WK = { n = 0, no = 0 }", "\nlocal function skater()", "the walk gate")
local td      = cut("local TD = { w = nil", "\n-- a game line under the mod's: push it up one tier", "TD .. tdLive")
local bail    = cut("NATIVE.tdBail = function()", "\ntrickName = function(text)", "tdBail")
local tick    = cut("trickNameTick = function(now)", "    tdLaterTick(now)", "trickNameTick's head")
local chunk = "local W, log, logOnce = ...\n"
    .. "local NATIVE, SB, S, s0 = {}, {}, { TrickNames = 1 }, nil\n"
    .. helpers .. "\n" .. gate .. "\n"
    .. "local function addr(o) return q(function() return o:GetAddress() end, nil) end\n"
    .. td .. "\n" .. bail .. "\n"
    .. "local trickNameTick\n" .. tick .. "\n    return true\nend\n"
    .. "W.N, W.TD, W.SB = NATIVE, TD, SB\n"
    .. "W.find, W.live, W.tickFn = tdFind, tdLive, trickNameTick\n"

local CN = "PBP_TrickDisplayWidget_C"
local function world()
    local W = { t = 100, logs = {}, once = {}, walks = 0, missWalks = 0, hits = 0, busy = 0, listeners = true,
                mem = {}, luaSet = {}, cache = {}, order = {}, freedRead = 0, num = 2147482414 }
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    env.HJN_GcBusy = function() return W.busy end
    env.HJN_Readable = function(a) return (a and a > 65536) and 1 or 0 end
    -- a wrapper: a pointer and nothing else. What it says is what stands at its address NOW
    local function wrap(a)
        if a ~= 0 then W.luaSet[a] = true end
        local w = { a = a }
        local function o() return W.mem[a] end
        w.GetAddress = function() return a end
        w.IsValid = function() local x = o() return a ~= 0 and not (x and x.unreachable) and W.luaSet[a] == true end
        w.GetFullName = function()
            local x = o()
            if not x then W.freedRead = W.freedRead + 1 error("access violation: the name of freed memory was read", 0) end
            return x.cls .. " " .. x.path
        end
        w.GetFName = function() local x = o() return { ToString = function() return x and x.short or "None" end } end
        w.GetOwningPlayer = function() local x = o() return wrap(x and x.owner or 0) end
        w.IsInViewport = function() local x = o() return x and x.inViewport == true end
        return setmetatable(w, { __index = function(_, k)
            local x = o() if not x then return nil end
            local v = x[k]
            if type(v) == "table" and v.isObj then return wrap(v.a) end
            return v
        end })
    end
    W.wrap = wrap
    W.new = function(a, cls, path, extra)
        local x = { isObj = true, a = a, cls = cls, path = path, short = path:match("[^%.:]+$") }
        for k, v in pairs(extra or {}) do x[k] = v end
        W.mem[a] = x W.order[#W.order + 1] = x
        return x
    end
    W.free = function(x)                                   -- the engine frees it: its memory, UE4SS's Lua list, UE4SS's path table
        if W.mem[x.a] == x then W.mem[x.a] = nil end
        W.luaSet[x.a] = nil
        if W.listeners then for p, o in pairs(W.cache) do if o == x then W.cache[p] = nil end end end
        x.freed = true
    end
    env.FindAllOf = function(cn)
        W.walks = W.walks + 1
        local out = {}
        for _, x in ipairs(W.order) do if not x.freed and x.cls == cn then out[#out + 1] = wrap(x.a) end end
        return out
    end
    env.StaticFindObject = function(path)
        local c = W.cache[path]
        if c then W.hits = W.hits + 1 return wrap(c.a) end
        W.walks, W.missWalks = W.walks + 1, W.missWalks + 1
        for _, x in ipairs(W.order) do if not x.freed and x.path == path then W.cache[path] = x return wrap(x.a) end end
        return wrap(0)
    end
    local fn = assert(load(chunk, "=td_review", "t", env))
    fn(W, function(s) W.logs[#W.logs + 1] = s end, function(k, s) if not W.once[k] then W.once[k] = true W.logs[#W.logs + 1] = s end end)
    -- the game: a player controller, the display class, one display on the screen
    W.cls = W.new(0x100000, "WidgetBlueprintGeneratedClass", "/Game/UI/" .. CN .. "." .. CN)
    W.pc = W.new(0x200000, "PBP_PlayerController_C", "/Game/Maps/M.M:PersistentLevel.PC_1", { _trickDisplayWidgetBlueprint = W.cls })
    W.wbl = W.new(0x300000, "WidgetBlueprintLibrary", "/Script/UMG.Default__WidgetBlueprintLibrary")
    W.cache[W.wbl.path] = W.wbl                            -- (looked up once at the start of a run and never freed: in UE4SS's table from then on)
    W.display = function(a)
        W.num = W.num - 1
        local path = "/Engine/Transient.GameEngine_2147482624:SessionGameInstance_C_2147482615." .. CN .. "_" .. W.num
        local panel = W.new(a + 0x1000, "CanvasPanel", path .. ".WidgetTree_0.Panel")
        local line = W.new(a + 0x2000, "WidgetBlueprintGeneratedClass", "/Game/UI/Line.Line_C")
        return W.new(a, CN, path, { owner = W.pc.a, inViewport = true, _trickDisplayPanel = panel, _trickDisplayTextBlueprint = line, panel = panel })
    end
    W.kill = function(d) W.free(d.panel) W.free(d) end
    W.SB.pc = wrap(W.pc.a)
    W.count = function(pat) local n = 0 for _, l in ipairs(W.logs) do if tostring(l):find(pat, 1, true) then n = n + 1 end end return n end
    W.secs = function(n) local ok = true for _ = 1, n do W.t = W.t + 1.01 W.tickFn(W.t) if not W.TD.w then ok = false end end return ok end
    return W
end

local out, all, nchecks = {}, true, 0
local function say(s) out[#out + 1] = "       " .. s end
local function check(name, cond, W)
    nchecks = nchecks + 1
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then all = false
        for _, l in ipairs(W and W.logs or {}) do out[#out + 1] = "       log: " .. tostring(l):sub(1, 230) end
    end
    return cond
end
out[#out + 1] = REC and "the file under test is the review's recommended form (TD.same)" or "the file under test is the CANDIDATE (by path, proven at find time): its numbers are printed, the [rec] checks are not made"
local function rec(name, cond, W) if REC then check("[rec] " .. name, cond, W) end end

-- A. the first name of a run: the display is found
do local W = world()
    local d = W.display(0x400000)
    local ok = W.find()
    say(string.format("A: found %s; walks over every object: %d (of them by StaticFindObject: %d); 'looks' counted by the mod: %d", tostring(ok), W.walks, W.missWalks, W.N.WK.n))
    check("A: the display is found", ok == true and W.TD.w ~= nil and W.TD.w.a == d.a, W)
    rec("A: one walk, and it is counted", W.walks == 1 and W.missWalks == 0 and W.N.WK.n == 1, W)
    -- B. sixty seconds of the once-a-second check
    local w0, n0 = W.walks, W.N.WK.n
    local held = W.secs(60)
    say(string.format("B: 60 s held: %s; walks: %d; 'looks' counted by the mod: %d; table hits: %d; freed memory read: %d", tostring(held), W.walks - w0, W.N.WK.n - n0, W.hits, W.freedRead))
    check("B: the display is held for the minute, no walk", held and W.walks == w0 and W.freedRead == 0, W)
    rec("B: ...and no 'look' is counted for a check that walked nothing", W.N.WK.n == n0, W)
    rec("B: ...and the log has the display's own name once", W.count("was asked its name -- '" .. CN .. " /Engine/Transient.") == 1, W)
    -- C. a bail; the game keeps its display; the next name
    W.N.tdBail() W.t = W.t + 5
    w0 = W.walks
    local m0 = W.missWalks
    ok = W.find()
    say(string.format("C: after a bail, the same display: found %s; walks: %d (by StaticFindObject: %d)", tostring(ok), W.walks - w0, W.missWalks - m0))
    check("C: found again, the same one", ok == true and W.TD.w.a == d.a, W)
    rec("C: no walk at all", W.walks == w0, W)
    rec("C: the log says how", W.count("the one held before the bail") == 1 and W.count("asked its name 6") == 1, W)
end
-- D. a bail; the game takes its display off the screen and makes a new one; the old one is not collected yet
do local W = world()
    local d = W.display(0x400000) W.find() W.secs(3)
    W.N.tdBail()
    d.inViewport = false
    local d2 = W.display(0x500000)
    W.t = W.t + 5
    local w0, m0 = W.walks, W.missWalks
    local ok = W.find()
    say(string.format("D: after a bail, a NEW display (the old one off the screen, not freed): found %s at %s; walks: %d (by StaticFindObject: %d)", tostring(ok), W.TD.w and string.format("0x%x", W.TD.w.a) or "?", W.walks - w0, W.missWalks - m0))
    check("D: the new display is the one taken", ok == true and W.TD.w.a == d2.a, W)
    rec("D: one walk (the old one said 'not on the screen')", W.walks - w0 == 1, W)
end
-- E. a bail; the old display is freed before the next name
do local W = world()
    local d = W.display(0x400000) W.find() W.secs(3)
    W.N.tdBail()
    W.kill(d)
    local d2 = W.display(0x500000)
    W.t = W.t + 5
    local w0, m0 = W.walks, W.missWalks
    local ok = W.find()
    say(string.format("E: after a bail, the old display freed: found %s; walks: %d (by StaticFindObject: %d); freed memory read: %d", tostring(ok), W.walks - w0, W.missWalks - m0, W.freedRead))
    check("E: the new display is taken, nothing of the freed one is read", ok == true and W.TD.w.a == d2.a and W.freedRead == 0, W)
    rec("E: one walk", W.walks - w0 == 1, W)
end
-- F. the display is freed while it is held (no bail, no level change seen)
do local W = world()
    local d = W.display(0x400000) W.find() W.secs(3)
    W.kill(d)
    local w0 = W.walks
    local r = W.live()                                     -- (the frame's own alive(TD.panel) stops the tick before this; the check is asked directly)
    say(string.format("F: freed while held: the check says %s; walks: %d; freed memory read: %d", tostring(r), W.walks - w0, W.freedRead))
    check("F: the check says no, no walk, and no name of freed memory is read", r == false and W.walks == w0 and W.freedRead == 0, W)
end
-- G. freed, and another object now stands at its address, one UE4SS has handed to Lua (IsValid says yes again)
do local W = world()
    local d = W.display(0x400000) W.find() W.secs(3)
    W.kill(d)
    W.new(0x400000, "TextBlock", "/Engine/Transient.GameEngine_2147482624:SessionGameInstance_C_2147482615.Other_1.WidgetTree_0.TextBlock_7")
    W.new(0x401000, "CanvasPanel", "/Engine/Transient.GameEngine_2147482624:SessionGameInstance_C_2147482615.Other_1.WidgetTree_0.Canvas_2")
    W.wrap(0x400000) W.wrap(0x401000)
    local w0 = W.walks
    W.t = W.t + 1.01 W.tickFn(W.t)
    say(string.format("G: another object at its address: forgotten %s; walks: %d; said: %s", tostring(W.TD.w == nil), W.walks - w0, tostring(W.logs[#W.logs]):sub(1, 200)))
    check("G: it is forgotten", W.TD.w == nil, W)
    rec("G: no walk, and the line says what stands there", W.walks == w0 and W.count("now calls itself 'TextBlock ") == 1, W)
end
-- H. freed, and a NEW DISPLAY of the same class stands at its address (the walk of builds 145-217 could not tell these apart)
do local W = world()
    local d = W.display(0x400000) W.find() W.secs(3)
    W.kill(d)
    W.display(0x400000)
    W.wrap(0x400000) W.wrap(0x401000)
    local w0 = W.walks
    W.t = W.t + 1.01 W.tickFn(W.t)
    say(string.format("H: a new display at the old one's address: forgotten %s; walks: %d", tostring(W.TD.w == nil), W.walks - w0))
    check("H: it is forgotten (its panel and its lines are the old display's)", W.TD.w == nil, W)
    rec("H: no walk", W.walks == w0, W)
end
-- I. the engine is clearing objects out: nothing is asked, the display is taken as still there
do local W = world()
    local d = W.display(0x400000) W.find()
    W.busy = 1
    local w0 = W.walks
    local held = W.secs(5)
    say(string.format("I: purge on for 5 s: held %s; walks: %d", tostring(held), W.walks - w0))
    check("I: held, no walk", held and W.walks == w0, W)
end
-- J. UE4SS's path table is never cleared (bUseUObjectArrayCache = 0), the display is freed, another Lua-known object takes its address
do local W = world()
    W.listeners = false
    local d = W.display(0x400000) W.find() W.secs(3)
    W.kill(d)
    W.display(0x400000)
    W.wrap(0x400000) W.wrap(0x401000)
    W.t = W.t + 1.01 W.tickFn(W.t)
    say(string.format("J: bUseUObjectArrayCache = 0, a new display at the old address: forgotten %s", tostring(W.TD.w == nil)))
    rec("J: it is forgotten", W.TD.w == nil, W)
end

out[#out + 1] = string.format("%d checks", nchecks)
local o = assert(io.open("td_review_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the trick display test failed: see td_review_out.txt", 0) end

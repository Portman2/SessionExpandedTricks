-- test_stutter218.lua (build 218 as it ships: mk218c.pl): THE STUTTER. "When I do a grab I get a micro freeze every ~10
-- seconds and eventually it stops" (the Steam tester, 13 Oct): the looks through EVERY object of the game that fell on
-- frames of play. What is checked is that they are gone, and that what they were for is still done:
--   A  tdFind keeps what the trick display calls itself (TD.full = its GetFullName) and looks nothing up by that name
--   B  tdLive: the object is asked its own name, with no walk and no look-up; by the walk as before where it gave none
--   C  trickNameTick's once-a-second check over 10 s of frames with the display held; a freed display and one whose
--      name changed are seen within a second
--   D  the name is forgotten with the widget (NATIVE.forgetUi, a bail, a level change); what a bail kept is asked
--      first by the next name (still the same, on the screen, this player's = no walk; anything else = one walk)
--   E  readAdvanced: a hop takes the kept value; the look is the pause menu's, once as it comes up and once as it goes
--   F  boardParts keeps the deck while it is YOUR board's (its actor is named "Skateboard") and within 4 m of you
--   G  NATIVE.slow / NATIVE.timed / NATIVE.gtDrain: a frame or a queued action the mod's own work makes long is said
-- Cut out of main.lua and run in real Lua against a stand-in for the game: main.lua's own q / alive, its game-thread
-- queue, its walk gate and timing, skater(), addr(), refs(), findFlipper(), readAdvanced(), the whole of the trick
-- names (tdFind, tdLive, tdBail, trickName, trickNameTick ...), forgetWorld(), boardParts(), the frame hook's
-- registration, the pause menu's watch and its 250 ms timer -- all as they stand in the file, none re-written here.
--   luareal -run test_stutter218.lua result.txt main.lua   (writes stutter218_out.txt)
-- Run on build 217's main.lua the checks marked [fix] must FAIL (92 of the 166) and the others pass: that is what
-- shows they look at the thing fixed. On build 218's main.lua as it stood on 13 Oct (l218f.lua) ONE check fails, and
-- it is the build's: D's "a SECOND bail before any name of the mod's" -- NATIVE.tdBail takes TD.kept from TD.w, which
-- is nil at a second bail, so what the first bail kept is thrown away and the next name walks (see the note there).
-- The lines that begin with spaces are not checks: they say what was counted, and
-- what the build does in cases nobody has ruled on. The stand-in is a model of the game, not the game: an object is a
-- table that stands for the memory at its address (freed = IsValid false, and whatever else is asked of it then is
-- counted as a read of freed memory; "another object at its address" = the same table under another class and name);
-- FindAllOf gives every object of a class that is not freed, a new Lua object for each at every call. Whether the
-- game's own objects answer as the stand-in does (the ridden board's actor named exactly "Skateboard", the options
-- object there as a pause menu goes) is what the mod's own log lines say at run time, and no test can.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local function at(s, from, what) return assert(src:find(s, from, true), what .. " was not found") end
local function cut(from, to, what) local a = at(from, 1, what) local b = at(to, a, what .. "'s end") return src:sub(a, b - 1) end
local helpers = cut("local function q(fn, d)", "\nlocal function log(s)", "q and alive")
local queue   = cut("NATIVE.GT = { q = {} }", "\n-- (v210) THE GAME'S OBJECTS ARE NOT WALKED WHILE", "the mod's own game-thread queue")
local gate    = cut("NATIVE.WK = { n = 0, no = 0 }", "\n-- THE REVERT SOUND of our 180s.", "the walk gate, the timing, skater, addr and refs")
local deck    = cut("local BD = { comp = nil, maxAir = 0 }", "\nlocal function boardPitch()", "findFlipper")
local adv     = cut("local advCache = {}", "\n-- once per session: the game's own numbers", "readAdvanced")
local td      = cut("local TD = { w = nil, panel = nil, cls = nil, pc = nil, wbl = nil,",
                    "\n------------------------------------------------------------------- stance swap: same-frame yaw", "the trick names")
local forget  = cut("NATIVE.forgetWorld = function(why)", "\n-- THE BOARD HOP (v78).", "forgetWorld")
local partsL  = cut("    local PARTS = { \"Flipper\"", "\n", "the board's part names")
local parts   = cut("    local function boardParts()\n", "    NATIVE.boardParts = boardParts", "boardParts")
local hook    = cut("local hooked = false\nensureHook = function()\n", "    if hooked and not bankHooked then", "the frame hook's registration")
local menu    = cut("NATIVE.mg = { proven = false }", "\nNATIVE.speed = { applied", "the pause menu's watch and its 250 ms timer")
local chunk = "local W, log, logOnce = ...\n"
    .. "local cached, s0, mesh, inst, mv = nil, nil, nil, nil, nil\n"            -- (main.lua's own file-level names)
    .. "local active, t0, myAddr = false, 0, nil\n"
    .. "local NATIVE = { live = true, mute = function() end }\n"
    .. "local VS, SB, RV, liftBroken, revertSnap = {}, {}, { pending = false }, {}, {}\n"
    .. "local S = { TrickNames = 1 }\n"
    .. "local MODE_RIDING, MODE_AIR, MODE_BAILING = 1, 2, 5\n"
    .. "local function modeNow() return W.mode end\n"
    .. "NATIVE.rawMode = function() return W.mode end\n"
    .. "local HOOK, ensureHook = \"the frame hook\", nil\n"
    .. "local function onFrame(ctx) return W.onFrame(ctx) end\n"
    .. "local function onFramePost(ctx) return W.onFramePost(ctx) end\n"
    .. helpers .. "\n" .. queue .. "\n" .. gate .. "\n" .. deck .. "\n" .. adv .. "\n"
    .. "local trickName, trickNameLater, trickNameTick, trickNameHide\n"
    .. td .. "\n" .. forget .. "\n" .. partsL .. "\n" .. parts .. "\n"
    .. hook .. "end\n"
    .. menu .. "\n"
    .. "W.N, W.BD, W.TD, W.M, W.addr = NATIVE, BD, TD, NATIVE.mg, addr\n"
    .. "W.refs = function() return refs() end\n"
    .. "W.tdFind, W.tdLive, W.boardParts, W.findFlipper, W.readAdvanced = tdFind, tdLive, boardParts, findFlipper, readAdvanced\n"
    .. "W.trickName = function(text) return trickName(text) end\n"
    .. "W.tick = function(now) return trickNameTick(now) end\n"
    .. "W.ensureHook = function() return ensureHook() end\n"

local CN  = "PBP_TrickDisplayWidget_C"                                         -- the trick display's class (the controller's _trickDisplayWidgetBlueprint)
local PKG = "/Engine/Transient.GameEngine_2147482624:SessionGameInstance_C_2147482615."
local PATH, PATH2, PATH3 = PKG .. CN .. "_2147482414", PKG .. CN .. "_2147481977", PKG .. CN .. "_2147481320"
local OTHER = PKG .. "PBP_PauseMenu_C_2147481502.WidgetTree_0.TextBlock_7"     -- some other object's path
local function fullOf(path, cls) return (cls or CN) .. " " .. path end         -- GetFullName: "<class> <path>"
local FULL = fullOf(PATH)
local ADV = "BodyRotationRateMultiplier"
local function obj(a) return { a = a, dead = false, GetAddress = function(self) return self.a end, IsValid = function(self) return not self.dead end } end
-- what UE4SS hands out: another Lua object for the same game object at every call (it says what stands at the address NOW)
local function again(o) return setmetatable({}, { __index = o }) end
local function world(opts)
    local W = { t = 100, logs = {}, once = {}, nAll = 0, nFirst = 0, nStatic = 0, nPath = 0, nName = 0, freedRead = 0, all = {}, first = {}, paths = {},
                gc = 0, busy = 0, mode = 1, skaters = {}, boards = {}, widgets = {}, unmapped = {}, hooks = {}, egt = {}, loops = {}, next = 0x900000 }
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    if not (opts and opts.noGc) then                                           -- (noGc: beside a native half that has no HJN_GcBusy)
        env.HJN_GcBusy = function() W.gc = W.gc + 1 return W.busy end          -- the engine's "a purge is on" flags: 0 / 1, -1 = they cannot be read
    end
    env.HJN_Readable = function(a) return W.unmapped[a] and 0 or 1 end
    env.HJN_SetMesh = function() return 1 end
    env.HJN_SetPC = function() return 1 end
    env.HJN_Set = function() return 0 end
    env.HJN_TrickMute = function() return 0 end
    env.FText = function(s) return s end
    env.RegisterHook = function(name, pre, post) W.hooks[#W.hooks + 1] = { name = name, pre = pre, post = post } end
    env.ExecuteInGameThread = function(fn) W.egt[#W.egt + 1] = fn end          -- UE4SS runs it later, on the game thread: W.serve()
    env.LoopAsync = function(ms, fn) W.loops[#W.loops + 1] = { ms = ms, fn = fn } end   -- UE4SS's timers: kept, run by the test
    local function live(list) local o = {} for _, x in ipairs(list) do if not x.dead then o[#o + 1] = x end end return o end
    -- THE LOOKS THROUGH EVERY OBJECT OF THE GAME: counted, with what was asked for (W.lookCost: the seconds one takes)
    W.cdo = obj(0x40)
    W.cdo.GetFullName = function() return CN .. " /Game/UI/HUD/PBP_TrickDisplayWidget.Default__" .. CN end
    env.FindAllOf = function(cn)
        W.nAll = W.nAll + 1 W.all[#W.all + 1] = cn
        if W.lookCost then W.t = W.t + W.lookCost end
        if cn == "SkaterCharacter" then return live(W.skaters) end
        if cn == "PBP_SkateboardEx_C" then return live(W.boards) end
        local o = {}
        if cn == CN then o[1] = W.cdo end
        for _, w in ipairs(W.widgets) do if not w.dead and w.cls == cn then o[#o + 1] = again(w) end end
        return o
    end
    env.FindFirstOf = function(cn)
        W.nFirst = W.nFirst + 1 W.first[#W.first + 1] = cn
        if W.lookCost then W.t = W.t + W.lookCost end
        if cn == "SkaterCharacter" then return live(W.skaters)[1] end
        if cn == "OptionsSaveGame" then return W.opts end
        return nil
    end
    -- THE LOOK-UP BY NAME: every call is counted (nStatic). The two engine objects the mod asks for by a fixed name are
    -- in UE4SS's table from the start of a run; ANY OTHER path is counted apart (nPath) and found by nobody -- in
    -- UE4SS 3.0.1 a path it has not found before is a walk over every object, so the mod must not ask for one
    W.pcls, W.wbl = obj(0x50), obj(0x60)
    env.StaticFindObject = function(path)
        W.nStatic = W.nStatic + 1
        if path == "/Script/Engine.PrimitiveComponent" then return W.pcls end
        if path == "/Script/UMG.Default__WidgetBlueprintLibrary" then return W.wbl end
        W.nPath = W.nPath + 1 W.paths[#W.paths + 1] = path
        return nil
    end
    local fn = assert(load(chunk, "=stutter218", "t", env))
    fn(W, function(s) W.logs[#W.logs + 1] = s end, function(k, s) if not W.once[k] then W.once[k] = true W.logs[#W.logs + 1] = s end end)
    -- the player's controller, with the trick display's class and (W.menuUp) the pause menu that is up; another player's
    W.pc, W.pc2 = obj(0x3000), obj(0x3800)
    do local bp = obj(0x3100)
        bp.GetFName = function() return { ToString = function() return CN end } end
        W.pc._trickDisplayWidgetBlueprint = bp
    end
    W.spawn = function(a)
        local s, m, i, v = obj(a), obj(a + 0x10), obj(a + 0x20), obj(a + 0x30)
        m.GetAnimInstance = function() return i end
        s.Mesh, s.GetSkaterMovement = m, function() return v end
        s.IsPlayerControlled = function() return true end
        s.GetFName = function() return { ToString = function() return "Skater" end } end
        s.GetFullName = function() return "Session_BP_Mod_Loader_C /Game/Art/Env/NYC/NYC01_BH_Persistent.NYC01_BH_Persistent:PersistentLevel.Skater" end
        s.GetController = function() return W.pc end
        s.K2_GetActorLocation = function() if W.noHere then error("where you are cannot be read") end return { X = 0, Y = 0, Z = 0 } end
        W.skaters[#W.skaters + 1] = s
        return s
    end
    -- the game's trick display: the widget (it calls itself "<class> <path>"), its panel of lines, the lines' class.
    --   w.noName  "raise" = its GetFullName raises an error, "" = it gives an empty name
    --   w.inView  on the screen or not ("raise" = the question raises an error);  w.owner  whose it is
    -- Asked for its name, its owner or the screen while it is freed = a read of freed memory (counted: in the game
    -- that is an access violation inside UE4SS, not a Lua error)
    W.hud = function(a, path, owner)
        local w, panel, cls = obj(a), obj(a + 0x100), obj(a + 0x200)
        panel.kids = {}
        panel.GetChildrenCount = function(self) return #self.kids end
        panel.GetChildAt = function(self, i) return self.kids[i + 1] end
        panel.AddChild = function(self, line)
            local slot = obj(line.a + 1)
            slot.y = 0
            slot.GetSize = function() return { X = 300, Y = 30 } end
            slot.SetPosition = function(sl, p) sl.y = p.Y end
            slot.GetPosition = function(sl) return { X = 0, Y = sl.y } end
            slot.SetAlignment = function() end
            line.Slot = slot
            line.RemoveFromParent = function(l) for i, k in ipairs(self.kids) do if k == l then table.remove(self.kids, i) break end end end
            self.kids[#self.kids + 1] = line
            return slot
        end
        local function freed(self) if self.dead then W.freedRead = W.freedRead + 1 error("access violation: freed memory was read", 0) end end
        w.cls, w.path, w.owner, w.inView = CN, path, owner or W.pc, true
        w.GetFullName = function(self)
            W.nName = W.nName + 1                                              -- (every time a display is asked its name)
            freed(self)
            if self.noName == "raise" then error("GetFullName raised", 0) end
            if self.noName then return self.noName end
            return self.cls .. " " .. self.path
        end
        w.GetOwningPlayer = function(self) freed(self) return self.owner end
        w.IsInViewport = function(self) freed(self) if self.inView == "raise" then error("IsInViewport raised", 0) end return self.inView end
        w._trickDisplayPanel, w._trickDisplayTextBlueprint = panel, cls
        w.NumberOfTiers, w.MaxTextDuration, w.MinTextScale, w.MaxTextScale = 3, 3, 0.5, 1
        w.MinTextAlpha, w.MaxTextAlpha, w.TrickDisplayTextWidgetPadding = 0.3, 1, 4
        W.widgets[#W.widgets + 1] = w
        W.panel = panel
        return w
    end
    -- the engine frees a display (and, unless keepPanel, its panel in the same purge)
    W.kill = function(w, keepPanel) w.dead = true if not keepPanel then w._trickDisplayPanel.dead = true end end
    -- ...and another object is made where it was (and one where its panel was), which UE4SS has handed to Lua: IsValid
    -- says yes again at that address, under another class and / or another name
    W.reuse = function(w, cls, path) w.dead, w.cls, w.path = false, cls, path w._trickDisplayPanel.dead = false end
    W.wbl.Create = function()                                                  -- UWidgetBlueprintLibrary::Create: a new text line
        W.next = W.next + 0x10
        local line, tb = obj(W.next), obj(W.next + 2)
        tb.SetText = function(self, t) self.text = t end
        tb.GetText = function(self) return { ToString = function() return self.text end } end
        line._text, line.op = tb, 1
        line.IsA = function() return true end
        line.SetRenderScale = function() end
        line.SetRenderOpacity = function(l, v) l.op = v end
        line.GetRenderOpacity = function(l) return l.op end
        line.SetVisibility = function() end
        line.RenderTransform = { Scale = { X = 1 } }
        return line
    end
    -- the game's UOptionsSaveGame, there or not (W.opts): the Advanced numbers of the active preset
    W.options = function(v, idx)
        local o = obj(0x5000)
        o.AdvancedSettingsPresets = { ActivePresetIndex = idx or 0, Presets = {} }
        o.AdvancedSettingsPresets.Presets[(idx or 0) + 1] = { [ADV] = v }
        W.opts = o
        return o
    end
    -- a pause menu comes up (the controller's _activePauseMenuPageContainer; it has the pad's focus) / goes
    W.menuUp = function(a)
        local c = obj(a)
        c.HasUserFocus = function() return true end
        c.HasUserFocusedDescendants = function() return false end
        c.SetUserFocus = function() end
        W.pc._activePauseMenuPageContainer = c
        return c
    end
    W.menuDown = function() W.pc._activePauseMenuPageContainer = nil end
    W.watch = function(n, key) for _ = 1, n do W.t = W.t + 0.25 W.N.menuWatch(key) end end   -- the look four times a second
    -- a board: its actor (named "Skateboard" unless told otherwise; name = false: the name cannot be read) and its
    -- seven parts. pos = where its deck is (a table the test may change); without one, W.deckX / deckY / deckZ
    W.board = function(a, name, pos)
        local owner, list = obj(a), {}
        owner.name, owner.pos = (name == nil) and "Skateboard" or name, pos
        owner.GetFName = function(self)
            if self.name == false then error("the board's name cannot be read") end
            return { ToString = function() return self.name end }
        end
        for k, part in ipairs({ "Flipper", "TruckHangerFront", "TruckHangerBack", "WheelFront_L", "WheelFront_R", "WheelBack_L", "WheelBack_R" }) do
            local c = obj(a + k)
            c.GetFName = function() return { ToString = function() return part end } end
            c.K2_GetComponentLocation = function()                             -- the board, from you (who stand at 0,0,0)
                local p = owner.pos
                if p then return { X = p.X, Y = p.Y, Z = p.Z } end
                return { X = W.deckX or 10, Y = W.deckY or 0, Z = W.deckZ or 0 }
            end
            c.GetOwner = function() return owner end
            list[#list + 1] = { get = function() return c end }
        end
        owner.K2_GetComponentsByClass = function() return list end
        W.boards[#W.boards + 1] = owner
        return owner
    end
    W.count = function(pat) local n = 0 for _, l in ipairs(W.logs) do if tostring(l):find(pat, 1, true) then n = n + 1 end end return n end
    W.last = function(pat) for i = #W.logs, 1, -1 do if tostring(W.logs[i]):find(pat, 1, true) then return tostring(W.logs[i]) end end return "" end
    W.walks = function() return W.nAll + W.nFirst end                      -- every look through all the game's objects so far
    W.frames = function(secs, fps)                                         -- that many seconds of frames: the frame hook's call of trickNameTick
        for _ = 1, math.floor(secs * fps + 0.5) do W.t = W.t + 1 / fps W.tick(W.t) end
    end
    W.till = function(pred, secs, fps)                                     -- frames until pred() says yes -> the seconds it took (nil: it never did)
        local from = W.t
        for _ = 1, math.floor(secs * fps + 0.5) do W.t = W.t + 1 / fps W.tick(W.t) if pred() then return W.t - from end end
        return nil
    end
    W.serve = function() local l = W.egt W.egt = {} for _, fn in ipairs(l) do fn() end end   -- UE4SS runs what was handed to ExecuteInGameThread
    return W
end
-- a skater, his controller and the game's trick display on screen
local function hudWorld(opts)
    local W = world(opts)
    W.spawn(0x1000) W.hud(0x4000, PATH)
    W.refs()
    return W
end
local function has(s, pat) return type(s) == "string" and s:find(pat, 1, true) ~= nil end
local function ends(s, tail) return type(s) == "string" and #s >= #tail and s:sub(-#tail) == tail end

local out, all, nchecks, nfail, nfixfail, nfix = {}, true, 0, 0, 0, 0
local function check(name, cond, W)
    nchecks = nchecks + 1
    local fix = name:sub(1, 5) == "[fix]"
    if fix then nfix = nfix + 1 end
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then
        all, nfail = false, nfail + 1
        if fix then nfixfail = nfixfail + 1 end
        local L = W and W.logs or {}
        for i = math.max(1, #L - 9), #L do out[#out + 1] = "       log: " .. tostring(L[i]):sub(1, 260) end
    end
    return cond
end
local function note(s) out[#out + 1] = "       " .. s end
local BYNAME = "; checked once a second by asking it its own name (no look through the game's objects)"
local BYWALK = "; checked once a second by a look through all the game's objects (it gave no name)"
local BYLOOK, BYKEPT = "; found by a look through the game's objects", "; the one held before the bail (asked: still there, on the screen, this player's) -- no look through the game's objects"
local USING, REBUILT = "trick names: using " .. CN, "the game rebuilt its trick display"

-- A. WHAT THE DISPLAY CALLS ITSELF IS KEPT WHEN IT IS FOUND: tdFind walks once (as before), keeps the widget's own
-- GetFullName in TD.full for the once-a-second check, and looks NOTHING up by that name
do local W = hudWorld()
    local a0, k0 = W.nAll, W.N.WK.n
    local ok = W.tdFind()
    check("A: the display is found by one look through the game's objects (as before, and counted as one) and held",
        ok == true and W.TD.w ~= nil and W.addr(W.TD.w) == 0x4000 and W.nAll == a0 + 1 and W.all[#W.all] == CN and W.N.WK.n == k0 + 1, W)
    check("[fix] A: what it calls itself is kept for the once-a-second check: TD.full is its GetFullName", W.TD.full == FULL, W)
    check("A: that name is NOT looked up: no StaticFindObject call for anything but the widget library, TD.path stays nil", W.nPath == 0 and W.TD.path == nil, W)
    local line = W.last(USING)
    check("[fix] A: the 'trick names: using' line ends with how it was found (a look) and how it is checked (asked its own name)", ends(line, BYLOOK .. BYNAME), W)
    note("the line: " .. line:sub(1, 260))
end
do  -- the trick names' own code, as it stands in the file: the only thing it asks StaticFindObject for
    local n, bad, from, want = 0, 0, 1, "\"/Script/UMG.Default__WidgetBlueprintLibrary\")"
    while true do
        local a, b = td:find("StaticFindObject(", from, true)
        if not a then break end
        n = n + 1
        if td:sub(b + 1, b + #want) ~= want then bad = bad + 1 end
        from = b + 1
    end
    check("A: in the file, the trick names' code calls StaticFindObject for the widget library and for nothing else", n >= 1 and bad == 0)
end
for _, how in ipairs({ "raise", "" }) do
    local W = hudWorld()
    W.widgets[1].noName = how
    local what = (how == "raise") and "raises an error" or "gives an empty name"
    local ok = W.tdFind()
    check("A: its GetFullName " .. what .. ": the display is held all the same, TD.full stays nil", ok == true and W.addr(W.TD.w) == 0x4000 and W.TD.panel ~= nil and W.TD.full == nil, W)
    check("[fix] A: ...and the line says the look through all the game's objects is used (it gave no name)", ends(W.last(USING), BYLOOK .. BYWALK), W)
end
do local W = hudWorld()
    W.tdFind()
    local first = W.TD.full
    W.kill(W.widgets[1])                                                  -- that display is gone; the game has a new one, which gives no name
    W.hud(0x4800, PATH2).noName = "raise"
    W.t = W.t + 1
    local ok = W.tdFind()
    check("A: found afresh (another widget) that gives no name: the FIRST widget's name is not kept", ok == true and W.addr(W.TD.w) == 0x4800 and W.TD.full == nil, W)
    W.kill(W.widgets[2])
    W.hud(0x4c00, PATH3)
    W.t = W.t + 1
    ok = W.tdFind()
    check("[fix] A: ...and a third, which does: its own name", first == FULL and ok == true and W.addr(W.TD.w) == 0x4c00 and W.TD.full == fullOf(PATH3), W)
    check("A: ...nothing of the two freed displays was read", W.freedRead == 0, W)
end
do local W = world()
    W.spawn(0x1000)
    W.hud(0x4000, PATH, W.pc2)                                            -- another player's display, first among the game's objects
    W.hud(0x4800, PATH2)
    W.refs()
    local ok = W.tdFind()
    check("A: two displays among the game's objects: this player's is the one taken (not the class's default object, not the other player's)", ok == true and W.addr(W.TD.w) == 0x4800, W)
    check("[fix] A: ...and its name the one kept", W.TD.full == fullOf(PATH2), W)
end

-- B. tdLive: "is the display we hold still the game's?" -- the object itself is asked its name: no walk, no look-up,
-- and not counted as a look (NATIVE.WK.n). Without a name: the walk, as before
do local W = hudWorld()
    W.tdFind()
    local w1 = W.widgets[1]
    local function probe()                                                -- -> the answer, walks made, StaticFindObject calls, times asked its name, looks counted
        local w, s, n, k = W.walks(), W.nStatic, W.nName, W.N.WK.n
        local r = W.tdLive()
        return r, W.walks() - w, W.nStatic - s, W.nName - n, W.N.WK.n - k
    end
    local r, walks, statics, names, counted = probe()
    check("[fix] B: the name held: still there (true) by asking the object its name ONCE -- no look through the game's objects, no StaticFindObject",
        r == true and walks == 0 and statics == 0 and names == 1, W)
    check("[fix] B: ...and that is not counted as a look through the game's objects (NATIVE.WK.n as it was)", r == true and counted == 0, W)
    W.kill(w1) W.reuse(w1, "TextBlock", OTHER)
    r, walks, statics, names, counted = probe()
    check("[fix] B: ANOTHER OBJECT stands at its address (valid, a text block): false, no walk, nothing counted", r == false and walks == 0 and statics == 0 and names == 1 and counted == 0, W)
    check("[fix] B: ...and TD.gone says what calls itself what there now", has(W.TD.gone, "what is at its address now calls itself '" .. fullOf(OTHER, "TextBlock") .. "', not '" .. FULL .. "'"), W)
    W.reuse(w1, CN, PATH2)
    r, walks = probe()
    check("[fix] B: a NEW DISPLAY of the same class at its address (builds 145-217's walk took it for the old one): false, no walk", r == false and walks == 0, W)
    W.reuse(w1, CN, PATH)
    r, walks = probe()
    check("[fix] B: the same name again: true, no walk", r == true and walks == 0, W)
    w1.noName = "raise"
    r, walks = probe()
    check("[fix] B: its name cannot be read now (GetFullName raises): false, no walk (it is found afresh for the next name)", r == false and walks == 0, W)
    w1.noName = nil
    W.busy = 1                                                            -- the engine is clearing objects out
    W.reuse(w1, CN, PATH2)
    r, walks, statics, names = probe()
    check("B: a purge on (HJN_GcBusy 1): taken as still there (true) -- nothing walked, and the object is not asked its name either", r == true and walks == 0 and statics == 0 and names == 0, W)
    W.busy = -1
    r, walks, statics, names = probe()
    check("[fix] B: the purge flags cannot be read (HJN_GcBusy -1): the object is asked all the same (false: another name), no walk", r == false and walks == 0 and names == 1, W)
    W.busy = 0
    W.reuse(w1, CN, PATH)
    W.kill(w1)
    r, walks, statics, names = probe()
    check("B: the display is freed (IsValid false): false at once -- nothing looked up, and no name is read from freed memory", r == false and walks == 0 and statics == 0 and names == 0 and W.freedRead == 0, W)
    check("[fix] B: ...and TD.gone says it is not a valid object any more", W.TD.gone == "it is not a valid object any more", W)
end
do local W = hudWorld({ noGc = true })
    W.tdFind()
    local w, n = W.walks(), W.nName
    check("[fix] B: beside a native half without HJN_GcBusy: asked its name all the same -- true, no walk", W.tdLive() == true and W.walks() == w and W.nName == n + 1, W)
end
do local W = hudWorld()
    local w1 = W.widgets[1]
    w1.noName = "raise"                                                   -- it gave no name when it was found
    W.tdFind()
    local a, s, k = W.nAll, W.nStatic, W.N.WK.n
    local r = W.tdLive()
    check("B: WITHOUT a name it walks as before: true by one FindAllOf of the display's class (counted as a look), no StaticFindObject",
        r == true and W.TD.full == nil and W.nAll == a + 1 and W.all[#W.all] == CN and W.nStatic == s and W.N.WK.n == k + 1, W)
    W.kill(w1) W.reuse(w1, "TextBlock", OTHER)
    a = W.nAll
    r = W.tdLive()
    check("B: ...and false when the walk no longer has a display at that address (one FindAllOf)", r == false and W.nAll == a + 1, W)
    check("[fix] B: ...TD.gone says it is not among the game's objects of that class", W.TD.gone == "it is not among the game's " .. CN .. " objects any more", W)
    W.busy = 1
    a = W.nAll
    check("B: ...a purge on: true, no walk", W.tdLive() == true and W.nAll == a, W)
end

-- C. THE STUTTER ITSELF: a name of the mod's is put up (a grab's), the display is held from then on, and the frame hook
-- asks once a second whether it is still the game's. Ten seconds of frames, at the developer's 60 and the tester's 90
for _, fps in ipairs({ 60, 90 }) do
    local W = hudWorld()
    local shown = W.trickName("Indy")
    local up = #W.panel.kids
    local a0, f0, s0, n0, k0 = W.nAll, W.nFirst, W.nStatic, W.nName, W.N.WK.n
    W.frames(10, fps)
    local nA, nF, nS, names = W.nAll - a0, W.nFirst - f0, W.nStatic - s0, W.nName - n0
    note(string.format("10 s at %d frames a second, the display held: %d FindAllOf, %d FindFirstOf, %d StaticFindObject call(s); the display was asked its name %d time(s)", fps, nA, nF, nS, names))
    check(string.format("C (%d fps): a name is put up through the game's display (one line in its panel) and taken off again by its time", fps),
        shown == true and up == 1 and #W.panel.kids == 0 and W.count("trick name: Indy") == 1, W)
    check(string.format("[fix] C (%d fps): 10 s of frames with the display held: NOT ONE FindAllOf, FindFirstOf or StaticFindObject call", fps),
        nA == 0 and nF == 0 and nS == 0 and W.TD.w ~= nil and W.TD.panel ~= nil and W.count(REBUILT) == 0, W)
    check(string.format("[fix] C (%d fps): ...the check is still made once a second: the display is asked its name about 10 times, none of them counted as a look", fps),
        names >= 9 and names <= 11 and W.TD.asked == names and W.N.WK.n == k0, W)
    check(string.format("[fix] C (%d fps): ...and the log has the display's own name once (a line only when the answer changes)", fps),
        W.count("trick names: the display was asked its name -- '" .. FULL .. "', as when it was found") == 1, W)
end
for _, how in ipairs({ "raise", "" }) do
    local W = hudWorld()
    W.widgets[1].noName = how
    local shown = W.trickName("Indy")
    local w0, s0 = W.walks(), W.nStatic
    W.frames(10, 60)
    local walks = W.walks() - w0
    note(string.format("10 s at 60 frames a second, the display held, its GetFullName %s: %d look(s) through all the game's objects", (how == "raise") and "raising an error" or "giving an empty name", walks))
    check("C: a display that gives no name (" .. ((how == "raise") and "an error" or "an empty one") .. "): about 10 walks in the 10 s (the once-a-second walk, as it was), no StaticFindObject, the display kept",
        shown == true and walks >= 9 and walks <= 11 and W.nStatic == s0 and W.TD.w ~= nil and W.count(REBUILT) == 0, W)
end
-- the display goes while it is held. `change` is made right after one of the once-a-second checks (the longest wait)
local function gone(fps, change)
    local W = hudWorld()
    W.trickName("Indy")
    W.frames(2.5, fps)
    W.till(function() return W.TD.validAt == W.t end, 2, fps)             -- (a check has just been made)
    local w1 = W.widgets[1]
    change(W, w1)
    local w0, s0 = W.walks(), W.nStatic
    local secs = W.till(function() return W.TD.w == nil end, 3, fps)
    return W, secs, W.walks() - w0, W.nStatic - s0
end
for _, fps in ipairs({ 60, 90 }) do
    local W, secs, walks, statics = gone(fps, function(W, w1) W.kill(w1, true) end)   -- the display freed, its panel not yet
    note(string.format("%d fps: a display freed right after a check was forgotten %s later", fps, secs and string.format("%.3f s", secs) or "NEVER"))
    check(string.format("C (%d fps): the display is FREED (IsValid false; its panel still there): seen within a second, ours forgotten, nothing walked and nothing read from freed memory", fps),
        secs ~= nil and secs <= 1 + 2 / fps and W.count(REBUILT) == 1 and W.TD.w == nil and W.TD.panel == nil and walks == 0 and statics == 0 and W.freedRead == 0, W)
    check(string.format("[fix] C (%d fps): ...the 'rebuilt' line says why (it is not a valid object any more), and the name is forgotten with it", fps),
        has(W.last(REBUILT), REBUILT .. " (it is not a valid object any more) -- ours forgotten") and W.TD.full == nil, W)
end
do local W, secs = gone(60, function(W, w1) W.kill(w1, true) end)
    W.hud(0x4800, PATH2)                                                  -- the game's new display
    W.t = W.t + 2.5                                                       -- (the 2 s of hands off after it)
    local w0 = W.walks()
    local shown = W.trickName("Tail Grab")
    check("C: the next name finds the new display (one look through the game's objects) and is put up", secs ~= nil and shown == true and W.addr(W.TD.w) == 0x4800 and W.walks() == w0 + 1, W)
    check("[fix] C: ...and the new display's own name is the one held", W.TD.full == fullOf(PATH2), W)
    local w1, s1 = W.walks(), W.nStatic
    W.frames(5, 60)
    check("[fix] C: ...5 s more of frames: no walk, no StaticFindObject, the display kept", W.walks() == w1 and W.nStatic == s1 and W.TD.w ~= nil and W.count(REBUILT) == 1, W)
end
do local W = hudWorld()                                                   -- the display AND its panel freed in the same purge
    W.trickName("Indy")
    W.frames(2, 60)
    W.kill(W.widgets[1])
    local w0, n0 = W.walks(), W.nName
    W.frames(2, 60)
    check("C: the display AND its panel freed: the frames touch nothing of either (no walk, no name asked, nothing read from freed memory), the mod's lines are forgotten",
        W.walks() == w0 and W.nName == n0 and W.freedRead == 0 and #W.TD.lines == 0, W)
    W.hud(0x4800, PATH2)
    local shown = W.trickName("Tail Grab")
    check("C: ...and the next name finds the new display by one look", shown == true and W.addr(W.TD.w) == 0x4800 and W.walks() == w0 + 1 and W.freedRead == 0, W)
    check("[fix] C: ...whose own name is the one held (not the freed one's)", W.TD.full == fullOf(PATH2), W)
end
for _, fps in ipairs({ 60, 90 }) do
    -- freed, and another object now stands at its address (and one at its panel's): IsValid says yes again
    local W, secs, walks, statics = gone(fps, function(W, w1) W.kill(w1) W.reuse(w1, "TextBlock", OTHER) end)
    note(string.format("%d fps: a display whose address went to another object right after a check was forgotten %s later", fps, secs and string.format("%.3f s", secs) or "NEVER"))
    check(string.format("C (%d fps): ANOTHER OBJECT at the display's address (its name changed): seen within a second, ours forgotten", fps),
        secs ~= nil and secs <= 1 + 2 / fps and W.count(REBUILT) == 1 and W.TD.w == nil and W.TD.panel == nil, W)
    check(string.format("[fix] C (%d fps): ...without a walk, and the 'rebuilt' line says what stands there now", fps),
        walks == 0 and statics == 0 and has(W.last(REBUILT), "(what is at its address now calls itself '" .. fullOf(OTHER, "TextBlock") .. "', not '" .. FULL .. "')") and W.TD.full == nil, W)
    -- ...and the case the walk of builds 145-217 could not tell from the old display: a NEW display of the same class there
    W, secs, walks, statics = gone(fps, function(W, w1) W.kill(w1) W.reuse(w1, CN, PATH2) end)
    check(string.format("[fix] C (%d fps): a NEW DISPLAY at the old one's address (the same class, another name): seen within a second, ours forgotten, no walk", fps),
        secs ~= nil and secs <= 1 + 2 / fps and W.count(REBUILT) == 1 and W.TD.w == nil and walks == 0 and statics == 0, W)
end
do local W = hudWorld()
    W.trickName("Indy")
    W.busy = 1
    local w0, s0, n0 = W.walks(), W.nStatic, W.nName
    W.frames(10, 60)
    check("C: a purge on for the whole 10 s: nothing is looked up, the display is not asked its name, and it is kept", W.walks() == w0 and W.nStatic == s0 and W.nName == n0 and W.TD.w ~= nil and W.TD.panel ~= nil, W)
    W.busy = 0
    W.frames(2, 60)
    check("[fix] C: ...the purge over: asked again within a second, still no walk", W.nName > n0 and W.walks() == w0 and W.TD.w ~= nil, W)
end
do local W = hudWorld()     -- not a check: the game takes its display off the screen and makes another, the old one not freed yet, no bail seen
    W.trickName("Indy")
    W.frames(2, 60)
    W.widgets[1].inView = false
    W.hud(0x4800, PATH2)
    W.frames(3, 60)
    local held = W.TD.w ~= nil and W.addr(W.TD.w) == 0x4000
    note(string.format("a display taken off the screen but not freed yet (the game has made another; no bail): after 3 s the mod %s; a name asked for then is %s",
        held and "still holds the old one (so did the walk of builds 145-217: it is among the game's objects until it is freed)" or "no longer holds the old one",
        W.trickName("Tail Grab") and "put up" or "not put up"))
end

-- D. THE NAME GOES WITH THE WIDGET: a name left behind would be asked of a widget it was never taken from. And what a
-- bail kept (the display and its name) is asked first by the next name
do local W = hudWorld()
    W.tdFind()
    local had = W.TD.full
    W.N.forgetUi()
    check("[fix] D: NATIVE.forgetUi drops the name with the widget", had == FULL and W.TD.full == nil and W.TD.w == nil and W.TD.panel == nil, W)
    W.TD.full, W.TD.kept, W.TD.keptFull, W.TD.path = "X /A/Name.Left:Over", W.widgets[1], "X /A/Name.Left:Over", "/A/Name.Left:Over"
    W.N.forgetUi()
    check("[fix] D: ...whatever is there (put there by hand): TD.full, TD.kept, TD.keptFull and TD.path", W.TD.full == nil and W.TD.kept == nil and W.TD.keptFull == nil and W.TD.path == nil, W)
    W.tdFind()
    had = W.TD.full
    local held = W.TD.w
    W.N.tdBail()
    check("[fix] D: a bail (NATIVE.tdBail) forgets it: TD.full nil with the widget", had == FULL and W.TD.full == nil and W.TD.w == nil and W.TD.panel == nil, W)
    check("[fix] D: ...and keeps what was held for the next name to ask: TD.kept the object, TD.keptFull its name", held ~= nil and W.TD.kept == held and W.TD.keptFull == FULL, W)
    W.t = W.t + 5
    W.tdFind()
    had = W.TD.full
    W.N.forgetWorld("a new skater")
    local w, s, n = W.walks(), W.nStatic, W.nName
    check("[fix] D: a level change (NATIVE.forgetWorld) forgets it", had == FULL and W.TD.full == nil and W.TD.w == nil, W)
    check("D: ...and tdLive then says no without looking anything up or asking anything", W.tdLive() == false and W.walks() == w and W.nStatic == s and W.nName == n, W)
end
do local W = hudWorld()
    W.tdFind()
    W.N.tdBail()
    W.N.forgetWorld("a new skater")
    check("D: a level change after a bail drops what the bail kept (the widgets die with the level)", W.TD.kept == nil and W.TD.keptFull == nil and W.TD.full == nil, W)
end
-- a display found, held and checked for 3 s, then a bail; `change` = what becomes of it in the 5 s after
local function bailed(change)
    local W = hudWorld()
    W.trickName("Indy")
    W.frames(3, 60)
    local asked = W.TD.asked
    W.N.tdBail()
    local w1 = W.widgets[1]
    if change then change(W, w1) end
    W.t = W.t + 5
    return W, w1, asked
end
do local W, _, asked = bailed()
    local w0, k0 = W.walks(), W.N.WK.n
    local ok = W.tdFind()
    check("[fix] D: after a bail, the display that is still the same, on the screen and this player's is taken WITHOUT a walk (no FindAllOf, no FindFirstOf, no StaticFindObject of its name, no look counted)",
        ok == true and W.addr(W.TD.w) == 0x4000 and W.TD.panel ~= nil and W.walks() == w0 and W.nPath == 0 and W.N.WK.n == k0, W)
    check("[fix] D: ...its name is held again and what the bail kept is let go", W.TD.full == FULL and W.TD.kept == nil and W.TD.keptFull == nil, W)
    local line = W.last(USING)
    check("[fix] D: ...and the 'trick names: using' line says how it was found (the one held before the bail, no look) and how it is checked", ends(line, BYKEPT .. BYNAME), W)
    note("the line: " .. line:sub(1, 300))
    check("[fix] D: ...the bail said what the once-a-second check had been (asked its name that many times, the game's objects not looked through)",
        type(asked) == "number" and asked >= 3 and W.count(string.format("trick names: the display was asked its name %d time(s) since it was found; the game's objects were not looked through for it", asked)) == 1, W)
end
do local W = hudWorld()                                                   -- the same through the names themselves
    W.trickName("Indy")
    W.frames(2, 60)
    local kids0 = #W.panel.kids
    W.N.tdBail()
    check("D: the bail takes the mod's line off the display while it is still ours", kids0 == 1 and #W.panel.kids == 0, W)
    W.t = W.t + 1
    local w0, n0 = W.walks(), W.nName
    local shown = W.trickName("Too Soon")
    check("D: a name within 4 s of the bail is not put up, and nothing of the display is touched (no walk, no name asked)", shown == false and W.walks() == w0 and W.nName == n0 and #W.panel.kids == 0, W)
    W.frames(3.5, 60)
    check("D: ...nor by the frames of those 4 s and the half second after", W.walks() == w0 and W.nName == n0, W)
    shown = W.trickName("Tail Grab")
    check("[fix] D: the first name after the 4 s goes up on the display the bail kept, with NO look through the game's objects", shown == true and #W.panel.kids == 1 and W.walks() == w0 and W.nPath == 0, W)
    W.frames(10, 60)
    check("[fix] D: ...and 10 s more of frames: still none", W.walks() == w0 and W.nPath == 0 and W.TD.w ~= nil and W.count(REBUILT) == 0, W)
end
for _, c in ipairs({
    { "is no longer on the screen (IsInViewport false; the game has made another)", function(W, w1) w1.inView = false W.hud(0x4800, PATH2) end, 0x4800, PATH2 },
    { "cannot be asked whether it is on the screen (IsInViewport raises)", function(W, w1) w1.inView = "raise" end, 0x4000, PATH },
    { "is another player's now (the game has made this player another)", function(W, w1) w1.owner = W.pc2 W.hud(0x4800, PATH2) end, 0x4800, PATH2 },
    { "has been freed (the game has made another)", function(W, w1) W.kill(w1) W.hud(0x4800, PATH2) end, 0x4800, PATH2 },
    { "has been freed and another object stands at its address", function(W, w1) W.kill(w1) W.reuse(w1, "TextBlock", OTHER) W.hud(0x4800, PATH2) end, 0x4800, PATH2 },
    { "has been freed and a NEW display stands at its address (another name)", function(W, w1) W.kill(w1) W.reuse(w1, CN, PATH2) end, 0x4000, PATH2 },
}) do
    local W = bailed(c[2])
    local w0 = W.walks()
    local ok = W.tdFind()
    check("D: after a bail, a kept display that " .. c[1] .. ": EXACTLY ONE look through the game's objects, the game's display is the one then held, nothing read from freed memory",
        ok == true and W.walks() == w0 + 1 and W.all[#W.all] == CN and W.addr(W.TD.w) == c[3] and W.freedRead == 0 and W.TD.kept == nil and W.TD.keptFull == nil, W)
    check("[fix] D: ...under its own name, and the line says it was found by a look", W.TD.full == fullOf(c[4]) and ends(W.last(USING), BYLOOK .. BYNAME), W)
end
do local W = bailed()
    W.busy = 1
    local w0, n0, failed0 = W.walks(), W.nName, W.TD.failed
    local ok = W.tdFind()
    check("D: after a bail, a purge on at the next name: not found now (false) -- nothing walked, the kept display not asked, and it is not counted as a failure",
        ok == false and W.walks() == w0 and W.nName == n0 and W.TD.failed == failed0 and W.TD.w == nil, W)
    W.busy = 0
    ok = W.tdFind()
    check("[fix] D: ...the purge over: the kept display is asked then and taken, no walk", ok == true and W.walks() == w0 and W.addr(W.TD.w) == 0x4000 and W.TD.full == FULL, W)
end
do local W = bailed(function(W, w1) end)
    W.N.forgetUi()                                                        -- (what a rebuilt display or a level change does)
    local w0 = W.walks()
    local ok = W.tdFind()
    check("D: NATIVE.forgetUi after a bail: what the bail kept is not asked -- the next name looks (one walk)", ok == true and W.walks() == w0 + 1 and W.addr(W.TD.w) == 0x4000, W)
end
do local W = hudWorld()                                                   -- three grabs with a bail between each, at the tester's 90 frames a second
    local a0 = W.walks()
    local n = 0
    for _, name in ipairs({ "Indy", "Tail Grab", "Melon" }) do
        if W.trickName(name) then n = n + 1 end
        W.frames(10, 90)
        W.N.tdBail()
        W.frames(5, 90)
    end
    note(string.format("three names of 10 s each, a bail and 5 s after each (45 s of frames at 90): %d look(s) through all the game's objects, %d StaticFindObject of a name", W.walks() - a0, W.nPath))
    check("[fix] D: three names with a bail after each, 45 s of frames: ONE look through the game's objects in all (the first find)", n == 3 and W.walks() - a0 == 1 and W.nPath == 0 and W.count(REBUILT) == 0, W)
end
-- TWO BAILS WITH NO NAME OF THE MOD'S BETWEEN THEM (a bail, back on the board, the game's own tricks, another bail --
-- the mod puts a name up only for its own moves). The display the first bail kept is as good after the second: it is
-- touched by nobody in between, and is asked the same three questions before it is taken.
do local W = bailed()
    W.N.tdBail()                                                          -- the second bail: the mod holds no display now
    W.t = W.t + 5
    local w0 = W.walks()
    local ok = W.tdFind()
    note(string.format("two bails with no name of the mod's between them, the display still the game's: the next name made %d look(s) through all the game's objects", W.walks() - w0))
    check("[fix] D: a SECOND bail before any name of the mod's does not throw away what the first bail kept: the next name takes the display without a walk",
        ok == true and W.addr(W.TD.w) == 0x4000 and W.walks() == w0, W)
end
do local W = hudWorld()     -- not a check: the number in the bail's line when the display was found afresh with no bail between (TD.asked is cleared by a bail only)
    W.trickName("Indy")
    W.frames(3, 60)
    local first = W.TD.asked or 0
    W.kill(W.widgets[1], true)
    W.frames(1.5, 60)                                                     -- (seen: forgotten)
    W.hud(0x4800, PATH2)
    W.t = W.t + 2.5
    W.trickName("Tail Grab")
    W.frames(2, 60)
    local second = (W.TD.asked or 0) - first
    W.N.tdBail()
    local line = W.last("since it was found"):gsub("^%s+", "")
    note(string.format("a display asked its name %d time(s) and freed, the next one found (no bail between) and asked %d time(s), then a bail: its line is '%s'", first, second, line))
end

-- E. THE GAME'S ADVANCED NUMBERS: a hop's start took a walk for an object that is hardly ever there. A hop takes the
-- kept value; the look is made when a pause menu comes up, and once more when it goes
do local W = world()
    W.options(0.85, 0)                                                    -- the object IS there
    local function ask(look) local w = W.walks() local v, why = W.readAdvanced(ADV, look) return v, why, W.walks() - w end   -- -> value, where from, looks made
    local v, why, looks = ask()
    check("[fix] E: readAdvanced(field) makes NO FindFirstOf call, even with the options object there: nothing kept yet = nil", v == nil and why == "cached/none" and looks == 0, W)
    v, why, looks = ask(true)
    check("E: readAdvanced(field, true) LOOKS (one FindFirstOf of OptionsSaveGame) and reads the active preset", v == 0.85 and why == "preset 0" and looks == 1 and W.first[#W.first] == "OptionsSaveGame", W)
    W.opts = nil                                                          -- gone again (it is only there around a settings load / save)
    v, why, looks = ask()
    check("[fix] E: ...and keeps it: readAdvanced(field) gives the kept value with no look", v == 0.85 and why == "cached/none" and looks == 0, W)
    v, why, looks = ask(true)
    check("E: asked to look with the object gone: one look, the kept value", v == 0.85 and why == "cached/none" and looks == 1, W)
    W.options(1.3, 2)
    W.busy = 1
    v, why, looks = ask(true)
    check("E: asked to look while a purge is on: no look, the kept value", v == 0.85 and looks == 0, W)
    W.busy = 0
    v, why, looks = ask(true)
    check("E: the purge over: looked, the new active preset (index 2) read and kept", v == 1.3 and why == "preset 2" and looks == 1 and W.readAdvanced(ADV) == 1.3, W)
    W.options("not a number", 0)
    v, why, looks = ask(true)
    check("E: a preset that gives no number: the kept value stays", v == 1.3 and looks == 1 and W.readAdvanced(ADV) == 1.3, W)
end
do  -- the hop's start is not cut out here (it is the whole of the hop): what it calls is read from the source
    local _, n1 = src:gsub("readAdvanced%(\"BodyRotationRateMultiplier\"%)", "")
    check("E: the hop's start asks with the field alone (the one such call in the file, its result the hop's rateMult)",
        n1 == 1 and src:find("    local m, why = readAdvanced(\"BodyRotationRateMultiplier\")\n    rateMult = (type(m) == \"number\" and m > 0) and m or 1.0\n", 1, true) ~= nil)
end
do local W = world()
    W.spawn(0x1000) W.refs()
    W.options(0.85, 0)
    local function looks(fn) local f = W.nFirst fn() return W.nFirst - f end              -- the FindFirstOf calls fn made
    local function kept() local f = W.nFirst local v = W.readAdvanced(ADV) return v, W.nFirst - f end   -- what a hop would take, and the looks that took
    local n = looks(function() W.watch(8) end)
    check("E: no pause menu up: the menu's watch looks for nothing (2 s of it)", n == 0, W)
    W.menuUp(0x7000)
    n = looks(function() W.watch(1) end)
    local v, l = kept()
    check("[fix] E: a pause menu comes up: the watch looks ONCE (FindFirstOf of OptionsSaveGame) and the number is kept for the hops", n == 1 and W.first[#W.first] == "OptionsSaveGame" and v == 0.85 and l == 0, W)
    W.options(1.2, 0)                                                     -- a slider is moved in that menu
    n = looks(function() W.watch(11) W.watch(2, "Gamepad_DPad_Down") end)
    check("E: ...3 s more of the same menu (thirteen looks of the watch, two of them at a press): nothing is looked for", n == 0, W)
    W.menuDown()
    n = looks(function() W.watch(1) end)
    v, l = kept()
    check("[fix] E: the menu GOES: looked for ONCE more, and the slider moved in that menu is what a hop takes now (1.2)", n == 1 and W.first[#W.first] == "OptionsSaveGame" and v == 1.2 and l == 0, W)
    n = looks(function() W.watch(7) end)
    check("E: ...the menu gone: nothing more is looked for", n == 0, W)
    W.options(1.5, 0)
    W.menuUp(0x7400)                                                      -- the next pause menu (another container object)
    n = looks(function() W.watch(4) end)
    v, l = kept()
    check("[fix] E: the next pause menu: looked for once as it comes up (not again in its first second), the number as it is now", n == 1 and v == 1.5 and l == 0, W)
    W.options(1.6, 0)
    W.menuDown()
    n = looks(function() W.watch(4) end)
    v, l = kept()
    check("[fix] E: ...and once as it goes", n == 1 and v == 1.6 and l == 0, W)
    W.options(1.7, 0)
    W.menuUp(0x7400)                                                      -- the game shows the SAME container object again
    n = looks(function() W.watch(4) end)
    v, l = kept()
    check("[fix] E: a pause menu whose container is the same object as the last one's: looked for once at that opening too", n == 1 and v == 1.7 and l == 0, W)
    W.menuDown()
    n = looks(function() W.watch(4) end)
    -- a pause menu that comes up while a look is refused (a purge on at that look of the watch)
    W.options(1.8, 0)
    W.busy = 1
    W.menuUp(0x7800)
    local a = looks(function() W.watch(1) end)
    W.busy = 0
    local b = looks(function() W.watch(8) end)
    local v1 = kept()
    W.menuDown()
    local c = looks(function() W.watch(1) end)
    v, l = kept()
    note(string.format("a pause menu that came up while a purge was on, the purge over a quarter second later: %d look(s) as it came up, %d in the 2 s of that menu after it (a hop then takes %s; the game's is 1.8), %d as it went",
        a, b, tostring(v1), c))
    check("[fix] E: a pause menu that comes up while a purge is on: no look then; the look as it goes reads the number", n == 1 and a == 0 and c == 1 and v == 1.8 and l == 0, W)
    -- not a check: a menu that GOES while a purge is on
    W.menuUp(0x7c00) W.watch(1)
    W.options(1.9, 0)
    W.busy = 1
    W.menuDown()
    a = looks(function() W.watch(1) end)
    W.busy = 0
    b = looks(function() W.watch(8) end)
    note(string.format("a pause menu that went while a purge was on: %d look(s) as it went, %d in the 2 s after; a hop then takes %s (the game's is 1.9) until the next pause menu", a, b, tostring((kept()))))
    -- the skater gone (a level change out of the pause menu): nothing is asked of anything
    W.menuUp(0x7000) W.watch(1)
    W.skaters[1].dead = true
    n = looks(function() W.watch(4) end)
    W.menuDown()
    n = n + looks(function() W.watch(4) end)
    check("E: no skater (the old one freed while a menu was up): the watch looks for nothing, with the menu up or gone", n == 0, W)
end

-- F. THE BOARD'S PARTS: boardParts dropped the deck it held and walked at every board hop, drop-in and throwdown. The
-- deck is kept while it is YOUR board's (its actor is named exactly "Skateboard") and within 4 m of you
do local W = world()
    W.spawn(0x1000) W.board(0x7000)
    W.refs()
    local function parts() local w = W.walks() local p = W.boardParts() return p and #p or 0, W.walks() - w, p end
    local n, wk, p = parts()
    check("F: the board's parts are found: seven, the deck first, by one look through the game's objects", n == 7 and p[1] == 0x7001 and wk == 1 and W.all[#W.all] == "PBP_SkateboardEx_C", W)
    local n7, w5 = 0, 0
    for _ = 1, 5 do W.t = W.t + 0.07 local a, b = parts() if a == 7 then n7 = n7 + 1 end w5 = w5 + b end
    note(string.format("five more calls with the deck 10 cm from you, its actor named 'Skateboard': %d gave seven parts, %d look(s) through the game's objects", n7, w5))
    check("[fix] F: five more calls with the deck 10 cm from you (its actor named 'Skateboard'): seven parts each time, NO look", n7 == 5 and w5 == 0, W)
    W.deckX = 399
    n, wk = parts()
    check("[fix] F: the deck 3.99 m off: kept, no look", n == 7 and wk == 0, W)
    W.deckX = 401
    n, wk = parts()
    check("F: 4.01 m off: looked for again (one look)", n == 7 and wk == 1, W)
    n, wk = parts()
    check("F: ...and at every call while it is that far", n == 7 and wk == 1, W)
    W.deckX, W.deckZ = 10, -450
    n, wk = parts()
    check("F: the distance is taken in all three directions: 10 cm aside and 4.5 m below you is beyond (one look)", n == 7 and wk == 1, W)
    W.deckZ = nil
    n, wk = parts()
    check("[fix] F: by you again: kept, no look", n == 7 and wk == 0, W)
    W.noHere = true
    n, wk = parts()
    check("F: where you are cannot be read: the kept deck is not trusted (looked for; that look fails as it did before)", n == 0 and wk == 1, W)
    W.noHere = nil
    W.t = W.t + 0.6
    n, wk = parts()
    check("F: ...and found again 0.6 s on", n == 7 and wk == 1, W)
    W.boards[1].dead = true                                               -- that board is gone, there is a new one
    if W.BD.comp then W.BD.comp.dead = true end
    W.board(0x8000)
    n, wk, p = parts()
    check("F: the kept deck dead: looked for again, the new board's parts", n == 7 and p[1] == 0x8001 and wk == 1, W)
    W.busy = 1
    n, wk, p = parts()
    check("[fix] F: a purge on: the kept deck's parts are given without a look (build 217: none -- the look was refused)", n == 7 and p[1] == 0x8001 and wk == 0, W)
    W.busy = 0
    W.N.forgetWorld("a new skater")                                       -- a new level forgets it
    check("F: a level change drops the kept deck", W.BD.comp == nil, W)
    W.refs()
    n, wk = parts()
    check("F: ...and the next call looks", n == 7 and wk == 1, W)
end
for _, c in ipairs({ { "Skateboard_2", "is named 'Skateboard_2' (a co-op peer's board carries a numbered name)" }, { "skateboard", "is named 'skateboard' (not exactly 'Skateboard')" },
                     { false, "cannot be asked its name" } }) do
    local W = world()
    W.spawn(0x1000) W.board(0x7000, c[1])
    W.refs()
    local n7, wk = 0, 0
    for _ = 1, 6 do
        W.t = W.t + 0.07
        local w = W.walks()
        local p = W.boardParts()
        if p and #p == 7 and p[1] == 0x7001 then n7 = n7 + 1 end
        wk = wk + (W.walks() - w)
    end
    check("F: a deck 10 cm from you whose actor " .. c[2] .. ": never kept -- seven parts and one look at EVERY one of six calls", n7 == 6 and wk == 6, W)
end
do local W = world()                                                      -- co-op, a shared spawn point: a peer's deck is the nearest one
    W.spawn(0x1000)
    W.board(0x7000, "Skateboard", { X = 30, Y = 0, Z = 0 })
    local peer = W.board(0x8000, "Skateboard_2", { X = 10, Y = 0, Z = 0 })
    W.refs()
    local function parts() W.t = W.t + 0.07 local w = W.walks() local p = W.boardParts() return p and #p or 0, W.walks() - w, p and p[1] end
    local n, wk, first = parts()
    local n2, wk2, first2 = parts()
    note(string.format("co-op, a peer's deck 10 cm from you and yours 30 cm: the look takes the deck at 0x%x (the peer's is 0x8001, yours 0x7001) -- the nearest, as before; it is not kept", first or 0))
    check("F: co-op: while a peer's deck is the nearest one it is looked for at every call (a peer's is never kept)", n == 7 and wk == 1 and first == 0x8001 and n2 == 7 and wk2 == 1 and first2 == 0x8001, W)
    peer.pos.X = 300                                                      -- the peer rolls off: 3 m away, yours is the nearest now
    n, wk, first = parts()
    check("F: ...the peer 3 m off: the look takes YOUR deck", n == 7 and wk == 1 and first == 0x7001, W)
    n, wk, first = parts()
    check("[fix] F: ...and yours is kept from then on: no look, though the peer's deck is within 4 m too", n == 7 and wk == 0 and first == 0x7001, W)
    peer.pos.X = 5
    n, wk, first = parts()
    check("[fix] F: ...a peer's deck coming nearer than yours does not take its place: yours still, no look", n == 7 and wk == 0 and first == 0x7001, W)
end

-- G. A FRAME THE MOD'S OWN WORK MAKES LONG IS SAID: NATIVE.timed runs the frame's work (as the pcall it stands for did),
-- and 4 ms or more of it is a "slow frame:" line -- the first 200 of a run, one in 2 s unless it is 12 ms or more
local function frame(W, ms, how)                                          -- one frame's work through NATIVE.timed: it takes `ms`; "throw" = it raises an error at its end
    if type(W.N.timed) ~= "function" then return false end
    W.got = nil
    return (pcall(W.N.timed, function(ctx) W.got = ctx W.t = W.t + ms / 1000 if how == "throw" then error("thrown inside the frame's work") end end, "the context"))
end
local function slows(W) return W.count("slow frame:") end
do local W = world()
    local ok = frame(W, 3)
    check("[fix] G: a 3 ms frame: the work is done (with its context) and nothing is said", ok and W.got == "the context" and slows(W) == 0 and #W.logs == 0, W)
    W.t = W.t + 0.5
    ok = frame(W, 3.9)
    check("[fix] G: 3.9 ms: nothing either (the line begins at 4 ms)", ok and slows(W) == 0, W)
    W.t = W.t + 0.5
    ok = frame(W, 6)
    local line = W.last("slow frame:")
    note("the line: " .. line:sub(1, 240))
    check("[fix] G: a 6 ms frame: ONE 'slow frame:' line, word for word -- the frame hook's work, 6 ms, no look through the game's objects in it, the first such frame",
        ok and slows(W) == 1 and line == "slow frame: the mod's own work (the frame hook) took 6 ms of this frame (0 look(s) through all the game's objects in it; 1 such frames so far, the longest 6 ms)", W)
    W.t = W.t + 0.5
    ok = frame(W, 6)
    check("[fix] G: a second 6 ms frame half a second later: not said (one line in 2 s)", ok and slows(W) == 1, W)
    W.t = W.t + 0.5
    ok = frame(W, 11)
    check("[fix] G: an 11 ms frame within the 2 s: not said either (under 12 ms)", ok and slows(W) == 1, W)
    W.t = W.t + 0.3
    ok = frame(W, 15)
    line = W.last("slow frame:")
    check("[fix] G: a 15 ms frame within the 2 s: said -- and it counts the ones not said (4 such frames, the longest 15 ms)",
        ok and slows(W) == 2 and has(line, "(the frame hook) took 15 ms of this frame") and has(line, "4 such frames so far, the longest 15 ms"), W)
    W.t = W.t + 1.0
    ok = frame(W, 6)
    check("[fix] G: a 6 ms frame 1 s after THAT line: not said", ok and slows(W) == 2, W)
    W.t = W.t + 1.1
    ok = frame(W, 6)
    check("[fix] G: ...and one 2.1 s after it: said", ok and slows(W) == 3, W)
end
do local W = world()
    local ok = true
    for _ = 1, 260 do W.t = W.t + 0.1 ok = frame(W, 15) and ok end
    local n = slows(W)
    W.t = W.t + 30
    ok = frame(W, 40) and ok
    note(string.format("260 frames of 15 ms and one of 40 ms: %d 'slow frame:' lines", slows(W)))
    W.logs = { W.logs[#W.logs] }                                          -- (not 200 lines into the report if this fails)
    check("[fix] G: 260 frames of 15 ms: 200 lines and never one more (a 40 ms frame half a minute on is not said either); every one is counted",
        ok and n == 200 and slows(W) == 1 and W.N.WK.slowN == 261 and W.N.WK.slowTold == 200, W)
end
do local W = world()
    local ok = frame(W, 1, "throw")
    check("[fix] G: an error thrown by the timed function does not come out of NATIVE.timed (as with the pcall it stands for)", ok == true and W.got == "the context" and #W.logs == 0, W)
    W.t = W.t + 1
    ok = frame(W, 6, "throw")
    check("[fix] G: ...and a frame that throws after 6 ms of work is said like any other", ok == true and slows(W) == 1, W)
end
do local W = world()
    local ok = type(W.N.timed) == "function" and pcall(W.N.timed, function() W.N.all("AnyClass") W.N.first("AnyOther") W.t = W.t + 0.008 end)
    check("[fix] G: the looks through the game's objects made in the frame are in its line: two of them", ok and W.walks() == 2 and has(W.last("slow frame:"), "(2 look(s) through all the game's objects in it"), W)
end
do local W = world()                                                      -- the frame hook itself
    W.ensureHook()
    local h = W.hooks[1]
    check("G: the frame hook is registered once, with a function before and one after", #W.hooks == 1 and type(h.pre) == "function" and type(h.post) == "function" and W.count("hook registered") == 1, W)
    W.onFrame = function(ctx) W.gotPre = ctx W.t = W.t + 0.006 end
    W.onFramePost = function(ctx) W.gotPost = ctx W.t = W.t + 0.002 end
    h.pre("the hook's context") h.post("the hook's context after")
    check("G: both of the hook's functions run the mod's frame with the hook's context", W.gotPre == "the hook's context" and W.gotPost == "the hook's context after", W)
    check("[fix] G: ...through NATIVE.timed: a 6 ms onFrame is one 'slow frame:' line, a 2 ms onFramePost none", slows(W) == 1 and has(W.last("slow frame:"), "(the frame hook) took 6 ms"), W)
    W.onFramePost = function() W.t = W.t + 0.007 end
    W.t = W.t + 3
    h.post("x")
    check("[fix] G: ...and a 7 ms onFramePost 3 s later is one too", slows(W) == 2, W)
    W.onFrame = function() error("thrown in onFrame") end
    W.onFramePost = function() error("thrown in onFramePost") end
    local ok1, ok2 = pcall(h.pre, "x"), pcall(h.post, "x")
    check("G: an error in onFrame or onFramePost does not come out of the hook (on either build)", ok1 == true and ok2 == true, W)
end
-- the two together: the once-a-second check of the display falls in a frame that is long for another reason. The line
-- counts "look(s) through all the game's objects": asking the display its own name is not one (it does not go through
-- NATIVE.walkOk, whose every "yes" is counted in NATIVE.WK.n -- the number NATIVE.timed takes its looks from), and a
-- line that said "1 look(s)" there would send whoever reads the log after a walk that was not made
do local W = hudWorld()
    W.trickName("Indy")
    W.t = W.t + 1.5                                                       -- the check is due at the next frame
    local w0, s0, n0, k0 = W.walks(), W.nStatic, W.nName, W.N.WK.n
    local ok = type(W.N.timed) == "function" and pcall(W.N.timed, function() W.tick(W.t) W.t = W.t + 0.006 end)
    local line = W.last("slow frame:")
    note(string.format("a 6 ms frame with the display's check in it: %d walk(s) made, %d StaticFindObject call(s), asked its name %d time(s), the walk gate's count of looks went up by %d; the line: %s",
        W.walks() - w0, W.nStatic - s0, W.nName - n0, W.N.WK.n - k0, line:sub(1, 200)))
    check("[fix] G: a slow frame in which the display was asked its own name (no walk made) is NOT said to have had a look through all the game's objects in it",
        ok and W.walks() == w0 and W.nStatic == s0 and W.nName == n0 + 1 and W.N.WK.n == k0 and has(line, "(0 look(s) through all the game's objects in it"), W)
end
do local W = hudWorld()
    W.widgets[1].noName = "raise"                                         -- a display that gives no name is walked for: that IS a look, and the line says so
    W.trickName("Indy")
    W.t = W.t + 1.5
    local w0 = W.walks()
    local ok = type(W.N.timed) == "function" and pcall(W.N.timed, function() W.tick(W.t) W.t = W.t + 0.006 end)
    check("[fix] G: ...and one in which the display was walked for (it gave no name) is said to have had one", ok and W.walks() == w0 + 1 and has(W.last("slow frame:"), "(1 look(s) through all the game's objects in it"), W)
end
-- THE QUEUED ACTIONS: a stick click, a bumper, Y and the timers' work do not run in the frame hook but in the mod's own
-- game-thread queue (NATIVE.gt -> UE4SS's ExecuteInGameThread -> NATIVE.gtDrain(false)). Each is timed by itself and
-- said the same way, under its tag (or "a queued action"). Drained by the frame hook (NATIVE.gtPump ->
-- NATIVE.gtDrain(true), when UE4SS does not run them) they are inside the hook's own time and the drain says nothing
local function queued(W, ms, tag, how)                                    -- NATIVE.gt of an action that takes `ms` ("look": it walks once; "throw": it raises an error at its end)
    W.N.gt(function()
        W.ran = (W.ran or 0) + 1
        if how == "look" then W.N.all("AnyClass") end
        W.t = W.t + ms / 1000
        if how == "throw" then error("thrown inside a queued action", 0) end
    end, tag, function() W.droppedN = (W.droppedN or 0) + 1 end)
end
do local W = world()
    queued(W, 6, "the ragdoll of a hop's bail")
    check("G: NATIVE.gt hands the queue to UE4SS (one ExecuteInGameThread call) and runs nothing itself", #W.egt == 1 and W.ran == nil and #W.N.GT.q == 1, W)
    W.serve()
    local line = W.last("slow frame:")
    note("the line: " .. line:sub(1, 240))
    check("[fix] G: a 6 ms queued action run by UE4SS (gtDrain with hook false): ONE 'slow frame:' line, and it names the action's tag",
        W.ran == 1 and slows(W) == 1 and line == "slow frame: the mod's own work (the ragdoll of a hop's bail) took 6 ms of this frame (0 look(s) through all the game's objects in it; 1 such frames so far, the longest 6 ms)", W)
    W.t = W.t + 3
    queued(W, 6)
    W.serve()
    check("[fix] G: one without a tag: the line says 'a queued action'", W.ran == 2 and slows(W) == 2 and has(W.last("slow frame:"), "the mod's own work (a queued action) took 6 ms of this frame"), W)
    W.t = W.t + 3
    local s0 = slows(W)
    queued(W, 2, "a short one") queued(W, 3.9)
    W.serve()
    check("G: queued actions of 2 ms and of 3.9 ms (one with a tag, one without): both run, nothing said", W.ran == 4 and slows(W) == s0 and #W.N.GT.q == 0, W)
end
do local W = world()
    queued(W, 6)                                                          -- (without a tag: one the frame hook may run)
    W.egt = {}                                                            -- UE4SS does not run it...
    W.N.gtDrain(true)                                                     -- ...the frame hook's pump does
    check("G: the same 6 ms action drained from the frame hook (gtDrain with hook true): run, and NO 'slow frame:' line from the drain", W.ran == 1 and slows(W) == 0, W)
    queued(W, 6, "the ragdoll of a hop's bail")
    W.egt = {}
    W.N.gtDrain(true)
    check("G: a TAGGED action is not run from the frame hook at all (dropped and said, its onDrop called): no 'slow frame:' line", W.ran == 1 and W.droppedN == 1 and slows(W) == 0 and W.count("is not run from the frame hook -- dropped") == 1, W)
end
do local W = world()                                                      -- ...its time is the frame hook's own: said once, by the hook
    W.ensureHook()
    local h = W.hooks[1]
    W.onFrame = function() W.N.gtPump() end
    W.onFramePost = function() end
    queued(W, 6)
    W.egt = {}                                                            -- UE4SS away
    W.t = W.t + 0.31
    if h then h.pre("x") h.post("x") end
    check("[fix] G: UE4SS away, the frame hook's pump runs the 6 ms action 0.31 s on: ONE 'slow frame:' line, the frame hook's own (none from the drain)",
        W.ran == 1 and slows(W) == 1 and has(W.last("slow frame:"), "(the frame hook) took 6 ms") and W.count("the frame hook runs them from here on") == 1, W)
end
do local W = world()
    queued(W, 8, "a look for the board", "look")
    W.serve()
    check("[fix] G: the looks through the game's objects a queued action made are in its line: one", W.ran == 1 and W.nAll == 1 and has(W.last("slow frame:"), "(a look for the board) took 8 ms of this frame (1 look(s) through all the game's objects in it"), W)
end
do local W = world()
    queued(W, 6, nil, "throw")
    local ok = pcall(W.serve)
    check("G: a queued action that raises an error does not bring the drain down, and the failure is logged (as before)",
        ok and W.ran == 1 and W.count("game thread: an action failed: thrown inside a queued action") == 1 and W.N.GT.busy == false, W)
    check("[fix] G: ...and its 6 ms are said like any other's", slows(W) == 1 and has(W.last("slow frame:"), "(a queued action) took 6 ms"), W)
    queued(W, 1)
    W.serve()
    check("G: ...and the next action is run", W.ran == 2, W)
end
do local W = world()
    queued(W, 13, "the first") queued(W, 14, "the second")
    W.serve()
    check("[fix] G: two actions run in one drain are each timed by themselves: two lines, each with its own tag and its own time",
        W.ran == 2 and slows(W) == 2 and W.count("(the first) took 13 ms of this frame") == 1 and W.count("(the second) took 14 ms of this frame") == 1, W)
end
do local W = world()
    local ok = frame(W, 6)                                                -- said: the first
    W.t = W.t + 0.5
    queued(W, 6, "Y") W.serve()                                           -- within 2 s and under 12 ms: counted, not said
    local s1, n1 = slows(W), W.N.WK.slowN
    W.t = W.t + 0.5
    queued(W, 15, "the drop-in's mount") W.serve()                        -- 12 ms or more: said
    local line = W.last("slow frame:")
    check("[fix] G: the frame hook's lines and the queued actions' share one count and one pace: a 6 ms action half a second after a 6 ms frame is counted and not said, a 15 ms one is said (3 so far, the longest 15 ms)",
        ok and s1 == 1 and n1 == 2 and slows(W) == 2 and has(line, "(the drop-in's mount) took 15 ms of this frame") and has(line, "3 such frames so far, the longest 15 ms"), W)
end
-- ...and the one queued action this build adds a look to: the pause menu's watch, as it really runs -- main.lua's own
-- 250 ms timer hands it to the queue and UE4SS runs it. A look through the game's objects takes 20 ms here (the
-- tester's machine): the one made as a menu comes up is under the menu, the one made as it goes is back in play
do local W = world()
    W.spawn(0x1000) W.refs()
    W.options(0.85, 0)
    W.lookCost = 0.020
    local function timer() W.t = W.t + 0.25 if W.loops[1] then W.loops[1].fn() end W.serve() end
    check("G: the pause menu's watch is on a 250 ms timer of its own (the file's one LoopAsync here), which hands it to the queue", #W.loops == 1 and W.loops[1].ms == 250, W)
    timer()
    check("G: no pause menu up: the timer's turn is run and nothing is said", #W.N.GT.q == 0 and slows(W) == 0, W)
    W.menuUp(0x7000)
    timer()
    local line = W.last("slow frame:")
    note("the line: " .. line:sub(1, 240))
    check("[fix] G: the look for the options as a pause menu comes up, run by the timer through the queue, is said: one line -- a queued action, 20 ms, 1 look",
        slows(W) == 1 and has(line, "(a queued action) took 20 ms of this frame (1 look(s) through all the game's objects in it") and W.nFirst == 1, W)
    local s1 = slows(W)
    for _ = 1, 8 do timer() end
    check("G: ...2 s more of that menu: no more lines", slows(W) == s1, W)
    W.menuDown()
    timer()
    check("[fix] G: ...and the look made as the menu goes is said too (the second line, 2 looks made in all)", slows(W) == 2 and W.nFirst == 2 and has(W.last("slow frame:"), "(a queued action) took 20 ms of this frame (1 look(s)"), W)
end

out[#out + 1] = string.format("%d checks, %d of them marked [fix]; %d failed (%d of those marked [fix])", nchecks, nfix, nfail, nfixfail)
local o = assert(io.open("stutter218_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the stutter fixes' test failed: see stutter218_out.txt", 0) end

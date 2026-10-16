-- test_menuguard.lua: the pause menu's focus guard (NATIVE.menuWatch), cut out of main.lua and run in real Lua against a
-- stand-in for the game.  luareal -run test_menuguard.lua result.txt main.lua   (writes mgtest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("NATIVE.mg = { proven = false }", 1, true), "the guard's start was not found")
local b = assert(src:find("LoopAsync(250, function()", a, true), "the guard's end was not found")
local body = src:sub(a, b - 1)

local function world(o)
    local W = { logs = {}, focusCalls = 0, t = 100 }
    for k, v in pairs(o or {}) do W[k] = v end
    -- the menu: W.menu = nil (none) or { own = bool|nil, part = bool|nil, takes = bool (SetUserFocus works) }
    local function widget(m)
        return { id = m, HasUserFocus = function() if m.noq then error("no such function") end return m.own end,
                 HasUserFocusedDescendants = function() if m.noq then error("no such function") end return m.part end,
                 SetUserFocus = function() W.focusCalls = W.focusCalls + 1 if m.takes then m.own = true end end }
    end
    local widgets = {}
    local pc = setmetatable({}, { __index = function(_, k) if k == "_activePauseMenuPageContainer" then
        if not W.menu then return nil end widgets[W.menu] = widgets[W.menu] or widget(W.menu) return widgets[W.menu] end end })
    local env = setmetatable({}, { __index = _G })
    env.os = setmetatable({ clock = function() return W.t end }, { __index = os })
    local NATIVE = {}
    local q = function(fn, d) local ok, r = pcall(fn) if ok then return r end return d end
    local chunk = "local NATIVE, alive, q, s0, SB, addr, log = ...\n" .. body .. "\nreturn NATIVE"
    local fn = assert(load(chunk, "=guard", "t", env))
    W.N = fn(NATIVE, function(x) return x end, q, { GetController = function() return pc end }, {}, function(o) return o and o.id end, function(s) W.logs[#W.logs + 1] = s end)
    W.look = function(n, key) for _ = 1, (n or 1) do W.t = W.t + 0.25 W.N.menuWatch(key) end end
    return W
end
local out = {}
local function check(name, cond, W) out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond then out[#out + 1] = "       focus calls " .. W.focusCalls for _, l in ipairs(W.logs) do out[#out + 1] = "       log: " .. l end end
    return cond end
local all = true

-- 1. no menu, then a healthy menu (a part of it has the focus), closed again: nothing is done
do local W = world({}) W.look(4) W.menu = { own = false, part = true } W.look(20) W.N.menuWatch("Gamepad_DPad_Up") W.menu = nil W.look(4)
    all = check("1: a healthy menu is never touched (and nothing is logged)", W.focusCalls == 0 and #W.logs == 0 and W.N.mg.proven == true, W) and all end
-- 2. the first menu of the run comes up without the focus: nothing until a press reaches the game, then handed it
do local W = world({}) W.menu = { own = false, part = false, takes = true } W.look(8)
    all = check("2: unproven question, no press yet = nothing done", W.focusCalls == 0, W) and all
    W.N.menuWatch("Gamepad_DPad_Down")
    all = check("2: a press that reached the game = the focus handed over, said twice", W.focusCalls == 1 and #W.logs == 2 and W.menu.own == true, W) and all
    for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l end
    W.look(8) W.N.menuWatch("Gamepad_DPad_Down")
    all = check("2: ...and left alone once it has it", W.focusCalls == 1, W) and all end
-- 3. a healthy menu earlier in the run, then one that comes up without the focus: handed it after 0.4 s, before any press
do local W = world({}) W.menu = { own = true, part = false } W.look(4) W.menu = nil W.look(2)
    W.menu = { own = false, part = false, takes = true } W.look(1)
    all = check("3: not in its first quarter second", W.focusCalls == 0, W) and all
    W.look(2)
    all = check("3: after 0.4 s without it, with no press", W.focusCalls == 1 and W.menu.own == true, W) and all
    out[#out + 1] = "       " .. tostring(W.logs[1]) end
-- 4. a menu that had the focus and loses it 2 s in (the respawn under it): a press hands it back
do local W = world({}) W.menu = { own = true, part = false, takes = true } W.look(8) W.menu.own = false W.look(2)
    all = check("4: had it, lost it, no press = nothing done", W.focusCalls == 0, W) and all
    W.N.menuWatch("Gamepad_FaceButton_Bottom")
    all = check("4: a press within 6 s of its coming up = handed back", W.focusCalls == 1, W) and all end
-- 5. a menu that had the focus and gives the pad to the game 10 s in (a gamepad assignment page): left alone, said once
do local W = world({}) W.menu = { own = true, part = false, takes = true } W.look(40) W.menu.own = false W.look(4)
    W.N.menuWatch("Gamepad_FaceButton_Bottom") W.N.menuWatch("Gamepad_FaceButton_Bottom")
    all = check("5: over 6 s old and it had the focus = not touched, one line", W.focusCalls == 0 and #W.logs == 1, W) and all
    out[#out + 1] = "       " .. tostring(W.logs[1]) end
-- 6. the focus will not stay: three tries a menu, no more; a new menu gets its own three
do local W = world({}) W.menu = { own = false, part = false, takes = false } W.look(2)
    for _ = 1, 8 do W.t = W.t + 0.3 W.N.menuWatch("Gamepad_DPad_Up") end
    all = check("6: three tries at most for one menu", W.focusCalls == 3, W) and all
    W.menu = nil W.look(1) W.menu = { own = false, part = false, takes = false } W.look(1) W.N.menuWatch("Gamepad_DPad_Up")
    all = check("6: a new menu is tried again", W.focusCalls == 4, W) and all end
-- 7. the question cannot be asked on this build: nothing is done, whatever is pressed
do local W = world({}) W.menu = { noq = true, takes = true } W.look(8) W.N.menuWatch("Gamepad_DPad_Up")
    all = check("7: no answer = nothing done, nothing said", W.focusCalls == 0 and #W.logs == 0, W) and all end

local o = assert(io.open("mgtest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the pause menu guard's test failed: see mgtest_out.txt", 0) end

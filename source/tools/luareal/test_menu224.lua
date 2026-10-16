-- test_menu224.lua (build 224, mk224q.pl): NO QUICK SETTINGS PAGE in the mod's own nested pause-menu pages ("just go ahead
-- and get rid of the quick settings, I don't like it", 14 Oct). The menu table and NATIVE.menuSend are cut out of main.lua
-- and run in real Lua against a stand-in for the native half's HJN_MenuPage / HJN_MenuRow / HJN_Set. The Quick page stays
-- only as what SessionOpenMP's one flat page shows (MenuOwnPages=0): the native half builds that page from the pages in
-- order, the first non-sub page being its title page.
-- luareal -run test_menu224.lua result.txt main.lua   (writes menu224_out.txt)
-- Run on build 223 the checks marked [new] must FAIL.
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("\nNATIVE.MENU = {\n", 1, true), "the menu table was not found")
local b = assert(src:find("\nNATIVE.menuPush = function()", a, true), "the menu's end was not found")
local body = src:sub(a + 1, b)
local s0 = assert(src:find("\nlocal SPEC = {", 1, true), "SPEC was not found")
local s1 = assert(src:find("\n}\n", s0, true), "SPEC's end was not found")
local spec = assert(load("return {" .. src:sub(src:find("{", s0, true) + 1, s1) .. "}", "=spec", "t", {}))()

local out, all = {}, true
local function check(name, cond, W)
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then for _, l in ipairs(W.logs) do out[#out + 1] = "       " .. l:sub(1, 300) end end
    return cond
end

local function run(own)
    local W = { logs = {}, pages = {}, set = {} }
    local env = { ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring, type = type, string = string, table = table, math = math,
        io = { open = function() return nil end } }
    env.HJN_Set = function(k, v) W.set[k] = v return 1 end
    env.HJN_MenuPage = function(t)
        if t == "" then W.pages = {} return 0 end
        W.pages[#W.pages + 1] = { title = t, rows = {} } return #W.pages
    end
    env.HJN_MenuRow = function(kind, key, label)
        local pg = W.pages[#W.pages] if not pg then return 0 end
        pg.rows[#pg.rows + 1] = { kind = kind, key = key, label = label } return #pg.rows
    end
    local NATIVE = { DEF = {} }
    local S = { MenuOwnPages = own }
    local chunk = "local NATIVE, S, SPEC, log = ...\n" .. body .. "\nreturn NATIVE"
    local N = assert(load(chunk, "=menu", "t", env))(NATIVE, S, spec, function(s) W.logs[#W.logs + 1] = tostring(s) end)
    N.menuSend()
    W.N = N
    return W
end
local function titles(W) local t = {} for _, p in ipairs(W.pages) do t[#t + 1] = p.title end return table.concat(t, " | ") end
local function page(W, title) for _, p in ipairs(W.pages) do if p.title == title then return p end end end
local function pageRows(p) local r = {} if p then for _, w in ipairs(p.rows) do if w.kind == 3 then r[#r + 1] = w.key end end end return r end

-- A. the mod's own nested pages (MenuOwnPages=1, the shipped default)
do local W = run(1)
    local et = page(W, "Expanded Tricks")
    local links = pageRows(et)
    local quickLink = false for _, k in ipairs(links) do if k == "Quick" then quickLink = true end end
    all = check("[new] A: own pages: no Quick settings page is sent (" .. titles(W) .. ")", page(W, "Quick") == nil and W.set.menuown == 1, W) and all
    all = check("[new] A: ...and the Expanded Tricks page has no row that opens it (" .. table.concat(links, ", ") .. ")", et ~= nil and not quickLink, W) and all
    local missing = {} for _, k in ipairs(links) do if not page(W, k) then missing[#missing + 1] = k end end
    all = check("A: every row of the Expanded Tricks page opens a page that is sent (6 of them)", #links == 6 and #missing == 0, W) and all
    all = check("A: the other pages are all there, with their rows", page(W, "General gameplay settings") and page(W, "Hippie Jumps") and page(W, "Drop-ins")
        and page(W, "Grabs") and #page(W, "Drop-ins").rows > 5 and W.logs[#W.logs]:find("^menu: 7 pages") ~= nil, W) and all
    all = check("A: the Quick list is still in the table (for the flat page)", W.N.MENU[1][1] == "Quick" and #W.N.MENU[1][2] >= 10, W) and all
end
-- B. SessionOpenMP's one flat page (MenuOwnPages=0): as before -- the Quick page first, linked from the Expanded Tricks page
do local W = run(0)
    local links = pageRows(page(W, "Expanded Tricks"))
    local quickLink = false for _, k in ipairs(links) do if k == "Quick" then quickLink = true end end
    all = check("B: the flat page: the Quick page is still sent first (" .. titles(W) .. ")", W.pages[1] and W.pages[1].title == "Quick" and #W.pages[1].rows >= 10 and W.set.menuown == 0, W) and all
    all = check("B: ...and linked from the Expanded Tricks page (so the native half takes it for a sub page and puts its rows on the flat page first)", quickLink, W) and all
end
local o = assert(io.open("menu224_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("build 224's menu test failed: see menu224_out.txt", 0) end

-- dryrun.lua: runs main.lua's whole top level, and its timer callbacks once, under real Lua 5.4 with a stand-in for
-- UE4SS and the native half. It cannot show that the mod works; it shows that the file starts without a Lua error.
-- Run by `luareal -run dryrun.lua <result> <main.lua>` with the working directory an EMPTY scratch folder holding
-- scenario.txt: "0" = the exe the mod was written against, "1" = another build found by signature (same layout),
-- "2" = another build with one property moved, "3" = another build, not all signatures found,
-- "4" = another build where an engine property reads wrong as well (the check is not acted on).
-- Files: only relative paths inside the working directory can be opened; nothing is removed or renamed.
local real_open = io.open
local sf = real_open("scenario.txt", "r") local SCEN = sf and tonumber(sf:read("l")) or 0 if sf then sf:close() end
local opened, denied = {}, {}
local function rel(p) p = tostring(p):gsub("\\", "/") return (not p:match("^%a:")) and (not p:match("^/")) and (not p:find("..", 1, true)) end
io.open = function(p, m) if rel(p) then opened[#opened + 1] = tostring(p) .. " (" .. tostring(m or "r") .. ")" return real_open(p, m) end denied[#denied + 1] = tostring(p) return nil, "sandbox: not opened" end
os.getenv = function() return "SANDBOX_ENV" end
os.remove = function() return true end
os.rename = function() return true end
io.popen, os.execute, os.exit = nil, nil, nil

-- anything of the game's that is asked for and not stood in for: a thing that can be indexed, called, compared
local smt = {}
local function stub(name) return setmetatable({ __stub = name }, smt) end
smt.__index = function(t, k) return stub(rawget(t, "__stub") .. "." .. tostring(k)) end
smt.__call = function(t) return stub(rawget(t, "__stub") .. "()") end
smt.__tostring = function(t) return "<" .. rawget(t, "__stub") .. ">" end
smt.__len = function() return 0 end
smt.__concat = function(a, b) return tostring(a) .. tostring(b) end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__idiv", "__pow" }) do smt[op] = function() return 0 end end
smt.__lt = function() return false end
smt.__le = function() return false end

-- the layout stand-in: main.lua's own table read out of the file, the classes answering with it
local src do local f = assert(real_open(MAIN, "rb")) src = f:read("a"):gsub("\r\n", "\n") f:close() end
local LAY do
    local a = assert(src:find("NATIVE.LAYOUT = {", 1, true)) local b = assert(src:find("\nNATIVE.layoutCheck = function", a, true))
    LAY = assert(load("local NATIVE = {} " .. src:sub(a, b) .. " return NATIVE.LAYOUT"))()
end
local loops, hooks, keys = {}, 0, 0
local G = {
    print = print,
    RegisterHook = function() hooks = hooks + 1 return hooks, hooks end,
    RegisterKeyBind = function() keys = keys + 1 end,
    RegisterCustomEvent = function() end, NotifyOnNewObject = function() end, RegisterConsoleCommandHandler = function() end,
    RegisterLoadMapPostHook = function() end, RegisterInitGameStatePostHook = function() end, RegisterBeginPlayPostHook = function() end,
    LoopAsync = function(ms, fn) loops[#loops + 1] = { ms = ms, fn = fn } end,
    ExecuteWithDelay = function(ms, fn) end, ExecuteAsync = function(fn) end,
    ExecuteInGameThread = function(fn) fn() end,
    FindFirstOf = function() return nil end, FindAllOf = function() return nil end, FindObject = function() return nil end,
    StaticFindObject = function(path)
        for _, c in ipairs(LAY) do
            if c[1] == tostring(path) then
                return { IsValid = function() return true end,
                    ForEachProperty = function(self, cb)
                        for name, off in pairs(c[2]) do
                            if (SCEN == 2 or SCEN == 4) and name == "LeftFootSocketLocation" then off = off + 8 end
                            if SCEN == 4 and name == "RootComponent" then off = off + 8 end      -- (4: an engine property reads wrong too = the reading is off)
                            cb({ GetFName = function() return { ToString = function() return name end } end, GetOffset_Internal = function() return off end })
                        end
                    end }
            end
        end
        return nil
    end,
    HJN_PushCap = function() return (SCEN == 3) and "0 not this game build" or "1 100 100" end,
    HJN_BuildMode = function() return (SCEN == 0 or SCEN == 5) and 0 or ((SCEN == 3) and -1 or 1) end,
    HJN_Version = function() return 105 end,
}
setmetatable(_G, { __index = function(_, k)
    if G[k] ~= nil then return G[k] end
    if type(k) == "string" and k:match("^HJN_") then local f = function() return 0 end G[k] = f return f end
    return stub(k)
end })

local t0 = os.clock()
local ok, err = pcall(dofile, MAIN)
print(string.format("scenario %d: top level %s in %.2f s; %d hooks, %d key binds, %d timers registered", SCEN, ok and "ran to its end" or "RAISED AN ERROR", os.clock() - t0, hooks, keys, #loops))
if not ok then print("  ERROR: " .. tostring(err)) end
local bad = 0
for i, l in ipairs(loops) do
    local ok2, err2 = pcall(l.fn)
    if not ok2 then bad = bad + 1 print(string.format("  timer %d (%s ms) RAISED: %s", i, tostring(l.ms), tostring(err2))) end
end
print(string.format("  timers run once each: %d of %d without an error", #loops - bad, #loops))
print("  files opened: " .. table.concat(opened, ", "):sub(1, 400))
if #denied > 0 then print("  REFUSED (outside the sandbox): " .. table.concat(denied, ", "):sub(1, 300)) end
local lf = real_open("ExpandedTricks.log", "r")
if lf then
    for line in lf:lines() do
        if line:find("loaded (v", 1, true) or line:find("layout:", 1, true) or line:find("ANOTHER BUILD", 1, true) or line:find("native half:", 1, true) then print("  LOG " .. line:sub(1, 420)) end
    end
    lf:close()
else print("  no ExpandedTricks.log was written") end
if not ok or bad > 0 then error("the dry run saw a Lua error (above)") end

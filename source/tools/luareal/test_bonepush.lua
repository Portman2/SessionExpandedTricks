-- test_bonepush.lua: the bone's three settings on their way to the native half (NATIVE.hands: GrabBoneMove /
-- GrabBoneHands / GrabBoneLean -> HJN_Set "boneboard" / "bonehands" / "boneleanadd") and what a boned grab's log
-- line says moves (GR.boneSet), cut out of main.lua and run in real Lua against a stand-in.
-- luareal -run test_bonepush.lua result.txt main.lua   (writes bptest_out.txt)
local f = assert(io.open(MAIN, "rb")); local src = f:read("a"); f:close()
src = src:gsub("\r\n", "\n")
local ha = assert(src:find("NATIVE.hands = function(force)", 1, true), "NATIVE.hands was not found")
local hb = assert(src:find("\n-- MAP CHANGES.", ha, true), "NATIVE.hands' end was not found")
local hands = src:sub(ha, hb)
local sa = assert(src:find("GR.boneK = { Left = 0, Right = 0 }", 1, true), "GR.boneSet's start was not found")
local sb = assert(src:find("GR.tweak = function(now, native)", sa, true), "GR.boneSet's end was not found")
local said = src:sub(sa, sb - 1)
local SHIP = {}
do
    local s0 = assert(src:find("\nlocal S = {\n", 1, true), "the settings table was not found")
    local s1 = assert(src:find("\n}\n", s0, true), "the settings table's end was not found")
    for line in src:sub(s0, s1):gmatch("[^\n]+") do
        local k, v = line:match("^%s+([%w_]+)%s*=%s*(-?[%d%.]+)%s*,")
        if k then SHIP[k] = tonumber(v) end
    end
end
local out = {}
local all = true
local function check(name, cond, W)
    out[#out + 1] = (cond and "ok   " or "FAIL ") .. name
    if not cond and W then
        for _, c in ipairs(W.calls) do out[#out + 1] = string.format("       HJN_Set(%s, %s)", tostring(c[1]), tostring(c[2])) end
        for _, l in ipairs(W.logs or {}) do out[#out + 1] = "       log: " .. l end
    end
    return cond
end
local function world(o)
    o = o or {}
    local W = { calls = {}, grab = {}, logs = {} }
    local S = {}
    for k, v in pairs(SHIP) do S[k] = v end
    S.BoneMelon, S.HandMelonAlong = 15, 2
    for k, v in pairs(o.S or {}) do S[k] = v end
    W.S = S
    local env = setmetatable({}, { __index = _G })
    if not o.noGrabSet then env.HJN_GrabSet = function(id, i, v) W.grab[#W.grab + 1] = { id, i, v } end end
    env.HJN_GrabSetSw = function() end
    env.HJN_Set = function(k, v)
        W.calls[#W.calls + 1] = { k, v }
        if o.oldNative and (k == "boneboard" or k == "bonehands" or k == "boneleanadd") then return 0 end   -- (a key the native half does not know)
        return 1
    end
    local NATIVE = { v = o.v or 113, GRABS = { { "Melon", 2 } }, PARAMS = { { "Bone", "", 5 }, { "Hand", "Along", 0 } } }
    W.NATIVE = assert(load("local NATIVE, S = ...\n" .. hands .. "\nreturn NATIVE", "=hands", "t", env))(NATIVE, S)
    W.GR = assert(load("local GR, S, NATIVE, log = ...\n" .. said .. "\nreturn GR", "=said", "t", env))({}, S, NATIVE, function(s) W.logs[#W.logs + 1] = tostring(s) end)
    W.last = function(k) local v, n = nil, 0 for _, c in ipairs(W.calls) do if c[1] == k then v, n = c[2], n + 1 end end return v, n end
    return W
end

all = check("what ships: the BODY moves (GrabBoneMove 0), the hands stay on (GrabBoneHands 1), 25 deg of extra lean", SHIP.GrabBoneMove == 0 and SHIP.GrabBoneHands == 1 and SHIP.GrabBoneLean == 25) and all
do local W = world({})
    W.NATIVE.hands()
    local mv, n1 = W.last("boneboard") local hd, n2 = W.last("bonehands") local ln, n3 = W.last("boneleanadd")
    all = check("the first push sends the three as they ship: boneboard 0, bonehands 1, boneleanadd 25, once each", mv == 0 and hd == 1 and ln == 25 and n1 == 1 and n2 == 1 and n3 == 1, W) and all
    all = check("...beside the grab's own numbers (the Melon's bone 15, its hand 2 along)", #W.grab == 2 and W.grab[1][3] == 15 and W.grab[2][3] == 2, W) and all
    local n = #W.calls
    W.NATIVE.hands()
    all = check("nothing changed: nothing is sent again", #W.calls == n, W) and all
    W.S.GrabBoneMove = 1 W.NATIVE.hands()
    all = check("Bone moves set to 1 (the menu or the ini): sent at the next push", W.last("boneboard") == 1 and select(2, W.last("boneboard")) == 2, W) and all
    W.S.GrabBoneLean = 10 W.NATIVE.hands()
    all = check("the extra lean set to 10: sent", W.last("boneleanadd") == 10 and W.last("boneboard") == 1, W) and all
    W.S.GrabBoneHands = 0 W.NATIVE.hands()
    all = check("GrabBoneHands set to 0: sent", W.last("bonehands") == 0, W) and all
    n = #W.calls
    W.NATIVE.hands()
    all = check("...and again nothing more until a change", #W.calls == n, W) and all
    W.NATIVE.hands(true)
    all = check("a forced push sends them all again", #W.calls > n and select(2, W.last("bonehands")) == 5, W) and all
end
do local W = world({ oldNative = true, v = 112 })
    local ok = pcall(W.NATIVE.hands)
    all = check("a native half that does not know the three keys: no error, the rest is still sent", ok and W.last("curltip") ~= nil and W.last("handavoid") ~= nil, W) and all end
do local W = world({ noGrabSet = true })
    local ok = pcall(W.NATIVE.hands)
    all = check("no native grab calls at all: nothing sent, no error", ok and #W.calls == 0, W) and all end

-- the boned grab's own line
local function line(o)
    local W = world(o)
    W.GR.boneSet(1, "Indy Grab", 45, 7.5)
    return W, W.logs[1] or ""
end
do local W, l = line({})
    all = check("said, as shipped: the body goes back (GrabBoneMove 0), the distance, the hands stay on with 25 deg more lean",
        #W.logs == 1 and l:find("bone: the Indy Grab is boned", 1, true) and l:find("-- the body goes back over the back foot, the board out toward the nose (GrabBoneMove 0): 45 cm at the full swing; the hands stay on their spots: the back may lean 25 deg further", 1, true) ~= nil
        and not l:find("BOARD", 1, true), W) and all
    out[#out + 1] = "       " .. l
    W.GR.boneSet(1, "Indy Grab", 45, 7.5) W.GR.boneSet(0.4, "Indy Grab", 45, 7.5)
    all = check("...once a grab, and the native half is told the amount when it changes", #W.logs == 1 and select(2, W.last("bone")) == 2 and W.last("bone") == 0.4, W) and all
end
do local W, l = line({ S = { GrabBoneMove = 1 } })
    all = check("said with Bone moves 1: the BOARD is pushed out and the body stays, and where that does not hold",
        l:find("-- the BOARD is pushed out toward the nose and the body stays (GrabBoneMove 1; in an air that began without a pop the body goes back over the back foot instead): 45 cm at the full swing; the hands stay on their spots", 1, true) ~= nil, W) and all
    out[#out + 1] = "       " .. l end
do local W, l = line({ S = { GrabBoneHands = 0, GrabBoneLean = 10 } })
    all = check("said with GrabBoneHands 0: the hands as before, no lean named", l:find("; the hands as before build 211 (GrabBoneHands 0)", 1, true) ~= nil and not l:find("lean", 1, true), W) and all end
do local W, l = line({ S = { GrabBoneLean = 10 } })
    all = check("said with the lean at 10", l:find("the back may lean 10 deg further", 1, true) ~= nil, W) and all end
do local W, l = line({ S = { GrabBoneMove = 1 }, v = 112 })
    all = check("an older native half (v112) with Bone moves 1: the line does not claim the board moves", l:find("-- the body goes back over the back foot", 1, true) ~= nil and not l:find("BOARD", 1, true)
        and l:find("the native half is older than v113: the bone and its hands are as before build 211", 1, true) ~= nil, W) and all
    out[#out + 1] = "       " .. l end

local o = assert(io.open("bptest_out.txt", "w")) o:write(table.concat(out, "\n"), "\n", all and "ALL PASSED" or "SOME FAILED", "\n") o:close()
if not all then error("the bone settings' test failed: see bptest_out.txt", 0) end

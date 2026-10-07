// ExpandedTricksNative -- the native half of the Expanded Tricks mod for Session: Skate Sim (the Lua half is
// Mods/ExpandedTricks/Scripts/main.lua; this was HippieNative until v44).
//
// Copyright (C) 2026 Portman2. This program is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software Foundation, either version 3
// of the License, or (at your option) any later version. It is distributed WITHOUT ANY WARRANTY; see
// LICENSE. It builds on SessionOpenMP / SessionTweaks by matsix (GPL-3.0-or-later): the UE4SS ABI
// transcription in third_party/, and the pose-buffer layout and two-bone arm solve of src/tweaks/sit.cpp.
//
// WHAT IT DOES. The game's (unfinished) grabs aim the grabbing hand at a hand anchor on the board:
// NativeUpdateAnimation writes Left/RightHandIKLocation (component space, the skeleton board's anchor
// carried onto the drawn deck) and ramps Left/RightHandIKAlpha while the skater has a grab for that
// hand. But the control rig only has a LEFT hand effector, and even that stops well short. So the hand
// is put there HERE, in the finished pose: USkaterSkeletalMeshComponent::FinalizeBoneTransform is a
// vtable slot the engine only ever calls virtually (the PDB shows no direct call), so swapping that one
// pointer sees every skater's finished component-space pose, in the editable buffer, before it is
// flipped and published (the same moment SessionTweaks' sit writes its pose). For OUR skater's mesh the
// grabbing arm is re-aimed with analytic two-bone IK onto the game's own target, weighted by the game's
// own alpha; every other mesh passes straight through.
//
// THE LUA HALF. UE4SS starts C++ mods before Lua mods, and on_lua_start registers the HJN_* functions
// below into the SkaterDump mod's Lua state. Lua says which mesh and anim instance are ours (addresses),
// hands over the bone chain and the parent table (from the reflected GetBoneIndex / GetParentBone), and
// the settings.
#include <windows.h>
#include <tlhelp32.h>
#include <cwchar>
#include <cstdio>
#include <cstdint>
#include <cstdarg>
#include <share.h>
#include <cmath>
#include <cstring>
#include <string>
#include <vector>
#include <winhttp.h>
#include <bcrypt.h>
#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "bcrypt.lib")
#include "ue4ss_abi/ue4ss_abi.h"

using RC::LuaMadeSimple::Lua;

namespace {

#define HJN_VERSION 103
#define HJN_STR2(x) #x
#define HJN_STR(x) HJN_STR2(x)
constexpr int kVersion = HJN_VERSION;
constexpr char kBuildTag[] = "ExpandedTricksNative-build-" HJN_STR(HJN_VERSION);   // (review) make-release.ps1 looks for this text in main.dll

// ------------------------------------------------------------------ this exe build
// SessionGame-Win64-Shipping.exe with PE TimeDateStamp 0x69ca6d05 (RVAs from its PDB). Another build =
// the hook is not installed (logged), everything else stays off.
constexpr uint32_t  kExeStamp      = 0x69ca6d05;
constexpr uintptr_t RVA_FBT        = 0x2b58280;   // USkeletalMeshComponent::FinalizeBoneTransform
constexpr uintptr_t RVA_SKM_VT_FBT = 0x3d541a8;   // ??_7USkaterSkeletalMeshComponent@@6BUObject@@@ + 0x938
// USkinnedMeshComponent (engine, verified in this exe: FlipEditableSpaceBases reads +0x4f0/+0x4f4 and
// copies the TArray<FTransform> pair at +0x4b0 + i*0x10)
constexpr int SKM_CST  = 0x4b0;
constexpr int SKM_EDIT = 0x4f0;
constexpr int SKM_ANIM = 0x6b0;   // USkeletalMeshComponent::AnimScriptInstance (reflected)
// USkaterAnimInstance (reflected, from the PDB's property tables)
constexpr int AI_LHAND_A   = 0x458;
constexpr int AI_RHAND_A   = 0x45c;
constexpr int AI_LHAND_LOC = 0x460;
constexpr int AI_RHAND_LOC = 0x478;
constexpr int AI_REVERT_TYPE = 0x4d8, AI_REVERT_RATIO = 0x4dc;
constexpr int AI_LFOOT_A = 0x3fc, AI_RFOOT_A = 0x400;           // Left/RightFootIKAlpha
constexpr int AI_LFOOT_LOC = 0x404, AI_RFOOT_LOC = 0x41c;       // Left/RightFootSocketLocation (the drawn deck's, component space)
constexpr int SC_C2W = 0x1c0;         // USceneComponent::ComponentToWorld (K2_GetComponentToWorld reads +0x1c0/+0x1d0)
// the revert, for the trace (ASkaterCharacterBase::Revert -> the board's movement component)
constexpr int SK_BOARD = 0x568;       // ASkaterCharacterBase::_skateboard (what Revert() reads)
constexpr int SK_FOOTPOS = 0x598;     // ...foot position (1 Regular, 2 Fakie, 3 Nollie, 4 Switch)
constexpr int SK_REVERT_T = 0x8f0;    // ...the 0.5 s Revert() sets
constexpr int BD_MOVE = 0x298;        // ASkateboardEx::_skateboardMovement (reflected)
// (v35) ASessionPlayerController (InGame_Tick reads them): its skater, input handler, flip tricks handler and the
// LB/RB bits it hands to InAirHandler::CheckForGrabs; FlipTricksHandler: the late trick's cooldown and "armed"
constexpr int PC_SKATER = 0x698, PC_INPUT = 0x6a0, PC_FLIPTRICKS = 0x6d0, PC_BUMPERS = 0x798;
constexpr int FTH_SKATER = 0x8, FTH_INPUT = 0x18, FTH_LATE_COOLDOWN = 0x5c, FTH_LATE_ARMED = 0x61;
constexpr int MAX_BONES = 256;

// ------------------------------------------------------------------ log (HippieNative.log next to the exe)
FILE* g_log = nullptr;
void Log(const char* fmt, ...) {
    if (!g_log) {
        wchar_t path[MAX_PATH];
        const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
        if (n == 0 || n >= MAX_PATH) return;
        wchar_t* slash = wcsrchr(path, L'\\');
        if (!slash) return;
        wcscpy_s(slash + 1, MAX_PATH - (slash + 1 - path), L"ExpandedTricks.native.log");
        // (v101) A FRESH FILE ONCE IT IS BIG. It was appended to for ever (39 MB after two days): over 6 MB at a start it
        // becomes ExpandedTricks.native.log.old (the one before that is dropped) -- what a tester sends stays small.
        {
            WIN32_FILE_ATTRIBUTE_DATA fa;
            if (GetFileAttributesExW(path, GetFileExInfoStandard, &fa) && (fa.nFileSizeHigh != 0 || fa.nFileSizeLow > 6u * 1024u * 1024u)) {
                wchar_t old[MAX_PATH + 8];
                if (wcslen(path) + 5 < MAX_PATH + 8) { wcscpy_s(old, path); wcscat_s(old, L".old"); MoveFileExW(path, old, MOVEFILE_REPLACE_EXISTING); }
            }
        }
        g_log = _wfsopen(path, L"a", _SH_DENYNO);
        if (!g_log) return;
    }
    SYSTEMTIME t; GetLocalTime(&t);
    fprintf(g_log, "%02d:%02d:%02d ", t.wHour, t.wMinute, t.wSecond);
    va_list ap; va_start(ap, fmt); vfprintf(g_log, fmt, ap); va_end(ap);
    fputc('\n', g_log);
    fflush(g_log);
}

// ------------------------------------------------------------------ small math (UE FQuat order x y z w)
struct V3 { float x, y, z; };
struct Q4 { float x, y, z, w; };
V3 v3(float x, float y, float z) { return V3{ x, y, z }; }
V3 add(V3 a, V3 b) { return v3(a.x + b.x, a.y + b.y, a.z + b.z); }
V3 sub(V3 a, V3 b) { return v3(a.x - b.x, a.y - b.y, a.z - b.z); }
V3 mul(V3 a, float s) { return v3(a.x * s, a.y * s, a.z * s); }
V3 mulv(V3 a, V3 b) { return v3(a.x * b.x, a.y * b.y, a.z * b.z); }
float dot(V3 a, V3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
V3 cross(V3 a, V3 b) { return v3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x); }
float len(V3 a) { return sqrtf(dot(a, a)); }
V3 norm(V3 a) { const float l = len(a); return l > 1e-6f ? mul(a, 1.0f / l) : v3(0, 0, 1); }
V3 lerp(V3 a, V3 b, float t) { return add(a, mul(sub(b, a), t)); }
float clampf(float v, float lo, float hi) { return v < lo ? lo : v > hi ? hi : v; }
bool finite3(V3 a) { return std::isfinite(a.x) && std::isfinite(a.y) && std::isfinite(a.z); }
Q4 q4(float x, float y, float z, float w) { return Q4{ x, y, z, w }; }
Q4 qconj(Q4 q) { return q4(-q.x, -q.y, -q.z, q.w); }
// Hamilton product a*b: rotate by b first, then by a. UE composes child under parent as parent*child.
Q4 qmul(Q4 a, Q4 b) {
    return q4(a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
              a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
              a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
              a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z);
}
V3 qrot(Q4 q, V3 v) {
    const V3 u = v3(q.x, q.y, q.z);
    const V3 t = mul(cross(u, v), 2.0f);
    return add(add(v, mul(t, q.w)), cross(u, t));
}
V3 qinv(Q4 q, V3 v) { return qrot(qconj(q), v); }
Q4 qnorm(Q4 q) {
    const float l = sqrtf(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
    return l > 1e-8f ? q4(q.x / l, q.y / l, q.z / l, q.w / l) : q4(0, 0, 0, 1);
}
// the shortest rotation carrying direction a onto direction b
Q4 qfromto(V3 a, V3 b) {
    a = norm(a); b = norm(b);
    const float d = dot(a, b);
    if (d > 0.99999f) return q4(0, 0, 0, 1);
    if (d < -0.99999f) {
        V3 ax = cross(v3(1, 0, 0), a);
        if (len(ax) < 1e-4f) ax = cross(v3(0, 1, 0), a);
        ax = norm(ax);
        return q4(ax.x, ax.y, ax.z, 0.0f);
    }
    const V3 c = cross(a, b);
    return qnorm(q4(c.x, c.y, c.z, 1.0f + d));
}

Q4 qaxis(V3 axis, float deg) {
    const V3 a = norm(axis); const float h = deg * 0.0174532925f * 0.5f, s = sinf(h);
    return q4(a.x * s, a.y * s, a.z * s, cosf(h));
}
// the angle of a rotation, degrees
float qangle(Q4 q) { return 2.0f * acosf(clampf(fabsf(q.w), 0.0f, 1.0f)) * 57.2957795f; }
// the part of q that is NOT a turn about axis n (q = swing * twist, twist about n)
Q4 qswing(Q4 q, V3 n) {
    n = norm(n);
    const V3 p = mul(n, dot(v3(q.x, q.y, q.z), n));
    Q4 twist = q4(p.x, p.y, p.z, q.w);
    if (len(p) < 1e-6f && fabsf(q.w) < 1e-6f) twist = q4(0, 0, 0, 1);
    return qnorm(qmul(q, qconj(qnorm(twist))));
}
// t of the way from no rotation to q (along the same axis)
Q4 qscale(Q4 q, float t) {
    q = qnorm(q);
    if (q.w < 0.0f) q = q4(-q.x, -q.y, -q.z, -q.w);
    const float s = sqrtf(fmaxf(1.0f - q.w * q.w, 0.0f));
    if (s < 1e-6f) return q4(0, 0, 0, 1);
    const float h = acosf(clampf(q.w, -1.0f, 1.0f)) * t;
    const float k = sinf(h) / s;
    return q4(q.x * k, q.y * k, q.z * k, cosf(h));
}

// ------------------------------------------------------------------ the rig (from Lua)
int  g_n = 0;                         // bones in the table Lua sent
int  g_parent[MAX_BONES];             // parents precede children (a UE reference skeleton always does)
int  g_uarm[2] = { -1, -1 }, g_larm[2] = { -1, -1 }, g_hand[2] = { -1, -1 };   // [0] left, [1] right
int  g_thigh[2] = { -1, -1 }, g_calf[2] = { -1, -1 }, g_foot[2] = { -1, -1 };
int  g_flipper = -1;                  // SKXX_SkateSkel_Flipper: the skeleton's board (the deck's centre)
int  g_footAnchor[2] = { -1, -1 }, g_handAnchor[2] = { -1, -1 };               // on the board
// (v36) the spine from its first joint up to the chest (root first), and the fingers: [hand][finger 0 thumb .. 4 pinky]
// [joint 0 root .. 2 tip] -- from Lua's chain (entries 21-50), -1 = not there
int  g_spine[6] = { -1, -1, -1, -1, -1, -1 }, g_spineN = 0;
int  g_fing[2][5][3];
int  g_neck = -1, g_head = -1;                 // from Lua's chain (entries 19, 20)
bool g_fingOk[2] = { false, false };
bool g_rigOk = false;                 // arms resolved
bool g_boardOk = false;               // legs + board resolved too (the tweak needs them)
int  g_pelvis = -1, g_spine1 = -1, g_chest = -1;   // derived: the thighs' / upper arms' common ancestors, and
                                                   // the pelvis's child on the way up to the chest

// ------------------------------------------------------------------ settings + targets (from Lua)
void* volatile g_mesh = nullptr;      // our skater's USkaterSkeletalMeshComponent
void* volatile g_anim = nullptr;      // ...and its USkaterAnimInstance
void* volatile g_skater = nullptr;    // ...and the skater (ASkaterCharacterBase)
volatile int   g_traceFrames = 0;     // HJN_Trace(n): log the revert state for the next n poses
int            g_traceN = 0;
DWORD          g_traceT0 = 0;
volatile int   g_grabOn = 1;          // HJN_Set("grab", 0/1)
volatile float g_strength = 1.0f;     // HJN_Set("strength", 0..1): share of the way to the target
volatile float g_handUp = 0.0f;       // HJN_Set("handup", cm): the wrist this far above the game's anchor
volatile float g_tweakMax = 30.0f;    // HJN_Set("tweak", deg): most the board is tipped toward the grabbing hand
volatile float g_tweakShare = 0.6f;   // HJN_Set("tweakshare", 0..1): share of the full turn toward the hand
volatile int   g_legs = 1;            // HJN_Set("legs", 0/1): the feet ride the tipped board
volatile float g_leanMax = 30.0f;     // HJN_Set("lean", deg): the spine bends this far at most to bring the shoulder in reach
volatile float g_pullMax = 15.0f;     // HJN_Set("pull", cm): the board is drawn up toward the shoulder this far at most
volatile int   g_feet = 1;            // HJN_Set("feet", 0/1): during grabs the feet stand on the DRAWN deck's foot sockets
volatile float g_elbowOut = 0.6f;     // HJN_Set("elbowout", 0..2): the grabbing elbow is pushed out, away from the chest
volatile int   g_kneeAway = 1;        // HJN_Set("kneeaway", 0/1): a knee the grabbing arm passes through is moved aside
volatile int   g_guard = 1;           // HJN_Set("guard", 0 off / 1 when Lua asks / 2 always): un-twist the lower body
volatile int   g_revertCtl = 1;       // HJN_Set("revertctl", 0/1): the instant revert also turns the board's +0x4f0 quat
volatile float g_handFull = 0.8f;     // HJN_Set("handfull", 0..1): the game's hand alpha at which the hand is fully on
volatile int   g_guardFrames = 0;     // HJN_Guard(n): the guard runs for the next n poses
volatile int   g_holdFrames = 0;      // HJN_Hold(n): the body's world heading is held for the next n poses
volatile int   g_holdTotal = 0;
bool           g_holdHave = false;    // the heading to hold was taken (first pose of the window)
float          g_holdWant = 0.0f;     // deg: mesh world yaw + shoulder-line yaw, as it was at the start
float          g_lastHold = 0.0f;     // deg of correction applied last pose (trace)
volatile float g_ease = 0.2f;         // HJN_Set("ease", 0.02..1): share of the way the grab corrections move per frame
volatile int   g_tweakMode = 3;       // HJN_Set("tweakmode", 1 = v4 swing toward the anchor / 2 = the 6-DOF fit)
volatile float g_fitHand = 2.0f;      // HJN_Set("fithand", w): how hard the grab spot is pulled to the wrist vs each foot holding
volatile float g_fitMove = 15.0f;     // HJN_Set("fitmove", cm): most the board's centre is shifted by the fit
volatile float g_holdBleed = 0.12f;   // HJN_Set("holdbleed", 0..1): how fast a held heading jump is let go per frame

// ------------------------------------------------------------------ state kept between poses
V3    g_footOff[2] = { { 0, 0, 0 }, { 0, 0, 0 } };   // foot bone - the deck's foot socket, learned while riding
bool  g_footOffOk[2] = { false, false };
float g_pullState = 0.0f;             // cm, integrated from the hand's leftover gap
// the deck's UP in the skeleton board bone's own frame (v9). v5-v8 took the bone's +Z -- the v75 log showed
// that is the deck's DOWN (the wrist sat 4 cm ABOVE the grab spot with HandUp -4), so every tip, heel lift
// and edge roll went the wrong way. Learned while riding (the board then lies flat under the mesh's +Z);
// until then the bone's -Z, which is what that log implies.
V3    g_upL = { 0.0f, 0.0f, 1.0f };      // (v10: learned value in game is +Z -- the v75 "4 cm above" was not the axis)
bool  g_upOk = false;
// eased corrections (v4: v3 applied them at full size the frame they were wanted -- the body twitched
// into the grab): each moves only Ease of the way to what this frame wants
float g_leanS = 0.0f;                 // deg of spine lean
V3    g_feetS[2] = { { 0, 0, 0 }, { 0, 0, 0 } };   // cm the feet are shifted onto the drawn deck
V3    g_kneeS[2] = { { 0, 0, 0 }, { 0, 0, 0 } };   // the knee poles' bias away from the arm

// ------------------------------------------------------------------ stats (for HJN_Stats)
volatile LONG g_calls = 0, g_applied = 0, g_faults = 0, g_mismatch = 0;
volatile LONG g_guardHips = 0, g_guardFeet = 0, g_kneeHits = 0;
float g_lastW[2] = { 0, 0 }, g_lastGapBefore[2] = { 0, 0 }, g_lastGapAfter[2] = { 0, 0 }, g_lastReach[2] = { 0, 0 };
float g_lastTweak = 0.0f, g_lastFootMiss[2] = { 0, 0 }, g_lastLean = 0.0f, g_lastPull = 0.0f;
float g_lastFeetDeck[2] = { -1, -1 };  // how far the feet were moved to reach the drawn deck (cm; -1 = not used)
float g_lastDeckOff = -1.0f;           // deg between the drawn deck's foot-socket line and the skeleton board's
float g_legFoot[2] = { 0, 0 }, g_legKnee[2] = { 0, 0 }, g_legFold[2] = { 1, 1 }, g_legAnimFold[2] = { 1, 1 };  // per grab: most the foot / knee moved off the animation (cm), least fold (hip-foot / leg length), ours and the animation's
float g_deckShift = -1.0f;             // cm between the drawn deck's foot-socket midpoint and the skeleton board's foot-anchor midpoint
// pose telemetry for the trace (component-space yaws of body lines, deg)
float g_trYaw[6] = { 0, 0, 0, 0, 0, 0 };   // hips, shoulders, feet, skeleton board, drawn deck, mesh world yaw
bool  g_trGuardHips = false, g_trGuardFeet = false;

// ------------------------------------------------------------------ the pose (inside the hook)
struct TF { Q4 q; V3 p; V3 s; };
TF   g_C[MAX_BONES], g_L[MAX_BONES], g_Ct[MAX_BONES], g_Lt[MAX_BONES];
bool g_inSub[MAX_BONES];

void LocalOf(int i, const TF* comp, TF* loc) {
    const int p = g_parent[i];
    loc[i].s = comp[i].s;
    if (p < 0) { loc[i].q = comp[i].q; loc[i].p = comp[i].p; return; }
    loc[i].q = qmul(qconj(comp[p].q), comp[i].q);
    const V3 d = qinv(comp[p].q, sub(comp[i].p, comp[p].p));
    const V3 ps = comp[p].s;
    loc[i].p = v3(d.x / (fabsf(ps.x) > 1e-6f ? ps.x : 1.0f), d.y / (fabsf(ps.y) > 1e-6f ? ps.y : 1.0f),
                  d.z / (fabsf(ps.z) > 1e-6f ? ps.z : 1.0f));
}
void CompOf(int i, const TF* loc, TF* comp) {
    const int p = g_parent[i];
    comp[i].s = loc[i].s;
    if (p < 0) { comp[i].q = loc[i].q; comp[i].p = loc[i].p; return; }
    comp[i].q = qmul(comp[p].q, loc[i].q);
    comp[i].p = add(comp[p].p, qrot(comp[p].q, mulv(loc[i].p, comp[p].s)));
}
// g_Lt -> g_Ct for everything under (not including) bone i
void RebuildSub(int i) {
    for (int j = 0; j < g_n; j++) g_inSub[j] = false;
    g_inSub[i] = true;
    for (int j = i + 1; j < g_n; j++) {
        const int p = g_parent[j];
        if (p >= 0 && g_inSub[p]) { CompOf(j, g_Lt, g_Ct); g_inSub[j] = true; }
    }
}
void SetComp(int i, Q4 q, V3 p) { g_Ct[i].q = q; g_Ct[i].p = p; LocalOf(i, g_Ct, g_Lt); RebuildSub(i); }
void TurnComp(int i, Q4 q) { SetComp(i, qnorm(qmul(q, g_Ct[i].q)), g_Ct[i].p); }
void AimBone(int i, V3 from, V3 to) { if (len(from) > 1e-3f && len(to) > 1e-3f) TurnComp(i, qfromto(from, to)); }

// the middle joint of a two-bone chain from H to F with lengths a and b, bending toward pole
V3 MidJoint(V3 H, V3 F, float a, float b, V3 pole) {
    V3 hf = sub(F, H);
    float d = len(hf);
    const float reach = (a + b) * 0.995f;
    if (d > reach) { hf = mul(hf, reach / d); d = reach; }
    if (d < 1e-3f) return add(H, mul(norm(pole), a));
    const V3 along = mul(hf, 1.0f / d);
    const float cosA = clampf((a * a + d * d - b * b) / (2.0f * a * d), -1.0f, 1.0f);
    const float sinA = sqrtf(1.0f - cosA * cosA);
    V3 perp = sub(pole, mul(along, dot(pole, along)));
    if (len(perp) < 1e-4f) perp = cross(along, v3(0, 0, 1));
    perp = norm(perp);
    return add(add(H, mul(along, a * cosA)), mul(perp, a * sinA));
}
float ReadF(const void* base, int off) { return *(const float*)((const uint8_t*)base + off); }
V3 ReadV3(const void* base, int off) { const float* f = (const float*)((const uint8_t*)base + off); return v3(f[0], f[1], f[2]); }
const V3 kUp = { 0.0f, 0.0f, 1.0f };      // component space up (the skater mesh stands on its Z)
V3 flat(V3 a) { return v3(a.x, a.y, 0.0f); }
float yawOf(V3 a) { return atan2f(a.y, a.x) * 57.2957795f; }
// the angle between two directions in the ground plane, 0..180
float flatAngle(V3 a, V3 b) {
    a = flat(a); b = flat(b);
    if (len(a) < 1e-3f || len(b) < 1e-3f) return 0.0f;
    return acosf(clampf(dot(norm(a), norm(b)), -1.0f, 1.0f)) * 57.2957795f;
}
float armLen(int sd) {
    return len(sub(g_Ct[g_larm[sd]].p, g_Ct[g_uarm[sd]].p)) + len(sub(g_Ct[g_hand[sd]].p, g_Ct[g_larm[sd]].p));
}

// Put the hand (the wrist bone) on Hh: the upper arm aims at the solved elbow, the forearm at the hand.
// The elbow bends the way the animation bent it (the pole is the animated elbow's side), pushed out
// sideways by ElbowOut (away from the chest, so the arm goes round the legs instead of through them).
// The hand keeps its angle to the forearm. Returns the reach (upper arm + forearm) for the log.
// (v54) THE ELBOW'S SIDE. The pole starts from the animation's own elbow -- but when the animated arm is nearly straight
// that side is noise, and ElbowOut + Elbow<Grab> + the search's swing (up to 120 deg) could carry it right round: the
// elbow then bent BACKWARDS (a mirror-image arm, snapping back after the landing -- the user's Indy, tuning the via
// point and the elbow). The side is remembered from the last frames the animation bent the arm clearly, and no pole
// may lie more than 95 deg from it.
V3 g_armRef[2]; bool g_armRefOk[2] = { false, false }; LONG g_armHeld = 0, g_armSideLogs = 0;
constexpr float kArmSideCos = -0.0871557f;           // cos 95
V3 ArmSide(int sd) {
    const V3 S = g_Ct[g_uarm[sd]].p;
    const V3 p = sub(g_Ct[g_larm[sd]].p, add(S, mul(sub(g_Ct[g_hand[sd]].p, S), 0.5f)));
    const float a1 = len(sub(g_Ct[g_larm[sd]].p, S));
    if (len(p) > 0.2f * a1) {                        // the arm bent clearly: this is the side
        const V3 r = norm(p);
        g_armRef[sd] = g_armRefOk[sd] ? norm(lerp(g_armRef[sd], r, 0.2f)) : r;
        g_armRefOk[sd] = true;
    }
    if (g_armRefOk[sd]) return g_armRef[sd];
    if (g_chest >= 0) { const V3 out = flat(sub(S, g_Ct[g_chest].p)); if (len(out) > 1.0f) return norm(out); }
    return v3(0, 0, -1);
}
V3 HoldToSide(V3 pole, V3 ref, int sd) {
    const float pl = len(pole);
    if (pl < 1e-4f) return pole;
    const V3 pn = mul(pole, 1.0f / pl);
    const float cs = dot(pn, ref);
    if (cs >= kArmSideCos) return pole;
    V3 side = sub(pn, mul(ref, cs));                 // the part of the pole across the side
    if (len(side) < 1e-4f) side = cross(ref, v3(0, 0, 1));
    if (len(side) < 1e-4f) side = cross(ref, v3(1, 0, 0));
    side = norm(side);
    InterlockedIncrement(&g_armHeld);
    static LONG lastLog = 0; const LONG now = (LONG)GetTickCount();
    if (now - lastLog > 2000 && InterlockedIncrement(&g_armSideLogs) <= 100) {
        lastLog = now;
        Log("arm %d: the elbow would have bent %.0f deg from the animation's side (backwards) -- held to 95", sd, acosf(clampf(cs, -1.0f, 1.0f)) * 57.2957795f);
    }
    return mul(add(mul(ref, kArmSideCos), mul(side, 0.9961947f)), pl);   // 95 deg from the side, on the pole's own side of it
}
float GrabElbow();                                   // (v48) the grab's Elbow number (defined with the grab numbers, below)
float Arm(int sd, V3 Hh) {
    const int ua = g_uarm[sd], la = g_larm[sd], ha = g_hand[sd];
    const V3 S = g_Ct[ua].p;
    const float a1 = len(sub(g_Ct[la].p, S)), a2 = len(sub(g_Ct[ha].p, g_Ct[la].p));
    V3 pole = norm(sub(g_Ct[la].p, add(S, mul(sub(g_Ct[ha].p, S), 0.5f))));
    if (g_chest >= 0 && g_elbowOut > 0.0f) {
        const V3 out = flat(sub(S, g_Ct[g_chest].p));
        if (len(out) > 1.0f) pole = add(pole, mul(norm(out), g_elbowOut));
    }
    const V3 d = sub(Hh, S); const float dl = len(d);
    if (dl > (a1 + a2) * 0.98f) Hh = add(S, mul(d, (a1 + a2) * 0.98f / dl));
    // (v48) ELBOW<GRAB>: the elbow swung round the shoulder-hand line by the grab's own number. With the shoulder and the
    // hand where they are, that swing is the one freedom the arm has left, and it is what sets how steep the forearm hangs
    const float swivel = GrabElbow();
    if (fabsf(swivel) > 0.01f && dl > 1.0f) pole = qrot(qaxis(mul(d, 1.0f / dl), swivel), pole);
    pole = HoldToSide(pole, ArmSide(sd), sd);         // (v54) never backwards
    const V3 E = MidJoint(S, Hh, a1, a2, pole);
    AimBone(ua, sub(g_Ct[la].p, S), sub(E, S));
    AimBone(la, sub(g_Ct[ha].p, g_Ct[la].p), sub(Hh, g_Ct[la].p));
    return a1 + a2;
}

// Put the foot on F with the rotation footQ: the thigh aims at the solved knee (bending the way it bent,
// plus bias -- used to swing a knee out of an arm's way), the calf at the foot, then the foot takes footQ.
// Returns how far short the foot stopped (cm).
// (v88) A LEG'S BONES ARE THEIR OWN LENGTH WHEN THE MOD PLACES ITS FOOT IN A TRICK. "Switch no comply: the feet are warping,
// almost like they're getting crumpled -- a leg segment issue, like they're getting compressed. You have a reference." The
// game's foot IK squeezes the shin to put a foot on its socket (29-42.7 cm riding, where the bone is 41.2), and this solve
// keeps the lengths it is handed: a foot the mod then pins somewhere else (the plant, the held feet, the boneless's glued
// back foot) was reached with a squeezed shin. While one of those parts is on (g_legFix, set by the hook) a bone more than
// 4 % off the leg's own length (the riding median, LegRefLearn) is put back first; the knee then bends for the difference.
extern float g_legRef[2][2]; extern bool g_legRefOk;
bool g_legFix = false; LONG g_legFixed = 0; float g_legFixMost = 0.0f;
// (v102) ...AND UNTIL THE LEGS ARRIVE SOUND AGAIN AFTER A GOOFY RIDER'S SWITCH PLANT. "The boneless are something nightmares
// are made of." The recording of 6 Oct 21:30 (segments 36-39, the goofy rider's switch boneless): from the landing on the
// game hands in the left leg straight, the knee over the ankle and the shin at 58-77 % of its length, for one to three
// seconds -- and the repair above stopped with the trick's last window, so that pose was drawn as it came. The Lua names a
// time (HJN_Set("leglinger", seconds)) when it puts the mirror table back: the repair stays on while riding until both
// shins have arrived within 6 % of their own for 12 poses running, or the time is up, or a grab or the air begins.
volatile ULONGLONG g_legLingerUntil = 0; int g_legLingerOk = 0; LONG g_legLingered = 0, g_legLingerLogs = 0;
// (v95) WHICH WAY A KNEE BENDS WHEN THE POSE DOES NOT SAY. The knee's way was always taken from the pose's own knee: how
// far it stands off the line from hip to ankle. Riding regular the game draws the leading leg STRAIGHT with a squeezed
// shin (hip to ankle 65-74 cm on bones of 43 + 26-33), so that knee is ON the line and its "way" was rounding noise:
// the mini 180 of 4 Oct 22:53:51 has the left knee jump 43 and 38 cm on landing poses 3 and 4 -- from one side of the leg
// to the other and back -- with both feet held still on the deck. Through a hop's poses (g_poleToes, set by the hook)
// a leg that is less than 18 cm bent takes its knee's way from its TOES (across the leg it is being solved to): all of it
// under 9 cm, blended in between. (Review: measured on the leg AFTER its bones are put back the squeezed leading leg is
// 8.3-9.6 cm off its line, not on it -- a band of 3..9 did nothing on the poses it was written for; with 9..18 the knee's
// step on landing pose 3 of the two 180s recorded goes 35 -> 7 and 38 -> 11 cm, the straight hops stay within 1 %.)
// A knee the pose really bends keeps its own way. HJN_Set("kneetoes", 0) = as it was.
extern int g_toe[2];
bool g_poleToes = false; volatile int g_kneeToes = 1; LONG g_poleToed = 0;
// (v96) ...AND THE WAY IT BENDS WHEN THE POSE DOES SAY IS READ FROM THE POSE, ONCE. "Doing the 180 hippie jump, our method of
// landing and sliding to the final position works. However now the foot is warping during the rotation, which is new."
// Replayed offline from the recordings of 5 Oct 00:10-00:11 (every part of the hop's air and landing, to 0.6 cm of what was
// drawn): Leg() reads the knee's way off the leg as it stands when it is called, and v95 calls it two or three times on a
// pose of the air -- LegUnstretch (bones back, ankle kept), then HopPull, then HopPlan -- so each solve took its knee's way
// from the leg the solve before had left. Over the last third of a crouched 180 from regular the game squeezes the left
// shin 41 -> 11 cm, its knee then 10 cm off the hip-ankle line: LegUnstretch folds that leg up on an ankle 40 cm from the
// hip, in the plane those 10 cm of side-slip span, and HopPlan then opened it out in THAT plane -- the left knee swung
// 28 deg inward over the last six poses of the air (the knees 43 -> 27 cm apart at 00:11:11, 44 -> 29 at 00:11:17; with
// the pose's own way 43 -> 36), 37 deg round from its own toes, and stepped 13 cm on the touchdown pose. In the mini 180
// the second and third solve each bent the right knee part of the way to its toes again: 3 cm in one pose where the plan
// begins.
// Now, through a hop's air, every solve on a pose is given the knee's way THE POSE CAME IN WITH (g_C: the thigh's own
// direction counts for most of it, a squeezed shin for as little as is left of it), taken across the leg as it will be: all
// of it where that stands 18 cm or more off the new hip-ankle line, none under 9 (there the pose does not say: the leg's
// own way and the toes', as before). HJN_Set("hopknee", 0) = v95.
// (v97) ...AND "THE TOES' WAY" IS THE WAY THAT SHIN STANDS ON ITS FOOT WHEN IT RIDES. "Hippies are still tearing at the ankles."
// The recording of 5 Oct 08:59 (a straight hop riding regular; the 180 before it reads the same): for 0.6 s after touchdown
// the game hands in the leading leg with its shin squeezed to 22-37 cm, v96 gives the bones their length back and bends the
// knee for it "toward the toes" -- the line from the ankle to the toe joint, taken across the leg. Riding, that knee stands
// 10 cm OUTSIDE its ankle along the board and 25 cm toward the toes (hip -6, knee +17, ankle +7 along the board); solved
// toward the toes alone, with the hip 12 cm inside the ankle, it came out 10 cm INSIDE it (hip +10, knee +12, ankle +22):
// the shin leaning 28-34 deg to the foot's own side where riding has 1-9 -- an ankle rolled over by 25 deg and more on a
// foot that lies flat on the deck, for 35 poses after every landing ridden regular, the knees knocked together. A foot does
// not say where its knee goes by its toes: it says it by how the shin stands on it. That direction (ankle to knee, in the
// foot bone's own frame) is kept from the very poses a riding stance is learned from, where the game's own leg is whole
// and really bent (the mean of the first 30, then a slow average); taken across the leg being solved it is the knee's way
// wherever the toes' way was used: a straight or squeezed leg through a hop's air and landing (Leg, g_poleToes) and the
// legs that keep their own length after one (LandOwnLegs). Replayed on that recording: the shin 2-11 deg to the side
// (28-33 before), the knee 22-30 cm along the board (8-13), stepping 1-5 cm a pose; it meets the game's own knee within
// 6 cm when the game's leg is whole again. HJN_Set("shinride", 0) = v96's (the toes' way).
V3 g_shinRide[2] = { { 0, 0, 0 }, { 0, 0, 0 } }; int g_shinRideN[2] = { 0, 0 }; volatile int g_shinRideOn = 1; LONG g_shinRided = 0;
bool ShinWay(int sd, Q4 footQ, V3 legLine, V3& out) {         // the riding shin's direction on a foot turned footQ, across the leg (hip to ankle = legLine)
    if (g_shinRideOn == 0 || sd < 0 || sd > 1 || g_shinRideN[sd] < 30) return false;
    V3 s = qrot(qnorm(footQ), g_shinRide[sd]);
    const float l2 = dot(legLine, legLine);
    if (l2 > 1.0f) s = sub(s, mul(legLine, dot(s, legLine) / l2));
    if (!finite3(s) || len(s) < 0.25f) return false;
    out = norm(s);
    InterlockedIncrement(&g_shinRided);
    return true;
}
extern volatile int g_airFrames, g_landFrames;
volatile int g_hopKnee = 1; LONG g_hopKneed = 0;
// (v99) THE KNEE IS A HINGE, AND A SOLVED LEG IS ROLLED ONTO IT. "Still a lot of leg tearing on a lot of things. Maybe we
// gotta work on degrees of freedom ... maybe we're just trying to be too rigid with everything." Leg() places the knee
// and then turns the thigh and the shin onto their new lines by the SHORTEST turn: each bone keeps whatever roll about
// its own length the pose came in with. On this rig (no twist bones: the skin hangs on thigh, shin and foot alone) that
// roll IS the knee: the shin swings about one axis of the thigh, and when a solve bends a knee another way than the pose
// had it -- a squeezed straight leg given its length back after every landing (a 59 deg bend made where the game had
// none, for up to six seconds), a plant leg carried to the ground, a foot held on its spot -- the bend comes out partly
// SIDEWAYS through that axis: the knee sheared, the shin's skin wrung against the thigh's and the foot's against the
// shin's. Nothing in the recordings shows it (they keep where the joints are, and those were right): v99's recorder
// keeps the two bones' turns as well.
// The axis is read from the game's own legs: on the poses the riding shin is learned from (the leg whole and really
// bent) the normal of the leg's plane, taken into the thigh's own frame and into the shin's, is one fixed direction in
// each -- kept only once 30 poses agree to 20 deg. After the knee is placed each of the two bones is turned about its
// own length until that axis lies on the new plane's normal: all of it from a knee 9 cm off the leg's line, none under
// 3 (a straight leg has no plane and keeps the roll it has). No joint moves by it. HJN_Set("legroll", 0) = v98's.
double NowS(); float Sm01(float x);
V3 g_hingeTh[2] = { { 0, 0, 0 }, { 0, 0, 0 } }, g_hingeCa[2] = { { 0, 0, 0 }, { 0, 0, 0 } };
int g_hingeN[2] = { 0, 0 }, g_hingeMiss[2] = { 0, 0 }, g_hingeOdd[2] = { 0, 0 }, g_hingeAgain[2] = { 0, 0 };
volatile int g_hingeOn = 1; LONG g_hingeRolled = 0, g_hingeLogs = 0; float g_hingeLast[2][2] = { { 0, 0 }, { 0, 0 } }, g_hingeMost = 0.0f; double g_hingeSaid = -1.0e9;
// (the further v99 switches the recorder reads: the foot sockets turned for this pose, a hop's hips, the plant foot's swivel)
volatile int g_sockLive = 0, g_plSwOn = 0, g_sockMirLive = 0;
void HingeLearn(int k, V3 ht, V3 hc) {                           // one riding pose's reading of leg k's hinge: in its thigh's frame, in its shin's
    if (g_hingeN[k] > 0 && fminf(dot(ht, g_hingeTh[k]), dot(hc, g_hingeCa[k])) < 0.94f) {
        g_hingeOdd[k]++;
        if (g_hingeN[k] >= 30) {
            if (++g_hingeMiss[k] <= 240) return;
            Log("legs: the %s knee's hinge has not agreed with what was learned for 240 riding poses (another skater, a bad start) -- learned afresh", k ? "R" : "L");
        } else if (++g_hingeAgain[k] == 40)
            Log("legs: the %s knee's hinge does not hold still in the riding poses (begun again 40 times): until 30 of them agree to 20 deg a solved leg keeps the roll it came in with", k ? "R" : "L");
        g_hingeN[k] = 0; g_hingeMiss[k] = 0;
    }
    if (g_hingeN[k] >= 30) {
        g_hingeMiss[k] = 0;
        g_hingeTh[k] = norm(lerp(g_hingeTh[k], ht, 0.02f)); g_hingeCa[k] = norm(lerp(g_hingeCa[k], hc, 0.02f));
        return;
    }
    const float f = 1.0f / (float)(g_hingeN[k] + 1);
    g_hingeTh[k] = (g_hingeN[k] == 0) ? ht : norm(lerp(g_hingeTh[k], ht, f));
    g_hingeCa[k] = (g_hingeN[k] == 0) ? hc : norm(lerp(g_hingeCa[k], hc, f));
    if (++g_hingeN[k] == 30)
        Log("legs: the %s knee's hinge, in its thigh's own frame (%.2f %.2f %.2f) and in its shin's (%.2f %.2f %.2f) -- 30 riding poses agree to 20 deg (%d did not on the way): a leg the mod solves is rolled onto it",
            k ? "R" : "L", g_hingeTh[k].x, g_hingeTh[k].y, g_hingeTh[k].z, g_hingeCa[k].x, g_hingeCa[k].y, g_hingeCa[k].z, g_hingeOdd[k]);
}
// bone (thigh: which 0, shin: 1) of leg sd runs from a to b: turned about that line until its hinge axis lies on nrm, by the share w
void HingeRoll(int sd, int bone, int which, V3 a, V3 b, V3 nrm, float w) {
    const V3 ax = sub(b, a); const float al = len(ax);
    if (al < 1.0f || w <= 0.0f) return;
    const V3 t = mul(ax, 1.0f / al);
    V3 h = qrot(g_Ct[bone].q, which ? g_hingeCa[sd] : g_hingeTh[sd]); h = sub(h, mul(t, dot(h, t)));
    const V3 n = sub(nrm, mul(t, dot(nrm, t)));
    if (!finite3(h) || !finite3(n) || len(h) < 0.3f || len(n) < 0.3f) return;
    const V3 hn = norm(h), nn = norm(n);
    const float ang = atan2f(dot(cross(hn, nn), t), dot(hn, nn)) * clampf(w, 0.0f, 1.0f);
    if (!std::isfinite(ang) || fabsf(ang) < 0.002f) return;
    TurnComp(bone, qaxis(t, ang * 57.2957795f));
    const float deg = ang * 57.2957795f;
    g_hingeLast[sd][which] = deg;
    if (fabsf(deg) > g_hingeMost) g_hingeMost = fabsf(deg);
    InterlockedIncrement(&g_hingeRolled);
    if (fabsf(deg) > 25.0f && g_hingeLogs < 60) {
        const double now = NowS();
        if (now - g_hingeSaid > 0.4) {
            g_hingeSaid = now; InterlockedIncrement(&g_hingeLogs);
            Log("hinge: the %s %s rolled %+.0f deg about its own length onto its knee's plane (it came in turned that far off it)", sd ? "R" : "L", which ? "shin" : "thigh", deg);
        }
    }
}
// (v100) IN A HOP'S AIR THE FEET ARE FREE, AND A LEG THE MOD HAS MADE ANOTHER LEG BENDS OVER ITS OWN FOOT. "The hippie jumps
// still have tearing" -- the screenshots of 5 Oct 14:25 have the trouser cuffs wrung flat between shin and shoe. v99's
// recorder keeps the shin bone's own turn, and it shows two things no earlier recording could.
// 1 THE GAME'S OWN TUCK WRINGS THE ANKLE. In a hop's air the game's knees stand out to the sides (the knee 80-115 deg round
//   the leg from the toes) while each foot keeps the heading it rides with: the foot 43 -> 75 deg round its shin through
//   the rise of the 180 of 14:31:05, with nothing of the mod's on the leg. On the board that is an ollie's tuck; under a
//   body the board is not under it is a cuff twisted most of a quarter turn. In the air nothing holds a foot: AnkleFree
//   turns each foot about its own shin until the twist against how it rides on that shin is within 18 deg (15 % of
//   what is over that is left in) -- the toes go out with the knee. Position, pitch and roll are the pose's.
// 2 A LEG MADE LONGER OR SHORTER KEPT THE GAME'S KNEE. The air took the knee's way from the pose as it came in wherever
//   the game's knee was 18 cm off its line (v96) -- right for the game's own leg, wrong for another one: the mini hop
//   lets its feet down 23 cm (hip to ankle 54 -> 77 cm), and that long leg was bent out sideways as the tucked one was,
//   under a foot that points ahead (and v99, rolling the shin onto that plane, put all of it into the ankle: 98-115 deg,
//   14:30:36; before v99 it sat in the knee). Now the pose's knee counts only as far as the leg is still the pose's
//   (all of it to 4 cm of difference hip-to-ankle, none from 14) and as far as the landing plan has not begun to carry
//   the feet; the rest is the way the knee's hinge lies on that FOOT when it rides (the hinge taken into the foot's own
//   frame on the riding poses: FootWay) -- the knee over the foot, the ankle unwrung, the hip taking the turn.
// HJN_Set("hopfree", 0) = v99's air; ("anklim", deg).
V3 g_hingeFt[2] = { { 0, 0, 0 }, { 0, 0, 0 } }; Q4 g_footRel[2] = { { 0, 0, 0, 1 }, { 0, 0, 0, 1 } }; int g_footRelN[2] = { 0, 0 };
volatile int g_hopFree = 1, g_ankNow = 0; volatile float g_ankLim = 18.0f; LONG g_ankFreed = 0, g_ankLogs = 0; float g_ankMost = 0.0f;
extern float g_planW;
void FootRelLearn(int k, V3 hf, Q4 fr) {                         // one riding pose: the hinge in the foot's own frame, the foot's turn against its shin
    if (g_footRelN[k] > 0 && g_footRel[k].x * fr.x + g_footRel[k].y * fr.y + g_footRel[k].z * fr.z + g_footRel[k].w * fr.w < 0.0f) fr = q4(-fr.x, -fr.y, -fr.z, -fr.w);
    const float f = (g_footRelN[k] < 30) ? 1.0f / (float)(g_footRelN[k] + 1) : 0.02f;
    if (g_footRelN[k] == 0) { g_hingeFt[k] = hf; g_footRel[k] = fr; }
    else {
        g_hingeFt[k] = norm(lerp(g_hingeFt[k], hf, f));
        const Q4 a = g_footRel[k];
        g_footRel[k] = qnorm(q4(a.x + (fr.x - a.x) * f, a.y + (fr.y - a.y) * f, a.z + (fr.z - a.z) * f, a.w + (fr.w - a.w) * f));
    }
    if (g_footRelN[k] < 30) g_footRelN[k]++;
}
// the knee's way for which the ankle is not wrung: across the leg (hip to ankle = legLine), on a foot turned footQ
bool FootWay(int sd, Q4 footQ, V3 legLine, V3& out) {
    if (sd < 0 || sd > 1 || g_hingeN[sd] < 30 || g_footRelN[sd] < 30) return ShinWay(sd, footQ, legLine, out);
    const float l2 = dot(legLine, legLine);
    if (l2 < 1.0f) return false;
    const V3 an = mul(legLine, 1.0f / sqrtf(l2));
    V3 n = qrot(qnorm(footQ), g_hingeFt[sd]); n = sub(n, mul(an, dot(n, an)));
    if (!finite3(n) || len(n) < 0.3f) return ShinWay(sd, footQ, legLine, out);
    out = norm(cross(an, norm(n)));
    return finite3(out);
}
// each foot turned about its own shin until its twist against how it rides on that shin is within the limit (the share w of that)
bool AnkleFree(float w) {
    g_ankNow = 0;
    if (g_hopFree == 0 || w <= 0.01f) return false;
    bool changed = false;
    for (int k = 0; k < 2; k++) {
        const int ca = g_calf[k], ft = g_foot[k];
        if (ca < 0 || ft < 0 || g_footRelN[k] < 30) continue;
        const V3 sh = sub(g_Ct[ft].p, g_Ct[ca].p); const float sl = len(sh);
        if (!(sl > 5.0f)) continue;
        const V3 a = mul(sh, 1.0f / sl);
        const Q4 qref = qnorm(qmul(g_Ct[ca].q, g_footRel[k]));   // the foot as it rides, on the shin as it is drawn
        Q4 D = qnorm(qmul(g_Ct[ft].q, qconj(qref)));             // from that to the foot as it is: a twist about the shin, then a swing
        if (D.w < 0.0f) D = q4(-D.x, -D.y, -D.z, -D.w);
        const float th = 2.0f * atan2f(D.x * a.x + D.y * a.y + D.z * a.z, D.w) * 57.2957795f;
        const float lim = clampf(g_ankLim, 0.0f, 90.0f), ex = fabsf(th) - lim;
        if (!std::isfinite(th) || !(ex > 0.5f)) continue;
        const float to = (th > 0.0f ? 1.0f : -1.0f) * (lim + ex * 0.15f);
        const float turn = (to - th) * clampf(w, 0.0f, 1.0f);
        const Q4 q = qnorm(qmul(g_Ct[ft].q, qaxis(qinv(qref, a), turn)));
        if (!std::isfinite(q.x) || !std::isfinite(q.y) || !std::isfinite(q.z) || !std::isfinite(q.w)) continue;
        SetComp(ft, q, g_Ct[ft].p);
        if (fabsf(th) > g_ankMost) g_ankMost = fabsf(th);
        InterlockedIncrement(&g_ankFreed);
        changed = true;
    }
    if (changed) g_ankNow = 1;
    return changed;
}
// (v98) ...AND A HOP TAKEN OFF INSIDE THE LAST LANDING'S OWN-LENGTH WINDOW BEGINS WHERE THAT PART HAD THE KNEE. Two rules
// meet on the first pose of such a hop's air: up to it LandOwnLegs draws a squeezed leg's knee the way its shin rides
// (all of it from 5 cm of squeeze), from it on the air takes the knee's way the pose came in with (all of it from 18 cm
// of bend). On a leg that is both squeezed and bent they are not the same way: the second of four hops in a row on
// 5 Oct 11:19 (the recording's segment 7, pose 155) has the left knee 25 deg round its leg on the last riding pose and 50
// on the first of the air -- 11.9 cm in one pose, the game's own knee moving 2.7. LandOwnLegs now keeps how far round
// the leg it put the knee from the pose's own (a signed angle about hip to ankle, per leg, on poses the air's rule is
// off), and the air's rule turns the pose's way by that much on its first pose and eases it out over 0.15 s. A hop from
// plain riding has nothing kept (the angle is 0.15 s old at most) and is solved exactly as before.
float g_ownTwist[2] = { 0, 0 }; double g_ownTwistT[2] = { -1.0e9, -1.0e9 }, g_ownTwistSaid[2] = { 0, 0 }; LONG g_ownTwistLogs = 0;
double NowS(); float Sm01(float x);
float Leg(int sd, V3 F, Q4 footQ, V3 bias = V3{ 0, 0, 0 }, const V3* poleOv = nullptr) {
    const int th = g_thigh[sd], ca = g_calf[sd], ft = g_foot[sd];
    const V3 S = g_Ct[th].p;
    const float a1 = len(sub(g_Ct[ca].p, S)), a2 = len(sub(g_Ct[ft].p, g_Ct[ca].p));
    V3 pole = poleOv ? *poleOv : add(norm(sub(g_Ct[ca].p, add(S, mul(sub(g_Ct[ft].p, S), 0.5f)))), bias);
    if (!poleOv && g_poleToes && g_toe[sd] >= 0) {               // (v95) a nearly straight leg: the knee over the toes
        const V3 hf = sub(g_Ct[ft].p, S); const float hl2 = dot(hf, hf);
        const V3 kv = sub(g_Ct[ca].p, S);
        const V3 kp = (hl2 > 1.0f) ? sub(kv, mul(hf, dot(kv, hf) / hl2)) : kv;   // the knee, off the hip-ankle line
        const float bend = len(kp), wt = 1.0f - clampf((bend - 9.0f) / 9.0f, 0.0f, 1.0f);
        if (wt > 0.0f) {
            const V3 dv = sub(F, S); const float dl2 = dot(dv, dv);
            V3 toes = qrot(qnorm(footQ), norm(g_Lt[g_toe[sd]].p));
            if (dl2 > 1.0f) toes = sub(toes, mul(dv, dot(toes, dv) / dl2));      // ...across the leg as it will be
            { V3 sw; if (ShinWay(sd, footQ, dv, sw)) toes = sw; }                // (v97) ...or, once it is known, the way the shin stands on that foot riding
            if (len(toes) > 0.25f) {
                toes = norm(toes);
                const V3 own = (bend > 0.5f) ? mul(kp, 1.0f / bend) : toes;
                pole = add((dot(own, toes) < -0.2f) ? toes : norm(lerp(own, toes, wt)), bias);
                InterlockedIncrement(&g_poleToed);
            }
        }
    }
    if (!poleOv && g_hopKnee != 0 && g_airFrames > 0 && g_landFrames <= 0) {   // (v96) a hop's air: the knee's way as the pose came in
        const V3 gS = g_C[th].p, dv = sub(F, S); const float dl2 = dot(dv, dv);
        V3 pp = sub(g_C[ca].p, add(gS, mul(sub(g_C[ft].p, gS), 0.5f)));
        if (dl2 > 1.0f) pp = sub(pp, mul(dv, dot(pp, dv) / dl2));                // ...across the leg as it will be
        if (dl2 > 1.0f && g_ownTwist[sd] != 0.0f) {                              // (v98) ...turned, on the air's first poses, to where the last landing's own-length part had the knee
            const double age = NowS() - g_ownTwistT[sd];
            const float tw = (age >= 0.0 && age < 0.15) ? g_ownTwist[sd] * (1.0f - Sm01((float)(age / 0.15))) : 0.0f;
            if (fabsf(tw) > 0.005f && finite3(pp)) {
                const V3 ax = mul(dv, 1.0f / sqrtf(dl2));
                pp = add(mul(pp, cosf(tw)), mul(cross(ax, pp), sinf(tw)));
                if (g_ownTwistSaid[sd] != g_ownTwistT[sd] && fabsf(g_ownTwist[sd]) > 0.14f) {
                    g_ownTwistSaid[sd] = g_ownTwistT[sd];
                    if (InterlockedIncrement(&g_ownTwistLogs) <= 60)
                        Log("hop: taken off inside the last landing's own-length window -- the %s knee begins %.0f deg round its leg from the pose's own way (where the pose before had it) and eases to it over 0.15 s",
                            sd ? "R" : "L", g_ownTwist[sd] * 57.29578f);
                }
            }
        }
        const float kt = clampf((len(pp) - 9.0f) / 9.0f, 0.0f, 1.0f); float kw = kt * kt * (3.0f - 2.0f * kt);
        V3 fw;
        if (g_hopFree != 0 && dl2 > 1.0f && FootWay(sd, footQ, dv, fw)) {        // (v100) ...as far as the leg is still the pose's and the landing plan has not begun; the rest over its own foot
            const float chg = Sm01((fabsf(sqrtf(dl2) - len(sub(g_C[ft].p, gS))) - 4.0f) / 10.0f);
            kw *= (1.0f - chg) * (1.0f - clampf(g_planW, 0.0f, 1.0f));
            V3 pd = fw;
            if (kw > 0.0f && finite3(pp) && len(pp) > 1e-3f) {
                const V3 pn = norm(pp);
                pd = (dot(pn, fw) < -0.85f) ? (kw > 0.5f ? pn : fw) : norm(lerp(fw, pn, kw));
            }
            pole = add(pd, bias);
            InterlockedIncrement(&g_hopKneed);
        }
        else if (kw > 0.0f && finite3(pp)) { pole = add(norm(lerp(norm(sub(pole, bias)), norm(pp), kw)), bias); InterlockedIncrement(&g_hopKneed); }
    }
    const V3 want = F;
    const V3 d = sub(F, S); const float dl = len(d);
    if (dl > (a1 + a2) * 0.995f) F = add(S, mul(d, (a1 + a2) * 0.995f / dl));
    const V3 K = MidJoint(S, F, a1, a2, pole);
    AimBone(th, sub(g_Ct[ca].p, S), sub(K, S));
    float hw = 0.0f; V3 hn = v3(0.0f, 0.0f, 0.0f);            // (v99) the leg's plane as the knee was just placed: its normal, and how far the knee stands off the line
    if (g_hingeOn != 0 && g_hingeN[sd] >= 30) {
        const V3 al = sub(F, S); const float all = len(al);
        if (all > 1.0f) {
            const V3 an = mul(al, 1.0f / all);
            const V3 pp = sub(pole, mul(an, dot(pole, an))), kk = sub(K, S);
            if (finite3(pp) && len(pp) > 1e-3f) { hn = norm(cross(norm(pp), an)); hw = Sm01((len(sub(kk, mul(an, dot(kk, an)))) - 3.0f) / 6.0f); }
        }
    }
    if (hw > 0.0f) HingeRoll(sd, th, 0, S, g_Ct[ca].p, hn, hw);
    AimBone(ca, sub(g_Ct[ft].p, g_Ct[ca].p), sub(F, g_Ct[ca].p));
    if (hw > 0.0f) HingeRoll(sd, ca, 1, g_Ct[ca].p, g_Ct[ft].p, hn, hw);
    SetComp(ft, qnorm(footQ), g_Ct[ft].p);
    return len(sub(want, g_Ct[ft].p));
}
// (v89) ...ONCE A POSE, BOTH LEGS, EASED. v88 put the bones back inside Leg(): only for a leg, and on a pose, that something
// happened to solve. The no comply of 18:07:27: the plant leg's shin drawn 41 cm while GroundFeet lifted the foot, 28 (the
// game's) on the pose it stopped; the boneless of 18:17:40: 41 -> 33 on the pose the hand's weight reached 0 -- the knee
// 10-19 cm somewhere else from one pose to the next. Now, first thing on every pose of the window (and easing in and out,
// a quarter a pose), each leg's bones go to their own length and the foot is put back exactly where the pose had it.
extern volatile int g_plantMode;
float g_legFixW = 0.0f;
// (v94) ...AND THE HIPS IN THEIR SOCKETS. The trick traces give the pelvis bone's height, each ankle's, and each leg's
// length hip joint to ankle: riding, the hip joints stand level with the pelvis bone (0 +- 3 cm; the rig has them 8.7 cm
// to either side of it and nowhere else), but through a no comply the plant side's is 6 -> 16 cm UNDER it (0.20-0.45 s:
// 20:33:51, 20:34:01, 20:08:30 all alike) and the back leg's 8-9 cm (0.30-0.39 s, as the board comes up under it) -- in
// the game's own pose too (hips 125, ankle 37, bones 43 + 32: the joint is 13 cm out at least). The game's foot placing
// drags the thigh bone out of the pelvis toward a foot place the leg cannot reach, as it squeezes the shin. Every leg the
// mod then solved started from that joint: "the stretch" was 16 cm of hip, not only of leg. While a plant is on (g_hipFix,
// set by the hook) each thigh's place against the pelvis is put back to where it rides -- learned from plain riding poses
// (the mean of the first 30, then a slow average of poses within 3 cm of it; taken afresh when none agree) -- eased as the bone lengths are, and the
// foot put back where the pose had it. The last pose's gaps are kept for the trace (g_hipGap).
extern volatile int g_riding; extern bool g_noLearn;
bool g_hipFix = false; float g_hipFixW = 0.0f, g_hipGap[2] = { 0, 0 }, g_hipGapMost = 0.0f;
// (v99) ...AND THROUGH A HOP, AND WITH A HAND ON THE BOARD. "And I don't know what to do on the hippie jumps, man. It's just
// tearing." The recording of 5 Oct 12:06 has BOTH hip joints out of the pelvis in every hop, in the game's own pose and
// so in the drawn one (the plants' poses had them put back since v94, the hops' never): 3-4 cm over the last poses of the
// air, 12-19 cm on the touchdown pose, 6-7 on the next ones, over 4 cm on 10-20 poses of every hop -- the thighs' roots
// torn a hand's width off the trunk as the board is met; and 13-20 cm for 45-52 poses while a hand is on the board
// before a boneless (the plant flag is not up yet). HopHips puts each thigh's root back where it rides (LegOwnLength's own
// reference and its test for a mirrored pose) on a hop's air, landing and own-length poses, eased in and out over four
// poses, and solves the leg to the ankle the pose had -- as far back only as the leg, at the length it has on that pose,
// still reaches that ankle (from its socket it is 2-5 % short on a touchdown pose or two: the foot keeps its place, the
// joint is left that much out). A hand on the board: the plant's own repair (g_hipFix) is on for it too.
// HJN_Set("hophips", 0) = v98's.
volatile int g_hopHipOn = 1; float g_hopHipW = 0.0f, g_hopHipMost = 0.0f; LONG g_hopHipped = 0, g_hopHipLogs = 0; bool g_hopHipWas = false;
volatile int g_hipFixOn = 1;                 // HJN_Set("hipfix", 0/1)
V3 g_hipRef[2] = { { 0, 0, 0 }, { 0, 0, 0 } }; int g_hipRefN[2] = { 0, 0 }, g_hipRefMiss[2] = { 0, 0 };
// ==== (v96) THE OTHER KNEE KEEPS ITS SIDE WHERE THE GAME'S LEG DOES NOT SAY ===========================================
// "The first no comply: the unfixed leg was all crazy and did like a scrambled mesh thing, but only on the first time. All
// the subsequent attempts looked good." The recording of 4 Oct 23:59:48 against the eight regular no complies after it.
// In EVERY one the game draws the back leg dead straight at 0.18-0.27 s (hip to ankle 99 % of its bones, the knee 1-3 cm
// off the line) and then folds it again. Eight times the game's knee comes out forward, 17-24 cm off the line by 0.33 s.
// That once it stays ON the line for another 0.3 s (3-7 cm off it) and the game takes the length out of the shin instead:
// 26, 21, 17, 15, 12, 12, 8, 6, 6, 6 cm at 0.32-0.47 s (41.2 its own), in the game's own pose. LegOwnLength puts the
// bones back and solves the leg to its ankle, and Leg() takes the knee's way from the pose's own knee -- here from a
// shin of 6 cm drawn out sevenfold: the knee went round the leg, (+13 -24) (+26 -13) (+30 +1) (-5 +30) (+18 +30) cm off
// its line on successive poses, 44 cm in one of them. (The other eight have the same thing small: over the straight
// stretch the drawn knee dips 7-10 cm to the BACK of the line and comes forward again in steps of up to 12 cm.)
// A pose says which way a knee bends only as far as its knee stands off its line. For a leg the soft plant does not plan
// (the back leg; both of them before the plant foot is known and once the plan is over): where the game's knee is less
// than 18 cm off its own hip-ankle line, or shows under 60 % of the bend the leg at its own length needs, the knee's way
// is turned from the pose's toward the way that knee was DRAWN on the pose before (kept in the pelvis' frame) -- all the
// way under 6 cm / 25 %. Run on the recording (these functions, cut out of the source): the first trick's knee moves
// 10 cm in one pose at most where it moved 44, and meets the game's own knee within 4 deg when that comes back (0.48 s);
// in the other eight, and the eight of the session before, it is used on 8-10 poses (0.17-0.32 s): the knee within
// 4-19 cm of where it was drawn, the dip to the back gone, its biggest step in a pose 7-18 cm before and 8-17 after.
// HJN_Set("kneekeep", 0) = v95's.
extern int g_plantFoot; double NowS();
volatile int g_kneeKeep = 1; LONG g_kneeKept = 0; float g_kneeKeptLow = 99.0f;
V3 g_kneeMem[2] = { { 0, 0, 0 }, { 0, 0, 0 } }; bool g_kneeMemOk[2] = { false, false }; double g_kneeMemT[2] = { 0.0, 0.0 };
// the knee's way for leg sd, about to be solved to F (its bones already put back): false = the pose's own, as Leg() takes it
bool KneeSide(int sd, V3 F, V3& pole) {
    const int th = g_thigh[sd], ca = g_calf[sd], ft = g_foot[sd];
    if (g_kneeKeep == 0 || !g_legFix || g_plantMode == 2 || sd == g_plantFoot || g_pelvis < 0) return false;
    if (!g_kneeMemOk[sd] || NowS() - g_kneeMemT[sd] > 0.1) return false;      // nothing drawn to go by (the window has only just opened)
    const V3 hf = sub(g_C[ft].p, g_C[th].p), kv = sub(g_C[ca].p, g_C[th].p);  // the GAME's leg: its knee off its own line
    const float hl2 = dot(hf, hf), bend = len((hl2 > 1.0f) ? sub(kv, mul(hf, dot(kv, hf) / hl2)) : kv);
    const V3 S = g_Ct[th].p, dv = sub(F, S);                                  // the leg as it is about to be solved: the hip in its socket, the bones their own
    const float a1 = len(sub(g_Ct[ca].p, S)), a2 = len(sub(g_Ct[ft].p, g_Ct[ca].p)), dl = len(dv);
    if (dl < 1.0f || a1 < 1.0f || a2 < 1.0f) return false;
    const float d = fminf(dl, (a1 + a2) * 0.995f), cosA = clampf((a1 * a1 + d * d - a2 * a2) / (2.0f * a1 * d), -1.0f, 1.0f), need = a1 * sqrtf(1.0f - cosA * cosA);
    const float own = fminf(clampf((bend - 6.0f) / 12.0f, 0.0f, 1.0f), (need > 0.5f) ? clampf((bend / need - 0.25f) / 0.35f, 0.0f, 1.0f) : 1.0f);
    if (own >= 1.0f) return false;                                            // the pose says it
    const V3 al = mul(dv, 1.0f / dl);
    V3 m = qrot(g_Ct[g_pelvis].q, g_kneeMem[sd]); m = sub(m, mul(al, dot(m, al)));
    if (len(m) < 0.2f) return false;
    m = norm(m);
    V3 o = sub(g_Ct[ca].p, add(S, mul(sub(g_Ct[ft].p, S), 0.5f)));            // (what Leg() takes by itself)
    o = sub(o, mul(al, dot(o, al)));
    float ang = 0.0f;                                                         // from the kept way round the leg to the pose's own, by the share the pose can be trusted
    if (len(o) > 1e-3f) { o = norm(o); ang = atan2f(dot(cross(m, o), al), dot(m, o)) * own; }
    pole = add(mul(m, cosf(ang)), mul(cross(al, m), sinf(ang)));
    InterlockedIncrement(&g_kneeKept);
    { const float sh = len(sub(g_C[ft].p, g_C[ca].p)); if (sh < g_kneeKeptLow) g_kneeKeptLow = sh; }
    return true;
}
void KneeNote(int sd) {                                   // ...and the way it was drawn, for the pose after
    const int th = g_thigh[sd], ca = g_calf[sd], ft = g_foot[sd];
    if (g_pelvis < 0) return;
    const double now = NowS();
    if (now - g_kneeMemT[sd] > 0.1) g_kneeMemOk[sd] = false;                  // (another window: nothing of the last one's)
    g_kneeMemT[sd] = now;
    const V3 hf = sub(g_Ct[ft].p, g_Ct[th].p), kv = sub(g_Ct[ca].p, g_Ct[th].p);
    const float hl2 = dot(hf, hf);
    const V3 kp = (hl2 > 1.0f) ? sub(kv, mul(hf, dot(kv, hf) / hl2)) : kv;
    if (len(kp) > 4.0f) { g_kneeMem[sd] = qinv(g_Ct[g_pelvis].q, norm(kp)); g_kneeMemOk[sd] = true; }
}
bool LegOwnLength() {
    if (g_riding && !g_noLearn && !g_legFix && g_legFixW < 0.02f && g_pelvis >= 0)
        for (int sd = 0; sd < 2; sd++) {
            const int th = g_thigh[sd];
            if (th < 0 || g_parent[th] != g_pelvis) continue;
            const V3 p = g_Lt[th].p;
            if (len(p) < 4.0f || len(p) > 14.0f) continue;
            if (g_hipRefN[sd] < 30) {
                if (g_hipRefN[sd] > 0 && len(sub(p, g_hipRef[sd])) > 1.5f) { g_hipRefN[sd] = 0; g_hipRef[sd] = v3(0.0f, 0.0f, 0.0f); }   // (review) the first 30 have to agree with each other: started over
                g_hipRef[sd] = lerp(g_hipRef[sd], p, 1.0f / (float)(g_hipRefN[sd] + 1)); g_hipRefN[sd]++;
            }
            else if (len(sub(p, g_hipRef[sd])) < 3.0f) { g_hipRef[sd] = lerp(g_hipRef[sd], p, 0.01f); g_hipRefMiss[sd] = 0; }
            else if (++g_hipRefMiss[sd] > 120) { g_hipRefN[sd] = 0; g_hipRefMiss[sd] = 0; g_hipRef[sd] = v3(0.0f, 0.0f, 0.0f); }   // two seconds of riding that never agree with it (another skater, a bad start): learned afresh
        }
    g_legFixW += ((g_legFix ? 1.0f : 0.0f) - g_legFixW) * 0.25f;
    g_hipFixW += (((g_hipFix && g_legFix) ? 1.0f : 0.0f) - g_hipFixW) * 0.25f;
    g_hipGap[0] = g_hipGap[1] = 0.0f;
    // (v96) A MIRRORED POSE IS READ OFF BOTH HIP JOINTS, NOT OFF ONE. A joint was left where the game had dragged it when it
    // lay on the other side of the pelvis bone from where it rides ("the other way round = a mirrored pose"). With a hand on
    // the board the game drags BOTH thigh bones 20-22 cm the same way out of the pelvis, 9-13 cm of that along the line from
    // one socket to the other (the recording of 5 Oct 00:08, the bean plant: in the pelvis's own frame L 17.6 -4.0 +18.3,
    // R 17.5 -4.8 +0.9, where they ride at 0 0 +8.8 and 0 0 -8.6): the right one crossed that plane, was taken for a mirrored
    // pose and stayed out for the 8 poses the plant foot stood (3 in the boneless) -- 18 cm from the pelvis bone for 8.7, out
    // with a 21 cm step and back with another ('R knee jumps 13.4 cm at #87'), its leg 5-14 cm shorter than from its socket.
    // Dragged alike, the two joints keep their 17 cm apart: a pose is mirrored when THAT line lies the other way.
    const bool hipPair = g_pelvis >= 0 && g_thigh[0] >= 0 && g_thigh[1] >= 0 && g_parent[g_thigh[0]] == g_pelvis && g_parent[g_thigh[1]] == g_pelvis
        && g_hipRefN[0] >= 30 && g_hipRefN[1] >= 30;
    const float hipWay = hipPair ? dot(sub(g_Lt[g_thigh[0]].p, g_Lt[g_thigh[1]].p), sub(g_hipRef[0], g_hipRef[1])) : 0.0f;   // (taken before either joint is put back)
    if (!g_legFix && g_legFixW < 0.02f) { g_legFixW = 0.0f; g_hipFixW = 0.0f; return false; }
    if (!g_legRefOk) return false;
    bool changed = false;
    for (int sd = 0; sd < 2; sd++) {
        const int th = g_thigh[sd], ca = g_calf[sd], ft = g_foot[sd];
        if (th < 0 || ca < 0 || ft < 0 || g_legRef[sd][0] < 1.0f || g_legRef[sd][1] < 1.0f) continue;
        const int bone[2] = { ca, ft }; bool fix = false; float off = 0.0f;
        const V3 F = g_Ct[ft].p; const Q4 fq = g_Ct[ft].q;
        if (g_hipFixW > 0.02f && g_hipRefN[sd] >= 30 && g_pelvis >= 0 && g_parent[th] == g_pelvis) {   // (v94) the hip joint back in its socket
            const V3 cur = g_Lt[th].p; const float gap = len(sub(cur, g_hipRef[sd]));
            g_hipGap[sd] = gap;
            if (gap > 1.0f && gap < 40.0f && (hipPair ? hipWay > 0.0f : dot(cur, g_hipRef[sd]) > 0.0f)) {      // (the other way round = a mirrored pose: left alone)
                g_Lt[th].p = lerp(cur, g_hipRef[sd], g_hipFixW);
                CompOf(th, g_Lt, g_Ct);
                if (gap > g_hipGapMost) g_hipGapMost = gap;
                fix = true;
            }
        }
        for (int j = 0; j < 2; j++) {
            const float cur = len(g_Lt[bone[j]].p), ref = g_legRef[sd][j];
            if (cur > 1.0f && fabsf(cur - ref) > 0.3f) { g_Lt[bone[j]].p = mul(g_Lt[bone[j]].p, (cur + (ref - cur) * g_legFixW) / cur); off += fabsf(cur - ref); fix = true; }
        }
        if (!fix) continue;
        RebuildSub(th);
        { V3 kw; const bool kept = KneeSide(sd, F, kw); Leg(sd, F, fq, v3(0.0f, 0.0f, 0.0f), kept ? &kw : nullptr); KneeNote(sd); }   // (v96) the knee's way: the pose's, as far as the pose says it
        if (off > g_legFixMost) g_legFixMost = off;
        InterlockedIncrement(&g_legFixed);
        changed = true;
    }
    return changed;
}
bool HopHips(bool want) {                                        // (v99) the note at g_hopHipOn
    g_hopHipW += ((want ? 1.0f : 0.0f) - g_hopHipW) * 0.34f;
    if (!want && g_hopHipW < 0.02f) {
        if (g_hopHipWas && g_hopHipMost > 2.0f && InterlockedIncrement(&g_hopHipLogs) <= 120)
            Log("hop: the hip joints were put back in their sockets on %ld poses (the game had them up to %.1f cm out)", (long)g_hopHipped, g_hopHipMost);
        g_hopHipW = 0.0f; g_hopHipWas = false; g_hopHipped = 0; g_hopHipMost = 0.0f;
        return false;
    }
    g_hopHipWas = true;
    if (g_hipFixW > 0.02f || g_pelvis < 0 || g_thigh[0] < 0 || g_thigh[1] < 0) return false;   // (a plant's window does it itself: LegOwnLength)
    if (g_parent[g_thigh[0]] != g_pelvis || g_parent[g_thigh[1]] != g_pelvis || g_hipRefN[0] < 30 || g_hipRefN[1] < 30) return false;
    if (dot(sub(g_Lt[g_thigh[0]].p, g_Lt[g_thigh[1]].p), sub(g_hipRef[0], g_hipRef[1])) <= 0.0f) return false;   // the two joints the other way round: a mirrored pose, left alone
    bool changed = false;
    for (int sd = 0; sd < 2; sd++) {
        const int th = g_thigh[sd], ca = g_calf[sd], ft = g_foot[sd];
        if (ca < 0 || ft < 0) continue;
        const V3 cur = g_Lt[th].p; const float gap = len(sub(cur, g_hipRef[sd]));
        if (!(gap > 1.0f && gap < 40.0f)) continue;
        const V3 F = g_Ct[ft].p; const Q4 fq = g_Ct[ft].q;
        const float reach = (len(sub(g_Ct[ca].p, g_Ct[th].p)) + len(sub(F, g_Ct[ca].p))) * 0.985f;
        if (!finite3(F) || reach < 20.0f) continue;
        float f = g_hopHipW; bool ok = false;
        for (int i = 0; i < 7 && f > 0.03f; i++, f *= 0.7f) {    // as far back as the leg still reaches its ankle
            g_Lt[th].p = lerp(cur, g_hipRef[sd], f);
            CompOf(th, g_Lt, g_Ct);
            if (len(sub(F, g_Ct[th].p)) <= reach) { ok = true; break; }
        }
        if (!ok) { g_Lt[th].p = cur; CompOf(th, g_Lt, g_Ct); continue; }
        RebuildSub(th);
        Leg(sd, F, fq);
        if (gap > g_hopHipMost) g_hopHipMost = gap;
        changed = true;
    }
    if (changed) InterlockedIncrement(&g_hopHipped);
    return changed;
}

// THE TWEAK. Real grabs pull the board up to the hand: the nose comes up for a nose grab, the toe edge
// for an indy. The skeleton's board (the Flipper bone and everything on it: anchors, trucks, wheels) is
// turned about its own centre by part of the rotation that points the grabbed anchor at the hand -- only
// its SWING (no spinning the deck about its own normal), a TweakShare of it, at most TweakMax degrees,
// eased by the game's grab weight -- then drawn toward the grabbing shoulder by the pull (integrated from
// the hand's leftover gap, at most PullMax cm). In the air the game pulls the drawn board toward this
// bone, so the drawn board follows a frame later. The feet: each stands on the DRAWN deck's foot socket
// (plus the foot-to-socket offset learned while riding) when Feet is on and that is near, else it is
// carried along with the skeleton board.
float Tweak(int sd, float w, const void* anim) {
    const int fl = g_flipper, an = g_handAnchor[sd];
    const V3 C = g_Ct[fl].p;
    V3 footP[2]; Q4 footQ[2];
    for (int k = 0; k < 2; k++) { footP[k] = g_Ct[g_foot[k]].p; footQ[k] = g_Ct[g_foot[k]].q; }
    Q4 R = q4(0, 0, 0, 1);
    float ang = 0.0f;
    const V3 toAnchor = sub(g_Ct[an].p, C), toHand = sub(g_Ct[g_hand[sd]].p, C);
    if (len(toAnchor) > 1.0f && len(toHand) > 1.0f) {
        const V3 deckUp = qrot(g_Ct[fl].q, g_upL);
        const Q4 swing = qswing(qfromto(toAnchor, toHand), deckUp);
        const float full = qangle(swing);
        if (full > 0.5f) {
            ang = fminf(full * clampf(g_tweakShare, 0.0f, 1.0f), fmaxf(g_tweakMax, 0.0f)) * w;
            if (ang >= 0.1f) { R = qscale(swing, ang / full); TurnComp(fl, R); }
            else ang = 0.0f;
        }
    }
    V3 pullV = v3(0, 0, 0);
    g_lastPull = 0.0f;
    if (g_pullMax > 0.0f && g_pullState > 0.1f) {
        const V3 dir = norm(sub(g_Ct[g_uarm[sd]].p, g_Ct[an].p));
        g_lastPull = fminf(g_pullState, g_pullMax) * w;
        pullV = mul(dir, g_lastPull);
        SetComp(fl, g_Ct[fl].q, add(g_Ct[fl].p, pullV));
    }
    if (g_legs) {
        for (int k = 0; k < 2; k++) {
            const V3 carried = add(add(C, qrot(R, sub(footP[k], C))), pullV);
            // the shift onto the drawn deck, eased and at most 12 cm (a bigger one = the deck's sockets lag)
            V3 want = v3(0, 0, 0);
            g_lastFeetDeck[k] = -1.0f;
            if (g_feet && g_footOffOk[k]) {
                const V3 s = ReadV3(anim, k ? AI_RFOOT_LOC : AI_LFOOT_LOC);
                if (finite3(s)) {
                    const V3 d = sub(add(s, g_footOff[k]), carried);
                    const float dd = len(d);
                    if (dd < 20.0f) want = dd > 12.0f ? mul(d, 12.0f / dd) : d;
                    g_lastFeetDeck[k] = dd;
                }
            }
            g_feetS[k] = lerp(g_feetS[k], want, clampf(g_ease, 0.02f, 1.0f));
            g_lastFootMiss[k] = Leg(k, add(carried, mul(g_feetS[k], w)), qmul(R, footQ[k]));
        }
    }
    return ang;
}

// ---- THE FIT (v5, TweakMode 2): the board is placed by all six degrees of freedom -- tipped, rolled,
// turned and shifted -- as the weighted best fit (Horn's closed form) of three points on it onto where the
// body wants them: its two foot anchors stay under the animated feet (weight 1 each) and the grab spot
// goes to the animated wrist (weight FitHand, 2 = the hand pulls twice as hard as each foot holds). So the
// board comes to the grab the way a real tweak does, while the feet move as little as possible (the legs
// barely re-fold). At most TweakMax degrees and FitMove cm, x the game's grab weight, eased.
Q4 g_fitQ = { 0, 0, 0, 1 };   // the eased applied rotation (about the board's centre)
V3 g_fitT = { 0, 0, 0 };      // ...and shift of the centre
bool g_fitHave = false;
float g_lastFitMiss = 0.0f;   // cm the grab spot was still short of the wrist after the fit
// the rotation (quat) that best carries the centred points a[i] onto b[i] with weights w[i] (Horn 1987)
Q4 HornQuat(const V3* a, const V3* b, const float* w, int n) {
    float S[3][3] = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } };
    for (int i = 0; i < n; i++) {
        const float A[3] = { a[i].x, a[i].y, a[i].z }, B[3] = { b[i].x, b[i].y, b[i].z };
        for (int r = 0; r < 3; r++) for (int c = 0; c < 3; c++) S[r][c] += w[i] * A[r] * B[c];
    }
    const float xx = S[0][0], xy = S[0][1], xz = S[0][2], yx = S[1][0], yy = S[1][1], yz = S[1][2],
                zx = S[2][0], zy = S[2][1], zz = S[2][2];
    const float N[4][4] = {
        { xx + yy + zz, yz - zy,       zx - xz,       xy - yx },
        { yz - zy,      xx - yy - zz,  xy + yx,       zx + xz },
        { zx - xz,      xy + yx,      -xx + yy - zz,  yz + zy },
        { xy - yx,      zx + xz,       yz + zy,      -xx - yy + zz } };
    // the eigenvector of N's largest eigenvalue, by cyclic Jacobi rotations (exact for a 4x4 symmetric
    // matrix in a few sweeps; power iteration was not -- three points often give two close eigenvalues)
    double A[4][4], V[4][4];
    for (int r = 0; r < 4; r++) for (int c = 0; c < 4; c++) { A[r][c] = N[r][c]; V[r][c] = (r == c) ? 1.0 : 0.0; }
    for (int sweep = 0; sweep < 30; sweep++) {
        double off = 0.0;
        for (int p = 0; p < 4; p++) for (int q = p + 1; q < 4; q++) off += A[p][q] * A[p][q];
        if (off < 1e-18) break;
        for (int p = 0; p < 4; p++)
            for (int q = p + 1; q < 4; q++) {
                if (fabs(A[p][q]) < 1e-30) continue;
                const double th = (A[q][q] - A[p][p]) / (2.0 * A[p][q]);
                const double t = (th >= 0.0 ? 1.0 : -1.0) / (fabs(th) + sqrt(th * th + 1.0));
                const double c = 1.0 / sqrt(t * t + 1.0), s = t * c;
                for (int k = 0; k < 4; k++) {                    // A = J^T A J
                    const double akp = A[k][p], akq = A[k][q];
                    A[k][p] = c * akp - s * akq; A[k][q] = s * akp + c * akq;
                }
                for (int k = 0; k < 4; k++) {
                    const double apk = A[p][k], aqk = A[q][k];
                    A[p][k] = c * apk - s * aqk; A[q][k] = s * apk + c * aqk;
                }
                for (int k = 0; k < 4; k++) {                    // V = V J
                    const double vkp = V[k][p], vkq = V[k][q];
                    V[k][p] = c * vkp - s * vkq; V[k][q] = s * vkp + c * vkq;
                }
            }
    }
    int best = 0;
    for (int i = 1; i < 4; i++) if (A[i][i] > A[best][best]) best = i;
    return qnorm(q4((float)V[1][best], (float)V[2][best], (float)V[3][best], (float)V[0][best]));
}
float TweakFit(int sd, float w, const void* anim, V3 tgtGame) {
    const int fl = g_flipper;
    const V3 C = g_Ct[fl].p;
    V3 footP[2]; Q4 footQ[2];
    for (int k = 0; k < 2; k++) { footP[k] = g_Ct[g_foot[k]].p; footQ[k] = g_Ct[g_foot[k]].q; }
    // the grab spot on this frame's (untweaked) skeleton board: the game's target sits on the drawn deck,
    // which already carries last frame's fit -- undo that (moved = C + T + R(p - C))
    V3 grabP = tgtGame;
    if (g_fitHave) grabP = add(C, qinv(g_fitQ, sub(sub(tgtGame, g_fitT), C)));
    const V3 deckUp = qrot(g_Ct[fl].q, g_upL);
    const V3 grabQ = sub(g_Ct[g_hand[sd]].p, mul(deckUp, g_handUp));      // just under the animated wrist
    const V3 P[3] = { g_Ct[g_footAnchor[0]].p, g_Ct[g_footAnchor[1]].p, grabP };
    const V3 Q[3] = { P[0], P[1], grabQ };
    const float W[3] = { 1.0f, 1.0f, fmaxf(g_fitHand, 0.0f) };
    const float ws = W[0] + W[1] + W[2];
    V3 pc = v3(0, 0, 0), qc = v3(0, 0, 0);
    for (int i = 0; i < 3; i++) { pc = add(pc, mul(P[i], W[i] / ws)); qc = add(qc, mul(Q[i], W[i] / ws)); }
    V3 a[3], b[3];
    for (int i = 0; i < 3; i++) { a[i] = sub(P[i], pc); b[i] = sub(Q[i], qc); }
    Q4 R = HornQuat(a, b, W, 3);
    const float full = qangle(R);
    if (full > g_tweakMax && full > 1e-3f) R = qscale(R, fmaxf(g_tweakMax, 0.0f) / full);
    V3 D = sub(add(qc, qrot(R, sub(C, pc))), C);                          // where the centre goes
    const float dl = len(D);
    if (dl > g_fitMove) D = mul(D, fmaxf(g_fitMove, 0.0f) / fmaxf(dl, 1e-3f));
    // x the grab weight, eased toward it
    const float e = clampf(g_ease, 0.02f, 1.0f);
    const Q4 Rw = qscale(R, clampf(w, 0.0f, 1.0f));
    if (!g_fitHave) { g_fitQ = q4(0, 0, 0, 1); g_fitT = v3(0, 0, 0); }
    Q4 step = qmul(Rw, qconj(g_fitQ));
    if (step.w < 0.0f) step = q4(-step.x, -step.y, -step.z, -step.w);
    g_fitQ = qnorm(qmul(qscale(step, e), g_fitQ));
    g_fitT = lerp(g_fitT, mul(D, clampf(w, 0.0f, 1.0f)), e);
    g_fitHave = true;
    TurnComp(fl, g_fitQ);
    SetComp(fl, g_Ct[fl].q, add(C, g_fitT));
    g_lastFitMiss = len(sub(add(add(C, g_fitT), qrot(g_fitQ, sub(grabP, C))), grabQ));
    g_lastPull = len(g_fitT);
    if (g_legs) {
        for (int k = 0; k < 2; k++) {
            const V3 carried = add(add(C, g_fitT), qrot(g_fitQ, sub(footP[k], C)));
            V3 want = v3(0, 0, 0);
            g_lastFeetDeck[k] = -1.0f;
            if (g_feet && g_footOffOk[k]) {
                const V3 s = ReadV3(anim, k ? AI_RFOOT_LOC : AI_LFOOT_LOC);
                if (finite3(s)) {
                    const V3 d = sub(add(s, g_footOff[k]), carried);
                    const float dd = len(d);
                    if (dd < 20.0f) want = dd > 12.0f ? mul(d, 12.0f / dd) : d;
                    g_lastFeetDeck[k] = dd;
                }
            }
            g_feetS[k] = lerp(g_feetS[k], want, e);
            g_lastFootMiss[k] = Leg(k, add(carried, mul(g_feetS[k], w)), qmul(g_fitQ, footQ[k]));
        }
    }
    return qangle(g_fitQ);
}

// THE LEAN. When the grab target is beyond the arm from the shoulder, the spine (the pelvis's child, so
// the whole upper body) bends toward it -- the least that brings the shoulder within 97% of the arm, at
// most LeanMax degrees, eased by the grab weight. Returns the degrees bent.
float g_ms = 1.0f;                             // the skater mesh's scale (for the log; set in DeckXf)
float g_leanScale = 1.0f;                      // this grab's lean multiplier (v22: Melon/Indy tuck)
float g_closeS = 0.0f, g_lastClose = 0.0f; volatile float g_closeMax = 16.0f;   // (v84) the hips toward the hand, cm
float g_foldExtra = 0.0f; volatile float g_closeMax2 = 12.0f, g_foldExtraMax = 30.0f;   // (v85) two hands: the hips, then the back past the grab's own Fold
int g_audCnt[2] = { 0, 0 }; float g_audSum[2] = { 0, 0 }, g_audMax[2] = { 0, 0 }, g_audLean = 0.0f, g_audClose = 0.0f, g_audFold = 0.0f; LONG g_audTold = 0;   // (v85)
float g_boundsR = 0.0f; V3 g_boundsOff = { 0, 0, 0 }; V3 g_boundsExt = { 0, 0, 0 };   // (v23) the deck component's bounds, set in DeckXf
// (v35) the same for a two-hand grab: the spine bends the shoulders' middle toward the two spots' middle, the least
// that lets BOTH arms reach
float LeanTwo(const V3* tgt, const float* wh) {
    if (g_spine1 < 0 || g_leanMax <= 0.0f) { g_leanS = 0.0f; return 0.0f; }
    const V3 P = g_Ct[g_spine1].p, S0 = g_Ct[g_uarm[0]].p, S1 = g_Ct[g_uarm[1]].p;
    const float r0 = armLen(0) * 0.97f, r1 = armLen(1) * 0.97f;
    const Q4 full = qfromto(sub(mul(add(S0, S1), 0.5f), P), sub(mul(add(tgt[0], tgt[1]), 0.5f), P));
    const float fullAng = qangle(full);
    auto over = [&](float t) {
        const Q4 q = qscale(full, t);
        return fmaxf(len(sub(tgt[0], add(P, qrot(q, sub(S0, P))))) - r0, len(sub(tgt[1], add(P, qrot(q, sub(S1, P))))) - r1);
    };
    float wantAng = 0.0f;
    if (fullAng >= 0.5f && over(0.0f) > 0.0f) {
        // (two hands far apart, a Cannonball's nose and tail, need the chest well down over the knees: 1.6 x the one-hand limit)
        float hi = fminf(1.0f, g_leanMax * g_leanScale * 1.6f / fullAng), lo = 0.0f;
        if (over(hi) <= 0.0f)
            for (int i = 0; i < 10; i++) { const float m = 0.5f * (lo + hi); if (over(m) > 0.0f) lo = m; else hi = m; }
        wantAng = hi * fullAng * clampf(fmaxf(wh[0], wh[1]), 0.0f, 1.0f);
    }
    g_leanS += (wantAng - g_leanS) * clampf(g_ease, 0.02f, 1.0f);
    if (g_leanS < 0.1f || fullAng < 0.5f) return 0.0f;
    TurnComp(g_spine1, qscale(full, fminf(g_leanS / fullAng, 1.0f)));
    return g_leanS;
}
float Lean(int sd, V3 tgt, float w) {
    if (g_spine1 < 0 || g_leanMax <= 0.0f) { g_leanS = 0.0f; return 0.0f; }
    const V3 S = g_Ct[g_uarm[sd]].p, P = g_Ct[g_spine1].p;
    const float reach = armLen(sd) * 0.97f;
    const Q4 full = qfromto(sub(S, P), sub(tgt, P));
    const float fullAng = qangle(full);
    float wantAng = 0.0f;
    if (len(sub(tgt, S)) > reach && fullAng >= 0.5f) {
        auto distAt = [&](float t) { return len(sub(tgt, add(P, qrot(qscale(full, t), sub(S, P))))); };
        float hi = fminf(1.0f, g_leanMax * g_leanScale / fullAng), lo = 0.0f;   // (v22) Melon/Indy may lean further
        if (distAt(hi) <= reach)
            for (int i = 0; i < 10; i++) { const float m = 0.5f * (lo + hi); if (distAt(m) > reach) lo = m; else hi = m; }
        wantAng = hi * fullAng * clampf(w, 0.0f, 1.0f);
    }
    // eased: the lean grows and shrinks over a few frames instead of jumping to what this frame wants
    g_leanS += (wantAng - g_leanS) * clampf(g_ease, 0.02f, 1.0f);
    if (g_leanS < 0.1f || fullAng < 0.5f) return 0.0f;
    TurnComp(g_spine1, qscale(full, fminf(g_leanS / fullAng, 1.0f)));
    return g_leanS;
}

// closest points between segments p1-q1 and p2-q2; returns the distance, c1/c2 the points
float SegSeg(V3 p1, V3 q1, V3 p2, V3 q2, V3& c1, V3& c2) {
    const V3 d1 = sub(q1, p1), d2 = sub(q2, p2), r = sub(p1, p2);
    const float a = dot(d1, d1), e = dot(d2, d2), f = dot(d2, r);
    float s = 0.0f, t = 0.0f;
    if (a < 1e-6f && e < 1e-6f) { c1 = p1; c2 = p2; return len(sub(c1, c2)); }
    if (a < 1e-6f) t = clampf(f / e, 0.0f, 1.0f);
    else {
        const float c = dot(d1, r);
        if (e < 1e-6f) s = clampf(-c / a, 0.0f, 1.0f);
        else {
            const float b = dot(d1, d2), den = a * e - b * b;
            s = den > 1e-6f ? clampf((b * f - c * e) / den, 0.0f, 1.0f) : 0.0f;
            t = (b * s + f) / e;
            if (t < 0.0f) { t = 0.0f; s = clampf(-c / a, 0.0f, 1.0f); }
            else if (t > 1.0f) { t = 1.0f; s = clampf((b - c) / a, 0.0f, 1.0f); }
        }
    }
    c1 = add(p1, mul(d1, s)); c2 = add(p2, mul(d2, t));
    return len(sub(c1, c2));
}

// THE KNEE AWAY. A grabbing arm (upper arm or forearm) that passes within 11 cm of a thigh or shin
// swings that knee away from it (the leg re-solved to the same foot with the knee's pole biased away).
// v4: the push is eased per leg (it grows while the arm is close, fades once clear) and gentler (at most 1).
void KneeAway(const float* wh) {
    const float R = 9.0f;
    for (int k = 0; k < 2; k++) {
        V3 want = v3(0, 0, 0);
        for (int s = 0; s < 2; s++) {
            if (wh[s] <= 0.001f) continue;
            const V3 A[3] = { g_Ct[g_uarm[s]].p, g_Ct[g_larm[s]].p, g_Ct[g_hand[s]].p };
            const V3 L[3] = { g_Ct[g_thigh[k]].p, g_Ct[g_calf[k]].p, g_Ct[g_foot[k]].p };
            float best = 1e9f; V3 ba{}, bl{};
            for (int i = 0; i < 2; i++)
                for (int j = 0; j < 2; j++) {
                    V3 ca, cl;
                    const float d = SegSeg(A[i], A[i + 1], L[j], L[j + 1], ca, cl);
                    if (d < best) { best = d; ba = ca; bl = cl; }
                }
            if (best >= R) continue;
            V3 away = sub(bl, ba);
            if (len(away) < 0.5f) away = flat(sub(L[1], g_Ct[g_pelvis >= 0 ? g_pelvis : g_thigh[k]].p));
            want = add(want, mul(norm(away), clampf((R - best) / R * 1.5f, 0.1f, 0.6f) * wh[s]));
            InterlockedIncrement(&g_kneeHits);
        }
        g_kneeS[k] = lerp(g_kneeS[k], want, clampf(g_ease, 0.02f, 1.0f));
        if (len(g_kneeS[k]) > 0.02f) Leg(k, g_Ct[g_foot[k]].p, g_Ct[g_foot[k]].q, g_kneeS[k]);
    }
}

// THE GUARD (180 landings). Two checks on lines across the body, in the ground plane:
//  - hips vs shoulders more than 120 deg apart = the lower body is facing the other way from the upper
//    body: the pelvis (and so the legs) is turned 180 about the vertical and the spine put back exactly;
//  - feet vs hips more than 120 deg apart = crossed legs: each foot goes where the other one is, turned 180.
// Both only ever fire on a twisted pose. Returns true if the pose changed.
bool Guard() {
    if (!g_boardOk || g_pelvis < 0 || g_spine1 < 0) return false;
    bool changed = false;
    const Q4 R180 = qaxis(kUp, 180.0f);
    const V3 hips = sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p);
    const V3 shoulders = sub(g_Ct[g_uarm[0]].p, g_Ct[g_uarm[1]].p);
    g_trGuardHips = g_trGuardFeet = false;
    if (flatAngle(hips, shoulders) > 120.0f) {
        const Q4 sq = g_Ct[g_spine1].q; const V3 sp = g_Ct[g_spine1].p;
        TurnComp(g_pelvis, R180);
        SetComp(g_spine1, sq, sp);
        InterlockedIncrement(&g_guardHips);
        g_trGuardHips = changed = true;
    }
    const V3 hips2 = sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p);
    const V3 feet = sub(g_Ct[g_foot[0]].p, g_Ct[g_foot[1]].p);
    if (flatAngle(feet, hips2) > 100.0f) {
        const V3 pL = g_Ct[g_foot[0]].p, pR = g_Ct[g_foot[1]].p;
        const Q4 qL = g_Ct[g_foot[0]].q, qR = g_Ct[g_foot[1]].q;
        Leg(0, pR, qmul(R180, qR));
        Leg(1, pL, qmul(R180, qL));
        InterlockedIncrement(&g_guardFeet);
        g_trGuardFeet = changed = true;
    }
    return changed;
}

float MeshYaw(const void* mesh) {
    const float* q = (const float*)((const uint8_t*)mesh + SC_C2W);
    return atan2f(2.0f * (q[3] * q[2] + q[0] * q[1]), 1.0f - 2.0f * (q[1] * q[1] + q[2] * q[2])) * 57.2957795f;
}
// (v95) no loop: the two 'while's this was never ended for an infinite number, or one too large for 360 to change it
// (1e10 - 360 == 1e10 in a float) -- on the game thread that is a freeze with no message.
float wrap180(float a) { if (!std::isfinite(a)) return 0.0f; if (a > 180.0f || a < -180.0f) a -= 360.0f * floorf(a / 360.0f + 0.5f); return a; }

// ==== (v95) IS THE SKATER'S WORLD STILL THERE? =========================================================================
// "I am getting freezing on map changes. No crash or error message." NOT PROVEN TO BE THIS (review of 4 Oct: the one
// v94 session ended on foot in the pause menu, where the recorder does not run; a blocking LoadMap has no poses to run a
// ray on; the v93 session of 21:53 also went quiet 20 s after a map change) -- the watchdog further down is what will
// say where the game thread stands when it happens again. What this closes all the same: v94's pose recorder casts a ray
// for the ground on every pose it records, in the world AActor::GetWorld() gives for the skater the Lua last handed over,
// and the Lua only notices a level change on its 2 s tick (the plant's, the trick trace's and GroundFeet's rays did the
// same inside a trick). Now the world comes from the MESH the engine is finalizing right now (UActorComponent::WorldPrivate, there only
// while the component is registered), and nothing of the mod's runs on a pose whose mesh is unregistered, whose owner is
// being destroyed, or whose world has begun tearing down (UWorld::bIsTearingDown, the first thing UEngine::LoadMap sets).
// The offsets are read off this exe: UActorComponent::OnUnregister clears [+0x88] bit 0, ::GetWorld returns [+0xa8],
// ::GetWorld_Uncached reads the owner at [+0xa0]; AActor::IsPendingKillPending tests [+0x5c] & 0x10;
// UWorld::BeginTearingDown sets [+0x10d] |= 0x20.
constexpr int AC_REGISTERED = 0x88, AC_OWNER = 0xa0, AC_WORLD = 0xa8, ACTOR_DESTROYING = 0x5c, WORLD_TEARING = 0x10d;
constexpr uint32_t RF_DESTROYING = 0x00008000u | 0x00010000u;   // RF_BeginDestroyed | RF_FinishDestroyed (UObject::ObjectFlags, +0x8)
bool PtrOk(const void* p, size_t need);                         // (defined with Ray())
bool g_inPose = false; const void* g_poseWorld = nullptr;       // the hook is in PosePass for a pose whose mesh passed | that pose's world
volatile LONG g_gonePoses = 0; LONG g_goneLogs = 0;
const void* PoseWorld(const void* mesh, int* why = nullptr) {
    const uint8_t* m = (const uint8_t*)mesh; int w0 = 0; const void* out = nullptr;
    if (!m || !(m[AC_REGISTERED] & 1)) w0 = 1;
    else {
        const uint8_t* own = *(const uint8_t* const*)(m + AC_OWNER);
        const uint8_t* w = *(const uint8_t* const*)(m + AC_WORLD);
        if (!own || !w || !PtrOk(own, 0x60) || !PtrOk(w, 0x110)) w0 = 2;
        else if ((own[ACTOR_DESTROYING] & 0x10) || (*(const uint32_t*)(own + 8) & RF_DESTROYING)) w0 = 3;
        else if ((w[WORLD_TEARING] & 0x20) || (*(const uint32_t*)(w + 8) & RF_DESTROYING)) w0 = 4;
        else out = w;
    }
    if (why) *why = w0;
    return out;
}

// THE HOLD (180 landings). When the revert completes, the skater actor (and so the mesh) turns with the
// board and the Lua body hold only catches up a frame later -- the v70 trace showed the mesh's world
// heading jump ~45 deg and ease back over ~10 frames. Here, in the finished pose, the body's WORLD
// heading (mesh world yaw + the shoulder line's yaw in the pose) is held at what it was on the first pose
// of the window: the pelvis (so everything above and the legs) is turned by the difference and the feet
// are put back where they were. The last 15 poses fade the correction out.
// ==== (v94) THE HOLD, ON SPRINGS ======================================================================================
// "It just seems like the warp is a compensation -- it's accommodating some sort of discrepancy. We can't solve the problem
// if we don't know what the problem is." What the traces of 4 Oct say about the BODY's heading at a landing:
//  1. THE LAG. After the deck-stays-put swap the game turns the actor a quarter of what is left per frame (45, 34, 25, 19,
//     14, 11, 8 ... deg) AFTER the Lua has run, so the mesh's world heading is off by exactly that frame's step on every
//     pose: +45 on landing pose 2, x0.75 a pose from there (the same row in all fourteen 180s of 19:57-20:34).
//  2. THE GAME ALREADY HOLDS THE HIPS. Its rig smooths the pelvis in the WORLD (the PowerIK pelvis effector): the hips' line
//     of the game's own pose counter-turns about half of the lag on pose 2 and 0.85 of it from pose 3 (the +180 and the
//     -180 landings mirror each other: 75635 against 75918 in the native log). The shoulders do not. So the v5 hold's half
//     share for the hips over-turned them 5-9 deg on poses 3-5, and its 12 % bleed took the shoulders' correction away
//     faster than the lag itself decays: +6, +8, +11, +12, +12, +12, +11 ... deg left on them for a third of a second.
//  3. THE POSE'S OWN STEP. The air pose and the landing pose stand differently on the mesh, and the game goes from one to
//     the other in one to three poses: the shoulders 33 -> 7 deg (-26 in ONE pose, 20:34:34), -67 -> -31 (+36, 19:57:33);
//     the hips +28..+40 deg inside two. And not only after a turn: riding REGULAR a straight hop's hips swing 35 deg in
//     four poses at touchdown (19:57:46: -176, -171, -158, -146, -142), the feet already held on the deck; riding switch
//     the game's own pre-landing blend spreads the same change over eight poses of the air (3 deg a pose).
// Now the two lines across the body -- hips, shoulders -- each have a heading in the WORLD that follows the pose's through
// a critically damped spring (g_holdOmega 22 /s: two thirds of a step in a tenth of a second, no overshoot), carried in
// from the last pose of the air with the speed it had there. The hips' spring follows the game's own hips (which the game
// holds in the world itself: only pose 2's 20 deg spike is left for the spring to round off); the shoulders' follows the
// game's shoulders with the mesh's lag taken out exactly (this pose's mesh heading against the first pose's) for the first
// 'lag' poses' time of the landing, let go over the next 0.13 s. HJN_Hold(n, lag): lag 0 = nothing to take out (a straight
// landing: the springs only); no second number = the v5 hold below, unchanged.
double NowS();
float Sm01(float x) { x = clampf(x, 0.0f, 1.0f); return x * x * (3.0f - 2.0f * x); }
volatile int   g_holdLag = -1;        // HJN_Hold's second number; -1 = the v5 hold
volatile float g_holdOmega = 22.0f;   // 1/s
volatile int   g_holdPlace = 1;       // (v95) HJN_Set("holdplace", 0/1): the hips' PLACE and the game's feet have the mesh's lag taken out too
float g_holdTake = 0.0f; LONG g_holdPlaced = 0;
float FootA(const void* anim, int k);   // (defined with the drawn deck, further down)
int    g_holdPose = 0;
float  g_holdY[2] = { 0, 0 }, g_holdV[2] = { 0, 0 }, g_holdC[2] = { 0, 0 }, g_holdErr = 0.0f;   // [0] hips [1] shoulders: world heading, its speed (deg/s), the turn given this pose; the mesh's lag
float  g_airWy[2] = { 0, 0 }, g_airWv[2] = { 0, 0 }; double g_airWt = 0.0, g_holdT = 0.0, g_holdT0 = 0.0; bool g_airWok = false;   // the same two lines on the last pose of the air (AirSave)
bool Hold(const void* mesh) {
    if (g_pelvis < 0 || g_spine1 < 0 || !g_boardOk) return false;
    if (g_holdLag >= 0 && g_thigh[0] >= 0 && g_thigh[1] >= 0 && g_uarm[0] >= 0 && g_uarm[1] >= 0 && g_foot[0] >= 0 && g_foot[1] >= 0) {
        const float mwN = MeshYaw(mesh);
        const float line[2] = { yawOf(sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p)), yawOf(sub(g_Ct[g_uarm[0]].p, g_Ct[g_uarm[1]].p)) };
        const double tN = NowS();
        if (!g_holdHave) {
            g_holdHave = true; g_holdWant = mwN; g_holdPose = 0; g_lastHold = 0.0f; g_holdT0 = tN;
            const bool seed = g_airWok && tN > g_airWt && (tN - g_airWt) < 0.08;
            for (int i = 0; i < 2; i++) {
                g_holdY[i] = seed ? g_airWy[i] : mwN + line[i];
                g_holdV[i] = seed ? clampf(g_airWv[i], -500.0f, 500.0f) : 0.0f;
            }
            g_holdT = seed ? g_airWt : tN;
        }
        g_holdPose++;
        const float dt = clampf((float)(tN - g_holdT), 0.0f, 0.05f); g_holdT = tN;
        const float lagW = (g_holdLag > 0) ? 1.0f - Sm01(((float)(tN - g_holdT0) - (float)g_holdLag * 0.016f) / 0.13f) : 0.0f;
        const float lag = wrap180(mwN - g_holdWant);
        const float tgt[2] = { mwN + line[0], mwN + line[1] - lag * lagW };
        const float om = clampf(g_holdOmega, 4.0f, 80.0f), ex = expf(-om * dt);
        float x[2];
        for (int i = 0; i < 2; i++) {
            x[i] = wrap180(g_holdY[i] - tgt[i]);
            const float tmp = (g_holdV[i] + om * x[i]) * dt;
            g_holdV[i] = (g_holdV[i] - om * tmp) * ex;
            x[i] = (x[i] + tmp) * ex;
            g_holdY[i] = tgt[i] + x[i];
        }
        const float fade = clampf((float)g_holdFrames / 15.0f, 0.0f, 1.0f);
        const float cH = clampf(x[0], -90.0f, 90.0f) * fade, cS = clampf(x[1] - lag * lagW, -120.0f, 120.0f) * fade;
        g_holdErr = lag; g_holdC[0] = cH; g_holdC[1] = cS; g_lastHold = cS;
        // (v95) ...AND THE HIPS' PLACE. "Still mad mesh tearing on the 180 hippies." The first two recordings of a 180's
        // landing (4 Oct 22:53:51 mini, 22:52 crouched), every joint in the world: the feet stand still on the deck, the
        // hips' and shoulders' HEADINGS are held by the springs above -- and the hips themselves swing 20-25 cm sideways in
        // ONE pose and creep back over eight. They stand 22-27 cm from the mesh's own origin, and the mesh's heading is off
        // by the lag (45, 34, 25, 19 ... deg): their bearing from the origin goes 81 -> 128 -> 118 -> 111 -> 106 deg (mini),
        // 2 -> 40 -> 25 -> 13 (crouched). With the lag taken out of the bearing it reads 81, 83, 85, 86, 88 and 2, -5, -9,
        // -12: one smooth move. So the hips' place (and with it everything on them) and the game's own feet -- the landing
        // blend's targets -- are turned back about the mesh's origin by the lag, for as long as the lag is taken out of the
        // shoulders' heading. Nothing new is aimed at: it is the pose the game made, stood where the game meant it.
        float take = (g_holdPlace != 0) ? clampf(lag * lagW, -90.0f, 90.0f) * fade : 0.0f;
        { const float* sc = (const float*)((const uint8_t*)mesh + SC_C2W + 0x20); if (sc[0] * sc[1] * sc[2] < 0.0f) take = -take; }   // (a mirrored mesh turns the other way round)
        const bool place = fabsf(take) > 0.3f;
        g_holdTake = place ? take : 0.0f;
        if (fabsf(cH) < 0.2f && fabsf(cS) < 0.2f && !place) return false;
        V3 fpN[2]; Q4 fqN[2];
        for (int k = 0; k < 2; k++) { fpN[k] = g_Ct[g_foot[k]].p; fqN[k] = g_Ct[g_foot[k]].q; }
        if (place) {
            const Q4 un = qaxis(kUp, -take);
            // (review) a FOOT hangs off the lagging mesh only by what the game's foot pull has not taken back yet (the Lua
            // ramps that pull 0.1 a pose through this landing): turned back by the whole lag the game's left foot stood
            // 9.1, 8.6, 6.9, 5.3, 4.0 cm from where it ends on landing poses 3-7 of the mini 180, untouched 3.0, 0.5, 0.5;
            // by lag x (1 - pull) the blend's path is the shortest of the three and ends on the game's own feet.
            const void* an = *(void* const*)((const uint8_t*)mesh + SKM_ANIM);
            for (int k = 0; k < 2; k++) {
                float a = an ? FootA(an, k) : 0.0f; if (!std::isfinite(a)) a = 0.0f;
                const Q4 uf = qaxis(kUp, -take * (1.0f - clampf(a, 0.0f, 1.0f)));
                fpN[k] = qrot(uf, fpN[k]); fqN[k] = qnorm(qmul(uf, fqN[k]));
            }
            SetComp(g_pelvis, g_Ct[g_pelvis].q, qrot(un, g_Ct[g_pelvis].p));
            InterlockedIncrement(&g_holdPlaced);
        }
        TurnComp(g_pelvis, qaxis(kUp, cH));
        TurnComp(g_spine1, qaxis(kUp, cS - cH));
        for (int k = 0; k < 2; k++) Leg(k, fpN[k], fqN[k]);
        return true;
    }
    // v5: only the MESH's world heading is held, and only against sudden jumps: the held heading follows the
    // mesh at HoldBleed per frame, so the one-frame turn when the revert completes is cancelled and then let
    // go smoothly, while the landing animation's own turn of the body is left alone (v4 held the shoulders
    // and fought it: hips 70 deg off the feet). The upper body takes all of it, the hips half, the feet stay.
    const float mw = MeshYaw(mesh);
    if (!g_holdHave) { g_holdWant = mw; g_holdHave = true; g_lastHold = 0.0f; return false; }
    const float fade = clampf((float)g_holdFrames / 15.0f, 0.0f, 1.0f);
    const float d = clampf(wrap180(g_holdWant - mw), -120.0f, 120.0f) * fade;
    g_holdWant = mw + wrap180(g_holdWant - mw) * (1.0f - clampf(g_holdBleed, 0.0f, 1.0f));
    g_lastHold = d;
    if (fabsf(d) < 0.3f) return false;
    V3 fp[2]; Q4 fq[2];
    for (int k = 0; k < 2; k++) { fp[k] = g_Ct[g_foot[k]].p; fq[k] = g_Ct[g_foot[k]].q; }
    TurnComp(g_pelvis, qaxis(kUp, 0.5f * d));
    TurnComp(g_spine1, qaxis(kUp, 0.5f * d));
    for (int k = 0; k < 2; k++) Leg(k, fp[k], fq[k]);
    return true;
}

// ---- THE LANDING BLEND (v11). The v75 trace: in the air the feet follow the body; on the touchdown frame the
// game's foot IK snaps them onto the deck's foot sockets -- after a 180 in CROSSED order for that one frame
// (feet line -2 -> -145 deg, back next frame): the "foot tornado"; after a clean landing a 27 deg snap. Now,
// during a hop (HJN_Air each frame) the feet are remembered relative to the pelvis; for HJN_Land(n) frames
// after touchdown they blend from there onto the game's feet (smoothstep), and a frame where the game's feet
// are crossed against the remembered ones is not followed at all.
volatile int g_airFrames = 0, g_landFrames = 0, g_landTotal = 0;
V3   g_airRelP[2]; Q4 g_airRelQ[2];
bool g_airHave = false;
volatile LONG g_landCrossed = 0;
void AirSave(const void* mesh);                 // (v87) defined further down, after the drawn deck: the blend is against the BOARD now
bool LandBlend(const void* mesh);

// ================================================================== v8: THE DRAWN DECK, GRAB BY GRAB (TweakMode 3)
// The deck you SEE is where the feet and hand go; the skeleton's board bone is only the handle the game
// uses to turn it (the drawn deck follows that bone's rotation and height, not its sideways position).
// v7 read the drawn deck's foot-socket ROTATORS -- the v74 log showed them drifting 20-30 deg against the
// board in any frame (the frame test flipped back and forth): unusable, and a likely cause of spinning
// feet. v8 uses only the sockets' POSITIONS; every rotation comes from the body-attached skeleton board.
//  - BOARD, per grab (the grab state is read off the skater, +0x648):
//      Nose  (1)  : rocketed -- the nose end up NosePitch deg, no roll about the long axis
//      Tail (100), Indy (102), Melon (2): the tail end up TailPitch deg, no roll
//      others     : the v7 Horn fit (limbs pull the deck)
//    eased in (BoardEase per frame, x the grab weight); the height follows the hand
//  - FEET: each on its nearer drawn socket plus the offset it had there while riding (kept in the skeleton
//    board's frame, which stays with the body), turned with the tweak; not forced flat: the foot may roll
//    onto an EDGE of its sole pinned to the deck -- per grab: Nose: the front foot on its outer edge (as in
//    an ollie); Tail/Indy/Melon: the front foot on its inner edge, the back foot on its outer edge -- and/or
//    lift its heel over the toe joint, and the knee may swing round the hip-ankle line: whichever keeps the
//    ankle nearest the animation's angle and the knee clear of the grabbing arm
//  - ARM: the elbow's side is searched too, so the arm goes round the knees, the feet and the deck edge
//    (Indy round the back knee, Melon round the front foot) instead of through them.
constexpr int SK_GRAB = 0x648;                 // ASkaterCharacterBase grab state (EGrabState, written by SetGrab)
int   g_toe[2] = { -1, -1 };                   // AMXX_L/R_Toe0 (from Lua's chain; -1 = no heel lift)
volatile float g_fitGain = 0.08f;              // HJN_Set("fitgain")   (the v7 fit, other grabs)
volatile float g_heelMax = 40.0f;              // HJN_Set("heel", deg)
volatile int   g_legSearch = 1;                // HJN_Set("legsearch", 0/1)
volatile float g_nosePitch = 25.0f;            // HJN_Set("nosepitch", deg)
volatile float g_tailPitch = 35.0f;            // HJN_Set("tailpitch", deg)
volatile float g_boardEase = 0.12f;            // HJN_Set("boardease", 0..1 per frame)
volatile float g_edgeRoll = 1.0f;              // HJN_Set("edgeroll", 0 = feet flat .. 1 = full edge rolls)
volatile int   g_armSearch = 1;                // HJN_Set("armsearch", 0/1)
Q4    g_tq = { 0, 0, 0, 1 };                   // the tweak held on the skeleton board (rotation about its centre)
float g_tz = 0.0f;                             // ...and height
V3    g_offB[2];                               // foot bone - its drawn-deck socket, in the skeleton board's frame
// ---- v12: THE DRAWN DECK ITSELF. Research (scratchpad drawn_deck_A/B.md): the anim's foot sockets are the
// skeleton's own foot anchors (smoothed, a frame behind) -- not the visible deck; the visible deck is the
// board's "Flipper" UStaticMeshComponent, kept at board+0x4E8, and the skater mesh ticks in TG_PostPhysics, so
// its ComponentToWorld read here is THIS frame's. During a grab the game pulls that deck to (0, 0, Flipper bone Z)
// of the mesh (X/Y locked under the mesh origin) and turns it to the Flipper bone's rotation.
constexpr int BD_DECK = 0x4e8;
Q4   g_dq = { 0, 0, 0, 1 };                    // the drawn deck in component space (this pose)
V3   g_dp = { 0, 0, 0 };
bool g_deckOk = false;
Q4   g_levelQ = { 0, 0, 0, 1 };                // the skeleton board while riding (component space): "level"
bool g_levelOk = false;
volatile float g_melonBack = 25.0f;            // HJN_Set("melonback", cm): Melon -- the body shifts back off the board
volatile float g_profileLift = 0.0f;           // HJN_Set("profilelift", cm): Nose/Tail/Indy lift of the board (v16: 0)
volatile int   g_tailFromNose = 1;             // HJN_Set("tailfromnose", 0/1): Tail grabs the Nose grab's spot, mirrored to the tail
// (v16) where on the deck the grab spot is: "along" toward the front foot's end, "across", "up" (deck frame, cm)
V3   g_lastSpot = { 0, 0, 0 }; bool g_lastSpotOk = false; bool g_lastSpotMirrored = false;
V3   g_lastSpot2 = { 0, 0, 0 };                // (v35) a two-hand grab's back hand spot
V3   g_lastIn = { 1, 0, 0 };                   // (v36) from the last spot worked out: the way IN to the deck (component space)
V3   g_noseSpot = { 0, 0, 0 }; bool g_noseSpotOk = false;
float g_lastDeckPitch = -1.0f;
// v13: everything about the drawn deck is learned FROM THE DECK while riding (the game's own foot IK then has the
// feet on it): each foot's pose in the deck's frame, the deck's up in its own frame, and its riding "level" in
// component space. v12 related the deck to the skeleton board's frame -- the v77 log: the pitch control ran
// to its 90 deg limit on Indy with the deck staying flat and overshot Nose to 91 (93 off its aim), and the
// feet "reached" targets that were off the deck: the two frames do not line up (after a 180 least of all).
Q4   g_dLevel = { 0, 0, 0, 1 }; bool g_dLevelOk = false;
V3   g_dUpL = { 0, 0, 1 };      bool g_dUpOk = false;
V3   g_dFootP[2];  Q4 g_dFootQ[2];  bool g_dFootOk[2] = { false, false };
V3   g_uFootP[2];  Q4 g_uFootQ[2];             // (v32) the same spots as they lie under the feet now (see UseFootSpots)
int  g_dFootN = 0;
volatile int g_riding = 1;                     // HJN_Set("riding", 0/1): Lua -- on the ground, on the board (the only time to learn)
V3   g_lastSampleP[2]; bool g_lastSampleOk = false; int g_dFootRejected = 0; LONG g_flipLogs = 0;
// (v19) THE DECK'S UP IS ITS OWN Z. v13-v18 took the mesh's up averaged in the deck's frame (g_dUpL) -- but the skater
// mesh leans forward while riding, so that "up" leaned ~9 deg toward the nose: the riding front ankle read 18 cm over
// the deck and the back one 9 in every v81 grab, the Nose spot (37 cm out along an axis tilted 9 deg down) went under
// the nose, the Tail spot floated, and the Nose's pitch was really 9 deg more than logged ("super rocketed").
// The deck's own frame had (0, 0, 1) as its up at every first sample (the deck flat, the skater standing).
volatile int g_deckUpMode = 1;                 // HJN_Set("deckup"): 1 = the deck's own Z, 0 = the learned mesh-up (v18)
V3 DeckN() { return g_deckUpMode ? v3(0.0f, 0.0f, 1.0f) : g_dUpL; }
volatile int g_mirror = 0;                     // HJN_Set("mirror"): the game draws the pose MIRRORED (goofy / switch)
// the anim instance's Left/Right hand and foot IK fields are the ANIMATION's sides: with the mirror on, the
// animation's left hand is the mesh's RIGHT hand bone (the v81 goofy Nose pulled the left hand 70 cm short)
int AnimSlot(int s) { return g_mirror ? 1 - s : s; }
float HandA(const void* anim, int s) { return ReadF(anim, AnimSlot(s) ? AI_RHAND_A : AI_LHAND_A); }
V3 HandLoc(const void* anim, int s) { return ReadV3(anim, AnimSlot(s) ? AI_RHAND_LOC : AI_LHAND_LOC); }
float FootA(const void* anim, int k) { return ReadF(anim, AnimSlot(k) ? AI_RFOOT_A : AI_LFOOT_A); }
// the deck's own axes (in its frame): a toward the front foot, lat = up x a
bool DeckAxes(int front, V3& a, V3& lat) {
    if (!g_dFootOk[0] || !g_dFootOk[1] || front < 0 || front > 1) return false;
    const V3 u = DeckN();
    V3 d = sub(g_uFootP[front], g_uFootP[1 - front]);
    d = sub(d, mul(u, dot(d, u)));
    if (len(d) < 5.0f) return false;
    // (v79) THE DECK'S OWN LONG AXIS, pointed the way the front foot stands -- not the line between the feet. In the pressure
    // flip stance the back foot stands 5 cm off to the heel side and 8 cm forward: that line is 13 deg off the board, and
    // every 'along the board' number was measured on it -- with the front hand set 30 cm along, its spot swung 7 cm out past
    // the toe edge ("the hand pops out from the board into thin air, in that stance only")
    V3 x = v3(d.x >= 0.0f ? 1.0f : -1.0f, 0.0f, 0.0f);
    x = sub(x, mul(u, dot(x, u)));
    a = (fabsf(d.x) >= 5.0f && len(x) > 0.5f) ? norm(x) : norm(d);
    lat = cross(u, a);
    return true;
}
bool DeckXf(const void* mesh) {
    const uint8_t* sk = (const uint8_t*)g_skater;
    if (!sk) return false;
    const uint8_t* board = *(const uint8_t* const*)(sk + SK_BOARD);
    const uint8_t* deck = board ? *(const uint8_t* const*)(board + BD_DECK) : nullptr;
    if (!deck) return false;
    const Q4 wq = *(const Q4*)(deck + SC_C2W); const V3 wp = *(const V3*)(deck + SC_C2W + 0x10);
    const Q4 mq = *(const Q4*)((const uint8_t*)mesh + SC_C2W); const V3 mp = *(const V3*)((const uint8_t*)mesh + SC_C2W + 0x10);
    const V3 ms = *(const V3*)((const uint8_t*)mesh + SC_C2W + 0x20);
    Q4 dq = qnorm(qmul(qconj(mq), wq));
    const V3 d = qinv(mq, sub(wp, mp));
    const V3 dp = v3(d.x / (fabsf(ms.x) > 1e-3f ? ms.x : 1.0f), d.y / (fabsf(ms.y) > 1e-3f ? ms.y : 1.0f), d.z / (fabsf(ms.z) > 1e-3f ? ms.z : 1.0f));
    if (!finite3(dp) || !std::isfinite(dq.w) || len(dp) > 400.0f) return false;
    g_dq = dq; g_dp = dp;
    if (std::isfinite(ms.z) && fabsf(ms.z) > 1e-3f) g_ms = ms.z;
    {                                            // (v23) the deck component's bounds: origin, box extent, sphere radius
        const float* bb = (const float*)(deck + SC_C2W + 0x30);
        const V3 bo = v3(bb[0], bb[1], bb[2]); const V3 be = v3(bb[3], bb[4], bb[5]); const float R = bb[6];
        if (finite3(bo) && finite3(be) && std::isfinite(R) && R > 25.0f && R < 70.0f && len(sub(bo, wp)) < 60.0f) {
            g_boundsR = R; g_boundsOff = qinv(wq, sub(bo, wp)); g_boundsExt = be;
        }
    }
    return true;
}
V3 DeckUp() { return (g_deckOk && g_dUpOk) ? qrot(g_dq, DeckN()) : qrot(qmul(g_tq, g_C[g_flipper].q), g_upL); }
bool  g_offBOk[2] = { false, false };
int   g_sockFrame = 0;                         // (v7 stat, kept for the log line: 1 once the offsets are learned)
int   g_grabKind = 0;                          // the grab state seen this pose
// stats
float g_lastFitRes = 0.0f, g_lastPlant[2] = { 0, 0 }, g_lastAnkle[2] = { 0, 0 }, g_lastHeel[2] = { 0, 0 }, g_lastSwing[2] = { 0, 0 };
float g_lastRoll[2] = { 0, 0 }, g_lastArmClear = -1.0f, g_lastArmSwing = 0.0f;
float g_lastFootH[2] = { -99, -99 }, g_learnFootH[2] = { -99, -99 };

float qdiff(Q4 a, Q4 b) { return qangle(qmul(qconj(a), b)); }
Q4 qslerpTo(Q4 from, Q4 to, float t) {
    Q4 step = qmul(to, qconj(from));
    if (step.w < 0.0f) step = q4(-step.x, -step.y, -step.z, -step.w);
    return qnorm(qmul(qscale(step, t), from));
}
// the drawn deck's socket under foot k: the nearer of the two (a deck reversed under you keeps its left/right)
int SockFor(const void* anim, int k) {
    const V3 a = ReadV3(anim, AI_LFOOT_LOC), b = ReadV3(anim, AI_RFOOT_LOC), f = g_C[g_foot[k]].p;
    if (!finite3(a) || !finite3(b)) return k;
    return (len(sub(a, f)) <= len(sub(b, f))) ? 0 : 1;
}
V3 SockP(const void* anim, int si) { return ReadV3(anim, si ? AI_RFOOT_LOC : AI_LFOOT_LOC); }

// (v32) ONE RULE FOR WHICH WAY THE FOOT SPOTS LIE. v28-v31 turned the learned spots on the game's deck yaw flag, on
// "the feet say so" votes and again at a grab's start -- but that flag flips several times a second in ordinary
// riding, and the three fought: the running average mixed both orientations (v93: both feet learned onto the middle
// of the deck -- "the feet slide along the board to swap places"). Now the spots are STORED one way round
// (g_dFootP/Q: the left foot further along the deck's +X than the right) whatever the deck does, and which way they
// are APPLIED (g_uFootP/Q, what every grab calculation reads) comes from the feet themselves: 5 agreeing riding
// samples, or the animation's feet at a grab's first frame. No flag, nothing to get stuck.
bool g_revGrab = false, g_newGrab = false;
LONG g_orientLogs = 0;
bool DeckReversed();                           // (defined with the tilt loop, below)
void BaseMemForget(int stance);                // (v35, the same)
// (v34) SEVERAL STANCES, each learned on its own. The v95 log: riding regular the feet stand at L +9 / R -30 cm along
// the deck, riding SWITCH at L +31 / R -8 -- the same way round, slid 20 cm toward the nose -- and a deck turned round
// under you gives two more. v32's single set was re-learned on every change (2 s) and wrong until then: the front
// foot on the nose in regular, the feet "at the wrong end" and the hand off in switch. Now every stance you ride is
// kept (up to 6), a riding sample goes to the one it is within 7 cm of, 30 still samples elsewhere make a new one, and
// a grab uses the stance you last rode.
struct Stance { V3 P[2]; Q4 Q[2]; int n; bool ok; unsigned seen; };
constexpr int ST_N = 6;
Stance g_st[ST_N];
int  g_stCur = -1, g_stVote = -1, g_stVotes = 0, g_stGrab = -1, g_candN = 0;
volatile int g_grabStance = 1;                 // (v58) HJN_Set("grabstance"): 1 = a grab takes the TAIL layout (back foot nearest the tail), 0 = the stance last ridden
volatile int g_offBoard = 0;                  // (v84) HJN_Set("offboard", 1): on foot / stepping off / bailing -- no grab is posed
volatile int g_bail = 0;                      // (v63) HJN_Set("bail", 1): the game is bailing -- nothing of ours is posed, every window closes
V3   g_candP[2]; Q4 g_candQ[2]; unsigned g_stClock = 0;
void UseStance(int i) {
    if (i < 0 || i >= ST_N || !g_st[i].ok) return;
    for (int k = 0; k < 2; k++) { g_uFootP[k] = g_st[i].P[k]; g_uFootQ[k] = g_st[i].Q[k]; }
}
float StanceDist(const Stance& s, const V3* P) { return fmaxf(len(sub(P[0], s.P[0])), len(sub(P[1], s.P[1]))); }
// (v87) A STANCE HAS TO LOOK LIKE ONE. "Cannonball: the switch is broken now." Not the grab: at 13:31:29 a no comply that
// never popped left the feet standing still for half a second with the front foot on the nose's tip, and that was learned
// as riding stance #4 -- L (+39 +1 +16) R (+4 -10 +16). The tail-layout pick takes the stance whose back foot stands
// nearest the tail: turned round, that one, in every switch Cannonball after it (13:32:29 - 13:32:52), so the hand spots
// were measured from feet that were not there. Every stance really ridden has both ankles inside +-31 cm along the deck
// and 9-18 cm off its centre line on the SAME edge. One that does not is neither learned nor picked, and nothing is
// learned on a pose the mod's own parts are placing the feet on (a no comply, a hop, a held pose).
bool g_noLearn = false;
bool StancePlausible(const V3* P) {
    if (fabsf(P[0].x) > 36.0f || fabsf(P[1].x) > 36.0f) return false;                              // a foot out past the board's ends
    if (fabsf(P[0].y) < 4.0f || fabsf(P[1].y) < 4.0f || P[0].y * P[1].y < 0.0f) return false;      // an ankle on the centre line, or one on each edge
    return true;
}

// (v34) EVERY GRAB'S OWN NUMBERS -- all 12 of the game's grabs, set from Lua (HJN_GrabSet) and kept in the ini.
// (v35) + THE TWO-HAND GRABS, the mod's own (the game has none): kinds 200 Cannonball (front hand on the nose, back hand
// on the tail), 201 Gorilla (both hands on the toe edge: Mute + Indy), 202 Rocket (both hands on the nose, both feet on
// the tail). The game holds ONE of its grabs for the crouch (Lua picks it) and Lua names the two-hand grab
// (HJN_Set("double", kind)) and which hand is the front one ("dblfront"); the BACK hand has its own spot offsets and
// via point (GP_ALONG2...).
enum { GP_ALONG, GP_ACROSS, GP_UP, GP_VIAA, GP_VIAC, GP_VIAU, GP_TILT, GP_LIFT, GP_DROP, GP_SPLAYF, GP_SPLAYB,
       GP_ROLLF, GP_ROLLB, GP_BACK, GP_SLIDE, GP_ALONG2, GP_ACROSS2, GP_UP2, GP_VIAA2, GP_VIAC2, GP_VIAU2,
       GP_FOLD /* (v36) two-hand grabs: the most the back may fold forward, deg */, GP_ROLL /* (v47) the deck rolled about its long axis, deg: + the toe-side edge up */, GP_ELBOW /* (v48) the elbow swung round the shoulder-hand line, deg: the forearm steeper or flatter */, GP_N };
constexpr int GS_N = 15;                       // slots: Nose Melon Mute ChickenSalad Taipan Seatbelt | Tail Stalefish Indy RoastBeef CanadianBacon Crail | Cannonball Gorilla Rocket
float g_gp[GS_N][GP_N];
// (v41) RIDING SWITCH: the game's switch animation reaches differently, so the same numbers put the hand elsewhere.
// These are ADDED to a grab's numbers while HJN_Set("switch", 1) (HJN_GrabSetSw; the ini's SwHand... keys); 0 = as regular.
float g_gpSw[GS_N][GP_N]; volatile int g_switchNow = 0;
volatile int g_double = 0;                     // HJN_Set("double", 0 / 200 / 201 / 202)
volatile int g_dblFront = 0;                   // HJN_Set("dblfront", 0 left / 1 right): the mesh's FRONT hand (= the front foot's side)
int GrabSlot(int kind) {
    return (kind >= 1 && kind <= 6) ? kind - 1 : (kind >= 100 && kind <= 105) ? 6 + (kind - 100) : (kind >= 200 && kind <= 202) ? 12 + (kind - 200) : -1;
}
bool IsDouble(int kind) { return kind >= 200 && kind <= 202; }
float GP(int kind, int what) { const int s = GrabSlot(kind); return (s >= 0 && what >= 0 && what < GP_N) ? g_gp[s][what] + (g_switchNow ? g_gpSw[s][what] : 0.0f) : 0.0f; }
float GrabElbow() { return GP(g_grabKind, GP_ELBOW); }
struct Cap { V3 a, b; float r; bool ok; };
Cap  g_legPrev[6]; bool g_legPrevOk = false;   // the legs as they ended up last frame (the arms are solved before the legs)
// while riding with the game's foot IK on: where each foot bone sits over its socket, in the board's frame
// (v96, review) THE TOES AS THEY RIDE. BackFlat (further down) lays the back FOOT bone flat on the deck -- and its toe bone, which
// hangs on it, kept the bend the clip gives it against that foot: 24-33 deg off its riding bend at 0.05-0.25 s (the recording of
// 5 Oct 00:00:29; the game stands those toes over the tip of a tail that is levered up 64 deg under them). Carried by a foot
// that now lies flat, the toe bone pointed 14-20 deg DOWN INTO the deck for 10-15 poses in every one of the 17 regular no
// complies recorded (it rides level; in the game's own pose it points 22-30 deg up out of the deck), its sole 16-24 deg off
// the deck, about a toe joint at its riding height: the front third of the shoe in the tail. How each toe bone is turned
// against its foot bone is kept here from the very poses a riding stance is learned from (both feet held to the board by the
// game and still on it: no push, no pop, no trick) -- the mean of the first 30, then a slow average; BackFlat turns the toe
// to it by the share it turns the foot. Replayed on those 17: the toe's sole 0-4 deg off the deck while the plan runs.
Q4 g_toeRide[2] = { { 0, 0, 0, 1 }, { 0, 0, 0, 1 } }; int g_toeRideN[2] = { 0, 0 };
void DeckLearn(const void* mesh, const void* anim, const float* fa) {
    (void)mesh;
    if (DeckXf(mesh)) {                          // (v13) the drawn deck, learned from itself
        const Q4 dq = g_dq; const V3 dp = g_dp;
        g_dLevel = (!g_dLevelOk || qdiff(g_dLevel, dq) > 45.0f) ? dq : qslerpTo(g_dLevel, dq, 0.05f);
        g_dLevelOk = true;
        const V3 u = norm(qinv(dq, kUp));
        g_dUpL = g_dUpOk ? norm(lerp(g_dUpL, u, 0.05f)) : u;
        if (!g_dUpOk) Log("drawn deck up in its own frame: (%.2f, %.2f, %.2f)", u.x, u.y, u.z);
        g_dUpOk = true;
        // (v25) THE RIDING FOOT SPOTS MUST NOT WANDER. v14-v24 wiped them whenever the deck's turn against the mesh
        // jumped 45 deg -- every hippie jump and bail (1337 wipes in one evening) -- and re-learned from the next
        // frames (the landing crouch, the pop's foot slide) with a 3%/frame memory that then tracked the ollie before
        // each grab: two Melons seconds apart had the deck top at +1 and +6 cm and the feet's midpoint 9 cm apart
        // ("the hand just doesn't go to the same spot"). Now a sample counts only while Lua says you are RIDING (on
        // the ground, on the board), with both feet standing on the deck and still against it (< 0.6 cm/frame), no
        // sample further than 4 cm from the settled average (a settled average moves 1%/frame), and a deck turned
        // round under you (a 180) TURNS the learned spots with it instead of wiping them.
        V3 P[2]; Q4 Q[2]; bool okk = g_riding != 0 && fa[0] > 0.9f && fa[1] > 0.9f;
        for (int k = 0; k < 2 && okk; k++) {
            P[k] = qinv(dq, sub(g_C[g_foot[k]].p, dp));
            Q[k] = qmul(qconj(dq), g_C[g_foot[k]].q);
            const float h = dot(P[k], DeckN());
            const V3 flatP = sub(P[k], mul(DeckN(), h));
            if (len(flatP) > 40.0f || h < 0.0f || h > 25.0f) okk = false;
        }
        if (okk && fabsf(P[0].x - P[1].x) < 15.0f) okk = false;   // no clear stance along the deck
        if (okk && (g_noLearn || !StancePlausible(P))) okk = false;   // (v87) not on a trick's pose, and only what looks like a stance
        bool still = true;
        for (int k = 0; k < 2 && okk; k++) {
            if (g_lastSampleOk && len(sub(P[k], g_lastSampleP[k])) > 0.6f) still = false;   // a foot on the move (a pop, a slide)
            g_lastSampleP[k] = P[k];
        }
        g_lastSampleOk = okk;
        if (okk && still) {                          // (v34) to the stance it belongs to, or toward a new one
            g_stClock++;
            int best = -1; float bd = 1e9f;
            for (int i = 0; i < ST_N; i++)
                if (g_st[i].ok) { const float d = StanceDist(g_st[i], P); if (d < bd) { bd = d; best = i; } }
            if (best >= 0 && bd < 7.0f) {
                Stance& s = g_st[best];
                if (s.n < 100000) s.n++;
                const float rate = (s.n < 60) ? 1.0f / (float)s.n : 0.01f;
                for (int k = 0; k < 2; k++) { s.P[k] = lerp(s.P[k], P[k], rate); s.Q[k] = qslerpTo(s.Q[k], Q[k], rate); }
                for (int k = 0; k < 2; k++) {        // (v96, review) ...and how each toe bone is bent against its foot there (the note at g_toeRide)
                    const int to = g_toe[k];
                    if (to < 0 || g_parent[to] != g_foot[k]) continue;
                    const Q4 tq = qnorm(qmul(qconj(g_C[g_foot[k]].q), g_C[to].q));
                    g_toeRide[k] = (g_toeRideN[k] == 0) ? tq : qslerpTo(g_toeRide[k], tq, (g_toeRideN[k] < 30) ? 1.0f / (float)(g_toeRideN[k] + 1) : 0.02f);
                    if (g_toeRideN[k] < 30) g_toeRideN[k]++;
                }
                for (int k = 0; k < 2; k++) {        // (v97) ...and how each shin stands on its foot there (the note at g_shinRide): the game's own leg, whole and really bent
                    const int th = g_thigh[k], ca = g_calf[k], ft = g_foot[k];
                    if (th < 0 || ca < 0 || ft < 0 || !g_legRefOk || g_legRef[k][1] < 1.0f) continue;
                    const V3 sh = sub(g_C[ca].p, g_C[ft].p), hf = sub(g_C[ft].p, g_C[th].p), kv = sub(g_C[ca].p, g_C[th].p);
                    const float sl = len(sh), hl2 = dot(hf, hf);
                    if (!(sl > g_legRef[k][1] * 0.96f && sl < g_legRef[k][1] * 1.04f) || hl2 < 100.0f) continue;
                    if (len(sub(kv, mul(hf, dot(kv, hf) / hl2))) < 10.0f) continue;      // (a knee on its leg's line says nothing)
                    const V3 v = norm(qinv(qnorm(g_C[ft].q), sh));
                    if (!finite3(v)) continue;
                    g_shinRide[k] = (g_shinRideN[k] == 0) ? v : norm(lerp(g_shinRide[k], v, (g_shinRideN[k] < 30) ? 1.0f / (float)(g_shinRideN[k] + 1) : 0.02f));
                    if (g_shinRideN[k] < 30 && ++g_shinRideN[k] == 30)
                        Log("legs: the %s shin as it stands on its foot riding, in the foot's own frame: (%.2f %.2f %.2f) -- a straight or squeezed leg's knee goes that way in a hop", k ? "R" : "L", g_shinRide[k].x, g_shinRide[k].y, g_shinRide[k].z);
                    {                                // (v99) ...and the knee's hinge, in the thigh's own frame and in the shin's (the note at g_hingeTh)
                        const V3 tv = sub(g_C[ca].p, g_C[th].p), sv = sub(g_C[ft].p, g_C[ca].p);
                        const float tl = len(tv);
                        const V3 nn = cross(tv, sv);
                        if (g_legRef[k][0] > 1.0f && tl > g_legRef[k][0] * 0.96f && tl < g_legRef[k][0] * 1.04f && len(nn) > 200.0f) {
                            const V3 n1 = norm(nn), ht = norm(qinv(qnorm(g_C[th].q), n1)), hc = norm(qinv(qnorm(g_C[ca].q), n1));
                            if (finite3(ht) && finite3(hc)) {
                                HingeLearn(k, ht, hc);
                                const V3 hf = norm(qinv(qnorm(g_C[ft].q), n1));          // (v100) ...and in the foot's; and how the foot is turned against its shin
                                const Q4 fr = qnorm(qmul(qconj(qnorm(g_C[ca].q)), qnorm(g_C[ft].q)));
                                if (finite3(hf) && std::isfinite(fr.x) && std::isfinite(fr.y) && std::isfinite(fr.z) && std::isfinite(fr.w)) FootRelLearn(k, hf, fr);
                            }
                        }
                    }
                }
                s.seen = g_stClock;
                g_candN = 0;
                if (best != g_stCur) {
                    if (best == g_stVote) g_stVotes++; else { g_stVote = best; g_stVotes = 1; }
                    if (g_stVotes >= 5) {
                        g_stCur = best; g_stVotes = 0;
                        if (InterlockedIncrement(&g_orientLogs) <= 200)
                            Log("riding stance #%d now: L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f), %d samples", best,
                                s.P[0].x, s.P[0].y, s.P[0].z, s.P[1].x, s.P[1].y, s.P[1].z, s.n);
                    }
                } else g_stVotes = 0;
            } else {
                if (g_candN > 0 && fmaxf(len(sub(P[0], g_candP[0])), len(sub(P[1], g_candP[1]))) < 3.0f) {
                    g_candN++;
                    for (int k = 0; k < 2; k++) { g_candP[k] = lerp(g_candP[k], P[k], 1.0f / (float)g_candN); g_candQ[k] = qslerpTo(g_candQ[k], Q[k], 1.0f / (float)g_candN); }
                } else { g_candN = 1; for (int k = 0; k < 2; k++) { g_candP[k] = P[k]; g_candQ[k] = Q[k]; } }
                if (g_candN >= 30) {                     // half a second of standing still somewhere new: a stance of its own
                    int slot = -1; unsigned oldest = 0xffffffffu;
                    for (int i = 0; i < ST_N && slot < 0; i++) if (!g_st[i].ok) slot = i;
                    if (slot < 0) for (int i = 0; i < ST_N; i++) if (g_st[i].seen < oldest) { oldest = g_st[i].seen; slot = i; }
                    Stance& s = g_st[slot];
                    for (int k = 0; k < 2; k++) { s.P[k] = g_candP[k]; s.Q[k] = g_candQ[k]; }
                    s.n = g_candN; s.ok = true; s.seen = g_stClock;
                    g_stCur = slot; g_stVotes = 0; g_candN = 0;
                    BaseMemForget(slot);
                    Log("a new riding stance learned, #%d: L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f)", slot,
                        s.P[0].x, s.P[0].y, s.P[0].z, s.P[1].x, s.P[1].y, s.P[1].z);
                }
            }
        }
        g_dFootOk[0] = g_dFootOk[1] = (g_stCur >= 0 && g_st[g_stCur].ok);
        g_dFootN = g_dFootOk[0] ? g_st[g_stCur].n : 0;
        UseStance(g_stCur);                          // between grabs: the stance being ridden
    }
    {                                            // the skeleton board while riding = "level" for the grab pitches
        const Q4 fq = g_C[g_flipper].q;
        g_levelQ = (!g_levelOk || qdiff(g_levelQ, fq) > 45.0f) ? fq : qslerpTo(g_levelQ, fq, 0.05f);
        g_levelOk = true;
    }
    {                                            // the deck's up, in the board bone's frame
        const V3 u = norm(qinv(g_C[g_flipper].q, kUp));
        const bool first = !g_upOk;
        g_upL = first ? u : norm(lerp(g_upL, u, 0.02f));
        g_upOk = true;
        if (first) Log("deck up in the board bone's frame: (%.2f, %.2f, %.2f)", u.x, u.y, u.z);
    }
    for (int k = 0; k < 2; k++) {
        if (!(fa[k] > 0.9f)) continue;
        const V3 s = SockP(anim, SockFor(anim, k));
        if (!finite3(s)) continue;
        const V3 o = qinv(g_C[g_flipper].q, sub(g_C[g_foot[k]].p, s));
        if (len(o) > 40.0f) continue;
        g_offB[k] = (!g_offBOk[k] || len(sub(g_offB[k], o)) > 12.0f) ? o : lerp(g_offB[k], o, 0.1f);
        g_offBOk[k] = true;
    }
    if (g_offBOk[0] && g_offBOk[1]) g_sockFrame = 1;
}

// where foot k goes on the drawn deck (position; the rotation is the animation's, turned with the tweak)
bool DeckFoot(const void* mesh, const void* anim, int k, V3& p, Q4& q) {
    (void)mesh; (void)anim;
    if (!g_deckOk || !g_dFootOk[k]) return false;
    p = add(g_dp, qrot(g_dq, g_uFootP[k]));
    q = qnorm(qmul(g_dq, g_uFootQ[k]));
    return finite3(p) && len(sub(p, g_C[g_foot[k]].p)) < 90.0f;
}

// the grab's profile: which foot is in front (the nose's foot), which end rises and how far
// (v34) all 12 grabs have a profile. spot: 1 the nose tip, 2 the tail tip, 3 the toe-side edge, 4 the heel-side edge;
// spotAlong: cm from the feet's midpoint toward the front foot (edge spots); route: 1 the arm goes between the legs,
// 2 round the outside; frontRoll/backRoll: the foot's roll onto a sole edge, signed (+ inner edge, - outer edge).
struct GrabProfile { bool fixed; int riseFoot; float pitch; int frontFoot; float frontRoll; float backRoll; int spot; float spotAlong; int route; bool set2; };
volatile float g_indyPitch = 15.0f;            // (pre-v34 settings, no longer read: every grab has its own numbers in g_gp)
volatile float g_melonPitch = 25.0f;
volatile float g_melonFwd = 6.0f;              // HJN_Set("melonfwd", cm): the Melon spot this far toward the front foot from the feet's midpoint
GrabProfile ProfileFor(int kind, int sd) {
    GrabProfile p = { false, sd, 0.0f, sd, 0.0f, 0.0f, 0, 0.0f, 0, false };
    if (GrabSlot(kind) < 0) return p;
    // the front-hand grabs' hand is on the front foot's side; (v35) a two-hand grab: Lua says which hand is in front
    const int front = IsDouble(kind) ? (g_dblFront ? 1 : 0) : (kind < 100) ? sd : 1 - sd;
    const int back = 1 - front;
    const bool frontHand = (sd == front);
    p.fixed = true; p.frontFoot = front;
    p.pitch = GP(kind, GP_TILT); p.frontRoll = GP(kind, GP_ROLLF); p.backRoll = GP(kind, GP_ROLLB);
    p.riseFoot = back;                                 // the tail's end rises...
    switch (kind) {
    case 1:   p.riseFoot = front; p.spot = 1; break;                       // Nose: front hand, the nose up
    case 105: p.riseFoot = front; p.spot = 1; break;                       // Crail: back hand on the nose
    case 100: p.spot = 2; p.route = 2; break;                              // Tail: back hand, round the outside of the back leg
    case 6:   p.spot = 2; break;                                           // Seatbelt: front hand across to the tail
    case 2:   p.spot = 4; p.spotAlong = g_melonFwd; break;                 // Melon: front hand, heel edge just behind the front heel
    case 4:   p.spot = 4; p.route = 1; break;                              // Chicken Salad: front hand between the legs to the heel edge
    case 101: p.spot = 4; p.spotAlong = -6.0f; p.route = 2; break;         // Stalefish: back hand behind the back leg to the heel edge
    case 103: p.spot = 4; p.route = 1; break;                              // Roast Beef: back hand between the legs to the heel edge
    case 3:   p.spot = 3; p.spotAlong = 6.0f; p.route = 1; break;          // Mute: front hand to the toe edge
    case 5:   p.spot = 3; p.route = 1; break;                              // Taipan: front hand between the legs to the toe edge
    case 102: p.spot = 3; p.route = 1; break;                              // Indy: back hand to the toe edge, between the knees
    case 104: p.spot = 3; p.route = 1; break;                              // Canadian Bacon: back hand between the legs to the toe edge
    // (v35) the two-hand grabs: what THIS hand (sd) does; the feet's side of the profile is the same for both hands
    case 200: p.spot = frontHand ? 1 : 2; p.route = frontHand ? 0 : 2; p.set2 = !frontHand; break;               // Cannonball
    case 201: p.spot = 3; p.spotAlong = frontHand ? 10.0f : -10.0f; p.route = 1; p.set2 = !frontHand; break;     // Gorilla
    case 202: p.riseFoot = front; p.spot = 1; p.set2 = !frontHand; break;                                         // Rocket
    }
    return p;
}

// the rotation whose images of the unit X, Y, Z axes are x, y, z (an orthonormal right-handed basis)
Q4 QuatFromBasis(V3 x, V3 y, V3 z) {
    const float m00 = x.x, m01 = y.x, m02 = z.x, m10 = x.y, m11 = y.y, m12 = z.y, m20 = x.z, m21 = y.z, m22 = z.z;
    const float tr = m00 + m11 + m22;
    Q4 q;
    if (tr > 0.0f) { const float s = sqrtf(tr + 1.0f) * 2.0f; q = q4((m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s, 0.25f * s); }
    else if (m00 > m11 && m00 > m22) { const float s = sqrtf(1.0f + m00 - m11 - m22) * 2.0f; q = q4(0.25f * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s); }
    else if (m11 > m22) { const float s = sqrtf(1.0f + m11 - m00 - m22) * 2.0f; q = q4((m01 + m10) / s, 0.25f * s, (m12 + m21) / s, (m02 - m20) / s); }
    else { const float s = sqrtf(1.0f + m22 - m00 - m11) * 2.0f; q = q4((m02 + m20) / s, (m12 + m21) / s, 0.25f * s, (m10 - m01) / s); }
    return qnorm(q);
}
V3 g_lastHeading = { 1, 0, 0 };

// (v17) OUR OWN GRAB SPOTS, on the deck (the game's were off: its Nose point sat 30 cm above the deck). In the deck's
// frame: along its long axis from the feet's midpoint (+ toward the front foot), across it, up from its top (the top
// = the riding ankles' height less 9 cm). Nose: the nose tip; Tail: the tail tip; Indy: the toe-side edge between
// the feet; Melon: the heel-side edge between the feet. The wrist goes there (no HandUp).
volatile int   g_ownSpots = 1;                 // HJN_Set("ownspots", 0/1)
volatile float g_deckHalfLen = 40.0f;          // HJN_Set("deckhalflen", cm): feet midpoint to a tip
volatile float g_deckHalfWidth = 10.5f;        // HJN_Set("deckhalfwidth", cm)
volatile float g_spotUp = 5.0f;                // HJN_Set("spotup", cm): the wrist over the deck top at a tip
volatile float g_spotIn = 7.0f;                // HJN_Set("spotin", cm): the wrist this far in from the tip (the fingers wrap the end)
volatile float g_footSlide = 8.0f;             // HJN_Set("footslide", cm): Nose/Tail -- the foot on the grabbed end slides off it
// (v22) THE TUCK for the between-the-feet grabs. The v83 log: the Melon hand stopped 8-32 cm short of its spot and the
// Indy hand 9-18 short, every grab -- the back/front shoulder sits ~70 cm over the deck at the game's crouch and the
// arm is 53: the hand hung where the arm ran out (Melon "way too high", Indy "too low, arm outside the leg"). Nose and
// Tail reach because their spots are far out along the deck. So for Melon and Indy the board comes up, the hips go
// down and the spine leans more -- the tucked-knees look those grabs have anyway.
volatile float g_melonLift = 6.0f;             // HJN_Set("melonlift", cm)   (v16-v21: -4)
volatile float g_indyLift = 8.0f;              // HJN_Set("indylift", cm)    (was the 0 of profilelift)
volatile float g_melonDrop = 8.0f;             // HJN_Set("melondrop", cm): the hips down along the deck's normal
volatile float g_indyDrop = 6.0f;              // HJN_Set("indydrop", cm)
volatile float g_leanTuck = 1.5f;              // HJN_Set("leantuck"): Melon/Indy lean limit x this
volatile float g_spotUpEdge = 5.0f;           // HJN_Set("spotupedge", cm): the Indy/Melon wrist over the deck top (v21: 1 -- the hand hung under the edge)
volatile float g_deckCentre = 0.0f;            // HJN_Set("deckcentre", cm): the deck mesh bounds' centre along its X (Lua measures it)
volatile int   g_deckMeasured = 0;             // HJN_Set("deckmeasured", 0/1): the half length/width came from the deck mesh's bounds
// (v23) the deck component's own bounds, read natively (USceneComponent::Bounds follows ComponentToWorld): the bounding
// sphere's radius does not depend on the deck's turn, so the half length = sqrt(R^2 - halfWidth^2 - 9) when no
// setting / Lua measurement says otherwise; the bounds' centre in the deck's frame is where its middle sits off the origin
float HalfWidth() { return g_deckHalfWidth > 0.0f ? (float)g_deckHalfWidth : 10.5f; }
float HalfLen() {
    if (g_deckHalfLen > 0.0f) return g_deckHalfLen;
    if (g_boundsR > 0.0f) { const float hw = HalfWidth(); const float v = g_boundsR * g_boundsR - hw * hw - 9.0f; if (v > 400.0f) return sqrtf(v); }
    return 40.0f;
}
float CentreX() { return g_deckMeasured ? (float)g_deckCentre : (g_boundsR > 0.0f ? g_boundsOff.x : 0.0f); }
// (v23) the pitch loop: 1-DOF, with the sense of the deck's answer (the game's deck yaw offset +-180 = the deck reversed
// under you answers a bone pitch the other way) and a check against what the deck actually does
float g_lastRollTarget = 0.0f;                 // (v47) the roll the deck is held at (for the trace)
volatile int g_rollLevel = 1;                  // HJN_Set("rolllevel", 0/1): also level the deck's roll (about its long axis)
// (v24) YOUR hand offsets per grab, on top of the geometric spot: along (+ toward the nose / front foot), across
// (+ toward the toes), up (+ off the deck), cm -- HJN_HandOffset(kind, along, across, up); Lua nudges them live
// from the numpad and keeps them in the ini, so the placement is tuned once by eye and stays
int HoffSlot(int kind) { return GrabSlot(kind); }   // (v34: the offsets live in g_gp, for all 12 grabs)
int   g_pitchSense = 1;                        // flipped when the deck answers the other way (reset per grab)
float g_pAcc = 0.0f, g_pStart = 0.0f; int g_pFrames = 0; LONG g_senseLogs = 0;
float g_pI = 0.0f, g_rI = 0.0f, g_pPrev = 0.0f; bool g_pPrevOk = false;   // the pitch / roll commands (deg) and the last pitch
// (v26) the feed-forward: what the deck does on its own (base) per grab kind, and our eased addition
float g_pBase = 0.0f, g_rBase = 0.0f, g_pFF = 0.0f, g_rFF = 0.0f, g_rPrev = 0.0f; int g_steady = 0, g_pBaseFrom = 0;
float g_cmdLag = 0.0f, g_rCmdLag = 0.0f, g_trim = 0.0f, g_pBaseEst = 0.0f, g_rBaseEst = 0.0f, g_memStart = 0.0f;   // (v30) the lag model
bool  g_senseInit = false; bool g_senseChecked = false; float g_pStartPitch = 0.0f;
volatile float g_deckLag = 25.0f;              // HJN_Set("decklag", frames): how far the drawn deck trails the bone (the game's smoothing)
// (v35) the deck's own pitch is remembered per grab AND per riding stance (the stance says how the pose lies on the
// deck; v27-v34 split it by the game's deck yaw flag, which flips in ordinary riding), slot ST_N = no stance
float g_baseMem[GS_N * (ST_N + 1)]; bool g_baseMemOk[GS_N * (ST_N + 1)];
bool  g_holdLive = false;                      // (v35) the game still HOLDS the grab (its grab byte is set): the only time to learn
volatile int g_catchHold = 1; LONG g_catchHolds = 0;   // (v55) HJN_Set("catchhold"): the game's catch-orient state held on through its own grabs
uint8_t* BoardMC();
int BoardMCMode() { uint8_t* bm = BoardMC(); return bm ? (int)bm[0x534] : -1; }   // (v55) for the trace: USkateboardExMovementComponent::_movementMode
void BaseMemForget(int stance) {               // a stance slot taken by a new stance: what was learned for the old one goes
    if (stance < 0 || stance > ST_N) return;
    for (int i = 0; i < GS_N; i++) { g_baseMem[i + GS_N * stance] = 0.0f; g_baseMemOk[i + GS_N * stance] = false; }
}
volatile float g_fitCap = 35.0f;               // HJN_Set("fitcap", deg): the most the old fit (non-profiled grabs) may tip the board (v28; was TweakMax = 90)
int   g_grabFrames = 0;                        // (v27) posed frames into this grab
float g_lastRollNow = 0.0f; int g_lastSense = 1;
static inline float Wrap180(float a) { return a - 360.0f * floorf(a / 360.0f + 0.5f); }   // (v61) into [-180, 180)
bool DeckReversed() {
    const uint8_t* sk = (const uint8_t*)g_skater;
    if (!sk) return false;
    const uint8_t* board = *(const uint8_t* const*)(sk + SK_BOARD);
    const uint8_t* bm = board ? *(const uint8_t* const*)(board + BD_MOVE) : nullptr;
    if (!bm) return false;
    const float y = ReadF(bm, 0x624);
    return std::isfinite(y) && fabsf(Wrap180(y)) > 90.0f;   // (v62) the game's own reverts ADD 180 to this: 360 is not reversed
}
float g_lastTop = 0.0f, g_lastTopToes = -99.0f, g_lastTopAnkles = -99.0f;
// the deck's top, in its frame: the riding toe joints (on the sole, ~3 cm of shoe under them) when the rig has
// them, else the riding ankles less 9 cm
float DeckTop() {
    const V3 u = DeckN();
    g_lastTopAnkles = fminf(dot(g_uFootP[0], u), dot(g_uFootP[1], u)) - 9.0f;
    float top = clampf(g_lastTopAnkles, -3.0f, 8.0f);
    g_lastTopToes = -99.0f;
    if (g_toe[0] >= 0 && g_toe[1] >= 0) {
        float tmin = 1e9f;
        for (int k = 0; k < 2; k++) {
            const V3 tl = qinv(g_C[g_foot[k]].q, sub(g_C[g_toe[k]].p, g_C[g_foot[k]].p));   // the toe joint off the ankle, in the foot's frame
            tmin = fminf(tmin, dot(add(g_uFootP[k], qrot(g_uFootQ[k], tl)), u));
        }
        if (tmin < 1e8f) { g_lastTopToes = tmin - 3.0f; top = clampf(g_lastTopToes, -4.0f, 10.0f); }
    }
    g_lastTop = top;
    return top;
}
bool OwnSpot(int kind, const GrabProfile& pr, V3& out) {
    if (!g_ownSpots || !g_deckOk || !g_dFootOk[0] || !g_dFootOk[1]) return false;
    if (!pr.fixed || pr.spot == 0) return false;
    V3 a, lat;
    if (!DeckAxes(pr.frontFoot, a, lat)) return false;
    const V3 u = DeckN();
    const float top = DeckTop();
    const float midA = 0.5f * (dot(g_uFootP[0], a) + dot(g_uFootP[1], a));
    const float midL = 0.5f * (dot(g_uFootP[0], lat) + dot(g_uFootP[1], lat));
    float toe = 0.0f;                                  // which side of the deck the toes point to
    for (int k = 0; k < 2; k++)
        if (g_toe[k] >= 0) toe += dot(qrot(g_uFootQ[k], qinv(g_C[g_foot[k]].q, sub(g_C[g_toe[k]].p, g_C[g_foot[k]].p))), lat);
    // (v78) "in the pressure flip stance the hand moves outward from the board into thin air": the toe side was the side the
    // two feet's TOES point to, summed -- and in the pressure stance the back foot is turned along the tail: the sum can
    // change sign, and the toe-edge spot, its offsets and the hand's way in all flip to the other edge. The ANKLES ride
    // ~10 cm to the heel side of the deck's centre line in every stance: when they are clearly to one side, that decides
    const float tsToe = (toe >= 0.0f) ? 1.0f : -1.0f;
    const float ts = (fabsf(midL) > 4.0f) ? ((midL < 0.0f) ? 1.0f : -1.0f) : tsToe;
    if (ts != tsToe) { static LONG told = 0; if (InterlockedIncrement(&told) <= 8) Log("spot: the toes point %+.0f to the side the ankles ride on (%+.0f cm off the centre line) -- the toe side is taken from the ankles (stance %d)", toe, midL, g_stCur); }
    V3 s;
    // (v18) from the deck's own centre: v17 measured from the feet's midpoint, which sits ~11 cm toward the tail (the back
    // foot rides on it) and ~10 cm toward the heels (ankles) -- the Nose "tip" landed 17 cm inside the nose
    // (v22) the tips from the deck mesh's own bounds (Lua measures them; the guessed 40 put the hand "too far in"):
    // the +a tip is at centre*a.x + halfLen along a, the -a tip at centre*a.x - halfLen
    const float cx = CentreX() * a.x, hl = HalfLen(), hw = HalfWidth();
    switch (pr.spot) {
    case 1:  s = v3(cx + (hl - g_spotIn), 0.0f, top + g_spotUp); break;                  // the nose tip
    case 2:  s = v3(cx - (hl - g_spotIn), 0.0f, top + g_spotUp); break;                  // the tail tip
    case 3:  s = v3(midA + pr.spotAlong, ts * (hw + 2.0f), top + g_spotUpEdge); break;   // the toe-side edge
    default: s = v3(midA + pr.spotAlong, -ts * (hw + 2.0f), top + g_spotUpEdge); break;  // the heel-side edge
    }
    // (v24) your own offsets for this grab: + toward the nose, + toward the toes, + off the deck
    s = add(s, pr.set2 ? v3(GP(kind, GP_ALONG2), GP(kind, GP_ACROSS2) * ts, GP(kind, GP_UP2))      // (v35) a two-hand grab's back hand
                       : v3(GP(kind, GP_ALONG), GP(kind, GP_ACROSS) * ts, GP(kind, GP_UP)));
    {                                                  // (v36) which way is IN from this spot: toward the deck, across the grabbed edge
        const V3 inL = (pr.spot == 1) ? mul(a, -1.0f) : (pr.spot == 2) ? a : (pr.spot == 3) ? mul(lat, -ts) : mul(lat, ts);
        g_lastIn = norm(qrot(g_dq, inL));
    }
    out = add(g_dp, qrot(g_dq, add(add(mul(a, s.x), mul(lat, s.y)), mul(u, s.z))));
    g_lastSpot = s;
    return finite3(out);
}

// ------------------------------------------------------------------ (v36) THE BODY OF A TWO-HAND GRAB
// v35 bent the whole upper body at ONE joint (the first spine joint) toward the middle of the two spots -- up to 64 deg
// of kink there, sideways as often as forward (the v97 Cannonball: the back hand 11-31 cm short while the front one
// reached, thighs 13-17 cm into the torso: "limb angles all crazy"). Now the back is a CHAIN: every spine joint takes
// its share of a forward fold, a side bend and a twist, and the hips may move along the deck -- the four numbers found
// by a small search (from last frame's answer, so it cannot jump) for the least bending that lets both arms reach at
// 94% of their length. The head comes back up by part of the fold, so the rider looks where he goes, not at his knees.
volatile float g_sideMax = 25.0f;              // HJN_Set("sidemax", deg)
volatile float g_twistMax = 45.0f;             // HJN_Set("twistmax", deg)
volatile float g_shiftMax = 15.0f;             // HJN_Set("shiftmax", cm)
float g_torso[4] = { 0, 0, 0, 0 };             // held: fold, side bend, twist (deg), hips along the deck (cm)
float g_lastTorso[4] = { 0, 0, 0, 0 }, g_lastShort[2] = { 0, 0 };
struct TorsoFrame { V3 joint[6]; int n; V3 S[2]; V3 F, W, T, A; float reach[2]; V3 tg[2]; };
Q4 TorsoEach(const TorsoFrame& tf, const float* x) {
    const float k = 1.0f / (float)tf.n;
    return qnorm(qmul(qaxis(tf.T, x[2] * k), qmul(qaxis(tf.W, x[1] * k), qaxis(tf.F, x[0] * k))));
}
void TorsoEval(const TorsoFrame& tf, const float* x, V3* out) {
    const Q4 each = TorsoEach(tf, x);
    V3 j[6];
    for (int i = 0; i < tf.n; i++) j[i] = tf.joint[i];
    V3 s0 = tf.S[0], s1 = tf.S[1];
    for (int i = 0; i < tf.n; i++) {
        const V3 p = j[i];
        for (int m = i + 1; m < tf.n; m++) j[m] = add(p, qrot(each, sub(j[m], p)));
        s0 = add(p, qrot(each, sub(s0, p)));
        s1 = add(p, qrot(each, sub(s1, p)));
    }
    const V3 sh = mul(tf.A, x[3]);
    out[0] = add(s0, sh); out[1] = add(s1, sh);
}
float TorsoCost(const TorsoFrame& tf, const float* x, float* shortBy) {
    V3 s[2];
    TorsoEval(tf, x, s);
    float c = 0.0f;
    for (int i = 0; i < 2; i++) {
        const float d = fmaxf(0.0f, len(sub(tf.tg[i], s[i])) - tf.reach[i]);
        if (shortBy) shortBy[i] = d;
        c += 10.0f * d * d;
    }
    return c + 0.010f * x[0] * x[0] + 0.020f * x[1] * x[1] + 0.012f * x[2] * x[2] + 0.05f * x[3] * x[3];
}
float LeanTwo(const V3* tgt, const float* wh);     // (v35's, the fallback without a spine chain)
float TorsoTwo(const V3* tg, const float* wh, float foldMax, int frontFoot) {
    if (g_spineN < 1 || g_spineN > 6 || g_pelvis < 0 || g_chest < 0) return LeanTwo(tg, wh);
    TorsoFrame tf;
    tf.n = g_spineN;
    for (int i = 0; i < tf.n; i++) tf.joint[i] = g_Ct[g_spine[i]].p;
    for (int i = 0; i < 2; i++) { tf.S[i] = g_Ct[g_uarm[i]].p; tf.reach[i] = armLen(i) * 0.94f; tf.tg[i] = tg[i]; }
    const V3 top = (g_neck >= 0) ? g_Ct[g_neck].p : mul(add(tf.S[0], tf.S[1]), 0.5f);
    tf.T = sub(top, tf.joint[0]);
    if (len(tf.T) < 5.0f) return LeanTwo(tg, wh);
    tf.T = norm(tf.T);
    V3 lr = sub(tf.S[1], tf.S[0]);                     // left shoulder -> right shoulder
    lr = sub(lr, mul(tf.T, dot(lr, tf.T)));
    if (len(lr) < 5.0f) return LeanTwo(tg, wh);
    tf.F = norm(lr);                                   // about it, + = the chest goes forward and down
    tf.W = norm(cross(tf.F, tf.T));                    // the way the chest faces; about it, + = toward the left shoulder
    V3 a, lat;
    const bool along = g_deckOk && DeckAxes(frontFoot, a, lat);
    tf.A = along ? norm(qrot(g_dq, a)) : v3(0, 0, 0);
    const float lo[4] = { 0.0f, -fmaxf(g_sideMax, 0.0f), -fmaxf(g_twistMax, 0.0f), along ? -fmaxf(g_shiftMax, 0.0f) : 0.0f };
    const float hi[4] = { clampf(foldMax, 0.0f, 85.0f), -lo[1], -lo[2], -lo[3] };
    float x[4];
    for (int d = 0; d < 4; d++) x[d] = clampf(g_torso[d], lo[d], hi[d]);
    float best = TorsoCost(tf, x, nullptr);
    const float steps[3] = { 8.0f, 3.0f, 1.0f };
    for (int pass = 0; pass < 3; pass++)
        for (int rep = 0; rep < 5; rep++) {
            bool moved = false;
            for (int d = 0; d < 4; d++)
                for (int sg = -1; sg <= 1; sg += 2) {
                    float y[4] = { x[0], x[1], x[2], x[3] };
                    y[d] = clampf(y[d] + (float)sg * steps[pass] * (d == 3 ? 0.5f : 1.0f), lo[d], hi[d]);
                    const float c = TorsoCost(tf, y, nullptr);
                    if (c < best - 1e-3f) { best = c; x[d] = y[d]; moved = true; }
                }
            if (!moved) break;
        }
    const float w = clampf(fmaxf(wh[0], wh[1]), 0.0f, 1.0f);
    float u[4];
    for (int d = 0; d < 4; d++) { g_torso[d] += (x[d] - g_torso[d]) * 0.25f; u[d] = g_torso[d] * w; g_lastTorso[d] = u[d]; }
    TorsoCost(tf, u, g_lastShort);
    if (fabsf(u[3]) > 0.05f) SetComp(g_pelvis, g_Ct[g_pelvis].q, add(g_Ct[g_pelvis].p, mul(tf.A, u[3])));
    const Q4 each = TorsoEach(tf, u);
    for (int i = 0; i < g_spineN; i++) TurnComp(g_spine[i], each);
    if (g_neck >= 0 && u[0] > 1.0f) TurnComp(g_neck, qaxis(tf.F, -0.45f * u[0]));
    return u[0];
}

// ------------------------------------------------------------------ (v36) THE HAND ON THE BOARD
// The game poses ONE hand for its grab and only for that grab's own spot: in a two-hand grab the other hand hung open
// ("only 1 hand is grabbing"), and the posed one faced the base grab's edge, not the end it now holds. So the hand is
// TURNED to its spot: the fingers point down past the edge (no more than 70 deg off the forearm's line), the palm faces
// in toward the deck; and the four fingers are CURLED round the edge, each joint aimed (root 50, middle 60, tip 35 deg
// x FingerCurl further toward the palm). All from the bones' positions -- which side the palm is on comes from the
// hand's own shape (fingers ahead, index to pinky across; checked against the way the fingers already curl).
volatile int   g_handAim = 1;                  // HJN_Set("handaim"): 0 off, 1 the two-hand grabs, 2 every grab
volatile float g_fingerCurl = 1.0f;            // HJN_Set("fingercurl", 0..1.5)
volatile float g_curlJoint[3] = { 50.0f, 60.0f, 35.0f };   // (v52) HJN_Set("curlroot"/"curlmid"/"curltip"): degrees each finger joint curls toward the palm, x FingerCurl
float g_lastPalm[2] = { 0, 0 }, g_lastWrist[2] = { 0, 0 };
bool HandAxes(int s, V3& f, V3& n) {
    const V3 H = g_Ct[g_hand[s]].p;
    const V3 I = g_Ct[g_fing[s][1][0]].p, P = g_Ct[g_fing[s][4][0]].p;
    f = sub(mul(add(add(I, g_Ct[g_fing[s][2][0]].p), add(g_Ct[g_fing[s][3][0]].p, P)), 0.25f), H);
    if (len(f) < 1.0f) return false;
    f = norm(f);
    V3 a = sub(I, P);
    a = sub(a, mul(f, dot(a, f)));
    if (len(a) < 0.5f) return false;
    a = norm(a);
    n = (s == 0) ? cross(a, f) : cross(f, a);          // (UE's axes are left-handed: the left palm is a x f)
    float curl = 0.0f;
    for (int i = 1; i <= 4; i++) curl += dot(sub(g_Ct[g_fing[s][i][2]].p, g_Ct[g_fing[s][i][0]].p), n);
    g_lastPalm[s] = curl;
    if (curl < -2.0f) n = mul(n, -1.0f);               // the fingers say the palm is on the other side
    return true;
}
void HandPose(int s, V3 in, V3 up, float w) {
    if (!g_fingOk[s] || w <= 0.001f) return;
    const float k = clampf(w, 0.0f, 1.0f);
    V3 f, n;
    if (!HandAxes(s, f, n)) return;
    const int h = g_hand[s];
    const V3 fore = norm(sub(g_Ct[h].p, g_Ct[g_larm[s]].p));
    V3 fw = norm(mul(up, -1.0f));
    const float ang = acosf(clampf(dot(fore, fw), -1.0f, 1.0f)) * 57.2957795f;
    if (ang > 70.0f) fw = norm(qrot(qscale(qfromto(fore, fw), 70.0f / ang), fore));
    V3 nw = sub(in, mul(fw, dot(in, fw)));
    if (len(nw) < 0.05f) return;
    nw = norm(nw);
    Q4 R = qnorm(qmul(QuatFromBasis(fw, nw, cross(fw, nw)), qconj(QuatFromBasis(f, n, cross(f, n)))));
    g_lastWrist[s] = qangle(R);
    TurnComp(h, qscale(R, k));
    const float kc = clampf(g_fingerCurl, 0.0f, 1.5f);
    if (kc <= 0.01f || !HandAxes(s, f, n)) return;
    const V3 H = g_Ct[h].p;
    const float curlDeg[3] = { g_curlJoint[0] * kc, g_curlJoint[1] * kc, g_curlJoint[2] * kc };   // (v52) the joints from the ini
    for (int i = 1; i <= 4; i++) {
        const int r = g_fing[s][i][0], m = g_fing[s][i][1], t = g_fing[s][i][2];
        V3 b = sub(g_Ct[r].p, H);
        b = sub(b, mul(n, dot(b, n)));
        if (len(b) < 0.5f) continue;
        b = norm(b);
        const V3 c = norm(cross(b, n));                 // about it, + = toward the palm
        const V3 c0 = sub(g_Ct[m].p, g_Ct[r].p);
        if (len(c0) > 0.3f) TurnComp(r, qscale(qfromto(c0, qrot(qaxis(c, curlDeg[0]), b)), k));
        const V3 c1 = sub(g_Ct[t].p, g_Ct[m].p);
        if (len(c1) > 0.3f) TurnComp(m, qscale(qfromto(c1, qrot(qaxis(c, curlDeg[0] + curlDeg[1]), b)), k));
        const V3 ax = g_L[t].p;                         // (the tip has no child: its long axis is taken as its parent's)
        if (len(ax) > 0.3f) TurnComp(t, qscale(qfromto(qrot(g_Ct[t].q, norm(ax)), qrot(qaxis(c, curlDeg[0] + curlDeg[1] + curlDeg[2]), b)), k));
    }
}

// THE BOARD
void DeckBoard(const void* mesh, const void* anim, int sd, float w) {
    const V3 G = HandLoc(anim, sd);
    const GrabProfile pr = ProfileFor(g_grabKind, sd);
    const V3 up0 = qrot(g_C[g_flipper].q, g_upL);
    if (pr.fixed && g_deckOk && g_dUpOk && g_dFootOk[0] && g_dFootOk[1]) {
        // (v23) TWO 1-DOF LOOPS on the deck as seen against the WORLD horizon: pitch about the deck's lateral axis
        // until the rising end sits `pitch` deg up, roll about its long axis toward level. v17-v22 solved the whole
        // 3-DOF rotation and fed the error to the bone: when the drawn deck answers a bone turn other than 1:1 (the
        // deck reversed under you by the 180's yaw offset answers a pitch the OTHER way; Melon/Indy picked up a roll
        // the bone never gave) that loop wound the bone round the wrong axis to its cap -- the v84 Nose "pitched along
        // the long axis" at 65 deg of tweak with the rising end at 21. A 1-DOF loop cannot roll a board it means to
        // pitch; the sense of the deck's answer comes from the game's deck yaw offset and is checked against what the
        // deck actually does.
        const Q4 mq = qnorm(*(const Q4*)((const uint8_t*)mesh + SC_C2W));
        const V3 u = DeckN();
        V3 ar = sub(g_uFootP[pr.riseFoot], g_uFootP[1 - pr.riseFoot]);
        ar = norm(sub(ar, mul(u, dot(ar, u))));
        const V3 latd = cross(u, ar);
        const Q4 dw = qmul(mq, g_dq);                             // the deck's frame -> the world
        const V3 A = norm(qrot(dw, ar)), L = norm(qrot(dw, latd));
        const float pitchNow = asinf(clampf(A.z, -1.0f, 1.0f)) * 57.2957795f;   // the rising end over the horizon
        const float rollNow = asinf(clampf(L.z, -1.0f, 1.0f)) * 57.2957795f;    // the lateral axis over the horizon (0 = level)
        const float targetP = clampf(pr.pitch, -85.0f, 85.0f) * clampf(w, 0.0f, 1.0f);
        const float errP = targetP - pitchNow;
        // (v29) NO inversion for a reversed deck: in the air the game rebuilds the deck from the Flipper bone itself, so it
        // follows the bone 1:1 either way -- v90's first grab, a reversed Tail steered "the other way", ran off to -60
        // (the base learner then read that as a -105 own pitch and pushed harder). The reversed state still picks the
        // memory slot and turns the foot spots.
        // (v31) ...except that the v92 reversed Indy/Melon went -12/-14 for +10 asked while the reversed Nose hit +25:
        // per kind and state the sense is remembered, checked once per grab after the lag has had its say
        // (v35) THE SENSE CHECK IS GONE. The v96 log: it fired on 25 of 28 grabs with the deck turned round and flipped
        // the steering each time -- it compared how far the deck had MOVED since frame 12 (the pop settling, an
        // overshoot coming back) with the LEVEL of our command, so a deck coming down from +54 to its aim "answered the
        // other way". The next grab then steered backwards: base estimate = now - command ran to its -40 stop, the
        // command to +65, the rising end to -64 ("rockets and dips like crazy"), and the roll loop with it. Every grab
        // that began with sense +1 rose as asked (+22, +42, +54, +36); every one with -1 sank (-14, -37, -33): the
        // deck follows the bone 1:1 whichever way round it lies, and the axes come from the stance.
        if (!g_senseInit) { for (int i = 0; i < GS_N * (ST_N + 1); i++) { g_baseMem[i] = 0.0f; g_baseMemOk[i] = false; } g_senseInit = true; }
        const int hs0 = GrabSlot(g_grabKind);
        const int hs = (hs0 >= 0) ? hs0 + GS_N * ((g_stGrab >= 0 && g_stGrab < ST_N) ? g_stGrab : ST_N) : -1;
        const int sense = 1;
        const float gain = clampf(g_boardEase, 0.01f, 1.0f);
        // (v26) FEED-FORWARD, corrected only at steady state. The drawn deck follows the bone with a lag of ~20 frames
        // (the game's catch-orient smoothing): v23-v25's integrators wound up while it lagged and overshot (the Indy
        // rose to +24 for a 10 aim), and v25's "did it answer the other way" check read the lag as an inverted deck
        // and flipped the loop mid-grab. Now the bone is asked for (target - base), where base = what the deck does
        // on its own (per grab kind, remembered from the last grab's steady state; the deck's pitch at the first frame
        // until then), eased in; the base is re-measured only while the deck is still (no motion for 6 frames), so
        // nothing winds up during the lag. Roll: the same, toward level (v25 had its sign wrong: the Nose rolled to -40).
        // (v27) v26 took "the deck's own pitch" from the grab's FIRST frame -- mid-pop, the tail 65-70 deg down: the
        // Tail was asked for 100, capped at 60, sailed to +73 for 35 and, with the tweak rebuilt each frame round the
        // deck's moving axes, coupled into roll and flapped. Now the base is the previous grab of this kind's LATE
        // estimate (0 until there is one), re-estimated only after the blend and the lag have settled (40 frames
        // in), and the axes are the deck's with our own tweak taken off, so the tweak cannot feed back into itself.
        // (v30) THE LAG, MODELLED. The deck follows the bone through the game's smoothing (~25 frames): v27-v29 took
        // "the deck's own pitch" as (now - our command) at frame 40, when the deck had only part-followed, so a short
        // grab remembered a base 20-37 deg too low and the next grab overshot (v91 Tail: +53, +73 for 35; the
        // 116-149-frame grabs, fully settled, read it right). Now our command is passed through the same lag
        // (cmdLag) and the base is (now - cmdLag) at any time; a slow trim covers a deck that answers with a gain
        // other than 1 (the v91 Melon: +7 for a command of 55). The memory per kind (and reversed state) blends 50%
        // with the grab's estimate, from grabs of 40+ frames only, clamped +-30. The roll: the same estimate, no memory.
        if (!g_pPrevOk) {
            g_memStart = (hs >= 0 && g_baseMemOk[hs]) ? g_baseMem[hs] : 0.0f;
            g_pBaseFrom = (hs >= 0 && g_baseMemOk[hs]) ? 1 : 0;
            g_pBase = g_memStart; g_pBaseEst = g_memStart;
            g_rBase = 0.0f; g_rBaseEst = 0.0f;
            g_pFF = g_rFF = g_trim = g_cmdLag = g_rCmdLag = 0.0f; g_steady = 0; g_grabFrames = 0; g_rI = 0.0f;
            g_pPrev = pitchNow; g_rPrev = rollNow; g_pPrevOk = true;
        }
        g_grabFrames++;
        g_pPrev = pitchNow; g_rPrev = rollNow;
        const float tau = clampf(g_deckLag, 3.0f, 120.0f);
        g_cmdLag += ((g_pFF + g_trim) - g_cmdLag) / tau;         // what the deck has followed of our command so far
        g_rCmdLag += (g_rFF - g_rCmdLag) / tau;
        // (v35) ...and only while the game HOLDS the grab. v30-v34 went on estimating (and remembering) through the
        // release and whatever came after -- a bail's tumbling board, up to 2085 frames of it: the v96 grabs began with
        // a remembered "own pitch" of -30, -22, +20, +40 and shot 17-29 deg past their aim in the first third of a second
        if (g_grabFrames >= 12 && g_holdLive) {                  // (the first frames are the pop)
            g_pBaseEst = clampf(g_pBaseEst + ((pitchNow - g_cmdLag) - g_pBaseEst) * 0.05f, -40.0f, 40.0f);
            g_rBaseEst = clampf(g_rBaseEst + ((rollNow + g_rCmdLag) - g_rBaseEst) * 0.05f, -40.0f, 40.0f);
            g_steady++;
        }
        if (g_grabFrames == 12) g_pStartPitch = pitchNow;
        if (g_grabFrames >= 40 && hs >= 0 && g_holdLive) { g_baseMem[hs] = clampf(0.5f * (g_memStart + g_pBaseEst), -30.0f, 30.0f); g_baseMemOk[hs] = true; }
        g_pBase = (g_grabFrames < 30) ? g_memStart : g_pBaseEst;   // the memory first, the grab's own estimate once it means something
        g_rBase = g_rBaseEst;
        const float capP = fminf(fmaxf(g_tweakMax, 0.0f), fabsf(clampf(pr.pitch, -90.0f, 90.0f)) + 25.0f);
        // (v31) the command goes to the bone at once (0.5/frame): the game's own smoothing eases the deck you see,
        // and the feet ride the drawn deck, not the bone -- v30's 0.12 ease on top of the lag left a 45-frame Tail at +29 of 35
        g_pFF += ((targetP - g_pBase) - g_pFF) * 0.5f;          // the tilt the bone must add
        if (g_grabFrames > 12 && g_holdLive) g_trim = clampf(g_trim + 0.04f * (targetP - pitchNow), -15.0f, 15.0f);   // (v47) from frame 12, twice the gain: the regular Nose sat 10-15 over its aim for 30 frames   // a deck answering with a gain other than 1
        g_rFF += (g_rBase - g_rFF) * 0.5f;                      // level: undo the roll the deck has on its own
        (void)gain;
        g_pI = clampf((g_pFF + g_trim) * (float)sense, -capP, capP);
        // (v47) THE ROLL, STRAIGHT ON THE MEASURED ROLL. v46 flipped the levelling turn's sense -- wrong: the turn is applied in
        // component space and the algebra holds (+t about A raises the lateral axis, so the levelling turn is -rI). What the
        // v45/v46 traces showed was the game's OWN regular Nose pose rolling the deck some 20 deg as the grab blends in,
        // faster than the estimate-then-undo loop (0.05/frame) could follow: the roll grew with a command of 1 behind it,
        // in either sense (v46's guard flipped twice on one grab). So the command now integrates the measured roll's error
        // toward a target every frame, and the target is each grab's own DeckRoll<Grab> (+ = the toe-side edge up, 0 =
        // level), scaled by the grab's weight -- the same number in both stances, the deck held there against the pose.
        {
            float toeL = 0.0f;                                   // which side of the deck the toes point to, along L
            for (int k = 0; k < 2; k++)
                if (g_toe[k] >= 0) toeL += dot(qrot(g_uFootQ[k], qinv(g_C[g_foot[k]].q, sub(g_C[g_toe[k]].p, g_C[g_foot[k]].p))), latd);
            const float tsL = (toeL >= 0.0f) ? 1.0f : -1.0f;
            // (v50) RELATIVE TO THE GAME'S OWN ROLL. v47 held the deck LEVEL by default -- and the game's regular Nose pose rolls
            // the deck some 20 deg so that the hand wraps its edge: held level, the hand lay flat on top of the deck (the user's
            // "flat hand", two versions running). DeckRoll<Grab> is now degrees ADDED to the roll the game's pose gives the deck
            // this frame (our last tweak taken off), 0 = as the game poses it, in either stance; SwDeckRoll<Grab> comes on top in switch
            const Q4 dqGame = qnorm(qmul(qconj(g_tq), g_dq));
            const float rollGame = asinf(clampf(norm(qrot(qmul(mq, dqGame), latd)).z, -1.0f, 1.0f)) * 57.2957795f;
            // (v86) A TWO-HAND GRAB'S DECK IS LEVEL. "The switch cannonball is solid, the normal one is weird: his knees go all
            // crazy -- is anything different between the two?" The deck's own roll: 4 Oct 12:56-12:58, riding switch the game's
            // host grab (the Indy it holds for the crouch) leaves the deck level ('own roll +1' in all three) and the grab ends
            // with the hips 5 cm toward the hands and the back at its Fold; riding regular the same host grab ROLLS the deck 22-29
            // deg in five of nine ('own roll +22 .. +29', board tipped 17-20), the hands' spots go with it, and the body went after
            // them: hips 12 cm down, the back 13-26 deg past its Fold, the hips 16 cm over the board, the back leg folded to 7-12 %
            // of its length with its knee thrown 37-51 cm. For a two-hand grab DeckRoll is measured from LEVEL, in both stances.
            const float rollTarget = rollGame + clampf(GP(g_grabKind, GP_ROLL), -45.0f, 45.0f) * tsL * clampf(w, 0.0f, 1.0f);
            if (!g_rollLevel) g_rI = 0.0f;
            else if (g_holdLive) g_rI = clampf(g_rI + 0.15f * (rollNow - rollTarget), -30.0f, 30.0f);
            else g_rI *= 0.9f;
            g_lastRollTarget = rollTarget;
        }
        // about L by +t: A -> A cos t - U sin t (the rising end DOWN), so the lifting turn is -pI;
        // about A by +t: L -> L cos t + U sin t (L.z UP), so the levelling turn (L.z down by rI) is -rI
        const Q4 dq0 = qnorm(qmul(qconj(g_tq), g_dq));           // the deck as the game has it, our last tweak taken off
        const V3 Lc = norm(qrot(dq0, latd)), Ac = norm(qrot(dq0, ar));   // its axes in component space
        g_tq = qnorm(qmul(qaxis(Lc, -g_pI), qaxis(Ac, -g_rI)));   // (v47) back to the algebra: -rI brings the lateral axis down by rI
        g_lastFitRes = fabsf(errP);
        g_lastDeckPitch = pitchNow;
        g_lastRollNow = rollNow; g_lastSense = sense;
        {                                                // (v36) the grab's tilt over time, every 6th frame (HippieNative.log)
            static LONG lines = 0;
            if ((g_grabFrames % 6) == 1 && InterlockedIncrement(&lines) <= 12000)
                Log("tilt: grab %d frame %d w %.2f %s | rising end %+.1f (aim %+.1f) roll %+.1f (aim %+.1f) | the deck's own: used %+.1f estimate %+.1f | ours %+.1f trim %+.1f, followed %+.1f | to the bone: pitch %+.1f roll %+.1f | catch %d mode %d land %.2f bm %d deck-bone %.0f %s held %ld",
g_grabKind, g_grabFrames, w, g_holdLive ? "held" : "released", pitchNow, targetP, rollNow, g_lastRollTarget, g_pBase, g_pBaseEst, g_pFF, g_trim, g_cmdLag, g_pI, g_rI,
(int)*((const uint8_t*)anim + 0x312), (int)*((const uint8_t*)anim + 0x311), ReadF(anim, 0x600), BoardMCMode(), g_lastDeckOff, DeckReversed() ? "REV" : "norm", g_catchHolds);
        }
    } else if (pr.fixed) {
        // no deck-native data yet (ride a moment first): the open-loop swing of v8
        const V3 upl = qrot(g_C[g_flipper].q, g_upL);
        V3 L = sub(g_C[g_footAnchor[pr.riseFoot]].p, g_C[g_footAnchor[1 - pr.riseFoot]].p);
        L = sub(L, mul(upl, dot(L, upl)));
        const Q4 target = qaxis(norm(cross(L, upl)), clampf(pr.pitch, 0.0f, fmaxf(g_tweakMax, 0.0f)) * clampf(w, 0.0f, 1.0f));
        g_tq = qslerpTo(g_tq, target, clampf(g_boardEase, 0.01f, 1.0f));
        g_lastFitRes = qdiff(g_tq, target);
        g_lastDeckPitch = -1.0f;
    } else {
        V3 fp[2]; Q4 fq[2];
        const bool ok = finite3(G) && DeckFoot(mesh, anim, 0, fp[0], fq[0]) && DeckFoot(mesh, anim, 1, fp[1], fq[1]);
        if (ok) {
            const V3 deckUp = DeckUp();
            const V3 P[3] = { fp[0], fp[1], G };
            V3 Q[3];
            for (int k = 0; k < 2; k++) Q[k] = g_C[g_foot[k]].p;
            Q[2] = sub(g_C[g_hand[sd]].p, mul(deckUp, g_handUp));
            const float W[3] = { 1.0f, 1.0f, fmaxf(g_fitHand, 0.0f) };
            const float ws = W[0] + W[1] + W[2];
            V3 pc = v3(0, 0, 0), qc = v3(0, 0, 0);
            for (int i = 0; i < 3; i++) { pc = add(pc, mul(P[i], W[i] / ws)); qc = add(qc, mul(Q[i], W[i] / ws)); }
            V3 a[3], b[3];
            for (int i = 0; i < 3; i++) { a[i] = sub(P[i], pc); b[i] = sub(Q[i], qc); }
            Q4 R = HornQuat(a, b, W, 3);
            g_lastFitRes = qangle(R);
            if (g_lastFitRes < 90.0f) {                  // (a fit wanting more than 90 = bad points: skip the frame)
                const float gain = clampf(g_fitGain, 0.0f, 0.5f) * clampf(w, 0.0f, 1.0f);
                R = qscale(R, fminf(gain, 3.0f / fmaxf(g_lastFitRes, 1e-3f)));
                g_tq = qnorm(qmul(R, g_tq));
                const float ang = qangle(g_tq);
                const float capF = fminf(fmaxf(g_tweakMax, 0.0f), fmaxf(g_fitCap, 0.0f));   // (v28) Stalefish/Seatbelt wound up to 90
                if (ang > capF && ang > 1e-3f) g_tq = qscale(g_tq, capF / ang);
            }
        }
    }
    if (pr.fixed) {
        // (v16) the profiled grabs take their tweak from the pitch alone -- v12-v15 also lifted the board the full FitMove
        // (15 cm) toward the hand on every grab: the rising end's leg folded to 10-12% of its length (the animation had
        // 23%) -- the Tail "knee clipping". Melon still goes a little down (boned).
        const float want = GP(g_grabKind, GP_LIFT) * clampf(w, 0.0f, 1.0f);   // (v34: each grab's own lift)
        g_tz += (want - g_tz) * clampf(g_boardEase, 0.01f, 1.0f);
    } else
    // the height: the grab spot comes up (or down) to just under the wrist
    if (finite3(G)) {
        const V3 deckUp = qrot(qmul(g_tq, g_C[g_flipper].q), g_upL);
        const float dz = (g_C[g_hand[sd]].p.z - deckUp.z * g_handUp) - G.z;
        const float gain = clampf(g_boardEase, 0.01f, 1.0f) * 0.5f * clampf(w, 0.0f, 1.0f);
        g_tz = clampf(g_tz + dz * gain, -fmaxf(g_fitMove, 0.0f), fmaxf(g_fitMove, 0.0f));
    }
    const int fl = g_flipper;
    TurnComp(fl, g_tq);
    SetComp(fl, g_Ct[fl].q, add(g_Ct[fl].p, v3(0, 0, g_tz)));
    g_lastPull = g_tz;
}
void DeckRelax() {                             // no grab: the held tweak lets go
    g_tq = qslerpTo(g_tq, q4(0, 0, 0, 1), 0.15f);
    g_tz *= 0.85f;
}
bool DeckHeld() { return qangle(g_tq) > 0.3f || fabsf(g_tz) > 0.2f; }

// obstacles the grabbing arm must go round: both legs (thigh, shin, foot) and the drawn deck's long line
constexpr int kMaxObstacles = 12;              // callers' seg/rad buffers hold this many (9 are filled)
int Obstacles(const void* anim, V3 (*seg)[2], float* rad) {
    int n = 0;
    for (int k = 0; k < 2; k++) {
        // (v34) the legs as they ENDED UP last frame: the arms are solved before the legs, so g_Ct still holds the
        // animation's legs here -- v8-v33 steered the elbow round legs that were about to move (the v95 audit: the
        // grabbing arm 8-12 cm inside its own side's shin and thigh)
        const V3 T = g_legPrevOk ? g_legPrev[k * 3].a : g_Ct[g_thigh[k]].p, K = g_legPrevOk ? g_legPrev[k * 3].b : g_Ct[g_calf[k]].p;
        const V3 F = g_legPrevOk ? g_legPrev[k * 3 + 1].b : g_Ct[g_foot[k]].p;
        const V3 To = g_legPrevOk ? g_legPrev[k * 3 + 2].b : (g_toe[k] >= 0 ? g_Ct[g_toe[k]].p : F);
        seg[n][0] = T; seg[n][1] = K; rad[n++] = 9.0f;
        seg[n][0] = K; seg[n][1] = F; rad[n++] = 8.0f;
        if (g_toe[k] >= 0) {
            seg[n][0] = F; seg[n][1] = To; rad[n++] = 7.0f;
            // (v19) the heel, behind the ankle (the Tail hand clipped the back foot's heel on the tail)
            seg[n][0] = F; seg[n][1] = sub(F, mul(sub(To, F), 0.5f)); rad[n++] = 6.0f;
        }
    }
    const V3 a = ReadV3(anim, AI_LFOOT_LOC), b = ReadV3(anim, AI_RFOOT_LOC);
    if (finite3(a) && finite3(b) && len(sub(a, b)) > 5.0f) {
        const V3 c = mul(add(a, b), 0.5f), d = norm(sub(a, b));
        seg[n][0] = add(c, mul(d, 38.0f)); seg[n][1] = sub(c, mul(d, 38.0f)); rad[n++] = 11.0f;
    }
    return n;
}

// (v17) the searches below are SMOOTHED: v8-v16 took each frame's best of discrete 15-deg steps, and neighbouring
// options won alternate frames -- the knees "jumping around" / "wiggling" and the elbow flipping +-120. Now a choice
// costs extra the further it is from what is held, and the held values move only 30% of the way per frame.
float g_armThS[2] = { 0, 0 };                          // held elbow swing per arm (deg)
float g_legThS[2] = { 0, 0 }, g_legRollS[2] = { 0, 0 }, g_legHeelS[2] = { 0, 0 };   // held knee swing / signed roll / heel per leg
void SearchReset() { for (int i = 0; i < 2; i++) { g_armThS[i] = g_legThS[i] = g_legRollS[i] = g_legHeelS[i] = 0.0f; } }

// the arm, with the elbow's side searched round the shoulder-wrist line for clearance
float ArmSearch(int sd, V3 Hh, const void* anim) {
    const int ua = g_uarm[sd], la = g_larm[sd], ha = g_hand[sd];
    const V3 S = g_Ct[ua].p;
    const float a1 = len(sub(g_Ct[la].p, S)), a2 = len(sub(g_Ct[ha].p, g_Ct[la].p));
    V3 p0 = norm(sub(g_Ct[la].p, add(S, mul(sub(g_Ct[ha].p, S), 0.5f))));
    if (g_chest >= 0 && g_elbowOut > 0.0f) {
        const V3 out = flat(sub(S, g_Ct[g_chest].p));
        if (len(out) > 1.0f) p0 = norm(add(p0, mul(norm(out), g_elbowOut)));
    }
    const V3 d = sub(Hh, S); const float dl = len(d);
    if (dl > (a1 + a2) * 0.98f) Hh = add(S, mul(d, (a1 + a2) * 0.98f / dl));
    {                                                        // (v48) Elbow<Grab>: the search starts from the swung side (see Arm)
        const float swivel = GP(g_grabKind, GP_ELBOW);
        if (fabsf(swivel) > 0.01f && dl > 1.0f) p0 = norm(qrot(qaxis(mul(d, 1.0f / dl), swivel), p0));
    }
    // 2 legs x (thigh, shin, foot, heel) + the deck = 9 entries: v19 added the heel to 8-entry buffers and the
    // first grab overran the stack (the /GS check kills the process on the spot -- no crash report at all)
    V3 seg[12][2]; float rad[12];
    const int n = Obstacles(anim, seg, rad);
    const V3 axis = norm(sub(Hh, S));
    const V3 ref = ArmSide(sd);                          // (v54) the elbow's side
    // Indy (v11): the back hand reaches BETWEEN the legs (the legs step aside in LegSearch); Tail (v17): the back hand
    // goes round OUTSIDE the back leg ("hands stuck between his knees ... almost like going for an indy")
    // (v34) by the grab's profile -- all 12 grabs; "between" no longer ignores the legs (it went straight through
    // them): they count, 2 cm slimmer, and the knees are splayed to make the room
    const GrabProfile prA = ProfileFor(g_grabKind, sd);
    const bool between = (prA.route == 1), outside = (prA.route == 2);
    const V3 gap = lerp(mul(add(g_Ct[g_calf[0]].p, g_Ct[g_calf[1]].p), 0.5f), mul(add(g_Ct[g_foot[0]].p, g_Ct[g_foot[1]].p), 0.5f), 0.4f);
    float best = 1e9f, bClear = 1e9f, bTh = 0.0f;
    for (int t = -8; t <= 8; t++) {
        const float th = 15.0f * (float)t;
        const V3 pc = qrot(qaxis(axis, th), p0);
        const V3 E = MidJoint(S, Hh, a1, a2, pc);
        const V3 Fa = lerp(E, Hh, outside ? 0.9f : 0.75f);   // the forearm up to near the wrist (Tail: nearly all of it)
        float pen = 0.0f, clear = 1e9f;
        for (int i = 0; i < n; i++) {
            V3 c1, c2;
            const float rr = rad[i] + ((rad[i] < 10.5f) ? (outside ? 3.0f : between ? -2.0f : 0.0f) : 0.0f);
            const float d1 = SegSeg(S, E, seg[i][0], seg[i][1], c1, c2) - rr;
            const float d2 = SegSeg(E, Fa, seg[i][0], seg[i][1], c1, c2) - rr;
            const float m = fminf(d1, d2);
            clear = fminf(clear, m);
            if (m < 3.0f) pen += (3.0f - m) * 6.0f;
        }
        float cost = pen + (outside ? 0.25f : 0.08f) * fabsf(th) + 0.12f * fabsf(th - g_armThS[sd]);
        if (dot(norm(pc), ref) < kArmSideCos) cost += 500.0f;   // (v54) a backwards elbow is no answer
        const float dg = len(sub(lerp(E, Fa, 0.5f), gap));
        if (between) cost += 0.3f * dg;
        if (outside && dg < 24.0f) cost += (24.0f - dg) * 1.5f;
        if (cost < best) { best = cost; bClear = clear; bTh = th; }
    }
    g_armThS[sd] += (bTh - g_armThS[sd]) * 0.3f;
    const V3 E = MidJoint(S, Hh, a1, a2, HoldToSide(qrot(qaxis(axis, g_armThS[sd]), p0), ref, sd));   // (v54)
    AimBone(ua, sub(g_Ct[la].p, S), sub(E, S));
    AimBone(la, sub(g_Ct[ha].p, g_Ct[la].p), sub(Hh, g_Ct[la].p));
    g_lastArmClear = bClear; g_lastArmSwing = g_armThS[sd];
    return a1 + a2;
}

// a leg: knee swing round the hip-ankle line x heel lift over the toe, with the foot ROLLED onto a sole edge
// (v34) rollS = the roll, signed (+ inner edge, toward the other foot; - outer edge) -- FORCED now, not searched: v8-v33
// let the search trade it against the ankle's angle and the foot mostly stayed flat ("it's always flat");
// splay = how far the knee would like to stand OUT from the other leg (deg round the hip-ankle line), and the
// other leg counts as an obstacle (the v95 audit: thigh in thigh 15 cm, shin in thigh 13 -- "knees always hitting")
void LegSearch(int k, V3 F, Q4 fq, const float* wh, float rollS, float splay) {
    const int th = g_thigh[k], ca = g_calf[k], ft = g_foot[k], to = g_toe[k];
    const V3 S = g_Ct[th].p;
    const float a1 = len(sub(g_Ct[ca].p, S)), a2 = len(sub(g_Ct[ft].p, g_Ct[ca].p));
    const V3 p0 = norm(sub(g_C[ca].p, add(g_C[th].p, mul(sub(g_C[ft].p, g_C[th].p), 0.5f))));
    const V3 cLocal = qinv(g_C[ft].q, norm(sub(g_C[ft].p, g_C[ca].p)));
    const V3 tLocal = (to >= 0) ? qinv(g_C[ft].q, sub(g_C[to].p, g_C[ft].p)) : v3(0.0f, 12.0f, 0.0f);
    const V3 up = DeckUp();
    // the sole: the toe direction on the deck, the side toward the other foot, the ankle's height over the grip
    V3 fwd = sub(qrot(fq, tLocal), mul(up, dot(qrot(fq, tLocal), up)));
    fwd = norm(fwd);
    V3 inward = sub(g_Ct[g_foot[1 - k]].p, F);
    inward = sub(inward, mul(up, dot(inward, up)));
    inward = sub(inward, mul(fwd, dot(inward, fwd)));
    inward = norm(inward);
    const float hAnk = clampf(dot(qinv(g_C[g_flipper].q, sub(g_C[ft].p, g_C[g_flipper].p)), g_upL), 3.0f, 15.0f);
    // the foot for a signed roll (+ inner edge, - outer) and a heel lift
    auto footFor = [&](float rollS, float heel, V3& Fo, Q4& qo) {
        Fo = F; qo = fq;
        const float roll = fabsf(rollS);
        if (roll > 0.05f) {                      // roll onto the edge: pivot on it, the other edge lifts
            const float side = (rollS >= 0.0f) ? 1.0f : -1.0f;
            const V3 E = add(sub(F, mul(up, hAnk)), mul(inward, 4.5f * side));
            Q4 Rr = qaxis(fwd, roll);
            const V3 other = add(sub(F, mul(up, hAnk)), mul(inward, -4.5f * side));
            if (dot(sub(qrot(Rr, sub(other, E)), sub(other, E)), up) < 0.0f) Rr = qaxis(fwd, -roll);
            Fo = add(E, qrot(Rr, sub(F, E)));
            qo = qnorm(qmul(Rr, fq));
        }
        if (heel > 0.05f) {                      // lift the heel over the toe: the ankle rises, the toe stays put
            const V3 T = add(Fo, qrot(qo, tLocal));
            const V3 fw = norm(sub(T, Fo));
            const V3 lat = norm(cross(up, fw));
            Q4 Rh = qaxis(lat, heel);
            if (dot(sub(qrot(Rh, sub(Fo, T)), sub(Fo, T)), up) < 0.0f) Rh = qaxis(lat, -heel);
            const V3 F1 = Fo;
            Fo = add(T, qrot(Rh, sub(F1, T)));
            qo = qnorm(qmul(Rh, qo));
        }
    };
    V3 armA[2][3]; int arms = 0;
    for (int s = 0; s < 2; s++)
        if (wh[s] > 0.001f) { armA[arms][0] = g_Ct[g_uarm[s]].p; armA[arms][1] = g_Ct[g_larm[s]].p; armA[arms][2] = g_Ct[g_hand[s]].p; arms++; }
    // the other leg, as it ended up last frame (this frame's is not solved yet when k = 0)
    const int o = 1 - k;
    const V3 oT = g_legPrevOk ? g_legPrev[o * 3].a : g_Ct[g_thigh[o]].p, oK = g_legPrevOk ? g_legPrev[o * 3].b : g_Ct[g_calf[o]].p;
    const V3 oF = g_legPrevOk ? g_legPrev[o * 3 + 1].b : g_Ct[g_foot[o]].p;
    const float rollUse = clampf(rollS * clampf(g_edgeRoll, 0.0f, 2.0f), -70.0f, 70.0f);
    // which way round the hip-ankle line takes this knee AWAY from the other one
    float outSign = 1.0f;
    {
        V3 F0; Q4 q0;
        footFor(rollUse, 0.0f, F0, q0);
        const V3 ax = norm(sub(F0, S));
        const V3 Kp = MidJoint(S, F0, a1, a2, qrot(qaxis(ax, 20.0f), p0)), Kn = MidJoint(S, F0, a1, a2, qrot(qaxis(ax, -20.0f), p0));
        outSign = (len(sub(Kp, oK)) >= len(sub(Kn, oK))) ? 1.0f : -1.0f;
    }
    const float pref = outSign * clampf(splay, -75.0f, 75.0f);
    float best = 1e9f, bTh = 0.0f, bHeel = 0.0f;
    const int heels = (to >= 0 && g_heelMax > 0.0f) ? 4 : 1;
    for (int h = 0; h < heels; h++) {
        const float heel = g_heelMax * (float)h / 3.0f;
        V3 F2; Q4 q2;
        footFor(rollUse, heel, F2, q2);
        const V3 axis = norm(sub(F2, S));
        for (int t = -6; t <= 6; t++) {
            const float thDeg = 15.0f * (float)t;
            const V3 K = MidJoint(S, F2, a1, a2, qrot(qaxis(axis, thDeg), p0));
            const V3 shin = norm(sub(F2, K));
            const float err = acosf(clampf(dot(shin, qrot(q2, cLocal)), -1.0f, 1.0f)) * 57.2957795f;
            float clear = 1e9f;
            for (int i = 0; i < arms; i++)
                for (int j = 0; j < 2; j++) {
                    V3 c1, c2;
                    clear = fminf(clear, SegSeg(armA[i][j], armA[i][j + 1], S, K, c1, c2));
                    clear = fminf(clear, SegSeg(armA[i][j], armA[i][j + 1], K, F2, c1, c2));
                }
            float legClear = 1e9f;
            {
                V3 c1, c2;
                const V3 Sm = lerp(S, K, 0.5f), oTm = lerp(oT, oK, 0.5f);      // (the hip ends always stand close)
                legClear = fminf(legClear, SegSeg(Sm, K, oTm, oK, c1, c2));
                legClear = fminf(legClear, SegSeg(Sm, K, oK, oF, c1, c2));
                legClear = fminf(legClear, SegSeg(K, F2, oTm, oK, c1, c2));
                legClear = fminf(legClear, SegSeg(K, lerp(K, F2, 0.7f), oK, lerp(oK, oF, 0.7f), c1, c2));   // (the ankles stand where the deck has them)
            }
            const float cost = err * 0.7f + 0.12f * fabsf(thDeg - pref) + 0.35f * heel
                             + (clear < 12.0f ? (12.0f - clear) * 5.0f : 0.0f)
                             + (legClear < 17.0f ? (17.0f - legClear) * 3.0f : 0.0f)
                             + 0.2f * (fabsf(thDeg - g_legThS[k]) + fabsf(heel - g_legHeelS[k]));
            if (cost < best) { best = cost; bTh = thDeg; bHeel = heel; }
        }
    }
    // held values glide toward the choice; the leg is solved with the held values
    g_legThS[k] += (bTh - g_legThS[k]) * 0.3f;
    g_legRollS[k] += (rollUse - g_legRollS[k]) * 0.3f;
    g_legHeelS[k] += (bHeel - g_legHeelS[k]) * 0.3f;
    V3 Fs; Q4 qs;
    footFor(g_legRollS[k], g_legHeelS[k], Fs, qs);
    const V3 pole = qrot(qaxis(norm(sub(Fs, S)), g_legThS[k]), p0);
    Leg(k, Fs, qs, v3(0, 0, 0), &pole);
    // the toe stays flat on the deck (as it sat on the unlifted foot): the toe joint bends instead
    if (to >= 0 && g_legHeelS[k] > 0.5f) SetComp(to, qnorm(qmul(fq, qmul(qconj(g_C[ft].q), g_C[to].q))), g_Ct[to].p);
    {
        const V3 Kf = g_Ct[ca].p;
        g_lastAnkle[k] = acosf(clampf(dot(norm(sub(Fs, Kf)), qrot(qs, cLocal)), -1.0f, 1.0f)) * 57.2957795f;
    }
    g_lastPlant[k] = len(sub(g_Ct[ft].p, Fs));
    g_lastHeel[k] = g_legHeelS[k]; g_lastSwing[k] = g_legThS[k]; g_lastRoll[k] = g_legRollS[k];
}

// THE FEET: on the drawn deck (eased in by the grab weight); a foot without a learned offset is left alone
void DeckLegs(const void* mesh, const void* anim, const float* w, const float* wh) {
    const float wf = clampf(fmaxf(w[0], w[1]) * 1.5f, 0.0f, 1.0f);
    const int sd = IsDouble(g_grabKind) ? (g_dblFront ? 1 : 0) : (w[1] > w[0]) ? 1 : 0;
    const GrabProfile pr = ProfileFor(g_grabKind, sd);
    for (int k = 0; k < 2; k++) {
        V3 p; Q4 q;
        if (!DeckFoot(mesh, anim, k, p, q)) { g_lastPlant[k] = -1.0f; continue; }
        // (v19) a grab on a tip: the foot on the grabbed end slides off it, out of the hand's way (v34: each grab's own)
        // (v35) Cannonball: both ends are grabbed, both feet come in; Rocket: the front foot goes back to the tail
        const float slide = GP(g_grabKind, GP_SLIDE);
        if (pr.fixed && slide > 0.0f) {
            const bool noseHeld = (g_grabKind == 200 || g_grabKind == 202) || (!IsDouble(g_grabKind) && pr.spot == 1);
            const bool tailHeld = (g_grabKind == 200) || (!IsDouble(g_grabKind) && pr.spot == 2);
            V3 a, lat;
            if (DeckAxes(pr.frontFoot, a, lat)) {
                if (k == pr.frontFoot && noseHeld) p = add(p, qrot(g_dq, mul(a, -slide)));
                if (k == 1 - pr.frontFoot && tailHeld) p = add(p, qrot(g_dq, mul(a, slide)));
            }
        }
        const V3 F = lerp(g_Ct[g_foot[k]].p, p, wf);
        const Q4 fq = qslerpTo(g_Ct[g_foot[k]].q, q, wf);
        g_lastFeetDeck[k] = len(sub(p, g_C[g_foot[k]].p));
        const bool front = (k == pr.frontFoot);
        const float rollS = (front ? pr.frontRoll : pr.backRoll) * wf;
        const float splay = (front ? GP(g_grabKind, GP_SPLAYF) : GP(g_grabKind, GP_SPLAYB)) * wf;
        if (g_legSearch) LegSearch(k, F, fq, wh, rollS, splay);
        else g_lastFootMiss[k] = Leg(k, F, fq);
        if (g_deckOk) {                          // (v14) how high the foot bone ends up over the drawn deck vs how it rode
            g_lastFootH[k] = dot(qinv(g_dq, sub(g_Ct[g_foot[k]].p, g_dp)), DeckN());
            g_learnFootH[k] = g_dFootOk[k] ? dot(g_uFootP[k], DeckN()) : -99.0f;
        }
    }
}

// ------------------------------------------------------------------ (v33) THE LIMB AUDIT
// Every posed grab frame, on the FINAL pose: how deep each pair of body parts (capsules) and each part and the deck
// (a box) run into each other. Per grab: each pair's deepest overlap, for how many frames, and when. Reported when
// the grab ends (HippieNative.log, and HJN_Collisions() for the Lua log) -- the numbers each grab is polished by.
constexpr int CP_N = 16;                       // 0-2 L arm, 3-5 R arm, 6-8 L leg, 9-11 R leg, 12 torso, 13 hips, 14 head, 15 deck
const char* const kPart[CP_N] = { "L upper arm", "L forearm", "L hand", "R upper arm", "R forearm", "R hand",
                                  "L thigh", "L shin", "L foot", "R thigh", "R shin", "R foot", "torso", "hips", "head", "deck" };
float g_colMax[CP_N][CP_N]; int g_colFrames[CP_N][CP_N], g_colAt[CP_N][CP_N];
int   g_colN = 0, g_colKind = 0, g_colHand = 0; LONG g_colSeq = 0;
char  g_colReport[1600] = "";
void CollideReset() {
    for (int i = 0; i < CP_N; i++) for (int j = 0; j < CP_N; j++) { g_colMax[i][j] = 0.0f; g_colFrames[i][j] = 0; g_colAt[i][j] = 0; }
    g_colN = 0;
}
void ColNote(int i, int j, float depth) {
    if (depth <= 0.5f) return;
    if (i > j) { const int t = i; i = j; j = t; }
    g_colFrames[i][j]++;
    if (depth > g_colMax[i][j]) { g_colMax[i][j] = depth; g_colAt[i][j] = g_colN; }
}
void BuildCaps(Cap* c) {
    for (int i = 0; i < CP_N; i++) { c[i].a = c[i].b = v3(0, 0, 0); c[i].r = 0.0f; c[i].ok = false; }
    for (int s = 0; s < 2; s++) {
        const V3 S = g_Ct[g_uarm[s]].p, E = g_Ct[g_larm[s]].p, H = g_Ct[g_hand[s]].p;
        c[s * 3 + 0] = { S, E, 4.5f, true };
        c[s * 3 + 1] = { E, H, 3.8f, true };
        c[s * 3 + 2] = { H, add(H, mul(norm(sub(H, E)), 9.0f)), 3.5f, true };
        const V3 T = g_Ct[g_thigh[s]].p, K = g_Ct[g_calf[s]].p, F = g_Ct[g_foot[s]].p;
        c[6 + s * 3 + 0] = { T, K, 7.5f, true };
        c[6 + s * 3 + 1] = { K, F, 5.5f, true };
        c[6 + s * 3 + 2] = { F, g_toe[s] >= 0 ? g_Ct[g_toe[s]].p : add(F, v3(0, 0, -5.0f)), 4.5f, true };
    }
    if (g_spine1 >= 0 && g_chest >= 0) {
        const V3 a = g_Ct[g_spine1].p, b = g_Ct[g_chest].p;
        c[12] = { a, add(b, mul(norm(sub(b, a)), 8.0f)), 12.0f, true };
    }
    if (g_pelvis >= 0) c[13] = { g_Ct[g_pelvis].p, g_Ct[g_pelvis].p, 11.0f, true };
    if (g_head >= 0 && g_neck >= 0) {
        const V3 h = add(g_Ct[g_head].p, mul(norm(sub(g_Ct[g_head].p, g_Ct[g_neck].p)), 8.0f));
        c[14] = { h, h, 9.5f, true };
    }
}
bool PairOn(int i, int j) {                    // i < j, neither the deck; joints that always meet are left out
    const bool ai = i < 6, aj = j < 6, li = i >= 6 && i < 12, lj = j >= 6 && j < 12;
    if (ai && aj) return (i / 3) != (j / 3) && (i % 3) != 0 && (j % 3) != 0;   // forearms and hands of the two arms
    if (ai && lj) return true;                                                  // arm x leg
    if (li && lj) return ((i - 6) / 3) != ((j - 6) / 3);                        // leg x the other leg
    if (ai && j == 12) return (i % 3) != 0;                                     // forearm, hand x torso
    if (ai && (j == 13 || j == 14)) return true;                                // arm x hips, head
    if (li && j == 12) return true;                                             // leg x torso (a thigh by its knee half)
    if (li && j == 13) return ((i - 6) % 3) != 0;                               // shin, foot x hips
    if (li && j == 14) return true;                                             // leg x head
    return false;
}
void SegFor(const Cap* c, int i, int other, V3& a, V3& b) {
    a = c[i].a; b = c[i].b;
    if ((i == 6 || i == 9) && (other == 12 || other == 6 || other == 9)) a = lerp(c[i].a, c[i].b, 0.5f);   // (the hip end always meets the body)
}
void CollideAudit(int sdGrab, bool both, const Cap* c) {
    g_colN++; g_colKind = g_grabKind; g_colHand = both ? 2 : sdGrab;
    for (int i = 0; i < 15; i++) {
        if (!c[i].ok) continue;
        for (int j = i + 1; j < 15; j++) {
            if (!c[j].ok || !PairOn(i, j)) continue;
            V3 a1, b1, a2, b2, x, y;
            SegFor(c, i, j, a1, b1); SegFor(c, j, i, a2, b2);
            ColNote(i, j, c[i].r + c[j].r - SegSeg(a1, b1, a2, b2, x, y));
        }
    }
    if (g_deckOk) {                              // parts x the deck (a box in its own frame); not the feet, not the grabbing hand
        const V3 bc = v3(CentreX(), 0.0f, g_lastTop - 1.0f), bh = v3(HalfLen(), HalfWidth(), 1.0f);
        for (int i = 0; i < 15; i++) {
            const bool grabHand = (i == sdGrab * 3 + 2) || (both && (i == 2 || i == 5));
            const bool grabFore = (i == sdGrab * 3 + 1) || (both && (i == 1 || i == 4));
            if (!c[i].ok || i == 8 || i == 11 || grabHand) continue;
            const float tmax = (i == 7 || i == 10) ? 0.7f : grabFore ? 0.8f : 1.0f;   // (the ankle stands on it, the wrist holds it)
            float worst = 0.0f;
            for (int n = 0; n <= 6; n++) {
                const V3 p = sub(qinv(g_dq, sub(lerp(c[i].a, c[i].b, (float)n / 6.0f * tmax), g_dp)), bc);
                const V3 q = v3(fabsf(p.x) - bh.x, fabsf(p.y) - bh.y, fabsf(p.z) - bh.z);
                const float out = len(v3(fmaxf(q.x, 0.0f), fmaxf(q.y, 0.0f), fmaxf(q.z, 0.0f))) + fminf(fmaxf(q.x, fmaxf(q.y, q.z)), 0.0f);
                worst = fmaxf(worst, c[i].r - out);
            }
            ColNote(i, 15, worst);
        }
    }
}
void CollideReport() {
    int bi[8], bj[8]; float bd[8]; int n = 0;
    for (int i = 0; i < CP_N; i++)
        for (int j = i + 1; j < CP_N; j++) {
            const float d = g_colMax[i][j];
            if (d < 1.5f || g_colFrames[i][j] < 3) continue;     // (v34: a frame or two is the landing, not the grab)
            int k;
            if (n < 8) k = n++; else { if (bd[7] >= d) continue; k = 7; }
            while (k > 0 && bd[k - 1] < d) { bi[k] = bi[k - 1]; bj[k] = bj[k - 1]; bd[k] = bd[k - 1]; k--; }
            bi[k] = i; bj[k] = j; bd[k] = d;
        }
    const long seq = InterlockedIncrement(&g_colSeq);
    int o = snprintf(g_colReport, sizeof(g_colReport), "#%ld grab %d (%s), %d frames: ", seq, g_colKind,
                     g_colHand == 2 ? "both hands" : g_colHand ? "R hand" : "L hand", g_colN);
    if (n == 0 && o > 0 && o < (int)sizeof(g_colReport)) snprintf(g_colReport + o, sizeof(g_colReport) - o, "no overlap over 1.5 cm");
    for (int k = 0; k < n && o > 0 && o < (int)sizeof(g_colReport) - 80; k++)
        o += snprintf(g_colReport + o, sizeof(g_colReport) - o, "%s%s x %s %.0f cm (%d frames, deepest at frame %d)", k ? "; " : "",
                      kPart[bi[k]], kPart[bj[k]], bd[k], g_colFrames[bi[k]][bj[k]], g_colAt[bi[k]][bj[k]]);
    Log("limbs: %s", g_colReport);
}

// (v33) THE HAND'S WAY TO THE BOARD. v3-v32 moved the wrist in a straight line from where the animation had it to the
// grab spot -- through whatever lay between. Now (a) each grab may have a VIA point (HJN_HandVia: cm along / toward
// the toes / up in the deck's frame, off the middle of that line) which the path bends through, and (b) the wrist
// is pushed out of the legs on its way (handavoid), fading out as it arrives at the spot.
volatile int g_handAvoid = 1;                  // HJN_Set("handavoid", 0/1)
V3 HandPath(int s, int sd, V3 hand, V3 tgt, float t) {
    t = clampf(t, 0.0f, 1.0f);
    V3 p = lerp(hand, tgt, t);
    if (s != sd) return p;
    const int hs = GrabSlot(g_grabKind);
    const GrabProfile pr = ProfileFor(g_grabKind, sd);
    const int v0 = pr.set2 ? GP_VIAA2 : GP_VIAA;       // (v35) a two-hand grab's back hand has its own via point
    const float g_via[1][3] = { { GP(g_grabKind, v0), GP(g_grabKind, v0 + 1), GP(g_grabKind, v0 + 2) } };   // (v34: in g_gp)
    if (hs >= 0 && g_deckOk && (fabsf(g_via[0][0]) + fabsf(g_via[0][1]) + fabsf(g_via[0][2])) > 0.1f) {
        V3 a, lat;
        if (DeckAxes(pr.frontFoot, a, lat)) {
            float toe = 0.0f;
            for (int k = 0; k < 2; k++)
                if (g_toe[k] >= 0) toe += dot(qrot(g_uFootQ[k], qinv(g_C[g_foot[k]].q, sub(g_C[g_toe[k]].p, g_C[g_foot[k]].p))), lat);
            const float ts = (toe >= 0.0f) ? 1.0f : -1.0f;
            const V3 off = qrot(g_dq, add(add(mul(a, g_via[0][0]), mul(lat, g_via[0][1] * ts)), mul(DeckN(), g_via[0][2])));
            const V3 ctrl = add(lerp(hand, tgt, 0.5f), mul(off, 2.0f));   // so the curve's middle passes through (middle + off)
            const float u = 1.0f - t;
            p = add(add(mul(hand, u * u), mul(ctrl, 2.0f * u * t)), mul(tgt, t * t));
        }
    }
    if (g_handAvoid && g_legPrevOk) {
        V3 q = p;
        for (int i = 0; i < 6; i++) {
            V3 c1, c2;
            const float R = g_legPrev[i].r + 4.0f;
            const float d = SegSeg(q, q, g_legPrev[i].a, g_legPrev[i].b, c1, c2);
            if (d < R) q = add(c2, mul(d > 0.5f ? mul(sub(q, c2), 1.0f / d) : DeckUp(), R));
        }
        p = lerp(p, q, clampf(1.0f - t * t, 0.0f, 1.0f));
    }
    return p;
}

void TraceLines(const void* mesh, const void* anim) {
    g_trYaw[0] = yawOf(sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p));
    g_trYaw[1] = yawOf(sub(g_Ct[g_uarm[0]].p, g_Ct[g_uarm[1]].p));
    g_trYaw[2] = yawOf(sub(g_Ct[g_foot[0]].p, g_Ct[g_foot[1]].p));
    g_trYaw[3] = yawOf(sub(g_Ct[g_footAnchor[0]].p, g_Ct[g_footAnchor[1]].p));
    g_trYaw[4] = yawOf(sub(ReadV3(anim, AI_LFOOT_LOC), ReadV3(anim, AI_RFOOT_LOC)));
    g_trYaw[5] = MeshYaw(mesh);
}

// our mesh's finished pose: the 180 guard, then the grab (board tweak + pull, lean, arms, feet, knees).
// POD only: it runs inside __try.
// ==== (v71) THE PLANT FOOT STAYS DOWN =================================================================================
// The traces of 18:28: the game lifts the SKATER the instant a no comply pops -- the mesh root is 29 cm up after 0.09 s,
// 78 cm after 0.25 s, 104 cm at 0.44 s -- while the board only starts rising at 0.1 s. The animation's planted foot is
// carried up with the root: 0.15 s in it hangs in the air ("the plant foot gets too high off the ground ... only when the
// board reaches the apex should that foot leave the ground"), and with a hand on the board the whole skater floats over it
// ("the feet come off the board, a couple of feet in the air"). While the Lua holds the window (HJN_Set("plant", seconds)):
// the first foot the animation puts on the ground is THE plant foot; it is kept on the ground under where the animation has
// it, and the hips are kept down as far as that leg needs to reach it -- at most g_plantMax cm. When they would have to
// come down further (the skater is that high by then: about when the board stands up, 0.3 s in) the foot PUSHES OFF: over
// nine poses the hips rise to where the game has them and the foot goes to the animation's, on its way back to the board.
volatile ULONGLONG g_plantUntil = 0; volatile float g_plantMax = 45.0f;
int g_plantFoot = -1; float g_plantW = 0.0f, g_plantD = 0.0f, g_plantMost = 0.0f; bool g_plantRel = false; LONG g_plantFrames = 0;
float g_plantDeck0 = -1e9f, g_plantDeckMax = -1e9f;   // (v72) the drawn deck's height when the foot went down, and its highest since
// (v73) THE FOOT STEPS ON AT THE BOARD'S TOP. v72 let the foot go when the deck had already dropped a centimetre and faded it,
// over nine poses, to the ANIMATION's foot -- which stays near the ground until the landing (the trace of 19:13:56: the deck
// at its top 0.34-0.39 s in, the foot let go at 0.41, back on the board at 0.55 -- as the wheels came down: "it's staying
// almost to the end"). Now the plant has stages: 1 the foot on the ground; 2 the STEP -- from the moment the deck's rise
// slows to g_plantLead cm/s the foot goes, in g_plantStepS seconds, from the ground to ITS OWN RIDING SPOT on the drawn deck
// (round the board's edge, not through the deck), the hips coming up as it goes; then both feet stay on their spots until
// the Lua's window ends, and go back to the animation's over nine poses.
int g_plantStage = 0; bool g_plantDone = false, g_plantHaveT = false;
float g_plantU = 0.0f, g_plantVz = 0.0f, g_plantPrevZ = 0.0f, g_plantGz = 0.0f, g_plantD0 = 0.0f, g_plantStepMs = -1.0f;
double g_plantPrevT = 0.0, g_plantStepT0 = 0.0, g_plantT0 = 0.0; LONG g_plantTold = 0;
volatile float g_plantStepS = 0.10f, g_plantLead = 60.0f, g_plantHump = 6.0f, g_plantBulge = 12.0f;
// (v74) v73 took "the rise is slower than g_plantLead" for the top -- but the deck STARTS slowly (85 cm/s when it had risen
// 8 cm, 0.17 s in; 400 cm/s at 0.27 s; its top at 0.40 s): the foot left the ground 0.23 s early, every time ("releasing
// before the apex, even returning to the board before the apex"). The rise has to have been fast first.
float g_plantVzMax = 0.0f;
// (v75) "The front foot goes down too far back, and when it tries to catch up with the board it scoops forward through the
// ground instead of just lifting": the animation's planted foot drifts 40 cm back along the board while it is down (the
// trace of 20:11:48: +8 cm along the deck at the pop, -33 at the step) -- the ground going by under a rider it was made
// for. Its drift ALONG THE BOARD (the deck's long axis as it lay when the foot went down) is cut to g_plantBack of that;
// the step to the side, off the board, is kept. The step back on is then nearly straight up.
volatile float g_plantBack = 0.0f; V3 g_plantX0 = { 0, 0, 0 }, g_plantAx = { 1, 0, 0 }; bool g_plantAxOk = false, g_plantTurned0 = false;
// (v76) "It's sliding along the ground. It needs to lift up vertically": the planted foot followed the animation's (30 % of
// its drift along the board, all of its 13 cm sideways wander) and the step back on was a slant. Now the foot STAYS WHERE IT
// WENT DOWN -- a fixed offset from the skater, in the world's axes (a turning body pivots over it), at least g_plantClear
// cm from the board's centre line so it stands beside the deck, not under it; g_plantBack of the animation's own movement
// may be mixed back in. And the step is UP FIRST, THEN OVER: the first 60 % of it lifts the foot to the deck's height
// beside the board, the last 55 % carries it over onto its spot.
V3 g_plantOffW = { 0, 0, 0 }; bool g_plantHaveOff = false; volatile float g_plantClear = 22.0f;
// (v89) THE SOFT PLANT'S FOOT STANDS WHERE IT IS PUT. "The front foot is leaving the board too far behind. Like it actively
// moves backwards. Then during the move, it's like slides forward. It just needs to hit the ground much more forward." The
// soft plant (v78) pins nothing -- v75/v76's cure for this very complaint only ever ran in the pinned plant. The traces of
// 18:07-18:19 (true horizontal places, in the skater's own frame): the foot is on the ground from 47 ms, at +7 cm along; it
// then travels 23-35 cm BACK over the ground in 0.25 s (to -15..-27, and 25-35 out), and 26 cm FORWARD again, still on the
// ground, in the 0.11 s before the step (the body is held down for a foot the animation is already carrying to the board).
// Now the foot goes down where it rides + plantfwd cm toward its own end of the board, plantclear out from the centre
// line, and keeps that place -- a fixed offset from the skater in the world's axes, as v76's -- until the step, when it
// eases back to the animation's foot (which by then is over that very place: the lift is straight up). Only the plant
// leg is solved; the body is the animation's, let down as before. Not with a hand on the board (the boneless stands on
// the animation's foot). plantback of the animation's own movement may be mixed back in.
volatile float g_plantFwd = -100.0f;                 // HJN_Set("plantfwd"): cm; under -90 = off (the animation's own track, v88)
float g_plantSoftW = 0.0f, g_plantCut = 0.0f; double g_plantHoldT0 = 0.0;
float g_plantHipS = 0.0f; LONG g_plantSided = 0;   // (v83)
// (v89) THE PINNED PLANT STEPS BEFORE THE BACK LEG IS FOLDED FLAT. The switch no complies of 18:10:44-52: the back foot is
// welded to the rising deck with the hips kept 28-32 cm down for the planted leg -- hip to ankle 29 / 18 / 27 cm of a leg
// of 84 at 0.28-0.41 s. Once the board has risen, a back leg under g_plantFold of its own length starts the step.
float g_plantBackFold = 0.0f; volatile float g_plantFold = 0.40f;
// ==== (v94) THE PLANT LEG IS PLANNED, NOT CORRECTED ====================================================================
// "We've gone through too many iterations with no progress ... we had the original animation in the game ... maybe go back
// to the original to understand how they did it." The original, read out of the game's files (AMXX_RGS_NoComply_LFL_Hi,
// 20 frames, 0.633 s): it is made in GROUND space -- hips 71 -> 120 cm, the board pivoting on its tail to 64 deg by 0.17 s
// and rising to 70 cm, the front foot flat on the ground (ankle 11 cm up, 35-43 deg toe-down by the rig's joints) from
// 0.13 to 0.23 s, heel up at 0.27, gone by 0.30 -- and its Foot_Anchor bones carry each foot's place IN THE BOARD'S FRAME.
// The game does not play that. It keeps the hips at one height over the skater (the crouch at the flick; the skater is
// thrown up at the flick, the BOARD pops 0.13-0.2 s later) and puts each foot where the clip has it against the clip's
// board -- carried by the REAL board (tested against the traces of 4 Oct: the back foot's place along the deck within
// 3 cm on every pose). For a foot that rides the board that is right whatever the physics does. For the foot the clip
// stands on the ground it is right only if the real board stands where the clip's does; it never does (flat on the
// ground until its pop, 32 deg, 56 cm), so that foot is aimed 10-20 cm UNDER the ground, 20 cm further back, and turned
// by the two boards' difference in pitch: 40-64 deg too far toe-down ("the toe points straight down"), and from 0.19 s the
// target is out of the leg's reach -- the foot hangs at full stretch under the rising hips, its shin 31-50 cm for 41.2.
// v67-v93 corrected THAT foot, layer on layer (lift it, let the body down by its hover, hold its place, turn it off its
// toe by a heading read from a near-vertical foot: the ankle twist of 141-172 deg at lift-off in the traces of 20:33).
// Now nothing of the plant leg is taken from the game's pose while it is off the board:
//   1 it STEPS OFF: from where the game has it when it first comes down, to its place on the ground (v89's rule: beside
//     its riding spot, plantclear out), over g_plStepIn s, turning to how it will stand;
//   2 it STANDS: the ankle fixed against the skater (the world's axes), the foot turned as it RIDES on a level deck --
//     its own roll, toes g_plToeIn deg in from the board's line, flat + g_footHeel deg toe-down -- the knee over the
//     toes; the body let down by exactly what the leg needs at 97 % of its length, never more than the back leg has
//     room for (v89's rule);
//   3 it GOES BACK to the game's own foot (which by then is on its way to the board, in reach, and turned to the real
//     board as a riding foot should be) over 1.5 x plantstep, the heel peeling up first, the body coming up with it.
// The release is as it was (the board at its top / on its way down / the leg out of reach / the window over).
int g_plPhase = 0;                                   // 1 the foot steps off the board, 2 it stands, 3 it goes back to the game's own foot
bool g_plHave0 = false, g_plFlatOk = false, g_plRides = false;
double g_plT0 = 0.0, g_plPrevT = 0.0;                // when the phase began; the pose before
V3 g_plP0 = { 0, 0, 0 };                             // the ankle when the phase began: from the mesh's place in the world's axes, z over the ground under it
Q4 g_plQ0W = { 0, 0, 0, 1 }, g_plFlatW = { 0, 0, 0, 1 };   // the foot's turn when the phase began / as it stands, in the world
V3 g_plHeadW = { 1, 0, 0 }, g_plPole0W = { 1, 0, 0 };      // the way a standing foot points, flat, in the world; the knee's way when the phase began
float g_plLf = 17.2f, g_plFw = 1.0f;                 // ankle to toe joint, cm; +1 / -1: the board's +X / -X end is the plant foot's own
float g_plSlide = 0.0f, g_plExtLo = 9.0f, g_plExtHi = 0.0f, g_plApart = 0.0f, g_plTurn = 0.0f, g_plDownMs = -1.0f;   // for the log
V3 g_plLast = { 0, 0, 0 }; bool g_plHaveLast = false; LONG g_plLogs = 0;
Q4 g_plStep = { 0, 0, 0, 1 }; bool g_plStepOk = false;   // (review) the turn still to go on the way back, as it was on the pose before (its way round is kept)
float g_plYaw0 = 0.0f;                               // (review) which way the hips faced, in the world, when the foot left the ground (rad)
volatile float g_plStepIn = 0.09f, g_plPeel = 28.0f, g_plToeIn = 17.0f;   // HJN_Set("plantin" s / "plantpeel" deg / "planttoein" deg)
// (v95) IT STICKS WHERE IT LANDS, AND LEAVES SOONER. "The foot is nice and flat ... the foot also slides along the ground.
// I don't know if you want to try a sticky version where the plant foot sticks to where it lands ... It still feels a
// little late. Not sure if we can release the plant foot even sooner." The recording of 4 Oct 22:47:50: the foot stood
// from 149 to 432 ms, its ankle 13.7 cm up and flat -- and 4.5 cm further on over the ground on every pose (it was fixed
// against the SKATER, who rolls at 270 cm/s): 77 cm of slide. And it stood until "the board is at its top", 383 ms after
// it came down; the clip's own foot is on the ground for about 120.
//   plantstick 1: from the pose it comes down on the ankle keeps its place in the WORLD; the body rolls on, the leg leans
//                 back (the hips come down for it as before) and the foot leaves when the leg or the back leg's room
//                 runs out, or the hips are more than 0.45 of a leg (36 cm) ahead of it -- further than that the lean
//                 alone pulled the hips 12-20 cm lower than v94 had them (review: 33 cm down at 389 cm/s);
//   plantstand:   the longest it stands, seconds (0 = no limit: until the leg or plantmax runs out; until the board's
//                 top only with plantstick 0);
//   from a place in the world the way back takes 0.12 s at least (1.5 x 0.08), whatever plantstep says: at the 0.06 s
//   of a zeroed NoComplyStepTime the hips came up 14-22 cm in one pose;
//   the way back starts from where it stood in the world, not from a place that already moves with the skater.
volatile int g_plStick = 1; volatile float g_plStandMax = 0.12f;          // HJN_Set("plantstick", 0/1) / HJN_Set("plantstand", s)
V3 g_plStickW = { 0, 0, 0 }, g_plRelW = { 0, 0, 0 }; bool g_plStickOk = false, g_plRelStick = false; double g_plStandT0 = 0.0;
double NowS() {
    static LARGE_INTEGER fq = { 0 };
    if (!fq.QuadPart) QueryPerformanceFrequency(&fq);
    LARGE_INTEGER n; QueryPerformanceCounter(&n);
    return (double)n.QuadPart / (double)fq.QuadPart;
}
void PlantOver(bool done) {
    g_plantFoot = -1; g_plantW = g_plantD = g_plantD0 = 0.0f; g_plantRel = false; g_plantStage = 0; g_plantU = 0.0f; g_plantHipS = 0.0f; g_plantBackFold = 0.0f;
    g_plPhase = 0; g_plHave0 = false; g_plFlatOk = false; g_plHaveLast = false; g_plStepOk = false;   // (v94)
    g_plStickOk = false; g_plRelStick = false;                                                        // (v95)
    if (done) g_plantDone = true;
}
bool PlantHold(const void* mesh);
// ==== (v96) THE BACK FOOT LIES FLAT ON THE TAIL =======================================================================
// "The one thing left to fix would be the back foot. When it slaps down and the trick starts, it turns so the sole of the
// foot is facing almost horizontal. That should still be more or less flat to the tail." The recording of 4/5 Oct (nine no
// complies ridden regular; the eight of the session before read the same): the back foot's sole is 18 deg off the drawn
// deck at 0.05 s, 57 at 0.10, 57-75 until 0.35 s and back under 20 by 0.5 s -- in the game's own pose, and to the tenth
// of a degree as drawn: nothing in the mod has ever turned that foot (LegOwnLength, the soft plant's lift onto the deck
// and GroundFeet all hand Leg() the rotation the pose came with). It is the clip. There the back foot stands LEVEL, on
// the tail's tip, while the clip's board levers up under it to 64 deg (measured: the foot 100-120 deg off the skeleton's
// board, by its trucks, at 0.08-0.2 s); the game carries each foot from the clip's board to the real one, turn and all,
// and the real board lies flat until 0.13 s and never pitches past 32 -- so the foot is tipped by the clip's 64 deg, the
// other way, on a board that is level: its sole toward the tail, the ankle 2-4 cm down on the sole's edge.
// (The pinned plant and the boneless's glued foot stand the back foot on its riding spot with its riding turn: there it
// was flat already -- 4-9 deg, and 2 once the glue is on.)
// While a soft plant has its plant foot, the OTHER foot's sole is swung -- the shortest way, so the heading the clip gives
// it on the deck is kept -- to lie on the drawn deck as it does riding (the riding stance's turn of it), and its ankle is
// no lower over the deck than it rides. The swing comes in at 1200 deg/s at most (the game tips the foot at 800-1100) and
// fades over 0.15 s once the plan is over (the game's own foot is back within 15 deg of the deck 0.1 s after that). Run on
// the recording (this function itself, cut out of the source): 0-1 deg off the deck while the plan runs (0.05-0.42 s) in
// all nine, the foot's biggest turn in one pose 19 -> 8-12 deg, the ankle raised by 2-4 cm at 0.05-0.17 s.
// HJN_Set("backflat", 0..1): the share of the tilt taken out (0 = the game's own foot).
volatile float g_bkFlat = 1.0f;
int g_bkFoot = -1; float g_bkW = 0.0f, g_bkA = 0.0f, g_bkMost = 0.0f, g_bkLift = 0.0f; double g_bkT = 0.0; LONG g_bkPoses = 0, g_bkLogs = 0;
bool BackFlat(const void* mesh) {
    const double now = NowS();
    const bool stale = now - g_bkT > 0.3;                 // not run for a while (a bail, a grab, the window shut): nothing is carried over
    const float dt = clampf((float)(now - g_bkT), 0.0f, 0.05f);
    g_bkT = now;
    if (stale) { g_bkFoot = -1; g_bkW = g_bkA = 0.0f; }
    const bool planned = g_plantMode != 2 && g_plantFoot >= 0 && g_bkFlat > 0.0f;   // the soft plant's: the pinned one stands the back foot on its spot itself
    if (planned && g_bkFoot != 1 - g_plantFoot) { g_bkFoot = 1 - g_plantFoot; g_bkA = 0.0f; g_bkMost = g_bkLift = 0.0f; g_bkPoses = 0; g_kneeKept = 0; g_kneeKeptLow = 99.0f; }   // (v96, review) + the knee's count and lowest shin: this plant's, not what ran on after the last trick's line (a landing's squeezed shin, a rolling grab)
    if (g_bkFoot < 0) return false;
    g_bkW = planned ? 1.0f : g_bkW - dt / 0.15f;
    const int o = g_bkFoot, ft = g_foot[o];
    if (g_bkW <= 0.0f || ft < 0) {
        if (g_bkPoses > 0 && InterlockedIncrement(&g_bkLogs) <= 300)
            Log("back foot (v96): the %s foot lay flat on the deck through this plant, %ld poses -- the game had its sole up to %.0f deg off the deck; its ankle was raised by up to %.1f cm | the unplanned knee kept its side on %ld poses where the game's leg did not say (the game's shin down to %.0f cm)",
                o ? "R" : "L", g_bkPoses, g_bkMost, g_bkLift, g_kneeKept, (g_kneeKept > 0) ? g_kneeKeptLow : 0.0f);
        g_kneeKept = 0; g_kneeKeptLow = 99.0f;
        g_bkFoot = -1; g_bkW = g_bkA = 0.0f;
        return false;
    }
    g_deckOk = g_boardOk && DeckXf(mesh);
    if (!g_deckOk || g_stCur < 0 || !g_dFootOk[o]) return false;   // no riding stance learned yet: the foot stays the pose's
    UseStance(g_stCur);
    const V3 up = qrot(g_dq, DeckN());
    const V3 nNow = qrot(g_Ct[ft].q, qinv(g_uFootQ[o], DeckN()));   // the deck's up as this foot carries it when it rides
    const float tilt = acosf(clampf(dot(nNow, up), -1.0f, 1.0f)) * 57.2957795f;
    if (tilt > g_bkMost) g_bkMost = tilt;
    g_bkA = fminf(tilt * g_bkW * clampf(g_bkFlat, 0.0f, 1.0f), g_bkA + 1200.0f * dt);
    if (g_bkA < 0.05f || tilt < 0.05f) return false;
    const Q4 q = qnorm(qmul(qscale(qfromto(nNow, up), g_bkA / tilt), g_Ct[ft].q));
    V3 l = qinv(g_dq, sub(g_Ct[ft].p, g_dp));            // ...standing on it: the game has the tipped foot's ankle 2-4 cm down, on the sole's edge
    const float low = g_uFootP[o].z - l.z;               // (a foot more than 8 cm under its riding height is not standing on the deck: left where it is)
    const float by = (low > 0.1f) ? low * clampf((8.0f - low) / 3.0f, 0.0f, 1.0f) * clampf(g_bkA / 10.0f, 0.0f, 1.0f) : 0.0f;
    if (by > 0.05f) {
        if (by > g_bkLift) g_bkLift = by;
        l.z += by;
        Leg(o, add(g_dp, qrot(g_dq, l)), q);
    } else SetComp(ft, q, g_Ct[ft].p);
    {   // (v96, review) ...and its toes lie flat with it: the toe bone bent against the foot as it rides (the note at g_toeRide), by
        // the share the foot is turned -- so it comes in, is held back and fades with the foot's own swing
        const int to = g_toe[o];
        if (to >= 0 && g_parent[to] == ft && g_toeRideN[o] >= 30) {
            g_Lt[to].q = qslerpTo(qnorm(g_Lt[to].q), g_toeRide[o], clampf(g_bkA / tilt, 0.0f, 1.0f));
            CompOf(to, g_Lt, g_Ct); RebuildSub(to);
        }
    }
    g_bkPoses++;
    return true;
}
// (v71) A HALF TURN OF THE WHOLE POSE (HJN_Set("yaw180", seconds)): the switch no comply's mirror. The anim instance's mirror
// flag, flipped by the Lua, mirrored the trick FRONT TO BACK -- the graph's mirror node follows the flag, the half turn of
// the root the game adds for a mirrored rider was worked out before our write and does not. With that half turn made here
// the two together are the left-to-right mirror the game draws a goofy rider with.
volatile ULONGLONG g_yaw180Until = 0;
// ==== (v70) THE TRICK TRACE ===========================================================================================
// "The feet come off the board, a couple of feet in the air ... it doesn't pop that high ... keep refining the logging":
// what the eye sees there is where the feet, the hips and the hand are against the DRAWN deck, pose by pose, and where the
// animation had them before the mod's own edits. HJN_TrickTrace(poses, tag) logs every third pose: the deck (pitch, roll,
// height over the ground), the mesh root over the ground, the hips over the deck (animation / as drawn), each ankle over
// the deck and along it (animation / as drawn), the game's foot IK weights, and the boneless hand (its weight, how far it
// is from its spot, the crouch).
volatile int g_ttFrames = 0; int g_ttN = 0; ULONGLONG g_ttT0 = 0; int g_ttEvery = 3;
void TrickTraceLine(const void* mesh, const void* anim);
// ==== (v68) THE BONELESS HAND =========================================================================================
// v67's boneless handed the game its Indy part way through the no comply: the game dropped it, took it for 0.2 s and its
// grab pose (both feet on the deck, the tuck) fought the trick's animation -- "it kind of scrambles his legs". A boneless is
// the back hand ON the board while the front foot plants and pushes off: so only the ARM is posed. While the Lua holds the
// window (HJN_Bone(seconds, side)) the hand of that side goes to the Indy's own spot on the drawn deck (the toe edge between
// the feet, the same spot and numbers the Indy grab uses), the spine leaning as far as a grab's may, eased in and out over a
// few frames. The legs, the board and the game's grab state are not touched.
volatile ULONGLONG g_boneUntil = 0; volatile int g_boneSide = -1;
float g_boneW = 0.0f, g_boneLean = 0.0f, g_boneGap = 0.0f; LONG g_boneFrames = 0;
// (v69) A GRAB WHILE ROLLING (and held through a no comply = the boneless, "how it is done in real life"): the hand of
// HJN_Bone's side goes to that grab's own spot on the drawn deck (kind 102 Indy: the back hand to the toe edge between the
// feet; 3 Mute: the front hand to the toe edge by the front foot). Standing on the board the hand is far short of the deck, so
// the hips come DOWN -- as far as the hand is still short, a few cm a frame, at most the crouch Lua allows -- with both feet
// kept exactly where the animation has them (the legs fold), then the spine leans and the arm reaches. In a no comply the
// animation is already crouched: the same loop lets the hips back up by itself.
volatile int g_boneKind = 102; volatile float g_boneDropMax = 0.0f; float g_boneDrop = 0.0f;
// (v72) "He just bends his knees and keeps his back too straight -- more like the Indy or the Mute": the spine may lean
// g_boneLeanMax deg toward the board (a grab's own limit was 45), and the hips come down only while that lean has stopped
// growing and the hand is still short; with the hand on the board and the back hardly bent, they come back up a little a
// frame and the back takes over (unless it then cannot: remembered for the grab)
volatile float g_boneLeanMax = 55.0f; bool g_boneNoRelax = false; float g_boneRelaxAt = -1.0f;
// (v73) THE ROLLING GRAB IS A SQUAT WITH A ROUND BACK. v72 bent the whole upper body 55 deg at ONE joint, the first of the
// spine, and only then let the hips down: "he bends almost in half at his waist, which is totally unnatural ... and if I
// crouch, it adds another layer". The game's own Indy has the hips 44-48 cm over the board (the grab lines of 19:17:33).
// So: the hips go DOWN TO g_boneHips cm over the drawn deck -- a height, not an amount: crouching yourself adds nothing --
// and a little back from the grabbed edge, as a squat's do; then the back bends only as far as the arm still needs, and
// that bend is SHARED: g_boneHipShare of it a hinge at the hips (the feet kept where they are), the rest in equal parts
// by every spine joint, the head coming back up by a third. With the back at its limit and the hand still short the hips
// come down a little further. And while a no comply's plant foot is on the ground the hips are not taken down for the
// hand at all: the plant leg stays straight ("he needs to extend that leg fully").
volatile float g_boneHips = 50.0f, g_boneHipShare = 0.4f, g_boneBack = 18.0f; float g_boneExtra = 0.0f;
// (v75) "The knees are too close to the ground -- the leg needs to make a better 90": with the hips straight down over the
// feet the knees went 37 cm out past the toes, the shins nearly flat. The hips sit BACK from the grabbed edge now (18 cm
// in a full squat) and a little higher: the shins stand up, the thighs lie flat. The knees part along the board
// (g_boneSplay), which makes room for the arm; and "the front hand goes through the front leg": the Mute's spot, by the
// front foot, is moved g_boneMuteIn cm toward the middle of the board for a rolling grab -- inside the front knee.
volatile float g_boneSplay = 0.45f, g_boneMuteIn = 12.0f;
// (v76) "give me a plus / minus for the along-the-board position, for both hands": cm added to a rolling grab's spot along
// the board, + toward the front foot. The front hand's default is v75's 12 cm toward the middle (-12).
volatile float g_boneAlongF = -12.0f, g_boneAlongB = 0.0f;
float LeanRound(int sd, V3 tgt, float w) {
    if (g_spineN < 1 || g_spineN > 6 || g_pelvis < 0 || g_leanMax <= 0.0f) return Lean(sd, tgt, w);
    const int n = g_spineN;
    const V3 P = g_Ct[g_pelvis].p, S = g_Ct[g_uarm[sd]].p;
    const float reach = armLen(sd) * 0.97f;
    const Q4 full = qfromto(sub(S, P), sub(tgt, P));
    const float fullAng = qangle(full);
    const float hs = clampf(g_boneHipShare, 0.0f, 0.9f);
    V3 j0[6];
    for (int i = 0; i < n; i++) j0[i] = g_Ct[g_spine[i]].p;
    auto shoulderAt = [&](float a) {                    // where the shoulder comes to with a deg of bend shared out
        const Q4 qh = qscale(full, hs * a / fullAng), qe = qscale(full, (1.0f - hs) * a / (fullAng * (float)n));
        V3 j[6]; V3 s = add(P, qrot(qh, sub(S, P)));
        for (int i = 0; i < n; i++) j[i] = add(P, qrot(qh, sub(j0[i], P)));
        for (int i = 0; i < n; i++) {
            const V3 p = j[i];
            for (int m = i + 1; m < n; m++) j[m] = add(p, qrot(qe, sub(j[m], p)));
            s = add(p, qrot(qe, sub(s, p)));
        }
        return s;
    };
    float wantAng = 0.0f;
    if (fullAng >= 0.5f && len(sub(tgt, S)) > reach) {
        float hi = fminf(g_leanMax * g_leanScale, fullAng * 1.25f), lo = 0.0f;
        if (len(sub(tgt, shoulderAt(hi))) <= reach)
            for (int i = 0; i < 10; i++) { const float m = 0.5f * (lo + hi); if (len(sub(tgt, shoulderAt(m))) > reach) lo = m; else hi = m; }
        wantAng = hi * clampf(w, 0.0f, 1.0f);
    }
    g_leanS += (wantAng - g_leanS) * clampf(g_ease, 0.02f, 1.0f);
    if (g_leanS < 0.1f || fullAng < 0.5f) return 0.0f;
    TurnComp(g_pelvis, qscale(full, hs * g_leanS / fullAng));
    const Q4 qe = qscale(full, (1.0f - hs) * g_leanS / (fullAng * (float)n));
    for (int i = 0; i < n; i++) TurnComp(g_spine[i], qe);
    if (g_neck >= 0) TurnComp(g_neck, qscale(qconj(full), 0.3f * g_leanS / fullAng));
    return g_leanS;
}
// (v87) THE BONELESS'S BACK FOOT STAYS ON THE BOARD. "The back foot does not stay on the board during the lift -- see if
// you can just glue it on." The trace of 13:35:50: with the board coming up 100 cm (v170) the animation's back foot is
// 20 cm under and behind the tail from 0.30 to 0.34 s -- the no comply's own scoop, made for a board that stays low.
// While a foot is planted and the hand is on the board, the OTHER foot is put on its riding spot on the drawn deck (eased
// in and out, a fifth a pose), turned as it rides.
int g_glueFoot = -1; float g_glueW = 0.0f, g_glueMost = 0.0f; LONG g_glueFrames = 0, g_glueLogs = 0;
// (v88) ...AND ITS LEG IS GIVEN ROOM. "The foot stays on the board, but it kind of crumples the knee or leg." The trace of
// 14:13:45: with the board rising 500 cm/s to the glued foot and the hips kept 45 cm down for the planted leg, the hips
// stand 22-30 cm over the back ankle from 0.34 to 0.50 s (the animation: 54 -> 30) -- a leg of 84 cm folded into that.
// The hips are raised (4 cm a pose at most, 18 cm at most) until the glued leg has g_glueMin (half) of its length from
// hip to ankle; the planted leg straightens for it and, where it cannot reach, comes off the ground a little early.
volatile float g_glueMin = 0.5f, g_glueRaiseMax = 18.0f; float g_glueRaise = 0.0f, g_glueRaiseMost = 0.0f; int g_glueTail = 0;
// ==== (v96) A PLANTED FOOT'S HEEL COMES UP WHERE ITS ANKLE CANNOT BEND ANY FURTHER =====================================
// "Bean plant had some fixed leg warping." PlantSoft plans the plant leg for a leg at 97 % of its length (the note at
// g_plPhase: flat foot, the knee over the toes, the body let down by what the leg needs) -- and with a hand on the board
// BoneHand then takes the hips down to g_boneHips over the deck and solves that leg again, to the same flat foot. The
// recording of 5 Oct 00:08 (segment 13 the boneless, 14 the bean plant): PlantSoft logs 'the leg 97-97 % of its length',
// drawn it is 53-83 %. The hips stand 40-56 cm over the stuck ankle (a plain no comply's: 74-80) and roll on from 10 cm
// behind it to 26 ahead; the knee goes 28-36 cm out past the ankle, 30-40 cm over the ground, the shin lies 51-66 deg off
// upright (17-30) -- and the foot is kept flat: shin to ankle->toe 84 -> 67 deg ('tf ... L 23/78, 22/68, 19/71') where
// riding in a crouch has 93 and a plain no comply's standing foot 101-116 (never under 93.6 in the nine recorded). Against
// the sole (a flat foot's ankle->toe is 26 deg toe-down by the joints) that is an ankle bent 32 -> 49 deg; riding has 23,
// a deep lunge 30-35, and there an ankle ends: a foot whose knee is further ahead of it than that stands on its BALL. So,
// for the planned plant foot, when BoneHand solves its leg: where that angle would come under g_plFlex the foot is turned
// toe-down about its own TOE JOINT -- which stays where the plan put it, on the ground -- by what brings the angle back
// to g_plFlex (g_plHeelMax deg at most), and the toes are turned back: they stay flat. Nothing is kept from pose to pose
// (replayed on those two recordings with 85: up by 1, 7, 11, 15, 18, 20, 20, 18 deg while it stands, 17 and 3 on the first
// two poses of the way back, then the plan's own peel has it; the foot stands 61 deg toe-down at most, the ankle moves
// 6 cm at most, the knee steps no further from pose to pose than before; with 90 it is 25 deg and 66).
// A no comply without a hand never comes here. HJN_Set("plantflex", deg; 0 = as it was) / ("plantheelmax", deg).
volatile float g_plFlex = 85.0f, g_plHeelMax = 35.0f;
int g_plHeelN = 0; float g_plHeelMost = 0.0f, g_plHeelLow = 999.0f; double g_plHeelT0 = 0.0; LONG g_plHeelLogs = 0;
void PlantHeelTold() {
    if (g_plHeelN > 0 && InterlockedIncrement(&g_plHeelLogs) <= 200)
        Log("plant (v96): with the hips down for the hand the plant foot's heel came up on %d poses, %.0f deg at most -- kept flat its ankle would have been bent to %.0f deg (shin to toe; plantflex %.0f)",
            g_plHeelN, g_plHeelMost, g_plHeelLow, (float)g_plFlex);
    g_plHeelN = 0; g_plHeelMost = 0.0f; g_plHeelLow = 999.0f;
}
bool PlantHeel(int k, V3 F, Q4 q, V3 bias) {                          // true = the leg is solved (heel up); false = nothing to do, solve it as ever
    if (g_plantT0 != g_plHeelT0) { PlantHeelTold(); g_plHeelT0 = g_plantT0; }   // another plant: the last one's line, if it is still owed
    const int th = g_thigh[k], ca = g_calf[k], ft = g_foot[k], to = g_toe[k];
    const float lim = g_plFlex;
    if (lim < 1.0f || th < 0 || ca < 0 || ft < 0 || to < 0) return false;
    const V3 tl = mulv(g_Lt[to].p, g_Ct[ft].s);               // the toe joint in the foot's own frame
    if (len(tl) < 3.0f) return false;
    q = qnorm(q);
    const V3 t0 = qrot(q, tl), hd = sub(t0, mul(kUp, dot(t0, kUp)));   // ankle to toe joint | its level part: the way the toes point
    if (len(hd) < 0.2f * len(tl)) return false;               // a foot on its tip has no heading (v93's lesson) -- and no bent ankle
    const V3 S = g_Ct[th].p, T = add(F, t0), ax = norm(cross(kUp, hd));   // the toe joint: it stays | the foot's cross axis, + = toe down
    const float a1 = len(sub(g_Ct[ca].p, S)), a2 = len(sub(g_Ct[ft].p, g_Ct[ca].p));
    const V3 pole = add(norm(sub(g_Ct[ca].p, add(S, mul(sub(g_Ct[ft].p, S), 0.5f)))), bias);   // the knee's own way (+ the squat's splay), as Leg() takes it
    V3 Fn = F; Q4 qn = q;
    auto flexAt = [&](float up) {                             // shin to ankle->toe with the heel up by `up` deg, the leg as Leg() will solve it
        qn = (up > 0.0f) ? qnorm(qmul(qaxis(ax, up), q)) : q;
        const V3 tn = qrot(qn, tl);
        Fn = (up > 0.0f) ? sub(T, tn) : F;
        V3 Fc = Fn; const V3 d = sub(Fn, S); const float dl = len(d);
        if (dl > (a1 + a2) * 0.995f) Fc = add(S, mul(d, (a1 + a2) * 0.995f / dl));
        return acosf(clampf(dot(norm(sub(MidJoint(S, Fc, a1, a2, pole), Fc)), norm(tn)), -1.0f, 1.0f)) * 57.2957795f;
    };
    const float flat = flexAt(0.0f);
    if (!(flat < lim)) { if (g_plPhase == 3) PlantHeelTold(); return false; }
    const float cap = clampf(g_plHeelMax, 0.0f, 60.0f);
    float up = 0.0f, fx = flat;
    for (int i = 0; i < 8 && fx < lim - 0.05f && up < cap; i++) { up = fminf(up + (lim - fx), cap); fx = flexAt(up); }
    if (!(up > 0.0f)) return false;
    Leg(k, Fn, qn, v3(0.0f, 0.0f, 0.0f), &pole);
    TurnComp(to, qaxis(ax, -up));                             // the toes stay flat on the ground: the foot is on its ball
    g_plHeelN++; if (up > g_plHeelMost) g_plHeelMost = up; if (flat < g_plHeelLow) g_plHeelLow = flat;
    return true;
}
bool BoneHand(const void* mesh, float w) {
    const int sd = g_boneSide, kind = g_boneKind;
    if (sd < 0 || sd > 1 || g_hand[sd] < 0) return false;
    g_deckOk = g_boardOk && DeckXf(mesh);
    if (!g_deckOk) return false;
    if (g_stCur >= 0) UseStance(g_stCur);                     // the foot spots the grab's spot is measured from
    const float k = clampf(w, 0.0f, 1.0f);
    const GrabProfile pro = ProfileFor(kind, sd);
    V3 tgt;
    if (!OwnSpot(kind, pro, tgt)) return false;
    const V3 in = g_lastIn, up = DeckUp();
    const V3 axd = qrot(g_dq, v3(1.0f, 0.0f, 0.0f));          // the deck's long axis
    {                                                         // (v76) your own shift along the board, + toward the front foot
        V3 a, lat;
        if (DeckAxes(pro.frontFoot, a, lat)) tgt = add(tgt, mul(qrot(g_dq, a), (kind < 100) ? g_boneAlongF : g_boneAlongB));
    }
    {                                                         // (v79) where the spot is, logged when the stance or the grab changes
        static int lastSt = -99, lastKind = -99; static LONG told = 0;
        if ((g_stCur != lastSt || kind != lastKind) && InterlockedIncrement(&told) <= 80) {
            lastSt = g_stCur; lastKind = kind;
            const V3 sl = qinv(g_dq, sub(tgt, g_dp));
            Log("bone spot: stance #%d, grab %d (%s hand): the spot is %+.0f cm along the deck, %+.0f across (its edge is %.0f out), %+.0f up", g_stCur, kind, sd ? "right" : "left", sl.x, sl.y, HalfWidth(), sl.z);
        }
    }
    // the squat: down to the Indy's own height over the deck, 3 cm a pose, at most what the Lua allows (less in the air)
    // (v74) v73 took the hips down not at all while a plant foot was on the ground: the skater rose 40 cm in the first 0.15 s
    // with the board still on the ground, and the hand came 37 cm off it ("the grab hand comes very far off the board").
    // The hips stay down WITH the hand: he stays crouched over the board, the plant leg bent, and comes up as the board
    // does -- the leg is at full stretch by the board's top (PlantHold takes the larger of the two drops, not their sum)
    const float cap = fmaxf(g_boneDropMax, 0.0f);
    const float rate = (g_plantFoot >= 0) ? 6.0f : 3.0f;      // in a no comply the skater rises 4 cm a pose
    const float over = (g_pelvis >= 0) ? dot(sub(g_Ct[g_pelvis].p, g_dp), up) : 0.0f;
    const float want = clampf(over - fmaxf(g_boneHips, 0.0f) + g_boneExtra, 0.0f, cap);
    g_boneDrop = (g_boneDrop < want) ? fminf(g_boneDrop + rate, want) : fmaxf(g_boneDrop - rate, want);
    const float drop = g_boneDrop * k;
    V3 fp[2] = { { 0, 0, 0 }, { 0, 0, 0 } }; Q4 fq[2] = { { 0, 0, 0, 1 }, { 0, 0, 0, 1 } };
    for (int f = 0; f < 2; f++) if (g_foot[f] >= 0) { fp[f] = g_Ct[g_foot[f]].p; fq[f] = g_Ct[g_foot[f]].q; }
    if (drop > 0.3f && g_pelvis >= 0) {
        const V3 flat = sub(in, mul(up, dot(in, up)));        // from the grabbed edge in over the deck: where a squat's hips go
        const float bk = (len(flat) > 0.5f) ? clampf(g_boneBack, 0.0f, 40.0f) * fminf(drop / 40.0f, 1.0f) : 0.0f;
        SetComp(g_pelvis, g_Ct[g_pelvis].q, add(sub(g_Ct[g_pelvis].p, v3(0.0f, 0.0f, drop)), mul(norm(flat), bk)));
    }
    {                                                         // (v87) the back foot on its riding spot, (v88) with room for its leg
        const bool planted = g_plantFoot == 0 || g_plantFoot == 1;
        if (planted) g_glueFoot = 1 - g_plantFoot;
        const int o = g_glueFoot;
        const bool can = o >= 0 && o <= 1 && g_foot[o] >= 0 && g_thigh[o] >= 0 && g_stCur >= 0 && g_dFootOk[o];
        if (planted) g_glueTail = 24; else if (g_glueTail > 0) g_glueTail--;
        const bool back = can && !planted && g_glueTail > 0 && g_glueW > 0.5f && len(sub(add(g_dp, qrot(g_dq, g_uFootP[o])), fp[o])) > 6.0f;   // (v89) not let go 30 cm from where it rides
        g_glueW += (((can && (planted || back)) ? 1.0f : 0.0f) - g_glueW) * 0.2f;
        float raiseWant = 0.0f;
        if (can && g_glueW * k > 0.01f) {
            const float gw = clampf(g_glueW * k, 0.0f, 1.0f);
            const V3 was = fp[o];
            const V3 spot = add(g_dp, qrot(g_dq, g_uFootP[o]));
            if (g_glueFrames == 0 && InterlockedIncrement(&g_glueLogs) <= 60)
                Log("boneless: the back foot (%s) is kept on its riding spot on the deck (%+.0f %+.0f %+.0f) -- the animation has it %.0f cm from there now",
                    o ? "R" : "L", g_uFootP[o].x, g_uFootP[o].y, g_uFootP[o].z, len(sub(spot, was)));
            fp[o] = lerp(was, spot, gw);
            fq[o] = qslerpTo(fq[o], qnorm(qmul(g_dq, g_uFootQ[o])), gw);
            const float moved = len(sub(fp[o], was));
            if (moved > g_glueMost) g_glueMost = moved;
            g_glueFrames++;
            if (g_pelvis >= 0) {
                const float legLen = (g_legRefOk && g_legRef[o][0] > 1.0f) ? g_legRef[o][0] + g_legRef[o][1] : 84.0f;
                const float minExt = clampf(g_glueMin, 0.3f, 0.8f) * legLen;
                const V3 d = sub(g_Ct[g_thigh[o]].p, fp[o]);
                const float hz = sqrtf(d.x * d.x + d.y * d.y);
                if (hz < minExt) raiseWant = clampf(sqrtf(minExt * minExt - hz * hz) - d.z, 0.0f, fmaxf(g_glueRaiseMax, 0.0f)) * gw;
            }
        } else if (g_glueW < 0.01f) {
            if (g_glueFrames > 0 && g_glueLogs <= 60)
                Log("boneless: the back foot was kept on the deck for %d poses, up to %.0f cm from where the animation had it; the hips were raised up to %.0f cm for its leg; leg bones put back to their own length on %ld solves (%.0f cm most)",
                    (int)g_glueFrames, g_glueMost, g_glueRaiseMost, g_legFixed, g_legFixMost);
            g_glueW = 0.0f; g_glueFoot = -1; g_glueFrames = 0; g_glueMost = 0.0f; g_glueRaiseMost = 0.0f; g_legFixed = 0; g_legFixMost = 0.0f;
        }
        g_glueRaise += clampf(raiseWant - g_glueRaise, -3.0f, 4.0f);
        if (g_glueRaise > 0.2f && g_pelvis >= 0) {
            SetComp(g_pelvis, g_Ct[g_pelvis].q, add(g_Ct[g_pelvis].p, v3(0.0f, 0.0f, g_glueRaise)));
            if (g_glueRaise > g_glueRaiseMost) g_glueRaiseMost = g_glueRaise;
        }
    }
    const float leanWas = g_boneLean;
    {
        const float keepMax = g_leanMax;                      // the hand's own lean limit for this call
        g_leanMax = fmaxf(g_boneLeanMax, 0.0f); g_leanScale = 1.0f;
        g_leanS = g_boneLean;                                 // (the grab code zeroes its own eased lean on every frame without a grab)
        LeanRound(sd, tgt, w);
        g_boneLean = g_leanS;
        g_leanMax = keepMax;
    }
    {                                                         // the feet where they were (a planted foot stays planted)
        const V3 mid = mul(add(fp[0], fp[1]), 0.5f);
        // (v96) ...and let go 0.04 a pose once a foot is planted, not in one pose: the bean plant of 5 Oct 00:08 began 16 cm
        // down in the squat (a splay of 0.18) and on the plant's first pose the back knee's way turned 19 deg -- 12 cm in one
        // pose where the game's own pose turns it 7 deg ('R knee jumps 9.5 cm at #80 -- a STEP'); from a full squat it is
        // 0.45, 24 deg. Replayed on that recording: 12.0, 7.2, 7.7, 6.1 cm a pose become 7.0, 8.5, 9.1, 7.3. On the board
        // nothing changes: the splay is the squat's own on every pose without a planted foot, as before.
        static float spHeld = 0.0f;
        spHeld = (g_plantFoot >= 0) ? fmaxf(spHeld - 0.04f, 0.0f) : clampf(g_boneSplay, 0.0f, 1.5f) * fminf(drop / 40.0f, 1.0f);
        const float sp = spHeld;                              // (v75) the knees apart, in a squat only
        for (int f = 0; f < 2; f++) {
            if (g_foot[f] < 0) continue;
            if (f == g_plantFoot && g_plPhase != 0 && g_plPhase != 4 && PlantHeel(f, fp[f], fq[f], mul(axd, (dot(sub(fp[f], mid), axd) >= 0.0f ? sp : -sp)))) continue;   // (v96) the planned plant foot under hips this low: on its ball, not flat with the ankle folded (v97: not once it stands on its riding spot again, the other stance's stage 3)
            Leg(f, fp[f], fq[f], mul(axd, (dot(sub(fp[f], mid), axd) >= 0.0f ? sp : -sp)));
        }
    }
    const V3 hand = g_Ct[g_hand[sd]].p;
    Arm(sd, lerp(hand, tgt, k));
    if (g_handAim >= 1) HandPose(sd, in, up, w);
    g_boneGap = len(sub(tgt, g_Ct[g_hand[sd]].p));
    // the back as far as it goes and the hand still short: the hips a little further down (kept for the grab)
    if (k > 0.95f && g_boneGap > 2.0f && (g_boneLean - leanWas) < 0.3f && g_boneDrop >= want - 0.5f && want < cap)
        g_boneExtra = fminf(g_boneExtra + clampf(0.3f * (g_boneGap - 2.0f), 0.0f, 2.0f), 40.0f);
    InterlockedIncrement(&g_boneFrames);
    return true;
}
// ==== (v67) THE PLANTED FOOT STAYS ON THE GROUND ======================================================================
// The no comply's animation plants the front foot lower than the ground the skater rolls on ("his foot plants underneath
// the ground"). While the Lua holds the window open (HJN_Set("footground", seconds), a frame at a time) each foot is traced
// down onto the world: an ankle less than g_footAnkle cm over the ground under it (or a toe less than g_footToe) is lifted
// straight up to that, the leg bent to suit (the same two-bone solve the grabs use). A foot on the board is far above that
// and is left alone.
volatile ULONGLONG g_footGroundUntil = 0; volatile float g_footAnkle = 10.0f, g_footToe = 2.5f;
LONG g_footLifts = 0; float g_footLiftMax = 0.0f;
bool GroundFeet(const void* mesh);
// ==== (v80) A HOP'S LEGS DO NOT SNAP LONGER ============================================================================
// "Right when the legs are coming down, the bottom of the feet warp down and stretch the legs -- two frames apart, you see
// how fast the leg grows." During a hop (HJN_Air each frame) each leg's length -- hip to ankle -- may grow g_hopLegRate
// cm/s at most; a pose that wants it longer than that gets the foot on the same line, nearer the hip. Shortening is free.
// The landing blend starts from these feet.
volatile float g_hopLegRate = 400.0f;
// (v81) ...ON THE WAY DOWN ONLY (HJN_Air(fraction of the air time)): v80 held the legs back on the way up too -- leaving
// the board they lengthen at 300+ cm/s -- "on the way up the legs suck up or shrink" (held back 8 poses, by up to 26 cm).
volatile float g_hopFrac = -1.0f;
// (v81) NO LEG LONGER THAN ITS BONES. The trace of 22:56:57: thigh + shin is 84-86 cm all through a hop's air, and on the
// touchdown pose of a 180 the right leg is 93 -- the game's foot IK, coming back on, drags the ankle to its socket on the
// board and STRETCHES the leg to get there (90, 90, 88, 85 on the next poses): "the bottom of the feet warp down and
// stretch the legs". The bones' own lengths are learned in the hop's air while the game's foot IK is off; for the landing
// (and the air) a thigh or shin more than 2 % over that is put back to its length -- the foot then stops short of the
// socket for those few poses instead of the leg growing.
float g_legRef[2][2] = { { 0, 0 }, { 0, 0 } }; volatile int g_stretchFrames = 0; LONG g_unstretched = 0; float g_unstretchMost = 0.0f;
// (v84) THE LEGS' OWN LENGTH IS THE MIDDLE OF WHAT RIDING MEASURES. "It broke the normal ones. His legs shrink. It looks
// crazy." v82 began from the FIRST pose the hook saw and then took in only poses under 8 % over that -- and on 3 Oct 23:52
// the first pose was a switch no comply's stance-swap frame (bones blended short): 'their own 70 71' where 83/84 is right,
// with every true length refused from then on, so each hop's legs were cut 16 % short all through the air. Now: one sample
// every fourth pose of plain RIDING (the game's foot IK full on, no grab, no hop, no plant), the last 48 kept, the length is
// their median; nothing is cut until 24 are in and the two legs agree.
// (v85) ...FROM THE THIGH. v84's median of riding poses was right for the thigh (42.6 cm, every time) and wrong for the
// shin: the game's foot IK SQUEEZES the shin while riding -- 'L 42.6 + 29.4, R 42.5 + 32.7' at 12:07:31, anywhere from 29
// to 42.7 over ten minutes -- so the legs' "own length" moved with whatever the last three seconds of riding had been
// (72 cm for a while: the legs cut again). The thigh is never touched: its median over riding poses is the length, and
// the shin's is 0.965 of it (41.1 of 42.6: what the air's poses, with the foot IK off, measure). Once known it is kept.
float g_thighBuf[2][48]; int g_legBufN = 0, g_legBufI = 0, g_legTick = 0; bool g_legRefOk = false; float g_legRefTold = 0.0f;
void LegRefLearn(bool riding) {
    if (!riding || (g_legTick++ & 3) != 0) return;
    float cur[2];
    for (int k = 0; k < 2; k++) {
        if (g_calf[k] < 0 || g_foot[k] < 0) return;
        cur[k] = len(g_L[g_calf[k]].p);
        if (!(cur[k] > 25.0f && cur[k] < 60.0f)) return;
    }
    for (int k = 0; k < 2; k++) g_thighBuf[k][g_legBufI] = cur[k];
    g_legBufI = (g_legBufI + 1) % 48;
    if (g_legBufN < 48) g_legBufN++;
    if (g_legBufN < 24) return;
    float med[2];
    for (int k = 0; k < 2; k++) {
        float s[48];
        for (int i = 0; i < g_legBufN; i++) {                 // (an insertion sort of at most 48)
            const float v = g_thighBuf[k][i]; int m = i;
            while (m > 0 && s[m - 1] > v) { s[m] = s[m - 1]; m--; }
            s[m] = v;
        }
        med[k] = s[g_legBufN / 2];
    }
    if (fabsf(med[0] - med[1]) >= 2.0f) return;               // the two thighs disagree: the last good numbers stay
    for (int k = 0; k < 2; k++) { g_legRef[k][0] = med[k]; g_legRef[k][1] = med[k] * 0.965f; }
    g_legRefOk = true;
    if (fabsf(med[0] + med[1] - g_legRefTold) > 1.0f) {
        g_legRefTold = med[0] + med[1];
        Log("legs: their own length, from the thighs of %d riding poses: L %.1f + %.1f, R %.1f + %.1f cm", g_legBufN, g_legRef[0][0], g_legRef[0][1], g_legRef[1][0], g_legRef[1][1]);
    }
}
// (v82) ...and done FIRST, on the pose as it comes in, before anything is solved on it: v81 shortened the bones after the
// landing blend had placed the feet with the stretched ones (a shin of 90 cm for a pose or two after a 180) -- shrinking
// it then folded the leg up (hip to ankle 5-7 cm on those poses). Only a gross stretch counts: more than 4 % over usual.
// (v85) ...and, in a hop's air only, no leg SHORTER than its bones either: riding regular the game's pose answers the
// Lua's reach (LandHeightRatio) by shrinking the leg's bones -- 84 cm to 70 over the last five poses of the air in every
// regular-stance hop of 4 Oct 12:07-12:09, back to 84 on the touchdown pose ("the feet warp toward the end of the trick");
// riding switch or fakie the same number bends the knee and leaves the bones alone. (The Lua no longer asks the game for
// the reach riding regular; this is for any pose that still comes in short.) Not on the ground: there the game's foot IK
// squeezes the shin on purpose.
// (v95) ...AND THE ANKLE STAYS WHERE THE POSE HAD IT. The bones were put back by scaling them where they lay, so the foot
// went out along the leg by whatever the shin had been short: the mini 180 of 4 Oct 22:53:51 takes off with the left shin
// at 26 cm (the game's straight leading leg), it is 41 on the first pose of the air -- and the ankle 18 cm further down,
// through the deck and the toe under the ground for three poses; from there that leg was a straight 82 cm stilt for the
// whole air (the same in both straight minis recorded). Now the leg is solved again to the ankle the pose had: the bones
// are their own length and the KNEE bends for the difference (its way: the note at g_poleToes).
// HJN_Set("legsolve", 0) = v94's.
volatile int g_unstrSolve = 1; LONG g_unstrSolved = 0;
// (v99) ...NOR 4 % LONGER. A bone was put back only once it was more than 4 % over its own length: in the recording of
// 5 Oct 12:06 every hop has the drawn shin 1.3-1.6 cm long (3.1-3.9 %) on two to seven poses round the touchdown, and
// over half a centimetre on 5-15 -- on a rig with no twist bone that is the ankle off the end of the shin ("like the top
// of the ankle disconnecting from the bottom of the calf", said of 2 cm of it in a plant). Now from 1.2 % (half a
// centimetre): the leg is solved to the same ankle with the bone its own length; where it is at full reach the foot
// comes up short of the pose's by that centimetre for those poses instead. HJN_Set("shintight", 0) = 4 %.
volatile float g_unstrLong = 1.012f;
bool LegUnstretch(bool shortToo, float shortEase = 0.0f) {   // (v89) shortEase: a share of a SHORT bone's missing length put back (a turned landing)
    bool changed = false;
    if (!g_legRefOk) return false;                            // (v84) not until the legs' own length is known
    for (int k = 0; k < 2; k++) {
        if (g_thigh[k] < 0 || g_calf[k] < 0 || g_foot[k] < 0 || g_legRef[k][0] < 1.0f || g_legRef[k][1] < 1.0f) continue;
        const int bone[2] = { g_calf[k], g_foot[k] };
        bool fix = false; float over = 0.0f;
        const V3 F0 = g_Ct[g_foot[k]].p; const Q4 fq0 = g_Ct[g_foot[k]].q;   // (v95) the ankle as the pose has it
        for (int j = 0; j < 2; j++) {
            const float cur = len(g_Lt[bone[j]].p), ref = g_legRef[k][j];
            float to = cur;
            if (cur > ref * g_unstrLong || (shortToo && cur < ref * 0.96f)) to = ref;
            else if (shortEase > 0.0f && cur < ref) to = cur + (ref - cur) * shortEase;
            if (cur > 1.0f && fabsf(to - cur) > 0.05f) { g_Lt[bone[j]].p = mul(g_Lt[bone[j]].p, to / cur); over += fabsf(cur - to); fix = true; }
        }
        if (!fix) continue;
        RebuildSub(g_thigh[k]);
        if (g_unstrSolve != 0 && finite3(F0)) { Leg(k, F0, fq0); InterlockedIncrement(&g_unstrSolved); }   // (v95) back to its ankle: the knee bends
        if (over > g_unstretchMost) g_unstretchMost = over;
        InterlockedIncrement(&g_unstretched);
        changed = true;
    }
    return changed;
}
// ==== (v83) A HOP'S FEET STAY LOW THROUGH A TURN =======================================================================
// "The mini jump is definitely jarring: quite a bit of a suck up on the way up, and then it stretches on the way down."
// Both mini hops of 23:25:01 and 23:27:12 were 180s. The mini hop keeps its feet low with the GAME's foot IK (MiniFootPull
// 0.35: each foot 35 % of the way from the air tuck to its socket on the board) -- and past a quarter turn those sockets
// are on the wrong sides, so the Lua cut the pull to nothing there, in one frame: hip to ankle 70/64 cm -> 47/32 on the
// next pose (60/74 -> 29/49 in the other), the feet 25-30 cm up at once, and back down over the landing. Now the Lua fades
// the game's pull out with the turn (all of it to 20 deg, none from 80) and names the pull it wants (HJN_Air's second
// number); what the game's IK no longer gives is made up here, in HEIGHT only: each foot is let down toward its riding
// height over the drawn deck by the missing share, straight along the deck's up -- no socket, no side to be wrong.
volatile float g_hopPull = 0.0f; LONG g_hopPulled = 0; float g_hopPullLast[2] = { 0, 0 };
V3 g_pullRel[2]; bool g_pullRelOk[2] = { false, false };   // (v84)
volatile float g_hopReach = 0.0f; V3 g_reachRel[2]; bool g_reachHave = false; float g_reachLast[2] = { 0, 0 };   // (v84)
volatile float g_hopReach01 = 0.0f; volatile int g_hopFlip = 0; float g_reachSide[2] = { 0, 0 };   // (v86)
bool HopPull(const void* mesh, const void* anim) {
    (void)mesh;
    // (v84) HANDED OVER WITHOUT A STEP. v83 let each foot down by the missing share of its HEIGHT -- but the game's pull
    // of 0.35 is not 35 % of the height (it blends the leg's joints): through the handover the legs grew 11-12 cm (the
    // trace of 23:54:50: hip to ankle 58/53 with the game's pull, 70/64 with the native one). Now, while the game's pull
    // is whole, each foot's place against the hips is remembered; as the game's pull fades with the turn the foot is
    // blended to that same place -- the legs keep the shape they had, whatever the game's blend made of the number.
    g_hopPullLast[0] = g_hopPullLast[1] = 0.0f;
    const float want = clampf(g_hopPull, 0.0f, 0.9f);
    if (want < 0.01f || !anim || g_pelvis < 0) return false;
    const V3 pp = g_Ct[g_pelvis].p;
    bool changed = false;
    for (int k = 0; k < 2; k++) {
        if (g_foot[k] < 0 || g_thigh[k] < 0) continue;
        float a = FootA(anim, k);
        if (!std::isfinite(a)) a = 0.0f;
        a = clampf(a, 0.0f, 1.0f);                                // the game's own pull on this pose
        if (a >= want - 0.005f) { g_pullRel[k] = sub(g_Ct[g_foot[k]].p, pp); g_pullRelOk[k] = true; continue; }
        if (!g_pullRelOk[k]) continue;
        // (v89) ...ALL OF IT BY A QUARTER OF THE FADE. The foot being blended is one the game is itself still fading: a blend of
        // a blend -- hip to ankle 63 -> 56 -> 64 across the fade of a mini 180 (18:13:25; 63 - 33 x share x (1 - share) fits
        // every pose within 2 cm), the feet 8 cm up and down again. With the kept place taken four times as fast it is 2 cm.
        const float share = clampf((1.0f - a / want) * 4.0f, 0.0f, 1.0f);
        const V3 F = lerp(g_Ct[g_foot[k]].p, add(pp, g_pullRel[k]), share);
        g_hopPullLast[k] = len(sub(F, g_Ct[g_foot[k]].p));
        Leg(k, F, g_Ct[g_foot[k]].q);
        changed = true;
    }
    if (changed) InterlockedIncrement(&g_hopPulled);
    return changed;
}
// (v86) for the hop's trace: a foot in the drawn deck's own frame -- cm along, across, and over its riding height
V3 TrFoot(const void* mesh, int k) {
    if (g_foot[k] < 0 || !g_boardOk || !DeckXf(mesh)) return v3(0.0f, 0.0f, 0.0f);
    const V3 l = qinv(g_dq, sub(g_Ct[g_foot[k]].p, g_dp));
    return v3(l.x, l.y, l.z - ((g_stCur >= 0 && g_dFootOk[k]) ? g_uFootP[k].z : 15.0f));
}
// ==== (v94) THE PLANNED LANDING ========================================================================================
// "We've gone through too many iterations with no progress ... I think we need to look at the physics of the move. If we
// know the arc of the move, the trajectory, it should be physics -- you could just plot it out in advance ... If we're
// relying too much on canned routines the stretching and warping is always going to be there."
// What every version since v80 was making up for, read off the hops of 4 Oct pose by pose:
//  1. THE HIPS END THE AIR TOO HIGH FOR THE LEGS. The Lua's lift ends at zero, and where that leaves the hips is the air
//     pose's own height: 87-89 cm over the ankles' riding level riding switch, about 100 riding regular and in a mini hop --
//     and a leg is 84. The feet cannot be on the deck at touchdown: they come down 2-3 poses late (switch) or 6-7 (regular
//     19:57:46: the left foot down on landing pose 7; the mini of 19:57:25: pose 6) on a leg held at 83-85 of 84 for four
//     to nine poses -- "the stretch", "the feet stop and hold in the air". v88's carried fall, v89's hip drop (hips 20 cm
//     down in two poses, then stock-still for four: 100, 89, 79, 78, 78, 79, 78 at 19:57:49 -- the caterpillar) and the
//     leg limiter all worked on what was left of that.
//  2. THE REACH CAME LATE AND FAST: from 80 % of the air, squared, 85 % of the way: a foot fell 870-1000 cm/s on the last
//     poses (the body 360-420), was still 18-35 cm up on the last pose of the air, and the leg limiter (400 cm/s) cut in on
//     five to nine poses of every hop.
//  3. THE FEET WERE NOT OVER WHERE THEY LAND: the game stands them at (+-23, -+11) cm on the deck after EVERY landing traced
//     (regular, fakie, nollie, switch; turned or not); the tuck has them 3-11 cm from there, and the blend slid them over.
// Now the last part of the air (from HJN_Air's 6th number, HopPlan 0.6, with w = its smoothstep) is one plan, worked out
// on every pose from that pose's own numbers, in the DECK's frame:
//   the hips    are let down by w x E along the deck's up, E = how far they stand above where the longer-reaching leg, at
//               'bend' (0.92) of its length, has its foot on its landing spot once the lift (HJN_Air's 8th number) is gone
//               -- so at touchdown the hips are exactly a bent leg over the board, still falling at the lift's own speed;
//   each leg    goes from the tuck's length to the length it will have at touchdown by the same w (a leg that is already
//               longer than that, the mini's, just rides down): its foot is that far from the hip, over the place
//   each foot   is carried to by w: from where the body has it to the spot the game stood that foot on at the last landing
//               that came down this way round (learned at the end of every landing's blend; none known = no carry), and
//               turned to the way it stood there; a foot that meets the deck early stays on it, the leg takes up the rest.
// At touchdown nothing is left to make up: the feet are within a pose's fall of their spots, the legs bent. After it the
// hips' let-down is given back evenly over g_sinkFade (0.22 s, LandSink: on every pose, the landing blend's or not), which
// leaves the game's own crouch its shape and makes the hips' fall one decelerating movement. The leg limiter stands by
// while the plan is on (its legs lengthen 330 cm/s at most by construction).
// (The lift is the Lua's number for this frame. If the mesh shows it a frame late the hips end the air up to 7 cm LOWER
// than planned -- the safe side: the feet meet the deck a pose early. The 'plan' lines log the mesh origin's height over
// the deck beside it, so the next log says which it is.)
volatile float g_planFrom = 0.0f, g_planBend = 0.92f, g_planLua = 0.0f;   // HJN_Air's 6th, 7th and 8th numbers: where the plan begins (0 = v93's reach), the leg at touchdown, the Lua's lift now (cm)
struct LandSpot { V3 p[2]; Q4 q[2]; int n; };
// (v95) NO SPOTS TO AIM AT IN A TURNED HOP. "After the jump apex the body's still turning on its way down, and the feet
// have like these target destinations. That's what's causing the warping, because the leg trajectory and the feet are in
// two different places. Why can't we just let him land on the board how he lands? And then the game will probably slide
// him into position anyway." The recordings say the same: the carry has both feet on their spots at 80 % of the air
// (22:53:51: L -19 +11 / R +24 +13 from pose 66 on) while the mesh has 40 deg still to turn -- the hips wind on over
// feet that have stopped; in the crouched 180 the left foot runs 11 cm ahead of the body across the deck. And where the
// body itself has the feet at touchdown is 3-7 cm from those spots anyway. HJN_Set("hopcarry"): 0 = no feet carried in
// any hop, 1 = only in a hop that lands the way it took off (the default: those looked right), 2 = every hop (v94).
// A hop that turns comes down where the body has its feet; the landing blend slides them to the game's from there.
volatile int g_planCarry = 1;
// (v100) A HOP THAT TURNS LANDS ON ITS SPOTS TOO -- ONCE THE TURN IS NEARLY DONE. "The 180 mini hippie jumps: he's landing
// way off the board. He used to be dead on." Since v95 a hop that turns comes down where the body has its feet and is
// slid into place after touchdown (the carry of v94 had the feet on their spots with 40 deg of the turn still to go). Where
// the body has them is the mini hop's kept place under the hips, kept from whatever pose the turn began on: in the
// recording of 5 Oct 14:25:45 the turn began 50 ms in and the feet came down 23 and 25 cm off the deck's middle line, both
// ankles 13 cm outside its edge; on 12:04:29 it began at 100 ms and they came down at 16 and 11. Now the feet of a turned
// hop are carried to the spots its landing will stand them on as well -- by the share of the turn that is done: nothing
// while more than 60 deg are left, all of it from 15 (the Lua says how far the body still has to turn: "hopturnleft").
// A hop that does not turn has 0 left and is carried as before. HJN_Set("hopturn", 0) = v95's (HopCarry's own 1).
volatile float g_hopTurnLeft = 0.0f; volatile int g_planTurn = 1;
LandSpot g_spot[2] = {};              // [0] the left foot further along the deck's +X than the right, [1] the other way round
int    g_planO = 0; bool g_planNew = false;               // which way round the feet stood at take-off (+1 / -1; 0 not seen yet)
volatile bool g_planGuess = false;                        // the Lua does not know yet how the hop will land (HJN_Air's 4th number + 2)
float  g_sink = 0.0f, g_sinkTd = 0.0f, g_sinkNow = 0.0f; volatile float g_sinkFade = 0.22f; double g_sinkT0 = 0.0, g_sinkAt = 0.0; bool g_sinkOn = false, g_sinkArm = false;
float  g_planE = 0.0f, g_planW = 0.0f, g_planCw = 0.0f;   // (review) g_planCw: the carry's own ease-in
V3     g_planAim[2] = { { 0, 0, 0 }, { 0, 0, 0 } }; bool g_planAimOk = false; LONG g_planLogs = 0, g_spotLogs = 0; int g_landNote = 0;
bool SpotFor(int o, int k, V3& p, Q4& q) {
    const int s = o > 0 ? 0 : 1;
    if (g_spot[s].n > 0) { p = g_spot[s].p[k]; q = g_spot[s].q[k]; return true; }
    if (g_spot[1 - s].n > 0) {                            // only the other way round is known: the same stance, half a turn round on the deck
        p = v3(-g_spot[1 - s].p[k].x, -g_spot[1 - s].p[k].y, g_spot[1 - s].p[k].z);
        q = qnorm(qmul(q4(0.0f, 0.0f, 1.0f, 0.0f), g_spot[1 - s].q[k]));
        return true;
    }
    return false;
}
// where the game has the feet on the last pose of a landing's blend: that is where the next landing's feet go
void SpotLearn(const TF* gf) {
    if (g_planFrom <= 0.01f) return;
    V3 p[2]; Q4 q[2]; bool ok = true;
    for (int k = 0; k < 2; k++) {
        p[k] = qinv(g_dq, sub(gf[k].p, g_dp));
        q[k] = qnorm(qmul(qconj(g_dq), gf[k].q));
        if (!finite3(p[k]) || fabsf(p[k].x) > 40.0f || fabsf(p[k].y) > 20.0f || p[k].z < 3.0f || p[k].z > 32.0f) ok = false;
    }
    const float dx = p[0].x - p[1].x;
    if (fabsf(dx) < 24.0f || fabsf(dx) > 75.0f) ok = false;
    if (!ok) {
        if (InterlockedIncrement(&g_spotLogs) <= 120)
            Log("landing spots: NOT learned from this landing -- the game's feet at the end of the blend L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f) on the deck do not look like a stance", p[0].x, p[0].y, p[0].z, p[1].x, p[1].y, p[1].z);
        return;
    }
    LandSpot& S = g_spot[dx > 0.0f ? 0 : 1];
    for (int k = 0; k < 2; k++) {
        S.p[k] = S.n > 0 ? lerp(S.p[k], p[k], 0.5f) : p[k];
        S.q[k] = S.n > 0 ? qslerpTo(S.q[k], q[k], 0.5f) : q[k];
    }
    S.n++;
    if (InterlockedIncrement(&g_spotLogs) <= 120) {
        if (g_planAimOk)
            Log("landing spots: the game stood the feet at L (%+.0f %+.0f) R (%+.0f %+.0f) on the deck (the left foot toward its %s end, sample %d) -- this landing was planned for L (%+.0f %+.0f) R (%+.0f %+.0f): %.1f / %.1f cm off",
                p[0].x, p[0].y, p[1].x, p[1].y, dx > 0.0f ? "+X" : "-X", S.n, g_planAim[0].x, g_planAim[0].y, g_planAim[1].x, g_planAim[1].y,
                sqrtf((p[0].x - g_planAim[0].x) * (p[0].x - g_planAim[0].x) + (p[0].y - g_planAim[0].y) * (p[0].y - g_planAim[0].y)),
                sqrtf((p[1].x - g_planAim[1].x) * (p[1].x - g_planAim[1].x) + (p[1].y - g_planAim[1].y) * (p[1].y - g_planAim[1].y)));
        else
            Log("landing spots: the game stood the feet at L (%+.0f %+.0f) R (%+.0f %+.0f) on the deck (the left foot toward its %s end, sample %d) -- this landing had no spots to plan for",
                p[0].x, p[0].y, p[1].x, p[1].y, dx > 0.0f ? "+X" : "-X", S.n);
    }
}
bool HopPlan(const void* mesh) {
    g_planW = 0.0f; g_planE = 0.0f;
    if (g_pelvis < 0 || g_foot[0] < 0 || g_foot[1] < 0 || g_thigh[0] < 0 || g_thigh[1] < 0 || g_calf[0] < 0 || g_calf[1] < 0) { g_sink = 0.0f; return false; }
    if (!g_boardOk || !DeckXf(mesh)) { g_sink = 0.0f; return false; }
    const V3 up = qrot(g_dq, v3(0.0f, 0.0f, 1.0f));
    V3 fd[2], jd[2];
    for (int k = 0; k < 2; k++) {
        fd[k] = qinv(g_dq, sub(g_Ct[g_foot[k]].p, g_dp));        // the foot and the hip joint on the deck, as the pose has them
        jd[k] = qinv(g_dq, sub(g_Ct[g_thigh[k]].p, g_dp));
    }
    if (g_planNew) {                                             // which way round the feet stand, on the first poses of the hop
        const float dx = fd[0].x - fd[1].x;
        if (fabsf(dx) > 10.0f) { g_planO = dx > 0.0f ? 1 : -1; g_planNew = false; }
    }
    const float from = clampf(g_planFrom, 0.3f, 0.95f);
    const float w = Sm01((g_hopFrac - from) / (1.0f - from));
    if (w <= 0.0f) { g_sink = 0.0f; g_planAimOk = false; return false; }
    if (g_stCur >= 0) UseStance(g_stCur);                        // (review) only while the plan is on, as v93's reach did
    const float lift = g_planLua / fmaxf(g_ms, 0.1f);            // (the Lua's cm are the world's; everything here is in the mesh's own units)
    V3 sp[2]; Q4 sq[2];
    bool have = g_planO != 0 && !g_planGuess                     // (while the landing is not decided the feet come down where the body has them)
        && (g_planCarry >= 2 || (g_planCarry == 1 && (!g_hopFlip || g_planTurn != 0)));   // (v95) not in a turned hop at 1 -- (v100) in one too, by how much of its turn is done
    for (int k = 0; k < 2 && have; k++) have = SpotFor(g_planO * (g_hopFlip ? -1 : 1), k, sp[k], sq[k]);
    g_planCw = have ? fminf(g_planCw + 0.5f, 1.0f) : 0.0f;       // (review) over two poses from the pose the landing is decided on
    const float cw = g_planCw * ((g_planTurn != 0 && g_planCarry < 2) ? 1.0f - Sm01((fabsf(g_hopTurnLeft) - 15.0f) / 45.0f) : 1.0f);   // (v100)
    float ride[2], L[2], C[2], E = -1.0e9f;
    for (int k = 0; k < 2; k++) {
        ride[k] = (g_stCur >= 0 && g_dFootOk[k]) ? g_uFootP[k].z : 15.0f;
        L[k] = len(sub(g_Ct[g_calf[k]].p, g_Ct[g_thigh[k]].p)) + len(sub(g_Ct[g_foot[k]].p, g_Ct[g_calf[k]].p));
        C[k] = clampf(g_planBend, 0.7f, 0.985f) * L[k];
        const float ax = (have ? fd[k].x + (sp[k].x - fd[k].x) * cw : fd[k].x) - jd[k].x, ay = (have ? fd[k].y + (sp[k].y - fd[k].y) * cw : fd[k].y) - jd[k].y;
        const float need = (jd[k].z - ride[k]) - lift - sqrtf(C[k] * C[k] - fminf(ax * ax + ay * ay, 0.7f * C[k] * C[k]));
        if (need > E) E = need;                                  // how far this hip stands over where its leg reaches its spot, once the lift is gone
    }
    E = clampf(E, 0.0f, 45.0f);
    const float S = E * w;
    if (S > 0.02f) SetComp(g_pelvis, g_Ct[g_pelvis].q, sub(g_Ct[g_pelvis].p, mul(up, S)));
    g_sink = S; g_planE = E; g_planW = w; g_sinkAt = NowS();
    float tuckL[2], ctdL[2], carry[2];
    for (int k = 0; k < 2; k++) {
        const V3 J = g_Ct[g_thigh[k]].p, F0 = g_Ct[g_foot[k]].p;                 // (both let down with the hips)
        const V3 j = qinv(g_dq, sub(J, g_dp)), f0 = qinv(g_dq, sub(F0, g_dp));
        const float tuck = len(sub(F0, J));
        const float tx = have ? f0.x + (sp[k].x - f0.x) * cw : f0.x, ty = have ? f0.y + (sp[k].y - f0.y) * cw : f0.y;
        const float ax = tx - j.x, ay = ty - j.y;
        const float vtd = fmaxf((jd[k].z - ride[k]) - lift - E, 10.0f);         // this hip over its ankle's riding level at touchdown
        const float ctd = fminf(sqrtf(ax * ax + ay * ay + vtd * vtd), C[k]);    // ...and so this leg's length then
        const float ext = fminf(tuck + (ctd - tuck) * w, 0.985f * L[k]);
        float x = f0.x + (tx - f0.x) * w, y = f0.y + (ty - f0.y) * w;
        float dx = x - j.x, dy = y - j.y, d = sqrtf(dx * dx + dy * dy);
        const float d0 = sqrtf((f0.x - j.x) * (f0.x - j.x) + (f0.y - j.y) * (f0.y - j.y));
        const float dMax = fmaxf(0.85f * ext, fminf(d0, 0.98f * ext));          // never flatter than the pose's own leg, nor than 58 deg from the deck's up
        if (d > dMax && d > 1.0e-3f) { x = j.x + dx * dMax / d; y = j.y + dy * dMax / d; d = dMax; }
        float z = j.z - sqrtf(fmaxf(ext * ext - d * d, 0.0f));
        if (z < ride[k]) z = ride[k];                                           // on the deck already: the leg takes up the rest
        Q4 fq = g_Ct[g_foot[k]].q;
        if (have) fq = qslerpTo(fq, qnorm(qmul(g_dq, sq[k])), w * cw);
        Leg(k, add(g_dp, qrot(g_dq, v3(x, y, z))), fq);
        tuckL[k] = tuck; ctdL[k] = ctd;
        carry[k] = sqrtf((x - f0.x) * (x - f0.x) + (y - f0.y) * (y - f0.y));
        g_reachLast[k] = f0.z - z; g_reachSide[k] = carry[k];
        g_planAim[k] = have ? sp[k] : v3(f0.x, f0.y, ride[k]);
    }
    g_planAimOk = have;
    if (g_traceFrames > 0 && InterlockedIncrement(&g_planLogs) <= 3000) {
        const V3 pd = qinv(g_dq, sub(g_Ct[g_pelvis].p, g_dp));
        Log("plan +%d: frac %.3f w %.2f | lift %.1f, the mesh origin %.1f over the deck | hips' excess %.1f, let down %.1f | legs (tuck > now, of touchdown) L %.0f > %.0f of %.0f R %.0f > %.0f of %.0f | spots %s L (%+.0f %+.0f) R (%+.0f %+.0f), carried L %.1f R %.1f | hips on the deck %+.0f %+.0f %+.0f",
            g_traceN + 1, g_hopFrac, w, lift, -dot(g_dp, up), E, S,
            tuckL[0], len(sub(g_Ct[g_foot[0]].p, g_Ct[g_thigh[0]].p)), ctdL[0], tuckL[1], len(sub(g_Ct[g_foot[1]].p, g_Ct[g_thigh[1]].p)), ctdL[1],
            have ? (g_hopFlip ? "learned (half turn)" : "learned") : "none", g_planAim[0].x, g_planAim[0].y, g_planAim[1].x, g_planAim[1].y, carry[0], carry[1], pd.x, pd.y, pd.z);
    }
    return true;
}
// the hips' let-down, given back after touchdown (called on every pose, before the hold and the landing blend)
bool LandSink(const void* mesh) {
    const double t = NowS();
    if (!g_sinkOn) {                                                            // a hop that ended with no landing call (handed back to the game's own air): given back all the same
        if (g_sink > 0.05f && g_airFrames <= 0 && t - g_sinkAt < 0.1) g_sinkOn = g_sinkArm = true;
        else { if (g_airFrames <= 0) g_sink = 0.0f; return false; }
    }
    if (g_sinkArm) { g_sinkArm = false; g_sinkTd = g_sink; g_sink = 0.0f; g_sinkT0 = (g_airWok && t > g_airWt && (t - g_airWt) < 0.08) ? g_airWt : t; }   // counted from the last pose of the air
    const float el = (float)(t - g_sinkT0);
    const float s = g_sinkTd * (1.0f - el / fmaxf(g_sinkFade, 0.05f));
    if (s <= 0.05f || el < 0.0f || g_pelvis < 0 || g_foot[0] < 0 || g_foot[1] < 0 || !g_boardOk || !DeckXf(mesh)) { g_sinkOn = false; g_sinkNow = 0.0f; return false; }
    const V3 up = qrot(g_dq, v3(0.0f, 0.0f, 1.0f));
    V3 fp[2]; Q4 fq[2];
    for (int k = 0; k < 2; k++) { fp[k] = g_Ct[g_foot[k]].p; fq[k] = g_Ct[g_foot[k]].q; }
    for (int k = 0; k < 2; k++) {                                               // (review) a foot the game has floating comes down with the hips, as far as its riding height
        const float ride = (g_stCur >= 0 && g_dFootOk[k]) ? g_uFootP[k].z : 15.0f;
        V3 f = qinv(g_dq, sub(fp[k], g_dp));
        if (f.z > ride) { f.z = fmaxf(f.z - s, ride); fp[k] = add(g_dp, qrot(g_dq, f)); }
    }
    SetComp(g_pelvis, g_Ct[g_pelvis].q, sub(g_Ct[g_pelvis].p, mul(up, s)));
    for (int k = 0; k < 2; k++) Leg(k, fp[k], fq[k]);
    g_sinkNow = s;
    return true;
}
// a landing's poses, for the log (while a trace runs): what the plan and the hold did, and the GAME's own lines beside the drawn ones
void LandNote(const void* mesh) {
    if (g_landNote <= 0) return;
    g_landNote--;
    if (g_traceFrames <= 0 || g_pelvis < 0 || g_thigh[0] < 0 || g_thigh[1] < 0 || g_uarm[0] < 0 || g_uarm[1] < 0 || g_foot[0] < 0 || g_foot[1] < 0 || !g_boardOk || !DeckXf(mesh)) return;
    if (InterlockedIncrement(&g_planLogs) > 3000) return;
    const V3 up = qrot(g_dq, v3(0.0f, 0.0f, 1.0f));
    const V3 pd = qinv(g_dq, sub(g_Ct[g_pelvis].p, g_dp)), pg = qinv(g_dq, sub(g_C[g_pelvis].p, g_dp));
    const float mw = MeshYaw(mesh);
    Log("land +%d: hips let down %.1f (of %.1f at touchdown) | mesh %.0f, its lag %+.0f | hips' line in the world: the game's %.0f drawn %.0f, shoulders': the game's %.0f drawn %.0f | hips on the deck: the game's %+.0f %+.0f %+.0f drawn %+.0f %+.0f %+.0f | the mesh origin %.1f over the deck",
        g_traceN + 1, g_sinkNow, g_sinkTd, mw, (g_holdFrames > 0 && g_holdLag >= 0) ? g_holdErr : 0.0f,
        wrap180(mw + yawOf(sub(g_C[g_thigh[0]].p, g_C[g_thigh[1]].p))), wrap180(mw + yawOf(sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p))),
        wrap180(mw + yawOf(sub(g_C[g_uarm[0]].p, g_C[g_uarm[1]].p))), wrap180(mw + yawOf(sub(g_Ct[g_uarm[0]].p, g_Ct[g_uarm[1]].p))),
        pg.x, pg.y, pg.z, pd.x, pd.y, pd.z, -dot(g_dp, up));
}
// ==== (v84) THE LEGS REACH FOR THE BOARD, IN EITHER STANCE =============================================================
// The Lua asks the game for the reach (the anim instance's LandHeightRatio over the last fifth of the air). Riding SWITCH
// the game's pose follows it (hip to ankle 25 -> 54 cm before touchdown, 23:55:18); riding REGULAR it does not move at
// all (36/27 cm to the last pose of the air in every regular hop traced: 23:26:08, 23:54:25, 23:54:27, 23:55:15) -- and
// a straight hop had no landing blend either, so the legs went from the tuck to straight, 36-45 cm, in ONE pose: the
// "warp point". Now the reach is made here as well (HJN_Air's third number, the same 0..1 the game is given): before it
// begins each foot's place against the hips is remembered -- the tuck -- and from then on the foot is no higher over its
// riding height on the drawn deck than (1 - reach) of where the tuck would have it now. A pose the game has already
// brought lower than that is left alone.
bool HopReach(const void* mesh) {
    g_reachLast[0] = g_reachLast[1] = 0.0f; g_reachSide[0] = g_reachSide[1] = 0.0f;
    if (g_planFrom > 0.01f) return HopPlan(mesh);                // (v94) the planned landing does all of it
    g_sink = 0.0f;
    if (g_pelvis < 0 || g_foot[0] < 0 || g_foot[1] < 0 || g_thigh[0] < 0 || g_thigh[1] < 0) return false;
    const float r = clampf(g_hopReach, 0.0f, 1.0f);
    const V3 pp = g_Ct[g_pelvis].p;
    if (r <= 0.0005f) {
        for (int k = 0; k < 2; k++) g_reachRel[k] = sub(g_Ct[g_foot[k]].p, pp);
        g_reachHave = true;
        return false;
    }
    if (!g_reachHave || !g_boardOk || !DeckXf(mesh)) return false;
    const V3 up = qrot(g_dq, v3(0.0f, 0.0f, 1.0f));
    if (g_stCur >= 0) UseStance(g_stCur);
    // (v86) TO ITS LANDING SPOT, NOT ONLY DOWN. "Maybe it's not so much a timing issue as a foot target issue -- where the foot
    // lands: the warping seems to be compensating for the landing position; it depends on velocity, or whether he is turning
    // slightly." The reach brought each foot straight down from where the tuck had it (under the body, the feet a hip's width
    // apart) and the touchdown then moved it to its riding spot (40 cm apart along the board, wherever the board was under
    // a leaning body) inside the landing blend's few poses. Now the same reach carries the foot ALONG THE DECK'S PLANE to
    // the spot it will stand on -- its own riding spot; after a half turn the OTHER foot's, across the board from it (the
    // rider turns round on the same two spots: stance #0's L +11 -10 / R -29 -12 becomes #5's L -26 +11 / R +13 +10) -- and
    // turns it to the way it will stand there, by the reach's own share (0 at its start, all of it at touchdown).
    // (v87) ...AND NOT SIDEWAYS. v86's carry went to the spots of the stance last RIDDEN (the crouch's: L -10 / R +30) while
    // the game lands in another (L -23 / R +16) -- which is where the tuck has the feet all through the air (the trace of
    // 13:38:34: -22 -> -8 and +18 -> +27 over the reach, then back at touchdown). The reach is height only again; where a
    // foot stands along the board is the landing blend's, measured against the board (LandBlend).
    bool changed = false;
    for (int k = 0; k < 2; k++) {
        const float ride = (g_stCur >= 0 && g_dFootOk[k]) ? g_uFootP[k].z : 15.0f;   // where the ankle rides over the deck
        const V3 F0 = g_Ct[g_foot[k]].p;
        const float href = dot(sub(add(pp, g_reachRel[k]), g_dp), up) - ride;        // where the tuck would have it now
        const float h = dot(sub(F0, g_dp), up) - ride;
        float hNew = h;
        if (href > 1.0f && href <= 200.0f) { const float want = href * (1.0f - r); if (h > want + 0.5f) hNew = want; }
        V3 F = sub(F0, mul(up, h - hNew));
        Q4 fq = g_Ct[g_foot[k]].q;
        if (h - hNew < 0.05f && g_reachSide[k] < 0.05f) continue;
        Leg(k, F, fq);
        g_reachLast[k] = h - hNew;
        changed = true;
    }
    return changed;
}
// ==== (v87) THE LANDING BLEND, AGAINST THE BOARD ======================================================================
// "If you move the feet to match the board at the end of the jump, it still does the warping thing. I just did a hippie jump
// with no warping -- check the very last one." The last two of 4 Oct, pose by pose, the feet in the DECK's frame:
//   13:39:41 (clean, riding switch): through the reach L -25 / R +18 cm along, touchdown -25 / +12, then -22, -19, -18.
//   13:38:34 (warped, riding regular): through the reach L -22 -> -8, R +18 -> +27 (v86 carried them toward the stance last
//   RIDDEN -- the crouch's, #5 -- while the game lands in another, #1: -23 / +16, which is where the tuck already has them),
//   touchdown +7 / +36, then -4 / +29, -16 / +20, -22 / +15: 30 cm along the board and back inside four poses.
// The touchdown jump is the blend's own: it kept the feet where they were against the HIPS, and on the touchdown pose the
// animation's hips move over the board (12 cm along it here, and 35 deg round over three poses; 1-2 cm in the clean one).
// Now the feet are remembered against the BOARD (the hips' way is kept for a pose with no deck) and blend from there onto
// the game's; the hips themselves are eased over from where they stood over the board on the last pose of the air. A board
// whose frame has turned half round under the feet (the 180's deck swap) is told from the hips' own memory of the feet.
V3   g_airDkP[2]; Q4 g_airDkQ[2]; V3 g_airDkPel = { 0, 0, 0 }; bool g_airDkHave = false;
bool g_landFirst = false, g_landFlip0 = false; V3 g_landPelOff = { 0, 0, 0 }; LONG g_landLogs = 0;
bool g_landTurned = false; float g_landDrop = 0.0f;                                     // (v89)
float g_airVz[2] = { 0, 0 }, g_airZp[2] = { 0, 0 }; double g_airZt = 0.0;               // (v88) each foot's fall on the deck, cm/s
float g_landZ[2] = { 0, 0 }, g_landZ0[2] = { 0, 0 }, g_landVz[2] = { 0, 0 }; double g_landT = 0.0; int g_landPose = 0, g_landDownAt[2] = { 0, 0 }; bool g_landPlan = false;
// (v96) ...AND THE KNEES ARE BLENDED AS THE FEET ARE. The same recordings, the first four poses after a 180's touchdown, in
// the world: the hips stand still (the hold), the ankles stand still (this blend) -- and the knees do not: at 00:11:11 the
// left knee is 8, 13, 4, -2, 5 cm along the world's x from the mesh's origin on the last pose of the air and landing poses
// 1-4, and in each of the four 180s recorded a knee steps 15-20 cm in ONE pose on landing pose 2 or 4 (beyond the speed it
// had: 16.3, 15.2, 15.8, 20.2). The feet come out of the air against the BOARD and go to the game's by the blend; the
// knee's way was re-read on every pose from the game's landing pose, which hangs off a mesh that is 45, 34, 25, 19 deg
// round and whose straight, squeezed leg's knee is noise (-150, -163, -106, -117 deg round the leg on poses 1-4).
// Now AirSave keeps each knee's way against the board beside the foot's place, and through a TURNED landing's blend the
// leg is solved with the way going from that to the pose's by the blend's own weight: the largest knee step on landing
// poses 1-10 becomes 7.9, 7.8, 7.7, 7.6 cm (what is left is the touchdown pose itself, where the feet's fall stops);
// ankles and hips are not touched. A straight landing is as it was. HJN_Set("landknee", 0) = v95.
V3 g_airDkPole[2] = { { 0, 0, 0 }, { 0, 0, 0 } }; volatile int g_landKnee = 1; LONG g_landKneed = 0;
float BoneLen(const TF* P, int a, int b) { return (a >= 0 && b >= 0) ? len(sub(P[a].p, P[b].p)) : 0.0f; }
void AirSave(const void* mesh) {
    if (g_pelvis < 0 || g_foot[0] < 0 || g_foot[1] < 0) return;
    if (g_thigh[0] >= 0 && g_thigh[1] >= 0 && g_uarm[0] >= 0 && g_uarm[1] >= 0) {   // (v94) the body's heading in the world, for the landing's springs
        const double tw = NowS(); const float mwA = MeshYaw(mesh);
        const float wy[2] = { mwA + yawOf(sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p)), mwA + yawOf(sub(g_Ct[g_uarm[0]].p, g_Ct[g_uarm[1]].p)) };
        const float dtw = (float)(tw - g_airWt);
        for (int i = 0; i < 2; i++) {
            g_airWv[i] = (g_airWok && dtw > 0.004f && dtw < 0.05f) ? wrap180(wy[i] - g_airWy[i]) / dtw : 0.0f;
            g_airWy[i] = wy[i];
        }
        g_airWt = tw; g_airWok = true;
    }
    const Q4 pq = g_Ct[g_pelvis].q; const V3 pp = g_Ct[g_pelvis].p;
    for (int k = 0; k < 2; k++) {
        g_airRelP[k] = qinv(pq, sub(g_Ct[g_foot[k]].p, pp));
        g_airRelQ[k] = qmul(qconj(pq), g_Ct[g_foot[k]].q);
    }
    g_airHave = true;
    g_airDkHave = false;
    if (g_boardOk && DeckXf(mesh)) {
        for (int k = 0; k < 2; k++) {
            g_airDkP[k] = qinv(g_dq, sub(g_Ct[g_foot[k]].p, g_dp));
            g_airDkQ[k] = qmul(qconj(g_dq), g_Ct[g_foot[k]].q);
        }
        for (int k = 0; k < 2; k++)                                // (v96) the knee's way on this pose, against the board as the feet are
            g_airDkPole[k] = (g_thigh[k] >= 0 && g_calf[k] >= 0)
                ? qinv(g_dq, norm(sub(g_Ct[g_calf[k]].p, add(g_Ct[g_thigh[k]].p, mul(sub(g_Ct[g_foot[k]].p, g_Ct[g_thigh[k]].p), 0.5f))))) : v3(0.0f, 0.0f, 0.0f);
        g_airDkPel = qinv(g_dq, sub(pp, g_dp));
        g_airDkHave = true;
        const double t = NowS(); const float dt = (float)(t - g_airZt);
        for (int k = 0; k < 2; k++) {
            g_airVz[k] = (dt > 0.004f && dt < 0.05f) ? (g_airDkP[k].z - g_airZp[k]) / dt : 0.0f;
            g_airZp[k] = g_airDkP[k].z;
        }
        g_airZt = t;
    }
    g_landFirst = true;
}
// (v88) THE FALL IS CARRIED ON TO THE BOARD. "The 180s are still out of whack: it's stretching and/or his feet stop and hold
// in the air. Like the feet are ahead of the body and it's a caterpillar: one segment has to catch up with the other.
// Maybe really analyse the flow and the physics of it and pre-plan everything." The 180 of 14:15:31, each foot's height
// over where it rides: through the reach 102, 96, 87, 74, 61, 47, 33 cm -- 14 cm a pose -- then from the touchdown pose 33,
// 31, 29, 26, 22, 17, 12, 7, 3, 0: v87 froze the feet at their last height over the board and eased them onto the game's
// over the blend's ten poses (LandFeetFrames; a straight hop has four, which is why those look right). The feet stopped in
// the air while the hips kept falling (100 -> 58 cm over the board), the legs folding 63 -> 50 and out again. Now the
// motion is one fall: each foot keeps the speed it had on the last pose of the air (450 cm/s at least, and enough to be
// down a pose before the blend ends) until it is at its riding height on the deck; its place ALONG the deck and the way
// it is turned go to the game's over the same stretch (or the blend's, whichever is sooner), so it lands where it will
// stand; from then it stays on the deck and its height goes to the game's with the blend. A leg may still grow no faster
// than a hop's legs do (HopLegs runs through the landing too), and the hips come down onto the planted feet -- the
// landing's own crouch.
bool LandBlend(const void* mesh) {
    if (!g_airHave || g_landTotal <= 0 || g_pelvis < 0 || g_foot[0] < 0 || g_foot[1] < 0) return false;
    const float f = (float)(g_landTotal - g_landFrames + 1) / (float)g_landTotal;
    float s = clampf(f, 0.0f, 1.0f); s = s * s * (3.0f - 2.0f * s);
    const Q4 pq = g_Ct[g_pelvis].q; const V3 pp = g_Ct[g_pelvis].p;
    const TF gf[2] = { g_Ct[g_foot[0]], g_Ct[g_foot[1]] };          // the game's feet on this pose
    V3 bp[2]; Q4 bq[2];
    for (int k = 0; k < 2; k++) { bp[k] = add(pp, qrot(pq, g_airRelP[k])); bq[k] = qmul(pq, g_airRelQ[k]); }
    const bool first = g_landFirst; g_landFirst = false;
    if (first) { g_landPose = 0; g_landPlan = false; g_landTurned = g_hopFlip != 0; g_landDrop = 0.0f; }
    g_landPose++;
    bool deck = g_airDkHave && g_boardOk && DeckXf(mesh);
    bool flip = false;
    V3 shift = v3(0.0f, 0.0f, 0.0f);
    if (deck) {
        const Q4 z180 = q4(0.0f, 0.0f, 1.0f, 0.0f);
        V3 a[2], b[2]; float da = 0.0f, db = 0.0f;
        for (int k = 0; k < 2; k++) {
            a[k] = add(g_dp, qrot(g_dq, g_airDkP[k]));
            b[k] = add(g_dp, qrot(g_dq, v3(-g_airDkP[k].x, -g_airDkP[k].y, g_airDkP[k].z)));
            da += len(sub(a[k], bp[k])); db += len(sub(b[k], bp[k]));
        }
        flip = db < da;                                              // the deck's frame turned half round since the air
        if (fminf(da, db) > 90.0f) deck = false;                     // neither is near where the body has them: the hips' way
        else {
            for (int k = 0; k < 2; k++) {
                bp[k] = flip ? b[k] : a[k];
                bq[k] = qnorm(qmul(g_dq, flip ? qmul(z180, g_airDkQ[k]) : g_airDkQ[k]));
            }
            if (first) {
                g_landFlip0 = flip;
                V3 off = sub(g_airDkPel, qinv(g_dq, sub(pp, g_dp)));
                off.z = 0.0f;
                const float l = len(off);
                g_landPelOff = (flip || l < 1.0f) ? v3(0.0f, 0.0f, 0.0f) : (l > 25.0f ? mul(off, 25.0f / l) : off);
                for (int k = 0; k < 2; k++) {
                    const float ride = (g_stCur >= 0 && g_dFootOk[k]) ? g_uFootP[k].z : 15.0f;
                    g_landZ[k] = g_landZ0[k] = g_airDkP[k].z;
                    const float need = (g_landZ0[k] - ride) / (fmaxf((float)g_landTotal - 1.0f, 1.0f) * 0.0156f);
                    g_landVz[k] = -fmaxf(fmaxf(clampf(-g_airVz[k], 0.0f, 1100.0f), 450.0f), need);
                    g_landDownAt[k] = 0;
                }
                g_landT = g_airZt; g_landPlan = true;
                if (InterlockedIncrement(&g_landLogs) <= 80)
                    Log("landing: against the board%s, the blend %d poses -- the feet L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f) on the deck, falling %.0f / %.0f cm/s on the last pose of the air, carried on at %.0f / %.0f to their riding height; the hips stand %.0f cm from where they were over it%s",
                        flip ? " (its frame turned half round under the feet)" : "", g_landTotal,
                        g_airDkP[0].x, g_airDkP[0].y, g_airDkP[0].z, g_airDkP[1].x, g_airDkP[1].y, g_airDkP[1].z,
                        -g_airVz[0], -g_airVz[1], -g_landVz[0], -g_landVz[1], l, flip ? "" : ": eased over");
            }
            if (flip != g_landFlip0) g_landPelOff = v3(0.0f, 0.0f, 0.0f);
            shift = qrot(g_dq, mul(g_landPelOff, 1.0f - s));
        }
    }
    if (!deck && first) {
        g_landPelOff = v3(0.0f, 0.0f, 0.0f);
        if (InterlockedIncrement(&g_landLogs) <= 80) Log("landing: against the hips over %d poses (no drawn deck on the touchdown pose)", g_landTotal);
    }
    const bool crossed = flatAngle(sub(gf[0].p, gf[1].p), sub(bp[0], bp[1])) > 100.0f;
    if (crossed) { s = 0.0f; InterlockedIncrement(&g_landCrossed); }
    if (s > 0.999f) { if (deck) SpotLearn(gf); return false; }   // (v94) the blend is over: where the game has the feet now is where the next landing's feet go
    if (!deck || !g_landPlan) {                                      // the hips' way: as it was before v87
        for (int k = 0; k < 2; k++) {
            const V3 F = lerp(bp[k], gf[k].p, s);
            Q4 st = qmul(gf[k].q, qconj(bq[k]));
            if (st.w < 0.0f) st = q4(-st.x, -st.y, -st.z, -st.w);
            Leg(k, F, qnorm(qmul(qscale(st, s), bq[k])));
        }
        return true;
    }
    const double tNow = NowS();
    const float dt = clampf((float)(tNow - g_landT), 0.004f, 0.035f); g_landT = tNow;
    if (len(shift) > 0.05f) SetComp(g_pelvis, pq, add(pp, shift));   // the hips ease over from where they stood over the board
    // (v89) A TURNED LANDING: THE PLACE AND THE TURN BY THE BLEND, NOT BY THE FALL. "The 180 minis still have a pretty bad foot
    // warp, the worst by far." Two readers found the same line: v88 took a foot's place along the deck and its rotation to
    // the game's as fast as it FELL (max(blend, fall)). A mini arrives 9-13 cm over the board, so on landing pose 2 the feet
    // went all the way to the game's -- and after a 180 the game's feet on that pose hang off a mesh that is still 45 deg
    // round (the actor is turned a step late, the game's foot pull is 0.10): L (-21 +4) -> (-6 +25), R (+19 +10) -> (+17 -6)
    // in ONE pose (18:13:25), 7-26 cm in every 180 traced, then a slide back over eight poses. v87, which used the blend's
    // own weight here, moved 1-2 cm a pose. So after a turn the place and the rotation go by the blend again (the fall is
    // kept); a straight hop, whose game feet are right at once, keeps v88's. Also for a turned landing: a game foot that
    // is still floating is not followed back UP (its share comes in with the blend's cube), and the hips come down for a
    // leg that cannot reach its foot (the game's landing poses have the legs straight, 5-10 cm short of the board: the
    // feet hung 22, 13, 13, 11 cm over it while the log said 'down') -- 25 cm at most, 8 cm a pose, gone with the blend.
    V3 Fk[2]; Q4 Qk[2]; bool dn[2] = { false, false };
    for (int k = 0; k < 2; k++) {
        const float ride = (g_stCur >= 0 && g_dFootOk[k]) ? g_uFootP[k].z : 15.0f;
        const V3 gl = qinv(g_dq, sub(gf[k].p, g_dp));                // the game's foot on the deck
        g_landZ[k] = fmaxf(g_landZ[k] + g_landVz[k] * dt, ride);
        const bool down = g_landZ[k] <= ride + 0.01f;
        dn[k] = down;
        const float span = g_landZ0[k] - ride;
        const float prog = (span > 1.0f) ? clampf(1.0f - (g_landZ[k] - ride) / span, 0.0f, 1.0f) : 1.0f;
        // (v94) with the plan the feet come down ON their spots and within a pose of the deck, so 'as fast as it falls' would
        // hand them to the game's feet on landing pose 1 -- and those wander for three poses (19:57:44, straight: the game's
        // left foot at -20 +8, -18 +10, -22 +11, then -23 +12 where it stays) and after a turn hang off a mesh that is still
        // round (34, 25, 19, 14 deg on poses 3-6). A planned landing keeps its feet on their spots and goes to the game's by
        // the blend's CUBE (a planned landing with no spots learned yet: by the blend, as a turned one always did)
        const float wh = crossed ? 0.0f : (g_planFrom > 0.01f ? (g_planAimOk ? s * s * s : s) : (g_landTurned ? s : fmaxf(s, prog)));
        const V3 sv = flip ? v3(-g_airDkP[k].x, -g_airDkP[k].y, 0.0f) : g_airDkP[k];
        const float dz = gl.z - ride;
        const float z = !down ? g_landZ[k] : ride + dz * ((g_landTurned && dz > 0.0f) ? s * s * s : s);
        Fk[k] = add(g_dp, qrot(g_dq, v3(sv.x + (gl.x - sv.x) * wh, sv.y + (gl.y - sv.y) * wh, z)));
        Q4 st = qmul(gf[k].q, qconj(bq[k]));
        if (st.w < 0.0f) st = q4(-st.x, -st.y, -st.z, -st.w);
        Qk[k] = qnorm(qmul(qscale(st, wh), bq[k]));
    }
    if (g_landTurned && g_thigh[0] >= 0 && g_thigh[1] >= 0 && g_calf[0] >= 0 && g_calf[1] >= 0) {
        const V3 up = qrot(g_dq, v3(0.0f, 0.0f, 1.0f));
        float need = 0.0f;
        for (int k = 0; k < 2; k++) {
            const float L = 0.985f * (BoneLen(g_Ct, g_thigh[k], g_calf[k]) + BoneLen(g_Ct, g_calf[k], g_foot[k]));
            const V3 d = sub(g_Ct[g_thigh[k]].p, Fk[k]);
            const float h = dot(d, up), side2 = dot(d, d) - h * h;
            if (h > 0.0f && L * L > side2) need = fmaxf(need, h - sqrtf(L * L - side2));
        }
        need = clampf(need, 0.0f, 25.0f) * (1.0f - s * s * s);
        g_landDrop += clampf(need - g_landDrop, -500.0f * dt, 500.0f * dt);
        if (g_landDrop > 0.1f) SetComp(g_pelvis, g_Ct[g_pelvis].q, sub(g_Ct[g_pelvis].p, mul(up, g_landDrop)));
    }
    for (int k = 0; k < 2; k++) {
        V3 kpole = v3(0.0f, 0.0f, 0.0f); bool kOk = false;         // (v96) a turned landing: the knee's way from the air's to the pose's, by the blend (s is 0 on a crossed pose: the air's)
        if (g_landKnee != 0 && g_landTurned && g_thigh[k] >= 0 && g_calf[k] >= 0) {
            const V3 own = sub(g_Ct[g_calf[k]].p, add(g_Ct[g_thigh[k]].p, mul(sub(g_Ct[g_foot[k]].p, g_Ct[g_thigh[k]].p), 0.5f)));
            const V3 was = flip ? v3(-g_airDkPole[k].x, -g_airDkPole[k].y, g_airDkPole[k].z) : g_airDkPole[k];
            if (len(own) > 0.5f && len(was) > 0.5f) {
                kpole = lerp(qrot(g_dq, was), norm(own), s);
                kOk = finite3(kpole) && len(kpole) > 0.2f;           // (the two ways opposite each other: the pose's own, as before)
            }
        }
        if (kOk) InterlockedIncrement(&g_landKneed);
        if (k == 1 && g_landFrames == 2 && g_landLogs <= 80) {     // (one line a landing, for the next log: did the two parts run?)
            Log("landing: knees -- %ld leg solves of the hop's air took the pose's own way; %ld of this landing's took the way blended from the air's", g_hopKneed, g_landKneed);
            g_hopKneed = 0; g_landKneed = 0;
        }
        const float miss = kOk ? Leg(k, Fk[k], Qk[k], V3{ 0, 0, 0 }, &kpole) : Leg(k, Fk[k], Qk[k]);
        if (dn[k] && miss < 1.5f && !g_landDownAt[k]) g_landDownAt[k] = g_landPose;   // (v89) down = the foot really got there
    }
    if (g_landFrames == 2 && g_landLogs <= 80)
        Log("landing: the feet were down on the deck on pose L %d R %d of %d", g_landDownAt[0], g_landDownAt[1], g_landTotal);
    return true;
}
// ==== (v87) A FOOT UNDER THE BOARD: WATCHED ==========================================================================
// "Sometimes his foot will get stuck below the board when doing like a throwdown." Nothing in the log of 4 Oct says which
// part did it (the throwdowns of 13:38:33 and 13:39:33: no window of the mod's on, no fault). Every pose that comes through
// here with you on the board is now checked: an ankle inside the deck's outline and less than 5 cm over its top (it rides
// ~15 over) for four poses running is logged -- as the GAME posed it and as it goes to the screen, the game's foot pull,
// and which of the mod's parts were on that pose.
int g_fuRun = 0; LONG g_fuLogs = 0;
void FootUnderWatch(const void* mesh, const void* anim, unsigned on) {
    // (v89) every hit of v87/v88 read 'riding 0' (the board thrown down or picked up, the replay), and the one real case --
    // a plant re-triggered at a throwdown -- was skipped by the plant's own bit. Riding only; nothing skipped.
    if (!g_riding || g_offBoard || g_foot[0] < 0 || g_foot[1] < 0 || !g_boardOk || !DeckXf(mesh)) { g_fuRun = 0; return; }
    V3 a[2], b[2]; bool under = false;
    for (int k = 0; k < 2; k++) {
        a[k] = qinv(g_dq, sub(g_C[g_foot[k]].p, g_dp));
        b[k] = qinv(g_dq, sub(g_Ct[g_foot[k]].p, g_dp));
        if (fabsf(b[k].x) < 45.0f && fabsf(b[k].y) < 13.0f && b[k].z < 5.0f && b[k].z > -45.0f) under = true;   // (v88) v87 took the pushing foot (25 cm off the edge) for one
    }
    if (!under) { g_fuRun = 0; return; }
    g_fuRun++;
    if (g_fuRun != 4 && (g_fuRun % 45) != 0) return;
    if (InterlockedIncrement(&g_fuLogs) > 200) return;
    float fa0 = anim ? FootA(anim, 0) : -1.0f, fa1 = anim ? FootA(anim, 1) : -1.0f;
    if (!std::isfinite(fa0)) fa0 = -1.0f;
    if (!std::isfinite(fa1)) fa1 = -1.0f;
    Log("FOOT UNDER THE BOARD, %d poses running: on the deck (along across up) the game's pose L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f), drawn L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f) | the game's foot pull L %.2f R %.2f | on this pose:%s%s%s%s%s%s%s%s%s%s%s%s%s%s | riding %d, stance #%d | plant foot %d stage %d body down %.0f",
        g_fuRun, a[0].x, a[0].y, a[0].z, a[1].x, a[1].y, a[1].z, b[0].x, b[0].y, b[0].z, b[1].x, b[1].y, b[1].z, fa0, fa1,
        (on & 0x1) ? " hop-air" : "", (on & 0x2) ? " landing-blend" : "", (on & 0x4) ? " yaw-hold" : "", (on & 0x8) ? " deck-ease" : "",
        (on & 0x80) ? " feet-hold" : "", (on & 0x100) ? " un-stretch" : "", (on & 0x200) ? " pose-hold" : "", (on & 0x400) ? " grab" : "",
        (on & 0x800) ? " riding-learn" : "", (on & 0x1000) ? " half-turn" : "", (on & 0x17ff) == 0 ? " nothing of the mod's" : "",
        (on & 0x10) ? " foot-ground" : "", (on & 0x20) ? " bone-hand" : "", (on & 0x40) ? " PLANT" : "",
        (int)g_riding, g_stCur, g_plantFoot, g_plantStage, g_plantD);
}
// ==== (v83) THE BODY TURNED TO THE FEET ===============================================================================
// The switch no comply rides you in the other stance with the mesh turned half round; the stance and the turn are two
// writes, and on the frames where only one of them shows (going in, and coming out at the landing: the trace of 23:24:19
// has the animation's feet at -17 / +18 cm along the deck with the held ones at +25 / -13) the whole body stands half a
// turn round from the feet the mod holds on the board -- "the lower half spins 180", "the feet do squirrely things". On a
// pose where the hips' line is more than 125 deg round from the line of the feet's riding spots, the body is turned half
// round about the mesh's own axis (as the missing write would have turned it); the held feet then meet it.
LONG g_bodyFlips = 0; float g_bodyAng = 0.0f; int g_bodyRun = 0;
bool BodyToSpots(const char* where) {
    g_bodyAng = 0.0f;
    if (g_pelvis < 0 || g_thigh[0] < 0 || g_thigh[1] < 0 || !g_deckOk || g_stCur < 0 || !g_dFootOk[0] || !g_dFootOk[1]) return false;
    const V3 fl = qrot(g_dq, sub(g_uFootP[0], g_uFootP[1]));
    const V3 hl = sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p);
    g_bodyAng = flatAngle(hl, fl);
    if (g_bodyAng <= 125.0f) { g_bodyRun = 0; return false; }
    // a swap's frame is one or two poses: a body that STAYS turned from the feet's line is the animation's own twist
    if (++g_bodyRun > 8) {
        if (g_bodyRun == 9) Log("%s: the body has stood %.0f deg round from the feet's line for 9 poses running -- the animation's own twist: left alone from here", where, g_bodyAng);
        return false;
    }
    const V3 pp = g_Ct[g_pelvis].p;
    SetComp(g_pelvis, qnorm(qmul(qaxis(kUp, 180.0f), g_Ct[g_pelvis].q)), v3(-pp.x, -pp.y, pp.z));
    if (InterlockedIncrement(&g_bodyFlips) <= 40)
        Log("%s: the body stood %.0f deg round from the feet's line on this pose (a stance swap's frame) -- turned half round to them", where, g_bodyAng);
    return true;
}
float g_hopExt[2] = { 0, 0 }; bool g_hopExtOk = false; double g_hopExtT = 0.0; LONG g_hopEased = 0; float g_hopEasedMost = 0.0f;
bool HopLegs() {
    if (g_planFrom > 0.01f) { g_hopExtOk = false; return false; }   // (v94) the planned landing's legs lengthen 330 cm/s at most by construction: a cut here would only make the feet late
    const double t = NowS();
    float dt = g_hopExtOk ? (float)(t - g_hopExtT) : 0.0f;
    if (dt > 0.12f) { g_hopExtOk = false; dt = 0.0f; }       // a gap: a new hop starts from the pose as it is
    if (g_hopFrac < 0.5f) g_hopExtOk = false;                // (v81) on the way up the legs lengthen as fast as they like
    bool changed = false;
    for (int k = 0; k < 2; k++) {
        if (g_thigh[k] < 0 || g_foot[k] < 0) continue;
        const V3 H = g_Ct[g_thigh[k]].p, F = g_Ct[g_foot[k]].p;
        const float ext = len(sub(F, H));
        if (!g_hopExtOk || ext < 1.0f) { g_hopExt[k] = ext; continue; }
        const float allow = g_hopExt[k] + fmaxf(g_hopLegRate, 30.0f) * dt;
        if (ext > allow + 0.2f) {
            Leg(k, add(H, mul(sub(F, H), allow / ext)), g_Ct[g_foot[k]].q);
            if (ext - allow > g_hopEasedMost) g_hopEasedMost = ext - allow;
            g_hopExt[k] = allow;
            InterlockedIncrement(&g_hopEased);
            changed = true;
        } else g_hopExt[k] = ext;
    }
    g_hopExtT = t; g_hopExtOk = true;
    return changed;
}
// ==== (v84) THE BODY HELD OVER A STANCE SWAP ==========================================================================
// "Switch no complies are probably the closest they've ever been. Give it another shot." The three of 23:52:58-23:53:15,
// every pose logged: the feet are held throughout; what is left are the swap's own frames. Going into the other stance
// one pose (16 ms in) has the body MIRRORED across the board -- facing its other side, the hips' line 71-87 deg off the
// feet's, the animation's feet on the far edge -- and coming out at the landing two poses in a row are wrong (the
// animation's feet at the opposite ends, then the hips 70 deg round). Not a half turn: v83's test for one never fired.
// The Lua knows the moment of both swaps; it asks for a hold (HJN_Set("posehold", poses)): for that many poses the body --
// the hips and everything on them -- is drawn as it stood on the last pose before, kept against the DECK's place and
// heading in the mesh (the mesh itself turns half round in the swap) and its own height, then blended back to the
// animation over five poses. 50-65 ms of a held body in place of the flash.
volatile int g_phFrames = 0; int g_phBlend = 0, g_phBlendN = 5; bool g_phHave = false; ULONGLONG g_phAt = 0; LONG g_phHeld = 0;
TF g_phPose[MAX_BONES]; bool g_phBody[MAX_BONES]; int g_phBodyN = -1, g_phBodyOf = -2;
// (v88) ...AND RUNS TO ITS END. The hold (4 poses) and its blend back (5) take 140 ms; the test for a kept pose being too
// old (120 ms) was made on every pose of it, so the blend was cut off two poses in -- the hips' line to the feet's 61, 59,
// 51, then 2 deg on the next pose coming out of the switch no comply of 14:23:12 (and 0 -> 23 going in): a snap of the
// whole body with the feet held on the board. The test is for the pose a hold STARTS from only.
bool g_phRun = false;
// (v96) THE SWITCH NO COMPLY'S TWO SWAPS, from the recordings of 5 Oct (00:02:08, 00:02:17, 00:04:15, 00:14:44 -- all alike):
// 1 A BONE KEEPS ITS LENGTH THROUGH THE BLEND. The five poses back to the game's pose moved every bone's PLACE on a straight
//   line between the two poses, each end of a bone on its own line: with the kept pose and the game's 60-85 deg apart a
//   thigh was drawn 31.6 / 33.4 / 35.0 / 37.7 cm for its 42.6 and a shin 35 for 41 (poses 46-50 going in, 83-87 coming
//   out; the game's own pose there: 42.6) -- "like they're getting crumpled, a leg segment issue". Now only the pelvis is
//   blended in place; every bone under it is TURNED against its parent (and its own offset eased), as a skeleton blends.
// 2 THE BODY'S PLACE ACROSS THE BOARD IS KEPT UNTIL THE GAME'S OWN CROSS-FADE IS DONE. After a swap the game fades from the
//   old stance's pose, standing in the mesh it has just turned half round, to the new one's -- over about 16 poses: its
//   hips are 24 cm on the FAR side of the board on the swap's pose and reach their own side (-25) sixteen poses later, a
//   straight line (and +20 -> -15 coming out). The hold let go after 4 + 5: the drawn hips swung 20 cm toward the board
//   (-27 -> -7 cm across it in four poses) and back out over the next nine, with both feet pinned -- twice a trick. For
//   g_phTail poses after the blend the pelvis keeps the kept pose's place ACROSS the deck (its place along it, its height
//   and its turn are the game's again); the feet stay where they are; the last five poses of that let it go.
//   HJN_Set("poselat", poses), 0 = as v95.
volatile int g_phTail = 10; float g_phLatMost = 0.0f; LONG g_phLatLogs = 0;
bool PoseHold(const void* mesh, int n) {
    if (g_pelvis < 0 || n <= 0 || n > MAX_BONES || !g_boardOk || !DeckXf(mesh)) return false;
    if (g_phBodyN != n || g_phBodyOf != g_pelvis) {
        for (int i = 0; i < n; i++) {
            bool body = false;
            for (int x = i, hops = 0; x >= 0 && hops < 64; x = g_parent[x], hops++) if (x == g_pelvis) { body = true; break; }
            g_phBody[i] = body;
        }
        g_phBodyN = n; g_phBodyOf = g_pelvis;
    }
    V3 fw = qrot(g_dq, v3(1.0f, 0.0f, 0.0f)); fw.z = 0.0f;
    if (len(fw) < 0.3f) return false;
    const Q4 qy = qaxis(kUp, atan2f(fw.y, fw.x) * 57.2957795f);
    const V3 o = v3(g_dp.x, g_dp.y, 0.0f);
    const ULONGLONG now = GetTickCount64();
    const bool holding = g_phFrames > 0;
    {   // (v96) a hold asked for while the last one's blend (ten poses longer now) still ran would hold the pose kept BEFORE that one
        static bool blending = false;
        if (holding && blending) g_phRun = false;         // ...the 120 ms test below then keeps this frame instead
        blending = !holding && g_phBlend > 0;
    }
    if (!holding && g_phBlend <= 0) {                     // no hold: this pose is the one a hold would keep
        g_phRun = false;
        for (int i = 0; i < n; i++) if (g_phBody[i]) { g_phPose[i].q = qnorm(qmul(qconj(qy), g_Ct[i].q)); g_phPose[i].p = qinv(qy, sub(g_Ct[i].p, o)); }
        g_phHave = true; g_phAt = now;
        return false;
    }
    if (!g_phRun && (!g_phHave || now - g_phAt > 120)) {
        // (v85) NOTHING KEPT FROM THE FRAMES BEFORE. Going INTO the other stance the hold was asked for on the very frame the
        // feet hold began -- no pose had been stored yet, and v84 dropped the hold (the traces of 4 Oct 11:46:51-11:47:01: the
        // mirrored pose still shows 31 ms in, hips' line 68 deg off; coming out, where the plant had kept poses, it held).
        // The frame the swap is asked on is still whole (the swap shows a frame later): it is the one kept.
        if (!holding) { g_phBlend = 0; return false; }
        for (int i = 0; i < n; i++) if (g_phBody[i]) { g_phPose[i].q = qnorm(qmul(qconj(qy), g_Ct[i].q)); g_phPose[i].p = qinv(qy, sub(g_Ct[i].p, o)); }
        g_phHave = true; g_phAt = now;
        return false;
    }
    g_phRun = true;
    float s = 1.0f, sl = 1.0f;                            // how much of the kept pose: all of it | of its place across the board
    const int tail = (g_phTail > 0) ? ((g_phTail < 40) ? (int)g_phTail : 40) : 0;
    if (holding) { if (--g_phFrames <= 0) { g_phFrames = 0; g_phBlend = g_phBlendN + tail; } }
    else {
        const int rem = g_phBlend - tail;                 // what is left of the pose's own blend
        s = (rem > 0) ? (float)rem / (float)(g_phBlendN + 1) : 0.0f; s = s * s * (3.0f - 2.0f * s);
        sl = (tail > 0) ? Sm01((float)g_phBlend / 6.0f) : s;
        g_phBlend--;
    }
    if (s > 0.0f)
        for (int i = 0; i < n; i++) {                     // (a parent comes before its children in the rig)
            if (!g_phBody[i]) continue;
            const int pa = g_parent[i];
            if (i == g_pelvis || pa < 0 || !g_phBody[pa]) {   // the pelvis: its place and its turn, against the deck
                const Q4 hq = qnorm(qmul(qy, g_phPose[i].q)); const V3 hp = add(o, qrot(qy, g_phPose[i].p));
                g_Ct[i].q = qslerpTo(g_Ct[i].q, hq, s); g_Ct[i].p = lerp(g_Ct[i].p, hp, s);
                LocalOf(i, g_Ct, g_Lt);
                continue;
            }
            // every bone under it: the kept pose's turn and offset AGAINST ITS PARENT (the deck's frame drops out of that)
            const V3 d = qinv(g_phPose[pa].q, sub(g_phPose[i].p, g_phPose[pa].p)), ps = g_Ct[pa].s;
            const V3 lp = v3(d.x / (fabsf(ps.x) > 1e-6f ? ps.x : 1.0f), d.y / (fabsf(ps.y) > 1e-6f ? ps.y : 1.0f), d.z / (fabsf(ps.z) > 1e-6f ? ps.z : 1.0f));
            g_Lt[i].q = qslerpTo(g_Lt[i].q, qnorm(qmul(qconj(g_phPose[pa].q), g_phPose[i].q)), s);
            g_Lt[i].p = lerp(g_Lt[i].p, lp, s);
            CompOf(i, g_Lt, g_Ct);
        }
    if (sl > s + 0.001f && s < 0.999f) {                  // the hips' place across the board: the kept pose's for a while longer
        const V3 c = qinv(qy, sub(g_Ct[g_pelvis].p, o));
        const float sh = clampf((g_phPose[g_pelvis].p.y - c.y) * (sl - s) / (1.0f - s), -35.0f, 35.0f);
        if (fabsf(sh) > 0.05f) {
            V3 F[2] = { v3(0.0f, 0.0f, 0.0f), v3(0.0f, 0.0f, 0.0f) }; Q4 Fq[2] = { q4(0, 0, 0, 1), q4(0, 0, 0, 1) };
            for (int k = 0; k < 2; k++) if (g_foot[k] >= 0) { F[k] = g_Ct[g_foot[k]].p; Fq[k] = g_Ct[g_foot[k]].q; }
            SetComp(g_pelvis, g_Ct[g_pelvis].q, add(g_Ct[g_pelvis].p, qrot(qy, v3(0.0f, sh, 0.0f))));
            for (int k = 0; k < 2; k++) if (g_foot[k] >= 0 && g_thigh[k] >= 0 && g_calf[k] >= 0) Leg(k, F[k], Fq[k]);   // the feet stay
            if (fabsf(sh) > g_phLatMost) g_phLatMost = fabsf(sh);
        }
    }
    if (!holding && g_phBlend <= 0) {
        if (tail > 0 && InterlockedIncrement(&g_phLatLogs) <= 12)
            Log("pose hold: over the game's own cross-fade after the swap the hips were kept up to %.0f cm from where its pose had them ACROSS the board (%d poses after the blend)", g_phLatMost, tail);
        g_phLatMost = 0.0f;
    }
    if (InterlockedIncrement(&g_phHeld) <= 12 && holding) Log("pose hold: the body kept as it stood %llu ms ago (a stance swap's pose)", now - g_phAt);
    return true;
}
// ==== (v79) THE FEET HELD ON THE BOARD ================================================================================
// The switch no comply's first frames: the game has started the trick in your own stance (its other foot steps off), the
// other stance and the mesh's half turn land a frame later, the game's foot IK is off and the plant has not begun --
// "his feet right at the start do some squirrely things, they almost step on the other side of the board" (the trace of
// 21:53: the back foot 38 cm across the deck and back in 0.2 s). While the Lua holds this window (HJN_Set("feethold",
// seconds)) both feet stand on their own riding spots on the drawn deck, whatever the legs' animation does; it eases
// out over six poses, and the plant, once it has its foot, takes both legs over.
volatile ULONGLONG g_feetHoldUntil = 0; float g_feetHoldW = 0.0f; LONG g_feetHoldFrames = 0;
bool FeetHold(const void* mesh) {
    const bool on = g_feetHoldUntil != 0 && GetTickCount64() < g_feetHoldUntil;
    if (on) g_feetHoldW = fminf(g_feetHoldW + 0.34f, 1.0f);   // (v83) over three poses (it snapped the feet 6 cm from the trick's stance to the riding one)
    else {
        g_feetHoldUntil = 0;
        g_feetHoldW -= 1.0f / 6.0f;
        if (g_feetHoldW <= 0.0f) { g_feetHoldW = 0.0f; return false; }
    }
    g_deckOk = g_boardOk && DeckXf(mesh);
    if (!g_deckOk || g_stCur < 0) return false;
    {   // (v89) the switch no comply of 18:10:52 held the feet on the spots of a stance last ridden, not the one stood in (R along +11 -> +22)
        static bool was = false;
        if (on && !was && g_foot[0] >= 0 && g_foot[1] >= 0 && g_st[g_stCur].ok) {
            V3 P[2]; for (int f = 0; f < 2; f++) P[f] = qinv(g_dq, sub(g_C[g_foot[f]].p, g_dp));
            int best = g_stCur; float bd = StanceDist(g_st[g_stCur], P);
            for (int i = 0; i < ST_N; i++) if (g_st[i].ok && StancePlausible(g_st[i].P)) { const float d = StanceDist(g_st[i], P); if (d < bd - 2.0f) { bd = d; best = i; } }
            if (best != g_stCur && bd < 8.0f) { Log("feet hold: stance #%d fits the feet better than #%d (%.0f cm off at most) -- held on its spots", best, g_stCur, bd); g_stCur = best; }
        }
        was = on;
    }
    UseStance(g_stCur);
    const float s = g_feetHoldW * g_feetHoldW * (3.0f - 2.0f * g_feetHoldW);
    bool any = false;
    for (int f = 0; f < 2; f++) {
        if (g_foot[f] < 0 || !g_dFootOk[f]) continue;
        const V3 p = add(g_dp, qrot(g_dq, g_uFootP[f]));
        const Q4 q = qnorm(qmul(g_dq, g_uFootQ[f]));
        if (!finite3(p) || len(sub(p, g_Ct[g_foot[f]].p)) > 140.0f) continue;
        Leg(f, lerp(g_Ct[g_foot[f]].p, p, s), qslerpTo(g_Ct[g_foot[f]].q, q, s));
        any = true;
    }
    if (any) InterlockedIncrement(&g_feetHoldFrames);
    return any;
}
// (v85) THE HAND'S AUDIT. "See if you can find the same hand wavering." The log had two snapshots a grab; now every pose a
// grab is fully held counts what the wrist still lacks of its spot after the arm has reached, and the grab's end says so.
void HandAudit(int kind) {
    if (g_audCnt[0] + g_audCnt[1] >= 5 && InterlockedIncrement(&g_audTold) <= 400)
        Log("hand audit: grab %d -- left over after the reach, per held pose: L %d poses mean %.1f most %.1f cm | R %d poses mean %.1f most %.1f cm | the most of: lean %.0f deg, hips to the hand %.1f cm, back past its Fold %.0f deg",
            kind, g_audCnt[0], g_audCnt[0] ? g_audSum[0] / g_audCnt[0] : 0.0f, g_audMax[0], g_audCnt[1], g_audCnt[1] ? g_audSum[1] / g_audCnt[1] : 0.0f, g_audMax[1],
            g_audLean, g_audClose, g_audFold);
    g_audCnt[0] = g_audCnt[1] = 0; g_audSum[0] = g_audSum[1] = 0.0f; g_audMax[0] = g_audMax[1] = 0.0f; g_audLean = g_audClose = g_audFold = 0.0f;
}
// ==== (v94) THE POSE RECORDER ===========================================================================================
// "So I can finally SEE what an animation fix does instead of guessing from sparse number logs." Every pose that gets to
// the end of PosePass() -- edited or not -- is kept: the whole skeleton as the game had it (g_C) and as it goes to the
// screen (g_Ct), the mesh's place in the world, the drawn deck, the ground under the mesh, and what of the mod's was on.
// The last PD_PRE poses wait in a ring; when any of a trick's windows opens (PD_TRIG) the ring and every pose after it are
// one SEGMENT, which ends PD_POST poses after the last window shut (or PD_MAX poses after it began, or when no pose has
// come for half a second) and is then appended to ExpandedTricks.poses.bin beside the logs in ONE write. Nothing is
// allocated or written per pose (two buffers, made once per bone count); nothing of the pose or of the mod's state is
// changed (the deck is read through DeckXf() and g_dq / g_dp put back as they were); and a fault in here turns only the
// recorder off (its own __try: PosePass runs inside SafeApply's, whose handler turns the grab arms off).
// HJN_Set("posedump", 0/1), ON by default; 0 also writes the segment that is open. The file's layout is in
// posedump/README.md, posedump/poseview.ps1 draws it. Two things to know when reading one: on a half-turn pose (flag
// 0x80) g_C is ALREADY turned (PosePass turns it in place before g_Ct is copied from it), and on a pose without 0x800
// ('changed') nothing was written back -- the screen has g_C, whatever g_Ct holds.
constexpr int PD_PRE = 40, PD_POST = 60, PD_MAX = 600;       // poses before a segment's start, after its last window shut, and the most after its start
constexpr uint32_t PD_TRIG = 0x3ffu;                         // what starts one: hop-air landing-blend plant bone-hand feet-hold pose-hold foot-ground half-turn grab trick-trace
constexpr ULONGLONG PD_GAP_MS = 500;                         // no pose for this long (a bail, the menu): what is open is written, the ring starts over
constexpr LONGLONG PD_FILE_CAP = 96ll * 1024 * 1024;         // the file grows no further than this
constexpr int PD_RIG_N = 36;
#pragma pack(push, 1)
struct PdSegHdr {                                            // 160 bytes; then int16 parent[bones], padded to 4 (= hdrBytes); then the poses
    char     magic[4];                                       // "ETPD"
    uint16_t version, hdrBytes;                              // 1 | the bytes from the magic to the first pose
    uint32_t segBytes, frames;                               // the whole segment, header and all (the next one starts there) | its poses
    uint16_t bones, frameHdrBytes;                           // g_n | sizeof(PdFrame)
    uint32_t frameBytes;                                     // frameHdrBytes + bones * 24
    uint16_t preFrames;                                      // the poses before the one that started it (= that pose's index)
    uint8_t  endReason, segFlags;                            // 1 its windows shut, 2 PD_MAX, 3 a gap, 4 switched off, 5 another rig | bit 0: goes on from a segment cut at PD_MAX
    uint32_t seq, flagsAny;                                  // the segment's number this run | every pose's flags OR-ed
    uint16_t modVersion, rigCount;                           // kVersion | PD_RIG_N
    uint16_t when[8];                                        // SYSTEMTIME (local) of the pose that started it: year month weekday day hour minute second ms
    uint64_t tick;                                           // GetTickCount64() of that pose
    float    deckHalfLen, deckHalfWidth, deckCentreX;        // HalfLen() HalfWidth() CentreX()
    float    footAnkle, footToe;                             // g_footAnkle g_footToe: how high a standing foot's ankle and toe joint are over the ground
    uint32_t reserved;
    int16_t  rig[PD_RIG_N];                                  // pelvis | thigh L R | calf L R | foot L R | toe L R | spineN, spine[6] | neck head | uarm L R | larm L R | hand L R
};                                                           // | flipper | foot anchor L R | hand anchor L R | chest spine1 | the pelvis's parent | 4 spare (-1)
struct PdFrame {                                             // 308 bytes; then float game[bones][3] (g_C's p), float drawn[bones][3] (g_Ct's p)
    uint32_t flags;                                          // the call's bits (see PosePass) | 0x100000 deck read, 0x200000 ground found, 0x400000 riding, 0x800000 off the board,
    uint32_t tick;                                           //   0x1000000 mirror, 0x2000000 the pose would be REJECTED (the v10 test), 0x4000000 g_legFix | (uint32_t)GetTickCount64()
    double   t;                                              // NowS(): the tick steps by 15.6 ms, this does not
    float    meshQ[4], meshP[3], meshS[3];                   // the mesh's component-to-world
    float    deckQ[4], deckP[3];                             // g_dq g_dp: the DRAWN deck, in the mesh's space
    float    footA[2];                                       // FootA(anim, 0 / 1)
    float    groundZ, groundN[3];                            // the ground under the mesh's origin: world z, and its normal
    float    plantD, plantW, hopFrac, hopReach, boneW, feetHoldW, legFixW;
    int16_t  plantFoot, plantStage, landFrames, landTotal, grabKind, stance;
    float    q[2][5][4];                                     // [0] g_C [1] g_Ct: the rotations of pelvis, foot L, foot R, toe L, toe R
    // (v99) appended -- a reader that takes the pose's bones from frameHdrBytes on (the viewer, pd_list.pl, the perl tools) skips them:
    float    q2[2][4][4];                                    // [0] g_C [1] g_Ct: the rotations of thigh L, thigh R, shin L, shin R
    float    sock[2][6];                                     // the anim instance's foot sockets L / R as the pose pass finds them: location (3), rotation (pitch yaw roll)
    float    hipGap[2];                                      // the DRAWN hip joints off their sockets, cm
    float    roll[2][2];                                     // the hinge roll the last solve of leg L / R put into thigh, shin (deg; 0 = none this pose)
    uint32_t more;                                           // 1 the sockets were turned for this pose, 2 both knees' hinges are known, 4 a hop's hips are being put back, 8 the plant foot swivels
};
#pragma pack(pop)
static_assert(sizeof(PdSegHdr) == 160 && sizeof(PdFrame) == 512, "the pose dump's layout is poseview.ps1's too (the first 308 bytes of a pose; the rest is v99's)");
volatile int  g_pdOn = 0;                                    // HJN_Set("posedump", 0/1) -- (v101) OFF until the Lua asks (PoseRecorder in the ini): the file grows to 96 MB
volatile LONG g_pdBusy = 0;                                  // the hook is in the recorder, or HJN_Set is writing what is open
volatile bool g_pdFull = false, g_pdDead = false;            // the file is at its cap or cannot be written (until the next HJN_Set("posedump", 1)) | it faulted: off for this run
int  g_pdN = 0, g_pdRec = 0, g_pdHdr = 0;                    // the bone count the buffers are for | the bytes of a pose | of a segment's header
uint8_t* g_pdRing = nullptr; uint8_t* g_pdSeg = nullptr;     // PD_PRE poses | a header and PD_PRE + PD_MAX poses
int  g_pdRingN = 0, g_pdRingAt = 0;                          // the poses in the ring | where the next one goes
bool g_pdOpen = false, g_pdCont = false;                     // a segment is being filled | the last one was cut at PD_MAX with a window still open
int  g_pdCount = 0, g_pdPre = 0, g_pdSince = 0, g_pdIdle = 0;
uint32_t g_pdAny = 0, g_pdSeq = 0; ULONGLONG g_pdTick = 0, g_pdLast = 0; SYSTEMTIME g_pdWhen;
bool PdGround(const void* mesh, float* z, V3* nrm);          // (with Ray(), further down)
int PdFilter(unsigned code) { return code == EXCEPTION_ACCESS_VIOLATION || code == EXCEPTION_INT_DIVIDE_BY_ZERO
                                  || code == EXCEPTION_FLT_INVALID_OPERATION ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH; }
bool PdAlloc(int n) {
    HANDLE heap = GetProcessHeap();
    if (g_pdRing) HeapFree(heap, 0, g_pdRing);
    if (g_pdSeg) HeapFree(heap, 0, g_pdSeg);
    g_pdRing = g_pdSeg = nullptr; g_pdN = 0; g_pdRingN = g_pdRingAt = 0; g_pdOpen = g_pdCont = false; g_pdCount = 0;
    if (n <= 0 || n > MAX_BONES) return false;
    g_pdRec = (int)sizeof(PdFrame) + n * 24;
    g_pdHdr = ((int)sizeof(PdSegHdr) + n * 2 + 3) & ~3;
    g_pdRing = (uint8_t*)HeapAlloc(heap, 0, (size_t)PD_PRE * g_pdRec);
    g_pdSeg = (uint8_t*)HeapAlloc(heap, 0, (size_t)g_pdHdr + (size_t)(PD_PRE + PD_MAX) * g_pdRec);
    if (!g_pdRing || !g_pdSeg) {
        if (g_pdRing) HeapFree(heap, 0, g_pdRing);
        if (g_pdSeg) HeapFree(heap, 0, g_pdSeg);
        g_pdRing = g_pdSeg = nullptr;
        return false;
    }
    g_pdN = n;
    Log("pose dump: on -- %d bones, %d bytes a pose; the last %d poses wait in a ring, a segment is %d at most (%.1f MB held); ExpandedTricks.poses.bin grows to %lld MB at most",
        n, g_pdRec, PD_PRE, PD_PRE + PD_MAX, ((double)g_pdHdr + (double)(2 * PD_PRE + PD_MAX) * g_pdRec) / 1048576.0, PD_FILE_CAP / (1024 * 1024));
    return true;
}
// a segment starts: its header's fixed part (the rig as it is NOW), then the ring, oldest pose first
void PdBegin(ULONGLONG now) {
    PdSegHdr* h = (PdSegHdr*)g_pdSeg;
    memset(g_pdSeg, 0, (size_t)g_pdHdr);
    memcpy(h->magic, "ETPD", 4);
    h->version = 1; h->hdrBytes = (uint16_t)g_pdHdr;
    h->bones = (uint16_t)g_pdN; h->frameHdrBytes = (uint16_t)sizeof(PdFrame); h->frameBytes = (uint32_t)g_pdRec;
    h->modVersion = (uint16_t)kVersion; h->rigCount = (uint16_t)PD_RIG_N;
    h->deckHalfLen = HalfLen(); h->deckHalfWidth = HalfWidth(); h->deckCentreX = CentreX();
    h->footAnkle = g_footAnkle; h->footToe = g_footToe;
    const int rig[PD_RIG_N] = { g_pelvis, g_thigh[0], g_thigh[1], g_calf[0], g_calf[1], g_foot[0], g_foot[1], g_toe[0], g_toe[1],
        g_spineN, g_spine[0], g_spine[1], g_spine[2], g_spine[3], g_spine[4], g_spine[5], g_neck, g_head,
        g_uarm[0], g_uarm[1], g_larm[0], g_larm[1], g_hand[0], g_hand[1], g_flipper, g_footAnchor[0], g_footAnchor[1], g_handAnchor[0], g_handAnchor[1],
        g_chest, g_spine1, (g_pelvis >= 0 && g_pelvis < g_pdN) ? g_parent[g_pelvis] : -1, -1, -1, -1, -1 };
    for (int i = 0; i < PD_RIG_N; i++) h->rig[i] = (int16_t)rig[i];
    int16_t* par = (int16_t*)(g_pdSeg + sizeof(PdSegHdr));
    for (int i = 0; i < g_pdN; i++) par[i] = (int16_t)g_parent[i];
    for (int i = 0; i < g_pdRingN; i++)
        memcpy(g_pdSeg + g_pdHdr + (size_t)i * g_pdRec, g_pdRing + (size_t)((g_pdRingAt - g_pdRingN + i + PD_PRE) % PD_PRE) * g_pdRec, (size_t)g_pdRec);
    g_pdCount = g_pdPre = g_pdRingN; g_pdRingN = g_pdRingAt = 0;
    h->segFlags = g_pdCont ? 1 : 0; g_pdCont = false;
    g_pdOpen = true; g_pdSince = 0; g_pdIdle = 0; g_pdAny = 0; g_pdTick = now; GetLocalTime(&g_pdWhen);
}
// a segment ends: the rest of its header, ONE write at the end of the file, one line in the log
void PdEnd(int reason) {
    const bool open = g_pdOpen; const int cnt = g_pdCount;
    g_pdOpen = false; g_pdCount = 0; g_pdRingN = g_pdRingAt = 0;
    g_pdCont = reason == 2;
    if (!open || !g_pdSeg || cnt <= 0) return;
    PdSegHdr* h = (PdSegHdr*)g_pdSeg;
    const DWORD bytes = (DWORD)g_pdHdr + (DWORD)cnt * (DWORD)g_pdRec;
    h->segBytes = bytes; h->frames = (uint32_t)cnt; h->preFrames = (uint16_t)g_pdPre;
    h->endReason = (uint8_t)reason; h->seq = ++g_pdSeq; h->flagsAny = g_pdAny; h->tick = g_pdTick;
    memcpy(h->when, &g_pdWhen, sizeof(h->when));
    wchar_t path[MAX_PATH];
    const DWORD pn = GetModuleFileNameW(nullptr, path, MAX_PATH);
    wchar_t* slash = (pn > 0 && pn < MAX_PATH) ? wcsrchr(path, L'\\') : nullptr;
    if (!slash || (slash + 1 - path) + 25 > MAX_PATH) { g_pdDead = true; Log("pose dump: no path for ExpandedTricks.poses.bin -- off for this run"); return; }
    wcscpy_s(slash + 1, MAX_PATH - (slash + 1 - path), L"ExpandedTricks.poses.bin");
    HANDLE f = CreateFileW(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE) {                 // (held open by something else, a full disk): as at the cap, it waits for the next HJN_Set("posedump", 1)
        const DWORD oe = GetLastError();
        g_pdFull = true; g_pdCont = false;
        Log("pose dump: ExpandedTricks.poses.bin could not be opened (error %lu) -- nothing more is recorded until HJN_Set(\"posedump\", 1)", oe);
        return;
    }
    LARGE_INTEGER sz; sz.QuadPart = 0;
    GetFileSizeEx(f, &sz);
    if (sz.QuadPart + (LONGLONG)bytes > PD_FILE_CAP) {
        CloseHandle(f);
        g_pdFull = true; g_pdCont = false;
        Log("pose dump: ExpandedTricks.poses.bin is at %.1f MB (the cap is %lld) -- nothing more is recorded; move it away and HJN_Set(\"posedump\", 1) to go on",
            (double)sz.QuadPart / 1048576.0, PD_FILE_CAP / (1024 * 1024));
        return;
    }
    DWORD wr = 0;
    const bool ok = WriteFile(f, g_pdSeg, bytes, &wr, nullptr) && wr == bytes;
    const DWORD err = ok ? 0 : GetLastError();
    CloseHandle(f);
    if (!ok) {
        g_pdFull = true; g_pdCont = false;
        Log("pose dump: the write failed (error %lu, %lu of %lu bytes) -- nothing more is recorded until HJN_Set(\"posedump\", 1); the file's last segment may be cut short (the viewer skips it)", err, wr, bytes);
        return;
    }
    const PdFrame* a = (const PdFrame*)(g_pdSeg + g_pdHdr);
    const PdFrame* b = (const PdFrame*)(g_pdSeg + g_pdHdr + (size_t)(cnt - 1) * g_pdRec);
    const uint32_t on = g_pdAny;
    Log("pose dump: segment %u written -- %d poses (%d before its start), %.2f s, %lu bytes (the file: %.1f MB) | on:%s%s%s%s%s%s%s%s%s%s%s%s | ended: %s",
        g_pdSeq, cnt, g_pdPre, b->t - a->t, bytes, (double)(sz.QuadPart + bytes) / 1048576.0,
        (on & 0x1) ? " hop-air" : "", (on & 0x2) ? " landing-blend" : "", (on & 0x4) ? " plant" : "", (on & 0x8) ? " bone-hand" : "",
        (on & 0x10) ? " feet-hold" : "", (on & 0x20) ? " pose-hold" : "", (on & 0x40) ? " foot-ground" : "", (on & 0x80) ? " half-turn" : "",
        (on & 0x100) ? " grab" : "", (on & 0x200) ? " trick-trace" : "", (on & 0x2000000) ? " (a REJECTED pose in it)" : "", h->segFlags ? " (goes on from the last)" : "",
        reason == 1 ? "its windows shut" : reason == 2 ? "at its longest, a window still open" : reason == 3 ? "no pose for half a second" : reason == 4 ? "switched off" : "another rig");
}
void PdQ(float* o, const TF* B, int b, int n) { const Q4 q = (b >= 0 && b < n) ? B[b].q : q4(0, 0, 0, 1); o[0] = q.x; o[1] = q.y; o[2] = q.z; o[3] = q.w; }
void PdFill(uint8_t* rec, const void* mesh, const void* anim, int n, uint32_t f, ULONGLONG now) {
    PdFrame* r = (PdFrame*)rec;
    const uint8_t* m = (const uint8_t*)mesh;
    r->tick = (uint32_t)now; r->t = NowS();
    memcpy(r->meshQ, m + SC_C2W, 16); memcpy(r->meshP, m + SC_C2W + 0x10, 12); memcpy(r->meshS, m + SC_C2W + 0x20, 12);
    {   // the drawn deck as DeckXf() reads it NOW -- and g_dq / g_dp left as the pose's own code had them
        const Q4 dq0 = g_dq; const V3 dp0 = g_dp;
        const bool ok = g_boardOk && DeckXf(mesh);
        const Q4 dq = ok ? g_dq : q4(0, 0, 0, 1); const V3 dp = ok ? g_dp : v3(0, 0, 0);
        g_dq = dq0; g_dp = dp0;
        if (ok) f |= 0x100000u;
        r->deckQ[0] = dq.x; r->deckQ[1] = dq.y; r->deckQ[2] = dq.z; r->deckQ[3] = dq.w;
        r->deckP[0] = dp.x; r->deckP[1] = dp.y; r->deckP[2] = dp.z;
    }
    r->footA[0] = anim ? FootA(anim, 0) : 0.0f; r->footA[1] = anim ? FootA(anim, 1) : 0.0f;
    float gz = r->meshP[2]; V3 gn = v3(0.0f, 0.0f, 1.0f);
    if (PdGround(mesh, &gz, &gn)) f |= 0x200000u;
    r->groundZ = gz; r->groundN[0] = gn.x; r->groundN[1] = gn.y; r->groundN[2] = gn.z;
    r->plantD = g_plantD; r->plantW = g_plantW; r->hopFrac = g_hopFrac; r->hopReach = g_hopReach; r->boneW = g_boneW;
    r->feetHoldW = g_feetHoldW; r->legFixW = g_legFixW;
    r->plantFoot = (int16_t)g_plantFoot; r->plantStage = (int16_t)g_plantStage;
    r->landFrames = (int16_t)g_landFrames; r->landTotal = (int16_t)g_landTotal;
    r->grabKind = (int16_t)g_grabKind; r->stance = (int16_t)g_stCur;
    const int qb[5] = { g_pelvis, g_foot[0], g_foot[1], g_toe[0], g_toe[1] };
    for (int i = 0; i < 5; i++) { PdQ(r->q[0][i], g_C, qb[i], n); PdQ(r->q[1][i], g_Ct, qb[i], n); }
    {                                                // (v99)
        const int q2b[4] = { g_thigh[0], g_thigh[1], g_calf[0], g_calf[1] };
        for (int i = 0; i < 4; i++) { PdQ(r->q2[0][i], g_C, q2b[i], n); PdQ(r->q2[1][i], g_Ct, q2b[i], n); }
        for (int k = 0; k < 2; k++) {
            const float* sp = anim ? (const float*)((const uint8_t*)anim + (k ? AI_RFOOT_LOC : AI_LFOOT_LOC)) : nullptr;
            for (int j = 0; j < 6; j++) r->sock[k][j] = sp ? sp[j] : 0.0f;
            float gap = 0.0f;
            if (g_pelvis >= 0 && g_pelvis < n && g_thigh[k] >= 0 && g_thigh[k] < n && g_hipRefN[k] >= 30 && g_parent[g_thigh[k]] == g_pelvis)
                gap = len(sub(qinv(g_Ct[g_pelvis].q, sub(g_Ct[g_thigh[k]].p, g_Ct[g_pelvis].p)), g_hipRef[k]));
            r->hipGap[k] = std::isfinite(gap) ? gap : 0.0f;
            r->roll[k][0] = g_hingeLast[k][0]; r->roll[k][1] = g_hingeLast[k][1];
        }
        r->more = (g_sockLive ? 1u : 0u) | ((g_hingeN[0] >= 30 && g_hingeN[1] >= 30) ? 2u : 0u) | (g_hopHipW > 0.02f ? 4u : 0u) | (g_plSwOn ? 8u : 0u) | (g_ankNow ? 16u : 0u) | (g_sockMirLive ? 32u : 0u);   // (v103) 32 = a foot socket was held on its own side of the deck for this pose (SockMirror)
    }
    float* p = (float*)(rec + sizeof(PdFrame));
    for (int i = 0; i < n; i++, p += 3) { p[0] = g_C[i].p.x; p[1] = g_C[i].p.y; p[2] = g_C[i].p.z; }
    bool bad = false;                                // PosePass's own test (v10) of the pose it is about to write: such a pose is NOT drawn
    for (int i = 0; i < n; i++, p += 3) {
        const Q4 q = g_Ct[i].q; const V3 c = g_Ct[i].p;
        p[0] = c.x; p[1] = c.y; p[2] = c.z;
        const float ql = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w;
        if (!finite3(c) || !std::isfinite(ql) || fabsf(ql - 1.0f) > 0.02f || len(sub(c, g_C[i].p)) > 200.0f) bad = true;
    }
    if (g_riding) f |= 0x400000u;
    if (g_offBoard) f |= 0x800000u;
    if (g_mirror) f |= 0x1000000u;
    if (bad && (f & 0x800u)) f |= 0x2000000u;
    if (g_legFix) f |= 0x4000000u;
    r->flags = f;
}
extern bool g_ownOn;                                 // (v96) LandOwnW's window, defined in front of PosePass
void PdPose(const void* mesh, const void* anim, int n, uint32_t f) {
    const ULONGLONG now = GetTickCount64();
    if (n != g_pdN) {                                // the first pose, or another rig: what is open still has the old one's header
        if (g_pdOpen) PdEnd(5);
        if (!PdAlloc(n)) { g_pdDead = true; Log("pose dump: no memory for %d bones -- off", n); return; }
    }
    if (g_pdLast != 0 && now - g_pdLast > PD_GAP_MS) { if (g_pdOpen) PdEnd(3); g_pdRingN = g_pdRingAt = 0; g_pdCont = false; }
    g_pdLast = now;
    const bool trig = (f & PD_TRIG) != 0 || (g_pdOpen && g_ownOn);   // (v96) an open segment goes on while a landing's legs keep their own length (the 600-pose limit holds)
    if (!trig) g_pdCont = false;
    if (!g_pdOpen && trig) PdBegin(now);
    uint8_t* rec = g_pdOpen ? g_pdSeg + g_pdHdr + (size_t)g_pdCount * g_pdRec : g_pdRing + (size_t)g_pdRingAt * g_pdRec;
    PdFill(rec, mesh, anim, n, f, now);
    if (!g_pdOpen) { g_pdRingAt = (g_pdRingAt + 1) % PD_PRE; if (g_pdRingN < PD_PRE) g_pdRingN++; return; }
    g_pdCount++; g_pdSince++; g_pdAny |= ((const PdFrame*)rec)->flags;
    g_pdIdle = trig ? 0 : g_pdIdle + 1;
    if (g_pdIdle >= PD_POST) PdEnd(1);
    else if (g_pdSince >= PD_MAX || g_pdCount >= PD_PRE + PD_MAX) PdEnd(2);
}
// POD only: these two run their own __try.
void PoseDump(const void* mesh, const void* anim, int n, uint32_t f) {
    if (g_pdDead || g_pdFull || (!g_pdOn && !g_pdOpen) || InterlockedExchange(&g_pdBusy, 1)) return;
    __try { if (g_pdOn) PdPose(mesh, anim, n, f); else PdEnd(4); }
    __except (PdFilter(GetExceptionCode())) {
        g_pdDead = true; g_pdOpen = false;
        Log("fault in the pose recorder (code %08x) -- it is off for this run; the pose itself is not its to touch", GetExceptionCode());
    }
    InterlockedExchange(&g_pdBusy, 0);
}
void PdSwitch(bool on) {
    const int was = g_pdOn;
    g_pdOn = on ? 1 : 0;
    if (on) g_pdFull = false;                        // (the file may have been moved away: its size is looked at again)
    if (was != g_pdOn) Log("pose dump %s", on ? "ON" : "off (what was open is written)");
    if (on || InterlockedExchange(&g_pdBusy, 1)) return;   // (the hook is in it right now: its next pose writes what is open)
    __try { PdEnd(4); }                              // off: what is open is written now -- the hook may not come by again before the game is closed
    __except (PdFilter(GetExceptionCode())) { g_pdDead = true; g_pdOpen = false; }
    InterlockedExchange(&g_pdBusy, 0);
}
// ==== (v96) A STRAIGHT HOP'S LEGS KEEP THEIR OWN LENGTH THROUGH THE LANDING ============================================
// "Normal hippie jump without the spin has some leg compression on landing. Specifically on the front foot. Unless I'm just
// getting lucky, the switch doesn't seem to have it at all." The recording of 5 Oct 00:09:15 (a mini riding regular; the one
// of 00:09:18 is the same): the left shin is drawn 41.2 cm to the last pose of the air, 32.1 on the touchdown pose, 36.4 four
// poses on, then 19.0 thirteen poses after touchdown -- the bottom of the landing's crouch -- and 33.5 a second after it.
// Every one of those lengths after the air is the GAME's: its rig is a Control Rig that runs PowerIK with bone translation
// allowed, and where that solver does not bend a leg far enough for the foot's place on the board the foot bone is moved up
// the shin instead (the thigh is 42.6 throughout). Riding regular it does that to the leading leg after a hop, the knee
// 2-12 cm off the leg's line and 60-160 deg round from the toes' way -- and after a MINI it stays that way: 29.9 and 30.9 cm
// 1.1-1.3 and 1.7-2.2 s after the touchdowns of 4 Oct 22:53:46 / :48, in the game's Idle state, and through the 180 that followed
// (the pre-hop dip then squeezes that shin further, 23.5, where a leg in its usual state bends). Fakie and switch (00:10:05,
// 00:10:09) both knees bend and the shins stay 40.8; in the game's own ollie landings riding regular (00:13:33, 00:13:42,
// the hips down to 61-64 cm where a hop's go to 77) the shin is 40.7-42.7; and 46 of the 48 segments of both sessions begin
// with both shins at 39.8-41.5 -- the two that do not are the hops chained after a regular mini. So it is not how the game
// rides or lands: it is the state a hop's landing leaves its rig in. The mod, which keeps the bones their own length through
// a hop's air, stopped on the touchdown pose (a straight landing had no shortEase), solved its let-down and its blend on
// the squeezed bones for thirteen poses -- the knee on the other side of the leg from the game's -- and then stopped
// writing: the left knee stepped 10.3 cm on that pose.
// Now, from the touchdown of a hop that lands the way it took off, a leg bone the pose hands in SHORT gets its length back and
// the leg is solved again to the ankle the pose has (LandOwnLegs): the knee bends for the difference, as the other leg's does
// and as both do riding switch. It is over as soon as the game's own legs have been whole for 0.75 s (riding switch: a second
// after touchdown); otherwise it lasts while the pose is plain riding, g_ownHold seconds at most (6), and is then handed back
// over g_ownFade (0.5 s) -- the lengths and the knee's way together, so there is no pose on which it stops. A bone the game
// hands in at its own length is not touched (98.5 % of it counts as all of it: riding, the game's shins measure 40.4-41.0 of
// the 41.2), so riding switch only the first two landing poses change.
// The knee's way: the pose's own where the leg is really bent and hardly short; the toes' (taken across the leg) as far as
// the leg is squeezed (1 -> 5 cm missing) or straight (bent under 9 -> 3 cm). Where the game really bends a knee on the
// board it stands a median 20 deg from its toes' way (1194 leg poses of seven segments: 90 % under 38 deg, 99 % under 52,
// 70 at most; the leading leg through the hops' and the game's own ollies' landings 1-26); a squeezed leg's knee is no guide.
// HJN_Set("landown", seconds): 0 = v95. HJN_Set("landownturn", 1): after a turned landing as well -- NOT the default: replayed
// on the four turned landings recorded it takes the squeeze away but not the knees' steps there, which are another part's.
constexpr int AI_PSLIDE_RATIO = 0x2e4, AI_MANUAL_RATIO = 0x330;   // USkaterAnimInstance PowerslideRatio / ManualRatio (reflected: the PDB's property table, as AI_LFOOT_A)
volatile float g_ownHold = 6.0f, g_ownFade = 0.5f; volatile int g_ownTurn = 1;   // (review) 1, as the Lua sends it: with the blended knees (landknee) the merged pass on the seven turned landings recorded draws the shin 40.5 cm where it was 15.8-18.6, the knee's largest step on landing poses 1-10 within 1.0 cm of landknee's alone
bool g_ownOn = false; double g_ownT0 = 0.0, g_ownEnd = 0.0, g_ownOkT = 0.0; const char* g_ownWhy = "";
float g_ownPs0 = 0.0f, g_ownMn0 = 0.0f, g_ownMost[2] = { 0, 0 }, g_ownNow[2] = { 0, 0 }; LONG g_ownPoses = 0, g_ownLogs = 0;
// how much of it this pose gets (0 = none); once a pose
float LandOwnW(bool air, bool land, bool grab, const float* fa, const void* anim) {
    const double t = NowS();
    const float ps = ReadF(anim, AI_PSLIDE_RATIO), mn = ReadF(anim, AI_MANUAL_RATIO);
    if (land && g_landTotal > 0 && g_landFrames == g_landTotal) {   // the touchdown pose: the first of HJN_Land's (LandBlend counts them down after this)
        g_ownOn = g_ownHold > 0.01f && (g_hopFlip == 0 || g_ownTurn != 0);
        g_ownT0 = t; g_ownEnd = 0.0; g_ownOkT = 0.0; g_ownWhy = ""; g_ownPoses = 0;
        g_ownMost[0] = g_ownMost[1] = 0.0f; g_ownNow[0] = g_ownNow[1] = 99.0f;
        g_ownPs0 = ps; g_ownMn0 = mn;                             // (whatever these read while nothing slides: only a CHANGE from here counts)
    }
    if (!g_ownOn) return 0.0f;
    // plain riding: on the board, both feet held to it by the game, no powerslide or manual begun, no other part of the mod's on the legs
    // (the next hop's air and landing count as riding)
    // (review) ...and the game's own flags for them. The two ratios are the right properties (0x2e4 PowerslideRatio, 0x330 ManualRatio: the PDB's
    // table) but ManualRatio is the stick's place in the manual's range (Skate_CheckForManuals: (stick - min) / (max - min), 0..1 -- a manual held
    // low never moves it a quarter), and a push does not show in the foot pulls at all: UpdateFootAnchors writes ONE number to both (1 on the board;
    // 0 only for a ragdoll, the board's modes 5 / 9). USkaterAnimInstance's reflected bools, each byte read off this exe's own
    // NewProp_..._SetBit helper: IsPowersliding 0x2d9, IsPushing 0x329, IsInManual 0x32e, IsInNoseManual 0x32f, IsGrinding 0x33c. (Through a hop's
    // air the Lua's standUp() clears them, so a hop itself never reads as one.)
    const uint8_t* ab = (const uint8_t*)anim;
    const bool slide = fabsf(ps - g_ownPs0) > 0.25f || fabsf(mn - g_ownMn0) > 0.25f   // (a quarter of their range: a wobble while carving must not end it)
        || ab[0x2d9] != 0 || ab[0x329] != 0 || ab[0x32e] != 0 || ab[0x32f] != 0 || ab[0x33c] != 0;
    const bool plain = !grab && !slide && g_riding != 0 && !g_offBoard && (air || land || (!g_noLearn && fa[0] > 0.9f && fa[1] > 0.9f));
    if (!plain && g_ownEnd == 0.0) {
        g_ownEnd = t;
        g_ownWhy = grab ? "a grab began" : slide ? "a powerslide, a manual, a grind or a push began" : (g_riding == 0 || g_offBoard) ? "off the board, or the game's own air" : g_noLearn ? "another trick began" : "a foot left the board's hold";
    }
    double e = g_ownT0 + (double)g_ownHold;
    if (g_ownEnd != 0.0 && g_ownEnd < e) e = g_ownEnd;           // handed back from here: its time is up, or the pose is no longer plain riding
    const float w = (t <= e) ? 1.0f : 1.0f - Sm01((float)((t - e) / (double)fmaxf(g_ownFade, 0.05f)));
    bool back = false;                                           // the game's own legs are whole again (nothing was missing on the last pose, for 0.75 s): over, with nothing to hand back
    if (w >= 1.0f && !air && !land && g_ownNow[0] < 0.6f && g_ownNow[1] < 0.6f) { if (g_ownOkT == 0.0) g_ownOkT = t; else if (t - g_ownOkT > 0.75) back = true; }
    else g_ownOkT = 0.0;
    if (back || w <= 0.0f || t < g_ownT0) {
        g_ownOn = false;
        if (InterlockedIncrement(&g_ownLogs) <= 300) {
            if (back) Log("landing: the legs kept their own length -- the game's own were whole again %.2f s after touchdown (%d poses changed, the most put back L %.1f R %.1f cm)",
                (float)(g_ownOkT - g_ownT0), (int)g_ownPoses, g_ownMost[0], g_ownMost[1]);
            else Log("landing: the legs kept their own length for %.2f s after touchdown, then were handed back over %.2f s (%s) -- %d poses changed, the most put back L %.1f R %.1f cm; still missing on the last pose L %.1f R %.1f cm",
                (float)(e - g_ownT0), g_ownFade, (g_ownEnd != 0.0 && g_ownEnd <= e) ? g_ownWhy : "its time was up", (int)g_ownPoses, g_ownMost[0], g_ownMost[1], g_ownNow[0], g_ownNow[1]);
        }
        return 0.0f;
    }
    return w;
}
bool LandOwnLegs(float w) {
    if (w <= 0.001f || !g_legRefOk) return false;
    bool changed = false;
    for (int k = 0; k < 2; k++) {
        const int th = g_thigh[k], ca = g_calf[k], ft = g_foot[k];
        g_ownNow[k] = 0.0f;
        if (th < 0 || ca < 0 || ft < 0 || g_legRef[k][0] < 1.0f || g_legRef[k][1] < 1.0f) continue;
        const int bone[2] = { ca, ft };
        float cur[2], to[2], lack = 0.0f; bool fix = false;
        for (int j = 0; j < 2; j++) {
            cur[j] = len(g_Lt[bone[j]].p); to[j] = cur[j];
            const float d = g_legRef[k][j] * 0.985f - cur[j];
            if (cur[j] > 1.0f && d > 0.0f) { to[j] = cur[j] + d * w; lack += d; if (d * w > 0.05f) fix = true; }
        }
        g_ownNow[k] = lack;
        if (!fix) continue;
        const V3 S = g_Ct[th].p, F0 = g_Ct[ft].p; const Q4 fq0 = g_Ct[ft].q;   // the ankle as the pose has it
        if (!finite3(S) || !finite3(F0)) continue;
        const V3 hf = sub(F0, S); const float hl2 = dot(hf, hf);
        const V3 kv = sub(g_Ct[ca].p, S);
        const V3 kp = (hl2 > 1.0f) ? sub(kv, mul(hf, dot(kv, hf) / hl2)) : kv;   // the knee, off the hip-ankle line, as the pose has it
        const float bend = len(kp);
        V3 pole = kp; bool havePole = bend > 0.5f;
        if (g_toe[k] >= 0) {
            V3 toes = qrot(qnorm(fq0), norm(g_Lt[g_toe[k]].p));
            if (hl2 > 1.0f) toes = sub(toes, mul(hf, dot(toes, hf) / hl2));      // ...across the leg
            { V3 sw; if (ShinWay(k, fq0, hf, sw)) toes = sw; }                   // (v97) the way the shin stands on that foot riding (the note at g_shinRide)
            if (len(toes) > 0.25f) {
                toes = norm(toes);
                const V3 own = havePole ? mul(kp, 1.0f / bend) : toes;
                const float u = fmaxf(Sm01((lack - 1.0f) / 4.0f), 1.0f - clampf((bend - 3.0f) / 6.0f, 0.0f, 1.0f)) * w;
                pole = (dot(own, toes) < -0.2f) ? toes : norm(lerp(own, toes, u));
                havePole = true;
            }
        }
        if (!(g_airFrames > 0 && g_landFrames <= 0)) {               // (v98) how far round the leg that is from the knee the pose came in with: the next hop's air begins from it (the note at g_ownTwist)
            g_ownTwist[k] = 0.0f; g_ownTwistT[k] = NowS();
            const V3 gS = g_C[th].p, gh = sub(g_C[ft].p, gS); const float gl2 = dot(gh, gh);
            if (havePole && hl2 > 1.0f && gl2 > 1.0f) {
                const V3 gv = sub(g_C[ca].p, gS), gk = sub(gv, mul(gh, dot(gv, gh) / gl2));   // the game's knee, off its own hip-ankle line
                const V3 ax = mul(hf, 1.0f / sqrtf(hl2));
                const V3 u = sub(gk, mul(ax, dot(gk, ax))), v = sub(pole, mul(ax, dot(pole, ax)));
                if (len(gk) > 6.0f && len(u) > 3.0f && len(v) > 0.25f && finite3(u) && finite3(v)) {
                    const V3 un = norm(u), vn = norm(v);
                    g_ownTwist[k] = atan2f(dot(cross(un, vn), ax), dot(un, vn));
                }
            }
        }
        for (int j = 0; j < 2; j++) if (to[j] != cur[j]) g_Lt[bone[j]].p = mul(g_Lt[bone[j]].p, to[j] / cur[j]);
        RebuildSub(th);
        Leg(k, F0, fq0, V3{ 0, 0, 0 }, havePole ? &pole : nullptr);
        if (lack > g_ownMost[k]) g_ownMost[k] = lack;
        changed = true;
    }
    if (changed) InterlockedIncrement(&g_ownPoses);
    return changed;
}
// ==== (v99) THE OTHER STANCE'S FOOT SOCKETS ARE TURNED WITH THE BODY: THE GAME PLACES THE FEET ITSELF =================
// "Switch no comply is no good. Again, it's pretty scrambled." Since v162 a switch plant is ridden in the other stance with
// the game's foot IK OFF: the game aims each foot at a socket that follows the real board through the trick (the clip's
// own choreography: riding regular the game's feet are ON its sockets all through a no comply, the trace of 5 Oct
// 12:04:39) -- and in the other stance those sockets are that stance's, half a turn round from where this rider's feet
// are (the same trace at 12:05:23: the sockets at -14 +16 and +15 +19 on the deck, the feet at +17 -16 and -14 -20). So
// the feet were the clip's alone, carried by nothing, and the mod held them: both on their riding spots on the real deck
// (v163), under a body the game had bent over and carried 25 cm along the board at 459 cm/s, on a deck pitched 28 deg --
// the right knee 50 cm out to the side of a foot 12 cm from the hips. That is the scramble.
// The body's half turn is the anim graph's own since v98 (its node is switched off); now the SOCKETS get theirs. The Lua
// calls HJN_Set("sockturn", 1) from its hook on the anim blueprint's update -- after the game has worked the sockets out
// for this pose, before its graph reads them -- on every pose the other stance is ridden: both foot sockets (the anim
// instance's Left/RightFootSocketLocation and ...Rotation, 0x404 / 0x410 / 0x41c / 0x428: the PDB's property table) are
// turned half round about the drawn deck's own up, through the middle of the stance (the mean of this rider's two
// sockets on the pose before the swap -- "sockturn" 2 notes them -- and the other stance's two on its first: the deck's
// own middle is 4-5 cm off it, and the feet would shuffle by twice that at each swap). The game's IK weights are left
// as the game has them. Its feet then go where the regular side's go, by the same rig, and the plant is the regular
// side's own (the soft plant, with "the game's own foot" for its home: PlantSoft's `own` is off while this is live).
// Should the feet NOT follow (28 cm or more from their sockets on 15 poses of a swap) it is switched off for the run
// and said so: the Lua then zeroes the IK weights again and the plant goes back to the riding spots.
constexpr int AI_LFOOT_ROT = 0x410, AI_RFOOT_ROT = 0x428;        // Left/RightFootSocketRotation (FRotator: pitch, yaw, roll)
volatile int g_sockOn = 1, g_sockBad = 0; volatile LONG g_sockMark = 0; LONG g_sockTurns = 0, g_sockLogs = 0;
V3 g_sockPrevD[2] = { { 0, 0, 0 }, { 0, 0, 0 } }, g_sockC = { 0, 0, 0 }, g_sockNowC[2] = { { 0, 0, 0 }, { 0, 0, 0 } };
double g_sockPrevT = -1.0e9, g_sockSeenT = -1.0e9; bool g_sockCOk = false;   // (g_sockSeenT: the Lua last called for this swap -- the sockets are the game's own business while it does)
float g_sockFarMost = 0.0f, g_sockFarSum = 0.0f; int g_sockFarN = 0, g_sockFarBad = 0, g_sockPoses = 0, g_sockTurnedN = 0; bool g_sockWas = false;
bool g_sockTurned = false; int g_sockFlag = 0, g_sockFlagN = 0, g_sockForced = 0;   // (v100) the sockets of the pose before were turned; the stance flag the Lua read, and for how many poses running
Q4 RotQ(const float* r) {                                        // FRotator::Quaternion()
    const float hp = fmodf(r[0], 360.0f) * 0.00872664626f, hy = fmodf(r[1], 360.0f) * 0.00872664626f, hr = fmodf(r[2], 360.0f) * 0.00872664626f;
    const float SP = sinf(hp), CP = cosf(hp), SY = sinf(hy), CY = cosf(hy), SR = sinf(hr), CR = cosf(hr);
    return q4(CR * SP * SY - SR * CP * CY, -CR * SP * CY - SR * CP * SY, CR * CP * SY - SR * SP * CY, CR * CP * CY + SR * SP * SY);
}
void QRot(Q4 q, float* r) {                                      // FQuat::Rotator()
    const float st = q.z * q.x - q.w * q.y, yy = 2.0f * (q.w * q.z + q.x * q.y), yx = 1.0f - 2.0f * (q.y * q.y + q.z * q.z);
    auto nax = [](float a) { a = fmodf(a, 360.0f); if (a < 0.0f) a += 360.0f; if (a > 180.0f) a -= 360.0f; return a; };
    if (st < -0.4999995f) { r[0] = -90.0f; r[1] = atan2f(yy, yx) * 57.2957795f; r[2] = nax(-r[1] - 2.0f * atan2f(q.x, q.w) * 57.2957795f); }
    else if (st > 0.4999995f) { r[0] = 90.0f; r[1] = atan2f(yy, yx) * 57.2957795f; r[2] = nax(r[1] - 2.0f * atan2f(q.x, q.w) * 57.2957795f); }
    else {
        r[0] = asinf(clampf(2.0f * st, -1.0f, 1.0f)) * 57.2957795f; r[1] = atan2f(yy, yx) * 57.2957795f;
        r[2] = atan2f(-2.0f * (q.w * q.x + q.y * q.z), 1.0f - 2.0f * (q.x * q.x + q.y * q.y)) * 57.2957795f;
    }
}
bool DeckXf(const void* mesh); float CentreX();
// ==== (v103) A GOOFY RIDER'S SWITCH PLANT, CAUGHT: THE FEET DO NOT TURN ROUND AT THE LANDING ===========================
// The goofy rider's switch plant is drawn with the game's mirror table taken away (the Lua, v189) and the sockets turned
// here. When the game has CAUGHT the board in such a trick its foot sockets are no longer the skeleton's anchors but the
// board's catch sockets, and those go by the game's goofy flag: on the pose the table is put back they stand mirrored
// across the deck's centre line, turned half round -- the recording of 6 Oct 21:20:09 (the one goofy switch trick caught
// so far, by hand), pose 78: L from -20 +10 to -21 -9, R from +22 +10 to +21 -9, the feet with them and their toes the
// other way, under hips that face as before; the game then walks each socket back across the board, R after 0.42 s, L
// after 0.57 s. "Both feet stand turned backwards for half a second." With the boneless's board caught by the game
// (Lua v191) every goofy switch boneless would land so.
// The Lua calls with mode 4 on the poses after it has put the table back. On the first of them a socket that has jumped
// to the other side of the centre line, and whose mirror image is where the pose before had it, is HELD: its own along
// and up, the image's across, and the rotation it came with turned half round about the deck's up (kept in the deck's
// frame) -- until the game's own socket has come round to that side (within 2 cm of the held across), 1.5 s at most.
// Replayed over that recording (source/tools/posedump/mirsim.pl): L held 34 poses at -21 +9, R 25 poses at +21 +9, steps
// of 2 cm at either end, the held rotation 11 and 15 deg from the game's own at the release; and over the 39 other
// switch landings on record (26 of the goofy rider's, none caught, 13 of the regular rider's as if mode 4 were sent)
// it does not start. It rests on that one trick, caught by hand: the first board the game catches in a goofy rider's
// switch boneless is its real test (the log's "switch plant, caught:" lines say what it did).
// Nothing else calls with mode 4: the regular rider's swap ends with the game's own flag.
bool g_sockMir[2] = { false, false }; float g_sockMirY[2] = { 0.0f, 0.0f }; Q4 g_sockMirQ[2] = { { 0.0f, 0.0f, 0.0f, 1.0f }, { 0.0f, 0.0f, 0.0f, 1.0f } };
double g_sockMirT0 = -1.0e9; int g_sockMirArm = 0, g_sockMirN[2] = { 0, 0 }; LONG g_sockMirLogs = 0;
// d: this pose's two sockets as the game has them, in the deck's frame; prev: what the pose before was given; lp: the anim instance's own
void SockMirror(double now, const V3* d, const V3* prev, float* const* lp) {
    if (g_sockMirArm == 0) g_sockMirT0 = now;
    if (g_sockMirArm < 100000) g_sockMirArm++;
    const V3 up = norm(qrot(g_dq, v3(0.0f, 0.0f, 1.0f)));
    const Q4 half = q4(up.x, up.y, up.z, 0.0f), dqc = q4(-g_dq.x, -g_dq.y, -g_dq.z, g_dq.w);
    for (int k = 0; k < 2; k++) {
        if (!g_sockMir[k]) {
            if (g_sockMirArm > 8 || now - g_sockMirT0 > 0.2) continue;       // only as the table comes back
            const V3 im = v3(d[k].x, -d[k].y, d[k].z);
            const float eRaw = len(sub(d[k], prev[k])), eIm = len(sub(im, prev[k]));
            if (!(std::isfinite(eRaw) && std::isfinite(eIm) && d[k].y * prev[k].y < 0.0f && fabsf(d[k].y - prev[k].y) > 12.0f && eIm + 8.0f < eRaw && eIm < 10.0f && fabsf(im.y) >= 4.0f)) continue;
            const Q4 hq = qnorm(qmul(dqc, qmul(half, RotQ(lp[k] + 3))));
            if (!(std::isfinite(hq.x) && std::isfinite(hq.y) && std::isfinite(hq.z) && std::isfinite(hq.w))) continue;
            g_sockMir[k] = true; g_sockMirY[k] = im.y; g_sockMirQ[k] = hq; g_sockMirN[k] = 0;
            if (InterlockedIncrement(&g_sockMirLogs) <= 60)
                Log("switch plant, caught: the game's %s foot socket came back on the far side of the board (%+.0f %+.0f on the deck; the pose before had it at %+.0f %+.0f) -- it is held on its own side, turned back, until the game's own comes round",
                    k ? "R" : "L", d[k].x, d[k].y, prev[k].x, prev[k].y);
        }
        const float sg = g_sockMirY[k] >= 0.0f ? 1.0f : -1.0f;
        if (d[k].y * sg >= fabsf(g_sockMirY[k]) - 2.0f || now - g_sockMirT0 > 1.5) {
            if (InterlockedIncrement(&g_sockMirLogs) <= 60)
                Log("switch plant, caught: the game's %s foot socket is %s (%+.0f %+.0f on the deck) after %d held poses, %.2f s -- the game's own again",
                    k ? "R" : "L", (d[k].y * sg >= fabsf(g_sockMirY[k]) - 2.0f) ? "back on its side" : "NOT back on its side in time", d[k].x, d[k].y, g_sockMirN[k], now - g_sockMirT0);
            g_sockMir[k] = false;
            continue;
        }
        const V3 o = v3(d[k].x, g_sockMirY[k], d[k].z), np = add(g_dp, qrot(g_dq, o));
        const Q4 nq = qnorm(qmul(g_dq, g_sockMirQ[k]));
        if (!finite3(np) || !(std::isfinite(nq.x) && std::isfinite(nq.y) && std::isfinite(nq.z) && std::isfinite(nq.w))) { g_sockMir[k] = false; continue; }
        lp[k][0] = np.x; lp[k][1] = np.y; lp[k][2] = np.z;
        QRot(nq, lp[k] + 3);
        g_sockNowC[k] = np; g_sockPrevD[k] = o; g_sockMirN[k]++;
        InterlockedExchange(&g_sockMark, 3);
    }
}
// mode 2: a swap begins -- this pose's sockets are your own stance's, and are kept (in the deck's frame). mode 1: every pose
// of the swap -- the sockets are kept CONTINUOUS with the pose before: turned half round when that is what brings them
// back to where they stood, left alone when they already are there. (v100. v99 turned them on the poses the game's stance
// flag named the other stance, and the sockets follow that flag ONE POSE LATE at both ends of a swap: on the swap's second
// pose the feet were sent to each other's ends by the turn, and on the first pose after it they stood there again with no
// turn -- the recording of 5 Oct 14:24:54, poses 42 and 76: "for one or two frames the feet switch places".) The sockets
// move 10 cm a pose at most through a trick; a stance's flip moves the two of them 80-100 cm between them.
// The turn is about the deck's own middle (CentreX, on its centre line): what v99 did in fact -- its 'middle of the two
// stances' sockets' was taken on the lagging pose, came out 15 cm off the centre line and was refused -- and what was
// called fine. The state is kept with a margin either way (a pose that does not say keeps what the pose before had), and
// the stance flag is the last word: mode 3 = the flag names the other stance, 1 = your own; four poses running of a flag
// the sockets do not agree with, and the flag is followed.
// From the Lua's hook, on the game thread
bool SockTurn(int mode) {
    void* mesh = g_mesh;
    if (!g_sockOn || g_sockBad || !mesh || !g_rigOk || !g_skater || !g_boardOk) return false;
    void* anim = *(void* const*)((const uint8_t*)mesh + SKM_ANIM);
    if (!anim || anim != g_anim) return false;
    const Q4 dq0 = g_dq; const V3 dp0 = g_dp;                    // (the pose pass reads the deck for itself: what it had is put back)
    bool ok = false;
    if (DeckXf(mesh)) {
        float* lp[2] = { (float*)((uint8_t*)anim + AI_LFOOT_LOC), (float*)((uint8_t*)anim + AI_RFOOT_LOC) };
        V3 p[2], d[2]; bool fin = true;
        for (int k = 0; k < 2; k++) {
            p[k] = v3(lp[k][0], lp[k][1], lp[k][2]);
            if (!finite3(p[k]) || !std::isfinite(lp[k][3]) || !std::isfinite(lp[k][4]) || !std::isfinite(lp[k][5]) || len(sub(p[k], g_dp)) > 200.0f) fin = false;
            d[k] = qinv(g_dq, sub(p[k], g_dp));
        }
        if (fin) {
            const double now = NowS();
            if (mode != 4 || now - g_sockPrevT > 0.25) { g_sockMir[0] = g_sockMir[1] = false; g_sockMirArm = 0; }   // (v103) the hold is the tail's alone
            if (mode == 2 || now - g_sockPrevT > 0.25) {         // the swap's first pose (or the first the Lua calls for after a gap): as they stand
                g_sockPrevD[0] = d[0]; g_sockPrevD[1] = d[1]; g_sockCOk = false;
                g_sockTurned = false; g_sockFlag = 0; g_sockFlagN = 0; g_sockForced = 0;
                g_sockNowC[0] = p[0]; g_sockNowC[1] = p[1];
                InterlockedExchange(&g_sockMark, 1);
            } else {
                const int flag = (mode == 3) ? 1 : 0;
                if (flag == g_sockFlag) g_sockFlagN++; else { g_sockFlag = flag; g_sockFlagN = 1; }
                const V3 c = g_sockCOk ? g_sockC : v3(CentreX(), 0.0f, 0.0f);
                const V3 t[2] = { v3(2.0f * c.x - d[0].x, 2.0f * c.y - d[0].y, d[0].z), v3(2.0f * c.x - d[1].x, 2.0f * c.y - d[1].y, d[1].z) };
                const float sRaw = len(sub(d[0], g_sockPrevD[0])) + len(sub(d[1], g_sockPrevD[1]));
                const float sTur = len(sub(t[0], g_sockPrevD[0])) + len(sub(t[1], g_sockPrevD[1]));
                bool turn = g_sockTurned;
                if (std::isfinite(sRaw) && std::isfinite(sTur)) turn = g_sockTurned ? !(sRaw + 6.0f < sTur) : (sTur + 6.0f < sRaw);
                if (g_sockFlagN >= 4 && turn != (flag != 0)) {   // the sockets have not said what the flag has said for four poses: the flag
                    turn = flag != 0;
                    if (!g_sockForced) { g_sockForced = 1; if (InterlockedIncrement(&g_sockLogs) <= 40) Log("switch plant: the foot sockets did not show the stance the game's flag has named for four poses (as they stand %.0f cm from the pose before's, turned %.0f) -- they are %s by the flag", sRaw, sTur, turn ? "turned" : "left as they are"); }
                }
                if (turn && !g_sockCOk) {                        // the first pose the other stance's sockets are there: the turn's centre is kept for the swap
                    if (finite3(c) && fabsf(c.x) <= 15.0f && fabsf(c.y) <= 12.0f) {
                        g_sockC = c; g_sockCOk = true;
                        if (InterlockedIncrement(&g_sockLogs) <= 40)
                            Log("switch plant: the game's foot sockets are the other stance's from this pose on and are turned half round about the deck -- about the point %+.1f %+.1f of it (the deck's own middle); they stood at L %+.0f %+.0f R %+.0f %+.0f on the pose before, and at L %+.0f %+.0f R %+.0f %+.0f now",
                                c.x, c.y, g_sockPrevD[0].x, g_sockPrevD[0].y, g_sockPrevD[1].x, g_sockPrevD[1].y, d[0].x, d[0].y, d[1].x, d[1].y);
                    } else turn = false;
                }
                if (turn) {
                    const V3 up = norm(qrot(g_dq, v3(0.0f, 0.0f, 1.0f)));
                    const Q4 half = q4(up.x, up.y, up.z, 0.0f);
                    V3 np[2]; Q4 nq[2];
                    for (int k = 0; k < 2; k++) {
                        np[k] = add(g_dp, qrot(g_dq, t[k]));
                        nq[k] = qnorm(qmul(half, RotQ(lp[k] + 3)));
                        if (!finite3(np[k]) || !std::isfinite(nq[k].x) || !std::isfinite(nq[k].y) || !std::isfinite(nq[k].z) || !std::isfinite(nq[k].w)) turn = false;
                    }
                    if (turn) {
                        for (int k = 0; k < 2; k++) {
                            lp[k][0] = np[k].x; lp[k][1] = np[k].y; lp[k][2] = np[k].z;
                            QRot(nq[k], lp[k] + 3);
                            g_sockNowC[k] = np[k]; g_sockPrevD[k] = t[k];
                        }
                        InterlockedExchange(&g_sockMark, 2); InterlockedIncrement(&g_sockTurns); g_sockTurnedN++;
                    }
                }
                g_sockTurned = turn;
                if (!turn) {
                    const V3 prev[2] = { g_sockPrevD[0], g_sockPrevD[1] };
                    g_sockPrevD[0] = d[0]; g_sockPrevD[1] = d[1];
                    g_sockNowC[0] = p[0]; g_sockNowC[1] = p[1];
                    InterlockedExchange(&g_sockMark, 1);
                    if (mode == 4) SockMirror(now, d, prev, lp);         // (v103) the goofy rider's switch plant, the table back: the note at SockMirror
                }
                else { g_sockMir[0] = g_sockMir[1] = false; }
            }
            g_sockPrevT = now; g_sockSeenT = now; ok = true;
        }
    }
    g_dq = dq0; g_dp = dp0;
    return ok;
}
bool SafeSockTurn(int mode) {                                    // (called from the Lua: a stale pointer must not take the game down)
    __try { return SockTurn(mode); }
    __except (EXCEPTION_EXECUTE_HANDLER) { g_sockBad = 1; Log("fault in the foot sockets' turn (code %08x) -- it is off for this run", GetExceptionCode()); return false; }
}
// once a pose, after the pose is read: do the game's feet follow the turned sockets? (and the end of a swap: what was seen)
void SockSeen(bool live) {
    if (live) {
        g_sockWas = true; g_sockPoses++;
        if (g_sockMirLive) return;                               // (v103, review) a pose with a socket HELD is not a test of the turn: a push in the second after the landing must not switch the turn off for the run
        for (int k = 0; k < 2; k++) {
            if (g_foot[k] < 0 || k == g_plantFoot) continue;     // (the plant foot leaves its socket for the ground: the regular side's does too)
            const float away = len(sub(g_C[g_foot[k]].p, g_sockNowC[k]));
            if (!std::isfinite(away)) continue;
            g_sockFarSum += away; g_sockFarN++;
            if (away > g_sockFarMost) g_sockFarMost = away;
            if (away > 28.0f && ++g_sockFarBad == 15 && !g_sockBad) {
                g_sockBad = 1;
                Log("switch plant: the game's feet do NOT follow the turned sockets (28 cm or more from them on 15 poses of this trick) -- the turn is off for this run: the IK weights are zeroed again and the plant goes back to the riding spots");
            }
        }
        return;
    }
    if (!g_sockWas) return;
    if (g_sockLogs <= 60)
        Log("switch plant: the foot sockets were kept through %d poses of that trick and turned on %d of them; the foot that stays on the board stood %.1f cm from its socket on average, %.1f at most (the regular side's: 0-16)",
            g_sockPoses, g_sockTurnedN, g_sockFarN ? g_sockFarSum / (float)g_sockFarN : 0.0f, g_sockFarMost);
    g_sockWas = false; g_sockPoses = 0; g_sockTurnedN = 0; g_sockFarMost = g_sockFarSum = 0.0f; g_sockFarN = g_sockFarBad = 0;   // (the turn's centre is kept until the Lua notes the sockets again: a pose the Lua missed must not move it)
}
// ==== (v97) THE OTHER STANCE'S HALF TURN IS MADE IN THE POSE, NOT IN THE MESH ==========================================
// "Switch no comply seem fine now, except for the fact that the player body does a full 360 in about a frame right before
// the trick." It is not on the screen while you play: the recording of 5 Oct (08:54:31, 08:58:01) has the drawn body's hip
// and shoulder lines within 10 deg from one pose to the next through both stance swaps. It is in the REPLAY -- the same
// recording has the replay being run back over each of those tricks 0.7 s after it landed. Since v161 the Lua turned the
// skater's MESH half round for the trick (the other stance's pose stands turned by that much on a board that rolls tail
// first) and the pose was turned to match on the same pose. The game's replay keeps, pose by pose, the mesh's place and
// turn and every bone's place IN the mesh (UAnimInstanceReplayComponent::RecordDataForFrame: GetBoneTransform against the
// mesh's own transform) and plays them back blended between two kept poses (Replaying: FQuat::Slerp) -- and between the
// pose before a swap and the one after it that is a mesh turned half round against bones turned half round the other way:
// for one replayed frame the body is spun and drawn in toward the mesh's own axis. Twice a trick, in every clip of it.
// Now the mesh is not turned at all. While the Lua has a swap on (HJN_Set("swapturn", 1 = you ride regular, 2 = goofy;
// 0 = it is over)) every pose on which the GAME's anim instance says the other stance (IsSkatingGoofy, the byte
// NativeUpdateAnimation builds afresh for each pose, 0x304) has its body -- the pelvis' parent and everything on it, as
// the game's own half turn has it; that bone stands on the mesh's own axis, the board's bones hang beside it -- turned
// half round about the mesh's up, in place, before anything else reads it: bone for bone where the turned mesh had it.
// The mesh, and with it the replay's record, never jumps; and the test is the game's own flag, so the turn starts and
// ends on exactly the poses the stance does (the Lua's "over" only says it may end).
// (v98) ...AND NOT IN THE POSE EITHER. v97 turned the body here, in the finished pose -- and the game's upper body is
// physics-blended: its bodies are set from the pose the mod WRITES when the skater moves and from the pose the game's
// graph hands in a moment later, so with those two half a turn apart every pose the spine, the head and the arms were
// thrown from one to the other each frame (the recording of 5 Oct 11:17: the shoulder line 137 deg, -15, 137, -21 ... on
// successive poses of every switch plant, the hips' line steady; a bean plant ended with the board hung up on the body).
// The half turn has to come OUT of the graph already right. The game makes it in one node of its anim blueprint
// (AnimGraphNode_ModifyBone_1 on AMXX_Root: additive yaw of -180 x IsAnimMirrorOn, straight after the mirror node), and
// what a switch plant needs is the mirror WITHOUT that turn -- so the Lua switches that node's rotation off for the poses
// the other stance is ridden (v182). HJN_Set("swapturn", 3) = a swap is on and nothing is turned here: the swap's poses
// are only known (g_swapOn, for the soft plant's riding spots). 1 / 2 still turn the pose (no build asks for it).
volatile int g_swapOn = 0, g_swapHome = 0, g_swapEnd = 0, g_swapInPose = 1; int g_swapEndN = 0; LONG g_swapPoses = 0, g_swapLogs = 0; ULONGLONG g_swapT0 = 0;
bool SwapTurnRaw(const void* anim);
bool SwapTurn(const void* anim) { return SwapTurnRaw(anim) && g_swapInPose != 0; }
bool SwapTurnRaw(const void* anim) {
    if (!g_swapOn) return false;
    if (!g_swapEnd && GetTickCount64() - g_swapT0 > 20000) g_swapEnd = 1;   // (a swap that was never called off: no trick rides the other stance for 20 s)
    const bool other = (*((const uint8_t*)anim + 0x304) != 0) != (g_swapHome != 0);
    if (g_swapEnd && (!other || ++g_swapEndN > 30)) {             // your own stance is back on the screen (or never came back: 30 poses)
        if (InterlockedIncrement(&g_swapLogs) <= 60)
            Log(g_swapInPose ? "stance swap: over -- the body was turned half round in the pose on %ld poses (the mesh itself was not turned)%s"
                             : "stance swap: over -- the game rode the other stance on %ld poses (its own half turn switched off in its anim graph by the Lua; nothing turned here, the mesh not turned)%s", (long)g_swapPoses,
                other ? "; the game still rides the other stance 30 poses after the swap was called off: the turn is dropped" : "");
        g_swapOn = 0; g_swapEnd = 0; g_swapEndN = 0; g_swapPoses = 0;
        return false;
    }
    if (other) InterlockedIncrement(&g_swapPoses);
    return other;
}
// ==== (v97) SESSIONTWEAKS' RE-LEARN WAITS WHILE THE MOD DRAWS ==========================================================
// "After I was playing for a bit, presumably after I did a bunch of the hippies, now every time the character lands on the
// board, he floats upwards for a couple inches and then floats back down. On landing any trick." It is SessionTweaks'
// landing stance holding the feet to what it has LEARNED of your idle -- and it had learned that from this mod's poses.
// Its own log of 5 Oct: "height held by up to" 1.6-3.3 cm at every landing until 08:58, 14.3 cm from 09:00 on; its ini,
// saved at 08:59: StanceLandBall 17.27 cm (4.15 when it learned it at 08:55), the main stance's feet at x 25.1 / -20.3
// (9.9 / -30.2). Read out of its DLL (3.19.607): it throws all of that away whenever the game's IsSkatingGoofy changes
// ("goofy/regular changed: learning your idle afresh" -- a switch plant rides the other stance for the trick, so twice a
// trick), and learns it again from the first poses after 1.2 s without a reason to hold off -- reasons it reads from the
// game's own flags as UpdateFootAnchors leaves them. A hippie jump is none of them: the board never leaves the ground, the
// game says "riding" all through it, and what SessionTweaks reads then is the mesh this mod has lifted and the pose it
// has drawn -- the foot sockets 13 cm under where they ride, and after a 180 the feet half way through the game's own
// shuffle along the board. Its 1.2 s clock is one float in its data (the only one read, added to and written back by
// "movss xmm0,[clock] / addss xmm0,xmm8 / jmp / movaps xmm0,xmm13 / movss [clock],xmm0", and compared in five places).
// While a pose of this mod's own is on the screen (a hop's air and landing, a plant, a held pose, a grab, the hand on the
// board) and for 1 s after, that clock is set back to 0 once a pose: SessionTweaks does everything it did, except learn.
// Found by that code alone, in the module SessionTweaks/dlls/main.dll: another build of it that has no such code is
// left alone, and the log says so. HJN_Set("stquiet", 0) = off.
volatile int g_stGuard = 1; int g_stState = 0, g_stLooks = 0; float* g_stSettle = nullptr;
ULONGLONG g_stLookAt = 0, g_stQuietTo = 0; LONG g_stZeroed = 0, g_stWindows = 0; bool g_stHot = false, g_stIn = false;
// POD only (its own __try): the clock's address in a loaded SessionTweaks, or null; *cmp = the places that compare it
float* StScan(const uint8_t* b, uint32_t size, int* cmp) {
    float* out = nullptr; *cmp = 0;
    __try {
        const IMAGE_DOS_HEADER* dos = (const IMAGE_DOS_HEADER*)b;
        if (dos->e_magic != IMAGE_DOS_SIGNATURE) __leave;
        const IMAGE_NT_HEADERS* nt = (const IMAGE_NT_HEADERS*)(b + dos->e_lfanew);
        if (nt->Signature != IMAGE_NT_SIGNATURE) __leave;
        const IMAGE_SECTION_HEADER* sec = IMAGE_FIRST_SECTION(nt);
        const uint8_t* tx = nullptr; uint32_t txN = 0; uintptr_t dLo = 0, dHi = 0;
        for (int i = 0; i < (int)nt->FileHeader.NumberOfSections; i++) {
            const uint32_t va = sec[i].VirtualAddress, vs = sec[i].Misc.VirtualSize, ch = sec[i].Characteristics;
            if (va == 0 || vs == 0 || (uint64_t)va + vs > size) continue;
            if (!tx && (ch & IMAGE_SCN_MEM_EXECUTE)) { tx = b + va; txN = vs; }
            if (!dLo && (ch & IMAGE_SCN_MEM_WRITE) && !(ch & IMAGE_SCN_MEM_EXECUTE)) { dLo = (uintptr_t)(b + va); dHi = dLo + vs; }
        }
        if (!tx || txN < 64 || !dLo) __leave;
        static const uint8_t mid[11] = { 0xF3, 0x41, 0x0F, 0x58, 0xC0, 0xEB, 0x04, 0x41, 0x0F, 0x28, 0xC5 };
        int hits = 0; uintptr_t at = 0;
        for (uint32_t i = 0; i + 27 <= txN; i++) {
            const uint8_t* p = tx + i;
            if (p[0] != 0xF3 || p[1] != 0x0F || p[2] != 0x10 || p[3] != 0x05 || p[19] != 0xF3 || p[20] != 0x0F || p[21] != 0x11 || p[22] != 0x05) continue;
            bool same = true;
            for (int j = 0; j < 11 && same; j++) same = p[8 + j] == mid[j];
            if (!same) continue;
            const uintptr_t a = (uintptr_t)(p + 8) + (intptr_t)*(const int32_t*)(p + 4), c = (uintptr_t)(p + 27) + (intptr_t)*(const int32_t*)(p + 23);
            if (a != c || a < dLo || a + 4 > dHi || (a & 3) != 0) continue;
            hits++; at = a;
        }
        if (hits != 1) __leave;
        for (uint32_t i = 0; i + 10 <= txN; i++) {               // movss xmm0,[clock] / comiss xmm0,...
            const uint8_t* p = tx + i;
            if (p[0] == 0xF3 && p[1] == 0x0F && p[2] == 0x10 && p[3] == 0x05 && p[8] == 0x0F && p[9] == 0x2F
                && (uintptr_t)(p + 8) + (intptr_t)*(const int32_t*)(p + 4) == at) (*cmp)++;
        }
        if (*cmp >= 2) out = (float*)at;
    }
    __except (EXCEPTION_EXECUTE_HANDLER) { out = nullptr; }
    return out;
}
void StFind() {
    g_stLooks++; g_stLookAt = GetTickCount64() + 10000;
    HANDLE snap = INVALID_HANDLE_VALUE;
    for (int t = 0; t < 3 && snap == INVALID_HANDLE_VALUE; t++) snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, GetCurrentProcessId());
    if (snap == INVALID_HANDLE_VALUE) { g_stState = -2; return; }
    MODULEENTRY32W me; memset(&me, 0, sizeof(me)); me.dwSize = sizeof(me);
    const uint8_t* base = nullptr; uint32_t size = 0;
    if (Module32FirstW(snap, &me)) {
        do {
            wchar_t lo[MAX_PATH]; int n = 0;
            for (; n < MAX_PATH - 1 && me.szExePath[n]; n++) { const wchar_t c = me.szExePath[n]; lo[n] = (c >= L'A' && c <= L'Z') ? (wchar_t)(c + 32) : c; }
            lo[n] = 0;
            if (n >= 8 && wcsstr(lo, L"\\sessiontweaks\\") && wcscmp(lo + n - 8, L"main.dll") == 0) { base = me.modBaseAddr; size = (uint32_t)me.modBaseSize; break; }
        } while (Module32NextW(snap, &me));
    }
    CloseHandle(snap);
    if (!base) {
        g_stState = -2;
        if (g_stLooks == 12) Log("SessionTweaks is not loaded (looked 12 times): nothing of its to hold back");
        return;
    }
    int cmp = 0;
    float* p = StScan(base, size, &cmp);
    if (p) {
        g_stSettle = p; g_stState = 1;
        Log("SessionTweaks found (its image %u KB): its idle re-learn waits while a trick of this mod's is drawn, and for 1 s after -- its 'settled' clock is at +0x%X, compared in %d places",
            (unsigned)(size >> 10), (unsigned)((uintptr_t)p - (uintptr_t)base), cmp);
    } else {
        g_stState = -1;
        Log("SessionTweaks is loaded, but its code is not the build this was written against (3.19.607: the 'settled' clock was not found) -- its idle re-learn cannot be made to wait. If landings begin to float after switch plants and hops: its F1 menu, 'Re-learn my idle', while rolling");
    }
}
void StQuiet(bool hot) {
    const ULONGLONG now = GetTickCount64();
    if (hot) g_stQuietTo = now + 1000;
    // looked for on a plain pose (the list of loaded modules takes a millisecond or two): not on a trick's first one
    if (g_stGuard != 0 && !hot && (g_stState == 0 || (g_stState == -2 && g_stLooks < 12 && now >= g_stLookAt))) StFind();
    if (g_stGuard == 0 || now >= g_stQuietTo) { g_stIn = false; return; }
    if (g_stState != 1 || !g_stSettle) return;
    *g_stSettle = 0.0f;
    InterlockedIncrement(&g_stZeroed);
    if (!g_stIn) {
        g_stIn = true;
        const LONG w = InterlockedIncrement(&g_stWindows);
        if (w <= 3 || w == 20 || w == 200) Log("SessionTweaks: its 'settled' clock is held at 0 while this trick is drawn (window %ld of this session)", (long)w);
    }
}
int ReplayNow();
void SafeStQuiet() {
    // (v100) ...AND WHILE THE REPLAY EDITOR IS OPEN. "Uh-oh, the floating feet are back. After he lands, it shoots his feet up."
    // SessionTweaks' log of 5 Oct: 'goofy/regular changed: learning your idle afresh' at 14:25:21 (a switch plant), the replay
    // editor opened at 14:25:24, 'learned the normal idle for stance 4: feet at x -33.9 / 2.0 cm' at 14:25:29.0 (-26.2 / 12.7
    // is right), 'replay mode 2 -> 1' at 14:25:29.7 -- it learned from the REPLAYED poses; by 14:31 its ini had the feet's
    // heights at 32 and 130 cm (15) and the landing's ball at 45 cm (4), and it held every landing 40 cm up. Its clock is
    // held at 0 while the replay manager is in playback as well, and for the second after.
    __try { StQuiet(g_stHot || ReplayNow() != 0); }
    __except (EXCEPTION_EXECUTE_HANDLER) {
        g_stState = -1; g_stSettle = nullptr;
        Log("fault while holding SessionTweaks' clock (code %08x) -- left alone from here", GetExceptionCode());
    }
}
// (v100) ...and from the watchdog's own thread, four times a second: in the replay editor the skater's mesh is not sure to
// come through the pose pass at all, and SessionTweaks' hook (UpdateFootAnchors) runs there all the same. One float of its
// data is written; it reads it on the game thread, and either order of the two is fine (0 = not settled).
LONG g_stReplayZ = 0;
void SafeStReplay() {
    __try {
        float* s = g_stSettle;
        if (g_stGuard == 0 || g_stState != 1 || !s || ReplayNow() == 0) return;
        *s = 0.0f; g_stQuietTo = GetTickCount64() + 1000;
        if (InterlockedIncrement(&g_stReplayZ) == 1) Log("SessionTweaks: its 'settled' clock is held at 0 while the replay editor is open as well (it learned your idle from replayed poses on 5 Oct)");
    } __except (EXCEPTION_EXECUTE_HANDLER) {}
}
void PosePass(void* mesh) {
    if (!g_rigOk) return;
    // the mesh's own, live anim instance -- used only while it is the one Lua last confirmed as our
    // skater's ABP (a swapped instance waits the <2 s until Lua hands the new one over)
    void* anim = *(void* const*)((const uint8_t*)mesh + SKM_ANIM);
    if (!anim || anim != g_anim) return;
    const LONG sockMark = InterlockedExchange(&g_sockMark, 0); g_sockLive = (sockMark == 2) ? 1 : 0; g_sockMirLive = (sockMark == 3) ? 1 : 0;           // (v99) this pose's foot sockets were turned by the Lua's call (the note at SockTurn)
    const bool swTurn = SwapTurn(anim);                              // (v97) the other stance's half turn, made in the pose (read once a pose, before anything can return)
    float a[2] = { HandA(anim, 0), HandA(anim, 1) }, w[2], wh[2];   // (v19) by the mesh's own sides (the mirror undone)
    for (int sd = 0; sd < 2; sd++) {
        if (!std::isfinite(a[sd]) || !g_grabOn) a[sd] = 0.0f;
        a[sd] = clampf(a[sd], 0.0f, 1.0f) * clampf(g_strength, 0.0f, 1.0f);
    }
    // (v34) a grab is one of the GAME's grabs: it starts only while the skater's grab byte names one (the hand IK's
    // alpha alone is also up while you carry the board on foot -- the v95 audit counted 11,514-frame "grabs") and,
    // once started, runs on through the release, keeping its kind
    // (v35) ...a release of at most 90 frames: the alpha can hang above nothing for a long time after a bail (the v96
    // grabs ran 460-2085 frames, posing a tumbling skater and teaching the tilt loop nonsense). And a TWO-HAND grab
    // rides on the game's grab: while Lua names one, that is the kind, and both hands carry the stronger hand's weight.
    const int kindNow = g_skater ? *((const uint8_t*)g_skater + SK_GRAB) : 0;
    const bool byteOn = GrabSlot(kindNow) >= 0 && !IsDouble(kindNow);
    const int dbl0 = g_double;
    const int effKind = (byteOn && IsDouble(dbl0)) ? dbl0 : kindNow;
    const bool anyW = a[0] > 0.001f || a[1] > 0.001f;
    static bool realGrab = false, wasByte = false; static int heldKind = 0; static int relFrames = 0;
    bool kindChanged = false;
    if (!anyW) realGrab = false;
    else if (byteOn) {                                   // (a grab taken again during the last one's release is a NEW grab)
        kindChanged = realGrab && (heldKind != effKind || !wasByte);
        realGrab = true; heldKind = effKind; relFrames = 0;
    }
    else if (realGrab && ++relFrames > 90) realGrab = false;
    wasByte = byteOn;
    // (v84) OFF THE BOARD NO GRAB IS POSED. "When I kickflip and then try to grab and bail, his real legs become invisible and
    // he has fake legs that dangle around, attached to the board." 23:57:47: the Tail grab was handed to the game mid-flip, you
    // stepped off -- and the game left its grab byte at 100 for as long as you walked (it clears it only in its own air
    // code), with the hand IK's weight up as it is whenever the board is carried: 412 poses of a 'grab', the legs solved onto
    // the board you were carrying.
    if (g_offBoard) realGrab = false;
    const bool grab = anyW && realGrab;
    g_holdLive = grab && byteOn;
    // (v55) THE GAME'S CATCH ORIENT, HELD THROUGH ITS OWN GRABS. The deck follows the board bone only while the game is in
    // its catch-orient state; when that ended part way through a grab the bone's tilt no longer reached the deck and the
    // deck fell to the game's own pose (the Crail: aim +44, got -18 with the bone at +70 -- "sometimes takes the ini value,
    // sometimes not"; the post-revert Indy too). The Lua holds this state for the click grabs; the native half now holds it
    // through the game's LB/RB grabs as well (HJN_Set("catchhold", 0) turns it off; the trace counts the holds)
    if (g_catchHold && g_holdLive && anim) {
        uint8_t* cs = (uint8_t*)anim + 0x312;        // USkaterAnimInstance::CatchOrientState
        if (*cs == 0) { *cs = 1; InterlockedIncrement(&g_catchHolds); }
    }
    {
        const float relW = (!grab) ? 0.0f : byteOn ? 1.0f : clampf((90.0f - (float)relFrames) / 30.0f, 0.0f, 1.0f);
        if (grab && IsDouble(heldKind)) a[0] = a[1] = fmaxf(a[0], a[1]);
        for (int sd = 0; sd < 2; sd++) {
            w[sd] = a[sd] * relW;
            wh[sd] = clampf(a[sd] / fmaxf(g_handFull * clampf(g_strength, 0.05f, 1.0f), 0.05f), 0.0f, 1.0f) * clampf(g_strength, 0.0f, 1.0f) * relW;
        }
    }
    static bool wasGrab = false;
    if (grab && wasGrab && kindChanged && g_colN >= 5) CollideReport();   // one grab changed into another in the air
    if (grab && wasGrab && kindChanged) { HandAudit(g_grabKind); g_foldExtra = 0.0f; }   // (v85)
    if (grab && (!wasGrab || kindChanged)) {         // a new grab: its leg numbers start over
        g_grabKind = heldKind;
        for (int k = 0; k < 2; k++) { g_legFoot[k] = g_legKnee[k] = 0.0f; g_legFold[k] = g_legAnimFold[k] = 1.0f; }
        g_pitchSense = 1; g_pAcc = 0.0f; g_pFrames = 0;   // (v23) the pitch loop's sense check starts fresh
        g_pI = g_rI = 0.0f; g_pPrevOk = false;             // (v25) and its integrators
        g_revGrab = DeckReversed();                         // (v28) frozen for the grab: a 180 landing mid-grab must not swap ends
        g_newGrab = true; g_senseChecked = false;           // (v31)
        CollideReset(); g_legPrevOk = false;                // (v33)
    }
    if (!grab && wasGrab && g_colN >= 5) CollideReport();   // (v33) the grab is over: its limb audit
    if (!grab && wasGrab) HandAudit(g_grabKind);            // (v85) ...and its hand's
    wasGrab = grab;
    if (g_bail) {                                    // (v63) THE GAME IS BAILING: no pose of ours on a ragdoll, every window closed
        g_guardFrames = g_holdFrames = g_landFrames = g_airFrames = g_traceFrames = 0;
        g_landNote = 0; g_sinkOn = g_sinkArm = false; g_sink = 0.0f;   // (review)
        g_phFrames = 0; g_phBlend = 0; g_phRun = false; g_phHave = false;   // (v89)
        g_phFrames = 0; g_phBlend = 0;                   // (v84)
        g_leanS = 0.0f; for (int k = 0; k < 2; k++) { g_feetS[k] = v3(0, 0, 0); g_kneeS[k] = v3(0, 0, 0); }
        g_fitHave = false; SearchReset(); g_pullState = 0.0f;
        PlantOver(false); g_plantUntil = 0;              // (v73) no plant on a ragdoll
        g_ownOn = false;                                 // (review) no hop landing's own-length window either: this branch returns before LandOwnW can end it
        return;
    }
    const bool guard = g_guard >= 2 || (g_guard == 1 && g_guardFrames > 0);
    if (g_guardFrames > 0) g_guardFrames--;
    if (!grab) g_pullState *= 0.8f;
    float fa[2] = { FootA(anim, 0), FootA(anim, 1) };
    const bool calib = !grab && g_feet && g_boardOk && (fa[0] > 0.9f || fa[1] > 0.9f);
    if (!grab) DeckRelax();
    const bool held = !grab && g_boardOk && DeckHeld();
    const bool trace = g_traceFrames > 0 && g_boardOk;
    const bool hold = g_holdFrames > 0;
    const bool air = g_airFrames > 0 && g_pelvis >= 0;
    if (air) g_airFrames--;
    const bool land = g_landFrames > 0 && g_pelvis >= 0;
    const bool gfeet = g_footGroundUntil != 0 && GetTickCount64() < g_footGroundUntil;   // (v67)
    const bool boneOn = g_boneSide >= 0 && g_boneUntil != 0 && GetTickCount64() < g_boneUntil;   // (v68)
    g_boneW += ((boneOn ? 1.0f : 0.0f) - g_boneW) * 0.2f;
    if (!boneOn && g_boneW < 0.02f) { g_boneW = 0.0f; g_boneLean = 0.0f; g_boneDrop = 0.0f; g_boneNoRelax = false; g_boneRelaxAt = -1.0f; g_boneExtra = 0.0f; g_glueW = 0.0f; g_glueFoot = -1; g_glueRaise = 0.0f; g_glueTail = 0; }
    const bool bone = !grab && g_boardOk && g_boneW > 0.0f;
    const bool tt = g_ttFrames > 0 && g_boardOk;                                     // (v70)
    const bool plant = (g_plantUntil != 0 || g_plantW > 0.0f) && g_pelvis >= 0;         // (v71)
    const bool y180 = swTurn || (g_yaw180Until != 0 && GetTickCount64() < g_yaw180Until);   // (v71; v97: or the other stance's, a swap)
    const bool fhold = g_feetHoldUntil != 0 || g_feetHoldW > 0.0f;                     // (v79)
    const bool unstr = g_stretchFrames > 0;                                            // (v81)
    const bool phOn = g_phFrames > 0 || g_phBlend > 0;                                 // (v84)
    if (!phOn) g_phRun = false;                                                        // (v89) a hold whose blend outlasted its window: the next one starts clean
    if (hold) g_holdFrames--;
    if (!grab) {                                     // the eased corrections start from nothing next grab
        g_leanS = 0.0f; g_closeS = 0.0f; g_lastClose = 0.0f; g_foldExtra = 0.0f;
        for (int k = 0; k < 2; k++) { g_feetS[k] = v3(0, 0, 0); g_kneeS[k] = v3(0, 0, 0); }
        g_fitHave = false;
        SearchReset();
        for (int d = 0; d < 4; d++) g_torso[d] = 0.0f;   // (v36)
    }
    if (!grab && !guard && !calib && !trace && !hold && !held && !air && !land && !gfeet && !bone && !tt && !plant && !y180 && !fhold && !unstr && !g_ownOn && !phOn && !(g_sinkOn || g_sink > 0.05f) && g_legFixW <= 0.0f && g_legLingerUntil == 0) return;   // (review) + a let-down still to be given back (v102: + the legs watched after a goofy switch plant)
    g_stHot = grab || guard || hold || held || air || land || gfeet || bone || plant || y180 || fhold || phOn || g_sinkOn || g_sink > 0.05f || g_swapOn != 0;   // (v97) a pose of the mod's own: SessionTweaks does not learn from it
    const int idx = *(const int*)((const uint8_t*)mesh + SKM_EDIT);
    if (idx < 0 || idx > 1) return;
    uint8_t* arr = (uint8_t*)mesh + SKM_CST + idx * 0x10;
    uint8_t* data = *(uint8_t**)arr;
    const int n = *(const int*)(arr + 8);
    if (!data || n != g_n) { InterlockedIncrement(&g_mismatch); return; }
    for (int i = 0; i < n; i++) {
        const float* t = (const float*)(data + i * 48);
        g_C[i].q = q4(t[0], t[1], t[2], t[3]); g_C[i].p = v3(t[4], t[5], t[6]); g_C[i].s = v3(t[8], t[9], t[10]);
    }
    if (y180) {
        // (v76) THE BODY ONLY, as the game's own half turn is (its graph turns AMXX_Root; the board's bones hang off
        // AMXX_Master beside it). v71-v75 turned EVERY bone -- the skeleton's board with them, and in the air the game
        // steers the real board toward that bone: the board swung half round under the rider and back at the catch (the
        // traces of 20:26:06 and 20:29:06: the back foot's place along the deck -27 -> +31 -> -19 cm in 0.7 s) while the
        // feet were held to their spots on it -- "a skeletal mesh tornado", in every version that had the half turn.
        const int root = (g_pelvis >= 0) ? g_parent[g_pelvis] : -1;
        const V3 pv = (root >= 0) ? g_C[root].p : v3(0.0f, 0.0f, 0.0f);
        const Q4 z180 = q4(0.0f, 0.0f, 1.0f, 0.0f);
        for (int i = 0; i < n; i++) {
            bool body = false;
            for (int x = i, hops = 0; x >= 0 && hops < 64; x = g_parent[x], hops++) if (x == root) { body = true; break; }
            if (!body) continue;
            g_C[i].q = qnorm(qmul(z180, g_C[i].q));
            g_C[i].p = v3(2.0f * pv.x - g_C[i].p.x, 2.0f * pv.y - g_C[i].p.y, g_C[i].p.z);
        }
    }
    for (int i = 0; i < n; i++) { LocalOf(i, g_C, g_L); g_Ct[i] = g_C[i]; g_Lt[i] = g_L[i]; }
    SockSeen(sockMark != 0);                                       // (v99)
    LegRefLearn(calib && g_riding != 0 && !air && !land && !plant && !fhold && !bone && !y180 && g_stretchFrames <= 0);   // (v84) from plain riding poses only
    // learn where each foot bone sits over the drawn deck's foot socket while the game's own foot IK holds it
    g_legFix = (plant || fhold || bone) && !grab;   // (v88, v89) see LegOwnLength(); (v94) the plain no comply too: the game hands in its shins at 31-48 cm (41.2 their own)
    if (g_legFix) g_legLingerOk = 0;
    else if (g_legLingerUntil != 0) {                                            // (v102) the note at g_legLingerUntil
        bool sound = g_legRefOk;
        for (int sd = 0; sd < 2 && sound; sd++) {
            const int ft = g_foot[sd];
            if (ft < 0 || g_legRef[sd][1] < 1.0f) continue;
            const float cur = len(g_Lt[ft].p);
            if (cur < g_legRef[sd][1] * 0.94f || cur > g_legRef[sd][1] * 1.04f) sound = false;
        }
        g_legLingerOk = sound ? g_legLingerOk + 1 : 0;
        if (grab || air || !g_riding || !g_legRefOk || g_legLingerOk >= 12 || GetTickCount64() > g_legLingerUntil) {
            if (g_legLingered > 0 && InterlockedIncrement(&g_legLingerLogs) <= 60)
                Log("legs after a goofy switch plant: put back to their own length on %ld poses after the trick's end (%s)", (long)g_legLingered,
                    g_legLingerOk >= 12 ? "the game's legs are sound again" : (grab || air || !g_riding) ? "a grab, the air or off the ground" : "the time is up");
            g_legLingerUntil = 0; g_legLingerOk = 0; g_legLingered = 0;
        }
        else { g_legFix = true; if (!sound) InterlockedIncrement(&g_legLingered); }
    }
    g_hipFix = (plant || bone) && g_hipFixOn != 0;                               // (v94) ...and through a plant the hip joints go back into their sockets
    g_noLearn = plant || fhold || bone || phOn || air || land || y180 || gfeet || g_swapOn != 0;   // (v87) the feet are a trick's, not a stance's (v98: a stance swap's poses too)
    if (calib) DeckLearn(mesh, anim, fa);
    if (calib)
        for (int k = 0; k < 2; k++) {
            if (!(fa[k] > 0.9f)) continue;
            const V3 s = ReadV3(anim, k ? AI_RFOOT_LOC : AI_LFOOT_LOC);
            if (!finite3(s)) continue;
            const V3 off = sub(g_C[g_foot[k]].p, s);
            if (len(off) > 40.0f) continue;
            g_footOff[k] = g_footOffOk[k] ? lerp(g_footOff[k], off, 0.1f) : off;
            g_footOffOk[k] = true;
        }
    bool changed = y180;                             // (v71: a turned pose is written back whatever else happens)
    float shortEase = 0.0f;                                       // (v89) a turned landing: the legs keep their own length into the blend
    if (land && g_hopFlip && g_landTotal > 0) { const float lf = clampf((float)(g_landTotal - g_landFrames + 1) / (float)g_landTotal, 0.0f, 1.0f); shortEase = 1.0f - lf * lf * (3.0f - 2.0f * lf); }
    g_poleToes = g_kneeToes != 0 && !grab && (air || land || g_sinkOn || g_sink > 0.05f || g_stretchFrames > 0);   // (v95) a hop's poses: a straight leg's knee goes over its toes
    // (v95, review) ...and a squeezed bone comes back over the first 12 % of the air, not in one pose: with the ankle kept the
    // whole 15 cm of shin went into the KNEE on the first pose of the air (19 cm in the straight mini recorded, 13.5 in the 180)
    const bool upEase = air && !land && g_hopFrac >= 0.0f && g_hopFrac < 0.12f;
    g_hingeLast[0][0] = g_hingeLast[0][1] = g_hingeLast[1][0] = g_hingeLast[1][1] = 0.0f; g_ankNow = 0;   // (v99) this pose's hinge rolls, for the recorder
    if (HopHips(g_hopHipOn != 0 && !grab && !plant && !bone && !fhold && (air || land || g_ownOn || g_sinkOn || g_sink > 0.05f))) changed = true;   // (v99) a hop's hip joints back in their sockets, before a leg is solved from them
    if ((air || land || g_stretchFrames > 0) && LegUnstretch(air && !land && !upEase, upEase ? Sm01(g_hopFrac / 0.12f) : shortEase)) changed = true;   // (v82) first: no leg longer than its bones, before anything is solved on it
    if (LandOwnLegs(LandOwnW(air, land, grab, fa, anim))) changed = true;   // (v96) a straight hop's landing: no squeezed leg from the touchdown pose until the game's own are whole again
    if (LegOwnLength()) changed = true;                           // (v89) both legs their own length on every pose of a plant / feet hold / bone window
    g_trGuardHips = g_trGuardFeet = false;
    // (v94) ...ADDED to what is already to be written, not put in its place: this line used to SET `changed`, so on a pose where
    // the guard was on but found nothing to do (most of a turned hop's air) the half turn, the un-stretched legs and the
    // bones put back above were dropped again unless something later happened to change the pose too.
    if (guard && Guard()) changed = true;
    if (LandSink(mesh)) changed = true;                           // (v94) the planned landing's let-down of the hips, given back
    if (hold && Hold(mesh)) changed = true;
    if (land) { if (LandBlend(mesh)) changed = true; g_landFrames--; }   // (v88) a leg grows no faster through the landing than in the air
    LandNote(mesh);                                               // (v94) 'land +N' lines while a trace runs
    if (held) {                                      // the drawn deck eases back after a grab
        TurnComp(g_flipper, g_tq);
        SetComp(g_flipper, g_Ct[g_flipper].q, add(g_Ct[g_flipper].p, v3(0, 0, g_tz)));
        changed = true;
    }
    if (grab) {
        g_lastTweak = g_lastLean = 0.0f;
        g_grabKind = heldKind;                           // (v34) kept through the release
        const bool dbl = IsDouble(g_grabKind);           // (v35) both hands on the board: the front hand leads
        const int sd = dbl ? (g_dblFront ? 1 : 0) : (w[1] > w[0]) ? 1 : 0;   // the stronger grab tips the board and bends the spine
        g_deckOk = g_boardOk && DeckXf(mesh);
        // (v34) the stance for THIS grab: the one last ridden -- unless the feet lie the other way along the deck right
        // now (turned in the air), then the learned stance nearest to them that lies that way. Kept for the whole grab.
        if (g_newGrab && g_deckOk && g_stCur >= 0 && g_st[g_stCur].ok) {
            g_stGrab = g_stCur;
            const V3 f[2] = { qinv(g_dq, sub(g_C[g_foot[0]].p, g_dp)), qinv(g_dq, sub(g_C[g_foot[1]].p, g_dp)) };
            const float dxNow = f[0].x - f[1].x, dxSt = g_st[g_stCur].P[0].x - g_st[g_stCur].P[1].x;
            const int frontK = ProfileFor(g_grabKind, sd).frontFoot, backK = 1 - frontK;
            const float dxLive = f[frontK].x - f[backK].x;
            if (g_grabStance && fabsf(dxLive) > 15.0f) {
                // (v58) THE TAIL LAYOUT. The game rides with the feet in two layouts and the clusters learn both: the usual one
                // (back foot on the tail, front foot over the front truck) and a forward one (both feet a truck's width toward
                // the nose: the nollie / fakie crouch). A grab took whichever was LAST RIDDEN, and after a revert the game sits
                // you in the forward one, so the grab had "the front foot on the nose and the back foot over the rear truck".
                // Now, among every learned stance -- as it lies, or turned round on the deck when it lies the other way from
                // the live feet -- the grab takes the one whose BACK foot stands nearest the tail; the front foot comes from
                // the grab's profile (the hand the game chose), the way you face from the live feet
                const float fwd = (dxLive >= 0.0f) ? 1.0f : -1.0f;
                int best = -1; bool bestTurned = false; float bestBack = 1e9f;
                for (int i = 0; i < ST_N; i++) {
                    if (!g_st[i].ok || !StancePlausible(g_st[i].P)) continue;   // (v87)
                    const bool turned = (g_st[i].P[frontK].x - g_st[i].P[backK].x) * fwd < 0.0f;
                    const float backX = (turned ? -g_st[i].P[backK].x : g_st[i].P[backK].x) * fwd;   // the back foot along the way you face
                    if (best < 0 || backX < bestBack - 3.0f || (backX < bestBack + 3.0f && g_st[i].n > g_st[best].n)) { bestBack = backX; best = i; bestTurned = turned; }
                }
                if (best >= 0) {
                    const Q4 turn = qaxis(v3(0, 0, 1), 180.0f);
                    for (int k = 0; k < 2; k++) {
                        const V3 p = g_st[best].P[k];
                        g_uFootP[k] = bestTurned ? v3(-p.x, -p.y, p.z) : p;
                        g_uFootQ[k] = bestTurned ? qnorm(qmul(turn, g_st[best].Q[k])) : g_st[best].Q[k];
                    }
                    g_stGrab = bestTurned ? ST_N : best;
                    if ((best != g_stCur || bestTurned) && InterlockedIncrement(&g_orientLogs) <= 300)
                        Log("grab %d: the tail layout -- stance #%d%s for this grab (last ridden #%d; front foot %s, facing %s along the deck): L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f)",
                            g_grabKind, best, bestTurned ? " turned round" : "", g_stCur, frontK ? "R" : "L", fwd > 0.0f ? "+x" : "-x",
                            g_uFootP[0].x, g_uFootP[0].y, g_uFootP[0].z, g_uFootP[1].x, g_uFootP[1].y, g_uFootP[1].z);
                }
            } else if (fabsf(dxNow) > 15.0f && dxNow * dxSt < 0.0f) {
                int best = -1; float bd = 1e9f;
                for (int i = 0; i < ST_N; i++) {
                    if (!g_st[i].ok || (g_st[i].P[0].x - g_st[i].P[1].x) * dxNow <= 0.0f) continue;
                    const float d = len(sub(f[0], g_st[i].P[0])) + len(sub(f[1], g_st[i].P[1]));
                    if (d < bd) { bd = d; best = i; }
                }
                if (best >= 0) {
                    g_stGrab = best;
                    if (InterlockedIncrement(&g_orientLogs) <= 200) Log("grab %d: the feet lie the other way along the deck than when last riding -- stance #%d for this grab", g_grabKind, best);
                } else {
                    // (v53) NO LEARNED STANCE LIES THAT WAY YET -- the first grabs after a revert: the game's 180 turns the deck
                    // round under you (its yaw offset 180, "REVERSED") and the turned-round stances are only learned after half
                    // a second of riding still on the ground. Until then the grab went on with the old stance: the along axis
                    // (from the ridden feet) pointed at the wrong end, so the Nose spot sat at the tail and the feet were pulled
                    // 40 cm to the old spots ("the grab is weird after a revert; fine from a fresh marker"). So: the ridden
                    // stance TURNED ROUND on the deck (180 about the deck frame's own up), for this grab
                    const Q4 turn = qaxis(v3(0, 0, 1), 180.0f);
                    for (int k = 0; k < 2; k++) {
                        const V3 p = g_st[g_stCur].P[k];
                        g_uFootP[k] = v3(-p.x, -p.y, p.z);
                        g_uFootQ[k] = qnorm(qmul(turn, g_st[g_stCur].Q[k]));
                    }
                    g_stGrab = ST_N;                             // (the shared memory slot: no stance of its own)
                    if (InterlockedIncrement(&g_orientLogs) <= 200)
                        Log("grab %d: the feet lie the other way along the deck than when last riding and no learned stance does (a revert?) -- stance #%d turned round for this grab: L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f)",
                            g_grabKind, g_stCur, g_uFootP[0].x, g_uFootP[0].y, g_uFootP[0].z, g_uFootP[1].x, g_uFootP[1].y, g_uFootP[1].z);
                }
            }
            if (g_stGrab != ST_N) UseStance(g_stGrab);       // (v53: the turned-round stance is already in place)
        }
        g_newGrab = false;
        const V3 tgtSd = HandLoc(anim, sd);
        if (g_boardOk && g_tweakMax > 0.0f) {
            if (g_tweakMode >= 3) { DeckBoard(mesh, anim, sd, w[sd]); g_lastTweak = qangle(g_tq); }
            else if (g_tweakMode >= 2 && finite3(tgtSd)) g_lastTweak = TweakFit(sd, w[sd], anim, tgtSd);
            else g_lastTweak = Tweak(sd, w[sd], anim);
        }
        const V3 deckUpNow = g_boardOk ? DeckUp() : kUp;
        // Melon (v12): the photo's "boned" melon has the board out in front -- the game locks the deck under the mesh
        // origin, so the body goes back instead (toward the heels), and the legs reach out to the deck
        const float backBy = GP(g_grabKind, GP_BACK);      // (v34: each grab's own; Melon 25)
        if (fabsf(backBy) > 0.01f && g_toe[0] >= 0 && g_toe[1] >= 0 && g_pelvis >= 0) {
            const V3 upl = qrot(g_levelOk ? g_levelQ : g_C[g_flipper].q, g_upL);
            V3 toe = add(sub(g_C[g_toe[0]].p, g_C[g_foot[0]].p), sub(g_C[g_toe[1]].p, g_C[g_foot[1]].p));
            toe = sub(toe, mul(upl, dot(toe, upl)));
            if (len(toe) > 1.0f) SetComp(g_pelvis, g_Ct[g_pelvis].q, sub(g_Ct[g_pelvis].p, mul(norm(toe), backBy * w[sd])));
        }
        // (v22) the tuck: the hips down toward the deck (the legs fold more) so the hand can reach between the feet
        {
            const GrabProfile prT = ProfileFor(g_grabKind, sd);
            const float drop = GP(g_grabKind, GP_DROP) * clampf(w[sd], 0.0f, 1.0f);
            if (drop > 0.01f && g_pelvis >= 0) SetComp(g_pelvis, g_Ct[g_pelvis].q, sub(g_Ct[g_pelvis].p, mul(deckUpNow, drop)));
            g_leanScale = (prT.spot == 3 || prT.spot == 4 || dbl) ? fmaxf(g_leanTuck, 0.0f) : 1.0f;   // the edge grabs (and two hands) may lean further
        }
        if (g_boardOk) {
            const V3 sa = ReadV3(anim, AI_LFOOT_LOC), sb = ReadV3(anim, AI_RFOOT_LOC);
            if (finite3(sa) && finite3(sb)) {
                const V3 deck = sub(sa, sb), skel = sub(g_Ct[g_footAnchor[0]].p, g_Ct[g_footAnchor[1]].p);
                g_lastDeckOff = (len(deck) > 1.0f && len(skel) > 1.0f)
                    ? acosf(clampf(dot(norm(deck), norm(skel)), -1.0f, 1.0f)) * 57.2957795f : -1.0f;
                g_deckShift = len(sub(mul(add(sa, sb), 0.5f), mul(add(g_Ct[g_footAnchor[0]].p, g_Ct[g_footAnchor[1]].p), 0.5f)));
            }
        }
        // (v35) first where each hand goes, then the lean (for both hands at once in a two-hand grab), then the arms
        V3 tg[2] = { { 0, 0, 0 }, { 0, 0, 0 } }, inDir[2] = { { 1, 0, 0 }, { 1, 0, 0 } }; bool on[2] = { false, false }, ownS[2] = { false, false };
        for (int s = 0; s < 2; s++) {
            if (wh[s] <= 0.001f) continue;
            V3 tgt = HandLoc(anim, s);
            if (!finite3(tgt)) { if (!dbl) continue; tgt = g_Ct[g_hand[s]].p; }
            bool own = false;
            if ((s == sd || dbl) && g_deckOk) {
                const GrabProfile pro = ProfileFor(g_grabKind, s);
                const V3 keep = g_lastSpot;
                V3 o;
                if (OwnSpot(g_grabKind, pro, o)) { tgt = o; own = true; g_lastSpotOk = true; g_lastSpotMirrored = false; inDir[s] = g_lastIn; ownS[s] = true; }
                if (dbl && s != sd) { g_lastSpot2 = g_lastSpot; g_lastSpot = keep; }
            }
            if (dbl && !own) continue;                   // a two-hand grab has only the mod's own spots
            if (!own && s == sd && g_deckOk) {
                V3 a, lat;
                const GrabProfile prs = ProfileFor(g_grabKind, sd);
                if (DeckAxes(prs.frontFoot, a, lat)) {
                    const V3 loc = qinv(g_dq, sub(tgt, g_dp));
                    g_lastSpot = v3(dot(loc, a), dot(loc, lat), dot(loc, DeckN()));
                    g_lastSpotOk = true; g_lastSpotMirrored = false;
                    if (g_grabKind == 1 && wh[s] > 0.8f) {             // the Nose spot (the user: Nose hand placement is good)
                        g_noseSpot = g_noseSpotOk ? lerp(g_noseSpot, g_lastSpot, 0.1f) : g_lastSpot;
                        g_noseSpotOk = true;
                    }
                    if (g_grabKind == 100 && g_tailFromNose && g_noseSpotOk) {
                        // (v16) the Tail's own spot looks off -- take the Nose's, at the other end of the board
                        const V3 m = v3(-g_noseSpot.x, g_noseSpot.y, g_noseSpot.z);
                        tgt = add(g_dp, qrot(g_dq, add(add(mul(a, m.x), mul(lat, m.y)), mul(DeckN(), m.z))));
                        g_lastSpotMirrored = true;
                    }
                }
            }
            if (!own) tgt = add(tgt, mul(deckUpNow, g_handUp));   // along the deck's normal (v5; was world-up); our own spots are the wrist
            tg[s] = tgt; on[s] = true;
        }
        if (dbl && on[0] && on[1]) g_lastLean = TorsoTwo(tg, wh, GP(g_grabKind, GP_FOLD) + g_foldExtra, ProfileFor(g_grabKind, sd).frontFoot);   // (v36; v85: + what the hands still lacked)
        else if (on[sd]) g_lastLean = Lean(sd, tg[sd], wh[sd]);
        // (v84) THE HAND LOCKS ON. "The melon grab is killing me: the hand just doesn't lock to the board like the others, it
        // wavers 10 to 20 cm through the grab." Every Melon in the log leaves the wrist 3-12 cm short of its spot AFTER the
        // arm is out straight ('gap 28 -> 5', '33 -> 7', '35 -> 10', '39 -> 12', '31 -> 12'), with the lean at its limit of
        // 40 deg each time; the Mute, Indy, Tail and Stalefish end at 0-3 with the lean at 2-36. The Melon has no board lift
        // and no hip drop of its own (LiftMelon / DropMelon 0 since 30 Sep; the Mute has 8 and 6), so nothing made up the
        // rest and the leftover moved with every sway of the body. For any one-hand grab: what the shoulder still lacks
        // after the lean, the hips make up -- moved straight toward the spot by that much (16 cm at most, eased), the legs
        // folding to suit.
        if (!dbl && on[sd] && g_pelvis >= 0) {
            const V3 dv = sub(tg[sd], g_Ct[g_uarm[sd]].p);
            const float dist = len(dv), reach = armLen(sd) * 0.97f;
            // ...only once the lean is at its limit: the grabs that reach by leaning (Mute, Indy, Tail, Stalefish -- 'very solid')
            // are not touched, not even while their lean is still easing in
            const float cap = g_leanMax * g_leanScale;
            const bool sat = cap > 1.0f && g_lastLean >= cap * 0.9f;
            const float want = (sat && dist > reach) ? fminf(dist - reach, fmaxf(g_closeMax, 0.0f)) * clampf(wh[sd], 0.0f, 1.0f) : 0.0f;
            g_closeS += (want - g_closeS) * 0.15f;
            if (g_closeS > 0.2f && dist > 1.0f) SetComp(g_pelvis, g_Ct[g_pelvis].q, add(g_Ct[g_pelvis].p, mul(dv, g_closeS / dist)));
            g_lastClose = g_closeS;
        }
        // (v85) TWO HANDS LOCK ON TOO. "The cannonball: the hands seem to waver quite a bit." 12:05:20: 'L gap 31 -> 9, R gap 89
        // -> 22' with the back at its Fold of 10 deg (FoldCannonball, set on 30 Sep; the Rocket and Gorilla have 45 and end
        // at 0) -- 9 and 22 cm that nothing made up, moving with every sway. As for one hand: once the back is at its limit
        // the hips go toward the middle of the two spots by what the worse hand lacks (12 cm at most); and what is left
        // after that the back folds for, past the grab's own Fold, only as far as it must (30 deg at most; it does not come
        // back during the grab, so it cannot hunt).
        if (dbl && on[0] && on[1] && g_pelvis >= 0) {
            const float foldCap = clampf(GP(g_grabKind, GP_FOLD) + g_foldExtra, 0.0f, 85.0f);
            const bool sat = g_lastLean >= foldCap * 0.9f - 0.5f;
            const V3 S0 = g_Ct[g_uarm[0]].p, S1 = g_Ct[g_uarm[1]].p;
            const float r0 = armLen(0) * 0.97f, r1 = armLen(1) * 0.97f;
            V3 u = sub(mul(add(tg[0], tg[1]), 0.5f), mul(add(S0, S1), 0.5f));
            const float ul = len(u);
            float want = 0.0f, left = 0.0f;
            if (ul > 1.0f) {
                u = mul(u, 1.0f / ul);
                auto worst = [&](float t) { return fmaxf(len(sub(tg[0], add(S0, mul(u, t)))) - r0, len(sub(tg[1], add(S1, mul(u, t)))) - r1); };
                if (sat && worst(0.0f) > 0.0f) {
                    // (v86) ...and the hips no nearer the deck than 18 cm (they ended 16 over it, the legs with nowhere to go)
                    const float room = g_deckOk ? fmaxf(dot(sub(g_Ct[g_pelvis].p, g_dp), deckUpNow) - 18.0f, 0.0f) : 99.0f;
                    float lo = 0.0f, hi = fminf(fminf(fmaxf(g_closeMax2, 0.0f), ul), room);
                    if (worst(hi) <= 0.0f)
                        for (int i = 0; i < 10; i++) { const float m = 0.5f * (lo + hi); if (worst(m) > 0.0f) lo = m; else hi = m; }
                    left = fmaxf(worst(hi), 0.0f);
                    want = hi * clampf(fmaxf(wh[0], wh[1]), 0.0f, 1.0f);
                }
            }
            g_closeS += (want - g_closeS) * 0.15f;
            if (g_closeS > 0.2f && ul > 1.0f) SetComp(g_pelvis, g_Ct[g_pelvis].q, add(g_Ct[g_pelvis].p, mul(u, g_closeS)));
            g_lastClose = g_closeS;
            if (left > 0.5f && g_closeS > want * 0.8f) g_foldExtra = fminf(g_foldExtra + fminf(0.5f * left, 1.5f), fmaxf(g_foldExtraMax, 0.0f));
        }
        for (int s = 0; s < 2; s++) {
            if (!on[s]) continue;
            const V3 tgt = tg[s];
            const V3 hand = g_Ct[g_hand[s]].p;
            g_lastW[s] = wh[s];
            g_lastGapBefore[s] = len(sub(tgt, hand));
            const V3 hp = HandPath(s, dbl ? s : sd, hand, tgt, wh[s]);   // (v33) by the grab's via point, round the legs
            g_lastReach[s] = (g_tweakMode >= 3 && g_armSearch) ? ArmSearch(s, hp, anim) : Arm(s, hp);
            g_lastGapAfter[s] = len(sub(tgt, g_Ct[g_hand[s]].p));
            if (wh[s] > 0.97f) {                              // (v85) the hand's audit: what is left over, pose by pose, while the grab is held
                g_audCnt[s]++; g_audSum[s] += g_lastGapAfter[s]; if (g_lastGapAfter[s] > g_audMax[s]) g_audMax[s] = g_lastGapAfter[s];
                if (g_lastLean > g_audLean) g_audLean = g_lastLean; if (g_lastClose > g_audClose) g_audClose = g_lastClose; if (g_foldExtra > g_audFold) g_audFold = g_foldExtra;
            }
            if (ownS[s] && (g_handAim >= 2 || (g_handAim == 1 && dbl))) HandPose(s, inDir[s], deckUpNow, wh[s]);   // (v36) the hand turned to its spot, the fingers round the edge
            if (s == sd) g_pullState = clampf(g_pullState + 0.08f * (g_lastGapAfter[s] - 1.0f), 0.0f, fmaxf(g_pullMax, 0.0f));
        }
        if (g_boardOk && g_tweakMode >= 3) DeckLegs(mesh, anim, w, wh);
        else if (g_kneeAway && g_boardOk) KneeAway(wh);
        if (g_boardOk)
            for (int k = 0; k < 2; k++) {
                const float L = len(sub(g_C[g_calf[k]].p, g_C[g_thigh[k]].p)) + len(sub(g_C[g_foot[k]].p, g_C[g_calf[k]].p));
                if (L < 1.0f) continue;
                g_legFoot[k] = fmaxf(g_legFoot[k], len(sub(g_Ct[g_foot[k]].p, g_C[g_foot[k]].p)));
                g_legKnee[k] = fmaxf(g_legKnee[k], len(sub(g_Ct[g_calf[k]].p, g_C[g_calf[k]].p)));
                g_legFold[k] = fminf(g_legFold[k], len(sub(g_Ct[g_foot[k]].p, g_Ct[g_thigh[k]].p)) / L);
                g_legAnimFold[k] = fminf(g_legAnimFold[k], len(sub(g_C[g_foot[k]].p, g_C[g_thigh[k]].p)) / L);
            }
        if (g_boardOk) {                                 // (v33) the limb audit, on the pose as it goes to the screen
            Cap cc[CP_N];
            BuildCaps(cc);
            if (wh[sd] > 0.3f) CollideAudit(sd, dbl, cc);   // (v34) while the hand is really on its way / on the board
            for (int i = 0; i < 6; i++) g_legPrev[i] = cc[6 + i];
            g_legPrevOk = true;
        }
        changed = true;
        InterlockedIncrement(&g_applied);
    }
    if ((fhold || plant || phOn) && !grab && PoseHold(mesh, n)) changed = true;   // (v84) before the feet are placed: the body over a stance swap's frames
    if (fhold && !grab && FeetHold(mesh)) changed = true;    // (v79) first: the plant, once it has its foot, takes both legs over
    if (plant && !grab && PlantHold(mesh)) changed = true;   // (v71) before the hand: the hips come down for the planted leg first
    if (plant && !grab && BackFlat(mesh)) changed = true;    // (v96) the soft plant's other foot: its sole flat on the drawn deck
    if (bone && BoneHand(mesh, g_boneW)) changed = true;   // (v68) the boneless hand
    if (gfeet && GroundFeet(mesh)) changed = true;   // (v67) after everything else: a foot the pose left under the ground
    if (air && !land) { if (HopPull(mesh, anim)) changed = true; if (HopReach(mesh)) changed = true; if (HopLegs()) changed = true; if (AnkleFree(1.0f)) changed = true; AirSave(mesh); }   // (v80) no snap longer; then the feet as the hop carries them (after this frame's edits)
    if (g_stretchFrames > 0) g_stretchFrames--;
    if (trace) TraceLines(mesh, anim);
    if (tt) { g_ttFrames--; if ((g_ttN++ % (g_ttEvery > 0 ? g_ttEvery : 3)) == 0) TrickTraceLine(mesh, anim); }   // (v70) the pose as it goes to the screen
    FootUnderWatch(mesh, anim, (air ? 0x1u : 0u) | (land ? 0x2u : 0u) | (hold ? 0x4u : 0u) | (held ? 0x8u : 0u) | (gfeet ? 0x10u : 0u) | (bone ? 0x20u : 0u) | (plant ? 0x40u : 0u)
        | (fhold ? 0x80u : 0u) | (unstr ? 0x100u : 0u) | (phOn ? 0x200u : 0u) | (grab ? 0x400u : 0u) | (calib ? 0x800u : 0u) | (y180 ? 0x1000u : 0u));   // (v87)
    PoseDump(mesh, anim, n, (air ? 0x1u : 0u) | (land ? 0x2u : 0u) | (plant ? 0x4u : 0u) | (bone ? 0x8u : 0u) | (fhold ? 0x10u : 0u) | (phOn ? 0x20u : 0u) | (gfeet ? 0x40u : 0u) | (y180 ? 0x80u : 0u) | (grab ? 0x100u : 0u) | (tt ? 0x200u : 0u) | (calib ? 0x400u : 0u) | (changed ? 0x800u : 0u) | (hold ? 0x1000u : 0u) | (held ? 0x2000u : 0u) | (guard ? 0x4000u : 0u) | (trace ? 0x8000u : 0u) | (unstr ? 0x10000u : 0u));   // (v94) the pose recorder: every pose that gets here, written back or not
    if (!changed) return;
    // (v10) never hand the renderer a broken pose: every bone finite, a unit rotation, and within 2 m of where
    // the animation had it -- otherwise this frame keeps the game's own pose (a NaN bone can wreck the
    // shadow pass: the v75 crash was in its mesh-draw allocator)
    for (int i = 0; i < n; i++) {
        const Q4 q = g_Ct[i].q; const V3 p = g_Ct[i].p;
        const float ql = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w;
        if (!finite3(p) || !std::isfinite(ql) || fabsf(ql - 1.0f) > 0.02f || len(sub(p, g_C[i].p)) > 200.0f) {
            InterlockedIncrement(&g_faults);
            static LONG logged = 0;
            if (InterlockedIncrement(&logged) <= 20)
                Log("REJECTED a pose: bone %d rot len %.3f pos (%.1f %.1f %.1f), anim (%.1f %.1f %.1f) -- the game's pose kept this frame",
                    i, sqrtf(fmaxf(ql, 0.0f)), p.x, p.y, p.z, g_C[i].p.x, g_C[i].p.y, g_C[i].p.z);
            return;
        }
    }
    for (int i = 0; i < n; i++) {
        float* t = (float*)(data + i * 48);
        t[0] = g_Ct[i].q.x; t[1] = g_Ct[i].q.y; t[2] = g_Ct[i].q.z; t[3] = g_Ct[i].q.w;
        t[4] = g_Ct[i].p.x; t[5] = g_Ct[i].p.y; t[6] = g_Ct[i].p.z;
    }
}

// ------------------------------------------------------------------ the revert trace (research for the 180)
// Per pose while HJN_Trace runs: the board movement component's revert fields (USkateboardExMovementComponent:
// +0x392/+0x3a0 the pending-revert bytes Revert() checks and sets, +0x4c9 the revert type SetRevertType
// stores, +0x4ca, +0x4cc the angle UpdateRevert counts down, +0x4d0/+0x4d4 what SetRevertType writes next),
// the skater's foot position and revert timer, and the anim's RevertType/RevertRatio. POD only (__try).
uint8_t RdU8(const void* b, int o) { return *(const uint8_t*)((const uint8_t*)b + o); }
float   RdF(const void* b, int o) { return *(const float*)((const uint8_t*)b + o); }
int     RdI(const void* b, int o) { return *(const int*)((const uint8_t*)b + o); }
float   QYaw(const void* b, int o) { const float* q = (const float*)((const uint8_t*)b + o);
    return atan2f(2.0f * (q[3] * q[2] + q[0] * q[1]), 1.0f - 2.0f * (q[1] * q[1] + q[2] * q[2])) * 57.2957795f; }
void TraceRevert(void* mesh) {
    void* sk = g_skater;
    if (!sk) return;
    void* board = *(void* const*)((const uint8_t*)sk + SK_BOARD);
    void* bm = board ? *(void* const*)((const uint8_t*)board + BD_MOVE) : nullptr;
    void* anim = *(void* const*)((const uint8_t*)mesh + SKM_ANIM);
    const DWORD now = GetTickCount();
    if (g_traceN == 0) g_traceT0 = now;
    g_traceN++;
    if (!bm) { Log("trace +%d: no board movement component", g_traceN); return; }
    Log("trace +%d (%lu ms): foot %u revertT %.2f | bm 392:%u 3a0:%u 4c9:%u 4ca:%u 4cc:%.1f 4d0:%.2f/%d 4d4:%.1f | "
        "ctrl yaw %.1f deck offset %.0f | anim revert %u ratio %.2f | hold %+.0f | yaw hips %.0f shoulders %.0f feet %.0f skelboard %.0f deck %.0f meshW %.0f%s%s | legs (hip-ankle / bones) L %.0f/%.0f R %.0f/%.0f (their own %.0f %.0f), held back %ld poses (%.0f cm most), un-stretched %ld poses (%.0f cm most) | the game's foot pull L %.2f R %.2f, the feet let down L %.0f R %.0f cm, the reach L %.0f R %.0f, to the spot L %.0f R %.0f%s | feet on the deck (along across over-riding) L %+.0f %+.0f %+.0f R %+.0f %+.0f %+.0f",
        g_traceN, now - g_traceT0, RdU8(sk, SK_FOOTPOS), RdF(sk, SK_REVERT_T),
        RdU8(bm, 0x392), RdU8(bm, 0x3a0), RdU8(bm, 0x4c9), RdU8(bm, 0x4ca), RdF(bm, 0x4cc), RdF(bm, 0x4d0), RdI(bm, 0x4d0), RdF(bm, 0x4d4),
        QYaw(bm, 0x5c0), RdF(bm, 0x624),
        anim ? RdU8(anim, AI_REVERT_TYPE) : 0, anim ? RdF(anim, AI_REVERT_RATIO) : 0.0f, g_lastHold,
        g_trYaw[0], g_trYaw[1], g_trYaw[2], g_trYaw[3], g_trYaw[4], g_trYaw[5],
        g_trGuardHips ? " GUARD-HIPS" : "", g_trGuardFeet ? " GUARD-FEET" : "",
        len(sub(g_Ct[g_foot[0]].p, g_Ct[g_thigh[0]].p)), len(sub(g_Ct[g_calf[0]].p, g_Ct[g_thigh[0]].p)) + len(sub(g_Ct[g_foot[0]].p, g_Ct[g_calf[0]].p)),
        len(sub(g_Ct[g_foot[1]].p, g_Ct[g_thigh[1]].p)), len(sub(g_Ct[g_calf[1]].p, g_Ct[g_thigh[1]].p)) + len(sub(g_Ct[g_foot[1]].p, g_Ct[g_calf[1]].p)),
        g_legRef[0][0] + g_legRef[0][1], g_legRef[1][0] + g_legRef[1][1], g_hopEased, g_hopEasedMost, g_unstretched, g_unstretchMost,
        anim ? FootA(anim, 0) : 0.0f, anim ? FootA(anim, 1) : 0.0f, g_hopPullLast[0], g_hopPullLast[1], g_reachLast[0], g_reachLast[1], g_reachSide[0], g_reachSide[1], g_hopFlip ? " (half turn)" : "",
        TrFoot(mesh, 0).x, TrFoot(mesh, 0).y, TrFoot(mesh, 0).z, TrFoot(mesh, 1).x, TrFoot(mesh, 1).y, TrFoot(mesh, 1).z);
}

// ------------------------------------------------------------------ the hook
typedef void (*FbtFn)(void* self);
FbtFn g_origFbt = nullptr;
bool  g_hooked = false;

int GrabFilter(unsigned code) { return code == EXCEPTION_ACCESS_VIOLATION || code == EXCEPTION_INT_DIVIDE_BY_ZERO
                                    || code == EXCEPTION_FLT_INVALID_OPERATION ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH; }

void SafeApply(void* self) {
    __try {
        // (v95) nothing of the mod's on a pose whose mesh, skater or world is on its way out (the note at PoseWorld)
        int why = 0;
        g_poseWorld = PoseWorld(self, &why);
        if (g_poseWorld) { g_gonePoses = 0; g_inPose = true; PosePass(self); }
        else if (InterlockedIncrement(&g_gonePoses) == 1 && InterlockedIncrement(&g_goneLogs) <= 60)
            Log("level change: our skater's mesh %s -- nothing of the mod's runs on its poses until the Lua hands a skater over again",
                why == 1 ? "is not registered any more" : why == 2 ? "has no owner or world" : why == 3 ? "belongs to a skater that is being destroyed" : "is in a world that has begun tearing down");
    }
    __except (GrabFilter(GetExceptionCode())) {
        g_grabOn = 0;
        InterlockedIncrement(&g_faults);
        Log("fault while posing (grab / guard) (code %08x) -- grab arms off until the next HJN_Set(\"grab\", 1)", GetExceptionCode());
    }
    g_inPose = false; g_poseWorld = nullptr;
}

void SafeTrace(void* self) {
    __try { TraceRevert(self); }
    __except (GrabFilter(GetExceptionCode())) { g_traceFrames = 0; Log("fault in the revert trace -- trace off"); }
}

// (v35) NO LATE FLIPS OUT OF A GRAB. FlipTricksHandler::CheckForLateTrick (InGame_Tick, every frame) does nothing while
// its cooldown (+0x5c) is above 0, and takes stick gestures for a late trick only once "armed" (+0x61: both sticks
// seen centred since the last trick -- which also wipes the gestures gathered so far). The game's own ResetLateTrick
// writes exactly these two. So while our skater holds a grab, or LB/RB is down (the stick push that PICKS the grab is a
// gesture too), every pose writes armed = 0 and keeps the cooldown at 0.2 s: the game never looks at the sticks for a
// late trick. Let go and, 0.2 s on, the sticks have to pass through centre once -- the grab's own stick movements are
// wiped there -- and late flips work as ever. (v96 fed the game centred sticks from Lua instead: that ARMED the late
// trick, and the real stick showing up again at the release read as a flick.)
// The controller comes from Lua (HJN_SetPC); it is used only while it, its flip tricks handler and our skater all
// name each other, so a stale pointer is never written through.
void* g_pc = nullptr;
volatile int g_lateBlock = 1;                  // HJN_Set("lateblock", 0/1)
LONG  g_lateWrites = 0;
uint8_t* LateHandler() {
    const uint8_t* pc = (const uint8_t*)g_pc;
    if (!pc || !g_skater) return nullptr;
    if (*(void* const*)(pc + PC_SKATER) != g_skater) return nullptr;
    uint8_t* fth = *(uint8_t* const*)(pc + PC_FLIPTRICKS);
    if (!fth) return nullptr;
    if (*(void* const*)(fth + FTH_SKATER) != g_skater) return nullptr;
    if (*(void* const*)(fth + FTH_INPUT) != *(void* const*)(pc + PC_INPUT)) return nullptr;
    return fth;
}
int Bumpers() {                                // 1 = LB held, 2 = RB held (what InGame_Tick hands to CheckForGrabs)
    if (!LateHandler()) return 0;
    return (((const uint8_t*)g_pc)[PC_BUMPERS] >> 1) & 3;
}
void LateBlock() {
    if (!g_lateBlock) return;
    uint8_t* fth = LateHandler();
    if (!fth) return;
    const bool grabbing = *((const uint8_t*)g_skater + SK_GRAB) != 0;
    if (!grabbing && ((((const uint8_t*)g_pc)[PC_BUMPERS] >> 1) & 3) == 0) return;
    fth[FTH_LATE_ARMED] = 0;
    float* cd = (float*)(fth + FTH_LATE_COOLDOWN);
    if (!(*cd > 0.2f)) *cd = 0.2f;
    InterlockedIncrement(&g_lateWrites);
}
void SafeLateBlock() {
    __try { LateBlock(); }
    __except (GrabFilter(GetExceptionCode())) { g_pc = nullptr; Log("fault in the late-trick block -- off until Lua hands the controller over again"); }
}
int SafeBumpers() { __try { return Bumpers(); } __except (GrabFilter(GetExceptionCode())) { g_pc = nullptr; return 0; } }

// (v68) RB KEPT FROM THE GAME for a moment (HJN_Set("bumpermask", seconds), only with an XInput pad to read it from instead):
// during a no comply RB is the boneless's, and the game, seeing it held once the board is caught, would pick a grab of its
// own. Its "RB held" bit is cleared here every pose, and RB presses are swallowed at the key hook
volatile ULONGLONG g_bumpMaskUntil = 0; uint64_t g_fnRB = 0, g_fnLB = 0;
void BumperMask() {
    __try { if (GetTickCount64() < g_bumpMaskUntil && LateHandler()) ((uint8_t*)g_pc)[PC_BUMPERS] &= (uint8_t)~0x06; }   // (v69) LB too
    __except (EXCEPTION_EXECUTE_HANDLER) { g_bumpMaskUntil = 0; }
}
// ==== (v96) HOW FAST THE SKATER REALLY MOVES =========================================================================
// "The drop in mechanic still seems to be firing when the player is moving." The one of 5 Oct 00:05:20: SessionTweaks had
// just turned a bail into a run-out ("RUN OUT instead of bail ... kept 911 cm/s") and for half a second the movement
// component's Velocity read (0, 0) while the skater ran on at 9 m/s -- the Lua's standstill test (Velocity under
// DropInStillSpeed) passed, the drop-in set him 267 cm back and turned him 175 deg. The mesh's own place in the world
// does not lie: its travel over the ground, pose to pose, eased by half a pose. HJN_MeshSpeed() -> cm/s, or -1 when no
// pose has come for 0.3 s.
V3 g_spP = { 0, 0, 0 }; double g_spT = 0.0; float g_spNow = 0.0f; bool g_spOk = false;
void SpeedNote(const void* mesh) {
    const V3 p = *(const V3*)((const uint8_t*)mesh + SC_C2W + 0x10);
    const double t = NowS();
    if (!finite3(p)) { g_spOk = false; return; }
    if (g_spOk) {
        const float dt = (float)(t - g_spT);
        if (dt > 0.004f && dt < 0.25f) { const float v = sqrtf((p.x - g_spP.x) * (p.x - g_spP.x) + (p.y - g_spP.y) * (p.y - g_spP.y)) / dt; g_spNow += (v - g_spNow) * 0.5f; }
        else if (dt >= 0.25f) g_spNow = 0.0f;
    }
    g_spP = p; g_spT = t; g_spOk = true;
}
int nMeshSpeed(const Lua& lua) {
    lua.set_number((g_spOk && NowS() - g_spT < 0.3) ? (double)g_spNow : -1.0);
    return 1;
}
// ==== (v95) A FREEZE LEAVES A TRACE ====================================================================================
// "Freezing on map changes. No crash or error message" -- and so nothing in any log either. A thread of the mod's own
// watches a counter the game thread bumps (UGameEngine::Tick, and every pose that comes through the hook). When it has
// stood still for 20 s (and once more at 60) the game thread is stopped for an instant, its registers and the top 32 KB
// of its stack are copied (nothing is allocated or logged while it is stopped), it is let go again, and every word of
// that stack that points into the game's exe, this mod, UE4SS or the system's own DLLs is written to the log: the calls
// it is inside of, resolvable against the PDB. A map that simply takes longer than 20 s to load writes one too; it is
// harmless (two short lists a stall at most).
volatile LONG g_beat = 0, g_wdOn = 0, g_wdTick = 0; volatile DWORD g_gameTid = 0;   // g_wdTick: the engine's tick comes through our hook (without it a pause or the main menu has no beat at all)
uint64_t g_wdStack[4096];
struct WdMod { uintptr_t lo, hi; const char* name; };
bool WdRange(const void* base, const char* name, WdMod& m) {
    const uint8_t* b = (const uint8_t*)base;
    if (!b) return false;
    const IMAGE_DOS_HEADER* dos = (const IMAGE_DOS_HEADER*)b;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
    const IMAGE_NT_HEADERS* nt = (const IMAGE_NT_HEADERS*)(b + dos->e_lfanew);
    m.lo = (uintptr_t)b; m.hi = (uintptr_t)b + nt->OptionalHeader.SizeOfImage; m.name = name;
    return true;
}
size_t WdGrab(HANDLE th, CONTEXT* cx) {              // POD only (its own __try): the game thread's registers and stack
    size_t n = 0;
    if (SuspendThread(th) == (DWORD)-1) return 0;
    __try {
        if (GetThreadContext(th, cx)) {
            MEMORY_BASIC_INFORMATION mbi;
            if (VirtualQuery((const void*)cx->Rsp, &mbi, sizeof(mbi)) == sizeof(mbi) && mbi.State == MEM_COMMIT) {
                const uintptr_t end = (uintptr_t)mbi.BaseAddress + mbi.RegionSize;
                n = (size_t)((end - (uintptr_t)cx->Rsp) / 8);
                if (n > 4096) n = 4096;
                memcpy(g_wdStack, (const void*)cx->Rsp, n * 8);
            }
        }
    }
    __except (EXCEPTION_EXECUTE_HANDLER) { n = 0; }
    ResumeThread(th);
    return n;
}
DWORD WINAPI WatchdogProc(LPVOID) {
    WdMod mods[6]; int nm = 0;
    if (WdRange(GetModuleHandleW(nullptr), "exe", mods[nm])) nm++;
    { HMODULE me = nullptr;
      if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCWSTR)&WatchdogProc, &me) && WdRange(me, "mod", mods[nm])) nm++; }
    if (WdRange(GetModuleHandleW(L"UE4SS.dll"), "ue4ss", mods[nm])) nm++;
    if (WdRange(GetModuleHandleW(L"ntdll.dll"), "ntdll", mods[nm])) nm++;
    if (WdRange(GetModuleHandleW(L"KERNELBASE.dll"), "kernelbase", mods[nm])) nm++;
    if (WdRange(GetModuleHandleW(L"kernel32.dll"), "kernel32", mods[nm])) nm++;
    LONG last = g_beat; ULONGLONG since = GetTickCount64(); int told = 0;
    for (;;) {
        for (int q = 0; q < 4; q++) { Sleep(250); SafeStReplay(); }   // (v100) a second, a quarter at a time: SessionTweaks' clock in the replay editor
        const LONG b = g_beat;
        if (b != last) { last = b; since = GetTickCount64(); told = 0; continue; }
        const ULONGLONG idle = GetTickCount64() - since;
        const DWORD tid = g_gameTid;
        if (!tid || !g_wdTick || told >= 2 || idle < (told ? 60000ull : 20000ull)) continue;
        told++;
        HANDLE th = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT | THREAD_QUERY_INFORMATION, FALSE, tid);
        if (!th) { Log("watchdog: the game thread has not come by for %.0f s, and it could not be opened (error %lu)", (double)idle / 1000.0, GetLastError()); continue; }
        CONTEXT cx; memset(&cx, 0, sizeof(cx)); cx.ContextFlags = CONTEXT_CONTROL | CONTEXT_INTEGER;
        const size_t n = WdGrab(th, &cx);
        CloseHandle(th);
        auto name = [&](uint64_t a, char* o, size_t on) {
            for (int i = 0; i < nm; i++) if (a >= mods[i].lo && a < mods[i].hi) { snprintf(o, on, "%s+0x%llx", mods[i].name, (unsigned long long)(a - mods[i].lo)); return true; }
            return false;
        };
        char one[64]; if (!name(cx.Rip, one, sizeof(one))) snprintf(one, sizeof(one), "%016llx", (unsigned long long)cx.Rip);
        Log("watchdog: the game thread (%lu) has not come by for %.0f s -- a freeze, or a map that takes this long to load. It is at %s. The mod itself: %s its pose pass, its recorder %s, %ld skater poses seen so far. Of the newest %zu words of its stack those that point into a module follow, the newest first (a mod+ word alone does not mean the mod is at work: the engine's tick and every skater pose are called THROUGH its hooks)",
            tid, (double)idle / 1000.0, one, g_inPose ? "INSIDE" : "not in", g_pdBusy ? "BUSY" : "idle", (long)g_calls, n);
        char line[700]; int ll = 0, hits = 0;
        for (size_t i = 0; i < n && hits < 160; i++) {
            if (!name(g_wdStack[i], one, sizeof(one))) continue;
            hits++;
            ll += snprintf(line + ll, sizeof(line) - ll, " %s", one);
            if (ll > 600) { Log("watchdog:%s", line); ll = 0; }
        }
        if (ll > 0) Log("watchdog:%s", line);
    }
    return 0;
}
// ==== (v96) THE BOARD'S SOUNDS AND THE SPEED SETTING ===================================================================
// "The grinds sound dull and not as grindy. It feels like many versions ago the game sound changed." It did, with Lua
// v147's SpeedScale. Read off this exe: the board sets its loops' volume and pitch from the speed over
// USkaterConfig::MaxPushingSpeed, clamped to 0..1 -- ASkateboardEx::AdjustOnBoardGrindingAudio (the grind loops and the
// sound a part makes as it leaves the edge) and StartGrindSounds (the first scrape) divide by [config+0x40];
// AdjustOnBoardIdleRollingAudio (the roll), AjustSurfaceChangedAudio and Push by [+0x40] x [+0x48]. The numbers
// (USkateboardAudioDataAsset, the pak's asset over the constructor's defaults): the grind loop goes from volume 0 /
// pitch 0.8 standing still to 1 / 1.2 at MaxPushingSpeed, the first scrape from volume 0.7 to 1, the roll from 0 / 0.9
// to 1 / 1.1. SpeedScale multiplied that very number (530 -> 1590 at x3), so every grind and every roll played like
// one at a third of its speed: at 312 cm/s (the median riding speed of the session of 4 Oct; its fastest was 763) a
// grind at volume 0.20 and pitch 0.88, where the game has 0.59 and 1.04 -- a third as loud and 2.8 semitones lower.
// THE PUSH'S TOP SPEED IS A PRODUCT (USkateboardExMovementComponent::HandlePendingPush, that number's only reader
// that is not a sound): MaxPushingSpeed x the skater's FAdvancedSettings::MaxPushSpeedMultiplier (skater+0x998+8, the
// game's own "max push speed" option, which nothing else reads) x (1 + the progression stat) x the fast-push ramp. So
// SpeedScale goes into that multiplier and the config keeps the game's number. The game copies its option over the
// skater's when one spawns and when the advanced-settings page is applied (ASkaterCharacterBase::SetAdvancedSettings,
// its two callers; the page reads and writes the PROFILE, never the skater's copy, so nothing of ours reaches the save):
// the Lua asks on its 2 s tick, and a number found there that is not the one written last is the game's own again.
constexpr int SKA_ADV = 0x998, SKA_MC = 0x550, MCA_CONFIG = 0xaf8, CFGA_MAXPUSH = 0x40;   // ASkaterCharacterBase: its FAdvancedSettings (0x74 bytes of multipliers: gravity, push, max push ...), its movement component | USkaterMovementComponent::SkaterConfig | USkaterConfig::MaxPushingSpeed
constexpr int BDA_AUDIO = 0x330, BDA_LOOPS = 0x3e0, ADA_GRIND = 0x328, ACA_VOLUME = 0x238, ACA_PITCH = 0x258;   // ASkateboardEx::_audioData, its grind loops (TArray<UAudioComponent*>: deck, grip tape, trucks, wheels) | the asset's _grindingMin/MaxSpeedVolume, Min/MaxSpeedPitch | UAudioComponent::VolumeMultiplier, PitchMultiplier
void* g_capSk = nullptr; float g_capBase = 1.0f, g_capNow = 0.0f;         // the skater whose multiplier was written | the game's own number | ours
// ONE LINE A GRIND (0.25 s in; 2 s apart at least): what the game has set the loop to, and the speed it had -- the
// deck's own, over the last tenth of a second -- against what its rule gives for that speed. They agree, or it is not
// the speed setting that changes the sound.
const char* const kGsPart[4] = { "deck", "grip tape", "trucks", "wheels" };
double g_gsT0 = 0.0, g_gsT1 = 0.0, g_gsTold = 0.0; V3 g_gsP1 = { 0, 0, 0 }; bool g_gsDone = false; volatile LONG g_gsFaults = 0;
void GrindSound() {
    const uint8_t* sk = (const uint8_t*)(void*)g_skater;
    const uint8_t* bd = (sk && PtrOk(sk, SKA_ADV + 0x74)) ? *(const uint8_t* const*)(sk + SK_BOARD) : nullptr;
    if (!bd || !PtrOk(bd, 0x4f0)) { g_gsT0 = 0.0; return; }
    const uint8_t* const* loops = *(const uint8_t* const* const*)(bd + BDA_LOOPS);
    const int n = *(const int32_t*)(bd + BDA_LOOPS + 8);
    const uint8_t* comp = nullptr; int part = 0;
    if (loops && n > 0 && n <= 4 && PtrOk(loops, 4 * sizeof(void*)))
        for (int i = 0; i < n && !comp; i++) if (loops[i] && PtrOk(loops[i], ACA_PITCH + 8)) { comp = loops[i]; part = i; }
    const uint8_t* deck = *(const uint8_t* const*)(bd + BD_DECK);
    if (!comp || !deck || !PtrOk(deck, SC_C2W + 0x20)) { g_gsT0 = 0.0; return; }
    const double now = NowS();
    const V3 p = *(const V3*)(deck + SC_C2W + 0x10);
    if (g_gsT0 == 0.0) { g_gsT0 = now; g_gsT1 = 0.0; g_gsDone = false; return; }
    if (g_gsDone) return;
    if (g_gsT1 == 0.0) { if (now - g_gsT0 >= 0.15) { g_gsT1 = now; g_gsP1 = p; } return; }
    if (now - g_gsT1 < 0.10) return;
    g_gsDone = true;
    if (now - g_gsTold < 2.0) return;
    g_gsTold = now;
    const uint8_t* mc = *(const uint8_t* const*)(sk + SKA_MC);
    const uint8_t* cfg = (mc && PtrOk(mc, MCA_CONFIG + 8)) ? *(const uint8_t* const*)(mc + MCA_CONFIG) : nullptr;
    const uint8_t* ad = *(const uint8_t* const*)(bd + BDA_AUDIO);
    if (!cfg || !PtrOk(cfg, 0x50) || !ad || !PtrOk(ad, ADA_GRIND + 0x10) || !finite3(p) || !finite3(g_gsP1)) return;
    const float speed = len(sub(p, g_gsP1)) / (float)(now - g_gsT1);
    const float mx = *(const float*)(cfg + CFGA_MAXPUSH); const float* g = (const float*)(ad + ADA_GRIND);
    const float r = mx > 1.0f ? clampf(speed / mx, 0.0f, 1.0f) : 0.0f;
    Log("grind sound: the %s loop is at volume %.2f pitch %.2f, %.2f s in at %.0f cm/s -- the game's rule gives %.2f / %.2f there (the speed over the config's MaxPushingSpeed %.0f = %.2f; volume %.2f..%.2f, pitch %.2f..%.2f). The skater's max-push-speed multiplier is %.2f (the game's own %.2f)",
        kGsPart[part], *(const float*)(comp + ACA_VOLUME), *(const float*)(comp + ACA_PITCH), now - g_gsT0, speed,
        g[0] + (g[1] - g[0]) * r, g[2] + (g[3] - g[2]) * r, mx, r, g[0], g[1], g[2], g[3],
        *(const float*)(sk + SKA_ADV + 8), (sk == (const uint8_t*)g_capSk) ? g_capBase : *(const float*)(sk + SKA_ADV + 8));
}
void SafeGrindSound() {
    __try { GrindSound(); }
    __except (GrabFilter(GetExceptionCode())) { g_gsT0 = 0.0; if (InterlockedIncrement(&g_gsFaults) == 3) Log("fault in the grind sound line (3 times) -- off for this run"); }
}
extern int g_host; void SafeHostInstall();
void hkFbt(void* self) {
    InterlockedIncrement(&g_calls);
    InterlockedIncrement(&g_beat);                          // (v95) the watchdog's counter; the game thread is the one that poses
    if (!g_gameTid) g_gameTid = GetCurrentThreadId();
    if (!g_wdOn && InterlockedExchange(&g_wdOn, 1) == 0) { HANDLE h = CreateThread(nullptr, 0, WatchdogProc, nullptr, 0, nullptr); if (h) CloseHandle(h); }
    if (g_host == 1) { g_host = 0; SafeHostInstall(); }     // (v44) our pause-menu host, placed from the game thread
    if (g_bumpMaskUntil && g_pc) BumperMask();              // (v68)
    if (self && self == g_mesh) {
        SpeedNote(self);                                        // (v96) how fast the skater really moves, for the drop-in's standstill test
        const bool whole = PoseWorld(self) != nullptr;          // (v95, review) the controller's write and the trace read the skater too: the same test
        if (whole && g_pc) SafeLateBlock();
        if (whole && g_gsFaults < 3) SafeGrindSound();          // (v96) one log line a grind: what the game set its loop to
        g_stHot = false;
        SafeApply(self);
        SafeStQuiet();                                          // (v97) while a pose of ours is drawn, SessionTweaks' idle re-learn waits
        if (g_traceFrames > 0) { g_traceFrames--; if (whole) SafeTrace(self); }
    }
    g_origFbt(self);
}

bool InstallHook() {
    if (g_hooked) return true;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    const IMAGE_DOS_HEADER* dos = (const IMAGE_DOS_HEADER*)exe;
    const IMAGE_NT_HEADERS64* nt = (const IMAGE_NT_HEADERS64*)(exe + dos->e_lfanew);
    if (nt->FileHeader.TimeDateStamp != kExeStamp) {
        Log("the game exe is a different build (stamp %08x, expected %08x) -- the pose hook is NOT installed",
            nt->FileHeader.TimeDateStamp, kExeStamp);
        return false;
    }
    void** slot = (void**)(exe + RVA_SKM_VT_FBT);
    void* expect = exe + RVA_FBT;
    if (*slot != expect)
        Log("note: the skater mesh's FinalizeBoneTransform slot holds %p, not the engine's %p -- chaining to it", *slot, expect);
    DWORD old = 0;
    if (!VirtualProtect(slot, sizeof(void*), PAGE_READWRITE, &old)) { Log("VirtualProtect failed (%lu) -- no hook", GetLastError()); return false; }
    g_origFbt = (FbtFn)*slot;
    *slot = (void*)&hkFbt;
    VirtualProtect(slot, sizeof(void*), old, &old);
    g_hooked = true;
    Log("pose hook installed: USkaterSkeletalMeshComponent::FinalizeBoneTransform slot @ %p (original %p)", slot, (void*)g_origFbt);
    return true;
}

// ------------------------------------------------------------------ the Lua half's calls
// get_* take stack index 1 and REMOVE it (so arguments come off in order); set_* push a result.
bool ArgNum(const Lua& lua, double& out) {
    if (lua.get_stack_size() < 1) return false;
    if (!lua.is_number()) { lua.discard_value(); return false; }
    out = lua.get_number();
    return true;
}
bool ArgStr(const Lua& lua, std::string& out) {
    if (lua.get_stack_size() < 1) return false;
    if (!lua.is_string()) { lua.discard_value(); return false; }
    const std::string_view v = lua.get_string();
    out.assign(v.data(), v.size());
    return true;
}
std::vector<int> ParseInts(const std::string& s) {
    std::vector<int> v;
    const char* p = s.c_str();
    while (*p) {
        char* e = nullptr;
        const long x = strtol(p, &e, 10);
        if (e == p) { p++; continue; }
        v.push_back((int)x);
        p = e;
    }
    return v;
}

// HJN_Version() -> the native half's version
int nVersion(const Lua& lua) { lua.set_integer(kVersion); return 1; }

// HJN_SetMesh(meshAddress, animInstanceAddress, skaterAddress) -> 1 if the pose hook is live
// (v62) A NEW SKATER MESH: everything learned about the last one goes with it. v1-v61 kept the stance clusters (the riding
// ankles over the deck), the deck frame, the board-socket offsets and the per-stance base memories across a map change
// and only reset the foot IK offsets: after the map switches of 2 Oct the learned riding ankle heights had crept from
// 15-18 to 19-24 cm and every grab sat a hand's width high ("the grabs are offset in Z"). Start clean, as at launch
void ForgetSkater(const char* why) {
    g_footOffOk[0] = g_footOffOk[1] = false; g_pullState = 0.0f; g_guardFrames = 0; g_traceFrames = 0; g_holdFrames = 0;
    g_offBOk[0] = g_offBOk[1] = false; g_sockFrame = 0;
    g_dFootOk[0] = g_dFootOk[1] = false; g_dFootN = 0; g_dLevelOk = false; g_dUpOk = false; g_upOk = false; g_levelOk = false;
    g_lastSampleOk = false; g_candN = 0; g_stCur = g_stVote = g_stGrab = -1; g_stVotes = 0;
    for (int i = 0; i < ST_N; i++) { if (g_st[i].ok) BaseMemForget(i); g_st[i].ok = false; g_st[i].n = 0; g_st[i].seen = 0; }
    g_learnFootH[0] = g_learnFootH[1] = -99.0f;
    g_boundsR = 0.0f; g_bail = 0; g_ownOn = false;   // (review) + the hop landing's window: nothing of the last skater's is handed on
    g_swapOn = 0; g_swapEnd = 0; g_swapEndN = 0; g_shinRideN[0] = g_shinRideN[1] = 0; g_ownTwist[0] = g_ownTwist[1] = 0.0f;
    g_footRelN[0] = g_footRelN[1] = 0;                                  // (v100)
    g_hingeN[0] = g_hingeN[1] = 0; g_hingeAgain[0] = g_hingeAgain[1] = 0; g_hingeOdd[0] = g_hingeOdd[1] = 0; g_hopHipW = 0.0f; g_sockLive = 0;   // (v99)   // (v97) no stance swap, no riding shin of the last skater's
    Log("skater mesh changed (%s): the learned stances, deck frame, socket and foot offsets are forgotten -- learned again as you ride", why);
}
int nSetMesh(const Lua& lua) {
    double m = 0, a = 0, s = 0;
    ArgNum(lua, m); ArgNum(lua, a); ArgNum(lua, s);
    void* mesh = (void*)(uintptr_t)m;
    void* anim = (void*)(uintptr_t)a;
    void* sk = (void*)(uintptr_t)s;
    if (mesh != g_mesh || anim != g_anim || sk != g_skater) Log("our skater %p: mesh %p, anim instance %p", sk, mesh, anim);
    if (mesh != g_mesh) ForgetSkater(mesh ? "another mesh" : "stood down");
    g_gonePoses = 0;                                 // (v95) a skater handed over (or stood down): the next 'level change' line is a new one
    g_mesh = mesh; g_anim = anim; g_skater = sk;
    lua.set_integer(g_hooked ? 1 : 0);
    return 1;
}

// HJN_Trace(poses, tag): log the revert state for the next poses (research for the 180)
int nTrace(const Lua& lua) {
    double f = 0; std::string tag;
    ArgNum(lua, f); ArgStr(lua, tag);
    g_traceN = 0;
    g_traceFrames = (int)clampf((float)f, 0.0f, 600.0f);
    Log("---- trace (%s): %d poses", tag.c_str(), g_traceFrames);
    lua.set_integer(g_traceFrames);
    return 1;
}

// the lowest common ancestor of bones a and b (parents precede children), -1 if none
int Lca(int a, int b) {
    static bool mark[MAX_BONES];
    for (int i = 0; i < MAX_BONES; i++) mark[i] = false;
    for (int x = a; x >= 0; x = g_parent[x]) mark[x] = true;
    for (int x = b; x >= 0; x = g_parent[x]) if (mark[x]) return x;
    return -1;
}

// HJN_SetRig("p0 p1 p2 ...", chain) -> bone count accepted (0 = refused). chain =
//   uarmL larmL handL uarmR larmR handR  [thighL calfL footL thighR calfR footR  flipper footAnchL footAnchR handAnchL handAnchR]
// (the bracketed part is what the board tweak needs; without it only the arms are posed)
int nSetRig(const Lua& lua) {
    std::string ps, cs;
    ArgStr(lua, ps); ArgStr(lua, cs);
    const std::vector<int> par = ParseInts(ps), ch = ParseInts(cs);
    const int n = (int)par.size();
    auto chainOk = [&](int a, int b, int c) { return par[b] == a && par[c] == b; };
    bool ok = n > 0 && n <= MAX_BONES && (ch.size() == 6 || ch.size() == 17 || ch.size() == 19 || ch.size() == 21 || ch.size() == 51);
    for (int i = 0; ok && i < n; i++) if (par[i] >= i || par[i] < -1) ok = false;       // parents first
    for (size_t k = 0; ok && k < 6; k++) if (ch[k] < 0 || ch[k] >= n) ok = false;
    for (int sd = 0; ok && sd < 2; sd++) if (!chainOk(ch[sd * 3], ch[sd * 3 + 1], ch[sd * 3 + 2])) ok = false;
    if (!ok) {
        Log("rig refused: %d bones, chain of %d (parents must precede children; upper arm > forearm > hand)", n, (int)ch.size());
        g_rigOk = g_boardOk = false;
        lua.set_integer(0);
        return 1;
    }
    bool board = ch.size() >= 17;
    for (size_t k = 6; board && k < 17; k++) if (ch[k] < 0 || ch[k] >= n) board = false;
    for (int sd = 0; board && sd < 2; sd++) if (!chainOk(ch[6 + sd * 3], ch[7 + sd * 3], ch[8 + sd * 3])) board = false;
    for (int k = 13; board && k < 17; k++) if (par[ch[k]] != ch[12]) board = false;       // anchors ride the Flipper
    g_rigOk = g_boardOk = false;          // (the hook reads these: off while they change)
    for (int i = 0; i < n; i++) g_parent[i] = par[i];
    for (int sd = 0; sd < 2; sd++) { g_uarm[sd] = ch[sd * 3]; g_larm[sd] = ch[sd * 3 + 1]; g_hand[sd] = ch[sd * 3 + 2]; }
    if (board) {
        for (int sd = 0; sd < 2; sd++) { g_thigh[sd] = ch[6 + sd * 3]; g_calf[sd] = ch[7 + sd * 3]; g_foot[sd] = ch[8 + sd * 3]; }
        g_flipper = ch[12];
        g_footAnchor[0] = ch[13]; g_footAnchor[1] = ch[14]; g_handAnchor[0] = ch[15]; g_handAnchor[1] = ch[16];
        for (int sd = 0; sd < 2; sd++) {
            const int t = (ch.size() >= 19) ? ch[17 + sd] : -1;
            g_toe[sd] = (t >= 0 && t < n && par[t] == g_foot[sd]) ? t : -1;
        }
    }
    g_n = n;
    g_neck = (ch.size() >= 21 && ch[19] >= 0 && ch[19] < n) ? ch[19] : -1;      // (v33) for the limb audit's head
    g_head = (ch.size() >= 21 && ch[20] >= 0 && ch[20] < n) ? ch[20] : -1;
    g_pelvis = g_spine1 = g_chest = -1;
    if (board) {
        g_chest = Lca(g_uarm[0], g_uarm[1]);
        g_pelvis = Lca(g_thigh[0], g_thigh[1]);
        int prev = -1, x = g_chest;
        while (x >= 0 && x != g_pelvis) { prev = x; x = g_parent[x]; }
        if (x == g_pelvis) g_spine1 = prev;
    }
    g_spineN = 0;                                  // (v36) spine1 .. chest, root first
    if (g_spine1 >= 0 && g_chest >= 0) {
        int up[6], m = 0;
        for (int x = g_chest; x >= 0 && m < 6; x = g_parent[x]) { up[m++] = x; if (x == g_spine1) break; }
        if (m > 0 && up[m - 1] == g_spine1) { for (int i = 0; i < m; i++) g_spine[i] = up[m - 1 - i]; g_spineN = m; }
    }
    for (int s = 0; s < 2; s++) {                  // (v36) the fingers
        const bool have = ch.size() >= 51;
        bool fok = have;
        for (int f = 0; f < 5; f++) {
            bool one = have;                       // (the thumb may hang off another bone: only the four fingers must fit)
            for (int j = 0; j < 3; j++) {
                const int b = have ? ch[21 + s * 15 + f * 3 + j] : -1;
                g_fing[s][f][j] = (b >= 0 && b < n) ? b : -1;
                if (g_fing[s][f][j] < 0) one = false;
                else if (j > 0 && par[g_fing[s][f][j]] != g_fing[s][f][j - 1]) one = false;
                else if (j == 0 && f > 0 && par[g_fing[s][f][j]] != g_hand[s]) one = false;
            }
            if (!one) { if (f > 0) fok = false; else g_fing[s][0][0] = -1; }
        }
        g_fingOk[s] = fok;
    }
    Log("rig: spine of %d joints, fingers L %s R %s", g_spineN, g_fingOk[0] ? "found" : "NOT found", g_fingOk[1] ? "found" : "NOT found");
    g_rigOk = true;
    g_boardOk = board;
    Log("rig: %d bones; arms L %d > %d > %d, R %d > %d > %d; board %s (flipper %d, legs L %d > %d > %d, R %d > %d > %d)",
        n, g_uarm[0], g_larm[0], g_hand[0], g_uarm[1], g_larm[1], g_hand[1], board ? "OK" : "NOT resolved -- no tweak",
        g_flipper, g_thigh[0], g_calf[0], g_foot[0], g_thigh[1], g_calf[1], g_foot[1]);
    Log("rig: pelvis %d, spine %d, chest %d (lean + guard %s)", g_pelvis, g_spine1, g_chest, g_spine1 >= 0 ? "on" : "OFF -- no spine found");
    lua.set_integer(n);
    return 1;
}

// ---- the instant revert. The game's revert (Revert -> the board movement component) keeps its state
// there: +0x4ca running (1/2 = which way), +0x4cc the angle still to turn -- UpdateRevert takes
// RevertRotationRate*dt off it each frame and writes the board's TARGET orientation (+0x5c0, a quat)
// from the deck's current one turned by that step; when it reaches 0 the revert completes (the skater's
// foot position flips) a frame later. Here the target is turned the whole remaining way at once and the
// remaining angle left at a hair, so the game completes it on its next update. Returns the yaw (degrees)
// the caller must now teleport the board's bodies by, about the deck's centre; 0 = nothing running.
float DoInstantRevert() {
    void* sk = g_skater;
    if (!sk) return 0.0f;
    void* board = *(void* const*)((const uint8_t*)sk + SK_BOARD);
    uint8_t* bm = board ? *(uint8_t* const*)((const uint8_t*)board + BD_MOVE) : nullptr;
    if (!bm) return 0.0f;
    const uint8_t st = bm[0x4ca];
    const float rem = *(const float*)(bm + 0x4cc);
    if (st == 0 || !(rem > 0.05f) || rem > 360.0f) return 0.0f;
    const float yaw = (st == 1) ? -rem : rem;
    Q4* tgt = (Q4*)(bm + 0x5c0);
    *tgt = qnorm(qmul(qaxis(v3(0, 0, 1), yaw), *tgt));
    if (g_revertCtl) { Q4* q = (Q4*)(bm + 0x4f0); *q = qnorm(qmul(qaxis(v3(0, 0, 1), yaw), *q)); }
    *(float*)(bm + 0x4cc) = 0.001f;
    return yaw;
}
float SafeInstantRevert() {
    __try { return DoInstantRevert(); }
    __except (GrabFilter(GetExceptionCode())) { Log("fault in the instant revert"); return 0.0f; }
}
// ---- THE REVERSED-DECK SWAP (v6, SwitchLanding 4): a 180 landing with the deck left exactly where it is.
// Static research (scratchpad board_reverse_A/B.md): USkateboardExMovementComponent keeps the rider's frame
// (the controller quat, comp+0x5C0 -- GetBoardControllerQuat's iface+0x488, iface = comp+0x138) apart from
// the deck's own facing: comp+0x624 is a yaw offset (deg) of the deck about the controller's up, and every
// grounded PID target is GetLocalAnimatorBoardQuat = ctrl * yaw(comp+0x624) (* the small manual/primo
// pitch/roll). A pop shove-it leaves 0x624 = +-180 with ctrl untouched ("deck reversed"); the game keeps that
// state (PostPhysSkateboarding / StopBoardRotation snap 0x624 to multiples of 180, SetBoardControllerQuat
// rebuilds ctrl from the deck body with a 180 fix while IsBoardReversed, and the nose/tail labels follow
// IsBoardReversed). A revert instead turns ctrl alone, so the deck spins -- the asymmetric-deck problem.
// Here: ctrl turned 180 about its own up AND 0x624 toggled 0 <-> 180 in the same frame, so the PID target
// is unchanged and the deck never moves; the rider (whose facing follows ctrl) is now turned round; then
// ASkaterCharacterBase::AdjustFootPositionAndMoveDirection re-derives footPosition from ctrl vs the move
// direction (Regular <-> Fakie, Nollie <-> Switch) and fires the game's own foot-position event.
constexpr uintptr_t RVA_ADJUST_FOOT = 0xfe95a0;    // ASkaterCharacterBase::AdjustFootPositionAndMoveDirection(bool, bool)
constexpr uintptr_t RVA_POP_PENDING = 0xff8590;    // ASkaterCharacterBase::IsPopPending() const
constexpr int BM_CTRL = 0x5c0, BM_CTRL_LAST = 0x610, BM_DECK_YAW = 0x624, BM_REVERTING = 0x4ca, BM_FLIPBITS = 0x7e9;
constexpr int SK_PRIMO = 0xa0c;
typedef void (*AdjustFootFn)(void* skater, bool force, bool force2);
typedef bool (*PopPendingFn)(const void* skater);
char g_swapWhy[160] = "";
int DoReverseSwap(float actorYaw, bool haveYaw) {
    g_swapWhy[0] = 0;
    uint8_t* sk = (uint8_t*)g_skater;
    if (!sk || !g_hooked) { strcpy_s(g_swapWhy, "no skater / not this game build"); return 0; }
    uint8_t* board = *(uint8_t**)(sk + SK_BOARD);
    uint8_t* bm = board ? *(uint8_t**)(board + BD_MOVE) : nullptr;
    if (!bm) { strcpy_s(g_swapWhy, "no board movement component"); return 0; }
    if (bm[BM_REVERTING] != 0) { strcpy_s(g_swapWhy, "a revert is running"); return 0; }
    if (bm[BM_FLIPBITS] & 0x28) { strcpy_s(g_swapWhy, "the board is flipping / scooping"); return 0; }
    if (sk[SK_PRIMO] != 0) { strcpy_s(g_swapWhy, "in a primo"); return 0; }
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    if (((PopPendingFn)(exe + RVA_POP_PENDING))(sk)) { strcpy_s(g_swapWhy, "a pop is pending"); return 0; }
    const Q4 turn = q4(0, 0, 1, 0);                        // 180 about Z, applied in the controller's own frame
    Q4* ctrl = (Q4*)(bm + BM_CTRL);
    Q4* last = (Q4*)(bm + BM_CTRL_LAST);
    float* yaw = (float*)(bm + BM_DECK_YAW);
    const Q4 c0 = *ctrl; const float y0 = *yaw; const uint8_t f0 = sk[SK_FOOTPOS];
    // (v61) THE CONTROLLER MUST SIT ON THE RIDER'S AXIS (0 or 180) TO BEGIN WITH. On 2 Oct at 18:48 it sat 130 deg off, the
    // deck offset at 360 (the game's own reverts ADD 180; one of them had been cut short by a bail): the swap turned that
    // into a rider whose feet followed the real deck and whose torso followed the skeleton's board, 70-110 deg apart, for
    // good. Refused here, Lua falls back to the game's own revert, which squares the lot
    // (v63) ...against the CAPSULE's yaw, as Lua read it this frame (the controller quat is a WORLD yaw; v61 compared it with
    // world 0/180, true only riding along the world's X, and refused most swaps)
    if (haveYaw) {
        const float rel = Wrap180(QYaw(&c0, 0) - actorYaw);
        const float off = fminf(fabsf(rel), fabsf(fabsf(rel) - 180.0f));
        if (off > 30.0f) {
            snprintf(g_swapWhy, sizeof(g_swapWhy), "the board's target sits %.0f deg off your capsule (deck offset %.0f) -- the game's own revert instead", rel, y0);
            return 0;
        }
    }
    *ctrl = qnorm(qmul(c0, turn));
    *last = qnorm(qmul(*last, turn));
    const float yn = Wrap180(y0);                                   // (v61) 360 is 0: reversed-or-not is the offset wrapped to a half turn
    *yaw = (fabsf(yn) < 90.0f) ? 180.0f : 0.0f;
    ((AdjustFootFn)(exe + RVA_ADJUST_FOOT))(sk, true, true);
    uint8_t f1 = sk[SK_FOOTPOS];
    bool manual = false;
    if (f1 == f0 && f0 >= 1 && f0 <= 4) {                  // the game's gate said no (e.g. its on-board flag): by hand
        static const uint8_t flip[5] = { 0, 2, 1, 4, 3 };
        f1 = flip[f0];
        sk[SK_FOOTPOS + 1] = f0; sk[SK_FOOTPOS] = f1; sk[SK_FOOTPOS + 2] = (f1 == 2 || f1 == 4) ? 1 : 2;
        manual = true;
    }
    // (v87) THE POWERSLIDE AFTER A 180. "Power slides are still blocked." The tries of 4 Oct 13:3x that failed all read
    // 'foot position 3 (was 4)' (or 1 / was 2): the game's adjust writes the OLD foot position to the byte after it, and
    // Skate_CheckForPowerSlides ends a slide on the tick the two differ (its sliding branch compares +0x599 with +0x598 and
    // leaves through ExitPowerSlide). The game's own flow calls the adjust again before any slide; after this swap nothing
    // does, so the two stayed apart until something else adjusted the stance -- every slide begun in between was ended on
    // its first tick. The previous foot position is the new one from here.
    sk[SK_FOOTPOS + 1] = sk[SK_FOOTPOS];
    Log("reversed-deck swap: ctrl yaw %.1f -> %.1f, deck yaw offset %.0f -> %.0f, foot position %u -> %u%s",
        QYaw(&c0, 0), QYaw(ctrl, 0), y0, *yaw, f0, f1, manual ? " (written by hand: the game's adjust did not change it)" : "");
    return 1;
}
int SafeReverseSwap(float ay, bool have) {
    __try { return DoReverseSwap(ay, have); }
    __except (GrabFilter(GetExceptionCode())) { strcpy_s(g_swapWhy, "fault"); Log("fault in the reversed-deck swap"); return 0; }
}
// ---- THE BOARD HOP (v15): after a bail the board lies on the ground as a free physics body ("ragdoll":
// board+0x3f0 bit 0, set by Bail -> EnableRagDoll). The game's own toggle would first put it in the hand
// (DisableRagDoll -> PlaceInHand). Research (scratchpad jump_on_board.md): ApplyToggleOnBoard(true) -- run by
// the skater's Tick when the reflected SetPendingApplyToggleOnBoard has set +0xa39 -- mounts the skater on the
// board AT THE BOARD'S OWN LOCATION (ASkateboardEx::SetOnBoardMode + SnapToGround), turning it to the capsule's
// yaw, plus 180 when IsSkatingSwitch != boardMC+0xa34. So after Lua's jump arc lands the capsule over the board:
// the pending foot position (+0xa38: 1 Regular / 4 Switch), the flip flag chosen so the deck keeps its heading,
// and the ragdoll bit cleared -- then Lua calls SetPendingApplyToggleOnBoard in the same game-thread slice.
constexpr int SK_MC = 0x550, MC_ONBOARD = 0xe20, SK_PENDFOOT = 0xa38, SK_PENDTOGGLE = 0xa39, SK_THROWDOWN = 0xa28, SK_PICKUP = 0xa29;
constexpr int BD_FLAGS = 0x3f0, BM_FLIPFLAG = 0xa34;
// -> flags: 1 the board lies loose (ragdoll), 2 board+0x3f0 bit 1 (the game would place it at the skater), 4 on
// board, 8 busy (throwdown / pickup / a toggle pending); -1 no board
constexpr int BM_MODE = 0x534;                  // USkateboardExMovementComponent::_movementMode (1 riding, 3 falling, 5 in hand, 6 throwdown, 8 loose)
uint8_t* BoardMC();
int BoardState() {
    const uint8_t* sk = (const uint8_t*)g_skater;
    if (!sk) return -1;
    const uint8_t* bd = *(const uint8_t* const*)(sk + SK_BOARD);
    const uint8_t* mc = *(const uint8_t* const*)(sk + SK_MC);
    if (!bd || !mc) return -1;
    int f = 0;
    if (bd[BD_FLAGS] & 1) f |= 1;
    if (bd[BD_FLAGS] & 2) f |= 2;
    if (mc[MC_ONBOARD]) f |= 4;
    if (sk[SK_THROWDOWN] || sk[SK_PICKUP] || sk[SK_PENDTOGGLE]) f |= 8;
    if (uint8_t* bm = BoardMC()) f |= ((int)bm[BM_MODE] & 0xff) << 4;   // (v40) the board's own movement mode
    return f;
}
int SafeBoardState() { __try { return BoardState(); } __except (GrabFilter(GetExceptionCode())) { return -1; } }
int nBoardState(const Lua& lua) { lua.set_integer(SafeBoardState()); return 1; }

// HJN_DeckWorld() -> "x y z yaw upz" of the drawn deck in the world ("" if none)
bool DeckWorld(char* out, size_t n) {
    const uint8_t* sk = (const uint8_t*)g_skater;
    if (!sk) return false;
    const uint8_t* bd = *(const uint8_t* const*)(sk + SK_BOARD);
    const uint8_t* deck = bd ? *(const uint8_t* const*)(bd + BD_DECK) : nullptr;
    if (!deck) return false;
    const Q4 q = *(const Q4*)(deck + SC_C2W); const V3 p = *(const V3*)(deck + SC_C2W + 0x10);
    const V3 fx = qrot(q, v3(1, 0, 0)), up = qrot(q, v3(0, 0, 1));
    snprintf(out, n, "%.2f %.2f %.2f %.2f %.3f", p.x, p.y, p.z, atan2f(fx.y, fx.x) * 57.2957795f, up.z);
    return finite3(p);
}
// HJN_DeckAxes() -> "fx fy fz ux uy uz": the drawn deck's long axis and its up, in the world ("" if none)
bool DeckAxesWorld(char* out, size_t n) {
    const uint8_t* sk = (const uint8_t*)g_skater;
    if (!sk) return false;
    const uint8_t* bd = *(const uint8_t* const*)(sk + SK_BOARD);
    const uint8_t* deck = bd ? *(const uint8_t* const*)(bd + BD_DECK) : nullptr;
    if (!deck) return false;
    const Q4 q = *(const Q4*)(deck + SC_C2W);
    const V3 fx = qrot(q, v3(1, 0, 0)), up = qrot(q, v3(0, 0, 1));
    snprintf(out, n, "%.4f %.4f %.4f %.4f %.4f %.4f", fx.x, fx.y, fx.z, up.x, up.y, up.z);
    return finite3(fx) && finite3(up);
}
int nDeckAxes(const Lua& lua) {
    char b[160] = "";
    bool ok = false;
    __try { ok = DeckAxesWorld(b, sizeof(b)); } __except (GrabFilter(GetExceptionCode())) { ok = false; }
    lua.set_string(ok ? b : "");
    return 1;
}
int nDeckWorld(const Lua& lua) {
    char b[160] = "";
    bool ok = false;
    __try { ok = DeckWorld(b, sizeof(b)); } __except (GrabFilter(GetExceptionCode())) { ok = false; }
    lua.set_string(ok ? b : "");
    return 1;
}

// HJN_BoardMount(switch 0/1, flipFlag 0/1) -> 1 if the writes were made (Lua then calls SetPendingApplyToggleOnBoard)
int BoardMount(int sw, int flip) {
    uint8_t* sk = (uint8_t*)g_skater;
    if (!sk) return 0;
    uint8_t* bd = *(uint8_t**)(sk + SK_BOARD);
    uint8_t* mc = *(uint8_t**)(sk + SK_MC);
    uint8_t* bm = bd ? *(uint8_t**)(bd + BD_MOVE) : nullptr;
    if (!bd || !mc || !bm) return 0;
    if (mc[MC_ONBOARD] || sk[SK_THROWDOWN] || sk[SK_PICKUP] || sk[SK_PENDTOGGLE]) return 0;
    sk[SK_PENDFOOT] = sw ? 4 : 1;
    bm[BM_FLIPFLAG] = flip ? 1 : 0;
    bd[BD_FLAGS] = (uint8_t)(bd[BD_FLAGS] & ~1);
    Log("board hop: mounting where the board lies (foot position %d, flip flag %d, board flags now %02x)", sw ? 4 : 1, flip ? 1 : 0, bd[BD_FLAGS]);
    return 1;
}
int nBoardMount(const Lua& lua) {
    double s = 0, f = 0;
    ArgNum(lua, s); ArgNum(lua, f);
    int r = 0;
    __try { r = BoardMount(s != 0 ? 1 : 0, f != 0 ? 1 : 0); } __except (GrabFilter(GetExceptionCode())) { r = 0; }
    lua.set_integer(r);
    return 1;
}
// HJN_BoardRagdoll(): put the ragdoll bit back (an aborted mount)
int nBoardRagdoll(const Lua& lua) {
    int r = 0;
    __try {
        uint8_t* sk = (uint8_t*)g_skater;
        uint8_t* bd = sk ? *(uint8_t**)(sk + SK_BOARD) : nullptr;
        if (bd) { bd[BD_FLAGS] = (uint8_t)(bd[BD_FLAGS] | 1); r = 1; }
    } __except (GrabFilter(GetExceptionCode())) { r = 0; }
    lua.set_integer(r);
    return 1;
}

// HJN_ReverseSwap() -> 1 done, 0 refused (HJN_ReverseSwapWhy() says why)
int nReverseSwap(const Lua& lua) {
    double ay = 0; const bool have = ArgNum(lua, ay);          // (v63) HJN_ReverseSwap(actorYaw): the capsule's yaw, for the gate
    const int r = SafeReverseSwap((float)ay, have);
    if (!r) Log("reversed-deck swap refused: %s", g_swapWhy);
    lua.set_integer(r);
    return 1;
}
int nReverseSwapWhy(const Lua& lua) { lua.set_string(g_swapWhy); return 1; }
bool PtrOk(const void* p, size_t need);                     // (defined further down)
// (v61) HJN_CtrlYaw() -> "ctrlYaw deckOffset reverting": the board controller's yaw in the rider's frame (deg, 0 or 180 when all is
// well), the deck's yaw offset as the game holds it, whether a revert runs; "" without a board
int nCtrlYaw(const Lua& lua) {
    char b[64] = "";
    double ay = 0; const bool have = ArgNum(lua, ay);          // (v63) given the capsule's yaw, the first number is relative to it
    __try {
        const uint8_t* sk = (const uint8_t*)g_skater;
        const uint8_t* board = sk ? *(const uint8_t* const*)(sk + SK_BOARD) : nullptr;
        const uint8_t* bm = board ? *(const uint8_t* const*)(board + BD_MOVE) : nullptr;
        if (bm && PtrOk(bm, 0x800)) snprintf(b, sizeof(b), "%.1f %.0f %d", Wrap180(QYaw(bm + BM_CTRL, 0) - (have ? (float)ay : 0.0f)), *(const float*)(bm + BM_DECK_YAW), (int)bm[BM_REVERTING]);
    } __except (GrabFilter(GetExceptionCode())) { b[0] = 0; }
    lua.set_string(b);
    return 1;
}

// HJN_InstantRevert() -> the yaw (deg) to teleport the board's bodies by; 0 = no revert to finish
int nInstantRevert(const Lua& lua) {
    const float yaw = SafeInstantRevert();
    Log("instant revert: %s", yaw != 0.0f ? "the target turned the whole way, the rest left to the game" : "nothing running");
    lua.set_number((double)yaw);
    return 1;
}

// HJN_Guard(poses): run the lower-body / crossed-legs guard for the next poses (a 180 landing)
int nGuard(const Lua& lua) {
    double f = 0;
    ArgNum(lua, f);
    g_guardFrames = (int)clampf((float)f, 0.0f, 600.0f);
    lua.set_integer(g_guardFrames);
    return 1;
}

// HJN_Air(): a hop frame -- remember the feet (call every frame of the hop)
int nAir(const Lua& lua) {
    double f = -1, p = 0, r = 0, fl = 0, r01 = 0; ArgNum(lua, f); ArgNum(lua, p); ArgNum(lua, r); ArgNum(lua, fl); ArgNum(lua, r01);   // (v86) + a half turn (0/1), the reach as 0..1
    double pf = 0, pb = 0.92, pl = 0; ArgNum(lua, pf); ArgNum(lua, pb); ArgNum(lua, pl);   // (v94) + where the planned landing begins (0 = off: v93's reach), the leg at touchdown, the lift now (cm)
    if (g_airFrames <= 0) { g_pullRelOk[0] = g_pullRelOk[1] = false; g_reachHave = false; }   // (v84) a new hop
    if (g_airFrames <= 0) { g_planNew = true; g_planO = 0; g_sink = 0.0f; g_planAimOk = false; g_planCw = 0.0f; g_planW = 0.0f; g_hopTurnLeft = 0.0f; g_landNote = 0; if (g_holdLag >= 0 && g_holdFrames > 15) g_holdFrames = 15; }   // (v94; review: the last landing's give-back runs out by itself, its hold fades over 15 poses)
    g_planFrom = (float)pf; g_planBend = (float)pb; g_planLua = (float)pl;
    g_hopFrac = (float)f; g_hopPull = (float)p; g_hopReach = (float)r; g_hopFlip = (((int)fl) & 1) ? 1 : 0; g_planGuess = ((int)fl) >= 2;   /* (v94) + 2 = not decided yet (still the trigger's turn, or heading for no landing): no feet carried to spots */ g_hopReach01 = (float)r01; g_airFrames = 3; lua.set_integer(1); return 1;
}   // (v81) + how far through the air
// HJN_Land(poses): touchdown -- blend the feet onto the game's over the next poses
int nLand(const Lua& lua) {
    double f = 0, fd = 0;
    ArgNum(lua, f); ArgNum(lua, fd);
    if (fd > 0.0) g_sinkFade = clampf((float)fd, 0.05f, 1.0f);   // (review) HJN_Land(poses, the let-down's give-back in s)
    g_landFrames = g_landTotal = (int)clampf((float)f, 0.0f, 120.0f);
    g_sinkOn = g_sinkArm = (f > 0 && g_planFrom > 0.01f && g_sink > 0.05f); g_landNote = (f > 0) ? 40 : 0; if (!g_sinkOn) g_sinkTd = g_sinkNow = 0.0f;   // (v94) the hips' let-down is given back from here; 40 'land' lines
    g_stretchFrames = 45; g_hopFrac = -1.0f;                 // (v81) the landing's poses are watched for a stretched leg
    g_hopPull = 0.0f; g_hopPullLast[0] = g_hopPullLast[1] = 0.0f; g_hopReach = 0.0f; g_reachLast[0] = g_reachLast[1] = 0.0f; g_hopReach01 = 0.0f; g_reachSide[0] = g_reachSide[1] = 0.0f;
    g_airFrames = 0;
    lua.set_integer(g_airHave ? 1 : 0);
    return 1;
}

// HJN_Hold(poses): hold the body's world heading for the next poses (from the first one's)
int nHold(const Lua& lua) {
    double f = 0, lag = -1;
    double om = 0;
    ArgNum(lua, f); ArgNum(lua, lag); ArgNum(lua, om);       // (v94) + for how many poses the mesh's lag is taken out: the sprung hold (no second number = the v5 hold); (review) + the springs' omega
    if (om > 0.0) g_holdOmega = (float)om;
    g_holdLag = (int)clampf((float)lag, -1.0f, 120.0f);
    g_holdHave = false;
    g_holdFrames = g_holdTotal = (int)clampf((float)f, 0.0f, 600.0f);
    lua.set_integer(g_holdFrames);
    return 1;
}

// (v96) HJN_PushCap(skaterAddress, scale): the skater's own max-push-speed multiplier = the game's x scale (the note at
// THE BOARD'S SOUNDS AND THE SPEED SETTING). -> "1 <the game's own> <now> <the config's MaxPushingSpeed>" it was that
// already, "2 ..." written, "0 wait ..." no live skater of ours yet (ask again), "0 <why>" refused for good
const void* SkaterWorld();
int PushCap(uintptr_t skAddr, float scale, char* out, size_t n) {
    uint8_t* sk = (uint8_t*)(void*)g_skater;
    if (!g_hooked) { snprintf(out, n, "0 not this game build"); return 0; }
    if (!sk || (uintptr_t)sk != skAddr || !PtrOk(sk, SKA_ADV + 0x74) || !SkaterWorld()) { snprintf(out, n, "0 wait: no live skater of ours"); return 0; }
    const float* adv = (const float*)(sk + SKA_ADV);
    for (int i = 0; i < 3; i++)
        if (!std::isfinite(adv[i]) || adv[i] < 0.01f || adv[i] > 100.0f) { snprintf(out, n, "0 the skater's advanced settings do not read as multipliers (%g %g %g)", adv[0], adv[1], adv[2]); return 0; }
    float* f = (float*)(sk + SKA_ADV + 8);
    const float cur = *f;
    if (sk != g_capSk || cur != g_capNow) { g_capSk = sk; g_capBase = cur; }      // not what was written last: the game's own (a new skater, or its settings applied)
    const float want = g_capBase * clampf(std::isfinite(scale) ? scale : 1.0f, 0.1f, 10.0f);
    const int r = (want != cur) ? 2 : 1;
    if (r == 2) *f = want;
    g_capNow = want;
    float mx = 0.0f;
    const uint8_t* mc = *(const uint8_t* const*)(sk + SKA_MC);
    const uint8_t* cfg = (mc && PtrOk(mc, MCA_CONFIG + 8)) ? *(const uint8_t* const*)(mc + MCA_CONFIG) : nullptr;
    if (cfg && PtrOk(cfg, 0x50)) mx = *(const float*)(cfg + CFGA_MAXPUSH);
    snprintf(out, n, "%d %.3f %.3f %.0f", r, g_capBase, want, mx);
    return r;
}
int SafePushCap(uintptr_t sk, float scale, char* out, size_t n) {
    __try { return PushCap(sk, scale, out, n); }
    __except (GrabFilter(GetExceptionCode())) { snprintf(out, n, "0 fault"); Log("fault in the push cap"); return 0; }
}
int nPushCap(const Lua& lua) {
    double a = 0, s = 1;
    ArgNum(lua, a); ArgNum(lua, s);
    char out[200] = "0";
    const int r = SafePushCap((a > 65536.0 && a < 1.8e19) ? (uintptr_t)a : 0, (float)s, out, sizeof(out));
    if (r == 2) Log("push cap: the skater's max-push-speed multiplier written (the game's own x SpeedScale %.2f): %s (the config's MaxPushingSpeed, which the board's sounds divide the speed by, last)", s, out);
    lua.set_string(out);
    return 1;
}

// ==== (v101) THE UPDATER ================================================================================================
// HJN_Update(mode, build): mode 1 = look and tell, 2 = look, download, check and put in place for the next start. One
// worker thread, once a run. The release is read from the repository's "latest release" download links (no API, no
// JSON): update.txt first -- "key=value" lines: version, build, game_stamp, lua_sha256, dll_sha256 -- then main.lua and
// main.dll, each checked against its SHA-256 before anything on disk is touched. update.txt itself must carry the
// author's signature (update.txt.sig, the note at kUpdKey). HTTPS only, certificates checked by
// WinHTTP, the host fixed here. The dll that is loaded is renamed away (Windows lets a loaded image be renamed) and the
// new one moved in; main.lua is replaced (the Lua is read at start). Both halves or neither; what was there is kept as
// main.dll.prev / main.lua.prev. Nothing takes effect before the game is started again.
// HJN_UpdateStatus() -> "<state> <text>": 0 not asked, 1 looking, 2 nothing to do, 3 a newer one exists (not installed),
// 4 installed (restart), 5 could not (why).
constexpr wchar_t kUpdHost[] = L"github.com";
constexpr wchar_t kUpdPath[] = L"/Portman2/SessionExpandedTricks/releases/latest/download/";
volatile LONG g_updState = 0, g_updStarted = 0; char g_updText[320] = ""; SRWLOCK g_updLock = SRWLOCK_INIT;   // (review) no initialising call: the flag was set before the critical section was made
int g_updMode = 0, g_updBuild = 0;
void UpdSay(int state, const char* fmt, ...) {
    char b[320]; va_list ap; va_start(ap, fmt); vsnprintf(b, sizeof(b), fmt, ap); va_end(ap);
    AcquireSRWLockExclusive(&g_updLock);
    snprintf(g_updText, sizeof(g_updText), "%s", b);
    ReleaseSRWLockExclusive(&g_updLock);
    InterlockedExchange(&g_updState, state);
    Log("update: %s", b);
}
// GET https://github.com/<repository>/releases/latest/download/<name> (redirects followed, never down to http) -> the HTTP
// status; 0 = no connection, -1 = the read failed, -2 = bigger than `cap`
int UpdGet(const wchar_t* name, std::vector<uint8_t>& out, size_t cap) {
    out.clear();
    int status = 0;
    HINTERNET s = WinHttpOpen(L"ExpandedTricks-updater/1", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!s) s = WinHttpOpen(L"ExpandedTricks-updater/1", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!s) return 0;
    WinHttpSetTimeouts(s, 8000, 8000, 8000, 20000);
    HINTERNET c = WinHttpConnect(s, kUpdHost, INTERNET_DEFAULT_HTTPS_PORT, 0);
    const std::wstring path = std::wstring(kUpdPath) + name;
    HINTERNET r = c ? WinHttpOpenRequest(c, L"GET", path.c_str(), nullptr, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE) : nullptr;
    if (r) {
        DWORD pol = WINHTTP_OPTION_REDIRECT_POLICY_DISALLOW_HTTPS_TO_HTTP;
        WinHttpSetOption(r, WINHTTP_OPTION_REDIRECT_POLICY, &pol, sizeof(pol));
        if (WinHttpSendRequest(r, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) && WinHttpReceiveResponse(r, nullptr)) {
            DWORD code = 0, sz = sizeof(code);
            if (WinHttpQueryHeaders(r, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, WINHTTP_HEADER_NAME_BY_INDEX, &code, &sz, WINHTTP_NO_HEADER_INDEX)) status = (int)code;
            if (status == 200) {
                for (;;) {
                    DWORD avail = 0;
                    if (!WinHttpQueryDataAvailable(r, &avail)) { status = -1; break; }
                    if (avail == 0) break;
                    if (out.size() + (size_t)avail > cap) { status = -2; break; }
                    const size_t at = out.size();
                    out.resize(at + avail);
                    DWORD got = 0;
                    if (!WinHttpReadData(r, out.data() + at, avail, &got)) { status = -1; break; }
                    out.resize(at + got);
                    if (got == 0) break;
                }
            }
        }
    }
    if (r) WinHttpCloseHandle(r);
    if (c) WinHttpCloseHandle(c);
    WinHttpCloseHandle(s);
    if (status != 200) out.clear();
    return status;
}
// (v101) THE RELEASE IS SIGNED. The checksums in update.txt only say a download is whole; they come from the same place
// as the files, so by themselves they would let whoever controls the repository's releases put code into every game.
// update.txt.sig is the ECDSA P-256 signature (r || s, 64 bytes, 128 hex digits) of update.txt's exact bytes, made by
// source/tools/make-release.ps1 with the author's private key, which is not on GitHub. Its public half is here; an
// update.txt this key did not sign is not read at all. (The files are covered through their checksums in it.)
const uint8_t kUpdKey[72] = {
    0x45, 0x43, 0x53, 0x31, 0x20, 0x00, 0x00, 0x00, 0xb8, 0x22, 0xee, 0x8a,
    0xe1, 0xcf, 0x21, 0xe3, 0xf8, 0x80, 0xf0, 0x68, 0xf4, 0x29, 0xa7, 0xf1,
    0x1e, 0x63, 0xda, 0x58, 0x69, 0x64, 0xb2, 0x3e, 0x10, 0xe4, 0xb6, 0x82,
    0x36, 0x26, 0x42, 0xb6, 0x58, 0xe7, 0x2f, 0xd6, 0x39, 0x69, 0x8a, 0x6f,
    0xec, 0xf6, 0x20, 0x8a, 0x7d, 0x7e, 0x56, 0xe3, 0xb8, 0xeb, 0x74, 0xed,
    0xc3, 0xf1, 0x5e, 0x23, 0x41, 0xd0, 0x6d, 0x50, 0x39, 0xf4, 0xfc, 0xcf,
};
bool Sha256Raw(const uint8_t* p, size_t n, uint8_t d[32]) {
    BCRYPT_ALG_HANDLE a = nullptr; BCRYPT_HASH_HANDLE h = nullptr; bool ok = false;
    if (n > 0x7fffffffu) return false;
    if (BCryptOpenAlgorithmProvider(&a, BCRYPT_SHA256_ALGORITHM, nullptr, 0) == 0) {
        if (BCryptCreateHash(a, &h, nullptr, 0, nullptr, 0, 0) == 0) {
            ok = BCryptHashData(h, (PUCHAR)p, (ULONG)n, 0) == 0 && BCryptFinishHash(h, d, 32, 0) == 0;
            BCryptDestroyHash(h);
        }
        BCryptCloseAlgorithmProvider(a, 0);
    }
    return ok;
}
// is `sigText` (128 hex digits, white space around them allowed) the author's signature of these bytes?
bool UpdSigned(const uint8_t* msg, size_t n, const std::vector<uint8_t>& sigText) {
    uint8_t sig[64]; int nib = 0;
    for (uint8_t ch : sigText) {
        int v;
        if (ch >= '0' && ch <= '9') v = ch - '0';
        else if (ch >= 'a' && ch <= 'f') v = ch - 'a' + 10;
        else if (ch >= 'A' && ch <= 'F') v = ch - 'A' + 10;
        else if (ch == ' ' || ch == '\r' || ch == '\n' || ch == '\t') continue;
        else return false;
        if (nib >= 128) return false;
        if (nib & 1) sig[nib >> 1] = (uint8_t)(sig[nib >> 1] | v); else sig[nib >> 1] = (uint8_t)(v << 4);
        nib++;
    }
    if (nib != 128) return false;
    uint8_t hash[32];
    if (!Sha256Raw(msg, n, hash)) return false;
    BCRYPT_ALG_HANDLE a = nullptr; BCRYPT_KEY_HANDLE k = nullptr; bool ok = false;
    if (BCryptOpenAlgorithmProvider(&a, BCRYPT_ECDSA_P256_ALGORITHM, nullptr, 0) == 0) {
        if (BCryptImportKeyPair(a, nullptr, BCRYPT_ECCPUBLIC_BLOB, &k, (PUCHAR)kUpdKey, (ULONG)sizeof(kUpdKey), 0) == 0) {
            ok = BCryptVerifySignature(k, nullptr, hash, 32, sig, 64, 0) == 0;
            BCryptDestroyKey(k);
        }
        BCryptCloseAlgorithmProvider(a, 0);
    }
    return ok;
}
bool Sha256Hex(const uint8_t* p, size_t n, char out[65]) {
    BCRYPT_ALG_HANDLE a = nullptr; BCRYPT_HASH_HANDLE h = nullptr; uint8_t d[32]; bool ok = false;
    if (n > 0x7fffffffu) return false;
    if (BCryptOpenAlgorithmProvider(&a, BCRYPT_SHA256_ALGORITHM, nullptr, 0) == 0) {
        if (BCryptCreateHash(a, &h, nullptr, 0, nullptr, 0, 0) == 0) {
            ok = BCryptHashData(h, (PUCHAR)p, (ULONG)n, 0) == 0 && BCryptFinishHash(h, d, 32, 0) == 0;
            BCryptDestroyHash(h);
        }
        BCryptCloseAlgorithmProvider(a, 0);
    }
    if (ok) for (int i = 0; i < 32; i++) snprintf(out + i * 2, 3, "%02x", d[i]);
    return ok;
}
// "key=value" on a line of its own -> the value, trimmed, lower case where `lower`; "" = not there
std::string UpdKey(const std::string& t, const char* key, bool lower) {
    const std::string k = std::string(key) + "=";
    size_t pos = 0;
    while (pos < t.size()) {
        size_t e = t.find('\n', pos);
        if (e == std::string::npos) e = t.size();
        std::string line = t.substr(pos, e - pos);
        while (!line.empty() && (line.back() == '\r' || line.back() == ' ' || line.back() == '\t')) line.pop_back();
        size_t b = 0;
        while (b < line.size() && (line[b] == ' ' || line[b] == '\t' || (unsigned char)line[b] == 0xEF || (unsigned char)line[b] == 0xBB || (unsigned char)line[b] == 0xBF)) b++;   // (a UTF-8 mark at the file's start)
        if (line.compare(b, k.size(), k) == 0) {
            std::string v = line.substr(b + k.size());
            while (!v.empty() && (v.front() == ' ' || v.front() == '\t')) v.erase(v.begin());
            if (lower) for (char& ch : v) if (ch >= 'A' && ch <= 'Z') ch = (char)(ch - 'A' + 'a');
            return v;
        }
        pos = e + 1;
    }
    return "";
}
bool UpdWrite(const std::wstring& path, const std::vector<uint8_t>& d) {
    HANDLE f = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE) return false;
    DWORD w = 0;
    const bool ok = WriteFile(f, d.data(), (DWORD)d.size(), &w, nullptr) && w == (DWORD)d.size() && FlushFileBuffers(f);
    const DWORD e = ok ? 0 : GetLastError();
    CloseHandle(f);
    if (!ok) { DeleteFileW(path.c_str()); SetLastError(e); }
    return ok;
}
// this dll's own path, and the Lua half's main.lua beside it (...\Mods\ExpandedTricksNative\dlls\main.dll ->
// ...\Mods\ExpandedTricks\Scripts\main.lua)
bool UpdPaths(std::wstring& dll, std::wstring& lua) {
    HMODULE me = nullptr; wchar_t p[1024];
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCWSTR)&UpdWrite, &me)) return false;
    const DWORD n = GetModuleFileNameW(me, p, 1024);
    if (n == 0 || n >= 1024) return false;
    dll = p;
    std::wstring d = dll;
    for (int up = 0; up < 3; up++) {                             // main.dll -> dlls -> ExpandedTricksNative -> Mods
        const size_t a = d.find_last_of(L"\\/");
        if (a == std::wstring::npos) return false;
        d.resize(a);
    }
    lua = d + L"\\ExpandedTricks\\Scripts\\main.lua";
    return GetFileAttributesW(lua.c_str()) != INVALID_FILE_ATTRIBUTES;
}
uint32_t UpdExeStamp() {
    const uint8_t* b = (const uint8_t*)GetModuleHandleW(nullptr);
    if (!b) return 0;
    const IMAGE_DOS_HEADER* dos = (const IMAGE_DOS_HEADER*)b;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return 0;
    const IMAGE_NT_HEADERS* nt = (const IMAGE_NT_HEADERS*)(b + dos->e_lfanew);
    return nt->Signature == IMAGE_NT_SIGNATURE ? nt->FileHeader.TimeDateStamp : 0;
}
void UpdRun() {
    std::vector<uint8_t> buf;
    const int st = UpdGet(L"update.txt", buf, 16384);
    if (st == 404) { UpdSay(2, "no release is published yet (nothing at the mod's GitHub page to compare with)"); return; }
    if (st != 200) {
        if (st == 0) UpdSay(5, "GitHub could not be reached -- not checked this time");
        else UpdSay(5, "the release's update.txt answered %d -- not checked this time", st);
        return;
    }
    {
        std::vector<uint8_t> sig;
        const int ss = UpdGet(L"update.txt.sig", sig, 4096);
        if (ss != 200) {
            if (ss == 404) UpdSay(5, "the latest release has no update.txt.sig: it is not signed by the mod's author -- ignored");
            else UpdSay(5, "the release's update.txt.sig answered %d -- not checked this time", ss);
            return;
        }
        if (!UpdSigned(buf.data(), buf.size(), sig)) { UpdSay(5, "the latest release's update.txt is NOT signed with the mod author's key -- ignored, nothing installed"); return; }
    }
    const std::string t((const char*)buf.data(), buf.size());
    std::string ver = UpdKey(t, "version", false);
    const int build = atoi(UpdKey(t, "build", false).c_str());
    bool verOk = !ver.empty() && ver.size() <= 24;
    for (char ch : ver) if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '.' || ch == '-')) verOk = false;
    if (!verOk || build <= 0) { UpdSay(5, "the release's update.txt could not be read -- not checked this time"); return; }
    if (build <= g_updBuild) { UpdSay(2, "up to date (this is build %d; the latest release is %s, build %d)", g_updBuild, ver.c_str(), build); return; }
    const std::string stamp = UpdKey(t, "game_stamp", true);
    const uint32_t mine = UpdExeStamp();
    bool stampOk = stamp.empty() || stamp.size() == 8;           // (review) it goes into both logs: eight hex digits, as make-release.ps1 writes it, or nothing
    for (char ch : stamp) if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))) stampOk = false;
    if (!stampOk) { UpdSay(5, "the release's update.txt could not be read (its game_stamp) -- not checked this time"); return; }
    if (!stamp.empty() && (uint32_t)strtoul(stamp.c_str(), nullptr, 16) != mine) {
        UpdSay(3, "version %s is out, but it is made for another build of the game (%s; this game is %08x) -- not installed", ver.c_str(), stamp.c_str(), mine);
        return;
    }
    if (g_updMode < 2) { UpdSay(3, "version %s is out (this is build %d, that is build %d). AutoUpdate=2 installs new versions by itself", ver.c_str(), g_updBuild, build); return; }
    const std::string hl = UpdKey(t, "lua_sha256", true), hd = UpdKey(t, "dll_sha256", true);
    if (hl.size() != 64 || hd.size() != 64) { UpdSay(5, "version %s: its update.txt has no checksums -- nothing installed", ver.c_str()); return; }
    std::vector<uint8_t> lua, dll;
    const int a = UpdGet(L"main.lua", lua, 8u << 20);
    const int b = (a == 200) ? UpdGet(L"main.dll", dll, 32u << 20) : 0;
    if (a != 200 || b != 200) { UpdSay(5, "version %s: the files could not be downloaded (main.lua answered %d, main.dll %d) -- nothing installed", ver.c_str(), a, b); return; }
    char h1[65] = "", h2[65] = "";
    if (!Sha256Hex(lua.data(), lua.size(), h1) || !Sha256Hex(dll.data(), dll.size(), h2) || hl != h1 || hd != h2 || lua.size() < 1000 || dll.size() < 4096 || dll[0] != 'M' || dll[1] != 'Z') {
        UpdSay(5, "version %s: a downloaded file does not match its checksum -- nothing installed", ver.c_str());
        return;
    }
    std::wstring dllPath, luaPath;
    if (!UpdPaths(dllPath, luaPath)) { UpdSay(5, "version %s: the mod's own folders were not found where they should be -- nothing installed", ver.c_str()); return; }
    const std::wstring dllNew = dllPath + L".new", luaNew = luaPath + L".new", dllPrev = dllPath + L".prev", luaPrev = luaPath + L".prev";
    // (review) a read-only or hidden left-over, or a read-only main.lua, made the steps below fail with error 5 at every start
    const std::wstring* const clr[] = { &dllNew, &luaNew, &dllPrev, &luaPrev, &luaPath };
    for (const std::wstring* p : clr) {
        const DWORD at = GetFileAttributesW(p->c_str());
        if (at != INVALID_FILE_ATTRIBUTES && (at & (FILE_ATTRIBUTE_READONLY | FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM))) SetFileAttributesW(p->c_str(), FILE_ATTRIBUTE_NORMAL);
    }
    if (!UpdWrite(dllNew, dll) || !UpdWrite(luaNew, lua)) {
        const DWORD e = GetLastError();
        DeleteFileW(dllNew.c_str()); DeleteFileW(luaNew.c_str());
        UpdSay(5, "version %s: the game's folder cannot be written to (error %lu) -- nothing installed; install it by hand from the mod's GitHub page", ver.c_str(), e);
        return;
    }
    // (review) can main.lua be replaced at all? Asked BEFORE the dll is touched (another program holding it open without
    // sharing a delete was only found once the dll had been swapped)
    {
        HANDLE probe = CreateFileW(luaPath.c_str(), DELETE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, 0, nullptr);
        if (probe == INVALID_HANDLE_VALUE) {
            const DWORD e = GetLastError();
            DeleteFileW(dllNew.c_str()); DeleteFileW(luaNew.c_str());
            UpdSay(5, "version %s: main.lua is open in another program (error %lu) -- nothing installed", ver.c_str(), e);
            return;
        }
        CloseHandle(probe);
    }
    // the dll: the loaded one away, the new one in -- or back as it was
    if (!MoveFileExW(dllPath.c_str(), dllPrev.c_str(), MOVEFILE_REPLACE_EXISTING)) {
        const DWORD e = GetLastError();
        DeleteFileW(dllNew.c_str()); DeleteFileW(luaNew.c_str());
        UpdSay(5, "version %s: the loaded main.dll could not be moved aside (error %lu) -- nothing installed", ver.c_str(), e);
        return;
    }
    if (!MoveFileExW(dllNew.c_str(), dllPath.c_str(), 0)) {
        const DWORD e = GetLastError();
        const bool back = MoveFileExW(dllPrev.c_str(), dllPath.c_str(), MOVEFILE_REPLACE_EXISTING) != 0;
        const DWORD e2 = back ? 0 : GetLastError();
        DeleteFileW(dllNew.c_str()); DeleteFileW(luaNew.c_str());
        if (back) UpdSay(5, "version %s: the new main.dll could not be put in place (error %lu) -- the old one is back, nothing installed", ver.c_str(), e);
        else UpdSay(5, "version %s: the new main.dll could not be put in place (error %lu) and the old one could not be put back (error %lu) -- in Mods/ExpandedTricksNative/dlls rename main.dll.prev to main.dll before the next start", ver.c_str(), e, e2);
        return;
    }
    // the Lua: a copy of the old one kept, the new one in -- or the dll back as well
    const bool kept = CopyFileW(luaPath.c_str(), luaPrev.c_str(), FALSE) != 0;
    if (!MoveFileExW(luaNew.c_str(), luaPath.c_str(), MOVEFILE_REPLACE_EXISTING)) {
        const DWORD e = GetLastError();
        const bool back = MoveFileExW(dllPrev.c_str(), dllPath.c_str(), MOVEFILE_REPLACE_EXISTING) != 0;   // (over the new one: it need not be moved away first)
        const DWORD e2 = back ? 0 : GetLastError();
        DeleteFileW(dllNew.c_str()); DeleteFileW(luaNew.c_str());
        if (back) UpdSay(5, "version %s: main.lua could not be replaced (error %lu) -- both halves are back as they were, nothing installed", ver.c_str(), e);
        else UpdSay(5, "version %s: main.lua could not be replaced (error %lu) and the old main.dll could not be put back (error %lu) -- the NEW main.dll is beside the OLD main.lua; tried again at the next start", ver.c_str(), e, e2);
        return;
    }
    if (kept) UpdSay(4, "version %s is installed -- restart the game to use it (what was there is kept as main.lua.prev and main.dll.prev)", ver.c_str());
    else UpdSay(4, "version %s is installed -- restart the game to use it (the old main.dll is kept as main.dll.prev; the old main.lua could not be copied to main.lua.prev)", ver.c_str());
}
DWORD WINAPI UpdProc(LPVOID) {
    try { UpdRun(); }
    catch (...) { UpdSay(5, "the updater stopped on an error -- nothing installed"); }
    return 0;
}
int nUpdate(const Lua& lua) {
    double mode = 0, build = 0;
    ArgNum(lua, mode); ArgNum(lua, build);
    if (mode < 1 || build < 1 || InterlockedExchange(&g_updStarted, 1) != 0) { lua.set_integer(0); return 1; }
    g_updMode = (int)mode; g_updBuild = (int)build;
    InterlockedExchange(&g_updState, 1);
    HANDLE h = CreateThread(nullptr, 0, UpdProc, nullptr, 0, nullptr);
    if (h) CloseHandle(h); else UpdSay(5, "the updater's thread could not be started");
    lua.set_integer(h ? 1 : 0);
    return 1;
}
int nUpdateStatus(const Lua& lua) {
    char out[360];
    AcquireSRWLockShared(&g_updLock);
    snprintf(out, sizeof(out), "%ld %s", (long)g_updState, g_updText);
    ReleaseSRWLockShared(&g_updLock);
    lua.set_string(out);
    return 1;
}

// HJN_MuteRevert(assetAddress, cueAddress, on): USkateboardAudioDataAsset::_revertSoundCue (+0x350, the cue
// ASkateboardEx::PlayRevertSound plays -- it skips a null one) cleared (on=1) or put back (on=0). Written only
// if the field holds what Lua says it does (the cue, or null to put it back). -> 1 if written
int MuteWrite(uintptr_t asset, uintptr_t cue, bool on) {
    __try {
        uintptr_t* f = (uintptr_t*)(asset + 0x350);
        if (on && *f == cue) { *f = 0; return 1; }
        if (!on && *f == 0) { *f = cue; return 1; }
        return 0;
    } __except (GrabFilter(GetExceptionCode())) { return 0; }
}
int nMuteRevert(const Lua& lua) {
    double a = 0, c = 0, on = 0;
    ArgNum(lua, a); ArgNum(lua, c); ArgNum(lua, on);
    const int r = (a != 0 && c != 0) ? MuteWrite((uintptr_t)a, (uintptr_t)c, on != 0) : 0;
    lua.set_integer(r);
    return 1;
}

// HJN_Readable(address) -> 1 if the 64 bytes there are committed, readable memory. Lua keeps UObject pointers (the
// skater, its mesh, the anim instance) and asks IsValid before using them -- but IsValid READS the object's index
// first, and a level change can hand the dead skater's page back to the OS before the 2 s watch runs: the v82
// apartment crash was an access violation at the old skater + 0xC from inside UE4SS's Lua. A stale pointer whose
// page is still mapped just fails IsValid as before.
int nReadable(const Lua& lua) {
    double a = 0;
    ArgNum(lua, a);
    int ok = 0;
    const uintptr_t p = (a > 65536.0 && a < 1.8e19) ? (uintptr_t)a : 0;
    if (p) {
        MEMORY_BASIC_INFORMATION mbi;
        if (VirtualQuery((LPCVOID)p, &mbi, sizeof(mbi)) == sizeof(mbi)) {
            const uintptr_t end = (uintptr_t)mbi.BaseAddress + mbi.RegionSize;
            const bool readable = mbi.State == MEM_COMMIT && mbi.Protect != 0 && (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD)) == 0;
            ok = (readable && p + 0x40 <= end) ? 1 : 0;
        }
    }
    lua.set_integer(ok);
    return 1;
}

// HJN_HandOffset(kind, along, across, up) -> 1: your hand offset for that grab (cm; see g_hoff)
int nHandOffset(const Lua& lua) {
    double k = 0, a = 0, c = 0, u = 0;
    ArgNum(lua, k); ArgNum(lua, a); ArgNum(lua, c); ArgNum(lua, u);
    const int hs = HoffSlot((int)k);
    if (hs < 0 || !std::isfinite(a) || !std::isfinite(c) || !std::isfinite(u)) { lua.set_integer(0); return 1; }
    g_gp[hs][GP_ALONG] = clampf((float)a, -40.0f, 40.0f); g_gp[hs][GP_ACROSS] = clampf((float)c, -40.0f, 40.0f); g_gp[hs][GP_UP] = clampf((float)u, -40.0f, 40.0f);
    lua.set_integer(1);
    return 1;
}

// HJN_HandVia(kind, along, across, up) -> 1: the via point of that grab's hand path (cm; see HandPath)
int nHandVia(const Lua& lua) {
    double k = 0, a = 0, c = 0, u = 0;
    ArgNum(lua, k); ArgNum(lua, a); ArgNum(lua, c); ArgNum(lua, u);
    const int hs = HoffSlot((int)k);
    if (hs < 0 || !std::isfinite(a) || !std::isfinite(c) || !std::isfinite(u)) { lua.set_integer(0); return 1; }
    g_gp[hs][GP_VIAA] = clampf((float)a, -60.0f, 60.0f); g_gp[hs][GP_VIAC] = clampf((float)c, -60.0f, 60.0f); g_gp[hs][GP_VIAU] = clampf((float)u, -60.0f, 60.0f);
    lua.set_integer(1);
    return 1;
}
// HJN_GrabSet(kind, what, value) -> 1: one of a grab's own numbers (what = 0 along, 1 across, 2 up, 3-5 the via
// point, 6 tilt, 7 lift, 8 drop, 9 splay front, 10 splay back, 11 roll front, 12 roll back, 13 back, 14 slide)
int nGrabSet(const Lua& lua) {
    double k = 0, w = 0, v = 0;
    ArgNum(lua, k); ArgNum(lua, w); ArgNum(lua, v);
    const int hs = GrabSlot((int)k), what = (int)w;
    if (hs < 0 || what < 0 || what >= GP_N || !std::isfinite(v)) { lua.set_integer(0); return 1; }
    g_gp[hs][what] = clampf((float)v, -90.0f, 90.0f);
    lua.set_integer(1);
    return 1;
}
// (v41) HJN_GrabSetSw(kind, what, value) -> 1: that number's SWITCH add-on (in force while riding switch; 0 = as regular)
int nGrabSetSw(const Lua& lua) {
    double k = 0, w = 0, v = 0;
    ArgNum(lua, k); ArgNum(lua, w); ArgNum(lua, v);
    const int hs = GrabSlot((int)k), what = (int)w;
    if (hs < 0 || what < 0 || what >= GP_N || !std::isfinite(v)) { lua.set_integer(0); return 1; }
    g_gpSw[hs][what] = clampf((float)v, -90.0f, 90.0f);
    lua.set_integer(1);
    return 1;
}
// HJN_Collisions() -> the last finished grab's limb audit ("#n grab k ...": n counts up with every report)
int nCollisions(const Lua& lua) { lua.set_string(g_colReport); return 1; }

// HJN_SetPC(address) -> 1: our player controller (0 = none) -- for the late-trick block and the bumpers
int nSetPC(const Lua& lua) {
    double a = 0;
    ArgNum(lua, a);
    void* pc = (a > 65536.0 && a < 1.8e19) ? (void*)(uintptr_t)a : nullptr;
    if (pc) {
        MEMORY_BASIC_INFORMATION mbi;
        const bool ok = VirtualQuery(pc, &mbi, sizeof(mbi)) == sizeof(mbi) && mbi.State == MEM_COMMIT && mbi.Protect != 0
                     && (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD)) == 0
                     && (uintptr_t)pc + 0x7a0 <= (uintptr_t)mbi.BaseAddress + mbi.RegionSize;
        if (!ok) pc = nullptr;
    }
    if (pc != g_pc) Log("our player controller: %p", pc);
    g_pc = pc;
    lua.set_integer(pc ? 1 : 0);
    return 1;
}
// HJN_Bumpers() -> 0..3: 1 = LB held, 2 = RB held, as the game sees them
int nBumpers(const Lua& lua) { lua.set_integer(g_pc ? SafeBumpers() : 0); return 1; }

// ------------------------------------------------------------------ (v36) THE DROP-IN: ledges, and the board held on one
// HOW THE GAME KNOWS A LEDGE: it does not have any marked. UGrindDetectorComponent (on the board) sweeps a shape at
// the world's collision as you come down, then sweeps again from either side of what it hit and compares the two
// surfaces' normals: two faces meeting at more than _edgeMinimumAngle = an edge to grind (rails are UGrindSplineComponent
// splines). Any hard corner in the level's collision is a ledge. So this finds one the same way, with rays: the ground
// under the skater, then outwards in 24 directions for where that ground drops away; the nearest such edge, the way
// its drop faces, how far down the ground is past it, and at what angle a board pivoting on the edge would meet it.
// Engine functions by address (this exe build only; the pose hook's build check guards them).
constexpr uintptr_t RVA_ACTOR_GETWORLD   = 0x29c3690;   // AActor::GetWorld
constexpr uintptr_t RVA_LINETRACE_OBJ    = 0x2aead10;   // UWorld::LineTraceSingleByObjectType
constexpr uintptr_t RVA_DEFAULT_QUERY    = 0x4f855a0;   // FCollisionQueryParams::DefaultQueryParam
constexpr uintptr_t RVA_QP_CTOR          = 0x2ab3cc0;   // (v51) FCollisionQueryParams::FCollisionQueryParams(FName, const TStatId&, bool bTraceComplex, const AActor* ignore)
constexpr uintptr_t RVA_QP_ADD_ACTOR     = 0x2ab60e0;   // (v51) FCollisionQueryParams::AddIgnoredActor(const AActor*)  (the struct is 0x70 bytes: bools at 0x10.., IgnoreComponents 0x20, IgnoreActors 0x50)
constexpr uintptr_t RVA_SET_WORLD_LOCROT = 0x2b669f0;   // USceneComponent::SetWorldLocationAndRotation(FVector, const FQuat&, bool, FHitResult*, ETeleportType)
constexpr uintptr_t RVA_SET_LINVEL       = 0x2ed85f0;   // UPrimitiveComponent::SetPhysicsLinearVelocity(FVector, bool, FName)
constexpr uintptr_t RVA_SET_ANGVEL       = 0x2ed85a0;   // UPrimitiveComponent::SetPhysicsAngularVelocityInRadians(FVector, bool, FName)
constexpr int ACTOR_ROOT = 0x130;                       // AActor::RootComponent
typedef void* (*GetWorldFn)(const void* actor);
typedef bool  (*TraceFn)(const void* world, void* outHit, const V3* start, const V3* end, const void* objParams, const void* queryParams);
typedef void  (*SetXfFn)(void* comp, const V3* loc, const Q4* rot, bool sweep, void* hit, uint8_t teleport);
typedef void  (*SetVelFn)(void* comp, const V3* vel, bool add, uint64_t boneName);
struct RayHit { bool hit; V3 p, n; };
LONG g_rays = 0;
volatile int32_t g_rayMask = 1;                      // (v42) the object types a ray hits: 1 = WorldStatic; a custom map may need more (see LedgeScan)
int32_t g_selfIdx[2] = { -1, -1 };                   // (v49) the skater's and the board's object indices (UObject::InternalIndex): a ray that
LONG g_selfHits = 0;                                 //       hits one of them looks on past it (a wide mask on a dropped object sees them)
volatile int g_rayComplex = 0;                       // (v51) 1 = rays hit the complex (per-triangle) collision; the dropped quarter pipe has no other
typedef void (*QPCtorFn)(void* self, uint64_t traceTag, const void* statId, bool traceComplex, const void* ignoreActor);
typedef void (*QPAddActorFn)(void* self, const void* actor);
void* BoardActorNow();
bool PtrOk(const void* p, size_t need);
// (v95) the world a ray may be cast in: this pose's (the hook has checked its mesh: the note at PoseWorld) or, for what
// the Lua calls, the skater's own -- if neither the skater, its mesh nor that world is on its way out
const void* SkaterWorld() {
    if (g_inPose) return g_poseWorld;
    const uint8_t* sk = (const uint8_t*)(void*)g_skater;
    if (!sk || !PtrOk(sk, 0x60)) return nullptr;
    if ((sk[ACTOR_DESTROYING] & 0x10) || (*(const uint32_t*)(sk + 8) & RF_DESTROYING)) return nullptr;
    const uint8_t* m = (const uint8_t*)(void*)g_mesh;
    if (m && PtrOk(m, 0xb0) && !(m[AC_REGISTERED] & 1)) return nullptr;
    const uint8_t* w = (const uint8_t*)((GetWorldFn)((uint8_t*)GetModuleHandleW(nullptr) + RVA_ACTOR_GETWORLD))(sk);
    if (!w || !PtrOk(w, 0x110) || (w[WORLD_TEARING] & 0x20) || (*(const uint32_t*)(w + 8) & RF_DESTROYING)) return nullptr;
    return w;
}
bool Ray(const void* world, V3 a, V3 b, RayHit& h) {
    alignas(16) uint8_t buf[0x100];
    struct { int32_t types; uint8_t ignore; uint8_t pad[3]; } obj = { g_rayMask /* WorldStatic: the level, not the skater or the board (or wider on a custom map) */, 0, { 0, 0, 0 } };
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    // (v51) the engine's own query params, built by its constructor: our skater and board IGNORED (a wide object mask saw
    // our own skater first, v49), and complex collision when asked for (the dropped quarter pipe's deck is WorldStatic to
    // the game yet no simple-collision ray of ours ever found it). The struct is 0x70 bytes; nothing in it is heap-allocated
    // for two ignored actors (inline room for 4), so it needs no destructor
    alignas(16) uint8_t qp[0x90]; memset(qp, 0, sizeof(qp));
    uint64_t statId = 0;
    const void* sk = PtrOk(g_skater, 0x10) ? g_skater : nullptr;
    void* bd = BoardActorNow(); if (bd && !PtrOk(bd, 0x10)) bd = nullptr;
    ((QPCtorFn)(exe + RVA_QP_CTOR))(qp, 0ull, &statId, g_rayComplex != 0, sk);
    if (bd) ((QPAddActorFn)(exe + RVA_QP_ADD_ACTOR))(qp, bd);
    const V3 full = sub(b, a); const float fl = len(full);
    V3 from = a; float step = 2.0f;
    for (int tries = 0; tries < 9; tries++) {         // (v50) steps 2 .. 512 cm: out of our own skater from its middle
        memset(buf, 0, sizeof(buf));
        InterlockedIncrement(&g_rays);
        h.hit = ((TraceFn)(exe + RVA_LINETRACE_OBJ))(world, buf, &from, &b, &obj, qp);
        h.p = *(const V3*)(buf + 0x18);                 // FHitResult::ImpactPoint
        h.n = *(const V3*)(buf + 0x30);                 // FHitResult::ImpactNormal
        if (h.hit && (!finite3(h.p) || !finite3(h.n))) h.hit = false;
        if (!h.hit) return false;
        const int32_t ai = *(const int32_t*)(buf + 0x68);   // FHitResult::Actor, a weak pointer: the actor's object index comes first
        if (ai < 0 || (ai != g_selfIdx[0] && ai != g_selfIdx[1])) return true;
        InterlockedIncrement(&g_selfHits);              // (v49) our own skater or board: look on from just past the hit
        if (fl < 1e-3f) return false;
        from = add(h.p, mul(full, step / fl)); step *= 2.0f;
        if (dot(sub(b, from), full) <= 0.0f) return false;
    }
    return false;
}
// (v94) THE POSE RECORDER'S ONE RAY: the ground straight under the mesh's origin, in the world (as TrickTraceLine's, but
// 10 m down: a pose high over a gap still has its ground), and that ground's normal -- the viewer carries the plane out to
// the feet with it.
bool PdGround(const void* mesh, float* z, V3* nrm) {
    const V3 mp = *(const V3*)((const uint8_t*)mesh + SC_C2W + 0x10);
    if (!g_skater || !finite3(mp)) return false;
    const void* world = SkaterWorld();               // (v95) this pose's own world, or none
    if (!world) return false;
    RayHit h;
    if (!Ray(world, add(mp, v3(0.0f, 0.0f, 60.0f)), add(mp, v3(0.0f, 0.0f, -1000.0f)), h)) return false;
    *z = h.p.z; *nrm = h.n;
    return true;
}
bool PtrOk(const void* p, size_t need) {
    if (!p) return false;
    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(p, &mbi, sizeof(mbi)) != sizeof(mbi)) return false;
    if (mbi.State != MEM_COMMIT || mbi.Protect == 0 || (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD)) != 0) return false;
    return (uintptr_t)p + need <= (uintptr_t)mbi.BaseAddress + mbi.RegionSize;
}
// (v91-v93) ...a foot at the ground was also turned off the tip of its toe HERE, by a heading read from the foot itself.
// (v94) GONE. That foot was the game's plant foot, and why it stood on its toe is known now (the note at g_plPhase: the
// game turns it by the difference between the clip's board and the real one). The turn's heading came from the level part
// of a foot standing 68-76 deg toe-down -- a tenth of its length, any way round: the ankle twisted 58-68 deg against the
// knee while the foot stood and 141 -> 172 -> 50 deg through the lift (the "tf" lines of 20:33:51 / 20:34:01), and turning
// "about the toe" carried the ankle 10-14 cm out from where the plant had put it. The plant foot is planned whole now
// (PlantSoft / PlantFlat); this is the plain lift again -- an ankle under g_footAnkle, or a toe under g_footToe, straight
// up -- which a planned foot never needs on level ground (and which, as the heel peels up at the lift-off, keeps the toe
// on the ground: the foot comes up about its toe by itself).
volatile float g_footHeel = 15.0f;                   // HJN_Set("footheel"): deg a STANDING plant foot's heel is up (v94: PlantStand); 80+ = the game's own turn
bool GroundFeet(const void* mesh) {
    const uint8_t* m = (const uint8_t*)mesh;
    const Q4 mq = *(const Q4*)(m + SC_C2W); const V3 mp = *(const V3*)(m + SC_C2W + 0x10); const V3 ms = *(const V3*)(m + SC_C2W + 0x20);
    if (!g_skater || !finite3(mp) || fabsf(ms.x) < 1e-3f || fabsf(ms.y) < 1e-3f || fabsf(ms.z) < 1e-3f) return false;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    const void* world = SkaterWorld();
    if (!world) return false;
    bool changed = false;
    for (int k = 0; k < 2; k++) {
        const int ft = g_foot[k];
        if (ft < 0) continue;
        const V3 c = g_Ct[ft].p;
        const V3 w = add(mp, qrot(mq, v3(c.x * ms.x, c.y * ms.y, c.z * ms.z)));
        RayHit h;
        if (!Ray(world, add(w, v3(0.0f, 0.0f, 45.0f)), add(w, v3(0.0f, 0.0f, -70.0f)), h)) continue;   // no ground within reach of this foot
        float need = h.p.z + g_footAnkle - w.z;
        if (g_toe[k] >= 0) {
            const V3 tc = g_Ct[g_toe[k]].p;
            const V3 tw = add(mp, qrot(mq, v3(tc.x * ms.x, tc.y * ms.y, tc.z * ms.z)));
            need = fmaxf(need, h.p.z + g_footToe - tw.z);
        }
        if (!(need > 0.3f)) continue;
        need = fminf(need, 60.0f);
        const V3 d = qinv(mq, v3(0.0f, 0.0f, need));                    // straight up in the world, in the mesh's own space
        Leg(k, add(c, v3(d.x / ms.x, d.y / ms.y, d.z / ms.z)), g_Ct[ft].q);
        InterlockedIncrement(&g_footLifts);
        if (need > g_footLiftMax) g_footLiftMax = need;
        changed = true;
    }
    return changed;
}
// HJN_Bone(seconds, side 0 = the mesh's left hand / 1 = its right) -> "<frames posed so far> <hand to its spot, cm> <weight>"
// (seconds 0 = let go now; the hand eases back by itself)
int nBone(const Lua& lua) {
    double s = 0, side = -1, kind = 102, crouch = 0; ArgNum(lua, s); ArgNum(lua, side); ArgNum(lua, kind); ArgNum(lua, crouch);
    if (s > 0 && (side == 0 || side == 1)) {
        g_boneSide = (int)side; g_boneKind = (GrabSlot((int)kind) >= 0) ? (int)kind : 102;      // (v69) which grab's spot, how deep the crouch may go (cm)
        g_boneDropMax = clampf((float)crouch, 0.0f, 80.0f);
        g_boneUntil = GetTickCount64() + (ULONGLONG)(s * 1000.0);
    }
    else if (s <= 0) g_boneUntil = 0;
    char out[64]; snprintf(out, sizeof(out), "%ld %.1f %.2f %.0f %.0f", g_boneFrames, g_boneGap, g_boneW, g_boneDrop, g_boneLean);   // (v69) + the crouch found, cm
    lua.set_string(out);
    return 1;
}
// HJN_FootGround() -> "<frames a foot was lifted, so far> <the most it was lifted since the last call, cm>"
int nFootGround(const Lua& lua) {
    char out[48]; snprintf(out, sizeof(out), "%ld %.1f", g_footLifts, g_footLiftMax);
    g_footLiftMax = 0.0f;
    lua.set_string(out);
    return 1;
}
// ==== (v78) THE SOFT PLANT, (v94) PLANNED ==============================================================================
// v78: "If I turn the setting off everything becomes fluid and there are no distortions -- but the foot ends up too high off
// the ground. Embrace that somehow, but keep it planted." The WHOLE BODY is let down, one rigid move, so the plant leg
// reaches the ground (at most g_plantMax, and never into the back leg: v89's g_plantRoom); the back foot comes down with
// it and is lifted back onto the deck where that takes it under its riding height. At the board's top the body is let up
// again over 1.5 x g_plantStepS, quickly at first. v94: the plant LEG itself is the plan's (the note at g_plPhase) -- its
// place, its turn, its knee -- from the pose it first comes down on until it is back with the game's own foot.
// HJN_Set("plantmode", 2) = v77's pinned plant (the switch trick's), which stands its foot the same way (PlantFlat).
volatile int g_plantMode = 1;
// (v97) THE SOFT PLANT IN THE OTHER STANCE. "The switch bean plant and boneless work, but it's almost like they're holding
// old code. They don't really mirror what the regular side does." They did run older code: a switch plant is ridden in the
// other stance with the game's foot pull off (its targets are that stance's), and since v163 it took the PINNED plant for
// that -- both feet stood on their riding spots, the plant foot put on the ground and back -- while the regular side got
// the soft plant of v94-v96 (the leg planned whole: the step off, the stand at its own angle with the toes in, the stuck
// foot, the heel up under low hips, the way back heel first, the body let down by what the leg needs). The soft plant
// could not simply be used there: it leaves from, measures against and comes back to "the game's own foot", and with the
// pull off that is the clip's foot on the CLIP's board -- 26-44 cm over the real one 0.2 s in (the trick traces of 5 Oct
// 08:58), and on the far side of the deck for the sixteen poses of the game's cross-fade through the swap.
// While a stance swap is on (g_swapOn) the soft plant's "game's own foot" is the foot's riding spot on the drawn deck,
// for both feet: the plan steps off from it and measures its place on the ground against it (so the side and the end of
// the board are the foot's own from the first pose), comes back to it, and then STANDS on it for as long as the window
// runs (stage 3; six poses back to the game's foot once the swap or the window is over); the back foot stands on its own
// spot all through. Everything between is the regular side's code, line for line.
float g_plOwnW = 0.0f; LONG g_plOwnLogs = 0;
// (v99) THE PLANT FOOT SWIVELS, AND COMES BACK IN ITS ANKLE. "The foot is planted to the ground, fixed to the ground.
// Technically we only need the place fixed. Rotation is probably fine: if I do a 180 no comply it twists his foot around,
// but if that foot was free to rotate around the Z axis, that should just swivel versus stretching."
// It was fixed twice over. (1) While it steps off and stands, its turn in the world was the one it was given when it was
// named: in the 180 no comply of 5 Oct 12:07:21 the hips' line turns 47 deg over the 13 poses it stands, the foot not at
// all -- the whole leg wrung between a trunk that turns and a foot that does not. Now the standing foot's heading turns
// with the hips' line (all of it by default: NoComplySwivel; a step of the hips' line of more than 34 deg in one pose is
// a stance swap's mirrored pose, not a turn, and is not followed), about the BALL of the foot: the toe joint keeps its
// place on the ground and the heel swings round it, as a foot does that is stood on while the body turns.
// (2) On the way back the foot's turn was blended IN THE WORLD from where it stood to the game's own foot -- the clip's
// lifted foot, 65-77 deg toe-down, whose heading swings 140 deg in three poses -- while the leg under it was the plan's:
// the same recording has the ankle 52 and 74 deg twisted about its shin on the last two poses of the way back of that
// trick, 128 and 153 deg in two others, 74-128 in seven of the ten regular no complies. Now the foot is turned IN ITS
// ANKLE: the leg is solved with the foot as it stood (heel peeling up), and then the foot's turn against its own shin
// goes from that to the game's foot against the game's shin. When the plan's leg meets the game's the foot is the
// game's, and at no pose between is the ankle further round than one of those two. It needs the knee's hinge (a shin
// whose roll means something: the note at g_hingeTh). HJN_Set("plswivel", 0..1) / ("plankle", 0) = v98's.
volatile float g_plSwivel = 1.0f; volatile int g_plAnkle = 1;
float g_plSwPrev = 0.0f, g_plSwAcc = 0.0f, g_plSwNow = 0.0f, g_plSwStick = 0.0f, g_plSwMost = 0.0f; bool g_plSwHave = false; LONG g_plSwLogs = 0;
// (v80) THE PLANT FOOT, NAMED (HJN_Set("plantfoot", 0 left / 1 right / -1 the first one down)). The switch no comply, ridden
// in the other stance: its first frames are still your own stance's animation, whose OTHER foot dips first -- the traces
// of 22:32-22:33 have that foot (2-6 cm over the ground at 47 ms) taken for the plant foot and pinned down, the leading
// foot pinned to the board: the wrong one planted. And with a hand on the board (22:34:03) neither foot came within
// 14 cm of the ground: no plant at all, and with the game's foot IK off nothing held the feet ("very blendery").
volatile float g_plantRoom = 0.42f;                        // (v89) the least the back leg keeps hip to ankle through a soft plant, as a share of its length
volatile int g_plantForce = -1; float g_plantIn = 1.0f;   // (g_plantIn: a named foot steps off the board over five poses, it is not snapped down)
// (v94) HOW A PLANT FOOT STANDS: flat on its sole (the ankle joint g_footAnkle up, the toe joint g_footToe) with the heel
// g_footHeel deg up -- 41 deg toe-down by the joints with the settings as shipped, what v91-v93 turned it to and what the
// clip itself has on the ground (34-43) -- and its ankle that high over the ground.
float PlantStand() {
    const float Lf = (g_plLf > 3.0f) ? g_plLf : 17.2f;
    return asinf(clampf((g_footAnkle - g_footToe) / Lf, 0.0f, 0.9f)) + clampf(g_footHeel, 0.0f, 45.0f) * 0.0174532925f;
}
float PlantAnkle() { return fmaxf(g_footAnkle, g_footToe + ((g_plLf > 3.0f) ? g_plLf : 17.2f) * sinf(PlantStand())); }
// ...and its turn, in the world, taken once a plant (g_plFlatW; false = not to be had: the foot keeps the pose's turn). The
// foot as it RIDES -- the learned stance's turn of it on a deck lying level the way this one lies: its own roll, sole down
// -- turned about the world's up so the toes point along the board toward the foot's own end (fw), toeIn deg in toward
// the side they ride on (the clip: 16-18 deg; keep = the riding heading itself, for the pinned plant), then tipped to
// PlantStand. With no stance learned yet: the pose's own foot, swung the shortest way to that direction.
bool PlantFlat(int k, Q4 mq, V3 ms, float fw, bool keep) {
    if (g_plFlatOk) return true;
    const int ft = g_foot[k], to = g_toe[k];
    if (ft < 0 || to < 0 || !g_deckOk || g_footHeel >= 80.0f) return false;
    const V3 tl = g_Lt[to].p;                             // the toe joint in the foot's own frame
    if (len(tl) < 3.0f) return false;
    g_plLf = len(tl) * fabsf(ms.z);
    const V3 up = v3(0.0f, 0.0f, 1.0f);
    const Q4 dW = qnorm(qmul(mq, g_dq));                  // the drawn deck, in the world
    V3 lx = qrot(dW, v3(1.0f, 0.0f, 0.0f)), lt = qrot(dW, v3(0.0f, 1.0f, 0.0f));
    lx.z = 0.0f; lt.z = 0.0f;
    if (len(lx) < 0.5f || len(lt) < 0.5f) return false;
    lx = norm(lx); lt = norm(lt);
    const float stand = PlantStand(), toeIn = clampf(g_plToeIn, 0.0f, 90.0f) * 0.0174532925f;
    g_plRides = g_stCur >= 0 && g_dFootOk[k];
    Q4 q = g_plRides ? qnorm(qmul(qmul(qfromto(qrot(dW, up), up), dW), g_uFootQ[k])) : qnorm(qmul(mq, g_Ct[ft].q));
    const V3 t = qrot(q, norm(tl));                       // where its toes point then
    V3 hr = v3(t.x, t.y, 0.0f);
    const bool level = len(hr) > 0.2f;                    // (a foot on its tip has no heading worth the name: v93's lesson)
    if (level) hr = norm(hr);
    const float side = level ? ((dot(hr, lt) >= 0.0f) ? 1.0f : -1.0f) : 0.0f;
    const V3 hd = (keep && level) ? hr : norm(add(mul(lx, fw * cosf(toeIn)), mul(lt, side * sinf(toeIn))));
    if (g_plRides && level) {
        const float turn = atan2f(hr.x * hd.y - hr.y * hd.x, hr.x * hd.x + hr.y * hd.y);
        q = qnorm(qmul(q4(0.0f, 0.0f, sinf(turn * 0.5f), cosf(turn * 0.5f)), q));
        const float rides = asinf(clampf(-t.z, -1.0f, 1.0f));                       // how far toe-down it rides
        q = qnorm(qmul(qaxis(cross(up, hd), (stand - rides) * 57.2957795f), q));    // about the foot's own cross axis: + = toe down
    } else {
        q = qnorm(qmul(qfromto(t, add(mul(hd, cosf(stand)), v3(0.0f, 0.0f, -sinf(stand)))), q));
    }
    g_plFlatW = q; g_plHeadW = hd; g_plFlatOk = true;
    return true;
}
bool PlantSoft(const void* mesh) {
    const bool on = g_plantUntil != 0 && GetTickCount64() < g_plantUntil;
    if (!on) {
        g_plantUntil = 0;
        if (g_plantFoot < 0) { PlantOver(false); return false; }   // nothing was planted; a foot that is off the board goes back to it below
    }
    if (g_pelvis < 0 || !g_skater) return false;
    const uint8_t* m = (const uint8_t*)mesh;
    const Q4 mq = *(const Q4*)(m + SC_C2W); const V3 mp = *(const V3*)(m + SC_C2W + 0x10); const V3 ms = *(const V3*)(m + SC_C2W + 0x20);
    if (!finite3(mp) || fabsf(ms.x) < 1e-3f || fabsf(ms.y) < 1e-3f || fabsf(ms.z) < 1e-3f) return false;
    auto toWorld = [&](V3 p) { return add(mp, qrot(mq, v3(p.x * ms.x, p.y * ms.y, p.z * ms.z))); };
    auto toComp = [&](V3 w) { const V3 e = qinv(mq, sub(w, mp)); return v3(e.x / ms.x, e.y / ms.y, e.z / ms.z); };
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    const void* world = SkaterWorld();
    if (!world) return false;
    const double now = NowS();
    auto hipsYaw = [&]() {                                // (review) which way the body faces, in the world: the mesh's turn and the pose's own, both
        if (g_thigh[0] < 0 || g_thigh[1] < 0) return 0.0f;
        const V3 a = qrot(mq, sub(g_C[g_thigh[0]].p, g_C[g_thigh[1]].p));
        return (a.x * a.x + a.y * a.y > 1.0f) ? atan2f(a.y, a.x) : 0.0f;
    };
    if (g_plantFoot < 0) {                                // the first foot the game puts on the ground
        if (g_plantDone) return false;
        int best = -1; float bh = 1e9f;
        for (int k = 0; k < 2; k++) {
            if (g_foot[k] < 0) continue;
            const V3 w = toWorld(g_C[g_foot[k]].p);
            RayHit h;
            if (!Ray(world, add(w, v3(0.0f, 0.0f, 45.0f)), add(w, v3(0.0f, 0.0f, -70.0f)), h)) continue;
            const float hgt = w.z - h.p.z;
            if (hgt < g_footAnkle + 4.0f && hgt < bh) { bh = hgt; best = k; }
        }
        { const int pf = g_plantForce; if ((pf == 0 || pf == 1) && g_foot[pf] >= 0) best = pf; }   // (v80) named by the Lua: no waiting for it to come down
        if (best < 0) return false;
        g_plantFoot = best; g_plantW = 1.0f; g_plantD = g_plantD0 = 0.0f; g_plantRel = false; g_plantMost = 0.0f;
        g_plantDeck0 = g_plantDeckMax = -1e9f;
        g_plantStage = 1; g_plantU = 0.0f; g_plantVz = 0.0f; g_plantVzMax = 0.0f; g_plantHaveT = false; g_plantStepMs = -1.0f; g_plantT0 = now;
        g_plantHaveOff = false; g_plantAxOk = false; g_plantSoftW = 0.0f; g_plantCut = 0.0f;   // (v89)
        g_plPhase = 1; g_plHave0 = false; g_plFlatOk = false; g_plHaveLast = false; g_plT0 = g_plPrevT = now;   // (v94)
        g_plStickOk = false; g_plRelStick = false; g_plStandT0 = now;                                           // (v95)
        g_plOwnW = 0.0f;                                                                                        // (v97)
        g_plSwHave = false; g_plSwAcc = g_plSwNow = g_plSwStick = g_plSwMost = 0.0f; g_plSwOn = 0;              // (v99)
        g_plSlide = 0.0f; g_plExtLo = 9.0f; g_plExtHi = 0.0f; g_plApart = 0.0f; g_plTurn = 0.0f; g_plDownMs = -1.0f; g_hipGapMost = 0.0f;
    }
    const int k = g_plantFoot, o = 1 - k;
    if (g_foot[k] < 0 || g_foot[o] < 0 || g_thigh[k] < 0 || g_calf[k] < 0) { PlantOver(on); return false; }
    if (now - g_plPrevT > 0.3) {
        if (InterlockedIncrement(&g_plLogs) <= 300) Log("plant (v94): DROPPED -- no pose of it for %.0f ms (a hitch, a pause, a grab): the foot is the game's own from here", (now - g_plPrevT) * 1000.0);
        PlantOver(on); return false;
    }   // the plan was not run for a while (a grab had the pose): dropped, not picked up half way
    g_deckOk = g_boardOk && DeckXf(mesh);
    if (g_deckOk && g_stCur >= 0) UseStance(g_stCur);
    const float sz = fabsf(ms.z);
    // (v97) the other stance: each foot's home is its riding spot on the drawn deck (the note at g_plOwnW)
    const bool spots = g_deckOk && g_stCur >= 0 && g_dFootOk[k] && g_dFootOk[o];
    const bool own = spots && g_swapOn != 0 && !(g_sockOn != 0 && g_sockBad == 0 && now - g_sockSeenT < 0.25);   // (v99: not while the game's foot sockets are turned with the body for this swap -- its own feet are right then, the note at SockTurn)
    V3 rideC[2]; Q4 rideQ[2];
    for (int f = 0; f < 2; f++) {
        rideC[f] = spots ? add(g_dp, qrot(g_dq, g_uFootP[f])) : g_C[g_foot[f]].p;
        rideQ[f] = spots ? qnorm(qmul(g_dq, g_uFootQ[f])) : g_Ct[g_foot[f]].q;
    }
    const V3 wa = toWorld(own ? rideC[k] : g_C[g_foot[k]].p);   // where the GAME has the plant foot (against the real board: the note at g_plPhase)
    // ---- once: its place on the ground (v89's rule: where it rides, within 15 cm of where the game brings it down, plantfwd
    // cm further toward its own end of the board, at least plantclear out from the centre line on its own side;
    // plantfwd under -90 = under where the game first has it) -- a fixed offset from the skater in the world's axes
    if (!g_plantHaveOff) {
        V3 place = v3(wa.x - mp.x, wa.y - mp.y, 0.0f);
        g_plFw = 1.0f;
        V3 lx = v3(1.0f, 0.0f, 0.0f), lt = v3(0.0f, 1.0f, 0.0f);
        if (g_deckOk) { lx = qrot(mq, qrot(g_dq, v3(1.0f, 0.0f, 0.0f))); lt = qrot(mq, qrot(g_dq, v3(0.0f, 1.0f, 0.0f))); }
        lx.z = 0.0f; lt.z = 0.0f;
        if (g_deckOk && len(lx) > 0.5f && len(lt) > 0.5f) {
            lx = norm(lx); lt = norm(lt);
            const V3 dw = toWorld(g_dp), wo = toWorld(own ? rideC[o] : g_C[g_foot[o]].p);
            const float a0 = (wa.x - dw.x) * lx.x + (wa.y - dw.y) * lx.y, c0 = (wa.x - dw.x) * lt.x + (wa.y - dw.y) * lt.y;   // along the board from its centre, across it
            const float ao = (wo.x - dw.x) * lx.x + (wo.y - dw.y) * lx.y;                                                  // the other foot, along
            // "forward" = away from the other foot (the plant foot's own end of the board), its side = the one it stepped off to:
            // both from the pose itself; the learned riding spots only where the pose does not say, and for the 15 cm
            // clamp only when they lie the way the feet stand now (a deck turned under the rider turns them)
            const bool st = g_stCur >= 0 && g_dFootOk[k] && g_dFootOk[o];
            const float da = a0 - ao, ds = st ? (g_uFootP[k].x - g_uFootP[o].x) * sz : 0.0f;
            const float fw = ((fabsf(da) >= 10.0f || !st) ? da : ds) >= 0.0f ? 1.0f : -1.0f;
            const bool ride = st && ds * fw > 8.0f;
            float side = (c0 >= 0.0f) ? 1.0f : -1.0f;
            if (fabsf(c0) < 6.0f && ride && fabsf(g_uFootP[k].y) > 3.0f) side = (g_uFootP[k].y >= 0.0f) ? 1.0f : -1.0f;
            float a = a0, c = c0;
            if (g_plantFwd > -90.0f) {
                const float want = clampf(g_plantClear, 0.0f, 40.0f);
                a = (ride ? clampf(a0, g_uFootP[k].x * sz - 15.0f, g_uFootP[k].x * sz + 15.0f) : a0) + fw * g_plantFwd;
                c = side * clampf(fabsf(c0), want, fmaxf(want, 32.0f));
            }
            place = v3(dw.x + lx.x * a + lt.x * c - mp.x, dw.y + lx.y * a + lt.y * c - mp.y, 0.0f);
            g_plFw = fw;
            g_plantOffW = place; g_plantHaveOff = true;
            const bool flat0 = PlantFlat(k, mq, ms, fw, false);
            float tip = -1.0f;                            // how far toe-down the game has the foot at this moment
            if (g_toe[k] >= 0) { const V3 tv = sub(toWorld(g_C[g_toe[k]].p), wa); if (len(tv) > 3.0f) tip = asinf(clampf(-tv.z / len(tv), -1.0f, 1.0f)) * 57.2957795f; }
            if (InterlockedIncrement(&g_plLogs) <= 300)
                Log("plant (v94): the %s foot steps off to the ground %+.0f cm along the board, %+.0f across, and stands there (the game's own foot is at %+.0f %+.0f now, %.0f deg toe-down; plantfwd %+.0f, toward the %s end) -- %s",
                    k ? "R" : "L", a, c, a0, c0, tip, (float)g_plantFwd, fw > 0.0f ? "+X" : "-X",
                    !flat0 ? "its turn is left as the pose has it (no toe bone / deck / footheel 80+)"
                    : g_plRides ? "turned as it rides, flat, the toes a little in from the board's line" : "no riding stance learned yet: the pose's own foot swung flat");
        }
        if (!g_plantHaveOff) { g_plantOffW = place; g_plantHaveOff = true; }
    }
    const bool flat = PlantFlat(k, mq, ms, g_plFw, false);
    float sw = 0.0f;                                      // (v99) the swivel: how far the hips' line has turned since the foot was named (rad), while it steps off and stands
    if (flat && g_plSwivel > 0.01f && g_plantStage == 1) {
        const float hy = hipsYaw();
        if (!g_plSwHave) { g_plSwPrev = hy; g_plSwHave = true; }
        float inc = hy - g_plSwPrev;
        while (inc > 3.14159265f) inc -= 6.2831853f;
        while (inc < -3.14159265f) inc += 6.2831853f;
        g_plSwPrev = hy;
        if (fabsf(inc) < 0.6f) g_plSwAcc += inc;          // (more than 34 deg in one pose: a mirrored pose of a stance swap, not a turn)
        const float want = clampf(g_plSwAcc * clampf(g_plSwivel, 0.0f, 1.0f), -2.6f, 2.6f);
        g_plSwNow += clampf(want - g_plSwNow, -0.3f, 0.3f) * 0.7f;
        sw = g_plSwNow;
        if (fabsf(sw) > g_plSwMost) g_plSwMost = fabsf(sw);
        g_plSwOn = fabsf(sw) > 0.02f ? 1 : 0;
    } else g_plSwOn = 0;
    const Q4 swQ = q4(0.0f, 0.0f, sinf(sw * 0.5f), cosf(sw * 0.5f));
    const V3 headS = flat ? qrot(swQ, g_plHeadW) : g_plHeadW;
    // ---- the ground under that place, and where the ankle stands on it
    V3 Aw = v3(mp.x + g_plantOffW.x, mp.y + g_plantOffW.y, wa.z);
    if (g_plStickOk && g_plPhase == 2) {                  // (v95) it stands where it came down, in the world
        Aw.x = g_plStickW.x; Aw.y = g_plStickW.y;
        if (flat && fabsf(sw - g_plSwStick) > 1e-4f) {    // (v99) ...its toe joint does: the heel swings round it as the hips turn
            const float lh = g_plLf * cosf(PlantStand());
            const V3 h0 = qrot(q4(0.0f, 0.0f, sinf(g_plSwStick * 0.5f), cosf(g_plSwStick * 0.5f)), g_plHeadW);
            Aw.x += (h0.x - headS.x) * lh; Aw.y += (h0.y - headS.y) * lh;
        }
    }
    {
        RayHit h;
        if (Ray(world, add(Aw, v3(0.0f, 0.0f, 60.0f)), add(Aw, v3(0.0f, 0.0f, -200.0f)), h)) { g_plantGz = h.p.z; g_plantHaveT = true; }
        else if (!g_plantHaveT) { PlantOver(on); return false; }
    }
    Aw.z = g_plantGz + (flat ? PlantAnkle() : g_footAnkle);
    float dh = 0.0f;                                      // the drawn deck over the ground, and how fast it rises
    if (g_deckOk) {
        dh = toWorld(g_dp).z - g_plantGz;
        if (g_plantDeck0 < -1e8f) { g_plantDeck0 = g_plantDeckMax = g_plantPrevZ = dh; g_plantPrevT = now; g_plantVz = 0.0f; }
        else {
            const float dt = (float)(now - g_plantPrevT);
            if (dt > 0.004f) {
                if (dt < 0.2f) g_plantVz += ((dh - g_plantPrevZ) / dt - g_plantVz) * 0.5f;
                if (g_plantVz > g_plantVzMax) g_plantVzMax = g_plantVz;
                g_plantPrevZ = dh; g_plantPrevT = now;
            }
        }
        if (dh > g_plantDeckMax) g_plantDeckMax = dh;
    }
    const float cap = fmaxf(g_plantMax, 0.0f);
    // (v89) NOT INTO THE BACK LEG. The body was let down by all the plant foot hangs over the ground (45 cm) whatever the
    // board did: in the boneless the deck is 74-85 cm up by then with the back foot on it -- hip to ankle 24 cm at 18:07:48
    // (with v88's 18 cm of raise), 19 -> 5 -> 17 at 18:17:40 (the hand let go: no raise at all), a leg of 84 cm folded
    // flat. room = the most the BODY may come down with that leg still g_plantRoom of its length, its ankle where it will
    // be drawn (lifted back onto the deck as below, or on the boneless's glue spot). (The clip itself folds that leg to
    // 37-43 % of its length on the board at the top: 0.42 is the animator's own number.)
    float room = cap;
    if (g_deckOk && g_thigh[o] >= 0) {
        const float zr = (g_stCur >= 0 && g_dFootOk[o]) ? g_uFootP[o].z : 15.0f;
        const float legLen = (g_legRefOk && g_legRef[o][0] > 1.0f) ? g_legRef[o][0] + g_legRef[o][1] : 84.0f;
        const float minExt = clampf(g_plantRoom, 0.25f, 0.8f) * legLen;
        const V3 H0 = g_Ct[g_thigh[o]].p, A0 = g_Ct[g_foot[o]].p;
        const float gw = (g_glueFoot == o && g_dFootOk[o]) ? clampf(g_glueW * g_boneW, 0.0f, 1.0f) : 0.0f;
        const V3 spot = add(g_dp, qrot(g_dq, g_uFootP[o]));
        auto ext = [&](float dd) {                            // that leg, hip to ankle, with the body dd cm down
            const V3 dn = v3(0.0f, 0.0f, dd / sz);
            V3 A = sub(A0, dn);
            V3 l = qinv(g_dq, sub(A, g_dp));
            if (fabsf(l.x) < HalfLen() + 6.0f && fabsf(l.y) < HalfWidth() + 8.0f && l.z < zr) { l.z = zr; A = add(g_dp, qrot(g_dq, l)); }
            if (gw > 0.0f) A = lerp(A, spot, gw);
            const V3 v = sub(sub(H0, dn), A);
            return (v.z > 0.0f) ? len(v) : 0.0f;
        };
        if (ext(cap) < minExt) {
            float lo = 0.0f, hi = cap;
            if (ext(0.0f) >= minExt) for (int i = 0; i < 10; i++) { const float md = 0.5f * (lo + hi); if (ext(md) >= minExt) lo = md; else hi = md; }
            room = lo;
        }
    }
    // ---- what the plant leg needs: how far the hips must come down for it to reach a point at 97 % of its own length
    const float L = ((g_legRefOk && g_legRef[k][0] > 1.0f && g_legRef[k][1] > 1.0f) ? g_legRef[k][0] + g_legRef[k][1]
                  : len(sub(g_Ct[g_calf[k]].p, g_Ct[g_thigh[k]].p)) + len(sub(g_Ct[g_foot[k]].p, g_Ct[g_calf[k]].p))) * sz;
    const float lim = L * 0.97f;
    const V3 Hw = toWorld(g_Ct[g_thigh[k]].p);            // the hip joint as the pose has it, before anything is let down
    auto needFor = [&](V3 F) {
        const float dx = fminf(sqrtf((Hw.x - F.x) * (Hw.x - F.x) + (Hw.y - F.y) * (Hw.y - F.y)), lim * 0.9f);
        return (Hw.z - F.z) - sqrtf(lim * lim - dx * dx);
    };
    const float limit = fminf(cap, room), need = needFor(Aw);
    const float dtp = clampf((float)(now - g_plPrevT), 0.004f, 0.05f); g_plPrevT = now;
    // ---- the foot on this pose: where (world), how turned, and the knee's way
    const Q4 standQ = flat ? qnorm(qmul(swQ, g_plFlatW)) : qnorm(qmul(mq, g_Ct[g_foot[k]].q));   // (v99: turned with the hips, the note at g_plSwivel)
    V3 Fw = Aw; Q4 Qw = standQ; V3 poleW = headS;
    bool ankOn = false; float ankT = 0.0f;                // (v99) the way back: the foot's turn is blended in its ankle, after the leg is solved
    if (g_plPhase == 1) {                                 // 1: it steps off, from where the game had it when it came down
        if (!g_plHave0) {
            const V3 f0 = toWorld(own ? rideC[k] : g_Ct[g_foot[k]].p);
            g_plP0 = v3(f0.x - mp.x, f0.y - mp.y, fmaxf(f0.z - g_plantGz, g_footAnkle));
            g_plQ0W = qnorm(qmul(mq, own ? rideQ[k] : g_Ct[g_foot[k]].q));
            const V3 kn = sub(g_Ct[g_calf[k]].p, lerp(g_Ct[g_thigh[k]].p, g_Ct[g_foot[k]].p, 0.5f));
            g_plPole0W = (len(kn) > 2.0f) ? norm(qrot(mq, kn)) : g_plHeadW;
            g_plHave0 = true; g_plT0 = now;
        }
        const float u = clampf((float)(now - g_plT0) / clampf(g_plStepIn, 0.02f, 0.4f), 0.0f, 1.0f), s = u * u * (3.0f - 2.0f * u);
        Fw = lerp(v3(mp.x + g_plP0.x, mp.y + g_plP0.y, g_plantGz + g_plP0.z), Aw, s);
        Fw.z += 3.0f * sinf(3.14159265f * u);             // it STEPS to its place: no slide in
        Qw = qslerpTo(g_plQ0W, standQ, s);
        poleW = norm(lerp(g_plPole0W, headS, s));
        if (u >= 1.0f) {
            g_plPhase = 2; g_plDownMs = (float)((now - g_plantT0) * 1000.0);
            g_plStandT0 = now;                            // (v95) it is down: from here it stands, and where it stands is kept
            if (g_plStick != 0) { g_plStickW = Aw; g_plStickOk = true; g_plSwStick = sw; }
        }
    }
    if (g_plantStage == 1) {                              // on its way down or standing: when does it leave?
        const bool risen = g_deckOk && (g_plantDeckMax - g_plantDeck0) > 8.0f;
        const char* why = nullptr;
        if (!on) why = "the window is over";
        else if (g_plPhase == 2 && g_plStandMax > 0.01f && now - g_plStandT0 >= (double)g_plStandMax) why = "it has stood its time (NoComplyPlantTime)";   // (v95)
        else if (g_plPhase == 2 && g_plStickOk && sqrtf((Hw.x - Aw.x) * (Hw.x - Aw.x) + (Hw.y - Aw.y) * (Hw.y - Aw.y)) > lim * 0.45f) why = "the body has rolled on too far from where it stands";   // (v95)
        else if (risen && g_plantVzMax >= fmaxf(150.0f, g_plantLead + 60.0f) && g_plantVz < g_plantLead) why = "the board is at its top";
        else if (risen && dh < g_plantDeckMax - 1.0f) why = "the board is on its way down";
        else if (need > limit + 1.5f) why = (room < cap) ? "the back leg has no room left under the hips and the plant leg is at full stretch" : "the body would have to come down too far";
        if (why) {
            g_plantStage = 2; g_plPhase = 3; g_plantStepT0 = now; g_plantD0 = g_plantD;
            g_plantStepMs = (float)((now - g_plantT0) * 1000.0);
            g_plP0 = v3(Fw.x - mp.x, Fw.y - mp.y, Fw.z - g_plantGz); g_plQ0W = Qw; g_plPole0W = poleW; g_plYaw0 = hipsYaw(); g_plStepOk = false;
            if (flat) { g_plHeadW = headS; g_plFlatW = standQ; }   // (v99) the way back begins from the heading it had swivelled to
            if (g_plSwMost > 0.09f && InterlockedIncrement(&g_plSwLogs) <= 60)
                Log("plant (v99): the foot swivelled %.0f deg with the hips while it stepped off and stood (about its toe joint; the hips' line turned %.0f)", g_plSwNow * 57.2957795f, g_plSwAcc * 57.2957795f);
            g_plSwOn = 0;
            g_plRelW = Fw; g_plRelStick = g_plStickOk;    // (v95) a foot that stuck goes back from where it stood in the world
            if (g_plLogs <= 300)
                Log("plant (v94): the foot leaves the ground %.0f ms after it came down (%s) -- the deck %.0f cm over the ground, rising %.0f cm/s (%.0f at its fastest); the body was %.0f cm down (the leg needed %.0f, the back leg left room for %.0f); it stood from %.0f ms, its ankle moved %.1f cm against the skater while it stood, the leg %.0f-%.0f %% of its length; the game had a hip joint up to %.0f cm out of its socket (put back)",
                    g_plantStepMs, why, dh, g_plantVz, g_plantVzMax, fminf(g_plantD, room), need, room, g_plDownMs, g_plSlide, g_plExtLo * 100.0f, g_plExtHi * 100.0f, g_hipGapMost);
        } else {
            const float want = clampf(need, 0.0f, limit);
            g_plantD += clampf(want - g_plantD, -350.0f * dtp, 500.0f * dtp);   // (the skater leaves the ground at 390 cm/s)
            if (g_plantD > g_plantMost) g_plantMost = g_plantD;
        }
    }
    float w = 0.0f;
    if (g_plantStage == 2) {                              // 3: back to the game's own foot; the body comes up, quickly at first
        g_plantU = clampf((float)(now - g_plantStepT0) / (clampf(g_plantStepS, g_plRelStick ? 0.08f : 0.03f, 0.5f) * 1.5f), 0.0f, 1.0f);   // (v95) from a place in the world the way back takes 0.12 s at least
        if (g_plantU >= 1.0f) {
            if (g_plLogs <= 300)
                Log("plant (v94): back with %s %.0f ms after leaving the ground; on the way the two were up to %.0f cm apart and %.0f deg apart in turn",
                    own ? "its riding spot on the deck (the other stance: it stands there while the trick runs)" : "the game's own foot",
                    (now - g_plantStepT0) * 1000.0, g_plApart, g_plTurn);
            if (!(own && on)) { PlantOver(on); return false; }
            g_plantStage = 3; g_plPhase = 4; g_plOwnW = 1.0f; g_plantD = 0.0f;   // (v97)
        }
        w = g_plantU * g_plantU * (3.0f - 2.0f * g_plantU);
        const float r = 1.0f - g_plantU;
        // ...but not faster than the leg, still near the ground, can follow
        const V3 Fe = lerp(g_plRelStick ? g_plRelW : v3(mp.x + g_plP0.x, mp.y + g_plP0.y, g_plantGz + g_plP0.z), v3(wa.x, wa.y, fmaxf(wa.z, g_plantGz + g_footAnkle)), w);
        g_plantD = clampf(fmaxf(g_plantD0 * r * r, needFor(Fe) * (1.0f - w)), 0.0f, fmaxf(g_plantD0, 0.0f));
    }
    const float d = fminf(g_plantD, room);                // (v89) the body's share of the way down: not into the back leg
    if (d > 0.05f) SetComp(g_pelvis, g_Ct[g_pelvis].q, sub(g_Ct[g_pelvis].p, v3(0.0f, 0.0f, d / sz)));   // the whole body, as one
    if (g_plantD > 0.2f && g_deckOk) {                    // the back foot: not under the deck
        V3 l = qinv(g_dq, sub(g_Ct[g_foot[o]].p, g_dp));  // in the deck's own frame
        const float zr = (g_stCur >= 0 && g_dFootOk[o]) ? g_uFootP[o].z : 15.0f;   // where its ankle rides over the deck
        if (fabsf(l.x) < HalfLen() + 6.0f && fabsf(l.y) < HalfWidth() + 8.0f && l.z < zr) {
            l.z = zr;
            Leg(o, add(g_dp, qrot(g_dq, l)), g_Ct[g_foot[o]].q);
        }
    }
    if (own && g_thigh[o] >= 0 && g_calf[o] >= 0) {       // (v97) the other stance: the back foot stands on its riding spot (the game's pull is off)
        // ...from where the feet hold has it as the plan begins (that hold is on its way out by then), all of it 0.07 s in
        const float wf = g_feetHoldW * g_feetHoldW * (3.0f - 2.0f * g_feetHoldW), wi = fmaxf(wf, Sm01((float)(now - g_plantT0) / 0.07f));
        Leg(o, lerp(g_Ct[g_foot[o]].p, rideC[o], wi), qslerpTo(g_Ct[g_foot[o]].q, rideQ[o], wi));
    }
    if (g_plantStage == 3) {                              // (v97) the other stance: back on the board, it stands on its riding spot while the window runs
        if (own && on) g_plOwnW = 1.0f; else g_plOwnW -= 1.0f / 6.0f;
        if (g_plOwnW <= 0.0f) { PlantOver(on); return false; }
        const float s3 = g_plOwnW * g_plOwnW * (3.0f - 2.0f * g_plOwnW);
        Fw = toWorld(lerp(g_Ct[g_foot[k]].p, rideC[k], s3));
        Qw = qnorm(qmul(mq, qslerpTo(g_Ct[g_foot[k]].q, rideQ[k], s3)));
        V3 kh = (g_toe[k] >= 0) ? qrot(Qw, norm(g_Lt[g_toe[k]].p)) : g_plHeadW; kh.z = 0.0f;
        poleW = (len(kh) > 0.15f) ? norm(kh) : g_plHeadW;
    }
    if (g_plantStage == 2) {
        // the game's own foot as the body's drop leaves it -- never under the ground (GroundFeet's own rule, applied here too)
        V3 Gw = toWorld(own ? rideC[k] : g_Ct[g_foot[k]].p);
        float zg = g_plantGz + g_footAnkle;
        if (g_toe[k] >= 0 && !own) zg = fmaxf(zg, g_plantGz + g_footToe + (Gw.z - toWorld(g_Ct[g_toe[k]].p).z));
        Gw.z = fmaxf(Gw.z, zg);
        const Q4 Gq = qnorm(qmul(mq, own ? rideQ[k] : g_Ct[g_foot[k]].q));
        Fw = lerp(g_plRelStick ? g_plRelW : v3(mp.x + g_plP0.x, mp.y + g_plP0.y, g_plantGz + g_plP0.z), Gw, w);
        // the heel peels up first (the first 30 %: with GroundFeet's toe rule the foot comes up about its toe), then the foot
        // turns to the game's -- which is the clip's own lifted foot (65-77 deg toe-down) carried by the real board
        const float pu = clampf(g_plantU / 0.3f, 0.0f, 1.0f), tu = clampf((g_plantU - 0.25f) / 0.75f, 0.0f, 1.0f);
        const Q4 turn = qaxis(v3(0.0f, 0.0f, 1.0f), (hipsYaw() - g_plYaw0) * 57.2957795f);   // (review) the skater has turned this far since the foot left the ground: it left WITH him
        const Q4 q0 = qnorm(qmul(turn, g_plQ0W)); const V3 hd0 = qrot(turn, g_plHeadW), pole0 = qrot(turn, g_plPole0W);
        const Q4 peel = flat ? qnorm(qmul(qaxis(cross(v3(0.0f, 0.0f, 1.0f), hd0), clampf(g_plPeel, 0.0f, 60.0f) * pu * pu * (3.0f - 2.0f * pu)), q0)) : q0;
        {
            Q4 st = qmul(Gq, qconj(peel));
            if ((g_plStepOk ? st.x * g_plStep.x + st.y * g_plStep.y + st.z * g_plStep.z + st.w * g_plStep.w : st.w) < 0.0f) st = q4(-st.x, -st.y, -st.z, -st.w);
            g_plStep = st; g_plStepOk = true;
            const float tt = tu * tu * (3.0f - 2.0f * tu), ha = acosf(clampf(st.w, -1.0f, 1.0f)), sn = sinf(ha);
            Qw = (sn < 1e-5f) ? peel : qnorm(qmul(q4(st.x * sinf(ha * tt) / sn, st.y * sinf(ha * tt) / sn, st.z * sinf(ha * tt) / sn, cosf(ha * tt)), peel));
        }
        ankOn = flat && !own && g_plAnkle != 0 && g_hingeOn != 0 && g_hingeN[k] >= 30;   // (v99) ...in its ANKLE (the note at g_plSwivel): the leg is solved with the foot as it stood,
        if (ankOn) { ankT = tu * tu * (3.0f - 2.0f * tu); Qw = peel; }                   //   the heel peeling up, and the foot turned against its shin afterwards
        const V3 kn = sub(g_Ct[g_calf[k]].p, lerp(g_Ct[g_thigh[k]].p, g_Ct[g_foot[k]].p, 0.5f));   // the game's knee: its way counts once that leg is bent
        V3 kh = (g_toe[k] >= 0) ? qrot(Qw, norm(g_Lt[g_toe[k]].p)) : pole0; kh.z = 0.0f;
        const V3 kd = (len(kh) > 0.15f) ? norm(kh) : pole0;
        // (v98) ...as far as the game's knee really is bent: on the way back the game's own leg is nearly straight for a few poses
        // (hip to ankle 93-95 % of its bones) and its knee, 4-8 cm off the line, pointed anywhere -- the drawn knee went 15 cm
        // one way and 19 the other on successive poses of the boneless of 5 Oct 11:17:08, 27 cm in the no comply of 11:16:54
        // (and of 08:53: it is in every recording). All of its way from 18 cm off the line, none under 9.
        const float knW = clampf((len(kn) - 9.0f) / 9.0f, 0.0f, 1.0f);
        poleW = norm(lerp(kd, (knW > 0.0f && !own) ? norm(qrot(mq, kn)) : kd, w * w * knW));   // (v97: in the other stance the game's leg hangs off the clip's board -- the toes' way all through)
        const float ap = len(sub(Fw, Gw)), tn = qdiff(Qw, Gq);
        if (ap > g_plApart) g_plApart = ap;
        if (tn > g_plTurn) g_plTurn = tn;
    }
    {                                                     // the plant leg, solved to it: the knee over the toes (its own way, not a straight leg's)
        if (g_plantStage == 2) {                          // on its way up the leg stays a little bent: the foot follows the hip
            const V3 Hd = toWorld(g_Ct[g_thigh[k]].p), v = sub(Fw, Hd);
            if (len(v) > lim) Fw = add(Hd, mul(v, lim / len(v)));
        }
        // (v95, review) "like the top of the ankle disconnecting from the bottom of the calf": the game stretches the plant
        // shin (43.7-50.1 cm for 41.1) and LegOwnLength eases the bones back a quarter a pose from the trick's first pose --
        // the drawn shin was 42.2, 42.6, 43.0, 42.7, 42.1, 41.7 cm while the foot stepped off (22:47:50, poses 43-48): the
        // foot bone up to 2 cm off the end of the calf, on a rig with no twist bone to hide it. The planned leg is placed
        // whole anyway: its bones are their own length from its first pose.
        if (g_legRefOk && g_legRef[k][0] > 1.0f && g_legRef[k][1] > 1.0f) {
            const int bn[2] = { g_calf[k], g_foot[k] };
            for (int j = 0; j < 2; j++) { const float cur = len(g_Lt[bn[j]].p); if (cur > 1.0f) g_Lt[bn[j]].p = mul(g_Lt[bn[j]].p, g_legRef[k][j] / cur); }
            RebuildSub(g_thigh[k]);
        }
        const V3 pc = qinv(mq, poleW);
        Leg(k, toComp(Fw), qnorm(qmul(qconj(mq), Qw)), v3(0.0f, 0.0f, 0.0f), flat ? &pc : nullptr);
        if (ankOn && ankT > 0.0f) {                       // (v99) the foot against its own shin: from as it stood to the game's foot against the game's shin
            const int ca = g_calf[k], ft = g_foot[k];
            const Q4 qc = g_Ct[ca].q;
            const Q4 relP = qnorm(qmul(qconj(qc), g_Ct[ft].q)), relG = qnorm(qmul(qconj(g_C[ca].q), g_C[ft].q));
            const Q4 fq = qnorm(qmul(qc, qslerpTo(relP, relG, ankT)));
            if (std::isfinite(fq.x) && std::isfinite(fq.y) && std::isfinite(fq.z) && std::isfinite(fq.w)) SetComp(ft, fq, g_Ct[ft].p);
        }
    }
    const V3 fd = toWorld(g_Ct[g_foot[k]].p), hdw = toWorld(g_Ct[g_thigh[k]].p);
    const float extNow = len(sub(fd, hdw)) / fmaxf(L, 1.0f);
    if (g_plPhase == 2) {                                 // while it stands: how far the drawn ankle moves against the skater, how long the leg is
        const V3 rel = g_plStickOk ? v3(fd.x, fd.y, fd.z - g_plantGz) : v3(fd.x - mp.x, fd.y - mp.y, fd.z - g_plantGz);   // (v95) a foot that sticks: against the ground it stands on
        if (g_plHaveLast) { const float mv = len(sub(rel, g_plLast)); if (mv > g_plSlide) g_plSlide = mv; }
        g_plLast = rel; g_plHaveLast = true;
        if (extNow < g_plExtLo) g_plExtLo = extNow;
        if (extNow > g_plExtHi) g_plExtHi = extNow;
    }
    if (g_ttFrames > 0 && (g_ttN % (g_ttEvery > 0 ? g_ttEvery : 3)) == 0) {   // (v94) the plan, on the poses the trick trace logs
        float pd = -1.0f, pg = -1.0f;                     // toe-down, deg: as drawn / as the game has it
        if (g_toe[k] >= 0) {
            V3 tv = sub(toWorld(g_Ct[g_toe[k]].p), fd); if (len(tv) > 3.0f) pd = asinf(clampf(-tv.z / len(tv), -1.0f, 1.0f)) * 57.2957795f;
            tv = sub(toWorld(g_C[g_toe[k]].p), wa); if (len(tv) > 3.0f) pg = asinf(clampf(-tv.z / len(tv), -1.0f, 1.0f)) * 57.2957795f;
        }
        Log("tp  +%4llu ms | plan: %s | %s ankle %3.0f cm over the ground, %+4.0f %+4.0f from the skater (the world's axes), %2.0f deg toe-down | its leg %3.0f %% of its length | body down %2.0f (the leg needs %+3.0f, the back leg leaves room for %2.0f) | the game's own foot: %3.0f over the ground, %2.0f cm from ours, %2.0f deg toe-down; its hip joints stood %2.0f (this leg) / %2.0f cm out of their sockets",
            GetTickCount64() - g_ttT0, g_plPhase == 1 ? "stepping off" : g_plPhase == 2 ? "standing    " : "back to game", k ? "R" : "L",
            fd.z - g_plantGz, fd.x - mp.x, fd.y - mp.y, pd, extNow * 100.0f, d, need, room, wa.z - g_plantGz, len(sub(fd, wa)), pg, g_hipGap[k], g_hipGap[o]);
    }
    InterlockedIncrement(&g_plantFrames);
    return true;
}
bool PlantHold(const void* mesh) {
    if (g_plantMode != 2) return PlantSoft(mesh);
    const bool on = g_plantUntil != 0 && GetTickCount64() < g_plantUntil;
    if (!on) {
        g_plantUntil = 0;
        if (g_plantFoot < 0 || g_plantW <= 0.0f) { PlantOver(false); return false; }
        g_plantRel = true;                                // the window is over: both feet go back to the animation's
    }
    if (g_pelvis < 0 || !g_skater) return false;
    const uint8_t* m = (const uint8_t*)mesh;
    const Q4 mq = *(const Q4*)(m + SC_C2W); const V3 mp = *(const V3*)(m + SC_C2W + 0x10); const V3 ms = *(const V3*)(m + SC_C2W + 0x20);
    if (!finite3(mp) || fabsf(ms.x) < 1e-3f || fabsf(ms.y) < 1e-3f || fabsf(ms.z) < 1e-3f) return false;
    auto toWorld = [&](V3 p) { return add(mp, qrot(mq, v3(p.x * ms.x, p.y * ms.y, p.z * ms.z))); };
    auto toComp  = [&](V3 w) { const V3 d = qinv(mq, sub(w, mp)); return v3(d.x / ms.x, d.y / ms.y, d.z / ms.z); };
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    const void* world = SkaterWorld();
    if (!world) return false;
    if (g_plantFoot < 0) {                                // the first foot the animation puts on the ground
        if (g_plantDone) return false;                    // (v73) one plant a window
        int best = -1; float bh = 1e9f;
        for (int k = 0; k < 2; k++) {
            if (g_foot[k] < 0) continue;
            const V3 w = toWorld(g_C[g_foot[k]].p);
            RayHit h;
            if (!Ray(world, add(w, v3(0.0f, 0.0f, 45.0f)), add(w, v3(0.0f, 0.0f, -70.0f)), h)) continue;
            const float hgt = w.z - h.p.z;
            if (hgt < g_footAnkle + 4.0f && hgt < bh) { bh = hgt; best = k; }
        }
        { const int pf = g_plantForce; if ((pf == 0 || pf == 1) && g_foot[pf] >= 0) best = pf; }   // (v80) named by the Lua: no waiting for it to come down
        if (best < 0) return false;
        g_plantFoot = best; g_plantW = 1.0f; g_plantD = g_plantD0 = 0.0f; g_plantRel = false; g_plantMost = 0.0f;
        g_plantDeck0 = g_plantDeckMax = -1e9f;
        g_plantStage = 1; g_plantU = 0.0f; g_plantVz = 0.0f; g_plantVzMax = 0.0f; g_plantHaveT = false; g_plantStepMs = -1.0f; g_plantT0 = NowS();
        g_plantX0 = g_C[g_foot[best]].p; g_plantAxOk = false; g_plantHaveOff = false;
        g_plantIn = (g_plantForce == best) ? 0.0f : 1.0f;
        g_plFlatOk = false; g_plPhase = 0;                // (v94) how it stands is taken afresh (PlantFlat)
        g_plantTurned0 = g_yaw180Until != 0 && GetTickCount64() < g_yaw180Until;
    }
    const int k = g_plantFoot, o = 1 - k;
    if (g_foot[k] < 0 || g_foot[o] < 0 || g_thigh[k] < 0 || g_calf[k] < 0) return false;
    if (g_plantRel) {
        g_plantW -= 1.0f / 9.0f;
        if (g_plantW <= 0.0f) { PlantOver(on); return false; }
    }
    g_deckOk = g_boardOk && DeckXf(mesh);
    const float sz = fabsf(ms.z);
    // (v83) a pose that stands half round from the held feet (a stance swap's frame) is turned to them first
    bool flipped = false;
    if (g_deckOk && g_stCur >= 0) UseStance(g_stCur);
    {                                                     // the switch trick's half turn came (or went) after the foot was down: measured afresh
        const bool tn = g_yaw180Until != 0 && GetTickCount64() < g_yaw180Until;
        if (tn != g_plantTurned0) { g_plantTurned0 = tn; g_plantHaveOff = false; g_plantAxOk = false; }
    }
    const V3 akC = flipped ? v3(-g_C[g_foot[k]].p.x, -g_C[g_foot[k]].p.y, g_C[g_foot[k]].p.z) : g_C[g_foot[k]].p;
    const V3 waAnim = toWorld(akC);                       // where the animation has the foot
    if (!g_plantHaveOff) { g_plantOffW = v3(waAnim.x - mp.x, waAnim.y - mp.y, 0.0f); g_plantHaveOff = true; g_plantAxOk = false; }
    if (!g_plantAxOk && g_deckOk) {                       // beside the board, not under it
        V3 lt = qrot(mq, qrot(g_dq, v3(0.0f, 1.0f, 0.0f))); lt.z = 0.0f;
        if (len(lt) > 0.5f) {
            lt = norm(lt);
            const V3 dw = toWorld(g_dp);
            const float a0 = (mp.x + g_plantOffW.x - dw.x) * lt.x + (mp.y + g_plantOffW.y - dw.y) * lt.y;
            const float want = clampf(g_plantClear, 0.0f, 40.0f);
            // (v83) ON ITS OWN SIDE OF THE BOARD, NEAR ITS OWN END. The foot was put beside the board on whichever side the
            // animation's foot happened to be when it was named -- and in a switch trick (the other stance, the mesh turned)
            // that was the FAR side, both times: the traces of 23:24:19 and 23:29:05 have it crossing the deck, -10 cm across
            // to +17 and +10 to -18 ("they almost try to step on the other side of the board"). The side is the one the
            // foot's ankle rides on (the heel side: where the game's own no comply puts it, -11 to -27), and along the board
            // it goes down within 15 cm of where it rides.
            float side = (a0 >= 0.0f) ? 1.0f : -1.0f;
            if (g_stCur >= 0 && g_dFootOk[k] && fabsf(g_uFootP[k].y) > 3.0f) side = (g_uFootP[k].y >= 0.0f) ? 1.0f : -1.0f;
            if (side * a0 < 0.0f && InterlockedIncrement(&g_plantSided) <= 20)
                Log("plant: the animation had the foot %.0f cm across the board on the far side -- it goes down on its own side", a0);
            const float to = side * clampf(fabsf(a0), want, fmaxf(want, 32.0f));
            { const float push = to - a0; g_plantOffW.x += lt.x * push; g_plantOffW.y += lt.y * push; }
            V3 lx = qrot(mq, qrot(g_dq, v3(1.0f, 0.0f, 0.0f))); lx.z = 0.0f;
            if (len(lx) > 0.5f && g_stCur >= 0 && g_dFootOk[k]) {
                lx = norm(lx);
                const float b0 = (mp.x + g_plantOffW.x - dw.x) * lx.x + (mp.y + g_plantOffW.y - dw.y) * lx.y;
                // (v90) ...OR WHERE THE SETTING SAYS, AS THE SOFT PLANT DOES. "Can't tell if the switch no comply is good or bad
                // because it seems like it's still adhering to the foot forward approach, even though I zeroed that setting."
                // It was: this plant took the animation's foot wherever it was when named, within 15 cm of the riding spot
                // (the switch trick of 19:31:32: 8 cm ahead of it), and never read NoComplyPlantForward. With the setting on
                // (plantfwd > -90) the foot goes down at its riding spot + that many cm toward its own end -- 0 = on the spot.
                float bt = clampf(b0, g_uFootP[k].x * sz - 15.0f, g_uFootP[k].x * sz + 15.0f);
                if (g_plantFwd > -90.0f && g_dFootOk[o]) {
                    const float fw = (g_uFootP[k].x - g_uFootP[o].x) >= 0.0f ? 1.0f : -1.0f;
                    bt = (g_uFootP[k].x + fw * g_plantFwd) * sz;
                    if (g_plantTold < 60) Log("plant: the foot goes down %+.0f cm along the board (its riding spot %+.0f, plantfwd %+.0f); the animation had it at %+.0f", bt, g_uFootP[k].x * sz, (float)g_plantFwd, b0);
                }
                g_plantOffW.x += lx.x * (bt - b0); g_plantOffW.y += lx.y * (bt - b0);
            }
            g_plantAxOk = true;
        }
    }
    const float kb = clampf(g_plantBack, 0.0f, 1.0f);
    // (v96) THE PINNED PLANT STANDS AND LEAVES AS THE SOFT ONE DOES (v95's rules, which never ran here). The four switch tricks
    // of 5 Oct: the foot stood 350-366 ms at a fixed place beside the SKATER -- 101, 103, 156 and 105 cm along the ground at
    // 290-470 cm/s -- with the hips kept 28-32 cm down for it until the board's top, the back leg welded to the rising deck
    // folded to 30-46 % of its length, its knee out to the side. With plantstick: from the pose it is down on it keeps its
    // place in the WORLD; it leaves after plantstand seconds, or when the hips are 0.45 of a leg ahead of it; from where
    // it stood it then goes on with the skater (up first, then over, as before), the leg a little bent, the foot following
    // the hip; the hips come up with the step and are not pulled down again for a foot that is on its way.
    if (g_plStickOk && g_plantStage != 1 && !g_plRelStick) { g_plantOffW = v3(g_plStickW.x - mp.x, g_plStickW.y - mp.y, 0.0f); g_plRelStick = true; }
    V3 wa = v3(mp.x + g_plantOffW.x + (waAnim.x - mp.x - g_plantOffW.x) * kb, mp.y + g_plantOffW.y + (waAnim.y - mp.y - g_plantOffW.y) * kb, waAnim.z);
    if (g_plStickOk) {                                    // where it stuck; once it has left the ground it takes up the skater's speed over the first 30 % of the step
        const float go = (g_plantStage == 1) ? 0.0f : Sm01((float)(NowS() - g_plantStepT0) / (clampf(g_plantStepS, 0.03f, 0.5f) * 0.3f));
        wa.x = g_plStickW.x + (wa.x - g_plStickW.x) * go; wa.y = g_plStickW.y + (wa.y - g_plStickW.y) * go;
    }
    {
        RayHit h;
        if (Ray(world, add(wa, v3(0.0f, 0.0f, 60.0f)), add(wa, v3(0.0f, 0.0f, -160.0f)), h)) { g_plantGz = h.p.z; g_plantHaveT = true; }
        else if (!g_plantHaveT) { g_plantRel = true; return false; }
        else if (g_plantStage == 1) { g_plantStage = 2; g_plantStepT0 = NowS(); g_plantD0 = g_plantD; }   // no ground under it any more: onto the board
    }
    // (v94) ...standing as a planned plant foot stands (PlantFlat: as it rides, flat, the heel a little up, the way it points on
    // the board kept) -- not turned as the game has it, which is right only against the game's own board: on the ground it is
    // 40-64 deg too far toe-down (v91-v93 turned it back in GroundFeet, by a heading read from the foot itself)
    // (v96) ...and a foot that STICKS is turned as the soft plant's: along the board toward its own end, planttoein deg in. The
    // body now rolls on past it (hips up to 0.45 of a leg ahead): with the riding heading kept (toes square to the board) the
    // shin would lean over the foot's SIDE and the toes would reach under the board's edge; turned this way the body goes
    // over its toes, as in the regular trick. It turns there as it steps off and back as it steps on (both were there).
    const bool flatK = (g_plStick != 0 && g_stCur >= 0 && g_dFootOk[k] && g_dFootOk[o])
        ? PlantFlat(k, mq, ms, (g_uFootP[k].x - g_uFootP[o].x) >= 0.0f ? 1.0f : -1.0f, false)
        : PlantFlat(k, mq, ms, 1.0f, true);
    V3 T = v3(wa.x, wa.y, g_plantGz + (flatK ? PlantAnkle() : g_footAnkle));       // ...on the ground under it
    const V3 hip = toWorld(g_Ct[g_thigh[k]].p);
    const float reach = (len(sub(g_Ct[g_calf[k]].p, g_Ct[g_thigh[k]].p)) + len(sub(g_Ct[g_foot[k]].p, g_Ct[g_calf[k]].p))) * sz * 0.97f;
    float dx = sqrtf((T.x - hip.x) * (T.x - hip.x) + (T.y - hip.y) * (T.y - hip.y));
    const float dxMax = reach * 0.8f;
    if (dx > dxMax) { const float s = dxMax / dx; T.x = hip.x + (T.x - hip.x) * s; T.y = hip.y + (T.y - hip.y) * s; dx = dxMax; }
    // how far the hips are too high for the leg -- less what a hand on the board brings them down by anyway (v73: the
    // two were ADDED, 5-12 cm for the leg and 11 for the hand in the boneless of 19:18:21: the plant leg bent)
    const float bd = fmaxf(g_boneDrop, 0.0f) * clampf(g_boneW, 0.0f, 1.0f) * sz;
    const float need = (hip.z - T.z) - sqrtf(fmaxf(reach * reach - dx * dx, 1.0f)) - bd;
    // the drawn deck over the ground, and how fast it rises
    float dh = 0.0f;
    if (g_deckOk) {
        dh = toWorld(g_dp).z - g_plantGz;
        const double t = NowS();
        if (g_plantDeck0 < -1e8f) { g_plantDeck0 = g_plantDeckMax = g_plantPrevZ = dh; g_plantPrevT = t; g_plantVz = 0.0f; }
        else {
            const float dt = (float)(t - g_plantPrevT);
            if (dt > 0.004f) {
                if (dt < 0.2f) g_plantVz += ((dh - g_plantPrevZ) / dt - g_plantVz) * 0.5f;
                if (g_plantVz > g_plantVzMax) g_plantVzMax = g_plantVz;
                g_plantPrevZ = dh; g_plantPrevT = t;
            }
        }
        if (dh > g_plantDeckMax) g_plantDeckMax = dh;
    }
    const float cap = fmaxf(g_plantMax, 0.0f);
    if (g_plantStage == 1 && !g_plantRel) {
        const bool risen = g_deckOk && (g_plantDeckMax - g_plantDeck0) > 8.0f;
        const char* why = nullptr;
        if (risen && g_plantVzMax >= fmaxf(150.0f, g_plantLead + 60.0f) && g_plantVz < g_plantLead) why = "the board is at its top";
        else if (risen && dh < g_plantDeckMax - 1.0f) why = "the board is on its way down";
        else if (need > cap + 1.0f) why = "the leg can reach no longer";
        else if (risen && g_plantFold > 0.0f && g_plantBackFold > 0.0f && g_plantBackFold < g_plantFold) why = "the back leg is folded as far as it goes";
        if (!why && g_plStickOk) {                        // (v96) a foot that sticks: the soft plant's two rules
            if (g_plStandMax > 0.01f && NowS() - g_plStandT0 >= (double)g_plStandMax) why = "it has stood its time (NoComplyPlantTime)";
            else if (dx > reach * 0.45f) why = "the body has rolled on too far from where it stands";
        }
        if (why) {
            g_plantStage = 2; g_plantStepT0 = NowS(); g_plantD0 = g_plantD;
            g_plantStepMs = (float)((g_plantStepT0 - g_plantT0) * 1000.0);
            if (InterlockedIncrement(&g_plantTold) <= 40)
                Log("plant: the foot leaves the ground %.0f ms after it went down (%s) -- the deck %.0f cm over the ground (%.0f up from its start), rising %.0f cm/s (%.0f at its fastest); the hips were %.0f cm down; onto the board in %.0f ms",
                    g_plantStepMs, why, dh, dh - g_plantDeck0, g_plantVz, g_plantVzMax, g_plantD, g_plantStepS * 1000.0f);
        } else {
            g_plantD = fminf(clampf(need, 0.0f, cap), g_plantD + (g_plStickOk ? 6.0f : 3.5f));   // (v86) not all at once (5 cm a pose in the switch traces: 30 cm in 0.1 s); (v96) 6 for a foot that stays behind while the body rolls on (at 3.5-4.5 its leg locked straight, lifted it off its place and the knee popped 11-15 cm when the step began)
            if (g_plantD > g_plantMost) g_plantMost = g_plantD;
        }
    }
    float su = 0.0f;
    if (g_plantStage == 2) {
        g_plantU = clampf((float)(NowS() - g_plantStepT0) / clampf(g_plantStepS, 0.03f, 0.5f), 0.0f, 1.0f);
        su = g_plantU * g_plantU * (3.0f - 2.0f * g_plantU);
        g_plantD = g_plantD0 * (1.0f - su);               // the hips come up as the foot does: he jumps off it
    }
    const float s = g_plantW * g_plantW * (3.0f - 2.0f * g_plantW);
    const float d = g_plantD * s;
    // a foot's own riding spot on the drawn deck. With the switch no comply drawn mirrored (the pose turned half round)
    // each foot rides at its own end still, facing the board's other side: the spot mirrored across the deck's long axis,
    // the animation's own turn of the foot
    const bool turned = g_yaw180Until != 0 && GetTickCount64() < g_yaw180Until;
    if (g_deckOk && g_stCur >= 0) UseStance(g_stCur);
    auto spot = [&](int f, V3& p, Q4& q) {
        if (!g_deckOk || g_stCur < 0 || !g_dFootOk[f]) return false;
        // (not DeckFoot: its "within 90 cm of the animation's foot" test would drop a spot high over a planted foot)
        // (v75) the same for the switch no comply's turned pose: the traces of 20:13:44 have the trick (the flag AND the half
        // turn) with each foot at the end of the board it rides at, facing the way it rides -- its own spot, its own turn
        (void)turned;
        p = add(g_dp, qrot(g_dq, g_uFootP[f]));
        q = qnorm(qmul(g_dq, g_uFootQ[f]));
        return finite3(p) && len(sub(p, g_C[g_foot[f]].p)) < 170.0f;
    };
    // (v72) THE BACK FOOT STAYS ON THE TAIL ("the back foot comes way off the tail in the initial stages"); (v73) for the
    // whole trick now: both feet go back to the animation's only when the window ends
    V3 fo = g_Ct[g_foot[o]].p; Q4 qo = g_Ct[g_foot[o]].q;
    { V3 dp; Q4 dqq; if (spot(o, dp, dqq)) { fo = lerp(fo, dp, s); qo = qslerpTo(qo, dqq, s); } }
    V3 fk = toComp(T); Q4 qk = flatK ? qnorm(qmul(qconj(mq), g_plFlatW)) : g_C[g_foot[k]].q;   // (v94)
    if (g_plantStage == 2) {
        V3 bp; Q4 bq;
        if (!spot(k, bp, bq)) { bp = g_C[g_foot[k]].p; bq = g_C[g_foot[k]].q; }   // no riding spot known: the animation's foot
        // (v76) UP FIRST, THEN OVER
        const float uu = clampf(g_plantU / 0.6f, 0.0f, 1.0f), uo = clampf((g_plantU - 0.45f) / 0.55f, 0.0f, 1.0f);
        const float sUp = uu * uu * (3.0f - 2.0f * uu), sOv = uo * uo * (3.0f - 2.0f * uo);
        const V3 gk = fk;
        fk = v3(gk.x + (bp.x - gk.x) * sOv, gk.y + (bp.y - gk.y) * sOv, gk.z + (bp.z - gk.z) * sUp + g_plantHump * sinf(3.14159265f * sOv));
        qk = qslerpTo(qk, bq, sOv);
    }
    // (v83) THE HIPS NO HIGHER THAN BOTH LEGS REACH. Once the foot had stepped back on, the hips went up to the animation's
    // own height -- and in the switch trick that is 85 cm over a board that has started down: the legs, straight, could not
    // reach their spots and both feet hung 13-16 cm over the deck for a tenth of a second (23:24:19: 'over the deck' 28,
    // 28, 18 where 15 is standing on it; 23:29:05: 31, 29, 24 on both). For as long as the plant holds the feet, the hips
    // are kept as low as the shorter-reaching leg needs (the knees a little bent once the step is done).
    float dd = d / sz;
    {
        const float lim = 0.97f - 0.07f * ((g_plantStage == 2) ? su : 0.0f);
        const V3 tk = lerp(g_C[g_foot[k]].p, fk, s);
        float nd = 0.0f;
        for (int j = 0; j < 2; j++) {
            if (j == k && g_plantStage != 2) continue;        // on the ground: the plant's own drop, above
            if (g_thigh[j] < 0 || g_calf[j] < 0 || g_foot[j] < 0) continue;
            const V3 tj = (j == k) ? tk : fo;
            const V3 H = g_Ct[g_thigh[j]].p;
            const float L = (len(sub(g_Ct[g_calf[j]].p, H)) + len(sub(g_Ct[g_foot[j]].p, g_Ct[g_calf[j]].p))) * lim;
            const float hx = sqrtf((tj.x - H.x) * (tj.x - H.x) + (tj.y - H.y) * (tj.y - H.y));
            const float nj = (H.z - tj.z) - sqrtf(fmaxf(L * L - hx * hx, 1.0f)) - bd / sz;
            const float nw = (j == k && g_plStickOk) ? nj * su : nj;   // (v96) a foot on its way from where it stuck follows the hip, not the hip the foot
            if (nw > nd) nd = nw;
        }
        nd = clampf(nd, 0.0f, 60.0f) * s;
        g_plantHipS += (nd - g_plantHipS) * ((nd > g_plantHipS) ? 0.6f : 0.25f);
        if (g_plantHipS > dd) dd = g_plantHipS;
        if (dd * sz > g_plantMost) g_plantMost = dd * sz;
    }
    if (dd > 0.2f) SetComp(g_pelvis, g_Ct[g_pelvis].q, sub(g_Ct[g_pelvis].p, v3(0.0f, 0.0f, dd)));
    Leg(o, fo, qo);
    if (g_thigh[o] >= 0 && g_calf[o] >= 0)                // (v89) how folded the back leg is drawn, as a share of its own length
        g_plantBackFold = len(sub(g_Ct[g_foot[o]].p, g_Ct[g_thigh[o]].p))
            / fmaxf((g_legRefOk && g_legRef[o][0] > 1.0f && g_legRef[o][1] > 1.0f) ? g_legRef[o][0] + g_legRef[o][1] : BoneLen(g_Ct, g_thigh[o], g_calf[o]) + BoneLen(g_Ct, g_calf[o], g_foot[o]), 1.0f);
    g_plantIn = fminf(g_plantIn + 0.2f, 1.0f);
    if (g_plStick != 0 && !g_plStickOk && g_plantStage == 1 && !g_plantRel && g_plantIn >= 1.0f) {   // (v96) it is down: it stands HERE, in the world
        g_plStickW = v3(T.x, T.y, 0.0f); g_plStickOk = true; g_plRelStick = false; g_plStandT0 = NowS();
        if (g_plantTold < 60) Log("plant: the pinned plant's foot is down %.0f ms after it began, %+.0f %+.0f cm from the skater (the world's axes) -- it keeps that place in the world, for %.2f s at most", (g_plStandT0 - g_plantT0) * 1000.0, T.x - mp.x, T.y - mp.y, (float)g_plStandMax);
    }
    const float pin = g_plantIn * g_plantIn * (3.0f - 2.0f * g_plantIn);
    const V3 pkNow = g_Ct[g_foot[k]].p; const Q4 qkNow = g_Ct[g_foot[k]].q;      // where it is now (held on the board, at the start)
    V3 tgK = lerp(pkNow, lerp(g_C[g_foot[k]].p, fk, s), pin);
    if (g_plStickOk && g_plantStage == 2) {               // (v96) the soft plant's rule: on its way up the leg stays a little bent
        const V3 H = g_Ct[g_thigh[k]].p, v = sub(tgK, H);
        const float L97 = (len(sub(g_Ct[g_calf[k]].p, H)) + len(sub(g_Ct[g_foot[k]].p, g_Ct[g_calf[k]].p))) * 0.97f;
        if (len(v) > L97) tgK = add(H, mul(v, L97 / len(v)));
    }
    // (v96) ITS KNEE OVER ITS TOES while it stands and steps, as the soft plant's leg has it. The knee's way was taken from the
    // pose -- and through the swap's cross-fade that leg of the game's pose is anywhere (its knee 70 cm from one pose to the
    // next at 00:02:08): the drawn plant knee stood 60-78 deg round from the toes all the time the foot was down, and went
    // 66 -> 178 -> 96 deg in two poses (26.9 cm in one). The pose's own knee comes back as the foot steps onto the board.
    V3 poleK = v3(0.0f, 0.0f, 0.0f); bool poleOk = false;
    if (flatK) {
        const V3 kn = sub(g_Ct[g_calf[k]].p, lerp(g_Ct[g_thigh[k]].p, g_Ct[g_foot[k]].p, 0.5f));
        const V3 hd = qinv(mq, g_plHeadW);
        if (len(hd) > 0.5f) { poleK = norm(lerp(hd, (len(kn) > 4.0f) ? norm(kn) : hd, 1.0f - s * pin * (1.0f - su * su))); poleOk = true; }
    }
    Leg(k, tgK, qslerpTo(qkNow, qslerpTo(g_C[g_foot[k]].q, qk, s), pin), v3(0.0f, 0.0f, 0.0f), poleOk ? &poleK : nullptr);
    InterlockedIncrement(&g_plantFrames);
    return true;
}
// HJN_Plant() -> "<poses the plant foot was held, so far> <the most the hips were kept down since the last call, cm> <foot: 0 left, 1 right, -1 none>"
int nPlant(const Lua& lua) {
    char out[96]; snprintf(out, sizeof(out), "%ld %.0f %d %d %.0f", g_plantFrames, g_plantMost, g_plantFoot, g_plantStage, g_plantStepMs);   // (v73) + the stage, ms from the plant to the step
    g_plantMost = 0.0f;
    lua.set_string(out);
    return 1;
}
void TrickTraceLine(const void* mesh, const void* anim) {
    if (!DeckXf(mesh)) { Log("tt  +%4llu ms | the drawn deck could not be read", GetTickCount64() - g_ttT0); return; }
    const uint8_t* m = (const uint8_t*)mesh;
    const Q4 mq = *(const Q4*)(m + SC_C2W); const V3 mp = *(const V3*)(m + SC_C2W + 0x10); const V3 ms = *(const V3*)(m + SC_C2W + 0x20);
    const V3 up = qrot(g_dq, v3(0, 0, 1)), fw = qrot(g_dq, v3(1, 0, 0));          // the deck's own up and long axis, in the mesh's space
    auto over  = [&](V3 p) { return dot(sub(p, g_dp), up); };
    auto world = [&](V3 p) { return add(mp, qrot(mq, v3(p.x * ms.x, p.y * ms.y, p.z * ms.z))); };
    const V3 fwW = qrot(mq, v3(fw.x * ms.x, fw.y * ms.y, fw.z * ms.z));
    const float pitch = asinf(clampf(norm(fwW).z, -1.0f, 1.0f)) * 57.2957795f;
    float gz = mp.z, deckG = -1.0f;                                              // (v71) everything against the GROUND under the skater
    if (g_skater) {
        uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
        const void* w = SkaterWorld();
        if (w) {
            RayHit h;
            if (Ray(w, add(mp, v3(0, 0, 60.0f)), add(mp, v3(0, 0, -400.0f)), h)) gz = h.p.z;
            const V3 dw = world(g_dp);
            if (Ray(w, add(dw, v3(0, 0, 30.0f)), add(dw, v3(0, 0, -400.0f)), h)) deckG = dw.z - h.p.z;
        }
    }
    const int L = g_foot[0], R = g_foot[1], P = g_pelvis;
    if (L < 0 || R < 0 || P < 0) return;
    auto hgt = [&](V3 p) { return world(p).z - gz; };
    const V3 lt = qrot(g_dq, v3(0, 1, 0));
    auto acr = [&](V3 p) { return dot(sub(p, g_dp), lt); };                        // (v75) cm toward the deck's +Y edge
    auto along = [&](V3 p) { return dot(sub(p, g_dp), fw); };                    // (v74) cm toward the deck's +X end
    Log("tt  +%4llu ms | root %4.0f, deck %4.0f cm over the ground (pitch %+4.0f) | hips over the ground: anim %4.0f drawn %4.0f | L ankle over the ground: anim %4.0f drawn %4.0f (over the deck %+4.0f) | R ankle: anim %4.0f drawn %4.0f (over the deck %+4.0f) | plant foot %d w %.2f step %.2f hips down %2.0f | foot IK L %.2f R %.2f | hand w %.2f gap %2.0f crouch %2.0f lean %2.0f | along the deck: L anim %+3.0f drawn %+3.0f, R anim %+3.0f drawn %+3.0f | across: L %+3.0f R %+3.0f | deck in the mesh: at %+4.0f %+4.0f, yaw %+4.0f | hips' line to the feet's: anim %3.0f drawn %3.0f, turned on %ld poses | legs drawn (thigh+shin, hip to ankle) L %.0f+%.0f %.0f R %.0f+%.0f %.0f; the game's bones L %.0f+%.0f R %.0f+%.0f | in the mesh (x y): hips %+.0f %+.0f, L hip %+.0f %+.0f, L %+.0f %+.0f, R %+.0f %+.0f",
        GetTickCount64() - g_ttT0, mp.z - gz, deckG, pitch, hgt(g_C[P].p), hgt(g_Ct[P].p),
        hgt(g_C[L].p), hgt(g_Ct[L].p), over(g_Ct[L].p), hgt(g_C[R].p), hgt(g_Ct[R].p), over(g_Ct[R].p),
        g_plantFoot, g_plantW, (g_plantStage == 2) ? g_plantU : 0.0f, g_plantD * g_plantW, ReadF(anim, AI_LFOOT_A), ReadF(anim, AI_RFOOT_A), g_boneW, g_boneGap, g_boneDrop, g_boneLean,
        along(g_C[L].p), along(g_Ct[L].p), along(g_C[R].p), along(g_Ct[R].p), acr(g_Ct[L].p), acr(g_Ct[R].p),
        g_dp.x, g_dp.y, atan2f(fw.y, fw.x) * 57.2957795f,
        (g_thigh[0] >= 0 && g_thigh[1] >= 0 && g_stCur >= 0) ? flatAngle(sub(g_C[g_thigh[0]].p, g_C[g_thigh[1]].p), qrot(g_dq, sub(g_uFootP[0], g_uFootP[1]))) : -1.0f,
        (g_thigh[0] >= 0 && g_thigh[1] >= 0 && g_stCur >= 0) ? flatAngle(sub(g_Ct[g_thigh[0]].p, g_Ct[g_thigh[1]].p), qrot(g_dq, sub(g_uFootP[0], g_uFootP[1]))) : -1.0f, g_bodyFlips,
        BoneLen(g_Ct, g_thigh[0], g_calf[0]), BoneLen(g_Ct, g_calf[0], g_foot[0]), BoneLen(g_Ct, g_thigh[0], g_foot[0]),
        BoneLen(g_Ct, g_thigh[1], g_calf[1]), BoneLen(g_Ct, g_calf[1], g_foot[1]), BoneLen(g_Ct, g_thigh[1], g_foot[1]),
        BoneLen(g_C, g_thigh[0], g_calf[0]), BoneLen(g_C, g_calf[0], g_foot[0]), BoneLen(g_C, g_thigh[1], g_calf[1]), BoneLen(g_C, g_calf[1], g_foot[1]),
        g_Ct[P].p.x, g_Ct[P].p.y, (g_thigh[0] >= 0) ? g_Ct[g_thigh[0]].p.x : 0.0f, (g_thigh[0] >= 0) ? g_Ct[g_thigh[0]].p.y : 0.0f, g_Ct[L].p.x, g_Ct[L].p.y, g_Ct[R].p.x, g_Ct[R].p.y);
    if (g_toe[0] >= 0 && g_toe[1] >= 0 && g_calf[0] >= 0 && g_calf[1] >= 0 && g_thigh[0] >= 0 && g_thigh[1] >= 0) {   // (v89)
        auto tw = [&](const TF* B, int k) { const V3 A = B[g_foot[k]].p, sh = norm(sub(A, B[g_calf[k]].p));
            V3 kn = sub(B[g_calf[k]].p, lerp(B[g_thigh[k]].p, A, 0.5f)), to = sub(B[g_toe[k]].p, A);
            kn = sub(kn, mul(sh, dot(kn, sh))); to = sub(to, mul(sh, dot(to, sh)));
            return (len(kn) > 3.0f && len(to) > 1.0f) ? acosf(clampf(dot(norm(kn), norm(to)), -1.0f, 1.0f)) * 57.2957795f : -1.0f; };
        auto fx = [&](const TF* B, int k) { return acosf(clampf(dot(norm(sub(B[g_calf[k]].p, B[g_foot[k]].p)), norm(sub(B[g_toe[k]].p, B[g_foot[k]].p))), -1.0f, 1.0f)) * 57.2957795f; };
        Log("tf  +%4llu ms | ankle twist/flex deg, anim > drawn: L %3.0f/%3.0f > %3.0f/%3.0f R %3.0f/%3.0f > %3.0f/%3.0f | ankle to toe cm drawn (game): L %.1f (%.1f) R %.1f (%.1f)",
            GetTickCount64() - g_ttT0, tw(g_C, 0), fx(g_C, 0), tw(g_Ct, 0), fx(g_Ct, 0), tw(g_C, 1), fx(g_C, 1), tw(g_Ct, 1), fx(g_Ct, 1),
            BoneLen(g_Ct, g_foot[0], g_toe[0]), BoneLen(g_C, g_foot[0], g_toe[0]), BoneLen(g_Ct, g_foot[1], g_toe[1]), BoneLen(g_C, g_foot[1], g_toe[1]));
    }
    // (v94) WHAT THE GAME AIMS EACH FOOT AT, in the drawn deck's own frame: its foot sockets (the anim instance's), the skeleton's
    // foot anchors and its own board bone. The clip keys the anchors to each foot's place in ITS board's frame (the plant foot:
    // -10 -21 -18 at 0.13 s, -38 -20 -9 at 0.30 s, +23 -10 +17 at the end) and its board bone from 4 to 70 cm, to 64 deg: if the
    // sockets read like those anchor keys, the note at g_plPhase is confirmed in the game itself; if the skeleton's board
    // bone reads the clip's heights, the clip's own clock can be read off it.
    if (g_flipper >= 0 && g_footAnchor[0] >= 0 && g_footAnchor[1] >= 0) {
        auto dk = [&](V3 p) { return qinv(g_dq, sub(p, g_dp)); };
        const V3 sL = ReadV3(anim, AI_LFOOT_LOC), sR = ReadV3(anim, AI_RFOOT_LOC);
        const V3 s0 = finite3(sL) ? dk(sL) : v3(0.0f, 0.0f, 0.0f), s1 = finite3(sR) ? dk(sR) : v3(0.0f, 0.0f, 0.0f);
        const V3 a0 = dk(g_C[g_footAnchor[0]].p), a1 = dk(g_C[g_footAnchor[1]].p), f0 = dk(g_C[L].p), f1 = dk(g_C[R].p);
        const V3 bx = norm(qrot(mq, qrot(g_C[g_flipper].q, v3(1.0f, 0.0f, 0.0f))));
        Log("ta  +%4llu ms | the skeleton's board bone %3.0f cm over the ground, its long axis %+3.0f deg off level | in the drawn deck's frame (along across up): the game's foot sockets L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f); the skeleton's foot anchors L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f); the game's feet L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f)",
            GetTickCount64() - g_ttT0, hgt(g_C[g_flipper].p), asinf(clampf(bx.z, -1.0f, 1.0f)) * 57.2957795f,
            s0.x, s0.y, s0.z, s1.x, s1.y, s1.z, a0.x, a0.y, a0.z, a1.x, a1.y, a1.z, f0.x, f0.y, f0.z, f1.x, f1.y, f1.z);
    }
}
// HJN_TrickTrace(poses, tag) -> poses that will be traced
int nTrickTrace(const Lua& lua) {
    double f = 0; std::string tag;
    ArgNum(lua, f); ArgStr(lua, tag);
    g_ttN = 0; g_ttT0 = GetTickCount64();
    g_ttFrames = (int)clampf((float)f, 0.0f, 400.0f);
    g_ttEvery = (tag.find("switch") != std::string::npos) ? 1 : 3;   // (v83) a switch trick: every pose
    Log("---- trick trace (%s): %d poses, every third logged. Heights are cm over the ground under the skater; anim = as the game's animation had it, drawn = after the mod's edits", tag.c_str(), g_ttFrames);
    lua.set_integer(g_ttFrames);
    return 1;
}
struct LedgeCtx { const void* world; V3 P; float z0; float minDrop; V3 n0; };
// how far the ground at (x, y) lies under the ground the skater stands on (cm; 400 = none within 4 m)
float DropAt(const LedgeCtx& c, float x, float y, V3* n = nullptr) {
    RayHit h;
    if (!Ray(c.world, v3(x, y, c.P.z), v3(x, y, c.z0 - 400.0f), h)) return 400.0f;
    if (n) *n = h.n;
    return c.z0 - h.p.z;
}
// along direction d from the skater: the distance at which the ground drops away (-1 = it does not within range)
// The edge = where the ground LEAVES the plane you stand on (by more than 4 cm), provided it goes on to fall by the
// least drop within 70 cm past that: the top of a bank or a transition falls away slowly at first -- taking "where it
// is 25 cm down" for the edge would put it half a metre out on the slope.
float EdgeAlong(const LedgeCtx& c, V3 d, float range) {
    const float per = (c.n0.z > 0.3f) ? (c.n0.x * d.x + c.n0.y * d.y) / c.n0.z : 0.0f;   // the top's own fall per cm this way
    auto off = [&](float r) { return DropAt(c, c.P.x + d.x * r, c.P.y + d.y * r) - per * r; };
    const float eps = 4.0f;
    float flat = 0.0f, first = -1.0f;
    for (float r = 10.0f; r <= range + 70.5f; r += 7.0f) {
        const float dv = off(r);
        if (dv < -18.0f) return -1.0f;                   // a step UP or a wall first: no ledge this way
        if (first < 0.0f) {
            if (dv <= eps) { flat = r; if (r > range) return -1.0f; continue; }
            if (r - 7.0f > range) return -1.0f;          // (the edge itself must be within range)
            first = r;
        } else if (dv <= eps) { first = -1.0f; flat = r; if (r > range) return -1.0f; continue; }   // only a dip
        if (first >= 0.0f && dv > c.minDrop) {
            float lo = flat, hi = first;
            for (int i = 0; i < 6; i++) {
                const float m = 0.5f * (lo + hi);
                if (off(m) > eps) hi = m; else lo = m;
            }
            const float e = 0.5f * (lo + hi);
            return (e <= range) ? e : -1.0f;
        }
        if (first >= 0.0f && r > first + 70.0f) return -1.0f;
    }
    return -1.0f;
}
void* BoardActorNow();
int LedgeScan(float range, float minDrop, float faceYaw, float faceCone, int gtype, char* out, size_t n) {
    out[0] = 0;
    if (!g_hooked || !g_skater || !PtrOk(g_skater, 0x140)) return 0;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    const void* root = *(void* const*)((const uint8_t*)g_skater + ACTOR_ROOT);
    if (!PtrOk(root, 0x200)) return 0;
    LedgeCtx c;
    c.world = SkaterWorld();
    if (!c.world) return 0;
    c.P = *(const V3*)((const uint8_t*)root + SC_C2W + 0x10);
    c.minDrop = clampf(minDrop, 8.0f, 300.0f);
    range = clampf(range, 20.0f, 200.0f);
    g_selfIdx[0] = PtrOk(g_skater, 0x10) ? *(const int32_t*)((const uint8_t*)g_skater + 0xC) : -1;   // (v49) UObject::InternalIndex
    { void* bd = BoardActorNow(); g_selfIdx[1] = (bd && PtrOk(bd, 0x10)) ? *(const int32_t*)((const uint8_t*)bd + 0xC) : -1; }
    const LONG selfBefore = g_selfHits;
    RayHit g;
    g_rayMask = 1; g_rayComplex = 0;                     // WorldStatic: the level as built, its simple collision
    if (!Ray(c.world, c.P, sub(c.P, v3(0, 0, 300.0f)), g)) {
        // (v42) a custom map's ground may be dynamic or on a channel of its own (Crooked Banks' vert ramp: "no ground under
        // you"): look again with every object type but the skater (Pawn) and the board (PhysicsBody), and keep that mask
        // for the rest of the look and the way down
        // (v51) COMPLEX COLLISION first: the dropped quarter pipe (PBP_OBJ_Ramp_Quater_A, a static mesh added at run time) is
        // WorldStatic to the game's floor check, yet no simple-collision ray found it in three versions -- it has only the
        // per-triangle mesh. The rest of this look, and the mount's own rays, then go complex too (the mask is kept the same way)
        g_rayComplex = 1;
        if (Ray(c.world, c.P, sub(c.P, v3(0, 0, 300.0f)), g) && g.p.z <= c.P.z - 30.0f) {
            Log("ledge scan: the ground under you is WorldStatic as COMPLEX collision only (a dropped object?) -- this look and the mount's rays go by the complex collision");
            goto ground_found;
        }
        Log("ledge scan: the ground under you is not WorldStatic, simple or complex (a dropped object, or a custom map's own collision?)");
        // (v50) THE GROUND'S OWN OBJECT TYPE, and the look goes on with that and the level alone. First the type of the floor
        // component the game stands you on (Lua: BasedMovement.MovementBase:GetCollisionObjectType -- a dropped quarter pipe is
        // a physics object, a type v49 left out as "the board"); else the single type that sees the highest ground at least 30 cm
        // under your middle; else every type but Visibility and Camera (v48's wide mask saw our own skater first and nothing else)
        int gt = -1;
        if (gtype >= 0 && gtype < 32) {
            RayHit h1; g_rayMask = 1 | (int32_t)(1u << gtype);
            if (Ray(c.world, c.P, sub(c.P, v3(0, 0, 300.0f)), h1) && h1.p.z <= c.P.z - 30.0f) { gt = gtype; g = h1; }
        }
        if (gt < 0) {
            float bestZ = -1e9f;
            for (int ty = 1; ty < 32; ty++) {
                if (ty == 3 || ty == 4) continue;        // trace channels, not object types
                RayHit h1; g_rayMask = (int32_t)(1u << ty);
                if (Ray(c.world, c.P, sub(c.P, v3(0, 0, 300.0f)), h1) && h1.p.z <= c.P.z - 30.0f && h1.p.z > bestZ) { bestZ = h1.p.z; gt = ty; g = h1; }
            }
        }
        if (gt >= 0) { g_rayMask = 1 | (int32_t)(1u << gt); Log("ledge scan: the ground under you is object type %d%s -- looking with that and the level (WorldStatic) only", gt, gt == gtype ? " (the floor the game stands you on)" : ""); }
        else {
            g_rayMask = 0x3ffff & ~((1 << 3) | (1 << 4));
            if (!Ray(c.world, c.P, sub(c.P, v3(0, 0, 300.0f)), g)) { g_rayMask = 1; snprintf(out, n, "none no ground under you (not as static, dynamic, physics or custom collision; the game's floor type %d)", gtype); return 0; }
            Log("ledge scan: the ground's own object type was not found -- looking with every type but Visibility and Camera");
        }
    }
ground_found:
    c.z0 = g.p.z;
    c.n0 = (g.n.z > 0.3f) ? g.n : v3(0, 0, 1);
    float bestR = 1e9f; int bestI = -1; float rr[24];
    float nearR = 1e9f; int nearI = -1;
    for (int i = 0; i < 24; i++) {
        const float a = (float)i * 15.0f * 0.0174532925f;
        rr[i] = EdgeAlong(c, v3(cosf(a), sinf(a), 0.0f), range);
        if (rr[i] <= 0.0f) continue;
        if (rr[i] < nearR) { nearR = rr[i]; nearI = i; }
        // (v49) the drop you FACE comes first (within the cone, half a step over for the 15 deg grid): on a dropped quarter
        // pipe's deck the back edge is the nearer one, and the nearest-of-all pick never gave the transition a look
        float off = fmodf((float)i * 15.0f - faceYaw, 360.0f);
        if (off < 0.0f) off += 360.0f;
        if (off > 180.0f) off = 360.0f - off;
        if (faceCone > 0.0f && off > faceCone + 7.5f) continue;
        if (rr[i] < bestR) { bestR = rr[i]; bestI = i; }
    }
    {
        char ring[240]; int p = 0;
        for (int i = 0; i < 24 && p < 200; i++) p += snprintf(ring + p, sizeof(ring) - p, (rr[i] > 0.0f) ? " %.0f" : " -", rr[i]);
        Log("ledge scan: facing %.0f deg (cone %.0f), the drop by direction (0, 15 .. 345 deg):%s -> %s%s", faceYaw, faceCone, ring,
            bestI >= 0 ? "the one you face" : (nearI >= 0 ? "none you face, the nearest" : "none"),
            (g_selfHits - selfBefore) > 0 ? " (some rays looked past our own skater or board)" : "");
    }
    if (bestI < 0) bestI = nearI;
    if (bestI < 0) { snprintf(out, n, "none no drop of %.0f cm within %.0f cm", c.minDrop, range); return 0; }
    auto at = [&](int i) { const float a = (float)i * 15.0f * 0.0174532925f; return add(c.P, v3(cosf(a) * rr[i], sinf(a) * rr[i], 0.0f)); };
    const int iL = (bestI + 23) % 24, iR = (bestI + 1) % 24;
    V3 o = norm(flat(sub(at(bestI), c.P)));
    if (rr[iL] > 0.0f && rr[iR] > 0.0f) {                // the edge's own line, from its neighbours
        const V3 t = norm(flat(sub(at(iR), at(iL))));
        V3 p = v3(t.y, -t.x, 0.0f);
        if (dot(p, o) < 0.0f) p = mul(p, -1.0f);
        if (dot(p, o) > 0.5f) o = p;
    }
    // (v91) SQUARE TO THE EDGE, HOWEVER YOU FACED IT. "When I was pretty far off from perpendicular it didn't fully align me --
    // it aligned me partly, so I bailed." The two bails of 4 Oct 19:45: facing 19 and 115 deg at an edge whose line stands
    // 65 deg, the look found the drop in ONE of its 15-deg directions inside your facing cone (45, and 90); the neighbour
    // on the far side of the cone had none within range, so the edge's line was never worked out and 'out' stayed the
    // direction of that one ray: out 0.7071 0.7071 and 0.0000 1.0000 where the same edge faced square gives 0.4189
    // 0.9080. The board was set 20 and 25 deg off square and the drop bailed 0.1-0.2 s in. Now the line is measured where
    // the look ends up: two rays 8 deg either side of 'out' (to the longer range), the edge between their two hits, 'out'
    // turned square to it -- three times over, each from the last answer.
    for (int it = 0; it < 3; it++) {
        const float a0 = atan2f(o.y, o.x);
        const V3 d1 = v3(cosf(a0 - 0.14f), sinf(a0 - 0.14f), 0.0f), d2 = v3(cosf(a0 + 0.14f), sinf(a0 + 0.14f), 0.0f);
        const float r1 = EdgeAlong(c, d1, range + 30.0f), r2 = EdgeAlong(c, d2, range + 30.0f);
        if (r1 <= 0.0f || r2 <= 0.0f) break;
        const V3 tl = flat(sub(mul(d2, r2), mul(d1, r1)));
        if (len(tl) < 1.0f) break;
        const V3 tn = norm(tl);
        V3 p = v3(tn.y, -tn.x, 0.0f);
        if (dot(p, o) < 0.0f) p = mul(p, -1.0f);
        const float turned = acosf(clampf(dot(p, o), -1.0f, 1.0f)) * 57.2957795f;
        if (turned > 70.0f) break;                        // another edge altogether: left as it was
        if (turned > 2.0f) Log("ledge scan: the edge's line stands %.0f deg from the way the look found it -- out turned square to it (%.0f -> %.0f deg)", turned, a0 * 57.2957795f, atan2f(p.y, p.x) * 57.2957795f);
        o = p;
        if (turned < 1.0f) break;
    }
    const float rE = EdgeAlong(c, o, range + 30.0f);
    if (rE <= 0.0f) { snprintf(out, n, "none the edge was lost on the second look"); return 0; }
    const V3 E = add(c.P, mul(o, rE));
    V3 nTop = v3(0, 0, 1);
    const float top6 = c.z0 - DropAt(c, E.x - o.x * 6.0f, E.y - o.y * 6.0f, &nTop);
    const float top14 = c.z0 - DropAt(c, E.x - o.x * 14.0f, E.y - o.y * 14.0f);
    const float top = (top14 > top6 - 20.0f) ? fminf(top6, top14) : top6;   // (v39: the ledge top proper, where the tail sits -- a coping stands UP on it)
    float lip = 0.0f;                                     // (v39) the lip: how far a coping stands up over the top just behind the edge
    for (float bk = 1.0f; bk <= 13.0f; bk += 3.0f) {
        RayHit hl;
        if (Ray(c.world, v3(E.x - o.x * bk, E.y - o.y * bk, top + 40.0f), v3(E.x - o.x * bk, E.y - o.y * bk, top - 5.0f), hl)) lip = fmaxf(lip, hl.p.z - top);
    }
    V3 nNear = v3(0, 0, 1), nFar = v3(0, 0, 1);
    const float dropNear = DropAt(c, E.x + o.x * 12.0f, E.y + o.y * 12.0f, &nNear) - (c.z0 - top);
    const float dropFar = DropAt(c, E.x + o.x * 45.0f, E.y + o.y * 45.0f, &nFar) - (c.z0 - top);
    // a board pivoting on the edge (its back wheels 4 cm behind it), nose going down: where the front wheels meet the ground
    const V3 Q = v3(E.x - o.x * 4.0f, E.y - o.y * 4.0f, top + 3.0f);
    const float R = 38.0f;
    float theta = -1.0f; V3 nc = v3(0, 0, 1);
    V3 prev = add(Q, mul(o, R));
    for (int i = 1; i <= 15 && theta < 0.0f; i++) {
        const float a = (float)i * 6.0f * 0.0174532925f;
        const V3 cur = add(Q, add(mul(o, R * cosf(a)), v3(0, 0, -R * sinf(a))));
        RayHit h;
        if (Ray(c.world, prev, cur, h)) {
            const V3 rel = sub(h.p, Q);
            theta = atan2f(-rel.z, fmaxf(dot(rel, o), 0.01f)) * 57.2957795f;
            nc = h.n;
        }
        prev = cur;
    }
    snprintf(out, n, "edge %.1f %.1f %.1f out %.4f %.4f dist %.1f top %.1f dropnear %.1f dropfar %.1f meet %.1f normal %.3f %.3f %.3f slope %.1f toptilt %.1f lip %.1f",
             E.x, E.y, top, o.x, o.y, rE, top, dropNear, dropFar, theta, nc.x, nc.y, nc.z,
             acosf(clampf(nFar.z, -1.0f, 1.0f)) * 57.2957795f, acosf(clampf(nTop.z, -1.0f, 1.0f)) * 57.2957795f, lip);
    return 1;
}
// (v56) THE GAME'S CATCH ORIENT, SET AS ITS OWN GRAB PICK WOULD. The v55 trace settled it: in the grabs whose tilt went
// nowhere the game's catch-orient state was 0 the whole grab (the deck sat 55-78 deg off the board bone -- the deck
// follows the bone only in that state), and writing the anim's copy did nothing (the game re-copies it every frame from
// ASkaterCharacterBase::_catchOrientState). InAirHandler::CheckForGrabs, when IT picks a grab with the state still 0,
// calls ASkaterCharacterBase::SetCatchOrient(handler->_defaultState (+0x32), pitchRatio (+0x90), yawRatio (+0x8c)); the
// mod's hand-over (ServerRPCSetGrab) skips that pick, so some grabs ran with no catch orient at all. So the Lua now
// asks for the same call when it hands a grab over (and again while the game holds it, should the state fall to 0).
constexpr uintptr_t RVA_SET_CATCH_ORIENT = 0x1004120;   // ASkaterCharacterBase::SetCatchOrient(ECatchOrientState, float, float)
constexpr int PC_INAIR = 0x6e0;                          // ASessionPlayerController -> InAirHandler* (InGame_Tick: mov rcx,[rdi+0x6e0])
constexpr int SK_CATCH_STATE = 0x63e;                    // ASkaterCharacterBase::_catchOrientState (reflected)
typedef void (*SetCatchFn)(void* skater, uint8_t state, float pitchRatio, float yawRatio);
LONG g_catchCalls = 0, g_catchLogs = 0;
// HJN_CatchOrient(fallback state) -> the skater's catch-orient state afterwards (-1 no skater, -2 fault)
int nCatchOrient(const Lua& lua) {
    double fb = 1, force = 0; ArgNum(lua, fb); ArgNum(lua, force);   // (v88) force: re-pick although a state is up
    int result = -1;
    if (!g_hooked) { lua.set_integer(-1); return 1; }               // (v101) another build of the game
    __try {
        uint8_t* sk = (uint8_t*)g_skater;
        if (sk && PtrOk(sk, 0x700)) {
            const int cur = sk[SK_CATCH_STATE];
            if (cur != 0 && (force == 0 || cur == (int)fb)) result = cur;
            else {
                uint8_t state = (uint8_t)clampf((float)fb, 1.0f, 4.0f); float pr = 0.0f, yr = 0.0f;
                const uint8_t* pc = (const uint8_t*)g_pc;
                if (pc && PtrOk(pc, 0x800)) {
                    const uint8_t* h = *(const uint8_t* const*)(pc + PC_INAIR);
                    if (h && PtrOk(h, 0x100)) {
                        if (h[0x32] != 0 && force == 0) state = h[0x32];
                        pr = *(const float*)(h + 0x90); yr = *(const float*)(h + 0x8c);
                        if (!std::isfinite(pr)) pr = 0.0f;
                        if (!std::isfinite(yr)) yr = 0.0f;
                    }
                }
                uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
                ((SetCatchFn)(exe + RVA_SET_CATCH_ORIENT))(sk, state, pr, yr);
                result = sk[SK_CATCH_STATE];
                InterlockedIncrement(&g_catchCalls);
                if (InterlockedIncrement(&g_catchLogs) <= 200)
                    Log("catch orient: %d at the grab -- SetCatchOrient(%d, %.2f, %.2f) %s -> %d", cur, state, pr, yr, cur ? "FORCED: a grab begun afresh over another" : "as the game's own pick would", result);
            }
        }
    } __except (GrabFilter(GetExceptionCode())) { Log("fault in the catch orient call"); result = -2; }
    lua.set_integer(result);
    return 1;
}
// (v57) HJN_CatchState() -> ASkaterCharacterBase::_catchOrientState as it is (0 = the game has no catch: the deck does not
// follow the board bone; the v56 log showed SetCatchOrient take and the game clear it again the next frame, every
// frame, in the grabs whose stick was pushed after the bumper -- in manual catch the state comes from the sticks, and
// the tweak gate was hiding them. So the Lua now lets the game see the sticks until it has its catch)
int nCatchState(const Lua& lua) {
    int r = -1;
    __try { const uint8_t* sk = (const uint8_t*)g_skater; if (sk && PtrOk(sk, 0x700)) r = sk[SK_CATCH_STATE]; }
    __except (GrabFilter(GetExceptionCode())) { r = -2; }
    lua.set_integer(r);
    return 1;
}
int SafeLedgeScan(float range, float minDrop, float faceYaw, float faceCone, int gtype, char* out, size_t n) {
    __try { return LedgeScan(range, minDrop, faceYaw, faceCone, gtype, out, n); }
    __except (GrabFilter(GetExceptionCode())) { snprintf(out, n, "none fault while looking"); Log("fault in the ledge scan"); return 0; }
}
// HJN_Ledge(range cm, least drop cm, [facing yaw deg, facing cone deg, the floor's object type or -1]) -> "edge x y z out ox oy dist d top z dropnear a dropfar b meet deg normal x y z slope deg toptilt deg"
// (world space; out = the horizontal way the drop faces) or "none <why>"
int nLedge(const Lua& lua) {
    double r = 60, d = 25, yaw = 0, cone = 0, gtype = -1;
    ArgNum(lua, r); ArgNum(lua, d); ArgNum(lua, yaw); ArgNum(lua, cone); ArgNum(lua, gtype);   // (v49) the facing; (v50) the floor's object type
    char b[400];
    const LONG before = g_rays;
    SafeLedgeScan((float)r, (float)d, (float)yaw, (float)cone, (int)gtype, b, sizeof(b));
    Log("ledge scan (%ld rays): %s", g_rays - before, b);
    lua.set_string(b);
    return 1;
}

// the board's parts (the deck first), held where the drop-in wants them
constexpr int kMaxParts = 10;
void* g_bpart[kMaxParts]; int g_bpartN = 0; Q4 g_bq[kMaxParts]; V3 g_bp[kMaxParts]; bool g_bcap = false;
// (v42) THE PARTS MUST STAY THE LIVE BOARD'S OWN COMPONENTS. The game destroys and respawns the board (a bail, a map
// change, v102's flung board), and an engine call on a dead component corrupts the object tables: the v102 session's
// crash was an access violation in UnhashObject during the garbage collection of the next map load. A freed block's
// first pointer (the vtable) is overwritten by the allocator, so each part's is checked, as is the skater's board itself.
void* g_bvt[kMaxParts]; void* g_bown = nullptr;
void* BoardActorNow() {
    uint8_t* sk = (uint8_t*)g_skater;
    if (!sk || !PtrOk(sk, 0x600)) return nullptr;
    return *(void**)(sk + SK_BOARD);
}
bool PartsOk(const char* what) {
    if (g_bpartN < 1) return false;
    void* bd = BoardActorNow();
    bool ok = bd != nullptr && bd == g_bown;
    for (int i = 0; ok && i < g_bpartN; i++) ok = PtrOk(g_bpart[i], 0x200) && *(void* const*)g_bpart[i] == g_bvt[i];
    if (!ok) {
        Log("board parts (%s): the board changed under the hold (%s) -- the parts are let go", what, (bd != g_bown) ? "the skater has another board" : "a part is gone");
        g_bpartN = 0; g_bcap = false;
    }
    return ok;
}
// HJN_BoardParts(address, ...) -> how many were taken (none = let go of them)
int nBoardParts(const Lua& lua) {
    g_bpartN = 0; g_bcap = false;
    double a = 0;
    while (g_bpartN < kMaxParts && ArgNum(lua, a)) {
        void* p = (a > 65536.0 && a < 1.8e19) ? (void*)(uintptr_t)a : nullptr;
        if (p && PtrOk(p, 0x200)) g_bpart[g_bpartN++] = p;
        a = 0;
    }
    for (int i = 0; i < g_bpartN; i++) g_bvt[i] = *(void* const*)g_bpart[i];   // (v42) what a live part's first word is
    g_bown = BoardActorNow();
    lua.set_integer(g_bpartN);
    return 1;
}
constexpr int BM_CTRLQUAT = 0x5c0;             // USkateboardExMovementComponent: the board controller's rotation (Set/GetBoardControllerQuat)
Q4 g_bctrl = { 0, 0, 0, 1 }; bool g_bctrlOk = false; bool g_baxleLogged = false; bool g_stanceLogged = false;
uint8_t* BoardMC() {
    uint8_t* sk = (uint8_t*)g_skater;
    if (!sk || !PtrOk(sk, 0x600)) return nullptr;
    uint8_t* bd = *(uint8_t**)(sk + SK_BOARD);
    if (!bd || !PtrOk(bd, 0x2a0)) return nullptr;
    uint8_t* bm = *(uint8_t**)(bd + BD_MOVE);
    return (bm && PtrOk(bm, 0x5d0)) ? bm : nullptr;
}
int BoardCapture() {
    if (!PartsOk("capture")) return 0;
    for (int i = 0; i < g_bpartN; i++) {
        if (!PtrOk(g_bpart[i], 0x200)) return 0;
        g_bq[i] = qnorm(*(const Q4*)((const uint8_t*)g_bpart[i] + SC_C2W));
        g_bp[i] = *(const V3*)((const uint8_t*)g_bpart[i] + SC_C2W + 0x10);
        if (!finite3(g_bp[i])) return 0;
    }
    g_bcap = g_bpartN > 0;
    g_baxleLogged = false; g_stanceLogged = false;
    g_bctrlOk = false;
    if (const uint8_t* bm = BoardMC()) {
        const Q4 c = *(const Q4*)(bm + BM_CTRLQUAT);
        const float l = c.x * c.x + c.y * c.y + c.z * c.z + c.w * c.w;
        if (std::isfinite(l) && fabsf(l - 1.0f) < 0.05f) { g_bctrl = qnorm(c); g_bctrlOk = true; }
    }
    return g_bcap ? g_bpartN : 0;
}
// the parts as captured, slid `slide` cm along out and pitched `pitch` deg (+ = the end over the drop UP); their
// velocities zeroed.
// (v38) THE PIVOT IS THE BACK AXLE, as the parts themselves show it. v36/v37 turned the board about a line on the
// ground a guessed 18 cm behind the deck's middle: at 12 deg that moved the back wheels half a cm and the game went on
// seeing them on the ground; at v99's 22 deg it took them off it -- the game switched to FALLING, and falling, ANY touch
// of the skater's legs or body on the world bails (ImpactBailCheck: the impulse needed is 10000 riding, 0 in the air):
// "it just throws him down before I even push forward". About the axle the back wheels only turn where they stand.
// ctrl: the game's board controller is given the same pitch (riding, it bails once the board is 55 deg off its
// controller: "Board dipped too far"), so the board can be pivoted down onto a ramp.
int BoardPlace(float slide, float pitch, V3 o, float zTop, float pivotBack, int ctrl) {
    if (!g_hooked || !g_bcap || g_bpartN < 1 || !PartsOk("hold")) return 0;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    o = norm(flat(o));
    const V3 k = cross(o, v3(0, 0, 1));
    V3 pivot0 = v3(g_bp[0].x - o.x * fmaxf(pivotBack, 0.0f), g_bp[0].y - o.y * fmaxf(pivotBack, 0.0f), zTop);
    int used = 0;
    if (pivotBack <= 0.0f) {
        V3 sum = v3(0, 0, 0);
        for (int i = 1; i < g_bpartN; i++) {
            const V3 r = sub(g_bp[i], g_bp[0]);
            const float al = dot(r, o);
            if (al < -8.0f && al > -40.0f && fabsf(r.z) < 15.0f) { sum = add(sum, g_bp[i]); used++; }
        }
        if (used > 0) pivot0 = mul(sum, 1.0f / (float)used);
        else pivot0 = v3(g_bp[0].x - o.x * 18.0f, g_bp[0].y - o.y * 18.0f, zTop + 2.7f);
    }
    if (!g_baxleLogged) {
        g_baxleLogged = true;
        const V3 r = sub(pivot0, g_bp[0]);
        Log("drop-in: the board pivots about %s: %.1f cm behind the deck's middle, %.1f cm over the ledge (the deck's middle %.1f over it); controller %s",
            (pivotBack <= 0.0f && used > 0) ? "its back axle (measured from its parts)" : "a set line", -dot(r, o), pivot0.z - zTop, g_bp[0].z - zTop,
            g_bctrlOk ? "read" : "NOT read");
    }
    const Q4 Rq = qaxis(k, pitch);
    const V3 zero = v3(0, 0, 0);
    int done = 0;
    for (int i = 0; i < g_bpartN; i++) {
        if (!PtrOk(g_bpart[i], 0x200)) continue;
        V3 loc = add(add(pivot0, mul(o, slide)), qrot(Rq, sub(g_bp[i], pivot0)));
        alignas(16) Q4 q = qnorm(qmul(Rq, g_bq[i]));
        if (!finite3(loc)) continue;
        ((SetXfFn)(exe + RVA_SET_WORLD_LOCROT))(g_bpart[i], &loc, &q, false, nullptr, 1 /* TeleportPhysics */);
        V3 v = zero;
        ((SetVelFn)(exe + RVA_SET_LINVEL))(g_bpart[i], &v, false, 0);
        v = zero;
        ((SetVelFn)(exe + RVA_SET_ANGVEL))(g_bpart[i], &v, false, 0);
        done++;
    }
    if (ctrl && g_bctrlOk && done > 0)
        if (uint8_t* bm = BoardMC()) *(Q4*)(bm + BM_CTRLQUAT) = qnorm(qmul(Rq, g_bctrl));
    return done;
}
// (v39) THE STANCE A SKATER SETS FOR A DROP-IN: the back wheels hung `hang` cm out PAST the edge, the tail down on the
// ledge (its tip `tail` cm behind the back axle, lifted `kick` cm off the deck's flat underside by the kick), the deck
// rising `pitch` deg from there over the edge. v38 turned the board about its back axle ON the ledge, 9 cm short of the
// edge: the wheels behind the coping, and the deck cut through the edge the moment it pivoted down. Now the board's own
// numbers set the pose -- the axles, the wheels and the deck's height are measured from the captured parts (all wheels
// down on the ledge), tail and kick come from the ini.
//   lip  how far a coping stands up over the ledge top (the deck must clear it: the pitch is raised as needed)
//   k    0 = the parts as captured .. 1 = the stance (the slide out and the rise, blended)
//   phi  the drop-in itself: the stance tipped nose-DOWN this many degrees about the back axle (the wheels stay hung)
struct BoardGeom { V3 axle, axleF; float wheelR, under, dB; int nB, nF; };
bool BoardGeomGet(V3 o, float zTop, BoardGeom& g) {
    if (!g_bcap || g_bpartN < 1) return false;
    const V3 lat = cross(v3(0, 0, 1), o);
    V3 sB = v3(0, 0, 0), sF = v3(0, 0, 0); g.nB = g.nF = 0;
    for (int i = 1; i < g_bpartN; i++) {
        const V3 r = sub(g_bp[i], g_bp[0]);
        const float al = dot(r, o);
        if (fabsf(r.z) > 15.0f || fabsf(al) > 40.0f || fabsf(dot(r, lat)) < 3.0f) continue;   // (the wheels: off the centre line)
        if (al < -8.0f) { sB = add(sB, g_bp[i]); g.nB++; } else if (al > 8.0f) { sF = add(sF, g_bp[i]); g.nF++; }
    }
    g.axle = g.nB > 0 ? mul(sB, 1.0f / (float)g.nB) : v3(g_bp[0].x - o.x * 22.7f, g_bp[0].y - o.y * 22.7f, g_bp[0].z - 3.1f);
    g.axleF = g.nF > 0 ? mul(sF, 1.0f / (float)g.nF) : v3(g_bp[0].x + o.x * 22.7f, g_bp[0].y + o.y * 22.7f, g_bp[0].z - 3.1f);
    g.wheelR = clampf(g.axle.z - zTop, 0.0f, 5.0f);             // (the wheel parts' origins sit at the TREAD: ~0 over the ledge as the board stands on it)
    g.under = g_bp[0].z - 0.5f;                                   // the deck's flat underside (its origin sits 3.1 over the axle)
    g.dB = fmaxf(g.under - g.axle.z, 0.5f);
    return true;
}
struct StancePose { V3 T0, T, A1; Q4 R1, R2, R; float pitch, along1, underE; BoardGeom g; };
// the pose for (k, phi); pitch may come out raised so the deck clears the lip. false = no captured board
bool StanceAt(float hang, float pitch, float tail, float kick, float lip, V3 o, V3 E, float zTop, float k, float phi, StancePose& s) {
    o = norm(flat(o));
    if (!BoardGeomGet(o, zTop, s.g)) return false;
    const V3 ax = cross(o, v3(0, 0, 1));                         // (+ = the nose up)
    k = clampf(k, 0.0f, 1.0f);
    tail = clampf(tail, 5.0f, 40.0f); kick = clampf(kick, 0.0f, 8.0f); lip = clampf(lip, 0.0f, 30.0f);
    // the deck must pass over the lip: the pitch is raised until its underside clears it by a cm at the edge
    float pu = clampf(pitch, 0.0f, 60.0f);
    for (int i = 0; i < 60; i++) {
        const float sn = sinf(pu * 0.0174532925f), cs = cosf(pu * 0.0174532925f);
        s.along1 = hang - tail * cs - s.g.dB * sn;                 // the tail's tip, this far past the edge (negative = behind)
        s.underE = -kick * cs + (0.0f - s.along1) * (sn / fmaxf(cs, 0.05f));   // the underside over the top, at the edge
        if (s.underE >= lip + 1.0f || s.along1 >= -1.0f || pu >= 60.0f) break;
        pu += 1.0f;
    }
    s.pitch = pu;
    const float cs = cosf(pu * 0.0174532925f);
    s.T0 = v3(s.g.axle.x - o.x * tail, s.g.axle.y - o.y * tail, s.g.under);                    // the tail's tip as captured
    const V3 T1 = v3(E.x + o.x * s.along1, E.y + o.y * s.along1, zTop - kick * cs);              // in the stance: down on the top
    s.T = lerp(s.T0, T1, k);
    s.R1 = qaxis(ax, pu * k);
    s.A1 = add(s.T, qrot(s.R1, sub(s.g.axle, s.T0)));                                           // the back axle, where it hangs
    s.R2 = qaxis(ax, -phi);
    s.R = qnorm(qmul(s.R2, s.R1));
    return true;
}
V3 StancePoint(const StancePose& s, V3 p) {                      // a point of the captured board, in the pose
    const V3 p1 = add(s.T, qrot(s.R1, sub(p, s.T0)));
    return add(s.A1, qrot(s.R2, sub(p1, s.A1)));
}
int BoardStance(float hang, float pitch, float tail, float kick, float lip, V3 o, V3 E, float zTop, float k, float phi, int ctrl) {
    if (!g_hooked || !g_bcap || g_bpartN < 1 || !PartsOk("hold")) return 0;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    StancePose s;
    if (!StanceAt(hang, pitch, tail, kick, lip, o, E, zTop, k, phi, s)) return 0;
    if (!g_stanceLogged) {
        g_stanceLogged = true;
        StancePose f;
        if (StanceAt(hang, pitch, tail, kick, lip, o, E, zTop, 1.0f, 0.0f, f)) {
            const V3 on = norm(flat(o));
            Log("drop-in: the board as captured: back axle %.1f cm behind the deck's middle (%d parts), front %.1f ahead (%d), the wheels' origins %.1f over the ledge (the tread), the deck's underside %.1f over them; "
                "the stance: pitch %.0f%s, the back axle %.1f cm past the edge, %.1f over the ledge top (the wheels' bottoms %+.1f), the deck %.1f over the top at the edge (lip %.1f), the tail's tip %.1f behind the edge; controller %s",
                -dot(sub(f.g.axle, g_bp[0]), on), f.g.nB, dot(sub(f.g.axleF, g_bp[0]), on), f.g.nF, f.g.wheelR, f.g.dB,
                f.pitch, (f.pitch > pitch + 0.5f) ? " (raised to clear the lip)" : "", dot(sub(f.A1, E), on), f.A1.z - zTop, f.A1.z - zTop - f.g.wheelR,
                f.underE, lip, -f.along1, g_bctrlOk ? "read" : "NOT read");
        }
    }
    const V3 zero = v3(0, 0, 0);
    int done = 0;
    for (int i = 0; i < g_bpartN; i++) {
        if (!PtrOk(g_bpart[i], 0x200)) continue;
        V3 loc = StancePoint(s, g_bp[i]);
        alignas(16) Q4 q = qnorm(qmul(s.R, g_bq[i]));
        if (!finite3(loc)) continue;
        ((SetXfFn)(exe + RVA_SET_WORLD_LOCROT))(g_bpart[i], &loc, &q, false, nullptr, 1 /* TeleportPhysics */);
        V3 v = zero;
        ((SetVelFn)(exe + RVA_SET_LINVEL))(g_bpart[i], &v, false, 0);
        v = zero;
        ((SetVelFn)(exe + RVA_SET_ANGVEL))(g_bpart[i], &v, false, 0);
        done++;
    }
    if (ctrl && g_bctrlOk && done > 0)
        if (uint8_t* bm = BoardMC()) *(Q4*)(bm + BM_CTRLQUAT) = qnorm(qmul(s.R, g_bctrl));
    return done;
}
// (v39) THE DROP-IN'S END: from the stance, how far the board may tip nose-down about its hung back axle before its front
// wheels (or its nose) meet the ground -- the wheels' bottoms and the nose traced along their arcs, a degree at a time.
// (v38 took the angle from chords of a guessed circle: 56 deg on a bank that took 40, the wheels 10 cm into the ramp and
// the board stuck fast.) -1 = nothing to meet within maxPhi (a straight drop). *pitchOut = the stance's pitch as used.
float BoardMeet(float hang, float pitch, float tail, float kick, float lip, V3 o, V3 E, float zTop, float maxPhi, float* pitchOut, float* slopeOut) {
    if (!g_hooked || !g_skater || !PtrOk(g_skater, 0x140)) return -1.0f;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    const void* world = SkaterWorld();
    if (!world) return -1.0f;
    StancePose s;
    if (!StanceAt(hang, pitch, tail, kick, lip, o, E, zTop, 1.0f, 0.0f, s)) return -1.0f;
    if (pitchOut) *pitchOut = s.pitch;
    const V3 on = norm(flat(o)), lat = cross(v3(0, 0, 1), on);
    // the points: the front wheels' centres (their bottoms a wheel's radius down the board's up) and the nose's tip
    V3 pts[8]; float down[8]; const char* names[8]; int np = 0;
    for (int i = 1; i < g_bpartN && np < 6; i++) {
        const V3 r = sub(g_bp[i], g_bp[0]);
        if (fabsf(r.z) > 15.0f || dot(r, on) < 8.0f || dot(r, on) > 40.0f || fabsf(dot(r, lat)) < 3.0f) continue;
        pts[np] = g_bp[i]; down[np] = s.g.wheelR; names[np] = "a front wheel"; np++;
    }
    pts[np] = v3(s.g.axleF.x + on.x * (tail + 1.0f), s.g.axleF.y + on.y * (tail + 1.0f), s.g.under + kick); down[np] = 0.0f; names[np] = "the nose"; np++;
    const LONG before = g_rays;
    float meet = -1.0f, depthAt = 0.0f, slopeAt = 0.0f; const char* what = "";
    V3 prev[8];
    for (int j = 0; j < np; j++) prev[j] = add(StancePoint(s, pts[j]), qrot(s.R, v3(0, 0, -down[j])));
    maxPhi = clampf(maxPhi, 5.0f, 150.0f);
    for (float phi = 1.0f; phi <= maxPhi + 0.5f && meet < 0.0f; phi += 1.0f) {
        StancePose t;
        if (!StanceAt(hang, pitch, tail, kick, lip, o, E, zTop, 1.0f, phi, t)) break;
        for (int j = 0; j < np; j++) {
            const V3 cur = add(StancePoint(t, pts[j]), qrot(t.R, v3(0, 0, -down[j])));
            RayHit h;
            if (meet < 0.0f && Ray(world, prev[j], cur, h)) { meet = fmaxf(phi - 2.0f, 0.0f); what = names[j]; depthAt = zTop - h.p.z; slopeAt = acosf(clampf(h.n.z, -1.0f, 1.0f)) * 57.2957795f; }
            prev[j] = cur;
        }
    }
    if (slopeOut) *slopeOut = slopeAt;
    if (meet >= 0.0f)
        Log("drop-in: the way down traced (%ld rays): %s meets the ground %.1f cm below the ledge top (%.0f deg steep there) once the board has tipped %.0f deg from the stance (%.0f deg below level); it will stop a degree short, at %.0f",
            g_rays - before, what, depthAt, slopeAt, meet + 2.0f, meet + 2.0f - s.pitch, meet);
    else
        Log("drop-in: the way down traced (%ld rays): nothing met within %.0f deg -- a straight drop", g_rays - before, maxPhi);
    return meet;
}
// (v37) let go WITH a motion: every part gets the velocity and, turning as one about the deck's middle, a spin that
// takes the end over the drop DOWN (spin deg/s; o = the way the drop faces)
int BoardKick(V3 vel, float spin, V3 o) {
    if (!g_hooked || g_bpartN < 1 || !finite3(vel) || !std::isfinite(spin) || !PartsOk("kick")) return 0;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    o = norm(flat(o));
    const V3 w = mul(cross(o, v3(0, 0, 1)), -spin * 0.0174532925f);      // (about o x Z, + lifts that end)
    if (!PtrOk(g_bpart[0], 0x200)) return 0;
    const V3 c = *(const V3*)((const uint8_t*)g_bpart[0] + SC_C2W + 0x10);
    int done = 0;
    for (int i = 0; i < g_bpartN; i++) {
        if (!PtrOk(g_bpart[i], 0x200)) continue;
        const V3 p = *(const V3*)((const uint8_t*)g_bpart[i] + SC_C2W + 0x10);
        V3 v = add(vel, cross(w, sub(p, c)));
        if (!finite3(v)) continue;
        ((SetVelFn)(exe + RVA_SET_LINVEL))(g_bpart[i], &v, false, 0);
        V3 a = w;
        ((SetVelFn)(exe + RVA_SET_ANGVEL))(g_bpart[i], &a, false, 0);
        done++;
    }
    return done;
}
// (v37) the parts put down as one, the deck at p, level, its long axis along yaw (wherever and however they lay)
int BoardPut(V3 p, float yaw) {
    if (!g_hooked || g_bpartN < 1 || !finite3(p) || !std::isfinite(yaw) || !PartsOk("put")) return 0;
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    if (!PtrOk(g_bpart[0], 0x200)) return 0;
    const Q4 q0 = qnorm(*(const Q4*)((const uint8_t*)g_bpart[0] + SC_C2W));
    const V3 p0 = *(const V3*)((const uint8_t*)g_bpart[0] + SC_C2W + 0x10);
    const Q4 qn = qaxis(v3(0, 0, 1), yaw);
    const Q4 turn = qnorm(qmul(qn, qconj(q0)));
    V3 np[kMaxParts]; Q4 nq[kMaxParts]; bool ok[kMaxParts];
    for (int i = 0; i < g_bpartN; i++) {
        ok[i] = PtrOk(g_bpart[i], 0x200);
        if (!ok[i]) continue;
        const Q4 qi = qnorm(*(const Q4*)((const uint8_t*)g_bpart[i] + SC_C2W));
        const V3 pi = *(const V3*)((const uint8_t*)g_bpart[i] + SC_C2W + 0x10);
        np[i] = add(p, qrot(turn, sub(pi, p0)));
        nq[i] = qnorm(qmul(turn, qi));
        if (!finite3(np[i]) || len(sub(pi, p0)) > 120.0f) ok[i] = false;     // (a part that far from the deck is not this board's)
    }
    const V3 zero = v3(0, 0, 0);
    int done = 0;
    for (int i = 0; i < g_bpartN; i++) {
        if (!ok[i]) continue;
        V3 loc = np[i];
        alignas(16) Q4 q = nq[i];
        ((SetXfFn)(exe + RVA_SET_WORLD_LOCROT))(g_bpart[i], &loc, &q, false, nullptr, 1);
        V3 v = zero;
        ((SetVelFn)(exe + RVA_SET_LINVEL))(g_bpart[i], &v, false, 0);
        v = zero;
        ((SetVelFn)(exe + RVA_SET_ANGVEL))(g_bpart[i], &v, false, 0);
        done++;
    }
    return done;
}
int SafeBoardCapture() { __try { return BoardCapture(); } __except (GrabFilter(GetExceptionCode())) { g_bcap = false; g_bpartN = 0; Log("fault capturing the board's parts"); return 0; } }
int SafeBoardPlace(float s, float p, V3 o, float z, float b, int c) {
    __try { return BoardPlace(s, p, o, z, b, c); }
    __except (GrabFilter(GetExceptionCode())) { g_bcap = false; g_bpartN = 0; Log("fault holding the board -- let go"); return 0; }
}
int SafeBoardKick(V3 v, float spin, V3 o) { __try { return BoardKick(v, spin, o); } __except (GrabFilter(GetExceptionCode())) { g_bpartN = 0; Log("fault kicking the board"); return 0; } }
// HJN_BoardCapture() -> parts captured as they stand now
int nBoardCapture(const Lua& lua) { lua.set_integer(SafeBoardCapture()); return 1; }
// HJN_BoardPlace(slide, pitch, outX, outY, topZ, pivotBack (0 = the back axle as measured), controller 0/1) -> parts placed
int nBoardPlace(const Lua& lua) {
    double s = 0, p = 0, ox = 1, oy = 0, z = 0, b = 0, c = 0;
    ArgNum(lua, s); ArgNum(lua, p); ArgNum(lua, ox); ArgNum(lua, oy); ArgNum(lua, z); ArgNum(lua, b); ArgNum(lua, c);
    lua.set_integer(SafeBoardPlace((float)s, clampf((float)p, -89.0f, 60.0f), v3((float)ox, (float)oy, 0.0f), (float)z, (float)b, c != 0 ? 1 : 0));
    return 1;
}
// HJN_BoardKick(vx, vy, vz, spin, outX, outY) -> parts given that velocity (cm/s, world) and spin (deg/s, the end over the drop going down)
int nBoardKick(const Lua& lua) {
    double x = 0, y = 0, z = 0, s = 0, ox = 1, oy = 0;
    ArgNum(lua, x); ArgNum(lua, y); ArgNum(lua, z); ArgNum(lua, s); ArgNum(lua, ox); ArgNum(lua, oy);
    lua.set_integer(SafeBoardKick(v3((float)x, (float)y, (float)z), clampf((float)s, -720.0f, 720.0f), v3((float)ox, (float)oy, 0.0f)));
    return 1;
}
int SafeBoardPut(V3 p, float yaw) { __try { return BoardPut(p, yaw); } __except (GrabFilter(GetExceptionCode())) { g_bpartN = 0; Log("fault putting the board down"); return 0; } }
// HJN_BoardPut(x, y, z, yaw) -> parts moved: the board set down level at that spot, heading yaw
int nBoardPut(const Lua& lua) {
    double x = 0, y = 0, z = 0, w = 0;
    ArgNum(lua, x); ArgNum(lua, y); ArgNum(lua, z); ArgNum(lua, w);
    lua.set_integer(SafeBoardPut(v3((float)x, (float)y, (float)z), (float)w));
    return 1;
}

int SafeBoardStance(float hang, float pitch, float tail, float kick, float lip, V3 o, V3 E, float z, float k, float phi, int c) {
    __try { return BoardStance(hang, pitch, tail, kick, lip, o, E, z, k, phi, c); }
    __except (GrabFilter(GetExceptionCode())) { g_bcap = false; g_bpartN = 0; Log("fault holding the board in the stance -- let go"); return 0; }
}
float SafeBoardMeet(float hang, float pitch, float tail, float kick, float lip, V3 o, V3 E, float z, float maxPhi, float* pu, float* sl) {
    __try { return BoardMeet(hang, pitch, tail, kick, lip, o, E, z, maxPhi, pu, sl); }
    __except (GrabFilter(GetExceptionCode())) { Log("fault tracing the way down"); return -1.0f; }
}
// HJN_BoardStance(hang, pitch, tail, kick, lip, outX, outY, edgeX, edgeY, topZ, k 0..1, phi (deg nose-down from the stance), controller 0/1)
// -> parts placed
int nBoardStance(const Lua& lua) {
    double a[13] = { 4, 25, 17, 2.5, 0, 1, 0, 0, 0, 0, 1, 0, 0 };
    for (int i = 0; i < 13; i++) ArgNum(lua, a[i]);
    lua.set_integer(SafeBoardStance((float)a[0], (float)a[1], (float)a[2], (float)a[3], (float)a[4], v3((float)a[5], (float)a[6], 0.0f),
                                    v3((float)a[7], (float)a[8], (float)a[9]), (float)a[9], (float)a[10], clampf((float)a[11], -30.0f, 150.0f), a[12] != 0 ? 1 : 0));
    return 1;
}
// HJN_BoardMeet(hang, pitch, tail, kick, lip, outX, outY, edgeX, edgeY, topZ, maxPhi) -> the nose-down turn from the stance at
// which the front wheels meet the ground (-1 = nothing within maxPhi), and the stance's pitch as used
int nBoardMeet(const Lua& lua) {
    double a[11] = { 4, 25, 17, 2.5, 0, 1, 0, 0, 0, 0, 105 };
    for (int i = 0; i < 11; i++) ArgNum(lua, a[i]);
    float pu = (float)a[1], sl = 0.0f;
    const float m = SafeBoardMeet((float)a[0], (float)a[1], (float)a[2], (float)a[3], (float)a[4], v3((float)a[5], (float)a[6], 0.0f),
                                  v3((float)a[7], (float)a[8], (float)a[9]), (float)a[9], (float)a[10], &pu, &sl);
    lua.set_number((double)m);
    lua.set_number((double)pu);
    lua.set_number((double)sl);
    return 3;
}

// (v40) THE GAME'S "GROUNDED" WHILE THE DROP-IN HOLDS THE BOARD. PostPhysSkateboarding asks IsGrounded through the board
// movement interface's vtable (slot 0x3b0; an OR over the wheels, the trucks and the deck's tail) and, told no, goes to
// Falling (SetMovementMode 3) -- and falling, any touch of the skater's legs on the world bails. With the back wheels
// hung out past the edge only the tail is down, and on a coping the game did not count it (v101: riding/air flicker and
// the bail on the quarter; the bank held only because its face lay within reach under the hung wheels). So while the
// board is held the slot answers "grounded" for this board's interface; every other object gets the game's own answer.
// The vtable lives in the exe's read-only data: unprotected for the one write, and left hooked (a passthrough) after.
constexpr uintptr_t RVA_ISGROUNDED = 0xfc36e0;
constexpr int BM_IFACE = 0x138, VT_ISGROUNDED = 0x3b0;
typedef bool (*IsGroundedFn)(void* iface);
IsGroundedFn g_isGroundedOrig = nullptr; volatile int g_groundHold = 0; void* g_groundIface = nullptr; LONG g_groundForced = 0;
bool HookIsGrounded(void* iface) {
    if (g_groundHold && iface == g_groundIface) { InterlockedIncrement(&g_groundForced); return true; }
    return g_isGroundedOrig ? g_isGroundedOrig(iface) : false;
}
int GroundHold(int on) {
    uint8_t* bm = BoardMC();
    if (!bm || !g_hooked) { g_groundHold = 0; return 0; }
    void* iface = bm + BM_IFACE;
    void** vt = *(void***)iface;
    if (!PtrOk(vt, VT_ISGROUNDED + 8)) { g_groundHold = 0; return 0; }
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    void** slot = vt + VT_ISGROUNDED / 8;
    if (on) {
        if (*slot != (void*)&HookIsGrounded) {
            if (*slot != (void*)(exe + RVA_ISGROUNDED)) { Log("ground hold: the IsGrounded slot holds something else (%p) -- not touched", *slot); g_groundHold = 0; return 0; }
            DWORD old = 0;
            if (!VirtualProtect(slot, sizeof(void*), PAGE_READWRITE, &old)) { Log("ground hold: the vtable could not be unprotected"); g_groundHold = 0; return 0; }
            g_isGroundedOrig = (IsGroundedFn)*slot;
            *slot = (void*)&HookIsGrounded;
            DWORD tmp = 0;
            VirtualProtect(slot, sizeof(void*), old, &tmp);
            Log("ground hold: IsGrounded (the board interface's vtable slot 0x%x) hooked; it answers for the held board only", VT_ISGROUNDED);
        }
        g_groundIface = iface; g_groundForced = 0; g_groundHold = 1;
        return 1;
    }
    const LONG n = g_groundForced;
    g_groundHold = 0;
    return (int)n;
}
int SafeGroundHold(int on) { __try { return GroundHold(on); } __except (GrabFilter(GetExceptionCode())) { g_groundHold = 0; Log("fault in the ground hold"); return 0; } }
// HJN_GroundHold(1) -> 1 while the game is told the held board is grounded; HJN_GroundHold(0) -> how many times it was told
int nGroundHold(const Lua& lua) {
    double on = 0;
    ArgNum(lua, on);
    lua.set_integer(SafeGroundHold(on != 0 ? 1 : 0));
    return 1;
}

// ==== (v43) THE IN-GAME SETTINGS PAGES =================================================================
// "Expanded Trick Settings" in the GAME'S OWN pause menu. Stage 1 rides SessionOpenMP's pause-menu seam
// (menu_ext.h in its source: a C ABI its main.dll exports, OmpMenu_RegisterPage2, that fills the game's
// native UMG menu with the rows a guest declares -- the same way SessionTweaks gets its pages). With no
// such host loaded the rows are never shown and the ini stays the way to set things. Stage 2 is a host
// of our own (a port of that injection), so that no other mod is needed; the rows below stay as they are.
// The rows come from the Lua half (HJN_MenuPage / HJN_MenuRow), which owns the ini: what a row shows
// is what HJN_MenuValue last said, what the player changes goes into a queue the Lua drains each
// second (HJN_MenuTake) and writes to the ini. The host calls back on the GAME thread, inside SEH.
#include <psapi.h>
#pragma comment(lib, "psapi.lib")
enum { MENU_ACTION = 0, MENU_TOGGLE = 1, MENU_SLIDER = 2, MENU_PAGE = 3 };
struct OmpPageItem2 { int kind; const char* key; const char* label; const char* desc; const char* offLabel; const char* onLabel; float minValue, maxValue, step; };
typedef void (*OmpPageSelectFn)(const char* key, void* user);
typedef void (*OmpPageValueFn)(const char* key, int intValue, float floatValue, void* user);
typedef int  (*OmpPageGetFn)(const char* key, int* outInt, float* outFloat, void* user);
typedef const char* (*OmpPageStatusFn)(const char* key, void* user);
typedef int (*OmpRegisterPage2Fn)(const char* title, const OmpPageItem2* items, int nItems, OmpPageSelectFn onSelect,
                                  OmpPageValueFn onValue, OmpPageGetFn onGet, OmpPageStatusFn onStatus, void* user);
constexpr int MENU_PAGES = 8, MENU_ROWS = 48, MENU_VALS = 256;
struct MenuRow { int kind; char key[48], label[64], desc[400], off[24], on[24]; float lo, hi, step; };   // (v100: the description 240 -> 400)
struct MenuPage { char title[64]; MenuRow row[MENU_ROWS]; OmpPageItem2 item[MENU_ROWS]; int n; };
MenuPage g_mpage[MENU_PAGES]; int g_mpageN = 0;
struct MenuVal { char key[48]; float v; }; MenuVal g_mval[MENU_VALS]; int g_mvalN = 0;
char g_mqueue[4096] = { 0 }; CRITICAL_SECTION g_mlock; bool g_mlockOk = false;
int g_mreg = 0, g_mtries = 0;
volatile int g_menuOwn = 0;                    // (v60) HJN_Set("menuown", 1): our own pages even when SessionOpenMP's seam is loaded (its menu is off in mods.txt)
void MenuLock() { if (!g_mlockOk) { InitializeCriticalSection(&g_mlock); g_mlockOk = true; } EnterCriticalSection(&g_mlock); }
void MenuUnlock() { LeaveCriticalSection(&g_mlock); }
MenuVal* MenuFind(const char* key) { for (int i = 0; i < g_mvalN; i++) if (strcmp(g_mval[i].key, key) == 0) return &g_mval[i]; return nullptr; }
int MenuKind(const char* key) {
    for (int p = 0; p < g_mpageN; p++) for (int r = 0; r < g_mpage[p].n; r++) if (strcmp(g_mpage[p].row[r].key, key) == 0) return g_mpage[p].row[r].kind;
    return -1;
}
void MenuOnValue(const char* key, int iv, float fv, void*) {
    if (!key || !key[0]) return;
    const int kind = MenuKind(key);
    const float v = (kind == MENU_TOGGLE) ? (float)iv : fv;
    if (!std::isfinite(v)) return;
    char one[96]; snprintf(one, sizeof(one), "%s=%.4g;", key, v);
    MenuLock();
    if (strlen(g_mqueue) + strlen(one) < sizeof(g_mqueue) - 1) strcat(g_mqueue, one);
    MenuUnlock();
    if (MenuVal* m = MenuFind(key)) m->v = v;        // (the row shows what was set until the Lua confirms it)
    Log("menu: %s -> %.4g", key, v);
}
int MenuOnGet(const char* key, int* oi, float* of, void*) {
    MenuVal* m = (key && key[0]) ? MenuFind(key) : nullptr;
    if (!m) return 0;
    if (oi) *oi = (int)(m->v + (m->v >= 0.0f ? 0.5f : -0.5f));
    if (of) *of = m->v;
    return 1;
}
bool PageIsSub(int idx);                        // (the host block, below)
OmpRegisterPage2Fn g_seamReg = nullptr;         // (v66) SessionOpenMP's seam when it is loaded: the fall-back for our own pages
int MenuRegisterFlat();
int MenuRegister() {
    if (g_mreg != 0) return g_mreg;
    if (g_mpageN < 1) return 0;
    OmpRegisterPage2Fn reg = nullptr;                 // the host: whichever loaded module exports the seam
    HMODULE mods[512]; DWORD need = 0;
    if (EnumProcessModules(GetCurrentProcess(), mods, sizeof(mods), &need)) {
        const int n = (int)((need / sizeof(HMODULE)) < 512 ? (need / sizeof(HMODULE)) : 512);
        for (int i = 0; i < n && !reg; i++) reg = (OmpRegisterPage2Fn)GetProcAddress(mods[i], "OmpMenu_RegisterPage2");
    }
    g_seamReg = reg;
    if (g_menuOwn) {                                  // (v66) MenuOwnPages=1 (the default): our own NESTED pages, with or without SessionOpenMP
        g_host = 1; g_mreg = 2;
        Log("menu: our own nested pause-menu pages%s", reg ? " (SessionOpenMP's menu is loaded too: ours go in front of its hooks; its one flat page is the fall-back)" : "");
        return g_mreg;
    }
    if (!reg) {
        if (++g_mtries < 3) return 0;                    // (mods.txt order decides who loads first; three looks a second apart is plenty)
        g_host = 1; g_mreg = 2;                           // (v44) no SessionOpenMP: our own host, installed on the game thread's next frame
        Log("menu: no SessionOpenMP menu host loaded -- our own pause-menu pages will be used");
        return g_mreg;
    }
    return MenuRegisterFlat();
}
// (v66) the one flat page through SessionOpenMP's seam: what MenuOwnPages=0 asks for, and the fall-back when our own nested
// pages cannot be placed
int MenuRegisterFlat() {
    OmpRegisterPage2Fn reg = g_seamReg;
    if (!reg) { g_mreg = -1; return g_mreg; }
    // (v45) ONE page through the seam. SessionOpenMP's page table holds 16 and SessionTweaks takes 15 of them, so the
    // nested layout (four pages) cannot be had there: every toggle and slider goes on one flat page, 14 rows at most
    // (what the panel is laid out for), each key once. The nested pages are our own host's, with no other mod loaded.
    static OmpPageItem2 flat[MENU_ROWS]; int n = 0; const char* title = "Expanded Tricks";
    int mainIdx = -1;
    for (int p = 0; p < g_mpageN && mainIdx < 0; p++) if (!PageIsSub(p)) mainIdx = p;
    if (mainIdx >= 0) title = g_mpage[mainIdx].title;
    for (int p = 0; p < g_mpageN; p++) {
        if (p == mainIdx) continue;
        for (int r = 0; r < g_mpage[p].n && n < 14; r++) {
            const MenuRow& w = g_mpage[p].row[r];
            if (w.kind != MENU_TOGGLE && w.kind != MENU_SLIDER) continue;
            bool dup = false;
            for (int i = 0; i < n; i++) if (strcmp(flat[i].key, w.key) == 0) dup = true;
            if (dup) continue;
            OmpPageItem2 it = { w.kind, w.key, w.label, w.desc[0] ? w.desc : nullptr, w.off[0] ? w.off : nullptr, w.on[0] ? w.on : nullptr, w.lo, w.hi, w.step };
            flat[n++] = it;
        }
    }
    if (n < 1) { g_mreg = -1; return g_mreg; }
    const int ok = reg(title, flat, n, nullptr, &MenuOnValue, &MenuOnGet, nullptr, nullptr);
    g_mreg = ok ? 1 : -1;
    if (ok) Log("menu: one flat page \"%s\" of %d rows registered with SessionOpenMP's menu (its page table has room for one of ours; the nested pages are the mod's own host's)", title, n);
    else Log("menu: SessionOpenMP's menu refused the page \"%s\" (%d rows): its page table is full -- the settings stay in the ini", title, n);
    return g_mreg;
}
void CopyStr(char* dst, size_t cap, const std::string& s) { snprintf(dst, cap, "%s", s.c_str()); }
// HJN_MenuPage(title) -> the page's number (rows added after this go to it); "" = forget every page (a reload)
int nMenuPage(const Lua& lua) {
    std::string t; ArgStr(lua, t);
    if (t.empty()) { g_mpageN = 0; g_mvalN = 0; lua.set_integer(0); return 1; }
    if (g_mreg == 1 || g_mpageN >= MENU_PAGES) { lua.set_integer(0); return 1; }
    MenuPage& pg = g_mpage[g_mpageN++];
    memset(&pg, 0, sizeof(pg));
    CopyStr(pg.title, sizeof(pg.title), t);
    lua.set_integer(g_mpageN);
    return 1;
}
// HJN_MenuRow(kind 1 toggle / 2 slider / 3 page, key, label, description, min, max, step, off label, on label) -> rows on the page
int nMenuRow(const Lua& lua) {
    double kind = 0, lo = 0, hi = 1, step = 1; std::string key, label, desc, off, on;
    ArgNum(lua, kind); ArgStr(lua, key); ArgStr(lua, label); ArgStr(lua, desc); ArgNum(lua, lo); ArgNum(lua, hi); ArgNum(lua, step); ArgStr(lua, off); ArgStr(lua, on);
    if (g_mreg == 1 || g_mpageN < 1 || key.empty()) { lua.set_integer(0); return 1; }
    MenuPage& pg = g_mpage[g_mpageN - 1];
    if (pg.n >= MENU_ROWS) { lua.set_integer(pg.n); return 1; }
    MenuRow& w = pg.row[pg.n++];
    memset(&w, 0, sizeof(w));
    w.kind = (int)kind; CopyStr(w.key, sizeof(w.key), key); CopyStr(w.label, sizeof(w.label), label.empty() ? key : label);
    CopyStr(w.desc, sizeof(w.desc), desc); CopyStr(w.off, sizeof(w.off), off); CopyStr(w.on, sizeof(w.on), on);
    w.lo = (float)lo; w.hi = (float)hi; w.step = (float)step;
    lua.set_integer(pg.n);
    return 1;
}
// HJN_MenuValue(key, value) -> 1: what the row shows (in the row's own units)
int nMenuValue(const Lua& lua) {
    std::string key; double v = 0;
    ArgStr(lua, key); ArgNum(lua, v);
    if (key.empty() || !std::isfinite(v)) { lua.set_integer(0); return 1; }
    MenuVal* m = MenuFind(key.c_str());
    if (!m) { if (g_mvalN >= MENU_VALS) { lua.set_integer(0); return 1; } m = &g_mval[g_mvalN++]; CopyStr(m->key, sizeof(m->key), key); }
    m->v = (float)v;
    lua.set_integer(1);
    return 1;
}
int SafeMenuRegister() { __try { return MenuRegister(); } __except (GrabFilter(GetExceptionCode())) { g_mreg = -1; Log("fault registering the menu pages -- the settings stay in the ini"); return -1; } }
// HJN_MenuRegister() -> 1 the pages are in the pause menu, 0 no host yet (ask again later), -1 no host (given up)
int nMenuRegister(const Lua& lua) { lua.set_integer(SafeMenuRegister()); return 1; }
// HJN_MenuTake() -> "key=value;key=value;..." the player's changes since the last call (in the rows' units)
int nMenuTake(const Lua& lua) {
    char out[sizeof(g_mqueue)];
    MenuLock();
    snprintf(out, sizeof(out), "%s", g_mqueue);
    g_mqueue[0] = 0;
    MenuUnlock();
    lua.set_string(out);
    return 1;
}

// ==== (v44) OUR OWN PAUSE-MENU HOST =====================================================================
// Stage 2: "Expanded Tricks" in the game's pause menu with no other mod loaded. The design and every measured
// fact below are SessionOpenMP's (src/ui/pause_menu.cpp and game_syms.h, GPLv3, matsix), cut down to what a
// settings page needs; where its code is used, the licence follows it.
//   * Session's menus are data: a UMenuPageDefinition holds a TArray<FMenuPageItemDefinition> (144 B each) and
//     UMenuPage::CreatePageItems turns that array into one row widget each. The hook hands it a DIFFERENT array,
//     one we own and never free -- so the engine never destructs anything of ours.
//   * Our sub-pages are FAKE: the engine's page stays the pause root; we swap the rows it builds from and set the
//     title. A swap is QUEUED and run a frame later from the engine tick (never inside the confirm callback, whose
//     caller is still walking the row widgets), and the engine tick runs paused or not.
//   * Rows are known by their FName key. Toggles are the game's MultiOption row, sliders its ProgressBar row; their
//     values are stamped onto the WIDGETS after each rebuild (the definition's copy does not survive the rebuild).
//   * An FText is a refcounted handle: built once from an FName (FText::FromName), copied bitwise into our rows and
//     never destructed; the one handed BY VALUE to SetTitle gets its refcount bumped first (the callee releases it).
//   * A zeroed FText is a null pointer with a crash attached: every text field of a row gets a real one.
// HOOKS. No hooking library in this tree, so a detour of our own: the target's first N bytes -- chosen by hand from
// the disassembly so that no relative instruction is displaced, and checked against the bytes found -- go to a
// trampoline followed by a jump back, and the target gets `jmp [rip+0]; <hook>` in their place. Two of the targets
// are 32-byte funnels with a branch in their first bytes, so the hook RE-IMPLEMENTS them (test a flag, stamp the
// page definition into the params, broadcast the delegate) instead of trampolining. Installed on the game thread.
constexpr uintptr_t RVA_MENU_CREATEITEMS = 0x1071150;   // UMenuPage::CreatePageItems(this, const TArray<FMenuPageItemDefinition>&, bool)
constexpr uintptr_t RVA_MENU_SELCONFIRM  = 0x1090c80;   // UMenuPage::OnSelectionConfirmed(this, params&)        -- re-implemented
constexpr uintptr_t RVA_MENU_BACKACTION  = 0x1076df0;   // UMenuPageContainer::HandlePageBackAction(this, params)
constexpr uintptr_t RVA_MENU_MULTICHG    = 0x10822e0;   // UMenuPage::OnMultiOptionItemSelectionChanged(this, params&)
constexpr uintptr_t RVA_MENU_PROGCHG     = 0x1090c50;   // UMenuPage::OnProgressBarValueChanged(this, params&)    -- re-implemented
constexpr uintptr_t RVA_MENU_REFRESH     = 0x1096b70;   // UMenuPage::RefreshItemsPanel(this)
constexpr uintptr_t RVA_MENU_SETTITLE    = 0x109ab60;   // UMenuPage::SetTitle(this, FText by value)
constexpr uintptr_t RVA_MENU_SETSEL      = 0x1099eb0;   // UMenuPage::SetSelectedIndex(this, int, bool)
constexpr uintptr_t RVA_ITEM_PROGSET     = 0x1096330;   // UMenuPageItem::ProgressBarSetPercent(this, float 0..1)
constexpr uintptr_t RVA_ITEM_MULTISET    = 0x1078e80;   // UMenuPageItem::MultiOptionSetSelectedItemIndex(this, int)
constexpr uintptr_t RVA_DELEGATE_BCAST   = 0x7e5920;    // TMulticastDelegate<void(Params&)>::Broadcast(this, params&) -- the funnels' tail call
constexpr uintptr_t RVA_FNAME_CTOR_A     = 0x132d4e0;   // FName::FName(const char*, EFindName)
constexpr uintptr_t RVA_FTEXT_FROMNAME   = 0x126d3f0;   // FText::FromName(const FName&)
constexpr uintptr_t RVA_ENGINE_TICK      = 0x2c2c000;   // UGameEngine::Tick(this, float, bool) -- the pump
constexpr int PG_FLAGS = 0x2b0, PG_MAXVISIBLE = 0x290, PG_ACTIVEDEF = 0x298, PG_WIDGETS = 0x2a0, PG_HEADERIDX = 0x2b4, PG_SELIDX = 0x2b8;
constexpr int PG_DLG_CONFIRM = 0x3b0, PG_DLG_PROGRESS = 0x398;      // the two funnels' delegates
constexpr int DEF_KEY = 0x30, DEF_DISPLAYNAME = 0x38;
constexpr int IT_SIZE = 0x90, IT_KEY = 0x00, IT_PLATFORMS = 0x08, IT_EDITORONLY = 0x0c, IT_TYPE = 0x0d, IT_LABEL = 0x10, IT_SHORT = 0x28,
              IT_LONG = 0x40, IT_DELAY = 0x60, IT_MULTITEXTS = 0x68, IT_MULTISTART = 0x78, IT_PMIN = 0x80, IT_PMAX = 0x84, IT_PINC = 0x88;
constexpr int PRM_ITEM = 0x08, PRM_NEW = 0x9c, CONT_PAGE = 0x2a0;
struct FTextBlob { uint8_t b[24]; };
struct TArrayHdr { void* data; int32_t num; int32_t max; };
typedef void  (*FNameCtorFn)(uint64_t* self, const char* s, int find);
typedef void* (*TextFromNameFn)(FTextBlob* out, const uint64_t* name);
typedef void  (*MenuCreateFn)(void* page, const void* items, bool flag);
typedef void  (*MenuParamsFn)(void* page, void* params);
typedef void  (*MenuBackFn)(void* container, void* pageDef);
typedef void  (*MenuRefreshFn)(void* page);
typedef void  (*MenuSetTitleFn)(void* page, const FTextBlob* text);
typedef void  (*MenuSetSelFn)(void* page, int32_t idx, bool flag);
typedef void  (*ItemFloatFn)(void* item, float v);
typedef void  (*ItemIntFn)(void* item, int32_t v);
typedef void  (*BroadcastFn)(void* delegate, void* params);
typedef void  (*EngineTickFn)(void* engine, float dt, bool idle);
// ---- the detour ----
uint8_t* g_trampPage = nullptr; size_t g_trampUsed = 0;
bool DetourPatch(uint8_t* target, const void* hook, int n, const uint8_t* expect, int nExpect, const char* name) {
    if (memcmp(target, expect, nExpect) != 0) { Log("menu host: %s does not start with the bytes expected -- not hooked", name); return false; }
    DWORD old = 0;
    if (!VirtualProtect(target, n, PAGE_EXECUTE_READWRITE, &old)) { Log("menu host: %s could not be unprotected", name); return false; }
    uint8_t patch[32]; memset(patch, 0x90, sizeof(patch));
    patch[0] = 0xFF; patch[1] = 0x25; *(int32_t*)(patch + 2) = 0; *(uint64_t*)(patch + 6) = (uint64_t)hook;
    memcpy(target, patch, n);
    DWORD tmp = 0; VirtualProtect(target, n, old, &tmp);
    FlushInstructionCache(GetCurrentProcess(), target, n);
    return true;
}
// n bytes displaced into a trampoline (n >= 14, an instruction boundary, nothing relative among them)
void* DetourInstall(uint8_t* target, const void* hook, int n, const uint8_t* expect, int nExpect, const char* name) {
    if (!g_trampPage) g_trampPage = (uint8_t*)VirtualAlloc(nullptr, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (!g_trampPage || g_trampUsed + n + 14 > 4096) return nullptr;
    if (memcmp(target, expect, nExpect) != 0) { Log("menu host: %s does not start with the bytes expected -- not hooked", name); return nullptr; }
    uint8_t* t = g_trampPage + g_trampUsed;
    memcpy(t, target, n);
    t[n] = 0xFF; t[n + 1] = 0x25; *(int32_t*)(t + n + 2) = 0; *(uint64_t*)(t + n + 6) = (uint64_t)(target + n);
    if (!DetourPatch(target, hook, 14, expect, nExpect, name)) return nullptr;
    g_trampUsed += n + 14;
    Log("menu host: %s hooked (%d bytes displaced)", name, n);
    return t;
}
// ---- state ----
int g_host = 0;                                  // 0 off, 1 armed (installed on the game thread's next frame), 2 on, -1 dead
MenuCreateFn o_CreateItems = nullptr; MenuParamsFn o_MultiChg = nullptr; MenuBackFn o_Back = nullptr; EngineTickFn o_EngineTick = nullptr;
// (v66) IN FRONT OF ANOTHER MOD'S HOOKS. With SessionOpenMP enabled the menu functions (and the engine tick) already carry its
// MinHook hooks, and our byte check refused them: the nested pages only showed with that mod off. Now a hooked target is
// CHAINED: o_* is what our hook calls on (the next hook in the chain, or the game's function when nothing else is there);
// g_createOrig is the game's own CreatePageItems past every hook (our sub-pages go straight to it, or the other mod would add
// its rows to them); the two funnels have a "next" only when chained (alone, our hook re-implements them)
typedef void (*MenuFunnelFn)(uint8_t* page, uint8_t* params);
MenuCreateFn g_createOrig = nullptr; MenuFunnelFn n_SelConfirm = nullptr, n_ProgChg = nullptr; int g_chained = 0;
uint64_t g_pauseKey = 0, g_rootKey = 0, g_backKey = 0;
int g_hpage = -1;                                // -1 = the game's own pause root (with our row appended), else the page shown
int g_hparent[MENU_PAGES];
uint8_t g_hrows[MENU_PAGES][MENU_ROWS + 1][IT_SIZE]; uint64_t g_hkeys[MENU_PAGES][MENU_ROWS + 1]; FTextBlob g_hopts[MENU_PAGES][MENU_ROWS][2];
uint8_t g_rootRow[IT_SIZE]; uint8_t g_rowBuf[96 * IT_SIZE]; bool g_hbuilt = false; int g_hmain = -1;
uint32_t g_tplPlat = 0; uint8_t g_tplEditor = 0; float g_tplDelay = 0.0f; bool g_tplHave = false;
bool g_selfRefresh = false, g_rebuilding = false;
void* g_pendingPage = nullptr; char g_pendingTitle[64] = { 0 }; bool g_pendingRoot = false, g_pendingRefresh = false;
int g_valAt[MENU_ROWS]; float g_valOf[MENU_ROWS]; bool g_valSet[MENU_ROWS]; int g_valPage = -1;
char g_titleStr[64] = { 0 }; FTextBlob g_titleText; bool g_titleHave = false;
void HostDie(const char* why) { if (g_host != -1) Log("menu host: *** off for this run: %s (the game's own menu carries on; the ini still works)", why); g_host = -1; }
// (v66) A MinHook on the target (x64): `E9 rel32` to a relay `FF 25 00000000 <detour>` that sits in the same 64-byte slot as
// the trampoline (the game's displaced first instructions + a jump back). The relay's pointer is swung to OUR hook; *next =
// the detour that was there, *orig = the trampoline (the game's own function). Every step is checked, nothing is written
// unless all of it is what MinHook leaves behind
bool ChainInstall(uint8_t* target, const void* hook, const uint8_t* expect, const char* name, void** next, void** orig) {
    if (target[0] != 0xE9) { Log("hook: %s starts with neither the game's bytes nor a hook's jump -- not hooked", name); return false; }
    uint8_t* relay = target + 5 + *(int32_t*)(target + 1);
    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(relay, &mbi, sizeof(mbi)) != sizeof(mbi) || mbi.State != MEM_COMMIT || (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD)) != 0 ||
        (uintptr_t)relay + 14 > (uintptr_t)mbi.BaseAddress + mbi.RegionSize) { Log("hook: %s jumps somewhere unreadable -- not hooked", name); return false; }
    if (relay[0] != 0xFF || relay[1] != 0x25 || *(int32_t*)(relay + 2) != 0) { Log("hook: %s is hooked by something that is not a MinHook relay -- not hooked", name); return false; }
    uint8_t* tramp = (uint8_t*)((uintptr_t)relay & ~(uintptr_t)63);
    if (relay - tramp < 5 || memcmp(tramp, expect, 5) != 0) { Log("hook: %s -- the other hook's trampoline does not start with the game's bytes -- not hooked", name); return false; }
    void* prev = *(void**)(relay + 6);
    HMODULE hm = nullptr;
    if (!prev || !GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCWSTR)prev, &hm) || !hm) {
        Log("hook: %s -- the other hook's function is not in a loaded module -- not hooked", name); return false;
    }
    if (prev == hook) { Log("hook: %s is already ours", name); return false; }
    DWORD old = 0;
    if (!VirtualProtect(relay, 14, PAGE_EXECUTE_READWRITE, &old)) { Log("hook: %s -- the relay could not be unprotected -- not hooked", name); return false; }
    *next = prev; *orig = tramp;
    *(void**)(relay + 6) = (void*)hook;
    DWORD tmp = 0; VirtualProtect(relay, 14, old, &tmp);
    FlushInstructionCache(GetCurrentProcess(), relay, 14);
    Log("hook: %s chained in front of another mod's hook (its function %p in module %p; the game's own through its trampoline %p)", name, prev, (void*)hm, (void*)tramp);
    return true;
}
// the game's bytes there: our own detour (a funnel is re-implemented by its hook: nothing to call on); a hook there: chained
bool HostPlace(uint8_t* target, const void* hook, int n, const uint8_t* expect, int nExpect, const char* name, bool funnel, void** next, void** orig) {
    *next = nullptr; *orig = nullptr;
    if (memcmp(target, expect, nExpect) == 0) {
        if (funnel) return DetourPatch(target, hook, 14, expect, nExpect, name);
        void* t = DetourInstall(target, hook, n, expect, nExpect, name);
        *next = t; *orig = t;
        return t != nullptr;
    }
    if (!ChainInstall(target, hook, expect, name, next, orig)) return false;
    g_chained++;
    return true;
}
uint8_t* Exe() { return (uint8_t*)GetModuleHandleW(nullptr); }
bool MakeFName(const char* s, uint64_t* out) { *out = 0; if (!s || !*s) return false; ((FNameCtorFn)(Exe() + RVA_FNAME_CTOR_A))(out, s, 1 /* FNAME_Add */); return *out != 0; }
bool MakeText(const char* s, FTextBlob* out) { uint64_t fn; if (!MakeFName(s, &fn)) return false; memset(out, 0, sizeof(*out)); ((TextFromNameFn)(Exe() + RVA_FTEXT_FROMNAME))(out, &fn); return true; }
// ---- (v59) THE CONTROLLER, NATIVELY. The hippie jumps' stick clicks, the varial's triggers, the grabs' bumpers and the
// drop-in's Y came from tailing SessionTweaks.log (matsix's mod sees the pad) -- a hard dependency on another mod and five
// of its ini keys. Now APlayerController::InputKey (every key event, the engine's stick-direction keys included) is
// detoured like the menu's seams, and every PRESSED key's name is queued for the Lua (HJN_PadEvents): the same names
// SessionTweaks logged ("Gamepad_LeftThumbstick", "GenericUSBController_Button11"...). SessionTweaks' log stays the fallback.
constexpr uintptr_t RVA_PC_INPUTKEY     = 0x2ecf510;   // bool APlayerController::InputKey(FKey, EInputEvent, float, bool): the FKey comes by pointer
constexpr uintptr_t RVA_FNAME_TOSTR_BUF = 0x133a690;   // uint32 FName::ToString(WIDECHAR* out, uint32 outSize) const
typedef bool (*InputKeyFn)(void* pc, const void* key, int ev, float amt, bool gamepad);
typedef uint32_t (*FNameToStrFn)(const void* fname, wchar_t* out, uint32_t n);
InputKeyFn o_InputKey = nullptr;
CRITICAL_SECTION g_padLock; bool g_padLockOk = false;
char g_padQ[4096]; int g_padQn = 0; LONG g_padEvents = 0; volatile int g_padOn = 0;
void PadQueue(const void* key) {
    wchar_t w[96]; char s[100]; int m = 0;
    const uint32_t n = ((FNameToStrFn)(Exe() + RVA_FNAME_TOSTR_BUF))(key, w, 96);
    if (n == 0 || n >= 96) return;
    for (uint32_t i = 0; i < n && m < 98; i++) s[m++] = (char)((w[i] > 31 && w[i] < 127) ? w[i] : '?');
    EnterCriticalSection(&g_padLock);
    if (g_padQn + m + 1 < (int)sizeof(g_padQ)) { memcpy(g_padQ + g_padQn, s, m); g_padQn += m; g_padQ[g_padQn++] = '\n'; }
    LeaveCriticalSection(&g_padLock);
    InterlockedIncrement(&g_padEvents);
}
// ==== (v67) THE REPLAY EDITOR'S STICK CLICKS ==========================================================================
// "I cannot use the stick clicks in filmer mode": in the game's replay editor L3 switches to its Filmer camera
// (ReplaySwitchToFilmerMode) and sets a clip's start, R3 cycles the scrub speed and sets its end. SessionTweaks' click-to-catch
// hooks UPlayerInput::InputKey and SWALLOWS both stick clicks whenever the skater counts as on the board -- and the replay's
// skater does ("[catch] key 'Gamepad_LeftThumbstick' pressed, onBoard=1" with the replay up), so the editor never saw them.
// APlayerController::InputKey, hooked here, is upstream of that: while the replay manager says playback (its mode byte = 2)
// the two stick clicks are handed straight to the game's own UPlayerInput::InputKey (the trampoline behind the MinHook on
// it, found and checked as ChainInstall does) -- and they are NOT queued for the Lua: a replay's skater does no tricks.
constexpr uintptr_t RVA_REPLAY_MGR  = 0x4fc3430;   // AReplayManager::_instance
constexpr uintptr_t RVA_PI_INPUTKEY = 0x308d310;   // bool UPlayerInput::InputKey(FKey, EInputEvent, float, bool)
constexpr int RM_MODE = 0x2a8, PC_PLAYERINPUT = 0x348;   // AReplayManager::_currentReplayMode (2 = playback); APlayerController::PlayerInput
uint64_t g_fnL3 = 0, g_fnR3 = 0; volatile int g_replayClicks = 1; int g_replayPassed = 0, g_replayTold = 0;
extern bool g_hooked;
int ReplayNow() {
    __try { const uint8_t* rm = *(const uint8_t* const*)(Exe() + RVA_REPLAY_MGR); return (rm && rm[RM_MODE] == 2) ? 1 : 0; }
    __except (EXCEPTION_EXECUTE_HANDLER) { return 0; }
}
InputKeyFn PlayerInputPastHook() {
    uint8_t* t = Exe() + RVA_PI_INPUTKEY;
    static const uint8_t expect[5] = { 0x48, 0x8b, 0xc4, 0x53, 0x57 };
    if (t[0] != 0xE9) return nullptr;                                   // nothing hooked there: the game's usual path does
    uint8_t* relay = t + 5 + *(int32_t*)(t + 1);
    if (!PtrOk(relay, 14) || relay[0] != 0xFF || relay[1] != 0x25 || *(int32_t*)(relay + 2) != 0) return nullptr;
    uint8_t* tramp = (uint8_t*)((uintptr_t)relay & ~(uintptr_t)63);
    if (relay - tramp < 5 || !PtrOk(tramp, 32) || memcmp(tramp, expect, 5) != 0) return nullptr;
    return (InputKeyFn)tramp;
}
int ReplayClick(void* pc, const void* key, InputKeyFn* past, void** pi) {
    __try {
        if (!g_fnL3) { MakeFName("Gamepad_LeftThumbstick", &g_fnL3); MakeFName("Gamepad_RightThumbstick", &g_fnR3); }
        const uint64_t k = *(const uint64_t*)key;
        if (k == 0 || (k != g_fnL3 && k != g_fnR3) || !ReplayNow()) return 0;
        *past = PlayerInputPastHook();
        *pi = *(void**)((uint8_t*)pc + PC_PLAYERINPUT);
        return 1;
    } __except (EXCEPTION_EXECUTE_HANDLER) { return 0; }
}
bool hkInputKey(void* pc, const void* key, int ev, float amt, bool gamepad) {
    if (g_replayClicks && g_hooked && pc && key) {
        InputKeyFn past = nullptr; void* pi = nullptr;
        if (ReplayClick(pc, key, &past, &pi)) {
            if (ev == 0 && g_replayTold < 4) {
                g_replayTold++;
                Log("replay: a stick click in the replay editor -- %s", (past && pi) ? "handed to the game past the hook that swallows it" : "nothing known is hooked on the game's key input: left to the game's usual path");
            }
            if (past && pi) { g_replayPassed++; return past(pi, key, ev, amt, gamepad); }
            return o_InputKey(pc, key, ev, amt, gamepad);
        }
    }
    if (g_bumpMaskUntil && ev == 0 && key && GetTickCount64() < g_bumpMaskUntil) {     // (v68) RB is the boneless's: not the game's, not the Lua's
        if (!g_fnRB) { MakeFName("Gamepad_RightShoulder", &g_fnRB); MakeFName("Gamepad_LeftShoulder", &g_fnLB); }
        if (g_fnRB && (*(const uint64_t*)key == g_fnRB || *(const uint64_t*)key == g_fnLB)) return true;   // (v69) LB too
    }
    if (g_padOn && ev == 0 /* IE_Pressed */ && key) {
        __try { PadQueue(key); } __except (EXCEPTION_EXECUTE_HANDLER) { g_padOn = 0; Log("pad: fault reading a key's name -- the native controller read is OFF for this run"); }
    }
    return o_InputKey(pc, key, ev, amt, gamepad);
}
// HJN_PadOn(1) -> 1 once the hook is in (0 = refused: the bytes differ, no room); HJN_PadOn(0) stops the queueing
int nPadOn(const Lua& lua) {
    double v = 1; ArgNum(lua, v);
    if (v == 0 || !g_hooked) { g_padOn = 0; lua.set_integer(0); return 1; }   // (v101: nor on another build of the game)
    if (!o_InputKey) {
        if (!g_padLockOk) { InitializeCriticalSection(&g_padLock); g_padLockOk = true; }
        static const uint8_t expect[15] = { 0x48, 0x8b, 0xc4, 0x48, 0x89, 0x58, 0x10, 0x48, 0x89, 0x70, 0x18, 0x55, 0x57, 0x41, 0x57 };
        o_InputKey = (InputKeyFn)DetourInstall(Exe() + RVA_PC_INPUTKEY, (const void*)&hkInputKey, 15, expect, sizeof(expect), "APlayerController::InputKey (the pad)");
    }
    g_padOn = o_InputKey ? 1 : 0;
    lua.set_integer(g_padOn);
    return 1;
}
// HJN_PadEvents() -> the names of the keys pressed since the last call, one per line ("" = none)
int nPadEvents(const Lua& lua) {
    char out[4096]; int n = 0;
    if (g_padLockOk) {
        EnterCriticalSection(&g_padLock);
        n = g_padQn; if (n > 0) memcpy(out, g_padQ, n); g_padQn = 0;
        LeaveCriticalSection(&g_padLock);
    }
    out[n] = 0;
    lua.set_string(out);
    return 1;
}
// (v62) HJN_PadSticks() -> "lx ly rx ry" of the first connected XInput pad (-1..1, right and up positive), "" without one.
// The game's filmer mode takes the sticks' analog input before the player controller ever sees it (GetInputAnalogStickState
// read 0,0 for both sticks there with the thumb hard over), so the pad is read at the source
struct XiPad { uint16_t buttons; uint8_t lt, rt; int16_t lx, ly, rx, ry; };
struct XiState { uint32_t packet; XiPad pad; };
typedef uint32_t (WINAPI *XiGetStateFn)(uint32_t, XiState*);
XiGetStateFn g_xiGet = nullptr; bool g_xiTried = false; int g_xiUser = -1; ULONGLONG g_xiScanAt = 0;
int nPadSticks(const Lua& lua) {
    char out[96] = "";
    if (!g_xiTried) {
        g_xiTried = true;
        const wchar_t* dlls[] = { L"xinput1_4.dll", L"xinput1_3.dll", L"xinput9_1_0.dll" };
        for (int i = 0; i < 3 && !g_xiGet; i++) { HMODULE h = LoadLibraryW(dlls[i]); if (h) g_xiGet = (XiGetStateFn)GetProcAddress(h, "XInputGetState"); }
        Log("pad sticks: XInputGetState %s", g_xiGet ? "found" : "NOT available (no XInput)");
    }
    if (g_xiGet) {
        XiState st; memset(&st, 0, sizeof(st));
        bool ok = false;
        if (g_xiUser >= 0) ok = g_xiGet((uint32_t)g_xiUser, &st) == 0;
        if (!ok) {
            const ULONGLONG now = GetTickCount64();
            if (now - g_xiScanAt > 2000) {                                  // (a pad is looked for every 2 s)
                g_xiScanAt = now; g_xiUser = -1;
                for (uint32_t u = 0; u < 4 && !ok; u++) { memset(&st, 0, sizeof(st)); if (g_xiGet(u, &st) == 0) { ok = true; g_xiUser = (int)u; Log("pad sticks: XInput pad %u", u); } }
            }
        }
        if (ok) snprintf(out, sizeof(out), "%.3f %.3f %.3f %.3f %.3f %.3f %u", st.pad.lx / 32767.0f, st.pad.ly / 32767.0f, st.pad.rx / 32767.0f, st.pad.ry / 32767.0f, st.pad.lt / 255.0f, st.pad.rt / 255.0f, (unsigned)st.pad.buttons);   // (v65) + the triggers, (v68) + the buttons (RB = 0x200)
    }
    lua.set_string(out);
    return 1;
}
bool RowBase(uint8_t* dst, const char* key, const char* label, const char* desc, uint64_t* keyOut) {
    memset(dst, 0, IT_SIZE);
    uint64_t fn; if (!MakeFName(key, &fn)) return false;
    *(uint64_t*)(dst + IT_KEY) = fn; if (keyOut) *keyOut = fn;
    dst[IT_TYPE] = 1;                                                    // Selection
    FTextBlob t; if (!MakeText(label, &t)) return false; memcpy(dst + IT_LABEL, &t, sizeof(t));
    if (!MakeText((desc && desc[0]) ? desc : label, &t)) return false;
    memcpy(dst + IT_SHORT, &t, sizeof(t)); memcpy(dst + IT_LONG, &t, sizeof(t));
    return true;
}
bool PageIsSub(int idx) {
    for (int p = 0; p < g_mpageN; p++) { if (p == idx) continue; for (int r = 0; r < g_mpage[p].n; r++) if (g_mpage[p].row[r].kind == MENU_PAGE && strcmp(g_mpage[p].row[r].key, g_mpage[idx].title) == 0) return true; }
    return false;
}
int PageByTitle(const char* t) { for (int p = 0; p < g_mpageN; p++) if (strcmp(g_mpage[p].title, t) == 0) return p; return -1; }
bool HostBuild() {
    if (g_hbuilt) return true;
    if (!MakeFName("PauseMenuPage", &g_pauseKey)) return false;
    g_hmain = -1;
    for (int p = 0; p < g_mpageN; p++) if (!PageIsSub(p)) { g_hmain = p; break; }
    if (g_hmain < 0) return false;
    if (!RowBase(g_rootRow, "ET_Root", g_mpage[g_hmain].title, "the mod's settings", &g_rootKey)) return false;
    for (int p = 0; p < g_mpageN; p++) {
        g_hparent[p] = -1;
        for (int r = 0; r < g_mpage[p].n; r++) {
            const MenuRow& w = g_mpage[p].row[r];
            uint8_t* row = g_hrows[p][r];
            char k[64]; snprintf(k, sizeof(k), "ET_%s", w.key);
            if (!RowBase(row, k, w.label, w.desc, &g_hkeys[p][r])) return false;
            if (w.kind == MENU_TOGGLE) {
                if (!MakeText(w.off[0] ? w.off : "Off", &g_hopts[p][r][0]) || !MakeText(w.on[0] ? w.on : "On", &g_hopts[p][r][1])) return false;
                row[IT_TYPE] = 2;                                        // MultiOption
                *(void**)(row + IT_MULTITEXTS) = g_hopts[p][r]; *(int32_t*)(row + IT_MULTITEXTS + 8) = 2; *(int32_t*)(row + IT_MULTITEXTS + 12) = 2;
            } else if (w.kind == MENU_SLIDER) {
                row[IT_TYPE] = 3;                                        // ProgressBar
                *(float*)(row + IT_PMIN) = w.lo; *(float*)(row + IT_PMAX) = (w.hi > w.lo) ? w.hi : w.lo + 1.0f; *(float*)(row + IT_PINC) = (w.step > 0.0f) ? w.step : 1.0f;
            }
        }
        if (!RowBase(g_hrows[p][g_mpage[p].n], "ET_Back", "Back", "back to the page before", &g_backKey)) return false;
        g_hkeys[p][g_mpage[p].n] = g_backKey;
    }
    g_hbuilt = true;
    Log("menu host: %d pages of rows built; the pause page gets a \"%s\" row", g_mpageN, g_mpage[g_hmain].title);
    return true;
}
void StampTemplate(uint8_t* row) {
    if (!g_tplHave) return;
    *(uint32_t*)(row + IT_PLATFORMS) = g_tplPlat; row[IT_EDITORONLY] = g_tplEditor;
    *(float*)(row + IT_DELAY) = g_tplDelay;
}
const TArrayHdr* HostChoose(uint8_t* page, const TArrayHdr* items, TArrayHdr* ours) {
    void* def = *(void**)(page + PG_ACTIVEDEF);
    if (!def) return items;
    if (!HostBuild()) { HostDie("the rows could not be built"); return items; }
    if (*(const uint64_t*)((const uint8_t*)def + DEF_KEY) != g_pauseKey) return items;   // another menu of the game's
    if (!g_selfRefresh && g_hpage != -1) g_hpage = -1;      // the game built the pause page itself: opened afresh, the root
    if (items && items->data && items->num > 0 && !g_tplHave) {
        const uint8_t* it = (const uint8_t*)items->data;
        g_tplPlat = *(const uint32_t*)(it + IT_PLATFORMS); g_tplEditor = it[IT_EDITORONLY]; g_tplDelay = *(const float*)(it + IT_DELAY); g_tplHave = true;
        Log("menu host: row template from the stock page: platforms 0x%08x, input delay %.3f", g_tplPlat, g_tplDelay);
    }
    int n = 0;
    auto add = [&](const uint8_t* src, bool mine) { if (n >= 96) return; uint8_t* dst = g_rowBuf + (size_t)n * IT_SIZE; memcpy(dst, src, IT_SIZE); if (mine) StampTemplate(dst); n++; };
    if (g_hpage < 0) {
        if (!items || !items->data || items->num < 0 || items->num + 1 > 60) return items;
        for (int i = 0; i < items->num; i++) add((const uint8_t*)items->data + (size_t)i * IT_SIZE, false);
        add(g_rootRow, true);
    } else {
        const MenuPage& pg = g_mpage[g_hpage];
        g_valPage = g_hpage;
        for (int r = 0; r < pg.n; r++) {
            const MenuRow& w = pg.row[r];
            add(g_hrows[g_hpage][r], true);
            g_valAt[r] = r; g_valSet[r] = false;
            if (w.kind == MENU_TOGGLE || w.kind == MENU_SLIDER) {
                if (MenuVal* m = MenuFind(w.key)) {
                    g_valOf[r] = m->v; g_valSet[r] = true;
                    if (w.kind == MENU_TOGGLE) *(int32_t*)(g_rowBuf + (size_t)(n - 1) * IT_SIZE + IT_MULTISTART) = (m->v >= 0.5f) ? 1 : 0;
                }
            }
        }
        add(g_hrows[g_hpage][pg.n], true);                      // Back
    }
    ours->data = g_rowBuf; ours->num = n; ours->max = n;
    return ours;
}
void hkCreateItems(void* page, void* itemsArray, bool flag) {
    const TArrayHdr* use = (const TArrayHdr*)itemsArray;
    TArrayHdr ours{};
    int32_t saved = 0; bool bumped = false;
    uint8_t* p = (uint8_t*)page;
    if (g_host == 2 && page && itemsArray) {
        __try {
            use = HostChoose(p, (const TArrayHdr*)itemsArray, &ours);
            if (use == &ours) {                                  // rows past the page's visible window are silently not built
                saved = *(int32_t*)(p + PG_MAXVISIBLE);
                const int32_t need = *(int32_t*)(p + PG_HEADERIDX) + ours.num;
                if (saved < need) { *(int32_t*)(p + PG_MAXVISIBLE) = need; bumped = true; }
            }
        } __except (EXCEPTION_EXECUTE_HANDLER) { HostDie("faulted building the rows"); use = (const TArrayHdr*)itemsArray; }
    }
    // (v66) our own sub-page goes straight to the game's function; the pause root (our row appended) and every other page
    // go on down the chain
    ((use == &ours && g_hpage >= 0 && g_createOrig) ? g_createOrig : o_CreateItems)(page, use, flag);
    if (bumped) { __try { *(int32_t*)(p + PG_MAXVISIBLE) = saved; } __except (EXCEPTION_EXECUTE_HANDLER) { HostDie("faulted restoring the row window"); } }
}
void StampValues(uint8_t* page) {
    if (g_valPage < 0) return;
    const int gp = g_valPage; g_valPage = -1;
    if (gp >= g_mpageN) return;
    const TArrayHdr* w = (const TArrayHdr*)(page + PG_WIDGETS);
    if (!w->data) return;
    for (int r = 0; r < g_mpage[gp].n; r++) {
        if (!g_valSet[r]) continue;
        const int idx = g_valAt[r];
        if (idx < 0 || idx >= w->num) continue;
        void* widget = ((void**)w->data)[idx];
        if (!widget) continue;
        const MenuRow& mr = g_mpage[gp].row[r];
        if (mr.kind == MENU_SLIDER) {
            float pct = (mr.hi > mr.lo) ? (g_valOf[r] - mr.lo) / (mr.hi - mr.lo) : 0.0f;
            pct = clampf(pct, 0.0f, 1.0f);
            ((ItemFloatFn)(Exe() + RVA_ITEM_PROGSET))(widget, pct);
        } else ((ItemIntFn)(Exe() + RVA_ITEM_MULTISET))(widget, (g_valOf[r] >= 0.5f) ? 1 : 0);
    }
}
void PassOwned(const void* src, FTextBlob* out) {           // a copy the callee may release: bump the controller's count first
    memcpy(out, src, sizeof(FTextBlob));
    void* ctl = *(void**)((uint8_t*)out + 8);
    if (ctl) InterlockedIncrement((volatile LONG*)((uint8_t*)ctl + 8));
}
void HostTitle(uint8_t* page, const char* text) {
    const void* src = nullptr;
    if (text) {
        if (!g_titleHave || strcmp(g_titleStr, text) != 0) { FTextBlob t; if (MakeText(text, &t)) { g_titleText = t; snprintf(g_titleStr, sizeof(g_titleStr), "%s", text); g_titleHave = true; } }
        src = g_titleHave ? &g_titleText : nullptr;
    } else {
        void* def = *(void**)(page + PG_ACTIVEDEF);
        if (def) src = (const uint8_t*)def + DEF_DISPLAYNAME;
    }
    if (!src) return;
    FTextBlob owned; PassOwned(src, &owned);
    ((MenuSetTitleFn)(Exe() + RVA_MENU_SETTITLE))(page, &owned);
}
void HostRefresh(uint8_t* page) {
    g_selfRefresh = true; g_rebuilding = true;
    ((MenuRefreshFn)(Exe() + RVA_MENU_REFRESH))(page);           // the game's own rebuild: CreatePageItems again, through our hook
    *(int32_t*)(page + PG_SELIDX) = -1;                           // the old index is meaningless on a list of another length
    ((MenuSetSelFn)(Exe() + RVA_MENU_SETSEL))(page, 0, false);
    StampValues(page);
    g_rebuilding = false; g_selfRefresh = false;
}
void HostQueue(void* page, const char* title, bool rootTitle) {
    g_pendingPage = page; g_pendingRefresh = true; g_pendingRoot = rootTitle;
    if (title) snprintf(g_pendingTitle, sizeof(g_pendingTitle), "%s", title); else g_pendingTitle[0] = 0;
}
void HostPump() {
    if (!g_pendingPage) return;
    uint8_t* page = (uint8_t*)g_pendingPage; g_pendingPage = nullptr;
    if (g_pendingRefresh) HostRefresh(page);
    if (g_pendingRoot) HostTitle(page, nullptr); else if (g_pendingTitle[0]) HostTitle(page, g_pendingTitle);
    g_pendingRefresh = false; g_pendingTitle[0] = 0; g_pendingRoot = false;
}
void hkEngineTick(void* engine, float dt, bool idle) {
    InterlockedIncrement(&g_beat); g_gameTid = GetCurrentThreadId(); g_wdTick = 1;   // (v95) the watchdog's counter
    if (g_host == 2) { __try { HostPump(); } __except (EXCEPTION_EXECUTE_HANDLER) { HostDie("faulted swapping a page"); } }
    o_EngineTick(engine, dt, idle);
}
bool HostBack(void* page) {
    if (g_hpage < 0 || !page) return false;
    const int up = g_hparent[g_hpage];
    if (up >= 0 && up < g_mpageN) { g_hparent[g_hpage] = -1; g_hpage = up; HostQueue(page, g_mpage[up].title, false); return true; }
    g_hpage = -1; HostQueue(page, nullptr, true);
    return true;
}
bool HostConfirm(uint8_t* page, uint8_t* params) {
    const uint64_t key = *(const uint64_t*)(params + PRM_ITEM + IT_KEY);
    if (!key || !g_hbuilt) return false;
    if (g_hpage < 0) {
        if (key != g_rootKey) return false;
        g_hpage = g_hmain; g_hparent[g_hmain] = -1;
        HostQueue(page, g_mpage[g_hmain].title, false);
        Log("menu host: opened \"%s\"", g_mpage[g_hmain].title);
        return true;
    }
    if (key == g_backKey) return HostBack(page);
    const MenuPage& pg = g_mpage[g_hpage];
    for (int r = 0; r < pg.n; r++) {
        if (key != g_hkeys[g_hpage][r] || pg.row[r].kind != MENU_PAGE) continue;
        const int target = PageByTitle(pg.row[r].key);
        if (target < 0 || target == g_hpage) return true;
        g_hparent[target] = g_hpage; g_hpage = target;
        HostQueue(page, g_mpage[target].title, false);
        Log("menu host: opened \"%s\"", g_mpage[target].title);
        return true;
    }
    return false;
}
// UMenuPage::OnSelectionConfirmed, re-implemented: our row is handled here and the game's chain is not run for it
void hkSelConfirm(uint8_t* page, uint8_t* params) {
    bool handled = false;
    if (g_host == 2 && page && params) { __try { handled = HostConfirm(page, params); } __except (EXCEPTION_EXECUTE_HANDLER) { HostDie("faulted handling a confirm"); handled = false; } }
    if (handled) return;
    if (n_SelConfirm) { n_SelConfirm(page, params); return; }        // (v66) chained: the other mod's hook, then the game's
    if (!(page[PG_FLAGS] & 1)) { *(void**)params = *(void**)(page + PG_ACTIVEDEF); ((BroadcastFn)(Exe() + RVA_DELEGATE_BCAST))(page + PG_DLG_CONFIRM, params); }
}
void hkPageBack(void* container, void* pageDef) {
    bool handled = false;
    if (g_host == 2 && container && pageDef && g_hpage >= 0) {
        __try {
            if (*(const uint64_t*)((const uint8_t*)pageDef + DEF_KEY) == g_pauseKey) {
                void* page = *(void**)((uint8_t*)container + CONT_PAGE);
                if (page) handled = HostBack(page);
            }
        } __except (EXCEPTION_EXECUTE_HANDLER) { HostDie("faulted handling the back button"); handled = false; }
    }
    if (!handled) o_Back(container, pageDef);
}
void HostValue(const uint8_t* params, bool isSlider) {
    if (g_rebuilding || g_hpage < 0 || !params) return;           // a rebuild restoring a row is not the player
    const uint64_t key = *(const uint64_t*)(params + PRM_ITEM + IT_KEY);
    const MenuPage& pg = g_mpage[g_hpage];
    for (int r = 0; r < pg.n; r++) {
        if (key != g_hkeys[g_hpage][r]) continue;
        const MenuRow& w = pg.row[r];
        float v;
        if (isSlider) { const float pct = *(const float*)(params + PRM_NEW); v = w.lo + pct * (w.hi - w.lo); }
        else v = (float)*(const int32_t*)(params + PRM_NEW);
        MenuOnValue(w.key, (int)(v + (v >= 0 ? 0.5f : -0.5f)), v, nullptr);
        return;
    }
}
void hkMultiChg(void* page, void* params) {
    if (g_host == 2) { __try { HostValue((const uint8_t*)params, false); } __except (EXCEPTION_EXECUTE_HANDLER) { HostDie("faulted on a toggle"); } }
    o_MultiChg(page, params);
}
// UMenuPage::OnProgressBarValueChanged, re-implemented (the same 32-byte shape as the confirm funnel)
void hkProgChg(uint8_t* page, uint8_t* params) {
    if (g_host == 2) { __try { HostValue(params, true); } __except (EXCEPTION_EXECUTE_HANDLER) { HostDie("faulted on a slider"); } }
    if (n_ProgChg) { n_ProgChg(page, params); return; }              // (v66) chained
    if (!(page[PG_FLAGS] & 1)) { *(void**)params = *(void**)(page + PG_ACTIVEDEF); ((BroadcastFn)(Exe() + RVA_DELEGATE_BCAST))(page + PG_DLG_PROGRESS, params); }
}
void HostInstall() {
    uint8_t* exe = Exe();
    static const uint8_t eCreate[] = { 0x48, 0x8b, 0xc4, 0x44, 0x88, 0x40, 0x18, 0x55, 0x41, 0x55, 0x41, 0x57, 0x48, 0x8d, 0x68, 0xa1 };
    static const uint8_t eSel[]    = { 0xf6, 0x81, 0xb0, 0x02, 0x00, 0x00, 0x01, 0x75, 0x16, 0x48, 0x8b, 0x81, 0x98, 0x02 };
    static const uint8_t eBack[]   = { 0x48, 0x89, 0x5c, 0x24, 0x18, 0x48, 0x89, 0x74, 0x24, 0x20, 0x48, 0x89, 0x54, 0x24, 0x10 };
    static const uint8_t eMulti[]  = { 0x40, 0x53, 0x48, 0x83, 0xec, 0x20, 0xf6, 0x81, 0xb0, 0x02, 0x00, 0x00, 0x01, 0x48, 0x8b, 0xd9 };
    static const uint8_t eProg[]   = { 0xf6, 0x81, 0xb0, 0x02, 0x00, 0x00, 0x01, 0x75, 0x16, 0x48, 0x8b, 0x81, 0x98, 0x02 };
    static const uint8_t eTick[]   = { 0x44, 0x88, 0x44, 0x24, 0x18, 0x55, 0x53, 0x57, 0x41, 0x54, 0x41, 0x57, 0x48, 0x8d, 0x6c, 0x24, 0xc9 };
    // (v66) each target: our own detour when it holds the game's bytes, chained when another mod's hook is on it. All of this
    // runs on the game thread, which is the only one that calls these functions: a hook is never run before its o_* is set
    void *nx = nullptr, *og = nullptr;
    const bool tick = HostPlace(exe + RVA_ENGINE_TICK, (const void*)&hkEngineTick, 17, eTick, sizeof(eTick), "UGameEngine::Tick", false, &nx, &og);
    if (tick) o_EngineTick = (EngineTickFn)nx;
    const bool create = tick && HostPlace(exe + RVA_MENU_CREATEITEMS, (const void*)&hkCreateItems, 16, eCreate, sizeof(eCreate), "UMenuPage::CreatePageItems", false, &nx, &og);
    if (create) { o_CreateItems = (MenuCreateFn)nx; g_createOrig = (MenuCreateFn)og; }
    if (!tick || !create) { HostDie("the hooks could not be placed"); return; }
    const bool sel = HostPlace(exe + RVA_MENU_SELCONFIRM, (const void*)&hkSelConfirm, 14, eSel, sizeof(eSel), "UMenuPage::OnSelectionConfirmed", true, &nx, &og);
    if (!sel) { HostDie("the confirm funnel could not be taken"); return; }
    n_SelConfirm = (MenuFunnelFn)nx;
    if (HostPlace(exe + RVA_MENU_BACKACTION, (const void*)&hkPageBack, 15, eBack, sizeof(eBack), "UMenuPageContainer::HandlePageBackAction", false, &nx, &og)) o_Back = (MenuBackFn)nx;
    if (HostPlace(exe + RVA_MENU_MULTICHG, (const void*)&hkMultiChg, 16, eMulti, sizeof(eMulti), "UMenuPage::OnMultiOptionItemSelectionChanged", false, &nx, &og)) o_MultiChg = (MenuParamsFn)nx;
    const bool prog = HostPlace(exe + RVA_MENU_PROGCHG, (const void*)&hkProgChg, 14, eProg, sizeof(eProg), "UMenuPage::OnProgressBarValueChanged", true, &nx, &og);
    if (prog) n_ProgChg = (MenuFunnelFn)nx;
    if (!o_Back) o_Back = nullptr;                              // (a back button that closes the menu from our page is the old behaviour)
    g_host = 2;
    Log("menu host: ON -- an \"Expanded Tricks\" row joins the pause menu%s%s%s", g_chained ? " (in front of another mod's menu hooks)" : "", o_MultiChg && prog ? "" : " (toggles/sliders will not report changes: a funnel was not hooked)",
        o_Back ? "" : " (the back button closes the menu from our pages)");
}
void SafeHostFallback() { __try { MenuRegisterFlat(); } __except (GrabFilter(GetExceptionCode())) { g_mreg = -1; } }
void SafeHostInstall() {
    __try { HostInstall(); } __except (GrabFilter(GetExceptionCode())) { HostDie("faulted installing"); }
    if (g_host != 2 && g_seamReg) {                 // (v66) the nested pages could not be placed: the one flat page through SessionOpenMP's menu
        Log("menu: the nested pages are not available on this run -- one flat page in SessionOpenMP's menu instead");
        SafeHostFallback();
    }
}

// ==== (v66) KEEP AN OBJECT FOR THE WHOLE RUN ==========================================================================
// The no comply puts an animation the game never references (BLD_RGS_NoComply) into a trick definition. The engine's garbage
// collector did not count that reference: about a minute on the blend space was freed with the definition still pointing at
// it -- "the no comply worked once, then broke", and every UE4SS fault of 3 Oct was the Lua reading that pointer. UE4SS exports
// the engine's AddToRoot (UObject::SetRootSet): a rooted object is never collected.
// HJN_Root(address) -> "flags <before> -> <after> cluster <n>" ("" = not rooted)
int RootIt(uintptr_t p, uint32_t* before, uint32_t* after, int32_t* cluster) {
    const uint8_t* it = (const uint8_t*)((RC::Unreal::UObjectBase*)p)->GetObjectItem();
    if (!it || *(const uintptr_t*)it != p) return 0;               // not this object's slot: nothing is touched
    *before = *(const uint32_t*)(it + 8); *cluster = *(const int32_t*)(it + 12);
    ((RC::Unreal::UObject*)p)->SetRootSet();
    *after = *(const uint32_t*)(it + 8);
    return 1;
}
int SafeRoot(uintptr_t p, uint32_t* before, uint32_t* after, int32_t* cluster) { __try { return RootIt(p, before, after, cluster); } __except (GrabFilter(GetExceptionCode())) { return -1; } }
int nRoot(const Lua& lua) {
    double a = 0; ArgNum(lua, a);
    char out[96] = "";
    const uintptr_t p = (a > 65536.0 && a < 1.8e19) ? (uintptr_t)a : 0;
    uint32_t f0 = 0, f1 = 0; int32_t cl = 0;
    const int r = p ? SafeRoot(p, &f0, &f1, &cl) : 0;
    if (r == 1) snprintf(out, sizeof(out), "flags %08x -> %08x cluster %d", f0, f1, cl);
    else Log("root: %p could not be rooted (%s)", (void*)p, r < 0 ? "fault" : "no slot");
    lua.set_string(out);
    return 1;
}

// ==== (v72) NO FLIP TRICKS WITH A HAND ON THE BOARD ===================================================================
// "Block, when he is grabbing the board, flip trick inputs -- apart from the no comply, and the low pop ollie." The game's
// FlipTricksHandler::CheckForTrick (and its late-trick twin) walks the list of trick definitions at [handler+0x28]+0x2c0 and
// passes over any whose Mute byte (+0x65, the reflected "Mute") is set. HJN_TrickMute(1) sets it on every definition but
// the allowed ones -- the two the no comply lives in (RGS / SWS pressure kickflip) and the low-pop ollies (the "Shitty"
// ollies, one per stance) -- keeping what each held; HJN_TrickMute(0) puts every one back. Turning is not a trick.
constexpr int FTH_DATA = 0x28, FTDL_LIST = 0x2c0, FTD_MUTE = 0x65, FTD_NAME = 0x30;
struct MuteSave { uint8_t* def; uint8_t was; };
MuteSave g_muteSave[512]; int g_muteN = 0; bool g_muteOn = false, g_muteTold = false;
int TrickMute(int on) {
    if (!on) {
        const int n = g_muteN;
        for (int i = 0; i < g_muteN; i++) if (PtrOk(g_muteSave[i].def, 0x70)) g_muteSave[i].def[FTD_MUTE] = g_muteSave[i].was;
        g_muteN = 0; g_muteOn = false;
        return n;
    }
    if (g_muteOn) return g_muteN;
    uint8_t* fth = LateHandler();
    if (!fth) return -1;
    uint8_t* data = *(uint8_t**)(fth + FTH_DATA);
    if (!PtrOk(data, FTDL_LIST + 0x10)) return -1;
    uint8_t** list = *(uint8_t***)(data + FTDL_LIST);
    const int32_t num = *(const int32_t*)(data + FTDL_LIST + 8);
    if (!list || num < 1 || num > 512 || !PtrOk(list, (size_t)num * 8)) return -1;
    int muted = 0, kept = 0;
    for (int i = 0; i < num; i++) {
        uint8_t* def = list[i];
        if (!PtrOk(def, 0x70)) continue;
        wchar_t w[96]; char s[96]; int m = 0;
        const uint32_t n = ((FNameToStrFn)(Exe() + RVA_FNAME_TOSTR_BUF))(def + FTD_NAME, w, 96);
        for (uint32_t j = 0; j < n && j < 95; j++) { const wchar_t ch = w[j]; s[m++] = (char)((ch >= L'A' && ch <= L'Z') ? ch + 32 : (ch > 31 && ch < 127) ? ch : '?'); }
        s[m] = 0;
        const bool allow = strstr(s, "shitty") || strstr(s, "rgs_pressure_kickflip") || strstr(s, "sws_pressure_kickflip")
            || (on == 2 && strstr(s, "pressure"));          // (v78) mode 2: the pressure flips stay (they do not flick: the finger flips)
        g_muteSave[g_muteN].def = def; g_muteSave[g_muteN].was = def[FTD_MUTE]; g_muteN++;
        if (allow) kept++; else { if (!def[FTD_MUTE]) muted++; def[FTD_MUTE] = 1; }
    }
    g_muteOn = true;
    if (!g_muteTold) { g_muteTold = true; Log("trick mute: %d flip trick definitions in the game's list -- %d muted while a hand is on the board, %d left on (the no comply's two and the low-pop ollies)", num, muted, kept); }
    return muted;
}
int SafeTrickMute(int on) { __try { return TrickMute(on); } __except (GrabFilter(GetExceptionCode())) { g_muteOn = false; g_muteN = 0; return -2; } }
// HJN_TrickMute(1 / 0) -> definitions muted (1) or put back (0); -1 = the trick list could not be reached
int nTrickMute(const Lua& lua) { double v = 0; ArgNum(lua, v); lua.set_integer(g_hooked ? SafeTrickMute(v >= 2 ? 2 : v != 0 ? 1 : 0) : 0); return 1; }   // (v101: not on another game build)
// (v74) HJN_Held() -> "<our trick mute on 0/1> <definitions muted in the game's list right now> <definitions in the list>
// <the controller's bumper byte, hex> <the skater's grab byte> <our bumper mask live 0/1>" -- logged with every Y on foot
// (3 Oct, 19:47:35: six presses of Y on foot in five seconds and the game put the board down for none of them)
int HeldState(char* out, size_t n) {
    int muted = -1, num = -1;
    uint8_t* fth = LateHandler();
    uint8_t* data = fth ? *(uint8_t**)(fth + FTH_DATA) : nullptr;
    if (data && PtrOk(data, FTDL_LIST + 0x10)) {
        uint8_t** list = *(uint8_t***)(data + FTDL_LIST);
        const int32_t cnt = *(const int32_t*)(data + FTDL_LIST + 8);
        if (list && cnt >= 1 && cnt <= 512 && PtrOk(list, (size_t)cnt * 8)) {
            num = cnt; muted = 0;
            for (int i = 0; i < cnt; i++) if (PtrOk(list[i], 0x70) && list[i][FTD_MUTE]) muted++;
        }
    }
    const int bump = g_pc ? ((const uint8_t*)g_pc)[PC_BUMPERS] : 0;
    const int grab = g_skater ? *((const uint8_t*)g_skater + SK_GRAB) : -1;
    return snprintf(out, n, "%d %d %d %02x %d %d", g_muteOn ? 1 : 0, muted, num, bump & 0xff, grab, (g_bumpMaskUntil && GetTickCount64() < g_bumpMaskUntil) ? 1 : 0);
}
int SafeHeld(char* out, size_t n) { __try { return HeldState(out, n); } __except (GrabFilter(GetExceptionCode())) { out[0] = 0; return 0; } }
// ==== (v85) THE GAME'S POWERSLIDE GATE =================================================================================
// "Right after a 180 hippie jump or a mini it blocks the power slide input -- I can't do power slides after that."
// ASessionPlayerController::Skate_CanPowerSlide (0xf9df20) says no while: the skater's flags at +0x710 have bit 1 (the
// crouch) or bit 2 (a pop pending); the timer at skater+0x8e8 is above 0; skater+0x651 bit 1; the board movement's byte at
// +0x684; the trick handler's crouch timer at +0x38 above 0; skater+0x918 bits 1-2; a primo; or the controller's byte at
// +0x780 is 0 -- that one is set only on a tick with all four stick axes (+0x728..+0x734) within 0.0001 of centre, and
// cleared when a stick gesture is not a slide. HJN_SlideGate() hands these to the Lua, which logs every change that lasts;
// HJN_CrankFix() finishes a crouch the handler was left holding (its own ResetCrank, which does nothing unless the skater's
// crank bit at +0x580 or a pending trick is there: the bit is lent to it for the call) -- the one stuck state known: a
// crouch timer running with both sticks at rest "broke powerslides until a flip trick completed it".
constexpr uintptr_t RVA_RESET_CRANK = 0x1030410;   // FlipTricksHandler::ResetCrank()
typedef void (*ResetCrankFn)(void* fth);
bool SlideGate(char* out, size_t n) {
    const uint8_t* pc = (const uint8_t*)g_pc;
    if (!pc) return false;
    const uint8_t* sk = *(const uint8_t* const*)(pc + PC_SKATER);
    const uint8_t* fth = *(const uint8_t* const*)(pc + PC_FLIPTRICKS);
    const uint8_t* opt = *(const uint8_t* const*)(pc + 0x690);
    if (!sk || !fth) return false;
    const uint8_t* bd = *(const uint8_t* const*)(sk + SK_BOARD);
    const uint8_t* bm = bd ? *(const uint8_t* const*)(bd + BD_MOVE) : nullptr;
    const float* st = (const float*)(pc + 0x728);
    snprintf(out, n, "%u %u %.3f %u %u %u %.3f %u %.4f %.4f %.4f %.4f %u %u %u %.0f %u",
        (unsigned)sk[0x710], (unsigned)sk[0x651], *(const float*)(sk + 0x8e8), (unsigned)sk[0x918], (unsigned)sk[SK_PRIMO], bm ? (unsigned)bm[0x684] : 0u,
        *(const float*)(fth + 0x38), (unsigned)pc[0x780], st[0], st[1], st[2], st[3], opt ? (unsigned)((*(const uint32_t*)(opt + 0x38) >> 12) & 1) : 9u,
        (unsigned)sk[SK_FOOTPOS], (unsigned)sk[SK_FOOTPOS + 1], bm ? *(const float*)(bm + BM_DECK_YAW) : 0.0f, bm ? (unsigned)bm[BM_MODE] : 0u);
    return true;
}
int SafeSlideGate(char* out, size_t n) { __try { return SlideGate(out, n) ? 1 : 0; } __except (GrabFilter(GetExceptionCode())) { return 0; } }
int nSlideGate(const Lua& lua) { char out[200] = ""; SafeSlideGate(out, sizeof(out)); lua.set_string(out); return 1; }
int CrankFix() {
    uint8_t* pc = (uint8_t*)g_pc;
    if (!pc || !g_hooked) return 0;
    uint8_t* sk = *(uint8_t**)(pc + PC_SKATER);
    uint8_t* fth = *(uint8_t**)(pc + PC_FLIPTRICKS);
    if (!sk || !fth) return 0;
    const float t0 = *(const float*)(fth + 0x38); const uint8_t b0 = sk[0x710], c0 = sk[0x580];
    uint8_t* exe = (uint8_t*)GetModuleHandleW(nullptr);
    sk[0x580] |= 0x01;                                    // (lent: ResetCrank does nothing without it or a pending trick)
    ((ResetCrankFn)(exe + RVA_RESET_CRANK))(fth);
    if (!(c0 & 0x01)) sk[0x580] &= (uint8_t)~0x01;
    int how = 1;
    if (*(const float*)(fth + 0x38) > 0.0f) { memset(fth + 0x38, 0, 8); how = 2; }
    Log("crank reset (%s): the trick handler's crouch timer %.2f s -> %.2f, the skater's flags at +0x710 %02x -> %02x",
        how == 1 ? "the game's own ResetCrank" : "and the timer by hand", t0, *(const float*)(fth + 0x38), (unsigned)b0, (unsigned)sk[0x710]);
    return how;
}
int SafeCrankFix() { __try { return CrankFix(); } __except (GrabFilter(GetExceptionCode())) { Log("fault in the crank reset"); return 0; } }
int nCrankFix(const Lua& lua) { lua.set_integer(SafeCrankFix()); return 1; }
int nHeld(const Lua& lua) { char out[96] = ""; SafeHeld(out, sizeof(out)); lua.set_string(out); return 1; }
// (v77) HJN_DeckOver() -> "<cm the drawn deck's centre is over the ground under it>" ("" = no deck, or no ground within 4 m).
// For the finger flip: the game's "in the air" starts with the flick, 0.1-0.15 s before the board leaves the ground -- the
// hand let go "as soon as the input was done". The Lua times the release from the board's own lift-off with this.
bool DeckOver(char* out, size_t n) {
    const uint8_t* sk = (const uint8_t*)g_skater;
    if (!sk) return false;
    const uint8_t* bd = *(const uint8_t* const*)(sk + SK_BOARD);
    const uint8_t* deck = bd ? *(const uint8_t* const*)(bd + BD_DECK) : nullptr;
    if (!deck) return false;
    const V3 p = *(const V3*)(deck + SC_C2W + 0x10);
    if (!finite3(p)) return false;
    const void* world = SkaterWorld();
    if (!world) return false;
    RayHit h;
    if (!Ray(world, add(p, v3(0.0f, 0.0f, 30.0f)), add(p, v3(0.0f, 0.0f, -400.0f)), h)) return false;
    snprintf(out, n, "%.1f", p.z - h.p.z);
    return true;
}
int nDeckOver(const Lua& lua) {
    char b[48] = ""; bool ok = false;
    __try { ok = DeckOver(b, sizeof(b)); } __except (GrabFilter(GetExceptionCode())) { ok = false; }
    lua.set_string(ok ? b : "");
    return 1;
}

// ==== (v69) A TRICK'S NAMES WITH A ROTATION ===========================================================================
// "When I do a 180 no comply, it calls it a FS or BS pressure kickflip": a UFlipTrickDefinition keeps, beside DisplayName,
// a TMap<EEventLineTrickRotationType, FText> at +0x80 (_displayNamesWithRotation: Frontside, Backside and their 360s) that
// UFlipTrickDefinition::GetDisplayName(rotation) looks in first. UE4SS's Lua has no maps, so the map is written here: its
// elements are 0x28 bytes (the key byte at 0, the FText at +8), four of them, as loaded from the asset. The FText comes
// from a name (FText::FromName) and is never released; what it replaces is kept, and put back by an empty text.
// HJN_TrickName(definition address, rotation key, text) -> 1 if that key's text was written
constexpr int FTD_ROTNAMES = 0x80;
struct SavedRotName { uintptr_t def; int key; FTextBlob old; bool used; };
SavedRotName g_rotSaved[32];
int TrickName(uintptr_t def, int key, const char* text) {
    uint8_t* d = (uint8_t*)def;
    if (!PtrOk(d, FTD_ROTNAMES + 0x50)) return 0;
    uint8_t* data = *(uint8_t**)(d + FTD_ROTNAMES);
    const int32_t num = *(const int32_t*)(d + FTD_ROTNAMES + 8);
    if (!data || num < 1 || num > 16 || !PtrOk(data, (size_t)num * 0x28)) return 0;
    SavedRotName* sv = nullptr;
    for (int i = 0; i < 32 && !sv; i++) if (g_rotSaved[i].used && g_rotSaved[i].def == def && g_rotSaved[i].key == key) sv = &g_rotSaved[i];
    for (int i = 0; i < num; i++) {
        uint8_t* e = data + (size_t)i * 0x28;
        if (e[0] != (uint8_t)key) continue;
        if (text && text[0]) {
            FTextBlob t;
            if (!MakeText(text, &t)) return 0;
            if (!sv) for (int j = 0; j < 32 && !sv; j++) if (!g_rotSaved[j].used) { sv = &g_rotSaved[j]; sv->used = true; sv->def = def; sv->key = key; memcpy(&sv->old, e + 8, sizeof(FTextBlob)); }
            memcpy(e + 8, &t, sizeof(FTextBlob));
        } else {
            if (!sv) return 0;
            memcpy(e + 8, &sv->old, sizeof(FTextBlob));
        }
        return 1;
    }
    return 0;
}
int SafeTrickName(uintptr_t def, int key, const char* text) { __try { return TrickName(def, key, text); } __except (GrabFilter(GetExceptionCode())) { return 0; } }
int nTrickName(const Lua& lua) {
    double a = 0, key = -1; std::string text;
    ArgNum(lua, a); ArgNum(lua, key); ArgStr(lua, text);
    if (!g_hooked) { lua.set_integer(0); return 1; }               // (v101) another build of the game: its addresses are not these
    const uintptr_t p = (a > 65536.0 && a < 1.8e19) ? (uintptr_t)a : 0;
    lua.set_integer((p && key >= 0 && key < 256) ? SafeTrickName(p, (int)key, text.c_str()) : 0);
    return 1;
}

// ==== (v66) NO IMPACT BAIL FOR A MOMENT ===============================================================================
// The no comply plants the front foot on the ground while the game counts you as in the air -- and in the air ANY hit on a
// body part other than a hand or an arm bails you (ASkaterCharacterBase::ImpactBailCheck: the threshold is 10000 riding, 0
// falling). Every no comply of 3 Oct bailed there, 0.1 s after the pop ("his foot plants underneath the ground"). While the
// Lua holds the window open (HJN_Set("nobail", seconds), refreshed each frame; it shuts by itself) that check is passed over
// for our skater; the board's own collision bails are another path and still run.
constexpr uintptr_t RVA_IMPACT_BAIL = 0xff66e0;   // ASkaterCharacterBase::ImpactBailCheck(const FVector& impulse, const FHitResult&)
typedef void (*ImpactBailFn)(void* skater, const float* impulse, const uint8_t* hit);
ImpactBailFn o_ImpactBail = nullptr; int g_noBailHook = 0; volatile ULONGLONG g_noBailUntil = 0; int g_noBailSkips = 0, g_noBailTold = 0;
void NoBailNote(const float* imp, const uint8_t* hit) {
    wchar_t w[64]; char s[64]; int m = 0;
    const uint32_t n = ((FNameToStrFn)(Exe() + RVA_FNAME_TOSTR_BUF))(hit + 0x80, w, 64);       // FHitResult::MyBoneName
    for (uint32_t i = 0; i < n && i < 63; i++) s[m++] = (char)((w[i] > 31 && w[i] < 127) ? w[i] : '?');
    s[m] = 0;
    Log("no bail: a hit on %s (impulse %.0f) passed over", s, sqrtf(imp[0] * imp[0] + imp[1] * imp[1] + imp[2] * imp[2]));
}
void hkImpactBail(void* sk, const float* imp, const uint8_t* hit) {
    if (g_noBailUntil && sk && sk == g_skater && imp && hit && GetTickCount64() < g_noBailUntil) {
        g_noBailSkips++;
        if (g_noBailTold < 4) { g_noBailTold++; __try { NoBailNote(imp, hit); } __except (EXCEPTION_EXECUTE_HANDLER) {} }
        return;
    }
    if (o_ImpactBail) o_ImpactBail(sk, imp, hit);
}
void NoBailPlace() {
    static const uint8_t e[14] = { 0x40, 0x55, 0x53, 0x57, 0x48, 0x8b, 0xec, 0x48, 0x81, 0xec, 0x80, 0x00, 0x00, 0x00 };
    void *nx = nullptr, *og = nullptr;
    if (HostPlace(Exe() + RVA_IMPACT_BAIL, (const void*)&hkImpactBail, 14, e, sizeof(e), "ASkaterCharacterBase::ImpactBailCheck", false, &nx, &og)) { o_ImpactBail = (ImpactBailFn)nx; g_noBailHook = 1; }
}
void NoBail(double secs) {
    if (secs <= 0) { g_noBailUntil = 0; return; }
    if (g_noBailHook == 0) {
        g_noBailHook = -1;
        if (g_hooked) { __try { NoBailPlace(); } __except (GrabFilter(GetExceptionCode())) { g_noBailHook = -1; } }
        Log("no bail: the impact-bail check %s", g_noBailHook == 1 ? "is hooked" : "could NOT be hooked on this game build -- the no comply's planted foot can bail you");
    }
    if (g_noBailHook != 1) return;
    if (!g_noBailUntil) g_noBailTold = 0;
    g_noBailUntil = GetTickCount64() + (ULONGLONG)(secs * 1000.0);
}
// HJN_NoBail() -> "<hook: 1 in, 0 not tried, -1 refused> <hits passed over so far>"
int nNoBail(const Lua& lua) {
    char out[48]; snprintf(out, sizeof(out), "%d %d", g_noBailHook, g_noBailSkips);
    lua.set_string(out);
    return 1;
}

// HJN_Set(name, value): grab (0/1), strength (0..1), handup (cm)
// (v64) THE STICK'S BANK OFF. In the game's foot-stick control mode the left stick's sideways push banks the board (the
// triggers lean it as well), and that spoils a stick trick. ASkateboardPhysics::Skate_BankLeft/Right(float) write the bank
// input (-value into the movement component's +0x154); with the stick's bank off their first byte is a `ret` (a RIP-relative
// andps follows the first instruction, so no detour), put back when it is on again. The triggers' lean is another path
// (Skate_LeanLeft/Right -> USkateboardExMovementComponent::LeanLeft/Right) and keeps working
constexpr uintptr_t RVA_BANK_LEFT = 0x1007d00, RVA_BANK_RIGHT = 0x1007d30;
int g_bankPatched = 0; uint8_t g_bankSaved[2] = { 0x0f, 0x0f };
void StickBank(bool on) {
    const int wantPatched = on ? 0 : 1;
    if (!g_hooked || g_bankPatched == wantPatched) return;
    uint8_t* exe = Exe();
    const uintptr_t rvas[2] = { RVA_BANK_LEFT, RVA_BANK_RIGHT };
    static const uint8_t expect[6] = { 0x0f, 0x28, 0xc1, 0x0f, 0x54, 0x05 };
    for (int i = 0; i < 2; i++) {
        uint8_t* p = exe + rvas[i];
        if (wantPatched && memcmp(p, expect, 6) != 0) { Log("stick bank: Skate_Bank%s does not start as expected -- left alone", i ? "Right" : "Left"); return; }
        if (!wantPatched && p[0] != 0xC3) continue;
        DWORD old = 0;
        if (!VirtualProtect(p, 16, PAGE_EXECUTE_READWRITE, &old)) { Log("stick bank: VirtualProtect failed"); return; }
        if (wantPatched) { g_bankSaved[i] = p[0]; p[0] = 0xC3; } else { p[0] = g_bankSaved[i]; }
        VirtualProtect(p, 16, old, &old);
        FlushInstructionCache(GetCurrentProcess(), p, 16);
    }
    g_bankPatched = wantPatched;
    Log("stick bank: the stick's bank is %s", on ? "ON again (the game's own: Skate_BankLeft/Right restored)" : "OFF (Skate_BankLeft/Right return at once; the triggers' lean is untouched)");
}
int nSet(const Lua& lua) {
    std::string k; double v = 0;
    ArgStr(lua, k); ArgNum(lua, v);
    if (k == "hopknee" || k == "landknee") {                     // (v96) in front of the chain, not in it: the compiler takes 128 links (C1061) and v95's has 117
        if (k == "hopknee") g_hopKnee = v != 0 ? 1 : 0;          //   a hop's air: every solve on a pose takes the knee's way the pose came in with (0 = v95: re-read after each solve)
        else g_landKnee = v != 0 ? 1 : 0;                        //   a turned landing: the knee's way is blended from the air's to the pose's, as the feet are (0 = v95)
        lua.set_integer(1);
        return 1;
    }
    if (k == "hopturnleft" || k == "hopturn" || k == "hopfree" || k == "anklim") {   // (v100) in front of the chain
        if (k == "hopturnleft") g_hopTurnLeft = std::isfinite(v) ? (float)v : 0.0f;     //   how far the body still has to turn before its landing heading, deg (each pose of a hop's air)
        else if (k == "hopturn") g_planTurn = v != 0 ? 1 : 0;        //   a turned hop's feet are carried to their landing spots as its turn completes
        else if (k == "hopfree") g_hopFree = v != 0 ? 1 : 0;         //   in the air: the feet turn with their shins, a changed leg bends over its own foot
        else g_ankLim = clampf((float)v, 0.0f, 90.0f);               //   the twist a foot may keep against its shin in the air, deg
        lua.set_integer(1);
        return 1;
    }
    if (k == "shintight") { g_unstrLong = v != 0 ? 1.012f : 1.04f; lua.set_integer(1); return 1; }   // (v99) a hop's leg bone is put back from half a centimetre over its own length (0 = from 4 %)
    if (k == "sockturn" || k == "sockon" || k == "legroll" || k == "hophips" || k == "plswivel" || k == "plankle") {   // (v99) in front of the chain as well
        int r = 1;
        if (k == "sockturn") { r = SafeSockTurn((int)(v + 0.5)) ? 1 : 0; if (r && (int)(v + 0.5) == 4 && (g_sockMir[0] || g_sockMir[1])) r = 2; }   // (v103) 4 = the poses after a goofy rider's switch plant; 2 back = a socket is held: call on   // (v100: 2 = a swap begins; every pose of it 1 = the stance flag names your own stance, 3 = the other)   //   1 = this pose's foot sockets are turned half round about the deck (0 back = not done: the Lua zeroes the IK weights instead); 2 = they are noted
        else if (k == "sockon") { g_sockOn = v != 0 ? 1 : 0; if (v != 0) g_sockBad = 0; }
        else if (k == "legroll") g_hingeOn = v != 0 ? 1 : 0;         //   a solved leg's thigh and shin are rolled onto the knee's hinge
        else if (k == "hophips") g_hopHipOn = v != 0 ? 1 : 0;        //   a hop's hip joints go back into their sockets
        else if (k == "plswivel") g_plSwivel = clampf((float)v, 0.0f, 1.0f);   //   the share of the hips' turn the standing plant foot follows
        else g_plAnkle = v != 0 ? 1 : 0;                             //   the plant foot's way back: its turn blended in the ankle
        lua.set_integer(r);
        return 1;
    }
    if (k == "swapturn" || k == "stquiet" || k == "shinride") {  // (v97) in front of the chain too
        if (k == "swapturn") {                                   //   1 = a stance swap is on and you ride regular, 2 = ...and you ride goofy; 0 = it is over (the turn ends with the game's own flag)
            if (v >= 1) {                                        //   (v98) 3 / 4 = the same, and the turn is the anim graph's own: nothing is turned in the pose
                const int m = (int)(v + 0.5);
                g_swapHome = (m == 2 || m == 4) ? 1 : 0; g_swapInPose = (m <= 2) ? 1 : 0;
                g_swapEnd = 0; g_swapEndN = 0; g_swapPoses = 0; g_swapT0 = GetTickCount64(); g_swapOn = 1;
            }
            else if (g_swapOn) g_swapEnd = 1;
        }
        else if (k == "stquiet") g_stGuard = v != 0 ? 1 : 0;     //   SessionTweaks' idle re-learn waits while a pose of ours is drawn (0 = off)
        else g_shinRideOn = v != 0 ? 1 : 0;                      //   a hop's straight or squeezed leg: the knee the way the shin stands on its foot riding (0 = v96: toward the toes)
        lua.set_integer(1);
        return 1;
    }
    bool chainOn = false;                                        // (v96) see the cut at "menuown"
    if (k == "grab") { if (g_grabOn != (v != 0)) Log("grab arms %s", v != 0 ? "ON" : "off"); g_grabOn = v != 0 ? 1 : 0; }
    else if (k == "strength") g_strength = (float)v;
    else if (k == "handup") g_handUp = (float)v;
    else if (k == "tweak") g_tweakMax = (float)v;
    else if (k == "tweakshare") g_tweakShare = (float)v;
    else if (k == "legs") g_legs = v != 0 ? 1 : 0;
    else if (k == "lean") g_leanMax = (float)v;
    else if (k == "handclose") g_closeMax = clampf((float)v, 0.0f, 30.0f);   // (v84) cm the hips may go toward a grabbing hand's spot
    else if (k == "pull") g_pullMax = (float)v;
    else if (k == "feet") g_feet = v != 0 ? 1 : 0;
    else if (k == "elbowout") g_elbowOut = (float)v;
    else if (k == "kneeaway") g_kneeAway = v != 0 ? 1 : 0;
    else if (k == "guard") g_guard = (int)v;
    else if (k == "revertctl") g_revertCtl = v != 0 ? 1 : 0;
    else if (k == "handfull") g_handFull = (float)v;
    else if (k == "ease") g_ease = (float)v;
    else if (k == "tweakmode") g_tweakMode = (int)v;
    else if (k == "fithand") g_fitHand = (float)v;
    else if (k == "fitmove") g_fitMove = (float)v;
    else if (k == "holdbleed") g_holdBleed = (float)v;
    else if (k == "fitgain") g_fitGain = (float)v;
    else if (k == "heel") g_heelMax = (float)v;
    else if (k == "legsearch") g_legSearch = v != 0 ? 1 : 0;
    else if (k == "nosepitch") g_nosePitch = (float)v;
    else if (k == "tailpitch") g_tailPitch = (float)v;
    else if (k == "boardease") g_boardEase = (float)v;
    else if (k == "edgeroll") g_edgeRoll = (float)v;
    else if (k == "armsearch") g_armSearch = v != 0 ? 1 : 0;
    else if (k == "melonback") g_melonBack = (float)v;
    else if (k == "profilelift") g_profileLift = (float)v;
    else if (k == "tailfromnose") g_tailFromNose = v != 0 ? 1 : 0;
    else if (k == "indypitch") g_indyPitch = (float)v;
    else if (k == "melonpitch") g_melonPitch = (float)v;
    else if (k == "ownspots") g_ownSpots = v != 0 ? 1 : 0;
    else if (k == "deckhalflen") g_deckHalfLen = (float)v;
    else if (k == "deckhalfwidth") g_deckHalfWidth = (float)v;
    else if (k == "spotup") g_spotUp = (float)v;
    else if (k == "spotin") g_spotIn = (float)v;
    else if (k == "footslide") g_footSlide = (float)v;
    else if (k == "deckup") g_deckUpMode = v != 0 ? 1 : 0;
    else if (k == "melonlift") g_melonLift = (float)v;
    else if (k == "indylift") g_indyLift = (float)v;
    else if (k == "melondrop") g_melonDrop = (float)v;
    else if (k == "indydrop") g_indyDrop = (float)v;
    else if (k == "leantuck") g_leanTuck = (float)v;
    else if (k == "melonfwd") g_melonFwd = (float)v;
    else if (k == "spotupedge") g_spotUpEdge = (float)v;
    else if (k == "deckcentre") g_deckCentre = (float)v;
    else if (k == "deckmeasured") g_deckMeasured = v != 0 ? 1 : 0;
    else if (k == "rolllevel") g_rollLevel = v != 0 ? 1 : 0;
    else if (k == "riding") g_riding = v != 0 ? 1 : 0;
    else if (k == "fitcap") g_fitCap = (float)v;
    else if (k == "decklag") g_deckLag = (float)v;
    else if (k == "handavoid") g_handAvoid = v != 0 ? 1 : 0;
    else if (k == "lateblock") g_lateBlock = v != 0 ? 1 : 0;
    else if (k == "catchhold") g_catchHold = v != 0 ? 1 : 0;   // (v55)
    else if (k == "grabstance") g_grabStance = v != 0 ? 1 : 0;   // (v58)
    else chainOn = true;                                         // (v96) the chain is CUT IN TWO here: the compiler takes 128 nested blocks (C1061: "blocks nested too deeply") and it had 117
    if (!chainOn) { lua.set_integer(1); return 1; }              //   a key of the first half: done
    if (k == "menuown") g_menuOwn = v != 0 ? 1 : 0;              // (v60)
    else if (k == "nobail") NoBail(v);                           // (v66) seconds the impact-bail check is passed over (0 = shut now)
    else if (k == "footground") g_footGroundUntil = (v > 0) ? GetTickCount64() + (ULONGLONG)(v * 1000.0) : 0;   // (v67) seconds the feet are kept over the ground
    else if (k == "plantstep") g_plantStepS = clampf((float)v, 0.03f, 0.5f);      // (v73) seconds the plant foot takes from the ground to the board
    else if (k == "plantlead") g_plantLead = clampf((float)v, -300.0f, 800.0f);   // (v73) it leaves the ground when the deck's rise is down to this, cm/s
    else if (k == "bonehips") g_boneHips = clampf((float)v, 10.0f, 95.0f);        // (v73) a rolling grab's hips: cm over the deck
    else if (k == "bonehipshare") g_boneHipShare = clampf((float)v, 0.0f, 0.9f);  // (v73) the share of the back's bend made at the hips
    else if (k == "bonealongf") g_boneAlongF = clampf((float)v, -40.0f, 40.0f);   // (v76) the rolling grab's front hand: cm along the board, + toward the front foot
    else if (k == "bonealongb") g_boneAlongB = clampf((float)v, -40.0f, 40.0f);   // (v76) ...and its back hand
    else if (k == "plantfoot") g_plantForce = (v == 0 || v == 1) ? (int)v : -1;        // (v80) which foot plants (-1 = the first one down)
    else if (k == "hoplegrate") g_hopLegRate = clampf((float)v, 30.0f, 2000.0f);   // (v80) cm/s a hop's leg may lengthen
    else if (k == "posehold") { g_phFrames = (int)clampf((float)v, 0.0f, 12.0f); g_phBlend = 0; }   // (v84) poses the body is held over a stance swap
    else if (k == "poselat") g_phTail = (int)clampf((float)v, 0.0f, 40.0f);   // (v96) poses after its blend the hips keep their place across the board (the game's own cross-fade); 0 = v95
    else if (k == "feethold") g_feetHoldUntil = (v > 0) ? GetTickCount64() + (ULONGLONG)(v * 1000.0) : 0;   // (v79) seconds both feet stand on their riding spots
    else if (k == "plantmode") g_plantMode = (v >= 2) ? 2 : 1;                        // (v78) 1 = the soft plant (the body let down, nothing pinned), 2 = v77's pinned plant
    else if (k == "plantfwd") g_plantFwd = (v <= -90.0) ? -100.0f : clampf((float)v, -30.0f, 40.0f);   // (v89) the soft plant: cm the foot goes down ahead of where it rides; -100 = off
    else if (k == "plantclear") g_plantClear = clampf((float)v, 0.0f, 40.0f);     // (v76) cm the planted foot stands from the board's centre line, at least
    else if (k == "plantback") g_plantBack = clampf((float)v, 0.0f, 1.0f);        // (v75) the share of the planted foot's drift along the board that is kept
    else if (k == "bonesplay") g_boneSplay = clampf((float)v, 0.0f, 1.5f);       // (v75) how far the knees part in a rolling grab's squat (0.45 = about 25 deg)
    else if (k == "bonemutein") g_boneMuteIn = clampf((float)v, 0.0f, 30.0f);    // (v75) cm the rolling Mute's spot moves toward the middle of the board
    else if (k == "boneback") g_boneBack = clampf((float)v, 0.0f, 40.0f);         // (v73) cm the hips go back from the grabbed edge in a full squat
    else if (k == "plant") {
        const ULONGLONG nowT = GetTickCount64();
        if (v > 0 && (g_plantUntil == 0 || nowT >= g_plantUntil)) g_plantDone = false;   // (v73) a new window: a new plant
        g_plantUntil = (v > 0) ? nowT + (ULONGLONG)(v * 1000.0) : 0;
    }
    else if (k == "plantfold") g_plantFold = clampf((float)v, 0.0f, 0.8f);     // (v89) 0 = off
    else if (k == "plantroom") g_plantRoom = clampf((float)v, 0.25f, 0.8f);   // (v89) 0.25 = as good as off
    else if (k == "hipfix") g_hipFixOn = v != 0 ? 1 : 0;                     // (v94) 0 = the hip joints are left where the game's pose has them
    else if (k == "hopcarry") g_planCarry = (int)clampf((float)v, 0.0f, 2.0f);   // (v95) feet carried to the last landing's spots: 0 never, 1 only in a hop that does not turn, 2 always (v94)
    else if (k == "holdplace") g_holdPlace = v != 0 ? 1 : 0;                 // (v95) a 180's landing: the hips' place has the mesh's lag taken out, as the shoulders' heading has
    else if (k == "kneetoes") g_kneeToes = v != 0 ? 1 : 0;                   // (v95) a hop's poses: a nearly straight leg bends its knee over its toes
    else if (k == "landown") g_ownHold = clampf((float)v, 0.0f, 120.0f);     // (v96) the longest, in seconds from a straight hop's touchdown, a leg the game hands in squeezed is drawn its own length (0 = v95)
    else if (k == "landownfade") g_ownFade = clampf((float)v, 0.05f, 3.0f);  // (v96) ...and the seconds it is handed back over
    else if (k == "landownturn") g_ownTurn = v != 0 ? 1 : 0;                 // (v96) ...after a turned landing too (off: see LandOwnW)
    else if (k == "legsolve") g_unstrSolve = v != 0 ? 1 : 0;                 // (v95) a leg whose bones are put back to their length keeps its ankle where the pose had it
    else if (k == "backflat") g_bkFlat = clampf((float)v, 0.0f, 1.0f);       // (v96) the soft plant's back foot: the share of its tilt off the deck taken out
    else if (k == "kneekeep") g_kneeKeep = v != 0 ? 1 : 0;                   // (v96) the unplanned knee keeps its side where the game's leg does not say
    else if (k == "leglinger") { g_legLingerUntil = v > 0 ? GetTickCount64() + (ULONGLONG)(clampf((float)v, 0.0f, 10.0f) * 1000.0f) : 0; g_legLingerOk = 0; g_legLingered = 0; }   // (v102)
    else if (k == "plantflex") g_plFlex = clampf((float)v, 0.0f, 120.0f);     // (v96) the least a planted foot's ankle is bent to (shin to toe, deg) before its heel comes up; 0 = off
    else if (k == "plantheelmax") g_plHeelMax = clampf((float)v, 0.0f, 60.0f); // (v96) the most its heel comes up for that, deg
    else if (k == "plantstick") g_plStick = v != 0 ? 1 : 0;                  // (v95) the plant foot keeps its place in the world while it stands
    else if (k == "plantstand") g_plStandMax = clampf((float)v, 0.0f, 1.0f); // (v95) the longest it stands, s (0 = until the board's top)
    else if (k == "plantin") g_plStepIn = clampf((float)v, 0.02f, 0.4f);      // (v94) seconds the plant foot takes from the board to its place on the ground
    else if (k == "plantpeel") g_plPeel = clampf((float)v, 0.0f, 60.0f);      // (v94) deg its heel peels up as it leaves the ground
    else if (k == "planttoein") g_plToeIn = clampf((float)v, 0.0f, 90.0f);    // (v94) deg its toes stand in from the board's line (90 = square to the board)
    else if (k == "gluemin") g_glueMin = clampf((float)v, 0.3f, 0.8f);          // (v88) the boneless's glued leg: least hip-to-ankle length, as a share of the leg
    else if (k == "glueraise") g_glueRaiseMax = clampf((float)v, 0.0f, 40.0f);  // (v88) ...and the most the hips are raised for it, cm
    else if (k == "plantmax") g_plantMax = clampf((float)v, 0.0f, 90.0f);   // (v71) the most the hips are kept down for it, cm
    else if (k == "bonelean") g_boneLeanMax = clampf((float)v, 0.0f, 85.0f);   // (v72) the most the back bends toward the board in a rolling grab, deg
    else if (k == "yaw180") g_yaw180Until = (v > 0) ? GetTickCount64() + (ULONGLONG)(v * 1000.0) : 0;   // (v71) seconds the pose is turned half round
    else if (k == "footankle") g_footAnkle = clampf((float)v, 0.0f, 40.0f);   // (v67) cm the ankle stays over the ground
    else if (k == "foottoe") g_footToe = clampf((float)v, 0.0f, 20.0f);
    else if (k == "footheel") g_footHeel = clampf((float)v, 0.0f, 90.0f);      // (v91) deg a standing foot's heel may be up; 90 = as the animation has it
    else if (k == "replayclicks") g_replayClicks = v != 0 ? 1 : 0;   // (v67) 0 = the replay editor's stick clicks go the game's usual way
    else if (k == "bumpermask") g_bumpMaskUntil = (v > 0 && g_xiUser >= 0) ? GetTickCount64() + (ULONGLONG)(v * 1000.0) : 0;   // (v68) seconds RB is kept from the game (only with an XInput pad to read it from)
    else if (k == "offboard") g_offBoard = v != 0 ? 1 : 0;       // (v84)
    else if (k == "bail") g_bail = v != 0 ? 1 : 0;               // (v63)
    else if (k == "posedump") PdSwitch(v != 0);                    // (v94) 1 = every trick's poses to ExpandedTricks.poses.bin (the default), 0 = off
    else if (k == "stickbank") StickBank(v != 0);                  // (v64) 1 = the game's own, 0 = the stick's bank off
    else if (k == "handaim") g_handAim = (int)v;
    else if (k == "fingercurl") g_fingerCurl = (float)v;
    else if (k == "curlroot") g_curlJoint[0] = (float)v;   // (v52)
    else if (k == "curlmid") g_curlJoint[1] = (float)v;
    else if (k == "curltip") g_curlJoint[2] = (float)v;
    else if (k == "sidemax") g_sideMax = (float)v;
    else if (k == "twistmax") g_twistMax = (float)v;
    else if (k == "shiftmax") g_shiftMax = (float)v;
    else if (k == "dblfront") g_dblFront = v != 0 ? 1 : 0;
    else if (k == "double") {
        const int d = IsDouble((int)v) ? (int)v : 0;
        if (d != g_double) Log("two-hand grab: %d (front hand %s)", d, g_dblFront ? "R" : "L");
        g_double = d;
    }
    else if (k == "mirror") { if (g_mirror != (v != 0 ? 1 : 0)) Log("pose mirror %s: the animation's left hand is the mesh's %s hand", v != 0 ? "ON" : "off", v != 0 ? "RIGHT" : "left"); g_mirror = v != 0 ? 1 : 0; }
    else if (k == "switch") { if (g_switchNow != (v != 0 ? 1 : 0)) Log("riding switch %s: the grab numbers' switch add-ons are %s", v != 0 ? "ON" : "off", v != 0 ? "in force" : "off"); g_switchNow = v != 0 ? 1 : 0; }
    else { lua.set_integer(0); return 1; }
    lua.set_integer(1);
    return 1;
}

// HJN_Stats() -> one line for the Lua log
int nStats(const Lua& lua) {
    char b[4400];
    const float upOff = acosf(clampf(g_dUpL.z, -1.0f, 1.0f)) * 57.2957795f;   // the learned mesh-up vs the deck's own Z
    snprintf(b, sizeof(b), "native: hook %s, %ld poses seen, %ld grab frames posed, %ld faults, %ld size mismatches | "
             "L w %.2f gap %.0f -> %.0f cm (arm %.0f) | R w %.2f gap %.0f -> %.0f cm (arm %.0f) | board tipped %.0f deg, "
             "feet short L %.0f R %.0f cm | lean %.0f deg + hips %.0f cm to the hand, board shift %.0f cm (fit leaves the grab spot %.0f cm off the wrist), feet to the deck L %.0f R %.0f cm (offset %s), "
             "deck vs skeleton board %.0f deg %.0f cm | DECK: tweak held %.0f deg height %+.0f cm, drawn deck %s, rising end %+.0f deg over the horizon, still %.0f deg from its aim (grab %d, feet offsets %s) | grab spot on the deck: along %+.0f across %+.0f up %+.0f cm%s%s (nose spot %s) | feet planted L %.0f R %.0f cm off (ankles over the deck L %.0f R %.0f cm, riding L %.0f R %.0f), ankle off L %.0f R %.0f deg, heel lift L %.0f R %.0f, edge roll L %+.0f R %+.0f (+ inner), knee swing L %+.0f R %+.0f, arm clear %.0f cm (elbow swung %+.0f) | legs this grab: L foot moved %.0f knee moved %.0f cm, fold %.0f%% (anim %.0f%%); "
             "R foot moved %.0f knee moved %.0f cm, fold %.0f%% (anim %.0f%%) | knee dodges %ld, guard hips %ld feet %ld, crossed landing frames held %ld"
             " | DECK FRAME: up = %s, the mesh's up learned in it (%.2f %.2f %.2f) = %.0f deg off its Z; riding ankles in it L (%+.0f %+.0f %+.0f) R (%+.0f %+.0f %+.0f) cm; top %+.0f cm (toes %+.0f, ankles %+.0f); mirror %s; deck half len %.1f half width %.1f centre %+.1f (%s), skater mesh scale %.2f; deck comp bounds R %.1f ext (%.1f %.1f %.1f) off (%+.1f %+.1f %+.1f); pitch loop sense %+d (deck yaw offset %s), roll now %+.0f; stance #%d (grab used #%d) from %d riding samples (riding now %s, %d samples toward a new stance); tilt: the deck's own pitch %+.0f (%s; this grab's estimate %+.0f) + ours %+.0f (trim %+.0f, followed so far %+.0f), own roll %+.0f, %d frames into the grab | two-hand grab %d (front hand %s; back hand spot along %+.0f across %+.0f up %+.0f), the game holds the grab %s, late-trick block %s (%ld writes), bumpers %d | torso: fold %.0f side %+.0f twist %+.0f deg, hips along %+.0f cm (arms still short L %.0f R %.0f cm); hands turned L %.0f R %.0f deg (palm check L %+.0f R %+.0f), fingers %s",
             g_hooked ? "on" : "OFF", g_calls, g_applied, g_faults, g_mismatch,
             g_lastW[0], g_lastGapBefore[0], g_lastGapAfter[0], g_lastReach[0],
             g_lastW[1], g_lastGapBefore[1], g_lastGapAfter[1], g_lastReach[1], g_lastTweak, g_lastFootMiss[0], g_lastFootMiss[1],
             g_lastLean, g_lastClose, g_lastPull, g_lastFitMiss, g_lastFeetDeck[0], g_lastFeetDeck[1], (g_footOffOk[0] && g_footOffOk[1]) ? "learned" : "NOT learned yet",
             g_lastDeckOff, g_deckShift,
             qangle(g_tq), g_tz, g_deckOk ? "read" : "NOT read", g_lastDeckPitch, g_lastFitRes, g_grabKind, (g_dFootOk[0] && g_dFootOk[1] && g_dLevelOk) ? "learned on the deck" : "NOT learned yet (ride a moment)",
             g_lastSpot.x, g_lastSpot.y, g_lastSpot.z, g_lastSpotMirrored ? " = the Nose spot mirrored" : "", (g_ownSpots && (g_grabKind == 1 || g_grabKind == 2 || g_grabKind == 100 || g_grabKind == 102)) ? " (OUR spot)" : "", g_noseSpotOk ? "learned" : "not seen yet",
             g_lastPlant[0], g_lastPlant[1], g_lastFootH[0], g_lastFootH[1], g_learnFootH[0], g_learnFootH[1], g_lastAnkle[0], g_lastAnkle[1], g_lastHeel[0], g_lastHeel[1], g_lastRoll[0], g_lastRoll[1], g_lastSwing[0], g_lastSwing[1], g_lastArmClear, g_lastArmSwing,
             g_legFoot[0], g_legKnee[0], g_legFold[0] * 100.0f, g_legAnimFold[0] * 100.0f,
             g_legFoot[1], g_legKnee[1], g_legFold[1] * 100.0f, g_legAnimFold[1] * 100.0f,
             g_kneeHits, g_guardHips, g_guardFeet, g_landCrossed,
             g_deckUpMode ? "its own Z" : "the mesh's up (learned)", g_dUpL.x, g_dUpL.y, g_dUpL.z, upOff,
             g_dFootOk[0] ? g_uFootP[0].x : 0.0f, g_dFootOk[0] ? g_uFootP[0].y : 0.0f, g_dFootOk[0] ? g_uFootP[0].z : 0.0f,
             g_dFootOk[1] ? g_uFootP[1].x : 0.0f, g_dFootOk[1] ? g_uFootP[1].y : 0.0f, g_dFootOk[1] ? g_uFootP[1].z : 0.0f,
             g_lastTop, g_lastTopToes, g_lastTopAnkles, g_mirror ? "ON (goofy/switch)" : "off",
             HalfLen(), HalfWidth(), CentreX(), g_deckMeasured ? "Lua measured the deck mesh" : (g_deckHalfLen > 0.0f ? "the setting" : (g_boundsR > 0.0f ? "from the deck's bounds" : "the 40 fallback")), g_ms,
             g_boundsR, g_boundsExt.x, g_boundsExt.y, g_boundsExt.z, g_boundsOff.x, g_boundsOff.y, g_boundsOff.z,
             g_lastSense, DeckReversed() ? "REVERSED" : "normal", g_lastRollNow, g_stCur, g_stGrab, g_dFootN, g_riding ? "yes" : "no", g_candN,
             g_pBase, g_pBaseFrom ? "remembered from the last such grab" : "first such grab: 0 assumed", g_pBaseEst, g_pFF, g_trim, g_cmdLag, g_rBase, g_grabFrames,
             (int)g_double, g_dblFront ? "R" : "L", g_lastSpot2.x, g_lastSpot2.y, g_lastSpot2.z, g_holdLive ? "yes" : "no",
             (g_lateBlock && g_pc) ? "on" : "OFF", g_lateWrites, g_pc ? SafeBumpers() : 0,
             g_lastTorso[0], g_lastTorso[1], g_lastTorso[2], g_lastTorso[3], g_lastShort[0], g_lastShort[1], g_lastWrist[0], g_lastWrist[1], g_lastPalm[0], g_lastPalm[1],
             (g_fingOk[0] && g_fingOk[1]) ? "found" : "NOT found");
    lua.set_string(b);
    return 1;
}

} // namespace

// ------------------------------------------------------------------ the UE4SS mod
class HippieNative : public RC::CppUserModBase {
  public:
    HippieNative() {
        ModName = STR("ExpandedTricksNative");
        ModVersion = STR("101");
        ModDescription = STR("Native half of the Expanded Tricks mod: grab hands, drop-ins, the settings pages");
        ModAuthors = STR("Expanded Tricks");
        Log("---- ExpandedTricksNative v%d loaded (%s)", kVersion, kBuildTag);
        InstallHook();
    }
    ~HippieNative() override {}

    // every Lua mod as it starts: ours (ExpandedTricks) gets the HJN_* functions
    auto on_lua_start(RC::StringViewType mod_name, Lua&, Lua& main_lua, Lua&, std::vector<Lua*>&) -> void override {
        if (mod_name != STR("ExpandedTricks")) return;
        try {
            main_lua.register_function("HJN_Version", &nVersion);
            main_lua.register_function("HJN_SetMesh", &nSetMesh);
            main_lua.register_function("HJN_MeshSpeed", &nMeshSpeed);
            main_lua.register_function("HJN_SetRig", &nSetRig);
            main_lua.register_function("HJN_Set", &nSet);
            main_lua.register_function("HJN_Stats", &nStats);
            main_lua.register_function("HJN_Trace", &nTrace);
            main_lua.register_function("HJN_InstantRevert", &nInstantRevert);
            main_lua.register_function("HJN_Guard", &nGuard);
            main_lua.register_function("HJN_Hold", &nHold);
            main_lua.register_function("HJN_Air", &nAir);
            main_lua.register_function("HJN_Land", &nLand);
            main_lua.register_function("HJN_MuteRevert", &nMuteRevert);
            main_lua.register_function("HJN_PushCap", &nPushCap);         // (v96)
            main_lua.register_function("HJN_Update", &nUpdate);           // (v101)
            main_lua.register_function("HJN_UpdateStatus", &nUpdateStatus);
            main_lua.register_function("HJN_ReverseSwap", &nReverseSwap);
            main_lua.register_function("HJN_ReverseSwapWhy", &nReverseSwapWhy);
            main_lua.register_function("HJN_BoardState", &nBoardState);
            main_lua.register_function("HJN_DeckWorld", &nDeckWorld);
            main_lua.register_function("HJN_BoardMount", &nBoardMount);
            main_lua.register_function("HJN_BoardRagdoll", &nBoardRagdoll);
            main_lua.register_function("HJN_CtrlYaw", &nCtrlYaw);         // (v61)
            main_lua.register_function("HJN_Readable", &nReadable);
            main_lua.register_function("HJN_HandOffset", &nHandOffset);
            main_lua.register_function("HJN_HandVia", &nHandVia);
            main_lua.register_function("HJN_GrabSet", &nGrabSet);
            main_lua.register_function("HJN_GrabSetSw", &nGrabSetSw);
            main_lua.register_function("HJN_Collisions", &nCollisions);
            main_lua.register_function("HJN_SetPC", &nSetPC);
            main_lua.register_function("HJN_Bumpers", &nBumpers);
            main_lua.register_function("HJN_Ledge", &nLedge);
            main_lua.register_function("HJN_CatchOrient", &nCatchOrient);   // (v56)
            main_lua.register_function("HJN_CatchState", &nCatchState);     // (v57)
            main_lua.register_function("HJN_PadOn", &nPadOn);               // (v59)
            main_lua.register_function("HJN_PadEvents", &nPadEvents);
            main_lua.register_function("HJN_PadSticks", &nPadSticks);       // (v62)
            main_lua.register_function("HJN_BoardParts", &nBoardParts);
            main_lua.register_function("HJN_BoardCapture", &nBoardCapture);
            main_lua.register_function("HJN_BoardPlace", &nBoardPlace);
            main_lua.register_function("HJN_BoardKick", &nBoardKick);
            main_lua.register_function("HJN_BoardPut", &nBoardPut);
            main_lua.register_function("HJN_BoardStance", &nBoardStance);
            main_lua.register_function("HJN_BoardMeet", &nBoardMeet);
            main_lua.register_function("HJN_GroundHold", &nGroundHold);
            main_lua.register_function("HJN_MenuPage", &nMenuPage);
            main_lua.register_function("HJN_MenuRow", &nMenuRow);
            main_lua.register_function("HJN_MenuValue", &nMenuValue);
            main_lua.register_function("HJN_MenuRegister", &nMenuRegister);
            main_lua.register_function("HJN_MenuTake", &nMenuTake);
            main_lua.register_function("HJN_Root", &nRoot);               // (v66)
            main_lua.register_function("HJN_NoBail", &nNoBail);           // (v66)
            main_lua.register_function("HJN_FootGround", &nFootGround);   // (v67)
            main_lua.register_function("HJN_DeckAxes", &nDeckAxes);       // (v67)
            main_lua.register_function("HJN_Bone", &nBone);               // (v68)
            main_lua.register_function("HJN_TrickName", &nTrickName);     // (v69)
            main_lua.register_function("HJN_TrickTrace", &nTrickTrace);   // (v70)
            main_lua.register_function("HJN_Plant", &nPlant);             // (v71)
            main_lua.register_function("HJN_TrickMute", &nTrickMute);     // (v72)
            main_lua.register_function("HJN_Held", &nHeld);               // (v74)
            main_lua.register_function("HJN_DeckOver", &nDeckOver);       // (v77)
            main_lua.register_function("HJN_SlideGate", &nSlideGate);     // (v85)
            main_lua.register_function("HJN_CrankFix", &nCrankFix);       // (v85)
            Log("HJN_* functions given to the ExpandedTricks Lua mod");
        } catch (...) {
            Log("could not register the HJN_* functions with the ExpandedTricks Lua mod -- the Lua half will say 'native half: NOT LOADED'");
        }
    }
};

#define HJN_API __declspec(dllexport)
extern "C" {
HJN_API RC::CppUserModBase* start_mod() { return new HippieNative(); }
HJN_API void uninstall_mod(RC::CppUserModBase* m) { delete m; }
}

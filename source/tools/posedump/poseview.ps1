<#
poseview.ps1 -- draws ExpandedTricks.poses.bin (the v94 pose recorder's file; layout in README.md).

  .\poseview.ps1 -Bin <file> [-Segment N | -All] [-Out <dir>] [-Every K] [-Metrics] [-List]

  -Bin       the pose file (it may be read while the game is still writing to it)
  -Segment   the N-th segment in the file (1 = the oldest). Without -Segment and -All: the LAST one (the newest trick)
  -All       every segment
  -Out       where the pictures go (default .\poseview_out)
  -Every     every K-th pose on the contact sheet (default 2); the pose that started the segment is always on it
  -Metrics   also write segNNN_metrics.csv (one line per pose) and segNNN_events.csv, and print the ranked events
  -List      only list the segments
  Sheet:     -Scale px/cm (3)  -MaxWidth px (4000)  -MaxHeight px (12000: more makes _p2, _p3 ... pages)
             -PageSize px (= -MaxWidth and -MaxHeight at once: pages no bigger than that. An image reader that shrinks
                           big pictures to ~2000 px -- Claude's does -- wants -PageSize 2000, and -Scale 2 for an overview)
             -Full (all poses; by default 10 before the start to 20 after the last window shut)  -PreShow n  -PostShow n
             -MaxCells n (160: a longer stretch is thinned to that many poses -- the sheet says so)
             -From ms -To ms (a time window, ms from the segment's start)  -Focus body|legs  -Views side,front,top
             -AllBones (every bone to its parent, thin)
             -AsRecorded (half-turn poses: show the game's pose as the file has it, already turned by PosePass; by
                          default the turn is taken out again, so the grey pose is the game's as it arrived)
  Events:    -JumpCm 4  -SlideCm 2  -PlantCm 3  -BonePct 3  -ExtHi 99  -ExtLo 30  -PitchDeg 60  -PitchNearCm 10  -TurnDeg 25  -Top 25
  -NoSheet / -NoPlots skip a picture.
#>
param(
    [Parameter(Mandatory = $true)][string]$Bin,
    [int]$Segment = 0,
    [switch]$All,
    [string]$Out = '',
    [int]$Every = 2,
    [switch]$Metrics,
    [switch]$List,
    [double]$Scale = 3.0,
    [int]$MaxWidth = 4000,
    [int]$MaxHeight = 12000,
    [int]$PageSize = 0,
    [int]$MaxCells = 160,
    [switch]$Full,
    [int]$PreShow = 10,
    [int]$PostShow = 20,
    [double]$From = [double]::NaN,
    [double]$To = [double]::NaN,
    [ValidateSet('body', 'legs')][string]$Focus = 'body',
    [string]$Views = 'side,front,top',
    [switch]$AllBones,
    [switch]$AsRecorded,
    [double]$JumpCm = 4.0,
    [double]$SlideCm = 2.0,
    [double]$PlantCm = 3.0,
    [double]$BonePct = 3.0,
    [double]$ExtHi = 99.0,
    [double]$ExtLo = 30.0,
    [double]$PitchDeg = 60.0,
    [double]$PitchNearCm = 10.0,
    [double]$TurnDeg = 25.0,
    [int]$Top = 25,
    [switch]$NoSheet,
    [switch]$NoPlots
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

namespace __NS__ {

public struct V3 {
    public double x, y, z;
    public V3(double x, double y, double z) { this.x = x; this.y = y; this.z = z; }
    public static V3 operator +(V3 a, V3 b) { return new V3(a.x + b.x, a.y + b.y, a.z + b.z); }
    public static V3 operator -(V3 a, V3 b) { return new V3(a.x - b.x, a.y - b.y, a.z - b.z); }
    public static V3 operator *(V3 a, double s) { return new V3(a.x * s, a.y * s, a.z * s); }
    public static double Dot(V3 a, V3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
    public static V3 Cross(V3 a, V3 b) { return new V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x); }
    public double Len { get { return Math.Sqrt(x * x + y * y + z * z); } }
    public double LenXY { get { return Math.Sqrt(x * x + y * y); } }
    public V3 Norm() { double l = Len; return l > 1e-9 ? this * (1.0 / l) : new V3(0, 0, 1); }
    public bool Finite { get { return !(double.IsNaN(x) || double.IsInfinity(x) || double.IsNaN(y) || double.IsInfinity(y) || double.IsNaN(z) || double.IsInfinity(z)); } }
    public static readonly V3 NaN = new V3(double.NaN, double.NaN, double.NaN);
}
public struct Q4 {
    public double x, y, z, w;
    public Q4(double x, double y, double z, double w) { this.x = x; this.y = y; this.z = z; this.w = w; }
    public V3 Rot(V3 v) { V3 u = new V3(x, y, z); V3 t = V3.Cross(u, v) * 2.0; return v + t * w + V3.Cross(u, t); }
    public static Q4 Mul(Q4 a, Q4 b) {
        return new Q4(a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y, a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                      a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w, a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z);
    }
    public bool Finite { get { return !(double.IsNaN(x + y + z + w) || double.IsInfinity(x + y + z + w)); } }
    public static double AngleDeg(Q4 a, Q4 b) {
        double la = Math.Sqrt(a.x * a.x + a.y * a.y + a.z * a.z + a.w * a.w), lb = Math.Sqrt(b.x * b.x + b.y * b.y + b.z * b.z + b.w * b.w);
        if (!(la > 1e-6) || !(lb > 1e-6)) return double.NaN;
        double d = Math.Abs(a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w) / (la * lb);
        return 2.0 * Math.Acos(Math.Min(1.0, d)) * 180.0 / Math.PI;
    }
}

public class Options {
    public string Bin = "", Out = "", Focus = "body", Views = "side,front,top";
    public int Segment = 0, Every = 2, MaxWidth = 4000, MaxHeight = 12000, PreShow = 10, PostShow = 20, Top = 25, MaxCells = 160;
    public bool All, Metrics, List, Full, AllBones, AsRecorded, NoSheet, NoPlots;
    public double Scale = 3.0, From = double.NaN, To = double.NaN;
    public double JumpCm = 4, SlideCm = 2, PlantCm = 3, BonePct = 3, ExtHi = 99, ExtLo = 30, PitchDeg = 60, PitchNearCm = 10, TurnDeg = 25;
}

public class Frame {
    public uint flags, tick; public double t, ms;
    public Q4 meshQ; public V3 meshP, meshS;
    public Q4 deckQ; public V3 deckP;
    public float footA0, footA1, plantD, plantW, hopFrac, hopReach, boneW, feetHoldW, legFixW;
    public double groundZ; public V3 groundN;
    public short plantFoot, plantStage, landFrames, landTotal, grabKind, stance;
    public Q4[] qGame = new Q4[5], qMod = new Q4[5];
    public V3[] game, mod;                                  // the mesh's space, as recorded
    // worked out
    public bool meshOk, changed, rejected, drawnIsGame, badNumbers, unwritten, turned;
    public V3[] cG, cD, wG, wD;                              // the game's / the drawn pose: in the mesh's space (cleaned), in the world
    public Q4[] qD;
    public bool deckOk, groundOk, groundKnown;
    public V3 deckC, deckX, deckY, deckZ;                    // the drawn deck in the world: its middle, its unit axes
    public double gx, gy, gz; public V3 gn;                  // the ground's plane: a point and its normal
    public V3 W(V3 c) { return meshP + meshQ.Rot(new V3(c.x * meshS.x, c.y * meshS.y, c.z * meshS.z)); }
    public V3 M(V3 c) { return new V3(c.x * meshS.x, c.y * meshS.y, c.z * meshS.z); }
    public double GroundAt(double x, double y) { return Math.Abs(gn.z) > 0.2 ? gz - (gn.x * (x - gx) + gn.y * (y - gy)) / gn.z : gz; }
}

public class Seg {
    public int index; public long offset, segBytes;
    public int version, hdrBytes, frames, bones, frameHdrBytes, frameBytes, preFrames, endReason, segFlags, modVersion, rigCount, framesInHeader;
    public uint seq, flagsAny; public ushort[] when = new ushort[8]; public ulong tick;
    public float deckHalfLen, deckHalfWidth, deckCentreX, footAnkle, footToe;
    public int[] rig = new int[36], parent;
    public bool truncated;
    public Frame[] f;
    public int pelvis, neck, head, flipper, chest, spine1, root, spineN;
    public int[] thigh = new int[2], calf = new int[2], foot = new int[2], toe = new int[2], uarm = new int[2], larm = new int[2], hand = new int[2],
                 footAnchor = new int[2], handAnchor = new int[2], spine = new int[6];
    int B(int i) { int v = rig[i]; return (v >= 0 && v < bones) ? v : -1; }
    public void NameRig() {
        pelvis = B(0); thigh[0] = B(1); thigh[1] = B(2); calf[0] = B(3); calf[1] = B(4); foot[0] = B(5); foot[1] = B(6); toe[0] = B(7); toe[1] = B(8);
        spineN = Math.Max(0, Math.Min(6, rig[9])); for (int i = 0; i < 6; i++) spine[i] = B(10 + i);
        neck = B(16); head = B(17); uarm[0] = B(18); uarm[1] = B(19); larm[0] = B(20); larm[1] = B(21); hand[0] = B(22); hand[1] = B(23);
        flipper = B(24); footAnchor[0] = B(25); footAnchor[1] = B(26); handAnchor[0] = B(27); handAnchor[1] = B(28); chest = B(29); spine1 = B(30); root = B(31);
    }
    public string When { get { return string.Format(CultureInfo.InvariantCulture, "{0:0000}-{1:00}-{2:00} {3:00}:{4:00}:{5:00}.{6:000}", when[0], when[1], when[3], when[4], when[5], when[6], when[7]); } }
    public static readonly string[] FlagNames = { "hop-air", "landing-blend", "plant", "bone-hand", "feet-hold", "pose-hold", "foot-ground", "half-turn", "grab", "trick-trace" };
    public const string FlagLetters = "ALPBFHGYRT";
    public static string OnNames(uint f) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 10; i++) if ((f & (1u << i)) != 0) sb.Append(' ').Append(FlagNames[i]);
        if ((f & 0x2000000u) != 0) sb.Append(" (a REJECTED pose)");
        return sb.Length > 0 ? sb.ToString().Substring(1) : "nothing";
    }
    public static string Letters(uint f) {
        char[] c = new char[10];
        for (int i = 0; i < 10; i++) c[i] = (f & (1u << i)) != 0 ? FlagLetters[i] : '.';
        string tail = ((f & 0x400u) != 0 ? "c" : "") + ((f & 0x2000000u) != 0 ? "!" : (f & 0x800u) != 0 ? "*" : "=");
        return new string(c) + " " + tail;
    }
    public string EndText { get { return endReason == 1 ? "its windows shut" : endReason == 2 ? "at its longest, a window still open" : endReason == 3 ? "no pose for half a second" : endReason == 4 ? "switched off" : endReason == 5 ? "another rig" : "?"; } }
}

public static class Reader {
    static void ReadFully(Stream s, byte[] b, int n) { int got = 0; while (got < n) { int r = s.Read(b, got, n - got); if (r <= 0) throw new EndOfStreamException(); got += r; } }
    static bool ParseHeader(byte[] b, Seg s) {
        if (b[0] != (byte)'E' || b[1] != (byte)'T' || b[2] != (byte)'P' || b[3] != (byte)'D') return false;
        s.version = BitConverter.ToUInt16(b, 4); s.hdrBytes = BitConverter.ToUInt16(b, 6); s.segBytes = BitConverter.ToUInt32(b, 8);
        s.frames = (int)BitConverter.ToUInt32(b, 12); s.bones = BitConverter.ToUInt16(b, 16); s.frameHdrBytes = BitConverter.ToUInt16(b, 18);
        s.frameBytes = (int)BitConverter.ToUInt32(b, 20); s.preFrames = BitConverter.ToUInt16(b, 24); s.endReason = b[26]; s.segFlags = b[27];
        s.seq = BitConverter.ToUInt32(b, 28); s.flagsAny = BitConverter.ToUInt32(b, 32); s.modVersion = BitConverter.ToUInt16(b, 36); s.rigCount = BitConverter.ToUInt16(b, 38);
        for (int i = 0; i < 8; i++) s.when[i] = BitConverter.ToUInt16(b, 40 + 2 * i);
        s.tick = BitConverter.ToUInt64(b, 56);
        s.deckHalfLen = BitConverter.ToSingle(b, 64); s.deckHalfWidth = BitConverter.ToSingle(b, 68); s.deckCentreX = BitConverter.ToSingle(b, 72);
        s.footAnkle = BitConverter.ToSingle(b, 76); s.footToe = BitConverter.ToSingle(b, 80);
        s.framesInHeader = s.frames;
        if (s.version < 1 || s.bones < 1 || s.bones > 1024 || s.frameHdrBytes < 308 || s.frames < 1 || s.frames > 1000000) return false;
        if (s.frameBytes != s.frameHdrBytes + s.bones * 24 || s.rigCount > 512 || s.hdrBytes < 88 + 2 * s.rigCount + 2 * s.bones) return false;
        if (s.segBytes != (long)s.hdrBytes + (long)s.frames * s.frameBytes) return false;
        return true;
    }
    static long Resync(FileStream fs, long from, long len) {
        byte[] buf = new byte[1 << 20], hb = new byte[88];
        for (long at = from; at + 88 <= len; ) {
            fs.Position = at; int n = fs.Read(buf, 0, (int)Math.Min(buf.Length, len - at));
            if (n < 88) return -1;
            for (int i = 0; i + 88 <= n; i++) {
                if (buf[i] != (byte)'E' || buf[i + 1] != (byte)'T' || buf[i + 2] != (byte)'P' || buf[i + 3] != (byte)'D') continue;
                Array.Copy(buf, i, hb, 0, 88);
                if (ParseHeader(hb, new Seg())) return at + i;
            }
            at += n - 87;
        }
        return -1;
    }
    public static List<Seg> Index(string path, List<string> warn) {
        List<Seg> list = new List<Seg>();
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
            long len = fs.Length, at = 0; byte[] hb = new byte[88];
            while (at + 88 <= len) {
                fs.Position = at; ReadFully(fs, hb, 88);
                Seg s = new Seg();
                if (!ParseHeader(hb, s)) {
                    long found = Resync(fs, at + 1, len);
                    warn.Add(string.Format(CultureInfo.InvariantCulture, "no segment header at byte {0}{1}", at, found < 0 ? " -- the rest of the file is not read" : " -- skipped to the next one at byte " + found));
                    if (found < 0) break;
                    at = found; continue;
                }
                s.offset = at; s.index = list.Count + 1;
                if (at + s.hdrBytes > len) { warn.Add("the file ends inside the last segment's header"); break; }
                byte[] rest = new byte[s.hdrBytes - 88]; ReadFully(fs, rest, rest.Length);
                for (int i = 0; i < 36; i++) s.rig[i] = i < s.rigCount ? BitConverter.ToInt16(rest, 2 * i) : -1;
                s.parent = new int[s.bones];
                for (int i = 0; i < s.bones; i++) s.parent[i] = BitConverter.ToInt16(rest, 2 * s.rigCount + 2 * i);
                s.NameRig();
                if (at + s.segBytes > len) {
                    int whole = (int)((len - at - s.hdrBytes) / s.frameBytes);
                    warn.Add(string.Format(CultureInfo.InvariantCulture, "segment {0} is cut short: {1} of its {2} poses are in the file", s.index, whole, s.frames));
                    s.truncated = true; s.frames = whole;
                    if (whole >= 1) list.Add(s);
                    break;
                }
                list.Add(s);
                at += s.segBytes;
            }
        }
        return list;
    }
    static V3 RV(byte[] b, int o) { return new V3(BitConverter.ToSingle(b, o), BitConverter.ToSingle(b, o + 4), BitConverter.ToSingle(b, o + 8)); }
    static Q4 RQ(byte[] b, int o) { return new Q4(BitConverter.ToSingle(b, o), BitConverter.ToSingle(b, o + 4), BitConverter.ToSingle(b, o + 8), BitConverter.ToSingle(b, o + 12)); }
    public static void Load(string path, Seg s) {
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
            fs.Position = s.offset + s.hdrBytes;
            byte[] b = new byte[s.frameBytes]; float[] fl = new float[s.bones * 6];
            s.f = new Frame[s.frames];
            for (int i = 0; i < s.frames; i++) {
                ReadFully(fs, b, b.Length);
                Frame f = new Frame();
                f.flags = BitConverter.ToUInt32(b, 0); f.tick = BitConverter.ToUInt32(b, 4); f.t = BitConverter.ToDouble(b, 8);
                f.meshQ = RQ(b, 16); f.meshP = RV(b, 32); f.meshS = RV(b, 44); f.deckQ = RQ(b, 56); f.deckP = RV(b, 72);
                f.footA0 = BitConverter.ToSingle(b, 84); f.footA1 = BitConverter.ToSingle(b, 88);
                f.groundZ = BitConverter.ToSingle(b, 92); f.groundN = RV(b, 96);
                f.plantD = BitConverter.ToSingle(b, 108); f.plantW = BitConverter.ToSingle(b, 112); f.hopFrac = BitConverter.ToSingle(b, 116); f.hopReach = BitConverter.ToSingle(b, 120);
                f.boneW = BitConverter.ToSingle(b, 124); f.feetHoldW = BitConverter.ToSingle(b, 128); f.legFixW = BitConverter.ToSingle(b, 132);
                f.plantFoot = BitConverter.ToInt16(b, 136); f.plantStage = BitConverter.ToInt16(b, 138); f.landFrames = BitConverter.ToInt16(b, 140); f.landTotal = BitConverter.ToInt16(b, 142);
                f.grabKind = BitConverter.ToInt16(b, 144); f.stance = BitConverter.ToInt16(b, 146);
                for (int k = 0; k < 5; k++) { f.qGame[k] = RQ(b, 148 + 16 * k); f.qMod[k] = RQ(b, 148 + 80 + 16 * k); }
                Buffer.BlockCopy(b, s.frameHdrBytes, fl, 0, s.bones * 24);
                f.game = new V3[s.bones]; f.mod = new V3[s.bones];
                for (int k = 0; k < s.bones; k++) {
                    f.game[k] = new V3(fl[3 * k], fl[3 * k + 1], fl[3 * k + 2]);
                    f.mod[k] = new V3(fl[3 * (s.bones + k)], fl[3 * (s.bones + k) + 1], fl[3 * (s.bones + k) + 2]);
                }
                s.f[i] = f;
            }
        }
    }
}

public class Ev {
    public string kind, who, text; public int from, to, peak; public double value, sev; public bool gameToo;
    public int joint = -1;                                   // 0 ankle L, 1 ankle R, 2 knee L, 3 knee R, 4 toe L, 5 toe R, 6 hip L, 7 hip R, 8 pelvis
}

public class Analysis {
    public Seg s; public Options o; public int n, pre;
    public double[] ms; public bool[] active;
    public V3 va, vb;                                        // the views' horizontal axes: along the deck as it stood at the start, and across it
    public List<int> spineChain = new List<int>(); public List<int>[] armChain = { new List<int>(), new List<int>() }, legChain = { new List<int>(), new List<int>() };
    public Dictionary<string, double[]> m = new Dictionary<string, double[]>(); public List<string> keys = new List<string>();
    public List<Ev> ev = new List<Ev>();
    public double[] thighRef = new double[2], shinRef = new double[2];
    public V3[][][] P = new V3[2][][], Mm = new V3[2][][];   // [0 drawn, 1 game][joint][pose]: in the world, in the mesh's space
    public V3[][] JV = new V3[9][];                          // the drawn pose's jump per joint, as a vector
    V3[] org;                                                // the mesh's origin, pose by pose
    public const int J = 9;
    public static readonly string[] JointName = { "L ankle", "R ankle", "L knee", "R knee", "L toe", "R toe", "L hip", "R hip", "pelvis" };
    public List<string> notes = new List<string>();

    static string F(string fmt, params object[] a) { return string.Format(CultureInfo.InvariantCulture, fmt, a); }
    double[] Ser(string key) { double[] a = new double[n]; for (int i = 0; i < n; i++) a[i] = double.NaN; m[key] = a; keys.Add(key); return a; }
    public double[] Get(string key) { return m[key]; }
    int JointBone(int j) { switch (j) { case 0: return s.foot[0]; case 1: return s.foot[1]; case 2: return s.calf[0]; case 3: return s.calf[1]; case 4: return s.toe[0]; case 5: return s.toe[1]; case 6: return s.thigh[0]; case 7: return s.thigh[1]; default: return s.pelvis; } }

    public Analysis(Seg seg, Options opt) {
        s = seg; o = opt; n = s.frames; pre = Math.Max(0, Math.Min(s.preFrames, n - 1));
        Derive(); Chains(); Basis(); Measure(); Events();
    }
    void Derive() {
        ms = new double[n]; active = new bool[n];
        bool tOk = true;
        for (int i = 1; i < n; i++) if (!(s.f[i].t > s.f[i - 1].t)) tOk = false;
        if (!tOk) notes.Add("the precise time does not run forward in this segment: the 15.6 ms tick is used instead");
        Q4 unturn = new Q4(0, 0, -1, 0);
        for (int i = 0; i < n; i++) {
            Frame f = s.f[i];
            ms[i] = tOk ? (f.t - s.f[pre].t) * 1000.0 : (double)(int)(f.tick - s.f[pre].tick);
            f.ms = ms[i];
            active[i] = (f.flags & 0x3ffu) != 0;
            f.changed = (f.flags & 0x800u) != 0; f.rejected = (f.flags & 0x2000000u) != 0;
            f.drawnIsGame = !f.changed || f.rejected;
            f.meshOk = f.meshQ.Finite && f.meshP.Finite && f.meshS.Finite;
            if (!f.meshOk) { f.meshQ = new Q4(0, 0, 0, 1); f.meshP = new V3(0, 0, 0); f.meshS = new V3(1, 1, 1); }
            f.cG = new V3[s.bones]; f.cD = new V3[s.bones]; f.wG = new V3[s.bones]; f.wD = new V3[s.bones];
            // A half-turn pose (0x80): PosePass turned g_C IN PLACE (the body's bones, half round about the pelvis's parent) before
            // g_Ct was copied from it, so the file's "game" pose is already turned. The pose as it ARRIVED is that turn taken out
            // again (exact: the turn is its own inverse) -- and that, not the recorded g_C, is what the screen had on a pose that
            // was not written back or was rejected.
            V3 pv = (s.root >= 0 && f.game[s.root].Finite) ? f.game[s.root] : new V3(0, 0, 0);
            f.turned = (f.flags & 0x80u) != 0 && s.root >= 0;
            double diff = 0;
            for (int k = 0; k < s.bones; k++) {
                V3 rec = f.game[k];
                if (!rec.Finite) { rec = new V3(0, 0, 0); f.badNumbers = true; }
                V3 raw = (f.turned && Under(k, s.root)) ? new V3(2 * pv.x - rec.x, 2 * pv.y - rec.y, rec.z) : rec;
                V3 d = f.drawnIsGame ? raw : f.mod[k];
                if (!d.Finite) { d = raw; f.badNumbers = true; }
                if (f.mod[k].Finite) diff = Math.Max(diff, (f.mod[k] - rec).Len);
                V3 g = o.AsRecorded ? rec : raw;
                f.cG[k] = g; f.cD[k] = d; f.wG[k] = f.W(g); f.wD[k] = f.W(d);
            }
            f.unwritten = !f.changed && diff > 0.5;
            f.qD = new Q4[5];
            for (int k = 0; k < 5; k++) {
                Q4 recq = f.qGame[k], rawq = f.turned ? Q4.Mul(unturn, recq) : recq;
                f.qGame[k] = o.AsRecorded ? recq : rawq; f.qD[k] = f.drawnIsGame ? rawq : f.qMod[k];
            }
            f.deckOk = (f.flags & 0x100000u) != 0 && f.deckQ.Finite && f.deckP.Finite;
            if (f.deckOk) {
                f.deckC = f.W(f.deckP);
                f.deckX = f.meshQ.Rot(f.M(f.deckQ.Rot(new V3(1, 0, 0)))).Norm(); f.deckY = f.meshQ.Rot(f.M(f.deckQ.Rot(new V3(0, 1, 0)))).Norm(); f.deckZ = f.meshQ.Rot(f.M(f.deckQ.Rot(new V3(0, 0, 1)))).Norm();
            }
            f.groundOk = (f.flags & 0x200000u) != 0 && !double.IsNaN(f.groundZ) && f.groundN.Finite && Math.Abs(f.groundN.z) > 0.2;
            if (f.groundOk) { f.gx = f.meshP.x; f.gy = f.meshP.y; f.gz = f.groundZ; f.gn = f.groundN; f.groundKnown = true; }
        }
        int nMirror = 0, nNoGround = 0, nNoDeck = 0, nTurn = 0;
        foreach (Frame f in s.f) { if ((f.flags & 0x1000000u) != 0) nMirror++; if (!f.groundOk) nNoGround++; if (!f.deckOk) nNoDeck++; if (f.turned) nTurn++; }
        if (nMirror > 0) notes.Add(F("the pose mirror is on for {0} of {1} poses (goofy / switch): 'left' is still the MESH's own left leg", nMirror, n));
        if (nNoGround > 0) notes.Add(F("{0} of {1} poses have no ground under the mesh (none within 10 m, or the ray missed): the nearest pose's ground is drawn dashed there, and nothing is measured against it", nNoGround, n));
        if (nNoDeck > 0) notes.Add(F("{0} of {1} poses have no drawn deck (DeckXf failed or the board is not resolved)", nNoDeck, n));
        if (nTurn > 0) notes.Add(F("{0} half-turn poses: the game's pose is {1}", nTurn, o.AsRecorded ? "shown AS RECORDED (already turned by PosePass)" : "shown as it ARRIVED (the turn taken out again; -AsRecorded shows the file's)"));
        int last = -1;                                       // a pose without its own ground takes the nearest one's (drawn dashed, not measured against)
        for (int i = 0; i < n; i++) { if (s.f[i].groundOk) last = i; else if (last >= 0) CopyGround(s.f[last], s.f[i]); }
        int next = -1;
        for (int i = n - 1; i >= 0; i--) { if (s.f[i].groundOk) next = i; else if (!s.f[i].groundKnown && next >= 0) CopyGround(s.f[next], s.f[i]); }
    }
    static void CopyGround(Frame a, Frame b) { b.gx = a.gx; b.gy = a.gy; b.gz = a.gz; b.gn = a.gn; b.groundKnown = true; }
    bool Under(int b, int anc) { for (int x = b, hops = 0; x >= 0 && hops < 256; x = s.parent[x], hops++) if (x == anc) return true; return false; }
    void Chains() {
        // head -> ... -> pelvis by the parents; the arms from each hand up to the first bone of that line; the legs from each foot up to the pelvis
        if (s.head >= 0 && s.pelvis >= 0 && Under(s.head, s.pelvis)) { for (int x = s.head; x >= 0; x = s.parent[x]) { spineChain.Add(x); if (x == s.pelvis) break; } }
        else { if (s.head >= 0) spineChain.Add(s.head); if (s.neck >= 0) spineChain.Add(s.neck); for (int i = s.spineN - 1; i >= 0; i--) if (s.spine[i] >= 0) spineChain.Add(s.spine[i]); if (s.pelvis >= 0) spineChain.Add(s.pelvis); }
        for (int k = 0; k < 2; k++) {
            if (s.hand[k] >= 0) {
                bool joined = false;
                for (int x = s.hand[k], hops = 0; x >= 0 && hops < 64; x = s.parent[x], hops++) { armChain[k].Add(x); if (spineChain.Contains(x)) { joined = true; break; } }
                if (!joined) { armChain[k].Clear(); armChain[k].Add(s.hand[k]); if (s.larm[k] >= 0) armChain[k].Add(s.larm[k]); if (s.uarm[k] >= 0) armChain[k].Add(s.uarm[k]); if (s.chest >= 0) armChain[k].Add(s.chest); }
            }
            if (s.foot[k] >= 0) {
                bool joined = false;
                for (int x = s.foot[k], hops = 0; x >= 0 && hops < 64; x = s.parent[x], hops++) { legChain[k].Add(x); if (x == s.pelvis) { joined = true; break; } }
                if (!joined) { legChain[k].Clear(); legChain[k].Add(s.foot[k]); if (s.calf[k] >= 0) legChain[k].Add(s.calf[k]); if (s.thigh[k] >= 0) legChain[k].Add(s.thigh[k]); if (s.pelvis >= 0) legChain[k].Add(s.pelvis); }
            }
        }
    }
    void Basis() {
        int pick = -1;
        for (int i = pre; i < n && pick < 0; i++) if (s.f[i].deckOk && s.f[i].deckX.LenXY > 0.3) pick = i;
        for (int i = pre - 1; i >= 0 && pick < 0; i--) if (s.f[i].deckOk && s.f[i].deckX.LenXY > 0.3) pick = i;
        V3 a = pick >= 0 ? s.f[pick].deckX : s.f[pre].meshQ.Rot(new V3(1, 0, 0));
        a.z = 0; if (a.Len < 0.05) a = new V3(1, 0, 0);
        va = a.Norm(); vb = new V3(-va.y, va.x, 0);
        if (pick < 0) notes.Add("no drawn deck in this segment: the views are along the mesh's own x axis");
    }
    static double Median(List<double> v) { if (v.Count == 0) return double.NaN; v.Sort(); return v[v.Count / 2]; }
    void Measure() {
        for (int p = 0; p < 2; p++) { P[p] = new V3[J][]; Mm[p] = new V3[J][]; for (int j = 0; j < J; j++) { P[p][j] = new V3[n]; Mm[p][j] = new V3[n]; } }
        org = new V3[n];
        for (int i = 0; i < n; i++) {
            Frame f = s.f[i];
            org[i] = f.meshP;
            for (int p = 0; p < 2; p++) for (int j = 0; j < J; j++) {
                int b = JointBone(j);
                P[p][j][i] = b >= 0 ? (p == 0 ? f.wD[b] : f.wG[b]) : V3.NaN;
                Mm[p][j][i] = b >= 0 ? f.M(p == 0 ? f.cD[b] : f.cG[b]) : V3.NaN;
            }
        }
        string[] pn = { "d", "g" }, kn = { "L", "R" };
        // the bones' own lengths: the game's pose, where nothing of a trick is on (else: all of it)
        for (int k = 0; k < 2; k++) {
            List<double> th = new List<double>(), sh = new List<double>(), thAll = new List<double>(), shAll = new List<double>();
            for (int i = 0; i < n; i++) {
                double a = (P[1][2 + k][i] - P[1][6 + k][i]).Len, b = (P[1][k][i] - P[1][2 + k][i]).Len;
                if (double.IsNaN(a) || double.IsNaN(b)) continue;
                thAll.Add(a); shAll.Add(b); if (!active[i]) { th.Add(a); sh.Add(b); }
            }
            thighRef[k] = th.Count >= 5 ? Median(th) : Median(thAll); shinRef[k] = sh.Count >= 5 ? Median(sh) : Median(shAll);
        }
        for (int p = 0; p < 2; p++) for (int k = 0; k < 2; k++) {
            string q = pn[p] + "_" + kn[k] + "_";
            double[] ag = Ser(q + "ankle_gnd"), tg = Ser(q + "toe_gnd"), cl = Ser(q + "clear"), od = Ser(q + "over_deck"), al = Ser(q + "along"), ac = Ser(q + "across"),
                     ha = Ser(q + "hip_ankle"), ex = Ser(q + "ext_pct"), th = Ser(q + "thigh"), sh = Ser(q + "shin"), pi = Ser(q + "pitch"),
                     aj = Ser(q + "ankle_jump"), ajm = Ser(q + "ankle_jump_mesh"), kj = Ser(q + "knee_jump"), kjm = Ser(q + "knee_jump_mesh"), ft = Ser(q + "foot_turn");
            for (int i = 0; i < n; i++) {
                Frame f = s.f[i];
                V3 A = P[p][k][i], K = P[p][2 + k][i], T = P[p][4 + k][i], H = P[p][6 + k][i];
                if (!A.Finite) continue;
                if (f.groundOk) {
                    ag[i] = A.z - f.GroundAt(A.x, A.y);
                    if (T.Finite) tg[i] = T.z - f.GroundAt(T.x, T.y);
                    cl[i] = T.Finite ? Math.Min(ag[i] - s.footAnkle, tg[i] - s.footToe) : ag[i] - s.footAnkle;
                }
                if (f.deckOk) { V3 d = A - f.deckC; od[i] = V3.Dot(d, f.deckZ); al[i] = V3.Dot(d, f.deckX); ac[i] = V3.Dot(d, f.deckY); }
                if (H.Finite) { ha[i] = (A - H).Len; ex[i] = 100.0 * ha[i] / (thighRef[k] + shinRef[k]); }
                if (H.Finite && K.Finite) th[i] = (K - H).Len;
                if (K.Finite) sh[i] = (A - K).Len;
                if (T.Finite && (T - A).Len > 0.5) pi[i] = Math.Asin(Math.Max(-1, Math.Min(1, (T.z - A.z) / (T - A).Len))) * 180.0 / Math.PI;
            }
            V3[] ja = Jump(P[p][k], org, aj), jk = Jump(P[p][2 + k], org, kj);
            Jump(Mm[p][k], null, ajm); Jump(Mm[p][2 + k], null, kjm);
            if (p == 0) { JV[k] = ja; JV[2 + k] = jk; }
            Turn(p, 1 + k, ft);
        }
        for (int p = 0; p < 2; p++) {
            string q = pn[p] + "_pelvis_";
            double[] pg = Ser(q + "gnd"), py = Ser(q + "yaw"), pj = Ser(q + "jump"), pjm = Ser(q + "jump_mesh"), pt = Ser(q + "turn");
            double prev = double.NaN;
            for (int i = 0; i < n; i++) {
                Frame f = s.f[i]; V3 C = P[p][8][i], L = P[p][6][i], R = P[p][7][i];
                if (C.Finite && f.groundOk) pg[i] = C.z - f.GroundAt(C.x, C.y);
                if (L.Finite && R.Finite && (L - R).LenXY > 0.5) { double y = Math.Atan2(L.y - R.y, L.x - R.x) * 180.0 / Math.PI; py[i] = prev = Unwrap(y, prev); }
            }
            V3[] jp = Jump(P[p][8], org, pj); Jump(Mm[p][8], null, pjm); Turn(p, 0, pt);
            if (p == 0) JV[8] = jp;
        }
        double[] dy = Ser("deck_yaw"), dp = Ser("deck_pitch"), dr = Ser("deck_roll"), dg = Ser("deck_gnd"), mx = Ser("mesh_x"), my = Ser("mesh_y"), mz = Ser("mesh_z"), myaw = Ser("mesh_yaw"), msp = Ser("mesh_speed"),
                 gz = Ser("ground_z"), mg = Ser("mesh_gnd"), mj = Ser("mesh_jump");
        Jump(org, null, mj);
        double[] st0 = Ser("foot_ik_L"), st1 = Ser("foot_ik_R"), st2 = Ser("plant_w"), st3 = Ser("plant_d"), st4 = Ser("plant_foot"), st5 = Ser("plant_stage"), st6 = Ser("hop_frac"), st7 = Ser("hop_reach"),
                 st8 = Ser("land_frames"), st9 = Ser("land_total"), st10 = Ser("bone_w"), st11 = Ser("feet_hold_w"), st12 = Ser("leg_fix_w"), st13 = Ser("grab_kind"), st14 = Ser("stance");
        double pdy = double.NaN, pmy = double.NaN;
        for (int i = 0; i < n; i++) {
            Frame f = s.f[i];
            if (f.deckOk) {
                if (f.deckX.LenXY > 0.05) dy[i] = pdy = Unwrap(Math.Atan2(f.deckX.y, f.deckX.x) * 180.0 / Math.PI, pdy);
                dp[i] = Math.Asin(Math.Max(-1, Math.Min(1, f.deckX.z))) * 180.0 / Math.PI; dr[i] = Math.Asin(Math.Max(-1, Math.Min(1, f.deckY.z))) * 180.0 / Math.PI;
                if (f.groundOk) dg[i] = f.deckC.z - f.GroundAt(f.deckC.x, f.deckC.y);
            }
            mx[i] = f.meshP.x; my[i] = f.meshP.y; mz[i] = f.meshP.z;
            V3 hx = f.meshQ.Rot(new V3(1, 0, 0)); if (hx.LenXY > 0.05) myaw[i] = pmy = Unwrap(Math.Atan2(hx.y, hx.x) * 180.0 / Math.PI, pmy);
            if (i > 0) { double dt = (ms[i] - ms[i - 1]) / 1000.0; if (dt > 0.0005 && dt < 0.2) msp[i] = (f.meshP - s.f[i - 1].meshP).Len / dt; }
            if (f.groundOk) { gz[i] = f.groundZ; mg[i] = f.meshP.z - f.groundZ; }
            st0[i] = f.footA0; st1[i] = f.footA1; st2[i] = f.plantW; st3[i] = f.plantD; st4[i] = f.plantFoot; st5[i] = f.plantStage; st6[i] = f.hopFrac; st7[i] = f.hopReach;
            st8[i] = f.landFrames; st9[i] = f.landTotal; st10[i] = f.boneW; st11[i] = f.feetHoldW; st12[i] = f.legFixW; st13[i] = f.grabKind; st14[i] = f.stance;
        }
        // (for the csv: the joints themselves, in the world, and the deck's middle)
        string[] jn = { "L_ankle", "R_ankle", "L_knee", "R_knee", "L_toe", "R_toe", "L_hip", "R_hip", "pelvis" };
        for (int p = 0; p < 2; p++) for (int j = 0; j < J; j++) {
            double[] wx = Ser(pn[p] + "_" + jn[j] + "_wx"), wy = Ser(pn[p] + "_" + jn[j] + "_wy"), wz = Ser(pn[p] + "_" + jn[j] + "_wz");
            for (int i = 0; i < n; i++) { V3 v = P[p][j][i]; if (v.Finite) { wx[i] = v.x; wy[i] = v.y; wz[i] = v.z; } }
        }
        double[] dcx = Ser("deck_wx"), dcy = Ser("deck_wy"), dcz = Ser("deck_wz");
        for (int i = 0; i < n; i++) if (s.f[i].deckOk) { dcx[i] = s.f[i].deckC.x; dcy[i] = s.f[i].deckC.y; dcz[i] = s.f[i].deckC.z; }
    }
    static double Unwrap(double y, double prev) { if (double.IsNaN(prev)) return y; while (y - prev > 180) y -= 360; while (y - prev < -180) y += 360; return y; }
    // What a joint moved in this pose that its last pose's speed does not explain, cm: steady motion reads 0, a pose that
    // pops out by d reads d (and 2d on the pose it comes back, the other way), a pose that steps to a new place by d reads
    // d (and d the other way on the next). With 'org' it is taken about the mesh's own origin: a takeoff or a landing moves
    // every joint together and is not a jump of any of them (that is the series mesh_jump).
    V3[] Jump(V3[] p, V3[] org, double[] outv) {
        V3[] v = new V3[n];
        for (int i = 0; i < n; i++) v[i] = V3.NaN;
        for (int i = 2; i < n; i++) {
            double dt1 = (ms[i] - ms[i - 1]) / 1000.0, dt0 = (ms[i - 1] - ms[i - 2]) / 1000.0;
            if (!(dt1 > 0.0005 && dt1 < 0.1 && dt0 > 0.0005 && dt0 < 0.1)) continue;
            V3 a = p[i], b = p[i - 1], c = p[i - 2];
            if (org != null) { a = a - org[i]; b = b - org[i - 1]; c = c - org[i - 2]; }
            if (!a.Finite || !b.Finite || !c.Finite) continue;
            v[i] = (a - b) - (b - c) * (dt1 / dt0);
            outv[i] = v[i].Len;
        }
        return v;
    }
    // the same for a bone's rotation (pelvis 0, foot L 1, foot R 2), in the world: degrees turned in this pose beyond the last pose's turn
    void Turn(int p, int qi, double[] outv) {
        double[] a = new double[n];
        for (int i = 0; i < n; i++) a[i] = double.NaN;
        for (int i = 1; i < n; i++) {
            Q4 q1 = Q4.Mul(s.f[i].meshQ, p == 0 ? s.f[i].qD[qi] : s.f[i].qGame[qi]), q0 = Q4.Mul(s.f[i - 1].meshQ, p == 0 ? s.f[i - 1].qD[qi] : s.f[i - 1].qGame[qi]);
            a[i] = Q4.AngleDeg(q0, q1);
        }
        for (int i = 2; i < n; i++) {
            double dt1 = (ms[i] - ms[i - 1]) / 1000.0, dt0 = (ms[i - 1] - ms[i - 2]) / 1000.0;
            if (!(dt1 > 0.0005 && dt1 < 0.1 && dt0 > 0.0005 && dt0 < 0.1) || double.IsNaN(a[i]) || double.IsNaN(a[i - 1])) continue;
            outv[i] = Math.Abs(a[i] - a[i - 1] * (dt1 / dt0));
        }
    }
    List<int[]> Runs(Func<int, bool> cond, int minLen, int gap) {
        List<int[]> r = new List<int[]>(); int from = -1, lastOn = -1;
        for (int i = 0; i <= n; i++) {
            bool on = i < n && cond(i);
            if (on) { if (from < 0) from = i; lastOn = i; }
            else if (from >= 0 && (i == n || i - lastOn > gap)) { if (lastOn - from + 1 >= minLen) r.Add(new int[] { from, lastOn }); from = -1; }
        }
        return r;
    }
    string Fr(int a, int b) { return a == b ? F("#{0} ({1:+0;-0;0} ms)", a, ms[a]) : F("#{0}..#{1} ({2:+0;-0;0}..{3:+0;-0;0} ms)", a, b, ms[a], ms[b]); }
    string SwitchNote(int i) {
        if (i < 1 || s.f[i].drawnIsGame == s.f[i - 1].drawnIsGame) return "";
        return s.f[i].drawnIsGame ? (s.f[i].rejected ? " [this pose was REJECTED: the screen has the game's pose]" : " [the mod's edits are not written from this pose on: the screen goes back to the game's pose]")
                                  : " [the mod's edits are written from this pose on]";
    }
    void Add(string kind, string who, int from, int to, int peak, double value, double sev, string text, int joint, bool gameToo) {
        Ev e = new Ev(); e.kind = kind; e.who = who; e.from = from; e.to = to; e.peak = peak; e.value = value; e.sev = sev; e.text = text; e.joint = joint; e.gameToo = gameToo; ev.Add(e);
    }
    void Events() {
        string[] kn = { "L", "R" };
        // 1. jumps: ankles, knees, pelvis
        string[] jkeys = { "_L_ankle_jump", "_R_ankle_jump", "_L_knee_jump", "_R_knee_jump", "", "", "", "", "_pelvis_jump" };
        foreach (int j in new int[] { 0, 1, 2, 3, 8 }) {
            double[] d = m["d" + jkeys[j]], g = m["g" + jkeys[j]], dm = m["d" + jkeys[j] + "_mesh"]; V3[] jv = JV[j];
            foreach (int[] r in Runs(i => d[i] >= o.JumpCm, 1, 0)) {
                // (the pose after a pop reads twice the pop, the other way: a lone pose that is just that belongs to a pop under the threshold)
                if (r[1] == r[0] && r[0] > 0 && jv[r[0] - 1].Finite && d[r[0] - 1] > 0.3 * d[r[0]] && V3.Dot(jv[r[0]], jv[r[0] - 1]) < -1.5 * d[r[0] - 1] * d[r[0] - 1]) continue;
                for (int on = r[0]; on <= r[1]; ) {
                    // a pop takes three poses of the run (out, back at twice the size, level again), a step two; anything else is one event to the run's end
                    int end = r[1], pk = on; string what = "";
                    if (on + 1 < n && jv[on + 1].Finite) {
                        double c = V3.Dot(jv[on + 1], jv[on]) / (d[on] * d[on]);
                        if (c < -1.5) { what = F(" -- a ONE-POSE POP: it is back at #{0}", on + 1); end = Math.Min(r[1], on + 2); }
                        else if (c < -0.5) { what = " -- a STEP: it stays there"; end = Math.Min(r[1], on + 1); }
                    }
                    if (what == "") for (int i = on; i <= end; i++) if (d[i] > d[pk]) pk = i;
                    double gv = 0; for (int i = on; i <= end; i++) if (!double.IsNaN(g[i])) gv = Math.Max(gv, g[i]);
                    bool own = gv >= 0.7 * d[pk];
                    Add(own ? "jump (the game's own)" : "JUMP", JointName[j], on, what != "" ? on : end, pk, d[pk], d[pk] / o.JumpCm * (own ? 0.4 : 1.0),
                        F("{0} jumps {1:0.0} cm in one pose at {2}{3} (in the mesh's space {4:0.0}); the game's pose there {5:0.0} cm{6}{7}", JointName[j], d[pk], Fr(pk, pk), what, dm[pk], gv,
                          own ? " -- the game's own pose does it" : "", SwitchNote(pk)), j, own);
                    on = end + 1;
                }
            }
        }
        {
            double[] d = m["mesh_jump"];
            foreach (int[] r in Runs(i => d[i] >= o.JumpCm, 1, 0)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (d[i] > d[pk]) pk = i;
                Add("mesh jump (the whole skater)", "mesh", r[0], r[1], pk, d[pk], 0.5,
                    F("the mesh's own origin jumps {0:0.0} cm in one pose at {1} (a takeoff, a landing, a snap of the whole skater): every joint goes with it, so it is in none of the joints' jumps", d[pk], Fr(pk, pk)), -1, true);
            }
        }
        // 1b. a foot's or the hips' rotation snapping
        string[] tkeys = { "_pelvis_turn", "_L_foot_turn", "_R_foot_turn" }; string[] tn = { "pelvis", "L foot", "R foot" }; int[] tj = { 8, 0, 1 };
        for (int q = 0; q < 3; q++) {
            double[] d = m["d" + tkeys[q]], g = m["g" + tkeys[q]];
            foreach (int[] r in Runs(i => d[i] >= o.TurnDeg, 1, 1)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (d[i] > d[pk]) pk = i;
                double gv = 0; for (int i = r[0]; i <= r[1]; i++) if (!double.IsNaN(g[i])) gv = Math.Max(gv, g[i]);
                bool own = gv >= 0.7 * d[pk];
                Add(own ? "turn (the game's own)" : "TURN", tn[q], r[0], r[1], pk, d[pk], d[pk] / o.TurnDeg * (own ? 0.4 : 1.0),
                    F("{0} turns {1:0} deg more in one pose than in the one before, at {2}; the game's pose there {3:0}{4}{5}", tn[q], d[pk], Fr(pk, pk), gv, own ? " -- the game's own pose does it" : "", SwitchNote(pk)), tj[q], own);
            }
        }
        for (int k = 0; k < 2; k++) {
            string q = "d_" + kn[k] + "_", qg = "g_" + kn[k] + "_";
            double[] cl = m[q + "clear"], ag = m[q + "ankle_gnd"], tg = m[q + "toe_gnd"], od = m[q + "over_deck"], al = m[q + "along"], ac = m[q + "across"], ex = m[q + "ext_pct"], th = m[q + "thigh"], sh = m[q + "shin"], pi = m[q + "pitch"];
            double[] gag = m[qg + "ankle_gnd"], god = m[qg + "over_deck"], gex = m[qg + "ext_pct"], gth = m[qg + "thigh"], gsh = m[qg + "shin"], gpi = m[qg + "pitch"];
            int ja = k, jt = 4 + k;
            // 2. a planted foot sliding
            foreach (int[] r in Runs(i => s.f[i].groundOk && cl[i] <= o.PlantCm && cl[i] > -30, 3, 0)) {
                double[] sum = new double[8]; double fast = 0;         // drawn: ankle world, toe world, ankle mesh, toe mesh | the game's: the same
                bool toeOk = true;
                for (int i = r[0] + 1; i <= r[1]; i++) {
                    for (int p = 0; p < 2; p++) {
                        sum[4 * p] += (P[p][ja][i] - P[p][ja][i - 1]).LenXY; sum[4 * p + 2] += (Mm[p][ja][i] - Mm[p][ja][i - 1]).LenXY;
                        if (P[p][jt][i].Finite && P[p][jt][i - 1].Finite) { sum[4 * p + 1] += (P[p][jt][i] - P[p][jt][i - 1]).LenXY; sum[4 * p + 3] += (Mm[p][jt][i] - Mm[p][jt][i - 1]).LenXY; } else toeOk = false;
                    }
                    double dt = (ms[i] - ms[i - 1]) / 1000.0;
                    if (dt > 0.0005) fast = Math.Max(fast, Math.Min((P[0][ja][i] - P[0][ja][i - 1]).LenXY, toeOk ? (P[0][jt][i] - P[0][jt][i - 1]).LenXY : 1e9) / dt);
                }
                double world = toeOk ? Math.Min(sum[0], sum[1]) : sum[0], mesh = toeOk ? Math.Min(sum[2], sum[3]) : sum[2];
                if (world < o.SlideCm && mesh < o.SlideCm) continue;
                bool slides = world >= o.SlideCm;
                Add(slides ? "SLIDE" : "planted (holds in the world)", kn[k] + " foot", r[0], r[1], r[0], world, slides ? world / o.SlideCm : 0.3,
                    F("{0} foot on the ground {1}: over the ground (world) its ankle goes {2:0.0} cm, its toe joint {3:0.0} cm (up to {4:0} cm/s); in the mesh's space ankle {5:0.0}, toe {6:0.0} cm | the game's pose over the same poses: world ankle {7:0.0} toe {8:0.0}, mesh ankle {9:0.0} toe {10:0.0} cm{11}",
                      kn[k], Fr(r[0], r[1]), sum[0], sum[1], fast, sum[2], sum[3], sum[4], sum[5], sum[6], sum[7], slides ? "" : " -- it holds its place in the world while the mesh moves on"), ja, false);
            }
            // 3. an ankle under the deck's plane, inside its outline
            double hl = (s.deckHalfLen > 5 && s.deckHalfLen < 200) ? s.deckHalfLen : 40, hw = (s.deckHalfWidth > 2 && s.deckHalfWidth < 60) ? s.deckHalfWidth : 10.5, cx = Math.Abs(s.deckCentreX) < 50 ? s.deckCentreX : 0;
            foreach (int[] r in Runs(i => s.f[i].deckOk && od[i] < 0 && od[i] > -45 && Math.Abs(al[i] - cx) <= hl && Math.Abs(ac[i]) <= hw, 1, 0)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (od[i] < od[pk]) pk = i;
                Add("UNDER THE DECK", kn[k] + " ankle", r[0], r[1], pk, -od[pk], 2 + -od[pk] / 3,
                    F("{0} ankle under the deck's plane inside its outline {1}: deepest {2:0.0} cm under at #{3} (along {4:+0;-0} across {5:+0;-0}); the game's pose there {6:+0.0;-0.0} cm", kn[k], Fr(r[0], r[1]), -od[pk], pk, al[pk], ac[pk], god[pk]), ja, false);
            }
            // 4. an ankle (a toe joint) under the ground
            foreach (int[] r in Runs(i => s.f[i].groundOk && ag[i] < 0, 1, 0)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (ag[i] < ag[pk]) pk = i;
                Add("UNDER THE GROUND", kn[k] + " ankle", r[0], r[1], pk, -ag[pk], 2 + -ag[pk] / 2,
                    F("{0} ankle under the ground {1}: deepest {2:0.0} cm under at #{3}; the game's pose there {4:+0.0;-0.0} cm", kn[k], Fr(r[0], r[1]), -ag[pk], pk, gag[pk]), ja, false);
            }
            foreach (int[] r in Runs(i => s.f[i].groundOk && tg[i] < -1 && !(ag[i] < 0), 1, 0)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (tg[i] < tg[pk]) pk = i;
                Add("toe under the ground", kn[k] + " toe", r[0], r[1], pk, -tg[pk], 1 + -tg[pk] / 3,
                    F("{0} toe joint under the ground {1}: deepest {2:0.0} cm under at #{3} (the ankle is {4:0.0} over)", kn[k], Fr(r[0], r[1]), -tg[pk], pk, ag[pk]), jt, false);
            }
            // 5. a bone's length off its own
            for (int b = 0; b < 2; b++) {
                double[] d = b == 0 ? th : sh, g = b == 0 ? gth : gsh; double rf = b == 0 ? thighRef[k] : shinRef[k]; string bn = b == 0 ? "thigh" : "shin";
                if (!(rf > 1)) continue;
                foreach (int[] r in Runs(i => Math.Abs(d[i] / rf - 1) * 100 > o.BonePct, 1, 0)) {
                    int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (Math.Abs(d[i] / rf - 1) > Math.Abs(d[pk] / rf - 1)) pk = i;
                    double pct = (d[pk] / rf - 1) * 100, gp = (g[pk] / rf - 1) * 100; bool own = Math.Abs(gp) >= 0.7 * Math.Abs(pct);
                    Add(own ? "bone length (the game's own)" : "BONE LENGTH", kn[k] + " " + bn, r[0], r[1], pk, pct, Math.Abs(pct) / o.BonePct * (own ? 0.4 : 1.0),
                        F("{0} {1} is {2:0.0} cm = {3:+0.0;-0.0} % of its own {4:0.0} {5}, the most at #{6}; the game's pose there {7:+0.0;-0.0} %{8}", kn[k], bn, d[pk], pct, rf, Fr(r[0], r[1]), pk, gp, own ? " -- the game's own pose does it" : ""), 2 + k, own);
                }
            }
            // 6. the leg all the way out, or folded flat
            foreach (int[] r in Runs(i => ex[i] > o.ExtHi, 1, 0)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (ex[i] > ex[pk]) pk = i;
                bool own = gex[pk] > o.ExtHi;
                Add(own ? "leg straight (the game's own)" : "LEG STRAIGHT", kn[k] + " leg", r[0], r[1], pk, ex[pk], (1 + (ex[pk] - o.ExtHi)) * (own ? 0.4 : 1.0),
                    F("{0} leg at {1:0.0} % of its length (hip to ankle {2:0.0} of {3:0.0} cm) {4}; the game's pose at #{5}: {6:0.0} %", kn[k], ex[pk], m[q + "hip_ankle"][pk], thighRef[k] + shinRef[k], Fr(r[0], r[1]), pk, gex[pk]), ja, own);
            }
            foreach (int[] r in Runs(i => ex[i] < o.ExtLo, 1, 0)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (ex[i] < ex[pk]) pk = i;
                bool own = gex[pk] < o.ExtLo;
                Add(own ? "leg folded (the game's own)" : "LEG FOLDED", kn[k] + " leg", r[0], r[1], pk, ex[pk], (1 + (o.ExtLo - ex[pk]) / 5) * (own ? 0.4 : 1.0),
                    F("{0} leg folded to {1:0.0} % of its length (hip to ankle {2:0.0} of {3:0.0} cm) {4}; the game's pose at #{5}: {6:0.0} %", kn[k], ex[pk], m[q + "hip_ankle"][pk], thighRef[k] + shinRef[k], Fr(r[0], r[1]), pk, gex[pk]), 2 + k, own);
            }
            // 7. a foot pitched steeply while at the ground
            foreach (int[] r in Runs(i => s.f[i].groundOk && Math.Abs(pi[i]) > o.PitchDeg && cl[i] < o.PitchNearCm, 1, 0)) {
                int pk = r[0]; for (int i = r[0]; i <= r[1]; i++) if (Math.Abs(pi[i]) > Math.Abs(pi[pk])) pk = i;
                bool own = Math.Abs(gpi[pk]) > o.PitchDeg;
                Add(own ? "foot pitch (the game's own)" : "FOOT PITCH", kn[k] + " foot", r[0], r[1], pk, pi[pk], (1 + (Math.Abs(pi[pk]) - o.PitchDeg) / 10) * (own ? 0.4 : 1.0),
                    F("{0} foot pitched {1:+0.0;-0.0} deg ({2}) while {3:0.0} cm clear of the ground {4}; the game's pose at #{5}: {6:+0.0;-0.0} deg", kn[k], pi[pk], pi[pk] < 0 ? "toe down" : "toe up", cl[pk], Fr(r[0], r[1]), pk, gpi[pk]), jt, own);
            }
        }
        // 8. poses the screen never had as recorded
        foreach (int[] r in Runs(i => s.f[i].rejected, 1, 0)) Add("REJECTED", "pose", r[0], r[1], r[0], r[1] - r[0] + 1, 3, F("the mod's pose was REJECTED {0} (a bone not finite, not a unit rotation, or 2 m off): the screen had the game's pose", Fr(r[0], r[1])), -1, false);
        foreach (int[] r in Runs(i => s.f[i].unwritten, 1, 0)) Add("not written", "pose", r[0], r[1], r[0], r[1] - r[0] + 1, 0.8, F("g_Ct differs from the game's pose but 'changed' was not set {0}: the edits were not written back, the screen had the game's pose", Fr(r[0], r[1])), -1, false);
        foreach (int[] r in Runs(i => s.f[i].badNumbers && !s.f[i].rejected, 1, 0)) Add("BAD NUMBERS", "pose", r[0], r[1], r[0], r[1] - r[0] + 1, 4, F("a bone's place is not a finite number {0}", Fr(r[0], r[1])), -1, false);
        foreach (int[] r in Runs(i => !s.f[i].meshOk, 1, 0)) Add("BAD NUMBERS", "mesh", r[0], r[1], r[0], r[1] - r[0] + 1, 4, F("the mesh's component-to-world is not finite {0}", Fr(r[0], r[1])), -1, false);
        ev.Sort((a, b) => b.sev != a.sev ? b.sev.CompareTo(a.sev) : a.from.CompareTo(b.from));
    }
    public List<Ev> At(int i) { List<Ev> r = new List<Ev>(); foreach (Ev e in ev) if (i >= e.from && i <= e.to && e.sev >= 1) r.Add(e); return r; }
}

public static class Pic {
    static string F(string fmt, params object[] a) { return string.Format(CultureInfo.InvariantCulture, fmt, a); }
    static readonly Color cGame = Color.FromArgb(172, 172, 172), cL = Color.FromArgb(214, 28, 30), cR = Color.FromArgb(22, 88, 222), cBody = Color.FromArgb(0, 0, 0), cArm = Color.FromArgb(96, 96, 96),
                          cDeck = Color.FromArgb(240, 132, 0), cSkelBoard = Color.FromArgb(150, 120, 0), cGround = Color.FromArgb(120, 92, 58), cGroundFill = Color.FromArgb(241, 234, 222), cGrid = Color.FromArgb(232, 232, 232),
                          cEvent = Color.FromArgb(235, 0, 140), cActive = Color.FromArgb(255, 249, 214);
    static Font Fnt(float px, bool bold) { return new Font("Consolas", px, bold ? FontStyle.Bold : FontStyle.Regular, GraphicsUnit.Pixel); }
    static Font FntUi(float px, bool bold) { return new Font("Segoe UI", px, bold ? FontStyle.Bold : FontStyle.Regular, GraphicsUnit.Pixel); }
    static Graphics G(Bitmap b) { Graphics g = Graphics.FromImage(b); g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit; g.Clear(Color.White); return g; }

    class View {
        public int kind;                                     // 0 side, 1 front, 2 top
        public RectangleF r; public double scale, hMid, zLo, bMid; public V3 anchor, va, vb;
        public PointF Map(V3 w) {
            V3 d = w - anchor; double ra = d.x * va.x + d.y * va.y, rb = d.x * vb.x + d.y * vb.y;
            if (kind == 0) return new PointF((float)(r.X + r.Width / 2 + (ra - hMid) * scale), (float)(r.Bottom - (w.z - zLo) * scale));
            if (kind == 1) return new PointF((float)(r.X + r.Width / 2 + (rb - hMid) * scale), (float)(r.Bottom - (w.z - zLo) * scale));
            return new PointF((float)(r.X + r.Width / 2 + (ra - hMid) * scale), (float)(r.Y + r.Height / 2 - (rb - bMid) * scale));
        }
    }
    static bool Ok(PointF p) { return !(float.IsNaN(p.X) || float.IsNaN(p.Y) || float.IsInfinity(p.X) || float.IsInfinity(p.Y)) && Math.Abs(p.X) < 1e6 && Math.Abs(p.Y) < 1e6; }
    static void Line(Graphics g, Pen pen, View v, V3 a, V3 b) { if (!a.Finite || !b.Finite) return; PointF p = v.Map(a), q = v.Map(b); if (Ok(p) && Ok(q)) g.DrawLine(pen, p, q); }
    static void Chain(Graphics g, Pen pen, View v, V3[] w, List<int> chain) { for (int i = 1; i < chain.Count; i++) Line(g, pen, v, w[chain[i - 1]], w[chain[i]]); }
    static void Dot(Graphics g, Brush br, View v, V3 a, float rad) { if (!a.Finite) return; PointF p = v.Map(a); if (Ok(p)) g.FillEllipse(br, p.X - rad, p.Y - rad, 2 * rad, 2 * rad); }

    static void Pose(Graphics g, View v, Analysis A, V3[] w, bool colour, bool legsOnly) {
        Seg s = A.s; float k = (float)Math.Max(0.6, Math.Min(2.0, v.scale / 3.0));
        Color body = colour ? cBody : cGame, arm = colour ? cArm : cGame;
        if (A.o.AllBones) using (Pen thin = new Pen(colour ? Color.FromArgb(150, 150, 190) : Color.FromArgb(215, 215, 215), 1f))
            for (int i = 0; i < s.bones; i++) if (s.parent[i] >= 0 && s.parent[i] < s.bones) Line(g, thin, v, w[i], w[s.parent[i]]);
        if (!legsOnly) {
            using (Pen pa = new Pen(arm, (colour ? 1.9f : 1.2f) * k)) { pa.LineJoin = LineJoin.Round; for (int sd = 0; sd < 2; sd++) Chain(g, pa, v, w, A.armChain[sd]); }
            using (Pen pb = new Pen(body, (colour ? 2.4f : 1.2f) * k)) {
                pb.LineJoin = LineJoin.Round; Chain(g, pb, v, w, A.spineChain);
                if (s.head >= 0 && w[s.head].Finite) {
                    V3 up = (s.neck >= 0 && w[s.neck].Finite && (w[s.head] - w[s.neck]).Len > 0.5) ? (w[s.head] - w[s.neck]).Norm() : new V3(0, 0, 1);
                    PointF c = v.Map(w[s.head] + up * 9.0); float rr = (float)(9.5 * v.scale);
                    if (Ok(c)) g.DrawEllipse(pb, c.X - rr, c.Y - rr, 2 * rr, 2 * rr);
                }
            }
        } else if (s.pelvis >= 0) using (SolidBrush bb = new SolidBrush(body)) Dot(g, bb, v, w[s.pelvis], 2.5f * k);
        for (int sd = 0; sd < 2; sd++) {
            Color c = colour ? (sd == 0 ? cL : cR) : cGame;
            using (Pen pl = new Pen(c, (colour ? 2.6f : 1.3f) * k)) { pl.LineJoin = LineJoin.Round; Chain(g, pl, v, w, A.legChain[sd]); }
            if (s.foot[sd] >= 0 && s.toe[sd] >= 0) using (Pen pf = new Pen(c, (colour ? 5.0f : 2.6f) * k)) { pf.StartCap = LineCap.Round; pf.EndCap = LineCap.Round; Line(g, pf, v, w[s.foot[sd]], w[s.toe[sd]]); }
            if (colour) using (SolidBrush br = new SolidBrush(c)) { if (s.calf[sd] >= 0) Dot(g, br, v, w[s.calf[sd]], 2.6f * k); if (s.thigh[sd] >= 0) Dot(g, br, v, w[s.thigh[sd]], 2.2f * k); }
        }
    }
    static void Deck(Graphics g, View v, Analysis A, Frame f) {
        if (!f.deckOk) return;
        Seg s = A.s; float k = (float)Math.Max(0.6, Math.Min(2.0, v.scale / 3.0));
        double hl = (s.deckHalfLen > 5 && s.deckHalfLen < 200) ? s.deckHalfLen : 40, hw = (s.deckHalfWidth > 2 && s.deckHalfWidth < 60) ? s.deckHalfWidth : 10.5, cx = Math.Abs(s.deckCentreX) < 50 ? s.deckCentreX : 0;
        V3 c = f.deckC + f.deckX * cx, nose = c + f.deckX * hl, tail = c - f.deckX * hl;
        using (Pen thin = new Pen(cDeck, 1.2f * k)) {
            V3[] cor = { nose + f.deckY * hw, nose - f.deckY * hw, tail - f.deckY * hw, tail + f.deckY * hw };
            for (int i = 0; i < 4; i++) Line(g, thin, v, cor[i], cor[(i + 1) % 4]);
        }
        using (Pen thick = new Pen(cDeck, 4.2f * k)) { thick.StartCap = LineCap.Round; thick.EndCap = LineCap.Round; Line(g, thick, v, tail, nose); Line(g, thick, v, nose, nose + f.deckZ * 9.0); if (v.kind != 0) Line(g, thick, v, nose - f.deckY * hw, nose + f.deckY * hw); }
    }
    static void Ground(Graphics g, View v, Frame f, double h0, double h1) {
        if (v.kind == 2 || !f.groundKnown) return;
        V3 dir = v.kind == 0 ? v.va : v.vb;
        V3 a = new V3(v.anchor.x + dir.x * h0, v.anchor.y + dir.y * h0, 0), b = new V3(v.anchor.x + dir.x * h1, v.anchor.y + dir.y * h1, 0);
        a.z = f.GroundAt(a.x, a.y); b.z = f.GroundAt(b.x, b.y);
        PointF p = v.Map(a), q = v.Map(b);
        if (!Ok(p) || !Ok(q)) return;
        using (SolidBrush fill = new SolidBrush(cGroundFill)) g.FillPolygon(fill, new PointF[] { p, q, new PointF(q.X, v.r.Bottom + 2), new PointF(p.X, v.r.Bottom + 2) });
        using (Pen pg = new Pen(cGround, 1.8f)) { if (!f.groundOk) pg.DashPattern = new float[] { 5, 4 }; g.DrawLine(pg, p, q); }
    }
    static V3 JointPos(Analysis A, int i, int joint) { return joint >= 0 ? A.P[0][joint][i] : V3.NaN; }

    // ------------------------------------------------------------------ the contact sheet
    public static List<string> Sheet(Analysis A, string basePath) {
        List<string> outp = new List<string>();
        Seg s = A.s; Options o = A.o; int n = A.n, pre = A.pre;
        bool legs = o.Focus == "legs";
        bool vs = o.Views.IndexOf("side", StringComparison.OrdinalIgnoreCase) >= 0, vf = o.Views.IndexOf("front", StringComparison.OrdinalIgnoreCase) >= 0, vt = o.Views.IndexOf("top", StringComparison.OrdinalIgnoreCase) >= 0;
        if (!vs && !vf && !vt) vs = vf = vt = true;
        // which poses
        int first = 0, last = n - 1; string shown;
        if (!double.IsNaN(o.From) || !double.IsNaN(o.To)) {
            double lo = double.IsNaN(o.From) ? double.NegativeInfinity : o.From, hi = double.IsNaN(o.To) ? double.PositiveInfinity : o.To;
            first = -1; for (int i = 0; i < n; i++) if (A.ms[i] >= lo - 0.5 && A.ms[i] <= hi + 0.5) { if (first < 0) first = i; last = i; }
            if (first < 0) { outp.Add("  (no pose in that time window: no sheet)"); return outp; }
        } else if (!o.Full) {
            int lastActive = pre; for (int i = 0; i < n; i++) if (A.active[i]) lastActive = i;
            first = Math.Max(0, pre - Math.Max(0, o.PreShow)); last = Math.Min(n - 1, lastActive + Math.Max(0, o.PostShow));
        }
        int K = Math.Max(1, o.Every);
        string thinned = "";
        if (o.MaxCells > 0 && (last - first) / K + 1 > o.MaxCells) {     // a very long segment: fewer poses rather than a picture nobody can open
            int k2 = (int)Math.Ceiling((last - first + 1) / (double)o.MaxCells);
            thinned = F(" (-Every {0} would be {1} poses: more than -MaxCells {2}; -From / -To look closer)", K, (last - first) / K + 1, o.MaxCells);
            K = k2;
        }
        SortedSet<int> pick = new SortedSet<int>();
        for (int i = first; i <= last; i++) if (((i - pre) % K + K) % K == 0) pick.Add(i);
        foreach (Ev e in A.ev) if (e.sev >= 1 && e.peak >= first && e.peak <= last) pick.Add(e.peak);   // an event's worst pose is never stepped over
        List<int> cells = pick.ToList();
        shown = F("poses #{0}..#{1} of #0..#{2} ({3:+0;-0;0}..{4:+0;-0;0} ms), every {5}{6}{7}", first, last, n - 1, A.ms[first], A.ms[last], K == 1 ? "one" : K == 2 ? "2nd" : K == 3 ? "3rd" : K + "th", thinned,
                  (first > 0 || last < n - 1) ? "; -Full shows all" : "");
        if (thinned != "") outp.Add("  note: every " + K + "th pose on the sheet" + thinned);
        // what each cell has to hold: every drawn point, about the mesh's own place, along the two view axes
        double aLo = 1e9, aHi = -1e9, bLo = 1e9, bHi = -1e9;
        double[] zLoC = new double[cells.Count], zHiC = new double[cells.Count];
        for (int ci = 0; ci < cells.Count; ci++) {
            Frame f = s.f[cells[ci]]; double zl = 1e9, zh = -1e9;
            List<V3> pts = new List<V3>();
            foreach (V3[] w in new V3[][] { f.wD, f.wG }) {
                foreach (int b in A.legChain[0]) pts.Add(w[b]); foreach (int b in A.legChain[1]) pts.Add(w[b]);
                for (int sd = 0; sd < 2; sd++) if (s.toe[sd] >= 0) pts.Add(w[s.toe[sd]]);
                if (!legs) {
                    foreach (int b in A.spineChain) pts.Add(w[b]); foreach (int b in A.armChain[0]) pts.Add(w[b]); foreach (int b in A.armChain[1]) pts.Add(w[b]);
                    if (s.head >= 0 && w[s.head].Finite) {          // the head's circle, whichever way it is seen
                        V3 up = (s.neck >= 0 && w[s.neck].Finite && (w[s.head] - w[s.neck]).Len > 0.5) ? (w[s.head] - w[s.neck]).Norm() : new V3(0, 0, 1);
                        V3 hc = w[s.head] + up * 9.0;
                        pts.Add(hc + A.va * 10.5); pts.Add(hc - A.va * 10.5); pts.Add(hc + A.vb * 10.5); pts.Add(hc - A.vb * 10.5); pts.Add(hc + new V3(0, 0, 10.5));
                    }
                }
            }
            if (f.deckOk) {
                double hl = (s.deckHalfLen > 5 && s.deckHalfLen < 200) ? s.deckHalfLen : 40, hw = (s.deckHalfWidth > 2 && s.deckHalfWidth < 60) ? s.deckHalfWidth : 10.5;
                for (int sx = -1; sx <= 1; sx += 2) for (int sy = -1; sy <= 1; sy += 2) pts.Add(f.deckC + f.deckX * (sx * (hl + 2)) + f.deckY * (sy * hw));
                pts.Add(f.deckC + f.deckX * hl + f.deckZ * 10);
            }
            foreach (V3 p in pts) {
                if (!p.Finite) continue;
                double ra = (p.x - f.meshP.x) * A.va.x + (p.y - f.meshP.y) * A.va.y, rb = (p.x - f.meshP.x) * A.vb.x + (p.y - f.meshP.y) * A.vb.y;
                if (Math.Abs(ra) > 160 || Math.Abs(rb) > 160 || Math.Abs(p.z - f.meshP.z) > 320) continue;   // (a wild bone does not get to size the sheet)
                aLo = Math.Min(aLo, ra); aHi = Math.Max(aHi, ra); bLo = Math.Min(bLo, rb); bHi = Math.Max(bHi, rb); zl = Math.Min(zl, p.z); zh = Math.Max(zh, p.z);
            }
            if (f.groundKnown) zl = Math.Min(zl, f.GroundAt(f.meshP.x, f.meshP.y));
            if (zl > zh) { zl = f.meshP.z; zh = f.meshP.z + 100; }
            zLoC[ci] = zl; zHiC[ci] = zh;
        }
        if (aLo > aHi) { aLo = -60; aHi = 60; } if (bLo > bHi) { bLo = -40; bHi = 40; }
        aLo -= 6; aHi += 6; bLo -= 6; bHi += 6;
        double sc = Math.Max(0.5, o.Scale);
        int gut = 58, labH = 54, gap = 6;
        int cellW = (int)Math.Ceiling(Math.Max(aHi - aLo, vf ? bHi - bLo : 0) * sc) + 8;
        if (cellW < 150) cellW = 150;
        int cols = Math.Max(1, (Math.Max(o.MaxWidth, gut + cellW + 8) - gut - 8) / cellW);
        if (cols > cells.Count) cols = cells.Count;
        int bands = (cells.Count + cols - 1) / cols;
        int width = Math.Max(gut + cols * cellW + 8, 1180);
        int topH = (int)Math.Ceiling((bHi - bLo) * sc);
        // each row of cells has its own height range (the same baseline across the row, so height reads across its poses)
        int[] bandH = new int[bands]; double[] bandZLo = new double[bands], bandZHi = new double[bands];
        for (int b = 0; b < bands; b++) {
            double zl = 1e9, zh = -1e9;
            for (int ci = b * cols; ci < Math.Min(cells.Count, (b + 1) * cols); ci++) { zl = Math.Min(zl, zLoC[ci]); zh = Math.Max(zh, zHiC[ci]); }
            zl -= 7; zh += 6;
            bandZLo[b] = zl; bandZHi[b] = zh;
            int vh = (int)Math.Ceiling((zh - zl) * sc);
            bandH[b] = labH + (vs ? vh + gap : 0) + (vf ? vh + gap : 0) + (vt ? topH + gap : 0) + 10;
        }
        int headH = 92;
        // pages
        List<int[]> pages = new List<int[]>(); int from = 0, acc = headH;
        for (int b = 0; b < bands; b++) { if (b > from && acc + bandH[b] > o.MaxHeight) { pages.Add(new int[] { from, b - 1 }); from = b; acc = headH; } acc += bandH[b]; }
        pages.Add(new int[] { from, bands - 1 });
        for (int pg = 0; pg < pages.Count; pg++) {
            int height = headH; for (int b = pages[pg][0]; b <= pages[pg][1]; b++) height += bandH[b];
            string path = basePath + "_sheet" + (pages.Count > 1 ? "_p" + (pg + 1) : "") + ".png";
            using (Bitmap bmp = new Bitmap(width, height, PixelFormat.Format24bppRgb)) using (Graphics g = G(bmp))
            using (Font fTitle = FntUi(17, true), fSmall = FntUi(13, false), fLab = Fnt(14, true), fFlag = Fnt(12.5f, false), fRow = FntUi(12, true), fTick = Fnt(10.5f, false))
            using (SolidBrush black = new SolidBrush(Color.Black), grey = new SolidBrush(Color.FromArgb(90, 90, 90)), evb = new SolidBrush(cEvent)) {
                Header(g, A, width, fTitle, fSmall, shown + F("; {0} px/cm", sc) + (pages.Count > 1 ? F("; page {0} of {1}", pg + 1, pages.Count) : ""), true);
                int y = headH;
                for (int b = pages[pg][0]; b <= pages[pg][1]; b++) {
                    double zl = bandZLo[b], zh = bandZHi[b]; int vh = (int)Math.Ceiling((zh - zl) * sc);
                    int ySide = y + labH, yFront = ySide + (vs ? vh + gap : 0), yTop = yFront + (vf ? vh + gap : 0);
                    double zRef = Math.Round(s.f[cells[b * cols]].groundKnown ? s.f[cells[b * cols]].GroundAt(s.f[cells[b * cols]].meshP.x, s.f[cells[b * cols]].meshP.y) : zl + 7);
                    // the row's gutter: view names and heights over the row's first pose's ground
                    for (int vi = 0; vi < 2; vi++) {
                        if ((vi == 0 && !vs) || (vi == 1 && !vf)) continue;
                        int y0 = vi == 0 ? ySide : yFront;
                        using (Pen pgd = new Pen(cGrid, 1f)) for (double h = Math.Ceiling((zl - zRef) / 50.0) * 50.0; zRef + h <= zh; h += 50.0) {
                            float yy = (float)(y0 + vh - (zRef + h - zl) * sc);
                            g.DrawLine(pgd, gut - 4, yy, gut + (Math.Min(cells.Count, (b + 1) * cols) - b * cols) * cellW, yy);
                            g.DrawString(F("{0:0}", h), fTick, grey, gut - 30, yy - 7);
                        }
                        g.DrawString(vi == 0 ? "SIDE" : "FRONT", fRow, black, 2, y0 + 2);
                        g.DrawString("cm", fTick, grey, 2, y0 + 18);
                    }
                    if (vt) g.DrawString("TOP", fRow, black, 2, yTop + 2);
                    for (int ci = b * cols; ci < Math.Min(cells.Count, (b + 1) * cols); ci++) {
                        int i = cells[ci]; Frame f = s.f[i]; int x = gut + (ci - b * cols) * cellW;
                        List<Ev> here = A.At(i);
                        // the label
                        string l1 = F("#{0} {1:+0;-0;0} ms", i, A.ms[i]);
                        if (i == pre) g.FillRectangle(Brushes.Gold, x + 1, y + 2, cellW - 3, 17);
                        using (StringFormat sf = new StringFormat(StringFormatFlags.NoWrap)) {
                            sf.Trimming = StringTrimming.EllipsisCharacter;
                            g.DrawString(l1, fLab, here.Count > 0 ? evb : black, new RectangleF(x + 2, y + 2, cellW - 4, 18), sf);
                            g.DrawString(Seg.Letters(f.flags) + (f.turned ? " turned" : "") + (f.unwritten ? " (edits not written)" : ""), fFlag, grey, new RectangleF(x + 2, y + 20, cellW - 4, 16), sf);
                            if (here.Count > 0) g.DrawString(string.Join(" ", here.Select(e => Short(e.kind)).Distinct().ToArray()), fFlag, evb, new RectangleF(x + 2, y + 35, cellW - 4, 16), sf);
                        }
                        using (Pen sep = new Pen(Color.FromArgb(214, 214, 214), 1f)) g.DrawLine(sep, x, y + 2, x, y + bandH[b] - 12);
                        V3 anchor = new V3(f.meshP.x, f.meshP.y, 0);
                        for (int kind = 0; kind < 3; kind++) {
                            if ((kind == 0 && !vs) || (kind == 1 && !vf) || (kind == 2 && !vt)) continue;
                            View v = new View(); v.kind = kind; v.scale = sc; v.anchor = anchor; v.va = A.va; v.vb = A.vb; v.zLo = zl;
                            v.hMid = kind == 1 ? (bLo + bHi) / 2 : (aLo + aHi) / 2; v.bMid = (bLo + bHi) / 2;
                            v.r = new RectangleF(x + 1, kind == 0 ? ySide : kind == 1 ? yFront : yTop, cellW - 2, kind == 2 ? topH : vh);
                            GraphicsState st = g.Save(); g.SetClip(v.r);
                            Ground(g, v, f, kind == 0 ? aLo - 40 : bLo - 40, kind == 0 ? aHi + 40 : bHi + 40);
                            if (kind != 2) using (Pen pgd = new Pen(Color.FromArgb(226, 226, 226), 1f)) for (double h = Math.Ceiling((zl - zRef) / 50.0) * 50.0; zRef + h <= zh; h += 50.0) { float yy = (float)(v.r.Bottom - (zRef + h - zl) * sc); if (h != 0) g.DrawLine(pgd, v.r.Left, yy, v.r.Right, yy); }
                            Pose(g, v, A, f.wG, false, legs);
                            Deck(g, v, A, f);
                            if (s.handAnchor[0] >= 0 && s.handAnchor[1] >= 0 && s.flipper >= 0) using (Pen sk = new Pen(cSkelBoard, 1.3f)) {
                                // the SKELETON's board: through its board bone, along the line of its two hand anchors (they sit at its ends)
                                V3 hv = (f.wD[s.handAnchor[0]] - f.wD[s.handAnchor[1]]) * 0.5;
                                sk.DashPattern = new float[] { 4, 3 }; Line(g, sk, v, f.wD[s.flipper] - hv, f.wD[s.flipper] + hv);
                            }
                            Pose(g, v, A, f.wD, true, legs);
                            foreach (Ev e in here) {
                                V3 jp = JointPos(A, i, e.joint); if (!jp.Finite) continue;
                                PointF c = v.Map(jp); if (Ok(c)) using (Pen pe = new Pen(cEvent, 2f)) g.DrawEllipse(pe, c.X - 9, c.Y - 9, 18, 18);
                            }
                            g.Restore(st);
                        }
                    }
                    y += bandH[b];
                }
                bmp.Save(path, ImageFormat.Png);
            }
            outp.Add(F("  sheet  {0}  ({1} x {2}, {3} poses in {4} row{5})", path, width, height, cells.Count, bands, bands == 1 ? "" : "s"));
        }
        return outp;
    }
    static string Short(string kind) {
        string k = kind.ToUpperInvariant();
        if (k.StartsWith("JUMP")) return "JUMP"; if (k.StartsWith("TURN")) return "TURN"; if (k.StartsWith("SLIDE")) return "SLIDE"; if (k.StartsWith("UNDER THE DECK")) return "UNDER-DECK";
        if (k.StartsWith("UNDER THE GROUND")) return "UNDER-GROUND"; if (k.StartsWith("TOE UNDER")) return "TOE-UNDER"; if (k.StartsWith("BONE")) return "BONE-LEN"; if (k.StartsWith("LEG STRAIGHT")) return "STRAIGHT";
        if (k.StartsWith("LEG FOLDED")) return "FOLDED"; if (k.StartsWith("FOOT PITCH")) return "PITCH"; if (k.StartsWith("REJECTED")) return "REJECTED"; if (k.StartsWith("BAD")) return "BAD"; return k;
    }
    static void Header(Graphics g, Analysis A, int width, Font fTitle, Font fSmall, string shown, bool sheet) {
        Seg s = A.s;
        using (SolidBrush black = new SolidBrush(Color.Black), grey = new SolidBrush(Color.FromArgb(70, 70, 70))) {
            g.DrawString(F("segment {0} (run's #{1}, mod v{2})   {3}   {4} poses, {5:0.00} s   on: {6}   ended: {7}{8}", s.index, s.seq, s.modVersion, s.When, s.frames, (A.ms[A.n - 1] - A.ms[0]) / 1000.0,
                Seg.OnNames(s.flagsAny), s.EndText, (s.segFlags & 1) != 0 ? " (goes on from the one before)" : ""), fTitle, black, 6, 4);
            bool anyTurn = false; foreach (Frame fr in s.f) if (fr.turned) anyTurn = true;
            g.DrawString(shown + (!anyTurn ? "" : A.o.AsRecorded ? "; half-turn poses (Y): the game's pose AS RECORDED, i.e. already turned by the mod" : "; half-turn poses (Y): the game's pose as it ARRIVED (the turn taken out; -AsRecorded shows the file's)"), fSmall, grey, 6, 28);
            float x = 6, y = 48;
            Action<string, Color, bool> item = (text, c, bold) => { using (SolidBrush b = new SolidBrush(c)) using (Font f = FntUi(13, bold)) { g.DrawString(text, f, b, x, y); x += g.MeasureString(text, f).Width + 2; } };
            if (sheet) {
                item("DRAWN (after the mod):", Color.Black, true); item("left leg", cL, true); item("right leg", cR, true); item("spine + head", cBody, true); item("arms", cArm, true);
                item("| the GAME's pose", Color.FromArgb(140, 140, 140), true); item("| drawn deck (the tick / bar: its +x end)", cDeck, true); item("| skeleton's board (dashed)", cSkelBoard, false); item("| ground", cGround, true); item("| ring = an event", cEvent, true);
                x = 6; y = 68;
                item("SIDE: seen across the deck as it stood at the start, its +x end to the right.  FRONT: looking back along it from its +x end (+y right).  TOP: from above (+x right, +y up).  Each cell is centred on the mesh's own place at its pose; heights are true, one baseline per row.", Color.FromArgb(70, 70, 70), false);
            } else {
                item("left", cL, true); item("right", cR, true); item("pelvis", cBody, true); item("| solid = DRAWN (after the mod), dashed = the GAME's pose", Color.FromArgb(70, 70, 70), false);
                item("| yellow = a window of the mod's is open", Color.FromArgb(150, 120, 0), false); item("| triangle = an event (" + A.ev.Count(e => e.sev >= 1) + " in this segment)", cEvent, true);
            }
            x = 6; y = sheet ? 68 + 0 : 68;
            if (!sheet) item("flags: A hop-air  L landing-blend  P plant  B bone-hand  F feet-hold  H pose-hold  G foot-ground  Y half-turn  R grab  T trick-trace", Color.FromArgb(70, 70, 70), false);
        }
    }

    // ------------------------------------------------------------------ the time plots
    class Series { public double[] y; public Color c; public bool dash; public float w = 1.8f; }
    static Series S(double[] y, Color c, bool dash) { Series s = new Series(); s.y = y; s.c = c; s.dash = dash; if (dash) s.w = 1.3f; return s; }
    static Series S(double[] y, Color c, bool dash, float w) { Series s = S(y, c, dash); s.w = w; return s; }
    static double NiceStep(double range, int target) {
        double raw = range / Math.Max(1, target), mag = Math.Pow(10, Math.Floor(Math.Log10(Math.Max(raw, 1e-9)))), n = raw / mag;
        return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * mag;
    }
    static void Panel(Graphics g, RectangleF r, string title, Analysis A, double x0, double x1, List<Series> ss, string[] evKinds, int[] evJoints, double[] hlines) {
        float L = r.X + 48, T = r.Y + 20, R = r.Right - 8, B = r.Bottom - 18;
        double lo = 1e18, hi = -1e18;
        foreach (Series s in ss) for (int i = 0; i < A.n; i++) { double v = s.y[i]; if (double.IsNaN(v) || double.IsInfinity(v) || A.ms[i] < x0 || A.ms[i] > x1) continue; lo = Math.Min(lo, v); hi = Math.Max(hi, v); }
        if (lo > hi) { lo = 0; hi = 1; }
        if (hi - lo < 2) { double mid = (lo + hi) / 2; lo = mid - 1; hi = mid + 1; }
        double pad = (hi - lo) * 0.07; lo -= pad; hi += pad;
        Func<double, float> X = v => (float)(L + (v - x0) / (x1 - x0) * (R - L));
        Func<double, float> Y = v => (float)(B - (v - lo) / (hi - lo) * (B - T));
        using (Font ft = FntUi(13, true), fa = Fnt(10.5f, false)) using (SolidBrush black = new SolidBrush(Color.Black), grey = new SolidBrush(Color.FromArgb(95, 95, 95)), act = new SolidBrush(cActive))
        using (Pen grid = new Pen(cGrid, 1f), axis = new Pen(Color.FromArgb(150, 150, 150), 1f), zero = new Pen(Color.FromArgb(120, 120, 120), 1f)) {
            int a0 = -1;
            for (int i = 0; i <= A.n; i++) {
                bool on = i < A.n && A.active[i] && A.ms[i] >= x0 && A.ms[i] <= x1;
                if (on && a0 < 0) a0 = i;
                if (!on && a0 >= 0) { float xa = X(A.ms[a0]), xb = X(A.ms[i - 1]); g.FillRectangle(act, xa, T, Math.Max(1.5f, xb - xa), B - T); a0 = -1; }
            }
            double ys = NiceStep(hi - lo, 5);
            for (double v = Math.Ceiling(lo / ys) * ys; v <= hi; v += ys) { g.DrawLine(Math.Abs(v) < ys * 1e-6 ? zero : grid, L, Y(v), R, Y(v)); g.DrawString(F("{0:0.##}", v), fa, grey, r.X + 2, Y(v) - 7); }
            double xs = NiceStep(x1 - x0, 12);
            for (double v = Math.Ceiling(x0 / xs) * xs; v <= x1; v += xs) { g.DrawLine(grid, X(v), T, X(v), B); g.DrawString(F("{0:0}", v), fa, grey, X(v) - 12, B + 2); }
            g.DrawRectangle(axis, L, T, R - L, B - T);
            if (0 >= x0 && 0 <= x1) using (Pen p0 = new Pen(Color.FromArgb(60, 60, 60), 1.3f)) { p0.DashPattern = new float[] { 2, 2 }; g.DrawLine(p0, X(0), T, X(0), B); }
            if (hlines != null) using (Pen ph = new Pen(Color.FromArgb(205, 120, 120), 1f)) { ph.DashPattern = new float[] { 6, 3 }; foreach (double h in hlines) if (h > lo && h < hi) g.DrawLine(ph, L, Y(h), R, Y(h)); }
            GraphicsState st = g.Save(); g.SetClip(new RectangleF(L, T, R - L, B - T));
            foreach (Series s in ss) using (Pen p = new Pen(s.c, s.w)) {
                if (s.dash) p.DashPattern = new float[] { 5, 3 };
                p.LineJoin = LineJoin.Round;
                List<PointF> run = new List<PointF>();
                for (int i = 0; i <= A.n; i++) {
                    bool ok = i < A.n && !double.IsNaN(s.y[i]) && !double.IsInfinity(s.y[i]) && A.ms[i] >= x0 && A.ms[i] <= x1;
                    if (ok) run.Add(new PointF(X(A.ms[i]), Y(s.y[i])));
                    else { if (run.Count > 1) g.DrawLines(p, run.ToArray()); else if (run.Count == 1) g.DrawEllipse(p, run[0].X - 1, run[0].Y - 1, 2, 2); run.Clear(); }
                }
            }
            g.Restore(st);
            if (evKinds != null) using (SolidBrush eb = new SolidBrush(cEvent)) foreach (Ev e in A.ev) {
                if (e.sev < 1 || A.ms[e.peak] < x0 || A.ms[e.peak] > x1) continue;
                bool kindOk = false; foreach (string k in evKinds) if (e.kind.StartsWith(k, StringComparison.OrdinalIgnoreCase)) kindOk = true;
                if (!kindOk) continue;
                if (evJoints != null && Array.IndexOf(evJoints, e.joint) < 0) continue;
                float xe = X(A.ms[e.peak]);
                g.FillPolygon(eb, new PointF[] { new PointF(xe - 5, T + 1), new PointF(xe + 5, T + 1), new PointF(xe, T + 10) });
                if (e.to > e.from) using (Pen pe = new Pen(cEvent, 2.5f)) g.DrawLine(pe, X(A.ms[e.from]), T + 2, X(A.ms[e.to]), T + 2);
            }
            g.DrawString(title, ft, black, L - 2, r.Y + 1);
        }
    }
    public static List<string> Plots(Analysis A, string basePath) {
        List<string> outp = new List<string>();
        Seg s = A.s; Options o = A.o;
        double x0 = double.IsNaN(o.From) ? A.ms[0] : o.From, x1 = double.IsNaN(o.To) ? A.ms[A.n - 1] : o.To;
        if (!(x1 > x0 + 1)) { x0 = A.ms[0]; x1 = Math.Max(A.ms[A.n - 1], x0 + 10); }
        int colW = 960, rowH = 232, headH = 92, cols = 2, rows = 6, flagsH = 17 * 13 + 34;
        int width = cols * colW + 12, height = headH + rows * rowH + flagsH + 8;
        string path = basePath + "_plots.png";
        Color cLg = cL, cRg = cR;
        using (Bitmap bmp = new Bitmap(width, height, PixelFormat.Format24bppRgb)) using (Graphics g = G(bmp)) using (Font fTitle = FntUi(17, true), fSmall = FntUi(13, false)) {
            Header(g, A, width, fTitle, fSmall, F("time in ms from the segment's start (the pose its first window opened, #{0}); heights and lengths in cm, in the world", A.pre), false);
            Func<string, List<Series>> feet = key => new List<Series> { S(A.Get("g_L_" + key), cLg, true), S(A.Get("g_R_" + key), cRg, true), S(A.Get("d_L_" + key), cL, false), S(A.Get("d_R_" + key), cR, false) };
            int[] ank = { 0, 1 }, pel = { 8 };
            double full0 = A.thighRef[0] + A.shinRef[0];
            Func<int, RectangleF> cell = i => new RectangleF(6 + (i % cols) * colW, headH + (i / cols) * rowH, colW - 6, rowH - 4);
            Panel(g, cell(0), "ankle over the ground", A, x0, x1, feet("ankle_gnd"), new string[] { "UNDER THE GROUND", "JUMP" }, ank, new double[] { 0 });
            Panel(g, cell(1), "toe joint over the ground", A, x0, x1, feet("toe_gnd"), new string[] { "toe under", "FOOT PITCH", "SLIDE" }, null, new double[] { 0 });
            Panel(g, cell(2), "ankle over the deck's plane", A, x0, x1, feet("over_deck"), new string[] { "UNDER THE DECK" }, null, new double[] { 0 });
            Panel(g, cell(3), "ankle along the deck (+ toward its +x end)", A, x0, x1, feet("along"), new string[] { "JUMP" }, ank, null);
            Panel(g, cell(4), "ankle across the deck (+ toward its +y edge)", A, x0, x1, feet("across"), new string[] { "JUMP" }, ank, null);
            Panel(g, cell(5), F("hip to ankle  (the leg's bones: L {0:0.0}, R {1:0.0} cm; lines at {2:0} % and {3:0} %)", full0, A.thighRef[1] + A.shinRef[1], o.ExtHi, o.ExtLo), A, x0, x1, feet("hip_ankle"),
                  new string[] { "LEG STRAIGHT", "LEG FOLDED" }, null, new double[] { full0 * o.ExtHi / 100.0, full0 * o.ExtLo / 100.0 });
            Panel(g, cell(6), F("thigh bone length  (its own: L {0:0.0}, R {1:0.0})", A.thighRef[0], A.thighRef[1]), A, x0, x1, feet("thigh"), new string[] { "BONE LENGTH" }, null, null);
            Panel(g, cell(7), F("shin bone length  (its own: L {0:0.0}, R {1:0.0})", A.shinRef[0], A.shinRef[1]), A, x0, x1, feet("shin"), new string[] { "BONE LENGTH" }, null, null);
            Panel(g, cell(8), "foot pitch, deg: ankle-to-toe against the horizontal (- = toe down)", A, x0, x1, feet("pitch"), new string[] { "FOOT PITCH", "TURN" }, null, new double[] { -o.PitchDeg, o.PitchDeg });
            Panel(g, cell(9), "pelvis over the ground", A, x0, x1, new List<Series> { S(A.Get("g_pelvis_gnd"), Color.FromArgb(110, 110, 110), true), S(A.Get("d_pelvis_gnd"), Color.Black, false) }, new string[] { "JUMP" }, pel, null);
            Panel(g, cell(10), "pelvis yaw, deg: the hips' line R->L in the world  (orange: the deck's long axis, grey dots: the mesh)", A, x0, x1,
                  new List<Series> { S(A.Get("mesh_yaw"), Color.FromArgb(170, 170, 170), true, 1.0f), S(A.Get("deck_yaw"), cDeck, false, 1.3f), S(A.Get("g_pelvis_yaw"), Color.FromArgb(110, 110, 110), true), S(A.Get("d_pelvis_yaw"), Color.Black, false) }, new string[] { "TURN" }, pel, null);
            Panel(g, cell(11), "jump per pose, cm: what a joint moved beyond its last speed  (ankles red/blue, knees lighter, pelvis black)", A, x0, x1,
                  new List<Series> { S(A.Get("d_L_knee_jump"), Color.FromArgb(240, 150, 150), false, 1.2f), S(A.Get("d_R_knee_jump"), Color.FromArgb(140, 175, 240), false, 1.2f), S(A.Get("g_L_ankle_jump"), cL, true), S(A.Get("g_R_ankle_jump"), cR, true),
                                     S(A.Get("d_pelvis_jump"), Color.Black, false, 1.3f), S(A.Get("d_L_ankle_jump"), cL, false), S(A.Get("d_R_ankle_jump"), cR, false) }, new string[] { "JUMP" }, null, new double[] { o.JumpCm });
            // the flags, one line each
            float fy = headH + rows * rowH + 22, L = 6 + 48, R = width - 14;
            string[] names = { "A hop-air", "L landing-blend", "P plant", "B bone-hand", "F feet-hold", "H pose-hold", "G foot-ground", "Y half-turn", "R grab", "T trick-trace", "c riding-learn", "* written back", "! REJECTED", "hold", "held (deck-ease)", "guard", "un-stretch" };
            uint[] bits = { 0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80, 0x100, 0x200, 0x400, 0x800, 0x2000000, 0x1000, 0x2000, 0x4000, 0x10000 };
            using (Font ff = Fnt(11f, false), ft = FntUi(13, true)) using (SolidBrush grey = new SolidBrush(Color.FromArgb(70, 70, 70)), bar = new SolidBrush(Color.FromArgb(70, 130, 70)), barT = new SolidBrush(Color.FromArgb(200, 140, 0)), barBad = new SolidBrush(cEvent), black = new SolidBrush(Color.Black))
            using (Pen grid = new Pen(cGrid, 1f)) {
                g.DrawString("what was on, pose by pose", ft, black, L - 2, fy - 20);
                float lblW = 118; float bx0 = L + lblW;
                Func<double, float> X = v => (float)(bx0 + (v - x0) / (x1 - x0) * (R - bx0));
                for (int k = 0; k < names.Length; k++) {
                    float yy = fy + k * 13;
                    g.DrawString(names[k], ff, grey, L - 46, yy - 1);
                    g.DrawLine(grid, bx0, yy + 11.5f, R, yy + 11.5f);
                    for (int i = 0; i < A.n; i++) {
                        if ((s.f[i].flags & bits[k]) == 0 || A.ms[i] < x0 || A.ms[i] > x1) continue;
                        float xa = X(A.ms[i]), xb = i + 1 < A.n ? X(Math.Min(x1, A.ms[i + 1])) : xa + 3;
                        g.FillRectangle(bits[k] == 0x2000000 ? barBad : k < 10 ? barT : bar, xa, yy + 2, Math.Max(1.5f, xb - xa + 0.5f), 8);
                    }
                }
                double xs = NiceStep(x1 - x0, 20);
                for (double v = Math.Ceiling(x0 / xs) * xs; v <= x1; v += xs) { g.DrawLine(grid, X(v), fy, X(v), fy + names.Length * 13); g.DrawString(F("{0:0}", v), ff, grey, X(v) - 12, fy + names.Length * 13 + 1); }
                if (0 >= x0 && 0 <= x1) using (Pen p0 = new Pen(Color.FromArgb(60, 60, 60), 1.3f)) { p0.DashPattern = new float[] { 2, 2 }; g.DrawLine(p0, X(0), fy, X(0), fy + names.Length * 13); }
                // the events, where they are
                using (SolidBrush eb = new SolidBrush(cEvent)) foreach (Ev e in A.ev) {
                    if (e.sev < 1 || A.ms[e.peak] < x0 || A.ms[e.peak] > x1) continue;
                    float xe = X(A.ms[e.peak]); g.FillPolygon(eb, new PointF[] { new PointF(xe - 4, fy - 9), new PointF(xe + 4, fy - 9), new PointF(xe, fy - 1) });
                }
            }
            bmp.Save(path, ImageFormat.Png);
        }
        outp.Add(F("  plots  {0}  ({1} x {2})", path, width, height));
        return outp;
    }
}

public static class Program {
    static string F(string fmt, params object[] a) { return string.Format(CultureInfo.InvariantCulture, fmt, a); }
    public static string[] Run(Options o) {
        List<string> outp = new List<string>(), warn = new List<string>();
        if (!File.Exists(o.Bin)) { outp.Add("no such file: " + o.Bin); return outp.ToArray(); }
        List<Seg> segs = Reader.Index(o.Bin, warn);
        outp.Add(F("{0}: {1} bytes, {2} segment{3}", o.Bin, new FileInfo(o.Bin).Length, segs.Count, segs.Count == 1 ? "" : "s"));
        foreach (string w in warn) outp.Add("  WARNING: " + w);
        if (segs.Count == 0) return outp.ToArray();
        if (o.List) {
            foreach (Seg s in segs)
                outp.Add(F("  {0,3}  run's #{1,-3} {2}  {3,4} poses ({4,2} before its start)  {5,3} bones  v{6}  on: {7}  | ended: {8}{9}{10}", s.index, s.seq, s.When, s.frames, s.preFrames, s.bones, s.modVersion,
                    Seg.OnNames(s.flagsAny), s.EndText, (s.segFlags & 1) != 0 ? " (goes on from the one before)" : "", s.truncated ? " CUT SHORT" : ""));
            return outp.ToArray();
        }
        List<Seg> todo = new List<Seg>();
        if (o.All) todo.AddRange(segs);
        else if (o.Segment > 0) { if (o.Segment > segs.Count) { outp.Add(F("there is no segment {0} (the file has {1})", o.Segment, segs.Count)); return outp.ToArray(); } todo.Add(segs[o.Segment - 1]); }
        else todo.Add(segs[segs.Count - 1]);
        Directory.CreateDirectory(o.Out);
        foreach (Seg s in todo) {
            Reader.Load(o.Bin, s);
            Analysis A = new Analysis(s, o);
            outp.Add(F("segment {0} (run's #{1}): {2}, {3} poses ({4} before its start), {5:0.00} s, {6} bones, on: {7}; ended: {8}", s.index, s.seq, s.When, s.frames, s.preFrames, (A.ms[A.n - 1] - A.ms[0]) / 1000.0, s.bones, Seg.OnNames(s.flagsAny), s.EndText));
            foreach (string nt in A.notes) outp.Add("  note: " + nt);
            string basePath = Path.Combine(o.Out, F("seg{0:000}", s.index));
            if (!o.NoSheet) outp.AddRange(Pic.Sheet(A, basePath));
            if (!o.NoPlots) outp.AddRange(Pic.Plots(A, basePath));
            if (o.Metrics) {
                WriteCsv(A, basePath + "_metrics.csv"); WriteEvents(A, basePath + "_events.csv");
                outp.Add("  csv    " + basePath + "_metrics.csv , " + basePath + "_events.csv");
                int real = A.ev.Count(e => e.sev >= 1);
                outp.Add(F("  events: {0} (and {1} of the game's own / minor), worst first -- # = the pose's index in the segment, ms from its start", real, A.ev.Count - real));
                int shown = 0;
                foreach (Ev e in A.ev) { if (shown >= o.Top) { outp.Add(F("    ... {0} more in the events csv", A.ev.Count - shown)); break; } outp.Add(F("   {0,2}. [{1,5:0.0}] {2,-16} {3}", ++shown, e.sev, e.kind, e.text)); }
                if (A.ev.Count == 0) outp.Add("    none");
            }
            s.f = null;
        }
        return outp.ToArray();
    }
    static string N(double v) { return (double.IsNaN(v) || double.IsInfinity(v)) ? "" : v.ToString("0.###", CultureInfo.InvariantCulture); }
    static void WriteCsv(Analysis A, string path) {
        using (StreamWriter w = new StreamWriter(path, false, new UTF8Encoding(false))) {
            w.Write("frame,ms,tick_ms,flags_hex,flags,changed,rejected,drawn_is_game,deck_ok,ground_ok,riding,off_board,mirror,leg_fix,half_turn,events");
            foreach (string k in A.keys) w.Write("," + k);
            w.WriteLine();
            for (int i = 0; i < A.n; i++) {
                Frame f = A.s.f[i];
                w.Write(F("{0},{1},{2},{3:x8},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15}", i, N(A.ms[i]), (int)(f.tick - A.s.f[A.pre].tick), f.flags, Seg.Letters(f.flags), f.changed ? 1 : 0, f.rejected ? 1 : 0, f.drawnIsGame ? 1 : 0,
                    f.deckOk ? 1 : 0, f.groundOk ? 1 : 0, (f.flags & 0x400000u) != 0 ? 1 : 0, (f.flags & 0x800000u) != 0 ? 1 : 0, (f.flags & 0x1000000u) != 0 ? 1 : 0, (f.flags & 0x4000000u) != 0 ? 1 : 0, f.turned ? 1 : 0,
                    string.Join(" ", A.At(i).Select(e => e.kind.Replace(' ', '-') + ":" + e.who.Replace(' ', '-')).ToArray())));
                foreach (string k in A.keys) w.Write("," + N(A.m[k][i]));
                w.WriteLine();
            }
        }
    }
    static void WriteEvents(Analysis A, string path) {
        using (StreamWriter w = new StreamWriter(path, false, new UTF8Encoding(false))) {
            w.WriteLine("rank,severity,kind,who,from,to,peak,ms_from,ms_to,ms_peak,value,text");
            int r = 0;
            foreach (Ev e in A.ev) w.WriteLine(F("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},\"{11}\"", ++r, N(e.sev), e.kind, e.who, e.from, e.to, e.peak, N(A.ms[e.from]), N(A.ms[e.to]), N(A.ms[e.peak]), N(e.value), e.text.Replace("\"", "'")));
        }
    }
}

}
'@

# (the namespace carries the source's hash: an edited script compiles afresh in a session that already ran the old one)
$md5 = [System.Security.Cryptography.MD5]::Create()
$hash = ([System.BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($cs))) -replace '-', '').Substring(0, 12)
$ns = "PoseView_$hash"
if (-not ("$ns.Program" -as [type])) {
    Add-Type -TypeDefinition ($cs.Replace('__NS__', $ns)) -ReferencedAssemblies System.Drawing, System.Core -IgnoreWarnings
}

$o = New-Object "$ns.Options"
$o.Bin = (Resolve-Path -LiteralPath $Bin).Path
if ($Out -eq '') { $Out = Join-Path (Get-Location).Path 'poseview_out' }
$o.Out = [System.IO.Path]::GetFullPath($Out)
$o.Segment = $Segment; $o.All = [bool]$All; $o.Every = $Every; $o.Metrics = [bool]$Metrics; $o.List = [bool]$List
$o.Scale = $Scale; $o.MaxWidth = $MaxWidth; $o.MaxHeight = $MaxHeight; $o.Full = [bool]$Full; $o.PreShow = $PreShow; $o.PostShow = $PostShow
if ($PageSize -gt 0) { $o.MaxWidth = $PageSize; $o.MaxHeight = $PageSize }
$o.MaxCells = $MaxCells
$o.From = $From; $o.To = $To; $o.Focus = $Focus; $o.Views = $Views; $o.AllBones = [bool]$AllBones; $o.AsRecorded = [bool]$AsRecorded
$o.JumpCm = $JumpCm; $o.SlideCm = $SlideCm; $o.PlantCm = $PlantCm; $o.BonePct = $BonePct; $o.ExtHi = $ExtHi; $o.ExtLo = $ExtLo
$o.PitchDeg = $PitchDeg; $o.PitchNearCm = $PitchNearCm; $o.TurnDeg = $TurnDeg; $o.Top = $Top; $o.NoSheet = [bool]$NoSheet; $o.NoPlots = [bool]$NoPlots
$prog = [type]"$ns.Program"
$prog::Run($o) | ForEach-Object { $_ }

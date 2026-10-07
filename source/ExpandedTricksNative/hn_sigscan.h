// hn_sigscan.h -- finds the game's functions in another build of the exe by the signatures of hn_sigs.h.
// Include after <windows.h>, <cstdint>, <cstring> and hn_sigs.h (hn_main.cpp does, inside its namespace; so does
// source/tools/sigcheck.cpp, which runs the same code over an exe file from the command line).
//
// The exe is read from DISK, not from memory: other mods (SessionOpenMP's MinHook) have already overwritten the first
// bytes of some of these functions in the running image by the time this mod starts.
#pragma once

typedef void (*HnSayFn)(const char* fmt, ...);
struct HnSigFound { int hits; uint32_t at[8]; uintptr_t rva; bool ok; };

// file: the whole exe file as it is on disk. Fills found[kSigN]; returns how many signatures resolved.
// Nothing is written to the RVA_* variables here (HnSigApply does that, and only when every one resolved).
inline int HnSigScan(const uint8_t* file, size_t fileSize, HnSigFound* found, HnSayFn say) {
    for (int i = 0; i < kSigN; i++) { found[i].hits = 0; found[i].rva = 0; found[i].ok = false; }
    if (fileSize < 0x1000) { say("signatures: the exe file is too small to be one (%u bytes)", (unsigned)fileSize); return 0; }
    const IMAGE_DOS_HEADER* dos = (const IMAGE_DOS_HEADER*)file;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || (size_t)dos->e_lfanew + sizeof(IMAGE_NT_HEADERS64) > fileSize) { say("signatures: not a PE file"); return 0; }
    const IMAGE_NT_HEADERS64* nt = (const IMAGE_NT_HEADERS64*)(file + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->FileHeader.Machine != IMAGE_FILE_MACHINE_AMD64) { say("signatures: not a 64-bit PE file"); return 0; }
    const IMAGE_SECTION_HEADER* sec = IMAGE_FIRST_SECTION(nt);
    uint32_t tRva = 0, tRaw = 0, tSize = 0;
    for (int s = 0; s < nt->FileHeader.NumberOfSections; s++)
        if (memcmp(sec[s].Name, ".text\0\0\0", 8) == 0) { tRva = sec[s].VirtualAddress; tRaw = sec[s].PointerToRawData; tSize = sec[s].SizeOfRawData < sec[s].Misc.VirtualSize ? sec[s].SizeOfRawData : sec[s].Misc.VirtualSize; }
    if (!tRva || (size_t)tRaw + tSize > fileSize || tSize < 0x10000) { say("signatures: the exe has no usable .text section"); return 0; }
    const uint32_t image = nt->OptionalHeader.SizeOfImage;
    // the signatures by their first byte (always a compared one)
    int head[256], next[kSigN];
    for (int b = 0; b < 256; b++) head[b] = -1;
    for (int i = kSigN - 1; i >= 0; i--) { next[i] = head[kSigs[i].b[0]]; head[kSigs[i].b[0]] = i; }
    const uint8_t* t = file + tRaw;
    for (uint32_t p = 0; p < tSize; p++) {
        for (int i = head[t[p]]; i >= 0; i = next[i]) {
            const HnSig& g = kSigs[i];
            if (p + g.n > tSize) continue;
            const uint8_t* q = t + p; bool same = true;
            for (int j = 1; j < g.n; j++) if (g.m[j] && q[j] != g.b[j]) { same = false; break; }
            if (!same) continue;
            if (found[i].hits < 8) found[i].at[found[i].hits] = tRva + p;      // (ascending: the scan goes up)
            found[i].hits++;
        }
    }
    auto rel32 = [&](uint32_t rva) -> uintptr_t {                             // the target of a rel32 / RIP-relative disp32 that ends at rva + 4
        if (rva < tRva || rva + 4 > tRva + tSize) return 0;
        int32_t d; memcpy(&d, t + (rva - tRva), 4);
        return (uintptr_t)((int64_t)rva + 4 + d);
    };
    // 1: the plain ones (found once) and the ones taken by their place among look-alikes
    for (int i = 0; i < kSigN; i++) {
        const HnSig& g = kSigs[i]; HnSigFound& f = found[i];
        if (g.callee >= 0) continue;
        if (g.rank >= 0) { if (f.hits == g.count && g.count <= 8) { f.rva = f.at[g.rank]; f.ok = true; } }
        else if (f.hits == 1) { f.rva = f.at[0]; f.ok = true; }
        if (f.ok && g.site >= 0) {                                            // a data address: where that instruction points
            const uintptr_t target = rel32((uint32_t)f.rva + g.site + g.dispAt) + (g.insLen - g.dispAt - 4);
            if (target >= 0x1000 && target < image) f.rva = target; else f.ok = false;
        }
    }
    // 2: look-alikes told apart by where one of their calls goes
    for (int i = 0; i < kSigN; i++) {
        const HnSig& g = kSigs[i]; HnSigFound& f = found[i];
        if (g.callee < 0 || !found[g.callee].ok) continue;
        int nRight = 0;
        for (int h = 0; h < f.hits && h < 8; h++)
            if (rel32(f.at[h] + g.callAt) == found[g.callee].rva) { f.rva = f.at[h]; nRight++; }
        f.ok = (nRight == 1 && f.hits <= 8);
    }
    int ok = 0;
    for (int i = 0; i < kSigN; i++) {
        const HnSigFound& f = found[i];
        if (f.ok) ok++;
        say("signatures: %-18s %s exe+%07llx  (%d match%s)", kSigs[i].name, f.ok ? "->" : "NOT FOUND, last candidate", (unsigned long long)(f.ok ? f.rva : (f.hits ? f.at[0] : 0)), f.hits, f.hits == 1 ? "" : "es");
    }
    return ok;
}

// every one resolved: the addresses the rest of the mod uses are these from now on
inline void HnSigApply(const HnSigFound* found) { for (int i = 0; i < kSigN; i++) *kSigs[i].rva = found[i].rva; }

// the exe file of this process (or any file), mapped read-only and scanned
inline int HnSigScanPath(const wchar_t* path, HnSigFound* found, HnSayFn say) {
    HANDLE f = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE) { say("signatures: the exe file could not be opened (error %lu)", GetLastError()); return 0; }
    LARGE_INTEGER sz; sz.QuadPart = 0;
    int n = 0;
    if (GetFileSizeEx(f, &sz) && sz.QuadPart > 0 && sz.QuadPart < 0x40000000ll) {
        HANDLE m = CreateFileMappingW(f, nullptr, PAGE_READONLY, 0, 0, nullptr);
        if (m) {
            const uint8_t* v = (const uint8_t*)MapViewOfFile(m, FILE_MAP_READ, 0, 0, 0);
            if (v) { n = HnSigScan(v, (size_t)sz.QuadPart, found, say); UnmapViewOfFile(v); }
            else say("signatures: the exe file could not be mapped (error %lu)", GetLastError());
            CloseHandle(m);
        } else say("signatures: the exe file could not be mapped (error %lu)", GetLastError());
    } else say("signatures: the exe file's size could not be read");
    CloseHandle(f);
    return n;
}

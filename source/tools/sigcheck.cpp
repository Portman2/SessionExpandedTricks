// sigcheck.cpp -- runs the native half's signature search (hn_sigs.h + hn_sigscan.h, the same code the mod runs on an
// unknown build of the game) over an exe file and prints what it finds.
//   sigcheck <path to SessionGame-Win64-Shipping.exe>
// Exit code 0 = every signature resolved. On the exe the table was made from, every address must equal the table's.
// Build (x64 Native Tools prompt, in source/ExpandedTricksNative): cl /nologo /O2 /EHsc /I. ..\tools\sigcheck.cpp
#include <windows.h>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <cstdarg>

namespace {
#include "hn_sigs.h"
#define HN_DEF(n, r) uintptr_t n = r;
HN_SIG_LIST(HN_DEF)
#undef HN_DEF
#include "hn_sigscan.h"
void Say(const char* fmt, ...) { va_list a; va_start(a, fmt); vprintf(fmt, a); va_end(a); printf("\n"); }
}

int wmain(int argc, wchar_t** argv) {
    if (argc < 2) { printf("usage: sigcheck <exe>\n"); return 2; }
    static HnSigFound found[kSigN];
    const int n = HnSigScanPath(argv[1], found, &Say);
    int same = 0;
    for (int i = 0; i < kSigN; i++) if (found[i].ok && found[i].rva == *kSigs[i].rva) same++;
    int named = 0; for (int i = 0; i < kSigN; i++) if (*kSigs[i].rva) named++;
    printf("\n%d of %d signatures resolved; %d resolve to the address in the table (of the %d that have one)\n", n, kSigN, same, named);
    return n == kSigN ? 0 : 1;
}

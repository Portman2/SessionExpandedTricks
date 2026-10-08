// luareal.cpp -- checks a Lua file with the REAL Lua that will load it: the Lua 5.4 inside UE4SS.dll (its exported
// RC::LuaMadeSimple). `luaL_loadfile` only: the file is compiled, not run.
//   luareal <file.lua> [<result.txt>]
//   luareal -run <test.lua> <result.txt> <main.lua>   runs a test script (global MAIN = the third path) and reports whether it raised an error
// Exit code 0 = it compiles; 1 = syntax error (the message is printed and written to result.txt); 2 = the check
// itself could not run. UE4SS.dll must be beside this exe (copy it there; do NOT run this in a game's folder):
// loading it starts UE4SS's own thread, which finds no Unreal Engine in this process -- so the process is ended
// hard as soon as the answer is on disk.
// Why it exists: build 193's main.lua had "Mods\ExpandedTricks" in a string -- an invalid escape that the mod's own
// syntax checker passed and Lua refused, so the whole Lua half did not load for anyone.
// Build (x64 Native Tools prompt): cl /nologo /O2 /EHsc /MD luareal.cpp <path>\UE4SS.lib
#include <windows.h>
#include <string>
#include <string_view>
#include <cstdio>
#include <exception>

namespace RC { namespace LuaMadeSimple {
class Lua {
public:
    __declspec(dllimport) auto execute_string(std::string_view) const -> void;   // throws on a Lua error
    __declspec(dllimport) auto open_all_libs() const -> void;
};
__declspec(dllimport) auto new_state() -> Lua&;
}}

static std::string LuaQuote(const std::string& s) {              // a Lua long-bracket string: no escapes to get wrong
    return "[==[" + s + "]==]";
}
static void Finish(int code) { fflush(stdout); TerminateProcess(GetCurrentProcess(), (UINT)code); }

int main(int argc, char** argv) {
    if (argc < 2) { printf("usage: luareal <file.lua> [<result.txt>] | luareal -run <test.lua> <result.txt> <main.lua>\n"); return 2; }
    const bool run = strcmp(argv[1], "-run") == 0;
    if (run && argc < 5) { printf("usage: luareal -run <test.lua> <result.txt> <main.lua>\n"); return 2; }
    std::string file = argv[run ? 2 : 1], out = run ? argv[3] : (argc > 2 ? argv[2] : "luareal_result.txt"), mainp = run ? argv[4] : "";
    for (auto& c : mainp) if (c == '\\') c = '/';
    for (auto& c : file) if (c == '\\') c = '/';
    for (auto& c : out) if (c == '\\') c = '/';
    DeleteFileA(out.c_str());
    try {
        const RC::LuaMadeSimple::Lua& lua = RC::LuaMadeSimple::new_state();
        lua.open_all_libs();
        const std::string chunk = run ?
            ("MAIN = " + LuaQuote(mainp) + "\n"
             "local io_open = io.open\n"      // (the test may fence io.open in)
             "local ok, e = pcall(dofile, " + LuaQuote(file) + ")\n"
             "local o = assert(io_open(" + LuaQuote(out) + ", 'w'))\n"
             "o:write(ok and 'SYNTAX OK (the test ran without an error)' or ('SYNTAX ERROR or test failure: ' .. tostring(e)), '\\n', _VERSION, '\\n')\n"
             "o:close()\n") :
            "local f, e = loadfile(" + LuaQuote(file) + ")\n"
            "local o = assert(io.open(" + LuaQuote(out) + ", 'w'))\n"
            "o:write(f and 'SYNTAX OK' or ('SYNTAX ERROR: ' .. tostring(e)), '\\n', _VERSION, '\\n')\n"
            "o:close()\n";
        lua.execute_string(chunk);
    } catch (const std::exception& e) { printf("the check could not run: %s\n", e.what()); Finish(2); }
    catch (...) { printf("the check could not run (unknown exception)\n"); Finish(2); }
    FILE* f = nullptr; char line[2048] = { 0 };
    if (fopen_s(&f, out.c_str(), "r") != 0 || !f) { printf("the check wrote no result\n"); Finish(2); }
    const bool got = fgets(line, sizeof(line), f) != nullptr; char ver[64] = { 0 }; fgets(ver, sizeof(ver), f); fclose(f);
    if (!got) { printf("the check wrote an empty result\n"); Finish(2); }
    printf("%s(%s", line, ver[0] ? ver : "?\n");
    size_t n = strlen(ver); if (n && ver[n - 1] == '\n') {}
    printf(")\n");
    Finish(strncmp(line, "SYNTAX OK", 9) == 0 ? 0 : 1);
    return 2;
}

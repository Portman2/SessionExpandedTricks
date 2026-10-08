@echo off
rem Builds luareal.exe. Run from an "x64 Native Tools Command Prompt for VS", in this folder.
rem The import library for UE4SS.dll is made from the mod's own UE4SS.def.
lib /nologo /def:..\..\ExpandedTricksNative\third_party\ue4ss\UE4SS.def /out:UE4SS.lib /machine:x64
cl /nologo /O2 /EHsc /MD /W3 /std:c++17 luareal.cpp UE4SS.lib /Fe:luareal.exe
echo.
echo Now copy luareal.exe, dryrun.lua, a copy of UE4SS.dll and UE4SS-settings.ini into %%USERPROFILE%%\.expandedtricks\luareal\

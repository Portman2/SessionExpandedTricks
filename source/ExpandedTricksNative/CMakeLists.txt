# ExpandedTricksNative -- the native half of the Expanded Tricks mod for Session: Skate Sim.
# Builds <game>/SessionGame/Binaries/Win64/Mods/ExpandedTricksNative/dlls/main.dll (a UE4SS 3.0.1 C++ mod).
#   cmake -S . -B <build> -G "Visual Studio 17 2022" -A x64
#   cmake --build <build> --config Release
cmake_minimum_required(VERSION 3.20)
project(ExpandedTricksNative CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(ExpandedTricksNative SHARED hn_main.cpp)
# UE4SS is /MD and hands us std:: objects across the boundary (the metadata strings): one CRT, /MD.
set_target_properties(ExpandedTricksNative PROPERTIES OUTPUT_NAME main MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
target_compile_definitions(ExpandedTricksNative PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN _CRT_SECURE_NO_WARNINGS)
target_include_directories(ExpandedTricksNative PRIVATE ${CMAKE_SOURCE_DIR}/third_party)
target_compile_options(ExpandedTricksNative PRIVATE /W3 /O2 /EHsc)
# the import lib generated from the installed UE4SS.dll (see third_party/ue4ss/README.md)
target_link_libraries(ExpandedTricksNative PRIVATE ${CMAKE_SOURCE_DIR}/third_party/ue4ss/UE4SS.lib)

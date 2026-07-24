cmake_minimum_required(VERSION 3.16)
project(parsergen-cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- PCRE2 (from covscript-regex submodule) ---
set(PCRE2_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(PCRE2_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(PCRE2_SUPPORT_JIT ON CACHE BOOL "" FORCE)
set(PCRE2_BUILD_PCRE2_8 ON CACHE BOOL "" FORCE)
set(PCRE2_BUILD_PCRE2_16 OFF CACHE BOOL "" FORCE)
set(PCRE2_BUILD_PCRE2_32 ON CACHE BOOL "" FORCE)
set(PCRE2_BUILD_TESTS OFF CACHE BOOL "" FORCE)

add_subdirectory(covscript-regex/pcre2 EXCLUDE_FROM_ALL)

# --- utfcpp ---
add_library(utfcpp INTERFACE)
target_include_directories(utfcpp INTERFACE utfcpp/source)

# --- libparsergen ---
add_library(parsergen STATIC
    src/lexer.cpp
    src/unicode_lexer.cpp
    src/parser.cpp
    src/generator.cpp
)
target_include_directories(parsergen PUBLIC
    include
    covscript-regex
)
target_link_libraries(parsergen PUBLIC pcre2-8 pcre2-32 utfcpp)

# --- test ---
add_executable(parsergen_test test/main.cpp)
target_link_libraries(parsergen_test parsergen)

add_executable(test_ecs_cpp test/test_ecs_cpp.cpp)
target_link_libraries(test_ecs_cpp parsergen)

# --- CNI layer (optional, requires CovScript SDK) ---
if(DEFINED ENV{CS_DEV_PATH})
    message(STATUS "CovScript SDK detected at $ENV{CS_DEV_PATH}")
    include("$ENV{CS_DEV_PATH}/csbuild.cmake")
    include_directories($ENV{CS_DEV_PATH}/include)
    link_directories($ENV{CS_DEV_PATH}/lib)

    add_library(parsergen_cni SHARED cni/parsergen_cni.cpp)
    target_link_libraries(parsergen_cni parsergen covscript)
    target_link_options(parsergen_cni PRIVATE -Wl,--export-all-symbols)
    set_target_properties(parsergen_cni PROPERTIES
        OUTPUT_NAME parsergen_cxx PREFIX "" SUFFIX ".cse")
endif()

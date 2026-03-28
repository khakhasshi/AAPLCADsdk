cmake_minimum_required(VERSION 3.20)

project(AAPLCADsdk
    VERSION 0.1.0
    DESCRIPTION "Apple-first CAD SDK scaffold"
    LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(AAPLCAD_BUILD_EXAMPLES "Build example targets" ON)
option(AAPLCAD_BUILD_TESTS "Build test targets" ON)
option(AAPLCAD_ENABLE_WARNINGS "Enable strict compiler warnings" ON)

if(AAPLCAD_ENABLE_WARNINGS)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
        add_compile_options(-Wall -Wextra -Wpedantic)
    elseif(MSVC)
        add_compile_options(/W4 /permissive-)
    endif()
endif()

add_library(aaplcad
    src/core/log.cpp
    src/platform/platform.cpp
    src/platform/input_event.cpp
    src/graphics/draw_list_2d.cpp
    src/database/document.cpp)

add_library(aaplcad::aaplcad ALIAS aaplcad)

target_include_directories(aaplcad
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_compile_features(aaplcad PUBLIC cxx_std_17)

target_compile_definitions(aaplcad
    PUBLIC
        AAPLCAD_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
        AAPLCAD_VERSION_MINOR=${PROJECT_VERSION_MINOR}
        AAPLCAD_VERSION_PATCH=${PROJECT_VERSION_PATCH})

if(APPLE)
    target_compile_definitions(aaplcad PUBLIC AAPLCAD_PLATFORM_MACOS=1)
else()
    message(WARNING "AAPLCAD SDK is designed for macOS first; current platform is not Apple.")
endif()

if(AAPLCAD_BUILD_EXAMPLES)
    add_executable(aaplcad_minimal_viewer
        examples/minimal_viewer/main.cpp)
    target_link_libraries(aaplcad_minimal_viewer PRIVATE aaplcad::aaplcad)

    if(APPLE)
        find_library(APPKIT_FRAMEWORK AppKit REQUIRED)
        find_library(METAL_FRAMEWORK Metal REQUIRED)
        find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
        find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)

        add_executable(aaplcad_mac_viewer
            apps/mac_viewer/main.mm)
        target_link_libraries(aaplcad_mac_viewer
            PRIVATE
                aaplcad::aaplcad
                ${APPKIT_FRAMEWORK}
                ${METAL_FRAMEWORK}
                ${METALKIT_FRAMEWORK}
                ${QUARTZCORE_FRAMEWORK})
    endif()
endif()

if(AAPLCAD_BUILD_TESTS)
    enable_testing()
    add_executable(aaplcad_tests
        tests/unit/test_core.cpp)
    target_link_libraries(aaplcad_tests PRIVATE aaplcad::aaplcad)
    add_test(NAME aaplcad_tests COMMAND aaplcad_tests)
endif()

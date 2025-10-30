cmake_minimum_required(VERSION 3.20)

# Project setup
project(CompilerInventory LANGUAGES CXX)

# Require C++23
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
option(RESULTS_IN_SOURCE "Write results to the project root instead of build dir" OFF)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
endif()

if (RESULTS_IN_SOURCE)
    set(RESULTS_DIR "${CMAKE_SOURCE_DIR}/results")
else()
    if(WIN32)
        set(RESULTS_DIR "C:/BENCHMARK_RESULTS")
    else()
        set(RESULTS_DIR "/tmp/benchmark_results")
    endif()
endif()
file(MAKE_DIRECTORY ${RESULTS_DIR})
message(STATUS "Results will be written to: ${RESULTS_DIR}")

add_executable(Project
    src/main.cpp
    "src/benchmark.h" 
    
 "src/singleton.h" "src/benchmark_utils.h")


add_subdirectory(libs)
target_link_libraries(Project PRIVATE Libs) 


# Force C++23 test build
target_compile_features(Project PRIVATE cxx_std_23)

# Define macros
target_compile_definitions(Project
    PRIVATE PROJECT_ROOT_DIR="${CMAKE_SOURCE_DIR}"
            PROJECT_RESULTS_DIR="${RESULTS_DIR}"
)

if (MSVC)
    add_compile_options(@CMAKE_CXX_FLAGS@)
    set(CMAKE_NINJA_FORCE_RESPONSE_FILE ON CACHE INTERNAL "")
endif() 

if (MINGW)
    message(STATUS "Building with fully static linking for MinGW")
    target_link_options(Project PRIVATE -static -static-libgcc -static-libstdc++)
endif()

if (MSVC)
    target_compile_options(Project PRIVATE /O2 /GL /DNDEBUG)
else()
    target_compile_options(Project PRIVATE -O3 -march=native -ffast-math -DNDEBUG)
endif()

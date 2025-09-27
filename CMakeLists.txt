cmake_minimum_required(VERSION 3.20)

# Project setup
project(CompilerInventory LANGUAGES CXX)

# Require C++23
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_executable(Project
    src/main.cpp
)

# Force C++23 test build
target_compile_features(Project PRIVATE cxx_std_23)
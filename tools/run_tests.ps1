Write-Host "=== Building and running with all compilers ==="

# Project root
$src = "$PSScriptRoot"
$buildRoot = Join-Path $src "build"

# Ensure results dir exists
New-Item -ItemType Directory -Force -Path "$src/results" | Out-Null

# --- MSVC ---
Write-Host "`n[1/3] MSVC..."
$vcvars = "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
if (Test-Path $vcvars) {
    cmd /c "`"$vcvars`" x64 && cmake -B build_msvc -S . && cmake --build build_msvc --config Release"
    & "$buildRoot\msvc\bin\Project.exe"
} else {
    Write-Warning "MSVC vcvarsall.bat not found."
}

# --- GCC ---
Write-Host "`n[2/3] GCC..."
$msysPath = "C:\msys64\usr\bin\bash.exe"
if (Test-Path $msysPath) {
    & $msysPath -lc "CC=gcc CXX=g++ cmake -B /c/$(basename $buildRoot)/gcc -S /c/$(basename $src) && cmake --build /c/$(basename $buildRoot)/gcc"
    & "$buildRoot\gcc\bin\Project.exe"
} else {
    Write-Warning "MSYS2 bash not found. GCC skipped."
}

# --- Clang ---
Write-Host "`n[3/3] Clang..."
$env:CC="clang"
$env:CXX="clang++"
cmake -B "$buildRoot/clang" -S .
cmake --build "$buildRoot/clang" --config Release
& "$buildRoot\clang\bin\Project.exe"    

Write-Host "`n=== All builds complete ==="
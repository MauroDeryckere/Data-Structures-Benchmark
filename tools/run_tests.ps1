Write-Host "=== Building and running with all compilers ==="

# Project root (assuming tools/ contains this script, go one up for the real root)
$src       = (Resolve-Path "$PSScriptRoot/..").ToString()
$buildRoot = (Join-Path $PSScriptRoot "build").ToString()

# Ensure results dir exists
New-Item -ItemType Directory -Force -Path "$src/results" | Out-Null

# --- MSVC ---
Write-Host "`n[1/3] MSVC..."
$vcvars = "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
if (Test-Path $vcvars) {
    cmd /c "`"$vcvars`" x64 && cmake -B $buildRoot/msvc -S $src && cmake --build $buildRoot/msvc --config Release"
    $exe = Join-Path $buildRoot "msvc/bin/Release/Project.exe"
    if (Test-Path $exe) { & $exe }
} else {
    Write-Warning "MSVC vcvarsall.bat not found."
}

# --- GCC ---
Write-Host "`n[2/3] GCC..."
$msysPath = "C:\msys64\usr\bin\bash.exe"
if (Test-Path $msysPath) {
    function To-MsysPath($path) {
        $p = $path.ToString()
        $drive = $p.Substring(0,1).ToLower()
        $rest  = $p.Substring(2).Replace("\","/")
        return "/$drive/$rest"
    }

    $msysBuild = To-MsysPath $buildRoot
    $msysSrc   = To-MsysPath $src

    & $msysPath -lc "CC=gcc CXX=g++ cmake -B $msysBuild/gcc -S $msysSrc && cmake --build $msysBuild/gcc --config Release"
    $exe = Join-Path $buildRoot "gcc/bin/Project.exe"
    if (Test-Path $exe) { & $exe }
} else {
    Write-Warning "MSYS2 bash not found. GCC skipped."
}

# --- Clang ---
Write-Host "`n[3/3] Clang..."
$env:CC="clang"
$env:CXX="clang++"
cmake -B "$buildRoot/clang" -S $src
cmake --build "$buildRoot/clang" --config Release
$exe = Join-Path $buildRoot "clang/bin/Release/Project.exe"
if (Test-Path $exe) { & $exe }

Write-Host "`n=== All builds complete ==="
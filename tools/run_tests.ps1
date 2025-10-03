Write-Host "=== Building and running with all compilers ==="

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path $vswhere)) {
    Write-Error "vswhere.exe not found at $vswhere. Please ensure Visual Studio Build Tools are installed."
    exit 1
}

# Find the latest Visual Studio installation with VC++ tools
$vsInstall = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath

if (-not $vsInstall) {
    Write-Error "No Visual Studio installation with VC++ tools found."
    exit 1
}

# Build the full path to vcvarsall.bat
$vcvars = Join-Path $vsInstall "VC\Auxiliary\Build\vcvarsall.bat"

if (-not (Test-Path $vcvars)) {
    Write-Error "vcvarsall.bat not found at $vcvars."
    exit 1
}

Write-Host "Using vcvarsall.bat at $vcvars"

# Run vcvarsall.bat for 64-bit builds and capture the environment
$arch = "x64"
cmd /c "`"$vcvars`" $arch && set" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        Set-Item -Force -Path "Env:$($matches[1])" -Value $matches[2]
    }
}

Write-Host "MSVC environment set up for $arch"


$src       = (Resolve-Path "$PSScriptRoot/..").ToString()
$buildRoot = (Join-Path $PSScriptRoot "build").ToString()

New-Item -ItemType Directory -Force -Path "$src/results" | Out-Null

function Clean-Dir($path) {
    if (Test-Path $path) {
        try {
            Remove-Item -Recurse -Force $path -ErrorAction Stop
        } catch {
            Write-Warning "Could not fully clean $path (maybe exe still running)."
        }
    }
}

function Run-Exe($exePath) {
    if (Test-Path $exePath) {
        Write-Host "Running $exePath"
        & $exePath
    } else {
        Write-Warning "No exe found at $exePath"
    }
}

# --- MSVC ---
Write-Host "`n[1/3] MSVC..."
$msvcBuild = Join-Path $buildRoot "msvc"
$msvcExe   = Join-Path $msvcBuild "bin/Release/Project.exe"
if (Test-Path $vcvars) {
    Clean-Dir $msvcBuild
    cmd /c "`"$vcvars`" x64 && cmake -G `"Visual Studio 17 2022`" -A x64 -B `"$msvcBuild`" -S `"$src`" && cmake --build `"$msvcBuild`" --config Release"
    Run-Exe $msvcExe
} else {
    Write-Warning "MSVC vcvarsall.bat not found."
}

# --- GCC (MSYS2) ---
Write-Host "`n[2/3] GCC (MSYS2)..."
$msysPath = "C:\msys64\usr\bin\bash.exe"
if (Test-Path $msysPath) {
    function To-MsysPath($path) {
        $drive = $path.Substring(0,1).ToLower()
        $rest = $path.Substring(2).Replace("\", "/")
        return "/$drive/$rest"
    }
    $msysBuild = To-MsysPath (Join-Path $buildRoot "gcc")
    $msysSrc   = To-MsysPath $src
    $gccExe = Join-Path $buildRoot "gcc/bin/Project.exe"

    & $msysPath -lc "rm -rf $msysBuild && mkdir -p $msysBuild"
    & $msysPath -lc "export PATH=/mingw64/bin:\$PATH && \
        export CC=/mingw64/bin/gcc && export CXX=/mingw64/bin/g++ && \
        cmake -G 'Ninja' -B $msysBuild -S $msysSrc && \
        cmake --build $msysBuild --config Release"
    Run-Exe $gccExe
} else {
    Write-Warning "MSYS2 bash not found. GCC skipped."
}

# --- Clang ---
Write-Host "`n[3/3] Clang..."
$clangBuild = Join-Path $buildRoot "clang"
$clangExe   = Join-Path $clangBuild "bin/Project.exe"
$clangBin   = Get-ChildItem -Path (Join-Path $PSScriptRoot "compilers/clang-21.1.2") -Recurse -Directory -Filter "bin" | Select-Object -First 1
if ($clangBin) {
    $env:CC  = Join-Path $clangBin.FullName "clang.exe"
    $env:CXX = Join-Path $clangBin.FullName "clang++.exe"

    Clean-Dir $clangBuild
   $clangCmd = "cmake -G `"Ninja`" -B `"$clangBuild`" -S `"$src`" ; cmake --build `"$clangBuild`" --config Release"
    Invoke-Expression $clangCmd

    Run-Exe $clangExe
} else {
    Write-Warning "Clang not found."
}

Write-Host "`n=== All builds complete ==="
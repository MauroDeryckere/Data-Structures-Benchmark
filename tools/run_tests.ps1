Write-Host "=== Building and running with all compilers ==="

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) 
{
    Write-Error "vswhere.exe not found at $vswhere. Please ensure Visual Studio Build Tools are installed."
    exit 1
}

# Setup paths
$src       = (Resolve-Path "$PSScriptRoot/..").ToString()
$buildRoot = (Join-Path $PSScriptRoot "build").ToString()
$compRoot  = (Join-Path $PSScriptRoot "compilers").ToString()

$gccListFile = Join-Path $PSScriptRoot "gcc_versions.txt"

New-Item -ItemType Directory -Force -Path "$src/results" | Out-Null

# ------------------------------
# Helper functions
# ------------------------------
function Clean-Dir($path) 
{
    if (Test-Path $path) 
    {
        try 
        {
            Remove-Item -Recurse -Force $path -ErrorAction Stop
        } catch 
        {
            Write-Warning "Could not fully clean $path (maybe exe still running)."
        }
    }
}

function Run-Exe($exePath) 
{
    if (Test-Path $exePath) 
    {
        Write-Host "Running $exePath"
        & $exePath
    } 
    else 
    {
        Write-Warning "No exe found at $exePath"
    }
}

function To-MsysPath($path) 
{
    $drive = $path.Substring(0,1).ToLower()
    $rest  = $path.Substring(2).Replace("\", "/")
    return "/$drive/$rest"
}
# ------------------------------


# ------------------------------
# MSVC
# ------------------------------
Write-Host "`n[1/3] MSVC..."

if (Test-Path $vswhere) 
{
    # Find the latest Visual Studio installation with VC++ tools
    $vsInstall = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath

    if ($vsInstall) 
    {
        # Build the full path to vcvarsall.bat
        $vcvars = Join-Path $vsInstall "VC\Auxiliary\Build\vcvarsall.bat"

        if (Test-Path $vcvars) 
        {
            Write-Host "Using vcvarsall.bat at $vcvars"

            # Run vcvarsall.bat for 64-bit builds and capture the environment
            $arch = "x64"
            cmd /c "`"$vcvars`" $arch && set" 2>$null | ForEach-Object `
            {
                if ($_ -match "^(.*?)=(.*)$") 
                {
                    Set-Item -Force -Path "Env:$($matches[1])" -Value $matches[2]
                }
            }
            Write-Host "MSVC environment set up for $arch"

            $msvcBuild = Join-Path $buildRoot "msvc"
            $msvcExe   = Join-Path $msvcBuild "bin/Release/Project.exe"
            Clean-Dir $msvcBuild

            cmake -G "Visual Studio 17 2022" -A x64 -B "$msvcBuild" -S "$src"
            cmake --build "$msvcBuild" --config Release

            Run-Exe $msvcExe
        }
        else 
        {
            Write-Warning "vcvarsall.bat not found at $vcvars."
        }
    }
    else 
    {
        Write-Warning "No Visual Studio installation with VC++ tools found."
    }
}
else
{
    Write-Warning "vswhere.exe not found. Skipping MSVC."
}
# ------------------------------



# ------------------------------
# CLang
# ------------------------------
Write-Host "`n[2/3] Clang..."
$clangBuild = Join-Path $buildRoot "clang"
$clangExe   = Join-Path $clangBuild "bin/Project.exe"
$clangBin   = Get-ChildItem -Path (Join-Path $PSScriptRoot "compilers/clang-21.1.2") -Recurse -Directory -Filter "bin" | Select-Object -First 1
if ($clangBin) 
{
    $env:CC  = Join-Path $clangBin.FullName "clang.exe"
    $env:CXX = Join-Path $clangBin.FullName "clang++.exe"

    Clean-Dir $clangBuild
    cmake -G "Ninja" -B "$clangBuild" -S "$src"
    cmake --build "$clangBuild" --config Release

    Run-Exe $clangExe
} 
else 
{
    Write-Warning "Clang not found."
}
# ------------------------------


# ------------------------------
# GCC (MSYS2)
# ------------------------------
Write-Host "`n[3/3] GCC (MSYS2)..."
$msysPath = "C:\msys64\usr\bin\bash.exe"
if (Test-Path $msysPath) 
{
    $msysBuild = To-MsysPath (Join-Path $buildRoot "gcc")
    $msysSrc   = To-MsysPath $src
    $gccExe = Join-Path $buildRoot "gcc/bin/Project.exe"

    & $msysPath -lc "rm -rf $msysBuild && mkdir -p $msysBuild"
    & $msysPath -lc "export PATH=/mingw64/bin:\$PATH && \
        export CC=/mingw64/bin/gcc && export CXX=/mingw64/bin/g++ && \
        cmake -G 'Ninja' -B $msysBuild -S $msysSrc && \
        cmake --build $msysBuild --config Release"
    
    Run-Exe $gccExe

    $gccVersions = Get-Content $gccListFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
        $parts = $_ -split "\|"
        @{
            Ver = $parts[0].Trim()
            Url = $parts[1].Trim()
        }
    }

    foreach ($gcc in $gccVersions) 
    {
        $outDir   = Join-Path $compRoot "gcc-$($gcc.Ver)"
        $gccBin   = Join-Path $outDir "mingw64\bin"
        $gccBuild = Join-Path $buildRoot "gcc-$($gcc.Ver)"
        $gccExe   = Join-Path $gccBuild "bin\Project.exe"

        if (!(Test-Path $gccBin)) 
        {
            Write-Warning "GCC $($gcc.Ver) not found at $gccBin. Skipping..."
            continue
        }

        Write-Host "=== Building with GCC $($gcc.Ver) ==="

        cmake -G "Ninja" -B $gccBuild -S $src `
            -DCMAKE_BUILD_TYPE=Release `
            -DCMAKE_C_COMPILER="$gccBin\gcc.exe" `
            -DCMAKE_CXX_COMPILER="$gccBin\g++.exe"

        cmake --build $gccBuild --config Release

        if (Test-Path $gccExe) 
        {
            Run-Exe $gccExe
        } 
        else 
        {
            Write-Warning "Build for GCC $($gcc.Ver) failed (no exe)."
        }
    }
} 
else
{
    Write-Warning "MSYS2 bash not found. GCC skipped."
}
# ------------------------------

Write-Host "`n=== All builds complete ==="
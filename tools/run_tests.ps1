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
$clangListFile = Join-Path $PSScriptRoot "clang_versions.txt"
$msvcListFile = Join-Path $PSScriptRoot "msvc_versions.txt"

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
    $generatorMap = @{
        "2022" = "Visual Studio 17 2022"
        "2019" = "Visual Studio 16 2019"
        "2017" = "Visual Studio 15 2017"
    }

    $msvcVersions = Get-Content $msvcListFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
        $parts = $_ -split "\|"
        @{
            Year       = $parts[0].Trim()
            PackageId  = $parts[1].Trim()
            Components = $parts[2].Trim()
            ToolsetVer = $parts[3].Trim()
            Generator  = $generatorMap[$parts[0].Trim()]
        }
    }

    foreach ($msvc in $msvcVersions) 
    {
        Write-Host "=== Building with MSVC $($msvc.Year) ==="

        # Find all installs for that year
        $vsInstalls = & $vswhere -all -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath | Where-Object { $_ -like "*$($msvc.Year)*" }

        if (-not $vsInstalls) {
            Write-Warning "No Visual Studio $($msvc.Year) installation found."
            continue
        }

        foreach ($vsInstall in $vsInstalls) {
            $toolsRoot = Join-Path $vsInstall "VC\Tools\MSVC"

            if (-not (Test-Path $toolsRoot)) {
                continue
            }

            # If "latest", pick the highest subfolder
            if ($msvc.ToolsetVer -eq "latest") {
                $selectedVer = Get-ChildItem $toolsRoot | Sort-Object Name -Descending | Select-Object -First 1
            } else {
                $selectedVer = Get-ChildItem $toolsRoot | Where-Object { $_.Name -eq $msvc.ToolsetVer }
            }

            if (-not $selectedVer) {
                Write-Warning "Toolset $($msvc.ToolsetVer) not found under $toolsRoot"
                continue
            }

            Write-Host "Using VC toolset: $($selectedVer.Name)"

            # Setup environment via vcvarsall
            $vcvars = Join-Path $vsInstall "VC\Auxiliary\Build\vcvarsall.bat"
            $arch = "x64"

            cmd /c "`"$vcvars`" $arch -vcvars_ver=$($selectedVer.Name) && set" 2>$null | ForEach-Object {
                if ($_ -match "^(.*?)=(.*)$") {
                    Set-Item -Force -Path "Env:$($matches[1])" -Value $matches[2]
                }
            }

            Write-Host "Environment ready for MSVC $($msvc.Year) $($selectedVer.Name)"

            # Build dir
            $msvcBuild = Join-Path $buildRoot "msvc-$($msvc.Year)-$($selectedVer.Name)"
            $msvcExe   = Join-Path $msvcBuild "bin/Release/Project.exe"
            Clean-Dir $msvcBuild

            cmake -G "$($msvc.Generator)" -A $arch -B "$msvcBuild" -S "$src"
            cmake --build "$msvcBuild" --config Release

            Run-Exe $msvcExe
        }
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

$clangVersions = Get-Content $clangListFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $parts = $_ -split "\|"
    @{
        Ver = $parts[0].Trim()
        Url = $parts[1].Trim()
    }
}

foreach ($clang in $clangVersions) 
{
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
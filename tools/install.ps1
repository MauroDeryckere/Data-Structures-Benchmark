Write-Host "=== Installing compilers and build tools ==="

$root = "$PSScriptRoot/compilers" 

$gccListFile = Join-Path $PSScriptRoot "gcc_versions.txt"
$clangListFile = Join-Path $PSScriptRoot "clang_versions.txt"

New-Item -ItemType Directory -Force -Path $root | Out-Null

# ------------------------------
# Helper functions
# ------------------------------
function Download-File($url, $dest) 
{
    Write-Host "Downloading: $url"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    & curl.exe -L --retry 3 --retry-delay 5 --ssl-no-revoke -o $dest $url
   
    if (!(Test-Path $dest)) 
    { 
        throw "Failed to download $url"
    }
}

function Extract-ArchiveSafe($file, $dest) 
{
    if ($file -match "\.7z$") 
    {
        & "C:\Program Files\7-Zip\7z.exe" x $file "-o$dest" -y | Out-Null
    }
    elseif ($file -match "\.xz$" -or $file -match "\.tar$") 
    {
        & "C:\Program Files\7-Zip\7z.exe" x $file "-o$dest" -y | Out-Null
    }
    else 
    {
        Expand-Archive -Path $file -DestinationPath $dest -Force
    }
}

# ------------------------------

# ------------------------------
# MSVC
# ------------------------------
Write-Host "`n[1/3] Checking for Visual Studio 2022 (MSVC)..."

$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"

if (Test-Path $vswhere) 
{
    $vsInfo = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath -version "[17.0,18.0)" 2>$null

    if ($vsInfo) 
    {
        $vcvarsPath = Join-Path $vsInfo "VC\Auxiliary\Build\vcvarsall.bat"
        if (Test-Path $vcvarsPath) 
        {
            Write-Host "Visual Studio 2022 detected at: $vsInfo"
            Write-Host "VCVars path: $vcvarsPath"
        }
        else
        {
            Write-Warning "Visual Studio 2022 found, but vcvarsall.bat missing."
        }
    }
    else 
    {
        Write-Warning "Visual Studio 2022 not found. You can install it via:"
        Write-Host " winget install Microsoft.VisualStudio.2022.Community --silent --accept-package-agreements --accept-source-agreements"
    }
}
else 
{
    Write-Warning "vswhere.exe not found! Visual Studio Installer may not be installed."
}
# ------------------------------


# ------------------------------
# GCC
# ------------------------------
$msysPath = "C:\msys64\usr\bin\bash.exe"

# MSYS2 GCC
Write-Host "`n[2/3] Installing MSYS2 (for GCC)..."

winget install MSYS2.MSYS2 --silent --accept-package-agreements --accept-source-agreements

if (Test-Path $msysPath) 
{ 
    & $msysPath -lc "pacman -Syu --noconfirm"
    & $msysPath -lc "pacman -S --noconfirm --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-binutils"
    Write-Host "GCC installed via MSYS2."
}

# WinLibs GCC (portable zip)
$gccVersions = Get-Content $gccListFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $parts = $_ -split "\|"
    @{
        Ver = $parts[0].Trim()
        Url = $parts[1].Trim()
    }
}

foreach ($gcc in $gccVersions)
{
    $outDir = Join-Path $root "gcc-$($gcc.Ver)"
    if (!(Test-Path $outDir)) 
    {
        $zipFile = "$outDir\gcc.zip"
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        Download-File $gcc.Url $zipFile
        Extract-ArchiveSafe $zipFile $outDir
        Remove-Item $zipFile
        Write-Host "GCC $($gcc.Ver) installed at $outDir"
    }
}
# ------------------------------


# ------------------------------
# Clang
# ------------------------------
Write-Host "`n[3/3] Installing Clang/LLVM..."

$clangVersions = Get-Content $clangListFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $parts = $_ -split "\|"
    @{
        Ver = $parts[0].Trim()
        Url = $parts[1].Trim()
    }
}

foreach ($clang in $clangVersions) 
{
    $outDir = Join-Path $root "clang-$($clang.Ver)"
    if (Test-Path $outDir) 
    {
        Write-Host "Clang/LLVM $($clang.Ver) already installed at $outDir"
        continue
    }

    New-Item -ItemType Directory -Path $outDir | Out-Null

    $tarUrl = "$($clang.Url)/clang+llvm-$($clang.Ver)-x86_64-pc-windows-msvc.tar.xz"
    $downloadFile = Join-Path $outDir "clang.tar.xz"

    try 
    {
        Write-Host "Downloading Clang $($clang.Ver) from $tarUrl..."
        Download-File $tarUrl $downloadFile

        Write-Host "Extracting Clang $($clang.Ver)..."
        Extract-ArchiveSafe $downloadFile $outDir

        # If a .tar was created inside, extract that too
        $tarFile = Get-ChildItem $outDir -Filter *.tar | Select-Object -First 1
        if ($tarFile) 
        {
            Extract-ArchiveSafe $tarFile.FullName $outDir
            Remove-Item $tarFile.FullName -Force
        }

        Remove-Item $downloadFile -Force
        Write-Host "Clang $($clang.Ver) installed at $outDir"
    }
    catch 
    {
        Write-Warning "Failed to install Clang $($clang.Ver): $_"
    }
}
# ------------------------------


# ------------------------------
# Build Tools
# ------------------------------
Write-Host "`n[Extra] Installing CMake..."
winget install Kitware.CMake --silent --accept-package-agreements --accept-source-agreements
winget install Ninja-build.Ninja --silent --accept-package-agreements --accept-source-agreements

if (Test-Path $msysPath) 
{ 
    Write-Host "Installing CMake inside MSYS2..."
    & $msysPath -lc "pacman -S --noconfirm --needed mingw-w64-x86_64-cmake"
}
if (Test-Path $msysPath) 
{ 
    Write-Host "Installing Ninja inside MSYS2..."
    & $msysPath -lc "pacman -S --noconfirm --needed mingw-w64-x86_64-ninja"
}
# ------------------------------


# ------------------------------
# Summary
# ------------------------------
Write-Host "`n=== Setup Complete ==="
Write-Host "MSVC:    available via vcvarsall.bat"
Write-Host "GCC:     installed via MSYS2 and/or WinLibs"
Write-Host "Clang:   installed at $root"
Write-Host "CMake & Ninja installed system-wide"
# ------------------------------

Write-Host "=== Installing compilers and build tools ==="

$root = "$PSScriptRoot/compilers" 
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
Write-Host "`n[1/3] Installing MSVC Build Tools..."
winget install --id Microsoft.VisualStudio.2022.BuildTools `
    --silent --accept-package-agreements --accept-source-agreements `
    --override "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
Write-Host "MSVC installed. Use vcvarsall.bat or Developer Command Prompt."
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
$gccVersions = @(
    @{ Ver = "13.2.0"; Url = "https://sourceforge.net/projects/winlibs-mingw/files/13.2.0posix-18.1.1-11.0.1-msvcrt-r6/winlibs-x86_64-posix-seh-gcc-13.2.0-mingw-w64msvcrt-11.0.1-r6.zip/download" },
    @{ Ver = "14.2.0"; Url = "https://sourceforge.net/projects/winlibs-mingw/files/14.2.0mcf-12.0.0-ucrt-r1/winlibs-x86_64-mcf-seh-gcc-14.2.0-mingw-w64ucrt-12.0.0-r1.zip/download" }
)

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

$clangVersions = @(
    @{ Ver = "21.1.2"; BaseUrl = "https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.2" }
    # @{ Ver = "20.1.0"; BaseUrl = "https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.0" }
)

foreach ($clang in $clangVersions) 
{
    $outDir = Join-Path $root "clang-$($clang.Ver)"
    if (Test-Path $outDir) 
    {
        Write-Host "Clang/LLVM $($clang.Ver) already installed at $outDir"
        continue
    }

    New-Item -ItemType Directory -Path $outDir | Out-Null

    $tarUrl = "$($clang.BaseUrl)/clang+llvm-$($clang.Ver)-x86_64-pc-windows-msvc.tar.xz"
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

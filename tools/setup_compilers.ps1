Write-Host "=== Installing all compilers: MSVC, GCC (MSYS2), Clang ==="

$root = "$PSScriptRoot/compilers" 
New-Item -ItemType Directory -Force -Path $root | Out-Null

# --- MSVC ---
Write-Host "`n[1/3] Installing MSVC Build Tools..."
winget install --id Microsoft.VisualStudio.2022.BuildTools `
    --silent --accept-package-agreements --accept-source-agreements `
    --override "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
Write-Host "MSVC installed (default location: C:\Program Files\Microsoft Visual Studio)." 
Write-Host "Use 'Developer Command Prompt' or run vcvarsall.bat before CMake."

# --- GCC via MSYS2 ---
# Define where MSYS2 should go
$msysPath = "C:\msys64\usr\bin\bash.exe"
Write-Host "`n[2/3] Installing MSYS2 (for GCC)..."

winget install `
    --id MSYS2.MSYS2 `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements `
Write-Host "MSYS2 installed at C:\msys64."

Write-Host "Installing MinGW-w64 GCC inside MSYS2..." 
if (Test-Path $msysPath) { 
    & $msysPath -lc "pacman -S --noconfirm --needed mingw-w64-x86_64-gcc" 
    Write-Host "GCC installed in MSYS2." 
} else { 
    Write-Warning "MSYS2 not found at $msysPath. You may need to restart and rerun GCC setup." 
}

# --- GCC (WinLibs builds) ---
Write-Host "`n[2/3] Installing GCC (versions 12, 13, 14)..."
$gccVersions = @(
    @{ Ver = "13.2.0"; Url = "https://sourceforge.net/projects/winlibs-mingw/files/13.2.0posix-18.1.1-11.0.1-msvcrt-r6/winlibs-x86_64-posix-seh-gcc-13.2.0-mingw-w64msvcrt-11.0.1-r6.zip/download" },
    @{ Ver = "14.2.0"; Url = "https://sourceforge.net/projects/winlibs-mingw/files/14.2.0mcf-12.0.0-ucrt-r1/winlibs-x86_64-mcf-seh-gcc-14.2.0-mingw-w64ucrt-12.0.0-r1.zip/download" }
)

foreach ($gcc in $gccVersions) {
    $outDir = Join-Path $root "gcc-$($gcc.Ver)"
    if (Test-Path $outDir) {
        Write-Host "GCC $($gcc.Ver) already installed at $outDir"
        continue
    }

    New-Item -ItemType Directory -Path $outDir | Out-Null

    $zipFile = Join-Path $outDir "gcc.zip"
    Write-Host "Downloading GCC $($gcc.Ver) from $($gcc.Url)..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $curl = "curl.exe"
        & $curl -L --retry 3 --retry-delay 5 --ssl-no-revoke -o $zipFile $gcc.Url
        Write-Host "Downloaded to $zipFile"
    }
    catch {
        Write-Warning "Could not download GCC $($gcc.Ver) — skipping. URL: $($gcc.Url)"
        continue
}

    if (Test-Path $zipFile) {
        $size = (Get-Item $zipFile).Length
        Write-Host "Downloaded file size: $size bytes"
        if ($size -lt 10MB) {
            Write-Warning "Download seems too small — likely not a valid archive. Skipping."
            continue
        }
        # Detect archive type

        Write-Host "Extracting GCC $($gcc.Ver)..."
        try {
            if ($zipFile -match "\.7z$") {
                Write-Host "Extracting with 7-Zip..."
                & 7z x $zipFile "-o$outDir" -y | Out-Null
            }
            else {
                Write-Host "Extracting ZIP..."
                Expand-Archive -Path $zipFile -DestinationPath $outDir -Force
            }
            Write-Host "Extracted in $outDir"
        }
        catch {
            Write-Warning "Failed to extract $zipFile"
        }
        Remove-Item $zipFile -ErrorAction SilentlyContinue
    }
    else {
        Write-Warning "Zip file $zipFile not found after download"
    }
}



Write-Host "`n[3/3] Installing Clang / LLVM builds..."
$clangVersions = @(
    @{ Ver = "21.1.2"; BaseUrl = "https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.2" }
)

foreach ($clang in $clangVersions) {
    $outDir = Join-Path $root "clang-$($clang.Ver)"
    if (Test-Path $outDir) {
        Write-Host "Clang/LLVM $($clang.Ver) already installed at $outDir"
        continue
    }

    New-Item -ItemType Directory -Path $outDir | Out-Null

    # Use tarball for portable install
    $tarUrl = "$($clang.BaseUrl)/clang+llvm-$($clang.Ver)-x86_64-pc-windows-msvc.tar.xz"
    $downloadFile = Join-Path $outDir "clang.tar.xz"

    try {
        Write-Host "Downloading Clang $($clang.Ver) from $tarUrl..."
        & curl.exe -L --ssl-no-revoke $tarUrl -o $downloadFile

        if (!(Test-Path $downloadFile)) {
            throw "Download failed."
        }

        Write-Host "Extracting tarball with 7-Zip..."
        # Path to 7-Zip
        $sevenZip = "C:\Program Files\7-Zip\7z.exe"
        if (!(Test-Path $sevenZip)) {
            $sevenZip = "C:\Program Files (x86)\7-Zip\7z.exe"
        }

        if (!(Test-Path $sevenZip)) {
            throw "7-Zip not found. Please install 7-Zip and update the path."
        }

        # Step 1: extract .xz -> .tar
        & $sevenZip x $downloadFile "-o$outDir" -y | Out-Null
        $tarFile = Get-ChildItem $outDir -Filter *.tar | Select-Object -First 1

        if ($tarFile) {
            # Step 2: extract .tar -> actual files
            & $sevenZip x $tarFile.FullName "-o$outDir" -y | Out-Null
            Remove-Item $tarFile.FullName -Force
        }           

        Remove-Item $downloadFile -Force
        Write-Host "Extracted Clang $($clang.Ver) to $outDir"
    }
    catch {
        Write-Warning "Failed to install Clang $($clang.Ver): $_"
    }
}

# --- Summary ---
Write-Host "`n=== Compiler setup complete ==="
Write-Host "MSVC: available via vcvarsall.bat or Developer Command Prompt"
Write-Host "GCC: available inside MSYS2 (use mingw64 shell or add to PATH)"
Write-Host "Clang: available system-wide after install"

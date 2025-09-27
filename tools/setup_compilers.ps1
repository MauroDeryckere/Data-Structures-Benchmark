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

# --- Clang / LLVM versions ---
Write-Host "`n[3/3] Installing Clang / LLVM builds..."
$clangVersions = @(
   @{ Ver = "21.1.2"; Url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.2/clang+llvm-21.1.2-x86_64-pc-windows-msvc.tar.xz" }
)

foreach ($clang in $clangVersions) {
    $outDir = Join-Path $root "clang-$($clang.Ver)"
    if (Test-Path $outDir) {
        Write-Host "Clang/LLVM $($clang.Ver) already installed at $outDir"
        continue
    }

    New-Item -ItemType Directory -Path $outDir | Out-Null
    $fileName = Split-Path $clang.Url -Leaf
    $archiveFile = Join-Path $outDir $fileName

    Write-Host "Downloading Clang $($clang.Ver) from $($clang.Url)..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $clang.Url -OutFile $archiveFile -UseBasicParsing -MaximumRedirection 5 -ErrorAction Stop
        Write-Host "Downloaded to $archiveFile"
    }
    catch {
        Write-Warning "Could not download Clang $($clang.Ver). Skipping. URL: $($clang.Url)"        continue
    }

    if (Test-Path archiveFile) {
        $size = (Get-Item archiveFile).Length
        Write-Host "Downloaded size: $size bytes"
        if ($size -lt 20MB) {
            Write-Warning "Download too small—likely not full archive. Skipping."
            continue
        }

        Write-Host "Extracting Clang $($clang.Ver)..."
    try{
        if ($archiveFile -like "*.zip") {
            Expand-Archive -Path $archiveFile -DestinationPath $outDir -Force
        }
        elseif ($archiveFile -like "*.tar.xz") {
            # First unpack the .xz into .tar
            & 7z x $archiveFile -o"$outDir" | Out-Null
            $tarFile = Get-ChildItem $outDir -Filter "*.tar" | Select-Object -First 1
            if ($tarFile) {
                & 7z x $tarFile.FullName -o"$outDir" | Out-Null
                Remove-Item $tarFile.FullName -ErrorAction SilentlyContinue
            }
        }
        else {
            Write-Warning "Unknown archive format: $archiveFile"
        }
    }
    catch {
        Write-Warning "Failed to extract $zipFile"
    }
        Remove-Item archiveFile -ErrorAction SilentlyContinue
    }
    else {
Write-Warning "Archive file $archiveFile not found after download"    }
}

# --- Summary ---
Write-Host "`n=== Compiler setup complete ==="
Write-Host "MSVC: available via vcvarsall.bat or Developer Command Prompt"
Write-Host "GCC: available inside MSYS2 (use mingw64 shell or add to PATH)"
Write-Host "Clang: available system-wide after install"

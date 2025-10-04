Write-Host "=== Installing compilers and build tools ==="

# Ensure script is running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Restarting script with elevated permissions..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

$root = "$PSScriptRoot/compilers" 

$gccListFile = Join-Path $PSScriptRoot "gcc_versions.txt"
$clangListFile = Join-Path $PSScriptRoot "clang_versions.txt"
$msvcListFile = Join-Path $PSScriptRoot "msvc_versions.txt"

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

$msvcVersions = Get-Content $msvcListFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $parts = $_ -split "\|"
    @{
        Year = $parts[0].Trim()
        PackageId = $parts[1].Trim()
        Components = $parts[2..($parts.Length - 1)] -join " "
        ToolsetVer = if ($parts.Length -ge 4) { $parts[3].Trim() } else { "latest" }
    }
}

# Ensure VS Installer is available (needed for specific toolset versions)
$vsInstaller = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
if (-not (Test-Path $vsInstaller)) 
{
    Write-Host "Downloading Visual Studio Installer..."
    Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_installer.exe" -OutFile "vs_installer.exe"
    Start-Process -FilePath ".\vs_installer.exe" -ArgumentList "--quiet --wait" -Wait
    $vsInstaller = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
}

foreach ($msvc in $msvcVersions) 
{
    Write-Host "`nInstalling MSVC $($msvc.Year) Build Tools (Toolset: $($msvc.ToolsetVer))..."
   
    try 
    {
        if ($msvc.ToolsetVer -eq "latest") 
        {
            # Install base Build Tools + latest VC toolset via winget
            winget install --id $msvc.PackageId `
                --silent --accept-package-agreements --accept-source-agreements `
                --override "--add $($msvc.Components)"
        }
        else 
        {
            # Dynamically generate a .vsconfig for the requested toolset version
            $configDir = "$PSScriptRoot\configs"
            if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir | Out-Null }
            $vsconfigPath = Join-Path $configDir "msvc-$($msvc.Year)-$($msvc.ToolsetVer).vsconfig"

            $vsconfig = @{
                version = "1.0"
                components = @(
                    @{
                        id = "Microsoft.VisualStudio.Workload.VCTools"
                    },
                    @{
                        id = "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
                        version = $msvc.ToolsetVer
                    }
                )
            }

            $vsconfig | ConvertTo-Json -Depth 4 | Set-Content -Path $vsconfigPath -Encoding UTF8
            Write-Host "Generated $vsconfigPath for MSVC toolset $($msvc.ToolsetVer)"

            # Map VS year -> correct product/channel
            switch ($msvc.Year) {
                "2022" {
                    $productId = "Microsoft.VisualStudio.Product.BuildTools"
                    $channelId = "VisualStudio.17.Release"
                }
                "2019" {
                    $productId = "Microsoft.VisualStudio.Product.BuildTools"
                    $channelId = "VisualStudio.16.Release"
                }
                default {
                    throw "Unsupported Visual Studio year: $($msvc.Year)"
                }
            }

            # Run installer with product + channel + config
            $args = @(
                "install",
                "--quiet", "--norestart",
                "--productId", $productId,
                "--channelId", $channelId,
                "--config", "`"$vsconfigPath`""
            )
            Start-Process -FilePath $vsInstaller -ArgumentList $args -Wait -NoNewWindow
        }
    }
    catch 
    {
        Write-Warning "Failed to install MSVC $($msvc.Year): $_"
    }
}

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

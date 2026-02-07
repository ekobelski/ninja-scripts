<#
.SYNOPSIS
    Ensures winget is installed and updates machine-level applications when run as SYSTEM.
.DESCRIPTION
    This script is intended to run as SYSTEM. It checks for the presence of winget, installs it if it is missing, and then updates applications installed at the machine level
#>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Log([string]$m) {
    # Write-Host avoids contaminating pipeline output captured into variables
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "s"), $m)
}

function Get-Arch {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { "x64" }
        "ARM64" { "arm64" }
        default { throw "Unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
    }
}

function Get-WingetExe {
    $pattern = Join-Path $env:ProgramFiles "WindowsApps\Microsoft.DesktopAppInstaller*_8wekyb3d8bbwe\winget.exe"
    $item = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($item) { return $item.FullName }

    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    return $null
}

function Download($uri, $out) {
    Log "Downloading: $uri"
    Invoke-WebRequest -Uri $uri -OutFile $out -UseBasicParsing
}

function Install-Appx($path) {
    try {
        Log "Provisioning package: $path"
        Add-AppxProvisionedPackage -Online -PackagePath $path -SkipLicense | Out-Null
    }
    catch {
        Log "Provisioning failed, trying Add-AppxPackage. Error: $($_.Exception.Message)"
        Add-AppxPackage -Path $path | Out-Null
    }
}

function Confirm-WingetInstalled {
    $existing = Get-WingetExe
    if ($existing) {
        Log "winget present: $existing"
        return $existing
    }

    $arch = Get-Arch
    $tmp = Join-Path $env:TEMP ("winget-bootstrap-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Log "Bootstrap dir: $tmp"

    $vclibsUri = "https://aka.ms/Microsoft.VCLibs.$arch.14.00.Desktop.appx"
    $vclibsPath = Join-Path $tmp "Microsoft.VCLibs.$arch.14.00.Desktop.appx"
    Download $vclibsUri $vclibsPath
    Install-Appx $vclibsPath

    $xamlIndex = "https://api.nuget.org/v3-flatcontainer/microsoft.ui.xaml/index.json"
    Log "Querying NuGet: $xamlIndex"
    $indexJson = Invoke-RestMethod -Uri $xamlIndex -UseBasicParsing
    $latest = ($indexJson.versions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1)
    if (-not $latest) { throw "Could not determine Microsoft.UI.Xaml version." }

    $nupkgUri = "https://api.nuget.org/v3-flatcontainer/microsoft.ui.xaml/$latest/microsoft.ui.xaml.$latest.nupkg"
    $nupkgPath = Join-Path $tmp "microsoft.ui.xaml.$latest.nupkg"
    Download $nupkgUri $nupkgPath

    $zipPath = Join-Path $tmp "microsoft.ui.xaml.$latest.zip"
    Copy-Item $nupkgPath $zipPath -Force
    $xamlDir = Join-Path $tmp "xaml"
    Expand-Archive -Path $zipPath -DestinationPath $xamlDir -Force

    $xamlAppx = Join-Path $xamlDir ("tools\AppX\{0}\release\Microsoft.UI.Xaml.2.8.appx" -f $arch)
    if (-not (Test-Path $xamlAppx)) {
        $found = Get-ChildItem -Path $xamlDir -Recurse -Filter "Microsoft.UI.Xaml.2.8.appx" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $xamlAppx = $found.FullName }
    }
    if (-not (Test-Path $xamlAppx)) { throw "Microsoft.UI.Xaml.2.8.appx not found after extract." }
    Install-Appx $xamlAppx

    $aiUri = "https://aka.ms/getwinget"
    $aiPath = Join-Path $tmp "Microsoft.DesktopAppInstaller.msixbundle"
    Download $aiUri $aiPath
    Install-Appx $aiPath

    Start-Sleep -Seconds 3

    $wg = Get-WingetExe
    if (-not $wg) { throw "winget still not found after App Installer install." }
    Log "winget installed: $wg"
    return $wg
}

$wg = Confirm-WingetInstalled

Log "Machine-scope upgrades (source=winget) starting..."
& $wg upgrade --all --include-unknown --scope machine --source winget --accept-source-agreements --accept-package-agreements --silent
Log "Machine-scope upgrades complete."

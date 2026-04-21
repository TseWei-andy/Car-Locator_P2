# PowerShell Script to Install Flutter (Direct Download)

$ErrorActionPreference = "Stop"
$WorkDir = "D:\"
$ZipPath = Join-Path $WorkDir "flutter.zip"
$InstallPath = Join-Path $WorkDir "flutter"

Write-Host "Checking for existing Flutter installation..."
if (Test-Path "$InstallPath\bin\flutter.bat") {
    Write-Host "Flutter is already installed at $InstallPath"
} else {
    Write-Host "Fetching latest stable release info..."
    try {
        $json = Invoke-RestMethod -Uri "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
        $stableHash = $json.current_release.stable
        $stableRelease = $json.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1
        
        if (-not $stableRelease) {
            throw "Could not find stable release info."
        }

        $downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/" + $stableRelease.archive
        Write-Host "Latest stable version: $($stableRelease.version)"
        Write-Host "Downloading from: $downloadUrl"

        Invoke-WebRequest -Uri $downloadUrl -OutFile $ZipPath -UseBasicParsing
        
        Write-Host "Extracting to $WorkDir..."
        Expand-Archive -Path $ZipPath -DestinationPath $WorkDir -Force
        
        Write-Host "Cleaning up zip file..."
        Remove-Item $ZipPath -Force
        
        Write-Host "Flutter installed successfully at $InstallPath"
    } catch {
        Write-Error "Failed to install Flutter: $_"
        exit 1
    }
}

# Add to PATH for current session
$FlutterBin = "$InstallPath\bin"
$env:PATH += ";$FlutterBin"
Write-Host "Added $FlutterBin to PATH environment variable."

# Verify
Write-Host "Verifying installation..."
flutter --version

Write-Host "---------------------------------------------------"
Write-Host "IMPORTANT: Please run the following command in your terminal to persist the PATH:"
Write-Host "[System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable('Path', 'User') + ';$FlutterBin', 'User')"
Write-Host "---------------------------------------------------"

# Fast Flutter Installer using Curl (SSL Fix)

$WorkDir = "D:\"
$ZipPath = "D:\flutter.zip"
$InstallPath = "D:\flutter"

Write-Host "Fetching latest stable release info..."
try {
    $json = Invoke-RestMethod -Uri "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
    $stableHash = $json.current_release.stable
    $stableRelease = $json.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1
    $Url = "https://storage.googleapis.com/flutter_infra_release/releases/" + $stableRelease.archive
    Write-Host "Latest version: $($stableRelease.version)"
} catch {
    $Url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip"
}

if (-not (Test-Path $InstallPath)) {
    Write-Host "Downloading with curl (SSL revoke check disabled)..."
    # Added --ssl-no-revoke
    $process = Start-Process -FilePath "curl.exe" -ArgumentList "-L", "--ssl-no-revoke", "-o", "$ZipPath", "-C", "-", "$Url" -PassThru -Wait -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-Error "Download failed with exit code $($process.ExitCode)"
        exit 1
    }

    Write-Host "Extracting..."
    Expand-Archive -Path $ZipPath -DestinationPath $WorkDir -Force
    Remove-Item $ZipPath -Force
}

Write-Host "Flutter is at: $InstallPath"

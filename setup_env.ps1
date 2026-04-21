# Automatic Environment Setup Script

Write-Host "Setting up environment..."

# 1. Install Scoop (if not exists)
if (-not (Test-Path "$env:USERPROFILE\scoop")) {
    Write-Host "Installing Scoop package manager..."
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    iwr -useb get.scoop.sh | iex
} else {
    Write-Host "Scoop is already installed."
}

# Add Scoop to current session path
$env:PATH += ";$env:USERPROFILE\scoop\shims"

# 2. Install Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git..."
    scoop install git
} else {
    Write-Host "Git is already installed."
}

# 3. Install Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Flutter..."
    scoop bucket add extras
    scoop install flutter
    
    Write-Host "Flutter installed. Running doctor..."
    flutter doctor
} else {
    Write-Host "Flutter is already installed."
}

Write-Host "----------------------------------------------------------------"
Write-Host "Setup complete!"
Write-Host "IMPORTANT: Please RESTART your IDE or Terminal to apply changes."
Write-Host "After restart, run 'flutter create .' to finish project setup."
Write-Host "----------------------------------------------------------------"

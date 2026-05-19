# BuildAndPackage.ps1
# Automates compiling the Spring Boot backend, the desktop app, and packaging them into a standalone Windows .exe installer with a bundled Java 21 JRE.

$ErrorActionPreference = "Stop"

# 1. Locate JDK 21
$JdkPath = "C:\Users\operaciones5\.jdks\dragonwell-21.0.10"
if (-not (Test-Path $JdkPath)) {
    Write-Host "Searching for system JDK 21..." -ForegroundColor Yellow
    if ($env:JAVA_HOME) {
        $JdkPath = $env:JAVA_HOME
    } else {
        $whereJava = where.exe java
        if ($whereJava) {
            $javaExe = $whereJava[0]
            $JdkPath = Split-Path (Split-Path $javaExe -Parent) -Parent
        } else {
            Write-Error "Could not find a valid JDK 21 installation. Please install JDK 21 or set JAVA_HOME."
        }
    }
}

Write-Host "Using JDK Path: $JdkPath" -ForegroundColor Green
$env:JAVA_HOME = $JdkPath
$env:Path = "$JdkPath\bin;" + $env:Path

$ProjectRoot = Get-Location

# 2. Compile Spring Boot Backend
Write-Host "`n=== Compiling Spring Boot Backend ===" -ForegroundColor Cyan
Set-Location "$ProjectRoot\backend"
& .\mvnw.cmd clean package -DskipTests

# 3. Compile Desktop App
Write-Host "`n=== Compiling Desktop App ===" -ForegroundColor Cyan
Set-Location "$ProjectRoot\desktop"
& .\mvnw.cmd clean package -DskipTests

# 4. Prepare Distribution Directory
Write-Host "`n=== Preparing Packaging Files ===" -ForegroundColor Cyan
Set-Location $ProjectRoot
$DistDir = "$ProjectRoot\dist"
if (Test-Path $DistDir) {
    Remove-Item -Recurse -Force $DistDir
}
New-Item -ItemType Directory -Path $DistDir | Out-Null
New-Item -ItemType Directory -Path "$DistDir\icons" | Out-Null

# Copy Jars and Icons
Copy-Item "$ProjectRoot\backend\target\app.jar" "$DistDir\app.jar"
Copy-Item "$ProjectRoot\desktop\target\desktop-1.0-SNAPSHOT.jar" "$DistDir\desktop.jar"
if (Test-Path "$ProjectRoot\desktop\icons\logo odoo CMP.png") {
    Copy-Item "$ProjectRoot\desktop\icons\logo odoo CMP.png" "$DistDir\icons\logo odoo CMP.png"
}

# 5. Package Standalone .EXE Installer using jpackage
Write-Host "`n=== Packaging to Standalone EXE with Java 21 JRE ===" -ForegroundColor Cyan
$jpackagePath = "$JdkPath\bin\jpackage.exe"
if (-not (Test-Path $jpackagePath)) {
    Write-Error "jpackage utility not found in JDK bin folder."
}

$OutputDir = "$ProjectRoot\output"
if (Test-Path $OutputDir) {
    Remove-Item -Recurse -Force $OutputDir
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null

# Run jpackage to build the zero-dependency installer
& $jpackagePath --type exe `
                --name "OdooDesktopSync" `
                --input "$DistDir" `
                --main-jar "desktop.jar" `
                --main-class "com.desktop.App" `
                --win-menu `
                --win-shortcut `
                --vendor "CMP" `
                --app-version "1.0.0" `
                --dest "$OutputDir"

Write-Host "`n=== PACKAGING COMPLETE ===" -ForegroundColor Green
Write-Host "Your standalone installer has been successfully generated in: $OutputDir\OdooDesktopSync-1.0.0.exe" -ForegroundColor Green
Write-Host "This installer contains a private copy of Java 21 so the end user does NOT need to install Java manually!" -ForegroundColor Green
Set-Location $ProjectRoot

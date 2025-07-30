$ErrorActionPreference = "Stop"

function install-course {
    param(
        [string]$CourseKey
    )

    # === CONFIGURATION ===
    $JavaRequiredVersion = 21
    $ZuluVersion = "21.0.1"
    $ZuluDownloadUrl = "https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-jre21.0.1-win_x64.zip"

    switch ($CourseKey) {
        "--course1" {
            $RepoUrl = "https://github.com/liferay/liferay-course-backend-client-extensions/archive/refs/heads/main.zip"
        }
        "--course2" {
            $RepoUrl = "https://github.com/liferay/liferay-course-frontend-client-extensions/archive/refs/heads/main.zip"
        }
        Default {
            Write-Host "❌ Invalid or missing argument. Use --course1 or --course2."
            return
        }
    }

    $ZipPath = "$env:TEMP\course.zip"
    $TempExtractRoot = "$env:TEMP\extracted-course"

    # === Download Course ZIP ===
    $ProgressPreference = 'SilentlyContinue' 
    Write-Host "📦 Downloading course repository..."
    Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath -UseBasicParsing

    # === Prepare temp folder ===
    if (Test-Path $TempExtractRoot) {
        Remove-Item $TempExtractRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TempExtractRoot | Out-Null

    Write-Host "📂 Extracting ZIP..."
    Expand-Archive -Path $ZipPath -DestinationPath $TempExtractRoot -Force
    Remove-Item $ZipPath

    # === Use Extracted GitHub Folder as Course Directory ===
    $ExtractedFolder = Get-ChildItem $TempExtractRoot | Where-Object { $_.PsIsContainer } | Select-Object -First 1

    if ($null -eq $ExtractedFolder) {
        Write-Host "❌ ZIP extraction failed: no folder found."
        exit 1
    }

    $ExtractPath = $ExtractedFolder.FullName
    Write-Host "📁 Using extracted folder: $ExtractPath"

    # === Java Version Detection ===
    function Get-JavaMajorVersion {
        try {
            $javaVersionOutput = & java -version 2>&1
            Write-Host "`n🔍 java -version output:`n$javaVersionOutput`n"
            foreach ($line in $javaVersionOutput) {
                if ($line -match '"(\d+)(\.\d+)*"') {
                    return [int]$matches[1]
                }
            }
        } catch {
            return $null
        }
        return $null
    }

    # === Java Installation ===
    $JavaInstallDir = Join-Path $ExtractPath "zulu-java"
    $JavaMarkerFile = Join-Path $JavaInstallDir ".installed"

    function Install-ZuluJRE {
        Write-Host "⬇️ Downloading Zulu JRE..."
        $zipFile = "$env:TEMP\zulu-jre.zip"
        $targetDir = $JavaInstallDir

        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $ZuluDownloadUrl -OutFile $zipFile -UseBasicParsing
        Expand-Archive -Path $zipFile -DestinationPath $targetDir
        Remove-Item $zipFile

        $unzipped = Get-ChildItem $targetDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1
        $ZuluPath = $unzipped.FullName

        $env:JAVA_HOME = $ZuluPath
        $env:Path = "$ZuluPath\bin;$env:Path"

        New-Item $JavaMarkerFile -ItemType File | Out-Null

        Write-Host "✅ Java installed at $ZuluPath"
        java -version
    }

    $javaMajor = Get-JavaMajorVersion

    if ($javaMajor -ne $JavaRequiredVersion) {
        if (Test-Path $JavaMarkerFile) {
            Write-Host "✅ Reusing previously installed Zulu Java from $JavaInstallDir"
            $ZuluPath = (Get-ChildItem $JavaInstallDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1).FullName
            $env:JAVA_HOME = $ZuluPath
            $env:Path = "$ZuluPath\bin;$env:Path"
        } else {
            Install-ZuluJRE
        }
    } else {
        Write-Host "☕ Java $JavaRequiredVersion already available in system."
    }

    # === Gradle Init ===
    Set-Location $ExtractPath
    Write-Host "🛠 Initializing course bundle..."
    Start-Process -FilePath ".\gradlew.bat" -ArgumentList "initBundle" -Wait

    # === Start Liferay ===
    $tomcatPath = Get-ChildItem "$ExtractPath\bundles" -Recurse -Directory | Where-Object { $_.Name -like "tomcat*" } | Select-Object -First 1
    if ($tomcatPath) {
        Write-Host "🚀 Starting Liferay server..."
        Start-Process "$($tomcatPath.FullName)\bin\catalina.bat" -ArgumentList "run"
    } else {
        Write-Host "❌ Tomcat not found inside bundle. Check if initBundle succeeded."
    }
}

# === Allow direct script execution ===
if ($MyInvocation.InvocationName -eq '.\content-manager-course-setup.ps1' -or $MyInvocation.MyCommand.Name -eq 'content-manager-course-setup.ps1') {
    if ($args.Count -ge 1) {
        install-course $args[0]
    } else {
        Write-Host "ℹ️ Usage: install-course --course1 | --course2"
    }
}

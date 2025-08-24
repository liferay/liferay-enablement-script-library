$ErrorActionPreference = "Stop"

function install-course {
    param(
        [string]$CourseKey
    )

    # === CONFIGURATION ===
    $JavaRequiredVersion = 21
    $ZuluDownloadUrl = "https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-jre21.0.1-win_x64.zip"

    switch ($CourseKey) {
        "--publishing-tool-and-content-lifecycle" {
            $RepoUrl = "https://github.com/liferay/liferay-course-publishing-tool-and-content-lifecycle/archive/refs/heads/main.zip"
        }
        "--pages-navigation" {
            $RepoUrl = "https://github.com/liferay/liferay-course-pages-navigation/archive/refs/heads/main.zip"
        }
        "--seo" {
            $RepoUrl = "https://github.com/liferay/liferay-course-search-engine-optimization/archive/refs/heads/main.zip"
        }
        "--content-search" {
            $RepoUrl = "https://github.com/liferay/liferay-course-content-search/archive/refs/heads/main.zip"
        }
        "--personalized-experiences" {
            $RepoUrl = "https://github.com/liferay/liferay-course-personalized-experiences/archive/refs/heads/main.zip"
        }
        "--assets-contents" {
            $RepoUrl = "https://github.com/liferay/liferay-course-assets-and-content/archive/refs/heads/main.zip"
        }
        Default {
            Write-Host "❌ Invalid or missing argument. Use --course1 or --course2."
            return
        }
    }

    $ZipPath = "$env:TEMP\course.zip"

    # === Download ZIP ===
    Write-Host "📦 Downloading course repository..."
    $ProgressPreference = 'SilentlyContinue' 
    Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath -UseBasicParsing

    # === Extract ZIP directly here ===
    Write-Host "📂 Extracting ZIP to current folder..."
    Expand-Archive -Path $ZipPath -DestinationPath $PWD -Force
    Remove-Item $ZipPath

    # === Find the extracted folder name ===
    $ExtractedFolder = Get-ChildItem -Path $PWD | Where-Object {
        $_.PsIsContainer -and $_.Name -like "liferay-course-*"
    } | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($null -eq $ExtractedFolder) {
        Write-Host "❌ Could not find the extracted folder."
        exit 1
    }

    $ExtractPath = $ExtractedFolder.FullName
    Write-Host "📁 Using extracted folder: $ExtractPath"

    # === Java Detection ===
function Get-JavaMajorVersion {
    # Returns [int] major version (e.g., 21) or $null if not found
    try {
        $javaCmd = (Get-Command java -ErrorAction Stop).Source
    } catch {
        return $null
    }

    # Run java -version but redirect both stderr and stdout to files to avoid NativeCommandError
    $tmpErr = [System.IO.Path]::GetTempFileName()
    $tmpOut = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $javaCmd -ArgumentList '-version' `
              -NoNewWindow -Wait -PassThru `
              -RedirectStandardError $tmpErr -RedirectStandardOutput $tmpOut

        $out = (Get-Content $tmpOut -Raw) + "`n" + (Get-Content $tmpErr -Raw)
    } finally {
        Remove-Item $tmpErr,$tmpOut -ErrorAction SilentlyContinue
    }

    Write-Host "`n🔍 java -version output:`n$out"

    # 1) Try quoted form:  version "21.0.8"
    $m = [regex]::Match($out, '(?im)version\s+"?(?<v>\d+(?:\.\d+){0,3})')
    if (-not $m.Success) {
        # 2) Try unquoted form: openjdk 21 ...
        $m = [regex]::Match($out, '(?im)^\s*openjdk\s+(?<v>\d+(?:\.\d+){0,3})\b')
    }
    if (-not $m.Success) { return $null }

    $ver = $m.Groups['v'].Value
    $parts = $ver.Split('.')

    # Normalize legacy 1.x (e.g., 1.8.0_xxx -> 8)
    if ($parts[0] -eq '1' -and $parts.Count -ge 2) {
        return [int]$parts[1]
    }
    return [int]$parts[0]
}

    # === Java Installation Inside the Extracted Folder ===
    $JavaInstallDir = Join-Path $ExtractPath "zulu-java"
    $JavaMarkerFile = Join-Path $JavaInstallDir ".installed"

    function Install-ZuluJRE {
        Write-Host "⬇️ Installing Zulu JRE inside: $JavaInstallDir"
        $zipFile = "$env:TEMP\zulu-jre.zip"

        $ProgressPreference = 'SilentlyContinue' 
        Invoke-WebRequest -Uri $ZuluDownloadUrl -OutFile $zipFile -UseBasicParsing
        Expand-Archive -Path $zipFile -DestinationPath $JavaInstallDir
        Remove-Item $zipFile

        $unzipped = Get-ChildItem $JavaInstallDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1
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
            Write-Host "☕ Using previously installed Java inside $JavaInstallDir"
            $ZuluPath = (Get-ChildItem $JavaInstallDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1).FullName
            $env:JAVA_HOME = $ZuluPath
            $env:Path = "$ZuluPath\bin;$env:Path"
        } else {
            Install-ZuluJRE
        }
    } else {
        Write-Host "☕ System Java version $javaMajor is OK."
    }

    # === Run Gradle Init ===
    Set-Location $ExtractPath
    Write-Host "🛠 Running Gradle init..."

    $p = Start-Process -FilePath ".\gradlew.bat" -ArgumentList "initBundle  --no-daemon --console=plain" -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
            Write-Host "❌ Gradle failed with exit code $($p.ExitCode)"
            exit $p.ExitCode
        }
    Write-Host "✅ Done. Liferay bundle initialized. You may proceed to start your Liferay application now."
return
}

# === Allow direct execution ===
if ($MyInvocation.InvocationName -eq '.\content-manager-course-setup.ps1' -or $MyInvocation.MyCommand.Name -eq 'content-manager-course-setup.ps1') {
    if ($args.Count -ge 1) {
        install-course $args[0]
    } else {
        Write-Host "ℹ️ Usage: install-course --course1 | --course2"
    }
}
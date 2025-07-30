$ErrorActionPreference = "Stop"

function install-course {
    param(
        [string]$CourseKey
    )

    # === CONFIGURATION ===
    $BaseDir = "liferay-course-content-manager"
    $JavaRequiredVersion = "21"
    $JavaRequiredFull = "21.0.1"

    switch ($CourseKey) {
        "--course1" {
            $RepoUrl = "https://github.com/liferay/liferay-course-backend-client-extensions/archive/refs/heads/main.zip"
        }
        "--course2" {
            $RepoUrl = "https://github.com/liferay/liferay-course-frontend-client-extensions/archive/refs/heads/main.zip"
        }
        Default {
            Write-Host "❌ Invalid or missing argument: use --course1 or --course2"
            return
        }
    }

    $CourseDirName = $CourseKey.TrimStart("-")
    $CourseDir = "$BaseDir-$CourseDirName"
    $ZipPath = "$env:TEMP\course.zip"
    $ExtractPath = "$PWD\$CourseDir"

    function Get-JavaMajorVersion {
        try {
            $javaVersionOutput = & java -version 2>&1
            if ($javaVersionOutput -match '"(\d+)(\.\d+)*"') {
                return [int]$matches[1]
            }
        } catch {
            return $null
        }
        return $null
    }

 $JavaInstallDir = "$PWD\$BaseDir\zulu-java"
$JavaMarkerFile = "$JavaInstallDir\.installed"

function Get-JavaMajorVersion {
    try {
        $javaVersionOutput = & java -version 2>&1
        if ($javaVersionOutput -match '"(\d+)(\.\d+)*"') {
            return [int]$matches[1]
        }
    } catch {
        return $null
    }
    return $null
}

function Install-ZuluJRE {
    Write-Host "⬇️ Downloading Zulu JRE..."

    $downloadUrl = "https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-jre21.0.1-win_x64.zip"
    $zipFile = "$env:TEMP\zulu-jre.zip"
    $targetDir = "$JavaInstallDir"

    if (Test-Path $JavaMarkerFile) {
        Write-Host "✅ Zulu JRE already installed."
        $env:JAVA_HOME = (Get-ChildItem $targetDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1).FullName
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
        return
    }

    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
    Expand-Archive -Path $zipFile -DestinationPath $targetDir
    Remove-Item $zipFile

    $unzipped = Get-ChildItem $targetDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1
    $ZuluPath = "$($unzipped.FullName)"

    $env:JAVA_HOME = $ZuluPath
    $env:Path = "$ZuluPath\bin;$env:Path"

    # Create marker file
    New-Item $JavaMarkerFile -ItemType File | Out-Null

    Write-Host "✅ Java installed at $ZuluPath"
    java -version
}

$javaMajor = Get-JavaMajorVersion

if (-not $javaMajor -or $javaMajor -ne 21) {
    Install-ZuluJRE
} else {
    Write-Host "☕ Java 21 already available in system."
}


    Write-Host "📦 Downloading course repository..."
    $ProgressPreference = 'SilentlyContinue'  
    nvoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath -UseBasicParsing

    if (-not (Test-Path $ZipPath)) {
    Write-Host "❌ Failed to download the course repository. Please check your network or try again."
    exit 1
}

    Write-Host "📂 Extracting repository..."
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath
    Remove-Item $ZipPath

    $inner = Get-ChildItem $ExtractPath | Where-Object { $_.PsIsContainer } | Select-Object -First 1
    Move-Item "$($inner.FullName)\*" $ExtractPath -Force
    Remove-Item $inner.FullName -Recurse -Force

    Set-Location $ExtractPath
    Write-Host "🛠 Setting up course environment..."
    Start-Process -FilePath ".\gradlew.bat" -ArgumentList "initBundle" -Wait

    Write-Host "🚀 Starting Liferay instance..."
    $tomcatPath = Get-ChildItem "$ExtractPath\bundles" -Recurse -Directory | Where-Object { $_.Name -like "tomcat*" } | Select-Object -First 1
    Start-Process "$($tomcatPath.FullName)\bin\catalina.bat" -ArgumentList "run"
}

# Allow direct execution
if ($MyInvocation.InvocationName -eq '.\content-manager-course-setup.ps1' -or $MyInvocation.MyCommand.Name -eq 'content-manager-course-setup.ps1') {
    if ($args.Count -ge 1) {
        install-course $args[0]
    } else {
        Write-Host "ℹ️ Usage: install-course --course1 | --course2"
    }
}

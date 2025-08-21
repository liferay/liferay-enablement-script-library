# setup.ps1
$ErrorActionPreference = "Stop"

# Ensure TLS 1.2 for downloads on Windows PowerShell 5.1
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# --- Quiet wrappers for downloads/extracts (no progress bars) ---
function Invoke-QuietDownload {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [Parameter(Mandatory)] [string]$OutFile
    )
    $prev = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile
    } finally {
        $ProgressPreference = $prev
    }
}

function Expand-ArchiveQuiet {
    param(
        [Parameter(Mandatory)] [string]$ZipPath,
        [Parameter(Mandatory)] [string]$DestinationPath
    )
    $prev = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force | Out-Null
    } finally {
        $ProgressPreference = $prev
    }
}

function Install-Course {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("--course1","--course2","--publishing-tool-and-content-lifecycle","--pages-navigation","--seo")]
        [string]$CourseKey
    )

    # === CONSTANTS ===
    $RuntimeDir = Join-Path $env:USERPROFILE ".liferay-course-runtime"
    $JavaDir    = Join-Path $RuntimeDir "zulu-java-21"
    $JavaRequiredMajor = 21

    # Arch-aware Azul JRE 21.0.1 URLs (used if system Java 21.x not found)
    $isArm = ($env:PROCESSOR_ARCHITECTURE -eq "ARM64")
    $ZuluDownloadUrl = if ($isArm) {
        "https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-jre21.0.1-win_aarch64.zip"
    } else {
        "https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-jre21.0.1-win_x64.zip"
    }

    switch ($CourseKey) {
        "--course1" { $RepoUrl = "https://github.com/liferay/liferay-course-backend-client-extensions/archive/refs/heads/main.zip" }
        "--course2" { $RepoUrl = "https://github.com/liferay/liferay-course-frontend-client-extensions/archive/refs/heads/main.zip" }
        "--publishing-tool-and-content-lifecycle" { $RepoUrl = "https://github.com/liferay/liferay-course-publishing-tool-and-content-lifecycle/archive/refs/heads/main.zip" }
        "--pages-navigation" { $RepoUrl = "https://github.com/liferay/liferay-course-pages-navigation/archive/refs/heads/main.zip" }
        "--seo" { $RepoUrl = "https://github.com/liferay/liferay-course-search-engine-optimization/archive/refs/heads/main.zip" }
    }

    # --- Your original helper: print java -version and return MAJOR ---
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

    function Install-ZuluJRE {
        Write-Host "⬇️ Installing Zulu JRE into: $JavaDir"
        New-Item -ItemType Directory -Force -Path $JavaDir | Out-Null
        $zipFile = Join-Path $env:TEMP "zulu-jre.zip"

        Invoke-QuietDownload -Url $ZuluDownloadUrl -OutFile $zipFile
        Expand-ArchiveQuiet -ZipPath $zipFile -DestinationPath $JavaDir
        Remove-Item $zipFile -Force

        # Flatten one-level folder if Azul ships as zulu-xx\*
        $unzipped = Get-ChildItem $JavaDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1
        if ($unzipped) {
            Move-Item -Path (Join-Path $unzipped.FullName "*") -Destination $JavaDir -Force
            Remove-Item $unzipped.FullName -Recurse -Force
        }

        $env:JAVA_HOME = $JavaDir
        $env:Path = "$JavaDir\bin;$env:Path"
        Write-Host "✅ Java installed at $JavaDir"
        & "$JavaDir\bin\java.exe" -version
    }

    # === JAVA CHECK (prefer managed JRE; else accept any system Java 21.x) ===
    if (Test-Path "$JavaDir\bin\java.exe") {
        $env:JAVA_HOME = $JavaDir
        $env:Path = "$JavaDir\bin;$env:Path"
        Write-Host "☕ Using managed Java from $JavaDir"
    } else {
        $major = Get-JavaMajorVersion
        if ($major -eq $JavaRequiredMajor) {
            Write-Host "☕ System Java major version $major detected — OK."
        } else {
            Install-ZuluJRE
        }
    }

    # === DOWNLOAD & EXTRACT REPO (quiet) ===
    $ZipPath = Join-Path $env:TEMP "course.zip"
    Write-Host "📦 Downloading course repository..."
    Invoke-QuietDownload -Url $RepoUrl -OutFile $ZipPath

    Expand-ArchiveQuiet -ZipPath $ZipPath -DestinationPath $PWD
    Remove-Item $ZipPath -Force

    # Pick the newest liferay-course-* folder
    $ExtractedFolder = Get-ChildItem -Path $PWD -Directory |
        Where-Object { $_.Name -like "liferay-course-*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $ExtractedFolder) {
        Write-Error "❌ Could not find extracted folder."
        exit 1
    }

    # Strip "-main" if present (rename, not move)
    $CleanName = ($ExtractedFolder.Name -replace "-main$", "")
    if ($ExtractedFolder.Name -ne $CleanName) {
        if (Test-Path $CleanName) { Remove-Item $CleanName -Recurse -Force }
        Rename-Item -Path $ExtractedFolder.FullName -NewName $CleanName
        $ExtractedFolder = Get-Item -Path (Join-Path $PWD $CleanName)
    }

    # === INIT BUNDLE ===
    Set-Location $ExtractedFolder.FullName
    Write-Host "🛠 Setting up course environment..."
    & .\gradlew.bat initBundle

    Write-Host "✅ Done. Liferay bundle initialized. You may proceed to start your Liferay application now."
}

# Allow direct execution too
if ($args.Count -ge 1) {
    Install-Course $args[0]
} else {
    Write-Host "ℹ️ Usage (one-liner):"
    Write-Host '  powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb <RAW_URL> | iex; Install-Course --course1"'
}

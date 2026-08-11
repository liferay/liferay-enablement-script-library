$ErrorActionPreference = "Stop"

# === COURSES (loaded dynamically from course-launcher/courses/*.conf) ===
function Import-CourseConfigs {
    param([string]$ConfDir)
    $configs = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($file in Get-ChildItem -Path $ConfDir -Filter "*.conf" | Sort-Object Name) {
        $learningPath = $null
        $courses = [System.Collections.Generic.List[string]]::new()
        $inCourses = $false
        foreach ($line in Get-Content $file.FullName) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^LEARNING_PATH="(.+)"$') {
                $learningPath = $Matches[1]
            } elseif ($trimmed -eq 'COURSES=(') {
                $inCourses = $true
            } elseif ($trimmed -eq ')' -and $inCourses) {
                $inCourses = $false
            } elseif ($inCourses -and $trimmed -ne '') {
                $courses.Add($trimmed)
            }
        }
        if ($learningPath -and $courses.Count -gt 0) {
            $configs.Add([PSCustomObject]@{ LearningPath = $learningPath; Courses = $courses.ToArray() })
        }
    }
    return ,$configs
}

# Fallback used when .conf files are unreachable (e.g. iex/irm invocation).
# Keep in sync with course-launcher/courses/*.conf.
$_LearningPaths = @(
    [PSCustomObject]@{
        LearningPath = "Content Manager"
        Courses = @(
            "--publishing-tool-and-content-lifecycle"
            "--pages-navigation"
            "--search-engine-optimization"
            "--content-search"
            "--personalized-experiences"
            "--classic-cms"
            "--content-management-system"
        )
    }
    [PSCustomObject]@{
        LearningPath = "Site Building"
        Courses = @("--building-enterprise-websites")
    }
    [PSCustomObject]@{
        LearningPath = "Commerce"
        Courses = @(
            "--foundations-of-commerce"
            "--commerce-users-and-accounts"
            "--commerce-product-management"
            "--commerce-inventory-management"
            "--commerce-pricing"
            "--commerce-order-management"
            "--commerce-storefronts"
        )
    }
)

# Override fallback with .conf files when running from a local checkout
$_ScriptPath = $MyInvocation.MyCommand.Path
if ($_ScriptPath) {
    $_ConfDir = Join-Path (Split-Path -Parent $_ScriptPath) "courses"
    if (Test-Path $_ConfDir) {
        $_loaded = Import-CourseConfigs -ConfDir $_ConfDir
        if ($_loaded.Count -gt 0) { $_LearningPaths = $_loaded }
    }
}

function Get-CourseKeys {
    foreach ($lp in $script:_LearningPaths) {
        Write-Host "  $($lp.LearningPath): $($lp.Courses -join ' | ')"
    }
}

function install-course {
    param(
        [string]$CourseKey
    )

    # === CONFIGURATION ===
    $JavaRequiredVersion = 21
    $ZuluDownloadUrl = "https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-jre21.0.1-win_x64.zip"
    # Managed JRE lives in a stable, user-level directory (mirrors the shell
    # script's ${HOME}/.liferay-course-runtime/zulu-java-21 path).
    # A fixed path lets setenv.bat reference %USERPROFILE% instead of an
    # absolute path that only works for the user who ran the installer.
    $RuntimeDir    = "$env:USERPROFILE\.liferay-course-runtime"
    $JavaInstallDir = "$RuntimeDir\zulu-java-21"

    switch ($CourseKey) {
        "--publishing-tool-and-content-lifecycle" {
            $RepoUrl = "https://github.com/liferay/liferay-course-publishing-tool-and-content-lifecycle/archive/refs/heads/main.zip"
        }
        "--pages-navigation" {
            $RepoUrl = "https://github.com/liferay/liferay-course-pages-navigation/archive/refs/heads/main.zip"
        }
        "--search-engine-optimization" {
            $RepoUrl = "https://github.com/liferay/liferay-course-search-engine-optimization/archive/refs/heads/main.zip"
        }
        "--content-search" {
            $RepoUrl = "https://github.com/liferay/liferay-course-content-search/archive/refs/heads/main.zip"
        }
        "--personalized-experiences" {
            $RepoUrl = "https://github.com/liferay/liferay-course-personalized-experiences/archive/refs/heads/main.zip"
        }
        "--classic-cms" {
            $RepoUrl = "https://github.com/liferay/liferay-course-classic-cms/archive/refs/heads/main.zip"
        }
        "--building-enterprise-websites" {
            $RepoUrl = "https://github.com/liferay/liferay-course-building-enterprise-websites/archive/refs/heads/main.zip"
        }
        "--foundations-of-commerce" {
            $RepoUrl = "https://github.com/liferay/liferay-course-foundations-of-commerce/archive/refs/heads/main.zip"
        }
        "--commerce-users-and-accounts" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-users-and-accounts/archive/refs/heads/main.zip"
        }
        "--commerce-product-management" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-product-management/archive/refs/heads/main.zip"
        }
        "--commerce-inventory-management" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-inventory-management/archive/refs/heads/main.zip"
        }
        "--commerce-pricing" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-pricing/archive/refs/heads/main.zip"
        }
        "--commerce-order-management" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-order-management/archive/refs/heads/main.zip"
        }
        "--commerce-storefronts" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-storefronts/archive/refs/heads/main.zip"
        }
        "--content-management-system" {
            $RepoUrl = "https://github.com/liferay/liferay-course-content-management-system/archive/refs/heads/main.zip"
        }
        Default {
            Write-Host "❌ Invalid or missing course key: $CourseKey"
            Write-Host "Available courses:"
            Get-CourseKeys
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

    # === Java Installation (user-level, shared across all courses) ===
    $JavaMarkerFile = Join-Path $JavaInstallDir ".installed"

    function Install-ZuluJRE {
        Write-Host "⬇️ Installing Zulu JRE to: $JavaInstallDir"
        $zipFile = "$env:TEMP\zulu-jre.zip"

        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $ZuluDownloadUrl -OutFile $zipFile -UseBasicParsing
        } catch {
            Write-Host "❌ Could not download Zulu JRE."
            Write-Host "   URL: $ZuluDownloadUrl"
            Write-Host "   Error: $_"
            Write-Host "   Please check your internet connection and try again."
            Write-Host "   If the problem persists, contact support and share this message."
            exit 1
        }

        # Extract to a temp dir first, then move the versioned subdirectory's
        # contents into the stable $JavaInstallDir so the path never changes
        # even if the Zulu version number is updated later.
        $tmpExtract = Join-Path $env:TEMP "zulu-extract-tmp"
        if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force }
        Expand-Archive -Path $zipFile -DestinationPath $tmpExtract
        Remove-Item $zipFile
        $unzipped = Get-ChildItem $tmpExtract | Where-Object { $_.PsIsContainer } | Select-Object -First 1
        New-Item -ItemType Directory -Path $JavaInstallDir -Force | Out-Null
        Move-Item -Path (Join-Path $unzipped.FullName "*") -Destination $JavaInstallDir -Force
        Remove-Item $tmpExtract -Recurse -Force

        $env:JAVA_HOME = $JavaInstallDir
        $env:Path = "$JavaInstallDir\bin;$env:Path"

        New-Item $JavaMarkerFile -ItemType File | Out-Null
        Write-Host "✅ Java installed at $JavaInstallDir"
        java -version

        # Persist JAVA_HOME for future sessions.
        # We compare against our exact path so that an existing Java 8 entry
        # is overwritten — not silently skipped.
        $existingJavaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", [System.EnvironmentVariableTarget]::User)
        if ($existingJavaHome -ne $JavaInstallDir) {
            [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $JavaInstallDir, [System.EnvironmentVariableTarget]::User)
            Write-Host "📝 JAVA_HOME updated to $JavaInstallDir in user environment."
        } else {
            Write-Host "ℹ️  JAVA_HOME already correctly set, skipping."
        }
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
        $zuluBin = "$JavaInstallDir\bin"
        if ($userPath -notlike "*$zuluBin*") {
            [System.Environment]::SetEnvironmentVariable("PATH", "$zuluBin;$userPath", [System.EnvironmentVariableTarget]::User)
            Write-Host "📝 $zuluBin added to user PATH."
        } else {
            Write-Host "ℹ️  $zuluBin already in user PATH, skipping."
        }
        Write-Host "ℹ️  Open a new terminal for the JAVA_HOME and PATH changes to take effect."
    }

    $javaMajor = Get-JavaMajorVersion

    if ($javaMajor -ne $JavaRequiredVersion) {
        if (Test-Path $JavaMarkerFile) {
            Write-Host "☕ Using previously installed Java at $JavaInstallDir"
            $env:JAVA_HOME = $JavaInstallDir
            $env:Path = "$JavaInstallDir\bin;$env:Path"
        } else {
            Install-ZuluJRE
        }
    } else {
        Write-Host "☕ System Java version $javaMajor is OK."
    }

    # Verify Java 21 is active before running Gradle.
    # Prefers JAVA_HOME/bin/java.exe to avoid PATH-cache issues,
    # giving a clear message instead of the cryptic JVM flag error.
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    $verifyJavaExe = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\java.exe" } elseif ($javaCmd) { $javaCmd.Source } else { $null }
    if (-not ($verifyJavaExe -and (Test-Path $verifyJavaExe))) {
        Write-Host "❌ No Java executable found after setup."
        Write-Host "   Please open a new terminal and re-run the script."
        exit 1
    }
    # Use Start-Process to capture java -version without triggering
    # NativeCommandError: java writes version info to stderr, which PowerShell
    # treats as a terminating error when $ErrorActionPreference = "Stop".
    $tmpVerErr = [System.IO.Path]::GetTempFileName()
    $tmpVerOut = [System.IO.Path]::GetTempFileName()
    try {
        Start-Process -FilePath $verifyJavaExe -ArgumentList '-version' `
              -NoNewWindow -Wait `
              -RedirectStandardError $tmpVerErr -RedirectStandardOutput $tmpVerOut
        $verifyOut = (Get-Content $tmpVerOut -Raw) + "`n" + (Get-Content $tmpVerErr -Raw)
    } finally {
        Remove-Item $tmpVerErr,$tmpVerOut -ErrorAction SilentlyContinue
    }
    $verifyMatch = [regex]::Match($verifyOut, 'version\s+"?(?<v>\d+(?:\.\d+)*)')
    $verifyMajor = if ($verifyMatch.Success) {
        $p = $verifyMatch.Groups['v'].Value.Split('.')
        if ($p[0] -eq '1') { [int]$p[1] } else { [int]$p[0] }
    } else { $null }
    if ($verifyMajor -ne $JavaRequiredVersion) {
        Write-Host "❌ Java $JavaRequiredVersion is required, but the active version is $verifyMajor."
        Write-Host "   JAVA_HOME: $($env:JAVA_HOME)"
        Write-Host "   Java binary: $verifyJavaExe"
        Write-Host "   If Java $JavaRequiredVersion was just installed, open a new terminal and re-run the script."
        exit 1
    }

    # === Run Gradle Init ===
    Set-Location $ExtractPath
    Write-Host "🛠 Running Gradle init..."

    $gradleMaxAttempts = 3
    $gradleSuccess = $false

    for ($attempt = 1; $attempt -le $gradleMaxAttempts; $attempt++) {
        $gradleLines = @()
        & .\gradlew.bat initBundle --no-daemon --console=plain 2>&1 |
            ForEach-Object { "$_" } |
            Tee-Object -Variable gradleLines
        $gradleExit = $LASTEXITCODE
        $gradleOutput = $gradleLines -join "`n"

        if ($gradleExit -eq 0) {
            $gradleSuccess = $true
            break
        }

        if ($attempt -lt $gradleMaxAttempts) {
            if ($gradleOutput -match "verifyBundle|checksum") {
                Write-Host "❌ Bundle download failed (checksum mismatch). This is usually caused by a slow or interrupted connection. Retrying... (attempt $attempt of $gradleMaxAttempts)"
            } else {
                Write-Host "❌ Gradle initBundle failed (exit code $gradleExit). Retrying... (attempt $attempt of $gradleMaxAttempts)"
            }
            Write-Host "🧹 Cleaning partial download artifacts..."
            Remove-Item -Path (Join-Path $ExtractPath "bundles") -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path (Join-Path $ExtractPath ".gradle") -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $gradleSuccess) {
        Write-Host "❌ Setup failed after $gradleMaxAttempts attempts. Please check your internet connection and try running the script again."
        exit 1
    }

    # Dynamically locate the Tomcat directory inside bundles\
    $TomcatDir = Get-ChildItem -Path (Join-Path $ExtractPath "bundles") -Directory -Filter "tomcat-*" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $TomcatDir) {
        Write-Host "⚠️  Could not find a Tomcat directory under bundles\. CATALINA_HOME not set."
    } else {
        $env:CATALINA_HOME = $TomcatDir.FullName
        Write-Host "✅ CATALINA_HOME set to $($env:CATALINA_HOME)"
        # Persist for future sessions (user scope, survives reboots)
        [System.Environment]::SetEnvironmentVariable("CATALINA_HOME", $TomcatDir.FullName, [System.EnvironmentVariableTarget]::User)
        Write-Host "📝 CATALINA_HOME persisted to user environment."

        $tomcatBinDir = Join-Path $TomcatDir.FullName "bin"

        # Patch startup.bat and shutdown.bat to use %~dp0.. (the script's own
        # directory) instead of %cd% (the caller's working directory) for
        # CATALINA_HOME detection. Without this, running them via a relative
        # path from the course root fails with "CATALINA_HOME is not defined correctly".
        foreach ($bat in @("startup.bat", "shutdown.bat")) {
            $batPath = Join-Path $tomcatBinDir $bat
            if (Test-Path $batPath) {
                $original = Get-Content $batPath -Raw
                $patched  = $original -replace 'set "CATALINA_HOME=%CURRENT_DIR%"', 'set "CATALINA_HOME=%~dp0.."'
                if ($original -ne $patched) {
                    Set-Content -Path $batPath -Value $patched -NoNewline
                    Write-Host "🔧 Patched $bat for script-relative CATALINA_HOME."
                }
            }
        }

        # Inject JAVA_HOME into setenv.bat so Tomcat always starts with the
        # correct Java 21, regardless of the user's system-level JAVA_HOME.
        # catalina.bat sources setenv.bat automatically on every startup/shutdown.
        # Use %USERPROFILE% (evaluated at Tomcat start time) instead of an
        # absolute path so the file works for any user on any machine.
        # Tomcat checks JRE_HOME first; without it, catalina.bat may resolve
        # to the system Java instead of our managed JRE 21.
        $javaHomeLine = 'set "JAVA_HOME=%USERPROFILE%\.liferay-course-runtime\zulu-java-21"'
        $jreHomeLine  = 'set "JRE_HOME=%USERPROFILE%\.liferay-course-runtime\zulu-java-21"'
        $setenvPath = Join-Path $tomcatBinDir "setenv.bat"
        $existing = if (Test-Path $setenvPath) { Get-Content $setenvPath -Raw } else { "" }
        $filtered = ($existing -split "`r?`n" |
            Where-Object { $_ -notmatch '^set "JAVA_HOME=' -and $_ -notmatch '^set "JRE_HOME=' }) -join "`r`n"
        $newContent = "$javaHomeLine`r`n$jreHomeLine`r`n$filtered".TrimEnd()
        Set-Content -Path $setenvPath -Value $newContent -NoNewline
        Write-Host "🔧 Configured Tomcat to use Java 21 via %USERPROFILE%\.liferay-course-runtime\zulu-java-21"
    }

    Write-Host "✅ Done. Liferay bundle initialized. You may proceed to start your Liferay application now."
return
}

# === Allow direct execution ===
if ($MyInvocation.InvocationName -eq '.\content-manager-course-setup.ps1' -or $MyInvocation.MyCommand.Name -eq 'content-manager-course-setup.ps1') {
    if ($args.Count -ge 1) {
        install-course $args[0]
    } else {
        Write-Host "ℹ️ Usage: .\content-manager-course-setup.ps1 <course-key>"
        Write-Host "Available courses:"
        Get-CourseKeys
    }
}
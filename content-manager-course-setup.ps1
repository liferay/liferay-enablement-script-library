$ErrorActionPreference = "Stop"

function install-course {
    param(
        [string]$CourseKey
    )

    # === CONFIGURATION ===
    $JavaRequiredVersion = 21
    # A JDK, not a JRE: Liferay starts Elasticsearch 8 as a child process for
    # search, and its entitlement subsystem needs the jdk.attach module that
    # only a full JDK ships. See Test-FullJdk below.
    $ZuluDownloadUrl = "https://cdn.azul.com/zulu/bin/zulu21.52.15-ca-jdk21.0.12-win_x64.zip"
    # Managed JDK lives in a stable, user-level directory (mirrors the shell
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
        "--users-and-accounts" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-users-and-accounts/archive/refs/heads/main.zip"
        }
        "--product-management" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-product-management/archive/refs/heads/main.zip"
        }
        "--inventory-management" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-inventory-management/archive/refs/heads/main.zip"
        }
        "--pricing" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-pricing/archive/refs/heads/main.zip"
        }
        "--order-management" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-order-management/archive/refs/heads/main.zip"
        }
        "--storefronts" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-storefronts/archive/refs/heads/main.zip"
        }
        "--content-management-system" {
            $RepoUrl = "https://github.com/liferay/liferay-course-content-management-system/archive/refs/heads/main.zip"
        }
        "--pricing" {
            $RepoUrl = "https://github.com/liferay/liferay-course-commerce-pricing/archive/refs/heads/main.zip"
        }
        Default {
            Write-Host "❌ Invalid or missing argument. Use --course1 or --course2."
            return
        }
    }

    $ZipPath = "$env:TEMP\course.zip"

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

# True when the given java.exe belongs to a full JDK rather than a JRE.
# Liferay starts Elasticsearch 8 as a child process for search, and its
# entitlement subsystem requires the jdk.attach module: on a JRE that process
# dies during JVM boot layer initialization with
#   FindException: Module jdk.attach not found, required by org.elasticsearch.entitlement
# leaving the portal running with search permanently broken. Probing for the
# module itself — rather than for javac.exe — also rejects trimmed or
# jlink-built runtimes that ship a compiler but omit jdk.attach. Mirrors
# is_full_jdk in content-manager-course-setup.sh.
function Test-FullJdk {
    param([string]$JavaExe)

    if (-not ($JavaExe -and (Test-Path $JavaExe))) { return $false }

    # Start-Process with redirected streams, as elsewhere in this script: java
    # writes to stderr, which PowerShell turns into a terminating error while
    # $ErrorActionPreference = "Stop".
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    try {
        Start-Process -FilePath $JavaExe -ArgumentList '--list-modules' `
              -NoNewWindow -Wait `
              -RedirectStandardError $tmpErr -RedirectStandardOutput $tmpOut | Out-Null
        $modules = Get-Content $tmpOut -Raw
    } catch {
        return $false
    } finally {
        Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
    }

    return ($modules -match '(?m)^jdk\.attach')
}

    # === Java Installation (user-level, shared across all courses) ===
    $JavaMarkerFile = Join-Path $JavaInstallDir ".installed"

    function Install-ZuluJdk {
        Write-Host "⬇️ Installing Zulu JDK to: $JavaInstallDir"
        $zipFile = "$env:TEMP\zulu-jdk.zip"

        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $ZuluDownloadUrl -OutFile $zipFile -UseBasicParsing
        } catch {
            Write-Host "❌ Could not download Zulu JDK."
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
        # Wipe any previous runtime rather than merging into it, so a JRE left
        # behind by an older version of this script cannot survive as a mix of
        # old and new files. The directory name is deliberately unchanged, so
        # the user environment variable and any bundle's setenv.bat keep
        # pointing at the right place.
        if (Test-Path $JavaInstallDir) { Remove-Item $JavaInstallDir -Recurse -Force }
        New-Item -ItemType Directory -Path $JavaInstallDir -Force | Out-Null
        Move-Item -Path (Join-Path $unzipped.FullName "*") -Destination $JavaInstallDir -Force
        Remove-Item $tmpExtract -Recurse -Force

        if (-not (Test-FullJdk (Join-Path $JavaInstallDir "bin\java.exe"))) {
            Write-Host "❌ The Java runtime downloaded from Azul is not a full JDK."
            Write-Host "   Installed at: $JavaInstallDir"
            Write-Host "   URL: $ZuluDownloadUrl"
            Write-Host "   Liferay's search engine cannot start without one."
            Write-Host "   Please contact support and share this message."
            exit 1
        }

        $env:JAVA_HOME = $JavaInstallDir
        $env:Path = "$JavaInstallDir\bin;$env:Path"

        # -Force so a re-install over a previous (JRE) runtime does not fail on
        # an already-existing marker file.
        New-Item $JavaMarkerFile -ItemType File -Force | Out-Null
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
    $usingManagedJdk = $false

    # A system Java 21 is only good enough if it is a full JDK. Resolve
    # JAVA_HOME from the system java binary too, so the setenv.bat injection
    # below can point Tomcat at the real install rather than the managed-JDK
    # path (which doesn't exist when the system Java is used).
    $systemJavaHome = $null
    if ($javaMajor -eq $JavaRequiredVersion) {
        try {
            $sysJavaCmd = (Get-Command java -ErrorAction Stop).Source
            $candidateHome = Split-Path (Split-Path $sysJavaCmd -Parent) -Parent
            if (Test-FullJdk (Join-Path $candidateHome "bin\java.exe")) {
                $systemJavaHome = $candidateHome
            } else {
                Write-Host "☕ System Java $javaMajor found at $candidateHome, but it is a JRE rather than a JDK."
                Write-Host "   Liferay's search engine needs a JDK, so the course JDK will be installed."
            }
        } catch { }
    }

    if ($systemJavaHome) {
        Write-Host "☕ System Java $javaMajor JDK is OK."
        $env:JAVA_HOME = $systemJavaHome
    } elseif ((Test-Path $JavaMarkerFile) -and (Test-FullJdk (Join-Path $JavaInstallDir "bin\java.exe"))) {
        Write-Host "☕ Using previously installed Java at $JavaInstallDir"
        $env:JAVA_HOME = $JavaInstallDir
        $env:Path = "$JavaInstallDir\bin;$env:Path"
        $usingManagedJdk = $true
    } else {
        # Reached either on a first run, or when a previous run of an older
        # version of this script left a JRE at $JavaInstallDir.
        if (Test-Path $JavaMarkerFile) {
            Write-Host "♻️  The course Java runtime at $JavaInstallDir is a JRE, which cannot run"
            Write-Host "   Liferay's search engine. Replacing it with a full JDK..."
        }
        Install-ZuluJdk
        $usingManagedJdk = $true
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
    if (-not (Test-FullJdk $verifyJavaExe)) {
        Write-Host "❌ Java $JavaRequiredVersion was found, but it is a JRE rather than a full JDK."
        Write-Host "   JAVA_HOME: $($env:JAVA_HOME)"
        Write-Host "   Java binary: $verifyJavaExe"
        Write-Host "   Liferay starts Elasticsearch as a child process for search, and that"
        Write-Host "   process cannot boot without the jdk.attach module a JDK provides."
        Write-Host "   Please install a Java $JavaRequiredVersion JDK, or clear JAVA_HOME and re-run this"
        Write-Host "   script so it can install the course JDK for you."
        exit 1
    }

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

    # === Run Gradle Init ===
    Set-Location $ExtractPath
    Write-Host "🛠 Running Gradle init..."

    $p = Start-Process -FilePath ".\gradlew.bat" -ArgumentList "initBundle  --no-daemon --console=plain" -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
            Write-Host "❌ Gradle failed with exit code $($p.ExitCode)"
            exit $p.ExitCode
        }

    # Patch Tomcat's startup.bat and shutdown.bat to use %~dp0.. (the script's
    # own directory) instead of %cd% (the caller's working directory) for
    # CATALINA_HOME detection. Without this, running them via a relative path
    # (e.g. .\bundles\tomcat\bin\startup.bat from the course root) fails with
    # "CATALINA_HOME is not defined correctly".
    $tomcatBinDir = Get-ChildItem -Path (Join-Path $ExtractPath "bundles") -Recurse `
        -Filter "startup.bat" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if ($tomcatBinDir) {
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
        # If initBundle already created a setenv.bat (Liferay uses it for JVM
        # heap options), prepend JAVA_HOME instead of overwriting the whole file.
        # Use %USERPROFILE% (evaluated at Tomcat start time) instead of an
        # absolute path so the file works for any user on any machine.
        # Tomcat checks JRE_HOME first; without it, catalina.bat may resolve
        # to the system Java instead of our managed JDK 21.
        if ($usingManagedJdk) {
            # Managed JDK: write %USERPROFILE%-relative paths so setenv.bat
            # works for any user, not just the one who ran the installer.
            $javaHomeLine = 'set "JAVA_HOME=%USERPROFILE%\.liferay-course-runtime\zulu-java-21"'
            $jreHomeLine  = 'set "JRE_HOME=%USERPROFILE%\.liferay-course-runtime\zulu-java-21"'
            $tomcatJavaNote = "%USERPROFILE%\.liferay-course-runtime\zulu-java-21"
        } else {
            # System Java 21 is being used (left in place) — point Tomcat at
            # its actual resolved path, not the managed-JDK path (which doesn't
            # exist when the system Java was used instead).
            $javaHomeLine = "set `"JAVA_HOME=$($env:JAVA_HOME)`""
            $jreHomeLine  = "set `"JRE_HOME=$($env:JAVA_HOME)`""
            $tomcatJavaNote = $env:JAVA_HOME
        }
        $setenvPath = Join-Path $tomcatBinDir "setenv.bat"
        $existing = if (Test-Path $setenvPath) { Get-Content $setenvPath -Raw } else { "" }
        $filtered = ($existing -split "`r?`n" |
            Where-Object { $_ -notmatch '^set "JAVA_HOME=' -and $_ -notmatch '^set "JRE_HOME=' }) -join "`r`n"
        $newContent = "$javaHomeLine`r`n$jreHomeLine`r`n$filtered".TrimEnd()
        Set-Content -Path $setenvPath -Value $newContent -NoNewline
        Write-Host "🔧 Configured Tomcat to use Java 21 via $tomcatJavaNote"
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
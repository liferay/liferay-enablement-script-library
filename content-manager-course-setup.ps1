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

    function Install-ZuluJRE {
        Write-Host "🌐 Downloading Zulu JRE..."

        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

        $jsonUrl = "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?java_version=$JavaRequiredFull&os=windows&arch=$arch&ext=zip&bundle_type=jre&javafx=false&release_status=ga&hw_bitness=64"

        $downloadUrl = Invoke-RestMethod $jsonUrl | Where-Object { $_.download_url } | Select-Object -ExpandProperty download_url

        $zipFile = "$env:TEMP\zulu-jre.zip"
        $targetDir = "$PWD\$BaseDir\zulu-java"

        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
        Expand-Archive -Path $zipFile -DestinationPath $targetDir
        Remove-Item $zipFile

        $unzipped = Get-ChildItem $targetDir | Where-Object { $_.PsIsContainer } | Select-Object -First 1
        $ZuluPath = "$($unzipped.FullName)"

        $env:JAVA_HOME = $ZuluPath
        $env:Path = "$ZuluPath\bin;$env:Path"

        java -version
    }

    $javaMajor = Get-JavaMajorVersion

    if (-not $javaMajor -or $javaMajor -ne 21) {
        Install-ZuluJRE
    }

    Write-Host "📦 Downloading course repository..."
    Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath

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

# Optional: local use fallback
if ($MyInvocation.InvocationName -eq '.\content-manager-course-setup.ps1' -or $MyInvocation.MyCommand.Name -eq 'content-manager-course-setup.ps1') {
    if ($args.Count -ge 1) {
        install-course $args[0]
    } else {
        Write-Host "ℹ️  Usage: install-course --course1 | --course2"
    }
}

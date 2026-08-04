# Course Setup Instructions

Liferay's Course Launcher tool automatically prepares your system and sets up a dedicated workspace for course exercises. Use this tool to streamline course environment setup — with **no technical expertise required**.

This tool:

* Checks if Java 21 is installed in your system. If not, it installs Zulu JRE 21 from Azul.
* Downloads and configures the course workspace.
* Initializes the local Liferay DXP bundle.

## Repository Structure

```
course-launcher/
├── course-setup.sh          # Linux/Mac launcher
├── course-setup.ps1         # Windows launcher
└── courses/
    ├── commerce.conf
    ├── content-manager.conf
    └── site-building.conf
```

## Course Key Convention

All course keys follow this naming convention:

```
key = repository name minus the "liferay-course-" prefix
```

Examples:

| Repository | Key |
|---|---|
| `liferay-course-pages-navigation` | `--pages-navigation` |
| `liferay-course-commerce-pricing` | `--commerce-pricing` |
| `liferay-course-building-enterprise-websites` | `--building-enterprise-websites` |

This convention applies to all learning paths. When in doubt, check the corresponding GitHub repository name under https://github.com/liferay.

## Adding a New Course

### To an existing learning path

1. Open the corresponding `.conf` file under `course-launcher/courses/`.

   Example: to add a new course to the Content Manager learning path, open `course-launcher/courses/content-manager.conf`:

   ```
   LEARNING_PATH="Content Manager"
   COURSES=(
     --publishing-tool-and-content-lifecycle
     --pages-navigation
     --search-engine-optimization
     --content-search
     --personalized-experiences
     --classic-cms
     --content-management-system
     --your-new-course-key   ← add the new key here
   )
   ```

2. Add the new course key following the naming convention: `key = repository name minus the "liferay-course-" prefix`.

   Example: for a repo named `liferay-course-content-staging`, add:

   ```
   --content-staging
   ```

3. Update the one-line fallback entry for that learning path in both `course-launcher/course-setup.sh` and `course-launcher/course-setup.ps1`. Search for the `# Keep in sync` comment to find the right place.

   Example in `course-setup.sh`:

   ```bash
   # Keep in sync with course-launcher/courses/content-manager.conf
   "--publishing-tool-and-content-lifecycle --pages-navigation --search-engine-optimization --content-search --personalized-experiences --classic-cms --content-management-system --content-staging"
   ```

   Example in `course-setup.ps1`:

   ```powershell
   # Keep in sync with course-launcher/courses/content-manager.conf
   [PSCustomObject]@{ LearningPath = "Content Manager"; Courses = @("--publishing-tool-and-content-lifecycle", "--pages-navigation", "--search-engine-optimization", "--content-search", "--personalized-experiences", "--classic-cms", "--content-management-system", "--content-staging") }
   ```

4. No other changes to the main scripts are needed.

### To a new learning path

1. Create a new `.conf` file under `course-launcher/courses/` following the format of the existing files.

   Example: to add a "Developer" learning path, create `course-launcher/courses/developer.conf`:

   ```
   LEARNING_PATH="Developer"
   COURSES=(
     --your-first-course-key
     --your-second-course-key
   )
   ```

2. Add a one-line fallback entry in both scripts. Search for the `# Keep in sync` comment and add a new line following the same pattern as the existing entries.

   Example in `course-setup.sh`:

   ```bash
   # Keep in sync with course-launcher/courses/developer.conf
   "--your-first-course-key --your-second-course-key"
   ```

   Example in `course-setup.ps1`:

   ```powershell
   # Keep in sync with course-launcher/courses/developer.conf
   [PSCustomObject]@{ LearningPath = "Developer"; Courses = @("--your-first-course-key", "--your-second-course-key") }
   ```

3. No other changes to the main scripts are needed.

## Troubleshooting

### JAVA_HOME not found after reopening the terminal

This was a known issue fixed in the 2026 maintenance window. If you installed Java via the course launcher and JAVA_HOME is missing in a new terminal:

- **Linux/Mac**: run `source ~/.bashrc` or `source ~/.zshrc`, then try again.
- **Windows**: open a new terminal window — the variable was persisted to your user environment and will be available in any new session.

If the issue persists, re-run the setup script — it will detect the existing Java installation and skip the download.

### Server fails to start with "CATALINA_HOME not defined"

This was a known issue fixed in the 2026 maintenance window. Re-run the setup script to set CATALINA_HOME correctly for your session.

### gradle initBundle fails with a checksum error

This is usually caused by a slow or interrupted internet connection. The setup script automatically retries up to 3 times and cleans any partial downloads between attempts. If all 3 attempts fail:

1. Check your internet connection.
2. Re-run the setup script — it will retry the download from scratch.

## Table of Contents

* [Setting Up the Clarity Workspace](#setting-up-the-clarity-workspace)
* [Manual Setup (Optional)](#manual-setup-optional)

## Setting Up the Clarity Workspace

Here, you'll execute the course launcher tool to prepare your system and set up the Clarity workspace you'll use in course exercises.

1. Open your terminal and run this command according to your operating system:

   <!-- Replace the [COURSE-NAME] placeholder with the corresponding course key. -->

   **Linux/Unix**:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.github.com/liferay/liferay-enablement-script-library/main/course-launcher/course-setup.sh)" -- --[COURSE-NAME] linux
   ```

   **Mac**:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.github.com/liferay/liferay-enablement-script-library/main/course-launcher/course-setup.sh)" -- --[COURSE-NAME] mac
   ```

   **Windows**:
   ```bash
   powershell Set-ExecutionPolicy Bypass -Scope Process -Force; iex "& { $(irm https://raw.githubusercontent.com/liferay/liferay-enablement-script-library/refs/heads/main/course-launcher/course-setup.ps1); install-course --[COURSE-NAME] }"
   ```

   This executes the course launcher tool, which automatically checks for and installs Java JDK 21, downloads the course's files, and prepares the Liferay DXP bundle.

> [!NOTE]
> The full process may take a few minutes to complete.

<!-- Replace the [COURSE-FOLDER-NAME] placeholder with the corresponding course folder. -->

2. Once the "Liferay bundle initialized" message displays, verify the `[COURSE-FOLDER-NAME]/` folder was created.

1. Go to the workspace's root folder in your terminal:

   <!-- Replace the [COURSE-FOLDER-NAME] placeholder with the corresponding course folder. -->

   ```bash
   cd [COURSE-FOLDER-NAME]/
   ```

1. Run this command to start the Liferay server:

   **Unix-based**:

   ```bash
   ./bundles/tomcat/bin/startup.sh
   ```

   **Windows**:

   ```bash
   .\bundles\tomcat\bin\startup.bat
   ```

1. Verify the “Tomcat started“ message displays.

   This indicates that the server has initiated its startup process in the background.

1. Access your Liferay DXP instance by going to [localhost:8080](http://localhost:8080) in your browser.

> [!NOTE]
> Server startup may take a few minutes to complete.

7. Sign in using these credentials:

   * Username: `admin@clarityvisionsolutions.com`
   * Password: `learn`

1. Open the *Global Menu*, go to the *Control Panel* tab, and click *Search*.

1. Go to the *Index Actions* tab and click *Reindex for All Search Indexes*.

1. When prompted, click *Execute* to confirm.

1. Take some time to explore the site and resources included in the training workspace.

> [!NOTE]
> To shutdown your Liferay server, run this command in your terminal:
>
> **Unix-based**:
>
> ```bash
> ./bundles/tomcat/bin/shutdown.sh
> ```
>
> **Windows**:
>
> ```bash
> .\bundles\tomcat\bin\shutdown.bat
> ```

Great! With your environment set up, you’re ready to start contributing to Clarity’s applications.

## Manual Setup (Optional)

Alternatively, you can set up your course environment manually.

> [!NOTE]
> This process involves more technical steps. If you're using a company system, you may need to contact your company's IT support.

1. Ensure your system satisfies the following prerequisites:

   * Git ([macOS](https://git-scm.com/download/mac) | [Windows](https://git-scm.com/download/win) | [Linux/Unix](https://git-scm.com/download/linux))
   * Java JDK 21 ([macOS](https://learn.microsoft.com/en-us/java/openjdk/install#install-on-macos) | [Windows](https://learn.microsoft.com/en-us/java/openjdk/install#install-on-windows) | [Linux](https://learn.microsoft.com/en-us/java/openjdk/install#install-on-ubuntu))

1. Open your terminal and clone the training workspace to your computer:

   <!-- Replace the [COURSE-REPO] placeholder with the corresponding course repository link. -->

   ```bash
   git clone https://github.com/liferay/[COURSE-REPO]
   ```

   This saves a copy of the project in your current terminal directory.

> [!NOTE]
> If you've cloned the repo previously, ensure your workspace is up to date by running `git pull origin main`.

3. Go to the workspace's root folder in your terminal:

   <!-- Replace the [COURSE-FOLDER-NAME] placeholder with the corresponding course folder. -->

   ```bash
   cd [COURSE-FOLDER-NAME]
   ```

1. Initialize your Liferay bundle.

   **Unix-based**:

   ```bash
   ./gradlew initBundle
   ```

   **Windows**:

   ```bash
   .\gradlew.bat initBundle
   ```

   This downloads and builds dependencies for running Liferay, including the Liferay Tomcat server.

1. Follow steps 3-9 of the [previous section](#setting-up-the-clarity-workspace).
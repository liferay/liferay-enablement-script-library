# 🚀 Liferay Course Launcher

This project provides a simple, automated way to set up and launch a Liferay DXP environment — with **no technical experience required**.

Currently, it supports the course:

> 📘 **Backend Client Extensions**  
> GitHub Repo: [liferay-course-backend-client-extensions](https://github.com/liferay/liferay-course-backend-client-extensions)

Future versions may support additional Liferay courses.

---

## ✅ What it does

- Automatically downloads and configures the course project
- Checks if Java is installed and is version 21
- If not, installs **Zulu JRE 21** from Azul
- Runs `initBundle` to prepare Liferay
- Starts the Liferay DXP server

---

## 🖥 Supported Operating Systems

- ✅ macOS
- ✅ Linux
- ✅ Windows

---

## 💻 How to Use

### 🪟 On Windows

1. Download this folder and unzip it.
2. Double-click `install-liferay.bat`.
3. Follow the on-screen instructions.

ℹ️ The script will:
- Open PowerShell behind the scenes
- Handle setup and installation automatically

---

### 🍎 On macOS or 🐧 Linux

1. Open your terminal.
2. Run the following commands (You may need certain priviledges to run these commands).:

```bash
chmod +x install-liferay-enablement-content-manager-setup.sh 
./install-liferay-enablement-content-manager-setup.sh

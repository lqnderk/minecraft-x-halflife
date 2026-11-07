# Changelog

## 0.2.6

- Extract MinGit and JDK archives using Windows tar instead of the PowerShell archive module.

## 0.2.5

- Detect Prism Launcher even when it runs from a custom or portable folder.
- Let the user pick the Prism executable if automatic detection fails. Keep the same Prism data folder when opening the crossover.

## 0.2.4

- Check PowerShell module loading before starting setup.
- If the system shell is a preview or its modules fail to load, download and verify a portable copy of stable PowerShell.

## 0.2.3

- Support PowerShell 7 when the Windows PowerShell entry point has been redirected, without loading modules through Windows PowerShell compatibility.

## 0.2.2

- Restrict Windows PowerShell module lookup to the built-in modules after startup so external PowerShell installations cannot shadow them.

## 0.2.1

- Launch the installer with the built-in Windows PowerShell and a clean module search path.
- Print the original installation error even if the PowerShell error-reporting module cannot load.

## 0.2.0

- Added a Windows installer that finds Steam Half-Life and supported Minecraft launchers.
- The installer prepares build dependencies and a Fabric 26.3 profile, installs the locally built mod, and creates a desktop shortcut.

## 0.1.0

- Build the native Half-Life client and server DLLs and the Fabric mod from pinned source revisions on Windows.
- Confirm that the Half-Life process exited before shutting Minecraft down. A Windows permission failure no longer triggers a false exit.
- Fall back to a centered Windows cursor if SDL loses relative mouse capture. Recenter also when the Minecraft inventory consumes mouse motion.

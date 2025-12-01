# Intune-scripts-for-MS-Defender-settings
![clint-patterson--jCY4oEMA3o-unsplash](https://github.com/user-attachments/assets/65681762-a45b-4c0e-b18a-f723636502a9)

*Credits to the respective creator.

These scripts can be readily deployed for various tasks related to Device Management using Microsoft Intune.

Currently, the following scripts are available in this repository.

1. **Check CPU uptime of Windows Devices**
   This can be helpful to know which devices have not been restarted in a while. Sometimes, application and OS updates require the devices to be restarted, but some device owners have a habit of putting their devices to sleep
   instead of shutting down/restarting. Hence, the app and/or OS is not installed, still leaving it vulnerable.

2. **Update apps using PowerShell**
   This ready-to-use script, when deployed using the **Scripts and Remediation** module of Intune, helps update installed software automatically and silently.

3. **Reparir System Integrity**
   This script will repair any flaws in underlying windows systems. Built on **System File Checker (SFC)**, it scans the operating system for missing or corrupted system files and repairs them automatically.

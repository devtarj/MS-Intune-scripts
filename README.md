# MS-Intune-scripts
![clint-patterson--jCY4oEMA3o-unsplash](https://github.com/user-attachments/assets/65681762-a45b-4c0e-b18a-f723636502a9)

*Credits to the respective creator.


🔥 PowerShell Scripts 🔥
These scripts can be readily deployed for various tasks related to Device Management using Microsoft Intune. Some scripts have been split into two parts - Detection and Remediation. Files names have been kept as required.

Currently, the following scripts are available in this repository.

1. **Check CPU uptime of Windows Devices** 🖥️

   In pair (Detection and Remediation)
   This can be helpful to know which devices have not been restarted in a while. Sometimes, application and OS updates require the devices to be restarted, but some device owners have a habit of putting their devices to sleep instead of shutting down/restarting. Hence, the app and/or OS is not installed, still leaving it vulnerable.

2. **Update apps using PowerShell** 📱
   
   In pair (Detection and Remediation)
   This ready-to-use script, when deployed using the **Scripts and Remediation** module of Intune, helps update installed software automatically and silently.

3. **Reparir System Integrity** ⚙️

   In pair (Detection and Remediation)
   This script will repair any flaws in underlying windows systems. Built on **System File Checker (SFC)**, it scans the operating system for missing or corrupted system files and repairs them automatically.

4. **Fetching basic inventory** 💻

   This script will fetch basic system information, disk information, installed applications, last reboot, and battery information (in case of laptop).

5. **Update Python in Windows** 🚀

   This script will update the installed python to the latest available version. Python will be added to PATH.


# WIN32 APP FILES

1. WinRAR
2. Git

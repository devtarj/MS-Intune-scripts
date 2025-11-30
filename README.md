# Intune-scripts-for-MS-Defender-settings

These scripts can be readily deployed for various tasks related to Device Management using Microsoft Intune.

Currently, the following scripts have been made available in this repository.

1. **Check CPU uptime of Windows Devices**
   This can be helpful to know which devices have not been restarted in a while. Sometimes, application and OS updates require the devices to be restarted, but some device owners have a habit of putting their devices to sleep
   instead of shutting down/restarting. Hence, the app and/or OS is not installed, still leaving it vulnerable.

2. **Update apps using PowerShell**
   This ready-to-use script, when deployed using **Scipts and Remeditaion** module of Intune, helps to update installed software automatically and silently.

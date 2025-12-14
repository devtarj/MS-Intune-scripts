<#
Creation date: 04-Dec-2025
Last modified date: 12-Dec-2025
Version: 0.1
#>

<#
Remediation Script to restart windows devices
#>

<#
It is recommended to restart the device using Intune > Device > open device > Restart. This is simpler and does not require a script. This enables control over timing and user experience. Hard restart is advised either after working hours or after a critical update requiring immediate restart.
#>

# regular command to restart the computer
shutdown /r /t 0

# Uncomment the below line for force restart
Restart-Computer -Force

# ------------------------------ END OF SCRIPT ------------------------------
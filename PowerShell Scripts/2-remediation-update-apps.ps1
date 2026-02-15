<#
Creation date: 02-Dec-2025
Last modified date: 02-Dec-2025
Version: 0.1
#>

<#
This script will use PowerShell to update installed applications.
It uses winget command. This script is next step to the detection script which checks whether or not winget is installed.
#>

# Update winget source
# winget source update #command

# Reset winget source by force
# winget source reset --force #command

# Re-register winget source 
# Add-AppxPackage -DisableDevelopmentMode -Register (Resolve-Path "C:\Program Files\WindowsApps\Microsoft.Winget.Source_*\AppXManifest.xml") -Verbose #command

# Command to update packages
winget upgrade --all --silent

# ------------------------------ END OF SCRIPT ------------------------------
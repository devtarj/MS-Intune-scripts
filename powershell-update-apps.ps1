<#
Creation date: 28-Nov-2025
Version: 0.1
#>

<#
This script will user PowerShell to update installed applications.
It uses winget command. This script will check whether or not winget is installed, its source is updated or not, and reset it (uncomment the command and re-run the script)
#>

# Check if winget is installed
Get-Command winget -ErrorAction SilentlyContinue

# Install winget if not present
# powershell -Command "Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile winget.msixbundle; Add-AppxPackage winget.msixbundle"

# Update winget source
# winget source update #command

# Reset winget source by force
# winget source reset --force #command

# Re-register winget source 
# Add-AppxPackage -DisableDevelopmentMode -Register (Resolve-Path "C:\Program Files\WindowsApps\Microsoft.Winget.Source_*\AppXManifest.xml") -Verbose #command

# Command to update packages
winget upgrade --all --silent

# ------------------------------ END OF SCRIPT ------------------------------
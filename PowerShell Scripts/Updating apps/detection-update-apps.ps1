<#
Creation date: 28-Nov-2025
Last modified date: 02-Dec-2025
Version: 0.1
#>

<#
Detection Script to check if winget is installed
#>

# Check if winget is installed
Get-Command winget -ErrorAction SilentlyContinue

# Install winget if not present
# powershell -Command "Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile winget.msixbundle; Add-AppxPackage winget.msixbundle"

# ------------------------------ END OF SCRIPT ------------------------------
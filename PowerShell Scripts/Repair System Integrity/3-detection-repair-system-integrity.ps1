<#
Creation date: 30-Nov-2025
Last modified date: 02-Dec-2025
Version: 0.1
#>

<#
Detection Script to check if sfc is available to repair system integrity
#>

# Check if SFC is installed
Get-Command sfc.exe -ErrorAction SilentlyContinue


# Check if SFC is installed
Get-Command dism.exe -ErrorAction SilentlyContinue

# --------------------------- END OF SCRIPT ---------------------------------
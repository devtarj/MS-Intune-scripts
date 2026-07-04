<#
Creation date: 01-Dec-2025
Last modified date: 11-Dec-2025
Version: 0.1
#>

<#
This script will use PowerShell to repair system integrity using DISM and SFC commands.
#>

# Repairs Windows Component Store (source of clean files)
DISM /Online /Cleanup-Image /RestoreHealth

# Repairs system files using that component store
sfc /scannow

# ------------------------------ END OF SCRIPT ------------------------------
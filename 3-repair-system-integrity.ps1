<#
Creation date: 28-Nov-2025
Version: 0.1
#>

<#
Script to repair Windows device's system integrity
#>

# Repairs Windows Component Store (source of clean files)
DISM /Online /Cleanup-Image /RestoreHealth

# Repairs system files using that component store
sfc /scannow

# --------------------------- END OF SCRIPT ---------------------------------
# Check how the script will be signed, if you want to keep it unsigned, you can set the "Enforce script signature check" to "NO" under scripts and remediation module of Intune.

# Ensure winget is available
Get-Command winget -ErrorAction SilentlyContinue

# Command to install Python 3.14 using winget - installs with normal user permissions
winget install --id Python.Python.3.14 --scope user --source winget --accept-package-agreements --accept-source-agreements --silent

# Command to install Python 3.14 using winget - installs with admin user permissions
#winget install --id Python.Python.3.12 --source winget --accept-package-agreements --accept-source-agreements --silent
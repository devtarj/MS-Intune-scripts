# Ensure winget is available
Get-Command winget -ErrorAction SilentlyContinue

# Command to install Python 3.14 using winget
winget install --id Python.Python.3.14 --scope user --source winget --accept-package-agreements --accept-source-agreements --silent
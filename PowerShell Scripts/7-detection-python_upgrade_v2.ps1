$python = Get-Command python -ErrorAction SilentlyContinue

if (-not $python) {
    Write-Output "Python not installed"
    exit 1
}

Write-Output "Python exists"
exit 0
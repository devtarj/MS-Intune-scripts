$Log = "C:\ProgramData\DotNetDiagnostic.txt"

$Results = @()

$Results += "===== WHOAMI ====="
$Results += (whoami)

$Results += ""
$Results += "===== DOTNET RUNTIMES ====="
$Results += (dotnet --list-runtimes 2>&1)

$Results += ""
$Results += "===== DOTNET SDKS ====="
$Results += (dotnet --list-sdks 2>&1)

$Results += ""
$Results += "===== WINGET UPGRADES ====="
$Results += (winget upgrade 2>&1)

$Results | Out-File $Log -Force

$Results
# Try to find PHP via PATH
$phpCmd = Get-Command php -ErrorAction SilentlyContinue

if ($phpCmd) {
    Write-Output "PHP found via PATH:"
    Write-Output $phpCmd.Source
} else {
    Write-Output "PHP not found in PATH. Searching common locations..."

    $paths = @(
        "C:\PHP\php.exe",
        "C:\xampp\php\php.exe",
        "C:\wamp64\bin\php\php.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Output "Found PHP at: $path"
        }
    }
}
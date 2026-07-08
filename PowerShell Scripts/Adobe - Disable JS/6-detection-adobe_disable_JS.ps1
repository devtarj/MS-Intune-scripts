# Detection script for JavaScript in Adobe Reader

try {
    $registryPath = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
    $valueName = "bDisableJavaScript"

    if (Test-Path $registryPath) {

        $value = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue

        if ($null -ne $value) {

            if ($value.$valueName -eq 0) {
                Write-Output "JavaScript is ENABLED (Non-compliant)"
                exit 1
            }
            elseif ($value.$valueName -eq 1) {
                Write-Output "JavaScript is DISABLED (Compliant)"
                exit 0
            }
        }
    }

    Write-Output "Registry key/value not found - needs remediation"
    exit 1
}
catch {
    Write-Output "Error checking registry: $($_.Exception.Message)"
    exit 1
}
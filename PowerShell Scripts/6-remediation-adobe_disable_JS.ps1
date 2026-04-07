# Remediation script to disable JavaScript in Adobe Reader DC

try {
    $registryPath = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
    $valueName = "bDisableJavaScript"
    $desiredValue = 1

    # Ensure the registry path exists
    if (!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    # Set the registry value
    New-ItemProperty -Path $registryPath `
                     -Name $valueName `
                     -Value $desiredValue `
                     -PropertyType DWORD `
                     -Force | Out-Null

    Write-Output "Remediation successful: JavaScript has been DISABLED in Adobe Reader DC"
    exit 0
}
catch {
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
}
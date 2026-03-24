# Remediation script for Chrome BlockThirdPartyCookies policy

try {
    # Define registry path
    $registryPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    
    # Ensure registry path exists
    if (-not (Test-Path -Path $registryPath)) {
        New-Item -Path $registryPath -Force -ErrorAction Stop | Out-Null
    }

    # Set the registry value to REG_DWORD = 1
    New-ItemProperty -Path $registryPath `
                     -Name "BlockThirdPartyCookies" `
                     -Value 1 `
                     -PropertyType DWord `
                     -Force `
                     -ErrorAction Stop | Out-Null

    Write-Output "Successfully set BlockThirdPartyCookies to 1"
    exit 0
}
catch {
    Write-Output "Error setting registry value: $($_.Exception.Message)"
    exit 1
}
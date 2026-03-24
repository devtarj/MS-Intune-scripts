# Detection script for Chrome BlockThirdPartyCookies policy

try {
    # Define registry path
    $registryPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    
    # Check if the registry path exists
    if (Test-Path $registryPath) {
        
        # Get the registry value
        $value = Get-ItemProperty -Path $registryPath -Name "BlockThirdPartyCookies" -ErrorAction SilentlyContinue
        
        # Check if value exists and equals 1
        if ($null -ne $value -and $value.BlockThirdPartyCookies -eq 1) {
            Write-Output "Registry configuration is compliant"
            exit 0  # Compliant
        }
    }
    
    Write-Output "Registry configuration needs remediation"
    exit 1  # Non-compliant
}
catch {
    Write-Output "Error checking registry: $($_.Exception.Message)"
    exit 1  # Treat errors as non-compliant
}
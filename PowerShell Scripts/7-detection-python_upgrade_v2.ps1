$minimumVersion = [version]"3.14.4"

$versionOutput = python --version 2>&1

if ($versionOutput -match "(\d+\.\d+\.\d+)") {

    $installedVersion = [version]$matches[1]

    if ($installedVersion -ge $minimumVersion) {

        Write-Output "Compliant: $installedVersion"
        exit 0
    }
}

Write-Output "Non-compliant"
exit 1
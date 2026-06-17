if (Test-Path "C:\ProgramData\Company\Logs\DotNetUpdate.log")
{
    Write-Output "LOG_EXISTS"
}
else
{
    Write-Output "LOG_MISSING"
}
$LogFolder = "C:\ProgramData\Company\Logs"

if(Test-Path $LogFolder)
{
    Get-ChildItem $LogFolder -Recurse

    Get-Content "$LogFolder\DotNetUpdate.log" -ErrorAction SilentlyContinue
}
Get-Command winget.exe

whoami

winget upgrade
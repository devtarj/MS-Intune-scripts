$packages = @(
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)

foreach ($pkg in $packages) {
    Write-Output "===== $pkg ====="
    winget list --id $pkg
}
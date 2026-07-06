# This script will fetch the value set for NTLMv2 registry settings on a Windows machine. It checks the registry for the NTLMv2 settings and outputs their current values.

Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" | Select-Object LmCompatibilityLevel
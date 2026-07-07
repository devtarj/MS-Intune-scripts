# If the detection script detects that NTLMv2 is not enebled, then it will set the registry values to enable NTLMv2. The expected value for LmCompatibilityLevel is 5, which means that NTLMv2 is enabled and will be used for authentication.

New-ItemProperty `
-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
-Name "LmCompatibilityLevel" `
-PropertyType DWord `
-Value 5 `
-Force
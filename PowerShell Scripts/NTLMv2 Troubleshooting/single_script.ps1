# LAN Manager Authentication Level
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
-Name "LmCompatibilityLevel" `
-Value 5 `
-PropertyType DWord `
-Force


# Restrict Receiving NTLM

New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" `
-Name "RestrictReceivingNTLMTraffic" `
-Value 2 `
-PropertyType DWord `
-Force


# Restrict Sending NTLM

New-ItemProperty `
-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" `
-Name "RestrictSendingNTLMTraffic" `
-Value 2 `
-PropertyType DWord `
-Force
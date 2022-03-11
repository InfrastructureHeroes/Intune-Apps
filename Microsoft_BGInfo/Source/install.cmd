@Echo OFF
cd %~dp0
Robocopy . C:\Programme\BGinfo *.* /R:2 /w:10
Robocopy . "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\ " *.lnk /R:2 /w:10
reg add HKU\.DEFAULT\Software\Sysinternals\BGInfo /v EulaAccepted /t REG_DWORD /d 1 /f
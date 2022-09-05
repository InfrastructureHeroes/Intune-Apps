# About this package
This package is created by Fabian Niesen - for more details, check https://github.com/InfrastructureHeroes/Intune-Apps

# Notes 
Install Language Pack over Intune, tested with Autopilot Pre-Provisioning process. Should work since 2004 / 20H1, tested for Pre-Provisioning with Windows 10 21H2.

To let the user chosse the Language modify settings "Language (Region)" is set to "User select" in the Autopilot profile. Pro-Tipp set "Automatically configure keyboard" to "no" befor change this setting.

# Requirements
To gather the required source files, download the following ISO images:
- Windows 10, version 2004 or 20H2 6C Local Experience Packs (LXPs) - prefered an updated version 
- Windows 10 Features on Demand, version 2004 DVD 1 - DVD 2 is not needed

# Adjustments for other languages
- Adjust in Win10-21H2-LanguagePack-DE-de.ps1 line 88 ($langname = "de-DE") and line 89 ($timezone = "W. Europe Standard Time") and change the locale in the filename
- Adjust in update-source.ps1 the following variables
 - $lang 
 - $LangDVD
 - $FoDDVD
-  remove the old locale folder, if existing
-  Replace the locale in config.xml
-  change the locale in the package path

# Tools I use
I Recomment to use PSCMWin10Language (https://github.com/codaamok/PSCMWin10Language) for creating the LP, LXP and FOD repositories.
Check out for more information: https://sysmansquad.com/2020/06/08/deploy-languages-via-software-center-with-pscmwin10language/

This packages are based upon the repository from https://github.com/gregnottage/IntuneScripts
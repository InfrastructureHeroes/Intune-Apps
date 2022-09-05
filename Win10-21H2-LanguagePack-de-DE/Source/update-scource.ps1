try {
    Import-Module "PSCMWin10Language"
}
catch {
    Install-Module "PSCMWin10Language" -Scope CurrentUser -Confirm:$false -Force
    Import-Module "PSCMWin10Language"
}
$lang = "de-DE"
$LangDVD = "\\adg\freigaben\Install\_Iso\Microsoft\Windows 10\mul_windows_10_version_2004_or_20h2_6c_local_experience_packs_lxps_updated_july_2022_x86_x64_arm64_dvd_9ca7c3a2\LocalExperiencePack"
$FoDDVD ="\\adg\freigaben\Install\_Iso\Microsoft\Windows 10\en_windows_10_features_on_demand_version_2004_x64"
$TargetPath= $PSScriptRoot 

New-LPRepository  -Language $lang -SourcePath $LangDVD -TargetPath $TargetPath
New-LXPRepository -Language $lang -SourcePath $LangDVD -TargetPath $TargetPath
New-FoDLanguageFeaturesRepository -Language $lang -SourcePath $FoDDVD -TargetPath $TargetPath
# Intune-Apps
Fork of [Greg Nottage](https://github.com/gregnottage/IntuneScripts) Intune Scripts by Fabian Niesen (InfrastrukturHelden.de / InfrastructureHeroes.org)
This is a framework for software packaging and automated upload to Intune. 

This Repo was locate as an personal repository from me before. I had rebuild it unter IFH and refilled it.

I will use this repository to provide additional Software examples. And maybe in future will add some mor functions and features. I have some ideas in mind, I just need to find some time.
Next step is implement the use of Versions and create a SCCM script to use the same sources for SCCM Applications.

# How to use it
Please add the installation file into the source folder. Then the Sourcefolder is ready to create the IntuneWin-File and Upload the file to Intune. 
All you need is to run the script:

.\Upload-IntuneWin.ps1 -userName admin@change.me -packagePath .\Dell_Command_Update_4.4.0\

The script also creates the needed AzureAD Groups for the software assignment.

For more information check [Guide for Upload](Guide for Upload v1.3.docx).

# Disclaimer
This repository includes Dell Tools. Iwork4Dell, but this is a personal project without any relation or support from Dell.

This script is supported as it is, usage is on your own risk. I recommend you check the code carfully and test ist before used in production.

# License
This scripts are available under the MIT License

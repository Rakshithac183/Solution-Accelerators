#Setup Script

#Enter Subscription ID
$subscriptionId= "<EnterSubscriptionIDValue>"

#Enter any 6 digit number
$uniqueNumber= "<Enter-any-6-Digits>"

#Update the region here if required: East US, South Central US, West US
$location= "East US"

New-Item -ItemType directory -Path D:\LabFiles -force

#LogFile
Start-Transcript -Path D:\LabFiles\DeploymentLogs.txt -Append
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force

#Creating LabValues file
New-Item D:\LabFiles\LabValues.txt

$subscriptionIdInFile= "subscriptionId = "+$subscriptionId
$uniqueNumberInFile= "uniqueNumber = "+$uniqueNumber
$locationInFile= "location = "+$location

Add-Content -Path D:\LabFiles\LabValues.txt -Value $subscriptionIdInFile -Force
Add-Content -Path D:\LabFiles\LabValues.txt -Value $uniqueNumberInFile -Force
Add-Content -Path D:\LabFiles\LabValues.txt -Value $locationInFile -Force


#Function4 Install Chocolatey
Function InstallChocolatey
{   
    #[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
    #[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 
    $env:chocolateyUseWindowsCompression = 'true'
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -Verbose
    choco feature enable -n allowGlobalConfirmation
}


InstallChocolatey

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name "PSGallery" -Installationpolicy Trusted
Install-Module -Name Az -AllowClobber -Scope AllUsers -Force
Install-Module -Name Az.Search -AllowClobber -Scope AllUsers
Install-Module -Name AzTable -Force


Import-Module -Name Az
Import-Module -Name Az.Search
Import-Module -Name AzTable

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/CloudLabsAI-Azure/Intelligent-Document-Processing-Solution-Accelerator/archive/refs/heads/main.zip","D:\LabFiles\Intelligent-Document-Processing.zip")
#unziping folder
function Expand-ZIPFile($file, $destination)
{
$shell = new-object -com shell.application
$zip = $shell.NameSpace($file)
foreach($item in $zip.items())
{
$shell.Namespace($destination).copyhere($item)
}
}
Expand-ZIPFile -File "D:\LabFiles\Intelligent-Document-Processing.zip" -Destination "D:\LabFiles\"

Rename-Item D:\LabFiles\Intelligent-Document-Processing-Solution-Accelerator-main D:\LabFiles\Intelligent-Document-Processing

#Update setup script URL
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/CloudLabsAI-Azure/Solution-Accelerators/raw/main/Intelligent-Document-Processing/cognitive-search-content-analytics-template.pbit","D:\LabFiles\cognitive-search-content-analytics-template.pbit")

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/CloudLabsAI-Azure/Solution-Accelerators/raw/main/Intelligent-Document-Processing/deploy.ps1","D:\LabFiles\Intelligent-Document-Processing\deploy\scripts\deploy.ps1")

Start-Sleep -s 5

CD D:\LabFiles\Intelligent-Document-Processing\deploy\scripts
.\deploy.ps1

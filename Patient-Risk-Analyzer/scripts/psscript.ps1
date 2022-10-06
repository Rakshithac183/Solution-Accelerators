Param (
    [Parameter(Mandatory = $true)]
    [string]
    $AzureUserName,

    [string]
    $AzurePassword,

    [string]
    $AzureTenantID,

    [string]
    $AzureSubscriptionID,

    [string]
    $DeploymentID,

    [string]
    $azuserobjectid,
    
    [string]
    $vmAdminUsername,

    [string]
    $vmAdminPassword
)


Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt -Append
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

$adminUsername = "demouser"
[System.Environment]::SetEnvironmentVariable('DeploymentID', $DeploymentID,[System.EnvironmentVariableTarget]::Machine)


Function Disable-InternetExplorerESC
{
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force -ErrorAction SilentlyContinue -Verbose
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force -ErrorAction SilentlyContinue -Verbose
    #Stop-Process -Name Explorer -Force
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green -Verbose
}

#Function2 - Enable File Download on Windows Server Internet Explorer
Function Enable-IEFileDownload
{
    $HKLM = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3"
    $HKCU = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3"
    Set-ItemProperty -Path $HKLM -Name "1803" -Value 0 -ErrorAction SilentlyContinue -Verbose
    Set-ItemProperty -Path $HKCU -Name "1803" -Value 0 -ErrorAction SilentlyContinue -Verbose
    Set-ItemProperty -Path $HKLM -Name "1604" -Value 0 -ErrorAction SilentlyContinue -Verbose
    Set-ItemProperty -Path $HKCU -Name "1604" -Value 0 -ErrorAction SilentlyContinue -Verbose
}

#Function3 - Enable Copy Page Content in IE
Function Enable-CopyPageContent-In-InternetExplorer
{
    $HKLM = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3"
    $HKCU = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3"
    Set-ItemProperty -Path $HKLM -Name "1407" -Value 0 -ErrorAction SilentlyContinue -Verbose
    Set-ItemProperty -Path $HKCU -Name "1407" -Value 0 -ErrorAction SilentlyContinue -Verbose
}

#Function4 Install Chocolatey
Function InstallChocolatey
{   
    #[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
    #[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 
    $env:chocolateyUseWindowsCompression = 'true'
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -Verbose
    choco feature enable -n allowGlobalConfirmation
}

#Function5 Disable PopUp for network configuration

Function DisableServerMgrNetworkPopup
{
    cd HKLM:\
    New-Item -Path HKLM:\System\CurrentControlSet\Control\Network -Name NewNetworkWindowOff -Force 

    Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose
}

Function CreateLabFilesDirectory
{
    New-Item -ItemType directory -Path C:\LabFiles -force
}

Function DisableWindowsFirewall
{
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

}

Function InstallAzPowerShellModule
{
    <#Install-PackageProvider NuGet -Force
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module Az -Repository PSGallery -Force -AllowClobber#>

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("https://github.com/Azure/azure-powershell/releases/download/v5.0.0-October2020/Az-Cmdlets-5.0.0.33612-x64.msi","C:\Packages\Az-Cmdlets-5.0.0.33612-x64.msi")
    sleep 5
    Start-Process msiexec.exe -Wait '/I C:\Packages\Az-Cmdlets-5.0.0.33612-x64.msi /qn' -Verbose 

}

Function InstallEdgeChromium
{
    #Download and Install edge
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("http://go.microsoft.com/fwlink/?LinkID=2093437","C:\Packages\MicrosoftEdgeBetaEnterpriseX64.msi")
    sleep 5
    
    Start-Process msiexec.exe -Wait '/I C:\Packages\MicrosoftEdgeBetaEnterpriseX64.msi /qn' -Verbose 
    sleep 5
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Azure Portal.lnk")
    $Shortcut.TargetPath = """C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"""
    $argA = """https://portal.azure.com"""
    $Shortcut.Arguments = $argA 
    $Shortcut.Save()
}

Function InstallAzCLI
{
    choco install azure-cli -y -force
}


Function WindowsServerCommon
{
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 
Disable-InternetExplorerESC
Enable-IEFileDownload
Enable-CopyPageContent-In-InternetExplorer
InstallChocolatey
DisableServerMgrNetworkPopup
CreateLabFilesDirectory
DisableWindowsFirewall
InstallAzPowerShellModule
InstallAzCLI
InstallEdgeChromium
}

WindowsServerCommon

#Import creds
$AzureUserName 
$AzurePassword 
$passwd = ConvertTo-SecureString $AzurePassword -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AzureUserName, $passwd


#deploy armtemplate

$parm = "syn"+$DeploymentID
Import-Module Az
Connect-AzAccount -Credential $cred
Select-AzSubscription -SubscriptionId $AzureSubscriptionID
$rgName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "many*" }).ResourceGroupName
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri https://raw.githubusercontent.com/CloudLabsAI-Azure/Solution-Accelerators/main/Patient-Risk-Analyzer/synapse.json -TemplateParameterUri https://raw.githubusercontent.com/CloudLabsAI-Azure/Solution-Accelerators/main/Patient-Risk-Analyzer/synapse.parameters.json
#storage copy
$userName = $AzureUserName
$password = $AzurePassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SpektraSystems/CloudLabs-Azure/master/azure-synapse-analytics-workshop-400/artifacts/setup/azcopy.exe" -OutFile "C:\labfiles\azcopy.exe"

$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Credential $cred | Out-Null

#Download lab files
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/CloudLabsAI-Azure/Solution-Accelerators.git","C:\Patient-Risk-Analyzer.zip")

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
Expand-ZIPFile -File "C:\Patient-Risk-Analyzer.zip" -Destination "C:\LabFiles\"

$rgName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "many*" }).ResourceGroupName
$storageAccounts = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Storage/storageAccounts"
$storageName = $storageAccounts | Where-Object { $_.Name -like 'pati*' }
$storage = Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageName.Name
$storageContext = $storage.Context
$storageaccname = $storageName.Name

$srcUrl = $null
$rgLocation = (Get-AzResourceGroup -Name $rgName).Location

$filesystemName = "raw"
$dirname = "DatasetDiabetes/"
$dirname1 = "Names/"

New-AzDataLakeGen2Item -Context $storageContext -FileSystem $filesystemName -Path $dirname -Directory
New-AzDataLakeGen2Item -Context $storageContext -FileSystem $filesystemName -Path $dirname1 -Directory

          

$srcUrl = "C:\LabFiles\Solution-Accelerators-main\Patient-Risk-Analyzer\Resources\diabetic_data.csv"
$srcUrl1 = "C:\LabFiles\Solution-Accelerators-main\Patient-Risk-Analyzer\Resources\Names.csv"

           
$destContext = $storage.Context
$containerName = "raw"
$resources = $null

$startTime = Get-Date
$endTime = $startTime.AddDays(2)
$destSASToken = New-AzStorageContainerSASToken  -Context $destContext -Container raw  -Permission rwdlac -StartTime $startTime -ExpiryTime $endTime
$destUrl = $destContext.BlobEndPoint + "raw/" + "DatasetDiabetes/" + $destSASToken
$destUrl1 = $destContext.BlobEndPoint + "raw/" + "Names/" + $destSASToken


$srcUrl 
$destUrl

C:\LabFiles\azcopy.exe copy $srcUrl $destUrl --recursive
C:\LabFiles\azcopy.exe copy $srcUrl1 $destUrl1 --recursive

$WebClient.DownloadFile("https://github.com/PowerShell/PowerShell/releases/download/v7.2.6/PowerShell-7.2.6-win-x64.msi","C:\LabFiles\PowerShell-7.2.6-win-x64.msi")

msiexec.exe /I C:\LabFiles\PowerShell-7.2.6-win-x64.msi /quiet

Start-Process C:\LabFiles\PowerShell-7.2.6-win-x64.msi -ArgumentList "/quiet"


$machinelearningAccount = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.MachineLearningServices/workspaces"
$machinelearningName = $machinelearningAccount | Where-Object { $_.Name -like 'ml*' }
$machinelearningaccname = $machinelearningName.Name

#Download LogonTask
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://raw.githubusercontent.com/CloudLabsAI-Azure/Solution-Accelerators/main/Patient-Risk-Analyzer/scripts/logontask.ps1","C:\LabFiles\logon.ps1")

#download psm1 file
$WebClient.DownloadFile("https://raw.githubusercontent.com/CloudLabsAI-Azure/Solution-Accelerators/main/Patient-Risk-Analyzer/scripts/validation.ps1","C:\LabFiles\validate.ps1")


#download psm1 file
$WebClient.DownloadFile("https://raw.githubusercontent.com/CloudLabsAI-Azure/Solution-Accelerators/main/Patient-Risk-Analyzer/scripts/validation.psm1","C:\LabFiles\validationscript.psm1")
$WebClient.DownloadFile("https://raw.githubusercontent.com/CloudLabsAI-Azure/Solution-Accelerators/main/Patient-Risk-Analyzer/scripts/docker.ps1","C:\LabFiles\docker.ps1")

(Get-Content -Path "C:\LabFiles\logon.ps1") | ForEach-Object {$_ -Replace 'enter_uname', $userName} | Set-Content -Path "C:\LabFiles\logon.ps1"
(Get-Content -Path "C:\LabFiles\logon.ps1") | ForEach-Object {$_ -Replace 'enter_pssword', $password} | Set-Content -Path "C:\LabFiles\logon.ps1"

#Download lab files
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://raw.githubusercontent.com/CloudLabsAI-Azure/Solution-Accelerators/main/Patient-Risk-Analyzer/scripts/solutionaccelarator.zip","C:\patientrisk.zip")

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
Expand-ZIPFile -File "C:\patientrisk.zip" -Destination "C:\LabFiles"

Copy-Item -Path C:\LabFiles\solutionaccelarator\* -Destination C:\LabFiles -Force

#first notebook
(Get-Content -Path "C:\LabFiles\00_preparedata.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name = ''", "data_lake_account_name = '$storageaccname'"} | Set-Content -Path "C:\LabFiles\00_preparedata.ipynb"

#second notebook
(Get-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name = ''", "data_lake_account_name = '$storageaccname'"} | Set-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb") | ForEach-Object {$_ -Replace "enter_subscription_id", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb") | ForEach-Object {$_ -Replace "enter_rg_name", "$rgName"} | Set-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb") | ForEach-Object {$_ -Replace "enter_workspace_name", "$machinelearningaccname"} | Set-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb"
(Get-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb") | ForEach-Object {$_ -Replace "enter_region", "$rgLocation"} | Set-Content -Path "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb"


#Download LogonTask

#Enable Auto-Logon
$AutoLogonRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoAdminLogon" -Value "1" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultUsername" -Value "$($env:ComputerName)\demouser" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultPassword" -Value "Password.1!!" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoLogonCount" -Value "1" -type DWord

#checkdeployment
$status = (Get-AzResourceGroupDeployment -ResourceGroupName $rgName -Name "deploy02").ProvisioningState
$status
if ($status -eq "Succeeded")
{
 
    $Validstatus="Pending"  ##Failed or Successful at the last step
    $Validmessage="Main Deployment is successful, logontask is pending"

# Scheduled Task
$Trigger= New-ScheduledTaskTrigger -AtLogOn
$User= "$($env:ComputerName)\demouser"
$Action= New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe" -Argument "-executionPolicy Unrestricted -File C:\LabFiles\logon.ps1"
Register-ScheduledTask -TaskName "Setup1" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest -Force
Set-ExecutionPolicy -ExecutionPolicy bypass -Force
 
}
else {
    Write-Warning "Validation Failed - see log output"
    $Validstatus="Failed"  ##Failed or Successful at the last step
    $Validmessage="ARM template Deployment Failed"
      }

CloudlabsManualAgent setStatus


Stop-Transcript
Restart-Computer -Force 

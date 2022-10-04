Start-Transcript -Path C:\WindowsAzure\Logs\logontask.txt -Append

# Install VS COde extension 
code --install-extension ms-azuretools.vscode-docker

#Install WSL
wsl --install -d Debian

#Install Dcoker-Desktop
choco install docker-for-windows -y -force

cd C:\LabFiles
$credsfilepath = "C:\LabFiles\AzureCreds.txt"
$creds = Get-Content $credsfilepath | Out-String | ConvertFrom-StringData
$AzureUserName = "$($creds.AzureUserName)"
$AzurePassword = "$($creds.AzurePassword)"
$SubscriptionId = "$($creds.AzureSubscriptionID)"
$passwd = ConvertTo-SecureString $AzurePassword -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AzureUserName, $passwd

 start Docker

Start-Service *docker*

Start-Sleep -s 150


# Build docker image and container

cd C:\LabFiles\Virtual-Assistant-Deployer\.devcontainer

docker build . -t vadimage:1.0

docker container create -i -t --name mycontainer vadimage:1.0

# Run scripts inside the container

docker start mycontainer

docker exec -it mycontainer /usr//bin/pwsh -command "New-Item "labfiles" -itemType Directory"

docker cp C:\LabFiles\Virtual-Assistant-Deployer mycontainer:/labfiles

docker exec  -it mycontainer /usr//bin/pwsh -command "/labfiles/Virtual-Assistant-Deployer/.devcontainer/setup.ps1"


# Run scripts in docker container

docker cp C:\LabFiles\deploy.ps1 mycontainer:/va/VirtualAssistantSample/Deployment/Scripts/deploy.ps1

docker exec  -it mycontainer /usr//bin/pwsh -command 'az login -u enter_username -p enter_pwd'

docker exec  -it mycontainer /usr//bin/pwsh -command 'az account set -s enter_subid'

docker exec  -it mycontainer /usr//bin/pwsh -command "/labfiles/Virtual-Assistant-Deployer/deploy.ps1"

# Fetch deployment info

Import-Module Az
Connect-AzAccount -Credential $cred | Out-Null
Select-AzSubscription -SubscriptionId $SubscriptionId



$deplyinfo= (Get-AzResourceGroupDeployment -ResourceGroupName "VA-did").DeploymentName

$Status1= (Get-AzResourceGroupDeployment -ResourceGroupName "VA-did" -Name $deplyinfo[0]).ProvisioningState
$Status2= (Get-AzResourceGroupDeployment -ResourceGroupName "VA-did" -Name $deplyinfo[1]).ProvisioningState
$Status3= (Get-AzResourceGroupDeployment -ResourceGroupName "VA-did" -Name $deplyinfo[2]).ProvisioningState
$Status4= (Get-AzResourceGroupDeployment -ResourceGroupName "VA-did" -Name $deplyinfo[3]).ProvisioningState
$Status5= (Get-AzResourceGroupDeployment -ResourceGroupName "VA-did" -Name $deplyinfo[4]).ProvisioningState


if (($Status1 -eq "Succeeded") -and ($Status2 -eq "Succeeded") -and ($Status3 -eq "Succeeded") -and ($Status4 -eq "Succeeded") -and ($Status5 -eq "Succeeded"))
 {
    $Validstatus="Succeeded"  ##Failed or Successful at the last step
    $Validmessage="Post Deployment is successful"
}
else{
    Write-Warning "Validation Failed - see log output"
    $Validstatus="Failed"  ##Failed or Successful at the last step
    $Validmessage="Post Deployment Failed"
}

Unregister-ScheduledTask -TaskName "Setup" -Confirm:$false
Stop-Transcript

Start-Transcript -Path C:\WindowsAzure\Logs\extensionlog.txt -Append

#InstallAzmodule
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name "PSGallery" -Installationpolicy Trusted
Install-Module -Name Az.Synapse -Force
Import-Module -Name Az.Synapse

. C:\LabFiles\AzureCreds.ps1



$userName = $AzureUserName # READ FROM FILE
$password = $AzurePassword # READ FROM FILE
$Sid = $AzureSubscriptionID # READ FROM FILE
$deployId = $DeploymentID
$synapseworkspaceName = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Synapse/workspaces"
$synapseworkspaceName = $workspaceName| Where-Object { $_.Name -like '*' }
$synapseworkspaceName = $workspaceName.Name

$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Credential $cred | Out-Null

$rgName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "many*" }).ResourceGroupName
$rgLocation = (Get-AzResourceGroup -Name $rgName).Location

$storageAccounts = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Storage/storageAccounts"
$storageName = $storageAccounts | Where-Object { $_.Name -like 'pati*' }
$storageaccountname = $storageName.Name

#adding roles
$id3 = $userName
New-AzRoleAssignment -SignInName $id3 -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$Sid/resourceGroups/$rgName/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

$id1 = (Get-AzADServicePrincipal -DisplayName $synapseworkspaceName).id
New-AzRoleAssignment -ObjectId $id1 -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$Sid/resourceGroups/$rgName/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

#adding clientsleep 20
 
$cosmosdb= Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.DocumentDB/databaseAccounts"
$cosmosdbaccountname = $cosmosdb| Where-Object { $_.Name -like 'cosmosdb*' }
$accountName = $cosmosdbaccountname.Name

$cosmosconnectstring = Get-AzCosmosDBAccountKey -ResourceGroupName $rgName -Name $accountName -Type "ConnectionStrings" 
$cosmosDBPrimarySQLConnectionString = $cosmosconnectstring["Primary SQL Connection String"]

$cosmoskey = Get-AzCosmosDBAccountKey -ResourceGroupName  $rgName -Name $accountName -Type "PrimaryMasterKey"
$cosmosDBPrimarykey = $cosmoskey["PrimaryMasterKey"]

$machinelearningAccount = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.MachineLearningServices/workspaces"
$machinelearningName = $machinelearningAccount | Where-Object { $_.Name -like 'ml*' }
$machinelearningaccname = $machinelearningName.Name
$mlaccountName = $machinelearningaccname

$id1 = (Get-AzADServicePrincipal -DisplayName $synapseworkspaceName).id
New-AzRoleAssignment -ObjectId $id1 -RoleDefinitionName "Contributor" -Scope "/subscriptions/$Sid/resourceGroups/$rgName/providers/Microsoft.MachineLearningServices/workspaces/$mlaccountName"

#speech service account name and key
$speech= Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.CognitiveServices/accounts"
$speechaccountname = $speech| Where-Object { $_.Name -like 'Speech*' }
$speechaccName = $speechaccountname.Name
$speecglocation = $speechaccountname.location

#cosmosdb key
(Get-Content -Path "C:\LabFiles\cosmosdblinkedservice.json") | ForEach-Object {$_ -Replace '#COSMOSDB_ACCOUNT_NAME#', $accountName} | Set-Content -Path "C:\LabFiles\cosmosdblinkedservice.json"
(Get-Content -Path "C:\LabFiles\cosmosdblinkedservice.json") | ForEach-Object {$_ -Replace '#COSMOSDB_ACCOUNT_KEY#', $cosmosDBPrimarykey }| Set-Content -Path "C:\LabFiles\cosmosdblinkedservice.json"


Set-AzSynapseLinkedService -WorkspaceName $synapseworkspaceName  -Name patientHubDB -DefinitionFile "C:\LabFiles\cosmosdblinkedservice.json"

#uploding notebooks to Synapse
Set-AzSynapseNotebook -WorkspaceName $synapseworkspaceName -DefinitionFile "C:\LabFiles\00_preparedata.ipynb"
Set-AzSynapseNotebook -WorkspaceName $synapseworkspaceName -DefinitionFile "C:\LabFiles\01_train_diabetes_readmission_automl.ipynb"

#set and run pipeline to  run notebooks
Set-AzSynapsePipeline -WorkspaceName $synapseworkspaceName -Name "Pipeline 1" -DefinitionFile  "C:\LabFiles\Pipeline 1.json"
Invoke-AzSynapsePipeline -WorkspaceName $synapseworkspaceName -PipelineName "Pipeline 1"

sleep 2100

##Replace variables of 2 and 3 rd notebooks
az login -u "enter_uname" -p "enter_pssword"
az extension add --name azure-cli-ml
az configure --defaults group=$rgName
az ml experiment list -w $mlaccountname
$a = az ml experiment list -w $mlaccountname --query "[].name" -o tsv
$b = az ml run list -w $mlaccountname --experiment-name $a --query "[].run_id" -o tsv

#kubernetes details
$kub= Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.ContainerService/managedClusters"
$kubaccountname = $kub| Where-Object { $_.Name -like 'k8*' }
$kubaccountName = $kubaccountname.Name

#speech service key
$speechkey = az cognitiveservices account keys list --name $speechaccName -g $rgName
$speechprimarykey = $speechkey[1].Substring(11)
$speechendkey = $speechprimarykey.Substring(0, $speechprimarykey.Length - 2)

#cosmosdb name
$cosmosdb= Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.DocumentDB/databaseAccounts"
$cosmosdbaccountname = $cosmosdb| Where-Object { $_.Name -like 'cosmosdb*' }
$accountName = $cosmosdbaccountname.Name

#container registry details
$containerreg= Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.ContainerRegistry/registries"
$containerregname = $containerreg| Where-Object { $_.Name -like '*' }
$contaccountName = $containerregname.Name

#third notebook
(Get-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb") | ForEach-Object {$_ -Replace "enter_data_lake_name", "$storageaccountname"} | Set-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"
(Get-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb") | ForEach-Object {$_ -Replace "enter_subscription_id", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"
(Get-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb") | ForEach-Object {$_ -Replace "enter_rg_name", "$rgName"} | Set-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"
(Get-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb") | ForEach-Object {$_ -Replace "enter_workspace_name", "$machinelearningaccname"} | Set-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"
(Get-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb") | ForEach-Object {$_ -Replace "enter_region", "$rgLocation"} | Set-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"
(Get-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb") | ForEach-Object {$_ -Replace "enter_automl_id","$b"} | Set-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"
(Get-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb") | ForEach-Object {$_ -Replace "enter_aks_target", "$kubaccountName"} | Set-Content -Path "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"

#fourth notebook
(Get-Content -Path "C:\LabFiles\03_load_predictions.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name = ''", "data_lake_account_name = '$storageaccountname'"} | Set-Content -Path "C:\LabFiles\03_load_predictions.ipynb"
(Get-Content -Path "C:\LabFiles\03_load_predictions.ipynb") | ForEach-Object {$_ -Replace "enter_subscription_id", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\03_load_predictions.ipynb"
(Get-Content -Path "C:\LabFiles\03_load_predictions.ipynb") | ForEach-Object {$_ -Replace "enter_rg_name", "$rgName"} | Set-Content -Path "C:\LabFiles\03_load_predictions.ipynb"
(Get-Content -Path "C:\LabFiles\03_load_predictions.ipynb") | ForEach-Object {$_ -Replace "enter_workspace_name", "$machinelearningaccname"} | Set-Content -Path "C:\LabFiles\03_load_predictions.ipynb"
(Get-Content -Path "C:\LabFiles\03_load_predictions.ipynb") | ForEach-Object {$_ -Replace "enter_region", "$rgLocation"} | Set-Content -Path "C:\LabFiles\03_load_predictions.ipynb"

#Upload 2 and 3 rd notebooks
Set-AzSynapseNotebook -WorkspaceName $synapseworkspaceName -DefinitionFile "C:\LabFiles\02_deploy_AKS_diabetes_readmission_model.ipynb"
Set-AzSynapseNotebook -WorkspaceName $synapseworkspaceName -DefinitionFile "C:\LabFiles\03_load_predictions.ipynb"

#set and invoke pipeline 2 this runs 02_depoy_aks_notebook

Set-AzSynapsePipeline -WorkspaceName $synapseworkspaceName -Name "Pipeline 2" -DefinitionFile "C:\LabFiles\Pipeline 2.json"
Invoke-AzSynapsePipeline -WorkspaceName $synapseworkspaceName -PipelineName "Pipeline 2"

sleep 2400

$endpoint = az ml endpoint realtime list -w $mlaccountname --query "[].scoringUri" -o tsv
$endkey = az ml endpoint realtime get-keys -n "diabetes-readmission-service-aks" -w $mlaccountname 
$primarykey = $endkey[1].Substring(17)
$endkey = $primarykey.Substring(0, $primarykey.Length - 2)


#container registry details
$containerreg= Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.ContainerRegistry/registries"
$containerregname = $containerreg| Where-Object { $_.Name -like '*' }
$contaccountName = $containerregname.Name


#Replace deployment script variables

(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace "enter_user_name", $AzureUserName} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace "enter_password", $AzurePassword} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace "enter_sub_id", $AzureSubscriptionID} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace "enter_rg_name", $rgName} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace  "enter_container_registy_name", $contaccountName} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace  "enter_kunernetes_name", $kubaccountname} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace  "enter_cosmosdb_name", $accountName} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace  "enter_speech_sub_key", $speechendkey} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace  "enter_speech_region", $speecglocation} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace  "enter_ml_service_url", $endpoint} | Set-Content -Path "C:\LabFiles\deployapp.ps1"
(Get-Content -Path "C:\LabFiles\deployapp.ps1") | ForEach-Object {$_ -Replace  "enter_ml_bearertoken", $endkey} | Set-Content -Path "C:\LabFiles\deployapp.ps1"

Start-Service *docker*

#execute deployment script
cd C:\LabFiles

.\deployapp.ps1

#execute pipeline 3 this run 
Set-AzSynapsePipeline -WorkspaceName $synapseworkspaceName -Name "Pipeline 3" -DefinitionFile "C:\LabFiles\Pipeline 3.json"
Invoke-AzSynapsePipeline -WorkspaceName $synapseworkspaceName -PipelineName "Pipeline 3"

sleep 600

cd 'C:\LabFiles\'

.\validate.ps1


#Import Common Functions
$commonscriptpath = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.12\Downloads\0\cloudlabs-common\cloudlabs-windows-functions.ps1"
. $commonscriptpath

sleep 3
#Start the cloudlabs agent service 
CloudlabsManualAgent Start


Unregister-ScheduledTask -TaskName "Setup1" -Confirm:$false 
Restart-Computer -Force 


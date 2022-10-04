$InformationPreference = "Continue"

cd 'C:\LabFiles\'

#Remove-Module solliance-synapse-automation
Import-Module ".\validationscript.psm1"
. C:\LabFiles\AzureCreds.ps1


        $userName = $AzureUserName                # READ FROM FILE
        $password = $AzurePassword                # READ FROM FILE
        $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"       # READ FROM FILE
        $global:sqlPassword = "password.1!!"      # READ FROM FILE
        $uniqueId = $DeploymentID
        
        $securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
        $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword
        
        Connect-AzAccount -Credential $cred | Out-Null
       
        $global:logindomain = (Get-AzContext).Tenant.Id
        $ropcBodyCore = "client_id=$($clientId)&username=$($userName)&password=$($password)&grant_type=password"
        $global:ropcBodySynapse = "$($ropcBodyCore)&scope=https://dev.azuresynapse.net/.default"
        $global:ropcBodyManagement = "$($ropcBodyCore)&scope=https://management.azure.com/.default"
        $global:ropcBodySynapseSQL = "$($ropcBodyCore)&scope=https://sql.azuresynapse.net/.default"
        $global:ropcBodyPowerBI = "$($ropcBodyCore)&scope=https://analysis.windows.net/powerbi/api/.default"

        $artifactsPath = "..\..\"
        $reportsPath = "..\reports"
        $templatesPath = "..\templates"
        $datasetsPath = "..\datasets"
        $dataflowsPath = "..\dataflows"
        $pipelinesPath = "..\pipelines"
        $sqlScriptsPath = "..\sql"

$rgName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*many-model*" -and  $_.ResourceGroupName -notlike "MC_many-models*" }).ResourceGroupName
$subscriptionId = (Get-AzContext).Subscription.Id
$tenantId = (Get-AzContext).Tenant.Id
$global:logindomain = (Get-AzContext).Tenant.Id;

#speech service account name and key
$workspaceName= Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Synapse/workspaces"
$workspaceName = $workspaceName| Where-Object { $_.Name -like '*' }
$workspaceName = $workspaceName.Name

$dataLakeAccountName = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Storage/storageAccounts"
$dataLakeAccountName = $dataLakeAccountName | Where-Object { $_.Name -like 'pati*' }
$dataLakeAccountName = $dataLakeAccountName.Name


$id = (Get-AzADServicePrincipal -DisplayName $workspaceName).id
$id3 = $userName

$machinelearningAccount = Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.MachineLearningServices/workspaces"
$machinelearningName = $machinelearningAccount | Where-Object { $_.Name -like 'ml*' }
$asamlworkspace = $machinelearningName.Name

$integrationRuntimeName = "AutoResolveIntegrationRuntime"
$sparkPoolName = "spark1"
$global:sqlEndpoint = "$($workspaceName).sql.azuresynapse.net"
$global:sqlUser = "asa.sql.admin"


$global:synapseToken = ""
$global:synapseSQLToken = ""
$global:managementToken = ""
$global:powerbiToken = "";

$global:tokenTimes = [ordered]@{
        Synapse = (Get-Date -Year 1)
        SynapseSQL = (Get-Date -Year 1)
        Management = (Get-Date -Year 1)
        PowerBI = (Get-Date -Year 1)
}


$overallStateIsValid = $true


$asaArtifacts = [ordered]@{
        "patientHubDB" = @{
                Category = "linkedServices"
                Valid = $false
        }
        
    
        
}

foreach ($asaArtifactName in $asaArtifacts.Keys) {
        
                Write-Information "Checking $($asaArtifactName) in $($asaArtifacts[$asaArtifactName]["Category"])"
                $result = Get-AzSynapseLinkedService -WorkspaceName $workspaceName -Name $asaArtifactName
                if( $result -eq $null){
                Write-Warning "Not found!"
                $overallStateIsValid = $false
                

                }else{
                 Write-Information "OK"
                }
                }

#Check spark pool 

Write-Information "Checking Spark pool $($sparkPoolName)"
$sparkPool = Get-SparkPool -SubscriptionId $subscriptionId -ResourceGroupName $rgName -WorkspaceName $workspaceName -SparkPoolName $sparkPoolName
if ($sparkPool -eq $null) {
        Write-Warning "    The Spark pool $($sparkPoolName) was not found"
        $overallStateIsValid = $false
} else {
        Write-Information "OK"
}


### check aml role
Write-Information "Checking aml role"

$amlrole = Get-AzRoleAssignment -ObjectId $id -RoleDefinitionName "Contributor" -Scope "/subscriptions/$SubscriptionId/resourceGroups/$rgname/providers/Microsoft.MachineLearningServices/workspaces/$asamlworkspace"

if ($amlrole -eq $null) {



        Write-Warning "The aml role is not applied"
        $overallStateIsValid = $false



} else {

        Write-Information "OK"
        
}


### check storage blob data role
Write-Information "Checking asastorage role"
$asastoragerole = Get-AzRoleAssignment -ObjectId $id -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$SubscriptionId/resourceGroups/$rgname/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName"

if ($asastoragerole -eq $null) {

       Write-Warning "The asastorage role is not applied"
        $overallStateIsValid = $false

} else {

        Write-Information "OK"
        

}
$pipelineresult= Query-pipeline -WorkspaceName $workspaceName

         $ExpectedPipelineName = (
            'Pipeline 1', 

            'Pipeline 2',

            'Pipeline 3'

    )
    $count = 0

    $pipelineresult.value | ForEach-Object -Process {
    
   
        if ( ($_.status -eq "Succeeded") -and ($ExpectedPipelineName -contains $_.pipelineName ) ) {

            Write-Output " " $workspacename $_.pipelineName  $_.status
            $count = $count + 1; 
    
        } 
        else{

            Write-Output " " $workspacename $_.pipelineName  $_.status
           $overallStateIsValid = $false
      
        }

    }
     if ($pipelineresult.value.Count -eq 0 ){
         $overallStateIsValid = $false
 
    }   
     elseif (($count -ne 3) -and ($pipelinesstatus -eq "Failed")){
         $overallStateIsValid = $false

    }
    else{
       Write-Information "Pipeline runs ok"
    } 

$appointment= kubectl get service/appointment -o jsonpath="{.status.loadBalancer.ingress[0].ip}" -n patienthub
$batchinference = kubectl get service/batchinference -o jsonpath="{.status.loadBalancer.ingress[0].ip}" -n patienthub
$patient= kubectl get service/patient -o jsonpath="{.status.loadBalancer.ingress[0].ip}" -n patienthub
$realtimeinference= kubectl get service/realtimeinference -o jsonpath="{.status.loadBalancer.ingress[0].ip}" -n patienthub
$tts = kubectl get service/tts -o jsonpath="{.status.loadBalancer.ingress[0].ip}" -n patienthub

if ( $appointment -eq $null)
{
Write-Warning "Not found!"
$overallStateIsValid = $false
}
else
{
Write-Information "OK"
}

if ( $batchinference -eq $null)
{
Write-Warning "Not found!"
$overallStateIsValid = $false
}
else
{
Write-Information "OK"
}

if ( $patient -eq $null)
{
Write-Warning "Not found!"
$overallStateIsValid = $false
}
else
{
Write-Information "OK"
}               

if ( $realtimeinference -eq $null)
{
Write-Warning "Not found!"
$overallStateIsValid = $false
}
else
{
Write-Information "OK"
} 

if ( $tts -eq $null)
{
Write-Warning "Not found!"
$overallStateIsValid = $false
}
else
{
Write-Information "OK"
}    


if ($overallStateIsValid -eq $true) {
    Write-Information "Validation Passed"
    
    $validstatus = "Successfull"
    
}
else {
    Write-Warning "Validation Failed - see log output"
    $validstatus = "Failed"
}

Function SetDeploymentStatus($ManualStepStatus, $ManualStepMessage)
{

    (Get-Content -Path "C:\WindowsAzure\Logs\status-sample.txt") | ForEach-Object {$_ -Replace "ReplaceStatus", "$ManualStepStatus"} | Set-Content -Path "C:\WindowsAzure\Logs\validationstatus.txt"
    (Get-Content -Path "C:\WindowsAzure\Logs\validationstatus.txt") | ForEach-Object {$_ -Replace "ReplaceMessage", "$ManualStepMessage"} | Set-Content -Path "C:\WindowsAzure\Logs\validationstatus.txt"
}
 if ($validstatus -eq "Successfull") {
    $ValidStatus="Succeeded"
    $ValidMessage="Environment is validated and the deployment is successful"
    
Remove-Item 'C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt' -force
      }
else {
    Write-Warning "Validation Failed - see log output"
    $ValidStatus="Failed"
    $ValidMessage="Environment Validation Failed and the deployment is Failed"
      } 
 SetDeploymentStatus $ValidStatus $ValidMessage


sleep 10

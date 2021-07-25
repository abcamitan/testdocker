PARAM (
    [Parameter(Mandatory=$true)][string] $SubscriptionId,
    [Parameter(Mandatory=$true)][string] $ResourceGroupName,
    [Parameter(Mandatory=$true)][string] $Location,
    [Parameter(Mandatory=$true)][string] $ImageTag,
    [Parameter(Mandatory=$true)][string] $ImageVersion,
    [string] $AcrTemplatePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Item $PSScriptRoot).parent "ARM\AzureContainer\azuredeploy.json")),
    [string] $AcrTemplateParameterPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Item $PSScriptRoot).parent "ARM\AzureContainer\azuredeploy.parameters.json")),
    [string] $DeployTemplatePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Item $PSScriptRoot).parent "ARM\DeployImage\azuredeploy.json")),
    [string] $AppId = $Env:application_id,
    [string] $Password = $Env:application_password,
    [string] $TenantId = $Env:tenant_id
)

Write-Host "AcrTemplatePath [$($AcrTemplatePath)]"
Write-Host "AcrTemplateParameterPath [$($AcrTemplateParameterPath)]"
Write-Host "DeployTemplatePath [$($DeployTemplatePath)]"

az login --service-principal `
    --username $AppId `
    --password $Password `
    --tenant $TenantId

$isResourceGroupExist = az group exists `
                            --name $ResourceGroupName `
                            --subscription $SubscriptionId
if ($isResourceGroupExist -eq $false)
{
    az group create --name $ResourceGroupName `
        --location $Location `
        --subscription $SubscriptionId
}

az deployment group create --resource-group $ResourceGroupName `
    --template-file $AcrTemplatePath `
    --parameters @$AcrTemplateParameterPath


# Deploy/Push image
$paramJson = Get-Content "$AcrTemplateParameterPath" | Out-String | ConvertFrom-Json  

$acrName = $paramJson.parameters.acrName.value
$acrServer = "$($acrName).azurecr.io"
$acrTag = "$acrServer/$($ImageTag):$ImageVersion"

az acr login --name $acrName

dotnet dev-certs https -ep $env:USERPROFILE\.aspnet\https\aspnetapp.pfx -p { $Password }
dotnet dev-certs https --trust


docker build -t $ImageTag .
docker tag $ImageTag $acrTag
docker push $acrTag

$containerName = "$($ImageTag)ctnrgrp"
az deployment group create --resource-group $ResourceGroupName `
    --template-file $DeployTemplatePath `
    --parameters containerName=$containerName location="$Location" imageName=$acrTag imageRegistryLoginServer=$acrServer imageUsername=$AppId imagePassword=$Password

$ipAddress = az container show `
    --name $containerName `
    --resource-group $ResourceGroupName `
    --query ipAddress.ip `
    --output tsv

write-output "Host: [http://$ipAddress]"    
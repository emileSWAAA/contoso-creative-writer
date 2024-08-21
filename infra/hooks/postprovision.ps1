#!/usr/bin/env pwsh

Write-Output  "Building creativeagentapi:latest..."
az login --use-device-code
az acr build --subscription $env:AZURE_SUBSCRIPTION_ID --registry $env:AZURE_CONTAINER_REGISTRY_NAME --image creativeagentapi:latest ./src/
$image_name = $env:AZURE_CONTAINER_REGISTRY_NAME + '.azurecr.io/creativeagentapi:latest'
az containerapp update --subscription $env:AZURE_SUBSCRIPTION_ID --name $env:SERVICE_ACA_NAME --resource-group $env:AZURE_RESOURCE_GROUP --image $image_name
az containerapp ingress update --subscription $env:AZURE_SUBSCRIPTION_ID --name $env:SERVICE_ACA_NAME --resource-group $env:AZURE_RESOURCE_GROUP --target-port 5000

Write-Host "Starting postprovisioning..."

# Retrieve service names, resource group name, and other values from environment variables
$resourceGroupName = $env:AZURE_RESOURCE_GROUP
Write-Host "resourceGroupName: $resourceGroupName"

$openAiService = $env:AZURE_OPENAI_NAME
Write-Host "openAiService: $openAiService"

$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
Write-Host "subscriptionId: $subscriptionId"

$azureSearchEndpoint = $env:AZURE_SEARCH_ENDPOINT
Write-Host "azureSearchEndpoint: $azureSearchEndpoint"

# Ensure all required environment variables are set
if ([string]::IsNullOrEmpty($resourceGroupName) -or [string]::IsNullOrEmpty($openAiService) -or [string]::IsNullOrEmpty($subscriptionId)) {
    Write-Host "One or more required environment variables are not set."
    Write-Host "Ensure that AZURE_RESOURCE_GROUP, AZURE_OPENAI_NAME, AZURE_SUBSCRIPTION_ID are set."
    exit 1
}

# Set additional environment variables expected by app 
# TODO: Standardize these and remove need for setting here
azd env set AZURE_OPENAI_API_VERSION 2023-03-15-preview
azd env set AZURE_OPENAI_CHAT_DEPLOYMENT gpt-35-turbo
azd env set AZURE_SEARCH_ENDPOINT $AZURE_SEARCH_ENDPOINT

# Output environment variables to .env file using azd env get-values
azd env get-values > .env
Write-Host "Script execution completed successfully."

Write-Host 'Installing dependencies from "requirements.txt"'
python -m pip install -r ./requirements.txt > $null

# populate data
Write-Host "Populating data ...."
jupyter nbconvert --execute --to python --ExecutePreprocessor.timeout=-1 data/create-azure-search.ipynb > $null
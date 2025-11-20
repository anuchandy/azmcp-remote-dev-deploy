#!/usr/bin/env pwsh
#Requires -Version 7

$ErrorActionPreference = 'Stop'

$LOCAL_IMAGE = azd env get-value LOCAL_DOCKER_IMAGE

if ([string]::IsNullOrWhiteSpace($LOCAL_IMAGE)) {
    Write-Host "ERROR: LOCAL_DOCKER_IMAGE not found in azd environment" -ForegroundColor Red
    exit 1
}

Write-Host "Local Docker image: $LOCAL_IMAGE" -ForegroundColor Gray

$ACR_NAME = azd env get-value ACR_NAME
$ACR_LOGIN_SERVER = azd env get-value ACR_LOGIN_SERVER

if ([string]::IsNullOrWhiteSpace($ACR_NAME) -or [string]::IsNullOrWhiteSpace($ACR_LOGIN_SERVER)) {
    Write-Host "ERROR: ACR_NAME or ACR_LOGIN_SERVER not found in azd environment" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "ACR Name: $ACR_NAME" -ForegroundColor Gray
Write-Host "ACR Login Server: $ACR_LOGIN_SERVER" -ForegroundColor Gray

Write-Host ""
az acr login --name $ACR_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to login to ACR" -ForegroundColor Red
    exit 1
}

$ACR_IMAGE = "$ACR_LOGIN_SERVER/azure-mcp:latest"
Write-Host ""
Write-Host "Tagging and pushing image to ACR..." -ForegroundColor Yellow
Write-Host "  Local: $LOCAL_IMAGE" -ForegroundColor Gray
Write-Host "  ACR:   $ACR_IMAGE" -ForegroundColor Gray

docker tag $LOCAL_IMAGE $ACR_IMAGE

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to tag Docker image" -ForegroundColor Red
    exit 1
}

Write-Host ""
docker push $ACR_IMAGE

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to push Docker image to ACR" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Local azmcp linux-x64 Docker image pushed to ACR: $ACR_IMAGE" -ForegroundColor Cyan

azd env set ACR_IMAGE $ACR_IMAGE

Write-Host ""

$AZURE_RESOURCE_GROUP = azd env get-value AZURE_RESOURCE_GROUP
$AZURE_LOCATION = azd env get-value AZURE_LOCATION
$CONTAINER_APP_NAME = azd env get-value CONTAINER_APP_NAME
$ENTRA_APP_CLIENT_ID = azd env get-value ENTRA_APP_CLIENT_ID
$AZURE_TENANT_ID = azd env get-value AZURE_TENANT_ID
$APP_INSIGHTS_CONNECTION_STRING = azd env get-value APPLICATION_INSIGHTS_CONNECTION_STRING
$OUTGOING_AUTH_STRATEGY = azd env get-value OUTGOING_AUTH_STRATEGY
$NAMESPACES_JSON = azd env get-value NAMESPACES

if ([string]::IsNullOrWhiteSpace($CONTAINER_APP_NAME)) {
    Write-Host "ERROR: CONTAINER_APP_NAME not found in azd environment" -ForegroundColor Red
    exit 1
}

Write-Host "Deploying Container App: $CONTAINER_APP_NAME" -ForegroundColor Gray
Write-Host ""

Write-Host "Deploying/Updating Container App..." -ForegroundColor Yellow

$ACA_BICEP_PATH = Join-Path $PSScriptRoot "../container-app.bicep"

$deployment = az deployment group create `
    --resource-group $AZURE_RESOURCE_GROUP `
    --template-file $ACA_BICEP_PATH `
    --parameters containerAppName=$CONTAINER_APP_NAME `
    --parameters acrLoginServer=$ACR_LOGIN_SERVER `
    --parameters acrImage=$ACR_IMAGE `
    --parameters azureAdTenantId=$AZURE_TENANT_ID `
    --parameters azureAdClientId=$ENTRA_APP_CLIENT_ID `
    --parameters appInsightsConnectionString=$APP_INSIGHTS_CONNECTION_STRING `
    --parameters outgoingAuthStrategy=$OUTGOING_AUTH_STRATEGY `
    --parameters namespaces=$NAMESPACES_JSON `
    --parameters location=$AZURE_LOCATION `
    --query 'properties.outputs' `
    -o json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to deploy Container App" -ForegroundColor Red
    exit 1
}

$CONTAINER_APP_URL = $deployment.containerAppUrl.value
$CONTAINER_APP_PRINCIPAL_ID = $deployment.containerAppPrincipalId.value

azd env set CONTAINER_APP_URL $CONTAINER_APP_URL
azd env set CONTAINER_APP_PRINCIPAL_ID $CONTAINER_APP_PRINCIPAL_ID
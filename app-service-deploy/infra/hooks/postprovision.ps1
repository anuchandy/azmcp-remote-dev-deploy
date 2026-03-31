#!/usr/bin/env pwsh
#Requires -Version 7

$ErrorActionPreference = 'Stop'

$DEPLOY_ZIP_PATH = azd env get-value DEPLOY_ZIP_PATH

if ([string]::IsNullOrWhiteSpace($DEPLOY_ZIP_PATH)) {
    Write-Host "ERROR: DEPLOY_ZIP_PATH not found in azd environment" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $DEPLOY_ZIP_PATH)) {
    Write-Host "ERROR: Deployment zip not found at $DEPLOY_ZIP_PATH" -ForegroundColor Red
    exit 1
}

Write-Host "Deployment zip: $DEPLOY_ZIP_PATH" -ForegroundColor Gray

$AZURE_RESOURCE_GROUP = azd env get-value AZURE_RESOURCE_GROUP
$AZURE_LOCATION = azd env get-value AZURE_LOCATION
$APP_SERVICE_NAME = azd env get-value APP_SERVICE_NAME
$AZURE_TENANT_ID = azd env get-value AZURE_TENANT_ID
$APP_INSIGHTS_CONNECTION_STRING = azd env get-value APPLICATION_INSIGHTS_CONNECTION_STRING
$OUTGOING_AUTH_STRATEGY = azd env get-value OUTGOING_AUTH_STRATEGY

if ($OUTGOING_AUTH_STRATEGY -eq 'UseOnBehalfOf') {
    $ENTRA_APP_CLIENT_ID = azd env get-value ENTRA_APP_OBO_SERVER_ID
} else {
    $ENTRA_APP_CLIENT_ID = azd env get-value ENTRA_APP_CLIENT_ID
}
$NAMESPACES_JSON = azd env get-value NAMESPACES

if ([string]::IsNullOrWhiteSpace($APP_SERVICE_NAME)) {
    Write-Host "ERROR: APP_SERVICE_NAME not found in azd environment" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deploying App Service: $APP_SERVICE_NAME" -ForegroundColor Gray

# Deploy the App Service infrastructure
Write-Host ""
Write-Host "Deploying/Updating App Service infrastructure..." -ForegroundColor Yellow

$APP_SERVICE_BICEP_PATH = Join-Path $PSScriptRoot "../app-service.bicep"

$deployParams = @(
    "--resource-group", $AZURE_RESOURCE_GROUP,
    "--template-file", $APP_SERVICE_BICEP_PATH,
    "--parameters", "appServiceName=$APP_SERVICE_NAME",
    "--parameters", "azureAdTenantId=$AZURE_TENANT_ID",
    "--parameters", "azureAdClientId=$ENTRA_APP_CLIENT_ID",
    "--parameters", "appInsightsConnectionString=$APP_INSIGHTS_CONNECTION_STRING",
    "--parameters", "outgoingAuthStrategy=$OUTGOING_AUTH_STRATEGY",
    "--parameters", "namespaces=$NAMESPACES_JSON",
    "--parameters", "location=$AZURE_LOCATION",
    "--query", "properties.outputs",
    "-o", "json"
)

if ($OUTGOING_AUTH_STRATEGY -eq 'UseOnBehalfOf') {
    $MANAGED_IDENTITY_CLIENT_ID = azd env get-value MANAGED_IDENTITY_CLIENT_ID
    $MANAGED_IDENTITY_ID = azd env get-value MANAGED_IDENTITY_ID
    $TOKEN_EXCHANGE_AUDIENCE = azd env get-value TOKEN_EXCHANGE_AUDIENCE

    $deployParams += @(
        "--parameters", "userAssignedManagedIdentityClientId=$MANAGED_IDENTITY_CLIENT_ID",
        "--parameters", "userAssignedManagedIdentityId=$MANAGED_IDENTITY_ID",
        "--parameters", "tokenExchangeAudience=$TOKEN_EXCHANGE_AUDIENCE"
    )
}

$deployment = az deployment group create @deployParams | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to deploy App Service infrastructure" -ForegroundColor Red
    exit 1
}

$APP_SERVICE_URL = $deployment.appServiceUrl.value
$APP_SERVICE_PRINCIPAL_ID = $deployment.appServicePrincipalId.value

# Zip deploy the application
Write-Host ""
Write-Host "Deploying application via zip deploy..." -ForegroundColor Yellow

az webapp deploy `
    --resource-group $AZURE_RESOURCE_GROUP `
    --name $APP_SERVICE_NAME `
    --src-path $DEPLOY_ZIP_PATH `
    --type zip `
    --clean true

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to deploy application to App Service" -ForegroundColor Red
    exit 1
}

azd env set APP_SERVICE_URL $APP_SERVICE_URL
if (-not [string]::IsNullOrWhiteSpace($APP_SERVICE_PRINCIPAL_ID)) {
    azd env set APP_SERVICE_PRINCIPAL_ID $APP_SERVICE_PRINCIPAL_ID
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "App Service URL: $APP_SERVICE_URL" -ForegroundColor Cyan

if ($OUTGOING_AUTH_STRATEGY -eq 'UseOnBehalfOf') {
    $SERVER_APP_ID = azd env get-value ENTRA_APP_OBO_SERVER_ID
    Write-Host ""
    Write-Host "OBO: Grant admin consent for Azure Resource Manager and Storage user_impersonation:" -ForegroundColor Yellow
    Write-Host "  az ad app permission admin-consent --id $SERVER_APP_ID" -ForegroundColor White
}

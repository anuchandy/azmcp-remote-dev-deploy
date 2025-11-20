@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Azure Container App')
param acaName string

@description('Display name for the Entra App')
param entraAppDisplayName string

@description('Application Insights connection string. Use "DISABLED" to disable telemetry, or provide existing connection string. If omitted, new App Insights will be created.')
param appInsightsConnectionString string = ''

@description('Outgoing authentication strategy for Azure service requests')
@allowed([
  'UseHostingEnvironmentIdentity'
  'UseOnBehalfOf'
])
param outgoingAuthStrategy string = 'UseHostingEnvironmentIdentity'

@description('Build configuration for the code build (Debug or Release)')
@allowed([
  'Debug'
  'Release'
])
param buildConfiguration string = 'Release'

@description('MCP namespaces to enable (leave empty for all namespaces)')
param namespaces array = []

// Deploy Application Insights if appInsightsConnectionString is empty and not DISABLED
var appInsightsName = '${acaName}-insights'
//
module appInsights 'modules/application-insights.bicep' = {
  name: 'application-insights-deployment'
  params: {
    appInsightsConnectionString: appInsightsConnectionString
    name: appInsightsName
    location: location
  }
}

// Deploy Entra App
var entraAppUniqueName = '${replace(toLower(entraAppDisplayName), ' ', '-')}-${uniqueString(resourceGroup().id)}'
var entraAppTag = 'RG:${resourceGroup().name}'
//
module entraApp 'modules/entra-app.bicep' = {
  name: 'entra-app-deployment'
  params: {
    entraAppDisplayName: entraAppDisplayName
    entraAppUniqueName: entraAppUniqueName
    entraAppTag: entraAppTag
  }
}

// Deploy Azure Container Registry
var acrName = 'acr${toLower(replace(acaName, '-', ''))}${uniqueString(resourceGroup().id)}'
//
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry-deployment'
  params: {
    name: acrName
    location: location
    sku: 'Basic'
    adminUserEnabled: true
  }
}

// Outputs for azd and other consumers
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output AZURE_LOCATION string = location

// Entra App outputs
output ENTRA_APP_CLIENT_ID string = entraApp.outputs.entraAppClientId
output ENTRA_APP_OBJECT_ID string = entraApp.outputs.entraAppObjectId
output ENTRA_APP_SERVICE_PRINCIPAL_ID string = entraApp.outputs.entraAppServicePrincipalObjectId
// output ENTRA_APP_ROLE_ID string = entraApp.outputs.entraAppRoleId
output ENTRA_APP_IDENTIFIER_URI string = entraApp.outputs.entraAppIdentifierUri

// Application Insights outputs
output APPLICATION_INSIGHTS_NAME string = appInsightsName
output APPLICATION_INSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString
output AZURE_MCP_COLLECT_TELEMETRY string = string(!empty(appInsights.outputs.connectionString))

// ACR outputs
output ACR_NAME string = containerRegistry.outputs.registryName
output ACR_LOGIN_SERVER string = containerRegistry.outputs.registryLoginServer
output ACR_ID string = containerRegistry.outputs.registryId

// Container App name and outgoing authentication strategy (for postprovision hook)
output CONTAINER_APP_NAME string = acaName
output OUTGOING_AUTH_STRATEGY string = outgoingAuthStrategy
output BUILD_CONFIGURATION string = buildConfiguration
output NAMESPACES string = string(namespaces)

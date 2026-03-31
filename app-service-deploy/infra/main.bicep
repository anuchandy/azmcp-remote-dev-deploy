@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Azure App Service')
param appServiceName string

@description('Display name for the Server Entra App')
param entraAppDisplayName string

@description('Display name for the Client Entra App (OBO only)')
param entraAppClientDisplayName string = ''

@description('Service Management Reference GUID for the Entra Applications. Optional.')
param serviceManagementReference string = ''

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
var appInsightsName = '${appServiceName}-insights'
//
module appInsights 'modules/application-insights.bicep' = {
  name: 'application-insights-deployment'
  params: {
    appInsightsConnectionString: appInsightsConnectionString
    name: appInsightsName
    location: location
  }
}

// Derive FIC token exchange audience based on the target cloud (sovereign cloud support)
var tokenExchangeAudience = environment().name == 'AzureUSGovernment'
  ? 'api://AzureADTokenExchangeUSGov'
  : environment().name == 'AzureChinaCloud'
    ? 'api://AzureADTokenExchangeChina'
    : 'api://AzureADTokenExchange'

var isObo = outgoingAuthStrategy == 'UseOnBehalfOf'

var entraAppUniqueName = '${replace(toLower(entraAppDisplayName), ' ', '-')}-${uniqueString(resourceGroup().id)}'
var entraAppTag = 'RG:${resourceGroup().name}'

// Deploy Entra App (UseHostingEnvironmentIdentity)
module entraAppServer 'modules/entra-app-hostingenvidentity.bicep' = if (!isObo) {
  name: 'entra-app-deployment'
  params: {
    entraAppDisplayName: entraAppDisplayName
    entraAppUniqueName: entraAppUniqueName
    entraAppTag: entraAppTag
  }
}

// Deploy User Assigned Managed Identity (OBO only)
module managedIdentity 'modules/obo-managed-identity.bicep' = if (isObo) {
  name: 'managed-identity-deployment'
  params: {
    location: location
    managedIdentityName: '${appServiceName}-managed-identity'
  }
}

// Deploy OBO Client Entra App (OBO only)
var entraAppClientUniqueName = '${replace(toLower(entraAppClientDisplayName), ' ', '-')}-${uniqueString(resourceGroup().id)}'
module entraAppOboClient 'modules/entra-app-obo-client.bicep' = if (isObo) {
  name: 'entra-app-obo-client-deployment'
  params: {
    entraAppDisplayName: entraAppClientDisplayName
    entraAppUniqueName: entraAppClientUniqueName
    serviceManagementReference: serviceManagementReference
  }
}

// Deploy OBO Server Entra App (OBO only)
module entraAppOboServer 'modules/entra-app-obo-server.bicep' = if (isObo) {
  name: 'entra-app-obo-server-deployment'
  params: {
    entraAppDisplayName: entraAppDisplayName
    entraAppUniqueName: entraAppUniqueName
    knownClientAppId: entraAppOboClient.outputs.entraAppClientId
    acaManagedIdentityObjectId: managedIdentity.outputs.managedIdentityPrincipalId
    tokenExchangeAudience: tokenExchangeAudience
    serviceManagementReference: serviceManagementReference
  }
}

// Outputs for azd and other consumers
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output AZURE_LOCATION string = location

// Hosting Environment Identity outputs (empty when UseOnBehalfOf)
output ENTRA_APP_CLIENT_ID string = !isObo ? entraAppServer.outputs.entraAppClientId : ''
output ENTRA_APP_OBJECT_ID string = !isObo ? entraAppServer.outputs.entraAppObjectId : ''
output ENTRA_APP_SERVICE_PRINCIPAL_ID string = !isObo ? entraAppServer.outputs.entraAppServicePrincipalObjectId : ''
output ENTRA_APP_IDENTIFIER_URI string = !isObo ? entraAppServer.outputs.entraAppIdentifierUri : ''

// OBO outputs (empty when not UseOnBehalfOf)
output ENTRA_APP_OBO_SERVER_ID string = isObo ? entraAppOboServer.outputs.entraAppClientId : ''
output ENTRA_APP_OBO_SERVER_OBJECT_ID string = isObo ? entraAppOboServer.outputs.entraAppObjectId : ''
output ENTRA_APP_OBO_SERVER_IDENTIFIER_URI string = isObo ? entraAppOboServer.outputs.entraAppIdentifierUri : ''
output ENTRA_APP_OBO_CLIENT_ID string = isObo ? entraAppOboClient.outputs.entraAppClientId : ''
output ENTRA_APP_OBO_SCOPE_ID string = isObo ? entraAppOboServer.outputs.entraAppScopeId : ''
output ENTRA_APP_OBO_SCOPE_VALUE string = isObo ? entraAppOboServer.outputs.entraAppScopeValue : ''
output MANAGED_IDENTITY_CLIENT_ID string = isObo ? managedIdentity.outputs.managedIdentityClientId : ''
output MANAGED_IDENTITY_ID string = isObo ? managedIdentity.outputs.managedIdentityId : ''
output TOKEN_EXCHANGE_AUDIENCE string = isObo ? tokenExchangeAudience : ''

// Application Insights outputs
output APPLICATION_INSIGHTS_NAME string = appInsightsName
output APPLICATION_INSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString
output AZURE_MCP_COLLECT_TELEMETRY string = string(!empty(appInsights.outputs.connectionString))

// App Service name and outgoing authentication strategy (for postprovision hook)
output APP_SERVICE_NAME string = appServiceName
output OUTGOING_AUTH_STRATEGY string = outgoingAuthStrategy
output BUILD_CONFIGURATION string = buildConfiguration
output NAMESPACES string = string(namespaces)

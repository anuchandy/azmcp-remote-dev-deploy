@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Azure App Service')
param appServiceName string

@description('Azure AD Tenant ID')
param azureAdTenantId string

@description('Azure AD Client ID (Entra App)')
param azureAdClientId string

@description('Application Insights connection string')
param appInsightsConnectionString string = ''

@description('Outgoing authentication strategy')
@allowed(['UseHostingEnvironmentIdentity', 'UseOnBehalfOf'])
param outgoingAuthStrategy string = 'UseHostingEnvironmentIdentity'

@description('Client ID of the user-assigned managed identity (required for OBO)')
param userAssignedManagedIdentityClientId string = ''

@description('Resource ID of the user-assigned managed identity (required for OBO)')
param userAssignedManagedIdentityId string = ''

@description('The FIC token exchange audience URI. Varies by cloud: api://AzureADTokenExchange (public), api://AzureADTokenExchangeUSGov (US Gov), api://AzureADTokenExchangeChina (China).')
param tokenExchangeAudience string = 'api://AzureADTokenExchange'

@description('Namespaces to enable (empty means all namespaces)')
param namespaces array = []

@description('App Service Plan SKU')
param planSku string = 'P1v4'

var baseArgs = [
  '--transport'
  'http'
  '--outgoing-auth-strategy'
  outgoingAuthStrategy
  '--read-only'
]
var modeArgs = !empty(namespaces) ? ['--mode', 'all'] : []
var namespaceArgsList = [for ns in namespaces: ['--namespace', ns]]
var namespaceArgs = flatten(namespaceArgsList)

var startupCommand = join(concat(['./azmcp', 'server', 'start'], baseArgs, modeArgs, namespaceArgs), ' ')

var baseAppSettings = [
  {
    name: 'AzureAd__TenantId'
    value: azureAdTenantId
  }
  {
    name: 'AzureAd__ClientId'
    value: azureAdClientId
  }
  {
    name: 'AzureAd__Instance'
    value: environment().authentication.loginEndpoint
  }
  {
    name: 'ApplicationInsights__ConnectionString'
    value: appInsightsConnectionString
  }
  {
    name: 'AZURE_MCP_COLLECT_TELEMETRY'
    value: string(!empty(appInsightsConnectionString))
  }
  {
    name: 'Logging__LogLevel__Default'
    value: 'Debug'
  }
  {
    name: 'Logging__LogLevel__Microsoft'
    value: 'Debug'
  }
  {
    name: 'Logging__LogLevel__Azure'
    value: 'Debug'
  }
  {
    name: 'AZURE_LOG_LEVEL'
    value: 'verbose'
  }
  {
    name: 'Logging__LogLevel__Microsoft.AspNetCore.Server.Kestrel'
    value: 'Information'
  }
  {
    // App Service forwards to the app on this port
    name: 'WEBSITES_PORT'
    value: '5000'
  }
  {
    name: 'ASPNETCORE_URLS'
    value: 'http://+:5000'
  }
  {
    // App Service's front-end sets X-Forwarded-Proto
    name: 'AZURE_MCP_DANGEROUSLY_ENABLE_FORWARDED_HEADERS'
    value: 'true'
  }
  {
    // App Service terminates TLS at the front-end; internal traffic to the app is HTTP
    name: 'AZURE_MCP_DANGEROUSLY_ALLOW_INSECURE_HTTP'
    value: 'true'
  }
]

var hostingEnvIdentityAppSettings = [
  {
    name: 'AZURE_TOKEN_CREDENTIALS'
    value: 'managedidentitycredential'
  }
  {
    name: 'AZURE_MCP_INCLUDE_PRODUCTION_CREDENTIALS'
    value: 'true'
  }
]

var oboAppSettings = [
  {
    name: 'AzureAd__ClientCredentials__0__SourceType'
    value: 'SignedAssertionFromManagedIdentity'
  }
  {
    name: 'AzureAd__ClientCredentials__0__ManagedIdentityClientId'
    value: userAssignedManagedIdentityClientId
  }
  {
    name: 'AzureAd__ClientCredentials__0__TokenExchangeUrl'
    value: tokenExchangeAudience
  }
]

var appSettings = outgoingAuthStrategy == 'UseHostingEnvironmentIdentity'
  ? concat(baseAppSettings, hostingEnvIdentityAppSettings)
  : concat(baseAppSettings, oboAppSettings)

// App Service Plan (Linux, Basic B1)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${appServiceName}-plan'
  location: location
  kind: 'linux'
  sku: {
    name: planSku
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// App Service (Linux, zip deploy)
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  identity: outgoingAuthStrategy == 'UseOnBehalfOf' ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedManagedIdentityId}': {}
    }
  } : {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      appCommandLine: startupCommand
      appSettings: appSettings
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      minTlsVersion: '1.2'
      healthCheckPath: '/health'
    }
  }
}

output appServiceUrl string = 'https://${webApp.properties.defaultHostName}'
output appServiceName string = webApp.name
output appServicePrincipalId string = webApp.identity.type == 'SystemAssigned' ? webApp.identity.principalId : ''

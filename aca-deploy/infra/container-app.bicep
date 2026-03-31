@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Azure Container App')
param containerAppName string

@description('ACR login server')
param acrLoginServer string

@description('Full ACR image with tag')
param acrImage string

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

@description('Deployment timestamp to force new revision')
param deploymentTimestamp string = utcNow()

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

var containerArgs = concat(baseArgs, modeArgs, namespaceArgs)

var baseEnvVars = [
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
    name: 'ASPNETCORE_URLS'
    value: 'http://+:5000'
  }
  {
    name: 'AZURE_MCP_DANGEROUSLY_ENABLE_FORWARDED_HEADERS'
    value: 'true'
  }
  {
    name: 'AZURE_MCP_DANGEROUSLY_ALLOW_INSECURE_HTTP'
    value: 'true'
  }
]

var hostingEnvIdentityEnvVars = [
  {
    name: 'AZURE_TOKEN_CREDENTIALS'
    value: 'managedidentitycredential'
  }
  {
    name: 'AZURE_MCP_INCLUDE_PRODUCTION_CREDENTIALS'
    value: 'true'
  }
]

var oboEnvVars = [
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

var containerEnvVars = outgoingAuthStrategy == 'UseHostingEnvironmentIdentity' 
  ? concat(baseEnvVars, hostingEnvIdentityEnvVars)
  : concat(baseEnvVars, oboEnvVars)

// Create Container App Environment with unique name
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${containerAppName}-env-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    appLogsConfiguration: !empty(appInsightsConnectionString) ? {
      destination: 'azure-monitor'
    } : null
  }
}

// Get ACR resource for credentials
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: split(acrLoginServer, '.')[0]
}

// Create Container App with managed identity
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
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
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
        allowInsecure: false
        transport: 'http'
      }
      registries: [
        {
          server: acrLoginServer
          username: acr.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      revisionSuffix: toLower(take(replace(replace(replace(deploymentTimestamp, ':', ''), '-', ''), 'T', ''), 12))
      containers: [
        {
          name: 'azure-mcp-server'
          image: acrImage
          command: []
          args: containerArgs
          env: containerEnvVars
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output containerAppName string = containerApp.name
output containerAppPrincipalId string = containerApp.identity.type == 'SystemAssigned' ? containerApp.identity.principalId : ''
output containerAppEnvironmentId string = containerAppEnvironment.id

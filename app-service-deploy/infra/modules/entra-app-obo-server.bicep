/*
  OBO Server Entra Application Registration

  Creates the server-side Entra app for the On-Behalf-Of (OBO) flow:
  - OAuth2 delegated permission scope for user-delegated access
  - Pre-authorized client applications (custom client app + VS Code)
  - Required resource access for Azure Resource Manager and Azure Storage data plane
  - Federated Identity Credential (FIC) linking UAMI to the server app
  - Service principal for authentication in this tenant
*/

extension microsoftGraphV1

@description('Display name for the Entra Application')
param entraAppDisplayName string

@description('Unique name for the Entra Application')
param entraAppUniqueName string

@description('Value of the app scope')
param entraAppScopeValue string = 'Mcp.Tools.ReadWrite'

@description('Display name of the app scope')
param entraAppScopeDisplayName string = 'Azure MCP Tools ReadWrite'

@description('Description of the app scope')
param entraAppScopeDescription string = 'Permission to call Azure MCP tools on behalf of the user'

@description('Client app ID to pre-authorize for delegated access')
param knownClientAppId string

@description('Object ID (principal ID) of the container app user-assigned managed identity')
param acaManagedIdentityObjectId string

@description('The FIC token exchange audience URI. Varies by cloud: api://AzureADTokenExchange (public), api://AzureADTokenExchangeUSGov (US Gov), api://AzureADTokenExchangeChina (China).')
param tokenExchangeAudience string = 'api://AzureADTokenExchange'

@description('Service Management Reference for the Entra Application. Optional GUID used to link the app to a service in Azure.')
param serviceManagementReference string = ''

// Pre-authorized applications (no consent prompt needed for these clients)
var vsCodeClientAppId = 'aebc6443-996d-45c2-90f0-388ff96faa56'

// Required Resource Access - APIs this app needs to call on behalf of the user
var azureServiceManagementApiId = '797f4846-ba00-4fd7-ba43-dac1f8f63013'
var azureServiceManagementUserImpersonationId = '41094075-9dad-400e-a0bd-54e686782033'

var azureStorageApiId = 'e406a681-f3d4-42a8-90b6-c2b029497af1'
var azureStorageUserImpersonationId = '03e0da56-190b-40ad-a80c-ea378c433f7f'

var scopeId = guid(entraAppUniqueName, entraAppScopeValue)

resource entraApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  serviceManagementReference: serviceManagementReference
  api: {
    oauth2PermissionScopes: [
      {
        id: scopeId
        type: 'User'
        adminConsentDescription: entraAppScopeDescription
        adminConsentDisplayName: entraAppScopeDisplayName
        userConsentDescription: entraAppScopeDescription
        userConsentDisplayName: entraAppScopeDisplayName
        value: entraAppScopeValue
        isEnabled: true
      }
    ]
    preAuthorizedApplications: [
      {
        appId: knownClientAppId
        delegatedPermissionIds: [scopeId]
      }
      {
        appId: vsCodeClientAppId
        delegatedPermissionIds: [scopeId]
      }
    ]
    requestedAccessTokenVersion: 2
  }
  requiredResourceAccess: [
    {
      // Azure Resource Manager API permission
      resourceAppId: azureServiceManagementApiId
      resourceAccess: [
        {
          id: azureServiceManagementUserImpersonationId
          type: 'Scope'
        }
      ]
    }
    {
      // Azure Storage data plane API permission
      resourceAppId: azureStorageApiId
      resourceAccess: [
        {
          id: azureStorageUserImpersonationId
          type: 'Scope'
        }
      ]
    }
  ]
}

// Second pass to set identifierUris (requires appId from first resource)
resource entraAppUpdate 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  serviceManagementReference: serviceManagementReference
  identifierUris: ['api://${entraApp.appId}']
  api: {
    oauth2PermissionScopes: entraApp.api.oauth2PermissionScopes
    preAuthorizedApplications: entraApp.api.preAuthorizedApplications
    requestedAccessTokenVersion: 2
  }
}

// Create service principal so the app can be used for authentication in this tenant
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: entraApp.appId
}

// Federated Identity Credential linking the UAMI to the server app registration
resource federatedIdentityCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: '${entraApp.uniqueName}/ServerClientCredential'
  audiences: [
    tokenExchangeAudience
  ]
  description: 'Client credential of Azure MCP server app registration'
  issuer: '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
  subject: acaManagedIdentityObjectId
}

output entraAppClientId string = entraApp.appId
output entraAppObjectId string = entraApp.id
output entraAppIdentifierUri string = 'api://${entraApp.appId}'
output entraAppScopeId string = scopeId
output entraAppScopeValue string = entraAppScopeValue

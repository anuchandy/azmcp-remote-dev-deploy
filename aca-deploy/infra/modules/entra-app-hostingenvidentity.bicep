extension microsoftGraphV1

@description('Display name for the Entra Application')
param entraAppDisplayName string

@description('Unique name for the Entra Application')
param entraAppUniqueName string

@description('Tag for the Entra Application')
param entraAppTag string

var orgServiceManagementReferenceId = '4405e061-966a-4249-afdd-f7435f54a510'

// OAuth2 Permission Scope (Delegated Permission) - for user-delegated access (OBO flow)
var oauth2PermissionScopeId = guid(subscription().id, 'Mcp.Tools.ReadWrite')
var oauth2PermissionScopeValue = 'Mcp.Tools.ReadWrite'
var oauth2PermissionScopeDisplayName = 'Read and Write operations'
var oauth2PermissionScopeDescription = 'Read and Write operations'

// App Roles (Application Permissions) - for service-to-service scenarios
var appRoleId = guid(subscription().id, 'Mcp.Tools.ReadWrite.All')
var appRoleValue = 'Mcp.Tools.ReadWrite.All'
var appRoleDisplayName = 'MCP All'
var appRoleDescription = 'ReadWrite'

// Pre-authorized applications (no consent prompt needed for these clients)
var azureCliAppId = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
var vsCodeAppId = 'aebc6443-996d-45c2-90f0-388ff96faa56'

// Required Resource Access - APIs this app needs to call
var azureServiceManagementApiId = '797f4846-ba00-4fd7-ba43-dac1f8f63013'
var azureServiceManagementUserImpersonationId = '41094075-9dad-400e-a0bd-54e686782033'

var azureContainerAppsSessionsApiId = '2c7dd73f-7a21-485b-b97d-a2508fa152c3'
var azureContainerAppsSessionsReadWriteId = '2843164f-ca31-473a-9198-ceaeb95e59b1'

var microsoftGraphApiId = '00000003-0000-0000-c000-000000000000'
var microsoftGraphUserReadId = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'

// Azure Storage data plane API (for blob/container operations)
var azureStorageApiId = 'e406a681-f3d4-42a8-90b6-c2b029497af1'
var azureStorageUserImpersonationId = '03e0da56-190b-40ad-a80c-ea378c433f7f'

resource entraApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraAppUniqueName 
  displayName: entraAppDisplayName
  serviceManagementReference: orgServiceManagementReferenceId
  signInAudience: 'AzureADMyOrg'
  tags: [entraAppTag]
  notes: entraAppTag
  
  // Service Principal Lock Configuration (security hardening)
  servicePrincipalLockConfiguration: {
    isEnabled: true
    allProperties: true
    credentialsWithUsageSign: true
    credentialsWithUsageVerify: true
    tokenEncryptionKeyId: true
  }
  
  // App Roles (Application Permissions)
  appRoles: [
    {
      id: appRoleId
      displayName: appRoleDisplayName
      description: appRoleDescription
      value: appRoleValue
      isEnabled: true
      allowedMemberTypes: ['Application']
    }
  ]
  
  // API configuration
  api: {
    // OAuth2 Permission Scopes (Delegated Permissions)
    oauth2PermissionScopes: [
      {
        id: oauth2PermissionScopeId
        adminConsentDescription: oauth2PermissionScopeDescription
        adminConsentDisplayName: oauth2PermissionScopeDisplayName
        isEnabled: true
        type: 'User'
        value: oauth2PermissionScopeValue
      }
    ]
    
    // Pre-authorized applications
    preAuthorizedApplications: [
      {
        appId: azureCliAppId
        delegatedPermissionIds: [oauth2PermissionScopeId]
      }
      {
        appId: vsCodeAppId
        delegatedPermissionIds: [oauth2PermissionScopeId]
      }
    ]
    
    requestedAccessTokenVersion: 2
  }
  
  // Required Resource Access - APIs this app needs to call
  requiredResourceAccess: [
    {
      resourceAppId: azureServiceManagementApiId
      resourceAccess: [
        {
          id: azureServiceManagementUserImpersonationId
          type: 'Scope'
        }
      ]
    }
    {
      resourceAppId: azureStorageApiId
      resourceAccess: [
        {
          id: azureStorageUserImpersonationId
          type: 'Scope'
        }
      ]
    }
    {
      resourceAppId: azureContainerAppsSessionsApiId
      resourceAccess: [
        {
          id: azureContainerAppsSessionsReadWriteId
          type: 'Scope'
        }
      ]
    }
    {
      resourceAppId: microsoftGraphApiId
      resourceAccess: [
        {
          id: microsoftGraphUserReadId
          type: 'Scope'
        }
      ]
    }
  ]
  
  // Web configuration
  web: {
    implicitGrantSettings: {
      enableAccessTokenIssuance: true
      enableIdTokenIssuance: true
    }
  }
}

resource entraAppUpdate 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  serviceManagementReference: entraApp.serviceManagementReference
  signInAudience: entraApp.signInAudience
  servicePrincipalLockConfiguration: entraApp.servicePrincipalLockConfiguration
  appRoles: entraApp.appRoles
  api: entraApp.api
  requiredResourceAccess: entraApp.requiredResourceAccess
  web: entraApp.web
  identifierUris: ['api://${entraApp.appId}']
}

resource entraServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: entraApp.appId
}

output entraAppClientId string = entraApp.appId
output entraAppObjectId string = entraApp.id
output entraAppIdentifierUri string = 'api://${entraApp.appId}'
output entraAppServicePrincipalObjectId string = entraServicePrincipal.id

// OAuth2 Permission Scope outputs (for delegated permissions / OBO flow)
output oauth2PermissionScopeId string = oauth2PermissionScopeId
output oauth2PermissionScopeValue string = oauth2PermissionScopeValue

// App Role outputs (for application permissions)
output appRoleId string = appRoleId
output appRoleValue string = appRoleValue

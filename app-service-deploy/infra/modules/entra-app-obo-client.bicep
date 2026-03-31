/*
  OBO Client Entra Application Registration

  Creates a public client app for testing the OBO flow with InteractiveBrowserCredential.
  This app is pre-authorized on the server app so users can acquire tokens
  via interactive browser login (http://localhost redirect).
*/

extension microsoftGraphV1

@description('Display name for the Client Entra Application')
param entraAppDisplayName string

@description('Unique name for the Client Entra Application')
param entraAppUniqueName string

@description('Service Management Reference for the Entra Application. Optional GUID used to link the app to a service in Azure.')
param serviceManagementReference string = ''

resource entraApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  serviceManagementReference: serviceManagementReference
  publicClient: {
    redirectUris: [
      'http://localhost'
    ]
  }
  isFallbackPublicClient: true
}

// Create service principal so the app can be used for authentication in this tenant
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: entraApp.appId
}

output entraAppClientId string = entraApp.appId
output entraAppObjectId string = entraApp.id

# Deploy `azmcp` dev build to ACA

The [aca-deploy](https://github.com/anuchandy/azmcp-remote-dev-deploy/tree/azmcp-obo-template-local/aca-deploy) directory contains an azd template to build the Azure MCP Server source code and deploy it as a remote HTTP service on Azure Container Apps (ACA).

## Prerequisites

1. Clone of the [microsoft/mcp](https://github.com/microsoft/mcp.git) source (with your local changes)
2. Azure subscription with **Owner** or **User Access Administrator** access
3. Dev Tools
   * **[az-cli](https://learn.microsoft.com/cli/azure/install-azure-cli)** (`az login`)
   * **[azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)** (`azd auth login`)
   * **[Docker](https://docs.docker.com/get-docker/)** (Ensure Docker daemon is running)
   * **[PowerShell 7+ (pwsh)](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)**

## Auth strategies

The template supports two outgoing authentication strategies, configured via the `outgoingAuthStrategy` parameter in `infra/main.parameters.json`:

| Strategy | Description |
|---|---|
| `UseHostingEnvironmentIdentity` (default) | The Container App's **system-assigned managed identity** authenticates to downstream Azure services.|
| `UseOnBehalfOf` | The server exchanges the calling user's token via **OBO flow** to access downstream Azure services as the user. |

## azd deploy

1. **Get azd-template** — Download [aca-deploy.zip](https://github.com/anuchandy/azmcp-remote-dev-deploy/blob/main/aca-deploy.zip), extract and copy it to the root of your local `microsoft/mcp` clone.

2. **Open azd-template in pwsh terminal**
   ```bash
   pwsh
   cd /code/mcp/aca-deploy
   ```

3. **Login az-cli**

   ```bash
   az login
   ```

3. **Login azd and run azd-template**

   ```bash
   azd init
   azd auth logout
   azd auth login
   azd up
   ```

<details>

<summary>Behind azd up:</summary>

The `azd up` command:

1. Compile the `Azure.Mcp.Server` in your local clone of `microsoft/mcp`, and build a Linux x64 musl Docker container image

2. **Provision Infra**:
   - Azure Container Registry (ACR)
   - Application Insights (unless disabled)
   - If Strategy is **UseHostingEnvironmentIdentity** then Entra ID Application for OAuth2 authentication
   - If Strategy is **UseOnBehalfOf** then User-Assigned Managed Identity for FIC, Server Entra App using FIC, and Client Entra App

3. **Deploy**:
   - Push Docker image to ACR
   - Deploy Azure Container App (ACA) using the image, with authentication and environment variables configured

</details>

## azd output

After deployment, retrieve azd outputs:

```bash
/code/mcp/aca-deploy> azd env get-values
```

<details>

<summary>Example output (UseHostingEnvironmentIdentity):</summary>

```bash
AZURE_ENV_NAME="explore-hei-env"
AZURE_LOCATION="eastus2"
AZURE_TENANT_ID="a9e6d517-32a4-4d1a-b409-e2be93fb60ad"
AZURE_SUBSCRIPTION_ID="01c2168f-b1cb-417a-ba8b-75256bc0c0f1"
AZURE_RESOURCE_GROUP="explore-hei-rg"

NAMESPACES="[\"storage\"]"
OUTGOING_AUTH_STRATEGY="UseHostingEnvironmentIdentity"

AZURE_MCP_COLLECT_TELEMETRY="False"
BUILD_CONFIGURATION="Release"

ACR_ID="/subscriptions/01c2168f-b1cb-417a-ba8b-75256bc0c0f1/resourceGroups/explore-hei-rg/providers/Microsoft.ContainerRegistry/registries/acrazmcpremoteserveraxi"
ACR_IMAGE="acrazmcpremoteserveraxi.azurecr.io/azure-mcp:latest"
ACR_LOGIN_SERVER="acrazmcpremoteserveraxi.azurecr.io"
ACR_NAME="acrazmcpremoteserveraxi"

CONTAINER_APP_NAME="azure-mcp-remote-server"
CONTAINER_APP_PRINCIPAL_ID="4e6a2296-f620-4ac8-b9d4-a740c7a67269"
CONTAINER_APP_URL="https://azure-mcp-remote-server.stranger-things.eastus2.azurecontainerapps.io"
LOCAL_DOCKER_IMAGE="azure-sdk/azure-mcp:2.0.0-alpha.99999"
APPLICATION_INSIGHTS_CONNECTION_STRING=""
APPLICATION_INSIGHTS_NAME="azure-mcp-remote-server-insights"

ENTRA_APP_CLIENT_ID="0dfbc09b-6dd8-4de3-ae48-054c806ee59f"
ENTRA_APP_IDENTIFIER_URI="api://0dfbc09b-6dd8-4de3-ae48-054c806ee59f"
ENTRA_APP_OBJECT_ID="36227e9d-8915-42bf-a6d3-3733d745ba71"
ENTRA_APP_SERVICE_PRINCIPAL_ID="92364c66-729f-4003-9fd0-111446f5ef14"

```

</details>

<details>

<summary>Example output (UseOnBehalfOf):</summary>

```bash
AZURE_ENV_NAME="explore-obo-env"
AZURE_LOCATION="eastus2"
AZURE_TENANT_ID="a9e6d517-32a4-4d1a-b409-e2be93fb60ad"
AZURE_SUBSCRIPTION_ID="01c2168f-b1cb-417a-ba8b-75256bc0c0f1"
AZURE_RESOURCE_GROUP="explore-obo-rg"

NAMESPACES="[\"storage\"]"
OUTGOING_AUTH_STRATEGY="UseOnBehalfOf"
TOKEN_EXCHANGE_AUDIENCE="api://AzureADTokenExchange"

AZURE_MCP_COLLECT_TELEMETRY="False"
BUILD_CONFIGURATION="Release"

ACR_ID="/subscriptions/01c2168f-b1cb-417a-ba8b-75256bc0c0f1/resourceGroups/explore-obo-rg/providers/Microsoft.ContainerRegistry/registries/acrazmcpremoteserveraxi"
ACR_IMAGE="acrazuremcpremoteserver<rnd>.azurecr.io/azure-mcp:latest"
ACR_LOGIN_SERVER="acrazmcpremoteserveraxi.azurecr.io"
ACR_NAME="acrazmcpremoteserveraxi"
CONTAINER_APP_NAME="azure-mcp-remote-server"
CONTAINER_APP_URL="https://azure-mcp-remote-server.stranger-things.eastus2.azurecontainerapps.io"
LOCAL_DOCKER_IMAGE="azure-sdk/azure-mcp:2.0.0-alpha.99999"
APPLICATION_INSIGHTS_CONNECTION_STRING=""
APPLICATION_INSIGHTS_NAME="azure-mcp-remote-server-insights"

MANAGED_IDENTITY_CLIENT_ID="e1d30edf-af63-4775-9954-f01086959c03"
MANAGED_IDENTITY_ID="/subscriptions/01c2168f-b1cb-417a-ba8b-75256bc0c0f1/resourceGroups/explore-obo-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azure-mcp-remote-server-managed-identity"

ENTRA_APP_OBO_CLIENT_ID="5ee04c42-151d-4f7d-aa68-547007db25d2"
ENTRA_APP_OBO_SERVER_ID="79cbf8ae-6bc5-4ea0-9071-241de4a57a03"
ENTRA_APP_OBO_SERVER_OBJECT_ID="8cc2b353-7380-4f3b-bdb5-892b41c61dc9"
ENTRA_APP_OBO_SERVER_IDENTIFIER_URI="api://79cbf8ae-6bc5-4ea0-9071-241de4a57a03"
ENTRA_APP_OBO_SCOPE_ID="101ae48b-1099-5279-9bdc-604258b54cc7"
ENTRA_APP_OBO_SCOPE_VALUE="Mcp.Tools.ReadWrite"

```

</details>

## azmcp azure authentication

### UseHostingEnvironmentIdentity

The Container App's **system-assigned managed identity** authenticates to downstream Azure services. You must assign the necessary RBAC roles to the Container App's identity for the Azure services that will be accessed.

<details>

<summary>RBAC Role assignments:</summary>

```bash
# Get the Container App's system-assigned managed identity principal ID and subscription ID
PRINCIPAL_ID=$(azd env get-value CONTAINER_APP_PRINCIPAL_ID)
SUBSCRIPTION_ID=$(azd env get-value AZURE_SUBSCRIPTION_ID)

# Required: Reader at subscription scope
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Reader" \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Optional: grant additional data-plane roles as needed, e.g. to list blobs:
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Storage Blob Data Reader" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/{resource-group}/providers/Microsoft.Storage/storageAccounts/{storage-account}

```

</details>

### UseOnBehalfOf

The server exchanges the calling user's token for a downstream token using the **OBO (On-Behalf-Of) flow**. Each user's own RBAC permissions are used to access Azure services.

After deployment, grant admin consent for the server app's API permissions (Azure Resource Manager and Azure Storage `user_impersonation`):

<details>

<summary>Admin consent command:</summary>

```bash
# Get the OBO server app ID
SERVER_APP_ID=$(azd env get-value ENTRA_APP_OBO_SERVER_ID)

# Grant tenant-wide admin consent for the server app's API permissions
az ad app permission admin-consent --id $SERVER_APP_ID
```

</details>

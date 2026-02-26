# Remote host Azure MCP Server dev build

An Azure Developer CLI (azd) template to build the Azure MCP Server source code and deploy it as a remote HTTP service on Azure Container Apps (ACA).

## Prerequisites

1. Clone of the [microsoft/mcp](https://github.com/microsoft/mcp.git) source (with your local changes)
2. Azure subscription with **Owner** or **User Access Administrator** access
3. Dev Tools
   * **[Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)** (`az login`)
   * **[Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)** (`azd auth login`)
   * **[Docker](https://docs.docker.com/get-docker/)** (Ensure Docker daemon is running)
   * **[PowerShell 7+ (pwsh)](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)**

## azd deploy

1. **Get azd-template** -  Download azd-template [azmcp-remote-dev-deploy.zip](https://github.com/anuchandy/azmcp-remote-dev-deploy/blob/main/azmcp-remote-dev-deploy.zip), extract and copy it to the root of your local `microsoft/mcp` clone.

2. **Open azd-template in pwsh terminal**
   ```bash
   pwsh
   cd /code/mcp/azmcp-remote-dev-deploy
   ```

3. **Run azd-template**
   ```bash
   azd init
   azd up
   ```

<details>

<summary>Behind azd up:</summary>

The `azd up` command:

1. Compile the `Azure.Mcp.Server` in your local clone of `microsoft/mcp`, and build Linux x64 musl Docker container image

2. **Provision Infra**:
   - Azure Container Registry (ACR)
   - Entra ID Application - for OAuth2 authentication

3. **Deploy**:
   - Push Docker image to ACR
   - Deploy Azure Container App (ACA) using the image, with authentication and environment variables configured

</details>

## azd output

After deployment, retrieve azd outputs:

```bash
/code/mcp/azmcp-remote-dev-deploy> azd env get-values
```

<details>

<summary>Example output:</summary>

```bash
ACR_ID="/subscriptions/145ee162-9bd2-48dc-814b-c424606897aa/resourceGroups/SSS3PT_anuchan-mcp15ccd223/providers/Microsoft.ContainerRegistry/registries/acrazmcpremoteserveraxi"
ACR_IMAGE="acrazmcpremoteserveraxi.azurecr.io/azure-mcp:latest"
ACR_LOGIN_SERVER="acrazmcpremoteserveraxi.azurecr.io"
ACR_NAME="acrazmcpremoteserveraxi"
APPLICATION_INSIGHTS_CONNECTION_STRING=""
APPLICATION_INSIGHTS_NAME="azure-mcp-remote-server-insights"
AZURE_ENV_NAME="azmcp-remote-dev-env"
AZURE_LOCATION="eastus2"
AZURE_MCP_COLLECT_TELEMETRY="False"
AZURE_RESOURCE_GROUP="SSS3PT_anuchan-mcp15ccd223"
AZURE_SUBSCRIPTION_ID="145ee162-9bd2-48dc-814b-c424606897aa"
AZURE_TENANT_ID="70a036f6-8e4d-4615-bad6-149c02e7720d"
BUILD_CONFIGURATION="Release"
CONTAINER_APP_NAME="azure-mcp-remote-server"
CONTAINER_APP_PRINCIPAL_ID="4e6a2296-f620-4ac8-b9d4-a740c7a67269"
CONTAINER_APP_URL="https://azure-mcp-remote-server.stranger-things.eastus2.azurecontainerapps.io"
ENTRA_APP_CLIENT_ID="0dfbc09b-6dd8-4de3-ae48-054c806ee59f"
ENTRA_APP_IDENTIFIER_URI="api://0dfbc09b-6dd8-4de3-ae48-054c806ee59f"
ENTRA_APP_OBJECT_ID="36227e9d-8915-42bf-a6d3-3733d745ba71"
ENTRA_APP_SERVICE_PRINCIPAL_ID="92364c66-729f-4003-9fd0-111446f5ef14"
LOCAL_DOCKER_IMAGE="azure-sdk/azure-mcp:2.0.0-alpha.99999"
NAMESPACES="[\"storage\",\"keyvault\",\"sql\",\"cosmos\"]"
OUTGOING_AUTH_STRATEGY="UseHostingEnvironmentIdentity"
```

</details>

## azmcp authentication

#### Managed Identity 

By default, the azmcp is configured to use the **Managed Identity** of the Azure Container App to authenticate downstream Azure services during tool execution. You must assign the necessary Azure RBAC roles to the Container App's managed identity for the Azure services that will be accessed.

<details>

<summary>Example role assignments:</summary>

```bash
# Get the ACA's Managed Identity principal ID
PRINCIPAL_ID=$(azd env get-value CONTAINER_APP_PRINCIPAL_ID)

# Assign Storage Blob Data Contributor role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Storage/storageAccounts/{storage-account}

# Assign Key Vault Secrets User role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.KeyVault/vaults/{key-vault}
```

</details>

#### On Behalf Of (OBO)

The deployed Entra app is configured with delegated permissions for Azure Storage (`user_impersonation` scope), enabling the On-Behalf-Of (OBO) flow for storage operations.

To run azmcp in OBO authentication mode so storage tools can be called using OBO, update `infra/main.parameters.json`:

```json
"outgoingAuthStrategy": {
  "value": "UseOnBehalfOf"
}
```

Then redeploy with `azd up`.

## Clients

Sample MCP clients are available in the `clients/` directory:

- **[VS Code](clients/vscode/README.md)** - Connect using VS Code's built-in MCP support
- **[C# McpClient](clients/csharp/README.md)** - .NET console application
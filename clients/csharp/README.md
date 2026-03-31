# Connect from C# McpClient

Connect to Azure MCP Server from a C# console app.

## Prerequisites

- Azure MCP Server deployed and running (see [main README](../../README.md))
- .NET 10 SDK

## Setup

1. **Update `appsettings.json` with your MCP server URL**

  Edit `appsettings.json` and set the `McpServer:Url` to your Container App URL:

  If you've run the azd template with `outgoingAuthStrategy` as `UseOnBehalfOf`, get the `ENTRA_APP_OBO_CLIENT_ID` value from `azd env get-values` and use it for `EntraClientClientId`.

  If you've run the azd template with `outgoingAuthStrategy` as `UseHostingEnvironmentIdentity`, leave `EntraClientClientId` as empty (`""`).

   ```json
   {
      "McpServer": {
        "Url": "https://azure-mcp-remote-server.stranger-things.eastus2.azurecontainerapps.io"
      },
      "list-accounts": "true",
      "EntraClientClientId": "",
      "SubscriptionId": "01c2168f-b1cb-417a-ba8b-75256bc0c0f1"
  }
   ```

   You can retrieve the URL using:
   ```bash
   azd env get-value CONTAINER_APP_URL
   ```

2. **Build and run**

   ```bash
   dotnet build && dotnet run
   ```

   The client will:
   - Fetch OAuth Protected Resource Metadata from the server
   - Authenticate using interactive browser login
   - Connect to the MCP server and list available tools, and calls storage tool
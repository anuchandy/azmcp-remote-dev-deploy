# Connect from C# McpClient

Connect to Azure MCP Server from a C# console app.

## Prerequisites

- Azure MCP Server deployed and running (see [main README](../../README.md))
- .NET 10 SDK

## Setup

1. **Update `appsettings.json` with your MCP server URL**

   Edit `appsettings.json` and set the `McpServer:Url` to your Container App URL:

   ```json
   {
     "McpServer": {
       "Url": "https://azure-mcp-remote-server.stranger-things.eastus2.azurecontainerapps.io"
     }
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
   - Connect to the MCP server and list available tools
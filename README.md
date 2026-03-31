# Azure MCP Server - Remote Dev Deploy

This repo includes

1. azd templates to build the Azure MCP Server source code and 
      - deploy it as a remote HTTP service on Azure Container Apps (ACA)
2. MCP clients to connect to the deployed server

## Deployment Templates

- [Azure Container Apps (ACA)](README-ACA.md)


## clients

Sample MCP clients to connect to deployed server are available in the `clients/` directory:

- **[VS Code](clients/vscode/README.md)** - Connect using VS Code's built-in MCP support
- **[C# McpClient](clients/csharp/README.md)** - .NET console application
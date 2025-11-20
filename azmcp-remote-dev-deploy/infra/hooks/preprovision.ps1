#!/usr/bin/env pwsh
#Requires -Version 7

$ErrorActionPreference = 'Stop'

$REPO_ROOT = (Get-Item (Join-Path $PSScriptRoot "../..")).Parent.FullName
Write-Host "Repository root: $REPO_ROOT" -ForegroundColor Gray

$parametersFile = Join-Path $PSScriptRoot "../main.parameters.json"
$BUILD_CONFIGURATION = 'Release'  # Default

if (Test-Path $parametersFile) {
    try {
        $parameters = Get-Content $parametersFile -Raw | ConvertFrom-Json
        if ($parameters.parameters.buildConfiguration.value) {
            $BUILD_CONFIGURATION = $parameters.parameters.buildConfiguration.value
        }
    } catch {
        # default to Release
    }
}

Write-Host "Build configuration: $BUILD_CONFIGURATION" -ForegroundColor Gray

$BUILD_OUTPUT_DIR = Join-Path $REPO_ROOT ".work/build/Azure.Mcp.Server"
if (Test-Path $BUILD_OUTPUT_DIR) {
    Write-Host ""
    Write-Host "Deleting $BUILD_OUTPUT_DIR" -ForegroundColor Yellow
    Remove-Item -Path $BUILD_OUTPUT_DIR -Recurse -Force
}

Write-Host ""
Write-Host "Building azmcp source for linux-x64 ($BUILD_CONFIGURATION)..." -ForegroundColor Yellow

$buildArgs = @{
    OperatingSystem = 'linux'
    Architecture = 'x64'
    SelfContained = $true
    SingleFile = $true
    ServerName = 'Azure.Mcp.Server'
}

if ($BUILD_CONFIGURATION -eq 'Release') {
    $buildArgs['ReleaseBuild'] = $true
}

& "$REPO_ROOT/eng/scripts/Build-Code.ps1" @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build-Code failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Building linux-x64 Docker image..." -ForegroundColor Yellow
& "$REPO_ROOT/eng/scripts/Build-Docker.ps1" `
    -ServerName "Azure.Mcp.Server"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build-Docker failed" -ForegroundColor Red
    exit 1
}

$dockerOutput = docker images --filter "reference=azure-sdk/azure-mcp" --format "{{.Repository}}:{{.Tag}}" | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($dockerOutput)) {
    Write-Host "ERROR: Could not find built Docker image" -ForegroundColor Red
    exit 1
}

Write-Host "Built azmcp linux-x64 Docker image: $dockerOutput" -ForegroundColor Green
azd env set LOCAL_DOCKER_IMAGE $dockerOutput
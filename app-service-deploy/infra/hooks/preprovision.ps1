#!/usr/bin/env pwsh
#Requires -Version 7

$ErrorActionPreference = 'Stop'

$SERVER_NAME = 'Azure.Mcp.Server'
$PLATFORM_NAME = 'linux-x64'

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

Write-Host ""
Write-Host "Generating build info for $SERVER_NAME" -ForegroundColor Yellow
& "$REPO_ROOT/eng/scripts/New-BuildInfo.ps1" -ServerName $SERVER_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: New-BuildInfo failed" -ForegroundColor Red
    exit 1
}

$BUILD_OUTPUT_DIR = Join-Path $REPO_ROOT ".work/build"
if (Test-Path $BUILD_OUTPUT_DIR) {
    Write-Host ""
    Write-Host "Deleting $BUILD_OUTPUT_DIR" -ForegroundColor Yellow
    Remove-Item -Path $BUILD_OUTPUT_DIR -Recurse -Force
}

Write-Host ""
Write-Host "Building azmcp source for $PLATFORM_NAME ($BUILD_CONFIGURATION)..." -ForegroundColor Yellow

$buildInfoPath = Join-Path $REPO_ROOT ".work/build_info.json"
$buildArgs = @{
    BuildInfoPath = $buildInfoPath
    PlatformName = $PLATFORM_NAME
    SelfContained = $true
    SingleFile = $true
    ServerName = $SERVER_NAME
}

if ($BUILD_CONFIGURATION -eq 'Release') {
    $buildArgs['ReleaseBuild'] = $true
}

& "$REPO_ROOT/eng/scripts/Build-Code.ps1" @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build-Code failed" -ForegroundColor Red
    exit 1
}

# Find the publish output directory
$publishDir = Join-Path $REPO_ROOT ".work/build/$SERVER_NAME/$PLATFORM_NAME"
if (-not (Test-Path $publishDir)) {
    Write-Host "ERROR: Publish output not found at $publishDir" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Publish output: $publishDir" -ForegroundColor Gray

# Create zip for deployment
$zipPath = Join-Path $REPO_ROOT ".work/build/azmcp-appservice.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host ""
Write-Host "Creating deployment zip..." -ForegroundColor Yellow
Compress-Archive -Path "$publishDir/*" -DestinationPath $zipPath -Force

$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "Deployment zip created: $zipPath ($zipSize MB)" -ForegroundColor Green

azd env set DEPLOY_ZIP_PATH $zipPath

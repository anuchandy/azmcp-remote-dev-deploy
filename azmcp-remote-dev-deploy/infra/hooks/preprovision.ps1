#!/usr/bin/env pwsh
#Requires -Version 7

$ErrorActionPreference = 'Stop'

function Update-BuildInfoFile {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string]$ServerName,
        [Parameter(Mandatory)]
        [string]$PlatformName,
        [Parameter(Mandatory)]
        [string]$ArtifactPath
    )

    $buildInfoPath = Join-Path $RepoRoot ".work/build_info.json"
    if (-not (Test-Path $buildInfoPath)) {
        Write-Host "ERROR: build_info.json not found at $buildInfoPath" -ForegroundColor Red
        return $false
    }

    $buildInfo = Get-Content $buildInfoPath -Raw | ConvertFrom-Json

    $server = $buildInfo.servers | Where-Object { $_.name -eq $ServerName }
    if (-not $server) {
        Write-Host "ERROR: Server '$ServerName' not found in build_info.json" -ForegroundColor Red
        return $false
    }

    $platform = $server.platforms | Where-Object { $_.name -eq $PlatformName }
    if (-not $platform) {
        Write-Host "ERROR: Platform '$PlatformName' not found for server '$ServerName'" -ForegroundColor Red
        return $false
    }

    $platform.artifactPath = $ArtifactPath
    Write-Host "Updated artifactPath for $PlatformName to: $ArtifactPath" -ForegroundColor Gray

    $buildInfo | ConvertTo-Json -Depth 10 | Set-Content $buildInfoPath -Encoding UTF8
    Write-Host "Saved updated build_info.json" -ForegroundColor Gray

    return $true
}

$SERVER_NAME = 'Azure.Mcp.Server'
$PLATFORM_NAME = 'linux-musl-x64-docker'

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

# Patch build-info file to fix-up artifactPath for $PLATFORM_NAME platform
$patchResult = Update-BuildInfoFile `
    -RepoRoot $REPO_ROOT `
    -ServerName $SERVER_NAME `
    -PlatformName $PLATFORM_NAME `
    -ArtifactPath "$SERVER_NAME/linux-musl-x64"

if (-not $patchResult) {
    exit 1
}

$BUILD_OUTPUT_DIR = Join-Path $REPO_ROOT ".work/build"
if (Test-Path $BUILD_OUTPUT_DIR) {
    Write-Host ""
    Write-Host "Deleting $BUILD_OUTPUT_DIR" -ForegroundColor Yellow
    Remove-Item -Path $BUILD_OUTPUT_DIR -Recurse -Force
}

Write-Host ""
Write-Host "Building azmcp source for linux-musl-x64 ($BUILD_CONFIGURATION)..." -ForegroundColor Yellow

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

Write-Host ""
Write-Host "Building linux-musl-x64 Docker image..." -ForegroundColor Yellow
& "$REPO_ROOT/eng/scripts/Build-Docker.ps1" `
    -ServerName $SERVER_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build-Docker failed" -ForegroundColor Red
    exit 1
}

$dockerOutput = docker images --filter "reference=azure-sdk/azure-mcp" --format "{{.Repository}}:{{.Tag}}" | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($dockerOutput)) {
    Write-Host "ERROR: Could not find built Docker image" -ForegroundColor Red
    exit 1
}

Write-Host "Built azmcp linux-musl-x64 Docker image: $dockerOutput" -ForegroundColor Green
azd env set LOCAL_DOCKER_IMAGE $dockerOutput
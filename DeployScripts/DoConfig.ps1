$ErrorActionPreference = "Stop"

Write-Host "Config file: $configFile"

function Get-ScriptDirectory
{
    Write-Host "Getting Script directory"
    Split-Path $script:MyInvocation.MyCommand.Path
}

function Get-OctopusWebSiteNameFromConfig($conf) {
    if($conf.Site) {
        if($conf.Site.Application) {
            return $conf.Site.Name + "/" + $conf.Site.Application.Name
        }
        return $conf.Site.Name
    }
    Write-Error "Configuration is missing site"
    exit 1
}
try
{
    if($configFile -eq $null) {
        $configFile = "Local.Config.ps1"
    }

    $scriptDirectory = split-path -parent $MyInvocation.MyCommand.Definition

    $IISConfigurationScriptPath = $scriptDirectory + "\IISConfiguration.ps1"
    Write-Host "Sourcing IIS configuration utility: $IISConfigurationScriptPath"
    . $IISConfigurationScriptPath

    Write-Host "Sourcing config file"

    $configFilePath = $scriptDirectory + "\$configFile"
    . $configFilePath

    Write-Host "Create application pools"
    CreateAppPools $config.ApplicationPools

    Write-Host "Create site"
    CreateSiteFromConfig $config.Site

    Write-Host "Set ocotpus web site name"
    $siteName = (Get-OctopusWebSiteNameFromConfig $config)

    Write-Host "Setting OctopusWebSiteName: $siteName"
    Set-OctopusVariable -Name "OctopusWebSiteName" -Value $siteName
    Set-OctopusVariable -Name "Octopus.Action.Package.UpdateIisWebsiteName" -Value $siteName
}
catch
{
    Write-Error "Failed to setup IIS"
    Exit 1
}

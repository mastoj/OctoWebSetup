$ErrorActionPreference = "Stop"

function Get-ScriptDirectory
{
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


	$IISConfigurationScriptPath = (Get-ScriptDirectory) + "\IISConfiguration.ps1"
	. $IISConfigurationScriptPath

	$configFilePath = (Get-ScriptDirectory) + "\$configFile"
	. $configFilePath

	CreateAppPools $config.ApplicationPools
	CreateSiteFromConfig $config.Site
	$siteName = (Get-OctopusWebSiteNameFromConfig $config)
	Write-Host "Setting OctopusWebSiteName: $siteName"
	Set-OctopusVariable -Name "OctopusWebSiteName" -Value $siteName
}
catch
{
	Write-Error "Failed to setup IIS"
	Exit 1
}

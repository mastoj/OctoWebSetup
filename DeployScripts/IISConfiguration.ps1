Import-Module WebAdministration

$appPoolsPath = "IIS:\AppPools"
$iisSitesPath = "iis:\sites"

function Write-Info ($message) {
    Write-Host "Info:" $message
}

function Write-Error ($message) {
    Write-Host "Error:" $message
}

function GuardAgainstNull($value, $message) {
    if($value -eq $null) {
        Write-Error $message
        exit 1
    }    
}

function IISObjectExists($objectName) {
    return Test-Path $objectName
}

function WebAppExists($appName) {
    if($appName.ToLower().StartsWith("iis")) {
        return IISObjectExists $appName
    } else {
        return IISObjectExists "IIS:\Sites\$appName"
    }
}

function WebSiteExists($siteName) {
    return WebAppExists $siteName 
}

function AppPoolExists($appPoolName) {
    return IISObjectExists "$appPoolsPath\$appPoolName"
}

function GetIfNull($value, $default) {
    if ($value -eq $null) { $default } else { $value }
}

function CreateApplicationPool($appPoolConfig) {
    $appPoolName = $appPoolConfig.Name
    $appPoolFrameworkVersion = $appPoolConfig.FrameworkVersion
    $appPoolIdentityType = $appPoolConfig.AppPoolIdentityType
    $userName = $appPoolConfig.UserName
    $password = $appPoolConfig.Password
    $enable32BitsApp = $appPoolConfig.Enable32BitApps

    $appPoolFrameworkVersion = GetIfNull $appPoolFrameworkVersion "v4.0"
    $appPoolIdentityType = GetIfNull $appPoolIdentityType "ApplicationPoolIdentity"
    $enable32BitsApp = GetIfNull $enable32BitsApp $False
    if($appPoolIdentityType -eq "SpecificUser") {
        GuardAgainstNull $userName "userName and password must be set when using SpecificUser"
        GuardAgainstNull $password "userName and password must be set when using SpecificUser"
    }
    
    $appPoolFullPath = "$appPoolsPath\$appPoolName"
    if(AppPoolExists $appPoolName) {
        Write-Info "Application pool already exists"
    } else {
        Write-Info "Creating application pool: $appPoolName"
        $appPool = new-item $appPoolFullPath
        Write-Info "Application pool created"
    }
    if($appPoolIdentityType -ne "SpecificUser") {
        Set-ItemProperty $appPoolFullPath -name processModel -value @{identitytype="$appPoolIdentityType"}
    }
    else {
        Set-ItemProperty $appPoolFullPath -name processModel -value @{identitytype="$appPoolIdentityType"; username="$userName"; password="$password"}
    }
    Set-ItemProperty $appPoolFullPath managedRuntimeVersion "$appPoolFrameworkVersion"
    Set-ItemProperty $appPoolFullPath enable32BitAppOnWin64 "$enable32BitsApp"
}

function GetNextSiteId {
    (dir $iisSitesPath | foreach {$_.id} | sort -Descending | select -first 1) + 1
}

function CreateSite($siteName, $siteRoot, $appPoolName, $port) {
    $port = GetIfNull $port 80
    GuardAgainstNull $siteName "siteName mest be set"
    GuardAgainstNull $siteRoot "siteRoot must be set"
    GuardAgainstNull $appPoolName "appPoolName must be set when creating a site"
    if(WebSiteExists $siteName) {
        Write-Info "Site $siteName already exists"
    } else {
        Write-Info "Creating site"
        if (!(Test-Path $siteRoot)) {
            Write-Info "Site root does not exist, creating..."
            [void](new-item $siteRoot -itemType directory)
        }

        $id = GetNextSiteId
        $sitePath = "$iisSitesPath\$siteName"
        new-item $sitePath -bindings @{protocol="http";bindingInformation="*:${port}:*"} -id $id -physicalPath $siteRoot
        Set-ItemProperty $sitePath -name applicationPool -value "$appPoolName"
        Write-Info "Site created, starting site"
        Start-Website $siteName
    }
}

function CreateApplication($siteName, $applicationConfig) {
	$applicationName = $applicationConfig.Name
	$applicationRoot = $applicationConfig.ApplicationRoot
	$appPoolName = $applicationConfig.AppPoolName
    GuardAgainstNull $siteName "siteName mest be set"
    GuardAgainstNull $applicationRoot "applicationRoot must be set"
    GuardAgainstNull $applicationName "applicationName must be set"
    GuardAgainstNull $appPoolName "appPoolName must be set"
	$appPath = $siteName + "\" + $applicationName
	$appPathForAuth = $siteName + "/" + $applicationName
    $applicationIISPath = ($iisSitesPath + "\" + $appPath)
    if(WebAppExists $applicationIISPath) {
        Write-Info "Application $siteName\$applicationName already exists"
    }
    else {
        Write-Info "Application does not exist, creating..."
        New-Item $applicationIISPath -physicalPath "$applicationRoot" -type Application
        Set-ItemProperty $applicationIISPath -name applicationPool -value "$appPoolName"
        Write-Info "Application Created" 
    }
	if($applicationConfig.Authentication) {
		ConfigureAuthentication $appPathForAuth $applicationConfig.Authentication
	}
}

function GetHostNamesForSite($siteName) {
    return $site.bindings.Collection | %{$_.bindingInformation.Split(":")[2]}
}

function Enable-AuthenticationMode($authenticationMode, $location) {
    Set-WebConfigurationProperty -filter "/system.webServer/security/authentication/$authenticationMode" -name enabled -value true -PSPath "IIS:\" -location "$location"
}

function Disable-AuthenticationMode($authenticationMode, $location) {
    Set-WebConfigurationProperty -filter "/system.webServer/security/authentication/$authenticationMode" -name enabled -value false -PSPath "IIS:\" -location "$location"
}

function ConfigureAuthentication($location, $authentications) {
	ForEach($authentication in $authentications) {
		$mode = $authentication.Mode
		if($authentication.Enabled) {
			Write-Info "Enabling Authentication $mode for $location"
			Enable-AuthenticationMode $mode $location
		}
		else {
			Write-Info "Disabling Authentication $mode for $location"
			Disable-AuthenticationMode $mode $location
		}
	}
}

function ClearBindings($siteName) {
    Clear-ItemProperty "$iisSitesPath\$siteName" -Name bindings
}

function AddBindings($siteName, $bindings) {
    ForEach($binding in $bindings) {
        $port = $binding.Port
        $hostName = $binding.HostName
        New-WebBinding -Name $siteName -HostHeader $hostName -Port $port -Protocol "http"
    }
}

function SetBindings($siteName, $bindings) {
    Write-Info "Bindings will be deleted and added again"
    Write-Info "SiteName: $siteName"
    Write-Info "Bindings: $bindings"
    if($bindings -ne $null) {
        Write-Info "Deleting bindings"
        ClearBindings $siteName
        Write-Info "Adding bindings"
        AddBindings $siteName $bindings
    }
}

function CreateAppPools($appPoolsConfig) {
    Foreach($appPoolConfig in $appPoolsConfig) {
        CreateApplicationPool $appPoolConfig
    }
}

function CreateSiteFromConfig($siteConfig) {
    $siteName = $siteConfig.Name
    $siteRoot = $siteConfig.SiteRoot
    $appPoolName = $siteConfig.AppPoolName
    $port = $siteConfig.Port
    CreateSite $siteName $siteRoot $appPoolName $port
    if($siteConfig.Bindings) {
        SetBindings $siteName $siteConfig.Bindings
    }
	if($siteConfig.Authentication) {
		ConfigureAuthentication $siteName $siteConfig.Authentication
	}
    if($siteConfig.Application) {
        CreateApplication $siteName $siteConfig.Application
    }
}
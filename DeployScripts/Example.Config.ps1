$config = @{
    ApplicationPools = @(
        @{
            Name = "DemoSiteAppPool";
            Enable32BitApps = $True;
            FrameworkVersion = "v4.0"
        },
        @{
            Name = "DemoSiteAppAppPool";
            Enable32BitApps = $True;
            FrameworkVersion = "v4.0"
        });
    Site = @{
        Name = "DemoSite";
        SiteRoot = "c:\tmp";
        AppPoolName = "DemoSiteAppPool";
        Port = 88
        Bindings = @(
            @{Port= 88; HostName= "*"}, 
            @{Port= 89; HostName= "DemoApp"}
        );
        Application = @{
            Name = "DemoApp";
            AppPoolName = "DemoSiteAppAppPool";
            ApplicationRoot = "c:\tmp"
        }
    };
}
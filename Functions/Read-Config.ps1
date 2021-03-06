Function Read-Config {
	
	Param (
	    
        [Parameter(Mandatory = $true)]
        $Path
    )

	Try {
	
		$Config = @{}
			
		$xmlconfig = [xml]([System.IO.File]::ReadAllText($Path))
		
		[string]$Sensitivity = $xmlconfig.Configuration.Sensitivity

		[string]$Network = $xmlconfig.Configuration.Thresholds.Network.kbout
		[string]$CPU = $xmlconfig.Configuration.Thresholds.CPU.Percent
		[string]$Logins = $xmlconfig.Configuration.Thresholds.Logins.Number
		[bool]$Logging = [System.Convert]::ToBoolean($xmlconfig.Configuration.Logging.DebugOutput)

		[string]$saltStagingDNSAlias = $xmlconfig.Configuration.SaltMaster.StagingAlias
		[string]$saltUATDNSAlias = $xmlconfig.Configuration.SaltMaster.UATAlias
		[string]$saltProductionDNSAlias = $xmlconfig.Configuration.SaltMaster.ProductionAlias
		
		[string]$saltStagingDNSName = $xmlconfig.Configuration.SaltMaster.StagingName
		[string]$saltUATDNSName = $xmlconfig.Configuration.SaltMaster.UATName
		[string]$saltProductionDNSName = $xmlconfig.Configuration.SaltMaster.ProductionName
		
		[string]$graphiteStagingDNSAlias = $xmlconfig.Configuration.Graphite.StagingAlias
		[string]$graphiteUATDNSAlias = $xmlconfig.Configuration.Graphite.UATAlias
		[string]$graphiteProductionDNSAlias = $xmlconfig.Configuration.Graphite.ProductionAlias
		
		[string]$graphiteStagingDNSName = $xmlconfig.Configuration.Graphite.StagingName
		[string]$graphiteUATDNSName = $xmlconfig.Configuration.Graphite.UATName
		[string]$graphiteProductionDNSName = $xmlconfig.Configuration.Graphite.ProductionName
		
		[string]$zoomStaging = $xmlconfig.Configuration.Zoom.StagingName
		[string]$zoomUAT = $xmlconfig.Configuration.Zoom.UATName
		[string]$zoomProduction = $xmlconfig.Configuration.Zoom.ProductionName
		
		[int]$TimeOut = $xmlconfig.Configuration.Graphite.Timeout
		
		[string]$TimeForAnalysys = $xmlconfig.Configuration.TimeForAnalysys.DaysBack
		
		[string]$NumberOfServers = $xmlconfig.Configuration.ServersToAnalyze.Number
		
		[string]$From = $xmlconfig.Configuration.Email.From
		[string]$To = $xmlconfig.Configuration.Email.To
		[string]$CC = $xmlconfig.Configuration.Email.CC
		[string]$SMTP = $xmlconfig.Configuration.Email.SMTP
		
		[string]$LxKernel = $xmlconfig.Configuration.LinuxRegEx.kernel
		[string]$LxOS = $xmlconfig.Configuration.LinuxRegEx.OS
		[string]$WinKernel = $xmlconfig.Configuration.WindowsRegEx.kernel
		[string]$WinOS = $xmlconfig.Configuration.WindowsRegEx.OS
		
		[bool]$UseSaltCache = [System.Convert]::ToBoolean($xmlconfig.Configuration.UseSaltCache)
		[string]$SaltCacheName = $xmlconfig.Configuration.SaltCacheName
		
		[string]$DomainName = $xmlconfig.Configuration.DomainName
		
		[string]$ClaimUserName = $xmlconfig.Configuration.ClaimUserName
		[string]$ClaimPassword = $xmlconfig.Configuration.ClaimPassword
		
		[string]$vCenterStg = $xmlconfig.Configuration.vCenter.Staging
		[string]$vCenterUAT = $xmlconfig.Configuration.vCenter.UAT
		[string]$vCenterProd = $xmlconfig.Configuration.vCenter.Production

		[string]$ZooStg = $xmlconfig.Configuration.Zookeeper.Staging
		[string]$ZooUAT = $xmlconfig.Configuration.Zookeeper.UAT
		[string]$ZooProduction = $xmlconfig.Configuration.Zookeeper.Production
		
		[string]$AWSAccessKey = $xmlconfig.Configuration.AWS.AccessKey
		[string]$AWSSecretKey = $xmlconfig.Configuration.AWS.SecretKey
		[string]$AWSRegion = $xmlconfig.Configuration.AWS.Region
		
		[string]$ExhibitorAuth = $xmlconfig.Configuration.Exhibitor.Auth

		$Config.Sensitivity = $Sensitivity
		
		$Config.NetThreshold = $Network
		$Config.CPUThreshold = $CPU
		$Config.LoginsThreshold = $Logins
		
		$Config.DebugLogLevel = $Logging
		
		$Config.saltStagingAlias = $saltStagingDNSAlias
		$Config.saltUATAlias = $saltUATDNSAlias
		$Config.saltProductionAlias = $saltProductionDNSAlias
		
		$Config.saltStagingName = $saltStagingDNSName
		$Config.saltUATName = $saltUATDNSName
		$Config.saltProductionName = $saltProductionDNSName
		
		$Config.graphiteStagingAlias = $graphiteStagingDNSAlias
		$Config.graphiteUATAlias = $graphiteUATDNSAlias
		$Config.graphiteProductionAlias = $graphiteProductionDNSAlias
		
		$Config.graphiteStagingName = $graphiteStagingDNSName
		$Config.graphiteUATName = $graphiteUATDNSName
		$Config.graphiteProductionName = $graphiteProductionDNSName
		
		$Config.zoomStaging = $zoomStaging
		$Config.zoomUAT = $zoomUAT
		$Config.zoomProduction = $zoomProduction
		
		$Config.graphiteTimeout = $Timeout
		
		$Config.DaysToAnalyze = "-" + $TimeForAnalysys + "days"
		
		$Config.ServersToAnalyze = $NumberOfServers
		
		$Config.EmailFrom = $From
		$Config.EmailTo = $To
		$Config.EmailCC = $CC
		$Config.EmailSMTP = $SMTP
		
		$Config.LinuxKernel = $LxKernel
		$Config.LinuxOS = $LxOS
		$Config.WindowsKernel = $WinKernel
		$Config.WindowsOS = $WinOS
		
		$Config.UseSaltCache = $UseSaltCache
		$Config.SaltCacheName = $SaltCacheName
		
		$Config.DomainName = $DomainName
		
		$Config.ClaimUserName = $ClaimUserName
		$Config.ClaimPassword = $ClaimPassword
		
		$Config.vCenterStg = $vCenterStg
		$Config.vCenterUAT = $vCenterUAT
		$Config.vCenterProduction = $vCenterProd
		
		$Config.ZooStg = $ZooStg
		$Config.ZooUAT = $ZooUAT
		$Config.ZooProduction = $ZooProduction
		
		$Config.AccessKey = $AWSAccessKey
		$Config.SecretKey = $AWSSecretKey
		$Config.Region = $AWSRegion
		
		$Config.ExhibitorAuth = $ExhibitorAuth
		
		Return $Config
	}
	
	Catch { $_ ; break }
}
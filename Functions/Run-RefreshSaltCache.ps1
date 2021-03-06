Function Run-RefreshSaltCache {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,

		[string]
		[Parameter( Mandatory = $true )]
		$CacheName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName
	)
		
	$ErrorActionPreference = "Stop"
	
	$Grains = $null
	
	$SaltTarget = $ComputerName + "." + $DomainName

	$SaltArguments = "cpu_model,productname,kernelrelease,serialnumber,osrelease,os,virtual,unused"
		
	$CacheURL = "http://$CacheName/api/v3/saltcache/repopulate/host/$SaltTarget"
					
	Try {
		Write-Debug "Refreshing Salt Cache for $ComputerName..."
		$Refresh = Invoke-RestMethod $CacheURL -TimeoutSec 20
		
		If ( $Refresh.response.grains.os ) { $Return = $true }
		Else { $Return = $false }
	}
	
	Catch { 
		$_ 
		Write-Debug "Got error from Salt Cache..."
		$Result = $false
	}
		
	return $Result
}
Function Run-GetGrainsCache {

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
		
	$CacheURL = "http://$CacheName/api/v2/saltcache/grains/$SaltTarget/" + $SaltArguments + "?nocase=True"
					
	Try {
		Write-Debug "Getting grains from Salt Cache for $ComputerName..."
		$Grains = Invoke-RestMethod $CacheURL -TimeoutSec 20
	}
	
	Catch { 
		$_ 
		Write-Debug "Got error from Salt Cache..."
		Write-Debug "Trying to get grains from Salt API..."
		$Grains = Run-GetGrains $ComputerName
	}
	
	$global:f = $Grains
			
	If ( ! $Grains ) { $Grains = $false }
	ElseIf ( $Grains.osrelease.Length -eq 0 -and $Grains.os.Length -eq 0 -and $Grains.cpu_model.Length -eq 0 ) { 
		Write-Debug "Got empty string from Salt Cache..."
		Write-Debug "Trying to get grains from Salt API..."
		$Grains = Run-GetGrains $ComputerName
	}
	
	return $Grains
}
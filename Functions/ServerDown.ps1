Function ServerDown {	

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$Comp,
		
		[string]
		[Parameter( Mandatory = $true )]
		$graphTarget,
		
		[switch]
		$Deprecate,
				
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName	
	)

	Write-Debug "$Comp is down"
	
	$HashLocal = @{}				
	
	$HashLocal.ComputerName = $Comp
	$HashLocal.Online = "No"
	$HashLocal.Model = "N/A"
	$HashLocal.SerialNumber = "N/A"
	$HashLocal.OS = "N/A"
	$HashLocal.Kernel = "N/A"
	$HashLocal.CPU = "N/A"
	
	$graphTarget = $graphTarget + "." + $DomainName
										
	If ( $Deprecate ) {
																
		$Result_CleanGr = Run-CleanGraphite -ComputerName $Comp -GraphiteTarget $graphTarget
		
		If ( $Result_CleanGr.Result -match $null ) { $HashLocal.GraphiteDataDeleted = "Yes" }
		
		Else { $HashLocal.GraphiteDataDeleted = "No" }
						
	}
							
	Else { $HashLocal.GraphiteDataDeleted = "No" }
				
	return $HashLocal
		
}
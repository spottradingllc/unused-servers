Function Get-ZoomInfo {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,

		[string]
		[Parameter( Mandatory = $true )]
		$Zoom,
		
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName
	)
	
	$ComputerName = $ComputerName + "." + $DomainName
					
	$ZoomURL = "http://$Zoom/api/v1/application/mapping/host/$ComputerName"

	Try {
		$ZoomInfo = Invoke-RestMethod $ZoomURL -TimeoutSec 30
		
		If ( $ZoomInfo.data.Count -gt 1 ) { $ZoomInfo.data = $ZoomInfo.data -join ", " }
		
		If ( ! $ZoomInfo.data  ) { $ZoomInfo.data = "-" }
	}
	
	Catch { 
		$_ 
		
		$k = @{} ; $k.data = "Error"
		
		$ZoomInfo = @() ; $ZoomInfo += New-Object PSObject -Property $k
 	}
		
	return $ZoomInfo.data
}
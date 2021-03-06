Function Remove-ZooException {
	
	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName , 
				
		[string]
		[Parameter( Mandatory = $true )]
		$ZooNode,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Auth
	)

	$ExhibitorAuth = @{ "Authorization" = $Auth }
		
	$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/znode/UnusedServersException/" + $ComputerName
		
	Try { 
	
		$Message = Invoke-RestMethod -Uri $Uri -Method Delete -Header $ExhibitorAuth -TimeoutSec 20
			
		If ( $Message.message -match "OK") { Write-Host $ComputerName "was removed from the list of the exceptions." -BackgroundColor Black -ForegroundColor Green ; "" }
		Else { Write-Host "$ComputerName was not found in the list of the exceptions." -BackgroundColor Red -ForegroundColor Yellow ; "" }
	}
	
	Catch { $_ ; break }
}
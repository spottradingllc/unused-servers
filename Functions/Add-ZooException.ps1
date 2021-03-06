Function Add-ZooException {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName , 
		
		[string]
		[Parameter( Mandatory = $true )]
		$Tag , 
		
		[string]
		[Parameter( Mandatory = $true )]
		$ZooNode,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Auth
	)
							
	Function ConvertTo-Hex ( $String ) {

		$StringBytes = [System.Text.Encoding]::UTF8.GetBytes($String)

		# Iterate through bytes, converting each to the hexidecimal equivalent
		$hexArr = $StringBytes | ForEach-Object { $_.ToString("X2") }

		# Join the hex array into a single string for output
		$global:Hex = $hexArr -join ''

	}
	
	$ExhibitorAuth = @{ "Authorization" = $Auth }
		
	ConvertTo-Hex $Tag
			
	$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/znode/UnusedServersException/" + $ComputerName
			
	Try {
	
		$Message = Invoke-RestMethod -Uri $Uri -Method Put -Header $ExhibitorAuth -Body $Hex -TimeoutSec 20
			
		If ( $Message.message -match "OK") { Write-Host "$ComputerName was added to the list of exceptions." -BackgroundColor Black -ForegroundColor Green ; ""	}
		Else { Write-Host "Error!" -BackgroundColor Red -ForegroundColor Yellow }
	}
	
	Catch { $_ ; break }
		
}
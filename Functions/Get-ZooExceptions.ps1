Function Get-ZooExceptions {

	Param (

		[string]
		[Parameter( Mandatory = $true )]
		$ZooNode,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Auth
	)
			
	$ExhibitorAuth = @{ "Authorization" = $Auth }
			
	$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/node?key=/UnusedServersException"
	
	$TryTime = 0

	Function Get-ZooExceptionsInternal {
	
		Try {
		
			$TryTime++
		
			$Exceptions = Invoke-RestMethod -Uri $Uri -Method Get -Header $ExhibitorAuth -TimeoutSec 20
					
			If ( $Exceptions ) {
			
				Switch ( $Exceptions.Count ) {
				
					"1" { $ExceptionsList = $Exceptions.Title }
					
					default { $ExceptionsList = $Exceptions.Title -join "|" }
				
				}
			}
		
			Return $ExceptionsList
		}
		
		# Need to retry 5 times here
		Catch { 
			$_ 
			
			If ( $TryTime -lt 5 ) { Start-Sleep 30 ; Get-ZooExceptionsInternal }
			Else { break }
		}
	}
	
	Get-ZooExceptionsInternal
}
Function Get-LoginStats {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$GraphiteServer,
		
		[string]
		[Parameter( Mandatory = $false )]
		$ExceptionsList,
			
		[string]
		[Parameter( Mandatory = $true )]
		$Threshold,
		
		[string]
		[Parameter( Mandatory = $true )]
		$NumberOfServers,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Time,
		
		[string]
		[Parameter( Mandatory = $false )]
		$graphiteTimeout = 30
		
	)

	If ( $ExceptionsList ) { $LoginsCount = "http://$GraphiteServer/render?target=aliasByNode(limit(maximumBelow(transformNull(exclude(*.logins.count, `"$ExceptionsList`"), 0), $Threshold), $NumberOfServers), 0)&from=$Time&format=csv" }
		
	Else { $LoginsCount = "http://$GraphiteServer/render?target=aliasByNode(limit(maximumBelow(transformNull(*.logins.count, 0), $Threshold), $NumberOfServers), 0)&from=$Time&format=csv" }
		
	$TryTime = 0
	
	Function Get-LoginStatsInternal {
		
		Try { 
			$TryTime++
			$Logins = Invoke-RestMethod $LoginsCount -TimeoutSec $graphiteTimeout
			$Logins = $Logins | ConvertFrom-Csv -Header "Name", "Date", "Value" | select Name -Unique | Sort Name	
			Return $Logins
		}
	
		Catch { 
			$_
		
			If ( $TryTime -lt 5 ) { Start-Sleep 30 ; Get-LoginStatsInternal }
			Else { break }
		}
	}
	
	Get-LoginStatsInternal
}
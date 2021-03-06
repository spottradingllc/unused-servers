Function Get-NetStats {

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
		$Time,
			
		[string]
		[Parameter( Mandatory = $false )]
		$graphiteTimeout = 30,
		
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		[ValidatePattern("Low|High")]
		$Sensitivity
		
	)
	
	If ( $Sensitivity -match "Low" ) { $Function = "averageBelow" }
	Else { $Function = "maximumBelow" }
	
	Write-Debug "Using $($Function) for $($Sensitivity) Sensitivity..."
	
	If ( $ExceptionsList ) { $NetworkKbOut = "http://$GraphiteServer/render?target=aliasByNode($Function(sumSeriesWithWildcards(transformNull(exclude($ComputerName.nettotals.kbout.*, `"$ExceptionsList`"), 0), 3), $Threshold), 0)&from=$Time&format=csv" }
																				   
	Else { $NetworkKbOut = "http://$GraphiteServer/render?target=aliasByNode($Function(sumSeriesWithWildcards(transformNull($ComputerName.nettotals.kbout.*, 0), 3), $Threshold), 0)&from=$Time&format=csv" }	
																 
	$TryTime = 0
		
	Function Get-NetStatsInternal {
			
		Try {
			$TryTime++
			$Network = Invoke-RestMethod $NetworkKbOut -TimeoutSec $graphiteTimeout 
			$Network = $Network | ConvertFrom-Csv -Header "Name", "Date", "Value" | select Name -Unique | Sort Name 
			Return $Network				
		}
			
		Catch { 
			$_
			
			If ( $TryTime -lt 5 ) { Start-Sleep 30 ; Get-NetStatsInternal }
			Else { break }
		}
	}
	 		
	Get-NetStatsInternal
}
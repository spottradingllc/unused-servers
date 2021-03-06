Function Get-CPUStats {

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
								
	If ( $ExceptionsList ) { $CPUTotalsUser = "http://$GraphiteServer/render?target=aliasByNode($Function(sumSeriesWithWildcards(transformNull(exclude($ComputerName.cputotals.user, `"$ExceptionsList`"), 0), 3), $Threshold), 0)&from=$Time&format=csv" }
	
	Else { $CPUTotalsUser = "http://$GraphiteServer/render?target=aliasByNode($Function(sumSeriesWithWildcards(transformNull($ComputerName.cputotals.user, 0), 3), $Threshold), 0)&from=$Time&format=csv" }
	
	$TryTime = 0
					
	Function Get-CPUStatsInternal {
								
		Try {
			$TryTime++
			$CPU = Invoke-RestMethod $CPUTotalsUser -TimeoutSec $graphiteTimeout
			$CPU = $CPU | ConvertFrom-Csv -Header "Name", "Date", "Value" | select Name -Unique | Sort Name
			Return $CPU
		}
			
		Catch { 
			$_ 
		
			If ( $TryTime -lt 5 ) { Start-Sleep 30 ; Get-CPUStatsInternal }
			Else { break }
		}
	}
	 		
	Get-CPUStatsInternal
}
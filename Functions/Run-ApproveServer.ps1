Function Run-ApproveServer {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$CacheName,
		
		[switch]
		[Parameter( Mandatory = $false )]
		$UseSaltCache
	)

	$Computers = ($ComputerName -split ",") -replace " ", ""
							
	$Computers | % {
	
		$SetUnused = Run-SetGrain -ComputerName $_ -DomainName $DomainName -SaltCommand grains.setval -SaltArguments "unused true"
		
		Write-Debug "SetUnused = $($SetUnused)"
		
		If ( $SetUnused -eq "True" ) { 
			If ( $UseSaltCache ) { $Refresh = Run-RefreshSaltCache -CacheName $CacheName -ComputerName $_ -DomainName $DomainName }
			Write-Host "Successfully approved $_." -ForegroundColor Green -BackgroundColor Black ; "" 
		}
		Else { Write-Host "Failed to approve $_... Restart salt-minion on that server." -ForegroundColor Red -BackgroundColor Black ; "" }
	}
 }
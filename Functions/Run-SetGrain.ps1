Function Run-SetGrain {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$SaltCommand,
		
		[string]
		[Parameter( Mandatory = $true )]
		$SaltArguments,
		
		[switch]
		[Parameter( Mandatory = $false )]
		$Quiet
	
	)

	$ComputerNameUp = $ComputerName.ToUpper()
	
	$ComputerNameLow = $ComputerName.ToLower()

	$SaltTargetUp = "$ComputerNameUp" + "." + $DomainName
	
	$SaltTargetLow = "$ComputerNameLow" + "." + $DomainName
							
	$SaltState = $SaltCommand
    						
    $SetGrain = salt $SaltTargetUp $SaltState $SaltArguments | salt-run
    						
	If ( $SetGrain.Result -match $False ) {

        # Up did not succeed
        
        $SetGrain = salt $SaltTargetLow $SaltState $SaltArguments | salt-run
        
        If ( (( $SetGrain.Result | Out-String ).Length -eq 2 -and $SetGrain.Result -notmatch $null) -or $SetGrain.Result -match $False ) {
                                        
            # Both Up and Low failed.
            If ( $Quiet ) { $Result = $false ; return $Result }
			
			Else { "" ; Write-Debug "Failed to run $($SaltCommand) $($SaltArguments) on $($ComputerName)" ; $Result = $false ; return $Result }
        }			

        Else {

            # Low succeeded.
			If ( $Quiet ) { $Result = $true ; return $Result }

			Else { $Result = $true ; return $Result }
        }
    }

    Else {

        # Up returned result.
		If ( ( $SetGrain.Result | Out-String ).Length -eq 2 -and $SetGrain.Result -notmatch $null ) {

            # Up returned empty result.

            If ( $Quiet ){ $Result = $false ; return $Result }

            Else { ""; Write-Debug "Failed to run $($SaltCommand) $($SaltArguments) on $($ComputerName)" ; $Result = $false ; return $Result }
        }

        Else {

            # Up succeeded
			If ( $Quiet ) { $Result = $true ; return $Result }

			Else { $Result = $true ; return $Result }
		}
    }
}
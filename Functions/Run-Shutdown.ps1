Function Run-Shutdown {

	[CmdletBinding(ConfirmImpact="High")] 

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$OS,
		
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName
	
	)
	
	$SaltTarget = $ComputerName + "." + $DomainName

    $SaltState = "cmd.run"
								
	If ($OS -match "CentOs|RedHat" ) { $SaltArguments = "shutdown -h now" }
    Else { $SaltArguments = "'shutdown /s /t 5'"  }

	Write-Debug "Shutting down $ComputerName with $SaltArguments command..."
	
	Try { 
		$Result = salt $SaltTarget $SaltState $SaltArguments | Salt-Run
		return $Result.Result
	}
	Catch { $_ ; break }
			
}
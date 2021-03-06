Function Run-CleanGraphite {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName, 
		
		[string]
		[Parameter( Mandatory = $true )]
		$GraphiteTarget
	
	)

	$saltTarget = $GraphiteTarget
								
	$RemoveComputer = $ComputerName
			
	$SaltState = "cmd.run"

	$SaltArguments = "rm -rf /opt/graphite/storage/whisper/" + $RemoveComputer
	
	$Result = salt $SaltTarget $SaltState $SaltArguments | salt-run

	return $Result
}
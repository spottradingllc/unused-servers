Function SetNewVMName {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Environment
	
	)

    $date = Get-Date -Format "yyyyMMdd"

    $NewName = $ComputerName + "-$date"

    Try { $Rename_Result = Rename-VM -OldName $ComputerName -NewName $NewName -Environment $Environment }
	
	Catch { $_ ; break }

 }
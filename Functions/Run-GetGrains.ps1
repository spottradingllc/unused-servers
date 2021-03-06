Function Run-GetGrains ( $ComputerName ) {
   
	$Result = @()
	
	$Grains = $null
	
	$SaltTargetUP = $ComputerName.ToUpper()
	$SaltTargetLow = $ComputerName.ToLower()

	$SaltState = "grains.item"
				
	$SaltArguments = "cpu_model,productname,kernelrelease,serialnumber,osrelease,os,virtual,unused"
					
	Try { 
		$Grains = salt -E "$SaltTargetUP|$SaltTargetLow" $SaltState $SaltArguments | salt-run
		$Result += $Grains.Result
		return $Result
	}
	
	Catch { $_ }
					
}
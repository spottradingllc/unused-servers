Function Test-ReverseDNS {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$Comp,
		
		[string]
		[Parameter( Mandatory = $true )]
		[ValidatePattern("\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]
		$IP
	
	)
				
	Try {
	
		$RealName = ([System.Net.Dns]::GetHostbyAddress($IP)).HostName

		If ( $RealName -match $Comp ) {
	    				
			Write-Debug "$Comp is online!" 
			
			$Return = New-Object PSObject -Property ([ordered]@{ "Error" = "None" ; "Result" = $True })
			
			return $Return

		}

		Else {

   			Write-Debug "$Comp is not online!"
			
			$Return = New-Object PSObject -Property ([ordered]@{ "Error" = "Incorrect DNS" ; "Result" = $False })
			
			return $Return

		}
	}
	
	Catch { 
	
		$_
		
		$Return = New-Object PSObject -Property ([ordered]@{ "Error" = "No Reverse DNS" ; "Result" = $True })
			
		return $Return
	}
}
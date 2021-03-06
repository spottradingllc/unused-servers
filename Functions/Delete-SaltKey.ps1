Function Delete-SaltKey {

	Param (
		
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$saltTarget,
		
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName
	
	)
	
    $SaltState = "cmd.run"

    $ComputerNameInt = $ComputerName + "." + $DomainName
	
	$SaltArguments = "salt-key -y -d $ComputerNameInt"
	
	$saltTargetInt = $saltTarget + "." + $DomainName
			
	$TestOnline = Test-Connection $ComputerNameInt -Quiet -Count 5 -ErrorAction SilentlyContinue
	
	$n = 0
		
	Function Delete-Internal {
	
		$n ++
			
		$ResultInt = salt $saltTargetInt $SaltState $SaltArguments | salt-run

		If ( $ResultInt.Result -notmatch $ComputerNameInt ) { 
		
			Write-Debug "Failed to delete Salt Key. Trying again: $($n) out of 5..."
			If ( $n -le 5 ) { Delete-Internal }
			Else { 
				
				Write-Debug "Failed to delete salt key for $($ComputerNameInt)!"
				return $ResultInt 
			}
		}
		
		Else { 
			Write-Debug "Successfully deleted Salt Key for $($ComputerNameInt)."
			return $ResultInt 
		}		
	}
	
	If ( ! $TestOnline ) { 
	
		Write-Debug "Deleteing salt key for $ComputerNameInt on $SaltTargetInt"
		$Result = Delete-Internal
	}

	Else { 
	
		$GetIP_S = (Test-Connection $ComputerNameInt -ErrorAction SilentlyContinue -Count 1).IPV4Address.IPAddressToString
		
		If ( $GetIP_S ) {
		
			$TestDNS_S = Test-ReverseDNS -Comp $ComputerNameInt -IP $GetIP_S
			
			If ( $TestDNS_S.Result ) {
	
				Write-Debug "$ComputerNameInt is still up, sleeping for 10 seconds and retrying salt key deletion..."
				Start-Sleep 10 ; Delete-SaltKey -ComputerName $ComputerName -saltTarget $saltTarget -DomainName $DomainName
			}
		
			Else {
		
				Write-Debug "$GetIP_S is being used by another server. Deleteing salt key for $ComputernameInt on $SaltTargetInt"
				$Result = Delete-Internal
					
			}
			
		}
		
		Else {
		
			Write-Debug "$ComputerNameInt is down. Deleteing salt key for $ComputernameInt on $SaltTargetInt"
			$Result = Delete-Internal
		
		}
	}
	
	return $Result.Result

}
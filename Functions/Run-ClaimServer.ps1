Function Run-ClaimServer {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$DomainName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$UserName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Password
	
	)

	$SkipErrors = $true

	$ComputerNameUp = $ComputerName.ToUpper()
	
	$ComputerNameLow = $ComputerName.ToLower()

	$SaltTargetUp = "$ComputerNameUp" + "." + $DomainName
	
	$SaltTargetLow = "$ComputerNameLow" + "." + $DomainName
							
	$SaltState = "cmd.run"

	If ($OS_Release -match "CentOs|RedHat" ) { $SaltArguments = "'su - $UserName -c /bin/true'" }
    Else { $SaltArguments = "'powershell schtasks /S localhost /Create /RU $DomainName\$UserName /RP $Password /SC ONCE /ST (Get-Date ((Get-Date).AddMinutes(1).ToShortTimeString()) -Format HH:mm) /Z /V1 /TN Claim_Server /TR ipconfig'"  }
						
    $Claim = salt $SaltTargetUp $SaltState $SaltArguments | salt-run
    						
	If ( $Claim.Result -match $False ) {

        # Up did not succeed
        
        $Claim = salt $SaltTargetLow $SaltState $SaltArguments | salt-run
        
        If ( (( $Claim.Result | Out-String ).Length -eq 2 -and $Claim.Result -notmatch $null) -or $Claim.Result -match $False ) {
                                        
            # Both Up and Low failed.
            
            If ( $Quiet ) { return $False }

            Else { 
                ""                
                Write-Host "Failed to claim " $ComputerName -BackgroundColor Black -ForegroundColor Red 
            }
        }			

        Else {

            # Low succeeded. Running verification.

            $Verify = VerifyClaim -ComputerName $SaltTargetLow -UserName $UserName
		
			If ( $Verify ) {
            
                # Running get login stats on the claimed server
			    $SaltState = "state.sls"
	
			    $SaltArguments = "graphite.get_login_stats"

                $PostLow = salt $SaltTargetLow $SaltState $SaltArguments
                                            
                If ( $Quiet ) { return $True }

                Else {
                    ""
	                Write-Host $ComputerName "claimed." -BackgroundColor Black -ForegroundColor Green
	                ""	
                }
            }

            Else {
                # ClaimServer did not succeed. Running again.
                Run-ClaimServer -ComputerName $ComputerName -DomainName $DomainName -UserName $UserName -Password $Password
            }
        }
    }

    Else {

        # Up returned result.

        If ( ( $Claim.Result | Out-String ).Length -eq 2 -and $Claim.Result -notmatch $null ) {

            # Up returned empty result.

            If ( $Quiet ) { return $False }

            Else { 
                ""
                Write-Host "Failed to claim " $ComputerName -BackgroundColor Black -ForegroundColor Red 
            }
        }

        Else {

            # Up succeeded
            # Runninng verification.

            $Verify = VerifyClaim -ComputerName $SaltTargetUp -UserName $UserName

            If ( $Verify ) {
                
                # Verification succeeded
	
			    # Running get login stats on the claimed server
			    $SaltState = "state.sls"
	
			    $SaltArguments = "graphite.get_login_stats"
                    
                $PostUp = salt $SaltTargetUp $SaltState $SaltArguments

                If ( $Quiet ) { return $True }

                Else {
                    ""
	                Write-Host $ComputerName "claimed." -BackgroundColor Black -ForegroundColor Green
	                ""	
                }
            }

            Else {
                #Verification did not succeed
                Run-ClaimServer -ComputerName $ComputerName -DomainName $DomainName -UserName $UserName -Password $Password
            }
        }
    }
}
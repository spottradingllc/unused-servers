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
		$Password,
		
		[string]
		[Parameter( Mandatory = $true )]
		$CacheName,

        [switch]
		[Parameter( Mandatory = $false )]
        $Quiet
	
	)

	$ComputerNameUp = $ComputerName.ToUpper()
	
	$ComputerNameLow = $ComputerName.ToLower()

	$SaltTargetUp = "$ComputerNameUp" + "." + $DomainName
	
	$SaltTargetLow = "$ComputerNameLow" + "." + $DomainName
							
	$SaltState = "cmd.run"
	
	$Grains = Run-GetGrainsCache -ComputerName $ComputerName -CacheName $CacheName -DomainName $DomainName
	
	$OS_Release = $Grains.os

	If ($OS_Release -match "CentOs|RedHat" ) { $SaltArguments = "'su - $UserName -c /bin/true'" }
    Else { $SaltArguments = "'powershell schtasks /S localhost /Create /RU `"$DomainName\$UserName`" /RP $Password /SC ONCE /ST (Get-Date ((Get-Date).AddSeconds(2).ToShortTimeString()) -Format HH:mm) /Z /V1 /TN Claim_Server /TR ipconfig'"  }
						
    $Claim = salt $SaltTargetUp $SaltState $SaltArguments | salt-run
    						
	If ( $Claim.Result -match $False ) {

        # Up did not succeed
        
        $Claim = salt $SaltTargetLow $SaltState $SaltArguments | salt-run
        
        If ( (( $Claim.Result | Out-String ).Length -eq 2 -and $Claim.Result -notmatch $null) -or $Claim.Result -match $False ) {
                                        
            # Both Up and Low failed.
            
            If ( $Quiet ) { }

            Else { 
                ""                
                Write-Host "Failed to login to $ComputerName..." -BackgroundColor Black -ForegroundColor Red 
            }
        }			

        Else {

            # Low succeeded. Running verification.

            $Verify = VerifyClaim -ComputerName $SaltTargetLow -UserName $UserName -OS $OS_Release
		
			If ( $Verify ) {
            
                # Running get login stats on the claimed server
			    $SaltState = "state.sls"
	
			    $SaltArguments = "graphite.get_login_stats"

                $PostLow = salt $SaltTargetLow $SaltState $SaltArguments
                                            
                If ( $Quiet ) { }

                Else {
                    ""
	                Write-Host "Logged in to $ComputerName..." -BackgroundColor Black -ForegroundColor Green
	                ""	
                }
            }

            Else {
                # ClaimServer did not succeed. Running again.
                Run-ClaimServer -ComputerName $ComputerName -DomainName $DomainName -UserName $UserName -Password $Password -CacheName $CacheName
            }
        }
    }

    Else {

        # Up returned result.

        If ( ( $Claim.Result | Out-String ).Length -eq 2 -and $Claim.Result -notmatch $null ) {

            # Up returned empty result.

            If ( $Quiet ) { }

            Else { 
                ""
                Write-Host "Failed to login to $ComputerName..." -BackgroundColor Black -ForegroundColor Red 
            }
        }

        Else {

            # Up succeeded
            # Runninng verification.

            $Verify = VerifyClaim -ComputerName $SaltTargetUp -UserName $UserName -OS $OS_Release

            If ( $Verify ) {
                
                # Verification succeeded
	
			    # Running get login stats on the claimed server
			    $SaltState = "state.sls"
	
			    $SaltArguments = "graphite.get_login_stats"
                    
                $PostUp = salt $SaltTargetUp $SaltState $SaltArguments

                If ( $Quiet ) { }

                Else {
                    ""
	                Write-Host "Logged in to $ComputerName..." -BackgroundColor Black -ForegroundColor Green
	                ""	
                }
            }

            Else {
                #Verification did not succeed
                Run-ClaimServer -ComputerName $ComputerName -DomainName $DomainName -UserName $UserName -Password $Password -CacheName $CacheName
            }
        }
    }
	
	Write-Debug "Checking for unused grain presence..."
	
	$SaltState = "grains.get"
	$SaltArguments = "unused"
	
	Write-Debug "Running salt -E $($SaltTargetUp)|$($SaltTargetLow) $($SaltState) $($SaltArguments)..."
	
	$CheckGrain = salt -E "$SaltTargetUp|$SaltTargetLow" $SaltState $SaltArguments | salt-run
	
	If ( $CheckGrain.Result -notmatch $null ) {
	
		Write-Debug "Removing unused grain..."
		
		$SaltState = "grains.delval"
		$SaltArguments = "unused destructive=true"
		
		Write-Debug "Running salt -E $($SaltTargetUp)|$($SaltTargetLow) $($SaltState) $($SaltArguments)..."
		
		$RemoveGrain = salt -E "$SaltTargetUp|$SaltTargetLow" $SaltState $SaltArguments | salt-run
		
		If ( ! $RemoveGrain.Result ) { 
			
			$Refresh = Run-RefreshSaltCache -CacheName $CacheName -ComputerName $ComputerName -DomainName $DomainName
			
			If ( $Quiet ) { return $True }
			Else { Write-Host "Claimed $ComputerName." -BackgroundColor Black -ForegroundColor Green }
		}
		
		Else { 
			If ( $Quiet ) { return $False }
			Else { Write-Host "Failed to claim $ComputerName..." -BackgroundColor Black -ForegroundColor Red }
		}
	}
	
	Else {  
		If ( $Quiet ) { return $True }
		Else { Write-Host "Claimed $ComputerName." -BackgroundColor Black -ForegroundColor Green  }
	}
}
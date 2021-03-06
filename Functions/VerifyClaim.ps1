Function VerifyClaim {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$UserName,
		
		[string]
		[Parameter( Mandatory = $true )]
		$OS
	)

   	If ( $Quiet ) {}

   	Else { Write-Host "Running verification process..." -BackgroundColor Black -ForegroundColor Green }
	
	$OS_Release = $OS

   	If ($OS_Release -match "CentOs|RedHat" ) { 
   
   		$ClaimVerify = Salt $ComputerName cmd.run "cat /var/log/secure | grep $UserName" | Salt-run
   	   
   		If ( $ClaimVerify.Result -match $UserName ) {
                
       		If ( $DebugPreference -match "Continue" ) { }
		    Else { cls }
                                                     
       		return $True
   		}

   		Else {

       		If ( $DebugPreference -match "Continue" ) { }
		    Else { cls }
                                                     
       		return $False
   		}
   	}
   
   	Else {
   
   		$ClaimVerify = Salt $ComputerName cmd.run "powershell `"(Get-EventLog -LogName Security -InstanceId 4624 -Newest 5 -ErrorAction SilentlyContinue -Message `"*$UserName*`").Count`"" | Salt-run
		
		If ( $ClaimVerify.Result -notmatch "\b0\b" ) {
                
       		If ( $DebugPreference -match "Continue" ) { }
		    Else { cls }
                                                     
       		return $True
                                               
   		}

   		Else {

       		If ( $DebugPreference -match "Continue" ) { }
		    Else { cls }
                                                     
       		return $False
   		}
   	}
}
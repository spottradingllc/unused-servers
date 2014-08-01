Function Get-UnusedServers {

<#

.Synopsis

Get-UnusedServers uses Graphite, Salt and Zookeeper to determine which servers are not being used.

.Description

Get-UnusedServers uses data that collectl and custom python script send to Graphite to determine which servers are not being 
used and can be re-used. The process is outlined below:

1. Collectl sends data (CPU, Network and Disk utilizations) to Graphite server.

2. Python script is scheduled (with Salt) to run on all Linux servers to send number of logins on the server during the day 
to Graphite. It is very important to understand that 'root' login is not counted as active login. Script assumes that we always 
use domain accounts to login and manage our servers (including running our services under domain user accounts).

3. The script then gets average nettotals.kbout below 3 KB for all servers and selects first 100 servers with lowest average 
value among the entire dataset for the last 29 days.

4. Then the script determines if these 100 servers also exist in lowest average CPU dataset (average CPU utilization below 2%) 
and lowest average Logins dataset (maximum below 0.001 logins during 29 days).

5. If the server does not exist in CPU or Logins dataset it is declared as false positive and nothing else is done for this 
particular server.

6. If the server does exist in all 3 datasets than it is declared unused.

7. Based on the script parameters the following actions will take place:

a. The script determines properties of the server in question by using Salt (CPU, hardware, OS, kernel version etc.)

b. OS and kernel versions match our standard (<your linux version> with <your kernel>):

If this is a physical server and we declare that this server is ready to be reused as it is in compliance with our standard.

If this is a virtual machine – we shut it down and rename to make sure VM is deleted by automated process after two weeks 
of being shut down.

c. If OS and kernel do not match our standard:

Physical server – we display it in a different section of the report stating that the server must be rebuild with our standard 
OS before it can be used again.

Virtual machine - we shut it down and rename to make sure VM is deleted by automated process after two weeks of being shut down.

d. If server does not respond to pings we determine that it was either rebuild or decommissioned and we delete its data from 
graphite and salt so next time it does not appear in the results or we just mention this in the result without doing anything.

Get-UnusedServers supports exceptions to make sure we do not take servers that are being used. Zookeeper is being used to keep 
these exceptions.

Get-UnusedServers also supports three different methods of output – console, email or quiet (so we can use output in other 
script, like Create-VM).

Get-UnusedServers also supports claiming servers as being used to make sure nobody else takes that server if we decided to use 
it.

.Parameter DeprecateVMs

Denotes whether to shut down virtual machines and rename them so another script can decommission them after two weeks of being 
offline.
This will also create Jira tickets for change tracking.

.Parameter ClaimServer

Denotes whether we want to claim a server as being used to start using it. This will use Salt API to login to the server with 
the special account. This way number oflogins will be more than our set threshold and the server will no longer appear in the 
report of unused servers (for the next 29 days). If the server isnot being used after 29 days it will go back to the list of 
unused servers.

.Parameter AddException

Allows us to add exception for the server so it will be skipped during unused servers script logic. It requires Description 
parameter.

.Parameter Description

Provides description for the exception. Needs to be enclosed in quotes.

.Parameter RemoveException

Allows us to remove exception for the server.

.Parameter ListExceptions

Allows us to list current exceptions.

.Parameter Email

Denotes whether to send results in the email (good for automated processes). 

.Parameter Quiet

Denotes whether to display any errors or format results – good for other scripts to use output for processing.

.Parameter Environment

Denotes environment we work with. Can be Staging, UAT or Production. Default value is Staging.

.Example

Get-UnusedServers -Environment Staging

This will display all unused servers in Staging environment but will not clean Graphite, Salt or shut down virtual machines.

.Example

Get-UnusedServers -Environment Production -DeprecateVMs –Email

This will send email report with all unused servers and also shutdown and rename all unused virtual machines. 
It will also delete all Graphite and Salt data for the servers that do not respond to pings.
Jira tickets will also be created for VMs shutdown, renaming and for removing Graphite and Salt data.

.Example

Get-UnusedServers -ClaimServer TestServer01

Claims TestServer01 as being used so it will not appear in the report next time.

.Example

Get-UnusedServers -AddException TestServer02 -Description “Test server” -Environment Staging

This will add TestServer02 with the description “Test server” to the list of the exceptions so this server will be skipped by 
the Get-UnusedServers logic.

.Example

Get-UnusedServers -RemoveException TestServer02 -Environment Staging

This will remove TestServer02 from the list of exceptions in Staging.

.Example

Get-UnusedServers –ListExceptions –Environment UAT

This will list all exceptions in UAT environment.

#>

[CmdletBinding(SupportsShouldProcess = $false, DefaultParameterSetname = "Clean_Ready_Deprecate_Rebuild", ConfirmImpact="Medium")] 

Param (

	[Parameter(ParameterSetName = "Clean_Ready_Deprecate_Rebuild")]
	[switch]
	$DeprecateVMs,

	[Parameter(ParameterSetName = "Claim_Server")]
	[string]
	$ClaimServer,

	[Parameter(ParameterSetName = "Add_Exception", Mandatory = $true )]
	[string]
	$AddException,
	
	[Parameter(ParameterSetName = "Add_Exception", Mandatory = $true)]
	[string]
	$Description,
	
	[Parameter(ParameterSetName = "Remove_Exception")]
	[string]
	$RemoveException,
	
	[Parameter(ParameterSetName = "List_Exceptions")]
	[switch]
	$ListExceptions,
	
	[Parameter(ParameterSetName = "Results_By_Email")]
	[Parameter(ParameterSetName = "Clean_Ready_Deprecate_Rebuild")]
	[switch]
	$Email,
	
	[Parameter(ParameterSetName = "Results_Quiet")]
	[Parameter(ParameterSetName = "Claim_Server")]
	[Parameter(ParameterSetName = "Clean_Ready_Deprecate_Rebuild")]
	[switch]
	$Quiet,
		
	[string]
	[Parameter(ParameterSetName = "Clean_Ready_Deprecate_Rebuild", Mandatory = $true )]
	[Parameter(ParameterSetName = "Results_By_Email", Mandatory = $true )]
	[Parameter(ParameterSetName = "Results_Quiet", Mandatory = $true )]
	[Parameter(ParameterSetName = "Add_Exception", Mandatory = $true )]
	[Parameter(ParameterSetName = "Remove_Exception", Mandatory = $true )]
	[Parameter(ParameterSetName = "List_Exceptions", Mandatory = $true )]
	[Parameter(ParameterSetName = "Claim_Server", Mandatory = $true)]
	[ValidatePattern("Staging|UAT|Production")]
	$Environment

)

Begin {

	$ErrorActionPreference = "Stop"
	
	$originalColor = $Host.UI.RawUI.ForegroundColor
	$originalBackColor = $Host.UI.RawUI.BackgroundColor

	Switch -regex ( $Environment ) {
	
		"Staging" { 
			
			$saltMaster = "<Salt Master in Staging>" 
			$GraphiteServer = "<Graphite server in Staging>"
		}
		
		"UAT" { 
		
			$saltMaster = "<Salt Master in UAT>" 
			$GraphiteServer = "<Graphite server in UAT>"
		}
		
		"Production" { 
		
			$saltMaster = "<Salt Master in Production>" 
			$GraphiteServer = "<Graphite server in Production>"
		}	
	}
	
	
	
	$Time = "-29days"
	$NumberOfServers = "<Number of servers to analyze>"
	
	$global:EmailBody = @()
	$global:EmailErrors = @()
			
	$global:ResultDeprecate = @()
	$global:ResultReadyForDeployment = @()
	$global:ResultRebuild = @()
	$global:ZookeeperResult = @()

    #For Jira Ticket
    $global:Shutdown_Jira_A = ""
    $global:Salt_Graphite_Clean = ""
    
    Salt-Connect $saltMaster
			
	$ExhibitorAuth = @{ 

		"Authorization" = "Basic <your password hash here>"
	
	}
	
	Function Get-ZookeeperNode {
	
		Switch -regex ( $Environment ) {
	
			"Staging" { $Zoo = @("<staging zookeeper node 01>", "<staging zookeeper node 02>", "<staging zookeeper node 03>", "<staging zookeeper node 04>", "<staging zookeeper node 05>") }
		
			"UAT" { $Zoo = @("<UAT zookeeper node 01>", "<UAT zookeeper node 02>", "<UAT zookeeper node 03>", "<UAT zookeeper node 04>", "<UAT zookeeper node 05>") }
	
			"Production" { $Zoo = @("<Production zookeeper node 01>", "<Production zookeeper node 02>", "<Production zookeeper node 03>", "<Production zookeeper node 04>", "<Production zookeeper node 05>") }
		}
		
			
	
			Do {
	
				$ZooNodeTry = $Zoo | Get-Random
		
				$Connection = Test-Connection $ZooNodeTry -Quiet -Count 1
		
				If ( $Connection ) {
			
					$global:ZooNode = $ZooNodeTry
			
				}
		
				Else {
		
					Write-Host $ZooNodeTry "is down! Searching for another one."
									
				}
			}
	
			Until ( $ZooNode )
			
		}
		
	If ( $PSBoundParameters.ContainsKey('ClaimServer') ) { }
	
	ElseIf ( $PSBoundParameters.ContainsKey('RemoveException') ) {
	
		Get-ZookeeperNode
		
		$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/znode/UnusedServersException/" + $RemoveException
		
		$Message = Invoke-RestMethod -Uri $Uri -Method Delete -Header $ExhibitorAuth
		
		If ( $Message.message -match "OK") {
			
				Write-Host $RemoveException "was removed from the list of the exceptions." -BackgroundColor Black -ForegroundColor Green
				""
			
			}
			
		Else {
		
				Write-Host $RemoveException "was not found in the list of the exceptions." -BackgroundColor Red -ForegroundColor Yellow
				""
			
		}	
	}
	
	ElseIf ( $PSBoundParameters.ContainsKey('AddException') ) {
	
		Function Create-ZooException {
		
			Get-ZookeeperNode
			
			Function ConvertTo-Hex ($String) {

				$StringBytes = [System.Text.Encoding]::UTF8.GetBytes($String)

				# Iterate through bytes, converting each to the hexidecimal equivalent
				$hexArr = $StringBytes | ForEach-Object { $_.ToString("X2") }

				# Join the hex array into a single string for output
				$global:Hex = $hexArr -join ''

			}

			ConvertTo-Hex $Description
			
			$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/znode/UnusedServersException/" + $AddException
			
			$Message = Invoke-RestMethod -Uri $Uri -Method Put -Header $ExhibitorAuth -Body $Hex
			
			If ( $Message.message -match "OK") {
			
				Write-Host $AddException "was added to the list of exceptions." -BackgroundColor Black -ForegroundColor Green
				""
			
			}
			
			Else {
			
				Write-Host "Error!" -BackgroundColor Red -ForegroundColor Yellow
			
			}
		
		}
		
		Create-ZooException 
	
	}
	
	ElseIf ( $PSBoundParameters.ContainsKey('ListExceptions') ) {
	
		Get-ZookeeperNode
				
		$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/node?key=/UnusedServersException"

		$Exceptions = Invoke-RestMethod -Uri $Uri -Method Get -Header $ExhibitorAuth
		
		$Exceptions | % {

			$ZooTemp = @{}

			$Uri2 = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/node-data?key=" + $_.key
	
			$ZooTemp.Description = (Invoke-RestMethod -Uri $Uri2 -Method Get -Header $ExhibitorAuth).str
	
			$ZooTemp.Name = $_.title
	
			$global:ZookeeperResult += New-Object PSObject -Property $ZooTemp
			
		}
		
		$global:ZookeeperResult = $ZookeeperResult | ft -AutoSize 
		
		""
		Write-Host "Current Exceptions:" -BackgroundColor Black -ForegroundColor Green
		Write-Host "                   " -BackgroundColor Black -ForegroundColor Green
		
		$ZookeeperResult | % {
		
			$Host.UI.RawUI.ForegroundColor = "Green"; $Host.UI.RawUI.BackgroundColor = "Black"; $_
		
		}
									
		""
		
		$global:ZookeeperResult = $null
		
		$Host.UI.RawUI.ForegroundColor = $originalColor
		$Host.UI.RawUI.BackgroundColor = $originalBackColor
	}
	
	Else {
				
		Get-ZookeeperNode
				
		$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/node?key=/UnusedServersException"

		$Exceptions = Invoke-RestMethod -Uri $Uri -Method Get -Header $ExhibitorAuth
				
		If ( $Exceptions ) {
		
			Switch ( $Exceptions.Count ) {
			
				"1" { $global:ExceptionsList = $Exceptions.Title }
				
				default { $global:ExceptionsList = $Exceptions.Title -join "|" }
			
			}
		
		}
	
		# Get Network Stats
		
		#Threshold in KB
		$NetThreshold = "3.0"
		
		#With exceptions
		If ( $ExceptionsList ) {
					
			$global:NetworkKbOut = "http://$GraphiteServer/render?target=aliasByNode(limit(maximumBelow(transformNull(exclude(*.nettotals.kbout,`"$ExceptionsList`"),0),$NetThreshold),$NumberOfServers),0)&from=$Time&format=csv"
		
		}
		
		#No exceptions
		Else {
				
			$global:NetworkKbOut = "http://$GraphiteServer/render?target=aliasByNode(limit(averageBelow(transformNull(*.nettotals.kbout,0),$NetThreshold),$NumberOfServers),0)&from=$Time&format=csv"
		
		}
		
		$Network = Invoke-RestMethod $NetworkKbOut
		$Network = $Network | ConvertFrom-Csv -Header "Name","Date","Value" | select Name -Unique | Sort Name
		
		Write-Debug "Network:"
					
	}
	
	If ( $PSBoundParameters.Count -eq 1 -and $PSBoundParameters.ContainsKey('Environment') ) {
	
		$PSBoundParameters['Deprecate'] = "No"
							
	}
		
	ElseIf ( $PSBoundParameters.ContainsKey('Email') -and ! $PSBoundParameters.ContainsKey("Deprecate") ) {
	
		$PSBoundParameters['Deprecate'] = "No"
					
	}
	
	ElseIf ( $PSBoundParameters.ContainsKey('Email') -and ! $PSBoundParameters.ContainsKey("Deprecate") ) {
	
		$PSBoundParameters['Deprecate'] = "No"
	
	}
			
	Else { }
	
	Function Run-GetGrains ( $ComputerName ) {
	   
		$global:Grains = $null
				
		$SaltTargetUP = $ComputerName.ToUpper()
		$SaltTargetLow = $ComputerName.ToLower()

		$SaltState = "grains.item"
					
		$SaltArguments = "cpu_model,productname,kernelrelease,serialnumber,osrelease,osfullname,virtual"
						
		$global:Grains = salt -E "$SaltTargetUP|$SaltTargetLow" $SaltState $SaltArguments | salt-run
						
	}
	
	Function Run-CleanServer ( $ComputerName ) {
	
		$SaltTarget = "$ComputerName*"
					
		$SaltState = "state.sls"
	
		$SaltArguments = "servers.clean"
				
		$Clean = salt $SaltTarget $SaltState $SaltArguments | Salt-Run

	}
	
	Function Run-CleanGraphite ( $ComputerName ) {
	
		Switch -regex ( $GraphiteServer ) {
		
			"graphiteStaging" { $SaltTarget = "<Staging graphite server>*" }
			
			"graphiteUAT" { $SaltTarget = "<UAT Graphite server>*" }
			
			"graphiteProduction" { $SaltTarget = "<Production Graphite server>*" }
		
		}
					
		$RemoveComputer = $ComputerName
				
		$SaltState = "cmd.run"
	
		$SaltArguments = "rm -rf /opt/graphite/storage/whisper/" + $RemoveComputer
		
		$Result = salt $SaltTarget $SaltState $SaltArguments | salt-run

        If ( $Result.Result -match $null ) {
                                
            $global:Salt_Graphite_Clean = $global:Salt_Graphite_Clean + $ComputerName + " ; "

        }
				
	}

    Function Delete-SaltKey ( $ComputerName ) {

        Switch -regex ( $saltMaster ) {

            "saltStaging" { $SaltTarget = "<Staging salt master>*" }

            "saltUAT" { $SaltTarget = "<UAT salt master>*" }

            "saltProduction" { $SaltTarget = "Production salt master>*" }

        }

        $SaltState = "cmd.run"

        $SaltArguments = "salt-key -y -d $ComputerName*"

        $Result = salt $saltTarget $SaltState $SaltArguments | salt-run

    }
	
	Function Run-Shutdown ( $ComputerName ) {
	
		$SaltTarget = "$ComputerName*"
								
		$SaltState = "cmd.run"
	
		$SaltArguments = "shutdown -h now"
		
		$Result = salt $SaltTarget $SaltState $SaltArguments
			
	}
		
	Function Run-ClaimServer ( $ComputerName ) {
	
		$global:SkipErrors = $true
	
		$ComputerNameUp = $ComputerName.ToUpper()
		
		$ComputerNameLow = $ComputerName.ToLower()
	
		$SaltTargetUp = "$ComputerNameUp*"
		
		$SaltTargetLow = "$ComputerNameLow*"
								
		$SaltState = "cmd.run"
	
		$SaltArguments = "'su - svc.build -c /bin/true'"
				
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

                $Verify = VerifyClaim $SaltTargetLow
			
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

                    Run-ClaimServer $ComputerName

                }
            }
        }

        Else {
            
            If ( ( $Claim.Result | Out-String ).Length -eq 2 -and $Claim.Result -notmatch $null ) {

                If ( $Quiet ) { return $False }

                Else { 
                    
                    ""
                    Write-Host "Failed to claim " $ComputerName -BackgroundColor Black -ForegroundColor Red 
                }

            }

            Else {

                # Runninng verification.

                $Verify = VerifyClaim $SaltTargetUp

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

                    Run-ClaimServer $ComputerName

                }
            }
        }
 	}

    Function VerifyClaim ( $ComputerName ) {

        If ( $Quiet ) {}

        Else { Write-Host "Running verification process..." -BackgroundColor Black -ForegroundColor Green }
    
       $ClaimVerify = Salt "$ComputerName*" cmd.run "cat /var/log/secure | grep <account to verify>" | Salt-run

       If ( $ClaimVerify.Result -match "<account to verify>" ) {
                    
           cls
                                                         
           return $True
                                                   
       }

       Else {

           cls
                                                         
           return $False

       }

    }

    Function SetNewVMName {

      $date = Get-Date -Format "yyyyMMdd"

      $NewName = $ComputerName + "-$date"

      $Rename_Result = Rename-VM -OldName $ComputerName -NewName $NewName -Environment $Environment

      If ( $Rename_Result.Result ) {
        
        $Shutdown_Jira_H = "Rename $ComputerName to $NewName and shut it down ; "

        $global:Shutdown_Jira_A = $global:Shutdown_Jira_A + $Shutdown_Jira_H

      }

      Else { return $False }

    }
	
	Function SendEmail ( $EmailBody ) {

		Switch -regex ( $Environment ) {
		
			"Staging" { $emailSubject = "---> Unused Servers in Staging...." }
			
			"UAT" { $emailSubject = "---> Unused Servers in UAT...." }
			
			"Production" { $emailSubject = "---> Unused Servers in Production...." }
		
		}
			
	
		$Body = $EmailBody | Out-String
			
		   Send-MailMessage -From "<From email>" -To "<To email>" -Cc "<CC email>" -Priority High -Subject $emailSubject -Body $Body -SmtpServer "<SMTP server name>"
	}
	
	Function ServerDown ( $Comp, $HashLocal ) {	
	
		Write-Debug "$ComputerName is down"
						
			$HashLocal.ComputerName = $Comp
			$HashLocal.Online = "No"
			$HashLocal.Model = "N/A"
			$HashLocal.SerialNumber = "N/A"
			$HashLocal.OS = "N/A"
			$HashLocal.Kernel = "N/A"
			$HashLocal.CPU = "N/A"
														
			If ( $DeprecateVMs ) {
																	
				Run-CleanGraphite $Comp
                  
                Delete-SaltKey $Comp
						
			    $HashLocal.CleanGraphite = "Yes"
                    
                $HashLocal.DeleteKey = "Yes"
								
		    }
								
			Else { 

                $HashLocal.CleanGraphite = "No" 

                $HashLocal.DeleteKey = "No"
                
            }
					
										
			$global:ResultDeprecate += New-Object PSObject -Property $HashLocal
	
	}
	
	Function TestReverseDNS ( $Comp, $IP ) {
				
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
}

Process {

	If ($PSBoundParameters.ContainsKey('ClaimServer')) {
	 		
		Run-ClaimServer $ClaimServer
	}
			
	ElseIf ( $PSBoundParameters.ContainsKey('RemoveException') ) { }
	
	ElseIf ( $PSBoundParameters.ContainsKey('AddException') ) { }
	
	ElseIf ( $PSBoundParameters.ContainsKey('ListExceptions') ) { }
	
	Else {
	
		Write-Debug "Getting CPU stats"
		
		$CPUThreshold = "2"
				
		$CPUTotalsUser = "http://$GraphiteServer/render?target=aliasByNode(limit(maximumBelow(transformNull(*.cputotals.user,0),$CPUThreshold),$NumberOfServers),0)&from=$Time&format=csv"
		$CPU = Invoke-RestMethod $CPUTotalsUser
		$CPU = $CPU | ConvertFrom-Csv -Header "Name","Date","Value" | select Name -Unique
		$CPUName = $CPU.Name
						
		Write-Debug "Getting Login stats"
					
		$LoginsThreshold = "0.001"
		
		$LoginsCount = "http://$GraphiteServer/render?target=aliasByNode(limit(maximumBelow(transformNull(*.logins.count,0),$LoginsThreshold),$NumberOfServers),0)&from=$Time&format=csv"
		$Logins = Invoke-RestMethod $LoginsCount
		$Logins = $Logins | ConvertFrom-Csv -Header "Name","Date","Value" | select Name -Unique | Sort Name	
		$LoginsName = $Logins.Name
		
		$Network | % {
		
			#Error handling
			trap {
	
				If ( $_.Exception.Message -match "Error due to lack of resources" ) {

					If ( $Email ) { 
									
						$global:EmailErrors += "$ComputerName --> Did not get grains! Please verify that salt-minion is running on that server or that Salt API is not having issues."
									
					}
									
					Else {
								
						Write-Host "Did not get reverse DNS for $ComputerName!" -BackgroundColor Black -ForegroundColor Red 
									
					}
				}
						
				continue
			}
				
			$Error.Clear()
		
			$Hash = @{}

			$global:ComputerName = $_.Name
			
			Write-Debug $ComputerName
			
			If ( $CPUName -notcontains $ComputerName -and $LoginsName -notcontains $ComputerName ) {
			
				Write-Debug "$ComputerName - false positive"
			
			}
			
			Else {

				If ( $CPUName -contains $ComputerName -and $LoginsName -contains $ComputerName ) {
				
					Write-Debug "$ComputerName is not being used"
	
					If ( Test-Connection $ComputerName -Quiet -Count 1 ) {
					
						$GetIP = (Test-Connection $ComputerName -Count 1).IPV4Address.IPAddressToString
		
						$TestDNS = TestReverseDNS $ComputerName $GetIP
				
						If ( $TestDNS.Result ) { 
						
							Write-Debug "$ComputerName is online."
							
							Write-Debug "Getting grains for $ComputerName"

							Run-GetGrains $ComputerName
							
							If ( ($Grains.Result | Out-String).Length -ne 2 -and $Grains.Result -notmatch "Welcome" -and $Grains.Result -notmatch $False ) {
									
								Write-Debug $Grains.Result.productname
								Write-Debug $Grains.Result.kernelrelease
								Write-Debug $Grains.Result.serialnumber
								Write-Debug $Grains.Result.osrelease
								Write-Debug $Grains.Result.osfullname
								Write-Debug $Grains.Result.cpu_model
								Write-Debug $Grains.Result.virtual
																					
								$ProductName = $Grains.Result.productname
								$KernelRelease = $Grains.Result.kernelrelease
								$SerialNumber = $Grains.Result.serialnumber
								$OSRelease = $Grains.Result.osrelease
								$OSFullName = $Grains.Result.osfullname
								$CPUModel = $Grains.Result.cpu_model
								$Virtual =  $Grains.Result.virtual
					
								$Os = "$OSFullName " + $OSRelease
															
								$Hash.ComputerName = $ComputerName
								$Hash.Online = "Yes"
								
								Switch -regex ( $ProductName ) {

									"VMware" { $Hash.Model = "VMware" }
		
									default { 

	                                       If ( $ProductName.Length -le 20 ) { }

	                                       Else { $ProductName = $ProductName.Substring(0,20) }

	                                       $Hash.Model = $ProductName 
	                                }

								}
															
								Switch -regex ( $Virtual ) {
								
									"physical" { $Hash.SerialNumber = $SerialNumber }
									
									"VMware" { $Hash.SerialNumber = "N/A" }
												
								}
								
								$Hash.OS = $Os
								
								$Hash.Kernel = $KernelRelease
														
								$CPUModel -match "CPU (.*)" | Out-Null

								$CPU = $Matches[1]
								
								$CPU = $CPU.TrimStart( " " )
								
								$Hash.CPU = $CPU
																			
								If ( $Os -match "<your linux version>" -and $KernelRelease -match "<your kernel version>" ) {
								
	                                # For all servers that are compliant with <you linux version> and kernel version
	                                    
	                                If ( $DeprecateVMs ) {

	                                    # Shutting down unused VMs.

	                                    If ( $Virtual -match "VMware" ) {

	                                        SetNewVMName
	                                                                           
	                                        Run-Shutdown $ComputerName
	                                        	                                        
										    $Hash.Shutdown = "Yes"

	                                    }

	                                    Else {

	                                        # Not touching physical servers
	                                        
	                                        $Hash.Shutdown = "No"

	                                    }
	                                    
	                                    $global:ResultReadyForDeployment += New-Object PSObject -Property $Hash
	                                }
	                                
	                                Else {

	                                    # $DeprecateVMs is not specified
	                                                                   
	                                    $Hash.Shutdown = "No"

	                                    $global:ResultReadyForDeployment += New-Object PSObject -Property $Hash
	                                
	                                }    
	                                
	                                    							
								}
								
								Else {

	                                 # For all servers that are not compliant with <your linux version> and kernel version.

	                                If ( $DeprecateVMs ) {
	                                    
	                                    # Shutting down Virtual Machines if they are not being used (physical will stay up)
	                                    
	                                    If ( $Virtual -match "VMware" ) {

	                                        SetNewVMName

	                                        Run-Shutdown $ComputerName
	                                        	                                        
										    $Hash.Shutdown = "Yes"

	                                    }

	                                    Else {

	                                        # Not touching physical servers
	                                        
	                                        $Hash.Shutdown = "No"

	                                    }


	                                    $global:ResultRebuild += New-Object PSObject -Property $Hash


	                                }


	                                Else {
	                                    
	                                    # DeprecateVMs is not present. 
	                                
	                                    $Hash.Shutdown = "No"

	                                    $global:ResultRebuild += New-Object PSObject -Property $Hash                               
	                                
	                                }
								
								}
						
							}
							
							Else {
							
								If ( $Quiet ) {
								
									#Do nothing
								}
								
								Else {
							
									If ( $Email ) { 
									
										$global:EmailErrors += "$ComputerName --> Did not get grains! Please verify that salt-minion is running on that server or that Salt API is not having issues."
									
									}
									
									Else {
								
										Write-Host "Did not get grains for $ComputerName. Please verify that salt-minion is running on that server or that Salt API is not having issues!" -BackgroundColor Black -ForegroundColor Red 
									
									}
								
								}
								
							}
							
						}
				
						Else {
				
							Write-Debug "$ComputerName is down. $GetIP is used by another server."
					
							ServerDown $ComputerName $Hash
							
						}
					}

					Else {
					
						Write-Debug "$ComputerName is offline."
			
						ServerDown $ComputerName $Hash
				    }
				
                }

				Else {
				
					Write-Debug "$ComputerName - false positive!"
				
			    }
		    }
	    }
    }
}

End {

If ( $Quiet ) {

	# For Creat-VM script

	$global:ResultReadyForDeployment = $ResultReadyForDeployment | ? { $_.Model -match "VMware" } | Sort ComputerName -Descending
	
	$ResultReadyForDeployment

}

Else {

	If ( $Email ) {
	
		If ( $EmailErrors ) {
		
			$global:EmailBody += "----> Errors occured! <----"		
			$global:EmailBody += " "
			$global:EmailBody += $EmailErrors
			$global:EmailBody += " "
		
		}
	
	}

	If ( $ResultDeprecate.Count -ne 0 ) {
	
		If ( $Email ) {
						
			$ResultDeprecate = $ResultDeprecate | Sort Model, ComputerName -Descending
			
			$global:EmailBody += "--> Offline Servers. Please remove monitoring. <--"
			$global:EmailBody += " "
			
			$global:EmailBody += "{0, -30} {1, -18} {2, -18}" -f "Server", "Graphite_Cleaned", "Salt_Key_Deleted"	
			
			$ResultDeprecate | % { 
	
					$global:EmailBody += "{0, -19} {1, -18} {1, -18}" -f $_.ComputerName, $_.CleanGraphite, $_.DeleteKey
		
			}
			
			$global:EmailBody += " "
		
		}

		Else {
			
			""
			Write-Host "--> Offline Servers. Please remove monitoring. <--" -ForegroundColor Red -BackgroundColor Black
			Write-Host "--------------------------------------------------" -ForegroundColor Red -BackgroundColor Black
			Write-Host "                                                  " -ForegroundColor Red -BackgroundColor Black
								
				$ResultDeprecate = $ResultDeprecate | Sort Model, ComputerName -Descending
			  
				$Host.UI.RawUI.ForegroundColor = "Red"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -18} {2, -16}" -f "Server", "Graphite_Cleaned", "Salt_Key_Deleted"

				$ResultDeprecate | % { 
	
					$Host.UI.RawUI.ForegroundColor = "Red"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -18} {2, -16}" -f $_.ComputerName, $_.CleanGraphite, $_.DeleteKey
		
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
				
				""
		}
	}
	
	If ( $ResultRebuild.Count -ne 0 ) {
	
		If ($PSBoundParameters.ContainsKey('DeprecateVMs')) {
		
			If ( $Email ) {
									
				$ResultRebuild = $ResultRebuild | Sort Model, ComputerName -Descending
				
				If ( $DeprecateVMs ) {
														
					$global:EmailBody += "Unused VMs were shutdown. Please verify that VMs are not needed."
					$global:EmailBody += "Notify IT if you need to reenable VM (it will be kept offline for two weeks and then deleted)"
                    $global:EmailBody += "Rebuild physical servers with the old OS."
					$global:EmailBody += " "
						
				}

                Else {
				
						$global:EmailBody += " -------> Servers with an old OS. <------- "
						$global:EmailBody += " ----------------------------------------- "
						$global:EmailBody += " "
				}
				
			
				$global:EmailBody += "{0, -30} {1, -25} {2, -34} {3, -20} {4, -18}" -f "Server", "OS", "Model", "Serial #", "Shutdown"
				
				$ResultRebuild | % { 
	
					$global:EmailBody += "{0, -19} {1, -16} {2, -30} {3, -22} {4, -18}" -f $_.ComputerName, $_.OS, $_.Model, $_.SerialNumber, $_.Shutdown
		
				}
				
				$global:EmailBody += " "
							
			}

			Else {
		
                If ( $DeprecateVMs ) { 
					
					""
					Write-Host " --------> Unused VMs were shutdown. <------- " -ForegroundColor Yellow -BackgroundColor Black
					Write-Host " --------> Rebuild physical servers. <------- "
                    Write-Host "                                              " -ForegroundColor Yellow -BackgroundColor Black
			    }
				
				Else {
					
						""
						Write-Host " -------> Servers with an old OS. <------- " -ForegroundColor Yellow -BackgroundColor Black
						Write-Host " ----------------------------------------- " -ForegroundColor Yellow -BackgroundColor Black
						Write-Host "                                           " -ForegroundColor Yellow -BackgroundColor Black
				}
												
				$ResultRebuild = $ResultRebuild | Sort Model, ComputerName -Descending
			  
				$Host.UI.RawUI.ForegroundColor = "Yellow"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -11} {2, -20} {3, -11} {4, -8}" -f "Server", "OS", "Model", "Serial #", "Shutdown"

				$ResultRebuild | % { 
	
					$Host.UI.RawUI.ForegroundColor = "Yellow"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -11} {2, -20} {3, -11} {4, -8}" -f $_.ComputerName, $_.OS, $_.Model, $_.SerialNumber, $_.Shutdown
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
				
				""
			}
		
		}
		
		Else {
		
			""
			Write-Host " -------> Servers with an old OS. <------- " -ForegroundColor Yellow -BackgroundColor Black
			Write-Host " ----------------------------------------- " -ForegroundColor Yellow -BackgroundColor Black
			Write-Host "                                           " -ForegroundColor Yellow -BackgroundColor Black
				
			$ResultRebuild = $ResultRebuild | Sort Model, ComputerName -Descending
			  
			$Host.UI.RawUI.ForegroundColor = "Yellow"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -11} {2, -20} {3, -11} {4, -8}" -f "Server", "OS", "Model", "Serial #", "Shutdown"

			$ResultRebuild | % { 
	
				$Host.UI.RawUI.ForegroundColor = "Yellow"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -11} {2, -20} {3, -11} {4, -8}" -f $_.ComputerName, $_.OS, $_.Model, $_.SerialNumber, $_.Shutdown
			}

			$Host.UI.RawUI.ForegroundColor = $originalColor
			$Host.UI.RawUI.BackgroundColor = $originalBackColor
				
			""
		}
	}
	
	If ( $ResultReadyForDeployment.Count -ne 0 ) {
	
			If ( $Email ) {
								
				$ResultReadyForDeployment = $ResultReadyForDeployment | Sort Model, ComputerName -Descending
								
				$global:EmailBody += "Servers are not used. Unused VMs were shutdown. Please verify that VMs are not needed."
				$global:EmailBody += "Notify IT if you need to reenable VM (it will be kept offline for two weeks and then deleted)"
				$global:EmailBody += "Claim physical server to start using it."
				$global:EmailBody += " "
											
				$global:EmailBody += "{0, -30} {1, -25} {2, -34} {3, -20} {4, -18}" -f "Server", "OS", "Model", "Serial #", "Shutdown"
										
				$ResultReadyForDeployment | % { 
	
					$global:EmailBody += "{0, -19} {1, -16} {2, -30} {3, -22} {4, -18}" -f $_.ComputerName, $_.OS, $_.Model, $_.SerialNumber, $_.Shutdown
		
				}
				
				$global:EmailBody += " "
			
			}

			Else {
		
				""
				Write-Host " ---------> Servers are not used. <---------  " -ForegroundColor Green -BackgroundColor Black
				Write-Host " --> Claim the server to start using it. <--  " -ForegroundColor Green -BackgroundColor Black
				Write-Host "                                              " -ForegroundColor Green -BackgroundColor Black
		
			}
							
			$ResultReadyForDeployment = $ResultReadyForDeployment | Sort Model, ComputerName -Descending
			  
			$Host.UI.RawUI.ForegroundColor = "Green"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -11} {2, -20} {3, -16} {4, -8}" -f "Server", "OS", "Model", "Serial #", "Shutdown"

			$ResultReadyForDeployment | % { 
	
				$Host.UI.RawUI.ForegroundColor = "Green"; $Host.UI.RawUI.BackgroundColor = "Black"; "{0, -14} {1, -11} {2, -20} {3, -16} {4, -8}" -f $_.ComputerName, $_.OS, $_.Model, $_.SerialNumber, $_.Shutdown
		
			}

			$Host.UI.RawUI.ForegroundColor = $originalColor
			$Host.UI.RawUI.BackgroundColor = $originalBackColor
			
			""			
			}
}
	
	If ( $ResultReadyForDeployment.Count -eq 0 -and $ResultRebuild.Count -eq 0 -and $ResultDeprecate.Count -eq 0 ) {
	
		If ( $Email ) {
							
			$global:EmailBody += "No unused servers found :-)"
			$global:EmailBody += " "
		
		}

		Else {
						
			If ( $PSBoundParameters.ContainsKey('RemoveException') -or $PSBoundParameters.ContainsKey('AddException') -or $PSBoundParameters.ContainsKey('ListExceptions') -or $PSBoundParameters.ContainsKey('ClaimServer') ) { }
			
			Else {
			
				""
			
				Write-Host "No unused servers found :-)" -ForegroundColor White -BackgroundColor Blue 
			
			}
		
		}
	}
	
	If ( $Email ) {
	
		SendEmail $EmailBody
		
	}

    If ( $Shutdown_Jira_A ) {
        
        $ProdDate = (Get-Date).ToShortDateString()

        $TicketA = Get-Jira -CreateTicket -Summary "Shutdown and Rename unused VMs" -Description $Shutdown_Jira_A -Assignee "<user name>" -ProdDate $ProdDate

        Get-Jira -StartProgress $TicketA -Quiet | Out-Null
		
		Get-Jira -Validate $TicketA -Quiet | Out-Null
		
        Get-Jira -CloseTicket $TicketA -Quiet | Out-Null
        
        ""
        
        Write-Host "Created and Closed $TicketA for VMs that were shutdown and renamed." -BackgroundColor Black -ForegroundColor Green

        ""
    }

    If ( $Salt_Graphite_Clean ) {
            
        $ProdDate = (Get-Date).ToShortDateString()

        $Description = "Delete Salt keys and Graphite data for " + $Salt_Graphite_Clean

        $TicketA = Get-Jira -CreateTicket -Summary "Delete Salt keys and Graphite data for offline servers" -Description $Description -Assignee "<user name>" -ProdDate $ProdDate

		Get-Jira -StartProgress $TicketA -Quiet | Out-Null
		
		Get-Jira -Validate $TicketA -Quiet | Out-Null

        Get-Jira -CloseTicket $TicketA -Quiet | Out-Null

        ""

        Write-Host "Created and Closed $TicketA for VMs that had their Salt key and Graphite data deleted." -BackgroundColor Black -ForegroundColor Green
        
        ""
    }

    $global:EmailBody = $null
	$global:EmailErrors = $null
	$global:ResultDeprecate = $null
	$global:ResultReadyForDeployment = $null
	$global:ResultRebuild = $null
	$global:ZookeeperResult = $null
    $global:Shutdown_Jira_A = $null 
    $global:Salt_Graphite_Clean = $null
    $global:Grains = $null
    $global:ZooNode = $null
    $global:Hex = $null
    $global:ExceptionsList = $null
    $global:NetworkKbOut = $null
    $global:ComputerName = $null
    $global:EmailErrors = $null

} #End End

} #End Get-UnusedServers
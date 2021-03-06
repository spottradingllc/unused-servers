Function Get-UnusedServers {

<#

.Synopsis

Get-UnusedServers uses Graphite, Salt and Zookeeper to determine which servers are not being used.

.Description

Get-UnusedServers uses data that collectl and custom python script send to Graphite to determine which servers are not being 
used and can be re-used. The process is outlined below:

1. Collectl sends data (CPU, Network and Disk utilizations) to Graphite server.

2. Python script is scheduled (with Salt) to run on all Linux servers to send number of logins on the server during the day 
to Graphite. It is very important to understand that 'root' login is not counted as active login. Script assumes that we always use domain accounts to login and manage our servers (including running our services under domain user accounts).

3. The script then gets average nettotals.kbout below 3 KB for all servers and selects first 100 servers with lowest average 
value among the entire dataset for the last 29 days.

4. Then the script determines if these 100 servers also exist in lowest average CPU dataset (average CPU utilization below 2%) 
and lowest average Logins dataset (maximum below 0.001 logins during 29 days).

5. If the server does not exist in CPU or Logins dataset it is declared as false positive and nothing else is done for this 
particular server.

6. If the server does exist in all 3 datasets than it is declared unused.

7. Based on the script parameters the following actions will take place:

a. The script determines properties of the server in question by using Salt (CPU, hardware, OS, kernel version etc.)

b. OS and kernel versions match our standard (CentOS 6.4 with 2.6.32-358.el6.x86_64 or CentOS 6.6 with 2.6.32-504.el6.x86_64):

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
the special account. This way number oflogins will be more than our set threshold and the server will no longer appear in the report of unused servers (for the next 29 days). If the server isnot being used after 29 days it will go back to the list of unused servers.

.Parameter ApproveServer

One or more, comma separated, computers to be approved as being unused.

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

Get-UnusedServers -ClaimServer CHIVLXSTG119

Claims CHIVLXSTG119 as being used so it will not appear in the report next time.

.Example

Get-UnusedServers -AddException CHIVLXSTG001 -Description “Test server” -Environment Staging

This will add CHIVLXSTG001 with the description “Test server” to the list of the exceptions so this server will be skipped by 
the Get-UnusedServers logic.

.Example

Get-UnusedServers -RemoveException CHIVLXSTG001 -Environment Staging

This will remove CHIVLXSTG001 from the list of exceptions in Staging.

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
	[Parameter(ParameterSetName = "Approve_Server", Mandatory = $true)]
	[ValidatePattern("Staging|UAT|Production")]
	$Environment,
	
	[string]
	[Parameter(ParameterSetName = "Approve_Server")]
	$ApproveServer
)

Begin {

	$ErrorActionPreference = "Stop"
	
	$originalColor = $Host.UI.RawUI.ForegroundColor
	$originalBackColor = $Host.UI.RawUI.BackgroundColor

	$EmailBody = @()
	$EmailErrorsHash = @{}
	$EmailErrors = @()
			
	$ResultOffline = @()
	$ResultReadyForDeployment = @()
	$ResultRebuild = @()
	$ResultDeprecateVMs = @()
	$ResultApprovalRequired = @()
	$ResultPotentialCandidate = @()

    #For Jira Ticket
    $Shutdown_Jira_A = ""
    $Salt_Graphite_Clean = ""
	
	$Jira_Tickets = @()
	
	Write-Debug "Reading configuration parameters from $($configPath)..."
	$Config = Read-Config -Path $configPath
		
	If ( $Config.DebugLogLevel ) { $DebugPreference = "Continue" }
	
	$Sensitivity = $Config.Sensitivity
	
	$Time = $Config.DaysToAnalyze
	$NumberOfServers = $Config.ServersToAnalyze
	
	$NetThreshold = $Config.NetThreshold
	$CPUThreshold = $Config.CPUThreshold
	$LoginsThreshold = $Config.LoginsThreshold
	
	$graphiteTimeout = $Config.graphiteTimeout
	
	$To = $Config.EmailTo
	$From = $Config.EmailFrom
	$CC = $Config.EmailCC
	$SMTP = $Config.EmailSMTP
	
	$LinuxKernel_RegEx = $Config.LinuxKernel
	$LinuxOS_RegExe = $Config.LinuxOS
	$WindowsKernel_RegEx = $Config.WindowsKernel
	$WindowsOS_RegEx = $Config.WindowsOS
	
	$UseSaltCache = $Config.UseSaltCache
	
	If ( $UseSaltCache ) { 
		Write-Debug "Using Salt Cache as a first source of grains info..." 
		Write-Debug "Will fall back to Salt API is Salt Cache does not return results..."
	}
		
	$SaltCacheName = $Config.SaltCacheName
	
	$DomainName = $Config.DomainName
	
	$UserName = $Config.ClaimUserName
	$Password = $Config.ClaimPassword
	
	$AWSAccessKey = $Config.AccessKey
	$AWSSecretKey = $Config.SecretKey
	$AWSRegion = $Config.Region
	
	$ExhibitorAuth = $Config.ExhibitorAuth
	
	Switch -regex ( $Environment ) {

		"Staging" { 
		
			$saltMaster = $Config.saltStagingAlias
			$saltTarget = $Config.saltStagingName
			$GraphiteServer = $Config.graphiteStagingAlias
			$GraphiteServerTarget = $Config.graphiteStagingName
			$ZoomServer = $Config.zoomStaging
			$emailSubject = "!!!< Unused Servers in Staging >!!!"
			$vCenter = $Config.vCenterStg
			$ZooNodes = $Config.ZooStg
		}
	
		"UAT" { 
	
			$saltMaster = $Config.saltUATAlias
			$saltTarget = $Config.saltUATName
			$GraphiteServer = $Config.graphiteUATAlias
			$GraphiteServerTarget = $Config.graphiteUATName
			$ZoomServer = $Config.zoomUAT
			$emailSubject = "!!!< Unused Servers in UAT >!!!"
			$vCenter = $Config.vCenterUAT
			$ZooNodes = $Config.ZooUAT
		}
	
		"Production" { 
	
			$saltMaster = $Config.saltProductionAlias
			$saltTarget = $Config.saltProductionName
			$GraphiteServer = $Config.graphiteProductionAlias
			$GraphiteServerTarget = $Config.graphiteProductionName
			$ZoomServer = $Config.zoomProduction
			$emailSubject = "!!!< Unused Servers in Production >!!!"
			$vCenter = $Config.vCenterProduction
			$ZooNodes = $Config.ZooProduction
		}	
	}
}

Process {

	Write-Debug "Getting Zookeeper Node..."
	$ZooNode = Get-ZookeeperNode -ZooNodes $ZooNodes
	Write-Debug "Got $($ZooNode) zokeeper node..."
	
	Write-Debug "Connecting to $($saltMaster) salt master..."
	Salt-Connect $saltMaster

	If ( $PSBoundParameters.ContainsKey('ClaimServer') ) { 

        		
		$Claim_Params = @{
			
			"CacheName" = $SaltCacheName ;
			"ComputerName" = $ClaimServer ;
			"DomainName" = $DomainName ;
            "UserName" = $UserName ;
            "Password" = $Password
		}

		If ( $Quiet ) { $Claim_Params.Add( "Quiet", $True ) }	

        $Result = Run-ClaimServer @Claim_Params
        
        If ( ! $Quiet ) { break }
        Else { return $Result }
        
    }
	ElseIf ( $PSBoundParameters.ContainsKey('RemoveException') ) { Remove-ZooException -ComputerName $RemoveException -ZooNode $ZooNode -Auth $ExhibitorAuth ; break }
	ElseIf ( $PSBoundParameters.ContainsKey('AddException') ) { Add-ZooException -ComputerName $AddException -Tag $Description -ZooNode $ZooNode -Auth $ExhibitorAuth ; break }
	ElseIf ( $PSBoundParameters.ContainsKey('ListExceptions') ) { List-ZooExceptions -ZooNode $ZooNode -Auth $ExhibitorAuth ; break }
	ElseIf ( $PSBoundParameters.ContainsKey('ApproveServer') ) { 
		
		$Approve_Params = @{
			
			"CacheName" = $SaltCacheName ;
			"ComputerName" = $ApproveServer ;
			"DomainName" = $DomainName
		}

		If ( $UseSaltCache ) { $Approve_Params.Add( "UseSaltCache", $True ) }	
		
		Run-ApproveServer @Approve_Params
				
		break 
	}

	Else {
		
		Write-Debug "Getting list of exceptions in $($Environment) environment..."
		$ExceptionsList = Get-ZooExceptions -ZooNode $ZooNode -Auth $ExhibitorAuth
		If ( $ExceptionsList ) { Write-Debug "Got exceptions $($ExceptionsList)..." }
		Else { Write-Debug "No Exceptions found..." }
		
		Write-Debug "Net Thershold (kbout): $($NetThreshold); CPU Thershold (user time): $($CPUThreshold); Logins Thershold (excluding root): $($LoginsThreshold); Max Servers: $($NumberOfServers)"
		
		$Stats_Params = @{
			
			"GraphiteServer" = $GraphiteServer ;
			"Threshold" = $LoginsThreshold ;
			"NumberOfServers" = $NumberOfServers ;
			"Time" = $Time ;
			"graphiteTimeout" = $graphiteTimeout
		}
		
		#Adding parameter to Get-LoginStats if we have exceptions
		If ( $ExceptionsList ) { $Stats_Params.Add( "ExceptionsList", $ExceptionsList ) }
					
		Write-Debug "Getting login stats..."
		$LoginsName = Get-LoginStats @Stats_Params
		
		Write-Debug  "Adding $($Sensitivity) Sensitivity parameter for Get-CPUStats and Get-NetStats functions..."
		$Stats_Params.Add( "Sensitivity", $Sensitivity )
						
		Write-Debug "Connecting to $($vCenter) vCenter server..."
		If ( ($defaultVIServer).IsConnected -and $defaultVIServer -match $vCenter ) { }
		Else { Connect-VIServer $vCenter -WarningAction SilentlyContinue | Out-Null }
				
		$LoginsName | % {
		
			#Error handling
			trap {
	
				If ( $_.Exception.Message -match "Error due to lack of resources" ) {

					If ( $Email ) { 
						
						$EmailErrorsHash.Error = "$($ComputerName): Did not get grains!"
						$EmailErrors += New-Object PSObject -Property $EmailErrorsHash
					}
															
					Else { Write-Host "Did not get reverse DNS for $ComputerName!" -BackgroundColor Black -ForegroundColor Red }
				}

                Else { $_.Exception.Message }
						
				continue
			}
				
			$Error.Clear()
		
			$Hash = @{}

			$ComputerName = $_.Name
			
			$Offline = $false
			
			Write-Debug $($ComputerName)
			
			# Removing unneeded parameters
			$Stats_Params.Remove("NumberOfServers")
			If ( $Stats_Params.ContainsKey("ComputerName") ) { $Stats_Params.Remove("ComputerName") }
			
			$Stats_Params.Add( "ComputerName", $ComputerName )
			$Stats_Params.Threshold = $NetThreshold
			
			Write-Debug "Getting network stats..."
			$NetName = Get-NetStats @Stats_Params
			# Getting list instead of array so we can compare against it
			$NetName = $NetName.Name
		
			Write-Debug "Getting CPU stats..."
			$Stats_Params.Threshold = $CPUThreshold
			$CPUName = Get-CPUStats @Stats_Params 
			# Getting list instead of array so we can compare against it
			$CPUName = $CPUName.Name
			
			If ( $CPUName -notcontains $ComputerName -and $NetName -notcontains $ComputerName ) { Write-Debug "$ComputerName - false positive" }
			
			Else {

				If ( $CPUName -contains $ComputerName -and $NetName -contains $ComputerName ) {
				
					Write-Debug "$ComputerName is not being used"
					
					# If computer is online
					If ( Test-Connection $ComputerName -Quiet -Count 1 ) {
					
						$GetIP = (Test-Connection $ComputerName -Count 1).IPV4Address.IPAddressToString
		
						$TestDNS = Test-ReverseDNS -Comp $ComputerName -IP $GetIP
				
						If ( $TestDNS.Result ) { 
													
							Write-Debug "Getting grains for $ComputerName"

							If ( $UseSaltCache ) { $Grains = Run-GetGrainsCache -ComputerName $ComputerName -CacheName $SaltCacheName -DomainName $DomainName }
							Else { $Grains = Run-GetGrains $ComputerName }
							
							If ( ($Grains | Out-String).Length -ne 2 -and $Grains -notmatch "Welcome" -and $Grains -notmatch $False ) {
								
								# What happens if we do not get result? How to handle this? 
								
								Write-Debug $Grains.productname
								Write-Debug $Grains.kernelrelease
							    If ( $Grains.serialnumber ) { Write-Debug $Grains.serialnumber }
								Else { Write-Debug "Serialnumber grain does not exist" }
								Write-Debug $Grains.osrelease
								Write-Debug $Grains.os
								Write-Debug $Grains.cpu_model
								If ( $Grains.virtual ) { Write-Debug $Grains.virtual }
								Else { Write-Debug "Virtual grain does not exist" }
																												
								$ProductName = $Grains.productname
								$KernelRelease = $Grains.kernelrelease
								
								If ( $Grains.serialnumber ) { $SerialNumber = $Grains.serialnumber }
								Else { $SerialNumber = "-" }
								
								$OSRelease = $Grains.osrelease
								$OSFullName = $Grains.os
								$CPUModel = $Grains.cpu_model
								
								If ( $Grains.virtual ) { $Virtual =  $Grains.virtual }
								Else { $Virtual =  "physical" }
													
								If ( $OSFullName -match "CentOS|RedHat" ) { $Os = "$OSFullName " + $OSRelease }
								Else { $Os = $OSRelease }
															
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
									"physical" { 
										$Hash.SerialNumber = $SerialNumber 
										$Hash.VMwareInfo = "-"
										$Hash.AWSInfo = "-"
										
										If ( $Grains.unused ) { $Unused = $Grains.unused }
										Else { $Unused = "-" }	
									}
									"VMware" { 
										$Hash.SerialNumber = "-" 
										Write-Debug "Getting VM Notes info..."
										$Hash.VMwareInfo = Get-VMNotes -ComputerName $ComputerName
										$Hash.AWSInfo = "-"
										$Hash.unused = "true"
										$Unused = $Grains.unused
									}
									"xen" { 
										$Hash.SerialNumber = "-" 
										$Hash.VMwareInfo = "-"
										$Hash.AWSInfo = Get-AWSApplication -ComputerName $ComputerName -AccessKey $AWSAccessKey -SecretKey $AWSSecretKey -Region $AWSRegion
										$Hash.unused = "true"
										$Unused = $Grains.unused
									}
								}
								
								$Hash.OS = $Os
								
								$Hash.Kernel = $KernelRelease
														
								If ( $CPUModel -match "CPU (.*)" ) {

								   $CPU = $Matches[1]
								
								   $CPU = $CPU.TrimStart( " " )
								
								   $Hash.CPU = $CPU
								
								}
								
								Else { $Hash.CPU = $CPUModel }
								
								Write-Debug "Getting Deployments Information..."
								$Hash.ConfigManagerInfo = Get-ConfigManagerInfo -ComputerName $ComputerName -Environment $Environment
								$Hash.ZoomInfo = Get-ZoomInfo -ComputerName $ComputerName -Zoom $ZoomServer -DomainName $DomainName
								
								If ( $DeprecateVMs ) {
									
									Write-Debug "Deprecating servers..."

	                                # Shutting down unused VMs.
	                                If ( $Virtual -match "VMware|xen" ) {
																			
	                                	If ( $Virtual -match "VMware" ) { 
										
											Write-Debug "Shutting down $($ComputerName)..."
											$Shutdown_Result = Invoke-VMwareShutdown -ComputerName $ComputerName 
											
											Write-Debug "Deprecate virtual machine - $ComputerName"
											$Rename_Result = SetNewVMName -ComputerName $ComputerName -Environment $Environment
										}
										
										Else { 
										
											Write-Debug "Shutting down $($ComputerName) AWS instance..."
											$Shutdown_Result = Invoke-AWSShutdown -ComputerName $ComputerName -AccessKey $AWSAccessKey -SecretKey $AWSSecretKey -Region $AWSRegion
											
											Write-Debug "Deprecate AWS Instance - $ComputerName"
											$Rename_Result = Set-NewAWSName -ComputerName $ComputerName -AccessKey $AWSAccessKey -SecretKey $AWSSecretKey -Region $AWSRegion
										}
															    																				
										#Checking if shutdown was successfull
										If ( $Shutdown_Result -match "True" ) { $Hash.Shutdown = "Yes" }
										Else { $Hash.Shutdown = "No" }
									
										$DeleteKey_Result = Delete-SaltKey -ComputerName $ComputerName -saltTarget $saltTarget -DomainName $DomainName
										
										#Checking if salt key deletion was successfull
										If ( $DeleteKey_Result -match $ComputerName ) { $Hash.SaltKeyDeleted = "Yes" }
										Else { $Hash.SaltKeyDeleted = "No" }
										
										If ( $Hash.Shutdown -match "Yes" -and $Hash.SaltKeyDeleted -match "Yes" ) { 
											Write-Debug "Adding $($ComputerName) to Shutdown and Salt Key deletion Jira Ticket..."
											$Shutdown_Jira_A = $Shutdown_Jira_A + "Shutdown $ComputerName, rename and delete Salt key ; " 
											
										}
										ElseIf ( $Hash.Shutdown -match "No" -and $Hash.SaltKeyDeleted -match "Yes" ) { 
												Write-Debug "Adding $($ComputerName) to Rename Jira Ticket..."
												$Shutdown_Jira_A = $Shutdown_Jira_A + "Rename VMware or AWS name for $ComputerName ; " 
										}
										ElseIf ( $Hash.Shutdown -match "Yes" -and $Hash.SaltKeyDeleted -match "No" ) { 
												Write-Debug "Adding $($ComputerName) to Shutdown Jira Ticket..."
												$Shutdown_Jira_A = $Shutdown_Jira_A + "Shutdown $ComputerName ; " 
										}
										Else { }
	                                }

	                                Else {
	                                    # Creating unused grain on physical servers
	                               		If ( $Unused -notmatch "-" ) { Write-Debug "Unused grain is $($Unused) on $($ComputerName)..." }
										
										Else {
											Write-Debug "Setting unused: approval_required grain on physical server - $ComputerName"
										
											$SetGrain_Params = @{
			
												"ComputerName" = $ComputerName ;
												"DomainName" = $DomainName ;
												"SaltCommand" = "grains.setval" ;
												"SaltArguments" = "unused approval_required"
											}
		
											#Adding parameter to Get-LoginStats if we have exceptions
											If ( $Email ) { $SetGrain_Params.Add( "Quiet", $True ) }
																				
											$SetGrain = Run-SetGrain @SetGrain_Params
																				
											If ( $SetGrain ) { $Hash.unused = "approval_required" ; $Unused = $Hash.unused }
											Else { 
										
												If ( $Email ) { 
													$EmailErrorsHash.Error = "$($ComputerName): Failed to set unused: approval_required grain!"
													$EmailErrors += New-Object PSObject -Property $EmailErrorsHash
												}
												$Hash.unused = "Grain_Not_Set" 
											}
											
											If ( $UseSaltCache ) { $Refresh = Run-RefreshSaltCache -ComputerName $ComputerName -CacheName $SaltCacheName -DomainName $DomainName }
										}
										
	                                    $Hash.Shutdown = "No"
	                                }
								}
								
								Else {
	                                   # $DeprecateVMs is not specified
	                                    $Hash.Shutdown = "No"
	                            } 
																			
								If ( $Os -match $LinuxOS_RegEx -and $KernelRelease -match $LinuxKernel_RegEx -or $Os -match $WindowsOS_RegEx -and $KernelRelease -match $WindowsKernel_RegEx ) {
								
									Write-Debug "$ComputerName is compliant with our OS and kernel versions"
								
	                                # For all servers that are compliant our kernel and OS versions
									If ( $DeprecateVMs -and ( $Virtual -match "VMware|xen" ) ) { $ResultDeprecateVMs += New-Object PSObject -Property $Hash }
	                                Else { 
									
										If ( $Unused -match "-" ) { $ResultPotentialCandidate += New-Object PSObject -Property $Hash }
										ElseIf ( $Unused -match "approval_required" ) { $ResultApprovalRequired += New-Object PSObject -Property $Hash }
										Else { $ResultReadyForDeployment += New-Object PSObject -Property $Hash }
									}	
	                            }
							
								Else {
	                                
									Write-Debug "$ComputerName is NOT compliant with our OS and kernel versions"
									
									# For all servers that are not compliant our kernel and OS versions
									If ( $DeprecateVMs -and ( $Virtual -match "VMware|xen" ) ) { $ResultDeprecateVMs += New-Object PSObject -Property $Hash }
									Else { 
									
										If ( $Unused -match "-" ) { $ResultPotentialCandidate += New-Object PSObject -Property $Hash }
										ElseIf ( $Unused -match "approval_required" ) { $ResultApprovalRequired += New-Object PSObject -Property $Hash }
										Else { $ResultRebuild += New-Object PSObject -Property $Hash }
									}
                                }
							}

							Else {
							
								If ( $Quiet ) { }
								
								Else {
									If ( $Email ) { 
									
										$EmailErrorsHash.Error = "$($ComputerName): Did not get grains!"
										$EmailErrors += New-Object PSObject -Property $EmailErrorsHash
									}

									Else { Write-Host "Did not get grains for $ComputerName. Please verify that salt-minion is running on that server or that Salt API is not having issues!" -BackgroundColor Black -ForegroundColor Red }
								}
							}
						}
				
						# If computer is offline but IP responds to pings (something else got the same IP already)
						Else { 					
							Write-Debug "$ComputerName is down. $GetIP is used by another server. Deprecating..."
							$Offline = $true							
						}
					}

					# If computer is offline
					Else { $Offline = $true }
					
					# For offline computers
					If ( $DeprecateVMs -and $Offline ) {
						
						Write-Debug "$ComputerName is offline. Deleteing graphite data..."
						
						$Result_ServerDown = ServerDown -Comp $ComputerName -graphTarget $GraphiteServerTarget -Deprecate -DomainName $DomainName
							
						If ( $Result_ServerDown.GraphiteDataDeleted -match "Yes" ) { 
							Write-Debug "Adding $($ComputerName) to Graphite Data deletion Jira Ticket..."
							$Salt_Graphite_Clean = $Salt_Graphite_Clean + $ComputerName + " ; " 
							
						}
						
						$ResultOffline += New-Object PSObject -Property $Result_ServerDown
					}
					
					ElseIf ( $Offline ) {
					
						Write-Debug "$ComputerName is offline."
					
						$Result_ServerDown = ServerDown -Comp $ComputerName -graphTarget $GraphiteServerTarget -DomainName $DomainName
	
						$ResultOffline += New-Object PSObject -Property $Result_ServerDown
					}
					
					Else { }
                }

				Else { Write-Debug "$ComputerName - false positive!" }
		    }
	    }
    }
}

End {

	If ( $Shutdown_Jira_A ) {
	
		Write-Debug "Creating Jira ticket for shutdown and salt key deletion events..."
    
        $ProdDate = (Get-Date).ToShortDateString()

        $TicketA = Get-Jira -CreateTicket -Summary "Shutdown and Rename unused VMs or AWS Instances and delete Salt keys in $Environment Environment" -Description $Shutdown_Jira_A -Assignee "andrew.girin" -ProdDate $ProdDate

        Get-Jira -StartProgress $TicketA -Quiet | Out-Null
		
		Get-Jira -Validate $TicketA -Quiet | Out-Null
		
        Get-Jira -CloseTicket $TicketA -Quiet | Out-Null
        
       	If ( $Email ) { 

			$jh = @{}
			
			$jh.Summary = "Shutdown and Salt Key deletion events"
			$jh.TicketNumber = $TicketA
			
			$Jira_Tickets += New-Object PSObject -Property $jh
		}
		
		Else {
			""
        	Write-Host "Created and Closed $TicketA for VMs and AWS Instances that were shutdown and renamed in $Environment Environment." -BackgroundColor Black -ForegroundColor Green
        	""
		}
	}

	If ( $Salt_Graphite_Clean ) {
	
		Write-Debug "Creating Jira ticket for Graphite data deletion events..."
            
        $ProdDate = (Get-Date).ToShortDateString()

        $Description = "Delete Graphite data for " + $Salt_Graphite_Clean

        $TicketA = Get-Jira -CreateTicket -Summary "Delete Graphite data for offline servers in $Environment Environment" -Description $Description -Assignee "andrew.girin" -ProdDate $ProdDate

		Get-Jira -StartProgress $TicketA -Quiet | Out-Null
		
		Get-Jira -Validate $TicketA -Quiet | Out-Null

        Get-Jira -CloseTicket $TicketA -Quiet | Out-Null

		If ( $Email ) { 
		
			$jh = @{}
			
			$jh.Summary = "Graphite Data Deletion events"
			$jh.TicketNumber = $TicketA
			
			$Jira_Tickets += New-Object PSObject -Property $jh
		}

        Else {
			""
        	Write-Host "Created and Closed $TicketA for offline servers that had their Graphite data deleted in $Environment environment." -BackgroundColor Black -ForegroundColor Green
        	""
		}
    }

	If ( $Quiet ) {
		# For Creat-VM script
		$ResultReadyForDeployment = $ResultReadyForDeployment | ? { $_.Model -match "VMware" } | Sort ComputerName -Descending
		$ResultReadyForDeployment
	}

	Else {

		If ( $Email ) {
	
			$TableID = 1
			
			If ( $EmailErrors ) {
			
				$HTML = Get-HTMLOutput -Data $EmailErrors -ReportHeader "Errors:" -ReportDescription "Verify that salt-minion is running or that Salt API is not having issues" `
											-FieldsToUse "Error" -Color "#CC0033" -TableID $TableID
				
				$EmailBody += $HTML
			}
			
			If ( $ResultOffline.Count -ne 0 ) {
			
				$ResultOffline = $ResultOffline | Sort ComputerName, Model
										
				$TableID ++
				
				$HTML = Get-HTMLOutput -Data $ResultOffline -ReportHeader "Offline Servers:" -ReportDescription "Graphite data needs to be deleted" -FieldsToUse "ComputerName, GraphiteDataDeleted" -Color red -TableID $TableID
							
				$EmailBody += $HTML
				
			}
			
			If ( $ResultDeprecateVMs ) {
			
				$ResultDeprecateVMs = $ResultDeprecateVMs | Sort ComputerName, Model
				
				$TableID ++
				
				$HTML = Get-HTMLOutput -Data $ResultDeprecateVMs -ReportHeader "Deprecated VMs:" `
											-ReportDescription "Deprecated VMs or AWS Instances will be completely deleted after two weeks. Notify IT if you need particular VM to be revived. <br><br> ZoomInfo: High Trust ; AWSInfo, VMwareInfo and ConfigManagerInfo: Medium Trust" `
											-FieldsToUse "ComputerName, OS, Model, ZoomInfo, ConfigManagerInfo, VMwareInfo, AWSInfo, Shutdown, SaltKeyDeleted" -Color "#9966FF" -TableID $TableID
				
				$EmailBody += $HTML
			}
			
			If ( $ResultApprovalRequired ) {
			
				$ResultApprovalRequired = $ResultApprovalRequired | Sort ComputerName, Model
				
				$TableID ++
				
				$HTML = Get-HTMLOutput -Data $ResultApprovalRequired -ReportHeader "Approval required:" `
											-ReportDescription "Servers need to be approved to become unused" `
											-FieldsToUse "ComputerName, OS, Model, Unused, ZoomInfo, ConfigManagerInfo, VMwareInfo, AWSInfo" -Color "#FF7F50" -TableID $TableID
				
				$EmailBody += $HTML
			}
			
			If ( $ResultPotentialCandidate ) {
			
				$ResultPotentialCandidate = $ResultPotentialCandidate | Sort ComputerName, Model
				
				$TableID ++
				
				$HTML = Get-HTMLOutput -Data $ResultPotentialCandidate -ReportHeader "Potential candidates for being unused:" `
											-ReportDescription "Servers might be unused" `
											-FieldsToUse "ComputerName, OS, Model, ZoomInfo, ConfigManagerInfo, VMwareInfo, AWSInfo" -Color "#6495ED" -TableID $TableID
				
				$EmailBody += $HTML
			}
			
			If ( $ResultRebuild.Count -ne 0 ) {
			
				$ResultRebuild = $ResultRebuild | Sort ComputerName, Model
				
				$TableID ++
				
				$HTML = Get-HTMLOutput -Data $ResultRebuild -ReportHeader "Servers with an old OS that were not used for the past 29 days:" `
											-ReportDescription "Servers need to be rebuilt with supported OS <br><br> ZoomInfo: High Trust ; AWSInfo, VMwareInfo and ConfigManagerInfo: Medium Trust" `
											-FieldsToUse "ComputerName, OS, Model, SerialNumber, ZoomInfo, ConfigManagerInfo, VMwareInfo, AWSInfo" -Color "#FF6600" -TableID $TableID
				
				$EmailBody += $HTML
			}
			
			If ( $ResultReadyForDeployment.Count -ne 0 ) {
			
				$TableID ++
				
				$ResultReadyForDeployment = $ResultReadyForDeployment | Sort ComputerName, Model
				
				$HTML = Get-HTMLOutput -Data $ResultReadyForDeployment -ReportHeader "Servers that were not used for the past 29 days:" `
												-ReportDescription "Logins (excluding root): 0 ; Network KBout < $NetThreshold ; CPU Utilization < $CPUThreshold <br><br> ZoomInfo: High Trust ; AWSInfo, VMwareInfo and ConfigManagerInfo: Medium Trust" `
												-FieldsToUse "ComputerName, OS, Model, SerialNumber, ZoomInfo, ConfigManagerInfo, VMwareInfo, AWSInfo" -Color "#33CC33" -TableID $TableID
				
				$EmailBody += $HTML
			
			}
			
			If ( $Jira_Tickets ) {
			
				$TableID ++
				
				$HTML = Get-HTMLOutput -Data $Jira_Tickets -ReportHeader "Jira Tickets:" -ReportDescription "Created and Closed" `
											-FieldsToUse "Summary, TicketNumber" -Color "#99FFFF" -TableID $TableID
				
				$EmailBody += $HTML
			}
			
			If ( $ResultReadyForDeployment.Count -eq 0 -and $ResultRebuild.Count -eq 0 -and $ResultOffline.Count -eq 0 -and $ResultDeprecateVMs.Count -eq 0 -and $ResultPotentialCandidate.Count -eq 0 -and $ResultApprovalRequired.Count -eq 0 ) {
			
				$EmailBody += "No unused servers found :-)"
				$EmailBody += " "
			
			}
			
			$EmailBody = $EmailBody | Out-String
			
			$Email_Params = @{
		
				"From" = $From ;
				"To" = $To ;
				"emailSubject" = $emailSubject ;
				"EmailBody" = $EmailBody ;
				"SMTP" = $SMTP
			}
		
			If ( $CC ) { $Email_Params.Add( "CC", $CC ) }
			
			SendEmail @Email_Params	
		}
	
		Else {

			If ( $ResultOffline.Count -ne 0 ) {
			
				$sp = Get-TableSpacing -Data $ResultOffline
											
				""
				Write-Host "--------> Offline Servers <---------" -ForegroundColor Red -BackgroundColor Black
				Write-Host "----> Please remove monitoring <----" -ForegroundColor Red -BackgroundColor Black
				Write-Host "                                    " -ForegroundColor Red -BackgroundColor Black
											
				$ResultOffline = $ResultOffline | Sort ComputerName, Model
					  
				$Host.UI.RawUI.ForegroundColor = "Red"
				$Host.UI.RawUI.BackgroundColor = "Black"
				"{0, -$($sp.ServerMax)} {1, -18}" -f "Server", "Graphite_Cleaned"

				$ResultOffline | % { 
					$Host.UI.RawUI.ForegroundColor = "Red"
					$Host.UI.RawUI.BackgroundColor = "Black"
					"{0, -$($sp.ServerMax)} {1, -18}" -f $_.ComputerName, $_.GraphiteDataDeleted 
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
					
				""

			}
			
			If ( $ResultDeprecateVMs ) {
			
				$sp = Get-TableSpacing -Data $ResultDeprecateVMs
			
				""
				Write-Host "---> Unused VMs or AWS Instances were shutdown <---" -ForegroundColor Magenta -BackgroundColor Black
				Write-Host "-------> VMs will be deleted after 2 weeks <-------" -ForegroundColor Magenta -BackgroundColor Black
		        Write-Host "                                                   " -ForegroundColor Magenta -BackgroundColor Black
														
				$ResultDeprecateVMs = $ResultDeprecateVMs | Sort ComputerName, Model
					  
				$Host.UI.RawUI.ForegroundColor = "Magenta"
				$Host.UI.RawUI.BackgroundColor = "Black"
				"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMAx)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)} {7, -9} {8, -16}" -f "Server", "OS", "Model", "ZoomInfo", "ConfigManagerInfo", "VMwareInfo", "AWSInfo", "Shutdown", "Salt_Key_Deleted"

				$ResultDeprecateVMs | % { 
				
					$Host.UI.RawUI.ForegroundColor = "Magenta"
					$Host.UI.RawUI.BackgroundColor = "Black"
					"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMAx)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)} {7, -9} {8, -16}" -f $_.ComputerName, $_.OS, $_.Model, $_.ZoomInfo, $_.ConfigManagerInfo, $_.VMwareInfo, $_.AWSInfo, $_.Shutdown , $_.SaltKeyDeleted
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
						
				""
			}
			
			If ( $ResultApprovalRequired.Count -ne 0 ) {
			
				$sp = Get-TableSpacing -Data $ResultApprovalRequired
				
				""
				
			    Write-Host "-----------> Approval required <-----------" -ForegroundColor Gray -BackgroundColor Black
			    Write-Host "---> Servers need to be approved first <---" -ForegroundColor Gray -BackgroundColor Black
			    Write-Host "                                           " -ForegroundColor Gray -BackgroundColor Black
						
			    $ResultApprovalRequired = $ResultApprovalRequired | Sort ComputerName, Model
				  
			    $Host.UI.RawUI.ForegroundColor = "Gray"
				$Host.UI.RawUI.BackgroundColor = "Black"
				"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f "Server", "OS", "Model", "ZoomInfo", "ConfigManagerInfo", "VMwareInfo", "AWSInfo"

			    $ResultApprovalRequired | % { 
				
					$Host.UI.RawUI.ForegroundColor = "Gray"
					$Host.UI.RawUI.BackgroundColor = "Black"
					"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f $_.ComputerName, $_.OS, $_.Model, $_.ZoomInfo, $_.ConfigManagerInfo, $_.VMwareInfo, $_.AWSInfo
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
					
	            ""
		    }
			
			If ( $ResultPotentialCandidate.Count -ne 0 ) {
			
				$sp = Get-TableSpacing -Data $ResultPotentialCandidate
				
				""
				
			    Write-Host "------------------> Potential Candidates <-----------------" -ForegroundColor Cyan -BackgroundColor Black
			    Write-Host "---> Run -DeprecateVMs option to have unused grain set <---" -ForegroundColor Cyan -BackgroundColor Black
			    Write-Host "                                                           " -ForegroundColor Cyan -BackgroundColor Black
						
			    $ResultPotentialCandidate = $ResultPotentialCandidate | Sort ComputerName, Model
				  
			    $Host.UI.RawUI.ForegroundColor = "Cyan"
				$Host.UI.RawUI.BackgroundColor = "Black"
				"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f "Server", "OS", "Model", "ZoomInfo", "ConfigManagerInfo", "VMwareInfo", "AWSInfo"

			    $ResultPotentialCandidate | % { 
				
					$Host.UI.RawUI.ForegroundColor = "Cyan"
					$Host.UI.RawUI.BackgroundColor = "Black"
					"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f $_.ComputerName, $_.OS, $_.Model, $_.ZoomInfo, $_.ConfigManagerInfo, $_.VMwareInfo, $_.AWSInfo
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
					
	            ""
		    }
				
			If ( $ResultRebuild.Count -ne 0 ) {
			
				$sp = Get-TableSpacing -Data $ResultRebuild
				
				""
				
			    Write-Host "--------> Servers with an old OS <--------" -ForegroundColor Yellow -BackgroundColor Black
			    Write-Host "-------> Rebuild with supported OS <------" -ForegroundColor Yellow -BackgroundColor Black
			    Write-Host "                                          " -ForegroundColor Yellow -BackgroundColor Black
						
			    $ResultRebuild = $ResultRebuild | Sort ComputerName, Model
				  
			    $Host.UI.RawUI.ForegroundColor = "Yellow"
				$Host.UI.RawUI.BackgroundColor = "Black"
				"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f "Server", "OS", "Model", "ZoomInfo", "ConfigManagerInfo", "VMwareInfo", "AWSInfo"

			    $ResultRebuild | % { 
				
					$Host.UI.RawUI.ForegroundColor = "Yellow"
					$Host.UI.RawUI.BackgroundColor = "Black"
					"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f $_.ComputerName, $_.OS, $_.Model, $_.ZoomInfo, $_.ConfigManagerInfo, $_.VMwareInfo, $_.AWSInfo
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
					
	            ""
		    }
		
			If ( $ResultReadyForDeployment.Count -ne 0 ) {
			
				$sp = Get-TableSpacing -Data $ResultReadyForDeployment
											
				""
				Write-Host "----------> Servers are not used <-----------" -ForegroundColor Green -BackgroundColor Black
				Write-Host "---> Claim the server to start using it <----" -ForegroundColor Green -BackgroundColor Black
				Write-Host "                                             " -ForegroundColor Green -BackgroundColor Black
					
				$ResultReadyForDeployment = $ResultReadyForDeployment | Sort ComputerName, Model
				  
				$Host.UI.RawUI.ForegroundColor = "Green"
				$Host.UI.RawUI.BackgroundColor = "Black"
				"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f "Server", "OS", "Model", "ZoomInfo", "ConfigManagerInfo", "VMwareInfo", "AWSInfo"

				$ResultReadyForDeployment | % { 
				
					$Host.UI.RawUI.ForegroundColor = "Green"
					$Host.UI.RawUI.BackgroundColor = "Black"
					"{0, -$($sp.ServerMax)} {1, -$($sp.OSMax)} {2, -$($sp.ModelMax)} {3, -$($sp.ZoomMax)} {4, -$($sp.CMMax)} {5, -$($sp.VMwareMax)} {6, -$($sp.AWSMax)}" -f $_.ComputerName, $_.OS, $_.Model, $_.ZoomInfo, $_.ConfigManagerInfo, $_.VMwareInfo, $_.AWSInfo 
				}

				$Host.UI.RawUI.ForegroundColor = $originalColor
				$Host.UI.RawUI.BackgroundColor = $originalBackColor
				
				""			
			}

			If ( $ResultReadyForDeployment.Count -eq 0 -and $ResultRebuild.Count -eq 0 -and $ResultOffline.Count -eq 0 -and $ResultDeprecateVMs.Count -eq 0 -and $ResultPotentialCandidate.Count -eq 0 -and $ResultApprovalRequired.Count -eq 0 ) {
				""
				Write-Host "No unused servers found :-)" -ForegroundColor White -BackgroundColor Blue 
			}
		}
	}

} #End End

} #End Get-UnusedServers